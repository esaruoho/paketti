# Pure Gherkin test extracted from features/clipboard-pattern-to-phrase.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/clipboard-pattern-to-phrase.feature

Feature: Clipboard Pattern to Phrase conversion
  As a Paketti user, I want cross-editor clipboard paste to respect phrase sample-column semantics, So that copied pattern notes do not turn into wrong or same-sample phrase content.

  @shipped @code-verified @runtime-untested
  Scenario: Pattern-sourced clipboard paste clears phrase sample selectors
    # cite: PakettiClipboard.lua write_note_column_data_to_phrase (~line 104) — clears instrument_value for pattern-sourced phrase writes
    # cite: PakettiClipboard.lua paste_phrase_from_clipboard (~line 1653) — routes normal Phrase Editor paste through the phrase-safe helper
    Given Clipboard Slot 01 contains note-column data copied from the Pattern Editor
    When the user pastes that slot into the Phrase Editor
    Then Paketti writes notes, volume, panning, delay, and sample effects into the phrase
    And Paketti writes an empty phrase instrument/sample selector instead of the pattern's song instrument index

  @shipped @code-verified @runtime-untested
  Scenario: Phrase-origin clipboard paste keeps explicit sample selectors
    # cite: PakettiClipboard.lua write_note_column_data_to_phrase (~line 104) — only changes data whose source_type is pattern
    Given Clipboard Slot 01 contains note-column data copied from the Phrase Editor
    When the user pastes that slot back into the Phrase Editor
    Then Paketti preserves the phrase's explicit sample selector values

  @shipped @code-verified @runtime-untested
  Scenario: Phrase paste grows instead of clipping pasted rows
    # cite: PakettiClipboard.lua prepare_phrase_clipboard_paste (~line 202) — expands phrase length on overflow, clamped to 512
    Given a phrase is shorter than the pasted clipboard rows would require
    When the user pastes clipboard data into the Phrase Editor
    Then Paketti grows the phrase length before writing rows
    And only the Renoise 512-line phrase limit can still clip the paste

  @shipped @code-verified @runtime-untested
  Scenario: Phrase paste reveals needed columns and sub-columns
    # cite: PakettiClipboard.lua analyze_phrase_clipboard_payload (~line 134) — scans first source track for note/effect columns and note sub-column data
    # cite: PakettiClipboard.lua prepare_phrase_clipboard_paste (~line 202) — raises visible phrase columns and sub-column visibility
    Given clipboard data contains note columns, effect columns, or note sub-column values hidden in the destination phrase
    When the user pastes into the Phrase Editor without a selection-constrained paste mode
    Then Paketti expands visible phrase note and effect columns before writing
    And Paketti turns on volume, panning, delay, and sample-effect sub-columns when the clipboard content needs them

  @shipped @code-verified @runtime-untested
  Scenario: Mixed pattern instruments are reported when pasted to a phrase
    # cite: PakettiClipboard.lua analyze_phrase_clipboard_payload (~line 134) — counts distinct pattern instrument references across the copied pattern payload
    # cite: PakettiClipboard.lua prepare_phrase_clipboard_paste (~line 202) — returns a status warning when more than one pattern instrument reference was cleared
    Given clipboard data copied from the Pattern Editor contains notes with multiple instrument values
    When the user pastes that data into the Phrase Editor
    Then Paketti clears those pattern instrument values for phrase safety
    And the status message warns that mixed pattern instruments were cleared

  @shipped @code-verified @runtime-untested
  Scenario: Effects-only phrase paste preserves existing notes
    # cite: PakettiClipboard.lua clipboard_has_only_effects (~line 239) — detects clipboard payloads without actual notes
    # cite: PakettiClipboard.lua paste_phrase_from_clipboard (~line 1653) — passes preserve_notes into the phrase-safe writer
    Given clipboard data contains only effect or sub-column values
    When the user pastes it into the Phrase Editor
    Then Paketti preserves existing phrase notes while writing the effect data

  @stock
  Scenario: Pattern-target clipboard paste keeps pattern instrument values
    # cite: PakettiClipboard.lua paste_pattern_from_clipboard (~line 598) — pattern paste still writes through the generic note writer
    Given Clipboard Slot 01 contains note-column data
    When the user pastes that slot into the Pattern Editor
    Then Paketti keeps using Pattern Editor instrument-column semantics
