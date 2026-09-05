# Feature Test Status — GENERATED, DO NOT EDIT BY HAND

> Computed by `gen-status.py` from the `@grade` tags in `*.feature`.
> The cards are the source of truth; this table is derived. The pre-commit
> hook regenerates it whenever a card changes, so nobody hand-types
> "runtime-verified" into an index again. Hand edits here will be
> overwritten -- change the card's tags instead.
>
> Runtime = exercised live in Renoise. MIDI hardware = confirmed on the actual controller.
>
> `~ partial` = some scenarios verified, some still untested.

| Card | Scn | Build | Runtime (Renoise) | MIDI hardware | Grades present |
|------|----:|:-----:|:----------:|:--------:|----------------|
| 2026-06-11-groovebox-controller-follow-and-menu | 9 | ✓ | — | ✗ | @built @code-verified @hw-untested @logic-verified @superseded |
| 2026-06-11-ui-fixes-and-menu-config | 8 | ✓ | ✓ | — | @built @code-verified @logic-verified @runtime-verified |
| device-hotswap-missing-to-actual | 9 | ✗ | — | — | @designed |
| device-toggle-automation | 4 | ✓ | ✗ | — | @built @code-verified @runtime-untested @shipped @stock |
| eq10-keyboard-controls | 2 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped |
| execute-command-slots | 7 | ✓ | ✗ | — | @built @code-verified @runtime-untested @shipped @stock |
| groovebox-8120-default-instrument-slots | 3 | ✓ | ✗ | — | @built @code-verified @runtime-untested @untested-in-renoise |
| groovebox-8120-grid-controllers | 12 | ✓ | — | ✓ | @built @code-verified @hw-verified |
| groovebox-8120-lpd8 | 6 | ✓ | ✗ | ✓ | @built @code-verified @hw-verified @runtime-untested @untested-in-renoise |
| groovebox-8120-record-pakettified-instrument | 2 | ✓ | ✗ | — | @built @code-verified @runtime-untested @untested-in-renoise |
| issue-followup-utilities | 4 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped |
| master-low-cut-200hz | 3 | ✗ | — | ✓ | @hw-verified |
| mcp-claude-bridge | 11 | ✓ | — | ✓ | @built @code-verified @hw-verified @untested |
| mlx-renoise-bridge | 10 | ✓ | — | ✓ | @built @code-verified @designed @hw-verified |
| music-mouse | 36 | ✓ | ✓ | — | @built @code-verified @mcp-verified @runtime-verified @stock @user-verified |
| parameter-editor-mixer-and-config | 7 | ✓ | ✓ | — | @built @code-verified @feasibility @in-renoise @logic-verified @runtime-verified @untested |
| pattern-song-jumps | 4 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped @stock |
| pattern-transform-shortcuts | 3 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped |
| quick-edit-navigation | 4 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped @stock |
| repeater-control | 5 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped @stock |
| sample-slice-selection | 3 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped @stock |
| section-loop-immediate-switch | 5 | ✓ | ✗ | — | @built @code-verified @runtime-untested @shipped @stock |
| section-loop-midi-capture | 3 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped |
| selection-reversed-instrument | 4 | ✓ | ✗ | — | @built @code-verified @runtime-untested @shipped @stock |
| song-lifecycle-safety | 3 | ✓ | ✗ | ✓ | @built @code-verified @hw-verified @runtime-untested @untested-in-renoise |
| subcolumn-only-invert | 3 | ✓ | ✗ | — | @code-verified @runtime-untested @shipped @stock |
| tx16w-cyclone-images | 9 | ✓ | ✓ | — | @built @code-verified @runtime-verified @shipped @stock |

## Tally (computed)
- Cards: 27
- Build-verified: 25
- Runtime-verified: 4 full + 0 partial
- **Hardware-verified: 6**  ·  hardware-untested: 1

