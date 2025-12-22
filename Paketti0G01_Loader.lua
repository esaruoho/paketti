local dialog
local upperbuttonwidth=160
local checkbox_spacing=20  -- Variable for checkbox spacing - adjust this to change spacing between checkboxes
local column1_width=430      -- Column 1 width (first column)
local column2_width=570      -- Column 2 width - widest row: text(150) + popup(100) + space(20) + text(150) + popup(200) = 620 + 20px buffer
local column3_width=460      -- Column 3 width

local vb = renoise.ViewBuilder()
local initial_value = nil
local dialog = nil
local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

local DEBUG = false



local filter_types = {"None", "LP Clean", "LP K35", "LP Moog", "LP Diode", "HP Clean","HP K35", "HP Moog", "BP Clean", "BP K35", "BP Moog", "BandPass","BandStop", "Vowel", "Comb", "Decimator", "Dist Shape", "Dist Fold","AM Sine", "AM Triangle", "AM Saw", "AM Pulse"}

local filter_type_map = {}
for i, v in ipairs(filter_types) do
  filter_type_map[v] = i
end

-- Function to get the index of a filter type using the lookup table
local function get_filter_type_index(filter_type)
  local index = filter_type_map[filter_type]
  if index then
    if DEBUG then
      print("Found filter type: " .. filter_type .. " at index: " .. index)
    end
    return index
  else
    if DEBUG then
      print("Filter type not found, defaulting to index 1 ('None').")
    end
    return 1 -- Default to "None" if not found
  end
end

-- Initialize the filter index
local cached_filter_index = 1

local sample_rates = {22050, 44100, 48000, 88200, 96000, 192000}

-- Function to find the index of the sample rate
local function find_sample_rate_index(rate)
    for i, v in ipairs(sample_rates) do
        if v == rate then
            return i
        end
    end
    return 1 -- default to 22050 if not found
end

local os_name=os.platform()
local default_executable
if os_name=="WINDOWS"then default_executable="C:\\Program Files\\espeak\\espeak.exe"
elseif os_name=="MACINTOSH"then default_executable="/opt/homebrew/bin/espeak-ng"
else default_executable="/usr/bin/espeak-ng" end

-- Define the PakettiPluginEntry class
renoise.Document.create("PakettiPluginEntry") {
  name = renoise.Document.ObservableString(),
  path = renoise.Document.ObservableString(),
}
-- Function to create a new PakettiPluginEntry
function create_plugin_entry(name, path)
  local entry = renoise.Document.instantiate("PakettiPluginEntry")
  entry.name.value = name
  entry.path.value = path
  return entry
end

renoise.Document.create("PakettiDeviceEntry") {
  name = renoise.Document.ObservableString(),
  path = renoise.Document.ObservableString(),
  device_type = renoise.Document.ObservableString(),
}

-- Function to create a new PakettiDeviceEntry
function create_device_entry(name, path, device_type)
  local entry = renoise.Document.instantiate("PakettiDeviceEntry")
  entry.name.value = name
  entry.path.value = path
  entry.device_type.value = device_type
  return entry
end

preferences = renoise.Document.create("ScriptingToolPreferences") {
  singlewaveformwriterhex=true,
  paketti_auto_disk_browser_mode = 0,  -- 0=Do Nothing, 1=Hide, 2=Show
  pakettiRePitchEnhanced = false,
  PakettiSteppersGlobalStepCount="16",
  UserSetTunings="",
  AutoInputTuning="false",
  MinimizedPitchControlSmall=false,
  PolyendRoot="",
  PolyendLocalPath="",
  PolyendLocalBackupPath="",
  PolyendUseLocalBackup=false,
  pakettiMarkerLine = 1,
  pakettiMarkerSequence = 1,
  pakettiMarkerExists = false,
  PolyendPTISavePath="",
  PolyendWAVSavePath="",
  PolyendUseSavePaths=true,
  pakettifyReplaceInstrument=false,
  pakettiInstrumentProperties=0,  -- 0=Do Nothing, 1=Hide, 2=Show
  pakettiPitchSliderRange=2,
  pakettiREXBundlePath = "." .. separator .. "rx2",
  pakettiShowSampleDetails=false,
  pakettiShowSampleDetailsFrequencyAnalysis=true,
  pakettiSampleDetailsCycles=1,
  pakettiAlwaysOpenDSPsOnTrack=false,
  pakettiAlwaysOpenSampleFXChainDevices=false,
  pakettiSampleRangeDeviceLoaderEnabled=false,
  pakettiLoaderDontCreateAutomationDevice=false,
  pakettiWipeExplodedTrack=false,
  pakettiAutomationFormat=2,
  pakettiAutomationWipeAfterSwitch=true,
  SelectedSampleBeatSyncLines = false,
  pakettiLoadOrder = false,
  pakettiDeviceLoadBehaviour = 3, -- 1=Open External Editor, 2=Open Selected Parameter Dialog, 3=Do Nothing
  pakettiOctaMEDNoteEchoDistance=2,
  pakettiOctaMEDNoteEchoMin=1,
  pakettiRotateSampleBufferCoarse=1000,
  pakettiRotateSampleBufferFine=10,
  pakettiBlendValue = 40,
  pakettiDialogClose="esc",
  pakettiObliqueStrategiesOnStartup = true,
  pakettiPlayerProEffectDialogDarkMode = false,
  pakettiPlayerProEffectCanvasWrite = false,
  pakettiPlayerProEffectCanvasSubColumn = false,
  pakettiPlayerProNoteCanvasWrite = false,
  pakettiPlayerProNoteCanvasPianoKeys = false,
  pakettiPlayerProNoteCanvasSpray = false,
  pakettiPlayerProNoteCanvasClearSelection = true,
  pakettiPlayerProAlwaysOpen = false,
  pakettiPlayerProSmartSubColumn = true,
  pakettiPlayerProAutoHideOnFrameSwitch = true,
  pakettiInstrumentInfoDialogHeight=750,
  pakettiEnableGlobalGrooveOnStartup=false,
  pakettiKeepSequenceSorted=0,  -- 0=Do Nothing, 1=False, 2=True
  pakettiRandomizeBPMOnNewSong=false,
  pakettiPatternStatusMonitor=false,
  pakettiAuditionOnLineChangeEnabled=false,
  pakettiFrameCalculatorLiveUpdate=1, -- 1=Off, 2=Song to Line, 3=Pattern to Line, 4=Both
  PakettiSBxFollowEnabled=true,
  PakettiPhraseFollowPatternPlayback=false,
  
  pakettiCaptureLastTakeSmartNoteOff=true,
  pakettiSwitcharooAutoGrab=true,
  PakettiImpulseTrackerF8=1,
  PakettiCaptureTrackFromInstrumentMode=0, -- 0=Disabled, 1=Pattern Editor, 2=Not Pattern Editor, 3=All Frames
  PakettiSelectTrackSelectInstrument=false,  -- When switching tracks, automatically select the instrument used in that track
  PakettiDeviceChainPath = "." .. separator .. "DeviceChains" .. separator,
  PakettiIRPath = "." .. separator .. "IR" .. separator,
  PakettiLFOWriteDelete=true,
  -- EQ30 visual options
  PakettiEQ30ColumnGradient=false,
  -- EQ30 automation playmode (1=Points, 2=Lines, 3=Curves)
  PakettiEQ30AutomationPlaymode=2,
  -- EQ30 behavior preferences
  PakettiEQ30Autofocus=true,
  PakettiEQ30MinimizeDevices=false,
  -- Canvas Experiments automation playmode (1=Points, 2=Lines, 3=Curves)
  PakettiCanvasAutomationPlaymode=2,
  upperFramePreference=0,
  _0G01_Loader=false,
  RandomBPM=false,
  loadPaleGreenTheme=false,
  PakettiStripSilenceThreshold=0.0121,
  PakettiMoveSilenceThreshold=0.0121,
  renderSampleRate=88200,
  renderBitDepth=32,
  renderBypass=false,
  RenderDCOffset=false,
  renderInterpolation="precise",  -- "default" or "precise"
  experimentalRenderPriority="high",  -- "high" or "realtime"
  experimentalRenderSilenceMultiplier=1,  -- 0, 1, 3, or 7 silences
  experimentalRenderRemoveSilence=false,  -- Remove silence from end after rendering
  pakettiEditMode=1,
  pakettiLoaderInterpolation=1,
  pakettiLoaderFilterType="LP Clean",
  pakettiLoaderOverSampling=true,
  pakettiLoaderOneshot=false,
  pakettiLoaderAutofade=true,
  pakettiLoaderAutoseek=false,
  pakettiLoaderLoopMode=1,
  pakettiLoaderNNA=2,
  pakettiLoaderLoopExit=false,
  pakettiLoaderMoveSilenceToEnd=false,
  pakettiLoaderNormalizeSamples=false,
  pakettiLoaderNormalizeLargeSamples=false,
  pakettiStemLoaderDestructive=false,  -- When enabled, clears all tracks and patterns before loading stems
  pakettiStemLoaderAutoSliceOnMixedRates=true,  -- Auto-switch to slice mode when mixed sample rates detected
  pakettiLoadToAllTracksPosition=true,  -- false = First (position 2), true = Last (end of chain)
  pakettiLazySlicerShowNewestSlice=false,  -- false = Show Original Sample, true = Show Newest Slice
  pakettiPolyendOpenDialog=true,
  pakettiExplodeTrackNaming=true,  -- Enable note+instrument naming for exploded tracks (e.g. "C-4 MyInstrument")
  selectionNewInstrumentSelect=false,
  selectionNewInstrumentLoop=2,
  selectionNewInstrumentInterpolation=4,
  selectionNewInstrumentAutofade=true,
  selectionNewInstrumentAutoseek=false,
  pakettiPitchbendLoaderEnvelope=false,
  pakettiSlideContentAutomationToo=true,
  pakettiUnisonDetune=25,
  pakettiUnisonDetuneFluctuation=true,
  pakettiUnisonDetuneHardSync=false,
  pakettiUnisonDuplicateInstrument=true,
  pakettiMaxFrameSize=10000000,  -- Default 10MB worth of frames
  pakettiAutomaticRenameTrack=false,  -- Automatic track renaming based on played samples
  PakettiHyperEditCaptureTrackColor=false,
  PakettiHyperEditAutoFit=true,
  PakettiHyperEditManualRows=8,
  pakettiDefaultXRNI = renoise.tool().bundle_path .. "Presets" .. separator .. "12st_Pitchbend.xrni",
  pakettiDefaultDrumkitXRNI = renoise.tool().bundle_path .. "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni",
  pakettiPresetPlusPlusDeviceChain = "DeviceChains" .. separator .. "hipass_lopass_dcoffset.xrnt",
  -- AutoSamplify Settings
  pakettiAutoSamplifyMonitoring = false,
  pakettiAutoSamplifyPakettify = false,
  -- Import Hooks Settings (Master toggle + individual format toggles)
  pakettiImportHooksEnabled = true,  -- Master toggle for all import hooks
  pakettiImportREX = true,           -- REX (.rex) import
  pakettiImportRX2 = true,           -- RX2 (.rx2) import
  pakettiImportIFF = true,           -- IFF (.iff, .8svx, .16sv) import
  pakettiImportSF2 = true,           -- SF2 (.sf2) import
  pakettiImportITI = true,           -- ITI (.iti) import
  pakettiImportOT = true,            -- OT (.ot) import
  pakettiImportWT = true,            -- WT (.wt) import
  pakettiImportSTRD = true,          -- STRD (.strd, .work) import
  pakettiImportPTI = true,           -- PTI/MTI (.pti, .mti) import
  pakettiImportMTP = true,           -- MTP/MT (.mtp, .mt) import
  pakettiImportMID = true,           -- MIDI (.mid) import
  pakettiImportTXT = true,           -- TXT (.txt) import - eSpeak
  pakettiImportImage = true,         -- Image (.png, .bmp, .jpg, .jpeg, .gif) import
  pakettiImportCSV = true,           -- CSV (.csv) import - PCMWriter
  pakettiImportEXE = true,           -- Raw binary (.exe, .dll, .bin, .sys, .dylib) import
  -- Quick Sample to New Track Settings
  pakettiQuickSampleTrackVolume = true,  -- Set new track volume to -30dB for safe recording levels
  -- MPC Cycler Settings
  pakettiMPCCyclerLastSampleFolder = "",
  pakettiMPCCyclerLastInstrumentFolder = "",
  pakettiMPCCyclerSampleIndex = 1,
  pakettiMPCCyclerInstrumentIndex = 1,
  pakettiMPCCyclerGlobalLock = false,
  pakettiMPCCyclerPreviewEnabled = false,
  ActionSelector = {
 Index01="",
 Index02="",
 Index03="",
 Index04="",
 Index05="",
 Index06="",
 Index07="",
 Index08="",
 Index09="",
 Index10="",
 Index11="",
 Index12="",
 Index13="",
 Index14="",
 Index15="",
 Index16="",
 Index17="",
 Index18="",
 Index19="",
 Index20="",
 Index21="",
 Index22="",
 Index23="",
 Index24="",
 Index25="",
 Index26="",
 Index27="",
 Index28="",
 Index29="",
 Index30="",
 Index31="",
 Index32="",
 Index33="",
 Index34="",
 Index35="",
 Index36="",
 Index37="",
 Index38="",
 Index39="",
 Index40="",
 Index41="",
 Index42="",
 Index43="",
 Index44="",
 Index45="",
 Index46="",
 Index47="",
 Index48="",
 Index49="",
 Index50="",
  },
  UserPreferences = {
    userPreferredDevice01 = "<None>",
    userPreferredDevice02 = "<None>",
    userPreferredDevice03 = "<None>",
    userPreferredDevice04 = "<None>",
    userPreferredDevice05 = "<None>",
    userPreferredDevice06 = "<None>",
    userPreferredDevice07 = "<None>",
    userPreferredDevice08 = "<None>",
    userPreferredDevice09 = "<None>",
    userPreferredDevice10 = "<None>",
    userPreferredDeviceLoad = true
  },
  WipeSlices = {
    WipeSlicesLoopMode=2,
    WipeSlicesLoopRelease=false,
    WipeSlicesBeatSyncMode=1,
    WipeSlicesOneShot=false,
    WipeSlicesAutoseek=false,
    WipeSlicesAutofade=true,
    WipeSlicesMuteGroup=1,
    WipeSlicesNNA=1,
    WipeSlicesBeatSyncGlobal=false,
    sliceCounter=1,
    SliceLoopMode=true, 
    slicePreviousDirection=1
  },
  SlicePro = {
    SliceProBeatSyncMode=1,     -- 1=Repitch, 2=Percussion, 3=Texture
    SliceProMuteGroup=0,        -- 0-15 (0 = none)
    SliceProNNA=1,              -- 1=Cut, 2=Note Off, 3=Sustain
    SliceProLoopMode=1,         -- 1=Off, 2=Forward, 3=Reverse, 4=PingPong
    SliceProAutofade=true,
    SliceProLoopRelease=false,
    SliceProOneShot=true,       -- Set one-shot mode on slices
    SliceProRequireSampleEditor=false,  -- When true, only works in Sample Editor
    SliceProOverrides="",       -- Persistent overrides storage (serialized string)
    SliceProFallbackOnLowConfidence=true,  -- Use intelligent detection as fallback
    SliceProConfidenceThreshold=0.3  -- Below this confidence, use fallback
  },
  AppSelection = {
    AppSelection1="",
    AppSelection2="",
    AppSelection3="",
    AppSelection4="",
    AppSelection5="",
    AppSelection6="",
    SmartFoldersApp1="",
    SmartFoldersApp2="",
    SmartFoldersApp3=""
  },
  pakettiThemeSelector = {
    PreviousSelectedTheme = "",
    FavoritedList = { "<No Theme Selected>" }, 
    RenoiseLaunchFavoritesLoad = false,
    RenoiseLaunchRandomLoad = false
  },
  PakettiJumpRowCommands = false,
  PakettiJumpForwardBackwardCommands = false,
  PakettiTriggerPatternLineCommands = false,
  PakettiInstrumentTransposeCommands = false,
  PakettiPlayAndLoopPatternCommands = true,
  UserDefinedSampleFolders01="",
  UserDefinedSampleFolders02="",
  UserDefinedSampleFolders03="",
  UserDefinedSampleFolders04="",
  UserDefinedSampleFolders05="",
  UserDefinedSampleFolders06="",
  UserDefinedSampleFolders07="",
  UserDefinedSampleFolders08="",
  UserDefinedSampleFolders09="",
  UserDefinedSampleFolders10="",
  PakettiFuzzySampleSearchPath="",

  pakettieSpeak = {
    word_gap=3,
    capitals=5,
    pitch=35,
    amplitude=05,
    speed=150,
    language=40,
    voice=2,
    text="Good afternoon, this is eSpeak, a Text-to-Speech engine, speaking. Shall we play a game?",
    executable=default_executable,
    clear_all_samples=true,
    add_render_to_current_instrument=false,
    render_on_change=false,
    dont_pakettify = false
  },
  OctaMEDPickPutSlots = {
    SetSelectedInstrument=false,
    UseEditStep=false,
    Slot01="",
    Slot02="",
    Slot03="",
    Slot04="",
    Slot05="",
    Slot06="",
    Slot07="",
    Slot08="",
    Slot09="",
    Slot10="",
    RandomizeEnabled=false,
    RandomizePercentage=10,
  },
  RandomizeSettings = {
    pakettiRandomizeSelectedDevicePercentage=50,
    pakettiRandomizeSelectedDevicePercentageUserPreference1=10,
    pakettiRandomizeSelectedDevicePercentageUserPreference2=25,
    pakettiRandomizeSelectedDevicePercentageUserPreference3=50,
    pakettiRandomizeSelectedDevicePercentageUserPreference4=75,
    pakettiRandomizeSelectedDevicePercentageUserPreference5=90,
    pakettiRandomizeAllDevicesPercentage=50,
    pakettiRandomizeAllDevicesPercentageUserPreference1=10,
    pakettiRandomizeAllDevicesPercentageUserPreference2=25,
    pakettiRandomizeAllDevicesPercentageUserPreference3=50,
    pakettiRandomizeAllDevicesPercentageUserPreference4=75,
    pakettiRandomizeAllDevicesPercentageUserPreference5=90,
    pakettiRandomizeSelectedPluginPercentage=50,
    pakettiRandomizeSelectedPluginPercentageUserPreference1=10,
    pakettiRandomizeSelectedPluginPercentageUserPreference2=20,
    pakettiRandomizeSelectedPluginPercentageUserPreference3=30,
    pakettiRandomizeSelectedPluginPercentageUserPreference4=40,
    pakettiRandomizeSelectedPluginPercentageUserPreference5=50,
    pakettiRandomizeAllPluginsPercentage=50,
    pakettiRandomizeAllPluginsPercentageUserPreference1=10,
    pakettiRandomizeAllPluginsPercentageUserPreference2=20,
    pakettiRandomizeAllPluginsPercentageUserPreference3=30,
    pakettiRandomizeAllPluginsPercentageUserPreference4=40,
    pakettiRandomizeAllPluginsPercentageUserPreference5=50
  },
  PakettiYTDLP = {
    PakettiYTDLPLoopMode=2,
    PakettiYTDLPClipLength=10,
    PakettiYTDLPAmountOfVideos=1,
    PakettiYTDLPLoadWholeVideo=true,
    PakettiYTDLPOutputDirectory="Set this yourself, please.",
    PakettiYTDLPFormatToSave=1,
    PakettiYTDLPPathToSave="<No path set>",
    PakettiYTDLPNewInstrumentOrSameInstrument=true,
    PakettiYTDLPYT_DLPLocation="/opt/homebrew/bin/yt-dlp"  
  },  
  pakettiCheatSheet = {
    pakettiCheatSheetRandomize=false,
    pakettiCheatSheetRandomizeMin=0,
    pakettiCheatSheetRandomizeMax=255,
    pakettiCheatSheetFillAll=100,
    pakettiCheatSheetRandomizeWholeTrack=false,
    pakettiCheatSheetRandomizeSwitch=false,
    pakettiCheatSheetRandomizeDontOverwrite=false,
    pakettiCheatSheetOnlyModifyEffects=false,
    pakettiCheatSheetOnlyModifyNotes=false,
  }, 
  pakettiPhraseInitDialog = {
    Autoseek = false,
    PhraseLooping = true,
    VolumeColumnVisible = false,
    PanningColumnVisible = false,
    InstrumentColumnVisible = false,
    DelayColumnVisible = false,
    SampleFXColumnVisible = false,
    NoteColumns = 1,
    EffectColumns = 0,
    Shuffle = 0,
    LPB = 4,
    Length = 64,
    SetName = false,
    Name=""
    },
  pakettiTrackInitDialog = {
    VolumeColumnVisible = false,
    PanningColumnVisible = false,
    DelayColumnVisible = false,
    SampleFXColumnVisible = false,
    NoteColumns = 1,
    EffectColumns = 1,
    SendEffectColumns = 1,
    SetName = false,
    Name="Track #"
    },
    pakettiTitler = {
    textfile_path = "External/wordlist.txt",
    notes_file_path = "External/notes.txt",
    trackTitlerDateFormat = "YYYY_MM_DD",
    },
    pakettiMidiPopulator = {
    volumeColumn = false,
    panningColumn = false,
    delayColumn = false,
    sampleEffectsColumn = false,
    noteColumns = 1.0,
    effectColumns = 1.0,
    collapsed = false,
    incomingAudio = false,
    populateSends = true,
    sendDeviceType = 1  -- 1 = Send, 2 = Multiband Send
    },    
  PakettiPluginLoaders = renoise.Document.DocumentList(),
  PakettiDeviceLoaders = renoise.Document.DocumentList(), 
    PakettiDynamicViews = renoise.Document.DocumentList(),
  UserDevices = {
      Path = renoise.Document.ObservableString(""),
    Slot01 = renoise.Document.ObservableString(""),
    Slot02 = renoise.Document.ObservableString(""),
    Slot03 = renoise.Document.ObservableString(""),
    Slot04 = renoise.Document.ObservableString(""),
    Slot05 = renoise.Document.ObservableString(""),
    Slot06 = renoise.Document.ObservableString(""),
    Slot07 = renoise.Document.ObservableString(""),
    Slot08 = renoise.Document.ObservableString(""),
    Slot09 = renoise.Document.ObservableString(""),
    Slot10 = renoise.Document.ObservableString("")  
    },
  UserInstruments = {
    Path = renoise.Document.ObservableString(""),
    Slot01 = renoise.Document.ObservableString(""),
    Slot02 = renoise.Document.ObservableString(""),
    Slot03 = renoise.Document.ObservableString(""),
    Slot04 = renoise.Document.ObservableString(""),
    Slot05 = renoise.Document.ObservableString(""),
    Slot06 = renoise.Document.ObservableString(""),
    Slot07 = renoise.Document.ObservableString(""),
    Slot08 = renoise.Document.ObservableString(""),
    Slot09 = renoise.Document.ObservableString(""),
    Slot10 = renoise.Document.ObservableString("")    
  },
  -- PakettiXMLizer Custom LFO Envelope Storage (16 slots)
  PakettiXMLizer = {
    pakettiCustomLFOXMLInject1 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject2 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject3 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject4 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject5 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject6 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject7 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject8 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject9 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject10 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject11 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject12 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject13 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject14 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject15 = renoise.Document.ObservableString(""),
    pakettiCustomLFOXMLInject16 = renoise.Document.ObservableString("")
  },
  -- Add pattern sequencer preferences section
  pakettiPatternSequencer = {
    clone_prefix = renoise.Document.ObservableString(""),
    clone_suffix = renoise.Document.ObservableString(" (Clone)"),
    use_numbering = renoise.Document.ObservableBoolean(true),
    numbering_format = renoise.Document.ObservableString("%d"),
    numbering_start = renoise.Document.ObservableNumber(2),
    select_after_clone = renoise.Document.ObservableBoolean(true),
    naming_behavior = renoise.Document.ObservableNumber(1)  -- 1=Use Settings, 2=Clear Name, 3=Keep Original
  },
  -- Wonkify preferences section
  pakettiWonkify = {
    -- Random Seed
    RandomSeedEnabled = true,
    RandomSeed = 12345,
    -- Multi-pattern generation
    PatternCount = 1,
    -- Rhythm Drift - Delay Ticks (micro-timing within row)
    DelayDriftEnabled = false,
    DelayDriftPercentage = 30,
    DelayDriftMax = 32,
    -- Rhythm Drift - Row Position (move to different lines)
    RowDriftEnabled = false,
    RowDriftPercentage = 20,
    RowDriftMax = 2,
    -- Pitch Drift (semitone shift)
    PitchDriftEnabled = false,
    PitchDriftPercentage = 15,
    PitchDriftMax = 2,
    PitchDriftTracks = "",
    -- Velocity Variation (percentage change from original)
    VelocityEnabled = false,
    VelocityPercentage = 40,
    VelocityVariation = 20,
    -- Note Density Variation
    DensityEnabled = false,
    DensityAddPercentage = 10,
    DensityRemovePercentage = 10,
    -- Ghost Notes (Rolls)
    GhostEnabled = false,
    GhostPercentage = 15,
    GhostCount = 2,
    GhostDirection = 1,
    GhostVolumeStart = 20,
    GhostVolumeEnd = 60,
    -- Retrig
    RetrigEnabled = false,
    RetrigPercentage = 10,
    RetrigMin = 1,
    RetrigMax = 8,
    RetrigColumn = 1
  },
  -- Menu Configuration Settings
  pakettiMenuConfig = {
    InstrumentBox = true,
    SampleEditor = true,
    SampleNavigator = true,
    SampleKeyzone = true,
    Mixer = true,
    PatternEditor = true,
    MainMenuTools = true,
    MainMenuView = true,
    MainMenuFile = true,
    PatternMatrix = true,
    PatternSequencer = true,
    PhraseEditor = true,
    PakettiGadgets = true,
    TrackDSPChain = true,
    TrackDSPDevice = true,
    Automation = true,
    DiskBrowserFiles = true,
    -- Master toggles (require Renoise restart to take effect)
    MasterMenusEnabled = true,
    MasterKeybindingsEnabled = true,
    MasterMidiMappingsEnabled = true
  },
  -- Groovebox 8120: show/hide additional options foldout by default
  PakettiGroovebox8120AdditionalOptions = false,
  -- Groovebox 8120 playhead highlight color (1=None, 2=Bright Orange, 3=Deeper Purple, 4=Black, 5=White, 6=Dark Grey)
  PakettiGrooveboxPlayheadColor = 3,
  -- Paketti Gater panning intensity (0-100%, controls how extreme left/right panning is)
  PakettiGaterPanningIntensity = 100,
  -- Groovebox 8120 main preferences
  PakettiGroovebox8120 = {
    Collapse = false,
    AppendTracksAndInstruments = true,
  },
  -- Groovebox 8120 per-instrument BeatSync mode defaults (1=Repitch, 2=Percussion, 3=Texture)
  PakettiGroovebox8120Beatsync = {
    Mode01 = 1,
    Mode02 = 1,
    Mode03 = 1,
    Mode04 = 1,
    Mode05 = 1,
    Mode06 = 1,
    Mode07 = 1,
    Mode08 = 1,
    Nna01 = 1,
    Nna02 = 1,
    Nna03 = 1,
    Nna04 = 1,
    Nna05 = 1,
    Nna06 = 1,
    Nna07 = 1,
    Nna08 = 1,
  },
  -- 1 = File, 2 = Paketti (File:Paketti), 3 = Both
  pakettiFileMenuLocationMode = 3,
  SononymphAutostart = false,
  SononymphAutotransfercreatenew = false,
  SononymphAutotransfercreateslot = false,
  SononymphPollingInterval = 1,
  SononymphPathToExe = "",
  SononymphPathToConfig = "",
  SononymphShowTransferWarning = true,
  SononymphShowSearchWarning = true,
  SononymphShowPrefs = true,
  -- Dialog of Dialogs Settings
  pakettiDialogOfDialogsColumnsPerRow = 6,
  -- Slice Step Sequencer Settings
  pakettiSliceStepSeqShowVelocity = false,
  -- Paketti Execute Settings
  pakettiExecute = {
    App01 = renoise.Document.ObservableString(""),
    App01Argument = renoise.Document.ObservableString(""),
    App02 = renoise.Document.ObservableString(""),
    App02Argument = renoise.Document.ObservableString(""),
    App03 = renoise.Document.ObservableString(""),
    App03Argument = renoise.Document.ObservableString(""),
    App04 = renoise.Document.ObservableString(""),
    App04Argument = renoise.Document.ObservableString(""),
    App05 = renoise.Document.ObservableString(""),
    App05Argument = renoise.Document.ObservableString(""),
    App06 = renoise.Document.ObservableString(""),
    App06Argument = renoise.Document.ObservableString(""),
    App07 = renoise.Document.ObservableString(""),
    App07Argument = renoise.Document.ObservableString(""),
    App08 = renoise.Document.ObservableString(""),
    App08Argument = renoise.Document.ObservableString(""),
    App09 = renoise.Document.ObservableString(""),
    App09Argument = renoise.Document.ObservableString(""),
    App10 = renoise.Document.ObservableString(""),
    App10Argument = renoise.Document.ObservableString("")
  },
  -- Parameter Editor Settings
  pakettiParameterEditor = {
    PreviousNext = true,
    AB = true,
    AutomationPlaymode = true,
    RandomizeStrength = true,
    HalfSize = false,
    HalfSizeFont = false,
    AutoOpen = false
  },
  -- Create New Send Settings
  pakettiCreateNewSends = {
    Collapsed = false,
    SendNamingPerTrack = true  -- true = per-track naming (S01-S04 per track), false = global naming (S01, S02, S03...)
  },
  -- PlayerPro Waveform Viewer Settings
  pakettiPlayerProWaveformViewer = {
    OnlySelectedTrack = false,
    SampleName = false,
    InstrumentName = false,
    NoteName = false,
    Zoom = 1,  -- 1x, 2x, 3x
    Direction = 1,  -- 1=horizontal, 2=vertical
    HorizontalPlayhead = true,  -- Show/hide horizontal playhead (yellow line)
    VerticalPlayhead = true     -- Show/hide vertical playhead (yellow line)
  },
}

renoise.tool().preferences = preferences

-- Accessing Segments
eSpeak = renoise.tool().preferences.pakettieSpeak
pakettiThemeSelector = renoise.tool().preferences.pakettiThemeSelector
WipeSlices = renoise.tool().preferences.WipeSlices
AppSelection = renoise.tool().preferences.AppSelection
RandomizeSettings = renoise.tool().preferences.RandomizeSettings
PakettiYTDLP = renoise.tool().preferences.PakettiYTDLP
DynamicViewPrefs = renoise.tool().preferences.PakettiDynamicViews

-- Safety check: ensure AppSelection is properly initialized
if not AppSelection then
  print("WARNING: AppSelection preferences not loaded properly, initializing defaults")
  AppSelection = {
    AppSelection1 = { value = "" },
    AppSelection2 = { value = "" },
    AppSelection3 = { value = "" },
    AppSelection4 = { value = "" },
    AppSelection5 = { value = "" },
    AppSelection6 = { value = "" },
    SmartFoldersApp1 = { value = "" },
    SmartFoldersApp2 = { value = "" },
    SmartFoldersApp3 = { value = "" }
  }
end

-- Add pattern sequencer preferences accessor
PatternSequencer = renoise.tool().preferences.pakettiPatternSequencer
-- Add execute preferences accessor
PakettiExecute = renoise.tool().preferences.pakettiExecute
-- Add parameter editor preferences accessor
PakettiParameterEditor = renoise.tool().preferences.pakettiParameterEditor
-- Add Create New Sends preferences accessor
PakettiCreateNewSends = renoise.tool().preferences.pakettiCreateNewSends
-- Add PlayerPro Waveform Viewer preferences accessor
PakettiPlayerProWaveformViewer = renoise.tool().preferences.pakettiPlayerProWaveformViewer

      -- Define available keys for dialog closing
      local dialog_close_keys = {"tab", "esc", "space", "return", "q", "donteverclose"}



-- Function to initialize the filter index
local function initialize_filter_index()
  if preferences.pakettiLoaderFilterType.value ~= nil then
    cached_filter_index = get_filter_type_index(preferences.pakettiLoaderFilterType.value)
  else
    preferences.pakettiLoaderFilterType.value = "LP Moog"
    cached_filter_index = get_filter_type_index("LP Moog")
  end
end

initialize_filter_index()

local function pakettiGetXRNIDefaultPresetFiles()
    local presetsFolder = renoise.tool().bundle_path .. "Presets" .. separator
    local files = {}
    
    -- Try to get files from the presets folder
    local success, result = pcall(os.filenames, presetsFolder, "*.xrni")
    if success and result then
        files = result
    end
    
    if #files == 0 then
        renoise.app():show_status("No .xrni preset files found in: " .. presetsFolder)
        return { "<No Preset Selected>" }
    end
    
    -- Process filenames to remove path and use correct separator
    for i, file in ipairs(files) do
        -- Extract just the filename from the full path
        files[i] = file:match("[^"..separator.."]+$")
    end
    
    -- Sort the files alphabetically for better user experience
    table.sort(files, function(a, b) return a:lower() < b:lower() end)
    
    -- Insert a default option at the beginning
    table.insert(files, 1, "<No Preset Selected>")
    
    return files
end

-- Function to get available .xrnt device chain files
function pakettiGetXRNTDeviceChainFiles()
    local deviceChainsFolder = renoise.tool().bundle_path .. "DeviceChains" .. separator
    local files = {}
    
    -- Try to get files from the DeviceChains folder
    local success, result = pcall(os.filenames, deviceChainsFolder, "*.xrnt")
    if success and result then
        files = result
    end
    
    -- Process filenames to remove path and use correct separator
    for i, file in ipairs(files) do
        -- Extract just the filename from the full path
        files[i] = file:match("[^"..separator.."]+$")
    end
    
    -- Sort the files alphabetically for better user experience
    table.sort(files, function(a, b) return a:lower() < b:lower() end)
    
    -- Always add <None> as the first option
    table.insert(files, 1, "<None>")
    
    return files
end

-- Function to create horizontal rule
function horizontal_rule()
    return vb:horizontal_aligner{mode="justify",width="100%", vb:space{width=2}, vb:row{height=2,width="30%", style="panel"}, vb:space{width=2}}
end

-- Function to create vertical space
function vertical_space(height) return vb:row{height = height} end

-- Functions to update preferences
function update_interpolation_mode(value) preferences.pakettiLoaderInterpolation.value = value end
function update_autofade_mode(value) preferences.pakettiLoaderAutofade.value = value end
function update_oversampling_mode(value) preferences.pakettiLoaderOverSampling.value=value end

function update_loop_mode(loop_mode_pref, value)
  loop_mode_pref.value = value
  preferences.pakettiLoaderLoopMode.value = value
end

function create_loop_mode_switch(preference)
  return vb:popup{
    items = {"Off", "Forward", "Backward", "PingPong"},
    value = preference.value,
    width=100,
    notifier=function(value)
      update_loop_mode(preference, value)
    end
  }
end

local function update_strip_silence_preview(threshold)
  local song=renoise.song()
  if not song.selected_sample then return end
  
  local sample_buffer = song.selected_sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then return end
  
  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR  
  
  -- If threshold is 0, clear selection and return
  if threshold == 0 then
    sample_buffer.selection_start = 1
    sample_buffer.selection_end = 1
    return
  end
  
  -- Calculate silence regions
  local channels = sample_buffer.number_of_channels
  local frames = sample_buffer.number_of_frames
  local selection_ranges = {}
  local in_silence = false
  local silence_start = 0
  
  for frame = 1, frames do
      local is_silent = true
      for channel = 1, channels do
          if math.abs(sample_buffer:sample_data(channel, frame)) > threshold then
              is_silent = false
              break
          end
      end
      
      if is_silent and not in_silence then
          in_silence = true
          silence_start = frame
      elseif not is_silent and in_silence then
          in_silence = false
          table.insert(selection_ranges, {silence_start, frame - 1})
      end
  end
  
  -- If we ended in silence, add final range
  if in_silence then
      table.insert(selection_ranges, {silence_start, frames})
  end
  
  -- Update sample editor selection to show silence regions
  if #selection_ranges > 0 then
      sample_buffer.selection_start = selection_ranges[1][1]
      sample_buffer.selection_end = selection_ranges[1][2]
  end
end

local function update_move_silence_preview(threshold)
  local song=renoise.song()
  if not song.selected_sample then return end
  
  local sample_buffer = song.selected_sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then return end
  
  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR  

  -- If threshold is 0, clear selection and return
  if threshold == 0 then
    sample_buffer.selection_start = 1
    sample_buffer.selection_end = 1
    return
  end
  
  -- Find first non-silent frame
  local channels = sample_buffer.number_of_channels
  local frames = sample_buffer.number_of_frames
  local first_sound = 1
  
  for frame = 1, frames do
      local is_silent = true
      for channel = 1, channels do
          if math.abs(sample_buffer:sample_data(channel, frame)) > threshold then
              is_silent = false
              break
          end
      end
      
      if not is_silent then
          first_sound = frame
          break
      end
  end
  
  -- Update sample editor selection to show beginning silence
  if first_sound > 1 then
      sample_buffer.selection_start = 1
      sample_buffer.selection_end = first_sound - 1
  else
      -- No silence at beginning, clear selection
      sample_buffer.selection_start = 1
      sample_buffer.selection_end = 1
  end
end

-- Initialize filter index
if preferences.pakettiLoaderFilterType.value ~= nil then
  initial_value = get_filter_type_index(preferences.pakettiLoaderFilterType.value)
else
  preferences.pakettiLoaderFilterType.value ="LP Moog"
  initial_value = get_filter_type_index("LP Moog")
end

local dialog_content = nil

function pakettiPreferences()
  -- Initialize unison detune preferences if nil
  if preferences.pakettiUnisonDetune.value == nil then
    preferences.pakettiUnisonDetune.value = 25
  end
  -- Clamp unison detune to new maximum of 96
  if preferences.pakettiUnisonDetune.value > 96 then
    preferences.pakettiUnisonDetune.value = 96
  end
  if preferences.pakettiUnisonDetuneFluctuation.value == nil then
    preferences.pakettiUnisonDetuneFluctuation.value = true
  end
  if preferences.pakettiUnisonDetuneHardSync.value == nil then
    preferences.pakettiUnisonDetuneHardSync.value = false
  end
  if preferences.pakettiUnisonDuplicateInstrument.value == nil then
    preferences.pakettiUnisonDuplicateInstrument.value = true
  end

  local pakettiDeviceChainPathDisplayId = "pakettiDeviceChainPathDisplay_" .. tostring(math.random(2, 30000))
local pakettiIRPathDisplayId = "pakettiIRPathDisplay_" .. tostring(math.random(2, 30000))

   local coarse_value_label = vb:text{width=60,
     text = string.format("%05d", preferences.pakettiRotateSampleBufferCoarse.value)
   }
   
   local fine_value_label = vb:text{width=60,
     text = string.format("%05d", preferences.pakettiRotateSampleBufferFine.value)
   }

  local unison_detune_value_label = vb:text{
    width=50,
    text = tostring(preferences.pakettiUnisonDetune.value)
  }

  local max_frame_size_value_label = vb:text{
    width=150,
    text = string.format("%.0f MB (%d frames)", preferences.pakettiMaxFrameSize.value / 1000000, preferences.pakettiMaxFrameSize.value)
  }


    local blend_value_label = vb:text{width=30,
      text = tostring(math.floor(preferences.pakettiBlendValue.value))
    }

    local threshold_label = vb:text{width=60,
      text = string.format("%07.3f%%", preferences.PakettiStripSilenceThreshold.value * 100)}

    local begthreshold_label = vb:text{width=60,
        text = string.format("%07.3f%%", preferences.PakettiMoveSilenceThreshold.value * 100)}

    if dialog and dialog.visible then
        dialog_content=nil
        dialog:close()
        return
    end

        local presetFiles = pakettiGetXRNIDefaultPresetFiles()
    
    -- Get the initial value (index) for the popup
    local pakettiDefaultXRNIDisplayId = "pakettiDefaultXRNIDisplay_" .. tostring(math.random(2,30000))
    local pakettiDefaultDrumkitXRNIDisplayId = "pakettiDefaultDrumkitXRNIDisplay_" .. tostring(math.random(2,30000))

  -- Get device chain files and find current selection
  local deviceChainFiles = pakettiGetXRNTDeviceChainFiles()
  local currentDeviceChainIndex = 1
  
  -- Find the index of currently selected device chain
  if preferences.pakettiPresetPlusPlusDeviceChain.value == "" then
    -- Empty preference means <None> was selected, which is always index 1
    currentDeviceChainIndex = 1
  else
    local currentFileName = preferences.pakettiPresetPlusPlusDeviceChain.value:match("[^/\\]+$")
    if currentFileName then
      for i, file in ipairs(deviceChainFiles) do
        if file == currentFileName then
          currentDeviceChainIndex = i
          break
        end
      end
    end
  end

  local dialog_content = vb:column{
      horizontal_rule(),
      vb:row{ -- this is where the row structure starts.
        vb:column{ -- first column.
          width=column1_width,style="group",margin=5,
          vb:column{
            style="group",width="100%",--margin=10,
            vb:text{style="strong",font="bold",text="Miscellaneous Settings"},
            --[[vb:row{
              vb:text{text="Upper Frame",width=150,tooltip="Whether F2,F3,F4,F11 change the Upper Frame Scope state or not"},
              vb:switch{items={"Off","Scopes","Spectrum"},value=preferences.upperFramePreference.value+1,width=200,
                tooltip="Whether F2,F3,F4,F11 change the Upper Frame Scope state or not",
                notifier=function(value) preferences.upperFramePreference.value=value-1 end}
            },
            ]]--
            
            vb:row{
              vb:text{text="Global Groove on Startup",width=150,tooltip="This enables Global Groove at the start of a new song or opening of Renoise"},
              vb:checkbox{
                value=preferences.pakettiEnableGlobalGrooveOnStartup.value,
                tooltip="This enables Global Groove at the start of a new song or opening of Renoise",
                notifier=function(value) preferences.pakettiEnableGlobalGrooveOnStartup.value=value end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="New Song BPM Randomizer",width=200,tooltip="Randomly set BPM (60-220) with bell curve around 120 for new songs (not loaded from file)"},
              vb:checkbox{
                value=preferences.pakettiRandomizeBPMOnNewSong.value,
                tooltip="Randomly set BPM (60-220) with bell curve around 120 for new songs (not loaded from file)",
                notifier=function(value) preferences.pakettiRandomizeBPMOnNewSong.value=value end
              }
            },
            vb:row{
              vb:text{text="Keep Sequence Sorted",width=150,tooltip="Control sequencer.keep_sequence_sorted on startup. True = patterns stay sorted, False = patterns can be reordered freely"},
              vb:popup{items={"Do Nothing","False","True"},tooltip="Control sequencer.keep_sequence_sorted on startup. True = patterns stay sorted, False = patterns can be reordered freely",value=preferences.pakettiKeepSequenceSorted.value+1,width=100,
                notifier=function(value)
                  preferences.pakettiKeepSequenceSorted.value=(value-1)
                  -- Apply the setting immediately
                  if renoise.song() then
                    if preferences.pakettiKeepSequenceSorted.value == 1 then
                      renoise.song().sequencer.keep_sequence_sorted = false
                    elseif preferences.pakettiKeepSequenceSorted.value == 2 then
                      renoise.song().sequencer.keep_sequence_sorted = true
                    end
                    -- Mode 0 (Do Nothing) - no immediate action taken
                  end
                  local mode_names = {"Do Nothing", "False", "True"}
                  renoise.app():show_status("Keep Sequence Sorted: " .. mode_names[value])
                end}
            },
            vb:row{
              vb:text{text="0G01 Loader",width=150,tooltip="Upon loading a Sample, inserts a C-4 and -G01 to New Track, Sample plays until end of length and triggers again."},
              vb:checkbox{
                value=preferences._0G01_Loader.value,
                tooltip="Upon loading a Sample, inserts a C-4 and -G01 to New Track, Sample plays until end of length and triggers again.",
                notifier=function(value)
                  preferences._0G01_Loader.value=value
                  update_0G01_loader_menu_entries()
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Random BPM",width=200,tooltip="Write BPM to file when using random BPM functions (Random BPM from List: 80, 100, 115, 123, 128, 132, 135, 138, 160)"},
              vb:checkbox{
                value=preferences.RandomBPM.value,
                tooltip="Write BPM to file when using random BPM functions (Random BPM from List: 80, 100, 115, 123, 128, 132, 135, 138, 160)",
                notifier=function(value) preferences.RandomBPM.value=value end
              },
--              vb:space{width=checkbox_spacing},
            },
            
              vb:row{
                vb:text{text="Always Open Track DSPs",width=150,tooltip="Automatically open external editors for all Track DSP devices when switching tracks"},
                vb:checkbox{
                  value=preferences.pakettiAlwaysOpenDSPsOnTrack.value,
                  tooltip="Automatically open external editors for all Track DSP devices when switching tracks",
                  notifier=function(value) 
                    preferences.pakettiAlwaysOpenDSPsOnTrack.value = value
                    -- Only toggle if the current state doesn't match the desired state
                    if PakettiAutomaticallyOpenTrackDeviceEditorsEnabled ~= value then
                      PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode()
                    end
                  end
                },
                vb:space{width=checkbox_spacing},
                vb:text{text="Always Open Sample FX Chain Devices",width=200,tooltip="Automatically open external editors for all Sample FX Chain devices when switching samples"},
                vb:checkbox{
                  value=preferences.pakettiAlwaysOpenSampleFXChainDevices.value,
                  tooltip="Automatically open external editors for all Sample FX Chain devices when switching samples",
                  notifier=function(value) 
                    preferences.pakettiAlwaysOpenSampleFXChainDevices.value = value
                    -- Only toggle if the current state doesn't match the desired state
                    if PakettiAutomaticallyOpenSampleDeviceChainExternalEditorsEnabled ~= value then
                      PakettiAutomaticallyOpenSelectedSampleDeviceChainExternalEditorsToggleAutoMode()
                    end
                  end
                }
              },
              vb:row{
                vb:text{text="Selected Sample BeatSync",width=150},

                vb:checkbox{
                  value=preferences.SelectedSampleBeatSyncLines.value,
                  notifier=function(value) preferences.SelectedSampleBeatSyncLines.value=value end
                },
                vb:space{width=checkbox_spacing},  

                vb:text{text="Replace Current Instrument",width=200,tooltip="Pakettification replaces current instrument instead of creating new one"},
                vb:checkbox{
                  value=preferences.pakettifyReplaceInstrument.value,
                  tooltip="Pakettification replaces current instrument instead of creating new one",
                  notifier=function(value) preferences.pakettifyReplaceInstrument.value=value end
                }
              },
              vb:row{
                vb:text{text="Instrument Properties",width=150,tooltip="Control Instrument Properties panel visibility on startup and when changed",},
                vb:popup{items={"Do Nothing","Hide","Show"},tooltip="Control Instrument Properties panel visibility on startup and when changed",value=preferences.pakettiInstrumentProperties.value+1,width=100,
                  notifier=function(value) 
                    preferences.pakettiInstrumentProperties.value=(value-1)
                    -- Update the instrument properties visibility immediately
                    if renoise.API_VERSION >= 6.2 then
                      if preferences.pakettiInstrumentProperties.value == 1 then
                        renoise.app().window.instrument_properties_is_visible = false
                      elseif preferences.pakettiInstrumentProperties.value == 2 then
                        renoise.app().window.instrument_properties_is_visible = true
                      end
                      -- Mode 0 (Do Nothing) - no immediate action taken
                    end
                    local mode_names = {"Do Nothing", "Hide", "Show"}
                    renoise.app():show_status("Instrument Properties Control: " .. mode_names[value])
                  end}},

            -- Only show Disk Browser control for API version 6.2 and above
            renoise.API_VERSION >= 6.2 and 
              vb:row{
                vb:text{text="Disk Browser Control",width=150,tooltip="Automatically control Disk Browser visibility when songs are loaded"},
                vb:popup{items={"Do Nothing","Hide on Song Load","Show on Song Load"},value=preferences.paketti_auto_disk_browser_mode.value+1,width=100,tooltip="Automatically control Disk Browser visibility when songs are loaded",
                  notifier=function(value) 
                    preferences.paketti_auto_disk_browser_mode.value=(value-1)
                    local mode_names = {"Do Nothing", "Hide on Song Load", "Show on Song Load"}
                    renoise.app():show_status("Disk Browser Control: " .. mode_names[value])
                  end}}

             or vb:space{height=1},
              vb:row{
              vb:text{text="Switcharoo Auto-Grab",width=150,tooltip="Automatically grab chords from pattern when opening Paketti Switcharoo dialog"},
              vb:checkbox{
                value=preferences.pakettiSwitcharooAutoGrab.value,
                tooltip="Automatically grab chords from pattern when opening Paketti Switcharoo dialog",
                notifier=function(value) preferences.pakettiSwitcharooAutoGrab.value=value end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Oblique Strategies",width=125,tooltip="Show Oblique Strategies message on startup"},
              vb:checkbox{
                value=preferences.pakettiObliqueStrategiesOnStartup.value,
                tooltip="Show Oblique Strategies message on startup",
                notifier=function(value) preferences.pakettiObliqueStrategiesOnStartup.value=value end
              }
            },
              vb:row{
              vb:text{text="Slice StepSeq Velocity",width=150,font="bold",style="strong",tooltip="Opens the Slice Step Sequencer dialog with Velocity add-on dialog opened by default"},
              vb:checkbox{value=preferences.pakettiSliceStepSeqShowVelocity.value,tooltip="Opens the Slice Step Sequencer dialog with Velocity add-on dialog opened by default",
                notifier=function(value) preferences.pakettiSliceStepSeqShowVelocity.value=value end}},
                vb:row{vb:text{text="Create New Instrument & Loop from Selection", font="bold",style = "strong"}},
              vb:row{
                    vb:text{text="Select Newly Created",width=150},
                    vb:checkbox{
                        value = preferences.selectionNewInstrumentSelect.value,
                  notifier=function(value) 
                            preferences.selectionNewInstrumentSelect.value = value
                        end
                    },
                    vb:space{width=checkbox_spacing},
                    vb:text{text="Autoseek",width=75},
                    vb:checkbox{
                        value=preferences.selectionNewInstrumentAutoseek.value,
                        notifier=function(value) preferences.selectionNewInstrumentAutoseek.value=value end
                    },
                    vb:space{width=checkbox_spacing},
                    vb:text{text="Autofade",width=75},
                    vb:checkbox{
                        value=preferences.selectionNewInstrumentAutofade.value,
                notifier=function(value) 
                        preferences.selectionNewInstrumentAutofade.value=value 
                        end
                    }
                },
          vb:row{vb:text{text="Sample Interpolation",width=150},vb:popup{items={"None","Linear","Cubic","Sinc"},value=preferences.selectionNewInstrumentInterpolation.value,width=100,
              notifier=function(value) 
                  preferences.selectionNewInstrumentInterpolation.value = value end}
            },
                    vb:row{vb:text{text="Loop on Newly Created",width=150},
                    create_loop_mode_switch(preferences.selectionNewInstrumentLoop)},
          -- Render Settings wrapped in group
              vb:text{style="strong",font="bold",text="Render Settings"},
              vb:row{vb:text{text="Sample Rate",width=150},vb:popup{items={"22050","44100","48000","88200","96000","192000"},value=find_sample_rate_index(preferences.renderSampleRate.value),width=100,
                notifier=function(value) preferences.renderSampleRate.value=sample_rates[value] end}},
            
              vb:row{vb:text{text="Bit Depth",width=150},vb:popup{items={"16","24","32"},value=preferences.renderBitDepth.value==16 and 1 or preferences.renderBitDepth.value==24 and 2 or 3,width=100,
                notifier=function(value) preferences.renderBitDepth.value=(value==1 and 16 or value==2 and 24 or 32) end}},
            
              vb:row{vb:text{text="Interpolation",width=150},vb:popup{items={"Default","Precise"},value=preferences.renderInterpolation.value=="default" and 1 or 2,width=100,
                notifier=function(value) preferences.renderInterpolation.value=(value==1 and "default" or "precise") end}},
            
              vb:row{
                vb:text{text="Bypass Devices",width=150},
                vb:checkbox{
                  value=preferences.renderBypass.value,
                  notifier=function(value) preferences.renderBypass.value=value end
                },
                vb:space{width=checkbox_spacing},
                vb:text{text="DC Offset",width=75},
                vb:checkbox{
                  value=preferences.RenderDCOffset.value,
                  notifier=function(value) preferences.RenderDCOffset.value=value end
                }
              },
            vb:text{style="strong",font="bold",text="Experimental Render Settings"},
            vb:row{vb:text{text="Render Priority",width=150},vb:popup{items={"High","Realtime"},value=preferences.experimentalRenderPriority.value=="high" and 1 or 2,width=100,
              tooltip="High: switches to Realtime if Line Input device detected. Realtime: always uses realtime priority.",
              notifier=function(value) preferences.experimentalRenderPriority.value=(value==1 and "high" or "realtime") end}},
            vb:row{vb:text{text="Silence Multiplier",width=150},vb:popup{items={"0","1","3","7"},value=(preferences.experimentalRenderSilenceMultiplier.value==0 and 1 or preferences.experimentalRenderSilenceMultiplier.value==1 and 2 or preferences.experimentalRenderSilenceMultiplier.value==3 and 3 or 4),width=100,
              tooltip="Number of sample-length silences after playback for FX trails (0=no trails, 7=max trails).",
              notifier=function(value) preferences.experimentalRenderSilenceMultiplier.value=(value==1 and 0 or value==2 and 1 or value==3 and 3 or 7) end}},
            vb:row{
              vb:text{text="Remove Silence from End",width=150,tooltip="Automatically remove silence from the end of rendered samples using Strip Silence functionality."},
              vb:checkbox{
                value=preferences.experimentalRenderRemoveSilence.value,
              tooltip="Automatically remove silence from the end of rendered samples using Strip Silence functionality.",
                notifier=function(value) preferences.experimentalRenderRemoveSilence.value=value end
              }
            },
              vb:text{style = "strong", font = "bold", text="Rotate Sample Buffer Settings"},
            vb:row{
                vb:text{text="Fine",width=50},
                vb:slider{
                    min = 0,
                    max = 10000,
                    value = preferences.pakettiRotateSampleBufferFine.value,
                    width=90,
                    notifier=function(value)
                        value = math.floor(value)  -- Ensure integer value
                        preferences.pakettiRotateSampleBufferFine.value = value
                        fine_value_label.text = string.format("%05d", value)
                    end
                },
                fine_value_label,
                vb:space{width=20},
                vb:text{text="Coarse",width=50},
                vb:slider{
                    min = 0,
                    max = 10000,
                    value = preferences.pakettiRotateSampleBufferCoarse.value,
                    width=90,
                    notifier=function(value)
                        value = math.floor(value)  -- Ensure integer value
                        preferences.pakettiRotateSampleBufferCoarse.value = value
                        coarse_value_label.text = string.format("%05d", value)
                    end
                },
                coarse_value_label
            },
            vb:text{style="strong",font="bold",text="Strip Silence Thresholds"},
vb:row{
              vb:text{text="Strip",width=50},
              vb:slider{
      min = 0,
      max = 1,
      value = preferences.PakettiStripSilenceThreshold.value,
                  width=90,
      notifier=function(value)
                      threshold_label.text = string.format("%07.3f%%", value * 100)
          preferences.PakettiStripSilenceThreshold.value = value
          update_strip_silence_preview(value)
                  end
              },
              threshold_label,
              vb:space{width=20},
              vb:text{text="Move",width=50},
              vb:slider{
      min = 0,
      max = 1,
      value = preferences.PakettiMoveSilenceThreshold.value,
                  width=90,
      notifier=function(value)
                      begthreshold_label.text = string.format("%07.3f%%", value * 100)
          preferences.PakettiMoveSilenceThreshold.value = value
          update_move_silence_preview(value)
                  end
              },
              begthreshold_label
            },
            vb:text{style="strong",font="bold",text="Pattern Editor"},
            vb:row{
              vb:text{text="Exploded Track Naming",width=150,tooltip="Use 'C-4 InstrumentName' format for exploded tracks instead of 'C-4 Notes'"},
              vb:checkbox{
                value=preferences.pakettiExplodeTrackNaming.value,
                tooltip="Use 'C-4 InstrumentName' format for exploded tracks instead of 'C-4 Notes'",
                notifier=function(value) preferences.pakettiExplodeTrackNaming.value=value end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Wipe Exploded Track",width=150,tooltip="Delete the original track after exploding it into separate tracks by note"},
              vb:checkbox{
                value=preferences.pakettiWipeExplodedTrack.value,
                tooltip="Delete the original track after exploding it into separate tracks by note",
                notifier=function(value) preferences.pakettiWipeExplodedTrack.value=value end
              }
            },
            vb:row{
              vb:text{text="Pattern Status Monitor",width=150,tooltip="Show real-time effect/note column information in status bar"},
              vb:checkbox{
                value=preferences.pakettiPatternStatusMonitor.value,
                tooltip="Show real-time effect/note column information in status bar",
                notifier=function(value) preferences.pakettiPatternStatusMonitor.value=value end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Audition on Line Change",width=150,tooltip="Automatically audition the current line when moving cursor (API 6.2+ only)"},
              vb:checkbox{
                value=preferences.pakettiAuditionOnLineChangeEnabled.value,
                tooltip="Automatically audition the current line when moving cursor (API 6.2+ only)",
                notifier=function(value) preferences.pakettiAuditionOnLineChangeEnabled.value=value end
              }
            },
            vb:row{
              vb:text{text="Automatic Rename Track",width=150,tooltip="Automatically rename tracks based on played samples every 200ms"},
              vb:checkbox{
                value=preferences.pakettiAutomaticRenameTrack.value,
                tooltip="Automatically rename tracks based on played samples every 200ms",
                notifier=function(value) 
                  preferences.pakettiAutomaticRenameTrack.value=value
                  -- Update the automatic rename system immediately
                  if preferences.pakettiAutomaticRenameTrack.value then
                    pakettiStartAutomaticRenameTrack()
                  else
                    pakettiStopAutomaticRenameTrack()
                  end
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Select Used Instrument",width=150,tooltip="When switching tracks, automatically select the instrument used in that track (like 'Capture Nearest Instrument')"},
              vb:checkbox{
                value=preferences.PakettiSelectTrackSelectInstrument.value,
                tooltip="When switching tracks, automatically select the instrument used in that track (like 'Capture Nearest Instrument')",
                notifier=function(value) 
                  preferences.PakettiSelectTrackSelectInstrument.value=value
                end
              }
            },
            vb:row{
              vb:text{text="Frame Calculator Update",width=150,tooltip="Continuously show frame information in status bar when line changes",},
              vb:popup{items={"Off","Song to Line","Pattern to Line","Both"},tooltip="Continuously show frame information in status bar when line changes",value=preferences.pakettiFrameCalculatorLiveUpdate.value,width=100,
                notifier=function(value) 
                  preferences.pakettiFrameCalculatorLiveUpdate.value=value
                  if value == 1 then
                    pakettiFrameCalculatorStopLiveUpdate()
                  else
                    pakettiFrameCalculatorStartLiveUpdate()
                  end
                end}
            },
            vb:row{
              vb:text{text="Impulse Tracker F8",width=150,tooltip="F8 (Stop Playback) behavior"},
              vb:popup{
                items={"Do Nothing","Enable Follow","Stop Follow"},
                value=preferences.PakettiImpulseTrackerF8.value,
                width=100,
                tooltip="F8 (Stop Playback) behavior",
                notifier=function(value)
                  preferences.PakettiImpulseTrackerF8.value = value
                end
              }
            },
  

            vb:row{
              vb:text{text="Edit Mode Colouring",width=150,style="strong",font="bold"},
              vb:popup{items={"None","Selected Track","All Tracks"},value=preferences.pakettiEditMode.value,width=100,
                notifier=function(value) preferences.pakettiEditMode.value=value end}
            },
            vb:row{vb:text{width=400,style="strong",text="Enable Scope Highlight by going to Settings -> GUI -> Show Track Color Blends."} },
            vb:row{
              vb:text{text="Blend Value",width=150,tooltip="Enable Scope Highlight by going to Settings -> GUI -> Show Track Color Blends."},
              vb:slider{
                min = 0,
                max = 100,
                value = math.floor(preferences.pakettiBlendValue.value),
                width=200,
                tooltip="Enable Scope Highlight by going to Settings -> GUI -> Show Track Color Blends.",
                notifier=function(value)
                  value = math.floor(value)  -- Force integer value
                  preferences.pakettiBlendValue.value = value
                  
                  -- Update track blend in real-time if edit mode is on
                  local song=renoise.song()
                  if song and renoise.song().transport.edit_mode ~= false then
                    if renoise.song().transport.edit_mode == true then
                      -- Selected track only
                      if song.selected_track then
                        song.selected_track.color_blend = value
                      end
                    end
                  end
                  
                  -- Update the display text
                  blend_value_label.text = tostring(value)
                end
              },
              blend_value_label
            },
            vb:text{style="strong",font="bold",text="Effect Column->Automation Settings"},
            vb:row{
              vb:text{text="Format",width=150},
              vb:popup{
                items={"Lines","Points","Curves"},
                value=preferences.pakettiAutomationFormat.value,
                width=100,
                notifier=function(value) 
                  preferences.pakettiAutomationFormat.value = value
                  print("Automation format set to: " .. value)
                end
              } 
            },
            vb:row{
              vb:text{text="Retain Effect Column?",width=150},
              vb:popup{
                items={"Keep","Wipe"},
                value=preferences.pakettiAutomationWipeAfterSwitch.value and 2 or 1,
                width=100,
                notifier=function(value)
                  preferences.pakettiAutomationWipeAfterSwitch.value = (value == 2)
                end
              }
            }
          },
        },
        -- Column 2
        vb:column{
          style="group",margin=5,width=column2_width,
          -- Paketti Loader Settings wrapped in group
          vb:column{
            style="group",width="100%",--margin=10,
            
            vb:text{style="strong",font="bold",text="AutoSamplify Settings"},
            vb:row{
              vb:text{text="Enable Monitoring",width=150,tooltip="Master switch: When Off, AutoSamplify is completely disabled. When On, AutoSamplify monitors for new samples."},
              vb:checkbox{
                value=preferences.pakettiAutoSamplifyMonitoring.value,
                tooltip="Master switch: When Off, AutoSamplify is completely disabled. When On, AutoSamplify monitors for new samples.",
                notifier=function(value) 
                  preferences.pakettiAutoSamplifyMonitoring.value=value
                  preferences:save_as("preferences.xml")
                  if preferences.pakettiAutoSamplifyMonitoring.value then
                    if PakettiStartNewSampleMonitoring then
                      PakettiStartNewSampleMonitoring()
                    end
                    renoise.app():show_status("AutoSamplify Monitoring: Enabled")
                  else
                    if PakettiStopNewSampleMonitoring then
                      PakettiStopNewSampleMonitoring()
                    end
                    renoise.app():show_status("AutoSamplify Monitoring: Disabled")
                  end
                end
            },
              vb:space{width=checkbox_spacing},
              vb:text{text="Pakettify",width=150,tooltip="When On: Creates new instrument with XRNI + loader settings. When Off: Only applies sample settings and normalizes in current instrument."},
              vb:checkbox{
                value=preferences.pakettiAutoSamplifyPakettify.value,
                tooltip="When On: Creates new instrument with XRNI + loader settings. When Off: Only applies sample settings and normalizes in current instrument.",
                notifier=function(value) 
                  preferences.pakettiAutoSamplifyPakettify.value=value 
                  preferences:save_as("preferences.xml")
                  if value then
                    renoise.app():show_status("AutoSamplify Pakettify: Enabled (creates new instrument with XRNI)")
                  else
                    renoise.app():show_status("AutoSamplify Pakettify: Disabled (applies settings in current instrument)")
                  end
                end
              }
            },
            vb:text{style="strong",font="bold",text="Paketti Loader Settings"},
            vb:row{
              vb:text{text="Skip Automation Device",width=150},
              vb:checkbox{
                value=preferences.pakettiLoaderDontCreateAutomationDevice.value,
                notifier=function(value) 
                  preferences.pakettiLoaderDontCreateAutomationDevice.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Enable AHDSR Envelope",width=150},
              vb:checkbox{
                value=preferences.pakettiPitchbendLoaderEnvelope.value,
                notifier=function(value) 
                  preferences.pakettiPitchbendLoaderEnvelope.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:row{
              vb:text{text="One-Shot",width=150},
              vb:checkbox{
                value=preferences.pakettiLoaderOneshot.value,
                notifier=function(value) 
                  preferences.pakettiLoaderOneshot.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Autoseek",width=150},
              vb:checkbox{
                value=preferences.pakettiLoaderAutoseek.value,
                notifier=function(value) 
                  preferences.pakettiLoaderAutoseek.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Autofade",width=100},
              vb:checkbox{
                value=preferences.pakettiLoaderAutofade.value,
                notifier=function(value) 
                  preferences.pakettiLoaderAutofade.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:row{
              vb:text{text="Loop Release/Exit Mode",width=150},
              vb:checkbox{
                value=preferences.pakettiLoaderLoopExit.value,
                notifier=function(value) 
                  preferences.pakettiLoaderLoopExit.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Oversampling",width=150},
              vb:checkbox{
                value=preferences.pakettiLoaderOverSampling.value,
                notifier=function(value) 
                  preferences.pakettiLoaderOverSampling.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:row{
              vb:text{text="Sample Interpolation",width=150},
              vb:popup{items={"None","Linear","Cubic","Sinc"},value=preferences.pakettiLoaderInterpolation.value,width=100,
                notifier=function(value) update_interpolation_mode(value) end},
              vb:space{width=checkbox_spacing},
              vb:text{text="New Note Action(NNA) Mode",width=150},
              vb:popup{items={"Cut","Note-Off","Continue"},value=preferences.pakettiLoaderNNA.value,width=100,
                notifier=function(value) 
                  preferences.pakettiLoaderNNA.value=value 
                  preferences:save_as("preferences.xml")
                end}
            },
            vb:row{
              vb:text{text="Loop Mode",width=150},
              create_loop_mode_switch(preferences.pakettiLoaderLoopMode),
              vb:space{width=checkbox_spacing},
              vb:text{text="FilterType",width=150},
              vb:popup{
                items = filter_types,
                value = cached_filter_index,
                width=100,
                notifier=function(value)
                  preferences.pakettiLoaderFilterType.value = filter_types[value]
                  cached_filter_index = value -- Update the cached index
                  -- Removed print statements for performance
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:text{style="strong",font="bold",text="LazySlicer (Real-Time Slice)"},
            vb:row{
              vb:text{text="Sample View",width=150,tooltip="Show Original: keeps viewing the original sample while slicing. Show Newest Slice: automatically switches to newest created slice."},
              vb:popup{items={"Show Original","Show Newest Slice"},value=preferences.pakettiLazySlicerShowNewestSlice.value and 2 or 1,width=100,
                tooltip="Show Original: keeps viewing the original sample while slicing. Show Newest Slice: automatically switches to newest created slice.",
                notifier=function(value) 
                  preferences.pakettiLazySlicerShowNewestSlice.value=(value==2) 
                  preferences:save_as("preferences.xml")
                end}
            },
            vb:row{vb:text{text="Paketti Loader Settings (Drumkit Loader)", font="bold", style="strong"}},
            vb:row{
              vb:text{text="Move Beginning Silence",width=150},
              vb:checkbox{
                value=preferences.pakettiLoaderMoveSilenceToEnd.value,
                notifier=function(value) 
                  preferences.pakettiLoaderMoveSilenceToEnd.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Normalize Samples",width=125,tooltip="Automatically normalize all samples after loading (works with drag & drop too)"},
              vb:checkbox{
                value=preferences.pakettiLoaderNormalizeSamples.value,
                tooltip="Automatically normalize all samples after loading (works with drag & drop too)",
                notifier=function(value) 
                  preferences.pakettiLoaderNormalizeSamples.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Normalize Large Samples (>10MB)",width=175,tooltip="Automatically normalize samples larger than 10MB after loading"},
              vb:checkbox{
                value=preferences.pakettiLoaderNormalizeLargeSamples.value,
                tooltip="Automatically normalize samples larger than 10MB after loading",
                notifier=function(value) 
                  preferences.pakettiLoaderNormalizeLargeSamples.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:row{vb:text{text="Paketti Stem Loader Settings", font="bold", style="strong"}},
            vb:row{
              vb:text{text="Destructive Mode",width=150,tooltip="When enabled, clears all tracks and patterns before loading stems (clean slate)"},
              vb:checkbox{
                value=preferences.pakettiStemLoaderDestructive.value,
                tooltip="When enabled, clears all tracks and patterns before loading stems (clean slate)",
                notifier=function(value) 
                  preferences.pakettiStemLoaderDestructive.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Auto-Slice on Mixed Rates",width=150,tooltip="Automatically use slice-to-patterns mode when mixed sample rates are detected"},
              vb:checkbox{
                value=preferences.pakettiStemLoaderAutoSliceOnMixedRates.value,
                tooltip="Automatically use slice-to-patterns mode when mixed sample rates are detected",
                notifier=function(value) 
                  preferences.pakettiStemLoaderAutoSliceOnMixedRates.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:text{style="strong",font="bold",text="Maximum Sample Frame Size Settings (for Auto-normalization)"},
            vb:row{
                vb:text{text="Max Frame Size",width=150,tooltip="Maximum frame size for sample processing (5MB to 100MB)"},
                vb:slider{
                    min = 5000000,    -- 5MB worth of frames
                    max = 100000000,  -- 100MB worth of frames
                    value = preferences.pakettiMaxFrameSize.value,
                    width=200,
                    tooltip="Maximum frame size for sample processing (5MB to 100MB)",
                    notifier=function(value)
                        value = math.floor(value)  -- Ensure integer value
                        preferences.pakettiMaxFrameSize.value = value
                        max_frame_size_value_label.text = string.format("%.0f MB (%d frames)", value / 1000000, value)
                    end
                },
                vb:column{max_frame_size_value_label}
            },
            vb:row{vb:text{text="Default XRNI to use:",width=150},vb:textfield{text=preferences.pakettiDefaultXRNI.value:match("[^/\\]+$"),width=300,id=pakettiDefaultXRNIDisplayId,notifier=function(value) preferences.pakettiDefaultXRNI.value=value end},vb:button{text="Browse",width=100,notifier=function()
              local filePath=renoise.app():prompt_for_filename_to_read({"*.XRNI"},"Paketti Default XRNI Selector Dialog")
              if filePath and filePath~="" then
                preferences.pakettiDefaultXRNI.value=filePath
                vb.views[pakettiDefaultXRNIDisplayId].text=filePath:match("[^/\\]+$")
                -- Save preferences immediately
                preferences:save_as("preferences.xml")
              else
                renoise.app():show_status("No XRNI Instrument was selected")
              end
            end} },
            vb:row{vb:text{text="Preset Files:",width=150},vb:popup{items=presetFiles,width=300,notifier=function(value)
              local selectedFile = presetFiles[value] 
              local bundle_path = renoise.tool().bundle_path  -- Already has correct separators
              local newPath
              
              if selectedFile:match("^<") then
                newPath = bundle_path .. "Presets" .. separator .. "12st_Pitchbend.xrni"
              else
                newPath = bundle_path .. "Presets" .. separator .. selectedFile
              end
              
              -- Update both the preference value and the display
              preferences.pakettiDefaultXRNI.value = newPath
              vb.views[pakettiDefaultXRNIDisplayId].text = selectedFile
              
              -- Save preferences immediately
              preferences:save_as("preferences.xml")
            end}},
            vb:row{vb:text{text="Default Drumkit XRNI to use:",width=150},vb:textfield{text=preferences.pakettiDefaultDrumkitXRNI.value:match("[^/\\]+$"),width=300,id=pakettiDefaultDrumkitXRNIDisplayId,notifier=function(value) preferences.pakettiDefaultDrumkitXRNI.value=value end},vb:button{text="Browse",width=100,notifier=function()
              local filePath=renoise.app():prompt_for_filename_to_read({"*.XRNI"},"Paketti Default Drumkit XRNI Selector Dialog")
              if filePath and filePath~="" then
                preferences.pakettiDefaultDrumkitXRNI.value=filePath
                vb.views[pakettiDefaultDrumkitXRNIDisplayId].text=filePath:match("[^/\\]+$")
                
                -- Save preferences immediately
                preferences:save_as("preferences.xml")
              else
                renoise.app():show_status("No XRNI Drumkit Instrument was selected")
              end
            end} },
            vb:row{vb:text{text="Preset Files:",width=150},vb:popup{items=presetFiles,width=300,notifier=function(value)
              local selectedFile = presetFiles[value] 
              local bundle_path = renoise.tool().bundle_path  -- Already has correct separators
              local newPath
              
              if selectedFile:match("^<") then
                newPath = bundle_path .. "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
              else
                newPath = bundle_path .. "Presets" .. separator .. selectedFile
              end
              
              -- Update both the preference value and the display
              preferences.pakettiDefaultDrumkitXRNI.value = newPath
              vb.views[pakettiDefaultDrumkitXRNIDisplayId].text = selectedFile
              
              -- Save preferences immediately
              preferences:save_as("preferences.xml")
            end}},
            vb:text{style="strong",font="bold",text="Wipe & Slices Settings"},
            vb:row{
              vb:text{text="Slice Loop Mode",width=150},
              create_loop_mode_switch(preferences.WipeSlices.WipeSlicesLoopMode),
              vb:space{width=checkbox_spacing},
              vb:text{text="Slice Beatsync Mode",width=150},
              vb:popup{items={"Repitch","Time-Stretch (Percussion)","Time-Stretch (Texture)","Off"},value=preferences.WipeSlices.WipeSlicesBeatSyncMode.value,width=100,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesBeatSyncMode.value=value 
                  preferences:save_as("preferences.xml")
                end}
            },
            vb:row{
              vb:text{text="New Note Action(NNA) Mode",width=150},
              vb:popup{items={"Cut","Note-Off","Continue"},value=preferences.WipeSlices.WipeSlicesNNA.value,width=100,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesNNA.value=value 
                  preferences:save_as("preferences.xml")
                end},
              vb:space{width=checkbox_spacing},
              vb:text{text="Mute Group",width=150},
              vb:popup{items={"Off","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"},value=preferences.WipeSlices.WipeSlicesMuteGroup.value+1,width=100,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesMuteGroup.value=value-1 
                  preferences:save_as("preferences.xml")
                end}
            },
            vb:row{
              vb:text{text="Slice Loop Release/Exit Mode",width=150},
              vb:checkbox{
                value=preferences.WipeSlices.WipeSlicesLoopRelease.value,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesLoopRelease.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Slice Loop EndHalf",width=150},
              vb:checkbox{
                value=preferences.WipeSlices.SliceLoopMode.value,
                notifier=function(value) 
                  preferences.WipeSlices.SliceLoopMode.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:row{
              vb:text{text="Slice One-Shot",width=150},
              vb:checkbox{
                value=preferences.WipeSlices.WipeSlicesOneShot.value,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesOneShot.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Slice Autoseek",width=150},
              vb:checkbox{
                value=preferences.WipeSlices.WipeSlicesAutoseek.value,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesAutoseek.value=value 
                  preferences:save_as("preferences.xml")
                end
              },
              vb:space{width=checkbox_spacing},
              vb:text{text="Slice Autofade",width=100},
              vb:checkbox{
                value=preferences.WipeSlices.WipeSlicesAutofade.value,
                notifier=function(value) 
                  preferences.WipeSlices.WipeSlicesAutofade.value=value 
                  preferences:save_as("preferences.xml")
                end
              }
            },
      vb:row{
        vb:text{text="Dialog Close Key",width=150, style="strong",font="bold"},
        vb:popup{
          items = dialog_close_keys,
          value = table.find(dialog_close_keys, preferences.pakettiDialogClose.value) or 1,
          width=200,
          notifier=function(value)
            preferences.pakettiDialogClose.value = dialog_close_keys[value]
            preferences:save_as("preferences.xml")
          end},},
    vb:text{style="strong", font="bold", text="Preset++"},
    vb:row{
        vb:text{text="Create Track w/ Channelstrip",width=150,tooltip="Device chain file (.xrnt) to load when creating new track with channelstrip"},
        vb:popup{
            items = deviceChainFiles,
            value = currentDeviceChainIndex,
            width=200,
            id = "pakettiPresetPlusPlusDeviceChainPopup_" .. tostring(math.random(2, 30000)),
            tooltip="Device chain file (.xrnt) to load when creating new track with channelstrip",
            notifier=function(value)
                if value > 0 and value <= #deviceChainFiles then
                    local selected_file = deviceChainFiles[value]
                    if selected_file == "<None>" then
                        preferences.pakettiPresetPlusPlusDeviceChain.value = ""
                        preferences:save_as("preferences.xml")
                        renoise.app():show_status("Device chain disabled (none will be loaded)")
                        return
                    end
                    if selected_file == "<No Device Chain Files Found>" then
                        return
                    end
                    preferences.pakettiPresetPlusPlusDeviceChain.value = "DeviceChains" .. separator .. selected_file
                    preferences:save_as("preferences.xml")
                    renoise.app():show_status("Device chain updated: " .. selected_file)
                end
            end
        },
        vb:button{
            text="Browse",
            width=60,
            notifier=function()
                local filePath = renoise.app():prompt_for_filename_to_read({"*.xrnt"}, "Select Device Chain for Preset++ Channelstrip")
                if filePath and filePath ~= "" then
                    -- Store relative path from tool root
                    local tool_path = renoise.tool().bundle_path
                    if filePath:find(tool_path, 1, true) == 1 then
                        -- File is inside tool bundle, use relative path
                        local relative_path = filePath:sub(#tool_path + 1)
                        if relative_path:sub(1, 1) == separator then
                            relative_path = relative_path:sub(2)  -- Remove leading separator
                        end
                        preferences.pakettiPresetPlusPlusDeviceChain.value = relative_path
                    else
                        -- File is outside tool bundle, use absolute path
                        preferences.pakettiPresetPlusPlusDeviceChain.value = filePath
                    end
                    
                    -- Update the popup selection (refresh the dropdown)
                    local refreshedFiles = pakettiGetXRNTDeviceChainFiles()
                    vb.views["pakettiPresetPlusPlusDeviceChainPopup"].items = refreshedFiles
                    local filename = filePath:match("[^/\\]+$")
                    for i, file in ipairs(refreshedFiles) do
                        if file == filename then
                            vb.views["pakettiPresetPlusPlusDeviceChainPopup"].value = i
                            break
                        end
                    end
                    
                    preferences:save_as("preferences.xml")
                    renoise.app():show_status("Device chain updated: " .. filename)
                else
                    renoise.app():show_status("No device chain file selected")
                end
            end
        }
    },
    vb:text{style="strong", font="bold", text="Random Device Chain Loader Path"},
    vb:row{
        vb:textfield{
            text = preferences.PakettiDeviceChainPath.value,
            width=300,
            id = pakettiDeviceChainPathDisplayId,
            notifier=function(value)
                preferences.PakettiDeviceChainPath.value = value
            end
        },
        vb:button{
            text="Browse",
            width=60,
            notifier=function()
                local path = renoise.app():prompt_for_path("Select Device Chain Path")
                if path and path ~= "" then
                    preferences.PakettiDeviceChainPath.value = path
                    vb.views[pakettiDeviceChainPathDisplayId].text = path
                else
                    renoise.app():show_status("No path was selected, returning to default.")
                    preferences.PakettiDeviceChainPath.value = "." .. separator .. "DeviceChains" .. separator
                    vb.views[pakettiDeviceChainPathDisplayId].text="." .. separator .. "DeviceChains" .. separator
                end
            end
        },
        vb:button{
            text="Reset",
            width=50,
            notifier=function()
                preferences.PakettiDeviceChainPath.value = "." .. separator .. "DeviceChains" .. separator
                vb.views[pakettiDeviceChainPathDisplayId].text="." .. separator .. "DeviceChains" .. separator
            end
        },
        vb:button{text="Load Random Chain",width=100,notifier=function()
            PakettiRandomDeviceChain(preferences.PakettiDeviceChainPath.value)
        end}
    },
    vb:text{style="strong", font="bold", text="Random IR Loader Path"},
    vb:row{
        vb:textfield{
            text = preferences.PakettiIRPath.value,
            width=300,
            id = pakettiIRPathDisplayId,
            notifier=function(value)
                preferences.PakettiIRPath.value = value
            end
        },
        vb:button{
            text="Browse",
            width=60,
            notifier=function()
                local path = renoise.app():prompt_for_path("Select IR Path")
                if path and path ~= "" then
                    preferences.PakettiIRPath.value = path
                    vb.views[pakettiIRPathDisplayId].text = path
                else
                    renoise.app():show_status("No path was selected, returning to default.")
                    preferences.PakettiIRPath.value = "." .. separator .. "IR" .. separator
                    vb.views[pakettiIRPathDisplayId].text="." .. separator .. "IR" .. separator
                end
            end
        },
        vb:button{
            text="Reset",
            width=50,
            notifier=function()
                preferences.PakettiIRPath.value = "." .. separator .. "IR" .. separator
                vb.views[pakettiIRPathDisplayId].text="." .. separator .. "IR" .. separator
            end
        },
        vb:button{text="Load Random IR",width=100,notifier=function()
            PakettiRandomIR(preferences.PakettiIRPath.value)
        end}
    },
  vb:row{
    vb:text{text="Device Load Order", style="strong",font="bold",width=150},
    vb:popup{
      items={"First", "Last"},
      value=preferences.pakettiLoadOrder.value and 2 or 1,
      width=100,
      notifier=function(value) 
        preferences.pakettiLoadOrder.value = (value == 2)
        print (preferences.pakettiLoadOrder.value)
      end
    }
  },
  
            vb:row{
              vb:text{text="Device Load Behavior", style="strong",font="bold",width=150,tooltip="Controls behavior when loading VST/AU plugins and native devices"},
              vb:popup{
                items={"<nothing>", "External Editor", "Parameter Editor"},
                value=(preferences.pakettiDeviceLoadBehaviour.value == 3 and 1 or preferences.pakettiDeviceLoadBehaviour.value == 1 and 2 or 3),
                tooltip="Controls behavior when loading VST/AU plugins and native devices",
                width=100,
                notifier=function(value) 
                  -- Map UI order (1:DoNothing,2:External,3:Parameter) back to stored 1/2/3
                  if value == 1 then
                    preferences.pakettiDeviceLoadBehaviour.value = 3
                  elseif value == 2 then
                    preferences.pakettiDeviceLoadBehaviour.value = 1
                  else
                    preferences.pakettiDeviceLoadBehaviour.value = 2
                  end
                  local behavior_text = ""
                  if preferences.pakettiDeviceLoadBehaviour.value == 1 then
                    behavior_text = "Open External Editor"
                  elseif preferences.pakettiDeviceLoadBehaviour.value == 2 then
                    behavior_text = "Open Selected Parameter Dialog"
                  else
                    behavior_text = "<do nothing>"
                  end
                  print("Device Load Behavior set to: " .. behavior_text)
                end
              }
            },
            vb:row{
              vb:text{text="Load to Track Position", style="strong",font="bold",width=150,tooltip="Controls whether devices are loaded at the first (position 2) or last position when using 'Load to All Tracks'"},
              vb:popup{
                items={"First", "Last"},
                value=preferences.pakettiLoadToAllTracksPosition.value and 2 or 1,
                tooltip="Controls whether devices are loaded at the first (position 2) or last position when using 'Load to All Tracks'",
                width=100,
                notifier=function(value) 
                  preferences.pakettiLoadToAllTracksPosition.value = (value == 2)
                  local position_text = value == 2 and "last" or "first"
                  print("Load to All Tracks Position set to: " .. position_text)
                end
              }
            },
    vb:row{
      vb:text{text="LFO Write Device Delete",style="strong",font="bold",width=150},
      vb:checkbox{
        value=preferences.PakettiLFOWriteDelete.value,
        notifier=function(value)
          preferences.PakettiLFOWriteDelete.value = value
        end
      }
    },
    vb:text{text="Sample Selection Info",width=150, style="strong",font="bold"},
    vb:text{text="Shows detected note, frequency, and tuning offset in sample selection info"},
    vb:row{
      vb:text{text="Show Sample Selection",width=150},
      vb:checkbox{
        value=preferences.pakettiShowSampleDetails.value,
        notifier=function(value) 
          preferences.pakettiShowSampleDetails.value=value
          print(string.format("Show Sample Selection changed to: %s", tostring(preferences.pakettiShowSampleDetails.value)))
        end
      },
      vb:space{width=checkbox_spacing},
      vb:text{text="Include Frequency Analysis",width=175},
      vb:checkbox{
        value=preferences.pakettiShowSampleDetailsFrequencyAnalysis.value,
        notifier=function(value) 
          preferences.pakettiShowSampleDetailsFrequencyAnalysis.value=value
        end
      }
    },
    vb:row{
      vb:text{text="Frequency Analysis Cycles",width=150},
      vb:textfield{
        text=tostring(preferences.pakettiSampleDetailsCycles.value),
        width=200,
        notifier=function(value)
          local cycles = tonumber(value)
          if cycles and cycles > 0 then
            preferences.pakettiSampleDetailsCycles.value = cycles
          end
        end
      } -- frequency analysis cycles textfield
    }, -- frequency analysis cycles row
  }, --
},
      
        --},
        -- Column 3
        vb:column{
          style="group",margin=5,width=column3_width,
          vb:column{
            style="group",width="100%",--margin=10,
          vb:row{
            vb:text{style="strong",font="bold",text="Player Pro Settings",width=150},
            vb:popup{items={"Light Mode","Dark Mode"},
              value=preferences.pakettiPlayerProEffectDialogDarkMode.value and 2 or 1,
              width=100,
              notifier=function(value) 
                preferences.pakettiPlayerProEffectDialogDarkMode.value=(value==2)
                print(string.format("PlayerPro Effect Dialog mode changed to: %s", value == 2 and "Dark Mode" or "Light Mode"))
              end
            }
          },
          vb:row{
            vb:text{text="Effect Canvas Write",width=150},
            vb:checkbox{
              value=preferences.pakettiPlayerProEffectCanvasWrite.value,
              notifier=function(value)
                preferences.pakettiPlayerProEffectCanvasWrite.value = value
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Effect Canvas SubColumn",width=150},
            vb:checkbox{
              value=preferences.pakettiPlayerProEffectCanvasSubColumn.value,
              notifier=function(value)
                preferences.pakettiPlayerProEffectCanvasSubColumn.value = value
              end
            }
          },
          vb:row{
            vb:text{text="Note Canvas Write",width=150},
            vb:checkbox{
              value=preferences.pakettiPlayerProNoteCanvasWrite.value,
              notifier=function(value)
                preferences.pakettiPlayerProNoteCanvasWrite.value = value
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Note Canvas Piano Keys",width=150},
            vb:checkbox{
              value=preferences.pakettiPlayerProNoteCanvasPianoKeys.value,
              notifier=function(value)
                preferences.pakettiPlayerProNoteCanvasPianoKeys.value = value
              end
            }
          },
          vb:row{
            vb:text{text="Always Open Dialog",width=150,tooltip="Automatically opens appropriate dialog based on cursor position"},
            vb:checkbox{
              value=preferences.pakettiPlayerProAlwaysOpen.value,
              tooltip="Automatically opens appropriate dialog based on cursor position",
              notifier=function(value) 
                preferences.pakettiPlayerProAlwaysOpen.value=value
                -- Update the always open system immediately
                if preferences.pakettiPlayerProAlwaysOpen.value then
                  pakettiPlayerProStartAlwaysOpen()
                else
                  pakettiPlayerProStopAlwaysOpen()
                end
                print(string.format("PlayerPro Always Open changed to: %s", value and "On" or "Off"))
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Smart SubColumn",width=150,tooltip="Effect dialog opens when in volume/panning/delay/sample FX subcolumns"},
            vb:checkbox{
              value=preferences.pakettiPlayerProSmartSubColumn.value,
              tooltip="Effect dialog opens when in volume/panning/delay/sample FX subcolumns",
              notifier=function(value) 
                preferences.pakettiPlayerProSmartSubColumn.value=value
                print(string.format("PlayerPro Smart SubColumn changed to: %s", value and "On" or "Off"))
              end
            }
          },
          vb:row{
            vb:text{text="Auto-Hide on Frame Switch",width=150,tooltip="Automatically hide PlayerPro dialogs when switching away from Pattern Editor"},
            vb:checkbox{
              value=preferences.pakettiPlayerProAutoHideOnFrameSwitch.value,
              tooltip="Automatically hide PlayerPro dialogs when switching away from Pattern Editor",
              notifier=function(value) 
                preferences.pakettiPlayerProAutoHideOnFrameSwitch.value=value
                -- Update the middle frame observer based on the new setting
                if value then
                  pakettiPlayerProStartMiddleFrameObserver()
                else
                  pakettiPlayerProStopMiddleFrameObserver()
                end
                print(string.format("PlayerPro Auto-Hide on Frame Switch changed to: %s", value and "On" or "Off"))
              end
            }
          },
      





          vb:text{style="strong",font="bold",text="Parameter Editor"},
          vb:row{
            vb:text{text="Previous/Next",width=150,tooltip="Show Previous Track, Previous Device, Next Device, Next Track buttons"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.PreviousNext.value,
              tooltip="Show Previous Track, Previous Device, Next Device, Next Track buttons",
              notifier=function(value) 
                preferences.pakettiParameterEditor.PreviousNext.value=value
              end
            },
            vb:space{width=checkbox_spacing},
            vb:text{text="A/B",width=75,tooltip="Show Edit A/B, Edit A, Edit B and Crossfade sliders"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.AB.value,
              tooltip="Show Edit A/B, Edit A, Edit B and Crossfade sliders",
              notifier=function(value) 
                preferences.pakettiParameterEditor.AB.value=value
              end
            },
            vb:space{width=checkbox_spacing},
            vb:text{text="Automation Playmode",width=120,tooltip="Show Automation Playmode Points, Lines, Curves controls"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.AutomationPlaymode.value,
              tooltip="Show Automation Playmode Points, Lines, Curves controls",
              notifier=function(value) 
                preferences.pakettiParameterEditor.AutomationPlaymode.value=value
              end
            }
          },
          vb:row{
            vb:text{text="Randomize Strength",width=150,tooltip="Show Randomize Strength text and slider"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.RandomizeStrength.value,
              tooltip="Show Randomize Strength text and slider",
              notifier=function(value) 
                preferences.pakettiParameterEditor.RandomizeStrength.value=value
              end
            },
            vb:space{width=checkbox_spacing},
            vb:text{text="Half Size",width=75,tooltip="Make canvas 75% of original height (390px becomes ~293px)"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.HalfSize.value,
              tooltip="Make canvas 75% of original height (390px becomes ~293px)",
              notifier=function(value) 
                preferences.pakettiParameterEditor.HalfSize.value=value
              end
            },
            vb:space{width=checkbox_spacing},
            vb:text{text="Half Size Font",width=120,tooltip="On: Always use smaller text. Off: Use small text only with Half Size canvas"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.HalfSizeFont.value,
              tooltip="On: Always use smaller text. Off: Use small text only with Half Size canvas",
              notifier=function(value) 
                preferences.pakettiParameterEditor.HalfSizeFont.value=value
              end
            }
          },
          vb:row{
            vb:text{text="Auto-Open upon Selection",width=150,tooltip="Automatically open Parameter Editor when selecting ANY device (excludes ProQ-3)"},
            vb:checkbox{
              value=preferences.pakettiParameterEditor.AutoOpen.value,
              tooltip="Automatically open Parameter Editor when selecting ANY device (excludes ProQ-3)",
              notifier=function(value) 
                preferences.pakettiParameterEditor.AutoOpen.value=value
                if type(PakettiCanvasExperimentsToggleAutoOpen) == "function" then
                  if preferences.pakettiParameterEditor.AutoOpen.value then
                    if type(PakettiCanvasExperimentsSetupGlobalDeviceObserver) == "function" then
                      PakettiCanvasExperimentsSetupGlobalDeviceObserver()
                    end
                  else
                    if type(PakettiCanvasExperimentsRemoveGlobalDeviceObserver) == "function" then
                      PakettiCanvasExperimentsRemoveGlobalDeviceObserver()
                    end
                  end
                end
                local status_text = value and "enabled" or "disabled"
                renoise.app():show_status("Parameter Editor Auto-Open " .. status_text)
              end
            }
          },

          -- Create New Send Settings
          vb:text{style="strong",font="bold",text="Create New Sends"},
          vb:row{
            vb:text{text="Collapsed",width=150,tooltip="When enabled, newly created Send Tracks will be collapsed by default"},
            vb:checkbox{
              value=preferences.pakettiCreateNewSends.Collapsed.value,
              tooltip="When enabled, newly created Send Tracks will be collapsed by default",
              notifier=function(value) 
                preferences.pakettiCreateNewSends.Collapsed.value=value
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Send Naming Per Track",width=150,tooltip="When enabled, each track gets its own S01-S04 send numbering. When disabled, sends are numbered globally (S01, S02, S03...)"},
            vb:checkbox{
              value=preferences.pakettiCreateNewSends.SendNamingPerTrack.value,
              tooltip="When enabled, each track gets its own S01-S04 send numbering. When disabled, sends are numbered globally (S01, S02, S03...)",
              notifier=function(value) 
                preferences.pakettiCreateNewSends.SendNamingPerTrack.value=value
              end
            }
          },

          -- Unison Generator Settings wrapped in group

            vb:text{style="strong",font="bold",text="Unison Generator Settings"},
            vb:row{
                vb:text{text="Unison Detune",width=150,tooltip="Controls the detune range (±) used by the Unison Generator. Hard Sync: alternating ±max values. Live-updates currently selected unison instrument."},
                vb:slider{
                    min = 0,
                    max = 96,
                    value = preferences.pakettiUnisonDetune.value,
                    width=200,
                    tooltip="Controls the detune range (±) used by the Unison Generator. Hard Sync: alternating ±max values. Live-updates currently selected unison instrument.",
                    notifier=function(value)
                        value = math.floor(value)  -- Ensure integer value
                        preferences.pakettiUnisonDetune.value = value
                        unison_detune_value_label.text = tostring(value)
                        
                        -- Smart update: if current instrument is a unison instrument, update live
                        local song = renoise.song()
                        if song and song.selected_instrument and song.selected_instrument.name:find("Unison") then
                            local instrument = song.selected_instrument
                            if #instrument.samples >= 8 then
                                -- Get the original fine tune value from the first sample
                                local original_fine_tune = instrument.samples[1].fine_tune
                                
                                -- Update samples 2-8 with new detune values
                                for i = 2, 8 do
                                    local sample = instrument.samples[i]
                                    if sample then
                                        local detune_offset = 0
                                        -- Calculate detune offset based on hard sync and fluctuation settings
                                        if preferences.pakettiUnisonDetuneHardSync.value then
                                            -- Hard sync: alternating -value, +value, -value, +value...
                                            detune_offset = (i % 2 == 0) and -value or value
                                        elseif preferences.pakettiUnisonDetuneFluctuation.value then
                                            -- Random fluctuation between -value and +value
                                            detune_offset = math.random(-value, value)
                                        else
                                            -- Fixed detune values distributed evenly
                                            local detune_step = value / 4  -- Spread across 7 samples (2-8)
                                            local sample_offset = i - 5  -- Center around sample 5, so: -3,-2,-1,0,1,2,3
                                            detune_offset = math.floor(sample_offset * detune_step)
                                        end
                                        -- Apply offset to original fine tune, clamping to valid range
                                        sample.fine_tune = math.max(-127, math.min(127, original_fine_tune + detune_offset))
                                        -- Update sample name to reflect new detune value
                                        local original_name = sample.name:gsub("%s*%(Unison.*$", "")
                                        local panning_label = sample.panning == 0 and "50L" or "50R"
                                        sample.name = string.format("%s (Unison %d [%d] (%s))", original_name:gsub("%(Unison.*%)%s*", ""), i - 1, sample.fine_tune, panning_label)
                                    end
                                end
                                local mode = preferences.pakettiUnisonDetuneHardSync.value and "hard sync" or (preferences.pakettiUnisonDetuneFluctuation.value and "random" or "fixed")
                                renoise.app():show_status(string.format("Updated unison detune to ±%d (%s) for current instrument", value, mode))
                            end
                        end
                    end
                },
                unison_detune_value_label
            },
            vb:row{
                vb:text{text="Random Fluctuation",width=150},
                vb:checkbox{
                    value=preferences.pakettiUnisonDetuneFluctuation.value,
                    notifier=function(value)
                        preferences.pakettiUnisonDetuneFluctuation.value = value
                        
                        -- Smart update: if current instrument is a unison instrument, update live
                        local song = renoise.song()
                        if song and song.selected_instrument and song.selected_instrument.name:find("Unison") then
                            local instrument = song.selected_instrument
                            if #instrument.samples >= 8 then
                                local detune_value = preferences.pakettiUnisonDetune.value
                                -- Get the original fine tune value from the first sample
                                local original_fine_tune = instrument.samples[1].fine_tune
                                
                                -- Update samples 2-8 with new detune method
                                for i = 2, 8 do
                                    local sample = instrument.samples[i]
                                    if sample then
                                        local detune_offset = 0
                                        -- Calculate detune offset based on hard sync and fluctuation settings
                                        if preferences.pakettiUnisonDetuneHardSync.value then
                                            -- Hard sync: alternating -value, +value, -value, +value...
                                            detune_offset = (i % 2 == 0) and -detune_value or detune_value
                                        elseif value then
                                            -- Random fluctuation between -value and +value
                                            detune_offset = math.random(-detune_value, detune_value)
                                        else
                                            -- Fixed detune values distributed evenly
                                            local detune_step = detune_value / 4  -- Spread across 7 samples (2-8)
                                            local sample_offset = i - 5  -- Center around sample 5, so: -3,-2,-1,0,1,2,3
                                            detune_offset = math.floor(sample_offset * detune_step)
                                        end
                                        -- Apply offset to original fine tune, clamping to valid range
                                        sample.fine_tune = math.max(-127, math.min(127, original_fine_tune + detune_offset))
                                        -- Update sample name to reflect new detune value
                                        local original_name = sample.name:gsub("%s*%(Unison.*$", "")
                                        local panning_label = sample.panning == 0 and "50L" or "50R"
                                        sample.name = string.format("%s (Unison %d [%d] (%s))", original_name:gsub("%(Unison.*%)%s*", ""), i - 1, sample.fine_tune, panning_label)
                                    end
                                end
                                local mode = value and "random" or "fixed"
                                renoise.app():show_status(string.format("Switched to %s detune mode for current unison instrument", mode))
                            end
                        end
                    end
            },
                vb:space{width=checkbox_spacing},
                vb:text{text="Hard Sync",width=75},
                vb:checkbox{
                    value=preferences.pakettiUnisonDetuneHardSync.value,
                    notifier=function(value)
                        preferences.pakettiUnisonDetuneHardSync.value = value
                        
                        -- Smart update: if current instrument is a unison instrument, update live
                        local song = renoise.song()
                        if song and song.selected_instrument and song.selected_instrument.name:find("Unison") then
                            local instrument = song.selected_instrument
                            if #instrument.samples >= 8 then
                                local detune_value = preferences.pakettiUnisonDetune.value
                                -- Get the original fine tune value from the first sample
                                local original_fine_tune = instrument.samples[1].fine_tune
                                
                                -- Update samples 2-8 with new detune method
                                for i = 2, 8 do
                                    local sample = instrument.samples[i]
                                    if sample then
                                        local detune_offset = 0
                                        -- Calculate detune offset based on hard sync and fluctuation settings
                                        if value then
                                            -- Hard sync: alternating -value, +value, -value, +value...
                                            detune_offset = (i % 2 == 0) and -detune_value or detune_value
                                        elseif preferences.pakettiUnisonDetuneFluctuation.value then
                                            -- Random fluctuation between -value and +value
                                            detune_offset = math.random(-detune_value, detune_value)
                                        else
                                            -- Fixed detune values distributed evenly
                                            local detune_step = detune_value / 4  -- Spread across 7 samples (2-8)
                                            local sample_offset = i - 5  -- Center around sample 5, so: -3,-2,-1,0,1,2,3
                                            detune_offset = math.floor(sample_offset * detune_step)
                                        end
                                        -- Apply offset to original fine tune, clamping to valid range
                                        sample.fine_tune = math.max(-127, math.min(127, original_fine_tune + detune_offset))
                                        -- Update sample name to reflect new detune value
                                        local original_name = sample.name:gsub("%s*%(Unison.*$", "")
                                        local panning_label = sample.panning == 0 and "50L" or "50R"
                                        sample.name = string.format("%s (Unison %d [%d] (%s))", original_name:gsub("%(Unison.*%)%s*", ""), i - 1, sample.fine_tune, panning_label)
                                    end
                                end
                                local mode = value and "hard sync" or (preferences.pakettiUnisonDetuneFluctuation.value and "random" or "fixed")
                                renoise.app():show_status(string.format("Switched to %s detune mode for current unison instrument", mode))
                            end
                        end
                    end
            },
              vb:space{width=checkbox_spacing},
              vb:text{text="Duplicate Instrument",width=120,tooltip="Copies entire instrument (plugins, AHDSR, macros) before unison-ing."},
                vb:checkbox{
                    value=preferences.pakettiUnisonDuplicateInstrument.value,
                    tooltip="Copies entire instrument (plugins, AHDSR, macros) before unison-ing.",
                    notifier=function(value)
                        preferences.pakettiUnisonDuplicateInstrument.value = value
                    end
                },
            },
          
          vb:row{
            vb:text{text="File Menu Location",width=150,style="strong",font="bold",tooltip="Choose where File-related Paketti menu entries appear. Controls whether entries are under File directly, File:Paketti submenu, or both."},
            vb:popup{items={"File","Paketti","Both"},value=preferences.pakettiFileMenuLocationMode.value,width=100,
              tooltip="Choose where File-related Paketti menu entries appear. Controls whether entries are under File directly, File:Paketti submenu, or both.",
              notifier=function(value)
                preferences.pakettiFileMenuLocationMode.value = value
                 if type(PakettiMenuApplyFileMenuLocation) == "function" then
                   PakettiMenuApplyFileMenuLocation(value)
                 end
                local labels = {"File","Paketti","Both"}
                renoise.app():show_status("Paketti File Menu Location: " .. (labels[value] or tostring(value)))
              end}
          },

          vb:text{style="strong",font="bold",text="EQ30 Behavior"},
          vb:row{
            vb:text{text="Autofocus selected EQ10",width=150},
            vb:checkbox{
              value=preferences.PakettiEQ30Autofocus.value,
              notifier=function(value)
                preferences.PakettiEQ30Autofocus.value = value
                preferences:save_as("preferences.xml")
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Minimize EQ10 devices",width=150},
            vb:checkbox{
              value=preferences.PakettiEQ30MinimizeDevices.value,
              notifier=function(value)
                preferences.PakettiEQ30MinimizeDevices.value = value
                preferences:save_as("preferences.xml")
              end
            }
          },
          
          vb:text{style="strong",font="bold",text="HyperEdit"},
          vb:row{
            vb:text{text="Auto-Fit Rows",width=150,tooltip="Automatically expand rows to show all existing automation"},
            vb:checkbox{
              value=preferences.PakettiHyperEditAutoFit.value,
              tooltip="Automatically expand rows to show all existing automation",
              notifier=function(value)
                preferences.PakettiHyperEditAutoFit.value = value
                preferences:save_as("preferences.xml")
                local mode = value and "enabled" or "disabled"
                renoise.app():show_status("HyperEdit Auto-Fit " .. mode)
              end
            }
          },
          vb:row{
            vb:text{text="Manual Row Count",width=150,tooltip="Fixed number of rows when Auto-Fit is disabled"},
            vb:popup{items={"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32"},
              value=preferences.PakettiHyperEditManualRows.value,
              width=100,
              tooltip="Fixed number of rows when Auto-Fit is disabled",
              notifier=function(value)
                preferences.PakettiHyperEditManualRows.value = value
                preferences:save_as("preferences.xml")
                renoise.app():show_status("HyperEdit Manual Row Count set to " .. value)
              end}
          },
          
          (function()
            local panning_intensity_label = vb:text{text=tostring(preferences.PakettiGaterPanningIntensity.value) .. "%",width=50}
            return vb:row{
              vb:text{text="Paketti Gater Panning",width=150,style="strong",font="bold",tooltip="Controls panning range: 100% = full hard left/right (P00/PFF), 30% = moderate panning, 0% = center only. Live-updates current track panning."},
              vb:slider{
                min = 0,
                max = 100,
                value = preferences.PakettiGaterPanningIntensity.value,
                width=200,
                tooltip="Controls panning range: 100% = full hard left/right (P00/PFF), 30% = moderate panning, 0% = center only. Live-updates current track panning.",
                notifier=function(value)
                  value = math.floor(value)
                  local old_value = preferences.PakettiGaterPanningIntensity.value
                  preferences.PakettiGaterPanningIntensity.value = value
                  panning_intensity_label.text = tostring(value) .. "%"
                  
                  -- Live update: if current track has panning gater values, update them
                  if type(PakettiGaterUpdatePanningIntensityInPattern) == "function" then
                    PakettiGaterUpdatePanningIntensityInPattern(old_value, value)
                  end
                end
              },
              panning_intensity_label
            }
          end)(),
          
          vb:text{style="strong",font="bold",text="Groovebox 8120"},
          vb:row{
            vb:text{text="Collapse",width=150,tooltip="Default collapse state for first 8 tracks when opening Groovebox 8120"},
            vb:checkbox{
              value=preferences.PakettiGroovebox8120.Collapse.value,
              tooltip="Default collapse state for first 8 tracks when opening Groovebox 8120",
              notifier=function(value)
                preferences.PakettiGroovebox8120.Collapse.value = value
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Append Tracks & Instruments",width=150,tooltip="Safely create 8 tracks and 8 instruments when opening Groovebox 8120 for the first time"},
            vb:checkbox{
              value=preferences.PakettiGroovebox8120.AppendTracksAndInstruments.value,
              tooltip="Safely create 8 tracks and 8 instruments when opening Groovebox 8120 for the first time",
              notifier=function(value)
                preferences.PakettiGroovebox8120.AppendTracksAndInstruments.value = value
              end
            }
          },
          vb:row{
            vb:text{text="Playhead Color",width=150},
            vb:popup{
              items={"None","Orange","Purple","Black","White","Grey"},
              value=preferences.PakettiGrooveboxPlayheadColor.value,
              width=100,
              notifier=function(value)
                preferences.PakettiGrooveboxPlayheadColor.value = value
                if type(PakettiEightOneTwentyApplyPlayheadColor) == "function" then
                  PakettiEightOneTwentyApplyPlayheadColor()
                end
              end
            }
          },
          
          vb:text{style="strong",font="bold",text="MIDI Populator Settings"},
          vb:row{
            vb:text{text="Send Device Type",width=150,tooltip="Choose between Send or Multiband Send devices for Populate Sends"},
            vb:switch{
              items={"Send","Multiband Send"},
              value=preferences.pakettiMidiPopulator.sendDeviceType.value,
              width=200,
              tooltip="Choose between Send or Multiband Send devices for Populate Sends",
              notifier=function(value)
                preferences.pakettiMidiPopulator.sendDeviceType.value = value
              end
            }
          },
          vb:text{style="strong",font="bold",text="Polyend Suite Settings"},
          vb:row{
            vb:text{text="Open Slice Dialog",width=150,tooltip="Automatically open Polyend Slice Switcher dialog when loading PTI files with slices"},
            vb:checkbox{
              value=preferences.pakettiPolyendOpenDialog.value,
              tooltip="Automatically open Polyend Slice Switcher dialog when loading PTI files with slices",
              notifier=function(value) preferences.pakettiPolyendOpenDialog.value=value end
            }
          },
          
          vb:text{style="strong",font="bold",text="Large Chunk of Keyboard Shortcuts"},
          vb:row{
            vb:text{text="Jump Row Commands",width=150,tooltip="Enable 2,048 'Play at Row' keybindings and MIDI mappings (000-511). When enabled, creates 'Play at Row 000-511' commands. Warning: Significantly increases startup time."},
            vb:checkbox{
              value=preferences.PakettiJumpRowCommands.value,
              tooltip="Enable 2,048 'Play at Row' keybindings and MIDI mappings (000-511). When enabled, creates 'Play at Row 000-511' commands. Warning: Significantly increases startup time.",
              notifier=function(value)
                preferences.PakettiJumpRowCommands.value = value
                local status = value and "enabled" or "disabled"
                renoise.app():show_status("Jump Row Commands " .. status .. ".")
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Jump Forward/Backward",width=150,tooltip="Enable 1,024 'Jump Forward/Backward Within Pattern/Song' keybindings and MIDI mappings (001-128). When enabled, creates 'Jump Forward/Backward by 001-128' commands. Warning: Increases startup time."},
            vb:checkbox{
              value=preferences.PakettiJumpForwardBackwardCommands.value,
              tooltip="Enable 1,024 'Jump Forward/Backward Within Pattern/Song' keybindings and MIDI mappings (001-128). When enabled, creates 'Jump Forward/Backward by 001-128' commands. Warning: Increases startup time.",
              notifier=function(value)
                preferences.PakettiJumpForwardBackwardCommands.value = value
                local status = value and "enabled" or "disabled"
                renoise.app():show_status("Jump Forward/Backward Commands " .. status .. ".")
              end
            }
          },
          vb:row{
            vb:text{text="Trigger Pattern Line",width=150,tooltip="Enable 1,024 'Trigger Pattern Line' keybindings and MIDI mappings (001-512). When enabled, creates 'Trigger Pattern Line 001-512' commands. Default: OFF."},
            vb:checkbox{
              value=preferences.PakettiTriggerPatternLineCommands.value,
              tooltip="Enable 1,024 'Trigger Pattern Line' keybindings and MIDI mappings (001-512). When enabled, creates 'Trigger Pattern Line 001-512' commands. Default: OFF.",
              notifier=function(value)
                preferences.PakettiTriggerPatternLineCommands.value = value
                local status = value and "enabled" or "disabled"
                renoise.app():show_status("Trigger Pattern Line Commands " .. status .. ".")
              end
          },
            vb:space{width=checkbox_spacing},
            vb:text{text="Instrument Transpose",width=150,tooltip="Enable 4,338 instrument transpose controls (1,928 keybindings + 1,928 menu entries + 482 MIDI mappings). When enabled, creates all transpose controls (keybindings, menu entries, MIDI mappings). Warning: Significantly increases startup time. Default: OFF for faster startup."},
            vb:checkbox{
              value=preferences.PakettiInstrumentTransposeCommands.value,
              tooltip="Enable 4,338 instrument transpose controls (1,928 keybindings + 1,928 menu entries + 482 MIDI mappings). When enabled, creates all transpose controls (keybindings, menu entries, MIDI mappings). Warning: Significantly increases startup time. Default: OFF for faster startup.",
              notifier=function(value)
                preferences.PakettiInstrumentTransposeCommands.value = value
                local status = value and "enabled" or "disabled"
                renoise.app():show_status("Instrument Transpose Commands " .. status .. ".")
              end
            }
          },
          vb:row{
            vb:text{text="Play & Loop Pattern",width=150,tooltip="Enable 192 Play & Loop Pattern controls (64 MIDI mappings + 64 Pattern Editor keybindings + 64 Global keybindings). When enabled, creates 'Play & Loop Pattern 01-64' commands. Default: ON."},
            vb:checkbox{
              value=preferences.PakettiPlayAndLoopPatternCommands.value,
              tooltip="Enable 192 Play & Loop Pattern controls (64 MIDI mappings + 64 Pattern Editor keybindings + 64 Global keybindings). When enabled, creates 'Play & Loop Pattern 01-64' commands. Default: ON.",
              notifier=function(value)
                preferences.PakettiPlayAndLoopPatternCommands.value = value
                local status = value and "enabled" or "disabled"
                renoise.app():show_status("Play & Loop Pattern Commands " .. status .. ".")
              end
            }
          },

        }
        }
      },
      
      vb:row{
        vb:text{text="Goodies",width=150,style="strong",font="bold"},
        vb:button{text="Load Pale Green Theme",width=150,notifier=function() update_loadPaleGreenTheme_preferences() end},
        vb:button{text="Load Plaid Zap .XRNI",width=125,notifier=function() renoise.app():load_instrument("Gifts/plaidzap.xrni") end},
        vb:button{text="Load 200 Drum Machines (.zip)",width=150,notifier=function() 
        renoise.app():open_url("http://www.hexawe.net/mess/200.Drum.Machines/") end}
        },



      
      vb:horizontal_aligner{mode="distribute",
        vb:button{text="Open Dialog of Dialogs",width="33%",notifier=function() 
          pakettiDialogOfDialogsToggle() 
        end},
        vb:button{text="OK",width="33%",notifier=function() 
          preferences:save_as("preferences.xml")
          dialog:close() 
        end},
        vb:button{text="Cancel",width="33%",notifier=function() dialog:close() end}
      }
    }
    
    
    -- Create simple keyhandler for preferences dialog
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    
    -- Preferences dialog restored to stable layout (dynamic filtering disabled due to ViewBuilder limitations)
    
    dialog = renoise.app():show_custom_dialog("Paketti Preferences", dialog_content, keyhandler)
    
    -- Set focus to Renoise after dialog opens for key capture
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Global counters for registrations (populated during startup)
PakettiRegistrationCounts = {
  menus = 0,
  menus_enabled = 0,
  menus_disabled = 0,
  keybindings = 0,
  keybindings_enabled = 0,
  keybindings_disabled = 0,
  midi_mappings = 0,
  midi_mappings_enabled = 0,
  midi_mappings_disabled = 0
}

-- Function to count registrations by scanning source files
function PakettiCountRegistrations()
  local bundle_path = renoise.tool().bundle_path
  local counts = {
    menus = 0,
    menus_commented = 0,
    keybindings = 0,
    keybindings_commented = 0,
    midi_mappings = 0,
    midi_mappings_commented = 0
  }
  
  -- Get all .lua files using the global helper function
  local lua_files = PakettiGetAllLuaFiles()
  
  for _, lua_file in ipairs(lua_files) do
    local file_path = bundle_path .. lua_file .. ".lua"
    local file = io.open(file_path, "r")
    
    if file then
      for line in file:lines() do
        -- Trim leading whitespace for checking
        local trimmed = line:match("^%s*(.-)%s*$")
        local is_commented = trimmed:match("^%-%-") ~= nil
        
        -- Count add_menu_entry
        if line:match("add_menu_entry") then
          if is_commented then
            counts.menus_commented = counts.menus_commented + 1
          else
            counts.menus = counts.menus + 1
          end
        end
        
        -- Count add_keybinding
        if line:match("add_keybinding") then
          if is_commented then
            counts.keybindings_commented = counts.keybindings_commented + 1
          else
            counts.keybindings = counts.keybindings + 1
          end
        end
        
        -- Count add_midi_mapping
        if line:match("add_midi_mapping") then
          if is_commented then
            counts.midi_mappings_commented = counts.midi_mappings_commented + 1
          else
            counts.midi_mappings = counts.midi_mappings + 1
          end
        end
      end
      file:close()
    end
  end
  
  return counts
end

-- Function to calculate enabled/disabled counts based on preferences
function PakettiCalculateEnabledCounts()
  local counts = PakettiCountRegistrations()
  
  -- Calculate enabled menus based on category preferences
  local menu_categories_enabled = 0
  local menu_categories_total = 17 -- Total number of menu categories
  
  local category_keys = {
    "InstrumentBox", "SampleEditor", "SampleNavigator", "SampleKeyzone",
    "Mixer", "PatternEditor", "MainMenuTools", "MainMenuView", "MainMenuFile",
    "PatternMatrix", "PatternSequencer", "PhraseEditor", "PakettiGadgets",
    "TrackDSPChain", "TrackDSPDevice", "Automation", "DiskBrowserFiles"
  }
  
  for _, key in ipairs(category_keys) do
    if preferences.pakettiMenuConfig[key] and preferences.pakettiMenuConfig[key].value then
      menu_categories_enabled = menu_categories_enabled + 1
    end
  end
  
  -- Store counts
  PakettiRegistrationCounts.menus = counts.menus
  PakettiRegistrationCounts.keybindings = counts.keybindings
  PakettiRegistrationCounts.midi_mappings = counts.midi_mappings
  
  -- For master toggles
  if preferences.pakettiMenuConfig.MasterMenusEnabled and preferences.pakettiMenuConfig.MasterMenusEnabled.value then
    PakettiRegistrationCounts.menus_enabled = counts.menus
    PakettiRegistrationCounts.menus_disabled = 0
  else
    PakettiRegistrationCounts.menus_enabled = 0
    PakettiRegistrationCounts.menus_disabled = counts.menus
  end
  
  if preferences.pakettiMenuConfig.MasterKeybindingsEnabled and preferences.pakettiMenuConfig.MasterKeybindingsEnabled.value then
    PakettiRegistrationCounts.keybindings_enabled = counts.keybindings
    PakettiRegistrationCounts.keybindings_disabled = 0
  else
    PakettiRegistrationCounts.keybindings_enabled = 0
    PakettiRegistrationCounts.keybindings_disabled = counts.keybindings
  end
  
  if preferences.pakettiMenuConfig.MasterMidiMappingsEnabled and preferences.pakettiMenuConfig.MasterMidiMappingsEnabled.value then
    PakettiRegistrationCounts.midi_mappings_enabled = counts.midi_mappings
    PakettiRegistrationCounts.midi_mappings_disabled = 0
  else
    PakettiRegistrationCounts.midi_mappings_enabled = 0
    PakettiRegistrationCounts.midi_mappings_disabled = counts.midi_mappings
  end
  
  return PakettiRegistrationCounts
end

local menu_config_dialog = nil
local menu_config_dialog_content = nil

function pakettiMenuConfigDialog()
  if menu_config_dialog and menu_config_dialog.visible then
    menu_config_dialog_content = nil
    menu_config_dialog:close()
    return
  end

  local function create_menu_checkbox(label, preference_key, update_function, width)
    return vb:row{
      vb:checkbox{
        value = preferences.pakettiMenuConfig[preference_key].value,
        notifier = function(value)
          preferences.pakettiMenuConfig[preference_key].value = value
          preferences:save_as("preferences.xml")
          if update_function and type(update_function) == "function" then
            update_function(value)
          end
        end
      },
      vb:text{text = label, width = width or 200}
    }
  end

  menu_config_dialog_content = vb:column{
    create_menu_checkbox("Instrument Box Menus", "InstrumentBox", PakettiMenuApplyInstrumentBoxMenus, 250),
    create_menu_checkbox("Sample Editor Menus", "SampleEditor", PakettiMenuApplySampleEditorMenus, 250),
    create_menu_checkbox("Sample Navigator Menus", "SampleNavigator", PakettiMenuApplySampleNavigatorMenus, 250),
    create_menu_checkbox("Sample Keyzone Menus", "SampleKeyzone", PakettiMenuApplySampleKeyzoneMenus, 250),
    create_menu_checkbox("Mixer Menus", "Mixer", PakettiMenuApplyMixerMenus, 250),
    create_menu_checkbox("Pattern Editor Menus", "PatternEditor", PakettiMenuApplyPatternEditorMenus, 250),
    create_menu_checkbox("Main Menu: Tools", "MainMenuTools", nil, 250),
    create_menu_checkbox("Main Menu: View", "MainMenuView", nil, 250),
    create_menu_checkbox("Main Menu: File", "MainMenuFile", nil, 250),
    create_menu_checkbox("Pattern Matrix Menus", "PatternMatrix", PakettiMenuApplyPatternMatrixMenus, 250),
    create_menu_checkbox("Pattern Sequencer Menus", "PatternSequencer", PakettiMenuApplyPatternSequencerMenus, 250),
    create_menu_checkbox("Phrase Editor Menus", "PhraseEditor", PakettiMenuApplyPhraseEditorMenus, 250),
    create_menu_checkbox("Paketti Gadgets Menus", "PakettiGadgets", nil, 250),
    create_menu_checkbox("Track DSP Device Menus", "TrackDSPDevice", PakettiMenuApplyTrackDSPDeviceMenus, 250),
    create_menu_checkbox("Automation Menus", "Automation", PakettiMenuApplyAutomationMenus, 250),
    create_menu_checkbox("Disk Browser Files Menus", "DiskBrowserFiles", PakettiMenuApplyDiskBrowserFilesMenus, 250)
  }

  menu_config_dialog = renoise.app():show_custom_dialog("Paketti Menu Configuration",menu_config_dialog_content,my_keyhandler_func)
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Paketti Toggler Dialog - comprehensive registration management
local paketti_toggler_dialog = nil
local paketti_toggler_dialog_content = nil

function PakettiTogglerDialog()
  if paketti_toggler_dialog and paketti_toggler_dialog.visible then
    paketti_toggler_dialog_content = nil
    paketti_toggler_dialog:close()
    paketti_toggler_dialog = nil
    return
  end

  -- Calculate current counts
  local counts = PakettiCalculateEnabledCounts()
  local raw_counts = PakettiCountRegistrations()
  
  local function create_master_checkbox(label, preference_key, width)
    return vb:row{
      vb:checkbox{
        value = preferences.pakettiMenuConfig[preference_key].value,
        notifier = function(value)
          preferences.pakettiMenuConfig[preference_key].value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:text{text = label, width = width or 250, font = "bold"}
    }
  end

  local function create_category_checkbox(label, preference_key, update_function, width)
    return vb:row{
      vb:checkbox{
        value = preferences.pakettiMenuConfig[preference_key].value,
        notifier = function(value)
          preferences.pakettiMenuConfig[preference_key].value = value
          preferences:save_as("preferences.xml")
          if update_function and type(update_function) == "function" then
            update_function(value)
          end
        end
      },
      vb:text{text = label, width = width or 200}
    }
  end

  local function enable_all_menus()
    local category_keys = {
      "InstrumentBox", "SampleEditor", "SampleNavigator", "SampleKeyzone",
      "Mixer", "PatternEditor", "MainMenuTools", "MainMenuView", "MainMenuFile",
      "PatternMatrix", "PatternSequencer", "PhraseEditor", "PakettiGadgets",
      "TrackDSPChain", "TrackDSPDevice", "Automation", "DiskBrowserFiles"
    }
    for _, key in ipairs(category_keys) do
      if preferences.pakettiMenuConfig[key] then
        preferences.pakettiMenuConfig[key].value = true
      end
    end
    preferences.pakettiMenuConfig.MasterMenusEnabled.value = true
    preferences:save_as("preferences.xml")
    renoise.app():show_status("All menus enabled. Restart Renoise for changes to take effect.")
  end

  local function disable_all_menus()
    local category_keys = {
      "InstrumentBox", "SampleEditor", "SampleNavigator", "SampleKeyzone",
      "Mixer", "PatternEditor", "MainMenuTools", "MainMenuView", "MainMenuFile",
      "PatternMatrix", "PatternSequencer", "PhraseEditor", "PakettiGadgets",
      "TrackDSPChain", "TrackDSPDevice", "Automation", "DiskBrowserFiles"
    }
    for _, key in ipairs(category_keys) do
      if preferences.pakettiMenuConfig[key] then
        preferences.pakettiMenuConfig[key].value = false
      end
    end
    preferences.pakettiMenuConfig.MasterMenusEnabled.value = false
    preferences:save_as("preferences.xml")
    renoise.app():show_status("All menus disabled. Restart Renoise for changes to take effect.")
  end

  local function enable_all_registrations()
    preferences.pakettiMenuConfig.MasterMenusEnabled.value = true
    preferences.pakettiMenuConfig.MasterKeybindingsEnabled.value = true
    preferences.pakettiMenuConfig.MasterMidiMappingsEnabled.value = true
    local category_keys = {
      "InstrumentBox", "SampleEditor", "SampleNavigator", "SampleKeyzone",
      "Mixer", "PatternEditor", "MainMenuTools", "MainMenuView", "MainMenuFile",
      "PatternMatrix", "PatternSequencer", "PhraseEditor", "PakettiGadgets",
      "TrackDSPChain", "TrackDSPDevice", "Automation", "DiskBrowserFiles"
    }
    for _, key in ipairs(category_keys) do
      if preferences.pakettiMenuConfig[key] then
        preferences.pakettiMenuConfig[key].value = true
      end
    end
    preferences:save_as("preferences.xml")
    renoise.app():show_status("All registrations enabled. Restart Renoise for changes to take effect.")
  end

  local function disable_all_registrations()
    preferences.pakettiMenuConfig.MasterMenusEnabled.value = false
    preferences.pakettiMenuConfig.MasterKeybindingsEnabled.value = false
    preferences.pakettiMenuConfig.MasterMidiMappingsEnabled.value = false
    local category_keys = {
      "InstrumentBox", "SampleEditor", "SampleNavigator", "SampleKeyzone",
      "Mixer", "PatternEditor", "MainMenuTools", "MainMenuView", "MainMenuFile",
      "PatternMatrix", "PatternSequencer", "PhraseEditor", "PakettiGadgets",
      "TrackDSPChain", "TrackDSPDevice", "Automation", "DiskBrowserFiles"
    }
    for _, key in ipairs(category_keys) do
      if preferences.pakettiMenuConfig[key] then
        preferences.pakettiMenuConfig[key].value = false
      end
    end
    preferences:save_as("preferences.xml")
    renoise.app():show_status("All registrations disabled. Restart Renoise for changes to take effect.")
  end

  paketti_toggler_dialog_content = vb:column{
    margin = 10,
    spacing = 5,
    
    -- Header
    vb:text{
      text = "Paketti Registration Manager",
      font = "big",
      style = "strong"
    },
    
    vb:space{height = 5},
    
    -- Counts summary
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "Registration Counts (from source files):", font = "bold"},
      vb:space{height = 3},
      vb:text{text = string.format("Menu Entries: %d total", raw_counts.menus)},
      vb:text{text = string.format("Keybindings: %d total", raw_counts.keybindings)},
      vb:text{text = string.format("MIDI Mappings: %d total", raw_counts.midi_mappings)},
      vb:space{height = 3},
      vb:text{text = string.format("(Commented out: Menus=%d, Keys=%d, MIDI=%d)", 
        raw_counts.menus_commented, raw_counts.keybindings_commented, raw_counts.midi_mappings_commented),
        font = "italic"
      }
    },
    
    vb:space{height = 10},
    
    -- Master toggles section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "Master Toggles (require Renoise restart):", font = "bold"},
      vb:space{height = 5},
      create_master_checkbox("Enable ALL Menu Entries", "MasterMenusEnabled", 250),
      create_master_checkbox("Enable ALL Keybindings", "MasterKeybindingsEnabled", 250),
      create_master_checkbox("Enable ALL MIDI Mappings", "MasterMidiMappingsEnabled", 250),
      
      vb:space{height = 5},
      
      vb:horizontal_aligner{
        mode = "justify",
        vb:button{
          text = "Enable All",
          width = 100,
          notifier = enable_all_registrations
        },
        vb:button{
          text = "Disable All",
          width = 100,
          notifier = disable_all_registrations
        }
      }
    },
    
    vb:space{height = 10},
    
    -- Menu categories section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "Menu Categories (require Renoise restart):", font = "bold"},
      vb:space{height = 5},
      
      vb:row{
        spacing = 20,
        
        -- Column 1
        vb:column{
          create_category_checkbox("Instrument Box", "InstrumentBox", PakettiMenuApplyInstrumentBoxMenus, 150),
          create_category_checkbox("Sample Editor", "SampleEditor", PakettiMenuApplySampleEditorMenus, 150),
          create_category_checkbox("Sample Navigator", "SampleNavigator", PakettiMenuApplySampleNavigatorMenus, 150),
          create_category_checkbox("Sample Keyzone", "SampleKeyzone", PakettiMenuApplySampleKeyzoneMenus, 150),
          create_category_checkbox("Mixer", "Mixer", PakettiMenuApplyMixerMenus, 150),
          create_category_checkbox("Pattern Editor", "PatternEditor", PakettiMenuApplyPatternEditorMenus, 150)
        },
        
        -- Column 2
        vb:column{
          create_category_checkbox("Main Menu: Tools", "MainMenuTools", nil, 150),
          create_category_checkbox("Main Menu: View", "MainMenuView", nil, 150),
          create_category_checkbox("Main Menu: File", "MainMenuFile", nil, 150),
          create_category_checkbox("Pattern Matrix", "PatternMatrix", PakettiMenuApplyPatternMatrixMenus, 150),
          create_category_checkbox("Pattern Sequencer", "PatternSequencer", PakettiMenuApplyPatternSequencerMenus, 150),
          create_category_checkbox("Phrase Editor", "PhraseEditor", PakettiMenuApplyPhraseEditorMenus, 150)
        },
        
        -- Column 3
        vb:column{
          create_category_checkbox("Paketti Gadgets", "PakettiGadgets", nil, 150),
          create_category_checkbox("Track DSP Device", "TrackDSPDevice", PakettiMenuApplyTrackDSPDeviceMenus, 150),
          create_category_checkbox("Track DSP Chain", "TrackDSPChain", nil, 150),
          create_category_checkbox("Automation", "Automation", PakettiMenuApplyAutomationMenus, 150),
          create_category_checkbox("Disk Browser Files", "DiskBrowserFiles", PakettiMenuApplyDiskBrowserFilesMenus, 150)
        }
      },
      
      vb:space{height = 5},
      
      vb:horizontal_aligner{
        mode = "justify",
        vb:button{
          text = "Enable All Menus",
          width = 120,
          notifier = enable_all_menus
        },
        vb:button{
          text = "Disable All Menus",
          width = 120,
          notifier = disable_all_menus
        }
      }
    },
    
    vb:space{height = 10},
    
    -- Import Hooks section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "Import Hooks (require Renoise restart):", font = "bold"},
      vb:space{height = 5},
      
      -- Master toggle
      vb:row{
        vb:checkbox{
          value = preferences.pakettiImportHooksEnabled.value,
          notifier = function(value)
            preferences.pakettiImportHooksEnabled.value = value
            preferences:save_as("preferences.xml")
          end
        },
        vb:text{text = "Enable ALL Import Hooks (Master)", width = 250, font = "bold"}
      },
      
      vb:space{height = 5},
      
      vb:row{
        spacing = 20,
        -- Column 1
        vb:column{
          vb:row{vb:checkbox{value = preferences.pakettiImportREX.value, notifier = function(v) preferences.pakettiImportREX.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "REX (.rex)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportRX2.value, notifier = function(v) preferences.pakettiImportRX2.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "RX2 (.rx2)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportIFF.value, notifier = function(v) preferences.pakettiImportIFF.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "IFF (.iff, .8svx)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportSF2.value, notifier = function(v) preferences.pakettiImportSF2.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "SF2 (.sf2)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportITI.value, notifier = function(v) preferences.pakettiImportITI.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "ITI (.iti)", width = 140}}
        },
        -- Column 2
        vb:column{
          vb:row{vb:checkbox{value = preferences.pakettiImportOT.value, notifier = function(v) preferences.pakettiImportOT.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "OT (.ot)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportWT.value, notifier = function(v) preferences.pakettiImportWT.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "WT (.wt)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportSTRD.value, notifier = function(v) preferences.pakettiImportSTRD.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "STRD (.strd, .work)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportPTI.value, notifier = function(v) preferences.pakettiImportPTI.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "PTI/MTI (.pti, .mti)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportMTP.value, notifier = function(v) preferences.pakettiImportMTP.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "MTP/MT (.mtp, .mt)", width = 140}}
        },
        -- Column 3
        vb:column{
          vb:row{vb:checkbox{value = preferences.pakettiImportMID.value, notifier = function(v) preferences.pakettiImportMID.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "MIDI (.mid)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportTXT.value, notifier = function(v) preferences.pakettiImportTXT.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "TXT (.txt)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportImage.value, notifier = function(v) preferences.pakettiImportImage.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "Image (.png, .jpg...)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportCSV.value, notifier = function(v) preferences.pakettiImportCSV.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "CSV (.csv)", width = 140}},
          vb:row{vb:checkbox{value = preferences.pakettiImportEXE.value, notifier = function(v) preferences.pakettiImportEXE.value = v preferences:save_as("preferences.xml") end}, vb:text{text = "Raw (.exe, .dll...)", width = 140}}
        }
      },
      
      vb:space{height = 5},
      
      vb:horizontal_aligner{
        mode = "justify",
        vb:button{
          text = "Enable All Hooks",
          width = 120,
          notifier = function()
            preferences.pakettiImportHooksEnabled.value = true
            preferences.pakettiImportREX.value = true
            preferences.pakettiImportRX2.value = true
            preferences.pakettiImportIFF.value = true
            preferences.pakettiImportSF2.value = true
            preferences.pakettiImportITI.value = true
            preferences.pakettiImportOT.value = true
            preferences.pakettiImportWT.value = true
            preferences.pakettiImportSTRD.value = true
            preferences.pakettiImportPTI.value = true
            preferences.pakettiImportMTP.value = true
            preferences.pakettiImportMID.value = true
            preferences.pakettiImportTXT.value = true
            preferences.pakettiImportImage.value = true
            preferences.pakettiImportCSV.value = true
            preferences.pakettiImportEXE.value = true
            preferences:save_as("preferences.xml")
            renoise.app():show_status("All import hooks enabled. Restart Renoise for changes to take effect.")
            -- Refresh dialog
            if paketti_toggler_dialog then
              paketti_toggler_dialog:close()
              paketti_toggler_dialog = nil
              paketti_toggler_dialog_content = nil
            end
            PakettiTogglerDialog()
          end
        },
        vb:button{
          text = "Disable All Hooks",
          width = 120,
          notifier = function()
            preferences.pakettiImportHooksEnabled.value = false
            preferences.pakettiImportREX.value = false
            preferences.pakettiImportRX2.value = false
            preferences.pakettiImportIFF.value = false
            preferences.pakettiImportSF2.value = false
            preferences.pakettiImportITI.value = false
            preferences.pakettiImportOT.value = false
            preferences.pakettiImportWT.value = false
            preferences.pakettiImportSTRD.value = false
            preferences.pakettiImportPTI.value = false
            preferences.pakettiImportMTP.value = false
            preferences.pakettiImportMID.value = false
            preferences.pakettiImportTXT.value = false
            preferences.pakettiImportImage.value = false
            preferences.pakettiImportCSV.value = false
            preferences.pakettiImportEXE.value = false
            preferences:save_as("preferences.xml")
            renoise.app():show_status("All import hooks disabled. Restart Renoise for changes to take effect.")
            -- Refresh dialog
            if paketti_toggler_dialog then
              paketti_toggler_dialog:close()
              paketti_toggler_dialog = nil
              paketti_toggler_dialog_content = nil
            end
            PakettiTogglerDialog()
          end
        }
      }
    },
    
    vb:space{height = 10},
    
    -- Warning text
    vb:text{
      text = "Note: Changes to registration toggles require Renoise restart to take effect.",
      font = "italic",
      style = "disabled"
    },
    
    vb:space{height = 10},
    
    -- Buttons
    vb:horizontal_aligner{
      mode = "center",
      spacing = 10,
      
      vb:button{
        text = "Refresh Counts",
        width = 100,
        notifier = function()
          -- Close and reopen dialog to refresh
          if paketti_toggler_dialog then
            paketti_toggler_dialog:close()
            paketti_toggler_dialog = nil
            paketti_toggler_dialog_content = nil
          end
          PakettiTogglerDialog()
        end
      },
      
      vb:button{
        text = "Close",
        width = 100,
        notifier = function()
          if paketti_toggler_dialog then
            paketti_toggler_dialog:close()
            paketti_toggler_dialog = nil
            paketti_toggler_dialog_content = nil
          end
        end
      }
    }
  }

  -- Create keyhandler
  local keyhandler = function(dialog, key)
    local closer = preferences.pakettiDialogClose.value
    if key.modifiers == "" and key.name == closer then
      dialog:close()
      paketti_toggler_dialog = nil
      paketti_toggler_dialog_content = nil
      return nil
    end
    return key
  end

  paketti_toggler_dialog = renoise.app():show_custom_dialog("Paketti Toggler", paketti_toggler_dialog_content, keyhandler)
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Add menu entries and keybindings for Paketti Toggler
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:!Preferences:Paketti Toggler...", invoke = PakettiTogglerDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Toggler...", invoke = PakettiTogglerDialog}

function on_sample_count_change()
    if not preferences._0G01_Loader.value then return end
    local song=renoise.song()
    if not song or #song.tracks == 0 or song.selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end

    local selected_track_index = song.selected_track_index
    local new_track_idx = selected_track_index + 1

    song:insert_track_at(new_track_idx)
    local line = song.patterns[song.selected_pattern_index].tracks[new_track_idx]:line(1)
    song.selected_track_index = new_track_idx
    line.note_columns[1].note_string = "C-4"
    line.note_columns[1].instrument_value = song.selected_instrument_index - 1
    line.effect_columns[1].number_string = "0G"
    line.effect_columns[1].amount_value = 01
end

function manage_sample_count_observer(attach)
    local song=renoise.song()
    local instr = song.selected_instrument
    if attach then
        if not instr.samples_observable:has_notifier(on_sample_count_change) then
            instr.samples_observable:add_notifier(on_sample_count_change)
        end
    else
        if instr.samples_observable:has_notifier(on_sample_count_change) then
            instr.samples_observable:remove_notifier(on_sample_count_change)
        end
    end
end

function Paketti0G01LoaderToggle()
    preferences._0G01_Loader.value = not preferences._0G01_Loader.value
    manage_sample_count_observer(preferences._0G01_Loader.value)
    renoise.app():show_status("0G01 Loader: " .. (preferences._0G01_Loader.value and "Enabled" or "Disabled"))
end

-- Update File vs File:Paketti menu entry visibility/location based on preference
-- moved to PakettiMenuConfig.lua as a global

-- Track if initialization has run
local initialize_tool_has_run = false

function initialize_tool()
    -- Only run once, then remove self from idle observable
    if initialize_tool_has_run then
        -- Remove self from idle observable if still attached
        if renoise.tool().app_idle_observable:has_notifier(initialize_tool) then
            renoise.tool().app_idle_observable:remove_notifier(initialize_tool)
        end
        return
    end
    
    -- Check if song is available yet
    if not pcall(renoise.song) then
        return  -- Song not ready yet, wait for next idle tick
    end
    
    -- Run initialization
    manage_sample_count_observer(preferences._0G01_Loader.value)
    pakettiFrameCalculatorInitializeLiveUpdate()
    
    -- Mark as done and remove self from idle observable
    initialize_tool_has_run = true
    if renoise.tool().app_idle_observable:has_notifier(initialize_tool) then
        renoise.tool().app_idle_observable:remove_notifier(initialize_tool)
    end
end

function safe_initialize()
    if not renoise.tool().app_idle_observable:has_notifier(initialize_tool) then
        renoise.tool().app_idle_observable:add_notifier(initialize_tool)
    end
    load_Pakettipreferences()
    initialize_filter_index() -- Ensure the filter index is initialized
end

function load_Pakettipreferences()
    if io.exists("preferences.xml") then 
        preferences:load_from("preferences.xml")
        local bundle_path = renoise.tool().bundle_path
        
        -- Always ensure full paths for XRNI files
        if not preferences.pakettiDefaultXRNI.value:match("^" .. bundle_path) then
            -- If it's a relative path or just filename, reconstruct the full path
            local filename = preferences.pakettiDefaultXRNI.value:match("[^/\\]+$") or "12st_Pitchbend.xrni"
            preferences.pakettiDefaultXRNI.value = bundle_path .. "Presets/" .. filename
        end
        
        if not preferences.pakettiDefaultDrumkitXRNI.value:match("^" .. bundle_path) then
            -- If it's a relative path or just filename, reconstruct the full path
            local filename = preferences.pakettiDefaultDrumkitXRNI.value:match("[^/\\]+$") or "12st_Pitchbend_Drumkit_C0.xrni"
            preferences.pakettiDefaultDrumkitXRNI.value = bundle_path .. "Presets/" .. filename
        end
        
        -- Save the corrected paths immediately
        preferences:save_as("preferences.xml")
    end
end

function update_loadPaleGreenTheme_preferences() renoise.app():load_theme("Themes/Lackluster - Pale Green Renoise Theme.xrnc") end

-- Function to check if sample editor is visible
function isSampleEditorVisible()
  return renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- ============================================================================
-- HELPER FUNCTIONS FOR CONDITIONAL REGISTRATION
-- These allow modules to check master toggles before registering
-- ============================================================================

-- Check if keybindings should be registered
function PakettiShouldRegisterKeybindings()
  if preferences and preferences.pakettiMenuConfig and preferences.pakettiMenuConfig.MasterKeybindingsEnabled then
    return preferences.pakettiMenuConfig.MasterKeybindingsEnabled.value
  end
  return true -- Default to enabled if preferences not loaded yet
end

-- Check if MIDI mappings should be registered
function PakettiShouldRegisterMidiMappings()
  if preferences and preferences.pakettiMenuConfig and preferences.pakettiMenuConfig.MasterMidiMappingsEnabled then
    return preferences.pakettiMenuConfig.MasterMidiMappingsEnabled.value
  end
  return true -- Default to enabled if preferences not loaded yet
end

-- Check if menu entries should be registered
function PakettiShouldRegisterMenus()
  if preferences and preferences.pakettiMenuConfig and preferences.pakettiMenuConfig.MasterMenusEnabled then
    return preferences.pakettiMenuConfig.MasterMenusEnabled.value
  end
  return true -- Default to enabled if preferences not loaded yet
end

-- Helper function to conditionally add keybinding
-- Usage: PakettiAddKeybinding{name="...", invoke=function() end}
function PakettiAddKeybinding(args)
  if PakettiShouldRegisterKeybindings() then
    renoise.tool():add_keybinding(args)
    return true
  end
  return false
end

-- Helper function to conditionally add MIDI mapping  
-- Usage: PakettiAddMidiMapping{name="...", invoke=function(message) end}
function PakettiAddMidiMapping(args)
  if PakettiShouldRegisterMidiMappings() then
    renoise.tool():add_midi_mapping(args)
    return true
  end
  return false
end

-- Helper function to conditionally add menu entry
-- Usage: PakettiAddMenuEntry{name="...", invoke=function() end}
function PakettiAddMenuEntry(args)
  if PakettiShouldRegisterMenus() then
    renoise.tool():add_menu_entry(args)
    return true
  end
  return false
end

-- ============================================================================

-- Initialize the tool
safe_initialize()


renoise.tool():add_keybinding{name="Global:Paketti:Show Paketti Preferences...",invoke=pakettiPreferences}


