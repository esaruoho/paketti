-- Paketti Groovebox 8120 Script



-- Add this line right after stored_step_counts
local sequential_load_current_row = 1

-- "Random" keybinding: Selects a random sample and mutes others
function sample_random()
  local song=renoise.song()
  local ing = song.selected_instrument

  -- Edge case: no instrument or no samples
  if not ing or #ing.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Pick a random sample index
  local random_index = math.random(1, #ing.samples)
  song.selected_sample_index = random_index

  -- Set velocity ranges accordingly
  pakettiSampleVelocityRangeChoke(random_index)
end

-- Function to update track name with step count
local function updateTrackNameWithSteps(track, steps)
  local base_name = track.name:match("8120_%d+")
  if base_name then
    track.name = string.format("%s[%03d]", base_name, steps)
  end
end

-- Function to get step count from track name
local function getStepsFromTrackName(track_name)
  local steps = track_name:match("%[(%d+)%]")
  return steps and tonumber(steps) or 16 -- Default to 16 if no steps found
end


-- Initialization
local vb = renoise.ViewBuilder()
local dialog, rows = nil, {}
local track_names, track_indices, instrument_names
local play_checkbox, follow_checkbox, bpm_display, groove_enabled_checkbox, random_gate_button, fill_empty_label, fill_empty_slider, global_step_buttons, global_controls
local local_groove_sliders, local_groove_labels
local number_buttons_row
local number_buttons
local initializing = false  -- Add initializing flag

-- Ensure instruments exist
function ensure_instruments_exist()
  local instrument_count = #renoise.song().instruments
  if instrument_count < 8 then
    for i = instrument_count + 1, 8 do
      renoise.song():insert_instrument_at(i)
      renoise.song().instruments[i].name = ""  -- Set empty name instead of "Instrument " .. i
    end
  end
  instrument_names = {}
  for i, instr in ipairs(renoise.song().instruments) do
    table.insert(instrument_names, instr.name ~= "" and instr.name or "Instrument " .. i)
  end
end



-- Function to update instrument and track lists
function update_instrument_list_and_popups()
  instrument_names = {}
  for i, instr in ipairs(renoise.song().instruments) do
    table.insert(instrument_names, instr.name ~= "" and instr.name or "")  -- Use empty string as fallback
  end
  for i, row_elements in ipairs(rows) do
    local instrument_popup = row_elements.instrument_popup
    local previous_value = instrument_popup.value
    instrument_popup.items = instrument_names
    if previous_value <= #instrument_names then
      instrument_popup.value = previous_value
    else
      instrument_popup.value = 1
    end
    row_elements.update_sample_name_label()
  end

  track_names = {}
  track_indices = {}
  for i, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(track_names, track.name)
      table.insert(track_indices, i)
    end
  end
  for i, row_elements in ipairs(rows) do
    local track_popup = row_elements.track_popup
    local previous_value = track_popup.value
    track_popup.items = track_names
    if previous_value <= #track_names then
      track_popup.value = previous_value
    else
      track_popup.value = 1
    end
  end
end

-- Function to create a row in the UI
function PakettiEightSlotsByOneTwentyCreateRow(row_index)
  local row_elements = {}
  local normal_color, highlight_color = nil, {0x22 / 255, 0xaa / 255, 0xff / 255}

  -- Create Instrument Popup first
  local instrument_popup = vb:popup{
    items = instrument_names,
    value = row_index,  -- Set default instrument index to row number
    width=150,
    notifier = function(value)
      row_elements.print_to_pattern()
      row_elements.update_sample_name_label()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
  }
  
  -- Store instrument_popup in row_elements immediately
  row_elements.instrument_popup = instrument_popup

  -- Create Number Buttons (1-16)
  local number_buttons = {}
  for i = 1, 16 do
    local is_highlight = (i == 1 or i == 5 or i == 9 or i == 13)
    number_buttons[i] = vb:button{
      text = string.format("%02d", i),
      width=30,
      color = is_highlight and highlight_color or normal_color,
      notifier = function()
        -- Update track name and valuebox
        local track_index = track_indices[row_elements.track_popup.value]
        local track = renoise.song():track(track_index)
        updateTrackNameWithSteps(track, i)
        row_elements.valuebox.value = i
        row_elements.print_to_pattern()
        renoise.app():show_status(string.format("Set steps to %d for row %d", i, row_index))
      end,
      active = true  -- Make buttons active
    }
  end

  -- Create number buttons row
  local number_buttons_plain = vb:row(number_buttons)

  -- Create transpose rotary with the available instrument_popup
  local instrument = renoise.song().instruments[instrument_popup.value]
  local current_transpose = instrument and instrument.transpose or 0
  
  local transpose_rotary = vb:rotary {
    min = -36,
    max = 36,
    value = current_transpose,
    width=25,
    height = 25,
    notifier = function(value)
      -- Get and select the track first
      local track_index = track_indices[row_elements.track_popup.value]
      if track_index then
        renoise.song().selected_track_index = track_index
      end
      
      -- Update instrument transpose
      local instrument_index = instrument_popup.value
      local instrument = renoise.song().instruments[instrument_index]
      if instrument then
        instrument.transpose = value
      end
      
      -- If we're in sample editor view, select the instrument and its active sample
      if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
        -- Select the instrument
        renoise.song().selected_instrument_index = instrument_index
        
        -- Find and select the sample with 00-7F velocity mapping
        if instrument then
          for sample_idx, sample in ipairs(instrument.samples) do
            local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
            local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
            if velocity_min == 0x00 and velocity_max == 0x7F then
              renoise.song().selected_sample_index = sample_idx
              break
            end
          end
        end
      end
      
      renoise.app():show_status(string.format("Set transpose to %+d for instrument %d: %s.", value, instrument_index, renoise.song().selected_sample.name))
    end
  }
    -- Create transpose label
    local transpose_label = vb:text{text="Pitch",font="bold",style="strong"}
    
    -- Create transpose column
    local transpose_column=vb:column{transpose_label,transpose_rotary,vb:text{text="Mute",font="bold",style="strong",width=30}}
  
    -- Create the final number_buttons_row with transpose
    local number_buttons_row=vb:row{number_buttons_plain}
    
    -- Add Output Delay Controls
  local output_delay_label=vb:text{text="Output Delay",font="bold",style="strong"}
  local output_delay_value_label=vb:text{text="0ms",width=50,font="bold",style="strong"}

  local output_delay_slider = vb:slider{
    min= -100,
    max=100,
    steps={1,-1},
    value=renoise.song().tracks[row_index].output_delay,  -- Initialize with current value
    width=100,
    notifier = function(value)
      local track_index = track_indices[row_elements.track_popup.value]
      if track_index then
        value = math.floor(value)  -- Ensure whole number
        renoise.song().tracks[track_index].output_delay = value
        output_delay_value_label.text = string.format("%+04dms", value)        
      end
    end
  }

  local output_delay_reset = vb:button{
    text="Reset",
    notifier = function()
      local track_index = track_indices[row_elements.track_popup.value]
      if track_index then
        output_delay_slider.value = 0
        renoise.song().tracks[track_index].output_delay = 0
        output_delay_value_label.text="0ms"  -- Consistent format when reset
      end
    end
  }

  -- Add Output Delay Controls to the row
  number_buttons_row:add_child(output_delay_label)
  number_buttons_row:add_child(output_delay_slider)
  number_buttons_row:add_child(output_delay_value_label)
  number_buttons_row:add_child(output_delay_reset)

  -- Store the row elements for later use
  row_elements.number_buttons_row = number_buttons_row
  row_elements.number_buttons = number_buttons
  row_elements.transpose_rotary = transpose_rotary
  row_elements.output_delay_slider = output_delay_slider
  row_elements.output_delay_value_label = output_delay_value_label

  -- Create Note Checkboxes (1-16)
  local checkboxes = {}
  local checkbox_row_elements = {}
  for i = 1, 16 do
    checkboxes[i] = vb:checkbox{
      value = false,
      width=30,
      notifier = function()
        if not row_elements.updating_checkboxes then
          -- Get and select the track first
          local track_index = track_indices[row_elements.track_popup.value]
          if track_index then
            renoise.song().selected_track_index = track_index
          end
          
          -- If we're in sample editor view, select the instrument and its active sample
          if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
            -- Select the instrument
            local instrument_index = row_elements.instrument_popup.value
            renoise.song().selected_instrument_index = instrument_index
            
            -- Find and select the sample with 00-7F velocity mapping
            local instrument = renoise.song().instruments[instrument_index]
            if instrument then
              for sample_idx, sample in ipairs(instrument.samples) do
                local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
                local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
                if velocity_min == 0x00 and velocity_max == 0x7F then
                  renoise.song().selected_sample_index = sample_idx
                  break
                end
              end
            end
          end
          
          -- Then print to pattern
          row_elements.print_to_pattern()
        end
      end
    }
    table.insert(checkbox_row_elements, checkboxes[i])
  end

  -- Valuebox for Steps
  local valuebox = vb:valuebox{
    min = 1,
    max = 512,
    value = 16,  -- Default to 16, will be updated in initialize_row()
    width=55,
    notifier = function(value)
      if not row_elements.updating_steps then
        local track_index = track_indices[row_elements.track_popup.value]
        local track = renoise.song():track(track_index)
        -- Select the track first
        renoise.song().selected_track_index = track_index
        -- Then update track name and pattern
        updateTrackNameWithSteps(track, value)
        row_elements.print_to_pattern()
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      --else 
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    end
  }

  -- Sample Name Label
  local sample_name_label = vb:text{
    text="Sample Name",
    font = "bold",
    style = "strong"
  }

  -- Append valuebox and sample name label after checkboxes
  table.insert(checkbox_row_elements, valuebox)
  table.insert(checkbox_row_elements, sample_name_label)

    -- Create Yxx Checkboxes (1-16)
    local yxx_checkboxes = {}
    local yxx_checkbox_row_elements = {}
    for i = 1, 16 do
      yxx_checkboxes[i] = vb:checkbox{
        value = false,
        width=30,
        notifier = function()
          if not row_elements.updating_yxx_checkboxes then
            local track_index = track_indices[row_elements.track_popup.value]
            if track_index then
              renoise.song().selected_track_index = track_index
            end
                      -- If we're in sample editor view, select the instrument and its active sample
          if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
            -- Select the instrument
            local instrument_index = row_elements.instrument_popup.value
            renoise.song().selected_instrument_index = instrument_index
            
            -- Find and select the sample with 00-7F velocity mapping
            local instrument = renoise.song().instruments[instrument_index]
            if instrument then
              for sample_idx, sample in ipairs(instrument.samples) do
                local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
                local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
                if velocity_min == 0x00 and velocity_max == 0x7F then
                  renoise.song().selected_sample_index = sample_idx
                  break
                end
              end
            end
          end

            row_elements.print_to_pattern()
            --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        end
      }
      table.insert(yxx_checkbox_row_elements, yxx_checkboxes[i])
    end
  
    -- Create the valuebox first
    local yxx_valuebox = vb:valuebox{
      min = 0,
      max = 255,
      value = 0,  -- Initialize to 00
      width=55,
      tostring = function(value)
        return string.format("%02X", value)
      end,
      tonumber = function(text)
        return tonumber(text, 16)
      end,
      notifier = function(value)
        row_elements.print_to_pattern()
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    }  
  
    -- Create the slider that updates the valuebox
    local yxx_slider = vb:slider{
      min = 0,
      max = 255,
      steps = {1, -1},
      value = 32, -- Default to 0x20
      width=100,
      notifier = function(value)
        yxx_valuebox.value = math.floor(value)
        row_elements.print_to_pattern()
      end
    }
    row_elements.yxx_slider = yxx_slider
  
    -- Append yxx_valuebox and label after yxx checkboxes
    table.insert(yxx_checkbox_row_elements, yxx_valuebox)
    table.insert(yxx_checkbox_row_elements, vb:text{font="bold",style="strong",text="Yxx"})
  
  -- Randomize Button for Yxx Slider
  local yxx_randomize_button = vb:button{
    text="Random Yxx",
    width=70, -- Adjust width as needed
    notifier = function()
      local random_value = math.random(0, 255)
      yxx_slider.value = random_value
      yxx_valuebox.value = random_value
      row_elements.print_to_pattern()
    end
  }

  -- **Clear Button for Yxx Checkboxes**
  local yxx_clear_button = vb:button{
    text="Clear Yxx",
    width=40, -- Adjust width as needed
    notifier = function()
      for _, checkbox in ipairs(yxx_checkboxes) do
        checkbox.value = false
      end
      row_elements.print_to_pattern()
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }

  -- Add slider and buttons to yxx_checkbox_row_elements
  table.insert(yxx_checkbox_row_elements, yxx_slider)
  table.insert(yxx_checkbox_row_elements, yxx_randomize_button)
  table.insert(yxx_checkbox_row_elements, yxx_clear_button)
  
  -- === End of Yxx Value Buttons Addition ===
  -- Adjusted Track Popup
  local default_track_index = row_index
  if default_track_index > #track_names then
    default_track_index = ((row_index - 1) % #track_names) + 1  -- Wrap around
  end

  local track_popup = vb:popup{
    items = track_names,
    value = default_track_index,
    notifier = function(value)
      row_elements.initialize_row()
    end
  }

  local mute_checkbox = vb:checkbox{
    value = false,
    width=30,
    notifier = function(value)
      local track_index = track_indices[track_popup.value]
      local track = renoise.song().tracks[track_index]
      track.mute_state = value and renoise.Track.MUTE_STATE_MUTED or renoise.Track.MUTE_STATE_ACTIVE
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }

  -- Function to map sample index to slider value
  function row_elements.sample_to_slider_value(sample_index, num_samples)
    if num_samples <= 0 then return 1 end
    -- Reverse the mapping: sample index -> slider value
    return math.floor(1 + ((sample_index - 1) * 120) / num_samples)
  end

  -- Function to map slider value to sample index
  function row_elements.slider_to_sample_index(slider_value, num_samples)
    if num_samples <= 0 then return 1 end
    -- Map slider value -> sample index
    local actual_value = math.floor(1 + ((slider_value - 1) / 120) * num_samples)
    return math.max(1, math.min(actual_value, num_samples))
  end

  local slider = vb:slider{
    min = 1,
    max = 120,
    value = 1,
    width=150,
    steps = {1, -1},
    notifier = function(value)
      value = math.floor(value)
      local instrument_index = row_elements.instrument_popup.value
      local instrument = renoise.song().instruments[instrument_index]
      if instrument and instrument.samples[1] and instrument.samples[1].slice_markers and #instrument.samples[1].slice_markers > 0 then
        renoise.app():show_status("This instrument contains Slices, doing nothing.")
        return
      end
      renoise.song().selected_instrument_index = instrument_index
      -- Set the selected track before changing the sample
      local track_index = track_indices[row_elements.track_popup.value]
      renoise.song().selected_track_index = track_index
      if instrument and #instrument.samples > 0 then
        value = math.min(value, #instrument.samples)
        pakettiSampleVelocityRangeChoke(value)
      end

      row_elements.update_sample_name_label()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
  }

  -- Update the slider value when updating sample name label
  local original_update_sample_name_label = row_elements.update_sample_name_label
  row_elements.update_sample_name_label = function()
    original_update_sample_name_label()
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if instrument and #instrument.samples > 0 then
      slider.value = renoise.song().selected_sample_index
    end
  end

    -- Create Instrument Popup first
  local instrument_popup = vb:popup{
    items = instrument_names,
    value = row_index,  -- Set default instrument index to row number
    width=150,
    notifier = function(value)
      row_elements.print_to_pattern()
      row_elements.update_sample_name_label()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
  }
  
  -- Store instrument_popup in row_elements immediately
  row_elements.instrument_popup = instrument_popup


  

-- Function to Print to Pattern
function row_elements.print_to_pattern()
  if initializing then return end
  local song=renoise.song()
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  local steps = valuebox.value
  local track_index = track_indices[track_popup.value]
  local instrument_index = instrument_popup.value
  local track_in_pattern = pattern.tracks[track_index]

  -- Ensure the track has at least one visible effect column
  local track = renoise.song().tracks[track_index]
  if track.visible_effect_columns == 0 then
    track.visible_effect_columns = 1
  end

  -- First clear all lines in the pattern for this track
  for line = 1, pattern_length do
    local note_line = track_in_pattern:line(line).note_columns[1]
    local effect_column = track_in_pattern:line(line).effect_columns[1]
    note_line:clear()
    effect_column:clear()
  end

  -- Only write notes to the first 16 steps
  for line = 1, math.min(16, steps) do
    local note_checkbox_value = checkboxes[line].value
    local yxx_checkbox_value = yxx_checkboxes[line].value
    local note_line = track_in_pattern:line(line).note_columns[1]
    local effect_column = track_in_pattern:line(line).effect_columns[1]

    if note_checkbox_value then
      note_line.note_string = "C-4"
      note_line.instrument_value = instrument_index - 1

      if yxx_checkbox_value then
        effect_column.number_string = "0Y"
        effect_column.amount_value = yxx_valuebox.value
      else
        effect_column:clear()
      end
    end
  end

  -- Repeat the pattern if needed
  if pattern_length > steps then
    local full_repeats = math.floor(pattern_length / steps)
    for repeat_num = 1, full_repeats - 1 do
      local start_line = repeat_num * steps + 1
      for line = 1, math.min(16, steps) do
        local source_line = track_in_pattern:line(line)
        local dest_line = track_in_pattern:line(start_line + line - 1)
        dest_line.note_columns[1]:copy_from(source_line.note_columns[1])
        dest_line.effect_columns[1]:copy_from(source_line.effect_columns[1])
      end
    end
  end
end

  -- Function to Update Sample Name Label
  function row_elements.update_sample_name_label()
    local instrument = renoise.song().instruments[instrument_popup.value]
    local sample_name = "No sample available"
    if instrument and #instrument.samples > 0 then
      for sample_idx, sample in ipairs(instrument.samples) do
        local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
        local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
        if velocity_min == 0x00 and velocity_max == 0x7F then
          sample_name = sample.name ~= "" and sample.name or string.format("Sample %d", sample_idx)
          -- Truncate sample name if longer than 50 characters
          if #sample_name > 50 then
            sample_name = sample_name:sub(1, 47) .. "..."
          end
          break
        end
      end
      -- Only show status if we have an instrument but couldn't find a valid sample
      if sample_name == "No sample available" then
        renoise.app():show_status(string.format("Instrument %d ('%s') has no samples with full velocity range (00-7F)", 
          instrument_popup.value, instrument.name))
      end
    end
    sample_name_label.text = sample_name
  end

  -- Function to Initialize Row
  function row_elements.initialize_row()
    local track_index = track_indices[track_popup.value]
    if track_index then
      local track = renoise.song().tracks[track_index]
      -- Get step count from track name when initializing row
      local step_count = getStepsFromTrackName(track.name)
      valuebox.value = step_count

      local current_delay = renoise.song().tracks[track_index].output_delay
      output_delay_slider.value = current_delay
      output_delay_value_label.text = string.format("%+04dms", current_delay)
        end

    local track = renoise.song().tracks[track_index]
    local pattern = renoise.song().selected_pattern
    local line_count = pattern.number_of_lines
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true

    for i = 1, 16 do
      checkboxes[i].active = false
      checkboxes[i].value = false
      yxx_checkboxes[i].active = false
      yxx_checkboxes[i].value = false
    end

    local yxx_value_found = false

    for line = 1, math.min(line_count, 16) do
      local note_line = pattern.tracks[track_index].lines[line].note_columns[1]
      local effect_column = pattern.tracks[track_index].lines[line].effect_columns[1]
      if note_line and note_line.note_string == "C-4" then
        checkboxes[line].value = true
        if effect_column and effect_column.number_string == "0Y" then
          yxx_checkboxes[line].value = true
          yxx_valuebox.value = effect_column.amount_value
          yxx_value_found = true
        else
          yxx_checkboxes[line].value = false
        end
      end
    end

    if not yxx_value_found then
      yxx_valuebox.value = 0  -- Initialize to 00 if no Yxx content
    end

    local mute = track.mute_state == renoise.Track.MUTE_STATE_MUTED
    mute_checkbox.value = mute

  -- Find the current 00-7F sample and set slider accordingly
  local instrument = renoise.song().instruments[instrument_popup.value]
  if instrument then
    local found_samples = {}
    for sample_index, sample in ipairs(instrument.samples) do
      local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
      local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
      if velocity_min == 0x00 and velocity_max == 0x7F then
        table.insert(found_samples, sample_index)
      end
    end
    
    -- If exactly one 00-7F sample found, set slider to that index
    -- Otherwise, set to minimum value
    if #found_samples == 1 then
      slider.value = found_samples[1]
    else
      slider.value = 1
    end
  end

    local instrument_used = nil
    for line = 1, math.min(line_count, 16) do
      local note_line = pattern.tracks[track_index].lines[line].note_columns[1]
      if note_line and not note_line.is_empty and note_line.note_string ~= '---' then
        instrument_used = note_line.instrument_value
        break
      end
    end

    if instrument_used and instrument_used + 1 <= #instrument_names then
      instrument_popup.value = instrument_used + 1
    else
      instrument_popup.value = row_index  -- Set default instrument index to row number
    end

    row_elements.update_sample_name_label()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false

    for i = 1, 16 do
      checkboxes[i].active = true
      yxx_checkboxes[i].active = true
    end
  end

  -- Function to Browse Instrument
  function row_elements.browse_instrument()
    local track_popup_value = track_popup.value
    local instrument_popup_value = instrument_popup.value
    local track_index = track_indices[track_popup_value]
    local instrument_index = instrument_popup_value
    renoise.song().selected_track_index = track_index
    renoise.song().selected_instrument_index = instrument_index

      pitchBendDrumkitLoader()

    local instrument = renoise.song().instruments[instrument_index]
    if not instrument then
      renoise.app():show_warning("Selected instrument does not exist.")
      return
    end

    for _, sample in ipairs(instrument.samples) do
      sample.sample_mapping.base_note = 48
      sample.sample_mapping.note_range = {0, 119}
    end

    renoise.app():show_status("Base notes set to C-4 and key mapping adjusted for all samples.")

    if renoise.song().tracks[track_index] then
      -- Preserve the 8120 track name format
      local track = renoise.song().tracks[track_index]
      if not track.name:match("^8120_%d+%[%d+%]$") then
        local base_name = string.format("8120_%02d", track_index)
        track.name = string.format("%s[016]", base_name)  -- Initialize with 16 steps
      end
    else
      renoise.app():show_warning("Selected track does not exist.")
    end

    update_instrument_list_and_popups()
    slider.value = 1

      pakettiSampleVelocityRangeChoke(1)

    update_instrument_list_and_popups()
    row_elements.random_button_pressed = row_elements.random_button_pressed
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end

  -- Function to Refresh Instruments
  function row_elements.refresh_instruments()
    update_instrument_list_and_popups()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end

  -- Function to Select Instrument
  function row_elements.select_instrument()
    renoise.song().selected_instrument_index = instrument_popup.value
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    local track_index = track_indices[track_popup.value]
    local track = renoise.song().tracks[track_index]
    renoise.song().selected_track_index = track_index


  end

  -- Function for Random Button Pressed
  function row_elements.random_button_pressed()
    if initializing then return end
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if instrument and instrument.samples[1] and instrument.samples[1].slice_markers and #instrument.samples[1].slice_markers > 0 then
      renoise.app():show_status("This instrument contains Slices, doing nothing.")
      return
    end
    renoise.song().selected_instrument_index = instrument_index
    sample_random()

    -- Update slider to match the currently selected sample
    local selected_index = renoise.song().selected_sample_index
    if selected_index and selected_index > 0 then
      slider.value = selected_index
    end

    row_elements.update_sample_name_label()
    renoise.song().selected_track_index = 1
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end

  -- Function to Randomize Steps
  function row_elements.randomize()
    if initializing then return end
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    for i = 1, 16 do
      checkboxes[i].value = math.random() >= 0.5
      yxx_checkboxes[i].value = math.random() >= 0.5
    end
    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end

  function row_elements.show_automation()
    local song=renoise.song()
    local track_index = track_indices[track_popup.value]
    local track = song.tracks[track_index]
    
    -- First switch to mixer view and show automation
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    
    -- Select the track
    song.selected_track_index = track_index
    
    -- Find and select the PitchBend parameter
    local found_pitchbend = false
    for device_index, device in ipairs(track.devices) do
      for param_index, param in ipairs(device.parameters) do
        if param.name:find("Pitchbend") then
          song.selected_automation_parameter = param
          
          -- Create automation in the pattern if it doesn't exist
          local pattern = song.selected_pattern
          local pattern_track = pattern.tracks[track_index]
          local existing_automation = pattern_track:find_automation(param)
          
          -- If no automation exists, create it
          if not existing_automation then
            local automation = pattern_track:create_automation(param)
            automation:add_point_at(1, 0.5) -- Start at middle
            automation:add_point_at(pattern.number_of_lines, 0.5) -- End at middle
            add_automation_points_for_notes()            
          end
          found_pitchbend = true
          renoise.app():show_status(string.format('Track "%s" Pitchbend automation for %s', track.name, renoise.song().selected_sample.name))
          break
        end
      end
      if found_pitchbend then break end
    end
    
    if not found_pitchbend then
      renoise.app():show_status(string.format('No Pitchbend automation found in Track "%s"', track.name))
    end
  end


--[[function row_elements.show_macros()
  local instrument_index = row_elements.instrument_popup.value
  local instrument = renoise.song().instruments[instrument_index]
  
  -- Find the active sample (the one with velocity range 00-7F)
  local selected_sample_index = 1
  if instrument and #instrument.samples > 0 then
    for i, sample in ipairs(instrument.samples) do
      local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
      local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
      if velocity_min == 0x00 and velocity_max == 0x7F then
        selected_sample_index = i
        break
      end
    end
  end

  -- Set both instrument and sample
  renoise.song().selected_instrument_index = instrument_index
  renoise.song().selected_sample_index = selected_sample_index
  
  -- Switch views
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app().window.lower_frame_is_visible = true
  renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
  renoise.song().selected_track_index = track_indices[track_popup.value]
end
]]--
  -- Define the Reverse Button
  local reverse_button = vb:button{
    text="Reverse",
    notifier = function()
      row_elements.select_instrument()
      reverse_sample(row_elements)
    end
  }

  -- Define the Row Column Layout
  local row = vb:row{
    vb:column{transpose_column, mute_checkbox},
    vb:column{
    vb:row{number_buttons_row},
    vb:row(checkbox_row_elements),
    vb:row(yxx_checkbox_row_elements),
    vb:row{
      vb:button{
        text="<",
        notifier = function()
          if initializing then return end
          row_elements.updating_checkboxes = true
          row_elements.updating_yxx_checkboxes = true
          local first_note_value = checkboxes[1].value
          local first_yxx_value = yxx_checkboxes[1].value
          for i = 1, 15 do
            checkboxes[i].value = checkboxes[i + 1].value
            yxx_checkboxes[i].value = yxx_checkboxes[i + 1].value
          end
          checkboxes[16].value = first_note_value
          yxx_checkboxes[16].value = first_yxx_value
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          row_elements.updating_yxx_checkboxes = false
          --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text=">",
        notifier = function()
          if initializing then return end
          row_elements.updating_checkboxes = true
          row_elements.updating_yxx_checkboxes = true
          local last_note_value = checkboxes[16].value
          local last_yxx_value = yxx_checkboxes[16].value
          for i = 16, 2, -1 do
            checkboxes[i].value = checkboxes[i - 1].value
            yxx_checkboxes[i].value = yxx_checkboxes[i - 1].value
          end
          checkboxes[1].value = last_note_value
          yxx_checkboxes[1].value = last_yxx_value
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          row_elements.updating_yxx_checkboxes = false
         --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text="Clear",
        notifier = function()
          if initializing then return end
          row_elements.updating_checkboxes = true
          row_elements.updating_yxx_checkboxes = true
          for i = 1, 16 do
            checkboxes[i].value = false
            yxx_checkboxes[i].value = false
          end
          row_elements.updating_checkboxes = false
          row_elements.updating_yxx_checkboxes = false
          row_elements.print_to_pattern()
          renoise.app():show_status("Wiped all steps of row " .. row_index .. ".")
          --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text="Random Steps",
        notifier = function()
          row_elements.randomize()
          renoise.app():show_status("Randomized steps of row " .. row_index .. ".")
         --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      --mute_checkbox,vb:text{text="Mute", font = "bold", style = "strong",width=30},
        instrument_popup,
        vb:button{text="Browse", notifier = row_elements.browse_instrument},
        vb:button{text="RandomLoad", notifier = function() 
        local track_popup_value = row_elements.track_popup.value
        local instrument_popup_value = row_index  -- Set instrument based on row number
        local track_index = track_indices[track_popup_value]
        local instrument_index = instrument_popup_value
        renoise.song().selected_track_index = track_index
        renoise.song().selected_instrument_index = instrument_index
      
        local instrument = loadRandomDrumkitSamples(120)
        if not instrument then
          return
        end
      
        for _, sample in ipairs(instrument.samples) do
          sample.sample_mapping.base_note = 48
          sample.sample_mapping.note_range = {0, 119}
        end
      
        if renoise.song().tracks[track_index] then
          -- Preserve the 8120 track name format
          local track = renoise.song().tracks[track_index]
          if not track.name:match("^8120_%d+%[%d+%]$") then
            local base_name = string.format("8120_%02d", track_index)
            track.name = string.format("%s[016]", base_name)  -- Initialize with 16 steps
          end
  
  -- Add automation device if enabled in preferences
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
    -- Remove any existing *Instr. Macros device first
    for i = #track.devices, 1, -1 do
      local device = track.devices[i]
      if device.name == "*Instr. Macros" then
        track:delete_device_at(i)
      end
    end
    -- Add new *Instr. Macros device
    loadnative("Audio/Effects/Native/*Instr. Macros")
    local macro_device = track:device(#track.devices)
    macro_device.display_name = string.format("%02X_Drumkit", track_index - 1)
    macro_device.is_maximized = false
  end


        else
          renoise.app():show_warning("Selected track does not exist.")
        end
      
        update_instrument_list_and_popups()
        row_elements.slider.value = 1
        pakettiSampleVelocityRangeChoke(1)
        row_elements.update_sample_name_label()
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      end},
      vb:button{text="Refresh", notifier = row_elements.refresh_instruments},
      slider,
      vb:button{text="Random", notifier = row_elements.random_button_pressed},
      vb:button{text="Sample", notifier = row_elements.select_instrument},
      vb:button{text="Automation", notifier = row_elements.show_automation},
--      vb:button{text="Macros", notifier=row_elements.show_macros},
      reverse_button,
    
  },
    },
  }

  -- Assign Elements to row_elements Table
  row_elements.checkboxes = checkboxes
  row_elements.yxx_checkboxes = yxx_checkboxes
  row_elements.yxx_valuebox = yxx_valuebox
  row_elements.valuebox = valuebox
  row_elements.slider = slider
  row_elements.track_popup = track_popup
  row_elements.instrument_popup = instrument_popup
  row_elements.mute_checkbox = mute_checkbox
  row_elements.output_delay_slider = output_delay_slider
  row_elements.output_delay_value_label = output_delay_value_label

  -- Initialize the Row
  row_elements.initialize_row()

  return row, row_elements
end

-- Function to create global controls
function create_global_controls()
  play_checkbox = vb:checkbox{value = renoise.song().transport.playing, midi_mapping = "Paketti:Paketti Groovebox 8120:Play Control", notifier = function(value)
    if initializing then return end
    if value then
      renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
    else
      renoise.song().transport:stop()
    end
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  follow_checkbox = vb:checkbox{value = renoise.song().transport.follow_player, notifier = function(value)
    if initializing then return end
    renoise.song().transport.follow_player = value
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  groove_enabled_checkbox = vb:checkbox{value = renoise.song().transport.groove_enabled, notifier = function(value)
    if initializing then return end
    renoise.song().transport.groove_enabled = value
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
  end}
  bpm_display = vb:button{text="BPM: " .. tostring(renoise.song().transport.bpm),width=60, notifier = update_bpm}

  local_groove_sliders = {}
  local_groove_labels = {}
  local groove_controls = vb:row{}
  for i = 1, 4 do
    local groove_value = renoise.song().transport.groove_amounts[i] or 0
    local_groove_labels[i] = vb:text{text = string.format("%.0f%%", groove_value * 100), style="strong", font="bold",width=35}
    local_groove_sliders[i] = vb:slider{min = 0.0, max = 1.0, value = groove_value,width=100, notifier = function(value)
      if initializing then return end
      local_groove_labels[i].text = string.format("%.0f%%", value * 100)
      local groove_values = {}
      for j = 1, 4 do
        groove_values[j] = local_groove_sliders[j].value
      end
      renoise.song().transport.groove_amounts = groove_values
      renoise.song().transport.groove_enabled = true
      renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
    end}
    groove_controls:add_child(vb:row{local_groove_sliders[i], local_groove_labels[i]})
  end

  random_gate_button = vb:button{ text="Random Gate", midi_mapping="Paketti:Paketti Groovebox 8120:Random Gate", notifier=function()
    if initializing then return end
    random_gate()
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}

  fill_empty_label = vb:text{ text="Fill Empty Steps: 0%", style="strong", font="bold",width=140 }
  fill_empty_slider = vb:slider{min = 0, max = 20, value = 0,width=150, steps = {0.1, -0.1}, midi_mapping="Paketti:Paketti Groovebox 8120:Fill Empty Steps Slider", notifier = function(value)
    if initializing then return end
    fill_empty_label.text="Fill Empty Steps: " .. tostring(math.floor(value)) .. "%"
    if value == 0 then
      clear_all()
    else
      fill_empty_steps(value / 100)
      renoise.app():show_status("Filled empty steps with " .. tostring(math.floor(value)) .. "% probability.")
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  end}

  local reverse_all_button = vb:button{text="Reverse Samples", midi_mapping="Paketti:Paketti Groovebox 8120:Reverse All", notifier = reverse_all}


local randomize_all_yxx_button = vb:button{
  text="Random Yxx",
  notifier = function()
    for _, row_elements in ipairs(rows) do
      local random_value = math.random(0, 255)
      row_elements.yxx_slider.value = random_value
      row_elements.yxx_valuebox.value = random_value
      row_elements.print_to_pattern()
    end
    renoise.app():show_status("Randomized Yxx values for all rows.")
  end
}



  global_controls = vb:column{
    vb:row{
      play_checkbox, vb:text{text="Play", font = "bold", style = "strong",width=30},
      follow_checkbox, vb:text{text="Follow", font = "bold", style = "strong",width=50},
      vb:button{text="/2", notifier = divide_bpm},
      vb:button{text="-", notifier = decrease_bpm},
      bpm_display,
      vb:button{text="+", notifier = increase_bpm},
      vb:button{text="*2", notifier = multiply_bpm},
      random_gate_button,
      vb:button{text="Fetch", midi_mapping="Paketti:Paketti Groovebox 8120:Fetch Pattern", notifier = fetch_pattern},
      fill_empty_label,
      fill_empty_slider}}

  local global_buttons = vb:row{
    vb:text{text="Global", style="strong", font="bold"},
    vb:button{text="Clear All", notifier = clear_all},
    vb:button{text="Random Steps", midi_mapping="Paketti:Paketti Groovebox 8120:Randomize All", notifier = randomize_all},

    vb:button{text="Random Samples", midi_mapping="Paketti:Paketti Groovebox 8120:Random All", notifier = random_all},

    reverse_all_button,
    randomize_all_yxx_button,
    vb:button{
      text="Reset Output Delay",
      notifier = function()
        local song=renoise.song()
        -- Reset all tracks' output delays and update all rows' displays
        for i = 1, 8 do
          song.tracks[i].output_delay = 0
          -- Update the corresponding row's display
          if rows[i] then
            rows[i].output_delay_slider.value = 0
            rows[i].output_delay_value_label.text = string.format("%+04dms", 0)
          end
        end
      end
    },

    -- Add new Sequential Load button
    vb:button{
      text="Sequential Load",
      notifier = function()
        -- Load samples for all 8 rows in sequence using browse_instrument
        for i = 1, 8 do
          local row_elements = rows[i]
          if row_elements then
            renoise.app():show_status("Loading samples for row " .. i)
            row_elements.browse_instrument()
          end
        end
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      end
    },
    vb:button{
      text="Sequential RandomLoad",
      notifier = function()
        loadSequentialDrumkitSamples()
      end
    },    
  }
  
  local global_groove_controls = vb:row{
    groove_enabled_checkbox, vb:text{text="Global Groove", font = "bold", style = "strong",width=100},
    groove_controls, vb:button{text="Random Groove", midi_mapping="Paketti:Paketti Groovebox 8120:Random Groove", notifier = randomize_groove}
  }

  -- Create Global Step Buttons
  local step_values = {"1", "2", "4", "6", "8", "12", "16", "24", "32", "48", "64", "128", "192", "256", "384", "512", "<<", ">>"}
  global_step_buttons = vb:row{}
  for _, step in ipairs(step_values) do
    global_step_buttons:add_child(vb:button{
      text = step,
      midi_mapping = "Paketti:Paketti Groovebox 8120:Global Step " .. step,
      notifier = function()
        if initializing then return end
        if step == "<<" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local first_note_value = row_elements.checkboxes[1].value
            local first_yxx_value = row_elements.yxx_checkboxes[1].value
            for i = 1, 15 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i + 1].value
            end
            row_elements.checkboxes[16].value = first_note_value
            row_elements.yxx_checkboxes[16].value = first_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the left.")
        elseif step == ">>" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local last_note_value = row_elements.checkboxes[16].value
            local last_yxx_value = row_elements.yxx_checkboxes[16].value
            for i = 16, 2, -1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i - 1].value
            end
            row_elements.checkboxes[1].value = last_note_value
            row_elements.yxx_checkboxes[1].value = last_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the right.")
        else
          set_global_steps(tonumber(step))
        end
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    })
  end

--global_controls:add_child(randomize_all_yxx_button)
  return global_controls, global_groove_controls, global_buttons, global_step_buttons
end


function fetch_pattern()
  if initializing then
    -- Allow fetching during initialization without setting checkboxes to inactive
  else
    for _, row_elements in ipairs(rows) do
      for _, checkbox in ipairs(row_elements.checkboxes) do
        checkbox.active = false
      end
      for _, yxx_checkbox in ipairs(row_elements.yxx_checkboxes) do
        yxx_checkbox.active = false
      end
    end
  end

  local pattern = renoise.song().selected_pattern
  
  -- For each row/track, analyze the pattern and store step count
  for i, row_elements in ipairs(rows) do
    -- Get track info and step count from track name
    local track_index = track_indices[row_elements.track_popup.value]
    local track = renoise.song():track(track_index)
    local step_count = getStepsFromTrackName(track.name)
    
    -- Set the valuebox to match track name's step count
    row_elements.updating_steps = true
    row_elements.valuebox.value = step_count
    row_elements.updating_steps = false
  
    local track_in_pattern = pattern.tracks[track_index]
    local line_count = pattern.number_of_lines
    local instrument_used = nil
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    local yxx_value_found = false

    -- First clear all checkboxes
    for i = 1, 16 do
      row_elements.checkboxes[i].value = false
      row_elements.yxx_checkboxes[i].value = false
    end

    -- Now fetch the actual pattern content for the first 16 steps
    for line = 1, math.min(line_count, 16) do
      local note_line = track_in_pattern:line(line).note_columns[1]
      local effect_column = track_in_pattern:line(line).effect_columns[1]
      if note_line and note_line.note_string == "C-4" then
        row_elements.checkboxes[line].value = true
        if effect_column and effect_column.number_string == "0Y" then
          row_elements.yxx_checkboxes[line].value = true
          row_elements.yxx_valuebox.value = effect_column.amount_value
          yxx_value_found = true
        else
          row_elements.yxx_checkboxes[line].value = false
        end
        if not instrument_used and not note_line.is_empty then
          instrument_used = note_line.instrument_value
        end
      else
        row_elements.checkboxes[line].value = false
        row_elements.yxx_checkboxes[line].value = false
      end
    end

    if not yxx_value_found then
      row_elements.yxx_valuebox.value = 0x20 -- Initialize to 20 if no Yxx content
    end

    if instrument_used then
      row_elements.instrument_popup.value = instrument_used + 1
      renoise.song().selected_instrument_index = row_elements.instrument_popup.value
    else
      row_elements.instrument_popup.value = i  -- Set default instrument index to row number
    end

    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end

  if not initializing then
    for _, row_elements in ipairs(rows) do
      for _, checkbox in ipairs(row_elements.checkboxes) do
        checkbox.active = true
      end
      for _, yxx_checkbox in ipairs(row_elements.yxx_checkboxes) do
        yxx_checkbox.active = true
      end
    end
  end

  renoise.app():show_status("Pattern fetched successfully.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end



-- Function to reverse sample
function reverse_sample(row_elements)
  local instrument_index = row_elements.instrument_popup.value
  local instrument = renoise.song().instruments[instrument_index]
  if not instrument then
    renoise.app():show_warning("Selected instrument does not exist.")
    return
  end
  local sample_to_reverse = nil
  for _, sample in ipairs(instrument.samples) do
    local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
    local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
    if velocity_min == 0x00 and velocity_max == 0x7F then
      sample_to_reverse = sample
      break
    end
  end
  if not sample_to_reverse or not sample_to_reverse.sample_buffer then
    renoise.app():show_status("No sample to reverse, doing nothing.")
    return
  end
  local sample_buffer = sample_to_reverse.sample_buffer
  local num_channels = sample_buffer.number_of_channels
  local num_frames = sample_buffer.number_of_frames
  if num_channels == 0 or num_frames == 0 then
    renoise.app():show_warning("Selected sample has no channels or frames for this row.")
    return
  end
  sample_buffer:prepare_sample_data_changes()
  for channel = 1, num_channels do
    local channel_data = {}
    for frame = 1, num_frames do
      channel_data[frame] = sample_buffer:sample_data(channel, frame)
    end
    for i = 1, math.floor(num_frames / 2) do
      channel_data[i], channel_data[num_frames - i + 1] = channel_data[num_frames - i + 1], channel_data[i]
    end
    for frame = 1, num_frames do
      sample_buffer:set_sample_data(channel, frame, channel_data[frame])
    end
  end
  sample_buffer:finalize_sample_data_changes()
  local sample_name = sample_to_reverse.name ~= "" and sample_to_reverse.name or "Sample " .. sample_to_reverse.index
  local instrument_name = instrument.name ~= "" and instrument.name or "Instrument " .. instrument_index
  renoise.app():show_status(string.format("Reversed Sample '%s' of Instrument '%s' for Row.", sample_name, instrument_name))
end

-- Function to reverse all samples
function reverse_all()
  if initializing then return end
  local reversed_count = 0
  local reversed_samples = {}
  
  for row_index, row_elements in ipairs(rows) do
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if instrument then
      local sample_to_reverse = nil
      for _, sample in ipairs(instrument.samples) do
        local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
        local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
        if velocity_min == 0x00 and velocity_max == 0x7F then
          sample_to_reverse = sample
          break
        end
      end
      
      if sample_to_reverse and sample_to_reverse.sample_buffer then
        local sample_buffer = sample_to_reverse.sample_buffer
        local num_channels = sample_buffer.number_of_channels
        local num_frames = sample_buffer.number_of_frames
        
        if num_channels > 0 and num_frames > 0 then
          sample_buffer:prepare_sample_data_changes()
          for channel = 1, num_channels do
            local channel_data = {}
            for frame = 1, num_frames do
              channel_data[frame] = sample_buffer:sample_data(channel, frame)
            end
            for i = 1, math.floor(num_frames / 2) do
              channel_data[i], channel_data[num_frames - i + 1] = channel_data[num_frames - i + 1], channel_data[i]
            end
            for frame = 1, num_frames do
              sample_buffer:set_sample_data(channel, frame, channel_data[frame])
            end
          end
          sample_buffer:finalize_sample_data_changes()
          
          local sample_name = sample_to_reverse.name ~= "" and sample_to_reverse.name or "Sample " .. sample_to_reverse.index
          table.insert(reversed_samples, string.format("%02d: %s", row_index, sample_name))
          reversed_count = reversed_count + 1
        end
      end
    end
  end
  
  if reversed_count > 0 then
    local status_message = string.format("Reversed Sample: %s", table.concat(reversed_samples, " - "))
    renoise.app():show_status(status_message)
  else
    renoise.app():show_status("No samples found to reverse in any instrument.")
  end
end

function random_gate()
  if initializing then return end
  
  -- Set batch update mode
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    
    -- Update both track name and valuebox
    local track_index = track_indices[row_elements.track_popup.value]
    local track = renoise.song():track(track_index)
    updateTrackNameWithSteps(track, 16)  -- Set track name to 16 steps
    row_elements.valuebox.value = 16     -- Set valuebox to 16
  end

  -- Prepare all changes in memory first
  local checkbox_states = {}
  -- Remove yxx_states as we don't want to randomize Yxx checkboxes
  
  for i = 1, 16 do
    local selected_row = math.random(1, #rows)
    for row_index = 1, #rows do
      if not checkbox_states[row_index] then 
        checkbox_states[row_index] = {}
      end
      checkbox_states[row_index][i] = (row_index == selected_row)
      -- Remove the yxx_states assignment
    end
  end

  -- Apply all changes at once
  for row_index, row_elements in ipairs(rows) do
    for i = 1, 16 do
      row_elements.checkboxes[i].value = checkbox_states[row_index][i]
      -- Leave Yxx checkboxes unchanged
    end
  end

  -- Single pattern update at the end
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    row_elements.print_to_pattern()
  end

  renoise.app():show_status("Step count reset to 16, random gate pattern applied.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to clear all steps
function clear_all()
  if initializing then return end
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    local checkboxes = row_elements.checkboxes
    local yxx_checkboxes = row_elements.yxx_checkboxes
    for i = 1, 16 do
      checkboxes[i].value = false
      yxx_checkboxes[i].value = false
    end
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    row_elements.print_to_pattern()
  end
  renoise.app():show_status("Wiped all steps of each row.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to fill empty steps
function fill_empty_steps(probability)
  if initializing then return end
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    for i = 1, 16 do
      if not row_elements.checkboxes[i].value then
        row_elements.checkboxes[i].value = math.random() < probability
      end
      if not row_elements.yxx_checkboxes[i].value then
        row_elements.yxx_checkboxes[i].value = math.random() < probability
      end
    end
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    row_elements.print_to_pattern()
  end
end

-- Function to randomize all samples
function random_all()
  if initializing then return end
  
  -- Check if we have enough instruments
  local song=renoise.song()
  if #song.instruments < 8 then
    renoise.app():show_status(string.format("Not enough instruments. Need 8, but only have %d. Please add more instruments first.", #song.instruments))
    return
  end
  
  -- Check if any instruments have samples
  local has_samples = false
  for i = 1, 8 do
    if song.instruments[i] and #song.instruments[i].samples > 0 then
      has_samples = true
      break
    end
  end
  
  if not has_samples then
    renoise.app():show_status("No samples found in any of the 8 instruments. Please load some samples first.")
    return
  end
  
  -- Now proceed with randomization only if we have samples
  for _, row_elements in ipairs(rows) do
    if row_elements.random_button_pressed then
      row_elements.random_button_pressed()
    else
      renoise.app():show_status("Error: random_button_pressed not found for a row.")
    end
  end
  renoise.app():show_status("Each Instrument Bank now has a Random Selected Sample.")
end

function randomize_all()
  if initializing then return end
  
  -- First set all rows to update mode
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
  end
  
  -- Then do all randomization
  for _, row_elements in ipairs(rows) do
    for i = 1, 16 do
      row_elements.checkboxes[i].value = math.random() >= 0.5
      row_elements.yxx_checkboxes[i].value = math.random() >= 0.5
    end
  end
  
  -- Finally, update pattern and reset flags
  for _, row_elements in ipairs(rows) do
    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end
  
  renoise.app():show_status("Each Instrument Row step content has now been randomized.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function set_global_steps(steps)
  if initializing then return end  
  
  -- Don't set initializing flag, as it prevents pattern printing
  for _, row_elements in ipairs(rows) do
    row_elements.updating_steps = true
    local track_index = track_indices[row_elements.track_popup.value]
    local track = renoise.song():track(track_index)
    updateTrackNameWithSteps(track, steps)
    row_elements.valuebox.value = steps
    row_elements.updating_steps = false
    row_elements.print_to_pattern()
  end
  
  renoise.app():show_status("All step counts set to " .. tostring(steps) .. ".")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Functions to adjust BPM
function increase_bpm()
  if initializing then return end
  local new_bpm = renoise.song().transport.bpm + 1
  if new_bpm > 999 then new_bpm = 999 end
  renoise.song().transport.bpm = new_bpm
  if bpm_display then bpm_display.text="BPM: " .. tostring(renoise.song().transport.bpm) end
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function decrease_bpm()
  if initializing then return end
  local new_bpm = renoise.song().transport.bpm - 1
  if new_bpm < 20 then new_bpm = 20 end
  renoise.song().transport.bpm = new_bpm
  if bpm_display then bpm_display.text="BPM: " .. tostring(renoise.song().transport.bpm) end
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function divide_bpm()
  if initializing then return end
  local new_bpm = math.floor(renoise.song().transport.bpm / 2)
  if new_bpm < 20 then new_bpm = 20 end
  renoise.song().transport.bpm = new_bpm
  if bpm_display then bpm_display.text="BPM: " .. tostring(renoise.song().transport.bpm) end
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function multiply_bpm()
  if initializing then return end
  local new_bpm = renoise.song().transport.bpm * 2
  if new_bpm > 999 then new_bpm = 999 end
  renoise.song().transport.bpm = new_bpm
  if bpm_display then bpm_display.text="BPM: " .. tostring(renoise.song().transport.bpm) end
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function update_bpm()
  if initializing then return end
  local random_bpm = math.random(20, 300)
  renoise.song().transport.bpm = random_bpm
  bpm_display.text="BPM: " .. tostring(random_bpm)
  renoise.app():show_status("BPM set to " .. random_bpm)
end

-- Function to randomize groove
function randomize_groove()
  if initializing then return end
  local groove_values = {}
  for i = 1, 4 do
    local random_value = math.random()
    if local_groove_sliders and local_groove_sliders[i] then
      local_groove_sliders[i].value = random_value
    end
    if local_groove_labels and local_groove_labels[i] then
      local_groove_labels[i].text = string.format("%d%%", random_value * 100)
    end
    groove_values[i] = random_value
  end
  renoise.song().transport.groove_amounts = groove_values
  renoise.song().transport.groove_enabled = true
  renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
--  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
  renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
end

-- Paketti Groovebox 8120 Dialog
function pakettiEightSlotsByOneTwentyDialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  initializing = true  -- Set initializing flag to true

  ensure_instruments_exist()  -- Ensure at least 8 instruments exist
  PakettiEightOneTwentyInit()


  -- Now rebuild track_names and track_indices
  track_names, track_indices = {}, {}
  for i, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(track_names, track.name)
      table.insert(track_indices, i)
    end
  end

  local global_controls, global_groove_controls, global_buttons, global_step_buttons = create_global_controls()
  local dc = vb:column{global_controls, global_groove_controls, global_buttons, global_step_buttons, vb:space{height=8}}
  -- Create and add rows with spacing between them
  for i = 1, 8 do
    if i > 1 then
      -- Add space before each row except the first one
      dc:add_child(vb:space {height = 8})
    end
    local row, elements = PakettiEightSlotsByOneTwentyCreateRow(i)
    dc:add_child(row)
    rows[i] = elements
  end


  fetch_pattern()  -- Call fetch_pattern() to populate GUI elements from the pattern

  initializing = false  -- Set initializing flag to false after initialization

--[[  dc:add_child(vb:button{text="Run Debug", notifier = function()
    debug_instruments_and_samples()
    renoise.app():show_status("Debug information printed to console.")
  end}) ]]--
--[[  dc:add_child(vb:button{text="Print to Pattern", notifier = function()
    for i, elements in ipairs(rows) do
      elements.print_to_pattern()
    end
    renoise.app():show_status("Pattern updated successfully.")
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end})--]]
  for _, row_elements in ipairs(rows) do
    row_elements.update_sample_name_label()
  end
  debug_instruments_and_samples()
  dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120", dc, my_keyhandler_func)
end



function assign_midi_mappings()
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Play Control",invoke=function(message)
    if message:is_trigger() then
      if not renoise.song().transport.playing then
        renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
      else
        renoise.song().transport:stop()
      end
    end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Fill",invoke=function(message)
    if message:is_trigger() then random_fill() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Gate",invoke=function(message)
    if message:is_trigger() then random_gate() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Fetch Pattern",invoke=function(message)
    if message:is_trigger() then fetch_pattern() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Fill Empty Steps Slider",invoke=function(message)
    if message:is_abs_value() then
      fill_empty_slider.value = message.int_value * 100 / 127
    end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random All",invoke=function(message)
    if message:is_trigger() then random_all() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Randomize All",invoke=function(message)
    if message:is_trigger() then randomize_all() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Groove",invoke=function(message)
    if message:is_trigger() then randomize_groove() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Reverse All",invoke=function(message)
    if message:is_trigger() then reverse_all() end
  end}

  local step_button_names = {"1", "2", "4", "6", "8", "12", "16", "24", "32", "48", "64", "128", "192", "256", "384", "512", "<<", ">>"}
  for _, step in ipairs(step_button_names) do
    renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Step " .. step,invoke=function(message)
      if message:is_trigger() then
        if step == "<<" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local first_note_value = row_elements.checkboxes[1].value
            local first_yxx_value = row_elements.yxx_checkboxes[1].value
            for i = 1, 15 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i + 1].value
            end
            row_elements.checkboxes[16].value = first_note_value
            row_elements.yxx_checkboxes[16].value = first_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the left.")
        elseif step == ">>" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local last_note_value = row_elements.checkboxes[16].value
            local last_yxx_value = row_elements.yxx_checkboxes[16].value
            for i = 16, 2, -1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i - 1].value
            end
            row_elements.checkboxes[1].value = last_note_value
            row_elements.yxx_checkboxes[1].value = last_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the right.")
        else
          set_global_steps(tonumber(step))
        end
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    end}
  end

  for row = 1, 8 do
    for step = 1, 16 do
      renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%d Step%d", row, step),invoke=function(message)
        if message:is_trigger() then
          local row_elements = rows[row]
          if row_elements and row_elements.checkboxes[step] then
            row_elements.checkboxes[step].value = not row_elements.checkboxes[step].value
          end
        end
      end}
    end
    local buttons = {"<", ">", "Clear", "Randomize", "Browse", "Show", "Random", "Automation", "Reverse"}
    for _, btn in ipairs(buttons) do
      renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%d %s", row, btn),invoke=function(message)
        if message:is_trigger() then
          local row_elements = rows[row]
          if row_elements then
            if btn == "<" then
              row_elements.updating_checkboxes = true
              row_elements.updating_yxx_checkboxes = true
              local first_note_value = row_elements.checkboxes[1].value
              local first_yxx_value = row_elements.yxx_checkboxes[1].value
              for i = 1, 15 do
                row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
                row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i + 1].value
              end
              row_elements.checkboxes[16].value = first_note_value
              row_elements.yxx_checkboxes[16].value = first_yxx_value
              row_elements.print_to_pattern()
              row_elements.updating_checkboxes = false
              row_elements.updating_yxx_checkboxes = false
              renoise.app():show_status(string.format("Row %d: Steps shifted left.", row))
            elseif btn == ">" then
              row_elements.updating_checkboxes = true
              row_elements.updating_yxx_checkboxes = true
              local last_note_value = row_elements.checkboxes[16].value
              local last_yxx_value = row_elements.yxx_checkboxes[16].value
              for i = 16, 2, -1 do
                row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
                row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i - 1].value
              end
              row_elements.checkboxes[1].value = last_note_value
              row_elements.yxx_checkboxes[1].value = last_yxx_value
              row_elements.print_to_pattern()
              row_elements.updating_checkboxes = false
              row_elements.updating_yxx_checkboxes = false
              renoise.app():show_status(string.format("Row %d: Steps shifted right.", row))
            elseif btn == "Clear" then
              row_elements.updating_checkboxes = true
              row_elements.updating_yxx_checkboxes = true
              for i = 1, 16 do
                row_elements.checkboxes[i].value = false
                row_elements.yxx_checkboxes[i].value = false
              end
              row_elements.updating_checkboxes = false
              row_elements.updating_yxx_checkboxes = false
              row_elements.print_to_pattern()
              renoise.app():show_status(string.format("Row %d: All steps cleared.", row))
            elseif btn == "Randomize" then
              row_elements.randomize()
              renoise.app():show_status(string.format("Row %d: Steps randomized.", row))
            elseif btn == "Browse" then
              row_elements.browse_instrument()
            elseif btn == "Show" then
              row_elements.select_instrument()
            elseif btn == "Random" then
              row_elements.random_button_pressed()
            elseif btn == "Automation" then
              row_elements.show_automation()
--            elseif btn == "Macros" then 
--              row_elements.show_macros()
            elseif btn == "Reverse" then
              reverse_sample(row_elements)
            end
          end
        end
      end}
    end
  end
end

assign_midi_mappings()

function GrooveboxShowClose()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    rows = {}
  else pakettiEightSlotsByOneTwentyDialog() end
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120",invoke=function() GrooveboxShowClose() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Groovebox 8120...",invoke=function() GrooveboxShowClose() end}

renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120",invoke=function(message)
  if message:is_trigger() then
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
      rows = {}
    else pakettiEightSlotsByOneTwentyDialog() end end end}

function debug_instruments_and_samples()
  print("----- Debug: Instruments and Samples (Velocity 00-7F) -----")
  for row_index, row_elements in ipairs(rows) do
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    local instrument_name = instrument and (instrument.name ~= "" and instrument.name or "Instrument " .. instrument_index) or "Unknown Instrument"
    if instrument then
      local sample_count = #instrument.samples
      if sample_count > 0 then
        for sample_index, sample in ipairs(instrument.samples) do
          local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1] or nil
          local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2] or nil
          if velocity_min == 0x00 and velocity_max == 0x7F then
            local sample_name = sample.name ~= "" and sample.name or "Sample " .. sample_index
            print(string.format("Row %d: Instrument [%d] '%s', Sample [%d] '%s' has Velocity Range: %02X-%02X", row_index, instrument_index, instrument_name, sample_index, sample_name, velocity_min, velocity_max))
          end
        end
      end
    end
  end
  print("----- End of Debug -----")
end


function PakettiEightOneTwentyInit()
  local song=renoise.song()
  local editmodestate = song.transport.edit_mode
  song.transport.edit_mode = true
  
  -- Count sequencer tracks in first 8 positions
  local sequencer_tracks = 0
  local needs_initialization = false
  for i = 1, math.min(8, #song.tracks) do
    if song:track(i).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      sequencer_tracks = sequencer_tracks + 1
      -- Check if track needs initialization (doesn't have correct base name format)
      if not song:track(i).name:match("^8120_%d+%[%d+%]$") then
        needs_initialization = true
      end
    end
  end

  -- Only change track if we need to initialize AND we're not in automation view
  local in_automation = (renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION)
  if needs_initialization and not in_automation then
    song.selected_track_index = 1
  end

  -- Add any missing sequencer tracks at position 1
  while sequencer_tracks < 8 do
    local next_track_number = sequencer_tracks + 1
    song:insert_track_at(next_track_number)
    song:track(next_track_number).name = string.format("8120_%02d[016]", next_track_number)
    sequencer_tracks = sequencer_tracks + 1
  end

  -- Only initialize track names if they don't follow the correct format
  for i = 1, 8 do
    local track = song:track(i)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Only change name if it doesn't match our format
      if not track.name:match("^8120_%d+%[%d+%]$") then
        local base_name = string.format("8120_%02d", i)
        track.name = string.format("%s[016]", base_name)  -- Initialize with 16 steps
      end
    end
  end

  song.transport.edit_mode = editmodestate
end


renoise.tool():add_keybinding{name="Global:Paketti:Initialize for Groovebox 8120",invoke=function() 
PakettiEightOneTwentyInit()
end}

renoise.tool():add_menu_entry{name="Mixer:Paketti..:Initialize for Groovebox 8120",invoke=function() 
PakettiEightOneTwentyInit()
end}





-- Function to load samples sequentially from 8 folders using ProcessSlicer
function loadSequentialDrumkitSamples()
  local folders = {}
  local current_folder = 1
  local slicer = nil
  local dialog = nil
  local vb = nil
  local status_labels = {}
  
  -- Helper function to get just filename from path
  local function getFilename(filepath)
    return filepath:match("([^/\\]+)%.%w+$") or filepath
  end
  
  -- Helper function to get file size
  local function getFileSize(filepath)
    local file = io.open(filepath, "rb")
    if file then
      local size = file:seek("end")
      file:close()
      return size
    end
    return 0
  end
  
  -- Helper function to format file size
  local function formatFileSize(size)
    local units = {'B', 'KB', 'MB', 'GB'}
    local unit_index = 1
    while size > 1024 and unit_index < #units do
      size = size / 1024
      unit_index = unit_index + 1
    end
    return string.format("%.2f %s", size, units[unit_index])
  end
  
  -- Helper function to cap filename length
  local function capFilename(filename)
    if #filename > 80 then
      return filename:sub(1, 77) .. "..."
    end
    return filename
  end

  -- Function to add *Instr. Macros device to a track
  local function addInstrMacrosToTrack(track_index)
    local song=renoise.song()
    -- First select the matching instrument
    song.selected_instrument_index = track_index
    -- Then select the track
    song.selected_track_index = track_index
    
    if song.selected_track.type ~= renoise.Track.TRACK_TYPE_MASTER then -- Don't add to master track
      -- Remove any existing *Instr. Macros device first
      for i = #song.selected_track.devices, 1, -1 do
        local device = song.selected_track.devices[i]
        if device.name == "*Instr. Macros" then
          song.selected_track:delete_device_at(i)
        end
      end
      -- Add new *Instr. Macros device
      loadnative("Audio/Effects/Native/*Instr. Macros")
      local macro_device = song.selected_track:device(#song.selected_track.devices)
      macro_device.display_name = string.format("%02X_Drumkit", track_index - 1)
      macro_device.is_maximized = false
      
      -- Print debug info
      print(string.format("Added *Instr. Macros to track %d, linked to instrument %d", track_index, song.selected_instrument_index))
    end
  end
  
  -- Function to process a single instrument
  local function processInstrument(instrument_index, folder_path)
    -- Get all valid audio files in the directory
    local sample_files = PakettiGetFilesInDirectory(folder_path)
    if #sample_files == 0 then
      print(string.format("ERROR: No audio files found in folder: %s", folder_path))
      return false, "No audio files found in folder " .. folder_path
    end

    -- Set up the instrument
    local song=renoise.song()
    song.selected_track_index = instrument_index
    song.selected_instrument_index = instrument_index
    local instrument = song.selected_instrument
    
    -- Load the default drumkit instrument
    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    renoise.app():load_instrument(defaultInstrument)
    
    -- Update instrument reference and name
    instrument = song.selected_instrument
    instrument.name = string.format("8120_%02d Kit", instrument_index)
    instrument.macros_visible = true

    -- Load samples
    local max_samples = 120
    local num_samples_to_load = math.min(#sample_files, max_samples)
    local failed_files = {}
    
    for i = 1, num_samples_to_load do
      local random_index = math.random(1, #sample_files)
      local selected_file = sample_files[random_index]
      table.remove(sample_files, random_index)
      
      local file_size = getFileSize(selected_file)

      if #instrument.samples < i then
        instrument:insert_sample_at(i)
      end
      
      local load_failed = false
      local error_msg = ""
      
      -- Try to load the sample
      local ok = pcall(function()
        local buffer = instrument.samples[i].sample_buffer
        if not buffer then
          load_failed = true
          error_msg = "No sample buffer available"
          return
        end
        
        -- Attempt to load and catch any errors
        local load_ok, load_err = buffer:load_from(selected_file)
        if not load_ok then
          load_failed = true
          error_msg = load_err or "Unknown error during load_from"
          return
        end
        
        -- Set the name only if load succeeded
        instrument.samples[i].name = getFilename(selected_file)
      end)

      -- Check both pcall result and our own error flag
      if not ok or load_failed then
        print(string.format("FAILED TO LOAD SAMPLE Part %d [%d/%d]: PATH: %s SIZE: %s", 
          instrument_index, i, num_samples_to_load, selected_file, formatFileSize(file_size)))
        
        table.insert(failed_files, {
          index = i,
          path = selected_file,
          size = file_size,
          error = error_msg
        })
      end

      -- Update status display
      if dialog and dialog.visible then
        local display_name = capFilename(getFilename(selected_file))
        status_labels[instrument_index].text = string.format("Part %d/8: Loading sample %03d/%03d: %s", 
          instrument_index, i, num_samples_to_load, display_name)
        status_labels[instrument_index].font = "bold"
        status_labels[instrument_index].style = "strong"
      end
      
      if i % 5 == 0 then
        coroutine.yield()
      end
    end

    -- Print summary of failed files at the end
    if #failed_files > 0 then
      print(string.format("\nSUMMARY: Part %d had %d failed loads:", instrument_index, #failed_files))
      for _, fail in ipairs(failed_files) do
        print(string.format("Sample [%d/%d]: PATH: %s SIZE: %s", 
          fail.index, num_samples_to_load, fail.path, formatFileSize(fail.size)))
      end
      print("----------------------------------------")
    end

    return true
  end

  -- Main processing function for ProcessSlicer
  local function process()
    -- Switch to sample editor at start
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

    for i = 1, 8 do
      if slicer:was_cancelled() then
        renoise.app():show_status("Sequential loading cancelled")
        break
      end
      
      -- Update status to show which part is processing
      for j = i + 1, 8 do
        local folder_name = getFilename(folders[j])
        status_labels[j].text = string.format("Part %d/8: Queued - Random from %s", j, folder_name)
        status_labels[j].font = "bold"
        status_labels[j].style = "strong"
      end
      
      local success, error = processInstrument(i, folders[i])
      if not success then
        print(error)
      end
      
      coroutine.yield()
    end
    
    -- Close dialog and finish up
    if dialog and dialog.visible then
      dialog:close()
    end
    
    -- Apply final settings and update UI
    for i = 1, 8 do
      local instrument = renoise.song():instrument(i)
      if instrument then
        -- First set all samples to velocity 0-0
        for sample_idx, sample in ipairs(instrument.samples) do
          sample.sample_mapping.velocity_range = {0, 0}
          -- Set base note and note range for all samples
          sample.sample_mapping.base_note = 48
          sample.sample_mapping.note_range = {0, 119}
        end
        -- Then set first sample to full velocity range
        if #instrument.samples > 0 then
          instrument.samples[1].sample_mapping.velocity_range = {0, 127}
        end
      -- Add *Instr. Macros device to each track if enabled in preferences
      if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
          renoise.song().selected_track_index = i
          addInstrMacrosToTrack(i)
        end
      end
    
    end
    
    update_instrument_list_and_popups()
    -- Switch back to pattern editor when done
   --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
  end

  -- Function to start the processing
  local function startProcessing()
    -- Create ProcessSlicer
    slicer = ProcessSlicer(process)
    
    -- Create progress dialog with status for all 8 parts
    local vb = renoise.ViewBuilder()
    local DEFAULT_margin=renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
    local DEFAULT_spacing=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
    
    local dialog_content = vb:column{
      margin=DEFAULT_MARGIN,
      spacing=DEFAULT_SPACING,
    }
    
    -- Add status labels for all 8 parts
    for i = 1, 8 do
      local folder_name = getFilename(folders[i])
      local status_label = vb:text{
        text = string.format("Part %d/8: Queued - Random from %s", i, folder_name),
        font = "bold",
        style = "strong"
      }
      status_labels[i] = status_label
      dialog_content:add_child(status_label)
    end
    
    dialog_content:add_child(vb:button{
      text="Cancel",
      width=80,
      notifier = function()
        slicer:cancel()
        if dialog and dialog.visible then
          dialog:close()
        end
        renoise.app():show_status("Sequential loading cancelled by user")
      end
    })
    
    -- Show dialog
    dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 Sequential Load Progress Dialog", dialog_content)
    
    -- Start processing
    slicer:start()
  end

  -- Function to prompt for next folder
  local function promptNextFolder()
    local folder_path = renoise.app():prompt_for_path(string.format("Select folder %d of 8 for sequential loading", current_folder))
    if folder_path then
      folders[current_folder] = folder_path
      local folder_name = getFilename(folder_path)
      renoise.app():show_status(string.format("Selected folder %d/8: %s", current_folder, folder_name))
      current_folder = current_folder + 1
      if current_folder <= 8 then
        return promptNextFolder()
      else
        -- All folders selected, start processing
        renoise.app():show_status("All folders selected, starting sequential load...")
        startProcessing()
      end
    else
      -- User cancelled folder selection
      if dialog and dialog.visible then
        dialog:close()
      end
      renoise.app():show_status("Sequential loading cancelled - folder selection aborted")
      return
    end
  end

  -- Start by prompting for folders
  promptNextFolder()
end