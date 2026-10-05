# Report Card — Dynamic Macro Toolbar action safety

> Source: `features/dynamic-toolbar-actions.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want Dynamic Macro Toolbar slots to handle dialog action names and 10-slot chunks safely, So that internal Groovebox sub-dialogs are not surfaced as standalone dialogs, missing helpers do not crash Renoise, and saved macro banks can be picked directly.

**Grades:** @built × 3 · @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Missing string action names report status instead of throwing strict-global errors

`@shipped @built @code-verified @runtime-untested`


- Given a Dynamic Macro Toolbar slot stores a dialog action whose function name is not declared globally
- When the slot is triggered
- Then Paketti does not read the name through the strict global metatable
- And the toolbar reports "Function not found" instead of raising a stack traceback

<sub>cite: PakettiDynamicMacroToolbar.lua execute_action (~line 56) - uses rawget(_G, func_ref) before checking function type</sub>


## 2. Groovebox-only Euclidean Fill is not advertised as a standalone toolbar action

`@shipped @built @code-verified @runtime-untested`


- Given the Dynamic Macro Toolbar builds its assignable action list from the Dialog-of-Dialogs registry
- When the action list is built
- Then the Groovebox 8ch960samp internal Euclidean Fill helper is not offered as a standalone dialog action
- And the Groovebox prototype's own Euclid button remains owned by PakettiGroovebox8ch960samp.lua

<sub>cite: PakettiMainMenuEntries.lua create_button_list (~line 277) - Dialog-of-Dialogs registry does not insert "Euclidean Fill" -> "show_euclid_dialog"</sub>


## 3. Valid global dialog functions still execute from toolbar slots

`@stock`


- Given a Dynamic Macro Toolbar slot stores a valid globally declared dialog function name
- When the slot is triggered
- Then the toolbar calls that function through pcall
- And errors from the called function are still shown in the Renoise status line

<sub>cite: PakettiDynamicMacroToolbar.lua execute_action (~line 56) - existing pcall dispatch remains unchanged after lookup</sub>


## 4. DynamicMacro folder presets can be selected as 10-slot chunks

`@shipped @built @code-verified @runtime-untested`


- Given the Paketti bundle contains a DynamicMacro folder with .txt chunk preset files
- When the Dynamic Macro Toolbar is opened
- Then the toolbar shows those chunk presets in a dropdown bar
- And selecting a preset loads its ten slot assignments into the visible toolbar buttons
- And presets from the older DynamicMacroToolbar_Presets folder remain readable as a fallback

<sub>cite: PakettiDynamicMacroToolbar.lua list_preset_records (~line 159) - reads DynamicMacro first and legacy presets second · PakettiDynamicMacroToolbar.lua build_toolbar_content (~line 277) - exposes preset_items in the toolbar popup · PakettiDynamicMacroToolbar.lua load_preset (~line 208) - writes each preset line into PakettiDMTSlot01..10 and clears the remainder</sub>

