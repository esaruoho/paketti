# Pure Gherkin test extracted from features/note-off-cleanup.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/note-off-cleanup.feature

Feature: Delete note-offs while preserving neighboring data
  @sim-verified @runtime-untested
  Scenario Outline: Remove OFFs only in the requested scope
    # cite: PakettiPatternEditor.lua PakettiDeleteNoteOffs
    Given note-offs in visible and hidden columns across used and unused patterns
    When I invoke Delete Note Offs in <scope>
    Then only OFF note values in that scope become empty
    And notes, instruments, volume, panning, delay and effects are preserved
    Examples:
      | scope |
      | Track |
      | Pattern |
      | Track (Whole Song) |
      | Song |

  @sim-verified @runtime-untested
  Scenario: Cleanup commands are accessible and repeat safe
    # cite: PakettiPatternEditor.lua PakettiDeleteNoteOffs registration block
    Given the four cleanup commands
    When I use their menu, keybinding or trigger MIDI mapping
    Then the requested scope is processed with an undo description and deletion count
    And repeated key events and non-trigger MIDI messages do nothing
    And selected group, master and send tracks are rejected for track-only scopes

  @built @runtime-untested
  Scenario: Credit the source idea
    # cite: PakettiMainMenuEntries.lua IDEAS
    Given the Ideas and Thanks dialog
    When I read Ideas provided by
    Then Phaos appears in the list
