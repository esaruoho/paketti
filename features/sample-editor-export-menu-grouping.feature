# =============================================================================
# WIKI PAGE / REPORT CARD: Sample Editor export menus live under Export
#
# WHAT THIS CARD SPAWNS:
#   codespace  — Sample Editor menu-entry paths for save/export/Ableton/Octatrack conversion commands
#   thinkspace — sample-editor-export-menu-grouping.session.md
#   areaspace  — OWNS: Sample Editor Paketti menu labels for export and conversion commands
#                MUST NOT TOUCH: keybinding names, MIDI mappings, Main Menu, Disk Browser,
#                Instrument Box, Sample Navigator, and Sample Mappings registrations
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "sample-editor-export-menu-grouping"):
#   PakettiMenuConfig.lua - core Sample Editor Export and Export:Convert entries
#   PakettiRX2Encode.lua - REX2 export menu entry
#   PakettiAbleton.lua - Ableton Simpler and Drum Rack export entries
#   PakettiSlicedImport.lua - AIFF-with-slice-markers export entry
#   PakettiDWVW.lua - DWVW export and conversion entries
#   PakettiMODToXRNI.lua - MOD to XRNI conversion entry
#   PakettiXRNIToWAV.lua - XRNI to WAV conversion entry
#   PakettiMODLoader.lua - MOD to WAV conversion entry
#   PakettiTyphoon.lua - TX16W/SDS export entries
#   PakettiLaunchApp.lua - smart/backup sample export entries
#   PakettiOTExport.lua - Octatrack export/import/debug/drumkit entries
#   PakettiOctaCycle.lua - OctaCycle Octatrack export entries
#   PakettiRX2Loader.lua - RX2 to Octatrack conversion entry
#   PakettiSF2Loader.lua - SF2 to XRNI and SF2 samples to WAV conversion entries
#   PakettiWavCueExtract.lua - Octatrack OT to CUE conversion entry
#
# Commit log:   worktree  Sample Editor export menu grouping
# SESSION:      sample-editor-export-menu-grouping.session.md
# RESULT:       Feature delivery worktree (direct to main, no PR); card worktree
#
# WATCH: PakettiExportMenus PakettiAbletonExportSimplerDialog PakettiRX2ExportDialog PakettiOTExport PakettiOctaCycle PakettiBatchRX2ToOT PakettiBatchOTToWavCue PakettiDWVWExportSelectedSample PakettiXRNIToWAVBatchDialog PakettiMODToXRNIBatchDialog PakettiBatchRX2ToXRNI PakettiBatchSF2ToXRNI PakettiBatchSF2ToWAV
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-25  direct-commit  touched: PakettiDWVWExportSelectedSample
#   2026-09-24  direct-commit  touched: PakettiOTExport PakettiOctaCycle PakettiBatchRX2ToOT PakettiBatchOTToWavCue PakettiDWVWExportSelectedSample PakettiXRNIToWAVBatchDialog PakettiMODToXRNIBatchDialog
# =============================================================================

Feature: Sample Editor export menus live under Export
  As a Paketti user, I want save/export/Ableton/Octatrack export commands in one Export branch, So that Sample Editor menus are scannable and conversion commands have a predictable home.

  @shipped @code-verified @runtime-untested
  Scenario: Save and Ableton export actions are consolidated under Export
    # cite: PakettiMenuConfig.lua Sample Editor Export menu entries (~lines 44-50, 2134-2142)
    # cite: PakettiAbleton.lua Sample Editor Ableton export entries (~lines 1772-1775)
    # cite: PakettiRX2Encode.lua REX2 export entry (~line 540)
    # cite: PakettiSlicedImport.lua AIFF slice-marker export entry (~line 693)
    Given Sample Editor commands save samples or export instrument/sample formats
    When Paketti registers those menu entries
    Then they appear under "Sample Editor:Paketti:Export:"
    And Ableton-specific exports appear under "Sample Editor:Paketti:Export:Ableton:"

  @shipped @code-verified @runtime-untested
  Scenario: Batch conversion actions live under Export Convert
    # cite: PakettiMenuConfig.lua format conversion entries (~lines 47-50, 2140-2141)
    # cite: PakettiDWVW.lua DWVW conversion entries (~lines 1253-1254)
    # cite: PakettiMODToXRNI.lua MOD to XRNI conversion entry (~line 471)
    # cite: PakettiXRNIToWAV.lua XRNI to WAV conversion entry (~line 402)
    # cite: PakettiMODLoader.lua MOD to WAV conversion entry (~line 917)
    # cite: PakettiRX2Loader.lua RX2 to XRNI conversion entry (~line 1303)
    # cite: PakettiSF2Loader.lua SF2 conversion entries (~lines 2372, 2378)
    Given Sample Editor commands batch-convert between formats
    When Paketti registers those menu entries
    Then they appear under "Sample Editor:Paketti:Export:Convert:"

  @shipped @code-verified @runtime-untested
  Scenario: Octatrack commands are inside Export
    # cite: PakettiOTExport.lua Octatrack Sample Editor menu entries (~lines 1164-1170, 3885)
    # cite: PakettiOctaCycle.lua OctaCycle menu entries (~lines 746-748)
    # cite: PakettiRX2Loader.lua RX2 to OT conversion entry (~line 1091)
    # cite: PakettiWavCueExtract.lua OT to CUE conversion entry (~line 1287)
    Given Sample Editor exposes Octatrack export/import/debug/generate and conversion commands
    When Paketti registers those menu entries
    Then ordinary Octatrack entries appear under "Sample Editor:Paketti:Export:Octatrack:"
    And Octatrack batch conversion entries appear under "Sample Editor:Paketti:Export:Convert:Octatrack:"

  @stock
  Scenario: Non-Sample-Editor command surfaces keep their existing homes
    # cite: PakettiOTExport.lua Sample Mappings Octatrack entries (~lines 1172-1178)
    # cite: PakettiAbleton.lua Main Menu Ableton export entries (~lines 1768-1771)
    Given other Paketti contexts expose the same export capabilities
    When Sample Editor menu paths are regrouped
    Then those other contexts are not renamed by this change
