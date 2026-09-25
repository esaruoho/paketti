# =============================================================================
# WIKI PAGE / REPORT CARD: Sample Editor slice menus live under Slices
#
# WHAT THIS CARD SPAWNS:
#   codespace  — Sample Editor menu-entry paths for Paketti slice commands
#   thinkspace — sample-slice-menu-grouping.session.md
#   areaspace  — OWNS: Sample Editor Paketti menu labels for slice-related commands
#                MUST NOT TOUCH: keybinding names, MIDI mappings, Sample Navigator,
#                Instrument Box, Main Menu, and Sample Editor Ruler registrations
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "sample-slice-menu-grouping"):
#   PakettiMenuConfig.lua - direct Sample Editor slice monitoring, deletion, oldschool, beatsync, and slices-to-pattern/phrase menu entries
#   PakettiManualSlicer.lua - Sample Editor Manual Slicer submenu entries
#   PakettiBeatsyncSeamless.lua - Sample Editor Beatsync Seamless submenu entries
#   PakettiSliceFades.lua - Sample Editor Slice Fades submenu entries
#   PakettiSliceSafely.lua - Sample Editor SliceSafely submenu entries
#   PakettiSliceToolsDialog.lua - Sample Editor Slice Tools dialog menu entry
#   PakettiSlicePro.lua - Sample Editor SlicePro apply/config/phrase menu entries
#   PakettiSlice.lua - Sample Editor Curved Slice Creator menu entry
#   PakettiSamples.lua - Sample Editor Isolate Slices menu entry
#
# Commit log:   worktree  Sample Editor slice menu grouping
# SESSION:      sample-slice-menu-grouping.session.md
# RESULT:       Feature delivery worktree (direct to main, no PR); card worktree
#
# WATCH: PakettiSliceMenus PakettiSliceFadeDialog SliceSafelyDialog PakettiSliceToolsDialog SliceProApplyOrConfig PakettiCurvedSliceCreator isolate_slices_play_all_together paketti_manual_slicer PakettiBeatsyncSeamlessAutoChop
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-25  direct-commit  touched: PakettiBeatsyncSeamlessAutoChop
#   2026-09-24  direct-commit  touched: SliceSafelyDialog PakettiSliceToolsDialog PakettiCurvedSliceCreator isolate_slices_play_all_together paketti_manual_slicer
# =============================================================================

Feature: Sample Editor slice menus live under Slices
  As a Paketti user, I want every Sample Editor slice command under one Slices branch, So that the menu is scannable and Renoise sees separator-prefixed entries correctly.

  @shipped @code-verified @runtime-untested
  Scenario: Direct Sample Editor slice actions are grouped under Slices
    # cite: PakettiMenuConfig.lua Sample Editor slice menu entries (~lines 188, 388, 942-992)
    # cite: PakettiSlice.lua PakettiCurvedSliceCreator menu entry (~line 4852)
    # cite: PakettiSamples.lua isolate_slices_play_all_together menu entry (~line 7813)
    Given Paketti registers direct Sample Editor slice commands
    When Renoise builds the Paketti Sample Editor menu
    Then those commands are registered below "Sample Editor:Paketti:Slices:"
    And the first entry of each separated direct slice group starts with "--Sample Editor"

  @shipped @code-verified @runtime-untested
  Scenario: Slice tool families remain separate inside Slices
    # cite: PakettiSliceFades.lua Slice Fades menu entries (~lines 193, 207-209)
    # cite: PakettiSliceSafely.lua SliceSafely menu entries (~lines 216-224)
    # cite: PakettiSliceToolsDialog.lua Slice Tools menu entry (~line 305)
    # cite: PakettiSlicePro.lua SlicePro menu entries (~lines 1498-1508, 1808-1813)
    Given Slice Fades, SliceSafely, Slice Tools, and SlicePro expose Sample Editor menu entries
    When those entries are registered
    Then each family remains in its own subfolder below "Sample Editor:Paketti:Slices:"
    And each family has at least one "--Sample Editor" separator-prefixed entry

  @shipped @code-verified @runtime-untested
  Scenario: Oldschool, manual, and beatsync slice tools are also under Slices
    # cite: PakettiMenuConfig.lua Oldschool Slice Pitch and Beatsync/Slices menu entries (~lines 917-932, 2232-2247, 2305)
    # cite: PakettiManualSlicer.lua Manual Slicer menu entries (~lines 1270-1278)
    # cite: PakettiBeatsyncSeamless.lua Beatsync Seamless menu entries (~lines 318, 335)
    Given slice-adjacent Sample Editor menu families register Oldschool Slice Pitch, Manual Slicer, Beatsync/Slices, and Beatsync Seamless commands
    When Paketti registers Sample Editor menu entries
    Then those families are below "Sample Editor:Paketti:Slices:"
    And each family keeps at least one "--Sample Editor" separator-prefixed entry

  @stock
  Scenario: Non-menu command surfaces keep their existing names
    # cite: PakettiOldschoolSlicePitch.lua Sample Editor keybindings (~lines 1863-1909)
    Given users have existing keybindings and MIDI mappings for slice workflows
    When the Sample Editor menu paths are regrouped
    Then keybinding and MIDI mapping names are not renamed by this change
