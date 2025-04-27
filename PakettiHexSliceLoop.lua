-- Helper functions
function focus_sample_editor()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

function validate_sample()
    local song = renoise.song()
    local sample = song.selected_sample
    if not sample or not sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample buffer empty")
        return false
    end
    return song, sample
end

function set_sample_selection_by_hex_offset(hex_value)
    local song = renoise.song()
    local instrument = song.selected_instrument
    if not instrument then
        renoise.app():show_status("No instrument selected")
        return
    end

    -- Convert hex string to number (if string) and ensure it's in 0-FF range
    local value = tonumber(hex_value, 16)
    if not value then
        renoise.app():show_status("Invalid hex value")
        return
    end
    value = math.min(0xFF, math.max(0x00, value))

    -- Check if first sample has slice markers
    local has_slice_markers = instrument.samples[1] and 
                            instrument.samples[1].slice_markers and 
                            #instrument.samples[1].slice_markers > 0

    -- Process all samples in the instrument
    for i = 1, #instrument.samples do
        -- Skip first sample if there are slice markers
        if has_slice_markers and i == 1 then
            -- do nothing for the first sample
        else
            local sample = instrument.samples[i]
            if sample and sample.sample_buffer.has_sample_data then
                local buffer = sample.sample_buffer
                local total_frames = buffer.number_of_frames
                
                -- Calculate percentage (value/255) and apply to total frames
                local target_frame = math.floor((value / 255) * total_frames)
                
                -- Ensure minimum of 1 frame
                target_frame = math.max(1, target_frame)
                
                -- Set selection range and loop points
                buffer.selection_start = 1
                buffer.selection_end = target_frame
                sample.loop_start = 1
                sample.loop_end = target_frame
                sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
            end
        end
    end
    
    -- Show info using the selected sample for display
    local selected_sample = song.selected_sample
    if selected_sample and selected_sample.sample_buffer.has_sample_data then
        local buffer = selected_sample.sample_buffer
        local target_frame = math.floor((value / 255) * buffer.number_of_frames)
        local channels_str = buffer.number_of_channels > 1 and "stereo" or "mono"
        local status_msg = string.format(
            "Set %s selection and loop: 1 to %d (%.1f%% at offset S%02X)%s", 
            channels_str,
            target_frame,
            (target_frame / buffer.number_of_frames) * 100,
            value,
            has_slice_markers and " (Skipped sliced sample)" or ""
        )
        renoise.app():show_status(status_msg)
    end
    focus_sample_editor()
end

function create_hex_offset_dialog()
    local song = renoise.song()
    local sample = song.selected_sample
    if not sample or not sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample buffer empty")
        return
    end

    local vb = renoise.ViewBuilder()
    
    -- Create textfield with immediate update notifier
    local hex_input = vb:textfield {
        id = "hex_input",
        width = 50,
        value = "80",
        notifier = function(value)
            if value and value ~= "" then
                set_sample_selection_by_hex_offset(value)
                focus_sample_editor()
            end
        end
    }
    
    -- Create switch for quick hex values
    local hex_switch = vb:switch {
        id = "hex_switch",
        width = 200,
        items = {"10", "20", "40", "80"},
        value = 4, -- Default to "80"
        notifier = function(value)
            local hex_value = vb.views.hex_switch.items[value]
            vb.views.hex_input.value = hex_value
            set_sample_selection_by_hex_offset(hex_value)
            focus_sample_editor()
        end
    }
    
    local dialog_content = vb:column {
        margin = 5,
        spacing = 5,
        
        vb:row {
            vb:text { text = "Hex value:" },
            hex_input
        },
        vb:row {
            vb:text { text = "Quick select:" },
            hex_switch
        },
        vb:row {
            vb:button {
                text = "Set forward loops for all samples",
                width = 305,
                notifier = function()
                    set_sample_selection_by_hex_offset(vb.views.hex_input.value)
                    focus_sample_editor()
                end
            }
        }
    }
    
    local function key_handler(dialog, key)
        if key.name == "return" then
            local hex_value = vb.views.hex_input.value
            if hex_value and hex_value ~= "" then
                set_sample_selection_by_hex_offset(hex_value)
            end
            return
        end
        return key
    end
    
    renoise.app():show_custom_dialog("Set Selection by Hex Offset", dialog_content, key_handler)
    focus_sample_editor()
end

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Set Selection by Hex Offset...", invoke = create_hex_offset_dialog}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Set Selection by Hex Offset...", invoke = create_hex_offset_dialog}

function cut_sample_after_selection()
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer.has_sample_data then
      renoise.app():show_status("No sample selected or sample buffer empty")
      return
  end

  local buffer = sample.sample_buffer
  local selection_end = buffer.selection_end
  
  if not selection_end then
      renoise.app():show_status("No selection end point set")
      return
  end
  
  buffer:prepare_sample_data_changes()
  
  -- Set all data after selection_end to 0
  for channel = 1, buffer.number_of_channels do
      for frame = selection_end + 1, buffer.number_of_frames do
          buffer:set_sample_data(channel, frame, 0)
      end
  end
  
  buffer:finalize_sample_data_changes()
  renoise.app():show_status(string.format("Cut sample data after frame %d", selection_end))
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

function create_instrument_from_selection()
    local song, sample = validate_sample()
    if not song then return end

    local buffer = sample.sample_buffer
    local selection_start = buffer.selection_start
    local selection_end = buffer.selection_end
    
    -- Check if there's a valid selection
    if not selection_start or not selection_end or selection_start >= selection_end then
        renoise.app():show_status("No valid selection range set")
        return
    end
    
    -- Calculate selection length
    local selection_length = selection_end - selection_start + 1
    if selection_length < 1 then
        renoise.app():show_status("Invalid selection range")
        return
    end

    -- Create new instrument
    local new_instrument_index = song.selected_instrument_index + 1
    song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    local new_instrument = song:instrument(new_instrument_index)
    
    -- Copy the original instrument name and append "_sel"
    new_instrument.name = sample.name .. "_sel"
    
    -- Ensure we have a sample
    if #new_instrument.samples == 0 then
        new_instrument:insert_sample_at(1)
    end
    local new_sample = new_instrument.samples[1]
    new_sample.name = sample.name .. "_sel"
    
    -- Create new buffer with selection length
    local new_buffer = new_sample.sample_buffer
    new_buffer:create_sample_data(buffer.sample_rate, buffer.bit_depth, buffer.number_of_channels, selection_length)
    new_buffer:prepare_sample_data_changes()
    
    -- Copy the selected portion
    for channel = 1, buffer.number_of_channels do
        for i = 1, selection_length do
            new_buffer:set_sample_data(channel, i, buffer:sample_data(channel, selection_start + i - 1))
        end
    end
    
    new_buffer:finalize_sample_data_changes()
    
    -- Now that we have sample data, set all sample properties
    new_sample.loop_mode = sample.loop_mode
    new_sample.loop_start = 1
    new_sample.loop_end = selection_length
    new_sample.fine_tune = sample.fine_tune
    new_sample.beat_sync_lines = sample.beat_sync_lines
    new_sample.interpolation_mode = sample.interpolation_mode
    new_sample.new_note_action = sample.new_note_action
    new_sample.oneshot = sample.oneshot
    new_sample.autoseek = sample.autoseek
    new_sample.autofade = sample.autofade
    new_sample.sync_to_song = sample.sync_to_song
    
    -- Copy the sample mapping
    new_sample.sample_mapping.base_note = sample.sample_mapping.base_note
    new_sample.sample_mapping.map_velocity_to_volume = sample.sample_mapping.map_velocity_to_volume
    new_sample.sample_mapping.note_range = sample.sample_mapping.note_range
    new_sample.sample_mapping.velocity_range = sample.sample_mapping.velocity_range
    
    renoise.app():show_status(string.format("Created new instrument from selection (frames %d to %d)", selection_start, selection_end))
    
    -- Focus sample editor
    focus_sample_editor()
end

function cut_all_samples_in_instrument()
    -- Get the hex selection value from the original sample
    local song = renoise.song()
    local selected_sample = song.selected_sample
    if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample buffer empty")
        return
    end

    local selection_end = selected_sample.sample_buffer.selection_end
    if not selection_end then
        renoise.app():show_status("No selection end point set")
        return
    end

    -- Get the hex percentage (0-255 mapped to 0-1)
    local hex_value = math.floor((selection_end / selected_sample.sample_buffer.number_of_frames) * 255)
    
    -- Process all samples in the current instrument
    local instrument = song.selected_instrument
    if not instrument then return end
    
    for i = 1, #instrument.samples do
        local sample = instrument.samples[i]
        if sample and sample.sample_buffer.has_sample_data then
            local buffer = sample.sample_buffer
            -- Calculate frames based on hex value (0-255)
            local target_frame = math.floor((hex_value / 255) * buffer.number_of_frames)
            target_frame = math.max(1, math.min(target_frame, buffer.number_of_frames))
            
            -- Set loop points and enable forward loop
            sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
            sample.loop_start = 1
            sample.loop_end = target_frame
        end
    end
    
    renoise.app():show_status(string.format("Set forward loops at hex value %02X", hex_value))
    focus_sample_editor()
end
