# Disk Browser automatic control toggle

User reported that the Main Menu Options checkbox seemed always enabled and could not turn automation off.

The checkmark compared a Renoise observable object directly with zero; the song-load handler compared that object directly with numeric modes. The toggle also attempted arithmetic on the object, cycled three modes and did not save. All mode access now uses .value. Active Hide/Show toggles to zero; zero enables Hide. Explicit popup modes remain available.

Regression harness failed before the fix on mode zero being checked. After the fix, Hide/Show application, disabling both modes, no action while disabled, enabling Hide and save count pass. Lua syntax and targeted whitespace checks pass. Renoise runtime untested.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/23/rollout-2026-10-23T22-49-01-01a16a4f-4018-71f0-9279-c8702b0de780.jsonl
- Session ID: 01a16a4f-4018-71f0-9279-c8702b0de780
- Resume: `codex --resume 01a16a4f-4018-71f0-9279-c8702b0de780`
- Verified snapshot timestamps: 2026-10-23T19:49:14.559Z through 2026-10-23T19:55:06.663Z.
- Bundle: [disk-browser-auto-toggle.transcript.jsonl](disk-browser-auto-toggle.transcript.jsonl), [disk-browser-auto-toggle.transcript.md](disk-browser-auto-toggle.transcript.md).
- Card: [disk-browser-auto-toggle.feature](disk-browser-auto-toggle.feature).

RESULT: Worktree fix; no commit, push or PR.
