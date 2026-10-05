# Pure Gherkin test extracted from features/normalize-selected-channel.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/normalize-selected-channel.feature

Feature: Normalize selected sample selection
  As a Sample Editor user, I want normalization to obey the selected range and channel, So that only the audio I selected is changed.

  @shipped @code-verified @runtime-untested
  Scenario: Resolve sample-buffer selection bounds
    # cite: PakettiProcess.lua paketti_sample_selection_bounds (~line 36) — rejects Renoise's {0, 0} no-selection value and clamps real bounds
    Given a sample buffer selection is empty or covers valid frames
    When Paketti resolves the frame selection
    Then an empty selection resolves to the full buffer at the normalize callsite
    And a valid selection resolves to its selected frame bounds

  @shipped @code-verified @runtime-untested
  Scenario: Resolve the selected sample-buffer channel
    # cite: PakettiProcess.lua paketti_selected_sample_channels (~line 12) — converts Renoise left/right/both channel selection into a channel list and status suffix
    Given a sample buffer has more than one channel
    When the Sample Editor selection is left-only or right-only
    Then Paketti resolves the selected side to only channel 1 or only channel 2
    And a both-channel selection resolves to every channel in the sample buffer

  @shipped @code-verified @runtime-untested
  Scenario: Normalize only the selected channel in the ultra-fast path
    # cite: PakettiProcess.lua normalize_selected_sample_ultra_fast_coroutine (~line 950) — reads peaks and writes gain only for channels_to_normalize
    Given a stereo sample has a loud left channel and a quiet right channel
    And the user selects only the right channel in the Sample Editor
    And selects a frame range that excludes the loudest right-channel peak elsewhere
    When the user runs Paketti Normalize Sample on a regular-sized sample
    Then peak detection uses the right channel's peak inside the selected range
    And normalization writes the right channel inside the selected range only
    And the left channel remains unchanged
    And audio outside the selected range remains unchanged

  @shipped @code-verified @runtime-untested
  Scenario: Normalize only the selected channel in the streaming path
    # cite: PakettiProcess.lua normalize_selected_sample_streaming_coroutine (~line 822) — streams only channels_to_normalize for peak detection and gain writes
    Given a large stereo sample is routed through the streaming normalizer
    And the user selects only the right channel in the Sample Editor
    And selects a frame range
    When the user runs Paketti Normalize Sample
    Then the streaming peak scan reads the right channel only
    And the streaming peak scan and gain pass stay inside the selected range
    And the streaming gain pass writes the right channel only
    And progress is calculated from the selected channel count

  @stock
  Scenario: Both-channel normalization remains linked
    # cite: PakettiProcess.lua paketti_selected_sample_channels (~line 27) — non-left/right selections include every channel
    Given no single side is selected in a stereo sample
    When the user runs Paketti Normalize Sample
    Then Paketti still finds the peak across both channels
    And it applies the same gain to both channels

  @shipped @code-verified @runtime-untested
  Scenario: Normalize Selected Sample or Slice obeys channel and range
    # cite: PakettiProcess.lua NormalizeSelectedSliceInSample (~line 52) — caches, measures and writes only selected channels and selected bounds within the sample or slice
    Given the user selects one channel and a frame range in a sample or slice
    When the user runs Normalize Selected Sample or Slice
    Then peak detection uses only the selected channel and selected range
    And only that channel and range are written
