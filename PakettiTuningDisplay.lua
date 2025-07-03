-- Paketti User-Set Tuning System
-- Reads notes from note columns and writes tuning effects to sample effects

local tuning_data = {}
local tuning_files = {}
local tuning_dialog = nil  -- Dialog reference for tuning selection



-- Add preference for auto-input tuning (only if it doesn't exist)
if not renoise.tool().preferences.AutoInputTuning then
    renoise.tool().preferences:add_property("AutoInputTuning", "false")
end

-- Add preference for auto-input tuning file (only if it doesn't exist)
if not renoise.tool().preferences.UserSetTunings then
    renoise.tool().preferences:add_property("UserSetTunings", "")
end

-- Auto-input tuning state
local auto_input_enabled = false
local pattern_notifier = nil
local last_cursor_pos = nil
local last_pattern_hash = nil
local last_logged_position = nil

-- Function to scan tunings folder for available tuning files
function scan_tuning_files()
    tuning_files = {}
    local tunings_path = renoise.tool().bundle_path .. "tunings/"
    
    -- Try to list files in tunings directory
    local success, files = pcall(function()
        return os.filenames(tunings_path, "*.txt")
    end)
    
    if success and files then
        for _, filename in ipairs(files) do
            table.insert(tuning_files, "tunings/" .. filename)
        end
    else
        -- Fallback: add known tuning files
        table.insert(tuning_files, "tunings/19edo.txt")
    end
    
    print("Found " .. #tuning_files .. " tuning files")
    return tuning_files
end

-- Function to load tuning data from user-selected file
function load_tuning_data(use_auto_input_pref)
    tuning_data = {}
    
    local tuning_pref
    if use_auto_input_pref then
        tuning_pref = renoise.tool().preferences.UserSetTunings
    else
        tuning_pref = renoise.tool().preferences.UserSetTunings
    end
    
    if not tuning_pref then
        return false
    end
    
    local tuning_file_path = tuning_pref.value
    if not tuning_file_path or tuning_file_path == "" then
        return false
    end
    
    local file_path
    -- Check if it's a custom file path (absolute path) or built-in tuning file
    if tuning_file_path:match("^tunings/") then
        -- Built-in tuning file
        file_path = renoise.tool().bundle_path .. tuning_file_path
    else
        -- Custom file path (assume it's already absolute)
        file_path = tuning_file_path
    end
    
    local file = io.open(file_path, "r")
    
    if not file then
        renoise.app():show_status("Error: Could not open " .. (tuning_file_path:match("([^/\\]+)$") or tuning_file_path))
        print("Error: Could not open file at " .. file_path)
        return false
    end
    
    print("Loading tuning data from: " .. file_path)
    
    for line in file:lines() do
        -- Parse line format: "1   A2"
        local midi_num, tuning_note = line:match("^(%d+)%s+(%S+)$")
        if midi_num and tuning_note then
            tuning_data[tonumber(midi_num)] = tuning_note
            print("DEBUG: Loaded MIDI " .. midi_num .. " -> " .. tuning_note)
        end
    end
    
    file:close()
    
    local count = 0
    local format_detected = nil
    for _, tuning_note in pairs(tuning_data) do 
        count = count + 1
        if not format_detected then
            if string.len(tuning_note) == 4 then
                format_detected = "XXYY"
            elseif string.len(tuning_note) == 2 then
                format_detected = "XX"
            else
                format_detected = "Unknown"
            end
        end
    end
    print("Loaded " .. count .. " tuning entries in " .. (format_detected or "Unknown") .. " format")
    
    local file_display = tuning_file_path:match("tunings/(.+)%.txt$") or tuning_file_path:match("([^/\\]+)$") or tuning_file_path
    renoise.app():show_status("Loaded " .. count .. " tuning entries from " .. file_display .. " (" .. (format_detected or "Unknown") .. " format)")
    
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

-- Function to get tuning for a MIDI note number
function get_tuning(midi_number)
    if not midi_number or not tuning_data[midi_number] then
        return nil
    end
    
    return tuning_data[midi_number]
end

-- Function to show tuning selection dialog
function show_tuning_selection_dialog()
    scan_tuning_files()
    
    if #tuning_files == 0 then
        renoise.app():show_status("No tuning files found in tunings/ folder")
        return false
    end
    
    local vb = renoise.ViewBuilder()
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    local current_tuning = tuning_pref and tuning_pref.value or ""
    local current_display = current_tuning ~= "" and current_tuning or "<None>"
    
    -- Create display names for popup
    local display_names = {"<None>"}
    local selected_index = 1
    local custom_file_path = ""  -- Store custom file path
    
    for i, file_path in ipairs(tuning_files) do
        local display_name = file_path:match("tunings/(.+)%.txt$") or file_path
        table.insert(display_names, display_name)
        if file_path == current_tuning then
            selected_index = i + 1
        end
    end
    
    -- Check if current tuning is a custom file (not in tunings folder)
    if current_tuning ~= "" and not current_tuning:match("^tunings/") then
        custom_file_path = current_tuning
        local custom_display = current_tuning:match("([^/\\]+)$") or current_tuning
        table.insert(display_names, "Custom: " .. custom_display)
        selected_index = #display_names
    end
    
    local dialog_content = vb:column {
        margin = 10,
        spacing = 5,
        
        vb:text {
            text = "Select Tuning System:",
            style = "strong"
        },
        
        vb:popup {
            id = "tuning_popup",
            items = display_names,
            value = selected_index,
            width = 320
        },
        
        vb:row {
            
            vb:button {
                text = "Set",
                width = 80,
                notifier = function()
                    local popup_value = vb.views.tuning_popup.value
                    local selected_file = ""  -- Declare selected_file at proper scope
                    
                    -- Ensure preference exists
                    if not renoise.tool().preferences.UserSetTunings then
                        renoise.tool().preferences:add_property("UserSetTunings", "")
                    end
                    
                    if popup_value == 1 then
                        -- <None> selected
                        renoise.app():show_status("Please select a tuning system first")
                        return
                    elseif popup_value <= #tuning_files + 1 then
                        -- Built-in tuning file selected
                        selected_file = tuning_files[popup_value - 1]
                        renoise.tool().preferences.UserSetTunings.value = selected_file
                        print("DEBUG: Set tuning preference to: " .. selected_file)
                    else
                        -- Custom file selected
                        selected_file = custom_file_path
                        renoise.tool().preferences.UserSetTunings.value = selected_file
                        print("DEBUG: Set tuning preference to custom file: " .. selected_file)
                    end
                    
                    -- Clear cached tuning data so it reloads
                    tuning_data = {}
                    
                    -- Apply tuning immediately
                    apply_tuning_to_track_immediate()
                end
            },
            
            vb:button {
                text = "Browse...",
                width = 80,
                notifier = function()
                    local filename = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Select custom tuning file...")
                    
                    if filename and filename ~= "" then
                        custom_file_path = filename
                        local custom_display = filename:match("([^/\\]+)$") or filename
                        
                        -- Add or update custom entry in popup
                        local custom_entry_name = "Custom: " .. custom_display
                        local found_custom = false
                        
                        -- Check if custom entry already exists and update it
                        for i, name in ipairs(display_names) do
                            if name:match("^Custom: ") then
                                display_names[i] = custom_entry_name
                                found_custom = true
                                break
                            end
                        end
                        
                        -- Add new custom entry if not found
                        if not found_custom then
                            table.insert(display_names, custom_entry_name)
                        end
                        
                        -- Update popup items and select the custom entry
                        vb.views.tuning_popup.items = display_names
                        vb.views.tuning_popup.value = #display_names
                        
                        renoise.app():show_status("Selected custom tuning file: " .. custom_display)
                    end
                end
            },
            
            vb:button {
                text = "OK",
                width = 80,
                notifier = function()
                    local popup_value = vb.views.tuning_popup.value
                    local selected_file = ""  -- Declare selected_file at proper scope
                    
                    -- Ensure preference exists
                    if not renoise.tool().preferences.UserSetTunings then
                        renoise.tool().preferences:add_property("UserSetTunings", "")
                    end
                    
                    if popup_value == 1 then
                        -- <None> selected
                        renoise.tool().preferences.UserSetTunings.value = ""
                        print("DEBUG: Set tuning preference to empty")
                    elseif popup_value <= #tuning_files + 1 then
                        -- Built-in tuning file selected
                        selected_file = tuning_files[popup_value - 1]
                        renoise.tool().preferences.UserSetTunings.value = selected_file
                        print("DEBUG: Set tuning preference to: " .. selected_file)
                    else
                        -- Custom file selected
                        selected_file = custom_file_path
                        renoise.tool().preferences.UserSetTunings.value = selected_file
                        print("DEBUG: Set tuning preference to custom file: " .. selected_file)
                    end
                    
                    -- Clear cached tuning data so it reloads
                    tuning_data = {}
                    
                    -- Show informative status message
                    local status_msg
                    if popup_value == 1 then
                        status_msg = "Tuning system cleared"
                    else
                        local file_display = selected_file:match("tunings/(.+)%.txt$") or selected_file:match("([^/\\]+)$") or selected_file
                        status_msg = "Tuning system set to: " .. file_display
                    end
                    renoise.app():show_status(status_msg)
                    
                    if tuning_dialog and tuning_dialog.visible then
                        tuning_dialog:close()
                    end
                    tuning_dialog = nil
                end
            },
            
            vb:button {
                text = "Cancel",
                width = 80,
                notifier = function()
                    if tuning_dialog and tuning_dialog.visible then
                        tuning_dialog:close()
                    end
                    tuning_dialog = nil
                end
            }
        }
    }
    
    -- Check if dialog is already open and close it
    if tuning_dialog and tuning_dialog.visible then
        tuning_dialog:close()
    end
    
    -- Show dialog and store reference
    tuning_dialog = renoise.app():show_custom_dialog("Paketti Tuning Selection", dialog_content)
    
    return true
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

-- Function to write tuning to note column sample effect
function write_tuning_effect(track, note_column, tuning_note)
    if not track or not note_column or not tuning_note then
        return false
    end
    
    -- Check if there's existing sample effect content
    local existing_effect = note_column.effect_number_string
    local existing_amount = note_column.effect_amount_string
    local had_existing = (existing_effect and existing_effect ~= "" and existing_effect ~= "00") or 
                        (existing_amount and existing_amount ~= "" and existing_amount ~= "00")
    
    -- Handle both 2-character (XX) and 4-character (XXYY) formats
    if string.len(tuning_note) == 4 then
        -- 4-character format like "SU03", "MI05" - split into XX and YY as strings
        local xx_part = string.sub(tuning_note, 1, 2)  -- "MI"
        local yy_part = string.sub(tuning_note, 3, 4)  -- "05"
        
        note_column.effect_number_string = xx_part
        note_column.effect_amount_string = yy_part
        
        if had_existing then
            print("DEBUG: Overwrote existing sample effect " .. (existing_effect or "00") .. (existing_amount or "00") .. " with " .. xx_part .. yy_part .. " (XXYY format: " .. tuning_note .. ")")
        else
            print("DEBUG: Wrote sample effect " .. xx_part .. yy_part .. " (XXYY format: " .. tuning_note .. ")")
        end
    else
        -- 2-character format like "A2", "B3" - write as XX string, set YY to "00"
        note_column.effect_number_string = tuning_note
        note_column.effect_amount_string = "00"
        
        if had_existing then
            print("DEBUG: Overwrote existing sample effect " .. (existing_effect or "00") .. (existing_amount or "00") .. " with " .. tuning_note .. "00 (XX format: " .. tuning_note .. ")")
        else
            print("DEBUG: Wrote sample effect " .. tuning_note .. "00 (XX format: " .. tuning_note .. ")")
        end
    end
    
    return true
end

-- Immediate apply function for the Set button (no dialog checks)
function apply_tuning_to_track_immediate()
    local song
    local success, error_msg = pcall(function()
        song = renoise.song()
    end)
    
    if not success or not song then
        renoise.app():show_status("No song available")
        return
    end
    
    local selected_track = song.selected_track
    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local track_pattern = pattern:track(song.selected_track_index)
    
    print("DEBUG: Immediately applying tuning to track " .. song.selected_track_index .. " in pattern " .. pattern_index)
    
    -- Make Sample FX Column visible on selected track
    selected_track.sample_effects_column_visible = true
    print("DEBUG: Made Sample FX Column visible on track")
    
    -- Load tuning data if not already loaded
    if not next(tuning_data) then
        if not load_tuning_data() then
            renoise.app():show_status("Failed to load tuning data")
            return
        end
    end
    
    local processed_count = 0
    local overwritten_count = 0
    local total_lines = #track_pattern.lines
    
    -- Process each line in the track pattern
    for line_index = 1, total_lines do
        local pattern_line = track_pattern:line(line_index)
        
        -- Check all note columns in this line
        if pattern_line.note_columns then
            for col_index = 1, #pattern_line.note_columns do
                local note_column = pattern_line.note_columns[col_index]
                local note_string = note_column.note_string
                
                if note_string and note_string ~= "---" and note_string ~= "" then
                    print("DEBUG: Processing line " .. line_index .. " column " .. col_index .. " with note " .. note_string)
                    
                    -- Check if there's existing sample effect content
                    local existing_effect = note_column.effect_number_string
                    local existing_amount = note_column.effect_amount_string
                    local had_existing = (existing_effect and existing_effect ~= "" and existing_effect ~= "00") or 
                                        (existing_amount and existing_amount ~= "" and existing_amount ~= "00")
                    
                    -- Convert note to MIDI number
                    local midi_number = note_string_to_midi_number(note_string)
                    if midi_number then
                        -- Get tuning
                        local tuning_note = get_tuning(midi_number)
                        if tuning_note then
                            -- Write to note column's sample effect
                            if write_tuning_effect(selected_track, note_column, tuning_note) then
                                processed_count = processed_count + 1
                                if had_existing then
                                    overwritten_count = overwritten_count + 1
                                end
                                print("Line " .. line_index .. " Col " .. col_index .. ": " .. note_string .. " -> " .. tuning_note)
                            end
                        else
                            print("DEBUG: No tuning found for MIDI number " .. midi_number)
                        end
                    else
                        print("DEBUG: Could not convert note " .. note_string .. " to MIDI number")
                    end
                end
            end
        end
    end
    
    local status_msg = "Applied tuning to " .. processed_count .. " notes"
    if overwritten_count > 0 then
        status_msg = status_msg .. " (overwrote " .. overwritten_count .. " existing sample effects)"
    end
    renoise.app():show_status(status_msg)
    print("Applied tuning to " .. processed_count .. " notes out of " .. total_lines .. " lines. Overwrote " .. overwritten_count .. " existing effects.")
end

-- Main function to process selected track with user-set tuning
function apply_tuning_to_track()
    -- Check if tuning preference exists and is set, show dialog if not
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    if not tuning_pref or tuning_pref.value == "" then
        show_tuning_selection_dialog()
        return
    end
    
    local song
    local success, error_msg = pcall(function()
        song = renoise.song()
    end)
    
    if not success or not song then
        renoise.app():show_status("No song available")
        return
    end
    
    local selected_track = song.selected_track
    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local track_pattern = pattern:track(song.selected_track_index)
    
    print("DEBUG: Processing track " .. song.selected_track_index .. " in pattern " .. pattern_index)
    
    -- Make Sample FX Column visible on selected track
    selected_track.sample_effects_column_visible = true
    print("DEBUG: Made Sample FX Column visible on track")
    
    -- Load tuning data if not already loaded
    if not next(tuning_data) then
        if not load_tuning_data() then
            renoise.app():show_status("Failed to load tuning data")
            return
        end
    end
    
    local processed_count = 0
    local total_lines = #track_pattern.lines
    
    -- Process each line in the track pattern
    for line_index = 1, total_lines do
        local pattern_line = track_pattern:line(line_index)
        
        -- Check all note columns in this line
        if pattern_line.note_columns then
            for col_index = 1, #pattern_line.note_columns do
                local note_column = pattern_line.note_columns[col_index]
                local note_string = note_column.note_string
                
                if note_string and note_string ~= "---" and note_string ~= "" then
                    print("DEBUG: Processing line " .. line_index .. " column " .. col_index .. " with note " .. note_string)
                    
                    -- Convert note to MIDI number
                    local midi_number = note_string_to_midi_number(note_string)
                    if midi_number then
                        -- Get tuning
                        local tuning_note = get_tuning(midi_number)
                        if tuning_note then
                            -- Write to note column's sample effect
                            if write_tuning_effect(selected_track, note_column, tuning_note) then
                                processed_count = processed_count + 1
                                print("Line " .. line_index .. " Col " .. col_index .. ": " .. note_string .. " -> " .. tuning_note)
                            end
                        else
                            print("DEBUG: No tuning found for MIDI number " .. midi_number)
                        end
                    else
                        print("DEBUG: Could not convert note " .. note_string .. " to MIDI number")
                    end
                end
            end
        end
    end
    
    renoise.app():show_status("Applied tuning to " .. processed_count .. " notes")
    print("Applied tuning to " .. processed_count .. " notes out of " .. total_lines .. " lines")
end

-- Function to clear tuning effects from selected track
function clear_tuning_effects_from_track()
    -- Check if tuning preference exists and is set, show dialog if not
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    if not tuning_pref or tuning_pref.value == "" then
        show_tuning_selection_dialog()
        return
    end
    local song
    local success, error_msg = pcall(function()
        song = renoise.song()
    end)
    
    if not success or not song then
        renoise.app():show_status("No song available")
        return
    end
    
    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local track_pattern = pattern:track(song.selected_track_index)
    
    local cleared_count = 0
    
    -- Process each line in the track pattern
    for line_index = 1, #track_pattern.lines do
        local pattern_line = track_pattern:line(line_index)
        
        -- Check all note columns for sample effects
        if pattern_line.note_columns then
            for col_index = 1, #pattern_line.note_columns do
                local note_column = pattern_line.note_columns[col_index]
                -- Clear any sample effect (since we're using tuning note names)
                if note_column.effect_number_string ~= "" then
                    note_column.effect_number_string = ""
                    note_column.effect_amount_string = ""
                    cleared_count = cleared_count + 1
                end
            end
        end
    end
    
    renoise.app():show_status("Cleared " .. cleared_count .. " sample effects")
    print("Cleared " .. cleared_count .. " sample effects from track")
end

-- Auto-input tuning functions
function auto_apply_tuning_to_note(track_index, line_index, note_column_index)
    -- Check if auto-input is enabled and tuning is set
    if not auto_input_enabled then
        print("DEBUG: Auto-input not enabled")
        return
    end
    
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    if not tuning_pref or tuning_pref.value == "" then
        print("DEBUG: No tuning preference set, value: '" .. (tuning_pref and tuning_pref.value or "nil") .. "'")
        return
    end
    
    print("DEBUG: Auto-applying tuning using file: " .. tuning_pref.value)
    
    -- Load tuning data if not already loaded
    if not next(tuning_data) then
        if not load_tuning_data(true) then
            return
        end
    end
    
    local song
    local success, error_msg = pcall(function()
        song = renoise.song()
    end)
    
    if not success or not song then
        print("DEBUG: No song available for auto-tuning")
        return
    end
    
    local track = song.tracks[track_index]
    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local track_pattern = pattern:track(track_index)
    
    if not track_pattern or not track_pattern.lines[line_index] then
        return
    end
    
    local pattern_line = track_pattern.lines[line_index]
    if not pattern_line.note_columns or not pattern_line.note_columns[note_column_index] then
        return
    end
    
    local note_column = pattern_line.note_columns[note_column_index]
    local note_string = note_column.note_string
    
    if note_string and note_string ~= "---" and note_string ~= "" and note_string ~= "OFF" then
        -- Make Sample FX Column visible on track
        track.sample_effects_column_visible = true
        
        -- Convert note to MIDI number
        local midi_number = note_string_to_midi_number(note_string)
        if midi_number then
            -- Get tuning
            local tuning_note = get_tuning(midi_number)
            if tuning_note then
                -- Write to note column's sample effect
                if write_tuning_effect(track, note_column, tuning_note) then
                    print("Auto-tuning: " .. note_string .. " -> " .. tuning_note .. " (Track " .. track_index .. ", Line " .. line_index .. ", Col " .. note_column_index .. ")")
                end
            end
        end
    end
end

function auto_input_idle_notifier()
    -- Check if auto-input is enabled
    if not auto_input_enabled then
        return
    end
    
    -- Safe song access with error handling
    local song
    local success, error_msg = pcall(function()
        song = renoise.song()
    end)
    
    if not success or not song or not song.selected_track then
        return
    end
    
    -- Get current cursor position
    local pos = song.transport.edit_pos
    local track_index = song.selected_track_index
    local line_index = pos.line
    local note_column_index = song.selected_note_column_index
    
    -- Create position hash for comparison
    local current_pos = track_index .. ":" .. line_index .. ":" .. note_column_index
    
    local should_check = false
    local reason = ""
    
    -- Check if cursor moved to a new position OR if we're on the same position (for editstep=0)
    if current_pos ~= last_cursor_pos then
        last_cursor_pos = current_pos
        should_check = true
        reason = "cursor moved"
        print("DEBUG: Cursor moved to position " .. current_pos)
    else
        -- Also check current position for notes without tuning (for editstep=0 case)
        should_check = true
        reason = "checking current position"
    end
    
    if should_check then
        -- Check if there's a note at the current position
        local pattern = song:pattern(song.selected_pattern_index)
        local track_pattern = pattern:track(track_index)
        
        if track_pattern and track_pattern.lines[line_index] then
            local pattern_line = track_pattern.lines[line_index]
            if pattern_line.note_columns and pattern_line.note_columns[note_column_index] then
                local note_column = pattern_line.note_columns[note_column_index]
                local note_string = note_column.note_string
                
                -- If there's a note, apply tuning (overwrites any existing effects)
                if note_string and note_string ~= "---" and note_string ~= "" and note_string ~= "OFF" then
                    if reason == "cursor moved" then
                        print("DEBUG: POSITION " .. current_pos .. " - Found NOTE: " .. note_string .. ", effect_number: '" .. (note_column.effect_number_string or "") .. "', effect_amount: '" .. (note_column.effect_amount_string or "") .. "'")
                        last_logged_position = current_pos
                    end
                    
                    -- Always apply tuning, overwriting any existing effects
                    print("DEBUG: POSITION " .. current_pos .. " - APPLYING TUNING to note " .. note_string .. " (" .. reason .. ")")
                    auto_apply_tuning_to_note(track_index, line_index, note_column_index)
                    last_logged_position = current_pos
                else
                    if reason == "cursor moved" then
                        print("DEBUG: POSITION " .. current_pos .. " - No note (found: " .. (note_string or "nil") .. ")")
                        last_logged_position = current_pos
                    end
                end
            end
        end
    end
end

function enable_auto_input_tuning()
    if auto_input_enabled then
        return -- Already enabled
    end
    
    auto_input_enabled = true
    renoise.tool().preferences.AutoInputTuning.value = "true"
    
    -- Make Sample FX Column visible on selected track
    local song
    local success, error_msg = pcall(function()
        song = renoise.song()
    end)
    
    if success and song and song.selected_track then
        song.selected_track.sample_effects_column_visible = true
        print("DEBUG: Made Sample FX Column visible on track")
    end
    
    -- Add idle notifier for polling cursor position
    if not renoise.tool():has_timer(auto_input_idle_notifier) then
        renoise.tool():add_timer(auto_input_idle_notifier, 50) -- Check every 50ms
    end
    
    -- Reset cursor tracking
    last_cursor_pos = nil
    
    -- Show informative status with tuning file name
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    local file_display = "Unknown"
    if tuning_pref and tuning_pref.value ~= "" then
        file_display = tuning_pref.value:match("tunings/(.+)%.txt$") or tuning_pref.value
    end
    
    renoise.app():show_status("Auto-Input Tuning: " .. file_display .. " Enabled")
    print("Auto-Input Tuning enabled with file: " .. file_display)
end

function disable_auto_input_tuning()
    if not auto_input_enabled then
        return -- Already disabled
    end
    
    auto_input_enabled = false
    renoise.tool().preferences.AutoInputTuning.value = "false"
    
    -- Remove idle timer
    if renoise.tool():has_timer(auto_input_idle_notifier) then
        renoise.tool():remove_timer(auto_input_idle_notifier)
    end
    
    -- Reset cursor tracking
    last_cursor_pos = nil
    
    -- Show informative status with tuning file name
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    local file_display = "Unknown"
    if tuning_pref and tuning_pref.value ~= "" then
        file_display = tuning_pref.value:match("tunings/(.+)%.txt$") or tuning_pref.value
    end
    
    renoise.app():show_status("Auto-Input Tuning: " .. file_display .. " Disabled")
    print("Auto-Input Tuning disabled for file: " .. file_display)
end

function toggle_auto_input_tuning()
    -- Check if tuning preference exists and is set
    local tuning_pref = renoise.tool().preferences.UserSetTunings
    if not tuning_pref or tuning_pref.value == "" then
        renoise.app():show_status("Please set a tuning system first")
        show_tuning_selection_dialog()
        return
    end
    
    if auto_input_enabled then
        disable_auto_input_tuning()
    else
        enable_auto_input_tuning()
    end
end

-- Initialize auto-input state from preferences
function initialize_auto_input_tuning()
    local auto_pref = renoise.tool().preferences.AutoInputTuning
    if auto_pref and auto_pref.value == "true" then
        enable_auto_input_tuning()
    else
        disable_auto_input_tuning()
    end
end

-- Initialize on tool startup
renoise.tool().app_new_document_observable:add_notifier(initialize_auto_input_tuning)

-- Safe initialization - only initialize if song is available
local function safe_initialize()
    if renoise.song() then
        initialize_auto_input_tuning()
    end
end

-- Use pcall to safely check for song availability during module loading
local success, error_msg = pcall(safe_initialize)
if not success then
    print("Paketti19edo: Deferred initialization - will initialize when song is loaded")
end

-- Menu entries and keybindings
renoise.tool():add_menu_entry {name = "Pattern Editor:Paketti:Tuning:Apply User-Set Tuning to Selected Track",invoke = apply_tuning_to_track}
renoise.tool():add_menu_entry {name = "Pattern Editor:Paketti:Tuning:Clear Tuning Effects from Selected Track", invoke = clear_tuning_effects_from_track}
renoise.tool():add_menu_entry {name = "Pattern Editor:Paketti:Tuning:User-Set Tuning Preferences Dialog...", invoke = show_tuning_selection_dialog}
renoise.tool():add_menu_entry {name = "Pattern Editor:Paketti:Tuning:Toggle Auto-Input Tuning", invoke = toggle_auto_input_tuning}

renoise.tool():add_keybinding {name = "Pattern Editor:Paketti:Apply User-Set Tuning to Selected Track",invoke = apply_tuning_to_track}
renoise.tool():add_keybinding {name = "Pattern Editor:Paketti:Clear Tuning Effects from Selected Track",invoke = clear_tuning_effects_from_track}
renoise.tool():add_keybinding {name = "Pattern Editor:Paketti:User-Set Tuning Preferences Dialog",invoke = show_tuning_selection_dialog}
renoise.tool():add_keybinding {name = "Pattern Editor:Paketti:Toggle Auto-Input Tuning",invoke = toggle_auto_input_tuning}

