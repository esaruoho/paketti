# Pure Gherkin test extracted from features/loader-ahdsr-release.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/loader-ahdsr-release.feature

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
