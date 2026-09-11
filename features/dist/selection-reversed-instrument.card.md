# Report Card — Reverse-duplicate instrument for pattern selections

> Source: `features/selection-reversed-instrument.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want one Pattern Editor action that makes a reversed copy of the current instrument and points my selected notes at it, So that I can turn a selected phrase into a reversed-instrument variation without manual instrument reassignment.

**Grades:** @built × 3 · @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Active pattern selection is retargeted to the reversed duplicate

`@shipped @built @code-verified @runtime-untested`


- Given a pattern selection is active
- And the selected instrument contains samples
- When the user invokes "Pattern Editor:Paketti:Duplicate and Reverse Instrument for Selection"
- Then Paketti creates a reversed duplicate of the selected instrument
- And note events inside the selected note columns and selected line range use the reversed duplicate instrument number

<sub>cite: PakettiSamples.lua PakettiDuplicateReverseInstrumentForSelection (~line 2603) - calls the existing reverse duplicate helper, then sets selected note instrument values to the new instrument ; commit worktree</sub>


## 2. Missing pattern selection is rejected before duplication

`@shipped @built @code-verified @runtime-untested`


- Given there is no active pattern selection
- When the user invokes the selection-aware reverse duplicate command
- Then Paketti shows "No selection in the pattern."
- And no instrument is duplicated

<sub>cite: PakettiSamples.lua PakettiDuplicateReverseInstrumentForSelection (~line 2603) - checks song.selection_in_pattern before duplicating ; commit worktree</sub>


## 3. Command is discoverable from Pattern Editor

`@shipped @built @code-verified @runtime-untested`


- Given the Paketti tool is installed
- When Renoise lists Pattern Editor shortcuts and menus
- Then the shortcut action is named "Pattern Editor:Paketti:Duplicate and Reverse Instrument for Selection"
- And the menu item is "Pattern Editor:Paketti:Instruments:Duplicate and Reverse Instrument for Selection"

<sub>cite: PakettiSamples.lua keybinding registration (~line 2662) - registers the Pattern Editor shortcut action ; commit worktree · PakettiMenuConfig.lua menu registration (~line 2821) - registers the Pattern Editor Instruments menu item ; commit worktree</sub>


## 4. Existing global duplicate-and-reverse command stays available

`@stock`


- Given any selected instrument with samples
- When the user invokes "Global:Paketti:Duplicate and Reverse Instrument"
- Then Paketti still duplicates the instrument, reverses the sample data, and selects the reversed copy

<sub>cite: PakettiSamples.lua PakettiDuplicateAndReverseInstrument (~line 2506) - unchanged existing global command ; commit worktree</sub>

