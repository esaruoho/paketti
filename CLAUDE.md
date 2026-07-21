# Paketti — Claude Working Notes

This file is the **first thing to read** before answering any question or writing any code in this repo. The full development reference is in the `paketti` skill (`~/.claude/skills/paketti/SKILL.md`); this file captures the *hierarchy*, *cross-module wiring*, and *house rules that keep tripping me up*.

## Rule -1 — ALWAYS PULL BEFORE DOING ANYTHING

**Before reading files, grepping, or making any claims about the codebase**, run:

```bash
cd /Users/esaruoho/work/paketti && git fetch origin && git pull origin master
```

This is non-negotiable. The local working tree can be behind `origin/master` — other sessions, other machines, or the user themselves may have pushed changes. Reading stale local files and then confidently saying "this variable doesn't exist" when it's been on `origin/master` for days is unacceptable.

**Real incident (2026-05-04):** I told the user that `PakettiEightOneTwentyFocusedRow` "has never existed in git history" — four times — because I was reading a stale local checkout. It was on `origin/master` the whole time. The user had to drag me through **six messages** saying things like "I think what you're ignoring is that you are not updating the repo," "please look at the remote main or master branch," and "you are simply not checked the branch" — and each time I deflected, theorized about corrupted installs, or doubled down on my wrong answer instead of just running `git fetch`. This wasted time and eroded trust.

**The pattern to break:** When the user says something contradicts my findings, my first action must be `git fetch origin && git pull origin master`, not another explanation of why I think I'm right. The user knows their own codebase better than a stale local checkout does.

### When working on branches

- Use **git worktrees** (`isolation: "worktree"` in Agent calls) for branch work so that `master` stays clean.
- If the user says "look at branch X," fetch first, then check it out in a worktree — never switch the main working tree off `master` without asking.
- If a branch exists on the remote but not locally, `git fetch origin` will make it available.

### Order of operations for every session

1. `git fetch origin && git pull origin master` (sync local master)
2. THEN grep / read / answer questions
3. If working on a branch: use a worktree

## Rule -0.5 — THIS CHECKOUT IS ON iCLOUD: FILES CAN BE EVICTED (0 bytes) AND `git commit` CAN SIGBUS

The working tree lives under iCloud Drive (`~/Library/Mobile Documents/…`; `/Users/esaruoho/work/paketti` is a symlink to it). The `.git` dir is off-iCloud at `/Users/esaruoho/.paketti-git` (safe). **iCloud evicts file *contents* to save space — leaving a "dataless placeholder": `ls` shows the real byte size, but reading the file returns 0 bytes.** This has two nasty consequences:

1. **A grep/read of an evicted file returns nothing — and that looks exactly like "the feature isn't there."**
   - **Real incident (2026-07-22):** asked whether Groovebox 8120's MODE2 (per-step sample mode) was implemented, I grepped `PakettiEightOneTwenty.lua`, got **zero hits**, and confidently said "not built — still a proposal." The file was an **evicted placeholder** (468 KB in `ls`, 0 bytes when read). MODE2 was **fully shipped** the whole time. The tell: `wc -l` = 0 and `grep -c "function"` = 0 on a 468 KB Lua file is impossible — it means the content isn't materialized, not that it's empty.
   - **Rule:** to inspect code reliably on this checkout, read from the git blob, not the working tree: **`git show HEAD:<file>`** (or `git cat-file -p HEAD:<file>`). The `.git` objects are on local disk and always readable. Only trust a working-tree read after confirming `cat <file> | wc -c` matches `ls`'s size.

2. **`git commit` / `git add -A` can crash with `Bus error: 10` (SIGBUS, exit 138).** git `mmap`s working-tree files during its full-tree index refresh; `mmap` of an evicted placeholder faults. You'll also see `error: short read while indexing …` spam and a stale `/Users/esaruoho/.paketti-git/index.lock` (a background `github-watcher.sh` grabs the lock every few minutes — check `ps` / `lsof` before removing it).
   - **Rule — commit via plumbing (object-DB only, never touches the working tree):**
     ```bash
     blob=$(git hash-object -w <path>)                       # reads only your materialized file
     GIT_INDEX_FILE=/tmp/t.idx git read-tree origin/master   # base on origin (it may be ahead via [skip ci] docs commits)
     GIT_INDEX_FILE=/tmp/t.idx git update-index --cacheinfo 100644,$blob,<path>
     tree=$(GIT_INDEX_FILE=/tmp/t.idx git write-tree)
     commit=$(git commit-tree $tree -p origin/master -m "msg")
     git update-ref refs/heads/master $commit
     git push origin $commit:master                          # fast-forward
     ```
   - Base on `origin/master` (not local `HEAD`): the `github-watcher`/CI pushes automated `docs: … [skip ci]` commits, so local is often behind.
   - **Root-cause fix (optional, user's call — pulls the whole AKWF set locally):** `brctl download /Users/esaruoho/work/paketti` to materialize everything, then normal git works.

## Rule 0 — SEARCH BEFORE THEORIZING

Paketti has **181 Lua files** and 1,180+ commits of accumulated infrastructure. Before claiming "we'd need to build X" or estimating that a feature is "~150 lines," **grep first**:

```bash
grep -rn "<keyword>" --include="*.lua" -l
```

Real example (2026-05-02): I told the user the Sidechain Curve Library would need ~150 lines for "XML preset injection into the LFO." A two-second grep would have shown `PakettiAutomationCurves.lua:322` already has `PakettiAutomationCurvesWriteToLFOCustom()` doing exactly that, with auto-detection of LFO devices in track DSP and sample FX chains. The actual feature was ~80 lines of *new shape math* plugging into existing infrastructure. **Theorizing without searching wastes the user's time and produces wrong scope estimates.**

If a question has the word "we already have" or "doesn't Paketti do" in it, that is a 100%-confidence signal to grep before responding.

## Module Hierarchy — Where Things Actually Live

### Cross-cutting shared infrastructure (read these first when touching anything)

| File | What it owns |
|------|-------------|
| `Paketti0G01_Loader.lua` | **Preferences source-of-truth** (`renoise.Document.create("ScriptingToolPreferences")` at line ~89–300); `PakettiAddMenuEntry{}` helper at line ~3965 (sortable menu wrapper — use this, NOT raw `add_menu_entry`); 0G01 command system; the doc layer |
| `main.lua` | Module load order via `timed_require()`. Load order matters when one file injects into another's globals (e.g. `PakettiSidechainCurves` must load AFTER `PakettiAutomationCurves` to mutate `PakettiAutomationCurvesShapes`) |
| `PakettiCompat.lua` | API-version compatibility (Renoise 2.8 / 3.1 / 3.5). 41 files refactored through it. When in doubt about a feature's API availability, check here |
| `PakettiMainMenuEntries.lua` | Menu organisation across the whole tool |
| `PakettiMenuConfig.lua` | The user-facing Menu Configuration dialog (Options menu) |
| `PakettiKeyBindings.lua` | Keybinding presets (paired with `KeyBindings/` folder) |
| `PakettiCanvasFont.lua` | Custom vector font for any canvas dialog (A–Z, 0–9, ä/ö/å, modifier keys, arrows, both orientations) |

### LFO Custom Waveform / Automation Curves cluster

`PakettiAutomationCurves.lua` is the **engine**. Anything that wants to draw shapes into a Custom LFO or automation envelope plugs into it.

| File | Role |
|------|------|
| `PakettiAutomationCurves.lua` | **Engine.** Owns `PakettiAutomationCurvesShapes` (global shape registry), `PakettiAutomationCurvesWriteToLFOCustom(name)` (XML injection into `*LFO` device — track DSP and sample FX chain auto-detected), `PakettiAutomationCurvesInsert(name)` (write into automation lane), the canvas dialog with bitmap shape buttons, length detection, repeat/divisor logic, offset/attenuation |
| `PakettiSidechainCurves.lua` | Sidechain shape pack (8 curves). Pure plug-in: injects new entries into `PakettiAutomationCurvesShapes`, registers menus/keybindings/MIDI. No engine duplication |
| `PakettiAutomation.lua` | Lower-level automation read/write helpers, clipboard |
| `PakettiAutomateLastTouched.lua` | Quick-automate the last-touched parameter |
| `PakettiAutomationStack.lua` | Multi-lane automation stack viewer (canvas) |

**Rule**: any new "curve / LFO custom envelope" feature should add shapes to `PakettiAutomationCurvesShapes` and reuse `PakettiAutomationCurvesWriteToLFOCustom`. Do not write a second LFO XML injector.

### Slicing cluster (lots of files — they overlap)

| File | Niche |
|------|-------|
| `PakettiSlice.lua`, `PakettiSlicePro.lua`, `PakettiSliceSafely.lua` | Core slicing operations |
| `PakettiManualSlicer.lua`, `PakettiSliceToolsDialog.lua` | UI dialogs |
| `PakettiSliceEffectStepSequencer.lua` | Per-slice step sequencer with canvas velocity bars |
| `PakettiOldschoolSlicePitch.lua` | Pitch-per-slice tracker-style |
| `PakettiZeroCrossings.lua` | Zero-crossing snap (used by all slicers) |
| `PakettiBeatDetect.lua` | **Transient/onset detection** (use this for any audio-analysis feature) |
| `PakettiHexSliceLoop.lua` | Hex-edit slice points |
| `PakettiStemSlicer.lua`, `PakettiSampleFXChainSlicer.lua` | Specialised slicers |
| `PakettiPolyendMelodicSliceExport.lua`, `PakettiPolyendSliceSwitcher.lua` | Polyend-specific slice export |

### Polyend Tracker cluster (full bidirectional project import/export)

| File | Role |
|------|------|
| `PakettiPTILoader.lua` | PTI import (binary parser) |
| `PakettiPolyendSuite.lua` | PTI export, auto-save, backup, WAV→PTI |
| `PakettiPolyendPatternData.lua` | MTP/MT project import + export, FX mapping (22/43), CRC32 |
| `PakettiPolyendSliceSwitcher.lua` | Velocity-mapped slice samples |
| `PakettiPolyendMelodicSliceExport.lua` | Mode-4 PTI export |

For binary format details, **always read the `polyend-tracker` skill first** — it has offset tables and FX maps.

### Format loaders/exporters

Loaders: `PakettiIFFLoader.lua`, `PakettiSF2Loader.lua`, `PakettiREXLoader.lua`, `PakettiRX2Loader.lua`, `PakettiMODLoader.lua`, `PakettiXMImport.lua`, `PakettiITIImport.lua`, `PakettiOTSTRDImporter.lua`, `PakettiStemLoader.lua`, `PakettiWavCueExtract.lua`, `PakettiWTImport.lua`.
Exporters: `PakettiITIExport.lua`, `PakettiXIExport.lua`, `PakettiOTExport.lua`.
Generic: `PakettiLoaders.lua`, `PakettiImport.lua`, `PakettiLoadDevices.lua`, `PakettiLoadPlugins.lua`.

### MIDI / Hardware controllers cluster

| File | Role |
|------|------|
| `PakettiMidi.lua` | Core MIDI helpers |
| `PakettiMidiImport.lua` | MIDI file import |
| `PakettiMidiPopulator.lua` | Generate MIDI patterns |
| `PakettiMIDIMappings.lua`, `PakettiMIDIMappingCategories.lua` | MIDI mapping registry |
| `PakettiCCizerLoader.lua` | CC controller mapping presets |
| `PakettiDigitakt.lua`, `PakettiZyklusMPS1.lua` | Device-specific |

### Pattern / Phrase clusters

Pattern: `PakettiPatternEditor.lua`, `PakettiPatternEditorCheatSheet.lua`, `PakettiPatternIterator.lua`, `PakettiPatternLength.lua`, `PakettiPatternMatrix.lua`, `PakettiPatternNameLoop.lua`, `PakettiPatternSequencer.lua`, `PakettiPatternDelayViewer.lua`.
Phrase: `PakettiPhraseEditor.lua`, `PakettiPhraseGenerator.lua`, `PakettiPhraseTransportRecording.lua`, `PakettiPhraseWorkflow.lua`.

### Canvas UI cluster (19+ files)

Anything drawing pixels into a Renoise dialog. See SKILL.md "Canvas Inventory" table for the full list. Key ones:

- `PakettiCanvasExperiments.lua` — the flagship Device Parameter Editor with live automation sync
- `PakettiEQ30.lua` — drawable 30-band EQ
- `PakettiPlayerProWaveformViewer.lua` — realtime per-track waveform
- `PakettiCanvasFont.lua` — text rendering library reused by all canvases

### Catch-all single-purpose files

Many files are self-contained features (e.g. `PakettiBPM.lua`, `PakettiBPMCalculator.lua`, `PakettiArpeggiator.lua`, `PakettiChords.lua`, `PakettiChordsPlus.lua`, `PakettiClipboard.lua`, `PakettiCommandWheel.lua`, `PakettiFill.lua`, `PakettiGater.lua`, `PakettiGlider.lua`, `PakettiTuningDisplay.lua`, `PakettiTupletGenerator.lua`, etc.). When the user names a feature, grep first — there is almost always an existing file that owns it.

## House Rules (violating these breaks the tool)

These extend the rules already in the `paketti` skill (which you've read). The ones below have caused real production incidents:

1. **Keybinding names: exactly 3 colon-separated parts.** `Global:Paketti:Plugin Slots:Toggle Slot 1` crashes Renoise at boot and prevents the **entire tool** from loading. Menu entries can have multi-colon subcategories; keybindings cannot. Flatten subcategories into the name part using spaces. (Real incident: Feb 2026, broke Paketti for all users overnight.)

2. **Use `PakettiAddMenuEntry{}`, not `renoise.tool():add_menu_entry{}`** for menu entries. The wrapper handles sortable ordering across all ~500 entries.

3. **Preferences need TWO things**: declared in `Paketti0G01_Loader.lua`'s `renoise.Document.create("ScriptingToolPreferences")` block AND saved via `preferences:save_as("preferences.xml")` after every change. `add_property()` alone does NOT persist.

4. **Never call `renoise.song()` at file load time.** Wrap in functions. No song exists during boot.

5. **Lua 5.1 only** — no `goto`, no `::label::`. Use `if/return/break/repeat/until`.

6. **Always update `manual/CHANGESLOG.md`** for every shipped change. Insert above the most recent dated entry. Format: `### YYYY-MM-DD - Type: Title` followed by a paragraph listing menu entries (full paths), keybindings (full names), MIDI mappings.

7. **Always commit + push after every change** (`master` branch). The user does not run a build step — the working tree is the release.

8. **`AHDSR` ≠ `LFO`**: `SampleAhdrsModulationDevice` has `attack/hold/duration/sustain/release`. `SampleLfoModulationDevice` has `mode/phase/frequency/amount/amplitude/delay`. There is no `.amplitude` on AHDSR.

9. **NEVER ship a duplicate `add_midi_mapping` / `add_keybinding` name — run `python3 .spine/check.py` before committing.** Renoise THROWS on the 2nd registration of a name (`invalid midi mapping entry: 'Paketti:X' was already added`) and **aborts the whole tool load** — a user sees a broken Paketti. Before adding any mapping, **grep the whole repo for the exact `name="Paketti:<...>"`** (the action usually already has one in its feature file). Do NOT map from the menu list assuming it lacks MIDI — the MIDI-GAPS/FEATURE-MAP analysis false-positives "missing". The `.spine` harness DEDUPS silently, so a registration-count check won't catch it; `.spine/check.py` runs the harness, replicates Renoise's duplicate guard, and exits 1 naming any duplicate or brittle file. CI (`main.yml` Job 0 `validate`) gates `create-release` on it. **Real incident (2026-06-20):** 13 duplicate MIDI mappings shipped → Renoise crashed at load → a user reported "it doesn't work" (fixed `25fdcbde` + `cb8d61f8`).

## Cross-Module Globals to Know

These globals are declared in one file and read/mutated by many. Search before adding new ones with similar names:

| Global | Owner | Used by |
|--------|-------|---------|
| `PakettiAutomationCurvesShapes` | `PakettiAutomationCurves.lua` | Sidechain Curves, any future curve pack |
| `PakettiAutomationCurvesWriteToLFOCustom` | `PakettiAutomationCurves.lua` | Anything writing custom LFO envelopes |
| `PakettiAddMenuEntry` | `Paketti0G01_Loader.lua` | Almost every file |
| `preferences` | `Paketti0G01_Loader.lua` | Tool-wide |
| `PAKETTI_PLAYMODE_CURVES`, `PAKETTI_PLAYMODE_LINES`, `PAKETTI_PLAYMODE_POINTS` | `PakettiAutomationCurves.lua` (or earlier) | Shape playmode constants |

## Workflow

When the user names a feature or asks "can we…":

0. **Pull first** — `git fetch origin && git pull origin master` — to ensure local state matches remote.
1. **Grep the codebase** — `grep -rn "<keyword>" --include="*.lua" -l` — to locate any existing implementation.
2. **Read the owning file** to understand the actual API surface, not theorize about it.
3. **Estimate scope based on what exists**, not on what would need to be built from scratch.
4. **Confirm with the user** before writing code if it's a substantial feature.
5. **Build** — reuse existing infrastructure, don't duplicate engines. Use worktrees for branch work.
6. **If you added any registration, run `python3 .spine/check.py`** — must print `✅ clean` (0 duplicate mappings/keybindings, 0 brittle). A duplicate aborts the whole tool load in Renoise (see rule 9).
7. **Update CHANGESLOG.md** in the same turn.
8. **Commit + push** in the same turn.
