# WIKI PAGE / REPORT CARD: Longer loaded-sample AHDSR release
# WHAT THIS CARD SPAWNS:
# codespace: PakettiSamples.lua, PakettiStretch.lua, tests/loader-ahdsr-release.lua
# thinkspace: loader-ahdsr-release.session.md
# areaspace: loader AHDSR-on preference and explicit Timestretch release edit; no reload-time envelope mutation.
# SESSION: loader-ahdsr-release.session.md
# RESULT: Local working-tree change; no commit, push or PR.
# Files: source modules, test, PLAN.md, manual/CHANGESLOG.md, card/session bundle and generated views.
# WATCH: PakettiApplyLoaderModulationSettings set_stretch_release_480ms
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: PakettiApplyLoaderModulationSettings set_stretch_release_480ms
Feature: Longer loaded-sample AHDSR release
  @sim-verified @runtime-untested
  Scenario: Loader preference on gives the envelope a 480 ms release
    # cite: PakettiSamples.lua PakettiApplyLoaderModulationSettings
    Given a freshly loaded instrument with Volume AHDSR and the loader envelope preference on
    When loader modulation settings are applied
    Then the AHDSR is activated and Release is assigned as 480 ms with tempo sync off
    And other AHDSR parameters and operator remain unchanged

  @sim-verified @runtime-untested
  Scenario: Loader preference off leaves release and timing unchanged
    # cite: PakettiSamples.lua PakettiApplyLoaderModulationSettings
    Given the loader envelope preference is off
    When loader modulation settings are applied
    Then AHDSR activation, release and tempo sync are not changed

  @sim-verified @runtime-untested
  Scenario: Timestretch offers a deliberate 480 ms release action
    # cite: PakettiStretch.lua set_stretch_release_480ms and 480 ms button
    Given a selected sample with an assigned Volume AHDSR
    When the 480 ms button is pressed
    Then only Release and its unsynced timing are set
    And enabled state, operator and other parameter values are preserved

  @runtime-verified
  Scenario: Renoise parses real 480 ms
    # cite: loader-ahdsr-release.session.md live parser verification
    Given an unsynced Volume AHDSR Release parameter
    When its value_string is assigned 480 ms
    Then its display reads 480 ms and normalized value is approximately 0.2
