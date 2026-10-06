# Report Card — Combine Paketti and Phaos transient navigation

> Source: `features/transient-integration.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @runtime-untested × 4 · @sim-verified × 4

**Scenarios: 4**


---


## 1. Choose stereo-safe detection

`@sim-verified @runtime-untested`


- Given stereo audio with a right-only or antiphase attack
- When I detect with adaptive Schmitt or level rise and treble
- Then both channels contribute without cancellation from mono summing
- And level rise provides sensitivity, relative threshold, minimum gap, onset or peak, and zero-cross options

<sub>cite: PakettiTransientAnalysis.lua M.detect; PakettiTransientNavigation.lua tn_start_detection</sub>


## 2. Reject stale background results

`@sim-verified @runtime-untested`


- Given a background detection for a selected sample
- When the sample, document, settings or probed audio changes
- Then its pending navigation does not edit a different sample
- And errors clear the detecting state so detection can retry

<sub>cite: PakettiTransientNavigation.lua tn_sample_key tn_start_detection</sub>


## 3. Select adjacent regions and move edges independently

`@sim-verified @runtime-untested`


- Given sorted transient boundaries and an inclusive Renoise selection
- When I select adjacent regions or move either edge or both edges
- Then adjacent regions share no audio frames
- And the final region includes the final sample frame
- And shrinking cannot cross the opposite edge

<sub>cite: PakettiTransientNavigation.lua tn_boundaries PakettiTransientSelectionEdge</sub>


## 4. Preserve crop metadata and stop on failed allocation

`@sim-verified @runtime-untested`


- Given a selected region with loop points and slice markers
- When I crop to selection
- Then retained audio and markers move to the new origin
- And removed loops turn off and overlapping loops retain their mode
- And failed allocation performs no sample-data writes

<sub>cite: PakettiTransientNavigation.lua tn_crop</sub>

