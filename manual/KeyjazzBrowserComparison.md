# Paketti Keyjazz loader versus SimpleBrowser 1.2.0

Compared the current PakettiLoadSampleBrowser.lua working tree against main.lua extracted from /Users/esaruoho/Downloads/com.phaos.SimpleBrowser.xrnx. This is a source inspection, not a live comparative Renoise test.

Both use a scratch instrument for auditioning, support keyboard piano playback, waveform selections and loop editing, and can import edited preview audio while leaving the source audio file untouched.

| Area | Paketti Keyjazz loader | Phaos SimpleBrowser 1.2.0 |
|---|---|---|
| Main purpose | Audition, then load with the Paketti template and return to the tracker | Browse, edit and build multisample instruments in a persistent browser |
| Layout | One folder/file list, metadata and waveform | One or two browsing panes, optional multisample panel, waveform/playhead and controls |
| Loading target | Selected empty instrument, first empty instrument, or a new one | New instrument, replace selected sample, or add to multisample instrument |
| Folder imports | Shift-Enter: direct files into separate instruments | Folder/sample selections can build a multisample instrument; optional recursive traversal |
| Formats | Native audio plus Paketti expansion/importers for formats such as REX, ITI, SF2 and EXS; non-native formats lack live preview | Audio extension list: WAV, AIF/AIFF, FLAC, MP3, OGG |
| WAV cues | Shared embedded-cue importer; zero/one cue stays unsliced; active preview loop overrides slicing | Normal sample loading plus WAV smpl loop probing; no dedicated cue-to-slice import found |
| Loop editing | Mode cycling, flag dragging, Selection to Loop | Those functions plus zero-crossing snapping and loop crossfade |
| Audio editing | Cmd-X removes selected frames; edited audio survives final native loading | Cut, trim, loop crossfade, reset to original |
| Edit history | No browser undo/redo; switching files resets edits | Per-file operation lists retained while browsing, browser undo/redo |
| Playback settings | Interpolation, oversampling, autofade, preview volume and tempo sync; chosen playback values survive loading | Interpolation and tempo sync controls; prehear volume/output controls. Autofade and oversampling occur in snapshot properties, but no dedicated controls found |
| Multisample mapping | No dedicated kit panel in this browser | Drumkit, Distribute, Layer; white-key mapping and overlap modes |
| Search | Recursive opening/chosen-root search: words, alternatives, exclusions, phrases, wildcards | Similar query syntax plus root-wide/recursive search options |
| Locations | Twelve F-key presets, last folder/file remembered, folder picker | Eight bookmarks, extra folder places, hidden entries, rescan and reveal in file browser |
| Delete | Cmd-Backspace confirms actual source-file deletion; retains/clamps row | Hide source entries and remove instrument samples; no actual source-file deletion action found |
| Tracker integration | Confirm closes browser; Right-Shift loads a new instrument and enables Edit Mode/Follow Pattern | Load-and-write-note action and multisample row note insertion; browser keeps broader editing workflow |
| Caps Lock | Angle-key octave handling ignores Caps Lock | Caps Lock toggles keyboard controls mode |

The largest remaining differences are retained per-file edits, undo/redo, crossfade, zero-crossing snapping, multisample assembly, preview output routing and a moving playhead. Paketti has separate tools for some of these operations, but they are not integrated into this Keyjazz browser.

Current Paketti changes have mocked regression coverage and syntax verification; live Renoise verification remains pending. The angle-key change resolves typed characters first and falls back to named keys plus Shift, without gating on Caps Lock.

Source landmarks: SimpleBrowser C.edit_data (~2510), C.xfade_data (~2551), C.record (~2609), C.source_for (~2723), C.undo/C.redo (~3137), C.kit_add_paths (~3600), C.help_text (~5638). Paketti plsb_preview_selected, plsb_do_load, plsb_cut_selection, plsb_confirm_delete_file and plsb_key_handler.

## Remaining gaps after the added controls

1. Per-file edit retention: navigating away currently discards Paketti cuts, trims, loop edits and explicit playback choices. SimpleBrowser keeps operation lists keyed by file while the browser is open.
2. Browser undo/redo and reset-to-original: SimpleBrowser covers preview edits, settings, multisample changes and loads. Paketti has no equivalent browser history.
3. Loop crossfade and zero-crossing snapping are not integrated into Paketti's browser (separate Paketti tools do not make them browser features).
4. Multisample panel: assemble/remove/reorder samples; Drumkit, Distribute and Layer mapping; white-key mapping; overlap Play All/Cycle/Random; audition the assembled instrument.
5. Shift-click/Shift-arrow multiple-file selection and selected-group loading.
6. Two-pane folder/sample layout, pane focus switching and keyboard control-navigation mode.
7. Automatic prehear on selection, moving playback cursor and explicit Master versus selected-track prehear routing.
8. Replace selected sample, load-and-write-note, and instrument/sample-slot navigation within the browser.
9. Hide/unhide entries, reveal in Finder, extra root places, explicit rescan and in-dialog help.
10. Tempo inference from BPM filenames: SimpleBrowser uses a filename BPM when present, then nearest power-of-two beat inference with a plausibility guard; Paketti currently always chooses nearest power-of-two beats.

Suggested implementation order based on protecting edits first: retain per-file edits, undo/redo, reset-to-original; then crossfade and snapping; then preview playhead/routing/autoplay; then multisample and navigation features.
