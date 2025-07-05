2025.05.30 1.5.0
 - Show loading overlay until async sample processing has completed to prevent multiple calls to renderList before the list is ready.
 - Style tweaks to support rendering within itch.io windows.
 - Enhanced waveform rendering accuracy and performance (thanks to github.com/boourns for the pull request).
 - Dither exports option when outputting 8/16/24 bit wav or 16 bit aif files.
 - Added user feedback on sample load processing.
 - Improved responsiveness of list with large numbers of samples loaded.
 - Reduced file processing load times.
 - Added a welcome screen with some usage guidance, tips, and link out to documentation page.
 - Show the length in seconds of the sample being edited on the editor.
 - Support importing samples and slices from Renoise Instrument files (.xrni) in addition to sample data from Renoise Project files (.xrnx).
 - Mini-waveform renderer no longer builds waveform cache when skip render is enabled.
 - Prevent default event bubbling on keydown events for handled keyboard shortcuts, stops 'funk' noise on macOS for valid shortcuts.
 - Improved creation of OP-1 Field / OP-Z chains, nudging end to zero crossing per slice if one is present in the last 256 samples.
 - OP-1 Field / OP-Z exports now default to one-shot play mode.
 - Shift + click on Pad With Zero selected action allows entering a custom value to pad the sample(s) with in seconds.
 - Config option, treat slice data in files as distinct files on join - defaults to YES, when set to YES, if a file contains slice data or has had slice data configured those slices will be represented as distinct files when creating new chains that include those selected slices; when set to NO, the per-file slices will be discarded when joined to new chains.
 - Moved about pop-up into unified audio config, settings, about panel.
 - Supporting the import and export of digichain session files.
 - Using a custom dialog instead of the browser built-ins to handle user prompts/confirmations.
 - Moved browser based alert messaging into a toast style notification that displays at the top center of the active window or dialog.
 - OP Export UI for creating drum kits for OP-1 Field and OP-XY via a drag and drop key layout.
 - OP Export supports combining samples on Left / Right / Center to more easily create A/B kits for use on the Field.
 - Chains / Spaced Chains buttons now do not both display, they are toggled via the new Chain Type toggle icon.
 - Rendering created chains to the top of the list instead of out to a downloaded zip file (the Shift + Click button action), is now toggled from an icon.
 - XY preset rendering toggle icon, when enabled, chains are created as XY Preset folders in the output zip, max 24 slices and samples longer than 20 seconds will be automatically truncated.
 - Invert phase selected action.
 - Flip L/R selected action, switched the left and right channels around.
 - Editor waveform height adjustment control (height retained as setting).
 - Crop keyboard shortcuts in the editor, Shift+Click to crop to a new sample, staying in the current sample; Shift+Ctrl+Click to crop to a new sample and open that new sample in the editor.
 - Bug fixes:
   - Delayed list rendering bug when removing all selected samples.
   - When a waveform is too short to render a valid mini-waveform, the renderer replaced the parent dom node, causing a dom tree layout issue, this is now fixed.
   - Sanitize name selected action.
   - When restore last used audio config is set to off, the text label of the audio config indicator was blank.
   - Where canvas element replacement threw an error when slicing to samples from the slice panel with skip render waveforms enabled.
   - Toggling the max-seconds per chain option de-selected all samples.
   - XY common configuration no longer sets the seconds time limit per chain to on.
   - OP Export renders at the target sample rate for XY presets and 44.1kHz regardless of the target sample rate for OP-1 Field kits.
   - Play-head was not displayed when playing the highlighted sample in the list using the P key keyboard shortcut.
   - Only positive buffer values were being removed in the condense action.
   - Edit panel not consistently closing when using the Escape key.
   - Smoothing on fuzz selected action caused peak spikes on some sample material.
   - Setting DT / DT II / XY / M8 / OT did not toggle the spaced / xy settings and icons when using the common configurations options.
   - Slice panel waveform did not show when no slices were set (regression fix from edit panel renderer changes).

2025.01.16 1.4.16
 - Nudge Crossings selected action, nudges all zero crossings off from zero.
 - Pad with Zero selected action, adds a zero sample to the beginning and end of each file.
 - Shift selected action, moves the sample start position over 50%.
 - Fixed bug where resampling the list when changing the working sample-rate caused the loop point to bet set on .ot slice metadata.
 - Support for reading slice data from the Sonicware LoFi-12 XT custom header data.
 - Added common configurations for Sonicware LoFi-12 XT (12/24 kHz target sample rate).
 - Added common configurations for Teenage Engineering EP-133 / EP-1320 mono/stereo.
 - Fixed some browser specific UI element positioning quirks.
 - Added de-serialize from mono L/R back to a stereo sample selected action (halves a mono sample and puts the first half on the left channel, second half on the right).
 - Prevent slicing by transient assigning an ot meta loop point flag.
 - Added button to set a custom slice count on the slices panel.
 - Change default chain names to not contain _ or [ ] chars.
 - Turn off embed slice data config option by default.
 - Use Cue markers as preferred slice data storage within the wav file data.
 - Turn on/off .ot file export options when choosing the ot common configuration on the audio config panel.
 - Add OP-XY to common configurations, as this uses wav files as the primary file type.
 - Sanitize Names selected action to format file names to align with the guidelines for successful MTP transfer to Teenage Engineering OP-XY filesystem.
 - Minor wav encode bug, the cue chunk size property should be 8 bytes less than the total chunk byte length, not 4.

2024.05.28 1.4.15
 - Amplitude threshold condense selected action, enter an upper and lower amplitude value (between 0 and 1), the sample will be modified to only include amplitudes within the given range, gaps between the audio is removed condensing the sample size.
 - Ctrl + Click on Filename column header to sort the list by numeric filename content only.
 - Improved drop file order consistency.
 - Allow dropping mp3 files.
 - If sample has slice information, the slices will be shown on the waveform when the slice panel opens.
 - Support multi-touch for selecting/deselecting samples.

2024.05.14 1.4.14
 - Added basic error catch in the joinAll method to help surface chain build errors.
 - User alert for userAgent version checks to inform users if their browser is of a minimum supported version for the browser API's used.
 - Fixes bug when in the sample editor, and snap to zero was enabled, if no zero crossing could be found on the end point, then browser tab would hang on short samples.
 - Fixes bug where an end point selected before the current non-zero start point with snap to zero crossing enabled, would result in a negative preview playback value causing looped playback preview in the editor to not play any audio.
 - Defaulting to 48kHz as the working sample rate for broader compatibility with built-in audio devices (continues to be user configurable in Audio Settings Panel, does not change if DigiChain has been used before as this is a restored setting).
 - If the sample list is empty, choosing an option from the 'Common Configurations' list will set both the Working Sample Rate and the Target Sample Rate to the same value.
 - When no samples are selected, clicking the chain buttons showed the processing overlay but did not remove it.
 - Selections won't clear when changing the slice-grid values via the audio config panel (grid choice will still be set to OFF).
 - The download buttons will now visually indicate their clickable state.

2024.04.30 1.4.13
 - Option to skip rendering of the mini waveform display in the sample list.
 - Fix regression bug on trim-right selected action.

2024.04.24 1.4.12
 - Added Double selected action to add a copy of a sample to the end of itself for the selected samples.
 - Prev / Next buttons on the edit panel to navigate between samples without needing to close the edit panel and re-select from the list.
 - Cleaned up selected actions list, added overflow so list can scroll on mobile and flex to the width of the panel.
 - Shift + Ctrl/Cmd click stretch longest/shortest selected action to set the stretch length in samples instead of seconds.
 - Shift + Click on Trim Right button in editor, or selected actions, to also trim silence from the start (left) of the sample.
 - Changed the behavior of the grid size buttons, clicking will now set the grid size and keep the selection, to also change the selection is now the shift+click action; This is inverted from other versions, but has been a requested change by several users.
 - Shift + L will toggle the lists visibility, useful for simple chaining/conversion if loading a large number of files that can cause the browser dom rendering to slow.
 - Hide 'Create .OT' button on sample panel if target SR is not 44100.
 - Added common configuration for Digitakt II.

2024.02.20 1.4.11
 - Fixes bug where saving slice data from imported slice file did not apply slice markers consistently.
 - Bug fix where parsing wav file headers contains multiple fmt chunks, where the first fmt chunk does not contain the samples format data.

2023.12.13 1.4.10
 - .xrns file contents parsing (useful for getting the samples out of a Renoise project file).
 - Parse the Renoise song data from within project files and extract slice markers.
 - When slicing from OP-1 Field tape.json, prevent the ot slice loop point CSS class being applied.
 - Drag-out single file from list (Chrome).
 - Option in settings to reverse all even samples in an exported chain (back-to-back mode).
 - Snap to zero-crossing toggle option on selections on edit panel.
 - Visual zero-crossing indicator on edit panel selection start and end points.
 - Surface tempo detection method to the edit panel to detect from the currently selected section of the waveform.
 - Fixed regression on .ot file generation not correctly setting the quantize value default to 'direct' instead of 'pattern length'.
 - Fixed bug when setting slice-grid options from the audio settings panel.
 - Added keyboard shortcuts info pop-up (Shift + ? / Shift + K).

2023.11.04 1.4.9
 - Store list in indexedDb for optional restoring of the last session on next load.
 - Map the Ctrl key to the Cmd key for macOS keyboard shortcuts.
 - Automatically ignore empty or nonsense cue markers (e.g. zero length or start/end greater than file length, end greater than start).
 - Improve handling of joining chains with other chains/files and slice types.
 - Normalize the slice-type to the common format when processing internally.
 - Show the number of slices if the file has any on the slice-grid icon instead of OT/DC/OP text.
 - Improved the speed of conversion between spaced/none-spaced chains from the slice panel.
 - Allow users to change audio context when files are loaded without emptying list; An advisory message to confirm the action is shown, as the sample rates of all files in the list are internally resampled to the new context.
 - Decoupled the working audio sample rate from the export audio sample rate. This allows users to work at 44.1kHz, but export to 48kHz for example without destructively resampling the list source buffers.
 - Audio context options are now an audio config panel, allowing arbitrary sample rates, and choice of bit depth and channel combinations.
 - A list of common configurations by hardware name are available in the audio config panel.
 - Audio config panel has slice grid options inputs so last used values are remembered. These values are also updated as part of the common configs list options.
 - 'Retain session data between browser refreshes?' setting on settings panel.
 - Gain adjustment on the edit panel (Thanks to eljeff).
 - Option in settings panel to download single files when Shift+Clicked to prevent accidental downloads being triggered.
 - Added rough stretch to selected actions list, this attempts to retain pitch while doubling the duration of the sample.
 - Importing of Polyend Tracker (OG) .pti instrument files (mono only).
 - Toggle slice looping from the slice panel (useful for .ot exports).
 - Toggle file looping point from the slice panel (useful for .ot exports).
 - Correctly calculate the tempo and bar values on .ot exports.
 - Create .ot button on slice panel to create a .ot metadata file independently of downloading of the audio file.

2023.10.15 1.4.8
 - New serialize selected action, any selected samples that are stereo files, will have their stereo channels serialized to mono, by Left/Right, Side/Mid, or Left/Right/Side/Mid.
 - Dual mono exports setting error.
 - Prevent find crossing point on edit panel.
 - Issue with auto-naming of duplicate files/same file imported multiple times.
 - Trim-right on sample that had slices removed threw unhandled error.
 - Merge/Blend panel mono/pan controls not consistently updating UI when clicked.
 - Fixed rendering bugs with Firefox 118.x when page zoom higher than 100%.
 - Removed arcs in svg for better representation of the waveform graphics.
 - Ctrl + Click on the 'add samples' icon will add a blank sample (8 samples in length) to the list to use for padding chains.

2023-08-31 1.4.7
 - Load samples from within zip files and Digitakt project files. (if max file limit setting is off, all files in the zip will be decompressed to memory, so be careful with zip sizes if setting that to off! If the zipped supported file count + file count already loaded is larger than the limit, the whole zip gets skipped).
 - Allow * and / on the stretch action shifted user input.
 - Hold shift on pitch buttons to use stretch instead of the resample method to affect the pitch.
 - Break-word on blend filenames to help prevent column width issues.
 - Fixed bug where keyboard shortcuts activated in name editing on edit panel.
 - Ctrl + Shift + Click On the edit panel, when clicking the waveform, this will set the end point selection to the clicked position and move the start point to the previous end point value.
 - Edit Panel, N : Create new slice.
 - Edit Panel, U : Update current slice.
 - Edit Panel, X : Remove current slice.
 - Option to export dual mono stereo files as a mono file (toggle in settings, on by default).
 - Shorten file path and names selected actions (and restore names).
 - Tweaks to note detection from filename.
 - Visual indicator on row name left-border if file path and name will be longer than 127 chars from root of the exported zip file.
 - Fixed bug (issue#2) where looped playback on edit panel spawned multiple audio playbacks when clicked repeatedly.
 - Changed behavior when removing all slices to default to whole waveform selected. (issue#3)
 - Fixed issue where duplicate samples inherited the filename instead of the name property. (issue#4)
 - Fixed padding issue on panel info text, and blend dropdown control.
 - Ignore multiple data chunk headers in the wav files to prevent instability when importing wav files. Fixes bug where tab might hang on import of some oddly structured wav file chunks.

2023-08-09 1.4.6
 - Convert chains between evenly spaced and unspaced chains from the slice panel. Works with DC, Octatrack, and OP-x slice data. When converted to a spaced chain, if the grid-size is set to a value, the new chain will be padded to this number.
 - Ctrl+Click to preview slices before slicing a sample.
 - Slice editing on sample edit panel, create/update/remove slice markers.
 - Playback/looped playback on the sample edit panel follows the selected region on the waveform.
 - Show stereo waveform if available on sample edit panel.
 - Update the row waveform when changing the mono rendering method.
 - Moved around the edit panel UI.
 - Added LRSD controls to the edit panel.
 - Remembering slice position/selection when changing options on edit panel.
 - Edit panel LRSD / play/stop keyboard shortcuts on edit panel.
 - Allow generating .ot metadata file on 16/24 44.1 mono exports.
 - Option in settings to match the end sample with the start sample (if possible), to help reduce clicks for samples that will be played looped. (can result in shorter than specified samples).
 - Read/write wav file cue point markers into DigiChain slice data (adds compatibility for DirtyWave M8 to read chains, and to import the slices from M8 to DigiChain).
 - Added basic sample stretching (which does affect pitch), stretch selected samples to shortest or longest sample in the list, or hold shift to set a custom length in seconds. (this will remove any slice data for the modified samples).

2023-07-27 1.4.5
 - Improved the note from filename detection and sorting.
 - 44.1/48K 8bit mono/stereo file exports.
 - Crush selected actions action to add some crush/distortion to the sample.
 - Pitch up/down in cents in sample editor panel. (click the 'Pitch (semi-tones)' link to toggle between semi-tones and cents.)

2023-07-16 1.4.4
 - Minimizes reported click/pops on exported chains when importing wav files of differing sample rate to the target sample rate, or when using audio interfaces configured with small sample buffers. On by default at a 40% threshold, user configurable thresholds and can be disabled via settings panel.
 - Resolves issue where running in the Brave browser caused an unexpected error modifying an existing audio array buffer.
 - Added fuzz selected actions action to add fuzz/noise into the selected samples.
 - Added fade-in fade-out selected actions to fade in/out the first/last 256 samples of each selected sample.
 - Blend panel to blend/interpolate between the selected samples (works best when the samples are similar in duration).

2023-07-02 1.4.3
 - Added a ping-pong selected actions action to add a reversed copy of the sample to the end of the sample.
 - Fixed issue where generated AIF files did not load slice data accurately into the new TE drum utility tool.

2023-06-01 1.4.2
 - Hold shift key while dragging in samples to import randomly up to the currently chosen grid-size.
 - Default to limit the number of imported samples to 750, to reduce risk of timeouts - can be disabled in the settings panel.
 - Limiting the max chain length to 64 slices when using the timed chain length in non-aif audio context, Aif context stays at max 24 slices.
 - Setting the default Shift import random drop value to 256 if no slice grid value is selected (this prevents accidental import of large numbers of files, Ctrl+click a slice-grid number and set a custom value to import more than 256 samples randomly).
 - Ctrl + Click on the Selected header text will toggle all the samples selection to all selected / all de-selected.
 - Changed load files to an icon.
 - Expanded width of the audio config selection.
 - Updated the drop-zone style when list is empty.
 - Added content-visibility to list body.

2023-05-22 1.4.1
- Added truncate selected action (shift+click to set a custom length), and crop to selection in the editor panel.
- Fixed bug playing back sample after editing in the edit panel if the sample was currently playing from the list.
- Changed start/end point editor selection.
- Changed zoom levels to +/- buttons to zoom in further than 4x.
- Fixed bug where grid keyboard shortcuts were still active on edit panel.

2023-05-15 1.4.0
- Workflow to support reading slices from and creating chains for the Teenage Engineering OP-1 Field / OP-Z
    - OP-1 / OP-1 Field / OP-Z aif file imports, mono and stereo.
    - Slice from OP-1 / OP-1 Field / OP-Z drum-kit aif files.
    - OP-1 Field and OP-Z drum kit and single file exports with the aif 44.1/16 mono/stereo options.
    - OP-1 Field L/R A/B toggle and value setting from the list when in 44.1/16 Stereo Aif context. (double-click to toggle).
    - Slice from tape.json (OP-1 Field tape file slice markers) in the slice panel.
    - Merge All Selected action - mixes down all the selected items into one sample (enables creating files with different samples on the L/R for use with OP-1 Field's A/B drum kit option.

- Automatic creation of Octatrack .ot meta files in 44.1 16/24 stereo non-aif audio contexts. (toggle in settings).

- Audio editor panel overhaul.
    - Added 1x, 2x, 4x zoom levels for the waveform.
    - Added loop playback button to editor panel.
    - Fade in/out/silence tools.

- UI Improvements
    - Added playback indicator icon and play-head marker to waveforms in the list view.
    - Shift+Click on the row sample select box will select all the samples in-between (inclusive of the highlighted and the clicked sample). Ctrl+Shift+Click will de-select.
    - Shift+Click Column Header : Sorts the list, but will keep the selected items grouped to the top of the list.
    - Shift+Click Reset Button : Randomizes the order of the list.
    - Numeric keys 1 - 0 play the first 10 selected samples from the list.
    - Alt + numeric key / P key stops the playback and looping of that single sample.
    - Showing the sample name from DC slice data in title of slices on slice panel.
    - Double-click to remove a slice before processing slices on the slice panel.
    - Ctrl+Click the slice sample row icon to clear any related sample slice data.
    - E key opens the edit panel for the currently highlighted sample. Shift+E opens the editor panel for the currently highlighted sample, with the file name and path inputs editable, and the filename input keyboard focused.
    - Basic note detection from filename for sorting the list.
    - Reworked layout for better rendering on smaller screen devices.
    - Added a light theme for users who don't like dark themes, toggled in the settings panel (first launch will set from the devices system color preference).
    - Custom filenames panel, add a list of custom filenames to use - once all names have been used, DigiChain will fall back to the default naming convention.

- Settings on the settings panel are saved to local-storage and will persist when the app re-opens.
    - Allow disabling slice embed in settings.
    - Option to play pop-markers at the start and end of the sample for direct sampling to the Digitakt audio inputs. Two options, 0db markers (which prevents the DT's auto normalization from changing the recorded sample volume), and peak, which sets the pop-marker volumes to match the loudest peak in the sample.
    - Show/hide touch modifier buttons in options panel.
    - Restore last used sample rate/bit depth/channel selection in options.
    - Option to normalize text/waveform color contrast in the settings panel.

- DC slice format embedded in output chain wav file so user can restore the chains to slices retaining the input filename.
- Support for importing webm and m4a audio files.
- Added 'Difference (Side)' stereo -> mono processing option.
- Trim All Selected action.
- Reverse All Selected action.
- Normalize All Selected action.
- Pitch Up by an Octave All Selected action.
- Enabled 32bit float wav exports.
- Allow importing of 16bit aif files (parser written to accommodate importing from TE devices, but should be ok on other exported aif files, testing with Ableton Live exports and worked as expected, ymmv).
- Split chained files at 12s (mono) or 20s (stereo) lengths mode. Sample order will loosely follow the list order, but it will try to fit smaller samples into the chain up to the max limit from further down the selected items in the list, so some samples may be out of order depending on their length and where they could be slotted into each chain to use up the time in the best way possible.
- Removing arraybuffers before removal of files to help free memory usage sooner.
- Ctrl+Click on the max length per chain in seconds to set a custom limit.

- Bugfixes
    - Fixed bug where file path changes were not persisted.
    - Prevent pitch-up crashing when doubling a very small audio buffer.
    - Checking for suspended audio-context and resuming if suspended before playback.
    - Checking audio context state before importing files, resuming if possible.
    - Fixed bug where joining chains together with single additional sample between caused the slice offsets to be incorrect.
    - Removing multiple and sorts will stop sample playback (audioCtx caused pops when in these situations previously).
    - Fixed bug where a non-standard wav file PAD chunk caused a page crash.
    - Adding a _n char/number to the end of duplicated files name (as exporting to zip overwrites same filename files).
      Importing the same file will also increment the filename.
    - Fixed bug where resampling a new chain with a global pitch modifier and embed slices disabled would cause the new pitched audio buffer to fail rendering.
    - Fixed bug in the reading of AIFC aif files.
    - Don't mute samples when toggling selection.

2023-04-07 1.3.1
 - Fixed bug where a duplicate sample shared the sources audio-buffer in specific situations (e.g. when reversing the sample.)
 - Simplified the transient detection method, enabled it for longer sample lengths as this approach is better suited to longer samples.
 - Trim right is more aggressive with what it trims (to 0.003 amplitude).

2023-04-05 1.3.0
- Importing of folders - recursive search for wav/syx files (be careful with filesize/depth of folders with this!).
- OT slices import from accompanying .ot file.
- Show source folder path on list, filenames will now include this path in their name if present - joined files with have the path of the first item in the chain in its name.
- Moved the UI around again, added ability to hide the top buttons panel.
- Multi-file/joined downloads will now be downloaded as a single zip file (can be put back to multi-single file prompts in the settings panel).
- Grid-view mode for those who dislike tables. (Shift+G)
- Swapped Shift/Ctrl coloring, added css transition on toggle.
- Added slice-count to end of chain filenames.
- Changed 'sort by selected icon' to a text value.
- Added sort by slice# to make building mega-break chains easier.
- Indicator on row/grid of end of joined chain based on slice-grid selection.
- Waveform and slice marker visual preview before slicing a file from the list into new samples.
- Basic transient detection on the slice grid panel (for samples less than ~128 seconds).
- Edit panel with file name/path editing, waveform view, play/stop controls.
- Normalize, trim right, reverse, half-speed, and double-speed (destructive) sample edit operations.
- Allow dropping of wav url links to be fetched (works with domains that allow CORS).
- Export settings panel with pitch up export setting (1, 2, or 3 octaves), and the zip file on/off toggle.
- Added offline support and install as app from the browser.

2023-03-27 1.2.0
- Added support for slicing files in the list into new items.
- Added ability to resample joined files back into the list instead of downloading.
- Sample import times are about a third faster than previously.
- Support for drag drop reordering of the list.
- Show selected/total length times in the length header.
- Added a bunch more keyboard shortcuts.
- Allow changes to stereo/mono and bit-depth, as it's only the sample-rate that makes things wonky. [Only sample rate changes will trigger the list to clear.]
- Show selected/total length times in the length header.
- Fixed waveform double first render bug.
- Tweaked height of waveform views.
- Fixed bug in sorting selected by items.
- Keyboard commands for managing the list (see keyboard-shortcuts.md).
- Shift / Ctrl lock buttons so mobile/tablet users can access the secondary (keyboard shortcut) functions.

2023-03-25 1.1.0
- Support for outputting stereo files.
- Support for 24 bit file exports.
- Now supports drag-drop sample importing.
- Add Shift+click function to set the stereo->mono method for all selected stereo samples in the list.
- Fixed an issue where setting a custom slice grid value did not persist.
- Allows custom slice values to be set with the Ctrl+Click keyboard shortcut.
- Export options beyond 48k/16bit - this setting is per session, changing will remove all entries from the list.

2023-03-24 1.0.2
- When a slice grid length is selected, samples will now be auto-generated, (e.g. if you have 13 samples selected and a grid of 4, you will get 4 files downloaded instead of one chain of 13 samples [which isn't ideal for the Digitakt!]).
- Shift+click the slice-grid numbers to change the grid size, but retain the selected samples.
- Added loading message while loading in files.
- Added sort-by selected.
- Changed button text, added joined file counts that will be produced, and a number of files that will be downloaded if downloading all.
- More tweaks for mobile device use.
- Fixed an issue where a looping sample would keep playing after removal.

2023-03-23 1.0.1
- Sorting error on length sort.
- Re-order button glitching.
- Shift+Up/Down, Shift+Duplicate error.
- Waveform display on Android.
- Show version number on bottom of screen.
- Shift+click on waveform will loop the files playback (de-select will stop loop, click will go back to one-shot, Off in slice grid will stop all sample playback).
- Added support for 128 slices (e.g. for wavetables or Model:Samples use on start point).
- Cleaned up UI for mobile, moved around buttons to make use of the space better.

2023-03-22 1.0.0
-  Load .wav files (stereo or mono).
-  Load .syx sds dumps (e.g. from the MD, or MD Elektron sample packs), support only for 44.1khz/16bit dumps.
- Samples can be previewed by clicking the mini-waveform.
- Processed file to 48khz/16bit download via clicking the sample name.
- Stereo input files are processed to mono, choice of the Left, Right, or sum of both channels via 'L S R' options.
- Individual files can be downloaded, or all the selected with the Download button, this will prompt to save each file individually.
- Download Joined will process all the selected files into one wav file.
- Download Joined (Spaced) will process all the selected files, and pad all shorter duration samples with silence to match the duration of the longest file in the selection.
- When the slice grid has an option other than Off selected, the last selected sample will repeat to fill to the chosen grid size (known bug, choosing more than the slice-grid number will result in a join with too many samples, this will be resolved shortly).
- Samples can be moved up or down in the list.
- Preview the sample by clicking on the mini-waveform.
- Duplicate the sample in the list to repeat it (or have versions from the LSR channel selection).
- Remove the sample from the list by double-clicking the trash icon.
- Use the Remove Selected button to remove all selected from the list.
- Sort by filename or duration.
- Reset Sort Order button resets the list to the order in which the files were loaded.
