# Paketti — cross-orifice coverage (what's left on the table)

*The three doors to a feature — keyboard shortcut · MIDI mapping · menu entry — matched by action name (from the running code). A feature behind only one door is unreachable through the others.*

## The whole surface: 11,567 distinct actions

| reachable by | count | meaning |
|---|--:|---|
| **KME** | 305 | all three (keyboard + MIDI + menu) |
| **KE** | 989 | keyboard + menu (no MIDI) |
| **KM** | 3,573 | keyboard + MIDI (no menu) |
| **ME** | 44 | MIDI + menu (no keyboard) |
| **K** | 2,724 | keyboard ONLY — no MIDI, no menu |
| **E** | 1,778 | menu ONLY — mouse-only, no shortcut |
| **M** | 2,154 | MIDI ONLY |

- **Keyboard-reachable:** 7,591 · **MIDI-reachable:** 6,076 · **Menu-reachable:** 3,116
- **Shortcut but NO MIDI mapping:** 3,713 actions (controller users can't reach these)
- **Shortcut but NO menu:** 6,297 actions (undiscoverable by browsing menus)
- **Menu but NO shortcut:** 1,822 actions (mouse-only; no keyboard access)
- **MIDI but NO shortcut:** 2,198 actions

## Per Renoise region — keyboard shortcuts vs the other doors

For each region's **keyboard shortcuts**: how many also have a MIDI mapping, how many also have a menu entry, and how many are **keyboard-only** (the gap).

| Region | shortcuts | also MIDI | also menu | keyboard-ONLY |
|---|--:|--:|--:|--:|
| Global | 6,402 | 3,485 | 0 | **2,917** |
| Pattern Editor | 1,224 | 582 | 228 | **468** |
| Phrase Editor | 409 | 203 | 47 | **168** |
| Sample Editor | 262 | 79 | 127 | **105** |
| Sample Navigator | 261 | 16 | 3 | **242** |
| Sample Mappings | 245 | 0 | 0 | **245** |
| Instrument Box | 243 | 0 | 0 | **243** |
| Pattern Matrix | 183 | 152 | 29 | **20** |
| Mixer | 175 | 91 | 25 | **63** |
| Pattern Sequencer | 42 | 14 | 32 | **7** |
| Sample Keyzones | 23 | 22 | 0 | **1** |

## Biggest gaps — keyboard shortcuts with NO MIDI mapping (sample)

These have a keyboard shortcut but **no MIDI equivalent** — add MIDI mappings and they become controller-reachable:

**Pattern Editor** — 642 keyboard-only of 1,224 shortcuts. e.g.:
- Apply Note Column Sample Effects M00/MFF
- Apply User-Set Tuning to Selected Track
- Automation Stack - Select Arbitrary Parameters...
- Automation Stack - Single View...
- Automation Stack - Stacker (Multi-Pattern)...
- Automation Stack...
- BPM Calculation Debug
- BPM Switcher Dialog...

**Sample Navigator** — 245 keyboard-only of 261 shortcuts. e.g.:
- Set All Samples in Selected Instrument to Beginning Half Loop
- Set All Samples in Selected Instrument to End-Half Loop
- Set All Samples in Selected Instrument to Full Loop
- Set Selected Instrument Transpose
- Set Selected Instrument Transpose to +1
- Set Selected Instrument Transpose to +10
- Set Selected Instrument Transpose to +100
- Set Selected Instrument Transpose to +101

**Sample Mappings** — 245 keyboard-only of 245 shortcuts. e.g.:
- Set All Samples in Selected Instrument to Beginning Half Loop
- Set All Samples in Selected Instrument to End-Half Loop
- Set All Samples in Selected Instrument to Full Loop
- Set Selected Instrument Transpose
- Set Selected Instrument Transpose to +1
- Set Selected Instrument Transpose to +10
- Set Selected Instrument Transpose to +100
- Set Selected Instrument Transpose to +101

**Instrument Box** — 243 keyboard-only of 243 shortcuts. e.g.:
- Set Selected Instrument Transpose
- Set Selected Instrument Transpose to +1
- Set Selected Instrument Transpose to +10
- Set Selected Instrument Transpose to +100
- Set Selected Instrument Transpose to +101
- Set Selected Instrument Transpose to +102
- Set Selected Instrument Transpose to +103
- Set Selected Instrument Transpose to +104

**Phrase Editor** — 206 keyboard-only of 409 shortcuts. e.g.:
- Apply Heavy Swing (75%) to Phrase
- Apply Humanize to Phrase
- Apply Light Swing (25%) to Phrase
- Apply Swing (50%) to Phrase
- Clipboard Dialog...
- Clipboard Paste from Pattern Slot 01
- Clipboard Paste from Pattern Slot 02
- Clipboard Paste from Pattern Slot 03

**Sample Editor** — 183 keyboard-only of 262 shortcuts. e.g.:
- 15 Frame Fade In & Fade Out
- Analyze Sample BPM
- Audio Diff
- BPM Calculation Debug
- Clip bottom of waveform
- Convert Beatsync to Sample Pitch
- Create New Instrument from Selection with Slices
- Create New Rhythmic Slice DrumChain from XRNI

**Mixer** — 84 keyboard-only of 175 shortcuts. e.g.:
- Clean Render Seamless Selected Track/Group
- Clean Render Selected Track/Group
- Clean Render Selected Track/Group LPB*2
- Clean Render&Save Selected Track/Group
- Create Group and Move DSPs
- Create Identical Track
- Create New Track with Channelstrip
- Double Double Phrase LPB
