# NetDrive zero-byte import guard

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/07/rollout-2026-10-07T16-48-49-01a1169f-bb17-7e01-b2d6-ec0c358a8863.jsonl
- Session ID: 01a1169f-bb17-7e01-b2d6-ec0c358a8863
- Resume: `codex --resume 01a1169f-bb17-7e01-b2d6-ec0c358a8863`
- Verified transcript window: 2026-10-07T13:49:29.715Z to 2026-10-07T13:51:34.698Z (UTC).
- Bundled source: [netdrive-zero-byte-guard.transcript.jsonl](netdrive-zero-byte-guard.transcript.jsonl); readable conversation: [netdrive-zero-byte-guard.transcript.md](netdrive-zero-byte-guard.transcript.md). Snapshot captured during implementation.

## Request and reasoning

Esa requested that Automatically Load From This Folder skip zero-byte files with “Zero Bytes - stop loading”, preventing Ableton's empty output files from causing repeated CoreAudio import failures.

The watcher treated stable size zero as a completed recording. Polling now holds empty files pending, without repeatedly notifying for the same signature, and waits for stability again after bytes arrive. Startup skips empty files while retaining a baseline signature so subsequent writes can be detected. The queue and loader independently recheck size before creating an instrument; empty skips do not count as decoder failures or advance the load-after cutoff.

## Verification and delivery

`python3 tests/netdrive_zero_byte_guard.py` passed actual Lua function tests with mocked Renoise APIs: direct empty load, repeated empty polling, positive-size recovery, queued truncation, and truncation between queue stat and loader stat. `luac -p PakettiSamples.lua` passed. Renoise/Ableton live runtime remains untested. Worktree changes only; no commit or PR. Existing preferences.xml and .gumroad-sync.FAILED changes were left untouched.

Card: [netdrive-zero-byte-guard.feature](netdrive-zero-byte-guard.feature).
