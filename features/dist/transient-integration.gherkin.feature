# Pure Gherkin test extracted from features/transient-integration.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/transient-integration.feature

Feature: Combine Paketti and Phaos transient navigation
  @sim-verified @runtime-untested
  Scenario: Choose stereo-safe detection
    # cite: PakettiTransientAnalysis.lua M.detect; PakettiTransientNavigation.lua tn_start_detection
    Given stereo audio with a right-only or antiphase attack
    When I detect with adaptive Schmitt or level rise and treble
    Then both channels contribute without cancellation from mono summing
    And level rise provides sensitivity, relative threshold, minimum gap, onset or peak, and zero-cross options

  @sim-verified @runtime-untested
  Scenario: Reject stale background results
    # cite: PakettiTransientNavigation.lua tn_sample_key tn_start_detection
    Given a background detection for a selected sample
    When the sample, document, settings or probed audio changes
    Then its pending navigation does not edit a different sample
    And errors clear the detecting state so detection can retry

  @sim-verified @runtime-untested
  Scenario: Select adjacent regions and move edges independently
    # cite: PakettiTransientNavigation.lua tn_boundaries PakettiTransientSelectionEdge
    Given sorted transient boundaries and an inclusive Renoise selection
    When I select adjacent regions or move either edge or both edges
    Then adjacent regions share no audio frames
    And the final region includes the final sample frame
    And shrinking cannot cross the opposite edge

  @sim-verified @runtime-untested
  Scenario: Preserve crop metadata and stop on failed allocation
    # cite: PakettiTransientNavigation.lua tn_crop
    Given a selected region with loop points and slice markers
    When I crop to selection
    Then retained audio and markers move to the new origin
    And removed loops turn off and overlapping loops retain their mode
    And failed allocation performs no sample-data writes
