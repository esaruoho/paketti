-- PakettiPolyendPatternData.lua
-- Polyend Pattern Data functionality for Paketti
-- Import Polyend Tracker patterns and projects into Renoise

print("PakettiPolyendPatternData.lua loaded")

local vb = renoise.ViewBuilder()
local bit = require("bit")
local separator = package.config:sub(1,1)

-- Dialog variables
local pattern_dialog = nil
local project_dialog = nil
local selected_polyend_path = ""
local available_patterns = {}
local available_projects = {}

-- Constants for Polyend format
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
    NOTE_OFF = -2,
    NOTE_CUT = -3,
    
    -- FX mappings to Renoise effects
    FX_MAP = {
        [1] = "0G",   -- Glide
        [2] = "01",   -- Arpeggio
        [3] = "02",   -- Pitch Bend
        [4] = "09",   -- Offset
        [5] = "0C",   -- Volume
        [6] = "08",   -- Pan
        [7] = "0E",   -- Extended
        [8] = "0A",   -- Volume Slide
        [9] = "05",   -- Tone Porta
        [10] = "06",  -- Vibrato
        [11] = "07",  -- Tremolo
        [12] = "0D",  -- Pattern Break
        [13] = "0B",  -- Position Jump
        [14] = "0F",  -- Set Speed
        [15] = "11",  -- Fine Volume Up
        [16] = "12",  -- Fine Volume Down
        [17] = "13",  -- Note Cut
        [18] = "14",  -- Note Delay
        [19] = "15",  -- Pattern Delay
        [20] = "16",  -- Pattern Loop
        [21] = "ZT",  -- Tremor
        [22] = "ZB",  -- Backwards
        [23] = "ZR",  -- Reverse
        [24] = "ZS",  -- Slice
        [25] = "ZD",  -- Delay
        [26] = "ZF",  -- Filter
        [27] = "ZG",  -- Glitch
        [28] = "ZL",  -- Low Pass
        [29] = "ZH",  -- High Pass
        [30] = "ZK",  -- Peak
        [31] = "ZN",  -- Notch
        [32] = "ZV",  -- Vowel
        [33] = "ZC",  -- Chorus
        [34] = "ZP",  -- Phaser
        [35] = "ZE",  -- Echo
        [36] = "ZA",  -- Autopan
        [37] = "ZU",  -- Unison
        [38] = "ZO",  -- Overdrive
        [39] = "ZW",  -- Wah
        [40] = "ZX",  -- Exciter
        [41] = "ZY",  -- Dynamics
        [42] = "ZQ",  -- EQ
        [43] = "ZM",  -- Multimode
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

-- Binary file reading helpers
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

local function read_int16_le(file)
    local value = read_uint16_le(file)
    if not value then return nil end
    if value >= 32768 then
        value = value - 65536
    end
    return value
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

-- Read individual pattern file
local function read_pattern_file(filepath)
    local file = io.open(filepath, "rb")
    if not file then
        print("-- Polyend Pattern: Cannot open pattern file: " .. filepath)
        return nil
    end
    
    -- Read first 16 bytes for debugging
    print("=== DEBUGGING MTP FILE HEADER ===")
    file:seek("set", 0)
    local debug_bytes = file:read(16)
    if debug_bytes then
        print("File size check - read " .. #debug_bytes .. " bytes")
        local hex_string = ""
        for i = 1, math.min(16, #debug_bytes) do
            hex_string = hex_string .. string.format("%02X ", string.byte(debug_bytes, i))
        end
        print("First 16 bytes (hex):", hex_string)
        
        -- Show as characters too
        local char_string = ""
        for i = 1, math.min(16, #debug_bytes) do
            local b = string.byte(debug_bytes, i)
            char_string = char_string .. (b >= 32 and b <= 126 and string.char(b) or ".")
        end
        print("First 16 bytes (chars):", char_string)
    end
    
    -- Reset and read header (16 bytes)
    file:seek("set", 0)
    local id_file = file:read(2)  -- 2 bytes: file identifier
    local pattern_type = read_uint16_le(file)  -- 2 bytes: file type
    local fw_version = file:read(4)  -- 4 bytes: firmware version
    local file_structure_version = file:read(4)  -- 4 bytes: file structure version
    local file_size = read_uint16_le(file)  -- 2 bytes: file size
    local padding = file:read(2)  -- 2 bytes: padding
    
    print("Header values:")
    print("  id_file:", id_file)
    print("  pattern_type:", pattern_type)
    print("  fw_version:", fw_version and string.format("%d.%d.%d.%d", string.byte(fw_version, 1, 4)) or "nil")
    print("  file_structure_version:", file_structure_version and string.format("%d.%d.%d.%d", string.byte(file_structure_version, 1, 4)) or "nil")
    print("  file_size:", file_size)
    print("  Expected pattern_type:", POLYEND_CONSTANTS.PATTERN_TYPE)
    
    -- Skip pattern metadata (12 bytes of unused/reserved fields)
    file:read(12)
    
    -- Determine track count based on file size
    local function detect_track_count(file_size)
        local base_size = 16 + 12 + 4  -- header + metadata + crc
        local track_header_size = 1  -- lastStep byte per track
        local step_size = 6  -- 6 bytes per step
        local steps_per_track = 128
        local track_data_size = track_header_size + (step_size * steps_per_track)
        
        local track_counts = {8, 12, 16}
        for _, count in ipairs(track_counts) do
            local expected_size = base_size + (track_data_size * count)
            if file_size == expected_size then
                return count
            end
        end
        
        -- Default to 16 if size doesn't match exactly
        print("-- Warning: Could not determine track count from file size, defaulting to 16")
        return 16
    end
    
    local track_count = detect_track_count(file_size)
    print("  detected_track_count:", track_count)
    
    -- Accept multiple pattern types (2, 75, etc.) - different Polyend devices/versions
    local valid_pattern_types = {2, 75}  -- Add more as needed
    local is_valid_type = false
    for _, valid_type in ipairs(valid_pattern_types) do
        if pattern_type == valid_type then
            is_valid_type = true
            break
        end
    end
    
    if not is_valid_type then
        print("-- Polyend Pattern: Unsupported pattern type: " .. pattern_type .. " (supported: " .. table.concat(valid_pattern_types, ", ") .. ")")
        file:close()
        return nil
    end
    
    if pattern_type ~= POLYEND_CONSTANTS.PATTERN_TYPE then
        print("-- Polyend Pattern: Non-standard pattern type " .. pattern_type .. " detected, proceeding anyway...")
    end
    
    print(string.format("-- Polyend Pattern: Type %d, %d tracks", pattern_type, track_count))
    
    local pattern_data = {
        pattern_type = pattern_type,
        track_count = track_count,
        tracks = {}
    }
    
    -- Read track data
    for track = 1, track_count do
        -- Read lastStep byte (only used from first track)
        local last_step = read_uint8(file)
        if track == 1 then
            pattern_data.pattern_length = last_step + 1
            print(string.format("  pattern_length: %d steps", pattern_data.pattern_length))
        end
        
        local track_data = {}
        
        for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
            -- Read note as signed int8 (1 byte)
            local note_raw = read_uint8(file)
            local note = note_raw
            -- Convert unsigned byte to signed int8 if needed
            if note_raw and note_raw > 127 then
                note = note_raw - 256
            end
            
            local instrument = read_uint8(file)
            local fx1_type = read_uint8(file)
            local fx1_value = read_uint8(file)
            local fx2_type = read_uint8(file)
            local fx2_value = read_uint8(file)
            
            track_data[step] = {
                note = note,
                instrument = instrument,
                fx1_type = fx1_type,
                fx1_value = fx1_value,
                fx2_type = fx2_type,
                fx2_value = fx2_value
            }
        end
        
        pattern_data.tracks[track] = track_data
    end
    
    file:close()
    return pattern_data
end

-- Convert Polyend note to Renoise note
local function convert_polyend_note(polyend_note)
    if polyend_note == POLYEND_CONSTANTS.NOTE_EMPTY then
        return nil
    elseif polyend_note == POLYEND_CONSTANTS.NOTE_OFF then
        return 120 -- Note off
    elseif polyend_note == POLYEND_CONSTANTS.NOTE_CUT then
        return 121 -- Note cut
    else
        -- Convert to MIDI note (C-4 = 60)
        local midi_note = polyend_note + 4
        if midi_note >= 0 and midi_note <= 119 then
            return midi_note
        end
    end
    return nil
end

-- Convert Polyend FX to Renoise effect
local function convert_polyend_fx(fx_type, fx_value)
    if fx_type == 0 or fx_type > 43 then
        return nil, nil
    end
    
    local effect_string = POLYEND_CONSTANTS.FX_MAP[fx_type]
    if not effect_string then
        return nil, nil
    end
    
    local effect_value = string.format("%02X", fx_value)
    return effect_string, effect_value
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
local function import_pattern_to_renoise(pattern_data, target_pattern_index, track_mapping, filepath)
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
        
        if renoise_track_idx and renoise_track_idx <= #song.tracks then
            local renoise_pattern_track = target_pattern:track(renoise_track_idx)
            local renoise_song_track = song.tracks[renoise_track_idx]
            
            -- Clear the target track first
            print(string.format("Clearing track %d before import", renoise_track_idx))
            renoise_pattern_track:clear()
            
            -- Ensure track has enough effect columns
            if renoise_song_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                if renoise_song_track.visible_effect_columns < 2 then
                    renoise_song_track.visible_effect_columns = 2
                end
            end
            
            for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
                local step_data = polyend_track[step]
                if step_data then
                    local line = renoise_pattern_track:line(step)
                    
                    -- Convert note
                    local note = convert_polyend_note(step_data.note)
                    if note then
                        if note <= 119 then
                            line.note_columns[1].note_value = note
                        elseif note == 120 then
                            line.note_columns[1].note_string = "OFF"
                        elseif note == 121 then
                            line.note_columns[1].note_string = "CUT"
                        end
                        
                        -- Set instrument (this is just an index reference)
                        if step_data.instrument < 255 then
                            line.note_columns[1].instrument_value = step_data.instrument
                            instruments_used[step_data.instrument] = (instruments_used[step_data.instrument] or 0) + 1
                        end
                        
                        -- Note: MTP format doesn't include velocity data
                        -- Velocity/volume would need to come from instrument settings or effects
                    end
                    
                    -- Convert effects - ensure we have effect columns available
                    local fx1_cmd, fx1_val = convert_polyend_fx(step_data.fx1_type, step_data.fx1_value)
                    if fx1_cmd and #line.effect_columns >= 1 then
                        line.effect_columns[1].number_string = fx1_cmd
                        line.effect_columns[1].amount_string = fx1_val
                    end
                    
                    local fx2_cmd, fx2_val = convert_polyend_fx(step_data.fx2_type, step_data.fx2_value)
                    if fx2_cmd and #line.effect_columns >= 2 then
                        line.effect_columns[2].number_string = fx2_cmd
                        line.effect_columns[2].amount_string = fx2_val
                    end
                end
            end
            
            imported_tracks = imported_tracks + 1
        end
    end
    
    -- Show summary of instruments used and auto-load them
    if next(instruments_used) then
        print("-- Instrument indices used in pattern:")
        for instrument_idx, count in pairs(instruments_used) do
            print(string.format("  Instrument %02X: %d times", instrument_idx, count))
        end
        
        -- Auto-load corresponding MTI instruments  
        -- Extract root path from the pattern filepath
        local pattern_root = filepath:match("^(.+)" .. separator .. "patterns" .. separator)
        local instrument_mapping = auto_load_pattern_instruments(instruments_used, pattern_root)
        
        -- Update pattern data with correct Renoise instrument indices
        if next(instrument_mapping) then
            print("-- Updating pattern with correct instrument mappings...")
            for polyend_track_idx, polyend_track in ipairs(pattern_data.tracks) do
                local renoise_track_idx = track_mapping[polyend_track_idx]
                
                if renoise_track_idx and renoise_track_idx <= #song.tracks then
                    local renoise_pattern_track = target_pattern:track(renoise_track_idx)
                    
                    for step = 1, POLYEND_CONSTANTS.STEP_COUNT do
                        local step_data = polyend_track[step]
                        if step_data and step_data.instrument > 0 then
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
    else
        print("-- No instruments were used in this pattern")
    end
    
    print(string.format("-- Polyend Pattern: Imported %d tracks to pattern %d", imported_tracks, target_pattern_index))
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
    
    for i, pattern in ipairs(patterns) do
        if pattern.exists then
            local pattern_data = read_pattern_file(pattern.full_path)
            if pattern_data then
                -- Create new pattern in Renoise
                local target_pattern = i
                while target_pattern > #song.sequencer.pattern_sequence do
                    song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
                end
                
                -- Simple 1:1 track mapping
                local track_mapping = {}
                for track_idx = 1, pattern_data.track_count do
                    track_mapping[track_idx] = math.min(track_idx, #song.tracks)
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



-- Menu entries and keybindings
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Polyend:Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Polyend:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Polyend:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Polyend:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Xperimental/Work in Progress:Polyend:Polyend Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Xperimental/Work in Progress:Polyend:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Xperimental/Work in Progress:Polyend:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Xperimental/Work in Progress:Polyend:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}

renoise.tool():add_keybinding{name="Global:Paketti:Show Polyend Pattern Browser", invoke=PakettiPolyendPatternBrowser}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Project", invoke=PakettiImportPolyendProject}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Pattern", invoke=PakettiImportPolyendPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Import Polyend Pattern Tracks", invoke=PakettiImportPolyendPatternTracks}

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
    
    -- Create default 1:1 track mapping
    local track_mapping = {}
    for track_idx = 1, pattern_data.track_count do
        track_mapping[track_idx] = math.min(track_idx, #song.tracks)
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
local has_hook = renoise.tool():has_file_import_hook("sample", { "mtp" })

if not has_hook then
    local success, error_msg = pcall(function()
        renoise.tool():add_file_import_hook(mtp_integration)
    end)
    if not success then
        renoise.app():show_error("ERROR registering MTP hook: " .. tostring(error_msg))
    end
end 