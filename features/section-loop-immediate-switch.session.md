# Session: Section Loop Switches Trigger Immediately

## How To Get Back

- Transcript: `file:///Users/esaruoho/.codex/sessions/2026/09/03/rollout-2026-09-03T15-11-41-01a0672e-9575-7f92-b94b-2e38296ad49f.jsonl`
- Bundled transcript: `features/section-loop-immediate-switch.transcript.jsonl`
- Readable transcript: `features/section-loop-immediate-switch.transcript.md`
- Session ID: `01a0672e-9575-7f92-b94b-2e38296ad49f`
- Resume: `Codex --resume 01a0672e-9575-7f92-b94b-2e38296ad49f`
- Date: 2026-09-03
- Window: issue #675 work began after issue #808 was completed in the same session

## Request

Esa asked to do the work for GitHub issue #675 and comment on it.

Issue #675 requested immediate next/previous section switching:

- If the section at the cursor is not the active loop range, enable looping for the current section and immediately switch to the first sequence in that section.
- If the section at the cursor is already the active loop range, enable looping for the next or previous section and immediately switch to that section's first sequence.

## Implementation Notes

The existing `tknaAddLoopAndScheduleSection()` already handled the scheduled version of the current-section action. The new implementation adds `tknaSetSectionLoopAndSwitchImmediately(direction)` beside it, with wrappers for next and previous.

The new helper:

- gathers section starts from Renoise's pattern sequencer
- treats sequence 1 as the first section start when no explicit marker exists there
- finds the section containing `song.selected_sequence_index`
- compares the exact current section bounds against `transport.loop_sequence_range`
- sets the current section loop and triggers its first sequence when it was not already looping
- moves to the adjacent section, sets its loop, selects it, and calls `transport:trigger_sequence()` when the current section was already looping

User-facing entry points:

- Shortcut: `Global:Paketti:Set Section Loop and Switch Section Immediately (Next)`
- Shortcut: `Global:Paketti:Set Section Loop and Switch Section Immediately (Previous)`
- MIDI: `Paketti:Set Section Loop and Switch Section Immediately (Next) [Trigger]`
- MIDI: `Paketti:Set Section Loop and Switch Section Immediately (Previous) [Trigger]`
- Menu: `Pattern Sequencer:Paketti:Sequences/Sections:Set Section Loop and Switch Immediately (Next)`
- Menu: `Pattern Sequencer:Paketti:Sequences/Sections:Set Section Loop and Switch Immediately (Previous)`
- Dialog: none

## Verification

Verification run before commit:

- `luac -p PakettiTkna.lua`
- `luac -p PakettiMenuConfig.lua`
- `luac -p PakettiMIDIMappings.lua`
- `xmllint --noout PakettiMIDIMappingCategories.xml`

Runtime verification inside Renoise was not available from this shell, so the feature card is graded `@runtime-untested`.
