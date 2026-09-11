# Report Card — Groovebox 8120 Kit loader status column alignment

> Source: `features/2026-06-11-ui-fixes-and-menu-config.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @built × 8 · @runtime-verified × 8

**Scenarios: 8**


---


## 1. Per-part status lines align the "Loading/Queued" column

`@built @runtime-verified`


- Given the Kit loader shows "Part N/8 [Category]: Loading ..." for 8 categories
- And category names vary in width (Kick=4 .. Rimshot=7)
- When a status line is built
- Then the "[name]" field is space-padded to the widest category name
- And every line's text after the bracket starts at the same column
- Feature: Groovebox 8120 step-repeat fills the final pattern row

<sub>cite: PakettiEightOneTwenty.lua note-trigger writer (~2251) + phrase-trigger writer (~8204) | commit 6594dfc</sub>


## 2. Trailing partial block is written when steps do not divide pattern length

`@built @logic-verified @runtime-verified`


- Given a 64-row pattern and a row step count of 3
- And full_repeats = floor(64/3) = 21 complete blocks cover lines 1..63
- When the writer finishes the full blocks
- Then the remainder (64 - 21*3 = 1 line) is filled from the block's leading steps
- And the last pattern row (Lua line 64 / display row 63) receives its trigger
- Feature: Wipe/Clear All Automation discoverable from the Automation List

<sub>cite: PakettiRequests.lua delete_automation registration loop (~10246) | commit 656f65a</sub>


## 3. Track Automation List + lane expose the wipe/clear commands

`@built @runtime-verified`


- Given delete_automation(all_tracks, whole_song) already exists
- When the Track Automation List or Track Automation lane is right-clicked
- Then "Wipe All Automation in Track/All Tracks on Current Pattern/Whole Song" appear
- And "Clear All Automation in Current Track" / "...for All Patterns" appear as synonyms
- And Global keybindings exist for the Clear variants
- Feature: Paketti Toggler lists every menu category, alphabetically

<sub>cite: Paketti0G01_Loader.lua PakettiTogglerDialog generated-checkbox block | commit d920bb8 (later superseded — see next)</sub>


## 4. Generated from the canonical list instead of a hardcoded subset

`@built @runtime-verified`


- Given the canonical list has 24 categories incl. TrackAutomationList
- When the Toggler dialog is built
- Then a checkbox is generated for every category, sorted by label
- Feature: Groovebox 8120 Canvas View survives a step-mode downshift

<sub>cite: PakettiEightOneTwenty.lua cv_read_row_steps clamp | commit c9dbddb</sub>


## 5. A lane's step count above the active MAX_STEPS no longer crashes the view

`@built @logic-verified @runtime-verified`


- Given a lane set to 32 steps while MAX_STEPS is now 16
- When the Canvas View builds the per-lane step valuebox (max = MAX_STEPS)
- Then cv_read_row_steps clamps the read into [1, MAX_STEPS]
- And the valuebox receives a valid initial value (no "invalid value ... [1-16]")
- And the lane's real 32 is preserved (classic box max=512) until changed in-canvas
- Feature: Paketti Toggler drops the duplicated menu-category grid

<sub>cite: Paketti0G01_Loader.lua PakettiTogglerDialog menu-categories section replaced by a link | commit 4675249</sub>


## 6. Per-context menu toggles live only in Menu Configuration now

`@built @runtime-verified`


- Given Menu Configuration owns the per-context menu on/off
- When the Toggler dialog is built
- Then the duplicate category grid is gone
- And a "Open Paketti Menu Configuration..." button replaces it
- And the Toggler keeps counts, master Menu/Key/MIDI toggles, and Import Hooks
- Feature: Paketti Menu Configuration shows per-category entry counts + bulk toggles

<sub>cite: Paketti0G01_Loader.lua PakettiCountMenuEntriesByCategory + pakettiMenuConfigDialog | commit 0f506fd</sub>


## 7. Each category checkbox shows its source-counted entry total

`@built @runtime-verified`


- Given every Paketti .lua source is scanned once (memoized)
- And both add_menu_entry and PakettiAddMenuEntry calls are counted
- When the Menu Configuration dialog opens
- Then each checkbox reads "<Category> (<N>)" and a header gives the grand total
- And "Enable All Menus (N)" / "Disable All Menus (N)" flip every category + refresh
- Feature: Preferences "Pattern Editor" section shows all eight settings

<sub>cite: Paketti0G01_Loader.lua dialog_content column-1 Pattern Editor rows (~1661) | commit f9472bd</sub>


## 8. No setting is clipped by the fixed first-column width

`@built @runtime-verified`


- Given the section lives in column 1 (width=column1_width=430)
- And a 3-text+checkbox row (~544px) overflows and is clipped
- When the 8 settings are laid out two-per-row (~356px each)
- Then Trigger on Input and SBx Pattern Loop Follow render fully
- And every checkbox fits within the 430px column

