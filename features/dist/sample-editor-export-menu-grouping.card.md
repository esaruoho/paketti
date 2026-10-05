# Report Card — Sample Editor export menus live under Export

> Source: `features/sample-editor-export-menu-grouping.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want save/export/Ableton/Octatrack export commands in one Export branch, So that Sample Editor menus are scannable and conversion commands have a predictable home.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Save and Ableton export actions are consolidated under Export

`@shipped @code-verified @runtime-untested`


- Given Sample Editor commands save samples or export instrument/sample formats
- When Paketti registers those menu entries
- Then they appear under "Sample Editor:Paketti:Export:"
- And Ableton-specific exports appear under "Sample Editor:Paketti:Export:Ableton:"

<sub>cite: PakettiMenuConfig.lua Sample Editor Export menu entries (~lines 44-50, 2134-2142) · PakettiAbleton.lua Sample Editor Ableton export entries (~lines 1772-1775) · PakettiRX2Encode.lua REX2 export entry (~line 540) · PakettiSlicedImport.lua AIFF slice-marker export entry (~line 693)</sub>


## 2. Batch conversion actions live under Export Convert

`@shipped @code-verified @runtime-untested`


- Given Sample Editor commands batch-convert between formats
- When Paketti registers those menu entries
- Then they appear under "Sample Editor:Paketti:Export:Convert:"

<sub>cite: PakettiMenuConfig.lua format conversion entries (~lines 47-50, 2140-2141) · PakettiDWVW.lua DWVW conversion entries (~lines 1253-1254) · PakettiMODToXRNI.lua MOD to XRNI conversion entry (~line 471) · PakettiXRNIToWAV.lua XRNI to WAV conversion entry (~line 402) · PakettiMODLoader.lua MOD to WAV conversion entry (~line 917) · PakettiRX2Loader.lua RX2 to XRNI conversion entry (~line 1303) · PakettiSF2Loader.lua SF2 conversion entries (~lines 2372, 2378)</sub>


## 3. Octatrack commands are inside Export

`@shipped @code-verified @runtime-untested`


- Given Sample Editor exposes Octatrack export/import/debug/generate and conversion commands
- When Paketti registers those menu entries
- Then ordinary Octatrack entries appear under "Sample Editor:Paketti:Export:Octatrack:"
- And Octatrack batch conversion entries appear under "Sample Editor:Paketti:Export:Convert:Octatrack:"

<sub>cite: PakettiOTExport.lua Octatrack Sample Editor menu entries (~lines 1164-1170, 3885) · PakettiOctaCycle.lua OctaCycle menu entries (~lines 746-748) · PakettiRX2Loader.lua RX2 to OT conversion entry (~line 1091) · PakettiWavCueExtract.lua OT to CUE conversion entry (~line 1287)</sub>


## 4. Non-Sample-Editor command surfaces keep their existing homes

`@stock`


- Given other Paketti contexts expose the same export capabilities
- When Sample Editor menu paths are regrouped
- Then those other contexts are not renamed by this change

<sub>cite: PakettiOTExport.lua Sample Mappings Octatrack entries (~lines 1172-1178) · PakettiAbleton.lua Main Menu Ableton export entries (~lines 1768-1771)</sub>

