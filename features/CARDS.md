# Paketti — Feature Reference

> **Generated** from the Gherkin report cards in this folder by `python3 print-card.py --readme`. Do not hand-edit — edit the `.feature` card and regenerate. Each entry below = one card: *what it does* (intent + behaviour scenarios) and *how it does it* (the procs/files the behaviour is cited to).

Each card is a triad: the `.feature` spec, a `.session.md` (the conversation that produced it), and a RESULT-LOG of what shipped.

## Contents

- [<Short name of the thing Paketti does>](#TEMPLATE) — `TEMPLATE.feature`
- [Device hotswap — missing plugins → actually-installed equivalents](#device-hotswap-missing-to-actual) — `device-hotswap-missing-to-actual.feature`
- [Device Control actions record bypass automation](#device-toggle-automation) — `device-toggle-automation.feature`
- [EQ10 keyboard controls](#eq10-keyboard-controls) — `eq10-keyboard-controls.feature`
- [Execute configurable shell commands](#execute-command-slots) — `execute-command-slots.feature`
- [Groovebox 8120 fills 8 instrument slots with the Paketti Default Instrument on empty-song open](#groovebox-8120-default-instrument-slots) — `groovebox-8120-default-instrument-slots.feature`
- [Groovebox 8120 grid controllers (Akai MidiMix + APC Key 25 + LPD8)](#groovebox-8120-grid-controllers) — `groovebox-8120-grid-controllers.feature`
- [Groovebox 8120 — AKAI LPD8 controller (8 pads + pages + follow + row select)](#groovebox-8120-lpd8) — `groovebox-8120-lpd8.feature`
- [Groovebox 8120 Record button records into a Pakettified instrument](#groovebox-8120-record-pakettified-instrument) — `groovebox-8120-record-pakettified-instrument.feature`
- [Issue follow-up utilities](#issue-followup-utilities) — `issue-followup-utilities.feature`
- [Master Low-Cut 200Hz punch toggle](#master-low-cut-200hz) — `master-low-cut-200hz.feature`
- [Paketti × Claude MCP + probe bridges (Renoise ↔ Claude)](#mcp-claude-bridge) — `mcp-claude-bridge.feature`
- [Human → local-LLM → Renoise bridge (zero Claude, zero Anthropic tokens)](#mlx-renoise-bridge) — `mlx-renoise-bridge.feature`
- [Music Mouse — Laurie Spiegel's "Intelligent Instrument" (1986) in Renoise](#music-mouse) — `music-mouse.feature`
- [Parameter Editor exposes on the Mixer the parameter you're modifying](#parameter-editor-mixer-and-config) — `parameter-editor-mixer-and-config.feature`
- [Pattern Editor note manipulation](#pattern-editor-example) — `pattern-editor-example.feature`
- [Pattern and song row jumps](#pattern-song-jumps) — `pattern-song-jumps.feature`
- [Pattern transform shortcuts](#pattern-transform-shortcuts) — `pattern-transform-shortcuts.feature`
- [Quick edit navigation commands](#quick-edit-navigation) — `quick-edit-navigation.feature`
- [Repeater control from keys and MIDI](#repeater-control) — `repeater-control.feature`
- [Sample slice selection range](#sample-slice-selection) — `sample-slice-selection.feature`
- [Section loop switches trigger immediately](#section-loop-immediate-switch) — `section-loop-immediate-switch.feature`
- [Section loop and MIDI capture](#section-loop-midi-capture) — `section-loop-midi-capture.feature`
- [Reverse-duplicate instrument for pattern selections](#selection-reversed-instrument) — `selection-reversed-instrument.feature`
- [Song-lifecycle safety for canvas dialogs and song observers](#song-lifecycle-safety) — `song-lifecycle-safety.feature`
- [Subcolumn-only pattern inversion](#subcolumn-only-invert) — `subcolumn-only-invert.feature`
- [TX16W IMG exports use Cyclone-compatible item identity](#tx16w-cyclone-images) — `tx16w-cyclone-images.feature`


<a id="TEMPLATE"></a>
## <Short name of the thing Paketti does>

`features/TEMPLATE.feature`

**What it does:** Context: <Renoise context>      # Global | Pattern Editor | Sample Editor | Instrument Box | Mixer | Phrase Editor | Sample Mappings | DSP Device | Main Menu | …

**Behaviour (2 scenarios):**

- <what happens, in a few words>
- <another behavior>


<a id="device-hotswap-missing-to-actual"></a>
## Device hotswap — missing plugins → actually-installed equivalents

`features/device-hotswap-missing-to-actual.feature`

**What it does:** Context: Mixer

**Behaviour (9 scenarios):**

- Scan a folder of .xrns and report missing devices per song — `@designed`
- Scan the currently-open song only — `@designed`
- A curated "this legacy -> this actual" map drives the swap — `@designed`
- User adds a mapping from an unresolved missing device — `@designed`
- Auto-suggest a mapping when names obviously match — `@designed`
- Hotswap a missing device and carry its settings across by name — `@designed`
- Positional fallback when both expose the same parameter count — `@designed`
- Batch hotswap across a whole song — `@designed`
- Never destroy the original on an ambiguous swap — `@designed`

**Grade:** @designed ×9


<a id="device-toggle-automation"></a>
## Device Control actions record bypass automation

`features/device-toggle-automation.feature` · [session](device-toggle-automation.session.md)

**What it does:** As a Paketti user, I want Device Control NN enable/disable/toggle actions to record automation, So that hardware or shortcut-driven device bypass moves become part of the pattern.

**Behaviour (4 scenarios):**

- Pattern Effects mode writes x000 or x001 — `@shipped @built @code-verified @runtime-untested`
- Graphical Automation mode writes the Active envelope — `@shipped @built @code-verified @runtime-untested`
- Follow-player decides cursor versus playhead line — `@shipped @built @code-verified @runtime-untested`
- Edit Mode off keeps Device Control as a live toggle only — `@stock`

**How it does it:** **Key procs:** `PakettiDeviceBypass`, `PakettiRecordDeviceBypassAutomation`, `PakettiWriteDeviceBypassPatternCommand`, `PakettiWriteDeviceBypassGraphicalAutomation` · **Source files:** `PakettiRequests.lua`

**Grade:** @built ×3 · @code-verified ×3 · @runtime-untested ×3 · @shipped ×3 · @stock ×1


<a id="eq10-keyboard-controls"></a>
## EQ10 keyboard controls

`features/eq10-keyboard-controls.feature` · [session](eq10-keyboard-controls.session.md)

**What it does:** As a Paketti user, I want quick keyboard control of EQ10 bands, So that I can shape gains without reaching for each GUI control.

**Behaviour (2 scenarios):**

- Shift-number shortcuts raise individual EQ10 bands — `@shipped @code-verified @runtime-untested`
- Shift-QWERTY shortcuts lower individual EQ10 bands — `@shipped @code-verified @runtime-untested`

**How it does it:** **Key procs:** `adjust_eq10_band_gain`, `pakettiEQ10XYDialog` · **Source files:** `PakettiExperimental_Verify.lua`

**Grade:** @code-verified ×2 · @runtime-untested ×2 · @shipped ×2


<a id="execute-command-slots"></a>
## Execute configurable shell commands

`features/execute-command-slots.feature` · [session](execute-command-slots.session.md)

**What it does:** As a Paketti user, I want labeled shell-command slots, So that keybindings and MIDI controls can launch scripts or external tools.

**Behaviour (7 scenarios):**

- 128 labeled command slots persist independently — `@shipped @built @code-verified @runtime-untested`
- Dialog edits and runs the selected slot — `@shipped @built @code-verified @runtime-untested`
- Shortcut and MIDI mappings trigger every slot — `@shipped @built @code-verified @runtime-untested`
- Selected sample range is exported through the $s placeholder — `@shipped @built @code-verified @runtime-untested`
- Existing ten-slot launch-app preferences remain migratable — `@shipped @built @code-verified @runtime-untested`
- User-facing menu and manual expose the feature — `@shipped @built @code-verified @runtime-untested`
- Other external-application and sample workflows remain separate — `@stock`

**How it does it:** **Key procs:** `PakettiCreateExecutePreferences`, `PakettiExecuteRunCommand`, `PakettiExecuteRunSlot`, `PakettiExecuteShowDialog`, `export_selected_range`, `command_with_selected_sample` · **Source files:** `Paketti0G01_Loader.lua`, `PakettiExecute.lua`, `PakettiMenuConfig.lua`, `manual/Experimental.md`

**Grade:** @built ×6 · @code-verified ×6 · @runtime-untested ×6 · @shipped ×6 · @stock ×1


<a id="groovebox-8120-default-instrument-slots"></a>
## Groovebox 8120 fills 8 instrument slots with the Paketti Default Instrument on empty-song open

`features/groovebox-8120-default-instrument-slots.feature`

**What it does:** Context: Global

**Behaviour (3 scenarios):**

- Opening 8120 on an empty song fills all 8 slots with the default instrument — `@built`
- Opening 8120 on a song that already has instruments leaves them untouched — `@built`
- New Song never triggers the auto-fill — `@built`

**Grade:** @built ×3


<a id="groovebox-8120-grid-controllers"></a>
## Groovebox 8120 grid controllers (Akai MidiMix + APC Key 25 + LPD8)

`features/groovebox-8120-grid-controllers.feature`

**What it does:** Context: Global

**Behaviour (12 scenarios):**

- APC pad toggles a step on the selected row (headless) — `@hw-verified`
- APC mid-row pad toggles per-step probability (headless) — `@hw-verified`
- APC bottom row selects the instrument/row — `@hw-verified`
- APC works headless via the Auto-Start setting — `@hw-verified`
- A MidiMix press reflects on the APC and vice-versa — `@hw-verified`
- LPD8 pages its 8 pads over the focused row (no forced step mode) — `@hw-verified`
- Follow is per-controller and independent — `@built`
- Each controller's follow persists and applies headlessly on the next session — `@built`
- APC follow restores the 16+16 paged layout at 32 steps — `@built`
- APC left non-rotating shows every step at 32 steps — `@built`
- MidiMix follow windows its 16 LEDs over a 32-step pattern — `@built`
- A controller's follow keybinding stays in sync with its own checkbox — `@built`

**Grade:** @built ×6 · @hw-verified ×6


<a id="groovebox-8120-lpd8"></a>
## Groovebox 8120 — AKAI LPD8 controller (8 pads + pages + follow + row select)

`features/groovebox-8120-lpd8.feature`

**What it does:** Context: Global

**Behaviour (6 scenarios):**

- 8 pads sequence the selected row (headless) — `@hw-verified`
- Do-nothing absorbers keep the pads from triggering samples — `@built`
- Flip a page through a 16/32-step pattern — `@hw-verified`
- Follow mode tracks the playhead across pages — `@hw-verified`
- 4 steps + 4 probability layout — `@built`
- Select the row with a single knob (three bindable copies) — `@built`

**Grade:** @built ×3 · @hw-verified ×3


<a id="groovebox-8120-record-pakettified-instrument"></a>
## Groovebox 8120 Record button records into a Pakettified instrument

`features/groovebox-8120-record-pakettified-instrument.feature`

**What it does:** Context: Global

**Behaviour (2 scenarios):**

- Record press loads a Paketti Default Instrument then starts recording — `@built`
- Second Record press injects the sample into the Paketti chassis — `@built`

**Grade:** @built ×2


<a id="issue-followup-utilities"></a>
## Issue follow-up utilities

`features/issue-followup-utilities.feature` · [session](issue-followup-utilities.session.md)

**What it does:** As a Paketti user, I want small workflow gaps closed, So that delay editing, automation editing, menu visibility, and eSpeak batch output behave predictably.

**Behaviour (4 scenarios):**

- Phrase delay nudging makes delay columns visible — `@shipped @code-verified @runtime-untested`
- Reverse selected automation — `@shipped @code-verified @runtime-untested`
- eSpeak can be hidden through Paketti Menu Config — `@shipped @code-verified @runtime-untested`
- Generate one eSpeak output per text line — `@shipped @code-verified @runtime-untested`

**How it does it:** **Key procs:** `PakettiPhraseEditorNudgeWithDelay`, `PakettiPhraseEditorNudgeByDelay`, `PakettiAutomationCurvesReverseSelection`, `PakettieSpeakGenerateLines` · **Source files:** `PakettiPhraseEditor.lua`, `PakettiAutomationCurves.lua`, `PakettiMenuConfig.lua`, `Paketti0G01_Loader.lua`, `PakettieSpeak.lua`

**Grade:** @code-verified ×4 · @runtime-untested ×4 · @shipped ×4


<a id="master-low-cut-200hz"></a>
## Master Low-Cut 200Hz punch toggle

`features/master-low-cut-200hz.feature`

**What it does:** Context: Global

**Behaviour (3 scenarios):**

- Punch in the low-cut — `@hw-verified`
- Punch it off — `@hw-verified`
- Momentary hold — `@hw-verified`

**Grade:** @hw-verified ×3


<a id="mcp-claude-bridge"></a>
## Paketti × Claude MCP + probe bridges (Renoise ↔ Claude)

`features/mcp-claude-bridge.feature`

**What it does:** Context: Global

**Behaviour (11 scenarios):**

- Start the MCP server — `@built @hw-verified`
- Any MCP client / curl discovers the tool surface — `@built @hw-verified`
- Claude READS live song state (the "watch it render" half) — `@built @hw-verified`
- Claude WRITES into the song (the bidirectional half) — `@built @hw-verified`
- The 79 tools span the whole Renoise object model — `@built @untested`
- Paketti-specific verbs drive Paketti's own dialogs over MCP — `@built @untested`
- Index conventions are non-uniform (inherited from ReMCP) — `@built @untested`
- Stop the server cleanly — `@built @untested`
- Dump arbitrary Renoise state for Claude to read off disk — `@built @untested`
- Zero-typing quick probes — `@built @untested`
- Talk to a Claude /loop session from a Renoise dialog — `@built @untested`

**Grade:** @built ×11 · @hw-verified ×4 · @untested ×7


<a id="mlx-renoise-bridge"></a>
## Human → local-LLM → Renoise bridge (zero Claude, zero Anthropic tokens)

`features/mlx-renoise-bridge.feature`

**What it does:** Context: Global

**Behaviour (10 scenarios):**

- Turning Auto-Start ON starts the server and keeps it up — `@built`
- The server survives a tool code-reload — `@built`
- The server survives a song load — `@built`
- Auto-Start defaults OFF — `@designed`
- One English line, run ON THE MINI, drives Renoise here — `@built @hw-verified`
- The Mini can reach this Mac's PakettiMCP over Tailscale — `@built @hw-verified`
- pakettimcp refuses cleanly when the server is down — `@built @hw-verified`
- pakettimcp drives Renoise from this Mac with a fractional tempo — `@built @hw-verified`
- "give me an amen break at 174" chains tempo + a composition generator — `@built @hw-verified`
- Multi-step chaining and graceful failure — `@built`

**Grade:** @built ×9 · @designed ×1 · @hw-verified ×5


<a id="music-mouse"></a>
## Music Mouse — Laurie Spiegel's "Intelligent Instrument" (1986) in Renoise

`features/music-mouse.feature` · [session](music-mouse.session.md)

**What it does:** Context: Global

**Behaviour (36 scenarios):**

- Open Music Mouse from the menu — `@built`
- Move the mouse to play a quantized 4-voice chord — `@built`
- Generate a Pakettified Bell instrument by default — `@built`
- 4 voices is classic Music Mouse; 5-9 give richer chords — `@built`
- Record what you play into the pattern (right-shift) — `@built`
- Gravitation seeds and Gravity Play — `@built`
- Music Mouse owns its keys but lets your shortcuts through — `@built`
- Sync the pattern player to the song BPM, controllable by MIDI — `@built`
- tab cycles the selected instrument through Paketti's microtonal tunings — `@built`
- A Launchpad plays Music Mouse and runs a Raindrops light show — `@built`
- Loudness persists and never boots silent — `@built`
- Changing a control never re-strikes the chord (and never sounds while frozen) — `@built`
- Chord changes are batched so there is no MIDI jitter — `@built`
- Pattern Applies = Melody sequences one voice over a sustained chord (no flood) — `@built`
- Recording auto-widens the track to the voice count — `@built`
- space is owned by Music Mouse and never bleeds to the pattern editor — `@built`
- Gravity Play rate is stated in pattern rows — `@built`
- Gravity Play moves the position; the Treatment plays it — `@built`
- Changing a dropdown never retriggers Gravity Play — `@built`
- Gravity Play keeps one tempo whether or not Renoise is playing — `@built`
- Gravity Play owns the sounding position — `@built`
- Pressing a gravitation node performs the WHOLE gesture, not one note of it — `@runtime-verified`
- Cursor up / down shifts an octave through the current Treatment — `@built`
- A strum rake fits inside the beat that started it — `@runtime-verified`
- Strum can be chosen from either control that offers it — `@runtime-verified`
- Automatic Gravity Play is not disturbed by the manual one — `@runtime-verified`
- Leaving a Treatment stops the phrase it was driving — `@built`
- A tool reload cannot destroy the saved gravitation seeds — `@runtime-verified`
- No helper is called before it is declared — `@runtime-verified`
- The file still fits Lua's 200-locals-per-chunk ceiling — `@stock`
- Arpeggiate has Up / Down / Scatter / Strum — `@built`
- i / o / p punch saved favorite waveforms; å = current; shift-i round-robin — `@built`
- Tuning dropdown and < > transpose — `@built`
- Layout polish and width toggles — `@built`
- Pattern contour up to 64 steps with a length switch — `@built`
- Keyboard Map is clickable and MIDI-mappable — `@built`

**How it does it:** **Source files:** `PakettiMusicMouse.lua`, `.spine/localroom.lua`, `check.py`, `PakettiMusicMouse-LOCALS.md`

**Grade:** @built ×29 · @runtime-verified ×6 · @stock ×1


<a id="parameter-editor-mixer-and-config"></a>
## Parameter Editor exposes on the Mixer the parameter you're modifying

`features/parameter-editor-mixer-and-config.feature` · [session](parameter-editor-mixer-and-config.session.md)

**Behaviour (7 scenarios):**

- Dragging a parameter with "Expose on Mixer" on surfaces it in the mixer — `@built`
- Surface only the automated parameters of the selected track — `@built`
- Alternating column backgrounds for grid-style reading — `@built @untested`
- Mode OFF or no config behaves exactly like today (no-op) — `@built`
- User curates which parameters show, in what order, under what names
- Reset to Plugin Default restores the baseline
- Edit a Live sample in Renoise and save it back so Live reloads it

**How it does it:** **Source files:** `PakettiCanvasExperiments.lua`, `Research/parameter-editor/feasibility.md`

**Grade:** @built ×4 · @untested ×1


<a id="pattern-editor-example"></a>
## Pattern Editor note manipulation

`features/pattern-editor-example.feature`

**What it does:** Context: Pattern Editor

**Behaviour (2 scenarios):**

- Replicate the current row down the pattern
- Toggle the Pattern Matrix


<a id="pattern-song-jumps"></a>
## Pattern and song row jumps

`features/pattern-song-jumps.feature` · [session](pattern-song-jumps.session.md)

**What it does:** As a Renoise user, I want bounded jump commands with a fast way back, So that navigation is reversible while composing.

**Behaviour (4 scenarios):**

- Reverse the last explicit pattern row jump — `@shipped @code-verified @runtime-untested`
- Reverse the last explicit song row jump — `@shipped @code-verified @runtime-untested`
- Jump to pattern fractions from Pattern Editor and Global contexts — `@shipped @code-verified @runtime-untested`
- Existing fixed row jumps remain available — `@stock`

**How it does it:** **Key procs:** `PakettiJumpRows`, `PakettiJumpRowsInSong`, `PakettiJumpBackByLastPatternJump`, `PakettiJumpBackByLastSongJump`, `PakettiJumpToPatternFraction`, `PakettiJumpToPreviousPosition` · **Source files:** `PakettiRequests.lua`, `PakettiPatternEditor.lua`

**Grade:** @code-verified ×3 · @runtime-untested ×3 · @shipped ×3 · @stock ×1


<a id="pattern-transform-shortcuts"></a>
## Pattern transform shortcuts

`features/pattern-transform-shortcuts.feature` · [session](pattern-transform-shortcuts.session.md)

**What it does:** As a Paketti user, I want small Pattern Editor transforms exposed consistently, So that interpolation, timing expansion, and note transpose operations can be performed from menus, shortcuts, or MIDI without opening a custom workflow.

**Behaviour (3 scenarios):**

- Exponential interpolation is visible from the Pattern Editor menu — `@shipped @code-verified @runtime-untested`
- Expand the current pattern from LPB1-style spacing to LPB4-style spacing — `@shipped @code-verified @runtime-untested`
- Transpose selected notes or the current row from shortcuts and MIDI — `@shipped @code-verified @runtime-untested`

**How it does it:** **Key procs:** `interpolate_current_subcolumn_exponential`, `PakettiExpandPatternLPB1ToLPB4`, `PakettiTransposeNotesInSelectionOrRow` · **Source files:** `PakettiRequests.lua`, `PakettiMenuConfig.lua`, `PakettiPatternEditor.lua`, `PakettiMidi.lua`

**Grade:** @code-verified ×3 · @runtime-untested ×3 · @shipped ×3


<a id="quick-edit-navigation"></a>
## Quick edit navigation commands

`features/quick-edit-navigation.feature` · [session](quick-edit-navigation.session.md)

**What it does:** As a Paketti user, I want repeated shortcuts to move editing state without modal setup, So that common tracker edits are fast and reversible enough to test live.

**Behaviour (4 scenarios):**

- Repeat Select Chunk to advance inside that chunk — `@shipped @code-verified @runtime-untested`
- Increment delay values from MIDI without overwriting them — `@shipped @code-verified @runtime-untested`
- Quantize selected notes onto triplet timing — `@shipped @code-verified @runtime-untested`
- Existing direct chunk and delay controls remain available — `@stock`

**How it does it:** **Key procs:** `select_chunk`, `PakettiDelayColumnModifier`, `PakettiQuantizeSelectionToTriplets` · **Source files:** `PakettiInstrumentBox.lua`, `PakettiPatternEditor.lua`

**Grade:** @code-verified ×3 · @runtime-untested ×3 · @shipped ×3 · @stock ×1


<a id="repeater-control"></a>
## Repeater control from keys and MIDI

`features/repeater-control.feature` · [session](repeater-control.session.md)

**What it does:** As a live performer, I want Repeater controls available from keybindings and MIDI, So that repeat effects can be punched in without opening the device chain.

**Behaviour (5 scenarios):**

- Selected-track Repeater actions can enable, bypass, toggle, set mode, step divisor, and toggle sync mode — `@shipped @code-verified @runtime-untested`
- Master-track Repeater actions target the master track instead of the selected track — `@shipped @code-verified @runtime-untested`
- Per-division MIDI buttons stamp or hold Repeater presets — `@shipped @code-verified @runtime-untested`
- Free Divisor MIDI knob switches Repeater to Free mode before changing divisor — `@shipped @code-verified @runtime-untested`
- Existing Set Repeater Value knob mappings keep their selected-track behavior — `@stock`

**How it does it:** **Key procs:** `PakettiFindOrInsertRepeater`, `PakettiRepeaterSetActive`, `PakettiRepeaterToggleActive`, `PakettiRepeaterSetMode`, `PakettiRepeaterSetDivision`, `PakettiRepeaterAddActionKeybindings`, `PakettiRepeaterAddActionMidiMappings`, `PakettiRepeaterAddPresetMidiMappings` · **Source files:** `PakettiMidi.lua`

**Grade:** @code-verified ×4 · @runtime-untested ×4 · @shipped ×4 · @stock ×1


<a id="sample-slice-selection"></a>
## Sample slice selection range

`features/sample-slice-selection.feature` · [session](sample-slice-selection.session.md)

**What it does:** As a Sample Editor user, I want one command that selects the current slice boundaries, So that loop and beat-sync work can start from the exact slice range.

**Behaviour (3 scenarios):**

- Select the current slice range — `@shipped @code-verified @runtime-untested`
- Expose the slice range command — `@shipped @code-verified @runtime-untested`
- Existing slice marker deletion remains separate — `@stock`

**How it does it:** **Key procs:** `PakettiSelectCurrentSliceRange` · **Source files:** `PakettiSlice.lua`, `PakettiMenuConfig.lua`

**Grade:** @code-verified ×2 · @runtime-untested ×2 · @shipped ×2 · @stock ×1


<a id="section-loop-immediate-switch"></a>
## Section loop switches trigger immediately

`features/section-loop-immediate-switch.feature` · [session](section-loop-immediate-switch.session.md)

**What it does:** As a Paketti live performer, I want next/previous section loop commands that switch immediately, So that a footswitch can move a song between section loops without waiting for scheduled playback.

**Behaviour (5 scenarios):**

- Next command starts the current section when it is not already looped — `@shipped @built @code-verified @runtime-untested`
- Next command advances when the current section is already looped — `@shipped @built @code-verified @runtime-untested`
- Previous command retreats when the current section is already looped — `@shipped @built @code-verified @runtime-untested`
- Commands are available from shortcuts, MIDI, and Pattern Sequencer menus — `@shipped @built @code-verified @runtime-untested`
- Scheduled section command remains separate — `@stock`

**How it does it:** **Key procs:** `tknaSetSectionLoopAndSwitchImmediately`, `tknaSetSectionLoopAndSwitchImmediatelyNext`, `tknaSetSectionLoopAndSwitchImmediatelyPrevious` · **Source files:** `PakettiTkna.lua`, `PakettiMenuConfig.lua`

**Grade:** @built ×4 · @code-verified ×4 · @runtime-untested ×4 · @shipped ×4 · @stock ×1


<a id="section-loop-midi-capture"></a>
## Section loop and MIDI capture

`features/section-loop-midi-capture.feature` · [session](section-loop-midi-capture.session.md)

**What it does:** As a live Paketti user, I want section loop actions to advance predictably and static MIDI values to be recordable, So that footswitches and controllers work without manual corrective steps.

**Behaviour (3 scenarios):**

- Schedule the current section and advance on repeated triggers — `@shipped @code-verified @runtime-untested`
- Switch immediately between sections — `@shipped @code-verified @runtime-untested`
- Capture a static selected-device parameter value — `@shipped @code-verified @runtime-untested`

**How it does it:** **Key procs:** `tknaAddLoopAndScheduleSection`, `tknaSetSectionLoopAndSwitchImmediately`, `MidiSelectedAutomationParameter`, `PakettiCaptureSelectedDeviceAutomationParameter` · **Source files:** `PakettiTkna.lua`, `PakettiMidi.lua`

**Grade:** @code-verified ×3 · @runtime-untested ×3 · @shipped ×3


<a id="selection-reversed-instrument"></a>
## Reverse-duplicate instrument for pattern selections

`features/selection-reversed-instrument.feature` · [session](selection-reversed-instrument.session.md)

**What it does:** As a Paketti user, I want one Pattern Editor action that makes a reversed copy of the current instrument and points my selected notes at it, So that I can turn a selected phrase into a reversed-instrument variation without manual instrument reassignment.

**Behaviour (4 scenarios):**

- Active pattern selection is retargeted to the reversed duplicate — `@shipped @built @code-verified @runtime-untested`
- Missing pattern selection is rejected before duplication — `@shipped @built @code-verified @runtime-untested`
- Command is discoverable from Pattern Editor — `@shipped @built @code-verified @runtime-untested`
- Existing global duplicate-and-reverse command stays available — `@stock`

**How it does it:** **Key procs:** `PakettiDuplicateReverseInstrumentForSelection` · **Source files:** `PakettiSamples.lua`, `PakettiMenuConfig.lua`

**Grade:** @built ×3 · @code-verified ×3 · @runtime-untested ×3 · @shipped ×3 · @stock ×1


<a id="song-lifecycle-safety"></a>
## Song-lifecycle safety for canvas dialogs and song observers

`features/song-lifecycle-safety.feature`

**What it does:** Context: Global

**Behaviour (3 scenarios):**

- 8120 survives New Song with its canvas open — `@hw-verified`
- HyperEdit must survive New Song / Load Song with its canvas open — `@built`
- ParameterEditor must survive New Song / Load Song with its canvas open — `@built`

**Grade:** @built ×2 · @hw-verified ×1


<a id="subcolumn-only-invert"></a>
## Subcolumn-only pattern inversion

`features/subcolumn-only-invert.feature` · [session](subcolumn-only-invert.session.md)

**What it does:** As a Pattern Editor user, I want to invert one note subcolumn at a time, So that volume, pan, delay, or sample-FX edits do not disturb the others.

**Behaviour (3 scenarios):**

- Invert only the requested note subcolumn — `@shipped @code-verified @runtime-untested`
- Reach the specific invert commands from the Pattern Editor menu — `@shipped @code-verified @runtime-untested`
- Existing broad inversion commands remain available — `@stock`

**How it does it:** **Key procs:** `invert_content_subcolumn` · **Source files:** `PakettiRequests.lua`, `PakettiMenuConfig.lua`

**Grade:** @code-verified ×2 · @runtime-untested ×2 · @shipped ×2 · @stock ×1


<a id="tx16w-cyclone-images"></a>
## TX16W IMG exports use Cyclone-compatible item identity

`features/tx16w-cyclone-images.feature` · [session](tx16w-cyclone-images.session.md)

**What it does:** As a Paketti user, I want exported Yamaha TX16W IMG disks to present the same disk and item identity as known-good Cyclone images, So that Typhoon/Cyclone sees the disk contents as loadable Typhoon items.

**Behaviour (9 scenarios):**

- Exported IMG uses the Typhoon/Cyclone short BPB identity — `@shipped @built @code-verified @runtime-verified`
- Exported Typhoon items use the observed creator signature — `@shipped @built @code-verified @runtime-verified`
- Exported Typhoon item ids avoid arbitrary hash values — `@shipped @built @code-verified @runtime-verified`
- Exported IMG keeps the known-good 720K floppy geometry — `@shipped @built @code-verified @runtime-verified`
- File placement and root-directory labels still use the existing FAT writer — `@stock`
- Cyclone loads a VInf-fixed Paketti-exported disk through Typhoon Load* — `@shipped @runtime-verified`
- RX2 break slices export as an audible Cyclone proof image — `@shipped @built @runtime-verified`
- Drum-pad exports preserve each slice's chromatic root — `@shipped @built @code-verified @runtime-verified`
- Drumkit exports include a loadable performance — `@shipped @built @code-verified @runtime-verified`

**How it does it:** **Key procs:** `PakettiTyphoonBuildDiskImage`, `PakettiTyphoonNewStamp`, `PakettiTyphoonNewWaveId`, `typhoon_export_wave_notes` · **Source files:** `PakettiTyphoon.lua`, `PakettiRX2Decode.lua`

**Grade:** @built ×7 · @code-verified ×6 · @runtime-verified ×8 · @shipped ×8 · @stock ×1


---

## Meta / session cards

These document the report-card *process* itself, not a product behaviour.

- **AKAI controller debug/demo entries moved out of the Groovebox menu** — `features/2026-06-11-groovebox-controller-follow-and-menu.feature` · [session](2026-06-11-groovebox-controller-follow-and-menu.session.md)
- **Groovebox 8120 Kit loader status column alignment** — `features/2026-06-11-ui-fixes-and-menu-config.feature` · [session](2026-06-11-ui-fixes-and-menu-config.session.md)

