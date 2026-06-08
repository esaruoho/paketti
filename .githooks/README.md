# `.githooks/` — self-maintaining report-card RESULT-LOG

Installed by `convey hooks install`. These hooks keep the **RESULT leg** of every
report card current straight from git: after each commit or merge, a dated line is
appended to each `*.feature` card whose WATCHed symbols actually changed.

Git does **not** run hooks from a tracked directory automatically (a clone running
arbitrary committed scripts would be a security hole), so each clone opts in once:

```bash
git config core.hooksPath .githooks
```

`convey hooks install` sets that for you in the target repo. Verify with
`git config core.hooksPath` (should print `.githooks`). Disable with
`git config --unset core.hooksPath`.

## What's here

- **`pre-commit`** — the everyday direct-to-commit path. Stamps cards whose
  WATCHed symbols are in the *staged* diff and `git add`s the card so the stamp
  rides into the same commit. Direct lines carry no self-SHA (the commit doesn't
  exist yet); recover it with `git blame` / `git log -L` on the line.
- **`post-merge`** — the merge / PR / non-ff-pull path. Records the merge SHA and
  PR number.
- **`report-card-stamp.sh`** — the shared engine both hooks call.

## How a card opts in

Two header lines in any tracked `*.feature` (under `features/` or
`principles/<id>/intent.feature`):

```
# WATCH: SymbolA SymbolB SymbolC ...
# RESULT-LOG >> (auto-maintained by convey hooks — newest below)
```

- **Mapping is by symbol, not filename** — a card is logged only when one of its
  WATCHed symbols appears on a changed (`+`/`-`) line, so touching an unrelated
  part of a shared file doesn't tag every card.
- **A WATCH line must be bare symbols, not prose** — tokens are matched as
  substrings; a word like `the` would match almost any diff. A card with no
  machine-watchable innards should carry no `# WATCH:` line.
- **Card homes (`features/`, `principles/`) and `.githooks/` are excluded** from
  the scanned diff, so a card edit or a hook edit can't self-tag.
- **Neither hook can break a commit or a merge** — both are defensive and exit 0.
- **Safe to re-run** — the merge path dedups by SHA; the commit path stamps once
  per commit by construction.

An appended line looks like:

```
#   2026-06-03  PR #3  merge 9493101  touched: F_SetControlInstrument   <- merge path
#   2026-06-03  direct-commit  touched: Glbl_F11                        <- direct path
```
