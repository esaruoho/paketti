sampleEditor = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
patternEditor = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
pe = patternEditor
sampleMappings = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES
sampleModulation = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION
mixer = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
phraseEditor = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
phrase = phraseEditor
midiEditor = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR
sampleFX = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
lowerTrackdsp=renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
lowerAutomation=renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
upperScopes=renoise.ApplicationWindow.UPPER_FRAME_TRACK_SCOPES
upperSpectrum=renoise.ApplicationWindow.UPPER_FRAME_MASTER_SPECTRUM
----------------------------------------------------------------------------------------------------------------------------------------
--from http://lua-users.org/lists/lua-l/2004-09/msg00054.html 
function DEC_HEX(IN)
  local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
  while IN>0 do
      I=I+1
      IN,D=math.floor(IN/B),math.mod(IN,B)+1
      OUT=string.sub(K,D,D)..OUT
  end
  return OUT
end
--
local init_time = os.clock()
-- Function to check if an instrument uses effects or has an empty FX chain and adjust name accordingly
function align_instrument_names()
  local song=renoise.song()
  
  for i, instrument in ipairs(song.instruments) do
    local name = instrument.name
    
    -- Check if the instrument uses effects in the instrument editor or has an empty FX chain
    local uses_fx = false

    -- Check for FX chains (even empty ones should be counted as using FX)
    if #instrument.sample_device_chains > 0 then
      uses_fx = true  -- FX chain exists, even if empty, it adds an icon in the GUI
    end

    -- If instrument uses effects or has an empty FX chain, remove leading spaces
    if uses_fx then
      -- Remove the 5 spaces if the instrument was previously aligned
      instrument.name = name:gsub("^%s%s%s%s%s", "")
    else
      -- If instrument does not use effects, add 5 spaces if not already aligned
      if not name:match("^%s%s%s%s%s") then
        instrument.name = "     " .. name
      end
    end
  end
end

function formatDigits(digits, number)
  return string.format("%0" .. digits .. "d", number)
end

function selection_in_pattern_pro()
  local song=renoise.song()

  -- Get the selection in pattern
  local selection = song.selection_in_pattern
  if not selection then
    print("No selection in pattern!")
    return nil
  end

  -- Debug: Print selection details
  print("Selection in Pattern:")
  print("Start Track:", selection.start_track)
  print("End Track:", selection.end_track)
  print("Start Column:", selection.start_column)
  print("End Column:", selection.end_column)
  print("Start Line:", selection.start_line)
  print("End Line:", selection.end_line)

  local result = {}

  -- Iterate over the selected tracks
  for track_index = selection.start_track, selection.end_track do
    local track = song.tracks[track_index]
    local track_info = {
      track_index = track_index,
      track_type = track.type, -- Track type (e.g., "track", "group", "send", "master")
      note_columns = {},
      effect_columns = {}
    }

    -- Fetch visible note and effect columns
    local visible_note_columns = track.visible_note_columns
    local visible_effect_columns = track.visible_effect_columns
    local total_columns = visible_note_columns + visible_effect_columns

    -- Debugging visibility
    print("Track Index:", track_index)
    print("Visible Note Columns:", visible_note_columns)
    print("Visible Effect Columns:", visible_effect_columns)
    print("Total Columns:", total_columns)

    -- Determine the range of selected columns for this track
    local track_start_column = (track_index == selection.start_track) and selection.start_column or 1
    local track_end_column = (track_index == selection.end_track) and selection.end_column or total_columns

    -- Ensure valid column ranges
    track_start_column = math.max(track_start_column, 1)
    track_end_column = math.min(track_end_column, total_columns)

    -- Process Note Columns
    if visible_note_columns > 0 and track_start_column <= visible_note_columns then
      for col = track_start_column, math.min(track_end_column, visible_note_columns) do
        table.insert(track_info.note_columns, col)
      end
    end

    -- Process Effect Columns
    if visible_effect_columns > 0 and track_end_column > visible_note_columns then
      local effect_start = math.max(track_start_column - visible_note_columns, 1)
      local effect_end = track_end_column - visible_note_columns
      for col = effect_start, math.min(effect_end, visible_effect_columns) do
        table.insert(track_info.effect_columns, col)
      end
    end

    -- Debugging output
    print("Selected Note Columns:", #track_info.note_columns > 0 and table.concat(track_info.note_columns, ", ") or "None")
    print("Selected Effect Columns:", #track_info.effect_columns > 0 and table.concat(track_info.effect_columns, ", ") or "None")

    -- Add track information to the result
    table.insert(result, track_info)
  end

  return result
end

function timed_require(module_name)
    local start_time = os.clock()
    
    -- Count lines in the file
    local line_count = 0
    local file_path = renoise.tool().bundle_path .. module_name .. ".lua"
    local file = io.open(file_path, "r")
    if file then
        for _ in file:lines() do
            line_count = line_count + 1
        end
        file:close()
    end
    
    -- Require the module and time it
    require(module_name)
    local elapsed = (os.clock() - start_time) * 1000 -- convert to milliseconds
    
    print(string.format("%s, %d lines, %.2f ms", module_name, line_count, elapsed))
end
print ("---------------------")


-- Helper function to create a keyhandler that can manage a specific dialog variable
function create_keyhandler_for_dialog(dialog_var_getter, dialog_var_setter)
  return function(dialog, key)
    local closer = preferences.pakettiDialogClose.value
    print("Key handler called - key.name: '" .. tostring(key.name) .. "', key.modifiers: '" .. tostring(key.modifiers) .. "', closer: '" .. tostring(closer) .. "'")
    
    if key.modifiers == "" and key.name == closer then
      -- Clean up any observers that might exist
      if cleanup_observers then
        cleanup_observers()
      end
      dialog:close()
      dialog_var_setter(nil)  -- Set the dialog variable to nil
      return nil
    else
      return key
    end
  end
end


-- Legacy function for backwards compatibility
function my_keyhandler_func(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  print("Key handler called - key.name: '" .. tostring(key.name) .. "', key.modifiers: '" .. tostring(key.modifiers) .. "', closer: '" .. tostring(closer) .. "'")
  
  if key.modifiers == "" and key.name == closer then
    -- Clean up any observers that might exist
    print("YO i got " .. closer)
    if cleanup_observers then
      cleanup_observers()
    end
    dialog:close()
    return nil
  else
    return key
  end
end

------------------------------------------------
local themes_path = renoise.tool().bundle_path .. "Themes/"
local themes = os.filenames(themes_path, "*.xrnc")
local selected_theme_index = nil
-- Debug print all available themes
--print("Debug: Available themes:")
--for i, theme in ipairs(themes) do
--  print(i .. ": " .. theme)
--end

-- Define valid audio file extensions globally
PakettiValidAudioExtensions = {".wav",".mp3",".flac",".aif",".aiff",".m4a"}

-- Global helper function to check if a file has a valid audio extension
function PakettiIsValidAudioFile(filename)
    for _, ext in ipairs(PakettiValidAudioExtensions) do
        if filename:lower():match(ext .. "$") then
            return true
        end
    end
    return false
end

-- Global helper function to find all .lua files in Paketti bundle
function PakettiGetAllLuaFiles()
    local files = {}
    local bundle_path = renoise.tool().bundle_path
    
    -- Get all .lua files in root directory
    local root_lua_files = os.filenames(bundle_path, "*.lua")
    for _, filename in ipairs(root_lua_files) do
        local name_without_ext = filename:match("(.+)%.lua$")
        if name_without_ext and name_without_ext ~= "main" and name_without_ext ~= "manifest" then
            table.insert(files, name_without_ext)
        end
    end
    
    -- Manually check known subdirectories that contain .lua files
    local known_subdirs = {"Research", "hotelsinus_stepseq", "Sononymph"}
    
    for _, subdir in ipairs(known_subdirs) do
        local subdir_path = bundle_path .. subdir .. "/"
        -- Check if subdirectory exists by trying to get filenames
        local success, subdir_files = pcall(os.filenames, subdir_path, "*.lua")
        if success and subdir_files then
            for _, filename in ipairs(subdir_files) do
                local name_without_ext = filename:match("(.+)%.lua$")
                if name_without_ext then
                    -- Include subdirectory path in the name
                    table.insert(files, subdir .. "/" .. name_without_ext)
                end
            end
        end
    end
    
    print(string.format("PakettiGetAllLuaFiles: Found %d .lua files", #files))
    return files
end

-- Global function to get files from directory with improved error handling and debugging
function PakettiGetFilesInDirectory(dir)
    local files = {}
    
    -- Function to properly escape paths for shell commands
    local function escape_path_for_shell(path)
        if package.config:sub(1, 1) == "\\" then  -- Windows
            -- For Windows, we need to escape special characters properly
            -- Replace tildes and other special chars that could be problematic
            path = path:gsub("~", "~")  -- Keep tildes as-is for now
            -- Wrap in quotes and escape existing quotes
            path = path:gsub('"', '""')  -- Escape quotes for Windows
            return '"' .. path .. '"'
        else  -- macOS and Linux
            -- For Unix-like systems, escape single quotes properly
            path = path:gsub("'", "'\"'\"'")
            return "'" .. path .. "'"
        end
    end
    
    -- Use OS-specific commands to list all files recursively
    local command
    if package.config:sub(1, 1) == "\\" then  -- Windows
        -- Use robust Windows command with proper escaping
        local escaped_dir = escape_path_for_shell(dir)
        command = string.format('dir %s /b /s 2>nul', escaped_dir)
    else  -- macOS and Linux
        -- Use robust Unix find command with proper escaping
        local escaped_dir = escape_path_for_shell(dir)
        command = string.format("find %s -type f 2>/dev/null", escaped_dir)
    end
    
    -- Debug output for troubleshooting
    print("PakettiGetFilesInDirectory: Executing command: " .. command)
    
    -- Execute the command and process the output
    local handle = io.popen(command)
    if handle then
        for line in handle:lines() do
            -- Clean up the line (remove any trailing whitespace)
            line = line:match("^%s*(.-)%s*$")
            
            -- Skip empty lines, files in OPS7 folder, and check if it's a valid audio file
            if line ~= "" and not line:match("OPS7") and PakettiIsValidAudioFile(line) then
                table.insert(files, line)
            end
        end
        local success, msg, code = handle:close()
        if not success then
            print("Warning: Command execution had issues: " .. tostring(msg))
            -- Don't show error to user for minor issues, just log it
        end
    else
        renoise.app():show_error("Failed to execute directory listing command: " .. command)
    end
    
    print("PakettiGetFilesInDirectory: Found " .. #files .. " audio files")
    return files
end
---
function pakettiThemeSelectorRenoiseStartFavorites()
  if #preferences.pakettiThemeSelector.FavoritedList <= 1 then
    renoise.app():show_status("You currently have no Favorite Themes set.")
    return
  end
  if #preferences.pakettiThemeSelector.FavoritedList == 2 then
    renoise.app():show_status("You only have 1 favorite, cannot randomize.")
    return
  end

  -- Initialize random seed for true randomness
  math.randomseed(os.time())
  
  local current_index = math.random(2, #preferences.pakettiThemeSelector.FavoritedList)
  local random_theme = preferences.pakettiThemeSelector.FavoritedList[current_index]

  local cleaned_theme_name = tostring(random_theme):match(".*%. (.+)") or tostring(random_theme)
  selected_theme_index = table.find(themes, cleaned_theme_name)

  renoise.app():load_theme(themes_path .. tostring(random_theme) .. ".xrnc")
  renoise.app():show_status("Randomized a theme out of your favorite list: " .. tostring(random_theme))
end

function pakettiThemeSelectorPickRandomThemeFromAll()
  local themes_path = renoise.tool().bundle_path .. "Themes/"
  local themes = os.filenames(themes_path, "*.xrnc")
  
  -- Initialize random seed based on current time for true randomness
  math.randomseed(os.time())
  
  if #themes == 0 then
    renoise.app():show_status("No themes found in Themes folder.")
    return
  end
  
  local new_index
  
  -- If we have a current theme and more than 1 theme, avoid repeating it
  if selected_theme_index and #themes > 1 then
    repeat
      new_index = math.random(#themes)
    until new_index ~= selected_theme_index
  else
    -- First time or only one theme - just pick random
    new_index = math.random(#themes)
  end
  
  selected_theme_index = new_index
  renoise.app():load_theme(themes_path .. themes[selected_theme_index])
  renoise.app():show_status("Picked a random theme from all themes: " .. themes[selected_theme_index])
end

--local PakettiAutomationDoofer=false

-- Function to generate bell curve BPM around 120 (range 60-220, step 5)
function pakettiGenerateBellCurveBPM()
  -- Generate 6 random numbers and average them for bell curve approximation
  local sum = 0
  for i = 1, 6 do
    sum = sum + math.random()
  end
  local normalized = sum / 6  -- Now we have a value roughly 0-1 with bell curve distribution
  
  -- Map to BPM range 60-220 with center at 120
  local range = 220 - 60  -- 160
  local center = 120
  local half_range = range / 2  -- 80
  
  -- Convert normalized (0-1) to (-1 to 1) centered distribution
  local centered = (normalized - 0.5) * 2
  
  -- Apply to center point with scaling
  local bpm = center + (centered * half_range)
  
  -- Clamp to valid range and round to nearest 5
  bpm = math.max(60, math.min(220, bpm))
  bpm = math.floor(bpm / 5 + 0.5) * 5
  
  return bpm
end

-- Function to detect if this is a fresh new song (not a loaded song)
-- Used by app_new_document_observable to distinguish File->New vs File->Load
function pakettiIsNewSong()
  local song = renoise.song()
  
  -- Check for new song characteristics (not loaded from file)
  local is_new = true
  
  -- Primary check: loaded songs have filenames, new songs don't
  if song.file_name ~= "" then
    is_new = false
  end
  
  -- Secondary check: if instrument slots have samples loaded
  for i = 1, math.min(8, #song.instruments) do  -- Check first 8 instruments
    local instrument = song.instruments[i]
    if #instrument.samples > 0 then
      -- Check if any sample has actual content
      for _, sample in ipairs(instrument.samples) do
        if sample.sample_buffer.has_sample_data then
          is_new = false
          break
        end
      end
      if not is_new then break end
    end
  end
  
  -- Tertiary check: if pattern has been modified (contains notes)
  local pattern = song:pattern(1)
  for track_idx = 1, math.min(4, #song.tracks) do  -- Check first few tracks
    local track = pattern:track(track_idx)
    for line_idx = 1, math.min(64, pattern.number_of_lines) do
      local line = track:line(line_idx)
      for _, note_col in ipairs(line.note_columns) do
        if not note_col.is_empty then
          is_new = false
          break
        end
      end
      if not is_new then break end
    end
    if not is_new then break end
  end
  
  -- Quaternary check: if tracks have DSP devices beyond Vol/Pan/Width
  for i = 1, math.min(8, #song.tracks) do  -- Check first 8 tracks
    local track = song:track(i)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Check if track has more than 1 DSP device (first is always Vol/Pan/Width)
      if #track.devices > 1 then
        is_new = false
        break
      end
    end
  end
  
  -- Quinternary check: if song has been playing (edit position moved)  
  if song.transport.edit_pos.line > 1 then
    is_new = false
  end
  
  -- Note: BPM check removed as suggested - don't check if BPM is default
  
  return is_new
end

function startup()  
  if preferences.pakettiAlwaysOpenDSPsOnTrack.value then
    PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode()
  end

  if preferences.pakettiEditMode.value == 2 and renoise.song().transport.edit_mode then 
    for i = 1,#renoise.song().tracks do
      renoise.song().tracks[i].color_blend=0 
    end
--renoise.song().selected_track.color_blend = preferences.pakettiBlendValue.value

  end
   local s=renoise.song()
   local t=s.transport
      s.sequencer.keep_sequence_sorted=false
      if preferences.pakettiEnableGlobalGrooveOnStartup.value then
        t.groove_enabled=true
      end
      

      
      if preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad.value then 
      pakettiThemeSelectorPickRandomThemeFromAll()
      else if preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad.value then
    pakettiThemeSelectorRenoiseStartFavorites()
  end
  end
       shuffle_oblique_strategies()
 if PakettiAutomationDoofer==true then
 
  local masterTrack=renoise.song().sequencer_track_count+1
  monitor_doofer2_macros(renoise.song().tracks[masterTrack].devices[3])
  monitor_doofer1_macros(renoise.song().tracks[masterTrack].devices[2])
else end
end

-- Function to handle BPM randomization on new documents
-- This is called by app_new_document_observable for both new and loaded songs
function handleNewDocument()
  -- Only randomize BPM for fresh new songs, not loaded songs
  -- Uses pakettiIsNewSong() to distinguish between File->New vs File->Load
  if preferences.pakettiRandomizeBPMOnNewSong.value and pakettiIsNewSong() then
    math.randomseed(os.time())  -- Seed randomizer
    local random_bpm = pakettiGenerateBellCurveBPM()
    renoise.song().transport.bpm = random_bpm
    renoise.app():show_status(string.format("Paketti: Randomized BPM to %d (new song created)", random_bpm))
  end
end



if not renoise.tool().app_new_document_observable:has_notifier(startup)   
  then renoise.tool().app_new_document_observable:add_notifier(startup)
  else renoise.tool().app_new_document_observable:remove_notifier(startup) end

-- Add BPM randomization handler to new document observable
if not renoise.tool().app_new_document_observable:has_notifier(handleNewDocument)   
  then renoise.tool().app_new_document_observable:add_notifier(handleNewDocument)
  else renoise.tool().app_new_document_observable:remove_notifier(handleNewDocument) end  

-- Function to toggle global groove on startup preference
function pakettiToggleGlobalGrooveOnStartup()
  local prefs = renoise.tool().preferences
  prefs.pakettiEnableGlobalGrooveOnStartup.value = not prefs.pakettiEnableGlobalGrooveOnStartup.value
  local state = prefs.pakettiEnableGlobalGrooveOnStartup.value and "enabled" or "disabled"
  renoise.app():show_status("Global Groove on startup is now " .. state .. ".")
end

-- Function to toggle BPM randomization on new songs
function pakettiToggleRandomizeBPMOnNewSong()
  local prefs = renoise.tool().preferences
  prefs.pakettiRandomizeBPMOnNewSong.value = not prefs.pakettiRandomizeBPMOnNewSong.value
  local state = prefs.pakettiRandomizeBPMOnNewSong.value and "enabled" or "disabled"
  renoise.app():show_status("BPM randomization on new songs is now " .. state .. ".")
end

-- Function to manually randomize BPM (for testing or manual use)
function pakettiRandomizeBPMNow()
  math.randomseed(os.time())
  local random_bpm = pakettiGenerateBellCurveBPM()
  renoise.song().transport.bpm = random_bpm
  renoise.app():show_status(string.format("Paketti: Manually randomized BPM to %d", random_bpm))
end

--------


timed_require("rx")                          -- 2318 lines, 2.00 ms
timed_require("Paketti0G01_Loader")          -- 857 lines, 4.00 ms
--if renoise_version >= 3.4 then ]]--
timed_require("PakettieSpeak")               -- 930 lines, 4.00 ms
timed_require("PakettiPlayerProSuite")       -- 852 lines, 3.00 ms
--else
--  print("PakettieSpeak and PakettiPlayerProSuite require Renoise v3.4 or higher")
--end  
timed_require("PakettiChordsPlus")
timed_require("PakettiLaunchApp")
--timed_require("PakettiCustomization")        -- 61 lines, 0.50 ms
timed_require("PakettiDeviceChains")         -- 85 lines, 0.00 ms
timed_require("base64float")                 -- 203 lines, 0.00 ms
timed_require("PakettiLoadDevices")          -- 496 lines, 1.00 ms
timed_require("PakettiSandbox")              -- 352 lines, 0.50 ms
timed_require("PakettiTupletGenerator")      -- 386 lines, 0.50 ms
timed_require("PakettiLoadPlugins")          -- 534 lines, 0.50 ms
timed_require("PakettiPatternSequencer")     -- 47 lines, 0.50 ms
timed_require("PakettiPatternMatrix")        -- 176 lines, 0.50 ms
timed_require("PakettiInstrumentBox")        -- 280 lines, 0.50 ms
timed_require("PakettiYTDLP")               -- 854 lines, 1.00 ms
timed_require("PakettiStretch")              -- 925 lines, 1.50 ms
timed_require("PakettiBeatDetect")           -- 396 lines, 1.00 ms
timed_require("PakettiStacker")              -- 518 lines, 1.00 ms
timed_require("PakettiRecorder")             -- 403 lines, 1.00 ms

timed_require("PakettiFuzzySearchUtil")      -- New fuzzy search utility

timed_require("PakettiKeyBindings")          -- 1443 lines, 2.00 ms
timed_require("PakettiPhraseEditor")         -- 461 lines, 1.00 ms
timed_require("PakettiControls")             -- 544 lines, 1.00 ms
timed_require("PakettiOctaMEDSuite")         -- 601 lines, 1.00 ms
timed_require("PakettiWavetabler")           -- 223 lines, 0.50 ms
timed_require("PakettiAudioProcessing")      -- 1538 lines, 1.50 ms
timed_require("PakettiPatternEditorCheatSheet") -- 953 lines, 1.00 ms
timed_require("PakettiThemeSelector")        -- 516 lines, 4.50 ms
timed_require("PakettiMidiPopulator")        -- 531 lines, 1.00 ms
timed_require("PakettiImpulseTracker")       -- 2112 lines, 2.00 ms
timed_require("PakettiGater")                -- 1233 lines, 2.50 ms
timed_require("PakettiAutomation")           -- 2776 lines, 3.50 ms
timed_require("PakettiUnisonGenerator")      -- 122 lines, 0.00 ms
timed_require("PakettiMainMenuEntries")      -- 383 lines, 4.50 ms
timed_require("PakettiMidi")                 -- 1692 lines, 5.50 ms
timed_require("PakettiDynamicViews")         -- 703 lines, 9.00 ms
timed_require("PakettiEightOneTwenty")       -- 1457 lines, 4.50 ms
timed_require("PakettiExperimental_Verify")  -- 4543 lines, 8.50 ms
timed_require("PakettiLoaders")              -- 3137 lines, 9.00 ms
timed_require("PakettiPatternEditor")        -- 4583 lines, 11.50 ms
timed_require("PakettiTkna")                 -- 1495 lines, 23.00 ms
print ("REQUESTS LOADING")
timed_require("PakettiRequests")             -- 9168 lines, 127.00 ms
print ("REQUESTS LOADED")
timed_require("PakettiSamples")              -- 4249 lines, 6.00 ms
timed_require("Paketti35")
timed_require("PakettiActionSelector")
timed_require("Research/FormulaDeviceManual")
timed_require("PakettiXRNSProbe")
timed_require("PakettiAKWF")
timed_require("PakettiSteppers")
timed_require("PakettiREXLoader")
timed_require("PakettiRX2Loader")
timed_require("PakettiPTILoader")
timed_require("PakettiSF2Loader")
timed_require("process_slicer")
timed_require("PakettiProcess")
timed_require("PakettiSubColumnModifier")
timed_require("PakettiPatternLength")
timed_require("PakettiKeyzoneDistributor")
timed_require("PakettiHexSliceLoop")
timed_require("PakettiMergeInstruments")
timed_require("PakettiBPMToMS")
timed_require("PakettiGlobalGrooveToDelayValues")
timed_require("PakettiAmigoInspect")
timed_require("PakettiRePitch")
timed_require("PakettiPhraseGenerator")
timed_require("PakettiIFFLoader")
timed_require("PakettiMODLoader")
timed_require("PakettiPolyendSuite")
timed_require("PakettiXMLizer")
timed_require("PakettiDeviceValues")
--timed_require("PakettiAKAI")
timed_require("PakettiMIDIMappings")
timed_require("PakettiMIDIMappingCategories")
timed_require("legacy_v2_8_tools")
timed_require("PakettiPitchControl")
timed_require("hotelsinus_stepseq/hotelsinus_stepseq")
timed_require("PakettiTuningDisplay")
timed_require("PakettiOTExport")
timed_require("PakettiXIExport")
timed_require("PakettiOctaCycle")
timed_require("PakettiOTSTRDImporter")
timed_require("PakettiCCizerLoader")
timed_require("PakettiDigitakt")
timed_require("PakettiM8Export")
timed_require("PakettiOP1Export")
timed_require("PakettiForeignSnippets")
timed_require("PakettiManualSlicer")
timed_require("Sononymph/AppMain")
timed_require("PakettiChebyshevWaveshaper")
timed_require("PakettiMetricModulation")
timed_require("PakettiPresetPlusPlus")
timed_require("PakettiWTImport")
timed_require("PakettiXRNIT")
timed_require("PakettiImport")
timed_require("PakettiClearance")
timed_require("PakettiRoutings")
timed_require("PakettiViews")

-- Polyend functionality toggle
local PolyendYes = false
PolyendYes = true
-- Conditional Polyend functionality loading
if PolyendYes then
  timed_require("PakettiPolyendPatternData")
end

if renoise.API_VERSION >= 6.2 then
  timed_require("PakettiPCMWriter")
  --timed_require("PakettiZyklusMPS1")
  timed_require("PakettiCanvasExperiments")
  timed_require("PakettiNotepadRun")
end

timed_require("PakettiRender")
timed_require("PakettiOldschoolSlicePitch")

timed_require("PakettiAutocomplete")         -- Autocomplete dialog system

--always have this at the end: PakettiMenuConfig MUST be at the end. otherwise there will be errors.
timed_require("PakettiMenuConfig")
print(string.format("Total load time: %.3f seconds", os.clock() - init_time))

_AUTO_RELOAD_DEBUG = true




