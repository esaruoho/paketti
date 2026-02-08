local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix


-- Global variable to control timed_require debug output (default: disabled)
PakettiTimedRequireDebug = false

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
-- Helper function to create a vertical separator in ViewBuilder dialogs
-- Must be passed a ViewBuilder instance and returns the text view element
function vertsep(vb)
  return vb:text{text="|", font="bold", style="strong", width=8}
end

-- Convert decimal to hexadecimal string
-- Original from http://lua-users.org/lists/lua-l/2004-09/msg00054.html
function DEC_HEX(IN)
  local B,K,OUT,I,D=16,"0123456789ABCDEF","",0
  while IN>0 do
      I=I+1
      IN,D=math.floor(IN/B),(IN % B)+1
      OUT=string.sub(K,D,D)..OUT
  end
  return OUT
end

-- Debug print  
function dbug(msg)  
 local base_types = {  
 ["nil"]=true, ["boolean"]=true, ["number"]=true,  
 ["string"]=true, ["thread"]=true, ["table"]=true  
 }  
 if not base_types[type(msg)] then oprint(msg)  
 elseif type(msg) == 'table' then rprint(msg)  
 else print(msg) end  
end

-- Global function for truly random seeding - used throughout Paketti
function trueRandomSeed()
  math.randomseed(os.time())
  -- Add some additional random calls to further randomize the sequence
  math.random(); math.random(); math.random()
end

-- Global helper function to get proper temporary file path - fixes os.tmpname() issues
function pakettiGetTempFilePath(extension)
    extension = extension or ".tmp"
    local temp_dir = "/tmp"
    
    if os.platform() == "WINDOWS" then
        temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\temp"
    else
        temp_dir = os.getenv("TMPDIR") or "/tmp"
    end
    
    -- Generate unique filename with timestamp and random suffix
    local timestamp = tostring(os.time())
    local random_suffix = math.random(100000, 999999)
    local filename = string.format("paketti_temp_%s_%d%s", timestamp, random_suffix, extension)
    
    return temp_dir .. separator .. filename
end

-- Global helper function to generate values following different curve types
-- Used for slice marker placement, volume curves, pitch curves, etc.
-- Parameters:
--   startValue: Starting value (e.g., frame 1)
--   endValue: Ending value (e.g., total frames)
--   intervals: Number of values to generate
--   curveType: Type of curve (see below)
--   debug: Optional boolean to enable debug printing (default: false)
-- Curve types:
--   "linear"       - Even spacing from start to end
--   "logarithmic"  - Front-loaded (fast start, slow end)
--   "exponential"  - Back-loaded (slow start, fast end)
--   "downParabola" - U-shape (valley in middle)
--   "upParabola"   - Inverted U (peak in middle)
--   "doublePeak"   - Two peaks at 25% and 75%
--   "doubleValley" - Two valleys at 25% and 75%
-- Returns: Table of rounded integer values
function PakettiGenerateCurve(startValue, endValue, intervals, curveType, debug)
    debug = debug or false
    local result = {}
    local range = endValue - startValue
    
    if debug then
        print("PakettiGenerateCurve: Start=" .. tostring(startValue) .. 
              " End=" .. tostring(endValue) .. 
              " Intervals=" .. tostring(intervals) .. 
              " CurveType=" .. tostring(curveType))
    end
    
    -- Handle edge cases
    if intervals < 1 then
        if debug then print("PakettiGenerateCurve: No intervals requested") end
        return result
    end
    
    if intervals == 1 then
        table.insert(result, math.floor(startValue + 0.5))
        return result
    end
    
    for i = 0, intervals - 1 do
        local t = i / (intervals - 1)
        local value
        
        if curveType == "linear" then
            -- Even spacing
            value = startValue + t * range
            
        elseif curveType == "logarithmic" then
            -- Front-loaded: more values clustered near start
            value = startValue + math.log(1 + t) / math.log(2) * range
            
        elseif curveType == "exponential" then
            -- Back-loaded: more values clustered near end
            value = startValue + (math.exp(t) - 1) / (math.exp(1) - 1) * range
            
        elseif curveType == "downParabola" then
            -- U-shape: valley in middle
            value = startValue + 4 * range * (t - 0.5)^2
            
        elseif curveType == "upParabola" then
            -- Inverted U: peak in middle
            value = endValue - 4 * range * (t - 0.5)^2
            
        elseif curveType == "doublePeak" then
            -- Two peaks at t=0.25 and t=0.75, valleys at t=0, t=0.5, t=1
            value = startValue + range * math.abs(math.sin(t * 2 * math.pi))
            
        elseif curveType == "doubleValley" then
            -- Two valleys at t=0.25 and t=0.75, peaks at t=0, t=0.5, t=1
            value = startValue + range * (1 - math.abs(math.sin(t * 2 * math.pi)))
            
        else
            -- Default to linear if unknown curve type
            if debug then print("PakettiGenerateCurve: Unknown curve type '" .. tostring(curveType) .. "', using linear") end
            value = startValue + t * range
        end
        
        local rounded = math.floor(value + 0.5)
        table.insert(result, rounded)
        
        if debug then
            print(string.format("  [%d] t=%.3f value=%.2f rounded=%d", i + 1, t, value, rounded))
        end
    end
    
    if debug then
        print("PakettiGenerateCurve: Generated " .. #result .. " values")
    end
    
    return result
end

-- List of available curve types for UI selectors
PakettiCurveTypes = {
    "linear",
    "logarithmic", 
    "exponential",
    "downParabola",
    "upParabola",
    "doublePeak",
    "doubleValley"
}

-- Human-readable curve type descriptions for UI
PakettiCurveDescriptions = {
    linear = "Linear (even spacing)",
    logarithmic = "Logarithmic (front-loaded)",
    exponential = "Exponential (back-loaded)",
    downParabola = "Down Parabola (U-shape)",
    upParabola = "Up Parabola (inverted U)",
    doublePeak = "Double Peak (two peaks)",
    doubleValley = "Double Valley (two valleys)"
}

local init_time = os.clock()
-- Function to check if an instrument uses effects or has an empty FX chain and adjust name accordingly
function align_instrument_names()
  local song=renoise.song()
  
  for _, instrument in ipairs(song.instruments) do
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

-- Optimized formatDigits with cached format strings
local formatDigitsCache = {}

function formatDigits(digits, number)
  -- Fast path for the most common case (digits = 3)
  if digits == 3 then
    return string.format("%03d", number)
  end
  
  -- Use cached format string for other cases
  local format_string = formatDigitsCache[digits]
  if not format_string then
    format_string = "%0" .. digits .. "d"
    formatDigitsCache[digits] = format_string
  end
  
  return string.format(format_string, number)
end

-- Even faster specialized function for 3-digit formatting
function formatDigits3(number)
  return string.format("%03d", number)
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
    local file_path = renoise.tool().bundle_path .. separator .. module_name .. ".lua"

    if PakettiTimedRequireDebug then
        local start_time = os.clock()

        -- Count lines in the file (only when debug is enabled)
        local line_count = 0
        local file = io.open(file_path, "r")
        if file then
            for _ in file:lines() do
                line_count = line_count + 1
            end
            file:close()
        end

        -- Load the module from local file and time it
        dofile(file_path)
        local elapsed = (os.clock() - start_time) * 1000 -- convert to milliseconds
        print(string.format("%s, %d lines, %.2f ms", module_name, line_count, elapsed))
    else
        -- Fast path: just load the module, no timing or line counting
        dofile(file_path)
    end
end

if PakettiTimedRequireDebug then
    print("---------------------")
end

-- Helper function to create a keyhandler that can manage a specific dialog variable
function create_keyhandler_for_dialog(dialog_var_getter, dialog_var_setter)
  return function(dialog, key)
    local closer = preferences.pakettiDialogClose.value
    print("KEYHANDLER DEBUG: name:'" .. tostring(key.name) .. "' modifiers:'" .. tostring(key.modifiers) .. "' closer:'" .. tostring(closer) .. "'")
    
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
  print("KEYHANDLER DEBUG: name:'" .. tostring(key.name) .. "' modifiers:'" .. tostring(key.modifiers) .. "' closer:'" .. tostring(closer) .. "'")
  
  if key.modifiers == "" and key.name == closer then
    -- Clean up any observers that might exist
    --print("YO i got " .. closer)
    if cleanup_observers then
      cleanup_observers()
    end
    dialog:close()
    return nil
  else
    return key
  end
end

-- Helper function to print which sub-column is currently selected
function whichSubcolumn()
  local song = renoise.song()
  local sub_column_type = song.selected_sub_column_type
  local sub_column_name = "Unknown"
  
  if sub_column_type == renoise.Song.SUB_COLUMN_NOTE then
    sub_column_name = "Note"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_INSTRUMENT then
    sub_column_name = "Instrument"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
    sub_column_name = "Volume"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
    sub_column_name = "Panning"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
    sub_column_name = "Delay"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
    sub_column_name = "Sample Effect Number"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    sub_column_name = "Sample Effect Amount"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
    sub_column_name = "Effect Number"
  elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
    sub_column_name = "Effect Amount"
  end
  
  print("Current sub-column: " .. sub_column_name .. " (type: " .. tostring(sub_column_type) .. ")")
  return sub_column_type, sub_column_name
end

-- Add menu entry and keybinding for whichSubcolumn function
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Which Sub-Column?", invoke=whichSubcolumn}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Which Sub-Column?", invoke=whichSubcolumn}

-- Function to toggle timed_require debug output
function pakettiToggleTimedRequireDebug()
    PakettiTimedRequireDebug = not PakettiTimedRequireDebug
    local state = PakettiTimedRequireDebug and "enabled" or "disabled"
    renoise.app():show_status("Timed require debug output is now " .. state .. ". Restart Paketti to see changes.")
end

-- Add menu entry and keybinding for timed_require debug toggle
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Toggle Timed Require Debug", invoke=pakettiToggleTimedRequireDebug}
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Timed Require Debug", invoke=pakettiToggleTimedRequireDebug}


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

-- Renoise instrument limit constant
RENOISE_MAX_INSTRUMENTS = 255

-- Check if we can insert more instruments (hasn't reached the 255 limit)
function canInsertInstrument()
  return #renoise.song().instruments < RENOISE_MAX_INSTRUMENTS
end

-- Safe wrapper for insert_instrument_at that checks the limit first
-- Returns the new instrument if successful, nil if at limit
function safeInsertInstrumentAt(song, index)
  if #song.instruments >= RENOISE_MAX_INSTRUMENTS then
    renoise.app():show_status("Cannot insert instrument: maximum of 255 instruments reached")
    return nil
  end
  return song:insert_instrument_at(index)
end

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
    
    -- print(string.format("PakettiGetAllLuaFiles: Found %d .lua files", #files))
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

-- =============================================================================
-- PakettiOnNewDocument: SINGLE consolidated handler for app_new_document_observable
-- Replaces the previous 3 separate handlers: startup_(), startup(), handleNewDocument()
-- =============================================================================
function PakettiOnNewDocument()
  local song = renoise.song()
  local transport = song.transport

  -- 1. BPM randomization for NEW songs only (not loaded songs)
  if preferences.pakettiRandomizeBPMOnNewSong.value and pakettiIsNewSong() then
    math.randomseed(os.time())
    local random_bpm = pakettiGenerateBellCurveBPM()
    transport.bpm = random_bpm
    renoise.app():show_status(string.format("Paketti: Randomized BPM to %d (new song created)", random_bpm))
  end

  -- 2. Set instrument active tab to 1 (Samples tab)
  -- TODO: Make this a preference (pakettiSetInstrumentActiveTabOnStartup) to allow user control
  -- song.instruments[song.selected_instrument_index].active_tab = 1

  -- 3. Auto-open DSP external editors if preference enabled
  if preferences.pakettiAlwaysOpenDSPsOnTrack.value then
    PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode()
  end

  -- 4. Auto-open Sample FX chain devices if preference enabled
  if preferences.pakettiAlwaysOpenSampleFXChainDevices.value then
    PakettiInitializeSampleFXChainAutoOpen()
  end

  -- 5. Reset track color blends for edit mode preference
  if preferences.pakettiEditMode.value == 2 and transport.edit_mode then
    for i = 1, #song.tracks do
      song.tracks[i].color_blend = 0
    end
  end

  -- 6. Apply Keep Sequence Sorted preference
  if preferences.pakettiKeepSequenceSorted.value == 1 then
    song.sequencer.keep_sequence_sorted = false
    print("Paketti: Keep Sequence Sorted set to false on startup")
  elseif preferences.pakettiKeepSequenceSorted.value == 2 then
    song.sequencer.keep_sequence_sorted = true
    print("Paketti: Keep Sequence Sorted set to true on startup")
  end
  -- Mode 0 (Do Nothing) - don't modify the setting

  -- 7. Enable global groove if preference enabled
  if preferences.pakettiEnableGlobalGrooveOnStartup.value then
    transport.groove_enabled = true
  end

  -- 8. Load marker position from preferences
  -- TODO: Consider making this preference-gated (pakettiLoadMarkerOnStartup)
  if type(PakettiLoadMarkerFromPreferences) == "function" then
    PakettiLoadMarkerFromPreferences()
  end

  -- 9. Initialize Pattern Status Monitor from preference
  PakettiPatternStatusMonitorEnabled = preferences.pakettiPatternStatusMonitor.value
  if PakettiPatternStatusMonitorEnabled then
    enable_pattern_status_monitor()
  end

  -- 10. Initialize Follow Page Pattern from preference
  if type(PakettiFollowPagePatternOnNewDocument) == "function" then
    PakettiFollowPagePatternOnNewDocument()
  end

  -- 11. Initialize Audition on Line Change from preference (API 6.2+ only)
  if renoise.API_VERSION >= 6.2 and preferences.pakettiAuditionOnLineChangeEnabled then
    PakettiAuditionOnLineChangeEnabled = preferences.pakettiAuditionOnLineChangeEnabled.value
    if PakettiAuditionOnLineChangeEnabled then
      PakettiToggleAuditionCurrentLineOnRowChange()
    end
  end

  -- 12. Initialize PlayerPro Always Open Dialog system (only if preference enabled)
  if preferences.pakettiPlayerProAlwaysOpen and preferences.pakettiPlayerProAlwaysOpen.value then
    if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      pakettiPlayerProInitializeAlwaysOpen()
    else
      pakettiPlayerProStartMiddleFrameObserver()
    end
  end

  -- 13. Initialize Automatic Rename Track system
  if preferences.pakettiAutomaticRenameTrack.value then
    pakettiStartAutomaticRenameTrack()
  end

  -- 14. Load random/favorite theme if preference enabled
  if preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad.value then
    pakettiThemeSelectorPickRandomThemeFromAll()
  elseif preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad.value then
    pakettiThemeSelectorRenoiseStartFavorites()
  end

  -- 15. Show oblique strategies if preference enabled
  if preferences.pakettiObliqueStrategiesOnStartup.value then
    shuffle_oblique_strategies()
  end

  -- 16. Monitor Doofer macros (if enabled)
  if PakettiAutomationDoofer == true then
    local masterTrack = song.sequencer_track_count + 1
    monitor_doofer2_macros(song.tracks[masterTrack].devices[3])
    monitor_doofer1_macros(song.tracks[masterTrack].devices[2])
  end
end

-- Register the SINGLE consolidated handler (no else branch that removes!)
if not renoise.tool().app_new_document_observable:has_notifier(PakettiOnNewDocument) then
  renoise.tool().app_new_document_observable:add_notifier(PakettiOnNewDocument)
end  

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

-- Automatic Rename Track system
local automatic_rename_timer_func = nil
local last_rename_time = 0

function pakettiStartAutomaticRenameTrack()
  -- Stop any existing timer first
  pakettiStopAutomaticRenameTrack()
  
  -- Do initial scan of ALL tracks when first enabled
  if type(rename_tracks_by_played_samples) == "function" then
    rename_tracks_by_played_samples()
  end
  
  -- Create the timer function and store the reference BEFORE adding as notifier
  automatic_rename_timer_func = function()
    local current_time = os.clock()
    
    -- Only run every 200ms (0.2 seconds)
    if current_time - last_rename_time >= 0.2 then
      last_rename_time = current_time
      
      -- Only run if the function exists (PakettiMidi.lua is loaded)
      -- Use the selected track version for continuous monitoring
      if type(rename_selected_track_by_played_samples) == "function" then
        rename_selected_track_by_played_samples()
      end
    end
  end
  
  -- Add the stored function reference as notifier
  renoise.tool().app_idle_observable:add_notifier(automatic_rename_timer_func)
end

function pakettiStopAutomaticRenameTrack()
  if automatic_rename_timer_func then
    if renoise.tool().app_idle_observable:has_notifier(automatic_rename_timer_func) then
      renoise.tool().app_idle_observable:remove_notifier(automatic_rename_timer_func)
    end
    automatic_rename_timer_func = nil
  end
end

function pakettiToggleAutomaticRenameTrack()
  preferences.pakettiAutomaticRenameTrack.value = not preferences.pakettiAutomaticRenameTrack.value
  
  if preferences.pakettiAutomaticRenameTrack.value then
    pakettiStartAutomaticRenameTrack()
    renoise.app():show_status("Automatic Rename Track enabled")
  else
    pakettiStopAutomaticRenameTrack()
    renoise.app():show_status("Automatic Rename Track disabled")
  end
end


function pakettiToggleSelectTrackSelectInstrument()
  preferences.PakettiSelectTrackSelectInstrument.value = not preferences.PakettiSelectTrackSelectInstrument.value
  
  if preferences.PakettiSelectTrackSelectInstrument.value then
    renoise.app():show_status("Select Track Selects Instrument enabled")
  else
    renoise.app():show_status("Select Track Selects Instrument disabled")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Select Track Selects Instrument",invoke=function() pakettiToggleSelectTrackSelectInstrument() end}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Select Track Selects Instrument",invoke=function(message) if message:is_trigger() then pakettiToggleSelectTrackSelectInstrument() end end}

--------
-- Global helper function to find Volume AHDSR device in an instrument
-- Returns the device object if found, nil otherwise
-- This is defined globally in main.lua so ALL modules can use it regardless of load order
function find_volume_ahdsr_device(instrument)
  if not instrument or not instrument.sample_modulation_sets or #instrument.sample_modulation_sets == 0 then
    return nil
  end
  
  -- Search through all modulation sets and their devices
  for _, mod_set in ipairs(instrument.sample_modulation_sets) do
    if mod_set.devices then
      for _, device in ipairs(mod_set.devices) do
        if device.name == "Volume AHDSR" then
          return device
        end
      end
    end
  end
  
  return nil
end
--------
timed_require("rx")
timed_require("base64float")
timed_require("Paketti0G01_Loader")

-- ============================================================================
-- CONDITIONAL REGISTRATION WRAPPERS
-- These wrap the original registration functions to check master toggles
-- Must be set up AFTER Paketti0G01_Loader (preferences) but BEFORE other modules
-- ============================================================================

-- Store original functions
local original_add_keybinding = renoise.tool().add_keybinding
local original_add_midi_mapping = renoise.tool().add_midi_mapping

-- Global counters for what actually gets registered
PakettiActualRegistrations = {
  keybindings = 0,
  keybindings_skipped = 0,
  midi_mappings = 0,
  midi_mappings_skipped = 0
}

-- Wrapped add_keybinding that checks master toggle
function PakettiWrappedAddKeybinding(tool, args)
  if PakettiShouldRegisterKeybindings and PakettiShouldRegisterKeybindings() then
    original_add_keybinding(tool, args)
    PakettiActualRegistrations.keybindings = PakettiActualRegistrations.keybindings + 1
    return true
  else
    PakettiActualRegistrations.keybindings_skipped = PakettiActualRegistrations.keybindings_skipped + 1
    return false
  end
end

-- Wrapped add_midi_mapping that checks master toggle  
function PakettiWrappedAddMidiMapping(tool, args)
  if PakettiShouldRegisterMidiMappings and PakettiShouldRegisterMidiMappings() then
    original_add_midi_mapping(tool, args)
    PakettiActualRegistrations.midi_mappings = PakettiActualRegistrations.midi_mappings + 1
    return true
  else
    PakettiActualRegistrations.midi_mappings_skipped = PakettiActualRegistrations.midi_mappings_skipped + 1
    return false
  end
end

-- Replace the methods on the tool object
-- Note: This only affects calls made AFTER this point
renoise.tool().add_keybinding = function(self, args)
  return PakettiWrappedAddKeybinding(self, args)
end

renoise.tool().add_midi_mapping = function(self, args)
  return PakettiWrappedAddMidiMapping(self, args)
end

-- ============================================================================

timed_require("PakettieSpeak")
timed_require("PakettiChordsPlus")
timed_require("PakettiLaunchApp")
timed_require("PakettiDeviceChains")
timed_require("PakettiExecute")
timed_require("PakettiLoadDevices")
timed_require("PakettiSandbox")
timed_require("PakettiTupletGenerator")
timed_require("PakettiLoadPlugins")
timed_require("PakettiPatternSequencer")
timed_require("PakettiFollowPagePattern")
timed_require("PakettiPatternNameLoop")
timed_require("PakettiWonkify")
timed_require("PakettiPatternMatrix")
timed_require("PakettiInstrumentBox")
timed_require("PakettiYTDLP")
timed_require("PakettiStretch")
timed_require("PakettiStacker")
timed_require("PakettiRecorder")
timed_require("PakettiHoldToFill")
timed_require("PakettiFuzzySearchUtil")
timed_require("PakettiFuzzySampleSearch")
timed_require("PakettiKeyBindings")

-- Phrase-related modules require API 6.2+ (Renoise 3.5.4+)
if renoise.API_VERSION >= 6.2 then
  timed_require("PakettiPhraseEditor")
  timed_require("PakettiPhraseWorkflow")
  timed_require("PakettiPhraseTransportRecording")
end

timed_require("PakettiControls")
timed_require("PakettiWavetabler")
timed_require("PakettiAKWF")

--- Other trackers
timed_require("PakettiImpulseTracker")
timed_require("PakettiPlayerProSuite")
timed_require("PakettiOctaMEDSuite")
timed_require("PakettiClipboard")

timed_require("PakettiBeatDetect")

timed_require("PakettiAudioProcessing")
timed_require("PakettiPatternEditorCheatSheet")
timed_require("PakettiZDxx")
timed_require("PakettiThemeSelector")
timed_require("PakettiMidiPopulator")
timed_require("PakettiGater")
timed_require("PakettiAutomation")
timed_require("PakettiAutomationCurves")
timed_require("PakettiAutomateLastTouched")
timed_require("PakettiUnisonGenerator")
timed_require("PakettiMainMenuEntries")
timed_require("PakettiMidi")
timed_require("PakettiDynamicViews")

timed_require("PakettiExperimental_Verify")
timed_require("PakettiExperimental_BlockLoopFollow")
timed_require("PakettiFill")
timed_require("PakettiLoaders")
timed_require("PakettiPatternEditor")
timed_require("PakettiTkna")
timed_require("PakettiSamples")
timed_require("PakettiStemLoader")
timed_require("PakettiMPCCycler")
timed_require("PakettiSlicePro")
timed_require("PakettiSliceSafely")
timed_require("PakettiSampleFXChainSlicer")
timed_require("PakettiZeroCrossings")
timed_require("Research/FormulaDeviceManual")
timed_require("PakettiXRNSProbe")
timed_require("PakettiSteppers")
timed_require("PakettiPatternIterator")
timed_require("PakettiPatternDelayViewer")


--- File Import / Export business
timed_require("PakettiREXLoader")
timed_require("PakettiRX2Loader")
timed_require("PakettiIFFLoader")
timed_require("PakettiWavCueExtract")
timed_require("PakettiVideoSlicer")

timed_require("PakettiSF2Loader")

timed_require("PakettiMODLoader")
timed_require("PakettiITIImport")
timed_require("PakettiITIExport")
timed_require("PakettiOTExport")
timed_require("PakettiXIExport")
timed_require("PakettiWTImport")


timed_require("process_slicer")
timed_require("PakettiProcess")
timed_require("PakettiSubColumnModifier")
timed_require("PakettiPatternLength")
timed_require("PakettiKeyzoneDistributor")
timed_require("PakettiHexSliceLoop")
timed_require("PakettiMergeInstruments")
timed_require("PakettiGlobalGrooveToDelayValues")
timed_require("PakettiAmigoInspect")
timed_require("PakettiRePitch")
timed_require("PakettiXMLizer")
timed_require("PakettiDeviceValues")
timed_require("PakettiCommandWheel")
timed_require("PakettiMIDIMappings")
timed_require("PakettiMIDIMappingCategories")
timed_require("legacy_v2_8_tools")
timed_require("PakettiPitchControl")
timed_require("hotelsinus_stepseq/hotelsinus_stepseq")
timed_require("PakettiTuningDisplay")
timed_require("PakettiOctaCycle")
timed_require("PakettiOTSTRDImporter")
timed_require("PakettiCCizerLoader")
timed_require("PakettiDigitakt")
--timed_require("PakettiM8Export")
--timed_require("PakettiOP1Export")
timed_require("PakettiForeignSnippets")
timed_require("PakettiManualSlicer")
timed_require("Sononymph/AppMain")
timed_require("PakettiChebyshevWaveshaper")
timed_require("PakettiMetricModulation")
timed_require("PakettiPresetPlusPlus")
timed_require("PakettiXRNIT")
-- PakettiImport moved to load last (before PakettiMenuConfig) for centralized import hook registration
timed_require("PakettiClearance")
timed_require("PakettiRoutings")
timed_require("PakettiViews")
timed_require("PakettiMixerParameterExposer")
timed_require("PakettiTransposeBlock")
timed_require("PakettiBeatstructureEditor")
timed_require("PakettiSlice")
timed_require("PakettiCaptureLastTake")
timed_require("PakettiTrackInstrumentOrganize")

timed_require("PakettiOpenMPTLinearKeyboardLayer")
timed_require("PakettiGlider")
timed_require("PakettiSlabOPatterns")
timed_require("PakettiSwitcharoo")
timed_require("PakettiChords")
timed_require("PakettiPTILoader")
timed_require("PakettiPolyendSuite")
timed_require("PakettiPolyendSliceSwitcher")
timed_require("PakettiPolyendMelodicSliceExport")
-- TODO: PakettiPolyendPatternData is disabled by default until ready for use
-- Set to true to enable Polyend pattern data export functionality
local PakettiPolyendPatternDataEnabled = true
if PakettiPolyendPatternDataEnabled then
  timed_require("PakettiPolyendPatternData")
end

if renoise.API_VERSION >= 6.2 then
  timed_require("Paketti35")
  timed_require("PakettiArpeggiator")
  timed_require("PakettiPCMWriter")
  timed_require("PakettiImageToSample")
  --timed_require("PakettiZyklusMPS1")
  timed_require("PakettiCanvasFont")
  timed_require("PakettiCanvasFontPreview")
  timed_require("PakettiCanvasExperiments")
  timed_require("PakettiSampleEffectGenerator")
  timed_require("PakettiNotepadRun")
  timed_require("PakettiEQ30")
  timed_require("PakettiSliceEffectStepSequencer")
  timed_require("PakettiHyperEdit")
  timed_require("PakettiEquationCalculator")
  timed_require("PakettiMultitapExperiment")
  timed_require("PakettiPlayerProWaveformViewer")
  timed_require("PakettiAutomationStack")
  timed_require("PakettiPhraseGenerator")  -- Enhanced headless phrase generator uses phrase.script (6.2+)
else
  -- Fallback stub for PCMWriter functions on older API versions
  -- Always returns false so AutoSamplify works normally on non-6.2
  function PCMWriterIsCreatingSamples()
    return false
  end
  function PCMWriterSetCreatingSamples(creating)
    -- No-op on older versions
  end
end


--timed_require("PakettiExperimentalDialog")
timed_require("PakettiMetaSynth")
timed_require("PakettiRequests")
timed_require("PakettiAutoSamplify")
timed_require("PakettiInstrumentTranspose")
timed_require("PakettiRender")
timed_require("PakettiBPM")
timed_require("PakettiFrameCalculator")
timed_require("PakettiStemSlicer")
timed_require("PakettiOldschoolSlicePitch")
timed_require("PakettiActionSelector")
timed_require("PakettiAutocomplete")
--timed_require("PakettiTreeStructure")
--timed_require("PakettiCustomization")        -- 61 lines, 0.50 ms
--timed_require("PakettiAKAI")

timed_require("PakettiEightOneTwenty")

-- PakettiImport MUST be loaded after all other modules so their loader functions are available
-- This centralizes all file import hook registrations with preference checks
timed_require("PakettiImport")

--always have this at the end: PakettiMenuConfig MUST be at the end. otherwise there will be errors.
timed_require("PakettiMenuConfig")

-- Initialize Zero Crossings auto-snap system (must be called after all modules are loaded)
if PakettiZeroCrossingsInitAutoSnap then
  PakettiZeroCrossingsInitAutoSnap()
end

local total_time = os.clock() - init_time
if PakettiTimedRequireDebug then
    print(string.format("Total load time: %.2f ms (%.3f seconds)", total_time * 1000, total_time))
end

-- Log registration counts on startup
local function PakettiLogStartupCounts()
  -- Use the counting function from Paketti0G01_Loader
  if PakettiCountRegistrations then
    local counts = PakettiCountRegistrations()
    print("-------------------------------------------")
    print("PAKETTI LOADED SUCCESSFULLY")
    print("-------------------------------------------")
    print("Source File Counts:")
    print(string.format("  Menu Entries:   %d in code (%d commented)", counts.menus, counts.menus_commented))
    print(string.format("  Keybindings:    %d in code (%d commented)", counts.keybindings, counts.keybindings_commented))
    print(string.format("  MIDI Mappings:  %d in code (%d commented)", counts.midi_mappings, counts.midi_mappings_commented))
    print("-------------------------------------------")
    
    -- Show actual registrations (what was actually registered based on toggles)
    if PakettiActualRegistrations then
      print("Actual Registrations (based on master toggles):")
      print(string.format("  Keybindings:    %d registered, %d skipped", 
        PakettiActualRegistrations.keybindings, 
        PakettiActualRegistrations.keybindings_skipped))
      print(string.format("  MIDI Mappings:  %d registered, %d skipped", 
        PakettiActualRegistrations.midi_mappings, 
        PakettiActualRegistrations.midi_mappings_skipped))
      print("-------------------------------------------")
    end
    
    -- Also show master toggle status
    if preferences and preferences.pakettiMenuConfig then
      local menus_status = "ON"
      local keys_status = "ON"
      local midi_status = "ON"
      
      if preferences.pakettiMenuConfig.MasterMenusEnabled and not preferences.pakettiMenuConfig.MasterMenusEnabled.value then
        menus_status = "OFF"
      end
      if preferences.pakettiMenuConfig.MasterKeybindingsEnabled and not preferences.pakettiMenuConfig.MasterKeybindingsEnabled.value then
        keys_status = "OFF"
      end
      if preferences.pakettiMenuConfig.MasterMidiMappingsEnabled and not preferences.pakettiMenuConfig.MasterMidiMappingsEnabled.value then
        midi_status = "OFF"
      end
      
      print(string.format("Master Toggles: Menus=%s, Keys=%s, MIDI=%s", menus_status, keys_status, midi_status))
      print("-------------------------------------------")
    end
  else
    print("Paketti: PakettiCountRegistrations function not available")
  end
end

-- Run startup logging
PakettiLogStartupCounts()

-- Function to randomly pick a Paketti feature for documentation
function pakettiRandomFeatureForDocumentation()
  trueRandomSeed()
  
  local lua_files = PakettiGetAllLuaFiles()
  local bundle_path = renoise.tool().bundle_path
  local all_features = {}
  
  -- Parse each lua file for registrations
  for _, lua_file in ipairs(lua_files) do
    local file_path = bundle_path .. lua_file .. ".lua"
    local file = io.open(file_path, "r")
    
    if file then
      local content = file:read("*all")
      file:close()
      
      -- More flexible pattern matching that handles multiline and various formats
      -- Just match add_menu_entry/add_keybinding/add_midi_mapping regardless of what comes before
      
      -- Find all add_menu_entry with name parameter
      for name in content:gmatch('add_menu_entry%s*{[^}]-name%s*=%s*"([^"]+)"') do
        table.insert(all_features, {type = "Menu Entry", name = name, file = lua_file})
      end
      
      -- Find all add_keybinding with name parameter
      for name in content:gmatch('add_keybinding%s*{[^}]-name%s*=%s*"([^"]+)"') do
        table.insert(all_features, {type = "Keybinding", name = name, file = lua_file})
      end
      
      -- Find all add_midi_mapping with name parameter
      for name in content:gmatch('add_midi_mapping%s*{[^}]-name%s*=%s*"([^"]+)"') do
        table.insert(all_features, {type = "MIDI Mapping", name = name, file = lua_file})
      end
    end
  end
  
  if #all_features == 0 then
    print("No Paketti features found!")
    return
  end
  
  -- Pick random feature
  local feature = all_features[math.random(1, #all_features)]
  local short_name = feature.name:match(".*:(.+)$") or feature.name
  
  -- Strip ... suffixes for comparison purposes
  local function strip_for_comparison(name)
    -- Remove trailing ... (dialog indicator)
    return name:gsub("%.%.%.$", "")
  end
  
  local short_name_clean = strip_for_comparison(short_name)
  
  -- Find ALL registrations with the same short name (ignoring ... markers)
  local related_features = {}
  for _, f in ipairs(all_features) do
    local f_short = f.name:match(".*:(.+)$") or f.name
    local f_short_clean = strip_for_comparison(f_short)
    if f_short_clean == short_name_clean then
      table.insert(related_features, f)
    end
  end
  
  print("----------------------------------------")
  print("RANDOM PAKETTI FEATURE FOR DOCUMENTATION")
  --print("----------------------------------------")
  print("Feature: " .. short_name)
  print("")
  print("All Registrations (" .. #related_features .. "):")
  for _, f in ipairs(related_features) do
    print("  [" .. f.type .. "] " .. f.name .. " (" .. f.file .. ".lua)")
  end
  print("----------------------------------------")
  
  renoise.app():show_status(string.format("Random: %s (%d registrations)", short_name, #related_features))
end

renoise.tool():add_keybinding{name="Global:Paketti:Random Feature for Documentation", invoke=pakettiRandomFeatureForDocumentation}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Random Feature for Documentation", invoke=pakettiRandomFeatureForDocumentation}

-- Auto-run random feature picker at startup (for development/documentation purposes)
-- GitHub Actions changes this to false during release builds.
_PAKETTI_RANDOM_FEATURE_ON_STARTUP = true
if _PAKETTI_RANDOM_FEATURE_ON_STARTUP then
  pakettiRandomFeatureForDocumentation()
end

-- Auto-reload debug: Set to true during development to auto-reload tool when files change.
-- GitHub Actions changes this to false during release builds.
-- WARNING: When true, any file save triggers full tool reload which re-executes all notifiers.
_AUTO_RELOAD_DEBUG = true

-- Initialize Block Loop Follow based on preference
if preferences.PakettiBlockLoopFollowEnabled.value and type(PakettiBlockLoopFollowEnable) == "function" then
  PakettiBlockLoopFollowEnable()
end

--dbug(renoise.song())
-- Added: PakettiSelectNextInstrument, PakettiSelectPreviousInstrument
