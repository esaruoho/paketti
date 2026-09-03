# Session: Reverse-Duplicate Instrument for Pattern Selections

## How To Get Back

- Transcript: `file:///Users/esaruoho/.codex/sessions/2026/09/03/rollout-2026-09-03T15-11-41-01a0672e-9575-7f92-b94b-2e38296ad49f.jsonl`
- Bundled transcript: `features/selection-reversed-instrument.transcript.jsonl`
- Readable transcript: `features/selection-reversed-instrument.transcript.md`
- Session ID: `01a0672e-9575-7f92-b94b-2e38296ad49f`
- Resume: `Codex --resume 01a0672e-9575-7f92-b94b-2e38296ad49f`
- Date: 2026-09-03
- Window: started 2026-09-03 15:11:41 EEST; issue #808 work began around 2026-09-03 16:28 EEST

## Request

Esa asked to implement GitHub issue #808, commit it, push it, comment on the issue, and close it as implemented.

Issue #808 requested one shortcut:

- check that a pattern selection exists
- duplicate the selected instrument
- reverse the duplicated instrument
- replace notes in the selection with the reversed instrument

## Implementation Notes

The existing `PakettiDuplicateAndReverseInstrument()` behavior already creates the reversed instrument copy, so the new work wraps that helper rather than duplicating the sample reversal code.

The new `PakettiDuplicateReverseInstrumentForSelection()` function:

- exits immediately when there is no `song.selection_in_pattern`
- exits before duplication if the selected instrument has no samples
- uses `selection_in_pattern_pro()` so selected track and column behavior matches existing Paketti selection tools
- retargets note events in the selected note columns and selected line range to the new reversed instrument index
- leaves effect columns and note order untouched

The user-facing entry points are:

- Shortcut action: `Pattern Editor:Paketti:Duplicate and Reverse Instrument for Selection`
- Menu entry: `Pattern Editor:Paketti:Instruments:Duplicate and Reverse Instrument for Selection`
- Dialog: none
- MIDI mapping: none added for this one-shortcut request

## Verification

Planned verification before commit:

- `luac -p PakettiSamples.lua`
- `luac -p PakettiMenuConfig.lua`
- `git diff --check`
- report-card generators

Runtime verification inside Renoise was not available from this shell, so the card is graded `@runtime-untested`.
