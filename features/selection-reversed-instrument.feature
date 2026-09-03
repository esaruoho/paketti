# =============================================================================
# WIKI PAGE / REPORT CARD: Reverse-duplicate instrument for pattern selections
#
# WHAT THIS CARD SPAWNS:
#   codespace  - PakettiSamples.lua selection-aware reverse duplicate command, PakettiMenuConfig.lua menu entry
#   thinkspace - selection-reversed-instrument.session.md (the conversation that produced it)
#   areaspace  - OWNS: one Pattern Editor action that duplicates the selected instrument reversed and retargets selected note events
#                MUST NOT TOUCH: normal duplicate-and-reverse behavior, note order reversal, or whole-song instrument replacement
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "selection-reversed-instrument"):
#   PakettiSamples.lua - PakettiDuplicateReverseInstrumentForSelection validates a pattern selection, duplicates the selected instrument reversed, and retargets selected notes
#   PakettiMenuConfig.lua - Pattern Editor Instruments menu exposes the selection-aware command
#
# Commit log:   worktree  issue #808 implementation, not committed yet
# SESSION:      selection-reversed-instrument.session.md
# RESULT:       Feature delivery worktree (direct local edit, no PR); card worktree
#
# WATCH: PakettiDuplicateReverseInstrumentForSelection
#
# RESULT-LOG >> (auto-maintained by the report-card hooks - newest below)
#   2026-09-03  direct-commit  touched: PakettiDuplicateReverseInstrumentForSelection
# =============================================================================

Feature: Reverse-duplicate instrument for pattern selections
  As a Paketti user, I want one Pattern Editor action that makes a reversed copy of the current instrument and points my selected notes at it, So that I can turn a selected phrase into a reversed-instrument variation without manual instrument reassignment.

  @shipped @built @code-verified @runtime-untested
  Scenario: Active pattern selection is retargeted to the reversed duplicate
    # cite: PakettiSamples.lua PakettiDuplicateReverseInstrumentForSelection (~line 2603) - calls the existing reverse duplicate helper, then sets selected note instrument values to the new instrument ; commit worktree
    Given a pattern selection is active
    And the selected instrument contains samples
    When the user invokes "Pattern Editor:Paketti:Duplicate and Reverse Instrument for Selection"
    Then Paketti creates a reversed duplicate of the selected instrument
    And note events inside the selected note columns and selected line range use the reversed duplicate instrument number

  @shipped @built @code-verified @runtime-untested
  Scenario: Missing pattern selection is rejected before duplication
    # cite: PakettiSamples.lua PakettiDuplicateReverseInstrumentForSelection (~line 2603) - checks song.selection_in_pattern before duplicating ; commit worktree
    Given there is no active pattern selection
    When the user invokes the selection-aware reverse duplicate command
    Then Paketti shows "No selection in the pattern."
    And no instrument is duplicated

  @shipped @built @code-verified @runtime-untested
  Scenario: Command is discoverable from Pattern Editor
    # cite: PakettiSamples.lua keybinding registration (~line 2662) - registers the Pattern Editor shortcut action ; commit worktree
    # cite: PakettiMenuConfig.lua menu registration (~line 2821) - registers the Pattern Editor Instruments menu item ; commit worktree
    Given the Paketti tool is installed
    When Renoise lists Pattern Editor shortcuts and menus
    Then the shortcut action is named "Pattern Editor:Paketti:Duplicate and Reverse Instrument for Selection"
    And the menu item is "Pattern Editor:Paketti:Instruments:Duplicate and Reverse Instrument for Selection"

  @stock
  Scenario: Existing global duplicate-and-reverse command stays available
    # cite: PakettiSamples.lua PakettiDuplicateAndReverseInstrument (~line 2506) - unchanged existing global command ; commit worktree
    Given any selected instrument with samples
    When the user invokes "Global:Paketti:Duplicate and Reverse Instrument"
    Then Paketti still duplicates the instrument, reverses the sample data, and selects the reversed copy
