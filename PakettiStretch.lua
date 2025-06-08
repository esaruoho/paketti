-- At the very start of the file
local dialog = nil  -- Proper global dialog reference
local view_switch
local write_to_master = false  -- State for master track writing
local vb=renoise.ViewBuilder()
local step_size = 1
local fill_all = true
local safe_mode = true  -- Add safety lock
local dialog_initializing = true  -- Add initialization flag

-- Declare variables first
local step_slider
local step_stepper

-- Helper Functions (all defined before usage)
local function find_volume_ahdsr_device(instrument)
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

-- Add this helper function to check if all notes in pattern are the same
function get_uniform_note_value(pattern_index)
    local song=renoise.song()
    local pattern = song.patterns[pattern_index]
    local track = pattern:track(song.selected_track_index)
    local first_note = nil
    local all_same = true
    
    -- First find the first actual note
    for i = 1, pattern.number_of_lines do
        local note_val = track:line(i).note_columns[1].note_value
        if note_val ~= 121 then -- If we find a note
            first_note = note_val
            break
        end
    end
    
    -- If no notes found, return nil
    if not first_note then return nil end
    
    -- Check if all other notes match the first one
    for i = 1, pattern.number_of_lines do
        local note_val = track:line(i).note_columns[1].note_value
        if note_val ~= 121 and note_val ~= first_note then -- If we find a different note
            all_same = false
            break
        end
    end
    
    return all_same and first_note or nil
end

local function set_view_frame(vb)
    renoise.app().window.active_middle_frame = 
        vb.views.switchmode and 
        (vb.views.switchmode.value == 1 and 1 or   -- Pattern Editor
         vb.views.switchmode.value == 2 and 5 or   -- Sample Editor
         vb.views.switchmode.value == 3 and 6)     -- Modulation Matrix
        or 1  -- Default to Pattern Editor if switchmode doesn't exist
end

-- Function to check if pattern has content
local function pattern_is_empty(pattern_index)
    local song=renoise.song()
    local pattern = song.patterns[pattern_index]
    local track = pattern:track(song.selected_track_index)
    
    -- Check first line for ANY content
    local first_line = track:line(1)
    if first_line.note_columns[1].note_value ~= 121 or -- 121 is empty note
       first_line.effect_columns[1].number_string == "0S" then
        return false
    end
    
    return true
end

local function fill_pattern_with_steps(pattern_index, instrument_index, use_512, note_value, reverse_s, step_size, fill_all)
    local song=renoise.song()
    local pattern = song.patterns[pattern_index]
    local track = pattern:track(song.selected_track_index)
    local pattern_length = use_512 and 512 or 256
    
    -- Don't clear notes, only clear effect columns
    for i = 1, pattern_length do
        track:line(i).effect_columns[1]:clear()
    end
    
    -- First 256 lines
    for step = 0, math.floor(256/step_size) - 1 do
        local s_value
        if reverse_s then
            s_value = 255 - (step * step_size)
        else
            s_value = step * step_size
        end
        s_value = math.min(255, math.max(0, s_value))
        
        -- Get the note at the start of this step
        local step_start = step * step_size + 1
        local step_note = track:line(step_start).note_columns[1].note_value
        -- If no note at step start (121 is empty), use the provided note_value
        if step_note == 121 then step_note = note_value end
        
        for i = 1, step_size do
            local line_num = step * step_size + i
            if line_num <= 256 then
                -- Only write note if there isn't one already
                if (fill_all or i == 1) and track:line(line_num).note_columns[1].note_value == 121 then
                    local note_column = track:line(line_num).note_columns[1]
                    -- Use the step's note instead of note_value when filling
                    note_column.note_value = step_note
                    note_column.instrument_value = instrument_index
                end
                
                -- Always write the sample offset
                track:line(line_num).effect_columns[1].number_string = "0S"
                track:line(line_num).effect_columns[1].amount_value = s_value
            end
        end
    end
    
    -- If 512 mode, do second 256 lines with same pattern
    if use_512 then
        for step = 0, math.floor(256/step_size) - 1 do
            local s_value
            if reverse_s then
                s_value = 255 - (step * step_size)
            else
                s_value = step * step_size
            end
            s_value = math.min(255, math.max(0, s_value))
            
            -- Get the note at the start of this step
            local step_start = 256 + step * step_size + 1
            local step_note = track:line(step_start).note_columns[1].note_value
            -- If no note at step start (121 is empty), use the provided note_value
            if step_note == 121 then step_note = note_value end
            
            for i = 1, step_size do
                local line_num = 256 + step * step_size + i
                if line_num <= 512 then
                    -- Only write note if there isn't one already
                    if (fill_all or i == 1) and track:line(line_num).note_columns[1].note_value == 121 then
                        local note_column = track:line(line_num).note_columns[1]
                        -- Use the step's note instead of note_value when filling
                        note_column.note_value = step_note
                        note_column.instrument_value = instrument_index
                    end
                    
                    -- Always write the sample offset
                    track:line(line_num).effect_columns[1].number_string = "0S"
                    track:line(line_num).effect_columns[1].amount_value = s_value
                end
            end
        end
    end
end

local function ensure_master_track_effects()
    local song=renoise.song()
    local master_track_index = song.sequencer_track_count + 1
    local master_track = song:track(master_track_index)
    
    if master_track.visible_effect_columns < 2 then
        master_track.visible_effect_columns = 2
    end
end

local function write_tempo_commands(bpm, lpb, from_line)
    if not write_to_master then return end
    
    local song=renoise.song()
    local master_track_index = song.sequencer_track_count + 1
    local pattern = song.patterns[song.selected_pattern_index]
    local master_track = pattern:track(master_track_index)
    local start_line = from_line or 1
    
    -- Convert BPM to hex for ZT
    local zt_value = math.min(255, math.floor(bpm))
    -- Convert LPB to hex for ZL
    local zl_value = math.min(255, math.floor(lpb))
    
    -- Write from current line to end of pattern
    for i = start_line, pattern.number_of_lines do
        master_track:line(i).effect_columns[1].number_string = "ZT"
        master_track:line(i).effect_columns[1].amount_value = zt_value
        master_track:line(i).effect_columns[2].number_string = "ZL"
        master_track:line(i).effect_columns[2].amount_value = zl_value
    end
end

local function check_and_set_uniform_note()
    local song=renoise.song()
    local pattern = song.patterns[current_pattern_index]
    local track = pattern:track(song.selected_track_index)
    local length = pattern.number_of_lines
    
    local first_note = track:line(1).note_columns[1].note_value
    if first_note == 121 then return end -- Skip if first note is OFF
    
    -- Check if all notes are the same
    for i = 2, length do
        local current_note = track:line(i).note_columns[1].note_value
        if current_note ~= first_note and current_note ~= 121 then -- 121 is note OFF
            return -- Notes are different, exit
        end
    end
    
    -- If we get here, all notes are the same (excluding OFFs)
    note_slider.value = first_note
end

local function check_and_set_envelope_status(vb)
    -- First check if vb exists and has views
    if not vb or not vb.views or not vb.views.envelope_checkbox then
        return false
    end

    -- Safely get song object
    local song = nil
    pcall(function() song = renoise.song() end)
    if not song then
        return false
    end

    -- Rest of the function with safe checks
    if not song.selected_instrument then
        return false
    end

    local instrument = song.selected_instrument
    if not instrument.sample_modulation_sets or 
       #instrument.sample_modulation_sets == 0 or 
       not instrument.sample_modulation_sets[1] or 
       not instrument.sample_modulation_sets[1].devices or 
       not instrument.sample_modulation_sets[1].devices[3] then
        return false
    end

    local device = instrument.sample_modulation_sets[1].devices[3]
    if not device or device.name ~= "Volume AHDSR" then
        return false
    end

    if device.enabled then
        vb.views.envelope_checkbox.value = true
        return true
    end

    return false
end

local function update_timing_displays()
    -- Safely get song object
    local song = nil
    pcall(function() song = renoise.song() end)
    if not song then
        return
    end

    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    local lines_per_sec = (bpm * lpb) / 60
    local ms_per_line = 1000 / lines_per_sec
    
    if lines_per_sec_display then
        lines_per_sec_display.text = string.format("%.2f", lines_per_sec)
    end
    if ms_per_line_display then
        ms_per_line_display.text = string.format("%.2f", ms_per_line)
    end
end

local function calculate_timing_values(slider_value)
    -- Convert 0-1000 to 0-1 range
    local normalized = slider_value / 1000
    
    -- Calculate total range of possible speeds
    local min_speed = 20 * 1      -- Slowest: 20 BPM at LPB 1
    local max_speed = 256 * 256   -- Fastest: 256 BPM at LPB 256
    
    -- Calculate target speed using exponential scaling
    local target_speed = min_speed * math.pow(max_speed/min_speed, normalized)
    
    -- Start with LPB 1 and calculate required BPM
    local lpb = 1
    local bpm = target_speed
    
    -- While BPM is too high, double LPB and halve BPM
    while bpm > 256 and lpb < 256 do
        lpb = lpb * 2
        bpm = bpm / 2
    end
    
    -- Ensure we stay within limits
    bpm = math.max(20, math.min(256, bpm))
    lpb = math.max(1, math.min(256, lpb))
    
    -- Snap LPB to powers of 2
    local common_lpbs = {1, 2, 4, 8, 16, 32, 64, 128, 256}
    local snap_threshold = 0.1 -- 10% tolerance
    
    for _, common_lpb in ipairs(common_lpbs) do
        if math.abs(lpb - common_lpb) / lpb < snap_threshold then
            lpb = common_lpb
            break
        end
    end
    
    return math.floor(bpm), lpb
end

-- Helper function to fill pattern with ONLY effects (not touching notes)
local function fill_pattern(pattern_index, instrument_index, use_512, note_value, reverse_s)
    fill_pattern_with_steps(pattern_index, instrument_index, use_512, note_value, reverse_s, step_size, fill_all)
end

-- Add this helper function with other helper functions at the top
local function analyze_pattern_settings(pattern_index)
    local song=renoise.song()
    local pattern = song.patterns[pattern_index]
    local track = pattern:track(song.selected_track_index)
    local pattern_length = pattern.number_of_lines
    
    print("-- Starting pattern analysis...")
    
    -- First find where sample offsets change value
    local offset_changes = {}
    local last_offset_value = -1
    local current_run_start = 1
    
    -- Find all points where sample offset value changes
    for i = 1, pattern_length do
        local fx_col = track:line(i).effect_columns[1]
        if fx_col.number_string == "0S" then
            if fx_col.amount_value ~= last_offset_value then
                if last_offset_value ~= -1 then
                    -- Store the length of this run of same offset value
                    local run_length = i - current_run_start
                    table.insert(offset_changes, {
                        position = current_run_start,
                        length = run_length,
                        value = last_offset_value
                    })
                    print(string.format("-- Sample offset change at line %d, previous value %d ran for %d lines", 
                        i, last_offset_value, run_length))
                end
                last_offset_value = fx_col.amount_value
                current_run_start = i
            end
        end
    end
    
    if #offset_changes == 0 then
        print("-- No sample offset changes found")
        return nil, nil
    end
    
    -- Calculate the most common run length (this will be our step size)
    local length_counts = {}
    local max_count = 0
    local detected_step = offset_changes[1].length
    
    for _, change in ipairs(offset_changes) do
        length_counts[change.length] = (length_counts[change.length] or 0) + 1
        if length_counts[change.length] > max_count then
            max_count = length_counts[change.length]
            detected_step = change.length
        end
    end
    
    print(string.format("-- Detected step size: %d", detected_step))
    
    -- Check if we have notes throughout each step (Fill All)
    -- or only at the start of each step
    local detected_fill = true  -- Assume Fill All until proven otherwise
    
    -- Look at the first few steps to determine Fill All
    for _, change in ipairs(offset_changes) do
        local has_notes_between = false
        -- Check if there are notes between the start and end of this run
        for i = change.position + 1, change.position + change.length - 1 do
            if track:line(i).note_columns[1].note_value ~= 121 then
                has_notes_between = true
                print(string.format("-- Found note between offsets at line %d", i))
                break
            end
        end
        if not has_notes_between then
            detected_fill = false
            print("-- No notes between offset changes, Fill All = false")
            break
        end
    end
    
    print(string.format("-- Analysis complete: Step Size = %d, Fill All = %s", 
        detected_step, tostring(detected_fill)))
        
    return detected_step, detected_fill
end

-- Dialog creation and pattern manipulation for timestretching
function pakettiTimestretchDialog()

    -- First, check if dialog exists and is visible
    if dialog and dialog.visible then
        dialog:close()
        dialog = nil  -- Clear the dialog reference
        return  -- Exit the function
    end

    local song=renoise.song()
    local selected_track = song:track(song.selected_track_index)
    render_context.source_track = song.selected_track_index  -- Store the track index
    local original_seq_pos = song.selected_sequence_index  -- Store original position
    
    -- Check if we're on a proper note track and switch to first track if not
    if selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
        song.selected_track_index = 1  -- Switch to first track which is always a sequencer track
    end
    
    local current_pattern_index = song.sequencer:pattern(song.selected_sequence_index)
    local current_pattern = song.patterns[current_pattern_index]
    
    -- Ensure pattern is at least 256 rows
    if current_pattern.number_of_lines < 256 then
        current_pattern.number_of_lines = 256
    end
    
    local current_pattern_length = current_pattern.number_of_lines
    local vb = renoise.ViewBuilder()
    
    -- Create record_mode checkbox first, before any analysis that might use it
    local record_mode = vb:checkbox{
        value = false,
        width=20
    }
    
    -- 1. Declare ALL variables we'll need upfront
    local note_slider
    local pattern_512_mode
    local reverse_checkbox
    local bpm_slider
    local lpb_slider
    local bpm_display
    local lpb_display
    local note_display
    local instrument_index_display
    local instrument_name_text
    local lines_per_sec_display
    local ms_per_line_display
    local lpb_stepper
    local note_stepper
    local step_slider
    local step_display
    local fill_all_checkbox
    
    -- Check for existing notes and sample offset commands
    local has_notes = false
    local has_offsets = false
    for i = 1, current_pattern.number_of_lines do
        local line = current_pattern:track(song.selected_track_index):line(i)
        if line.note_columns[1].note_value ~= 121 then
            has_notes = true
        end
        if line.effect_columns[1].number_string == "0S" then
            has_offsets = true
        end
    end
    
    print("Pattern analysis - Has notes:", has_notes, "Has offsets:", has_offsets)
    
    -- Initialize pattern if completely empty
    if not has_notes and not has_offsets then
        print("Pattern is completely empty, initializing with C-4 and sample offsets")
        for i = 1, current_pattern.number_of_lines do
            local note_column = current_pattern:track(song.selected_track_index):line(i).note_columns[1]
            note_column.note_value = 48  -- C-4
            note_column.instrument_value = song.selected_instrument_index - 1
            
            -- Always write sample offset
            local s_value = math.floor(((i - 1) % 256) * 255 / 255)
            current_pattern:track(song.selected_track_index):line(i).effect_columns[1].number_string = "0S"
            current_pattern:track(song.selected_track_index):line(i).effect_columns[1].amount_value = s_value
        end
    else
        -- If we have notes but no offsets, add the offsets
        if not has_offsets then
            print("Pattern has notes but no offsets, adding sample offsets")
            for i = 1, current_pattern.number_of_lines do
                local s_value = math.floor(((i - 1) % 256) * 255 / 255)
                current_pattern:track(song.selected_track_index):line(i).effect_columns[1].number_string = "0S"
                current_pattern:track(song.selected_track_index):line(i).effect_columns[1].amount_value = s_value
            end
        end
        
        -- Check for uniform notes and set record mode
        local uniform_note = get_uniform_note_value(current_pattern_index)
        record_mode.value = (uniform_note == nil)
        if uniform_note == nil then
            print("Multiple different notes detected, enabling record mode")
        else
            print("All notes are the same, record mode disabled")
        end
    end
    
    -- Declare these variables before creating the row
    local scale_value_text = vb:text{ -- Create the text elements first
        width=40,
        text="1.00"
    }
    
    local release_time_text = vb:text{ -- Create the text elements first
        width=50,
        text="480ms"
    }
    
    -- 2. Create basic displays
    bpm_display = vb:text{
        width=50,
        text = tostring(song.transport.bpm)
    }
    lpb_display = vb:text{width=30, text = tostring(song.transport.lpb)}
    note_display = vb:text{width=50, text="C-4", style="strong", font="bold"}
    
    -- Add integer step valueboxes next to the displays
    lpb_stepper = vb:valuebox{
        min = -1,
        max = 1,
        value = 0,
        width=30,
        tonumber = function(str) 
            return math.floor(tonumber(str) or 0)
        end,
        tostring = function(value)
            return tostring(value)
        end,
        notifier=function(new_value)
            local current_lpb = song.transport.lpb
            local new_lpb = math.max(1, math.min(256, current_lpb + new_value))
            song.transport.lpb = new_lpb
            lpb_display.text = tostring(new_lpb)
            lpb_slider.value = new_lpb
            update_timing_displays()
            if write_to_master then
                write_tempo_commands(song.transport.bpm, new_lpb,
                    song.transport.playing and song.transport.playback_pos.line or 1)
            end
            lpb_stepper.value = 0  -- Reset the stepper
        end
    }
    
    note_stepper = vb:valuebox{
        min = -1,
        max = 1,
        value = 0,
        width=30,
        tonumber = function(str) 
            return math.floor(tonumber(str) or 0)
        end,
        tostring = function(value)
            return tostring(value)
        end,
        notifier=function(new_value)
            local current_note = note_slider.value
            local new_note = math.max(0, math.min(119, current_note + new_value))
            update_note_value(new_note)
            note_stepper.value = 0  -- Reset the stepper
        end
    }
    
    -- 3. Create instrument controls
    instrument_index_display = vb:valuebox{
        min = 0,
        max = 254,
        value = song.selected_instrument_index - 1,
        width=50,
        tostring = function(value) return string.format("%02X", value) end,
        tonumber = function(str) return tonumber(str, 16) end,
        notifier=function(new_value)
            -- Update all notes in the pattern with the new instrument value
            local pattern = song.patterns[current_pattern_index]
            local track = pattern:track(song.selected_track_index)
            
            for i = 1, pattern.number_of_lines do
                local note_column = track:line(i).note_columns[1]
                if note_column.note_value ~= 121 then -- Only update if there's a note
                    note_column.instrument_value = new_value
                end
            end
            
            -- Update selected instrument in Renoise
            song.selected_instrument_index = new_value + 1
            
            -- Update instrument name display
            instrument_name_text.text = song.instruments[new_value + 1].name
        end
    }
    
    instrument_name_text = vb:text{
        text = song.instruments[song.selected_instrument_index].name,
        width=200,
        style = "strong",
        font = "bold"
    }
    
    -- 5. Pattern fill function
    local function fill_pattern(pattern_index, instrument_index, use_512, note_value, reverse_s)
        local song=renoise.song()
        local pattern = song.patterns[pattern_index]
        local track = pattern:track(song.selected_track_index)
        local length = use_512 and 512 or 256
        
        -- Set pattern length
        pattern.number_of_lines = length
        
        -- Only modify effect columns, preserve notes
        for i = 1, length do
            local s_value
            if reverse_s then
                s_value = math.floor(255 - ((i - 1) % 256) * 255 / 255)  -- SFF to S00
            else
                s_value = math.floor(((i - 1) % 256) * 255 / 255)  -- S00 to SFF
            end
            
            track:line(i).effect_columns[1].number_string = "0S"
            track:line(i).effect_columns[1].amount_value = s_value
        end
    end
    
    -- 6. Create checkboxes
    pattern_512_mode = vb:checkbox{
        value = current_pattern_length == 512,
        width=20,
        notifier=function(new_value)
            print("512 Mode - New value:", new_value)
            local song=renoise.song()
            local pattern = song.patterns[current_pattern_index]
            local current_length = pattern.number_of_lines
            
            -- Only resize if checkbox state actually changed
            if new_value and current_length == 256 then
                -- Going to 512 mode from 256
                pattern.number_of_lines = 512
                -- Copy notes from first half to second half
                local track = pattern:track(song.selected_track_index)
                local note_255 = track:line(255).note_columns[1].note_value
                local inst_255 = track:line(255).note_columns[1].instrument_value
                
                for i = 256, 512 do
                    track:line(i).note_columns[1].note_value = note_255
                    track:line(i).note_columns[1].instrument_value = inst_255
                end
            elseif not new_value and current_length == 512 then
                -- Going back to 256 mode from 512
                pattern.number_of_lines = 256
            end
            
            -- Fill pattern with effects
            fill_pattern_with_steps(current_pattern_index, 
                        instrument_index_display.value, 
                        new_value,
                        note_slider.value,
                        reverse_checkbox.value,
                        step_size,
                        fill_all)
            set_view_frame(vb)
        end
    }
    
    reverse_checkbox = vb:checkbox{
        value = false,
        width=20,
        notifier=function(new_value)
            print("Reverse - New value:", new_value)
            print("Current step_size:", step_size)
            print("Current fill_all:", fill_all)
            
            fill_pattern_with_steps(current_pattern_index, 
                        instrument_index_display.value, 
                        pattern_512_mode.value,
                        note_slider.value,
                        new_value,
                        step_size,
                        fill_all)
            set_view_frame(vb)
        end
    }
    
    -- In the dialog content creation
    view_switch = vb:switch {
        width=300,
        items = {"Pattern Editor", "Sample Editor", "Modulation Matrix"},
        value = 1,
        notifier=function(new_value)
            -- 1 = Pattern Editor
            -- 2 = Sample Editor
            -- 3 = Modulation Matrix
            if new_value == 1 then
                renoise.app().window.active_middle_frame = 1  -- Pattern Editor
            elseif new_value == 2 then
                renoise.app().window.active_middle_frame = 5  -- Sample Editor
            else
                renoise.app().window.active_middle_frame = 6  -- Modulation Matrix
            end
        end
    }
    
    -- 7. Create note slider
    note_slider = vb:slider{
        id = "note_slider",
        min = 0,
        max = 119,
        value = 48,
        width=300,
        steps = {1, 12},  -- Small steps = 1, large steps = 12 (one octave)
        notifier=function(new_value)
            new_value = math.floor(new_value)
            
            -- Always update display if it exists
            if note_display then
                local note = new_value % 12
                local octave = math.floor(new_value / 12)
                local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
                note_display.text = note_names[note + 1] .. tostring(octave)
            end
            
            -- Exit if we're initializing
            if dialog_initializing then
                return
            end
            
            local song=renoise.song()
            local pattern = song.patterns[current_pattern_index]
            local track = pattern:track(song.selected_track_index)
            
            if record_mode.value and song.transport.playing then
                -- Record mode ON: Write from current position downward
                local start_line = song.transport.playback_pos.line
                for i = start_line, pattern.number_of_lines do
                    if fill_all or ((i-1) % step_size == 0) then
                        track:line(i).note_columns[1].note_value = new_value
                        track:line(i).note_columns[1].instrument_value = instrument_index_display.value
                    end
                end
            else
                -- Record mode OFF: Only update if not in record mode
                if not record_mode.value then
                    for i = 1, pattern.number_of_lines do
                        if fill_all or ((i-1) % step_size == 0) then
                            track:line(i).note_columns[1].note_value = new_value
                            track:line(i).note_columns[1].instrument_value = instrument_index_display.value
                        end
                    end
                end
            end
            
            -- Start playback on actual user action
            song.transport.playing = true
            song.transport.loop_pattern = true
            song.transport.follow_player = true
            
            set_view_frame(vb)
        end
    }
    
    -- Function to update timing displays
    local function update_timing_displays()
        local bpm = song.transport.bpm
        local lpb = song.transport.lpb
        local lines_per_sec = (bpm * lpb) / 60
        local ms_per_line = 1000 / lines_per_sec
        
        lines_per_sec_display.text = string.format("%.2f", lines_per_sec)
        ms_per_line_display.text = string.format("%.2f", ms_per_line)
    end
    
    -- Create BPM and LPB sliders (add these before the dialog content creation)
    bpm_slider = vb:slider{
        min = 20,
        max = 256,
        value = math.min(256, song.transport.bpm),
        width=300,
        steps = {1, 10},  -- Small steps = 1, large steps = 10
        notifier=function(new_value)
            new_value = math.floor(new_value)  -- Ensure whole number
            song.transport.bpm = new_value
            bpm_display.text = tostring(new_value)
            update_timing_displays()
            if write_to_master then
                write_tempo_commands(new_value, song.transport.lpb, 
                    song.transport.playing and song.transport.playback_pos.line or 1)
            end
        end
    }
    
    lpb_slider = vb:slider{
        min = 1,
        max = 256,
        value = math.min(256, song.transport.lpb),
        width=300,
        steps = {1, 16},  -- Small steps = 1, large steps = 16
        notifier=function(new_value)
            new_value = math.floor(new_value)  -- Ensure whole number
            song.transport.lpb = new_value
            lpb_display.text = tostring(new_value)
            update_timing_displays()
            if write_to_master then
                write_tempo_commands(song.transport.bpm, new_value,
                    song.transport.playing and song.transport.playback_pos.line or 1)
            end
        end
    }
    
    -- Create BPM buttons array
    local bpm_buttons = {}
    for bpm = 50, 900, 50 do
        table.insert(bpm_buttons, vb:button{
            text = tostring(bpm),
            width=30,
            notifier=function()
                song.transport.bpm = bpm
                bpm_display.text = tostring(bpm)
            end
        })
    end
    
    -- Create step controls
    step_display = vb:text{width=40, text="1" }

step_slider = vb:slider{
    min = 1,
    max = 64,  -- Direct range from 1 to 64
    value = 1,
    width=200,
    steps = {1, -1},  -- Small steps = 1, large steps = 1
    notifier=function(new_value)
        -- Force to nearest integer and clamp to valid range
        new_value = math.max(1, math.min(64, math.floor(new_value)))
        print("Changing step size to:", new_value)
        
        local song=renoise.song()
        local pattern = song.patterns[current_pattern_index]
        local track = pattern:track(song.selected_track_index)
        local pattern_length = pattern.number_of_lines
        
        -- First collect all notes at their positions
        local original_notes = {}
        local last_valid_note = nil
        local last_valid_instrument = nil
        
        for i = 1, pattern_length do
            local note_val = track:line(i).note_columns[1].note_value
            if note_val ~= 121 then  -- If there's a note
                last_valid_note = note_val
                last_valid_instrument = track:line(i).note_columns[1].instrument_value
                original_notes[i] = {
                    note = note_val,
                    instrument = track:line(i).note_columns[1].instrument_value
                }
            end
        end
        
        -- Clear everything
        for i = 1, pattern_length do
            track:line(i).note_columns[1]:clear()
            track:line(i).effect_columns[1]:clear()
        end
        
        step_size = new_value
        step_display.text = tostring(step_size)
        
        -- Write new pattern with new step size
        last_valid_note = nil
        last_valid_instrument = nil
        
        for step = 0, math.floor((pattern_length - 1) / step_size) do
            local step_start = step * step_size + 1
            local note_found = nil
            local instrument_found = nil
            
            -- First try to find a note in the original pattern for this step region
            for i = step_start, math.min(step_start + step_size - 1, pattern_length) do
                if original_notes[i] then
                    note_found = original_notes[i].note
                    instrument_found = original_notes[i].instrument
                    last_valid_note = note_found
                    last_valid_instrument = instrument_found
                    break
                end
            end
            
            -- If no note found for this step, use the last valid note
            if not note_found and last_valid_note then
                note_found = last_valid_note
                instrument_found = last_valid_instrument
            end
            
            if note_found then
                -- Write note at step start
                if fill_all then
                    -- Fill all positions in this step
                    for i = 0, step_size - 1 do
                        local pos = step_start + i
                        if pos <= pattern_length then
                            local note_column = track:line(pos).note_columns[1]
                            note_column.note_value = note_found
                            note_column.instrument_value = instrument_found
                        end
                    end
                else
                    -- Just write the first note
                    local note_column = track:line(step_start).note_columns[1]
                    note_column.note_value = note_found
                    note_column.instrument_value = instrument_found
                end
            end
            
            -- Write effect columns for this step
            local s_value
            if reverse_checkbox.value then
                s_value = 255 - (step * step_size)
            else
                s_value = step * step_size
            end
            s_value = math.min(255, math.max(0, s_value))
            
            for i = 0, step_size - 1 do
                local pos = step_start + i
                if pos <= pattern_length then
                    track:line(pos).effect_columns[1].number_string = "0S"
                    track:line(pos).effect_columns[1].amount_value = s_value
                end
            end
        end
            
        print("Step size change complete")
    end
}

    -- Create the stepper
    step_stepper = vb:valuebox{
        min = 1,
        max = 64,
        value = 1,
        width=30,
        tonumber = function(str)
            return math.floor(tonumber(str) or 1)
        end,
        tostring = function(value)
            return tostring(value)
        end,
        notifier=function(new_value)
            step_slider.value = new_value
        end
    }

    fill_all_checkbox = vb:checkbox{
        value = true,
        width=20,
        notifier=function(new_value)
            fill_all = new_value
            print("Fill All changed to:", new_value)
            
            local song=renoise.song()
            local pattern = song.patterns[current_pattern_index]
            local track = pattern:track(song.selected_track_index)
            
            -- Store existing notes at step positions
            local step_notes = {}
            for i = 1, pattern.number_of_lines do
                if (i - 1) % step_size == 0 then
                    local note_val = track:line(i).note_columns[1].note_value
                    local instr_val = track:line(i).note_columns[1].instrument_value
                    if note_val ~= 121 then  -- If there's a note
                        step_notes[i] = {note = note_val, instrument = instr_val}
                    end
                end
            end
            
            -- If fill_all is turned off, clear notes between steps
            if not new_value then
                for i = 1, pattern.number_of_lines do
                    if (i - 1) % step_size ~= 0 then  -- If not at step start
                        track:line(i).note_columns[1]:clear()
                    end
                end
            else
                -- Fill all positions with the note from their step
                for i = 1, pattern.number_of_lines do
                    local step_start = i - ((i - 1) % step_size)
                    if step_notes[step_start] then
                        local note_column = track:line(i).note_columns[1]
                        note_column.note_value = step_notes[step_start].note
                        note_column.instrument_value = step_notes[step_start].instrument
                    end
                end
            end
            
            -- Always maintain sample offsets
            for step = 0, math.floor((pattern.number_of_lines - 1) / step_size) do
                local s_value
                if reverse_checkbox.value then
                    s_value = 255 - (step * step_size)
                else
                    s_value = step * step_size
                end
                s_value = math.min(255, math.max(0, s_value))
                
                -- Write the same offset value for all lines in this step
                for i = 1, step_size do
                    local line_num = step * step_size + i
                    if line_num <= pattern.number_of_lines then
                        track:line(line_num).effect_columns[1].number_string = "0S"
                        track:line(line_num).effect_columns[1].amount_value = s_value
                    end
                end
            end
        end
    }
    
    -- Create timing displays after other displays
    lines_per_sec_display = vb:text{
        width=50,
        text="0.00",
        style = "strong",
        font = "bold"
    }
    
    ms_per_line_display = vb:text{
        width=50,
        text="0.00",
        style = "strong",
        font = "bold"
    }
    
    -- Add function to update timing displays
    local function update_timing_displays()
        local bpm = song.transport.bpm
        local lpb = song.transport.lpb
        local lines_per_sec = (bpm * lpb) / 60
        local ms_per_line = 1000 / lines_per_sec
        
        lines_per_sec_display.text = string.format("%.2f", lines_per_sec)
        ms_per_line_display.text = string.format("%.2f", ms_per_line)
    end
    
    -- Store the switch as a variable so we can access it throughout the dialog
    local view_switch
    
    -- Define the update_note_value function BEFORE creating the dialog content
    local function update_note_value(new_value)
        -- Clamp the note value between 0 and 119 (C-0 to B-9)
        new_value = math.max(0, math.min(119, new_value))
        
        local song=renoise.song()
        local pattern = song.patterns[current_pattern_index]
        local track = pattern:track(song.selected_track_index)
        
        if record_mode.value and song.transport.playing then
            -- Record mode ON: Write from current position downward
            local start_line = song.transport.playback_pos.line
            for i = start_line, pattern.number_of_lines do
                if fill_all or ((i-1) % step_size == 0) then
                    track:line(i).note_columns[1].note_value = new_value
                    track:line(i).note_columns[1].instrument_value = instrument_index_display.value
                end
            end
        else
            -- Record mode OFF: Write to ALL rows or step rows
            for i = 1, pattern.number_of_lines do
                if fill_all or ((i-1) % step_size == 0) then
                    track:line(i).note_columns[1].note_value = new_value
                    track:line(i).note_columns[1].instrument_value = instrument_index_display.value
                end
            end
        end
        note_slider.value = new_value
        set_view_frame(vb)
    end
    
    -- At the start of dialog creation, before creating other UI elements
    local master_write_checkbox = vb:checkbox{
        value = write_to_master,
        width=20,
        notifier=function(new_value)
            write_to_master = new_value
            if new_value then
                ensure_master_track_effects()
                -- Write current values immediately
                write_tempo_commands(song.transport.bpm, song.transport.lpb,
                    song.transport.playing and song.transport.playback_pos.line or 1)
            end
        end
    }
    
    -- Create dialog content
    local dialog_content = vb:column{
        -- Instrument row
        vb:row{
            instrument_index_display,
            instrument_name_text
        },
        
        -- Pattern type and checkboxes row
        vb:row{
            pattern_512_mode,
            vb:text{text="512 rows mode", font = "bold" },
            vb:space { width=20 },
            record_mode,
            vb:text{text="Record notes below cursor", font = "bold" },
            vb:space { width=20 },
            reverse_checkbox,
            vb:text{text="Reversed", font = "bold" }
        },
        
        -- BPM row
        vb:row{
            vb:text{text="BPM",width=85, style = "strong", font = "bold" },
            bpm_slider,
            bpm_display
        },
        
        -- BPM buttons row
        vb:row{
            spacing=2,
            unpack(bpm_buttons)
        },
        
        -- LPB row with preset buttons
        vb:row{
            vb:text{text="LPB",width=85, style = "strong", font = "bold" },
            lpb_slider,
            lpb_display,
            vb:space { width=10 },
            vb:button{ text="2",width=30, notifier=function() song.transport.lpb = 2 lpb_display.text="2" lpb_slider.value = 2 end},
            vb:button{ text="4",width=30, notifier=function() song.transport.lpb = 4 lpb_display.text="4" lpb_slider.value = 4 end},
            vb:button{ text="8",width=30, notifier=function() song.transport.lpb = 8 lpb_display.text="8" lpb_slider.value = 8 end},
            vb:button{ text="16",width=30, notifier=function() song.transport.lpb = 16 lpb_display.text="16" lpb_slider.value = 16 end},
            vb:button{ text="32",width=30, notifier=function() song.transport.lpb = 32 lpb_display.text="32" lpb_slider.value = 32 end},
            vb:button{ text="64",width=30, notifier=function() song.transport.lpb = 64 lpb_display.text="64" lpb_slider.value = 64 end},
            vb:button{ text="128",width=30, notifier=function() song.transport.lpb = 128 lpb_display.text="128" lpb_slider.value = 128 end}
        },
        
        -- ComboTempo row
        vb:row{
            vb:text{text="ComboTempo",width=85, style = "strong", font = "bold" },
            vb:slider{
                min = 0,
                max = 1000,
                value = 500,
                width=555,
                notifier=function(new_value)
                    -- Calculate BPM and LPB values
                    local bpm, lpb = calculate_timing_values(new_value)
                    
                    -- Update transport values (these will be clamped automatically)
                    song.transport.lpb = lpb
                    song.transport.bpm = bpm
                    
                    -- Update slider values (ensure within valid ranges)
                    lpb_slider.value = math.min(256, math.max(1, lpb))
                    bpm_slider.value = math.min(256, math.max(20, bpm))
                    
                    -- Update displays
                    lpb_display.text = tostring(lpb)
                    bpm_display.text = tostring(bpm)
                    update_timing_displays()
                    
                    -- Ensure playback
                    song.transport.playing = true
                    song.transport.loop_pattern = true
                    song.transport.follow_player = true
                    
                    -- Write to master if enabled
                    if write_to_master then
                        write_tempo_commands(bpm, lpb,
                            song.transport.playing and song.transport.playback_pos.line or 1)
                    end
                    
                    set_view_frame(vb)
                end
            }
        },
        
        -- Lines/sec and ms/line row
        vb:row{
            vb:text{text="Lines/sec:", style = "strong", font = "bold" },
            lines_per_sec_display,
            vb:text{text="ms/line:", style = "strong", font = "bold" },
            ms_per_line_display
        },
        
        -- Note row
        vb:row{
            vb:text{text="Note",width=85, style = "strong", font = "bold" },
            note_slider,
            note_display,
            vb:button{
                text="-24",
                width=40,
                notifier=function()
                    update_note_value(note_slider.value - 24)
                end
            },
            vb:button{
                text="-12",
                width=40,
                notifier=function()
                    update_note_value(note_slider.value - 12)
                end
            },
            vb:button{
                text="C-4",
                width=40,
                notifier=function()
                    update_note_value(48)  -- C-4 is note value 48
                end
            },
            vb:button{
                text="+12",
                width=40,
                notifier=function()
                    update_note_value(note_slider.value + 12)
                end
            },
            vb:button{
                text="+24",
                width=40,
                notifier=function()
                    update_note_value(note_slider.value + 24)
                end
            }
        },
        
        -- Render buttons row
        vb:row{
            vb:button{
                text="Render",
                width=100,
                notifier=function()
                    local current_bpm = song.transport.bpm
                    render_context.current_bpm = current_bpm
                    StrRender()
                    song.selected_sequence_index = original_seq_pos
                    set_view_frame(vb)
                end
            }
        },
        
        vb:row{
            vb:text{text="Force View:",width=85, style = "strong", font = "bold" },
            vb:switch {
                id = "switchmode",  -- Give it a proper ID
                width=354,
                items = {"Pattern Editor", "Sample Editor", "Modulation Matrix"},
                value = 1,
                notifier=function(new_value)
                    -- 1 = Pattern Editor
                    -- 2 = Sample Editor
                    -- 3 = Modulation Matrix
                    if new_value == 1 then
                        renoise.app().window.active_middle_frame = 1  -- Pattern Editor
                    elseif new_value == 2 then
                        renoise.app().window.active_middle_frame = 5  -- Sample Editor
                    else
                        renoise.app().window.active_middle_frame = 6  -- Modulation Matrix
                    end
                end
            }
        },
        
        vb:row{
            vb:checkbox{
                id = "envelope_checkbox",
                value = false,
                width=20,
                notifier=function(new_value)
                    local instrument = renoise.song().selected_instrument
                    
                    -- Find Volume AHDSR device
                    local device = find_volume_ahdsr_device(instrument)
                    if not device then
                        renoise.app():show_status("Please Pakettify the Instrument to enable envelopes") 
                        vb.views.envelope_checkbox.value = false
                        return
                    end
                    
                    if new_value then
                        renoise.song().selected_sample.new_note_action = 2
                        device.operator = 3
                        device.enabled = true
                        device.parameters[8].value = 1
                        device.parameters[3].value = 0
                        device.parameters[4].value = 1
                        
                        -- Convert initial Release slider value (480ms) to 0-1 range
                        local initial_ms = 480
                        local renoise_value = initial_ms / 20000
                        renoise_value = math.max(0, math.min(1, renoise_value))
                        
                        device.parameters[5].value = renoise_value

                        -- Check if loop mode is OFF and set it to ON
                        if renoise.song().selected_sample.loop_mode == 1 then
                            renoise.song().selected_sample.loop_mode = 2
                        end
                        
                        renoise.app():show_status("Activated Volume AHDSR, Envelopes now enabled")
                    else
                        renoise.song().selected_sample.new_note_action = 1
                        if renoise.song().selected_sample.loop_mode == 2 then
                            renoise.song().selected_sample.loop_mode = 1
                        end
                        device.operator = 1
                        device.enabled = false
                        
                        renoise.app():show_status("Deactivated Volume AHDSR, Envelopes now disabled")
                    end
                end
            },
            vb:text{text="Enable Envelopes", font = "bold" },
            vb:space { width=10 },
            
            -- Release Value scaling slider (0.00-1.00)
            vb:text{text="Scale:", font = "bold" },
            vb:slider{
                min = 0,
                max = 100,
                value = 100,
                width=100,
                notifier=function(new_value)
                    local instrument = renoise.song().selected_instrument
                    
                    -- Find Volume AHDSR device
                    local device = find_volume_ahdsr_device(instrument)
                    if not device then
                        renoise.app():show_status("Please Pakettify the Instrument to use Scale") 
                        return
                    end
                    
                    local scaled_value = new_value / 100
                    device.parameters[8].value = scaled_value
                    scale_value_text.text = string.format("%.2f", scaled_value)
                end
            },
            scale_value_text,
            
            vb:space { width=10 },
            
            -- Release Time slider
            vb:text{text="Release:", font = "bold" },
            vb:slider{
                min = 0,
                max = 100,
                value = 20,
                width=300,
                notifier=function(new_value)
                    local instrument = renoise.song().selected_instrument
                    
                    -- Find Volume AHDSR device
                    local device = find_volume_ahdsr_device(instrument)
                    if not device then
                        renoise.app():show_status("Please Pakettify the Instrument to use Release") 
                        return
                    end
                    
                    -- Enable envelope checkbox if not already enabled
                    vb.views.envelope_checkbox.value = true
                    
                    -- Enable envelope if not already enabled
                    if not device.enabled then
                        renoise.song().selected_sample.new_note_action = 2
                        if renoise.song().selected_sample.loop_mode == 1 then
                            renoise.song().selected_sample.loop_mode = 2
                        end
                        device.operator = 3
                        device.enabled = true
                        device.parameters[3].value = 0
                        device.parameters[4].value = 1
                        device.parameters[8].value = 1
                    end

                    -- Convert 0-100 to 0-1
                    local renoise_value = new_value / 100
                    
                    -- Set the device parameter
                    device.parameters[5].value = renoise_value
                    
                    -- Use device's own string formatting for display
                    release_time_text.text = device.parameters[5].value_string
                end
            },
            release_time_text,
            vb:space { width=10 },
            vb:button{
                text="Pakettify",
                width=60,
                notifier=function()
                    -- Store current view before pakettifying
                    local current_view = vb.views.switchmode.value
                    
                    PakettiInjectDefaultXRNI()
                    
                    -- Update the instrument index display
                    instrument_index_display.value = renoise.song().selected_instrument_index - 1
                    -- Update the instrument name display
                    instrument_name_text.text = renoise.song().instruments[renoise.song().selected_instrument_index].name
                    
                    -- Restore the view based on switchmode value
                    if current_view == 1 then
                        renoise.app().window.active_middle_frame = 1  -- Pattern Editor
                    elseif current_view == 2 then
                        renoise.app().window.active_middle_frame = 5  -- Sample Editor
                    else
                        renoise.app().window.active_middle_frame = 6  -- Modulation Matrix
                    end
                end
            }
        },
        
        vb:row{
            master_write_checkbox,
            vb:text{text="Write to Master Track", font = "bold" }
        },
        
        vb:row{
            vb:text{text="Step Size:",width=85, style = "strong", font = "bold" },
            step_slider,
            step_display,
            vb:text{text="Fill All", font = "bold" },
            fill_all_checkbox
        }
    }
    
    -- Initial update of timing displays
    update_timing_displays()
    
    -- At the end of pakettiTimestretchDialog(), before showing the dialog
    -- First analyze the pattern
    local detected_step, detected_fill = analyze_pattern_settings(current_pattern_index)
    local pattern = song.patterns[current_pattern_index]
    local track = pattern:track(song.selected_track_index)
    
    -- Check for existing notes and sample offset commands
    local has_notes = false
    local has_offsets = false
    for i = 1, pattern.number_of_lines do
        local line = track:line(i)
        if line.note_columns[1].note_value ~= 121 then
            has_notes = true
        end
        if line.effect_columns[1].number_string == "0S" then
            has_offsets = true
        end
    end
    
    print("Pattern analysis - Has notes: " .. (has_notes and "yes" or "no") .. ", Has offsets: " .. (has_offsets and "yes" or "no"))
    
    -- Initialize pattern if completely empty
    if not has_notes and not has_offsets then
        print("Pattern is completely empty, initializing with C-4 and sample offsets")
        for i = 1, pattern.number_of_lines do
            local note_column = track:line(i).note_columns[1]
            note_column.note_value = 48  -- C-4
            note_column.instrument_value = instrument_index_display.value
            
            -- Always write sample offset
            local s_value = math.floor(((i - 1) % 256) * 255 / 255)
            track:line(i).effect_columns[1].number_string = "0S"
            track:line(i).effect_columns[1].amount_value = s_value
        end
    else
        -- If we have notes but no offsets, add the offsets
        if not has_offsets then
            print("Pattern has notes but no offsets, adding sample offsets")
            for i = 1, pattern.number_of_lines do
                local s_value = math.floor(((i - 1) % 256) * 255 / 255)
                track:line(i).effect_columns[1].number_string = "0S"
                track:line(i).effect_columns[1].amount_value = s_value
            end
        end
        
        -- Check for uniform notes and set record mode
        local uniform_note = get_uniform_note_value(current_pattern_index)
        record_mode.value = (uniform_note == nil)
        if uniform_note == nil then
            print("Multiple different notes detected, enabling record mode")
        else
            print("All notes are the same, record mode disabled")
        end
    end
    
    -- Set initial controls based on analysis
    if detected_step then
        step_size = detected_step
        fill_all = detected_fill
        
        -- Update UI controls
        step_slider.value = detected_step
        step_display.text = tostring(detected_step)
        fill_all_checkbox.value = detected_fill
        
        print("Setting detected values: Step Size = " .. detected_step .. ", Fill All = " .. (detected_fill and "yes" or "no"))
    end
    
    -- Turn off initialization flag BEFORE showing dialog
    dialog_initializing = false

    -- Show dialog and store reference
    dialog = renoise.app():show_custom_dialog("Paketti Timestretch Dialog", dialog_content, my_keyhandler_func)
end

renoise.tool():add_keybinding{name="Global:Paketti:Timestretch Dialog...",invoke=pakettiTimestretchDialog}
render_context = {
    source_track = 0,
    target_track = 0,
    target_instrument = 0,
    temp_file_path = "",
    num_tracks_before = 0,
    current_bpm = 0,
    on_render_complete = nil
}

-- Variable to store the original solo and mute states
local track_states = {}

-- Function to initiate rendering
function Strstart_rendering()
    local song=renoise.song()
    local render_priority = "high"
    local selected_track = song.selected_track

    -- Add DC Offset if enabled in preferences
    if preferences.RenderDCOffset.value then
        local has_dc_offset = false
        for _, device in ipairs(selected_track.devices) do
            if device.display_name == "Render DC Offset" then
                has_dc_offset = true
                break
            end
        end
        
        if not has_dc_offset then
            loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
            local dc_offset_device = selected_track.devices[#selected_track.devices]
            if dc_offset_device.display_name == "Render DC Offset" then
                dc_offset_device.parameters[2].value = 1
            end
        end
    end    
    local song=renoise.song()
    print("AT Strstart_rendering BEFORE SET - Transport BPM:", song.transport.bpm)
    print("AT Strstart_rendering BEFORE SET - Context BPM:", render_context.current_bpm)
    
    local render_priority = "high"
    local selected_track = song.selected_track

    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
            break
        end
    end

    -- Explicitly set the BPM to the captured value before rendering
    song.transport.bpm = render_context.current_bpm
    print("AT Strstart_rendering AFTER SET - Transport BPM:", song.transport.bpm)

    -- Set up rendering options
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(song.selected_sequence_index, 1),
        end_pos = renoise.SongPos(song.selected_sequence_index, song.patterns[song.selected_pattern_index].number_of_lines),
    }

    -- Save current solo and mute states of all tracks
    track_states = {}
    render_context.num_tracks_before = #song.tracks  -- Save the number of tracks before rendering
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
    end

    -- Solo the selected track and unsolo others
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    song.tracks[song.selected_track_index].solo_state = true

    -- Set render context
    render_context.source_track = song.selected_track_index
    render_context.target_track = render_context.source_track + 1
    render_context.target_instrument = song.selected_instrument_index + 1
    render_context.temp_file_path = os.tmpname() .. ".wav"

    -- Start rendering
    local success, error_message = song:render(render_options, render_context.temp_file_path, Strrendering_done_callback)
    if not success then
        print("Rendering failed: " .. error_message)
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(Strmonitor_rendering, 500)
    end
end

-- Callback function that gets called when rendering is complete
function Strrendering_done_callback()
    local song=renoise.song()
    local renderTrack = render_context.source_track

    -- Remove DC Offset if it was added (FIRST, before other operations)
    if preferences.RenderDCOffset.value then
        local original_track = song:track(renderTrack)
        local last_device = original_track.devices[#original_track.devices]
        if last_device.display_name == "Render DC Offset" then
            original_track:delete_device_at(#original_track.devices)
        end
    end

    local song=renoise.song()
    
    -- Remove any reference to target_track = source_track + 1
    render_context.target_track = render_context.source_track  -- Stay on same track
    
    -- Get the captured BPM
    local bpm = render_context.current_bpm
    
    -- Get the current note from the pattern
    local pattern = song.patterns[song.selected_pattern_index]
    local track = pattern:track(song.selected_track_index)
    local note_val = track:line(1).note_columns[1].note_value
    local note = note_val % 12
    local octave = math.floor(note_val / 12)
    local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
    
    -- Format: "BPM note"
    local renderName = string.format("%dBPM %dLPB %s%d", bpm, song.transport.lpb, note_names[note + 1], octave)

    -- Restore the original solo and mute states
    for i = 1, render_context.num_tracks_before do
        if track_states[i] then
            song.tracks[i].solo_state = track_states[i].solo_state
            song.tracks[i].mute_state = track_states[i].mute_state
        end
    end

    -- Load default instrument
    pakettiPreferencesDefaultInstrumentLoader()

    -- Add *Instr. Macros to Rendered Track
    local new_instrument = song:instrument(song.selected_instrument_index)

    -- Load Sample into New Instrument Sample Buffer
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)

    -- Only rename the instrument and its sample, not the track
    new_instrument.samples[1].name = renderName
    new_instrument.name = renderName
    new_instrument.samples[1].autofade = true
if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
    -- Add *Instr. Macros to selected Track
    loadnative("Audio/Effects/Native/*Instr. Macros")
    song.selected_track.devices[2].is_maximized = false
end
    if song.transport.edit_mode then
        song.transport.edit_mode = false
        song.transport.edit_mode = true
    else
        song.transport.edit_mode = true
        song.transport.edit_mode = false
    end
    renoise.song().selected_track.mute_state = 1
    for i=1,#song.tracks do
        renoise.song().tracks[i].mute_state=1
    end 


end

-- Function to monitor rendering progress
function Strmonitor_rendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Rendering in progress: " .. (progress * 100) .. "% complete")
    else
        -- Remove the monitoring timer once rendering is complete or if it wasn't started
        renoise.tool():remove_timer(Strmonitor_rendering)
        print("Rendering not in progress or already completed.")
    end
end

-- Function to handle rendering for a group track
function Strrender_group_track()
    local song=renoise.song()
    local group_track_index = song.selected_track_index
    local group_track = song:track(group_track_index)

    -- Get the member track indices
    local child_track_indices = group_track.members

    -- Save current solo and mute states
    track_states = {}
    render_context.num_tracks_before = #song.tracks  -- Save the number of tracks before rendering
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
    end

    -- Unsolo all tracks
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end

    -- Solo each track in the group
    for _, idx in ipairs(child_track_indices) do
        song.tracks[idx].solo_state = true
    end

    -- Start rendering
    Strstart_rendering()
end

function StrRender()
    local song=renoise.song()
    local renderTrack = render_context.source_track  -- This is set when we start working with the track
    local renderedInstrument = song.selected_instrument_index + 1
    
    print("AT StrRender - Transport BPM:", song.transport.bpm)
    print("AT StrRender - Context BPM:", render_context.current_bpm)

    -- Select the correct track before rendering
    song.selected_track_index = renderTrack

    -- Create New Instrument
    song:insert_instrument_at(renderedInstrument)
    song.selected_instrument_index = renderedInstrument

    -- Check if the selected track is a group track
    if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
        Strrender_group_track()
    else
        Strstart_rendering()
    end
end

-- Improved time resolution calculation
local function calculate_timing_values(slider_value)
    -- Convert 0-1000 to 0-1 range
    local normalized = slider_value / 1000
    
    -- Use exponential scaling for more natural progression
    local min_timing = math.log(20 * 1)     -- Slowest: 20 BPM, LPB 1
    local max_timing = math.log(256 * 256)  -- Fastest: 256 BPM, LPB 256
    local target = math.exp(min_timing + (max_timing - min_timing) * normalized)
    
    -- Find optimal LPB/BPM combination
    local lpb = 1
    local bpm = target
    
    -- Prefer changing LPB over BPM values
    while bpm > 256 and lpb < 256 do
        lpb = lpb * 2
        bpm = bpm / 2
    end
    
    -- Snap to common musical values when close
    local common_lpbs = {1, 2, 4, 8, 16, 32, 64, 128, 256}
    local snap_threshold = 0.1 -- 10% tolerance
    
    for _, common_lpb in ipairs(common_lpbs) do
        if math.abs(lpb - common_lpb) / lpb < snap_threshold then
            lpb = common_lpb
            break
        end
    end
    
    return math.floor(bpm), lpb
end

-- Add a function to check if rendering is in progress
local function is_rendering()
    return renoise.song().rendering
end

-- Add a function to wait until rendering is complete
local function wait_for_render_complete(callback)
    if is_rendering() then
        renoise.tool():add_timer(function()
            wait_for_render_complete(callback)
        end, 0.1)
    else
        callback()
    end
end

-- At the top of the file, add this helper function for cleaner code
local function get_view_frame()
    local mode = (vb.views.switchmode and vb.views.switchmode.value or 1)
    if mode == 1 then
        return 1  -- Pattern Editor
    elseif mode == 2 then
        return 5  -- Sample Editor
    else
        return 6  -- Modulation Matrix
    end
end

-- Function to ensure master track has enough effect columns
local function ensure_master_track_effects()
    local song=renoise.song()
    local master_track_index = song.sequencer_track_count + 1
    local master_track = song:track(master_track_index)
    
    if master_track.visible_effect_columns < 2 then
        master_track.visible_effect_columns = 2
    end
end

-- Function to write tempo commands to master track
local function write_tempo_commands(bpm, lpb, from_line)
    if not write_to_master then return end
    
    local song=renoise.song()
    local master_track_index = song.sequencer_track_count + 1
    local pattern = song.patterns[song.selected_pattern_index]
    local master_track = pattern:track(master_track_index)
    local start_line = from_line or 1
    
    -- Convert BPM to hex for ZT
    local zt_value = math.min(255, math.floor(bpm))
    -- Convert LPB to hex for ZL
    local zl_value = math.min(255, math.floor(lpb))
    
    -- Write from current line to end of pattern
    for i = start_line, pattern.number_of_lines do
        master_track:line(i).effect_columns[1].number_string = "ZT"
        master_track:line(i).effect_columns[1].amount_value = zt_value
        master_track:line(i).effect_columns[2].number_string = "ZL"
        master_track:line(i).effect_columns[2].amount_value = zl_value
    end
end

-- Add this helper function at the top of the file with other helper functions
local function find_volume_ahdsr_device(instrument)
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

-- Add checkbox for master track writing
local master_write_checkbox = vb:checkbox{
    value = write_to_master,
    width=20,
    notifier=function(new_value)
        write_to_master = new_value
        if new_value then
            ensure_master_track_effects()
            -- Write current values immediately
            write_tempo_commands(song.transport.bpm, song.transport.lpb,
                song.transport.playing and song.transport.playback_pos.line or 1)
        end
    end
}

-- Add this function to check and set envelope status
local function check_and_set_envelope_status(vb)
    -- First check if vb exists and has views
    if not vb or not vb.views or not vb.views.envelope_checkbox then
        return false
    end

    -- Safely get song object
    local song = nil
    pcall(function() song = renoise.song() end)
    if not song then
        return false
    end

    -- Rest of the function with safe checks
    if not song.selected_instrument then
        return false
    end

    local instrument = song.selected_instrument
    if not instrument.sample_modulation_sets or 
       #instrument.sample_modulation_sets == 0 or 
       not instrument.sample_modulation_sets[1] or 
       not instrument.sample_modulation_sets[1].devices or 
       not instrument.sample_modulation_sets[1].devices[3] then
        return false
    end

    local device = instrument.sample_modulation_sets[1].devices[3]
    if not device or device.name ~= "Volume AHDSR" then
        return false
    end

    if device.enabled then
        vb.views.envelope_checkbox.value = true
        return true
    end

    return false
end

-- Modify the envelope checkbox creation
vb:checkbox{
    id = "envelope_checkbox",
    value = false,
    width=20,
    notifier=function(new_value)
        local instrument = renoise.song().selected_instrument
        
        -- Find Volume AHDSR device
        local device = find_volume_ahdsr_device(instrument)
        if not device then
            renoise.app():show_status("Please Pakettify the Instrument to enable envelopes") 
            vb.views.envelope_checkbox.value = false
            return
        end
        
        if new_value then
            renoise.song().selected_sample.new_note_action = 2
            device.operator = 3
            device.enabled = true
            device.parameters[8].value = 1
            device.parameters[3].value = 0
            device.parameters[4].value = 1
            
            -- Convert initial Release slider value (480ms) to 0-1 range
            local initial_ms = 480
            local renoise_value = initial_ms / 20000
            renoise_value = math.max(0, math.min(1, renoise_value))
            
            device.parameters[5].value = renoise_value

            -- Check if loop mode is OFF and set it to ON
            if renoise.song().selected_sample.loop_mode == 1 then
                renoise.song().selected_sample.loop_mode = 2
            end
            
            renoise.app():show_status("Activated Volume AHDSR, Envelopes now enabled")
        else
            renoise.song().selected_sample.new_note_action = 1
            if renoise.song().selected_sample.loop_mode == 2 then
                renoise.song().selected_sample.loop_mode = 1
            end
            device.operator = 1
            device.enabled = false
            
            renoise.app():show_status("Deactivated Volume AHDSR, Envelopes now disabled")
        end
    end
}

-- In dialog creation, after creating the checkbox
check_and_set_envelope_status(vb)

