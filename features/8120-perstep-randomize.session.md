# Groovebox 8120 Per-Step randomization

## How to get back

- Source transcript: [source](file:///Users/esaruoho/.codex/sessions/2026/10/07/rollout-2026-10-07T20-17-51-01a1175f-1a8a-7980-939e-618862a400a2.jsonl)
- Session ID: 01a1175f-1a8a-7980-939e-618862a400a2
- Resume: `codex --resume 01a1175f-1a8a-7980-939e-618862a400a2`
- Verified UTC timestamp range at snapshot: 2026-10-07T17:40:53.824Z through 2026-10-07T17:49:52.884Z
- Lossless bundle: [8120-perstep-randomize.transcript.jsonl](8120-perstep-randomize.transcript.jsonl)
- Readable bundle: [8120-perstep-randomize.transcript.md](8120-perstep-randomize.transcript.md)

## Request

Esa requested a Randomize Per-Step button after each row's per-step selectors and a Global Randomize Per-Step button available only when Per-Step mode is enabled.

## Implementation

Each row button randomizes all its displayed sample selectors. Global action does the same for all rows. Both use samples present in the associated instrument, capped at 120; empty instruments are skipped. Changes update step_samples and selector text under the existing notifier guard, then print the row once. Step gates, Yxx values and Single-mode sample choices are not randomized. The global button starts with mode-dependent visibility and follows mode changes. Actions also guard against initialization and Single mode.

## Verification and delivery

Lua syntax and scoped whitespace checks passed. A temporary Lua mock verified 8/16/32 selectors, matching state/text, bounds, empty instruments, the 120 cap, one print per row, eight-row global updates, mode guards and visibility transitions. Live Renoise testing remains unverified. Worktree delivery only; no commit or push performed.

Card: [8120-perstep-randomize.feature](8120-perstep-randomize.feature). Bundles are snapshots taken during implementation.

## Label refinement

Esa requested the global button be renamed to “Random Per-Steps” to reduce its width. Updated only the global button label and the card’s corresponding claim; the row button remains “Randomize Per-Step”. Lua syntax verification passed.
