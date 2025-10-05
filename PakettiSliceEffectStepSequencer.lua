-- Paketti Sample Offset / Slice Step Sequencer
-- A comprehensive polyphonic step sequencer: 8 content rows → 8 note columns + 1 reverse control row
-- Supports slices, sample offsets, device parameter automation, and reverse control
--
-- PERFORMANCE OPTIMIZATIONS:
-- - Targeted updates: Only updates the specific row/note column that changed
-- - PakettiEightOneTwenty-inspired flood-fill: Clear once, write active steps only, use copy_from for repetition
-- - Row-specific pattern writes: Each checkbox/control only updates its own row
-- - Efficient repetition using Renoise's copy_from() method instead of recalculating every line
-- - Eliminates audio jitter from excessive pattern manipulation
-- - Auto-selects corresponding note column when interacting with any row control

local vb = renoise.ViewBuilder()
local dialog = nil

-- Configuration
local NUM_ROWS = 8  -- 8 content rows only
local MAX_STEPS = 16
local current_steps = MAX_STEPS

-- Row data structure
local rows = {}
local row_buttons = {}
local row_checkboxes = {}
local row_ui_elements = {}
local row_mode_switches = {}  -- Store references to mode switches for direct updates
local step_valueboxes = {}  -- Store references to step count valueboxes
local note_text_labels = {}  -- Store references to note text labels for dynamic updates
local note_valueboxes = {}  -- Store references to sample offset note valueboxes
local slice_note_valueboxes = {}  -- Store references to slice note valueboxes
local slice_note_labels = {}  -- Store references to slice note text labels
local sample_offset_valueboxes = {}  -- Store references to sample offset valueboxes
local transpose_rotaries = {}  -- Store references to transpose rotaries
local row_containers = {}  -- Store row container references for styling

-- Track change detection
local current_track_index = nil
local track_change_notifier = nil

-- Pattern change detection  
local current_pattern_index = nil
local pattern_change_notifier = nil

-- Dialog initialization flag to prevent pattern writing during population
local initializing_dialog = false

-- Step switching flag to prevent auto Global Slice during step changes
local step_switching_in_progress = false

-- Track currently selected row for styling (like PakettiEightOneTwenty)
local current_selected_row = nil

-- Velocity Canvas Variables (expandable section like PakettiCaptureLastTake gater)
local velocity_canvas_expanded = preferences.pakettiSliceStepSeqShowVelocity.value or false
local velocity_canvas_toggle_button = nil
local velocity_canvas_content_column = nil
local velocity_canvas = nil
local velocity_canvas_width = 480  -- Will be calculated as MAX_STEPS * 30 to match step button width
local velocity_canvas_height = 200
local velocity_canvas_mouse_is_down = false
local velocity_canvas_last_mouse_x = -1
local velocity_canvas_last_mouse_y = -1

-- Velocity slider width (reach close to 4-step separator lines without overlapping)
local velocity_slider_width = 27  -- Step buttons are 30px, sliders touch but don't overlap separators (was 28, now 27)

-- Left offset to align velocity canvas with step buttons (solo checkbox width + spacing)
local velocity_canvas_left_offset = 26

-- Flag to prevent checkbox notifier from overriding velocity canvas settings
local velocity_canvas_setting_velocity = false

-- Calculate velocity canvas width to match step buttons (30px each)
function PakettiSliceStepCalculateVelocityCanvasWidth()
  return MAX_STEPS * 30  -- Step button width exactly (ViewBuilder spacer handles offset)
end

-- Velocity data for each row (16 steps per row, values 0-80)
local row_velocities = {}

-- Initialize velocity data for all rows (will be expanded as needed)
for row = 1, NUM_ROWS do
  row_velocities[row] = {}
  -- Initialize for current MAX_STEPS, but expand dynamically as needed
  for step = 1, 32 do  -- Always initialize for maximum possible steps
    row_velocities[row][step] = 80  -- Default to max velocity (80)
  end
end

-- Row modes
local ROW_MODES = {
  SAMPLE_OFFSET = 1,
  SLICE = 2
}

local MODE_NAMES = {
  [ROW_MODES.SAMPLE_OFFSET] = "Sample Offset (0Sxx)",
  [ROW_MODES.SLICE] = "Slice Notes"
}

-- Current note column tracking for optimized updates
local current_note_column = 1
local last_pattern_state = {}  -- Cache to detect actual changes

-- Playhead state
local playhead_color = nil
local playhead_timer_fn = nil
local playing_observer_fn = nil
local playhead_step_indices = {}

-- (Reverse functionality removed)

-- Velocity Canvas Functions

-- Function to update velocity canvas section visibility (like PakettiCapture gater)
function PakettiSliceStepUpdateVelocityCanvasVisibility()
  if velocity_canvas_content_column then
    velocity_canvas_content_column.visible = velocity_canvas_expanded
  end
  if velocity_canvas_toggle_button then
    velocity_canvas_toggle_button.text = velocity_canvas_expanded and "▾" or "▴"
  end
end

-- Draw the velocity canvas showing velocities for selected row
function PakettiSliceStepDrawVelocityCanvas(ctx)
  -- Calculate width to match current step button layout
  velocity_canvas_width = PakettiSliceStepCalculateVelocityCanvasWidth()
  local w, h = velocity_canvas_width, velocity_canvas_height
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background grid
  ctx.stroke_color = {32, 32, 32, 255}
  ctx.line_width = 1
  
  -- Horizontal grid lines for velocity levels (draw first - behind vertical lines)
  ctx.stroke_color = {32, 32, 32, 255}
  ctx.line_width = 1
  for level = 0, 8 do
    local y = h - (level / 8) * h
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(w, y)
    ctx:stroke()
  end
  
  -- Vertical grid lines for each step (draw second - on top of horizontal lines)
  local step_width = w / MAX_STEPS
  for step = 0, MAX_STEPS do
    local x = step * step_width
    
    -- Make every 4th step line bright white, all others pale grey - both 3px thick
    if step > 0 and (step % 4) == 0 then
      ctx.stroke_color = {255, 255, 255, 255}  -- Bright white for 4-step separators
      ctx.line_width = 3  -- 3px thick
    elseif step > 0 then
      ctx.stroke_color = {80, 80, 80, 255}  -- Pale grey for regular step separators
      ctx.line_width = 3  -- 3px thick (same as 4-step separators)
    else
      ctx.stroke_color = {32, 32, 32, 255}  -- Dark gray for edge (step 0)
      ctx.line_width = 1  -- Thin line for edge
    end
    
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
  end
  
  -- Draw velocity values for current selected row (or row 1 if none selected) - ONLY where steps are active
  local display_row = current_selected_row or 1
  if row_velocities[display_row] and row_checkboxes[display_row] then
    
    -- Draw all step areas first to show where drawing is possible
    for step = 1, MAX_STEPS do
      local step_is_active = row_checkboxes[display_row][step] and row_checkboxes[display_row][step].value
      -- Center the narrower velocity slider within the step button area
      local step_center_x = ((step - 1) * step_width) + (step_width / 2)
      local bar_x = step_center_x - (velocity_slider_width / 2)
      local bar_width = velocity_slider_width
      
      if step_is_active then
        -- Draw active velocity bars in purple
        ctx.fill_color = {120, 40, 160, 255}  -- Purple like canvas experiments
        local velocity = row_velocities[display_row][step] or 80
        local normalized_velocity = velocity / 80.0  -- 0-80 range to 0-1
        local bar_height = normalized_velocity * h
        local bar_y = h - bar_height
        ctx:fill_rect(bar_x, bar_y, bar_width, bar_height)
      else
        -- Draw faint background for inactive steps to show they can be drawn on
        ctx.fill_color = {32, 32, 32, 100}  -- Very dark gray, semi-transparent
        ctx:fill_rect(bar_x, h - 10, bar_width, 8)  -- Small indicator at bottom
      end
    end
  end
  
  -- Draw border
  ctx.stroke_color = {255, 255, 255, 255}
  ctx.line_width = 3  -- Match the 4-step separator thickness (was 2, now 3)
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:stroke()
  
  -- Draw mouse cursor when drawing
  if velocity_canvas_mouse_is_down and velocity_canvas_last_mouse_x >= 0 and velocity_canvas_last_mouse_y >= 0 then
    ctx.stroke_color = {255, 255, 255, 255}
    ctx.line_width = 1
    
    -- Vertical line
    ctx:begin_path()
    ctx:move_to(velocity_canvas_last_mouse_x, 0)
    ctx:line_to(velocity_canvas_last_mouse_x, h)
    ctx:stroke()
    
    -- Horizontal line
    ctx:begin_path()
    ctx:move_to(0, velocity_canvas_last_mouse_y)
    ctx:line_to(w, velocity_canvas_last_mouse_y)
    ctx:stroke()
  end
  
  -- Draw velocity value labels using PakettiCanvasFont
  ctx.stroke_color = {200, 200, 200, 255}
  ctx.line_width = 2
  
  local label_size = 8  -- Match the row number font size (was 10, now 8)
  local label_x = w - 13  -- Moved 2 pixels further to the right (was 15, now 13)
  
  -- Draw "80" at top using proper canvas font with proper digit spacing
  PakettiCanvasFontDrawDigit8(ctx, label_x - label_size - 3, 5, label_size)
  PakettiCanvasFontDrawDigit0(ctx, label_x, 5, label_size)
  
  -- Draw "00" at bottom using proper canvas font with proper digit spacing  
  PakettiCanvasFontDrawDigit0(ctx, label_x - label_size - 3, h - label_size - 5, label_size)
  PakettiCanvasFontDrawDigit0(ctx, label_x, h - label_size - 5, label_size)
  
  -- Display current row info using PakettiCanvasFont
  ctx.stroke_color = {255, 255, 255, 255}
  ctx.line_width = 2
  
  local info_size = 8
  local step_width = w / MAX_STEPS
  local info_x = (step_width / 2) - (info_size / 2)  -- Center horizontally in first step area
  local info_y = 5   -- Match the "80" label y position (was 10, now 5)
  
  -- Draw just the row number using direct function calls (same approach as "80"/"00" labels)
  local row_digit = tostring(display_row or 1)
  if row_digit == "1" then
    PakettiCanvasFontDrawDigit1(ctx, info_x, info_y, info_size)
  elseif row_digit == "2" then
    PakettiCanvasFontDrawDigit2(ctx, info_x, info_y, info_size)
  elseif row_digit == "3" then
    PakettiCanvasFontDrawDigit3(ctx, info_x, info_y, info_size)
  elseif row_digit == "4" then
    PakettiCanvasFontDrawDigit4(ctx, info_x, info_y, info_size)
  elseif row_digit == "5" then
    PakettiCanvasFontDrawDigit5(ctx, info_x, info_y, info_size)
  elseif row_digit == "6" then
    PakettiCanvasFontDrawDigit6(ctx, info_x, info_y, info_size)
  elseif row_digit == "7" then
    PakettiCanvasFontDrawDigit7(ctx, info_x, info_y, info_size)
  elseif row_digit == "8" then
    PakettiCanvasFontDrawDigit8(ctx, info_x, info_y, info_size)
  end
end

-- Handle velocity canvas mouse input
function PakettiSliceStepHandleVelocityCanvasMouse(ev)
  -- CRITICAL: Only handle mouse events if velocity canvas is actually expanded/visible
  if not velocity_canvas_expanded then
    return
  end
  
  -- Use current calculated width to match step buttons
  local w = PakettiSliceStepCalculateVelocityCanvasWidth()
  local h = velocity_canvas_height
  
  if ev.type == "exit" then
    return
  end
  
  if not (ev.position.x >= 0 and ev.position.x < w and ev.position.y >= 0 and ev.position.y < h) then
    if ev.type == "up" then
      velocity_canvas_mouse_is_down = false
      velocity_canvas_last_mouse_x = -1
      velocity_canvas_last_mouse_y = -1
      if velocity_canvas and velocity_canvas.update then
        velocity_canvas:update()
      end
    end
    return
  end
  
  local x = ev.position.x
  local y = ev.position.y
  
  velocity_canvas_last_mouse_x = x
  velocity_canvas_last_mouse_y = y
  
  if ev.type == "down" then
    velocity_canvas_mouse_is_down = true
    PakettiSliceStepHandleVelocityCanvasInput(x, y)
  elseif ev.type == "up" then
    velocity_canvas_mouse_is_down = false
    velocity_canvas_last_mouse_x = -1
    velocity_canvas_last_mouse_y = -1
    if velocity_canvas and velocity_canvas.update then
      velocity_canvas:update()
    end
  elseif ev.type == "move" then
    if velocity_canvas_mouse_is_down then
      PakettiSliceStepHandleVelocityCanvasInput(x, y)
    end
    if velocity_canvas and velocity_canvas.update then
      velocity_canvas:update()
    end
  end
end

-- Handle velocity canvas input for parameter editing
function PakettiSliceStepHandleVelocityCanvasInput(x, y)
  local display_row = current_selected_row or 1
  if not row_velocities[display_row] then return end
  
  -- Use current calculated width to match step buttons
  local canvas_width = PakettiSliceStepCalculateVelocityCanvasWidth()
  local step_width = canvas_width / MAX_STEPS
  local step = math.floor(x / step_width) + 1
  step = math.max(1, math.min(MAX_STEPS, step))
  
  -- Calculate velocity from Y position (inverted: top = 80, bottom = 0)
  local normalized_y = 1.0 - (y / velocity_canvas_height)
  normalized_y = math.max(0, math.min(1, normalized_y))
  
  local velocity = math.floor(normalized_y * 80)
  velocity = math.max(0, math.min(80, velocity))
  
  -- Update velocity for this step
  row_velocities[display_row][step] = velocity
  
  -- CRITICAL: If drawing velocity in an area where step is not active, activate that step!
  if row_checkboxes[display_row] and row_checkboxes[display_row][step] then
    local was_active = row_checkboxes[display_row][step].value
    if not was_active then
      -- Mark that we're setting velocity from canvas to prevent checkbox from overriding it
      velocity_canvas_setting_velocity = true
      -- Activate this step checkbox since user is drawing velocity here
      row_checkboxes[display_row][step].value = true
      velocity_canvas_setting_velocity = false
      renoise.app():show_status("Row " .. display_row .. " Step " .. step .. ": Created new step with velocity " .. string.format("%02d", velocity))
    else
      renoise.app():show_status("Row " .. display_row .. " Step " .. step .. ": Updated velocity to " .. string.format("%02d", velocity))
    end
  end
  
  -- Update button colors to reflect new checkbox state
  PakettiSliceStepUpdateButtonColors()
  
  -- Apply changes to pattern immediately (this will write both the step and its velocity)
  if not initializing_dialog then
    PakettiSliceStepWriteRowToPattern(display_row)
  end
  
  -- Update canvas to show new state
  if velocity_canvas and velocity_canvas.update then
    velocity_canvas:update()
  end
end

-- Update velocity canvas when row selection changes
function PakettiSliceStepUpdateVelocityCanvasForRow(row)
  if velocity_canvas and velocity_canvas_expanded and velocity_canvas.update then
    velocity_canvas:update()
  end
end

-- Apply velocities from a specific row to pattern
function PakettiSliceStepApplyRowVelocitiesToPattern(row)
  if initializing_dialog then return end
  if not row_velocities[row] then return end
  
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_track
  
  if not pattern or not track then return end
  if row > track.visible_note_columns then return end
  
  local pattern_track = pattern:track(track_index)
  local pattern_length = pattern.number_of_lines
  
  -- Get row step count
  local row_steps = (rows[row] and rows[row].active_steps) or MAX_STEPS
  
  -- Apply velocities across entire pattern with replication
  for line = 1, pattern_length do
    local step_in_sequence = ((line - 1) % row_steps) + 1
    
    if step_in_sequence <= MAX_STEPS then
      local velocity = row_velocities[row][step_in_sequence]
      
      if velocity then
        local pattern_line = pattern_track:line(line)
        local note_col = pattern_line:note_column(row)
        
        -- Only apply velocity to lines that have notes (not empty or OFF)
        if note_col.note_string ~= "---" and note_col.note_string ~= "" and note_col.note_string ~= "OFF" then
          -- Convert 0-80 range to Renoise 0-127 range
          local renoise_velocity = math.floor((velocity / 80) * 127)
          renoise_velocity = math.max(0, math.min(127, renoise_velocity))
          
          -- Apply velocity (0-127 range, 255 = empty)
          note_col.volume_value = (renoise_velocity == 0) and 0 or renoise_velocity
        end
      end
    end
  end
end

-- Read existing velocities from pattern (only where notes exist)
function PakettiSliceStepReadVelocitiesFromPattern()
  if not renoise.song() then return end
  
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  
  local pattern_track = pattern:track(track_index)
  local lines_to_read = math.min(MAX_STEPS, pattern.number_of_lines)
  
  -- Reset all velocities to default first
  for row = 1, NUM_ROWS do
    for step = 1, MAX_STEPS do
      row_velocities[row][step] = 80  -- Default max velocity
    end
  end
  
  -- Read velocities from first MAX_STEPS lines for each row (only where notes exist)
  for row = 1, NUM_ROWS do
    if row <= song.selected_track.visible_note_columns then
      for step = 1, lines_to_read do
        local pattern_line = pattern_track:line(step)
        local note_col = pattern_line:note_column(row)
        
        -- Only read velocities where there are actual notes (aligns with new behavior)
        if note_col.note_string ~= "---" and note_col.note_string ~= "" and note_col.note_string ~= "OFF" then
          if note_col.volume_value and note_col.volume_value ~= 255 then
            -- Convert Renoise 0-127 range to 0-80 range
            local velocity_80 = math.floor((note_col.volume_value / 127) * 80)
            velocity_80 = math.max(0, math.min(80, velocity_80))
            row_velocities[row][step] = velocity_80
            print("DEBUG: Read velocity " .. velocity_80 .. " from row " .. row .. " step " .. step)
          else
            -- No velocity specified = max velocity
            row_velocities[row][step] = 80
            print("DEBUG: Set default velocity 80 for row " .. row .. " step " .. step .. " (no velocity in pattern)")
          end
        end
      end
    end
  end
  
  print("DEBUG: Finished reading velocities from pattern")
end

-- Sample Offset Visualizer - Shows where 0S effects point to in sample editor
-- Calculate precise frame position from Sample Offset value (0-255)
function PakettiSliceStepSampleOffsetCalculateFrame(offset_value, total_frames)
  if not offset_value or not total_frames or total_frames <= 1 then
    return 1
  end
  
  -- Map 0S value (0-255) to frame position (1 to total_frames)
  -- 0S00 = frame 1, 0SFF = near end frame
  local normalized = offset_value / 255.0
  local frame = math.floor(normalized * (total_frames - 1)) + 1
  
  -- Ensure frame is within valid range
  frame = math.max(1, math.min(frame, total_frames))
  
  return frame
end

-- Update sample editor selection and display to show from Sample Offset position
function PakettiSliceStepSampleOffsetUpdateSelection(offset_value)
  -- Only visualize when in instrument sample editor
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
    return
  end
  
  local song = renoise.song()
  
  -- Check if we have selected instrument and sample
  if not song.selected_instrument or not song.selected_sample then
    return
  end
  
  local sample = song.selected_sample
  local buffer = sample.sample_buffer
  
  -- Check if sample has data
  if not buffer.has_sample_data or buffer.number_of_frames <= 1 then
    return
  end
  
  -- Calculate precise frame position
  local frame = PakettiSliceStepSampleOffsetCalculateFrame(offset_value, buffer.number_of_frames)
  
  -- Set selection to a much more visible range around offset position  
  -- For short samples (8 beats or less, roughly 200,000 frames at 44.1khz), use 3x smaller range
  -- For longer samples, retain the current size
  local base_selection_size = math.min(1000, math.floor(buffer.number_of_frames * 0.01)) -- 1% of sample or 1000 frames, whichever is smaller
  base_selection_size = math.max(base_selection_size, 100) -- But at least 100 frames
  
  -- Determine if this is a short sample (roughly 8 beats at 140 BPM at 44.1kHz = ~200,000 frames)
  local short_sample_threshold = 200000
  local selection_size = base_selection_size
  
  if buffer.number_of_frames < short_sample_threshold then
    -- For short samples, use 3x smaller range
    selection_size = math.floor(base_selection_size / 3)
    selection_size = math.max(selection_size, 50) -- But at least 50 frames for visibility
    print("DEBUG: Short sample detected (" .. buffer.number_of_frames .. " frames), using 3x smaller selection range: " .. selection_size .. " frames")
  else
    -- For longer samples, keep the current size
    print("DEBUG: Long sample detected (" .. buffer.number_of_frames .. " frames), using normal selection range: " .. selection_size .. " frames")
  end
  -- Set selection starting from offset position (not centered)
  local selection_start = frame
  local selection_end = math.min(buffer.number_of_frames, selection_start + selection_size)
  buffer.selection_range = {selection_start, selection_end}
  
  -- Set display range to start FROM the offset position
  -- Get current display range to maintain zoom level/window size
  local current_display = buffer.display_range
  local current_display_length = current_display[2] - current_display[1]
  
  -- Set display to start from the offset frame position
  local new_display_start = frame
  local new_display_end = math.min(buffer.number_of_frames, new_display_start + current_display_length)
  
  -- If we're near the end and can't show full length, adjust start position
  if new_display_end == buffer.number_of_frames and (new_display_end - new_display_start) < current_display_length then
    new_display_start = math.max(1, new_display_end - current_display_length)
  end
  
  buffer.display_range = {new_display_start, new_display_end}
  
  local selection_frames = selection_end - selection_start + 1
  print("DEBUG: Sample Offset 0S" .. string.format("%02X", offset_value) .. " -> Frame " .. frame .. " (" .. math.floor((frame / buffer.number_of_frames) * 100) .. "%), display from " .. new_display_start .. "-" .. new_display_end .. ", selection: " .. selection_start .. "-" .. selection_end .. " (" .. selection_frames .. " frames)")
end

-- Smart transpose function - context-aware instrument transpose
-- If current track has content, transpose the instruments used in that track
-- If current track is empty, transpose the selected instrument
function PakettiSliceStepSmartTranspose(transpose_value)
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end
  
  local current_track_index = song.selected_track_index
  local current_track = song.tracks[current_track_index]
  if not current_track then
    renoise.app():show_status("No track selected")
    return
  end
  
  -- Find instruments used in current track across all patterns
  local track_instruments = {}
  local pattern_sequence = song.sequencer.pattern_sequence
  
  for seq_index = 1, #pattern_sequence do
    local pattern_index = pattern_sequence[seq_index]
    local pattern = song.patterns[pattern_index]
    if pattern and pattern.tracks[current_track_index] then
      local track_in_pattern = pattern.tracks[current_track_index]
      
      -- Check all lines in this track
      for line_index = 1, track_in_pattern.number_of_lines do
        local line = track_in_pattern:line(line_index)
        
        -- Check all note columns for instruments
        for note_column_index = 1, #line.note_columns do
          local note_column = line.note_columns[note_column_index]
          if note_column.instrument_value < 255 then  -- Valid instrument (255 = empty)
            local instrument_index = note_column.instrument_value + 1  -- Convert to 1-based
            track_instruments[instrument_index] = true
          end
        end
      end
    end
  end
  
  -- Count instruments found
  local instrument_count = 0
  local instruments_to_transpose = {}
  for instrument_index, _ in pairs(track_instruments) do
    instrument_count = instrument_count + 1
    instruments_to_transpose[#instruments_to_transpose + 1] = instrument_index
  end
  
  -- Decide what to transpose
  if instrument_count > 0 then
    -- Track has content - transpose instruments used in track
    local transposed_names = {}
    for _, instrument_index in ipairs(instruments_to_transpose) do
      local instrument = song.instruments[instrument_index]
      if instrument then
        -- Clamp transpose value to valid range (-120 to +120)
        local new_transpose = math.max(-120, math.min(120, transpose_value))
        instrument.transpose = new_transpose
        transposed_names[#transposed_names + 1] = string.format("%02X", instrument_index - 1)
      end
    end
    
    local instrument_list = table.concat(transposed_names, ", ")
    renoise.app():show_status(string.format("Track %d instruments [%s] transpose set to %+d", 
      current_track_index, instrument_list, transpose_value))
  else
    -- Track is empty - transpose selected instrument  
    local selected_instrument = song.selected_instrument
    if selected_instrument then
      local new_transpose = math.max(-120, math.min(120, transpose_value))
      selected_instrument.transpose = new_transpose
      renoise.app():show_status(string.format("Selected instrument [%02X] transpose set to %+d", 
        song.selected_instrument_index - 1, transpose_value))
    else
      renoise.app():show_status("No instrument selected and track is empty")
    end
  end
end

-- Colors
local normal_color = {0,0,0}
local beat_color = {0x22 / 255, 0xaa / 255, 0xff / 255}
local selected_color = {0x80, 0x00, 0x80}

-- Helper function to update sample effects column visibility
function PakettiSliceStepUpdateSampleEffectColumnVisibility()
  local song = renoise.song()
  if not song then return end
  
  local track = song.selected_track
  if not track then return end
  
  -- Check if any rows are using sample offset mode
  local has_sample_offset_mode = false
  for row = 1, NUM_ROWS do
    if rows[row] and rows[row].enabled and rows[row].mode == ROW_MODES.SAMPLE_OFFSET then
      has_sample_offset_mode = true
      break
    end
  end
  
  -- Show sample effect column only if sample offset mode is used
  track.sample_effects_column_visible = has_sample_offset_mode
  
  print("DEBUG: Sample effect column visibility set to " .. tostring(has_sample_offset_mode))
end

-- Helper function to detect and auto-select instrument used in current track
function PakettiSliceStepAutoSelectInstrument()
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_track
  
  -- Scan first few lines of the track to find instrument usage
  local instrument_counts = {}
  local max_lines_to_scan = math.min(32, pattern.number_of_lines)
  
  for line_idx = 1, max_lines_to_scan do
    local pattern_line = pattern:track(track_index):line(line_idx)
    for col = 1, track.visible_note_columns do
      local note_col = pattern_line:note_column(col)
      if note_col.note_string ~= "---" and note_col.note_string ~= "" and note_col.instrument_value < 255 then
        local instrument_index = note_col.instrument_value + 1  -- Convert from 0-based to 1-based
        instrument_counts[instrument_index] = (instrument_counts[instrument_index] or 0) + 1
      end
    end
  end
  
  -- Find the most used instrument
  local most_used_instrument = nil
  local max_count = 0
  for instrument_index, count in pairs(instrument_counts) do
    if count > max_count and instrument_index <= #song.instruments then
      max_count = count
      most_used_instrument = instrument_index
    end
  end
  
  -- Auto-select the most used instrument if different from current
  if most_used_instrument and most_used_instrument ~= song.selected_instrument_index then
    local old_instrument = song.selected_instrument_index
    song.selected_instrument_index = most_used_instrument
    print("DEBUG: Auto-selected instrument " .. most_used_instrument .. " (was instrument " .. old_instrument .. ") based on track usage")
    renoise.app():show_status("Auto-selected instrument " .. most_used_instrument .. " based on track usage")
    return true  -- Instrument was changed
  end
  
  return false  -- No change needed
end

-- Selected step tracking (like PakettiGater)
local selected_steps = {}

-- Initialize row data
function PakettiSliceStepInitializeRows()
  rows = {}
  row_buttons = {}
  row_checkboxes = {}
  row_mode_switches = {}  -- Clear switch references
  step_valueboxes = {}  -- Clear step valuebox references
  note_text_labels = {}  -- Clear note text label references
  note_valueboxes = {}  -- Clear sample offset note valuebox references
  slice_note_valueboxes = {}  -- Clear slice note valuebox references
  slice_note_labels = {}  -- Clear slice note label references
  sample_offset_valueboxes = {}  -- Clear sample offset valuebox references
  transpose_rotaries = {}  -- Clear transpose rotary references
  row_containers = {}  -- Clear row container references
  playhead_step_indices = {}
  selected_steps = {}  -- Initialize selected step tracking
  current_track_index = renoise.song().selected_track_index
  current_pattern_index = renoise.song().selected_pattern_index
  
  local slice_info = PakettiSliceStepGetSliceInfo()
  local default_first_slice = slice_info and slice_info.first_slice_key or 48
  
  -- Don't apply auto Global Slice during initialization - let pattern reading handle it
  local auto_global_slice = false
  if step_switching_in_progress then
    print("DEBUG: Step switching in progress - preserving existing row modes")
  else
    print("DEBUG: Initializing with default modes - pattern reading will apply smart detection")
  end
  
  -- Check if we should initialize with slice mode
  local slice_info = PakettiSliceStepGetSliceInfo()
  local use_slice_mode = slice_info and slice_info.slice_count > 0
  
  for row = 1, NUM_ROWS do
    local row_mode = ROW_MODES.SAMPLE_OFFSET  -- Default to sample offset
    local row_enabled = true
    local slice_note = nil
    
    -- If we have slices, initialize directly with slice mode and proper slice notes
    if use_slice_mode and row <= math.min(8, slice_info.slice_count) then
      row_mode = ROW_MODES.SLICE
      slice_note = slice_info.first_slice_key + (row - 1)  -- Row 1 = first slice (E-2), row 2 = second slice (F-2), etc.
      print("DEBUG: Row " .. row .. " initialized with SLICE mode, slice note " .. slice_note .. " (" .. PakettiSliceStepNoteValueToString(slice_note) .. ")")
    end
    
    rows[row] = {
      mode = row_mode,
      value = 0x20, -- Default sample offset
      note_value = 48, -- C-4 default note
      slice_note = slice_note,
      active_steps = MAX_STEPS,
      enabled = row_enabled, -- Still used for legitimate enable/disable (beyond slice count, etc.)
      soloed = false -- Solo state for UI checkbox
    }
    
    print("DEBUG: Row " .. row .. " created with mode " .. row_mode .. " (enabled: " .. tostring(row_enabled) .. ")")
    
    row_buttons[row] = {}
    row_checkboxes[row] = {}
    playhead_step_indices[row] = nil
    selected_steps[row] = nil  -- No selection by default
    
    for step = 1, MAX_STEPS do
      row_checkboxes[row][step] = nil -- Will be created by ViewBuilder
    end
  end
  
  -- Initialization complete - pattern reading will apply smart detection
  print("DEBUG: Row initialization complete - pattern reading will apply smart mode detection")
end

-- Helper function to update step count label display - REMOVED (redundant with step count valuebox)

-- Set active steps for a specific row (like PakettiGater)
function PakettiSliceStepSetActiveSteps(row, step_count)
  if not rows[row] then return end
  
  rows[row].active_steps = step_count
  
  -- Only highlight button if step count is different from MAX_STEPS (like PakettiGater)
  if step_count ~= MAX_STEPS then
    selected_steps[row] = step_count  -- Track which step was selected
  else
    selected_steps[row] = nil  -- No selection for default MAX_STEPS
  end
  
  -- Update the step count valuebox if it exists
  if step_valueboxes[row] then
    step_valueboxes[row].value = step_count
  end
  
  -- Update button colors and write to pattern
  PakettiSliceStepUpdateButtonColors()
  renoise.app():show_status("Row " .. row .. ": Step count set to " .. step_count)
  
  if not initializing_dialog then
    -- Only update this specific row, not entire pattern
    PakettiSliceStepWriteRowToPattern(row)
  end
end

-- Playhead functionality
function PakettiSliceStepResolvePlayheadColor()
  local choice = (preferences and preferences.PakettiGrooveboxPlayheadColor and preferences.PakettiGrooveboxPlayheadColor.value) or 2
  if choice == 1 then return nil end -- None
  if choice == 2 then return {255,128,0} end -- Bright Orange
  if choice == 3 then return {64,0,96} end -- Deeper Purple
  if choice == 4 then return {0,0,0} end -- Black
  if choice == 5 then return {255,255,255} end -- White
  if choice == 6 then return {64,64,64} end -- Dark Grey
  return {255,128,0}
end

function PakettiSliceStepUpdatePlayheadHighlights()
  if not dialog or not dialog.visible then return end
  local song = renoise.song()
  if not song then return end
  
  -- Use cursor position when not playing, playback position when playing
  local current_line = song.selected_line_index
  if song.transport.playing then
    local pos = song.transport.playback_pos
    if pos and pos.line then current_line = pos.line end
  end
  if not current_line then return end
  
  local changed = false
  
  for row = 1, NUM_ROWS do
    local row_data = rows[row]
    if not row_data.enabled then
      if playhead_step_indices[row] ~= nil then
        playhead_step_indices[row] = nil
        changed = true
      end
    else
      local steps = row_data.active_steps
      local new_idx = nil
      
      if steps and steps > 0 then
        local within_steps_window_index = ((current_line - 1) % steps) + 1
        
        if steps <= MAX_STEPS then
          new_idx = within_steps_window_index
        elseif within_steps_window_index <= MAX_STEPS then
          new_idx = within_steps_window_index
        end
      end
      
      if playhead_step_indices[row] ~= new_idx then
        playhead_step_indices[row] = new_idx
        changed = true
      end
    end
  end
  
  if changed then
    PakettiSliceStepUpdateButtonColors()
  end
end

-- (CheckReverseControl function removed - reverse functionality removed)

-- Track change detection and UI refresh
function PakettiSliceStepSetupTrackChangeDetection()
  if track_change_notifier then return end -- Already setup
  
  track_change_notifier = function()
    local new_track_index = renoise.song().selected_track_index
    if new_track_index ~= current_track_index then
      local old_track_index = current_track_index
      current_track_index = new_track_index
      print("DEBUG: Track changed from " .. (old_track_index or "nil") .. " to " .. new_track_index)
      
      -- Auto-select instrument based on new track
      PakettiSliceStepAutoSelectInstrument()
      
      -- Read pattern data from new track to update dialog
      if dialog and dialog.visible then
        print("DEBUG: Track change - reading pattern from new track")
        PakettiSliceStepReadExistingPattern()
        
        -- Update step counts and step view based on new track's column names
        local song = renoise.song()
        if song and song.selected_track then
          local track = song.selected_track
          if track.max_note_columns >= 1 then
            local first_column_name = track:column_name(1)
            local old_steps = current_steps
            if first_column_name:find("_32") then
              current_steps = 32
              MAX_STEPS = 32
            elseif first_column_name:find("_16") then
              current_steps = 16
              MAX_STEPS = 16
            end
            
            if current_steps ~= old_steps then
              print("DEBUG: Track change - step count changed from " .. old_steps .. " to " .. current_steps)
              -- Refresh dialog to update step view
              PakettiSliceStepRefreshDialog()
            else
              -- Just update button colors and sample effect column visibility
              PakettiSliceStepUpdateButtonColors()
              PakettiSliceStepUpdateSampleEffectColumnVisibility()
            end
          end
        end
      end
      
      renoise.app():show_status("Step Sequencer: Track changed to " .. new_track_index .. ", updated dialog content")
    end
  end
  
  if renoise.song().selected_track_index_observable and 
     not renoise.song().selected_track_index_observable:has_notifier(track_change_notifier) then
    renoise.song().selected_track_index_observable:add_notifier(track_change_notifier)
  end
end

function PakettiSliceStepCleanupTrackChangeDetection()
  local song = renoise.song()
  if track_change_notifier and song.selected_track_index_observable and 
     song.selected_track_index_observable:has_notifier(track_change_notifier) then
    song.selected_track_index_observable:remove_notifier(track_change_notifier)
  end
  track_change_notifier = nil
end

-- Pattern change detection and UI refresh
function PakettiSliceStepSetupPatternChangeDetection()
  if pattern_change_notifier then return end -- Already setup
  
  pattern_change_notifier = function()
    local new_pattern_index = renoise.song().selected_pattern_index
    if new_pattern_index ~= current_pattern_index then
      local old_pattern_index = current_pattern_index
      current_pattern_index = new_pattern_index
      print("DEBUG: Pattern changed from " .. (old_pattern_index or "nil") .. " to " .. new_pattern_index)
      
      -- Read pattern data from new pattern to update dialog
      if dialog and dialog.visible then
        print("DEBUG: Pattern change - reading pattern data from new pattern")
        PakettiSliceStepReadExistingPattern()
        
        -- Update button colors and sample effect column visibility  
        PakettiSliceStepUpdateButtonColors()
        PakettiSliceStepUpdateSampleEffectColumnVisibility()
      end
      
      renoise.app():show_status("Step Sequencer: Pattern changed to " .. new_pattern_index .. ", updated dialog content")
    end
  end
  
  if renoise.song().selected_pattern_index_observable and 
     not renoise.song().selected_pattern_index_observable:has_notifier(pattern_change_notifier) then
    renoise.song().selected_pattern_index_observable:add_notifier(pattern_change_notifier)
  end
end

function PakettiSliceStepCleanupPatternChangeDetection()
  local song = renoise.song()
  if pattern_change_notifier and song.selected_pattern_index_observable and 
     song.selected_pattern_index_observable:has_notifier(pattern_change_notifier) then
    song.selected_pattern_index_observable:remove_notifier(pattern_change_notifier)
  end
  pattern_change_notifier = nil
end

-- (CalculateReverseStep function removed - reverse functionality removed)

-- (Reverse visualization function removed - reverse functionality removed)

function PakettiSliceStepSetupPlayhead()
  local song = renoise.song()
  if not song then return end
  
  if not playhead_timer_fn then
    playhead_timer_fn = function()
      PakettiSliceStepUpdatePlayheadHighlights()
    end
    renoise.tool():add_timer(playhead_timer_fn, 40)
  end
  
  if not playing_observer_fn then
    playing_observer_fn = function()
      playhead_color = PakettiSliceStepResolvePlayheadColor()
      PakettiSliceStepUpdatePlayheadHighlights()
    end
    if song.transport.playing_observable and not song.transport.playing_observable:has_notifier(playing_observer_fn) then
      song.transport.playing_observable:add_notifier(playing_observer_fn)
    end
  end
  
  playhead_color = PakettiSliceStepResolvePlayheadColor()
end

function PakettiSliceStepCleanupPlayhead()
  local song = renoise.song()
  if playhead_timer_fn then
    if renoise.tool():has_timer(playhead_timer_fn) then
      renoise.tool():remove_timer(playhead_timer_fn)
    end
    playhead_timer_fn = nil
  end
  if song and playing_observer_fn and song.transport.playing_observable and song.transport.playing_observable:has_notifier(playing_observer_fn) then
    song.transport.playing_observable:remove_notifier(playing_observer_fn)
  end
  playing_observer_fn = nil
  for row = 1, NUM_ROWS do
    playhead_step_indices[row] = nil
  end
end

-- Button color management
function PakettiSliceStepUpdateButtonColors()
  if not dialog or not dialog.visible then return end
  
  for row = 1, NUM_ROWS do
    if row_buttons[row] then
      for step = 1, MAX_STEPS do
        if row_buttons[row][step] then
          local is_beat_marker = ((step - 1) % 4 == 0)
          local is_playhead = (playhead_step_indices[row] == step and playhead_color)
          local is_active_step = (step <= rows[row].active_steps)
          local is_selected = (selected_steps[row] == step)
          
          if is_playhead then
            row_buttons[row][step].color = playhead_color
          elseif is_selected then
            row_buttons[row][step].color = selected_color -- Purple for selected step
          elseif not is_active_step then
            row_buttons[row][step].color = {0.3, 0.3, 0.3} -- Dimmed for inactive steps
          elseif is_beat_marker then
            row_buttons[row][step].color = beat_color
          else
            row_buttons[row][step].color = normal_color
          end
        end
      end
    end
  end
end

-- Row styling (similar to PakettiEightOneTwenty)
function PakettiSliceStepUpdateRowStyles(selected_row_index)
  for row = 1, NUM_ROWS do
    local rc = row_containers[row]
    if rc then
      -- Available row styles: plain | border | group | panel | body
      if row == selected_row_index then
        rc.style = "group" -- SELECTED: subtle outline
      else
        rc.style = "body"   -- NOT-SELECTED: light background
      end
    end
  end
end

-- Direct row highlighting function (like PakettiEightOneTwenty)
function PakettiSliceStepHighlightRow(row_index)
  if initializing_dialog then return end
  current_selected_row = row_index
  PakettiSliceStepUpdateRowStyles(current_selected_row)
  -- Also select the corresponding note column
  PakettiSliceStepSelectNoteColumnOnly(row_index)
  -- Update velocity canvas for new row selection
  PakettiSliceStepUpdateVelocityCanvasForRow(row_index)
end

-- Separated note column selection without styling (to avoid double styling calls)
function PakettiSliceStepSelectNoteColumnOnly(row)
  local song = renoise.song()
  if not song then return end
  
  local track = song.selected_track
  
  -- Ensure enough note columns are visible
  if track.visible_note_columns < row then
    track.visible_note_columns = row
  end
  
  -- Select the corresponding note column (row 1 -> note column 1, etc.)
  if row >= 1 and row <= track.visible_note_columns then
    song.selected_note_column_index = row
    -- Also ensure we're in the pattern editor and focused on note columns
    if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then 
      return
    else 
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
    print("DEBUG: Selected note column " .. row .. " for step sequencer row " .. row)
  end
end

-- Row step selection
function PakettiSliceStepSelectStep(row, step)
  -- Set active steps for all modes
  PakettiSliceStepSetRowSteps(row, step)
end

-- Cached slice info to avoid repeated detection
local cached_slice_info = nil
local cached_instrument_index = nil

-- Slice detection
function PakettiSliceStepGetSliceInfo()
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then return nil end
  
  local current_instrument_index = song.selected_instrument_index
  
  -- Return cached result if instrument hasn't changed
  if cached_slice_info and cached_instrument_index == current_instrument_index then
    return cached_slice_info
  end
  
  local first_sample = instrument.samples[1]
  if #first_sample.slice_markers == 0 then 
    cached_slice_info = nil
    cached_instrument_index = current_instrument_index
    return nil 
  end
  
  print("DEBUG: SLICE DETECTION - Found " .. #first_sample.slice_markers .. " slice markers")
  
  -- Find the actual key mappings using the proper layer access
  local min_note = nil
  local max_note = nil
  local first_slice_key = nil
  local all_slice_notes = {}
  
  -- Check NOTE_ON layer mappings (layer 1 is NOTE_ON)
  local note_on_mappings = instrument.sample_mappings[1]
  if note_on_mappings and #note_on_mappings > 0 then
    print("DEBUG: SLICE DETECTION - Found " .. #note_on_mappings .. " NOTE_ON sample mappings")
    
    -- DEBUG: Print all sample mappings and collect all notes
    for i = 1, #note_on_mappings do
      local mapping = note_on_mappings[i]
      if mapping and mapping.note_range then
        print("DEBUG: Mapping " .. i .. " - Range: " .. mapping.note_range[1] .. "-" .. mapping.note_range[2])
        
        -- Collect all notes from all mappings (for sliced instruments, all mappings are relevant)
        for note = mapping.note_range[1], mapping.note_range[2] do
          table.insert(all_slice_notes, note)
          if not min_note or note < min_note then
            min_note = note
          end
          if not max_note or note > max_note then
            max_note = note
          end
        end
      else
        print("DEBUG: Mapping " .. i .. " - Invalid mapping or no note_range")
      end
    end
  else
    print("DEBUG: SLICE DETECTION - No NOTE_ON mappings found!")
  end
  
  -- The FIRST SLICE is the SECOND mapping ([1][2]), not the first ([1][1] = full sample)
  if all_slice_notes and #all_slice_notes > 1 then
    table.sort(all_slice_notes)
    local full_sample_key = all_slice_notes[1] -- [1][1] = full sample
    first_slice_key = all_slice_notes[2] -- [1][2] = FIRST SLICE
    print("DEBUG: SLICE DETECTION - Full sample key: " .. full_sample_key .. " (" .. PakettiSliceStepNoteValueToString(full_sample_key) .. ")")
    print("DEBUG: SLICE DETECTION - First slice key: " .. first_slice_key .. " (" .. PakettiSliceStepNoteValueToString(first_slice_key) .. ")")
    print("DEBUG: SLICE DETECTION - Note range: " .. min_note .. " to " .. max_note .. " (" .. PakettiSliceStepNoteValueToString(min_note) .. " to " .. PakettiSliceStepNoteValueToString(max_note) .. ")")
  elseif #all_slice_notes == 1 then
    -- Only one mapping found (just the full sample)
    print("DEBUG: SLICE DETECTION - Only full sample found, no slice mappings!")
    first_slice_key = 48 -- C-4 fallback
    min_note = 48
    max_note = 48 + #first_sample.slice_markers
  else
    -- Fallback if no mappings found at all
    print("DEBUG: SLICE DETECTION - NO MAPPINGS FOUND! Using fallback C-4")
    first_slice_key = 48 -- C-4
    min_note = 48
    max_note = 48 + #first_sample.slice_markers
  end
  
  local function note_to_string(note_value)
    local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
    local octave = math.floor(note_value / 12)
    local note = (note_value % 12) + 1
    return note_names[note] .. octave
  end
  
  local slice_count = #first_sample.slice_markers  -- Number of actual slices, NOT including the full sample
  local was_detected = (all_slice_notes and #all_slice_notes > 0)
  local detection_info = was_detected and " (detected)" or " (fallback - no keymaps found!)"
  
  -- Cache the result
  cached_slice_info = {
    slice_count = slice_count,
    sample = first_sample,
    first_slice_key = first_slice_key or 48,
    min_note = min_note,
    max_note = max_note,
    note_range = "First slice: " .. note_to_string(first_slice_key or 48) .. detection_info .. " | Range: " .. note_to_string(first_slice_key or 48) .. " to " .. note_to_string(max_note),
    was_detected = was_detected
  }
  cached_instrument_index = current_instrument_index
  
  return cached_slice_info
end

-- Clear slice info cache (call when instrument changes)
function PakettiSliceStepClearSliceCache()
  cached_slice_info = nil
  cached_instrument_index = nil
end

-- Refresh slice UI elements after slice notes have been applied
function PakettiSliceStepRefreshSliceUI()
  print("DEBUG: PakettiSliceStepRefreshSliceUI - Updating slice UI elements")
  
  for row = 1, NUM_ROWS do
    if rows[row] and rows[row].mode == ROW_MODES.SLICE and rows[row].slice_note then
      -- Update slice note valuebox if it exists
      if slice_note_valueboxes[row] then
        slice_note_valueboxes[row].value = rows[row].slice_note
        print("DEBUG: Refreshed slice valuebox for row " .. row .. " to " .. rows[row].slice_note)
      end
      
      -- Update slice note label if it exists
      if slice_note_labels[row] then
        slice_note_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].slice_note)
        print("DEBUG: Refreshed slice label for row " .. row .. " to " .. PakettiSliceStepNoteValueToString(rows[row].slice_note))
      end
    end
  end
end

-- (Device parameter detection functions removed)

-- Get current note column from cursor position
function PakettiSliceStepGetCurrentNoteColumn()
  local song = renoise.song()
  if not song then return 1 end
  
  -- Use the current cursor position to determine which note column we're working with
  local edit_pos = song.selected_line_index
  local note_col = song.selected_note_column_index
  
  -- Clamp to valid range
  if note_col < 1 then note_col = 1 end
  if note_col > NUM_ROWS then note_col = NUM_ROWS end
  
  return note_col
end

-- Select the note column corresponding to the step sequencer row
function PakettiSliceStepSelectNoteColumn(row)
  local song = renoise.song()
  if not song then return end
  
  local track = song.selected_track
  
  -- Ensure enough note columns are visible
  if track.visible_note_columns < row then
    track.visible_note_columns = row
  end
  
  -- Select the corresponding note column (row 1 -> note column 1, etc.)
  if row >= 1 and row <= track.visible_note_columns then
    song.selected_note_column_index = row
    -- Also ensure we're in the pattern editor and focused on note columns
    if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then return
    else 
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
    print("DEBUG: Selected note column " .. row .. " for step sequencer row " .. row)
  end
  
  -- Update row styling to show which row is selected
  current_selected_row = row
  PakettiSliceStepUpdateRowStyles(current_selected_row)
end

-- Select the slice or highlight sample offset corresponding to the step sequencer row
function PakettiSliceStepSelectSliceForRow(row)
  local song = renoise.song()
  if not song then return end
  
  -- Check if we have valid row data
  if not rows[row] then return end
  
  if rows[row].mode == ROW_MODES.SLICE and rows[row].slice_note then
    -- SLICE mode: select the corresponding slice sample
    local slice_note = rows[row].slice_note
    local sample_index = PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
    
    if sample_index and sample_index >= 1 then
      local instrument = song.selected_instrument
      if instrument and sample_index <= #instrument.samples then
        song.selected_sample_index = sample_index
        print("DEBUG: Selected slice sample " .. sample_index .. " for row " .. row .. " (slice note " .. slice_note .. " - " .. PakettiSliceStepNoteValueToString(slice_note) .. ")")
      end
    end
  elseif rows[row].mode == ROW_MODES.SAMPLE_OFFSET then
    -- SAMPLE_OFFSET mode: highlight the sample offset position in sample editor
    local offset_value = rows[row].value or 0x20
    PakettiSliceStepSampleOffsetUpdateSelection(offset_value)
    print("DEBUG: Highlighted sample offset 0S" .. string.format("%02X", offset_value) .. " for row " .. row)
  end
end

-- PakettiEightOneTwenty-inspired optimization: Clear once, write active steps only, use copy_from for repetition
function PakettiSliceStepWriteRowToPattern(target_row)
  if initializing_dialog then return end
  
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_track
  local pattern_length = pattern.number_of_lines
  
  -- Ensure enough note columns are visible for this specific row
  if track.visible_note_columns < target_row then
    track.visible_note_columns = target_row
  end
  
  -- Ensure sample effect column is visible for sample offset mode
  if rows[target_row].mode == ROW_MODES.SAMPLE_OFFSET then
    track.sample_effects_column_visible = true
  end
  
  local row_data = rows[target_row]
  local row_steps = row_data.active_steps
  
  -- STEP 1: Clear this row's entire column once (PakettiEightOneTwenty approach)
  for line = 1, pattern_length do
    local pattern_line = pattern:track(track_index):line(line)
    
    -- Clear note column for this row
    if target_row <= track.visible_note_columns then
      pattern_line:note_column(target_row):clear()
    end
    
    -- Clear sample effect column if in sample offset mode
    if row_data.mode == ROW_MODES.SAMPLE_OFFSET and target_row <= track.visible_note_columns then
      pattern_line:note_column(target_row).effect_number_string = ""
      pattern_line:note_column(target_row).effect_amount_string = ""
    end
  end
  
  -- STEP 2: Update column name to show step count
  if target_row <= track.max_note_columns then
    if target_row == 1 then
      -- Row 1 uses special format with view setting
      local view_setting = string.format("%02d", row_steps) .. "_" .. current_steps
      track:set_column_name(target_row, view_setting)
      print("DEBUG: Updated column " .. target_row .. " name to '" .. view_setting .. "' for row " .. target_row .. " (" .. row_steps .. " steps + view setting)")
    else
      -- Other rows use simple step count format
      track:set_column_name(target_row, string.format("%02d", row_steps))
      print("DEBUG: Updated column " .. target_row .. " name to '" .. string.format("%02d", row_steps) .. "' for row " .. target_row .. " (" .. row_steps .. " steps)")
    end
  end
  
  -- STEP 3: Write only ACTIVE steps to first row_steps lines (not all lines!)
  -- Note: Solo/mute is now handled by track column muting, not by disabling pattern writing
  for step = 1, math.min(MAX_STEPS, row_steps) do
    if row_checkboxes[target_row][step] and row_checkboxes[target_row][step].value then
      local pattern_line = pattern:track(track_index):line(step)
      PakettiSliceStepWriteStepToLine(target_row, step, pattern_line, track)
    end
  end
  
  -- STEP 4: Use copy_from for efficient repetition (PakettiEightOneTwenty approach)
  if pattern_length > row_steps then
    local full_repeats = math.floor(pattern_length / row_steps)
    for repeat_num = 1, full_repeats - 1 do
      local start_line = repeat_num * row_steps + 1
      for step = 1, math.min(MAX_STEPS, row_steps) do
        if start_line + step - 1 <= pattern_length then
          local source_line = pattern:track(track_index):line(step)
          local dest_line = pattern:track(track_index):line(start_line + step - 1)
          
          -- Copy note column efficiently
          if target_row <= track.visible_note_columns then
            dest_line:note_column(target_row):copy_from(source_line:note_column(target_row))
          end
          
          -- Copy sample effect efficiently if in sample offset mode
          if row_data.mode == ROW_MODES.SAMPLE_OFFSET and target_row <= track.visible_note_columns then
            dest_line:note_column(target_row).effect_number_string = source_line:note_column(target_row).effect_number_string
            dest_line:note_column(target_row).effect_amount_string = source_line:note_column(target_row).effect_amount_string
          end
        end
      end
    end
  end
  
--  renoise.app():show_status("Flood-filled row " .. target_row .. " pattern")
end

-- Helper function: Write a single step to a single line (extracted from PakettiSliceStepWriteRowToLine)
function PakettiSliceStepWriteStepToLine(row, step, pattern_line, track)
  local row_data = rows[row]
  local note_col = nil
  
  if row_data.mode == ROW_MODES.SAMPLE_OFFSET then
    -- Write sample offset command AND note to same note column
    if row <= track.visible_note_columns then
      local note_string = PakettiSliceStepNoteValueToString(row_data.note_value)
      note_col = pattern_line:note_column(row)
      note_col.note_string = note_string
      note_col.instrument_value = renoise.song().selected_instrument_index - 1
      -- Write sample offset to note column sample effect
      note_col.effect_number_string = "0S"
      note_col.effect_amount_string = string.format("%02X", row_data.value)
    end
    
  elseif row_data.mode == ROW_MODES.SLICE then
    -- Write specific slice note for this row
    local slice_info = PakettiSliceStepGetSliceInfo()
    if slice_info and row <= track.visible_note_columns then
      local note_value = row_data.slice_note or (slice_info.first_slice_key + row - 1)
      local note_string = PakettiSliceStepNoteValueToString(note_value)
      
      note_col = pattern_line:note_column(row)
      note_col.note_string = note_string
      note_col.instrument_value = renoise.song().selected_instrument_index - 1
    end
  end
  
  -- Apply velocity from velocity canvas
  if note_col and row_velocities[row] and row_velocities[row][step] then
    local velocity = row_velocities[row][step]
    -- Convert 0-80 range to Renoise 0-127 range
    local renoise_velocity = math.floor((velocity / 80) * 127)
    renoise_velocity = math.max(0, math.min(127, renoise_velocity))
    
    -- Apply velocity (0-127 range, 255 = empty)
    note_col.volume_value = (renoise_velocity == 0) and 0 or renoise_velocity
  end
end

-- Original function kept for full updates when needed
function PakettiSliceStepWriteToPattern()
  -- Don't write to pattern during dialog initialization/population
  if initializing_dialog then return end
  
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_track
  
  -- Ensure enough note columns are visible (up to 8 for all rows)
  local max_note_columns_needed = 0
  for row = 1, NUM_ROWS do
    if rows[row].enabled and (rows[row].mode == ROW_MODES.SLICE or rows[row].mode == ROW_MODES.SAMPLE_OFFSET) then
      max_note_columns_needed = math.max(max_note_columns_needed, row)
    end
  end
  
  if max_note_columns_needed > 0 then
    track.visible_note_columns = math.max(track.visible_note_columns, max_note_columns_needed)
  end
  
  -- Ensure sample effect column is visible for sample offset mode
  local has_sample_offset_mode = false
  for row = 1, NUM_ROWS do
    if rows[row].enabled and rows[row].mode == ROW_MODES.SAMPLE_OFFSET then
      has_sample_offset_mode = true
      break
    end
  end
  if has_sample_offset_mode then
    track.sample_effects_column_visible = true
  end
  
  local pattern_length = pattern.number_of_lines
  
  -- Clear all existing content first
  PakettiSliceStepClearAllPattern(pattern, track_index, track, pattern_length)
  
  -- Set column names to show step counts for all rows
  PakettiSliceStepWriteStepCountMarkers(pattern, track_index, track)
  
  -- Write pattern line by line to handle multiple simultaneous triggers
  for line = 1, pattern_length do
    local pattern_line = pattern:track(track_index):line(line)
    
    -- Process each row for this line
    for row = 1, NUM_ROWS do
      if rows[row].enabled then
        PakettiSliceStepWriteRowToLine(row, line, pattern_line, track)
      end
    end
  end
  
  renoise.app():show_status("Step sequencer pattern applied")
end

-- Set note column names to show step counts AND store view setting in first column
function PakettiSliceStepWriteStepCountMarkers(pattern, track_index, track)
  -- Column 1 gets special treatment: stores both row 1 step count and view setting
  if track.max_note_columns >= 1 then
    local first_row_steps = rows[1].active_steps or current_steps
    local view_setting = string.format("%02d", first_row_steps) .. "_" .. current_steps
    track:set_column_name(1, view_setting)
    print("DEBUG: Set column 1 name to '" .. view_setting .. "' to store " .. current_steps .. "-step view setting (first row: " .. first_row_steps .. " steps)")
  end
  
  -- Set column names to show step counts for other enabled rows (2-8)
  for row = 2, NUM_ROWS do
    if rows[row].enabled and row <= track.max_note_columns then
      local step_count = rows[row].active_steps
      -- Set column name to show step count (e.g., "04", "08", "16")
      track:set_column_name(row, string.format("%02d", step_count))
      print("DEBUG: Set column " .. row .. " name to '" .. string.format("%02d", step_count) .. "' for row " .. row .. " (" .. step_count .. " steps)")
    end
  end
end

-- Read step counts from note column names AND view setting from first column
function PakettiSliceStepReadStepCountMarkers(pattern, track_index, track)
  -- First, check column 1 for view setting (e.g. "04_32" or "08_16") and row 1 step count
  if track.max_note_columns >= 1 then
    local first_column_name = track:column_name(1)
    if first_column_name:find("_32") then
      current_steps = 32
      MAX_STEPS = 32
      print("DEBUG: Found 32-step view setting in first column: '" .. first_column_name .. "'")
    elseif first_column_name:find("_16") then
      current_steps = 16
      MAX_STEPS = 16
      print("DEBUG: Found 16-step view setting in first column: '" .. first_column_name .. "'")
    end
    
    -- Extract row 1 step count from the format "XX_YY"
    local row1_steps = first_column_name:match("(%d+)_")
    if row1_steps then
      local step_count = tonumber(row1_steps)
      if step_count and step_count >= 1 and step_count <= 32 then
        rows[1].active_steps = step_count
        if step_valueboxes[1] then
          step_valueboxes[1].value = step_count
        end
        print("DEBUG: Read row 1 step count " .. step_count .. " from column 1 name '" .. first_column_name .. "'")
      end
    end
  end
  
  -- Read step counts from column names for other rows (2-8)
  for row = 2, NUM_ROWS do
    if row <= track.max_note_columns then
      local column_name = track:column_name(row)
      local step_count = tonumber(column_name)
      
      if step_count and step_count >= 1 and step_count <= 32 then
        rows[row].active_steps = step_count
        -- Update the UI step valuebox to reflect the read step count
        if step_valueboxes[row] then
          step_valueboxes[row].value = step_count
        end
        print("DEBUG: Read column " .. row .. " name '" .. column_name .. "' - updated row " .. row .. " step count to " .. step_count .. " and UI elements")
      else
        -- If column name is not a number or is invalid, use default
        print("DEBUG: Column " .. row .. " name '" .. column_name .. "' is not a valid step count, using default for row " .. row)
      end
    end
  end
end

-- New approach: write to specific line and handle multiple simultaneous triggers
function PakettiSliceStepWriteRowToLine(row, line, pattern_line, track)
  local row_data = rows[row]
  local row_steps = row_data.active_steps
  
  local step_in_pattern = ((line - 1) % row_steps) + 1
  
  -- Check if this step should trigger
  if step_in_pattern <= MAX_STEPS and row_checkboxes[row][step_in_pattern] and row_checkboxes[row][step_in_pattern].value then
    
    if row_data.mode == ROW_MODES.SAMPLE_OFFSET then
      -- Ensure we have enough note columns visible for this row
      if track.visible_note_columns < row then
        track.visible_note_columns = row
      end
      
      -- Write sample offset command AND note to same note column
      local note_string = PakettiSliceStepNoteValueToString(row_data.note_value)
      pattern_line:note_column(row).note_string = note_string
      pattern_line:note_column(row).instrument_value = renoise.song().selected_instrument_index - 1
      -- Write sample offset to note column sample effect
      pattern_line:note_column(row).effect_number_string = "0S"
      pattern_line:note_column(row).effect_amount_string = string.format("%02X", row_data.value)
      print("DEBUG: Sample Offset Row " .. row .. " wrote " .. note_string .. " to note column " .. row .. " with 0S" .. string.format("%02X", row_data.value) .. " (sample effect)")
      
    elseif row_data.mode == ROW_MODES.SLICE then
      -- Write specific slice note for this row using the slice_note value
      local slice_info = PakettiSliceStepGetSliceInfo()
      if slice_info then
        local note_value = row_data.slice_note or (slice_info.first_slice_key + row - 1)
        local note_string = PakettiSliceStepNoteValueToString(note_value)
        
        -- Ensure we have enough note columns visible for this row
        if track.visible_note_columns < row then
          track.visible_note_columns = row
        end
        
        -- Use row number as note column (1-8)
        pattern_line:note_column(row).note_string = note_string
        pattern_line:note_column(row).instrument_value = renoise.song().selected_instrument_index - 1
        print("DEBUG: Slice Row " .. row .. " wrote " .. note_string .. " (note value: " .. note_value .. ") to note column " .. row)
      else
        -- No slices available - inform user
        renoise.app():show_status("Slice mode: No sliced instrument detected on row " .. row .. " - load a sliced sample first!")
        return  -- Don't write anything
      end
      
    -- (Device parameter mode removed)
    end
  end
end

function PakettiSliceStepClearAllPattern(pattern, track_index, track, pattern_length)
  -- Clear all note columns and effect columns that this step sequencer uses
  for line = 1, pattern_length do
    local pattern_line = pattern:track(track_index):line(line)
    
    -- Clear note columns (up to 8)
    for col = 1, math.min(8, track.visible_note_columns) do
      pattern_line:note_column(col).note_string = "---"
      pattern_line:note_column(col).instrument_value = 255 -- Empty
      pattern_line:note_column(col).volume_string = ""
      pattern_line:note_column(col).panning_string = ""
      pattern_line:note_column(col).delay_string = ""
      -- Clear note column sample effects  
      pattern_line:note_column(col).effect_number_string = ""
      pattern_line:note_column(col).effect_amount_string = ""
    end
    
    -- ALWAYS clear effect columns - especially important for slice modes to clear sample offsets
    for col = 1, math.min(8, #pattern_line.effect_columns) do
      pattern_line.effect_columns[col].number_string = ""
      pattern_line.effect_columns[col].amount_string = ""
    end
  end
end

function PakettiSliceStepNoteValueToString(note_value)
  local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local octave = math.floor(note_value / 12)
  local note = (note_value % 12) + 1
  return note_names[note] .. octave
end

function PakettiSliceStepNoteStringToValue(note_string)
  if not note_string or note_string == "---" or note_string == "" or note_string == "OFF" then 
    return nil 
  end
  
  local note_names = {
    ["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3, ["E-"] = 4, ["F-"] = 5,
    ["F#"] = 6, ["G-"] = 7, ["G#"] = 8, ["A-"] = 9, ["A#"] = 10, ["B-"] = 11
  }
  
  -- Ensure we have at least 3 characters for a valid note
  if string.len(note_string) < 3 then return nil end
  
  local note_part = string.sub(note_string, 1, 2)
  local octave_part = tonumber(string.sub(note_string, 3))
  
  if note_names[note_part] and octave_part then
    return (octave_part * 12) + note_names[note_part]
  end
  
  return nil
end

-- (Parameter command mapping function removed)

-- (Detailed device parameter detection function removed)

-- Global functions
function PakettiSliceStepGlobalSlice()
  local slice_info = PakettiSliceStepGetSliceInfo()
  if not slice_info or slice_info.slice_count == 0 then
    renoise.app():show_status("Cannot use Slice mode: Sample has no slice markers")
    return
  end
  
  print("DEBUG: PakettiSliceStepGlobalSlice - Setting all rows to SLICE mode...")
  
  -- STEP 1: Disable writing to pattern
  initializing_dialog = true
  
  -- STEP 2: Set all switches to Slice mode directly
  for row = 1, NUM_ROWS do
    if row <= slice_info.slice_count then
      print("DEBUG: Setting row " .. row .. " to SLICE mode and enabling")
      rows[row].mode = ROW_MODES.SLICE
      rows[row].enabled = true
      
      -- Update the UI switch directly - no dialog refresh needed
      if row_mode_switches[row] then
        row_mode_switches[row].value = ROW_MODES.SLICE
        print("DEBUG: Updated switch for row " .. row .. " to SLICE mode")
      end
      
      -- Disable sample offset valuebox since we're switching to slice mode
      if sample_offset_valueboxes[row] then
        sample_offset_valueboxes[row].active = false
        print("DEBUG: Disabled sample offset valuebox for row " .. row)
      end
      
      -- ENABLE slice note valuebox for slice mode
      if slice_note_valueboxes[row] then
        slice_note_valueboxes[row].active = true
        print("DEBUG: Enabled slice note valuebox for row " .. row .. " (slice mode)")
      end
      
      -- ENABLE transpose rotary for slice mode
      if transpose_rotaries[row] then
        transpose_rotaries[row].active = true
        print("DEBUG: Enabled transpose rotary for row " .. row .. " (slice mode)")
      end
      
      -- Update transpose rotary to appropriate sample value
      if transpose_rotaries[row] then
        local song = renoise.song()
        if song then
          local instrument = song.selected_instrument
          if instrument and #instrument.samples > 0 then
            local sample_index = song.selected_sample_index  -- Default to current sample
            
            if rows[row].mode == ROW_MODES.SLICE then
              -- Use the slice note that this row is actually set to play
              local slice_note = rows[row].slice_note
              if slice_note then
                sample_index = PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
              else
                -- Fallback to old behavior if slice_note is not set
                sample_index = row + 1
              end
            end
            
            -- Clamp to available samples
            if sample_index > #instrument.samples then
              sample_index = #instrument.samples
            end
            if sample_index < 1 then
              sample_index = 1
            end
            
            local target_sample = instrument.samples[sample_index]
            if target_sample then
              local transpose_value = target_sample.transpose
              -- Clamp to rotary range to prevent errors
              if transpose_value < -32 then transpose_value = -32 end
              if transpose_value > 32 then transpose_value = 32 end
              transpose_rotaries[row].value = transpose_value
            end
          end
        end
      end
    else
      -- Disable rows beyond available slices
      rows[row].enabled = false
      print("DEBUG: Row " .. row .. " disabled (beyond slice count " .. slice_info.slice_count .. ")")
    end
  end
  
  -- STEP 3: Clear sample offsets from the pattern
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  
  print("DEBUG: Clearing sample offsets from pattern...")
  for line = 1, pattern.number_of_lines do
    local pattern_line = pattern:track(track_index):line(line)
    -- Clear all effect columns to remove 0Sxx commands
    for col = 1, math.min(8, #pattern_line.effect_columns) do
      pattern_line.effect_columns[col].number_string = ""
      pattern_line.effect_columns[col].amount_string = ""
    end
  end
  
  -- STEP 4: Re-enable writing to pattern and write the slice pattern
  initializing_dialog = false
  
  -- Update button colors and write new slice pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  
  -- Update sample effect column visibility (should be hidden in slice mode)
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  local enabled_rows = math.min(NUM_ROWS, slice_info.slice_count)
  renoise.app():show_status("Global Slice: Enabled " .. enabled_rows .. " rows, cleared sample offsets, applied slice pattern")
end

function PakettiSliceStepGlobalSampleOffset()
  print("DEBUG: PakettiSliceStepGlobalSampleOffset - Setting all rows to SAMPLE_OFFSET mode...")
  
  -- Check if we're currently in slice mode (any row using slice mode)
  local dialog_in_slice_mode = false
  for row = 1, NUM_ROWS do
    if rows[row] and rows[row].enabled and rows[row].mode == ROW_MODES.SLICE then
      dialog_in_slice_mode = true
      break
    end
  end
  
  print("DEBUG: Dialog in slice mode:", dialog_in_slice_mode)
  
  -- STEP 1: Disable writing to pattern
  initializing_dialog = true
  
  -- Calculate even spread values: 8 equal slices (256/8 = 32 units apart)  
  local even_spread_values = {0, 32, 64, 96, 128, 160, 192, 224}
  
  -- STEP 2: Set all switches to Sample Offset mode directly with spread values
  for row = 1, NUM_ROWS do
    print("DEBUG: Setting row " .. row .. " to SAMPLE_OFFSET mode and enabling with offset " .. even_spread_values[row])
    rows[row].mode = ROW_MODES.SAMPLE_OFFSET
    rows[row].enabled = true
    rows[row].value = even_spread_values[row]
    
    -- Update the UI switch directly - no dialog refresh needed
    if row_mode_switches[row] then
      row_mode_switches[row].value = ROW_MODES.SAMPLE_OFFSET
      print("DEBUG: Updated switch for row " .. row .. " to SAMPLE_OFFSET mode")
    end
    
    -- Enable and update sample offset valuebox since we're switching to sample offset mode
    if sample_offset_valueboxes[row] then
      sample_offset_valueboxes[row].active = true
      sample_offset_valueboxes[row].value = even_spread_values[row]
      print("DEBUG: Enabled sample offset valuebox for row " .. row .. " with value " .. even_spread_values[row])
    end
    
    -- DISABLE slice note valuebox for sample offset mode
    if slice_note_valueboxes[row] then
      slice_note_valueboxes[row].active = false
      print("DEBUG: Disabled slice note valuebox for row " .. row .. " (sample offset mode)")
    end
    
    -- DISABLE transpose rotary for sample offset mode
    if transpose_rotaries[row] then
      transpose_rotaries[row].active = false
      print("DEBUG: Disabled transpose rotary for row " .. row .. " (sample offset mode)")
    end
  end
  
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  
  if dialog_in_slice_mode then
    -- STEP 3a: If in slice mode, convert existing slice notes to first sample notes + offsets
    -- BUT preserve the stepsequencing pattern content
    print("DEBUG: Converting slice notes to first sample notes with offsets, preserving stepsequencing...")
    
    for line = 1, pattern.number_of_lines do
      local pattern_line = pattern:track(track_index):line(line)
      -- Only modify notes that exist, don't clear empty lines
      for col = 1, math.min(8, #pattern_line.note_columns) do
        local note_col = pattern_line:note_column(col)
        if note_col.note_string ~= "---" and note_col.note_string ~= "" then
          -- Get the first sample's note (typically C-4 or the base note)
          local instrument = song.selected_instrument
          if instrument and #instrument.samples > 0 then
            local first_sample = instrument.samples[1]
            if first_sample then
              -- Set note to play the first sample (usually C-4)
              note_col.note_string = "C-4"
              print("DEBUG: Line " .. line .. " col " .. col .. " converted to first sample note C-4")
            end
          end
        end
      end
    end
  else
    -- STEP 3b: Original behavior for non-slice mode - clear pattern completely
    print("DEBUG: Clearing pattern (not in slice mode)...")
    for line = 1, pattern.number_of_lines do
      local pattern_line = pattern:track(track_index):line(line)
      -- Clear all note columns and effect columns
      for col = 1, math.min(8, #pattern_line.note_columns) do
        pattern_line:note_column(col).note_string = "---"
        pattern_line:note_column(col).instrument_value = 255
      end
      for col = 1, math.min(8, #pattern_line.effect_columns) do
        pattern_line.effect_columns[col].number_string = ""
        pattern_line.effect_columns[col].amount_string = ""
      end
    end
  end
  
  -- STEP 4: Re-enable writing to pattern and write the sample offset pattern
  initializing_dialog = false
  
  -- Update button colors and write new sample offset pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  
  -- Update sample effect column visibility (should be visible in sample offset mode)
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  if dialog_in_slice_mode then
    renoise.app():show_status("Global Sample Offset: Enabled all 8 rows, converted slice notes to first sample + spread offsets (00,20,40,60,80,A0,C0,E0), preserved stepsequencing")
  else
    renoise.app():show_status("Global Sample Offset: Enabled all 8 rows, cleared pattern, applied sample offset pattern with spread offsets (00,20,40,60,80,A0,C0,E0)")
  end
end

function PakettiSliceStepEvenSpread()
  print("DEBUG: PakettiSliceStepEvenSpread - Starting even spread function...")
  
  -- Check if sample has slices
  local slice_info = PakettiSliceStepGetSliceInfo()
  local sample_has_slices = slice_info and slice_info.slice_count > 0
  
  -- Check if dialog is currently in slice mode (any row using slice mode)
  local dialog_in_slice_mode = false
  for row = 1, NUM_ROWS do
    if rows[row] and rows[row].enabled and rows[row].mode == ROW_MODES.SLICE then
      dialog_in_slice_mode = true
      break
    end
  end
  
  print("DEBUG: Sample has slices:", sample_has_slices, "Dialog in slice mode:", dialog_in_slice_mode)
  
  -- STEP 1: Set selected sample's New Note Action to CUT for proper slice behavior
  local song = renoise.song()
  if song then
    local instrument = song.selected_instrument
    if instrument and #instrument.samples > 0 then
      local sample = instrument.samples[song.selected_sample_index]
      if sample then
        sample.new_note_action = renoise.Sample.NEW_NOTE_ACTION_NOTE_CUT
        sample.mute_group = 1
        print("DEBUG: Set sample New Note Action to CUT and Mute Group to 1 for clean slice behavior")
      end
    end
  end
  
  -- STEP 2: Disable writing to pattern
  initializing_dialog = true
  
  -- Handle the special case: sample has slices AND dialog is in slice mode
  if sample_has_slices and dialog_in_slice_mode then
    print("DEBUG: Both sample has slices AND dialog in slice mode - distributing slice notes instead of sample offsets")
    
    -- Use slice mode and distribute slice notes evenly across rows
    for row = 1, NUM_ROWS do
      print("DEBUG: Setting row " .. row .. " to SLICE mode")
      rows[row].mode = ROW_MODES.SLICE
      rows[row].enabled = true
      rows[row].active_steps = current_steps  -- Set step count to match current step mode
      
      -- Calculate slice note for this row (distribute evenly across available slices)
      local slice_note = slice_info.first_slice_key + ((row - 1) % slice_info.slice_count)
      rows[row].slice_note = slice_note
      
      -- Update the UI switch directly
      if row_mode_switches[row] then
        row_mode_switches[row].value = ROW_MODES.SLICE
        print("DEBUG: Updated switch for row " .. row .. " to SLICE mode")
      end
      
      -- DISABLE sample offset valuebox for slice mode
      if sample_offset_valueboxes[row] then
        sample_offset_valueboxes[row].active = false
        print("DEBUG: Disabled sample offset valuebox for row " .. row .. " (slice mode)")
      end
      
      -- Enable slice note valuebox
      if slice_note_valueboxes[row] then
        slice_note_valueboxes[row].active = true
        slice_note_valueboxes[row].value = slice_note
        print("DEBUG: Set slice note valuebox for row " .. row .. " to " .. slice_note)
      end
      
      -- Update step count valuebox to current_steps
      if step_valueboxes[row] then
        step_valueboxes[row].value = current_steps
        print("DEBUG: Set step count valuebox for row " .. row .. " to " .. current_steps)
      end
      
      -- Enable transpose rotary for slice mode
      if transpose_rotaries[row] then
        transpose_rotaries[row].active = true
        print("DEBUG: Enabled transpose rotary for row " .. row .. " (slice mode)")
      end
    end
    
  else
    -- Original behavior: use sample offset mode
    print("DEBUG: Using sample offset mode (sample has no slices or dialog not in slice mode)")
    -- Calculate even spread values: 8 equal slices (256/8 = 32 units apart)  
    local even_spread_values = {0, 32, 64, 96, 128, 160, 192, 224}

    -- STEP 3: Set all rows to Sample Offset mode and apply even spread values
  for row = 1, NUM_ROWS do
    print("DEBUG: Setting row " .. row .. " to SAMPLE_OFFSET mode with value " .. even_spread_values[row])
    rows[row].mode = ROW_MODES.SAMPLE_OFFSET
    rows[row].enabled = true
    rows[row].value = even_spread_values[row]
    rows[row].active_steps = current_steps  -- Set step count to match current step mode
    
    -- Update the UI switch directly
    if row_mode_switches[row] then
      row_mode_switches[row].value = ROW_MODES.SAMPLE_OFFSET
      print("DEBUG: Updated switch for row " .. row .. " to SAMPLE_OFFSET mode")
    end
    
    -- Enable and update sample offset valuebox
    if sample_offset_valueboxes[row] then
      sample_offset_valueboxes[row].active = true
      sample_offset_valueboxes[row].value = even_spread_values[row]
      print("DEBUG: Set sample offset valuebox for row " .. row .. " to " .. even_spread_values[row])
      -- Update sample editor visualization for this offset value
      PakettiSliceStepSampleOffsetUpdateSelection(even_spread_values[row])
    end
    
    -- DISABLE slice note valuebox for sample offset mode
    if slice_note_valueboxes[row] then
      slice_note_valueboxes[row].active = false
      print("DEBUG: Disabled slice note valuebox for row " .. row .. " (sample offset mode)")
    end
    
    -- Update step count valuebox to current_steps
    if step_valueboxes[row] then
      step_valueboxes[row].value = current_steps
      print("DEBUG: Set step count valuebox for row " .. row .. " to " .. current_steps)
    end
    
    
    -- DISABLE transpose rotary for sample offset mode
    if transpose_rotaries[row] then
      transpose_rotaries[row].active = false
      print("DEBUG: Disabled transpose rotary for row " .. row .. " (sample offset mode)")
    end
  end
  end -- close the else block
  
  -- STEP 3: Clear the whole track completely (common to both modes)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = pattern:track(track_index)
  
  print("DEBUG: Clearing entire track...")
  track:clear()
  
  -- STEP 4: Re-enable writing to pattern first
  initializing_dialog = false
  
  -- STEP 5: Set checkboxes at evenly spaced positions (AFTER re-enabling dialog updates)
  local step_interval = current_steps / 8  -- 16/8=2, 32/8=4
  print("DEBUG: Even Spread - current_steps=" .. current_steps .. ", step_interval=" .. step_interval .. ", MAX_STEPS=" .. MAX_STEPS)
  
  for row = 1, NUM_ROWS do
    print("DEBUG: Processing row " .. row .. ", row_checkboxes[row] exists: " .. tostring(row_checkboxes[row] ~= nil))
    if row_checkboxes[row] then
      -- Clear all checkboxes first
      for step = 1, MAX_STEPS do
        if row_checkboxes[row][step] then
          row_checkboxes[row][step].value = false
        end
      end
      -- Set checkbox at the calculated position for this row
      local target_step = ((row - 1) * step_interval) + 1
      print("DEBUG: Row " .. row .. " calculated target_step=" .. target_step)
      if target_step <= MAX_STEPS and row_checkboxes[row][target_step] then
        row_checkboxes[row][target_step].value = true
        print("DEBUG: Row " .. row .. " checkbox SET at step " .. target_step)
      else
        print("DEBUG: Row " .. row .. " FAILED to set checkbox - target_step=" .. target_step .. ", MAX_STEPS=" .. MAX_STEPS .. ", checkbox exists=" .. tostring(row_checkboxes[row][target_step] ~= nil))
      end
    end
  end
  
  -- Update button colors and write new sample offset pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  
  -- Update sample effect column visibility (should be visible for sample offset mode)
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  local step_list = ""
  for row = 1, NUM_ROWS do
    local target_step = ((row - 1) * step_interval) + 1
    if row > 1 then step_list = step_list .. ", " end
    step_list = step_list .. target_step
  end
  
  -- Show appropriate status message based on the mode that was used
  if sample_has_slices and dialog_in_slice_mode then
    renoise.app():show_status("Even Spread (" .. current_steps .. " steps): Slice notes distributed across slices - Checkboxes at steps: " .. step_list)
  else
    renoise.app():show_status("Even Spread (" .. current_steps .. " steps): Sample offsets 00,20,40,60,80,A0,C0,E0 - Checkboxes at steps: " .. step_list)
  end
end

function PakettiSliceStepEvenOffsets()
  print("DEBUG: PakettiSliceStepEvenOffsets - Setting even spread sample offset values without stepsequencers...")
  
  -- STEP 1: Set selected sample's New Note Action to CUT for proper slice behavior
  local song = renoise.song()
  if song then
    local instrument = song.selected_instrument
    if instrument and #instrument.samples > 0 then
      local sample = instrument.samples[song.selected_sample_index]
      if sample then
        sample.new_note_action = renoise.Sample.NEW_NOTE_ACTION_NOTE_CUT
        sample.mute_group = 1
        print("DEBUG: Set sample New Note Action to CUT and Mute Group to 1 for clean slice behavior")
      end
    end
  end
  
  -- STEP 2: Disable writing to pattern
  initializing_dialog = true
  
  -- Calculate even spread values: 8 equal slices (256/8 = 32 units apart)  
  local even_spread_values = {0, 32, 64, 96, 128, 160, 192, 224}
  
  -- STEP 3: Set all rows to Sample Offset mode and apply even spread values (NO STEPSEQUENCER CHANGES)
  for row = 1, NUM_ROWS do
    print("DEBUG: Setting row " .. row .. " to SAMPLE_OFFSET mode with value " .. even_spread_values[row])
    rows[row].mode = ROW_MODES.SAMPLE_OFFSET
    rows[row].enabled = true
    rows[row].value = even_spread_values[row]
    
    -- Update the UI switch directly
    if row_mode_switches[row] then
      row_mode_switches[row].value = ROW_MODES.SAMPLE_OFFSET
      print("DEBUG: Updated switch for row " .. row .. " to SAMPLE_OFFSET mode")
    end
    
    -- Enable and update sample offset valuebox
    if sample_offset_valueboxes[row] then
      sample_offset_valueboxes[row].active = true
      sample_offset_valueboxes[row].value = even_spread_values[row]
      print("DEBUG: Set sample offset valuebox for row " .. row .. " to " .. even_spread_values[row])
      -- Update sample editor visualization for this offset value
      PakettiSliceStepSampleOffsetUpdateSelection(even_spread_values[row])
    end
    
    -- DISABLE slice note valuebox for sample offset mode
    if slice_note_valueboxes[row] then
      slice_note_valueboxes[row].active = false
      print("DEBUG: Disabled slice note valuebox for row " .. row .. " (sample offset mode)")
    end
    
    -- DISABLE transpose rotary for sample offset mode
    if transpose_rotaries[row] then
      transpose_rotaries[row].active = false
      print("DEBUG: Disabled transpose rotary for row " .. row .. " (sample offset mode)")
    end
  end
  
  -- STEP 4: Re-enable writing to pattern
  initializing_dialog = false
  
  -- Update button colors (but don't write to pattern automatically)
  PakettiSliceStepUpdateButtonColors()
  
  -- Update sample effect column visibility (should be visible for sample offset mode)
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  renoise.app():show_status("Even Offsets: Sample offsets 00,20,40,60,80,A0,C0,E0 set - Checkboxes unchanged")
end

-- Randomize all rows at once (optimized)
function PakettiSliceStepRandomizeAllRows()
  -- STEP 1: Disable pattern writing for batch operation
  initializing_dialog = true
  
  -- STEP 2: Use proper random seeding from main.lua
  trueRandomSeed()
  
  local total_filled = 0
  
  -- STEP 3: Randomize all rows in memory (fast)
  for row = 1, NUM_ROWS do
    if row_checkboxes[row] and rows[row] then
      local row_steps = rows[row].active_steps
      
      -- Clear all checkboxes first for this row
      for step = 1, MAX_STEPS do
        if row_checkboxes[row][step] then
          row_checkboxes[row][step].value = false
        end
      end
      
      -- Randomly fill steps (50% chance per step within active range)
      for step = 1, row_steps do
        if step <= MAX_STEPS and row_checkboxes[row][step] then
          if math.random() < 0.5 then
            row_checkboxes[row][step].value = true
            total_filled = total_filled + 1
          end
        end
      end
    end
  end
  
  -- STEP 4: Re-enable pattern writing
  initializing_dialog = false
  
  -- STEP 5: Write all rows to pattern in one batch operation (fast!)
  PakettiSliceStepWriteToPattern()
  
  -- STEP 6: Update UI once at the end
  PakettiSliceStepUpdateButtonColors()
  
  renoise.app():show_status("Randomized all rows: " .. total_filled .. " total steps filled across 8 rows")
end

-- Helper function to check if current instrument is pakettified
function PakettiSliceStepIsInstrumentPakettified()
  local song = renoise.song()
  if not song then return false end
  local instrument = song.selected_instrument
  if not instrument then return false end
  return string.find(instrument.name, " %(Pakettified%)") ~= nil
end


function PakettiSliceStepTwoOctaves()
  print("DEBUG: PakettiSliceStepTwoOctaves - Creating two octave melodic pattern across 8 rows...")
  
  -- STEP 1: Handle non-pakettified instruments properly
  print("DEBUG: Checking if instrument is pakettified...")
  local is_pakettified = PakettiSliceStepIsInstrumentPakettified()
  print("DEBUG: Instrument pakettified: " .. tostring(is_pakettified))
  
  if not is_pakettified then
    print("DEBUG: Instrument NOT pakettified, checking slice compatibility...")
    local slice_info = PakettiSliceStepGetSliceInfo()
    if slice_info and slice_info.slice_count > 0 then
      -- Check if slice notes are within ValueBox range (36-58)
      local min_note = slice_info.min_note or slice_info.first_slice_key
      local max_note = slice_info.max_note or (min_note + 24)  -- Use detected range or calculate
      print("DEBUG: Slice range: " .. min_note .. "-" .. max_note .. " (required: 36-58)")
      print("DEBUG: min_note < 36: " .. tostring(min_note < 36))
      print("DEBUG: max_note > 58: " .. tostring(max_note > 58))
      local needs_pakettification = (min_note < 36 or max_note > 58)
      print("DEBUG: Needs pakettification: " .. tostring(needs_pakettification))
      
      if needs_pakettification then
        print("DEBUG: Slices outside ValueBox range (" .. min_note .. "-" .. max_note .. "), auto-pakettifying...")
        
        -- STEP 1A: HALT dialog->pattern writing
        local was_initializing = initializing_dialog
        initializing_dialog = true
        print("DEBUG: Dialog-to-pattern writing HALTED for pakettification")
        
        -- STEP 1B: Store current slice setup (which slice numbers are selected)
        local stored_slice_setup = {}
        for row = 1, NUM_ROWS do
          if rows[row].mode == ROW_MODES.SLICE and rows[row].enabled then
            -- Find which slice number this corresponds to
            local slice_note = rows[row].slice_note
            local slice_number = slice_note - slice_info.first_slice_key + 2  -- +2 because first_slice_key is slice #2
            stored_slice_setup[row] = {
              slice_number = slice_number,
              enabled = rows[row].enabled,
              steps = {}
            }
            -- Store which steps are active for this row
            for step = 1, 32 do
              stored_slice_setup[row].steps[step] = row_checkboxes[row] and row_checkboxes[row][step] and row_checkboxes[row][step].value or false
            end
            print("DEBUG: Stored row " .. row .. " slice #" .. slice_number .. " (note " .. slice_note .. ")")
          end
        end
        
        -- STEP 1C: Pakettify instrument
        renoise.app():show_status("Auto-pakettifying instrument for slice step sequencer compatibility...")
        local old_instrument_index = renoise.song().selected_instrument_index
        PakettiInjectDefaultXRNI()
        local new_instrument_index = renoise.song().selected_instrument_index
        print("DEBUG: Pakettify complete. Instrument changed from " .. old_instrument_index .. " to " .. new_instrument_index)
        
        -- STEP 1D: Clear cached slice info to force re-detection
        cached_slice_info = nil
        cached_instrument_index = nil
        print("DEBUG: Cleared cached slice info for re-detection")
        
        -- STEP 1E: Re-detect slice mappings with new instrument
        local new_slice_info = PakettiSliceStepGetSliceInfo()
        if new_slice_info and new_slice_info.slice_count > 0 then
          print("DEBUG: Re-detected slices - first slice key now: " .. new_slice_info.first_slice_key)
          
          -- STEP 1F: Re-map stored slice selections to new note mappings AND update UI immediately
          for row = 1, NUM_ROWS do
            if stored_slice_setup[row] then
              local slice_number = stored_slice_setup[row].slice_number
              local new_slice_note = new_slice_info.first_slice_key + (slice_number - 2)  -- -2 because first_slice_key is slice #2
              
              -- Restore row settings with new note mapping
              rows[row].mode = ROW_MODES.SLICE  
              rows[row].slice_note = new_slice_note
              rows[row].enabled = stored_slice_setup[row].enabled
              
              print("DEBUG: Remapped row " .. row .. " slice #" .. slice_number .. " from old setup to new note " .. new_slice_note .. " (" .. PakettiSliceStepNoteValueToString(new_slice_note) .. ")")
              
              -- IMMEDIATELY update UI elements with the NEW note value
              -- Update UI switch
              if row_mode_switches[row] then
                row_mode_switches[row].value = ROW_MODES.SLICE
                print("DEBUG: Updated switch for row " .. row .. " to SLICE mode")
              end
              
              -- Update slice note valuebox - CRITICAL: Use new_slice_note directly!
              if slice_note_valueboxes[row] then
                slice_note_valueboxes[row].value = new_slice_note
                print("DEBUG: Updated valuebox for row " .. row .. " to new note " .. new_slice_note .. " (" .. PakettiSliceStepNoteValueToString(new_slice_note) .. ")")
              end
              
              -- Update slice note label
              if slice_note_labels[row] then
                slice_note_labels[row].text = PakettiSliceStepNoteValueToString(new_slice_note)
                print("DEBUG: Updated label for row " .. row .. " to " .. PakettiSliceStepNoteValueToString(new_slice_note))
              end
              
              -- Restore checkbox states
              for step = 1, 32 do
                if row_checkboxes[row] and row_checkboxes[row][step] then
                  row_checkboxes[row][step].value = stored_slice_setup[row].steps[step]
                end
              end
              
              print("DEBUG: Completed UI update for row " .. row .. " with slice #" .. slice_number .. " at new note " .. new_slice_note)
            end
          end
          
          print("DEBUG: Slice setup restoration complete")
        end
        
        -- STEP 1H: Resume dialog-to-pattern writing
        initializing_dialog = was_initializing
        print("DEBUG: Dialog-to-pattern writing RESUMED after pakettification")
      else
        print("DEBUG: Slices are within compatible range, no pakettification needed")
      end
    else
      print("DEBUG: No slices found or slice_count = 0, no pakettification needed")
    end
  else
    print("DEBUG: Instrument already pakettified, no pakettification needed")
  end
  
  if not is_pakettified then
    -- For newly pakettified instruments: Apply transpose pattern to dialog
    print("DEBUG: Applying Two Octaves transpose pattern to dialog after pakettification")
    
    -- Disable writing to pattern while we update the dialog
    initializing_dialog = true
    
    -- Get slice info (fresh after pakettification)
    local slice_info = PakettiSliceStepGetSliceInfo()
    local base_note = 48  -- C-4 default
    
    if slice_info and slice_info.slice_count > 0 then
      base_note = slice_info.first_slice_key
    end
    
    -- Two octaves pattern: 0 +12 +24 +12 0 -12 -24 -12 (8 steps for 8 rows)
    local transpose_pattern = {0, 12, 24, 12, 0, -12, -24, -12}
    
    -- Set all rows based on transpose pattern
    for row = 1, NUM_ROWS do
      if slice_info and slice_info.slice_count > 0 then
        -- SLICE MODE: Set slice notes based on transpose pattern
        rows[row].mode = ROW_MODES.SLICE
        rows[row].slice_note = base_note + transpose_pattern[row]
        rows[row].enabled = true
        
        -- Update UI
        if row_mode_switches[row] then
          row_mode_switches[row].value = ROW_MODES.SLICE
        end
        if slice_note_valueboxes[row] then
          slice_note_valueboxes[row].value = rows[row].slice_note
        end
        if slice_note_labels[row] then
          slice_note_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].slice_note)
        end
      else
        -- SAMPLE OFFSET MODE: Set note values based on transpose pattern
        rows[row].mode = ROW_MODES.SAMPLE_OFFSET
        rows[row].note_value = base_note + transpose_pattern[row]
        rows[row].value = 0
        rows[row].enabled = true
        
        -- Update UI
        if row_mode_switches[row] then
          row_mode_switches[row].value = ROW_MODES.SAMPLE_OFFSET
        end
        if note_text_labels[row] then
          note_text_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].note_value)
        end
      end
      
      -- Set step count to current_steps
      rows[row].active_steps = current_steps
      if step_valueboxes[row] then
        step_valueboxes[row].value = current_steps
      end
    end
    
    -- Set checkboxes at first step for all rows
    for row = 1, NUM_ROWS do
      if row_checkboxes[row] then
        -- Clear all checkboxes first
        for step = 1, MAX_STEPS do
          if row_checkboxes[row][step] then
            row_checkboxes[row][step].value = false
          end
        end
        -- Set checkbox at step 1
        if row_checkboxes[row][1] then
          row_checkboxes[row][1].value = true
        end
      end
    end
    
    -- Re-enable pattern writing
    initializing_dialog = false
  else
    print("DEBUG: Pakettified instrument - using current dialog state without modification")
  end
  
  -- Clear the track and write pattern
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = pattern:track(track_index)
  track:clear()
  
  -- Update UI and write pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  -- ALWAYS apply pitch stepper function
  print("DEBUG: Applying Two Octaves pitch stepper")
  PakettiFillPitchStepperTwoOctaves()
  
  local mode_name = slice_info and slice_info.slice_count > 0 and "Slice" or "Sample Offset"
  renoise.app():show_status("Two Octaves pattern applied in " .. mode_name .. " mode + Pitch Stepper applied")
end

function PakettiSliceStepOctaveUpDown()
  print("DEBUG: PakettiSliceStepOctaveUpDown - Creating octave up/down pattern across 8 rows...")
  
  -- STEP 1: Check if instrument is already pakettified
  local is_pakettified = PakettiSliceStepIsInstrumentPakettified()
  print("DEBUG: Instrument pakettified: " .. tostring(is_pakettified))
  
  -- STEP 2: Handle non-pakettified instruments properly
  if not is_pakettified then
    local slice_info = PakettiSliceStepGetSliceInfo()
    if slice_info and slice_info.slice_count > 0 then
      -- Check if slice notes are within ValueBox range (36-58)
      local min_note = slice_info.first_slice_key
      local max_note = min_note + 12  -- One octave range
      if min_note < 36 or max_note > 58 then
        print("DEBUG: Slices outside ValueBox range (" .. min_note .. "-" .. max_note .. "), auto-pakettifying...")
        
        -- STEP 1A: HALT dialog->pattern writing
        local was_initializing = initializing_dialog
        initializing_dialog = true
        print("DEBUG: Dialog-to-pattern writing HALTED for pakettification")
        
        -- STEP 1B: Store current slice setup (which slice numbers are selected)
        local stored_slice_setup = {}
        for row = 1, NUM_ROWS do
          if rows[row].mode == ROW_MODES.SLICE and rows[row].enabled then
            -- Find which slice number this corresponds to
            local slice_note = rows[row].slice_note
            local slice_number = slice_note - slice_info.first_slice_key + 2  -- +2 because first_slice_key is slice #2
            stored_slice_setup[row] = {
              slice_number = slice_number,
              enabled = rows[row].enabled,
              steps = {}
            }
            -- Store which steps are active for this row
            for step = 1, 32 do
              stored_slice_setup[row].steps[step] = row_checkboxes[row] and row_checkboxes[row][step] and row_checkboxes[row][step].value or false
            end
            print("DEBUG: Stored row " .. row .. " slice #" .. slice_number .. " (note " .. slice_note .. ")")
          end
        end
        
        -- STEP 1C: Pakettify instrument
        renoise.app():show_status("Auto-pakettifying instrument for slice step sequencer compatibility...")
        local old_instrument_index = renoise.song().selected_instrument_index
        PakettiInjectDefaultXRNI()
        local new_instrument_index = renoise.song().selected_instrument_index
        print("DEBUG: Pakettify complete. Instrument changed from " .. old_instrument_index .. " to " .. new_instrument_index)
        
        -- STEP 1D: Clear cached slice info to force re-detection
        cached_slice_info = nil
        cached_instrument_index = nil
        print("DEBUG: Cleared cached slice info for re-detection")
        
        -- STEP 1E: Re-detect slice mappings with new instrument
        local new_slice_info = PakettiSliceStepGetSliceInfo()
        if new_slice_info and new_slice_info.slice_count > 0 then
          print("DEBUG: Re-detected slices - first slice key now: " .. new_slice_info.first_slice_key)
          
          -- STEP 1F: Re-map stored slice selections to new note mappings AND update UI immediately
          for row = 1, NUM_ROWS do
            if stored_slice_setup[row] then
              local slice_number = stored_slice_setup[row].slice_number
              local new_slice_note = new_slice_info.first_slice_key + (slice_number - 2)  -- -2 because first_slice_key is slice #2
              
              -- Restore row settings with new note mapping
              rows[row].mode = ROW_MODES.SLICE  
              rows[row].slice_note = new_slice_note
              rows[row].enabled = stored_slice_setup[row].enabled
              
              print("DEBUG: Remapped row " .. row .. " slice #" .. slice_number .. " from old setup to new note " .. new_slice_note .. " (" .. PakettiSliceStepNoteValueToString(new_slice_note) .. ")")
              
              -- IMMEDIATELY update UI elements with the NEW note value
              -- Update UI switch
              if row_mode_switches[row] then
                row_mode_switches[row].value = ROW_MODES.SLICE
                print("DEBUG: Updated switch for row " .. row .. " to SLICE mode")
              end
              
              -- Update slice note valuebox - CRITICAL: Use new_slice_note directly!
              if slice_note_valueboxes[row] then
                slice_note_valueboxes[row].value = new_slice_note
                print("DEBUG: Updated valuebox for row " .. row .. " to new note " .. new_slice_note .. " (" .. PakettiSliceStepNoteValueToString(new_slice_note) .. ")")
              end
              
              -- Update slice note label
              if slice_note_labels[row] then
                slice_note_labels[row].text = PakettiSliceStepNoteValueToString(new_slice_note)
                print("DEBUG: Updated label for row " .. row .. " to " .. PakettiSliceStepNoteValueToString(new_slice_note))
              end
              
              -- Restore checkbox states
              for step = 1, 32 do
                if row_checkboxes[row] and row_checkboxes[row][step] then
                  row_checkboxes[row][step].value = stored_slice_setup[row].steps[step]
                end
              end
              
              print("DEBUG: Completed UI update for row " .. row .. " with slice #" .. slice_number .. " at new note " .. new_slice_note)
            end
          end
          
          print("DEBUG: Slice setup restoration complete")
        end
        
        -- STEP 1H: Resume dialog-to-pattern writing
        initializing_dialog = was_initializing
        print("DEBUG: Dialog-to-pattern writing RESUMED after pakettification")
      else
        print("DEBUG: Slices are within compatible range, no pakettification needed")
      end
    else
      print("DEBUG: No slices found or slice_count = 0, no pakettification needed")
    end
  else
    print("DEBUG: Instrument already pakettified, no pakettification needed")
  end
  
  if not is_pakettified then
    -- For newly pakettified instruments: Apply transpose pattern to dialog
    print("DEBUG: Applying Octave Up/Down transpose pattern to dialog after pakettification")
    
    -- Disable writing to pattern while we update the dialog
    initializing_dialog = true
    
    -- Get slice info (fresh after pakettification)
    local slice_info = PakettiSliceStepGetSliceInfo()
    local base_note = 48  -- C-4 default
    
    if slice_info and slice_info.slice_count > 0 then
      base_note = slice_info.first_slice_key
    end
    
    -- Octave up/down pattern: 0 +12 0 -12 0 +12 0 -12 (repeating across 8 rows)
    local transpose_pattern = {0, 12, 0, -12, 0, 12, 0, -12}
    
    -- Set all rows based on transpose pattern
    for row = 1, NUM_ROWS do
      if slice_info and slice_info.slice_count > 0 then
        -- SLICE MODE: Set slice notes based on transpose pattern
        rows[row].mode = ROW_MODES.SLICE
        rows[row].slice_note = base_note + transpose_pattern[row]
        rows[row].enabled = true
        
        -- Update UI
        if row_mode_switches[row] then
          row_mode_switches[row].value = ROW_MODES.SLICE
        end
        if slice_note_valueboxes[row] then
          slice_note_valueboxes[row].value = rows[row].slice_note
        end
        if slice_note_labels[row] then
          slice_note_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].slice_note)
        end
      else
        -- SAMPLE OFFSET MODE: Set note values based on transpose pattern
        rows[row].mode = ROW_MODES.SAMPLE_OFFSET
        rows[row].note_value = base_note + transpose_pattern[row]
        rows[row].value = 0
        rows[row].enabled = true
        
        -- Update UI
        if row_mode_switches[row] then
          row_mode_switches[row].value = ROW_MODES.SAMPLE_OFFSET
        end
        if note_text_labels[row] then
          note_text_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].note_value)
        end
      end
      
      -- Set step count to current_steps
      rows[row].active_steps = current_steps
      if step_valueboxes[row] then
        step_valueboxes[row].value = current_steps
      end
    end
    
    -- Set checkboxes at first step for all rows
    for row = 1, NUM_ROWS do
      if row_checkboxes[row] then
        -- Clear all checkboxes first
        for step = 1, MAX_STEPS do
          if row_checkboxes[row][step] then
            row_checkboxes[row][step].value = false
          end
        end
        -- Set checkbox at step 1
        if row_checkboxes[row][1] then
          row_checkboxes[row][1].value = true
        end
      end
    end
    
    -- Re-enable pattern writing
    initializing_dialog = false
  else
    print("DEBUG: Pakettified instrument - using current dialog state without modification")
  end
  
  -- Clear the track and write pattern
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = pattern:track(track_index)
  track:clear()
  
  -- Update UI and write pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  -- ALWAYS apply pitch stepper function
  print("DEBUG: Applying Octave Up/Down pitch stepper")
  PakettiFillPitchStepper()
  
  local mode_name = slice_info and slice_info.slice_count > 0 and "Slice" or "Sample Offset"
  renoise.app():show_status("Octave Up/Down pattern applied in " .. mode_name .. " mode + Pitch Stepper applied")
end

-- (Global Parameter function removed - parameter functionality removed)

-- Row management
function PakettiSliceStepSetRowSteps(row, steps)
  rows[row].active_steps = steps
  PakettiSliceStepUpdateButtonColors()
  -- Only update this specific row, not entire pattern
  PakettiSliceStepWriteRowToPattern(row)
end

-- Clear individual row (like PakettiGater)
function PakettiSliceStepClearRow(row)
  if row_checkboxes[row] then
    for step = 1, MAX_STEPS do
      if row_checkboxes[row][step] then
        row_checkboxes[row][step].value = false
      end
    end
    -- Only update this specific row, not entire pattern
    PakettiSliceStepWriteRowToPattern(row)
    renoise.app():show_status("Row " .. row .. " cleared")
  end
end

-- Fill row with every N pattern
function PakettiSliceStepFillRowEveryN(row, interval)
  if not row_checkboxes[row] or not rows[row] then return end
  
  local row_steps = rows[row].active_steps
  
  -- Clear all checkboxes first
  for step = 1, MAX_STEPS do
    if row_checkboxes[row][step] then
      row_checkboxes[row][step].value = false
    end
  end
  
  -- Fill every N steps (starting from step 1, so 1,1+N,1+2N...)
  for step = 1, row_steps, interval do
    if step <= MAX_STEPS and row_checkboxes[row][step] then
      row_checkboxes[row][step].value = true
    end
  end
  
  -- Update button colors and write pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteRowToPattern(row)
  
  renoise.app():show_status("Row " .. row .. ": Filled every " .. interval .. " steps (" .. row_steps .. " total steps)")
end

-- Helper function to check if current row pattern matches the desired edit step pattern
function PakettiSliceStepWouldEditStepPatternBeDifferent(row, edit_step)
  if not row_checkboxes[row] or not rows[row] then return true end
  
  local row_steps = rows[row].active_steps
  
  -- First check: are there any active checkboxes beyond row_steps?
  for step = row_steps + 1, MAX_STEPS do
    if row_checkboxes[row][step] and row_checkboxes[row][step].value then
      return true -- Found a checkbox beyond active steps, pattern would be different
    end
  end
  
  -- Check if current pattern matches what edit step pattern would create
  for step = 1, row_steps do
    local should_be_active = (step % edit_step == 1) -- Edit step pattern: 1, 1+edit_step, 1+2*edit_step...
    local is_currently_active = row_checkboxes[row][step] and row_checkboxes[row][step].value
    
    if should_be_active ~= is_currently_active then
      return true -- Pattern would be different
    end
  end
  
  return false -- Pattern would be identical
end

-- Fill row with edit step pattern
function PakettiSliceStepFillRowEveryEditStep(row)
  if not row_checkboxes[row] or not rows[row] then return end
  
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song available")
    return
  end
  
  local edit_step = song.transport.edit_step
  -- If edit_step is 0, use interval of 1 (fill every step)
  if edit_step == 0 then
    edit_step = 1
  end
  
  -- Check if the pattern would actually be different
  if not PakettiSliceStepWouldEditStepPatternBeDifferent(row, edit_step) then
    renoise.app():show_status("Row " .. row .. ": Already has edit step pattern (EditStep=" .. edit_step .. "), no changes needed")
    return
  end
  
  local row_steps = rows[row].active_steps
  
  -- Clear all checkboxes first
  for step = 1, MAX_STEPS do
    if row_checkboxes[row][step] then
      row_checkboxes[row][step].value = false
    end
  end
  
  -- Fill every edit_step steps (starting from step 1, so 1,1+edit_step,1+2*edit_step...)
  for step = 1, row_steps, edit_step do
    if step <= MAX_STEPS and row_checkboxes[row][step] then
      row_checkboxes[row][step].value = true
    end
  end
  
  -- Update button colors and write pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteRowToPattern(row)
  
  renoise.app():show_status("Row " .. row .. ": Filled every " .. edit_step .. " steps (EditStep=" .. edit_step .. ", " .. row_steps .. " total steps)")
end

-- Fill row randomly
function PakettiSliceStepFillRowRandomly(row)
  if not row_checkboxes[row] or not rows[row] then return end
  
  local row_steps = rows[row].active_steps
  
  -- Use proper random seeding from main.lua
  trueRandomSeed()
  
  -- Clear all checkboxes first
  for step = 1, MAX_STEPS do
    if row_checkboxes[row][step] then
      row_checkboxes[row][step].value = false
    end
  end
  
  -- Randomly fill steps (50% chance per step within active range)
  local filled_count = 0
  for step = 1, row_steps do
    if step <= MAX_STEPS and row_checkboxes[row][step] then
      if math.random() < 0.5 then
        row_checkboxes[row][step].value = true
        filled_count = filled_count + 1
      end
    end
  end
  
  -- Update button colors and write pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteRowToPattern(row)
  
  renoise.app():show_status("Row " .. row .. ": Randomly filled " .. filled_count .. " of " .. row_steps .. " steps")
end

-- Shift individual row left/right (like PakettiGater)
function PakettiSliceStepShiftRow(row, direction)
  if not row_checkboxes[row] then return end
  
  local shifted = {}
  if direction == "left" then
    for step = 1, MAX_STEPS do
      local source_step = (step % MAX_STEPS) + 1
      shifted[step] = row_checkboxes[row][source_step].value
    end
  elseif direction == "right" then
    for step = 1, MAX_STEPS do
      local source_step = ((step - 2) % MAX_STEPS) + 1
      shifted[step] = row_checkboxes[row][source_step].value
    end
  end
  
  for step = 1, MAX_STEPS do
    if row_checkboxes[row][step] then
      row_checkboxes[row][step].value = shifted[step]
    end
  end
  
  -- Only update this specific row, not entire pattern
  PakettiSliceStepWriteRowToPattern(row)
  renoise.app():show_status("Row " .. row .. " shifted " .. direction)
end

function PakettiSliceStepSetRowMode(row, mode)
  print("DEBUG: PakettiSliceStepSetRowMode - Setting row " .. row .. " to mode " .. mode)
  
  -- Validate mode - prevent switching to SLICE mode if no slices are available
  if mode == ROW_MODES.SLICE then
    local slice_info = PakettiSliceStepGetSliceInfo()
    if not slice_info or slice_info.slice_count == 0 then
      print("DEBUG: Cannot set row " .. row .. " to SLICE mode - no slices available")
      renoise.app():show_status("Cannot use Slice mode: Sample has no slice markers")
      return -- Exit without changing mode
    end
  end
  
  rows[row].mode = mode
  -- Mode-specific setup could go here
  PakettiSliceStepUpdateButtonColors()
  -- Only update this specific row, not entire pattern
  PakettiSliceStepWriteRowToPattern(row)
  -- Update switch if it exists
  if row_mode_switches[row] then
    row_mode_switches[row].value = mode
    print("DEBUG: Updated switch value for row " .. row .. " to " .. mode)
  end
  
  -- Update sample effect column visibility based on new mode
  PakettiSliceStepUpdateSampleEffectColumnVisibility()
  
  -- Enable/disable sample offset valuebox based on mode
  if sample_offset_valueboxes[row] then
    sample_offset_valueboxes[row].active = (mode == ROW_MODES.SAMPLE_OFFSET)
    print("DEBUG: Sample offset valuebox for row " .. row .. " " .. (mode == ROW_MODES.SAMPLE_OFFSET and "enabled" or "disabled"))
  end
  
  -- Enable/disable slice note valuebox based on mode
  if slice_note_valueboxes[row] then
    slice_note_valueboxes[row].active = (mode == ROW_MODES.SLICE)
    print("DEBUG: Slice note valuebox for row " .. row .. " " .. (mode == ROW_MODES.SLICE and "enabled" or "disabled"))
  end
  
  -- Enable/disable transpose rotary based on mode
  if transpose_rotaries[row] then
    transpose_rotaries[row].active = (mode == ROW_MODES.SLICE)
    print("DEBUG: Transpose rotary for row " .. row .. " " .. (mode == ROW_MODES.SLICE and "enabled" or "disabled"))
  end
  
  -- Update transpose rotary to appropriate sample value
  if transpose_rotaries[row] then
    local song = renoise.song()
    if song then
      local instrument = song.selected_instrument
      if instrument and #instrument.samples > 0 then
        local sample_index = song.selected_sample_index  -- Default to current sample
        
        if mode == ROW_MODES.SLICE then
          -- Use the slice note that this row is actually set to play
          local slice_note = rows[row].slice_note
          if slice_note then
            sample_index = PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
          else
            -- Fallback to old behavior if slice_note is not set
            sample_index = row + 1
          end
        end
        
        -- Clamp to available samples
        if sample_index > #instrument.samples then
          sample_index = #instrument.samples
        end
        if sample_index < 1 then
          sample_index = 1
        end
        
        local target_sample = instrument.samples[sample_index]
        if target_sample then
          local transpose_value = target_sample.transpose
          -- Clamp to rotary range to prevent errors
          if transpose_value < -32 then transpose_value = -32 end
          if transpose_value > 32 then transpose_value = 32 end
          transpose_rotaries[row].value = transpose_value
        end
      end
    end
  end
end

-- Refresh dialog when device/parameter changes
function PakettiSliceStepRefreshDialog()
  if dialog and dialog.visible then
    -- Store current checkbox states AND complete row data before refresh
    local checkbox_states = {}
    local saved_rows = {}
    for row = 1, NUM_ROWS do
      checkbox_states[row] = {}
      if row_checkboxes[row] then
        for step = 1, MAX_STEPS do
          if row_checkboxes[row][step] then
            checkbox_states[row][step] = row_checkboxes[row][step].value
          end
        end
      end
      -- Save complete row data including note values, sample offsets, modes, etc.
      if rows[row] then
        saved_rows[row] = {
          mode = rows[row].mode,
          value = rows[row].value,
          note_value = rows[row].note_value,
          active_steps = rows[row].active_steps,
          enabled = rows[row].enabled,
          slice_note = rows[row].slice_note,
          soloed = rows[row].soloed
        }
      end
    end
    
    dialog:close()
    PakettiSliceStepCreateDialog()
    
    -- Restore checkbox states AND complete row data after refresh
    for row = 1, NUM_ROWS do
      if row_checkboxes[row] and checkbox_states[row] then
        for step = 1, MAX_STEPS do
          if row_checkboxes[row][step] and checkbox_states[row][step] ~= nil then
            row_checkboxes[row][step].value = checkbox_states[row][step]
          end
        end
      end
      -- Restore complete row data
      if saved_rows[row] and rows[row] then
        rows[row].mode = saved_rows[row].mode
        rows[row].value = saved_rows[row].value
        rows[row].note_value = saved_rows[row].note_value
        -- Only restore active_steps if not in the middle of step switching
        if not step_switching_in_progress then
          rows[row].active_steps = saved_rows[row].active_steps
        end
        rows[row].enabled = saved_rows[row].enabled
        rows[row].slice_note = saved_rows[row].slice_note
        rows[row].soloed = saved_rows[row].soloed or false
        -- Update the mode switch to reflect the restored mode
        if row_mode_switches[row] then
          row_mode_switches[row].value = saved_rows[row].mode
        end
        -- Update step valuebox - use current value if step switching, saved value otherwise
        if step_valueboxes[row] then
          if step_switching_in_progress then
            step_valueboxes[row].value = rows[row].active_steps  -- Use current (pattern-read) value
          else
            step_valueboxes[row].value = saved_rows[row].active_steps  -- Use saved value
          end
        end
        -- Update step count label to saved value
        -- Update note text labels and sample offset valuebox
        if saved_rows[row].mode == ROW_MODES.SAMPLE_OFFSET and note_text_labels[row] then
          note_text_labels[row].text = PakettiSliceStepNoteValueToString(saved_rows[row].note_value)
        end
        -- Always update sample offset valuebox value and active state
        if sample_offset_valueboxes[row] then
          sample_offset_valueboxes[row].value = saved_rows[row].value
          sample_offset_valueboxes[row].active = (saved_rows[row].mode == ROW_MODES.SAMPLE_OFFSET)
        end
        -- Update slice note valuebox active state
        if slice_note_valueboxes[row] then
          slice_note_valueboxes[row].active = (saved_rows[row].mode == ROW_MODES.SLICE)
        end
        -- Update transpose rotary to appropriate sample value and active state
        if transpose_rotaries[row] then
          -- Set active state based on mode
          transpose_rotaries[row].active = (saved_rows[row].mode == ROW_MODES.SLICE)
          
          local song = renoise.song()
          if song then
            local instrument = song.selected_instrument
            if instrument and #instrument.samples > 0 then
              local sample_index = song.selected_sample_index  -- Default to current sample
              
              if saved_rows[row].mode == ROW_MODES.SLICE then
                -- Use the slice note that this row is actually set to play
                local slice_note = saved_rows[row].slice_note
                if slice_note then
                  sample_index = PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
                else
                  -- Fallback to old behavior if slice_note is not set
                  sample_index = row + 1
                end
              end
              
              -- Clamp to available samples
              if sample_index > #instrument.samples then
                sample_index = #instrument.samples
              end
              if sample_index < 1 then
                sample_index = 1
              end
              
              local target_sample = instrument.samples[sample_index]
              if target_sample then
                local transpose_value = target_sample.transpose
                -- Clamp to rotary range to prevent errors
                if transpose_value < -32 then transpose_value = -32 end
                if transpose_value > 32 then transpose_value = 32 end
                transpose_rotaries[row].value = transpose_value
              end
            end
          end
        end
        -- Update slice valuebox and label if in slice mode
        if saved_rows[row].mode == ROW_MODES.SLICE then
          if slice_note_valueboxes[row] then
            slice_note_valueboxes[row].value = saved_rows[row].slice_note
          end
          if slice_note_labels[row] then
            slice_note_labels[row].text = PakettiSliceStepNoteValueToString(saved_rows[row].slice_note)
          end
        end
      end
    end
  end
end

-- Random Gate functionality - ensures only one row plays per step
function PakettiSliceStepRandomGate()
  -- Don't proceed if dialog is initializing
  if initializing_dialog then return end
  
  -- Check if any rows are in slice mode and if we have slices available
  local has_slice_rows = false
  for row = 1, NUM_ROWS do
    if rows[row].enabled and rows[row].mode == ROW_MODES.SLICE then
      has_slice_rows = true
      break
    end
  end
  
  if has_slice_rows then
    local slice_info = PakettiSliceStepGetSliceInfo()
    if not slice_info then
      renoise.app():show_status("Cannot Random Gate because instrument has no slices, doing nothing.")
      return
    end
  end
  
  trueRandomSeed()
  
  -- STEP 1: Disable "print to pattern"
  initializing_dialog = true
  
  -- STEP 2: Clear the selected track completely
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = pattern:track(track_index)
  track:clear()
  
  -- STEP 3: Turn all checkboxes OFF in one go (prepare batch changes)
  local checkbox_states = {}
  for row = 1, NUM_ROWS do
    checkbox_states[row] = {}
    for step = 1, MAX_STEPS do
      checkbox_states[row][step] = false -- Start with everything off
    end
  end
  
  -- Get list of enabled rows
  local enabled_rows = {}
  for row = 1, NUM_ROWS do
    if rows[row].enabled then
      table.insert(enabled_rows, row)
    end
  end
  
  -- Randomly assign one enabled row per step
  if #enabled_rows > 0 then
    for step = 1, MAX_STEPS do
      local selected_row = enabled_rows[math.random(1, #enabled_rows)]
      checkbox_states[selected_row][step] = true
    end
  end
  
  -- Apply all checkbox changes at once (batch update)
  for row = 1, NUM_ROWS do
    if row_checkboxes[row] then
      for step = 1, MAX_STEPS do
        if row_checkboxes[row][step] then
          row_checkboxes[row][step].value = checkbox_states[row][step]
        end
      end
    end
  end
  
  -- STEP 4: Re-enable "print to pattern"
  initializing_dialog = false
  
  -- Single pattern write and UI update
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  renoise.app():show_status("Random Gate applied - one row per step")
end

-- Shift functionality
function PakettiSliceStepShiftAllRows(direction)
  for row = 1, NUM_ROWS do
    if rows[row].enabled then
      PakettiSliceStepShiftRow(row, direction)
    end
  end
  PakettiSliceStepWriteToPattern()
  renoise.app():show_status("All patterns shifted " .. direction)
end

function PakettiSliceStepShiftRow(row, direction)
  if not row_checkboxes[row] then return end
  
  local shifted = {}
  if direction == "left" then
    for step = 1, MAX_STEPS do
      shifted[step] = row_checkboxes[row][(step % MAX_STEPS) + 1].value
    end
  elseif direction == "right" then
    for step = 1, MAX_STEPS do
      shifted[step] = row_checkboxes[row][((step - 2) % MAX_STEPS) + 1].value
    end
  end
  
  for step = 1, MAX_STEPS do
    if row_checkboxes[row][step] then
      row_checkboxes[row][step].value = shifted[step]
    end
  end
end

-- Helper function to get current sample for transpose
function PakettiSliceStepGetCurrentSample()
  local song = renoise.song()
  if not song then return nil end
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then return nil end
  return instrument.samples[song.selected_sample_index] or instrument.samples[1]
end

-- Helper function to map slice note to corresponding sample index
function PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
  local slice_info = PakettiSliceStepGetSliceInfo()
  if not slice_info then return nil end
  
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then return nil end
  
  -- If slice_note is the first slice key, return sample index 2 (first slice)
  if slice_note == slice_info.first_slice_key then
    return 2  -- First slice is sample index 2
  end
  
  -- Map slice notes to sample indices
  -- slice_note = first_slice_key + 0 -> sample index 2 (first slice)  
  -- slice_note = first_slice_key + 1 -> sample index 3 (second slice)
  -- etc.
  if slice_note >= slice_info.first_slice_key and slice_note <= (slice_info.first_slice_key + slice_info.slice_count - 1) then
    local slice_offset = slice_note - slice_info.first_slice_key
    local sample_index = slice_offset + 2  -- +2 because sample 1 is full sample, slices start at index 2
    
    -- Clamp to available samples
    if sample_index > #instrument.samples then
      sample_index = #instrument.samples
    end
    if sample_index < 1 then
      sample_index = 1
    end
    
    return sample_index
  end
  
  -- Fallback: return currently selected sample
  return song.selected_sample_index or 1
end

-- UI Creation
function PakettiSliceStepCreateRowControls(vb_local, row)
  local row_data = rows[row]
  print("DEBUG: Creating row " .. row .. " controls - mode is: " .. row_data.mode)
  
  -- Get appropriate sample transpose for initial value
  local current_transpose = 0
  local song = renoise.song()
  if song then
    local instrument = song.selected_instrument
    if instrument and #instrument.samples > 0 then
      local sample_index = song.selected_sample_index or 1  -- Default to first sample if none selected
      
      if row_data.mode == ROW_MODES.SLICE then
        -- Use the slice note that this row is actually set to play
        local slice_note = row_data.slice_note
        if slice_note then
          sample_index = PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
        else
          -- Fallback to old behavior if slice_note is not set
          sample_index = row + 1
        end
      end
      
      -- Clamp to available samples
      if sample_index > #instrument.samples then
        sample_index = #instrument.samples
      end
      if sample_index < 1 then
        sample_index = 1
      end
      
      local target_sample = instrument.samples[sample_index]
      if target_sample then
        current_transpose = target_sample.transpose
        -- Clamp to rotary range to prevent errors
        if current_transpose < -32 then current_transpose = -32 end
        if current_transpose > 32 then current_transpose = 32 end
      end
    end
  end
  
  -- Create transpose rotary (replaces "R1" text)
  local transpose_rotary = vb_local:rotary{
    min = -32,
    max = 32,
    value = current_transpose,
    width = 20,
    height = 20,
    active = (row_data.mode == ROW_MODES.SLICE),  -- Active only in slice mode
    notifier = (function(current_row)
      return function(value)
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        
        local song = renoise.song()
        if not song then return end
        
        local instrument = song.selected_instrument
        if not instrument or #instrument.samples == 0 then return end
        
        -- For slice mode: control the transpose of the actual slice note that's selected
        -- For sample offset mode: use currently selected sample
        local sample_index = song.selected_sample_index  -- Default to current sample
        
        if rows[current_row].mode == ROW_MODES.SLICE then
          -- Use the slice note that this row is actually set to play
          local slice_note = rows[current_row].slice_note
          if slice_note then
            sample_index = PakettiSliceStepGetSampleIndexForSliceNote(slice_note)
          else
            -- Fallback to old behavior if slice_note is not set
            sample_index = current_row + 1
          end
        end
        
        -- Clamp to available samples
        if sample_index > #instrument.samples then
          sample_index = #instrument.samples
        end
        if sample_index < 1 then
          sample_index = 1
        end
        
        local target_sample = instrument.samples[sample_index]
        if target_sample then
          target_sample.transpose = value
          local slice_note_text = ""
          if rows[current_row].mode == ROW_MODES.SLICE and rows[current_row].slice_note then
            slice_note_text = " (slice note: " .. PakettiSliceStepNoteValueToString(rows[current_row].slice_note) .. ")"
          end
          renoise.app():show_status("Row " .. current_row .. " sample " .. sample_index .. " transpose: " .. value .. " semitones" .. slice_note_text)
        end
      end
    end)(row)
  }
  transpose_rotaries[row] = transpose_rotary  -- Store reference
  
  -- ROW 1: [TRANSPOSE ROTARY][step buttons][step count valuebox]
  local step_buttons = {}
  for step = 1, MAX_STEPS do
    step_buttons[step] = vb_local:button{
      text = string.format("%02d", step),
      width = 30,
      color = {0,0,0},
      notifier = (function(s, current_row) 
        return function()
          -- Highlight the row and select note column when interacting with this row
          PakettiSliceStepHighlightRow(current_row)
          -- Select the corresponding slice in sample editor when interacting with this row
          PakettiSliceStepSelectSliceForRow(current_row)
          -- Set step count to clicked step (like PakettiGater)
          PakettiSliceStepSetActiveSteps(current_row, s)
        end
      end)(step, row)
    }
    row_buttons[row][step] = step_buttons[step]
  end
  
  -- Step valuebox
  local step_valuebox = vb_local:valuebox{
    min = 1,
    max = 32,
    value = row_data.active_steps,
    width = 50,
    notifier = (function(current_row)
      return function(value)
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        PakettiSliceStepSetRowSteps(current_row, value)
      end
    end)(row)
  }
  step_valueboxes[row] = step_valuebox  -- Store reference for updating
  
  -- Build row 1: solo checkbox + step buttons + step valuebox + Clear/Shift buttons
  -- Solo checkbox (moved to row 1)
  local solo_checkbox = vb_local:checkbox{
    value = rows[row].soloed or false,
    width = 20,
    notifier = (function(current_row)
      return function(value)
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        -- Update solo state
        rows[current_row].soloed = value
        -- Update column muting based on solo states
        PakettiSliceStepUpdateSoloStates()
        PakettiSliceStepUpdateButtonColors()
      end
    end)(row)
  }
  
  local row_1_elements = {solo_checkbox}
  for step = 1, MAX_STEPS do
    table.insert(row_1_elements, step_buttons[step])
  end
  table.insert(row_1_elements, step_valuebox)
  
  -- Add Clear, shift, and fill buttons to row 1
  table.insert(row_1_elements, vb_local:button{
    text = "Clear",
    width = 50,
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        PakettiSliceStepClearRow(current_row)
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = "<",
    width = 30,
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        PakettiSliceStepShiftRow(current_row, "left")
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = ">",
    width = 30,
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        PakettiSliceStepShiftRow(current_row, "right")
      end
    end)(row)
  })
  -- Add fill pattern buttons
  table.insert(row_1_elements, vb_local:button{
    text = "2",
    width = 25,
    tooltip = "Fill every 2 steps (1,3,5,7...)",
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        PakettiSliceStepFillRowEveryN(current_row, 2)
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = "4", 
    width = 25,
    tooltip = "Fill every 4 steps (1,5,9,13...)",
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        PakettiSliceStepFillRowEveryN(current_row, 4)
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = "E",
    width = 25,
    tooltip = "Fill using current Edit Step",
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        PakettiSliceStepFillRowEveryEditStep(current_row)
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = "RND",
    width = 35,
    tooltip = "Fill randomly (50% chance per step)",
    notifier = (function(current_row)
      return function()
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        -- Select the corresponding slice in sample editor when interacting with this row
        PakettiSliceStepSelectSliceForRow(current_row)
        PakettiSliceStepFillRowRandomly(current_row)
      end
    end)(row)
  })
  local row_1 = vb_local:row(row_1_elements)
  
  -- ROW 2: [TRANSPOSE ROTARY][checkboxes][switch][sample offset valuebox if applicable]
  -- Create step checkboxes with optimized notifiers (transpose rotary moved to row 2)
  local row_2_elements = {transpose_rotary}
  for step = 1, MAX_STEPS do
    local checkbox = vb_local:checkbox{
      value = false,
      width = 30,
      notifier = (function(current_row, current_step)
        return function(value)
          -- Highlight the row and select note column when interacting with this row
          PakettiSliceStepHighlightRow(current_row)
          -- Select the corresponding slice in sample editor when interacting with this row
          PakettiSliceStepSelectSliceForRow(current_row)
          
          -- CRITICAL: When step is activated, set velocity to maximum (80) - unless velocity canvas is setting it
          if value == true and not velocity_canvas_setting_velocity then
            if row_velocities[current_row] then
              row_velocities[current_row][current_step] = 80  -- Set to maximum velocity
              print("DEBUG: Step " .. current_step .. " activated on row " .. current_row .. " - set velocity to 80 (max)")
              
              -- Update velocity canvas if it's visible and showing this row
              if velocity_canvas_expanded and current_selected_row == current_row then
                PakettiSliceStepUpdateVelocityCanvasForRow(current_row)
              end
            end
          end
          
          -- Only update this specific row, not entire pattern
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end)(row, step)
    }
    row_checkboxes[row][step] = checkbox
    table.insert(row_2_elements, checkbox)
  end
  
  -- Add mode switch to row_2
  local current_mode = rows[row].mode
  print("DEBUG: Creating switch for row " .. row .. " with current mode " .. current_mode)
  
  -- Check if slices are available 
  local slice_info = PakettiSliceStepGetSliceInfo()
  local has_slices = slice_info and slice_info.slice_count > 0
  
  -- Always provide both options (ViewBuilder switch needs at least 2 items)
  local switch_items = {"Sample Offset", "Slice"}
  local switch_value = current_mode
  
  -- Force to sample offset mode if no slices available but somehow in slice mode
  if current_mode == ROW_MODES.SLICE and not has_slices then
    print("DEBUG: FORCING row " .. row .. " from SLICE to SAMPLE_OFFSET mode (no slices available)")
    rows[row].mode = ROW_MODES.SAMPLE_OFFSET
    switch_value = ROW_MODES.SAMPLE_OFFSET
  end
  
  print("DEBUG: Row " .. row .. " switch using mode " .. switch_value .. " (has_slices: " .. tostring(has_slices) .. ")")
  
  local mode_switch = vb_local:switch{
    items = switch_items,
    value = switch_value,
    width = 160,
    notifier = (function(current_row)
      return function(value)
        -- Dynamic check for slices (in case sample changed after dialog creation)
        local current_slice_info = PakettiSliceStepGetSliceInfo()
        local current_has_slices = current_slice_info and current_slice_info.slice_count > 0
        
        print("DEBUG: Row " .. current_row .. " switch clicked - attempting to change to mode " .. value .. " (has_slices: " .. tostring(current_has_slices) .. ")")
        
        -- BUGFIX: Only block Slice mode when no slices available - allow Sample Offset to work normally
        if value == ROW_MODES.SLICE and not current_has_slices then
          -- Don't update anything - just show error and let UI stay "broken" temporarily
          -- This way clicking "Sample Offset" will trigger the notifier properly
          renoise.app():show_status("Cannot use Slice mode: Sample has no slice markers - click Sample Offset to fix")
          print("DEBUG: Row " .. current_row .. " BLOCKED from SLICE mode (no slices available) - UI temporarily desync'd")
          return
        end
        
        -- Normal switching - both Sample Offset (when no slices) and Slice (when slices available)
        PakettiSliceStepHighlightRow(current_row)
        print("DEBUG: Row " .. current_row .. " switch clicked - changing to mode " .. value)
        PakettiSliceStepSetRowMode(current_row, value)
      end
    end)(row)
  }
  row_mode_switches[row] = mode_switch
  table.insert(row_2_elements, mode_switch)
  
  -- Add sample offset controls after the mode switch
  table.insert(row_2_elements, vb_local:text{text = "0S:", width = 20, style = "strong", font = "bold"})
  
  local sample_offset_valuebox = vb_local:valuebox{
    min = 0,
    max = 255,
    value = row_data.value,
    width = 50,
    active = (switch_value == ROW_MODES.SAMPLE_OFFSET),
    notifier = (function(current_row)
      return function(value)
        -- Highlight the row and select note column when interacting with this row
        PakettiSliceStepHighlightRow(current_row)
        if rows[current_row].mode == ROW_MODES.SAMPLE_OFFSET then
          rows[current_row].value = value
          -- Update sample editor selection to show offset position
          PakettiSliceStepSampleOffsetUpdateSelection(value)
          -- Only update this specific row, not entire pattern
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end
    end)(row)
  }
  sample_offset_valueboxes[row] = sample_offset_valuebox
  table.insert(row_2_elements, sample_offset_valuebox)
  
  -- Control buttons (Clear, shift left/right) moved to row 1
  
  -- Add mode-specific controls to row_2
  PakettiSliceStepAddModeControlsToRow(vb_local, row, row_2_elements)
  
  local row_2 = vb_local:row(row_2_elements)
  
  -- Build the 2-row column layout
  return vb_local:column{row_1, row_2}
end

-- Add mode-specific controls to the elements table
function PakettiSliceStepAddModeControlsToRow(vb_local, row, elements_table)
  local row_data = rows[row]
  
  if row_data.mode == ROW_MODES.SAMPLE_OFFSET then
    local note_valuebox = vb_local:valuebox{
      min = 0,
      max = 119,
      value = row_data.note_value,
      width = 50,
      notifier = (function(current_row)
        return function(value)
          -- Highlight the row and select note column when interacting with this row
          PakettiSliceStepHighlightRow(current_row)
          rows[current_row].note_value = value
          -- Update the note text label dynamically
          if note_text_labels[current_row] then
            note_text_labels[current_row].text = PakettiSliceStepNoteValueToString(value)
          end
          -- Only update this specific row, not entire pattern
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end)(row)
    }
    note_valueboxes[row] = note_valuebox  -- Store reference
    table.insert(elements_table, note_valuebox)
    
    local note_text_label = vb_local:text{text = PakettiSliceStepNoteValueToString(row_data.note_value), style = "strong", font = "bold", width = 30}
    note_text_labels[row] = note_text_label  -- Store reference for dynamic updates
    table.insert(elements_table, note_text_label)
    
    -- Add +1/-1 octave buttons for Sample Offset mode
    table.insert(elements_table, vb_local:button{
      text = "-1",
      width = 25,
      notifier = (function(current_row, current_valuebox)
        return function()
          PakettiSliceStepHighlightRow(current_row)
          local new_value = math.max(0, rows[current_row].note_value - 12)
          rows[current_row].note_value = new_value
          -- Update the valuebox directly
          current_valuebox.value = new_value
          -- Update note label
          if note_text_labels[current_row] then
            note_text_labels[current_row].text = PakettiSliceStepNoteValueToString(new_value)
          end
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end)(row, note_valuebox)
    })
    table.insert(elements_table, vb_local:button{
      text = "+1",
      width = 25,
      notifier = (function(current_row, current_valuebox)
        return function()
          PakettiSliceStepHighlightRow(current_row)
          local new_value = math.min(119, rows[current_row].note_value + 12)
          rows[current_row].note_value = new_value
          -- Update the valuebox directly
          current_valuebox.value = new_value
          -- Update note label
          if note_text_labels[current_row] then
            note_text_labels[current_row].text = PakettiSliceStepNoteValueToString(new_value)
          end
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end)(row, note_valuebox)
    })
  
  elseif row_data.mode == ROW_MODES.SLICE then
    local slice_info = PakettiSliceStepGetSliceInfo()
    if slice_info then
      table.insert(elements_table, vb_local:text{text = "Slice:", width = 30, style = "strong", font = "bold"})
      
      -- Apply slice mapping directly: row 1 = first slice ([1][2]), row 2 = second slice ([1][3]), etc.
      local slice_note_for_row = slice_info.first_slice_key + (row - 1)
      if not row_data.slice_note then
        row_data.slice_note = slice_note_for_row  -- Apply it directly to the data
        rows[row].slice_note = slice_note_for_row  -- And to the global rows data
      end
      
      local slice_valuebox = vb_local:valuebox{
        min = slice_info.min_note, -- Use actual detected min 
        max = slice_info.max_note, -- Use actual detected max
        value = row_data.slice_note,
        width = 50,
        notifier = (function(current_row)
          return function(value)
            -- Highlight the row and select note column when interacting with this row
            PakettiSliceStepHighlightRow(current_row)
            rows[current_row].slice_note = value
            -- Update the text label dynamically
            if slice_note_labels[current_row] then
              slice_note_labels[current_row].text = PakettiSliceStepNoteValueToString(value)
            end
            -- Only update this specific row, not entire pattern
            PakettiSliceStepWriteRowToPattern(current_row)
          end
        end)(row)
      }
      slice_note_valueboxes[row] = slice_valuebox  -- Store reference
      table.insert(elements_table, slice_valuebox)
      
      local slice_note_label = vb_local:text{
        text = PakettiSliceStepNoteValueToString(row_data.slice_note), 
        style = "strong", 
        font = "bold",
        width = 35
      }
      slice_note_labels[row] = slice_note_label  -- Store reference for dynamic updates
      table.insert(elements_table, slice_note_label)
      
      -- Add +1/-1 octave buttons for Slice mode
      table.insert(elements_table, vb_local:button{
        text = "-1",
        width = 25,
        notifier = (function(current_row, current_valuebox, current_label)
          return function()
            PakettiSliceStepHighlightRow(current_row)
            local new_value = math.max(slice_info.min_note, rows[current_row].slice_note - 12)
            rows[current_row].slice_note = new_value
            -- Update slice valuebox directly
            current_valuebox.value = new_value
            -- Update slice note label directly
            current_label.text = PakettiSliceStepNoteValueToString(new_value)
            PakettiSliceStepWriteRowToPattern(current_row)
          end
        end)(row, slice_valuebox, slice_note_label)
      })
      table.insert(elements_table, vb_local:button{
        text = "+1",
        width = 25,
        notifier = (function(current_row, current_valuebox, current_label)
          return function()
            PakettiSliceStepHighlightRow(current_row)
            local new_value = math.min(slice_info.max_note, rows[current_row].slice_note + 12)
            rows[current_row].slice_note = new_value
            -- Update slice valuebox directly
            current_valuebox.value = new_value
            -- Update slice note label directly
            current_label.text = PakettiSliceStepNoteValueToString(new_value)
            PakettiSliceStepWriteRowToPattern(current_row)
          end
        end)(row, slice_valuebox, slice_note_label)
      })
    else
      table.insert(elements_table, vb_local:text{text = "N/A", style = "disabled"})
    end
  end
end


function PakettiSliceStepUpdateSoloStates()
  local song = renoise.song()
  local track = song.selected_track
  
  -- Check if any rows are soloed
  local any_soloed = false
  for row = 1, NUM_ROWS do
    if rows[row].soloed then
      any_soloed = true
      break
    end
  end
  
  -- Update column muting based on solo states
  if any_soloed then
    -- Solo mode: mute all columns, then unmute only soloed ones
    for row = 1, NUM_ROWS do
      if row <= track.max_note_columns then
        local should_be_muted = not rows[row].soloed
        if track:column_is_muted(row) ~= should_be_muted then
          track:set_column_is_muted(row, should_be_muted)
          print("DEBUG: Solo - Set column " .. row .. " muted = " .. tostring(should_be_muted))
        end
      end
    end
  else
    -- No solo: unmute all columns
    for row = 1, NUM_ROWS do
      if row <= track.max_note_columns then
        if track:column_is_muted(row) then
          track:set_column_is_muted(row, false)
          print("DEBUG: Solo - Unmuted column " .. row .. " (no solo active)")
        end
      end
    end
  end
end

function PakettiSliceStepDuplicatePattern()
  local song=renoise.song()
  local current_pattern_index=song.selected_pattern_index
  local current_sequence_index=song.selected_sequence_index
  local new_sequence_index = current_sequence_index + 1
  local new_pattern_index = song.sequencer:insert_new_pattern_at(new_sequence_index)
  song.patterns[new_pattern_index]:copy_from(song.patterns[current_pattern_index])
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (duplicate)"
  
  -- CRITICAL: Transport user to the new pattern location
  song.selected_sequence_index = new_sequence_index
  song.selected_pattern_index = new_pattern_index
  
  -- CRITICAL: Force the edit and playback positions to the new pattern location
  -- This works regardless of follow pattern setting and ensures user is transported to new pattern
  local new_song_pos = renoise.SongPos(new_sequence_index, 1)
  
  -- Always set edit position to new pattern
  song.transport.edit_pos = new_song_pos
  
  -- If playing, also move playback position to new pattern  
  if song.transport.playing then
    song.transport.playback_pos = new_song_pos
  end
  
  -- Ensure pattern editor is active and updates view
  --if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
  --  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  --end
  
  -- Copy mute states from original sequence slot to the new one
  for track_index = 1, #song.tracks do
    local is_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end
  -- Copy automation data explicitly to ensure full duplication
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    local source_pattern = song.patterns[current_pattern_index]
    local dest_pattern = song.patterns[new_pattern_index]
    
    -- Copy track automation
    if source_pattern.tracks[track_index] and source_pattern.tracks[track_index].automation then
      for _, automation in ipairs(source_pattern.tracks[track_index].automation) do
        local dest_automation = dest_pattern.tracks[track_index]:create_automation(automation.dest_parameter)
        dest_automation.playmode = automation.playmode
        dest_automation.length = automation.length
        dest_automation:clear()
        for point_index = 1, automation.length do
          dest_automation:add_point_at(point_index, automation:point_at(point_index))
        end
      end
    end
  end
  renoise.app():show_status("Pattern duplicated and moved to sequence position " .. new_sequence_index)
end

function PakettiSliceStepCreateDialog()
  -- Handle close-on-reopen: if dialog is already open, close it
  if dialog and dialog.visible then
    PakettiSliceStepCleanupPlayhead()
    PakettiSliceStepCleanupTrackChangeDetection()
    PakettiSliceStepCleanupPatternChangeDetection()
    dialog:close()
    dialog = nil
    return
  end
  
  -- STEP 1: HALT dialog -> pattern writing
  print("DEBUG: Dialog opening - HALTING pattern writing")
  initializing_dialog = true
  
  -- STEP 1.1: Clear slice cache to ensure fresh detection
  PakettiSliceStepClearSliceCache()
  
  -- STEP 1.2: Auto-select instrument based on track usage
  local instrument_changed = PakettiSliceStepAutoSelectInstrument()
  
  -- STEP 1.5: Read view setting from first column before initializing UI
  local song = renoise.song()
  if song and song.selected_track and song.selected_track.max_note_columns >= 1 then
    local first_column_name = song.selected_track:column_name(1)
    if first_column_name:find("_32") then
      current_steps = 32
      MAX_STEPS = 32
      print("DEBUG: Restored 32-step view setting from first column: '" .. first_column_name .. "'")
    elseif first_column_name:find("_16") then
      current_steps = 16
      MAX_STEPS = 16
      print("DEBUG: Restored 16-step view setting from first column: '" .. first_column_name .. "'")
    end
  end
  
  -- STEP 2: Initialize rows with default values
  print("DEBUG: Dialog opening - INITIALIZING rows")
  PakettiSliceStepInitializeRows()
  
  local content = vb:column{
    vb:row{
      vb:text{text = "Steps",style="strong",font="bold"},
      vb:switch{
        items = {"16", "32"},width=50,
        value = (current_steps == 32) and 2 or 1,
        notifier = function(value)
          local old_steps = current_steps
          current_steps = (value == 2) and 32 or 16
          MAX_STEPS = current_steps -- Update MAX_STEPS
          
          -- Show immediate feedback
          renoise.app():show_status("Switching to " .. current_steps .. " steps...")
          
          -- Optimize: Only save checkbox states that we'll actually need to restore/duplicate
          local saved_checkbox_states = {}
          local saved_row_steps = {}
          local saved_row_modes = {}
          local saved_row_enabled = {}
          local saved_row_data = {}
          
          -- CRITICAL: Save velocity canvas state and selected row for restoration
          local saved_velocity_canvas_expanded = velocity_canvas_expanded
          local saved_current_selected_row = current_selected_row
          local saved_row_velocities = {}
          -- Deep copy velocity data
          for row = 1, NUM_ROWS do
            saved_row_velocities[row] = {}
            if row_velocities[row] then
              for step = 1, MAX_STEPS do
                saved_row_velocities[row][step] = row_velocities[row][step]
              end
            end
          end
          for row = 1, NUM_ROWS do
            saved_checkbox_states[row] = {}
            saved_row_steps[row] = rows[row].active_steps -- Only save step counts, not all data
            saved_row_modes[row] = rows[row].mode -- PRESERVE row modes during step switching
            saved_row_enabled[row] = rows[row].enabled -- PRESERVE enabled states
            saved_row_data[row] = {
              mode = rows[row].mode,
              value = rows[row].value,
              note_value = rows[row].note_value,
              slice_note = rows[row].slice_note,
              enabled = rows[row].enabled,
              active_steps = rows[row].active_steps
            }
            if row_checkboxes[row] then
              -- Only save states for steps that exist
              local steps_to_save = math.min(old_steps, rows[row].active_steps or old_steps)
              for step = 1, steps_to_save do
                if row_checkboxes[row][step] then
                  saved_checkbox_states[row][step] = row_checkboxes[row][step].value
                end
              end
            end
          end
          
          -- Smart step count updating logic
          -- Check if ALL rows are currently using the old step count
          local all_rows_at_old_steps = true
          print("DEBUG: Checking step counts - old_steps=" .. old_steps .. ", current_steps=" .. current_steps)
          for row = 1, NUM_ROWS do
            local row_steps = rows[row].active_steps or 0
            print("DEBUG: Row " .. row .. " has active_steps=" .. row_steps)
            if row_steps ~= old_steps then
              all_rows_at_old_steps = false
              print("DEBUG: Row " .. row .. " step count mismatch - has " .. row_steps .. ", expected " .. old_steps)
              break
            end
          end
          print("DEBUG: all_rows_at_old_steps=" .. tostring(all_rows_at_old_steps))
          
          local rows_to_update = {}
          if all_rows_at_old_steps then
            -- If ALL rows are at old step count, update ALL to new step count (best UX)
            print("DEBUG: *** ALL ROWS AT " .. old_steps .. " STEPS -> UPDATING ALL TO " .. current_steps .. " STEPS AND DUPLICATING ***")
            for row = 1, NUM_ROWS do
              rows[row].active_steps = current_steps
              rows_to_update[row] = true
              print("DEBUG: Updated row " .. row .. " from " .. old_steps .. " to " .. current_steps .. " steps (will duplicate content)")
            end
          else
            -- Mixed step counts - only update rows that were using the old maximum
            print("DEBUG: *** MIXED STEP COUNTS - ONLY UPDATING ROWS THAT MATCH " .. old_steps .. " STEPS ***")
            for row = 1, NUM_ROWS do
              if rows[row].active_steps == old_steps then
                rows[row].active_steps = current_steps
                rows_to_update[row] = true
                print("DEBUG: Updated row " .. row .. " from " .. old_steps .. " to " .. current_steps .. " steps (will duplicate content)")
              else
                print("DEBUG: Skipped row " .. row .. " (has " .. (rows[row].active_steps or 0) .. " steps, not " .. old_steps .. " - will preserve existing pattern)")
              end
            end
          end
          
          -- Optimize: Batch UI updates and minimize dialog recreation work
          local was_initializing = initializing_dialog
          initializing_dialog = true -- Prevent pattern writing during UI updates
          
          -- Set global flag to prevent auto Global Slice during step switching
          step_switching_in_progress = true
          
          -- CRITICAL: Update ALL column names BEFORE recreating dialog
          -- Otherwise PakettiSliceStepCreateDialog() will read the old names and reset our changes!
          local song = renoise.song()
          if song and song.selected_track then
            local track = song.selected_track
            
            -- Update column 1 with view setting
            local view_setting = current_steps .. "_" .. current_steps
            track:set_column_name(1, view_setting)
            print("DEBUG: PRE-DIALOG: Updated column 1 name to '" .. view_setting .. "' before dialog recreation")
            
            -- Update columns 2-8 for rows that were updated to new step count
            for row = 2, NUM_ROWS do
              if rows_to_update[row] and row <= track.max_note_columns then
                local new_step_count = rows[row].active_steps
                local current_column_name = track:column_name(row)
                local target_column_name = string.format("%02d", new_step_count)
                
                -- Only update if the column name doesn't already match the target
                if current_column_name ~= target_column_name then
                  track:set_column_name(row, target_column_name)
                  print("DEBUG: PRE-DIALOG: Updated column " .. row .. " name from '" .. current_column_name .. "' to '" .. target_column_name .. "' before dialog recreation")
                else
                  print("DEBUG: PRE-DIALOG: Column " .. row .. " name '" .. current_column_name .. "' already matches target, skipping update")
                end
              end
            end
          end
          
          -- Refresh dialog (unavoidable due to ViewBuilder limitations)
          PakettiSliceStepCleanupPlayhead()
          PakettiSliceStepCleanupTrackChangeDetection()
          PakettiSliceStepCleanupPatternChangeDetection()
          dialog:close()
          dialog = nil
          PakettiSliceStepCreateDialog()
          
          -- CRITICAL: Restore row data IMMEDIATELY after dialog recreation
          -- NOTE: Don't restore active_steps during step switching - pattern reading handles it correctly
          for row = 1, NUM_ROWS do
            if saved_row_data[row] then
              rows[row].mode = saved_row_data[row].mode
              rows[row].value = saved_row_data[row].value
              rows[row].note_value = saved_row_data[row].note_value
              rows[row].slice_note = saved_row_data[row].slice_note
              rows[row].enabled = saved_row_data[row].enabled
              -- DON'T restore active_steps during step switching - pattern reading already set correct values from updated column names
              
              print("DEBUG: RESTORED row " .. row .. " - mode: " .. rows[row].mode .. ", enabled: " .. tostring(rows[row].enabled) .. ", active_steps: " .. rows[row].active_steps .. " (preserved from pattern reading)")
              
              -- Update UI switch to match restored mode
              if row_mode_switches[row] then
                row_mode_switches[row].value = rows[row].mode
                print("DEBUG: RESTORED switch for row " .. row .. " to mode " .. rows[row].mode)
              end
              
              -- CRITICAL: Update step valuebox to show the CURRENT (pattern-read) step count, not the saved one
              if step_valueboxes[row] then
                step_valueboxes[row].value = rows[row].active_steps  -- Use current value, not saved value
                print("DEBUG: RESTORED step valuebox for row " .. row .. " to " .. rows[row].active_steps .. " steps (from pattern reading)")
              end
            end
          end
          
          -- CRITICAL: Restore velocity canvas state and selected row
          velocity_canvas_expanded = saved_velocity_canvas_expanded
          current_selected_row = saved_current_selected_row
          
          -- Restore velocity data (expand for 32-step mode)
          row_velocities = {}
          for row = 1, NUM_ROWS do
            row_velocities[row] = {}
            if saved_row_velocities[row] then
              for step = 1, MAX_STEPS do
                if step <= old_steps then
                  -- Restore original velocity data
                  row_velocities[row][step] = saved_row_velocities[row][step] or 80
                elseif old_steps == 16 and current_steps == 32 and step > 16 then
                  -- For 16->32 expansion, duplicate velocities like checkboxes
                  local source_step = step - 16
                  if source_step >= 1 and source_step <= 16 then
                    row_velocities[row][step] = saved_row_velocities[row][source_step] or 80
                  else
                    row_velocities[row][step] = 80  -- Default for new steps
                  end
                else
                  row_velocities[row][step] = 80  -- Default max velocity
                end
              end
            else
              -- Initialize with defaults if no saved data
              for step = 1, MAX_STEPS do
                row_velocities[row][step] = 80
              end
            end
          end
          
          -- Restore velocity canvas expanded state
          if velocity_canvas_toggle_button then
            velocity_canvas_toggle_button.text = velocity_canvas_expanded and "▾" or "▴"
          end
          if velocity_canvas_content_column then
            velocity_canvas_content_column.visible = velocity_canvas_expanded
          end
          
          -- Restore selected row highlighting
          if saved_current_selected_row then
            PakettiSliceStepHighlightRow(saved_current_selected_row)
            print("DEBUG: RESTORED selected row: " .. saved_current_selected_row)
          end
          
          -- Update velocity canvas to show restored state
          PakettiSliceStepUpdateVelocityCanvasForRow(current_selected_row or 1)
          
          -- Clear the step switching flag after restoration
          step_switching_in_progress = false
          print("DEBUG: Step switching restoration complete - flag cleared, velocity canvas state restored")
          
          -- Smart restore and duplicate logic
          if old_steps == 16 and current_steps == 32 then
            local duplicated_rows = 0
            local preserved_rows = 0
            
            print("DEBUG: *** 16->32 STEP EXPANSION: Restoring checkboxes and duplicating patterns ***")
            
            -- Batch all checkbox updates to minimize UI redraws
            for row = 1, NUM_ROWS do
              if saved_checkbox_states[row] and row_checkboxes[row] then
                local row_step_count = saved_row_steps[row] or 16
                
                -- Restore original steps (only up to what the row actually had)
                local restore_steps = math.min(16, row_step_count)
                for step = 1, restore_steps do
                  if row_checkboxes[row][step] and saved_checkbox_states[row][step] ~= nil then
                    row_checkboxes[row][step].value = saved_checkbox_states[row][step]
                  end
                end
                
                -- Smart duplication logic based on whether this row was updated
                if rows_to_update[row] then
                  -- This row was updated to 32 steps - duplicate its pattern
                  print("DEBUG: Row " .. row .. " - DUPLICATING steps 1-" .. restore_steps .. " to 17-" .. (restore_steps + 16))
                  for step = 1, restore_steps do
                    local target_step = step + 16
                    if target_step <= 32 and row_checkboxes[row][target_step] and saved_checkbox_states[row][step] ~= nil then
                      row_checkboxes[row][target_step].value = saved_checkbox_states[row][step]
                    end
                  end
                  duplicated_rows = duplicated_rows + 1
                else
                  -- This row kept its original step count - preserve silence in 17-32
                  print("DEBUG: Row " .. row .. " - PRESERVING original pattern (was " .. row_step_count .. " steps)")
                  preserved_rows = preserved_rows + 1
                end
              end
            end
            
            -- Smart status messages based on behavior
            local status_msg = "Expanded to 32 steps"
            if all_rows_at_old_steps then
              status_msg = status_msg .. " - all rows expanded to 32 steps and patterns duplicated"
            elseif duplicated_rows > 0 and preserved_rows > 0 then
              status_msg = status_msg .. " - duplicated " .. duplicated_rows .. " rows, preserved " .. preserved_rows .. " rows"
            elseif duplicated_rows > 0 then
              status_msg = status_msg .. " - pattern duplicated for " .. duplicated_rows .. " rows"
            else
              status_msg = status_msg .. " - preserved all row patterns"
            end
            renoise.app():show_status(status_msg)
          elseif old_steps == 32 and current_steps == 16 then
            -- Smart contracting from 32 to 16: keep only first 16 steps
            local contracted_rows = 0
            local preserved_rows = 0
            
            for row = 1, NUM_ROWS do
              if saved_checkbox_states[row] and row_checkboxes[row] then
                for step = 1, 16 do
                  if row_checkboxes[row][step] and saved_checkbox_states[row][step] ~= nil then
                    row_checkboxes[row][step].value = saved_checkbox_states[row][step]
                  end
                end
                
                if rows_to_update[row] then
                  contracted_rows = contracted_rows + 1
                else
                  preserved_rows = preserved_rows + 1
                end
              end
            end
            
            -- Smart status message for contraction
            local status_msg = "Contracted to 16 steps"
            if all_rows_at_old_steps then
              status_msg = status_msg .. " - all rows contracted to 16 steps"
            elseif contracted_rows > 0 and preserved_rows > 0 then
              status_msg = status_msg .. " - contracted " .. contracted_rows .. " rows, preserved " .. preserved_rows .. " rows"
            else
              status_msg = status_msg .. " - kept first 16 steps"
            end
            renoise.app():show_status(status_msg)
          else
            -- Same step count or other transition: restore as-is
            for row = 1, NUM_ROWS do
              if saved_checkbox_states[row] and row_checkboxes[row] then
                for step = 1, math.min(old_steps, current_steps) do
                  if row_checkboxes[row][step] and saved_checkbox_states[row][step] ~= nil then
                    row_checkboxes[row][step].value = saved_checkbox_states[row][step]
                  end
                end
              end
            end
          end
          
          -- Restore original initializing state and batch final updates
          initializing_dialog = was_initializing
          
          -- (Column name was already updated before dialog recreation)
          
          -- Single batched update at the end
          PakettiSliceStepUpdateButtonColors()
          if not initializing_dialog then
            PakettiSliceStepWriteToPattern()
          end
        end
      },
      
       vb:text{text="Global:",font="bold",style="strong"},
vb:text{text="Steps",font="bold",style="strong"},
vb:valuebox{
  min = 1,
  max = 32,
  value = current_steps,
  width = 47,
  notifier = function(value)
    current_steps = value
    MAX_STEPS = value
    
    -- Update all row step counts to match master steps
    for row = 1, NUM_ROWS do
      rows[row].active_steps = value
      -- Update the UI step valuebox for each row
      if step_valueboxes[row] then
        step_valueboxes[row].value = value
      end
      -- Update the step count label for each row
    end
    
    -- Update the view setting in the first column
    local song = renoise.song()
    if song and song.selected_track then
      local view_setting = value .. "_" .. value
      song.selected_track:set_column_name(1, view_setting)
      print("DEBUG: Updated column 1 name to '" .. view_setting .. "' for master steps change")
    end
    
    -- Update button colors and write pattern
    PakettiSliceStepUpdateButtonColors()
    PakettiSliceStepWriteToPattern()
    
    renoise.app():show_status("Master steps set to " .. value .. " - all rows updated")
  end

},


    vb:button{
     text = "Sample Offset",
     width = 80,
     notifier = PakettiSliceStepGlobalSampleOffset
    },
       vb:button{
        text = "Slice",
        width = 30,
        active = (PakettiSliceStepGetSliceInfo() and PakettiSliceStepGetSliceInfo().slice_count > 0),
        notifier = PakettiSliceStepGlobalSlice
    },
           vb:button{
      text = "Even Spread",
      width = 80,
      notifier = PakettiSliceStepEvenSpread
    },
    vb:button{
      text = "Even Offsets",
      width = 80,
      notifier = PakettiSliceStepEvenOffsets
    },
    vb:button{
      text = "Randomize All Rows",
      width = 120,
      tooltip = "Randomly fill all 8 rows (50% chance per step)",
      notifier = PakettiSliceStepRandomizeAllRows
    },

    vb:text{text = "Transpose", font = "bold", style = "strong"},
    vb:button{
      text = "-24",
      width = 25,
      notifier = function()
        PakettiSliceStepSmartTranspose(-24)
      end
    },
    vb:button{
      text = "-12",
      width = 25,
      notifier = function()
        PakettiSliceStepSmartTranspose(-12)
      end
    },
    vb:button{
      text = "0",
      width = 15,
      notifier = function()
        PakettiSliceStepSmartTranspose(0)
      end
    },
    vb:button{
      text = "+12",
      width = 25,
      notifier = function()
        PakettiSliceStepSmartTranspose(12)
      end
    },
    vb:button{
      text = "+24",
      width = 25,
      notifier = function()
        PakettiSliceStepSmartTranspose(24)
      end
    },
    
    vb:text{text = "BPM", font = "bold", style = "strong"},
    vb:button{
      text = "Detect",
      width = 45,
      notifier = function()
        local song = renoise.song()
        if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
          renoise.app():show_status("No sample selected or sample has no data")
          return
        end
        
        local sample = song.selected_sample
        local sample_buffer = sample.sample_buffer
        local sample_length_frames = sample_buffer.number_of_frames
        local sample_rate = sample_buffer.sample_rate
        
        local detected_bpm, beat_count
        
        -- Check if sample has slice markers (sliced break)
        if sample.slice_markers and #sample.slice_markers > 0 then
          -- Use transient detection for sliced breaks
          local estimated_beats = #sample.slice_markers
          detected_bpm, beat_count = pakettiBPMDetectFromTransients(sample_buffer, estimated_beats)
        else
          -- Use intelligent detection for non-sliced breaks
          detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_length_frames, sample_rate)
        end
        
        if detected_bpm then
          renoise.app():show_status(string.format("Detected BPM: %.1f", detected_bpm))
        else
          renoise.app():show_status("Could not detect BPM from sample")
        end
      end
    },
    vb:button{
      text = "Detect&Set",
      width = 70,
      notifier = function()
        local song = renoise.song()
        if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
          renoise.app():show_status("No sample selected or sample has no data")
          return
        end
        
        local sample = song.selected_sample
        local sample_buffer = sample.sample_buffer
        local sample_length_frames = sample_buffer.number_of_frames
        local sample_rate = sample_buffer.sample_rate
        local original_bpm = song.transport.bpm
        
        local detected_bpm, beat_count
        
        -- Check if sample has slice markers (sliced break)
        if sample.slice_markers and #sample.slice_markers > 0 then
          -- Use transient detection for sliced breaks
          local estimated_beats = #sample.slice_markers
          detected_bpm, beat_count = pakettiBPMDetectFromTransients(sample_buffer, estimated_beats)
        else
          -- Use intelligent detection for non-sliced breaks
          detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_length_frames, sample_rate)
        end
        
        if detected_bpm then
          song.transport.bpm = detected_bpm
          renoise.app():show_status(string.format("BPM set to %.1f (was %.1f, %d beats detected)", detected_bpm, original_bpm, beat_count))
        else
          renoise.app():show_status("Could not detect BPM from sample")
        end
      end
    }}}
  
  -- Add row controls
  for row = 1, NUM_ROWS do
    local row_container = PakettiSliceStepCreateRowControls(vb, row)
    row_containers[row] = row_container  -- Store reference for styling
    content:add_child(row_container)
  end
  
  -- Initialize row styles (all to body style initially)
  PakettiSliceStepUpdateRowStyles(nil)
  
  -- Global controls
  content:add_child(vb:column{
  vb:row{
      vb:button{
        text = "Clear All",
        width = 60,
        notifier = function()
          for row = 1, NUM_ROWS do
            for step = 1, MAX_STEPS do
              if row_checkboxes[row][step] then
                row_checkboxes[row][step].value = false
              end
            end
          end
          PakettiSliceStepWriteToPattern()
          renoise.app():show_status("All steps cleared")
        end
      },
      vb:button{
        text = "Random All",
        width = 80,
        notifier = function()
          -- Check if any rows are in slice mode and if we have slices available
          local has_slice_rows = false
          for row = 1, NUM_ROWS do
            if rows[row].enabled and rows[row].mode == ROW_MODES.SLICE then
              has_slice_rows = true
              break
            end
          end
          
          if has_slice_rows then
            local slice_info = PakettiSliceStepGetSliceInfo()
            if not slice_info then
              renoise.app():show_status("Cannot Random All because instrument has no slices, doing nothing.")
              return
            end
          end
          
          -- STEP 1: Disable "print to pattern"
          initializing_dialog = true
          
          trueRandomSeed()
          
          -- STEP 2: Clear the selected track completely
          local song = renoise.song()
          if song then
            local pattern = song.selected_pattern
            local track_index = song.selected_track_index
            local track = pattern:track(track_index)
            track:clear()
            
            -- STEP 3: Turn all checkboxes OFF, then randomize in one batch
            local checkbox_states = {}
            for row = 1, NUM_ROWS do
              checkbox_states[row] = {}
              for step = 1, MAX_STEPS do
                checkbox_states[row][step] = rows[row].enabled and (math.random() > 0.5) or false
              end
            end
            
            -- Apply all checkbox changes at once (batch update)
            for row = 1, NUM_ROWS do
              if row_checkboxes[row] then
                for step = 1, MAX_STEPS do
                  if row_checkboxes[row][step] then
                    row_checkboxes[row][step].value = checkbox_states[row][step]
                  end
                end
              end
            end
            
            -- STEP 4: Re-enable "print to pattern"
            initializing_dialog = false
            
            PakettiSliceStepUpdateButtonColors()
            PakettiSliceStepWriteToPattern()
            renoise.app():show_status("All patterns randomized")
          end
        end
      },
      vb:button{
        text = "Random Gate",
        width = 80,
        notifier = function()
          PakettiSliceStepRandomGate()
        end
      },

      vb:button{
        text = "Render Track to New Sample",
        width = 150,
        notifier = function()
          PakettiImpulseTrackerPatternToSample()
        end
      },
      vb:button{
        text = "Read Pattern",
        width = 80,
        notifier = function()
          PakettiSliceStepReadExistingPattern()
        end
      },
      vb:button{
        text = "<<",
        width = 20,
        notifier = function()
          PakettiSliceStepShiftAllRows("left")
        end
      },
      vb:button{
        text = ">>", 
        width = 20,
        notifier = function()
          PakettiSliceStepShiftAllRows("right")
        end
      },
      vb:text{text = "Pitch Stepper", style="strong", font="Bold", width=70},
      vb:button{
        text = "Clear",
        width = 50,
        notifier = function() PakettiClearStepper("Pitch Stepper") end
      },
      vb:button{
        text = "Two Octaves",
        width = 80,
        notifier = PakettiSliceStepTwoOctaves
    },
       vb:button{
        text = "Octave Up/Down",
        width = 90,
        notifier = PakettiSliceStepOctaveUpDown
    },
    vb:text{text="|",font="bold",style="strong",width=10},
    vb:button{
      text = "Duplicate Pattern", 
      midi_mapping = "Paketti:Paketti Slice Step Sequencer:Duplicate Pattern",
      notifier = PakettiSliceStepDuplicatePattern
    }
    },

  })
  
  -- Create velocity canvas expandable section (moved to bottom)
  velocity_canvas_toggle_button = vb:button{
    text = velocity_canvas_expanded and "▾" or "▴", -- Set initial state from preference
    width = 22,
    notifier = function()
      velocity_canvas_expanded = not velocity_canvas_expanded
      -- Update the preference when user toggles
      preferences.pakettiSliceStepSeqShowVelocity.value = velocity_canvas_expanded
      PakettiSliceStepUpdateVelocityCanvasVisibility()
    end
  }
  
  -- Create the canvas directly and store reference
  velocity_canvas = vb:canvas{
    width = PakettiSliceStepCalculateVelocityCanvasWidth(),  -- Calculate width to match step buttons
    height = velocity_canvas_height,
    mode = "plain",
    render = PakettiSliceStepDrawVelocityCanvas,
    mouse_handler = PakettiSliceStepHandleVelocityCanvasMouse,
    mouse_events = {"down", "up", "move", "exit"}
  }
  
  velocity_canvas_content_column = vb:column{
    
    style = "group",
    --margin = 6,
    visible = velocity_canvas_expanded, -- Use preference for initial state
    
    vb:row{
      vb:text{text=" ",width=20},
      velocity_canvas  -- Use the stored canvas reference
    }
    
--    vb:row{
--      vb:text{
--        text = "Instructions: Draws velocity bars only where steps are active. Drawing in empty areas creates new steps with that velocity.",
--        width = PakettiSliceStepCalculateVelocityCanvasWidth() - 20,  -- Match calculated canvas width
--        style = "normal"
--      }
--    }
  }

  -- Add expandable velocity section to dialog
  content:add_child(vb:row{
    velocity_canvas_toggle_button,
    vb:text{
      text = "Show Velocity Editor Canvas",
      style = "strong",
      font = "bold",
      width = 300
    }
  })
  
  -- Add the collapsible velocity content
  content:add_child(velocity_canvas_content_column)
  
  -- Initialize velocity section visibility
  PakettiSliceStepUpdateVelocityCanvasVisibility()
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) 
      dialog = value 
      if not value then
        -- Dialog closed, cleanup
        PakettiSliceStepCleanupPlayhead()
        PakettiSliceStepCleanupTrackChangeDetection()
        PakettiSliceStepCleanupPatternChangeDetection()
      end
    end,
    -- Custom key handler for CTRL-Z/CMD-Z undo support
    function(dialog, key)
      -- Check for undo key combinations
      if (key.modifiers == "control" and key.name == "z") or (key.modifiers == "cmd" and key.name == "z") then
        print("DEBUG: Undo key detected - will read pattern after 4ms delay")
        -- Let Renoise handle the undo first, then read the pattern after a short delay
        local undo_timer_fn = function()
          if dialog and dialog.visible then
            print("DEBUG: Reading pattern after undo operation")
            PakettiSliceStepReadExistingPattern()
          end
        end
        renoise.tool():add_timer(undo_timer_fn, 4) -- 4ms delay
        -- Return false to let Renoise handle the undo normally
        return false
      end
      -- Return false for all other keys to use default handling
      return false
    end
  )
  
  dialog = renoise.app():show_custom_dialog("Paketti Sample Offset / Slice Step Sequencer", content, keyhandler)
  
  -- Setup playhead and track/pattern change detection
  PakettiSliceStepSetupPlayhead()
  PakettiSliceStepSetupTrackChangeDetection()
  PakettiSliceStepSetupPatternChangeDetection()
  
  -- STEP 3: READ PATTERN to populate rows (NOW that UI elements exist)
  print("DEBUG: Dialog opened - READING pattern to populate rows")
  PakettiSliceStepReadExistingPattern()
  
  -- STEP 3.5: READ VELOCITIES from pattern
  print("DEBUG: Dialog opened - READING velocities from pattern")
  PakettiSliceStepReadVelocitiesFromPattern()
  
  -- STEP 4: RESTART dialog -> pattern writing
  print("DEBUG: Dialog opened - RESTARTING pattern writing")
  initializing_dialog = false
  
  -- STEP 5: Auto-highlight row based on current note column position
  local song = renoise.song()
  if song and song.selected_track then
    local track = song.selected_track
    local current_note_column = song.selected_note_column_index
    local visible_columns = track.visible_note_columns
    
    -- If the track has 8 note columns enabled and we're on the 8th note column
    if visible_columns == 8 and current_note_column == 8 then
      print("DEBUG: Auto-highlighting row 8 (current note column: " .. current_note_column .. ", visible columns: " .. visible_columns .. ")")
      PakettiSliceStepHighlightRow(8)
    -- If we're on any other note column position within the available rows, highlight that row
    elseif current_note_column >= 1 and current_note_column <= NUM_ROWS and current_note_column <= visible_columns then
      print("DEBUG: Auto-highlighting row " .. current_note_column .. " (current note column: " .. current_note_column .. ", visible columns: " .. visible_columns .. ")")
      PakettiSliceStepHighlightRow(current_note_column)
    end
  end
  
  -- Ensure focus returns to Pattern Editor
--  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Show current Sample Offset position from selected row manually
function PakettiSliceStepShowCurrentSampleOffset()
  -- Switch to sample editor if not already there
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end
  
  local song = renoise.song()
  if not song then return end
  
  -- Get currently selected note column to determine which step sequencer row to check
  local note_column = song.selected_note_column_index
  if note_column < 1 or note_column > NUM_ROWS then
    renoise.app():show_status("Select a note column (1-8) to show its Sample Offset position")
    return
  end
  
  -- Check if this row is in sample offset mode and has a value
  if not rows[note_column] or rows[note_column].mode ~= ROW_MODES.SAMPLE_OFFSET then
    renoise.app():show_status("Note column " .. note_column .. " is not in Sample Offset mode")
    return
  end
  
  local offset_value = rows[note_column].value
  PakettiSliceStepSampleOffsetUpdateSelection(offset_value)
  renoise.app():show_status("Sample Offset Row " .. note_column .. ": 0S" .. string.format("%02X", offset_value) .. " position highlighted in sample editor")
end

-- Menu entries and keybindings
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Sample Offset / Slice Step Sequencer...",invoke = function() PakettiSliceStepCreateDialog() end}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Gadgets:Sample Offset / Slice Step Sequencer...",invoke = function() PakettiSliceStepCreateDialog() end}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti Gadgets:Sample Offset / Slice Step Sequencer...",invoke = function() PakettiSliceStepCreateDialog() end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti Gadgets:Sample Offset / Slice Step Sequencer...",invoke = function() PakettiSliceStepCreateDialog() end}
renoise.tool():add_menu_entry{name = "Mixer:Paketti Gadgets:Sample Offset / Slice Step Sequencer...",invoke = function() PakettiSliceStepCreateDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Sample Offset / Slice Step Sequencer...",
  invoke = function() 
    if renoise.song() then
      PakettiSliceStepCreateDialog()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Sample Offset / Slice Step Sequencer...",
  invoke = function(message)
    if message:is_trigger() and renoise.song() then
      PakettiSliceStepCreateDialog()
    end
  end
}

-- Sample Offset Visualizer keybinding
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Show Current Sample Offset in Sample Editor",
  invoke = PakettiSliceStepShowCurrentSampleOffset
}

-- Function to read existing pattern and populate checkboxes
function PakettiSliceStepReadExistingPattern()
  if not renoise.song() then return end
  
  print("DEBUG: PakettiSliceStepReadExistingPattern - Starting pattern read...")
  
  -- HALT pattern writing during read
  local was_initializing = initializing_dialog
  initializing_dialog = true
  
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_track
  
  local read_count = 0
  local detected_modes = {} -- Track what mode each row should be
  local slice_info = PakettiSliceStepGetSliceInfo()
  local has_sample_offsets = false
  
  -- First read step counts from column names
  PakettiSliceStepReadStepCountMarkers(pattern, track_index, track)
  
  -- Clear all checkboxes first
  for row = 1, NUM_ROWS do
    if row_checkboxes[row] then
      for step = 1, MAX_STEPS do
        if row_checkboxes[row][step] then
          row_checkboxes[row][step].value = false
        end
      end
    end
  end
  
  -- FIRST PASS: Analyze pattern to detect what modes each row should use
  print("DEBUG: Analyzing pattern to detect content modes...")
  
  -- Check for ANY sample offsets in the pattern (check both effect columns and note column sample effects)
  for line_idx = 1, pattern.number_of_lines do
    local pattern_line = pattern:track(track_index):line(line_idx)
    -- Check effect columns (legacy)
    for col = 1, #pattern_line.effect_columns do
      local effect_col = pattern_line.effect_columns[col]
      if effect_col.number_string == "0S" then
        has_sample_offsets = true
        print("DEBUG: Found sample offsets in effect columns - will use SAMPLE_OFFSET mode")
        break
      end
    end
    -- Check note column sample effects (new method)
    if not has_sample_offsets then
      for col = 1, track.visible_note_columns do
        local note_col = pattern_line:note_column(col)
        if note_col.effect_number_string == "0S" then
          has_sample_offsets = true
          print("DEBUG: Found sample offsets in note column sample effects - will use SAMPLE_OFFSET mode")
          break
        end
      end
    end
    if has_sample_offsets then break end
  end
  
  -- Track slice notes for empty pattern initialization
  local detected_slice_notes = {}
  
  -- Now analyze each row
  for line_idx = 1, math.min(MAX_STEPS, pattern.number_of_lines) do
    local pattern_line = pattern:track(track_index):line(line_idx)
    
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then
        -- Check for Sample Offset (0Sxx in effect columns or note column sample effects)
        local found_sample_offset = false
        if row <= #pattern_line.effect_columns then
          local effect_col = pattern_line.effect_columns[row]
          if effect_col.number_string == "0S" then
            found_sample_offset = true
          end
        end
        if not found_sample_offset and row <= track.visible_note_columns then
          local note_col = pattern_line:note_column(row)
          if note_col.effect_number_string == "0S" then
            found_sample_offset = true
          end
        end
        if found_sample_offset then
          detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
          print("DEBUG: Row " .. row .. " detected as SAMPLE_OFFSET (found 0S)")
        end
        
        -- Check for Slice notes (if sliced instrument is available)
        if not detected_modes[row] and slice_info and row <= track.visible_note_columns then
          local note_col = pattern_line:note_column(row)
          if note_col.note_string ~= "---" and note_col.note_string ~= "" then
            -- Try to parse the note and see if it's in slice range
            local note_value = PakettiSliceStepNoteStringToValue(note_col.note_string)
            if note_value and note_value >= slice_info.first_slice_key and note_value <= (slice_info.first_slice_key + slice_info.slice_count - 1) then
              detected_modes[row] = ROW_MODES.SLICE
              detected_slice_notes[row] = note_value  -- STORE THE ACTUAL SLICE NOTE VALUE!
              print("DEBUG: Row " .. row .. " detected as SLICE (found slice note " .. note_col.note_string .. " = " .. note_value .. ")")
            end
          end
        end
      end
    end
  end
  
  -- Analyze pattern type and apply the user's clear logic
  local rows_with_sample_offsets = 0
  local rows_with_slices = 0
  local empty_rows = 0
  
  for row = 1, NUM_ROWS do
    if detected_modes[row] == ROW_MODES.SAMPLE_OFFSET then
      rows_with_sample_offsets = rows_with_sample_offsets + 1
    elseif detected_modes[row] == ROW_MODES.SLICE then
      rows_with_slices = rows_with_slices + 1
    else
      empty_rows = empty_rows + 1
    end
  end
  
  local total_content_rows = rows_with_sample_offsets + rows_with_slices
  
  print("DEBUG: Pattern analysis - Sample offsets: " .. rows_with_sample_offsets .. ", Slices: " .. rows_with_slices .. ", Empty: " .. empty_rows)
  
  if total_content_rows == 0 then
    -- CASE 1: EMPTY PATTERN + SLICED INSTRUMENT → Global Slice with sequential slice mapping
    if slice_info and slice_info.slice_count > 0 then
      print("DEBUG: EMPTY PATTERN + SLICED INSTRUMENT → GLOBAL SLICE with first 8 slices")
      for row = 1, NUM_ROWS do
        if row <= math.min(8, slice_info.slice_count) then
          detected_modes[row] = ROW_MODES.SLICE
          -- Map first 8 slices sequentially: Row 1 = first slice, Row 2 = second slice, etc.
          local slice_note = slice_info.first_slice_key + (row - 1)
          detected_slice_notes[row] = slice_note
          print("DEBUG: Row " .. row .. " set to SLICE with slice note " .. slice_note .. " (" .. PakettiSliceStepNoteValueToString(slice_note) .. ")")
        else
          detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
          print("DEBUG: Row " .. row .. " set to SAMPLE_OFFSET (beyond first 8 slices)")
        end
      end
    else
      print("DEBUG: EMPTY PATTERN + NO SLICES → SAMPLE_OFFSET")
      for row = 1, NUM_ROWS do
        detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
      end
    end
  elseif rows_with_slices > 0 and rows_with_sample_offsets == 0 then
    -- CASE 2: PATTERN WITH ONLY SLICES → Preserve existing slices, fill empty rows
    print("DEBUG: PATTERN WITH ONLY SLICES → PRESERVE EXISTING SLICES")
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then -- Only set undetected rows (preserve existing slice data)
        if slice_info and row <= slice_info.slice_count then
          detected_modes[row] = ROW_MODES.SLICE
          -- Only assign default slice notes to EMPTY rows - don't overwrite existing ones
          if not detected_slice_notes[row] then
            detected_slice_notes[row] = slice_info.first_slice_key + (row - 1)
          end
          print("DEBUG: Row " .. row .. " set to SLICE (preserving existing slice data)")
        else
          detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
          print("DEBUG: Row " .. row .. " set to SAMPLE_OFFSET (beyond slice count)")
        end
      end
    end
  elseif rows_with_sample_offsets > 0 and rows_with_slices == 0 then
    -- CASE 3: PATTERN WITH ONLY SAMPLE OFFSETS → Global Sample Offset
    print("DEBUG: PATTERN WITH ONLY SAMPLE OFFSETS → GLOBAL SAMPLE OFFSET")
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then -- Only set undetected rows
        detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
        print("DEBUG: Row " .. row .. " set to SAMPLE_OFFSET (Global Sample Offset)")
      end
    end
  else
    -- CASE 4: MIXED PATTERN → Per-row detection (already done in first pass)
    print("DEBUG: MIXED PATTERN → PER-ROW DETECTION (sample offsets: " .. rows_with_sample_offsets .. ", slices: " .. rows_with_slices .. ")")
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then
        -- Default empty rows in mixed pattern to sample offset
        detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
        print("DEBUG: Row " .. row .. " defaulted to SAMPLE_OFFSET (mixed pattern, empty row)")
      end
    end
  end
  
  -- Apply detected modes to rows
  local mode_change_count = 0
  for row = 1, NUM_ROWS do
    if detected_modes[row] and detected_modes[row] ~= rows[row].mode then
      print("DEBUG: Changing row " .. row .. " from mode " .. rows[row].mode .. " to mode " .. detected_modes[row])
      rows[row].mode = detected_modes[row]
      if row_mode_switches[row] then
        row_mode_switches[row].value = detected_modes[row]
      end
      mode_change_count = mode_change_count + 1
    end
    
    -- Apply detected slice notes for SLICE mode rows
    if detected_slice_notes[row] and detected_modes[row] == ROW_MODES.SLICE then
      rows[row].slice_note = detected_slice_notes[row]
      print("DEBUG: Applied slice note " .. detected_slice_notes[row] .. " to row " .. row)
      
      -- Update slice note valuebox if it exists
      if slice_note_valueboxes[row] then
        slice_note_valueboxes[row].value = detected_slice_notes[row]
        print("DEBUG: Updated slice note valuebox for row " .. row .. " to " .. detected_slice_notes[row])
      end
      
      -- Update slice note label if it exists
      if slice_note_labels[row] then
        slice_note_labels[row].text = PakettiSliceStepNoteValueToString(detected_slice_notes[row])
        print("DEBUG: Updated slice note label for row " .. row .. " to " .. PakettiSliceStepNoteValueToString(detected_slice_notes[row]))
      end
    end
  end
  
  if mode_change_count > 0 then
    print("DEBUG: Auto-detected and changed " .. mode_change_count .. " row modes")
    -- Refresh UI after mode changes to update switch displays and controls
    PakettiSliceStepUpdateButtonColors()
    PakettiSliceStepUpdateSampleEffectColumnVisibility()
    
    -- Update mode-specific control visibility for all changed rows
    for row = 1, NUM_ROWS do
      if detected_modes[row] then
        local mode = detected_modes[row] -- Use the detected mode (which is now applied to rows[row].mode)
        -- Enable/disable sample offset valuebox based on mode
        if sample_offset_valueboxes[row] then
          sample_offset_valueboxes[row].active = (mode == ROW_MODES.SAMPLE_OFFSET)
          print("DEBUG: Sample offset valuebox for row " .. row .. " " .. (mode == ROW_MODES.SAMPLE_OFFSET and "enabled" or "disabled"))
        end
        -- Enable/disable slice note valuebox based on mode
        if slice_note_valueboxes[row] then
          slice_note_valueboxes[row].active = (mode == ROW_MODES.SLICE)
          print("DEBUG: Slice note valuebox for row " .. row .. " " .. (mode == ROW_MODES.SLICE and "enabled" or "disabled"))
        end
        -- Enable/disable transpose rotary based on mode  
        if transpose_rotaries[row] then
          transpose_rotaries[row].active = (mode == ROW_MODES.SLICE)
          print("DEBUG: Transpose rotary for row " .. row .. " " .. (mode == ROW_MODES.SLICE and "enabled" or "disabled"))
        end
      end
    end
  end
  
  -- SECOND PASS: Read existing pattern data based on detected/current modes
  for line_idx = 1, math.min(MAX_STEPS, pattern.number_of_lines) do
    local pattern_line = pattern:track(track_index):line(line_idx)
    
    -- Check each row for existing data based on current mode
    for row = 1, NUM_ROWS do  -- All rows 1-8
      if row_checkboxes[row] and row_checkboxes[row][line_idx] then
        local row_data = rows[row]
        local found_data = false
        
        if row_data.mode == ROW_MODES.SAMPLE_OFFSET then
          -- Check for 0Sxx in effect columns AND notes in note columns
          if row <= track.visible_note_columns then
            local note_col = pattern_line:note_column(row)
            if note_col.note_string ~= "---" and note_col.note_string ~= "" then
              found_data = true
              -- Update the note value from the pattern
              local note_value = PakettiSliceStepNoteStringToValue(note_col.note_string)
              if note_value then
                rows[row].note_value = note_value
                print("DEBUG: Read note " .. note_col.note_string .. " (value: " .. note_value .. ") from row " .. row .. " line " .. line_idx)
              end
            end
          end
          -- Also check for 0Sxx in effect columns (legacy) or note column sample effects (new)
          local sample_offset_value = nil
          local sample_offset_source = ""
          if row <= #pattern_line.effect_columns then
            local effect_col = pattern_line.effect_columns[row]
            if effect_col.number_string == "0S" then
              sample_offset_value = tonumber(effect_col.amount_string, 16)
              sample_offset_source = "effect column"
            end
          end
          if not sample_offset_value and row <= track.visible_note_columns then
            local note_col = pattern_line:note_column(row)
            if note_col.effect_number_string == "0S" then
              sample_offset_value = tonumber(note_col.effect_amount_string, 16)
              sample_offset_source = "note column sample effect"
            end
          end
          if sample_offset_value then
            found_data = true
            rows[row].value = sample_offset_value
            -- Update the UI valuebox if it exists
            if sample_offset_valueboxes[row] then
              sample_offset_valueboxes[row].value = sample_offset_value
              -- Update sample editor visualization for this offset value
              PakettiSliceStepSampleOffsetUpdateSelection(sample_offset_value)
            end
            print("DEBUG: Read 0S" .. string.format("%02X", sample_offset_value) .. " from row " .. row .. " line " .. line_idx .. " (" .. sample_offset_source .. ") - updated UI valuebox and sample visualization")
          end
          
        elseif row_data.mode == ROW_MODES.SLICE then
          -- Check for notes in note columns
          if row <= track.visible_note_columns then
            local note_col = pattern_line:note_column(row)
            if note_col.note_string ~= "---" and note_col.note_string ~= "" then
              found_data = true
              -- Update the slice note value
              local note_value = PakettiSliceStepNoteStringToValue(note_col.note_string)
              if note_value then
                rows[row].slice_note = note_value
                print("DEBUG: Read slice note " .. note_col.note_string .. " (value: " .. note_value .. ") from row " .. row .. " line " .. line_idx)
              end
            end
          end
          
        -- (Device parameter mode removed)
        end
        
        if found_data then
          row_checkboxes[row][line_idx].value = true
          read_count = read_count + 1
        end
      end
    end
    -- (Reverse row functionality removed)
  end
  
  -- Update UI elements to reflect the read note values
  for row = 1, NUM_ROWS do
    if rows[row].mode == ROW_MODES.SAMPLE_OFFSET and rows[row].note_value then
      -- Update note valuebox if it exists
      if note_valueboxes[row] then
        note_valueboxes[row].value = rows[row].note_value
        print("DEBUG: Updated note valuebox for row " .. row .. " to note value " .. rows[row].note_value)
      end
      -- Update note label if it exists
      if note_text_labels[row] then
        note_text_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].note_value)
        print("DEBUG: Updated note label for row " .. row .. " to " .. PakettiSliceStepNoteValueToString(rows[row].note_value))
      end
    elseif rows[row].mode == ROW_MODES.SLICE and rows[row].slice_note then
      -- Update slice note valuebox if it exists
      if slice_note_valueboxes[row] then
        slice_note_valueboxes[row].value = rows[row].slice_note
        print("DEBUG: Updated slice note valuebox for row " .. row .. " to note value " .. rows[row].slice_note)
      end
      -- Update slice note label if it exists
      if slice_note_labels[row] then
        slice_note_labels[row].text = PakettiSliceStepNoteValueToString(rows[row].slice_note)
        print("DEBUG: Updated slice note label for row " .. row .. " to " .. PakettiSliceStepNoteValueToString(rows[row].slice_note))
      end
    end
  end
  
  -- RESTORE pattern writing state (will remain halted if called during dialog creation)
  initializing_dialog = was_initializing
  print("DEBUG: PakettiSliceStepReadExistingPattern - Pattern writing state restored to: " .. tostring(not initializing_dialog))
  
  print("DEBUG: PakettiSliceStepReadExistingPattern - Completed. Read " .. read_count .. " steps")
  
  -- Pattern reading complete - refresh slice UI elements to show applied slice notes
  PakettiSliceStepRefreshSliceUI()
  
  -- Pattern reading complete
  
  local status_message = "Read Pattern: Found " .. read_count .. " steps"
  if mode_change_count > 0 then
    status_message = status_message .. " (auto-detected " .. mode_change_count .. " row modes)"
  end
  if has_sample_offsets then
    status_message = status_message .. " - Sample Offset mode"
  elseif slice_info then
    status_message = status_message .. " - Slice mode"
  end
  renoise.app():show_status(status_message)
end

-- MIDI mapping and keybinding for Duplicate Pattern button in Slice Step Sequencer
renoise.tool():add_midi_mapping{name="Paketti:Paketti Slice Step Sequencer:Duplicate Pattern",invoke=function(message)
  if message:is_trigger() then PakettiSliceStepDuplicatePattern() end
end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Pattern (Slice Step Sequencer)",invoke=PakettiSliceStepDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate Pattern (Slice Step Sequencer)",invoke=PakettiSliceStepDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Pattern (Slice Step Sequencer)",invoke=PakettiSliceStepDuplicatePattern}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Pattern (Slice Step Sequencer)",invoke=PakettiSliceStepDuplicatePattern}


