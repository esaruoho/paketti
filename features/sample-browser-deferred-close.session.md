# Sample browser deferred loading and closure

The user reported intermittent Renoise 3.5.4 GUI crashes when pressing the opening shortcut again to load a sample. The supplied stack reports SIGSEGV in TWindowImpl::HandleModifiers. Inspection found synchronous loading, window closure and a Pattern Editor switch within global keyboard dispatch. This supports a window-lifetime hypothesis but does not prove native use-after-free.

The user supplied the proposed event sequence and asked to fix it by staggering operations. Codex deferred the entire confirmation or cancellation to a one-shot 50 ms timer, guarded duplicate actions and repeats, froze interaction while pending, and cancelled work on document release. The original loading/target rules remain in the deferred body.

Verification: Lua syntax check and mocked-host regression harness passed for shortcut confirmation, Return, Escape, repeats, duplicate requests, navigation freeze, document release and externally closed windows. The first harness run failed because its target instrument mock remained occupied for a second load; resetting the mock between cases resolved that fixture defect. Native Renoise crash reproduction and live verification have not been performed.

Card: [sample-browser-deferred-close.feature](sample-browser-deferred-close.feature).
Source transcript: bundled beside this session as JSONL and readable Markdown, captured during this turn (later tool results are not present in that snapshot).

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/02/rollout-2026-10-02T13-40-27-01a0fc33-7c7e-7751-9b9b-782224bb9388.jsonl
- Session ID: 01a0fc33-7c7e-7751-9b9b-782224bb9388 (matched to CODEX_THREAD_ID and transcript metadata).
- Resume: `codex --resume 01a0fc33-7c7e-7751-9b9b-782224bb9388`
- Exact source timestamps are retained in the bundled transcript; session date 2026-10-02.

RESULT: Working-tree implementation only; no commit, push or PR; runtime untested.

## Follow-up: restore forwarding and import folders

The user reported that octave keys were swallowed, Cmd-CapsLock no longer confirmed, and Shift-Enter did not import folders. Git inspection identified commit `0222b895a534cbe9fae5ad90e10d506505ae624d` as changing the unhandled-key return from `return key` to Space-only forwarding, breaking both existing controls. Codex restored forwarding and allowed modified piano keys to reach global bindings, preserving the deferred action guard.

Shift-Enter now queues an import of the selected folder's directly contained loadable files, sorted alphabetically, using the existing empty-target/default-template loader once per file. Empty folders remain open. This uses separate instruments, consistent with the existing single-file browser behavior; nested directories are not traversed.

The expanded harness passes for octave keys including ISO Shift-<, Cmd-CapsLock forwarding plus global-binding confirmation, modified piano keys, folder sort/order, separate targets, and empty-folder behavior. Syntax and scoped whitespace checks pass. No live Renoise verification or new commit/push/PR was performed for this follow-up.
