-- Debug flag for menu loading messages
local PakettiMenuDebug = false

-- Debug print function
local function debugPrint(message)
  if PakettiMenuDebug then
    print(message)
  end
end

-- Dynamically apply File vs File:Paketti menu location (1=File, 2=Paketti, 3=Both)
function PakettiMenuApplyFileMenuLocation(mode)
  if not preferences or not preferences.pakettiMenuConfig or not preferences.pakettiMenuConfig.MainMenuFile then return end
  if type(mode) ~= "number" then
    mode = (preferences.pakettiFileMenuLocationMode and preferences.pakettiFileMenuLocationMode.value) or 3
  end

  local file_entries = {
    "Main Menu:File:Paketti New Song Dialog...",
    "Main Menu:File:Load Most Recently Saved Song",
    "Main Menu:File:Save (Paketti Track Dater & Titler)...",
    "Main Menu:File:Save Song with Timestamp",
    "--Main Menu:File:Save All Samples to Folder...",
    "--Main Menu:File:Save Unused Samples (.WAV&.XRNI)...",
    "Main Menu:File:Save Unused Instruments (.XRNI)...",
    "--Main Menu:File:Delete Unused Instruments...",
    "Main Menu:File:Delete Unused Samples...",
    "--Main Menu:File:Remove Empty Tracks...",
    "Main Menu:File:Remove Empty Tracks (No Notes, No DSP)...",
    "--Main Menu:File:Largest Samples Dialog...",
    "Main Menu:File:Wipe Song Patterns",
    "Main Menu:File:Clear Unused Patterns",
  }

  local paketti_entries = {
    "Main Menu:File:Paketti:Load Most Recently Saved Song",
    "Main Menu:File:Paketti:Paketti New Song Dialog...",
    "Main Menu:File:Paketti:Paketti Track Dater & Titler...",
    "Main Menu:File:Paketti:Save Song with Timestamp",
    "--Main Menu:File:Paketti:Save All Samples to Folder...",
    "--Main Menu:File:Paketti:Save Unused Samples (.WAV&.XRNI)...",
    "Main Menu:File:Paketti:Save Unused Instruments (.XRNI)...",
    "--Main Menu:File:Paketti:Delete Unused Instruments...",
    "Main Menu:File:Paketti:Delete Unused Samples...",
    "--Main Menu:File:Paketti:Remove Empty Tracks...",
    "Main Menu:File:Paketti:Remove Empty Tracks (No Notes, No DSP)...",
    "--Main Menu:File:Paketti:Largest Samples Dialog...",
    "Main Menu:File:Paketti:Wipe Song Patterns",
    "Main Menu:File:Paketti:Clear Unused Patterns",
  }

  local function remove_list(list)
    for i = 1, #list do
      local n = list[i]
      if renoise.tool():has_menu_entry(n) then
        renoise.tool():remove_menu_entry(n)
      end
    end
  end

  local function ensure_file_entries()
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti New Song Dialog...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Load Most Recently Saved Song") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Load Most Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Save (Paketti Track Dater & Titler)...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Save (Paketti Track Dater & Titler)...",invoke=pakettiTitlerDialog}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Save Song with Timestamp") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Save All Samples to Folder...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Save Unused Samples (.WAV&.XRNI)...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Save Unused Instruments (.XRNI)...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Delete Unused Instruments...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Delete Unused Instruments...",invoke=deleteUnusedInstruments}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Delete Unused Samples...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Delete Unused Samples...",invoke=deleteUnusedSamples}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Remove Empty Tracks...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Remove Empty Tracks...",invoke=PakettiClearanceRemoveEmptyTracks}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Remove Empty Tracks (No Notes, No DSP)...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Remove Empty Tracks (No Notes, No DSP)...",invoke=PakettiClearanceRemoveEmptyTracksAndDSP}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Largest Samples Dialog...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
    end
    if type(wipeSongPattern) == "function" and not renoise.tool():has_menu_entry("Main Menu:File:Wipe Song Patterns") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
    end
    if type(PakettiClearUnusedPatterns) == "function" and not renoise.tool():has_menu_entry("Main Menu:File:Clear Unused Patterns") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Clear Unused Patterns",invoke=PakettiClearUnusedPatterns}
    end
  end

  local function ensure_paketti_entries()
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Load Most Recently Saved Song") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Load Most Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Paketti New Song Dialog...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Paketti Track Dater & Titler...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Paketti Track Dater & Titler...",invoke=pakettiTitlerDialog}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Save Song with Timestamp") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Paketti:Save All Samples to Folder...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Paketti:Save Unused Samples (.WAV&.XRNI)...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Save Unused Instruments (.XRNI)...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Paketti:Delete Unused Instruments...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Delete Unused Instruments...",invoke=deleteUnusedInstruments}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Delete Unused Samples...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Delete Unused Samples...",invoke=deleteUnusedSamples}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Paketti:Remove Empty Tracks...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Remove Empty Tracks...",invoke=PakettiClearanceRemoveEmptyTracks}
    end
    if not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Remove Empty Tracks (No Notes, No DSP)...") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Remove Empty Tracks (No Notes, No DSP)...",invoke=PakettiClearanceRemoveEmptyTracksAndDSP}
    end
    if not renoise.tool():has_menu_entry("--Main Menu:File:Paketti:Largest Samples Dialog...") then
      renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
    end
    if type(wipeSongPattern) == "function" and not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Wipe Song Patterns") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
    end
    if type(PakettiClearUnusedPatterns) == "function" and not renoise.tool():has_menu_entry("Main Menu:File:Paketti:Clear Unused Patterns") then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Clear Unused Patterns",invoke=PakettiClearUnusedPatterns}
    end
  end

  if mode == 1 then
    remove_list(paketti_entries)
    ensure_file_entries()
  elseif mode == 2 then
    remove_list(file_entries)
    ensure_paketti_entries()
  else
    ensure_file_entries()
    ensure_paketti_entries()
  end
end

-- Global helpers for adding/removing menu entries safely
-- Removed dynamic helpers/updater to keep File menu configuration localized below

--- Instrument Box Config
if preferences.pakettiMenuConfig.InstrumentBox then
  debugPrint("Instrument Box Menus Are Enabled")
-- Gadgets
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti eSpeak Text-to-Speech...",invoke=function()pakettieSpeakDialog()end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti Stacker Dialog...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti Timestretch Dialog...",invoke=pakettiTimestretchDialog}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti Steppers Dialog...", invoke=function() PakettiSteppersDialog() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti YT-DLP Downloader...",invoke=pakettiYTDLPDialog }
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Merge Instruments Dialog...",invoke=function() pakettiMergeInstrumentsDialog() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti Global Volume Adjustment...",invoke=function() pakettiGlobalVolumeDialog() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Steppers:Paketti Steppers Dialog...", invoke=function() PakettiSteppersDialog() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Phrases:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Select Random Instrument (Sample,Plugin,MIDI)",invoke=function() pakettiSelectRandomInstrument() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Transpose Dialog...",invoke=function() PakettiInstrumentTransposeDialog() end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Transpose Dialog...",invoke=function() PakettiInstrumentTransposeDialog() end}


renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load Random AKWF Sample",invoke=function() load_random_akwf_sample(1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load Random amount (1...12) of AKWF Samples",invoke=function() load_random_akwf_sample("random") end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:AKWF:Load 02 AKWF Samples",invoke=function() load_random_akwf_sample(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load 05 AKWF Samples",invoke=function() load_random_akwf_sample(5) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load 12 AKWF Samples",invoke=function() load_random_akwf_sample(12) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:AKWF:Load 05 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load 12 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load 05 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Load 12 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (032)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(32, false) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (064)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(64, false) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (128)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(128, false) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (256)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(256, false) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (032,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(32, true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (064,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(64, true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (128,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(128, true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:AKWF:Create Random AKWF Wavetable (256,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(256, true) end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Phrases:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Phrases:Load XRNI & Wipe Phrases",invoke=function() loadXRNIWipePhrases() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Phrases:Wipe Phrases on Selected Instrument",invoke=function() wipePhrases() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Phrases:Load XRNI & Disable Phrases",invoke=function() loadXRNIWipePhrasesTwo() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Phrases:Load XRNI & Keep Phrases",invoke=function() loadXRNIKeepPhrases() end}
--renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Phrases:Create Paketti Phrase",invoke=function() createPhrase() end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Load:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Load:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Load:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Load:Load Drumkit with Overlap Random",invoke=function() pitchBendDrumkitLoader() DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Load:Load Drumkit with Overlap Cycle",invoke=function() pitchBendDrumkitLoader() DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Load:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Load:Load Random 128 IFFs",invoke=function() loadRandomIFF(128) end }
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Load:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Load:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Load:Load New Instrument with Current Slice Markers",invoke=function() loadNewWithCurrentSliceMarkers() end}

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Polyend:Export .PTI Instrument",invoke=pti_savesample}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Save:Save Unused Samples (.WAV&.XRNI)...",invoke=function() saveUnusedSamples() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Save:Save Unused Instruments (.XRNI)...",invoke=function() saveUnusedInstruments() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Save:Save All Samples to Folder...",invoke=function() saveAllSamplesToFolder() end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Initialize:12st PitchBend Instrument Init",invoke=function() pitchedInstrument(12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Initialize:PitchBend Drumkit Instrument Init",invoke=function() pitchedDrumkit() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Initialize:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Global Volume Reduce All Instruments by -4.5dB",invoke=function() reduceInstrumentsVolume(4.5) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Set All Instruments All Samples Autofade On",invoke=function() setAllInstrumentsAllSamplesAutofade(1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Set All Instruments All Samples Autofade Off",invoke=function() setAllInstrumentsAllSamplesAutofade(0) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Set All Instruments All Samples Autoseek On",invoke=function() setAllInstrumentsAllSamplesAutoseek(1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Set All Instruments All Samples Autoseek Off",invoke=function() setAllInstrumentsAllSamplesAutoseek(0) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Global Volume Reduce Reduce All Samples by -4.5dB",invoke=function() reduceSamplesVolume(4.5) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Enable All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Bypass All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", false) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Enable All Sample FX on All Instruments",invoke=function() sampleFXControls("all", true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Bypass All Sample FX on All Instruments",invoke=function() sampleFXControls("all", false) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Delete Unused Instruments...",invoke=function() deleteUnusedInstruments() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Delete Unused Samples...",invoke=function() deleteUnusedSamples() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Hide All Instrument Properties",invoke=function() InstrumentPropertiesControl(false) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Show All Instrument Properties",invoke=function() InstrumentPropertiesControl(true) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Duplicate Instrument and Select New Instrument",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Duplicate Instrument and Select Last Instrument",invoke=function() duplicateSelectInstrumentToLastInstrument() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Instruments:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice&Write to Pattern",invoke = function() WipeSliceAndWrite() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Wipe&Slice:Wipe Slices",invoke=function() wipeslices() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Double Slices",invoke=function() doubleslices() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Wipe&Slice:Halve Slices",invoke=function() halveslices() end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Start Sampling and Sample Editor (Record)",invoke=function() PakettiSampleAndToSampleEditor() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Record:Paketti Overdub 12 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Paketti Overdub 12 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Record:Paketti Overdub 01 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Paketti Overdub 01 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Record:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,1) end}

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Plugins/Devices:Randomize Selected Instrument Plugin Parameters",invoke=function()randomizeSelectedPlugin()end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Plugins/Devices:Show XO Plugin External Editor",invoke=function() XOPointCloud() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Plugins/Devices:Toggle Mono Device",invoke=function() PakettiToggleMono() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Plugins/Devices:Switch Plugin AutoSuspend Off",invoke=function() autosuspendOFF() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Plugins/Devices:Insert Random Plugin (All)", invoke=function() insertRandomPlugin(false) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Plugins/Devices:Insert Random Plugin (AU Only)", invoke=function() insertRandomPlugin(true) end}

end

--- Sample Editor Config
if preferences.pakettiMenuConfig.SampleEditor then
  debugPrint("Sample Editor Menus Are Enabled")
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Paketti YT-DLP Downloader...",invoke=pakettiYTDLPDialog }
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Paketti Sample Adjust Dialog...",invoke = show_paketti_sample_adjust_dialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Set Selection by Hex Offset Dialog...", invoke = pakettiHexOffsetDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Sample Cycle Tuning Calculator...",invoke=function() pakettiSimpleSampleTuningDialog() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Unison Generator Dialog",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Paketti eSpeak Text-to-Speech...",invoke=function() pakettieSpeakDialog() end}
renoise.tool():add_menu_entry{name="Sample Editor:Process:Paketti Sample Cycle Tuning Calculator...",invoke=function() pakettiSimpleSampleTuningDialog() end}

-- Sample Editor Load
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Load:Load .MOD as Sample",invoke=function() 
  local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any File to Load as Sample")
  if file_path ~= "" then
    pakettiLoadExeAsSample(file_path)
    paketti_toggle_signed_unsigned() end end}



-- Sample Editor Save
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Save:Paketti Save Selected Sample .WAV",invoke=function() pakettiSaveSample("WAV") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Save:Paketti Save Selected Sample .FLAC",invoke=function() pakettiSaveSample("FLAC") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Save:Paketti Save Selected Sample Range .WAV",invoke=function() pakettiSaveSampleRange("WAV") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Save:Paketti Save Selected Sample Range .FLAC",invoke=function() pakettiSaveSampleRange("FLAC") end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Save:Export .PTI Instrument",invoke=pti_savesample}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Save:Duplicate, Maximize, Convert to 16Bit, and Save as .WAV",invoke=function() DuplicateMaximizeConvertAndSave("wav") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Save:Duplicate, Maximize, Convert to 16Bit, and Save as .FLAC",invoke=function() DuplicateMaximizeConvertAndSave("flac") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Save:Save Current Sample as IFF...",invoke = saveCurrentSampleAsIFF}


-- Sample Editor Record
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Record:Start Sampling and Sample Editor (Record)",invoke=function() PakettiSampleAndToSampleEditor() end}  

-- Sample Editor Process
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Protracker MOD Modulation...",invoke = showProtrackerModDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Strip Silence",invoke=function() PakettiStripSilence() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Move Beginning Silence to End",invoke=function() PakettiMoveSilence() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Move Beginning Silence to End for All Samples",invoke=function() PakettiMoveSilenceAllSamples() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Invert Sample",invoke=PakettiSampleInvertEntireSample}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Invert Left Channel",invoke=PakettiSampleInvertLeftChannel}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Invert Right Channel",invoke=PakettiSampleInvertRightChannel}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Invert Random Samples in Instrument",invoke=PakettiInvertRandomSamplesInInstrument}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:15 Frame Fade In & Fade Out",invoke=function() apply_fade_in_out() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Max Amp DC Offset Kick Generator",invoke=function() pakettiMaxAmplitudeDCOffsetKickCreator() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:FT2 Minimize Selected Sample",invoke=pakettiMinimizeToLoopEnd}
renoise.tool():add_menu_entry {name="--Sample Editor:Paketti:Process:Wrap Signed as Unsigned",invoke=paketti_wrap_signed_as_unsigned}
renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Process:Unwrap Unsigned to Signed",invoke=paketti_unwrap_unsigned_as_signed}
renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Process:Toggle Signed/Unsigned",invoke=paketti_toggle_signed_unsigned}
renoise.tool():add_menu_entry {name="--Sample Editor:Paketti:Process:Scale Signed → Unsigned",invoke=paketti_float_unsign}
renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Process:Scale Unsigned → Signed",invoke=paketti_float_sign}
renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Process:Create Wrecked Sample Variants",invoke=paketti_build_sample_variants}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Offset Dialog...",invoke=pakettiOffsetDialog }
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Normalize Sample",invoke=function() normalize_selected_sample() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Normalize All Samples in Instrument",invoke=function() normalize_all_samples_in_instrument() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Normalize Selected Sample -12dB",invoke=function() normalize_and_reduce("current_sample", -12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Normalize Selected Instrument -12dB (All Samples & Slices)",invoke=function() normalize_and_reduce("all_samples", -12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Normalize All Instruments -12dB",invoke=function() normalize_and_reduce("all_instruments", -12) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Normalize Slices Independently",invoke=function() normalize_selected_sample_by_slices() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Convert Mono to Stereo",invoke=convert_mono_to_stereo_optimized}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Mono to Left with Blank Right",invoke=function() mono_to_blank_optimized(1, 0) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Mono to Right with Blank Left",invoke=function() mono_to_blank_optimized(0, 1) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Convert Stereo to Mono (Mix Both)",invoke=stereo_to_mono_mix_optimized}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert Stereo to Mono (Keep Left)",invoke=function() stereo_to_mono_optimized(1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert Stereo to Mono (Keep Right)",invoke=function() stereo_to_mono_optimized(2) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Convert All Samples to Mono (Keep Left)",invoke=function() convert_all_samples_to_mono("left") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert All Samples to Mono (Keep Right)",invoke=function() convert_all_samples_to_mono("right") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert All Samples to Mono (Mix Both)",invoke=function() convert_all_samples_to_mono("mix") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert to 8-bit", invoke=function() convert_bit_depth(8) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert to 16-bit", invoke=function() convert_bit_depth(16) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert to 24-bit", invoke=function() convert_bit_depth(24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert to 32-bit", invoke=function() convert_bit_depth(32) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert All Samples to 8-bit", invoke=function() convert_all_samples_to_bit_depth(8) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert All Samples to 16-bit", invoke=function() convert_all_samples_to_bit_depth(16) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert All Samples to 24-bit", invoke=function() convert_all_samples_to_bit_depth(24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Convert All Samples to 32-bit", invoke=function() convert_all_samples_to_bit_depth(32) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Process:Cross-fade Sample w/ Fade-In/Out",invoke=function() crossfade_with_fades() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Cross-fade Loop Edges (Fixed End)",invoke=function() crossfade_loop_edges_fixed_end() end}

  -- Sample Editor: Loop Length helpers for all samples in selected instrument
  renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Set All Samples in Selected Instrument to Full Loop",invoke=function() set_loop_length_for_selected_instrument("full") end}
  renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Set All Samples in Selected Instrument to End-Half Loop",invoke=function() set_loop_length_for_selected_instrument("half") end}
  renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Set All Samples in Selected Instrument to Beginning Half Loop",invoke=function() set_loop_length_for_selected_instrument("begin") end}


-- Sample Editor Wipe&Slice
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Wipe&Slice:Wipe Slices",invoke=function() wipeslices() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Double Slices",invoke=function() doubleslices() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Halve Slices",invoke=function() halveslices() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Slice Count From Selection",invoke=function() pakettiSlicesFromSelection() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Prepare Sample for Slicing (Setup + First Slice + Write Note)",invoke=function() prepare_sample_for_slicing() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Auto-Slice Using First Slice Length",invoke=function() detect_first_slice_and_auto_slice() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Select Beat Range 1.0.0 to 9.0.0 (Verification)",invoke=function() select_beat_range_for_verification() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Auto-Slice every 8 beats",invoke=function() auto_slice_every_8_beats() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Whole Hog (Complete Workflow)",invoke=function() whole_hog_complete_workflow() end}

-- Sample Editor Beatsync/Slices
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Beatsync/Slices:Double Beatsync Line",invoke=function() doubleBeatSyncLines() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Beatsync/Slices:Halve Beatsync Line",invoke=function() halveBeatSyncLines() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Beatsync/Slices:Slice Drumkit (Percussion)", invoke=slicePercussionDrumKit}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Beatsync/Slices:Slice Drumkit (Texture)", invoke=sliceTextureDrumKit}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Beatsync/Slices:Beatsync Lines Halve (All)",invoke=function() halveBeatSyncLinesAll() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Beatsync/Slices:Beatsync Lines Halve (Selected Sample)",invoke=function() halveBeatSyncLinesSelected() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Beatsync/Slices:Beatsync Lines Double (All)",invoke=function() doubleBeatSyncLinesAll() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Beatsync/Slices:Beatsync Lines Double (Selected Sample)",invoke=function() doubleBeatSyncLinesSelected() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Beatsync/Slices:Analyze Slice Markers",invoke=function() analyze_slice_markers() end}

-- Sample Editor Instruments
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Instruments:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Instruments:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Instruments:Set Selected Instrument Velocity Tracking On",invoke=function()  selectedInstrumentVelocityTracking(1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Instruments:Set Selected Instrument Velocity Tracking Off",invoke=function() selectedInstrumentVelocityTracking(0) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Convert Beatsync to Sample Pitch",invoke=convert_beatsync_to_pitch}

-- Sample Editor Experimental/WIP
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Xperimental/WIP:Detect Zero Crossings",invoke=detect_zero_crossings}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Xperimental/WIP:Auto Correlate Loop",invoke=auto_correlate}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Xperimental/WIP:Auto Detect Single-Cycle Loop",invoke = auto_detect_single_cycle_loop}
renoise.tool():add_menu_entry{name='Sample Editor:Paketti:Xperimental/WIP:BeatDetector Modified...',invoke=function() pakettiBeatDetectorDialog() end}
renoise.tool():add_menu_entry{name='Sample Editor:Paketti:Xperimental/WIP:BeatDetector Modified (Headless Mode)',invoke=function() BeatSlicerDetect() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Xperimental/WIP:Crossfade Loop",invoke=function()
  local crossfade_length = get_dynamic_crossfade_length()
  if crossfade_length then
    renoise.app():show_status("Using crossfade length: " .. tostring(crossfade_length))
    crossfade_loop(crossfade_length) end end}

    -- Sample Editor Convolver
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Convolver:Import Selected Sample to Convolver",invoke=function()
    print("Importing selected sample to Convolver via Sample Editor menu entry")
    local selected_device = renoise.song().selected_device
    local selected_track_index = renoise.song().selected_track_index
    local selected_device_index = renoise.song().selected_device_index
    if not selected_device or selected_device.name ~= "Convolver" then
      pakettiConvolverSelectionDialog(handle_convolver_action)
      return
    end
    save_instrument_to_convolver(selected_device, selected_track_index, selected_device_index)
  end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Convolver:Show Convolver Selection Dialog",invoke=function()
    print("Showing Convolver Selection Dialog via Sample Editor menu")
    pakettiConvolverSelectionDialog(handle_convolver_action)
  end}

-- Sample Editor Ruler
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti Toggle Sample Selection Info",invoke = toggleSampleDetails}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Select Center of Sample Buffer",invoke=function()pakettiSampleBufferCenterSelector()end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Set Selection by Hex Offset...", invoke = pakettiHexOffsetDialog}

-- Sample Editor Root
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Toggle Sample Selection Info",invoke = toggleSampleDetails}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Create New Instrument & Loop from Selection",invoke=create_new_instrument_from_selection}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Copy Sample in Note-On to Note-Off Layer +24",invoke=function() noteOnToNoteOff(24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Copy Sample in Note-On to Note-Off Layer +12",invoke=function() noteOnToNoteOff(12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Copy Sample in Note-On to Note-Off Layer",invoke=function() noteOnToNoteOff(0) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Copy Sample in Note-On to Note-Off Layer -12",invoke=function() noteOnToNoteOff(-12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Copy Sample in Note-On to Note-Off Layer -24",invoke=function() noteOnToNoteOff(-24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Toggle Loop Range (Selection)",invoke=pakettiToggleLoopRangeSelection}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Unmark / Clear Selection",invoke=pakettiSampleEditorSelectionClear}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Toggle Frequency Analysis",invoke = toggleFrequencyAnalysis}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Cycle Frequency Analysis Cycles (1/2/4/8/16)",invoke = cycleThroughCycles}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load New Instrument with Current Slice Markers",invoke=function() loadNewWithCurrentSliceMarkers() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Map Sample to All Keyzones", invoke=function() mapsample() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Wipe Song Retain Sample",invoke=function() WipeRetain() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Smart Beatsync from Selection",invoke=function() BeatSyncFromSelection() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Paketti Groovebox 8120 Eight 120-fy Instrument",invoke=function() PakettiEight120fy() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Octave Slammer (-3 +3 octaves)",invoke=PakettiOctaveSlammer3}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octave Slammer (-2 +2 octaves)",invoke=PakettiOctaveSlammer2}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octave Slammer (-1 +1 octaves)",invoke=PakettiOctaveSlammer1}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Sample Loop Halve",invoke=function() adjust_loop_range(0.5) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sample Loop Double",invoke=function() adjust_loop_range(2) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sample Loop Length Next Division",invoke=function() cycle_loop_division(true) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sample Loop Length Previous Division",invoke=function() cycle_loop_division(false) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Snap Loop To Nearest Row",invoke=snap_loop_to_rows}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Duplicate Sample Range, Mute Original",invoke = duplicate_sample_range_and_mute_original}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Randomize Selected Sample Finetune/Transpose +6/-6",invoke=function() randomize_sample_pitch_and_finetune(6,6) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Randomize Selected Sample Transpose +6/-6 Finetune +127/-127",invoke=function() randomize_sample_pitch_and_finetune(6,127) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}

-- Sample FX Mixer entries
renoise.tool():add_menu_entry{name="--Sample FX Mixer:Paketti:Enable All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", true) end}
renoise.tool():add_menu_entry{name="Sample FX Mixer:Paketti:Bypass All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", false) end}
renoise.tool():add_menu_entry{name="Sample FX Mixer:Paketti:Enable All Sample FX on All Instruments",invoke=function() sampleFXControls("all", true) end}
renoise.tool():add_menu_entry{name="Sample FX Mixer:Paketti:Bypass All Sample FX on All Instruments",invoke=function() sampleFXControls("all", false) end}
renoise.tool():add_menu_entry{name="Sample FX Mixer:Paketti Gadgets:Quick Load Device Dialog...", invoke=pakettiQuickLoadDialog}
end

--- Sample Navigator Config
if preferences.pakettiMenuConfig.SampleNavigator then
  debugPrint("Sample Navigator Menus Are Enabled")
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Map Sample to All Keyzones", invoke=function() mapsample() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Set Instrument Transpose -24",invoke=function() renoise.song().selected_instrument.transpose=renoise.song().selected_instrument.transpose-24 end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Instrument Transpose -12",invoke=function() renoise.song().selected_instrument.transpose=renoise.song().selected_instrument.transpose-12 end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Instrument Transpose 0",invoke=function() renoise.song().selected_instrument.transpose=0 end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Instrument Transpose +12",invoke=function() renoise.song().selected_instrument.transpose=renoise.song().selected_instrument.transpose+12 end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Instrument Transpose +24",invoke=function() renoise.song().selected_instrument.transpose=renoise.song().selected_instrument.transpose+24 end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Set Loop Mode to Off",invoke=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_OFF) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Loop Mode to Forward",invoke=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_FORWARD) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Loop Mode to PingPong",invoke=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_PING_PONG) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set Loop Mode to Reverse",invoke=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_REVERSE) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti Gadgets:Paketti Stacker Dialog...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Stack All Samples in Instrument with Velocity Mapping Split",invoke=function() fix_sample_velocity_mappings() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Process:Invert Sample",invoke=PakettiSampleInvertEntireSample}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Invert Left Channel",invoke=PakettiSampleInvertLeftChannel}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Invert Right Channel",invoke=PakettiSampleInvertRightChannel}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Invert Random Samples in Instrument",invoke=PakettiInvertRandomSamplesInInstrument}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Save:Paketti Save Selected Sample .WAV",invoke=function() pakettiSaveSample("WAV") end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Save:Paketti Save Selected Sample .FLAC",invoke=function() pakettiSaveSample("FLAC") end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Save:Save All Samples to Folder...",invoke=function() saveAllSamplesToFolder() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Beatsync/Slices:Slice Drumkit (Percussion)", invoke=slicePercussionDrumKit}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Beatsync/Slices:Slice Drumkit (Texture)", invoke=sliceTextureDrumKit}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti Gadgets:Paketti YT-DLP Downloader...",invoke=pakettiYTDLPDialog }
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Octave Slammer (-3 +3 octaves)",invoke=PakettiOctaveSlammer3}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Octave Slammer (-2 +2 octaves)",invoke=PakettiOctaveSlammer2}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Octave Slammer (-1 +1 octaves)",invoke=PakettiOctaveSlammer1}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Wipe&Slice:Wipe Slices",invoke=function() wipeslices() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Double Slices",invoke=function() doubleslices() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Wipe&Slice:Halve Slices",invoke=function() halveslices() end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Autofade/Autoseek:Set Selected Instrument All Autofade On",invoke=function() selectedInstrumentAllAutofadeControl(1) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Autofade/Autoseek:Set Selected Instrument All Autoseek On",invoke=function() selectedInstrumentAllAutoseekControl(1) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Autofade/Autoseek:Set All Instruments All Samples Autoseek Off",invoke=function() setAllInstrumentsAllSamplesAutoseek(0) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Autofade/Autoseek:Set All Instruments All Samples Autofade On",invoke=function() setAllInstrumentsAllSamplesAutofade(1) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Autofade/Autoseek:Set All Instruments All Samples Autofade Off",invoke=function() setAllInstrumentsAllSamplesAutofade(0) end}

renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Beatsync/Slices:Beatsync Lines Halve (All)",invoke=function() halveBeatSyncLinesAll() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Beatsync/Slices:Beatsync Lines Halve (Selected Sample)",invoke=function() halveBeatSyncLinesSelected() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Beatsync/Slices:Beatsync Lines Double (All)",invoke=function() doubleBeatSyncLinesAll() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Beatsync/Slices:Beatsync Lines Double (Selected Sample)",invoke=function() doubleBeatSyncLinesSelected() end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Normalize Sample",invoke=function() normalize_selected_sample() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Normalize All Samples in Instrument",invoke=function() normalize_all_samples_in_instrument() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert to 8-bit", invoke=function() convert_bit_depth(8) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert to 16-bit", invoke=function() convert_bit_depth(16) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert to 24-bit", invoke=function() convert_bit_depth(24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert to 32-bit", invoke=function() convert_bit_depth(32) end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to Mono (Keep Left)",invoke=function() convert_all_samples_to_mono("left") end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to Mono (Keep Right)",invoke=function() convert_all_samples_to_mono("right") end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to Mono (Mix Both)",invoke=function() convert_all_samples_to_mono("mix") end}

renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Process:Convert Mono to Stereo",invoke=convert_mono_to_stereo_optimized}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Mono to Left with Blank Right",invoke=function() mono_to_blank_optimized(1, 0) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Mono to Right with Blank Left",invoke=function() mono_to_blank_optimized(0, 1) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert Stereo to Mono (Keep Left)",invoke=function() stereo_to_mono_optimized(1) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert Stereo to Mono (Keep Right)",invoke=function() stereo_to_mono_optimized(2) end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert Stereo to Mono (Mix Both)",invoke=stereo_to_mono_mix_optimized}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Normalize Selected Sample -12dB",invoke=function() normalize_and_reduce("current_sample", -12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Normalize Selected Instrument -12dB (All Samples & Slices)",invoke=function() normalize_and_reduce("all_samples", -12) end}

  -- Sample Navigator: Loop Length helpers for all samples in selected instrument
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set All Samples in Selected Instrument to Full Loop",invoke=function() set_loop_length_for_selected_instrument("full") end}
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set All Samples in Selected Instrument to End-Half Loop",invoke=function() set_loop_length_for_selected_instrument("half") end}
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Set All Samples in Selected Instrument to Beginning Half Loop",invoke=function() set_loop_length_for_selected_instrument("begin") end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Normalize All Instruments -12dB",invoke=function() normalize_and_reduce("all_instruments", -12) end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Normalize Slices Independently",invoke=function() normalize_selected_sample_by_slices() end}

renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Load .MOD as Sample",invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod", "mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to 8-bit", invoke=function() convert_all_samples_to_bit_depth(8) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to 16-bit", invoke=function() convert_all_samples_to_bit_depth(16) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to 24-bit", invoke=function() convert_all_samples_to_bit_depth(24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Convert All Samples to 32-bit", invoke=function() convert_all_samples_to_bit_depth(32) end}

  -- Sample Navigator: Instruments – FX/Mod distribution and deletion
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:FX/MOD:Distribute All Samples to Separate FX Chains",invoke=function() selectedInstrumentDistributeToSeparateFxChains() end}
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:FX/MOD:Delete All Sample FX Chains",invoke=function() selectedInstrumentDeleteAllSampleFxChains() end}
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:FX/MOD:Distribute All Samples to Separate Modulation Sets",invoke=function() selectedInstrumentDistributeToSeparateModulationSets() end}
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:FX/MOD:Distribute All Samples to Separate FX & Mod Sets",invoke=function() selectedInstrumentDistributeToSeparateFxAndModChains() end}
  renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:FX/MOD:Delete All Modulation Sets",invoke=function() selectedInstrumentDeleteAllSampleModulationSets() end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Strip Silence",invoke=function() PakettiStripSilence() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Process:Move Beginning Silence to End",invoke=function() PakettiMoveSilence() end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Move Beginning Silence to End for All Samples",invoke=function() PakettiMoveSilenceAllSamples() end}


renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Copy Sample in Note-On to Note-Off Layer +24",invoke=function() noteOnToNoteOff(24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Copy Sample in Note-On to Note-Off Layer +12",invoke=function() noteOnToNoteOff(12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Copy Sample in Note-On to Note-Off Layer",invoke=function() noteOnToNoteOff(0) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Copy Sample in Note-On to Note-Off Layer -12",invoke=function() noteOnToNoteOff(-12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Copy Sample in Note-On to Note-Off Layer -24",invoke=function() noteOnToNoteOff(-24) end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}


renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Protracker MOD Modulation...",invoke = showProtrackerModDialog}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti Gadgets:Paketti Sample Adjust Dialog...",invoke = show_paketti_sample_adjust_dialog}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Wipe Song Retain Sample",invoke=function() WipeRetain() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Process:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Process:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Autofade/Autoseek:Set All Instruments All Samples Autoseek On",invoke=function() setAllInstrumentsAllSamplesAutoseek(1) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Delete Unused Samples...",invoke=deleteUnusedSamples}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Create Wrecked Sample Variants",invoke=paketti_build_sample_variants}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export Current Sample as IFF...",invoke = saveCurrentSampleAsIFF}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Export:Export .PTI Instrument",invoke=pti_savesample}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti Gadgets:Keyzone Distributor Dialog...",invoke=function() pakettiKeyzoneDistributorDialog() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Paketti Drumkit Loader MuteTrig (Randomize)",invoke=function() selectedInstrumentLoadMuteTrigDrumkit() end}







end




--- Sample Keyzone Config
if preferences.pakettiMenuConfig.SampleKeyzone then
debugPrint("Sample Keyzone Menus Are Enabled")
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti Gadgets:Paketti Sample Adjust Dialog...",invoke = show_paketti_sample_adjust_dialog}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti Gadgets:Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti Gadgets:Keyzone Distributor Dialog...",invoke=function() pakettiKeyzoneDistributorDialog() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti Gadgets:Paketti Stacker Dialog...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}

-- Sample Mappings Load
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Convert IFF to WAV...",invoke = convertIFFToWAV}


-- Sample Mappings Save
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Save:Export .PTI Instrument",invoke=pti_savesample}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Save:Save Current Sample as IFF...",invoke = saveCurrentSampleAsIFF}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Save:Paketti Save Selected Sample .WAV",invoke=function() pakettiSaveSample("WAV") end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Save:Paketti Save Selected Sample .FLAC",invoke=function() pakettiSaveSample("FLAC") end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Save:Save All Samples to Folder...",invoke=function() saveAllSamplesToFolder() end}

-- Sample Mappings Export

-- Sample Mappings Process
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Normalize Sample",invoke=function() normalize_selected_sample() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Normalize All Samples in Instrument",invoke=function() normalize_all_samples_in_instrument() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Process:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Process:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Process:Invert Sample",invoke=PakettiSampleInvertEntireSample}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Invert Left Channel",invoke=PakettiSampleInvertLeftChannel}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Invert Right Channel",invoke=PakettiSampleInvertRightChannel}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Invert Random Samples in Instrument",invoke=PakettiInvertRandomSamplesInInstrument}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Normalize Selected Sample -12dB",invoke=function() normalize_and_reduce("current_sample", -12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Normalize Selected Instrument -12dB (All Samples & Slices)",invoke=function() normalize_and_reduce("all_samples", -12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Normalize All Instruments -12dB",invoke=function() normalize_and_reduce("all_instruments", -12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to Mono (Keep Left)",invoke=function() convert_all_samples_to_mono("left") end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to Mono (Keep Right)",invoke=function() convert_all_samples_to_mono("right") end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to Mono (Mix Both)",invoke=function() convert_all_samples_to_mono("mix") end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Strip Silence",invoke=function() PakettiStripSilence() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Process:Move Beginning Silence to End",invoke=function() PakettiMoveSilence() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Move Beginning Silence to End for All Samples",invoke=function() PakettiMoveSilenceAllSamples() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert to 8-bit", invoke=function() convert_bit_depth(8) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert to 16-bit", invoke=function() convert_bit_depth(16) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert to 24-bit", invoke=function() convert_bit_depth(24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert to 32-bit", invoke=function() convert_bit_depth(32) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to 8-bit", invoke=function() convert_all_samples_to_bit_depth(8) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to 16-bit", invoke=function() convert_all_samples_to_bit_depth(16) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to 24-bit", invoke=function() convert_all_samples_to_bit_depth(24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert All Samples to 32-bit", invoke=function() convert_all_samples_to_bit_depth(32) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert Stereo to Mono (Mix Both)",invoke=stereo_to_mono_mix_optimized}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Process:Convert Mono to Stereo",invoke=convert_mono_to_stereo_optimized}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Mono to Left with Blank Right",invoke=function() mono_to_blank_optimized(1, 0) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Mono to Right with Blank Left",invoke=function() mono_to_blank_optimized(0, 1) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert Stereo to Mono (Keep Left)",invoke=function() stereo_to_mono_optimized(1) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Process:Convert Stereo to Mono (Keep Right)",invoke=function() stereo_to_mono_optimized(2) end}


-- Sample Mappings Phrases
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Phrases:Load XRNI & Wipe Phrases",invoke=function() loadXRNIWipePhrases() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Phrases:Load XRNI & Disable Phrases",invoke=function() loadXRNIWipePhrasesTwo() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Phrases:Load XRNI & Keep Phrases",invoke=function() loadXRNIKeepPhrases() end}        

-- Sample Mappings Root
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Delete Unused Samples...",invoke=deleteUnusedSamples}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Set Selected Sample (+1) Velocity Range 7F others 00",invoke=function() sample_one_down() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Selected Sample (-1) Velocity Range 7F others 00",invoke=function() sample_one_up() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Selected Sample (Random) Velocity Range 7F others 00",invoke=function() sample_random() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Map Sample to All Keyzones", invoke=function() mapsample() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Stack All Samples in Instrument with Velocity Mapping Split",invoke=function() fix_sample_velocity_mappings() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Phrases:Wipe Phrases on Selected Instrument",invoke=function() wipePhrases() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Copy Sample in Note-On to Note-Off Layer +24",invoke=function() noteOnToNoteOff(24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Copy Sample in Note-On to Note-Off Layer +12",invoke=function() noteOnToNoteOff(12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Copy Sample in Note-On to Note-Off Layer",invoke=function() noteOnToNoteOff(0) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Copy Sample in Note-On to Note-Off Layer -12",invoke=function() noteOnToNoteOff(-12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Copy Sample in Note-On to Note-Off Layer -24",invoke=function() noteOnToNoteOff(-24) end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Octave Slammer (-3 +3 octaves)",invoke=PakettiOctaveSlammer3}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octave Slammer (-2 +2 octaves)",invoke=PakettiOctaveSlammer2}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octave Slammer (-1 +1 octaves)",invoke=PakettiOctaveSlammer1}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Cycle Overlap Mode",invoke=overlayModeCycle}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Overlap Mode 0 (Play All)",invoke=function() setOverlapMode(0) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Overlap Mode 1 (Cycle)",invoke=function() setOverlapMode(1) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Overlap Mode 2 (Random)",invoke=function() setOverlapMode(2) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Drumkit to Overlap Random",invoke=function() DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Set Selected Instrument Velocity Tracking On",invoke=function()  selectedInstrumentVelocityTracking(1) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Set Selected Instrument Velocity Tracking Off",invoke=function() selectedInstrumentVelocityTracking(0) end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}


renoise.tool():add_menu_entry{name="--Sample Modulation Matrix:Paketti:PitchStepper Demo",invoke=function() pakettiPitchStepperDemo() end}
renoise.tool():add_menu_entry{name="--Sample Modulation Matrix:Paketti:Reset All Steppers",invoke = ResetAllSteppers}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Show/Hide PitchStep on Selected Instrument",invoke=function() PakettiShowStepper("Pitch Stepper") end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Show/Hide VolumeStep on Selected Instrument",invoke=function() PakettiShowStepper("Volume Stepper") end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Clear PitchStep Steps",invoke=function() PakettiClearStepper("Pitch Stepper") end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Modify PitchStep Steps (Random)",invoke=function() PakettiFillStepperRandom("Pitch Stepper") end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Modify PitchStep Steps (Octave Up, Octave Down)",invoke=function() PakettiFillPitchStepper() end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Modify PitchStep Steps (Octave Up+2, Octave Down-2)",invoke=function() PakettiFillPitchStepperTwoOctaves() end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti:Modify PitchStep Steps (Hard Detune)",invoke=function() PakettiFillPitchStepperDigits(0.05,64) end}



end

--- Mixer Config
if preferences.pakettiMenuConfig.Mixer then
  debugPrint("Mixer Menus Are Enabled")
renoise.tool():add_menu_entry{name="Mixer:Paketti Gadgets:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="Mixer:Paketti Gadgets:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Show/Hide User Preference Devices Master Dialog (SlotShow)...",invoke=function() pakettiUserPreferencesShowerDialog() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Automation:Snapshot All Devices on Selected Track to Automation",invoke = snapshot_all_devices_to_automation}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Automation:Snapshot Selected Device to Automation",invoke = snapshot_selected_device_to_automation}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Automation:Convert FX to Automation",invoke = function() read_fx_to_automation(false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Automation:Convert FX to Automation (Move)",invoke = function() read_fx_to_automation(true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Automation:Convert Automation to FX",invoke = function() write_automation_to_fx(false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Automation:Convert Automation to FX (Move)",invoke = function() write_automation_to_fx(true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}

renoise.tool():add_menu_entry{name="--Mixer:Paketti:LFO Write:LFO Write to Phrase LPB (1-255)",invoke=function() toggle_lpb_following(255) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Phrase LPB (1-127)",invoke=function() toggle_lpb_following(127) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Phrase LPB (1-64)",invoke=function() toggle_lpb_following(64) end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:Single Parameter Write to Automation",invoke = toggle_single_parameter_following}


renoise.tool():add_menu_entry{name="--Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (Amount Only)",invoke=function() toggle_fx_amount_following() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (0Yxx)",invoke=function() toggle_fx_amount_following("0Y") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (0Sxx)",invoke=function() toggle_fx_amount_following("0S") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (0Dxx)",invoke=function() toggle_fx_amount_following("0D") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (0Uxx)",invoke=function() toggle_fx_amount_following("0U") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (0Gxx)",invoke=function() toggle_fx_amount_following("0G") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:LFO Write:LFO Write to Effect Column 1 (0Rxx)",invoke=function() toggle_fx_amount_following("0R") end}


renoise.tool():add_menu_entry{name="Mixer:Paketti:Duplicate Track Duplicate Instrument",invoke=function() duplicateTrackDuplicateInstrument() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti Gadgets:Value Interpolation Looper Dialog...",invoke = pakettiVolumeInterpolationLooper}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Reset Delay Output to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Reset Delay Output to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Create Identical Track",invoke=create_identical_track}

renoise.tool():add_menu_entry{name="--Mixer:Paketti:Populate GlobalGainers on Each Track (start chain)",invoke=function() PopulateGainersOnEachTrack("start") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Populate GlobalGainers on Each Track (end chain)",invoke=function() PopulateGainersOnEachTrack("end") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Automation:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}

renoise.tool():add_menu_entry{name="--Mixer:Paketti:Add Gainer A to Selected Track",invoke=function() AddGainerCrossfadeSelectedTrack("A") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Add Gainer B to Selected Track",invoke=function() AddGainerCrossfadeSelectedTrack("B") end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Flip Gainers A/B",invoke=function() flip_gainers() end}

renoise.tool():add_menu_entry{name="--Mixer:Paketti:Delay Output:Nudge Delay Output +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Nudge Delay Output -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Reset Delay Output to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Delay Output:Reset Delay Output to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Populate Send Tracks for All Tracks",invoke=PakettiPopulateSendTracksAllTracks}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Populate Send Tracks for Selected Track",invoke=PakettiPopulateSendTracksSelectedTrack}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Decrease All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(-3) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Increase All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(3) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Clean Render:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection(false) end}

renoise.tool():add_menu_entry{
    name="Mixer:Paketti:Clean Render:Clean Render Selected Track/Group (WAV Only)", -- CMD-R / ⌘-R",
    invoke=function()
        print("DEBUG WAV: About to call pakettiCleanRenderSelection with true")
pakettiCleanRenderSelection(true)  end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Quick Load Device Dialog...", invoke=pakettiQuickLoadDialog}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Initialize for Groovebox 8120",invoke=function() 
  PakettiEightOneTwentyInit()
  end}

  renoise.tool():add_menu_entry{name="--Mixer:Paketti:Clear/Wipe Selected Track TrackDSPs",invoke=function() wipeSelectedTrackTrackDSPs() end}
  renoise.tool():add_menu_entry{name="--Mixer:Paketti:Tracks:Panning - Set All Tracks to Hard Left",invoke=function() globalLeft() end}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Tracks:Panning - Set All Tracks to Hard Right",invoke=function() globalRight() end}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Tracks:Panning - Set All Tracks to Center",invoke=function() globalCenter() end}
  renoise.tool():add_menu_entry{name="--Mixer:Paketti:Devices:Move DSPs to Previous Track",invoke=function() move_dsps_to_adjacent_track(-1) end}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Devices:Move DSPs to Next Track",invoke=function() move_dsps_to_adjacent_track(1) end}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Tracks:Create Group and Move DSPs",invoke=create_group_and_move_dsps}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Pattern:Duplicate Pattern Below & Clear Muted",invoke=duplicate_pattern_and_clear_muted}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Pattern:Duplicate Pattern Above & Clear Muted",invoke=duplicate_pattern_and_clear_muted_above}
  renoise.tool():add_menu_entry{name="--Mixer:Paketti:Uncollapse All Tracks",invoke=function() Uncollapser() end}
  renoise.tool():add_menu_entry{name="Mixer:Paketti:Collapse All Tracks",invoke=function() Collapser() end}

renoise.tool():add_menu_entry{name="Mixer:Paketti ChordsPlus:Duplicate Highest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "duplicate") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti ChordsPlus:Duplicate Highest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "selected") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti ChordsPlus:Duplicate Highest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "original") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti ChordsPlus:Duplicate Lowest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "duplicate") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti ChordsPlus:Duplicate Lowest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "selected") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti ChordsPlus:Duplicate Lowest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "original") end}
renoise.tool():add_menu_entry{name="Mixer:Device:Parama Param Next Parameter",invoke = param_next}
renoise.tool():add_menu_entry{name="Mixer:Device:Parama Param Previous Parameter",invoke = param_prev}
renoise.tool():add_menu_entry{name="Mixer:Device:Parama Param Increase",invoke = param_up}
renoise.tool():add_menu_entry{name="Mixer:Device:Parama Param Decrease",invoke = param_down}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Auto Assign Outputs",invoke=AutoAssignOutputs}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Device Chains:Open Track DSP Device & Instrument Loader...",invoke=function() pakettiDeviceChainDialog() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Expose/Hide Selected Device Parameters",invoke=function() exposeHideParametersInMixer() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Expose/Hide Selected Track ALL Device Parameters",invoke=function() exposeHideAllParametersInMixer() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Enable All Devices on Track",invoke=function() effectenable() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Bypass All Devices on Track",invoke=function() effectbypass() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Enable All Devices on All Tracks",invoke=function() PakettiAllDevices(true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Bypass All Devices on All Tracks",invoke=function() PakettiAllDevices(false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Bypass/Enable All Other Track DSP Devices (Toggle)",invoke=function() toggle_bypass_selected_device() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Insert Stereo -> Mono device to Beginning of DSP Chain",invoke=function() insertMonoToBeginning() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Insert Stereo -> Mono device to End of DSP Chain",invoke=function() insertMonoToEnd() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Randomize Selected Device Parameters",invoke=function()randomize_selected_device()end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti Gadgets:Randomize Devices and Plugins Dialog...",invoke=function() pakettiRandomizerDialog() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Toggle Automatically Open Selected Track Device Editors On/Off",invoke = PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Insert Stereo -> Mono device to End of ALL DSP Chains",invoke=function() insertMonoToAllTracksEnd() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Tracks:Rename Tracks By Played Samples",invoke=function() rename_tracks_by_played_samples() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Tracks:Rename Current Track to Selected Instrument Name",invoke=function() PakettiRenameCurrentTrackToSelectedInstrument() end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Clean Render:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Clean Render:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Clean Render:Clean Render and Save Selected Track/Group as .WAV",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Clean Render:Clean Render and Save Selected Track/Group as .FLAC",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Duplicate Track and Instrument",invoke=duplicateTrackAndInstrument}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Show Paketti Formula Device Manual Dialog...",invoke = pakettiFormulaDeviceDialog}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Add Input Inertia Formula Device",invoke = add_input_inertia}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Start Sampling and Sample Editor (Record)",invoke=function() PakettiSampleAndToSampleEditor() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Record:Paketti Overdub 12 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,12) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Paketti Overdub 12 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,12) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,12) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Record:Paketti Overdub 01 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,1) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Paketti Overdub 01 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,1) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,1) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Record:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,1) end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Tracks:Duplicate Track, set to Selected Instrument",invoke=function() setToSelectedInstrument_DuplicateTrack() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Convolver:Import Selected Sample to Convolver",invoke=function()
  print("Importing selected sample to Convolver via Mixer menu entry")
  local selected_device = renoise.song().selected_device
  local selected_track_index = renoise.song().selected_track_index
  local selected_device_index = renoise.song().selected_device_index
  if not selected_device or selected_device.name ~= "Convolver" then
    pakettiConvolverSelectionDialog(handle_convolver_action)
    return
  end
  save_instrument_to_convolver(selected_device, selected_track_index, selected_device_index)
end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:Convolver:Export Convolver IR into New Instrument",invoke=function()
  print("Exporting Convolver IR into New Instrument via menu entry")
  local selected_device = renoise.song().selected_device
  local selected_track_index = renoise.song().selected_track_index
  local selected_device_index = renoise.song().selected_device_index
  if not selected_device or selected_device.name ~= "Convolver" then
    pakettiConvolverSelectionDialog(handle_convolver_action)
    return
  end
  create_instrument_from_convolver(selected_device, selected_track_index, selected_device_index)
end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Convolver:Show Convolver Selection Dialog",invoke=function() pakettiConvolverSelectionDialog(handle_convolver_action) end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti Gadgets:Paketti Fuzzy Search Track...",invoke = pakettiFuzzySearchTrackDialog}


end



--- Pattern Editor Config
if preferences.pakettiMenuConfig.PatternEditor then
  
  --- Gadgets
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Beat Structure Editor...",invoke=pakettiBeatStructureEditorDialog}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Timestretch Dialog...",invoke=pakettiTimestretchDialog}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Groovebox 8120...",invoke=function() GrooveboxShowClose() end}  
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Effect Column CheatSheet...",invoke=function() pakettiPatternEditorCheatsheetDialog() end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Dialog of Dialogs...",invoke=function() pakettiDialogOfDialogsToggle() end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Gater...",invoke=function()
    local max_rows = renoise.song().selected_pattern.number_of_lines
    if renoise.song() then
      pakettiGaterDialog()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:(WIP) Paketti Tuplet Writer Dialog...",invoke=function() pakettiTupletDialog() end}

  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Snapshot All Devices on Selected Track to Automation",invoke = snapshot_all_devices_to_automation}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Snapshot Selected Device to Automation",invoke = snapshot_selected_device_to_automation}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Automation:Convert FX to Automation",invoke = function() read_fx_to_automation(false) end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Convert FX to Automation (Move)",invoke = function() read_fx_to_automation(true) end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Convert Automation to FX",invoke = function() write_automation_to_fx(false) end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Convert Automation to FX (Move)",invoke = function() write_automation_to_fx(true) end}
  
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (Amount Only)",invoke=function() toggle_fx_amount_following() end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (0Yxx)",invoke=function() toggle_fx_amount_following("0Y") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (0Sxx)",invoke=function() toggle_fx_amount_following("0S") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (0Dxx)",invoke=function() toggle_fx_amount_following("0D") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (0Uxx)",invoke=function() toggle_fx_amount_following("0U") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (0Gxx)",invoke=function() toggle_fx_amount_following("0G") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:LFO Write to Effect Column 1 (0Rxx)",invoke=function() toggle_fx_amount_following("0R") end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:LFO Write:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:LFO Write:Single Parameter Write to Automation",invoke = toggle_single_parameter_following}

  

  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Generate Delay Value on Note Columns",invoke=function() GenerateDelayValue("row") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Generate Delay Value on Entire Pattern",invoke=function() GenerateDelayValue("pattern") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Generate Delay Value on Selection",invoke=function() GenerateDelayValue("selection") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Generate Delay Value (Notes Only, Row)",invoke=function() GenerateDelayValueNotes("row") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Generate Delay Value (Notes Only, Pattern)",invoke=function() GenerateDelayValueNotes("pattern") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Generate Delay Value (Notes Only, Selection)",invoke=function() GenerateDelayValueNotes("selection") end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Note Columns:Roll the Dice on Notes in Selection",invoke=function() randomize_notes_in_selection() end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Reverse Notes in Selection",invoke=PakettiReverseNotesInSelection}

  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Populate Send Tracks for All Tracks",invoke=PakettiPopulateSendTracksAllTracks}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Populate Send Tracks for Selected Track",invoke=PakettiPopulateSendTracksSelectedTrack}
  
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Create Phrase",invoke=function() createPhrase() end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Create Identical Track",invoke=create_identical_track}

  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Switch to Automation",invoke=function() showAutomation() end}

  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Note Columns:Invert Note Column Subcolumns",invoke=function() invert_content("notecolumns") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Invert Effect Column Subcolumns",invoke=function() invert_content("effectcolumns") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Invert All Subcolumns",invoke=function() invert_content("all") end}

  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:VolDelayPan Slider Dialog...",invoke=function() pakettiVolDelayPanSliderDialog() end}

  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Clean Render and Save Selected Track/Group as .WAV",invoke=function() CleanRenderAndSaveSelection("WAV") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Clean Render and Save Selected Track/Group as .FLAC",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Instruments:Duplicate and Reverse Instrument",invoke=PakettiDuplicateAndReverseInstrument}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Automation:Wipe All Automation in Track on Current Pattern",invoke=function() delete_automation(false, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Wipe All Automation in All Tracks on Current Pattern",invoke=function() delete_automation(true, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Wipe All Automation in Track on Whole Song",invoke=function() delete_automation(false, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Automation:Wipe All Automation in All Tracks on Whole Song",invoke=function() delete_automation(true, true) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:Wipe All Effect Columns on Selected Track on Current Pattern",invoke=function() wipe_effect_columns(false, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Wipe All Effect Columns on Selected Track on Song",invoke=function() wipe_effect_columns(false, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Wipe All Effect Columns on Selected Pattern",invoke=function() wipe_effect_columns(true, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Wipe All Effect Columns on Song",invoke=function() wipe_effect_columns(true, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Multiply BPM & Halve LPB",invoke=function() multiply_bpm_halve_lpb() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Halve BPM & Multiply LPB",invoke=function() halve_bpm_multiply_lpb() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Instruments:Enable All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Instruments:Bypass All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Instruments:Enable All Sample FX on All Instruments",invoke=function() sampleFXControls("all", true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Instruments:Bypass All Sample FX on All Instruments",invoke=function() sampleFXControls("all", false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Flood Fill from Current Row w/ AutoArp",invoke=pakettiFloodFillFromCurrentRow}

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Transposer Row +03",invoke=function() PakettiTransposer(3, false) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Distribute (Even 2)",invoke=function() DistributeNotes("even2") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Distribute (Even 4)",invoke=function() DistributeNotes("even4") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Distribute (Uneven)",invoke=function() DistributeNotes("uneven") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Distribute (Always Next Row)",invoke=function() DistributeNotes("nextrow") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Distribute Across Selection (Even)",invoke=function() DistributeAcrossSelection("even") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Distribute Across Selection (Even 2)",invoke=function() DistributeAcrossSelection("even2") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Distribute Across Selection (Even 4)",invoke=function() DistributeAcrossSelection("even4") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Distribute Across Selection (Uneven)",invoke=function() DistributeAcrossSelection("uneven") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Auto Assign Outputs",invoke=AutoAssignOutputs}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Other Trackers:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Select Current Row",invoke=PakettiSelectCurrentRow}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Convert Global Groove to Delay on Selected Track/Group",invoke=pakettiGrooveToDelay}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Enable All Devices on Track",invoke=function() effectenable() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Bypass All Devices on Track",invoke=function() effectbypass() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Devices:Enable All Devices on All Tracks",invoke=function() PakettiAllDevices(true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Bypass All Devices on All Tracks",invoke=function() PakettiAllDevices(false) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Devices:Insert Stereo -> Mono device to End of ALL DSP Chains",invoke=function() insertMonoToAllTracksEnd() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Generate&Randomize:Write 0Sxx Command Random Slice/Offset",invoke=function() write_random_slice_command() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Rename Tracks By Played Samples",invoke=function() rename_tracks_by_played_samples() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Rename Current Track to Selected Instrument Name",invoke=function() PakettiRenameCurrentTrackToSelectedInstrument() end}


  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Interpolate Column Values (Volume)",invoke=function() volume_interpolation() end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Interpolate Column Values (Delay)",invoke=function() delay_interpolation() end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Interpolate Column Values (Panning)",invoke=function() panning_interpolation() end}
  renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Interpolate Column Values (Sample FX)",invoke=function() samplefx_interpolation() end}

  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Double LPB",invoke=function() PakettiLPBDouble() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Halve LPB",invoke=function() PakettiLPBHalve() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Double Double LPB",invoke=function() PakettiLPBDouble() PakettiLPBDouble() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Halve Halve LPB",invoke=function() PakettiLPBHalve() PakettiLPBHalve() end}

renoise.tool():add_menu_entry{
  name="Pattern Editor:Paketti:Clean Render:Clean Render Selected Track/Group",
  invoke=function() pakettiCleanRenderSelection(false) end
}
renoise.tool():add_menu_entry{
  name="Pattern Editor:Paketti:Clean Render:Clean Render Selected Track/Group (WAV Only)",
  invoke=function() 
      print("DEBUG WAV: About to call pakettiCleanRenderSelection with true")
      pakettiCleanRenderSelection(true) 
  end
}

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:BPM&LPB:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Play Samples Backwards in Selection 0B00",invoke=add_backwards_effect_to_selection}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Duplicate Track and Instrument",invoke=duplicateTrackAndInstrument}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Open Player Pro Note Column Dialog...",invoke=pakettiPlayerProNoteGridShowDropdownGrid}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Open Player Pro Tools Effect Dialog",invoke=function() pakettiPlayerProEffectDialog() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Open Player Pro Tools Dialog...",invoke=pakettiPlayerProShowMainDialog}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Duplicate Track, set to Selected Instrument",invoke=function() setToSelectedInstrument_DuplicateTrack() end}


renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to current Pattern length",invoke = resize_all_non_empty_patterns_to_current_pattern_length}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 012",invoke=function() resize_all_non_empty_patterns_to(12) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 016",invoke=function() resize_all_non_empty_patterns_to(016) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 024",invoke=function() resize_all_non_empty_patterns_to(024) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 032",invoke=function() resize_all_non_empty_patterns_to(032) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 048",invoke=function() resize_all_non_empty_patterns_to(048) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 064",invoke=function() resize_all_non_empty_patterns_to(064) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 096",invoke=function() resize_all_non_empty_patterns_to(96) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 128",invoke=function() resize_all_non_empty_patterns_to(128) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 192",invoke=function() resize_all_non_empty_patterns_to(192) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 256",invoke=function() resize_all_non_empty_patterns_to(256) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 384",invoke=function() resize_all_non_empty_patterns_to(384) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize all non-empty Patterns:Resize all non-empty Patterns to 512",invoke=function() resize_all_non_empty_patterns_to(512) end}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Hide All Unused Columns (All Tracks)", invoke=function() PakettiHideAllUnusedColumns() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Hide All Unused Columns (Selected Track)", invoke=function() PakettiHideAllUnusedColumnsSelectedTrack() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write Notes:Write Notes Ascending",invoke=function() writeNotesMethod("ascending") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write Notes:Write Notes Descending",invoke=function() writeNotesMethod("descending") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write Notes:Write Notes Random",invoke=function() writeNotesMethod("random") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write Notes:Write Notes EditStep Ascending",invoke=function() writeNotesMethodEditStep("ascending") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write Notes:Write Notes EditStep Descending",invoke=function() writeNotesMethodEditStep("descending") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write Notes:Write Notes EditStep Random",invoke=function() writeNotesMethodEditStep("random") end}


renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Paketti Speed and Tempo to BPM Dialog...",invoke=pakettiSpeedTempoDialog}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Copy Above Effect Column",invoke=function() handle_above_effect_command("copy") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Copy Above Effect Column + Increase Value",invoke=function() handle_above_effect_command("inc") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Copy Above Effect Column + Decrease Value",invoke=function() handle_above_effect_command("dec") end}

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Decrease All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(-3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Increase All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(3) end}


renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Paketti Stacker:Paketti Stacker Dialog...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle All Columns",invoke=function() toggleColumns(true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle All Columns (No Sample Effects)",invoke=function() toggleColumns(false) end}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Show Only Volume Columns",invoke=function() showOnlyColumnType("volume") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Show Only Panning Columns",invoke=function() showOnlyColumnType("panning") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Show Only Delay Columns",invoke=function() showOnlyColumnType("delay") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Show Only Effect Columns",invoke=function() showOnlyColumnType("effects") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Show Only Volume Columns",invoke=function() showOnlyColumnType("volume") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Show Only Panning Columns",invoke=function() showOnlyColumnType("panning") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Show Only Delay Columns",invoke=function() showOnlyColumnType("delay") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Show Only Effect Columns",invoke=function() showOnlyColumnType("effects") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Paketti Stacker:Write Velocity Ramp Up for Stacked Instrument",invoke=function() write_velocity_ramp_up() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Paketti Stacker:Write Velocity Ramp Down for Stacked Instrument",invoke=function() write_velocity_ramp_down() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Paketti Stacker:Write Velocity Random for Stacked Instrument",invoke=function() write_random_velocity_notes() end}


renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Wipe&Slice&Write to Pattern",invoke = function() WipeSliceAndWrite() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Create Pattern Sequencer Patterns based on Slice Count with Automatic Slice Printing",invoke = createPatternSequencerPatternsBasedOnSliceCount}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Delete all Pattern Sequences",invoke=function() delete_all_pattern_sequences() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delete Unused Columns", invoke = deleteUnusedColumns}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Instruments:Hide All Instrument Properties",invoke=function() hideAllInstrumentProperties() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Instruments:Show All Instrument Properties",invoke=function() showAllInstrumentProperties() end}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Reset Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Reset Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Delay Output:Nudge Delay Output +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Nudge Delay Output -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Reset Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delay Output:Reset Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}



renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Start/Stop Column Cycling",invoke=function() startcolumncycling() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz Special (2)",invoke=function() ColumnCycleKeyjazzSpecial(2) end}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize&Fill:Paketti Pattern Resize and Fill 032",invoke=function() pakettiResizeAndFill(32) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize&Fill:Paketti Pattern Resize and Fill 064",invoke=function() pakettiResizeAndFill(64) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize&Fill:Paketti Pattern Resize and Fill 128",invoke=function() pakettiResizeAndFill(128) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize&Fill:Paketti Pattern Resize and Fill 256",invoke=function() pakettiResizeAndFill(256) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Resize&Fill:Paketti Pattern Resize and Fill 512",invoke=function() pakettiResizeAndFill(512) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:OctaMED Pick/Put Dialog...",invoke=function() pakettiOctaMEDPickPutRowDialog() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:OctaMED Note Spread Increment",invoke=function() IncrementSpread() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:OctaMED Note Spread Decrement",invoke=function() DecrementSpread() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:OctaMED Note Echo Dialog...",invoke = pakettiOctaMEDNoteEchoDialog}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Uncollapse All Tracks",invoke=function() Uncollapser() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Collapse All Tracks",invoke=function() Collapser() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Paketti Pattern Doubler",invoke=pakettiPatternDoubler}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Paketti Pattern Halver",invoke=pakettiPatternHalver}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Renoise Random BPM & Write BPM/LPB to Master",invoke=function() randomBPMMaster() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Write Current BPM&LPB to Master Column",invoke=function() write_bpm() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:BPM&LPB:Random BPM (60-180)",invoke=function() randomBPM() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:BPM&LPB:Play at 75% Speed (Song BPM)",invoke=function() playat75()  end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM&LPB:Play at 100% Speed (Song BPM)",invoke=function() returnbackto100()  end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Clear Effect Columns",invoke=function() delete_effect_column() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:(L00) Set Track Volume Level",invoke=function() voloff() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:(Uxx) Selection Slide Pitch Up +1",invoke=function() effectamount(1,"0U") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Uxx) Selection Slide Pitch Up +10",invoke=function() effectamount(10,"0U") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Uxx) Selection Slide Pitch Up -1",invoke=function() effectamount(-1,"0U") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Uxx) Selection Slide Pitch Up -10",invoke=function() effectamount(-10,"0U") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:(Dxx) Selection Slide Pitch Down +1",invoke=function() effectamount(1,"0D") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Dxx) Selection Slide Pitch Down +10",invoke=function() effectamount(10,"0D") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Dxx) Selection Slide Pitch Down -1",invoke=function() effectamount(-1,"0D") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Dxx) Selection Slide Pitch Down -10",invoke=function() effectamount(-10,"0D") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:(Gxx) Selection Glide +1",invoke=function() effectamount(1,"0G") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Gxx) Selection Glide +10",invoke=function() effectamount(10,"0G") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Gxx) Selection Glide -1",invoke=function() effectamount(-1,"0G") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:(Gxx) Selection Glide -10",invoke=function() effectamount(-10,"0G") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:Switch Effect Column/Note Column",invoke=function() switchcolumns() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:ZBxx Jump To Row (Next)",invoke=function() JumpToNextRow() end}
  
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Match Effect Column EditStep with Note Placement",invoke=function() toggle_match_editstep_effect() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Match Note Column EditStep with Note Placement",invoke=function() toggle_match_editstep_note() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Clear Selected Track Above Current Row",invoke=function() clear_track_direction("above",false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Clear Selected Track Below Current Row",invoke=function() clear_track_direction("below",false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Clear All Tracks Above Current Row",invoke=function() clear_track_direction("above",true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Clear All Tracks Below Current Row",invoke=function() clear_track_direction("below",true) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Panning - Set All Tracks to Hard Left",invoke=function() globalLeft() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Panning - Set All Tracks to Hard Right",invoke=function() globalRight() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Panning - Set All Tracks to Center",invoke=function() globalCenter() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Create New Pattern from Selection",invoke=function() SelectionToNewPattern() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Hide All Effect Columns",invoke=function() HideAllEffectColumns() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Move Track Left",invoke=moveTrackLeft}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Move Track Right",invoke=moveTrackRight}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Generate&Randomize:Random Selected Notes Octave Up 25% Probability",invoke=function() randomly_raise_selected_notes_one_octave(0.25) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Generate&Randomize:Random Selected Notes Octave Up 50% Probability",invoke=function() randomly_raise_selected_notes_one_octave(0.5) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Generate&Randomize:Random Selected Notes Octave Up 75% Probability",invoke=function() randomly_raise_selected_notes_one_octave(0.75) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Fill Effect Column with 0D00",invoke=function() writeEffectToPattern("0D00") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Fill Effect Column with 0U00",invoke=function() writeEffectToPattern("0U00") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Fill Effect Column with 0G01+0D00",invoke=function() writeEffectToPattern("0D00", "0G01") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Fill Effect Column with 0G01+0U00",invoke=function() writeEffectToPattern("0U00", "0G01") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Devices:Move DSPs to Previous Track",invoke=function() move_dsps_to_adjacent_track(-1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Move DSPs to Next Track",invoke=function() move_dsps_to_adjacent_track(1) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Devices:Move Selected DSP to Previous Track",invoke=function() move_selected_dsp_to_adjacent_track(-1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Move Selected DSP to Next Track",invoke=function() move_selected_dsp_to_adjacent_track(1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Create Group and Move DSPs",invoke=create_group_and_move_dsps}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Apply Note Column Sample Effects M00/MFF",invoke=function() applyNoteColumnEffects() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Clear Note Column Sample Effects M00/MFF",invoke=function() clearNoteColumnEffects() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Toggle Template Mode",invoke = toggle_template_mode}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Value Interpolation Looper Dialog...",invoke = pakettiVolumeInterpolationLooper}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:CapsLockChassis:Default Pattern (2,3,5,8)", invoke=function() PakettiCapsLockPatternDefault() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:CapsLockChassis:Tight Pattern (1,2,3,4)", invoke=function() PakettiCapsLockPatternTight() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:CapsLockChassis:Wide Pattern (4,8,12,16)", invoke=function() PakettiCapsLockPatternWide() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:CapsLockChassis:Custom Pattern (EditStep Based)", invoke=function() PakettiCapsLockPatternCustom() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Note-Off Paste (from Selection)", invoke=function() noteOffPaste() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Duplicate Pattern Above & Clear Muted",invoke=duplicate_pattern_and_clear_muted_above}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Duplicate Pattern Below & Clear Muted",invoke=duplicate_pattern_and_clear_muted}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Convert 3 Note Chord to Arpeggio", invoke=function() ConvertChordsToArpeggio() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Effect Columns:B01 Reverse Sample Effect On/Off",invoke=function()
  local s=renoise.song()
  local nci=s.selected_note_column_index 
  s.selected_effect_column_index=1
  revnoter() 
  if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then 
    return
  else 
  s.selected_note_column_index=nci
  --s.selected_note_column_index=1 
  end end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:B00 Reverse Sample Effect On/Off",invoke=function() effectColumnB00()end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:L00/LC0 Volume Effect Switch",invoke=function() 
    renoise.song().selected_effect_column_index=1
    write_effect("0L") 
    
      if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then return
    else renoise.song().selected_note_column_index=1 end end} 
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:0R(LPB) Retrig On/Off",invoke=function() 
      renoise.song().selected_effect_column_index=1
      writeretrig() 
        if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then return
      else renoise.song().selected_note_column_index=1 end end} 
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Duplicate Effect Column Content to Pattern or Selection",invoke=pakettiDuplicateEffectColumnToPatternOrSelection}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Randomize Effect Column Parameters",invoke=pakettiRandomizeEffectColumnParameters}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Effect Columns:Interpolate Column Values (Effect)",invoke=pakettiInterpolateEffectColumnParameters}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Flood Fill Note and Instrument",invoke=pakettiFloodFill}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Flood Fill Note and Instrument with EditStep",invoke=pakettiFloodFillWithEditStep}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Devices:Enable 8 Track DSP Devices (Write to Pattern)",invoke=function() effectenablepattern()  end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Devices:Bypass 8 Track DSP Devices (Write to Pattern)",invoke=function() effectbypasspattern() end}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Start Sampling and Sample Editor (Record)",invoke=function() PakettiSampleAndToSampleEditor() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Record:Paketti Overdub 12 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,12) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Paketti Overdub 12 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,12) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,12) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Record:Paketti Overdub 01 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Paketti Overdub 01 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Record:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Duplicate Track Duplicate Instrument",invoke=function() duplicateTrackDuplicateInstrument() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Note Columns:Interpolate Notes",invoke=function() note_interpolation() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Visible Column (Volume) Globally",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Visible Column (Panning) Globally",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Visible Column (Delay) Globally",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Toggle Visible Column (Sample Effects) Globally",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Global Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Global Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Global Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Global Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Fuzzy Search Track...",invoke = pakettiFuzzySearchTrackDialog}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Switch Note Instrument Dialog...",invoke=pakettiSwitchNoteInstrumentDialog}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row -03",invoke=function() PakettiTransposer(-3, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row +04",invoke=function() PakettiTransposer(4, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row -04",invoke=function() PakettiTransposer(-4, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row +07",invoke=function() PakettiTransposer(7, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row -07",invoke=function() PakettiTransposer(-7, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row +11",invoke=function() PakettiTransposer(11, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Row -11",invoke=function() PakettiTransposer(-11, false) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row +03",invoke=function() PakettiTransposer(3, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row -03",invoke=function() PakettiTransposer(-3, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row +04",invoke=function() PakettiTransposer(4, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row -04",invoke=function() PakettiTransposer(-4, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row +07",invoke=function() PakettiTransposer(7, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row -07",invoke=function() PakettiTransposer(-7, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row +11",invoke=function() PakettiTransposer(11, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Transposer Selection/Row -11",invoke=function() PakettiTransposer(-11, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Basic Triads - Major (3-4)",invoke=function() chordsplus(4,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Basic Triads - Minor (4-3)",invoke=function() chordsplus(3,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Basic Triads - Augmented (4-4)",invoke=function() chordsplus(4,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Basic Triads - Sus2 (2-5)",invoke=function() chordsplus(2,5) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Basic Triads - Sus4 (5-2)",invoke=function() chordsplus(5,2) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Seventh - Major 7 (4-3-4)",invoke=function() chordsplus(4,3,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Seventh - Minor 7 (3-4-3)",invoke=function() chordsplus(3,4,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Seventh - Dominant 7 (4-3-3)",invoke=function() chordsplus(4,3,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Seventh - Minor-Major 7 (3-4-4)",invoke=function() chordsplus(3,4,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Ninth - Major 9 (4-3-4-3)",invoke=function() chordsplus(4,3,4,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Ninth - Minor 9 (3-4-3-3)",invoke=function() chordsplus(3,4,3,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Ninth - Major 9 Simple (4-7-3)",invoke=function() chordsplus(4,7,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Ninth - Minor 9 Simple (3-7-4)",invoke=function() chordsplus(3,7,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Added - Major Add 9 (4-3-7)",invoke=function() chordsplus(4,3,7) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Added - Minor Add 9 (3-4-7)",invoke=function() chordsplus(3,4,7) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Added - Major 6 Add 9 (4-3-2-5)",invoke=function() chordsplus(4,3,2,5) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Added - Minor 6 Add 9 (3-4-2-5)",invoke=function() chordsplus(3,4,2,5) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Added - Major 9 Add 11 (4-3-4-3-3)",invoke=function() chordsplus(4,3,4,3,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Augmented - Aug6 (4-4-2)",invoke=function() chordsplus(4,4,2) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Augmented - Aug7 (4-4-3)",invoke=function() chordsplus(4,4,3) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Augmented - Aug8 (4-4-4)",invoke=function() chordsplus(4,4,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Augmented - Aug9 (4-3-3-5)",invoke=function() chordsplus(4,3,3,5) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Augmented - Aug10 (4-4-7)",invoke=function() chordsplus(4,4,7) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Augmented - Aug11 (4-3-3-4-4)",invoke=function() chordsplus(4,3,3,4,4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Special - Octaves (12-12-12)",invoke=function() chordsplus(12,12,12) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Special - Next Chord",invoke=next_chord }
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Special - Previous Chord",invoke=previous_chord }
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Note Columns:Note Sorter (Ascending)",invoke=NoteSorterAscending}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Note Sorter (Descending)",invoke=NoteSorterDescending}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Randomize Voicing for Notes in Row/Selection",invoke=function() RandomizeVoicing() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Shift Notes Right",invoke=function() ShiftNotes(1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Columns:Shift Notes Left",invoke=function() ShiftNotes(-1) end}  
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Cycle Chord Inversion Up",invoke=function() cycle_inversion("up")
NoteSorterAscending() end}  
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Cycle Chord Inversion Down",invoke=function() cycle_inversion("down")
NoteSorterAscending() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Random - Apply Random Chord",invoke=function() RandomChord() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus:Extract Bassline to New Track",invoke=function() ExtractBassline() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Extract Highest Note to New Track",invoke=function() ExtractHighestNote() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Duplicate Highest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "duplicate") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Duplicate Highest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "selected") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Duplicate Highest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "original") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Duplicate Lowest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "duplicate") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Duplicate Lowest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "selected") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus:Duplicate Lowest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "original") end}


for i=1,12 do
  renoise.tool():add_menu_entry{name=string.format("Pattern Editor:Paketti ChordsPlus:Add Intervals:Add %d", i),invoke=function() JalexAdd(i) end}
  renoise.tool():add_menu_entry{name=string.format("Pattern Editor:Paketti ChordsPlus:Sub Intervals:Sub %d", i),invoke=function() JalexAdd(-i) end}
end


  debugPrint("Pattern Editor Menus Are Enabled")
  

end

--- Main Menu Tools Config
if preferences.pakettiMenuConfig.MainMenuTools then
debugPrint("Main Menu Tools Menus Are Enabled")
--- Gadgets
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Fuzzy Search Track...",invoke = pakettiFuzzySearchTrackDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Show Paketti Formula Dialog...",invoke = pakettiFormulaDeviceDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Stacker...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Beat Structure Editor...",invoke=pakettiBeatStructureEditorDialog}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Keyzone Distributor Dialog...",invoke=function() pakettiKeyzoneDistributorDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Timestretch Dialog...",invoke=pakettiTimestretchDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Groovebox 8120...",invoke=function() GrooveboxShowClose() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Volume/Delay/Pan Slider Controls...",invoke=function() pakettiVolDelayPanSliderDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Show/Hide User Preference Devices Master Dialog (SlotShow)...",invoke=function() pakettiUserPreferencesShowerDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Quick Load Device Dialog...", invoke=pakettiQuickLoadDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Sequencer Settings Dialog...",invoke = pakettiSequencerSettingsDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Dialog of Dialogs...",invoke=function() pakettiDialogOfDialogsToggle() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Track Dater & Titler...",invoke=function() pakettiTitlerDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Theme Selector...",invoke=pakettiThemeSelectorDialogShow }
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Gater...",invoke=function()
          local max_rows = renoise.song().selected_pattern.number_of_lines
          if renoise.song() then
            pakettiGaterDialog()
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR end end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti MIDI Populator...",invoke=function() pakettiMIDIPopulator() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Track Routings...",invoke=function() pakettiTrackOutputRoutingsDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Oblique Strategies...",invoke=function() pakettiObliqueStrategiesDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Track Renamer...",invoke=function() pakettiTrackRenamerDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti eSpeak Text-to-Speech...",invoke=function()pakettieSpeakDialog()end}
    
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Convert REX/RX2/ITI to PTI",invoke=universal_to_pti_convert}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export .PTI Instrument",invoke=pti_savesample}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:File Formats:Export Subfolders as Melodic Slices",invoke=PakettiExportSubfoldersAsMelodicSlices}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export Subfolders as Drum Slices",invoke=PakettiExportSubfoldersAsDrumSlices}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Polyend:Export Subfolders as Melodic Slices",invoke=PakettiExportSubfoldersAsMelodicSlices}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend:Export Subfolders as Drum Slices",invoke=PakettiExportSubfoldersAsDrumSlices}


renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:File Formats:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}

      
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Generate OctaCycle...",invoke=function() PakettiOctaCycle() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Quick OctaCycle (C, Oct 1-7)",invoke=function() PakettiOctaCycleQuick() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Export OctaCycle to Octatrack",invoke=function() PakettiOctaCycleExport() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Export (.WAV+.ot)",invoke=function() PakettiOTExport() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Export (.ot only)",invoke=function() PakettiOTExportOtOnly() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Import (.ot)",invoke=function() PakettiOTImport() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Debug (.ot)",invoke=function() PakettiOTDebugDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Generate Drumkit (Smart Mono/Stereo)",invoke=function() PakettiOTDrumkitSmart() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Generate Drumkit (Force Mono)",invoke=function() PakettiOTDrumkitMono() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:File Formats:Octatrack:Set Loop to Slice",invoke=function() PakettiOTSetLoopToSlice() end}


renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Convert IFF to WAV...",invoke=convertIFFToWAV}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Convert WAV to IFF...",invoke=convertWAVToIFF}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Save Current Sample as IFF...",invoke=saveCurrentSampleAsIFF}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import .RX2",invoke=function() 
  local filename = renoise.app():prompt_for_filename_to_read({"*.RX2","*.rx2"}, "ReCycle .RX2 Import tool")
  if filename then rx2_loadsample(filename) end end}

  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Dump REX Structure to Text",
  invoke=function()
    local file_path = renoise.app():prompt_for_filename_to_read({ "*.rex","*.REX" }, "ReCycle Legacy .REX Import Structure Dumper")
    if file_path then
      dump_rex_structure(file_path)
    end
  end
  
}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import .REX",invoke=function() 
  local filename = renoise.app():prompt_for_filename_to_read({"*.REX"}, "ReCycle .REX Import tool")
  if filename then rex_loadsample(filename) end end}



renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import .SF2 (Single XRNI per Preset)",
  invoke=function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import")
    if f and f ~= "" then import_sf2(f) end
  end
}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import .SF2 (Multitimbral)",
  invoke=function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import (multitimbral)")
    if f and f ~= "" then import_sf2_multitimbral(f) end
  end
}



renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Paketti Steppers Dialog...", invoke=function() PakettiSteppersDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Reset All Steppers",invoke = ResetAllSteppers}



-- Xperimental/WIP
renoise.tool():add_menu_entry{name='Main Menu:Tools:Paketti:Xperimental/WIP:BeatDetector Modified...',invoke=function() pakettiBeatDetectorDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Paketti XRNS Probe",invoke = pakettiXRNSProbeShowDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Expand to Triplets (Note every row, note every 2nd row)",invoke=function() pcall(detect_and_apply_triplet_pattern)end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Align Instrument Names",invoke=function() align_instrument_names() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Paketti YT-DLP Downloader...",invoke=function() pakettiYTDLPDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:EQ10 XY Control...",invoke = pakettiEQ10XYDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:XY Pad Sound Mixer",invoke=function() showXyPaddialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:SBx Loop Playback",invoke=showSBX_dialog}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Xperimental/WIP:Match Effect Column EditStep with Note Placement",invoke=function() toggle_match_editstep_effect() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Match Note Column EditStep with Note Placement",invoke=function() toggle_match_editstep_note() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Match EditStep with Delay Pattern",invoke=function() toggle_match_editstep() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Xperimental/WIP:Paketti Tuplet Writer Dialog...",invoke=function() pakettiTupletDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Xperimental/WIP:PitchStepper Demo",invoke=function() pakettiPitchStepperDemo() end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Audio Processing Tools...",invoke=function() pakettiAudioProcessingToolsDialog() end}
local os_name = os.getenv("OS") or os.getenv("OSTYPE") or (io.popen("uname -s"):read("*l"))
if os_name == "MACINTOSH" or os_name == "Darwin" then
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Xperimental/WIP:Amigo:Import Embedded Amigo (AU) WAV into Sample",invoke=function() pakettiAmigoLoadIntoSample() end }
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Amigo:Open Amigo (AU) Sample Path",invoke=function() pakettiAmigoOpenSamplePath() end }

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Xperimental/WIP:Amigo:Decode Active Plugin ParameterChunk Amigo (AU)",invoke=function() pakettiAmigoDecodeActiveParameterChunk() end }
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Amigo:Import Active Plugin Wavefile Amigo (AU)",invoke=function() pakettiAmigoImportWavefile() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Amigo:Set Active Plugin Pathname Amigo (AU)",invoke=function() pakettiAmigoSetActivePathname() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Amigo:Export Selected Sample to Amigo (AU)",invoke=function() pakettiAmigoExportSampleToAmigo() end}
end

-- Main Menu Options
renoise.tool():add_menu_entry{name="--Main Menu:Options:Toggle Automatically Open Selected Track Device Editors On/Off",invoke = PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode}


-- Tools Preferences
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Paketti Preferences...",invoke=pakettiPreferences}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!Preferences:Paketti Dynamic View Preferences Dialog 1-4...", invoke=function() pakettiDynamicViewDialog(1, 4) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Paketti Dynamic View Preferences Dialog 5-8...", invoke=function() pakettiDynamicViewDialog(5, 8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Paketti Save Dynamic Views as a Textfile", invoke=function() save_dynamic_views_to_txt() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Paketti Load Dynamic Views from a Textfile", invoke=function() load_dynamic_views_from_txt() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!Preferences:Paketti MIDI Mappings...",invoke=function() pakettiMIDIMappingsDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!Preferences:Toggle Automatically Open Selected Track Device Editors On/Off",invoke = PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode}
  
-- Tools Plugins/Devices
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:SlotShow:Show/Hide User Preference Devices Master Dialog (SlotShow)...",invoke=function() pakettiUserPreferencesShowerDialog() end}


renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:Show Effect Details Dialog...",invoke=function() pakettiDebugDeviceInfoDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Expose/Hide Selected Track ALL Device Parameters",invoke=function() exposeHideParametersInMixer() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Hide Track DSP Device External Editors for All Tracks",invoke=function() hide_all_external_editors() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Bypass All Devices on Track",invoke=function() effectbypass() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Enable All Devices on Track",invoke=function() effectenable() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Randomize Selected Instrument Plugin Parameters",invoke=function()randomizeSelectedPlugin()end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Randomize Selected Device Parameters",invoke=function()randomize_selected_device()end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Show XO Plugin External Editor",invoke=function() XOPointCloud() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Insert Random Device (All)", invoke=function() insertRandomDevice(false) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Insert Random Device (AU/Native Only)", invoke=function() insertRandomDevice(true) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Insert Random Plugin (All)", invoke=function() insertRandomPlugin(false) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Insert Random Plugin (AU Only)", invoke=function() insertRandomPlugin(true) end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Show Paketti Sub Column Status",invoke = show_sub_column_status}


renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Merge Instruments Dialog...",invoke=function() pakettiMergeInstrumentsDialog() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Samples:Paketti Offset Dialog...",invoke=pakettiOffsetDialog }
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Replace FC with 0L",invoke=function() ReplaceLegacyEffect("FC", "0L") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Delete Unused Columns", invoke = deleteUnusedColumns}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Toggle Global Groove on Startup On/Off",invoke=pakettiToggleGlobalGrooveOnStartup}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Toggle BPM Randomization on New Songs On/Off",invoke=pakettiToggleRandomizeBPMOnNewSong}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Transport:BPM&LPB:Randomize BPM Now (60-220, Bell Curve)",invoke=pakettiRandomizeBPMNow}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize BPM Now (60-220, Bell Curve)",invoke=pakettiRandomizeBPMNow}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Paketti Speed and Tempo to BPM Dialog...",invoke=pakettiSpeedTempoDialog}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Hide All Unused Columns (All Tracks)", invoke=function() PakettiHideAllUnusedColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Hide All Unused Columns (Selected Track)", invoke=function() PakettiHideAllUnusedColumnsSelectedTrack() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Double LPB",invoke=function() PakettiLPBDouble() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Halve LPB",invoke=function() PakettiLPBHalve() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Double Double LPB",invoke=function() PakettiLPBDouble() PakettiLPBDouble() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Halve Halve LPB",invoke=function() PakettiLPBHalve() PakettiLPBHalve() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Reverse Notes in Selection",invoke=function() PakettiReverseNotesInSelection() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Populate Send Tracks for All Tracks",invoke=PakettiPopulateSendTracksAllTracks}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Populate Send Tracks for Selected Track",invoke=PakettiPopulateSendTracksSelectedTrack}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Track Properties:Decrease All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(-3) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Track Properties:Increase All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(3) end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Resize&Fill:Paketti Pattern Resize and Fill 032",invoke=function() pakettiResizeAndFill(32) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Resize&Fill:Paketti Pattern Resize and Fill 064",invoke=function() pakettiResizeAndFill(64) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Resize&Fill:Paketti Pattern Resize and Fill 128",invoke=function() pakettiResizeAndFill(128) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Resize&Fill:Paketti Pattern Resize and Fill 256",invoke=function() pakettiResizeAndFill(256) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Resize&Fill:Paketti Pattern Resize and Fill 512",invoke=function() pakettiResizeAndFill(512) end}



renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Automation:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (Amount Only)",invoke=function() toggle_fx_amount_following() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (0Yxx)",invoke=function() toggle_fx_amount_following("0Y") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (0Sxx)",invoke=function() toggle_fx_amount_following("0S") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (0Dxx)",invoke=function() toggle_fx_amount_following("0D") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (0Uxx)",invoke=function() toggle_fx_amount_following("0U") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (0Gxx)",invoke=function() toggle_fx_amount_following("0G") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Effect Column 1 (0Rxx)",invoke=function() toggle_fx_amount_following("0R") end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:LFO Write:LFO Write to Phrase LPB (1-255)",invoke=function() toggle_lpb_following(255) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Phrase LPB (1-127)",invoke=function() toggle_lpb_following(127) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:LFO Write to Phrase LPB (1-64)",invoke=function() toggle_lpb_following(64) end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:LFO Write:Single Parameter Write to Automation",invoke = toggle_single_parameter_following}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Automation:Snapshot All Devices on Selected Track to Automation",invoke = snapshot_all_devices_to_automation}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Automation:Snapshot Selected Device to Automation",invoke = snapshot_selected_device_to_automation}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Automation:Convert FX to Automation",invoke = function() read_fx_to_automation(false) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Automation:Convert FX to Automation (Move)",invoke = function() read_fx_to_automation(true) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Automation:Convert Automation to FX",invoke = function() write_automation_to_fx(false) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Automation:Convert Automation to FX (Move)",invoke = function() write_automation_to_fx(true) end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Auto Assign Outputs",invoke=AutoAssignOutputs}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Open Visible Pages to Fit Plugin Parameter Count",invoke=openVisiblePagesToFitParameters}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Add Input Inertia Formula Device",invoke = add_input_inertia}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Cycle Overlap Mode",invoke=overlayModeCycle}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120)  end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Clean Render:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Clean Render:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Clean Render:Clean Render and Save Selected Track/Group as .WAV",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Clean Render:Clean Render and Save Selected Track/Group as .FLAC",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Clean Render:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Quick Sample Folders:Paketti User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Set Overlap Mode 0 (Play All)",invoke=function() setOverlapMode(0) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Set Overlap Mode 1 (Cycle)",invoke=function() setOverlapMode(1) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Set Overlap Mode 2 (Random)",invoke=function() setOverlapMode(2) end}


renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Debug:Generate Paketti Midi Mappings to Console",
  invoke=function() generate_paketti_midi_mappings() end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Renoise KeyBindings Dialog...",invoke=function() pakettiRenoiseKeyBindingsDialog() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!Preferences:Find Free KeyBindings...",invoke=pakettiFreeKeybindingsDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Debug:Print Free KeyBindings to Terminal",invoke=print_free_combinations}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Explode Notes to New Tracks",invoke=function() explode_notes_to_tracks() end}




renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Paketti Effect Column CheatSheet...",invoke=function() pakettiPatternEditorCheatsheetDialog() end}

-------- Plugins/Devices
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!!About:About Paketti/Donations...",invoke=function() pakettiAboutDonations() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!Preferences:Open Paketti Path",invoke=function() renoise.app():open_path(renoise.tool().bundle_path)end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Load Plugins...",invoke=function() pakettiLoadPluginsDialog() end}renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Switch Note Instrument Dialog...",invoke=pakettiSwitchNoteInstrumentDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Load Devices...",invoke=function() pakettiLoadDevicesDialog() end}


renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:Inspect Plugin (Console)",invoke=function() inspectPlugin() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:Inspect Selected Device (Console)",invoke=function() inspectEffect() end}



renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:List Available VST Plugins (Console)",invoke=function() listByPluginType("VST") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:List Available AU Plugins (Console)",invoke=function() listByPluginType("AU") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:List Available VST3 Plugins (Console)",invoke=function() listByPluginType("VST3") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:List Available VST Effects (Console)",invoke=function() listDevicesByType("VST") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:List Available AU Effects (Console)",invoke=function() listDevicesByType("AU") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:List Available VST3 Effects (Console)",invoke=function() listDevicesByType("VST3") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:Dump VST/VST3/AU/Native Effects (Console)",invoke=function() 
local devices=renoise.song().tracks[renoise.song().selected_track_index].available_devices
  for key, value in ipairs (devices) do 
    print(key, value)
  end
end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:Available Routings for Track...",invoke=function() showAvailableRoutings() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Debug:∿ Squiggly Sinewave to Clipboard...",invoke=function() squigglerdialog() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Clone Current Sequence",invoke=clone_current_sequence}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Set All Instruments All Samples Autoseek On",invoke=function() setAllInstrumentsAllSamplesAutoseek(1) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Set All Instruments All Samples Autoseek Off",invoke=function() setAllInstrumentsAllSamplesAutoseek(0) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Set All Instruments All Samples Autofade On",invoke=function() setAllInstrumentsAllSamplesAutofade(1) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Set All Instruments All Samples Autofade Off",invoke=function() setAllInstrumentsAllSamplesAutofade(0) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Beatsync Lines Halve (All)",invoke=function() halveBeatSyncLinesAll() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Beatsync Lines Halve (Selected Sample)",invoke=function() halveBeatSyncLinesSelected() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Beatsync Lines Double (All)",invoke=function() doubleBeatSyncLinesAll() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Beatsync Lines Double (Selected Sample)",invoke=function() doubleBeatSyncLinesSelected() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Initialize:12st PitchBend Instrument Init",invoke=function() pitchedInstrument(12) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Initialize:PitchBend Drumkit Instrument Init",invoke=function() pitchedDrumkit() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Jump to First Track In Next Group",invoke=function() select_first_track_in_next_group(1) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Jump to First Track In Previous Group",invoke=function() select_first_track_in_next_group(0) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Toggle Visible Column (Volume) Globally",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Toggle Visible Column (Panning) Globally",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Toggle Visible Column (Delay) Globally",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Toggle Visible Column (Sample Effects) Globally",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Global Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Global Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Global Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Global Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Show Convolver Selection Dialog...",invoke=function()
  pakettiConvolverSelectionDialog(handle_convolver_action)
end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Import Selected Sample to Selected Convolver",invoke=function()
  print("Importing selected sample to Convolver via menu entry")
  local selected_device = renoise.song().selected_device
  local selected_track_index = renoise.song().selected_track_index
  local selected_device_index = renoise.song().selected_device_index
  if not selected_device or selected_device.name ~= "Convolver" then
    pakettiConvolverSelectionDialog(handle_convolver_action)
    return
  end
  save_instrument_to_convolver(selected_device, selected_track_index, selected_device_index)
end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Plugins/Devices:Export Convolver IR into New Instrument",invoke=function()
  print("Exporting Convolver IR into New Instrument via menu entry")
  local selected_device = renoise.song().selected_device
  local selected_track_index = renoise.song().selected_track_index
  local selected_device_index = renoise.song().selected_device_index
  if not selected_device or selected_device.name ~= "Convolver" then
    pakettiConvolverSelectionDialog(handle_convolver_action)
    return
  end
  create_instrument_from_convolver(selected_device, selected_track_index, selected_device_index)
end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Global Volume Reduce All Samples by -4.5dB",invoke=function() reduceSamplesVolume(4.5) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Paketti Global Volume Adjustment...",invoke=function() pakettiGlobalVolumeDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Delete Unused Instruments...",invoke=deleteUnusedInstruments}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Delete Unused Samples...",invoke=deleteUnusedSamples}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Duplicate Pattern Above & Clear Muted",invoke=duplicate_pattern_and_clear_muted_above}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Duplicate Pattern Below & Clear Muted",invoke=duplicate_pattern_and_clear_muted}


renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Pattern/Phrase Length Dialog...",invoke=function() pakettiLengthDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Pattern Length Increase by 8",invoke=function() adjust_length_by(8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Pattern Length Decrease by 8",invoke=function() adjust_length_by(-8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Pattern Length Increase by LPB",invoke=function() adjust_length_by("lpb") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Pattern Length Decrease by LPB",invoke=function() adjust_length_by("-lpb") end}
-- Phrase Editor entries require API 6.2+
if (renoise.API_VERSION >= 6.2) then
  renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Phrases:Phrase Length Increase by 8",invoke=function() adjust_length_by(8) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Phrase Length Decrease by 8",invoke=function() adjust_length_by(-8) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Phrase Length Increase by LPB",invoke=function() adjust_length_by("lpb") end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Phrase Length Decrease by LPB",invoke=function() adjust_length_by("-lpb") end}
end
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Collapse All Tracks",invoke=function() Collapser() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Uncollapse All Tracks",invoke=function() Uncollapser() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Paketti Pattern Doubler",invoke=pakettiPatternDoubler}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Paketti Pattern Halver",invoke=pakettiPatternHalver}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Renoise Random BPM & Write BPM/LPB to Master",invoke=function() randomBPMMaster() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Write Current BPM&LPB to Master Column",invoke=function() write_bpm() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:BPM&LPB:Random BPM (60-180)",invoke=function() randomBPM() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Randomize Effect Column Parameters",invoke=pakettiRandomizeEffectColumnParameters}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Interpolate Column Values (Effect)",invoke=pakettiInterpolateEffectColumnParameters}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Flood Fill Note and Instrument",invoke=pakettiFloodFill}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Flood Fill Note and Instrument with EditStep",invoke=pakettiFloodFillWithEditStep}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Automation:Randomize Automation Envelope",invoke=randomize_envelope}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Automation:Paketti Automation Value...",invoke=function() pakettiAutomationValue() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Automation:Flood Fill Automation Selection",invoke=PakettiAutomationSelectionFloodFill}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Paketti Track DSP Device & Instrument Loader...",invoke=function() pakettiDeviceChainDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Switch Plugin AutoSuspend Off",invoke=function() autosuspendOFF() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:Show Plugin Details Dialog...",invoke=function() pakettiDebugPluginInfoDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Expose/Hide Selected Device Parameters in Mixer",invoke=function() exposeHideParametersInMixer() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Randomize Devices and Plugins Dialog...",invoke=function() pakettiRandomizerDialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Plugins/Devices:Debug:Dump VST/VST3/AU/LADSPA/DSSI/Native Effects to Dialog...",invoke=function() show_available_plugins_dialog() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Duplicate Effect Column Content to Pattern or Selection",invoke=pakettiDuplicateEffectColumnToPatternOrSelection}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Value Interpolation Looper Dialog...",invoke = pakettiVolumeInterpolationLooper}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Catch Octave",invoke = toggle_catch_octave}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Pattern Editor:Create Identical Track",invoke=create_identical_track}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Global Volume Reduce All Instruments by -4.5dB",invoke=function() reduceInstrumentsVolume(4.5) end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Instruments:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}



end

--- Main Menu View Config
if preferences.pakettiMenuConfig.MainMenuView then

renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti:Visible Columns:Hide All Unused Columns (All Tracks)", invoke=function() PakettiHideAllUnusedColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Hide All Unused Columns (Selected Track)", invoke=function() PakettiHideAllUnusedColumnsSelectedTrack() end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti:Visible Columns:Uncollapse All Tracks",invoke=function() Uncollapser() end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Collapse All Tracks",invoke=function() Collapser() end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti:Visible Columns:Hide All Effect Columns",invoke=function() HideAllEffectColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Hide All Effect Columns",invoke=function() HideAllEffectColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Toggle All Columns",invoke=function() toggleColumns(true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Toggle All Columns (No Sample Effects)",invoke=function() toggleColumns(false) end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti:Visible Columns:Toggle Visible Column (Volume) Globally",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Toggle Visible Column (Panning) Globally",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Toggle Visible Column (Delay) Globally",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Toggle Visible Column (Sample Effects) Globally",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti:Visible Columns:Global Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Set Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Set Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Set Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Set Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti:Visible Columns:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Visible Columns:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}


  debugPrint("Main Menu View Menus Are Enabled")
end

--- Main Menu File Config
if preferences.pakettiMenuConfig.MainMenuFile then
  debugPrint("Main Menu File Menus Are Enabled")
  local file_menu_mode = (preferences.pakettiFileMenuLocationMode and preferences.pakettiFileMenuLocationMode.value) or 3
  if file_menu_mode == 1 or file_menu_mode == 3 then
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
    renoise.tool():add_menu_entry{name="Main Menu:File:Load Most Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
    renoise.tool():add_menu_entry{name="Main Menu:File:Save (Paketti Track Dater & Titler)...",invoke=pakettiTitlerDialog}
    renoise.tool():add_menu_entry{name="Main Menu:File:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}
    renoise.tool():add_menu_entry{name="Main Menu:File:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Delete Unused Instruments...",invoke=deleteUnusedInstruments}
    renoise.tool():add_menu_entry{name="Main Menu:File:Delete Unused Samples...",invoke=deleteUnusedSamples}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
    if type(PakettiClearUnusedPatterns) == "function" then
      renoise.tool():add_menu_entry{name="Main Menu:File:Clear Unused Patterns",invoke=PakettiClearUnusedPatterns}
    end
  end

  -- File -> Paketti
  if file_menu_mode == 2 or file_menu_mode == 3 then
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Load Most Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Paketti Track Dater & Titler...",invoke=pakettiTitlerDialog}
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Delete Unused Instruments...",invoke=deleteUnusedInstruments}
    renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Delete Unused Samples...",invoke=deleteUnusedSamples}
    renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
    if type(PakettiClearUnusedPatterns) == "function" then
      renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Clear Unused Patterns",invoke=PakettiClearUnusedPatterns}
    end
  end

end

--- Pattern Matrix Config
if preferences.pakettiMenuConfig.PatternMatrix then
-- Gadgets
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Gadgets:Paketti Beat Structure Editor...",invoke=pakettiBeatStructureEditorDialog}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Gadgets:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Gadgets:Value Interpolation Looper Dialog...",invoke = pakettiVolumeInterpolationLooper}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Gadgets:Paketti Sequencer Settings Dialog...",invoke = pakettiSequencerSettingsDialog}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Gadgets:Fuzzy Search Track Dialog...",invoke = pakettiFuzzySearchTrackDialog}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Gadgets:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}


renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Automation:Convert FX to Automation",invoke = function() read_fx_to_automation(false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Convert FX to Automation (Move)",invoke = function() read_fx_to_automation(true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Convert Automation to FX",invoke = function() write_automation_to_fx(false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Convert Automation to FX (Move)",invoke = function() write_automation_to_fx(true) end}

-- Pattern Matrix Devices
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Devices:Insert Stereo -> Mono device to End of ALL DSP Chains",invoke=function() insertMonoToAllTracksEnd() end}

-- Pattern Matrix Automation
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Snapshot All Devices on Selected Track to Automation",invoke = snapshot_all_devices_to_automation}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Automation:Center to Top (Exp) for Pattern Matrix Selection",invoke=automation_center_to_top_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Top to Center (Exp) for Pattern Matrix Selection",invoke=automation_top_to_center_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Center to Bottom (Exp) for Pattern Matrix Selection",invoke=automation_center_to_bottom_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Bottom to Center (Exp) for Pattern Matrix Selection",invoke=automation_bottom_to_center_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Center to Top (Lin) for Pattern Matrix Selection",invoke=automation_center_to_top_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Top to Center (Lin) for Pattern Matrix Selection",invoke=automation_top_to_center_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Center to Bottom (Lin) for Pattern Matrix Selection",invoke=automation_center_to_bottom_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Bottom to Center (Lin) for Pattern Matrix Selection",invoke=automation_bottom_to_center_lin }
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Automation:Automation Ramp Up (Exp) for Pattern Matrix Selection",invoke=automation_ramp_up_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Automation Ramp Down (Exp) for Pattern Matrix Selection",invoke=automation_ramp_down_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Automation Ramp Up (Lin) for Pattern Matrix Selection",invoke=automation_ramp_up_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Automation Ramp Down (Lin) for Pattern Matrix Selection",invoke=automation_ramp_down_lin }
renoise.tool():add_menu_entry({name="--Pattern Matrix:Paketti:Automation:Top to Top",invoke=function() apply_constant_automation_top_to_top() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Bottom to Bottom (One Pattern)",invoke=function() apply_constant_automation_bottom_to_bottom() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Selection Up (Exp) (One Pattern)",invoke=function() apply_exponential_automation_curveUP() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Selection Up (Linear) (One Pattern)",invoke=function() apply_selection_up_linear() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Selection Down (Exp) (One Pattern)",invoke=function() apply_exponential_automation_curveDOWN() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Selection Down (Linear) (One Pattern)",invoke=function() apply_selection_down_linear() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Center to Top (Exp) (One Pattern)",invoke=function() apply_exponential_automation_curve_center_to_top() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Center to Bottom (Exp) (One Pattern)",invoke=function() apply_exponential_automation_curve_center_to_bottom() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Top to Center (Exp) (One Pattern)",invoke=function() apply_exponential_automation_curve_top_to_center() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti:Automation:Bottom to Center (Exp) (One Pattern)",invoke=function() apply_exponential_automation_curve_bottom_to_center() end})

-- Pattern Matrix Root
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Toggle Automatically Open Selected Track Device Editors On/Off",invoke = PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Selection in Pattern Matrix to Group",invoke=function() SelectionInPatternMatrixToGroup() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Pattern Matrix Selection Expand",invoke=PatternMatrixExpand }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Pattern Matrix Selection Shrink",invoke=PatternMatrixShrink }
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Automation:Wipe All Automation in Track on Current Pattern",invoke=function() delete_automation(false, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Wipe All Automation in All Tracks on Current Pattern",invoke=function() delete_automation(true, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Wipe All Automation in Track on Whole Song",invoke=function() delete_automation(false, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Automation:Wipe All Automation in All Tracks on Whole Song",invoke=function() delete_automation(true, true) end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Multiply BPM & Halve LPB",invoke=function() multiply_bpm_halve_lpb() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Halve BPM & Multiply LPB",invoke=function() halve_bpm_multiply_lpb() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Automation:Switch to Automation",invoke=function() showAutomation() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Devices:Bypass EFX (Write to Pattern)",invoke=function() effectbypasspattern()  end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Devices:Enable EFX (Write to Pattern)",invoke=function() effectenablepattern() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Devices:Bypass All Devices on Channel",invoke=function() effectbypass() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Devices:Enable All Devices on Channel",invoke=function() effectenable() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Transport:Play at 75% Speed (Song BPM)",invoke=function() playat75() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Transport:Play at 100% Speed (Song BPM)",invoke=function() returnbackto100()  end}


renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Clone Sequence (With Automation)",invoke=function() clone_sequence_with_automation_only() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Clone Pattern (Without Automation)",invoke=function() clone_pattern_without_automation() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Clone and Expand Pattern to LPB*2",invoke=function() cloneAndExpandPatternToLPBDouble()end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Clone and Shrink Pattern to LPB/2",invoke=function() cloneAndShrinkPatternToLPBHalve()end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Duplicate Pattern Above & Clear Muted",invoke=function() duplicate_pattern_and_clear_muted_above() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Duplicate Pattern Below & Clear Muted",invoke=function() duplicate_pattern_and_clear_muted() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Duplicate Track and Instrument",invoke=function() duplicateTrackAndInstrument() end}

-- Pattern Matrix Delay Output Delay
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Reset Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Reset Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Nudge Delay Output Delay -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Reset Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delay Output:Reset Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

-- Pattern Matrix Record
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 12 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,12) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 12 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,12) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,12) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Record:Paketti Overdub 01 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,1) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 01 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,1) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,1) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Record:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}


debugPrint("Pattern Matrix Menus Are Enabled")
end

--- Pattern Sequencer Config
if preferences.pakettiMenuConfig.PatternSequencer then
  debugPrint("Pattern Sequencer Menus Are Enabled")
-- gadgets

renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti Gadgets:Paketti Sequencer Settings Dialog...",invoke = pakettiSequencerSettingsDialog}

renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Create Pattern Sequencer Patterns based on Slice Count with Automatic Slice Printing",invoke = createPatternSequencerPatternsBasedOnSliceCount}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Toggle Sequence Selection to Loop",invoke=function() SequenceSelectionToLoop() end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Toggle Sequence Selection (All) On/Off",invoke=function() TKNAToggleSequenceSelectionAll() end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Set Sequence Selection Off",invoke=tknaUnselectSequenceSelection}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Toggle Current Sequence Selection On/Off",invoke=tknaToggleCurrentSequenceSelection}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Set Sequence Loop Selection Off",invoke=set_sequence_selection_off}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Continue Current Sequence From Same Line",invoke=function() tknaContinueCurrentSequenceFromCurrentLine() end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Set Current Sequence as Scheduled List",invoke=function() renoise.song().transport:set_scheduled_sequence(renoise.song().selected_sequence_index) end}  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Add Current Sequence to Scheduled List",invoke=function() renoise.song().transport:add_scheduled_sequence(renoise.song().selected_sequence_index) end}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Sequences/Sections:Set Current Section as Scheduled Sequence",invoke=tknaSetCurrentSectionAsScheduledSequence}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Add Current Section to Scheduled Sequences",invoke=tknaAddCurrentSectionToScheduledSequences}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Sequences/Sections:Section Loop (Next)",invoke=expandSectionLoopNext}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Section Loop (Previous)",invoke=expandSectionLoopPrevious}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Sequences/Sections:Sequence Selection (Next)",invoke=tknaSequenceSelectionPlusOne}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Sequence Selection (Previous)",invoke=tknaSequenceSelectionMinusOne}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Sequences/Sections:Sequence Loop Selection (Next)",invoke=tknaSequenceLoopSelectionNext}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Sequence Loop Selection (Previous)",invoke=tknaSequenceLoopSelectionPrevious}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Set Section Loop and Schedule Section",invoke=tknaAddLoopAndScheduleSection}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Set Current Sequence as Scheduled and Loop",invoke=tknaSetScheduledSequenceToCurrentSequenceAndLoop}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Sequences/Sections:Select Next Section Sequence",invoke=function() navigate_section_sequence("next") end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select Previous Section Sequence",invoke=function() navigate_section_sequence("previous") end}

renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to current Pattern length",invoke = resize_all_non_empty_patterns_to_current_pattern_length}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 012",invoke=function() resize_all_non_empty_patterns_to(012) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 016",invoke=function() resize_all_non_empty_patterns_to(016) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 024",invoke=function() resize_all_non_empty_patterns_to(024) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 032",invoke=function() resize_all_non_empty_patterns_to(032) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 048",invoke=function() resize_all_non_empty_patterns_to(048) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 064",invoke=function() resize_all_non_empty_patterns_to(064) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 096",invoke=function() resize_all_non_empty_patterns_to(96) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 128",invoke=function() resize_all_non_empty_patterns_to(128) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 192",invoke=function() resize_all_non_empty_patterns_to(192) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 256",invoke=function() resize_all_non_empty_patterns_to(256) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 384",invoke=function() resize_all_non_empty_patterns_to(384) end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize all non-empty Patterns:Resize all non-empty Patterns to 512",invoke=function() resize_all_non_empty_patterns_to(512) end}


-- Pattern Sequencer Root
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Duplicate Selected Sequence Range",invoke=duplicate_selected_sequence_range}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Create Section From Selection",invoke=create_section_from_selection}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Keep Sequence Sorted False",invoke=function() renoise.song().sequencer.keep_sequence_sorted=false end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Keep Sequence Sorted True",invoke=function() renoise.song().sequencer.keep_sequence_sorted=true end}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Show/Hide Pattern Matrix",invoke=function() showhidepatternmatrix() end}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Clone and Expand Pattern to LPB*2",invoke=function() cloneAndExpandPatternToLPBDouble()end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Clone and Shrink Pattern to LPB/2",invoke=function() cloneAndShrinkPatternToLPBHalve()end}
renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti:Keep Sequence Sorted Toggle",invoke=function() 
if renoise.song().sequencer.keep_sequence_sorted==false then renoise.song().sequencer.keep_sequence_sorted=true else
renoise.song().sequencer.keep_sequence_sorted=false end end}



end

--- Phrase Editor Config
if preferences.pakettiMenuConfig.PhraseEditor then
  debugPrint("Phrase Editor Menus Are Enabled")
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Load XRNI & Disable Phrases",invoke=function() loadXRNIWipePhrasesTwo() end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Load XRNI & Keep Phrases",invoke=function() loadXRNIKeepPhrases() end}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Load XRNI & Wipe Phrases",invoke=function() loadXRNIWipePhrases() end}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Wipe Phrases on Selected Instrument",invoke=function() wipePhrases() end}
renoise.tool():add_menu_entry{name="--Phrase Mappings:Paketti:Wipe Phrases on Selected Instrument",invoke=function() wipePhrases() end}
renoise.tool():add_menu_entry{name="--Phrase Mappings:Paketti:Load XRNI & Wipe Phrases",invoke=function() loadXRNIWipePhrases() end}

-- Phrase Mappings
renoise.tool():add_menu_entry{name="Phrase Mappings:Paketti:Load XRNI & Disable Phrases",invoke=function() loadXRNIWipePhrasesTwo() end}
renoise.tool():add_menu_entry{name="Phrase Mappings:Paketti:Load XRNI & Keep Phrases",invoke=function() loadXRNIKeepPhrases() end}

-- Phrase Grid
renoise.tool():add_menu_entry{name="Phrase Grid:Paketti:Wipe Phrases on Selected Instrument",invoke=function() wipePhrases() end}
renoise.tool():add_menu_entry{name="--Phrase Grid:Paketti:Load XRNI & Wipe Phrases",invoke=function() loadXRNIWipePhrases() end}
renoise.tool():add_menu_entry{name="Phrase Grid:Paketti:Load XRNI & Disable Phrases",invoke=function() loadXRNIWipePhrasesTwo() end}
renoise.tool():add_menu_entry{name="Phrase Grid:Paketti:Load XRNI & Keep Phrases",invoke=function() loadXRNIKeepPhrases() end}
renoise.tool():add_menu_entry{name="--Phrase Grid:Paketti:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_menu_entry{name="Phrase Grid:Paketti:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_menu_entry{name="Phrase Grid:Paketti:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_menu_entry{name="--Phrase Grid:Paketti:Phrase Follow Pattern Playback Hack",invoke=function() observe_phrase_playhead() end}
end

--- Paketti Gadgets Config
if preferences.pakettiMenuConfig.PakettiGadgets then
  debugPrint("Paketti Gadgets Menus Are Enabled")
end

--- Track DSP Chain Config
if preferences.pakettiMenuConfig.TrackDSPChain then
  debugPrint("Track DSP Chain Menus Are Enabled")
  renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Populate Send Tracks for All Tracks",invoke=PakettiPopulateSendTracksAllTracks}
  renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Populate Send Tracks for Selected Track",invoke=PakettiPopulateSendTracksSelectedTrack}
  renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Insert Random Device (All)", invoke=function() insertRandomDevice(false) end}
  renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Insert Random Device (AU/Native Only)", invoke=function() insertRandomDevice(true) end}
  
end

--- Track DSP Device Config
if preferences.pakettiMenuConfig.TrackDSPDevice then
  debugPrint("Track DSP Device Menus Are Enabled")
renoise.tool():add_menu_entry{name="DSP Device Automation:Follow Off",invoke=function() renoise.song().transport.follow_player=false end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Open Visible Pages to Fit Plugin Parameter Count",invoke=openVisiblePagesToFitParameters}

renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Inspect Selected Device",invoke=function() inspectEffect() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Inspect Selected Sample Device", invoke = inspectSampleDevice}


renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Automation:Snapshot All Devices on Selected Track to Automation",invoke = snapshot_all_devices_to_automation}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Automation:Snapshot Selected Device to Automation",invoke = snapshot_selected_device_to_automation}

renoise.tool():add_menu_entry{name="DSP Device:Paketti:Show/Hide User Preference Devices Master Dialog (SlotShow)...",invoke=function() pakettiUserPreferencesShowerDialog() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Populate Send Tracks for All Tracks",invoke=PakettiPopulateSendTracksAllTracks}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Populate Send Tracks for Selected Track",invoke=PakettiPopulateSendTracksSelectedTrack}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti Gadgets:Quick Load Device Dialog...", invoke=pakettiQuickLoadDialog}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Automation:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Device Chains:Open Track DSP Device & Instrument Loader...",invoke=function() pakettiDeviceChainDialog() end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Clear/Wipe Selected Track TrackDSPs",invoke=function() wipeSelectedTrackTrackDSPs() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Insert Random Device (All)", invoke=function() insertRandomDevice(false) end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Insert Random Device (AU/Native Only)", invoke=function() insertRandomDevice(true) end}

renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Insert Stereo -> Mono device to Beginning of DSP Chain",invoke=function() insertMonoToBeginning() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Insert Stereo -> Mono device to End of DSP Chain",invoke=function() insertMonoToEnd() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Randomize Devices and Plugins Dialog...",invoke=function() pakettiRandomizerDialog() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Randomize Selected Device Parameters",invoke=function()randomize_selected_device()end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Panning - Set All Tracks to Hard Left",invoke=function() globalLeft() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Panning - Set All Tracks to Hard Right",invoke=function() globalRight() end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Panning - Set All Tracks to Center",invoke=function() globalCenter() end}

renoise.tool():add_menu_entry{name="DSP Device:Paketti:Bypass/Enable All Other Track DSP Devices (Toggle)",invoke=function() toggle_bypass_selected_device() end}

renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Convolver:Import Selected Sample to Convolver",invoke=function()
  print("Importing selected sample to Convolver via DSP menu entry")
  local selected_device = renoise.song().selected_device
  local selected_track_index = renoise.song().selected_track_index
  local selected_device_index = renoise.song().selected_device_index
  if not selected_device or selected_device.name ~= "Convolver" then
    pakettiConvolverSelectionDialog(handle_convolver_action)
    return
  end
  save_instrument_to_convolver(selected_device, selected_track_index, selected_device_index) end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Convolver:Load Random IR from User Set Folder",invoke=function() PakettiRandomIR(preferences.PakettiIRPath.value) end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Convolver:Export Convolver IR into New Instrument",invoke=function()
  print("Exporting Convolver IR into New Instrument via DSP menu entry")
  local selected_device = renoise.song().selected_device
  local selected_track_index = renoise.song().selected_track_index
  local selected_device_index = renoise.song().selected_device_index
  if not selected_device or selected_device.name ~= "Convolver" then
    pakettiConvolverSelectionDialog(handle_convolver_action)
    return
  end
  create_instrument_from_convolver(selected_device, selected_track_index, selected_device_index) end}

renoise.tool():add_menu_entry{name="DSP Device:Paketti:Convolver:Show Convolver Selection Dialog",invoke=function()
  print("Showing Convolver Selection Dialog via DSP menu")
  pakettiConvolverSelectionDialog(handle_convolver_action) end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Query Missing Device for Parameters", invoke=function() MissingDeviceParameters() end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Show Paketti Formula Device Manual Dialog...",invoke = pakettiFormulaDeviceDialog}
end

--- Track Automation Config
if preferences.pakettiMenuConfig.Automation then
  debugPrint("Automation Menus Are Enabled")
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Start/Stop Pattern Follow",invoke=function() local fp=renoise.song().transport.follow_player if not fp then fp=true else fp=false end end}

renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Convert FX to Automation",invoke = function() read_fx_to_automation(false) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Convert FX to Automation (Move)",invoke = function() read_fx_to_automation(true) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Convert Automation to FX",invoke = function() write_automation_to_fx(false) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Convert Automation to FX (Move)",invoke = function() write_automation_to_fx(true) end}


renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Snapshot All Devices on Selected Track to Automation",invoke = snapshot_all_devices_to_automation}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Snapshot Selected Device to Automation",invoke = snapshot_selected_device_to_automation}


renoise.tool():add_menu_entry{name="--Track Automation:Paketti Gadgets:Paketti Automation Value...",invoke=function() pakettiAutomationValue() end}

renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Top to Top",invoke=function() apply_constant_automation_top_to_top() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Bottom to Bottom",invoke=function() apply_constant_automation_bottom_to_bottom() end})
renoise.tool():add_menu_entry({name="--Track Automation:Paketti:Automation Curves:Selection Up (Exp)",invoke=function() apply_exponential_automation_curveUP() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Selection Up (Linear)",invoke=function() apply_selection_up_linear() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Selection Down (Exp)",invoke=function() apply_exponential_automation_curveDOWN() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Selection Down (Linear)",invoke=function() apply_selection_down_linear() end})
renoise.tool():add_menu_entry({name="--Track Automation:Paketti:Automation Curves:Center to Top (Exp)",invoke=function() apply_exponential_automation_curve_center_to_top() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Center to Bottom (Exp)",invoke=function() apply_exponential_automation_curve_center_to_bottom() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Top to Center (Exp)",invoke=function() apply_exponential_automation_curve_top_to_center() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti:Automation Curves:Bottom to Center (Exp)",invoke=function() apply_exponential_automation_curve_bottom_to_center() end})
renoise.tool():add_menu_entry({name="--Track Automation:Paketti:Automation Curves:Set to Center",invoke=function() set_to_center() end})
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Open External Editor for Plugin",invoke=function() openExternalInstrumentEditor() end}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Show/Hide External Editor for Device",invoke=function() AutomationDeviceShowUI() end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Show/Hide External Editor for Plugin",invoke=function() openExternalInstrumentEditor() end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Set Automation Range to Max (1.0)",invoke=function() SetAutomationRangeValue(1.0) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Set Automation Range to Middle (0.5)",invoke=function() SetAutomationRangeValue(0.5) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Set Automation Range to Min (0.0)",invoke=function() SetAutomationRangeValue(0.0) end}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Scale Automation to 90%",invoke=function() ScaleAutomation(0.9) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Scale Automation to 110%",invoke=function() ScaleAutomation(1.1) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Scale Automation to 200%",invoke=function() ScaleAutomation(2.0) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Scale Automation to 50%",invoke=function() ScaleAutomation(0.5) end}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Flip Automation Selection Horizontally",invoke=FlipAutomationHorizontal}
renoise.tool():add_menu_entry{name="Track Automation:Paketti:Flip Automation Selection Vertically",invoke=FlipAutomationVertical}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Randomize Automation Envelope",invoke=randomize_envelope}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Flood Fill Automation Selection",invoke=PakettiAutomationSelectionFloodFill}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti:Generate Automation Points from Notes in Selected Track",invoke=function()
add_automation_points_for_notes() end}
renoise.tool():add_menu_entry{name="--Track Automation List:Paketti:Generate Automation Points from Notes in Selected Track",invoke=function()
add_automation_points_for_notes() end}
renoise.tool():add_menu_entry{name="Track Automation List:Paketti:Show/Hide External Editor for Device",invoke=function() AutomationDeviceShowUI() end}
renoise.tool():add_menu_entry{name="Track Automation List:Paketti:Show/Hide External Editor for Plugin",invoke=function() openExternalInstrumentEditor() end}
end

--- Disk Browser Files Config
if preferences.pakettiMenuConfig.DiskBrowserFiles then
debugPrint("Disk Browser Files Menus Are Enabled")
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti Gadgets:Paketti Stacker Dialog...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti Gadgets:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_menu_entry{name="--Disk Browser:Paketti Gadgets:Paketti Dialog of Dialogs...",invoke=function() pakettiDialogOfDialogsToggle() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load Random AKWF Sample",invoke=function() load_random_akwf_sample(1) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load Random amount (1...12) of AKWF Samples",invoke=function() load_random_akwf_sample("random") end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:AKWF:Load 02 AKWF Samples",invoke=function() load_random_akwf_sample(2) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load 05 AKWF Samples",invoke=function() load_random_akwf_sample(5) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load 12 AKWF Samples",invoke=function() load_random_akwf_sample(12) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:AKWF:Load 05 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load 12 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load 05 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Load 12 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (032)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(32, false) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (064)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(64, false) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (128)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(128, false) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (256)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(256, false) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (032,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(32, true) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (064,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(64, true) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (128,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(128, true) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:AKWF:Create Random AKWF Wavetable (256,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(256, true) end}

renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Phrases:Load XRNI & Disable Phrases",invoke=function() loadXRNIWipePhrasesTwo() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Phrases:Load XRNI & Keep Phrases",invoke=function() loadXRNIKeepPhrases() end}

renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Load:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Load:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Load:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Load:Paketti PitchBend Multiple Sample Loader (Normalize)",invoke=function() pitchBendMultipleSampleLoader(true) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Load:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Load:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}

renoise.tool():add_menu_entry{name="Disk Browser:Paketti:Import/Export:Convert REX/RX2/ITI to PTI",invoke=universal_to_pti_convert}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Import .PTI (Polyend Tracker Instrument)",
  invoke=function()
    local f = renoise.app():prompt_for_filename_to_read({"*.PTI"}, "Select PTI to import")
    if f and f ~= "" then pti_loadsample(f) end
  end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Import .RX2 (ReCycle v2.0 Format)",invoke=function() 
  local filename = renoise.app():prompt_for_filename_to_read({"*.RX2"}, "ReCycle .RX2 Import tool")
  if filename then rx2_loadsample(filename) end end}
  renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Import .SF2 (Single XRNI per Preset)",
  invoke=function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import")
    if f and f ~= "" then import_sf2(f) end end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Import/Export:Import .REX (ReCycle v1.0 Legacy Format)",invoke=function() 
    local filename = renoise.app():prompt_for_filename_to_read({"*.REX"}, "ReCycle .REX Import tool")
    if filename then rex_loadsample(filename) end end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Import/Export:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Import/Export:Load .MOD as Sample",invoke=function() 
      local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any .MOD/MOD. to Load as Sample")
      if file_path ~= "" then
        pakettiLoadExeAsSample(file_path)
        paketti_toggle_signed_unsigned() end end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Import/Export:Export .PTI Instrument",invoke=pti_savesample}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti:Import/Export:Export Subfolders as Melodic Slices",invoke=PakettiExportSubfoldersAsMelodicSlices}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti:Import/Export:Export Subfolders as Drum Slices",invoke=PakettiExportSubfoldersAsDrumSlices}
end 


---
--AKAI STUFF


-- Tools Instruments
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export Current Sample as AKP...",invoke=exportCurrentSampleAsAKP}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Akai Formats Info...",invoke=function() showAkaiFormatsInfo() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import Any Akai Sample...",invoke=function() importAnyAkaiSample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import Akai Folder (Batch)...",invoke=function() importAkaiFolderBatch() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export as Akai Format...",invoke=function() exportCurrentSampleAsAkai() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Check Akai Importers...",invoke=function() checkAkaiImportersAvailable() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import MPC2000 SND Sample...",invoke=function() importMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export MPC2000 SND Sample...",invoke=function() exportMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import MPC2000 SND Folder...",invoke=function() importMPC2000Folder() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import Akai Program...",invoke=function() importAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export Akai Program...",invoke=function() exportAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import S900/S950 Sample...",invoke=function() importS900Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export S900/S950 Sample...",invoke=function() exportS900Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import S1000 Sample...",invoke=function() importS1000Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export S1000 Sample...",invoke=function() exportS1000Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import S3000 Sample...",invoke=function() importS3000Sample() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export S3000 Sample...",invoke=function() exportS3000Sample() end}           
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import S1000 Sample...",invoke = function() importS1000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import S3000 Sample...",invoke = function() importS3000Sample() end}
--renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Load:Import AKP File...",invoke = importAKPFile}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import Any Akai Sample...",invoke = function() importAnyAkaiSample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import Akai Folder (Batch)...",invoke = function() importAkaiFolderBatch() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import MPC2000 SND Sample...",invoke = function() importMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import MPC2000 SND Folder...",invoke = function() importMPC2000Folder() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import Akai Program...",invoke = function() importAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Load:Import S900/S950 Sample...",invoke = function() importS900Sample() end}

-- Sample Editor Export
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export S900/S950 Sample...",invoke = function() exportS900Sample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export S1000 Sample...",invoke = function() exportS1000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export S3000 Sample...",invoke = function() exportS3000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export Current Sample as AKP...",invoke = exportCurrentSampleAsAKP}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export as Akai Format...",invoke = function() exportCurrentSampleAsAkai() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export MPC2000 SND Sample...",invoke = function() exportMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Export:Export Akai Program...",invoke = function() exportAkaiProgram() end}

-- Sample Editor Octatrack
--renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Octatrack:Export to Octatrack (.WAV+.OT)...",invoke = function() PakettiOTExport() end}
--renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Octatrack:Export to Octatrack (.OT)",invoke = function() PakettiOTExportOtOnly() end}
--renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Octatrack:Import Octatrack (.OT)...",invoke = function() PakettiOTImport() end}

--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export Current Sample as AKP...",invoke = exportCurrentSampleAsAKP}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import Any Akai Sample...",invoke = function() importAnyAkaiSample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import Akai Folder (Batch)...",invoke = function() importAkaiFolderBatch() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export as Akai Format...",invoke = function() exportCurrentSampleAsAkai() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import MPC2000 SND Sample...",invoke = function() importMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export MPC2000 SND Sample...",invoke = function() exportMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import MPC2000 SND Folder...",invoke = function() importMPC2000Folder() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import Akai Program...",invoke = function() importAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export Akai Program...",invoke = function() exportAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import S900/S950 Sample...",invoke = function() importS900Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export S900/S950 Sample...",invoke = function() exportS900Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import S1000 Sample...",invoke = function() importS1000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export S1000 Sample...",invoke = function() exportS1000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import S3000 Sample...",invoke = function() importS3000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Export:Export S3000 Sample...",invoke = function() exportS3000Sample() end}

--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import AKP File...",invoke = importAKPFile}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import Any Akai Sample...",invoke = function() importAnyAkaiSample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import MPC2000 SND Sample...",invoke = function() importMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import Akai Program...",invoke = function() importAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import S900/S950 Sample...",invoke = function() importS900Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import S1000 Sample...",invoke = function() importS1000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Load:Import S3000 Sample...",invoke = function() importS3000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export S3000 Sample...",invoke = function() exportS3000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export Current Sample as AKP...",invoke = exportCurrentSampleAsAKP}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export as Akai Format...",invoke = function() exportCurrentSampleAsAkai() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export MPC2000 SND Sample...",invoke = function() exportMPC2000Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export Akai Program...",invoke = function() exportAkaiProgram() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export S900/S950 Sample...",invoke = function() exportS900Sample() end}
--renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Export:Export S1000 Sample...",invoke = function() exportS1000Sample() end}

-- renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Load:Import AKP File...",invoke = importAKPFile}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import AKP File...",invoke=importAKPFile}
