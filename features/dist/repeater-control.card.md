# Report Card — Repeater control from keys and MIDI

> Source: `features/repeater-control.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a live performer, I want Repeater controls available from keybindings and MIDI, So that repeat effects can be punched in without opening the device chain.

**Grades:** @code-verified × 4 · @runtime-untested × 4 · @shipped × 4 · @stock × 1

**Scenarios: 5**


---


## 1. Selected-track Repeater actions can enable, bypass, toggle, set mode, step divisor, and toggle sync mode

`@shipped @code-verified @runtime-untested`


- Given the user invokes a selected-track Repeater action
- When the selected track has no Repeater and the action needs an active device
- Then Paketti inserts the native Repeater on the selected track
- And the action updates the requested Repeater state

<sub>cite: PakettiMidi.lua PakettiRepeaterAddActionKeybindings / PakettiRepeaterAddActionMidiMappings - registers selected-track action surface</sub>


## 2. Master-track Repeater actions target the master track instead of the selected track

`@shipped @code-verified @runtime-untested`


- Given the user invokes a Repeater Master action
- When Paketti needs a target track
- Then Paketti resolves the song's master track and applies the command there

<sub>cite: PakettiMidi.lua PakettiRepeaterGetMasterTrack / PakettiRepeaterGetTargetTrack - resolves the master target</sub>


## 3. Per-division MIDI buttons stamp or hold Repeater presets

`@shipped @code-verified @runtime-untested`


- Given a mapped MIDI button for a Repeater divisor and mode
- When the direct mapping is triggered
- Then Paketti sets that divisor and mode, or bypasses the Repeater if the same active preset is triggered again
- When the Hold mapping receives a non-zero absolute value followed by zero
- Then Paketti activates the preset on press and bypasses it on release

<sub>cite: PakettiMidi.lua PakettiRepeaterAddPresetMidiMappings - registers direct and Hold mappings for each Even/Triplet/Dotted divisor preset</sub>


## 4. Free Divisor MIDI knob switches Repeater to Free mode before changing divisor

`@shipped @code-verified @runtime-untested`


- Given the Free Divisor MIDI mapping receives an absolute MIDI value
- When the target Repeater exists or can be inserted
- Then Paketti switches the Repeater to Free mode and maps the knob value to a divisor

<sub>cite: PakettiMidi.lua PakettiRepeaterSetFreeDivisorFromMidi - maps 0..127 across the Repeater divisor list with mode value 1</sub>


## 5. Existing Set Repeater Value knob mappings keep their selected-track behavior

`@stock`


- Given the user moves an existing Set Repeater Value knob mapping
- When the value is in the old OFF or divisor/mode range
- Then the existing selected-track knob path still handles it

<sub>cite: PakettiMidi.lua update_repeater_with_midi_value / get_time_division_from_midi - unchanged legacy knob path</sub>

