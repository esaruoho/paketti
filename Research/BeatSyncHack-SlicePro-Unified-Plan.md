# Unified "Infinite BeatSync Slices" — Feasibility Analysis & Implementation Plan

Analysis date: 2026-05-29. Repo state: `master` @ `6826137`.

This evaluates the proposal to combine the **BeatSync XRNI hack** (`PakettiHack.lua`)
with **Sliced Pro** (`PakettiSlicePro.lua`) into a runtime synchronization system that
lets slices stay tempo-locked far beyond Renoise's native 512 `beat_sync_lines` cap, while
guaranteeing that illegal values never permanently serialize into an XRNS.

---

## TL;DR verdict

**Feasible, and ~70% already built.** The proposal is largely a description of infrastructure
that already exists in Paketti. The genuinely new work is small and well-scoped:

1. Remove SlicePro's `min(512,…)` clamp and route over-512 slices through the hack's XML injector.
2. Add a **batch** XML-roundtrip (patch all slices of one instrument in a single save/reload pass)
   so multi-slice and multi-instrument restoration isn't O(N) full instrument reloads.
3. Add **reload restoration** via `renoise.song().tool_data` (the proper persistence channel) so
   hacked values come back automatically after closing/reopening the project.

But there are **real reliability gaps and hard engine constraints** that must be handled before
this is safe to ship to users. The biggest are: autosave behavior is unverified (possible crash-file),
the post-save restore is **not** seamless (it reloads instruments and cuts playing voices), undo/redo
interacts badly with the clamp/restore mutations, and Render & Restore is **currently disabled** due to
engine crash bugs.

---

## What already exists (do not rebuild)

### `PakettiHack.lua` — the runtime injector (576 lines)

- `paketti_hack_set_beatsync_lines(target_lines)` — the XRNI XML roundtrip:
  `save_instrument(tmp.xrni)` → `unzip Instrument.xml` → regex-patch the Nth `<BeatSyncLines>`
  block (Nth = `selected_sample_index`) → `zip` back → `load_instrument(tmp.xrni)` → restore
  instrument name + selection. Range 1–65535. Forces `beat_sync_enabled = true`.
  Shells out to `unzip`/`zip` → **macOS/Linux only; Windows shows a status message and exits.**
- **Confirmed by the user and by the code:** the Lua API setter clamps `beat_sync_lines` to 1–512;
  only the XML loader accepts larger values. The engine **getter does not clamp on read** — once a
  sample holds an illegal value it reports the real number. This is why the save-protection needs no
  cache (see below).
- **Save protection (active):**
  - `app_will_save_document_observable` → `paketti_hack_on_will_save`: iterates **all** instruments ×
    **all** samples, finds every sample with `beat_sync_lines > 512`, records
    `{instr_idx, sample_idx, original_lines, had_sync}` into a restore queue, and sets
    `beat_sync_lines = 512` so the XRNS serializer writes legal values.
  - `app_saved_document_observable` → `paketti_hack_on_did_save`: for each queued entry, re-selects
    that instrument/sample and calls `paketti_hack_set_beatsync_lines(original_lines)` — i.e. a
    **full XML roundtrip per hacked sample.**
  - The old `PakettiHackCache` is **gone** — the current design uses the engine getter as source of
    truth ("iterate all samples to find the hacked ones — no cache needed"). This already makes
    multi-instrument, instrument-duplication, and Paketti-reload-before-save robust.
- **Render & Restore** (`pakettiBeatSyncHackRenderAndRestore`) is **commented out / DISABLED** —
  engine bugs: `TPlayerEngine::OnCalcBuffer` crash on Texture/Percussion stretch and
  `TPatternWasRemovedObservable` dtor SIGSEGV on slot deletion. The proposal lists "bake to WAV"
  as a desirable outcome; that path is not currently usable.
- **The crash being defended against:** writing `BeatSyncLines > 512` into an XRNS produces a file
  that hard-crashes (SIGSEGV in `TPatternPool` teardown, weak-ref-owner use-after-free) when reloaded.
  This is the whole reason illegal values must never serialize. The clamp-on-save is mandatory, not optional.

### `PakettiSlicePro.lua` — the state manager (1764 lines)

- Header: "Automatic per-slice `beat_sync_lines` calculation and application … so all slices remain
  tempo-locked when BPM changes."
- `SliceProState` already tracks per-instrument analysis: `total_beats`, `slice_beats[]`,
  `user_overrides[]`, `root_override`, `instrument_index`. **This is exactly the "state manager"
  the proposal wants** — it already holds every slice's intended musical length.
- Apply logic (lines ~705–735): iterates `instrument.samples[2..N]`, checks `sample.is_slice_alias`,
  computes `sync_lines = max(1, min(512, floor(beats * lpb + 0.5)))`, and sets
  `sample.beat_sync_lines = sync_lines` on the slice alias.
- **Slice-alias samples DO accept `beat_sync_lines`** via the API (≤512). The read-only restriction
  applies to the sample *buffer* and the *sample_mapping* of a sliced instrument, **not** to the
  `beat_sync_lines` property. So per-slice sync is real and already works up to 512.
- **The exact wall the proposal targets:** SlicePro line ~720 clamps with `min(512,…)` and pushes a
  warning `"Slice N: X beats clamped to 512 lines"`. Over-512 slices are silently capped today.

### Renoise API facts confirmed from the v6.2 reference

- All needed observables exist: `app_will_save_document_observable`, `app_saved_document_observable`,
  `app_new_document_observable`, `app_release_document_observable`, `app_new_document_pre_observable`.
- `renoise.song().tool_data` — `string?`, "per-tool persistent slot keyed by bundle id, only readable
  from inside the tool itself," written from `app_will_save_document_observable`, pairs with
  `renoise.Document:to_string()/from_string()`. **This persists inside the XRNS and is the correct,
  legal channel for reload restoration** — no sidecar file needed.

---

## Reliability assessment of the current save-safe logic (the user's explicit question)

| Case | Current behavior | Verdict |
|------|------------------|---------|
| **Multiple instruments / samples** | `on_will_save` iterates all instruments × all samples; getter is source of truth. Clamp side is solid. | **Clamp: OK.** Restore: see below. |
| **Repeated saves** | Each save clamps all >512 → serialize → restore all via per-sample roundtrip. Functionally correct (getter + `save_instrument` both preserve real values, so it self-corrects). | **Correct but slow**, and injects undo steps each time. |
| **Project reloads** | XRNS on disk holds 512 everywhere (safe). After load the hacked values are **gone** — nothing re-applies them. | **GAP — not implemented.** This is the proposal's core ask. Fix = `tool_data`. |
| **Undo / redo** | The will-save clamp and post-save re-hack mutate the document and create undo steps; `load_instrument` is itself a heavy undoable op. Undoing across a save can land on clamped (512) or half-restored state. | **Fragile.** Needs explicit handling / `describe_undo` discipline or suppression. |
| **Autosave** | Unverified whether Renoise's timed autosave fires `app_will_save_document_observable` / `app_saved_document_observable`. If it does **not**, autosave writes a crash-on-reload file. If it fires will-save but not saved, samples stay clamped silently (hack lost). | **CRITICAL UNKNOWN — must test in Renoise before shipping.** |
| **Instrument duplication** | A duplicated hacked instrument copies the in-memory >512 value (getter returns it); iterate-all finds both. | **OK** by design. |
| **Large projects** | Find-phase is cheap. Restore-phase does `save_instrument` (can be many MB) + shell `unzip`/`zip` + `load_instrument` **per hacked sample**, sequentially, after every save. | **Performance + UX risk.** Seconds of post-save churn; each reload cuts playing voices. |

### Concrete defects in the current restore path

1. **Not seamless.** `load_instrument` *replaces* the instrument object and stops any voices it is
   playing. Saving while the song plays (very common) cuts every hacked instrument out and reloads it.
   This directly contradicts the proposal's "seamless playback" goal.
2. **O(N) full reloads.** N hacked samples → N `save_instrument`/`load_instrument` cycles. A 30-slice
   instrument = 30 roundtrips after each save. The patcher only edits the Nth `<BeatSyncLines>`, so it
   cannot do an instrument in one pass today.
3. **Silent loss on failure.** If `unzip`/`zip`/`load_instrument` fails for an entry, that sample stays
   at 512 with only a status-bar note; the hack is lost until manually re-applied.
4. **Selection side effects.** `on_did_save` moves `selected_instrument_index`/`selected_sample_index`;
   it restores them at the end, but mid-interaction the selection jumps.
5. **`had_sync` recorded but unused** — `beat_sync_enabled` state isn't faithfully restored.
6. **Windows unsupported** (shell `zip`/`unzip`).

---

## Hard engine constraints (cannot be designed around)

- **No in-memory way to set >512.** The only mechanism is the file roundtrip
  (`save_instrument` → patch XML → `load_instrument`). Every "apply" or "restore" of an illegal value
  therefore pays a full instrument reload. There is no API to poke the live value.
- **Illegal values must never reach the XRNS serializer** — guaranteed crash on reload. The clamp-on-save
  is the safety floor; everything else builds on it.
- **Reload always lands on legal values.** Restoration after load is inherently a re-injection step
  (another roundtrip), not a "the value was preserved" step.
- **Render & Restore (bake to audio) is currently unusable** due to the two engine crash bugs noted above.
- **"Stop playback after next slice trigger" OFF + play-through** is a slice-triggering / sample-offset
  behavior, **independent** of `beat_sync_lines`. Beat-sync controls *time-stretch-to-fit*; continuous
  Serato-style jumping is a separate trigger concern. The two need to be designed as separate axes, not
  conflated.

---

## Recommended architecture

Keep the proposal's division of labor — it matches the code:

- **SlicePro = state manager.** It already owns per-slice intended beat length. Add: "this instrument
  uses extended sync" registry + the `tool_data` (de)serialization.
- **PakettiHack = injector.** Add a **batch** roundtrip that patches *every* over-512 `<BeatSyncLines>`
  in one instrument in a single save/reload, and expose it as a clean function SlicePro can call.
- **Renoise only ever saves legal values** — preserved exactly as today (clamp on will-save).
- **Extended sync exists only at runtime** — preserved; `tool_data` stores *restoration metadata*
  (which instrument/sample → which value), never the illegal value itself in a song property.

### `tool_data` schema (restoration metadata only)

Store a small structured doc, e.g. a Renoise Document or JSON string:
```
extended_sync = [
  { instrument = <name+index hint>, sample = <idx>, lines = <int>, mode = <int> }, ...
]
```
Write it in `app_will_save_document_observable` (after clamping). Read it in
`app_new_document_observable` and re-inject via the batch roundtrip. Key entries by a stable identity
(instrument name + sample index + slice signature) so a moved instrument index doesn't mis-target —
index alone is not stable across edits.

---

## Phased implementation path (safest order)

**Phase 0 — Verify the unknowns in Renoise (before writing integration code).**
A throwaway test tool that: (a) logs whether autosave fires the two save observables; (b) confirms a
reloaded XRNI with patched per-slice `<BeatSyncLines>` reports >512 on each slice alias via the getter;
(c) confirms `tool_data` round-trips through an actual save/quit/reload. **Do not build on assumptions
about autosave** — this is the single biggest crash risk.

**Phase 1 — Batch injector in PakettiHack.**
Add `paketti_hack_set_beatsync_lines_batch(instr_idx, { [sample_idx]=lines, ... })` that does ONE
`save_instrument` / patch-all-matching-`<BeatSyncLines>` / `load_instrument`. Refactor the existing
single-sample function to call it. This alone turns the O(N) post-save restore into one roundtrip
per instrument and is independently useful. Add a `pcall` guard + explicit failure surfacing
(never silently leave a sample clamped).

**Phase 2 — Reload restoration via `tool_data`.**
Write metadata on will-save (after clamp); read + batch-re-inject on `app_new_document_observable`.
This closes the "project reload" gap — the headline feature.

**Phase 3 — SlicePro integration.**
Replace the `min(512,…)` clamp: compute the true per-slice value; collect the over-512 ones; after the
normal ≤512 API pass, call the batch injector once for the over-512 set. Replace the "clamped to 512"
warning with a "N slices use extended sync (>512) — runtime only, song stays XRNS-safe" status.
Add a SlicePro preference gate (off by default; this is an advanced/experimental path).

**Phase 4 — Undo/autosave hardening.**
Wrap clamp/restore mutations in deliberate `describe_undo` boundaries (or document that an extended-sync
song's undo history is not guaranteed across a save). If Phase 0 shows autosave bypasses the observables,
either disable extended sync while autosave is enabled, or warn loudly in the dialog.

**Phase 5 — Seamlessness (optional, hard).**
Accept that save-time restoration cuts voices (document it), OR investigate deferring re-injection to an
idle tick and only for instruments not currently sounding. True zero-dropout restore may not be reachable
given `load_instrument` semantics — set expectations accordingly. The proven dropout-free alternative for
"one long sample, tempo-locked" already exists: `PakettiBeatsyncSeamless.lua` chops into N real
keyzoned samples each ≤512 — no illegal values at all. For pure long-form playback, that path is safer
than the hack; the hack's unique value is *per-slice* extended sync on a single sliced instrument.

---

## Open questions for the user

1. Autosave: do you run Renoise with autosave on? (Determines whether Phase 0's autosave result is a
   blocker or a nicety.)
2. Primary goal — per-slice extended sync on **one** sliced instrument (the hack's unique capability),
   or long-form whole-sample playback (where `PakettiBeatsyncSeamless`'s chop-to-N-samples is already
   dropout-free and crash-proof)?
3. Windows support needed? The injector currently shells out to `zip`/`unzip` (macOS/Linux only).
4. Acceptable for a save during playback to briefly reload hacked instruments (voice cut), or is
   zero-dropout a hard requirement? (Affects whether Phase 5 is mandatory.)
