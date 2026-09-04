# =============================================================================
# WIKI PAGE / REPORT CARD: Repeater control from keys and MIDI
#
# WHAT THIS CARD SPAWNS:
#   codespace  - PakettiMidi.lua Repeater targeting, action commands, MIDI maps
#   thinkspace - repeater-control.session.md
#   areaspace  - OWNS: selected-track/master Repeater command and MIDI surfaces
#                MUST NOT TOUCH: existing Repeater value knob behavior and loader preset keybindings
#
# Innards linked back to this card (grep "repeater-control.feature"):
#   PakettiMidi.lua - PakettiFindOrInsertRepeater master-capable device lookup/insert
#   PakettiMidi.lua - PakettiRepeaterSetActive / ToggleActive / SetMode / SetDivision helpers
#   PakettiMidi.lua - PakettiRepeaterAddAction* and PakettiRepeaterAddPresetMidiMappings registrations
#
# SESSION:      repeater-control.session.md
# RESULT:       worktree
#
# WATCH: PakettiFindOrInsertRepeater PakettiRepeaterSetActive PakettiRepeaterToggleActive PakettiRepeaterSetMode PakettiRepeaterSetDivision PakettiRepeaterAddActionKeybindings PakettiRepeaterAddActionMidiMappings PakettiRepeaterAddPresetMidiMappings
#
# RESULT-LOG >> (auto-maintained by the report-card hooks - newest below)
#   2026-09-04  direct-commit  touched: PakettiFindOrInsertRepeater PakettiRepeaterSetActive PakettiRepeaterToggleActive PakettiRepeaterSetMode PakettiRepeaterSetDivision PakettiRepeaterAddActionKeybindings PakettiRepeaterAddActionMidiMappings PakettiRepeaterAddPresetMidiMappings
# =============================================================================

Feature: Repeater control from keys and MIDI
  As a live performer, I want Repeater controls available from keybindings and MIDI, So that repeat effects can be punched in without opening the device chain.

  @shipped @code-verified @runtime-untested
  Scenario: Selected-track Repeater actions can enable, bypass, toggle, set mode, step divisor, and toggle sync mode
    # cite: PakettiMidi.lua PakettiRepeaterAddActionKeybindings / PakettiRepeaterAddActionMidiMappings - registers selected-track action surface
    Given the user invokes a selected-track Repeater action
    When the selected track has no Repeater and the action needs an active device
    Then Paketti inserts the native Repeater on the selected track
    And the action updates the requested Repeater state

  @shipped @code-verified @runtime-untested
  Scenario: Master-track Repeater actions target the master track instead of the selected track
    # cite: PakettiMidi.lua PakettiRepeaterGetMasterTrack / PakettiRepeaterGetTargetTrack - resolves the master target
    Given the user invokes a Repeater Master action
    When Paketti needs a target track
    Then Paketti resolves the song's master track and applies the command there

  @shipped @code-verified @runtime-untested
  Scenario: Per-division MIDI buttons stamp or hold Repeater presets
    # cite: PakettiMidi.lua PakettiRepeaterAddPresetMidiMappings - registers direct and Hold mappings for each Even/Triplet/Dotted divisor preset
    Given a mapped MIDI button for a Repeater divisor and mode
    When the direct mapping is triggered
    Then Paketti sets that divisor and mode, or bypasses the Repeater if the same active preset is triggered again
    When the Hold mapping receives a non-zero absolute value followed by zero
    Then Paketti activates the preset on press and bypasses it on release

  @shipped @code-verified @runtime-untested
  Scenario: Free Divisor MIDI knob switches Repeater to Free mode before changing divisor
    # cite: PakettiMidi.lua PakettiRepeaterSetFreeDivisorFromMidi - maps 0..127 across the Repeater divisor list with mode value 1
    Given the Free Divisor MIDI mapping receives an absolute MIDI value
    When the target Repeater exists or can be inserted
    Then Paketti switches the Repeater to Free mode and maps the knob value to a divisor

  @stock
  Scenario: Existing Set Repeater Value knob mappings keep their selected-track behavior
    # cite: PakettiMidi.lua update_repeater_with_midi_value / get_time_division_from_midi - unchanged legacy knob path
    Given the user moves an existing Set Repeater Value knob mapping
    When the value is in the old OFF or divisor/mode range
    Then the existing selected-track knob path still handles it
