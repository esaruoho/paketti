# =============================================================================
# WIKI PAGE / REPORT CARD: Section loop switches trigger immediately
#
# WHAT THIS CARD SPAWNS:
#   codespace  - PakettiTkna.lua section-loop immediate switch commands, PakettiMenuConfig.lua menu entries, MIDI mapping catalog entries
#   thinkspace - section-loop-immediate-switch.session.md (the conversation that produced it)
#   areaspace  - OWNS: next/previous commands that set a whole-section loop and trigger the first sequence immediately
#                MUST NOT TOUCH: scheduled-section commands, per-pattern section scheduling, or sequence-selection expansion tools
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "section-loop-immediate-switch"):
#   PakettiTkna.lua - tknaSetSectionLoopAndSwitchImmediately chooses current/adjacent section loop range and triggers the first sequence
#   PakettiMenuConfig.lua - Pattern Sequencer menu entries expose next/previous immediate switch commands
#   PakettiMIDIMappings.lua and PakettiMIDIMappingCategories.xml - MIDI mapping catalog entries for the two trigger mappings
#
# Commit log:   worktree  issue #675 implementation, not committed yet
# SESSION:      section-loop-immediate-switch.session.md
# RESULT:       Feature delivery worktree (direct local edit, no PR); card worktree
#
# WATCH: tknaSetSectionLoopAndSwitchImmediately tknaSetSectionLoopAndSwitchImmediatelyNext tknaSetSectionLoopAndSwitchImmediatelyPrevious
#
# RESULT-LOG >> (auto-maintained by the report-card hooks - newest below)
#   2026-09-03  direct-commit  touched: tknaSetSectionLoopAndSwitchImmediately tknaSetSectionLoopAndSwitchImmediatelyNext tknaSetSectionLoopAndSwitchImmediatelyPrevious
# =============================================================================

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
