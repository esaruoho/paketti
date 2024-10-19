local vb = renoise.ViewBuilder()
local dialog, rows = nil, {}
local track_names, track_indices, instrument_names
local play_checkbox, follow_checkbox, bpm_display, groove_enabled_checkbox, random_gate_button, fill_empty_label, fill_empty_slider, global_step_buttons, global_controls

local function set_global_steps(steps)
  for _, row_elements in ipairs(rows) do
    row_elements.updating_steps = true
    row_elements.valuebox.value = steps
    row_elements.updating_steps = false
    row_elements.print_to_pattern()
  end
  renoise.app():show_status("All step counts set to " .. tostring(steps) .. ".")
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function random_gate()
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
  end
  for i = 1, 16 do
    local selected_row = math.random(1, #rows)
    for row_index, row_elements in ipairs(rows) do
      row_elements.checkboxes[i].value = (row_index == selected_row)
    end
  end
  for _, row_elements in ipairs(rows) do
    row_elements.print_to_pattern()
    row_elements.valuebox.value = 16
  end
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = false
  end
  renoise.app():show_status("Stepcount reset to 16, all rows filled with one checkbox per each rowstep.")
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function fill_empty_steps(probability)
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    local checkboxes = row_elements.checkboxes
    for i = 1, 16 do
      if not checkboxes[i].value then
        if math.random() < probability then
          checkboxes[i].value = true
        end
      end
    end
    row_elements.updating_checkboxes = false
    row_elements.print_to_pattern()
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function PakettiEightSlotsByOneTwentyKeyHandler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    rows = {}
    return nil
  else
    return key
  end
end

local function update_instrument_list_and_popups()
  instrument_names = {}
  for i, instr in ipairs(renoise.song().instruments) do
    table.insert(instrument_names, instr.name ~= "" and instr.name or "Instrument " .. i)
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
end

local function debug_instruments_and_samples()
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

local function reverse_sample(row_elements)
  local instrument_index = row_elements.instrument_popup.value
  local instrument = renoise.song().instruments[instrument_index]
  if not instrument then
    renoise.app():show_message("Instrument not found for this row.")
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
    renoise.app():show_message("Sample with velocity range 00-7F not found or has no audio data for this row.")
    return
  end
  local sample_buffer = sample_to_reverse.sample_buffer
  local num_channels = sample_buffer.number_of_channels
  local num_frames = sample_buffer.number_of_frames
  if num_channels == 0 or num_frames == 0 then
    renoise.app():show_message("Selected sample has no channels or frames for this row.")
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

local function reverse_all()
  local reversed_samples = {}
  for row_index, row_elements in ipairs(rows) do
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if not instrument then
      table.insert(reversed_samples, string.format("Row %d: Instrument not found.", row_index))
    else
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
        table.insert(reversed_samples, string.format("Row %d: Sample not found or no audio data.", row_index))
      else
        local sample_buffer = sample_to_reverse.sample_buffer
        local num_channels = sample_buffer.number_of_channels
        local num_frames = sample_buffer.number_of_frames
        if num_channels == 0 or num_frames == 0 then
          table.insert(reversed_samples, string.format("Row %d: Selected sample has no channels or frames.", row_index))
        else
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
          table.insert(reversed_samples, string.format("Row %d: Reversed Sample '%s' of Instrument '%s'.", row_index, sample_name, instrument_name))
        end
      end
    end
  end
  if #reversed_samples > 0 then
    local status_message = table.concat(reversed_samples, "\n")
    renoise.app():show_status(status_message)
  else
    renoise.app():show_status("No samples were reversed.")
  end
end

local function PakettiEightSlotsByOneTwentyCreateRow(row_index)
  local row_elements = {}
  preferences.PakettiEightSlotsByOneTwenty = preferences.PakettiEightSlotsByOneTwenty or {}
  local row_prefs = preferences.PakettiEightSlotsByOneTwenty[row_index] or {}
  preferences.PakettiEightSlotsByOneTwenty[row_index] = row_prefs
  
  local normal_color, highlight_color = nil, {0x22 / 255, 0xaa / 255, 0xff / 255}
  
  -- Create Number Buttons (1-16)
  local number_buttons = {}
  for i = 1, 16 do
    local is_highlight = (i == 1 or i == 5 or i == 9 or i == 13)
    number_buttons[i] = vb:button {
      text = string.format("%02d", i),
      width = 30,
      color = is_highlight and highlight_color or normal_color,
      notifier = function() end,
      active = false
    }
  end
  
  -- Create Checkboxes (1-16)
  local checkboxes = {}
  for i = 1, 16 do
    checkboxes[i] = vb:checkbox {
      value = false,
      width = 30,
      notifier = function()
        if not row_elements.updating_checkboxes then
          row_elements.print_to_pattern()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      end
    }
  end
  
  -- Track Popup
  local track_popup = vb:popup {
    items = track_names,
    value = row_prefs.track_value or row_index,
    notifier = function(value)
      row_prefs.track_value = value
      row_elements.initialize_row()
    end
  }
  
  -- Mute Checkbox
  local mute_checkbox = vb:checkbox {
    value = false,
    notifier = function(value)
      row_prefs.mute_value = value
      local track_index = track_indices[track_popup.value]
      local track = renoise.song().tracks[track_index]
      track.mute_state = value and renoise.Track.MUTE_STATE_MUTED or renoise.Track.MUTE_STATE_ACTIVE
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }
  
  -- Valuebox for Steps
  local valuebox = vb:valuebox {
    min = 1,
    max = 16,
    value = 16,
    width = 50,
    notifier = function(value)
      if not row_elements.updating_steps then
        row_elements.print_to_pattern()
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    end
  }
  
  -- Slider for Sample Selection
  local slider = vb:slider {
    min = 1,
    max = 120,
    value = 1,
    width = 130,
    notifier = function(value)
      local instrument_index = row_elements.instrument_popup.value
      renoise.song().selected_instrument_index = instrument_index
      if type(midi_sample_velocity_switcharoo) == "function" then
        midi_sample_velocity_switcharoo(value)
      end
      row_elements.update_sample_name_label()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
  }
  
  -- Sample Name Label
  local sample_name_label = vb:text {
    text = "Sample Name",
    font = "bold",
    style = "strong"
  }
  
  -- Instrument Popup
  local instrument_popup = vb:popup {
    items = instrument_names,
    value = row_prefs.instrument_value or row_index,
    width = 150,
    notifier = function(value)
      row_prefs.instrument_value = value
      row_elements.print_to_pattern()
      row_elements.update_sample_name_label()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
  }
  
  -- Function to Print to Pattern
  local function print_to_pattern()
    local song = renoise.song()
    local pattern = song.selected_pattern
    local pattern_length = pattern.number_of_lines
    local steps = valuebox.value
    local track_index = track_indices[track_popup.value]
    local instrument_index = instrument_popup.value
    local track_in_pattern = pattern.tracks[track_index]
    
    for line = 1, steps do
      local checkbox_value = checkboxes[line].value
      local note_line = track_in_pattern:line(line).note_columns[1]
      if checkbox_value then
        note_line.note_string = "C-4"
        note_line.instrument_value = instrument_index - 1
      else
        note_line:clear()
      end
    end
    
    for line = steps + 1, pattern_length do
      local source_line_index = ((line - 1) % steps) + 1
      local source_note_line = track_in_pattern:line(source_line_index).note_columns[1]
      local dest_note_line = track_in_pattern:line(line).note_columns[1]
      dest_note_line:copy_from(source_note_line)
    end
  end
  
  -- Function to Update Sample Name Label
  local function update_sample_name_label()
    local instrument = renoise.song().instruments[instrument_popup.value]
    local sample_name = "No valid sample selected"
    if instrument and #instrument.samples > 0 then
      for _, sample in ipairs(instrument.samples) do
        local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
        local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
        if velocity_min == 0x00 and velocity_max == 0x7F then
          sample_name = sample.name ~= "" and sample.name or "Sample " .. sample.index
          break
        end
      end
    end
    sample_name_label.text = sample_name
  end
  
  -- Function to Initialize Row
  local function initialize_row()
    local track_index = track_indices[track_popup.value]
    local track = renoise.song().tracks[track_index]
    local pattern = renoise.song().selected_pattern
    local line_count = pattern.number_of_lines
    row_elements.updating_checkboxes = true
    
    for i = 1, 16 do
      checkboxes[i].active = false
      checkboxes[i].value = false
    end
    
    for line = 1, math.min(line_count, 16) do
      local note_line = pattern.tracks[track_index].lines[line].note_columns[1]
      if note_line and note_line.note_string == "C-4" then
        checkboxes[line].value = true
      end
    end
    
    local mute = track.mute_state == renoise.Track.MUTE_STATE_MUTED
    mute_checkbox.value = mute
    
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
      instrument_popup.value = 1
    end
    
    update_sample_name_label()
    row_elements.updating_checkboxes = false
    
    for i = 1, 16 do
      checkboxes[i].active = true
    end
  end
  
  -- Function to Browse Instrument
  local function browse_instrument()
    local track_popup_value = track_popup.value
    local instrument_popup_value = instrument_popup.value
    local track_index = track_indices[track_popup_value]
    local instrument_index = instrument_popup_value
    renoise.song().selected_track_index = track_index
    renoise.song().selected_instrument_index = instrument_index
    
    if type(pitchBendDrumkitLoader) == "function" then
      pitchBendDrumkitLoader()
    else
      renoise.app():show_warning("pitchBendDrumkitLoader function is not defined.")
    end
    
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
      renoise.song().tracks[track_index].name = instrument.name ~= "" and instrument.name or "Instrument " .. instrument_index
      renoise.app():show_status("Track " .. track_index .. " renamed to '" .. (instrument.name ~= "" and instrument.name or "Instrument " .. instrument_index) .. "'.")
    else
      renoise.app():show_warning("Selected track does not exist.")
    end
    
    local selected_device = renoise.song().selected_device
    if selected_device and instrument and #instrument.samples > 0 then
      selected_device.display_name = "8120_row" .. row_index
      renoise.app():show_status("Selected device renamed to '8120_row" .. row_index .. "'.")
    else
      renoise.app():show_status("No valid device loaded; device not renamed.")
    end
    
    update_instrument_list_and_popups()
    slider.value = 1
    
    if type(pakettiSampleVelocityRangeChoke) == "function" then
      pakettiSampleVelocityRangeChoke(1)
    end
    
    update_sample_name_label()
    row_elements.random_button_pressed = random_button_pressed
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  -- Function to Refresh Instruments
  local function refresh_instruments()
    update_instrument_list_and_popups()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  -- Function to Select Instrument
  local function select_instrument()
    renoise.song().selected_instrument_index = instrument_popup.value
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  -- Function for Random Button Pressed
  local function random_button_pressed()
    row_elements.updating_checkboxes = true
    local instrument_index = row_elements.instrument_popup.value
    renoise.song().selected_instrument_index = instrument_index
    
    if type(sample_random) == "function" then
      sample_random()
    end
    
    local instrument = renoise.song().instruments[instrument_index]
    for sample_index, sample in ipairs(instrument.samples) do
      if sample.sample_mapping.note_range[1] == 0 and sample.sample_mapping.note_range[2] == 127 then
        slider.value = sample_index
        break
      end
    end
    
    update_sample_name_label()
    renoise.song().selected_track_index = 1
    row_elements.updating_checkboxes = false
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  -- Function to Randomize Steps
  local function randomize()
    row_elements.updating_checkboxes = true
    for i = 1, 16 do
      checkboxes[i].value = math.random() >= 0.5
    end
    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
  end
  
  -- Function to Show Automation
  local function show_automation()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    renoise.song().selected_track_index = row_index
    renoise.song().selected_device_index = 2
    renoise.app():show_status("Showing Automation for Row " .. row_index)
  end
  
  -- Define select_instrument function
  local function select_instrument()
    renoise.song().selected_instrument_index = instrument_popup.value
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  -- Assign select_instrument to row_elements
  row_elements.select_instrument = select_instrument
  
  -- Define the Reverse Button with Corrected Notifier
  local reverse_button = vb:button {
    text = "Reverse",
    notifier = function()
      row_elements.select_instrument(); 
      reverse_sample(row_elements)
    end
  }
  
  -- Define the Row Column Layout
  local row = vb:column {
    vb:row(number_buttons),
    vb:row {
      checkboxes[1], checkboxes[2], checkboxes[3], checkboxes[4],
      checkboxes[5], checkboxes[6], checkboxes[7], checkboxes[8],
      checkboxes[9], checkboxes[10], checkboxes[11], checkboxes[12],
      checkboxes[13], checkboxes[14], checkboxes[15], checkboxes[16],
      valuebox, sample_name_label
    },
    vb:row {
      vb:button {
        text = "<",
        notifier = function()
          row_elements.updating_checkboxes = true
          local first_value = checkboxes[1].value
          for i = 1, 15 do
            checkboxes[i].value = checkboxes[i + 1].value
          end
          checkboxes[16].value = first_value
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button {
        text = ">",
        notifier = function()
          row_elements.updating_checkboxes = true
          local last_value = checkboxes[16].value
          for i = 16, 2, -1 do
            checkboxes[i].value = checkboxes[i - 1].value
          end
          checkboxes[1].value = last_value
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button {
        text = "Clear",
        notifier = function()
          row_elements.updating_checkboxes = true
          for i = 1, 16 do
            checkboxes[i].value = false
          end
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          renoise.app():show_status("Wiped all steps of row " .. row_index .. ".")
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button {
        text = "Randomize",
        notifier = function()
          row_elements.updating_checkboxes = true
          for i = 1, 16 do
            checkboxes[i].value = math.random() >= 0.5
          end
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          renoise.app():show_status("Randomized steps of row " .. row_index .. ".")
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      track_popup,
      vb:row {
        mute_checkbox,
        vb:text {text = "Mute", font = "bold", style = "strong", width = 30}
      },
      instrument_popup,
      vb:button {text = "Browse", notifier = browse_instrument},
      vb:button {text = "Refresh", notifier = refresh_instruments},
      vb:button {text = "Show", notifier = select_instrument},
      slider,
      vb:button {text = "Random", notifier = random_button_pressed},
      vb:button {text = "Show Automation", notifier = show_automation},
      reverse_button -- Add the Reverse button here
    }
  }
  
  -- Assign Elements to row_elements Table
  row_elements.checkboxes = checkboxes
  row_elements.valuebox = valuebox
  row_elements.slider = slider
  row_elements.track_popup = track_popup
  row_elements.instrument_popup = instrument_popup
  row_elements.mute_checkbox = mute_checkbox
  
  -- Assign Functions to row_elements Table
  row_elements.initialize_row = initialize_row
  row_elements.print_to_pattern = print_to_pattern
  row_elements.update_sample_name_label = update_sample_name_label
  row_elements.randomize = randomize
  row_elements.random_button_pressed = random_button_pressed
  
  -- Initialize the Row
  row_elements.initialize_row()
  
  return row, row_elements
end

local function update_bpm()
  local random_bpm = math.random(20, 300)
  renoise.song().transport.bpm = random_bpm
  bpm_display.text = "BPM: " .. tostring(random_bpm)
  renoise.app():show_status("BPM set to " .. random_bpm)
end

function create_global_controls()
  play_checkbox = vb:checkbox {value = renoise.song().transport.playing, midi_mapping = "Paketti:Paketti Groovebox 8120:Play Control", notifier = function(value)
    if value then
      renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
    else
      renoise.song().transport:stop()
    end
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  follow_checkbox = vb:checkbox {value = renoise.song().transport.follow_player, notifier = function(value)
    renoise.song().transport.follow_player = value
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  groove_enabled_checkbox = vb:checkbox {value = renoise.song().transport.groove_enabled, notifier = function(value)
    renoise.song().transport.groove_enabled = value
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
  end}
  bpm_display=vb:button{text="BPM: " .. tostring(renoise.song().transport.bpm),width=60,notifier=update_bpm}
    
  local function increase_bpm()
    local new_bpm = renoise.song().transport.bpm + 1
    if new_bpm > 999 then new_bpm = 999 end
    renoise.song().transport.bpm = new_bpm
    bpm_display.text = "BPM: " .. tostring(renoise.song().transport.bpm)
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local function decrease_bpm()
    local new_bpm = renoise.song().transport.bpm - 1
    if new_bpm < 20 then new_bpm = 20 end
    renoise.song().transport.bpm = new_bpm
    bpm_display.text = "BPM: " .. tostring(renoise.song().transport.bpm)
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local function divide_bpm()
    local new_bpm = math.floor(renoise.song().transport.bpm / 2)
    if new_bpm < 20 then new_bpm = 20 end
    renoise.song().transport.bpm = new_bpm
    bpm_display.text = "BPM: " .. tostring(renoise.song().transport.bpm)
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local function multiply_bpm()
    local new_bpm = renoise.song().transport.bpm * 2
    if new_bpm > 999 then new_bpm = 999 end
    renoise.song().transport.bpm = new_bpm
    bpm_display.text = "BPM: " .. tostring(renoise.song().transport.bpm)
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local local_groove_sliders, local_groove_labels, groove_controls = {}, {}, vb:row {}
  for i = 1, 4 do
    local groove_value = renoise.song().transport.groove_amounts[i] or 0
    local_groove_labels[i] = vb:text {text = string.format("%d%%", groove_value * 100), width = 30}
    local_groove_sliders[i] = vb:slider {min = 0.0, max = 1.0, value = groove_value, width = 100, notifier = function(value)
      local_groove_labels[i].text = string.format("%d%%", value * 100)
      local groove_values = {}
      for j = 1, 4 do
        groove_values[j] = local_groove_sliders[j].value
      end
      renoise.song().transport.groove_amounts = groove_values
      renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
    end}
    groove_controls:add_child(vb:row {local_groove_sliders[i], local_groove_labels[i]})
  end
  
  local function randomize_groove()
    local groove_values = {}
    for i = 1, 4 do
      local random_value = math.random()
      local_groove_sliders[i].value = random_value
      local_groove_labels[i].text = string.format("%d%%", random_value * 100)
      groove_values[i] = random_value
    end
    renoise.song().transport.groove_amounts = groove_values
    renoise.song().transport.groove_enabled = true
    renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
  end
  
  random_gate_button = vb:button{ text="Random Gate", midi_mapping="Paketti:Paketti Groovebox 8120:Random Gate", notifier=function()
    random_gate()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  
  fill_empty_label = vb:text{ text="Fill Empty Steps: 0%", width=90 }
  fill_empty_slider = vb:slider {min = 0, max = 100, value = 0, width = 150, notifier = function(value)
    fill_empty_label.text = "Fill Empty Steps: " .. tostring(math.floor(value)) .. "%"
    if value == 0 then
      for _, row_elements in ipairs(rows) do
        row_elements.updating_checkboxes = true
        for i = 1, 16 do
          row_elements.checkboxes[i].value = false
        end
        row_elements.updating_checkboxes = false
        row_elements.print_to_pattern()
      end
      renoise.app():show_status("Wiped all steps of each row.")
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    else
      fill_empty_steps(value / 100)
      renoise.app():show_status("Filled empty steps with " .. tostring(math.floor(value)) .. "% probability.")
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  end}
  
  local function clear_all()
    for _, row_elements in ipairs(rows) do
      row_elements.updating_checkboxes = true
      local checkboxes = row_elements.checkboxes
      for i = 1, 16 do
        checkboxes[i].value = false
      end
      row_elements.updating_checkboxes = false
      row_elements.print_to_pattern()
    end
    renoise.app():show_status("Wiped all steps of each row.")
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local function random_fill()
    for _, row_elements in ipairs(rows) do
      row_elements.updating_checkboxes = true
      local random_steps = math.random(1, 16)
      row_elements.updating_steps = true
      row_elements.valuebox.value = random_steps
      row_elements.updating_steps = false
      local checkboxes = row_elements.checkboxes
      for i = 1, 16 do
        checkboxes[i].value = false
      end
      for i = 1, random_steps do
        local rand_index = math.random(1, 16)
        checkboxes[rand_index].value = true
      end
      row_elements.updating_checkboxes = false
      row_elements.print_to_pattern()
    end
    renoise.app():show_status("Randomly filled each row, and set step values for each instrument.")
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local function fetch_pattern()
    for _, row_elements in ipairs(rows) do
      for _, checkbox in ipairs(row_elements.checkboxes) do
        checkbox.active = false
      end
    end
    for i, row_elements in ipairs(rows) do
      local track_index = track_indices[row_elements.track_popup.value]
      local pattern = renoise.song().selected_pattern
      local line_count = pattern.number_of_lines
      local instrument_used = nil
      row_elements.updating_checkboxes = true
      for line = 1, math.min(line_count, 16) do
        local note_line = pattern.tracks[track_index].lines[line].note_columns[1]
        if note_line and note_line.note_string == "C-4" then
          row_elements.checkboxes[line].value = true
          if not instrument_used and not note_line.is_empty then
            instrument_used = note_line.instrument_value
          end
        else
          row_elements.checkboxes[line].value = false
        end
      end
      if instrument_used then
        row_elements.instrument_popup.value = instrument_used + 1
        renoise.song().selected_instrument_index = row_elements.instrument_popup.value
      end
      row_elements.print_to_pattern()
      row_elements.updating_checkboxes = false
    end
    for _, row_elements in ipairs(rows) do
      for _, checkbox in ipairs(row_elements.checkboxes) do
        checkbox.active = true
      end
    end
    renoise.app():show_status("Pattern fetched successfully.")
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local function random_all()
    for _, row_elements in ipairs(rows) do
      if row_elements.random_button_pressed then
        row_elements.random_button_pressed()
      else
        renoise.app():show_status("Error: random_button_pressed not found for a row.")
      end
    end
    renoise.app():show_status("Each Instrument Bank now has a Random Selected Sample.")
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  local function randomize_all()
    for _, row_elements in ipairs(rows) do
      row_elements.randomize()
    end
    renoise.app():show_status("Each Instrument Row step content has now been randomized.")
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
  
  local reverse_all_button = vb:button {text = "Reverse All", notifier = reverse_all}
  
  local global_controls = vb:column {
    vb:row {
      play_checkbox, vb:text {text = "Play", font = "bold", style = "strong", width = 30},
      follow_checkbox, vb:text {text = "Follow", font = "bold", style = "strong", width = 50},
      vb:button {text = "/2", notifier = divide_bpm},
      vb:button {text = "-", notifier = decrease_bpm},
      bpm_display,
      vb:button {text = "+", notifier = increase_bpm},
      vb:button {text = "*2", notifier = multiply_bpm},
      vb:button {text = "Clear All", notifier = clear_all},
      vb:button {text = "Random Fill", midi_mapping="Paketti:Paketti Groovebox 8120:Random Fill", notifier = random_fill},
      random_gate_button,
      vb:button {text = "Fetch", notifier = fetch_pattern},
      fill_empty_label,
      fill_empty_slider,
      vb:button {text = "Random All", notifier = random_all},
      vb:button {text = "Randomize All", notifier = randomize_all},
      reverse_all_button
    }
  }
  
  local global_groove_controls = vb:row {
    groove_enabled_checkbox, vb:text {text = "Global Groove", font = "bold", style = "strong", width = 100},
    groove_controls, vb:button {text = "Random Groove", midi_mapping="Paketti:Paketti Groovebox 8120:Random Groove", notifier = randomize_groove}
  }
  
  return global_controls, global_groove_controls, global_step_buttons
end

local function PakettiEightSlotsByOneTwentyDialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end
  track_names, track_indices, instrument_names = {}, {}, {}
  for i, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(track_names, track.name)
      table.insert(track_indices, i)
    end
  end
  for i, instr in ipairs(renoise.song().instruments) do
    table.insert(instrument_names, instr.name ~= "" and instr.name or "Instrument " .. i)
  end
  local global_controls, global_groove_controls, global_step_buttons = create_global_controls()
  local dc = vb:column {global_controls, global_groove_controls, global_step_buttons}
  for i = 1, 8 do
    local row, elements = PakettiEightSlotsByOneTwentyCreateRow(i)
    dc:add_child(row)
    rows[i] = elements
  end
  dc:add_child(vb:button {text = "Run Debug", notifier = function()
    debug_instruments_and_samples()
    renoise.app():show_status("Debug information printed to console.")
  end})
  dc:add_child(vb:button {text = "Print to Pattern", notifier = function()
    for i, elements in ipairs(rows) do
      elements.print_to_pattern()
    end
    renoise.app():show_status("Pattern updated successfully.")
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end})
  for _, row_elements in ipairs(rows) do
    row_elements.update_sample_name_label()
  end
  debug_instruments_and_samples()
  dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120", dc, PakettiEightSlotsByOneTwentyKeyHandler)
end

local function assign_midi_mappings()
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Increase BPM", invoke = function(message)
    if message:is_trigger() then increase_bpm() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Decrease BPM", invoke = function(message)
    if message:is_trigger() then decrease_bpm() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Divide BPM by 2", invoke = function(message)
    if message:is_trigger() then divide_bpm() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Multiply BPM by 2", invoke = function(message)
    if message:is_trigger() then multiply_bpm() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Play Toggle", invoke = function(message)
    if message:is_trigger() then play_checkbox.value = not play_checkbox.value end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Follow Toggle", invoke = function(message)
    if message:is_trigger() then follow_checkbox.value = not follow_checkbox.value end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Clear All", invoke = function(message)
    if message:is_trigger() then clear_all() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Random Fill", invoke = function(message)
    if message:is_trigger() then random_fill() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Random Gate", invoke = function(message)
    if message:is_trigger() then random_gate() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Fetch Pattern", invoke = function(message)
    if message:is_trigger() then fetch_pattern() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Fill Empty Steps Slider", invoke = function(message)
    if message:is_trigger() then
      local new_value = fill_empty_slider.value + 10
      if new_value > 100 then new_value = 100 end
      fill_empty_slider.value = new_value
    end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Random All", invoke = function(message)
    if message:is_trigger() then random_all() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Randomize All", invoke = function(message)
    if message:is_trigger() then randomize_all() end
  end}
  local step_button_names = {"1", "2", "4", "6", "8", "12", "16", "<<", ">>"}
  for _, step in ipairs(step_button_names) do
    renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Global Step " .. step, invoke = function(message)
      if message:is_trigger() then
        if step == "<<" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            local first_value = row_elements.checkboxes[1].value
            for i = 1, 15 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
            end
            row_elements.checkboxes[16].value = first_value
            row_elements.print_to_pattern()
          end
          renoise.app():show_status("All steps shifted to the left.")
        elseif step == ">>" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            local last_value = row_elements.checkboxes[16].value
            for i = 16, 2, -1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
            end
            row_elements.checkboxes[1].value = last_value
            row_elements.print_to_pattern()
          end
          renoise.app():show_status("All steps shifted to the right.")
        else
          set_global_steps(tonumber(step))
        end
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    end}
  end
  for row = 1, 8 do
    for step = 1, 16 do
      renoise.tool():add_midi_mapping {name = string.format("Paketti:Paketti Groovebox 8120:Row%d Step%d", row, step), invoke = function(message)
        if message:is_trigger() then
          local row_elements = rows[row]
          if row_elements and row_elements.checkboxes[step] then
            row_elements.checkboxes[step].value = not row_elements.checkboxes[step].value
          end
        end
      end}
    end
    local buttons = {"<", ">", "Clear", "Randomize", "Browse", "Show", "Random", "Show Automation", "Reverse"}
    for _, btn in ipairs(buttons) do
      renoise.tool():add_midi_mapping {name = string.format("Paketti:Paketti Groovebox 8120:Row%d %s", row, btn), invoke = function(message)
        if message:is_trigger() then
          local row_elements = rows[row]
          if row_elements then
            if btn == "<" then
              row_elements.updating_checkboxes = true
              local first_value = row_elements.checkboxes[1].value
              for i = 1, 15 do
                row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
              end
              row_elements.checkboxes[16].value = first_value
              row_elements.print_to_pattern()
              row_elements.updating_checkboxes = false
              renoise.app():show_status(string.format("Row %d: Steps shifted left.", row))
            elseif btn == ">" then
              row_elements.updating_checkboxes = true
              local last_value = row_elements.checkboxes[16].value
              for i = 16, 2, -1 do
                row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
              end
              row_elements.checkboxes[1].value = last_value
              row_elements.print_to_pattern()
              row_elements.updating_checkboxes = false
              renoise.app():show_status(string.format("Row %d: Steps shifted right.", row))
            elseif btn == "Clear" then
              row_elements.updating_checkboxes = true
              for i = 1, 16 do
                row_elements.checkboxes[i].value = false
              end
              row_elements.updating_checkboxes = false
              row_elements.print_to_pattern()
              renoise.app():show_status(string.format("Row %d: All steps cleared.", row))
            elseif btn == "Randomize" then
              row_elements.updating_checkboxes = true
              for i = 1, 16 do
                row_elements.checkboxes[i].value = math.random() >= 0.5
              end
              row_elements.updating_checkboxes = false
              row_elements.print_to_pattern()
              renoise.app():show_status(string.format("Row %d: Steps randomized.", row))
            elseif btn == "Browse" then
              row_elements.browse_instrument()
            elseif btn == "Show" then
              row_elements.select_instrument()
            elseif btn == "Random" then
              row_elements.random_button_pressed()
            elseif btn == "Show Automation" then
              row_elements.show_automation()
            elseif btn == "Reverse" then
              reverse_sample(row_elements)
            end
          end
        end
      end}
    end
  end
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Random Groove", invoke = function(message)
    if message:is_trigger() then randomize_groove() end
  end}
  renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120:Reverse All", invoke = function(message)
    if message:is_trigger() then reverse_all() end
  end}
end

assign_midi_mappings()

renoise.tool():add_keybinding {name = "Global:Paketti:Paketti Groovebox 8120", invoke = function()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    rows = {}
  else PakettiEightSlotsByOneTwentyDialog() end end}

renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti..:Paketti Groovebox 8120", invoke = function()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    rows = {}
  else PakettiEightSlotsByOneTwentyDialog() end end}

renoise.tool():add_midi_mapping {name = "Paketti:Paketti Groovebox 8120", invoke = function(message)
  if message:is_trigger() then
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
      rows = {}
    else PakettiEightSlotsByOneTwentyDialog() end end end}
