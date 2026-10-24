# Dynamic View startup preferences fix

User supplied a startup overload traceback at loadDynamicViewPreferences line 107. Inspection found that Paketti0G01_Loader.lua assigns DynamicViewPrefs to preferences.PakettiDynamicViews, declared as a DocumentList. The modified Dynamic Views module reused this global and skipped creating its own document. A regression harness reproduces the failure at the same call with a strict list mock.

Reset the global before the existing document-construction block. This preserves global access for navigation while ensuring standalone XML loading uses the correct node. Existing F2/F3 worktree changes were preserved. Regression checks cover pre-existing list, saved values, reload and absent XML; the existing F2/F3 harness and Lua syntax check pass. Renoise runtime remains untested.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/24/rollout-2026-10-24T11-43-52-01a16d14-a745-7fc1-a3af-4ac919caef13.jsonl
- Session ID: 01a16d14-a745-7fc1-a3af-4ac919caef13
- Resume: `codex --resume 01a16d14-a745-7fc1-a3af-4ac919caef13`
- Verified snapshot timestamps: 2026-10-24T08:43:55.059Z through 2026-10-24T08:45:13.307Z.
- Bundled source: [JSONL](dynamic-view-preferences.transcript.jsonl), [readable transcript](dynamic-view-preferences.transcript.md).
- Card: [dynamic-view-preferences.feature](dynamic-view-preferences.feature).

RESULT: Worktree fix; no commit, push or PR. Transcript snapshot taken before final documentation generation.
