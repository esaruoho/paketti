# =============================================================================
# WIKI PAGE / REPORT CARD: Clipboard Pattern to Phrase conversion
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiClipboard.lua phrase-target clipboard paste helpers
#   thinkspace — clipboard-pattern-to-phrase.session.md
#   areaspace  — OWNS: cross-editor clipboard writes from Pattern Editor slots into Phrase Editor note columns
#                MUST NOT TOUCH: same-editor phrase sample selection, pattern-target paste semantics, native Renoise clipboard
#
# Innards linked back to this card (grep "features/clipboard-pattern-to-phrase.feature"):
#   PakettiClipboard.lua - write_note_column_data_to_phrase clears pattern instrument values for phrase targets
#   PakettiClipboard.lua - paste_phrase_from_clipboard and related phrase paste sinks route note writes through the helper
#
# SESSION:      clipboard-pattern-to-phrase.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: write_note_column_data_to_phrase paste_phrase_from_clipboard paste_phrase_by_editstep mix_paste_phrase_from_clipboard flood_fill_phrase_from_clipboard wonked_paste_phrase_from_clipboard transposed_paste_phrase_from_clipboard swap_phrase_selection_with_clipboard
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-09  direct-commit  touched: write_note_column_data_to_phrase
# =============================================================================

Feature: Clipboard Pattern to Phrase conversion
  As a Paketti user, I want cross-editor clipboard paste to respect phrase sample-column semantics, So that copied pattern notes do not turn into wrong or same-sample phrase content.

  @shipped @code-verified @runtime-untested
  Scenario: Pattern-sourced clipboard paste clears phrase sample selectors
    # cite: PakettiClipboard.lua write_note_column_data_to_phrase (~line 104) — clears instrument_value for pattern-sourced phrase writes
    # cite: PakettiClipboard.lua paste_phrase_from_clipboard (~line 1525) — routes normal Phrase Editor paste through the phrase-safe helper
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

  @stock
  Scenario: Pattern-target clipboard paste keeps pattern instrument values
    # cite: PakettiClipboard.lua paste_pattern_from_clipboard (~line 598) — pattern paste still writes through the generic note writer
    Given Clipboard Slot 01 contains note-column data
    When the user pastes that slot into the Pattern Editor
    Then Paketti keeps using Pattern Editor instrument-column semantics
