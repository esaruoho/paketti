# Pure Gherkin test extracted from features/sample-slice-menu-grouping.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/sample-slice-menu-grouping.feature

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
