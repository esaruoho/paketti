local dialog = nil
local dialog_content = nil
local steppers_expanded = false  -- Track steppers section visibility
local volumeSliderWidth = 314

-- Volume Canvas Variables (for v6.2+ API)
local volume_canvas = nil
local volume_canvas_width = 400
local volume_canvas_height = 150
local volume_bars = {-36, -24, -12, 0, 12, 24, 36}
local volume_values = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}  -- Default volumes
local mouse_is_down = false
local canvas_content_margin = 10

-- No debug mode - show canvas for v6.2+, sliders for older versions

-- API Version Detection
local function is_canvas_api_available()
  return renoise.API_VERSION >= 6.2
end

-- Volume dB conversion
local function linear_to_db(linear_value)
  if linear_value <= 0 then
    return "INF"  -- Return string for -infinity
  else
    return string.format("%.2f", 20 * math.log10(linear_value))
  end
end

-- Volume label text elements (for legacy slider mode)
local volume_labels = {}

-- Volume slider elements (for direct access)
local volume_sliders = {}

-- Track which transpose levels have samples available
local transpose_availability = {false, false, false, false, false, false, false}  -- -36, -24, -12, 0, +12, +24, +36

-- Observable for instrument changes
local instrument_observable = nil

-- Observable for pattern length changes
local pattern_observable = nil

-- Pattern navigation buttons (for dynamic updates)
local pattern_buttons = {}

-- User preference for volume controls (for v6.2+ users)
local prefer_sliders_over_canvas = false

--------------------------------------------------------------------------------
-- VELOCITY STACKER DETECTION FUNCTIONS
--------------------------------------------------------------------------------

-- Check if an instrument is velocity-stacked
-- Returns true if multiple samples have non-overlapping single-velocity or narrow velocity ranges
function PakettiStackerIsVelocityStacked(instrument)
  if not instrument then
    instrument = renoise.song().selected_instrument
  end
  if not instrument then return false end
  
  local samples = instrument.samples
  if #samples < 2 then return false end
  
  -- Count samples with narrow velocity ranges (width <= 16)
  local narrow_range_count = 0
  local velocity_coverage = {}
  
  for i = 1, #samples do
    local sample = samples[i]
    local mapping = sample.sample_mapping
    if mapping then
      local vel_range = mapping.velocity_range
      if vel_range then
        local vel_min = vel_range[1]
        local vel_max = vel_range[2]
        local range_width = vel_max - vel_min
        
        -- Consider it stacked if velocity range is narrow (16 or less)
        if range_width <= 16 then
          narrow_range_count = narrow_range_count + 1
          -- Track velocity coverage
          for v = vel_min, vel_max do
            velocity_coverage[v] = true
          end
        end
      end
    end
  end
  
  -- Consider it velocity-stacked if:
  -- 1. At least 2 samples have narrow velocity ranges
  -- 2. They cover a reasonable portion of the velocity spectrum
  local coverage_count = 0
  for _ in pairs(velocity_coverage) do
    coverage_count = coverage_count + 1
  end
  
  return narrow_range_count >= 2 and coverage_count >= 16
end

-- Get velocity layers info from a stacked instrument
-- Returns table of {sample_index, sample_name, velocity_min, velocity_max}
function PakettiStackerGetVelocityLayers(instrument)
  if not instrument then
    instrument = renoise.song().selected_instrument
  end
  if not instrument then return {} end
  
  local layers = {}
  local samples = instrument.samples
  
  for i = 1, #samples do
    local sample = samples[i]
    local mapping = sample.sample_mapping
    if mapping then
      local vel_range = mapping.velocity_range
      if vel_range then
        table.insert(layers, {
          sample_index = i,
          sample_name = sample.name,
          velocity_min = vel_range[1],
          velocity_max = vel_range[2]
        })
      end
    end
  end
  
  -- Sort by velocity_min
  table.sort(layers, function(a, b) return a.velocity_min < b.velocity_min end)
  
  return layers
end

-- Get a formatted string describing velocity stack status
function PakettiStackerGetStatusString(instrument)
  if not instrument then
    instrument = renoise.song().selected_instrument
  end
  if not instrument then return "No instrument" end
  
  if PakettiStackerIsVelocityStacked(instrument) then
    local layers = PakettiStackerGetVelocityLayers(instrument)
    return string.format("VELOCITY STACKED (%d layers)", #layers)
  else
    return "Not velocity-stacked"
  end
end

-- Check which phrases in an instrument use velocity data (for stacked instruments)
function PakettiStackerGetPhraseVelocityInfo(instrument, phrase_index)
  if not instrument then
    instrument = renoise.song().selected_instrument
  end
  if not instrument then return nil end
  
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    return nil
  end
  
  local phrase = instrument.phrases[phrase_index]
  local velocities_used = {}
  
  for line_idx = 1, phrase.number_of_lines do
    local line = phrase:line(line_idx)
    for col_idx = 1, phrase.visible_note_columns do
      local note_col = line:note_column(col_idx)
      if note_col.note_value < 120 and note_col.volume_value < 128 then
        velocities_used[note_col.volume_value] = true
      end
    end
  end
  
  -- Convert to sorted list
  local vel_list = {}
  for vel, _ in pairs(velocities_used) do
    table.insert(vel_list, vel)
  end
  table.sort(vel_list)
  
  return vel_list
end

-- Check which transpose levels have samples
local function update_transpose_availability()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    -- Reset all to false if no instrument
    for i = 1, 7 do
      transpose_availability[i] = false
    end
    return
  end
  
  -- Reset availability
  for i = 1, 7 do
    transpose_availability[i] = false
  end
  
  -- Check for original samples (transpose 0)
  for _, sample in ipairs(instrument.samples) do
    if not sample.name:match("PakettiProcessed[%+%-]%d+") then
      transpose_availability[4] = true  -- Index 4 = transpose 0
      break
    end
  end
  
  -- Check for processed samples
  for _, sample in ipairs(instrument.samples) do
    if sample.name:find("PakettiProcessed-36", 1, true) then
      transpose_availability[1] = true  -- Index 1 = -36
    elseif sample.name:find("PakettiProcessed-24", 1, true) then
      transpose_availability[2] = true  -- Index 2 = -24
    elseif sample.name:find("PakettiProcessed-12", 1, true) then
      transpose_availability[3] = true  -- Index 3 = -12
    elseif sample.name:find("PakettiProcessed+12", 1, true) then
      transpose_availability[5] = true  -- Index 5 = +12
    elseif sample.name:find("PakettiProcessed+24", 1, true) then
      transpose_availability[6] = true  -- Index 6 = +24
    elseif sample.name:find("PakettiProcessed+36", 1, true) then
      transpose_availability[7] = true  -- Index 7 = +36
    end
  end
end

-- Update volume controls when instrument changes
local function update_volume_controls_for_instrument()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    return
  end
  
  -- Read actual sample volumes from the current instrument and update volume_values
  for i = 1, 7 do
    local transpose_value = volume_bars[i]
    local found_volume = 1.0  -- Default
    
    if transpose_value == 0 then
      -- Handle original samples (no PakettiProcessed in name)
      for _, sample in ipairs(instrument.samples) do
        if not sample.name:match("PakettiProcessed[%+%-]%d+") then
          found_volume = sample.volume
          break
        end
      end
    else
      -- Handle transposed samples (with PakettiProcessed pattern)
      local transpose_pattern = "PakettiProcessed" .. (transpose_value >= 0 and "+" or "") .. transpose_value
      
      for _, sample in ipairs(instrument.samples) do
        if sample.name:find(transpose_pattern, 1, true) then
          found_volume = sample.volume
          break
        end
      end
    end
    
    volume_values[i] = found_volume
  end
  
  if is_canvas_api_available() and not prefer_sliders_over_canvas then
    update_transpose_availability()
    if volume_canvas then
      volume_canvas:update()
    end
  end
  
  -- Update slider labels to match actual volumes (if sliders are visible)
  if (not is_canvas_api_available() or prefer_sliders_over_canvas) and volume_labels and #volume_labels > 0 then
    for i = 1, 7 do
      if volume_labels[i] then
        local db_val = linear_to_db(volume_values[i])
        volume_labels[i].text = db_val == "INF" and "-INF" or (db_val .. "dB")
      end
    end
  end
end

-- Volume Canvas Drawing Function
function PakettiStackerDrawVolumeCanvas(ctx)
  local w, h = volume_canvas_width, volume_canvas_height
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Calculate bar dimensions
  local bar_width = (w - canvas_content_margin * 2) / #volume_bars
  local bar_height = h - canvas_content_margin * 2
  
  for i, transpose_value in ipairs(volume_bars) do
    local x = canvas_content_margin + (i - 1) * bar_width
    local y = canvas_content_margin
    local volume = volume_values[i]
    local is_available = transpose_availability[i]
    
    -- Draw bar background (changes based on availability)
    if is_available then
      ctx.fill_color = {64, 32, 96, 255}  -- Deep purple background for available
    else
      ctx.fill_color = {32, 32, 32, 255}  -- Dark background for unavailable
    end
    ctx:fill_rect(x + 2, y, bar_width - 4, bar_height)
    
    -- Draw volume level (bright, only if samples are available)
    if is_available then
      local fill_height = bar_height * volume
      local fill_y = y + bar_height - fill_height
      
      -- Color based on transpose value (brighter when available)
      if transpose_value < 0 then
        ctx.fill_color = {255, 100, 100, 255}  -- Red for negative
      elseif transpose_value == 0 then
        ctx.fill_color = {100, 255, 100, 255}  -- Green for original
      else
        ctx.fill_color = {100, 100, 255, 255}  -- Blue for positive
      end
      
      ctx:fill_rect(x + 2, fill_y, bar_width - 4, fill_height)
    end
    
    -- Draw bar outline (changes based on availability)
    if is_available then
      ctx.stroke_color = {0, 0, 0, 255}  -- Black outline for available
    else
      ctx.stroke_color = {0, 0, 0, 255}  -- Black outline for unavailable
    end
    ctx.line_width = 1
    ctx:stroke_rect(x + 2, y, bar_width - 4, bar_height)
    
    -- Draw transpose label (brighter if available)
    if is_available then
      ctx.stroke_color = {255, 255, 255, 255}  -- Bright white for available
    else
      ctx.stroke_color = {128, 128, 128, 255}  -- Dimmed for unavailable
    end
    ctx.line_width = 1
    local label_x = x + bar_width / 2 - 8
    local label_y = y + bar_height + 15
    
    -- Simple text rendering using lines (since we can't use real text)
    local label = tostring(transpose_value)
    if transpose_value > 0 then label = "+" .. label end
    -- Draw simple tick mark for now
    ctx:begin_path()
    ctx:move_to(label_x, label_y - 5)
    ctx:line_to(label_x, label_y + 5)
    ctx:stroke()
  end
end

-- Volume Canvas Mouse Handler
function PakettiStackerHandleVolumeMouse(ev)
  local w, h = volume_canvas_width, volume_canvas_height
  
  if ev.type == "down" then
    mouse_is_down = true
  elseif ev.type == "up" then
    mouse_is_down = false
    return
  elseif ev.type == "exit" then
    mouse_is_down = false
    return
  end
  
  if mouse_is_down or ev.type == "down" then
    local bar_width = (w - canvas_content_margin * 2) / #volume_bars
    local bar_height = h - canvas_content_margin * 2
    
    -- Find which bar was clicked
    local bar_index = math.floor((ev.position.x - canvas_content_margin) / bar_width) + 1
    
    if bar_index >= 1 and bar_index <= #volume_bars then
      -- Calculate volume based on Y position
      local y_in_bar = ev.position.y - canvas_content_margin
      local volume = 1.0 - (y_in_bar / bar_height)
      volume = math.max(0.0, math.min(1.0, volume))  -- Clamp 0-1
      
      -- Update volume value
      volume_values[bar_index] = volume
      
      -- Update the corresponding sample volumes
      local transpose_value = volume_bars[bar_index]
      set_volume_for_transpose(transpose_value, volume)
      
      -- Update volume labels  
      if volume_labels[bar_index] then
        local db_val = linear_to_db(volume)
        volume_labels[bar_index].text = db_val == "INF" and "-INF" or (db_val .. "dB")
      end
      
      -- Update availability and refresh canvas
      update_transpose_availability()
      if volume_canvas then
        volume_canvas:update()
      end
    end
  end
end

function returnpe()
    renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to set loop mode for all samples in the selected instrument
function set_loop_mode_for_selected_instrument(loop_mode)
  local song=renoise.song()
  local instrument = song.selected_instrument

  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  local samples = instrument.samples
  local num_samples = #samples

  if num_samples < 1 then
    renoise.app():show_status("No samples in the selected instrument.")
    return
  end

  -- Create a lookup table for human-readable loop mode names
  local loop_mode_names = {
    [renoise.Sample.LOOP_MODE_OFF] = "Off",
    [renoise.Sample.LOOP_MODE_FORWARD] = "Forward",
    [renoise.Sample.LOOP_MODE_REVERSE] = "Reverse",
    [renoise.Sample.LOOP_MODE_PING_PONG] = "PingPong"
  }

  for i = 1, num_samples do
    samples[i].loop_mode = loop_mode
  end


  local mode_name = loop_mode_names[loop_mode] or "Unknown"
  renoise.app():show_status("Loop mode set to " .. mode_name .. " for " .. num_samples .. " samples.")
  --returnpe()
end

-- Function to set loop length for all samples in the selected instrument
function set_loop_length_for_selected_instrument(length_type)
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end
  
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in the selected instrument.")
    return
  end
  
  local samples_processed = 0
  
  for _, sample in ipairs(instrument.samples) do
    if sample.sample_buffer.has_sample_data then
      local total_frames = sample.sample_buffer.number_of_frames
      
      if length_type == "full" then
        -- Set loop to full sample (first frame to last frame)
        sample.loop_start = 1
        sample.loop_end = total_frames
      elseif length_type == "half" then
        -- Set loop to second half of sample (half point to end)
        local half_point = math.floor(total_frames / 2)
        sample.loop_start = half_point
        sample.loop_end = total_frames
      elseif length_type == "begin" then
        -- Set loop to beginning half of sample (start to half point)
        local half_point = math.floor(total_frames / 2)
        sample.loop_start = 1
        sample.loop_end = half_point
      end
      
      samples_processed = samples_processed + 1
    end
  end
  
  renoise.app():show_status(string.format("Loop length set to %s for %d samples.", length_type, samples_processed))
end

-- Fix velocity mappings of all samples in the selected instrument and disable vel->vol
function fix_sample_velocity_mappings()
  local song=renoise.song()
  local instrument = song.selected_instrument

  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  -- Check if the instrument has slices
  if instrument.samples[1].slice_markers ~= nil then
    renoise.app():show_status("Slices detected, isolating slices to individual instruments.")
    PakettiIsolateSlicesToInstrument()
  end
  local instrument = renoise.song().selected_instrument
  local samples = instrument.samples
  local num_samples = #samples

  if num_samples < 1 then
    renoise.app():show_status("No samples found in the selected instrument.")
    return
  end

  -- Define the velocity range (01 to 127)
  local velocity_min = 1
  local velocity_max = 127
  local velocity_step = math.floor((velocity_max - velocity_min + 1) / num_samples)

  -- Base note and note range to apply to all samples
  local base_note = 48 -- Default to C-4
  local note_range = {base_note, base_note} -- Restrict to a single key

  for i = 1, num_samples do
    local sample = samples[i]
    local start_velocity = velocity_min + (i - 1) * velocity_step
    local end_velocity = start_velocity + velocity_step - 1

    -- Adjust for the last sample to ensure it ends exactly at 127
    if i == num_samples then
      end_velocity = velocity_max
    end

    -- Disable vel->vol
    sample.sample_mapping.map_velocity_to_volume = false

    -- Update sample mapping
    sample.sample_mapping.base_note = base_note
    sample.sample_mapping.note_range = note_range
    sample.sample_mapping.velocity_range = {start_velocity, end_velocity}
  end

  renoise.app():show_status("Velocity mappings updated, vel->vol set to OFF for " .. num_samples .. " samples.")
end

-- Function to update pattern navigation button texts based on current pattern length
function update_pattern_buttons()
  local song = renoise.song()
  local pattern_length = song.selected_pattern.number_of_lines
  
  for i = 1, 8 do
    if pattern_buttons[i] then
      local row_number
      
      if pattern_length >= 8 then
        -- Original logic for 8+ row patterns: divide into 8 equal segments
        local segment = math.floor(pattern_length / 8)
        row_number = segment * (i - 1)
        if i == 8 then
          row_number = segment * 7
        end
      else
        -- Edge case for patterns shorter than 8 rows: repeat each row to fill all 8 buttons
        row_number = math.floor((i - 1) * pattern_length / 8)
      end
      
      pattern_buttons[i].text = string.format("%02d", row_number)
    end
  end
end

function jump_to_pattern_segment(segment_number)
  local song=renoise.song()
  song.transport.follow_player = false
  local pattern_length = song.selected_pattern.number_of_lines
  
  local target_row
  if pattern_length >= 8 then
    -- Original logic for 8+ row patterns: divide into 8 equal segments
    local segment = math.floor(pattern_length / 8)
    target_row = segment * (segment_number - 1)
    if segment_number == 8 then
      target_row = segment * 7
    end
  else
    -- Edge case for patterns shorter than 8 rows: repeat each row to fill all 8 buttons
    target_row = math.floor((segment_number - 1) * pattern_length / 8)
  end
  
  song.selected_line_index = target_row + 1  -- +1 because Renoise uses 1-based indexing
  returnpe()
end
-- Write notes with ramp-up velocities (01 to 127)
function write_velocity_ramp_up()
  local song=renoise.song()
  local pattern = song.selected_pattern
  local start_line_index = song.selected_line_index  
  local line_index = song.selected_line_index
  local instrument_index = song.selected_instrument_index
  
  local notecoll
  if song.selected_note_column_index == 0 then
    notecoll = 1
  else
    notecoll = song.selected_note_column_index
  end

  -- Check if track is a note track
  if renoise.song().selected_track.type ~= 1 then
    renoise.app():show_status("Cannot write notes to non-note tracks.")
    return
  end

  -- Get unique velocity ranges
  local velocity_ranges = {}
  local samples = renoise.song().selected_instrument.samples
  for _, sample in ipairs(samples) do
    local range_key = table.concat(sample.sample_mapping.velocity_range, "-")
    velocity_ranges[range_key] = sample.sample_mapping.velocity_range
  end

  -- Convert to array and sort by lower velocity bound
  local unique_ranges = {}
  for _, range in pairs(velocity_ranges) do
    table.insert(unique_ranges, range)
  end
  table.sort(unique_ranges, function(a, b) return a[1] < b[1] end)

  local num_ranges = #unique_ranges
  if num_ranges < 1 then
    renoise.app():show_status("No velocity mappings found.")
    return
  end

  -- Calculate how many notes we can write before hitting the pattern limit
  local max_lines = pattern.number_of_lines
  local available_lines = max_lines - line_index + 1
  local notes_to_write = math.min(num_ranges, available_lines)

  local base_note = 48 -- C-4

  -- Write notes using the actual velocity ranges
  for i = 1, notes_to_write do
    local velocity = unique_ranges[i][1] -- Use the lower bound of each range
    local line = pattern.tracks[song.selected_track_index].lines[line_index + i - 1]
    if line and line.note_columns and line.note_columns[notecoll] then
      line.note_columns[notecoll].note_value = base_note
      line.note_columns[notecoll].instrument_value = instrument_index - 1
      line.note_columns[notecoll].volume_value = velocity
    end
  end

  song.selection_in_pattern = {
    start_line = start_line_index,
    end_line = start_line_index + notes_to_write - 1,
    start_track = song.selected_track_index,
    end_track = song.selected_track_index,
    start_column = notecoll,
    end_column = notecoll
  }

  renoise.app():show_status("Ramp-up velocities written based on " .. notes_to_write .. " unique velocity ranges.")
end

-- Write notes with ramp-down velocities starting from the last sample's lower velocity bound
function write_velocity_ramp_down()
  local song=renoise.song()
  local pattern = song.selected_pattern
  local start_line_index = song.selected_line_index
  local instrument_index = song.selected_instrument_index
  
  local notecoll
  if song.selected_note_column_index == 0 then
    notecoll = 1
  else
    notecoll = song.selected_note_column_index
  end

  -- Check if track is a note track
  if renoise.song().selected_track.type ~= 1 then
    renoise.app():show_status("Cannot write notes to non-note tracks.")
    return
  end

  -- Get unique velocity ranges
  local velocity_ranges = {}
  local samples = renoise.song().selected_instrument.samples
  for _, sample in ipairs(samples) do
    local range_key = table.concat(sample.sample_mapping.velocity_range, "-")
    velocity_ranges[range_key] = sample.sample_mapping.velocity_range
  end

  -- Convert to array and sort by lower velocity bound (descending)
  local unique_ranges = {}
  for _, range in pairs(velocity_ranges) do
    table.insert(unique_ranges, range)
  end
  table.sort(unique_ranges, function(a, b) return a[1] > b[1] end)

  local num_ranges = #unique_ranges
  if num_ranges < 1 then
    renoise.app():show_status("No velocity mappings found.")
    return
  end

  -- Calculate how many notes we can write before hitting the pattern limit
  local max_lines = pattern.number_of_lines
  local available_lines = max_lines - start_line_index + 1
  local notes_to_write = math.min(num_ranges, available_lines)

  local base_note = 48

  -- Write notes using the actual velocity ranges in descending order
  for i = 1, notes_to_write do
    local velocity = unique_ranges[i][1] -- Use the lower bound of each range
    local line = pattern.tracks[song.selected_track_index].lines[start_line_index + i - 1]
    if line and line.note_columns and line.note_columns[notecoll] then
      line.note_columns[notecoll].note_value = base_note
      line.note_columns[notecoll].instrument_value = instrument_index - 1
      line.note_columns[notecoll].volume_value = velocity
    end
  end

  song.selection_in_pattern = {
    start_line = start_line_index,
    end_line = start_line_index + notes_to_write - 1,
    start_track = song.selected_track_index,
    end_track = song.selected_track_index,
    start_column = notecoll,
    end_column = notecoll
  }

  renoise.app():show_status("Ramp-down velocities written based on " .. notes_to_write .. " unique velocity ranges.")
end

-- Write notes with random velocities, respecting the last sample's velocity range
function write_random_velocity_notes()
  trueRandomSeed()

  local song=renoise.song()
  local pattern = song.selected_pattern
  local start_line_index = song.selected_line_index
  local instrument_index = song.selected_instrument_index
  
  local notecoll
  if song.selected_note_column_index == 0 then
    notecoll = 1
  else
    notecoll = song.selected_note_column_index
  end

  -- Check if track is a note track
  if renoise.song().selected_track.type ~= 1 then
    renoise.app():show_status("Cannot write notes to non-note tracks.")
    return
  end

  -- Get unique velocity ranges
  local velocity_ranges = {}
  local samples = renoise.song().selected_instrument.samples
  for _, sample in ipairs(samples) do
    local range_key = table.concat(sample.sample_mapping.velocity_range, "-")
    velocity_ranges[range_key] = sample.sample_mapping.velocity_range
  end

  -- Convert to array
  local unique_ranges = {}
  for _, range in pairs(velocity_ranges) do
    table.insert(unique_ranges, range)
  end

  local num_ranges = #unique_ranges
  if num_ranges < 1 then
    renoise.app():show_status("No velocity mappings found.")
    return
  end

  -- Calculate how many notes we can write before hitting the pattern limit
  local max_lines = pattern.number_of_lines
  local available_lines = max_lines - start_line_index + 1
  local notes_to_write = math.min(num_ranges, available_lines)

  local base_note = 48

  -- Write notes with random velocities within the available ranges
  for i = 1, notes_to_write do
    -- Pick a random range
    local random_range_index = math.random(1, num_ranges)
    local range = unique_ranges[random_range_index]
    
    -- Pick a random velocity within that range
    local velocity = math.random(range[1], range[2])
    local line = pattern.tracks[song.selected_track_index].lines[start_line_index + i - 1]
    if line and line.note_columns and line.note_columns[notecoll] then
      line.note_columns[notecoll].note_value = base_note
      line.note_columns[notecoll].instrument_value = instrument_index - 1
      line.note_columns[notecoll].volume_value = velocity
    end
  end

  song.selection_in_pattern = {
    start_line = start_line_index,
    end_line = start_line_index + notes_to_write - 1,
    start_track = song.selected_track_index,
    end_track = song.selected_track_index,
    start_column = notecoll,
    end_column = notecoll
  }

  renoise.app():show_status("Random velocities written based on " .. notes_to_write .. " unique velocity ranges.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Stack All Samples in Instrument with Velocity Mapping Split",invoke=function() fix_sample_velocity_mappings() end}
renoise.tool():add_keybinding{name="Global:Paketti:Write Velocity Ramp Up for Stacked Instrument",invoke=function() write_velocity_ramp_up() end}
renoise.tool():add_keybinding{name="Global:Paketti:Write Velocity Ramp Down for Stacked Instrument",invoke=function() write_velocity_ramp_down() end}
renoise.tool():add_keybinding{name="Global:Paketti:Write Velocity Random for Stacked Instrument",invoke=function() write_random_velocity_notes() end}

-- NOTE: Using existing PakettiDuplicateInstrumentSamplesWithTranspose() from PakettiSamples.lua
-- (Keybindings already exist there too - no need to duplicate!)

-- Function to set volume for all samples with specific transpose (using PakettiSamples.lua naming convention)
function set_volume_for_transpose(transpose_value, volume)
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    return
  end
  
  local affected_count = 0
  
  if transpose_value == 0 then
    -- Handle original samples (no PakettiProcessed in name)
    for _, sample in ipairs(instrument.samples) do
      if not sample.name:match("PakettiProcessed[%+%-]%d+") then
        sample.volume = volume
        affected_count = affected_count + 1
      end
    end
    
    if affected_count == 0 then
      renoise.app():show_status("No original samples found")
    end
  else
    -- Handle transposed samples (with PakettiProcessed pattern)
    local transpose_pattern = "PakettiProcessed" .. (transpose_value >= 0 and "+" or "") .. transpose_value
    
    for _, sample in ipairs(instrument.samples) do
      if sample.name:find(transpose_pattern, 1, true) then -- true = plain text search, not pattern
        sample.volume = volume
        affected_count = affected_count + 1
      end
    end
    
    if affected_count == 0 then
      renoise.app():show_status(string.format("No samples found with pattern '%s'", transpose_pattern))
    end
  end
end

function on_switch_changed(selected_value)
  local instrument = renoise.song().selected_instrument
  local num_samples = #instrument.samples

  -- Check if the first sample has slices
  local has_slices = false
  if num_samples > 0 and instrument.samples[1].slice_markers ~= nil then
    has_slices = #instrument.samples[1].slice_markers > 0
  end

  if has_slices then
    -- Already have slices
   --f wipeslices()
    if selected_value ~= "OFF" then
      slicerough(selected_value)
      renoise.app():show_status("Slices updated to " .. tostring(selected_value) .. " divisions.")
    else
      renoise.app():show_status("Slices cleared. No further slicing performed.")
    end
  else
    -- No slices currently
    if num_samples == 1 then
      -- Single sample, no slices
      if selected_value ~= "OFF" then
        slicerough(selected_value)
        renoise.app():show_status("Sample sliced into " .. tostring(selected_value) .. " divisions.")
      else
        renoise.app():show_status("Slice function is OFF. No slicing performed.")
      end
    else
      -- Multiple samples, no slices
      renoise.app():show_status("Multiple samples detected. No slicing performed.")
    end
  end
end

-- Variables for progress dialog
local duplicate_all_slicer = nil
local duplicate_all_progress_dialog = nil
local duplicate_all_progress_vb = nil

-- Function to duplicate samples with all octave transpositions (with progress dialog)
function duplicate_all_octaves_process()
  local transpose_values = {-36, -24, -12, 12, 24, 36}
  
  for i, transpose in ipairs(transpose_values) do
    -- Update progress text if dialog exists
    if duplicate_all_progress_dialog and duplicate_all_progress_vb then
      duplicate_all_progress_vb.views.progress_text.text = 
        string.format("Processing transpose %+d... (%d/%d)", transpose, i, #transpose_values)
    end
    
    -- Check for cancellation
    if duplicate_all_slicer and duplicate_all_slicer:was_cancelled() then
      renoise.app():show_status("All octaves operation cancelled")
      return
    end
    
    PakettiDuplicateInstrumentSamplesWithTranspose(transpose, true)
    
    -- Yield control back to UI after each transpose
    coroutine.yield()
  end
  
  -- Update canvas after all operations are complete
  if is_canvas_api_available() then
    update_transpose_availability()
    if volume_canvas then
      volume_canvas:update()
    end
  end
  
  -- Close progress dialog
  if duplicate_all_progress_dialog and duplicate_all_progress_dialog.visible then
    duplicate_all_progress_dialog:close()
  end
  
  renoise.app():show_status("All octave samples created: -36, -24, -12, +12, +24, +36")
end

-- Function to duplicate samples with all octave transpositions
function duplicate_all_octaves()
  -- Don't start if already running
  if duplicate_all_slicer and duplicate_all_slicer:running() then
    renoise.app():show_status("All octaves operation already in progress...")
    return
  end
  
  -- Create ProcessSlicer
  duplicate_all_slicer = ProcessSlicer(duplicate_all_octaves_process)
  
  -- Create progress dialog
  duplicate_all_progress_dialog, duplicate_all_progress_vb = 
    duplicate_all_slicer:create_dialog("Processing All Octaves")
  
  -- Start the process
  duplicate_all_slicer:start()
end

function pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument)
  if dialog and dialog.visible then
  dialog:close()
  dialog = nil
  dialog_content = nil
  return 
  end

  -- Create fresh ViewBuilder instance to avoid ID conflicts
  local vb = renoise.ViewBuilder()
  
--  local dialog = nil

  local switch_values = {"OFF", "2", "4", "8", "16", "32", "64", "128"}
  local switch_index = 1 -- Default to "OFF"

  -- Function to close the dialog
  local function closeST_dialog()
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
    end
  end

  -- Create volume canvas (if v6.2+ API available and user doesn't prefer sliders)
  if is_canvas_api_available() then
    volume_canvas = vb:canvas{
      width = volume_canvas_width,
      height = volume_canvas_height,
      mode = "plain",
      render = PakettiStackerDrawVolumeCanvas,
      mouse_handler = PakettiStackerHandleVolumeMouse,
      mouse_events = {"down", "up", "move", "exit"}
    }
  end
  
  -- Create volume label text elements (always needed for slider functionality)
  for i = 1, 7 do
    local db_val = linear_to_db(volume_values[i])
    volume_labels[i] = vb:text{
      text = db_val == "INF" and "-INF" or (db_val .. "dB"),
      font = "mono",
      width = 60
    }
  end

  -- Create steppers UI elements without IDs to avoid conflicts
  local steppers_toggle_button = vb:button{
    text = "▴", -- Start collapsed
    width = 22,
    notifier = function()
      steppers_expanded = not steppers_expanded
      update_steppers_visibility()
    end
  }
  
  local steppers_content_column = vb:column{
    style = "group",
    margin = 6,
    visible = false, -- Start hidden
    
    -- Include the Paketti Steppers dialog content using DRY principle
    PakettiCreateStepperDialogContent(vb)
  }
  
  -- Function to update steppers section visibility
  function update_steppers_visibility()
    steppers_content_column.visible = steppers_expanded
    steppers_toggle_button.text = steppers_expanded and "▾" or "▴"
  end

  -- Create volume control elements first
  local canvas_title_button, canvas_row, slider_title_button, slider_rows

  -- Initialize volume values by reading actual sample volumes
  update_volume_controls_for_instrument()

  -- Create pattern navigation buttons with dynamic text
  for i = 1, 8 do
    local segment_num = i -- Create local copy for closure
    pattern_buttons[i] = vb:button{
      text="00", -- Will be updated by update_pattern_buttons()
      width=37,
      notifier=function() jump_to_pattern_segment(segment_num) end
    }
  end

  -- Create notifier functions for volume sliders
  local function create_volume_notifier(transpose_value, label_index)
    return function(value)
      -- Update the volume_values array
      volume_values[label_index] = value
      
      -- Update sample volume
      set_volume_for_transpose(transpose_value, value)
      
      -- Update volume label
      if volume_labels[label_index] then
        local db_val = linear_to_db(value)
        volume_labels[label_index].text = db_val == "INF" and "-INF" or (db_val .. "dB")
      end
      
      -- Update canvas if available and update transpose availability  
      if is_canvas_api_available() then
        update_transpose_availability()
        if volume_canvas then
          volume_canvas:update()
        end
      end
    end
  end

  if is_canvas_api_available() then
    canvas_title_button = vb:button{
      text="Transpose Volume Bars - Click to Switch to Sliders",
      width=400,
      notifier=function() 
        canvas_title_button.visible = false
        canvas_row.visible = false
        slider_title_button.visible = true
        for _, row in ipairs(slider_rows) do
          row.visible = true
        end
        -- Update slider values and labels to match current volume_values
        for i = 1, 7 do
          if volume_sliders[i] then
            volume_sliders[i].value = volume_values[i]
          end
          if volume_labels[i] then
            local db_val = linear_to_db(volume_values[i])
            volume_labels[i].text = db_val == "INF" and "-INF" or (db_val .. "dB")
          end
        end
      end
    }
    
    canvas_row = vb:row{volume_canvas}
    
    slider_title_button = vb:button{
      text="Transpose Volume Sliders - Click to Switch to Canvas", 
      width=400,
      visible=false,
      notifier=function()
        canvas_title_button.visible = true
        canvas_row.visible = true
        slider_title_button.visible = false
        for _, row in ipairs(slider_rows) do
          row.visible = false
        end
        -- Update canvas to reflect current volume_values
        update_transpose_availability()
        if volume_canvas then
          volume_canvas:update()
        end
      end
    }
    
    -- Create slider elements and store references
    volume_sliders[1] = vb:slider{min=0, max=1, value=volume_values[1], width=volumeSliderWidth, notifier=create_volume_notifier(-36, 1)}
    volume_sliders[2] = vb:slider{min=0, max=1, value=volume_values[2], width=volumeSliderWidth, notifier=create_volume_notifier(-24, 2)}
    volume_sliders[3] = vb:slider{min=0, max=1, value=volume_values[3], width=volumeSliderWidth, notifier=create_volume_notifier(-12, 3)}
    volume_sliders[4] = vb:slider{min=0, max=1, value=volume_values[4], width=volumeSliderWidth, notifier=create_volume_notifier(0, 4)}
    volume_sliders[5] = vb:slider{min=0, max=1, value=volume_values[5], width=volumeSliderWidth, notifier=create_volume_notifier(12, 5)}
    volume_sliders[6] = vb:slider{min=0, max=1, value=volume_values[6], width=volumeSliderWidth, notifier=create_volume_notifier(24, 6)}
    volume_sliders[7] = vb:slider{min=0, max=1, value=volume_values[7], width=volumeSliderWidth, notifier=create_volume_notifier(36, 7)}
    
    slider_rows = {
      vb:row{
        vb:text{text="-36", font="mono", width=25},
        volume_sliders[1],
        volume_labels[1],
        visible=false
      },
      vb:row{
        vb:text{text="-24", font="mono", width=25},
        volume_sliders[2],
        volume_labels[2],
        visible=false
      },
      vb:row{
        vb:text{text="-12", font="mono", width=25},
        volume_sliders[3],
        volume_labels[3],
        visible=false
      },
      vb:row{
        vb:text{text=" 0 ", font="mono", width=25},
        volume_sliders[4],
        volume_labels[4],
        visible=false
      },
      vb:row{
        vb:text{text="+12", font="mono", width=25},
        volume_sliders[5],
        volume_labels[5],
        visible=false
      },
      vb:row{
        vb:text{text="+24", font="mono", width=25},
        volume_sliders[6],
        volume_labels[6],
        visible=false
      },
      vb:row{
        vb:text{text="+36", font="mono", width=25},
        volume_sliders[7],
        volume_labels[7],
        visible=false
      }
    }
  else
    -- Legacy API - no toggle functionality  
    slider_title_button = vb:text{text="Transpose Volume Sliders",width=200,font="bold",style="strong"}
    
    -- Create slider elements and store references  
    volume_sliders[1] = vb:slider{min=0, max=1, value=volume_values[1], width=volumeSliderWidth, notifier=create_volume_notifier(-36, 1)}
    volume_sliders[2] = vb:slider{min=0, max=1, value=volume_values[2], width=volumeSliderWidth, notifier=create_volume_notifier(-24, 2)}
    volume_sliders[3] = vb:slider{min=0, max=1, value=volume_values[3], width=volumeSliderWidth, notifier=create_volume_notifier(-12, 3)}
    volume_sliders[4] = vb:slider{min=0, max=1, value=volume_values[4], width=volumeSliderWidth, notifier=create_volume_notifier(0, 4)}
    volume_sliders[5] = vb:slider{min=0, max=1, value=volume_values[5], width=volumeSliderWidth, notifier=create_volume_notifier(12, 5)}
    volume_sliders[6] = vb:slider{min=0, max=1, value=volume_values[6], width=volumeSliderWidth, notifier=create_volume_notifier(24, 6)}
    volume_sliders[7] = vb:slider{min=0, max=1, value=volume_values[7], width=volumeSliderWidth, notifier=create_volume_notifier(36, 7)}
    
    slider_rows = {
      vb:row{
        vb:text{text="-36", font="mono", width=25},
        volume_sliders[1],
        volume_labels[1]
      },
      vb:row{
        vb:text{text="-24", font="mono", width=25},
        volume_sliders[2],
        volume_labels[2]
      },
      vb:row{
        vb:text{text="-12", font="mono", width=25},
        volume_sliders[3],
        volume_labels[3]
      },
      vb:row{
        vb:text{text=" 0 ", font="mono", width=25},
        volume_sliders[4],
        volume_labels[4]
      },
      vb:row{
        vb:text{text="+12", font="mono", width=25},
        volume_sliders[5],
        volume_labels[5]
      },
      vb:row{
        vb:text{text="+24", font="mono", width=25},
        volume_sliders[6],
        volume_labels[6]
      },
      vb:row{
        vb:text{text="+36", font="mono", width=25},
        volume_sliders[7],
        volume_labels[7]
      }
    }
  end

  -- Dialog Content Definition
  local dialog_content = vb:column{
    vb:row{vb:button{text="Load Sample to Stack",width=400,notifier=function() pitchBendMultipleSampleLoader() end}},
    vb:row{vb:text{text="Set Slice Count",width=100,style = "strong",font = "bold"},
vb:switch {
--  id="wipeslice",
  items = switch_values,
  width=300,
  value = switch_index,
  notifier=function(index)
    local selected_value = switch_values[index]
    if selected_value ~= "OFF" then
      -- Do not revert to OFF here. Just call on_switch_changed.
      on_switch_changed(tonumber(selected_value))
      renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    else
      wipeslices()
      on_switch_changed("OFF")
    end
  end}},
   vb:row{
        vb:button{
            text="Proceed with Stacking",
            width=200,
            notifier=function()
                proceed_with_stacking()
                returnpe() 
            end
        },
        vb:button{
            text="Auto Stack from Pattern",
            width=200,
            notifier=function()
                auto_stack_from_existing_pattern()
            end
        }
    },
    
    vb:row{vb:text{text="Stack Ramp",width=100,font = "bold",style = "strong",},
      vb:button{text="Up",width=100,notifier=function() write_velocity_ramp_up()
      returnpe() end},
      vb:button{
        text="Down",
        width=100,
        notifier=function() write_velocity_ramp_down() 
        returnpe() end},
      vb:button{
        text="Random",
        width=100,
        notifier=function() write_random_velocity_notes() 
        returnpe() end}},

-- Phrase Creation Section
vb:row{vb:text{text="Phrases",width=100,font="bold",style="strong"},
  vb:button{text="Layer",width=50,notifier=function() PakettiStackerCreateVelocityPhrases() end},
  vb:button{text="Cycle",width=50,notifier=function() PakettiStackerCreateVelocityCyclePhrase() end},
  vb:button{text="From Pat",width=60,notifier=function() PakettiStackerCreatePhraseFromPattern() end},
  vb:button{text="Rnd8",width=35,notifier=function() PakettiStackerCreateRandomPhrase8() end},
  vb:button{text="Rnd16",width=40,notifier=function() PakettiStackerCreateRandomPhrase16() end},
  vb:button{text="Rnd32",width=40,notifier=function() PakettiStackerCreateRandomPhrase32() end},
  vb:button{text="Sparse",width=45,notifier=function() PakettiStackerCreateSparseRandomPhrase(16) end}
},

-- Loop Length Controls  
vb:row{vb:text{text="Loop Length",width=100, style="strong",font="bold"},
vb:button{text="Full",width=150,notifier=function() set_loop_length_for_selected_instrument("full") end},
vb:button{text="Half",width=150,notifier=function() set_loop_length_for_selected_instrument("half") end}
},        
vb:row{vb:text{text="Set Loop Mode",width=100, style="strong",font="bold"},
vb:button{text="Off",width=75,notifier=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_OFF) end},
vb:button{text="Forward",width=75,notifier=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_FORWARD) end},
vb:button{text="PingPong",width=75,notifier=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_PING_PONG) end},
vb:button{text="Reverse",width=75,notifier=function() set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_REVERSE)end}

},

vb:row{vb:text{text="PitchStepper",width=100,font="bold",style="strong"},
vb:button{text="+12 -12",width=100,notifier=function() PakettiFillPitchStepper() end},
vb:button{text="+24 -24",width=100,notifier=function() PakettiFillPitchStepperTwoOctaves() end},
vb:button{text="0",width=100,notifier=function() PakettiClearStepper("Pitch Stepper") end},
},
vb:row{
vb:text{text="Instrument Pitch",width=100,font="bold",style="strong"},
vb:switch {
  width=300,
--  id = "instrument_pitch",
  items = {"-24", "-12", "0", "+12", "+24"},
  value = (function()
    -- Read current instrument transpose and convert to switch index
    local current_transpose = renoise.song().selected_instrument.transpose
    local pitch_values = {-24, -12, 0, 12, 24}
    for i, pitch in ipairs(pitch_values) do
      if pitch == current_transpose then
        return i
      end
    end
    return 3 -- Default to "0" if not found
  end)(),
  notifier=function(index)
    -- Convert the selected index to the corresponding pitch value
    local pitch_values = {-24, -12, 0, 12, 24}
    local selected_pitch = pitch_values[index] -- Lua uses 1-based indexing for tables
    
    -- Update the instrument transpose
    renoise.song().selected_instrument.transpose = selected_pitch
  end
}},
vb:row{
  vb:button{
    text="Follow Pattern",width=104,
    notifier=function()
      local song = renoise.song()
      local is_in_pattern_editor = (renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR)
      
      if is_in_pattern_editor and song.transport.follow_player then
        -- Already in pattern editor AND follow pattern is on -> turn it off
        song.transport.follow_player = false
        renoise.app():show_status("Follow Pattern turned OFF")
      elseif song.transport.follow_player then
        -- Follow pattern is on but not in pattern editor -> just move to pattern editor
        returnpe()
      else
        -- Follow pattern is off -> turn it on and move to pattern editor
        song.transport.follow_player = true
        returnpe()
      end
    end},
   pattern_buttons[1],
   pattern_buttons[2],
   pattern_buttons[3],
   pattern_buttons[4],
   pattern_buttons[5],
   pattern_buttons[6],
   pattern_buttons[7],
   pattern_buttons[8]},

-- Sample Duplication with Transpose
vb:row{vb:text{text="Duplicate Samples",width=130,font="bold",style="strong"},
  vb:button{text="-36",width=40,notifier=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36); if is_canvas_api_available() then update_transpose_availability(); if volume_canvas then volume_canvas:update() end end end},
  vb:button{text="-24",width=40,notifier=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24); if is_canvas_api_available() then update_transpose_availability(); if volume_canvas then volume_canvas:update() end end end},
  vb:button{text="-12",width=40,notifier=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12); if is_canvas_api_available() then update_transpose_availability(); if volume_canvas then volume_canvas:update() end end end},
  vb:button{text="+12",width=40,notifier=function() PakettiDuplicateInstrumentSamplesWithTranspose(12); if is_canvas_api_available() then update_transpose_availability(); if volume_canvas then volume_canvas:update() end end end},
  vb:button{text="+24",width=40,notifier=function() PakettiDuplicateInstrumentSamplesWithTranspose(24); if is_canvas_api_available() then update_transpose_availability(); if volume_canvas then volume_canvas:update() end end end},
  vb:button{text="+36",width=40,notifier=function() PakettiDuplicateInstrumentSamplesWithTranspose(36); if is_canvas_api_available() then update_transpose_availability(); if volume_canvas then volume_canvas:update() end end end},
  vb:button{text="All",width=30,notifier=function() duplicate_all_octaves() end}
},

-- Volume controls  
is_canvas_api_available() and canvas_title_button or vb:space{},
is_canvas_api_available() and canvas_row or vb:space{},
slider_title_button,
slider_rows[1],
slider_rows[2], 
slider_rows[3],
slider_rows[4],
slider_rows[5],
slider_rows[6],
slider_rows[7],

-- Expandable Paketti Steppers Section
vb:row{
  steppers_toggle_button,
  vb:text{
    text = "Show Paketti Steppers Dialog Content",
    style = "strong",
    font = "bold",
    width = 300
  }
},


-- Collapsible Steppers Content
steppers_content_column
}
  
  -- Show the dialog
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Stacker", dialog_content, keyhandler)
  
  -- Show which volume control mode is active and initialize
  if is_canvas_api_available() and not prefer_sliders_over_canvas then
    renoise.app():show_status("Paketti Stacker: Canvas mode (v6.2+ API) - Click title to switch to sliders")
    -- Update canvas colors based on available transpose levels
    update_transpose_availability()
    if volume_canvas then
      volume_canvas:update()
    end
  elseif is_canvas_api_available() and prefer_sliders_over_canvas then
    renoise.app():show_status("Paketti Stacker: Slider mode (v6.2+ API, user preference) - Click title to switch to canvas")
  else
    renoise.app():show_status("Paketti Stacker: Slider mode (legacy API)")
  end
  
  -- Set up instrument change observer
  if not instrument_observable then
    instrument_observable = renoise.song().selected_instrument_index_observable
    instrument_observable:add_notifier(update_volume_controls_for_instrument)
  end
  
  -- Set up pattern length observer
  if not pattern_observable then
    pattern_observable = renoise.song().selected_pattern.number_of_lines_observable
    pattern_observable:add_notifier(update_pattern_buttons)
  end
  
  -- Initialize pattern button texts
  update_pattern_buttons()
  
  -- Initialize steppers section visibility
  update_steppers_visibility()
  
  -- Set up dialog close cleanup
  local original_close = dialog.close
  dialog.close = function(self)
    if instrument_observable then
      pcall(function() instrument_observable:remove_notifier(update_volume_controls_for_instrument) end)
      instrument_observable = nil
    end
    if pattern_observable then
      pcall(function() pattern_observable:remove_notifier(update_pattern_buttons) end)
      pattern_observable = nil
    end
    original_close(self)
  end
end

  function proceed_with_stacking()
    local song=renoise.song()
    local current_track = song.selected_track
    
    -- Remove *Instr. Macros device if it exists
    for i = #current_track.devices, 2, -1 do
      if current_track.devices[i].name == "*Instr. Macros" then
        current_track:delete_device_at(i)
        break
      end
    end

    -- Run the isolation function synchronously (no ProcessSlicer)
    PakettiIsolateSlicesToInstrumentNoProcess()
    
    if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
    -- Add *Instr. Macros device back
    loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
end
    local instrument = song.selected_instrument
    local samples = instrument.samples
    local num_samples = #samples

    -- Base note and note range to apply to all samples
    local base_note = 48 -- Default to C-4
    local note_range = {0, 119} -- Restrict to a single key

    for i = 1, num_samples do
      local sample = samples[i]
      
      -- First slice gets velocity 0, rest get 1-127
      local velocity = (i == 1) and 0 or (i - 1)

      sample.sample_mapping.map_velocity_to_volume = false
      sample.sample_mapping.base_note = base_note
      sample.sample_mapping.note_range = note_range
      sample.sample_mapping.velocity_range = {velocity, velocity} -- Each slice gets exactly one velocity
    end
  end

function auto_stack_from_existing_pattern()
    print("--- Auto Stack from Existing Pattern ---")
    
    local song = renoise.song()
    local current_track_index = song.selected_track_index
    local current_pattern = song.selected_pattern
    local current_track_data = current_pattern:track(current_track_index)
    local original_instrument_index = song.selected_instrument_index
    
    -- 1. ANALYZE: Read the current track's pattern data
    local slice_sequence = {}
    print("Analyzing pattern data on track " .. current_track_index)
    
    local current_track = song.selected_track
    local visible_note_columns = current_track.visible_note_columns
    
    for line_index = 1, current_pattern.number_of_lines do
        local line = current_track_data:line(line_index)
        for col = 1, visible_note_columns do
            local note_col = line:note_column(col)
            if not note_col.is_empty and note_col.instrument_value == (original_instrument_index - 1) then
                -- Found a note using current instrument - record the slice info
                local slice_info = {
                    line = line_index,
                    column = col,
                    note_value = note_col.note_value,
                    volume = note_col.volume_value,
                    delay = note_col.delay_value,
                    panning = note_col.panning_value,
                    effect_number = note_col.effect_number_value,
                    effect_amount = note_col.effect_amount_value
                }
                table.insert(slice_sequence, slice_info)
                print("Found slice at line " .. line_index .. ", note " .. note_col.note_value .. " (" .. note_value_to_string(note_col.note_value) .. ")")
            end
        end
    end
    
    if #slice_sequence == 0 then
        renoise.app():show_status("No notes found using current instrument on this track")
        print("Error: No notes found using current instrument")
        return
    end
    
    print("Found " .. #slice_sequence .. " notes to convert")
    
    -- 2. STACK: Check if we need to isolate slices first, or just stack existing samples
    local instrument = song:instrument(original_instrument_index)
    local has_slices = instrument.samples[1] and instrument.samples[1].slice_markers and #instrument.samples[1].slice_markers > 0
    
    if has_slices then
        print("Found slices - running isolation...")
        PakettiIsolateSlicesToInstrument() -- Creates individual samples from slices
        -- After isolation, we need to get the NEW instrument that was created
        instrument = song.selected_instrument -- Get the newly created instrument
        original_instrument_index = song.selected_instrument_index -- Update to new instrument index
    end
    
    -- Set up simple velocity mapping for all samples
    print("Setting up velocity mapping...")
    local samples = instrument.samples
    local num_samples = #samples
    
    for i = 1, num_samples do
        local sample = samples[i]
        local velocity = i -- Sample 1 = velocity 1, Sample 2 = velocity 2, etc.
        
        sample.sample_mapping.map_velocity_to_volume = false
        sample.sample_mapping.base_note = 48 -- C-4
        sample.sample_mapping.note_range = {0, 119}
        sample.sample_mapping.velocity_range = {velocity, velocity} -- Each sample gets exactly one velocity
        
        print("Sample " .. i .. " mapped to velocity " .. velocity)
    end
    
    -- 3. CREATE: New track
    print("Creating new track...")
    song:insert_track_at(current_track_index + 1)
    song.selected_track_index = current_track_index + 1
    
    -- 4. TRANSLATE: Convert slice sequence to velocity sequence on new track
    print("Translating slice notes to velocity notes...")
    local new_track_data = current_pattern:track(song.selected_track_index)
    
    for _, slice_info in ipairs(slice_sequence) do
        local line = new_track_data:line(slice_info.line)
        local note_col = line:note_column(slice_info.column)
        
        -- Calculate velocity based on original note value (C-0 = velocity 1, C#0 = velocity 2, etc.)
        local velocity = slice_info.note_value + 1 -- Convert 0-based note to 1-based velocity
        velocity = math.min(127, velocity) -- Cap at 127
        
        -- Write note with velocity = slice mapping
        note_col.note_value = 48 -- C-4 base note for stacked instrument
        note_col.instrument_value = original_instrument_index - 1 -- Use the original (now stacked) instrument
        note_col.volume_value = velocity -- Velocity triggers the right sample
        note_col.delay_value = slice_info.delay
        note_col.panning_value = slice_info.panning
        note_col.effect_number_value = slice_info.effect_number
        note_col.effect_amount_value = slice_info.effect_amount
        
        print("Converted " .. note_value_to_string(slice_info.note_value) .. " to velocity " .. velocity)
    end
    
    renoise.app():show_status("Auto-stacked! " .. #slice_sequence .. " slice notes → velocity-mapped samples on new track")
    print("--- Auto Stack Complete ---")
    returnpe()
end

function LoadSliceIsolateStack()
  -- Initial Operations
  pitchBendMultipleSampleLoader()
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
--    renoise.app():show_status("Velocity mappings updated, vel->vol set to OFF for " .. num_samples .. " samples.")

    renoise.song().selected_line_index = 1
pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument)
    set_loop_mode_for_selected_instrument(renoise.Sample.LOOP_MODE_FORWARD)
 --   selectedInstrumentAllAutoseekControl(1) -- this shouldn't be included in the mix.
    selectedInstrumentAllAutofadeControl(1)
    setSelectedInstrumentInterpolation(4)
    if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
    loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
    end
    renoise.app():show_status("The Slices have been turned to Samples. The Samples have been Stacked together. The Velocity controls the Sample Selection. The Pattern now has a ramp up for the samples.")
  end

renoise.tool():add_keybinding{name="Global:Paketti:Load&Slice&Isolate&Stack Sample",invoke=function() LoadSliceIsolateStack() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stacker Dialog...",invoke=function() pakettiStackerDialog(proceed_with_stacking, on_switch_changed, PakettiIsolateSlicesToInstrument) end}

--------------------------------------------------------------------------------
-- PHRASE INTEGRATION (PhraseGrid Integration)
--------------------------------------------------------------------------------

-- Create one phrase per velocity layer (each phrase plays one slice via velocity)
function PakettiStackerCreateVelocityPhrases()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local num_samples = #instrument.samples
  if num_samples == 0 then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  local phrases_created = 0
  
  for i = 1, num_samples do
    local sample = instrument.samples[i]
    
    -- Get velocity range from sample mapping
    local vel_range = sample.sample_mapping and sample.sample_mapping.velocity_range
    local velocity = vel_range and vel_range[1] or (i - 1)
    
    -- Create new phrase
    local phrase_count = #instrument.phrases
    local new_phrase_index = phrase_count + 1
    instrument:insert_phrase_at(new_phrase_index)
    
    local phrase = instrument.phrases[new_phrase_index]
    phrase.number_of_lines = 4
    phrase.lpb = song.transport.lpb
    phrase.name = string.format("Vel %02d (%s)", velocity, sample.name:sub(1, 20))
    phrase.volume_column_visible = true
    
    -- Write single note with specific velocity
    local phrase_line = phrase:line(1)
    local note_col = phrase_line:note_column(1)
    note_col.note_value = 48  -- C-4
    note_col.instrument_value = song.selected_instrument_index - 1
    note_col.volume_value = velocity
    
    phrases_created = phrases_created + 1
  end
  
  renoise.app():show_status(string.format("Created %d velocity phrases from stacked samples", phrases_created))
  return phrases_created
end

-- Create a phrase that cycles through all velocity values
function PakettiStackerCreateVelocityCyclePhrase()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local num_samples = #instrument.samples
  if num_samples == 0 then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  
  local phrase = instrument.phrases[new_phrase_index]
  phrase.number_of_lines = math.min(num_samples, 256)  -- Limit to max phrase length
  phrase.lpb = song.transport.lpb
  phrase.name = "Velocity Cycle"
  phrase.volume_column_visible = true
  
  -- Write one note per line, cycling through velocities
  for i = 1, math.min(num_samples, 256) do
    local sample = instrument.samples[i]
    local vel_range = sample.sample_mapping and sample.sample_mapping.velocity_range
    local velocity = vel_range and vel_range[1] or (i - 1)
    
    local phrase_line = phrase:line(i)
    local note_col = phrase_line:note_column(1)
    note_col.note_value = 48  -- C-4
    note_col.instrument_value = song.selected_instrument_index - 1
    note_col.volume_value = velocity
  end
  
  song.selected_phrase_index = new_phrase_index
  renoise.app():show_status(string.format("Created velocity cycle phrase with %d steps", math.min(num_samples, 256)))
  return new_phrase_index
end

-- Create a phrase with random velocity values per line
-- length: number of lines (default 16)
-- density: probability of note on each line, 0.0-1.0 (default 1.0 = every line)
-- allow_rests: if true, includes empty lines based on density (default false for compatibility)
function PakettiStackerCreateRandomVelocityPhrase(length, density, allow_rests)
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local num_samples = #instrument.samples
  if num_samples == 0 then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  -- Initialize random seed
  if trueRandomSeed then
    trueRandomSeed()
  else
    math.randomseed(os.time())
  end
  
  length = length or 16  -- Default to 16 lines
  density = density or 1.0  -- Default to 100% density (note on every line)
  if allow_rests == nil then allow_rests = false end
  
  -- Get valid velocity values from sample mappings
  local valid_velocities = {}
  for i = 1, num_samples do
    local sample = instrument.samples[i]
    local vel_range = sample.sample_mapping and sample.sample_mapping.velocity_range
    local velocity = vel_range and vel_range[1] or (i - 1)
    table.insert(valid_velocities, velocity)
  end
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  
  local phrase = instrument.phrases[new_phrase_index]
  phrase.number_of_lines = length
  phrase.lpb = song.transport.lpb
  local density_pct = math.floor(density * 100)
  phrase.name = string.format("Random %d%%", density_pct)
  phrase.volume_column_visible = true
  
  -- Write random velocity notes
  local notes_written = 0
  for i = 1, length do
    -- Check density - should we write a note on this line?
    local should_write = true
    if allow_rests then
      should_write = (math.random() <= density)
    end
    
    if should_write then
      local random_index = math.random(1, #valid_velocities)
      local velocity = valid_velocities[random_index]
      
      local phrase_line = phrase:line(i)
      local note_col = phrase_line:note_column(1)
      note_col.note_value = 48  -- C-4
      note_col.instrument_value = song.selected_instrument_index - 1
      note_col.volume_value = velocity
      notes_written = notes_written + 1
    end
  end
  
  song.selected_phrase_index = new_phrase_index
  renoise.app():show_status(string.format("Created random phrase: %d lines, %d notes", length, notes_written))
  return new_phrase_index
end

-- Create random phrase with specific length (shortcut functions)
function PakettiStackerCreateRandomPhrase8()
  return PakettiStackerCreateRandomVelocityPhrase(8, 1.0, false)
end

function PakettiStackerCreateRandomPhrase16()
  return PakettiStackerCreateRandomVelocityPhrase(16, 1.0, false)
end

function PakettiStackerCreateRandomPhrase32()
  return PakettiStackerCreateRandomVelocityPhrase(32, 1.0, false)
end

function PakettiStackerCreateRandomPhrase64()
  return PakettiStackerCreateRandomVelocityPhrase(64, 1.0, false)
end

-- Create sparse random phrase (50% density with rests)
function PakettiStackerCreateSparseRandomPhrase(length)
  return PakettiStackerCreateRandomVelocityPhrase(length or 16, 0.5, true)
end

-- Create a PhraseGrid bank from stacked velocity layers
function PakettiStackerCreatePhraseBankFromStacked()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local num_samples = #instrument.samples
  if num_samples == 0 then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  -- First create velocity phrases
  local phrases_created = PakettiStackerCreateVelocityPhrases()
  
  -- Then create a PhraseGrid bank if PhraseWorkflow is available
  if PakettiPhraseBankCreate and phrases_created and phrases_created > 0 then
    local bank_index = PakettiPhraseBankCreate(song.selected_instrument_index, "Stacker Bank")
    if bank_index and PakettiPhraseBanks[bank_index] then
      -- Assign phrases to bank slots (up to 8)
      local num_phrases = #instrument.phrases
      local start_phrase = num_phrases - phrases_created + 1
      for i = 1, math.min(8, phrases_created) do
        PakettiPhraseBankSetSlot(bank_index, i, start_phrase + i - 1)
      end
      renoise.app():show_status(string.format("Created Stacker Bank with %d phrases", math.min(8, phrases_created)))
    end
  else
    renoise.app():show_status(string.format("Created %d velocity phrases (PhraseGrid bank not available)", phrases_created or 0))
  end
end

-- Create a phrase from the current pattern track (preserving velocities)
function PakettiStackerCreatePhraseFromPattern()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  
  -- Check if it's a note track
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Select a note track first")
    return
  end
  
  local pattern_track = pattern:track(track_index)
  local pattern_length = pattern.number_of_lines
  local instrument_index = song.selected_instrument_index - 1
  
  -- Collect all notes from the pattern track for this instrument
  local notes_found = {}
  local visible_columns = track.visible_note_columns
  
  for line_idx = 1, pattern_length do
    local line = pattern_track:line(line_idx)
    for col_idx = 1, visible_columns do
      local note_col = line:note_column(col_idx)
      if not note_col.is_empty and note_col.instrument_value == instrument_index then
        table.insert(notes_found, {
          line = line_idx,
          column = col_idx,
          note_value = note_col.note_value,
          instrument_value = note_col.instrument_value,
          volume_value = note_col.volume_value,
          panning_value = note_col.panning_value,
          delay_value = note_col.delay_value,
          effect_number_value = note_col.effect_number_value,
          effect_amount_value = note_col.effect_amount_value
        })
      end
    end
  end
  
  if #notes_found == 0 then
    renoise.app():show_status("No notes for current instrument found in pattern")
    return
  end
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  
  local phrase = instrument.phrases[new_phrase_index]
  phrase.number_of_lines = pattern_length
  phrase.lpb = song.transport.lpb
  phrase.name = string.format("From Pattern %02d", song.selected_pattern_index)
  phrase.volume_column_visible = true
  phrase.delay_column_visible = true
  phrase.sample_effects_column_visible = true
  
  -- Find max column used
  local max_column = 1
  for _, note_data in ipairs(notes_found) do
    if note_data.column > max_column then
      max_column = note_data.column
    end
  end
  phrase.visible_note_columns = max_column
  
  -- Write notes to phrase
  for _, note_data in ipairs(notes_found) do
    local phrase_line = phrase:line(note_data.line)
    local note_col = phrase_line:note_column(note_data.column)
    
    note_col.note_value = note_data.note_value
    note_col.instrument_value = note_data.instrument_value
    note_col.volume_value = note_data.volume_value
    note_col.panning_value = note_data.panning_value
    note_col.delay_value = note_data.delay_value
    note_col.effect_number_value = note_data.effect_number_value
    note_col.effect_amount_value = note_data.effect_amount_value
  end
  
  song.selected_phrase_index = new_phrase_index
  renoise.app():show_status(string.format("Created phrase from pattern with %d notes", #notes_found))
  return new_phrase_index
end

--------------------------------------------------------------------------------
-- STACKER PHRASE STUDIO DIALOG
--------------------------------------------------------------------------------

-- Dialog state
local stacker_studio_dialog = nil
local stacker_studio_vb = nil

-- UI element references for updates
local studio_instrument_text = nil
local studio_status_text = nil
local studio_layers_column = nil
local studio_phrases_popup = nil
local studio_current_phrase_text = nil

-- Refresh the studio dialog content
function PakettiStackerStudioRefresh()
  if not stacker_studio_dialog or not stacker_studio_dialog.visible then return end
  
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then return end
  
  -- Update instrument name
  if studio_instrument_text then
    studio_instrument_text.text = instrument.name ~= "" and instrument.name or "(unnamed)"
  end
  
  -- Update status
  if studio_status_text then
    studio_status_text.text = PakettiStackerGetStatusString(instrument)
  end
  
  -- Update phrase popup
  if studio_phrases_popup then
    local phrase_items = {}
    for i = 1, #instrument.phrases do
      local phrase = instrument.phrases[i]
      local vel_info = PakettiStackerGetPhraseVelocityInfo(instrument, i)
      local vel_str = ""
      if vel_info and #vel_info > 0 then
        if #vel_info == 1 then
          vel_str = string.format(" [Vel %02X]", vel_info[1])
        else
          vel_str = string.format(" [Vel %02X-%02X]", vel_info[1], vel_info[#vel_info])
        end
      end
      table.insert(phrase_items, string.format("%02d: %s%s", i, phrase.name:sub(1, 20), vel_str))
    end
    if #phrase_items == 0 then
      phrase_items = {"(no phrases)"}
    end
    studio_phrases_popup.items = phrase_items
    if song.selected_phrase_index > 0 and song.selected_phrase_index <= #phrase_items then
      studio_phrases_popup.value = song.selected_phrase_index
    end
  end
  
  -- Update current phrase indicator
  if studio_current_phrase_text then
    if song.selected_phrase_index > 0 and song.selected_phrase_index <= #instrument.phrases then
      studio_current_phrase_text.text = string.format("Phrase %02d", song.selected_phrase_index)
    else
      studio_current_phrase_text.text = "No phrase"
    end
  end
end

-- Create velocity layers view
function PakettiStackerStudioCreateLayersView(vb)
  local song = renoise.song()
  local instrument = song.selected_instrument
  local layers = PakettiStackerGetVelocityLayers(instrument)
  
  local rows = {}
  
  if #layers == 0 then
    table.insert(rows, vb:text{text = "(No velocity layers detected)", style = "disabled"})
  else
    -- Limit to first 16 layers to avoid huge dialogs
    local max_display = math.min(#layers, 16)
    for i = 1, max_display do
      local layer = layers[i]
      local vel_range_str = string.format("[%02X-%02X]", layer.velocity_min, layer.velocity_max)
      local sample_name = layer.sample_name:sub(1, 25)
      if #layer.sample_name > 25 then
        sample_name = sample_name .. "..."
      end
      
      table.insert(rows, vb:row{
        spacing = 5,
        vb:text{text = vel_range_str, font = "mono", width = 60},
        vb:text{text = sample_name, width = 180}
      })
    end
    
    if #layers > max_display then
      table.insert(rows, vb:text{
        text = string.format("... and %d more layers", #layers - max_display),
        style = "disabled"
      })
    end
  end
  
  return vb:column{
    style = "group",
    margin = 5,
    vb:text{text = "VELOCITY LAYERS", font = "bold"},
    unpack(rows)
  }
end

-- Show the Stacker Phrase Studio dialog
function PakettiStackerPhraseStudioShow()
  local song = renoise.song()
  if not song then return end
  
  -- Close existing dialog
  if stacker_studio_dialog and stacker_studio_dialog.visible then
    stacker_studio_dialog:close()
    stacker_studio_dialog = nil
    return
  end
  
  stacker_studio_vb = renoise.ViewBuilder()
  local vb = stacker_studio_vb
  
  local instrument = song.selected_instrument
  local is_stacked = PakettiStackerIsVelocityStacked(instrument)
  
  -- Build phrase items
  local phrase_items = {}
  if instrument then
    for i = 1, #instrument.phrases do
      local phrase = instrument.phrases[i]
      table.insert(phrase_items, string.format("%02d: %s", i, phrase.name:sub(1, 25)))
    end
  end
  if #phrase_items == 0 then
    phrase_items = {"(no phrases)"}
  end
  
  -- Create UI elements with references
  studio_instrument_text = vb:text{
    text = instrument and (instrument.name ~= "" and instrument.name or "(unnamed)") or "No instrument",
    font = "bold",
    width = 250
  }
  
  studio_status_text = vb:text{
    text = PakettiStackerGetStatusString(instrument),
    style = is_stacked and "strong" or "normal",
    width = 250
  }
  
  studio_phrases_popup = vb:popup{
    items = phrase_items,
    value = song.selected_phrase_index > 0 and song.selected_phrase_index or 1,
    width = 250,
    notifier = function(value)
      if value > 0 and instrument and value <= #instrument.phrases then
        song.selected_phrase_index = value
      end
    end
  }
  
  studio_current_phrase_text = vb:text{
    text = song.selected_phrase_index > 0 and string.format("Phrase %02d", song.selected_phrase_index) or "No phrase",
    font = "bold",
    width = 80
  }
  
  -- Build content
  local content = vb:column{
    margin = 10,
    spacing = 5,
    
    -- Instrument Info Section
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "INSTRUMENT", font = "bold"},
      vb:row{
        vb:text{text = "Name:", width = 50},
        studio_instrument_text
      },
      vb:row{
        vb:text{text = "Status:", width = 50},
        studio_status_text
      }
    },
    
    -- Velocity Layers Section
    PakettiStackerStudioCreateLayersView(vb),
    
    -- Phrase Creation Section
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "CREATE PHRASES", font = "bold"},
      vb:row{
        spacing = 5,
        vb:button{text = "Layer", width = 50, tooltip = "One phrase per velocity layer", notifier = function()
          PakettiStackerCreateVelocityPhrases()
          PakettiStackerStudioRefresh()
        end},
        vb:button{text = "Cycle", width = 50, tooltip = "Cycle through all layers", notifier = function()
          PakettiStackerCreateVelocityCyclePhrase()
          PakettiStackerStudioRefresh()
        end},
        vb:button{text = "Random", width = 55, tooltip = "Random velocity pattern", notifier = function()
          PakettiStackerCreateRandomPhrase16()
          PakettiStackerStudioRefresh()
        end},
        vb:button{text = "Sparse", width = 50, tooltip = "Random with 50% density", notifier = function()
          PakettiStackerCreateSparseRandomPhrase(16)
          PakettiStackerStudioRefresh()
        end},
        vb:button{text = "From Pat", width = 60, tooltip = "From current pattern", notifier = function()
          PakettiStackerCreatePhraseFromPattern()
          PakettiStackerStudioRefresh()
        end}
      }
    },
    
    -- Phrases Section
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "PHRASES", font = "bold"},
      vb:row{
        vb:text{text = "Select:", width = 50},
        studio_phrases_popup
      },
      vb:row{
        spacing = 5,
        vb:button{text = "< Prev", width = 60, notifier = function()
          if instrument and #instrument.phrases > 0 then
            local new_idx = song.selected_phrase_index - 1
            if new_idx < 1 then new_idx = #instrument.phrases end
            song.selected_phrase_index = new_idx
            PakettiStackerStudioRefresh()
          end
        end},
        vb:button{text = "Next >", width = 60, notifier = function()
          if instrument and #instrument.phrases > 0 then
            local new_idx = song.selected_phrase_index + 1
            if new_idx > #instrument.phrases then new_idx = 1 end
            song.selected_phrase_index = new_idx
            PakettiStackerStudioRefresh()
          end
        end},
        vb:button{text = "Delete", width = 55, notifier = function()
          if instrument and song.selected_phrase_index > 0 and song.selected_phrase_index <= #instrument.phrases then
            instrument:delete_phrase_at(song.selected_phrase_index)
            PakettiStackerStudioRefresh()
          end
        end}
      }
    },
    
    -- Pattern Integration Section
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "PATTERN INTEGRATION", font = "bold"},
      vb:row{
        spacing = 5,
        vb:button{text = "Auto-Fill Pattern", width = 120, tooltip = "Fill pattern with Zxx phrase triggers", notifier = function()
          if PakettiPhraseAutoFillPattern then
            PakettiPhraseAutoFillPattern()
          else
            renoise.app():show_status("Auto-fill function not available")
          end
        end},
        vb:button{text = "Clear Pattern", width = 100, tooltip = "Clear current track in pattern", notifier = function()
          local pattern = song.selected_pattern
          local track_index = song.selected_track_index
          local pattern_track = pattern:track(track_index)
          pattern_track:clear()
          renoise.app():show_status("Pattern track cleared")
        end}
      },
      vb:row{
        vb:text{text = string.format("Pattern: %02d (%d lines)", song.selected_pattern_index, song.selected_pattern.number_of_lines)}
      }
    },
    
    -- Live Switching Section
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "LIVE SWITCHING", font = "bold"},
      vb:row{
        spacing = 5,
        vb:button{text = "<", width = 30, notifier = function()
          if instrument and #instrument.phrases > 0 then
            local new_idx = song.selected_phrase_index - 1
            if new_idx < 1 then new_idx = #instrument.phrases end
            song.selected_phrase_index = new_idx
            PakettiStackerStudioRefresh()
            -- Inject phrase trigger if switcher is available
            if PakettiPhraseSwitcherInject then
              PakettiPhraseSwitcherInject(new_idx)
            end
          end
        end},
        studio_current_phrase_text,
        vb:button{text = ">", width = 30, notifier = function()
          if instrument and #instrument.phrases > 0 then
            local new_idx = song.selected_phrase_index + 1
            if new_idx > #instrument.phrases then new_idx = 1 end
            song.selected_phrase_index = new_idx
            PakettiStackerStudioRefresh()
            -- Inject phrase trigger if switcher is available
            if PakettiPhraseSwitcherInject then
              PakettiPhraseSwitcherInject(new_idx)
            end
          end
        end},
        vb:button{text = "Trigger Now", width = 80, tooltip = "Write Zxx trigger at current position", notifier = function()
          if PakettiPhraseSwitcherInject then
            PakettiPhraseSwitcherInject(song.selected_phrase_index, "trigger", "line")
          else
            -- Fallback: write directly
            local pattern = song.selected_pattern
            local track_index = song.selected_track_index
            local line_index = song.selected_line_index
            local pattern_track = pattern:track(track_index)
            local line = pattern_track:line(line_index)
            local note_col = line:note_column(1)
            note_col.note_value = 48
            note_col.instrument_value = song.selected_instrument_index - 1
            note_col.effect_number_value = 0x23
            note_col.effect_amount_value = song.selected_phrase_index
            song.tracks[track_index].sample_effects_column_visible = true
            renoise.app():show_status(string.format("Wrote Z%02X trigger", song.selected_phrase_index))
          end
        end}
      }
    },
    
    -- Refresh and Close buttons
    vb:row{
      spacing = 10,
      vb:button{text = "Refresh", width = 80, notifier = function()
        stacker_studio_dialog:close()
        PakettiStackerPhraseStudioShow()
      end},
      vb:button{text = "Close", width = 80, notifier = function()
        stacker_studio_dialog:close()
      end}
    }
  }
  
  stacker_studio_dialog = renoise.app():show_custom_dialog(
    "Stacker Phrase Studio",
    content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Phrase Studio Dialog...", invoke=PakettiStackerPhraseStudioShow}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Velocity Phrases", invoke=PakettiStackerCreateVelocityPhrases}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Velocity Cycle Phrase", invoke=PakettiStackerCreateVelocityCyclePhrase}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Random Velocity Phrase", invoke=function() PakettiStackerCreateRandomVelocityPhrase(16) end}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Random Phrase (8 lines)", invoke=PakettiStackerCreateRandomPhrase8}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Random Phrase (16 lines)", invoke=PakettiStackerCreateRandomPhrase16}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Random Phrase (32 lines)", invoke=PakettiStackerCreateRandomPhrase32}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Random Phrase (64 lines)", invoke=PakettiStackerCreateRandomPhrase64}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Sparse Random Phrase", invoke=function() PakettiStackerCreateSparseRandomPhrase(16) end}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Phrase Bank from Stacked", invoke=PakettiStackerCreatePhraseBankFromStacked}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Create Phrase from Pattern", invoke=PakettiStackerCreatePhraseFromPattern}

-- MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:Stacker Phrase Studio [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerPhraseStudioShow() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Velocity Phrases [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateVelocityPhrases() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Velocity Cycle Phrase [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateVelocityCyclePhrase() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Random Velocity Phrase [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateRandomVelocityPhrase(16) end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Random Phrase 8 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateRandomPhrase8() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Random Phrase 16 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateRandomPhrase16() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Random Phrase 32 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateRandomPhrase32() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Random Phrase 64 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateRandomPhrase64() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Sparse Random Phrase [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreateSparseRandomPhrase(16) end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Phrase Bank [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreatePhraseBankFromStacked() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Create Phrase from Pattern [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerCreatePhraseFromPattern() end end}

--------------------------------------------------------------------------------
-- RENDER + PHRASEGRID INTEGRATION
--------------------------------------------------------------------------------

-- Render current pattern and stack the result with velocity mapping
function PakettiStackerRenderPatternAndStack(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local slice_count = options.slice_count or 8
  
  -- Use PhraseGrid render function if available
  if PakettiRenderPatternToPhrase then
    -- Set up for stacking workflow
    PakettiRenderPhraseContext.post_process = "stack"
    
    PakettiRenderPatternToPhrase({
      slice_count = slice_count,
      normalize = options.normalize ~= false,
      create_phrases = false,  -- We'll create velocity phrases instead
      add_to_bank = false
    })
    
    -- After render completes, we need to stack
    -- This is handled by the callback chain
    renoise.app():show_status("Rendering pattern for stacking...")
  else
    renoise.app():show_status("Render function not available")
  end
end

-- Create stacked instrument from rendered audio with automatic phrase creation
function PakettiStackerFromRenderedAudio()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  if #instrument.samples == 0 then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  local sample = instrument.samples[1]
  if not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Sample has no data")
    return
  end
  
  -- Check if already sliced
  local slice_count = #sample.slice_markers
  if slice_count == 0 then
    -- Slice first
    if slicerough then
      slicerough(8)
      slice_count = 8
    else
      renoise.app():show_status("No slices and slice function not available")
      return
    end
  end
  
  -- Now isolate slices and stack
  if PakettiIsolateSlicesToInstrumentNoProcess then
    PakettiIsolateSlicesToInstrumentNoProcess()
  elseif PakettiIsolateSlicesToInstrument then
    PakettiIsolateSlicesToInstrument()
  else
    renoise.app():show_status("Slice isolation function not available")
    return
  end
  
  -- Get the updated instrument after isolation
  instrument = song.selected_instrument
  local num_samples = #instrument.samples
  
  -- Set up velocity mapping
  local base_note = 48  -- C-4
  local note_range = {0, 119}
  
  for i = 1, num_samples do
    local s = instrument.samples[i]
    local velocity = (i == 1) and 0 or (i - 1)
    
    s.sample_mapping.map_velocity_to_volume = false
    s.sample_mapping.base_note = base_note
    s.sample_mapping.note_range = note_range
    s.sample_mapping.velocity_range = {velocity, velocity}
  end
  
  -- Create velocity phrases
  local phrases_created = PakettiStackerCreateVelocityPhrases()
  
  -- Create PhraseGrid bank
  if phrases_created and phrases_created > 0 then
    PakettiStackerCreatePhraseBankFromStacked()
  end
  
  renoise.app():show_status(string.format("Stacked %d samples with velocity phrases", num_samples))
end

-- Full workflow: Render -> Slice -> Stack -> Velocity Phrases -> PhraseGrid Bank
function PakettiStackerFullWorkflow(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  -- If PhraseGrid is available, use its full workflow
  if PakettiFullRenderStackWorkflow then
    PakettiFullRenderStackWorkflow(options)
  else
    -- Fallback to local implementation
    PakettiStackerRenderPatternAndStack(options)
  end
end

-- Rearrange stacked instrument velocity patterns on new track
function PakettiStackerRearrangeVelocityToTrack(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local num_samples = #instrument.samples
  if num_samples == 0 then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  local pattern_length = song.selected_pattern.number_of_lines
  local randomize = options.randomize or false
  local step = options.step or math.floor(pattern_length / num_samples)
  
  -- Create new track
  local source_track = song.selected_track_index
  song:insert_track_at(source_track + 1)
  song.selected_track_index = source_track + 1
  
  local track_data = song.selected_pattern:track(song.selected_track_index)
  
  -- Build list of velocities from sample mappings
  local velocity_list = {}
  for i = 1, num_samples do
    local sample = instrument.samples[i]
    local vel_range = sample.sample_mapping and sample.sample_mapping.velocity_range
    local velocity = vel_range and vel_range[1] or (i - 1)
    table.insert(velocity_list, velocity)
  end
  
  -- Optionally randomize order
  if randomize then
    math.randomseed(os.time())
    for i = #velocity_list, 2, -1 do
      local j = math.random(1, i)
      velocity_list[i], velocity_list[j] = velocity_list[j], velocity_list[i]
    end
  end
  
  -- Write notes with velocities
  local current_line = 1
  for _, velocity in ipairs(velocity_list) do
    if current_line > pattern_length then break end
    
    local line = track_data:line(current_line)
    local note_col = line:note_column(1)
    
    note_col.note_value = 48  -- C-4 (base note for stacked instrument)
    note_col.instrument_value = song.selected_instrument_index - 1
    note_col.volume_value = velocity
    
    current_line = current_line + step
  end
  
  song.tracks[song.selected_track_index].name = instrument.name .. " (Rearranged)"
  renoise.app():show_status(string.format("Rearranged %d velocity steps on new track", #velocity_list))
end

-- Keybindings for render integration
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Render and Stack", invoke=function() PakettiStackerRenderPatternAndStack() end}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker From Rendered Audio", invoke=PakettiStackerFromRenderedAudio}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Full Workflow", invoke=function() PakettiStackerFullWorkflow() end}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Rearrange Velocity to Track", invoke=function() PakettiStackerRearrangeVelocityToTrack() end}
renoise.tool():add_keybinding{name="Global:Paketti:Stacker Rearrange Velocity (Random)", invoke=function() PakettiStackerRearrangeVelocityToTrack({randomize = true}) end}

-- MIDI mappings for render integration
renoise.tool():add_midi_mapping{name="Paketti:Stacker Render and Stack [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerRenderPatternAndStack() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker From Rendered Audio [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerFromRenderedAudio() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Full Workflow [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerFullWorkflow() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stacker Rearrange Velocity [Trigger]", invoke=function(message) if message:is_trigger() then PakettiStackerRearrangeVelocityToTrack() end end}