# Report Card — Sample slice selection range

> Source: `features/sample-slice-selection.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Sample Editor user, I want one command that selects the current slice boundaries, So that loop and beat-sync work can start from the exact slice range.

**Grades:** @code-verified × 2 · @runtime-untested × 2 · @shipped × 2 · @stock × 1

**Scenarios: 3**


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


## 3. Existing slice marker deletion remains separate

`@stock`


- Given the user triggers Delete Slice Markers in Selection
- When Paketti deletes slice markers
- Then the new slice selection helper is not involved

<sub>cite: PakettiSlice.lua pakettiDeleteSliceMarkersInSelection (~line 1) — pre-existing deletion command</sub>

