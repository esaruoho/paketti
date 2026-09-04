# Issue Follow-up Utilities Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-04

## User Request

Esa asked to implement issues #793, #686, #695, and #557. The #686 request specifically required eSpeak visibility to be part of Paketti Menu Config. The user also requested comments after completion, especially a test request to tkna91 for #557.

## Implementation Notes

Issue #793 now reveals the phrase delay column and the selected sequencer track delay column when delay nudge runs.

Issue #686 adds an `eSpeak` category to Paketti Menu Config and gates the eSpeak menu entries behind it.

Issue #695 adds selected automation reversal. It mirrors point times within the selected automation range, or the full pattern when no range is selected, while retaining points outside the range.

Issue #557 adds serialized per-line eSpeak generation. Instrument mode creates one instrument per non-empty line. Drum-kit mode creates one instrument with one-key samples mapped upward from C-2. Both modes use one ProcessSlicer worker so rendering and sample loading do not overlap.

## Verification

- `luac -p` passed for PakettiPhraseEditor.lua, PakettiAutomationCurves.lua, Paketti0G01_Loader.lua, PakettiMenuConfig.lua, and PakettieSpeak.lua
- Runtime verification in Renoise was not performed from this shell session
