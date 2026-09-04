# =============================================================================
# WIKI PAGE / REPORT CARD: Execute configurable shell commands
#
# WHAT THIS CARD SPAWNS:
#   codespace  - PakettiExecute.lua command slots, Paketti0G01_Loader.lua preference schema,
#                PakettiMenuConfig.lua entry, keybinding presets, and Experimental manual
#   thinkspace - execute-command-slots.session.md (the conversation and implementation audit)
#   areaspace  - OWNS: 128 user-configured os.execute slots and selected-sample export via $s
#                MUST NOT TOUCH: unrelated launchers, shell safety policy, or other sample exporters
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "execute-command-slots"):
#   PakettiExecute.lua - 128 slots, dialog, os.execute dispatch, and $s selected-range export
#   Paketti0G01_Loader.lua - persistent Slot001..Slot128 label/command preferences plus legacy migration fields
#   PakettiMenuConfig.lua - Tools:Paketti:Execute Commands... menu entry
#   KeyBindings/*.xml - first ten command-slot preset assignments
#   manual/Experimental.md - user-facing command-slot, shortcut, MIDI, and $s documentation
#
# Commit log:   pending until implementation commit
# SESSION:      execute-command-slots.session.md
# RESULT:       Feature delivery pending (direct push, no PR); card pending
#
# WATCH: PakettiCreateExecutePreferences PakettiExecuteRunCommand PakettiExecuteRunSlot PakettiExecuteShowDialog export_selected_range command_with_selected_sample
#
# RESULT-LOG >> (auto-maintained by the report-card hooks - newest below)
# =============================================================================

Feature: Execute configurable shell commands
  As a Paketti user, I want labeled shell-command slots, So that keybindings and MIDI controls can launch scripts or external tools.

  @shipped @built @code-verified @runtime-untested
  Scenario: 128 labeled command slots persist independently
    # cite: Paketti0G01_Loader.lua PakettiCreateExecutePreferences (~line 176) and PakettiExecute.lua slot_key/get_slot_label/get_slot_command (~lines 33-64) - creates persistent label and command fields for Slot001 through Slot128
    Given Paketti preferences are loaded
    When the user edits any execute-command slot label and command
    Then the label and command are stored independently for that slot
    And slots 001 through 128 are available

  @shipped @built @code-verified @runtime-untested
  Scenario: Dialog edits and runs the selected slot
    # cite: PakettiExecute.lua PakettiExecuteShowDialog (~line 267) and PakettiExecuteRunCommand (~line 226) - presents the selected slot and invokes os.execute with its configured command
    Given the Execute Commands dialog is open
    When the user selects a slot, enters a label and command, and presses Run
    Then Paketti saves the fields and executes the configured command
    And Browse, Clear, and Close controls remain available

  @shipped @built @code-verified @runtime-untested
  Scenario: Shortcut and MIDI mappings trigger every slot
    # cite: PakettiExecute.lua registration loop (~lines 392-411) - registers global shortcut actions and MIDI trigger mappings for slots 001 through 128
    Given the Paketti tool is installed
    When Renoise lists Paketti execute-command actions
    Then a global shortcut exists for each command slot
    And a MIDI trigger mapping exists for each command slot

  @shipped @built @code-verified @runtime-untested
  Scenario: Selected sample range is exported through the $s placeholder
    # cite: PakettiExecute.lua export_selected_range (~line 150) and command_with_selected_sample (~line 211) - writes the current sample selection to a temporary WAV and exports shell variable s before execution
    Given a sample selection exists and a configured command contains $s
    When the user runs that command slot
    Then Paketti exports the selected range as a temporary WAV
    And the shell command receives its path through variable s

  @shipped @built @code-verified @runtime-untested
  Scenario: Existing ten-slot launch-app preferences remain migratable
    # cite: PakettiExecute.lua legacy_key/migrate_legacy_slot (~lines 52-64) and Paketti0G01_Loader.lua legacy App01..App10 fields (~lines 185-190) - migrates old app slots into the first ten command slots
    Given an older Paketti preferences file contains App01 through App10
    When a new execute-command slot is read
    Then the old application and argument values are converted into the corresponding command slot

  @shipped @built @code-verified @runtime-untested
  Scenario: User-facing menu and manual expose the feature
    # cite: PakettiMenuConfig.lua Execute Commands menu entry (~line 463) and manual/Experimental.md Execute Commands (~line 14673) - exposes the dialog and documents shortcuts, MIDI mappings, and examples
    Given the Paketti menu is enabled
    When the user opens Tools:Paketti
    Then Execute Commands... opens the configuration dialog
    And the manual describes the command-slot workflow

  @stock
  Scenario: Other external-application and sample workflows remain separate
    # cite: PakettiExecute.lua legacy fields and surrounding Paketti tools - this feature does not replace unrelated launchers or sample-export commands
    Given the user invokes an unrelated Paketti tool
    When that tool handles its own external process or sample export
    Then its existing command path remains independent of the execute-command slots
