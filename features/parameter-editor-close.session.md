# Close the unfocused parameter editor

User report: Cmd-H from Pattern Editor or Global leaves the unfocused Selected Device Parameter Editor open and says no external editors were open. The screenshot establishes that the existing hide action fires but ignores the Paketti custom dialog.

Fix: expose PakettiCanvasExperimentsCloseDialog, capture its visible dialog, run existing automation/observer/timer cleanup, then close the captured dialog. hide_all_external_editors calls it independently of focus, includes its result in status, and preserves external plugin/track/sample-chain closure. No mapping names changed.

Verification: lua tests/parameter-editor-close.lua passed: unfocused dialog closes, cleanup precedes close, real extracted hide action still closes external windows, repeated invocation is safe, unavailable module is tolerated. LuaJIT compilation passed for both changed modules. Live Renoise shortcut dispatch not yet verified.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/05/rollout-2026-10-05T18-43-41-01a10cbc-2e3e-7830-ac65-13832c5af416.jsonl
- Session ID: 01a10cbc-2e3e-7830-ac65-13832c5af416
- Resume: Codex --resume 01a10cbc-2e3e-7830-ac65-13832c5af416
- Verified UTC snapshot: 2026-10-05T15:45:11.546Z through 2026-10-05T16:20:50.640Z.
- Bundle: [parameter-editor-close.transcript.jsonl](parameter-editor-close.transcript.jsonl), [parameter-editor-close.transcript.md](parameter-editor-close.transcript.md).
- Card: [parameter-editor-close.feature](parameter-editor-close.feature).
- Result: local working-tree change; no commit, push or PR.

Live verification: PakettiMCP found the real dialog visible. Loaded the exact new close/hide action bodies into the running instance (the close helper resolves the existing dialog closure), invoked hide_all_external_editors, and confirmed visible before=true, after=false. Live global hide action is updated; the keyboard shortcut itself was not synthesized.
