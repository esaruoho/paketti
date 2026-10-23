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

## Focused Cmd-H follow-up

User: “when the parameter editor is open and you press cmd-h, it should hide the dialog and all external editors that are open. got it? please make it clever.”

The focused key handler duplicated dialog-only cleanup, bypassing the existing song-wide hide action. It now calls hide_all_external_editors and consumes Cmd-H. The existing action closes the dialog through its cleanup helper and traverses track devices, instrument plugins and sample FX chains.

Verification: lua tests/parameter-editor-close.lua passed with the extracted real handler and hide action, including all three editor locations, plain H, and repeated hiding. LuaJIT compilation passed. This follow-up has not been tested live in Renoise. Result: working tree only; no commit, push or PR.

### How to get back — follow-up

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/23/rollout-2026-10-23T22-45-06-01a16a4b-aacf-7841-b65d-5a010c8109cd.jsonl
- Session ID: 01a16a4b-aacf-7841-b65d-5a010c8109cd
- Resume: Codex --resume 01a16a4b-aacf-7841-b65d-5a010c8109cd
- Verified UTC transcript snapshot: 2026-10-23T19:45:24.573Z through 2026-10-23T19:46:28.492Z.
- Bundled source: [JSONL](parameter-editor-focused-hide.transcript.jsonl), [readable transcript](parameter-editor-focused-hide.transcript.md).
- Card: [parameter-editor-close.feature](parameter-editor-close.feature).
