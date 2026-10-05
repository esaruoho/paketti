# Report Card — Sample slice selection range

> Source: `features/sample-slice-selection.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Sample Editor user, I want one command that selects the current slice boundaries, So that loop and beat-sync work can start from the exact slice range.

**Grades:** @code-verified × 4 · @runtime-untested × 4 · @shipped × 4 · @stock × 1

**Scenarios: 5**


---


## 1. Select the current slice range

`@shipped @code-verified @runtime-untested`


- Given the selected sample has sample data and slice markers
- When the user triggers Select Current Slice Range
- Then Paketti sets the sample buffer selection start and end to that slice's boundaries
- And the last slice ends at the sample buffer end

<sub>cite: PakettiSlice.lua PakettiSelectCurrentSliceRange (~line 82) — maps selected/current slice to buffer selection</sub>


## 2. Expose the slice range command

`@shipped @code-verified @runtime-untested`


- Given Paketti has loaded its Sample Editor tools
- When the user looks for slice selection commands
- Then the command is available as Sample Editor and Global keybindings, MIDI mapping, and Sample Editor menu entry

<sub>cite: PakettiSlice.lua command registrations (~line 129) — keybinding and MIDI mapping · PakettiMenuConfig.lua Sample Editor Wipe&Slice menu (~line 2190) — menu entry</sub>


## 3. Map a MIDI knob to a one-frame sample-buffer selection

`@shipped @code-verified @runtime-untested`


- Given the selected sample has sample data
- When the user moves Sample Editor:Paketti:Sample Buffer Selection Point 0-127 x[Knob]
- Then Paketti maps MIDI value 0 to frame 1 and MIDI value 127 to the sample buffer's final frame
- And Paketti focuses the Sample Editor
- And the sample-buffer selection is exactly one frame long

<sub>cite: PakettiMidi.lua PakettiMidiSampleBufferPointSelection (~line 911) — validates selected sample, focuses Sample Editor, and writes selection_range = {frame, frame} · PakettiMIDIMappings.lua PakettiMidiMappings (~line 157) — exposes the mapping in discovery</sub>


## 4. Clearing sample selection after deleting a sample is harmless

`@shipped @code-verified @runtime-untested`


- Given the Sample Editor has focus after the selected sample was deleted
- When the user triggers Unmark / Clear Selection
- Then Paketti reports that no sample data is available for selection clearing
- And it does not dereference an empty sample buffer

<sub>cite: PakettiSamples.lua pakettiSampleEditorSelectionClear (~line 7055) — validates selected sample and buffer data before clearing selection_range</sub>


## 5. Existing slice marker deletion remains separate

`@stock`


- Given the user triggers Delete Slice Markers in Selection
- When Paketti deletes slice markers
- Then the new slice selection helper is not involved

<sub>cite: PakettiSlice.lua pakettiDeleteSliceMarkersInSelection (~line 1) — pre-existing deletion command</sub>

