# Paketti — Claude Working Notes

This file is the **first thing to read** before answering any question or writing any code in this repo. The full development reference is in the `paketti` skill (`~/.claude/skills/paketti/SKILL.md`); this file captures the *hierarchy*, *cross-module wiring*, and *house rules that keep tripping me up*.

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

### Akai sampler cluster

`PakettiAKAI.lua` (entry), `PakettiAkaiFormats.lua` (shared parsers), then per-device: `PakettiAkaiMPC2000.lua`, `PakettiAkaiS900.lua`, `PakettiAkaiS1000.lua`, `PakettiAkaiS3000.lua`, `PakettiAkaiPrograms.lua`.

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

## House Rules (load-bearing — violating these breaks the tool)

These extend the rules already in the `paketti` skill (which you've read). The ones below have caused real production incidents:

1. **Keybinding names: exactly 3 colon-separated parts.** `Global:Paketti:Plugin Slots:Toggle Slot 1` crashes Renoise at boot and prevents the **entire tool** from loading. Menu entries can have multi-colon subcategories; keybindings cannot. Flatten subcategories into the name part using spaces. (Real incident: Feb 2026, broke Paketti for all users overnight.)

2. **Use `PakettiAddMenuEntry{}`, not `renoise.tool():add_menu_entry{}`** for menu entries. The wrapper handles sortable ordering across all ~500 entries.

3. **Preferences need TWO things**: declared in `Paketti0G01_Loader.lua`'s `renoise.Document.create("ScriptingToolPreferences")` block AND saved via `preferences:save_as("preferences.xml")` after every change. `add_property()` alone does NOT persist.

4. **Never call `renoise.song()` at file load time.** Wrap in functions. No song exists during boot.

5. **Lua 5.1 only** — no `goto`, no `::label::`. Use `if/return/break/repeat/until`.

6. **Always update `manual/CHANGESLOG.md`** for every shipped change. Insert above the most recent dated entry. Format: `### YYYY-MM-DD - Type: Title` followed by a paragraph listing menu entries (full paths), keybindings (full names), MIDI mappings.

7. **Always commit + push after every change** (`master` branch). The user does not run a build step — the working tree is the release.

8. **`AHDSR` ≠ `LFO`**: `SampleAhdrsModulationDevice` has `attack/hold/duration/sustain/release`. `SampleLfoModulationDevice` has `mode/phase/frequency/amount/amplitude/delay`. There is no `.amplitude` on AHDSR.

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

1. **Grep the codebase** — `grep -rn "<keyword>" --include="*.lua" -l` — to locate any existing implementation.
2. **Read the owning file** to understand the actual API surface, not theorize about it.
3. **Estimate scope based on what exists**, not on what would need to be built from scratch.
4. **Confirm with the user** before writing code if it's a substantial feature.
5. **Build** — reuse existing infrastructure, don't duplicate engines.
6. **Update CHANGESLOG.md** in the same turn.
7. **Commit + push** in the same turn.
