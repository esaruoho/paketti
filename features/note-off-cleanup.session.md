# Note-off cleanup inspired by Phaos

The user requested comparison of SimpleNotesOff with Paketti, then authorized implementing the four cleanup commands and adding Phaos to the Ideas list. The saved comparison is [the inspection](../notes/simple-notes-off-comparison.md).

Implementation removes only note_value 120, setting it to 121. It scans every note column, visits each pattern-pool entry once for whole-song scopes, rejects non-sequencer tracks for selected-track cleanup, and offers Tools/Pattern Editor menus, repeat-suppressed keys, trigger MIDI mappings, undo descriptions and counts. Existing toggles and Clever Note Off remain unchanged. Phaos is credited under Ideas provided by.

Verification: `lua tests/note-off-cleanup.lua` passes mock checks for all scopes, preservation, hidden columns, unused patterns, duplicate sequence occurrences, repeat suppression, trigger filtering, menu invocation, track guards, no song and empty skips. `luac -p PakettiPatternEditor.lua PakettiMainMenuEntries.lua` passes. The full `.spine/check.py` registration harness loaded 248/248 files with no new registration errors, but its overall gate failed on three pre-existing duplicate global definitions in tests/keyjazz-special-cycler.lua; it also reported existing undeclared-call warnings elsewhere. Full-tree whitespace checking found pre-existing preferences.xml whitespace; the changed files pass. Live Renoise execution and dialog display remain untested. Delivery is local working-tree only; no commit, push or PR.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/06/rollout-2026-10-06T02-08-16-01a10e53-340b-7e73-8ce9-52f67ed0094e.jsonl
- Session ID: 01a10e53-340b-7e73-8ce9-52f67ed0094e
- Resume: Codex --resume 01a10e53-340b-7e73-8ce9-52f67ed0094e
- Verified UTC snapshot: 2026-10-05T23:09:17.381Z through 2026-10-05T23:13:20.343Z.
- Source bundle: [note-off-cleanup.transcript.jsonl](note-off-cleanup.transcript.jsonl), [note-off-cleanup.transcript.md](note-off-cleanup.transcript.md).
- Card: [note-off-cleanup.feature](note-off-cleanup.feature).
