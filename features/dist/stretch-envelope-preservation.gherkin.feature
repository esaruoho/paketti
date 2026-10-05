# Pure Gherkin test extracted from features/stretch-envelope-preservation.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/stretch-envelope-preservation.feature

Feature: Preserve crafted envelopes in Timestretch
  @sim-verified @runtime-untested
  Scenario: Activate without disabling or overwriting the envelope
    # cite: PakettiStretch.lua and read-only envelope display
    Given a crafted Volume AHDSR with custom parameters and operator
    When the module is loaded or the dialog is initialized
    Then its existing enabled or disabled state is preserved
    And all parameters, operator, sample looping and new-note action are preserved

  @sim-verified @runtime-untested
  Scenario: Displaying envelope state never enables or disables it
    # cite: PakettiStretch.lua and read-only envelope display
    Given the selected sample has an enabled Volume AHDSR
    When the dialog displays envelope state repeatedly
    Then the envelope stays enabled with every parameter and sample setting preserved

  @sim-verified @runtime-untested
  Scenario: Release and Release Scaling edit only their parameter
    # cite: PakettiStretch.lua pakettiTimestretchDialog Release and Release Scaling notifiers
    Given a crafted envelope
    When Release or Release Scaling is edited
    Then only parameter five or eight respectively changes
    And Release editing preserves enabled state and other envelope and sample settings

  @sim-verified @runtime-untested
  Scenario: Target the selected sample modulation set
    # cite: PakettiStretch.lua find_stretch_volume_ahdsr_device
    Given several modulation sets contain Volume AHDSR devices
    When an envelope control is used
    Then only the selected sample assigned set is targeted
    And an unassigned sample leaves unrelated sets untouched
