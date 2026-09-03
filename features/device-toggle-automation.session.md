# Device Toggle Automation Session

## How To Get Back

- Transcript path: `file:///Users/esaruoho/.codex/sessions/2026/09/03/rollout-2026-09-03T15-11-41-01a0672e-9575-7f92-b94b-2e38296ad49f.jsonl`
- Bundled raw transcript: `features/device-toggle-automation.transcript.jsonl`
- Readable transcript: `features/device-toggle-automation.transcript.md`
- Session ID: `01a0672e-9575-7f92-b94b-2e38296ad49f`
- Resume command: `codex --resume 01a0672e-9575-7f92-b94b-2e38296ad49f`
- Session started: `2026-09-03 15:11:41 +0300 EEST` (`2026-09-03T12:11:41.338Z`)
- Card written: `2026-09-03 15:22:05 +0300 EEST`
- Identified by content: the session ID was exposed in `CODEX_SESSION_ID`, then the matching JSONL was found under `/Users/esaruoho/.codex/sessions/2026/09/03/`.

## Request

Esa first asked whether GitHub issue #593 was already in Paketti. The issue title was "Automation recording function: Enable/Disable the Nth device of the selected track", with separate checklists for Pattern Automation Recording Mode as Effect Commands (`x000`/`x001`) and as Graphical Envelope.

After confirming the old implementation only flipped `device.is_active`, Esa asked: "please accomplish it".

## What Changed

`PakettiDeviceBypass(number, state)` in `PakettiRequests.lua` now preserves the existing live enable/disable/toggle behavior and adds recording when Edit Mode is on.

When `renoise.song().transport.record_parameter_mode` is `renoise.Transport.RECORD_PARAMETER_MODE_PATTERN`, the action writes the Renoise device bypass command into the selected track's first effect column: Device Control 01 writes `10 00` for off and `10 01` for on, Device Control 02 writes `20 00`/`20 01`, and so on.

When the record parameter mode is graphical automation, the action finds the device's `Active` parameter, creates an automation envelope if needed, and writes `0.0` for disabled or `1.0` for enabled.

Both modes use the issue's line-placement rule: playhead only when playback is running and Follow Pattern is on; otherwise the selected cursor line.

## Verification

- `luac -p PakettiRequests.lua` passed.
- Runtime behavior is not verified in Renoise from this shell, so the feature card is graded `@runtime-untested`.

## Boundaries

This session did not change the older "Show/Hide Selected Track Device NN" mappings. It changed the "Device Control NN (Enable/Disable/Toggle)" path used by `PakettiDeviceBypass`, which is the Nth-device enable/disable function referenced by issue #593.
