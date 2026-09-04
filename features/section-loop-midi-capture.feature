# =============================================================================
# WIKI PAGE / REPORT CARD: Section loop and MIDI capture
#
# WHAT THIS CARD SPAWNS:
#   codespace  — section-loop scheduling state machine and selected-device value capture
#   thinkspace — section-loop-midi-capture.session.md
#   areaspace  — OWNS: immediate/scheduled section actions and static MIDI automation capture
#                MUST NOT TOUCH: pattern data or unrelated transport controls
#
# Innards linked back to this card (grep "features/section-loop-midi-capture.feature"):
#   PakettiTkna.lua - tknaAddLoopAndScheduleSection and immediate section switch
#   PakettiMidi.lua - selected device automation value capture mappings
#   PakettiMenuConfig.lua - configured Track Automation capture menu
#
# SESSION:      section-loop-midi-capture.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: tknaAddLoopAndScheduleSection tknaSetSectionLoopAndSwitchImmediately MidiSelectedAutomationParameter PakettiCaptureSelectedDeviceAutomationParameter
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: PakettiCaptureSelectedDeviceAutomationParameter
# =============================================================================

Feature: Section loop and MIDI capture
  As a live Paketti user, I want section loop actions to advance predictably and static MIDI values to be recordable, So that footswitches and controllers work without manual corrective steps.

  @shipped @code-verified @runtime-untested
  Scenario: Schedule the current section and advance on repeated triggers
    # cite: PakettiTkna.lua tknaAddLoopAndScheduleSection — detects whether the current section is already looped, then targets current or next section
    Given the cursor is inside a defined section
    When the schedule-section action is triggered
    Then a non-looping current section is looped and its first sequence is added to the schedule
    And a currently-looping section advances to the next section and adds its first sequence to the schedule

  @shipped @code-verified @runtime-untested
  Scenario: Switch immediately between sections
    # cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately — loops the current section first, then immediately triggers adjacent sections
    Given the cursor is inside a defined section
    When the immediate next or previous action is triggered
    Then a non-looping current section becomes the active loop and starts immediately
    And a looping current section switches immediately to the adjacent section

  @shipped @code-verified @runtime-untested
  Scenario: Capture a static selected-device parameter value
    # cite: PakettiMidi.lua PakettiCaptureSelectedDeviceAutomationParameter — writes the existing parameter value at the cursor or playhead
    Given a selected device parameter is automatable and its controller has not moved
    When the matching Capture Selected Device Automation Parameter MIDI trigger is received
    Then the current parameter value is written to the selected automation envelope
    And the write uses the playhead when playback and follow mode are active, otherwise the cursor
