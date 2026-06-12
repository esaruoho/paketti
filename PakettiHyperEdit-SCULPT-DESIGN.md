# HyperEdit — Cirklon-style Sculpt / Random modes (design)

Source: SynthCamp 2026 demo follow-up. Four sculpt modes ported from the Cirklon
sequencer. New **sculpt-mode axis** layered on top of HyperEdit's existing
data-source axis (Effect Parameters / Steppers).

## Cirklon manual (verbatim summary)

Sculpt lets knobs A/B continuously edit a pattern's values as it plays. Enabled by
holding the SCULPT key; the top display line shows the sculpt mode + a preview.
While sculpt is active and the pattern is playing, **holding SCULPT modifies the
value for the current row and step according to the knob positions**. Four modes:

- **Sculpt ABS** — knob A overwrites the value in each playing step.
- **Sculpt REL** — knob A adjusts the stored value by a relative (signed) amount,
  zero at knob mid-position. Hold across repeats → each step moves incrementally
  further from its original value.
- **Random ABS** — each playing step overwritten with a random value in the range
  set by knobs A and B.
- **Random REL** — each step adjusted by a random offset in the A..B range;
  multiple passes accumulate.

## How HyperEdit already supports this (code facts)

- **Canonical data**: `step_data[row][step]` ∈ 0.0–1.0 (line 1030). Matches the
  "127 = 1.0, 0 = 0.0" mental model directly — no translation layer.
- **Step-entry hook**: `PakettiHyperEditUpdatePlayheadHighlights()` (line 720),
  40 ms timer, computes the playing step per row and change-detects via
  `playhead_step_indices[row] ~= step_index` (line 780). Fires once per step
  entry → correct cadence for REL accumulation (once per pass, not 25×/s).
- **Write-back**: stepper → `PakettiHyperEditWriteStepper(row)` (line 443, cheap,
  native 0–1). effect → `PakettiHyperEditWriteAutomationPattern(row)` (line 2084,
  rewrites envelope).
- **Hold gesture**: `vb:button` has `pressed`/`released` notifiers; release is
  guaranteed to fire after press (Button.md:105). Direct SCULPT-key analogue.
- **Focused row**: `current_focused_row` (line 1041) tracks last-interacted row.

## The four transforms (applied to each ACTIVE playing step, once per entry)

Work in 0–1 internally; expose knobs as 0–127 to the user.

- Sculpt ABS:  `step = A`
- Sculpt REL:  `step = clamp01(step + A)`   (A signed, −1..+1, center 0)
- Random ABS:  `step = rand(A, B)`
- Random REL:  `step = clamp01(step + rand(A, B))`   (cumulative)

Clamp at 0 and 1 (no wrap). Skip inactive steps (`step_active`).
`math.random()` is fine in Renoise Lua (the Workflow-sandbox ban does not apply).

## New UI: sculpt toolbar (top row, distinct from the Effect/Stepper popup)

- Sculpt-mode selector: `Regular | Sculpt ABS | Sculpt REL | Random ABS | Random REL`
- Knob A, Knob B (0–127; REL shows signed −127..+127, center 0). B only used by
  Random modes.
- SCULPT hold button (momentary, pressed→holding=true, released→holding=false).

## Mechanism (the "hold" question)

In `UpdatePlayheadHighlights`, at the existing step-change branch: if a sculpt mode
is engaged AND holding AND playing, transform `step_data[row][new_step]`, clamp,
write-through that row. Once-per-entry cadence is already there.

### Decisions (Esa, 2026-06-13)
- **Hold gesture = BOTH** (button foundation + canvas-hold live layer) PLUS a
  **keyboard shortcut** and a **MIDI button**. Keyboard = TOGGLE (no reliable
  key-up in Renoise); MIDI = momentary (note/CC release) or toggle (trigger map);
  button + canvas-hold = momentary. All four funnel through
  `PakettiHyperEditSculptSetActive(on)`.
- **Scope = per-row selectable** — each row has an "S" arm toggle (default all
  armed on open). Only armed rows respond. Arm All / Arm None buttons in toolbar.
- **Knobs = valueboxes** A/B, −127..127.

## RESULT (what shipped)
- `Paketti0G01_Loader.lua`: 3 prefs — `PakettiHyperEditSculptMode/KnobA/KnobB`.
- `PakettiHyperEdit.lua`:
  - state block + `PakettiHyperEditSculptStep` (the 4 transforms),
    `PakettiHyperEditMaybeSculptStep` (engine hook), `…SculptSetActive`,
    `…SculptToggle`, `…SculptArmAll`, `…SculptToggleArm`, `…SculptUpdateHoldButton`.
  - engine hook wired into BOTH branches of `UpdatePlayheadHighlights`
    (stepper + effect), inside the existing once-per-step-entry change-detect.
  - canvas-hold live gesture in `HandleRowMouse` (mouse-Y → `sculpt_live_a`).
  - Sculpt toolbar added above the rows; per-row "S" arm button added.
  - prefs sync + arm-all on dialog open; sculpt reset in `Cleanup`.
  - registrations: keybinding `Global:Paketti:HyperEdit Toggle Sculpt Hold`,
    MIDI `Paketti:Paketti HyperEdit Sculpt Hold`.
- `manual/CHANGESLOG.md`: 2026-06-13 feature entry.

## Honest grades
- `@built` — code written; `luac` parses clean as Lua 5.1.
- `@untested-live` — NOT yet verified in a running Renoise. The live instance still
  has the OLD code until Paketti is reloaded. Live test plan below.
- Known v1 limits: sculpt only touches ACTIVE steps (inactive steps stay empty —
  matches how WriteAutomationPattern writes points). Effect mode rewrites the whole
  envelope per armed row per step-crossing while held (same cost as a MIDI-knob
  write); stepper mode is cheap. A single `sculpt_live_a` is global, so canvas-hold
  feeds the same live A to every armed row (arm one row for surgical use).

## Live test plan (run after reloading Paketti in Renoise)
1. Open HyperEdit (Stepper mode is easiest — cheap writes). Assign a Stepper row,
   fill some steps. Play the pattern.
2. Sculpt REL, A = −10, arm one row, hold SCULPT → that row's steps walk down to 0
   over successive passes and clamp.
3. Sculpt ABS, A = 64, hold → armed row's playing steps flatten toward ~0.5.
4. Random ABS / REL → values scatter / drift within A..B.
5. Verify keyboard toggle engages/disengages; MIDI pad does momentary; canvas-hold
   sweeps live with mouse-Y.

## STATUS: @built, @untested-live
