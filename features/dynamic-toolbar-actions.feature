# =============================================================================
# WIKI PAGE / REPORT CARD: Dynamic Macro Toolbar action safety
#
# WHAT THIS CARD SPAWNS:
#   codespace  - PakettiDynamicMacroToolbar.lua string action dispatch and
#                PakettiMainMenuEntries.lua Dialog-of-Dialogs action registry
#   thinkspace - dynamic-toolbar-actions.session.md (bug report, preset picker request,
#                diagnosis, and fix audit)
#   areaspace  - OWNS: toolbar execution of configured dialog action names and
#                10-slot chunk preset selection
#                MUST NOT TOUCH: Groovebox 8ch960samp internal selection verbs
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "dynamic-toolbar-actions"):
#   PakettiDynamicMacroToolbar.lua - execute_action strict-safe string lookup
#   PakettiDynamicMacroToolbar.lua - DynamicMacro preset dropdown and chunk loader
#   PakettiMainMenuEntries.lua - create_button_list excludes Groovebox-only sub-dialogs
#
# Commit log:   pending until implementation commit
# SESSION:      dynamic-toolbar-actions.session.md
# RESULT:       Feature delivery pending (direct push, no PR); card pending
#
# WATCH: execute_action create_button_list DynamicMacroToolbar show_euclid_dialog list_preset_records load_preset save_preset
#
# RESULT-LOG >> (auto-maintained by the report-card hooks - newest below)
#   2026-09-28  direct-commit  touched: DynamicMacroToolbar
#   2026-09-28  direct-commit  touched: DynamicMacroToolbar
#   2026-09-28  direct-commit  touched: DynamicMacroToolbar
#   2026-09-27  direct-commit  touched: DynamicMacroToolbar list_preset_records load_preset
#   2026-09-26  direct-commit  touched: DynamicMacroToolbar
#   2026-09-25  direct-commit  touched: DynamicMacroToolbar show_euclid_dialog
# =============================================================================

Feature: Dynamic Macro Toolbar action safety
  As a Paketti user, I want Dynamic Macro Toolbar slots to handle dialog action names and 10-slot chunks safely, So that internal Groovebox sub-dialogs are not surfaced as standalone dialogs, missing helpers do not crash Renoise, and saved macro banks can be picked directly.

  @shipped @built @code-verified @runtime-untested
  Scenario: Missing string action names report status instead of throwing strict-global errors
    # cite: PakettiDynamicMacroToolbar.lua execute_action (~line 56) - uses rawget(_G, func_ref) before checking function type
    Given a Dynamic Macro Toolbar slot stores a dialog action whose function name is not declared globally
    When the slot is triggered
    Then Paketti does not read the name through the strict global metatable
    And the toolbar reports "Function not found" instead of raising a stack traceback

  @shipped @built @code-verified @runtime-untested
  Scenario: Groovebox-only Euclidean Fill is not advertised as a standalone toolbar action
    # cite: PakettiMainMenuEntries.lua create_button_list (~line 277) - Dialog-of-Dialogs registry does not insert "Euclidean Fill" -> "show_euclid_dialog"
    Given the Dynamic Macro Toolbar builds its assignable action list from the Dialog-of-Dialogs registry
    When the action list is built
    Then the Groovebox 8ch960samp internal Euclidean Fill helper is not offered as a standalone dialog action
    And the Groovebox prototype's own Euclid button remains owned by PakettiGroovebox8ch960samp.lua

  @stock
  Scenario: Valid global dialog functions still execute from toolbar slots
    # cite: PakettiDynamicMacroToolbar.lua execute_action (~line 56) - existing pcall dispatch remains unchanged after lookup
    Given a Dynamic Macro Toolbar slot stores a valid globally declared dialog function name
    When the slot is triggered
    Then the toolbar calls that function through pcall
    And errors from the called function are still shown in the Renoise status line

  @shipped @built @code-verified @runtime-untested
  Scenario: DynamicMacro folder presets can be selected as 10-slot chunks
    # cite: PakettiDynamicMacroToolbar.lua list_preset_records (~line 159) - reads DynamicMacro first and legacy presets second
    # cite: PakettiDynamicMacroToolbar.lua build_toolbar_content (~line 277) - exposes preset_items in the toolbar popup
    # cite: PakettiDynamicMacroToolbar.lua load_preset (~line 208) - writes each preset line into PakettiDMTSlot01..10 and clears the remainder
    Given the Paketti bundle contains a DynamicMacro folder with .txt chunk preset files
    When the Dynamic Macro Toolbar is opened
    Then the toolbar shows those chunk presets in a dropdown bar
    And selecting a preset loads its ten slot assignments into the visible toolbar buttons
    And presets from the older DynamicMacroToolbar_Presets folder remain readable as a fallback
