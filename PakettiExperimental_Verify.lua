-------
-- Function to ensure EQ10 exists on selected track and return its index
local function ensure_eq10_exists()
  local song=renoise.song()
  local track = song.selected_track
  
  -- First check if EQ10 already exists
  for i, device in ipairs(track.devices) do
    if device.name == "EQ 10" then
      -- Show the device in DSP chain
      device.is_maximized = true
      return i
    end
  end
  
  -- If not found, add EQ10 after the track volume device
  loadnative("Audio/Effects/Native/EQ 10")
  
  -- Find the newly added EQ10
  for i, device in ipairs(track.devices) do
    if device.name == "EQ 10" then
      device.is_maximized = true
      return i
    end
  end
  
  return nil
end

-- Function to get current EQ10 parameters
local function get_eq10_params(device)
  local params = {}
  for i = 1, 10 do
    params[i] = {
      gain = device.parameters[i].value,              -- Gains are parameters 1-10
      freq = device.parameters[i + 10].value,         -- Frequencies are parameters 11-20
      bandwidth=device.parameters[i + 20].value     -- Bandwidths are parameters 21-30
    }
  end
  return params
end

-- Function to normalize gain value to 0-1 range
local function normalize_gain(gain)
  -- EQ10 gain range is -12 to +12
  local normalized = (gain + 12) / 24
  -- Ensure value is between 0 and 1
  return math.max(0, math.min(1, normalized))
end

-- Global dialog reference for EQ10 XY toggle behavior
local dialog = nil

-- Function to create the EQ10 dialog
function pakettiEQ10XYDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Ensure EQ10 exists and get its index
  local eq10_index = ensure_eq10_exists()
  local eq10_device = renoise.song().selected_track.devices[eq10_index]
  
  -- Create single row of XY pads
  local content = vb:column{
    margin=5,
    --spacing=5
  }
  
  -- Create the single row for all XY pads
  local row_content = vb:row{
    margin=5,
   -- spacing=10
  }
  
  -- Add all 10 bands
  for band_idx = 1, 10 do
    -- Parameter indices for this band
    local gain_idx = band_idx           -- Gains are parameters 1-10
    local freq_idx = band_idx + 10      -- Frequencies are parameters 11-20
    local bw_idx = band_idx + 20        -- Bandwidths are parameters 21-30
    
    -- Get current values
    local gain_param = eq10_device.parameters[gain_idx]
    local freq_param = eq10_device.parameters[freq_idx]
    local bw_param = eq10_device.parameters[bw_idx]
    
    -- Calculate normalized values
    local x_value = (freq_param.value - freq_param.value_min) / 
                   (freq_param.value_max - freq_param.value_min)
    local y_value = normalize_gain(gain_param.value)
    
    local band_group = vb:column{
      margin=2,
      vb:text{text=string.format("Band %d", band_idx) },
      vb:xypad{
        id = string.format("xy_band_%d", band_idx),
        width=80,
        height = 80,
        value = { x = x_value, y = y_value },
        notifier=function(value)
          -- Update frequency (X axis)
          local new_freq = freq_param.value_min + 
                         value.x * (freq_param.value_max - freq_param.value_min)
          freq_param.value = new_freq
          
          -- Update gain and bandwidth (Y axis)
          local gain = (value.y * 24) - 12
          gain_param.value = gain
          
          -- Adjust bandwidth based on gain (higher bandwidth when further from center)
          -- Scale to 0.0001 to 1 range
          local bw_factor = math.abs(gain) / 12  -- 0 to 1 based on gain
          local new_bw = 0.0001 + (bw_factor * 0.9999)  -- Scale to valid range
          bw_param.value = new_bw
        end
      }
    }
    row_content:add_child(band_group)
  end
  
  content:add_child(row_content)
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("EQ10 XY Control",content,keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Show EQ10 XY Control Dialog...",invoke = pakettiEQ10XYDialog}
-----
if preferences.SelectedSampleBeatSyncLines.value == true then 
  for i=1,512 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Lines to " .. i,invoke=function()SelectedSampleBeatSyncLine(i)end}
  end 
end
------------------------
local vb = renoise.ViewBuilder()
local dialog = nil
local dialog_content = nil

local function update_sample_volumes(x, y)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples < 4 then
    renoise.app():show_status("Selected instrument must have at least 4 samples.")
    return
  end

  -- Calculate volumes based on the x, y position of the xypad
  local volumes = {
    (1 - x) * y, -- Top-left (Sample 1)
    x * y,       -- Top-right (Sample 2)
    (1 - x) * (1 - y), -- Bottom-left (Sample 3)
    x * (1 - y)  -- Bottom-right (Sample 4)
  }

  -- Normalize volumes to range 0.0 - 1.0
  for i, volume in ipairs(volumes) do
    instrument.samples[i].volume = math.min(1.0, math.max(0.0, volume))
  end

  renoise.app():show_status(
    ("Sample volumes updated: S1=%.2f, S2=%.2f, S3=%.2f, S4=%.2f"):
    format(volumes[1], volumes[2], volumes[3], volumes[4])
  )
end

dialog_content = vb:column{
  vb:xypad{width=200,height=200,value={x=0.5,y=0.5},
    notifier=function(value)
      update_sample_volumes(value.x, value.y)
    end
  }
}

function showXyPaddialog()
  if dialog and dialog.visible then
    dialog:close()
  else
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("XY Pad Sound Mixer", dialog_content, keyhandler)
  end
end

--

local vb = renoise.ViewBuilder()
local dialog = nil
local monitoring_enabled = false -- Tracks the monitoring state
local active = false

-- Tracks all SB0/SBX pairs in the Master Track
local loop_pairs = {}

-- Scan the Master Track for all SB0/SBX pairs

function analyze_loops()
  if not renoise.song() then
    return false
  end
  local song=renoise.song()
  local master_track_index = renoise.song().sequencer_track_count + 1
  local master_track = song.selected_pattern.tracks[master_track_index]
  loop_pairs = {}

  for line_idx, line in ipairs(master_track.lines) do
    if #line.effect_columns > 0 then
      local col = line.effect_columns[1]
      if col.number_string == "0S" then
        local parameter = col.amount_value - 176 -- Decode by subtracting `B0`

        if parameter == 0 then
          -- Found SB0 (start)
          table.insert(loop_pairs, {start_line = line_idx, end_line = nil, repeat_count = 0, max_repeats = 0})
        elseif parameter >= 1 and parameter <= 15 then
          -- Found SBX (end) for the last SB0
          local last_pair = loop_pairs[#loop_pairs]
          if last_pair and not last_pair.end_line then
            last_pair.end_line = line_idx
            last_pair.max_repeats = parameter
          end
        end
      end
    end
  end

  if #loop_pairs == 0 then
    print("Error: No valid SB0/SBX pairs found in the Master Track.")
    return false
  end

  print("Detected SB0/SBX pairs in Master Track:")
  for i, pair in ipairs(loop_pairs) do
    print("Pair " .. i .. ": Start=" .. pair.start_line .. ", End=" .. pair.end_line .. ", Max Repeats=" .. pair.max_repeats)
  end

  return true
end

-- Playback Monitoring Function
local function monitor_playback()
  local song=renoise.song()
  local play_pos = song.transport.playback_pos
  local current_line = play_pos.line
  local max_row = renoise.song().selected_pattern.number_of_lines - 1 -- Last row in the pattern

  -- Reset all repeat counts at the end of the pattern
  if current_line == max_row then
    for _, pair in ipairs(loop_pairs) do
      pair.repeat_count = 0
    end
    print("Resetting all repeat counts at the end of the pattern.")
    return
  end

  -- Handle looping logic for each pair
  for i, pair in ipairs(loop_pairs) do
    if current_line == pair.end_line then
      if pair.repeat_count < pair.max_repeats then
        pair.repeat_count = pair.repeat_count + 1
        print("Pair " .. i .. ": Looping back to SB0 (line " .. pair.start_line .. "). Repeat count: " .. pair.repeat_count)
        song.transport.playback_pos = renoise.SongPos(play_pos.sequence, pair.start_line)
        return
      else
        print("Pair " .. i .. ": Completed all repeats for this iteration.")
      end
    end
  end
end
--]]
-- Global Reset Function
function reset_repeat_counts()
  if not monitoring_enabled then
    print("Monitoring is disabled. Reset operation skipped.")
    return
  end

  print("Checking Master Track for SB0/SBX pairs...")
  if not analyze_loops() then
    print("No valid SB0/SBX pairs found in the Master Track. Reset operation aborted.")
    return
  end

  for i, pair in ipairs(loop_pairs) do
    pair.repeat_count = 0
    print("Reset Pair " .. i .. ": Start=" .. pair.start_line .. ", End=" .. pair.end_line .. ", Max Repeats=" .. pair.max_repeats)
  end

  print("All repeat counts reset to 0. Monitoring restarted.")
  InitSBx() -- Reinitialize SBX monitoring
end

-- Initialize SBX Monitoring
function InitSBx()
  if monitoring_enabled then
    print("Monitoring is enabled. Checking Master Track for SBX...")
    if not analyze_loops() then
      print("No valid SBX commands found in the Master Track. Monitoring will not start.")
      return
    end
    if not active then
      renoise.tool().app_idle_observable:add_notifier(monitor_playback)
      print("SBX Monitoring started.")
      active = true
    end
  else
    print("Monitoring is disabled. SBX initialization skipped.")
  end
end

-- Enable Monitoring
local function enable_monitoring()
  monitoring_enabled = true
  InitSBx()
end

-- Disable Monitoring
local function disable_monitoring()
  monitoring_enabled = false
  if active and renoise.tool().app_idle_observable:has_notifier(monitor_playback) then
    renoise.tool().app_idle_observable:remove_notifier(monitor_playback)
    print("SBX Monitoring stopped.")
    active = false
  end
end

-- GUI for Triggering the Script
function showSBX_dialog()
  if dialog and dialog.visible then dialog:close() return end
  local content = vb:column{
    margin=10,
    vb:text{text="Trigger SBX Loop Handler" },
    vb:button{
      text="Enable Monitoring",
      released = function()
        enable_monitoring()
      end
    },
    vb:button{
      text="Disable Monitoring",
      released = function()
        disable_monitoring()
      end
    }
  }
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("SBX Playback Handler", content, keyhandler)
end


renoise.tool():add_keybinding{name="Global:Transport:Reset SBx and Start Playback",
  invoke=function() reset_repeat_counts() renoise.song().transport:start() end}

-- Tool Initialization
  monitoring_enabled = true
--InitSBx()

function crossfade_loop(crossfade_length)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- User-adjustable fade length for loop start/end fades
  local fade_length = 20

  -- Check for an active instrument
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  -- Check for an active sample
  local sample = instrument:sample(1)
  if not sample then
    renoise.app():show_status("No sample available.")
    return
  end

  -- Check if sample has data and looping is enabled
  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then
    renoise.app():show_status("Sample has no data.")
    return
  end

  if sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
    renoise.app():show_status("Loop mode is off.")
    return
  end

  local loop_start = sample.loop_start
  local loop_end = sample.loop_end
  local num_frames = sample_buffer.number_of_frames

  -- Validate frame ranges for crossfade and fade operations
  if loop_start <= crossfade_length + fade_length then
    renoise.app():show_status("Not enough frames before loop_start for crossfade and fades.")
    return
  end

  if loop_end <= crossfade_length + fade_length then
    renoise.app():show_status("Not enough frames before loop_end for crossfade and fades.")
    return
  end

  if loop_start + fade_length - 1 > num_frames then
    renoise.app():show_status("Not enough frames after loop_start for fade-in.")
    return
  end

  if loop_end - fade_length < 1 then
    renoise.app():show_status("Not enough frames before loop_end for fade-out.")
    return
  end

  -- Define crossfade regions:
  -- a-b (fade-in region) is before loop_start
  local fade_in_start = loop_start - crossfade_length
  local fade_in_end = loop_start - 1

  -- c-d (fade-out region) is before loop_end
  local fade_out_start = loop_end - crossfade_length
  local fade_out_end = loop_end - 1

  -- Prepare sample data changes
  sample_buffer:prepare_sample_data_changes()

  ---------------------------------------------------
  -- Crossfade: Mix a-b region into c-d region
  ---------------------------------------------------
  for i = 0, crossfade_length - 1 do
    local fade_in_pos = fade_in_start + i
    local fade_out_pos = fade_out_start + i

    -- Fade ratios: fade_in ramps 0->1, fade_out ramps 1->0
    local fade_in_ratio = i / (crossfade_length - 1)
    local fade_out_ratio = 1 - fade_in_ratio

    for c = 1, sample_buffer.number_of_channels do
      local fade_in_val = sample_buffer:sample_data(c, fade_in_pos)
      local fade_out_val = sample_buffer:sample_data(c, fade_out_pos)

      -- Blend the two segments
      local blended_val = (fade_in_val * fade_in_ratio) + (fade_out_val * fade_out_ratio)

      -- Write the blended value back to the fade_out region (c-d)
      sample_buffer:set_sample_data(c, fade_out_pos, blended_val)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-out at loop_end
  -- Ensures silence right at loop_end
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_end - fade_length + i
    local fade_ratio = 1 - (i / (fade_length - 1))
    for c = 1, sample_buffer.number_of_channels do
      local sample_val = sample_buffer:sample_data(c, pos)
      sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-in at loop_start
  -- Ensures sound ramps up from silence at loop_start
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_start + i
    local fade_ratio = i / (fade_length - 1)
    for c = 1, sample_buffer.number_of_channels do
      local sample_val = sample_buffer:sample_data(c, pos)
      sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-out before loop_start
  -- Ensures silence leading into the loop_start region
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_start - fade_length + i
    if pos >= 1 and pos <= num_frames then
      local fade_ratio = 1 - (i / (fade_length - 1))
      for c = 1, sample_buffer.number_of_channels do
        local sample_val = sample_buffer:sample_data(c, pos)
        sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
      end
    end
  end

  -- Finalize changes
  sample_buffer:finalize_sample_data_changes()

  renoise.app():show_status("Crossfade and 20-frame fades applied to create a smooth X-shaped loop.")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Helper function to determine crossfade_length based on the current selection
local function get_dynamic_crossfade_length()
  local song=renoise.song()
  local sample = song and song.selected_sample or nil
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected.")
    return nil
  end

  local loop_end = sample.loop_end
  local sel = sample.sample_buffer.selection_range

  if not sel or #sel < 2 then
    renoise.app():show_status("No sample selection made.")
    return nil
  end

  -- According to the updated math:
  -- crossfade_length = loop_end - selection_end
  local selection_end = sel[2]

  if selection_end >= loop_end then
    renoise.app():show_status("Selection end must be before loop_end.")
    return nil
  end

  local crossfade_length = loop_end - selection_end
  return crossfade_length
end


-- Keybinding: Use the dynamic crossfade length based on selection_end
renoise.tool():add_keybinding{name="Global:Paketti:Crossfade Loop",
  invoke=function()
    local crossfade_length = get_dynamic_crossfade_length()
    if crossfade_length then
      renoise.app():show_status("Using crossfade length: " .. tostring(crossfade_length))
      crossfade_loop(crossfade_length)
    end
  end
}




renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Transpose (-64-+64)",
  invoke=function(message)
    -- Ensure the selected instrument exists
    local instrument=renoise.song().selected_instrument
    if not instrument then return end
    
    -- Map the MIDI message value (0-127) to transpose range (-64 to 64)
    local transpose_value=math.floor((message.int_value/127)*128 - 64)
    instrument.transpose=math.max(-64,math.min(transpose_value,64))
    
    -- Status update for debugging
    renoise.app():show_status("Transpose adjusted to "..instrument.transpose)
  end
}

-- Function to set transpose for a specific instrument by index
local function set_instrument_transpose(instrument_index, message)
  local song = renoise.song()
  -- Check if the instrument exists (Lua is 1-indexed, but we receive 0-based indices)
  local instrument = song.instruments[instrument_index + 1]
  if not instrument then
    renoise.app():show_status("Instrument " .. string.format("%02d", instrument_index) .. " does not exist")
    return
  end
  
  -- Map the MIDI message value (0-127) to transpose range (-64 to 64)
  local transpose_value = math.floor((message.int_value / 127) * 128 - 64)
  instrument.transpose = math.max(-64, math.min(transpose_value, 64))
  
  -- Status update for debugging
  renoise.app():show_status("Instrument " .. string.format("%02d", instrument_index) .. " transpose adjusted to " .. instrument.transpose)
end


for i=0,7 do
renoise.tool():add_midi_mapping{name="Paketti:Midi Instrument 0" .. i .." Transpose (-64-+64)",
  invoke=function(message) set_instrument_transpose(i, message) 
  renoise.song().selected_instrument_index=i+1
  renoise.song().selected_track_index=i+1
  end}
end

-- Define the path to the mixpaste.xml file within the tool's directory
local tool_dir = renoise.tool().bundle_path
local xml_file_path = tool_dir .. "mixpaste.xml"

-- Function to save the current pattern selection to mixpaste.xml
function save_selection_as_xml()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then 
    renoise.app():show_status("No selection available.") 
    return 
  end

  local pattern_index = song.selected_pattern_index
  local xml_data = '<?xml version="1.0" encoding="UTF-8"?>\n<PatternClipboard.BlockBuffer doc_version="0">\n  <Columns>\n'

  for track_index = selection.start_track, selection.end_track do
    local track = song.tracks[track_index]
    local pattern_track = song.patterns[pattern_index].tracks[track_index]
    xml_data = xml_data .. '    <Column>\n'

    -- Handle NoteColumns
    local note_columns = track.visible_note_columns
    xml_data = xml_data .. '      <Column>\n        <Lines>\n'
    for line_index = selection.start_line, selection.end_line do
      local line = pattern_track:line(line_index)
      local has_data = false
      xml_data = xml_data .. '          <Line index="' .. (line_index - selection.start_line) .. '">\n            <NoteColumns>\n'
      for note_column_index = selection.start_column, selection.end_column do
        local note_column = line:note_column(note_column_index)
        if not note_column.is_empty then
          xml_data = xml_data .. '              <NoteColumn>\n'
          xml_data = xml_data .. '                <Note>' .. note_column.note_string .. '</Note>\n'
          xml_data = xml_data .. '                <Instrument>' .. note_column.instrument_string .. '</Instrument>\n'
          xml_data = xml_data .. '              </NoteColumn>\n'
          has_data = true
        end
      end
      xml_data = xml_data .. '            </NoteColumns>\n'
      if not has_data then
        xml_data = xml_data .. '          <Line />\n'
      end
      xml_data = xml_data .. '          </Line>\n'
    end
    xml_data = xml_data .. '        </Lines>\n        <ColumnType>NoteColumn</ColumnType>\n'
    xml_data = xml_data .. '        <SubColumnMask>' .. get_sub_column_mask(track, 'note') .. '</SubColumnMask>\n'
    xml_data = xml_data .. '      </Column>\n'

    -- Handle EffectColumns
    local effect_columns = track.visible_effect_columns
    xml_data = xml_data .. '      <Column>\n        <Lines>\n'
    for line_index = selection.start_line, selection.end_line do
      local line = pattern_track:line(line_index)
      local has_data = false
      xml_data = xml_data .. '          <Line>\n            <EffectColumns>\n'
      for effect_column_index = 1, effect_columns do
        local effect_column = line:effect_column(effect_column_index)
        if not effect_column.is_empty then
          xml_data = xml_data .. '              <EffectColumn>\n'
          xml_data = xml_data .. '                <EffectNumber>' .. effect_column.number_string .. '</EffectNumber>\n'
          xml_data = xml_data .. '                <EffectValue>' .. effect_column.amount_string .. '</EffectValue>\n'
          xml_data = xml_data .. '              </EffectColumn>\n'
          has_data = true
        end
      end
      xml_data = xml_data .. '            </EffectColumns>\n'
      if not has_data then
        xml_data = xml_data .. '          <Line />\n'
      end
      xml_data = xml_data .. '          </Line>\n'
    end
    xml_data = xml_data .. '        </Lines>\n        <ColumnType>EffectColumn</ColumnType>\n'
    xml_data = xml_data .. '        <SubColumnMask>' .. get_sub_column_mask(track, 'effect') .. '</SubColumnMask>\n'
    xml_data = xml_data .. '      </Column>\n'
    xml_data = xml_data .. '    </Column>\n'
  end

  xml_data = xml_data .. '  </Columns>\n</PatternClipboard.BlockBuffer>\n'

  -- Write XML to file
  local file = io.open(xml_file_path, "w")
  if file then
    file:write(xml_data)
    file:close()
    renoise.app():show_status("Selection saved to mixpaste.xml.")
    print("Saved selection to mixpaste.xml")
  else
    renoise.app():show_status("Error writing to mixpaste.xml.")
    print("Error writing to mixpaste.xml")
  end
end

-- Utility function to generate the SubColumnMask for note or effect columns
function get_sub_column_mask(track, column_type)
  local mask = {}
  if column_type == 'note' then
    for i = 1, track.visible_note_columns do
      mask[i] = 'true'
    end
  elseif column_type == 'effect' then
    for i = 1, track.visible_effect_columns do
      mask[i] = 'true'
    end
  end
  for i = #mask + 1, 8 do
    mask[i] = 'false'
  end
  return table.concat(mask, ' ')
end

-- Function to load the pattern data from mixpaste.xml and paste at the current cursor line
function load_xml_into_selection()
  local song=renoise.song()
  local cursor_line = song.selected_line_index
  local cursor_track = song.selected_track_index

  -- Open the mixpaste.xml file
  local xml_file = io.open(xml_file_path, "r")
  if not xml_file then
    renoise.app():show_status("Error reading mixpaste.xml.")
    print("Error reading mixpaste.xml.")
    return
  end

  local xml_data = xml_file:read("*a")
  xml_file:close()

  -- Parse the XML data manually (basic parsing for this use case)
  local parsed_data = parse_xml_data(xml_data)
  if not parsed_data or #parsed_data.lines == 0 then
    renoise.app():show_status("No valid data in mixpaste.xml.")
    print("No valid data in mixpaste.xml.")
    return
  end

  print("Parsed XML data successfully.")

  -- Insert parsed data starting at the cursor position
  local total_lines = #parsed_data.lines
  for line_index, line_data in ipairs(parsed_data.lines) do
    local target_line = cursor_line + line_index - 1
    if target_line > #song.patterns[song.selected_pattern_index].tracks[cursor_track].lines then
      break -- Avoid exceeding pattern length
    end

    local pattern_track = song.patterns[song.selected_pattern_index].tracks[cursor_track]
    local pattern_line = pattern_track:line(target_line)
    
    -- Handle NoteColumns
    for column_index, note_column_data in ipairs(line_data.note_columns) do
      local note_column = pattern_line:note_column(column_index)
      if note_column_data.note ~= "" then
        note_column.note_string = note_column_data.note
        note_column.instrument_string = note_column_data.instrument
        print("Pasting note: " .. (note_column_data.note or "nil") .. " at line " .. target_line .. ", column " .. column_index)
      end
    end

    -- Handle EffectColumns
    for column_index, effect_column_data in ipairs(line_data.effect_columns) do
      local effect_column = pattern_line:effect_column(column_index)
      if effect_column_data.effect_number ~= "" then
        effect_column.number_string = effect_column_data.effect_number
        effect_column.amount_string = effect_column_data.effect_value
        print("Pasting effect: " .. (effect_column_data.effect_number or "nil") .. " with value " .. (effect_column_data.effect_value or "nil") .. " at line " .. target_line .. ", column " .. column_index)
      end
    end
  end

  renoise.app():show_status("Pattern data loaded from mixpaste.xml.")
  print("Pattern data loaded from mixpaste.xml.")
end

-- Basic XML parsing function
function parse_xml_data(xml_string)
  local parsed_data = { lines = {} }
  local line_count = 0
  for line_content in xml_string:gmatch("<Line.-index=\"(.-)\">(.-)</Line>") do
    local line_index = tonumber(line_content:match("index=\"(.-)\""))
    local line_data = { note_columns = {}, effect_columns = {} }

    -- Parsing NoteColumns
    for note_column_content in line_content:gmatch("<NoteColumn>(.-)</NoteColumn>") do
      local note = note_column_content:match("<Note>(.-)</Note>") or ""
      local instrument = note_column_content:match("<Instrument>(.-)</Instrument>") or ""
      table.insert(line_data.note_columns, { note = note, instrument = instrument })
    end

    -- Parsing EffectColumns
    for effect_column_content in line_content:gmatch("<EffectColumn>(.-)</EffectColumn>") do
      local effect_number = effect_column_content:match("<EffectNumber>(.-)</EffectNumber>") or ""
      local effect_value = effect_column_content:match("<EffectValue>(.-)</EffectValue>") or ""
      table.insert(line_data.effect_columns, { effect_number = effect_number, effect_value = effect_value })
    end

    table.insert(parsed_data.lines, line_data)
    line_count = line_count + 1
  end
  print("Parsed " .. line_count .. " lines from XML.")
  return parsed_data
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Save",invoke=function() save_selection_as_xml() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Load",invoke=function() load_xml_into_selection() end}
---------------
function shrink_to_triplets()
    local song=renoise.song()
    local track = song.selected_pattern.tracks[renoise.song().selected_track_index]
    local pattern_length = song.selected_pattern.number_of_lines

    local note_positions = {}

    -- Collect all notes and their positions
    for line_index = 1, pattern_length do
        local line = track:line(line_index)
        local note_column = line.note_columns[1]

        if not note_column.is_empty then
            -- Manually clone the note data
            table.insert(note_positions, {line_index, {
                note_value = note_column.note_value,
                instrument_value = note_column.instrument_value,
                volume_value = note_column.volume_value,
                panning_value = note_column.panning_value,
                delay_value = note_column.delay_value
            }})
        end
    end

    -- Ensure we have enough notes to work with
    if #note_positions < 2 then
        renoise.app():show_status("Not enough notes to apply triplet structure.")
        return
    end

    -- Calculate the original spacing between notes
    local original_spacing=note_positions[2][1] - note_positions[1][1]

    -- Determine the modifier based on the spacing
    local modifier = math.floor(original_spacing / 2)  -- Will be 1 for 2-row spacing and 2 for 4-row spacing
    local cycle_step = 0

    -- Clear the pattern before applying the triplets
    for line_index = 1, pattern_length do
        track:line(line_index):clear()
    end

    -- Apply triplet logic based on the original spacing
    local new_index = note_positions[1][1]  -- Start at the first note

    for i = 1, #note_positions do
        local note_data = note_positions[i][2]
        local target_line = track:line(new_index)

        -- Triplet Logic
        if original_spacing == 2 then
            -- Case for notes every 2 rows
            if cycle_step == 0 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x00
            elseif cycle_step == 1 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x55
            elseif cycle_step == 2 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0xAA

                -- Add extra empty row after AA
                new_index = new_index + 1
            end

            -- Move to the next row
            new_index = new_index + 1
            cycle_step = (cycle_step + 1) % 3

        elseif original_spacing == 4 then
            -- Case for notes every 4 rows
            if cycle_step == 0 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x00
            elseif cycle_step == 1 then
                -- Move the note up by 2 rows and apply AA delay
                new_index = new_index + 2
                target_line = track:line(new_index)
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0xAA

                -- Add one empty row after AA
                new_index = new_index + 1
            elseif cycle_step == 2 then
                -- Apply 55 delay and move up by 1 row
                target_line = track:line(new_index)
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x55

                -- Add one empty row after 55
                new_index = new_index + 1
            end

            -- Move to the next row
            new_index = new_index + 1
            cycle_step = (cycle_step + 1) % 3
        end
    end

    renoise.app():show_status("Shrink to triplets applied successfully.")
end

-- Keybinding for the script
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Shrink to Triplets",invoke=function() shrink_to_triplets() end}

function triple(first,second,where)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index+first].note_columns[1]:copy_from(renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[1])
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index+second].note_columns[1]:copy_from(renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[1])


local wherenext=renoise.song().selected_line_index+where

if wherenext > renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines then
wherenext=1 
renoise.song().selected_line_index = wherenext return
else  renoise.song().selected_line_index=renoise.song().selected_line_index+where
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Triple (Experimental)",invoke=function() triple(3,6,8) end}

--------
function xypad()
local vb = renoise.ViewBuilder()
local dialog = nil

-- Initial center position
local initial_position = 0.5
local prev_x = initial_position
local prev_y = initial_position

-- Adjust the shift and rotation amounts
local shift_amount = 1  -- Reduced shift amount for smaller up/down changes
local rotation_amount = 2000  -- Adjusted rotation amount for left/right to be less intense

-- Set the middle frame to the instrument sample editor
renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

-- Function to wrap the sample value
local function wrap_sample_value(value)
  if value > 1.0 then
    return value - 2.0
  elseif value < -1.0 then
    return value + 2.0
  else
    return value
  end
end

-- Function to shift the sample buffer upwards with wrap-around
local function PakettiXYPadSampleRotatorUp(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value * 1000  -- Adjusted to match the desired intensity
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted upwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to shift the sample buffer downwards with wrap-around
local function PakettiXYPadSampleRotatorDown(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value * 1000  -- Adjusted to match the desired intensity
        local new_value = wrap_sample_value(current_value - shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted downwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to rotate sample buffer content forwards by a specified number of frames
local function PakettiXYPadSampleRotatorRight(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + rotation_amount * knob_value - 1) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer rotated forward by "..(rotation_amount * knob_value).." frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

-- Function to rotate sample buffer content backwards by a specified number of frames
local function PakettiXYPadSampleRotatorLeft(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i - rotation_amount * knob_value - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer rotated backward by "..(rotation_amount * knob_value).." frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

-- Function to handle XY pad changes and call appropriate rotator functions
local function on_xy_change(value)
  local x = value.x
  local y = value.y

  -- Compare current x and y with previous values to determine direction
  if x > prev_x then
    PakettiXYPadSampleRotatorRight(x - prev_x) -- Moving right
  elseif x < prev_x then
    PakettiXYPadSampleRotatorLeft(prev_x - x) -- Moving left
  end

  if y > prev_y then
    PakettiXYPadSampleRotatorUp(y - prev_y) -- Moving up
  elseif y < prev_y then
    PakettiXYPadSampleRotatorDown(prev_y - y) -- Moving down
  end

  -- Update previous x and y with the current position
  prev_x = x
  prev_y = y

  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to handle vertical slider change (up/down)
local function on_vertical_slider_change(value)
  if value > initial_position then
    PakettiXYPadSampleRotatorUp(value - initial_position)
  elseif value < initial_position then
    PakettiXYPadSampleRotatorDown(initial_position - value)
  end
  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to handle horizontal slider change (left/right)
local function on_horizontal_slider_change(value)
  if value > initial_position then
    PakettiXYPadSampleRotatorRight(value - initial_position)
  elseif value < initial_position then
    PakettiXYPadSampleRotatorLeft(initial_position - value)
  end
  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to display the dialog with the XY pad and sliders
local function show_paketti_sample_rotator_dialog()
  -- Reset the XY pad to the center (0.5, 0.5)
  prev_x = initial_position
  prev_y = initial_position

  if dialog and dialog.visible then
    dialog:show()
    return
  end

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti XYPad Sample Rotator",
    vb:column{
      vb:row{
        vb:xypad{
          width=200,
          height = 200,
          notifier = on_xy_change,
          value = {x = initial_position, y = initial_position} -- Center the XY pad
        },
        vb:vertical_aligner{
          mode = "center",
          vb:slider{
            height = 200,
            min = 0.0,
            max = 1.0,
            value = initial_position,
            notifier = on_vertical_slider_change
          }
        }
      },
      vb:horizontal_aligner{
        mode = "center",
        vb:slider{
          width=200,
          min = 0.0,
          max = 1.0,
          value = initial_position,
          notifier = on_horizontal_slider_change
        }}}, keyhandler
  )
end

-- Show the dialog when the script is run
--show_paketti_sample_rotator_dialog()

end


------------------
-- Updated shift amount
local shift_amount = 0.01  -- Default value for subtle shifts

-- Function to wrap the sample value
local function wrap_sample_value(value)
  if value > 1.0 then
    return value - 2.0
  elseif value < -1.0 then
    return value + 2.0
  else
    return value
  end
end

-- Function to shift the sample buffer upwards with wrap-around
function PakettiShiftSampleBufferUpwards(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted upwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to wrap the sample value correctly
local function wrap_sample_value(value)
  if value < -1.0 then
      return value + 2.0  -- Simple wrap from bottom to top
  elseif value > 1.0 then
      return value - 2.0  -- Simple wrap from top to bottom
  end
  return value
end

function PakettiShiftSampleBufferDownwards(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
      -- First, read ALL values before modifying anything
      local values = {}
      for c = 1, buffer.number_of_channels do
          values[c] = {}
          for i = 1, buffer.number_of_frames do
              values[c][i] = buffer:sample_data(c, i)
          end
      end

      print("\nBefore shift (all frames):")
      for c = 1, buffer.number_of_channels do
          print("Channel " .. c .. ":")
          for i = 1, buffer.number_of_frames do
              print(string.format("Frame %d: %.12f", i, values[c][i]))
          end
      end

      buffer:prepare_sample_data_changes()
      
      local shift_value = shift_amount * knob_value
      
      -- Calculate new values before writing any of them
      local new_values = {}
      for c = 1, buffer.number_of_channels do
          new_values[c] = {}
          for i = 1, buffer.number_of_frames do
              local current_value = values[c][i]
              if math.abs(current_value + 1.0) < 0.000001 then
                  new_values[c][i] = 1.0 - shift_value
              else
                  new_values[c][i] = current_value - shift_value
              end
              
              print(string.format(
                  "Frame %d: %.12f %s shifted by %.12f = %.12f",
                  i,
                  current_value,
                  (math.abs(current_value + 1.0) < 0.000001) and "wrapped to 1.0 then" or "",
                  shift_value,
                  new_values[c][i]
              ))
          end
      end
      
      -- Now write all the new values
      for c = 1, buffer.number_of_channels do
          for i = 1, buffer.number_of_frames do
              buffer:set_sample_data(c, i, new_values[c][i])
              print(string.format("   Frame %d actually stored as: %.12f", i, buffer:sample_data(c, i)))
          end
      end
      
      buffer:finalize_sample_data_changes()

      print("\nAfter shift (all frames):")
      for c = 1, buffer.number_of_channels do
          print("Channel " .. c .. ":")
          for i = 1, buffer.number_of_frames do
              print(string.format("Frame %d: %.12f", i, buffer:sample_data(c, i)))
          end
      end

      print("\nShift parameters:")
      print(string.format("knob_value: %.12f", knob_value))
      print(string.format("shift_amount: %.12f", shift_amount))
      print(string.format("total shift: %.12f", shift_amount * knob_value))

      renoise.app():show_status("Sample buffer shifted downwards with wrap-around.")
  else
      renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to shift the sample buffer based on knob position (Up/Down)
function PakettiShiftSampleBuffer(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local direction = 0
    if knob_value <= 63 then
      direction = -1  -- Shift downwards
    else
      direction = 1  -- Shift upwards
    end
    local adjusted_knob_value = math.abs(knob_value - 64) / 63  -- Normalize to 0...1 range
    
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * adjusted_knob_value * direction
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted " .. (direction > 0 and "upwards" or "downwards") .. " with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up x[Trigger]",invoke=function(message) if message:is_trigger() then PakettiShiftSampleBufferUpwards(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Down x[Trigger]",invoke=function(message) if message:is_trigger() then PakettiShiftSampleBufferDownwards(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up x[Knob]",invoke=function(message) local knob_value = message.int_value / 127 PakettiShiftSampleBufferUpwards(knob_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Down x[Knob]",invoke=function(message) local knob_value = message.int_value / 127 PakettiShiftSampleBufferDownwards(knob_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up/Down x[Knob]",invoke=function(message) PakettiShiftSampleBuffer(message.int_value) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Upwards",invoke=function() PakettiShiftSampleBufferUpwards(1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Downwards",invoke=function() PakettiShiftSampleBufferDownwards(1) end}


--[[
local function randomizeSmatterEffectColumnCustom(effect_command)
  local song=renoise.song()
  local track_index = song.selected_track_index
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local selection = song.selection_in_pattern
  local randomize = function()
    return string.format("%02X", math.random(1, 255))
  end

  local apply_command = function(line)
    local effect_column = line.effect_columns[1]
    if math.random() > 0.5 then
      effect_column.number_string = effect_command
      effect_column.amount_string = randomize()
    else
      effect_column:clear()
    end
  end

  if selection then
    for line_index = selection.start_line, selection.end_line do
      local line = pattern:track(track_index).lines[line_index]
      apply_command(line)
    end
  else
    for sequence_index, sequence in ipairs(song.sequencer.pattern_sequence) do
      if song:pattern(sequence).tracks[track_index] then
        local lines = song:pattern(sequence).number_of_lines
        for line_index = 1, lines do
          local line = song:pattern(sequence).tracks[track_index].lines[line_index]
          apply_command(line)
        end
      end
    end
  end

  renoise.app():show_status("Random " .. effect_command .. " commands applied to the first effect column of the selected track.")
end
]]--
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (C00/C0F)",invoke=function() randomizeSmatterEffectColumnCustom("0C", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0G Glide)",invoke=function() randomizeSmatterEffectColumnCustom("0G", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0U Slide Up)",invoke=function() randomizeSmatterEffectColumnCustom("0U", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0D Slide Down)",invoke=function() randomizeSmatterEffectColumnCustom("0D", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0R Retrig)",invoke=function() randomizeSmatterEffectColumnCustom("0R", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0P Panning)",invoke=function() randomizeSmatterEffectColumnCustom("0P", false,0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0B00/0B01)",invoke=function() randomizeSmatterEffectColumnCustom("0B", false, 0x00, 0xFF) end}


renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (C00/C0F)",invoke=function() randomizeSmatterEffectColumnCustom("0C", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0G Glide)",invoke=function() randomizeSmatterEffectColumnCustom("0G", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0U Slide Up)",invoke=function() randomizeSmatterEffectColumnCustom("0U", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0D Slide Down)",invoke=function() randomizeSmatterEffectColumnCustom("0D", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0R Retrig)",invoke=function() randomizeSmatterEffectColumnCustom("0R", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0P Panning)",invoke=function() randomizeSmatterEffectColumnCustom("0P", true,0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0B00/0B01)",invoke=function() randomizeSmatterEffectColumnCustom("0B", true, 0x00, 0xFF) end}
------------------------
----
-- Utility function to check if a table contains a value
function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

-- Function to unmute all sequencer tracks except the master track (ignores send tracks)
function PakettiToggleSoloTracksUnmuteAllTracks()
  local song=renoise.song()

  print("----")
  print("Unmuting all sequencer tracks (ignoring send tracks)")
  for i = 1, song.sequencer_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end
end

-- Function to mute all tracks except a specific range, and not the master track
function PakettiToggleSoloTracksMuteAllExceptRange(start_track, end_track)
  local song=renoise.song()
  -- Only consider sequencer tracks, ignore send tracks entirely
  local total_track_count = song.sequencer_track_count
  local group_parents = {}

  print("----")
  print("Muting all tracks except range: " .. start_track .. " to " .. end_track)
  for i = start_track, end_track do
    if song:track(i).group_parent then
      local group_parent = song:track(i).group_parent.name
      if not table_contains(group_parents, group_parent) then
        table.insert(group_parents, group_parent)
      end
    end
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      if i < start_track or i > end_track then
        song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
        print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
      end
    end
  end

  for i = start_track, end_track do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end

  for _, group_parent_name in ipairs(group_parents) do
    local group_parent_index = nil
    for i = 1, song.sequencer_track_count do
      if song:track(i).name == group_parent_name then
        group_parent_index = i
        break
      end
    end
    if group_parent_index then
      local group_parent = song:track(group_parent_index)
      group_parent.mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting group track: " .. group_parent.name)
    end
  end
end

-- Function to mute all tracks except a specific track and its group, and not the master track
function PakettiToggleSoloTracksMuteAllExceptSelectedTrack(track_index)
  local song=renoise.song()
  -- Only consider sequencer tracks, ignore send tracks entirely
  local total_track_count = song.sequencer_track_count
  local selected_track = song:track(track_index)
  local group_tracks = {}

  print("----")
  print("Muting all tracks except selected track: " .. track_index .. " (" .. selected_track.name .. ")")

  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    table.insert(group_tracks, track_index)
    print("Group name is " .. selected_track.name .. ", Number of Members is " .. #selected_track.members)
    -- Group members come BEFORE the group track
    for i = track_index - #selected_track.members, track_index - 1 do
      if i >= 1 then
        table.insert(group_tracks, i)
        print("Member index: " .. i .. " (" .. song:track(i).name .. ")")
      end
    end
    
    -- If this group has a parent group (nested group), include the parent too
    if selected_track.group_parent then
      local parent_group_name = selected_track.group_parent.name
      for i = 1, song.sequencer_track_count do
        if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == parent_group_name then
          table.insert(group_tracks, i)
          print("Parent group index: " .. i .. " (" .. parent_group_name .. ")")
          break
        end
      end
    end
  elseif selected_track.group_parent then
    local group_parent = selected_track.group_parent.name
    for i = 1, song.sequencer_track_count do
      if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == group_parent then
        table.insert(group_tracks, i)
        print("Group parent: " .. group_parent .. " at index " .. i)
        break
      end
    end
    table.insert(group_tracks, track_index)
    print("Member index: " .. track_index .. " (" .. selected_track.name .. ")")
  else
    table.insert(group_tracks, track_index)
    print("Single track index: " .. track_index .. " (" .. selected_track.name .. ")")
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and not table_contains(group_tracks, i) then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
      print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end

  for _, group_track in ipairs(group_tracks) do
    if song:track(group_track).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(group_track).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. group_track .. " (" .. song:track(group_track).name .. ")")
    end
  end
end

-- Function to check if all tracks and send tracks are unmuted
function PakettiToggleSoloTracksAllTracksUnmuted()
  local song=renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      return false
    end
  end
  return true
end

-- Function to check if all tracks except the selected track and its group are muted
function PakettiToggleSoloTracksAllOthersMutedExceptSelected(track_index)
  local song=renoise.song()
  local selected_track = song:track(track_index)
  local group_tracks = {}
  -- Only consider sequencer tracks, ignore send tracks entirely
  local total_track_count = song.sequencer_track_count

  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    -- For group tracks, add the group track and its members (members come before the group)
    table.insert(group_tracks, track_index)
    for i = track_index - #selected_track.members, track_index - 1 do
      if i >= 1 then
        table.insert(group_tracks, i)
      end
    end
    
    -- If this group has a parent group (nested group), include the parent too
    if selected_track.group_parent then
      local parent_group_name = selected_track.group_parent.name
      for i = 1, song.sequencer_track_count do
        if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == parent_group_name then
          table.insert(group_tracks, i)
          break
        end
      end
    end
  elseif selected_track.group_parent then
    local group_parent = selected_track.group_parent.name
    for i = 1, song.sequencer_track_count do
      if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == group_parent then
        table.insert(group_tracks, i)
        break
      end
    end
    table.insert(group_tracks, track_index)
  else
    table.insert(group_tracks, track_index)
  end

  -- Check if all tracks outside the group are muted
  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and not table_contains(group_tracks, i) then
      if song:track(i).mute_state ~= renoise.Track.MUTE_STATE_OFF then
        return false
      end
    end
  end
  
  -- Check if all tracks in the group are active (unmuted)
  for _, group_track_index in ipairs(group_tracks) do
    if song:track(group_track_index).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      return false
    end
  end
  
  -- If all other tracks are muted and all group tracks are active, we're in a solo state that should be toggled off
  return true
end

-- Function to check if all tracks except the selected range are muted
function PakettiToggleSoloTracksAllOthersMutedExceptRange(start_track, end_track)
  local song=renoise.song()
  -- Only consider sequencer tracks, ignore send tracks entirely
  local total_track_count = song.sequencer_track_count
  local group_parents = {}

  print("Selection In Pattern is from index " .. start_track .. " to index " .. end_track)
  print("MUTE_STATE_ACTIVE = " .. renoise.Track.MUTE_STATE_ACTIVE)
  print("MUTE_STATE_OFF = " .. renoise.Track.MUTE_STATE_OFF)
  print("MUTE_STATE_MUTED = " .. renoise.Track.MUTE_STATE_MUTED)
  for i = start_track, end_track do
    print("Track index: " .. i .. " (" .. song:track(i).name .. ")")
    if song:track(i).group_parent then
      local group_parent = song:track(i).group_parent.name
      if not table_contains(group_parents, group_parent) then
        table.insert(group_parents, group_parent)
        print("Group parent: " .. group_parent)
      end
    end
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and (i < start_track or i > end_track) then
      local is_group_parent = false
      for _, group_parent_name in ipairs(group_parents) do
        if song:track(i).name == group_parent_name then
          is_group_parent = true
          break
        end
      end
      
      print("Checking track outside range: " .. i .. " (" .. song:track(i).name .. ") - mute_state: " .. song:track(i).mute_state .. " - is_group_parent: " .. tostring(is_group_parent))
      
      if not is_group_parent and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_OFF then
        print("Track " .. i .. " is not muted and not a group parent, returning false")
        return false
      end
    end
  end
  for i = start_track, end_track do
    print("Checking track in range: " .. i .. " (" .. song:track(i).name .. ") - mute_state: " .. song:track(i).mute_state)
    if song:track(i).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      print("Track " .. i .. " is not active, returning false")
      return false
    end
  end

  for _, group_parent_name in ipairs(group_parents) do
    local group_parent_index = nil
    for i = 1, song.sequencer_track_count do
      if song:track(i).name == group_parent_name then
        group_parent_index = i
        break
      end
    end
    if group_parent_index then
      local group_parent = song:track(group_parent_index)
      if group_parent.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
        return false
      end
    end
  end
  print("All conditions met - returning true (should unmute all tracks)")
  return true
end

-- Main function to toggle mute states
function PakettiToggleSoloTracks()
  local song=renoise.song()
  local sip = song.selection_in_pattern
  local selected_track_index = song.selected_track_index
  local selected_track = song:track(selected_track_index)

  print("----")
  print("Running PakettiToggleSoloTracks")

  if sip then
    -- If a selection in pattern exists
    print("Selection In Pattern is from index " .. sip.start_track .. " to " .. sip.end_track)
    for i = sip.start_track, sip.end_track do
      print("Track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
    local should_unmute = PakettiToggleSoloTracksAllOthersMutedExceptRange(sip.start_track, sip.end_track)
    print("PakettiToggleSoloTracksAllOthersMutedExceptRange returned: " .. tostring(should_unmute))
    if should_unmute then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      print("Detecting Muting situation")
      PakettiToggleSoloTracksMuteAllExceptRange(sip.start_track, sip.end_track)
    end
  elseif selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    -- If the selected track is a group, mute all tracks and then unmute the group and its members
    print("Selected track is a group")
    print("Group name is " .. selected_track.name .. ", Number of Members is " .. #selected_track.members)
    if PakettiToggleSoloTracksAllOthersMutedExceptSelected(selected_track_index) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      -- First mute all sequencer tracks except master (ignore send tracks entirely)
      for i = 1, song.sequencer_track_count do
        if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
          song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
          print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
        end
      end
      -- Then unmute the group and its members (members come before the group track)  
      for i = selected_track_index - #selected_track.members, selected_track_index do
        song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
        print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
      end
      
      -- If this group has a parent group (nested group), unmute the parent too
      if selected_track.group_parent then
        local parent_group_name = selected_track.group_parent.name
        for i = 1, song.sequencer_track_count do
          if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == parent_group_name then
            song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
            print("Unmuting parent group track index: " .. i .. " (" .. parent_group_name .. ")")
            break
          end
        end
      end
    end
  else
    -- If no selection in pattern and selected track is not a group
    print("No selection in pattern, using selected track: " .. selected_track_index .. " (" .. selected_track.name .. ")")
    if PakettiToggleSoloTracksAllOthersMutedExceptSelected(selected_track_index) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      print("Detecting Muting situation")
      PakettiToggleSoloTracksMuteAllExceptSelectedTrack(selected_track_index)
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}

-- Define the function to toggle mute state
function toggle_mute_tracks()
  -- Get the current song
  local song=renoise.song()

  -- Determine the range of selected tracks
  local selection = song.selection_in_pattern

  -- Check if there is a valid selection
  local start_track, end_track
  if selection then
    start_track = selection.start_track
    end_track = selection.end_track
  end

  -- If no specific selection is made, operate on the currently selected track
  if not start_track or not end_track then
    start_track = song.selected_track_index
    end_track = song.selected_track_index
  end

  -- Check if any track in the selection is unmuted (active), ignoring the master track
  local any_track_unmuted = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
      any_track_unmuted = true
      break
    end
  end

  -- Determine the desired mute state for all tracks
  local new_mute_state
  if any_track_unmuted then
    -- If any tracks are unmuted, mute them all
    new_mute_state = renoise.Track.MUTE_STATE_MUTED
  else
    -- If all tracks are muted, unmute them all
    new_mute_state = renoise.Track.MUTE_STATE_ACTIVE
  end

  -- Iterate over the range of tracks and set the new mute state, ignoring the master track
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      track.mute_state = new_mute_state
    end
  end

  -- Additionally, handle group members and parent groups when a group is in the selection
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_GROUP then
      -- Set the mute state for all member tracks of this group
      set_group_mute_state(track, new_mute_state)
      
      -- If this group has a parent group (nested group), ensure parent group has same mute state
      if track.group_parent then
        local parent_group_name = track.group_parent.name
        for i = 1, song.sequencer_track_count do
          if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == parent_group_name then
            song:track(i).mute_state = new_mute_state
            break
          end
        end
      end
    end
  end
end

-- Helper function to set mute state for a group's member tracks only (group itself is handled in main loop)
function set_group_mute_state(group, mute_state)
  -- Set mute state for all member tracks of the group, ignoring the master track
  -- Note: The group track itself is already handled in the main loop
  for _, track in ipairs(group.members) do
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      track.mute_state = mute_state
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute Tracks",invoke=toggle_mute_tracks}
--------
-- Function to initialize selection if it is nil
function PakettiImpulseTrackerShiftInitializeSelection()
  local song=renoise.song()
  local pos = song.transport.edit_pos
  local selected_track_index = song.selected_track_index
  local selected_column_index = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index

  song.selection_in_pattern = {
    start_track = selected_track_index,
    end_track = selected_track_index,
    start_column = selected_column_index,
    end_column = selected_column_index,
    start_line = pos.line,
    end_line = pos.line
  }
end

-- Function to ensure selection is valid and swap if necessary
function PakettiImpulseTrackerShiftEnsureValidSelection()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if selection.start_track > selection.end_track then
    local temp = selection.start_track
    selection.start_track = selection.end_track
    selection.end_track = temp
  end

  if selection.start_column > selection.end_column then
    local temp = selection.start_column
    selection.start_column = selection.end_column
    selection.end_column = temp
  end

  if selection.start_line > selection.end_line then
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  song.selection_in_pattern = selection
end

-- Debug function to print selection details
local function debug_print_selection(message)
  local song=renoise.song()
  local selection = song.selection_in_pattern
  print(message)
print("--------")
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)
print("--------")

end

-- Function to select the next column or track to the right
function PakettiImpulseTrackerShiftRight()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Right Shift")

  if song.selected_track_index == selection.end_track and (song.selected_note_column_index == selection.end_column or song.selected_effect_column_index == selection.end_column) then
    if selection.end_column < song:track(selection.end_track).visible_note_columns then
      selection.end_column = selection.end_column + 1
    elseif selection.end_track < #song.tracks then
      selection.end_track = selection.end_track + 1
      local track = song:track(selection.end_track)
      if track.visible_note_columns > 0 then
        selection.end_column = 1
      else
        selection.end_column = track.visible_effect_columns > 0 and 1 or 0
      end
    else
      renoise.app():show_status("You are on the last track. No more can be selected in that direction.")
      return
    end
  else
    if song.selected_track_index < selection.start_track then
      local temp_track = selection.start_track
      selection.start_track = selection.end_track
      selection.end_track = temp_track

      local temp_column = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp_column
    end
    selection.start_track = song.selected_track_index
    selection.start_column = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  if song:track(selection.end_track).visible_note_columns > 0 then
    song.selected_note_column_index = selection.end_column
  else
    song.selected_effect_column_index = selection.end_column
  end

  debug_print_selection("After Right Shift")
end

-- Function to select the previous column or track to the left
function PakettiImpulseTrackerShiftLeft()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Left Shift")

  if song.selected_track_index == selection.end_track and (song.selected_note_column_index == selection.end_column or song.selected_effect_column_index == selection.end_column) then
    if selection.end_column > 1 then
      selection.end_column = selection.end_column - 1
    elseif selection.end_track > 1 then
      selection.end_track = selection.end_track - 1
      local track = song:track(selection.end_track)
      if track.visible_note_columns > 0 then
        selection.end_column = track.visible_note_columns
      else
        selection.end_column = track.visible_effect_columns > 0 and track.visible_effect_columns or 0
      end
    else
      renoise.app():show_status("You are on the first track. No more can be selected in that direction.")
      return
    end
  else
    if song.selected_track_index > selection.start_track then
      local temp_track = selection.start_track
      selection.start_track = selection.end_track
      selection.end_track = temp_track

      local temp_column = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp_column
    end
    selection.start_track = song.selected_track_index
    selection.start_column = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  if song:track(selection.end_track).visible_note_columns > 0 then
    song.selected_note_column_index = selection.end_column
  else
    song.selected_effect_column_index = selection.end_column
  end

  debug_print_selection("After Left Shift")
end

-- Function to extend the selection down by one line
function PakettiImpulseTrackerShiftDown()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local current_pattern = song.selected_pattern_index

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Down Shift")

  if song.transport.edit_pos.line == selection.end_line then
    if selection.end_line < song:pattern(current_pattern).number_of_lines then
      selection.end_line = selection.end_line + 1
    else
      renoise.app():show_status("You are at the end of the pattern. No more can be selected.")
      return
    end
  else
    if song.transport.edit_pos.line < selection.start_line then
      local temp_line = selection.start_line
      selection.start_line = selection.end_line
      selection.end_line = temp_line
    end
    selection.start_line = song.transport.edit_pos.line
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection
  song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)

  debug_print_selection("After Down Shift")
end

-- Main function to determine which shift up function to call
function PakettiImpulseTrackerShiftUp()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  if selection.start_column == selection.end_column then
    PakettiImpulseTrackerShiftUpSingleColumn()
  else
    PakettiImpulseTrackerShiftUpMultipleColumns()
  end
end

-- Function to extend the selection up by one line in a single column
function PakettiImpulseTrackerShiftUpSingleColumn()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local edit_pos = song.transport.edit_pos

  debug_print_selection("Before Up Shift (Single Column)")

  -- Determine the current column index based on the track type
  local current_column_index
  if song:track(song.selected_track_index).visible_note_columns > 0 then
    current_column_index = song.selected_note_column_index
  else
    current_column_index = song.selected_effect_column_index
  end

  -- Check if the cursor is within the current selection
  local cursor_in_selection = song.selected_track_index == selection.start_track and
                              song.selected_track_index == selection.end_track and
                              current_column_index == selection.start_column and
                              edit_pos.line >= selection.start_line and
                              edit_pos.line <= selection.end_line

  if not cursor_in_selection then
    -- Reset the selection to start from the current cursor position if the cursor is not within the selection
    selection.start_track = song.selected_track_index
    selection.end_track = song.selected_track_index
    selection.start_column = current_column_index
    selection.end_column = current_column_index
    selection.start_line = edit_pos.line
    selection.end_line = edit_pos.line

    if selection.start_line > 1 then
      selection.start_line = selection.start_line - 1
      song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
    else
      renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
      return
    end
  else
    -- Extend the selection upwards if the cursor is within the selection
    if edit_pos.line == selection.end_line then
      if selection.end_line > selection.start_line then
        selection.end_line = selection.end_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      elseif selection.end_line == selection.start_line then
        if selection.start_line > 1 then
          selection.start_line = selection.start_line - 1
          song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
        else
          renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
          return
        end
      end
    elseif edit_pos.line == selection.start_line then
      if selection.start_line > 1 then
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    else
      if edit_pos.line < selection.start_line then
        selection.start_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        selection.end_line = edit_pos.line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      end
    end
  end

  -- Ensure start_line is always <= end_line
  if selection.start_line > selection.end_line then
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  debug_print_selection("After Up Shift (Single Column)")
end

-- Function to extend the selection up by one line in multiple columns
function PakettiImpulseTrackerShiftUpMultipleColumns()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local edit_pos = song.transport.edit_pos

  -- Print separator and current state
  print("----")
  print("Before Up Shift (Multiple Columns)")
  print("Current Line Index: " .. edit_pos.line)
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)

  -- Determine the current column index based on the track type
  local current_column_index
  if song:track(song.selected_track_index).visible_note_columns > 0 then
    current_column_index = song.selected_note_column_index
  else
    current_column_index = song.selected_effect_column_index
  end

  -- Print the current column index and edit position line
  print("Current Column Index: " .. current_column_index)
  print("Edit Position Line: " .. edit_pos.line)

  -- Check if the cursor is within the current selection
  local cursor_in_selection = song.selected_track_index == selection.start_track and
                              song.selected_track_index == selection.end_track and
                              current_column_index >= selection.start_column and
                              current_column_index <= selection.end_column and
                              edit_pos.line >= selection.start_line and
                              edit_pos.line <= selection.end_line

  print("Cursor in Selection: " .. tostring(cursor_in_selection))

  if not cursor_in_selection then
    -- Reset the selection to start from the current cursor position if the cursor is not within the selection
    print("Cursor not in selection, resetting selection.")
    selection.start_track = song.selected_track_index
    selection.end_track = song.selected_track_index
    selection.start_column = current_column_index
    selection.end_column = current_column_index
    selection.start_line = edit_pos.line
    selection.end_line = edit_pos.line

    if selection.start_line > 1 then
      selection.start_line = selection.start_line - 1
      song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
    else
      renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
      return
    end
  else
    -- Extend the selection upwards if the cursor is within the selection
    print("Cursor in selection, extending selection upwards.")
    if edit_pos.line == selection.end_line and current_column_index == selection.end_column then
      if selection.end_line > selection.start_line then
        print("Decrementing end_line")
        selection.end_line = selection.end_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      elseif selection.start_line > 1 then
        print("Decrementing start_line")
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    elseif edit_pos.line == selection.start_line and current_column_index == selection.start_column then
      if selection.start_line > 1 then
        print("Decrementing start_line")
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    else
      if edit_pos.line < selection.start_line then
        print("Adjusting start_line to edit position")
        selection.start_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        print("Adjusting end_line to edit position")
        selection.end_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      end
    end
  end

  -- Ensure start_line is always <= end_line
  if selection.start_line > selection.end_line then
    print("Swapping start_line and end_line to ensure start_line <= end_line")
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  -- Print separator and current state after the operation
  print("After Up Shift (Multiple Columns)")
  print("Current Line Index: " .. song.transport.edit_pos.line)
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)
  print("----")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Right Selection In Pattern",invoke=PakettiImpulseTrackerShiftRight}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Left Selection In Pattern",invoke=PakettiImpulseTrackerShiftLeft}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Down Selection In Pattern",invoke=PakettiImpulseTrackerShiftDown}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Up Selection In Pattern",invoke=PakettiImpulseTrackerShiftUp}
-- Function to copy a single note column
function PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src, dst)
  if src and dst then
    dst.note_value = src.note_value
    dst.instrument_value = src.instrument_value
    dst.volume_value = src.volume_value
    dst.panning_value = src.panning_value
    dst.delay_value = src.delay_value
    dst.effect_number_value = src.effect_number_value
    dst.effect_amount_value = src.effect_amount_value
  elseif dst then
    dst:clear()
  end
end

-- Function to copy a single effect column
function PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src, dst)
  if src and dst then
    dst.number_value = src.number_value
    dst.amount_value = src.amount_value
  elseif dst then
    dst:clear()
  end
end

-- Slide selected column content down by one row in the current pattern
function PakettiImpulseTrackerSlideSelectedColumnDown()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines
  local column_index = song.selected_note_column_index
  local is_note_column = column_index > 0

  if not is_note_column then
    column_index = song.selected_effect_column_index
  end

  -- Store the content of the last row to move it to the first row
  local last_row_content
  if is_note_column then
    last_row_content = track:line(number_of_lines).note_columns[column_index]
  else
    last_row_content = track:line(number_of_lines).effect_columns[column_index]
  end

  -- Slide content down
  for line = number_of_lines, 2, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    if is_note_column then
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    else
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  -- Move the last row content to the first row and clear the last row
  local first_line = track:line(1)
  if is_note_column then
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(last_row_content, first_line.note_columns[column_index])
    track:line(number_of_lines).note_columns[column_index]:clear()
  else
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(last_row_content, first_line.effect_columns[column_index])
    track:line(number_of_lines).effect_columns[column_index]:clear()
  end
end

-- Slide selected column content up by one row in the current pattern
function PakettiImpulseTrackerSlideSelectedColumnUp()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines
  local column_index = song.selected_note_column_index
  local is_note_column = column_index > 0

  if not is_note_column then
    column_index = song.selected_effect_column_index
  end

  -- Store the content of the first row to move it to the last row
  local first_row_content
  if is_note_column then
    first_row_content = track:line(1).note_columns[column_index]
  else
    first_row_content = track:line(1).effect_columns[column_index]
  end

  -- Slide content up
  for line = 1, number_of_lines - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    if is_note_column then
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    else
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  -- Move the first row content to the last row and clear the first row
  local last_line = track:line(number_of_lines)
  if is_note_column then
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(first_row_content, last_line.note_columns[column_index])
    track:line(1).note_columns[column_index]:clear()
  else
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(first_row_content, last_line.effect_columns[column_index])
    track:line(1).effect_columns[column_index]:clear()
  end
end

-- Functions to slide selected columns up or down within a selection
local function slide_selected_columns_up(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  local first_row_content_note_columns = {}
  local first_row_content_effect_columns = {}

  for _, column_index in ipairs(selected_note_columns) do
    first_row_content_note_columns[column_index] = track:line(start_line).note_columns[column_index]
  end
  for _, column_index in ipairs(selected_effect_columns) do
    first_row_content_effect_columns[column_index] = track:line(start_line).effect_columns[column_index]
  end

  for line = start_line, end_line - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    for _, column_index in ipairs(selected_note_columns) do
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    end
    for _, column_index in ipairs(selected_effect_columns) do
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  local last_line = track:line(end_line)
  for _, column_index in ipairs(selected_note_columns) do
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(first_row_content_note_columns[column_index], last_line.note_columns[column_index])
    track:line(start_line).note_columns[column_index]:clear()
  end
  for _, column_index in ipairs(selected_effect_columns) do
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(first_row_content_effect_columns[column_index], last_line.effect_columns[column_index])
    track:line(start_line).effect_columns[column_index]:clear()
  end
end

local function slide_selected_columns_down(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  local last_row_content_note_columns = {}
  local last_row_content_effect_columns = {}

  for _, column_index in ipairs(selected_note_columns) do
    last_row_content_note_columns[column_index] = track:line(end_line).note_columns[column_index]
  end
  for _, column_index in ipairs(selected_effect_columns) do
    last_row_content_effect_columns[column_index] = track:line(end_line).effect_columns[column_index]
  end

  for line = end_line, start_line + 1, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    for _, column_index in ipairs(selected_note_columns) do
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    end
    for _, column_index in ipairs(selected_effect_columns) do
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  local first_line = track:line(start_line)
  for _, column_index in ipairs(selected_note_columns) do
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(last_row_content_note_columns[column_index], first_line.note_columns[column_index])
  end
  for _, column_index in ipairs(selected_effect_columns) do
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(last_row_content_effect_columns[column_index], first_line.effect_columns[column_index])
  end
end

-- Function to get selected columns in the current selection
local function get_selected_columns(track, start_line, end_line)
  local selected_note_columns = {}
  local selected_effect_columns = {}

  for column_index = 1, #track:line(start_line).note_columns do
    for line = start_line, end_line do
      if track:line(line).note_columns[column_index].is_selected then
        table.insert(selected_note_columns, column_index)
        break
      end
    end
  end

  for column_index = 1, #track:line(start_line).effect_columns do
    for line = start_line, end_line do
      if track:line(line).effect_columns[column_index].is_selected then
        table.insert(selected_effect_columns, column_index)
        break
      end
    end
  end

  return selected_note_columns, selected_effect_columns
end

-- Slide selected column content down by one row or the selection if it exists
function PakettiImpulseTrackerSlideDown()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if selection then
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(track_index)
    local start_line = selection.start_line
    local end_line = math.min(selection.end_line, pattern.number_of_lines)
    local selected_note_columns, selected_effect_columns = get_selected_columns(track, start_line, end_line)
    slide_selected_columns_down(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  else
    PakettiImpulseTrackerSlideSelectedColumnDown()
  end
end

-- Slide selected column content up by one row or the selection if it exists
function PakettiImpulseTrackerSlideUp()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if selection then
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(track_index)
    local start_line = selection.start_line
    local end_line = math.min(selection.end_line, pattern.number_of_lines)
    local selected_note_columns, selected_effect_columns = get_selected_columns(track, start_line, end_line)
    slide_selected_columns_up(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  else
    PakettiImpulseTrackerSlideSelectedColumnUp()
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}
--------------
-- Function to copy note columns
function PakettiImpulseTrackerSlideTrackCopyNoteColumns(src, dst)
  for i = 1, #src do
    if src[i] and dst[i] then
      dst[i].note_value = src[i].note_value
      dst[i].instrument_value = src[i].instrument_value
      dst[i].volume_value = src[i].volume_value
      dst[i].panning_value = src[i].panning_value
      dst[i].delay_value = src[i].delay_value
      dst[i].effect_number_value = src[i].effect_number_value
      dst[i].effect_amount_value = src[i].effect_amount_value
    elseif dst[i] then
      dst[i]:clear()
    end
  end
end

-- Function to copy effect columns
function PakettiImpulseTrackerSlideTrackCopyEffectColumns(src, dst)
  for i = 1, #src do
    if src[i] and dst[i] then
      dst[i].number_value = src[i].number_value
      dst[i].amount_value = src[i].amount_value
    elseif dst[i] then
      dst[i]:clear()
    end
  end
end

-- Slide selected track content down by one row in the current pattern
function PakettiImpulseTrackerSlideTrackDown()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines

  -- Store the content of the last row to move it to the first row
  local last_row_note_columns = {}
  local last_row_effect_columns = {}

  for pos, column in song.pattern_iterator:note_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == number_of_lines then
      table.insert(last_row_note_columns, column)
    end
  end

  for pos, column in song.pattern_iterator:effect_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == number_of_lines then
      table.insert(last_row_effect_columns, column)
    end
  end

  -- Slide content down
  for line = number_of_lines, 2, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    PakettiImpulseTrackerSlideTrackCopyNoteColumns(src_line.note_columns, dst_line.note_columns)
    PakettiImpulseTrackerSlideTrackCopyEffectColumns(src_line.effect_columns, dst_line.effect_columns)
  end

  -- Move the last row content to the first row
  local first_line = track:line(1)
  PakettiImpulseTrackerSlideTrackCopyNoteColumns(last_row_note_columns, first_line.note_columns)
  PakettiImpulseTrackerSlideTrackCopyEffectColumns(last_row_effect_columns, first_line.effect_columns)
end

-- Slide selected track content up by one row in the current pattern
function PakettiImpulseTrackerSlideTrackUp()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines

  -- Store the content of the first row to move it to the last row
  local first_row_note_columns = {}
  local first_row_effect_columns = {}

  for pos, column in song.pattern_iterator:note_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == 1 then
      table.insert(first_row_note_columns, column)
    end
  end

  for pos, column in song.pattern_iterator:effect_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == 1 then
      table.insert(first_row_effect_columns, column)
    end
  end

  -- Slide content up
  for line = 1, number_of_lines - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    PakettiImpulseTrackerSlideTrackCopyNoteColumns(src_line.note_columns, dst_line.note_columns)
    PakettiImpulseTrackerSlideTrackCopyEffectColumns(src_line.effect_columns, dst_line.effect_columns)
  end

  -- Move the first row content to the last row
  local last_line = track:line(number_of_lines)
  PakettiImpulseTrackerSlideTrackCopyNoteColumns(first_row_note_columns, last_line.note_columns)
  PakettiImpulseTrackerSlideTrackCopyEffectColumns(first_row_effect_columns, last_line.effect_columns)
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}

renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}
--------------
-- Mix-Paste Tool for Renoise
-- This tool will mix clipboard data with the pattern data in Renoise

local temp_text_path = renoise.tool().bundle_path .. "temp_mixpaste.txt"
local mix_paste_mode = false

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker MixPaste",invoke=function()
  mix_paste()
end}

function mix_paste()
  if not mix_paste_mode then
    -- First invocation: save selection to text file and perform initial paste
    save_selection_to_text()
    local clipboard_data = load_pattern_data_from_text()
    if clipboard_data then
      print("Debug: Clipboard data loaded for initial paste:\n" .. clipboard_data)
      perform_initial_paste(clipboard_data)
      renoise.app():show_status("Initial mix-paste performed. Run Mix-Paste again to perform the final mix.")
    else
      renoise.app():show_error("Failed to load clipboard data from text file.")
    end
    mix_paste_mode = true
  else
    -- Second invocation: load from text file and perform final mix-paste
    local clipboard_data = load_pattern_data_from_text()
    if clipboard_data then
      print("Debug: Clipboard data loaded for final paste:\n" .. clipboard_data)
      perform_final_mix_paste(clipboard_data)
      mix_paste_mode = false
      -- Clear the temp text file
      local file = io.open(temp_text_path, "w")
      file:write("")
      file:close()
    else
      renoise.app():show_error("Failed to load clipboard data from text file.")
    end
  end
end

function save_selection_to_text()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_error("Please make a selection in the pattern first.")
    return
  end

  -- Capture pattern data using rprint and save to text file
  local pattern_data = {}
  local pattern = song:pattern(song.selected_pattern_index)
  local track_index = song.selected_track_index

  for line_index = selection.start_line, selection.end_line do
    local line_data = {}
    local line = pattern:track(track_index):line(line_index)
    for col_index = 1, #line.note_columns do
      local note_column = line:note_column(col_index)
      table.insert(line_data, string.format("%s %02X %02X %02X %02X", 
        note_column.note_string, note_column.instrument_value, 
        note_column.volume_value, note_column.effect_number_value, 
        note_column.effect_amount_value))
    end
    for col_index = 1, #line.effect_columns do
      local effect_column = line:effect_column(col_index)
      table.insert(line_data, string.format("%02X %02X", 
        effect_column.number_value, effect_column.amount_value))
    end
    table.insert(pattern_data, table.concat(line_data, " "))
  end

  -- Save pattern data to text file
  local file = io.open(temp_text_path, "w")
  file:write(table.concat(pattern_data, "\n"))
  file:close()

  print("Debug: Saved pattern data to text file:\n" .. table.concat(pattern_data, "\n"))
end

function load_pattern_data_from_text()
  local file = io.open(temp_text_path, "r")
  if not file then
    return nil
  end
  local clipboard = file:read("*a")
  file:close()
  return clipboard
end

function perform_initial_paste(clipboard_data)
  local song=renoise.song()
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(track_index)

  local clipboard_lines = parse_clipboard_data(clipboard_data)

  for i, clipboard_line in ipairs(clipboard_lines) do
    local line = track:line(line_index + i - 1)
    for col_index, clipboard_note_col in ipairs(clipboard_line.note_columns) do
      if col_index <= #line.note_columns then
        local note_col = line:note_column(col_index)
        if note_col.is_empty then
          note_col.note_string = clipboard_note_col.note_string
          note_col.instrument_value = clipboard_note_col.instrument_value
          note_col.volume_value = clipboard_note_col.volume_value
          note_col.effect_number_value = clipboard_note_col.effect_number_value
          note_col.effect_amount_value = clipboard_note_col.effect_amount_value
        end
      end
    end
    for col_index, clipboard_effect_col in ipairs(clipboard_line.effect_columns) do
      if col_index <= #line.effect_columns then
        local effect_col = line:effect_column(col_index)
        if effect_col.is_empty then
          effect_col.number_value = clipboard_effect_col.number_value
          effect_col.amount_value = clipboard_effect_col.amount_value
        end
      end
    end
  end
end

function perform_final_mix_paste(clipboard_data)
  local song=renoise.song()
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(track_index)

  local clipboard_lines = parse_clipboard_data(clipboard_data)

  for i, clipboard_line in ipairs(clipboard_lines) do
    local line = track:line(line_index + i - 1)
    for col_index, clipboard_note_col in ipairs(clipboard_line.note_columns) do
      if col_index <= #line.note_columns then
        local note_col = line:note_column(col_index)
        if not note_col.is_empty then
          if clipboard_note_col.effect_number_value > 0 then
            note_col.effect_number_value = clipboard_note_col.effect_number_value
            note_col.effect_amount_value = clipboard_note_col.effect_amount_value
          end
        end
      end
    end
    for col_index, clipboard_effect_col in ipairs(clipboard_line.effect_columns) do
      if col_index <= #line.effect_columns then
        local effect_col = line:effect_column(col_index)
        if not effect_col.is_empty then
          if clipboard_effect_col.number_value > 0 then
            effect_col.number_value = clipboard_effect_col.number_value
            effect_col.amount_value = clipboard_effect_col.amount_value
          end
        end
      end
    end
  end
end

function parse_clipboard_data(clipboard)
  local lines = {}
  for line in clipboard:gmatch("[^\r\n]+") do
    table.insert(lines, parse_line(line))
  end
  return lines
end

function parse_line(line)
  local note_columns = {}
  local effect_columns = {}
  for note_col_data in line:gmatch("(%S+ %S+ %S+ %S+ %S+)") do
    table.insert(note_columns, parse_note_column(note_col_data))
  end
  for effect_col_data in line:gmatch("(%S+ %S+)") do
    table.insert(effect_columns, parse_effect_column(effect_col_data))
  end
  return {note_columns=note_columns,effect_columns=effect_columns}
end

function parse_note_column(data)
  local note, instrument, volume, effect_number, effect_amount = data:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
  return {
    note_string=note,
    instrument_value=tonumber(instrument, 16),
    volume_value=tonumber(volume, 16),
    effect_number_value=tonumber(effect_number, 16),
    effect_amount_value=tonumber(effect_amount, 16),
  }
end

function parse_effect_column(data)
  local number, amount = data:match("(%S+) (%S+)")
  return {
    number_value=tonumber(number, 16),
    amount_value=tonumber(amount, 16),
  }
end

--Wipes the pattern data, but not the samples or instruments.
--WARNING: Does not reset current filename.
-- TODO

function wipeSongPattern()
local s=renoise.song()
  for i=1,300 do
    if s.patterns[i].is_empty==false then
    s.patterns[i]:clear()
    renoise.song().patterns[i].number_of_lines=64
    else 
    print ("Encountered empty pattern, not deleting")
    renoise.song().patterns[i].number_of_lines=64
    end
  end
end
renoise.tool():add_keybinding{name="Global:Paketti:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
----

function get_master_track_index()
  for k,v in ripairs(renoise.song().tracks)
    do if v.type == renoise.Track.TRACK_TYPE_MASTER then return k end  
  end
end

function AutoGapper()
renoise.song().tracks[get_master_track_index()].visible_effect_columns = 4  
local gapper=nil
renoise.app().window.active_lower_frame=1
renoise.app().window.lower_frame_is_visible=true
  loadnative("Audio/Effects/Native/Filter")
  loadnative("Audio/Effects/Native/*LFO")
  renoise.song().selected_track.devices[2].parameters[2].value=2
  renoise.song().selected_track.devices[2].parameters[3].value=1
  renoise.song().selected_track.devices[2].parameters[7].value=2
--  renoise.song().selected_track.devices[3].parameters[5].value=0.0074
local gapper=renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines*2*4
  renoise.song().selected_track.devices[2].parameters[6].value_string=tostring(gapper)
renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[4].number_string = "18"
end

renoise.tool():add_keybinding{name="Global:Paketti:Add Filter & LFO (AutoGapper)",invoke=function() AutoGapper() end}

----------
function glideamount(amount)
local counter=nil 
for i=renoise.song().selection_in_pattern.start_line,renoise.song().selection_in_pattern.end_line 
do renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].number_string="0G" 
counter=renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].amount_value+amount 

if counter > 255 then counter=255 end
if counter < 1 then counter=0 
end
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].amount_value=counter 
end
end

----------------------------------------
function move_up(chg)
local sindex=renoise.song().selected_line_index
local s= renoise.song()
local note=s.selected_note_column
--This switches currently selected row but doesn't 
--move the note
--s.selected_line_index = (sindex+chg)
-- moving note up, applying correct delay value and moving cursor up goes here
end
--movedown
function move_down(chg)
local sindex=renoise.song().selected_line_index
local s= renoise.song()
--This switches currently selected row but doesn't 
--move the note
--s.selected_line_index = (sindex+chg)
-- moving note down, applying correct delay value and moving cursor down goes here
end


-- Function to adjust the delay value of the selected note column within the current phrase
function delay(seconds)
    local command = "sleep " .. tonumber(seconds)
    os.execute(command)
end
---------------------------
-- Global variable to track which column cycling is active for
local active_cycling_column = nil

function pattern_line_notifier(pos)
  local s = renoise.song()
  local t = s.transport
  local pattern = s.patterns[s.selected_pattern_index]
  
  if t.edit_step == 0 then
    local new_col = s.selected_note_column_index + 1
    local max_cols = s.tracks[s.selected_track_index].visible_note_columns
    
    if new_col > max_cols then
      -- When reaching last column, move to next line or wrap
      local new_line = s.selected_line_index + 1
      
      if new_line > pattern.number_of_lines then
        new_line = 1  -- Wrap to first line if at end of pattern
      end
      
      s.selected_line_index = new_line
      s.selected_note_column_index = 1
    else
      s.selected_note_column_index = new_col
    end
    return
  end

  -- Existing code for edit_step > 0 cases
  local countline = s.selected_line_index + 1
  if t.edit_step > 1 then
    countline = countline - 1
  end
  
  if countline > pattern.number_of_lines then
    countline = 1
  end
  
  s.selected_line_index = countline
  local colnumber = s.selected_note_column_index + 1
  
  if colnumber > s.tracks[s.selected_track_index].visible_note_columns then
    s.selected_note_column_index = 1
    return
  end
  
  s.selected_note_column_index = colnumber
end

function startcolumncycling(number)
  local s = renoise.song()
  local pattern = s.patterns[s.selected_pattern_index]
  local was_active = pattern:has_line_notifier(pattern_line_notifier)

  if number then
    -- Store the current column before displayNoteColumn changes it
    local original_column = s.selected_note_column_index
    
    -- Column-specific activation/deactivation
    if was_active then
      -- Cycling is currently on, turn it off
      pattern:remove_line_notifier(pattern_line_notifier)
      renoise.app():show_status(number .. " Column Cycle Keyjazz Off")
    else
      -- Cycling is currently off, turn it on
      pattern:add_line_notifier(pattern_line_notifier)
      renoise.app():show_status(number .. " Column Cycle Keyjazz On")
    end
  else
    -- General toggle (no specific column)
    if was_active then
      pattern:remove_line_notifier(pattern_line_notifier)
      renoise.app():show_status("Column Cycling Off")
    else
      pattern:add_line_notifier(pattern_line_notifier)
      renoise.app():show_status(s.selected_note_column_index .. " Column Cycle Keyjazz On")
    end
  end
end

for cck=1,12 do 
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz " .. formatDigits(2,cck),invoke=function() displayNoteColumn(cck) startcolumncycling(cck) end} 
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz " .. formatDigits(2,cck),invoke=function() displayNoteColumn(cck) startcolumncycling(cck) end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Start/Stop Column Cycling",invoke=function() startcolumncycling() end}

function ColumnCycleKeyjazzSpecial(number)
displayNoteColumn(number) 
GenerateDelayValue("pattern")
renoise.song().transport.edit_mode=true
renoise.song().transport.edit_step=0
renoise.song().selected_note_column_index=1
startcolumncycling(number)
end

for ccks=3,12 do
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz Special (" .. ccks .. ")",invoke=function() ColumnCycleKeyjazzSpecial(ccks) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz Special (" .. ccks .. ")",invoke=function() ColumnCycleKeyjazzSpecial(ccks) end}
end
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz Special (2)",invoke=function() ColumnCycleKeyjazzSpecial(2) end}

---
-- Toggle mute state functions
function toggleMuteSelectedTrack()
  local track = renoise.song().selected_track
  if track.mute_state == 1 then
    track.mute_state = 3
  elseif track.mute_state == 2 or track.mute_state == 3 then
    track.mute_state = 1
  end
end

function toggleMuteTrack(track_number)
  local song = renoise.song()
  if track_number <= #song.tracks then
    local track = song.tracks[track_number]
    if track.mute_state == 1 then
      track.mute_state = 3
    elseif track.mute_state == 2 or track.mute_state == 3 then
      track.mute_state = 1
    end
  end
end

-- Explicit mute functions
function muteSelectedTrack()
  renoise.song().selected_track.mute_state = 3
end

function muteTrack(track_number)
  local song = renoise.song()
  if track_number <= #song.tracks then
    song.tracks[track_number].mute_state = 3
  end
end

-- Explicit unmute functions
function unmuteSelectedTrack()
  renoise.song().selected_track.mute_state = 1
end

function unmuteTrack(track_number)
  local song = renoise.song()
  if track_number <= #song.tracks then
    song.tracks[track_number].mute_state = 1
  end
end

-- Keybindings and MIDI mappings for selected track
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute/Unmute of Selected Track", invoke=toggleMuteSelectedTrack}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute/Unmute of Selected Track", invoke=function(message) if message:is_trigger() then toggleMuteSelectedTrack() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Mute Selected Track", invoke=muteSelectedTrack}
renoise.tool():add_midi_mapping{name="Paketti:Mute Selected Track", invoke=function(message) if message:is_trigger() then muteSelectedTrack() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Unmute Selected Track", invoke=unmuteSelectedTrack}
renoise.tool():add_midi_mapping{name="Paketti:Unmute Selected Track", invoke=function(message) if message:is_trigger() then unmuteSelectedTrack() end end}

-- Keybindings and MIDI mappings for tracks 1-16
for i = 1, 16 do
  local track_num_str = string.format("%02d", i)
  renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute/Unmute of Track " .. track_num_str, invoke=function() toggleMuteTrack(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Mute Track " .. track_num_str, invoke=function() muteTrack(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Unmute Track " .. track_num_str, invoke=function() unmuteTrack(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute/Unmute of Track " .. track_num_str, invoke=function(message) if message:is_trigger() then toggleMuteTrack(i) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Mute Track " .. track_num_str, invoke=function(message) if message:is_trigger() then muteTrack(i) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Unmute Track " .. track_num_str, invoke=function(message) if message:is_trigger() then unmuteTrack(i) end end}
end

-- Group Samples by Name to New Instruments Feature
function PakettiGroupSamplesByName()
  local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix
  local song = renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No valid instrument with samples selected.")
    return
  end

  -- Check if instrument has slices - we can't process sliced instruments
  if #instrument.samples > 0 and #instrument.samples[1].slice_markers > 0 then
    renoise.app():show_status("Cannot group slices - slices cannot be renamed. Use with multi-sample instruments only.")
    return
  end

  -- Need at least 2 samples to group
  if #instrument.samples < 2 then
    renoise.app():show_status("Need at least 2 samples in instrument to group by name.")
    return
  end

  -- Helper function to extract the base name from a sample name
  local function extract_base_name(name)
    -- Simple approach: take the first word before any numbers, notes, or separators
    local base_name = name
    
    -- Extract the first word (everything before first space, number, or separator)
    base_name = base_name:match("^([^%s%d_%-%.]+)")
    
    if not base_name or base_name == "" then
      -- Fallback: take everything before first number
      base_name = name:match("^([^%d]+)")
      if base_name then
        base_name = base_name:gsub("[%s_%-%.]+$", "") -- trim trailing separators
      end
    end
    
    if not base_name or base_name == "" then
      base_name = name -- ultimate fallback
    end
    
    -- Convert to lowercase for consistent grouping
    base_name = base_name:lower()
    
    print(string.format("  Base name extraction: '%s' -> '%s'", name, base_name))
    return base_name
  end

  -- Helper function to create a new drumkit instrument
  local function create_drumkit_instrument(index)
    song:insert_instrument_at(index)
    song.selected_instrument_index = index
    
    -- Load the default drumkit instrument template
    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
    
    local success, error_msg = pcall(function()
      renoise.app():load_instrument(defaultInstrument)
    end)
    
    if not success then
      -- Try fallback
      pcall(function()
        renoise.app():load_instrument(renoise.tool().bundle_path .. fallbackInstrument)
      end)
    end
    
    local new_instrument = song.instruments[index]
    return new_instrument
  end

  -- Helper function to copy sample to new instrument
  local function copy_sample_to_instrument(source_sample, target_instrument, key_index)
    local insert_position = #target_instrument.samples + 1
    print(string.format("  Inserting sample at position %d", insert_position))
    local new_sample = target_instrument:insert_sample_at(insert_position)
    
    -- Copy the entire sample
    new_sample:copy_from(source_sample)
    print(string.format("  Copied sample '%s' -> '%s'", source_sample.name, new_sample.name))
    
    -- Set up sequential key mapping starting from C-0
    local mapping = new_sample.sample_mapping
    mapping.base_note = key_index -- Sequential notes starting from 0 (C-0)
    mapping.note_range = {key_index, key_index} -- Each sample gets exactly one key
    mapping.velocity_range = {0, 127}
    mapping.map_velocity_to_volume = true
    
    return new_sample
  end

  -- Collect and group samples by base name
  local groups = {}
  
  print("Processing samples from instrument: " .. instrument.name)
  
  for i, sample in ipairs(instrument.samples) do
    local base_name = extract_base_name(sample.name)
    
    if not groups[base_name] then
      groups[base_name] = {}
    end
    
    table.insert(groups[base_name], sample)
    
    print(string.format("Sample %d ('%s') grouped under '%s'", i, sample.name, base_name))
  end

  -- Check if we actually have groups (more than one sample with same base name)
  local has_groups = false
  for group_name, group_samples in pairs(groups) do
    if #group_samples > 1 then
      has_groups = true
      break
    end
  end
  
  if not has_groups then
    renoise.app():show_status("No samples found with matching base names to group.")
    return
  end

  -- Create drumkit instruments for each group that has more than one sample
  local insert_index = selected_instrument_index + 1
  local created_instruments = 0
  
  for group_name, group_samples in pairs(groups) do
    if #group_samples > 1 then -- Only create instruments for groups with multiple samples
      print(string.format("Creating drumkit instrument for '%s' with %d samples", group_name, #group_samples))
      
      local new_instrument = create_drumkit_instrument(insert_index)
      
      -- Clear only placeholder samples from the drumkit template before copying real samples
      local deleted_count = 0
      for i = #new_instrument.samples, 1, -1 do
        if new_instrument.samples[i].name == "Placeholder for drumkit" then
          print(string.format("Deleting placeholder sample: '%s'", new_instrument.samples[i].name))
          new_instrument:delete_sample_at(i)
          deleted_count = deleted_count + 1
        end
      end
      print(string.format("Deleted %d placeholder samples, %d samples remain", deleted_count, #new_instrument.samples))
      
      -- Copy all samples in this group to the new instrument
      for i, sample in ipairs(group_samples) do
        local key_index = i - 1 -- Start from 0 (C-0), then 1 (C#-0), 2 (D-0), etc.
        print(string.format("Copying sample %d: '%s' to key %d", i, sample.name, key_index))
        copy_sample_to_instrument(sample, new_instrument, key_index)
        print(string.format("After copying, instrument has %d samples", #new_instrument.samples))
      end
      
      -- Set the instrument name AFTER all copying is complete
      local instrument_name = string.format("%s (%d)", group_name, #group_samples)
      new_instrument.name = instrument_name
      print(string.format("Set final instrument name: '%s'", new_instrument.name))
      
      insert_index = insert_index + 1
      created_instruments = created_instruments + 1
      
      print(string.format("Created instrument '%s' with %d samples", group_name, #group_samples))
    end
  end

  -- Set octave and show completion status
  --song.transport.octave = 3
  
  local total_grouped_samples = 0
  for _, group_samples in pairs(groups) do
    if #group_samples > 1 then
      total_grouped_samples = total_grouped_samples + #group_samples
    end
  end
  
  renoise.app():show_status(string.format(
    "Grouped %d samples into %d drumkit instruments by name", 
    total_grouped_samples, created_instruments
  ))
  
  print(string.format("=== GROUPING COMPLETE ==="))
  print(string.format("Source: %d samples from '%s'", #instrument.samples, instrument.name))
  print(string.format("Created: %d drumkit instruments", created_instruments))
  for group_name, group_samples in pairs(groups) do
    if #group_samples > 1 then
      print(string.format("  - '%s': %d samples", group_name, #group_samples))
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_midi_mapping{name="Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}

-- Pure Sinewave Generator Function
-- Creates one complete sine wave cycle from 0.5 to 1.0 to 0.5 to 0.0 to 0.5
-- Parameters:
--   sample_rate: Sample rate (e.g., 44100)
--   frequency: Frequency of the sine wave (e.g., 440 for A4)
--   duration: Duration in seconds (optional, defaults to one cycle)
function generatePureSinewave(sample_rate, frequency, duration)
  sample_rate = sample_rate or 44100
  frequency = frequency or 440
  
  -- Use 1024 frames for high resolution, with one complete cycle
  local num_samples = 1024
  local samples = {}
  
  print("Generating sine wave:")
  print("- Sample rate: " .. sample_rate .. " Hz")
  print("- Frequency: " .. frequency .. " Hz (for naming)")
  print("- Number of samples: " .. num_samples .. " (one complete cycle, high resolution)")
  
  -- Generate the sine wave samples for exactly one cycle over 1024 frames
  for i = 0, num_samples - 1 do
    -- Calculate the phase (0 to 2*pi for one complete cycle over 1024 frames)
    local phase = (2.0 * math.pi * i) / num_samples
    
    -- Calculate sine wave value (-1 to 1)
    local sine_value = math.sin(phase)
    
    -- Scale and offset to go from 0.5 to 1.0 to 0.5 to 0.0 to 0.5
    -- sine_value * 0.5 + 0.5 gives us 0.0 to 1.0 range with 0.5 center
    local sample_value = sine_value * 0.5 + 0.5
    
    -- Store the sample (clamped to ensure it stays in range)
    samples[i + 1] = math.max(0.0, math.min(1.0, sample_value))
  end
  
  print("Sine wave generation completed")
  print("Sample range: " .. string.format("%.3f", samples[1]) .. " to " .. string.format("%.3f", samples[math.floor(num_samples/2) + 1]) .. " to " .. string.format("%.3f", samples[num_samples]))
  
  return samples, num_samples
end

-- Function to create a sine wave sample in Renoise
function createSinewaveSample(sample_rate, frequency, duration)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  
  -- Check if we have a selected instrument
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument available")
    return
  end
  
  -- Generate the sine wave data
  local samples, num_samples = generatePureSinewave(sample_rate, frequency, duration)
  
  -- Create a new sample in the instrument
  local sample_index = #instrument.samples + 1
  instrument:insert_sample_at(sample_index)
  local sample = instrument.samples[sample_index]
  
  -- Set sample properties
  sample.name = "Sine " .. frequency .. "Hz"
  
  -- Create sample buffer
  sample.sample_buffer:create_sample_data(sample_rate, 16, 1, num_samples)
  local buffer = sample.sample_buffer
  
  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    -- Write the sine wave data to the sample buffer
    for i = 1, num_samples do
      -- Convert 0.0-1.0 range to -1.0 to 1.0 range for sample buffer
      local buffer_value = (samples[i] - 0.5) * 2.0
      buffer:set_sample_data(1, i, buffer_value)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set up sample mapping
    sample.sample_mapping.base_note = 48 -- C-4
    sample.sample_mapping.note_range = {0, 119}
    sample.sample_mapping.velocity_range = {0, 127}
    
    -- Add loop from 1st frame to last frame
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = buffer.number_of_frames
    
    -- Set instrument name
    instrument.name = "sinewave[" .. frequency .. "hz][" .. buffer.number_of_frames .. " frames]"
    
    -- Go to sample editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    print("Created sine wave sample: " .. sample.name)
    print("Sample properties:")
    print("- Index: " .. sample_index)
    print("- Sample rate: " .. buffer.sample_rate .. " Hz")
    print("- Bit depth: " .. buffer.bit_depth .. " bit")
    print("- Channels: " .. buffer.number_of_channels)
    print("- Length: " .. buffer.number_of_frames .. " frames")
    print("- Loop: " .. sample.loop_start .. " to " .. sample.loop_end)
    print("- Duration: " .. string.format("%.4f", buffer.number_of_frames / buffer.sample_rate) .. " seconds")
    
    renoise.app():show_status("Created sine wave sample: " .. sample.name)
  else
    renoise.app():show_status("Error: Could not create sample data")
    print("Error: Sample buffer has no data")
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to generate amplitude modulated sine wave
function generateAmplitudeModulatedSinewave(sample_rate, frequency, modulation_multiplier, modulation_amplitude)
  sample_rate = sample_rate or 44100
  frequency = frequency or 440
  modulation_multiplier = modulation_multiplier or 20
  modulation_amplitude = modulation_amplitude or 30
  
  -- Use 1024 frames for high resolution, with one complete cycle
  local num_samples = 1024
  local samples = {}
  
  print("Generating amplitude modulated sine wave:")
  print("- Sample rate: " .. sample_rate .. " Hz")
  print("- Base frequency: " .. frequency .. " Hz (for naming)")
  print("- Modulation: " .. modulation_multiplier .. "x faster")
  print("- Modulation amplitude: " .. modulation_amplitude .. "%")
  print("- Number of samples: " .. num_samples .. " (one base cycle, high resolution)")
  
  -- Convert amplitude percentage to decimal (0-100% -> 0.0-1.0)
  local amp_factor = modulation_amplitude / 100.0
  
  -- Generate the amplitude modulated sine wave
  for i = 0, num_samples - 1 do
    -- Master sine wave: one complete cycle over 1024 frames
    -- Generate directly in 0.25 to 0.75 range (centered at 0.5)
    local master_phase = (2.0 * math.pi * i) / num_samples
    local master_sine = math.sin(master_phase)
    local base_sample = master_sine * 0.25 + 0.5  -- Scale to 0.25-0.75 range
    
    -- Modulation sine wave: faster cycles for the tiny ripples
    local mod_phase = (2.0 * math.pi * modulation_multiplier * i) / num_samples
    local mod_sine = math.sin(mod_phase)
    
    -- Apply amplitude modulation to the base sample
    -- modulation_sine ranges from -1 to 1, so we scale it by amp_factor
    local modulated_sample = base_sample * (1.0 + amp_factor * mod_sine)
    
    -- Store the sample (clamped to ensure it stays in valid range)
    samples[i + 1] = math.max(0.0, math.min(1.0, modulated_sample))
  end
  
  print("Amplitude modulated sine wave generation completed")
  print("Sample range: " .. string.format("%.3f", samples[1]) .. " to " .. string.format("%.3f", samples[math.floor(num_samples/2) + 1]) .. " to " .. string.format("%.3f", samples[num_samples]))
  
  return samples, num_samples
end

-- Function to create amplitude modulated sine wave sample in Renoise
function createAmplitudeModulatedSinewaveSample(sample_rate, frequency, modulation_multiplier, modulation_amplitude)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  
  -- Check if we have a selected instrument
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument available")
    return
  end
  
  -- Generate the amplitude modulated sine wave data
  local samples, num_samples = generateAmplitudeModulatedSinewave(sample_rate, frequency, modulation_multiplier, modulation_amplitude)
  
  -- Create a new sample in the instrument
  local sample_index = #instrument.samples + 1
  instrument:insert_sample_at(sample_index)
  local sample = instrument.samples[sample_index]
  
  -- Set sample properties
  sample.name = "AM Sine " .. frequency .. "Hz (mod " .. modulation_multiplier .. "x, amp " .. (modulation_amplitude or 30) .. "%)"
  
  -- Create sample buffer
  sample.sample_buffer:create_sample_data(sample_rate, 16, 1, num_samples)
  local buffer = sample.sample_buffer
  
  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    -- Write the sine wave data to the sample buffer
    for i = 1, num_samples do
      -- Convert 0.0-1.0 range to -1.0 to 1.0 range for sample buffer
      local buffer_value = (samples[i] - 0.5) * 2.0
      buffer:set_sample_data(1, i, buffer_value)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set up sample mapping
    sample.sample_mapping.base_note = 48 -- C-4
    sample.sample_mapping.note_range = {0, 119}
    sample.sample_mapping.velocity_range = {0, 127}
    
    -- Add loop from 1st frame to last frame
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = buffer.number_of_frames
    
    -- Set instrument name
    instrument.name = "am_sinewave[" .. frequency .. "hz][mod " .. modulation_multiplier .. "x][amp " .. (modulation_amplitude or 30) .. "%][" .. buffer.number_of_frames .. " frames]"
    
    -- Go to sample editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    print("Created amplitude modulated sine wave sample: " .. sample.name)
    renoise.app():show_status("Created AM sine wave sample: " .. sample.name)
  else
    renoise.app():show_status("Error: Could not create sample data")
    print("Error: Sample buffer has no data")
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function for custom frequency sine wave generation
function createCustomSinewave()
  local vb = renoise.ViewBuilder()
  local frequency_text = vb:textfield{
    text = "440",
    width = 80
  }
  
  local dialog_content = vb:column{
    margin = 10,
    vb:row{
      vb:text{text = "Enter frequency in Hz (1-20000):"}
    },
    vb:row{
      frequency_text
    },
    vb:row{
      vb:button{
        text = "OK",
        width = 80,
        notifier = function()
          local freq_str = frequency_text.text
          local freq = tonumber(freq_str)
          if freq and freq > 0 and freq <= 20000 then
            createSinewaveSample(44100, freq, nil)
            -- Close dialog by setting it to nil - will be handled by dialog framework
          else
            renoise.app():show_status("Invalid frequency. Please enter a value between 1-20000 Hz")
          end
        end
      },
      vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          -- Cancel button - dialog will close automatically
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  renoise.app():show_custom_dialog("Sine Wave Generator", dialog_content, keyhandler)
end

-- Function for custom amplitude modulated sine wave generation
function createCustomAmplitudeModulatedSinewave()
  local vb = renoise.ViewBuilder()
  local frequency_text = vb:textfield{
    text = "440",
    width = 80
  }
  local modulation_text = vb:textfield{
    text = "20",
    width = 80
  }
  local amplitude_text = vb:textfield{
    text = "30",
    width = 80
  }
  
  local dialog_content = vb:column{
    margin = 10,
    vb:row{
      vb:text{text = "Enter base frequency in Hz (1-20000):"}
    },
    vb:row{
      frequency_text
    },
    vb:row{
      vb:text{text = "Enter modulation multiplier (1-1000):"}
    },
    vb:row{
      modulation_text
    },
    vb:row{
      vb:text{text = "Enter modulation amplitude % (1-100):"}
    },
    vb:row{
      amplitude_text
    },
    vb:row{
      vb:button{
        text = "OK",
        width = 80,
        notifier = function()
          local freq_str = frequency_text.text
          local mod_str = modulation_text.text
          local amp_str = amplitude_text.text
          local freq = tonumber(freq_str)
          local mod = tonumber(mod_str)
          local amp = tonumber(amp_str)
          if freq and freq > 0 and freq <= 20000 and 
             mod and mod > 0 and mod <= 1000 and
             amp and amp > 0 and amp <= 100 then
            createAmplitudeModulatedSinewaveSample(44100, freq, mod, amp)
            -- Keep dialog open for multiple generations
            renoise.app():show_status("Generated AM sine wave: " .. freq .. "Hz, mod " .. mod .. "x, amp " .. amp .. "%")
          else
            renoise.app():show_status("Invalid values. Frequency: 1-20000 Hz, Modulation: 1-1000x, Amplitude: 1-100%")
          end
        end
      },
      vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          -- Cancel button - dialog will close automatically
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  renoise.app():show_custom_dialog("AM Sine Wave Generator", dialog_content, keyhandler)
end


renoise.tool():add_keybinding{name = "Global:Paketti:Generate Pure Sinewave 440Hz", invoke = function() createSinewaveSample(44100, 440, nil) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Pure Sinewave 1000Hz", invoke = function() createSinewaveSample(44100, 1000, nil) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Pure Sinewave Custom", invoke = createCustomSinewave}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate AM Sinewave 440Hz (20x mod)", invoke = function() createAmplitudeModulatedSinewaveSample(44100, 440, 20, 30) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate AM Sinewave 1000Hz (20x mod)", invoke = function() createAmplitudeModulatedSinewaveSample(44100, 1000, 20, 30) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate AM Sinewave Custom", invoke = createCustomAmplitudeModulatedSinewave}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:Pure Sinewave 440Hz",invoke = function() createSinewaveSample(44100, 440, nil) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:Pure Sinewave 1000Hz",invoke = function() createSinewaveSample(44100, 1000, nil) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:Pure Sinewave Custom Frequency",invoke = createCustomSinewave}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:AM Sinewave 440Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 440, 20, 30) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:AM Sinewave 1000Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 1000, 20, 30) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:AM Sinewave Custom",invoke = createCustomAmplitudeModulatedSinewave}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:Pure Sinewave 440Hz",invoke = function() createSinewaveSample(44100, 440, nil) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:Pure Sinewave 1000Hz",invoke = function() createSinewaveSample(44100, 1000, nil) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:Pure Sinewave Custom Frequency",invoke = createCustomSinewave}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:AM Sinewave 440Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 440, 20, 30) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:AM Sinewave 1000Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 1000, 20, 30) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:AM Sinewave Custom",invoke = createCustomAmplitudeModulatedSinewave}
--------
-- Play Current Line in Phrase (CORRECTED)
function PakettiPlayCurrentLineInPhrase()
  -- Ensure we're in phrase editor
  if renoise.app().window.active_middle_frame ~= 
     renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    renoise.app():show_status("Switch to phrase editor first")
    return
  end
  
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  if phrase.is_empty then
    renoise.app():show_status("Selected phrase is empty")
    return
  end
  
  -- Get current cursor position in phrase
  local current_line = song.selected_phrase_line_index
  
  -- Check if current line exists
  if current_line > phrase.number_of_lines then
    renoise.app():show_status("Invalid phrase line index")
    return
  end
  
  -- Get the phrase line
  local phrase_line = phrase:line(current_line)
  
  if phrase_line.is_empty then
    renoise.app():show_status("Current phrase line is empty")
    return
  end
  
  -- Build temporary pattern with the phrase line content
  local temp_pattern = song:pattern(song.selected_pattern_index)
  local temp_track = temp_pattern:track(song.selected_track_index)
  local temp_line = temp_track:line(song.selected_line_index)
  
  -- Copy phrase line content to pattern for playback
  temp_line:copy_from(phrase_line)
  
  -- Play the line using the standard pattern trigger
  if renoise.API_VERSION >= 6.2 then
    song:trigger_pattern_line(song.selected_line_index)
  else
    local t = song.transport
    t:start_at(song.selected_line_index)
    local start_time = os.clock()
    while (os.clock() - start_time < 0.4) do
      -- Wait for playback
    end
    t:stop()
  end
  
  renoise.app():show_status("Played phrase line " .. current_line)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Phrases:Play Current Line in Phrase", invoke = PakettiPlayCurrentLineInPhrase}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Play Current Line in Phrase", invoke = PakettiPlayCurrentLineInPhrase}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Play Current Line in Phrase", invoke = PakettiPlayCurrentLineInPhrase}
renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line in Phrase", invoke = PakettiPlayCurrentLineInPhrase}
renoise.tool():add_midi_mapping{name="Paketti:Play Current Line in Phrase [Trigger]", invoke = function(message) if message:is_trigger() then PakettiPlayCurrentLineInPhrase() end end}

--------
function detect_zero_crossings()
  local song=renoise.song()
  local sample = song.selected_sample

  if not sample or not sample.sample_buffer.has_sample_data then
      renoise.app():show_status("No sample selected or sample has no data")
      return
  end

  local buffer = sample.sample_buffer
  local zero_crossings = {}
  local max_silence = 0.002472  -- Your maximum silence threshold

  print("\n=== Sample Buffer Analysis ===")
  print("Sample length:", buffer.number_of_frames, "frames")
  print("Number of channels:", buffer.number_of_channels)
  print("Scanning for zero crossings (threshold:", max_silence, ")")

  -- Scan through sample data in chunks for better performance
  local chunk_size = 1000
  local last_was_silence = nil

  for frame = 1, buffer.number_of_frames do
      local value = buffer:sample_data(1, frame)
      local is_silence = (value >= 0 and value <= max_silence)
      
      -- Detect transition points between silence and non-silence
      if last_was_silence ~= nil and last_was_silence ~= is_silence then
          table.insert(zero_crossings, frame)
      end
      
      last_was_silence = is_silence
      
      -- Show progress every chunk_size frames
      if frame % chunk_size == 0 or frame == buffer.number_of_frames then
          renoise.app():show_status(string.format("Analyzing frames %d to %d of %d", 
              math.max(1, frame-chunk_size+1), frame, buffer.number_of_frames))
      end
  end

  -- Show results
  local status_message = string.format("\nFound %d zero crossings", #zero_crossings)
  renoise.app():show_status(status_message)
  print(status_message)

  -- Animate through the zero crossings
  if #zero_crossings >= 2 then
      -- Create a coroutine to handle the animation
      local co = coroutine.create(function()
          for i = 1, #zero_crossings - 1, 2 do  -- Step by 2 to get pairs of transitions
              if i + 1 <= #zero_crossings then
                  buffer.selection_range = {
                      zero_crossings[i],
                      zero_crossings[i + 1]
                  }
                  renoise.app():show_status(string.format("Selecting zero crossings %d to %d (frames %d to %d)", 
                      i, i+1, zero_crossings[i], zero_crossings[i + 1]))
                  coroutine.yield()
              end
          end
      end)
      
      -- Add timer to step through coroutine
      renoise.tool():add_timer(function()
          if coroutine.status(co) ~= "dead" then
              local success, err = coroutine.resume(co)
              if not success then
                  print("Error:", err)
                  return false
              end
              return true
          end
          return false
      end, 0.5)
  else
      print("Not enough zero crossings found to set loop points")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Detect Zero Crossings",invoke=detect_zero_crossings}

--------
-- Load RingMod Instrument Functions
--------

function PakettiLoadRingModInstrument()
  local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix
  local song = renoise.song()
  local index = song.selected_instrument_index + 1
  
  -- Insert new instrument and select it
  song:insert_instrument_at(index)
  song.selected_instrument_index = index
  
  -- Load the RingMod instrument template
  local ringmod_instrument = "Presets" .. separator .. "RingMod.xrni"
  
  local success, error_msg = pcall(function()
    renoise.app():load_instrument(renoise.tool().bundle_path .. ringmod_instrument)
  end)
  
  if success then
    renoise.app():show_status("RingMod instrument loaded successfully")
  else
    renoise.app():show_status("Failed to load RingMod.xrni: " .. tostring(error_msg))
  end
end

function PakettiLoadRingModLegacyInstrument()
  local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix
  local song = renoise.song()
  local index = song.selected_instrument_index + 1
  
  -- Insert new instrument and select it
  song:insert_instrument_at(index)
  song.selected_instrument_index = index
  
  -- Load the RingMod Legacy instrument template
  local ringmod_legacy_instrument = "Presets" .. separator .. "RingModLegacy.xrni"
  
  local success, error_msg = pcall(function()
    renoise.app():load_instrument(renoise.tool().bundle_path .. ringmod_legacy_instrument)
  end)
  
  if success then
    renoise.app():show_status("RingMod Legacy instrument loaded successfully")
  else
    renoise.app():show_status("Failed to load RingModLegacy.xrni: " .. tostring(error_msg))
  end
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Load RingMod Instrument", invoke = PakettiLoadRingModInstrument}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Load RingMod Legacy Instrument", invoke = PakettiLoadRingModLegacyInstrument}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Load RingMod Instrument", invoke = PakettiLoadRingModInstrument}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Instruments:Load RingMod Legacy Instrument", invoke = PakettiLoadRingModLegacyInstrument}

renoise.tool():add_keybinding{name="Global:Paketti:Load RingMod Instrument", invoke = PakettiLoadRingModInstrument}
renoise.tool():add_keybinding{name="Global:Paketti:Load RingMod Legacy Instrument", invoke = PakettiLoadRingModLegacyInstrument}

renoise.tool():add_midi_mapping{name="Paketti:Load RingMod Instrument [Trigger]", invoke = function(message) if message:is_trigger() then PakettiLoadRingModInstrument() end end}
renoise.tool():add_midi_mapping{name="Paketti:Load RingMod Legacy Instrument [Trigger]", invoke = function(message) if message:is_trigger() then PakettiLoadRingModLegacyInstrument() end end}

-----------------------------------------------------------------------
-- Solo Only Tracks with Pattern Data in Current Pattern
-----------------------------------------------------------------------

-- Helper function to check if a track has pattern data in current pattern
function PakettiTrackHasPatternDataInCurrentPattern(track_index)
  local song = renoise.song()
  
  -- Get current selected pattern index
  local current_pattern_index = song.selected_pattern_index
  if not current_pattern_index then
    return false
  end
  
  local pattern = song.patterns[current_pattern_index]
  if not pattern then
    return false
  end
  
  local pattern_track = pattern:track(track_index)
  if not pattern_track then
    return false
  end
  
  -- Check each line in the pattern for note data or effect data
  for line_index = 1, pattern.number_of_lines do
    local line = pattern_track:line(line_index)
    
    -- Check note columns for notes
    for _, note_col in ipairs(line.note_columns) do
      if not note_col.is_empty then
        -- Check for real notes (not note-offs) or instrument data
        if (note_col.note_value > 0 and note_col.note_value < 120) or 
           note_col.instrument_value < 255 or
           note_col.volume_value > 0 or
           note_col.panning_value ~= 255 or
           note_col.delay_value > 0 or
           note_col.effect_number_value > 0 or
           note_col.effect_amount_value > 0 then
          return true
        end
      end
    end
    
    -- Check effect columns for effects
    for _, fx_col in ipairs(line.effect_columns) do
      if fx_col.number_value > 0 or fx_col.amount_value > 0 then
        return true
      end
    end
  end
  
  return false
end

-- Main function to solo only tracks that have pattern data in current pattern (toggles with unsolo all)
function PakettiSoloTracksWithPatternData()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_status("Paketti Solo Pattern Data: No song loaded")
    return
  end
  
  local tracks_with_data = {}
  local tracks_without_data = {}
  local groups_to_unmute = {}
  
  -- Check each track for pattern data in current pattern
  for track_index = 1, #song.tracks do
    local track = song:track(track_index)
    
    -- Skip master track and group tracks (groups are handled automatically)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.type ~= renoise.Track.TRACK_TYPE_GROUP then
      if PakettiTrackHasPatternDataInCurrentPattern(track_index) then
        table.insert(tracks_with_data, track_index)
        
        -- If track is in a group, add that group to unmute list
        if track.group_parent then
          groups_to_unmute[track.group_parent] = true
        end
      else
        table.insert(tracks_without_data, track_index)
      end
    end
  end
  
  -- Check if we're already in "soloed" state 
  -- (tracks without data are muted AND tracks with data are unmuted)
  local already_soloed = false
  print("DEBUG: tracks_without_data=" .. #tracks_without_data .. ", tracks_with_data=" .. #tracks_with_data)
  
  if #tracks_without_data > 0 and #tracks_with_data > 0 then
    local tracks_without_data_muted = true
    local tracks_with_data_unmuted = true
    
    -- Check if tracks without data are muted (not ACTIVE = they're muted via OFF or MUTE)
    for _, track_index in ipairs(tracks_without_data) do
      local track = song:track(track_index)
      print("DEBUG: Track " .. track_index .. " without data, mute_state=" .. track.mute_state)
      if track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
        tracks_without_data_muted = false
        print("DEBUG: Track " .. track_index .. " is ACTIVE, so not already soloed")
        break
      end
    end
    
    print("DEBUG: tracks_without_data_muted=" .. tostring(tracks_without_data_muted))
    
    -- Check if tracks with data are unmuted (including their parent groups)
    if tracks_without_data_muted then
      for _, track_index in ipairs(tracks_with_data) do
        local track = song:track(track_index)
        print("DEBUG: Track " .. track_index .. " with data, mute_state=" .. track.mute_state)
        if track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
          tracks_with_data_unmuted = false
          print("DEBUG: Track " .. track_index .. " is NOT active, so not already soloed")
          break
        end
        -- If track is in a group, also check that the group is unmuted
        if track.group_parent then
          print("DEBUG: Track " .. track_index .. " has group_parent, group mute_state=" .. track.group_parent.mute_state)
          if track.group_parent.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
            tracks_with_data_unmuted = false
            print("DEBUG: Track " .. track_index .. " group is NOT active, so not already soloed")
            break
          end
        end
      end
    end
    
    print("DEBUG: tracks_with_data_unmuted=" .. tostring(tracks_with_data_unmuted))
    already_soloed = tracks_without_data_muted and tracks_with_data_unmuted
  end
  
  print("DEBUG: already_soloed=" .. tostring(already_soloed))
  
  local current_pattern_index = song.selected_pattern_index
  
  if already_soloed then
    -- We're already soloed, so unsolo everything (unmute all tracks)
    local unmuted_count = 0
    for track_index = 1, #song.tracks do
      local track = song:track(track_index)
      if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
        if track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
          track.mute_state = renoise.Track.MUTE_STATE_ACTIVE
          unmuted_count = unmuted_count + 1
        end
      end
    end
    renoise.app():show_status(string.format("Paketti: Unmuted all %d tracks", unmuted_count))
  else
    -- First mute all non-master tracks (using OFF like existing solo functionality)
    for track_index = 1, #song.tracks do
      local track = song:track(track_index)
      if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
        track.mute_state = renoise.Track.MUTE_STATE_OFF
      end
    end
    
    -- Then unmute tracks with data
    for _, track_index in ipairs(tracks_with_data) do
      local track = song:track(track_index)
      track.mute_state = renoise.Track.MUTE_STATE_ACTIVE
    end
    
    -- Unmute groups that contain tracks with data
    for group_track, _ in pairs(groups_to_unmute) do
      group_track.mute_state = renoise.Track.MUTE_STATE_ACTIVE
    end
    
    -- Status message
    renoise.app():show_status(string.format("Paketti: Soloed %d tracks with pattern data in pattern %02X", #tracks_with_data, current_pattern_index))
  end
end

-- Function to unsolo all tracks (unmute all)
function PakettiUnsoloAllTracks()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_status("Paketti Unsolo All: No song loaded")
    return
  end
  
  local unmuted_count = 0
  
  -- Unmute all tracks except master
  for track_index = 1, #song.tracks do
    local track = song:track(track_index)
    
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      if track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
        track.mute_state = renoise.Track.MUTE_STATE_ACTIVE
        unmuted_count = unmuted_count + 1
      end
    end
  end
  
  renoise.app():show_status(string.format("Paketti: Unmuted all %d tracks", unmuted_count))
end

-- Menu entries for multiple contexts
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}

-- Keybindings and MIDI mappings
renoise.tool():add_keybinding{name="Global:Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_keybinding{name="Global:Paketti:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}
renoise.tool():add_midi_mapping{name="Paketti:Solo Tracks with Pattern Data", invoke=PakettiSoloTracksWithPatternData}
renoise.tool():add_midi_mapping{name="Paketti:Unsolo All Tracks", invoke=PakettiUnsoloAllTracks}


InitSBx()