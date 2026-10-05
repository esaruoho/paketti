# WIKI PAGE / REPORT CARD: Refresh Special keyjazz delays at every count
# WHAT THIS CARD SPAWNS:
# codespace: PakettiExperimental_Verify.lua and tests/keyjazz-special-cycler.lua
# thinkspace: keyjazz-special-cycler.session.md
# areaspace: Special count controls; preserve ordinary cycler delay behavior.
# SESSION: keyjazz-special-cycler.session.md
# RESULT: Local working-tree change; no commit, push or PR performed.
# Files: PakettiExperimental_Verify.lua, tests/keyjazz-special-cycler.lua, PLAN.md, manual/CHANGESLOG.md and this card/session bundle.
# WATCH: ColumnCycleKeyjazzSpecial PakettiColumnCycleKeyjazzSpecialPrepare PakettiColumnCycleKeyjazzCyclerApply PakettiColumnCycleKeyjazzCyclerStep
# RESULT-LOG >>
Feature: Refresh Special keyjazz delays at every count
  @sim-verified @runtime-untested
  Scenario: Reapply delays at the upper limit
    # cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzCyclerApply; tests/keyjazz-special-cycler.lua
    Given twelve note columns are visible and delays have been erased
    When Special cycler plus one is triggered with its stored count at twelve
    Then all rows receive floor(256 / 12 * (column - 1)) delays
    And cycling stays on with edit mode enabled, edit step zero and column one selected

  @sim-verified @runtime-untested
  Scenario: Select Special counts through keys, menus and a MIDI knob
    # cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzCyclerStep and Special registrations
    Given a sequencer track
    When a Special step or absolute MIDI knob selects a count
    Then the count is clamped to one through twelve and pattern delays are regenerated

  @sim-verified @runtime-untested
  Scenario: Preserve ordinary cycler behavior
    # cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzCyclerApply
    Given existing delay values
    When the ordinary cycler changes count
    Then existing delays are preserved

  @sim-verified @runtime-untested
  Scenario: Numbered Special twelve refreshes already-visible columns
    # cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzSpecialPrepare and ColumnCycleKeyjazzSpecial
    Given twelve columns are already visible
    When numbered Special twelve is invoked again
    Then the visible count is assigned directly and every row receives regenerated delays
