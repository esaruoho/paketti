# Groovebox Collapse checkbox scope fix

User reported `variable 'collapse_checkbox' is not declared` at dialog construction, line 4620. Existing worktree changes moved the control into controller_follow_row while leaving its declaration local to the global-controls builder. Moved the checkbox construction into pakettiEightSlotsByOneTwentyDialog immediately before its consuming row. Existing notifier and preference remain intact; unrelated worktree changes are preserved.

Validation: `luac -p PakettiEightOneTwenty.lua` passed. Renoise runtime remains untested.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/07/rollout-2026-10-07T21-18-08-01a11796-4c8f-7b01-aebf-21fd4bd9a7cf.jsonl
- Session ID: 01a11796-4c8f-7b01-aebf-21fd4bd9a7cf
- Resume: `codex --resume 01a11796-4c8f-7b01-aebf-21fd4bd9a7cf`
- Verified transcript timestamps (UTC): 2026-10-07T18:18:11.475Z through 2026-10-07T18:19:04.459Z.
- Bundled snapshot: [raw](8120-collapse-scope.transcript.jsonl), [readable](8120-collapse-scope.transcript.md).
- Card: [8120-collapse-scope.feature](8120-collapse-scope.feature).

RESULT: Worktree fix; no commit, push or PR.
