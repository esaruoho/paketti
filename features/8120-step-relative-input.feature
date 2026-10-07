# WHAT THIS CARD SPAWNS:
# codespace: PakettiEightOneTwenty.lua per-step sample textfield notifier; card/session/transcript bundle
# thinkspace: 8120-step-relative-input.session.md
# areaspace: committed sample-number text input only; preserve pattern update and focus behavior
# SESSION: 8120-step-relative-input.session.md
# RESULT: Worktree implementation; no commit, push or PR. Files: PakettiEightOneTwenty.lua, PLAN.md, features card/session/bundle/index/generated views.
# WATCH: sample_valueboxes updating_step_samples
# RESULT-LOG >>
Feature: Adjust per-step sample numbers with typed plus and minus
  @code-verified @runtime-untested
  Scenario: Apply relative input to the current step sample
    # cite: PakettiEightOneTwenty.lua PakettiEightSlotsByOneTwentyCreateRow sample_valueboxes notifier
    Given a per-step sample number of 3
    When the user commits + in its sample field
    Then the sample number becomes 4
    When the user commits - with a current sample number of 3
    Then the sample number becomes 2
    And surrounding whitespace is accepted
    And the displayed number is normalized after input

  @code-verified @runtime-untested
  Scenario: Keep sample numbers within their existing bounds
    # cite: PakettiEightOneTwenty.lua sample_valueboxes notifier
    Given per-step sample input
    When incrementing 120 or decrementing 1
    Then the sample number stays at its respective bound
    And numeric input still sets an absolute sample number
    And invalid input retains the current number
    And the existing guarded display update and pattern notifier path remain in place

  @code-verified @runtime-untested
  Scenario: Consume relative keypresses while a sample field is focused
    # cite: PakettiEightOneTwenty.lua pakettiEightSlotsByOneTwentyDialog keyhandler
    Given a per-step sample textfield is in edit mode
    When the dialog keyhandler receives a plus or minus character with no modifier or Shift
    Then it updates the stored and displayed sample number by one within 1–120
    And it consumes the key and invokes the existing per-step pattern update
    And modified shortcuts and keys outside a focused sample field pass through
