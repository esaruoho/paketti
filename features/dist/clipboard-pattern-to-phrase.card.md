# Report Card — Clipboard Pattern to Phrase conversion

> Source: `features/clipboard-pattern-to-phrase.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want cross-editor clipboard paste to respect phrase sample-column semantics, So that copied pattern notes do not turn into wrong or same-sample phrase content.

**Grades:** @code-verified × 6 · @runtime-untested × 6 · @shipped × 6 · @stock × 1

**Scenarios: 7**


---


## 1. Pattern-sourced clipboard paste clears phrase sample selectors

`@shipped @code-verified @runtime-untested`


- Given Clipboard Slot 01 contains note-column data copied from the Pattern Editor
- When the user pastes that slot into the Phrase Editor
- Then Paketti writes notes, volume, panning, delay, and sample effects into the phrase
- And Paketti writes an empty phrase instrument/sample selector instead of the pattern's song instrument index

<sub>cite: PakettiClipboard.lua write_note_column_data_to_phrase (~line 104) — clears instrument_value for pattern-sourced phrase writes · PakettiClipboard.lua paste_phrase_from_clipboard (~line 1653) — routes normal Phrase Editor paste through the phrase-safe helper</sub>


## 2. Phrase-origin clipboard paste keeps explicit sample selectors

`@shipped @code-verified @runtime-untested`


- Given Clipboard Slot 01 contains note-column data copied from the Phrase Editor
- When the user pastes that slot back into the Phrase Editor
- Then Paketti preserves the phrase's explicit sample selector values

<sub>cite: PakettiClipboard.lua write_note_column_data_to_phrase (~line 104) — only changes data whose source_type is pattern</sub>


## 3. Phrase paste grows instead of clipping pasted rows

`@shipped @code-verified @runtime-untested`


- Given a phrase is shorter than the pasted clipboard rows would require
- When the user pastes clipboard data into the Phrase Editor
- Then Paketti grows the phrase length before writing rows
- And only the Renoise 512-line phrase limit can still clip the paste

<sub>cite: PakettiClipboard.lua prepare_phrase_clipboard_paste (~line 202) — expands phrase length on overflow, clamped to 512</sub>


## 4. Phrase paste reveals needed columns and sub-columns

`@shipped @code-verified @runtime-untested`


- Given clipboard data contains note columns, effect columns, or note sub-column values hidden in the destination phrase
- When the user pastes into the Phrase Editor without a selection-constrained paste mode
- Then Paketti expands visible phrase note and effect columns before writing
- And Paketti turns on volume, panning, delay, and sample-effect sub-columns when the clipboard content needs them

<sub>cite: PakettiClipboard.lua analyze_phrase_clipboard_payload (~line 134) — scans first source track for note/effect columns and note sub-column data · PakettiClipboard.lua prepare_phrase_clipboard_paste (~line 202) — raises visible phrase columns and sub-column visibility</sub>


## 5. Mixed pattern instruments are reported when pasted to a phrase

`@shipped @code-verified @runtime-untested`


- Given clipboard data copied from the Pattern Editor contains notes with multiple instrument values
- When the user pastes that data into the Phrase Editor
- Then Paketti clears those pattern instrument values for phrase safety
- And the status message warns that mixed pattern instruments were cleared

<sub>cite: PakettiClipboard.lua analyze_phrase_clipboard_payload (~line 134) — counts distinct pattern instrument references across the copied pattern payload · PakettiClipboard.lua prepare_phrase_clipboard_paste (~line 202) — returns a status warning when more than one pattern instrument reference was cleared</sub>


## 6. Effects-only phrase paste preserves existing notes

`@shipped @code-verified @runtime-untested`


- Given clipboard data contains only effect or sub-column values
- When the user pastes it into the Phrase Editor
- Then Paketti preserves existing phrase notes while writing the effect data

<sub>cite: PakettiClipboard.lua clipboard_has_only_effects (~line 239) — detects clipboard payloads without actual notes · PakettiClipboard.lua paste_phrase_from_clipboard (~line 1653) — passes preserve_notes into the phrase-safe writer</sub>


## 7. Pattern-target clipboard paste keeps pattern instrument values

`@stock`


- Given Clipboard Slot 01 contains note-column data
- When the user pastes that slot into the Pattern Editor
- Then Paketti keeps using Pattern Editor instrument-column semantics

<sub>cite: PakettiClipboard.lua paste_pattern_from_clipboard (~line 598) — pattern paste still writes through the generic note writer</sub>

