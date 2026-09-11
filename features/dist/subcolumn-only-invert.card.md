# Report Card — Subcolumn-only pattern inversion

> Source: `features/subcolumn-only-invert.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Pattern Editor user, I want to invert one note subcolumn at a time, So that volume, pan, delay, or sample-FX edits do not disturb the others.

**Grades:** @code-verified × 2 · @runtime-untested × 2 · @shipped × 2 · @stock × 1

**Scenarios: 3**


---


## 1. Invert only the requested note subcolumn

`@shipped @code-verified @runtime-untested`


- Given a pattern selection exists, or no selection exists and the selected track is used
- When the user triggers one of the specific subcolumn inversion commands
- Then Paketti changes only that subcolumn's value range
- And the other note-column subcolumns are left unchanged

<sub>cite: PakettiRequests.lua invert_content_subcolumn (~line 9693) — dispatches volume, panning, delay, and samplefx inversion</sub>


## 2. Reach the specific invert commands from the Pattern Editor menu

`@shipped @code-verified @runtime-untested`


- Given Paketti menu entries are loaded
- When the user opens the Pattern Editor Note Columns menu
- Then the volume-only, panning-only, delay-only, and sample-FX-only invert commands are present

<sub>cite: PakettiMenuConfig.lua Pattern Editor invert menu entries (~line 2816) — exposes the four commands</sub>


## 3. Existing broad inversion commands remain available

`@stock`


- Given the user wants to invert every note-column subcolumn or effect-column amount
- When the user triggers the existing broad invert commands
- Then Paketti still runs the original all/note/effect inversion behavior

<sub>cite: PakettiRequests.lua invert_content (~line 9612) — existing all/note/effect inversion path</sub>

