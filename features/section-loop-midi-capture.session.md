# Section Loop and MIDI Capture Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-04

## User Request

Esa asked to implement GitHub issues #675, #653, and #546.

## Implementation Notes

#675 already had immediate switching code. It was retained and linked into this card: the first trigger loops and starts the current section; subsequent triggers move to the adjacent section and trigger it immediately.

#653 had a partial implementation that always looped and scheduled the current section. It now checks whether the current section is already the active loop, targets the next section when it is, and uses `add_scheduled_sequence` for the requested schedule behavior.

#546 now has per-parameter MIDI capture triggers that write the existing selected-device parameter value to automation without requiring a knob movement. A Track Automation menu command is also available when the selected automation parameter belongs to the selected device.

## Verification

- `luac -p PakettiTkna.lua` passed
- `luac -p PakettiMidi.lua` passed
- `luac -p PakettiMenuConfig.lua` passed
- Scoped `git diff --check` passed
- Runtime verification in Renoise was not performed from this shell session
