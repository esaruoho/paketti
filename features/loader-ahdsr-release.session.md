# Longer AHDSR release on loading

User requested a real 480 ms Timestretch release and a longer envelope when the loader AHDSR preference is on. Prior source inspection found loader activation intact but no Release assignment. Preserve the earlier requirement that reload never touches existing envelopes.

Implementation: loader AHDSR-on branch sets Release.value_string="480 ms" and tempo_synced=false. AHDSR-off branch never writes those values. Timestretch gets an explicit 480 ms button, targeting the selected sample modulation set; it leaves enabled, operator and other parameters untouched. A millisecond release necessarily uses unsynced timing, so this deliberate action turns tempo sync off. Other AHDSR stages are not lengthened automatically; 480 ms is the requested release tail.

Verification: live Renoise parser accepted "480 ms", produced normalized 0.20000000298023 and displayed "480 ms"; restored prior Release immediately. Mock regression tests exercise actual loader/helper bodies and pass; preservation tests pass; both source files compile with LuaJIT. No sample import or GUI button click was synthesized; parser behavior alone is runtime verified. No commit, push or PR.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/05/rollout-2026-10-05T18-43-41-01a10cbc-2e3e-7830-ac65-13832c5af416.jsonl
- Session ID: 01a10cbc-2e3e-7830-ac65-13832c5af416
- Resume: Codex --resume 01a10cbc-2e3e-7830-ac65-13832c5af416
- Verified UTC snapshot: 2026-10-05T15:45:11.546Z through 2026-10-05T17:05:25.009Z.
- Source bundle: [loader-ahdsr-release.transcript.jsonl](loader-ahdsr-release.transcript.jsonl), [loader-ahdsr-release.transcript.md](loader-ahdsr-release.transcript.md).
- Card: [loader-ahdsr-release.feature](loader-ahdsr-release.feature).
