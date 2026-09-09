# Clipboard Pattern to Phrase Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-09
- Note: session file created during live implementation; click-back can be backfilled by content search for `write_note_column_data_to_phrase`.

## User Request

Esa asked whether Paketti already had an answer for a Renoise user report: copying notes from the Pattern Editor into the Phrase Editor could make the pasted content play as the same note/sample because the sample column behaves differently in phrases.

After the audit identified that the direct `PakettiPhraseWorkflow.lua` Pattern-to-Phrase features already clear pattern instrument values, Esa asked to fix the generic Paketti clipboard cross-editor path as well.

## Implementation Notes

`PakettiClipboard.lua` already preserves complete note-column payloads for same-domain clipboard use. That includes `instrument_value`, which is correct for Pattern-to-Pattern and Phrase-to-Phrase paste.

The cross-editor case is different. In a pattern, `instrument_value` addresses a song instrument. In a phrase, the same field addresses a sample inside the selected instrument. Pasting the value raw can turn a copied song instrument number into an unintended phrase sample selector.

The fix adds `write_note_column_data_to_phrase()`. When the clipboard data has `source_type == "pattern"`, the helper copies note, volume, panning, delay, and sample-effect values, but forces `instrument_value = 255` so Renoise leaves the phrase sample selector empty and resolves playback through the instrument/keyzone context. When the clipboard data came from a phrase, the helper delegates unchanged to the generic note writer so explicit phrase sample selectors keep working.

All Phrase Editor clipboard paste sinks now use the helper:

- normal paste
- paste by edit-step
- mix-paste
- flood fill
- wonkified paste
- transposed paste
- swap with phrase selection

Pattern-target clipboard paste was left untouched.

## Verification

Static verification was performed from the shell. Runtime verification inside Renoise was not performed in this session.
