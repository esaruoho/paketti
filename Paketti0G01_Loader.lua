local dialog
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
  pakettiRandomizeBPMOnNewSong=false,
  pakettiPatternStatusMonitor=false,
  PakettiImpulseTrackerF8=1,
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
  experimentalRenderPriority="high",  -- "high" or "realtime"
  experimentalRenderSilenceMultiplier=1,  -- 0, 1, 3, or 7 silences
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
  pakettiDefaultXRNI = renoise.tool().bundle_path .. "Presets" .. separator .. "12st_Pitchbend.xrni",
  pakettiDefaultDrumkitXRNI = renoise.tool().bundle_path .. "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni",
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
    populateSends = true
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
    TrackDSPDevice = true,
    Automation = true,
    DiskBrowserFiles = true
  },
  -- Groovebox 8120: show/hide additional options foldout by default
  PakettiGroovebox8120AdditionalOptions = false,
  -- Groovebox 8120 playhead highlight color (1=None, 2=Bright Orange, 3=Deeper Purple, 4=Black, 5=White, 6=Dark Grey)
  PakettiGrooveboxPlayheadColor = 3,
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
  return vb:switch{
    items = {"Off", "Forward", "Backward", "PingPong"},
    value = preference.value,
    width=400,
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

  local coarse_value_label = vb:text{
    width=50,  -- Width to accommodate values up to 10000
    text = tostring(preferences.pakettiRotateSampleBufferCoarse.value)
  }
  
  local fine_value_label = vb:text{
    width=50,  -- Width to accommodate values up to 10000
    text = tostring(preferences.pakettiRotateSampleBufferFine.value)
  }

  local unison_detune_value_label = vb:text{
    width=50,
    text = tostring(preferences.pakettiUnisonDetune.value)
  }

  local threshold_label = vb:text{
        text = string.format("%.3f%%", preferences.PakettiStripSilenceThreshold.value * 100),width=100
    }

    local blend_value_label = vb:text{width=30,
      text = tostring(math.floor(preferences.pakettiBlendValue.value))
    }

    local begthreshold_label = vb:text{
        text = string.format("%.3f%%", preferences.PakettiMoveSilenceThreshold.value * 100),width=100
    }

    local upperbuttonwidth=160
    if dialog and dialog.visible then
        dialog_content=nil
        dialog:close()
        return
    end

        local presetFiles = pakettiGetXRNIDefaultPresetFiles()
    
    -- Get the initial value (index) for the popup
    local pakettiDefaultXRNIDisplayId = "pakettiDefaultXRNIDisplay_" .. tostring(math.random(2,30000))
    local pakettiDefaultDrumkitXRNIDisplayId = "pakettiDefaultDrumkitXRNIDisplay_" .. tostring(math.random(2,30000))

  local dialog_content = vb:column{
      --margin=5,
      horizontal_rule(),
      vb:row{ -- this is where the row structure starts.
        vb:column{ -- first column.
          margin=5,width=600,style="group",      
          vb:column{
            style="group",margin=10,width="100%",
            vb:text{style="strong",font="bold",text="Miscellaneous Settings"},
            --[[vb:row{
              vb:text{text="Upper Frame",width=150},
              vb:switch{items={"Off","Scopes","Spectrum"},value=preferences.upperFramePreference.value+1,width=200,
                notifier=function(value) preferences.upperFramePreference.value=value-1 end}
            },
            vb:row{vb:text{style="strong",text="Whether F2,F3,F4,F11 change the Upper Frame Scope state or not"}},            
            ]]--
            vb:space{height=8},
            vb:row{
              vb:text{text="Selected Sample BeatSync",width=150},
              vb:switch{items={"Off","On"},value=preferences.SelectedSampleBeatSyncLines.value and 2 or 1,width=200,
                notifier=function(value) preferences.SelectedSampleBeatSyncLines.value=(value==2) end}
            },
            
              vb:row{
                vb:text{text="Always Open Track DSPs",width=150},
                vb:switch{items={"Off","On"},value=preferences.pakettiAlwaysOpenDSPsOnTrack.value and 2 or 1,width=200,
                  notifier=function(value) 
                    preferences.pakettiAlwaysOpenDSPsOnTrack.value=(value==2)
                    PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode()
                  end}},
              vb:row{
                vb:text{text="Replace Current Instrument",width=150,tooltip="Pakettification replaces current instrument instead of creating new one"},
                vb:switch{items={"Off","On"},value=preferences.pakettifyReplaceInstrument.value and 2 or 1,width=200,tooltip="Pakettification replaces current instrument instead of creating new one",
                  notifier=function(value) preferences.pakettifyReplaceInstrument.value=(value==2) end}},
              vb:row{
                vb:text{text="Wipe Exploded Track",width=150},
                vb:switch{items={"Off","On"},value=preferences.pakettiWipeExplodedTrack.value and 2 or 1,width=200,
                  notifier=function(value) preferences.pakettiWipeExplodedTrack.value=(value==2) end}},
              vb:row{
                vb:text{text="Instrument Properties",width=150,tooltip="Control Instrument Properties panel visibility on startup and when changed",},
                vb:switch{items={"Do Nothing","Hide","Show"},tooltip="Control Instrument Properties panel visibility on startup and when changed",value=preferences.pakettiInstrumentProperties.value+1,width=300,
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
                vb:switch{items={"Do Nothing","Hide on Song Load","Show on Song Load"},value=preferences.paketti_auto_disk_browser_mode.value+1,width=300,tooltip="Automatically control Disk Browser visibility when songs are loaded",
                  notifier=function(value) 
                    preferences.paketti_auto_disk_browser_mode.value=(value-1)
                    local mode_names = {"Do Nothing", "Hide on Song Load", "Show on Song Load"}
                    renoise.app():show_status("Disk Browser Control: " .. mode_names[value])
                  end}}

             or vb:space{height=1},
            
              vb:row{
                vb:text{text="0G01 Loader",width=150,tooltip="Upon loading a Sample, inserts a C-4 and -G01 to New Track, Sample plays until end of length and triggers again."},
                vb:switch{items={"Off","On"},tooltip="Upon loading a Sample, inserts a C-4 and -G01 to New Track, Sample plays until end of length and triggers again.",value=preferences._0G01_Loader.value and 2 or 1,width=200,
                  notifier=function(value)
                    preferences._0G01_Loader.value=(value==2)
                    update_0G01_loader_menu_entries()
                  end}},
              vb:row{
                vb:text{text="Random BPM",width=150},
                vb:switch{items={"Off","On"},value=preferences.RandomBPM.value and 2 or 1,width=200,
                  notifier=function(value) preferences.RandomBPM.value=(value==2) end}},
              vb:row{
                vb:text{text="Global Groove on Startup",width=150,tooltip="Automatically enable Global Groove when creating/loading songs",},
                vb:switch{items={"Off","On"},tooltip="Automatically enable Global Groove when creating/loading songs",value=preferences.pakettiEnableGlobalGrooveOnStartup.value and 2 or 1,width=200,
                  notifier=function(value) preferences.pakettiEnableGlobalGrooveOnStartup.value=(value==2) end}},
              vb:row{
                vb:text{text="BPM Randomizer on New Songs",width=150,tooltip="Randomly set BPM (60-220) with bell curve around 120 for new songs (not loaded from file)",},
                vb:switch{items={"Off","On"},tooltip="Randomly set BPM (60-220) with bell curve around 120 for new songs (not loaded from file)",value=preferences.pakettiRandomizeBPMOnNewSong.value and 2 or 1,width=200,
                  notifier=function(value) preferences.pakettiRandomizeBPMOnNewSong.value=(value==2) end}},
              vb:row{
                vb:text{text="Pattern Status Monitor",width=150,tooltip="Show real-time effect/note column information in status bar",},
                vb:switch{items={"Off","On"},tooltip="Show real-time effect/note column information in status bar",value=preferences.pakettiPatternStatusMonitor.value and 2 or 1,width=200,
                  notifier=function(value) preferences.pakettiPatternStatusMonitor.value=(value==2) end}},
            vb:row{
            vb:button{text="Load Pale Green Theme",width=150,notifier=function() update_loadPaleGreenTheme_preferences() end},
            vb:button{text="Load Plaid Zap .XRNI",width=150,notifier=function() renoise.app():load_instrument("Gifts/plaidzap.xrni") end},
            vb:button{text="Load 200 Drum Machines (.zip)",width=150,notifier=function() 
            renoise.app():open_url("http://www.hexawe.net/mess/200.Drum.Machines/") end}
            },
                vb:row{vb:text{text="Create New Instrument & Loop from Selection", font="bold",style = "strong"}},
                vb:row{vb:text{text="Select Newly Created",width=150},
                    vb:switch{items = {"Off", "On"},
                        value = preferences.selectionNewInstrumentSelect.value and 2 or 1,
                        width=200,
                        notifier=function(value)
                            preferences.selectionNewInstrumentSelect.value = (value == 2)
                        end}},
          vb:row{vb:text{text="Sample Interpolation",width=150},vb:switch{items={"None","Linear","Cubic","Sinc"},value=preferences.selectionNewInstrumentInterpolation.value,width=200,
              notifier=function(value) 
                  preferences.selectionNewInstrumentInterpolation.value = value end}
            },
                    vb:row{vb:text{text="Loop on Newly Created",width=150},
                    create_loop_mode_switch(preferences.selectionNewInstrumentLoop)},
            vb:row{vb:text{text="Autoseek",width=150},vb:switch{items={"Off","On"},value=preferences.selectionNewInstrumentAutoseek.value and 2 or 1,width=200,
              notifier=function(value) preferences.selectionNewInstrumentAutoseek.value=(value ==2) end}
            },
            vb:row{vb:text{text="Autofade",width=150},vb:switch{items={"Off","On"},value=preferences.selectionNewInstrumentAutofade.value and 2 or 1,width=200,
              notifier=function(value) 
              preferences.selectionNewInstrumentAutofade.value=(value==2) 
              end}},
          -- Render Settings wrapped in group
              vb:text{style="strong",font="bold",text="Render Settings"},
              vb:row{vb:text{text="Sample Rate",width=150},vb:switch{items={"22050","44100","48000","88200","96000","192000"},value=find_sample_rate_index(preferences.renderSampleRate.value),width=300,
                notifier=function(value) preferences.renderSampleRate.value=sample_rates[value] end}},
            
              vb:row{vb:text{text="Bit Depth",width=150},vb:switch{items={"16","24","32"},value=preferences.renderBitDepth.value==16 and 1 or preferences.renderBitDepth.value==24 and 2 or 3,width=300,
                notifier=function(value) preferences.renderBitDepth.value=(value==1 and 16 or value==2 and 24 or 32) end}},
            
              vb:row{vb:text{text="Bypass Devices",width=150},vb:switch{items={"Off","On"},value=preferences.renderBypass.value and 2 or 1,width=300,
                notifier=function(value) preferences.renderBypass.value=(value==2) end}},
            
              vb:row{vb:text{text="DC Offset",width=150},vb:switch{items={"Off","On"},value=preferences.RenderDCOffset.value and 2 or 1,width=300,
                notifier=function(value) preferences.RenderDCOffset.value=(value==2) end}},
            vb:text{style="strong",font="bold",text="Experimental Render Settings"},
            vb:row{vb:text{text="Render Priority",width=150},vb:switch{items={"High","Realtime"},value=preferences.experimentalRenderPriority.value=="high" and 1 or 2,width=300,
              tooltip="High: switches to Realtime if Line Input device detected. Realtime: always uses realtime priority.",
              notifier=function(value) preferences.experimentalRenderPriority.value=(value==1 and "high" or "realtime") end}},
            vb:row{vb:text{text="Silence Multiplier",width=150},vb:switch{items={"0","1","3","7"},value=(preferences.experimentalRenderSilenceMultiplier.value==0 and 1 or preferences.experimentalRenderSilenceMultiplier.value==1 and 2 or preferences.experimentalRenderSilenceMultiplier.value==3 and 3 or 4),width=300,
              tooltip="Number of sample-length silences after playback for FX trails (0=no trails, 7=max trails).",
              notifier=function(value) preferences.experimentalRenderSilenceMultiplier.value=(value==1 and 0 or value==2 and 1 or value==3 and 3 or 7) end}},
              vb:text{style = "strong", font = "bold", text="Rotate Sample Buffer Settings"},
            vb:row{
                vb:text{text="Fine Control",width=150},
                vb:slider{
                    min = 0,
                    max = 10000,
                    value = preferences.pakettiRotateSampleBufferFine.value,
                    width=200,
                    notifier=function(value)
                        value = math.floor(value)  -- Ensure integer value
                        preferences.pakettiRotateSampleBufferFine.value = value
                        fine_value_label.text = tostring(value)
                    end
                },
                fine_value_label
            },
            vb:row{
                vb:text{text="Coarse Control",width=150},
                vb:slider{
                    min = 0,
                    max = 10000,
                    value = preferences.pakettiRotateSampleBufferCoarse.value,
                    width=200,
                    notifier=function(value)
                        value = math.floor(value)  -- Ensure integer value
                        preferences.pakettiRotateSampleBufferCoarse.value = value
                        coarse_value_label.text = tostring(value)
                    end
                },coarse_value_label},
            vb:text{style="strong",font="bold",text="Strip Silence Settings"},
vb:row{
  vb:text{text="Strip Silence Threshold:",width=150},
  vb:minislider{
      min = 0,
      max = 1,
      value = preferences.PakettiStripSilenceThreshold.value,
      width=200,
      notifier=function(value)
          threshold_label.text = string.format("%.3f%%", value * 100)
          preferences.PakettiStripSilenceThreshold.value = value
          update_strip_silence_preview(value)
      end},threshold_label},
vb:row{
  vb:text{text="Move Silence Threshold:",width=150},
  vb:minislider{
      min = 0,
      max = 1,
      value = preferences.PakettiMoveSilenceThreshold.value,
      width=200,
      notifier=function(value)
          begthreshold_label.text = string.format("%.3f%%", value * 100)
          preferences.PakettiMoveSilenceThreshold.value = value
          update_move_silence_preview(value)
      end},begthreshold_label,},
              vb:text{style="strong",font="bold",text="Edit Mode Colouring"}

              
            ,
            vb:row{vb:text{text="Edit Mode",width=150},vb:switch{items={"None","Selected Track","All Tracks"},value=preferences.pakettiEditMode.value,width=300,
              notifier=function(value) preferences.pakettiEditMode.value=value end}
            },
            vb:row{vb:text{style="strong",text="Enable Scope Highlight by going to Settings -> GUI -> Show Track Color Blends."} },

            vb:row{
              vb:text{text="Blend Value",width=150},
              vb:slider{
                min = 0,
                max = 100,
                value = math.floor(preferences.pakettiBlendValue.value),
                width=200,
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
              vb:switch{
                items={"Lines","Points","Curves"},
                value=preferences.pakettiAutomationFormat.value,
                width=200,
                notifier=function(value) 
                  preferences.pakettiAutomationFormat.value = value
                  print("Automation format set to: " .. value)
                end
              } 
            },
            vb:row{
              vb:text{text="Retain Effect Column?",width=150},
              vb:switch{
                items={"Keep","Wipe"},
                value=preferences.pakettiAutomationWipeAfterSwitch.value and 2 or 1,
                width=200,
                notifier=function(value)
                  preferences.pakettiAutomationWipeAfterSwitch.value = (value == 2)
                end
              }
            }
          },
        },
        -- Column 2
        vb:column{
          style="group",margin=5,width=600,
          -- Paketti Loader Settings wrapped in group
          vb:column{
            style="group",margin=10,width="100%",
            
            vb:text{style="strong",font="bold",text="Paketti Loader Settings"},
            vb:row{
              vb:text{text="Skip Automation Device",width=150},
              vb:switch{items={"Off","On"},value=preferences.pakettiLoaderDontCreateAutomationDevice.value and 2 or 1,width=200,
                notifier=function(value) preferences.pakettiLoaderDontCreateAutomationDevice.value=(value==2) end}
            },
            vb:row{vb:text{text="Sample Interpolation",width=150},vb:switch{items={"None","Linear","Cubic","Sinc"},value=preferences.pakettiLoaderInterpolation.value,width=200,
              notifier=function(value) update_interpolation_mode(value) end}
            },
            vb:row{vb:text{text="One-Shot",width=150},vb:switch{items={"Off","On"},value=preferences.pakettiLoaderOneshot.value and 2 or 1,width=200,
              notifier=function(value) preferences.pakettiLoaderOneshot.value=(value==2) end}
            },
            vb:row{vb:text{text="Autoseek",width=150},vb:switch{items={"Off","On"},value=preferences.pakettiLoaderAutoseek.value and 2 or 1,width=200,
              notifier=function(value) preferences.pakettiLoaderAutoseek.value=(value==2) end}
            },
            vb:row{vb:text{text="Autofade",width=150},vb:switch{items={"Off","On"},value=preferences.pakettiLoaderAutofade.value and 2 or 1,width=200,
              notifier=function(value) preferences.pakettiLoaderAutofade.value=(value==2) end}
            },
            vb:row{vb:text{text="New Note Action(NNA) Mode",width=150},vb:switch{items={"Cut","Note-Off","Continue"},value=preferences.pakettiLoaderNNA.value,width=300,
              notifier=function(value) preferences.pakettiLoaderNNA.value=value end}
            },
            vb:row{vb:text{text="OverSampling",width=150},vb:switch{items={"Off","On"},value=preferences.pakettiLoaderOverSampling.value and 2 or 1,width=200,
              notifier=function(value) preferences.pakettiLoaderOverSampling.value=(value==2) end}
            },
            vb:row{vb:text{text="Loop Mode",width=150},create_loop_mode_switch(preferences.pakettiLoaderLoopMode) },
            vb:row{vb:text{text="Loop Release/Exit Mode",width=150},vb:checkbox{value=preferences.pakettiLoaderLoopExit.value,notifier=function(value) preferences.pakettiLoaderLoopExit.value=value end} },
            vb:row{vb:text{text="Enable AHDSR Envelope",width=150},vb:checkbox{value=preferences.pakettiPitchbendLoaderEnvelope.value,notifier=function(value) preferences.pakettiPitchbendLoaderEnvelope.value=value end} },
            vb:row{
              vb:text{text="FilterType",width=150},
              vb:popup{
                items = filter_types,
                value = cached_filter_index,
                width=200,
                notifier=function(value)
                  preferences.pakettiLoaderFilterType.value = filter_types[value]
                  cached_filter_index = value -- Update the cached index
                  -- Removed print statements for performance
                  preferences:save_as("preferences.xml")
                end
              }
            },
            vb:row{vb:text{text="Paketti Loader Settings (Drumkit Loader)", font="bold", style="strong"}},
            vb:row{vb:text{text="Move Beginning Silence",width=150},vb:switch{items={"Off","On"},value=preferences.pakettiLoaderMoveSilenceToEnd.value and 2 or 1,width=200,
              notifier=function(value) preferences.pakettiLoaderMoveSilenceToEnd.value=(value==2) end}},
          vb:row{vb:text{text="Normalize Samples",width=150},vb:switch{items={"Off","On"},value=preferences.pakettiLoaderNormalizeSamples.value and 2 or 1,width=200,
            notifier=function(value) preferences.pakettiLoaderNormalizeSamples.value=(value==2) end}},
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
            vb:row{vb:text{text="Slice Loop Mode",width=150},create_loop_mode_switch(preferences.WipeSlices.WipeSlicesLoopMode) },
            vb:row{vb:text{text="Slice Loop Release/Exit Mode",width=150},vb:checkbox{value=preferences.WipeSlices.WipeSlicesLoopRelease.value,notifier=function(value) preferences.WipeSlices.WipeSlicesLoopRelease.value=value end} },
            vb:row{vb:text{text="Slice Beatsync Mode",width=150},vb:switch{items={"Repitch","Time-Stretch (Percussion)","Time-Stretch (Texture)","Off"},value=preferences.WipeSlices.WipeSlicesBeatSyncMode.value,width=420,
              notifier=function(value) preferences.WipeSlices.WipeSlicesBeatSyncMode.value=value end}},
            vb:row{vb:text{text="Slice One-Shot",width=150},vb:switch{items={"Off","On"},value=preferences.WipeSlices.WipeSlicesOneShot.value and 2 or 1,width=200,
              notifier=function(value) preferences.WipeSlices.WipeSlicesOneShot.value=(value==2) end}},
            vb:row{vb:text{text="Slice Autoseek",width=150},vb:switch{items={"Off","On"},value=preferences.WipeSlices.WipeSlicesAutoseek.value and 2 or 1,width=200,
              notifier=function(value) preferences.WipeSlices.WipeSlicesAutoseek.value=(value==2) end}},
            vb:row{vb:text{text="Slice Autofade",width=150},vb:switch{items={"Off","On"},value=preferences.WipeSlices.WipeSlicesAutofade.value and 2 or 1,width=200,
              notifier=function(value) preferences.WipeSlices.WipeSlicesAutofade.value=(value==2) end}},
            vb:row{vb:text{text="New Note Action(NNA) Mode",width=150},vb:switch{items={"Cut","Note-Off","Continue"},value=preferences.WipeSlices.WipeSlicesNNA.value,width=300,
              notifier=function(value) preferences.WipeSlices.WipeSlicesNNA.value=value end}},
            vb:row{vb:text{text="Mute Group",width=150},vb:switch{items={"Off","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"},value=preferences.WipeSlices.WipeSlicesMuteGroup.value+1,width=400,
              notifier=function(value) preferences.WipeSlices.WipeSlicesMuteGroup.value=value-1 end}},
            vb:row{vb:text{text="Slice Loop EndHalf",width=150},vb:switch{items={"Off","On"},value=preferences.WipeSlices.SliceLoopMode.value and 2 or 1,width=200,
          notifier=function(value) preferences.WipeSlices.SliceLoopMode.value=(value==2) end}},
      vb:row{
        vb:text{text="Dialog Close Key",width=150, style="strong",font="bold"},
        vb:popup{
          items = dialog_close_keys,
          value = table.find(dialog_close_keys, preferences.pakettiDialogClose.value) or 1,
          width=200,
          notifier=function(value)
            preferences.pakettiDialogClose.value = dialog_close_keys[value]
          end},},
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
            text="Reset to Default",
            width=100,
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
            text="Reset to Default",
            width=100,
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
    vb:switch{
      items={"First", "Last"},
      value=preferences.pakettiLoadOrder.value and 2 or 1,
      width=200,
      notifier=function(value) 
        preferences.pakettiLoadOrder.value = (value == 2)
        print (preferences.pakettiLoadOrder.value)
      end
    }
  },
  
    vb:row{
      vb:text{text="Device Load Behavior", style="strong",font="bold",width=150,tooltip="Controls behavior when loading VST/AU plugins and native devices"},
      vb:switch{
        items={"<do nothing>", "Open External Editor", "Open Selected Parameter Dialog"},
        value=(preferences.pakettiDeviceLoadBehaviour.value == 3 and 1 or preferences.pakettiDeviceLoadBehaviour.value == 1 and 2 or 3),
        tooltip="Controls behavior when loading VST/AU plugins and native devices",
        width=400,
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
      vb:text{text="LFO Write Device Delete",style="strong",font="bold",width=150},
      vb:switch{
        items={"Off","On"},
        value=preferences.PakettiLFOWriteDelete.value and 2 or 1,
        width=200,
        notifier=function(value)
          preferences.PakettiLFOWriteDelete.value = (value == 2)
        end
      }
    },
    vb:text{text="Sample Selection Info (Shows detected note, frequency, and tuning offset in sample selection info)",width=150, style="strong",font="bold"},
    vb:row{
      vb:text{text="Show Sample Selection",width=150},
      vb:switch{items={"Off","On"},
        value=preferences.pakettiShowSampleDetails.value and 2 or 1,
        width=200,
        notifier=function(value) 
          preferences.pakettiShowSampleDetails.value=(value==2)
          print(string.format("Show Sample Selection changed to: %s", tostring(preferences.pakettiShowSampleDetails.value)))
        end
      }
    },
    vb:row{
      vb:text{text="Include Frequency Analysis",width=150},
      vb:switch{items={"Off","On"},
        value=preferences.pakettiShowSampleDetailsFrequencyAnalysis.value and 2 or 1,
        width=200,
        notifier=function(value) 
          preferences.pakettiShowSampleDetailsFrequencyAnalysis.value=(value==2)
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
          style="group",margin=5,width=600,
          vb:column{
            style="group",margin=10,width="100%",
            vb:text{style="strong",font="bold",text="Player Pro Settings"},
          vb:row{
            vb:text{text="Dialog Dark Mode",width=150},
            vb:switch{items={"Light Mode","Dark Mode"},
              value=preferences.pakettiPlayerProEffectDialogDarkMode.value and 2 or 1,
              width=200,
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
            }
          },
          vb:row{
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
            }
          },
          vb:row{
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
            vb:switch{items={"Off","On"},
              value=preferences.pakettiPlayerProAlwaysOpen.value and 2 or 1,
              width=200,
              tooltip="Automatically opens appropriate dialog based on cursor position",
              notifier=function(value) 
                preferences.pakettiPlayerProAlwaysOpen.value=(value==2)
                -- Update the always open system immediately
                if preferences.pakettiPlayerProAlwaysOpen.value then
                  pakettiPlayerProStartAlwaysOpen()
                else
                  pakettiPlayerProStopAlwaysOpen()
                end
                print(string.format("PlayerPro Always Open changed to: %s", value == 2 and "On" or "Off"))
              end
            }
          },
          vb:row{
            vb:text{text="Smart SubColumn",width=150,tooltip="Effect dialog opens when in volume/panning/delay/sample FX subcolumns"},
            vb:switch{items={"Off","On"},
              value=preferences.pakettiPlayerProSmartSubColumn.value and 2 or 1,
              width=200,
              tooltip="Effect dialog opens when in volume/panning/delay/sample FX subcolumns",
              notifier=function(value) 
                preferences.pakettiPlayerProSmartSubColumn.value=(value==2)
                print(string.format("PlayerPro Smart SubColumn changed to: %s", value == 2 and "On" or "Off"))
              end
            }
          },
          vb:row{
            vb:text{text="Auto-Hide on Frame Switch",width=150,tooltip="Automatically hide PlayerPro dialogs when switching away from Pattern Editor"},
            vb:switch{items={"Off","On"},
              value=preferences.pakettiPlayerProAutoHideOnFrameSwitch.value and 2 or 1,
              width=200,
              tooltip="Automatically hide PlayerPro dialogs when switching away from Pattern Editor",
              notifier=function(value) 
                preferences.pakettiPlayerProAutoHideOnFrameSwitch.value=(value==2)
                -- Update the middle frame observer based on the new setting
                if value == 2 then
                  pakettiPlayerProStartMiddleFrameObserver()
                else
                  pakettiPlayerProStopMiddleFrameObserver()
                end
                print(string.format("PlayerPro Auto-Hide on Frame Switch changed to: %s", value == 2 and "On" or "Off"))
              end
            }
          },
      





          -- Unison Generator Settings wrapped in group

            vb:text{style="strong",font="bold",text="Unison Generator Settings"},
            vb:row{
                vb:text{text="Unison Detune",width=150},
                vb:slider{
                    min = 0,
                    max = 96,
                    value = preferences.pakettiUnisonDetune.value,
                    width=200,
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
                }
            },
            vb:row{
                vb:text{text="Hard Sync",width=150},
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
                }
            },
            vb:row{
                vb:text{text="Duplicate Instrument",width=150},
                vb:checkbox{
                    value=preferences.pakettiUnisonDuplicateInstrument.value,
                    notifier=function(value)
                        preferences.pakettiUnisonDuplicateInstrument.value = value
                    end
                }
            },
            vb:row{vb:text{style="strong",text="Controls the detune range (±) used by the Unison Generator. Hard Sync: alternating ±max values."}},
            vb:row{vb:text{style="strong",text="Live-updates currently selected unison instrument."}},
            vb:row{vb:text{style="strong",text="Duplicate whole Instrument: copies entire instrument (plugins, AHDSR, macros) before unison-ing."}},
          
          vb:row{
            vb:text{text="File Menu Location",width=150,style="strong",font="bold",tooltip="Choose where File-related Paketti menu entries appear"},
            vb:switch{items={"File","Paketti","Both"},value=preferences.pakettiFileMenuLocationMode.value,width=300,
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
            vb:text{text="Autofocus selected EQ10 device",width=150},
            vb:switch{items={"False","True"},width=200,value=preferences.PakettiEQ30Autofocus.value and 2 or 1,
              notifier=function(value)
                preferences.PakettiEQ30Autofocus.value = (value==2)
                preferences:save_as("preferences.xml")
              end}
          },
          vb:row{
            vb:text{text="Minimize EQ10 devices",width=150},
            vb:switch{items={"False","True"},width=200,value=preferences.PakettiEQ30MinimizeDevices.value and 2 or 1,
              notifier=function(value)
                preferences.PakettiEQ30MinimizeDevices.value = (value==2)
                preferences:save_as("preferences.xml")
              end}
          },
          vb:row{vb:text{style="strong",text="Controls whether entries are under File directly, File:Paketti submenu, or both."}},
          vb:space{height=8},
          vb:text{style="strong",font="bold",text="Groovebox 8120"},
          vb:row{
            vb:text{text="Playhead Color",width=150},
            vb:switch{items={"None","Orange","Purple","Black","White","Grey"},
              value=preferences.PakettiGrooveboxPlayheadColor.value,
              width=422,
              notifier=function(value)
                preferences.PakettiGrooveboxPlayheadColor.value = value
                if type(PakettiEightOneTwentyApplyPlayheadColor) == "function" then
                  PakettiEightOneTwentyApplyPlayheadColor()
                end
              end}
          },
          vb:space{height=8},
          vb:text{style="strong",font="bold",text="Impulse Tracker"},
          vb:row{
            vb:text{text="Impulse Tracker F8",width=150},
            vb:switch{
              items={"Do Nothing","Enable Follow","Stop Follow"},
              value=preferences.PakettiImpulseTrackerF8.value,
              width=400,
              notifier=function(value)
                preferences.PakettiImpulseTrackerF8.value = value
              end
            }
          },
        }
        }
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

function update_dynamic_menu_entries()
    local enableMenuEntryName="--Main Menu:Tools:Paketti:!Preferences:0G01 Loader Enable"
    local disableMenuEntryName="--Main Menu:Tools:Paketti:!Preferences:0G01 Loader Disable"

    if preferences._0G01_Loader.value then
        if renoise.tool():has_menu_entry(enableMenuEntryName) then
            renoise.tool():remove_menu_entry(enableMenuEntryName)
        end
        if not renoise.tool():has_menu_entry(disableMenuEntryName) then
            renoise.tool():add_menu_entry{name=disableMenuEntryName,
                invoke=function()
                    preferences._0G01_Loader.value = false
                    update_dynamic_menu_entries()
                    if dialog and dialog.visible then
                        dialog:close()
                        pakettiPreferences()
                    end
                end}
        end
    else
        if renoise.tool():has_menu_entry(disableMenuEntryName) then
            renoise.tool():remove_menu_entry(disableMenuEntryName)
        end
        if not renoise.tool():has_menu_entry(enableMenuEntryName) then
            renoise.tool():add_menu_entry{name=enableMenuEntryName,
                invoke=function()
                    preferences._0G01_Loader.value = true
                    update_dynamic_menu_entries()
                    if dialog and dialog.visible then
                        dialog:close()
                        pakettiPreferences()
                    end
                end}
        end
    end
end

function update_0G01_loader_menu_entries()
    manage_sample_count_observer(preferences._0G01_Loader.value)
    update_dynamic_menu_entries()
end

-- Update File vs File:Paketti menu entry visibility/location based on preference
-- moved to PakettiMenuConfig.lua as a global

function initialize_tool()
    update_0G01_loader_menu_entries()
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

-- Initialize the tool
safe_initialize()

renoise.tool():add_keybinding{name="Global:Paketti:Show Paketti Preferences...",invoke=pakettiPreferences}


