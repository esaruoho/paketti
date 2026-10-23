# WHAT THIS CARD SPAWNS:
# codespace: PakettiRequests.lua menu registration; Paketti0G01_Loader.lua preferences UI/helper
# thinkspace: oblique-startup-options.session.md
# areaspace: startup setting placement; preserve startup message and manual dialog
# SESSION: oblique-startup-options.session.md
# RESULT: Worktree changes; no commit, push or PR. Files: PakettiRequests.lua, Paketti0G01_Loader.lua, PLAN.md and this card bundle.
# WATCH: pakettiObliqueStrategiesOnStartup
# RESULT-LOG >>
#   2026-10-23  direct-commit  touched: pakettiObliqueStrategiesOnStartup
Feature: Toggle startup Oblique Strategies from Options
  @built @runtime-untested
  Scenario: Persist startup toggle and reflect it with a checkmark
    # cite: PakettiRequests.lua PakettiAddMenuOptionsEntry; Paketti0G01_Loader.lua PakettiAddMenuToggleEntry
    Given the saved Oblique Strategies startup boolean
    When the user selects Main Menu Options Oblique Strategies on Startup
    Then the boolean is inverted and preferences.xml is saved
    And selected returns a strict boolean matching the preference

  @built @runtime-untested
  Scenario: Replace the preferences checkbox
    # cite: Paketti0G01_Loader.lua preferences dialog Switcharoo row
    Given the preferences dialog is opened
    Then the Oblique Strategies startup checkbox is absent

  @stock
  Scenario: Preserve startup and manual strategies
    # cite: main.lua startup preference guard; PakettiRequests.lua pakettiObliqueStrategiesDialog
    Given Oblique Strategies is enabled on startup
    When startup runs
    Then the existing startup message behavior remains available
