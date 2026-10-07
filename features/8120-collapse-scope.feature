# WHAT THIS CARD SPAWNS:
# codespace: PakettiEightOneTwenty.lua dialog-local Collapse checkbox and this card/session/bundle
# thinkspace: 8120-collapse-scope.session.md
# areaspace: Collapse control construction scope; preserve notifier and stored preference
# SESSION: 8120-collapse-scope.session.md
# RESULT: Worktree fix; no commit, push or PR. Files: PakettiEightOneTwenty.lua, PLAN.md, card/session/transcript bundle, INDEX.md and generated views.
# WATCH: pakettiEightSlotsByOneTwentyDialog collapse_checkbox
# RESULT-LOG >>
#   2026-10-07  direct-commit  touched: collapse_checkbox
Feature: Construct the Collapse checkbox in its consuming dialog scope
  @code-verified @runtime-untested
  Scenario: Resolve the relocated Collapse control locally
    # cite: PakettiEightOneTwenty.lua pakettiEightSlotsByOneTwentyDialog collapse_checkbox controller_follow_row
    Given the Collapse control appears in the controller follow row
    When the dialog constructs that row
    Then collapse_checkbox refers to the checkbox declared earlier in the same function
    And the Lua source passes luac syntax validation

  @built @runtime-untested
  Scenario: Preserve Collapse behavior
    # cite: PakettiEightOneTwenty.lua collapse_checkbox PakettiGrooveboxCollapseFirstEightTracks
    Given the checkbox starts with the stored Collapse preference
    When the user changes its value
    Then the existing helper changes the first eight tracks' collapse state
    And the new value updates the Collapse preference
