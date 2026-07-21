# Groovebox 8120 — Per-Step Sample Mode (MODE2) — Design

Status: **SHIPPED.** Built after this doc was written; owning file `PakettiEightOneTwenty.lua`
(~10,800 lines). This document is kept as the design record — the header and the "Open decisions"
below are annotated with what actually shipped.

**What shipped (vs. this design):**
- **Mechanism → Option A (mode-scoped remap).** The remap fires only when you opt into MODE2;
  existing songs are untouched until then. Entering Per-Step the first time remaps the row
  instruments to one-note-per-sample. (The doc recommended Option B; Option A is what shipped.)
- **Mode scope → global.** One Mode toggle button flips all 8 rows between Single Sample (MODE1)
  and Per-Step Sample (MODE2) together.
- **Persistence → in-memory.** State lives in `row_elements.step_samples[]`, `StepMode == "perstep"`,
  and `PakettiEightOneTwentyNotePerSampleActive`.
- **Where it lives now:** per-step valuebox row build (`~:1671`), note-per-sample writes in
  `print_to_pattern` (`~:2293`, `~:2361`, `~:9248`), Mode button + tooltip (`~:3326`), MODE2 seeding
  on entry (`~:3170`), `fetch_pattern` inferring `step_samples` from the note (`~:3681`), arrow-key
  nudge of the focused per-step field (`~:4800`).

---

## Original design (as proposed, pre-build)

## What you asked for

A **Mode button** that flips each row between:

- **MODE1 (current):** the per-row control strip — `< >`, `Clear`, `Random Steps`, instrument
  dropdown, `Load`, `RandomLoad`, the sample slider (1–120), `Random`, `Show`. One sample per
  row; the 16/32 checkboxes just toggle that one sample on/off across steps.
- **MODE2 (new):** under **every** step checkbox, a **numbervaluebox 001–120** choosing *which
  sample triggers on that step*. Every step can fire a different sample from the row's 120-sample kit.

## How sample-selection works TODAY (the thing that has to change)

This is the crux. Right now a row plays exactly one of its (up to 120) samples via a trick:

- The kit's samples are **all keyzone-mapped to the full note range 0–119, base note C-4 (48)** —
  they overlap completely (`PakettiEightOneTwenty.lua:2901-2903`, RandomLoad).
- "Which sample is audible" is chosen by **velocity-range choke**
  (`pakettiSampleVelocityRangeChoke`, `PakettiRequests.lua:6056`): the chosen sample gets
  velocity `{0,127}`, **every other sample gets `{0,0}`** (silenced). This is *static, whole-
  instrument state* — it is not per-note.
- `print_to_pattern` (`PakettiEightOneTwenty.lua:2196`) writes the **same note `C-4` + instrument**
  on every ON step. The audible sample is whatever the choke last selected.

**Consequence:** you cannot choke per-step. Velocity-choke is global to the instrument, decided
once, not at trigger time. So MODE2 *cannot* be built on the current selection mechanism.

## The only pattern-level way to trigger a different sample per step

Renoise triggers a sample through `(instrument, note)` via the keyzone. There is **no** pattern
effect command for "play sample index N." So per-step sample choice **must be driven by the note
value**, which means each sample needs its **own single-note keyzone**:

> Map sample *i* (1..120) → note *(i-1)*, `note_range = {i-1, i-1}`, `base_note = i-1`,
> velocity `{0,127}`. 120 samples ↔ notes 0..119 — an **exact 1:1 fit** (Renoise has exactly 120
> playable notes; 120=OFF, 121=empty).

Then "trigger sample N on step S" = write `note_value = N-1` on that step. This is exactly how a
Renoise/Redux drumkit natively works. The velocity-choke hack disappears.

## Two ways to reconcile MODE1 and MODE2 mappings — **Option A shipped**

### Option A — Mode-scoped remap (surgical, MODE1 untouched) ✅ SHIPPED
- MODE1 keeps the current full-overlap + velocity-choke exactly as-is.
- Entering MODE2 **remaps** the kit to note-per-sample (un-chokes, one note each).
- Leaving MODE2 **restores** full-range + re-applies choke to the slider's sample.
- 👍 Zero change to MODE1 behavior, loaders, MIDI switcharoo, beatsync sample-finder.
- 👎 Mutates the user's instrument on every toggle; the round-trip must restore *perfectly* or the
  kit is left in a weird state. Fragile, and risky to do mid-performance.

### Option B — Unify on note-per-sample (cleaner, deeper) — *recommended at design time, NOT shipped*
- Drop velocity-choke as the selection mechanism. The kit is **always** note-per-sample.
- MODE1 slider value V → every ON step writes `note (V-1)` (one sample across all steps — same UX,
  achieved by note instead of choke).
- MODE2 → each ON step writes `note (perStepValue-1)`.
- MODE1 becomes the special case of MODE2 where all steps share one sample number.
  `print_to_pattern` collapses to a single code path.
- 👍 No fragile remap on toggle; removes the global-choke hack; tracker-native; one write path.
- 👎 Bigger change: touches the drumkit loader (`loadRandomDrumkitSamples` maps `{0,119}` today →
  must map note-per-sample for 8120), the slider notifier, `midi_sample_velocity_switcharoo`, the
  beatsync primary-sample finder, and `Fetch`. Changes how *existing* saved 8120 sets behave.

## Interface / layout

The row container (`PakettiEightOneTwenty.lua:2807`) stacks: number_buttons_row → **checkbox_row**
→ yxx_checkbox_row → control strip. MODE2 adds a **4th aligned row of N valueboxes** directly under
the checkbox row, bound to `row_elements.step_samples[i]` (1–120, default = slider value).

- **Show/hide by `.visible`** — already proven in this exact file (`:4123` toggles the beatsync
  block). Build both the control strip and the per-step valuebox row once; flip `.visible` on Mode
  change. No dialog rebuild needed (lighter than reopen).
- **Mode button placement:** recommend **one global Mode button** in the top `global_controls`
  strip, toggling all 8 rows together — keeps `print_to_pattern` uniform. (Per-row is possible but
  multiplies state and edge cases.) **← decision needed.**
- **Alignment caveat:** checkboxes are `width=30`. A `vb:valuebox` showing "120" with its up/down
  arrows needs ~36–44px or the arrows clip. So MODE2 either widens step cells to ~40px (32 steps ×
  40 = 1280px, still within the existing ~1280px width budget) or accepts a slightly wider row.
  This is the one real layout constraint.
- **Density:** 32 steps × 8 rows = up to 256 valueboxes live at once. Honor the valuebox request,
  but worth eyeballing performance/visual load at 32-step × 8-row.

## State, persistence, round-trip
- `row_elements.step_samples = {}` — N integers (1..120), default to the slider value so flipping to
  MODE2 starts "flat" (every step = current sample) and you edit from there.
- **Persistence:** in-memory first. Later: persist per-row (track-name encoding like the existing
  `8120_NN[steps]`, or a preference) so it survives dialog reopen / step-count switch (which
  currently closes+reopens the dialog, `:3090`).
- **Fetch** (`fetch_pattern`) in MODE2 must infer `step_samples[i]` from each line's note value
  (`note_value + 1`). MODE1 fetch stays note-agnostic.
- **`<` `>` `Clear` `Random Steps`** should operate on `step_samples` too in MODE2 (rotate/clear/
  randomize the sample numbers, not just the on/off bits).

## Touch list (Option B)
- `print_to_pattern` (`:2196`) — write per-step note from `step_samples`; MODE1 = uniform.
- `write_to_phrase` (`:~2150`) — same per-step note logic for phrase output mode.
- Row builder (`:~1502`) — add the valuebox row + `step_samples`; wire `.visible` to mode.
- `global_controls` (`:2978`) — add the Mode button + global mode state.
- `loadRandomDrumkitSamples` callers in 8120 (`:2895` etc.) — note-per-sample mapping.
- slider notifier (`:1987`), `update_sample_name_label`, beatsync sample-finder — drop/adapt choke.
- `fetch_pattern`, `<`/`>`/`Clear`/`Random Steps` notifiers — handle `step_samples`.

## Open decisions before building — RESOLVED (as shipped)
1. **Mechanism: Option A (scoped remap) or Option B (unify on note-per-sample)?** → **Option A** —
   scoped remap; MODE1 and existing songs untouched until you opt into MODE2.
2. **Mode scope: global (all 8 rows) or per-row?** → **Global** — one Mode button toggles all 8 rows.
3. **Persistence now or in-memory first?** → **In-memory** (`step_samples[]` / `StepMode` /
   `PakettiEightOneTwentyNotePerSampleActive`).
