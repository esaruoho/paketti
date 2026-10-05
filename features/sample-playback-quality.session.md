# Checked sample playback quality controls

The user requested low-hanging additions from SimpleInterpolation and documentation for improving native-load detection, particularly welcoming checked context menus. The earlier comparison confirmed existing setters for sample/instrument/song interpolation, sample oversampling on/off/toggle, song oversampling on/off and Paketti loader defaults.

Added a scoped menu/control layer inside PakettiTkna.lua that invokes existing setters, with uniform-mode checks, all-enabled oversampling checks, cycles and collective toggles. Menus live in Tools, Sample List, Sample Editor and Instrument Box. New shortcuts suppress repeats; MIDI mappings require triggers. Existing keybinding names remain intact; the selected-sample toggle shortcut is reused rather than duplicated. Changes receive explicit undo descriptions. Phaos was already credited in Ideas by the preceding change.

The [native-default document](../manual/NativeSampleDefaults.md) describes actual watcher behavior, ambiguities, a bounded event recorder and separated policy, lifecycle/undo considerations and an experiment matrix. No automatic watcher was implemented.

Verification: `lua tests/sample-playback-quality.lua` passes checked booleans, mixed scopes, cycle wrapping, toggling, field preservation, context menus, empty targets, repeats and MIDI checks. `luac -p PakettiTkna.lua` passes. Full registration harness loaded 248/248 modules and registered the five new keys and six MIDI mappings without registration errors. Overall gate still fails on the same three existing duplicate definitions in tests/keyjazz-special-cycler.lua, with the same 57 unrelated undeclared-call warnings. Changed-file whitespace check passes. Live Renoise menus and undo remain unverified. No commit, push or PR.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/06/rollout-2026-10-06T02-08-16-01a10e53-340b-7e73-8ce9-52f67ed0094e.jsonl
- Session ID: 01a10e53-340b-7e73-8ce9-52f67ed0094e
- Resume: Codex --resume 01a10e53-340b-7e73-8ce9-52f67ed0094e
- Verified UTC snapshot: 2026-10-05T23:09:17.381Z through 2026-10-05T23:34:14.172Z.
- Bundle: [sample-playback-quality.transcript.jsonl](sample-playback-quality.transcript.jsonl), [sample-playback-quality.transcript.md](sample-playback-quality.transcript.md).
- Card: [sample-playback-quality.feature](sample-playback-quality.feature).

## Menu refinement

The user supplied a Renoise screenshot showing alphabetical mode order and requested numeric quality ordering, an Oversampling separator, and removal of scope submenus with current instrument directly in the quality area. Flattened all scope actions into that area; current-instrument leaves are unprefixed, sample/song leaves explicitly name their scope. Four modes use 00 None, 01 Linear, 02 Cubic, 03 Sinc. Oversampling entries carry the -- menu separator prefix. Screenshot verifies earlier menus displayed live; the revised layout still needs live display verification.

## Next label and scope grouping

The user asked whether cycling increments by one, requested Interpolation (Next), and moved the separator to Whole Song so Oversampling remains in its scope block. The menu action advances one mode, wrapping Sinc to None; mixed scopes follow the first sample. Renamed menu, keybinding and MIDI action labels to Interpolation (Next). Separator now precedes Whole Song - 00 None. Mock tests cover the updated labels/separator and existing scope behavior; live revised layout remains unverified.
