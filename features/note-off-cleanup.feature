# WIKI PAGE / REPORT CARD: Preserve data when deleting note-offs
# WHAT THIS CARD SPAWNS:
# codespace: PakettiPatternEditor.lua, PakettiMainMenuEntries.lua, tests/note-off-cleanup.lua
# thinkspace: note-off-cleanup.session.md
# areaspace: removal-only pattern commands and Phaos Ideas credit; existing insertion/toggles unchanged.
# SESSION: note-off-cleanup.session.md
# RESULT: Local working-tree change; no commit, push or PR.
# Files: source modules, test, PLAN.md, changelog, card/session/transcript and generated views.
# WATCH: PakettiDeleteNoteOffs PakettiClearPatternTrackNoteOffs
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: PakettiDeleteNoteOffs PakettiClearPatternTrackNoteOffs
#   2026-10-06  direct-commit  touched: PakettiClearPatternTrackNoteOffs
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
