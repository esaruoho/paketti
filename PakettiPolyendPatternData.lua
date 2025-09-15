-- PakettiPolyendPatternData.lua
-- Polyend Pattern Data functionality for Paketti
-- Import Polyend Tracker patterns and projects into Renoise
local vb = renoise.ViewBuilder()
local bit = require("bit")
local separator = package.config:sub(1,1)

-- Dialog variables
local pattern_dialog = nil
local project_dialog = nil
local selected_polyend_path = ""
local available_patterns = {}
local available_projects = {}

-- Constants for Polyend format based on official documentation
local POLYEND_CONSTANTS = {
    -- Pattern metadata file
    PAMD_IDENTIFIER = "PAMD",
    PAMD_VERSION = 1,
    PATTERN_NAME_LENGTH = 30,
    PATTERN_RECORD_SIZE = 50,
    
    -- Pattern file constants
    PATTERN_TYPE = 2,
    FILE_STRUCTURE_VERSION = 5,
    STEP_COUNT = 128,
    TRACK_COUNTS = {8, 12, 16}, -- Old, OG, Mini/Plus
    
    -- Special note values  
    NOTE_EMPTY = -1,
    NOTE_OFF_FADE = -2,
    NOTE_OFF_CUT = -3,
    NOTE_OFF = -4,
    
    -- Polyend FX types (these are Polyend-specific, most don't map to Renoise)
    FX_NAMES = {
        [0] = "None",
        [1] = "Off", 
        [2] = "Micro-move",
        [3] = "Roll",
        [4] = "Chance", 
        [5] = "Random Note",
        [6] = "Random Instrument",
        [7] = "Random Volume",
        [8] = "Send CC A",
        [9] = "Send CC B", 
        [10] = "Send CC C",
        [11] = "Send CC D",
        [12] = "Send CC E", 
        [13] = "Break Pattern",
        [14] = "MIDI Chord",
        [15] = "Tempo",
        [16] = "Random FX Value",
        [17] = "Swing", 
        [18] = "Volume/Velocity",
        [19] = "Glide",
        [20] = "Gate Length",
        [21] = "Arp",
        [22] = "Position",
        [23] = "Volume LFO",
        [24] = "Panning LFO", 
        [25] = "Sample Slice",
        [26] = "Reverse Playback",
        [27] = "Filter Low-pass",
        [28] = "Filter High-pass",
        [29] = "Filter Band-pass",
        [30] = "Delay Send",
        [31] = "Panning",
        [32] = "Reverb Send",
        [33] = "Finetune LFO", 
        [34] = "Micro-tune/Pitchbend",
        [35] = "Filter LFO",
        [36] = "Position LFO",
        [37] = "Send CC F",
        [38] = "Overdrive",
        [39] = "Bit Depth",
        [40] = "Tune",
        [41] = "Slide Up",
        [42] = "Slide Down"
    },
    
    FX_SYMBOLS = {
        [0] = "-", [1] = "!", [2] = "m", [3] = "R", [4] = "C", [5] = "n", [6] = "i", [7] = "v",
        [8] = "a", [9] = "b", [10] = "c", [11] = "d", [12] = "e", [13] = "x", [14] = "0", [15] = "T",
        [16] = "x", [17] = "I", [18] = "V", [19] = "G", [20] = "q", [21] = "A", [22] = "p", [23] = "g", 
        [24] = "h", [25] = "S", [26] = "r", [27] = "L", [28] = "H", [29] = "B", [30] = "s", [31] = "P",
        [32] = "t", [33] = "l", [34] = "M", [35] = "j", [36] = "k", [37] = "f", [38] = "D", [39] = "E",
        [40] = "U", [41] = "F", [42] = "J"
    }
}

-- Helper function to check if path exists
local function check_polyend_path_exists(path)
    if not path or path == "" then
        return false
    end
    
    local test_file = io.open(path, "r")
    if test_file then
        test_file:close()
        return true
    end
    
    -- Try as directory
    local success = pcall(function()
        local files = os.filenames(path, "*")
        return files ~= nil
    end)
    
    return success
end

-- Helper function to get project root path
local function get_polyend_project_root()
    if preferences and preferences.PolyendRoot and preferences.PolyendRoot.value then
        local path = preferences.PolyendRoot.value
        if path ~= "" and check_polyend_path_exists(path) then
            return path
        end
    end
    return ""
end

-- Helper function to prompt for temporary Polyend root path (not saved to preferences)
local function prompt_for_polyend_root()
    local path = renoise.app():prompt_for_path("Select Polyend Tracker Root Folder (temporary)")
    if path and path ~= "" then
        -- Verify it looks like a Polyend project (has patterns folder)
        local patterns_path = path .. separator .. "patterns"
        if check_polyend_path_exists(patterns_path) then
            -- Return temporary path (not saved to preferences)
            print("-- Polyend Pattern: Using temporary root path: " .. path)
            return path
        else
            renoise.app():show_error("Selected folder doesn't contain a 'patterns' subfolder.\nPlease select the root folder of your Polyend Tracker project.")
            return nil
        end
    end
    return nil
end

-- Binary file reading helpers - converted from Python struct.unpack logic
local function read_uint8(file)
    local byte = file:read(1)
    if not byte then return nil end
    return string.byte(byte)
end

local function read_uint16_le(file)
    local bytes = file:read(2)
    if not bytes or #bytes < 2 then return nil end
    local b1, b2 = string.byte(bytes, 1, 2)
    return b1 + (b2 * 256)
end

local function read_uint32_le(file)
    local bytes = file:read(4)
    if not bytes or #bytes < 4 then return nil end
    local b1, b2, b3, b4 = string.byte(bytes, 1, 4)
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function read_int8(file)
    local value = read_uint8(file)
    if not value then return nil end
    -- Convert unsigned byte to signed int8
    if value > 127 then
        value = value - 256
    end
    return value
end

local function read_float_le(file)
    local bytes = file:read(4)
    if not bytes or #bytes < 4 then return nil end
    -- Basic float conversion (good enough for pattern metadata)
    local b1, b2, b3, b4 = string.byte(bytes, 1, 4)
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

-- Read pattern metadata file
local function read_pattern_metadata(filepath)
    local file = io.open(filepath, "rb")
    if not file then
        print("-- Polyend Pattern: Cannot open metadata file: " .. filepath)
        return nil
    end
    
    -- Read header  
    file:seek("set", 0)  -- Ensure we're at the beginning
    local header = file:read(16)
    if not header or #header < 16 then
        file:close()
        return nil
    end
    
    local file_id = header:sub(1, 4)
    if file_id ~= POLYEND_CONSTANTS.PAMD_IDENTIFIER then
        print("-- Polyend Pattern: Invalid file identifier: " .. file_id)
        file:close()
        return nil
    end
    
    -- Parse the rest of the header from the data we already read
    local version = string.byte(header, 5) + (string.byte(header, 6) * 256)
    local total_size = string.byte(header, 9) + (string.byte(header, 10) * 256) + (string.byte(header, 11) * 65536) + (string.byte(header, 12) * 16777216)
    local control_flags = string.byte(header, 13) + (string.byte(header, 14) * 256) + (string.byte(header, 15) * 65536) + (string.byte(header, 16) * 16777216)
    
    print(string.format("-- Polyend Pattern: Metadata version %d, size %d", version, total_size))
    
    -- Read pattern names
    local patterns = {}
    local pattern_count = 0
    
    while true do
        local pattern_data = file:read(POLYEND_CONSTANTS.PATTERN_RECORD_SIZE)
        if not pattern_data or #pattern_data < POLYEND_CONSTANTS.PATTERN_RECORD_SIZE then
            break
        end
        
        -- Extract pattern name (first 30 chars + null terminator)
        local name_data = pattern_data:sub(1, 31)
        local name = ""
        for i = 1, 30 do
            local char = string.byte(name_data, i)
            if char == 0 then break end
            name = name .. string.char(char)
        end
        
        if name ~= "" then
            pattern_count = pattern_count + 1
            patterns[pattern_count] = {
                index = pattern_count,
                name = name,
                filename = string.format("pattern_%03d.mtp", pattern_count - 1)
            }
        end
    end
    
    file:close()
    
    print(string.format("-- Polyend Pattern: Found %d patterns", pattern_count))
    return patterns
end

-- Read Polyend project file - converted from Python projectRead.py
local function read_project_file(filepath)
    local file = io.open(filepath, "rb")
    if not file then
        print("-- Polyend Project: Cannot open project file: " .. filepath)
        return nil
    end
    
    print(string.format("-- Reading MT file: %s", filepath))
    
    -- Read header (16 bytes) - same format as patterns
    local id_file = file:read(2)
    if not id_file or #id_file < 2 then
        print("-- ERROR: Cannot read project file identifier")
        file:close()
        return nil
    end
    
    local project_type = read_uint16_le(file)
    local fw_version = file:read(4) 
    local file_structure_version = file:read(4)
    local reported_size = read_uint16_le(file)
    
    -- Read padding (2 bytes)
    local padding = file:read(2)
    
    print(string.format("-- Project Header: id='%s', type=%d, fw_ver=%s, struct_ver=%s, size=%d",
        id_file,
        project_type or 0,
        fw_version and string.format("%d.%d.%d.%d", string.byte(fw_version, 1, 4)) or "nil",
        file_structure_version and string.format("%d.%d.%d.%d", string.byte(file_structure_version, 1, 4)) or "nil",
        reported_size or 0))
    
    -- Read song data (256 bytes total)
    -- Playlist array (255 bytes)
    local playlist = {}
    for i = 1, 255 do
        local pattern_num = read_uint8(file)
        if pattern_num then
            playlist[i] = pattern_num
        else
            break
        end
    end
    
    -- Playlist position (1 byte)
    local playlist_pos = read_uint8(file)
    
    -- Find actual playlist length (last non-zero entry)
    local actual_playlist_length = 0
    for i = 1, 255 do
        if playlist[i] and playlist[i] > 0 then
            actual_playlist_length = i
        end
    end
    
    file:close()
    
    print(string.format("-- Project playlist length: %d, current position: %d", actual_playlist_length, playlist_pos or 0))
    
    return {
        header = {
            id_file = id_file,
            project_type = project_type,
            fw_version = fw_version,
            file_structure_version = file_structure_version,
            size = reported_size
        },
        playlist = playlist,
        playlist_pos = playlist_pos or 0,
        playlist_length = actual_playlist_length
    }
end

-- Global mapping table to track Polyend instrument indices to Renoise instrument slots
_G.polyend_to_renoise_instrument_mapping = {}

-- Auto-load all PTI instruments from instruments folder using the existing PTI loader
local function auto_load_all_instruments(project_root)
    if not project_root or project_root == "" then
        return 0
    end
    
    local instruments_folder = project_root .. separator .. "instruments"
    if not check_polyend_path_exists(instruments_folder) then
        print("-- No instruments folder found: " .. instruments_folder)
        return 0
    end
    
    print("-- Auto-loading PTI instruments from: " .. instruments_folder)
    print("-- NOTE: Renoise instrument 01 is left empty for Polyend instrument 00 references")
    
    -- Clear the global mapping table
    _G.polyend_to_renoise_instrument_mapping = {}
    
    local loaded_count = 0
    
    -- Look for PTI files
    local success, files = pcall(function()
        return os.filenames(instruments_folder, "*.pti")
    end)
    
    if not success or not files then
        print("-- Could not scan instruments folder")
        return 0
    end
    
    -- Sort files to load in order
    table.sort(files)
    
    -- Load PTI instruments for bulk project import (without ProcessSlicer dialogs)
    print(string.format("-- Loading %d PTI instruments for project import", #files))
    
    -- Clear existing instruments first (but keep instrument 1 empty as a placeholder for instrument 00)
    local song = renoise.song()
    while #song.instruments > 1 do
        song:delete_instrument_at(2)
    end
    
    for i, filename in ipairs(files) do
        local full_path = instruments_folder .. separator .. filename
        print(string.format("-- Loading PTI instrument: %s (%d/%d)", filename, i, #files))
        
        renoise.app():show_status(string.format("Loading PTI: %s (%d/%d)", filename, i, #files))
        
        -- Extract the numeric part from filename to determine the PTI file index
        local file_number = filename:match("^(%d+)")
        if file_number then
            local pti_file_number = tonumber(file_number) -- 1, 2, 3, 4, 5, 6...
            -- The PTI file number represents the actual Polyend instrument index (0-based)
            local polyend_instrument_index = pti_file_number - 1 -- Convert 1-based filename to 0-based Polyend index
            local renoise_instrument_index = pti_file_number + 1 -- Map to Renoise (skip slot 1, use 2, 3, 4, etc.)
            
            -- Store the mapping: Polyend instrument index -> Renoise instrument slot
            _G.polyend_to_renoise_instrument_mapping[polyend_instrument_index] = renoise_instrument_index
            
            print(string.format("   Mapping PTI file '%s' (Polyend instrument %02d) -> Renoise instrument %02d", 
                filename, polyend_instrument_index, renoise_instrument_index))
        
            -- Ensure we have enough instrument slots
            while #song.instruments < renoise_instrument_index do
                song:insert_instrument_at(#song.instruments + 1)
            end
            
            -- Select the target instrument slot
            song.selected_instrument_index = renoise_instrument_index
            
            -- Call PTI worker function directly for bulk loading (bypass ProcessSlicer dialog system)
            local success, error_msg = pcall(function()
                if pti_loadsample_Worker then
                    -- Set loading flag
                    _G.pti_is_loading = true
                    
                    -- Call worker function directly (no dialog needed for bulk import)
                    pti_loadsample_Worker(full_path, nil, nil)
                    
                    -- Clear loading flag after completion
                    _G.pti_is_loading = false
                    
                    loaded_count = loaded_count + 1
                    print(string.format("-- Successfully loaded PTI: %s -> Renoise instrument %d", filename, renoise_instrument_index - 1))
                else
                    error("PTI worker function not available")
                end
            end)
            
            if not success then
                print(string.format("-- FAILED to load PTI %s: %s", filename, tostring(error_msg)))
                -- Make sure flag is cleared on error
                _G.pti_is_loading = false
            end
        else
            print(string.format("-- WARNING: Could not extract number from PTI filename: %s", filename))
        end
    end
    
    print(string.format("-- Loaded %d PTI instruments", loaded_count))
    return loaded_count
end

-- Auto-load all MTP patterns from patterns folder  
local function auto_load_all_patterns(project_root, playlist)
    if not project_root or project_root == "" then
        return 0
    end
    
    local patterns_folder = project_root .. separator .. "patterns"
    if not check_polyend_path_exists(patterns_folder) then
        print("-- No patterns folder found: " .. patterns_folder)
        return 0
    end
    
    print("-- Auto-loading all MTP patterns from: " .. patterns_folder)
    
    local loaded_count = 0
    local song = renoise.song()
    
    -- Clear existing patterns except the first one
    while #song.patterns > 1 do
        song:delete_pattern_at(2)
    end
    
    -- Load patterns based on playlist
    local max_pattern = 0
    for i = 1, #playlist do
        if playlist[i] and playlist[i] > max_pattern then
            max_pattern = playlist[i]
        end
    end
    
    print(string.format("-- Loading patterns 1-%d based on playlist", max_pattern))
    
    -- Ensure we have enough patterns in Renoise
    while #song.patterns < max_pattern do
        local new_pattern_index = song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
        print(string.format("-- Created new pattern %d", new_pattern_index))
    end
    
    -- Pre-scan all patterns to determine maximum track requirement
    local max_tracks_needed = 0
    for pattern_num = 1, max_pattern do
        local filename = string.format("pattern_%02d.mtp", pattern_num)
        local full_path = patterns_folder .. separator .. filename
        
        if check_polyend_path_exists(full_path) then
            local pattern_data = read_pattern_file(full_path)
            if pattern_data and pattern_data.track_count > max_tracks_needed then
                max_tracks_needed = pattern_data.track_count
            end
        end
    end
    
    -- Create all required tracks ONCE at the beginning
    local current_sequencer_tracks = 0
    for i = 1, #song.tracks do
        if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
            current_sequencer_tracks = current_sequencer_tracks + 1
        end
    end
    
    local tracks_to_create = math.max(0, max_tracks_needed - current_sequencer_tracks)
    if tracks_to_create > 0 then
        -- Find the position to insert sequencer tracks (before first master/send track)
        local master_track_index = #song.tracks + 1 -- Default to end if no master/send tracks found
        for i = 1, #song.tracks do
            if song.tracks[i].type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
                master_track_index = i
                break
            end
        end
        for i = 1, tracks_to_create do
            local new_track = song:insert_track_at(master_track_index)
            print(string.format("-- Created new sequencer track %d", master_track_index))
            master_track_index = master_track_index + 1
        end
        print(string.format("-- Created %d additional tracks for %d-track patterns", tracks_to_create, max_tracks_needed))
    end
    
    -- Create shared 1:1 track mapping for all patterns
    local track_mapping = {}
    for track_idx = 1, max_tracks_needed do
        track_mapping[track_idx] = track_idx -- Direct 1:1 mapping
    end
    
    -- Now import all patterns using the same track mapping
    for pattern_num = 1, max_pattern do
        local filename = string.format("pattern_%02d.mtp", pattern_num) -- Polyend uses 1-based, 2-digit numbering
        local full_path = patterns_folder .. separator .. filename
        
        if check_polyend_path_exists(full_path) then
            print(string.format("-- Loading pattern %d: %s", pattern_num, filename))
            
            local pattern_data = read_pattern_file(full_path)
            if pattern_data then
                if import_pattern_to_renoise(pattern_data, pattern_num, track_mapping, full_path) then
                    loaded_count = loaded_count + 1
                end
            end
        else
            print(string.format("-- Pattern %d not found: %s", pattern_num, filename))
        end
    end
    
    print(string.format("-- Loaded %d patterns", loaded_count))
    return loaded_count
end

-- Read individual pattern file - converted from Python patternRead.py
function read_pattern_file(filepath)
    local file = io.open(filepath, "rb")
    if not file then
        print("-- Polyend Pattern: Cannot open pattern file: " .. filepath)
        return nil
    end
    
    print(string.format("-- Reading MTP file: %s", filepath))
    
    -- Read header (16 bytes) - matches Python HEADER_FORMAT = '<2sH4s4sH'
    local id_file = file:read(2)
    if not id_file or #id_file < 2 then
        print("-- ERROR: Cannot read file identifier")
        file:close()
        return nil
    end
    
    local pattern_type = read_uint16_le(file)
    local fw_version = file:read(4)
    local file_structure_version = file:read(4)
    local reported_size = read_uint16_le(file)
    
    -- Read padding (2 bytes)
    local padding = file:read(2)
    
    print(string.format("-- Header: id='%s', type=%d, fw_ver=%s, struct_ver=%s, size=%d", 
        id_file, 
        pattern_type or 0,
        fw_version and string.format("%d.%d.%d.%d", string.byte(fw_version, 1, 4)) or "nil",
        file_structure_version and string.format("%d.%d.%d.%d", string.byte(file_structure_version, 1, 4)) or "nil",
        reported_size or 0))
    
    -- Read unused/reserved metadata (12 bytes) - matches Python UNUSED_FORMAT = '<ff4B'
    local f_unused1 = read_float_le(file)
    local f_unused2 = read_float_le(file)
    local unused1 = read_uint8(file)
    local unused2 = read_uint8(file)
    local unused3 = read_uint8(file)
    local unused4 = read_uint8(file)
    
    -- Just assume 16 tracks max and read what we can
    local track_count = 16
    
    local pattern_data = {
        header = {
            id_file = id_file,
            pattern_type = pattern_type,
            fw_version = fw_version,
            file_structure_version = file_structure_version,
            size = reported_size
        },
        track_count = track_count,
        pattern_length = 1,  -- Will be set from first track
        tracks = {}
    }
    
    -- Read track data - try up to 16 tracks, stop if we can't read more
    local actual_track_count = 0
    for track_idx = 1, track_count do
        -- Try to read lastStep byte 
        local last_step = read_uint8(file)
        if not last_step then
            -- Can't read any more tracks
            break
        end
        
        if track_idx == 1 then
            pattern_data.pattern_length = last_step + 1
            print(string.format("-- Pattern length: %d steps", pattern_data.pattern_length))
        end
        
        local track_data = {}
        local track_complete = true
        
        -- Try to read all 128 steps 
        for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
            local note = read_int8(file)
            local instrument = read_uint8(file)
            local fx0_type = read_uint8(file)
            local fx0_value = read_uint8(file)
            local fx1_type = read_uint8(file)
            local fx1_value = read_uint8(file)
            
            -- Check if any read failed
            if not note or not instrument or not fx0_type or not fx0_value or not fx1_type or not fx1_value then
                track_complete = false
                break
            end
            
            track_data[step] = {
                note = note,
                instrument = instrument,
                fx = {
                    {type = fx0_type, value = fx0_value},
                    {type = fx1_type, value = fx1_value}
                }
            }
        end
        
        if track_complete then
            pattern_data.tracks[track_idx] = track_data
            actual_track_count = track_idx
        else
            -- Couldn't complete this track, stop reading
            break
        end
    end
    
    pattern_data.track_count = actual_track_count
    
    -- Read CRC (4 bytes) - matches Python read_crc
    local crc = read_uint32_le(file)
    pattern_data.crc = crc
    
    file:close()
    print(string.format("-- Successfully read pattern: %d tracks, %d steps, CRC: 0x%08X", 
        actual_track_count, pattern_data.pattern_length, crc or 0))
    return pattern_data
end

-- Convert Polyend note to Renoise note
local function convert_polyend_note(polyend_note)
    if polyend_note == POLYEND_CONSTANTS.NOTE_EMPTY then
        return nil
    elseif polyend_note == POLYEND_CONSTANTS.NOTE_OFF_FADE then
        return 120 -- Note off
    elseif polyend_note == POLYEND_CONSTANTS.NOTE_OFF_CUT then  
        return 121 -- Note cut
    elseif polyend_note == POLYEND_CONSTANTS.NOTE_OFF then
        return 120 -- Generic note off
    else
        -- Polyend notes are MIDI notes (0-127)
        if polyend_note >= 0 and polyend_note <= 119 then
            return polyend_note
        end
    end
    return nil
end

-- Convert Polyend FX to Renoise effect (only a few can be mapped)
local function convert_polyend_fx(fx_type, fx_value)
    if not fx_type or fx_type == 0 or fx_value == 0 then
        return nil, nil, nil -- No effect
    end
    
    -- Only convert the FX that have meaningful Renoise equivalents
    if fx_type == 15 then  -- Tempo (T)
        -- Polyend tempo: 8-400 BPM, value 4-200 maps to 8-400
        local bpm = (fx_value * 2) + 8
        return "F0", string.format("%02X", math.min(255, math.max(32, bpm))), "Tempo"
    elseif fx_type == 18 then  -- Volume/Velocity (V)
        return "0C", string.format("%02X", math.min(64, fx_value)), "Volume"
    elseif fx_type == 31 then  -- Panning (P) 
        -- Polyend: 0-100 (50=center), Renoise: 0-255 (128=center)
        local pan_value = math.floor((fx_value / 100) * 255)
        return "08", string.format("%02X", pan_value), "Panning"
    elseif fx_type == 13 then  -- Break Pattern (x)
        return "0D", "00", "Pattern Break"
    else
        -- For other FX, return info for debugging/display but no Renoise effect
        local fx_name = POLYEND_CONSTANTS.FX_NAMES[fx_type] or "Unknown"
        local fx_symbol = POLYEND_CONSTANTS.FX_SYMBOLS[fx_type] or "?"
        return nil, nil, string.format("Polyend %s (%s:%02X)", fx_name, fx_symbol, fx_value)
    end
end

-- Auto-load MTI instruments used in pattern and create instrument mapping
local function auto_load_pattern_instruments(instruments_used, polyend_path)
    if not instruments_used or not next(instruments_used) then
        return {}
    end
    
    local project_root = polyend_path or get_polyend_project_root()
    if not project_root or project_root == "" then
        print("-- Auto-load instruments: No Polyend root path available")
        return {}
    end
    
    local instruments_folder = project_root .. separator .. "instruments"
    if not check_polyend_path_exists(instruments_folder) then
        print("-- Auto-load instruments: Instruments folder not found: " .. instruments_folder)
        return {}
    end
    
    local loaded_count = 0
    local failed_count = 0
    local instrument_mapping = {} -- polyend_idx -> renoise_idx
    local song = renoise.song()
    
    print("-- Auto-loading MTI instruments used in pattern...")
    
    for polyend_instrument_idx, usage_count in pairs(instruments_used) do
        -- Skip instrument 00 (usually empty/silence)
        if polyend_instrument_idx ~= 0 then
            -- MTI files are numbered with decimal values
            local mti_filename = string.format("instrument_%02d.mti", polyend_instrument_idx)
            local mti_path = instruments_folder .. separator .. mti_filename
            
            print(string.format("-- Checking for Polyend instrument %02X (decimal %d): %s", polyend_instrument_idx, polyend_instrument_idx, mti_path))
            
            if check_polyend_path_exists(mti_path) then
                -- Use our existing MTI loader function
                local success, error_msg = pcall(function()
                    mti_loadsample(mti_path)
                end)
                
                if success then
                    -- Get the actual instrument index after loading (mti_loadsample creates and selects the instrument)
                    local renoise_instrument_idx = song.selected_instrument_index
                    
                    -- Map Polyend instrument index to Renoise instrument index
                    instrument_mapping[polyend_instrument_idx] = renoise_instrument_idx
                    loaded_count = loaded_count + 1
                    print(string.format("-- Successfully loaded Polyend instrument %02X -> Renoise instrument %02d (%d uses in pattern)", 
                        polyend_instrument_idx, renoise_instrument_idx, usage_count))
                else
                    failed_count = failed_count + 1
                    print(string.format("-- Failed to load Polyend instrument %02X: %s", polyend_instrument_idx, mti_path))
                    print(string.format("   Error: %s", tostring(error_msg)))
                end
            else
                failed_count = failed_count + 1
                print(string.format("-- Polyend instrument %02X not found: %s", polyend_instrument_idx, mti_path))
            end
        end
    end
    
    local total_instruments = loaded_count + failed_count
    print(string.format("-- Auto-load complete: %d/%d instruments loaded successfully", 
        loaded_count, total_instruments))
    
    if loaded_count > 0 then
        renoise.app():show_status(string.format("Pattern imported with %d instruments auto-loaded", loaded_count))
    end
    
    return instrument_mapping
end

-- Import pattern into Renoise
function import_pattern_to_renoise(pattern_data, target_pattern_index, track_mapping, filepath)
    local song = renoise.song()
    
    if not pattern_data or not pattern_data.tracks then
        renoise.app():show_error("Invalid pattern data")
        return false
    end
    
    local target_pattern = song:pattern(target_pattern_index)
    if not target_pattern then
        renoise.app():show_error("Invalid target pattern")
        return false
    end
    
    local imported_tracks = 0
    local instruments_used = {}
    
    for polyend_track_idx, polyend_track in ipairs(pattern_data.tracks) do
        local renoise_track_idx = track_mapping[polyend_track_idx]
        
        print(string.format("DEBUG: Processing Polyend track %d -> Renoise track %d", polyend_track_idx, renoise_track_idx or 0))
        
        -- Only import if track is mapped and exists  
        if renoise_track_idx and renoise_track_idx <= #song.tracks then
            local renoise_song_track = song.tracks[renoise_track_idx]
            local renoise_pattern_track = target_pattern:track(renoise_track_idx)
            
            -- Only process sequencer tracks (skip master, send, group tracks)
            if renoise_song_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                
                -- Clear the target track first
                print(string.format("Clearing track %d before import", renoise_track_idx))
                renoise_pattern_track:clear()
                
                -- Ensure track has enough effect columns
                if renoise_song_track.visible_effect_columns < 2 then
                    renoise_song_track.visible_effect_columns = 2
                end
                
                -- Track line structure validation
                local invalid_steps = {}
                local valid_steps = 0
                local track_has_data = false
                
                -- Check if this track has any data at all
                for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
                    local step_data = polyend_track[step]
                    if step_data and (step_data.note ~= POLYEND_CONSTANTS.NOTE_EMPTY or 
                                     (step_data.instrument and step_data.instrument > 0) or
                                     (step_data.fx and #step_data.fx > 0)) then
                        track_has_data = true
                        break
                    end
                end
                
                print(string.format("Track %d has data: %s", renoise_track_idx, tostring(track_has_data)))
                
                for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
                local step_data = polyend_track[step]
                if step_data then
                    local line = renoise_pattern_track:line(step)
                    
                    -- Check line structure and ensure track has note columns
                    if line then
                        -- Ensure the track has visible note columns
                        if renoise_song_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                            if renoise_song_track.visible_note_columns < 1 then
                                renoise_song_track.visible_note_columns = 1
                            end
                        end
                        
                        -- Now check if we can access note columns
                        if line.note_columns and #line.note_columns >= 1 then
                            valid_steps = valid_steps + 1
                            
                            -- Convert note
                            local note = convert_polyend_note(step_data.note)
                            if note then
                                if note <= 119 then
                                    line.note_columns[1].note_value = note
                                    -- Only set instrument when there's actually a note
                                    -- Use the global mapping table to find the correct Renoise instrument slot
                                    if step_data.instrument and step_data.instrument < 255 then
                                        local renoise_instrument_index = _G.polyend_to_renoise_instrument_mapping[step_data.instrument]
                                        if renoise_instrument_index then
                                            line.note_columns[1].instrument_value = renoise_instrument_index
                                            instruments_used[step_data.instrument] = (instruments_used[step_data.instrument] or 0) + 1
                                        else
                                            print(string.format("-- WARNING: No mapping found for Polyend instrument %02X", step_data.instrument))
                                        end
                                    end
                                elseif note == 120 then
                                    line.note_columns[1].note_string = "OFF"
                                elseif note == 121 then
                                    line.note_columns[1].note_string = "OFF"
                                end
                                -- Note: MTP format doesn't include velocity data
                                -- Velocity/volume would need to come from instrument settings or effects
                            end
                            
                            -- Convert effects - handle the new fx structure
                            if step_data.fx and #step_data.fx >= 1 then
                                local fx1_cmd, fx1_val, fx1_info = convert_polyend_fx(step_data.fx[1].type, step_data.fx[1].value)
                                if fx1_cmd and fx1_val and #line.effect_columns >= 1 then
                                    line.effect_columns[1].number_string = fx1_cmd
                                    line.effect_columns[1].amount_string = fx1_val
                                elseif fx1_info then
                                    -- Log unmapped FX for reference (only first few)
                                    if step <= 5 then 
                                        print(string.format("-- Unmapped FX1 on step %d: %s", step, fx1_info))
                                    end
                                end
                            end
                            
                            if step_data.fx and #step_data.fx >= 2 then
                                local fx2_cmd, fx2_val, fx2_info = convert_polyend_fx(step_data.fx[2].type, step_data.fx[2].value)
                                if fx2_cmd and fx2_val and #line.effect_columns >= 2 then
                                    line.effect_columns[2].number_string = fx2_cmd
                                    line.effect_columns[2].amount_string = fx2_val
                                elseif fx2_info then
                                    -- Log unmapped FX for reference (only first few)
                                    if step <= 5 then
                                        print(string.format("-- Unmapped FX2 on step %d: %s", step, fx2_info))
                                    end
                                end
                            end
                        else
                            table.insert(invalid_steps, step)
                        end
                    else
                        table.insert(invalid_steps, step)
                    end
                end
            end
            
            -- Report invalid steps as ranges instead of individual errors
            if #invalid_steps > 0 then
                if #invalid_steps > 10 then
                    print(string.format("-- ERROR: Invalid line structure on %d steps (001-%03d)", #invalid_steps, POLYEND_CONSTANTS.STEP_COUNT))
                else
                    print(string.format("-- ERROR: Invalid line structure on steps: %s", table.concat(invalid_steps, ", ")))
                end
            end
            
            if valid_steps > 0 then
                print(string.format("-- Successfully processed %d valid steps on track %d", valid_steps, renoise_track_idx))
            else
                print(string.format("-- Track %d had no valid steps to process", renoise_track_idx))
            end
            
            imported_tracks = imported_tracks + 1
        else
            print(string.format("-- Skipped track %d (not a sequencer track: %s)", renoise_track_idx, renoise_song_track.type))
        end
    else
        print(string.format("-- Skipped Polyend track %d (not mapped or track doesn't exist)", polyend_track_idx))
    end
    end
    
    -- Show summary of instruments used and auto-load them
    if next(instruments_used) then
        print("-- Instrument indices used in pattern:")
        for instrument_idx, count in pairs(instruments_used) do
            print(string.format("  Instrument %02X: %d times", instrument_idx, count))
        end
        
        -- Skip MTI auto-loading - PTI instruments already loaded at project level
        -- local pattern_root = filepath:match("^(.+)" .. separator .. "patterns" .. separator)
        -- local instrument_mapping = auto_load_pattern_instruments(instruments_used, pattern_root)
        local instrument_mapping = {}
        
        -- Update pattern data with correct Renoise instrument indices
        if next(instrument_mapping) then
            print("-- Updating pattern with correct instrument mappings...")
            for polyend_track_idx, polyend_track in ipairs(pattern_data.tracks) do
                local renoise_track_idx = track_mapping[polyend_track_idx]
                
                if renoise_track_idx and renoise_track_idx <= #song.tracks then
                    local renoise_pattern_track = target_pattern:track(renoise_track_idx)
                    
                    for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
                        local step_data = polyend_track[step]
                        if step_data and step_data.instrument and step_data.instrument > 0 then
                            local mapped_instrument = instrument_mapping[step_data.instrument]
                            if mapped_instrument then
                                local line = renoise_pattern_track:line(step)
                                if line.note_columns[1].note_value < 120 then -- Only update actual notes, not OFF/CUT
                                    line.note_columns[1].instrument_value = mapped_instrument - 1 -- Renoise uses 0-based indexing
                                    print(string.format("-- Updated step %d: Polyend instrument %02X -> Renoise instrument %02d", 
                                        step, step_data.instrument, mapped_instrument - 1))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Show instrument usage summary
    if next(instruments_used) then
        print("-- Instrument indices used in pattern:")
        for instrument_idx, count in pairs(instruments_used) do
            print(string.format("  Instrument %02X: %d times", instrument_idx, count))
        end
    else
        print("-- No instruments were used in this pattern")
    end
    
    print(string.format("-- Polyend Pattern: Imported %d tracks to pattern %d", imported_tracks, target_pattern_index))
    return true
end

-- Export Renoise pattern to MTP file
local function export_pattern_to_mtp(pattern_index, output_path, track_count)
    track_count = track_count or 16  -- Default to 16 tracks for Tracker Mini/Plus
    
    local song = renoise.song()
    if pattern_index > #song.patterns then
        print("-- ERROR: Pattern index out of range")
        return false
    end
    
    local pattern = song.patterns[pattern_index]
    
    -- Open output file
    local file = io.open(output_path, "wb")
    if not file then
        print("-- ERROR: Cannot create MTP file: " .. output_path)
        return false
    end
    
    print(string.format("-- Exporting pattern %d to MTP: %s (%d tracks)", pattern_index, output_path, track_count))
    
    -- Write header (16 bytes)
    file:write("--")  -- id_file (2 bytes) - placeholder, real MTP files use different IDs
    
    -- Write pattern type as little-endian uint16
    file:write(string.char(2, 0))  -- pattern_type = 2
    
    -- Write firmware version (4 bytes) - use generic version
    file:write(string.char(1, 0, 0, 0))  -- fw_version
    
    -- Write file structure version (4 bytes)
    file:write(string.char(5, 0, 0, 0))  -- file_structure_version = 5
    
    -- Calculate and write file size (will need to update this)
    local header_size = 16
    local unused_size = 12
    local track_header_size = 1
    local step_size = 6
    local steps_per_track = 128
    local crc_size = 4
    local total_size = header_size + unused_size + (track_count * (track_header_size + (step_size * steps_per_track))) + crc_size
    
    -- Write size as little-endian uint16 (this is wrong for large files, but matches format)
    local size_low = total_size % 256
    local size_high = math.floor(total_size / 256) % 256
    file:write(string.char(size_low, size_high))
    
    -- Write padding (2 bytes)
    file:write(string.char(0, 0))
    
    -- Write unused/reserved metadata (12 bytes) - all zeros
    for i = 1, 12 do
        file:write(string.char(0))
    end
    
    -- Get pattern length 
    local pattern_length = math.min(pattern.number_of_lines, 128)
    local last_step = pattern_length - 1  -- 0-based
    
    -- Write track data
    for track_idx = 1, track_count do
        -- Write lastStep byte (only meaningful for first track)
        if track_idx == 1 then
            file:write(string.char(last_step))
        else
            file:write(string.char(0))  -- Other tracks use 0
        end
        
        -- Get Renoise track if it exists
        local renoise_track = nil
        if track_idx <= #song.tracks then
            renoise_track = pattern:track(track_idx)
        end
        
        -- Write all 128 steps
        for step = 1, 128 do
            local note = -1  -- Default to empty
            local instrument = 0
            local fx0_type, fx0_value = 0, 0
            local fx1_type, fx1_value = 0, 0
            
            -- Get data from Renoise if step exists and track exists
            if step <= pattern_length and renoise_track then
                local line = renoise_track:line(step)
                
                -- Convert note
                if line.note_columns[1].note_value < 120 then
                    note = line.note_columns[1].note_value
                elseif line.note_columns[1].note_string == "OFF" then
                    note = POLYEND_CONSTANTS.NOTE_OFF_FADE
                elseif line.note_columns[1].note_string == "CUT" then
                    note = POLYEND_CONSTANTS.NOTE_OFF_CUT
                end
                
                -- Get instrument
                -- Map Renoise instruments to match PTI loading: 02(hihat)->00, 03(snare)->01, etc. (Skip instrument 01 empty)
                if line.note_columns[1].instrument_value < 255 then
                    local polyend_instrument_index = math.max(0, line.note_columns[1].instrument_value - 2)
                    instrument = polyend_instrument_index
                end
                
                -- Convert effects (very basic - only handle a few Renoise -> Polyend mappings)
                if #line.effect_columns >= 1 and line.effect_columns[1].number_string ~= "" then
                    local fx_cmd = line.effect_columns[1].number_string
                    local fx_val = tonumber(line.effect_columns[1].amount_string, 16) or 0
                    
                    if fx_cmd == "0C" then  -- Volume -> Volume/Velocity
                        fx0_type, fx0_value = 18, math.min(100, fx_val)
                    elseif fx_cmd == "08" then  -- Pan -> Panning
                        fx0_type, fx0_value = 31, math.floor((fx_val / 255) * 100)
                    elseif fx_cmd == "F0" then  -- Tempo -> Tempo
                        fx0_type, fx0_value = 15, math.max(4, math.min(200, math.floor((fx_val - 32) / 2)))
                    elseif fx_cmd == "0D" then  -- Pattern Break -> Break Pattern
                        fx0_type, fx0_value = 13, 1
                    end
                end
                
                if #line.effect_columns >= 2 and line.effect_columns[2].number_string ~= "" then
                    local fx_cmd = line.effect_columns[2].number_string
                    local fx_val = tonumber(line.effect_columns[2].amount_string, 16) or 0
                    
                    if fx_cmd == "0C" then  -- Volume -> Volume/Velocity
                        fx1_type, fx1_value = 18, math.min(100, fx_val)
                    elseif fx_cmd == "08" then  -- Pan -> Panning
                        fx1_type, fx1_value = 31, math.floor((fx_val / 255) * 100)
                    elseif fx_cmd == "F0" then  -- Tempo -> Tempo
                        fx1_type, fx1_value = 15, math.max(4, math.min(200, math.floor((fx_val - 32) / 2)))
                    elseif fx_cmd == "0D" then  -- Pattern Break -> Break Pattern
                        fx1_type, fx1_value = 13, 1
                    end
                end
            end
            
            -- Write step data (6 bytes)
            -- Note as signed int8
            local note_byte = note
            if note < 0 then
                note_byte = note + 256
            end
            file:write(string.char(note_byte))
            
            -- Instrument, fx0_type, fx0_value, fx1_type, fx1_value
            file:write(string.char(instrument, fx0_type, fx0_value, fx1_type, fx1_value))
        end
    end
    
    -- Calculate and write CRC (placeholder - real implementation would calculate proper CRC32)
    file:write(string.char(0x00, 0x00, 0x00, 0x00))
    
    file:close()
    print(string.format("-- MTP export complete: %s", output_path))
    return true
end

-- Scan for available patterns
local function scan_polyend_patterns(root_path)
    if not root_path then
        root_path = get_polyend_project_root()
    end
    if not root_path or root_path == "" then
        return {}
    end
    
    local patterns_path = root_path .. separator .. "patterns"
    if not check_polyend_path_exists(patterns_path) then
        print("-- Polyend Pattern: Patterns folder not found: " .. patterns_path)
        return {}
    end
    
    -- Read metadata file
    local metadata_path = patterns_path .. separator .. "patternsMetadata"
    local patterns = read_pattern_metadata(metadata_path)
    
    if patterns then
        -- Verify pattern files exist
        for i, pattern in ipairs(patterns) do
            local pattern_file = patterns_path .. separator .. pattern.filename
            if not check_polyend_path_exists(pattern_file) then
                print("-- Polyend Pattern: Pattern file not found: " .. pattern_file)
                pattern.exists = false
            else
                pattern.exists = true
                pattern.full_path = pattern_file
            end
        end
        
        return patterns
    end
    
    return {}
end

-- Create track mapping dialog
local function create_track_mapping_dialog(pattern_data)
    local song = renoise.song()
    local track_items = {}
    
    for i = 1, #song.tracks do
        table.insert(track_items, string.format("Track %d: %s", i, song.tracks[i].name))
    end
    
    local mapping_dialog = nil
    local track_mapping = {}
    
    local content = vb:column{
        margin = 10,
        vb:text{text = "Map Polyend tracks to Renoise tracks:", style = "strong"},
        vb:space{height = 10}
    }
    
    -- Create mapping controls
    for i = 1, pattern_data.track_count do
        local row = vb:row{
            vb:text{text = string.format("Polyend Track %d:", i), width = 120},
            vb:popup{
                id = "track_mapping_" .. i,
                items = track_items,
                value = math.min(i, #song.tracks),
                width = 300,
                notifier = function(value)
                    track_mapping[i] = value
                end
            }
        }
        content:add_child(row)
        track_mapping[i] = math.min(i, #song.tracks)
    end
    
    content:add_child(vb:space{height = 10})
    content:add_child(vb:horizontal_aligner{
        mode = "distribute",
        vb:button{
            text = "Import",
            width = 100,
            notifier = function()
                mapping_dialog:close()
                return track_mapping
            end
        },
        vb:button{
            text = "Cancel",
            width = 100,
            notifier = function()
                mapping_dialog:close()
                return nil
            end
        }
    })
    
    mapping_dialog = renoise.app():show_custom_dialog("Track Mapping", content)
    return track_mapping
end

-- 1. Import Polyend Project
function PakettiImportPolyendProject()
    local root_path = get_polyend_project_root()
    if not root_path or root_path == "" then
        root_path = prompt_for_polyend_root()
        if not root_path then
            return
        end
    end
    
    local patterns = scan_polyend_patterns(root_path)
    if #patterns == 0 then
        renoise.app():show_error("No patterns found in Polyend project at: " .. root_path)
        return
    end
    
    local song = renoise.song()
    local imported_count = 0
    
    -- Pre-scan all patterns to determine maximum track requirement
    local max_tracks_needed = 0
    for i, pattern in ipairs(patterns) do
        if pattern.exists then
            local pattern_data = read_pattern_file(pattern.full_path)
            if pattern_data and pattern_data.track_count > max_tracks_needed then
                max_tracks_needed = pattern_data.track_count
            end
        end
    end
    
    -- Create all required tracks ONCE at the beginning
    local current_sequencer_tracks = 0
    for i = 1, #song.tracks do
        if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
            current_sequencer_tracks = current_sequencer_tracks + 1
        end
    end
    
    local tracks_to_create = math.max(0, max_tracks_needed - current_sequencer_tracks)
    if tracks_to_create > 0 then
        -- Find the position to insert sequencer tracks (before first master/send track)
        local master_track_index = #song.tracks + 1 -- Default to end if no master/send tracks found
        for i = 1, #song.tracks do
            if song.tracks[i].type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
                master_track_index = i
                break
            end
        end
        for i = 1, tracks_to_create do
            local new_track = song:insert_track_at(master_track_index)
            print(string.format("-- Created new sequencer track %d", master_track_index))
            master_track_index = master_track_index + 1
        end
        print(string.format("-- Created %d additional tracks for %d-track patterns", tracks_to_create, max_tracks_needed))
    end
    
    -- Create shared 1:1 track mapping for all patterns
    local track_mapping = {}
    for track_idx = 1, max_tracks_needed do
        track_mapping[track_idx] = track_idx -- Direct 1:1 mapping
    end
    
    -- Now import all patterns using the same track mapping
    for i, pattern in ipairs(patterns) do
        if pattern.exists then
            local pattern_data = read_pattern_file(pattern.full_path)
            if pattern_data then
                -- Create new pattern in Renoise
                local target_pattern = i
                while target_pattern > #song.sequencer.pattern_sequence do
                    song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
                end
                
                if import_pattern_to_renoise(pattern_data, target_pattern, track_mapping, pattern.full_path) then
                    imported_count = imported_count + 1
                end
            end
        end
    end
    
    renoise.app():show_status(string.format("Imported %d patterns from Polyend project", imported_count))
end

-- 2. Import Polyend Pattern
function PakettiImportPolyendPattern()
    local root_path = get_polyend_project_root()
    if not root_path or root_path == "" then
        root_path = prompt_for_polyend_root()
        if not root_path then
            return
        end
    end
    
    local patterns = scan_polyend_patterns(root_path)
    if #patterns == 0 then
        renoise.app():show_error("No patterns found in Polyend project at: " .. root_path)
        return
    end
    
    -- Create pattern selection dialog
    local pattern_items = {}
    for i, pattern in ipairs(patterns) do
        if pattern.exists then
            table.insert(pattern_items, string.format("%d: %s", pattern.index, pattern.name))
        end
    end
    
    if #pattern_items == 0 then
        renoise.app():show_error("No valid patterns found")
        return
    end
    
    local selected_pattern_idx = 1
    local target_pattern_idx = renoise.song().selected_pattern_index
    
    local content = vb:column{
        margin = 10,
        vb:text{text = "Select pattern to import:", style = "strong"},
        vb:popup{
            id = "pattern_selector",
            items = pattern_items,
            value = 1,
            width = 400,
            notifier = function(value)
                selected_pattern_idx = value
            end
        },
        vb:space{height = 10},
        vb:text{text = "Target pattern index:"},
        vb:textfield{
            id = "target_pattern",
            text = tostring(target_pattern_idx),
            width = 100,
            notifier = function(value)
                local num = tonumber(value)
                if num and num > 0 then
                    target_pattern_idx = num
                end
            end
        },
        vb:space{height = 10},
        vb:horizontal_aligner{
            mode = "distribute",
            vb:button{
                text = "Import",
                width = 100,
                notifier = function()
                    pattern_dialog:close()
                    
                    local selected_pattern = patterns[selected_pattern_idx]
                    if selected_pattern and selected_pattern.exists then
                        local pattern_data = read_pattern_file(selected_pattern.full_path)
                        if pattern_data then
                            local track_mapping = create_track_mapping_dialog(pattern_data)
                            if track_mapping then
                                import_pattern_to_renoise(pattern_data, target_pattern_idx, track_mapping, selected_pattern.full_path)
                                renoise.app():show_status("Pattern imported successfully")
                            end
                        end
                    end
                end
            },
            vb:button{
                text = "Cancel",
                width = 100,
                notifier = function()
                    pattern_dialog:close()
                end
            }
        }
    }
    
    pattern_dialog = renoise.app():show_custom_dialog("Import Polyend Pattern", content)
end

-- 3. Import Pattern Tracks
function PakettiImportPolyendPatternTracks()
    local root_path = get_polyend_project_root()
    if not root_path or root_path == "" then
        root_path = prompt_for_polyend_root()
        if not root_path then
            return
        end
    end
    
    local patterns = scan_polyend_patterns(root_path)
    if #patterns == 0 then
        renoise.app():show_error("No patterns found in Polyend project at: " .. root_path)
        return
    end
    
    -- Create pattern and track selection dialog
    local pattern_items = {}
    for i, pattern in ipairs(patterns) do
        if pattern.exists then
            table.insert(pattern_items, string.format("%d: %s", pattern.index, pattern.name))
        end
    end
    
    if #pattern_items == 0 then
        renoise.app():show_error("No valid patterns found")
        return
    end
    
    local selected_pattern_idx = 1
    local selected_tracks = {}
    
    local content = vb:column{
        margin = 10,
        vb:text{text = "Select pattern:", style = "strong"},
        vb:popup{
            id = "pattern_selector",
            items = pattern_items,
            value = 1,
            width = 400,
            notifier = function(value)
                selected_pattern_idx = value
                -- Update track checkboxes based on selected pattern
                local selected_pattern = patterns[selected_pattern_idx]
                if selected_pattern and selected_pattern.exists then
                    local pattern_data = read_pattern_file(selected_pattern.full_path)
                    if pattern_data then
                        for i = 1, 16 do  -- Max 16 tracks
                            local checkbox = vb.views["track_" .. i]
                            if checkbox then
                                checkbox.visible = (i <= pattern_data.track_count)
                            end
                        end
                    end
                end
            end
        },
        vb:space{height = 10},
        vb:text{text = "Select tracks to import:", style = "strong"}
    }
    
    -- Add track checkboxes
    for i = 1, 16 do
        local checkbox = vb:checkbox{
            id = "track_" .. i,
            text = string.format("Track %d", i),
            value = false,
            visible = false,
            notifier = function(value)
                selected_tracks[i] = value
            end
        }
        content:add_child(checkbox)
    end
    
    content:add_child(vb:space{height = 10})
    content:add_child(vb:horizontal_aligner{
        mode = "distribute",
        vb:button{
            text = "Import Selected",
            width = 120,
            notifier = function()
                pattern_dialog:close()
                
                local selected_pattern = patterns[selected_pattern_idx]
                if selected_pattern and selected_pattern.exists then
                    local pattern_data = read_pattern_file(selected_pattern.full_path)
                    if pattern_data then
                        -- Create filtered track mapping
                        local track_mapping = {}
                        local song = renoise.song()
                        local target_track = song.selected_track_index
                        
                        for i = 1, pattern_data.track_count do
                            if selected_tracks[i] then
                                track_mapping[i] = target_track
                                target_track = target_track + 1
                            end
                        end
                        
                        if next(track_mapping) then
                            import_pattern_to_renoise(pattern_data, renoise.song().selected_pattern_index, track_mapping, selected_pattern.full_path)
                            renoise.app():show_status("Selected tracks imported successfully")
                        else
                            renoise.app():show_error("No tracks selected")
                        end
                    end
                end
            end
        },
        vb:button{
            text = "Cancel",
            width = 100,
            notifier = function()
                pattern_dialog:close()
            end
        }
    })
    
    pattern_dialog = renoise.app():show_custom_dialog("Import Pattern Tracks", content)
    
    -- Initialize track checkboxes for first pattern
    local first_pattern = patterns[1]
    if first_pattern and first_pattern.exists then
        local pattern_data = read_pattern_file(first_pattern.full_path)
        if pattern_data then
            for i = 1, 16 do
                local checkbox = vb.views["track_" .. i]
                if checkbox then
                    checkbox.visible = (i <= pattern_data.track_count)
                end
            end
        end
    end
end

-- 4. Pattern Browser (Main Dialog)
function PakettiPolyendPatternBrowser()
    local root_path = get_polyend_project_root()
    if not root_path or root_path == "" then
        root_path = prompt_for_polyend_root()
        if not root_path then
            return
        end
    end
    
    local patterns = scan_polyend_patterns(root_path)
    
    local content = vb:column{
        margin = 10,
        vb:text{text = "Polyend Pattern Browser", style = "strong", font = "bold"},
        vb:space{height = 10},
        vb:text{text = string.format("Root Path: %s", root_path), font = "italic"},
        vb:text{text = string.format("Found %d patterns", #patterns)},
        vb:space{height = 10},
        
        vb:horizontal_aligner{
            mode = "distribute",
            vb:button{
                text = "Import Entire Project",
                width = 150,
                height = 30,
                notifier = function()
                    pattern_dialog:close()
                    PakettiImportPolyendProject()
                end
            },
            vb:button{
                text = "Import Single Pattern",
                width = 150,
                height = 30,
                notifier = function()
                    pattern_dialog:close()
                    PakettiImportPolyendPattern()
                end
            }
        },
        
        vb:space{height = 5},
        
        vb:horizontal_aligner{
            mode = "distribute",
            vb:button{
                text = "Import Pattern Tracks",
                width = 150,
                height = 30,
                notifier = function()
                    pattern_dialog:close()
                    PakettiImportPolyendPatternTracks()
                end
            },
            vb:button{
                text = "Refresh",
                width = 150,
                height = 30,
                notifier = function()
                    pattern_dialog:close()
                    PakettiPolyendPatternBrowser()
                end
            }
        },
        
        vb:space{height = 10},
        vb:button{
            text = "Close",
            width = 100,
            notifier = function()
                pattern_dialog:close()
            end
        }
    }
    
    pattern_dialog = renoise.app():show_custom_dialog("Polyend Pattern Browser", content)
end



-- Export current pattern to MTP file
function PakettiExportPolyendPattern()
    local song = renoise.song()
    local pattern_index = song.selected_pattern_index
    local pattern_name = song.patterns[pattern_index].name
    
    -- Create default filename
    local default_name = string.format("pattern_%03d", pattern_index - 1)
    if pattern_name and pattern_name ~= "" then
        default_name = pattern_name:gsub("[^%w%-%_]", "_")  -- Clean filename
    end
    default_name = default_name .. ".mtp"
    
    -- Prompt for save location
    local output_path = renoise.app():prompt_for_filename_to_write("mtp", "Export Pattern as MTP", default_name)
    if not output_path or output_path == "" then
        return
    end
    
    -- Export with 16 tracks by default (can be modified for different Polyend devices)
    local success = export_pattern_to_mtp(pattern_index, output_path, 16)
    if success then
        renoise.app():show_status(string.format("Pattern %d exported to MTP: %s", pattern_index, output_path))
    else
        renoise.app():show_error("Failed to export pattern to MTP format")
    end
end

-- Menu entries and keybindings
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend WIP:Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend WIP:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend WIP:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend WIP:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend WIP:Export Pattern to MTP", invoke=PakettiExportPolyendPattern}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Polyend WIP:Import MT Project File", invoke=function() PakettiImportPolyendMTProject() end}

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Polyend WIP:Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Polyend WIP:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Polyend WIP:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Polyend WIP:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Polyend WIP:Export Pattern to MTP", invoke=PakettiExportPolyendPattern}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Polyend WIP:Import MT Project File", invoke=function() PakettiImportPolyendMTProject() end}

renoise.tool():add_keybinding{name="Global:Paketti:Show Polyend Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}
renoise.tool():add_keybinding{name="Global:Paketti:Export Pattern to MTP", invoke=PakettiExportPolyendPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Import MT Project File", invoke=function() PakettiImportPolyendMTProject() end}

-- Main MT project import function  
function PakettiImportPolyendMTProject(filepath)
    if not filepath then
        filepath = renoise.app():prompt_for_filename_to_read({"*.mt"}, "Select Polyend Tracker project file")
        if not filepath or filepath == "" then
            return
        end
    end
    
    print("=== IMPORTING POLYEND TRACKER PROJECT ===")
    
    -- Parse the project file
    local project_data = read_project_file(filepath)
    if not project_data then
        renoise.app():show_error("Failed to read Polyend Tracker project file")
        return
    end
    
    -- Get project root directory
    local project_root = filepath:match("^(.+)" .. separator .. "[^" .. separator .. "]+$")
    if not project_root then
        renoise.app():show_error("Cannot determine project root directory")
        return
    end
    
    print("-- Project root: " .. project_root)
    
    -- Load all instruments using the existing PTI loader
    local instruments_loaded = auto_load_all_instruments(project_root)
    
    -- Load all patterns
    local patterns_loaded = auto_load_all_patterns(project_root, project_data.playlist)
    
    -- Set up Renoise sequence based on playlist
    local song = renoise.song()
    local sequence = {}
    
    for i = 1, project_data.playlist_length do
        local pattern_num = project_data.playlist[i]
        if pattern_num and pattern_num > 0 and pattern_num <= #song.patterns then
            table.insert(sequence, pattern_num)
        end
    end
    
    -- Apply sequence to Renoise
    if #sequence > 0 then
        -- Clear existing sequence (keep at least one)
        while #song.sequencer.pattern_sequence > 1 do
            song.sequencer:delete_sequence_at(#song.sequencer.pattern_sequence)
        end
        
        -- Set first pattern in sequence
        local first_seq_pos = 1
        if #song.sequencer.pattern_sequence > 0 then
            -- Set the first existing sequence position
            song.sequencer.pattern_sequence[1] = sequence[1]
        else
            -- This shouldn't happen, but just in case
            song.sequencer:insert_sequence_at(1, sequence[1])
        end
        
        -- Add remaining patterns to sequence
        for i = 2, #sequence do
            song.sequencer:insert_sequence_at(i, sequence[i])
        end
        
        print(string.format("-- Set up sequence with %d pattern entries", #sequence))
    end
    
    renoise.app():show_status(string.format("Imported Polyend project: %d instruments loaded, %d patterns loaded, %d sequence entries", 
        instruments_loaded, patterns_loaded, #sequence))
    
    print("=== POLYEND PROJECT IMPORT COMPLETE ===")
end

-- Direct MT project file import function for drag-and-drop
local function mt_import_hook(filename)
    if not filename then
        renoise.app():show_error("MT Import Error: No filename provided!")
        return false
    end
    
    -- Check if file exists
    local file_test = io.open(filename, "rb")
    if not file_test then
        renoise.app():show_error("Cannot open MT project file: " .. filename)
        return false
    end
    file_test:close()
    
    -- Import the project
    PakettiImportPolyendMTProject(filename)
    return true
end

-- Direct MTP file import function for drag-and-drop
local function mtp_import_hook(filename)
    if not filename then
        renoise.app():show_error("MTP Import Error: No filename provided!")
        return false
    end
    
    -- Check if file exists
    local file_test = io.open(filename, "rb")
    if not file_test then
        renoise.app():show_error("Cannot open MTP file: " .. filename)
        return false
    end
    file_test:close()
    
    -- Read the pattern file
    local pattern_data = read_pattern_file(filename)
    if not pattern_data then
        renoise.app():show_error("Failed to read MTP pattern file: " .. filename)
        return false
    end
    
    local song = renoise.song()
    local current_pattern_index = song.selected_pattern_index
    
    -- Ensure we have enough sequencer tracks by creating new ones if needed
    local current_sequencer_tracks = 0
    for i = 1, #song.tracks do
        if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
            current_sequencer_tracks = current_sequencer_tracks + 1
        end
    end
    
    local required_tracks = pattern_data.track_count
    local tracks_to_create = math.max(0, required_tracks - current_sequencer_tracks)
    
    -- Create additional tracks if needed (insert before master track)
    local master_track_index = #song.tracks -- Master is always last
    for i = 1, tracks_to_create do
        local new_track = song:insert_track_at(master_track_index)
        print(string.format("-- Created new sequencer track %d", master_track_index))
        master_track_index = master_track_index + 1
    end
    
    -- Create 1:1 track mapping for all Polyend tracks
    local track_mapping = {}
    for track_idx = 1, pattern_data.track_count do
        track_mapping[track_idx] = track_idx -- Direct 1:1 mapping
    end
    
    -- Import the pattern
    local success = import_pattern_to_renoise(pattern_data, current_pattern_index, track_mapping, filename)
    
    if success then
        local filename_only = filename:match("[^/\\]+$") or "pattern"
        renoise.app():show_status(string.format("MTP pattern imported: %s (%d tracks)", filename_only, pattern_data.track_count))
        return true
    else
        renoise.app():show_error("Failed to import MTP pattern: " .. filename)
        return false
    end
end

-- Register the file import hook for MTP files
local mtp_integration = {
    category = "sample",  -- Changed from "other" to "sample" like RX2
    extensions = { "mtp" },
    invoke = mtp_import_hook
}

-- Check if hook already exists
local has_mtp_hook = renoise.tool():has_file_import_hook("sample", { "mtp" })

if not has_mtp_hook then
    local success, error_msg = pcall(function()
        renoise.tool():add_file_import_hook(mtp_integration)
    end)
    if not success then
        renoise.app():show_error("ERROR registering MTP hook: " .. tostring(error_msg))
    end
end

-- Register the file import hook for MT project files
local mt_integration = {
    category = "song",  -- Project files are song-level
    extensions = { "mt" },
    invoke = mt_import_hook
}

-- Check if hook already exists
local has_mt_hook = renoise.tool():has_file_import_hook("song", { "mt" })

if not has_mt_hook then
    local success, error_msg = pcall(function()
        renoise.tool():add_file_import_hook(mt_integration)
    end)
    if not success then
        renoise.app():show_error("ERROR registering MT hook: " .. tostring(error_msg))
    end
end 


