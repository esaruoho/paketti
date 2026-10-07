# Live Step Names experiment

## How to get back

- Source: [transcript](file:///Users/esaruoho/.codex/sessions/2026/10/07/rollout-2026-10-07T20-17-51-01a1175f-1a8a-7980-939e-618862a400a2.jsonl)
- Session ID: 01a1175f-1a8a-7980-939e-618862a400a2
- Resume: `codex --resume 01a1175f-1a8a-7980-939e-618862a400a2`
- Verified UTC timestamps at snapshot: 2026-10-07T17:40:53.824Z through 2026-10-07T18:01:09.869Z
- Lossless bundle: [8120-live-sample-names.transcript.jsonl](8120-live-sample-names.transcript.jsonl)
- Readable bundle: [8120-live-sample-names.transcript.md](8120-live-sample-names.transcript.md)

## Request and choices

Esa supplied a screenshot of the wide sample-name button and requested an experiment, initially ON, where the button follows different Per-Step samples as the cycling step highlighter reaches them. A checkbox must allow disabling the experiment if the display is not useful.

Implemented a persistent default-true Live Step Names checkbox in the global controls. The label follows each row's existing play_step_index, including inactive steps and the editing cursor while stopped. Frozen highlighter windows restore the normal label. Disabling the checkbox or switching to Single mode restores normal labels immediately. The existing label updater resolves the current step too, so ordinary refreshes do not overwrite the live name with the static name.

The existing 40ms highlighter timer checks sample names, assigning text only when it changes. This also catches edits or randomization at the current step. No timer is added; no sample selection, mapping or pattern data changes are introduced. Missing or unnamed samples display Sample N; names longer than 50 characters are truncated as before.

## Verification and result

Lua syntax and scoped whitespace checks passed. A temporary Lua mock verified step changes, inactive-step display, no repeated assignments for unchanged text, edits at the same step, unnamed fallback, truncation, preference and mode guards, frozen-window restoration, stopped-cursor following and selection preservation. Live Renoise visual verification remains untested. Delivered in the worktree; no commit, push or PR made.

Card: [8120-live-sample-names.feature](8120-live-sample-names.feature). Transcript bundles are implementation-time snapshots.
