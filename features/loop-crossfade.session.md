# Combined loop crossfade

The user asked to inspect Phaos SimpleXfade and compare it with Paketti's existing destructive crossfades. The source comparison was saved to manual/CrossfadeComparison.md. The user approved implementation: “yeah, please do the changes, sounds like a good idea.”

Implemented independently written pre-loop-to-tail processing, selection/existing-loop modes, sample/instrument scopes, Linear/Equal Power, Auto/frames/ms and frame/time batch alignment. Equal Power peaks beyond sample headroom are rejected before writing. Fixed the legacy experimental selected-sample mismatch, length and range bugs, omitted endpoint and monitoring early-return issue by using the new helper without disabling monitoring. Retained the whole-sample reverse blend and separate fixed-end effect; fixed the latter's out-of-range end fade and added slice/error guards.

Tests pass under Lua and LuaJIT, including actual extracted legacy function bodies, whole-sample reverse-blend preservation, failure cleanup and a mocked dialog. LuaJIT compilation passes all four changed source modules. Stock luac rejects an existing main.lua construct at line 659, so target-compatible LuaJIT compilation is the applicable check. Registration harness loads 249/249 modules without new registration failures. The overall gate still fails on three existing duplicate globals in tests/keyjazz-special-cycler.lua and reports 57 unrelated undeclared-call warnings. Live Renoise listening, control display and native Undo remain unverified. No commit, push or PR.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/06/rollout-2026-10-06T02-50-02-01a10e79-7294-7b43-b5df-ccb6ac05adbc.jsonl
- Session ID: 01a10e79-7294-7b43-b5df-ccb6ac05adbc
- Resume: Codex --resume 01a10e79-7294-7b43-b5df-ccb6ac05adbc
- Verified UTC transcript snapshot: 2026-10-05T23:50:33.326Z through 2026-10-05T23:56:03.579Z.
- Bundle: [loop-crossfade.transcript.jsonl](loop-crossfade.transcript.jsonl), [loop-crossfade.transcript.md](loop-crossfade.transcript.md).
- Card: [loop-crossfade.feature](loop-crossfade.feature).
