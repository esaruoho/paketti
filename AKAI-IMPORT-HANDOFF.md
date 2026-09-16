# Handoff: Akai sampler import for Paketti

**Date:** 2026-09-16
**Author:** Claude (Opus 4.8) session with Esa
**Status:** NOT SHIPPED — three Akai importer files exist in the repo but are **dead code** (never `timed_require`d in `main.lua`). This document is the plan to make them ship.

Companion work shipped in the same session: Korg (`.ksf/.kmp/.ksc`), Reason NN-XT (`.sxt`) and Roland MV-8000 (`.mv0`) import — commit `58650ed9`. Those were ported fresh from Martin Bealby's 2011 `com.mxb.FileFormats` tool. The Akai side is **different**: Paketti already has its own Akai code, so this is a *wire-up + de-conflict + test* job, not a port.

---

## 1. What exists today (and why it does nothing)

Three materialised, self-contained files sit in the repo. None of them is referenced anywhere in `main.lua`, so their `add_file_import_hook` / `add_keybinding` / `add_menu_entry` calls never run. Confirmed 2026-09-16: `grep -nE 'PakettiAkai' main.lua` → only a commented-out `--timed_require("PakettiAKAI")` (a *different*, non-existent module name).

| File | Lines | What it provides |
|------|-------|------------------|
| `PakettiAkaiFormats.lua` | 352 | The "umbrella": `AKAI_FORMATS` table, `importAnyAkaiSample`, `importAkaiFolderBatch`, `exportCurrentSampleAsAkai`, `showAkaiFormatsInfo`, `checkAkaiImportersAvailable`. Registers **one universal import hook covering every akai extension** (`s`, `snd`, `akp`, `p`, `pgm`) + 3 keybindings. |
| `PakettiAkaiPrograms.lua` | 829 | Akai **program** parsers: `importAkaiProgram`, `importS1000Program` + `exportS1000Program`, MPC1000/MPC2000 `.pgm` (`is_mpc1000_pgm`/`is_mpc2000_pgm`, `import_mpc1000_pgm`, `import_mpc2000_pgm`, `load_mpc1000_samples`, `load_mpc2000_samples`, `importMPCProgram`, `importMPC1000Program`, `importMPC2000Program`, exporters). Registers a **`{p, pgm}` import hook** + 2 keybindings. |
| `PakettiAkaiMPC2000.lua` | 488 | MPC2000 `.snd` **sample** parser/writer: `parse_mpc2000_snd`, `create_mpc2000_snd`, `importMPC2000Sample`, `exportMPC2000Sample`, `importMPC2000Folder`. Registers a **`{snd}` import hook** + 2 keybindings. |

Formats covered, per the manifest of the tool they parallel:
- Akai S1000/S3000 `.s` sample
- Akai MPC2000/2000XL `.snd` sample
- Akai S1000 program `.p`
- Akai S5000/S6000/Z4/Z8 program `.akp`
- Akai MPC1000 / MPC2000 program `.pgm`

## 2. Good news — these are already modern Paketti code

I verified the following on `HEAD` (a20dab7c → now 58650ed9) via `git show HEAD:<file>`:

- **They use the current `sample_mapping` API** (`sample.sample_mapping.base_note / .note_range / .velocity_range`), NOT the dead `instrument:insert_sample_mapping()` that broke Bealby's ports. So the Korg/Reason/Roland modernisation I just did is **not** needed here.
- **No `require` of Bealby's `support/` libs** — self-contained (each file has its own `read_u16_le` etc.).
- **No duplicate keybinding/MIDI names across the three files** (`sort | uniq -d` on the registration names came back empty).
- Keybinding names are all 3-part (`Global:Paketti:...`) — no boot-crash risk from rule 16.

## 3. The blockers to resolve BEFORE `timed_require`

### 3a. Import-hook extension collision (the real one)
`PakettiAkaiFormats.lua`'s universal hook registers **all** akai extensions, while the other two register subsets:
- Formats umbrella hook: `s, snd, akp, p, pgm`
- Programs hook: `p, pgm`
- MPC2000 hook: `snd`

Renoise allows only one import hook per (category, extension-set). Each file guards with `has_file_import_hook(...)` so the *second* registration for an already-taken extension is skipped — but **load order then decides which parser actually handles `.snd`, `.p`, `.pgm`**, and that is fragile and confusing. Also note `has_file_import_hook` matches on the *exact extension list*, so a `{snd}` check does **not** see a `{s,snd,akp,p,pgm}` umbrella registration — meaning you can end up with genuinely conflicting hooks depending on order.

**Decision needed (pick one):**
1. **Umbrella only** — load `PakettiAkaiFormats.lua`, and have its `importAnyAkaiSample` dispatch to the right parser in `PakettiAkaiPrograms` / `PakettiAkaiMPC2000` by calling their global functions. Do NOT register the per-file hooks. Cleanest. Requires the parser files to expose their functions as globals (they do) and the umbrella to route by `detect_akai_format`.
2. **Per-format only** — drop the universal hook, keep `{snd}` on MPC2000 and split `{p}` (S1000 program) vs `{pgm}` (MPC program) cleanly, add a `{s}` and `{akp}` hook where the parsers live. More hooks, but each extension has exactly one owner and no dispatch layer.

Recommendation: **option 1** (umbrella dispatch) — it matches how `importAnyAkaiSample` was already designed and gives one obvious entry point.

### 3b. `renoise.song()` at load time (rule 9)
Grep before wiring: none was obvious at module scope, but confirm each file only *calls* `renoise.song()` inside functions, never at file top level. `git show HEAD:PakettiAkaiPrograms.lua | grep -n 'renoise.song()'` and check the line is inside a `function`. (The hits at 588/594/625 are inside `load_mpc2000_samples`, which is fine.)

### 3c. Forward-reference ordering (rules 18/28)
Each file registers its hooks/keybindings at the bottom, after the function definitions — good. But `PakettiAkaiFormats.lua`'s umbrella dispatch (if you take option 1) will call globals defined in the *other two* files. Those are resolved lazily at invoke time, so load order only matters for the registration guards, not for dispatch. Still: `timed_require` `PakettiAkaiMPC2000` and `PakettiAkaiPrograms` **before** `PakettiAkaiFormats` so the umbrella's guard sees the specific hooks first (or, under option 1, so it can decide not to double-register).

### 3d. `.spine/check.py` MUST pass
After wiring, run `python3 .spine/check.py` (in `~/work/paketti`). It replicates Renoise's duplicate-registration guard, which the test harness silently dedups (rule 24). A duplicate `add_keybinding` / `add_midi_mapping` aborts the whole tool load in real Renoise. Must print `✅ clean`.

## 4. The wiring change (once 3a–3c are settled)

In `main.lua`, in the "File Import / Export" block (near line 1461, right after the Korg/Reason/Roland block added this session):

```lua
timed_require("PakettiAkaiMPC2000")   -- .snd parser (define before umbrella)
timed_require("PakettiAkaiPrograms")  -- .p / .pgm / .akp / .s program parsers
timed_require("PakettiAkaiFormats")   -- umbrella dispatch + hooks (load last)
```

Then add import-hook prefs + `should_register_hook` gating to match the rest of Paketti (this is how the Korg/Reason/Roland ones were done this session):
- Declare `pakettiImportAkaiSND`, `pakettiImportAkaiProgram`, `pakettiImportAkaiS` (etc., whatever the final hook split is) in `Paketti0G01_Loader.lua`'s `renoise.Document.create("ScriptingToolPreferences")` block (near line 454, beside `pakettiImportKSF...pakettiImportMV0`).
- Move the hook registrations into `PakettiImport.lua`'s centralised block guarded by `should_register_hook(...)` (like every other format), **or** leave them in-file but gate them on the new prefs. The centralised approach is the house style — see the KSF/KMP/KSC/SXT/MV0 hooks added at `PakettiImport.lua` for the exact pattern.
- Add checkboxes to the Import Hooks dialog in `Paketti0G01_Loader.lua` (near line 4107) for parity.

## 5. Testing — DO NOT claim done without real files

There are **no Akai test files** in this repo to verify against, and PakettiMCP was **not connectable** this session (Renoise wasn't running the tool), so nothing was live-tested. Before shipping:

1. Get real `.snd`, `.s`, `.p`, `.akp`, `.pgm` files (Bealby's `com.mxb.FileFormats.xrnx/samples/` and `instruments/` folders contain example files — check `~/Library/Mobile Documents/com~apple~CloudDocs/Renoise/Tools/com.mxb.FileFormats.xrnx/`).
2. With Renoise running + Paketti loaded, drop each format onto the disk browser AND use the menu entry. Verify: sample audio is correct (not noise → endianness/bit-depth right), keyzones map sensibly, no missing-sample false alarms.
3. If you can reach PakettiMCP (`localhost:19714`), call the real global (e.g. `importMPC2000Sample("/path/to.snd")`) via `paketti_eval` and read back `renoise.song().selected_sample.sample_buffer.number_of_frames` etc. — call the shipped global, never re-inline it (skill rule).
4. Watch for the ProcessSlicer / idle-notifier brick (rule 25): if the MPC program loaders use `ProcessSlicer` and one throws, it can disable all Paketti notifiers until a Renoise restart. Probe first.

## 6. Reference: Bealby's Akai parsers (for filling gaps)

If any Paketti parser is incomplete, cross-reference the 2011 originals in `com.mxb.FileFormats.xrnx`:
- `samples/akai-s1000s.lua` (.s), `samples/mpc2000-snd.lua` (.snd)
- `instruments/akai-s1000p.lua` (.p), `instruments/akai-s5s6.lua` (.akp)
- `instruments/mpc1000-pgm.lua`, `instruments/mpc2000-pgm.lua`, `instruments/mpcCommon-pgm.lua`
- Support: `support/akaii_to_ascii` (in `file_tools.lua`) — AKAII→ASCII name decoding, needed for S1000/S3000 sample names. Paketti's `PakettiAkaiPrograms.lua` already has its own `akaii_to_ascii` at line 43; compare them if names come out garbled.

Note Bealby's mapping calls (`insert_sample_mapping`) are dead API — do NOT copy those lines; Paketti's files already do it right.

## 7. Definition of done

- [ ] Hook-collision decision made (§3a) and implemented
- [ ] No load-time `renoise.song()` (§3b)
- [ ] `timed_require` added to `main.lua` in the right order (§4)
- [ ] Prefs declared + `should_register_hook` gating + dialog checkboxes (§4)
- [ ] `python3 .spine/check.py` → `✅ clean`
- [ ] All five extensions tested against real files in a running Renoise (§5)
- [ ] `manual/CHANGESLOG.md` + `manual/README.md` Import section updated
- [ ] Committed via plumbing (iCloud SIGBUS hazard, rule -0.5) + pushed + `gumroad-paketti` launched
