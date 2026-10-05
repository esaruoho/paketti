# WIKI PAGE / REPORT CARD: Close the unfocused parameter editor
# WHAT THIS CARD SPAWNS:
# codespace: PakettiLoaders.lua, PakettiCanvasExperiments.lua, tests/parameter-editor-close.lua
# thinkspace: parameter-editor-close.session.md
# areaspace: existing hide-editors action and parameter-editor lifecycle; preserve device parameter values.
# SESSION: parameter-editor-close.session.md
# RESULT: Local working-tree change; no commit, push or PR.
# Files: source modules, test, PLAN.md, manual/CHANGESLOG.md, card/session bundle and generated views.
# WATCH: hide_all_external_editors PakettiCanvasExperimentsCloseDialog
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: PakettiCanvasExperimentsCloseDialog
#   2026-10-06  direct-commit  touched: hide_all_external_editors PakettiCanvasExperimentsCloseDialog
Feature: Close the unfocused parameter editor
  @sim-verified @runtime-verified
  Scenario: Hide editors from Pattern Editor or Global closes the custom dialog
    # cite: PakettiLoaders.lua hide_all_external_editors; PakettiCanvasExperiments.lua PakettiCanvasExperimentsCloseDialog
    Given the Selected Device Parameter Editor is visible but unfocused
    When the existing hide external editors shortcut is invoked
    Then parameter editor automation observers and timers are cleaned up
    And the parameter editor closes without requiring its keyboard focus
    And existing external device editors also close

  @sim-verified @runtime-untested
  Scenario: Repeated hide calls and an unavailable parameter editor remain safe
    # cite: PakettiLoaders.lua hide_all_external_editors; tests/parameter-editor-close.lua
    Given the parameter editor is already closed or its module is unavailable
    When hide external editors is invoked
    Then external device editors still close without a missing-function error
