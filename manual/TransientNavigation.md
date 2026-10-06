# Paketti transient navigation with Phaos detection options

Open **Sample Editor → Paketti → Transient Navigation → Detection Settings…**. The same settings panel is available in Tools → Paketti → Transient Navigation. Existing transient shortcuts and onset/region/no-zoom commands remain available.

## Two detectors, shared controls

**Paketti Adaptive Schmitt** remains the default. It detects attack novelty with lowpass/highpass fast and slow envelopes. Its existing dense-hit tuning is retained. It now examines both channels independently rather than only the left channel; channel hits feed one shared spacing pass. Zero snapping uses the maximum absolute amplitude across channels, so silence in the left channel cannot masquerade as a zero in a right-only hit.

**Phaos Level Rise / Treble** adapts the detector from SimpleTransients 1.0.3 by Phaos & Claude. It measures signal and first-difference power in 5 ms hops, scores rises against the preceding three hops, uses a relative volume floor and local maxima, and keeps stronger candidates when their coarse positions conflict with the minimum gap. Onsets are refined around candidates using a change-point score; peak mode instead finds the largest amplitude within 25 ms of the refined onset. Refinement uses channel power rather than a mono sum to avoid antiphase cancellation. Zero snapping searches back up to 3 ms around the refined onset.

| Level Rise setting | Meaning |
| --- | --- |
| Sensitivity, 0–100% | Higher requires a smaller jump in level and admits weaker rises |
| Threshold, 6–90 dB below peak | Larger admits quieter hits relative to the loudest analyzed hop |
| Minimum gap, 10–2000 ms | Separates coarse candidates; choose smaller for dense hits, larger for broader segments |
| Snap to Onset / Peak | Chooses attack start or nearby maximum amplitude |
| Zero-crossing snap | Adjusts onset placement; also controls adaptive snapping |

The level-rise settings do not retune adaptive Schmitt. The panel labels them accordingly. Both detectors run cooperatively in ProcessSlicer and share the same navigation and selection controls. The first command waits for analysis by scheduling its action when ready; repeated commands on that same pending job replace the pending action rather than restart analysis forever.

On the existing `farmman-369finlp.wav` fixture, the actual Lua implementations produced approximately 90 adaptive positions and 17 level-rise positions at default settings. Counts demonstrate different segmentation behavior, not a quality ranking or proof that every musical transient is correct. Keep the detector suited to the task; a blind union would also accumulate false positives.

## Selection edges

New Sample Editor menu entries, keybindings and trigger MIDI mappings move:

- Selection Start to Previous / Next Transient.
- Selection End to Previous / Next Transient.
- Selection Both Edges Out / In.
- Crop to Selection.

Edges do not wrap or cross each other. From a point selection, an edge command begins a span toward its requested direction. The sample start and end act as additional stops. Adjacent regions use exclusive end boundaries internally and inclusive Renoise selection ranges externally: a region before transient T ends at T−1. The last region includes the final sample frame. Starting region navigation from the whole-sample selection now selects the first region for Next and the last for Previous.

Paketti retains onset zoom, region zoom-to-fit and no-zoom point navigation. The API exposes selection edges rather than Renoise's dotted playback cursor; these operations follow the selection. Existing Delete Left/Right commands retain their inclusive cursor-frame semantics. Crop to Selection keeps exactly the selected inclusive range.

## Cache, background work and edits

Up to eight analyzed keys are remembered. Keys include sample/song object identity, dimensions, sample name, detector preferences and 64 audio probes per channel. These probes detect many same-size edits, including right-channel changes, but are not a full waveform hash: an edit confined between probe locations can be missed. Use Re-detect after such edits. Crop, re-detect, settings changes and document release explicitly invalidate caches.

Background jobs check document/sample identity and the content/settings key after yields and before publishing results or running pending selection changes. Switching away prevents a pending action from editing the newly selected sample. Releasing a document stops the running slicer and closes the settings dialog. A failed worker releases the busy state, permitting a later retry. This does not provide an atomic snapshot of audio changed during analysis; settings/content changes detected by the key cause the result to be discarded.

## Cropping

Crop preserves the kept channels and sample format, remaps surviving slice markers, and moves overlapping loop points while retaining loop mode. If the loop is removed or collapses to a point, looping turns off. Read-only buffers and slice aliases are rejected. A failed `create_sample_data` return stops before data writes. Cropping supplies an explicit undo description; actual undo behavior still needs live Renoise confirmation.

Crop currently copies and rebuilds the kept audio synchronously, as Paketti's previous crop path did. Large crops can use substantial temporary memory. This integration does not change BPM detection, BeatDetect slicing, or add automatic slice markers during navigation.

## What was carried over and what remains separate

The integration carries over configurable level-rise/treble detection, onset/peak placement, independent and paired selection edges, and selection cropping. It retains Paketti's adaptive detector, zoom variants, existing command names and slice-at-cursor action. Phaos's automatic prehear, optional wrap/follow/fine-selection modes, background sample prefetch, custom keyboard-focus panel and keybinding suggestion/help UI were not ported. Renoise's existing playback-selection actions can audition the resulting selections.

## Verification

`lua tests/transient-integration.lua /Users/esaruoho/Downloads/farmman-369finlp.wav` executes the actual Lua detector/navigation implementations. Synthetic checks cover mono, right-only and antiphase attacks, quiet/silent audio, adjacent regions and final-frame coverage, selection growth/shrink guards, probed same-size edits, stale/document/error jobs, repeated pending actions and crop metadata/allocation/read-only behavior. The same synthetic suite passes under LuaJIT. The older Python dense-hit regression also passes.

Full registration loaded 249/249 source modules; the overall repository gate remains blocked by the same pre-existing duplicate globals in `tests/keyjazz-special-cycler.lua`, with existing undeclared-call warnings elsewhere. Live GUI display, real audio editing/undo and musical accuracy across a broader sample corpus remain unverified.

Related: [integration report card](../features/transient-integration.feature).
