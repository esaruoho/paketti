# Session — Parameter Editor ↔ Mixer batch (2026-07-04)

## The requests (verbatim intent)
1. Parameter Editor "Expose on Mixer" should show the automation parameters the user is
   modifying — "currently does not do it."
2. A shortcut for the Mixer to expose (`show_in_mixer`) only the **automated** parameters, not all.
3. Feasibility study: Parameter Editor editable with per-plugin config — user decides order,
   what's shown/ditched, and can rename params for discoverability.
4. Parameter Editor visual mode: alternating black/white column backgrounds ("grid" thinking).
6. Feasibility: use Renoise as a pure Ableton Live sample editor — edit, press a button, saves
   exactly where it should so Live reloads. (No item 5 in the user's list.)
Directive: "log these as gherkin features, plan, propose, what is easy / hard, and hit them all."

## What was done
- **#1** fixed: the `show_in_mixer` write was gated behind `if follow_automation` in the Edit-A
  drag branch — moved out so exposing works with Automation Sync off. `@built @logic-verified`.
- **#2** shipped: `PakettiExposeAutomatedParamsOnMixer()` + keybinding + `[Trigger]` MIDI +
  `Mixer:Paketti Gadgets` menu. Uses read-only `DeviceParameter.is_automated`. `@built @logic-verified`.
- **#4** shipped: `grid_stripe` flag + "Grid stripes" checkbox + alternating column fill in the
  render loop. `@built @untested` (canvas render; couldn't screenshot-verify this session).
- **#3 / #6** feasibility written in `Research/parameter-editor/feasibility.md` with concrete
  designs and difficulty. #3 = FEASIBLE (display layer over the editor's own param list). #6 =
  Renoise save-back is easy; Live auto-reload needs AbletonOSC/M4L (cross-app, not Renoise-alone).

## Update (later same day) — #3 SHIPPED
A copilot agent then implemented #3 (apply layer + config schema + helpers, commits 50ce876e /
8f8ccc7c / 6569fbc2, plus an uncommitted apply-layer slice). This session reviewed that slice
(correct + safe but incomplete: no UI, unverified), built the missing Configure dialog (reorder /
hide / rename, Save / Reset / Cancel) + button + menu + keybinding, verified it live through the
real `BuildDisplayedParameters` path (mode-off==base, reset==base, reorder/hide/rename apply), and
shipped it in `eec944cc`. #3 is now `@built @in-renoise`. #6 remains a feasibility study.
Correction logged: persistence was NOT a gap — Renoise auto-persists the tool prefs document and
`save_as` forces it; the only real gap was the missing UI.

## Honest state
- #1/#2 verified by API reasoning + `.spine/check.py` clean + `luac -p` clean; not driven live.
- #4 renders in code but not visually confirmed (display capture was unreliable this session).
- #3/#6 are studies, not shipping features.

## How to get back
- Repo: /Users/esaruoho/work/paketti  (branch master)
- Files: PakettiCanvasExperiments.lua ; Research/parameter-editor/feasibility.md ;
  features/parameter-editor-mixer-and-config.feature
- Session: claude.ai/code/session_01PbeqBSqaip4QSUChJNfvCW
