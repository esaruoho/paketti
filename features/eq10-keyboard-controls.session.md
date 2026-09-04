# EQ10 Keyboard Controls Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-04

## User Request

Esa asked to implement GitHub issue #522, “Controlling EQ10 with shortcuts,” and validate issue #781, “knobs for changing notes per row.”

## Implementation Notes

Issue #522 requested QWERTY keyboard combinations for moving EQ10 controls. The existing EQ10 XY dialog now accepts Shift+1..0 to raise bands 1..10 by 1 dB and Shift+Q..P to lower bands 1..10 by 1 dB. Values are clamped to each parameter’s native minimum and maximum, and the existing dialog fallback still handles close/navigation keys.

Issue #781 is covered by the selection-or-row note transpose rotary mapping delivered in the pattern-transform-shortcuts unit: the rotary mapping changes the selected note column on the current row when there is no pattern selection, and changes selected note columns when a pattern selection exists.

## Verification

- `luac -p PakettiExperimental_Verify.lua` passed
- Runtime verification in Renoise was not performed from this shell session
