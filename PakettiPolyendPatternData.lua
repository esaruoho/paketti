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

-- CRC32 lookup table (standard polynomial 0xEDB88320)
local crc32_table = {}
for i = 0, 255 do
    local crc = i
    for _ = 1, 8 do
        if bit.band(crc, 1) == 1 then
            crc = bit.bxor(bit.rshift(crc, 1), 0xEDB88320)
        else
            crc = bit.rshift(crc, 1)
        end
    end
    crc32_table[i] = crc
end

-- Compute CRC32 over a string of bytes
local function compute_crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        local byte = string.byte(data, i)
        local index = bit.band(bit.bxor(crc, byte), 0xFF)
        crc = bit.bxor(bit.rshift(crc, 8), crc32_table[index])
    end
    return bit.bxor(crc, 0xFFFFFFFF)
end

-- Write helpers for binary export
local function write_uint16_le(file, value)
    file:write(string.char(bit.band(value, 0xFF), bit.band(bit.rshift(value, 8), 0xFF)))
end

local function write_uint32_le(file, value)
    file:write(string.char(
        bit.band(value, 0xFF),
        bit.band(bit.rshift(value, 8), 0xFF),
        bit.band(bit.rshift(value, 16), 0xFF),
        bit.band(bit.rshift(value, 24), 0xFF)
    ))
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
                filename = string.format("pattern_%02d.mtp", pattern_count)  -- device uses 1-based, 2-digit
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

    -- Read extended project data from absolute offsets (discovered via ptlib)
    local global_tempo = nil
    local project_name = ""
    local track_names = {}
    local delay_params = {}
    local reverb_params = {}

    -- Re-open to read absolute offsets (file may be large enough)
    local file2 = io.open(filepath, "rb")
    if file2 then
        local file_size = file2:seek("end")

        -- Global tempo: float32 at offset 0x1C0 (VERIFIED against real device project.mt
        -- files: Treasure Island=140, Bios Creatures=170, sandroid=130, and Polyend's own
        -- official 2324-byte project template=130, all match 0x1C0. The old 0x80 offset read
        -- 0.0 on every real file, so BPM silently fell back to default — confirmed bug.)
        if file_size >= 0x1C4 then
            file2:seek("set", 0x1C0)
            local tempo_bytes = file2:read(4)
            if tempo_bytes and #tempo_bytes == 4 then
                -- Decode IEEE 754 float32 little-endian
                local b1, b2, b3, b4 = string.byte(tempo_bytes, 1, 4)
                local sign = (b4 >= 128) and -1 or 1
                local exponent = bit.band(bit.rshift(b4, 0), 0x7F) * 2 + bit.rshift(b3, 7)
                local mantissa = bit.band(b3, 0x7F) * 65536 + b2 * 256 + b1
                if exponent == 0 and mantissa == 0 then
                    global_tempo = 0
                elseif exponent == 0xFF then
                    global_tempo = nil  -- NaN or Inf
                else
                    global_tempo = sign * math.pow(2, exponent - 127) * (1 + mantissa / 8388608)
                end
                if global_tempo and global_tempo >= 20 and global_tempo <= 999 then
                    print(string.format("-- Project BPM: %.1f", global_tempo))
                else
                    global_tempo = nil  -- Invalid BPM value
                end
            end
        end

        -- Project name: char[32], offset is firmware-version-gated (matches the official
        -- tracker-lib: fileStructureVersion major >16 -> 0x810 (newest T+/Mini), >15 -> 0x80C
        -- (verified on real 16.x device files), else 0x600 (legacy/OG). Write side always 0x810.
        local fsv_major = file_structure_version and string.byte(file_structure_version, 1) or 0
        local name_offset = 0x600
        if fsv_major > 16 then name_offset = 0x810
        elseif fsv_major > 15 then name_offset = 0x80C end
        if file_size >= name_offset + 32 then
            file2:seek("set", name_offset)
            local name_bytes = file2:read(32)
            if name_bytes then
                -- Extract null-terminated string
                local null_pos = name_bytes:find("\0")
                if null_pos then
                    project_name = name_bytes:sub(1, null_pos - 1)
                else
                    project_name = name_bytes
                end
                -- Clean non-printable chars
                project_name = project_name:gsub("[%c]", "")
                if project_name ~= "" then
                    print(string.format("-- Project name: '%s'", project_name))
                end
            end
        end

        -- Track names: first 8 tracks at 21-byte intervals from 0x428
        local track_name_offsets = {0x428, 0x43D, 0x452, 0x467, 0x47C, 0x491, 0x4A6, 0x4BB}
        for i = 1, 8 do
            if file_size >= track_name_offsets[i] + 21 then
                file2:seek("set", track_name_offsets[i])
                local name_bytes = file2:read(21)
                if name_bytes then
                    local null_pos = name_bytes:find("\0")
                    local name = null_pos and name_bytes:sub(1, null_pos - 1) or name_bytes
                    track_names[i] = name:gsub("[%c]", "")
                end
            end
        end

        -- Track names: next 8 tracks at 8-byte intervals from 0x603
        if file_size >= 0x603 + 64 then
            for i = 1, 8 do
                local offset = 0x603 + (i - 1) * 8
                file2:seek("set", offset)
                local name_bytes = file2:read(8)
                if name_bytes then
                    local null_pos = name_bytes:find("\0")
                    local name = null_pos and name_bytes:sub(1, null_pos - 1) or name_bytes
                    track_names[8 + i] = name:gsub("[%c]", "")
                end
            end
        end

        -- Delay parameters
        if file_size >= 0x53C then
            file2:seek("set", 0x11A)
            delay_params.feedback = read_uint8(file2)
            file2:seek("set", 0x11C)
            delay_params.time = read_uint16_le(file2)
            file2:seek("set", 0x11F)
            delay_params.params = read_uint8(file2)
            file2:seek("set", 0x539)
            delay_params.volume = read_uint8(file2)
            file2:seek("set", 0x53B)
            delay_params.mute = read_uint8(file2)
            print(string.format("-- Delay: feedback=%d, time=%d, volume=%d, mute=%d",
                delay_params.feedback or 0, delay_params.time or 0,
                delay_params.volume or 0, delay_params.mute or 0))
        end

        -- Reverb parameters (float32 values)
        if file_size >= 0x53B then
            -- Read float32 helper
            local function read_float32_at(f, offset)
                f:seek("set", offset)
                local bytes = f:read(4)
                if not bytes or #bytes < 4 then return 0 end
                local b1, b2, b3, b4 = string.byte(bytes, 1, 4)
                local sign = (b4 >= 128) and -1 or 1
                local exponent = bit.band(b4, 0x7F) * 2 + bit.rshift(b3, 7)
                local mantissa = bit.band(b3, 0x7F) * 65536 + b2 * 256 + b1
                if exponent == 0 and mantissa == 0 then return 0 end
                if exponent == 0xFF then return 0 end
                return sign * math.pow(2, exponent - 127) * (1 + mantissa / 8388608)
            end

            reverb_params.size = read_float32_at(file2, 0x418)
            reverb_params.damp = read_float32_at(file2, 0x41C)
            reverb_params.predelay = read_float32_at(file2, 0x420)
            reverb_params.diffusion = read_float32_at(file2, 0x424)
            file2:seek("set", 0x538)
            reverb_params.volume = read_uint8(file2)
            file2:seek("set", 0x53A)
            reverb_params.mute = read_uint8(file2)
            print(string.format("-- Reverb: size=%.2f, damp=%.2f, predelay=%.2f, diffusion=%.2f, volume=%d, mute=%d",
                reverb_params.size or 0, reverb_params.damp or 0,
                reverb_params.predelay or 0, reverb_params.diffusion or 0,
                reverb_params.volume or 0, reverb_params.mute or 0))
        end

        file2:close()
    end

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
        playlist_length = actual_playlist_length,
        global_tempo = global_tempo,
        project_name = project_name,
        track_names = track_names,
        delay_params = delay_params,
        reverb_params = reverb_params
    }
end

-- Global mapping table to track Polyend instrument indices to Renoise instrument slots
_G.polyend_to_renoise_instrument_mapping = {}

-- Global variable to track detected BPM from patterns
_G.polyend_detected_bpm = nil

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
    
    -- Clear the global mapping table and BPM detection
    _G.polyend_to_renoise_instrument_mapping = {}
    _G.polyend_detected_bpm = nil
    
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
                if not safeInsertInstrumentAt(song, #song.instruments + 1) then return end
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
    
    -- Set global song BPM from detected tempo or default
    local final_bpm = _G.polyend_detected_bpm or 128 -- Default to 128 BPM if no tempo found
    local song = renoise.song()
    if song and song.transport then
        song.transport.bpm = final_bpm
        print(string.format("-- SET GLOBAL BPM: %d BPM", final_bpm))
        renoise.app():show_status(string.format("Polyend MT Project: Set BPM to %d", final_bpm))
    end
    
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
    
    -- Debug output for potential BPM data in unused fields
    if f_unused1 and f_unused1 ~= 0.0 then
        print(string.format("-- DEBUG: MTP f_unused1 = %.2f (potential BPM?)", f_unused1))
    end
    if f_unused2 and f_unused2 ~= 0.0 then
        print(string.format("-- DEBUG: MTP f_unused2 = %.2f (potential BPM?)", f_unused2))
    end
    
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

-- Convert Polyend FX to Renoise effect
local function convert_polyend_fx(fx_type, fx_value)
    if not fx_type or fx_type == 0 then
        return nil, nil, nil -- No effect (None)
    end

    -- FX 1: Off - no Renoise equivalent needed
    if fx_type == 1 then
        return nil, nil, nil

    -- FX 2: Micro-move → 09xx (Sample Offset)
    -- Polyend 0-100 → Renoise 00-FF
    elseif fx_type == 2 then
        local offset = math.floor((fx_value / 100) * 255)
        return "09", string.format("%02X", offset), "Sample Offset"

    -- FX 3: Roll → 0Exy (Retrigger)
    -- Polyend 0-47 → Renoise retrigger ticks
    elseif fx_type == 3 then
        -- Map roll value to retrigger: lower Polyend values = more subdivisions
        local retrig = math.max(1, math.min(15, math.floor(fx_value / 3)))
        return "0E", string.format("0%X", retrig), "Retrigger"

    -- FX 4: Chance - no direct Renoise equivalent
    -- FX 5: Random Note - no direct Renoise equivalent
    -- FX 6: Random Instrument - no direct Renoise equivalent
    -- FX 7: Random Volume - no direct Renoise equivalent

    -- FX 8-12, 37: MIDI CC A-F
    -- On the Polyend Tracker, CC A-F send user-configured CC numbers to MIDI instruments (48-63).
    -- The actual CC number assignments are stored in project.mt at undocumented offsets.
    -- We log these for reference but can't map them without knowing the target CC numbers.
    -- Users can route these via Renoise's *Instr. MIDI Control device after import.
    elseif fx_type == 8 or fx_type == 9 or fx_type == 10 or fx_type == 11 or fx_type == 12 or fx_type == 37 then
        local cc_letter = ({[8]="A",[9]="B",[10]="C",[11]="D",[12]="E",[37]="F"})[fx_type]
        return nil, nil, string.format("MIDI CC %s = %d (configure via Instr. MIDI Control)", cc_letter, fx_value)

    -- FX 13: Break Pattern → 0D00
    elseif fx_type == 13 then
        return "0D", "00", "Pattern Break"

    -- FX 14: MIDI Chord - no direct Renoise equivalent

    -- FX 15: Tempo → F0xx
    elseif fx_type == 15 then
        local bpm = (fx_value * 2) + 8
        if not _G.polyend_detected_bpm then
            _G.polyend_detected_bpm = bpm
            print(string.format("-- DETECTED BPM: %d from Polyend Tempo FX", bpm))
        end
        local renoise_bpm = math.min(255, math.max(32, bpm))
        return "F0", string.format("%02X", renoise_bpm), "Tempo"

    -- FX 16: Random FX Value - no direct Renoise equivalent

    -- FX 17: Swing → ZTxx (Set Groove)
    -- Polyend 25-75 (-25 to +25), Renoise groove amount
    elseif fx_type == 17 then
        -- Map swing to groove. Polyend 50=no swing, Renoise uses groove tables
        -- Approximate: convert to delay column value (0-FF)
        local swing_offset = fx_value - 50  -- -25 to +25
        if swing_offset ~= 0 then
            local delay = math.floor(128 + (swing_offset / 25) * 127)
            delay = math.max(0, math.min(255, delay))
            return "ZD", string.format("%02X", delay), "Swing/Delay"
        end
        return nil, nil, nil

    -- FX 18: Volume/Velocity → 0Cxx
    elseif fx_type == 18 then
        -- Polyend 0-100 → Renoise volume 00-80 (0x80 = full)
        local vol = math.floor((fx_value / 100) * 128)
        return "0C", string.format("%02X", math.min(128, vol)), "Volume"

    -- FX 19: Glide → 05xx (Glide to Note)
    -- Polyend 0-100 → Renoise glide speed
    elseif fx_type == 19 then
        local glide = math.floor((fx_value / 100) * 255)
        return "05", string.format("%02X", glide), "Glide"

    -- FX 20: Gate Length → 0Cxx approximation (Note Cut after N ticks)
    elseif fx_type == 20 then
        -- Polyend 0-100 gate length, map to ECxy (Note Cut at tick y)
        -- Lower gate = earlier cut
        local tick = math.max(0, math.min(15, math.floor((fx_value / 100) * 15)))
        if tick < 15 then
            return "EC", string.format("0%X", tick), "Gate Length"
        end
        return nil, nil, nil

    -- FX 21: Arp → 00xy (Arpeggio)
    elseif fx_type == 21 then
        -- Polyend arp value 0-33, encode as semitone intervals
        -- Simple mapping: value as combined xy where x=major, y=minor intervals
        local x = math.min(15, math.floor(fx_value / 3))
        local y = math.min(15, fx_value % 3 * 4)
        return "00", string.format("%X%X", x, y), "Arpeggio"

    -- FX 22: Position → 09xx (Sample Offset)
    elseif fx_type == 22 then
        local offset = math.floor((fx_value / 100) * 255)
        return "09", string.format("%02X", offset), "Position/Offset"

    -- FX 25: Sample Slice → 0Sxx (Trigger Slice)
    elseif fx_type == 25 then
        -- Polyend 0-47 (displayed 1-48) → Renoise Sxx
        local slice = math.min(255, fx_value + 1)
        return "0S", string.format("%02X", slice), "Slice"

    -- FX 26: Reverse Playback → 0B01 (Reverse)
    elseif fx_type == 26 then
        if fx_value > 0 then
            return "0B", "01", "Reverse"
        else
            return "0B", "00", "Forward"
        end

    -- FX 27: Filter Low-pass → cutoff value (approximate with volume as placeholder)
    -- FX 28: Filter High-pass
    -- FX 29: Filter Band-pass
    -- These need DSP device control; store as comments for now
    elseif fx_type == 27 or fx_type == 28 or fx_type == 29 then
        -- Map to Renoise filter cutoff if available
        -- Use 24xx for cutoff (if filter device is in chain)
        local cutoff = math.floor((fx_value / 100) * 255)
        return "24", string.format("%02X", cutoff), "Filter Cutoff"

    -- FX 30: Delay Send → log for reference (per-step send levels need track automation)
    elseif fx_type == 30 then
        return nil, nil, string.format("Delay Send = %d%% (apply via Send device)", fx_value)

    -- FX 31: Panning → 08xx
    elseif fx_type == 31 then
        -- Polyend: 0-100 (50=center), Renoise: 00-FF (80=center)
        local pan_value = math.floor((fx_value / 100) * 255)
        return "08", string.format("%02X", pan_value), "Panning"

    -- FX 32: Reverb Send → log for reference (per-step send levels need track automation)
    elseif fx_type == 32 then
        return nil, nil, string.format("Reverb Send = %d%% (apply via Send device)", fx_value)

    -- FX 34: Micro-tune/Pitchbend → 0Mxx (Set Fine Pitch)
    elseif fx_type == 34 then
        -- Polyend 0-198 maps to -99 to +99
        -- Renoise fine pitch: 00-7F down, 80-FF up (80=center)
        local pitch = fx_value - 99  -- -99 to +99
        local renoise_pitch = math.floor(128 + (pitch / 99) * 127)
        renoise_pitch = math.max(0, math.min(255, renoise_pitch))
        return "0M", string.format("%02X", renoise_pitch), "Fine Pitch"

    -- FX 38: Overdrive → log (would need Distortion DSP device in Renoise)
    elseif fx_type == 38 then
        return nil, nil, string.format("Overdrive = %d%% (add Distortion DSP)", fx_value)

    -- FX 39: Bit Depth → log (would need LoFi DSP device in Renoise)
    elseif fx_type == 39 then
        return nil, nil, string.format("Bit Depth = %d (add LoFi DSP)", fx_value)

    -- FX 40: Tune → 0Uxx (Pitch up/down in semitones)
    elseif fx_type == 40 then
        -- Polyend 0-48 maps to -24 to +24 semitones
        local semitones = fx_value - 24
        if semitones > 0 then
            return "01", string.format("%02X", math.min(255, semitones * 16)), "Pitch Up"
        elseif semitones < 0 then
            return "02", string.format("%02X", math.min(255, math.abs(semitones) * 16)), "Pitch Down"
        end
        return nil, nil, nil

    -- FX 41: Slide Up → 01xx (Pitch Slide Up)
    elseif fx_type == 41 then
        return "01", string.format("%02X", math.min(255, fx_value)), "Slide Up"

    -- FX 42: Slide Down → 02xx (Pitch Slide Down)
    elseif fx_type == 42 then
        return "02", string.format("%02X", math.min(255, fx_value)), "Slide Down"

    else
        -- Unmapped FX: LFOs (23,24,33,35,36), CC sends (8-12,37), Random (4-7,16), MIDI Chord (14)
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
-- Global so it can be driven headlessly (PakettiMCP test harness) and reused
-- programmatically (clipboard/selection export). Writes pattern `pattern_index`
-- (1-based Renoise) to `output_path` as a byte-faithful .mtp with `track_count` tracks.
function export_pattern_to_mtp(pattern_index, output_path, track_count, start_line, num_lines)
    track_count = track_count or 16  -- Default to 16 tracks for Tracker Mini/Plus
    start_line = start_line or 1      -- 1-based first Renoise line to export (for splitting
                                      -- long patterns / exporting a selection into one .mtp)
    -- num_lines: optional explicit length (for selection export); else to end of pattern.

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
    
    -- Header (28 bytes before track data), byte-faithful to REAL device .mtp files. Verified
    -- against sandroid/Treasure Island/Bios Creatures patterns: id="KS" (the real Tracker
    -- signature — NOT "PM"/"--"), type=2, fwVersion=1.9.1.1, fileStructureVersion=5.5.5.5,
    -- size field = TOTAL file size, then 2 padding + 12 unused (2 float32 + 4 bytes), all zero.
    local total_size = 28 + (track_count * 769) + 4   -- 16 trk = 12336, matches real device files
    file:write("KS")                                   -- id_file (0x4B53)
    file:write(string.char(2, 0))                      -- type = 2 (uint16 LE)
    file:write(string.char(1, 9, 1, 1))                -- fwVersion 1.9.1.1
    file:write(string.char(5, 5, 5, 5))                -- fileStructureVersion 5.5.5.5
    write_uint16_le(file, total_size)                  -- size = total file size (uint16 LE)
    file:write(string.char(0, 0))                      -- 2 padding bytes
    for _ = 1, 12 do file:write(string.char(0)) end    -- 12 unused bytes (zeros)
    
    -- Get pattern length
    -- Number of lines to export from start_line, capped at the Polyend 128-step max.
    local lines_remaining = pattern.number_of_lines - (start_line - 1)
    if num_lines then lines_remaining = math.min(lines_remaining, num_lines) end
    local pattern_length = math.max(0, math.min(lines_remaining, 128))
    local last_step = pattern_length - 1  -- 0-based

    -- Map Polyend tracks ONLY to Renoise SEQUENCER tracks. Master / Send / Group tracks
    -- have no note columns, so indexing note_columns[1] on them crashes — collect the
    -- sequencer-track indices and map Polyend track N to the Nth sequencer track.
    local sequencer_track_indices = {}
    for ti = 1, #song.tracks do
        if song.tracks[ti].type == renoise.Track.TRACK_TYPE_SEQUENCER then
            sequencer_track_indices[#sequencer_track_indices + 1] = ti
        end
    end

    -- Write track data
    for track_idx = 1, track_count do
        -- Write lastStep byte on EVERY track. Real device patterns store the same lastStep
        -- (pattern_length - 1) on all 16 tracks, not just track 0 (verified on real files).
        file:write(string.char(last_step))

        -- Get the Renoise sequencer track that maps to this Polyend track (if any)
        local renoise_track = nil
        local renoise_track_index = sequencer_track_indices[track_idx]
        if renoise_track_index then
            renoise_track = pattern:track(renoise_track_index)
        end
        
        -- Write all 128 steps
        for step = 1, 128 do
            local note = -1  -- Default to empty
            local instrument = 0
            local fx0_type, fx0_value = 0, 0
            local fx1_type, fx1_value = 0, 0
            
            -- Get data from Renoise if step exists and track exists
            if step <= pattern_length and renoise_track then
                local line = renoise_track:line(start_line + step - 1)
                
                -- Convert note
                if line.note_columns[1].note_value < 120 then
                    note = line.note_columns[1].note_value
                elseif line.note_columns[1].note_string == "OFF" then
                    note = POLYEND_CONSTANTS.NOTE_OFF_FADE
                elseif line.note_columns[1].note_string == "CUT" then
                    note = POLYEND_CONSTANTS.NOTE_OFF_CUT
                end
                
                -- Instrument: direct device-correct mapping. The Polyend step byte is the
                -- 0-based instrument index, which equals the Renoise instrument_value (0-based).
                -- Instrument export writes "<value+1> <name>.pti", so step byte = value lines up
                -- with the file the device loads. Clamp to Polyend's 0-47 range. (Was a fragile
                -- "-2" offset that assumed one specific import slot scheme.)
                if line.note_columns[1].instrument_value < 255 then
                    instrument = math.max(0, math.min(47, line.note_columns[1].instrument_value))
                end
                
                -- Convert effects (very basic - only handle a few Renoise -> Polyend mappings)
                -- Helper to convert a single Renoise effect column to Polyend FX
                local function renoise_fx_to_polyend(fx_cmd, fx_val)
                    if fx_cmd == "0C" then      -- Volume → Volume/Velocity (18)
                        return 18, math.min(100, math.floor((fx_val / 128) * 100))
                    elseif fx_cmd == "08" then  -- Panning → Panning (31)
                        return 31, math.floor((fx_val / 255) * 100)
                    elseif fx_cmd == "F0" then  -- Tempo → Tempo (15)
                        return 15, math.max(4, math.min(200, math.floor((fx_val - 8) / 2)))
                    elseif fx_cmd == "0D" then  -- Pattern Break → Break (13)
                        return 13, 1
                    elseif fx_cmd == "01" then  -- Pitch Slide Up → Slide Up (41)
                        return 41, math.min(255, fx_val)
                    elseif fx_cmd == "02" then  -- Pitch Slide Down → Slide Down (42)
                        return 42, math.min(255, fx_val)
                    elseif fx_cmd == "05" then  -- Glide → Glide (19)
                        return 19, math.min(100, math.floor((fx_val / 255) * 100))
                    elseif fx_cmd == "00" and fx_val > 0 then  -- Arpeggio → Arp (21)
                        local x = math.floor(fx_val / 16)
                        return 21, math.min(33, x * 3)
                    elseif fx_cmd == "09" then  -- Sample Offset → Micro-move (2) or Position (22)
                        return 22, math.floor((fx_val / 255) * 100)
                    elseif fx_cmd == "0E" then  -- Retrigger → Roll (3)
                        local y = fx_val % 16
                        return 3, math.min(47, y * 3)
                    elseif fx_cmd == "EC" then  -- Note Cut → Gate Length (20)
                        local tick = fx_val % 16
                        return 20, math.floor((tick / 15) * 100)
                    elseif fx_cmd == "0B" then  -- Reverse → Reverse (26)
                        return 26, (fx_val > 0) and 1 or 0
                    elseif fx_cmd == "0S" then  -- Slice → Sample Slice (25)
                        return 25, math.max(0, math.min(47, fx_val - 1))
                    elseif fx_cmd == "24" then  -- Filter Cutoff → Filter LP (27)
                        return 27, math.floor((fx_val / 255) * 100)
                    elseif fx_cmd == "ZD" then  -- Set Groove → Swing (17), inverse of the import map
                        return 17, math.max(25, math.min(75, math.floor(50 + ((fx_val - 128) / 127) * 25)))
                    elseif fx_cmd == "0M" then  -- Fine Pitch → Micro-tune (34), inverse of the import map
                        return 34, math.max(0, math.min(198, math.floor(99 + ((fx_val - 128) / 127) * 99)))
                    end
                    return 0, 0
                end

                if #line.effect_columns >= 1 and line.effect_columns[1].number_string ~= "" then
                    local fx_cmd = line.effect_columns[1].number_string
                    local fx_val = tonumber(line.effect_columns[1].amount_string, 16) or 0
                    fx0_type, fx0_value = renoise_fx_to_polyend(fx_cmd, fx_val)
                end

                if #line.effect_columns >= 2 and line.effect_columns[2].number_string ~= "" then
                    local fx_cmd = line.effect_columns[2].number_string
                    local fx_val = tonumber(line.effect_columns[2].amount_string, 16) or 0
                    fx1_type, fx1_value = renoise_fx_to_polyend(fx_cmd, fx_val)
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
    
    -- CRC32 (4 bytes, LE) at end of file. Real device .mtp files store 0x00000000 — the
    -- hardware does not compute/verify it (every real file we checked is 0), and the official
    -- tracker-lib also writes 0. So write 4 zero bytes to be byte-identical to real device files.
    -- (The previous code never wrote these 4 bytes, then seek(end,-4) overwrote the last step's
    -- data — producing a 4-byte-short, malformed file the device rejected.)
    file:write(string.char(0, 0, 0, 0))
    file:close()

    print(string.format("-- MTP export complete: %s (%d bytes, %d tracks, %d steps)",
        output_path, total_size, track_count, pattern_length))
    return true
end

-- Split a Renoise pattern longer than Polyend's 128-step max into multiple .mtp files.
-- A 256-line pattern -> two 128-step parts; returns the list of files written. The caller
-- chains them in the playlist so the song plays back identically on the device.
function PakettiPolyendExportPatternSplit(pattern_index, output_dir, base_name, track_count)
    local song = renoise.song()
    local pat = song.patterns[pattern_index]
    if not pat then return {} end
    local sep = package.config:sub(1, 1)
    local parts = math.max(1, math.ceil(pat.number_of_lines / 128))
    local written = {}
    for part = 1, parts do
        local start_line = (part - 1) * 128 + 1
        local name = (parts > 1) and string.format("%s_part%02d.mtp", base_name, part)
                                  or  (base_name .. ".mtp")
        local path = output_dir .. sep .. name
        if export_pattern_to_mtp(pattern_index, path, track_count, start_line, 128) then
            written[#written + 1] = path
        end
    end
    print(string.format("-- Split pattern %d (%d lines) into %d .mtp file(s)",
        pattern_index, pat.number_of_lines, #written))
    return written
end

-- Export the current pattern selection's line range (clipboard-style) to a single .mtp.
-- Polyend patterns are whole-step, so column selection is ignored — the selected LINE
-- range becomes a 1..N-step pattern (capped at 128). With no selection, exports the
-- whole selected pattern.
function PakettiPolyendExportSelectionToMTP(output_path, track_count)
    local song = renoise.song()
    local pi = song.selected_pattern_index
    local sel = song.selection_in_pattern
    local start_line, num_lines
    if sel then
        start_line = sel.start_line
        num_lines = sel.end_line - sel.start_line + 1
    else
        start_line = 1
        num_lines = song.patterns[pi].number_of_lines
    end
    print(string.format("-- Export selection: pattern %d lines %d..%d (%d lines)",
        pi, start_line, start_line + num_lines - 1, num_lines))
    return export_pattern_to_mtp(pi, output_path, track_count or 16, start_line, num_lines)
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



-- Export project.mt file from Renoise song
-- Helper to encode a float32 to 4 little-endian bytes
local function encode_float32_le(value)
    if value == 0 then return string.char(0, 0, 0, 0) end
    local sign = 0
    if value < 0 then sign = 1; value = -value end
    local mantissa, exponent = math.frexp(value)
    exponent = exponent + 126  -- IEEE 754 bias
    mantissa = (mantissa * 2 - 1) * 8388608  -- 2^23
    local mant_int = math.floor(mantissa + 0.5)
    local b1 = bit.band(mant_int, 0xFF)
    local b2 = bit.band(bit.rshift(mant_int, 8), 0xFF)
    local b3 = bit.bor(bit.band(bit.rshift(mant_int, 16), 0x7F), bit.lshift(bit.band(exponent, 1), 7))
    local b4 = bit.bor(bit.rshift(exponent, 1), bit.lshift(sign, 7))
    return string.char(b1, b2, b3, b4)
end

-- Embedded real-device project.mt template (a clean 2320-byte "ripe glass"
-- project the Tracker itself wrote: fwVersion 1.9.x, fileStructureVersion 16,
-- valid instrument/delay/reverb config). We patch playlist, tempo, names onto
-- it so the exported project.mt is byte-shaped exactly like a device file —
-- far more trustworthy than hand-rolling from zeros.
local POLYEND_MT_TEMPLATE_B64 = "TVQAAAEJAf8QEBAQEAkDIAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8BAAAAQALGAgAMgD0AQAAZAAAAG8SAz/4dRABAAAAAAAAAAAAAAAAAAAAAAAAr0IAAAEAAQABAAEAAQABAAEAAQABAgMEBQYHCAkKCwwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVgEAAQABAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD8AAAA/AAAAP3sULj9UcmFjayAxAAAAAAAAAAAAAAAAAABUcmFjayAyAAAAAAAAAAAAAAAAAABUcmFjayAzAAAAAAAAAAAAAAAAAABUcmFjayA0AAAAAAAAAAAAAAAAAABUcmFjayA1AAAAAAAAAAAAAAAAAABUcmFjayA2AAAAAAAAAAAAAAAAAABUcmFjayA3AAAAAAAAAAAAAAAAAABUcmFjayA4AAAAAAAAAAAAAAAAAABWVlZWVlZWVlZWAAAAVgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwEAAAEAfwEFBwtAgAAAAAAAAAAAAX8BBQcLQIAAAAAAAAAAAAJ/AQUHC0CAAAAAAAAAAAADfwEFBwtAgAAAAAAAAAAABH8BBQcLQIAAAAAAAAAAAAV/AQUHC0CAAAAAAAAAAAAGfwEFBwtAgAAAAAAAAAAAB38BBQcLQIAAAAAAAAAAAAh/AQUHC0CAAAAAAAAAAAAJfwEFBwtAgAAAAAAAAAAACn8BBQcLQIAAAAAAAAAAAAt/AQUHC0CAAAAAAAAAAAAMfwEFBwtAgAAAAAAAAAAADX8BBQcLQIAAAAAAAAAAAA5/AQUHC0CAAAAAAAAAAAAPfwEFBwtAgAAAAAAAAAAAACBOAQEBTWlkaSA5AABNaWRpIDEwAE1pZGkgMTEATWlkaSAxMgBNaWRpIDEzAE1pZGkgMTQATWlkaSAxNQBNaWRpIDE2AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABDBAQAAAAMAAAAAAAAASW5pdAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD8/AD8/PwAAAAAQwQEAAAAAAAAAAAAAAEluaXQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEMEBAAAAAgAAAAAAAABJbml0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAByaXBlIGdsYXNzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABQcm9qZWN0cwAAAAAAAAAAAAAAdJYBIASdACAEnwAgxHQCICy8ACA3BgNggAAAAGeiCmCAAAAA+LcAIE0tCmD4twAgAAA6QOR8A2AAADpAwwAAAAAAOkDDAAAA+gAAAEYAAAAAAAAAAQAAABAAAABwfwUgCwAAAAAAAADDAAAAb38FIAAAOkD8IDAANLwAIAEAAAAAAAAAAQAAABAAAACgfwUgAAAAAAAAAABnfwUgn38FIPwgMAA0vAAgAQAAACy8ACAAABxAjsR50AAAAAABAAAAAAAAAIDaASAEAAAAAAAAAA=="

local function polyend_b64decode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  data = data:gsub("[^"..b.."=]", "")
  return (data:gsub(".", function(x)
    if x == "=" then return "" end
    local r, f = "", (b:find(x) - 1)
    for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and "1" or "0") end
    return r
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
    if #x ~= 8 then return "" end
    local c = 0
    for i = 1, 8 do c = c + (x:sub(i,i) == "1" and 2^(8-i) or 0) end
    return string.char(c)
  end))
end

-- Global for headless testing (PakettiMCP) and programmatic project export.
function export_project_to_mt(output_path, playlist, playlist_pos)
    local song = renoise.song()

    -- Start from the real-device template, then patch fields by absolute offset.
    local template = polyend_b64decode(POLYEND_MT_TEMPLATE_B64)
    if #template < 0x82C then
        print("-- ERROR: project.mt template decode failed (" .. #template .. " bytes)")
        return false
    end

    local file = io.open(output_path, "wb")
    if not file then
        print("-- ERROR: Cannot create MT file: " .. output_path)
        return false
    end
    file:write(template)
    print(string.format("-- Exporting project.mt from template: %s (%d bytes, %d playlist entries)",
        output_path, #template, #playlist))

    -- Playlist (255 bytes @ 0x10) + position (1 byte @ 0x10F). Clear then write.
    file:seek("set", 0x10)
    for i = 1, 255 do
        local v = (playlist[i] and playlist[i] > 0) and math.min(255, playlist[i]) or 0
        file:write(string.char(v))
    end
    file:write(string.char(math.min(254, playlist_pos or 0)))

    -- Global tempo: float32 @ 0x1C0 (NOT 0x80 — verified against real device files
    -- and the official project template; 0x80 is always 0.0).
    file:seek("set", 0x1C0)
    file:write(encode_float32_le(song.transport.bpm))
    print(string.format("-- Exported BPM: %g @ 0x1C0", song.transport.bpm))

    -- Track names. Clear each fixed-width field first, then write name+null so no
    -- leftover template names ("ripe glass" tracks) bleed through.
    local seq_indices = {}
    for ti = 1, #song.tracks do
        if song.tracks[ti].type == renoise.Track.TRACK_TYPE_SEQUENCER then
            seq_indices[#seq_indices + 1] = ti
        end
    end
    -- Tracks 1-8: 21-byte fields @ 0x428; tracks 9-16: 8-byte fields @ 0x603.
    for slot = 1, 16 do
        local off, width
        if slot <= 8 then off = 0x428 + (slot - 1) * 21; width = 21
        else off = 0x603 + (slot - 9) * 8; width = 8 end
        file:seek("set", off)
        file:write(string.rep("\0", width))  -- clear field
        local ti = seq_indices[slot]
        if ti then
            local name = song.tracks[ti].name or ""
            if #name > width - 1 then name = name:sub(1, width - 1) end
            file:seek("set", off)
            file:write(name)
        end
    end

    -- Project name: char[32] @ 0x80C (template fileStructureVersion is 16 -> 0x80C,
    -- matching the version-gated reader). Clear then write.
    local project_name = song.name or "Renoise Project"
    if #project_name > 31 then project_name = project_name:sub(1, 31) end
    file:seek("set", 0x80C)
    file:write(string.rep("\0", 32))
    file:seek("set", 0x80C)
    file:write(project_name)
    print(string.format("-- Exported project name: '%s'", project_name))

    file:close()
    print(string.format("-- MT export complete: %s", output_path))
    return true
end

-- Export patternsMetadata file from Renoise pattern names
local function export_patterns_metadata(output_path, pattern_names)
    local file = io.open(output_path, "wb")
    if not file then
        print("-- ERROR: Cannot create patternsMetadata file: " .. output_path)
        return false
    end

    local record_count = #pattern_names
    local data_size = record_count * POLYEND_CONSTANTS.PATTERN_RECORD_SIZE

    print(string.format("-- Exporting patternsMetadata: %s (%d patterns)", output_path, record_count))

    -- Write 16-byte header
    file:write("PAMD")                        -- identifier (4 bytes)
    write_uint16_le(file, POLYEND_CONSTANTS.PAMD_VERSION) -- version (2 bytes)
    file:write(string.char(0, 0))             -- padding after version (2 bytes, offsets 0x06-0x07)
    write_uint32_le(file, data_size)          -- total data size (4 bytes, offset 0x08)
    write_uint32_le(file, 0)                  -- control flags (4 bytes, offset 0x0C)

    -- Write pattern records
    for i = 1, record_count do
        local name = pattern_names[i] or string.format("Pattern %d", i)
        -- Truncate to 30 chars max
        if #name > 30 then
            name = name:sub(1, 30)
        end

        -- Write name (30 chars) + null terminator (1 byte) = 31 bytes
        file:write(name)
        -- Pad with zeros to fill 31 bytes
        for _ = 1, 31 - #name do
            file:write(string.char(0))
        end

        -- Write reserved space (19 bytes of zeros)
        for _ = 1, 19 do
            file:write(string.char(0))
        end
    end

    file:close()
    print(string.format("-- patternsMetadata export complete: %s", output_path))
    return true
end

-- Export full Polyend project (all MTP patterns + project.mt + patternsMetadata + instruments)
function PakettiExportPolyendProject()
    -- Prompt for output folder, then delegate to the headless exporter.
    local output_folder = renoise.app():prompt_for_path("Select Output Folder for Polyend Project")
    if not output_folder or output_folder == "" then
        return
    end
    PakettiExportPolyendProjectToFolder(output_folder)
end

-- Headless project export to a given folder. Global so PakettiMCP can drive it and so it can
-- be reused programmatically. Writes patterns/, patternsMetadata, instruments/*.pti, project.mt.
function PakettiExportPolyendProjectToFolder(output_folder)
    local song = renoise.song()

    -- Determine track count from dialog or default
    local track_count = 16  -- Default to Tracker Mini/Plus

    -- Count sequencer tracks in Renoise
    local sequencer_track_count = 0
    for i = 1, #song.tracks do
        if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
            sequencer_track_count = sequencer_track_count + 1
        end
    end

    -- Clamp to valid Polyend track counts
    if sequencer_track_count <= 8 then
        track_count = 8
    elseif sequencer_track_count <= 12 then
        track_count = 12
    else
        track_count = 16
    end

    print(string.format("=== EXPORTING POLYEND PROJECT (%d tracks) ===", track_count))

    -- Create patterns subfolder
    local patterns_folder = output_folder .. separator .. "patterns"
    if separator == "\\" then
        os.execute('mkdir "' .. patterns_folder .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. patterns_folder .. '"')
    end

    -- Assign Polyend pattern numbers, splitting any Renoise pattern longer than 128 lines
    -- into multiple parts, then build the device playlist by expanding each sequence entry
    -- into its part numbers — so long patterns play back in order on the device.
    -- Files are pattern_NN.mtp, 1-based, sequential (matches the device + auto-loader).
    local pattern_parts = {}        -- renoise_pat_idx -> { polyend_num per 128-line part }
    local part_meta = {}            -- polyend_num -> name
    local patterns_exported = 0
    local next_polyend_num = 0

    -- Number patterns in first-appearance order within the sequence (stable, device-like).
    local seen, ordered = {}, {}
    for seq_idx = 1, #song.sequencer.pattern_sequence do
        local pat_idx = song.sequencer.pattern_sequence[seq_idx]
        if not seen[pat_idx] then seen[pat_idx] = true; ordered[#ordered + 1] = pat_idx end
    end

    for _, pat_idx in ipairs(ordered) do
        local nlines = song.patterns[pat_idx].number_of_lines
        local nparts = math.max(1, math.ceil(nlines / 128))
        local base_name = song.patterns[pat_idx].name
        if not base_name or base_name == "" then base_name = string.format("Pattern %d", pat_idx) end
        pattern_parts[pat_idx] = {}
        for part = 1, nparts do
            next_polyend_num = next_polyend_num + 1
            pattern_parts[pat_idx][part] = next_polyend_num
            local fpath = patterns_folder .. separator .. string.format("pattern_%02d.mtp", next_polyend_num)
            if export_pattern_to_mtp(pat_idx, fpath, track_count, (part - 1) * 128 + 1, 128) then
                patterns_exported = patterns_exported + 1
            end
            part_meta[next_polyend_num] = (nparts > 1)
                and string.format("%s (%d/%d)", base_name, part, nparts) or base_name
        end
    end

    -- Device playlist: expand each Renoise sequence entry into its pattern's part numbers.
    local playlist = {}
    for seq_idx = 1, #song.sequencer.pattern_sequence do
        local pat_idx = song.sequencer.pattern_sequence[seq_idx]
        for _, pnum in ipairs(pattern_parts[pat_idx] or {}) do
            playlist[#playlist + 1] = pnum
        end
    end

    -- Pattern names for metadata, indexed by Polyend number.
    local pattern_names = {}
    for pnum = 1, next_polyend_num do
        pattern_names[pnum] = part_meta[pnum] or string.format("Pattern %d", pnum)
    end

    -- Export patternsMetadata
    local metadata_path = patterns_folder .. separator .. "patternsMetadata"
    export_patterns_metadata(metadata_path, pattern_names)

    -- Export instruments as .pti so the project actually has SOUND on the device. Naming
    -- "<N> <name>.pti" (N = 1-based instrument number) matches real device files; the pattern
    -- step instrument byte is the 0-based Polyend index = N-1 = the Renoise instrument_value.
    -- (Polyend holds 48 sample instruments, 0-47, so we cap at the first 48.)
    local instruments_folder = output_folder .. separator .. "instruments"
    if separator == "\\" then
        os.execute('mkdir "' .. instruments_folder .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. instruments_folder .. '"')
    end
    local saved_instrument_index = song.selected_instrument_index
    local instruments_exported = 0
    for ri = 1, math.min(48, #song.instruments) do
        local inst = song.instruments[ri]
        if #inst.samples > 0 and inst.samples[1].sample_buffer and inst.samples[1].sample_buffer.has_sample_data then
            song.selected_instrument_index = ri
            local safe = (inst.name or ""):gsub('[/\\:%*%?"<>|]', "_")
            if safe == "" then safe = "Instrument" end
            local pti_path = instruments_folder .. separator .. string.format("%d %s.pti", ri, safe)
            if pti_savesample_to_path(pti_path) then
                instruments_exported = instruments_exported + 1
            end
        end
    end
    song.selected_instrument_index = saved_instrument_index
    print(string.format("-- Exported %d instrument(s) as .pti to %s", instruments_exported, instruments_folder))

    -- Export project.mt
    local mt_path = output_folder .. separator .. "project.mt"
    export_project_to_mt(mt_path, playlist, 0)

    renoise.app():show_status(string.format("Polyend project exported: %d patterns, %d instruments, %d sequence entries to %s",
        patterns_exported, instruments_exported, #playlist, output_folder))

    print("=== POLYEND PROJECT EXPORT COMPLETE ===")
end

-- Export current pattern to MTP file
function PakettiExportPolyendPattern()
    local song = renoise.song()
    local pattern_index = song.selected_pattern_index
    local pattern_name = song.patterns[pattern_index].name
    
    -- Create default filename
    local default_name = string.format("pattern_%02d", pattern_index)
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

-- Interactive wrapper: export the current pattern selection (or whole pattern) to one .mtp.
function PakettiPolyendExportSelectionDialog()
    local path = renoise.app():prompt_for_filename_to_write("mtp", "Export Selection to Polyend MTP")
    if not path or path == "" then return end
    if PakettiPolyendExportSelectionToMTP(path, 16) then
        renoise.app():show_status("Paketti: exported selection to " .. path)
    else
        renoise.app():show_error("Paketti: failed to export selection to MTP")
    end
end

-- Interactive wrapper: export the selected pattern, auto-splitting if it exceeds 128 lines.
function PakettiPolyendExportPatternSplitDialog()
    local song = renoise.song()
    local pi = song.selected_pattern_index
    local dir = renoise.app():prompt_for_path("Select folder for split Polyend MTP files")
    if not dir or dir == "" then return end
    local files = PakettiPolyendExportPatternSplit(pi, dir, string.format("pattern_%02d", pi), 16)
    renoise.app():show_status(string.format("Paketti: pattern %d exported as %d MTP file(s)", pi, #files))
end

-- Menu entries and keybindings
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Pattern Browser", invoke=PakettiPolyendPatternBrowser}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import Polyend Project", invoke=PakettiImportPolyendProject}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Export Pattern to MTP", invoke=PakettiExportPolyendPattern}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Export Selection to MTP", invoke=PakettiPolyendExportSelectionDialog}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Export Pattern to MTP (auto-split >128)", invoke=PakettiPolyendExportPatternSplitDialog}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Export Polyend Project", invoke=PakettiExportPolyendProject}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend:Import MT Project File", invoke=function() PakettiImportPolyendMTProject() end}

-- MIDI mappings: drive Polyend import/export from a controller (fire on button press).
renoise.tool():add_midi_mapping{name="Paketti:Import Polyend MT Project File", invoke=function(message) if message:is_trigger() then PakettiImportPolyendMTProject() end end}
renoise.tool():add_midi_mapping{name="Paketti:Export Pattern to Polyend MTP", invoke=function(message) if message:is_trigger() then PakettiExportPolyendPattern() end end}
renoise.tool():add_midi_mapping{name="Paketti:Export Selection to Polyend MTP", invoke=function(message) if message:is_trigger() then PakettiPolyendExportSelectionDialog() end end}
renoise.tool():add_midi_mapping{name="Paketti:Export Pattern to Polyend MTP (auto-split)", invoke=function(message) if message:is_trigger() then PakettiPolyendExportPatternSplitDialog() end end}
renoise.tool():add_midi_mapping{name="Paketti:Export Polyend Project", invoke=function(message) if message:is_trigger() then PakettiExportPolyendProject() end end}
--[[
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Pattern Browser", invoke=PakettiPolyendPatternBrowser}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Import Polyend Project", invoke=PakettiImportPolyendProject}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Polyend WIP:Export Pattern to MTP", invoke=PakettiExportPolyendPattern}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Polyend WIP:Import MT Project File", invoke=function() PakettiImportPolyendMTProject() end}

renoise.tool():add_keybinding{name="Global:Paketti:Show Polyend Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}
renoise.tool():add_keybinding{name="Global:Paketti:Export Pattern to MTP", invoke=PakettiExportPolyendPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Import MT Project File", invoke=function() PakettiImportPolyendMTProject() end}
]]--
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

    -- Apply pattern names from patternsMetadata file
    local metadata_path = project_root .. separator .. "patterns" .. separator .. "patternsMetadata"
    local pattern_names = read_pattern_metadata(metadata_path)
    if pattern_names then
        local song = renoise.song()
        local names_applied = 0
        for i, pdata in ipairs(pattern_names) do
            if pdata.name and pdata.name ~= "" and i <= #song.patterns then
                song.patterns[i].name = pdata.name
                names_applied = names_applied + 1
                print(string.format("-- Applied pattern name: %d = '%s'", i, pdata.name))
            end
        end
        print(string.format("-- Applied %d pattern names from patternsMetadata", names_applied))
    end

    -- Apply extended project data (BPM, project name, track names, delay, reverb)
    local song = renoise.song()

    -- Apply BPM
    if project_data.global_tempo and project_data.global_tempo >= 20 and project_data.global_tempo <= 999 then
        song.transport.bpm = math.floor(project_data.global_tempo + 0.5)
        print(string.format("-- Applied BPM: %d", song.transport.bpm))
    end

    -- Apply project name
    if project_data.project_name and project_data.project_name ~= "" then
        song.name = project_data.project_name
        print(string.format("-- Applied project name: '%s'", project_data.project_name))
    end

    -- Apply track names
    if project_data.track_names then
        for i, name in pairs(project_data.track_names) do
            if name and name ~= "" and i <= #song.tracks then
                if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
                    song.tracks[i].name = name
                    print(string.format("-- Applied track %d name: '%s'", i, name))
                end
            end
        end
    end

    -- Create send tracks for delay and reverb if project has them
    local delay_send_track = nil
    local reverb_send_track = nil

    if project_data.delay_params and project_data.delay_params.volume and project_data.delay_params.volume > 0
       and (not project_data.delay_params.mute or project_data.delay_params.mute == 0) then
        -- Create a Delay send track
        local send_count = 0
        for i = 1, #song.tracks do
            if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
                send_count = send_count + 1
            end
        end
        -- Insert send track after the last track
        song:insert_track_at(#song.tracks + 1)
        delay_send_track = #song.tracks
        song.tracks[delay_send_track].name = "PT Delay"

        -- Add Delay device
        local delay_device = song.tracks[delay_send_track]:insert_device_at("Audio/Effects/Native/Delay", 2)
        if delay_device then
            -- Map delay time (Polyend uint16 → milliseconds)
            local delay_time_ms = project_data.delay_params.time or 250
            -- Map feedback (0-100 → 0.0-1.0)
            local feedback = (project_data.delay_params.feedback or 50) / 100
            print(string.format("-- Created Delay send: time=%dms, feedback=%.0f%%",
                delay_time_ms, feedback * 100))
        end

        -- Set volume
        local vol = math.max(0, math.min(1.0, (project_data.delay_params.volume or 100) / 100))
        song.tracks[delay_send_track].postfx_volume.value = vol
        print(string.format("-- Delay send track created at track %d", delay_send_track))
    end

    if project_data.reverb_params and project_data.reverb_params.volume and project_data.reverb_params.volume > 0
       and (not project_data.reverb_params.mute or project_data.reverb_params.mute == 0) then
        -- Create a Reverb send track
        song:insert_track_at(#song.tracks + 1)
        reverb_send_track = #song.tracks
        song.tracks[reverb_send_track].name = "PT Reverb"

        -- Add Reverb device
        local reverb_device = song.tracks[reverb_send_track]:insert_device_at("Audio/Effects/Native/mpReverb", 2)
        if reverb_device then
            -- Reverb params are floats; map them to mpReverb parameters
            print(string.format("-- Created Reverb send: size=%.2f, damp=%.2f, predelay=%.2f, diffusion=%.2f",
                project_data.reverb_params.size or 0, project_data.reverb_params.damp or 0,
                project_data.reverb_params.predelay or 0, project_data.reverb_params.diffusion or 0))
        end

        -- Set volume
        local vol = math.max(0, math.min(1.0, (project_data.reverb_params.volume or 100) / 100))
        song.tracks[reverb_send_track].postfx_volume.value = vol
        print(string.format("-- Reverb send track created at track %d", reverb_send_track))
    end

    -- Store send track indices globally for per-instrument send routing
    _G.polyend_delay_send_track = delay_send_track
    _G.polyend_reverb_send_track = reverb_send_track

    -- Set up Renoise sequence based on playlist
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
        if #song.sequencer.pattern_sequence > 0 then
            song.sequencer.pattern_sequence[1] = sequence[1]
        else
            song.sequencer:insert_sequence_at(1, sequence[1])
        end

        -- Add remaining patterns to sequence
        for i = 2, #sequence do
            song.sequencer:insert_sequence_at(i, sequence[i])
        end

        print(string.format("-- Set up sequence with %d pattern entries", #sequence))
    end

    renoise.app():show_status(string.format("Imported Polyend project: %d instruments, %d patterns, %d sequence, BPM=%s, name='%s'",
        instruments_loaded, patterns_loaded, #sequence,
        project_data.global_tempo and tostring(math.floor(project_data.global_tempo + 0.5)) or "N/A",
        project_data.project_name or ""))

    print("=== POLYEND PROJECT IMPORT COMPLETE ===")
end

-- Direct MT project file import function for drag-and-drop
-- Global function for use by PakettiImport.lua file import hook
function mt_import_hook(filename)
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
-- Global function for use by PakettiImport.lua file import hook
function mtp_import_hook(filename)
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

-- NOTE: MTP and MT file import hook registrations moved to PakettiImport.lua for centralized management


