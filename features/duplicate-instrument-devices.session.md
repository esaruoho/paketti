# Preserve duplicated instrument devices

## How to get back

- Source: [transcript](file:///Users/esaruoho/.codex/sessions/2026/10/07/rollout-2026-10-07T21-30-24-01a117a1-8728-70d3-8a25-b98c5656dbfd.jsonl)
- Session ID: 01a117a1-8728-70d3-8a25-b98c5656dbfd
- Resume: `codex --resume 01a117a1-8728-70d3-8a25-b98c5656dbfd`
- Verified UTC snapshot range: 2026-10-07T18:32:16.327Z through 2026-10-07T18:33:53.334Z
- Bundles: [duplicate-instrument-devices.transcript.jsonl](duplicate-instrument-devices.transcript.jsonl), [duplicate-instrument-devices.transcript.md](duplicate-instrument-devices.transcript.md)

## Request

Esa reported that duplicating the Single Cycle writer’s A&B wavetable track loses the Wavetable Mod *LFO name and leaves Instrument Macros pointing to 0B instead of the new 0C. Requested a fix.

## Change and verification

The two duplication commands now use a shared full-preset device copier, restore display names after preset assignment, bind Instrument Macros by selecting the duplicate before insertion and retain Instrument Automation XML retargeting. The alternate command now preserves automation-device order rather than moving it to the end. Clean variants retain their DSP-free path.

A Lua mock passed 0B-to-0C selector checks, source preservation, custom names, complete preset/routing retention and mixer flags. Both changed Lua files passed luac syntax checks. Live Renoise behavior remains unverified. No commit or push. Existing preferences.xml changes and .gumroad-sync.FAILED were left alone.

Card: [duplicate-instrument-devices.feature](duplicate-instrument-devices.feature).

## Correction after a reported crash

Esa reported invalid parameter_value 13 (valid range 0–1). The first fix wrongly treated macro parameter 1 as an instrument selector; its mock incorrectly allowed instrument numbers in normalized macro values. Renoise identified this parameter as X_PitchBend. An attempted LinkedInstrument preset edit failed live target checks and was removed. Esa explicitly directed the investigation back to Create A&B, rather than forum research.

PCMWriter's Create A&B selects the new instrument before PCMWriterLoadABDevices inserts Macros. Both duplication callers now do the same. There is no numeric instrument-index assignment to a macro parameter and no guessed Macros XML field. Range-enforcing mocks cover the crash; a live temporary-track check using distinct SOURCE_TEST/TARGET_TEST instrument macro names confirmed the duplicate binds to the selected target and remains linked after preset copying. Temporary tracks and test macro names were restored. Immediate macro-value propagation probes were inconclusive; their target assertions failed and are not claimed as passes. Full end-to-end duplication still awaits user verification.
