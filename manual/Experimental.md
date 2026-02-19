**[Support on Patreon](http://patreon.com/esaruoho)** | [GitHub](https://github.com/esaruoho/paketti) | [Discord](https://discord.gg/xNT6eH7W) | [README](index.html) | [Changeslog](CHANGESLOG.html) 

📖 **Navigation:** [Paketti README](index.html) | [Changeslog](CHANGESLOG.html) | Experimental (You are here)

# Paketti Experimental Documentation

**The comprehensive, all-in-one documentation for Paketti - Renoise Enhancement Suite**

**Last Updated:** 2026-01-09

> *Thousands of shortcuts. Hundreds of dialogs. Daily updates. All free.*
> **[Support the development on Patreon →](http://patreon.com/esaruoho)**

---

## 📚 Complete Table of Contents

### Core Features
1. [Phrase Selection Features](#phrase-selection-features-new)
2. [BPM Features](#bpm-features)
3. [Recording Features](#recording-features)
4. [MIDI Control](#midi-control)
5. [Routing Features](#routing-features)
6. [Chords & Harmony](#chords--harmony)
7. [Workflow Controls](#workflow-controls)
8. [Tracker Emulation](#tracker-emulation) *(Impulse Tracker, PlayerPro, OctaMED, OpenMPT)*
9. [Instrument Management](#instrument-management)
10. [Rendering Features](#rendering-features)
11. [Column Visibility](#column-visibility)
12. [Pattern Matrix](#pattern-matrix)
13. [Device & Plugin Loaders](#device--plugin-loaders)
14. [Phrase Editor](#phrase-editor)
15. [Automation Features](#automation-features)
16. [Pattern Editor Advanced](#pattern-editor-advanced)

### Sample Management
17. [Sample Loading & Management](#sample-loading--management)
18. [Sample Normalization & Channel/Bit Depth Conversion](#sample-normalization--channelbit-depth-conversion)
19. [Sample Processing & Manipulation](#sample-processing--manipulation)
20. [Sample Processing Suite](#sample-processing-suite)
21. [Sample Processing Tools](#sample-processing-tools)
22. [Sample Cycle Tuning (RePitch)](#sample-cycle-tuning-repitch)
23. [Sample Effect Generator](#sample-effect-generator)
24. [Sample Loop MIDI Control](#sample-loop-midi-control)
25. [Sample Range Device Loader](#sample-range-device-loader)

### Audio & Effects
26. [Audio Processing & Effects](#audio-processing--effects)
27. [Audio Processing Tools](#audio-processing-tools)
28. [Chebyshev Polynomial Waveshaper](#chebyshev-polynomial-waveshaper)
29. [Custom LFO Presets & Device XML Control](#custom-lfo-presets--device-xml-control)

### Slicing & Samples
30. [Slicing Features](#slicing-features)
31. [Slicing Tools](#slicing-tools)
32. [Stem Loader](#stem-loader) *(NEW - Dec 2025)*
33. [Manual Slicer (Power of 2 Padding)](#manual-slicer-power-of-2-padding)
34. [Zero Crossings System](#zero-crossings-system)
35. [Oldschool Slice Pitch Workflow](#oldschool-slice-pitch-workflow)
36. [Samples and Instruments](#samples-and-instruments)

### Pattern Editor
36. [Pattern Editor Features](#pattern-editor-features)
37. [Effect Command CheatSheet](#effect-command-cheatsheet)
38. [Pattern Delay Viewer](#pattern-delay-viewer)
39. [Sub-Column Modifier](#sub-column-modifier)
40. [HyperEdit (8-Row Step Sequencer)](#hyperedit-8-row-step-sequencer)

### Pattern Sequencer
41. [Pattern Sequencer & Section Management](#pattern-sequencer--section-management)
42. [Pattern Name Loop](#pattern-name-loop-new---dec-2025) *(NEW - Dec 2025)*
43. [Pattern Sequencer](#pattern-sequencer)
44. [Slab'o'Patterns (Time Signature Generator)](#slabopatterns-time-signature-generator)
45. [Pattern Sequencer Utilities](#pattern-sequencer-utilities)
46. [Pattern/Phrase Length Control](#patternphrase-length-control)

### Generative & Creative Tools
46. [Generative Tools](#generative-tools)
47. [Paketti Clipboard](#paketti-clipboard) *(NEW - Jan 2026)*
48. [Paketti Wonkify](#paketti-wonkify)
49. [Tuplet Generator](#tuplet-generator)
50. [Unison Generator](#unison-generator)
51. [Paketti Gater](#paketti-gater)
52. [Hotelsinus Step Sequencer](#hotelsinus-step-sequencer)
53. [Paketti 8120 Groovebox](#paketti-8120-groovebox)
53. [Global Groove to Delay](#global-groove-to-delay)
54. [Metric Modulation](#metric-modulation)

### Chord & Harmony
55. [Chord Progression Player](#chord-progression-player)
56. [Switcharoo (Chord Reharmonization)](#switcharoo-chord-reharmonization)

### Import/Export
57. [Import/Export Suite](#importexport-suite)
58. [FastTracker II XI Export](#fasttracker-ii-xi-export)
59. [ProTracker MOD Sample Import](#protracker-mod-sample-import)
60. [WAV CUE Marker Import/Export](#wav-cue-marker-importexport)
61. [Drag & Drop Import Hooks](#drag--drop-import-hooks-comprehensive-list)

### Elektron Integration
62. [Elektron Octatrack Export Suite](#elektron-octatrack-export-suite)
63. [Elektron Digitakt Export Suite](#elektron-digitakt-export-suite)
64. [Octatrack OctaCycle Generator](#octatrack-octacycle-generator)

### Polyend Integration
65. [Polyend Pattern Data Suite](#polyend-pattern-data-suite)
66. [Polyend Buddy (PTI File Browser)](#polyend-buddy-pti-file-browser)
67. [Melodic Slice Switching (Polyend)](#melodic-slice-switching-polyend)
68. [Melodic Slice Export (Polyend)](#melodic-slice-export-polyend)

### Device & Plugin Management
69. [Plugin Loader](#plugin-loader)
70. [Device Chain Presets](#device-chain-presets)
71. [Quick Load Device Dialog](#quick-load-device-dialog)
72. [Device Parameter Control (Parama Param)](#device-parameter-control-parama-param)
73. [Canvas Parameter Editor](#canvas-parameter-editor) *(NEW - Jan 2026)*
74. [Mixer Parameter Exposer](#mixer-parameter-exposer) *(NEW - Jan 2026)*
75. [Favorited Plugin Instruments](#favorited-plugin-instruments-new---dec-2025) *(NEW - Dec 2025)*
76. [Preset++ (Advanced Device Presets)](#preset-advanced-device-presets)
77. [CCizer Loader](#ccizer-loader)

### Instruments & Keyzones
75. [Keyzone Distributor](#keyzone-distributor)
76. [Merge Instruments](#merge-instruments)
77. [Instrument Transpose System](#instrument-transpose-system)
78. [XRNIT (Track/Instrument Preset Loader)](#xrnit-trackinstrument-preset-loader)

### Tuning & Pitch
79. [Tuning Display & Microtonal Control](#tuning-display--microtonal-control)
80. [Pitch & BPM Control Suite](#pitch--bpm-control-suite)
81. [Transpose Blocks](#transpose-blocks)

### Automation
82. [Automation Stack](#automation-stack)

### Views & Navigation
83. [Dynamic View Cycling](#dynamic-view-cycling)
84. [Theme Selector](#theme-selector)
85. [PlayerPro Waveform Viewer](#playerpro-waveform-viewer)

### Utilities
86. [Utility Features](#utility-features)
87. [Utility Tools](#utility-tools)
88. [Paketti Utilities](#paketti-utilities)
89. [Clearance (Cleanup Utilities)](#clearance-cleanup-utilities)
90. [Volume Delay Pan Equation Calculator](#volume-delay-pan-equation-calculator)
91. [Frame Calculator](#frame-calculator)
92. [Multi-File Raw Loader](#multi-file-raw-loader)

### Search & Tools
93. [Paketti Function Search (Autocomplete)](#paketti-function-search-autocomplete)
94. [Action Selector](#action-selector)
95. [XRNS Probe (Song File Inspector)](#xrns-probe-song-file-inspector)
96. [Notepad Device Code Runner](#notepad-device-code-runner)

### Recording & Capture
97. [Capture Last Take & EditStep MIDI Gate](#capture-last-take--editstep-midi-gate)
98. [OctaMED Hold-to-Fill Mode](#octamed-hold-to-fill-mode)
99. [New Sample Auto-Settings](#new-sample-auto-settings)

### MIDI & Keybindings
100. [MIDI Mapping Utilities](#midi-mapping-utilities)
101. [Control Mixer Shown Parameters](#control-mixer-shown-parameters-new---dec-2025) *(NEW - Dec 2025)*
102. [KeyBindings Management](#keybindings-management)

### External Integration
102. [Sononymph Integration](#sononymph-integration)
103. [YT-DLP Downloader](#yt-dlp-downloader)
104. [Execute Applications](#execute-applications)
105. [Launch App & Smart Folders](#launch-app--smart-folders)

### Advanced & Experimental
106. [Advanced Features](#advanced-features)
107. [Renoise 3.5+ Features (API 6.2+)](#renoise-35-features-api-62)
108. [Experimental & Verify Features](#experimental--verify-features)
109. [Sandbox (Experimental Features)](#sandbox-experimental-features)

### System & Preferences
110. [Paketti Preferences System](#paketti-preferences-system)

### Documentation & Support
111. [The Paketti Story](#the-paketti-story)
112. [Support](#support)

---

# Phrase Selection Features (NEW)

**Source File:** `PakettiPhraseEditor.lua`

Comprehensive phrase navigation and selection features with both standard and phrase-editor-focused variants.

## Features Added

### 1. Direct Phrase Selection (01-16)
Select specific phrases by number with validation, automatically switches to phrase editor view (optional), protection against non-existent phrases, shows phrase name in status message.

**Keybindings:**
- `Global:Paketti:Select Phrase 01` through `Select Phrase 16` ⌨️
- `Global:Paketti:Select Phrase 01 (Phrase Editor)` through `Select Phrase 16 (Phrase Editor)` ⌨️

**Menu Entries:**
- `Main Menu:Tools:Paketti..:Phrases:Select Phrase:Select Phrase 01-16` 📋
- `Main Menu:Tools:Paketti..:Phrases:Select Phrase (Phrase Editor):Select Phrase 01-16 (Phrase Editor)` 📋

### 2. Next/Previous Phrase Navigation
Navigate through phrases with wrapping (last→first, first→last), works from any view, optional automatic phrase editor switching.

**Keybindings:**
- `Global:Paketti:Select Next Phrase` ⌨️
- `Global:Paketti:Select Previous Phrase` ⌨️
- `Global:Paketti:Select Next Phrase (Phrase Editor)` ⌨️
- `Global:Paketti:Select Previous Phrase (Phrase Editor)` ⌨️

**Menu Entries:**
- `Main Menu:Tools:Paketti..:Phrases:Select Next Phrase` 📋
- `Main Menu:Tools:Paketti..:Phrases:Select Previous Phrase` 📋
- `Main Menu:Tools:Paketti..:Phrases:Select Next Phrase (Phrase Editor)` 📋
- `Main Menu:Tools:Paketti..:Phrases:Select Previous Phrase (Phrase Editor)` 📋

**MIDI Mappings (NEW - Jan 2026):**
- `Paketti:Next Phrase` 🎹 - Navigate to next phrase with wrap-around
- `Paketti:Previous Phrase` 🎹 - Navigate to previous phrase with wrap-around

## Design
- **Standard versions** - Select phrase without view switching (workflow continuity)
- **(Phrase Editor) versions** - Select phrase AND switch to phrase editor (focused editing)
- **Protection & Validation** - Validates song, instrument, phrases exist; shows helpful errors
- **DRY Principles** - Core internal functions handle all logic with clean wrapper API

---

# BPM Features

Guide to Paketti's BPM analysis, calculation, and manipulation features for tempo-based workflows.

**Source:** `PakettiBPM.lua` | **Keybindings:** 14

## BPM to MS Delay Calculator

### Paketti BPM to MS Delay Calculator Dialog
**Shortcut:** `Global:Paketti:Paketti BPM to MS Delay Calculator Dialog...` ⌨️

Comprehensive delay calculator showing millisecond delay times for musical note values at current BPM.

**Displays delays for:** Whole notes, half notes, quarter notes, eighth notes, sixteenth notes, thirty-second notes, sixty-fourth notes, 128th notes (all with Even, Dotted, Triplet variants), plus special 3/16-note delays.

**Use cases:** Setting delay effect times, calculating echo/reverb pre-delays, syncing external hardware, creating rhythmic delay patterns, dub production, synth modulation timing.

## Sample BPM Analysis

### Analyze Sample BPM (Multiple Variants)
- `Analyze Sample BPM (4 beats)` ⌨️ - Default loop analysis
- `Analyze Sample BPM (1 beat)` ⌨️ - Single kick, snare analysis
- `Analyze Sample BPM (2 beats)` ⌨️ - Half-bar loop
- `Analyze Sample BPM (8 beats)` ⌨️ - 2-bar loop
- `Analyze Sample BPM (16 beats)` ⌨️ - 4-bar loop
- `Intelligent BPM Detection` ⌨️ - Advanced analysis with peak detection

## BPM Manipulation

- **Halve BPM** - Divides current BPM by 2
- **Double BPM** - Multiplies current BPM by 2
- **Halve Halve BPM** - Divides BPM by 4
- **Double Double BPM** - Multiplies BPM by 4
- **Multiply BPM & Halve LPB** - Double BPM, halve LPB (same speed, double resolution)
- **Halve BPM & Multiply LPB** - Half BPM, double LPB (same speed, half resolution)

---

# Recording Features

Guide to Paketti's recording, sampling, and overdub features for audio capture workflows.

**Source:** `PakettiRecorder.lua` | **Keybindings:** 19

## Sample Recording

### Contour Shuttle Record On/Off
Hardware controller support for Contour Design ShuttlePRO. First press opens Sample Recorder + starts recording, second press stops, auto-processing sets autoseek=true and autofade=true.

### Start Sampling and Sample Editor (Record)
Comprehensive recording workflow: Creates new instrument, opens Sample Recorder, starts recording, on stop automatically switches to Sample Editor, sets autoseek/autofade, locks keyboard focus.

## Paketti Overdub

**Smart Multi-Take Recording System** - Records audio into note columns on row 1 of the current pattern, automatically creating new tracks when needed.

### How It Works
1. First recording → Places note in column 1
2. Second recording → Places note in column 2
3. Continues filling columns on row 1...
4. When row 1 reaches max columns → Creates NEW TRACK after current one
5. Each recording creates new instrument (if current isn't empty)
6. Each recording trims tail frames, sets autofade/autoseek
7. Tracks named "OverdubXX", instruments named with PTN:length BPM:xxx LPB:xx

### Overdub 12 (4 Variants)
**Maximum 12 note columns** - Records up to 12 samples in 12 columns before creating new track.

**Keybindings:**
- `Global:Paketti:Paketti Overdub 12 (No Metronome/No Line Input)` ⌨️
- `Global:Paketti:Paketti Overdub 12 (Metronome/No Line Input)` ⌨️
- `Global:Paketti:Paketti Overdub 12 (No Metronome/Line Input)` ⌨️
- `Global:Paketti:Paketti Overdub 12 (Metronome/Line Input)` ⌨️

**MIDI Mappings:**
- `Paketti:Paketti Overdub 12 (No Metronome/No Line Input)` 🎹
- `Paketti:Paketti Overdub 12 (Metronome/No Line Input)` 🎹
- `Paketti:Paketti Overdub 12 (No Metronome/Line Input)` 🎹
- `Paketti:Paketti Overdub 12 (Metronome/Line Input)` 🎹

**Menu:**
- `Instrument Box:Paketti:Record:Paketti Overdub 12 (...)` 📋 (all 4 variants)
- `Mixer:Paketti:Record:Paketti Overdub 12 (...)` 📋 (all 4 variants)
- `Pattern Editor:Paketti:Record:Paketti Overdub 12 (...)` 📋 (all 4 variants)
- `Pattern Matrix:Paketti:Record:Paketti Overdub 12 (...)` 📋 (all 4 variants)

### Overdub 01 (4 Variants)
**Maximum 1 note column** - Each recording creates new track immediately (perfect for vocal/guitar takes).

**Keybindings:**
- `Global:Paketti:Paketti Overdub 01 (No Metronome/No Line Input)` ⌨️
- `Global:Paketti:Paketti Overdub 01 (Metronome/No Line Input)` ⌨️
- `Global:Paketti:Paketti Overdub 01 (No Metronome/Line Input)` ⌨️
- `Global:Paketti:Paketti Overdub 01 (Metronome/Line Input)` ⌨️

**MIDI Mappings:**
- `Paketti:Paketti Overdub 01 (No Metronome/No Line Input)` 🎹
- `Paketti:Paketti Overdub 01 (Metronome/No Line Input)` 🎹
- `Paketti:Paketti Overdub 01 (No Metronome/Line Input)` 🎹
- `Paketti:Paketti Overdub 01 (Metronome/Line Input)` 🎹

**Menu:**
- `Instrument Box:Paketti:Record:Paketti Overdub 01 (...)` 📋 (all 4 variants)
- `Mixer:Paketti:Record:Paketti Overdub 01 (...)` 📋 (all 4 variants)
- `Pattern Editor:Paketti:Record:Paketti Overdub 01 (...)` 📋 (all 4 variants)
- `Pattern Matrix:Paketti:Record:Paketti Overdub 01 (...)` 📋 (all 4 variants)

**Options:**
- **Metronome** - Enables/disables metronome during recording
- **Line Input** - Automatically adds/removes #Line Input device to track

## Record Follow Controls

### Record Follow
**Shortcut:** `Global:Paketti:Record Follow` ⌨️

Intelligent edit mode + follow player toggle with 3 states:
- **State 1:** Not editing but following → Enables edit mode, disables follow
- **State 2:** Editing and following → Disables follow only
- **State 3:** All other cases → Enables both edit mode and follow player

### Simple Play Record Follow
**Shortcuts:**
- `Global:Paketti:Simple Play Record Follow` ⌨️
- `Global:Paketti:Simple Play Record Follow (2nd)` ⌨️

All-in-one recording workflow:
- Starts playback if stopped
- Enables follow player
- Enables edit mode
- Switches to Pattern Editor
- **Toggle:** If already in this state, disables follow + edit mode

## Sample Recorder Utilities

### Start/Stop Sample Recording and Pakettify
**Shortcut:** `Global:Paketti:Start/Stop Sample Recording and Pakettify` ⌨️

Smart sample recorder with auto-Pakettify:
1. Opens Sample Recorder dialog
2. Creates new instrument
3. Applies Paketti default template
4. Starts recording
5. On stop: Applies preferences (interpolation, filter, modulation, oversample, autofade, autoseek, oneshot, loop mode, NNA)
6. Sets loop mode to Forward

### Display Sample Recorder with #Line Input
**Shortcut:** `Global:Paketti:Display Sample Recorder with #Line Input` ⌨️

Toggle Sample Recorder + automatically manage #Line Input device:
- **First press:** Opens recorder + adds #Line Input (if not present)
- **Second press:** Closes recorder + removes #Line Input
- **Smart detection:** Only removes #Line Input if it's in device slot 2

### Recordammajic9000
**Shortcut:** `Global:Paketti:Recordammajic9000` ⌨️

Automated recording workflow:
1. Checks for #Line Input (adds if missing)
2. Calls recordtocurrenttrack()
3. Automatically adds 0G01 effect command

## TouchOSC Integration

Mobile control optimized for TouchOSC tablet/phone controllers:

**Shortcuts:**
- `Global:Paketti:TouchOSC Sample Recorder and Record` ⌨️ - Toggle recorder
- `Global:Paketti:TouchOSC Pattern Editor` ⌨️ - Switch to Pattern Editor
- `Global:Paketti:TouchOSC Sample Editor` ⌨️ - Switch to Sample Editor

---

# MIDI Control

Guide to Paketti's MIDI mappings for hardware controller integration.

**Source:** `PakettiMidi.lua` | **MIDI Mappings:** 14

## Groove Control
- Groove Settings Groove #2&4 🎹
- Individual Groove Controls #1-4 🎹

## Computer Keyboard Velocity
- Computer Keyboard Velocity Slider 🎹 - Adjusts QWERTY keyboard note entry velocity

## Sample Parameters
- Change Selected Sample Volume 🎹

## Pattern Editor Controls
- Delay Column (DEPRECATED) 🎹

## Transport & View Control
- Metronome On/Off 🎹
- Uncollapser / Collapser 🎹
- Show/Hide Pattern Matrix 🎹

## Recording Controls
- Record and Follow 🎹 (Toggle + Knob variants)

---

# Routing Features

Guide to Paketti's output routing manipulation for creative track routing and mixing workflows.

**Source:** `PakettiRoutings.lua` | **Keybindings:** 9

## Serial Output Routing

**What is it?** Serial routing chains tracks sequentially: Track 1 → Track 2 → Track 3 → Master, instead of all tracks going directly to Master.

## Routing Modes (8 Configurations)

**Mode Options:**
1. **Continual vs. Non-Continual** - Cycles continuously or routes once
2. **Skip Master vs. Include Master** - Master track routing inclusion
3. **Exclude Master vs. Include Master in Cycle** - Master in routing cycle

### Available Shortcuts
- Output Routing (Non-Continual, Skip Master, Exclude Master)
- Output Routing (Continual, Skip Master, Exclude Master)
- Output Routing (Non-Continual, Include Master, Exclude Master)
- Output Routing (Continual, Include Master, Exclude Master)
- Output Routing (Non-Continual, Skip Master, Include Master in Cycle)
- Output Routing (Continual, Skip Master, Include Master in Cycle)
- Output Routing (Non-Continual, Include Master, Include Master in Cycle)
- Output Routing (Continual, Include Master, Include Master in Cycle)
- **Reset Output Routings to Master** - Restore default routing

## Creative Uses
- Serial Effects Chain
- Feedback Loop Creation
- Parallel Processing with Serial Return
- Experimental Routing

---

# Chords & Harmony

Comprehensive guide to Paketti's chord generation, manipulation, and harmony tools - **72 features** for composers!

**Source:** `PakettiChordsPlus.lua` | **Keybindings:** 72

## ChordsPlus Add/Sub

### Add Intervals (1-12 semitones)
`ChordsPlus (Add 01)` through `(Add 12)` ⌨️

Instant harmony adding note X semitones above current note in next column, chooses the next column.

### Subtract Intervals (1-12 semitones)
`ChordsPlus (Sub 01)` through `(Sub 12)` ⌨️

Downward harmony adding note X semitones below current note.

## Chord Library
Built-in chord types including major/minor triads, dominant 7ths, major/minor 7ths, extended chords (9ths, 11ths, 13ths), suspended chords, diminished/augmented, jazz voicings.

- **Next Chord in List** - Cycle through chords

## Note Sorting & Organization
- Note Sorter (Ascending/Descending)
- Randomize Voicing
- Shift Notes (Left/Right)

## Chord Inversions
- Cycle Chord Inversion (Up/Down)
- Random Chord

## Note Extraction
- Extract Bassline to New Track
- Extract Highest Note to New Track
- Duplicate Highest Notes (3 modes: Duplicate Instrument, Selected Instrument, Original Instrument)
- Duplicate Lowest Notes (3 modes)

## Note Distribution
- Distribute (Even 2, Even 4, Uneven, Always Next Row)
- Distribute Across Selection (Even, Even 2, Even 4, Uneven)

## Vertical Spreading
Spread Notes Vertically (+1/+2/+3/+4 Rows)

## Arpeggio Patterns
16-Row and 8-Row arpeggios with patterns: Up, Down, Up-Down, Down-Up, Up-Up-Down, Random, Outside-In, Inside-Out.

---

# Workflow Controls

Collection of Paketti's workflow control shortcuts for editing, playback, navigation, and view management.

**Source:** `PakettiControls.lua` | **Keybindings:** 100

## Edit Mode & Recording
- Record+Follow Toggle (multiple bindings)
- Toggle EditMode (intelligent edit step)
- Record+Follow+Metronome Toggle
- Contour Shuttle Controls (hardware controller support)
- Record & Follow Flip
- Global Edit Mode Toggle

## Playback Controls
- Toggle Follow Pattern
- Simple Play
- Rewind Playback by 4 steps
- Toggle Metronome

## Transpose Operations
- Transpose Selection/Track (Octave Up/Down, +1/-1)
- Transpose Note Column (Octave Up/Down, +1/-1)
- ChordsPlus Transposer Row (+/-3, +/-4, +/-7, +/-11)
- Selection/Row variants for each interval

## Track & View Navigation
- Select Track (Next/Previous)
- Insert Track
- Pattern Editor <-> MIDI Editor Switcher
- Sample Editor Tab Switcher (Phrases, Keyzones)

## Octave Controls
- KeybOctave Up/Down

## Utility Functions
- Save Song
- Fullscreen
- Song Details (Filename, BPM, LPB)

---

# Tracker Emulation

Paketti emulates workflow features from classic trackers including Impulse Tracker (DOS), PlayerPro (Mac), OctaMED (Amiga), and OpenMPT (Windows). These provide familiar keyboard shortcuts, dialogs, and note entry systems for users coming from other tracker platforms.

## Impulse Tracker Suite

**Source:** `PakettiImpulseTracker.lua` | **Keybindings:** 200+ | **MIDI:** 30+ | **Menu:** 4

Comprehensive Impulse Tracker-style keyboard workflow - bringing the legendary DOS tracker interface to Renoise!

### What is Impulse Tracker Mode?

Impulse Tracker (IT) was a legendary DOS tracker created by Jeffrey Lim in the 1990s. Paketti recreates IT's iconic keyboard workflow in Renoise with extensive keyboard shortcuts, MIDI mappings, and workflow enhancements.

### F-Key Screen Switching

#### F2 - Pattern Editor
**Shortcuts:**
- `Global:Paketti:Impulse Tracker F2 Pattern Editor` ⌨️
- `Global:Paketti:Impulse Tracker F2 Pattern Editor ONLY` ⌨️
- `Global:Paketti:Impulse Tracker F2 Pattern Editor Mini` ⌨️
- `Mixer:Paketti:To Pattern Editor` ⌨️

**F2** - Toggles between Pattern Editor layouts
**F2 ONLY** - Forces Pattern Editor with lower/upper frames
**F2 Mini** - Pattern Editor only, no frames
**Mixer → F2** - Jump from Mixer to Pattern Editor

#### F3 - Sample Editor
**Shortcuts:**
- `Global:Paketti:Impulse Tracker F3 Sample Editor` ⌨️
- `Global:Paketti:Impulse Tracker F3 Sample Editor Only` ⌨️

Switches to Sample Editor with various frame configurations. Intelligent switching between Instrument tabs (MIDI/Plugin/Phrase → Sample Editor).

#### F4 - Instrument Editor
**Shortcut:** `Global:Paketti:Impulse Tracker F4 Instrument Editor` ⌨️

Cycles between MIDI Editor → Plugin Editor → Phrase Editor.

### F11 - Order List (Mixer)
**Shortcut:** `Global:Paketti:Impulse Tracker F11 Order List` ⌨️

Switches to Mixer, toggles Pattern Matrix and Automation frame. Double press cycles views.

#### F12 - Master
**Shortcut:** `Global:Paketti:Impulse Tracker F12 Master` ⌨️

Jumps to Master track, cycles between Track DSPs and Track Automation when pressed repeatedly.

### Playback Control

#### F5 - Start Playback (Song)
**Shortcuts:**
- `Global:Paketti:Impulse Tracker F5 Start Playback` ⌨️
- `Global:Paketti:Impulse Tracker F5 Start Playback (2nd)` ⌨️

Starts playback from sequence 1, line 1. Disables follow player, edit mode, metronome, loop block, and loop pattern. Includes 0.225s delay after panic for plugin stability.

#### F6 - Start Playback Pattern
**Shortcuts:**
- `Global:Paketti:Impulse Tracker F6 Start Playback Pattern` ⌨️
- `Global:Paketti:Impulse Tracker F6 Start Playback Pattern (2nd)` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker F6 Start Playback Pattern` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker F6 Start Playback Pattern (2nd)` ⌨️
- `Mixer:Paketti:Impulse Tracker F6 Start Playback Pattern` ⌨️
- `Mixer:Paketti:Impulse Tracker F6 Start Playback Pattern (2nd)` ⌨️

Loops current pattern - starts from current sequence index, line 1, enables loop pattern. Reduced 30ms delay (vs F5's 225ms).

#### F7 - Start Playback from Cursor Row
**Shortcuts:**
- `Global:Paketti:Impulse Tracker F7 Start Playback from Cursor Row` ⌨️
- `Global:Paketti:Impulse Tracker F7 Start Playback from Cursor Row (2nd)` ⌨️

Starts playback from cursor position OR from captured marker (if CTRL-F7 was used). Validates marker position, enables edit mode.

#### CTRL-F7 - Capture Marker Position
**Shortcut:** `Global:Paketti:Impulse Tracker Capture Marker Position (CTRL-F7)` ⌨️

**Menu:** `Main Menu:Tools:Paketti:Impulse Tracker:Toggle Marker Position (CTRL-F7)` 📋

**Toggle Marker:**
- **First press:** Captures current sequence + line as marker
- **Second press:** Disables marker
- **F7 behavior:** When marker exists, F7 plays from marker instead of cursor

Marker is saved in preferences and persists across sessions.

#### F8 - Stop Playback (Panic)
**Shortcuts:**
- `Global:Paketti:Impulse Tracker F8 Stop Playback (Panic)` ⌨️
- `Global:Paketti:Impulse Tracker F8 Stop Playback (Panic) (2nd)` ⌨️
- `Global:Paketti:Impulse Tracker F8 Stop/Start Playback (Panic)` ⌨️

**F8 Behavior (when playing):**
- Stops playback
- Disables follow player
- Calls panic
- Disables loop pattern/block
- Resets steppers

**F8 Behavior (when stopped):**
- **Line > 1:** Jump to line 1
- **Line = 1, Sequence > 1:** Jump to sequence 1
- **Already at 1,1:** Trigger panic

**F8 Stop/Start:** Toggles between stop and play from sequence 1.

### Start/Stop Playback Toggle
**Shortcuts:**
- `Global:Paketti:Start/Stop Playback (Continue)` ⌨️
- `Pattern Editor:Paketti:Start/Stop Playback (Continue)` ⌨️
- `Phrase Editor:Paketti:Start/Stop Playback (Continue)` ⌨️
- `Global:Paketti:Start/Stop Playback (First Row)` ⌨️
- `Pattern Editor:Paketti:Start/Stop Playback (First Row)` ⌨️
- `Phrase Editor:Paketti:Start/Stop Playback (First Row)` ⌨️

**Continue:** Toggles playback from current position
**First Row:** Toggles playback from pattern start

### Pattern Navigation

#### Next/Previous Pattern
**Shortcuts:**
- `Global:Paketti:Impulse Tracker Pattern (Next)` ⌨️
- `Global:Paketti:Impulse Tracker Pattern (Previous)` ⌨️
- `Global:Paketti:Impulse Tracker Pattern (Next) 2nd` ⌨️
- `Global:Paketti:Impulse Tracker Pattern (Previous) 2nd` ⌨️

Jumps to next/previous sequence. Enables follow player if disabled. When playing, triggers sequence change. Wraps at song boundaries.

### Selection Operations

#### ALT-D - Double Select
**Pattern Editor:**
- `Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select W/ Automation` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select Pattern` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select Column` ⌨️

**Phrase Editor:**
- `Phrase Editor:Paketti:Impulse Tracker ALT-D Double Select` ⌨️

**Global:**
- `Global:Paketti:Impulse Tracker ALT-D Double Select` ⌨️

**ALT-D behavior:**
1. **First press:** Selects LPB rows from cursor (e.g., 4 lines at LPB 4)
2. **Second press:** Doubles selection (4 → 8 lines)
3. **Third press:** Doubles again (8 → 16 lines)
4. Clamps to pattern length

**Double Select W/ Automation:** Also updates automation selection range
**Double Select Pattern:** Selects across all tracks
**Double Select Column:** Selects only current note/effect column

### ALT-F - Expand Selection
**Pattern Editor:**
- `Pattern Editor:Paketti:Impulse Tracker ALT-F Expand Selection` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-F Expand Selection Twice` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-F Expand Selection Replicate` ⌨️

**Phrase Editor:**
- `Phrase Editor:Paketti:Impulse Tracker ALT-F Expand Selection` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker ALT-F Expand Selection Twice` ⌨️

**MIDI:**
- `Paketti:Expand Selection Replicate [Trigger]` 🎹
- `Paketti:Expand Selection Replicate Tracks 1-8 [Trigger]` 🎹
- `Paketti:Expand Selection Replicate Track 1-8 [Trigger]` 🎹 (individual tracks)

**Expand:** Doubles pattern length, copies notes to new positions, clears intermediate lines
**Expand Twice:** Applies expand operation twice
**Expand Replicate:** Expands then flood-fills with selection

#### ALT-G - Shrink Selection
**Pattern Editor:**
- `Pattern Editor:Paketti:Impulse Tracker ALT-G Shrink Selection` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Twice` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Replicate` ⌨️

**Phrase Editor:**
- `Phrase Editor:Paketti:Impulse Tracker ALT-G Shrink Selection` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Twice` ⌨️

**MIDI:**
- `Paketti:Shrink Selection Replicate [Trigger]` 🎹
- `Paketti:Shrink Selection Replicate Tracks 1-8 [Trigger]` 🎹
- `Paketti:Shrink Selection Replicate Track 1-8 [Trigger]` 🎹 (individual tracks)

**Shrink:** Halves pattern length by removing every other line
**Shrink Twice:** Applies shrink operation twice
**Shrink Replicate:** Shrinks then flood-fills

#### ALT-S - Set Selection to Instrument
**Shortcut:** `Pattern Editor:Paketti:Impulse Tracker ALT-S Set Selection to Instrument` ⌨️

Changes all instrument numbers in selection to currently selected instrument. Only affects lines with notes.

#### ALT-L - Mark Track/Mark Pattern
**Shortcut:** `Pattern Editor:Selection:Impulse Tracker ALT-L Mark Track/Mark Pattern` ⌨️

**Smart Marking:**
1. **First press:** Selects entire track (line 1 to end)
2. **Second press:** Selects entire pattern (all tracks)
3. Also updates automation selection if automation frame visible

#### SHIFT-ALT-L - Mark Note Column/Mark Pattern
**Shortcut:** `Pattern Editor:Selection:Impulse Tracker SHIFT-ALT-L Mark Note Column/Mark Pattern` ⌨️

**For Phrase Editor:** `Phrase Editor:Paketti:Impulse Tracker ALT-L Mark Note Column/Mark Phrase` ⌨️

**Smart Column Marking:**
1. **First press:** Selects current note/effect column for entire pattern/phrase
2. **Second press:** Selects all columns

#### ALT-B - Modify Selection Start (Keep End)
**Shortcut:** `Pattern Editor:Selection:Impulse Tracker ALT-B Modify Selection Start (Keep End)` ⌨️

Extends selection from current END point to new cursor position. End stays fixed, start moves to cursor.

### ALT-U - Unmark Selection
**Shortcuts:**
- `Global:Paketti:Impulse Tracker ALT-U Unmark Selection` ⌨️
- `Global:Paketti:Impulse Tracker ALT-U Unmark Selection (2nd)` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-U Unmark Selection` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-U Unmark Selection (2nd)` ⌨️
- `Automation:Paketti:Impulse Tracker ALT-U Unmark Selection` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker ALT-U Unmark Selection` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker ALT-U Unmark Selection (2nd)` ⌨️

Clears pattern selection. Also clears automation envelope selection if automation frame is active.

#### ALT-Y - Swap Block
**Shortcut:** `Global:Paketti:Impulse Tracker ALT-Y Swap Block` ⌨️

Swaps selection with block at cursor position. Automatically adjusts column visibility on target track if needed.

### Selection Utilities

#### Select Current Row
**Shortcut:** `Pattern Editor:Paketti:Select Current Row` ⌨️

Selects current row across all visible note/effect columns in current track.

### Navigation

#### Home *2 Behaviour
**Shortcuts:**
- `Pattern Editor:Paketti:Impulse Tracker Home *2 behaviour` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Home *2 behaviour (2nd)` ⌨️
- `Mixer:Paketti:Impulse Tracker Home *2 behaviour` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker Home *2 behaviour` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker Home *2 behaviour (2nd)` ⌨️

**Smart Home Navigation:**
1. **First press:** Jump to line 1, current column
2. **Second press:** Jump to line 1, column 1
3. **Third press:** Jump to track 1, line 1, column 1

Works in both Pattern Editor and Phrase Editor.

#### End *2 Behaviour
**Shortcuts:**
- `Pattern Editor:Paketti:Impulse Tracker End *2 behaviour` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker End *2 behaviour (2nd)` ⌨️
- `Mixer:Paketti:Impulse Tracker End *2 behaviour` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker End *2 behaviour` ⌨️
- `Phrase Editor:Paketti:Impulse Tracker End *2 behaviour (2nd)` ⌨️

**Smart End Navigation:**
1. **First press:** Jump to last line, current column
2. **Second press:** Jump to last track

#### PageUp/PageDown Jump Lines
**Shortcuts:**
- `Global:Paketti:Impulse Tracker PageUp Jump Lines` ⌨️
- `Global:Paketti:Impulse Tracker PageDown Jump Lines` ⌨️

Jumps by (LPB × 2) lines. Disables follow player when jumping. Clamps to pattern boundaries.

### Track Navigation

#### ALT-Right/Left - Move Between Tracks
**Pattern Editor:**
- `Pattern Editor:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel (Wrap)` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel (Wrap)` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel` ⌨️

**Mixer:**
- `Mixer:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel (Wrap)` ⌨️
- `Mixer:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel (Wrap)` ⌨️
- `Mixer:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel` ⌨️
- `Mixer:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel` ⌨️

**MIDI:**
- `Paketti:Move to Next Track (Wrap) [Knob]` 🎹
- `Paketti:Move to Previous Track (Wrap) [Knob]` 🎹
- `Paketti:Move to Next Track [Knob]` 🎹
- `Paketti:Move to Previous Track [Knob]` 🎹

**Wrap:** Cycles from last track to first (and vice versa)
**No Wrap:** Stops at first/last track

Maintains column type (note column vs effect column) when switching tracks.

### Note Operations

#### Set Note to Octave (0-9)
**Shortcuts (with EditStep):**
- `Pattern Editor:Paketti:Set Note to Octave 0-9 with EditStep` ⌨️ (10 shortcuts)

**Shortcuts (without EditStep):**
- `Pattern Editor:Paketti:Set Note to Octave 0-9 without EditStep` ⌨️ (10 shortcuts)

Changes note at cursor to specified octave, preserving note value (C/C#/D/etc). **with EditStep** advances cursor by edit step amount.

#### 8 - Play Current Line
**Shortcuts:**
- `Global:Paketti:Impulse Tracker 8 Play Current Line & Advance by EditStep` ⌨️
- `Global:Paketti:Impulse Tracker 8 Play Current Line Only` ⌨️

Triggers current line's notes. **& Advance** moves cursor forward by edit step.

## Interpolation

### ALT-X - Smart Interpolation
**Shortcuts:**
- `Pattern Editor:Paketti:Impulse Tracker ALT-X Smart (Auto-detect Column)` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-X Volume Column (Interpolate&Clear)` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker ALT-X Effect Column (Interpolate&Clear)` ⌨️

**Auto-detect Column:** Intelligently detects which column type cursor is in (Volume/Panning/Delay/Sample FX/Effect) and interpolates that column type.

**Interpolation Behavior:**
1. **First ALT-X:** Interpolates between first and last values
2. **Second ALT-X (if already interpolated):** Clears interpolation

**Supported Columns:**
- Volume (sub-column 3)
- Panning (sub-column 4)
- Delay (sub-column 5)
- Sample Effect (sub-columns 6-7)
- Effect (sub-columns 8-9)

### File Operations

#### CTRL-N - New Song Dialog
**Shortcut:** `Global:Paketti:Impulse Tracker CTRL-N New Song Dialog...` ⌨️

Comprehensive new song dialog with Keep/Clear options for:
- Patterns
- Pattern Sequence
- Instruments
- Instrument Samples
- Instrument MIDI Outs
- Instrument Plugins
- Track DSPs

**Set all to:** Quick toggle for all sections
**Smart defaults:** If all set to Clear, performs standard New Song

#### CTRL-O - Pattern to Sample
**Shortcut:** `Global:Paketti:Impulse Tracker CTRL-O Pattern to Sample` ⌨️

**Menu:** `Pattern Editor:Paketti:Impulse Tracker CTRL-O Pattern to Sample` 📋

**MIDI:** `Paketti:Impulse Tracker CTRL-O Pattern to Sample [Trigger]` 🎹

Renders current pattern to new sample:
1. Renders pattern to temporary WAV
2. Creates new instrument
3. Loads rendered audio as sample
4. Applies Paketti loader preferences (autofade, autoseek, loop mode, etc.)
5. Names instrument "Pattern XX Render"
6. Cleans up temp file

### Utilities

#### ALT-F10 - Solo Toggle
**Shortcut:** `Global:Paketti:Impulse Tracker ALT-F10 (Solo Toggle)` ⌨️

Toggles solo on current track. If not in Pattern Editor or Mixer, switches to Pattern Editor first.

#### Select First Instrument
**Shortcut:** `Global:Paketti:Select First Instrument Box Slot` ⌨️

Jumps to instrument 01, displays instrument name in status.

#### Speed and Tempo to BPM Dialog
**Shortcut:** `Global:Paketti:Paketti Speed and Tempo to BPM Dialog...` ⌨️

Interactive calculator for Speed/Tempo → BPM conversion. Shows real BPM based on formula: `BPM = Tempo / (Speed / 6)`. Validates BPM range (20-999), can apply BPM to song.

### Sample Processing (Signed/Unsigned)

#### Wrap/Unwrap Operations
**Shortcuts:**
- `Sample Editor:Paketti:Wrap Signed as Unsigned` ⌨️
- `Sample Editor:Paketti:Unwrap Unsigned to Signed` ⌨️
- `Sample Editor:Paketti:Toggle Signed/Unsigned` ⌨️

**Wrap Signed as Unsigned:** Converts signed 16-bit → unsigned 16-bit (creates bit-crushed/broken sound)
**Unwrap Unsigned to Signed:** Reverses the process
**Toggle:** Automatically detects and applies correct operation

**Use Cases:** Experimental sound design, bit-manipulation effects, recreating vintage sampler artifacts.

---

## PlayerPro Suite

**Source:** `PakettiPlayerProSuite.lua` | **Features:** 51 (transpose, note grid, tools, effects)

Complete PlayerPro (Mac tracker) workflow emulation with intelligent dialogs, transpose operations, and note entry system.

### Main Dialog

**Shortcuts:**
- `Pattern Editor:Paketti:Open Player Pro Tools Dialog...` ⌨️ - Main tools interface
- `Global:Paketti:Player Pro Intelligent Dialog...` ⌨️ - Context-aware dialog
- `Global:Paketti:Open Player Pro Note Column Dialog...` ⌨️ - Note entry grid

**Menu:** Dynamic note dropdown menus for all note ranges (Pattern Editor:Paketti:Other Trackers:Note Dropdown)

### Transpose Operations

**Pattern Editor & Phrase Editor Support:**

**Row/Selection Transpose:**
- +1/-1 semitone
- +12/-12 octave
- With/without playback preview
- Selection or row mode

**Note Column Transpose:**
- +1/-1 semitone  
- +12/-12 octave
- With/without playback preview
- Affects only current note column

**All Instruments Transpose:**
- Transpose with Play (All Instruments) variants
- +1/-1/-12/+12 for row and note column
- Changes instrument assignment while transposing

**Keybindings (Pattern Editor):**
- `Player Pro Transpose Selection or Row +1/-1/+12/-12` ⌨️
- `Player Pro Transpose Selection or Note Column +1/-1/+12/-12` ⌨️
- `Player Pro Transpose ... with Play` variants ⌨️
- `Player Pro Transpose ... with Play (All Instruments)` variants ⌨️

**Keybindings (Phrase Editor):**
- `Player Pro Transpose Selection or Row +1/-1/+12/-12` ⌨️
- `Player Pro Transpose Selection or Note Column +1/-1/+12/-12` ⌨️
- `Player Pro Transpose ... with Play` variants ⌨️

### Effect Dialog

**Shortcut:** `Pattern Editor:Paketti:Player Pro Effect Dialog...` ⌨️

Quick access dialog for inserting PlayerPro-style effects into pattern. Maps PlayerPro effect commands to Renoise equivalents.

### Scanner

**Shortcut:** `Pattern Editor:Paketti:Player Pro Scanner (Start/Stop)` ⌨️

Pattern scanner tool - analyze and visualize pattern data, PlayerPro-style scrolling display.

### Note Grid

Context-aware note entry system with octave selection, note dropdowns, and quick entry shortcuts.

**Phrase Editor Support:**
- `Phrase Editor:Paketti:Player Pro Note Grid Dialog` ⌨️
- `Phrase Editor:Paketti:Player Pro Intelligent Dialog` ⌨️
- `Phrase Editor:Paketti:Player Pro Effect Dialog` ⌨️

### Workflow

**PlayerPro-Style Features:**
- Transpose with immediate playback preview
- Context-sensitive note entry
- Effect command quick access
- Phrase editor full integration
- All Instruments transpose mode

---

## OctaMED Suite

**Source:** `PakettiOctaMEDSuite.lua` | **Features:** 15

OctaMED (Amiga tracker) workflow features including Pick/Put, Note Spread, Note Echo, and track mute operations.

### Pick/Put System

**Shortcut:** `Pattern Editor:Paketti:OctaMED Pick/Put Dialog...` ⌨️

Visual dialog for Pick/Put note/instrument operations - OctaMED's clipboard system for rapid note entry.

**Pick Shortcuts (01-16):**
- `Pattern Editor:Paketti:OctaMED Pick Slot 01` through `16` ⌨️
- Captures note + instrument at cursor
- Stores in numbered slot

**Put Shortcuts (01-16):**
- `Pattern Editor:Paketti:OctaMED Put Slot 01` through `16` ⌨️
- Pastes stored note + instrument
- Advances by edit step

### Note Spread

**Shortcuts:**
- `Global:Paketti:OctaMED Note Spread 01` through `64` ⌨️
- `Pattern Editor:Paketti:OctaMED Note Spread 01` through `64` ⌨️
- `Global:Paketti:OctaMED Note Spread Increment/Decrement` ⌨️

**Menu:** `Pattern Editor:Paketti:Other Trackers:OctaMED Note Spread 01-64` 📋

**Note Spread Effect:**
- Duplicates current note across pattern
- Spacing = spread value (lines between notes)
- Creates instant drum patterns
- Increment/decrement adjusts spread value

**Example:** Spread 04 = note every 4 lines (16th notes at LPB 4)

### Note Echo

**Shortcut:** `Pattern Editor:Paketti:OctaMED Note Echo Dialog...` ⌨️

Creates echo/delay patterns from current note. Configurable:
- Echo count (repeats)
- Echo spacing (lines)
- Volume decay
- Transpose per echo

### Track Mute (01-64)

**Shortcuts:**
- `Global:Paketti:OctaMED Toggle Mute Track 01` through `64` ⌨️
- `Pattern Editor:Paketti:OctaMED Toggle Mute Track 01` through `64` ⌨️
- `Mixer:Paketti:OctaMED Toggle Mute Track 01` through `64` ⌨️
- `Phrase Editor:Paketti:OctaMED Toggle Mute Track 01` through `64` ⌨️

Direct track mute shortcuts by track number - instant mute/unmute without navigating.

### Workflow

**OctaMED-Style Features:**
- Pick/Put for rapid note entry
- Note Spread for rhythmic patterns
- Note Echo for delay effects
- Direct track muting (1-64)

---

## OpenMPT Linear Keyboard Layer

**Source:** `PakettiOpenMPTLinearKeyboardLayer.lua` | **Features:** 1

**Shortcut:** `Global:Paketti:Paketti PlayerPro OpenMPT Linear Keyboard Layer...` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti PlayerPro OpenMPT Linear Keyboard Layer...` 📋
- `Pattern Editor:Paketti Gadgets:Paketti PlayerPro OpenMPT Linear Keyboard Layer...` 📋

Advanced keyboard-to-MIDI mapper with OpenMPT-style linear keyboard layout. Transform your QWERTY keyboard into a chromatic instrument with independent octave controls per row.

### Linear Keyboard Layout

**Four keyboard rows become linear octaves:**
- **1-row:** `1234567890+=´` (13 keys) - Octave 1
- **Q-row:** `QWERTYUIOP` (10+ keys) - Octave 2  
- **A-row:** `ASDFGHJKL` (9+ keys) - Octave 3
- **Z-row:** `ZXCVBNM,.-` (10+ keys) - Octave 4

Each key triggers a semitone in sequence (C, C#, D, D#, E, F, F#, G, G#, A, A#, B, C+).

### Per-Row Octave Control

**Independent octave dropdowns (C-0 through B-9):**
- **1-row base note:** Configurable (default: C-3)
- **Q-row base note:** Configurable (default: C-4)
- **A-row base note:** Configurable (default: C-5)
- **Z-row base note:** Configurable (default: C-6)

Change any row's starting octave independently - perfect for chords across ranges or bassline + melody split.

### Special Modes

**Follow Transport Checkbox:**
When enabled, all row base notes automatically follow `renoise.song().transport.octave`:
- **1-row** = transport.octave - 1
- **Q-row** = transport.octave
- **A-row** = transport.octave + 1
- **Z-row** = transport.octave + 2

Change Renoise's octave (< / > keys), all rows shift together.

**Fret Mode Checkbox:**
Guitar-style layout with overlapping ranges (like guitar strings):
- **Z-row:** E-2 base (low E string)
- **A-row:** A-2 base (A string)
- **Q-row:** D-3 base (D string)  
- **1-row:** G-3 base (G string)

Emulates guitar fretting - adjacent keys = adjacent frets.

### Features

**Real-time MIDI Triggering:**
- Direct note triggering (bypasses Pattern Editor)
- Polyphonic (play multiple keys simultaneously)
- Note-off on key release
- Auto-cleanup for stuck notes (5s timeout)

**Visual Feedback:**
- Shows currently playing notes
- Displays active octave ranges per row
- Preset indicator
- Minimize/maximize dialog

**Integration:**
- Uses current instrument
- Respects instrument's MIDI/sample properties
- Works alongside normal pattern editing

### Use Cases

**Live Performance:**
- Play melodies with QWERTY keyboard
- Trigger samples during live sets
- Record performances into pattern

**Composition:**
- Quick melody sketching
- Chord voicing exploration
- Bass + melody layering (different rows)

**Learning Tool:**
- Visualize linear note layout
- Understand chromatic relationships
- Practice without MIDI keyboard

---

# Instrument Management

Guide to Paketti's instrument duplication, selection, chunk navigation, and management features.

**Source:** `PakettiInstrumentBox.lua` | **Keybindings:** 22+

## Instrument Duplication

### Duplicate and Select New Instrument
Creates duplicate and automatically selects the newly created instrument. Handles large samples with progress dialog, preserves all settings/samples/phrases/plugins. Multiple bindings available (2nd, 3rd).

### Duplicate and Select New Instrument (Wrong)
Alternative behavior with different selection logic. Named "Wrong" because it behaves differently than expected in certain scenarios.

### Duplicate and Select Last Instrument
Creates duplicate but selects the last instrument in the list.

## Quick Instrument Selection

### Numpad SelectPlay (1-9)
Press numpad 1-9 to select and play that instrument slot. Combines selection + note trigger - perfect for live performance.

## Capture Nearest Instrument

### Capture Nearest Instrument and Octave (nojump/jump)
Finds the nearest note in the pattern, captures its instrument number and octave value. **nojump** = cursor stays at current position. **jump** = cursor moves to the captured note's position.

## Chunk Navigation

### Next/Previous Chunk
Navigate through chunks (hex ranges: 00-0F, 10-1F, 20-2F, ..., F0-FF).

### Select Specific Chunk
Direct chunk access - jump directly to any chunk (00, 10, 20, ..., F0).

## Basic Operations
- Insert New Instrument
- Delete Current Instrument
- Load Plaid Zap .XRNI (special loader)

---

# Rendering Features

Guide to Paketti's advanced rendering and bouncing features for tracks, groups, patterns, and sample-based rendering.

**Source:** `PakettiRender.lua` | **Keybindings:** 24

## Clean Render Track/Group

### Standard Clean Render
Renders selected track or group to new instrument, creates sample at target BPM, inserts rendered instrument into new track, preserves automation and effects.

### WAV Only Render
Same as Standard but saves intermediate WAV file without loading into Renoise.

### LPB*2 Render (Double Resolution)
Temporarily doubles LPB before rendering, capturing twice the automation/effect resolution.

### Seamless Clean Render
Ensures perfect loop points and no clicks at start/end - ideal for looped samples.

## Clean Render with Save

### Render & Save to File
All-in-one operation: Renders, loads into new instrument, immediately opens save dialog. Choose format: WAV (lossless), FLAC (compressed lossless), or MP3.

## Pattern Selection Rendering
- Render Pattern Selection
- Render Pattern Selection (Mute Original)
- Render Pattern Selection (New Track)
- Render Pattern Selection (Mute + New Track)

## Pattern Matrix Rendering
Select multiple patterns in Pattern Matrix view, then render them all into a new instrument with samples.

## Experimental Features
- Experimental Sample FX Render
- Test Peak Detection

---

# Column Visibility

Guide to Paketti's column visibility management for cleaner Pattern Editor views and focused editing.

**Source:** `PakettiViews.lua` | **Keybindings:** 23

## Global Column Visibility

### Show/Hide All Columns
- **All** - Shows Volume, Panning, Delay, and Sample Effects columns on all tracks
- **None** - Hides all sub-columns on all tracks

### Toggle All Columns
- Including Sample Effects
- Excluding Sample Effects

## Individual Column Toggle

### Global Toggle/Set Specific Column Type
Toggle or force visibility of specific column type (Volume, Panning, Delay, Sample Effects) across all tracks simultaneously.

## Show Only Specific Column Type

### Toggle Show Only (Single Column Type)
Focused editing mode: Shows only the specified column type, hides all other column types. Perfect for focused volume automation, panning, delay timing, or effect column work.

## Smart Column Hiding

### Hide All Unused Columns
Intelligent cleanup - scans pattern for actual column usage, hides columns with no data. Works on all tracks or just selected track.

### Hide Unused Effect Columns
Specifically hides effect columns that contain no data.

---

# Pattern Matrix

Guide to Paketti's Pattern Matrix operations for pattern duplication, arrangement, and workflow enhancements.

**Source:** `PakettiPatternMatrix.lua` | **Keybindings:** 8 + MIDI

## Pattern Matrix Visibility
**Show/Hide Pattern Matrix** - Toggles visibility, switches to Pattern Editor if needed.

## Smart Pattern Duplication

### Duplicate Pattern Above & Clear Muted Tracks
Intelligent duplication: Creates new pattern slot above, copies all data and automation, applies mute states from sequencer, clears all muted/off tracks, names pattern appropriately.

### Duplicate Pattern Below & Clear Muted Tracks
Same as above but inserts below current position.

### Duplicate Pattern (No Clear)
Standard duplication without clearing muted tracks.

## Pattern Slot Management
- Swap Pattern Slot with Above
- Swap Pattern Slot with Below
- Swap Two Pattern Slots (interactive)

## Batch Operations

### Resize All Patterns to Current Length
Powerful batch operation taking current pattern's length and applying to ALL patterns in song.

---

# Device & Plugin Loaders

Comprehensive guide to Paketti's device and plugin loading shortcuts.

**Source:** `PakettiLoaders.lua` | **Keybindings:** 79+

## Quick Device Loading

### AutoFilter
**Add Filter & LFO (AutoFilter)** - Instant Effect Chain: Loads Filter + LFO with LFO automatically routed to Filter Cutoff.

## Native Renoise Devices

**Effects Available:** Analog Filter, Bus Compressor, Cabinet Simulator, Chorus, Chorus 2, Comb Filter 2, Compressor, Convolver, DC Offset, Delay, Digital Filter, Distortion 2, Doofer, EQ 5, EQ 10, Exciter, Flanger 2, Gainer, Gate 2, LofiMat 2, Maximizer, Mixer EQ, mpReverb 2, Multitap, Phaser 2, Repeater, Notepad, Splitter, Reverb, RingMod 2, Stereo Expander.

**Routing Devices:** #Line Input, #Multiband Send, #ReWire Input, #Send, #Sidechain.

**Modulation Devices:** ***Formula, ***Hydra, ***Instr. Automation, ***Instr. Macros, ***Instr. MIDI Control, ***Key Tracker, ***LFO, ***Meta Mixer, ***Signal Follower, ***Velocity Tracker, ***XY Pad.

## Hidden/Legacy Renoise Devices

Legacy devices (version 1.0 of effects): Chorus, Comb Filter, Distortion, Filter variants, Flanger, Gate, LofiMat, mpReverb, Phaser, RingMod, Scream Filter, Shaper, Stutter.

**Why use hidden devices?** Different character/sound than v2, CPU efficiency, retro sound design, backward compatibility.

## Third-Party Plugin Loaders

**Supported Plugins:** U-He (Zebra, Colour Copy), Waldorf (PPG v2, Attack), FabFilter (One), Rhino 2.1, Surge, Koen KTGranulator, and many more.

## Device Management
- Device Bypass/Enable Operations
- Favorited Devices Control
- Parameter Exposure in Mixer

---

# Phrase Editor

Comprehensive guide to Paketti's Phrase Editor features, creation, manipulation, and workflow enhancements.

**Source:** `PakettiPhraseEditor.lua` | **Keybindings:** 49

## Phrase Creation & Initialization

### Create New Phrase using Paketti Settings
Creates new phrase with predefined Paketti settings: custom name, autoseek, column visibility, note/effect columns, shuffle, LPB, length, looping.

### Modify Current Phrase using Paketti Settings
Applies Paketti phrase settings to currently selected phrase. If no phrase exists, creates a new one.

### Init Phrase Settings
Opens Paketti Phrase Settings preferences dialog.

### Add New Phrase
Simple phrase creation - adds new empty phrase to current instrument.

## Phrase View Controls
- Phrase Editor Visible (Toggle) - Multiple contexts
- Record + Follow Off - Impulse Tracker-style editing

## Phrase Doubler & Halver

### Phrase Doubler
Doubles phrase length and intelligently spreads out all note data.

### Phrase Halver (Joule)
Halves phrase length and compresses note data. Named "Joule" after the physics unit.

## Delay Column Controls
Fine (+1/-1) and coarse (+10/-10) delay column control. Automatically shows delay column when used.

## Write Notes Operations
- Write Notes (Ascending/Descending/Random)
- Write Notes with EditStep (Ascending/Descending/Random)

## Transpose Operations
Various transpose operations for phrase editing.

## Impulse Tracker Operations
ALT-F Expand/Shrink selection operations in Phrase Editor.

## Shift & Nudge
Pattern shifting and nudging operations.

## Flood Fill Pattern with Phrase
Fill pattern with phrase data.

---

# Automation Features

Comprehensive guide to Paketti's automation manipulation, editing, and workflow enhancement features.

**Source:** `PakettiAutomation.lua` | **Keybindings:** 49

## Switch to Automation
Quick automation view access from multiple contexts (Global, Pattern Matrix, Pattern Editor, Mixer) with Dynamic variant for intelligent switching.

## Automation Ramps

### Exponential Ramps
Creates exponential (curved) ramps: Ramp Up (Exp), Ramp Down (Exp).

### Linear Ramps
Creates linear (straight) ramps: Ramp Up (Lin), Ramp Down (Lin).

## Automation Position Controls

### Center ↔ Top (Exponential/Linear)
Creates curves/ramps from center (0.5) to top (1.0) or vice versa.

### Center ↔ Bottom (Exponential/Linear)
Creates curves/ramps from center (0.5) to bottom (0.0) or vice versa.

## Randomize Automation
- Randomize Automation Envelope
- Randomize Automation Envelopes for Device

## Automation Value Operations
- Show Automation Value Dialog
- Write Automation Value (fixed values 0.00-1.00)
- Set Automation Range (Max 1.0, Middle 0.5, Min 0.0)

## Automation Transformations
- Flood Fill Automation Selection
- Flip Automation (Horizontal/Vertical)

## Automation Playmode
Select Automation Playmode (Points/Lines/Curves).

## Pattern Operations
- Show Pattern Automation
- Copy/Paste Pattern Automation

## LFO to Automation
Generate LFO to Automation with various shapes.

## Device Snapshot to Automation
Record Device Snapshot to Automation.

---

# Pattern Editor Advanced

Comprehensive guide to Paketti's advanced Pattern Editor features - **373 keyboard shortcuts!**

**Source:** `PakettiPatternEditor.lua` | **Keybindings:** 373

## Note Column Operations
- Mute/Unmute Note Column
- Record + Follow Off (Impulse Tracker-style)

## Delay Column Controls
Pattern Editor and Phrase Editor delay controls with fine (+1/-1) and coarse (+10/-10) adjustment.

## Pattern Length Settings
Set Pattern Length to common values: 001, 004, 008, 016, 032, 064, 128, 256, 512, plus 006, 012, 024, 048, 096, 192, 384.

## Clever Note Off

### Intelligent Note-Off Placement
- Clever Note Off Right After
- Clever Note Off Right Before
- Clever Note Off Half Before

### KapsLock Note Off
Multiple variants with/without step, available in Pattern Editor, Phrase Editor, and Global contexts.

## Effect Column Operations

### Arpeggio (AXY)
Adjust arpeggio effect values (Xx and xY variants).

### Vibrato (VXY)
Adjust vibrato effect values.

### Tremolo (TXY)
Adjust tremolo effect values.

### Retrig (RXY)
Adjust retrigger effect values.

### Cut (CXX)
Adjust note cut effect values.

## LPB & Timing Controls
Global LPB settings (1-256), Pattern-specific LPB, Quantization controls.

## Pattern Doubler & Halver
dBlue-style pattern doubling and halving operations.

## BPM Controls
Various BPM adjustment shortcuts.

## Column Navigation
Smart column navigation and selection features.

## Advance Cursor Forward/Backward (NEW - Jan 2026)

**Source:** `PakettiPatternEditor.lua`

Fixed-step cursor advancement for pattern editing without relying on EditStep.

**Pattern Editor Shortcuts (01-32 Steps):**
- `Pattern Editor:Paketti:Advance Cursor Forward 01 Steps` through `32 Steps` ⌨️
- `Pattern Editor:Paketti:Advance Cursor Backward 01 Steps` through `32 Steps` ⌨️

**Phrase Editor Shortcuts (01-32 Steps):**
- `Phrase Editor:Paketti:Advance Cursor Forward 01 Steps` through `32 Steps` ⌨️
- `Phrase Editor:Paketti:Advance Cursor Backward 01 Steps` through `32 Steps` ⌨️

**MIDI Mappings:**
- `Paketti:Advance Cursor Forward 01 Steps` through `32 Steps` 🎹
- `Paketti:Advance Cursor Backward 01 Steps` through `32 Steps` 🎹

**How It Works:**
- Forward advancement moves cursor down by specified steps
- Backward advancement moves cursor up by specified steps
- Independent of EditStep setting (EditStep can be 0)
- Wraps at pattern boundaries

**Use Cases:**

**EditStep = 0 Workflow:**
- Keep EditStep at 0 for note preview
- Use Advance shortcuts for precise movement
- Combine with note entry for controlled input

**Fixed Navigation:**
- Jump exactly 4, 8, or 16 rows
- Consistent movement regardless of EditStep
- Good for grid-based editing

**MIDI Controller Integration:**
- Assign pads to common step amounts
- Hardware-based pattern navigation
- Works alongside EditStep controls

## Advanced Operations
Advanced pattern operations, transformations, and workflow enhancements.

---

# Advanced Features

## Foreign Snippets

**Source:** `PakettiForeignSnippets.lua` | **Features:** 66

Collection of experimental and utility features - advanced operations, batch conversions, and workflow enhancements.

### Auto Disk Browser Control

**Shortcut:** `Global:Paketti:Auto Control Disk Browser on Song Load` ⌨️

Automatically shows/hides disk browser when loading songs based on preference.

### Instrument Info

**Shortcuts:**
- `Global:Paketti:Show Instrument Info (Status)` ⌨️ - Status bar display
- `Global:Paketti:Show Instrument Info (Dialog)` ⌨️ - Full dialog
- `Global:Paketti:Set Instrument Info Dialog Height` ⌨️ - Adjust dialog size

Displays comprehensive instrument information:
- Sample count and properties
- Modulation chains
- FX chains
- Plugin settings
- Phrase data

### MIDI Output Management

**Shortcut:** `Global:Paketti:Set MIDI Output for All Instruments` ⌨️

Batch-sets MIDI output device for all instruments in song. Perfect for:
- Routing all to external synth
- Switching between MIDI devices
- Hardware setup changes

### Basenote Management

**Shortcut:** `Global:Paketti:Reset Basenote to Lowest Note Range` ⌨️

Resets basenote of all samples to lowest note in their keyzone range. Useful for:
- Fixing transposed samples
- Standardizing sample mappings
- Preparing for re-keymapping

### SFZ Batch Converter

**Shortcuts:**
- `Global:Paketti:Batch Convert SFZ to XRNI (Save Only)...` ⌨️
- `Global:Paketti:Batch Convert SFZ to XRNI & Load...` ⌨️

Converts multiple SFZ files to Renoise XRNI format:
- Batch folder processing
- Preserves zones and mappings
- Optional auto-load after conversion

**SFZ Support:**
- Zone mappings
- Volume/pan settings
- Loop points
- Sample layers

### Pattern Alias Operations

**Shortcuts:**
- `Global:Paketti:Alias Identical Pattern Slots` ⌨️ 📋
- `Global:Paketti:Match Automation with all Aliases` ⌨️
- `Global:Paketti:Clear Pattern Aliases` ⌨️

**Pattern Matrix:**
- `Pattern Matrix:Paketti:Alias Identical Pattern Slots` ⌨️
- `Pattern Matrix:Paketti:Match Automation with all Aliases` ⌨️
- `Pattern Matrix:Paketti:Clear Pattern Aliases` ⌨️

**Alias Identical Patterns:**
- Finds patterns with identical content
- Creates aliases to save memory
- Reduces song file size

**Match Automation:**
- Synchronizes automation across all aliases
- Updates when one is changed
- Maintains consistency

**Clear Aliases:**
- Removes all pattern aliases
- Makes each unique again
- For independent editing

### Auto-Capture Track

**Shortcuts:**
- `Pattern Editor:Paketti:Enable/Disable Auto-Capture Track` ⌨️
- `Pattern Editor:Paketti:Auto-Capture Track (Cycle All Modes)` ⌨️
- `Pattern Editor:Paketti:Auto-Capture Track (Pattern Editor Only)` ⌨️
- `Pattern Editor:Paketti:Auto-Capture Track (Not Pattern Editor)` ⌨️
- `Pattern Editor:Paketti:Auto-Capture Track (All Frames)` ⌨️
- `Mixer:Paketti:Capture Track from Instrument` ⌨️

**Mixer Context:** Full duplicate set of shortcuts

**Auto-Capture System:**
- Automatically switches track when instrument changes
- Multiple capture modes (Pattern Editor only, Not Pattern Editor, All Frames)
- Manual capture trigger
- Enable/disable toggle

**Use Cases:**
- Organize tracks by instrument automatically
- Studio recording workflow
- Live performance setup

---

## Preset++

**Source:** `PakettiPresetPlusPlus.lua` | **Features:** 79

Advanced DSP device preset system with intelligent send creation, multiband sends, LFO presets, and device chain inspection.

### Device Inspection

**Shortcuts:**
- `Global:Paketti:Inspect Selected Device` ⌨️ - Shows selected device parameters
- `Global:Paketti:Inspect Track Device Chain` ⌨️ - Shows entire device chain
- `Global:Paketti:Inspect Track Device Chain (Clean)` ⌨️ - Cleaned output

**Menu:**
- `DSP Chain:Paketti:Inspect Track Device Chain` 📋
- `DSP Chain:Paketti:Inspect Track Device Chain (Clean)` 📋
- `Mixer:Paketti:Inspect Track Device Chain` 📋
- `Mixer:Paketti:Inspect Selected Device` 📋

Displays device parameters, values, and ranges in human-readable format. "Clean" version removes technical clutter.

### Send Device Creation

**Send Device Shortcuts:**
- `Global:Paketti:Send Device (Preset++)` ⌨️
- `Global:Paketti:Send (Preset++)` ⌨️

**Multiband Send Shortcuts:**
- `Global:Paketti:Multiband Send Device (Preset++)` ⌨️
- `Global:Paketti:Multiband Send (Preset++)` ⌨️

**Menu (All Contexts):**
- `DSP Device:Paketti:Preset++:Send Device` 📋
- `DSP Device:Paketti:Preset++:Multiband Send Device` 📋
- `DSP Chain:Paketti:Send Device (Preset++)` 📋
- `Mixer:Paketti:Preset++:Send Device` 📋

Adds pre-configured Send or Multiband Send device with optimal routing.

### Send Track Creation

**Basic Send Track:**
- `Global:Paketti:Create New Send Track (Preset++)` ⌨️

**Advanced Send Track Creation:**
- `Global:Paketti:Create New Send Track (Keep Source) (Preset++)` ⌨️
- `Global:Paketti:Create New Send Track (Mute Source) (Preset++)` ⌨️
- `Global:Paketti:Create New Multiband Send Track (Keep Source) (Preset++)` ⌨️
- `Global:Paketti:Create New Multiband Send Track (Mute Source) (Preset++)` ⌨️

**Menu (All Contexts):**
- `DSP Chain:Paketti:Create New Send Track ...` 📋
- `DSP Device:Paketti:Preset++:Create New Send Track ...` 📋
- `Mixer:Paketti:Preset++:Create New Send Track ...` 📋
- `Pattern Matrix:Paketti:Preset++:Create New Send Track ...` 📋
- `Pattern Editor:Paketti:Create New Send Track ...` 📋

**Keep Source:**
- Creates send track
- Original track continues playing
- Parallel processing

**Mute Source:**
- Creates send track
- Mutes original track
- Send-only processing

**Multiband Variants:**
- Creates Multiband Send device
- Frequency-split routing
- Multi-band parallel processing

### LFO Presets

**SeparateSyncLFO (Beatsgo):**
- `Global:Paketti:SeparateSyncLFO (Beatsgo) (Preset++)` ⌨️

**Menu:**
- `DSP Device:Paketti:Preset++:SeparateSyncLFO (Beatsgo LFO)` 📋
- `DSP Chain:Paketti:SeparateSyncLFO (Beatsgo) (Preset++)` 📋
- `Mixer:Paketti:Preset++:SeparateSyncLFO (Beatsgo LFO)` 📋

Pre-configured LFO with beat-synced modulation, optimized Beatsgo settings.

**LFOEnvelopePan:**
- `Global:Paketti:LFOEnvelopePan (Preset++)` ⌨️

**Menu:**
- `DSP Device:Paketti:Preset++:LFOEnvelopePan` 📋
- `DSP Chain:Paketti:LFOEnvelopePan (Preset++)` 📋
- `Mixer:Paketti:Preset++:LFOEnvelopePan` 📋

LFO preset with envelope-based panning modulation.

### Filter Presets

**Hipass:**
- `Global:Paketti:Hipass (Preset++)` ⌨️
- `DSP Device:Paketti:Hipass (Preset++)` ⌨️
- `Mixer:Paketti:Hipass (Preset++)` ⌨️

**Menu:**
- `DSP Device:Paketti:Preset++:Hipass` 📋
- `DSP Chain:Paketti:Hipass (Preset++)` 📋
- `Mixer:Paketti:Preset++:Hipass` 📋

Pre-configured high-pass filter with optimal settings.

### Workflow

**Preset++ Philosophy:**
- One-click device insertion with optimal settings
- Context-aware menu placement
- Advanced routing automation
- Professional mixing shortcuts

---

## Zero Crossings

**Source:** `PakettiZeroCrossings.lua` | **Features:** 59

Advanced slicing system based on zero-crossing detection - create perfect, click-free slices with BPM-synced movement and randomization.

### Advanced Dialog

**Shortcut:** `Global:Paketti:Zero Crossings Advanced Dialog` ⌨️

**Menu:**
- `Sample Editor:Paketti:Zero Crossings:Advanced Dialog` 📋
- `Instrument Box:Paketti:Zero Crossings:Advanced Dialog` 📋
- `Sample Navigator:Paketti:Zero Crossings:Advanced Dialog` 📋

Comprehensive zero-crossing slicer with:
- Threshold adjustment
- Slice count control
- Visual waveform display
- Slice preview
- Zero-crossing snap

### Snap Selection

**Shortcut:** `Sample Editor:Paketti:Snap Selection to Zero Crossings` ⌨️

**Menu:** `Sample Editor:Paketti:Zero Crossings:Snap Selection to Zero Crossings` 📋

Adjusts selection boundaries to nearest zero crossings - eliminates clicks when looping or slicing.

### Wipe&Slice (Zero Crossing)

**Shortcuts:**
- `Global:Paketti:Zero Crossing Wipe&Slice (002)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (004)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (008)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (016)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (032)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (064)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (128)` ⌨️

**Menu:** `Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (002-128)` 📋

**Wipe&Slice Algorithm:**
1. Deletes existing slice markers
2. Creates N evenly-spaced slices
3. Snaps each to nearest zero crossing
4. Result: Perfect, click-free slices

### Slice Randomization

**Shortcuts:**
- `Global:Paketti:Randomize Slice Positions` ⌨️
- `Global:Paketti:Create Random Distributed Slices` ⌨️

**Menu:**
- `Sample Editor:Paketti:Zero Crossings:Randomize:Randomize Existing Slices` 📋
- `Sample Editor:Paketti:Zero Crossings:Randomize:Create Random Distributed Slices` 📋
- `Instrument Box:Paketti:Zero Crossings:Randomize Slices` 📋

**Randomize Existing:**
- Moves existing slices to random positions
- Maintains slice count
- Snaps to zero crossings

**Create Random:**
- Generates new random slice distribution
- Configurable slice count
- Zero-crossing aligned

### BPM-Synced Slice Movement

**Slice Start Movement:**
- `Sample Editor:Paketti:Move Slice Start -/+ 1/4 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -/+ 1/8 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -/+ 1/16 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -/+ 1/32 Beat` ⌨️

**Slice End Movement:**
- `Sample Editor:Paketti:Move Slice End -/+ 1/4 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -/+ 1/8 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -/+ 1/16 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -/+ 1/32 Beat` ⌨️

**Menu:** `Sample Editor:Paketti:Zero Crossings:BPM Movement:...` 📋 (all variants)

**BPM-Synced Movement:**
- Moves slice markers by musical timing
- 1/4 beat = quarter note
- 1/8 beat = eighth note
- 1/16 beat = sixteenth note
- 1/32 beat = thirty-second note

**Use Cases:**
- Adjust slice timing to groove
- Fix slightly off-beat slices
- Quantize slice markers
- Create swing feel

### Workflow

**Zero-Crossing Benefits:**
- Click-free slices
- Clean loops
- Professional quality
- No artifacts

**Perfect For:**
- Drum breaks
- Vocal chops
- Melodic samples
- Loop creation

---

## Dirtywave M8 Integration

**Source:** `PakettiM8Export.lua` | **Features:** 8

Import/export samples and instruments between Renoise and Dirtywave M8 tracker.

### Export to M8

**Shortcuts:**
- `Global:Paketti:M8 Export Sample Chain` ⌨️
- `Global:Paketti:M8 Export Instrument` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:M8:Export Sample Chain` 📋
- `Main Menu:Tools:Paketti:Xperimental/WIP:M8:Export Instrument` 📋

**Sample Chain:**
- Exports all samples in instrument as M8-compatible chain
- Generates slice data
- Creates M8 instrument file

**Instrument Export:**
- Full instrument with samples
- Preserves keymapping
- M8-compatible format

### Import from M8

**Shortcuts:**
- `Global:Paketti:M8 Import Sample Chain` ⌨️
- `Global:Paketti:M8 Import Instrument` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:M8:Import Sample Chain` 📋
- `Main Menu:Tools:Paketti:Xperimental/WIP:M8:Import Instrument` 📋

**Sample Chain Import:**
- Loads M8 sample chains
- Restores slices
- Maps to Renoise instrument

**Instrument Import:**
- Loads M8 instruments
- Converts to XRNI format
- Preserves samples and mapping

### Workflow

**M8 → Renoise:**
- Capture M8 beats in Renoise
- Process with Renoise DSP
- Re-export back to M8

**Renoise → M8:**
- Create complex instruments in Renoise
- Export for M8 performance
- Hybrid production workflow

---

## Teenage Engineering OP-1 Integration

**Source:** `PakettiOP1Export.lua` | **Features:** 10

Export samples and drumkits to Teenage Engineering OP-1/OP-Z format with AIFF metadata.

### Export Drum Kit

**Shortcut:** `Global:Paketti:OP-1 Export Drum Kit` ⌨️

**Menu:** `Main Menu:Tools:Paketti:Xperimental/WIP:OP-1:Export Drum Kit` 📋

**Drum Kit Format:**
- 24 samples maximum (OP-1 pads)
- AIFF format with OP-1 metadata
- Slice markers preserved
- Pad mapping (1-24)

**Process:**
1. Select instrument with samples
2. Export as OP-1 drum kit
3. Transfer AIFF files to OP-1
4. Load on OP-1 Drum Sampler

### Export Tape

**Shortcut:** `Global:Paketti:OP-1 Export Tape` ⌨️

**Menu:** `Main Menu:Tools:Paketti:Xperimental/WIP:OP-1:Export Tape` 📋

Exports audio to OP-1 Tape format:
- Tape-compatible AIFF
- 4-track tape metadata
- Timestamp embedding
- Album artwork (optional)

### Export Sample

**Shortcut:** `Global:Paketti:OP-1 Export Sample` ⌨️

**Menu:** `Main Menu:Tools:Paketti:Xperimental/WIP:OP-1:Export Sample` 📋

Single sample export with OP-1 AIFF chunks:
- Loop points preserved
- BPM metadata
- Key/transpose info
- OP-1 sampler compatible

### Import Sample

**Shortcut:** `Global:Paketti:OP-1 Import Sample` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:OP-1:Import Sample` 📋
- `Sample Editor:Paketti:Xperimental/WIP:OP-1:Import Sample` 📋
- `Sample Mappings:Paketti:Xperimental/WIP:OP-1:Import Sample` 📋

Imports OP-1 AIFF files with metadata:
- Reads loop points from metadata
- Applies BPM info
- Restores transpose settings
- Converts to Renoise format

### Use Cases

**OP-1 → Renoise:**
- Import OP-1 recordings
- Process with full DAW capabilities
- Edit and enhance

**Renoise → OP-1:**
- Create drum kits in Renoise
- Export for portable OP-1 use
- Hybrid production workflow

---

## FastTracker XI Export

**Source:** `PakettiXIExport.lua` | **Features:** 3

**Shortcut:** `Global:Paketti:Export Instrument to XI...` ⌨️

**Menu:**
- `Main Menu:File:Paketti Export:Export Instrument to XI...` 📋
- `Sample Editor:Paketti:Export:Export Instrument to XI...` 📋
- `Instrument Box:Paketti:Export:Export Instrument to XI...` 📋

Exports current Renoise instrument to FastTracker II .XI (Extended Instrument) format.

**XI Format:**
- Sample data
- Keymapping
- Volume envelope
- Panning envelope
- FT2 compatible

**Use Cases:**
- Share instruments with FT2 users
- Archive in classic format
- Cross-tracker compatibility

---

## Impulse Tracker ITI Export

**Source:** `PakettiITIExport.lua` | **Features:** 3

**Shortcuts:**
- `Global:Paketti:Export Instrument to ITI...` ⌨️
- `Sample Editor:Paketti:Export Instrument to ITI...` ⌨️

**Menu:** `Sample Editor:Paketti:Export:Export Instrument to ITI...` 📋

Exports current Renoise instrument to Impulse Tracker .ITI (Impulse Tracker Instrument) format.

**ITI Format:**
- Full instrument data
- All samples
- Envelopes
- NNA (New Note Action)
- IT2 compatible

**Use Cases:**
- Share with Impulse Tracker / OpenMPT users
- Archive in IT format
- Classic tracker compatibility

---

# Slicing Tools

## Stem Slicer

**Source:** `PakettiStemSlicer.lua` | **Features:** 2

Advanced stem separation and slicing tool - separate audio into stems (drums, bass, vocals, other) then slice each stem independently.

### Main Dialog

**Shortcut:** `Global:Paketti:Paketti StemSlicer Dialog...` ⌨️

**Menu:** `Main Menu:Tools:Paketti:StemSlicer:Paketti StemSlicer...` 📋

Comprehensive stem separation interface with:
- AI-powered stem separation
- Per-stem slice control
- BPM detection
- Automatic instrument creation
- Pattern writing

**Stem Separation:**
- Drums
- Bass
- Vocals
- Other (everything else)

**Process:**
1. Select sample
2. AI separates into 4 stems
3. Each stem gets own instrument
4. Optional: Auto-slice each stem
5. Optional: Write to pattern

### Output Management

**Shortcut:** `Global:Paketti:Open Last StemSlicer Output...` ⌨️

**Menu:** `Main Menu:Tools:Paketti:StemSlicer:Open Last StemSlicer Output...` 📋

Opens folder containing last stem separation output. Quick access to:
- Separated stem WAV files
- Slice data
- Processing logs

### Use Cases

**Remixing:**
- Separate full mix into stems
- Rearrange individual elements
- Create new arrangements

**Sampling:**
- Extract drums from full mix
- Isolate vocals
- Get bass/melodic content

**DJing:**
- Create instant acapellas
- Extract drum breaks
- Build mashup stems

---

## Stem Loader

**Source:** `PakettiStemLoader.lua` | **Features:** 20+

Comprehensive stem loading system that imports multiple audio files (stems) into separate tracks with automatic BPM detection, pattern creation, slice triggering, and advanced randomization features.

### Main Loader

**Shortcuts:**
- `Global:Paketti:Paketti Stem Loader` ⌨️
- `Global:Paketti:Paketti Stem Loader (Normalize)` ⌨️
- `Global:Paketti:Paketti Stem Loader (No Preset)` ⌨️
- `Global:Paketti:Paketti Stem Loader (No Preset + Normalize)` ⌨️
- `Global:Paketti:Paketti Stem Loader (Slice to Patterns)` ⌨️
- `Global:Paketti:Paketti Stem Loader (Slice to Patterns + Normalize)` ⌨️
- `Global:Paketti:Paketti Stem Loader (Slice to Patterns + No Preset)` ⌨️
- `Global:Paketti:Paketti Stem Loader (Slice to Patterns + No Preset + Normalize)` ⌨️
- `Global:Paketti:Paketti Stem Loader (Forwards+Reverse)` ⌨️
- `Global:Paketti:Paketti Stem Loader (Forwards+Reverse + Normalize)` ⌨️

**Menu Entries:**
- `Main Menu:File:Paketti StemLoader...` 📋
- `Main Menu:File:Paketti StemLoader (Slice to Patterns)...` 📋

**Core Features:**
- Load multiple audio files, each into its own instrument on its own track
- Automatic track naming based on filename
- C-4 triggers with 0G01 glide command written to patterns
- Automatic BPM detection from:
  - WAV file ACID chunk header
  - Folder name patterns (e.g., "146BPM", "BPM_120", "song_90bpm")
  - Filename patterns
- Pattern sequence creation based on sample length
- `*Instr. Macros` device added to each track

**Loading Modes:**

1. **Autoseek Mode (Default):**
   - Simple C-4 trigger with autoseek ON
   - Stems play synchronized with pattern

2. **Slice to Patterns Mode:**
   - Creates slices based on pattern length
   - Writes slice notes across patterns
   - Each pattern triggers corresponding slice

3. **Forwards+Reverse Mode:**
   - Creates two tracks per stem (forward + reversed)
   - Useful for tape-style effects and creative mixing

**BPM Detection Priority:**
1. WAV ACID chunk metadata
2. Folder name in path (checks all folders, deepest first)
3. Filename patterns
4. Majority vote if multiple stems have different BPM values

### Stem Slice Randomizer Dialog

**Shortcut:** `Global:Paketti:Stem Slice Randomizer Dialog...` ⌨️

Opens comprehensive dialog for randomizing slice triggers across loaded stems.

**Randomization Modes:**

1. **Independent Randomization:**
   - Each stem gets different random slices
   - Creates polyrhythmic/chaotic variations
   - Step sizes: 1, 2, 4, 8, 16, 32

2. **Synchronized Randomization:**
   - All stems trigger same slice number
   - Preserves song structure while randomizing position
   - Step sizes: 1, 2, 4, 8, 16, 32

3. **Odd Step Sizes:**
   - Independent Odd: 3, 5, 7, 9, 11, 13
   - Synchronized Odd: 3, 5, 7, 9, 11, 13

**Dialog Controls:**
- **Pattern Mode:** Current pattern only, or all patterns
- **Selection Only:** Randomize only within pattern editor selection
- **Quick Select till End:** Auto-select from cursor to pattern end
- **Carry Selection:** Preserve row range when changing tracks
- **Step Size Sliders:** Visual control for step granularity
- **Duplicate to New Pattern:** Create variation in new pattern

**MIDI Mappings:**
- `Paketti:Midi Knob Stem Slice Randomizer (Independent)` 🎹
- `Paketti:Midi Knob Stem Slice Randomizer (Synchronized)` 🎹
- `Paketti:Midi Knob Stem Slice Randomizer Odd (Independent)` 🎹
- `Paketti:Midi Knob Stem Slice Randomizer Odd (Synchronized)` 🎹

### Additional Stem Loader Shortcuts

**Randomization Shortcuts:**
- `Global:Paketti:Stem Loader Randomize Independent 1-Step` through `32-Step` ⌨️
- `Global:Paketti:Stem Loader Randomize Synchronized 1-Step` through `32-Step` ⌨️
- `Global:Paketti:Stem Loader Randomize Odd Independent 3-Step` through `13-Step` ⌨️
- `Global:Paketti:Stem Loader Randomize Odd Synchronized 3-Step` through `13-Step` ⌨️
- `Global:Paketti:Stem Loader Sequential 1-Step` through `32-Step` ⌨️
- `Global:Paketti:Stem Loader Create Phrases from Slices` ⌨️

### Use Cases

**Multi-track Production:**
- Load stems from DAW exports (drums, bass, vocals, synths)
- Each stem gets its own track with proper routing
- BPM automatically detected and applied

**Live Performance:**
- Randomize slice positions for instant variations
- Independent mode for polyrhythmic chaos
- Synchronized mode for structured remixing

**Remix Work:**
- Load separated stems
- Create new arrangements with slice randomization
- Forwards+Reverse for tape-style effects

**Sample Pack Organization:**
- Batch load related samples
- Auto-create patterns and triggers

---
> *AI-powered stem separation and intelligent slice randomization — features like these take serious development time.*
> *If Paketti saves you hours, consider [supporting on Patreon →](http://patreon.com/esaruoho)*
---
- Quickly audition and arrange

---

## Sample FX Chain Slicer

**Source:** `PakettiSampleFXChainSlicer.lua` | **Features:** 2

Applies Sample FX Chain to individual slices, rendering each slice with effects - create processed drumkits from single breakbeat.

### Features

**Shortcuts:** (2 main operations)
- Slice processing with FX chain
- Batch render slices

**Process:**
1. Create slices on sample
2. Add Sample FX Chain to instrument
3. Run FX Chain Slicer
4. Each slice rendered with FX
5. New samples created
6. Original untouched

**Use Cases:**
- Apply reverb to each drum hit independently
- Process slices with different FX
- Create variations from one source
- Destructive FX application per slice

**Output:**
- New samples per slice
- All in same instrument
- Keymapped chromatically
- Original preserved

---

# Utility Tools

## Steppers

**Source:** `PakettiSteppers.lua` | **Features:** 18+

Advanced control over Renoise's Sample Modulation Steppers (Pitch, Volume, Cutoff, Resonance, Drive, Panning).

### Main Dialog

**Shortcut:** `Global:Paketti:Paketti Steppers Dialog...` ⌨️

Comprehensive stepper management interface with visual step editing, preset loading, randomization, and real-time preview.

### Show/Hide Steppers

**Shortcuts:**
- `Global:Paketti:Show/Hide PitchStep on Selected Instrument` ⌨️
- `Global:Paketti:Show/Hide VolumeStep on Selected Instrument` ⌨️
- `Global:Paketti:Show/Hide CutoffStep on Selected Instrument` ⌨️
- `Global:Paketti:Show/Hide ResonanceStep on Selected Instrument` ⌨️
- `Global:Paketti:Show/Hide DriveStep on Selected Instrument` ⌨️
- `Global:Paketti:Show/Hide PanningStep on Selected Instrument` ⌨️

**Menu:** `Instrument Box:Paketti:Steppers:Show Selected Instrument X Stepper` 📋 (all variants)

Toggles visibility of specific stepper on current instrument. Quick access to specific modulation.

### Reset All Steppers

**Shortcut:** `Global:Paketti:Reset All Steppers` ⌨️

Resets all stepper values across all instruments to neutral position.

### Clear Stepper

**Shortcuts:** `Global:Paketti:Clear X Steps` ⌨️ (for each stepper type)

**Menu:** `Sample Modulation Matrix:Paketti:Clear X Steps` 📋

Clears all step values for specific stepper type (Pitch/Volume/Cutoff/etc).

### PitchStepper Operations

**Demo:**
- `Global:Paketti:PitchStepper Demo` ⌨️

**Modify Shortcuts:**
- `Global:Paketti:Modify PitchStep Steps (Random)` ⌨️
- `Global:Paketti:Modify PitchStep Steps (Octave Up, Octave Down)` ⌨️
- `Global:Paketti:Modify PitchStep Steps (Octave Up+2, Octave Down-2)` ⌨️
- `Global:Paketti:Modify PitchStep Steps (Hard Detune)` ⌨️
- `Global:Paketti:Modify PitchStep Steps (Minor Flurry)` ⌨️
- `Global:Paketti:Clear PitchStep Steps` ⌨️

**Random:**
- Randomizes all pitch steps
- Creates unpredictable melodies
- Great for happy accidents

**Octave Up/Down:**
- Alternates between +12 and -12 semitones
- Classic arpeggio pattern
- Clean octave jumps

**Octave Up+2/Down-2:**
- Wider pitch range (±24 semitones)
- Two-octave arpeggios
- Dramatic pitch movement

**Hard Detune:**
- ±0.05 semitones * 64 steps
- Analog-style detuning
- Chorus/doubling effect

**Minor Flurry:**
- ±0.015 semitones * 64 steps
- Subtle pitch variation
- Humanization

### Use Cases

**Rhythmic Modulation:**
- Volume stepper for side-chain effect
- Panning stepper for auto-pan
- Cutoff stepper for rhythmic filtering

**Melodic Generation:**
- Pitch stepper for arpeggios
- Random pitch for generative melodies
- Octave patterns for basslines

**Sound Design:**
- Drive stepper for rhythmic distortion
- Resonance stepper for filter sweeps
- Combined steppers for complex modulation

---

## Frame Calculator

**Source:** `PakettiFrameCalculator.lua` | **Features:** 32

Comprehensive timing calculator - displays frame counts, song length, pattern timing, and cursor position in frames/time.

### Frame Calculator Dialog

**Shortcut:** `Global:Paketti:Frame Calculator Dialog` ⌨️

**Menu:**
- `Pattern Matrix:Paketti:Frame Calculator Dialog` 📋
- `Pattern Sequencer:Paketti:Frame Calculator Dialog` 📋
- `Pattern Editor:Paketti:Frame Calculator Dialog` 📋
- `Mixer:Paketti:Frame Calculator Dialog` 📋

Visual calculator with real-time display:
- BPM ↔ frames conversion
- Pattern length in frames
- Sequence length
- Cursor position timing

### Pattern Frame Info

**Shortcut:** `Global:Paketti:Show Pattern Frame Info` ⌨️

**Menu:**
- `Pattern Matrix:Paketti:Show Pattern Frame Info` 📋
- `Pattern Sequencer:Paketti:Show Pattern Frame Info` 📋
- `Pattern Editor:Paketti:Show Pattern Frame Info` 📋
- `Mixer:Paketti:Show Pattern Frame Info` 📋

Displays frame count for current pattern in status bar.

### Sequence Frame Info

**Shortcut:** `Global:Paketti:Show Sequence Frame Info` ⌨️

**Menu:**
- `Pattern Matrix:Paketti:Show Sequence Frame Info` 📋
- `Pattern Sequencer:Paketti:Show Sequence Frame Info` 📋
- `Pattern Editor:Paketti:Show Sequence Frame Info` 📋
- `Mixer:Paketti:Show Sequence Frame Info` 📋

Displays frame count for current sequence position in status bar.

### Pattern to Line Frame Info

**Shortcut:** `Global:Paketti:Show Pattern to Line Frame Info` ⌨️

**Menu:** `Pattern Editor:Paketti:Show Pattern to Line Frame Info` 📋

Shows frame count from pattern start to cursor line.

### Song to Line Frame Info

**Shortcut:** `Global:Paketti:Show Song to Line Frame Info` ⌨️

**Menu:** `Pattern Editor:Paketti:Show Song to Line Frame Info` 📋

Shows frame count from song start to cursor line - absolute position in frames.

### Song Length

**Shortcuts:**
- `Global:Paketti:Show Song Length` ⌨️ - Status bar display
- `Global:Paketti:Show Song Length Dialog` ⌨️ - Full dialog

**Menu:**
- `Pattern Matrix:Paketti:Show Song Length` 📋
- `Pattern Sequencer:Paketti:Show Song Length` 📋
- `Pattern Editor:Paketti:Show Song Length` 📋
- `Mixer:Paketti:Show Song Length` 📋

Calculates and displays total song length in:
- Frames
- Samples
- Seconds
- Minutes:seconds

### Live Update Modes

**Shortcuts:**
- `Global:Paketti:Toggle Frame Calculator Live Update (Song to Line)` ⌨️
- `Global:Paketti:Toggle Frame Calculator Live Update (Pattern to Line)` ⌨️
- `Global:Paketti:Toggle Frame Calculator Live Update (Both)` ⌨️

**Live Updates:**
- Continuously displays frame position
- Updates as cursor moves
- Song to Line: From song start
- Pattern to Line: From pattern start
- Both: Both displays simultaneously

### Use Cases

**Video Sync:**
- Calculate exact frame timing
- Match Renoise to video frames
- Frame-accurate cuts/edits

**Sample-Accurate Editing:**
- Know exact sample position
- Precise loop point calculation
- Subsample accuracy

**Timing Analysis:**
- Measure pattern lengths
- Calculate section durations
- Plan arrangement timing

---

## Launch App

**Source:** `PakettiLaunchApp.lua` | **Features:** 28+

Open samples in external applications with automatic temp file creation and Smart Folder integration.

### Smart/Backup Folders

**Save Single Sample (01-10):**
- `Global:Paketti:Save Sample to Smart/Backup Folder 1-10` ⌨️

**Menu:**
- `Sample Navigator:Paketti:Save:Save Sample to Smart/Backup Folder 1-10` 📋
- `Sample Mappings:Paketti:Save:Save Sample to Smart/Backup Folder 1-10` 📋
- `Sample Editor:Paketti:Save:Save Sample to Smart/Backup Folder 1-10` 📋

**Save All Samples (01-10):**
- `Global:Paketti:Save All Samples to Smart/Backup Folder 1-10` ⌨️

**Menu:**
- `Sample Navigator:Paketti:Save:Save All Samples to Smart/Backup Folder 1-10` 📋
- `Sample Mappings:Paketti:Save:Save All Samples to Smart/Backup Folder 1-10` 📋
- `Instrument Box:Paketti:Save:Save All Samples to Smart/Backup Folder 1-10` 📋

**Smart Folders:**
- 10 configurable quick-save locations
- Instant backup workflow
- Project organization
- Sample library building

### External Editor Integration

**Configure:**
- `Global:Paketti:Configure Launch App Selection...` ⌨️

**Launch App Features:**
- Open selected sample in external app
- Open sample range/selection
- Automatic temp file creation
- Monitor for changes
- Auto-reload on save

**Supported Contexts:**
- Sample Navigator
- Sample Editor
- Sample Mappings
- Instrument Box

**Use Cases:**
- Edit in Audacity
- Process in iZotope RX
- Spectral edit in external app
- Destructive processing workflow

---

## XMLizer (Custom LFO System)

**Source:** `PakettiXMLizer.lua` | **Features:** 27

Advanced LFO envelope management with custom presets, XML editing, resolution doubling/halving, and transformation operations.

### Custom LFO Presets

**Apply Presets (01-16):**
- `Global:Paketti:Apply Custom LFO Preset 01-16` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Apply Custom LFO Preset 01-16` 📋
- `DSP Device:Paketti:Custom LFO Envelopes:Apply Custom LFO Preset 01-16` 📋

**Store Presets (01-16):**
**Menu:**
- `Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Store Current LFO to Slot 01-16` 📋
- `DSP Device:Paketti:Custom LFO Envelopes:Store Current LFO to Slot 01-16` 📋

**Shortcuts:**
- `Global:Paketti:Store Current LFO to Slot 01-16` ⌨️

**Load Presets (01-16):**
**Menu:**
- `Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Load LFO from Slot 01-16` 📋
- `DSP Device:Paketti:Custom LFO Envelopes:Load LFO from Slot 01-16` 📋

**Shortcuts:**
- `Global:Paketti:Load LFO from Slot 01-16` ⌨️

**Preset System:**
- 16 storable LFO slots
- Quick recall presets
- Build custom LFO library
- Share between projects

### LFO Resolution

**Shortcuts:**
- `Global:Paketti:Double LFO Envelope Resolution` ⌨️
- `Global:Paketti:Halve LFO Envelope Resolution` ⌨️

**Double Resolution:**
- Increases point density
- More detailed modulation
- Smoother curves

**Halve Resolution:**
- Reduces point density
- Simpler envelopes
- Stepped modulation

### LFO External Editor

**Shortcuts:**
- `Global:Paketti:Toggle LFO/Device External Editor` ⌨️
- `Global:Paketti:List Devices with External Editor Support` ⌨️
- `Global:Paketti:Quick LFO Custom Editor` ⌨️

**External Editor:**
- Edit LFO XML directly
- Advanced curve control
- Mathematical precision
- Power-user features

### LFO Envelope Transformations

**Scale Operations:**
- `Global:Paketti:Custom LFO Envelope Scale 50%` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale 150%` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale FLIP` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Invert` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Mirror` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Slapback` ⌨️

**Adjustment Operations:**
- `Global:Paketti:Custom LFO Envelope Scale Center` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Min` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Max` ⌨️

**Randomization:**
- `Global:Paketti:Custom LFO Envelope Scale Randomize` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Humanize` ⌨️

**Scale 50%/150%:**
- Reduces/increases amplitude
- Subtle/extreme modulation

**FLIP:**
- Reverses envelope horizontally
- Backward modulation

**Invert/Mirror:**
- Flips envelope vertically
- Negative → positive, positive → negative

**Slapback:**
- Creates delay/echo pattern in envelope
- Rhythmic modulation

**Center/Min/Max:**
- Centers envelope around midpoint
- Sets all to minimum
- Sets all to maximum

**Randomize:**
- Random point positions
- Chaotic modulation
- Experimental textures

**Humanize:**
- Subtle random variations
- Natural feel
- Anti-robotic

### LFO Envelope Editor Dialog

**Shortcut:** `Global:Paketti:LFO Envelope Editor Dialog` ⌨️

Visual LFO editor with:
- Point-by-point control
- Transformation presets
- Real-time preview
- XML export

### Send Reverser

**Shortcut:** `Global:Paketti:Send Reverser` ⌨️

Special utility - reverses send device routing behavior (keep/mute toggle).

### Use Cases

**Modulation Design:**
- Build custom LFO shapes
- Create modulation presets library
- Complex rhythmic modulation

**Sound Transformation:**
- Apply mathematical transformations
- Generate unpredictable modulation
- Precision control

**Preset Management:**
- Store favorite LFO shapes
- Quick recall complex envelopes
- Share between projects

---

## Theme Selector

**Source:** `PakettiThemeSelector.lua` | **Features:** 3

Comprehensive Renoise theme management with favorites system and random theme selection.

### Open Theme Selector Dialog

**Shortcut:** `Global:Paketti Theme Selector:Open Paketti Theme Selector Dialog...` ⌨️

Visual theme browser with:
- Preview all installed themes
- Mark favorites
- Apply themes instantly
- Organize theme collection
- Search/filter themes

### Pick Random Theme (All)

**Shortcut:** `Global:Paketti Theme Selector:Pick a Random Theme (All)` ⌨️

Randomly selects and applies any theme from your entire installed theme collection. Perfect for:
- Discovering forgotten themes
- Daily inspiration
- Breaking creative ruts
- Finding new color schemes

### Pick Random Theme (Favorites)

**Shortcut:** `Global:Paketti Theme Selector:Pick a Random Theme (Favorites)` ⌨️

Randomly selects and applies a theme from your favorites list. Uses your curated collection of preferred themes.

**Favorites System:**
- Mark themes as favorites in dialog
- Build curated theme collection
- Quick random selection from best themes
- Organize preferred color schemes

### Use Cases

**Visual Variety:**
- Change theme mood by project
- Random theme for fresh perspective
- Test UI readability across themes

**Workflow Organization:**
- Different themes for different projects
- Visual project identification
- Mood-based theme selection

---
---

# Audio Processing & Effects

Complete guide to Paketti's audio processing, silence removal, channel inversion, phase manipulation, and creative effects.

---

## Table of Contents
1. [Silence Processing](#silence-processing)
2. [Channel Inversion](#channel-inversion)
3. [DC Offset Removal](#dc-offset-removal)
4. [Fade In/Out](#fade-inout)
5. [Phase Manipulation](#phase-manipulation)
6. [Audio Diff](#audio-diff)
7. [Creative Effects](#creative-effects)
8. [Audio Processing Tools Dialog](#audio-processing-tools-dialog)

---

## Silence Processing

### Strip Silence
**Shortcut:** `Global:Paketti:Strip Silence` ⌨️ 🎹 📋

**MIDI:** `Paketti:Strip Silence` 🎹

**Menu:** `Sample Editor:Paketti:Process:Strip Silence` 📋
**Menu:** `Sample Navigator:Paketti:Process:Strip Silence` 📋
**Menu:** `Sample Mappings:Paketti:Process:Strip Silence` 📋

**Intelligent Silence Removal:**
- Analyzes sample for silence at beginning and end
- Uses user-configurable threshold (set in Paketti Preferences)
- Creates new trimmed sample
- **Preserves all sample properties** (loop points, transpose, volume, etc.)
- **Progress dialog** with cancellation support
- Yields every 10k frames for responsiveness

**Use Cases:**
- **Clean recordings** - Remove mic noise
- **Tight loops** - Remove unwanted silence
- **Sample library cleanup** - Batch processing
- **File size reduction** - Smaller samples

**Threshold:** Set in Audio Processing Tools Dialog or Paketti Preferences

---

### Strip Silence from All Samples
Available in **Audio Processing Tools Dialog**

Batch processes all samples in instrument:
- Only processes samples with >50 frames of silence
- Skips already-clean samples
- Progress shows which sample is being processed
- Smart filtering to avoid unnecessary processing

---

### Move Beginning Silence to End
**Shortcut:** `Global:Paketti:Move Beginning Silence to End` ⌨️ 🎹 📋

**MIDI:** `Paketti:Move Beginning Silence to End` 🎹

**Menu:** `Sample Editor:Paketti:Process:Move Beginning Silence to End` 📋
**Menu:** `Sample Navigator:Paketti:Process:Move Beginning Silence to End` 📋
**Menu:** `Sample Mappings:Paketti:Process:Move Beginning Silence to End` 📋

**Creative Silence Relocation:**
- Finds silence at beginning
- Moves audio to start of buffer
- Places silence at end
- **Preserves sample length** (unlike Strip Silence)

**Perfect for:**
- **Loop creation** - Audio starts immediately
- **Tight triggering** - No latency from silence
- **Keeping sample length** - When exact length matters (e.g., beat-synced)

---

### Move Beginning Silence to End for All Samples
**Shortcut:** `Global:Paketti:Move Beginning Silence to End for All Samples` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Move Beginning Silence to End for All Samples` 📋
**Menu:** `Sample Navigator:Paketti:Process:Move Beginning Silence to End for All Samples` 📋
**Menu:** `Sample Mappings:Paketti:Process:Move Beginning Silence to End for All Samples` 📋

Batch processes entire instrument:
- Only processes samples with >50 frames of initial silence
- Progress dialog with per-sample feedback
- Smart filtering for efficiency

---

## Channel Inversion

### Invert Sample
**Shortcuts:**
- `Global:Paketti:Invert Sample` ⌨️ 📋
- `Sample Editor:Paketti:Invert Sample` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Invert Sample` 📋
**Menu:** `Sample Navigator:Paketti:Process:Invert Sample` 📋
**Menu:** `Sample Mappings:Paketti:Process:Invert Sample` 📋

Inverts entire sample (flips waveform upside down). Works with mono and stereo.

---

### Invert Left Channel
**Shortcut:** `Sample Editor:Paketti:Invert Left Channel` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Invert Left Channel` 📋
**Menu:** `Sample Navigator:Paketti:Process:Invert Left Channel` 📋
**Menu:** `Sample Mappings:Paketti:Process:Invert Left Channel` 📋

Inverts only the left channel of stereo sample.

**Use Cases:**
- Phase alignment
- Side-chain preparation
- Creative stereo effects

---

### Invert Right Channel
**Shortcut:** `Sample Editor:Paketti:Invert Right Channel` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Invert Right Channel` 📋
**Menu:** `Sample Navigator:Paketti:Process:Invert Right Channel` 📋
**Menu:** `Sample Mappings:Paketti:Process:Invert Right Channel` 📋

Inverts only the right channel of stereo sample.

---

### Invert Random Samples in Instrument
**Shortcut:** `Global:Paketti:Invert Random Samples in Instrument` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Invert Random Samples in Instrument` 📋
**Menu:** `Sample Navigator:Paketti:Process:Invert Random Samples in Instrument` 📋
**Menu:** `Sample Mappings:Paketti:Process:Invert Random Samples in Instrument` 📋

**Creative Randomization:**
- 50% chance each sample will be inverted
- Perfect for drumkits
- Creates phase variation
- Adds subtle character differences

---

### Invert Right, Sum Mono
**Shortcut:** `Sample Editor:Paketti:Invert Right, Sum Mono` ⌨️

**Mid-Side Processing Helper:**
1. Inverts right channel
2. Sums L+R to mono
3. Extracts side information

**Use Cases:**
- Mid-side analysis
- Stereo width extraction
- Phase cancellation experiments

---

## DC Offset Removal

### Recursive Remove DC Offset
**Shortcut:** `Sample Editor:Process:Recursive Remove DC Offset` ⌨️

**High-Pass Filter Algorithm:**
- Removes DC offset using recursive filter
- Cutoff: -3dB @ 40Hz (configurable in code)
- Alternative cutoffs available: 30Hz, 20Hz
- Processes all channels

**Technical:** Uses `R = 1 - (250 / samplerate)` formula

---

### Recursive Remove DC Offset Random Times
**Shortcut:** `Sample Editor:Process:Recursive Remove DC Offset Random Times` ⌨️

Runs recursive DC offset **1-50 times randomly**:
- Each pass removes more low-end
- Creates increasingly thin sound
- Unpredictable results (1-50 iterations)

---

### Max Amp DC Offset Kick Generator
**Shortcut:** `Global:Paketti:Max Amp DC Offset Kick Generator` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Max Amp DC Offset Kick Generator` 📋

**Instant Kick Drum Synthesizer:**
1. Creates new instrument with Paketti template
2. Generates 16,800-frame sample at maximum amplitude
3. Runs recursive DC offset 1-50 times randomly
4. Sets transpose to -36 (C-4 = sub-bass kick)
5. Names it "Max Amp DC Offset Kick"

**Result:** Unique kick drum every time!

**Perfect for:**
- **808-style kicks** - Deep sub-bass
- **Experimental percussion** - Unpredictable character
- **Quick drums** - Instant usable kick
- **Sound design starting point**

---

## Fade In/Out

### 15 Frame Fade In & Fade Out
**Shortcut:** `Sample Editor:Paketti:15 Frame Fade In & Fade Out` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:15 Frame Fade In & Fade Out` 📋

**Anti-Click Fading:**
- Applies 15-frame fade-in at start
- Applies 15-frame fade-out at end
- Linear fade curves
- Removes clicks/pops
- Works with all sample types

**Frame Count:** 15 frames = ~0.34ms @ 44.1kHz

**Use Cases:**
- **Remove clicks** - Clean sample start/end
- **Loop preparation** - Smooth loop points
- **Sample cleanup** - Professional polish

---

## Phase Manipulation

### Phase Inversion
**Shortcut:** `Sample Editor:Paketti:Phase Inversion` ⌨️

**Duplicate + Invert Mix:**
1. Duplicates sample
2. Inverts original
3. Keeps both samples

**Use Cases:**
- Phase cancellation experiments
- Creating "negative" of sound
- Preparing for audio diff

---

### Phase Inversion & Audio Diff
**Shortcut:** `Sample Editor:Paketti:Phase Inversion & Audio Diff` ⌨️

Combined operation:
1. Phase inverts sample
2. Creates audio diff with duplicate
3. Results in phase-cancelled difference signal

---

## Audio Diff

### Audio Diff
**Shortcut:** `Sample Editor:Paketti:Audio Diff` ⌨️

**Difference Signal Extraction:**
1. Duplicates sample
2. Subtracts duplicate from original
3. Normalizes result to prevent clipping

**Mathematical:** `output = sample - duplicate`

**Use Cases:**
- **Isolate changes** - Hear only what changed after processing
- **Compare versions** - Find differences between takes
- **Extract artifacts** - Hear only the processing artifacts
- **Sound design** - Create complementary signals

---

## Creative Effects

### Pitch Shift
**Shortcut:** `Sample Editor:Paketti:Pitch Shift` ⌨️

Shifts sample by 20 frames:
- Simple frame-offset pitch shift
- Creates chorus-like artifacts
- No interpolation (aliasing may occur)

---

### Pitch Shift & Audio Diff
**Shortcut:** `Sample Editor:Paketti:Pitch Shift & Audio Diff` ⌨️

Combines pitch shift with audio diff for creative effects.

---

### Clip Bottom of Waveform
**Shortcut:** `Sample Editor:Paketti:Clip bottom of waveform` ⌨️

Modulation effect that clips/shapes the waveform:
- Creates harmonic distortion
- Asymmetric waveform shaping
- Unique tonal character

---

### Modulate & Audio Diff
**Shortcut:** `Sample Editor:Paketti:Modulate & Audio Diff` ⌨️

Combines modulation with audio diff.

---

### ProTracker MOD Modulation
**Shortcut:** `Sample Editor:Paketti:Protracker MOD Modulation...` ⌨️

**Classic Amiga ProTracker Effect:**
- Opens dialog with Mod Speed slider (-128 to +127)
- Applies time-varying modulation using ProTracker's 64-value modulation table
- Creates vibrato/chorus-like effects
- **Speed 0** = no effect (must be non-zero)
- Press Enter in dialog to process

**Historical:** Authentic ProTracker algorithm from Amiga era!

**Use Cases:**
- **Retro effects** - Authentic Amiga sound
- **Vibrato** - Speed controls depth/rate
- **Chorus** - Subtle modulation (low speeds)
- **Weird textures** - High speeds create artifacts

---

## Audio Processing Tools Dialog

**Shortcut:** `Global:Paketti:Paketti Audio Processing Tools Dialog...` ⌨️ 📋

**Menu:** `Main Menu:Tools:Paketti:Xperimental/WIP:Audio Processing Tools...` 📋

**Comprehensive Audio Processing Interface** with:

### Silence Threshold Controls
- **Strip Silence Threshold** - Adjustable slider (0.0-1.0)
- **Move Silence Threshold** - Separate threshold for move operation
- Visual percentage display

### Buttons Available:
1. **Strip Silence using Threshold** - Processes selected sample
2. **Move Beginning Silence to End** - Relocates silence
3. **Strip Silence from All Samples** - Batch process instrument

### DC Offset Controls
- **Recursive DC Offset** - Single pass
- **Run DC Offset x times** - Slider for 1-500 iterations
- **Run DC Offset 1-50 times (randomized)** - Random iterations
- **Max Amp DC Offset Kick Generator** - Create kick drum

### Channel Operations
- **Invert Left Channel**
- **Invert Right Channel**
- **Invert Sample** (both channels)

### Conversion
- **Mono→Stereo** - Duplicate to both channels
- **Mono→Stereo (Blank L)** - Right only + blank left
- **Mono→Stereo (Blank R)** - Left only + blank right

### Normalization
- **Normalize Sample** - Quick normalize button

### Phase & Creative
- **Phase Inversion** - Invert and subtract
- **Phase Inversion & Audio Diff** - Combined
- **Invert Right, Sum Mono** - Mid-side extraction
- **Pitch Shift** - Frame-offset pitch shift (with valuebox)
- **Pitch Shift & Audio Diff** - Combined
- **Clip bottom of waveform** - Modulation distortion
- **Modulate & Audio Diff** - Combined
- **Audio Diff** - Difference extraction

### Resampling Section
- **Sample Rate Slider** - 225 Hz to 192 kHz
- **Halve Sample Rate** button
- **Double Sample Rate** button
- **Resample to 44.1 kHz** button
- **Bit Depth Switch** - 8/16/24/32 bit
- **Process** button - Applies conversion

**Sample Info Display:**
- Shows current sample name
- Shows Hz/bit depth/frame count
- Updates automatically on sample change

**This dialog stays open** - Process multiple samples without reopening!

---

## Diagonal Line to Sample

**Shortcut:** `Global:Paketti:Diagonal Line to 16800 length Sample` ⌨️

**Waveform Generator:**
- Creates new instrument
- Generates 16,800-frame sample
- Diagonal line waveform (1.0 to -1.0)
- 44.1kHz, 16-bit, mono

**Use Cases:**
- **Sound design starting point**
- **Test signals**
- **Modulation sources** (via sampling)
- **Wavetable creation**


# Pattern Editor Features

This section covers Pattern Editor features including time signatures, keyboard velocity, BPM control, and pattern organization.

---

## Table of Contents
1. [Time Signatures](#time-signatures)
2. [Keyboard & Velocity Control](#keyboard--velocity-control)
3. [BPM Control](#bpm-control)
4. [Pattern Organization](#pattern-organization)
5. [Pattern Resizing](#pattern-resizing)
6. [Pattern Transformation](#pattern-transformation)
7. [Column Operations](#column-operations)
8. [Interpolation](#interpolation)
9. [Humanization](#humanization)
10. [Automation Operations](#automation-operations)
11. [Effect Column Operations](#effect-column-operations)
12. [Note Operations](#note-operations)
13. [Navigation & Playback](#navigation--playback)
14. [Track & Group Management](#track--group-management)
15. [Sample Controls](#sample-controls)

---

## Time Signatures

Paketti provides quick shortcuts for setting up common time signatures with appropriate pattern lengths and LPB settings.

### Set Time Signature 3/4 and 48 rows @ LPB 4
**Shortcut:** `Pattern Editor:Paketti:Set Time Signature 3/4 and 48 rows @ LPB 4`

Configures the current pattern for 3/4 time signature:
- **TPL (Ticks Per Line):** 3
- **LPB (Lines Per Beat):** 4
- **Metronome LPB:** 4
- **Metronome Beats Per Bar:** 3
- **Pattern Length:** 48 rows

*Perfect for waltzes and other 3/4 time music.*

---

### Set Time Signature 7/8 and 56 rows @ LPB 8
**Shortcut:** `Pattern Editor:Paketti:Set Time Signature 7/8 and 56 rows @ LPB 8`

Configures the current pattern for 7/8 time signature:
- **TPL:** 7
- **LPB:** 8
- **Metronome LPB:** 8
- **Metronome Beats Per Bar:** 7
- **Pattern Length:** 56 rows

*Useful for progressive rock, jazz, and experimental music.*

---

### Set Time Signature 6/8 and 48 rows @ LPB 8
**Shortcut:** `Pattern Editor:Paketti:Set Time Signature 6/8 and 48 rows @ LPB 8`

Configures the current pattern for 6/8 time signature:
- **TPL:** 6
- **LPB:** 8
- **Metronome LPB:** 8
- **Metronome Beats Per Bar:** 6
- **Pattern Length:** 48 rows

*Common in folk music and compound time signatures.*

---

## Keyboard & Velocity Control

### Computer Keyboard Velocity Adjustment
**Shortcuts:**
- `Global:Paketti:Computer Keyboard Velocity (-16)` - Decrease by 16
- `Global:Paketti:Computer Keyboard Velocity (+16)` - Increase by 16

Quickly adjust the velocity/volume of notes entered via computer keyboard. Range adjustments help you create dynamics without reaching for sliders.

---

## BPM Control

### BPM Adjustment (±5)
**Shortcuts:**
- `Global:Paketti:BPM Decrease (-5)` - Decrease by 5 BPM
- `Global:Paketti:BPM Increase (+5)` - Increase by 5 BPM

Rapid BPM changes in larger increments than the default ±1. Useful for finding the right tempo range quickly.

---

## Pattern Organization

### Selection in Pattern to Group
**Shortcut:** `Pattern Editor:Paketti:Selection in Pattern to Group`

Creates a group track from your current pattern selection. All selected tracks are moved into a new group track, which is inserted after the selection.

**How it works:**
1. Select multiple tracks in the pattern editor (click and drag across track headers, or use pattern selection)
2. Trigger the shortcut
3. A new group is created at the end of your selection
4. All selected tracks are moved into this group
5. Master and Send tracks are automatically excluded

*Useful for organizing your project by grouping related tracks (drums, bass, synths, etc.).*

---

## Sample Exit Loop

### Selected Sample Exit Loop Note-Off
**Shortcuts:**
- `Global:Paketti:Selected Sample Exit Loop Note-Off Toggle` - Toggle on/off
- `Global:Paketti:Selected Sample Exit Loop Note-Off Off` - Force off
- `Global:Paketti:Selected Sample Exit Loop Note-Off On` - Force on

Controls whether the sample continues playing its loop after a note-off is received, or if it exits the loop and plays to the end of the sample.

**Use cases:**
- **Loop Release ON:** For sustained notes (pads, strings) where you want the natural tail to play after releasing the key
- **Loop Release OFF:** For percussive sounds where you want the loop to continue until explicitly stopped

---

## Additional Sample Controls

### Sample Autofade
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Autofade On` - Enable autofade
- `Global:Paketti:Set Selected Sample Autofade Off` - Disable autofade

Quick shortcuts to enable/disable autofade without navigating through sample properties.

---

### Fine Sample Control (±5 increments)
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Finetune (-5)` / `(+5)` - Larger finetune adjustments
- `Global:Paketti:Set Selected Sample Volume (-0.05)` / `(+0.05)` - 5% volume steps
- `Global:Paketti:Set Selected Sample Panning (-0.05)` / `(+0.05)` - 5% panning steps
- `Global:Paketti:Set Selected Sample Transpose (-5)` / `(+5)` - Quick 5-semitone jumps

Alternative increment sizes for faster sample parameter adjustments. Complements the standard ±1/±0.01 controls.

---

## Sample Modulation & FX Assignment

### Assign Modulation Set to Selected Sample
**Function:** `selectedSampleMod(number)`

Assigns a specific modulation set (0-N) to the currently selected sample. If you have multiple modulation sets configured in your instrument, this allows quick switching between them.

**Values:**
- **0:** No modulation set
- **1-N:** Modulation set index (depends on how many you've created)

*Note: Shortcuts for these can be added via Paketti's customization system.*

---

### Assign FX Chain to Selected Sample
**Function:** `selectedSampleFX(number)`

Assigns a specific Sample FX Chain (0-N) to the currently selected sample. Useful for having different FX chains for different samples within the same instrument.

**Values:**
- **0:** No FX chain
- **1-N:** FX chain index (depends on how many you've created)

*Note: Shortcuts for these can be added via Paketti's customization system.*

---

### Assign Modulation Set to All Samples
**Function:** `selectedInstrumentAllMod(number)`

Applies the same modulation set index to ALL samples in the currently selected instrument. Useful for bulk configuration.

---

### Assign FX Chain to All Samples
**Function:** `selectedInstrumentAllFX(number)`

Applies the same FX chain index to ALL samples in the currently selected instrument. Useful for bulk configuration.

---

## Pattern Resizing

### Resize All Non-Empty Patterns
**Shortcuts:**
- `Global:Paketti:Resize all non-empty Patterns to current Pattern length` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 012` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 016` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 024` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 032` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 048` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 064` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 096` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 128` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 192` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 256` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 384` ⌨️ 📋
- `Global:Paketti:Resize all non-empty Patterns to 512` ⌨️ 📋

**Menu:** `Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns` (all sizes available) 📋
**Menu:** `Pattern Sequencer:Paketti:Resize all non-empty Patterns` (all sizes available) 📋

**Batch Pattern Length Adjustment:**
- Resizes ALL non-empty patterns in song to specified length
- **Skips empty patterns** (preserves empty slots)
- Useful for standardizing pattern lengths across project
- **Current pattern length** option matches all to currently selected pattern

**Use Cases:**
- **Song arrangement** - Make all verses/choruses same length
- **Grid alignment** - Standardize to 64/128 for easier arrangement
- **Genre conventions** - 64 rows for techno, 128 for breaks

---

### Pattern Resize and Fill
**Shortcuts:**
- `Global:Paketti:Pattern Resize and Fill 032` ⌨️ 📋
- `Global:Paketti:Pattern Resize and Fill 064` ⌨️ 📋
- `Global:Paketti:Pattern Resize and Fill 128` ⌨️ 📋
- `Global:Paketti:Pattern Resize and Fill 256` ⌨️ 📋
- `Global:Paketti:Pattern Resize and Fill 512` ⌨️ 📋

**Menu:** `Pattern Editor:Paketti:Pattern:Resize&Fill` (submenu) 📋
**Menu:** `Main Menu:Tools:Paketti:Pattern Editor:Resize&Fill` (submenu) 📋

**Intelligent Duplication:**
1. Resizes pattern to target length
2. **Loops/repeats existing content** to fill new space
3. Perfect for extending loops without copy/paste

**Example:** 16-row drum loop → Fill 128 = 8 repetitions

---

## Pattern Transformation

### Rotate Track Content
**Shortcut:** `Pattern Editor:Paketti:Rotate Track Content to SelectionStart First` ⌨️

**Circular Rotation:**
- Takes pattern content from `selection start` to `pattern end`
- Moves it to beginning of pattern
- Rest of content wraps around to end

**Use Case:** Adjust loop start point without rewriting pattern

---

### Reverse Notes in Selection
**Shortcut:** `Pattern Editor:Paketti:Reverse Notes in Selection` ⌨️ 📋

**Menu:** `Pattern Editor:Paketti:Note Columns:Reverse Notes in Selection` 📋
**Menu:** `Main Menu:Tools:Paketti:Pattern Editor:Reverse Notes in Selection` 📋

Reverses the order of all notes within selected area:
- Note pitches play backwards
- Timing preserved
- Columns/effects also reversed

**Use Cases:**
- **Retrograde melodies** - Classical composition technique
- **Reverse fills** - Backwards drum fills
- **Experimental** - Create mirror versions

---

### Interpolate Notes
**Shortcut:** `Pattern Editor:Paketti:Interpolate Notes` ⌨️

**Menu:** `Pattern Editor:Paketti:Note Columns:Interpolate Notes` 📋

**Smart Note Filling:**
- Finds first and last note in selection
- Fills intermediate rows with interpolated pitches
- Creates smooth pitch glides/arpeggios

**Example:**
```
Row 00: C-4
Row 16: (empty rows)
Row 32: C-5
```
Result: Chromatic scale from C-4 to C-5

---

### Flood Fill with Selection
**Shortcut:** `Pattern Editor:Paketti:Flood Fill with Selection` ⌨️

*(No direct menu entry - use "Flood Fill Note and Instrument" instead)*

**Loop Duplicator:**
1. Takes your selection
2. Repeats it until end of pattern
3. No gaps, continuous repetition

**Perfect for:**
- **Bass lines** - Repeat 4-bar loop
- **Percussion patterns** - Extend hi-hat pattern
- **Any loop** - Instant pattern filler

---

### Flood Fill from Current Row w/ AutoArp
**Shortcut:** `Pattern Editor:Paketti:Flood Fill from Current Row w/ AutoArp` ⌨️ 📋

**Menu:** `Pattern Editor:Paketti:Pattern:Flood Fill from Current Row w/ AutoArp` 📋

Advanced flood fill with auto-arpeggio insertion.

---

## Column Operations

### Delete/Clear/Wipe Operations
**Shortcuts:**
- `Pattern Editor:Paketti:Delete/Clear/Wipe Entire Row` ⌨️ - Clears all columns in current row
- `Pattern Editor:Paketti:Delete/Clear/Wipe Entire Row with EditStep` ⌨️ - Clear + advance by EditStep
- `Pattern Editor:Paketti:Delete/Clear/Wipe Selected Note Column` ⌨️ - Clear just the note column
- `Global:Paketti:Wipe All Columns of Selected Track` ⌨️ - Clear entire track in pattern

---

### Wipe Selection Columns
**Shortcuts (auto-generated for each column type):**
- `Pattern Editor:Paketti:Wipe Selection Volume Column` ⌨️
- `Pattern Editor:Paketti:Wipe Selection Panning Column` ⌨️
- `Pattern Editor:Paketti:Wipe Selection Delay Column` ⌨️
- `Pattern Editor:Paketti:Wipe Selection Sample FX Column` ⌨️

Sets selected column values to 0/empty.

---

### Adjust Selection Columns
**Format:** `Pattern Editor:Paketti:Adjust Selection [Column] Column (±X)` ⌨️

Available for **Volume, Panning, Delay, Sample FX** with multiple increment sizes.

**Example shortcuts:**
- `Adjust Selection Volume Column (+1)` - Increase by 1
- `Adjust Selection Volume Column (-10)` - Decrease by 10
- `Adjust Selection Panning Column (+16)` - Pan right
- `Adjust Selection Delay Column (-5)` - Earlier timing

---

### Squeeze Note Columns (Pattern)
**Shortcut:** `Global:Paketti:Squeeze Note Columns (Pattern)` ⌨️ 🎹

**MIDI:** `Paketti:Squeeze Note Columns (Pattern)` 🎹

**Smart Column Minimization:**
- Removes empty note columns
- Keeps only columns with content
- Makes pattern easier to read
- Reduces horizontal scrolling

---

### Invert Subcolumns
**Shortcuts:**
- `Pattern Editor:Paketti:Invert Note Column Subcolumns` ⌨️
- `Pattern Editor:Paketti:Invert Effect Column Subcolumns` ⌨️
- `Pattern Editor:Paketti:Invert All Subcolumns` ⌨️

Inverts the order of subcolumn values (mathematical inversion).

---

## Interpolation

### Interpolate Column Values
**Shortcuts:**
- `Pattern Editor:Paketti:Interpolate Column Values (Volume)` ⌨️ 📋
- `Pattern Editor:Paketti:Interpolate Column Values (Delay)` ⌨️ 📋
- `Pattern Editor:Paketti:Interpolate Column Values (Panning)` ⌨️ 📋
- `Pattern Editor:Paketti:Interpolate Column Values (Sample FX)` ⌨️ 📋

**Menu:** `Pattern Editor:Paketti:Pattern:Interpolate Column Values` (all 4 available) 📋

**Smooth Value Transitions:**
1. Enter start value at beginning of selection
2. Enter end value at end of selection
3. Run interpolation
4. All intermediate rows filled with smooth transition

**Perfect for:**
- **Volume fades** - 80 → 00 over 16 rows
- **Panning sweeps** - L40 → R40 sweep
- **Delay timing** - Create delay ramps
- **Filter sweeps** - Using Sample FX column

---

## Humanization

### Humanize Dialog
**Shortcut:** `Pattern Editor:Paketti:Humanize Selection...` ⌨️

Opens comprehensive humanization dialog with:
- **Timing variation** (delay column)
- **Velocity variation** (volume column)
- **Pitch variation** (note pitches)
- Adjustable ranges for each

---

### Quick Humanize Presets
**Shortcuts:**
- `Pattern Editor:Paketti:Quick Humanize 5` ⌨️ - Subtle (±5 timing, ±3 velocity)
- `Pattern Editor:Paketti:Quick Humanize 10` ⌨️ - Medium (±10 timing, ±5 velocity)
- `Pattern Editor:Paketti:Quick Humanize 20` ⌨️ - Heavy (±20 timing, ±8 velocity)
- `Pattern Editor:Paketti:Quick Humanize Random` ⌨️ - Randomized amounts

**Perfect for:**
- **Drum programming** - Make drums feel live
- **MIDI input** - Add realism to quantized notes
- **Mechanical parts** - Break the grid
- **Organic feel** - Make sequences less robotic

---

## Automation Operations

### Wipe Automation (Multiple Scopes)
**Shortcuts:**
- `Pattern Editor:Paketti:Wipe All Automation in Track on Current Pattern` ⌨️
- `Pattern Editor:Paketti:Wipe All Automation in All Tracks on Current Pattern` ⌨️
- `Pattern Editor:Paketti:Wipe All Automation in Track on Whole Song` ⌨️
- `Pattern Editor:Paketti:Wipe All Automation in All Tracks on Whole Song` ⌨️

**4 Scope Levels:**
1. **Track + Pattern** - Current track, current pattern only
2. **All Tracks + Pattern** - All tracks, current pattern only
3. **Track + Song** - Current track, entire song
4. **All Tracks + Song** - Every track, entire song (nuclear option!)

**Use Cases:**
- **Start fresh** - Remove all automation to start over
- **Clean mistakes** - Delete automation from problematic section
- **Track isolation** - Remove automation from specific track
- **Global reset** - Clear all automation across entire project

---

## Effect Column Operations

### Wipe Effect Columns (Multiple Scopes)
**Shortcuts:**
- `Pattern Editor:Paketti:Wipe All Effect Columns on Selected Track on Current Pattern` ⌨️ 📋
- `Pattern Editor:Paketti:Wipe All Effect Columns on Selected Track on Song` ⌨️ 📋
- `Pattern Editor:Paketti:Wipe All Effect Columns on Selected Pattern` ⌨️ 📋
- `Pattern Editor:Paketti:Wipe All Effect Columns on Song` ⌨️ 📋

**Menu:** `Pattern Editor:Paketti:Effect Columns:Wipe All Effect Columns` (submenu) 📋

**4 Scope Levels:**
1. **Track + Pattern** - Current track, current pattern
2. **Track + Song** - Current track, all patterns
3. **All Tracks + Pattern** - All tracks, current pattern
4. **All Tracks + Song** - Everything (nuclear!)

**Perfect for:**
- **Remove delay column** - Clean up timing commands
- **Remove glide commands** - Clear pitch effects
- **Clean project** - Remove unwanted effects
- **Start arrangement** - Clear effects before mastering

---

## Note Operations

### Insert Random Note-Offs
**Shortcut:** `Pattern Editor:Paketti:Insert Random Note-Offs in Empty Rows` ⌨️

**Creative Note Cutting:**
- Finds empty rows in selection
- Randomly inserts `OFF` notes
- Creates stutter/gating effects
- Controlled chaos

---

### Randomize Note-Off Positions
**Shortcut:** `Pattern Editor:Paketti:Randomize Positions of Note-Offs` ⌨️

**Shuffle Existing Note-Offs:**
- Takes all `OFF` notes in selection
- Moves them to random positions within selection
- Preserves note-off count
- Changes timing only

**Use Cases:**
- **Gating effects** - Randomize gate timing
- **Stutter variations** - Create unpredictable cuts
- **Experimental** - Break up sustained notes

---

### Fix C0 Panning Values
**Shortcut:** `Pattern Editor:Paketti:Fix C0 Panning Values` ⌨️

**C0 Bug Workaround:**
- Renoise has a quirk with C0 panning values
- This shortcut fixes/normalizes them
- Run if panning behaves strangely

---

### Step by EditStep
**Shortcuts:**
- `Pattern Editor:Paketti:Step by EditStep (Forwards)` ⌨️
- `Pattern Editor:Paketti:Step by EditStep (Backwards)` ⌨️

Move cursor by EditStep amount (like pressing Enter, but backwards too).

---

## Navigation & Playback

### Play at Random Line
**Shortcuts:**
- `Global:Paketti:Play at Random Line in Current Pattern` ⌨️ - Any line
- `Global:Paketti:Play at Random Line in Current Pattern 2` ⌨️ - Even lines (0, 2, 4...)
- `Global:Paketti:Play at Random Line in Current Pattern 4` ⌨️ - Every 4th line
- `Global:Paketti:Play at Random Line in Current Pattern LPB` ⌨️ - Every LPB line

**Random Pattern Preview:**
- Jumps to random position in current pattern
- Starts playback from there
- Great for auditioning different sections

**Use Cases:**
- **Quick preview** - Hear random parts of long pattern
- **Inspiration** - Discover unexpected combinations
- **Testing** - Check different sections rapidly

---

### Jump Forward/Backward by Random
**Shortcuts:**
- `Global:Paketti:Jump Forward Within Pattern by Random` ⌨️
- `Global:Paketti:Jump Backward Within Pattern by Random` ⌨️

Random cursor jumping within current pattern (without playing).

---

## Track & Group Management

### Selection to Group
**Shortcuts:**
- `Pattern Editor:Paketti:Selection in Pattern to Group` ⌨️
- `Pattern Matrix:Paketti:Selection in Pattern Matrix to Group` ⌨️ 📋

**Menu:** `Pattern Matrix:Paketti:Selection in Pattern Matrix to Group` 📋

**Smart Track Grouping:**
- Works from Pattern Editor selection OR Pattern Matrix selection
- Creates new group
- Adds all selected tracks to group
- Skips Master/Send tracks automatically

**Perfect for:**
- **Organizing mix** - Group drums, synths, vocals
- **Bus processing** - Group tracks for collective FX
- **Mixing workflow** - Organize by instrument type

---

### Navigate Groups
**Shortcuts:**
- `Pattern Editor:Paketti:Jump to First Track In Next Group` ⌨️
- `Pattern Editor:Paketti:Jump to First Track In Previous Group` ⌨️

**Fast Group Navigation:**
- Jumps to first track in next/previous group
- Skips over all tracks in between
- Great for large projects with many groups

---

### Populate Send Tracks
**Shortcut:** `Global:Paketti:Populate Send Tracks for All Selected Tracks` ⌨️

**Automatic Send Routing:**
- Creates send tracks for selected tracks
- Sets up routing automatically
- Saves manual send setup time

---

## Sample Controls

(See [Sample Exit Loop](#sample-exit-loop) section above)

---

## Tips & Workflow

### Time Signature Workflows
- Use time signature shortcuts when starting new projects or sections
- Combine with pattern length shortcuts for quick setup
- The pattern lengths are designed to work well with the specified LPB settings

### BPM & Velocity Control
- Use ±16 velocity for dramatic dynamic changes
- Use ±5 BPM for rapid tempo exploration
- Combine with MIDI controllers for live performance tempo rides

### Pattern Organization
- Group tracks by instrument type (drums, bass, leads, pads)
- Group tracks by processing chains (everything going through the same send)
- Group stems for easier mixdown management


# Pattern Sequencer & Section Management

This section covers all Paketti features related to Pattern Sequencer, Sequence Selection, Section management, and playback control.

---

## Table of Contents
1. [Sequence Selection](#sequence-selection)
2. [Sequence Looping](#sequence-looping)
3. [Section Selection & Management](#section-selection--management)
4. [Scheduled Sequences](#scheduled-sequences)
5. [Section Loop Control](#section-loop-control)
6. [Pattern Navigation within Sections](#pattern-navigation-within-sections)
7. [Performance Lock Features](#performance-lock-features)

---

## Sequence Selection

### Toggle Sequence Selection (Individual)
**Shortcuts:** (00-32 available)
- `Global:Paketti:Toggle Sequence Selection 00` through `32`

Toggles selection for a specific sequence position. If the sequence is already selected, it will be deselected. If not selected, it will be selected.

---

### Toggle Current Sequence Selection On/Off
**Shortcut:** `Global:Paketti:Toggle Current Sequence Selection On/Off`

Toggles the selection state of the currently selected sequence. Pressing once selects it, pressing again deselects it.

---

### Toggle Sequence Selection (All) On/Off
**Shortcut:** `Global:Paketti:Toggle Sequence Selection (All) On/Off`

Selects all sequences in the song from position 1 to the end. *Note: Currently always selects all, does not toggle off.*

---

### Set Sequence Selection Off
**Shortcut:** `Global:Paketti:Set Sequence Selection Off`

Clears any active sequence selection.

---

### Sequence Selection (Next/Previous)
**Shortcuts:**
- `Global:Paketti:Sequence Selection (Next)` - Expand selection by 1 sequence forward
- `Global:Paketti:Sequence Selection (Previous)` - Expand selection by 1 sequence backward

**MIDI Mappings:**
- `Paketti:Sequence Selection (Next)`
- `Paketti:Sequence Selection (Previous)`

Step-by-step sequence selection expansion. If no selection exists, selects the current sequence. Then expands the selection range one sequence at a time.

---

### Sequence Selection to Loop
**Shortcut:** `Global:Paketti:Toggle Sequence Selection to Loop` ⌨️ 📋

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Toggle Sequence Selection to Loop` 📋

Converts the current sequence selection into a loop range. If the loop already matches the selection, it toggles the loop off.

---

## Sequence Looping

### Toggle Sequence Loop (Individual Positions)
**Shortcuts:** (01-32 available)
- `Global:Paketti:Toggle Sequence Loop to 00` through `31`

Sets or toggles a loop to a specific sequence position. If the loop is already set to that position, it turns the loop off.

---

### Clear Pattern Sequence Loop
**Shortcut:** `Global:Paketti:Clear Pattern Sequence Loop`

Removes any active sequence loop, allowing playback to continue through the entire song.

---

### Set Sequence Loop from Current to Position
**Shortcuts:** (01-32 available)
- `Global:Paketti:Set Sequence Loop from Current to 00` through `31`

Creates a loop range from the current loop position (or creates a new one) to the specified position. If the new position is before the current start, it becomes the new start.

---

### Sequence Loop Selection (Next/Previous)
**Shortcuts:**
- `Global:Paketti:Sequence Loop Selection (Next)` ⌨️ 📋 - Extend loop by 1 sequence forward
- `Global:Paketti:Sequence Loop Selection (Previous)` ⌨️ 📋 - Extend loop by 1 sequence backward

**MIDI Mappings:**
- `Paketti:Sequence Loop Selection (Next)` 🎹
- `Paketti:Sequence Loop Selection (Previous)` 🎹

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Sequence Loop Selection (Next)` 📋
**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Sequence Loop Selection (Previous)` 📋

Incrementally expand the loop range by adding one more sequence in either direction. If no loop exists, starts with the current sequence.

---

### Pattern Name Loop (NEW - Dec 2025)

**Keybinding:** `Global:Paketti:Pattern Name Loop` ⌨️

**Menu:** `Pattern Sequencer:Paketti:Pattern Name Loop` 📋

Uses pattern naming convention to define loop ranges with `[` and `]` markers.

**Naming Convention:**
- `[` in pattern name = Loop start marker
- `]` in pattern name = Loop end marker
- `[]` in single pattern = Loop that single pattern

**How It Works:**
1. Name patterns with bracket markers
2. Trigger Pattern Name Loop
3. Paketti finds patterns with markers
4. Sets loop range accordingly

**Examples:**

**Single Pattern Loop:**
```
Pattern 05: "[Verse]"
Result: Loops pattern 05 only
```

**Multi-Pattern Loop:**
```
Pattern 03: "[Intro"
Pattern 04: "Intro cont"
Pattern 05: "Intro end]"
Result: Loops patterns 03-05
```

**Nested Sections:**
```
Pattern 01: "[Verse A"
Pattern 02: "Verse A]"
Pattern 03: "[Chorus"
Pattern 04: "Chorus]"
```
- Trigger on pattern 01 or 02 = Loops 01-02
- Trigger on pattern 03 or 04 = Loops 03-04

**Use Cases:**
- Quick section looping without manual selection
- Visual indication of song structure
- Performance-friendly navigation
- Works with existing pattern naming

---

## Section Selection & Management

### Select and Loop Section (Next/Previous)
**Shortcuts:**
- `Global:Paketti:Select and Loop Section (Next)` - Jump to and loop next section
- `Global:Paketti:Select and Loop Section (Previous)` - Jump to and loop previous section

Navigates between sections in your song and automatically creates a loop for the entire section. Useful for quickly jumping between song parts during arrangement.

---

### Set Sequence Loop Selection Off
**Shortcut:** `Global:Paketti:Set Sequence Loop Selection Off` ⌨️ 📋

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Set Sequence Loop Selection Off` 📋

Disables the sequence loop, setting the loop range to {0, 0}.

---

### Section Loop (Next/Previous)
**Shortcuts:**
- `Global:Paketti:Section Loop (Next)` ⌨️ 📋 - Expand section loop to include next section
- `Global:Paketti:Section Loop (Previous)` ⌨️ 📋 - Expand section loop to include previous section

**MIDI Mappings:**
- `Paketti:Section Loop (Next)` 🎹
- `Paketti:Section Loop (Previous)` 🎹

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Section Loop (Next)` 📋
**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Section Loop (Previous)` 📋

If no loop exists, creates a loop for the current section. If a loop exists, extends it to include the next/previous section. Great for building up section combinations during live performance.

---

### Select, Trigger and Loop Section by Name (00-64)
**Shortcuts:** (00-64 available)
- `Global:Paketti:Select, Trigger and Loop Section 00` through `64`

**MIDI Mappings:**
- `Paketti:Select&Trigger&Loop Section 00` through `64` [Trigger]

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Select, Trigger and Loop:Select, Trigger and Loop Section 00-64`

Finds the next occurrence of a section starting with the specified number (e.g., "01.Intro", "01-Intro", "01,Intro") and immediately triggers it with looping enabled. Cycles through multiple occurrences of the same section number.

---

### Select, Schedule and Loop Section by Name (00-64)
**Shortcuts:** (00-64 available)
- `Global:Paketti:Select, Schedule and Loop Section 00` through `64`

**MIDI Mappings:**
- `Paketti:Select&Schedule&Loop Section 00` through `64` [Trigger]

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Select, Schedule and Loop:Select, Schedule and Loop Section 00-64`

Same as above, but schedules the section to play at the next pattern boundary instead of immediately triggering it. Useful for seamless transitions.

---

### Select, Add to Schedule and Loop Section by Name (00-64)
**Shortcuts:** (00-64 available)
- `Global:Paketti:Select, Add to Schedule and Loop Section 00` through `64`

**MIDI Mappings:**
- `Paketti:Select&Add to Schedule&Loop Section 00` through `64` [Trigger]

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Select, Add to Schedule and Loop:Select, Add to Schedule and Loop Section 00-64`

Adds the specified section to the schedule queue rather than replacing it. Allows building a playlist of sections to play in sequence.

---

### Select, Trigger and Loop Section by Position (01-32)
**Shortcuts:** (01-32 available)
- `Global:Paketti:Select&Trigger&Loop Section by Position 01` through `32`

**MIDI Mappings:**
- `Paketti:Select&Trigger&Loop Section by Position 01` through `32` [Trigger]

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Select, Trigger and Loop by Position:Select, Trigger and Loop Section by Position 01-32`

Selects sections by their position (1st section, 2nd section, etc.) regardless of their names, and immediately triggers with looping.

---

### Select, Schedule and Loop Section by Position (01-32)
**Shortcuts:** (01-32 available)
- `Global:Paketti:Select&Schedule&Loop Section by Position 01` through `32`

**MIDI Mappings:**
- `Paketti:Select&Schedule&Loop Section by Position 01` through `32` [Trigger]

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Select, Schedule and Loop by Position:Select, Schedule and Loop Section by Position 01-32`

Same as above but schedules the section by position instead of triggering immediately.

---

### Select, Add to Schedule and Loop Section by Position (01-32)
**Shortcuts:** (01-32 available)
- `Global:Paketti:Select&Add to Schedule&Loop Section by Position 01` through `32`

**MIDI Mappings:**
- `Paketti:Select&Add to Schedule&Loop Section by Position 01` through `32` [Trigger]

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Select, Add to Schedule and Loop by Position:Select, Add to Schedule and Loop Section by Position 01-32`

Adds the section by position to the schedule queue.

---

## Scheduled Sequences

### Set Sequence as Scheduled List (00-31)
**Shortcuts:** (00-31 available)
- `Global:Paketti:Set Sequence 00 as Scheduled List` through `31`

**Menu Entries:**
- `Pattern Sequencer:Paketti:Sequences/Sections:Set Sequence as Scheduled List:Set Sequence 00-31 as Scheduled List`

Sets a specific sequence to play next, replacing any existing schedule. Starts playback if not already playing.

---

### Set Current Sequence as Scheduled List
**Shortcut:** `Global:Paketti:Set Current Sequence as Scheduled List` ⌨️ 📋

**MIDI:** `Paketti:Set Current Sequence as Scheduled List` 🎹

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Set Current Sequence as Scheduled List` 📋

Schedules the currently selected sequence to play next.

---

### Add Sequence to Scheduled List (00-31)
**Shortcuts:** (00-31 available)
- `Global:Paketti:Add Sequence 00 to Scheduled List` through `31`

Adds a sequence to the scheduled playback queue without replacing existing scheduled sequences.

---

### Set Current Section as Scheduled Sequence
**Shortcut:** `Global:Paketti:Set Current Section as Scheduled Sequence` ⌨️ 📋

**MIDI Mapping:** `Paketti:Set Current Section as Scheduled Sequence` 🎹

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Set Current Section as Scheduled Sequence` 📋

Schedules all patterns in the current section to play next, replacing any existing schedule.

---

### Add Current Section to Scheduled Sequences
**Shortcut:** `Global:Paketti:Add Current Section to Scheduled Sequences` ⌨️ 📋

**MIDI Mapping:** `Paketti:Add Current Section to Scheduled Sequences` 🎹

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Add Current Section to Scheduled Sequences` 📋

Adds all patterns in the current section to the scheduled playback queue.

---

### Set Section Loop and Schedule Section
**Shortcut:** `Global:Paketti:Set Section Loop and Schedule Section` ⌨️ 📋

**MIDI Mapping:** `Paketti:Set Section Loop and Schedule Section [Knob]` 🎹

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Set Section Loop and Schedule Section` 📋

Creates a loop for the current section and schedules it to play from the first sequence of that section.

---

### Set Current Sequence as Scheduled and Loop
**Shortcut:** `Global:Paketti:Set Current Sequence as Scheduled and Loop` ⌨️ 📋

**Menu:** `Pattern Sequencer:Paketti:Sequences/Sections:Set Current Sequence as Scheduled and Loop` 📋

Combines scheduling and looping: sets the current sequence as the scheduled sequence and creates a single-sequence loop.

---

## Section Loop Control

### Jump to Section (Next/Previous)
**Shortcuts:**
- `Global:Paketti:Jump to Section (Next)` - Navigate to next section
- `Global:Paketti:Jump to Section (Previous)` - Navigate to previous section

**MIDI Mappings:**
- `Paketti:Jump to Section (Next) [Trigger]`
- `Paketti:Jump to Section (Previous) [Trigger]`

Quickly navigate between section boundaries in your song without changing loop settings.

---

## Pattern Navigation within Sections

### Jump to Pattern in Section (01-16)
**Shortcuts:** (01-16 available)
- `Global:Paketti:Jump to Pattern 01 in Section` through `16`

**MIDI Mappings:**
- `Paketti:Jump to Pattern 01 in Section [Trigger]` through `16`

Jumps to a specific pattern number within the current section. For example, if you're in a section with 8 patterns, pressing "03" jumps to the 3rd pattern of that section.

---

### Select Pattern Within Section (MIDI Knob)
**MIDI Mapping:** `Paketti:Select Pattern Within Section [Knob]`

Use a MIDI knob to select different patterns within the current section. The knob range (0-127) is mapped to the number of patterns in the section.

---

### Select and Trigger Pattern in Current Section (01-16)
**Shortcuts:** (01-16 available)
- `Global:Paketti:Select and Trigger Pattern 01 in Current Section` through `16`

**MIDI Mappings:**
- `Paketti:Select and Trigger Pattern 01 in Current Section [Trigger]` through `16`

Selects and immediately triggers playback of a specific pattern within the current section.

---

### Select and Schedule Pattern in Current Section (01-16)
**Shortcuts:** (01-16 available)
- `Global:Paketti:Select and Schedule Pattern 01 in Current Section` through `16`

**MIDI Mappings:**
- `Paketti:Select and Schedule Pattern 01 in Current Section [Trigger]` through `16`

Schedules a specific pattern within the current section to play at the next pattern boundary.

---

### Select and Add to Schedule Pattern in Current Section (01-16)
**Shortcuts:** (01-16 available)
- `Global:Paketti:Select and Add to Schedule Pattern 01 in Current Section` through `16`

**MIDI Mappings:**
- `Paketti:Select and Add to Schedule Pattern 01 in Current Section [Trigger]` through `16`

Adds a specific pattern within the current section to the schedule queue.

---

### Trigger Pattern Within Section (MIDI Knob)
**MIDI Mapping:** `Paketti:Trigger Pattern Within Section [Knob]`

Use a MIDI knob to trigger different patterns within the current section. Automatically starts playback.

---

## Performance Lock Features

### Select Section with Performance Lock (MIDI Knob)
**MIDI Mapping:** `Paketti:Select Section with Performance Lock [Knob]`

**Special Feature:** This knob allows selecting and triggering sections with a **performance lock** - once playback starts, you cannot change sections until you stop transport. This prevents accidental section changes during live performance.

Maps MIDI value (0-127) to all available sections in your song. Automatically:
- Selects the target section
- Creates a loop for that section
- Starts playback if not already playing
- Triggers the section to play immediately
- **LOCKS section selection until transport is stopped**

---

## Sequence Jumping & Triggering

### Jump to Sequence (Next/Previous)
**Shortcuts:**
- `Global:Paketti:Jump to Sequence (Next)` - Move to next sequence
- `Global:Paketti:Jump to Sequence (Previous)` - Move to previous sequence

Simple navigation between sequences without affecting playback or loop settings.

---

### Selected Specific Sequence (00-31)
**Shortcuts:** (00-31 available)
- `Global:Paketti:Selected Specific Sequence 00` through `31`

Directly jumps the edit cursor to a specific sequence position (without triggering playback).

---

### Trigger Sequence (00-31)
**Shortcuts:** (00-31 available)
- `Global:Paketti:Trigger Sequence 00` through `31`

Immediately triggers playback from a specific sequence position, regardless of current transport state.

---

### Continue Sequence from Same Line (00-31)
**Shortcuts:** (00-31 available)
- `Global:Paketti:Continue Sequence 00 From Same Line` through `31`

**MIDI Mapping:** `Paketti:Continue Sequence From Same Line [Set Sequence]`

Jumps to a specified sequence position while maintaining the same pattern line number. Useful for live performance when you want to switch sections but stay on the same beat.

*Example: If you're on line 32 of sequence 5, and trigger "Continue Sequence 10 from Same Line", you'll jump to line 32 of sequence 10.*

---

### Continue Current Sequence From Same Line
**Shortcut:** `Global:Paketti:Continue Current Sequence From Same Line`

Re-triggers the current sequence from its current line position. Useful for "restart current section" functionality.

---

## Pattern Editor Integration

### Selection in Pattern to Group
**Shortcut:** `Pattern Editor:Paketti:Selection in Pattern to Group`

Takes your selected tracks from the Pattern Editor and creates a new group track containing them. Automatically positions the group after the selected tracks.

---

### Selection in Pattern Matrix to Group
**Shortcut:** `Pattern Matrix:Paketti:Selection in Pattern Matrix to Group`

Same as above, but works with Pattern Matrix selections. Allows grouping tracks by selecting them in the Pattern Matrix view.

---

## Tips & Workflow Suggestions

### Live Performance Workflow
1. **Pre-arrange sections** with descriptive names (01.Intro, 02.Verse, 03.Chorus, etc.)
2. **Use Section by Name shortcuts** for reliable section triggering
3. **Enable Performance Lock** for the main section selection knob to prevent accidents
4. **Use "Continue from Same Line"** for seamless section transitions during performance
5. **Schedule sections** ahead of time for smooth transitions

### Studio Workflow  
1. **Use Position-based shortcuts** when sections are still unnamed
2. **Loop expansion** (Next/Previous) for quick A/B section comparisons
3. **Pattern-within-section navigation** for detailed editing without losing your place
4. **Sequence Selection to Loop** for quickly testing specific sequence ranges

# Sample Loading & Management

← [Back to Main Manual](README.md)

Comprehensive guide to Paketti's sample loading, drumkit creation, and sample management features.

---

## Table of Contents
1. [PitchBend Sample Loaders](#pitchbend-sample-loaders)
2. [Sample Slot Management](#sample-slot-management)
3. [Quick Sample Folders](#quick-sample-folders)
4. [Sample Zoom Controls](#sample-zoom-controls)
5. [Save Sample Functions](#save-sample-functions)

---

## PitchBend Sample Loaders

### Paketti PitchBend Multiple Sample Loader
**Shortcuts:**
- `Global:Paketti:Paketti PitchBend Multiple Sample Loader` ⌨️ 📋
- `Global:Paketti:Paketti PitchBend Multiple Sample Loader (Normalize)` ⌨️ 📋
- `Sample Editor:Paketti:Paketti PitchBend Multiple Sample Loader` ⌨️
- `Sample Editor:Paketti:Paketti PitchBend Multiple Sample Loader (Normalize)` ⌨️

**MIDI Mapping:** `Paketti:Midi Paketti PitchBend Multiple Sample Loader` 🎹

**Menu:** `Instrument Box:Paketti:Load:Paketti PitchBend Multiple Sample Loader` 📋
**Menu:** `Main Menu:Tools:Paketti:Instruments:Paketti PitchBend Multiple Sample Loader` 📋
**Menu:** `Disk Browser Files:Paketti:Load:Paketti PitchBend Multiple Sample Loader` 📋
**Menu:** `Disk Browser Files:Paketti:Load:Paketti PitchBend Multiple Sample Loader (Normalize)` 📋

Loads multiple samples using macOS Finder/Windows Explorer and automatically "Pakettifies" them with the default Paketti XRNI instrument template:
- **8 Macros** pre-configured (PitchBend, Cutoff, Resonance, Cutoff LFO, Drive, Parallel Compression, etc.)
- **Sample FX Chain** with modulation devices
- **Track DSP** with *Instr. Macros device for automation
- **Normalize option** applies normalization during load

---

### Paketti PitchBend Drumkit Sample Loader
**Shortcuts:**
- `Global:Paketti:Paketti PitchBend Drumkit Sample Loader` ⌨️ 📋
- `Global:Paketti:Paketti PitchBend Drumkit Sample Loader (Random)` ⌨️ 📋 - Loads random 120 samples

**MIDI Mappings:**
- `Paketti:Midi Paketti PitchBend Drumkit Sample Loader` 🎹
- `Paketti:Midi Paketti PitchBend Drumkit Sample Loader (Random)` 🎹

**Menu:** `Instrument Box:Paketti:Load:Paketti PitchBend Drumkit Sample Loader` 📋
**Menu:** `Instrument Box:Paketti:Load:Paketti PitchBend Drumkit Sample Loader (Random)` 📋
**Menu:** `Main Menu:Tools:Paketti:Instruments:Paketti PitchBend Drumkit Sample Loader (Random)` 📋
**Menu:** `Disk Browser Files:Paketti:Load:Paketti PitchBend Drumkit Sample Loader` 📋
**Menu:** `Disk Browser Files:Paketti:Load:Paketti PitchBend Drumkit Sample Loader (Random)` 📋

Loads up to 120 samples and maps them chromatically from C-0 to B-9. Applies the same Paketti XRNI template.

**Random variant** loads 120 random samples from your selected folder - great for instant experimental drumkits!

---

## Sample Slot Management

### Add Sample Slots
**Shortcuts:**
- `Global:Paketti:Add Sample Slot to Instrument` ⌨️ - Add 1 empty slot
- `Global:Paketti:Add 84 Sample Slots to Instrument` ⌨️ 📋 - Add 84 empty slots

**Menu:** `Instrument Box:Paketti:Initialize:Add 84 Sample Slots to Instrument` 📋
**Menu:** `Sample Editor:Paketti:Instruments:Add 84 Sample Slots to Instrument` 📋
**Menu:** `Sample Navigator:Paketti:Add 84 Sample Slots to Instrument` 📋

Quickly add empty sample slots to the current instrument without manual clicking.

---

### Insert New Sample Slot & Select
**Shortcut:** `Global:Paketti:Insert New Sample Slot & Select` ⌨️
**MIDI Mapping:** `Paketti:Midi Insert New Sample Slot & Select` 🎹

Inserts a new empty sample slot and automatically selects it, ready for you to load or record audio.

---

### Delete Current Sample & Select Next
**Shortcut:** `Global:Paketti:Delete Current Sample & Select Next`
**MIDI Mapping:** `Paketti:Midi Delete Current Sample & Select Next`

Deletes the currently selected sample and automatically jumps to the next sample. Speeds up sample cleanup workflows.

---

## Quick Sample Folders

Paketti provides a **Quick Sample Folders** system for instant access to your most-used sample libraries.

**Menu Location:** `Main Menu:Tools:Paketti:Quick Sample Folders`

For each configured folder, you get **6 menu entries:**

### Per-Folder Actions
1. **Open Folder** - Opens the folder in Finder/Explorer
2. **Random Drumkit** - Loads 120 random samples as drumkit
3. **Random 01** - Loads 1 random sample  
4. **Random 01 Sample to Pattern** - Loads 1 random sample + writes it to pattern
5. **Random 12** - Loads 12 random samples
6. **Random 32** - Loads 32 random samples

**How to Configure:**
- Set folder paths in Paketti Preferences
- Folders appear automatically in the Quick Sample Folders menu
- All loaded samples are automatically Pakettified

**Use Cases:**
- **Drum libraries** - Quick random drumkit generation
- **Vocal chops** - Load random vocal samples
- **Texture libraries** - Instant ambient sample access
- **Sound design** - Random sample inspiration

---

## Sample Zoom Controls

### Set Sample Zoom (01x-99x)
**Shortcuts:** (01-99 available)
- `Sample Editor:Paketti:Set Sample Zoom 01x` through `99x`
- `Sample Editor:Paketti:Set Sample Zoom:Zoom 01x` through `99x`

**MIDI Mapping:** `Paketti:Midi Sample Zoom (1x-11x) [Knob]`

Directly set the Sample Editor zoom level without scrolling. Higher numbers = more zoomed in.

**Workflow tip:** Assign commonly used zoom levels (2x, 4x, 8x, 16x) to shortcuts for quick navigation between overview and detail views.

---

## Save Sample Functions

### Save Selected Sample
**Shortcuts:**
- `Global:Paketti:Paketti Save Selected Sample .WAV` ⌨️ 📋
- `Global:Paketti:Paketti Save Selected Sample .FLAC` ⌨️ 📋

**MIDI Mappings:**
- `Paketti:Midi Paketti Save Selected Sample .WAV` 🎹
- `Paketti:Midi Paketti Save Selected Sample .FLAC` 🎹

**Menu:** `Sample Editor:Paketti:Save:Paketti Save Selected Sample .WAV/.FLAC` 📋
**Menu:** `Sample Navigator:Paketti:Save:Paketti Save Selected Sample .WAV/.FLAC` 📋
**Menu:** `Sample Mappings:Paketti:Save:Paketti Save Selected Sample .WAV/.FLAC` 📋

Opens Finder/Explorer to save the currently selected sample. Much faster than navigating through Renoise's sample save dialog.

---

### Save Selected Sample Range
**Shortcuts:**
- `Global:Paketti:Paketti Save Selected Sample Range .WAV` ⌨️ 📋
- `Global:Paketti:Paketti Save Selected Sample Range .FLAC` ⌨️ 📋

**MIDI Mappings:**
- `Paketti:Save Selected Sample Range .WAV` 🎹
- `Paketti:Save Selected Sample Range .FLAC` 🎹

**Menu:** `Sample Editor:Paketti:Save:Paketti Save Selected Sample Range .WAV/.FLAC` 📋

**Fast Tracker 2 Feature:** Saves only the selected range in the sample buffer. Perfect for:
- Exporting individual slices
- Extracting specific transients
- Creating loops from longer samples

---

# Sample Normalization & Channel/Bit Depth Conversion

← [Back to Main Manual](README.md)

Complete guide to Paketti's advanced normalization, channel conversion, and bit depth processing features.

---

## Table of Contents
1. [Normalize Sample](#normalize-sample)
2. [Normalize to -12dB](#normalize-to--12db)
3. [Normalize Slices Independently](#normalize-slices-independently)
4. [Reverse Sample & Slices](#reverse-sample--slices)
5. [Mono/Stereo Conversion](#monostereo-conversion)
6. [Bit Depth Conversion](#bit-depth-conversion)
7. [Sample Truncater](#sample-truncater)
8. [Sample Adjust Dialog](#sample-adjust-dialog)
9. [Build Sample Variants](#build-sample-variants)

---

## Normalize Sample

### Normalize Selected Sample or Slice
**Shortcuts:**
- `Sample Editor:Paketti:Normalize Selected Sample or Slice` ⌨️ 📋
- `Global:Paketti:Normalize Selected Sample or Slice` ⌨️ 📋

**MIDI:** `Paketti:Normalize Selected Sample or Slice` 🎹

**Menu:** `Sample Editor:Paketti:Process:Normalize Selected Sample or Slice` 📋
**Menu:** `Sample Navigator:Paketti:Process:Normalize Selected Sample or Slice` 📋
**Menu:** `Sample Mappings:Paketti:Process:Normalize Selected Sample or Slice` 📋

**Smart Normalization** - Works with both whole samples and individual slices:
- **No Slices:** Normalizes entire sample or selection
- **Has Slices:** Normalizes only the selected slice or selection within slice
- **Channel-aware:** Respects left/right/both channel selection
- **Per-channel peaks:** Finds peak per channel for accurate normalization
- **Smart detection:** Skips if already at 0.999969 or higher (near max)

**Features:**
- Progress dialog with cancellation support
- Ultra-fast optimized processing (4M+ frames/second)
- Memory-efficient for huge samples (>50MB uses streaming)
- Works with selections within samples or slices

---

### Normalize Sample (Ultra-Fast)
**Shortcut:** `Global:Paketti:Normalize Sample` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Normalize Sample` 📋
**Menu:** `Sample Navigator:Paketti:Process:Normalize Sample` 📋
**Menu:** `Sample Mappings:Paketti:Process:Normalize Sample` 📋

Fast normalization of the selected sample - automatically chooses best algorithm:
- **< 50MB:** Ultra-fast cached method
- **> 50MB:** Streaming method (memory-efficient)

---

### Normalize All Samples in Instrument
**Shortcut:** `Global:Paketti:Normalize All Samples in Instrument` ⌨️ 📋

**MIDI:** `Paketti:Normalize All Samples in Instrument` 🎹

**Menu:** `Sample Editor:Paketti:Process:Normalize All Samples in Instrument` 📋
**Menu:** `Sample Navigator:Paketti:Process:Normalize All Samples in Instrument` 📋
**Menu:** `Sample Mappings:Paketti:Process:Normalize All Samples in Instrument` 📋

Normalizes every sample in the current instrument:
- **Sliced instruments:** Only normalizes first sample (preserves slices)
- **Regular instruments:** Normalizes each sample independently
- Progress dialog shows which sample is being processed
- Skips already-normalized samples

---

## Normalize to -12dB

### Normalize with Headroom
**Shortcuts:**
- `Sample Editor:Paketti:Normalize Selected Sample to -12dB` ⌨️ 📋
- `Sample Editor:Paketti:Normalize Selected Instrument to -12dB` ⌨️ 📋
- `Sample Editor:Paketti:Normalize All Instruments to -12dB` ⌨️ 📋

**MIDI Mappings:**
- `Paketti:Normalize Selected Sample to -12dB` 🎹
- `Paketti:Normalize Selected Instrument to -12dB` 🎹
- `Paketti:Normalize All Instruments to -12dB` 🎹

**Menu:** `Sample Editor:Paketti:Process:Normalize Selected Sample -12dB` 📋
**Menu:** `Sample Editor:Paketti:Process:Normalize Selected Instrument -12dB (All Samples & Slices)` 📋
**Menu:** `Sample Editor:Paketti:Process:Normalize All Instruments -12dB` 📋
(Also in Sample Navigator & Sample Mappings)

**Professional Normalization** with -12dB headroom for:
- **Mastering chains** - Leaves room for processing
- **Preventing clipping** - Safe for further compression/limiting
- **Mixing** - Consistent levels with overhead

**Three Scopes:**
1. **Current Sample** - Selected sample only
2. **All Samples** - Entire instrument
3. **All Instruments** - Every instrument in song

---

## Normalize Slices Independently

**Shortcut:** `Global:Paketti:Normalize Sample Slices Independently` ⌨️ 📋

**Menu:** `Sample Editor:Paketti:Process:Normalize Slices Independently` 📋
**Menu:** `Sample Navigator:Paketti:Process:Normalize Slices Independently` 📋

**Advanced Slice Processing** - Each slice is normalized independently:
- Finds peak for each slice separately
- Normalizes each slice to its own maximum
- Preserves relative dynamics between slices
- Perfect for drumkits where each slice should be at maximum volume

**Use Cases:**
- **Drumkits** - Make every drum hit equally loud
- **Vocal chops** - Maximize each chop independently
- **Breaks** - Each hit at full volume for maximum punch

---

## Reverse Sample & Slices

### Reverse Selected Sample or Slice
**Shortcuts:**
- `Sample Editor:Paketti:Reverse Selected Sample or Slice` ⌨️ 📋
- `Sample Keyzones:Paketti:Reverse Selected Sample or Slice` ⌨️ 📋

**MIDI:** `Paketti:Reverse Selected Sample or Slice` 🎹

**Menu:** `Sample Editor:Paketti:Process:Reverse Selected Sample or Slice` 📋
**Menu:** `Sample Navigator:Paketti:Process:Reverse Selected Sample or Slice` 📋
**Menu:** `Sample Mappings:Paketti:Process:Reverse Selected Sample or Slice` 📋

**Intelligent Reversing:**
- **No Slices:** Reverses entire sample or selection
- **Has Slices:** Reverses only the selected slice or selection within slice
- Works with stereo samples
- Progress dialog with cancellation

---

### Reverse All Samples in Selected Instrument
**Shortcut:** `Global:Paketti:Reverse All Samples in Selected Instrument` ⌨️

**MIDI:** `Paketti:Reverse All Samples in Selected Instrument` 🎹

**Menu:** `Sample Editor:Paketti:Process:Reverse All Samples in Selected Instrument` 📋

Reverses every sample in the instrument:
- **Sliced instruments:** Only reverses first sample
- **Regular instruments:** Reverses each sample independently
- Progress shows sample name and overall completion

---

## Mono/Stereo Conversion

### Mono to Stereo
**Shortcuts:**
- `Sample Editor:Paketti:Convert Mono to Stereo` ⌨️ 📋
- `Sample Keyzones:Paketti:Convert Mono to Stereo` ⌨️ 📋

**MIDI:** `Sample Editor:Paketti:Convert Mono to Stereo` 🎹

**Menu:** `Sample Editor:Paketti:Process:Convert Mono to Stereo` 📋
**Menu:** `Sample Navigator:Paketti:Process:Convert Mono to Stereo` 📋

Converts mono sample to stereo by duplicating to both channels.

---

### Mono to Stereo (Blank Channel)
**Shortcuts:**
- `Sample Editor:Paketti:Mono to Left with Blank Right` ⌨️ 🎹
- `Sample Editor:Paketti:Mono to Right with Blank Left` ⌨️ 🎹
- `Sample Keyzones:Paketti:Mono to Left with Blank Right` ⌨️
- `Sample Keyzones:Paketti:Mono to Right with Blank Left` ⌨️

**MIDI Mappings:**
- `Sample Editor:Paketti:Mono to Right with Blank Left` 🎹
- `Sample Editor:Paketti:Mono to Left with Blank Right` 🎹

Converts mono to stereo with one channel silent:
- **Left with Blank Right:** Mono→Left, Right=silence
- **Right with Blank Left:** Mono→Right, Left=silence

**Use Cases:**
- Preparing for mid/side processing
- Creating space for layer stacking
- Phase manipulation setups

---

### Stereo to Mono
**Shortcuts:**
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Left)` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Right)` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert Stereo to Mono (Mix Both)` ⌨️ 🎹 📋
- `Sample Keyzones:Paketti:Convert Stereo to Mono (Keep Left)` ⌨️
- `Sample Keyzones:Paketti:Convert Stereo to Mono (Keep Right)` ⌨️
- `Sample Keyzones:Paketti:Convert Stereo to Mono (Mix Both)` ⌨️

**MIDI Mappings:**
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Left)` 🎹
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Right)` 🎹
- `Sample Editor:Paketti:Convert Stereo to Mono (Mix Both)` 🎹

**Menu:** `Sample Editor:Paketti:Process:Convert Stereo to Mono (Keep Left/Right/Mix Both)` 📋
(Also in Sample Navigator)

**Three Modes:**
1. **Keep Left** - Uses left channel only
2. **Keep Right** - Uses right channel only
3. **Mix Both** - Averages both channels (true mono mix)

---

### Convert All Samples to Mono
**Shortcuts:**
- `Sample Editor:Paketti:Convert All Samples to Mono (Keep Left)` ⌨️ 🎹
- `Sample Editor:Paketti:Convert All Samples to Mono (Keep Right)` ⌨️ 🎹
- `Sample Editor:Paketti:Convert All Samples to Mono (Mix Both)` ⌨️ 🎹
- `Sample Keyzones:Paketti:Convert All Samples to Mono (Keep Left)` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to Mono (Keep Right)` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to Mono (Mix Both)` ⌨️

**MIDI Mappings:**
- `Sample Editor:Paketti:Convert All Samples to Mono (Keep Left)` 🎹
- `Sample Editor:Paketti:Process:Convert All Samples to Mono (Keep Right)` 🎹
- `Sample Editor:Paketti:Process:Convert All Samples to Mono (Mix Both)` 🎹

Batch converts all stereo samples in instrument to mono:
- Skips mono samples
- Skips sliced samples
- Progress dialog shows which sample is processing
- Preserves all sample properties

---

## Bit Depth Conversion

### Convert to Bit Depth (Single Sample)
**Shortcuts:**
- `Sample Editor:Paketti:Convert to 8-bit` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert to 16-bit` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert to 24-bit` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert to 32-bit` ⌨️ 🎹 📋
- `Sample Keyzones:Paketti:Convert to 8-bit` ⌨️
- `Sample Keyzones:Paketti:Convert to 16-bit` ⌨️
- `Sample Keyzones:Paketti:Convert to 24-bit` ⌨️
- `Sample Keyzones:Paketti:Convert to 32-bit` ⌨️

**MIDI Mappings:**
- `Sample Editor:Paketti:Convert to 8-bit` 🎹
- `Sample Editor:Paketti:Convert to 16-bit` 🎹
- `Sample Editor:Paketti:Convert to 24-bit` 🎹
- `Sample Editor:Paketti:Convert to 32-bit` 🎹

**Menu:** `Sample Editor:Paketti:Process:Convert to [8/16/24/32]-bit` 📋
(Also in Sample Navigator & Sample Mappings)

**Professional Bit Depth Conversion with:**
- **Triangular dithering (TPDF)** - Reduces quantization noise
- **Proper quantization** - Mathematically correct bit reduction
- **Property preservation** - All sample settings maintained
- **Progress feedback** - Shows conversion percentage

**Common Workflows:**
- **32→16bit:** For distribution/compatibility
- **16→8bit:** For lo-fi aesthetic
- **Any→32bit:** For maximum quality processing

---

### Convert All Samples to Bit Depth
**Shortcuts:**
- `Sample Editor:Paketti:Convert All Samples to 8-bit` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert All Samples to 16-bit` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert All Samples to 24-bit` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Convert All Samples to 32-bit` ⌨️ 🎹 📋
- `Sample Keyzones:Paketti:Convert All Samples to 8-bit` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to 16-bit` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to 24-bit` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to 32-bit` ⌨️

**MIDI Mappings:**
- `Sample Editor:Paketti:Convert All Samples to 8-bit` 🎹
- `Sample Editor:Paketti:Convert All Samples to 16-bit` 🎹
- `Sample Editor:Paketti:Convert All Samples to 24-bit` 🎹
- `Sample Editor:Paketti:Convert All Samples to 32-bit` 🎹

**Menu:** `Sample Editor:Paketti:Process:Convert All Samples to [8/16/24/32]-bit` 📋
(Also in Sample Navigator & Sample Mappings)

Batch converts all samples in instrument:
- Skips samples already at target bit depth
- Progress shows sample number and percentage
- Preserves all sample properties including keymapping

---

## Sample Truncater

### Truncate Sample (Duplicate Frames)
**Shortcuts:**
- `Sample Editor:Paketti:Truncate Sample 2x` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Truncate Sample 4x` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Truncate Sample 8x` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Truncate Sample 16x` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Truncate Sample 32x` ⌨️ 🎹 📋
- `Sample Editor:Paketti:Truncate Sample 64x` ⌨️ 🎹 📋
- `Sample Keyzones:Paketti:Truncate Sample 2x` through `64x` ⌨️

**MIDI Mappings:**
- `Paketti:Truncate Sample 2x` through `64x` 🎹

**Menu:** `Sample Editor:Paketti:Process:Truncate Sample [2x/4x/8x/16x/32x/64x]` 📋

**Lo-Fi Sample Rate Reducer Effect:**
- Duplicates each frame N times
- Creates "bit-crushed" / sample-rate-reduced sound
- **2x:** Subtle degradation
- **4x-8x:** Noticeable lo-fi character
- **16x-64x:** Extreme degradation, aliasing artifacts

**Technical:** This doesn't actually change sample rate - it duplicates frames to simulate lower sample rate playback.

**Use Cases:**
- **Lo-fi aesthetic** - 8-bit/chiptune sounds
- **Telephone effect** - Heavily truncated (32x-64x)
- **Retro textures** - 4x-8x sweet spot

---

## Sample Adjust Dialog

**Shortcuts:**
- `Sample Editor:Paketti:Paketti Sample Adjust Dialog...` ⌨️ 📋
- `Global:Paketti:Paketti Sample Adjust Dialog...` ⌨️ 📋

**Menu:** `Sample Editor:Paketti Gadgets:Paketti Sample Adjust Dialog...` 📋
**Menu:** `Sample Navigator:Paketti Gadgets:Paketti Sample Adjust Dialog...` 📋
**Menu:** `Sample Mappings:Paketti Gadgets:Paketti Sample Adjust Dialog...` 📋

**All-In-One Sample Conversion Dialog** with dropdowns for:

### Channel Conversion
**For Mono Samples:**
- Mono (unchanged)
- Stereo (duplicate to both)

**For Stereo Samples:**
- Mono (Mix) - Average both channels
- Mono (Keep Left) - Discard right
- Mono (Keep Right) - Discard left
- Stereo (unchanged)
- Mono→Stereo (Left only) - Right = silence
- Mono→Stereo (Right only) - Left = silence

### Sample Rate Conversion
8 presets: **11025, 22050, 32000, 44100, 48000, 88200, 96000, 192000 Hz**

### Bit Depth Conversion
4 options: **8-bit, 16-bit, 24-bit, 32-bit** (with TPDF dithering)

### Invert Channels
**For Mono:**
- Do nothing
- Invert

**For Stereo:**
- Do nothing
- Invert Left
- Invert Right
- Invert Both

**Atomic Operation:** All conversions happen in one operation - no quality loss from multiple passes!

---

## Build Sample Variants

**Shortcut:** `Pattern Editor:Paketti:Build Sample Variants` ⌨️ 🎹

**Menu:** `Pattern Editor:Paketti:Build Sample Variants` 📋

**MIDI:** `Paketti:Build Sample Variants` 🎹

**Creative Waveform Destruction** - Creates 4 variant samples with different bit-wrapping algorithms:

1. **Wrapped** - Signed-to-unsigned wrap-around distortion
2. **Unwrapped** - Unsigned-to-signed conversion
3. **Scaled Unsigned** - DC offset shift
4. **Scaled Signed** - Bipolar scaling distortion

Each variant is:
- Created as new sample
- Named with "(wrapped)", "(unwrapped)", etc suffix
- **Set to -INF dB** so you can fade them in manually
- Ready for layering with original

**Perfect for:**
- **Glitch aesthetics** - Digital artifacts
- **Sound design** - Instant variations
- **Layering** - Blend with original for texture
- **Experimental** - Unpredictable transformations

---

## Legend

**Symbols:**
- ⌨️ = Keyboard shortcut available
- 🎹 = MIDI mapping available
- 📋 = Menu entry available

← [Back to Main Manual](README.md)

# Sample Processing & Manipulation

← [Back to Main Manual](README.md)

Comprehensive guide to sample buffer manipulation, processing, and transformation features.

## Table of Contents
1. [Sample Buffer Rotation](#sample-buffer-rotation)
2. [Sample Buffer Flipping](#sample-buffer-flipping)
3. [Sample Buffer Selection](#sample-buffer-selection)
4. [Loop Manipulation](#loop-manipulation)
5. [Sample Trimming](#sample-trimming)
6. [Sample Duplication](#sample-duplication)
7. [Frequency Analysis](#frequency-analysis)

## Sample Buffer Rotation

### Rotate Sample Buffer (Fixed Amounts)
**Shortcuts:**
- `Sample Editor:Paketti:Rotate Sample Buffer Right 10` / `Left 10` ⌨️
- `Sample Editor:Paketti:Rotate Sample Buffer Right 100` / `Left 100` ⌨️
- `Sample Editor:Paketti:Rotate Sample Buffer Right 1000` / `Left 1000` ⌨️
- `Sample Editor:Paketti:Rotate Sample Buffer Right 10000` / `Left 10000` ⌨️

Rotates the sample buffer by moving audio from the beginning to the end (or vice versa). The audio wraps around - no data is lost.

**Use Cases:**
- Phase alignment - Nudge samples for better phase coherence
- Loop creation - Find natural loop points by rotating
- Rhythmic shifting - Move transients to different positions

### Rotate Sample Buffer (MIDI Knob Control)
**MIDI Mappings:**
- `Paketti:Rotate Sample Buffer Left/Right Fine x[Knob]` 🎹
- `Paketti:Rotate Sample Buffer Left/Right Coarse x[Knob]` 🎹

Real-time sample rotation with MIDI controller.

## Sample Buffer Flipping

### Flip Sample Buffer Selection
**Shortcuts:**
- `Sample Editor:Paketti:Flip Sample Buffer Selection Back` ⌨️
- `Sample Editor:Paketti:Flip Sample Buffer Selection Forward` ⌨️

**MIDI Mappings:**
- `Paketti:Flip Sample Buffer Selection Back [Trigger]` 🎹
- `Paketti:Flip Sample Buffer Selection Forward [Trigger]` 🎹

Flips (rotates) the audio in different sized chunks: 1/2, 1/4, 1/8, 1/16. Each press cycles through divisions.

## Loop Manipulation

### Sample Loop Cycler
**Shortcuts:**
- `Global:Paketti:Sample Loop Cycler (Forwards)` ⌨️
- `Global:Paketti:Sample Loop Cycler (Backwards)` ⌨️

Cycle: Off → Forward → Backward → PingPong → Off

### All Samples Loop Cycler
**Shortcuts:**
- `Global:Paketti:All Samples Loop Cycler (Forwards)` ⌨️
- `Global:Paketti:All Samples Loop Cycler (Backwards)` ⌨️

### Set Loop Mode (Sample Editor Context)
**Shortcuts:**
- `Sample Editor:Paketti:Set Loop Mode to 1 Off` ⌨️
- `Sample Editor:Paketti:Set Loop Mode to 2 Forward` ⌨️
- `Sample Editor:Paketti:Set Loop Mode to 3 Reverse` ⌨️
- `Sample Editor:Paketti:Set Loop Mode to 4 PingPong` ⌨️

### Sample Loop Halve/Double
**MIDI Mappings:**
- `Sample Editor:Paketti:Sample Loop Halve` 🎹
- `Sample Editor:Paketti:Sample Loop Double` 🎹

## Sample Trimming

### Trim by Half
**Shortcuts:**
- `Sample Editor:Paketti:Trim by Half (Selected Sample)` ⌨️
- `Global:Paketti:Trim by Half (All Samples in Instrument)` ⌨️

### FT2 Minimize Selected Sample
**Shortcut:** `Global:Paketti:FT2 Minimize Selected Sample` ⌨️

Trims the sample to end at the loop end point.

## Sample Duplication

### Duplicate and Reverse Instrument
**Shortcut:** `Global:Paketti:Duplicate and Reverse Instrument` ⌨️ 📋
**MIDI:** `Paketti:Duplicate and Reverse Instrument [Trigger]` 🎹

Creates a new instrument with all samples reversed.

### Duplicate Sample with Transpose
**MIDI Mappings:**
- `Paketti:Duplicate Selected Sample at -12 transpose` 🎹
- `Paketti:Duplicate Selected Sample at -24 transpose` 🎹
- `Paketti:Duplicate Selected Sample at +12 transpose` 🎹
- `Paketti:Duplicate Selected Sample at +24 transpose` 🎹

### Octave Slammer
**MIDI Mappings:**
- `Paketti:Octave Slammer (-3 +3 octaves)` 🎹
- `Paketti:Octave Slammer (-2 +2 octaves)` 🎹
- `Paketti:Octave Slammer (-1 +1 octaves)` 🎹

Creates multiple copies at different octave transposes simultaneously.

## Frequency Analysis

### Detect and Correct Single-Cycle Pitch
**Menu:** `Sample Editor:Paketti:Detect and Correct Single-Cycle Pitch` 📋

Analyzes single-cycle waveform and automatically sets correct transpose.

### Frequency to Note Analysis
**Menu:** `Sample Editor Ruler:Frequency to Note Analysis` 📋

Shows detected frequency, nearest MIDI note, cents deviation.


# Slicing Features

← [Back to Main Manual](README.md)

Complete guide to Paketti's sample slicing, slice manipulation, and slice marker management features.

## Table of Contents
1. [Real-Time Slice Monitoring](#real-time-slice-monitoring)
2. [BPM-Based Sample Slicer](#bpm-based-sample-slicer)
3. [Slice to Pattern Sequencer](#slice-to-pattern-sequencer)
4. [Slice Marker Management](#slice-marker-management)
5. [Slice Transient Detection](#slice-transient-detection)
6. [Slice Extraction](#slice-extraction)
7. [Beatsync & Slice Processing](#beatsync--slice-processing)
8. [Slice Randomization](#slice-randomization)
9. [Auto-Slice & Kit Creation](#auto-slice--kit-creation)

## Real-Time Slice Monitoring

**Keybindings:**
- `Global:Paketti:Real-Time Slice Monitoring (Toggle Start/Stop)` ⌨️
- `Global:Paketti:Real-Time Slice Monitoring (Start)` ⌨️
- `Global:Paketti:Real-Time Slice Monitoring (Stop)` ⌨️
- `Global:Paketti:Real-Time Slice Insert Marker at Current Position` ⌨️

**MIDI:**
- `Paketti:Real-Time Slice Monitoring Toggle` 🎹
- `Paketti:Real-Time Slice Insert Marker` 🎹

**Menu:**
- `Main Menu:Tools:Paketti:Real-Time Slice Monitoring (Toggle)` 📋
- `Sample Editor:Paketti:Real-Time Slice Monitoring (Toggle)` 📋
- `Sample Editor Ruler:Real-Time Slice Monitoring (Toggle)` 📋

Live slice marker insertion while sample plays. Perfect for manual slicing to audio playback - press keys in rhythm to create slice markers.

**How It Works:**
1. **Start:** Toggle Real-Time Slice Monitoring
2. **Playback:** Sample starts playing from beginning
3. **Insert Markers:** Press assigned key during playback to insert slice markers at current position
4. **Stop:** Toggle again or playback reaches end

**Features:**
- Continuous sample playback
- Frame-accurate marker insertion
- Visual selection follows playback
- Automatic cleanup of stuck notes
- Duplicate marker prevention (100-frame threshold)
- Auto-stops at sample end

**Use Cases:**
- **Manual slicing to rhythm:** Tap along with break, create perfect slices
- **Live performance prep:** Mark key hit points in real-time
- **DJ-style slicing:** Create slice points by feel
- **Drum break slicing:** Listen and slice in one pass

**Workflow:**
1. Load drum break
2. Enable Real-Time Slice Monitoring
3. Sample plays continuously
4. Press key on each kick/snare/hat
5. Markers inserted instantly
6. Disable monitoring
7. Result: Perfect slices at exact hit points

---

## BPM-Based Sample Slicer

**Keybinding:**
- `Global:Paketti:BPM-Based Sample Slicer Dialog...` ⌨️

**MIDI:**
- `Paketti:BPM-Based Sample Slicer Dialog` 🎹

**Menu:**
- `Main Menu:Tools:Paketti:BPM-Based Sample Slicer Dialog...` 📋

Intelligent slicer that creates slice markers based on BPM and beat divisions. Perfect for loops and rhythmic material with known tempo.

**Dialog Features:**
- **BPM Input:** Set sample's original BPM (20-999)
- **Beats per Slice:** Define slice timing (0.125-16 beats)
- **Preset Buttons:** Quick access to common divisions

**Preset Beat Values:**
- **1/6 beat** - Sextuplets
- **1/4 beat** - Sixteenth notes
- **1/3 beat** - Triplets
- **1/2 beat** - Eighth notes
- **1 beat** - Quarter notes
- **2 beats** - Half notes
- **4 beats** - Whole notes
- **8 beats** - Two measures

**Process:**
1. Enter sample BPM
2. Choose beats per slice
3. Click "Slice" button
4. Markers created at exact beat positions
5. Beatsync automatically configured

**Calculations:**
- **Frames per beat** = (Sample Rate × 60) / BPM
- **Slice spacing** = Frames per beat × Beats per slice
- **Total slices** = Sample length / Slice spacing

**Use Cases:**
- **Perfect loop slicing:** 4/8/16-beat loops sliced to quarter/eighth notes
- **Breakbeat slicing:** 2-bar break (8 beats) sliced to 1/2 beat = 16 slices
- **Tempo-locked slicing:** Maintain musical timing regardless of sample length
- **Pattern-ready kits:** Slices aligned to grid

**Example:** 140 BPM breakbeat, 2 bars = 8 beats
- Slice at 1 beat → 8 slices (one per beat)
- Slice at 1/2 beat → 16 slices (eighth notes)
- Slice at 1/4 beat → 32 slices (sixteenth notes)

---

## Slice to Pattern Sequencer

**Keybindings:**
- `Global:Paketti:Create Pattern Sequencer Patterns based on Slice Count with Automatic Slice Printing` ⌨️
- `Global:Paketti:Slice to Pattern Sequencer Dialog...` ⌨️

**Menu:**
- `Pattern Sequencer:Paketti Gadgets:Slice to Pattern Sequencer Dialog...` 📋
- `Instrument Box:Paketti:Slice to Pattern Sequencer Dialog...` 📋

Advanced pattern generator that writes slices to pattern sequencer with intelligent BPM, LPB, and pattern length configuration.

**Dialog Controls:**
- **BPM:** Set song tempo (20-999)
- **LPB:** Lines Per Beat (1-256)
- **Pattern Length:** Number of lines (1-512)
- **Real-time updates:** Changes apply immediately

**Features:**
- **Auto-spacing:** Calculates optimal slice spacing based on BPM/LPB
- **Pattern writing:** Creates notes for each slice
- **Track management:** Creates/selects appropriate track
- **Instrument mapping:** Maps slices to notes chromatically

**Process:**
1. Slice sample (any method)
2. Open Slice to Pattern Sequencer
3. Set BPM, LPB, pattern length
4. Click "Generate Pattern"
5. Slices written to pattern with proper timing

**Calculations:**
- Lines per beat = LPB
- Beats per pattern = Pattern Length / LPB
- Slice spacing = (Pattern Length / Number of Slices)

**Use Cases:**
- **Instant drum patterns:** Slice break → auto-generate pattern
- **Melodic sequencing:** Slice melody → write to pattern at tempo
- **Arrangement building:** Quick pattern creation from slices
- **Live set prep:** Generate playable patterns from one-shots

**Example:** 16 slices, LPB 4, 64-line pattern
- Slice 01 → Line 1
- Slice 02 → Line 5
- Slice 03 → Line 9
- ...creates evenly-spaced pattern

---

## Wipe&Slice&Write to Pattern

**Keybinding:**
- `Global:Paketti:Wipe&Slice&Write to Pattern` ⌨️

All-in-one pattern-based slicing workflow that clears existing slices, creates new slices mathematically based on pattern length, and writes slice notes to the pattern.

**Process:**
1. **Wipe:** Removes all existing slice markers
2. **Slice:** Divides sample into equal slices (one per pattern row, max 255)
3. **Write:** Writes slice notes to pattern sequentially

**Features:**
- Automatic slice count from pattern length
- Mathematical even distribution
- Instant pattern population
- Applies WipeSlices preferences to all samples
- Preserves original transpose
- Auto-configures interpolation (Sinc) and oversample

**Use Cases:**
- **Quick drum break sequencing:** Pattern length defines slice count
- **Instant playable breaks:** Load → slice → pattern-ready
- **Live performance prep:** Fast break setup for jamming

**Example:** 64-line pattern
- Creates 64 slices (max 255)
- Writes one slice per row
- Slice 01 → Row 1, Slice 02 → Row 2, etc.

---

## Slice Marker Management

### Add Slice Marker at Cursor
**Shortcut:** `Sample Editor:Paketti:Add Slice Marker at Cursor` ⌨️ 📋 🎹
**MIDI:** `Paketti:Add Slice Marker at Cursor` 🎹

Adds a slice marker at the current cursor position in the sample editor.

### Delete Slice Marker at Cursor
**Shortcut:** `Sample Editor:Paketti:Delete Slice Marker at Cursor` ⌨️ 📋 🎹
**MIDI:** `Paketti:Delete Slice Marker at Cursor` 🎹

Removes the slice marker closest to the cursor.

### Delete Slice Markers in Selection
**Keybindings:**
- `Sample Editor:Paketti:Delete Slice Markers in Selection` ⌨️
- `Global:Paketti:Delete Slice Markers in Selection` ⌨️

**MIDI:**
- `Paketti:Delete Slice Markers in Selection` 🎹

Removes all slice markers that fall within the current sample buffer selection range. Perfect for cleaning up unwanted slice markers in a specific region without affecting the rest of the sample.

**Workflow:**
1. Select region in sample editor
2. Trigger Delete Slice Markers in Selection
3. Only markers within selection are removed
4. Markers outside selection are preserved

### Delete All Slice Markers
**Shortcut:** `Sample Editor:Paketti:Delete All Slice Markers` ⌨️ 📋 🎹
**MIDI:** `Paketti:Delete All Slice Markers` 🎹

Removes all slice markers from the selected sample.

### Slice Marker Navigation
**Shortcuts:**
- `Sample Editor:Paketti:Go to Previous Slice` ⌨️ 🎹
- `Sample Editor:Paketti:Go to Next Slice` ⌨️ 🎹

**MIDI:**
- `Paketti:Go to Previous Slice` 🎹
- `Paketti:Go to Next Slice` 🎹

## Slice Transient Detection

### Slice (Auto-Detect Transients)
**Shortcut:** `Sample Editor:Paketti:Slice (Auto-Detect Transients)` ⌨️ 📋

**Smart Transient Detection:**
- No Beatsync: Uses default threshold
- Beatsync Enabled: Analyzes Beatsync Lines for optimal threshold

Perfect for drum loops, breaks, vocals, any rhythmic material.

### Slice with Threshold Dialog
**Shortcut:** `Sample Editor:Paketti:Slice with Threshold Dialog...` ⌨️ 📋 🎹
**MIDI:** `Paketti:Slice with Threshold Dialog` 🎹

Manual threshold control with real-time preview.

## Slice Extraction

### Slices to Instruments
**Shortcut:** `Sample Editor:Paketti:Slices to Instruments` ⌨️ 📋 🎹
**MIDI:** `Paketti:Slices to Instruments` 🎹

Creates a new instrument for each slice.

### Slices to Samples in Instrument
**Shortcut:** `Sample Editor:Paketti:Slices to Samples in Instrument` ⌨️ 📋 🎹
**MIDI:** `Paketti:Slices to Samples in Instrument` 🎹

Converts all slices to separate samples within the same instrument with keyzones.

## Beatsync & Slice Processing

### Slice & Set Beatsync Values
**Shortcut:** `Sample Editor:Paketti:Slice & Set Beatsync Values` ⌨️ 📋 🎹
**MIDI:** `Paketti:Slice & Set Beatsync Values` 🎹

All-in-one Beatsync slicer:
1. Auto-detects transients
2. Enables Beatsync
3. Calculates and sets Beatsync Lines
4. Configures slices for optimal playback

## Slice Randomization

### Randomize Selected Slice Pitch
**Shortcuts:**
- `Global:Paketti:Randomize Selected Slice Pitch x25` ⌨️ 🎹 - ±25 semitones
- `Global:Paketti:Randomize Selected Slice Pitch x12` ⌨️ 🎹 - ±12 semitones
- `Global:Paketti:Randomize Selected Slice Pitch x06` ⌨️ 🎹 - ±6 semitones
- `Global:Paketti:Randomize Selected Slice Pitch x03` ⌨️ 🎹 - ±3 semitones
- `Global:Paketti:Randomize Selected Slice Pitch x02` ⌨️ 🎹 - ±2 semitones
- `Global:Paketti:Randomize Selected Slice Pitch x01` ⌨️ 🎹 - ±1 semitone

**MIDI:** All variants available 🎹

### Randomize All Slices Pitch
**Shortcuts:**
- `Global:Paketti:Randomize All Slices Pitch x25` ⌨️ 🎹
- `Global:Paketti:Randomize All Slices Pitch x12` ⌨️ 🎹
- `Global:Paketti:Randomize All Slices Pitch x06` ⌨️ 🎹
- `Global:Paketti:Randomize All Slices Pitch x03` ⌨️ 🎹
- `Global:Paketti:Randomize All Slices Pitch x02` ⌨️ 🎹
- `Global:Paketti:Randomize All Slices Pitch x01` ⌨️ 🎹

**MIDI:** All variants available 🎹

Applies random pitch to ALL slices. Each slice gets its own random transpose.

## Slice Distribution to Pattern

### Random Slice Distribution

**Keybinding:**
- `Pattern Editor:Paketti:Random Slice Distribution` ⌨️

**MIDI:**
- `Paketti:Random Slice Distribution` 🎹

**Menu:**
- `Pattern Editor:Paketti..:Slices..:Random Slice Distribution` 📋

Distributes slices randomly across the selected track in the current pattern with equal spacing. Perfect for creating unpredictable, chaotic drum patterns from sliced breaks.

**Features:**
- Shuffles slice order using Fisher-Yates algorithm
- Equal spacing between slices
- Supports both note-based and 0Sxx effect methods
- Auto-detects when note range exceeds B-9 and uses 0Sxx

**Workflow:**
1. Load sliced instrument
2. Select track in pattern
3. Trigger Random Slice Distribution
4. Slices written in random order with equal spacing

### Equal Slice Distribution

**Keybinding:**
- `Pattern Editor:Paketti:Equal Slice Distribution` ⌨️

**MIDI:**
- `Paketti:Equal Slice Distribution` 🎹

**Menu:**
- `Pattern Editor:Paketti..:Slices..:Equal Slice Distribution` 📋

Distributes slices in sequential order across the selected track with equal spacing. Creates predictable, evenly-spaced slice playback.

**Features:**
- Maintains slice order (0, 1, 2, 3...)
- Equal spacing between slices
- Supports both note-based and 0Sxx effect methods
- Auto-detects when note range exceeds B-9 and uses 0Sxx

**Example:** 8 slices, 64-line pattern
- Spacing = 8 lines
- Slice 0 → Line 1
- Slice 1 → Line 9
- Slice 2 → Line 17
- ...creates evenly-distributed pattern

## Rhythmic Slice DrumChain

Advanced slice chain generator that takes slice timing from a sliced instrument and applies it to new samples. Creates new instruments with rhythmic patterns preserved.

### Create Rhythmic Slice DrumChain with Current Slices

**Keybindings:**
- `Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices` ⌨️
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices` ⌨️

**Menu:**
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices` 📋
- `Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices` 📋

Loads user-selected samples and chains them using the current instrument's slice timing. Each slice gets filled with a new sample truncated to match the slice duration.

**Process:**
1. Current instrument must have slices
2. User selects samples to load
3. Samples are matched to slice durations
4. New instrument created with chained sample
5. Original slice timing preserved
6. Automatic Pakettification applied

**Features:**
- Sample rate/bit depth/channel conversion
- Intelligent truncation for large samples
- Silent sample detection and skipping
- Cycling through samples if fewer than slices
- 10-frame fadeout on each slice
- Applies Paketti loader settings

### Create Rhythmic Slice DrumChain (Normalized)

**Keybindings:**
- `Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)` ⌨️
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)` 📋
- `Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)` 📋

Same as regular DrumChain but normalizes each slice independently for consistent loudness.

### Create Rhythmic Slice DrumChain from XRNI

**Keybindings:**
- `Global:Paketti:Create New Rhythmic Slice DrumChain from XRNI` ⌨️
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI` ⌨️

**Menu:**
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI` 📋
- `Instrument Box:Paketti:Create New Rhythmic Slice DrumChain from XRNI` 📋

Uses slices from a loaded XRNI file instead of user-selected samples. Cycles through XRNI slices to match current instrument's slice timing.

**Process:**
1. Current instrument must have slices
2. User selects XRNI file (must contain slices)
3. XRNI slices extracted and converted
4. Cycles through XRNI slices to fill all positions
5. New instrument created with chained sample

**Use Cases:**
- **Break variations:** Apply drum break timing to synth hits
- **Kit morphing:** Combine different kit slice timings
- **Texture layering:** Apply vocal slice timing to FX samples

### Create Rhythmic Slice DrumChain from XRNI (Normalized)

**Keybindings:**
- `Global:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)` ⌨️
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)` 📋
- `Instrument Box:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)` 📋

Same as XRNI DrumChain but normalizes each slice independently.

### Create Rhythmic Slice DrumChain (Randomize)

**Keybindings:**
- `Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)` ⌨️
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)` 📋
- `Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)` 📋

Randomly selects samples from a folder instead of user selection. Uses Fisher-Yates shuffle for true randomization.

**Process:**
1. Current instrument must have slices
2. User selects folder
3. All audio files found recursively
4. Files randomized using Fisher-Yates
5. Random samples matched to slice durations
6. New instrument created

**Features:**
- Recursive folder scanning
- True random shuffle (not pseudo-random)
- Silent sample detection and skipping
- Automatic cycling if fewer files than slices

**Use Cases:**
- **Instant variety:** Create multiple variations from same timing
- **Sample pack exploration:** Quick audition of folder contents
- **Happy accidents:** Discover unexpected combinations

### Create Rhythmic Slice DrumChain (Randomize) (Normalized)

**Keybindings:**
- `Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)` ⌨️
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)` 📋
- `Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)` 📋

Same as Randomize DrumChain but normalizes each slice independently.

**Technical Details:**
- Preserves slice timing frame-accurately
- Converts sample formats automatically (rate/depth/channels)
- Applies WipeSlices preferences
- Intelligently truncates large samples
- Chunked processing for performance
- 10-frame fadeout prevents clicks

## Auto-Slice & Kit Creation

### Custom Auto-Slice Kit
**Shortcut:** `Global:Paketti:Custom Auto-Slice Kit` ⌨️ 📋
**Menu:** `Main Menu:File:Load:Custom Auto-Slice Kit...` 📋

Batch slicing workflow:
1. Select folder of audio files
2. Load each file as instrument
3. Auto-detect transients and create slices
4. Configure Beatsync for each instrument

# Samples and Instruments

← [Back to Main Manual](README.md)

This section covers all Paketti features related to Sample and Instrument management, manipulation, and configuration.

## Table of Contents
1. [Sample Loop Settings](#sample-loop-settings)
2. [Sample Transpose & Pitch](#sample-transpose--pitch)
3. [Sample Panning & Volume](#sample-panning--volume)
4. [Sample Playback Quality](#sample-playback-quality)
5. [Sample Beatsync](#sample-beatsync)
6. [Sample Behavior Settings](#sample-behavior-settings)
7. [Sample New Note Action](#sample-new-note-action-nna)
8. [Sample Mute Groups](#sample-mute-groups)
9. [Slice Settings](#slice-settings)
10. [Instrument-Level Operations](#instrument-level-operations)
11. [Track Volume Control](#track-volume-control)
12. [Output Routing](#output-routing)
13. [Studio Session Workflow](#studio-session-workflow)
14. [LPB Control](#lpb-control)

## Sample Loop Settings

### Set Selected Sample Loop Release On/Off
**Shortcut:** `Global:Paketti:Set Selected Sample Loop Release On/Off`

### Set Selected Sample One-Shot On/Off
**Shortcut:** `Global:Paketti:Set Selected Sample One-Shot On/Off`

### Set Selected Sample Loop Mode
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Loop 1 (Off)`
- `Global:Paketti:Set Selected Sample Loop 2 (Forward)`
- `Global:Paketti:Set Selected Sample Loop 3 (Backward)`
- `Global:Paketti:Set Selected Sample Loop 4 (PingPong)`

## Sample Transpose & Pitch

### Sample Transpose
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Transpose (-1)` - Decrease by 1 semitone
- `Global:Paketti:Set Selected Sample Transpose (+1)` - Increase by 1 semitone
- `Global:Paketti:Set Selected Sample Transpose (-12)` - Decrease by 1 octave
- `Global:Paketti:Set Selected Sample Transpose (+12)` - Increase by 1 octave
- `Global:Paketti:Selected Sample Transpose (0)` - Reset to 0

Range: -120 to +120 semitones.

### Sample Finetune
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Finetune (-1)` - Decrease by 1
- `Global:Paketti:Set Selected Sample Finetune (+1)` - Increase by 1
- `Global:Paketti:Set Selected Sample Finetune (-10)` - Decrease by 10
- `Global:Paketti:Set Selected Sample Finetune (+10)` - Increase by 10
- `Global:Paketti:Set Selected Sample Finetune (0)` - Reset to 0

Range: -127 to +127.

## Sample Panning & Volume

### Sample Panning
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Panning 0.5 (Center)` - Center
- `Global:Paketti:Set Selected Sample Panning 0.0 (Left)` - Hard left
- `Global:Paketti:Set Selected Sample Panning 1.0 (Right)` - Hard right
- `Global:Paketti:Set Selected Sample Panning (+0.01)` - Nudge right
- `Global:Paketti:Set Selected Sample Panning (-0.01)` - Nudge left

Range: 0.0 (left) to 1.0 (right).

### Sample Volume
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Volume (+0.01)` - Increase
- `Global:Paketti:Set Selected Sample Volume (-0.01)` - Decrease
- `Global:Paketti:Set Selected Sample Volume Reset (0.0dB)` - Unity gain

Range: 0.0 to 4.0 (0.0dB = 1.0).

## Sample Playback Quality

### Interpolation Mode
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Interpolation to 1 (None)`
- `Global:Paketti:Set Selected Sample Interpolation to 2 (Linear)`
- `Global:Paketti:Set Selected Sample Interpolation to 3 (Cubic)`
- `Global:Paketti:Set Selected Sample Interpolation to 4 (Sinc)` - Highest quality

### Oversample
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Oversample On`
- `Global:Paketti:Set Selected Sample Oversample Off`
- `Global:Paketti:Set Selected Sample Oversample On/Off` - Toggle

## Sample Beatsync

### Beatsync Mode
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Beatsync 1 (Repitch)`
- `Global:Paketti:Set Selected Sample Beatsync 2 (Time-Stretch Percussion)`
- `Global:Paketti:Set Selected Sample Beatsync 3 (Time-Stretch Texture)`

### Beatsync Mode with Toggle
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Beatsync On/Off 1 (Repitch)`
- `Global:Paketti:Set Selected Sample Beatsync On/Off 2 (Time-Stretch Percussion)`
- `Global:Paketti:Set Selected Sample Beatsync On/Off 3 (Time-Stretch Texture)`

### Beatsync Enable/Disable
**Shortcut:** `Global:Paketti:Set Selected Sample Beatsync On/Off`

### Beatsync Lines
**Shortcuts:**
- `Global:Paketti:Set Selected Sample Beatsync Line (+1)` ⌨️
- `Global:Paketti:Set Selected Sample Beatsync Line (-1)` ⌨️
- `Global:Paketti:Set Selected Sample Beatsync Line (Power of Two Above)` ⌨️
- `Global:Paketti:Set Selected Sample Beatsync Line (Power of Two Below)` ⌨️
- `Global:Paketti:Double Beatsync Line` ⌨️ 📋
- `Global:Paketti:Halve Beatsync Line` ⌨️ 📋

Range: 1-512 lines.

## Sample Behavior Settings

### Autofade
**Shortcut:** `Global:Paketti:Set Selected Sample Autofade On/Off`

### Autoseek
**Shortcut:** `Global:Paketti:Set Selected Sample Autoseek On/Off`

## Sample New Note Action (NNA)

**Shortcuts:**
- `Global:Paketti:Set Selected Sample NNA to 1 (Cut)` ⌨️
- `Global:Paketti:Set Selected Sample NNA to 2 (Note-Off)` ⌨️
- `Global:Paketti:Set Selected Sample NNA to 3 (Continue)` ⌨️

### Set All Instruments Samples NNA to Cut
**Shortcut:** `Global:Paketti:Set All Instruments Samples NNA to Cut` ⌨️ 📋
**Menu:** `Main Menu:Tools:Paketti:Instruments:Set All Instruments Samples NNA to Cut` 📋

## Sample Mute Groups

**Shortcuts:**
- `Global:Paketti:Set Selected Sample Mute Group to 0 (Off)`
- `Global:Paketti:Set Selected Sample Mute Group to 1` through `9`
- `Global:Paketti:Set Selected Sample Mute Group to A` through `F`

## Slice Settings

### Slice Drumkit (Percussion)
**Shortcut:** `Sample Editor:Paketti:Slice Drumkit (Percussion)` ⌨️

Optimized settings: Beatsync enabled (Percussion), Forward loop, Mute group 1, Autoseek on.

### Slice Drumkit (Texture)
**Shortcut:** `Sample Editor:Paketti:Slice Drumkit (Texture)` ⌨️

Optimized settings: Beatsync enabled (Texture), Forward loop, Mute group 1, Autoseek on.

## Instrument-Level Operations

### Transpose Dialog
**Shortcuts:**
- `Global:Paketti:Paketti Instrument Transpose Dialog...` ⌨️ 📋
**Menu:** `Instrument Box:Paketti:Transpose Dialog...` 📋

### Global Volume Adjustment Dialog
**Shortcut:** `Global:Paketti:Paketti Global Volume Adjustment...` ⌨️ 📋
**Menu:** `Instrument Box:Paketti Gadgets:Paketti Global Volume Adjustment...` 📋

### Duplicate and Reverse Instrument
**Shortcut:** `Global:Paketti:Duplicate and Reverse Instrument` ⌨️ 📋
**MIDI:** `Paketti:Duplicate and Reverse Instrument` 🎹

### Duplicate All Samples with Transpose
**Shortcuts:**
- `Global:Paketti:Duplicate All Samples at -36 Transpose` ⌨️ 📋
- `Global:Paketti:Duplicate All Samples at -24 Transpose` ⌨️ 📋
- `Global:Paketti:Duplicate All Samples at -12 Transpose` ⌨️ 📋
- `Global:Paketti:Duplicate All Samples at +12 Transpose` ⌨️ 📋
- `Global:Paketti:Duplicate All Samples at +24 Transpose` ⌨️ 📋
- `Global:Paketti:Duplicate All Samples at +36 Transpose` ⌨️ 📋

## Track Volume Control

### Selected Track Volume
**Shortcuts:**
- `Global:Paketti:Set Selected Track Volume to -INF dB`
- `Global:Paketti:Set Selected Track Volume to 0.0dB`

### Master Track Volume
**Shortcuts:**
- `Global:Paketti:Set Master Track Volume to -INF dB`
- `Global:Paketti:Set Master Track Volume to 0.0dB`
- `Global:Paketti:Change Master Track Volume by +0.1dB`
- `Global:Paketti:Change Master Track Volume by -0.1dB`

Range: -INF to +3.0dB.

## Output Routing

### Cycle Output Routing
**Shortcuts:**
- `Global:Paketti:Selected Track Output Routing +1`
- `Global:Paketti:Selected Track Output Routing -1`
- `Global:Paketti:Master Track Output Routing +1`
- `Global:Paketti:Master Track Output Routing -1`

**MIDI Mappings:**
- `Paketti:Selected Track Output Routing +1 x[Trigger]`
- `Paketti:Master Track Output Routing +1 x[Trigger]`

### Direct Output Routing Selection
**Shortcuts:** (00-63 available)
- `Global:Paketti:Set Selected Track Output Routing 00` through `63`
- `Global:Paketti:Set Master Track Output Routing 00` through `63`

## Studio Session Workflow

### Selected Track to Mono and Hard Pan
**Shortcuts:**
- `Global:Paketti:Selected Track to Mono and Hard Left` - Mono sum, pan hard left
- `Global:Paketti:Selected Track to Mono and Hard Right` - Mono sum, pan hard right

**MIDI:**
- `Paketti:Selected Track to Mono and Hard Left`
- `Paketti:Selected Track to Mono and Hard Right`

Inserts Mono device (Stereo Expander) and sets hard panning for dual-mono studio setups.

### Master Track to Mono and Hard Pan
**Shortcuts:**
- `Global:Paketti:Master Track to Mono and Hard Left`
- `Global:Paketti:Master Track to Mono and Hard Right`

**MIDI:**
- `Paketti:Master Track to Mono and Hard Left`
- `Paketti:Master Track to Mono and Hard Right`

## LPB (Lines Per Beat) Control

### Double/Halve LPB
**Shortcuts:**
- `Global:Paketti:Double LPB` - Multiply by 2
- `Global:Paketti:Halve LPB` - Divide by 2
- `Global:Paketti:Double Double LPB` - Multiply by 4
- `Global:Paketti:Halve Halve LPB` - Divide by 4

Constraints: LPB 1-256, halving only works with even values.

---

# Generative Tools

## Musical Chord Progression Arpeggiator

**Source:** `PakettiArpeggiator.lua` | **Inspired by Jake Albaugh's CodePen**

Advanced musical arpeggiator with chord progression composer, real-time playback, and pattern writing. Features per-chord modal interchange, visual pattern preview, and intelligent chord detection from existing patterns.

### Opening the Arpeggiator

**Shortcuts:**
- `Global:Paketti:Musical Chord Progression Arpeggiator...` ⌨️
- `Pattern Editor:Paketti Gadgets:Musical Chord Progression Arpeggiator...` 📋

**MIDI:** `Paketti:Musical Chord Progression Arpeggiator...` 🎹

**Menu:**
- `Main Menu:Tools:Paketti Gadgets:Musical Chord Progression Arpeggiator...` 📋
- `Pattern Editor:Paketti Gadgets:Musical Chord Progression Arpeggiator...` 📋

### Musical Features

**Supported Scales & Modes:**
- **Church Modes:** Ionian, Dorian, Phrygian, Lydian, Mixolydian, Aeolian, Locrian
- **Standard:** Major, Minor
- **Advanced:** Melodic Minor, Harmonic Minor

**Automatic Triad Generation:**
- Major (maj), Minor (min), Diminished (dim), Augmented (aug)
- Triads generated automatically based on scale degree
- Roman numeral notation (I, II, III, IV, V, VI, VII)

**Per-Chord Modal Interchange:**
- Each of 8 chord positions can have its own mode
- Allows complex harmonic progressions (e.g., position 1=Ionian, position 5=Mixolydian)
- Creates modal mixture and borrowing

### Arpeggio Pattern Engine

**Pattern Types:**
- **Straight:** All permutations of step order (e.g., 0123, 0132, 0213...)
- **Looped:** Straight pattern + reverse (e.g., 0123210)

**Steps:** 3-6 notes per arpeggio

**Visual Pattern Preview:**
- 15x canvas visualizations per row
- Orange highlighting for selected pattern
- Clickable pattern selection

### Playback Modes

**Space Bar - Next Chord Preview:**
- Plays one chord with bass note + arpeggiated notes
- Advances through 8-chord progression
- Automatic note-off after arpeggio completes

**Shift+Space - Continuous Playback:**
- Plays entire 8-chord progression in loop
- Real-time button highlighting (deep purple)
- Continues until stopped or ESC pressed

**BPM Options:**
- Current (uses song BPM)
- Fixed: 45, 60, 75, 90, 105, 120, 135, 150

**Timing:**
- Synchronized to song LPB
- Each arpeggio step is fraction of one line
- Capped to 16 steps maximum for performance

### Chord Progression Composer

**8-Position Grid:**
- 8 vertical columns (one per chord position)
- 7 buttons per column (I-VII scale degrees)
- Click to change chord at that position
- Clicking plays preview of that chord

**Live Editing During Playback:**
- Change chords while continuous playback is running
- Immediately updates harmonic progression
- No dialog rebuild required

**Default Progression:** I-III-VII-IV-V-III-VI-II

### Read from Pattern

**Intelligent Chord Detection:**
- Scans selected track (or specified track number)
- Detects key AND mode simultaneously
- Identifies chord progressions by matching:
  - Bass notes (lowest note in chord)
  - Triad tones (root, third, fifth matching)
  - Diatonic extensions (scale tones)
  - Out-of-scale notes (penalties)

**Works with:**
- Multi-column chords (reads all visible note columns)
- Slash chords and inversions (uses tonal center detection)
- Complex voicings (scores all chord tones)

**Track Selection:**
- Read from Current Track button
- Read Track valuebox (specify track 1-N)
- Read button (analyze and import)

### Write to Pattern

**Smart Pattern Writing:**
- Writes 8 chords to pattern starting at cursor
- 2 lines per chord (note-ons + note-offs)
- Automatically adjusts visible note columns
- Enables delay column for timing

**Delay Column Arpeggio:**
- Calculates 256-tick delay increments
- Each note in different column with precise delay
- Creates arpeggiated effect within single line

**Requirements:**
- Sequencer track selected
- Sufficient pattern lines (16 minimum for 8 chords)

### Key Handler

**ESC:** Stop all playback, close dialog (or just stop if playing)
**Space:** Next chord preview
**Shift+Space:** Toggle continuous playback

### Technical Details

**Performance Optimizations:**
- No dialog rebuilds during playback
- Real-time button color updates without reconstruction
- 40ms highlight timer (25fps)
- Unique note deduplication prevents crashes

**Note Handling:**
- Bass note one octave below chord root
- Arpeggio notes extend across multiple octaves
- Octave base adjustable (default: 4)
- MIDI note-on/note-off with velocity control

### Use Cases

**Composition:**
- Explore chord progressions quickly
- Test modal interchange ideas
- Generate harmonic frameworks

**Live Performance:**
- Play arpeggiated backing tracks
- Real-time chord switching
- Improvise over generated progressions

**Learning:**
- Study scale-chord relationships
- Understand modal harmony
- Visualize arpeggio patterns

---

## Paketti Gater

**Source:** `PakettiGater.lua`

Advanced 16/32-step gate sequencer with per-step note/volume/panning/retrig control, visual grid editor, and intelligent pattern writing.

### Opening the Gater

**Shortcuts:**
- `Global:Paketti:Paketti Gater Dialog...` ⌨️

**MIDI:**
- `Paketti:Paketti Gater Dialog...` 🎹 (Toggle dialog)
- `Paketti:Paketti Gater:Toggle Step Mode (16/32)` 🎹 (Switch 16↔32 steps)

### Step Grid Interface

**16 or 32 Steps:**
- Switch between 16-step and 32-step modes
- Each step represents one line in pattern
- Visual checkbox grid for easy editing

**Per-Step Controls:**
1. **On/Off Checkbox** - Enable/disable step
2. **Note Selector** - Choose pitch for this step
3. **Volume Control** - Set step volume (00-80 hex)
4. **Panning Control** - Left/Center/Right per step
5. **Retrig Control** - Retriggering effect per step

### Panning System

**Panning Intensity Slider (0-100%):**
- Adjusts stereo width globally
- Updates existing pattern data in real-time
- Affects both Panning Column and 0P FX commands

**Panning Column Format:**
- Left: 00-3F
- Center: 40
- Right: 41-80

**FX Column Format (0P command):**
- Left: 00-7F
- Right: 80-FF

**Real-Time Updates:**
- Changing intensity recalculates all panning values in current pattern
- Scans and replaces old panning with new values
- Shows count of updated values

### Retrig System

**Retrig Options:** 1-9 retrigs per step
- Uses Renoise Panning Column retrig format: R1-R9
- Pattern Editor displays as R1, R2, etc.
- Creates rhythmic subdivisions within step

### Pattern Writing Modes

**Write Note Column:**
- Writes to note columns only
- Volume column for step volumes
- Panning column for panning/retrig

**Write FX Column:**
- Writes notes + volumes to note columns
- Uses Effect Column for panning (0P command)
- Better for complex effect chain routing

**Randomize Feature:**
- Randomizes all enabled steps
- Random notes, volumes, panning
- Maintains step on/off state

### Grid Visualization

**25fps Update Rate:**
- Real-time visual feedback
- Smooth cursor tracking
- Responsive UI without performance impact

### Note Range

**Available Notes:**
- C-0 through B-9 (full MIDI range)
- Dropdown selector per step
- Easy octave/note selection

### Use Cases

**Rhythmic Gating:**
- Create gated synth patterns
- Tremolo/volume patterns
- Rhythmic automation

**Melodic Sequencing:**
- Step-based melody writing
- Bassline patterns
- Lead sequences

**Euclidean Rhythms:**
- Enable specific steps for rhythmic patterns
- Retrig for hi-hat patterns
- Panning for stereo movement

**Live Performance:**
- Quick pattern generation
- Real-time randomization
- MIDI-mappable toggle

---

## Enhanced Phrase Generator

**Source:** `PakettiPhraseGenerator.lua` | **Depends on:** `PakettiSteppers.lua`

Comprehensive phrase creation tool with 28 musical scales, multiple rhythm patterns, note ordering options, and stepper-based editing interface.

### Opening the Generator

**Shortcut:** `Global:Paketti:Paketti Enhanced Phrase Generator` ⌨️

### Musical Scales (28 Total)

**Western Scales:**
- All Notes, Minimal (C Major), Chromatic
- Major, Natural Minor, Harmonic Minor, Melodic Minor
- Pentatonic, Blues

**Modal Scales:**
- Dorian, Phrygian, Lydian, Mixolydian, Locrian

**Exotic Scales:**
- Whole Tone, Diminished
- Persian, Japanese, Gamelan
- Hungarian, Romanian, Spanish
- Enigmatic, Neapolitan, Prometheus
- Algerian, Blue1, Blue2

**Scale Display:**
- Full scale name shown
- Root note adjustable via transpose
- Notes displayed in Renoise notation (c-4, d-4, etc.)

### Note Ordering Options

**Available Orders:**
1. **Random** - Unpredictable melodic patterns
2. **Ascending** - Low to high
3. **Descending** - High to low
4. **Ascending + Random** - Mix of both
5. **Descending + Random** - Mix of both

**Status Display:**
- Current order shown in dialog
- Real-time updates when changed

### Rhythm Patterns

**Rhythm Units:** 1/1, 1/2, 1/4, 1/8, 1/16, 1/32, 1/64

**Pattern Types:**
- Straight (even rhythm)
- Dotted (swing feel)
- Triplet (3-feel)
- Custom patterns via stepper interface

### Stepper Integration

**Shared with PakettiSteppers.lua:**
- DRY (Don't Repeat Yourself) approach
- Modifications in PakettiSteppers automatically appear here
- Consistent UI across tools

**Stepper Features:**
- Visual grid for note/rhythm editing
- Per-step enable/disable
- Multiple rhythm patterns
- Copy/paste patterns

---
> *28 scales, modal interchange, arpeggiators, gaters, phrase generators — these generative tools exist because of community support.*
> *[Join supporters on Patreon →](http://patreon.com/esaruoho)*
---

### Phrase Creation

**Auto-Initialization:**
- Creates new phrase if none exists
- Applies Paketti phrase settings
- Sets appropriate length based on rhythm unit

**Phrase Settings:**
- Custom naming
- Autoseek configuration
- Column visibility
- Note/effect column counts
- LPB and length
- Looping mode

### Transpose Control

**Range:** -120 to +120 semitones

**Safe Transpose:**
- Clamped to valid MIDI range
- No crashes from extreme values
- Affects entire phrase

**Instrument-Level:**
- Changes root pitch of scale
- All generated notes transposed accordingly

### Generation Process

1. **Select Scale** - Choose from 28 options
2. **Choose Order** - How notes are arranged
3. **Set Rhythm** - Pick timing pattern
4. **Configure Stepper** - Fine-tune individual steps
5. **Generate** - Creates phrase in current instrument
6. **Edit** - Modify using phrase editor

### Advanced Features

**Future-Proof Design:**
- Variables for phrase script syntax
- Pattern field/event field/unit field abstraction
- Return type configuration

**Instrument Switching Protection:**
- Detects rapid instrument changes
- Prevents conflicts during generation
- Safe transpose handling

### Use Cases

**Quick Phrase Creation:**
- Generate melodic patterns instantly
- Test different scales
- Rapid prototyping

**Algorithmic Composition:**
- Random note orders for inspiration
- Combine scales with rhythms
- Generate variations

**Learning Tool:**
- Explore exotic scales
- Understand modal harmony
- Study rhythmic patterns

**Live Performance:**
- Quick phrase generation on-the-fly
- Change scales mid-performance
- Generate backing patterns

---

## Paketti Preferences

**Source:** `Paketti0G01_Loader.lua`

**Shortcut:** `Global:Paketti:Show Paketti Preferences...` ⌨️

Central configuration dialog for all Paketti features. Contains hundreds of preferences organized by category.

### Preference Categories

**Sample Processing:**
- RePitch Enhanced mode toggle
- Waveform writer hex mode
- Auto disk browser behavior

**Stepper Configuration:**
- Global step count (16/32/64)
- Default stepper behaviors

**Tuning System:**
- User-defined tunings
- Auto input tuning
- Custom tuning files

**UI Preferences:**
- Minimized pitch control
- Column widths
- Spacing adjustments

**Gater Settings:**
- Panning intensity default
- Grid visualization options

**Polyend Integration:**
- Polyend root path
- Local backup paths
- Use local backup toggle

**External Tools:**
- eSpeak executable paths (Windows/Mac/Linux)
- Sample rate preferences (22050-192000 Hz)
- Filter type defaults

**Plugin/Device Paths:**
- Custom VST/AU plugin paths
- Favorite devices
- Device chain templates

### Preference Storage

**Document-Based:**
- ObservableString/ObservableNumber types
- Real-time updates across Paketti
- Persistent across Renoise sessions

**Plugin Entry Management:**
- Add/remove custom plugins
- Define device paths
- Organize favorites

**Filter Presets (22 types):**
- **Low-Pass:** LP Clean, LP K35, LP Moog, LP Diode
- **High-Pass:** HP Clean, HP K35, HP Moog, HP SVF
- **Band-Pass:** BP 2 Pole, BP 4 Pole, BP Moog, BP SVF
- **Notch:** Notch
- **Comb:** Comb+, Comb-, Comb+ Flt, Comb- Flt
- **Effects:** Decimator, Distortion, Ringmod, AM Sine, AM Triangle

### Integration

**All Paketti Tools:**
- Preferences affect all features
- Consistent behavior across dialogs
- Global defaults

**Platform-Specific:**
- Windows/Mac/Linux path detection
- Appropriate executable defaults
- Cross-platform compatibility

---

## Paketti Wonkify

**Source:** `PakettiWonkify.lua`

Advanced pattern variation generator with reproducible randomization. Creates "wonky" variations of patterns by applying controlled random modifications to timing, pitch, velocity, and note density. Supports multi-pattern chain generation for creating evolving arrangements.

### Opening Wonkify

**Shortcuts:**
- `Global:Paketti:Wonkify Dialog` ⌨️
- `Pattern Editor:Paketti:Wonkify Dialog` ⌨️
- `Pattern Sequencer:Paketti:Wonkify Dialog` ⌨️
- `Pattern Matrix:Paketti:Wonkify Dialog` ⌨️

**MIDI:** `Paketti:Wonkify Dialog` 🎹

**Menu:**
- `Pattern Editor:Paketti:Pattern:Wonkify Settings...` 📋
- `Pattern Matrix:Paketti:Wonkify Settings...` 📋
- `Pattern Sequencer:Paketti:Wonkify Settings...` 📋
- `Main Menu:Tools:Paketti:Pattern Editor:Wonkify Settings...` 📋

### Core Operations

**Wonkify Current Pattern:**
- Applies modifications to the current pattern in-place
- All enabled effects are applied based on percentage settings
- `Global:Paketti:Wonkify Current Pattern` ⌨️
- `Paketti:Wonkify Current Pattern` 🎹

**Duplicate and Wonkify:**
- Creates a new pattern (finds first empty pattern not in sequence)
- Copies current pattern content to new pattern
- Applies wonkification to the duplicate
- Jumps to the new pattern
- `Global:Paketti:Duplicate & Wonkify Pattern` ⌨️
- `Paketti:Duplicate & Wonkify Pattern` 🎹

**Generate Chain:**
- Creates multiple wonkified patterns in sequence
- Each new pattern is a variation of the previous one
- Uses incrementing random seeds for different variations
- Pattern count configurable (1-16)
- `Global:Paketti:Wonkify Generate Chain` ⌨️
- `Paketti:Wonkify Generate Chain` 🎹

### Random Seed System

**Reproducible Results:**
- Set a numeric seed (1-999999) for consistent "random" variations
- Same seed + same settings = identical output every time
- Enable/disable seed usage with checkbox
- "New" button generates a fresh random seed

**Use Cases:**
- Share exact variations with collaborators
- Return to a specific variation you liked
- A/B compare different seed values
- Chain generation auto-increments seed for variety

### Rhythm Modifications

**Delay Drift (Micro-timing):**
- Shifts notes within the same row using delay column (0-255 ticks)
- Percentage: How many notes to affect (0-100%)
- Max Ticks: Maximum drift amount (+/-)
- Automatically shows delay column when used

**Row Drift (Position Swap):**
- Swaps note positions between different rows
- Creates rhythmic displacement
- Percentage: How many notes to move (0-100%)
- Max Rows: Maximum rows to shift (+/-)

### Pitch and Velocity

**Pitch Drift:**
- Shifts notes by semitones (+/-)
- Percentage: How many notes to affect
- Max Semitones: Maximum shift amount (1-12)
- Track Selection: Comma-separated track numbers, or empty for all tracks
- Useful for melodic variation while preserving drums

**Velocity Variation:**
- Changes note volume by percentage of original value
- Percentage: How many notes to affect
- Max Change: Maximum variation (+/- percent)
- Creates humanized dynamics
- Automatically shows volume column

### Note Density

**Add Notes:**
- Randomly adds notes to empty positions
- Notes are copied from existing notes in the pattern
- Preserves instrument assignments
- Percentage: Chance to add a note to each empty cell

**Remove Notes:**
- Randomly removes existing notes
- Percentage: Chance to remove each note
- Creates sparser patterns
- Good for breakdown/buildup sections

### Ghost Notes (Rolls)

**Roll Creation:**
- Adds velocity-faded ghost notes before or after existing notes
- Creates drum rolls, note trails, and build-ups

**Settings:**
- Ghost Count: Number of ghost notes per original (1-4)
- Direction: Build-up (before) or Trail-off (after)
- Volume Start: Starting velocity percentage
- Volume End: Ending velocity percentage
- Linear interpolation between start and end

**Build-up Mode:**
- Places ghosts on rows before the note
- Volume increases toward the original note
- Creates anticipation/tension

**Trail-off Mode:**
- Places ghosts on rows after the note
- Volume decreases from the original note
- Creates echo/decay effect

### Retrig Effects

**0Rxx Command Insertion:**
- Randomly adds retrigger effects to notes
- Percentage: Chance to add retrig
- Min/Max: Range of retrig values
- Column Choice: Effect Column or Sample FX Column

### Preferences

All settings are saved in Paketti preferences:
- Enable/disable each effect type independently
- All percentage and range values persist
- Random seed is remembered between sessions
- Pattern count for chain generation

### Dialog Interface

**Organized Sections:**
1. Generation Settings (seed, pattern count)
2. Rhythm (delay drift, row drift)
3. Pitch (with track selector)
4. Velocity
5. Density (add/remove)
6. Ghost Notes
7. Retrig

**Action Buttons:**
- Wonkify Current - Apply to current pattern
- Duplicate and Wonkify - Create new pattern with variations
- Generate Chain - Create multiple chained variations

### Creative Uses

**Drum Variations:**
- Use delay drift for humanized timing
- Ghost notes for fills and rolls
- Velocity variation for dynamics
- Disable pitch drift on drum tracks

**Melodic Evolution:**
- Pitch drift for subtle note changes
- Row drift for rhythmic variation
- Chain generation for song sections

**Breakdown/Buildup:**
- Density remove for sparse breakdowns
- Density add for busy sections
- Ghost trail-off for decay effects
- Ghost build-up for tension

**Sound Design:**
- High drift values for glitchy effects
- Retrig for stuttering textures
- Combine all effects for chaos

---

## Paketti Clipboard

**Source:** `PakettiClipboard.lua` | **Features:** 20+

Multi-slot clipboard system for Renoise with Cut, Copy, Paste, Flood Fill, and advanced operations. Supports both Pattern Editor and Phrase Editor with 10 numbered clipboard slots.

### Main Dialog

**Keybinding:** `Global:Paketti:Clipboard Dialog...` ⌨️

Opens the Paketti Clipboard dialog with visual slot management, status display, and operation buttons.

### Core Operations

**Copy to Slot (01-10):**
- `Pattern Editor:Paketti:Clipboard:Copy to Slot 01` through `10` ⌨️
- Copies selection or current row (if no selection) to numbered slot
- Preserves note columns, effect columns, and all data
- Works in Pattern Editor and Phrase Editor

**Cut to Slot (01-10):**
- `Pattern Editor:Paketti:Clipboard:Cut to Slot 01` through `10` ⌨️
- Copies selection to slot and clears original content
- Uses proper empty values (---, .., 00)

**Paste from Slot (01-10):**
- `Pattern Editor:Paketti:Clipboard:Paste from Slot 01` through `10` ⌨️
- Pastes slot content at cursor position
- Respects visible column settings

### Smart Paste Behavior (NEW - Jan 2026)

**Preserve Notes on Effects-Only Paste:**
- When pasting clipboard that contains only effects (no notes)
- Existing notes are NOT overwritten
- Only effect column data is pasted
- Allows layering effects onto existing patterns

**Preserve Effects on Notes-Only Paste:**
- Similar logic in reverse
- Only writes note data when clipboard has notes
- Existing effect data preserved

### Flood Fill

**Paste & Flood Fill (01-10):**
- `Pattern Editor:Paketti:Clipboard:Paste & Flood Fill from Slot 01` through `10` ⌨️
- Pastes content repeatedly from cursor to end of pattern/selection
- Useful for quick drum pattern generation
- Respects selection boundaries if active

### Inverse Cut (Solo Selection) (NEW - Jan 2026)

**Keybinding:** `Pattern Editor:Paketti:Clipboard:Inverse Cut (Solo Selection)` ⌨️

Cuts all content from OTHER tracks while preserving the selected track's content.

**How It Works:**
1. Select content on a track (or make a selection)
2. Trigger Inverse Cut
3. All OTHER tracks within the same row range are cut
4. Preserved tracks remain untouched
5. Cut content stored for later restoration

**Inverse Paste:**
- `Pattern Editor:Paketti:Clipboard:Inverse Paste` ⌨️
- Restores previously inverse-cut content
- Returns other tracks to their original state

**Use Cases:**
- Quickly solo a track for breakdown sections
- Create variations with isolated elements
- Non-destructive with restore capability

### Cursor Row Operations

**If No Selection:**
- Copy/Cut operations work on current row, current note column
- Allows single-note clipboard operations
- Quick capture without making selections

### Phrase Editor Support

All clipboard operations work in Phrase Editor:
- Same slot system (01-10)
- Same copy/cut/paste logic
- Same flood fill behavior
- Wonkify presets also work in phrases

### MIDI Mappings

- `Paketti:Clipboard Copy Slot 01` through `10` 🎹
- `Paketti:Clipboard Cut Slot 01` through `10` 🎹
- `Paketti:Clipboard Paste Slot 01` through `10` 🎹
- `Paketti:Clipboard Paste & Flood Fill Slot 01` through `10` 🎹

### Use Cases

**Quick Pattern Building:**
1. Copy a bar of drums to Slot 01
2. Flood fill to create 8-bar pattern
3. Copy variation to Slot 02
4. Mix and match slots

**Live Sampling:**
1. Copy interesting sections as they play
2. Paste and rearrange in real-time
3. Use multiple slots for different elements

**Phrase Construction:**
1. Copy pattern data to slot
2. Switch to Phrase Editor
3. Paste into phrase
4. Apply Wonkify for variation

---

## Wonkify Clipboard

**Source:** `PakettiClipboard.lua`

Wonkify Clipboard applies the same humanization and variation effects as Wonkify Pattern, but operates on Paketti's internal clipboard system during paste operations rather than modifying patterns directly. This provides a non-destructive workflow where you can paste the same clipboard content multiple times with different transformations applied each time.

### How It Works

1. **Copy pattern data** to a Paketti clipboard slot (Slots 01-20)
2. **Choose a Wonkify preset** when pasting
3. **Transformations are applied on-the-fly** during the paste operation
4. The original clipboard data remains unchanged for reuse

### Wonkify Clipboard vs Wonkify Pattern

| Feature | Wonkify Pattern | Wonkify Clipboard |
|---------|-----------------|-------------------|
| **Operation** | Modifies patterns directly | Transforms during paste |
| **Source** | Current pattern or selection | Clipboard slot data |
| **Destructive** | Yes (changes pattern in-place) | No (clipboard unchanged) |
| **Undo** | Standard undo | Don't paste if unwanted |
| **Settings** | Full dialog with all parameters | Preset-based (7 presets) |
| **Chain Generation** | Yes (multiple pattern variations) | No |
| **Best For** | Comprehensive editing, chains | Quick variations, experimentation |

### Available Presets

All seven presets match the built-in Wonkify Pattern presets:

| Preset | Description | Effects Applied |
|--------|-------------|-----------------|
| **Humanized** | Subtle, natural feel | Light delay drift (25%), velocity variation (40%) |
| **Drunk** | Loose, wobbly timing | Heavy delay drift (50%), velocity variation, row drift |
| **Lo-Fi** | Gritty, degraded feel | Delay drift (20%), heavy velocity variation (60%) |
| **Glitchy** | Stuttered, broken timing | Row drift only (35%), position swapping |
| **Chaos** | Maximum variation | All effects: delay, velocity, pitch, row drift |
| **Jazz** | Swung, dynamic feel | Delay drift (30%), velocity variation (45%) |
| **Tight** | Minimal micro-timing | Small delay drift only (8 ticks max) |

### Pattern Editor Keybindings

**Wonkify Paste from Slot 01:**
- `Pattern Editor:Paketti:Clipboard:Wonkify:Humanized (Slot 01)` - Paste with subtle humanization
- `Pattern Editor:Paketti:Clipboard:Wonkify:Drunk (Slot 01)` - Paste with drunk groove
- `Pattern Editor:Paketti:Clipboard:Wonkify:Lo-Fi (Slot 01)` - Paste with lo-fi grit
- `Pattern Editor:Paketti:Clipboard:Wonkify:Glitchy (Slot 01)` - Paste with glitchy timing
- `Pattern Editor:Paketti:Clipboard:Wonkify:Chaos (Slot 01)` - Paste with maximum chaos
- `Pattern Editor:Paketti:Clipboard:Wonkify:Jazz (Slot 01)` - Paste with jazz feel
- `Pattern Editor:Paketti:Clipboard:Wonkify:Tight (Slot 01)` - Paste with tight micro-timing

### Phrase Editor Keybindings

The same Wonkify presets are available when pasting into phrases:

- `Phrase Editor:Paketti:Clipboard Wonkify Humanized` - Paste with humanization
- `Phrase Editor:Paketti:Clipboard Wonkify Drunk` - Paste with drunk groove
- `Phrase Editor:Paketti:Clipboard Wonkify Lo-Fi` - Paste with lo-fi grit
- `Phrase Editor:Paketti:Clipboard Wonkify Glitchy` - Paste with glitchy timing
- `Phrase Editor:Paketti:Clipboard Wonkify Chaos` - Paste with chaos
- `Phrase Editor:Paketti:Clipboard Wonkify Jazz` - Paste with jazz feel
- `Phrase Editor:Paketti:Clipboard Wonkify Tight` - Paste with tight timing

### MIDI Mappings

All seven presets have corresponding MIDI mappings:

- `Paketti:Clipboard Wonkify Humanized` - Trigger humanized paste
- `Paketti:Clipboard Wonkify Drunk` - Trigger drunk groove paste
- `Paketti:Clipboard Wonkify Lo-Fi` - Trigger lo-fi paste
- `Paketti:Clipboard Wonkify Glitchy` - Trigger glitchy paste
- `Paketti:Clipboard Wonkify Chaos` - Trigger chaos paste
- `Paketti:Clipboard Wonkify Jazz` - Trigger jazz feel paste
- `Paketti:Clipboard Wonkify Tight` - Trigger tight timing paste

### Transformations Applied

**Delay Drift:**
- Shifts note timing using the delay column (0-255 ticks)
- Each preset defines percentage chance and maximum drift amount
- Creates micro-timing variations for humanization

**Velocity Variation:**
- Randomizes note velocity based on percentage of original value
- Adds dynamic variation to otherwise static patterns
- Preserves relative loud/soft relationships

**Pitch Drift (Chaos preset only):**
- Shifts notes by semitones
- Only enabled in the Chaos preset for maximum variation
- Keeps notes within valid MIDI range (0-119)

**Row Drift:**
- Swaps note positions between different rows
- Creates rhythmic displacement and shuffling
- Enabled in Drunk, Glitchy, and Chaos presets

### Creative Workflow

**Build Variations Quickly:**
1. Copy a drum pattern to Slot 01
2. Paste with "Humanized" for verse
3. Paste with "Drunk" for breakdown
4. Paste with "Chaos" for climax
5. Each paste creates a unique variation from the same source

**A/B Testing:**
- Copy your pattern
- Paste with different presets to adjacent tracks
- Compare and choose the best variation
- Delete unwanted variations

**Layered Humanization:**
- Paste the same content multiple times with "Humanized"
- Each paste applies fresh random values
- Build up subtle variations across sections

### Technical Details

- Transformations use time-based random seeds for variety
- Original clipboard data is deep-copied before transformation
- Effect columns are preserved without modification
- Empty notes and OFF notes are not transformed
- Works with multi-track clipboard content

---

# Sample Processing Tools

## AKWF Wavetable Generator

**Source:** `PakettiWavetabler.lua`

Creates random wavetables from Adventure Kid Waveforms (AKWF) library - 4,000+ single-cycle waveforms combined into seamless wavetables. This library is actually included inside Paketti, so you don't need to install it. The loading is hardcoded to access the AKWF library from within Paketti.

### Random Wavetable Creation

**Shortcuts (Non-Looped):**
- `Global:Paketti:Create Random AKWF Wavetable (032)` ⌨️ - 32 cycles
- `Global:Paketti:Create Random AKWF Wavetable (064)` ⌨️ - 64 cycles
- `Global:Paketti:Create Random AKWF Wavetable (128)` ⌨️ - 128 cycles
- `Global:Paketti:Create Random AKWF Wavetable (256)` ⌨️ - 256 cycles

**Shortcuts (Looped):**
- `Global:Paketti:Create Random AKWF Wavetable (032,loop)` ⌨️ - 32 cycles + loop
- `Global:Paketti:Create Random AKWF Wavetable (064,loop)` ⌨️ - 64 cycles + loop
- `Global:Paketti:Create Random AKWF Wavetable (128,loop)` ⌨️ - 128 cycles + loop
- `Global:Paketti:Create Random AKWF Wavetable (256,loop)` ⌨️ - 256 cycles + loop

### Generation Process

1. **Select Random Cycles:** Picks N random single-cycle waveforms from AKWF library
2. **Combine into Buffer:** Concatenates all cycles into single sample
3. **Set Loop Points:**
   - **Non-looped:** Loop covers entire wavetable
   - **Looped:** Loop covers first single cycle only
4. **Apply Template:** Uses Paketti XRNI template with macros
5. **Name Instrument:** "Random AKWF Wavetable (064+loop)" format

### Wavetable Control Dialog

**Menu:** `Main Menu:Tools:Paketti:.WT:Wavetable Control...` 📋

Comprehensive wavetable control interface for managing, navigating, and editing wavetables.

### Import/Export Wavetables

**Menu:**
- `Main Menu:Tools:Paketti:.WT:Import Wavetable...` 📋
- `Main Menu:Tools:Paketti:.WT:Export Wavetable...` 📋

Import wavetables from external formats, export Renoise wavetables for use in other tools.

### Wavetable Navigation

**Next/Previous Cycle:**
- `Global:Paketti:Next Wavetable Cycle` ⌨️ - Move loop to next single cycle
- `Global:Paketti:Previous Wavetable Cycle` ⌨️ - Move loop to previous cycle

**MIDI Mappings:**
- `Paketti:Next Wavetable Cycle` 🎹 - Trigger next cycle
- `Paketti:Previous Wavetable Cycle` 🎹 - Trigger previous cycle
- `Paketti:Select Wavetable Cycle [Set]` 🎹 - MIDI CC 0-127 selects cycle

**Loop Calculation:**
- Automatically calculates frames per cycle
- Updates loop start/end to single cycle
- Shows "Loop cycle: 5/64" status

**MIDI Control:**
- CC value 0-127 maps to cycle 1-N
- Instant wavetable scanning
- Real-time morphing during performance

### Technical Details

**AKWF Library:**
- 4,000+ single-cycle waveforms
- Organized in akwf.txt manifest
- Located in tool's AKWF/ folder
- All samples 44.1kHz, 16-bit

**Buffer Management:**
- Disables AutoSamplify during generation
- Temporary samples deleted after combination
- Preserves sample rate and bit depth from source
- Forward loop mode by default

### Use Cases

**Synthesis:**
- Create unique wavetable synths
- Morphing pad sounds
- Evolving textures

**Live Performance:**
- MIDI-controlled wavetable scanning
- Real-time cycle switching
- Dynamic timbre changes

**Sound Design:**
- Random wavetable inspiration
- Combine diverse waveforms
- Experimental synthesis

---

## Time Stretch

**Source:** `PakettiStretch.lua`

**Shortcut:** `Global:Paketti:Timestretch Dialog...` ⌨️

Advanced time-stretching dialog for tempo-independent sample manipulation with quality presets.

### Features

**Time Stretch Modes:**
- Percussion (transient preservation)
- Texture (smooth stretching)
- Custom ratios

**Quality Settings:**
- Fast (low CPU)
- Standard (balanced)
- High Quality (best results)

**Stretch Ratios:**
- 0.5x (half speed, double length)
- 1.0x (original)
- 2.0x (double speed, half length)
- Custom (manual input)

### Dialog Controls

**Source Selection:**
- Current sample
- All samples in instrument
- Sample range

**Output Options:**
- Replace original
- Create new sample
- Create new instrument

**Preview:**
- Real-time preview before applying
- A/B comparison with original
- Visual waveform display

### Use Cases

**Tempo Matching:**
- Match loops to song BPM
- Sync samples without repitching
- Create time-stretched variations

**Sound Design:**
- Extreme slow-down effects
- Granular texture creation
- Preserve pitch while changing length

---

## Sample Cycle Tuning (RePitch)

**Source:** `PakettiRePitch.lua`

Automatic pitch detection and correction for single-cycle waveforms. Analyzes waveform frequency and sets correct transpose value.

### Features

**Shortcuts:**
- `Global:Paketti:Sample Cycle Tuning Calculator...` ⌨️ - Opens calculator dialog
- `Global:Paketti:Selected Sample 1 Cycle Tuning` ⌨️ - Quick tune current sample
- `Global:Paketti:Selected Instrument 1 Cycle Tuning` ⌨️ - Tune all samples in instrument
- `Sample Editor:Paketti:Sample Cycle Tuning Calculator...` ⌨️
- `Sample Editor:Paketti:Selected Sample 1 Cycle Tuning` ⌨️
- `Sample Editor:Paketti:Selected Instrument 1 Cycle Tuning` ⌨️

### Tuning Calculator Dialog

**Analysis:**
- Detects fundamental frequency
- Calculates nearest MIDI note
- Shows cents deviation
- Suggests transpose value

**Auto-Correction:**
- Applies optimal transpose
- Sets finetune for cents accuracy
- Preserves sample properties

**Manual Override:**
- Adjust detected frequency
- Fine-tune cents
- Preview before applying

### Quick Tuning

**Selected Sample:**
- Analyzes single cycle
- Auto-calculates transpose
- Instant correction

**All Samples:**
- Batch processes instrument
- Individual analysis per sample
- Progress feedback

### Use Cases

**Wavetable Creation:**
- Correct AKWF wavetable tuning
- Ensure accurate pitch
- Create chromatic wavetables

**Sample Library Management:**
- Fix detuned samples
- Standardize sample pitch
- Prepare samples for keymapping

**Sound Design:**
- Single-cycle waveform tuning
- Oscillator calibration
- Synthesis preparation

---

# Slab'o'Patterns (Time Signature Generator)

**Source:** `PakettiSlabOPatterns.lua` | **Features:** 2

**Shortcuts:**
- `Pattern Editor:Paketti:Paketti Slab'o'Patterns...` ⌨️
- `Global:Paketti:Paketti Slab'o'Patterns...` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti Gadgets:Paketti Slab'o'Patterns...` 📋
- `Pattern Sequencer:Paketti Gadgets:Paketti Slab'o'Patterns...` 📋
- `Pattern Matrix:Paketti Gadgets:Paketti Slab'o'Patterns...` 📋
- `Pattern Editor:Paketti Gadgets:Paketti Slab'o'Patterns...` 📋

**Beat-based pattern generation system** for creating complex time signature sequences. Define pattern lengths in beats (not lines), automatically adapts to any LPB.

## Core Concept

Instead of thinking in "64 lines" or "48 lines", think in **musical beats:**
- **"4"** = 4 beats using current song LPB (e.g., at LPB 4 = 16 lines, at LPB 8 = 32 lines)
- **"7"** = 7 beats = 7/4 time signature
- **"3.5"** = 3.5 beats = fractional measures
- **"4:8"** = 4 beats at LPB 8 (force specific LPB via ZL command in pattern)

Beat-based approach maintains rhythmic structure regardless of LPB changes.

## Preset Time Signatures

**Built-in Presets:**
- **7/4** - 7 beats
- **5/4** - 5 beats
- **14/8** - 4 beats, 3 beats alternating
- **15/8** - 4 beats, 3.5 beats
- **14/8 - 15/8** - Four-pattern cycle
- **14/8 - 15/8 - 15/8 - 14/8** - Eight-pattern progressive cycle
- **6/4 8/4** - 3, 3, 4, 4 beats
- **8/4 6/4** - 4, 4, 3, 3 beats

Click preset button to apply. Toggle "Append Preset" checkbox to add preset to existing list (instead of replacing).

## Custom Sequences

**Build your own:**
1. Enter beat values in rows (e.g., "4", "7", "3.5")
2. **+** button duplicates current seed pattern
3. **-** button removes selected row
4. **↑/↓** arrows move rows
5. **Section Name** text field labels the sequence

**Generate Patterns button:**
- Creates patterns in sequence for each beat value
- Names patterns with section name
- Applies LPB if specified (via ZL command)
- Updates sequencer

## Advanced Features

**Seed Pattern Duplication:**
When you click **+**, duplicates the entire current pattern list. Example:
- Start: `[4, 7]`
- After +: `[4, 7, 4, 7]`
- After + again: `[4, 7, 4, 7, 4, 7, 4, 7]`

Perfect for building extended sections quickly.

**LPB Control:**
- Use `beats:lpb` format (e.g., "7:5") to force specific LPB
- Writes ZL command to pattern master track
- Overrides song global LPB for that pattern

**Section Naming:**
- Enter section name (e.g., "Verse", "Chorus", "Bridge")
- Toggle "Append preset name" to add preset label to section
- Generated patterns named: "Section 01", "Section 02", etc.

## Configuration Persistence

Pattern list saved to `slab_o_patterns.txt` in tool bundle path. Configuration persists across sessions.

## Use Cases

**Progressive Metal/Jazz:**
- Complex time signature progressions
- Polyrhythmic sections
- Metric modulation

**Film Scoring:**
- Match video timing with beat-accurate patterns
- Quick time signature experiments

**Electronic Music:**
- Asymmetric loop lengths
- Phase-shifting patterns
- Generative structures

**Workflow Efficiency:**
- Pre-plan song structure by beats
- Bulk-create pattern skeleton
- Experiment with rhythm without manual pattern resizing

---

# Pattern Sequencer Utilities

**Source:** `PakettiPatternSequencer.lua` | **Features:** 34

Advanced pattern sequencer management with cloning, section management, sorting, and cleanup tools.

## Sequence Cloning & Duplication

**Shortcuts:**
- `Global:Paketti:Clone Current Sequence` ⌨️ - Clones current sequence
- `Pattern Sequencer:Paketti:Clone Current Sequence` ⌨️
- `Global:Paketti:Duplicate Selected Sequence Range` ⌨️ - Duplicates selection
- `Pattern Sequencer:Paketti:Duplicate Selected Sequence Range` ⌨️

**Configurable Naming:**
- Prefix/Suffix options
- Numbering formats (%d, %02d, %03d)
- Keep original / Clear name / Use settings
- Settings dialog: `Pattern Sequencer:Paketti:Show Paketti Sequencer Settings Dialog` ⌨️

## Section Management

**Create Section:**
- `Pattern Sequencer:Paketti:Create Section From Selection` ⌨️
- Creates named section from selected sequence range
- Auto-naming with configurable format

**Section Navigation:**
- `Pattern Sequencer:Paketti:Select Next Section Sequence` ⌨️
- `Pattern Sequencer:Paketti:Select Previous Section Sequence` ⌨️
- Jump between section boundaries

**Section Loops (01-64):**
- `Global:Paketti:Select and Loop Sequence Section 01` through `64` ⌨️
- Instant section selection + loop creation
- 64 pre-mapped section shortcuts

## Sequence Scheduling

**Shortcuts:**
- `Global:Paketti:Add Current Sequence to Scheduled List` ⌨️
- Adds current sequence to schedule queue
- Builds multi-sequence playlists

## Keep Sequence Sorted

**Auto-Sort Patterns:**
- `Global:Paketti:Keep Sequence Sorted On/Off/Toggle` ⌨️
- `Pattern Editor:Paketti:Keep Sequence Sorted On/Off/Toggle` ⌨️
- `Pattern Sequencer:Paketti:Keep Sequence Sorted On/Off/Toggle` ⌨️

**Menu:**
- `Pattern Matrix:Paketti:Keep Sequence Sorted On/Off/Toggle` 📋

**Automatic Sorting:**
- Keeps pattern sequence in ascending order
- Automatically re-sorts when patterns inserted/moved
- Toggle on/off per preference

## Pattern Cleanup

**Wipe Empty Patterns From End:**
- `Pattern Sequencer:Paketti:Wipe Empty Patterns From End` ⌨️ 📋
- `Pattern Matrix:Paketti:Wipe Empty Patterns From End` 📋
- Removes trailing empty patterns
- Cleans up unused slots at end

**Clear Unused Patterns:**
- `Global:Paketti:Clear Unused Patterns` ⌨️
- `Pattern Sequencer:Paketti:Clear Unused Patterns` ⌨️ 📋
- `Pattern Editor:Paketti:Clear Unused Patterns` ⌨️
- `Pattern Matrix:Paketti:Clear Unused Patterns` ⌨️ 📋

**Menu:**
- `Pattern Matrix:Paketti:Clear Unused Patterns` 📋
- `Pattern Sequencer:Paketti:Clear Unused Patterns` 📋

**Smart Cleanup:**
- Finds patterns not used in any sequence
- Clears their content (keeps slot)
- Reclaims memory without breaking sequence

## Delete Sequences

Mass-delete sequences above, below, or around current sequence or selection. Respects pattern sequencer selection range if present.

**Delete All Sequences Above:**
- `Global:Paketti:Delete All Sequences Above` ⌨️
- `Pattern Sequencer:Paketti:Delete All Sequences Above` ⌨️ 📋
- `Pattern Editor:Paketti:Delete All Sequences Above` ⌨️ 📋
- `Pattern Matrix:Paketti:Delete All Sequences Above` ⌨️ 📋

**Delete All Sequences Below:**
- `Global:Paketti:Delete All Sequences Below` ⌨️
- `Pattern Sequencer:Paketti:Delete All Sequences Below` ⌨️ 📋
- `Pattern Editor:Paketti:Delete All Sequences Below` ⌨️ 📋
- `Pattern Matrix:Paketti:Delete All Sequences Below` ⌨️ 📋

**Delete All Sequences Above and Below:**
- `Global:Paketti:Delete All Sequences Above and Below` ⌨️
- `Pattern Sequencer:Paketti:Delete All Sequences Above and Below` ⌨️ 📋
- `Pattern Editor:Paketti:Delete All Sequences Above and Below` ⌨️ 📋
- `Pattern Matrix:Paketti:Delete All Sequences Above and Below` ⌨️ 📋

**Selection-Aware Behavior:**
- If no selection: Uses current sequence position as reference
- If selection exists: Uses selection boundaries (start/end)
- Delete Above: Removes everything above selection start
- Delete Below: Removes everything below selection end
- Delete Above and Below: Keeps only the selected range

**Use Cases:**
- Quickly trim song to specific section
- Remove intro/outro sequences
- Isolate selection for rendering
- Clean up work-in-progress arrangements

## Pattern Operations

**Duplicate Pattern and Insert Next:**
- `Global:Paketti:Duplicate Pattern and Insert Next` ⌨️
- `Pattern Sequencer:Paketti:Duplicate Pattern and Insert Next` ⌨️
- `Pattern Editor:Paketti:Duplicate Pattern and Insert Next` ⌨️
- Duplicates current pattern
- Inserts into next sequence position

**Play Current Pattern Sequence:**
- `Global:Paketti:Play Current Pattern Sequence` ⌨️
- Starts playback from current sequence
- Pattern-based playback control

## Preferences

**Naming Behavior:**
1. Use Settings (Prefix/Suffix)
2. Clear Name
3. Keep Original Name

**Numbering:**
- Enable/disable numbering
- Format: %d (1), %02d (01), %03d (001)

**Section Naming:**
- Prefix/suffix for sections
- Numbering format
- Auto-naming rules

---

# Utility Features

## Groove to Delay Converter

**Source:** `PakettiGlobalGrooveToDelayValues.lua`

**Shortcut:** `Global:Paketti:Global Groove to Delay Values` ⌨️

Converts groove settings to delay column values across pattern. Analyzes current groove (1-4) and writes corresponding delay values to all notes, creating groove feel without using groove engine.

**Use Cases:**
- Render grooved patterns
- Export with groove baked in
- Fine-tune per-note groove

---

## Fill Pattern

**Source:** `PakettiFill.lua`

**Shortcut:** `Pattern Editor:Paketti:Fill Pattern` ⌨️

Flood-fills pattern with current selection, repeating until pattern end. Creates instant loops and pattern extensions.

**Use Cases:**
- Extend 4-bar loop to 16 bars
- Fill pattern with sequence
- Quick pattern generation

---

## 810 (EightOneTwenty)

**Source:** `PakettiEightOneTwenty.lua` | **Features:** 6

Grid-based step sequencer (8x10 grid = 80 steps) with visual editing, built-in scales, and direct pattern writing.

**Shortcuts:**
- `Global:Paketti:Show 810 Dialog...` ⌨️
- `Global:Paketti:Save 810 State` ⌨️
- `Global:Paketti:Load 810 State` ⌨️
- `Global:Paketti:Write 810 to Pattern` ⌨️
- `Global:Paketti:Clear 810 Grid` ⌨️

**Features:**
- 8 columns × 10 rows = 80 steps
- Musical scale selection
- Step enable/disable checkboxes
- Direct pattern writing
- State save/load

---

## Tree Structure Browser (TODO)

**Source:** `PakettiTreeStructure.lua` | **Features:** 6

Hierarchical pattern/sequence structure browser with collapsible sections. Displays song structure as expandable tree.

**Shortcuts:**
- `Global:Paketti:Show Tree Structure...` ⌨️
- Tree navigation shortcuts (expand/collapse)
- Section jumping
- Pattern selection from tree

**Features:**
- Nested section display
- Pattern count per section
- Click to jump to pattern/section
- Collapsible hierarchy

---

## Capture Last Take

**Source:** `PakettiCaptureLastTake.lua` | **Features:** 3

Records and organizes multiple recording takes with visual slot management. Shows 20 slots with captured samples.

**Shortcuts:**
- `Global:Paketti:Capture Last Take` ⌨️
- `Global:Paketti:Show Last Take Capture Dialog...` ⌨️

**Features:**
- 20 take slots
- Automatic capture after recording
- Visual take browser
- Notes per take
- Audition from dialog
- Write to pattern
- Capture from pattern
- Modify voicings
---


## Selected Device Parameter Editor

**Source:** `PakettiCanvasExperiments.lua` | **Features:** 3

Visual canvas-based parameter editor for Renoise devices with A/B comparison, automation support, and real-time drawing.

### Main Dialog

**Keybinding:** `Global:Paketti:Paketti Selected Device Parameter Editor` ⌨️

Opens a visual parameter editor for the currently selected device with real-time drawing capabilities.

**Features:**
- Visual bar representation of all device parameters
- Mouse-based parameter editing (click/drag to adjust)
- Real-time device parameter updates
- A/B edit mode for parameter comparison
- Crossfade between A and B states
- Automation sync (read/write automation while playing)
- Randomization with strength control
- Parameter name display
- Auto-device switching
- External editor toggle (Space key)

**Visual Elements:**
- **Purple bars** - Edit A parameters (bold when active)
- **Yellow bars** - Edit B parameters (bold when active)
- **Green line** - Crossfade position
- **White cursor** - Mouse position while drawing
- **Vertical text** - Parameter names

### Pattern Automation Features

**Keybindings:**
- `Global:Paketti:Parameter Editor Duplicate to Next Pattern` ⌨️
- `Global:Paketti:Parameter Editor Snapshot to Next Pattern` ⌨️

**Duplicate to Next Pattern:**
- Copies ALL automation from current pattern to next pattern
- Creates new pattern if needed
- Automatically jumps to new pattern
- Preserves automation curves and points

**Snapshot to Next Pattern:**
- Writes current parameter values to automation in next pattern
- Creates snapshot at line 1
- Useful for creating static parameter states
- Works with crossfaded A/B values

### Dialog Controls

**Automation:**
- Add Snapshot - Write current parameters to automation at cursor
- Clear - Remove all automation for current device
- Clean&Snap - Clear automation and write at line 1
- Automation Sync - Toggle bidirectional automation (read during playback, write when drawing)

**Randomization:**
- Randomize Automation - Randomize and write snapshot
- Randomize by EditStep - Create random automation at EditStep intervals
- Randomize Strength slider (0-100%)
- Separate randomization for Edit A/B

**Edit A/B:**
- Edit A button - Edit device parameters directly
- Edit B button - Edit alternate parameter set
- Crossfade slider - Morph between A and B states
- Real-time crossfading during playback

**Device Navigation:**
- Previous/Next Track buttons
- Previous/Next Device buttons
- Auto-device switching (follows selected device)

**Automation Playmode:**
- Points - Stepped automation
- Lines - Linear interpolation
- Curves - Smooth curved interpolation

### Workflow

**Basic Editing:**
1. Select device in Renoise
2. Open Parameter Editor
3. Click/drag bars to adjust parameters
4. Device updates in real-time

**A/B Comparison:**
1. Edit A - Adjust parameters (purple bars)
2. Switch to Edit B
3. Edit B - Create alternate settings (yellow bars)
4. Use Crossfade slider to morph between A and B
5. Snapshot to write crossfaded value to automation

**Automation Writing:**
1. Enable Automation Sync
2. Start playback
3. Draw parameter changes in real-time
4. Automation is written at current playback position
5. Automation view updates automatically

**Pattern Duplication:**
1. Set up automation in current pattern
2. Press "Duplicate to Next Pattern"
3. Automation is copied and you jump to new pattern
4. Continue editing or add variations

### Special Features

**Auto-open:**
- Can auto-open when selecting compatible devices
- Excludes Pro-Q 3 (uses external editor)
- Excludes EQ30/EQ64 (uses dedicated EQ30 dialog)

**Wavetable Mod *LFO:**
- Special handling for Wavetable Mod *LFO devices
- Hides first 3 routing parameters
- Shows only musically relevant parameters

**Parameter Name Cleaning:**
- Removes "CC XX " prefixes from parameter names
- Cleaner display for MIDI-controlled devices

### Keyboard Shortcuts

- **CMD-H** - Close dialog
- **Space** - Toggle external editor (if available)
- All other keys pass through to Renoise

### Use Cases

**Sound Design:**
- Real-time filter sweeps with automation
- Create evolving pad sounds
- Design complex modulation patterns

**Mixing:**
- A/B compare EQ settings
- Automate effect parameters
- Create dynamic effect changes

**Performance:**
- Draw expressive automation during playback
- Morph between preset A and B states
- Create buildups and breakdowns

---

## EQ30/EQ64 Visual Equalizer

**Source:** `PakettiEQ30.lua` | **Features:** 5

Advanced visual EQ system using multiple EQ10 devices for 30-band or 64-band parametric EQ with canvas-based drawing.

### Main Features

**Keybindings:**
- `Global:Paketti:Load & Show Paketti EQ30` ⌨️
- `Global:Paketti:Paketti EQ30 Unused Note Frequency Reduction Flavor` ⌨️
- `Global:Paketti:Paketti EQ64 Unused Note Frequency Reduction Flavor` ⌨️

**MIDI Mappings:**
- `Paketti:Load & Show PakettiEQ30` 🎹
- `Paketti:Paketti EQ30 Unused Note Frequency Reduction Flavor` 🎹
- `Paketti:Paketti EQ64 Unused Note Frequency Reduction Flavor` 🎹

### EQ30 System

**Load & Show Paketti EQ30:**
Opens visual 30-band EQ editor with canvas-based control.

**System:**
- 4 EQ10 devices (8 bands each = 32 total, using middle 8 bands)
- 30 usable bands total
- Frequencies: 25Hz to 20kHz (1/3 octave spacing)
- Avoids problematic 1st and 10th bands of EQ10

**Features:**
- Visual bar-based EQ curve drawing
- Real-time device parameter updates
- Column-aligned vertical guides per band
- Gain markers at musical intervals (-20, -12, -6, -3, 0, +3, +6, +12, +20 dB)
- Left-click/drag to adjust individual bands
- Right-click to reset all bands to flat
- Automation sync support
- Global Q/Bandwidth control
- Create/Follow mode (auto-load EQ when switching tracks)

**Visual Elements:**
- **Purple bars** - EQ gain per band
- **White zero line** - 0dB reference (thick)
- **Green grid lines** - Band boundaries
- **Gray gain markers** - dB reference lines
- **Vertical frequency labels** - Band frequencies
- **Bottom band numbers** - 01-30

### EQ64 System

**Paketti EQ64 Unused Note Frequency Reduction Flavor:**
64-band system for ultra-precise frequency cleanup.

**System:**
- 8 EQ10 devices (8 bands each = 64 total)
- 64 usable bands
- Dynamically generated frequencies based on note analysis
- Same band-skipping strategy (middle 8 bands only)

### Unused Note Frequency Reduction

**Concept:**
Analyzes your track's used notes and generates EQ bands targeting unused note frequencies.

**EQ30 Unused Note Frequency Reduction Flavor:**
1. Scans selected track pattern for used notes
2. Identifies unused note frequencies in expanded range (±1 octave)
3. Generates up to 30 target frequencies
4. Adds 2nd/3rd harmonics if needed
5. Opens EQ30 dialog with custom frequency set

**EQ64 Unused Note Frequency Reduction Flavor:**
1. Same analysis as EQ30
2. Generates up to 64 target frequencies
3. More precise frequency targeting
4. Fills gaps with interpolated frequencies
5. Opens EQ64 dialog with 8 devices

**Use Cases:**
- Clean up mud from unused frequency ranges
- Surgical notching of problematic frequencies
- Create space for lead melodies
- Reduce frequency masking
- Sound design and mixing

### Dialog Controls

**Automation:**
- Reset Flat - Set all bands to 0dB
- Add Snapshot to Automation - Write current EQ curve to automation
- Clear - Remove all EQ automation
- Clean & Snap - Clear and write line 1 snapshot
- Automation Sync toggle

**Randomization:**
- Randomize Automation Step - Create randomized automation per EditStep
- Smooth - Musical random with gentle peaks
- Surgical - Sharp individual band adjustments
- Creative - Wild experimental curves

**Global Q Control:**
- Slider to adjust bandwidth of all bands simultaneously
- Range: 0.05 (sharp) to 0.8 (wide)
- Displays both bandwidth value and approximate Q factor
- Updates all devices in real-time

**Automation Playmode:**
- Points - Stepped automation
- Lines - Linear interpolation
- Curves - Smooth curves

**Workflow:**
- Load from Track - Import existing EQ10 device settings
- Create/Follow - Auto-load EQ when switching tracks
- Recreate Devices - Force rebuild all EQ10 devices
- Close - Close dialog

### Workflow

**Basic EQ Editing:**
1. Select track
2. Open EQ30/EQ64 dialog
3. Click/drag bars to adjust frequencies
4. Right-click to reset to flat
5. EQ10 devices update in real-time

**Unused Note Reduction:**
1. Create melody on track
2. Open Unused Note Frequency Reduction
3. Automatically generates cleanup frequencies
4. Draw notches on unused frequencies
5. Creates space for melody

**Automation Recording:**
1. Enable Automation Sync
2. Start playback
3. Draw EQ changes in real-time
4. Automation is written automatically
5. Create evolving EQ sweeps

**A/B Comparison:**
1. Set up EQ curve
2. Snapshot to automation
3. Adjust to alternate curve
4. Use automation playback to compare
5. Choose best result

### Technical Details

**Frequency Distribution:**
- **EQ30:** 1/3 octave bands (ISO standard)
- **EQ64:** Note-based or interpolated frequencies
- Logarithmic frequency spacing
- Covers full audible spectrum (20Hz-20kHz)

**Bandwidth Calculation:**
- Frequency-dependent default values
- Low frequencies: 0.15 (sharp control)
- Midrange: 0.12 (surgical precision)
- Presence: 0.10 (very sharp)
- High frequencies: 0.15 (sharp)

**Device Naming:**
- EQ30: "EQ30 Device 1-4"
- EQ64: "EQ64 Device 1-8"
- Auto-labels for easy identification

### Special Features

**Auto-open:**
- Automatically opens when selecting EQ30/EQ64 devices
- Device selection observer
- Seamless workflow integration

**Create/Follow Mode:**
- Follows track selection
- Auto-loads existing EQ settings
- Click canvas to create if missing
- Perfect for mixing workflow

**Auto-load:**
- Silent auto-load of existing device settings on dialog open
- "Just works" - no manual loading needed
- Preserves your existing EQ curves

### Use Cases

**Mixing:**
- Surgical EQ for individual tracks
- Remove problematic frequencies
- Create separation between instruments
- Frequency-based sidechaining

**Sound Design:**
- Creative EQ filtering
- Generate unusual frequency responses
- Random EQ for texture
- Evolving timbral changes

**Mastering:**
- Gentle broad strokes (wider Q)
- Fix frequency imbalances
- Create character
- Analog-style coloration

**Live Performance:**
- Real-time EQ automation
- Dynamic frequency sweeps
- Build tension with filter automation
- Drop automation for impact

---

## Slice Effect Step Sequencer

**Source:** `PakettiSliceEffectStepSequencer.lua` | **Features:** 8

Visual step sequencer for creating slice-based patterns with effect columns and velocity control.

### Main Features

**Keybindings:**
- `Global:Paketti:Paketti Slice Effect Step Sequencer Dialog...` ⌨️
- `Pattern Sequencer:Paketti:Duplicate Pattern (Slice Step Sequencer)` ⌨️
- `Pattern Matrix:Paketti:Duplicate Pattern (Slice Step Sequencer)` ⌨️
- `Pattern Editor:Paketti:Duplicate Pattern (Slice Step Sequencer)` ⌨️
- `Global:Paketti:Duplicate Pattern (Slice Step Sequencer)` ⌨️

**MIDI Mappings:**
- `Paketti:Paketti Slice Effect Step Sequencer Dialog...` 🎹
- `Paketti:Paketti Slice Step Sequencer:Duplicate Pattern` 🎹

### Main Dialog

**Paketti Slice Effect Step Sequencer Dialog:**
Visual step sequencer with grid-based editing for sliced instruments.

**Grid Interface:**
- Visual step grid (typically 16 steps)
- Slice selection per step
- Velocity control per step
- Effect column writing
- Pattern length control
- LPB (Lines Per Beat) control

**Features:**
- Click steps to enable/disable
- Select which slice plays per step
- Adjust velocity per step
- Write effect commands (0Sxx for slice changes)
- Real-time pattern preview
- Auto-create patterns
- Multiple pattern lengths

### Duplicate Pattern

**Multiple contexts for quick duplication:**
- From Pattern Sequencer view
- From Pattern Matrix view
- From Pattern Editor view
- Global shortcut (works anywhere)

**Workflow:**
1. Create pattern with Slice Step Sequencer
2. Press duplicate shortcut
3. New pattern created instantly
4. Continue editing variations

### Dialog Controls

**Pattern Settings:**
- Pattern Length - Number of lines
- LPB - Lines per beat (timing)
- Track - Target track selection
- Instrument - Source sliced instrument

**Step Grid:**
- Click to toggle step on/off
- Active steps highlighted
- Slice number selector per step
- Velocity slider per step

**Slice Selection:**
- Dropdown or buttons for slice numbers
- Visual feedback of current slice
- Support for up to 255 slices (0Sxx effect)

**Effect Column:**
- Automatically writes 0Sxx commands
- Slice-per-step triggering
- Velocity column writing
- Clean pattern generation

**Playback:**
- Play button for preview
- Stop button
- Loop toggle
- Transport integration

### Workflow

**Basic Pattern Creation:**
1. Select sliced instrument
2. Open Slice Effect Step Sequencer
3. Click steps to activate
4. Select slice number for each step
5. Adjust velocities
6. Press "Write to Pattern"
7. Pattern appears in sequencer

**Velocity Programming:**
1. Enable steps in grid
2. Adjust velocity slider per step
3. Create dynamic patterns
4. Accent specific beats
5. Write to pattern

**Slice Variations:**
1. Program basic pattern
2. Duplicate pattern
3. Change slice assignments
4. Create variations
5. Build arrangement

**Effect Column Usage:**
1. Automatically uses 0Sxx commands
2. One slice per step
3. Clean, efficient pattern data
4. Works with any sliced instrument

### Use Cases

**Drum Programming:**
- Create kick/snare patterns
- Program hi-hat rhythms
- Build complete drum loops
- Velocity-accented grooves

**Slice-based Sequencing:**
- Melodic slice patterns
- Vocal chop sequences
- Glitch effects
- Rhythmic textures

**Live Performance:**
- Quick pattern sketching
- Real-time variation creation
- Pattern duplication for buildup
- Dynamic arrangement

**Sound Design:**
- Rhythmic texture creation
- Glitchy patterns
- Slice-based arpeggios
- Experimental sequences

---

## Stacker

**Source:** `PakettiStacker.lua` | **Features:** 6

A method of doing velocity stacking - where each velocity stack has a different slice, isolated to individual samples. Basically a poor man's Ableton Live "Warp Mode". Also features methods for playing, and mixing, the slices at 3, 2, 1 octaves lower and 1, 2, 3 octaves higher, at the same time.

### Main Features

**Keybindings:**
- `Global:Paketti:Paketti Stacker Dialog...` ⌨️
- `Global:Paketti:Stack All Samples in Instrument with Velocity Mapping Split` ⌨️
- `Global:Paketti:Load&Slice&Isolate&Stack Sample` ⌨️
- `Global:Paketti:Write Velocity Ramp Up for Stacked Instrument` ⌨️
- `Global:Paketti:Write Velocity Ramp Down for Stacked Instrument` ⌨️
- `Global:Paketti:Write Velocity Random for Stacked Instrument` ⌨️

### Main Dialog

**Paketti Stacker Dialog:**
Visual interface for creating velocity-layered instruments from multiple samples.

**Features:**
- Load multiple samples
- Automatic velocity mapping
- Equal velocity splits
- Sample ordering
- Velocity range display
- Preview stacked result

### Stack with Velocity Mapping

**Stack All Samples in Instrument with Velocity Mapping Split:**
Takes all samples in current instrument and maps them across the full velocity range.

**Process:**
1. Counts total samples in instrument
2. Divides velocity range (0-127) equally
3. Assigns velocity splits to each sample
4. Creates layered instrument
5. Preserves original samples

**Example:**
- 4 samples → 32 velocity units each
- Sample 1: velocity 0-31
- Sample 2: velocity 32-63
- Sample 3: velocity 64-95
- Sample 4: velocity 96-127

### Load&Slice&Isolate&Stack

**Complete workflow automation:**
1. Load sample from browser
2. Auto-detect transients and slice
3. Isolate each slice to separate sample
4. Stack all slices with velocity mapping
5. Create performance-ready instrument

**Perfect for:**
- Drum kit creation from loops
- Multi-sample instruments from breaks
- One-shot libraries from loops
- Velocity-sensitive percussion

### Velocity Pattern Writing

**Write Velocity Ramp Up:**
Writes notes with gradually increasing velocity in pattern.

**Process:**
1. Starts at low velocity
2. Increments velocity per note
3. Reaches maximum at end
4. Creates crescendo effect

**Write Velocity Ramp Down:**
Opposite of ramp up - decrescendo effect.

**Process:**
1. Starts at high velocity
2. Decreases velocity per note
3. Reaches minimum at end
4. Creates fade-out effect

**Write Velocity Random:**
Writes notes with randomized velocities.

**Process:**
1. Generates random velocity values
2. Writes to pattern
3. Creates dynamic, humanized feel
4. Perfect for realistic performances

### Dialog Controls

**Sample Selection:**
- Load samples button
- Sample list display
- Reorder samples (drag/drop)
- Remove samples

**Velocity Mapping:**
- Manual split points
- Equal split button
- Velocity range display
- Preview mapping

**Options:**
- Preserve original samples
- Create new instrument
- Auto-name based on source
- Velocity curve options

### Workflow

**Basic Stacking:**
1. Select instrument with multiple samples
2. Press "Stack All Samples"
3. Velocity mapping applied automatically
4. Play notes - velocity selects sample

**Manual Stacking:**
1. Open Stacker Dialog
2. Add samples in desired order
3. Adjust velocity splits if needed
4. Click "Create Stacked Instrument"
5. New instrument created

**Loop-to-Kit:**
1. Load drum loop
2. Press "Load&Slice&Isolate&Stack"
3. Auto-slicing detects hits
4. Each hit becomes velocity layer
5. Play velocity-sensitive drum kit

**Pattern Generation:**
1. Create stacked instrument
2. Write basic pattern
3. Use "Write Velocity Ramp Up/Down"
4. Or use "Write Velocity Random"
5. Dynamic velocity automatically

### Use Cases

**Multi-Sample Instruments:**
- Velocity-layered piano
- Dynamic drums
- Expressive guitars
- Round-robin samples

**Drum Kit Creation:**
- Convert loops to kits
- Build velocity-sensitive drums
- Create one-shot libraries
- Dynamic percussion

**Sound Design:**
- Layer textures by velocity
- Create evolving sounds
- Build complex instruments
- Dynamic sampling

**Live Performance:**
- Velocity-expressive instruments
- Dynamic playing response
- Natural-sounding drums
- Expressive controllers

**Mixing:**
- Velocity-based variation
- Dynamic sample selection
- Humanization
- Realistic performances

---


---

# Import/Export Suite

Comprehensive file format support for importing and exporting samples and instruments across multiple vintage samplers, hardware devices, and modern formats.

## Format Overview

**Supported Import Formats:**
- **REX/RX2** - Propellerhead ReCycle loops with slice markers
- **PTI/MTI** - Polyend Tracker instruments with slices and wavetables
- **ITI** - Impulse Tracker instruments
- **SF2** - SoundFont 2.0 sample banks
- **IFF/8SVX/16SV** - Amiga IFF audio (8-bit and 16-bit)
- **WT** - Wavetable files
- **WAV+CUE** - WAV files with cue point markers
- **OT** - Elektron Octatrack metadata files

**Supported Export Formats:**
- **PTI** - Polyend Tracker (melodic slices, drum slices, wavetables)
- **ITI** - Impulse Tracker instruments with samples
- **IFF/8SVX/16SV** - Amiga IFF audio formats
- **OT** - Elektron Octatrack (.ot metadata + WAV)
- **Digitakt** - Elektron Digitakt sample chains
- **WAV+CUE** - WAV files with embedded or separate cue markers
- **WT** - Wavetable export

---

## REX/RX2 Loader

**Source:** `PakettiREXLoader.lua`, `PakettiRX2Loader.lua` | **Format:** File Import Hook

Automatic import of Propellerhead ReCycle (REX/RX2) loop files with slice marker preservation.

### REX Loader (.rex)

**Import Method:** Drag & drop .rex file or File → Load Sample

Imports ReCycle 1.x format loops. The loader:
1. Detects and removes 256-frame headers before each slice
2. Reconstructs clean audio without artifacts
3. Creates slice markers at original positions
4. Applies Paketti loader preferences to all slices

**Features:**
- **Automatic header removal** - Removes 256-frame headers that REX format inserts before slices
- **Slice marker preservation** - All original slice timing preserved
- **Mono/stereo support** - Handles both channel configurations
- **Paketti preferences applied** - Autofade, autoseek, interpolation, oversampling, NNA, loop settings
- **Instrument naming** - Uses filename (without extension) for instrument/sample names
- **Macro device creation** - Auto-creates *Instr. Macro device (unless disabled in preferences)

**Process:**
1. Loads REX file as AIFF into temp location
2. Scans for "REX " chunk at offset +1032
3. Reads slice offset table (up to 256 slices)
4. Calculates actual audio length (visible frames + header frames)
5. Removes headers in sequential order
6. Creates new sample without headers
7. Inserts slice markers at corrected positions
8. Applies loader preferences to base sample and all slice samples

**Technical Details:**
- Header length: 256 frames per slice
- Max slices: 255 (Renoise limit)
- Slice position calculation: `new_pos = original_pos - (slice_index * 256)`

### RX2 Loader (.rx2)

**Import Method:** Drag & drop .rx2 file or File → Load Sample

Imports ReCycle 2.x format loops using external decoder (rex2decoder).

**Features:**
- **External decoder** - Uses rex2decoder binary (macOS/Windows/Linux+Wine)
- **Automatic permission handling** - macOS: removes quarantine, sets +x permission
- **Slice marker import** - Reads slice positions from decoder output
- **255 slice limit** - Truncates to 255 slices if file exceeds limit
- **Empty sample cleanup** - Removes spurious "Sample 01" entries after slice loading
- **Cross-platform** - macOS (native), Windows (native), Linux (Wine)

**Process:**
1. Creates new instrument with Paketti defaults
2. Runs rex2decoder to extract WAV + slice marker text file
3. Loads WAV into sample buffer
4. Parses slice marker text file (`insert_slice_marker(position)` format)
5. Inserts slice markers (max 255)
6. Applies Paketti loader preferences
7. Cleans up temporary files
8. Shows truncation warning if > 255 slices

**Platform-specific:**
- **macOS:** `rex2decoder_mac` + `REX Shared Library.bundle`
- **Windows:** `rex2decoder_win.exe`
- **Linux:** `rex2decoder_win.exe` via Wine (requires Wine installed)

**Error Handling:**
- Validates decoder exit code
- Checks output file existence (even on non-zero exit)
- Prevents multiple simultaneous imports
- Restores sample selection after import

### Batch RX2 to Octatrack Converter

**Source:** `PakettiRX2Loader.lua`

Batch converts a folder of RX2 files to Octatrack-compatible WAV + .ot files.

**Keybindings:**
- `Global:Paketti:Batch Convert RX2 to Octatrack (WAV+.ot)` ⌨️

**Menu:**
- `Main Menu:File:Paketti Export:Octatrack Batch Convert RX2 to OT (WAV+.ot)...` 📋
- `Sample Editor:Paketti:Octatrack:Batch Convert RX2 to OT (WAV+.ot)...` 📋

**How it Works:**
1. Select input folder containing RX2 files
2. Select output folder for WAV+.ot files
3. For each RX2 file:
   - Uses rex2decoder to extract audio and slice data
   - Parses slice marker positions from decoder output
   - Generates Octatrack-compatible .ot file with slice info
   - Copies WAV to output folder
4. Reports success/failure count

**Features:**
- **Recursive search** - Finds RX2 files in subfolders
- **Alphabetical processing** - Files processed in sorted order
- **64 slice limit** - Octatrack maximum, extras truncated
- **BPM from song** - Uses current Renoise BPM for tempo calculation
- **Cross-platform** - macOS, Windows, Linux (Wine)
- **Progress reporting** - Status bar updates during conversion
- **Detailed console log** - Full processing info in scripting terminal

**Output:**
- `filename.wav` - Audio file
- `filename.ot` - Octatrack slice metadata (832 bytes)

**Use Cases:**
- Convert legacy ReCycle sample packs to Octatrack format
- Batch prepare sliced loops for Elektron hardware
- Migrate REX library to modern hardware sampler format

---

## PTI/MTI Loader (Polyend Tracker)

**Source:** `PakettiPTILoader.lua` | **Format:** File Import Hook + Export Functions

Complete Polyend Tracker instrument format support with import, export, melodic slices, drum slices, and wavetables.

### PTI Import (.pti)

**Import Method:** Drag & drop .pti file or File → Load Sample

Imports Polyend Tracker instruments with full slice marker, loop, and wavetable support.

**Keybindings:**
- `Global:Paketti:PTI Export` ⌨️

**Features:**
- **Slice modes** - Detects Slice (4) vs Beat Slice (5) playback modes
- **Wavetable support** - Imports wavetable instruments with position mapping
- **Loop preservation** - Reads and applies loop start/end/mode
- **Mono/stereo auto-detection** - Analyzes PCM data size to determine channels
- **50% silence trimming** - Auto-trims silent padding with slice rescaling
- **Polyend slice processing** - Routes Slice mode (4) PTIs to Polyend slice switcher
- **B-1 base note mapping** - Slices auto-map from C-2 (Polyend standard)
- **ProcessSlicer progress** - Shows progress dialog for large samples

**Import Process:**
1. Reads 392-byte PTI header
2. Detects mono/stereo from PCM data size
3. Creates new instrument with Paketti defaults
4. Decodes 16-bit PCM data (stereo = separate L/R blocks, mono = interleaved)
5. Reads loop mode (OFF/Forward/Reverse/PingPong) and loop points
6. Detects wavetable mode (offset 20)
7. Reads slice markers (offset 280-375, max 48 slices)
8. Trims 50% silence if detected
9. Sets base sample to B-1, slice samples auto-map from C-2
10. Applies Paketti loader preferences

**Wavetable Import:**
- Reads wavetable window size (offset 64-65)
- Reads total positions (offset 68-69)  
- Reads active position (offset 88-89)
- Creates Sample 1 as full wavetable (looped)
- Creates individual samples for each position
- Sets velocity mapping: active position = 00-7F, others = 00-00

**Slice Note Mapping:**
- Slice mode PTIs print expected note mapping to console
- Base sample: B-1 (note 35)
- Slice 00: C-2 (note 36)
- Slice 01: C#2 (note 37)
- ...continues chromatically

### PTI Export (.pti)

**Keybindings:**
- `Global:Paketti:PTI Export` ⌨️
- `Global:Paketti:Export Subfolders as Melodic Slices` ⌨️
- `Global:Paketti:Export Subfolders as Drum Slices` ⌨️

**Export Features:**
- **Smart detection** - Auto-detects melodic slice vs drum slice vs regular sample
- **Slice mode selection** - Beat Slice (5) for drums, Slice (4) for melodic
- **Base sample export** - For sliced instruments, always exports Sample 1
- **Loop point mapping** - Converts Renoise loop points to PTI format
- **48 slice limit** - Truncates to 48 slices (PTI format limitation)
- **ProcessSlicer progress** - Shows progress for large exports

**Export Process:**
1. Detects export type (melodic slice/drum slice/regular)
2. Prompts for save location (.pti file)
3. Builds 392-byte PTI header with all metadata
4. Writes 16-bit PCM data (stereo = L block then R block, mono = sequential)
5. Applies slice marker conversion (frame → 0-65535 range)
6. Sets playback mode (0=1-Shot, 1=Forward, 2=Reverse, 3=PingPong, 4=Slice, 5=Beat Slice)

**PTI Header Structure:**
- Offset 0-1: "TI" marker
- Offset 21-51: Instrument name (31 bytes)
- Offset 60-63: Sample length (frames)
- Offset 76: Playback/loop mode
- Offset 78-79: Playback start
- Offset 80-81: Loop start (raw value 1-65534)
- Offset 82-83: Loop end (raw value 1-65534)
- Offset 84-85: Playback end
- Offset 280-375: Slice markers (48 × 2 bytes)
- Offset 376: Slice count
- Offset 377: Active slice

**Melodic Slice Detection:**
- Pattern: (n-1) samples with velocity 00-00 + 1 sample with velocity 00-7F
- Exports as Slice mode (4)
- Uses current_selected_slice for active slice

**Drum Slice Detection:**
- Sample 1 has slice markers
- Exports as Beat Slice mode (5)
- Active slice always 0

### MTI Import (.mti)

**Import Method:** Drag & drop .mti file

Imports Polyend Tracker multi-file instruments (MTI references separate WAV file).

**Features:**
- **WAV file pairing** - Searches for corresponding WAV file using naming patterns
- **Multiple search locations** - Checks same folder and ../Samples/ folder
- **Naming pattern matching** - Handles instrument_XX → instXX.wav patterns
- **Slice marker support** - Attempts to read slice data from MTI header
- **Loop preservation** - Reads and applies loop points

**WAV Search Pattern:**
1. `instrument_33.mti` → `inst33.wav` (same folder)
2. `instrument_33.mti` → `../Samples/inst33.wav`
3. Tries variations: `instr33.wav`, `instrument33.wav`, `inst_33.wav`, etc.

### Subfolder Batch Export

**Melodic Slice Export** - `Global:Paketti:Export Subfolders as Melodic Slices` ⌨️

Exports each subfolder as a melodic slice PTI (one file per subfolder).

**Process:**
1. Select parent folder
2. For each subfolder:
   - If 1 file: Create simple instrument (C-0 to B-9)
   - If 2-48 files: Create melodic slice setup (first sample 00-7F, others 00-00)
   - Export as PTI with subfolder name
3. Shows count of exported PTIs

**Drum Slice Export** - `Global:Paketti:Export Subfolders as Drum Slices` ⌨️

Exports each subfolder as a drum slice PTI using sample chaining.

**Process:**
1. Select parent folder
2. For each subfolder:
   - If 1 file: Export as simple PTI
   - If 2-48 files: Chain samples, insert slice markers, export as Beat Slice PTI
3. Creates sample chain by concatenating audio
4. Handles mono/stereo mixing intelligently

---

## Polyend Buddy (PTI File Browser)

**Source:** `PakettiPolyendSuite.lua`

**Keybindings:**
- `Global:Paketti:Polyend Buddy (PTI File Browser)` ⌨️

**MIDI:**
- `Paketti:Polyend Buddy (PTI File Browser)` 🎹

Dedicated PTI file browser and loader dialog with Polyend Tracker workflow integration.

**Features:**
- **PTI file browser** - Lists .pti files in selected directory
- **Quick preview** - Audition PTI instruments before loading
- **Batch operations** - Load multiple PTIs sequentially
- **Polyend integration** - Designed for Polyend Tracker sample library management
- **Recent folders** - Remembers last browsed locations

**Workflow:**
1. Open Polyend Buddy dialog
2. Browse to PTI library folder
3. Preview instruments
4. Load selected PTI into Renoise
5. Edit and export back to PTI

---

## Melodic Slice Export (Polyend)

**Source:** `PakettiPolyendMelodicSliceExport.lua`

**Keybindings:**
- `Global:Paketti:Melodic Slice Export (One-Shot)` ⌨️
- `Global:Paketti:Melodic Slice Create Chain` ⌨️
- `Global:Paketti:Melodic Slice Export Current` ⌨️

Specialized tools for creating and exporting melodic slice instruments for Polyend Tracker.

### Melodic Slice Export (One-Shot)

Creates PTI with each sample as separate melodic slice, no sample chaining.

**Process:**
1. Validates instrument has 2-48 samples
2. Sets first sample velocity to 00-7F (active)
3. Sets remaining samples velocity to 00-00 (inactive)
4. Exports PTI in Slice mode (4)

**Use Case:** Multi-sample melodic instruments where each sample is a different recording

### Melodic Slice Create Chain

Creates sample chain from multiple samples with slice markers.

**Process:**
1. Concatenates all samples into single audio buffer
2. Inserts slice markers at sample boundaries
3. Creates melodic slice velocity mapping
4. Ready for PTI export

**Use Case:** Convert multi-sample instrument to sliced format for Polyend

### Melodic Slice Export Current

Exports currently selected sample/slice as melodic slice PTI.

**Process:**
1. Identifies selected sample in melodic slice instrument
2. Sets that sample as active (00-7F)
3. Exports PTI with correct active slice metadata
4. Uses current_selected_slice for PTI header

**Use Case:** Export specific variation from multi-sample melodic instrument

---

## Polyend Slice Switcher

**Source:** `PakettiPolyendSliceSwitcher.lua`

**Keybindings:**
- `Global:Paketti:Polyend Slice Next` ⌨️
- `Global:Paketti:Polyend Slice Previous` ⌨️
- `Global:Paketti:Polyend Slice Dialog Toggle` ⌨️

**MIDI:**
- `Paketti:Polyend Slice Select (0-48) x[Knob]` 🎹

Real-time melodic slice switching for Polyend-style instruments using velocity mapping.

**Features:**
- **Velocity-based switching** - Changes which slice is active (00-7F vs 00-00)
- **MIDI knob control** - Continuous controller knob for slice selection
- **Visual feedback** - Dialog shows current slice and instrument info
- **Next/Previous navigation** - Step through slices sequentially
- **48 slice support** - Full Polyend Tracker slice count

**How It Works:**
1. Instrument has multiple samples (2-48)
2. Each sample mapped to same note range (C-0 to B-9)
3. Active sample has velocity 00-7F, others have 00-00
4. Switching changes which sample responds to velocity

**Use Case:**
- Live performance with melodic slice instruments
- Auditioning different takes/variations of same melodic phrase
- MIDI controller-based slice selection

**Dialog:**
- Shows current slice number (0-47)
- Shows total slice count
- Shows instrument name
- Real-time updates during switching

---

## ITI Export/Import (Impulse Tracker)

**Source:** `PakettiITIExport.lua`, `PakettiITIImport.lua`

Complete Impulse Tracker instrument format support with advanced sample properties and envelope preservation.

### ITI Export

**Keybindings:**
- `Global:Paketti:Export Instrument to ITI...` ⌨️
- `Sample Editor:Paketti:Export Instrument to ITI...` ⌨️

**Menu:**
- `Sample Editor:Paketti:Export:Export Instrument to ITI...` 📋

**Features:**
- **Full instrument export** - All samples and settings
- **Sample properties** - Volume, panning, transpose, finetune
- **Envelope support** - Volume and panning envelopes (planned)
- **Loop preservation** - Forward/bidirectional/off loop modes
- **Note mapping** - Sample keyzones and velocity layers
- **ADSR envelopes** - Attack, decay, sustain, release

**Export Dialog:**
- Instrument name
- Sample count
- Target filename
- Progress indicator

**ITI Format Support:**
- Header: "IMPI" marker
- Instrument name (26 chars)
- Sample count
- Envelope data
- Sample data (8-bit or 16-bit)

### ITI Import

**Import Method:** Drag & drop .iti file or File → Load Instrument

**Features:**
- **Automatic import** - File import hook integration
- **Sample properties** - Restores volume, panning, transpose, finetune
- **Loop restoration** - Applies loop points and modes
- **Envelope restoration** - Volume and panning envelopes (planned)
- **Naming** - Uses instrument name from ITI file

**Process:**
1. Reads IMPI header
2. Validates format
3. Creates new instrument
4. Loads samples with properties
5. Applies envelopes
6. Sets note mapping

---

## SF2 Loader (SoundFont)

**Source:** `PakettiSF2Loader.lua` | **Format:** File Import Hook

**Import Method:** Drag & drop .sf2 file

SoundFont 2.0 bank loader with preset and sample extraction.

**Features:**
- **Automatic import** - File import hook integration
- **Preset extraction** - Imports presets as Renoise instruments
- **Multi-sample support** - Creates proper sample layers
- **Loop preservation** - Reads and applies loop points
- **Velocity layers** - Preserves velocity-mapped samples
- **Keyzone mapping** - Applies proper note ranges

**Import Process:**
1. Reads SF2 RIFF structure
2. Parses INFO, sdta, and pdta chunks
3. Extracts preset list
4. Shows preset selection dialog
5. Loads selected preset(s) as instruments
6. Maps samples to keyzones with correct properties

**SF2 Format Support:**
- RIFF/INFO/sdta/pdta chunks
- Preset/instrument generators
- Sample generators
- Modulator support (basic)

---

## Octatrack OctaCycle Generator

**Source:** `PakettiOctaCycle.lua`

**Keybindings:**
- `Sample Editor:Paketti:Generate OctaCycle for Octatrack` ⌨️
- `Sample Editor:Paketti:Quick OctaCycle for Octatrack` ⌨️
- `Sample Editor:Paketti:Export OctaCycle to Octatrack` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Generate OctaCycle...` 📋
- `Sample Editor:Paketti:Octatrack:Quick OctaCycle (C, Oct 1-7)` 📋
- `Sample Editor:Paketti:Octatrack:Export OctaCycle to Octatrack` 📋
- `Sample Mappings:Paketti:Octatrack:Generate OctaCycle...` 📋
- `Sample Mappings:Paketti:Octatrack:Quick OctaCycle (C, Oct 1-7)` 📋
- `Sample Mappings:Paketti:Octatrack:Export OctaCycle to Octatrack` 📋

Generates pitch-shifted sample sets for Elektron Octatrack's OctaCycle feature (chromatic sample playback).

### Generate OctaCycle (Full Dialog)

**Process:**
1. Opens dialog with pitch/octave/note selection
2. User selects root note and octave range
3. Generates 12-84 samples (1-7 octaves)
4. Each sample pitch-shifted chromatically
5. Maps samples to keyboard chromatically

**Options:**
- Root note selection (C, C#, D, etc.)
- Octave count (1-7 octaves)
- Pitch algorithm (cubic interpolation)
- Note naming format

### Quick OctaCycle (C, Oct 1-7)

One-click OctaCycle generation with preset settings:
- Root note: C
- Octave range: 1-7 octaves (84 samples)
- Standard chromatic mapping

**Use Case:** Fast OctaCycle generation for most common use case

### Export OctaCycle to Octatrack

**Features:**
- Exports OctaCycle instrument as individual WAV files
- Creates matching .ot metadata files
- Organizes in Octatrack-compatible folder structure
- Adds sample length, loop, and slice metadata

**Export Structure:**
```
OctaCycle_InstrumentName/
  C-1.wav
  C-1.ot
  C#1.wav
  C#1.ot
  ...
  C-7.wav
  C-7.ot
```

---

## Octatrack Export Suite

**Source:** `PakettiOTExport.lua`

**Keybindings:**
- `Sample Editor:Paketti:Export to Octatrack (.WAV+.ot)` ⌨️
- `Sample Editor:Paketti:Export to Octatrack (.ot)` ⌨️
- `Sample Editor:Paketti:Import Octatrack (.ot)` ⌨️
- `Sample Editor:Paketti:Debug Octatrack (.ot)` ⌨️
- `Sample Editor:Paketti:Octatrack Generate Drumkit (Smart Mono/Stereo)` ⌨️
- `Sample Editor:Paketti:Octatrack Generate Drumkit (Force Mono)` ⌨️
- `Sample Editor:Paketti:Octatrack Generate Drumkit (Play to End)` ⌨️
- `Sample Editor:Paketti:Octatrack Set .ot Loop to Slice` ⌨️

**Menu:** 16 menu entries across Sample Editor, Sample Mappings

Comprehensive Elektron Octatrack metadata and sample export with drumkit generation.

### Export to Octatrack (.WAV+.ot)

Exports sample with matching .ot metadata file.

**Features:**
- **Slice marker export** - Converts Renoise slices to Octatrack slices
- **Loop metadata** - Loop start/end/mode
- **BPM detection** - Auto-detects and writes BPM
- **Gain/trim metadata** - Start/end trim points, gain
- **Tempo multiplier** - Speed/pitch relationship
- **Sample attributes** - Bit depth, sample rate, length

**.ot Format:**
- Binary format with Octatrack-specific structure
- Slice data (up to 64 slices)
- Loop points (frames)
- Playback parameters
- BPM and tempo settings

### Export to Octatrack (.ot only)

Exports only .ot metadata file (no WAV export).

**Use Case:** Update metadata for existing Octatrack samples

### Import Octatrack (.ot)

**Features:**
- Reads .ot metadata file
- Applies slice markers to Renoise sample
- Restores loop points
- Shows BPM and tempo data
- Validates slice positions

**Process:**
1. Select .ot file
2. Reads binary structure
3. Applies to currently selected sample
4. Creates slice markers
5. Sets loop points

### Generate Drumkit (Smart Mono/Stereo)

Creates Octatrack-compatible drumkit from instrument.

**Features:**
- **Smart channel handling** - Preserves stereo, converts mono as needed
- **Slice-based export** - Each slice becomes separate WAV + .ot
- **Note mapping** - Chromatic mapping from C-0
- **Metadata generation** - Full .ot files for each slice

**Export Structure:**
```
DrumkitName/
  01_KickName.wav
  01_KickName.ot
  02_SnareName.wav
  02_SnareName.ot
  ...
```

### Generate Drumkit (Force Mono)

Same as Smart mode but forces all samples to mono (summed L+R).

**Use Case:** Octatrack Mk1 with limited sample memory

### Generate Drumkit (Play to End)

Exports drumkit with "play to end" mode (no loop).

**Use Case:** One-shot drum sounds (kicks, snares, etc.)

### Set .ot Loop to Slice

Sets Octatrack loop points to match slice boundaries.

**Process:**
1. Select slice in Renoise
2. Reads slice start/end frames
3. Creates .ot file with loop = slice range
4. Useful for isolating specific slices in Octatrack

---
> *Deep hardware integration like Octatrack/Digitakt export takes serious development time.*
> *If Paketti improves your workflow, consider [supporting on Patreon →](http://patreon.com/esaruoho)*
---

## Digitakt Export Suite

**Source:** `PakettiDigitakt.lua`

**Keybindings:**
- `Global:Paketti:Export Digitakt Sample Chain...` ⌨️
- `Global:Paketti:Export Digitakt Quick Export (Digitakt Mono)` ⌨️
- `Global:Paketti:Export Digitakt Quick Export (Digitakt 2 Stereo)` ⌨️
- `Global:Paketti:Export Digitakt Quick Export (Chain Mode)` ⌨️
- `Global:Paketti:Digitakt Export Sample Chain...` ⌨️
- `Sample Editor:Paketti:Digitakt Export Sample Chain...` ⌨️
- `Sample Editor:Paketti:Digitakt Quick Export Mono` ⌨️
- `Sample Editor:Paketti:Digitakt Quick Export Stereo` ⌨️
- `Sample Editor:Paketti:Digitakt Quick Export Chain` ⌨️

**Menu:**
- `Sample Editor:Paketti:Digitakt:Export Sample Chain...` 📋
- `Sample Editor:Paketti:Digitakt:Quick Export (Digitakt Mono)` 📋
- `Sample Editor:Paketti:Digitakt:Quick Export (Digitakt 2 Stereo)` 📋
- `Sample Editor:Paketti:Digitakt:Quick Export (Chain Mode)` 📋
- `Instrument Box:Paketti:Digitakt:Export Sample Chain...` 📋
- `DSP Device:Paketti:Digitakt:Export Sample Chain...` 📋
- `Mixer:Paketti:Digitakt:Export Sample Chain...` 📋

Elektron Digitakt sample chain and slice export with Digitakt/Digitakt 2 format support.

### Export Sample Chain (Full Dialog)

**Features:**
- **Format selection** - Digitakt Mono / Digitakt 2 Stereo / Chain Mode
- **Slice-based export** - Chains slices into single WAV
- **Start point markers** - Embeds cue points for Digitakt slice triggering
- **Sample count limit** - Max 127 slices (Digitakt limit)
- **Mono summing** - L+R mix for original Digitakt
- **Stereo preservation** - Full stereo for Digitakt 2

**Dialog Options:**
- Export format (Mono/Stereo/Chain)
- Target filename
- Slice range selection
- Normalize option

**Export Process:**
1. Validates instrument has slices
2. Opens export dialog
3. Chains slices into single audio buffer
4. Adds silence padding between slices (optional)
5. Embeds cue point markers
6. Exports as WAV
7. Shows slice count and total duration

### Quick Export (Digitakt Mono)

One-click export for original Digitakt (mono, 127 slices max).

**Process:**
- Chains all slices
- Sums to mono
- Adds cue points
- Exports with Digitakt-compatible naming

### Quick Export (Digitakt 2 Stereo)

One-click export for Digitakt 2 (stereo, 127 slices max).

**Process:**
- Chains all slices in stereo
- Adds cue points
- Exports with Digitakt 2-compatible naming

### Quick Export (Chain Mode)

Simple sample chain without cue points.

**Use Case:** Manual slice assignment in Digitakt

**Digitakt Format Requirements:**
- **Original Digitakt:** Mono only, 127 samples max, 48kHz/16-bit
- **Digitakt 2:** Stereo support, 127 samples max, 48kHz/16-bit
- **Cue points:** WAV "cue " chunk with sample start positions

---

## IFF/8SVX/16SV Loader (Amiga)

**Source:** `PakettiIFFLoader.lua`

**Keybindings:**
- `Global:Paketti:Load IFF Sample File...` ⌨️
- `Global:Paketti:Convert IFF to WAV...` ⌨️
- `Global:Paketti:Convert WAV to IFF...` ⌨️
- `Global:Paketti:Save Current Sample as IFF...` ⌨️
- `Global:Paketti:Save Current Sample as 8SVX...` ⌨️
- `Global:Paketti:Save Current Sample as 16SV...` ⌨️
- `Global:Paketti:Batch Convert WAV/AIFF to 8SVX...` ⌨️
- `Global:Paketti:Batch Convert WAV/AIFF to 16SV...` ⌨️
- `Global:Paketti:Batch Convert IFF/8SVX/16SV to WAV...` ⌨️
- `Global:Paketti:Batch Convert WAV to IFF...` ⌨️

Complete Amiga IFF/8SVX/16SV format support with import, export, and batch conversion.

### Load IFF Sample File

**Features:**
- **8SVX support** - 8-bit signed samples
- **16SV support** - 16-bit signed samples
- **IFF-ILBM support** - Amiga image file detection (skips)
- **VHDR chunk** - Reads sample rate, loop points, volume
- **NAME chunk** - Reads sample name
- **ANNO chunk** - Reads annotation/comment

**Import Process:**
1. Reads IFF FORM header
2. Validates FORM type (8SVX/16SV)
3. Parses VHDR (voice header)
4. Reads BODY chunk (sample data)
5. Creates Renoise sample
6. Applies loop points
7. Sets sample name

**8SVX Format:**
- 8-bit signed samples (-128 to 127)
- Max sample rate: 28867 Hz (Amiga hardware limit)

**16SV Format:**
- 16-bit signed samples
- No compression
- Higher sample rates supported

### Convert IFF to WAV

Batch conversion from IFF/8SVX/16SV to WAV.

**Features:**
- Folder selection for batch processing
- Recursive directory scanning
- Maintains folder structure
- Creates WAV folder for output

### Convert WAV to IFF

Batch conversion from WAV to IFF/8SVX.

**Features:**
- 8-bit or 16-bit output
- Loop point preservation
- Sample rate conversion

### Save Current Sample as IFF/8SVX/16SV

**Features:**
- **Format selection** - IFF (auto-detect), 8SVX (8-bit), 16SV (16-bit)
- **Loop preservation** - Writes VHDR loop points
- **Name embedding** - Embeds sample name in NAME chunk
- **Volume** - Writes 0-64 volume in VHDR

**8SVX Output:**
```
FORM 8SVX
  VHDR (voice header - 20 bytes)
  NAME (sample name)
  BODY (sample data)
```

### Batch Conversion Tools

**Batch Convert WAV/AIFF to 8SVX** - Converts all WAV/AIFF files in folder to 8-bit IFF

**Batch Convert WAV/AIFF to 16SV** - Converts all WAV/AIFF files in folder to 16-bit IFF

**Batch Convert IFF/8SVX/16SV to WAV** - Converts all IFF files in folder to WAV

**Batch Convert WAV to IFF** - Converts all WAV files to IFF (auto-detect 8/16-bit)

**Batch Features:**
- Progress reporting
- Error handling per file
- Skips already converted files
- Maintains directory structure

---

## Wavetable Import/Export

**Source:** `PakettiWTImport.lua`

**Keybindings:**
- `Global:Paketti:Wavetable Control` ⌨️
- `Global:Paketti:Export Wavetable` ⌨️
- `Global:Paketti:Import Wavetable` ⌨️

**MIDI:**
- `Paketti:Wavetable Sample Selector x[Knob]` 🎹

Wavetable import/export with position switching and MIDI control.

### Wavetable Control

**Features:**
- **Position browser** - Shows all wavetable positions (samples)
- **MIDI switching** - Use MIDI knob to switch between positions
- **Visual feedback** - Displays current position and total count
- **Velocity mapping** - Switches active position using velocity layers
- **Real-time switching** - Changes during playback

**Dialog:**
- Wavetable name
- Current position (0-n)
- Total positions
- Position list with names
- MIDI learn button

### Export Wavetable

**Features:**
- **Multi-sample export** - Exports all samples as wavetable positions
- **Loop preservation** - Maintains loop points
- **Position metadata** - Embeds position count and window size
- **WAV or custom format** - Standard WAV with metadata chunks

**Process:**
1. Validates instrument has multiple samples
2. Checks sample lengths match (wavetable requirement)
3. Prompts for filename
4. Exports each sample as wavetable position
5. Adds metadata chunk with position info

### Import Wavetable

**Features:**
- **Position detection** - Auto-detects wavetable positions
- **Velocity mapping** - Maps positions to velocity layers
- **Loop setup** - Sets appropriate loop points
- **Position naming** - Names samples by position

**Process:**
1. Select wavetable file
2. Detects position count
3. Creates instrument
4. Loads each position as sample
5. Maps to velocity or note layers
6. Sets loops for wavetable playback

### MIDI Wavetable Sample Selector

**MIDI:** `Paketti:Wavetable Sample Selector x[Knob]` 🎹

**Features:**
- **Continuous control** - MIDI knob/fader control
- **Position switching** - Velocity-based position selection
- **Real-time** - Changes during playback
- **0-127 mapping** - Maps MIDI CC 0-127 to sample positions

**Use Case:**
- Live wavetable position morphing
- Hardware wavetable synthesis emulation
- Wavetable scanning with MIDI controller

---

## WAV Cue Extract/Export

**Source:** `PakettiWavCueExtract.lua`

**Keybindings:**
- `Global:Paketti:Load WAV with CUE Markers...` ⌨️
- `Sample Editor:Paketti:Load WAV with CUE Markers...` ⌨️
- `Global:Paketti:Export WAV with CUE File...` ⌨️
- `Global:Paketti:Export WAV with Embedded CUE Headers...` ⌨️
- `Sample Editor:Paketti:Export WAV with CUE File...` ⌨️
- `Sample Editor:Paketti:Export WAV with Embedded CUE Headers...` ⌨️

**Menu:**
- `Main Menu:File:Load WAV with CUE Markers...` 📋
- `Main Menu:File:Export WAV with CUE File...` 📋
- `Main Menu:File:Export WAV with Embedded CUE Headers...` 📋
- `Sample Editor:Paketti:Load WAV with CUE Markers...` 📋
- `Sample Editor:Paketti:Export WAV with CUE File...` 📋
- `Sample Editor:Paketti:Export WAV with Embedded CUE Headers...` 📋
- `Sample Navigator:Paketti:Load WAV with CUE Markers...` 📋
- `Sample Navigator:Paketti:Export WAV with CUE File...` 📋
- `Sample Navigator:Paketti:Export WAV with Embedded CUE Headers...` 📋
- `Main Menu:Tools:Paketti:!Sample Editor:Load WAV with CUE Markers...` 📋
- `Main Menu:Tools:Paketti:!Sample Editor:Export WAV with CUE File...` 📋
- `Main Menu:Tools:Paketti:!Sample Editor:Export WAV with Embedded CUE Headers...` 📋

Import and export WAV files with cue point markers (slice markers) using embedded headers or separate .cue files.

### Load WAV with CUE Markers

**Features:**
- **Embedded cue chunks** - Reads WAV "cue " chunk
- **Separate .cue files** - Reads companion .cue text file
- **Slice marker creation** - Converts cue points to Renoise slices
- **Multiple cue formats** - Supports various cue file syntaxes
- **Frame-accurate** - Preserves exact cue point positions

**Import Process:**
1. Select WAV file
2. Searches for "cue " chunk in WAV header
3. OR looks for .cue file in same directory
4. Parses cue point positions
5. Loads WAV as sample
6. Creates slice markers at cue positions
7. Applies Paketti loader preferences

**Cue Chunk Format:**
```
cue  [chunk size]
[cue point count]
[cue point 1: ID, position, chunk ID, etc.]
[cue point 2: ...]
```

**Cue File Format (.cue):**
```
FILE "sample.wav" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    INDEX 01 00:01:45
```

### Export WAV with CUE File

Exports sample with separate .cue text file.

**Features:**
- **Slice to cue conversion** - Converts Renoise slices to cue points
- **Frame positions** - Writes exact frame positions
- **Time codes** - Also writes time code format (MM:SS:FF)
- **Companion file** - Creates .cue file next to WAV

**Export Process:**
1. Select save location
2. Exports sample as WAV
3. Writes .cue file with slice positions
4. Uses standard cue sheet format

**Output:**
```
sample.wav
sample.cue
```

### Export WAV with Embedded CUE Headers

Embeds cue points directly in WAV file.

**Features:**
- **Self-contained** - No separate .cue file needed
- **"cue " chunk** - Standard RIFF/WAV cue chunk format
- **Compatible** - Works with other DAWs and samplers
- **Frame-accurate** - Preserves exact positions

**Process:**
1. Select save location
2. Exports WAV with standard audio data
3. Adds "cue " chunk to RIFF header
4. Writes cue point list with frame positions

**Use Case:**
- Sharing sliced samples with other DAWs
- Exporting drum breaks with slice markers
- Archiving sliced samples with metadata intact

---

## Import/Export Format Summary

| Format | Import | Export | Slices | Loops | Stereo | Notes |
|--------|--------|--------|--------|-------|--------|-------|
| **REX** | ✓ | - | ✓ | - | ✓ | ReCycle 1.x, header removal |
| **RX2** | ✓ | - | ✓ | - | ✓ | ReCycle 2.x, external decoder |
| **PTI** | ✓ | ✓ | ✓ | ✓ | ✓ | Polyend Tracker, wavetables, melodic/drum slices |
| **MTI** | ✓ | - | ✓ | ✓ | ✓ | Polyend multi-file, requires WAV |
| **ITI** | ✓ | ✓ | - | ✓ | ✓ | Impulse Tracker, envelopes |
| **SF2** | ✓ | - | - | ✓ | ✓ | SoundFont 2.0, presets |
| **IFF/8SVX** | ✓ | ✓ | - | ✓ | - | Amiga 8-bit |
| **16SV** | ✓ | ✓ | - | ✓ | - | Amiga 16-bit |
| **OT** | ✓ | ✓ | ✓ | ✓ | ✓ | Octatrack metadata, drumkits |
| **Digitakt** | - | ✓ | ✓ | - | ✓ | Sample chains, cue points |
| **WT** | ✓ | ✓ | - | ✓ | ✓ | Wavetables, position switching |
| **WAV+CUE** | ✓ | ✓ | ✓ | - | ✓ | Embedded or separate cue files |

---

## Hardware Compatibility

**Polyend Tracker:**
- PTI/MTI import/export
- Melodic slices (velocity 00-7F switching)
- Drum slices (Beat Slice mode)
- Wavetables (position mapping)
- 48 slice maximum

**Elektron Octatrack:**
- .ot metadata files
- Slice marker export (64 slices)
- OctaCycle chromatic sample sets
- Drumkit generation
- Loop and BPM metadata

**Elektron Digitakt:**
- Sample chain export
- Cue point markers
- 127 slice maximum
- Mono (Digitakt) or Stereo (Digitakt 2)

**Amiga:**
- IFF/8SVX/16SV formats
- Classic tracker compatibility
- ProTracker/OctaMED sample exchange

**Impulse Tracker:**
- ITI instrument format
- Envelope support
- DOS tracker compatibility
- Sample properties preservation


---

# Renoise 3.5+ Features (API 6.2+)

**Source:** `Paketti35.lua` | **Requirements:** Renoise 3.5 or higher

Features that require Renoise 3.5 (API version 6.2) or higher. These features will not work in earlier versions.

## Pattern Line Triggering

### Trigger Pattern Line Scrub (MIDI CC)

**MIDI:** `Paketti:Trigger Pattern Line Scrub (CC)` 🎹

Smooth MIDI CC-based scrubbing through pattern lines. Maps MIDI CC value (0-127) to pattern length and triggers each line.

**Features:**
- Continuous scrubbing with MIDI knob/fader
- Auto-scales to current pattern length
- Shows hex line number in status
- Perfect for live performance and DJ-style pattern scrubbing

**Use Case:** Control pattern playback position with a MIDI controller knob in real-time

### Individual Pattern Line Triggers (512 Commands)

**Keybindings:** `Global:Paketti:Trigger Pattern Line 001 (00)` through `Global:Paketti:Trigger Pattern Line 512 (1FF)` ⌨️

**MIDI:** Same 512 MIDI mappings available 🎹

**Requires:** `PakettiTriggerPatternLineCommands` preference enabled

Creates 512 individual keybindings + MIDI mappings for triggering specific pattern lines. Each command triggers its designated line and shows both decimal and hex line numbers.

**Pattern:** `Trigger Pattern Line XXX (HEX)`
- 001 (00) = Line 001
- 064 (3F) = Line 064  
- 256 (FF) = Line 256
- 512 (1FF) = Line 512

**Features:**
- Validates pattern length before triggering
- Shows status for each trigger
- Hex notation for tracker users
- Can be mapped to hardware controllers

**Warning:** This creates 1,024 total bindings (512 keybindings + 512 MIDI). Only enable if you need precise line-by-line control.

## Sample Properties Control

### Sample Properties Visibility

**Keybindings:**
- `Global:Paketti:Hide Sample Properties` ⌨️
- `Global:Paketti:Show Sample Properties` ⌨️
- `Global:Paketti:Toggle Sample Properties` ⌨️

Quick show/hide/toggle for Sample Properties panel in Sample Editor.

## Instrument Properties Control

### All Instrument Properties

**Keybindings:**
- `Global:Paketti:Hide All Instrument Properties` ⌨️
- `Global:Paketti:Show All Instrument Properties` ⌨️

Shows or hides ALL instrument property sections simultaneously:
- Volume/Transpose
- Trigger Options
- Scale Options
- Plugin
- Plugin Program
- MIDI
- MIDI Program
- Macros
- Phrases

**Use Case:** Quickly declutter instrument view or show everything for editing.

## Disk Browser Control

### Disk Browser Visibility

**Keybinding:** `Global:Paketti:Show/Hide Disk Browser` ⌨️

Toggles disk browser panel visibility.

### Disk Browser Category Cycling

**Keybindings:**
- `Global:Paketti:Cycle Disk Browser Category` ⌨️ - Cycles through all 4 categories
- `Global:Paketti:Set Disk Browser Category to Songs` ⌨️ - Category 1
- `Global:Paketti:Set Disk Browser Category to Instruments` ⌨️ - Category 2
- `Global:Paketti:Set Disk Browser Category to Samples` ⌨️ - Category 3
- `Global:Paketti:Set Disk Browser Category to Other` ⌨️ - Category 4

**Features:**
- Auto-shows disk browser if hidden
- Cycles: Songs → Instruments → Samples → Other → Songs
- Direct category selection

**Categories:**
1. Songs (.xrns files)
2. Instruments (.xrni files)
3. Samples (audio files)
4. Other (all other files)

## Instrument Box Slot Size

**Requirements:** Experimental feature - may not be available in all builds

### Slot Size Controls

**Keybindings:**
- `Global:Paketti:Increase Instrument Box Slot Size` ⌨️
- `Global:Paketti:Decrease Instrument Box Slot Size` ⌨️
- `Global:Paketti:Set Instrument Box Slot Size 1 (Normal)` ⌨️
- `Global:Paketti:Set Instrument Box Slot Size 2 (Small)` ⌨️
- `Global:Paketti:Set Instrument Box Slot Size 3 (Large)` ⌨️
- `Global:Paketti:Toggle Instrument Box Slot Size 1 (Normal)` ⌨️
- `Global:Paketti:Toggle Instrument Box Slot Size 2 (Small)` ⌨️
- `Global:Paketti:Toggle Instrument Box Slot Size 3 (Large)` ⌨️

Controls the size of instrument slots in the Instrument Box.

**Sizes:**
1. **Normal** - Standard slot size
2. **Small** - Compact view (more instruments visible)
3. **Large** - Expanded view (easier clicking)

**Note:** If this feature is not available in your Renoise build, commands will show a status message and do nothing.

## Right Frame Control

**Keybinding:** `Global:Paketti:Show/Hide Right Frame` ⌨️

Toggles the right frame visibility (Instrument Box, Sample Navigator, etc.).

## Phrase Editor Column Control

### Expose and Select Columns

**Keybindings:**
- `Phrase Editor:Paketti:Expose and Select Next Column` ⌨️
- `Phrase Editor:Paketti:Hide Current and Select Previous Column` ⌨️

Smart column management in Phrase Editor - works for both Note Columns and Effect Columns.

**For Note Columns:**
- Exposes next note column and selects it
- Max 12 note columns
- Auto-selects the newly exposed column

**For Effect Columns:**
- Exposes next effect column and selects it
- Max 8 effect columns
- When hiding last effect column, deselects effect column focus

**Use Case:** Navigate and expose phrase columns without mouse, similar to pattern editor workflow.

## Sync Mode Control

**Keybindings:**
- `Global:Paketti:Set Sync Mode to (Internal)` ⌨️
- `Global:Paketti:Set Sync Mode to (Midi Clock)` ⌨️
- `Global:Paketti:Set Sync Mode to (Ableton Link)` ⌨️
- `Global:Paketti:Set Sync Mode to (Jack)` ⌨️ - Linux only

**Menu:** `Main Menu:Paketti:Set Sync Mode to (Jack)` 📋 - Linux only

Quick switching between transport sync modes.

**Sync Modes:**
- **Internal** - Renoise controls tempo (standalone)
- **MIDI Clock** - Sync to external MIDI clock
- **Ableton Link** - Network sync with Ableton Live and other Link-enabled apps
- **Jack** - Jack transport sync (Linux only)

## Metronome Volume Control

**Keybindings:**
- `Global:Paketti:Metronome Volume Up` ⌨️ - Increase by 0.1
- `Global:Paketti:Metronome Volume Down` ⌨️ - Decrease by 0.1
- `Global:Paketti:Metronome Volume Reset` ⌨️ - Reset to 0 dB
- `Global:Paketti:Set Metronome Volume to (0) Silence` ⌨️

**MIDI:** `Paketti:Metronome Volume x[Knob]` 🎹

Fine control over metronome click volume.

**Features:**
- Range: Silence to +6 dB
- Shows dB value in status
- MIDI knob for continuous control (0-127 → Silence to +6 dB)
- Clamped to safe range

**Default:** 0 dB (1.0 linear)

## MIDI Input Octave Follow

**Keybindings:**
- `Global:Paketti:Midi Input Octave Follow Enable` ⌨️
- `Global:Paketti:Midi Input Octave Follow Disable` ⌨️
- `Global:Paketti:Midi Input Octave Follow Toggle` ⌨️

**MIDI:**
- `Paketti:Midi Input Octave Follow Enable x[Trigger]` 🎹
- `Paketti:Midi Input Octave Follow Disable x[Trigger]` 🎹
- `Paketti:Midi Input Octave Follow Toggle x[Toggle]` 🎹
- `Paketti:Midi Input Octave Follow x[Button]` 🎹

Enables/disables MIDI input following the current octave setting in Renoise.

**When Enabled:**
- MIDI keyboard respects Renoise octave setting
- Changing octave in Renoise shifts MIDI input range
- Useful for staying in same editing range

**When Disabled:**
- MIDI keyboard plays at absolute octave
- Renoise octave setting doesn't affect MIDI input
- Useful for consistent MIDI keyboard response

---

# eSpeak Text-to-Speech Generator

**Source:** `PakettieSpeak.lua` | **Requirements:** eSpeak or eSpeak-ng installed

Generate speech samples from text using eSpeak text-to-speech engine. Perfect for vocal samples, announcements, experimental music, and sound design.

## eSpeak Text-to-Speech Dialog

**Keybinding:** `Global:Paketti:Paketti eSpeak Text-to-Speech Dialog...` ⌨️

Opens full eSpeak dialog with extensive language, voice, and parameter control.

**Features:**
- **130+ Languages** - Including English (US/UK), Spanish, French, German, Japanese, Chinese, etc.
- **80+ Voices** - Male, female, robotic, whisper, special character voices
- **Pitch Control** - 0-99 range for voice pitch
- **Speed Control** - Words per minute (80-500 WPM)
- **Sample Rate** - 22050 Hz to 192000 Hz
- **Text File Loading** - Load .txt files for batch processing
- **Live Preview** - Generate and audition before committing
- **Multi-line Support** - Process entire text files line-by-line

**Dialog Sections:**

### Text Input
- Large text field for speech content
- Load from .txt file button
- Line count display
- Multi-line editing

### Language Selection
- Chooser with 130+ languages
- Includes regional variants (en-US, en-GB, etc.)
- Constructed languages (Klingon, Lojban, Esperanto)
- Ancient languages (Latin, Ancient Greek)

### Voice Selection
- 80+ voice presets
- Character voices (Demonic, Anxious Andy, etc.)
- Robotic variants
- Whisper modes
- Gender options

### Parameters
- **Pitch:** 0-99 (default 50)
- **Speed:** 80-500 WPM (default 175)
- **Sample Rate:** 22050/44100/48000/88200/96000/192000 Hz

### Actions
- **Generate Sample** - Creates sample in new instrument
- **Generate Selection** - Creates sample from selected text only
- **Generate Row** - Creates sample for specific line number
- **Refresh** - Reload text from file

## Quick Generate Functions

### Generate Sample (No Dialog)

**Keybinding:** `Global:Paketti:Paketti eSpeak Generate Sample` ⌨️

Generates speech sample using last dialog settings without opening dialog.

**Use Case:** Rapid generation of multiple samples with same voice/settings

### Generate Selection

**Keybinding:** `Global:Paketti:Paketti eSpeak Generate Selection` ⌨️

Generates sample from selected text in dialog.

**Use Case:** Extract specific phrases from larger text

### Generate Row (01-16)

**Keybindings:** 16 keybindings:
- `Global:Paketti:Paketti eSpeak Generate Row 01` ⌨️
- `Global:Paketti:Paketti eSpeak Generate Row 02` ⌨️
- ...
- `Global:Paketti:Paketti eSpeak Generate Row 16` ⌨️

Generates speech for specific line number from loaded text file.

**Use Case:** 
- Create drum kit from text list (one word per line)
- Generate phrase variations
- Build dialogue samples sequentially

**Workflow:**
1. Load text file with numbered lines
2. Use Row 01-16 shortcuts to generate each line
3. Each line creates separate sample
4. Perfect for building sample kits from lists

### Refresh

**Keybinding:** `Global:Paketti:Paketti eSpeak Refresh` ⌨️

Reloads text from currently loaded text file.

**Use Case:** Edit text file externally, then refresh to see changes

## eSpeak Installation

**Requirements:**
- **Windows:** Download and install eSpeak from espeak.sourceforge.net
  - Default path: `C:\Program Files\espeak\espeak.exe`
- **macOS:** Install eSpeak-ng via Homebrew: `brew install espeak-ng`
  - Default path: `/opt/homebrew/bin/espeak-ng`
- **Linux:** Install via package manager: `apt install espeak-ng` or `dnf install espeak-ng`
  - Default path: `/usr/bin/espeak-ng`

**Preference:** Configure eSpeak executable path in Paketti preferences if installed in non-default location.

## Language Examples

**English Variants:**
- en-US (American)
- en-GB-x-rp (Received Pronunciation)
- en-GB-scotland (Scottish)
- en-029 (Caribbean)

**Asian Languages:**
- ja (Japanese)
- cmn (Mandarin Chinese)
- yue (Cantonese)
- ko (Korean)
- hi (Hindi)

**European Languages:**
- de (German)
- fr (French)
- es (Spanish)
- ru (Russian)
- pl (Polish)

**Constructed Languages:**
- eo (Esperanto)
- ia (Interlingua)
- piqd (Klingon)
- jbo (Lojban)

## Voice Examples

**Standard Voices:**
- Mike, Paul, Dennis - Male voices
- Linda, Annie, Alicia - Female voices

**Character Voices:**
- Demonic - Low, menacing
- Whisper/Whisperf - Whispered speech
- RoboSoft - Robotic, soft
- Croak - Croaky, rough

**Special:**
- Klatt1-6 - Formant synthesis variants
- Fast - High-speed speech
- Storm - Dramatic voice

## Use Cases

**Music Production:**
- Vocal snippets for electronic music
- Robotic vocals for genres like electro/techno
- Background announcements
- Rhythmic vocal textures

**Sound Design:**
- Robot dialogue
- Computer voice feedback
- Alien/creature voices (pitch shifted)
- Automated announcements

**Experimental:**
- Text-based composition
- Found text as lyrics
- Multiple language layering
- Glitch vocals (manipulate after generation)

**Sampling:**
- Build drum kits from phonemes
- Create phrase libraries
- Generate call-and-response samples
- Make vocal one-shots

---


---

# Experimental & Verify Features

**Source:** `PakettiExperimental_Verify.lua` | **Features:** 104+

Advanced experimental features - EQ control, sample rotation, effect randomization, track solo/mute systems, Impulse Tracker workflows, and pattern manipulation.

## EQ10 XY Control Dialog

**Keybinding:** `Global:Paketti:Show EQ10 XY Control Dialog...` ⌨️

Visual XY pad controller for all 10 bands of Renoise's EQ 10 device with real-time parameter manipulation.

**Features:**
- **10 XY Pads** - One for each EQ band
- **X-Axis:** Frequency control (logarithmic)
- **Y-Axis:** Gain control (-12 to +12 dB)
- **Bandwidth control** - Dedicated knobs below each XY pad
- **Real-time updates** - Changes immediately affect the EQ
- **Auto-device creation** - Creates EQ 10 if not present
- **Toggle behavior** - Open/close with same keybinding

**How It Works:**
1. Opens dialog with 10 XY pads in a single row
2. Each pad controls frequency (horizontal) and gain (vertical) for one band
3. Bandwidth knobs below each pad control Q factor
4. Device is automatically maximized in DSP chain
5. All changes apply immediately to the EQ 10 device

**Use Case:** Quick visual EQ adjustments without navigating device parameters.

## Sample Beatsync Lines

**Keybindings:** 16 keybindings (02-16):
- `Global:Paketti:Set Selected Sample Beatsync Lines to 2` ⌨️
- `Global:Paketti:Set Selected Sample Beatsync Lines to 4` ⌨️
- `Global:Paketti:Set Selected Sample Beatsync Lines to 8` ⌨️
- ...continues through 16

Quick shortcuts to set sample beatsync lines values (02-16).

**Beatsync Lines Values:**
- 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16

**Use Case:** Rapidly configure beatsync for loops and rhythmic samples.

## Transport & Playback

### Reset SBx and Start Playback

**Keybinding:** `Global:Transport:Reset SBx and Start Playback` ⌨️

Resets all SBx (offset) effect commands in the current pattern and starts playback from the beginning.

**Process:**
1. Scans entire pattern for SBx effect commands
2. Resets all found SBx values to S00
3. Starts playback from pattern beginning

**Use Case:** Quick reset of sample offset commands when testing sliced patterns.

## Sample Buffer Rotation

### Rotate Sample Buffer

**Keybindings:**
- `Sample Editor:Paketti:Rotate Sample Buffer Upwards` ⌨️
- `Sample Editor:Paketti:Rotate Sample Buffer Downwards` ⌨️

**MIDI:**
- `Paketti:Rotate Sample Buffer Up x[Trigger]` 🎹
- `Paketti:Rotate Sample Buffer Down x[Trigger]` 🎹
- `Paketti:Rotate Sample Buffer Up x[Knob]` 🎹
- `Paketti:Rotate Sample Buffer Down x[Knob]` 🎹
- `Paketti:Rotate Sample Buffer Up/Down x[Knob]` 🎹

Circular rotation of sample waveform - shifts sample data up or down with wraparound.

**Upwards:** Shifts waveform amplitude values up (positive direction)
**Downwards:** Shifts waveform amplitude values down (negative direction)

**MIDI Knob Control:**
- Knob value 0-127 scales rotation amount
- Bi-directional knob for up/down control

**Effect:** Creates unique phase-shifting and timbre-altering effects by rotating the actual sample values.

**Use Case:** 
- Experimental sound design
- Create variations from single sample
- Subtle timbre shifts

## Crossfade Loop

**Keybinding:** `Global:Paketti:Crossfade Loop` ⌨️

Creates smooth loop by crossfading loop start and end points. Eliminates clicks at loop boundary.

**Process:**
1. Identifies loop start and end points
2. Applies crossfade between the two regions
3. Creates seamless loop transition

**Use Case:** Fix clicking loops, create smooth sustaining sounds.

## MIDI Transpose Control

### Selected Instrument Transpose

**MIDI:** `Paketti:Midi Selected Instrument Transpose (-64-+64)` 🎹

Real-time transpose control for currently selected instrument via MIDI controller.

**Range:** -64 to +64 semitones
**Control:** MIDI knob/fader (0-127 maps to full range)

### Individual Instrument Transpose (00-15)

**MIDI:** 16 MIDI mappings:
- `Paketti:Midi Instrument 00 Transpose (-64-+64)` 🎹
- `Paketti:Midi Instrument 01 Transpose (-64-+64)` 🎹
- ...through Instrument 15

Direct MIDI transpose control for first 16 instruments regardless of selection.

**Use Case:**
- Live performance transpose
- Hardware controller integration
- Multi-instrument pitch control

## Effect Column Randomization

### Randomize Effect Column (Smatter Mode)

**"Smatter"** = Sparse randomization (not every line)

**Keybindings:**
- `Global:Paketti:Randomize Effect Column Smatter (C00/C0F)` ⌨️ - Volume
- `Global:Paketti:Randomize Effect Column Smatter (0G Glide)` ⌨️
- `Global:Paketti:Randomize Effect Column Smatter (0U Slide Up)` ⌨️
- `Global:Paketti:Randomize Effect Column Smatter (0D Slide Down)` ⌨️
- `Global:Paketti:Randomize Effect Column Smatter (0R Retrig)` ⌨️
- `Global:Paketti:Randomize Effect Column Smatter (0P Panning)` ⌨️
- `Global:Paketti:Randomize Effect Column Smatter (0B00/0B01)` ⌨️ - Backward

Adds randomized effect commands sparsely throughout selection.

### Randomize Effect Column (Fill Mode)

**"Fill"** = Dense randomization (every line)

**Keybindings:**
- `Global:Paketti:Randomize Effect Column Fill (C00/C0F)` ⌨️ - Volume
- `Global:Paketti:Randomize Effect Column Fill (0G Glide)` ⌨️
- `Global:Paketti:Randomize Effect Column Fill (0U Slide Up)` ⌨️
- `Global:Paketti:Randomize Effect Column Fill (0D Slide Down)` ⌨️
- `Global:Paketti:Randomize Effect Column Fill (0R Retrig)` ⌨️
- `Global:Paketti:Randomize Effect Column Fill (0P Panning)` ⌨️
- `Global:Paketti:Randomize Effect Column Fill (0B00/0B01)` ⌨️ - Backward

Fills selection densely with randomized effect commands.

**Effect Commands:**
- **C00-C0F:** Volume (0C00 = off, 0C0F = max)
- **0G:** Glide (portamento)
- **0U:** Slide Up (pitch slide)
- **0D:** Slide Down (pitch slide)
- **0R:** Retrigger
- **0P:** Panning
- **0B:** Backward playback

**Use Cases:**
- Generative music creation
- Random modulation textures
- Experimental rhythmic variations
- Chaotic glitch effects

## Track Solo/Mute Systems

### Toggle Solo Tracks

**Keybinding:** `Global:Paketti:Toggle Solo Tracks` ⌨️

**MIDI:** `Paketti:Toggle Solo Tracks` 🎹

Toggles solo state of currently selected track. When any track is soloed, all other tracks are muted.

### Solo Tracks with Pattern Data

**Keybinding:** `Global:Paketti:Solo Tracks with Pattern Data` ⌨️

**MIDI:** `Paketti:Solo Tracks with Pattern Data` 🎹

**Menu:** `Pattern Matrix:Paketti:Solo Tracks with Pattern Data` 📋

Intelligently solos only tracks that contain data in the current pattern.

**Process:**
1. Scans current pattern for tracks with note/effect data
2. Solos all tracks with data
3. Mutes empty tracks

**Use Case:** Focus on active tracks during arrangement, hide silent tracks.

### Unsolo All Tracks

**Keybinding:** `Global:Paketti:Unsolo All Tracks` ⌨️

**MIDI:** `Paketti:Unsolo All Tracks` 🎹

Removes solo from all tracks, restoring normal playback.

### Toggle Mute Tracks

**Keybinding:** `Global:Paketti:Toggle Mute Tracks` ⌨️

**MIDI:** `Paketti:Toggle Mute Tracks` 🎹

Toggles mute state of currently selected track.

### Individual Track Mute/Unmute (01-16)

**Keybindings:** 48 keybindings total:
- `Global:Paketti:Mute Track 01` through `16` ⌨️
- `Global:Paketti:Unmute Track 01` through `16` ⌨️
- `Global:Paketti:Toggle Mute/Unmute of Track 01` through `16` ⌨️

**MIDI:** Same 48 MIDI mappings available 🎹

Direct mute/unmute/toggle control for first 16 tracks.

### Selected Track Mute Control

**Keybindings:**
- `Global:Paketti:Mute Selected Track` ⌨️
- `Global:Paketti:Unmute Selected Track` ⌨️
- `Global:Paketti:Toggle Mute/Unmute of Selected Track` ⌨️

**MIDI:** Same 3 MIDI mappings available 🎹

Mute control for currently selected track (works beyond track 16).

## Impulse Tracker Features

### Alt-M MixPaste

**Keybindings:**
- `Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Save` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Load` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker MixPaste` ⌨️

Impulse Tracker-style MixPaste - blend pattern data without overwriting.

**Save:** Stores current selection to clipboard
**Load:** Blends clipboard data with existing pattern (preserves non-empty cells)
**MixPaste:** Combined save+blend operation

**MixPaste Behavior:**
- Empty cells in clipboard → keeps existing data
- Data in clipboard → overwrites existing data
- Intelligent merging of note/effect data

### Impulse Tracker Shift Operations

**Keybindings:**
- `Pattern Editor:Paketti:Impulse Tracker Shift-Right Selection In Pattern` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Shift-Left Selection In Pattern` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Shift-Down Selection In Pattern` ⌨️
- `Pattern Editor:Paketti:Impulse Tracker Shift-Up Selection In Pattern` ⌨️

Shifts pattern selection in 4 directions while preserving data boundaries.

**Shift-Right:** Moves data right, wraps to next row
**Shift-Left:** Moves data left, wraps to previous row
**Shift-Down:** Moves data down in pattern
**Shift-Up:** Moves data up in pattern

**Use Case:** Nudge patterns into groove, create variations, adjust timing.

### Slide Column Content

**Keybindings:**
- `Pattern Editor:Paketti:Slide Selected Column Content Down` ⌨️
- `Pattern Editor:Paketti:Slide Selected Column Content Up` ⌨️

**MIDI:**
- `Paketti:Slide Selected Column Content Down` 🎹
- `Paketti:Slide Selected Column Content Up` 🎹

Slides content of selected column up or down with wraparound.

**Down:** Shifts all column data down one line (bottom wraps to top)
**Up:** Shifts all column data up one line (top wraps to bottom)

**Use Case:** 
- Rotate note sequences
- Shift effect columns
- Create rhythmic variations

### Slide Track Content

**Keybindings:**
- `Pattern Editor:Paketti:Slide Selected Track Content Up` ⌨️
- `Pattern Editor:Paketti:Slide Selected Track Content Down` ⌨️

**MIDI:**
- `Paketti:Slide Selected Track Content Up` 🎹
- `Paketti:Slide Selected Track Content Down` 🎹

Slides entire track content (all columns) up or down with wraparound.

**Use Case:** Shift complete track patterns, create polyrhythms.

## Pattern Manipulation

### Shrink to Triplets

**Keybinding:** `Pattern Editor:Paketti:Shrink to Triplets` ⌨️

Converts selected pattern data to triplet timing (3 notes in space of 2).

**Process:**
1. Analyzes note timing
2. Recalculates positions for triplet feel
3. Adjusts LPB if necessary

**Use Case:** Convert straight rhythms to swing/shuffle feel.

### Triple (Experimental)

**Keybinding:** `Pattern Editor:Paketti:Triple (Experimental)` ⌨️

Triples the selected pattern content (experimental timing transformation).

**Parameters:** Uses 3, 6, 8 ratio for tripling calculation

**Use Case:** Experimental rhythmic transformations, polyrhythmic patterns.

## Instrument & Sample Utilities

### Group Samples by Name to New Instruments

**Keybinding:** `Global:Paketti:Group Samples by Name to New Instruments` ⌨️

**MIDI:** `Paketti:Group Samples by Name to New Instruments` 🎹

Analyzes sample names and groups similar samples into new instruments automatically.

**Process:**
1. Scans all samples in song
2. Groups samples with similar naming patterns
3. Creates new instruments for each group
4. Moves samples to appropriate instruments

**Use Case:** Organize drum hits, organize imported sample libraries.

### Load RingMod Instruments

**Keybindings:**
- `Global:Paketti:Load RingMod Instrument` ⌨️
- `Global:Paketti:Load RingMod Legacy Instrument` ⌨️

**MIDI:**
- `Paketti:Load RingMod Instrument [Trigger]` 🎹
- `Paketti:Load RingMod Legacy Instrument [Trigger]` 🎹

**Menu:**
- `Instrument Box:Paketti:Instruments:Load RingMod Instrument` 📋
- `Instrument Box:Paketti:Instruments:Load RingMod Legacy Instrument` 📋

Loads pre-configured ring modulation instruments.

**RingMod:** Modern ring modulation setup
**RingMod Legacy:** Classic/vintage ring mod configuration

## Column Cycle Keyjazz

**Keybindings:**
- `Global:Paketti:Start/Stop Column Cycling` ⌨️
- `Global:Paketti:Column Cycle Keyjazz` ⌨️
- `Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz` ⌨️
- `Global:Paketti:Column Cycle Keyjazz Special (` ⌨️
- `Global:Paketti:Column Cycle Keyjazz Special (2)` ⌨️
- `Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz Special (` ⌨️

Automatically cycles through note columns as you play MIDI keyboard, distributing notes across columns.

**Features:**
- **Start/Stop:** Toggle column cycling on/off
- **Standard mode:** Cycles through visible columns sequentially
- **Special modes:** Alternative cycling patterns

**Use Case:**
- Record polyphonic MIDI as individual monophonic columns
- Create layered patterns automatically
- Rapid chord entry with voice separation

## Phrase Playback

**Keybindings:**
- `Global:Paketti:Play Current Line in Phrase` ⌨️
- `Phrase Editor:Paketti:Play Current Line in Phrase` ⌨️

**MIDI:** `Paketti:Play Current Line in Phrase [Trigger]` 🎹

Triggers playback of the current line in the phrase editor for auditioning.

## Wipe Song Patterns

**Keybinding:** `Global:Paketti:Wipe Song Patterns` ⌨️

Clears all pattern data in the entire song (destructive operation).

**Warning:** Cannot be undone. Creates empty patterns.

**Use Case:** Start fresh arrangement keeping instrument/sample setup.

## AutoGapper

**Keybinding:** `Global:Paketti:Add Filter & LFO (AutoGapper)` ⌨️

Adds pre-configured Filter + LFO device combo for automatic gating/rhythmic filtering effects.

**Setup:**
- Filter device with cutoff modulation
- LFO device routed to filter cutoff
- Pre-configured for rhythmic gating

**Use Case:** Instant sidechained/gated filter effect, rhythmic filtering.

## Zero Crossing Detection

**Keybinding:** `Sample Editor:Paketti:Detect Zero Crossings` ⌨️

Detects and marks zero-crossing points in selected sample. Identifies points where waveform crosses zero amplitude.

**Use Case:** Find ideal slice points, prepare for click-free editing.

---

# Zero Crossings System

**Source:** `PakettiZeroCrossings.lua` | **Features:** 64

Advanced zero-crossing based slicing with BPM-synced slice movement, randomization, and intelligent wipe & slice operations.

## Zero Crossings Advanced Dialog

**Keybindings:**
- `Global:Paketti:Zero Crossings Advanced Dialog` ⌨️

**MIDI:** `Paketti:Zero Crossings Advanced Dialog` 🎹

**Menu:**
- `Instrument Box:Paketti:Zero Crossings:Advanced Dialog` 📋

Comprehensive dialog for zero-crossing detection and slice marker creation with extensive controls.

**Features:**
- **Threshold Control** - Sensitivity for zero-crossing detection
- **Minimum Distance** - Prevent too-close slice markers
- **Preview Mode** - See potential slices before applying
- **BPM Detection** - Auto-detect sample tempo
- **Slice Count Presets** - Common slice counts (8, 16, 32, 64, 128)
- **Smart Placement** - Finds nearest zero-crossings to calculated positions

**Process:**
1. Analyzes sample waveform
2. Detects zero-crossing points
3. Places slice markers at detected crossings
4. Ensures click-free slices

## Zero Crossing Wipe & Slice

**Keybindings:** 7 presets:
- `Global:Paketti:Zero Crossing Wipe&Slice (002)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (004)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (008)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (016)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (032)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (064)` ⌨️
- `Global:Paketti:Zero Crossing Wipe&Slice (128)` ⌨️

**MIDI:** `Paketti:Zero Cross Wipe&Slice (016)` 🎹

**Menu:** `Instrument Box:Paketti:Zero Crossings:Zero Cross Wipe&Slice (016)` 📋

One-click slice creation with preset slice counts. Wipes existing slices and creates new ones at zero-crossing points.

**Slice Counts:** 2, 4, 8, 16, 32, 64, 128

**Process:**
1. **Wipe:** Removes all existing slice markers
2. **Calculate:** Determines even slice spacing
3. **Detect:** Finds nearest zero-crossing to each calculated position
4. **Place:** Inserts slice markers at zero-crossings

**Result:** Perfectly even slices with zero clicks/pops at slice boundaries.

**Use Case:**
- Quick drumloop slicing
- Click-free sample division
- Prepare slices for beat mangling

## BPM-Synced Slice Movement

### Move Slice Start

**Keybindings:** 8 keybindings:
- `Sample Editor:Paketti:Move Slice Start +1/4 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start +1/8 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start +1/16 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start +1/32 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -1/4 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -1/8 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -1/16 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice Start -1/32 Beat` ⌨️

Moves slice start point forward/backward by musical divisions (quarter, 8th, 16th, 32nd notes).

**Beat Divisions:**
- **1/4 Beat** - Quarter note adjustment
- **1/8 Beat** - 8th note adjustment
- **1/16 Beat** - 16th note adjustment
- **1/32 Beat** - 32nd note adjustment

### Move Slice End

**Keybindings:** 8 keybindings:
- `Sample Editor:Paketti:Move Slice End +1/4 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End +1/8 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End +1/16 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End +1/32 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -1/4 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -1/8 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -1/16 Beat` ⌨️
- `Sample Editor:Paketti:Move Slice End -1/32 Beat` ⌨️

Moves slice end point forward/backward by musical divisions.

**How It Works:**
1. Detects current sample BPM (from beatsync or detection)
2. Calculates frame distance for requested beat division
3. Moves slice marker by that distance
4. Snaps to nearest zero-crossing for click-free result

**Use Cases:**
- Fine-tune slice timing
- Adjust slice groove
- Fix slightly off-beat slices
- Create swing by moving alternate slices

## Slice Randomization

### Randomize Slice Positions

**Keybinding:** `Global:Paketti:Randomize Slice Positions` ⌨️

**MIDI:** `Paketti:Randomize Slice Positions` 🎹

**Menu:** `Instrument Box:Paketti:Zero Crossings:Randomize Slices` 📋

Randomly shifts existing slice marker positions slightly for groove variation.

**Features:**
- Preserves slice order
- Small random offsets
- Maintains zero-crossing alignment
- Creates natural timing variations

**Use Case:** Add human feel to quantized slices, create groove variations.

### Create Random Distributed Slices

**Keybinding:** `Global:Paketti:Create Random Distributed Slices` ⌨️

**MIDI:** `Paketti:Create Random Distributed Slices` 🎹

Creates completely random slice distribution across sample.

**Features:**
- Random slice count
- Random positions
- Zero-crossing aligned
- Chaotic slice patterns

**Use Case:** 
- Experimental beat mangling
- Glitch effects
- Generative rhythms

### Snap Selection to Zero Crossings

**MIDI:** `Paketti:Snap Selection to Zero Crossings` 🎹

Snaps current sample selection start/end points to nearest zero-crossings.

**Use Case:** Prepare selection for click-free processing, ensure clean loop points.

---

# Oldschool Slice Pitch Workflow

**Source:** `PakettiOldschoolSlicePitch.lua` | **Features:** 49

Classic Amiga-style slice and pitch workflow with gap detection, gap filling methods, and intelligent slice-to-pattern writing.

## Gap Detection & Analysis

### Detect Gaps in Sample

**Keybinding:** `Sample Editor:Paketti:Detect Gaps in Sample` ⌨️

Analyzes sample for silent gaps between audio regions. Identifies potential slice points based on silence detection.

**Detection:**
- Finds regions below threshold amplitude
- Marks gap boundaries
- Reports gap count and positions
- Shows gap durations

**Use Case:** Find slice points in concatenated samples, detect recording gaps.

### Detect Sample BPM

**Keybindings:**
- `Sample Editor:Paketti:Detect Sample BPM` ⌨️
- `Global:Paketti:Detect Sample BPM` ⌨️

Intelligent BPM detection for loops and rhythmic samples.

**Process:**
1. Analyzes transient peaks
2. Calculates inter-onset intervals
3. Detects repeating patterns
4. Estimates BPM with confidence rating

**Features:**
- Auto-detects loop length
- Identifies time signature hints
- Shows confidence percentage
- Suggests beatsync lines value

**Use Case:** Auto-configure beatsync, prepare loops for slicing.

## Gap Filling Methods

### Fill Selected Gap (Reversed)

**Keybinding:** `Sample Editor:Paketti:Fill Selected Gap (Reversed)` ⌨️

Fills selected gap with reversed audio from adjacent regions.

**Method:**
1. Identifies gap boundaries
2. Takes audio before gap
3. Reverses it
4. Fills gap with reversed audio

**Effect:** Creates backwards-fill transition

### Fill Selected Gap (Copied)

**Keybinding:** `Sample Editor:Paketti:Fill Selected Gap (Copied)` ⌨️

Fills gap by copying adjacent audio.

**Method:** Direct copy from before-gap region

### Fill Selected Gap (PingPong)

**Keybinding:** `Sample Editor:Paketti:Fill Selected Gap (PingPong)` ⌨️

Fills gap with ping-pong (forward-reverse-forward) pattern.

**Method:**
1. Takes adjacent audio
2. Plays forward then backward
3. Loops to fill gap

**Effect:** Creates smooth back-and-forth transition

### Fill All Gaps (3 Methods)

**Keybindings:**
- `Sample Editor:Paketti:Fill All Gaps (Reversed)` ⌨️
- `Sample Editor:Paketti:Fill All Gaps (Copied)` ⌨️
- `Sample Editor:Paketti:Fill All Gaps (PingPong)` ⌨️

Batch-fills all detected gaps in sample using chosen method.

**Use Case:**
- Remove silence from sample chains
- Create continuous drone from gapped samples
- Experimental textures

## Oldschool Slice Pitch Workflow

**Keybindings:**
- `Pattern Editor:Paketti:Oldschool Slice Pitch Workflow (Reversed)` ⌨️
- `Pattern Editor:Paketti:Oldschool Slice Pitch Workflow (Copied)` ⌨️
- `Pattern Editor:Paketti:Oldschool Slice Pitch Workflow (PingPong)` ⌨️

Complete Amiga-style workflow: detect gaps, fill with chosen method, create slices, write to pattern.

**Workflow Steps:**
1. **Detect gaps** in sample
2. **Fill gaps** with chosen method (Reversed/Copied/PingPong)
3. **Create slices** at gap boundaries
4. **Write pattern** with slice commands
5. **Configure beatsync** based on detected BPM

**Methods:**
- **Reversed:** Classic reversed-fill (Amiga style)
- **Copied:** Simple gap fill
- **PingPong:** Forward-backward fill

**Result:** Ready-to-play sliced instrument with pattern sequence.

**Use Case:** 
- Amiga ProTracker workflow emulation
- Quick break chopping
- Classic jungle/DnB production

## Slices to Pattern

### Basic Slices to Pattern

**Keybindings:**
- `Pattern Editor:Paketti:Slices to Pattern (from first row)` ⌨️
- `Pattern Editor:Paketti:Slices to Pattern (from current row)` ⌨️
- `Sample Editor:Paketti:Slices to Pattern (from first row)` ⌨️
- `Sample Editor:Paketti:Slices to Pattern (from current row)` ⌨️

Writes slice notes to pattern starting from first row or current row.

**Process:**
1. Reads slice markers from sample
2. Writes note + 0Sxx commands for each slice
3. Spaces notes evenly or based on timing
4. Starts from first row (00) or current cursor position

### Slices to Pattern (Beat Sync Only)

**Keybindings:**
- `Pattern Editor:Paketti:Slices to Pattern (beat sync only)` ⌨️
- `Sample Editor:Paketti:Slices to Pattern (beat sync only)` ⌨️

Writes slices to pattern using beatsync timing (no 0Sxx commands needed).

**Requirements:**
- Sample must have beatsync enabled
- Beatsync lines must be configured

**Advantage:** Cleaner pattern (no offset commands), easy timing adjustments.

### Slices to Pattern (Detected BPM)

**Keybindings:**
- `Pattern Editor:Paketti:Slices to Pattern (detected BPM, from first row)` ⌨️
- `Pattern Editor:Paketti:Slices to Pattern (detected BPM, from current row)` ⌨️
- `Sample Editor:Paketti:Slices to Pattern (detected BPM, from first row)` ⌨️

Auto-detects sample BPM first, then writes slices to pattern with accurate timing.

**Process:**
1. **Detect BPM** using intelligent analysis
2. **Calculate timing** based on detected BPM
3. **Write notes** with proper spacing
4. **Configure beatsync** automatically

**Use Case:** One-click break sequencing with automatic tempo matching.

### Slices to Pattern Evenly

**Keybindings:**
- `Pattern Editor:Paketti:Slices to Pattern Evenly (from first row)` ⌨️
- `Pattern Editor:Paketti:Slices to Pattern Evenly (from current row)` ⌨️
- `Sample Editor:Paketti:Slices to Pattern Evenly (from first row)` ⌨️
- `Sample Editor:Paketti:Slices to Pattern Evenly (from current row)` ⌨️

Writes slices with even spacing regardless of original slice positions.

**Spacing:** `pattern_lines / slice_count` = space between each slice

**Use Case:** Create even groove from unevenly-sliced breaks.

## Slices to Phrase

**Keybindings:**
- `Pattern Editor:Paketti:Slices to Phrase (with trigger)` ⌨️
- `Pattern Editor:Paketti:Slices to Phrase (phrase only)` ⌨️
- `Sample Editor:Paketti:Slices to Phrase (with trigger)` ⌨️
- `Sample Editor:Paketti:Slices to Phrase (phrase only)` ⌨️

Writes slice sequence to phrase editor instead of pattern.

**With Trigger:** Creates phrase + adds trigger note in pattern
**Phrase Only:** Creates phrase without pattern trigger

**Use Case:**
- Build slice phrase libraries
- Create reusable break patterns
- Phrase-based arrangement

---


---

# Pitch & BPM Control Suite

**Source:** `PakettiPitchControl.lua` | **Features:** 19

Advanced BPM calculation, beatsync-to-pitch conversion, and sample pitch modification with visual feedback.

## Set BPM from Sample Length

**Keybindings:**
- `Global:Paketti:Set BPM from Sample Length` ⌨️
- `Sample Editor:Paketti:Set BPM from Sample Length` ⌨️
- `Pattern Editor:Paketti:Set BPM from Sample Length` ⌨️

**Menu:**
- `Sample Editor:Paketti:Set BPM from Sample Length` 📋
- `Pattern Editor:Paketti:Set BPM from Sample Length` 📋

Calculates and sets song BPM based on selected sample's length and beatsync settings.

**Process:**
1. Reads sample beatsync lines value
2. Calculates implied BPM from sample length
3. Sets song BPM to match sample
4. Shows calculation in status

**Use Case:** 
- Sync song tempo to loop
- Match project BPM to imported sample
- Quick tempo setup from reference loop

## BPM Calculation Dialog

**Keybindings:**
- `Global:Paketti:Show BPM Calculation Dialog...` ⌨️
- `Sample Editor:Paketti:Show BPM Calculation Dialog...` ⌨️
- `Pattern Editor:Paketti:Show BPM Calculation Dialog...` ⌨️

Interactive calculator showing real-time BPM calculations from sample length.

**Display:**
- Sample length in frames
- Sample rate
- Current beatsync lines value
- Calculated BPM
- Suggested song BPM

**Features:**
- Real-time calculation updates
- Multiple beatsync lines options
- Try before apply
- Shows formula used

## Convert Beatsync to Sample Pitch

**Keybindings:**
- `Global:Paketti:Convert Beatsync to Sample Pitch` ⌨️
- `Sample Editor:Paketti:Convert Beatsync to Sample Pitch` ⌨️
- `Pattern Editor:Paketti:Convert Beatsync to Sample Pitch` ⌨️

Converts sample's beatsync setting to equivalent pitch/transpose offset, then disables beatsync.

**Process:**
1. Reads current beatsync lines
2. Calculates equivalent pitch shift
3. Applies transpose to sample
4. Disables beatsync mode
5. Preserves audio playback timing

**Why:**
- Beatsync can cause artifacts at extreme tempos
- Pitch-based timing is more stable
- Better for tempo changes
- Reduces CPU load

**Use Case:** Convert beatsync samples to pitch-based playback for stability.

## Sample Pitch Modifier Dialog

**Keybindings:**
- `Global:Paketti:Sample Pitch Modifier Dialog...` ⌨️
- `Sample Editor:Paketti:Sample Pitch Modifier Dialog...` ⌨️
- `Global:Paketti:Sample Pitch Modifier Dialog Size Toggle` ⌨️

Visual dialog for adjusting sample pitch with real-time preview.

**Features:**
- **Transpose slider** - Semitone adjustment
- **Finetune slider** - Cent adjustment
- **Real-time preview** - Hear changes immediately
- **Visual waveform** - See sample while adjusting
- **Size toggle** - Switch between compact/expanded view
- **Keyboard shortcuts** - Adjust without mouse

**Controls:**
- **Transpose:** -48 to +48 semitones
- **Finetune:** -127 to +127 cents
- **Combined:** Full pitch control range

**Use Case:**
- Tune samples to song key
- Pitch-match loops
- Create pitch variations
- Quick transposition

## BPM Calculation Debug

**Keybindings:**
- `Global:Paketti:BPM Calculation Debug (Comprehensive)` ⌨️
- `Sample Editor:Paketti:BPM Calculation Debug (Comprehensive)` ⌨️
- `Pattern Editor:Paketti:BPM Calculation Debug (Comprehensive)` ⌨️

**Menu:**
- `Sample Editor:Paketti:BPM Calculation Debug (Comprehensive)` 📋
- `Pattern Editor:Paketti:BPM Calculation Debug (Comprehensive)` 📋

Comprehensive debugging output for BPM detection and calculation.

**Output:**
- Sample properties (rate, length, channels)
- Beatsync configuration
- Calculated BPMs for all common beatsync lines (1-16)
- Frame-to-beat conversions
- Detection algorithm results

**Use Case:** Troubleshoot BPM detection issues, verify calculations.

---

# Polyend Pattern Data Suite

**Source:** `PakettiPolyendPatternData.lua` | **Features:** 18

Import/export patterns and projects between Renoise and Polyend Tracker with pattern browser and batch operations.

## Pattern Browser

**Keybinding:** `Global:Paketti:Show Polyend Pattern Browser` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Pattern Browser` 📋
- `Main Menu:Tools::Paketti:Xperimental/WIP:Polyend WIP:Pattern Browser` 📋

Visual browser for Polyend Tracker pattern files with preview and batch import.

**Features:**
- **File Browser** - Lists pattern files from Polyend projects
- **Pattern Preview** - See pattern data before import
- **Batch Selection** - Import multiple patterns
- **Metadata Display** - Shows pattern length, track count
- **Folder Navigation** - Browse Polyend project folders

**Workflow:**
1. Select Polyend project folder
2. Browse pattern files
3. Preview patterns
4. Select patterns to import
5. Import to Renoise

## Import Polyend Project

**Keybinding:** `Global:Paketti:Import Polyend Project` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import Polyend Project` 📋
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Import Polyend Project` 📋

Imports entire Polyend Tracker project (all patterns, instruments, songs).

**Import Process:**
1. Select Polyend project folder
2. Scans for all patterns
3. Imports instruments (PTI files)
4. Imports patterns with note data
5. Recreates project structure in Renoise

**Features:**
- **Full project import** - All patterns and instruments
- **Structure preservation** - Maintains project organization
- **Batch processing** - Imports all at once
- **Instrument mapping** - Links patterns to correct instruments

## Import Polyend Pattern

**Keybinding:** `Global:Paketti:Import Polyend Pattern` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import Polyend Pattern` 📋
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Import Polyend Pattern` 📋

Imports single pattern from Polyend Tracker.

**Import Details:**
- Pattern length preservation
- Note data conversion
- Effect command mapping
- Track routing

## Import Polyend Pattern Tracks

**Keybinding:** `Global:Paketti:Import Polyend Pattern Tracks` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import Polyend Pattern Tracks` 📋
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Import Polyend Pattern Tracks` 📋

Imports selected tracks from Polyend pattern (partial import).

**Features:**
- **Track selection** - Choose specific tracks to import
- **Multi-track import** - Import multiple tracks at once
- **Existing pattern** - Adds to current pattern
- **Track mapping** - Maps to available Renoise tracks

**Use Case:** Cherry-pick useful tracks from Polyend patterns.

## Export Pattern to MTP

**Keybinding:** `Global:Paketti:Export Pattern to MTP` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Export Pattern to MTP` 📋
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Export Pattern to MTP` 📋

Exports current Renoise pattern to Polyend Tracker MTP (pattern data) format.

**Export Features:**
- **Pattern structure** - Preserves pattern length
- **Note conversion** - Maps Renoise notes to Polyend format
- **Effect mapping** - Converts compatible effects
- **Track organization** - Maintains track order

**Limitations:**
- Polyend Tracker has fewer tracks (8 vs Renoise 128)
- Some effects may not convert directly
- May require manual adjustment after export

## Import MT Project File

**Keybinding:** `Global:Paketti:Import MT Project File` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import MT Project File` 📋
- `Main Menu:Tools:Paketti:Polyend WIP:Import MT Project File` 📋

Imports complete Polyend Medusa Tracker (MT) project file.

**Features:**
- Full MT project import
- Pattern reconstruction
- Instrument integration
- Song structure preservation

---

# CCizer Loader

**Source:** `PakettiCCizerLoader.lua` | **Features:** 17+

MIDI CC automation loader and text-based MIDI control device generator for automating device parameters.

## CCizer Loader Dialog

**Keybinding:** `Global:Paketti:CCizer Loader...` ⌨️

**Menu:**
- `DSP Device:Paketti:CCizer:Open CCizer Dialog` 📋
- `Sample FX Mixer:Paketti:CCizer:Open CCizer Dialog` 📋
- `Mixer:Paketti:CCizer:Open CCizer Dialog` 📋

Opens CCizer file browser for loading MIDI CC automation snapshots.

**Features:**
- **File Browser** - Lists saved CCizer files
- **Preview** - See CC assignments before loading
- **Apply to Device** - Loads CC mappings to selected device
- **Parameter Mapping** - Maps CC numbers to device parameters

**CCizer File Format:**
- Text-based CC automation
- Parameter name mapping
- CC number assignments
- Value ranges

## Load CCizer from File

**Menu:**
- `DSP Device:Paketti:CCizer:Load from File` 📋
- `Sample FX Mixer:Paketti:CCizer:Load from File` 📋
- `Mixer:Paketti:CCizer:Load from File` 📋

Browse and load CCizer file to selected device.

## Load Preset CCizer Files

**Menu:** Dynamic menu entries (10-15+ presets):
- `DSP Device:Paketti:CCizer:Load [PresetName]` 📋
- `Sample FX Mixer:Paketti:CCizer:Load [PresetName]` 📋
- `Mixer:Paketti:CCizer:Load [PresetName]` 📋

**Keybindings:** Dynamic keybindings for each preset:
- `Global:Paketti:CCizer Load [PresetName]` ⌨️

Pre-configured CCizer setups for common devices (Filter, Delay, Reverb, etc.).

**Preset Examples:**
- Filter Cutoff + Resonance
- Delay Time + Feedback
- Reverb Size + Damping
- EQ Band Controls
- Compressor Threshold + Ratio

## Create MIDI Control from Text File

**Keybinding:** `Global:Paketti:Create MIDI Control from Text File` ⌨️

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental:Create MIDI Control from Text File` 📋
- `DSP Device:Paketti:Experimental:Create MIDI Control from Text File` 📋
- `Sample FX Mixer:Paketti:Experimental:Create MIDI Control from Text File` 📋
- `Mixer:Paketti:Experimental:Create MIDI Control from Text File` 📋

Creates MIDI Control device from text file specification.

**Text File Format:**
```
Parameter 1: CC 20
Parameter 2: CC 21
Parameter 3: CC 22
...
```

**Process:**
1. Select text file with CC mappings
2. Creates *MIDI Control Device
3. Maps parameters to specified CC numbers
4. Inserts device in track

**Use Case:**
- Quick MIDI control setup
- Hardware controller templates
- Standardized CC mappings
- Batch device configuration

---

# PlayerPro Waveform Viewer

**Source:** `PakettiPlayerProWaveformViewer.lua` | **Features:** 16

Visual waveform viewer integrated with pattern editor showing audio playback position synchronized with pattern cursor.

## Open Waveform Viewer

**Keybindings:**
- `Global:Paketti:PlayerPro Waveform Viewer Open Viewer` ⌨️
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Open Viewer` ⌨️

**MIDI:** `Paketti:PlayerPro Waveform Viewer Open Viewer` 🎹

**Menu:**
- `Main Menu:Tools:Paketti:Xperimental/WIP:PlayerPro:Waveform Viewer` 📋
- `Main Menu:Tools:PlayerPro Waveform Viewer` 📋
- `Pattern Editor:Paketti:PlayerPro:Waveform Viewer` 📋

Opens visual waveform display synchronized with pattern cursor position.

**Features:**
- **Waveform Display** - Visual sample waveform
- **Playback Position** - Red line shows current playback position
- **Pattern Sync** - Position updates with pattern cursor
- **Note Event Markers** - Shows where notes trigger in pattern
- **Selection Display** - Highlights sample selection regions
- **Zoom Controls** - Zoom in/out on waveform
- **Multi-sample Support** - Shows all samples in instrument

**Display:**
- Horizontal waveform with time axis
- Vertical amplitude display
- Note trigger markers (vertical lines)
- Playback position (red vertical line)
- Selection region (highlighted)

## Nudge Controls

### Nudge by Tick

**Keybindings:**
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Left (Tick)` ⌨️
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Right (Tick)` ⌨️

**MIDI:**
- `Paketti:PlayerPro Waveform Viewer Nudge Left (Tick)` 🎹
- `Paketti:PlayerPro Waveform Viewer Nudge Right (Tick)` 🎹

Nudges playback position by one tick (smallest timing division).

**Tick:** 1/256th of a line at LPB 1

**Use Case:** Fine-tune note timing by single tick increments.

### Nudge by Line

**Keybindings:**
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Left (Line)` ⌨️
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Right (Line)` ⌨️

Nudges playback position by one pattern line.

**Line:** Full pattern row (1/LPB of a beat)

**Use Case:** Adjust note timing by full line increments.

## Event Navigation

### Select Previous/Next Event

**Keybindings:**
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Select Previous Event` ⌨️
- `Pattern Editor:Paketti:PlayerPro Waveform Viewer Select Next Event` ⌨️

Jumps to previous/next note event in pattern and updates waveform display.

**Features:**
- Skips empty lines
- Jumps to note events only
- Updates waveform position marker
- Shows event details

**Use Case:** Quick navigation between note events while seeing waveform.

## Snap Selected To Row

**Keybinding:** `Pattern Editor:Paketti:PlayerPro Waveform Viewer Snap Selected To Row` ⌨️

Snaps currently displayed sample position to align with selected pattern row.

**Use Case:** Align waveform view with specific pattern row for timing analysis.

## Refresh Viewer

**Keybinding:** `Pattern Editor:Paketti:PlayerPro Waveform Viewer Refresh` ⌨️

Refreshes waveform display (useful after sample edits or pattern changes).

**Updates:**
- Redraws waveform
- Updates note event markers
- Refreshes playback position
- Reloads sample data

## Use Cases

**Visual Pattern Editing:**
- See which part of sample plays at each note
- Understand slice triggering visually
- Debug timing issues

**Sample Analysis:**
- Identify transients in waveform
- See attack/release characteristics
- Plan slice points

**Educational:**
- Understand relationship between notes and audio
- Learn sample triggering
- Visualize playback behavior

---


---

# Elektron Octatrack Export Suite

**Source:** `PakettiOTExport.lua` | **Features:** 24

Complete Octatrack export/import system with .ot metadata file support, drumkit generation, and slice management.

## Export to Octatrack

### Export WAV + .ot Metadata

**Keybinding:** `Sample Editor:Paketti:Export to Octatrack (.WAV+.ot)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Export (.WAV+.ot)` 📋
- `Sample Mappings:Paketti:Octatrack:Export to Octatrack (.WAV+.OT)` 📋

Exports sample as WAV file with accompanying .ot metadata file for Octatrack.

**Export includes:**
- WAV audio file (48kHz, 16-bit)
- .ot metadata file with:
  - Slice marker positions
  - Loop points
  - Playback settings
  - Sample attributes

### Export .ot Metadata Only

**Keybinding:** `Sample Editor:Paketti:Export to Octatrack (.ot)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Export (.ot only)` 📋
- `Sample Mappings:Paketti:Octatrack:Export to Octatrack (.ot only)` 📋

Exports only the .ot metadata file (for samples already on Octatrack).

**Use Case:** Update slice markers or loop points without re-exporting audio.

## Import from Octatrack

### Import .ot Metadata

**Keybinding:** `Sample Editor:Paketti:Import Octatrack (.ot)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Import (.ot)` 📋
- `Sample Mappings:Paketti:Octatrack:Import Octatrack (.ot)` 📋

Imports .ot metadata and applies to selected sample.

**Imports:**
- Slice marker positions
- Loop start/end points
- Playback mode settings
- Sample attributes

**Process:**
1. Select .ot file
2. Reads metadata
3. Applies to currently selected sample
4. Creates slice markers in Renoise

## Debug .ot File

**Keybinding:** `Sample Editor:Paketti:Debug Octatrack (.ot)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Debug (.ot)` 📋
- `Sample Mappings:Paketti:Octatrack:Debug Octatrack (.ot)` 📋

Opens debug dialog showing complete .ot file structure and contents.

**Display:**
- Raw .ot file data (hexadecimal)
- Decoded slice positions
- Loop point values
- All metadata fields
- Calculated frame positions

**Use Case:** Troubleshoot .ot import issues, understand .ot file format.

## Drumkit Generation

### Generate Drumkit (Force Mono)

**Keybinding:** `Sample Editor:Paketti:Octatrack Generate Drumkit (Force Mono)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Generate Drumkit (Force Mono)` 📋
- `Sample Mappings:Paketti:Octatrack:Generate .ot Drumkit (Force Mono)` 📋

Generates Octatrack-compatible drumkit by concatenating all samples in instrument (forced mono).

**Process:**
1. Converts all samples to mono
2. Concatenates samples end-to-end
3. Creates slice markers at each sample boundary
4. Exports WAV + .ot file
5. Ready for Octatrack import

**Mono Conversion:**
- Stereo → Mono (mix down)
- Maintains audio quality
- 48kHz, 16-bit output

### Generate Drumkit (Smart Mono/Stereo)

**Keybinding:** `Sample Editor:Paketti:Octatrack Generate Drumkit (Smart Mono/Stereo)` ⌨️

**Menu:**
- `--Sample Editor:Paketti:Octatrack:Generate Drumkit (Smart Mono/Stereo)` 📋 (separator above)
- `--Sample Mappings:Paketti:Octatrack:Generate .ot Drumkit (Smart Mono/Stereo)` 📋 (separator above)

Intelligently generates drumkit preserving mono/stereo per sample.

**Smart Detection:**
- Mono samples → remain mono
- Stereo samples → remain stereo (if Octatrack MK2)
- Mixed → creates two kits or warns user

### Generate Drumkit (Play to End)

**Keybinding:** `Sample Editor:Paketti:Octatrack Generate Drumkit (Play to End)` ⌨️

**Menu:**
- `Sample Editor:Paketti:Octatrack:Generate Drumkit (Play to End)` 📋
- `Sample Mappings:Paketti:Octatrack:Generate .ot Drumkit (Play to End)` 📋

Generates drumkit where each slice plays to the end of the sample chain (no slice boundaries).

**Behavior:**
- Each trigger plays from slice start to chain end
- Creates long, evolving sounds
- Useful for textural layers

**Use Case:** 
- Create evolving textures
- Build-up sounds
- Ambient layers

## Set Loop to Slice

**Keybinding:** `Sample Editor:Paketti:Octatrack Set .ot Loop to Slice` ⌨️

**Menu:**
- `--Sample Editor:Paketti:Octatrack:Set Loop to Slice` 📋 (separator above)
- `--Sample Mappings:Paketti:Octatrack:Set .ot Loop to Slice` 📋 (separator above)

Sets loop start/end points to match selected slice boundaries.

**Process:**
1. Identifies current slice selection
2. Sets loop start to slice start
3. Sets loop end to slice end
4. Updates .ot metadata

**Use Case:** Create per-slice loops for Octatrack timestretch.

---

# Elektron Digitakt Export Suite

**Source:** `PakettiDigitakt.lua` | **Features:** 16

Specialized Digitakt sample chain export with support for Digitakt 1 (mono) and Digitakt 2 (stereo) with multiple export modes.

## Export Sample Chain Dialog

**Keybindings:**
- `Global:Paketti:Export Digitakt Sample Chain...` ⌨️
- `Global:Paketti:Digitakt Export Sample Chain...` ⌨️
- `Sample Editor:Paketti:Digitakt Export Sample Chain...` ⌨️

**Menu:**
- `Sample Editor:Paketti:Digitakt:Export Sample Chain...` 📋
- `Instrument Box:Paketti:Digitakt:Export Sample Chain...` 📋
- `DSP Device:Paketti:Digitakt:Export Sample Chain...` 📋
- `Mixer:Paketti:Digitakt:Export Sample Chain...` 📋

Comprehensive dialog for Digitakt sample chain export with full control.

**Dialog Options:**

**Hardware Selection:**
- **Digitakt (Mono)** - Original Digitakt (mono only)
- **Digitakt 2 (Stereo)** - Digitakt 2 (stereo support)

**Export Mode:**
- **Chain (Direct Concatenation)** - Samples joined end-to-end
- **Spaced (Fixed Slots)** - Fixed-length slots with padding

**Slot Count (Spaced Mode):**
- Auto (calculate optimal)
- 4, 8, 16, 32, or 64 slots

**Mono Conversion (Digitakt 1):**
- Mix to Mono - L+R mix
- Left Channel Only
- Right Channel Only

**Output:**
- 48kHz, 16-bit WAV
- Digitakt-compatible format
- Transfer file ready

## Quick Export Presets

### Quick Export (Digitakt Mono)

**Keybindings:**
- `Global:Paketti:Export Digitakt Quick Export (Digitakt Mono)` ⌨️
- `Sample Editor:Paketti:Digitakt Quick Export Mono` ⌨️

**Menu:** `Sample Editor:Paketti:Digitakt:Quick Export (Digitakt Mono)` 📋

One-click export optimized for original Digitakt (mono, chain mode).

**Settings:**
- Digitakt 1 (mono)
- Chain mode (direct concatenation)
- Mix to mono
- 48kHz, 16-bit

### Quick Export (Digitakt 2 Stereo)

**Keybindings:**
- `Global:Paketti:Export Digitakt Quick Export (Digitakt 2 Stereo)` ⌨️
- `Sample Editor:Paketti:Digitakt Quick Export Stereo` ⌨️

**Menu:** `Sample Editor:Paketti:Digitakt:Quick Export (Digitakt 2 Stereo)` 📋

One-click export for Digitakt 2 (stereo, chain mode).

**Settings:**
- Digitakt 2 (stereo)
- Chain mode
- Preserve stereo
- 48kHz, 16-bit

### Quick Export (Chain Mode)

**Keybindings:**
- `Global:Paketti:Export Digitakt Quick Export (Chain Mode)` ⌨️
- `Sample Editor:Paketti:Digitakt Quick Export Chain` ⌨️

**Menu:** `Sample Editor:Paketti:Digitakt:Quick Export (Chain Mode)` 📋

Default chain mode export (auto-detects hardware).

## Export Modes Explained

### Chain Mode (Direct Concatenation)

Samples are joined end-to-end without gaps or padding.

**Advantages:**
- Minimal file size
- No wasted space
- Maximum sample count per chain

**Format:**
```
[Sample1][Sample2][Sample3][Sample4]...
```

**Use Case:** Pack maximum number of short samples (drum hits).

### Spaced Mode (Fixed Slots)

Samples are placed in fixed-length slots with padding.

**Advantages:**
- Predictable slice positions
- Easy to calculate offsets
- Uniform slice lengths

**Format (4 slots):**
```
[Sample1+padding][Sample2+padding][Sample3+padding][Sample4+padding]
```

**Slot Calculation:**
- Auto: `Total_Length / Sample_Count`
- Fixed: User-specified slot size

**Use Case:** 
- Loops that need consistent timing
- Samples with varying lengths
- Simplified slice management

## Digitakt Workflow

1. **Prepare:** Organize samples in Renoise instrument
2. **Export:** Use dialog or quick export
3. **Transfer:** Copy WAV to Digitakt via Overbridge or USB
4. **Load:** Import sample chain on Digitakt
5. **Slice:** Digitakt auto-detects slice boundaries

**Tips:**
- Normalize samples before export for consistent levels
- Use 120 samples max per chain (Digitakt limitation)
- Name chains descriptively for easy Digitakt browsing

---

# WAV CUE Marker Import/Export

**Source:** `PakettiWavCueExtract.lua` | **Features:** 18

Import and export WAV files with CUE markers - support for both external .cue files and embedded CUE chunk headers.

## Load WAV with CUE Markers

**Keybindings:**
- `Global:Paketti:Load WAV with CUE Markers...` ⌨️
- `Sample Editor:Paketti:Load WAV with CUE Markers...` ⌨️

**Menu:**
- `Sample Editor:Paketti:Load WAV with CUE Markers...` 📋
- `Sample Navigator:Paketti:Load WAV with CUE Markers...` 📋
- `Main Menu:File:Load WAV with CUE Markers...` 📋
- `Main Menu:Tools:Paketti:!Sample Editor:Load WAV with CUE Markers...` 📋

Loads WAV file and automatically imports CUE markers as Renoise slice markers.

**Supports Two CUE Formats:**

### External .cue File
Looks for matching .cue file (same name as WAV) in same directory.

**Example:** `drumloop.wav` + `drumloop.cue`

**Process:**
1. Loads WAV audio
2. Finds matching .cue file
3. Parses CUE marker positions
4. Creates Renoise slice markers

### Embedded CUE Chunk
Reads CUE chunk from WAV header (if present).

**Process:**
1. Loads WAV audio
2. Parses embedded CUE chunk in WAV header
3. Extracts marker positions
4. Creates Renoise slice markers

**Auto-detection:**
- Checks for embedded CUE chunk first
- Falls back to external .cue file
- Shows status message indicating source

**Use Cases:**
- Import pre-sliced loops
- Load samples with markers from other DAWs
- Import drumkits with slice points
- Use samples from commercial libraries with CUE data

## Export WAV with CUE File

**Keybindings:**
- `Global:Paketti:Export WAV with CUE File...` ⌨️
- `Sample Editor:Paketti:Export WAV with CUE File...` ⌨️

**Menu:**
- `Sample Editor:Paketti:Export WAV with CUE File...` 📋
- `Sample Navigator:Paketti:Export WAV with CUE File...` 📋
- `Main Menu:File:Export WAV with CUE File...` 📋
- `Main Menu:Tools:Paketti:!Sample Editor:Export WAV with CUE File...` 📋

Exports sample with external .cue text file containing slice marker positions.

**Output Files:**
- `sample.wav` - Audio file
- `sample.cue` - Text file with marker positions

**CUE File Format:**
```
FILE "sample.wav" WAVE
TRACK 01 AUDIO
  INDEX 01 00:00:00
TRACK 02 AUDIO
  INDEX 01 00:00:500
TRACK 03 AUDIO
  INDEX 01 00:01:000
...
```

**Use Cases:**
- Share sliced samples with other DAWs
- Archive slice positions separately
- Text-editable slice points
- Compatible with CD burning software

## Export WAV with Embedded CUE Headers

**Keybindings:**
- `Global:Paketti:Export WAV with Embedded CUE Headers...` ⌨️
- `Sample Editor:Paketti:Export WAV with Embedded CUE Headers...` ⌨️

**Menu:**
- `Sample Editor:Paketti:Export WAV with Embedded CUE Headers...` 📋
- `Sample Navigator:Paketti:Export WAV with Embedded CUE Headers...` 📋
- `Main Menu:File:Export WAV with Embedded CUE Headers...` 📋
- `Main Menu:Tools:Paketti:!Sample Editor:Export WAV with Embedded CUE Headers...` 📋

Exports WAV with CUE markers embedded in WAV header (single file).

**Output:**
- Single WAV file
- CUE chunk embedded in WAV header
- Markers preserved within audio file

**Advantages:**
- Single file (no separate .cue)
- Markers travel with audio
- Cleaner file management
- Direct DAW compatibility

**CUE Chunk Structure:**
Embeds binary CUE chunk in RIFF WAV header with:
- Cue point count
- Sample positions for each marker
- Label IDs

**Use Cases:**
- Export to Ableton Live (reads embedded CUEs)
- Sample library creation
- Single-file archiving
- Cross-DAW compatibility

## Batch OT to CUE Converter

**Source:** `PakettiWavCueExtract.lua`

Batch converts a folder of Octatrack .ot files to CUE files for use with audio players, CD burning software, and other DAWs.

**Keybindings:**
- `Global:Paketti:Batch Convert .ot to CUE Files` ⌨️

**Menu:**
- `Main Menu:File:Paketti Export:Octatrack Batch Convert .ot to CUE Files...` 📋
- `Sample Editor:Paketti:Octatrack:Batch Convert .ot to CUE Files...` 📋

**How it Works:**
1. Select folder containing .ot files (matching WAV files must be in same folder)
2. For each .ot file:
   - Finds matching WAV file (same name, .wav extension)
   - Reads slice data from .ot file
   - Reads WAV header for sample rate (needed for timing)
   - Generates .cue file with track entries for each slice
3. Reports results (created, skipped, missing WAV, failed)

**Features:**
- **Recursive search** - Finds .ot files in subfolders
- **Auto WAV matching** - Locates WAV files by base name
- **CD frame timing** - Proper 75 fps for CUE format
- **Skip existing** - Won't overwrite existing CUE files
- **Missing WAV detection** - Reports when no matching audio found
- **Detailed console log** - Full processing info in scripting terminal

**Output:**
- `filename.cue` - CUE sheet with track entries for each slice

**CUE File Format:**
```
FILE "sample.wav" WAVE

  TRACK 01 AUDIO
    TITLE "Slice 01"
    INDEX 01 00:00:00

  TRACK 02 AUDIO
    TITLE "Slice 02"
    INDEX 01 00:01:25
...
```

**Use Cases:**
- Convert Octatrack sliced samples for other DAWs
- Create CD-compatible track sheets from OT samples
- Archive OT slice data in portable text format
- Share sliced samples with non-Elektron users

## Supported Applications

**Import CUE Support:**
- Renoise (via Paketti)
- Ableton Live
- FL Studio
- Reaper
- Pro Tools
- Logic Pro
- Cubase/Nuendo

**Export Compatibility:**
- External .cue: Universal text format
- Embedded CUE: Supported by most modern DAWs

---


---

# Paketti Function Search (Autocomplete)

**Source:** `PakettiAutocomplete.lua` | **Features:** 12

Intelligent function search and launcher with fuzzy matching, usage statistics, custom abbreviations, and learning capabilities.

## Paketti Function Search Dialog

**Keybindings:**
- `Global:Paketti:Paketti Function Search...` ⌨️
- `Pattern Editor:Paketti:Paketti Function Search...` ⌨️
- `Mixer:Paketti:Paketti Function Search...` ⌨️

**MIDI:** `Paketti:Paketti Function Search...` 🎹

Opens intelligent function search dialog with real-time filtering and ranking.

**Features:**

### Search Interface
- **Fuzzy Matching** - Type partial names, find matches
- **Multi-word Search** - Space-separated terms (AND logic)
- **Real-time Filtering** - Results update as you type
- **Ranked Results** - Most relevant matches first
- **Context Display** - Shows menu/keybinding/MIDI context

### Search Algorithm
**Matching:**
- Abbreviation expansion (custom shortcuts)
- Case-insensitive fuzzy search
- Word boundary matching
- Substring matching

**Ranking Factors:**
1. **Usage frequency** - Recently/frequently used functions rank higher
2. **Match quality** - Exact matches > partial matches
3. **Abbreviation matches** - Custom abbreviations prioritized
4. **Context relevance** - Matches current view context

### Usage Statistics
- Tracks function invocation count
- Remembers last use time
- Learns your workflow patterns
- Adapts ranking to your usage

### Function Database
Automatically indexes:
- All menu entries
- All keybindings
- All MIDI mappings
- All Paketti functions

**Database includes:**
- Function names
- Keybinding assignments
- MIDI mapping assignments
- Menu context paths
- Invoke functions

### Execution
**Select & Execute:**
1. Type search term
2. Use arrow keys to select result
3. Press Enter to execute
4. Dialog closes automatically

**Or click to execute** - Mouse support

## Add Custom Abbreviation

**Keybinding:** `Global:Paketti:Add Autocomplete Abbreviation` ⌨️

Creates custom shortcut abbreviations for frequently-used functions.

**Example Abbreviations:**
- `ns` → "New Send Track"
- `rf` → "Render Selection to Sample"
- `bs` → "Beat Sync"
- `pp` → "PlayerPro"

**Process:**
1. Invoke "Add Abbreviation"
2. Enter abbreviation code (2-4 letters)
3. Enter full function name
4. Saves to abbreviations list
5. Now type abbreviation in search to find function instantly

**Storage:** Abbreviations persist between Renoise sessions

**Use Case:** 
- Speed up common operations
- Create personal shortcuts
- Reduce typing for long function names

## Reset Usage Statistics

**Keybinding:** `Global:Paketti:Reset Autocomplete Usage Statistics` ⌨️

Clears all function usage history and ranking data.

**Resets:**
- Invocation counts
- Last use timestamps
- Learning data
- Ranking preferences

**Effect:** Function search returns to default ranking (alphabetical).

**Use Case:** Start fresh after workflow change, reset after experimentation.

## Cache Management

### Nuke Autocomplete Cache

**Keybinding:** `Global:Paketti:Nuke Autocomplete Cache` ⌨️

Completely deletes function search cache (forces rebuild).

**Deletes:**
- Function database
- Index data
- Cached search results

**When to use:**
- After installing new tools
- After Paketti updates
- If search results seem incorrect
- Troubleshooting

### Rebuild Autocomplete Cache

**Keybinding:** `Global:Paketti:Rebuild Autocomplete Cache` ⌨️

Manually rebuilds function database from scratch.

**Rebuild Process:**
1. Scans all Paketti files
2. Extracts menu entries
3. Extracts keybindings
4. Extracts MIDI mappings
5. Builds searchable index
6. Saves cache

**Auto-rebuild triggers:**
- First run
- Cache missing
- Paketti version change

## Debug Autocomplete Search

**Keybinding:** `Global:Paketti:Debug Autocomplete Search` ⌨️

Opens debug mode for search algorithm testing.

**Debug Output:**
- Search query parsing
- Match algorithm steps
- Ranking score calculations
- Database lookup results
- Performance metrics

**Use Case:** Troubleshoot search behavior, understand ranking logic.

## Workflow Tips

**Power User Shortcuts:**
1. **Quick Search** - Press search hotkey → type 2-3 letters → Enter
2. **Abbreviations** - Create abbreviations for top 10 functions
3. **Learn Mode** - Let usage statistics adapt to your workflow
4. **Context Awareness** - Search prioritizes functions relevant to current view

**Example Workflow:**
```
User presses Global:Paketti:Paketti Function Search
Types: "send"
Results show (ranked):
  1. Create New Send Track (used 45 times)
  2. Send Device (Preset++) (used 12 times)
  3. Multiband Send Device (used 3 times)
User presses Enter → Creates send track immediately
```

---

# Device Chain Presets

**Source:** `PakettiDeviceChains.lua` | **Features:** 9

Pre-configured device chain loader for instant professional effect setups and mixing workflows.

## Load Random Device Chain

**Keybinding:** `Global:Paketti:Create New Track&Load Random Device Chain/Preset` ⌨️

Creates new track and loads random device chain from configured device chain folder.

**Process:**
1. Creates new track after selected track
2. Scans device chain folder
3. Selects random chain file
4. Loads chain to new track

**Configuration:** Set device chain path in Paketti preferences

**Use Case:** 
- Instant inspiration
- Random effect experimentation
- Quick track creation with processing

## Pre-configured Device Chains

### EQ10 Macro Experimental

**Keybinding:** `Global:Paketti:Load Device Chain EQ10 Macro Experimental` ⌨️

Loads experimental EQ 10 setup with macro controls for quick EQ adjustments.

**Features:**
- Macro-mapped frequency/gain controls
- Quick low/mid/high adjustments
- Visual EQ interface
- Pre-configured bands

### SimpleSend

**Keybinding:** `Global:Paketti:Load Device Chain SimpleSend` ⌨️

Loads basic send chain with routing already configured.

**Setup:**
- Send Device
- Pre-routed to send track
- Ready for parallel processing

### Paketti Doofer Rudiments

**Keybinding:** `Global:Paketti:Load Device Chain Paketti Doofer Rudiments` ⌨️

Loads essential Doofer chain with Paketti's core processing elements.

**Contents:**
- Basic filter
- Gain staging
- Output limiter
- Macro controls

### ClippyClip

**Keybinding:** `Global:Paketti:Load Device Chain ClippyClip` ⌨️

Loads clipper chain for aggressive distortion and loudness.

**Setup:**
- Gain boost
- Soft clipper
- Hard clipper
- Output ceiling
- Macro-controlled clip amount

**Use Case:** Saturate drums, aggressive limiting, distortion effects.

## NPC1 (Neutral Preset Collection 1)

Professional mixing chains from Neutral Preset Collection.

### Track Compressor (NPC1)

**Keybinding:** `Global:Paketti:Load Device Chain Track Compressor (NPC1)` ⌨️

Neutral, transparent track compression.

**Settings:**
- Moderate ratio (4:1)
- Automatic makeup gain
- Gentle attack/release
- Transparent character

**Use Case:** General-purpose track compression, glue compression.

### Low - High Cut (steep) (NPC1)

**Keybinding:** `Global:Paketti:Load Device Chain Low - High Cut (steep) (NPC1)` ⌨️

Steep-slope high-pass and low-pass filters.

**Filters:**
- **Low Cut:** 80Hz, 48dB/octave
- **High Cut:** 12kHz, 48dB/octave
- Steep rolloff
- Minimal phase distortion

**Use Case:** Aggressive frequency sculpting, remove rumble/hiss.

### Low - High Cut (halfsteep) (NPC1)

**Keybinding:** `Global:Paketti:Load Device Chain Low - High Cut (halfsteep) (NPC1)` ⌨️

Moderate-slope filters for gentler frequency control.

**Filters:**
- **Low Cut:** 80Hz, 24dB/octave
- **High Cut:** 12kHz, 24dB/octave
- Balanced rolloff
- Musical character

**Use Case:** Standard high/low pass, general cleanup.

### Low - High Cut (flat) (NPC1)

**Keybinding:** `Global:Paketti:Load Device Chain Low - High Cut (flat) (NPC1)` ⌨️

Gentle-slope filters for subtle frequency shaping.

**Filters:**
- **Low Cut:** 80Hz, 12dB/octave
- **High Cut:** 12kHz, 12dB/octave
- Gentle rolloff
- Transparent, natural sound

**Use Case:** Subtle filtering, preserve character, gentle cleanup.

## Device Chain Folder Setup

**Configuration Path:** Paketti Preferences → Device Chain Path

**Folder Structure:**
```
DeviceChains/
  ├── Compression/
  ├── EQ/
  ├── Effects/
  ├── Mixing/
  └── Mastering/
```

**Creating Custom Chains:**
1. Setup devices on track
2. Right-click track header
3. Save Device Chain
4. Save to configured folder
5. Now available in random loader

---

# Dynamic View Cycling

**Source:** `PakettiDynamicViews.lua` | **Features:** 9

Programmable view cycling system - create custom shortcuts to cycle between specific Renoise views.

## Cycle Dynamic View (1-9)

**Keybindings:** 9 keybindings:
- `Global:Paketti:Cycle Paketti Dynamic View 1` ⌨️
- `Global:Paketti:Cycle Paketti Dynamic View 2` ⌨️
- ...through 9

**MIDI:** 9 MIDI mappings:
- `Paketti:Cycle Paketti Dynamic View 1` 🎹
- `Paketti:Cycle Paketti Dynamic View 2` 🎹
- ...through 9

Cycles through user-configured view sequence for each dynamic view slot (1-9).

**How It Works:**
1. Each slot (1-9) has a configurable view sequence
2. Pressing keybinding cycles to next view in sequence
3. Loops back to first view after last
4. Independent cycling for each slot

**Example Slot 1:**
```
Press once: Pattern Editor
Press again: Mixer
Press again: Sample Editor
Press again: Pattern Editor (loops)
```

## Dynamic View MIDI Knob Control

**MIDI:** 9 MIDI mappings:
- `Paketti:Midi Paketti Dynamic View 1 x[Knob]` 🎹
- ...through 9

Direct knob/fader control to jump to specific view in sequence.

**Knob Behavior:**
- 0-127 mapped to view sequence
- 0-31: View 1
- 32-63: View 2
- 64-95: View 3
- 96-127: View 4

**Use Case:** Hardware controller with knobs/faders to jump directly to views.

## Dynamic View Preferences Dialogs

**Keybindings:**
- `Global:Paketti:Paketti Dynamic View Preferences Dialog 1-3...` ⌨️
- `Global:Paketti:Paketti Dynamic View Preferences Dialog 4-6...` ⌨️
- `Global:Paketti:Paketti Dynamic View Preferences Dialog 7-9...` ⌨️

**MIDI:**
- `Paketti:Paketti Dynamic View Preferences Dialog 1-3...` 🎹
- `Paketti:Paketti Dynamic View Preferences Dialog 4-6...` 🎹
- `Paketti:Paketti Dynamic View Preferences Dialog 7-9...` 🎹

Opens configuration dialog for dynamic view slots (grouped by 3).

**Dialog Features:**

### View Sequence Configuration
For each dynamic view slot:
- **Enable/Disable** - Toggle slot on/off
- **View List** - Add/remove/reorder views
- **View Selection** - Dropdown with all Renoise views

**Available Views:**
- Pattern Editor
- Mixer
- Sample Editor
- Sample Keyzones
- Sample Effects
- Instrument Settings
- Pattern Matrix
- Automation
- Disk Browser

### Configuration Controls
- **Add View** - Append view to sequence
- **Remove View** - Delete view from sequence
- **Move Up/Down** - Reorder views
- **Reset** - Clear sequence
- **Test** - Preview cycling behavior

## Use Cases

### Workflow Presets

**Slot 1: Composing**
```
Pattern Editor → Pattern Matrix → Disk Browser
```

**Slot 2: Mixing**
```
Mixer → Pattern Editor → Automation
```

**Slot 3: Sound Design**
```
Sample Editor → Sample Keyzones → Sample Effects → Instrument Settings
```

**Slot 4: Arrangement**
```
Pattern Matrix → Pattern Editor → Mixer
```

### MIDI Controller Setup

Map MIDI pads/buttons to dynamic views:
- Pad 1: Composing workflow (Slot 1)
- Pad 2: Mixing workflow (Slot 2)
- Pad 3: Sound design workflow (Slot 3)
- Pad 4: Arrangement workflow (Slot 4)
- Knob 1: Direct view jump (Slot 1 knob control)

### Single-Press Context Switching

**Instead of:**
```
Pattern Editor → (press 5 keys) → Sample Editor → (press 3 keys) → Keyzones
```

**With Dynamic View:**
```
Press Slot 3 → Sample Editor
Press Slot 3 again → Keyzones
Press Slot 3 again → Sample Effects
```

---


---

# Sub-Column Modifier

**Source:** `PakettiSubColumnModifier.lua` | **Features:** 11

MIDI-controlled sub-column editing for note columns, effect columns, panning, delay, and volume - fine-grained pattern editing via hardware controllers.

## MIDI Sub-Column Control

### Command Absolute Control

**MIDI:** `Paketti:Sub Column Command Absolute Control` 🎹

Absolute MIDI control for effect command values in selected sub-column.

**How It Works:**
1. Select effect column
2. Move MIDI knob/fader
3. Effect command value follows controller (0x00-0xFF)

**Example:**
- Select 0C (volume) column
- Move MIDI knob
- Value changes: 0C00 → 0C7F → 0CFF

### Command Relative Control

**MIDI:** `Paketti:Sub Column Command Relative Control` 🎹

Relative MIDI control for incrementing/decrementing effect command values.

**Behavior:**
- CC > 64: Increment effect value
- CC < 64: Decrement effect value
- Amount based on distance from 64

**Use Case:** Encoder-style MIDI controllers with relative output.

### Value Absolute Control

**MIDI:** `Paketti:Sub Column Value Absolute Control` 🎹

Absolute MIDI control for note/instrument/volume/panning/delay values in selected sub-column.

**Applies to:**
- **Note Column:** Note values (C-0 to G-9)
- **Instrument Column:** Instrument number (00-FF)
- **Volume Column:** Volume value (00-80)
- **Panning Column:** Panning value (00-80)
- **Delay Column:** Delay value (00-FF)

### Value Relative Control

**MIDI:** `Paketti:Sub Column Value Relative Control` 🎹

Relative MIDI control for incrementing/decrementing values in selected sub-column.

**Use Case:** Fine-tune values with encoder, nudge notes up/down.

## Show Sub Column Status

**Keybinding:** `Pattern Editor:Paketti:Show Paketti Sub Column Status` ⌨️

Displays current sub-column selection status in status bar.

**Shows:**
- Selected track
- Selected column type (Note/FX/Vol/Pan/Delay)
- Sub-column index
- Current value
- Available range

## Sub-Column Aware Pattern Writing

### Write Random (SubColumn Aware)

**Keybindings:**
- `Pattern Editor:Paketti:Write Values/Notes Random (SubColumn Aware)` ⌨️
- `Pattern Editor:Paketti:Write Values/Notes Random EditStep (SubColumn Aware)` ⌨️

Writes random values to selected sub-column.

**Random mode:** Fills every line in selection
**EditStep mode:** Fills lines based on edit step value

**Behavior by column:**
- **Note:** Random notes within octave range
- **Instrument:** Random instrument numbers
- **Volume:** Random volume (00-80)
- **Effect:** Random effect values (00-FF)
- **Panning:** Random pan (00-80)
- **Delay:** Random delay (00-FF)

### Write Ascending (SubColumn Aware)

**Keybindings:**
- `Pattern Editor:Paketti:Write Values/Notes Ascending (SubColumn Aware)` ⌨️
- `Pattern Editor:Paketti:Write Values/Notes Ascending EditStep (SubColumn Aware)` ⌨️

Writes ascending values to selected sub-column.

**Pattern:**
- Starts at current value
- Increases each line
- Wraps at maximum value

**Example (Volume):**
```
00
10
20
30
...
80 (wraps to 00)
```

### Write Descending (SubColumn Aware)

**Keybindings:**
- `Pattern Editor:Paketti:Write Values/Notes Descending (SubColumn Aware)` ⌨️
- `Pattern Editor:Paketti:Write Values/Notes Descending EditStep (SubColumn Aware)` ⌨️

Writes descending values to selected sub-column.

**Pattern:**
- Starts at current value
- Decreases each line
- Wraps at minimum value

**Use Cases:**

**MIDI Hardware Integration:**
- Map MIDI controller to sub-column control
- Live pattern editing with knobs/faders
- Hardware sequencer-style workflow

**Generative Patterns:**
- Random sub-column fills
- Ascending/descending sequences
- EditStep-based rhythmic patterns

**Fine Control:**
- Precise effect value tweaking
- Sub-column-specific editing
- Non-destructive pattern manipulation

---

# XRNIT (Track/Instrument Preset Loader)

**Source:** `PakettiXRNIT.lua` | **Features:** 11

Quick-load system for device chains (.xrnt) and instruments (.xrni) with 3 configurable preset slots per type.

## Load Device Chain from Slot (1-3)

**Keybindings:** 3 keybindings:
- `Global:Paketti:Load Device Chain from Slot 1` ⌨️
- `Global:Paketti:Load Device Chain from Slot 2` ⌨️
- `Global:Paketti:Load Device Chain from Slot 3` ⌨️

**Menu:** 6 menu entries (2 contexts each):
- `DSP Chain:Paketti:XRNIT:Load Device Chain from Slot 1-3` 📋
- `Mixer:Paketti:XRNIT:Load Device Chain from Slot 1-3` 📋

Loads pre-configured device chain (.xrnt file) to selected track.

**Configuration:**
- Set device chain paths in Paketti preferences
- 3 slots for frequently-used chains
- Instant recall

**Use Cases:**
- **Slot 1:** Vocal chain (comp + EQ + reverb)
- **Slot 2:** Drum bus (comp + saturation + EQ)
- **Slot 3:** Master chain (limiter + dither)

## Load Instrument from Slot (1-3)

**Keybindings:** 3 keybindings:
- `Global:Paketti:Load Instrument from Slot 1` ⌨️
- `Global:Paketti:Load Instrument from Slot 2` ⌨️
- `Global:Paketti:Load Instrument from Slot 3` ⌨️

**Menu:** 6 menu entries:
- `Instrument Box:Paketti:XRNIT:Load Instrument from Slot 1-3` 📋
- `Instrument Selector:Paketti:XRNIT:Load Instrument from Slot 1-3` 📋

Loads pre-configured instrument (.xrni file) to new instrument slot.

**Configuration:**
- Set instrument paths in Paketti preferences
- 3 slots for go-to instruments
- Instant insertion

**Use Cases:**
- **Slot 1:** Kick drum (favorite 808)
- **Slot 2:** Bass synth (signature sound)
- **Slot 3:** Lead synth (main melody preset)

## Load Both (Device Chain + Instrument) from Slot (1-3)

**Keybindings:** 3 keybindings:
- `Global:Paketti:Load Device Chain + Instrument from Slot 1` ⌨️
- `Global:Paketti:Load Device Chain + Instrument from Slot 2` ⌨️
- `Global:Paketti:Load Device Chain + Instrument from Slot 3` ⌨️

**Menu:** 6 menu entries:
- `DSP Chain:Paketti:XRNIT:Load Device Chain + Instrument from Slot 1-3` 📋
- `Mixer:Paketti:XRNIT:Load Device Chain + Instrument from Slot 1-3` 📋

Loads both device chain and instrument simultaneously to selected track.

**Process:**
1. Creates new instrument (loads .xrni)
2. Loads device chain to track (.xrnt)
3. Selects new instrument
4. Ready to play

**Use Cases:**

**Template Tracks:**
- **Slot 1:** Vocal track (vocal instrument + vocal processing chain)
- **Slot 2:** Drum track (drum kit + drum bus processing)
- **Slot 3:** Bass track (bass instrument + bass processing chain)

**Instant Song Starters:**
- Load Slot 1: Main lead + lead processing
- Load Slot 2: Rhythm section + rhythm processing
- Load Slot 3: Pad + ambient processing
- Start composing immediately

**Setup:**
1. Open Paketti Preferences
2. Navigate to XRNIT section
3. For each slot (1-3):
   - Set .xrnt path (device chain)
   - Set .xrni path (instrument)
4. Save preferences
5. Now accessible via keybindings/menus

---

# Tuning Display & Microtonal Control

**Source:** `PakettiTuningDisplay.lua` | **Features:** 8

Apply custom tuning systems to tracks - support for microtonal scales, historical temperaments, and real-time tuning input.

## Apply User-Set Tuning to Selected Track

**Keybinding:** `Pattern Editor:Paketti:Apply User-Set Tuning to Selected Track` ⌨️

**Menu:** `Pattern Editor:Paketti:Tuning:Apply User-Set Tuning to Selected Track` 📋

Applies currently configured tuning system to all notes in selected track.

**Process:**
1. Scans all notes in track
2. Calculates tuning offset for each note
3. Inserts 01xx pitch offset effect commands
4. Tunes each note to match tuning system

**Tuning Systems Supported:**
- **12-TET:** Standard equal temperament (reference)
- **Just Intonation:** Pure interval ratios
- **Pythagorean:** Perfect fifths tuning
- **Quarter-comma Meantone:** Renaissance tuning
- **19-TET:** 19 equal divisions
- **24-TET:** Quarter-tone tuning
- **31-TET:** Optimal meantone approximation
- **Custom:** User-defined cent offsets

## Clear Tuning Effects from Selected Track

**Keybinding:** `Pattern Editor:Paketti:Clear Tuning Effects from Selected Track` ⌨️

**Menu:** `Pattern Editor:Paketti:Tuning:Clear Tuning Effects from Selected Track` 📋

Removes all 01xx pitch offset commands from selected track (reverts to 12-TET).

**Use Case:** Undo tuning application, restore standard tuning.

## User-Set Tuning Preferences Dialog

**Keybinding:** `Pattern Editor:Paketti:User-Set Tuning Preferences Dialog` ⌨️

**Menu:** `Pattern Editor:Paketti:Tuning:User-Set Tuning Preferences Dialog...` 📋

Opens comprehensive tuning configuration dialog.

**Dialog Features:**

### Tuning System Selection
Dropdown with preset systems:
- 12-TET (Equal Temperament)
- Just Intonation (5-limit)
- Pythagorean
- Quarter-comma Meantone
- 19-TET
- 24-TET
- 31-TET
- 53-TET
- Bohlen-Pierce
- Carlos Alpha/Beta/Gamma
- Custom

### Custom Tuning Editor
For "Custom" mode:
- **12 cent offset fields** (C, C#, D, D#, E, F, F#, G, G#, A, A#, B)
- Enter cent deviation from 12-TET
- Range: -100 to +100 cents per note
- Real-time preview

**Example Custom Tuning (Minor Third Emphasis):**
```
C:   0 cents
C#:  -10 cents
D:   0 cents
Eb:  -14 cents (pure minor third)
E:   0 cents
...
```

### Reference Frequency
- **A4 Reference:** 440Hz (default), adjustable
- Affects all pitch calculations
- Historical pitch: 415Hz (Baroque), 432Hz (alternative)

### Visualization
- **Cents deviation graph** - Visual representation
- **Interval quality display** - Shows pure vs tempered intervals
- **Beat frequency calculator** - Predicts beating intervals

## Toggle Auto-Input Tuning

**Keybinding:** `Pattern Editor:Paketti:Toggle Auto-Input Tuning` ⌨️

**Menu:** `Pattern Editor:Paketti:Tuning:Toggle Auto-Input Tuning` 📋

Enables/disables real-time tuning for incoming MIDI notes.

**Auto-Input Mode:**
- **Enabled:** Notes entered via MIDI automatically get 01xx commands
- **Disabled:** Notes entered normally (12-TET)

**Workflow:**
1. Configure tuning system in preferences
2. Enable Auto-Input Tuning
3. Play MIDI keyboard
4. Notes are automatically tuned as entered
5. No post-processing needed

**Use Cases:**

### Microtonal Composition
- Compose in 24-TET (quarter tones)
- Compose in Just Intonation (pure harmonies)
- Explore non-Western scales

### Historical Music
- Baroque music (Meantone temperament)
- Medieval music (Pythagorean tuning)
- Renaissance music (Quarter-comma meantone)

### Experimental Music
- Bohlen-Pierce (non-octave scale)
- Carlos scales (electronic music tunings)
- Custom stretched/compressed octaves

### Workflow Example
```
1. Open Tuning Preferences
2. Select "Just Intonation"
3. Apply to track
4. All notes now in pure ratios
5. Sounds more consonant, less beating
```

---

# Theme Selector

**Source:** `PakettiThemeSelector.lua` | **Features:** 3

Visual theme browser with favorites system and random theme selection for Renoise GUI customization.

## Open Theme Selector Dialog

**Keybinding:** `Global:Paketti Theme Selector:Open Paketti Theme Selector Dialog...` ⌨️

Comprehensive theme selection interface with preview and management.

**Dialog Features:**

### Theme Browser
- **Theme List** - All installed themes
- **Preview Pane** - Visual theme preview
- **Current Theme** - Highlighted in list
- **Search/Filter** - Find themes by name
- **Sort Options** - Name, date, favorites

### Theme Information
For each theme:
- Theme name
- Author
- Description
- Install date
- Preview image (if available)
- Favorite status

### Theme Actions
- **Apply Theme** - Switch to selected theme
- **Add to Favorites** - Mark theme as favorite
- **Remove from Favorites** - Unmark theme
- **Delete Theme** - Remove from system (confirmation required)
- **Reveal in Finder/Explorer** - Open theme folder

### Favorites System
- **Star/favorite themes** - Quick access to preferred themes
- **Favorites filter** - Show only favorite themes
- **Favorites count** - Display in status

### Random Selection
- **Random button** - Pick random theme from all
- **Random favorites** - Pick random from favorites only

## Pick Random Theme (All)

**Keybinding:** `Global:Paketti Theme Selector:Pick a Random Theme (All)` ⌨️

Instantly switches to random theme from all installed themes.

**Process:**
1. Scans theme folder
2. Selects random theme
3. Applies immediately
4. Shows theme name in status

**Use Case:**
- Visual inspiration
- Break creative blocks
- Discover forgotten themes
- Surprise aesthetics

## Pick Random Theme (Favorites)

**Keybinding:** `Global:Paketti Theme Selector:Pick a Random Theme (Favorites)` ⌨️

Switches to random theme from favorites list only.

**Process:**
1. Filters to favorites
2. Selects random favorite
3. Applies immediately

**Use Case:**
- Rotate between preferred themes
- Variety within known-good options
- Mood-based theme selection

### Workflow Tips

**Create Theme Collections:**
1. **Day Themes** (bright, high contrast)
   - Mark as favorites
   - Use random favorites for variety
2. **Night Themes** (dark, low contrast)
   - Separate favorite group
   - Swap between day/night sets

**Quick Theme Switching:**
- Bind "Random Favorites" to MIDI pad
- Press pad when feeling uncreative
- New visual environment = new ideas

**Theme Organization:**
1. Browse all themes (Open dialog)
2. Star favorites (5-10 best)
3. Daily: Press "Random Favorites"
4. Weekly: Press "Random All" to rediscover

---


---

# Transpose Blocks

**Source:** `PakettiTransposeBlock.lua` | **Features:** 3

Advanced block transposition with visual selection and independent octave/semitone/cent control.

## Transpose Blocks Dialog

**Keybindings:**
- `Global:Paketti:Transpose Blocks Dialog...` ⌨️
- `Pattern Editor:Paketti:Transpose Blocks Dialog...` ⌨️
- `Mixer:Paketti:Transpose Blocks Dialog...` ⌨️

Comprehensive transposition interface for selected note blocks with fine-grained control.

**Dialog Features:**

### Block Selection
- **Visual Block Display** - Shows selected pattern range
- **Note Count** - Number of notes in selection
- **Track Display** - Which tracks are affected
- **Column Display** - Which note columns included

### Transpose Controls

**Octave Transpose:**
- Range: -4 to +4 octaves
- Slider or numeric entry
- Instant octave jumps

**Semitone Transpose:**
- Range: -12 to +12 semitones
- Independent of octave control
- Fine melodic adjustment

**Cent Transpose (Microtonal):**
- Range: -100 to +100 cents
- 1 cent = 1/100 semitone
- Adds 01xx pitch offset commands
- Microtonal adjustments

### Transpose Options

**Note Range Limiting:**
- **Clip to C-0 / G-9** - Prevents out-of-range notes
- **Preserve Octaves** - Wraps notes within octave
- **Allow Off-notes** - Converts out-of-range to OFF

**Column Handling:**
- **Selected Columns Only** - Transpose only selected note columns
- **All Columns** - Transpose all note columns in track
- **Track Selection** - Choose which tracks to affect

### Preview
- **Preview Button** - Hear result before applying
- **Undo Safeguard** - Can cancel before commit
- **Real-time Calculation** - Shows resulting notes

### Apply Actions
- **Transpose Up** - Apply positive transposition
- **Transpose Down** - Apply negative transposition
- **Reset** - Clear all transpose values
- **Close** - Cancel operation

**Use Cases:**

**Song Key Change:**
```
1. Select entire song (Ctrl+A)
2. Open Transpose Blocks Dialog
3. Semitone: +2 (up a whole tone)
4. Apply
5. Entire song transposed to new key
```

**Octave Doubling:**
```
1. Select melody line
2. Copy to new track (Ctrl+C, Ctrl+V)
3. Transpose Blocks: Octave +1
4. Now have melody + octave above
```

**Microtonal Tuning:**
```
1. Select chord
2. Transpose Blocks
3. Cent: +14 (pure major third adjustment)
4. Apply
5. Chord now in Just Intonation
```

---

# Sample Range Device Loader

**Source:** `PakettiSampleFXChainSlicer.lua` | **Features:** 3

One-click device chain loader for selected sample range - instant processing setup.

## Sample Range Device Loader Toggle

**Keybindings:**
- `Global:Paketti:Sample Range Device Loader Toggle` ⌨️
- `Sample Editor:Paketti:Sample Range Device Loader Toggle` ⌨️

**MIDI:** `Paketti:Sample Range Device Loader Toggle` 🎹

Opens/closes device chain loader dialog for applying effects to selected sample range.

**Features:**

### Range-Based Processing
- **Selection-Aware** - Operates on sample editor selection
- **Non-Destructive Preview** - Hear before committing
- **Quick Apply** - One-click device insertion

### Device Chain Browser
Dialog shows:
- **Available Device Chains** - All .dspchain files
- **Recent Chains** - Recently used chains
- **Favorites** - Starred chains
- **Preview** - Device list for each chain

### Apply Options
- **Insert Before Selection** - Adds devices before range
- **Insert After Selection** - Adds devices after range
- **Replace Selection** - Replaces existing devices
- **Render to New Sample** - Bakes effect into new sample

**Workflow:**
1. Select sample range in Sample Editor
2. Press Toggle keybinding
3. Dialog appears with device chain list
4. Select desired chain
5. Click Apply
6. Devices inserted/effect applied

**Use Cases:**

**Drum Hit Processing:**
```
1. Load break loop
2. Select single kick hit
3. Open Range Device Loader
4. Apply "Kick Enhancement" chain
5. Just that kick is processed
6. Other drums untouched
```

**Surgical EQ:**
```
1. Select problem frequency region
2. Load "Notch Filter" chain
3. Apply to selection
4. Rest of sample unaffected
```

**Creative FX:**
```
1. Select middle section of sample
2. Load "Reverse + Reverb" chain
3. Creates contrast in sample
4. Starts normal → FX middle → ends normal
```

---

# Volume Delay Pan Equation Calculator

**Source:** `PakettiEquationCalculator.lua` | **Features:** 2

Mathematical formula evaluator for generating volume, delay, and panning patterns in the pattern editor.

## Equation Calculator Dialog

**Keybinding:** `Pattern Editor:Paketti:Volume Delay Pan Equation Calculator...` ⌨️

**Menu:** `Pattern Editor:Paketti Gadgets:Volume Delay Pan Equation Calculator...` 📋

Opens calculator for generating algorithmic volume/delay/panning patterns using mathematical formulas.

**Dialog Features:**

### Formula Input
- **Text Field** - Enter mathematical expression
- **Variable Support** - Use `x` for line number
- **Function Support** - sin, cos, tan, abs, sqrt, etc
- **Operators** - +, -, *, /, ^, %
- **Constants** - pi, e

### Target Column Selection
- **Volume Column** - Generate volume patterns (00-80 hex)
- **Delay Column** - Generate delay patterns (00-FF hex)
- **Panning Column** - Generate panning patterns (00-80 hex, 40=center)

### Range Settings
- **Start Line** - First line of pattern range
- **End Line** - Last line of pattern range
- **Output Range Min/Max** - Scale formula output
- **Quantization** - Round to nearest value

### Preview
- **Graph Display** - Visual representation of formula
- **Value List** - Shows calculated values per line
- **Update Real-time** - Graph updates as you type

### Presets
Pre-configured formulas:
- **Linear Ramp:** `x`
- **Sine Wave:** `sin(x * 0.1) * 50 + 50`
- **Exponential:** `x^2 / 100`
- **Random Walk:** `random() * 100`
- **Sawtooth:** `x % 16`
- **Triangle:** `abs((x % 32) - 16)`

**Formula Examples:**

### Volume Fade
```
Formula: 80 - (x * 2)
Range: Line 0-40
Result: Volume fades from 80 to 00 over 40 lines
```

### Delay Wobble
```
Formula: sin(x * 0.5) * 128 + 128
Target: Delay column
Result: Sinusoidal delay modulation
```

### Auto-Pan
```
Formula: sin(x * 0.2) * 64 + 64
Target: Panning column
Result: Smooth left-right panning
```

### Exponential Curve
```
Formula: (x / 64)^2 * 128
Result: Accelerating curve (slow start, fast end)
```

### Step Pattern
```
Formula: floor(x / 4) * 16
Result: Stepped values every 4 lines
```

**Advanced Formulas:**

### Polyrhythm Volume
```
sin(x * 0.3) * 40 + 40 + cos(x * 0.2) * 20
```
Two sine waves combined for complex rhythm

### Chaotic Pattern
```
(x^2 % 128) + (sin(x) * 32)
```
Mathematical chaos for unpredictable patterns

### Envelope Follower Simulation
```
80 * exp(-x / 10)
```
Exponential decay like ADSR envelope

**Use Cases:**

### Generative Composition
- Create evolving volume patterns
- Generate rhythmic delay patterns
- Produce algorithmic panning

### Sound Design
- Mathematical modulation curves
- Precise automation shapes
- Complex polyrhythmic structures

### Experimental Music
- Chaotic patterns
- Fractal rhythms
- Mathematical music

---

# Chebyshev Polynomial Waveshaper

**Source:** `PakettiChebyshevWaveshaper.lua` | **Features:** 2

Advanced waveshaping using Chebyshev polynomials for harmonic generation and spectral transformation.

## Show Chebyshev Polynomial Waveshaper

**Keybindings:**
- `Global:Paketti:Show Chebyshev Polynomial Waveshaper` ⌨️
- `Sample Editor:Paketti:Show Chebyshev Polynomial Waveshaper` ⌨️

Opens Chebyshev polynomial waveshaper for sophisticated harmonic distortion and timbre sculpting.

**Chebyshev Polynomials:**
Mathematical functions that generate specific harmonics when used for waveshaping.

**Theory:**
- **T1:** Fundamental (no distortion)
- **T2:** Adds 2nd harmonic (octave)
- **T3:** Adds 3rd harmonic (octave + fifth)
- **T4:** Adds 4th harmonic (two octaves)
- **T5-T16:** Higher harmonics

**Dialog Features:**

### Polynomial Coefficient Controls

**16 Sliders (T1-T16):**
- Each slider controls amplitude of that polynomial
- Range: -1.0 to +1.0
- Real-time waveform update
- Visual feedback

**Coefficient Combinations:**
- **All Odd:** Adds odd harmonics (hollow sound)
- **All Even:** Adds even harmonics (rich, warm)
- **Mixed:** Complex harmonic structures
- **Single:** Isolate specific harmonics

### Waveform Display

**Input/Output Visualization:**
- **Input Waveform** - Original signal (sine reference)
- **Transfer Function** - Waveshaping curve
- **Output Waveform** - Shaped result
- **Spectrum Analyzer** - Harmonic content

### Presets

**Built-in Waveshaping Presets:**
- **Soft Clip** - T1: 0.9, T3: 0.2
- **Hard Clip** - T1: 0.5, T3: 0.4, T5: 0.1
- **Tube Saturation** - T1: 0.8, T2: 0.3, T3: 0.2
- **Foldback** - All odd harmonics
- **Ring Mod Style** - T2: 1.0 only
- **Bitcrush Style** - High order polynomials

### Processing Controls

**Dry/Wet Mix:**
- 0%: Original signal
- 100%: Fully processed
- Intermediate: Blend

**Input Drive:**
- Boosts input before waveshaping
- More drive = more harmonics
- Range: 0-200%

**Output Gain:**
- Compensates for level changes
- Auto-gain option
- Manual control

**DC Offset Removal:**
- Removes DC component
- Prevents asymmetry
- Optional

### Apply Options

- **Preview (Real-time)** - Hear while adjusting
- **Apply to Selection** - Process selected sample range
- **Apply to Sample** - Process entire sample
- **Render to New Sample** - Create processed copy

**Harmonic Recipes:**

### Classic Tube Warmth
```
T1: 0.85  (fundamental)
T2: 0.25  (2nd harmonic - warmth)
T3: 0.15  (3rd harmonic - body)
T5: 0.05  (5th harmonic - air)
Drive: 120%
```

### Aggressive Distortion
```
T1: 0.6
T3: 0.6
T5: 0.4
T7: 0.2
T9: 0.1
Drive: 180%
```

### Octave Up Effect
```
T2: 1.0  (pure 2nd harmonic)
All others: 0.0
Drive: 100%
```

### Ring Modulator
```
T2: 0.8
T4: 0.5
T6: 0.3
Drive: 150%
```

### Bitcrusher Emulation
```
T8: 0.6
T10: 0.4
T12: 0.3
T14: 0.2
Drive: 140%
```

**Use Cases:**

### Sound Design
- Custom distortion characters
- Harmonic enhancement
- Spectral transformation
- Analog emulation

### Synthesis
- Additive-style waveshaping
- Harmonic oscillators
- Formant synthesis
- Spectral effects

### Mastering
- Subtle harmonic excitement
- Analog-style saturation
- Tape emulation
- Tube warmth

### Experimental
- Mathematical audio processing
- Algorithmic distortion
- Spectral experiments
- Non-linear processing

**Advanced Techniques:**

### Dynamic Shaping
1. Apply different polynomials to transients vs sustain
2. Automate coefficients over time
3. Create evolving timbres

### Frequency-Dependent Shaping
1. Split signal into bands
2. Apply different polynomials per band
3. Recombine for complex results

### Parallel Processing
1. Dry signal + multiple polynomial outputs
2. Each output with different coefficients
3. Mix for rich, complex sound

---


---

# ProTracker MOD Sample Import

**Source:** `PakettiMODLoader.lua` | **Access:** File Import Hook

Import samples from classic Amiga ProTracker .MOD files (4-channel tracker modules).

## MOD File Import

**Access Method:** File import hook (drag & drop or File→Load Sample)

**Supported Formats:**
- `.MOD` - Standard 4-channel ProTracker format
- `M.K.` - ProTracker 1.1-3.0 (4 channels)
- `4CHN` - 4-channel FastTracker
- `6CHN` - 6-channel FastTracker
- `8CHN` - 8-channel FastTracker  
- `FLT4` - 4-channel StarTrekker
- `FLT8` - 8-channel StarTrekker

**Import Process:**
1. Drag .MOD file into Renoise
   - OR: File→Load Sample→select .MOD file
2. Paketti detects .MOD format
3. Parses 31 sample slots from MOD file
4. Extracts each sample with metadata
5. Converts 8-bit signed to unsigned
6. Imports to new Renoise instrument
7. Preserves loop points

**What Gets Imported:**
- **31 Sample Slots** - All samples from MOD (slots 1-31)
- **Sample Names** - Original ProTracker names
- **Loop Points** - Loop start/length preserved
- **Sample Data** - 8-bit mono audio converted to WAV

**What Doesn't Import:**
- Pattern data (notes/effects)
- Song arrangement
- Module tempo/speed
- Effect commands

**MOD File Structure Support:**

**Sample Headers (31 slots):**
- Sample name (22 chars)
- Sample length (words * 2 = bytes)
- Finetune value
- Volume
- Loop start position
- Loop length

**Automatic Detection:**
- Reads MOD ID at offset 1080 (M.K., 4CHN, etc)
- Calculates number of patterns
- Determines channel count (4, 6, or 8)
- Locates sample data offset

**Conversion Details:**

**Sample Format:**
- **Input:** 8-bit signed mono (-128 to +127)
- **Output:** 8-bit unsigned WAV (0 to 255)
- **Sample Rate:** 44.1kHz (upsampled from ~8363Hz Amiga)
- **Channels:** Mono

**Loop Conversion:**
- **ProTracker loop:** Start position + loop length (in words)
- **Renoise loop:** Start frame + end frame (in samples)
- **Auto-detection:** If loop length > 2, sample is looped

**Use Cases:**

**Retro Sampling:**
```
1. Drag vintage.mod into Renoise
2. 31 samples imported automatically
3. Original Amiga samples now in Renoise
4. Use for authentic retro sound
```

**Sample Library Mining:**
```
1. Import classic MOD files
2. Extract drum hits, synth sounds
3. Build vintage sample library
4. Reuse in modern productions
```

**Chiptune Production:**
```
1. Load ProTracker MOD files
2. Get authentic Amiga samples
3. Use for chiptune/8-bit music
4. Original vintage character
```

**Workflow Tips:**

**Organize Imported Samples:**
- MOD import creates one instrument with 31 samples
- Samples appear in sample list
- Original names preserved
- Loops automatically configured

**Quality Considerations:**
- **8-bit depth** - Inherent noise/grit (authentic!)
- **Low sample rate** - Amiga was ~8kHz-28kHz
- **No interpolation** - Raw conversion
- **Vintage character** - Part of the charm

**Example MOD Files:**
- Classic Amiga game soundtracks
- Demo scene productions
- Keygen music
- Tracker archives (modarchive.org)

**Technical Notes:**

**Supported Channel Counts:**
- 4 channels: Standard ProTracker
- 6 channels: Extended FastTracker
- 8 channels: OctaMED/StarTrekker

**Pattern Data:**
- Pattern data is skipped (only samples imported)
- Use original .MOD in tracker to play patterns
- Paketti focuses on sample extraction

**Empty Slots:**
- MOD files may have empty sample slots
- Empty slots are skipped during import
- Only samples with data are imported

---


---

# Drag & Drop Import Hooks (Comprehensive List)

**Paketti extends Renoise's file import system** with support for 20+ additional file formats via drag & drop or File→Load Sample/Instrument.

## Audio Sample Formats

### .REX (ReCycle V1)
**Extensions:** `.rex`
**Category:** Sample
**Import:** Drag .rex file → imports sliced loop with markers

### .RX2 (ReCycle V2)
**Extensions:** `.rx2`  
**Category:** Sample
**Import:** Drag .rx2 file → imports sliced loop with markers, preserves tempo info

### .SF2 (SoundFont)
**Extensions:** `.sf2`
**Category:** Sample
**Import:** Drag .sf2 file → extracts all samples from SoundFont bank

### .PTI (Polyend Tracker Instrument)
**Extensions:** `.pti`
**Category:** Sample
**Import:** Drag .pti file → imports Polyend Tracker instrument

### .MTI (Polyend Tracker Instrument Legacy)
**Extensions:** `.mti`
**Category:** Sample
**Import:** Drag .mti file → imports legacy Polyend instrument format

### .WT (Wavetable)
**Extensions:** `.wt`
**Category:** Sample
**Import:** Drag .wt file → imports wavetable as sliced instrument

### .OT (Octatrack Metadata)
**Extensions:** `.ot`
**Category:** Sample
**Import:** Drag .ot file → imports Octatrack slice/loop metadata, applies to selected sample

### .IFF / .8SVX / .16SV (Amiga IFF)
**Extensions:** `.iff`, `.8svx`, `.16sv`
**Category:** Sample
**Import:** Drag Amiga IFF file → converts to WAV, preserves loop points

### .CSV (PCM Writer Data)
**Extensions:** `.csv`
**Category:** Sample
**Import:** Drag .csv file → loads PCM waveform data from CSV format

### Raw Binary (.EXE, .DLL, .BIN, .SYS, .DYLIB)
**Extensions:** `.exe`, `.dll`, `.bin`, `.sys`, `.dylib`
**Category:** Sample
**Import:** Drag binary file → loads raw data as 8-bit sample at 8363Hz
**Use Case:** Experimental sound design, glitch effects

## Instrument Formats

### .ITI (Impulse Tracker Instrument)
**Extensions:** `.iti`
**Category:** Instrument
**Import:** Drag .iti file → imports Impulse Tracker instrument with envelopes

### .MID (MIDI File)
**Extensions:** `.mid`
**Category:** Instrument  
**Import:** Drag .mid file → converts MIDI to Renoise instrument/pattern

## Project/Song Formats

### .STRD / .WORK (Octatrack Bank)
**Extensions:** `.strd`, `.work`
**Category:** Song
**Import:** Drag Octatrack bank file → imports entire bank structure

### .MTP (Polyend Tracker Pattern)
**Extensions:** `.mtp`
**Category:** Sample
**Import:** Drag .mtp file → imports Polyend pattern data

### .MT (Polyend Medusa Tracker Project)
**Extensions:** `.mt`
**Category:** Song
**Import:** Drag .mt file → imports complete Medusa Tracker project

## Text-to-Speech

### .TXT (eSpeak Text-to-Speech)
**Extensions:** `.txt`
**Category:** Sample
**Import:** Drag .txt file → generates speech sample from text content using eSpeak-NG

**Process:**
1. Drag text file into Renoise
2. eSpeak reads file contents
3. Generates speech audio
4. Imports as sample
5. Configurable voice/language

## Image to Audio

### Image Formats
**Extensions:** `.png`, `.bmp`, `.jpg`, `.jpeg`, `.gif`
**Category:** Sample
**Import:** Drag image file → converts image pixel data to audio waveform

**Process:**
1. Drag image into Renoise
2. Reads pixel brightness values
3. Converts to amplitude data
4. Creates audio waveform
5. Imports as sample

**Use Case:**
- Generative sound design
- Image sonification
- Experimental composition
- Data visualization → audio

## How to Use Drag & Drop Imports

### Method 1: Drag & Drop
```
1. Open Renoise
2. Drag supported file from Finder/Explorer
3. Drop onto Renoise window
4. Paketti automatically detects format
5. File imported to appropriate location
```

### Method 2: File Menu
```
1. File → Load Sample (for sample formats)
   OR File → Load Instrument (for instrument formats)
2. Select file with supported extension
3. Click Open
4. Paketti imports file
```

### Method 3: Disk Browser
```
1. Open Disk Browser
2. Navigate to file location
3. Double-click supported file
4. Imports automatically
```

## Import Behavior by Category

### Sample Category
**Destination:** Current instrument, new sample slot
**Behavior:**
- Creates new sample in selected instrument
- Sample appears in sample list
- Sample Editor opens automatically

### Instrument Category
**Destination:** New instrument slot
**Behavior:**
- Creates new instrument after current
- Loads all samples/envelopes
- Instrument Box shows new instrument

### Song Category
**Destination:** Current song or new song
**Behavior:**
- May prompt for import options
- Can create new tracks/patterns
- Preserves project structure

## Format Priority

**If multiple loaders match same extension:**
1. Paketti loaders take precedence
2. Native Renoise formats handled first
3. Most specific loader wins

**Example:** `.wav` → Native Renoise handles normally
**Example:** `.rx2` → Paketti RX2 loader handles (not native Renoise)

## Troubleshooting

**File not recognized:**
- Check file extension matches supported list
- Some files may need manual keybinding loader
- Corrupted files won't import

**Wrong import behavior:**
- File may have wrong extension
- Loader expects specific file structure
- Check console for error messages

**Import fails:**
- File format may be variant/version
- File corruption
- Missing file dependencies

## Performance Notes

**Large Files:**
- SF2 files: May take time for large banks
- Image files: Large images = long samples
- Binary files: Imports entire file as audio

**Memory Usage:**
- Each import creates new sample
- Large imports consume RAM
- Close unused instruments to free memory

## Experimental Formats

**Binary/Raw Data:**
- `.exe`, `.dll`, `.bin` - Pure experimentation
- Creates unpredictable sounds
- Every file sounds unique
- No musical guarantee!

**Image Files:**
- Visual → audio translation
- Brightness = amplitude
- Pixel order = time
- Experimental by nature

**CSV Files:**
- Requires specific PCM format
- Custom waveform creation
- For advanced users

---


---

# Clearance (Cleanup Utilities)

**Source:** `PakettiClearance.lua` | **Features:** 7

Project cleanup utilities for removing unused samples, instruments, and empty tracks.

## Save Unused Samples

**Keybinding:** `Global:Paketti:Save Unused Samples (.WAV&.XRNI)` ⌨️

Exports all unused samples (not referenced in patterns) as WAV files + XRNI instrument.

**Process:**
1. Scans all samples in song
2. Identifies samples not used in any pattern
3. Exports each unused sample as .WAV
4. Creates .XRNI instrument containing all unused samples
5. Prompts for save location

**Use Case:**
- Backup samples before deleting
- Extract unused samples for library
- Archive experimental sounds

## Save Unused Instruments

**Keybinding:** `Global:Paketti:Save Unused Instruments (.XRNI)` ⌨️

Exports all unused instruments (not used in patterns) as .XRNI files.

**Process:**
1. Scans all instruments
2. Identifies instruments not used in any pattern/phrase
3. Exports each unused instrument as separate .XRNI
4. Batch export to selected folder

**Use Case:**
- Archive unused presets
- Clean up before project finalization
- Extract instruments for reuse

## Delete Unused Instruments

**Keybinding:** `Global:Paketti:Delete Unused Instruments` ⌨️

Removes all unused instruments from song (destructive operation).

**Warning:** Cannot be undone - instruments are permanently deleted

**Safety:**
- Only deletes instruments with zero pattern/phrase usage
- Preserves all instruments referenced in song
- Shows confirmation with count

**Use Case:**
- Reduce song file size
- Clean up after experimentation
- Optimize project

## Delete Unused Samples

**Keybindings:**
- `Global:Paketti:Delete Unused Samples` ⌨️
- `Sample Keyzones:Paketti:Delete Unused Samples` ⌨️

Removes all unused samples from instruments (destructive operation).

**Process:**
1. Scans all samples in all instruments
2. Checks pattern/phrase usage
3. Deletes samples with zero references
4. Preserves used samples

**Warning:** Cannot be undone - samples are permanently deleted

**Use Case:**
- Remove placeholder samples
- Clean up after slicing experiments
- Reduce memory usage

## Remove Empty Tracks

**Keybinding:** `Global:Paketti:Remove Empty Tracks` ⌨️

Deletes all tracks that contain no pattern data.

**Criteria for "Empty":**
- No notes in any pattern
- No effect commands in any pattern
- Track may have devices (preserved in other tracks)

**Process:**
1. Scans all patterns
2. Identifies tracks with zero data
3. Removes empty tracks
4. Preserves track order

**Use Case:**
- Clean up after arrangement
- Remove experimental tracks
- Prepare for mixing

## Remove Empty Tracks (No Notes, No DSP)

**Keybinding:** `Global:Paketti:Remove Empty Tracks (No Notes, No DSP)` ⌨️

Stricter cleanup - deletes tracks with no notes AND no DSP devices.

**Criteria:**
- No pattern data
- No DSP devices
- Completely empty/default track

**Use Case:**
- Maximum cleanup
- Reset project to minimal tracks
- Prepare template

---

# Metric Modulation

**Source:** `PakettiMetricModulation.lua` | **Features:** 9

Advanced tempo/subdivision calculator for metric modulation, triplet conversion, and polyrhythmic pattern manipulation.

## Metric Modulation Calculator

**Keybinding:** `Global:Paketti:Metric Modulation Calculator` ⌨️

Comprehensive calculator for tempo changes and rhythmic relationships.

**Dialog Features:**

### Current Song State
- **Current BPM** - Display only
- **Current LPB** - Lines per beat
- **Pattern Length** - Current pattern length

### Metric Modulation Calculator
**Input:**
- **Old Note Value** - Dropdown (whole, half, quarter, 8th, 16th, 32nd)
- **New Note Value** - Dropdown (whole, half, quarter, 8th, 16th, 32nd)
- **Relationship** - "Old becomes New"

**Calculate:**
- Shows new BPM to maintain timing relationship
- Example: "Quarter note becomes triplet" 
- Result: New BPM for triplet feel

### Common Ratios
Pre-configured metric modulation ratios:
- **3:2** - Triplet feel (hemiola)
- **4:3** - Four against three
- **5:4** - Quintuplet to sixteenth
- **3:4** - Inverse ratio

**Apply:** Sets song BPM to calculated value

## Convert to Triplet Feel

**Keybinding:** `Pattern Editor:Paketti:Convert to Triplet Feel` ⌨️

**MIDI:** `Paketti:Metric Modulation 3of2 (Triplet)` 🎹

Converts current pattern from straight to triplet feel.

**Process:**
1. Changes LPB to accommodate triplets
2. Redistributes note timing
3. Adjusts BPM to maintain tempo feel
4. Creates 3-against-2 polyrhythm

**Ratio:** 3:2 (three notes in space of two)

**Use Case:**
- Add swing to straight patterns
- Create triplet-based grooves
- Jazz/blues feel conversion

## Convert from Triplet Feel

**Keybinding:** `Pattern Editor:Paketti:Convert from Triplet Feel` ⌨️

**MIDI:** `Paketti:Metric Modulation 2of3 (From Triplet)` 🎹

Converts triplet pattern back to straight feel.

**Process:**
1. Reverse of triplet conversion
2. Redistributes to even timing
3. Adjusts BPM/LPB accordingly

**Ratio:** 2:3 (two notes in space of three)

## Convert 4to3 Feel

**Keybinding:** `Pattern Editor:Paketti:Convert 4to3 Feel` ⌨️

**MIDI:** `Paketti:Metric Modulation 4of3 (4/4→3/4)` 🎹

Converts 4/4 pattern to 3/4 time feel (or vice versa).

**Process:**
1. Recalculates timing for different meter
2. Adjusts pattern length/BPM
3. Creates polymetric effect

**Ratio:** 4:3

**Use Case:**
- Time signature changes
- Polymetric composition
- Progressive timing

## Advanced Subdivision Calculator

**Keybinding:** `Global:Paketti:Advanced Subdivision Calculator` ⌨️

Comprehensive subdivision calculator with visual timeline.

**Features:**

### Subdivision Options
- Whole notes
- Half notes
- Quarter notes
- 8th notes
- 16th notes
- 32nd notes
- Triplets (all divisions)
- Quintuplets
- Septuplets
- Custom ratios

### Visual Timeline
- Graphical representation of subdivisions
- Shows note placement
- Timing visualization
- Polyrhythm display

### Calculations
- Frame count per division
- Exact timing in milliseconds
- LPB recommendations
- Pattern length suggestions

### Use Cases

**Metric Modulation:**
```
Current: 120 BPM, 4/4
Want: Quarter becomes dotted 8th
Calculator: New BPM = 180
Result: Maintains quarter note duration
```

**Triplet Conversion:**
```
Current: Straight 16ths at 140 BPM
Convert: To triplet feel
Result: Adjust to accommodate triplets
Feel: Swung/shuffled groove
```

**Polyrhythm Setup:**
```
Track 1: 3 over 4
Track 2: 5 over 4
Calculator: Shows LPB/BPM for alignment
Result: Clean polyrhythmic pattern
```

**Time Signature Change:**
```
Current: 4/4 at 100 BPM
Change: To 3/4
Calculator: Maintains feel, adjusts timing
Result: Smooth transition
```

## Real-time Metric Ratio (MIDI Knob)

**MIDI:** `Paketti:Real-time Metric Ratio x[Knob]` 🎹

MIDI knob control for live metric modulation ratio selection.

**Knob Mapping (0-127):**
- 0-15: 3:4 ratio
- 16-31: 4:5 ratio
- 32-47: 5:6 ratio
- 48-63: 4:3 ratio
- 64-79: 3:2 ratio
- 80-95: 5:4 ratio
- 96-111: 6:5 ratio
- 112-127: 2:1 ratio

**Use Case:** Live performance metric modulation, hardware controller integration

---

# Sandbox (Experimental Features)

**Source:** `PakettiSandbox.lua` | **Features:** 10

Experimental features including APC40 controller integration, pattern sectionizer, and wacky filters.

## APC40 Pad Control

### Light Up All Pads

**MIDI:** `Paketti:APC Light Up All Pads` 🎹

Sends note-on to all APC40 pads (lights up).

### Turn Off All Pads

**MIDI:** `Paketti:APC Turn Off All Pads` 🎹

Sends note-off to all APC40 pads (lights off).

### Toggle Pads 1-4

**MIDI:** `Paketti:APC Toggle Pads 1-4` 🎹

Toggles first 4 pads (clips 1-4) on/off.

### Toggle Pads 5-8

**MIDI:** `Paketti:APC Toggle Pads 5-8` 🎹

Toggles pads 5-8 (clips 5-8) on/off.

### Toggle ALL 8 Pads

**MIDI:** `Paketti:APC Toggle ALL 8 Pads` 🎹

Toggles all 8 pads simultaneously.

### Test First 4 Pads

**MIDI:**
- `Paketti:APC Test First 4 Pads ON` 🎹
- `Paketti:APC Test First 4 Pads OFF` 🎹

Test functions for first 4 pads (troubleshooting).

**Note:** Requires Akai APC40 or compatible controller

**Use Case:** 
- Control APC40 LED feedback
- Visual performance cues
- Hardware integration testing

## Sectionizer

**Keybinding:** `Global:Paketti:Sectionizer...` ⌨️

Visual dialog for organizing patterns into named sections.

**Features:**
- **Section Naming** - Label groups of patterns
- **Color Coding** - Visual organization
- **Section Browser** - Navigate sections quickly
- **Auto-arrangement** - Generate section-based arrangements

**Use Case:**
- Song structure organization (Intro, Verse, Chorus, Bridge, Outro)
- Pattern library organization
- Arrangement workflow

## Clear All Pattern Names

**Keybinding:** `Global:Paketti:Clear all Pattern Names` ⌨️

Removes names from all patterns in song.

**Process:**
1. Scans all patterns
2. Sets pattern names to empty string
3. Preserves pattern data

**Use Case:**
- Reset pattern naming
- Clean slate for new naming scheme
- Template preparation

## Wacky Filter

**Menu:** `Main Menu:Tools:Paketti:Xperimental/WIP:Wacky Filter` 📋

Experimental filter with unconventional/chaotic behavior.

**Features:**
- Non-standard filter algorithms
- Unpredictable modulation
- Experimental sound design
- "Happy accidents" generator

**Warning:** Experimental - results may vary wildly!

**Use Case:** Experimental sound design, glitch effects, chaos generation

---

# Device Parameter Control (Parama Param)

**Source:** `PakettiDeviceValues.lua` | **Features:** 6

Keyboard shortcuts for navigating and controlling DSP device parameters without mouse.

## Parameter Navigation

### Next Parameter

**Keybinding:** `Mixer:Device:Parama Param Next Parameter` ⌨️

Moves to next parameter in selected device.

### Previous Parameter

**Keybinding:** `Mixer:Device:Parama Param Previous Parameter` ⌨️

Moves to previous parameter in selected device.

**Workflow:**
1. Select device in DSP chain
2. Press Next/Previous
3. Parameter focus moves
4. Ready for adjustment

## Parameter Adjustment

### Increase Parameter

**Keybinding:** `Mixer:Device:Parama Param Increase` ⌨️

Increases current parameter value.

**Step size:** Default increment (fine control)

### Decrease Parameter

**Keybinding:** `Mixer:Device:Parama Param Decrease` ⌨️

Decreases current parameter value.

**Step size:** Default decrement (fine control)

## Device Slot Selection (1-8)

**Keybindings:** 16 keybindings:
- `Mixer:Device:Select Device Slot 1` ⌨️
- `Mixer:Device:Select Device Slot 2` ⌨️
- ...through Slot 8

Direct keyboard selection of device slots in DSP chain.

**Use Case:**

**Mouse-Free Mixing:**
```
1. Press "Select Device Slot 3" (jump to 3rd device)
2. Press "Next Parameter" (move to parameter)
3. Press "Increase/Decrease" (adjust value)
4. Result: No mouse needed!
```

**Live Performance:**
```
1. Map to MIDI controller
2. Hardware control over device selection
3. Parameter navigation via buttons
4. Value control via knobs
```

**Fast Workflow:**
```
1. Slot 1 = Compressor (select, tweak threshold)
2. Slot 2 = EQ (select, adjust frequency)
3. Slot 3 = Reverb (select, change wet/dry)
4. All via keyboard - no mouse clicks
```

---

# Canvas Parameter Editor

**Source:** `PakettiCanvasExperiments.lua` | **Features:** 10+

Visual canvas-based device parameter editor with Edit A/B comparison, crossfade morphing, automation sync, and real-time parameter visualization.

## Main Features

**Keybinding:** `Global:Paketti:Canvas Parameter Editor...` ⌨️

**Menu Entry:** `Main Menu:Tools:Paketti..:Canvas Parameter Editor...` 📋

Opens a visual editor displaying all parameters of the selected device as vertical bars on a canvas.

### Visual Parameter Display

**Canvas Layout:**
- Each device parameter shown as vertical bar
- Bar height represents current value (0-100%)
- Parameter names displayed below bars
- CC parameter names cleaned (removes "CC XX " prefix)
- Real-time updates as parameters change

**Interaction:**
- Click and drag on bars to adjust values
- Visual feedback during adjustment
- Status text shows current parameter being edited
- Mouse position tracked for precise control

### Edit A/B System

Inspired by hardware synthesizers, allows comparison between two parameter states:

**Edit A Button:**
- Stores current parameter values in "A" memory
- Purple bar overlay shows Edit A values

**Edit B Button:**
- Stores current parameter values in "B" memory
- Yellow bar overlay shows Edit B values

**Crossfade Slider:**
- Morphs between Edit A and Edit B values
- 0% = full Edit A
- 100% = full Edit B
- Real-time interpolation between states
- Green outline shows crossfade position

### Automation Sync

**Follow Automation Toggle:**
- When enabled, canvas reads automation envelope values
- Displays current automation state at playhead position
- Auto-updates as playback progresses

**Auto-Show Automation:**
- Automatically switches to automation view when sync enabled

**Auto-Show Mixer Params:**
- Shows exposed mixer parameters when automation sync enabled

### Navigation Controls

**Track Navigation:**
- Previous/Next Track buttons
- Wraps at beginning/end of track list

**Device Navigation:**
- Previous/Next Device buttons
- Wraps within track's device chain

### Randomization

**Randomize Button:**
- Applies random values to all parameters
- Strength slider controls intensity (0-100%)
- Hidden in "Randomize" text label

### Parameter Name Cleaning

**Clean CC Names Toggle:**
- Removes "CC XX " prefix from parameter names
- Removes surrounding parentheses
- "CC 54 (Cutoff)" becomes "Cutoff"

### Use Cases

**Sound Design:**
- Visual overview of all device parameters
- Quick comparison between A/B settings
- Crossfade morphing for transitions

**Live Performance:**
- Real-time parameter visualization
- A/B switching for song sections
- Crossfade for smooth transitions

**Mixing:**
- See all plugin parameters at once
- Compare different mix settings
- Gradual parameter morphing

---

# Mixer Parameter Exposer

**Source:** `PakettiMixerParameterExposer.lua` | **Features:** 6

Dialog for viewing and toggling `show_in_mixer` property for all device parameters on the selected track, with humanize and MIDI control features.

## Main Dialog

**Keybinding:** `Global:Paketti:Mixer Parameter Exposer...` ⌨️

Opens dialog showing all devices and parameters on current track with checkbox toggles for mixer visibility.

### Parameter Visibility Control

**Display:**
- One column per device on track
- Checkboxes for each parameter
- Parameter names listed with device context
- Checked = visible in mixer, Unchecked = hidden

**Bulk Operations:**
- **Show All:** Makes all parameters visible in mixer
- **Hide All:** Hides all parameters from mixer
- **Make Automated Visible:** Shows only parameters with automation

### Humanize Feature

**Humanize Button:**
- Applies random variation to all exposed parameters
- Percentage slider controls intensity (0-100%)
- If parameter has automation: humanizes envelope points
- If no automation: humanizes current parameter value

**Algorithm:**
- Random deviation within percentage of parameter range
- Bipolar variation (positive and negative)
- Respects parameter min/max bounds

### Bipolar Offset Control

**Offset Slider:**
- Center position (0) = no change
- Positive values = increase all exposed parameters
- Negative values = decrease all exposed parameters
- Relative offset based on parameter range
- Spring-back to center on release

**Original Values:**
- Values stored when interaction begins
- Offset applied relative to stored values
- Allows experimentation without losing original

### MIDI Control

**MIDI Mapping:** `Paketti:Mixer Parameter Exposer Control [Knob]` 🎹

- Absolute MIDI CC control (0-127)
- 64 = center position (store values)
- 0-63 = negative offset
- 65-127 = positive offset

### Track Following

**Auto-Rebuild:**
- Dialog automatically rebuilds when track changes
- Shows devices and parameters for new track
- Maintains open state across track changes

### Use Cases

**Mixing Workflow:**
- Quickly expose key parameters to mixer
- Hide unneeded parameters for cleaner view
- Bulk show/hide for different mix stages

**Live Performance:**
- Control exposed parameters via MIDI
- Humanize for organic variation
- Offset for global parameter sweeps

**Automation Setup:**
- Make automated parameters visible
- Visual overview of what's automated
- Quick toggle for automation display

---

# Execute Applications

**Source:** `PakettiExecute.lua` | **Features:** 11

Launch external applications directly from Renoise with 10 configurable quick-launch slots.

## Execute Applications Dialog

**Keybinding:** `Global:Paketti:Show Execute Applications Dialog` ⌨️

Opens application launcher configuration dialog.

**Dialog Features:**

### Application Slots (1-10)
For each slot:
- **Application Path** - Browse to executable
- **Arguments** - Optional command-line arguments
- **Working Directory** - Optional working directory
- **Test Button** - Test launch before saving

**Configuration:**
1. Click "Browse" for slot
2. Select application executable
3. Optional: Add arguments (e.g., `--fullscreen`)
4. Optional: Set working directory
5. Save configuration
6. Now accessible via keybinding

### Examples
**Slot 1:** Audacity
- Path: `/Applications/Audacity.app`
- Use: Quick audio editing

**Slot 2:** Terminal
- Path: `/Applications/Utilities/Terminal.app`
- Args: `--working-directory=/Users/me/samples`
- Use: Quick shell access to samples folder

**Slot 3:** Text Editor
- Path: `/Applications/Sublime Text.app`
- Args: `~/Documents/song-notes.txt`
- Use: Open song notes

## Execute Application Slot (01-10)

**Keybindings:** 10 keybindings:
- `Global:Paketti:Execute Application Slot 01` ⌨️
- `Global:Paketti:Execute Application Slot 02` ⌨️
- ...through Slot 10

Launches pre-configured application from slot (1-10).

**Workflow:**
1. Configure slots in dialog
2. Close dialog
3. Press slot keybinding anytime
4. Application launches

**Use Cases:**
- Open sample editor (Audacity/RX)
- Launch visual feedback (oscilloscope app)
- Open reference player (VLC with reference track)
- Launch documentation browser
- Open project folder in Finder/Explorer
- Quick access to utilities

---

# Sample Loop MIDI Control

**Source:** `PakettiHexSliceLoop.lua` | **Features:** 1

Real-time MIDI knob control for sample loop length across all samples in selected instrument.

## Sample Loop Control (MIDI Knob)

**MIDI:** `Paketti:Sample Loop Control (CC 0-127 to 0-100%) x[Knob]` 🎹

Maps MIDI CC knob (0-127) to sample loop length (0-100% of sample).

**Behavior:**
- **0:** Loop disabled or minimum loop
- **64:** Loop at 50% of sample length
- **127:** Loop at 100% of sample length

**Applies to:** All samples in currently selected instrument

**Process:**
1. Turn MIDI knob
2. All samples' loop points adjust proportionally
3. Real-time loop length modulation
4. Visual feedback in sample editor

**Use Cases:**

**Live Looping:**
```
1. Load drum loop
2. Assign MIDI knob to loop control
3. Turn knob to shorten loop
4. Create stuttering/glitch effects
```

**Rhythmic Gating:**
```
1. Long sustained sound
2. Short loop = rhythmic pulse
3. Long loop = smooth sustain
4. Modulate in real-time
```

**Performance Tool:**
```
1. Hardware controller integration
2. Live loop manipulation
3. Dynamic texture control
4. Performance FX
```

---

# OctaMED Hold-to-Fill Mode

**Source:** `PakettiHoldToFill.lua` | **Features:** 1

OctaMED-style "hold key to fill notes" workflow - hold keyboard key and notes fill automatically at edit step.

## Toggle Hold-to-Fill Mode

**Keybinding:** `Global:Paketti:Toggle OctaMED Hold-to-Fill Mode` ⌨️

Opens dialog and enables/disables OctaMED-style hold-to-fill note entry.

**Dialog Features:**

### Hold-to-Fill Settings
- **Enable Hold-to-Fill** - Toggle mode on/off
- **Use Edit Step** - Fill at edit step intervals vs every line
- **Don't Clear Column** - Preserve existing notes when filling
- **Enable MIDI** - Use MIDI keyboard instead of QWERTY
- **MIDI Device** - Select MIDI input device

### Keyboard Layout
Same as PakettiCaptureLastTake:
- **Q-row:** C-4 through B-4 (plus sharps on number row)
- **A-row:** (not used for notes)
- **Z-row:** C-3 through B-3 (octave below)

**How It Works:**

**Keyboard Mode:**
1. Enable Hold-to-Fill Mode
2. Position cursor in pattern
3. Press and HOLD keyboard note key (Q, W, E, etc.)
4. While held: Notes fill automatically
5. Release: Stops filling

**MIDI Mode:**
1. Enable Hold-to-Fill Mode
2. Enable MIDI checkbox
3. Select MIDI device
4. Press and HOLD MIDI key
5. While held: Notes + velocity fill automatically
6. Release: Stops filling

**Fill Behavior:**

**With Edit Step:**
- Fills every N lines (edit step value)
- Example: Edit step 4 = note every 4 lines
- Creates rhythmic patterns

**Without Edit Step:**
- Fills every line
- Creates solid note stream
- Hold for duration, release to stop

**Don't Clear Column:**
- Preserves existing notes
- Fills only empty lines
- Non-destructive layering

### Use Cases

**Quick Note Entry:**
```
1. Want 16 consecutive C-4 notes
2. Enable Hold-to-Fill
3. Hold 'Q' key
4. 16 notes appear instantly
5. Release
```

**Rhythmic Patterns:**
```
1. Edit Step: 4
2. Hold-to-Fill enabled
3. Hold 'Q' → every 4th line gets C-4
4. Switch to 'E' → every 4th line gets E-4
5. Create rhythm by switching notes
```

**MIDI + Velocity:**
```
1. Enable MIDI mode
2. Hold MIDI key softly (low velocity)
3. Notes fill with low velocity values
4. Hit harder = higher velocities
5. Dynamic pattern creation
```

**OctaMED Workflow:**
```
1. Classic OctaMED tracker style
2. Hold = fill, release = stop
3. Fast pattern entry
4. No repeated key presses
```

**Drum Programming:**
```
1. Edit Step: 4 (quarter notes)
2. Hold 'Q' → kick every quarter note
3. Switch column
4. Hold 'E' → snare on 2 and 4
5. Quick drum pattern
```

---

# New Sample Auto-Settings

**Source:** `PakettiAutoSamplify.lua` | **Features:** 1

Automatically applies preset settings to newly loaded/recorded samples.

## Toggle New Sample Auto-Settings

**Keybinding:** `Global:Paketti:Toggle New Sample Auto-Settings` ⌨️

Enables/disables automatic sample processing for newly loaded samples.

**When Enabled:**
Automatically applies to every new sample:
- **Loop Mode** - Forward/backward/ping-pong
- **Interpolation** - None/Linear/Cubic/Sinc
- **Transpose** - Semitone offset
- **Finetune** - Cent adjustment
- **Volume** - Initial volume
- **Panning** - Pan position
- **Beatsync** - Enable/disable beatsync
- **Beatsync Lines** - Line count for sync
- **NNA (New Note Action)** - Cut/Continue/Note-off/Fade-out
- **Oneshot** - Enable one-shot mode

**Configuration:**
Set in Paketti Preferences → AutoSamplify section

**Use Cases:**

**Consistent Sample Setup:**
```
1. Configure: Loop=Forward, Interpolation=Cubic
2. Enable Auto-Settings
3. Every loaded sample gets same settings
4. Consistent workflow
```

**Template-Based Loading:**
```
1. Set NNA=Cut, Oneshot=Enabled
2. Perfect for drum hits
3. All drums auto-configured
4. No manual tweaking
```

**Quick Beatsync:**
```
1. Set Beatsync=Enabled, Lines=16
2. Load breakbeats
3. Auto-beatsync applied
4. Ready for tempo manipulation
```

**Disable for Special Cases:**
```
1. Toggle Off for one-time loads
2. Load special sample without auto-settings
3. Toggle back On
4. Resume automatic processing
```

---


---

# Instrument Transpose System

**Source:** `PakettiInstrumentTranspose.lua` | **Features:** 15

Comprehensive instrument transpose control with MIDI knobs, relative/absolute transpose, and quick octave shifts (-120 to +120 semitones).

## Relative Transpose (-1 to +1 Semitone)

**MIDI:** `Paketti:MIDI Instrument Transpose ±1 Semitone x[Knob]` 🎹

Real-time MIDI knob for incrementing/decrementing selected instrument transpose by 1 semitone.

**Behavior:**
- CC > 64: Transpose up by 1 semitone
- CC < 64: Transpose down by 1 semitone
- Range: -120 to +120 semitones (clamped)

## Absolute Transpose by Octave (-5 to +5)

**Keybindings:** 11 keybindings:
- `Global:Paketti:Set Instrument Transpose to -5 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to -4 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to -3 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to -2 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to -1 Octave` ⌨️
- `Global:Paketti:Set Instrument Transpose to 0 (Reset)` ⌨️
- `Global:Paketti:Set Instrument Transpose to +1 Octave` ⌨️
- `Global:Paketti:Set Instrument Transpose to +2 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to +3 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to +4 Octaves` ⌨️
- `Global:Paketti:Set Instrument Transpose to +5 Octaves` ⌨️

**Menu:** All available in `Instrument Box:Paketti:Transpose:Set to [Octave]` 📋

**MIDI:** All 11 available as MIDI mappings 🎹

Sets instrument to exact octave transpose value (absolute).

**Values:** -60, -48, -36, -24, -12, 0, +12, +24, +36, +48, +60 semitones

## Relative Transpose by Octave (±1, ±2)

**Keybindings:**
- `Global:Paketti:Transpose Instrument +1 Octave (Relative)` ⌨️
- `Global:Paketti:Transpose Instrument -1 Octave (Relative)` ⌨️
- `Global:Paketti:Transpose Instrument +2 Octaves (Relative)` ⌨️
- `Global:Paketti:Transpose Instrument -2 Octaves (Relative)` ⌨️

**Menu:** All available in `Instrument Box:Paketti:Transpose:Relative [±Octave]` 📋

**MIDI:** All 4 available as MIDI mappings 🎹

Adds/subtracts octaves from current transpose (relative).

**Example:**
```
Current: -12 semitones
Press: +2 Octaves (Relative)
Result: +12 semitones (added 24)
```

## MIDI Knob Transpose Controls

### Absolute Transpose (-120 to +120)

**MIDI:** `Paketti:MIDI Set Instrument Transpose -120 to +120 x[Knob]` 🎹

Maps MIDI knob (0-127) to full transpose range (-120 to +120 semitones).

**Knob Mapping:**
- 0: -120 semitones (-10 octaves)
- 64: 0 semitones (neutral)
- 127: +120 semitones (+10 octaves)

### Relative Transpose (-12 to +12)

**MIDI:** `Paketti:MIDI Relative Instrument Transpose ±12 x[Knob]` 🎹

Maps MIDI knob to relative transpose within ±1 octave.

**Knob Mapping:**
- 0: -12 semitones
- 64: 0 (no change)
- 127: +12 semitones

**Use Case:** Fine-tuning with encoder-style controllers

## Use Cases

**Quick Octave Shifting:**
```
1. Load bass instrument
2. Press "Transpose +1 Octave"
3. Now plays an octave higher
4. Fast retuning
```

**Hardware Control:**
```
1. Map MIDI knob to absolute transpose
2. Turn knob left = lower pitch
3. Turn knob right = higher pitch
4. Real-time instrument pitch control
```

**Relative Adjustments:**
```
1. Instrument at -6 semitones
2. Press "+1 Octave (Relative)"
3. Now at +6 semitones
4. Preserves fine-tuning
```

---

# MIDI Mapping Utilities

**Source:** `PakettiMIDIMappings.lua` | **Features:** 14

Advanced MIDI mapping analysis, verification, and debugging tools for Paketti development.

## Verify Paketti MIDI Mappings

**Keybinding:** `Global:Paketti:Verify Paketti MIDI Mappings` ⌨️

Scans all Paketti Lua files and verifies MIDI mapping declarations.

**Verification:**
- Checks for duplicate mapping names
- Identifies syntax errors
- Verifies invoke functions exist
- Reports missing mappings

**Output:** Console log with verification results

## Paketti MIDI Mappings (Dynamic)

**Keybinding:** `Global:Paketti:Paketti MIDI Mappings (Dynamic)...` ⌨️

Opens dialog showing all Paketti MIDI mappings dynamically extracted from code.

**Dialog Features:**
- **Mapping List** - All MIDI mappings with names
- **Filter** - Search by name
- **Category** - Group by function type
- **Test** - Trigger mapping from dialog

## Print Active MIDI Mappings to Console

**Keybinding:** `Global:Paketti:Print Active MIDI Mappings to Console` ⌨️

Outputs all currently active MIDI mappings to console.

**Output Format:**
```
MIDI Mapping: [Name]
  Function: [invoke function]
  Category: [Global/Track/Sample/etc]
  Status: Active
```

## Generate MIDI Mappings to Console

**Keybinding:** `Global:Paketti:Generate MIDI Mappings to Console` ⌨️

Generates skeleton MIDI mapping code for all Paketti functions.

**Use Case:** Development - create MIDI mappings for new features

## Extract MIDI Mappings to Console

**Keybinding:** `Global:Paketti:Extract MIDI Mappings to Console` ⌨️

Extracts all `add_midi_mapping` calls from Paketti source files.

**Output:** List of all MIDI mapping declarations with file locations

## Show MIDI Category Statistics

**Keybinding:** `Global:Paketti:Show MIDI Category Statistics` ⌨️

Displays statistics about MIDI mapping distribution.

**Statistics:**
- Total MIDI mappings
- Mappings per category (Global, Track, Sample, etc.)
- Mappings per file
- Most-used categories

## Test Dynamic MIDI Mapping Detection

**Keybinding:** `Global:Paketti:Test Dynamic MIDI Mapping Detection` ⌨️

Tests dynamic MIDI mapping detection system.

**Use Case:** Development/debugging - verify mapping detection works

## Refresh MIDI Mapping Table Cache

**Keybinding:** `Global:Paketti:Refresh MIDI Mapping Table Cache` ⌨️

Rebuilds MIDI mapping cache from source files.

**When to use:**
- After adding new MIDI mappings
- After editing mapping names
- If dialog shows stale data

---

# Control Mixer Shown Parameters (NEW - Dec 2025)

**Source:** `PakettiMidi.lua` | **Features:** 32

MIDI control for device parameters that are exposed in the mixer (show_in_mixer = true).

## Individual Parameter Control (01-16)

**MIDI Mappings:**
- `Paketti:Control Mixer Shown Parameter 01` through `16` 🎹 (Absolute)
- `Paketti:Control Mixer Shown Parameter 01 Relative` through `16 Relative` 🎹 (Relative)

Controls individual exposed parameters on the selected track.

**How It Works:**
1. Expose device parameters to mixer using show_in_mixer
2. Parameters are numbered 01-16 based on order exposed
3. Use MIDI CC to control each parameter directly
4. Works with absolute (0-127) or relative (increments) values

**Absolute Mode:**
- MIDI CC 0 = minimum parameter value
- MIDI CC 127 = maximum parameter value
- Linear mapping across full range

**Relative Mode:**
- Positive deltas increase value
- Negative deltas decrease value
- Respects parameter min/max bounds

## Use Cases

**Performance Control:**
- Expose key synth parameters to mixer
- Assign MIDI knobs to parameters 01-16
- Real-time control without mouse

**Mixing Workflow:**
- Expose volume/pan parameters
- Control multiple tracks via MIDI controller
- Hardware integration for mixing

**Automation Alternative:**
- Direct parameter control
- Bypasses automation system
- Immediate response

---

# Favorited Plugin Instruments (NEW - Dec 2025)

**Source:** `PakettiLoadPlugins.lua`

Load favorited plugin instruments with automatic External Editor display and *Instr. Automation device.

## Load Favorited Plugin Instruments

**Keybinding:** `Global:Paketti:Load Favorited Plugin Instruments (Paketti)` ⌨️

Loads all currently favorited plugin instruments into the song.

**Process:**
1. Reads currently favorited plugin instruments
2. Creates new instrument for each favorite
3. Opens External Editor for visual feedback
4. Adds *Instr. Automation device to track DSP chain
5. Renames *Instr. Automation to identify source instrument

**Device Setup:**
- *Instr. Automation device automatically linked to new instrument
- Ready for automation in pattern editor
- External Editor visible for parameter access

**Use Cases:**

**Quick Session Setup:**
- Mark favorite synths in Renoise preferences
- One shortcut loads all of them
- External Editors open automatically
- Ready to play and automate immediately

**Template Building:**
- Create instrument templates with favorites
- Consistent device chains per instrument
- Faster project startup

---

# Quick Load Device Dialog

**Source:** `PakettiLoadDevices.lua` | **Features:** 11+

Fast device loader with favorites, search, and one-click insertion of VST/AU/Native devices.

## Quick Load Device Dialog

**Keybinding:** `Global:Paketti:Quick Load Device Dialog...` ⌨️

**MIDI:** `Paketti:Quick Load Device Dialog... [Trigger]` 🎹

Opens fast device selection dialog with search and categories.

**Dialog Features:**

### Device Categories
- **Native Effects** - All Renoise native DSP
- **VST/VST3** - VST plugins
- **Audio Units** - AU plugins (macOS)
- **All Devices** - Combined list

### Search
- Real-time filter
- Search by name
- Fuzzy matching
- Instant results

### Favorites
- Star/favorite frequently used devices
- Quick access section
- Persistent across sessions

### Actions
- **Double-click** - Load device immediately
- **Enter** - Load selected device
- **Esc** - Close dialog

## Dynamic Device Slot Keybindings

**Features:** Dynamic keybinding generation for all devices

**Auto-generated for each device:**
- Keybinding: `Global:Paketti:Load [DeviceName]`
- MIDI mapping: `Paketti:Load [DeviceName] [Trigger]`

**All Native Devices Available:**

**EQ & Filtering:**
- `Global:Paketti:Load EQ 5` ⌨️
- `Global:Paketti:Load EQ 10` ⌨️
- `Global:Paketti:Load Mixer EQ` ⌨️
- `Global:Paketti:Load Filter` ⌨️
- `Global:Paketti:Load Filter 2` ⌨️
- `Global:Paketti:Load Filter 3` ⌨️

**Dynamics:**
- `Global:Paketti:Load Compressor` ⌨️
- `Global:Paketti:Load Gate` ⌨️
- `Global:Paketti:Load Maximizer` ⌨️
- `Global:Paketti:Load Gainer` ⌨️
- `Global:Paketti:Load Bus Compressor` ⌨️

**Distortion & Saturation:**
- `Global:Paketti:Load Distortion` ⌨️
- `Global:Paketti:Load LofiMat` ⌨️
- `Global:Paketti:Load Shaper` ⌨️
- `Global:Paketti:Load Cabinet Simulator` ⌨️

**Stereo & Spatial:**
- `Global:Paketti:Load Stereo Expander` ⌨️

**Modulation:**
- `Global:Paketti:Load Chorus` ⌨️
- `Global:Paketti:Load Flanger` ⌨️
- `Global:Paketti:Load Phaser` ⌨️
- `Global:Paketti:Load Comb Filter` ⌨️
- `Global:Paketti:Load RingMod` ⌨️

**Time-Based:**
- `Global:Paketti:Load Delay` ⌨️
- `Global:Paketti:Load Reverb` ⌨️
- `Global:Paketti:Load mpReverb` ⌨️

**Modulation Sources:**
- `Global:Paketti:Load *LFO Device` ⌨️
- `Global:Paketti:Load *Key Tracking` ⌨️
- `Global:Paketti:Load *Velocity Tracking` ⌨️
- `Global:Paketti:Load *Hydra` ⌨️
- `Global:Paketti:Load *Signal Follower` ⌨️
- `Global:Paketti:Load *XY Pad` ⌨️

**Instrument Control:**
- `Global:Paketti:Load *Instr. MIDI Control` ⌨️
- `Global:Paketti:Load *Instr. Automation` ⌨️
- `Global:Paketti:Load *Instr. Macros` ⌨️

**Routing:**
- `Global:Paketti:Load Send` ⌨️
- `Global:Paketti:Load Multiband Send` ⌨️
- `Global:Paketti:Load Sidechain` ⌨️

**Meta Devices:**
- `Global:Paketti:Load Doofer` ⌨️
- `Global:Paketti:Load Meta Mixer` ⌨️

**Input:**
- `Global:Paketti:Load #Line Input` ⌨️
- `Global:Paketti:Load #Rewire Input` ⌨️

**Plus:** All VST/VST3/AU plugins installed on your system!

**Use Case:**
- Bind favorite devices to hardware
- Quick device insertion
- Live performance device loading

---

# Automation Stack

**Source:** `PakettiAutomationStack.lua` | **Features:** 11

Multi-parameter automation editor with visual envelope control and synchronized parameter editing.

## Automation Stack Dialog

**Keybinding:** `Pattern Editor:Paketti:Automation Stack...` ⌨️

**Menu:**
- `Main Menu:Tools:Automation Stack` 📋
- `Pattern Editor:Paketti:Automation:Automation Stack` 📋

Comprehensive automation editor for multiple parameters simultaneously.

**Dialog Features:**

### Parameter Selection
- **Track Parameters** - Volume, panning, width
- **Device Parameters** - All device parameters
- **Send Levels** - Send track amounts
- **Multi-select** - Edit multiple parameters at once

### Visual Envelope Editor
- **Waveform Display** - Visual automation curves
- **Point Editing** - Click to add/remove points
- **Drag Points** - Mouse manipulation
- **Curve Types** - Linear/Bezier/Stepped

### Synchronized Editing
- **Link Parameters** - Edit multiple params together
- **Offset Mode** - Maintain relative offsets
- **Scale Mode** - Proportional scaling
- **Mirror Mode** - Inverted relationships

### Presets
- **Save Automation Stack** - Store parameter groups
- **Load Automation Stack** - Recall saved groups
- **Automation Templates** - Pre-configured setups

### Pattern Range
- **Selection** - Edit selected pattern range
- **Entire Pattern** - Edit full pattern
- **Loop Range** - Edit loop section

## Automation Stack - Single View

**Keybinding:** `Pattern Editor:Paketti:Automation Stack - Single View...` ⌨️

**Menu:**
- `Main Menu:Tools:Automation Stack - Single View` 📋
- `Pattern Editor:Paketti:Automation:Automation Stack - Single View` 📋

Simplified single-parameter automation editor.

**Features:**
- Focus on one parameter
- Larger envelope view
- Detailed editing
- Pattern-wide control

## Automation Stack - Select Arbitrary Parameters

**Keybinding:** `Pattern Editor:Paketti:Automation Stack - Select Arbitrary Parameters...` ⌨️

**Menu:**
- `Main Menu:Tools:Automation Stack - Select Arbitrary Parameters` 📋
- `Pattern Editor:Paketti:Automation:Automation Stack - Select Arbitrary Parameters` 📋

Advanced parameter selection dialog.

**Features:**
- **Device Hierarchy** - Browse all tracks/devices
- **Parameter Tree** - Organized parameter structure
- **Custom Groups** - Create parameter sets
- **Save Groups** - Store custom selections

## Debug Print Points

**Menu:**
- `Main Menu:Tools:Automation Stack - Debug Print Points` 📋
- `Pattern Editor:Paketti:Automation:Debug Print Points` 📋

Prints all automation point data to console (debugging).

**Output:**
- Point positions (time, value)
- Curve types
- Pattern locations
- Parameter names

## Use Cases

**Complex Modulation:**
```
1. Open Automation Stack
2. Select Filter Cutoff + Resonance
3. Draw synchronized curves
4. Both parameters modulate together
5. Perfect filter sweeps
```

**Multi-Parameter Control:**
```
1. Select Volume + Panning + Send Level
2. Link in offset mode
3. Adjust volume
4. Pan and send follow proportionally
5. Balanced automation
```

**Automation Templates:**
```
1. Create riser automation (filter, volume, reverb)
2. Save as "Riser" preset
3. Load in other patterns
4. Instant build-ups
```

---


---

# HyperEdit (8-Row Step Sequencer)

**Source:** `PakettiHyperEdit.lua` | **Features:** 6

Visual 8-row step sequencer with per-row device and parameter selection for complex automation patterns.

## Paketti HyperEdit

**Keybinding:** `Global:Paketti:Paketti HyperEdit` ⌨️

**Menu:**
- `--Pattern Editor:Paketti Gadgets:Paketti HyperEdit` 📋 (separator above)
- `--Mixer:Paketti Gadgets:Paketti HyperEdit` 📋 (separator above)
- `--Pattern Matrix:Paketti Gadgets:Paketti HyperEdit` 📋 (separator above)
- `--Track Automation:Paketti Gadgets:Paketti HyperEdit` 📋 (separator above)

8-row interchangeable step sequencer with individual device/parameter selection per row.

**Dialog Features:**

### 8 Independent Rows
Each row includes:
- **Canvas Display** - Visual step sequencer (16-32-64 steps)
- **Device Selector** - Dropdown to choose device
- **Parameter Selector** - Dropdown for device parameter
- **Step Editor** - Click/drag to edit step values
- **Clear Button** - Reset row
- **Copy/Paste** - Duplicate patterns between rows

### Device Selection Priority
Automatically finds/creates optimal device:
1. **Instr. MIDI Control** (highest priority)
2. **Instr. Automation** (medium priority)
3. **Instr. Macros** (fallback)

### Parameter Options
- All device parameters available
- Clean parameter names (removes "CC XX" prefix)
- Whitelisted parameters for clarity
- Real-time parameter updates

### Pattern Writing
- **Write to Pattern** - Inserts automation
- **Pattern Range** - Selection or entire pattern
- **LPB-aware** - Respects lines per beat
- **Multi-row Write** - All 8 rows simultaneously

### Use Cases

**Complex Modulation:**
```
Row 1: Filter Cutoff (16 steps)
Row 2: Filter Resonance (16 steps)
Row 3: LFO Rate (32 steps)
Row 4: LFO Amount (32 steps)
Row 5: Volume (16 steps)
Row 6: Panning (16 steps)
Row 7: Reverb Send (32 steps)
Row 8: Delay Send (32 steps)
→ Write to Pattern → 8-parameter modulation
```

**Polyrhythmic Automation:**
```
Row 1: Cutoff @ 16 steps (1 bar)
Row 2: Resonance @ 12 steps (3/4 bar)
Row 3: Volume @ 20 steps (5/4 bar)
→ Creates polyrhythmic modulation
```

**Drum Processing:**
```
Row 1: Kick EQ (4 steps - 4 kicks)
Row 2: Snare Reverb (8 steps)
Row 3: Hihat Filter (16 steps)
Row 4: Overall Compression (2 steps)
→ Per-hit processing automation
```

## HyperEdit Duplicate to Next Pattern

**Keybinding:** `Global:Paketti:HyperEdit Duplicate to Next Pattern` ⌨️

Duplicates current HyperEdit automation setup to next pattern.

**Process:**
1. Reads current pattern's 8-row setup
2. Copies automation to next pattern
3. Preserves device/parameter assignments
4. Creates continuous automation flow

**Use Case:** Build evolving automation across multiple patterns

---

# Keyzone Distributor

**Source:** `PakettiKeyzoneDistributor.lua` | **Features:** 4

Automatically maps samples to keyboard zones with visual distribution and filename-based mapping.

## Keyzone Distributor Dialog

**Keybinding:** `Global:Paketti:Show Keyzone Distributor Dialog...` ⌨️

**MIDI:** `Paketti:Show Keyzone Distributor Dialog...` 🎹

Visual dialog for distributing samples across keyboard with automatic or manual zone assignment.

**Dialog Features:**

### Distribution Modes
- **Chromatic** - One sample per semitone
- **Octave** - One sample per octave
- **White Keys Only** - Skip black keys
- **Custom Intervals** - User-defined spacing
- **Even Distribution** - Spread evenly across range

### Keyboard Range
- **Start Note** - First key for mapping (C-0 to G-9)
- **End Note** - Last key for mapping
- **Root Note** - Reference pitch for samples
- **Overlap** - Allow zone overlap for crossfading

### Sample Order
- **Original Order** - As loaded
- **Alphabetical** - Sort by name
- **Reverse** - Backwards mapping
- **Random** - Shuffle samples
- **By Pitch** - Analyze and sort by detected pitch

### Zone Settings
- **Base Note** - Center note for each zone
- **Key Tracking** - Enable/disable pitch tracking
- **Zone Width** - How many keys per sample
- **Crossfade** - Overlap amount for smooth transitions

### Visual Preview
- **Keyboard Display** - Shows zone assignments
- **Sample Names** - Which sample on which keys
- **Zone Boundaries** - Visual markers
- **Color Coding** - Per-zone colors

**Process:**
1. Load samples into instrument
2. Open Keyzone Distributor
3. Select distribution mode
4. Set keyboard range
5. Adjust settings
6. Click "Apply"
7. Samples mapped instantly

**Use Cases:**

**Drum Kit Mapping:**
```
1. Load 16 drum hits
2. Chromatic distribution
3. Start: C-4, End: D#-5
4. Result: Each drum on consecutive key
```

**Multi-Octave Instrument:**
```
1. Load 7 samples (one per octave)
2. Octave distribution
3. Root: C-4
4. Result: Same sample every octave
```

**Velocity Layers:**
```
1. Load 3 samples (soft, med, loud)
2. Even distribution
3. Overlap enabled
4. Crossfade: 2 semitones
5. Result: Smooth velocity transitions
```

## Filename-Based Keyzone Mapping

**Keybinding:** `Global:Paketti:Show Filename-Based Keyzone Mapping...` ⌨️

**MIDI:** `Paketti:Show Filename-Based Keyzone Mapping...` 🎹

Intelligent keyzone mapping based on sample filenames.

**Filename Parsing:**

Supports multiple naming conventions:
- **Note Names:** `Kick_C2.wav`, `Snare_D#3.wav`
- **MIDI Numbers:** `Sample_060.wav` (Middle C)
- **Octave Numbers:** `Bass_C4.wav`, `Lead_A5.wav`
- **Interval Names:** `Root.wav`, `Fifth.wav`, `Octave.wav`

**Process:**
1. Scans all sample filenames
2. Detects note information
3. Automatically assigns zones
4. Preserves original tuning
5. No manual mapping needed

**Supported Formats:**
```
kick_c1.wav     → Maps to C-1
snare-d2.wav    → Maps to D-2
HiHat_F#3.wav   → Maps to F#-3
Cymbal(A4).wav  → Maps to A-4
Bass_036.wav    → Maps to MIDI note 36 (C-2)
Lead [C5].wav   → Maps to C-5
```

**Auto-Detection:**
- Note name (C, D, E, F, G, A, B)
- Accidentals (#, b, sharp, flat)
- Octave number (0-9)
- MIDI note number (0-127)

**Fallback:**
- Samples without note info → unmapped
- Can manually assign after import
- Shows warning for unparseable names

**Use Cases:**

**Sample Library Import:**
```
1. Load folder of named samples
2. Filename-based mapping
3. Automatic keyboard layout
4. Ready to play immediately
```

**Drum Kit Auto-Map:**
```
Files:
  Kick_C1.wav → C-1
  Snare_D1.wav → D-1
  HiHat_F#1.wav → F#-1
Result: Instant drum mapping
```

---

# Manual Slicer (Power of 2 Padding)

**Source:** `PakettiManualSlicer.lua` | **Features:** 2

Fits sample slices to longest slice with power-of-2 padding for hardware sampler compatibility.

## Fit Slices to Longest Slice with Power of 2 Padding

**Keybinding:** `Sample Editor:Paketti:Fit Slices to Longest Slice with Power of 2 Padding` ⌨️

**Menu:** `Sample Editor:Paketti..:Manual Slicer:Fit Slices to Longest Slice with Power of 2 Padding` 📋

Extends all slices to match longest slice length, padded to power-of-2 for hardware sampler compatibility.

**Process:**
1. Analyzes all slice markers
2. Finds longest slice
3. Rounds up to next power of 2 (256, 512, 1024, 2048, etc.)
4. Extends all shorter slices to that length
5. Pads with silence

**Why Power of 2?**
- Hardware samplers often require power-of-2 lengths
- Ensures compatibility with:
  - Akai MPC series
  - Elektron Octatrack/Digitakt
  - Roland SP series
  - Vintage samplers

**Power of 2 Values:**
- 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 samples

**Example:**
```
Before:
  Slice 1: 1200 samples
  Slice 2: 800 samples  
  Slice 3: 1500 samples (longest)

After:
  Slice 1: 2048 samples (padded)
  Slice 2: 2048 samples (padded)
  Slice 3: 2048 samples (padded)
  
(2048 = next power of 2 after 1500)
```

**Use Cases:**

**Hardware Export:**
```
1. Slice drum loop in Renoise
2. Run power-of-2 padding
3. Export slices
4. Import to Octatrack
5. Perfect compatibility
```

**MPC Workflow:**
```
1. Create slices
2. Apply power-of-2 padding
3. All slices same length
4. MPC recognizes format
5. No timing issues
```

**Technical:** 
- Pads with silence (zeros)
- Preserves original audio
- Doesn't affect playback in Renoise
- Only changes slice boundaries

---

# Notepad Device Code Runner

**Source:** `PakettiNotepadRun.lua` | **Features:** 2

Execute Lua code from Notepad device in the DSP chain for live coding and experimentation.

## Run Notepad Device Code

**Keybinding:** `Global:Paketti:Run Notepad Device Code` ⌨️

**MIDI:** `Paketti:Run Notepad Device Code` 🎹

Executes Lua code written in a Notepad device's text field.

**Setup:**
1. Add Notepad device to track DSP chain
2. Write Lua code in Notepad text field
3. Select track with Notepad
4. Press keybinding
5. Code executes immediately

**Code Execution:**
- Full Renoise API access
- Can modify song state
- Can create/modify patterns
- Can manipulate instruments
- Can control devices

**Example Code:**

**Simple Status:**
```lua
renoise.app():show_status("Hello from Notepad!")
```

**BPM Control:**
```lua
renoise.song().transport.bpm = 140
renoise.app():show_status("BPM set to 140")
```

**Pattern Generation:**
```lua
local s = renoise.song()
for line = 1, 16 do
  s.selected_pattern_track:line(line).note_columns[1].note_value = 48 + (line % 12)
end
renoise.app():show_status("Pattern generated!")
```

**Sample Processing:**
```lua
local s = renoise.song().selected_sample
s.transpose = 12
s.volume = 0.8
renoise.app():show_status("Sample transposed +12")
```

**Use Cases:**

**Live Coding:**
```
1. Open Notepad device
2. Write generative code
3. Run during performance
4. Real-time pattern creation
```

**Experiment:**
```
1. Test API functions
2. Quick prototyping
3. No need for separate script
4. Immediate feedback
```

**Automation Scripting:**
```
1. Write batch operations
2. Store in Notepad device
3. Run when needed
4. Song-specific utilities
```

**Quick Fixes:**
```
1. Need to modify 100 samples?
2. Write loop in Notepad
3. Execute once
4. Done in seconds
```

**Safety:**
- Code runs with full permissions
- Can modify/delete song data
- No undo for code execution
- Test carefully first!

**Tips:**
- Use `print()` for debugging
- Check console for errors
- Start simple, iterate
- Save song before experiments

---


---

# Pattern/Phrase Length Control

**Source:** `PakettiPatternLength.lua` | **Features:** 8

Quick pattern and phrase length adjustment with dialog and keyboard shortcuts.

## Pattern/Phrase Length Dialog

**Keybindings:**
- `Global:Paketti:Show Pattern/Phrase Length Dialog...` ⌨️
- `Pattern Editor:Paketti:Show Pattern Length Dialog...` ⌨️
- `Phrase Editor:Paketti:Show Phrase Length Dialog...` ⌨️

**MIDI:** `Paketti:Show Pattern/Phrase Length Dialog...` 🎹

Opens context-aware length adjustment dialog.

**Dialog Features:**
- **Current Length** - Display only
- **New Length** - Numeric input
- **Common Presets** - Buttons for 16, 32, 64, 128, 256, 512
- **Apply** - Set new length
- **Expand/Shrink Toggle** - Preserve or clear pattern data

**Context-Aware:**
- Pattern Editor → adjusts pattern length
- Phrase Editor → adjusts phrase length
- Automatically detects context

## Phrase Length Shortcuts

### Increase Phrase Length by 8

**Keybinding:** `--Phrase Editor:Paketti:Increase Phrase Length by 8` ⌨️ (separator above)

Adds 8 lines to current phrase.

**Use Case:** Extend phrase for more notes.

### Decrease Phrase Length by 8

**Keybinding:** `Phrase Editor:Paketti:Decrease Phrase Length by 8` ⌨️

Removes 8 lines from end of phrase.

**Warning:** Deletes data if present at end.

### Increase Phrase Length by LPB

**Keybinding:** `Phrase Editor:Paketti:Increase Phrase Length by LPB` ⌨️

Increases phrase length by current LPB value (one beat).

**Example:** LPB=4 → adds 4 lines

### Decrease Phrase Length by LPB

**Keybinding:** `Phrase Editor:Paketti:Decrease Phrase Length by LPB` ⌨️

Decreases phrase length by current LPB value (one beat).

**Use Cases:**

**Pattern Workflow:**
```
1. Create 64-line pattern
2. Need more space
3. Open dialog → 128
4. Extended instantly
```

**Phrase Adjustment:**
```
1. Phrase is 32 lines
2. Press "Increase by 8"
3. Now 40 lines
4. Add more notes
```

**Beat-Based:**
```
1. LPB = 12 (triplets)
2. Phrase = 24 lines (2 beats)
3. Press "Increase by LPB"
4. Now 36 lines (3 beats)
5. Perfect triplet extension
```

---

# Plugin Loader

**Source:** `PakettiLoadPlugins.lua` | **Features:** 4+

Dynamic plugin loading system - creates keybindings for all installed VST/AU plugins.

## Dynamic Plugin Keybindings

**Auto-generated for each installed plugin:**
- Keybinding: `Global:Paketti:Load Plugin [PluginName]` ⌨️
- MIDI mapping: `Paketti:Load Plugin [PluginName]` 🎹

**Scans:**
- VST plugins folder
- VST3 plugins folder
- Audio Units (macOS)
- LADSPA (Linux)
- DSSI (Linux)

**Generation Process:**
1. Renoise starts
2. Scans plugin folders
3. Reads plugin names
4. Creates keybinding for each
5. Creates MIDI mapping for each

**Examples:**
- `Global:Paketti:Load Plugin Massive` ⌨️
- `Global:Paketti:Load Plugin Serum` ⌨️
- `Global:Paketti:Load Plugin Kontakt` ⌨️
- `Global:Paketti:Load Plugin FabFilter Pro-Q` ⌨️
- `Global:Paketti:Load Plugin Valhalla VintageVerb` ⌨️
- etc. (all your plugins!)

**Use Cases:**

**MIDI Controller Integration:**
```
1. Map favorite 8 plugins to MIDI pads
2. Pad 1: Bass synth
3. Pad 2: Lead synth
4. Pad 3: Drum machine
5. Pad 4: Reverb
6. One-press plugin loading
```

**Quick Production:**
```
1. Start with empty track
2. Press plugin keybinding
3. Plugin loads instantly
4. Start playing immediately
```

**Live Performance:**
```
1. Pre-map plugins to hardware
2. Load instruments on-the-fly
3. No mouse/menu diving
4. Fast workflow
```

---

# Pattern Delay Viewer

**Source:** `PakettiPatternDelayViewer.lua` | **Features:** 3

Visual pattern delay (0Dxx) analyzer and editor with delay visualization and batch editing.

## Show Pattern Delay Viewer

**Keybinding:** `Global:Paketti:Show Pattern Delay Viewer...` ⌨️

Opens visual analyzer showing all delay column values in current pattern.

**Dialog Features:**

### Visual Display
- **Timeline View** - Horizontal timeline of pattern
- **Delay Values** - Shows 0Dxx values as vertical bars
- **Note Markers** - Which lines have notes
- **Track View** - Shows delays per track
- **Color Coding** - Different colors for delay ranges

### Statistics
- **Total Delays** - Count of delay commands
- **Average Delay** - Mean delay value
- **Max/Min Delay** - Highest/lowest values
- **Delay Distribution** - Histogram of values

### Delay Value Analysis
- **0D00-0D20** - Small delays (tight humanization)
- **0D21-0D40** - Medium delays (shuffle feel)
- **0D41-0D80** - Large delays (pushed/laid-back feel)
- **0D81-0DFF** - Extreme delays (nearly next line)

**Use Case:** Visualize humanization/groove, analyze delay patterns.

## Copy Delay to All Same Notes in Track

**Keybinding:** `Pattern Editor:Paketti:Copy Delay to All Same Notes in Track` ⌨️

Copies delay value from selected note to all identical notes in current track.

**Process:**
1. Select note with delay (e.g., C-4 with 0D10)
2. Press keybinding
3. All C-4 notes in track get 0D10
4. Other notes unchanged

**Use Cases:**

**Consistent Groove:**
```
1. Set perfect delay on snare (0D18)
2. Copy to all snares in track
3. Consistent groove throughout
4. No manual copying
```

**Batch Humanization:**
```
1. Adjust delay on hi-hat
2. Copy to all hi-hats
3. All hi-hats have same feel
4. Instant consistency
```

## Set Delay for All Same Notes in Track

**Keybinding:** `Pattern Editor:Paketti:Set Delay for All Same Notes in Track...` ⌨️

Prompts for delay value and applies to all matching notes in track.

**Process:**
1. Select note (e.g., C-4)
2. Press keybinding
3. Dialog: Enter delay value (00-FF)
4. All C-4 notes get that delay
5. Can override existing delays

**Use Cases:**

**Quantize Humanization:**
```
1. All kicks have random delays
2. Want consistent timing
3. Set all kicks to 0D00 (no delay)
4. Perfect timing restored
```

**Add Groove:**
```
1. Select snare note
2. Set delay for all same notes
3. Enter: 0D15
4. All snares pushed slightly
5. Instant groove adjustment
```

**Create Swing:**
```
1. Off-beat hi-hats selected
2. Set delay: 0D20
3. Off-beats pushed back
4. Swing feel created
```

---

# Effect Command CheatSheet

**Source:** `PakettiPatternEditorCheatSheet.lua` | **Features:** 5

Visual reference guides for Renoise effect commands with searchable database and quick reference. **Works in both Pattern Editor and Phrase Editor** - automatically detects which editor is active and applies effects to the appropriate context. **Now includes Sample FX mode** for writing effects directly to note column sample effect sub-columns.

## Effect Command CheatSheet

**Keybinding:** `Global:Paketti:Pattern Effect Command CheatSheet` ⌨️

Comprehensive effect command reference with descriptions and examples.

### Pattern Editor vs Phrase Editor Mode

The cheatsheet automatically detects whether you're working in the Pattern Editor or Phrase Editor:

**Pattern Editor Mode:**
- All effect commands are available
- Effects apply to pattern selection or current line
- Full set of track-level and global effects

**Phrase Editor Mode:**
- Only phrase-valid effects are enabled (sample/note-level effects)
- Pattern-only effects (track routing, global commands) are visually disabled
- Effects apply to phrase selection or current phrase line
- Volume, Panning, Delay, and Sample FX columns are automatically made visible when using their respective sliders

**Phrase-Valid Effects (17 effects):**
- **0Axy** - Set arpeggio, x/y = first/second note offset in semitones
- **0Uxx** - Slide Pitch up by xx 1/16ths of a semitone
- **0Dxx** - Slide Pitch down by xx 1/16ths of a semitone
- **0Gxx** - Glide towards given note by xx 1/16ths of a semitone
- **0Ixx** - Fade Volume in by xx volume units
- **0Oxx** - Fade Volume out by xx volume units
- **0Cxy** - Cut volume to x after y ticks (x = volume factor: 0=0%, F=100%)
- **0Qxx** - Delay note by xx ticks
- **0Mxx** - Set note volume to xx
- **0Sxx** - Trigger sample slice number xx or offset xx
- **0Bxx** - Play Sample Backwards (B00) or forwards again (B01)
- **0Rxy** - Retrigger line every y ticks with volume factor x
- **0Yxx** - Maybe trigger line with probability xx, 00 = mutually exclusive note columns
- **0Vxy** - Set Vibrato x = speed, y = depth; x=(0-F); y=(0-F)
- **0Txy** - Set Tremolo x = speed, y = depth
- **0Nxy** - Set Auto Pan, x = speed, y = depth
- **0Exx** - Set Active Sample Envelope's Position to Offset XX

**Pattern-Only Effects (12 effects - disabled in Phrase Editor):**
- **0Zxx** - Trigger Phrase (01-7E = phrase number, 00 = none, 7F = keymap)
- **0Lxx** - Set Track Volume Level (00 = -INF, FF = +3dB)
- **0Pxx** - Set Track Pan (00 = full left, 80 = center, FF = full right)
- **0Wxx** - Set Track Surround Width (00 = Min, FF = Max)
- **0Jxx** - Set Track Routing (01 upwards = hardware, FF downwards = parent groups)
- **0Xxx** - Stop all notes and FX (00), or only effect xx (>00)
- **ZTxx** - Set tempo to xx BPM (14-FF, 00 = stop song)
- **ZLxx** - Set Lines Per Beat (LPB) to xx lines
- **ZKxx** - Set Ticks Per Line (TPL) to xx ticks (01-10)
- **ZGxx** - Enable (01) or disable (00) Groove
- **ZBxx** - Break pattern and jump to line xx in next
- **ZDxx** - Delay (pause) pattern for xx lines

### Write Mode: Effect Columns vs Sample FX

The cheatsheet includes a **Write Mode Switch** that lets you choose where effects are written:

**Switch Options:**
- **Effect Columns** (Default) - Writes to the track's effect columns (standard behavior)
- **Sample FX** - Writes to the Sample FX sub-column of note columns

#### Effect Columns Mode

The default mode that writes effects to the track's effect columns:
- All 29 effect commands are available (filtered by Pattern/Phrase context)
- Effects are written to effect columns at the right side of the track
- Supports selection-based writing across multiple effect columns
- Makes effect columns visible automatically

#### Sample FX Mode

Writes effects directly to the Sample FX sub-column within note columns:

**How it works:**
- Effects are written to the per-note-column sample effects area (the small FX column after Volume/Panning/Delay)
- Automatically makes the sample effects column visible
- Requires cursor to be in a note column (not an effect column)
- If there's a selection, writes to all selected note columns

**Sample FX-Valid Effects (13 effects):**

| Code | Syntax | Description |
|------|--------|-------------|
| 0A | -Axy | Set arpeggio, x/y = first/second note offset in semitones |
| 0U | -Uxx | Slide pitch up by xx 1/16ths of a semitone |
| 0D | -Dxx | Slide pitch down by xx 1/16ths of a semitone |
| 0G | -Gxx | Glide towards given note by xx 1/16ths of a semitone |
| 0V | -Vxy | Set vibrato, x = speed, y = depth |
| 0I | -Ixx | Fade volume in by xx volume units |
| 0O | -Oxx | Fade volume out by xx volume units |
| 0T | -Txy | Set tremolo, x = speed, y = depth |
| 0C | -Cxy | Cut volume to x after y ticks |
| 0S | -Sxx | Trigger sample slice number xx or offset xx |
| 0B | -Bxx | Play sample backwards (00) or forwards (01) |
| 0E | -Exx | Set envelope position to offset xx |
| 0N | -Nxy | Set auto pan, x = speed, y = depth |

**Effects NOT available in Sample FX mode:**
- Track effects (0L, 0P, 0W, 0J, 0X, 0Z)
- Global effects (ZT, ZL, ZK, ZG, ZB, ZD)
- Note column sub-commands (0Q, 0M, 0R, 0Y)

**Button States:**
When switching to Sample FX mode, buttons for invalid effects are automatically disabled/grayed out.

**Clear Button:**
The Clear button changes based on mode:
- **Effect Columns mode:** "Clear Effects" - clears effect columns
- **Sample FX mode:** "Clear Sample FX" - clears sample effects from note columns

**Use Cases:**
- Adding per-note pitch slides without using effect columns
- Writing vibrato/tremolo directly to specific notes
- Randomizing sample slices across multiple note columns
- Keeping effect columns free for track-level automation

**Works in both Pattern Editor and Phrase Editor:**
Sample FX mode works identically in both editors - it detects the current context and writes to the appropriate note columns.

### Dialog Features

#### Complete Effect Command List (29 Effects)

All effect commands available in the cheatsheet, organized by category:

**Sample/Note Effects (✓ Work in both Pattern and Phrase Editor):**

| Code | Syntax | Description |
|------|--------|-------------|
| 0A | -Axy | Set arpeggio, x/y = first/second note offset in semitones |
| 0U | -Uxx | Slide Pitch up by xx 1/16ths of a semitone |
| 0D | -Dxx | Slide Pitch down by xx 1/16ths of a semitone |
| 0G | -Gxx | Glide towards given note by xx 1/16ths of a semitone |
| 0I | -Ixx | Fade Volume in by xx volume units |
| 0O | -Oxx | Fade Volume out by xx volume units |
| 0C | -Cxy | Cut volume to x after y ticks (x = volume factor: 0=0%, F=100%) |
| 0Q | -Qxx | Delay note by xx ticks |
| 0M | -Mxx | Set note volume to xx |
| 0S | -Sxx | Trigger sample slice number xx or offset xx |
| 0B | -Bxx | Play Sample Backwards (B00) or forwards again (B01) |
| 0R | -Rxy | Retrigger line every y ticks with volume factor x |
| 0Y | -Yxx | Maybe trigger line with probability xx, 00 = mutually exclusive note columns |
| 0V | -Vxy | Set Vibrato x = speed, y = depth; x=(0-F); y=(0-F) |
| 0T | -Txy | Set Tremolo x = speed, y = depth |
| 0N | -Nxy | Set Auto Pan, x = speed, y = depth |
| 0E | -Exx | Set Active Sample Envelope's Position to Offset XX |

**Track Effects (Pattern Editor Only - disabled in Phrase Editor):**

| Code | Syntax | Description |
|------|--------|-------------|
| 0Z | -Zxx | Trigger Phrase xx (Phrase Number 01-7E, 00 = none, 7F = keymap) |
| 0L | -Lxx | Set Track Volume Level, 00 = -INF, FF = +3dB |
| 0P | -Pxx | Set Track Pan, 00 = full left, 80 = center, FF = full right |
| 0W | -Wxx | Set Track Surround Width, 00 = Min, FF = Max |
| 0J | -Jxx | Set Track Routing, 01 upwards = hardware channels, FF downwards = parent groups |
| 0X | -Xxx | Stop all notes and FX (xx = 00), or only effect xx (xx > 00) |

**Global/Song Effects (Pattern Editor Only - disabled in Phrase Editor):**

| Code | Syntax | Description |
|------|--------|-------------|
| ZT | ZTxx | Set tempo to xx BPM (14-FF, 00 = stop song) |
| ZL | ZLxx | Set Lines Per Beat (LPB) to xx lines |
| ZK | ZKxx | Set Ticks Per Line (TPL) to xx ticks (01-10) |
| ZG | ZGxx | Enable (xx = 01) or disable (xx = 00) Groove |
| ZB | ZBxx | Break pattern and jump to line xx in next |
| ZD | ZDxx | Delay (pause) pattern for xx lines |

#### Randomization Settings

The cheatsheet includes powerful randomization options for effect values:

**Randomize Checkbox:**
- Enable/disable randomization when adjusting sliders
- When enabled, slider movements apply random values within Min/Max range

**Fill Probability Slider (0-100%):**
- Controls probability that each line receives a value
- 100% = fill all lines, 50% = fill roughly half

**Randomize Whole Track:**
- When enabled, randomization applies to entire track/phrase
- When disabled, only selection or current line is affected

**Randomize Min/Max Only:**
- Values are randomly chosen between only the Min OR Max value
- Creates binary switching effect

**Don't Overwrite Existing Data:**
- Skip lines that already have effect values
- Preserves manually entered data

**Only Modify Rows With Effects:**
- Only randomize lines that already contain effects
- Useful for modifying existing effect patterns

**Only Modify Rows With Notes:**
- Only randomize lines that contain note data
- Useful for tying effects to melodic content

**Min/Max Sliders:**
- Set the range for random values (00-FF)
- Displayed in hexadecimal
- Use < > buttons for fine adjustment

#### Note Column Sliders

Sliders for directly setting note column values across selection:

- **Volume Slider** - Set volume values (automatically shows Volume column in Phrase Editor)
- **Panning Slider** - Set panning values (automatically shows Panning column in Phrase Editor)
- **Delay Slider** - Set delay values (automatically shows Delay column in Phrase Editor)
- **Sample FX Slider** - Set sample effect values (automatically shows Sample FX column in Phrase Editor)
- **Effect Slider** - Set effect amount values

#### Search Function
- **Filter box** - Type to search
- **Category filter** - Filter by type
- **Example filter** - Show only with examples

#### Examples Tab
Real-world usage examples:
- **Drum Rolls** - Using 0Rxx
- **Risers** - Using 01xx
- **Stutters** - Using 0Sxx + 09xx
- **Pitch Dives** - Using 02xx

#### Copy Function
- Click effect command
- Copies to clipboard
- Ready to paste in pattern or phrase

#### Additional Buttons
- **Clear Effects** - Clear all effect columns in selection
- **Minimize Horizontal** - Switch to compact horizontal view
- **Minimize Vertical** - Switch to compact vertical view
- **Close** - Close the dialog

## Minimize Cheatsheet (Horizontal)

**Keybinding:** `Global:Paketti:Show Minimize Cheatsheet Horizontal` ⌨️

Compact horizontal reference showing most common effects. Includes mode indicator showing whether you're in Pattern or Phrase mode.

**Display:**
```
[Pattern Mode] or [Phrase Mode]
Dropdown: Effect selection (filtered by mode)
Random button | Apply button
```

**Features:**
- Mode indicator updates dynamically
- Effect dropdown shows only valid effects for current mode
- Random selection respects mode filtering

**Use Case:** Quick reference without full dialog, stays on screen.

## Minimize Cheatsheet (Vertical)

**Keybinding:** `Global:Paketti:Show Minimize Cheatsheet Vertical` ⌨️

Compact vertical reference for common effects. Includes mode indicator.

**Display:**
```
[Pattern Mode] or [Phrase Mode]
Effect dropdown
Random | Apply
```

**Features:**
- Same mode-aware filtering as horizontal version
- Vertical layout for side panel placement

**Use Case:** Side panel reference, doesn't obstruct pattern or phrase editor.

## Toggle Pattern Status Monitor

**Keybinding:** `Global:Paketti:Toggle Pattern Status Monitor` ⌨️

Enables/disables real-time pattern/phrase statistics in status bar. **Context-aware** - displays different information based on active editor.

**Pattern Editor Displays:**
- Current pattern length
- Pattern number
- Track count
- Note count in pattern
- Effect count
- Instrument index (I:xx)
- Updates as cursor moves

**Phrase Editor Displays:**
- Phrase information with [Phrase] prefix
- Sample index (S:xx) instead of instrument index
- Phrase line position
- Updates as phrase cursor moves

**Use Case:** 
- Monitor pattern complexity
- Track note density
- See effect usage
- Real-time pattern stats

---


---

# Sample Processing Suite

**Source:** `PakettiProcess.lua` | **Features:** 49

Comprehensive sample processing toolkit with normalization, reversal, channel operations, and bit depth conversion.

## Normalization Features

### Normalize Selected Sample or Slice

**Keybindings:**
- `Sample Editor:Paketti:Normalize Selected Sample or Slice` ⌨️
- `Global:Paketti:Normalize Selected Sample or Slice` ⌨️

**MIDI:** `Paketti:Normalize Selected Sample or Slice` 🎹

Normalizes selected sample or individual slice to maximum amplitude without clipping.

**Slice-Aware:**
- If selection within slice: Normalizes only that slice
- If full sample: Normalizes entire sample
- Preserves relative loudness between slices

### Normalize Sample

**Keybinding:** `Global:Paketti:Normalize Sample` ⌨️

Ultra-fast normalization of current sample to 0dB peak.

### Normalize All Samples in Instrument

**Keybinding:** `Global:Paketti:Normalize All Samples in Instrument` ⌨️

**MIDI:** `Paketti:Normalize All Samples in Instrument` 🎹

Normalizes every sample in selected instrument.

**Process:**
- Analyzes peak of each sample
- Calculates gain needed
- Applies normalization
- Maintains relative balance between samples

### Normalize to -12dB

**Sample:**
- `Sample Editor:Paketti:Normalize Selected Sample to -12dB` ⌨️
- `Paketti:Normalize Selected Sample to -12dB` 🎹

**Instrument:**
- `Sample Editor:Paketti:Normalize Selected Instrument to -12dB` ⌨️
- `Paketti:Normalize Selected Instrument to -12dB` 🎹

**All Instruments:**
- `Sample Editor:Paketti:Normalize All Instruments to -12dB` ⌨️
- `Paketti:Normalize All Instruments to -12dB` 🎹

Normalizes to -12dB instead of 0dB, leaving headroom for mixing.

**Use Case:** Consistent levels across all samples with headroom for processing.

### Normalize Sample Slices Independently

**Keybinding:** `Global:Paketti:Normalize Sample Slices Independently` ⌨️

Normalizes each slice individually to maximum amplitude.

**Process:**
1. Detects all slice markers
2. Analyzes peak of each slice
3. Normalizes each slice independently
4. Each slice reaches maximum amplitude

**Use Case:**
- Drum breaks with quiet snares
- Uneven slice loudness
- Maximize dynamic range per slice

## Reverse Features

### Reverse Selected Sample or Slice

**Keybindings:**
- `Sample Editor:Paketti:Reverse Selected Sample or Slice` ⌨️
- `Sample Keyzones:Paketti:Reverse Selected Sample or Slice` ⌨️

**MIDI:** `Paketti:Reverse Selected Sample or Slice` 🎹

Reverses selected sample or individual slice.

**Slice-Aware:**
- If slice selected: Reverses only that slice
- If full sample: Reverses entire sample

### Reverse All Samples in Selected Instrument

**Keybinding:** `Global:Paketti:Reverse All Samples in Selected Instrument` ⌨️

**MIDI:** `Paketti:Reverse All Samples in Selected Instrument` 🎹

**Menu:** `Sample Editor:Paketti:Process:Reverse All Samples in Selected Instrument` 📋

Reverses every sample in instrument.

**Use Cases:**
- Reverse cymbal swells
- Backward vocals
- Reverse drum hits
- Experimental textures

## Stereo/Mono Conversion

### Mono to Stereo

**Keybindings:**
- `Sample Editor:Paketti:Convert Mono to Stereo` ⌨️
- `Sample Keyzones:Paketti:Convert Mono to Stereo` ⌨️

**MIDI:** `Sample Editor:Paketti:Convert Mono to Stereo` 🎹

Converts mono sample to stereo (duplicates to both channels).

### Mono to Left/Right with Blank

**Left Channel:**
- `Sample Editor:Paketti:Mono to Left with Blank Right` ⌨️
- `Sample Keyzones:Paketti:Mono to Left with Blank Right` ⌨️
- `Sample Editor:Paketti:Mono to Left with Blank Right` 🎹

**Right Channel:**
- `Sample Editor:Paketti:Mono to Right with Blank Left` ⌨️
- `Sample Keyzones:Paketti:Mono to Right with Blank Left` ⌨️
- `Sample Editor:Paketti:Mono to Right with Blank Left` 🎹

Places mono signal in one channel, leaves other channel silent.

**Use Case:** Extreme hard-panning, stereo placement control.

### Stereo to Mono (Keep One Channel)

**Keep Left:**
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Left)` ⌨️
- `Sample Keyzones:Paketti:Convert Stereo to Mono (Keep Left)` ⌨️
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Left)` 🎹

**Keep Right:**
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Right)` ⌨️
- `Sample Keyzones:Paketti:Convert Stereo to Mono (Keep Right)` ⌨️
- `Sample Editor:Paketti:Convert Stereo to Mono (Keep Right)` 🎹

Converts stereo to mono by keeping only specified channel.

### Stereo to Mono (Mix Both)

**Keybindings:**
- `Sample Editor:Paketti:Convert Stereo to Mono (Mix Both)` ⌨️
- `Sample Keyzones:Paketti:Convert Stereo to Mono (Mix Both)` ⌨️

**MIDI:** `Sample Editor:Paketti:Convert Stereo to Mono (Mix Both)` 🎹

Mixes both channels to mono (averages L+R).

**Use Case:** True mono conversion preserving both channels.

### Convert All Samples to Mono

**Keep Left:**
- `Sample Editor:Paketti:Convert All Samples to Mono (Keep Left)` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to Mono (Keep Left)` ⌨️
- `Sample Editor:Paketti:Convert All Samples to Mono (Keep Left)` 🎹

**Keep Right:**
- `Sample Editor:Paketti:Convert All Samples to Mono (Keep Right)` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to Mono (Keep Right)` ⌨️
- `Sample Editor:Paketti:Process:Convert All Samples to Mono (Keep Right)` 🎹

**Mix Both:**
- `Sample Editor:Paketti:Convert All Samples to Mono (Mix Both)` ⌨️
- `Sample Keyzones:Paketti:Convert All Samples to Mono (Mix Both)` ⌨️
- `Sample Editor:Paketti:Process:Convert All Samples to Mono (Mix Both)` 🎹

Batch converts all samples in instrument to mono.

**Use Case:** Reduce file size, ensure mono compatibility.

## Bit Depth Conversion

**Keybindings:**
- `Sample Editor:Paketti:Convert to 8-bit` ⌨️
- `Sample Editor:Paketti:Convert to 16-bit` ⌨️
- `Sample Editor:Paketti:Convert to 24-bit` ⌨️

Converts sample bit depth with dithering.

**8-bit:**
- Lo-fi character
- Reduced file size
- Vintage sampler sound

**16-bit:**
- CD quality
- Standard resolution
- Good balance

**24-bit:**
- Maximum quality
- Studio standard
- Best for processing

**Use Cases:**

**Lo-Fi Effects:**
```
1. High-quality sample
2. Convert to 8-bit
3. Instant lo-fi character
4. Vintage sound
```

**File Size Optimization:**
```
1. 24-bit samples too large
2. Convert to 16-bit
3. Smaller file size
4. Minimal quality loss
```

---

# Audio Processing Tools

**Source:** `PakettiAudioProcessing.lua` | **Features:** 28

Advanced audio processing including phase operations, silence management, and creative effects.

## Audio Processing Tools Dialog

**Keybinding:** `Global:Paketti:Paketti Audio Processing Tools Dialog...` ⌨️

Unified dialog for various audio processing operations.

**Available Operations:**
- Phase Inversion
- Pitch Shifting
- Modulation
- Audio Diff
- DC Offset Removal
- Silence Management

## Protracker MOD Modulation

**Keybinding:** `Sample Editor:Paketti:Protracker MOD Modulation...` ⌨️

Applies classic Protracker-style modulation effects.

**Effects:**
- Vibrato
- Tremolo
- Arpeggio
- Portamento

**MOD-Accurate:**
- Period-based pitch
- 4-bit depth
- Authentic Amiga sound

## Phase Operations

### Phase Inversion

**Keybinding:** `Sample Editor:Paketti:Phase Inversion` ⌨️

Inverts phase of sample (multiplies by -1).

**Use Cases:**
- Fix phase issues
- Cancel frequencies
- Create hollow sounds

### Phase Inversion & Audio Diff

**Keybinding:** `Sample Editor:Paketti:Phase Inversion & Audio Diff` ⌨️

Inverts phase and creates difference sample.

### Invert Right, Sum Mono

**Keybinding:** `Sample Editor:Paketti:Invert Right, Sum Mono` ⌨️

Inverts right channel and sums to mono.

**Result:** Extracts center-canceled audio (isolates sides).

**Use Case:**
- Remove centered vocals
- Extract side information
- Mid-side processing

## Pitch Operations

### Pitch Shift

**Keybinding:** `Sample Editor:Paketti:Pitch Shift` ⌨️

Shifts pitch of sample (default: +20 semitones).

### Pitch Shift & Audio Diff

**Keybinding:** `Sample Editor:Paketti:Pitch Shift & Audio Diff` ⌨️

Pitch shifts and creates difference between original and shifted.

**Result:** Harmonic content extraction.

## Modulation Effects

### Clip Bottom of Waveform

**Keybinding:** `Sample Editor:Paketti:Clip bottom of waveform` ⌨️

Clips negative amplitude values.

**Effect:**
- Half-wave rectification
- Harsh distortion
- Octave-up artifacts

### Modulate & Audio Diff

**Keybinding:** `Sample Editor:Paketti:Modulate & Audio Diff` ⌨️

Applies modulation and creates difference sample.

## Audio Diff

**Keybinding:** `Sample Editor:Paketti:Audio Diff` ⌨️

Creates difference between current sample and last processed version.

**Use Case:**
- Hear what effect changed
- Extract processing artifacts
- A/B comparison

## Silence Management

### Strip Silence

**Keybinding:** `Global:Paketti:Strip Silence` ⌨️

**MIDI:** `Paketti:Strip Silence` 🎹

Removes silence from beginning and end of sample.

**Process:**
1. Detects silence threshold
2. Finds first non-silent sample
3. Finds last non-silent sample
4. Trims sample

### Move Beginning Silence to End

**Keybinding:** `Global:Paketti:Move Beginning Silence to End` ⌨️

**MIDI:** `Paketti:Move Beginning Silence to End` 🎹

Moves leading silence to end of sample.

**Use Case:**
- Maintain sample length
- Fix loop timing
- Preserve sync

### Move Silence (All Samples)

**Keybinding:** `Global:Paketti:Move Beginning Silence to End for All Samples` ⌨️

Batch processes all samples in instrument.

### Strip Silence (All Samples)

**Keybinding:** `Global:Paketti:Strip Silence from All Samples` ⌨️

Removes silence from all samples in instrument.

## Sample Inversion

### Invert Entire Sample

**Keybindings:**
- `Global:Paketti:Invert Sample` ⌨️
- `Sample Editor:Paketti:Invert Sample` ⌨️

Inverts entire sample waveform.

### Invert Single Channel

**Left Channel:**
- `Sample Editor:Paketti:Invert Left Channel` ⌨️

**Right Channel:**
- `Sample Editor:Paketti:Invert Right Channel` ⌨️

Inverts only specified channel.

### Invert Random Samples

**Keybinding:** `Global:Paketti:Invert Random Samples in Instrument` ⌨️

Randomly inverts samples in instrument.

**Use Case:** Experimental, chaotic variations.

## Fade Operations

### 15 Frame Fade In & Fade Out

**Keybinding:** `Sample Editor:Paketti:15 Frame Fade In & Fade Out` ⌨️

Applies short fade in (15 frames) and fade out (15 frames).

**Use Case:**
- Remove clicks
- Smooth sample edges
- Quick crossfades

## DC Offset Removal

### Recursive Remove DC Offset

**Keybinding:** `Sample Editor:Process:Recursive Remove DC Offset` ⌨️

Recursively removes DC offset until centered.

**Process:**
1. Calculate DC offset
2. Remove offset
3. Re-calculate
4. Repeat until < threshold

### Recursive Remove DC Offset Random Times

**Keybinding:** `Sample Editor:Process:Recursive Remove DC Offset Random Times` ⌨️

Applies recursive DC offset removal 1-50 random times.

**Use Case:** Experimental offset manipulation.

## Creative Generators

### Max Amp DC Offset Kick Generator

**Keybinding:** `Global:Paketti:Max Amp DC Offset Kick Generator` ⌨️

Generates kick drum using DC offset and maximum amplitude.

**Process:**
1. Creates DC offset pulse
2. Applies exponential decay
3. Results in kick-like transient

### Diagonal Line to Sample

**Keybinding:** `Global:Paketti:Diagonal Line to 16800 length Sample` ⌨️

Creates 16,800-sample diagonal line waveform.

**Result:**
- Linear ramp from -1 to +1
- Sawtooth-like tone
- Experimental waveform

## Sample Adjust Dialog

**Keybindings:**
- `Sample Editor:Paketti:Paketti Sample Adjust Dialog...` ⌨️
- `Global:Paketti:Paketti Sample Adjust Dialog...` ⌨️

Unified dialog for sample parameter adjustment.

**Parameters:**
- Volume
- Panning
- Transpose
- Finetune
- All sample properties

---

# Action Selector

**Source:** `PakettiActionSelector.lua` | **Features:** 1

Searchable command palette for all Paketti functions.

## Paketti Action Selector Dialog

**Keybinding:** `Global:Paketti:Paketti Action Selector Dialog...` ⌨️

Quick-launch dialog with fuzzy search for all Paketti features.

**Dialog Features:**

### Command Search
- **Search Box** - Type to filter
- **Fuzzy Matching** - Finds partial matches
- **Real-time Filter** - Updates as you type
- **Keyboard Navigation** - Arrow keys + Enter

### Command Database
Indexes all Paketti functions:
- All keybindings
- All menu entries
- All tools
- All dialogs

**Display:**
- Command name
- Keybinding (if assigned)
- Category
- Description

**Search Examples:**
```
Type: "norm" 
Finds:
  - Normalize Sample
  - Normalize All Samples
  - Normalize to -12dB
  - Normalize Slices

Type: "rev"
Finds:
  - Reverse Sample
  - Reverse All Samples
  - Reverb (if mapped)

Type: "slice"
Finds:
  - All slice-related commands
  - Slice markers
  - Slice to pattern
  - etc.
```

**Use Cases:**

**Command Discovery:**
```
1. Not sure what's available
2. Open Action Selector
3. Browse commands
4. Launch directly
```

**Fuzzy Recall:**
```
1. "Something with normalize..."
2. Type: "norm"
3. See all normalization features
4. Pick correct one
```

**Keyboard-Only Workflow:**
```
1. Open Action Selector (keybinding)
2. Type command name
3. Press Enter
4. No mouse needed
```

---


---

# XRNS Probe (Song File Inspector)

**Source:** `PakettiXRNSProbe.lua` | **Features:** 2

Advanced XRNS file inspector and browser for analyzing Renoise song structure.

## Paketti XRNS Probe

**Keybinding:** `Global:Paketti:Paketti XRNS Probe` ⌨️

**Menu:** `Main Menu:Tools:Paketti:Xperimental/WIP:Paketti XRNS Probe (Browse)` 📋

Deep inspection tool for XRNS (Renoise Song) file format.

**Dialog Features:**

### File Browser
- Browse XRNS files on disk
- Show file size and date
- Quick preview
- Load for inspection

### XRNS Structure Analysis

**Song.xml Inspection:**
- Track count
- Pattern count  
- Sequence length
- BPM/LPB/TPL settings
- Master track settings

**Instruments:**
- Instrument count
- Sample count per instrument
- Sample sizes
- Plugin instances

**Patterns:**
- Pattern lengths
- Line count
- Track data size
- Note density

**Device Chains:**
- Device count
- Device types
- Parameter count
- Routing structure

### Internal File List
XRNS files are ZIP archives containing:
- `Song.xml` - Main song data
- `Instrument NN/` - Instrument folders
- `Sample NN/` - Sample data
- `Effects/` - Effect settings
- `Automation/` - Automation envelopes

**Display:**
- File paths within XRNS
- File sizes
- Compression ratios
- Total archive size

### Use Cases

**Song Analysis:**
```
1. Load colleague's XRNS
2. Inspect structure
3. See track/pattern layout
4. Understand song before opening
```

**File Forensics:**
```
1. Corrupted XRNS?
2. Probe file structure
3. Identify missing files
4. Diagnose issues
```

**Learning Tool:**
```
1. Analyze professional XRNS files
2. Study structure
3. Learn techniques
4. Understand best practices
```

---

# Zyklus MPS1 Sampler Support

**Source:** `PakettiZyklusMPS1.lua` | **Features:** 2

Import/export support for Zyklus MPS-1 sampler format.

## Zyklus MPS1 Import/Export

**Menu:** (XRNS file format support)

**Keybinding:** (Integrated with sample operations)

Support for Zyklus MPS-1 hardware sampler format.

**Import Features:**
- Load MPS-1 sample banks
- Parse instrument metadata
- Import slice markers
- Preserve loop points

**Export Features:**
- Export to MPS-1 format
- Maintain compatibility
- Optimize for hardware

**MPS-1 Format:**
- 16-bit WAV samples
- Metadata sidecar files
- Hardware-specific parameters
- Bank organization

**Use Cases:**
- Transfer samples from MPS-1 to Renoise
- Prepare samples for MPS-1 export
- Round-trip workflow
- Hardware/software integration

---

# KeyBindings Management

**Source:** `PakettiKeyBindings.lua` | **Features:** 5

Advanced keybinding browser and manager for Paketti and Renoise.

## Show Paketti KeyBindings Dialog

**Keybinding:** `Global:Paketti:Show Paketti KeyBindings Dialog...` ⌨️

**Menu:** (Available in multiple contexts)

Displays all Paketti keybindings in searchable list.

**Dialog Features:**

### Keybinding List
- All Paketti commands
- Currently assigned keys
- Conflicts highlighted
- Unassigned commands shown

### Search & Filter
- **Search Box** - Type to filter
- **Category Filter** - By function type
- **Assigned/Unassigned** - Show only mapped/unmapped
- **Conflict Detection** - Highlight duplicates

### Assignment Status
- ✓ Assigned - Green
- ⚠ Conflict - Yellow/Red
- ○ Unassigned - Gray

## Show Renoise KeyBindings Dialog

**Keybinding:** `Global:Paketti:Show Renoise KeyBindings Dialog...` ⌨️

Same as above but for native Renoise keybindings.

**Shows:**
- All Renoise commands
- Default keybindings
- User customizations
- Global vs. context bindings

## Show Free KeyBindings Dialog

**Keybinding:** `Global:Paketti:Show Free KeyBindings Dialog...` ⌨️

Shows unassigned key combinations available for mapping.

**Analysis:**
- Scans all key combinations
- Checks Renoise + Paketti bindings
- Lists available keys
- Suggests optimal mappings

**Display:**
- **Free Keys** - Completely unassigned
- **Context-Free** - Free in specific contexts
- **Modifier Combos** - Ctrl/Shift/Alt combinations
- **Function Keys** - F1-F12 availability

**Use Cases:**

**Find Available Keys:**
```
1. Want to map new function
2. Open Free KeyBindings
3. See what's available
4. Pick optimal key
```

**Avoid Conflicts:**
```
1. About to assign keybinding
2. Check if key is free
3. Prevent overwriting
4. Clean key assignments
```

**Optimize Workflow:**
```
1. Map frequently-used functions
2. Find ergonomic keys
3. Logical grouping
4. Efficient layout
```

---

# Multi-File Raw Loader

**Source:** `PakettiImport.lua` | **Features:** 5

Import multiple raw/headerless audio files as 8-bit samples.

## Multi-File Raw Loader (8-bit)

**Keybinding:** `Global:Paketti:Multi-File Raw Loader (8-bit)` ⌨️

**MIDI:** `Paketti:Multi-File Raw Loader (8-bit)` 🎹

**Menus:**
- `Main Menu:Tools:Paketti:Instruments:File Formats:Multi-File Raw Loader (8-bit)` 📋
- `Instrument Box:Paketti:Load:Multi-File Raw Loader (8-bit)` 📋
- `Sample Editor:Paketti:Load:Multi-File Raw Loader (8-bit)` 📋

Loads multiple raw/headerless audio files as 8-bit samples.

**Dialog Features:**

### File Selection
- Multi-file picker
- Folder batch import
- Drag & drop support
- File filtering

### Import Settings

**Sample Rate:**
- 8000 Hz (lo-fi)
- 11025 Hz (phone quality)
- 22050 Hz (half CD)
- 44100 Hz (CD quality)
- Custom sample rate

**Bit Interpretation:**
- Signed 8-bit
- Unsigned 8-bit
- Auto-detect

**Channel Configuration:**
- Mono
- Stereo (interleaved)
- Stereo (separate L/R files)

### Raw File Formats

**What are Raw Files?**
- No header information
- Pure audio data
- No metadata
- Manual interpretation needed

**Sources:**
- Vintage samplers
- Game audio
- Embedded systems
- Data sonification
- Binary files

### Processing Options
- **Auto-normalize** - Maximize amplitude
- **Remove DC offset** - Center waveform
- **Trim silence** - Remove leading/trailing silence
- **Map to keyboard** - Auto-keyzone mapping

**Use Cases:**

**Vintage Sampler Files:**
```
1. Old sampler disk images
2. Raw sample dumps
3. No headers
4. Import with raw loader
5. Specify sample rate manually
```

**Game Audio Extraction:**
```
1. Extracted .raw files from game
2. Unknown format
3. Try different sample rates
4. Find correct playback speed
5. Import to Renoise
```

**Data Sonification:**
```
1. Binary file (image, text, etc.)
2. Treat as 8-bit audio
3. Import as raw
4. Create experimental sounds
```

**Hardware Sampler Recovery:**
```
1. Old Akai/E-mu disk
2. Raw sample data
3. No modern support
4. Import via raw loader
5. Preserve vintage sounds
```

---

# Paketti Utilities

**Source:** `PakettiMainMenuEntries.lua` | **Features:** 3

Miscellaneous Paketti utilities and dialogs.

## ∿ Squiggly Sinewave to Clipboard (macOS)

**Keybinding:** `Global:Paketti:∿ Squiggly Sinewave to Clipboard (macOS)` ⌨️

Copies squiggly sinewave symbol (∿) to clipboard.

**Use Case:**
- Text decoration
- Music notation
- Visual markers
- Fun symbol

**macOS Only:** Uses macOS clipboard APIs.

## Toggle Paketti Dialog of Dialogs

**Keybinding:** `Global:Paketti:Toggle Paketti Dialog of Dialogs...` ⌨️

Opens master dialog listing all Paketti dialogs.

**Dialog Features:**

### Dialog Browser
- All Paketti dialogs listed
- Categories:
  - Sample Tools
  - Pattern Tools
  - Instrument Tools
  - Workflow Tools
  - Experimental

### Quick Launch
- Click dialog name to open
- Search/filter dialog list
- Favorites system
- Recently used

**Use Cases:**

**Dialog Discovery:**
```
1. Not sure which dialog needed
2. Open Dialog of Dialogs
3. Browse categories
4. Launch correct tool
```

**Quick Access:**
```
1. Central launcher
2. No need to remember keybindings
3. Visual interface
4. Fast workflow
```

## About Paketti/Donations

**Keybinding:** `Global:Paketti:About Paketti/Donations...` ⌨️

Opens Paketti about dialog with version info and donation links.

**Display:**
- Credits
- List of thanks (ideas, suggestions)
- Donation links (Patreon, Ko-fi, Buymeacoffee, PayPal, etc)
- List of sent donations with URLs
- License information

**Use Case:** Support development, view credits.

---

# Sononymph Integration

**Source:** `Sononymph/AppMain.lua`, `App.lua`, `AppUI.lua` | **Features:** 9

Complete integration with Sononym sample browser - bidirectional sample transfer and search.

## Sononymph Dialog

**Keybinding:** `Global:Sononymph:Open Sononymph Dialog...` ⌨️

**Menus:**
- `Instrument Box:Paketti Gadgets:Sononymph Dialog...` 📋
- `Instrument Box:Paketti:Sononymph:Sononymph Dialog...` 📋

Opens Sononymph control panel for Sononym integration.

**What is Sononym?**
- Professional sample browser/organizer
- AI-powered similarity search
- Automatic sample analysis
- Tag-based organization
- Cross-platform audio search

**Dialog Features:**

### Configuration
- **Sononym Path** - Path to Sononym executable
- **Database Path** - Sononym database location
- **Polling Interval** - How often to check for changes
- **Auto-Transfer Toggle** - Enable/disable live transfer

### Monitoring Status
- **Connection Status** - Connected/Disconnected
- **File Monitor Active** - Real-time file watching
- **Current Selection** - Selected sample in Sononym
- **Transfer Queue** - Pending transfers

### Transfer Modes
- **Manual Transfer** - Click button to transfer
- **Auto Transfer** - Automatic on selection
- **Prompt Mode** - Ask before loading
- **Silent Mode** - Load without confirmation

## Toggle Sononym Auto-Transfer

**Keybinding:** `Global:Sononymph:Toggle Sononym Auto-Transfer [Trigger]` ⌨️

**Menu:** `Instrument Box:Paketti:Sononymph:Toggle Sononym Auto-Transfer` 📋

Enables/disables automatic sample transfer from Sononym to Renoise.

**When Enabled:**
1. Select sample in Sononym
2. Renoise automatically receives it
3. Sample loaded to current instrument
4. No manual import needed

**Use Cases:**
- Quick auditioning
- Rapid sound design
- Browse → load workflow
- Experimental sampling

## Search Selected Sample in Sononym

**Keybinding:** `Global:Sononymph:Search Selected Sample in Sononym` ⌨️

**Menu:** `Instrument Box:Paketti:Sononymph:Search Selected Sample in Sononym` 📋

Searches currently selected Renoise sample in Sononym database.

**Process:**
1. Select sample in Renoise
2. Press keybinding
3. Sononym opens (if not running)
4. Searches for similar samples
5. Shows results based on:
   - Audio similarity (spectral)
   - Filename matching
   - Tag matching
   - Folder structure

**Similarity Search:**
- Finds samples that sound alike
- Spectral analysis comparison
- Timbre matching
- Pitch-independent search

## Load Selected Sample from Sononym (Prompt)

**Keybinding:** `Global:Sononymph:Load Selected Sample from Sononym (Prompt) [Trigger]` ⌨️

Loads selected Sononym sample with confirmation dialog.

**Process:**
1. Select sample in Sononym
2. Press keybinding
3. Dialog appears:
   - Sample name
   - File path
   - File size
   - Sample rate
   - "Load" or "Cancel"
4. Confirm to load

**Prompt Shows:**
- Sample metadata
- Where it will load
- Existing sample warning (if replacing)

## Load Selected Sample from Sononym (No Prompt)

**Keybinding:** `Global:Sononymph:Load Selected Sample from Sononym (No Prompt) [Trigger]` ⌨️

Loads selected Sononym sample instantly without confirmation.

**Process:**
1. Select sample in Sononym
2. Press keybinding
3. Sample loads immediately
4. Replaces current sample

**Use Case:** Fast workflow, no interruptions.

## Sononymph Workflow Examples

### Sound Design Workflow
```
1. Enable Auto-Transfer
2. Browse samples in Sononym
3. Samples load automatically
4. Audition in Renoise
5. Keep or continue browsing
```

### Similarity Search Workflow
```
1. Create cool sound in Renoise
2. Search in Sononym
3. Find similar samples
4. Load variations
5. Build sample palette
```

### Rapid Sampling
```
1. Open Sononymph dialog
2. Monitor mode active
3. Browse Sononym database
4. Click samples → instant load
5. Build track quickly
```

### Genre/Tag Search
```
1. Search "808" in Sononym
2. Browse results
3. Load with keybinding
4. Instant kit building
```

## Technical Details

### File Monitoring
- Watches Sononym configuration file
- Detects selection changes
- Triggers transfer on change
- Configurable polling rate

### Transfer Method
- Reads Sononym config JSON
- Extracts file path
- Loads via Renoise API
- Updates instrument/sample

### Path Validation
- Verifies Sononym installation
- Checks database existence
- Validates file paths
- Reports errors clearly

### Performance
- Lightweight monitoring
- Minimal CPU usage
- Fast transfer speed
- No lag during playback

## Setup Requirements

1. **Sononym Installed**
   - Download from Sononym website
   - Activate license
   - Build/import sample database

2. **Configure Paths**
   - Open Sononymph dialog
   - Set Sononym executable path
   - Set database location
   - Test connection

3. **Enable Monitoring**
   - Start file monitor
   - Enable auto-transfer (optional)
   - Configure polling interval

4. **Ready!**
   - Browse in Sononym
   - Transfer to Renoise
   - Seamless workflow

---


---

# Hotelsinus Step Sequencer

**Source:** `hotelsinus_stepseq/hotelsinus_stepseq.lua` | **Features:** 2

Visual 16/32-step sequencer with per-track control and pattern matrix overview.

## Hotelsinus Step Sequencer

**Keybinding:** `Global:Paketti:Hotelsinus Step Sequencer` ⌨️

Opens comprehensive step sequencer interface with visual grid.

**Dialog Features:**

### Step Count Selection
- **16 Steps** - Classic 1-bar sequencing
- **32 Steps** - Extended 2-bar sequencing
- Switch instantly - dialog recreates

### Pattern Matrix Overview
- **Visual Grid** - Shows current pattern
- **Track Status** - Which tracks have data
- **Color Coding:**
  - Filled square: Track has notes
  - Empty square: Track is silent
- **Real-time Updates** - Refreshes as you work

### Per-Track Controls

**Each track row has:**
- **Track Number** - T01, T02, etc.
- **Note** - Valuebox (C-0 to B-9)
- **Instrument** - Valuebox (1-max instruments)
- **Velocity** - Valuebox (0-127)
- **16/32 Checkboxes** - Step grid
- **Clear Button** - Erase track

### Step Grid
- **Checkboxes** - Click to toggle notes
- **Visual Highlighting** - Every 4th step highlighted
- **Real-time Preview** - Hear as you click
- **Immediate Writing** - Updates pattern instantly

### Global Controls
- **Fetch Pattern Data** - Reload from current pattern
- **Clear All** - Erase all tracks
- **Step Count Toggle** - Switch 16/32

## Hotelsinus Matrix Overview

**Keybinding:** `Global:Paketti:Hotelsinus Matrix Overview` ⌨️

Standalone pattern matrix viewer.

**Features:**
- Shows current pattern only
- All sequencer tracks displayed
- 8x8 pixel indicators per track
- Automatic refresh (250ms interval)
- Minimal CPU usage

**Display:**
- **Header Row** - Track numbers
- **Data Row** - Pattern status
- **Bitmaps** - Visual indicators
- **Tooltips** - Track names + pattern

## Step Sequencer Workflow

### Basic Drum Programming
```
1. Open Step Sequencer
2. Track 1: Kick (C-4, Inst 01, Vol 127)
3. Check steps: 1, 5, 9, 13
4. Track 2: Snare (D-4, Inst 01, Vol 100)
5. Check steps: 5, 13
6. Track 3: Hi-hat (F#4, Inst 01, Vol 80)
7. Check steps: 3, 7, 11, 15 (offbeats)
8. Result: Classic drum groove
```

### Melodic Sequencing
```
1. Set track to 16 steps
2. Note: C-4, Instrument: Bass
3. Click pattern: X__X__X__X__X__X
4. Change note to G-3
5. Click different steps
6. Build bass line
```

### Pattern Variations
```
1. Create pattern in steps 1-16
2. Switch to 32 steps
3. Steps 1-16 stay same
4. Add variation in steps 17-32
5. A/B sections in one pattern
```

### Quick Fills
```
1. Load pattern data
2. Tracks already have notes
3. Add fills on empty steps
4. Instant drum variations
5. No manual editing
```

### Euclidean-Style Patterns
```
Track 1: X___X___X___X___ (every 4)
Track 2: X__X__X__X__X___ (every 3.2)
Track 3: X_X_X_X_X_X_X_X_ (every 2)
→ Polyrhythmic patterns
```

## Advanced Features

### Pattern Data Loading
- **Auto-Load** - Reads existing pattern on open
- **Preserves Notes** - Maintains pitch/instrument
- **Smart Defaults** - Uses current instrument if empty
- **Slice-Aware** - Handles sliced instruments

### Per-Track Settings
- **Independent Controls** - Each track separate
- **Volume Curves** - Different velocities per track
- **Instrument Switching** - Change instruments on-the-fly
- **Note Ranges** - Full keyboard range

### Real-Time Updates
- Changes write immediately to pattern
- No "apply" button needed
- Hear changes instantly
- Works during playback

### Matrix Integration
- Shows pattern status
- Visualizes track usage
- Helps planning
- Complements sequencer

## Technical Details

### Grid System
- 16 or 32 checkbox columns
- Adjustable checkbox size (28px)
- Compact valuebox width (62px)
- Efficient layout

### Pattern Integration
- Direct pattern line access
- Note column manipulation
- Instrument/volume writing
- Compatible with all Renoise features

### UI Design
- **Group Style** - Clean borders
- **Bold Headers** - Easy reading
- **Color Highlights** - Visual rhythm guides
- **Tooltips** - Helpful hints

### Performance
- Lightweight checkbox system
- Fast pattern writing
- Smooth UI updates
- Works with large projects

## Use Cases

**Live Performance:**
```
- Pre-program patterns
- Toggle steps in real-time
- Quick variations
- No mouse needed (keybinding)
```

**Beat Making:**
```
- Visual drum programming
- See whole pattern at once
- Easy euclidean rhythms
- Fast workflow
```

**Learning Tool:**
```
- Understand step sequencing
- Visual rhythm representation
- Experiment with patterns
- See note relationships
```

**Experimental:**
```
- 32-step polyrhythms
- Unusual time signatures
- Generative ideas
- Random toggling
```

---


---

# Unison Generator

**Source:** `PakettiUnisonGenerator.lua` | **Features:** 1

Creates rich unison sounds by generating 8-voice polyphonic instruments with intelligent detuning and voice distribution.

## Paketti Unison Generator

**Keybinding:** `Global:Paketti:Paketti Unison Generator` ⌨️

Creates an 8-voice unison instrument from the selected sample with advanced detune options.

**Core Functionality:**
- Creates 8 copies of selected sample
- Intelligent voice distribution (alternating L/R panning)
- Multiple detune modes for different unison characters
- Preserves or duplicates pakettified instruments
- Automatic volume compensation (-18dB per voice)

**Detune Modes:**

1. **Fixed Detune** (Default)
   - Evenly distributed across unison range
   - Centered around sample 5
   - Predictable, stable detuning

2. **Hard Sync** (`pakettiUnisonDetuneHardSync`)
   - Alternating negative/positive offsets
   - Even samples: negative detune
   - Odd samples: positive detune
   - Creates strong stereo phasing

3. **Fluctuation** (`pakettiUnisonDetuneFluctuation`)
   - Random detune per voice
   - Creates organic, living sound
   - Different each time

**Voice Layout:**
- Voice 1 (center): Original sample, center pan
- Voices 2-8: Alternating L/R panning
- Sample 2, 4, 6, 8: Hard left (0.0)
- Sample 3, 5, 7: Hard right (1.0)

**Fractional Shifting:**
- Applies phase offset to samples 2-8
- Creates comb-filtering effects
- Fractions: 1/8, 2/8, 3/8... 7/8
- Skipped for samples > 500,000 frames (performance)

**Special: Wavetable Mode**

Automatically detected when instrument has:
- 2 samples routed to different FX chains (1→1, 2→2)
- OR samples named "PCM Wave A" and "PCM Wave B"

**Wavetable Mode Features:**
- Creates 5 copies each of Wave A and Wave B
- Total: 12 samples (2 original + 5A + 5B)
- Fifths fractions (1/5, 2/5, 3/5, 4/5)
- Maintains separate FX chain routing
- Volume: -21.5dB (adjusted for 12 voices)

**Pakettified Instrument Handling:**

If `pakettiUnisonDuplicateInstrument` is enabled AND instrument is pakettified:
- Duplicates entire instrument (plugins, FX, macros, phrases)
- Preserves external plugin editor state
- Updates *Instr. Macros devices to point to new instrument
- Only selected sample is processed for unison

**Detection of Pakettified Instruments:**
- Has plugin loaded
- Has Volume AHDSR device
- Has assigned macros

**Sample Configuration:**
- Loop mode: Forward (2)
- Interpolation: From preferences
- Oversample: From preferences
- Autofade: From preferences

**Naming Convention:**
- Format: `<sample_name> (Unison <n> [<detune>] (<pan>))`
- Example: "Saw (Unison 3 [12] (50R))"

**Phrase Preservation:**
- Copies all phrases from original instrument
- Maintains phrase data integrity
- Restores selected phrase index after processing

**Technical Details:**
- Temporarily disables 0G01 Loader
- Temporarily disables AutoSamplify Pakettify
- Clamps detune to -127 to +127 range
- Assigns samples to device chain 1 (if available)

**Use Cases:**
- Analog-style supersaw sounds
- Rich pads and strings
- Chorus/ensemble effects
- Wide stereo leads
- Layered bass sounds

---

# Paketti 8120 Groovebox

**Source:** `PakettiEightOneTwenty.lua` | **Features:** ~150+

Complete groovebox-style sequencer interface with 8 rows of 16/32-step patterns, per-row instrument selection, real-time recording, pitch control, and advanced beat sync integration.

## Paketti 8120 Dialog

**Keybinding:** `Global:Paketti:Paketti 8120...` ⌨️

Opens the main 8120 Groovebox interface - an 8-row x 16/32-step sequencer with comprehensive per-row controls.

**Core Architecture:**
- 8 independent sequencer rows
- 16 or 32 steps per row (switchable)
- Per-row track + instrument assignment
- Per-row pattern controls
- Per-row sample recording
- Global and per-row pitch controls
- Advanced Beatsync + NNA integration

**Main Interface Sections:**

### 1. Row Controls (8 rows)

Each row has:
- **Row Number** (01-08) with selection highlighting
- **Track Popup** - Select destination track
- **Instrument Popup** - Select instrument for this row
- **Pattern Popup** - Select pattern destination
- **Volume Slider** - Per-row volume (0.0-4.0)
- **Delay Slider** - Per-row delay (0-255)
- **Transpose Slider** - Per-row transpose (-48 to +48)
- **Record Button** - 3-phase recording (Arm → Record → Stop)

### 2. Step Grid (16 or 32 steps)

Each step button:
- **Toggle state** - On/Off
- **Group style** when active
- **Body style** when inactive
- Immediate visual feedback

### 3. Row Action Buttons

Per-row operations:
- **Write** - Write pattern to selected line
- **Fetch** - Load pattern from selected line
- **Clear** - Clear all steps in row
- **Copy** - Copy row pattern
- **Paste** - Paste row pattern
- **Nudge +/-** - Shift pattern left/right
- **Reverse** - Reverse step order
- **Random** - Randomize steps

### 4. Global Controls

**Top Panel:**
- **16 Steps / 32 Steps** switch
- **BPM Display** (live updating)
- **Instruments List** dropdown
- **Select Row** buttons (01-08)
- **Show Advanced** toggle (Beatsync + NNA panel)

**Global Actions:**
- **Write All 8 Rows** - Write entire pattern
- **Fetch All 8 Rows** - Load entire pattern
- **Load 8 Sequential Rows** - Load 8 consecutive rows
- **Clear All Rows** - Reset all patterns
- **Close** button

### 5. Advanced Panel (Beatsync + NNA)

Per-row Beatsync controls:
- **Beatsync Checkbox** - Enable/disable beat sync
- **Beatsync Lines** - Number of lines (1-512)
- **Beatsync Mode** popup:
  - Percussive
  - Repitch
  - Texture

Per-row NNA (New Note Action) controls:
- **NNA Mode** popup:
  - Note-Off
  - Continue
  - Cut

### 6. Global Pitch Control

Two modes for global pitch adjustment:

**Absolute Mode** (`Global Pitch (Abs)` button):
- Single reference baseline for all rows
- Consistent pitch offsets across rows
- Uses `gbx_global_pitch_midi_prev_abs`

**Relative Mode** (default):
- Per-row pitch baselines
- Independent pitch offsets per row
- Uses `gbx_transpose_baseline[row]`

### 7. Recording Features

**3-Phase Recording Per Row:**

**Phase 0 (Idle):**
- Press Record → Phase 1
- Opens sample recorder dialog
- Maintains keyboard focus

**Phase 1 (Armed):**
- Press Record → Phase 2
- Starts recording
- Stores previous sample count

**Phase 2 (Recording):**
- Press Record → Phase 0
- Stops recording
- Automatically:
  - Finds new sample
  - Maps velocity 00-7F to new sample
  - Maps velocity 00-00 to other samples
  - Enables autoseek + autofade
  - Selects new sample

### 8. Pattern Write/Fetch

**Write Logic:**
- Converts steps to pattern notes
- Uses edit step from preferences
- Respects row delay + transpose
- Applies per-row volume
- Uses selected track + instrument

**Fetch Logic:**
- Reads notes from pattern
- Converts to step positions
- Preserves row configuration
- Updates step buttons

**Multi-Row Write:**
- Writes 8 rows sequentially
- Advances edit position between rows
- Can write to different patterns per row

**Sequential Load:**
- Loads 8 consecutive rows from pattern
- Auto-increments row position
- Maintains per-row separation

### 9. Step Manipulation

**Per-Row Operations:**

**Nudge Left:**
- Shifts all steps left
- Wraps first step to end

**Nudge Right:**
- Shifts all steps right
- Wraps last step to start

**Reverse:**
- Reverses step order
- Maintains step count

**Random:**
- Randomizes step on/off state
- Uses `trueRandomSeed()`

**Clear:**
- Clears all steps in row
- Resets visual state

### 10. Beatsync Integration

**Real-Time Observation:**
- Attaches to sample observables
- Updates UI when sample changes
- Tracks primary sample (velocity 00-7F)
- Detaches/reattaches on instrument change

**Primary Sample Detection:**
- Finds sample with velocity range 00-7F
- Falls back to sample 1 if not found
- Updates Beatsync controls for correct sample

**Observable Management:**
- `beat_sync_enabled_observable`
- `beat_sync_lines_observable`
- Prevents feedback loops with `beatsync_updating[i]` flag

### 11. Keyboard Navigation

**Arrow Keys:**
- **Up/Down** - Navigate rows
- **Left/Right** - Navigate steps
- Wraps at boundaries
- Visual highlighting follows

**Enter Key:**
- Toggles current step on/off

**Space Key:**
- Toggles current step on/off (alternative)

**Escape:**
- Closes dialog

### 12. MIDI Integration

**Global Pitch MIDI:**
- `Global:Paketti:8120 Global Pitch+` (CC increase)
- `Global:Paketti:8120 Global Pitch-` (CC decrease)
- Applies to all rows simultaneously

### 13. Memory Management

**Per-Row State:**
- `gbx_record_phase[1-8]` - Recording state
- `gbx_prev_sample_count[1-8]` - Sample count tracking
- `gbx_record_instrument_index[1-8]` - Target instrument
- `gbx_transpose_baseline[1-8]` - Per-row pitch baseline

**Global State:**
- `gbx_global_pitch_ui_prev_value` - UI pitch value
- `gbx_global_pitch_midi_prev_abs` - Absolute pitch baseline
- `sequential_load_current_row` - Row cursor for sequential load

### 14. Pattern Length Support

**Configurable Steps:**
- 16-step mode: Fits 1 bar at LPB 4
- 32-step mode: Fits 2 bars at LPB 4 or 1 bar at LPB 8

**Dynamic Switching:**
- Change step count via switch
- Dialog recreates with new layout
- Preserves row patterns where possible

### 15. Technical Features

**Observable Cleanup:**
- BPM observer (updates display)
- Instruments list observer (refreshes dropdown)
- Beatsync observers per row
- All properly detached on dialog close

**Sample Mapping:**
- Velocity split: 00-7F for primary, 00-00 for others
- Ensures one-shot operation
- Prevents sample bleed

**Edit Step Handling:**
- Reads from `song.transport.edit_step`
- Advances by edit step after each note
- Supports various edit step values

**Volume Handling:**
- Range: 0.0 to 4.0 (linear)
- Default: 1.0 (unity gain)
- Applied per note when writing

**Delay Column:**
- Range: 0-255 (hex 00-FF)
- Applied per note when writing
- Automatically shows delay column if hidden

---
> *The Paketti 8120 Groovebox — 150+ features that rival hardware costing hundreds of euros.*
> *Built and maintained through community support. [Join on Patreon →](http://patreon.com/esaruoho)*
---

# Merge Instruments

**Source:** `PakettiMergeInstruments.lua` | **Features:** 1

Merges samples and keymaps from one instrument to another with validation and safety checks.

## Paketti Merge Instruments Dialog

**Keybinding:** `Global:Paketti:Paketti Merge Instruments...` ⌨️

**Menu:** `Instrument Box:Paketti..:Merge Instruments...` 📋

Opens dialog to merge samples from source instrument to target instrument.

**Dialog Features:**
- **Source Instrument** valuebox (hex display)
- **Target Instrument** valuebox (hex display)
- **Instrument Name** display for both
- **Merge** button

**Merge Process:**
1. Validates source and target indices
2. Checks target doesn't have slices
3. Copies each sample with full properties:
   - Sample buffer data
   - Loop points
   - Panning
   - Volume
   - Transpose
   - Fine tune
   - Interpolation mode
   - All other sample properties

4. Copies sample mapping overlap mode
5. Shows status with sample count

**Safety Checks:**
- Cannot merge if target has slice markers
- Skips empty samples in source
- Validates sample count

**Debug Output:**
- Logs sample details (name, frames, channels, rate, bit depth)
- Verifies copy success
- Reports frame count mismatches

**Use Cases:**
- Combining drum kits
- Merging sample collections
- Consolidating instruments

---

# Switcharoo (Chord Reharmonization)

**Source:** `PakettiSwitcharoo.lua` | **Features:** 1

Advanced chord progression reharmonization tool with voicing, inversion, circle of fifths transposition, and intelligent chord extension system.

## Paketti Switcharoo Dialog

**Keybinding:** `Global:Paketti:Paketti Switcharoo...` ⌨️

Opens the Switcharoo chord reharmonization interface.

**Core Concept:**
- Reads chord progressions from pattern
- Applies transformations per chord
- Real-time audition of original and transformed chords
- Replace chords in-place at original positions

**Interface Layout:**

### Top Controls

- **Read from Pattern (Ctrl+R)** - Scan current track for chords
- **Reset All** - Reset all transformations to 0
- **Close** button

**Navigation Help:**
- Up/Down = select slot
- Left = play original
- Right = play processed
- Enter = switcharoo (replace)
- Esc = stop

### Slot Grid (16 rows)

Each row shows:
1. **Slot Number** (01-16)
2. **Original Notes** - Chord as read from pattern
3. **Voice** control (-5 to +5)
4. **Invert** control (-6 to +6)
5. **CoF** control (-6 to +6, Circle of Fifths)
6. **Complex** control (0-12, chord extensions)
7. **Min** octave (0-9)
8. **Max** octave (0-9)
9. **Resultant Notes** - Transformed chord
10. **Aud** button - Audition transformed chord
11. **Switch** button - Replace in pattern

### Transformation Parameters

**1. Voicing (-5 to +5)**

Randomly shifts notes by octaves with octave range limits:
- Positive = more variety
- Negative = more variety (opposite seed)
- 0 = no voicing changes
- Uses value as randomization seed for consistency

**Adjustments:**
- -24 semitones (-2 octaves)
- -12 semitones (-1 octave)
- +12 semitones (+1 octave)
- +24 semitones (+2 octaves)

Notes outside octave range are relocated to valid octaves.

**2. Inversion (-6 to +6)**

Chord inversions - fully reversible:
- Positive: Move lowest note up octaves
- Negative: Move highest note down octaves
- 0 = root position
- Preserves pitch classes (note identities)

**Example (C major triad):**
- 0: C E G (root position)
- +1: E G C (first inversion)
- +2: G C E (second inversion)
- -1: G C E (same as +2)

**3. Circle of Fifths (-6 to +6)**

Transposes entire chord by perfect fifths:
- Each step = 7 semitones
- Positive: up the circle (C→G→D→A→E→B)
- Negative: down the circle (C→F→Bb→Eb→Ab)

**Examples:**
- +1: Up perfect fifth (C→G, D→A)
- +2: Up 2 fifths (C→D, 14 semitones)
- -1: Down perfect fifth (C→F, 7 semitones down)

**4. Complexity (0-12)**

Intelligent chord extensions based on detected chord quality.

**Chord Quality Detection:**
- Analyzes intervals from root
- Detects: major, minor, major7, minor7, dominant7, augmented, diminished

**Level 0:** No extensions (original chord)

**Level 1:** Add 7th
- Major/augmented: Major 7th (+11 semitones)
- Minor: Minor 7th (+10 semitones)
- Diminished: dim7 (+9 semitones)
- Default: Minor 7th (dominant sound)

**Level 2:** Add 9th
- Major 9th (+14 semitones) for all chord types

**Level 3:** Add 11th or #11
- Major/dominant7: #11 (+18 semitones, avoids clash with major 3rd)
- Minor: Perfect 11th (+17 semitones)

**Level 4:** Add alterations/13th
- Dominant7: #9 (+15 semitones, altered dominant)
- Others: 13th (+21 semitones)

**Level 5:** More alterations
- Dominant7: b5 (+6 semitones, tritone sub flavor)
- Others: b9 (+16 semitones, tension)

**Level 6:** Augmented 5th or b13
- Dominant7/major7: #5 (+8 semitones)
- Others: b13 (+20 semitones)

**Level 7:** Advanced alterations
- Dominant7: #13 (+22 semitones)
- Others: b11 (+16 semitones) for minor

**Level 8:** Upper structure triads
- Major triad from b7
- Adds: b7, 9th, 11th

**Level 9:** Polychordal elements
- Tritone substitution chord tones
- Adds: b2 (+1), b6 (+7)

**Level 10:** Maximum alterations
- All chromatic neighbors
- Adds: b9, #9, alternate b13 octave

**Level 11:** Extreme extensions
- Double alterations
- Adds: major 2nd, perfect 4th, b7 up octave

**Level 12:** Chromatic saturation
- Fills remaining chromatic spaces
- Adds: minor 3rd variation, major 6th, octave reinforcement

**5. Min/Max Octave (0-9)**

Octave range constraints:
- All transformed notes clamped to this range
- Min must be ≤ Max (auto-corrected)
- Default: 0-7 (C-0 to B-7)

Notes outside range are relocated to nearest valid octave for their pitch class.

### Reading from Pattern

**Scan Process:**
- Scans all lines in selected track
- Reads all note columns (up to 12)
- Creates slot for each line with notes
- Stores original line position
- Maximum 16 slots

**Chord Detection:**
- Looks for 2+ simultaneous notes (chords)
- Also captures single notes
- Ignores OFF notes
- Stores as note strings (e.g., "C-4", "E-4", "G-4")

### Audition System

**Original Audition (Left Arrow):**
- Plays original chord as read from pattern
- Stops transformed if playing
- Toggle: press again to stop

**Transformed Audition (Right Arrow):**
- Plays transformed chord
- Stops original if playing
- Toggle: press again to stop

**Audition Buttons:**
- Text changes: "Aud" / "Stop"
- Plays until stopped or new audition starts

**MIDI Note Triggering:**
- Uses `trigger_instrument_note_on()`
- Selected instrument + track
- Velocity: 1.0
- Automatic note-off on stop

**Duplicate Note Handling:**
- Removes duplicate note values before triggering
- Prevents "notes must be unique" errors

### Switcharoo (Replace)

**Replace Process:**
1. Gets transformed chord for selected slot
2. Finds original line position
3. Clears existing notes in line
4. Writes transformed notes
5. Sets instrument index
6. Ensures enough visible columns

**Smart Note-Off Logic:**
- If transformed has MORE notes than original:
  - Places note-offs in line BEFORE
  - Prevents stuck notes

**Pattern End Handling:**
- Places note-offs on last pattern line
- Prevents endless sustain

**Status Message:**
- Shows slot number, line position, note count

### Keyboard Controls

**Up Arrow:** Select previous slot

**Down Arrow:** Select next slot

**Left Arrow:** Audition original chord (toggle)

**Right Arrow:** Audition transformed chord (toggle)

**Enter:** Replace chord in pattern (switcharoo)

**Escape:** Stop any playing audition

**Ctrl+R:** Read chords from pattern

### Auto-Grab Preference

If `preferences.pakettiSwitcharooAutoGrab.value` is enabled:
- Automatically reads pattern on dialog open

### Music Theory Details

**Root Finding Algorithm:**
- Analyzes all pitch classes in chord
- Scores each potential root based on:
  - Presence of root (0): +10
  - Major 3rd (+4): +8
  - Minor 3rd (+3): +8
  - Perfect 5th (+7): +6
  - Minor 7th (+10): +4
  - Major 7th (+11): +4
  - Penalties for dissonant intervals

**Chord Quality Analysis:**
- Checks for characteristic intervals
- Determines: major, minor, major7, minor7, dominant7, augmented, diminished, unknown

**Extension Placement:**
- Extensions added from higher octave than highest existing note
- Prevents muddy low register extensions
- Checks for duplicate pitch classes
- Skips already-present extensions

### UI Features

**Selected Row:**
- Original/Resultant text in bold ("strong" style)
- Non-selected rows use "normal" style

**Active Buttons:**
- Buttons only active for slots with content
- Grayed out for empty slots

**Real-Time Updates:**
- Transformations apply immediately
- Resultant notes update live

### Technical Details

**Maximum Rows:** 16 (const `PakettiSwitcharoo_MAX_ROWS`)

**Note Range:** 0-119 (C-0 to B-9)

**State Variables:**
- `PakettiSwitcharoo_sequences` - Original chords
- `PakettiSwitcharoo_transformed_sequences` - Processed chords
- `PakettiSwitcharoo_original_line_positions` - Line positions
- `PakettiSwitcharoo_selected_slot` - Current slot
- `PakettiSwitcharoo_current_audition_slot` - Playing slot
- `PakettiSwitcharoo_current_audition_type` - "original" or "transformed"

**Transformation Order:**
1. Voicing (octave shifts with range limits)
2. Inversion (chord inversions)
3. Circle of Fifths (transposition)
4. Complexity (chord extensions)
5. Final octave clamping

**Use Cases:**
- Jazz reharmonization
- Chord progression experimentation
- Modal interchange
- Tension/release adjustments
- Voice leading exploration
- Polychordal composition

---

# YT-DLP Downloader

**Source:** `PakettiYTDLP.lua` | **Features:** 1

YouTube and multi-platform audio downloader integration using yt-dlp, with automatic import to Renoise instruments.

## Paketti YT-DLP Downloader

**Keybinding:** `Global:Paketti:Paketti YT-DLP Downloader` ⌨️

Opens comprehensive YouTube/audio downloader dialog with yt-dlp integration.

**Supported Platforms:**
- YouTube
- Twitter
- Facebook
- SoundCloud
- Bandcamp
- Instagram
- Any site supported by yt-dlp

**OS Support:**
- macOS (Apple Silicon + Intel)
- Linux
- Windows: Not currently supported

**Dialog Interface:**

### Input Fields

**Search Phrase:**
- Enter search term for YouTube search
- Searches 30 videos, picks random one
- Auto-starts download on Enter

**URL:**
- Direct URL to download
- Auto-sanitizes common URL issues
- Detects timestamps in URLs
- Auto-starts download on Enter

**Output Directory:**
- Where downloaded files are saved
- Browse button to select folder
- Temp folder created automatically: `<output>/tempfolder/`
- Opens path in Finder/file manager

**YT-DLP Location:**
- Path to yt-dlp executable
- Auto-detected on startup:
  - macOS: `/opt/homebrew/bin/yt-dlp`, `/usr/local/bin/yt-dlp`, `/usr/bin/yt-dlp`
  - Linux: `/usr/bin/yt-dlp`, `/usr/local/bin/yt-dlp`, `/home/linuxbrew/.linuxbrew/bin/yt-dlp`, `/snap/bin/yt-dlp`
- Browse to select manually if not found

### Download Options

**Loop Mode** (popup):
- Off
- Forward
- Backward
- PingPong

**Amount of Searched Videos:**
- Range: 1-100
- How many results to search through

**Download Whole Video as Audio:**
- Always enabled (checkbox shown for reference)
- Downloads full audio of video
- WAV format output

**Create New Instrument for Each Downloaded Audio:**
- If enabled: New instrument per download
- If disabled: Adds to current instrument

### Save Options

**Save Successfully Downloaded Audio:**
- **Off** - Don't save outside Renoise
- **Save WAV** - Also save as WAV to specified path
- **Save FLAC** - Also save as FLAC to specified path

**Save Path:**
- Directory for saving WAV/FLAC copies
- Browse button

### Status and Progress

**Status Text:**
- "Ready" when idle
- "Downloading: XX%" during download
- "ETA X:XX at X.XMiB/s" with detailed progress
- "Extracting Audio..." when converting
- "Processing stream..." for live streams

**Cancel Button:**
- Active during download
- Stops current download process

**Log Output:**
- Multiline text field showing:
  - Search results
  - Download progress
  - File operations
  - Errors and warnings
- Auto-scrolls to latest output
- Clear button

### Process Flow

**For Search:**
1. Enters search phrase
2. Searches YouTube for 30 results
3. Lists found videos with IDs
4. Picks random video
5. Downloads audio
6. Converts to WAV
7. Imports to Renoise

**For Direct URL:**
1. Enters URL
2. Auto-sanitizes (fixes missing 'h' in https://)
3. Downloads full audio
4. Converts to WAV
5. Imports to Renoise

### Automatic Import to Renoise

**Import Process:**
1. Downloads to temp folder
2. Converts to WAV format
3. Waits for download completion signal
4. Loads WAV files asynchronously (200ms between samples)
5. Sets sample names from filenames
6. Applies loop mode from preferences
7. Removes placeholder samples
8. Moves files to final output directory
9. Switches to Sample Editor view

**Async Sample Loading:**
- Loads one sample at a time
- 200ms delay between samples
- Prevents UI freezing
- Progress shown in status

**AutoSamplify Integration:**
- Temporarily disables AutoSamplify monitoring during import
- Restores state after import completes

**XRNI Template:**
- If `preferences.pakettiPitchbendLoaderEnvelope.value` enabled:
  - Loads default XRNI template via `pakettiPreferencesDefaultInstrumentLoader()`
  - Applies loader modulation settings

### URL Sanitization

**Auto-Fixes:**
- Missing 'h' prefix: `ttps://` → `https://`
- Updates URL field automatically

### Timestamp Detection

**Supported Formats:**
- `?t=47` (YouTube short links)
- `&t=45s` (YouTube full URLs)
- `?t=2m30s` (minutes + seconds)
- `#t=120` (fragment format)

**Parsing:**
- Converts time strings to seconds
- Supports: `47s`, `2m30s`, `1h2m30`
- Uses section parameter: `*<seconds>-inf`
- Falls back to `*from-url` if parsing fails

### Chapter Detection

**Features:**
- Checks if video has chapters
- Logs chapter titles
- Shows first chapter title
- Can download specific chapters (experimental)

### File Management

**Filename Sanitization:**
- Allows only: A-Z, a-z, 0-9, hyphens, underscores
- Preserves file extension
- Removes special characters

**Temp Folder:**
- `<output_directory>/tempfolder/`
- Stores intermediate files
- Cleaned up after import

**Completion Signal:**
- `download_completed.txt` file
- Created when download finishes
- Triggers import process
- Removed after import

### ffmpeg Integration

**Auto-Detection:**
- macOS: `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, `/usr/bin/ffmpeg`
- Linux: `/home/linuxbrew/.linuxbrew/bin/ffmpeg`, `/usr/bin/ffmpeg`, `/usr/local/bin/ffmpeg`

**Used For:**
- Audio extraction from video
- Format conversion to WAV

### yt-dlp Command Structure

**Basic Command:**
```bash
cd "<temp_dir>" && \
"<yt-dlp_path>" \
--extract-audio \
--audio-format wav \
"<url>"
```

**Environment:**
- macOS: `env PATH=/opt/homebrew/bin:$PATH`
- Linux: Uses system PATH

**Output:**
- Extracts audio only
- Converts to WAV
- Saves to temp directory

### Process Slicing

**For Search Queries:**
- Uses `ProcessSlicer` for UI responsiveness
- Yields during search results parsing
- Shows progress counter: "Found video 01/30"

**For Direct URLs:**
- Direct command execution
- Timer-based progress updates (200ms)
- Real-time output parsing

### Preferences Storage

All settings saved to preferences:
- `PakettiYTDLPOutputDirectory`
- `PakettiYTDLPLoopMode`
- `PakettiYTDLPAmountOfVideos`
- `PakettiYTDLPNewInstrumentOrSameInstrument`
- `PakettiYTDLPFormatToSave`
- `PakettiYTDLPPathToSave`
- `PakettiYTDLPYT_DLPLocation`

### Error Handling

**Common Errors:**
- yt-dlp not found → Prompts for location
- Output directory not set → Prompts for path
- Save path needed for WAV/FLAC → Prompts for path
- Download failed → Shows error in log
- No videos found → Status message

**Process Recovery:**
- Failed downloads don't hang UI
- Completion timer stops on error
- Can retry immediately

### Technical Details

**Process Timer:** 100ms check for completion file

**Progress Timer:** 200ms read of process output

**Sample Load Timer:** 200ms between samples

**Output Filtering:**
- Shows only essential output
- Hides debug/verbose messages
- Filters duplicate progress lines

**Path Handling:**
- Cross-platform separator detection
- Proper path escaping for shell commands

**Use Cases:**
- Sample pack creation from YouTube tutorials
- Grabbing audio from SoundCloud releases
- Importing reference tracks
- Building drum kits from Instagram samples
- Getting acapellas from Twitter posts

---

# Tuplet Generator

**Source:** `PakettiTupletGenerator.lua` | **Features:** 1

Visual tuplet and polyrhythm pattern generator with real-time preview and automatic pattern writing.

## Paketti Tuplet Writer Dialog

**Keybinding:** `Global:Paketti:Paketti Tuplet Writer Dialog...` ⌨️

Opens tuplet pattern generator with visual preview and instant pattern writing.

**Core Concept:**
- Divide N rows into M notes using delay column
- Visual representation of tuplet patterns
- Instant write to pattern
- Supports 1-8 notes per pattern

**Dialog Layout:**

### Input Fields

**Note Count:**
- Number of notes to fit in the pattern
- Range: 1 to row count
- Text field with validation

**Row Count:**
- Total pattern length in rows
- Range: 1 to 512
- Text field with validation

**Ticks per Line:** (Display only)
- Shows LPB value
- Reference for delay calculation

**Highlight:** (Display only)
- Pattern editor highlight value
- Visual reference

### Pattern Preview

**Visual Display:**
- Shows exact pattern as it will be written
- Format: `C-4 XX` or `--- XX`
- Mono font for alignment
- Updates in real-time

**Delay Values:**
- Shown in hex (00-FF)
- Calculated based on note count
- Formula: `floor((position - 1) * 255 / total_notes)`

### Action Buttons

**Print:**
- Writes pattern to current cursor position
- Uses current instrument
- Shows delay column if hidden

**Print when switch changes:**
- Checkbox (default: ON)
- Auto-writes on switch selection
- Auto-writes on note count change

**Tuplet Switch:**
- 8 buttons for common tuplet patterns
- Instant visual feedback
- Auto-selection updates pattern

**Print Delay Values Only:**
- Checkbox (default: OFF)
- When enabled: writes only delay values (`--- XX`)
- When disabled: writes notes + delay (`C-4 XX`)

**Auto flood fill after printing:**
- Checkbox (default: OFF)
- Calls `floodfill_with_selection()` after print
- Fills rest of track with pattern

**Jump to below selection:**
- Checkbox (default: OFF)
- Moves cursor after pattern
- Wraps to line 1 if exceeding pattern length

### Tuplet Presets (Switch)

**1. Single** (1 note)
- First row only
- No delays

**2. Quarter** (2 notes)
- First row + middle row
- No delays

**3. Triplets** (3 notes)
- First row, then delayed notes
- Classic triplet feel

**4. Eighth** (4 notes)
- Evenly spaced across rows
- Four equal divisions

**5. Quintuplets** (5 notes)
- First row + 4 delayed notes
- 5-note grouping

**6. Sextuplets** (6 notes)
- Two triplets
- First row + 5 delayed notes

**7. Septuplets** (7 notes)
- First row + 6 delayed notes
- 7-note grouping

**8. Sixteenth** (8 notes)
- Evenly spaced across rows
- Eight equal divisions

### Pattern Writing

**Write Process:**
1. Validates note count ≤ row count
2. Sets selection in pattern (start to end line)
3. Clears selected area
4. Writes notes with delays:
   - Note column: C-4 (or empty if delays only)
   - Instrument: Current selected instrument
   - Delay column: Calculated hex value
5. Shows delay column if hidden
6. Optionally jumps to next position

**Selection Management:**
- Sets pattern selection before writing
- Highlights affected area
- Selection range: `start_line` to `min(start_line + row_count - 1, 512)`

**Delay Column:**
- Automatically shown if hidden
- Enabled per track

### Tuplet Calculation

**Formula:**
```lua
delay = floor((position - 1) * 255 / total_notes)
```

**Examples:**

**Triplets (3 notes in 8 rows):**
- Row 1: C-4 -- (position 1, no delay)
- Row 3: C-4 AA (position 2, delay 85)
- Row 6: C-4 55 (position 3, delay 170)

**Quintuplets (5 notes in 8 rows):**
- Row 1: C-4 -- (position 1)
- Row 2: C-4 33 (position 2, delay 51)
- Row 3: C-4 66 (position 3, delay 102)
- Row 4: C-4 99 (position 4, delay 153)
- Row 5: C-4 CC (position 5, delay 204)

**Sixteenth Notes (8 notes in 8 rows):**
- All rows: C-4 -- (evenly spaced, no delays needed)

### Special Pattern Layouts

**6 Notes (Sextuplets):**
- Two groups of triplets
- Rows 1-3: First triplet
- Rows 5-7: Second triplet

**7 Notes (Septuplets):**
- All 7 notes in sequence
- Calculated delays for each

### Validation

**Auto-Correction:**
- If note count > row count: caps to row count
- If note count < 1: sets to 1
- If row count < 1: sets to 1

**Display Updates:**
- Corrected values shown immediately
- Pattern preview updates

### Keyboard Focus

**Auto-Focus:**
- Note count field selected on open
- Edit mode enabled
- Ready for immediate input

**Enter Key:**
- In text field: regenerates pattern
- Refocuses on Pattern Editor

### Use Cases

- **Triplet feels:** 3 notes in 4/8/16 rows
- **Quintuplet runs:** 5-note patterns
- **Polyrhythms:** Odd divisions (3 over 4, 5 over 8)
- **Swing patterns:** 2 notes with first row + delayed second
- **Complex rhythms:** 7-note patterns
- **Delay-only automation:** Modulation without notes


---

# Amigo Sampler Integration

**Source:** `PakettiAmigoInspect.lua` | **Features:** 5

Complete integration with PotenzaDSP Amigo Sampler plugin - extract, import, analyze, and modify embedded sample files and paths within Amigo presets.

**Prerequisites:**
- macOS only (uses `plutil`)
- `base64.lua` module (included)
- PotenzaDSP Amigo plugin (AU/VST3)

## Core Features

### 1. Decode Active Plugin ParameterChunk

Analyzes and displays the internal structure of Amigo presets.

**Process:**
1. Reads active preset data from plugin
2. Decodes base64 ParameterChunk
3. Converts binary plist to XML via `plutil`
4. Extracts JUCE plugin state
5. Parses JUCE parameter structure
6. Displays:
   - JUCE magic ("PARAMS")
   - Version number
   - All parameter entries
   - Pathname entries
   - WAV file locations
   - Sample data locations

**Output:**
- Console logging with hex dumps
- First 64 bytes of chunks
- Parameter structure analysis
- WAV header information

### 2. Load Embedded Sample to New Instrument

**Keybinding:** `Global:Paketti:Paketti Load Amigo Sample to New Instrument` ⌨️

**Menu:** `Instrument Box:Paketti Amigo Sampler:Load Embedded Sample to New Instrument` 📋

Extracts embedded sample from Amigo preset and loads it into a new Renoise instrument.

**Extraction Process:**
1. Validates Amigo plugin is loaded
2. Reads active preset data
3. Converts binary plist → XML
4. Extracts JUCE plugin state (base64 → binary)
5. Locates "EMBEDDED_FILE" marker
6. Extracts base64-encoded WAV data after marker
7. Decodes to raw WAV file
8. Parses JUCE parameters for filename
9. Creates new instrument with default XRNI template
10. Loads WAV into sample slot 1
11. Names instrument and sample from extracted filename
12. Removes placeholder sample

**Error Handling:**
- "NO_EMBEDDED_SAMPLE" → Shows user-friendly message
- Instructs to click "Embed" in Amigo interface
- Safe fallback for missing data

**Filename Extraction:**
- Parses pathname entry from JUCE data
- Uses full filename with extension
- Fallback: "Amigo Sample Export"

**Instrument Setup:**
- Creates new instrument at `selected_index + 1`
- Loads default XRNI via `pakettiPreferencesDefaultInstrumentLoader()`
- Inserts sample at slot 1
- Sets instrument name = filename
- Sets sample name = filename

### 3. Open Sample Folder

Opens the folder containing the original sample file referenced in the Amigo preset.

**Process:**
1. Validates Amigo plugin loaded
2. Extracts JUCE state from preset
3. Searches for full path in JUCE data:
   - Checks first 1024 bytes (header area)
   - Looks for `/Users/` path pattern
   - Searches near "EMBEDDED_FILE" marker
   - Finds last path before marker
   - Scans for any `.wav` paths
4. Extracts directory path
5. Opens in Finder/file manager

**Path Search Strategy:**
- Multiple search methods (header, marker context, full scan)
- Handles various path storage formats
- Robust fallback mechanisms

**Error Handling:**
- "NO_PATH_FOUND" if no valid path detected
- Status message guides user

### 4. Export Sample to Amigo

**Keybinding:** `Global:Paketti:Paketti Export Renoise Sample to Amigo Embedded Sample` ⌨️

**Menu:** `Instrument Box:Paketti Amigo Sampler:Export Renoise Sample to Amigo Embedded Sample` 📋

Exports the current Renoise sample into Amigo as its embedded WAV.

**Export Process:**
1. Validates Amigo plugin loaded
2. Checks selected sample has audio data
3. Saves sample to temporary WAV file
4. Reads and verifies WAV data
5. Builds new JUCE data structure:
   - "PARAMS" header with version 1
   - Pathname entry (sanitized filename)
   - jucedata entry (WAV file data)
   - EMBEDDED_FILE marker
   - Base64-encoded WAV
6. Converts to binary plist
7. Wraps in Renoise preset XML format
8. Updates plugin's `active_preset_data`
9. Forces plugin refresh
10. Verifies update succeeded

**JUCE Data Structure:**

**Header:**
```
PARAMS              -- Magic (6 bytes)
0x01 0x00          -- Version 1 (little-endian)
```

**Pathname Entry:**
```
pathname + padding  -- ID (8 bytes total)
0x65 0x00          -- Version 101 (little-endian)
<length>           -- Path length (1 byte)
0x21               -- Flag: direct path mode
<path_string>      -- Filename.wav
```

**jucedata Entry:**
```
jucedata + padding  -- ID (8 bytes total)
0x65 0x00          -- Version 101 (little-endian)
<length_lo> <length_hi>  -- WAV size (2 bytes, little-endian)
<wav_data>         -- Raw WAV file data
```

**Embedded Sample:**
```
EMBEDDED_FILE      -- Marker string
0x00               -- Null terminator
<base64_wav>       -- Base64-encoded WAV
```

**Filename Sanitization:**
- Removes non-alphanumeric characters
- Keeps: A-Z, a-z, 0-9, `-`, `_`
- Ensures `.wav` extension
- Fallback: "untitled.wav"

**Verification:**
- Reads back updated preset
- Parses JUCE data
- Verifies pathname entry
- Verifies WAV data present
- Logs sizes and details

**Debug Output:**
- Original sample details (frames, channels, bits, rate)
- Temporary WAV file size
- JUCE data structure sizes
- Pathname and flag values
- WAV header details

### 5. Import WAV into Preset

Replaces the embedded sample in Amigo with a selected WAV file from disk.

**Import Process:**
1. Validates Amigo plugin loaded
2. Prompts for WAV file selection
3. Reads and validates input WAV
4. Parses existing preset data
5. Locates jucedata entry in JUCE parameters
6. Replaces WAV data in-place:
   - Keeps header and version/length fields
   - Replaces sample data
   - Updates length field (2-byte little-endian)
7. Verifies new JUCE header structure
8. Converts back to base64
9. Updates XML plist
10. Converts to binary plist
11. Wraps in preset XML
12. Updates plugin preset
13. Forces refresh

**Validation:**
- Verifies WAV header (RIFF, WAVE, fmt, data chunks)
- Logs sample rate, channels, bit depth
- Ensures data integrity

**In-Place Replacement:**
- Finds jucedata entry offset
- Calculates: `entry.offset + 12` (past ID + version + length)
- Keeps: `before` (up to data start)
- Replaces: WAV data
- Keeps: `after` (rest of chunk)
- Updates length field at `offset + 10-11`

## JUCE Parameter Parsing

**Header Structure:**
```
Offset 0-5:   "PARAMS" magic
Offset 6-7:   Version (little-endian, typically 0x01 0x00)
Offset 8+:    Parameter entries
```

**Entry Structure:**
```
ID (8 bytes, null-padded)
Version (2 bytes, little-endian)
Length (1-2 bytes, little-endian)
[Optional flag byte for pathname]
Data (variable length)
```

**Known Entry Types:**

**pathname/pathnam:**
- Version: 2 bytes LE
- Length: 1 byte
- Flag: 1 byte
  - `0x19` = Path index + embedded path
  - `0x21` = Direct path
  - `0x3C` = Path index (requires lookup)
- Data: Path string or index

**jucedata:**
- Version: 2 bytes LE
- Length: 2 bytes LE
- Data: Binary blob (often WAV data)

**metadata:**
- Version: 2 bytes LE
- Length: 2 bytes LE
- Data: Contains path lookup table

## Binary Plist Handling

**Conversion to XML:**
```bash
plutil -convert xml1 -o output.xml input.bin
```

**Conversion to Binary:**
```bash
plutil -convert binary1 -o output.bin input.xml
```

**Plist Structure:**
```xml
<plist version="1.0">
<dict>
    <key>jucePluginState</key>
    <data><![CDATA[<base64_juce_data>]]></data>
</dict>
</plist>
```

## WAV File Analysis

**WAV Header Parsing:**
- Reads RIFF chunk
- Parses fmt chunk:
  - Audio format (PCM = 1)
  - Channel count
  - Sample rate
  - Byte rate
  - Block align
  - Bits per sample
- Locates data chunk
- Calculates audio data size

**Sample Size Calculation:**
- Finds "data" chunk marker
- Reads 4-byte size (little-endian)
- Returns raw audio data size

## Path Detection Strategies

**Strategy 1: Header Search**
- Scans first 1024 bytes
- Looks for `/Users/...` patterns
- Finds paths ending in `.wav`

**Strategy 2: Marker Context**
- Locates "EMBEDDED_FILE" marker
- Searches 512 bytes before marker
- Finds last path-like string

**Strategy 3: Metadata Lookup**
- Parses metadata entry
- Builds path lookup table
- Matches path indices

**Strategy 4: Full Scan**
- Scans entire JUCE data
- Collects all path patterns
- Returns most likely path

## Debugging Tools

**Hex Dump:**
- Formats binary data as hex
- Shows ASCII representation
- 16 bytes per line
- Format: `XX XX XX XX | ASCII`

**Bytes to ASCII:**
- Converts printable bytes to characters
- Shows `\xXX` for non-printable

**Read Little-Endian Integer:**
- Supports 1-4 byte integers
- Lowest byte first
- Debug logging of each byte

## Amigo Plugin Detection

**Detection Logic:**
1. Check plugin is loaded
2. Verify `short_name == "Amigo"`
3. Works for AU and VST3 versions

**Safe Failure:**
- Returns false if not Amigo
- Shows status message
- Prevents errors on wrong plugin

## Sample Verification

**Match Verification:**
- Compares WAV headers (channels, rate, bit depth)
- Compares data chunk sizes
- Byte-by-byte data comparison
- Reports first difference with context

**Statistics:**
- Frame count
- Channel configuration
- Bit depth
- Sample rate

## Error Handling

**Common Errors:**
- "No active preset data found"
- "Invalid WAV file"
- "<ParameterChunk> not found"
- "No JUCE plugin state found"
- "NO_EMBEDDED_SAMPLE" (no sample embedded)
- "NO_PATH_FOUND" (no path in preset)

**Recovery:**
- All errors show user-friendly messages
- Console logging for debugging
- Safe fallbacks
- No crashes on malformed data

## Preset XML Format

**Renoise Preset Structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="AudioPluginDevice">
    <IsMaximized>true</IsMaximized>
    <ActiveProgram>-1</ActiveProgram>
    <PluginType>AU</PluginType>
    <PluginIdentifier>aumu:Amgo:PTNZ</PluginIdentifier>
    <PluginDisplayName>AU: PotenzaDSP: Amigo</PluginDisplayName>
    <PluginShortDisplayName>Amigo</PluginShortDisplayName>
    <PluginEditorWindowPosition>-1,-1</PluginEditorWindowPosition>
    <ParameterChunkType>Chunk</ParameterChunkType>
    <ParameterChunk><![CDATA[<base64_binary_plist>]]></ParameterChunk>
  </DeviceSlot>
</FilterDevicePreset>
```

## Use Cases

**Workflow 1: Sample Library Management**
1. Load Amigo preset
2. Extract embedded sample
3. Process in Renoise
4. Export back to Amigo

**Workflow 2: Preset Creation**
1. Prepare sample in Renoise
2. Export to Amigo
3. Design modulation/FX in Amigo
4. Save preset

**Workflow 3: Sample Recovery**
1. Load old Amigo preset
2. Extract embedded sample
3. Save to disk
4. Archive or reuse

**Workflow 4: Path Management**
1. Open sample folder
2. Replace sample file
3. Reimport to preset
4. Update path if needed


---

# Paketti Gater

**Source:** `PakettiGater.lua` | **Features:** 4

Advanced 16/32-step gater with 4 independent gating engines - Volume, Retrig, Playback Direction, and Panning. Real-time pattern writing with playhead tracking, per-gater step control, and multiple operation modes.

## Dialog Interface

**Keybinding:** `Global:Paketti:Paketti Gater Dialog...` ⌨️  
**MIDI Mapping:** `Paketti:Paketti Gater Dialog...` 🎹

**Core Features:**
- **16/32 Step Modes** - Switch between 16-step and 32-step patterns
- **4 Independent Gaters:**
  - **Volume Gater** - Controls volume (FX Column C00/Volume Column/FX Column L00)
  - **Retrig Gater** - Controls retrigger (FX Column/Volume Column/Panning Column)
  - **Playback Gater** - Controls playback direction (B00/B01)
  - **Panning Gater** - Controls stereo panning (FX Column/Panning Column)
- **Per-Gater Step Count** - Each gater can have different step counts (1-32)
- **Global Step Control** - Set all gaters to the same step count
- **Column Target Selection** - Choose which column to write to for each gater type

## Pattern Writing Modes

1. **Normal Mode** - Write to selected track only
2. **Solo Mode** - Write to all tracks EXCEPT selected (inverse gating)
3. **Selection Only Mode** - Apply gating only to pattern selection
4. **Print Once Mode** - Write pattern once from current line position

## Checkbox Grid Interface

**For Each Gater:**
- 16 or 32 checkboxes for step programming
- Step buttons (01-32) for quick step count selection
- Checkboxes show ON/OFF state for each step

**Volume Gater:**
- Checkboxes control volume per step (ON = full volume, OFF = silence)
- FX Column modes: C00 (cut volume) or L00 (set track gain)
- Volume Column mode: 80 (full) vs 00 (silent)

**Retrig Gater:**
- Checkboxes control retrigger per step
- Adjustable retrig speed (R01-R0F)
- Auto-reads existing retrig speed from track
- Can use FX Column, Volume Column, or Panning Column

**Playback Gater:**
- Checkboxes control playback direction per step
- ON = Forward playback (B00)
- OFF = Reverse/Stop playback (B01)

**Panning Gater:**
- 3 rows of checkboxes per step: Left / Center / Right
- Adjustable panning intensity (0-100%)
- FX Column mode: 0P command
- Panning Column mode: Direct panning values

## Preset Buttons

**Available Presets:**
- **All** - Every step ON
- **Every 2nd** - Alternating steps (1010...)
- **Every 3rd** - Every third step (100100...)
- **Every 4th** - Every fourth step (1000100...)
- **Jaguar** - Custom pattern: 101011101011110
- **Caapi** - Custom pattern: 1010101011101110

## Utility Functions

**Per-Gater Controls:**
- **Clear** - Clear all checkboxes for that gater
- **Random** - Randomize checkbox states
- **< / >** - Shift pattern left/right
- **Receive** - Read existing pattern from track
- **Clear Column** - Wipe column data

**Global Controls:**
- **Wipe** - Remove gating effects (respects Solo mode)
- **Global Clear** - Clear all gaters at once
- **Global Random** - Randomize all gaters at once
- **Global Receive** - Receive patterns from all gaters
- **Global Shift** - Shift all gaters left/right simultaneously

## Playhead Tracking

**Real-Time Visual Feedback:**
- Playhead highlights current step during playback
- Configurable playhead color (Orange/Purple/Black/White/Grey/None)
- Updates at 40ms intervals
- Works for all 4 gater types

## Auto-Grab Mode

**Automatic Pattern Reading:**
- Toggle checkbox: Automatically read patterns when changing tracks
- Reads all 4 gater types simultaneously
- Updates retrig speed from track
- Perfect for quickly copying patterns between tracks

## Keybindings

⌨️ `Global:Paketti:Paketti Gater Dialog...`

## MIDI Mappings

🎹 `Paketti:Paketti Gater Dialog...`  
🎹 `Paketti:Paketti Gater:Toggle Step Mode (16/32)`

## Technical Details

**Pattern Replication:**
- Automatically replicates pattern to fill entire pattern length
- Each gater's pattern repeats based on its step count
- Supports patterns up to 1024 lines
- Handles different LPB values correctly

**Column Management:**
- Makes required columns visible automatically
- Respects existing content in other columns
- Smart conflict avoidance (e.g., Volume Column used by multiple gaters)

**Step Count Behavior:**
- Steps 1-16: Use checkbox pattern
- Steps 17-32: Silence (for extended step counts beyond 16 checkboxes)
- Each gater can have independent step counts

**Panning Intensity:**
- Adjustable via preferences
- 0% = center panning only
- 100% = full left/right panning
- Updates existing patterns when changed

---

# Sample Cycle Tuning (RePitch)

**Source:** `PakettiRePitch.lua` | **Features:** 3

Advanced single-cycle waveform tuning calculator with frequency analysis, automatic pitch correction, and batch processing. Accurately analyzes sample frequency and applies precise transpose and fine-tune corrections.

## Sample Cycle Tuning Calculator Dialog

**Keybinding (Global):** `Global:Paketti:Sample Cycle Tuning Calculator...` ⌨️  
**Keybinding (Sample Editor):** `Sample Editor:Paketti:Sample Cycle Tuning Calculator...` ⌨️

**Dialog Features:**
- **Cycle Count Input** - Enter number of cycles in selection (default: 1)
- **Calculate Button** - Analyze selection and show results
- **Set Pitch Button** - Apply tuning correction to sample
- **Batch Mode** - Process all samples in instrument
- **Auto-Calculate** - Automatically runs 1-cycle calculation on dialog open

**Analysis Output:**
- Detected note name (e.g., "C4", "A#3")
- Frequency in Hz
- Cents deviation (+/- from nearest note)
- MIDI note number

**Batch Mode Features:**
- Analyzes all samples in current instrument
- Shows count of samples needing tuning (>2 cents deviation)
- Skips well-tuned samples (≤2 cents deviation)
- Applies corrections only to samples that need it
- Reports: X samples corrected, Y skipped

## Quick Selected Sample Tuning

**Keybinding (Global):** `Global:Paketti:Selected Sample 1 Cycle Tuning` ⌨️  
**Keybinding (Sample Editor):** `Sample Editor:Paketti:Selected Sample 1 Cycle Tuning` ⌨️

**Instant 1-cycle tuning:**
- Analyzes entire sample as 1 cycle
- Applies tuning immediately (no dialog)
- Shows result in status bar
- Perfect for single-cycle waveforms

## Quick Instrument Tuning

**Keybinding (Global):** `Global:Paketti:Selected Instrument 1 Cycle Tuning` ⌨️  
**Keybinding (Sample Editor):** `Sample Editor:Paketti:Selected Instrument 1 Cycle Tuning` ⌨️

**Batch 1-cycle tuning:**
- Analyzes all samples in instrument as 1 cycle each
- Applies corrections automatically
- Skips well-tuned samples
- No dialog - instant processing

## Technical Details

**Frequency Analysis:**
- Uses A4 = 440Hz reference
- Full MIDI range support (C0-B9)
- Precise cent calculations (1/1200 of semitone)
- Advanced frequency-to-note algorithm

**Pitch Correction:**
- Sets sample transpose (-120 to +120)
- Sets fine tune (-128 to +127 steps)
- Fine tune scaling: 255 steps = 200 cents
- Correction formula: negates detected deviation

**Special Handling:**
- **Ping-Pong Loop Detection** - Adds +12 semitones (1 octave) for ping-pong loops
- **Sample Selection Range** - Analyzes only selected range if available
- **Batch Processing** - 2 cents threshold for "needs tuning" classification

**Tuning Display Format:**
- Note name with octave (e.g., "C#4")
- Signed cents (e.g., "+15 cents", "-23 cents")
- Frequency with 2 decimal places
- MIDI note number (C4 = 60)

## Use Cases

1. **Single-Cycle Waveforms** - Tune synthesizer waveforms to exact pitch
2. **Multisamples** - Batch-tune entire instruments
3. **Drum Samples** - Quick tune percussion hits
4. **Loop Analysis** - Analyze loops with known cycle counts

---

# Sample Effect Generator

**Source:** `PakettiSampleEffectGenerator.lua` | **Features:** 1

Visual sample synthesizer with 3 canvas-based drawing interfaces for waveform, pitch modulation, and volume envelope. Draw effects directly and generate custom samples with real-time preview.

## Sample Effect Generator Dialog

**Keybinding:** `Global:Paketti:Paketti Sample Effect Generator` ⌨️

**3 Drawing Canvases:**
1. **Waveform Canvas** - Draw base waveform shape
2. **Pitch Modulation Canvas** - Draw pitch changes over time
3. **Volume Envelope Canvas** - Draw volume curve

**Mouse Drawing:**
- **Click & Drag** - Draw freehand curves
- **Smooth Interpolation** - Automatic interpolation between drawn points
- **Erase Mode** - Right-click to erase
- **Live Preview** - Updates selected sample in real-time (when enabled)

## Waveform Presets

**Dropdown Selection:**
- **Current** - Keep existing waveform
- **Sine** - Smooth sine wave
- **Triangle** - Linear triangle wave
- **Square** - Square wave (50% duty)
- **Sawtooth** - Ramp sawtooth
- **Flat** - Straight line (DC offset)
- **Ramp Up** - Linear ramp up
- **Ramp Down** - Linear ramp down
- **Log Ramp Up** - Logarithmic curve up
- **Log Ramp Down** - Logarithmic curve down
- **Pulse** - Narrow pulse wave
- **Diode** - Asymmetric waveform
- **Gauss** - Gaussian bell curve
- **Chebyshev** - Chebyshev polynomial
- **Chirp** - Frequency sweep
- **Pink Noise** - 1/f noise
- **Random** - Random values
- **Random Stairs** - Stepped random values

## Pitch Modulation Presets

**Additional Pitch Presets:**
- **1 Octave Steps** - Stepped pitch changes (12 semitones)
- **2 Octave Steps** - Larger stepped pitch changes (24 semitones)
- (All waveform presets also available)

**Pitch Range:**
- Center (0.5) = No pitch change
- Bottom (0.0) = -2 octaves
- Top (1.0) = +2 octaves

## Volume Envelope Presets

(All waveform presets available)

**Volume Range:**
- Bottom (0.0) = Silent
- Top (1.0) = Full volume

## Sample Generation Settings

**Duration Control:**
- Adjustable sample length (default 2.0 seconds)
- Sample rate: 44100 Hz
- Tuned resolution: 100 samples (perfect A440 tuning)

**Processing Options:**
- **Fade Out** - Apply 1000-frame fade at end (prevents clicks)
- **Beatsync** - Enable beatsync with 32 lines, Stretch-Texture mode
- **Waveform Override** - Use drawn waveform instead of preset

## Live Pickup Mode

**Real-Time Sample Monitoring:**
- Toggle checkbox: Enable live preview
- Updates selected sample as you draw
- Monitors sample/instrument index
- Automatically applies changes
- Perfect for sound design experimentation

## Normalization Functions

**Per-Canvas Normalization:**
- **Waveform Normalize** - Stretch to full 0.0-1.0 range
- **Pitch Normalize** - Expand pitch range to maximum
- **Volume Normalize** - Maximize volume envelope

**Button Actions:**
- **Generate Sample** - Create new sample from current settings
- **Clear Canvas** - Erase all drawing data
- **Reset to Preset** - Reload selected preset

## Technical Details

**Canvas Specifications:**
- Canvas Width: 463 pixels
- Canvas Height: 183 pixels
- Internal Padding: 10 pixels (prevents edge clipping)
- Border Margin: 6 pixels
- Text Height: 14 pixels
- Resolution: Variable point density

**Drawing Algorithm:**
- Smooth point interpolation between mouse positions
- Anti-aliasing for visual quality
- Normalized data storage (0.0-1.0)
- Real-time canvas updates

**Sample Generation Process:**
1. Read waveform data (or use preset)
2. Apply pitch modulation
3. Apply volume envelope
4. Generate audio buffer
5. Apply fade-out (if enabled)
6. Apply beatsync (if enabled)
7. Insert into Renoise

---

# Global Groove to Delay

**Source:** `PakettiGlobalGrooveToDelayValues.lua` | **Features:** 1

Convert Renoise's Global Groove settings to delay column values on selected track or group. Handles different LPB values with appropriate scaling and supports group track processing.

## Convert Global Groove to Delay

**Keybinding:** `Pattern Editor:Paketti:Convert Global Groove to Delay on Selected Track/Group` ⌨️  
**MIDI Mapping:** `Pattern Editor:Paketti:Convert Global Groove to Delay on Selected Track/Group` 🎹

**Conversion Process:**
- Reads Global Groove amounts (4 values: 0-1.0)
- Converts to delay column values (0-255)
- Writes delay values to pattern
- Disables Global Groove automatically
- Makes delay column visible automatically

**LPB Mode Support:**

1. **LPB4 Mode:**
   - Delay on every second row
   - GA1-GA4 affect odd lines (1,3,5,7...)
   - Simple alternating pattern

2. **LPB8 Mode:**
   - GA1: Line 03
   - GA2: Line 07
   - GA3: Line 11
   - GA4: Line 15
   - 2x delay scaling

3. **LPB16+ Mode:**
   - Scaled positions: (LPB8 position × scale) - 1
   - Scale = LPB / 8 (2 for LPB16, 4 for LPB32, etc.)
   - For LPB16 with groove ≥ 0.5: Moves notes down one line with delay

**Group Track Processing:**
- If group track selected: Processes all member tracks
- Makes delay columns visible for all members
- Shows detailed per-track status
- Applies same groove conversion to all members

## Conversion Formula

```lua
delay = (groove_percentage × 170) × scale_factor
```

**Scale Factors:**
- LPB4: 1x (no scaling)
- LPB8: 2x
- LPB16+: (LPB / 8)x

**Example Values:**
- 50% groove @ LPB4 = 85 (0x55)
- 50% groove @ LPB8 = 170 (0xAA)
- 50% groove @ LPB16 = 340 (0xFF, capped at 255)

## Safety Checks

**Validation:**
- Rejects Master track
- Rejects Send track
- Warns if LPB is not power of 2
- Warns if LPB < 4
- Checks for empty group tracks

**Status Messages:**
- Shows LPB mode
- Shows groove percentages and hex delay values
- Shows track name or group member list
- LPB16 warning: "not precise, contact esaruoho@icloud.com"

## Technical Details

**Delay Column Writing:**
- Writes to all visible note columns
- Clears non-delay lines (base lines)
- Preserves other column data
- Full pattern length coverage

**LPB16 Special Handling:**
- Groove ≥ 0.5: Move note down + apply delay
- Groove < 0.5: Keep note in place + apply delay
- Note data fully copied (note, instrument, volume, panning, effect)
- Original line cleared after move

---

# Launch App & Smart Folders

**Source:** `PakettiLaunchApp.lua` | **Features:** 3

Configure up to 6 external applications and 3 smart/backup folders for sample export. Dynamic menu generation with sample sending and folder saving capabilities.

## Configure Launch App Selection Dialog

**Keybinding:** `Global:Paketti:Configure Launch App Selection...` ⌨️

**Dialog Features:**
- **6 Application Slots** - Configure external apps
- **3 Smart Folder Slots** - Configure backup/export folders
- **Per-Slot Actions:**
  - **Browse** - Select application or folder
  - **Send Selected Sample to App** - Export and open current sample
  - **Send Sample Range to App** - Export and open selection range
  - **Save Selected Sample to Folder** - Save to smart folder
  - **Save All Samples to Folder** - Batch export all samples

## Dynamic Keybindings & Menu Entries

**Auto-Generated Bindings:**
- Creates keybindings for each configured app
- Creates MIDI mappings for each app
- Creates menu entries in multiple contexts:
  - Instrument Box
  - Main Menu
  - Sample Navigator
  - Sample Editor

**Naming Convention:**
- App name extracted from path
- Appended to menu entry (e.g., "Send Selected Sample to App 1 Audacity")

## Send Sample Operations

**Send Selected Sample to App:**
- Saves sample as WAV to temp folder
- Names file: `[SampleName]-tmpSave.wav`
- Launches configured application with sample

**Send Sample Range to App:**
- Creates temporary instrument/sample
- Copies selection range
- Exports as WAV
- Launches app
- Cleans up temporary data
- Disables AutoSamplify monitoring temporarily

**Platform Support:**
- **macOS:** `open -a "app_path" "file_path"`
- **Windows:** `start "" "app_path" "file_path"`
- **Linux:** `exec "app_path" "file_path" &`

## Smart Folder Operations

**Save Sample to Folder:**
- Names file: `[InstrumentName].wav`
- Handles 32-bit samples (saves as-is)
- Shows status: "Saved [filename] to Smart Folder [path]"

**Save All Samples to Folder:**
- Iterates through all instruments
- Names files: `[InstrumentName]_[index].wav`
- Shows count: "Saved X samples to Smart Folder [path]"
- Opens folder in system file explorer after save

**Static Keybindings:**
- `Global:Paketti:Save Sample to Smart/Backup Folder 1/2/3` (3 slots)
- `Global:Paketti:Save All Samples to Smart/Backup Folder 1/2/3` (3 slots)
- Plus menu entries + MIDI mappings

## Menu Organization

**3-Pass Menu Generation:**
1. **First Pass:** "Send Selected Sample" entries (no separator)
2. **Second Pass:** "Send Selected Sample Range" entries (separator before first)
3. **Third Pass:** "Launch App" entries (separator before first)

**Configure Entry:**
- Separator + "Configure Launch App Selection..." at bottom
- Available in all contexts

## Technical Details

**Menu Entry Management:**
- Tracks added entries in table
- `appSelectionRemoveMenuEntries()` - Cleans up old entries
- `appSelectionUpdateMenuEntries()` - Removes + recreates entries
- `appSelectionCreateMenuEntries()` - Initial creation

**Idle Notifier:**
- Waits for `renoise.song()` initialization
- Creates entries after document load
- Auto-removes notifier after execution
- Handles new document observable

**Path Handling:**
- Windows: Converts backslashes to double backslashes
- macOS: Preserves forward slashes
- Extracts app name from `.app` bundles
- Cross-platform compatible

---

# Frame Calculator

**Source:** `PakettiFrameCalculator.lua` | **Features:** 8

Calculate audio frames, duration, and timing information for patterns, sequences, and selected lines. Multiple calculation modes with live updates and detailed analysis.

## Frame Calculator Dialog

**Keybinding:** `Global:Paketti:Frame Calculator Dialog` ⌨️  
**Menu Entries:** Pattern Matrix, Pattern Sequencer, Pattern Editor, Mixer ⌨️ 📋

**4 Calculation Modes:**

1. **Current Pattern** - Analyze selected pattern
2. **Whole Song** - Calculate entire sequence length
3. **Song to Line** - From start to selected line
4. **Pattern to Line** - From pattern start to selected line

**Input Fields:**
- BPM (20-999)
- LPB (1-256)
- TPL (1-16)
- Pattern Lines (1-1024)
- Sample Rate (8000-192000 Hz)

**Output Information:**
- Duration in seconds
- Duration in frames
- Duration in beats
- Time format (MM:SS.MS)
- Pattern count (for song modes)

**Live Updates:**
- BPM observable - Updates on BPM change
- LPB observable - Updates on LPB change
- TPL observable - Updates on TPL change
- Pattern lines observable - Updates on pattern length change
- Line timer - Updates on line/sequence position change (modes 3 & 4)

## Show Pattern Frame Info

**Keybinding:** `Global:Paketti:Show Pattern Frame Info` ⌨️  
**Menu Entries:** Pattern Matrix, Pattern Sequencer, Pattern Editor, Mixer 📋

**Status Bar Output:**
```
Pattern: [lines] lines | [LPB] LPB | [BPM] BPM | [beats] beats | [sec]s | [frames] frames @ 44100Hz | [MM]:[SS.MS]
```

## Show Sequence Frame Info

**Keybinding:** `Global:Paketti:Show Sequence Frame Info` ⌨️  
**Menu Entries:** Pattern Matrix, Pattern Sequencer, Pattern Editor, Mixer 📋

**Console Output:**
- Per-pattern breakdown (lines, beats, seconds, frames)
- Sequence totals
- Pattern count

**Status Bar:**
```
Sequence: [count] patterns | [sec]s | [frames] frames @ 44100Hz | [MM]:[SS.MS]
```

## Show Pattern to Line Frame Info

**Keybinding:** `Global:Paketti:Show Pattern to Line Frame Info` ⌨️  
**Menu Entry:** Pattern Editor 📋

**Calculates:**
- Lines from pattern start to selected line
- Beats to selected line
- Seconds to selected line
- Frames to selected line

## Show Song to Line Frame Info

**Keybinding:** `Global:Paketti:Show Song to Line Frame Info` ⌨️  
**Menu Entry:** Pattern Editor 📋

**Calculates:**
- All patterns before current position
- Lines from current pattern start to selected line
- Total frames from song start
- Total duration from song start

## Show Song Length

**Keybinding:** `Global:Paketti:Show Song Length` ⌨️  
**Menu Entries:** Pattern Matrix, Pattern Sequencer, Pattern Editor, Mixer 📋

**Status Bar Output:**
```
Total song time: [HH]:[MM]:[SS]:[MS] | [count] patterns | [sec]s | [frames] frames @ 44100Hz | [BPM] BPM | [LPB] LPB
```

## Show Song Length Dialog

**Keybinding:** `Global:Paketti:Show Song Length Dialog` ⌨️  
**Menu Entries:** Pattern Matrix, Pattern Sequencer, Pattern Editor, Mixer 📋

**Dialog Display:**
- Total song time (HH:MM:SS:MS)
- Pattern count
- Duration in seconds
- Frame count @ sample rate
- BPM
- LPB

## Frame Calculator Live Update

**3 Toggle Functions:**

1. **Toggle Song to Line:**  
   **Keybinding:** `Global:Paketti:Toggle Frame Calculator Live Update (Song to Line)` ⌨️  
   Shows: `Song to line [N]: [sec]s | [frames] frames | [rows] rows | [MM]:[SS.MS]`

2. **Toggle Pattern to Line:**  
   **Keybinding:** `Global:Paketti:Toggle Frame Calculator Live Update (Pattern to Line)` ⌨️  
   Shows: `Pattern to line [N]: [sec]s | [frames] frames | [rows] rows | [MM]:[SS.MS]`

3. **Toggle Both:**  
   **Keybinding:** `Global:Paketti:Toggle Frame Calculator Live Update (Both)` ⌨️  
   Shows both Song to Line and Pattern to Line simultaneously

**Live Update Features:**
- Updates in real-time using app_idle_observable
- Tracks selected line changes
- Tracks sequence position changes
- Tracks BPM/LPB changes
- Persists across sessions (preference-based)

## Technical Details

**Frame Calculation Formula:**
```lua
pattern_beats = pattern_lines / LPB
pattern_seconds = (pattern_beats × 60) / BPM
pattern_frames = pattern_seconds × sample_rate
```

**Time Format:**
- Minutes: `math.floor(seconds / 60)`
- Seconds: `seconds - (minutes × 60)`
- Format: `MM:SS.MS` (5 decimal places for seconds)
- Hours format for song length: `HH:MM:SS:MS`

**Observable Management:**
- Adds notifiers when dialog opens
- Removes notifiers when dialog closes
- Handles pattern switching (re-attaches line observable)
- Prevents memory leaks

**Optimization:**
- Line timer only active for modes 3 & 4
- Updates only when values change (prevents redundant calculations)
- Caches last values (selected_line, selected_sequence, bpm, lpb)

---

# Preset++ (Advanced Device Presets)

**Source:** `PakettiPresetPlusPlus.lua` | **Features:** 15

Advanced device preset system with intelligent device inspection, quick device loading with pre-configured states, and automated send track creation workflows.

## Device Inspection

**Inspect Selected Device:**  
**Keybinding:** `Global:Paketti:Inspect Selected Device` ⌨️  
**Menu Entry:** Mixer 📋

**Console Output:**
- Device display name, name, path
- All parameters with indices and values
- Exposed (mixer) parameters
- Device state (active, maximized, external editor)
- **Complete Device Recreation Workflow:**
  1. Load device command (native vs VST)
  2. XML preset data for state injection
  3. Mixer parameter visibility commands
  4. Maximized state command
  5. External editor state command
  6. Display name command
  7. Enabled/disabled state command

**Inspect Track Device Chain:**  
**Keybinding:** `Global:Paketti:Inspect Track Device Chain` ⌨️  
**Menu Entries:** DSP Chain, Mixer 📋

Shows complete device chain with full details for each device.

**Inspect Track Device Chain (Clean):**  
**Keybinding:** `Global:Paketti:Inspect Track Device Chain (Clean)` ⌨️  
**Menu Entries:** DSP Chain, Mixer 📋

Simplified output without XML data (faster, cleaner).

## Quick Device Presets

### SeparateSyncLFO (Beatsgo)

**Keybinding:** `Global:Paketti:SeparateSyncLFO (Beatsgo) (Preset++)` ⌨️  
**Menu Entries:** DSP Device, DSP Chain, Mixer 📋

Loads *LFO Device with pre-configured Beatsgo LFO settings.

### Hipass (Preset++)

**Keybinding:** `Global:Paketti:Hipass (Preset++)` ⌨️  
**Menu Entries:** DSP Device, DSP Chain, Mixer 📋

Loads Filter device configured as high-pass filter.

### LFOEnvelopePan (Preset++)

**Keybinding:** `Global:Paketti:LFOEnvelopePan (Preset++)` ⌨️  
**Menu Entries:** DSP Device, DSP Chain, Mixer 📋

Loads *LFO Device with envelope-controlled panning.

### Send Device (Preset++)

**Keybinding:** `Global:Paketti:Send Device (Preset++)` ⌨️  
**Menu Entries:** DSP Device, DSP Chain, Mixer 📋

Loads Send device with optimized routing.

### Multiband Send Device (Preset++)

**Keybinding:** `Global:Paketti:Multiband Send Device (Preset++)` ⌨️  
**Menu Entries:** DSP Device, DSP Chain, Mixer 📋

Loads Multiband Send device with frequency splitting.

### Send (Preset++)

**Keybinding:** `Global:Paketti:Send (Preset++)` ⌨️

Quick send device loader.

### Multiband Send (Preset++)

**Keybinding:** `Global:Paketti:Multiband Send (Preset++)` ⌨️

Quick multiband send device loader.

## Create New Send Track Workflows

### Basic Creation

**Create New Send Track:**  
**Keybinding:** `Global:Paketti:Create New Send Track (Preset++)` ⌨️  
**Menu Entries:** DSP Device, DSP Chain, Mixer, Pattern Matrix, Pattern Editor 📋

Creates new send track (keeps source).

### Advanced Send Track Creation

**4 Keybindings:**
1. **Keep Source + Send:**  
   `Global:Paketti:Create New Send Track (Keep Source) (Preset++)`
2. **Mute Source + Send:**  
   `Global:Paketti:Create New Send Track (Mute Source) (Preset++)`
3. **Keep Source + Multiband Send:**  
   `Global:Paketti:Create New Multiband Send Track (Keep Source) (Preset++)`
4. **Mute Source + Multiband Send:**  
   `Global:Paketti:Create New Multiband Send Track (Mute Source) (Preset++)`

**Menu Entry Contexts:**
- DSP Chain (4 entries)
- DSP Device (4 entries)
- Mixer (4 entries)
- Pattern Matrix (4 entries)
- Pattern Editor (4 entries)

**Total:** 4 keybindings + 20 menu entries

**Workflow:**
1. Analyzes source track
2. Creates new send track
3. Inserts Send or Multiband Send device on source
4. Routes to new send track
5. Optionally mutes source track
6. Names send track appropriately

## Technical Features

**Device Loading:**
- Native device support (`loadnative()`)
- VST/AU plugin support (`loadvst()`)
- Line Input device protection
- XML state injection
- Mixer parameter visibility control

**Send Track Intelligence:**
- Auto-naming (e.g., "Send from [SourceTrack]")
- Proper routing setup
- Device placement after #Track Input
- Mute source option
- Group track avoidance

**XML Preset System:**
- Captures complete device state
- Includes all parameter values
- Stores mixer visibility settings
- Preserves device display name
- Handles external editor state


---

# Pattern Sequencer

**Source:** `PakettiPatternSequencer.lua` | **Features:** 35

Advanced pattern sequencer tools for cloning, duplicating, section management, and sequence organization. Includes flexible naming system with prefix/suffix/numbering controls.

## Sequencer Settings Dialog

**Keybinding:** `Pattern Sequencer:Paketti:Show Paketti Sequencer Settings Dialog` ⌨️

Opens a comprehensive settings dialog for controlling pattern sequencer behavior.

**Settings:**

- **Naming Options:**
  - **Naming Behavior** - 3 modes:
    - "Use Settings (Prefix/Suffix)" - Apply configured naming scheme
    - "Clear Name" - Empty name for cloned patterns
    - "Keep Original Name" - Preserve source pattern name
  - **Prefix** - Text added before pattern name
  - **Suffix** - Text added after pattern name
  - **Use Numbering** - Enable/disable automatic numbering
  - **Number Format** - Choose between `%d`, `%02d`, `%03d`
  - **Start From** - Starting number for sequence (1-999)

- **Behavior Options:**
  - **Select Cloned Pattern After Creation** - Auto-select newly created patterns

## Clone Current Sequence

**Keybinding:** `Global:Paketti:Clone Current Sequence` ⌨️  
**Keybinding:** `Pattern Sequencer:Paketti:Clone Current Sequence` ⌨️  
**MIDI Mapping:** `Paketti:Clone Current Sequence` 🎹

Clones the currently selected pattern sequence entry and inserts it immediately after.

**Features:**
- Respects naming preferences (prefix, suffix, numbering)
- Increments existing numbers if detected
- Selects cloned pattern if preference enabled
- Preserves pattern content and properties

## Duplicate Selected Sequence Range

**Keybinding:** `Global:Paketti:Duplicate Selected Sequence Range` ⌨️  
**Keybinding:** `Pattern Sequencer:Paketti:Duplicate Selected Sequence Range` ⌨️

Duplicates a selected range of sequence entries as a complete block.

**Features:**
- Applies naming scheme to entire range
- Maintains relative positioning
- Preserves track mute states
- Auto-selects new range if preference enabled

## Section Management

### Create Section From Selection

**Keybinding:** `Pattern Sequencer:Paketti:Create Section From Selection` ⌨️

Creates a new section from the current pattern sequencer selection.

**Features:**
- Auto-generates sequential section names (01, 02, 03...)
- Validates section boundaries
- Prevents overlapping sections
- Creates separating sections automatically

### Navigate Section Sequences

**Keybinding:** `Pattern Sequencer:Paketti:Select Next Section Sequence` ⌨️  
**Keybinding:** `Pattern Sequencer:Paketti:Select Previous Section Sequence` ⌨️

Navigate and select sections in the pattern sequencer.

**Features:**
- **Select Next** - Extends selection to include next section
- **Select Previous** - Removes last section or selects previous
- Auto-selects current section if no selection exists

### Select and Loop Sequence Section (01-32)

**Keybindings:** `Global:Paketti:Select and Loop Sequence Section 01` through `32` ⌨️

32 dedicated keybindings for instant section selection and loop setup.

**Features:**
- Directly select any numbered section (01-32)
- Automatically sets loop range
- Starts playback from section start

## Keep Sequence Sorted

**Keybindings:**
- `Global:Paketti:Keep Sequence Sorted On/Off/Toggle` ⌨️
- `Pattern Editor:Paketti:Keep Sequence Sorted On/Off/Toggle` ⌨️
- `Pattern Sequencer:Paketti:Keep Sequence Sorted On/Off/Toggle` ⌨️

**Menu Entries:**
- `Pattern Matrix:Paketti:Keep Sequence Sorted On/Off/Toggle` 📋

Controls the "Keep Sequence Sorted" feature that automatically reorders patterns.

## Wipe Empty Patterns From End

**Keybinding:** `Pattern Sequencer:Paketti:Wipe Empty Patterns From End` ⌨️  
**Menu Entry:** `Pattern Matrix:Paketti:Wipe Empty Patterns From End` 📋

Removes all empty patterns from the end of the pattern sequencer.

**Features:**
- Works backwards from end to find last non-empty pattern
- Preserves at least one pattern
- Shows count of removed patterns

## Clear Unused Patterns

**Keybindings:**
- `Global:Paketti:Clear Unused Patterns` ⌨️
- `Pattern Editor:Paketti:Clear Unused Patterns` ⌨️
- `Pattern Sequencer:Paketti:Clear Unused Patterns` ⌨️
- `Pattern Matrix:Paketti:Clear Unused Patterns` ⌨️

**Menu Entries:**
- `Pattern Matrix:Paketti:Clear Unused Patterns` 📋
- `Pattern Sequencer:Paketti:Clear Unused Patterns` 📋

Clears all patterns that are not used in the pattern sequencer.

**Features:**
- Identifies patterns not in sequence
- Clears pattern content
- Reports count of cleared patterns

## Duplicate Pattern and Insert Next

**Keybindings:**
- `Global:Paketti:Duplicate Pattern and Insert Next` ⌨️
- `Pattern Editor:Paketti:Duplicate Pattern and Insert Next` ⌨️
- `Pattern Sequencer:Paketti:Duplicate Pattern and Insert Next` ⌨️

Creates a complete duplicate of the current pattern and inserts it as the next sequence entry.

**Features:**
- Creates new pattern (not sequence alias)
- Copies all track data, automation, and content
- Preserves track mute states for both sequences
- Names duplicate with "(duplicate)" suffix
- Auto-selects new sequence position

## Add Current Sequence to Scheduled List

**Keybinding:** `Global:Paketti:Add Current Sequence to Scheduled List` ⌨️

Adds the currently selected sequence index to the transport's scheduled sequence list.

## Play Current Pattern Sequence

**Keybinding:** `Global:Paketti:Play Current Pattern Sequence` ⌨️

Starts playback from the first line of the currently selected sequence entry.

---

# FastTracker II XI Export

**Source:** `PakettiXIExport.lua` | **Features:** 4

Complete FastTracker II Extended Instrument (.xi) export system for Renoise instruments. Based on the authoritative XI implementation from Schism Tracker.

## Export XI (FastTracker II Extended Instrument)

**Keybinding:** `Global:Paketti:Export XI (FastTracker II Extended Instrument)` ⌨️

**Menu Entries:**
- `Instrument Box:Paketti:Export XI (FastTracker II Extended Instrument)` 📋
- `Main Menu:Tools:Paketti:Export XI (FastTracker II Extended Instrument)` 📋
- `Main Menu:File:Paketti Export:Export XI (FastTracker II Extended Instrument)` 📋

Exports the selected Renoise instrument to FastTracker II .xi format.

**Core Features:**
- **Sample Data:** FT2-style delta-compressed 16-bit PCM encoding
- **Stereo Support:** Interleaved L/R channel export
- **Envelopes:** Volume and panning envelope export with sustain/loop
- **Loops:** Forward and ping-pong loop support
- **Vibrato:** Auto vibrato parameters (type, sweep, depth, rate)
- **Instrument Properties:** Name, type, fadeout, volume column enabled
- **Sample Mappings:** Note-to-sample keyboard mapping (96 notes)

**XI Format Details:**
- Header signature: "Extended Instrument: "
- Version: 1.02
- Sample slots: Up to 16 samples per instrument
- Envelope points: Up to 12 points per envelope
- Sample resolution: 16-bit signed PCM (delta-compressed)

**Export Process:**
1. Validates selected instrument has samples
2. Prompts for save location (.xi extension)
3. Writes XI header (samples + 1) * 4 bytes
4. Writes instrument name (22 bytes, null-padded)
5. Exports instrument properties and envelopes
6. Exports sample mappings (96 notes)
7. Exports sample headers (40 bytes each)
8. Writes delta-compressed sample data

**Compatibility:**
- FT2/XM trackers
- Schism Tracker
- MilkyTracker
- OpenMPT (XI import)
- ModPlug Tracker

**Limitations:**
- Maximum 16 samples per instrument (XI format limit)
- Envelope points limited to 12 (XI format limit)
- No filter/modulation export (XI format does not support)

---

# Octatrack OctaCycle Generator

**Source:** `PakettiOctaCycle.lua` | **Features:** 9

Creates multiple octave versions of single-cycle waveforms optimized for Elektron Octatrack. Extends Octatrack's ±1 octave pitch range by generating pre-pitched samples across multiple octaves.

## Generate OctaCycle

**Keybinding:** `Sample Editor:Paketti:Generate OctaCycle for Octatrack` ⌨️

**Menu Entries:**
- `Sample Editor:Paketti:Octatrack:Generate OctaCycle...` 📋
- `Sample Mappings:Paketti:Octatrack:Generate OctaCycle...` 📋

Opens a comprehensive dialog for generating octave-spread single-cycle waveforms.

**Parameters:**

1. **Root Note** - Base note for cycle (C, C#, D... B)
2. **Cents Offset** - Fine tune adjustment (-100 to +100 cents)
3. **Octave Range** - Low/High octave selection (0-7)
4. **Export After Creation** - Auto-export to Octatrack after generation

**Generation Process:**

1. **Source Validation:**
   - Checks for valid single-cycle waveform
   - Warns if sample exceeds 1 second
   - Supports mono/stereo sources

2. **Frequency Calculation:**
   - Calculates target frequencies for each octave
   - Uses A4 = 440Hz reference
   - Applies cents offset for fine tuning

3. **Resampling:**
   - Resamples cycle to exact lengths per octave
   - Uses linear interpolation for smooth results
   - Ensures minimum Octatrack slice length (64 samples)
   - Pads to power-of-2 lengths if needed

4. **Sample Chain Creation:**
   - Concatenates resampled octaves into single sample
   - Creates slice markers at octave boundaries
   - Names instrument with root note/octave range
   - Assigns samples to chromatic keyboard layout

## Quick OctaCycle (C, Oct 1-7)

**Keybinding:** `Sample Editor:Paketti:Quick OctaCycle for Octatrack` ⌨️

**Menu Entries:**
- `Sample Editor:Paketti:Octatrack:Quick OctaCycle (C, Oct 1-7)` 📋
- `Sample Mappings:Paketti:Octatrack:Quick OctaCycle (C, Oct 1-7)` 📋

One-click OctaCycle generation with preset defaults:
- Root Note: C
- Octave Range: 1-7
- No cents offset

## Export OctaCycle to Octatrack

**Keybinding:** `Sample Editor:Paketti:Export OctaCycle to Octatrack` ⌨️

**Menu Entries:**
- `Sample Editor:Paketti:Octatrack:Export OctaCycle to Octatrack` 📋
- `Sample Mappings:Paketti:Octatrack:Export OctaCycle to Octatrack` 📋

Exports the generated OctaCycle to Octatrack-compatible WAV format.

**Export Details:**
- Sample rate: 44.1kHz (Octatrack native)
- Bit depth: 16-bit
- Format: WAV with slice markers
- Filename: Includes root note and octave range

**Use Cases:**
- Wavetable synthesis on Octatrack
- Wide pitch range single-cycle playback
- Chromatic melodic single-cycle instruments
- Granular synthesis with octave-spread grains

---

# Capture Last Take & EditStep MIDI Gate

**Source:** `PakettiCaptureLastTake.lua` | **Features:** 4

Real-time MIDI note capture system with audition slots, MIDI input recording, and EditStep-based MIDI gate for controlled note entry.

## Capture Last Take Dialog

**Keybinding:** `Global:Paketti:Paketti Capture Last Take...` ⌨️

Opens a comprehensive MIDI capture interface with 16 capture slots and audition system.

**Core Features:**

1. **MIDI Note Capture (Max 12 Notes)**
   - Real-time MIDI input monitoring
   - Captures up to 12 simultaneous notes
   - Auto-sorts notes by pitch (ascending)
   - Visual note display and status

2. **Capture Slots (16 Total)**
   - Store captured note sets to 16 slots
   - Each slot shows: note count, sample, velocity range
   - Visual "NEWEST" indicator for latest capture
   - Button-based dump to pattern

3. **Audition System**
   - 16 audition slots for quick sample testing
   - MIDI knob control for slot selection (0-48)
   - One-shot audition playback
   - Sample name display

4. **Pattern Writing**
   - "Dump To Pattern" - Write notes to current pattern line
   - Per-slot dump buttons
   - Instrument auto-selection
   - Velocity preservation

5. **MIDI Device Selection**
   - Device dropdown for input selection
   - Real-time device switching
   - Connection status display

6. **Gater Section (Expandable)**
   - EditStep MIDI Gate integration
   - Visual feedback for gate status
   - Collapse/expand UI control

**Workflow:**
1. Select MIDI input device
2. Play notes on MIDI controller
3. Notes captured and sorted automatically
4. Store to slot when satisfied
5. Dump slot contents to pattern at any time

## Put Audition Slot to Pattern

**Keybinding:** `Global:Paketti:Put Audition Slot to Pattern` ⌨️

Writes the currently selected audition slot directly to the pattern at the current position.

**Features:**
- Uses selected audition slot (1-16)
- Inserts note at current edit line
- Auto-advances cursor by EditStep
- Preserves instrument/sample selection

## Toggle EditStep MIDI Gate

**Keybinding:** `Global:Paketti:Toggle EditStep MIDI Gate` ⌨️  
**MIDI Mapping:** `Paketti:Toggle EditStep MIDI Gate` 🎹

Enables/disables EditStep-based MIDI gating for controlled note entry.

**How It Works:**
- **Gate ON:** MIDI notes only trigger on EditStep boundaries
- **Gate OFF:** MIDI notes trigger immediately (normal behavior)

**Use Cases:**
- Quantized live MIDI input
- Step-by-step melodic entry
- Precise timing control for live performance
- Rhythmic pattern building

**Visual Feedback:**
- Status message on toggle
- Gater section UI updates
- Current gate state displayed

---

# Polyend Buddy (PTI File Browser)

**Source:** `PakettiPolyendSuite.lua` | **Features:** 2

Comprehensive Polyend Tracker integration for browsing, loading, and managing PTI (Polyend Tracker Instrument) files.

## Polyend Buddy Dialog

**Keybinding:** `Global:Paketti:Polyend Buddy (PTI File Browser)` ⌨️  
**MIDI Mapping:** `Paketti:Polyend Buddy (PTI File Browser)` 🎹

Opens a full-featured file browser for Polyend Tracker PTI/WAV files with backup and sync capabilities.

**Core Features:**

1. **Dual File Browsers:**
   - **Polyend Device Browser** - Browse connected Polyend device
   - **Computer Local Browser** - Browse local PTI backup folders
   - Real-time folder navigation
   - File count display

2. **File Operations:**
   - **Load to Renoise** - Import PTI to instrument slot
   - **Save PTI** - Export current instrument as PTI
   - **Save WAV** - Export sample chain as WAV
   - **Refresh** - Rescan device/folders

3. **Device Detection:**
   - Auto-detects connected Polyend devices
   - USB storage mode verification
   - Connection status display
   - Path validation

4. **Backup System:**
   - Local PTI backup folder support
   - Backup file browser
   - Sync between device and computer
   - Duplicate file handling

5. **Save Path Management:**
   - Separate PTI/WAV save paths
   - Use Save Paths toggle
   - Path configuration UI
   - Default path fallbacks

6. **PTI Format Support:**
   - Full PTI file import/export
   - Sample chain slice markers
   - Polyend Tracker compatibility
   - WAV with CUE point support

**Preferences Integration:**
- `PolyendRoot` - Device root path
- `PolyendLocalPath` - Local PTI folder
- `PolyendPTISavePath` - PTI export location
- `PolyendWAVSavePath` - WAV export location
- `PolyendLocalBackupPath` - Backup folder
- `PolyendUseSavePaths` - Enable custom save paths
- `PolyendUseLocalBackup` - Enable backup system

**Workflow:**
1. Connect Polyend device (USB storage mode)
2. Open Polyend Buddy dialog
3. Browse device folders or local backups
4. Load PTI files to Renoise
5. Save Renoise instruments as PTI
6. Sync with local backup folder

---

# Melodic Slice Switching (Polyend)

**Source:** `PakettiPolyendSliceSwitcher.lua` | **Features:** 4

Velocity-based slice switching system for polyphonic melodic slice playback, designed for Polyend Tracker workflow.

## Polyend Slice Dialog Toggle

**Keybinding:** `Global:Paketti:Polyend Slice Dialog Toggle` ⌨️

Opens/closes the melodic slice switcher dialog with real-time slice selection.

**Core Features:**

1. **Velocity Range Control:**
   - Active slice: 00-7F velocity (full velocity)
   - Inactive slices: 00-00 velocity (silent)
   - Real-time velocity mapping updates

2. **Slice Navigation:**
   - Visual slice display (current/total)
   - Slider control for slice selection
   - Auto-selects corresponding sample in Renoise

3. **MIDI Knob Control:**
   - Knob parameter for slice selection (0-48)
   - Real-time MIDI feedback
   - Smooth slice switching

4. **Sample Name Display:**
   - Shows current slice sample name
   - Status messages for slice changes

**How It Works:**
- Only one slice active at a time (00-7F velocity)
- All other slices set to 00-00 (silent)
- Allows polyphonic playback of single melodic note
- Compatible with up to 48 samples per instrument

## Polyend Slice Next/Previous

**Keybindings:**
- `Global:Paketti:Polyend Slice Next` ⌨️
- `Global:Paketti:Polyend Slice Previous` ⌨️

Navigate through slices without opening dialog.

**Features:**
- Wraps at boundaries (00 ↔ 47)
- Updates velocity ranges automatically
- Shows sample name in status
- MIDI knob compatible

## Polyend Slice Select (MIDI Knob)

**MIDI Mapping:** `Paketti:Polyend Slice Select (0-48) x[Knob]` 🎹

Real-time MIDI knob control for slice selection.

**MIDI Implementation:**
- 0-127 MIDI range → 0-48 slices
- Smooth interpolation
- Visual feedback in dialog (if open)
- Works without dialog open

**Use Cases:**
- Live performance slice switching
- Melodic one-shot slice playback
- Polyend-style velocity layer workflow
- Polyphonic melodic slice instruments

---

# Melodic Slice Export (Polyend)

**Source:** `PakettiPolyendMelodicSliceExport.lua` | **Features:** 3

Creates sample chains from multiple samples and exports as PTI with slice markers. Reverse of PTI import: takes individual samples → creates chained sample with slices.

## Melodic Slice Export (One-Shot)

**Keybinding:** `Global:Paketti:Melodic Slice Export (One-Shot)` ⌨️

Loads up to 48 individual samples and creates a slice-chained instrument for melodic playback.

**Process:**

1. **Sample Selection:**
   - Prompts for multiple files (WAV/AIF/FLAC/MP3/AIFF)
   - Maximum 48 samples (Polyend limit)
   - Shows warning if exceeding limit

2. **Instrument Creation:**
   - Creates new instrument if needed
   - Loads default drumkit XRNI
   - Names instrument with hex slot number

3. **Sample Loading:**
   - ProcessSlicer progress dialog
   - Applies Paketti loader preferences
   - Sets samples to full keyboard range (C-0 to B-9)
   - Base note: C-5 for all samples

4. **Modulation Setup:**
   - Applies user modulation preferences
   - Configures Volume AHDSR if enabled
   - Sets interpolation, oversampling, autofade

**Loader Preferences Applied:**
- Interpolation mode
- Oversampling
- Autofade/Autoseek
- Loop mode/Loop exit
- NNA (New Note Action)
- Oneshot mode

## Melodic Slice Create Chain

**Keybinding:** `Global:Paketti:Melodic Slice Create Chain` ⌨️

Creates a sample chain from loaded melodic samples with slice markers.

**Process:**

1. **Validation:**
   - Checks for multiple samples (2-48)
   - Validates sample data
   - Confirms slice creation intent

2. **Chain Creation:**
   - Concatenates all samples sequentially
   - Creates slice markers at sample boundaries
   - Preserves sample order

3. **Output:**
   - Single chained sample with slices
   - Slice markers at exact boundaries
   - Ready for PTI export

## Melodic Slice Export Current

**Keybinding:** `Global:Paketti:Melodic Slice Export Current` ⌨️

Exports the currently selected slice-chained instrument as a Polyend PTI file.

**Export Process:**
1. Validates slice-chained instrument
2. Prompts for PTI save location
3. Exports with PTI slice markers
4. Shows confirmation

**PTI Export Features:**
- Sample rate conversion (44.1kHz)
- Bit depth: 16-bit
- Slice marker preservation
- Polyend Tracker compatible

**Use Cases:**
- One-shot sample collections → melodic instrument
- Drum hit libraries → chromatic playback
- Vocal chops → melodic slices
- Sound effect collections → slice switching

---

# Custom LFO Presets & Device XML Control

**Source:** `PakettiXMLizer.lua` | **Features:** 31

Advanced LFO envelope manipulation system with 16 preset slots, custom envelope generation, external editor support, and device XML control via active_preset_data injection.

## Send Reverser (MuteSource Toggle)

**Keybinding:** `Global:Paketti:Send Reverser` ⌨️

Toggles the MuteSource parameter on the selected track's Send device (device slot 2).

**Features:**
- Toggles between `true` (mute source) and `false` (keep source)
- Uses XML injection for parameter control
- Works with Send device only

## Custom LFO Preset System

### Apply Custom LFO Preset (01-16)

**Keybindings:** `Global:Paketti:Apply Custom LFO Preset 01` through `16` ⌨️

**Menu Entries:**
- `Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Apply Custom LFO Preset 01-16` 📋
- `DSP Device:Paketti:Custom LFO Envelopes:Apply Custom LFO Preset 01-16` 📋

Applies a stored custom LFO envelope to the selected LFO device.

**Features:**
- 16 preset slots stored in preferences
- XML-based envelope injection
- Preserves amplitude, offset, frequency
- Custom envelope points (up to 1024 steps)

### Store Current LFO to Slot (01-16)

**Keybindings:** `Global:Paketti:Store Current LFO to Slot 01` through `16` ⌨️

**Menu Entries:**
- `Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Store Current LFO to Slot 01-16` 📋
- `DSP Device:Paketti:Custom LFO Envelopes:Store Current LFO to Slot 01-16` 📋

Stores the current LFO device's envelope to a preset slot.

**Stored Data:**
- Complete envelope point data
- Amplitude, offset, frequency
- Custom envelope playmode
- All envelope parameters

### Load LFO from Slot (01-16)

**Keybindings:** `Global:Paketti:Load LFO from Slot 01` through `16` ⌨️

**Menu Entries (Separator Above):**
- `Main Menu:Tools:Paketti:Instruments:Custom LFO Envelopes:Load LFO from Slot 01-16` 📋
- `DSP Device:Paketti:Custom LFO Envelopes:Load LFO from Slot 01-16` 📋

Loads a stored LFO preset from preferences.

**Features:**
- Validates slot data before loading
- Shows error if slot empty
- Preserves device routing

## LFO Envelope Resolution Control

**Keybindings:**
- `Global:Paketti:Double LFO Envelope Resolution` ⌨️
- `Global:Paketti:Halve LFO Envelope Resolution` ⌨️

Modifies the number of envelope points by doubling or halving.

**Features:**
- **Double:** Adds interpolated points between existing
- **Halve:** Removes every other point
- Preserves envelope shape
- Updates envelope length accordingly

## Toggle LFO/Device External Editor

**Keybinding:** `Global:Paketti:Toggle LFO/Device External Editor` ⌨️  
**MIDI Mapping:** `Paketti:Toggle LFO/Device External Editor` 🎹

Opens or closes the external editor for the selected device.

**Supported Devices:**
- *LFO Device
- *Instr. MIDI Control
- *Instr. Automation
- *Instr. Macros
- *Hydra
- *XY Pad
- *Key Tracking
- *Velocity Tracking
- *Signal Follower

## List Devices with External Editor Support

**Keybinding:** `Global:Paketti:List Devices with External Editor Support` ⌨️  
**MIDI Mapping:** `Paketti:List Devices with External Editor Support` 🎹

Prints a list of all devices that support external editor to console.

## Quick LFO Custom Editor

**Keybinding:** `Global:Paketti:Quick LFO Custom Editor` ⌨️  
**MIDI Mapping:** `Paketti:Quick LFO Custom Editor` 🎹

Opens the LFO custom envelope editor with one keypress.

**Features:**
- Finds first LFO device on track
- Creates LFO if none exists
- Opens external editor automatically

## LFO Envelope Editor Dialog

**Keybinding:** `Global:Paketti:LFO Envelope Editor Dialog` ⌨️  
**MIDI Mapping:** `Paketti:LFO Envelope Editor Dialog` 🎹

Opens a comprehensive LFO envelope editing dialog with curve generation and manipulation tools.

**Dialog Features:**

1. **Curve Generators:**
   - Sine, Triangle, Saw Up/Down
   - Square, Random, Smooth Random
   - Exponential, Logarithmic
   - Custom envelope drawing

2. **Envelope Manipulation:**
   - Scale (50%, 150%, 200%)
   - Flip, Invert, Mirror
   - Center, Min, Max
   - Slapback, Reverse

3. **Point Editing:**
   - Add/remove envelope points
   - Drag points graphically
   - Numerical value input
   - Time/value display

4. **Resolution Control:**
   - 64, 128, 256, 512, 1024 points
   - Double/halve resolution
   - Smooth interpolation

5. **Preset Management:**
   - Load from 16 slots
   - Save to 16 slots
   - Quick apply
   - Preset naming

## LFO Envelope Scale Operations

**Keybindings:**
- `Global:Paketti:Custom LFO Envelope Scale 50%` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale 150%` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale FLIP` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Invert` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Mirror` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Slapback` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Center` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Min` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Max` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Randomize` ⌨️
- `Global:Paketti:Custom LFO Envelope Scale Humanize` ⌨️

Quick envelope transformation operations applied to selected LFO device.

**Transformations:**
- **Scale 50%/150%** - Amplitude scaling
- **FLIP** - Vertical flip (1 - value)
- **Invert** - Same as FLIP
- **Mirror** - Horizontal mirror (reverse time)
- **Slapback** - Original + reversed concatenated
- **Center** - Normalize around center (0.5)
- **Min** - Scale to minimum value
- **Max** - Scale to maximum value
- **Randomize** - Apply random values
- **Humanize** - Add subtle random variations

**Use Cases:**
- Complex modulation curves for synthesis
- Preset-based LFO management
- Live performance LFO switching
- Advanced envelope shaping
- Backup and restore LFO presets


---

# Paketti Preferences System

**Source:** `Paketti0G01_Loader.lua` | **Features:** 1

The core preferences system for Paketti, managing all global settings, tool configuration, and user preferences. This file also defines the comprehensive Paketti Preferences dialog.

## Show Paketti Preferences

**Keybinding:** `Global:Paketti:Show Paketti Preferences...` ⌨️

Opens the comprehensive Paketti Preferences dialog with all settings organized in 3 columns.

**Column 1: Miscellaneous Settings**
- Global Groove on Startup
- Keep Sequence Sorted (Do Nothing/False/True) - Control sequencer.keep_sequence_sorted on startup. True = patterns stay sorted, False = patterns can be reordered freely
- New Song BPM Randomizer (bell curve 60-220, centered at 120)
- 0G01 Loader (auto-inserts C-4 + 0G01 on new track)
- Random BPM (write BPM to file)
- Always Open Track DSPs
- Always Open Sample FX Chain Devices
- Selected Sample Beatsync Lines
- Replace Current Instrument (pakettification)
- Instrument Properties (Do Nothing/Hide/Show)
- Disk Browser Control (API 6.2+)
- Switcharoo Auto-Grab
- Oblique Strategies on Startup
- Slice StepSeq Velocity
- Create New Instrument & Loop from Selection
- Render Settings (sample rate, bit depth, interpolation, bypass, DC offset)
- Experimental Render Settings (priority, silence multiplier, remove silence)
- Rotate Sample Buffer Settings (fine/coarse)
- Strip Silence Thresholds (strip/move)
- Pattern Editor (exploded track naming, wipe exploded track, pattern status monitor, audition on line change, automatic rename track, select used instrument, frame calculator update, Impulse Tracker F8)
- Edit Mode Colouring (none/selected track/all tracks)
- Blend Value (scope highlight intensity)
- Effect Column→Automation Settings (format, retain effect column)

**Column 2: Paketti Loader Settings**
- AutoSamplify Settings (enable monitoring, pakettify)
- Skip Automation Device
- Enable AHDSR Envelope
- One-Shot, Autoseek, Autofade
- Loop Release/Exit Mode
- Oversampling
- Sample Interpolation (None/Linear/Cubic/Sinc)
- New Note Action (NNA) Mode (Cut/Note-Off/Continue)
- Loop Mode (Off/Forward/Backward/PingPong)
- FilterType (22 filter types)
- LazySlicer (show original/newest slice)
- Drumkit Loader (move beginning silence, normalize samples, normalize large samples)
- Maximum Sample Frame Size (5MB-100MB)
- Default XRNI files (standard + drumkit)
- Preset Files dropdowns
- Wipe & Slices Settings (loop mode, beatsync mode, NNA, mute group, loop release, one-shot, autoseek, autofade)
- Dialog Close Key (tab/esc/space/return/q/donteverclose)
- Preset++ (create track w/ channelstrip)
- Random Device Chain Loader Path
- Random IR Loader Path
- Device Load Order (first/last)
- Device Load Behavior (nothing/external editor/parameter editor)
- Load to Track Position (first/last)
- LFO Write Device Delete
- Sample Selection Info (show sample selection, include frequency analysis, frequency analysis cycles)

**Column 3: Advanced Settings**
- Player Pro Settings (light/dark mode, effect canvas write/subcolumn, note canvas write/piano keys, always open dialog, smart subcolumn, auto-hide on frame switch)
- Parameter Editor (previous/next, A/B, automation playmode, randomize strength, half size, half size font, auto-open)
- Create New Sends (collapsed, send naming per track)
- Unison Generator Settings (detune, random fluctuation, hard sync, duplicate instrument)
- File Menu Location (File/Paketti/Both)
- EQ30 Behavior (autofocus, minimize devices)
- HyperEdit (auto-fit rows, manual row count)
- Paketti Gater Panning (0-100% intensity)
- Groovebox 8120 (collapse, append tracks & instruments, playhead color)
- MIDI Populator Settings (send device type)
- Polyend Suite Settings (open slice dialog)
- Large Chunk of Keyboard Shortcuts (jump row commands, jump forward/backward, trigger pattern line, instrument transpose, play & loop pattern)

**Goodies Section:**
- Load Pale Green Theme
- Load Plaid Zap .XRNI
- Load 200 Drum Machines (.zip)

**Special Features:**
- **0G01 Loader Toggle** - Automatically creates new tracks with C-4 + 0G01 glide command when loading samples
- **Menu Configuration Dialog** - Separate dialog for enabling/disabling menu entries per context (Instrument Box, Sample Editor, etc.)
- **Live Preview** - Strip/Move silence thresholds show real-time selection preview in Sample Editor
- **Live Updates** - Many settings apply immediately (track blend, unison detune, etc.)
- **Preference Persistence** - All settings automatically saved to `preferences.xml`

**Dialog Controls:**
- **Open Dialog of Dialogs** - Quick access to all Paketti dialogs
- **OK** - Save and close
- **Cancel** - Discard changes and close
- **ESC key** - Close dialog (respects Dialog Close Key preference)

---

# Chord Progression Player

**Source:** `PakettiChords.lua` | **Features:** 3 (API 6.2+)

Advanced chord progression player with 13 chord types, per-slot settings, strum control, extra notes, preset progressions, and real-time playback.

## Paketti Chords - Progression Player

**Keybinding:** `Global:Paketti:Paketti Chords - Progression Player...` ⌨️  
**MIDI Mapping:** `Paketti:Paketti Chords - Progression Player` 🎹  
**Menu Entry:** `Main Menu:Tools:Chords - Progression Player...` 📋

Opens the comprehensive chord progression editor and player.

**Core Features:**

1. **13 Chord Types Available:**
   - **Triads:** I (maj), ii (min), iii (min), IV (maj), V (maj), vi (min), vii° (dim)
   - **Seventh Chords:** I7 (maj7), ii7 (min7), V7 (dom7)
   - **Suspended:** Isus2, Isus4
   - **Augmented:** I+ (aug)

2. **8 Progression Slots:**
   - Each slot stores: chord type, duration, strum, velocity, extra notes
   - Visual feedback: Purple (selected), Blue (has chord), Orange (playing), Gray (empty)
   - Per-slot controls: Up/Down movement, Copy/Paste, Clear, Audition

3. **Global Settings:**
   - **Key** - C through B (12 keys)
   - **Base Octave** - 0-8
   - **Interval** - 0.25-64 beats (time between chords)
   - **Instrument** - 1-255
   - **Repeat** - Loop progression infinitely

4. **Per-Slot Settings:**

   **Length** (0.1-64 beats) - Note duration before OFF

   **Strum** (0-16) - Delay between notes:
   - **Rows Mode:** Notes on separate rows (original spacing)
   - **Delays Mode:** Notes on same row using delay column (00-FF spread)

   **Strum Mode:**
   - **Rows** - Notes written to separate pattern rows
   - **Delays** - Notes written to same row with delay column values

   **Velocity** (0-127) - Volume for all notes in chord (displays as 00-80 hex in Renoise)

   **Strum Order:**
   - **Up** - Ascending (low to high)
   - **Down** - Descending (high to low)
   - **Random** - Shuffled

   **EX1 (Extra Note 1):**
   - **Index** (0-4) - Which chord note (0=Off, 1=Root, 2=2nd, 3=3rd, 4=4th)
   - **Octave** (-4 to +4) - Transpose offset (e.g., -2 for bass)
   - **Length** (0.1-64 beats) - Independent duration

   **EX2 (Extra Note 2):**
   - **Index** (0-4) - Which chord note
   - **Octave** (-4 to +4) - Transpose offset (e.g., +1 for melody)
   - **Length** (0.1-64 beats) - Independent duration

5. **17 Preset Progressions:**
   - I-V-vi-IV (Pop)
   - I-IV-V (Rock)
   - I-IV-I-V (Blues)
   - I-vi-IV-V (50s)
   - vi-IV-I-V (Axis)
   - I-V-vi-iii-IV-I-IV-V (Canon)
   - ii-V-I (Jazz)
   - I-vi-ii-V (Circle)
   - I-bVII-IV (Modal)
   - i-bVII-bVI-V (Minor)
   - I-iii-IV-iv (Creep)
   - vi-V-IV-V (Andalusian)
   - I-IV-vi-V (Sensitive)
   - I-II-IV-I (Royal Road)
   - I-V-IV-IV (Plagal)
   - I-bIII-bVII-IV (Dorian)
   - vi-ii-V-I (Turnaround)

6. **Playback Modes:**
   - **Live Audition** - Preview individual slots (slower tempo, press again to stop)
   - **Real-Time Playback** - Play entire progression with BPM sync
   - **Write to Pattern** - Export progression to pattern editor

7. **Keyboard Shortcuts:**
   - **Space** - Play/Stop
   - **Esc** - Stop
   - **A** - Audition selected slot
   - **Ctrl+C** - Copy slot
   - **Ctrl+V** - Paste slot
   - **Ctrl+W** - Write to pattern
   - **Shift+Up/Down** - Move slot up/down

**Write to Pattern Features:**
- Clears entire track first (prevents duplicates)
- Auto-expands note columns as needed (up to 12)
- Respects LPB for timing
- **Strum Modes:**
  - **Rows:** Notes on separate rows with fractional delays
  - **Delays:** All notes on same row with 00-FF delay spread
- Writes velocity to volume column (00-7F hex)
- Extra notes written to additional columns
- Intelligent note-off placement (only when needed)
- Pattern length validation with status feedback

**Technical Details:**
- BPM-synced timing (60000ms / BPM = beat duration)
- Real-time timer management (prevents note overlap)
- Velocity normalization (0-127 → 0.0-1.0 for `trigger_instrument_note_on`)
- Deep copy for copy/paste operations
- Visual playhead tracking
- Safe cleanup on stop (removes all timers and note-offs)

**Use Cases:**
- Chord progression experimentation
- Genre-specific progressions
- Bass + melody layering (EX1 + EX2)
- Strum patterns for guitar/pluck sounds
- Pattern template generation
- Live performance with loop mode
- Musical sketching and arrangement

**Requirements:** Renoise API 6.2+ (uses `.color` and `tooltip` properties)

---

# The Paketti Story

**Paketti** represents **14 years of continuous development** (2011-2025) by esaruoho, taking notes of:
- **Impulse Tracker** by Jeffrey Lim
- **dBlue's** Renoise tools
- **Martblek's** Renoise tools
- **Joule's** Renoise tools
- **OctaMED** by Teijo Kinnunen
- **Protracker, FastTracker 2, ModPlug Tracker (OpenMPT)**
- The entire **tracker music community**

---

# Support

If you liked what you're seeing here, please consider supporting. Every bit helps.

- [Patreon](http://patreon.com/esaruoho) - Join as a monthly supporter - it really adds up and helps me. There are different level tiers from 3€ to 7€ to 10€ to 20€ to 30€ to 50€ to 100€ to 300€.
- [GitHub Sponsors](https://github.com/sponsors/esaruoho) - Be the first one to become a Paketti GitHub Sponsor.
- [PayPal](http://paypal.me/esaruoho) - Anything is welcome.
- [Ko-Fi](https://ko-fi.com/esaruoho) - A one-time donation / a monthly donation
- [Buy Me a Coffee](https://buymeacoffee.com/esaruoho) - A one-time donation / a monthly donation
- [Gumroad](https://lackluster.gumroad.com/l/paketti) - I've listed Paketti up on Gumroad so you can make a one-time purchase.
- [Bandcamp](http://lackluster.bandcamp.com/) and [Bandcamp](http://hler.bandcamp.com/) - You can just buy the music from these.

📖 **Navigation:** [Paketti README](index.html) | [Changeslog](CHANGESLOG.html) | Experimental (You are here)
