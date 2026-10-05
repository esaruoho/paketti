# Pure Gherkin test extracted from features/sample-editor-export-menu-grouping.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/sample-editor-export-menu-grouping.feature

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
