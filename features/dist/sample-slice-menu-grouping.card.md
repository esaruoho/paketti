# Report Card — Sample Editor slice menus live under Slices

> Source: `features/sample-slice-menu-grouping.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want every Sample Editor slice command under one Slices branch, So that the menu is scannable and Renoise sees separator-prefixed entries correctly.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Direct Sample Editor slice actions are grouped under Slices

`@shipped @code-verified @runtime-untested`


- Given Paketti registers direct Sample Editor slice commands
- When Renoise builds the Paketti Sample Editor menu
- Then those commands are registered below "Sample Editor:Paketti:Slices:"
- And the first entry of each separated direct slice group starts with "--Sample Editor"

<sub>cite: PakettiMenuConfig.lua Sample Editor slice menu entries (~lines 188, 388, 942-992) · PakettiSlice.lua PakettiCurvedSliceCreator menu entry (~line 4852) · PakettiSamples.lua isolate_slices_play_all_together menu entry (~line 7813)</sub>


## 2. Slice tool families remain separate inside Slices

`@shipped @code-verified @runtime-untested`


- Given Slice Fades, SliceSafely, Slice Tools, and SlicePro expose Sample Editor menu entries
- When those entries are registered
- Then each family remains in its own subfolder below "Sample Editor:Paketti:Slices:"
- And each family has at least one "--Sample Editor" separator-prefixed entry

<sub>cite: PakettiSliceFades.lua Slice Fades menu entries (~lines 193, 207-209) · PakettiSliceSafely.lua SliceSafely menu entries (~lines 216-224) · PakettiSliceToolsDialog.lua Slice Tools menu entry (~line 305) · PakettiSlicePro.lua SlicePro menu entries (~lines 1498-1508, 1808-1813)</sub>


## 3. Oldschool, manual, and beatsync slice tools are also under Slices

`@shipped @code-verified @runtime-untested`


- Given slice-adjacent Sample Editor menu families register Oldschool Slice Pitch, Manual Slicer, Beatsync/Slices, and Beatsync Seamless commands
- When Paketti registers Sample Editor menu entries
- Then those families are below "Sample Editor:Paketti:Slices:"
- And each family keeps at least one "--Sample Editor" separator-prefixed entry

<sub>cite: PakettiMenuConfig.lua Oldschool Slice Pitch and Beatsync/Slices menu entries (~lines 917-932, 2232-2247, 2305) · PakettiManualSlicer.lua Manual Slicer menu entries (~lines 1270-1278) · PakettiBeatsyncSeamless.lua Beatsync Seamless menu entries (~lines 318, 335)</sub>


## 4. Non-menu command surfaces keep their existing names

`@stock`


- Given users have existing keybindings and MIDI mappings for slice workflows
- When the Sample Editor menu paths are regrouped
- Then keybinding and MIDI mapping names are not renamed by this change

<sub>cite: PakettiOldschoolSlicePitch.lua Sample Editor keybindings (~lines 1863-1909)</sub>

