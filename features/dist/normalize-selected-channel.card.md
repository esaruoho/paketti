# Report Card — Normalize selected sample selection

> Source: `features/normalize-selected-channel.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Sample Editor user, I want normalization to obey the selected range and channel, So that only the audio I selected is changed.

**Grades:** @code-verified × 5 · @runtime-untested × 5 · @shipped × 5 · @stock × 1

**Scenarios: 6**


---


## 1. Resolve sample-buffer selection bounds

`@shipped @code-verified @runtime-untested`


- Given a sample buffer selection is empty or covers valid frames
- When Paketti resolves the frame selection
- Then an empty selection resolves to the full buffer at the normalize callsite
- And a valid selection resolves to its selected frame bounds

<sub>cite: PakettiProcess.lua paketti_sample_selection_bounds (~line 36) — rejects Renoise's {0, 0} no-selection value and clamps real bounds</sub>


## 2. Resolve the selected sample-buffer channel

`@shipped @code-verified @runtime-untested`


- Given a sample buffer has more than one channel
- When the Sample Editor selection is left-only or right-only
- Then Paketti resolves the selected side to only channel 1 or only channel 2
- And a both-channel selection resolves to every channel in the sample buffer

<sub>cite: PakettiProcess.lua paketti_selected_sample_channels (~line 12) — converts Renoise left/right/both channel selection into a channel list and status suffix</sub>


## 3. Normalize only the selected channel in the ultra-fast path

`@shipped @code-verified @runtime-untested`


- Given a stereo sample has a loud left channel and a quiet right channel
- And the user selects only the right channel in the Sample Editor
- And selects a frame range that excludes the loudest right-channel peak elsewhere
- When the user runs Paketti Normalize Sample on a regular-sized sample
- Then peak detection uses the right channel's peak inside the selected range
- And normalization writes the right channel inside the selected range only
- And the left channel remains unchanged
- And audio outside the selected range remains unchanged

<sub>cite: PakettiProcess.lua normalize_selected_sample_ultra_fast_coroutine (~line 950) — reads peaks and writes gain only for channels_to_normalize</sub>


## 4. Normalize only the selected channel in the streaming path

`@shipped @code-verified @runtime-untested`


- Given a large stereo sample is routed through the streaming normalizer
- And the user selects only the right channel in the Sample Editor
- And selects a frame range
- When the user runs Paketti Normalize Sample
- Then the streaming peak scan reads the right channel only
- And the streaming peak scan and gain pass stay inside the selected range
- And the streaming gain pass writes the right channel only
- And progress is calculated from the selected channel count

<sub>cite: PakettiProcess.lua normalize_selected_sample_streaming_coroutine (~line 822) — streams only channels_to_normalize for peak detection and gain writes</sub>


## 5. Both-channel normalization remains linked

`@stock`


- Given no single side is selected in a stereo sample
- When the user runs Paketti Normalize Sample
- Then Paketti still finds the peak across both channels
- And it applies the same gain to both channels

<sub>cite: PakettiProcess.lua paketti_selected_sample_channels (~line 27) — non-left/right selections include every channel</sub>


## 6. Normalize Selected Sample or Slice obeys channel and range

`@shipped @code-verified @runtime-untested`


- Given the user selects one channel and a frame range in a sample or slice
- When the user runs Normalize Selected Sample or Slice
- Then peak detection uses only the selected channel and selected range
- And only that channel and range are written

<sub>cite: PakettiProcess.lua NormalizeSelectedSliceInSample (~line 52) — caches, measures and writes only selected channels and selected bounds within the sample or slice</sub>

