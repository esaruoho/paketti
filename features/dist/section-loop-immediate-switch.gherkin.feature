# Pure Gherkin test extracted from features/section-loop-immediate-switch.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/section-loop-immediate-switch.feature

Feature: Section loop switches trigger immediately
  As a Paketti live performer, I want next/previous section loop commands that switch immediately, So that a footswitch can move a song between section loops without waiting for scheduled playback.

  @shipped @built @code-verified @runtime-untested
  Scenario: Next command starts the current section when it is not already looped
    # cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately (~line 2028) - compares current section bounds against transport.loop_sequence_range before deciding the target ; commit worktree
    Given the selected sequence is inside a section
    And the transport loop range is not exactly the current section
    When the user invokes "Global:Paketti:Set Section Loop and Switch Section Immediately (Next)"
    Then Paketti sets the loop range to the current section
    And immediately triggers the first sequence of the current section

  @shipped @built @code-verified @runtime-untested
  Scenario: Next command advances when the current section is already looped
    # cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately (~line 2070) - advances from the current section to the next section only when the current section is already looping ; commit worktree
    Given the selected sequence is inside a section
    And the transport loop range exactly matches that section
    When the user invokes the immediate next section-loop command
    Then Paketti sets the loop range to the next section
    And immediately triggers the first sequence of the next section

  @shipped @built @code-verified @runtime-untested
  Scenario: Previous command retreats when the current section is already looped
    # cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately (~line 2077) - retreats from the current section to the previous section only when the current section is already looping ; commit worktree
    Given the selected sequence is inside a section
    And the transport loop range exactly matches that section
    When the user invokes "Global:Paketti:Set Section Loop and Switch Section Immediately (Previous)"
    Then Paketti sets the loop range to the previous section
    And immediately triggers the first sequence of the previous section

  @shipped @built @code-verified @runtime-untested
  Scenario: Commands are available from shortcuts, MIDI, and Pattern Sequencer menus
    # cite: PakettiTkna.lua keybinding and MIDI registrations (~line 2112) - registers next/previous shortcut and MIDI trigger mappings ; commit worktree
    # cite: PakettiMenuConfig.lua menu registrations (~line 4158) - exposes next/previous immediate switch actions in the Pattern Sequencer menu ; commit worktree
    Given the Paketti tool is installed
    When Renoise lists Paketti section-loop actions
    Then the two global shortcut actions are available
    And the two MIDI trigger mappings are available
    And the two Pattern Sequencer menu entries are available

  @stock
  Scenario: Scheduled section command remains separate
    # cite: PakettiTkna.lua tknaAddLoopAndScheduleSection (~line 1975) - existing scheduled-section command remains registered and unchanged ; commit worktree
    Given the user invokes "Global:Paketti:Set Section Loop and Schedule Section"
    When the current section is found
    Then Paketti still uses scheduled playback instead of immediate trigger switching
