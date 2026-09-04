# Pattern And Song Jumps Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-04
- Note: session file created during live implementation; click-back can be backfilled from Codex transcripts by content search for `PakettiJumpBackByLastPatternJump`.

## User Request

Esa asked to do GitHub issues #683 and #680, with emphasis on finishing a few items before token exhaustion.

## Implementation Notes

Issue #680 already had pattern fraction jump machinery in `PakettiPatternEditor.lua` for /2, /4, /8, and /16. I extended it so the same fraction commands are available from Global keybinding context as well as Pattern Editor context.

Issue #683 had a previous-position toggle for fraction jumps, but explicit row jumps in `PakettiRequests.lua` did not have an amount-based "same jump back" command. I added last-jump state for pattern row jumps and song row jumps, then added commands that apply the opposite direction with the same amount. Repeating the reverse command toggles because the reverse jump becomes the newly stored jump.

I also adjusted song row jumps during playback-follow mode to derive the source position from `transport.playback_pos`, matching the existing playback behavior that starts transport at a `SongPos`.

## Verification

- `luac -p PakettiRequests.lua` passed
- `luac -p PakettiPatternEditor.lua` passed

Runtime verification in Renoise was not performed from this shell session.
