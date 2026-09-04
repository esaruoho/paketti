# =============================================================================
# WIKI PAGE / REPORT CARD: Quick edit navigation commands
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiInstrumentBox.lua chunk stepping and PakettiPatternEditor.lua edit transforms
#   thinkspace — quick-edit-navigation.session.md
#   areaspace  — OWNS: instrument chunk selection, delay increment commands, triplet quantize
#                MUST NOT TOUCH: sample buffers, device chains, or unrelated pattern transforms
#
# Innards linked back to this card (grep "features/quick-edit-navigation.feature"):
#   PakettiInstrumentBox.lua - select_chunk advances inside a fixed 16-instrument chunk
#   PakettiPatternEditor.lua - PakettiDelayColumnModifier MIDI increment mappings and triplet quantizer
#
# SESSION:      quick-edit-navigation.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: select_chunk PakettiDelayColumnModifier PakettiQuantizeSelectionToTriplets
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: PakettiDelayColumnModifier PakettiQuantizeSelectionToTriplets
# =============================================================================

Feature: Quick edit navigation commands
  As a Paketti user, I want repeated shortcuts to move editing state without modal setup, So that common tracker edits are fast and reversible enough to test live.

  @shipped @code-verified @runtime-untested
  Scenario: Repeat Select Chunk to advance inside that chunk
    # cite: PakettiInstrumentBox.lua select_chunk (~line 942) — advances within the requested 16-instrument chunk
    Given the cursor is already on an instrument inside a requested chunk such as 20-F0
    When the user triggers the same Select Chunk command again
    Then Paketti selects the next instrument inside that chunk
    And triggering past the chunk end wraps back to the chunk start

  @shipped @code-verified @runtime-untested
  Scenario: Increment delay values from MIDI without overwriting them
    # cite: PakettiPatternEditor.lua PakettiDelayColumnModifier (~line 4801) — adjusts selected delay values by a delta
    # cite: PakettiPatternEditor.lua delay MIDI mappings (~line 4872) — exposes trigger and relative-knob increment mappings
    Given the user has a note column or pattern selection
    When the user triggers a delay increment/decrement MIDI mapping
    Then Paketti adds the delta to existing delay values and clamps them to 00-FF
    And the existing absolute delay-value mapping remains separate

  @shipped @code-verified @runtime-untested
  Scenario: Quantize selected notes onto triplet timing
    # cite: PakettiPatternEditor.lua PakettiQuantizeSelectionToTriplets (~line 4923) — moves note columns to nearest triplet tick
    Given the user has selected note-column content in the Pattern Editor
    When the user triggers Quantize Selection to Triplets
    Then Paketti moves each note to the nearest third-of-beat timing using row and delay values
    And collisions are moved into an empty note column or restored to their source column

  @stock
  Scenario: Existing direct chunk and delay controls remain available
    # cite: PakettiInstrumentBox.lua chunk binding loop (~line 972) — existing Select Chunk command family
    # cite: PakettiPatternEditor.lua delay keybindings (~line 4868) — existing delay delta keybindings
    Given the existing Select Chunk and Delay Column keybindings are loaded
    When the user triggers them
    Then Paketti still exposes the same command names
