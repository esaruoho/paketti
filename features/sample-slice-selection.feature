# =============================================================================
# WIKI PAGE / REPORT CARD: Sample slice selection range
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiSlice.lua selected-slice boundary helper and Sample Editor menu entry
#   thinkspace — sample-slice-selection.session.md
#   areaspace  — OWNS: sample-buffer selection range changes for the current slice
#                MUST NOT TOUCH: slice marker creation/deletion, sample audio data, or pattern notes
#
# Innards linked back to this card (grep "features/sample-slice-selection.feature"):
#   PakettiSlice.lua - PakettiSelectCurrentSliceRange finds slice boundaries and selects the sample range
#   PakettiMenuConfig.lua - Sample Editor Wipe&Slice menu entry exposes the command
#
# SESSION:      sample-slice-selection.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: PakettiSelectCurrentSliceRange
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: PakettiSelectCurrentSliceRange
# =============================================================================

Feature: Sample slice selection range
  As a Sample Editor user, I want one command that selects the current slice boundaries, So that loop and beat-sync work can start from the exact slice range.

  @shipped @code-verified @runtime-untested
  Scenario: Select the current slice range
    # cite: PakettiSlice.lua PakettiSelectCurrentSliceRange (~line 82) — maps selected/current slice to buffer selection
    Given the selected sample has sample data and slice markers
    When the user triggers Select Current Slice Range
    Then Paketti sets the sample buffer selection start and end to that slice's boundaries
    And the last slice ends at the sample buffer end

  @shipped @code-verified @runtime-untested
  Scenario: Expose the slice range command
    # cite: PakettiSlice.lua command registrations (~line 129) — keybinding and MIDI mapping
    # cite: PakettiMenuConfig.lua Sample Editor Wipe&Slice menu (~line 2190) — menu entry
    Given Paketti has loaded its Sample Editor tools
    When the user looks for slice selection commands
    Then the command is available as Sample Editor and Global keybindings, MIDI mapping, and Sample Editor menu entry

  @stock
  Scenario: Existing slice marker deletion remains separate
    # cite: PakettiSlice.lua pakettiDeleteSliceMarkersInSelection (~line 1) — pre-existing deletion command
    Given the user triggers Delete Slice Markers in Selection
    When Paketti deletes slice markers
    Then the new slice selection helper is not involved
