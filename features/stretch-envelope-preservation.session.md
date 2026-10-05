# Preserve crafted envelopes

User report: activating envelopes changes a carefully crafted Volume AHDSR into deafening noise. Reproduced the parameter overwrite with the original checkbox handler: custom Decay became zero. Activation also forced Sustain=1, Release=0.024, Release Scaling=1, operator=3, looping and NNA. A duplicate module-level checkbox synchronized enabled state by setting its value, potentially firing the same destructive handler on load. The generic device finder selected the first matching device across all modulation sets.

Fix: toggle only enabled; preserve envelope and sample settings. Use the selected sample's assigned modulation set. Initialize controls from real values; accurately label Release Scaling. Release edits preserve all other parameters. Remove duplicate checkbox and dead synchronization functions.

Verification: original-handler regression failed before fix; lua tests/stretch-envelope-preservation.lua passes; luajit bytecode compilation passes. Live Renoise assertions ran the actual fixed checkbox handler twice at the existing enabled state and verified all eight values, operator, enabled state, looping and NNA unchanged. Full module reload then failed at an already-registered keybinding (after redefining the dialog); replaced the existing Timestretch keybinding with the newly defined fixed function. No GUI click-through or audible playback test performed. No claim that the preexisting damaged envelope has been restored; original values are unknown.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/05/rollout-2026-10-05T18-43-41-01a10cbc-2e3e-7830-ac65-13832c5af416.jsonl
- Session ID: 01a10cbc-2e3e-7830-ac65-13832c5af416
- Resume: Codex --resume 01a10cbc-2e3e-7830-ac65-13832c5af416
- Verified transcript UTC snapshot: 2026-10-05T15:45:11.546Z through 2026-10-05T15:58:40.602Z.
- Bundled source: [stretch-envelope-preservation.transcript.jsonl](stretch-envelope-preservation.transcript.jsonl) and [stretch-envelope-preservation.transcript.md](stretch-envelope-preservation.transcript.md).
- Card: [stretch-envelope-preservation.feature](stretch-envelope-preservation.feature).

User correction: activation must leave an already-enabled envelope enabled, never toggle it off. Replaced the checkbox with a one-way Activate Envelopes button; helper only writes enabled=true when the device is currently off. Updated regression tests and grades for this final behavior.

Final correction: no automatic enabled-state changes at all. Removed the activation button/helper and Release's enabling call. Startup replay of the original module tail using actual Renoise ViewBuilder with mock song/device confirmed enabled=true triggered operator=3, Decay=0, Sustain=1, Release=0.024, Release Scaling=1, loop=2, NNA=2. The original checkbox constructor began false, then check_and_set_envelope_status assigned true, triggering the destructive notifier. This is a reproduced reload path, not merely code inspection.
