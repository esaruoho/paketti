# Report Card — Quick edit navigation commands

> Source: `features/quick-edit-navigation.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want repeated shortcuts to move editing state without modal setup, So that common tracker edits are fast and reversible enough to test live.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Repeat Select Chunk to advance inside that chunk

`@shipped @code-verified @runtime-untested`


- Given the cursor is already on an instrument inside a requested chunk such as 20-F0
- When the user triggers the same Select Chunk command again
- Then Paketti selects the next instrument inside that chunk
- And triggering past the chunk end wraps back to the chunk start

<sub>cite: PakettiInstrumentBox.lua select_chunk (~line 942) — advances within the requested 16-instrument chunk</sub>


## 2. Increment delay values from MIDI without overwriting them

`@shipped @code-verified @runtime-untested`


- Given the user has a note column or pattern selection
- When the user triggers a delay increment/decrement MIDI mapping
- Then Paketti adds the delta to existing delay values and clamps them to 00-FF
- And the existing absolute delay-value mapping remains separate

<sub>cite: PakettiPatternEditor.lua PakettiDelayColumnModifier (~line 4801) — adjusts selected delay values by a delta · PakettiPatternEditor.lua delay MIDI mappings (~line 4872) — exposes trigger and relative-knob increment mappings</sub>


## 3. Quantize selected notes onto triplet timing

`@shipped @code-verified @runtime-untested`


- Given the user has selected note-column content in the Pattern Editor
- When the user triggers Quantize Selection to Triplets
- Then Paketti moves each note to the nearest third-of-beat timing using row and delay values
- And collisions are moved into an empty note column or restored to their source column

<sub>cite: PakettiPatternEditor.lua PakettiQuantizeSelectionToTriplets (~line 4923) — moves note columns to nearest triplet tick</sub>


## 4. Existing direct chunk and delay controls remain available

`@stock`


- Given the existing Select Chunk and Delay Column keybindings are loaded
- When the user triggers them
- Then Paketti still exposes the same command names

<sub>cite: PakettiInstrumentBox.lua chunk binding loop (~line 972) — existing Select Chunk command family · PakettiPatternEditor.lua delay keybindings (~line 4868) — existing delay delta keybindings</sub>

