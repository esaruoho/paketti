# Paketti — cross-orifice coverage (what's left on the table)

*The three doors to a feature — keyboard shortcut · MIDI mapping · menu entry — matched by action name (from the running code). A feature behind only one door is unreachable through the others.*

## The whole surface: 12,059 distinct actions

| reachable by | count | meaning |
|---|--:|---|
| **KME** | 390 | all three (keyboard + MIDI + menu) |
| **KE** | 915 | keyboard + menu (no MIDI) |
| **KM** | 3,650 | keyboard + MIDI (no menu) |
| **ME** | 145 | MIDI + menu (no keyboard) |
| **K** | 2,679 | keyboard ONLY — no MIDI, no menu |
| **E** | 1,698 | menu ONLY — mouse-only, no shortcut |
| **M** | 2,582 | MIDI ONLY |

- **Keyboard-reachable:** 7,634 · **MIDI-reachable:** 6,767 · **Menu-reachable:** 3,148
- **Shortcut but NO MIDI mapping:** 3,594 actions (controller users can't reach these)
- **Shortcut but NO menu:** 6,329 actions (undiscoverable by browsing menus)
- **Menu but NO shortcut:** 1,843 actions (mouse-only; no keyboard access)
- **MIDI but NO shortcut:** 2,727 actions

## Per Renoise region — keyboard shortcuts vs the other doors

For each region's **keyboard shortcuts**: how many also have a MIDI mapping, how many also have a menu entry, and how many are **keyboard-only** (the gap).

| Region | shortcuts | also MIDI | also menu | keyboard-ONLY |
|---|--:|--:|--:|--:|
| Global | 6,457 | 3,582 | 0 | **2,875** |
| Pattern Editor | 1,235 | 642 | 229 | **467** |
| Phrase Editor | 408 | 209 | 47 | **161** |
| Sample Keyzones | 268 | 22 | 0 | **246** |
| Sample Editor | 262 | 89 | 127 | **103** |
| Instrument Box | 243 | 0 | 0 | **243** |
| Pattern Matrix | 183 | 152 | 29 | **20** |
| Mixer | 175 | 92 | 25 | **62** |
| Pattern Sequencer | 42 | 14 | 32 | **7** |

## Biggest gaps — keyboard shortcuts with NO MIDI mapping (sample)

These have a keyboard shortcut but **no MIDI equivalent** — add MIDI mappings and they become controller-reachable:

**Pattern Editor** — 593 keyboard-only of 1,235 shortcuts. e.g.:
- Automation Stack - Select Arbitrary Parameters...
- Automation Stack - Single View...
- Automation Stack - Stacker (Multi-Pattern)...
- Automation Stack...
- BPM Calculation Debug
- BPM Switcher Dialog...
- ChordsPlus
- ChordsPlus 12-12-12

**Sample Keyzones** — 246 keyboard-only of 268 shortcuts. e.g.:
- Delete Unused Samples
- Set All Samples in Selected Instrument to Beginning Half Loop
- Set All Samples in Selected Instrument to End-Half Loop
- Set All Samples in Selected Instrument to Full Loop
- Set Selected Instrument Transpose
- Set Selected Instrument Transpose to +1
- Set Selected Instrument Transpose to +10
- Set Selected Instrument Transpose to +100

**Instrument Box** — 243 keyboard-only of 243 shortcuts. e.g.:
- Set Selected Instrument Transpose
- Set Selected Instrument Transpose to +1
- Set Selected Instrument Transpose to +10
- Set Selected Instrument Transpose to +100
- Set Selected Instrument Transpose to +101
- Set Selected Instrument Transpose to +102
- Set Selected Instrument Transpose to +103
- Set Selected Instrument Transpose to +104

**Phrase Editor** — 199 keyboard-only of 408 shortcuts. e.g.:
- Apply Heavy Swing (75%) to Phrase
- Apply Humanize to Phrase
- Apply Light Swing (25%) to Phrase
- Apply Swing (50%) to Phrase
- Clipboard Dialog...
- Clipboard Paste from Pattern Slot 01
- Clipboard Paste from Pattern Slot 02
- Clipboard Paste from Pattern Slot 03

**Sample Editor** — 173 keyboard-only of 262 shortcuts. e.g.:
- Analyze Sample BPM
- Audio Diff
- BPM Calculation Debug
- Clip bottom of waveform
- Create New Instrument from Selection with Slices
- Create New Rhythmic Slice DrumChain from XRNI
- Create New Rhythmic Slice DrumChain with Current Slices
- Create New Rhythmic Slice DrumChain with Current Slices (Randomize)

**Mixer** — 83 keyboard-only of 175 shortcuts. e.g.:
- Clean Render Seamless Selected Track/Group
- Clean Render Selected Track/Group
- Clean Render Selected Track/Group LPB*2
- Clean Render&Save Selected Track/Group
- Create Group and Move DSPs
- Create Identical Track
- Create New Track with Channelstrip
- Double Double Phrase LPB

**Pattern Matrix** — 31 keyboard-only of 183 shortcuts. e.g.:
- Clear Unused Patterns
- Create New Track with Channelstrip
- Delete All Sequences Above
- Delete All Sequences Above and Below
- Delete All Sequences Below
- Duplicate Pattern Above & Clear Muted Tracks
- Duplicate Pattern Below & Clear Muted Tracks
- Impulse Tracker ALT-S Set Selection to Instrument
