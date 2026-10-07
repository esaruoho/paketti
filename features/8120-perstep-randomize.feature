# WHAT THIS CARD SPAWNS:
# codespace: PakettiEightOneTwenty.lua row and global Per-Step sample randomizers
# thinkspace: 8120-perstep-randomize.session.md and transcript bundle
# areaspace: Per-Step sample selectors only; preserve gates, Yxx and Single sample choices
# SESSION: 8120-perstep-randomize.session.md
# RESULT: Worktree delivery; no commit, push or PR. Files: PakettiEightOneTwenty.lua, PLAN.md, card/session/transcript bundle and generated card views.
# WATCH: PakettiEightOneTwentyRandomizePerStepRow PakettiEightOneTwentyRandomizeAllPerStep PakettiEightOneTwentyApplyStepMode
# RESULT-LOG >>
#   2026-10-07  direct-commit  touched: PakettiEightOneTwentyRandomizePerStepRow PakettiEightOneTwentyRandomizeAllPerStep
Feature: Randomize Groovebox 8120 per-step sample choices
  @code-verified @runtime-untested
  Scenario: Randomize one row's sample choices
    # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyRandomizePerStepRow and Randomize Per-Step button
    Given Per-Step mode is enabled and the row instrument contains samples
    When the user clicks Randomize Per-Step after that row's selectors
    Then every displayed selector receives a random sample number from 1 through the instrument sample count capped at 120
    And selector text and step_samples agree
    And updates are batched and the row prints once
    And step gates and Yxx settings remain unchanged
    And empty instruments are skipped

  @code-verified @runtime-untested
  Scenario: Randomize all rows only in Per-Step mode
    # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyRandomizeAllPerStep and PakettiEightOneTwentyApplyStepMode
    Given the dialog is open
    When the user selects Per-Step mode
    Then the global Random Per-Steps button is visible
    And clicking it randomizes sample choices for all rows with samples
    When the user selects Single mode
    Then the global button is hidden
    And both randomization functions refuse to change per-step samples

  @code-verified @runtime-untested
  Scenario: Support all displayed step counts
    # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyRandomizePerStepRow
    Given the dialog displays 8, 16 or 32 steps
    When Per-Step randomization runs
    Then it updates every displayed sample selector
