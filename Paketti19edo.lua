-- Paketti 19edo Tuning System
-- Reads notes from note column 1 and writes 19edo tuning effects to effect column 1

local tuning_data = {}
local tuning_file_path = "tunings/19edo.txt"

-- Function to load 19edo tuning data from file
function load_19edo_tuning_data()
    tuning_data = {}
    
    local file_path = renoise.tool().bundle_path .. tuning_file_path
    local file = io.open(file_path, "r")
    
    if not file then
        renoise.app():show_status("Error: Could not open " .. tuning_file_path)
        print("Error: Could not open file at " .. file_path)
        return false
    end
    
    print("Loading 19edo tuning data from: " .. file_path)
    
    for line in file:lines() do
        -- Parse line format: "1   A2"
        local midi_num, edo_note = line:match("^(%d+)%s+(%S+)$")
        if midi_num and edo_note then
            tuning_data[tonumber(midi_num)] = edo_note
            print("DEBUG: Loaded MIDI " .. midi_num .. " -> " .. edo_note)
        end
    end
    
    file:close()
    
    local count = 0
    for _ in pairs(tuning_data) do count = count + 1 end
    print("Loaded " .. count .. " 19edo tuning entries")
    renoise.app():show_status("Loaded " .. count .. " 19edo tuning entries")
    
    return true
end

-- Function to convert Renoise note string to MIDI note number
function note_string_to_midi_number(note_string)
    if not note_string or note_string == "" or note_string == "---" or note_string == "OFF" then
        return nil
    end
    
    -- Parse note format like "C-4", "C#4", "D-3", etc.
    local note_name, octave = note_string:match("^([A-G][#-]?)(%d)$")
    if not note_name or not octave then
        print("DEBUG: Could not parse note string: " .. note_string)
        return nil
    end
    
    octave = tonumber(octave)
    
    -- Note to semitone mapping (C = 0)
    local note_values = {
        ["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3,
        ["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7,
        ["G#"] = 8, ["A-"] = 9, ["A#"] = 10, ["B-"] = 11
    }
    
    local semitone = note_values[note_name]
    if not semitone then
        print("DEBUG: Unknown note name: " .. note_name)
        return nil
    end
    
    -- Calculate MIDI note number to match the 19edo.txt file numbering
    -- The file starts at 1 for what would be MIDI note 0 (C-1 in some systems)
    -- Standard MIDI: C4 = 60, so C0 = 12, C-1 = 0
    -- But the file starts at 1, so we need: MIDI_note + 1
    local standard_midi = octave * 12 + semitone
    local file_midi_number = standard_midi + 1
    
    print("DEBUG: Converted " .. note_string .. " (octave=" .. octave .. ", semitone=" .. semitone .. ") to standard MIDI " .. standard_midi .. ", file index " .. file_midi_number)
    return file_midi_number
end

-- Function to get 19edo tuning for a MIDI note number
function get_19edo_tuning(midi_number)
    if not midi_number or not tuning_data[midi_number] then
        return nil
    end
    
    return tuning_data[midi_number]
end

-- Function to convert 19edo note to hex value
function edo_note_to_hex(edo_note)
    if not edo_note then return "00" end
    
    -- Extract the note letter (A-S) and octave number
    local note_letter, octave = edo_note:match("^([A-S])(%d+)$")
    if not note_letter or not octave then
        print("DEBUG: Could not parse edo note: " .. edo_note)
        return "00"
    end
    
    -- Map note letters A-S to values 0-18 (19 divisions)
    local note_values = {
        A = 0, B = 1, C = 2, D = 3, E = 4, F = 5, G = 6, H = 7, I = 8, J = 9,
        K = 10, L = 11, M = 12, N = 13, O = 14, P = 15, Q = 16, R = 17, S = 18
    }
    
    local note_value = note_values[note_letter]
    if not note_value then
        print("DEBUG: Unknown note letter: " .. note_letter)
        return "00"
    end
    
    octave = tonumber(octave)
    
    -- Calculate a hex value: combine octave and note value
    -- Use octave as upper nibble, note value as lower part
    -- Clamp to 0-255 range
    local hex_value = math.min(255, (octave * 19) + note_value)
    
    -- Convert to hex string with uppercase and zero padding
    local hex_string = string.format("%02X", hex_value)
    
    print("DEBUG: Converted " .. edo_note .. " to hex " .. hex_string)
    return hex_string
end

-- Function to write 19edo tuning to effect column
function write_19edo_effect(track, pattern_line, edo_note)
    if not track or not pattern_line or not edo_note then
        return false
    end
    
    -- Write to effect column 1 (index 1 in Lua, 0-based in Renoise)
    if pattern_line.effect_columns and pattern_line.effect_columns[1] then
        -- Write the 19edo note name to effect number field and "00" to amount
        pattern_line.effect_columns[1].number_string = edo_note
        pattern_line.effect_columns[1].amount_string = "00"
        
        print("DEBUG: Wrote effect " .. edo_note .. "00 for " .. edo_note)
        return true
    end
    
    return false
end

-- Main function to process selected track with 19edo tuning
function apply_19edo_tuning_to_track()
    local song = renoise.song()
    local selected_track = song.selected_track
    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local track_pattern = pattern:track(song.selected_track_index)
    
    print("DEBUG: Processing track " .. song.selected_track_index .. " in pattern " .. pattern_index)
    
    -- Load tuning data if not already loaded
    if not next(tuning_data) then
        if not load_19edo_tuning_data() then
            return
        end
    end
    
    local processed_count = 0
    local total_lines = #track_pattern.lines
    
    -- Process each line in the track pattern
    for line_index = 1, total_lines do
        local pattern_line = track_pattern:line(line_index)
        
        -- Check note column 1
        if pattern_line.note_columns and pattern_line.note_columns[1] then
            local note_column = pattern_line.note_columns[1]
            local note_string = note_column.note_string
            
            if note_string and note_string ~= "---" and note_string ~= "" then
                print("DEBUG: Processing line " .. line_index .. " with note " .. note_string)
                
                -- Convert note to MIDI number
                local midi_number = note_string_to_midi_number(note_string)
                if midi_number then
                    -- Get 19edo tuning
                    local edo_note = get_19edo_tuning(midi_number)
                    if edo_note then
                        -- Write to effect column 1
                        if write_19edo_effect(selected_track, pattern_line, edo_note) then
                            processed_count = processed_count + 1
                            print("Line " .. line_index .. ": " .. note_string .. " -> " .. edo_note)
                        end
                    else
                        print("DEBUG: No 19edo tuning found for MIDI number " .. midi_number)
                    end
                else
                    print("DEBUG: Could not convert note " .. note_string .. " to MIDI number")
                end
            end
        end
    end
    
    renoise.app():show_status("Applied 19edo tuning to " .. processed_count .. " notes")
    print("Applied 19edo tuning to " .. processed_count .. " notes out of " .. total_lines .. " lines")
end

-- Function to clear 19edo effects from selected track
function clear_19edo_effects_from_track()
    local song = renoise.song()
    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local track_pattern = pattern:track(song.selected_track_index)
    
    local cleared_count = 0
    
    -- Process each line in the track pattern
    for line_index = 1, #track_pattern.lines do
        local pattern_line = track_pattern:line(line_index)
        
        -- Check effect column 1 for "19" effects
        if pattern_line.effect_columns and pattern_line.effect_columns[1] then
            local effect_column = pattern_line.effect_columns[1]
            if effect_column.number_string == "19" then
                effect_column.number_string = ""
                effect_column.amount_string = ""
                cleared_count = cleared_count + 1
            end
        end
    end
    
    renoise.app():show_status("Cleared " .. cleared_count .. " 19edo effects")
    print("Cleared " .. cleared_count .. " 19edo effects from track")
end

-- Initialize tuning data on load
load_19edo_tuning_data()

-- Menu entries
renoise.tool():add_menu_entry {
    name = "Pattern Editor:Paketti..:19edo:Apply 19edo Tuning to Selected Track",
    invoke = apply_19edo_tuning_to_track
}

renoise.tool():add_menu_entry {
    name = "Pattern Editor:Paketti..:19edo:Clear 19edo Effects from Selected Track", 
    invoke = clear_19edo_effects_from_track
}

-- Keybindings
renoise.tool():add_keybinding {
    name = "Pattern Editor:Paketti:Apply 19edo Tuning to Selected Track",
    invoke = apply_19edo_tuning_to_track
}

renoise.tool():add_keybinding {
    name = "Pattern Editor:Paketti:Clear 19edo Effects from Selected Track",
    invoke = clear_19edo_effects_from_track
}

print("Paketti 19edo Tuning System loaded") 