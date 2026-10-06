# SimpleXfade and Paketti destructive crossfades

Scope: source review of `/Users/esaruoho/Downloads/com.phaos.SimpleXfade.xrnx`, manifest version 1.2.0, author phaos. Read both archive members in full. Compared sample-buffer crossfades; device-parameter and mixer crossfades are separate operations. No DSP implementation changed. Arithmetic checked locally; no Renoise listening or runtime verification performed.

## Existing operations

| Operation | Actual behavior | Consequence |
| --- | --- | --- |
| `PakettiProcess.lua:3642`, `crossfade_with_fades` | Averages the entire sample with its reversed copy, then applies six-frame edge fades. | A creative forward/reverse blend, not a conventional loop crossfade. Changes the whole recording and ignores loop markers and selection. Preserve as its own effect. |
| `PakettiProcess.lua:3712`, `crossfade_loop_edges_fixed_end` | Mirror-averages the first/last 10% of the loop, then fades before/start/end regions. | Alters the attack before the loop and introduces level dips. Requires pre-loop space despite not using that audio as a crossfade source. |
| `PakettiExperimental_Verify.lua:727`, `crossfade_loop` | Linearly blends pre-loop audio into the tail, then applies three 20-frame fades. | Closest to SimpleXfade, but extra fades disturb the original pre-loop/start transition. Processes instrument sample 1 rather than the selected sample. |
| `PakettiExperimental_Verify.lua:871`, `get_dynamic_crossfade_length` | Computes fade length as loop end minus selection end. | Selection means fade length indirectly, whereas SimpleXfade treats selection as the loop itself. These gestures should not silently change meaning under an existing shortcut. |

Menu locations: `PakettiMenuConfig.lua:2200` and `:2201` under Process; `:2258` under Xperimental/WIP. Experimental shortcut: `Global:Paketti:Crossfade Loop`. Fixed End also has MIDI registration at `PakettiMenuConfig.lua:4666`.

## What SimpleXfade improves

Its core uses loop start `ls`, inclusive loop end `le`, and fade length `F = min(le-ls+1, ls-1)`. Source frames are `ls-F .. ls-1`; destination frames are `le-F+1 .. le`. For `i=0..F-1`, it writes:

```lua
local theta = ((i + 1) / F) * math.pi / 2
output = tail * math.cos(theta) + before_loop * math.sin(theta)
```

At the final fade frame, the output is effectively the original frame `ls-1`. Playback then proceeds to original frame `ls`, preserving their original adjacent-frame transition. It does not force the waveform to zero and does not overwrite the loop start or pre-loop source. This preserves continuity without claiming every source will become inaudibly seamless: an existing transient between those original adjacent frames can remain.

The two ranges never overlap because the fade is bounded by loop length and available pre-loop audio. Consequently it can process in place without caching the whole sample. It handles every channel consistently.

Useful workflow improvements:

- A proper editor selection becomes the loop; without one, use the existing enabled loop.
- One-key operation with automatic fade length, bounded safely by available source audio.
- Instrument-wide application: use the selected sample's selection frame positions for every eligible sample, otherwise use each sample's own loop.
- Skip read-only slice aliases, empty samples, short samples, missing loops and insufficient pre-loop audio; summarize counts by reason.
- Report loop and fade times instead of only a generic completion message.
- Ignore repeated key events and require MIDI trigger messages.

## Defects found in Paketti

1. **Fixed End writes beyond the loop.** Its end-fade position is `(le-fade_len)+(i+1)`, with `i=1..fade_len`: actual range is `le-fade_len+2 .. le+1`. For loop 101..200 and fade length 10, that is 192..201. This contradicts its comment, misses part of the intended fade, modifies post-loop audio and can access frame `number_of_frames+1` when the loop ends at the sample end.
2. **Experimental selected-sample mismatch.** The length helper reads the selected sample, but the processor calls `instrument:sample(1)`. It can derive a length from one sample and destructively edit another.
3. **Experimental monitoring restoration is incomplete.** AutoSamplify monitoring is disabled before validation; early returns bypass restoration, as do processing errors.
4. **Experimental fade length 1 divides by zero.** The helper permits a selection end one frame before loop end, but DSP divides by `crossfade_length-1`.
5. **Experimental tail excludes `loop_end`.** Both the crossfade and end silence fade finish at `loop_end-1`; the loop's final frame is left untreated.
6. **Experimental fade is not bounded by loop length.** A sufficiently long requested fade can overwrite before the loop and overlap its source region, invalidating in-place reads.
7. The Process implementations do not guard read-only buffers or guarantee finalization after a write error.

## What should be adapted rather than copied unchanged

**Keep both Linear and Equal Power curves.** Sine/cosine weights satisfy squared-gain sum 1, which helps weakly correlated material avoid the linear blend's perceived energy dip. They do not guarantee constant amplitude for correlated material. Identical positive signals at the midpoint sum to approximately 1.414 times their original amplitude, a +3.01 dB rise, potentially exceeding sample headroom. Opposite-phase signals can still cancel. Offer Linear for highly correlated/phase-aligned material and Equal Power for less correlated material; describe this clearly. Do not silently clamp or normalize the whole sample.

**Keep adjustable fade length as well as Auto.** SimpleXfade's Auto can rewrite the entire loop when enough pre-loop audio exists. That can smooth sustained sounds but change a rhythmic or evolving loop substantially. Add a frame/ms length control capped by loop length and available pre-loop audio. Auto should retain SimpleXfade's exact policy; a shorter explicit fade preserves more of the loop.

**Make loop-mode changes explicit.** SimpleXfade forces forward looping, including existing backward/ping-pong loops. The tail-to-head algorithm is intended for forward loops. For selection-created loops, forward is sensible. For existing non-forward loops, report that the operation needs a forward loop rather than silently changing playback direction; direction-specific processing can be a separate feature.

**Strengthen error handling.** SimpleXfade catches DSP errors but does not finalize a successfully prepared buffer if a later write throws. It also swallows marker-setting errors and returns success. Track whether preparation succeeded, finalize on the error path, report marker failures honestly, and preserve/restore editor and monitoring state where needed. Error catching alone is not rollback; partial sample writes may require native Undo.

**Clarify selections and batch units.** SimpleXfade treats a full-buffer selection and a one-frame selection as no selection, because the API can report the full range when nothing is selected. Document this ambiguity. Batch selection reuse is in absolute frames, so differing sample rates mean differing times; offer an explicit frame/time choice if supporting mixed-rate instruments. Its batch command also requires the selected sample to have data even when other samples have valid loops; independent per-sample-loop batch mode need not impose this restriction.

**Respect source attribution.** The archive identifies phaos and mentions afta8's xfade pow, but contains no license file or explicit reuse grant. The manifest is not a license. Implement the DSP idea and workflow within Paketti's conventions; establish permission/license before copying substantial source verbatim. Credit Phaos for the workflow idea and retain afta8 attribution where applicable.

## Recommended combined implementation

Build a shared, validated forward-loop crossfade helper under Paketti sample processing. Use SimpleXfade's non-overlapping pre-loop-to-tail geometry and exact final-frame behavior. Expose selected-sample and instrument scopes, selection-to-loop and existing-loop modes, Auto or explicit frame/ms length, and Linear or Equal Power curves. Keep the original pre-loop audio, loop start, sample length and audio outside the destination range intact. Use one prepare/finalize pair per edited buffer, native undo, precise skip/error counts and useful fade-duration reporting.

Add clearly named new Process actions for this conventional loop crossfade. Preserve the whole-sample reverse-blend effect and existing shortcut gestures; migrate legacy loop-crossfade callers only with an explicit compatibility decision. Fix the selected-sample, out-of-range and monitoring-restoration defects independently of new UI. Do not carry over mandatory six/20-frame silence fades into the new default algorithm.

Verification should exercise mono/stereo, loop-at-sample-end, minimum fade, no pre-loop space, source/destination disjointness, unchanged data outside the destination, slice aliases, selection versus own-loop batch scopes, different sample rates, correlated peaks, error cleanup and loop-mode handling. Listening in Renoise should cover sustained pads, phase-aligned tones and rhythmic material. This review establishes source behavior and arithmetic, not audible quality or live API correctness.

## Implementation follow-through

The user approved the proposal. See [LoopCrossfade.md](LoopCrossfade.md) for the implemented controls and [the report card](../features/loop-crossfade.feature) for verification. The defects described above refer to the pre-change source. Legacy experimental processing now delegates to the validated Linear helper without disabling monitoring; the fixed-end range and legacy slice/error guards are corrected. Equal Power headroom is checked before any writes. Live Renoise audio and Undo remain unverified.
