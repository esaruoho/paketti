# Music Mouse and the 200-local ceiling — why it happens, and the plan

*Written 2026-08-31, after adding six helpers to `PakettiMusicMouse.lua` and having `luac`
refuse the file with `too many local variables (limit is 200) in main function`.*

## The rule

Lua 5.1 — the version Renoise runs — allows **200 local variables live at once inside any one
function**. A `.lua` file *is* a function (Lua calls it the "main chunk"), so **every top-level
`local` in a Paketti module spends one of those 200**.

Two things make this nastier than a normal limit:

- **It is a compile error, not a runtime one.** Over the line, the file does not load at all.
  In Renoise that arrives as a brittle file and an aborted tool load — the user sees a broken
  Paketti, with no warning beforehand.
- **The count is of *names*, not of `local` lines.** `local a, b, c = f()` spends three.

## Why Music Mouse hits it and 8120 doesn't

Measured with the real compiler (append N dummy locals, ask whether it still builds):

| File | Lines | Chunk-level locals | Headroom |
|------|-------|--------------------|----------|
| `PakettiMusicMouse.lua` (before) | 3,551 | **180** | 20 |
| `PakettiEightOneTwenty.lua` | 10,842 | 126 | 74 |
| `PakettiCanvasExperiments.lua` | 3,454 | 83 | 117 |
| `PakettiHyperEdit.lua` | 5,423 | 56 | 144 |
| `PakettiPolyendPatternData.lua` | — | 34 | 166 |
| `PakettiAutomationCurves.lua` | — | 1 | 199 |

**8120 is three times the size and uses 54 fewer locals.** So this is not a complexity problem —
it is a *declaration-style* problem. The difference is one habit:

| | Music Mouse | 8120 |
|---|---|---|
| top-level `local function` | **112** | 96 |
| top-level `function` (global) | 37 | **169** |

8120 declares most of its functions as plain prefixed globals. Music Mouse declares almost
everything `local`. `PakettiHyperEdit.lua` is the extreme of the good case: **zero**
`local function` at top level, 86 globals, 144 headroom.

Music Mouse's 180 break down as:

- **112** `local function` — all of them `mm_`-prefixed
- **47** constants — 36 `MM_*` (`MM_SCALES`, `MM_PATTERNS`, every `*_ITEMS` popup list, the
  Launchpad palette, the geometry) plus 11 more (`PLAY_X0`, `DISPLAY_SPAN`, `TWO_PI`, `LBL`, …)
- **21** mutable state / forward declarations (`mm`, `vb`, `dialog`, `mm_canvas`,
  `mm_update_panel`, `mm_record_write`, …)

## The guard (done)

`python3 .spine/check.py` now reports local-variable headroom for every file in the repo, using
`.spine/localroom.lua` — which appends dummy locals and asks the actual compiler, so the number
is exact rather than an estimate. It prints a **warning** (not a build failure) for any file
with fewer than 25 locals left:

```
⚠️  1 FILE(S) LOW ON LOCAL-VARIABLE HEADROOM ...
   • PakettiMusicMouse.lua — room for 20 more top-level `local`s
```

It runs under both `lua` and `luajit`, whose error wordings differ, and it ignores files that
end in a top-level `return` (`base64.lua`, the `PakettiMCP/` modules) where appending anything
is a syntax error for unrelated reasons. Across the whole tree only two files are anywhere
near: Music Mouse, and `PakettiChebyshevWaveshaper.lua` at 50.

## Phase 1 — `do ... end` around the Launchpad section (done)

Locals inside a `do ... end` block go out of scope at the `end`, and Lua hands their registers
back. The Launchpad section (~190 lines) declares 16 locals, exposes only
`PakettiMusicMouseLaunchpad*` globals, and — verified by scanning every later line — leaks
nothing. Wrapping it costs **no renames and no new globals**.

**20 → 36 headroom.** Reloaded live and confirmed the Launchpad globals still resolve and run.

## Phase 2 — promote the `mm_` helpers to globals (recommended next)

`sed 's/^local function mm_/function mm_/'`. That is the entire change: no call site moves,
because the names do not change.

Measured on a scratch copy:

| Variant | Headroom |
|---------|----------|
| today (after Phase 1) | 36 |
| promote the 46 helpers from the Waveforms section onward (UI, panel, pattern editor, dialog, keys) | **66** |
| promote all 112 | **132** |

Why this is safe here:

- All 112 are already `mm_`-prefixed, and a scan of every other `.lua` in the repo found
  **zero** name collisions.
- Globals resolve at *call* time, so it removes a whole bug class rather than adding one —
  the "a `local function` is invisible to anything defined above it" trap (skill rule 28,
  which bit `PakettiAmigo.lua` twice in one day) simply cannot happen to a global.
- It is the house style of the two largest comparable files (8120, HyperEdit).
- Strict-globals is satisfied: every one is assigned at file load, before any call.

The one real cost: a global is a hash lookup where a local is a register read. Keep the
per-pixel canvas render helpers and the 16 ms timer path local; promote the UI, panel,
Launchpad and keyboard helpers, which run once per user action. That is exactly the
46-function variant above, and it buys 30 with no measurable performance question.

## Phase 3 — namespace the constants (if more is needed)

47 constant names → about 5 tables (`MM.geom`, `MM.ui`, `MM.scale`, `MM.cfg`, `MM.lp`) is
worth roughly **42**. It is arithmetic rather than a measurement, and unlike Phase 2 it is a
real rename touching every use site, so it is the *last* lever, not the first.

## Phase 4 — split the module (only if the file keeps growing)

The section boundaries are already clean, and the phrase-arpeggio section is halfway there
(18 globals). A split into core / UI / Launchpad gives each file its own fresh 200. It
requires the shared state (`mm`, `vb`, `dialog`) and the shared helpers to become globals —
i.e. Phase 2 done thoroughly — plus `timed_require` ordering in `main.lua`. Do not start here.

## The order to actually do this in

1. **Guard first** so the wall is never hit by surprise again — done.
2. **Phase 1** (`do ... end`, zero renames) — done, +16.
3. **Phase 2** when headroom next drops below ~20. Start with the 46 non-hot-path helpers (+30);
   go to all 112 (+96) only if that is not enough.
4. Phases 3 and 4 are held in reserve. On the measured numbers they should never be needed.
