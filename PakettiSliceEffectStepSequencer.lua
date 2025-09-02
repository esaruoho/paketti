-- Paketti Slice / Effect Step Sequencer
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
local slice_note_valueboxes = {}  -- Store references to slice note valueboxes
local slice_note_labels = {}  -- Store references to slice note text labels
local sample_offset_valueboxes = {}  -- Store references to sample offset valueboxes
local transpose_rotaries = {}  -- Store references to transpose rotaries

-- Track change detection
local current_track_index = nil
local track_change_notifier = nil

-- Dialog initialization flag to prevent pattern writing during population
local initializing_dialog = false

-- Current note column tracking for optimized updates
local current_note_column = 1
local last_pattern_state = {}  -- Cache to detect actual changes

-- Playhead state
local playhead_color = nil
local playhead_timer_fn = nil
local playing_observer_fn = nil
local playhead_step_indices = {}

-- (Reverse functionality removed)

-- Colors
local normal_color = {0,0,0}
local beat_color = {0x22 / 255, 0xaa / 255, 0xff / 255}
local selected_color = {0x80, 0x00, 0x80}

-- Selected step tracking (like PakettiGater)
local selected_steps = {}

-- Row modes
local ROW_MODES = {
  SAMPLE_OFFSET = 1,
  SLICE = 2
}

local MODE_NAMES = {
  [ROW_MODES.SAMPLE_OFFSET] = "Sample Offset (0Sxx)",
  [ROW_MODES.SLICE] = "Slice Notes"
}

-- Initialize row data
function PakettiSliceStepInitializeRows()
  rows = {}
  row_buttons = {}
  row_checkboxes = {}
  row_mode_switches = {}  -- Clear switch references
  step_valueboxes = {}  -- Clear step valuebox references
  note_text_labels = {}  -- Clear note text label references
  slice_note_valueboxes = {}  -- Clear slice note valuebox references
  slice_note_labels = {}  -- Clear slice note label references
  sample_offset_valueboxes = {}  -- Clear sample offset valuebox references
  transpose_rotaries = {}  -- Clear transpose rotary references
  playhead_step_indices = {}
  selected_steps = {}  -- Initialize selected step tracking
  current_track_index = renoise.song().selected_track_index
  
  local slice_info = PakettiSliceStepGetSliceInfo()
  local default_slice_base = slice_info and slice_info.base_note or 48
  
  for row = 1, NUM_ROWS do
    rows[row] = {
      mode = ROW_MODES.SLICE, -- Default to slice mode
      value = 0x20, -- Default sample offset
      note_value = 36, -- C-3 default note
      slice_note = default_slice_base + row, -- Default slice note for each row
      active_steps = MAX_STEPS,
      enabled = true
    }
    
    row_buttons[row] = {}
    row_checkboxes[row] = {}
    playhead_step_indices[row] = nil
    selected_steps[row] = nil  -- No selection by default
    
    for step = 1, MAX_STEPS do
      row_checkboxes[row][step] = nil -- Will be created by ViewBuilder
    end
  end
end

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
          new_idx = ((within_steps_window_index - 1) % MAX_STEPS) + 1
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
      current_track_index = new_track_index
      -- Refresh device/parameter information in UI
      renoise.app():show_status("Step Sequencer: Track changed, refreshing device list")
      -- Would refresh UI here if it was dynamic
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
          local is_beat_marker = (step == 1 or step == 5 or step == 9 or step == 13)
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

-- Row step selection
function PakettiSliceStepSelectStep(row, step)
  -- Set active steps for all modes
  PakettiSliceStepSetRowSteps(row, step)
end

-- Slice detection
function PakettiSliceStepGetSliceInfo()
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then return nil end
  
  local first_sample = instrument.samples[1]
  if #first_sample.slice_markers == 0 then return nil end
  
  -- Find the actual key mappings - we need to distinguish base sample from slices
  local min_note = nil
  local max_note = nil
  local base_note = nil
  local all_slice_notes = {}
  
  -- Scan through sample mappings to find the ACTUAL base note and slice range
  for i = 1, #instrument.sample_mappings do
    local mapping = instrument.sample_mappings[i]
    if mapping.sample_index == 1 then -- First sample (sliced)
      -- Collect all notes mapped to the sliced sample
      for note = mapping.note_range[1], mapping.note_range[2] do
        table.insert(all_slice_notes, note)
        if not min_note or note < min_note then
          min_note = note
        end
        if not max_note or note > max_note then
          max_note = note
        end
      end
    end
  end
  
  -- The base note is typically the LOWEST note mapped to the sliced sample
  -- (This is where the full unsliced sample is usually mapped)
  if all_slice_notes and #all_slice_notes > 0 then
    table.sort(all_slice_notes)
    base_note = all_slice_notes[1] -- Lowest note = base sample
  else
    -- Fallback if no mappings found
    base_note = 48 -- C-4
    min_note = 48
    max_note = 48 + #first_sample.slice_markers
  end
  
  local function note_to_string(note_value)
    local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
    local octave = math.floor(note_value / 12)
    local note = (note_value % 12) + 1
    return note_names[note] .. octave
  end
  
  local slice_count = #first_sample.slice_markers + 1
  local was_detected = (all_slice_notes and #all_slice_notes > 0)
  local detection_info = was_detected and " (detected)" or " (fallback - no keymaps found!)"
  
  return {
    slice_count = slice_count,
    sample = first_sample,
    base_note = base_note or 48,
    min_note = min_note,
    max_note = max_note,
    note_range = "Base: " .. note_to_string(base_note or 48) .. detection_info .. " | Slices: " .. note_to_string((base_note or 48) + 1) .. " to " .. note_to_string(max_note),
    was_detected = was_detected
  }
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
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    print("DEBUG: Selected note column " .. row .. " for step sequencer row " .. row)
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
  
  -- Ensure effect columns are visible for sample offset mode
  if rows[target_row].mode == ROW_MODES.SAMPLE_OFFSET and track.visible_effect_columns < target_row then
    track.visible_effect_columns = target_row
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
    
    -- Clear effect column if in sample offset mode
    if row_data.mode == ROW_MODES.SAMPLE_OFFSET and target_row <= #pattern_line.effect_columns then
      pattern_line.effect_columns[target_row]:clear()
    end
  end
  
  -- STEP 2: Write step count marker (ZZxx) to first line
  if row_data.enabled and row_steps ~= 16 then
    local first_line = pattern:track(track_index):line(1)
    if target_row <= track.visible_note_columns then
      local note_column = first_line:note_column(target_row)
      note_column.effect_number_string = "ZZ"
      note_column.effect_amount_string = string.format("%02X", row_steps)
    end
  end
  
  -- STEP 3: Write only ACTIVE steps to first row_steps lines (not all lines!)
  if row_data.enabled then
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
            
            -- Copy effect column efficiently if in sample offset mode
            if row_data.mode == ROW_MODES.SAMPLE_OFFSET and target_row <= #dest_line.effect_columns then
              dest_line.effect_columns[target_row]:copy_from(source_line.effect_columns[target_row])
            end
          end
        end
      end
    end
  end
  
  renoise.app():show_status("Flood-filled row " .. target_row .. " pattern")
end

-- Helper function: Write a single step to a single line (extracted from PakettiSliceStepWriteRowToLine)
function PakettiSliceStepWriteStepToLine(row, step, pattern_line, track)
  local row_data = rows[row]
  
  if row_data.mode == ROW_MODES.SAMPLE_OFFSET then
    -- Write sample offset command AND note
    if row <= #pattern_line.effect_columns then
      pattern_line.effect_columns[row].number_string = "0S"
      pattern_line.effect_columns[row].amount_string = string.format("%02X", row_data.value)
    end
    
    -- Also write the note for this sample offset
    if row <= track.visible_note_columns then
      local note_string = PakettiSliceStepNoteValueToString(row_data.note_value)
      pattern_line:note_column(row).note_string = note_string
      pattern_line:note_column(row).instrument_value = renoise.song().selected_instrument_index - 1
    end
    
  elseif row_data.mode == ROW_MODES.SLICE then
    -- Write specific slice note for this row
    local slice_info = PakettiSliceStepGetSliceInfo()
    if slice_info and row <= track.visible_note_columns then
      local note_value = row_data.slice_note or (slice_info.base_note + row)
      local note_string = PakettiSliceStepNoteValueToString(note_value)
      
      pattern_line:note_column(row).note_string = note_string
      pattern_line:note_column(row).instrument_value = renoise.song().selected_instrument_index - 1
    end
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
  
  -- Ensure effect columns are visible for sample offset mode
  if track.visible_effect_columns < 8 then
    track.visible_effect_columns = 8
  end
  
  local pattern_length = pattern.number_of_lines
  
  -- Clear all existing content first
  PakettiSliceStepClearAllPattern(pattern, track_index, track, pattern_length)
  
  -- Write step count markers (ZZxx) to first line for rows with non-default step counts
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

-- Write step count markers (ZZxx) for non-default step counts
function PakettiSliceStepWriteStepCountMarkers(pattern, track_index, track)
  local first_line = pattern:track(track_index):line(1)
  
  -- Write ZZxx markers for rows with step counts different from 16
  for row = 1, NUM_ROWS do
    if rows[row].enabled and rows[row].active_steps ~= 16 then
      -- Use the note column's sample effect columns for step count storage
      if row <= track.visible_note_columns then
        local note_column = first_line:note_column(row)
        note_column.effect_number_string = "ZZ"
        note_column.effect_amount_string = string.format("%02X", rows[row].active_steps)
      end
    end
  end
end

-- Read step count markers (ZZxx) from pattern
function PakettiSliceStepReadStepCountMarkers(pattern, track_index, track)
  local first_line = pattern:track(track_index):line(1)
  
  -- Read ZZxx markers from note columns
  for row = 1, NUM_ROWS do
    if row <= track.visible_note_columns then
      local note_column = first_line:note_column(row)
      if note_column.effect_number_string == "ZZ" then
        local step_count = tonumber(note_column.effect_amount_string, 16)
        if step_count and step_count >= 1 and step_count <= 32 then
          rows[row].active_steps = step_count
          -- Update the UI step valuebox to reflect the read step count
          if step_valueboxes[row] then
            step_valueboxes[row].value = step_count
          end
          print("DEBUG: Read ZZ" .. note_column.effect_amount_string .. " - updated row " .. row .. " step count to " .. step_count .. " and UI valuebox")
        end
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
      
      -- Write sample offset command AND note to appropriate columns
      local effect_column_index = math.min(row, #pattern_line.effect_columns)
      pattern_line.effect_columns[effect_column_index].number_string = "0S"
      pattern_line.effect_columns[effect_column_index].amount_string = string.format("%02X", row_data.value)
      
      -- Also write the note for this sample offset
      local note_string = PakettiSliceStepNoteValueToString(row_data.note_value)
      pattern_line:note_column(row).note_string = note_string
      pattern_line:note_column(row).instrument_value = renoise.song().selected_instrument_index - 1
      print("DEBUG: Sample Offset Row " .. row .. " wrote " .. note_string .. " to note column " .. row .. " with 0S" .. string.format("%02X", row_data.value))
      
    elseif row_data.mode == ROW_MODES.SLICE then
      -- Write specific slice note for this row using the slice_note value
      local slice_info = PakettiSliceStepGetSliceInfo()
      if slice_info then
        local note_value = row_data.slice_note or (slice_info.base_note + row)
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
      -- Clear sample effect columns (where ZZ step count markers are stored)
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
  if not note_string or note_string == "---" or note_string == "" then return nil end
  
  local note_names = {
    ["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3, ["E-"] = 4, ["F-"] = 5,
    ["F#"] = 6, ["G-"] = 7, ["G#"] = 8, ["A-"] = 9, ["A#"] = 10, ["B-"] = 11
  }
  
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
  if not slice_info then
    renoise.app():show_status("No sliced instrument detected - load a sliced sample first!")
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
  
  local enabled_rows = math.min(NUM_ROWS, slice_info.slice_count)
  renoise.app():show_status("Global Slice: Enabled " .. enabled_rows .. " rows, cleared sample offsets, applied slice pattern")
end

function PakettiSliceStepGlobalSampleOffset()
  print("DEBUG: PakettiSliceStepGlobalSampleOffset - Setting all rows to SAMPLE_OFFSET mode...")
  
  -- STEP 1: Disable writing to pattern
  initializing_dialog = true
  
  -- STEP 2: Set all switches to Sample Offset mode directly
  for row = 1, NUM_ROWS do
    print("DEBUG: Setting row " .. row .. " to SAMPLE_OFFSET mode and enabling")
    rows[row].mode = ROW_MODES.SAMPLE_OFFSET
    rows[row].enabled = true
    
    -- Update the UI switch directly - no dialog refresh needed
    if row_mode_switches[row] then
      row_mode_switches[row].value = ROW_MODES.SAMPLE_OFFSET
      print("DEBUG: Updated switch for row " .. row .. " to SAMPLE_OFFSET mode")
    end
    
    -- Enable sample offset valuebox since we're switching to sample offset mode
    if sample_offset_valueboxes[row] then
      sample_offset_valueboxes[row].active = true
      print("DEBUG: Enabled sample offset valuebox for row " .. row)
    end
    
    -- DISABLE transpose rotary for sample offset mode
    if transpose_rotaries[row] then
      transpose_rotaries[row].active = false
      print("DEBUG: Disabled transpose rotary for row " .. row .. " (sample offset mode)")
    end
  end
  
  -- STEP 3: Clear sample offsets from the pattern
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  
  print("DEBUG: Clearing pattern...")
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
  
  -- STEP 4: Re-enable writing to pattern and write the sample offset pattern
  initializing_dialog = false
  
  -- Update button colors and write new sample offset pattern
  PakettiSliceStepUpdateButtonColors()
  PakettiSliceStepWriteToPattern()
  
  renoise.app():show_status("Global Sample Offset: Enabled all 8 rows, cleared pattern, applied sample offset pattern")
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
  
  -- Enable/disable sample offset valuebox based on mode
  if sample_offset_valueboxes[row] then
    sample_offset_valueboxes[row].active = (mode == ROW_MODES.SAMPLE_OFFSET)
    print("DEBUG: Sample offset valuebox for row " .. row .. " " .. (mode == ROW_MODES.SAMPLE_OFFSET and "enabled" or "disabled"))
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
          slice_note = rows[row].slice_note
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
        rows[row].active_steps = saved_rows[row].active_steps
        rows[row].enabled = saved_rows[row].enabled
        rows[row].slice_note = saved_rows[row].slice_note
        -- Update the mode switch to reflect the restored mode
        if row_mode_switches[row] then
          row_mode_switches[row].value = saved_rows[row].mode
        end
        -- Update step valuebox
        if step_valueboxes[row] then
          step_valueboxes[row].value = saved_rows[row].active_steps
        end
        -- Update note text labels and sample offset valuebox
        if saved_rows[row].mode == ROW_MODES.SAMPLE_OFFSET and note_text_labels[row] then
          note_text_labels[row].text = PakettiSliceStepNoteValueToString(saved_rows[row].note_value)
        end
        -- Always update sample offset valuebox value and active state
        if sample_offset_valueboxes[row] then
          sample_offset_valueboxes[row].value = saved_rows[row].value
          sample_offset_valueboxes[row].active = (saved_rows[row].mode == ROW_MODES.SAMPLE_OFFSET)
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
  
  -- If slice_note is the base note, return sample index 1 (full sample)
  if slice_note == slice_info.base_note then
    return 1
  end
  
  -- If slice_note is above base_note, it corresponds to a slice
  -- slice_note = base_note + 1 -> sample index 2 (first slice)
  -- slice_note = base_note + 2 -> sample index 3 (second slice)
  -- etc.
  if slice_note > slice_info.base_note and slice_note <= (slice_info.base_note + slice_info.slice_count) then
    local slice_offset = slice_note - slice_info.base_note
    local sample_index = slice_offset + 1  -- +1 because sample 1 is the full sample
    
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
      local sample_index = song.selected_sample_index  -- Default to current sample
      
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
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        
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
          -- Select the corresponding note column when interacting with this row
          PakettiSliceStepSelectNoteColumn(current_row)
          -- Set step count to clicked step (like PakettiGater)
          PakettiSliceStepSetActiveSteps(current_row, s)
          -- Also toggle the checkbox at this step
          PakettiSliceStepSelectStep(current_row, s)
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
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        PakettiSliceStepSetRowSteps(current_row, value)
      end
    end)(row)
  }
  step_valueboxes[row] = step_valuebox  -- Store reference for updating
  
  -- Build row 1: mute checkbox + step buttons + step valuebox + Clear/Shift buttons
  -- Mute checkbox (moved to row 1)
  local mute_checkbox = vb_local:checkbox{
    value = row_data.enabled,
    width = 20,
    notifier = (function(current_row)
      return function(value)
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        rows[current_row].enabled = value
        PakettiSliceStepUpdateButtonColors()
        -- Only update this specific row, not entire pattern
        PakettiSliceStepWriteRowToPattern(current_row)
      end
    end)(row)
  }
  
  local row_1_elements = {mute_checkbox}
  for step = 1, MAX_STEPS do
    table.insert(row_1_elements, step_buttons[step])
  end
  table.insert(row_1_elements, step_valuebox)
  
  -- Add Clear and shift buttons to row 1
  table.insert(row_1_elements, vb_local:button{
    text = "Clear",
    width = 50,
    notifier = (function(current_row)
      return function()
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        PakettiSliceStepClearRow(current_row)
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = "<",
    width = 30,
    notifier = (function(current_row)
      return function()
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        PakettiSliceStepShiftRow(current_row, "left")
      end
    end)(row)
  })
  table.insert(row_1_elements, vb_local:button{
    text = ">",
    width = 30,
    notifier = (function(current_row)
      return function()
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        PakettiSliceStepShiftRow(current_row, "right")
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
      notifier = (function(current_row)
        return function()
          -- Select the corresponding note column when interacting with this row
          PakettiSliceStepSelectNoteColumn(current_row)
          -- Only update this specific row, not entire pattern
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end)(row)
    }
    row_checkboxes[row][step] = checkbox
    table.insert(row_2_elements, checkbox)
  end
  
  -- Add mode switch to row_2
  local current_mode = rows[row].mode
  print("DEBUG: Creating switch for row " .. row .. " with current mode " .. current_mode)
  
  local mode_switch = vb_local:switch{
    items = {"Sample Offset", "Slice"},
    value = current_mode,
    width = 160,
    notifier = (function(current_row)
      return function(value)
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        print("DEBUG: Row " .. current_row .. " switch clicked - changing from mode " .. current_mode .. " to mode " .. value)
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
    active = (current_mode == ROW_MODES.SAMPLE_OFFSET),
    notifier = (function(current_row)
      return function(value)
        -- Select the corresponding note column when interacting with this row
        PakettiSliceStepSelectNoteColumn(current_row)
        if rows[current_row].mode == ROW_MODES.SAMPLE_OFFSET then
          rows[current_row].value = value
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
    table.insert(elements_table, vb_local:text{text = "Note:", width = 30, style = "strong", font = "bold"})
    table.insert(elements_table, vb_local:valuebox{
      min = 0,
      max = 119,
      value = row_data.note_value,
      width = 50,
      notifier = (function(current_row)
        return function(value)
          -- Select the corresponding note column when interacting with this row
          PakettiSliceStepSelectNoteColumn(current_row)
          rows[current_row].note_value = value
          -- Update the note text label dynamically
          if note_text_labels[current_row] then
            note_text_labels[current_row].text = PakettiSliceStepNoteValueToString(value)
          end
          -- Only update this specific row, not entire pattern
          PakettiSliceStepWriteRowToPattern(current_row)
        end
      end)(row)
    })
    local note_text_label = vb_local:text{text = PakettiSliceStepNoteValueToString(row_data.note_value), style = "strong", font = "bold"}
    note_text_labels[row] = note_text_label  -- Store reference for dynamic updates
    table.insert(elements_table, note_text_label)
  
  elseif row_data.mode == ROW_MODES.SLICE then
    local slice_info = PakettiSliceStepGetSliceInfo()
    if slice_info then
      table.insert(elements_table, vb_local:text{text = "Slice:", width = 30, style = "strong", font = "bold"})
      
      local slice_valuebox = vb_local:valuebox{
        min = slice_info.base_note + 1, -- First slice (base+1)
        max = slice_info.base_note + slice_info.slice_count, -- Last slice
        value = row_data.slice_note or (slice_info.base_note + row),
        width = 50,
        notifier = (function(current_row)
          return function(value)
            -- Select the corresponding note column when interacting with this row
            PakettiSliceStepSelectNoteColumn(current_row)
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
        text = PakettiSliceStepNoteValueToString(row_data.slice_note or (slice_info.base_note + row)), 
        style = "strong", 
        font = "bold"
      }
      slice_note_labels[row] = slice_note_label  -- Store reference for dynamic updates
      table.insert(elements_table, slice_note_label)
    else
      table.insert(elements_table, vb_local:text{text = "N/A", style = "disabled"})
    end
  end
end


function PakettiSliceStepCreateDialog()
  -- Handle close-on-reopen: if dialog is already open, close it
  if dialog and dialog.visible then
    PakettiSliceStepCleanupPlayhead()
    PakettiSliceStepCleanupTrackChangeDetection()
    dialog:close()
    dialog = nil
    return
  end
  
  -- STEP 1: HALT dialog -> pattern writing
  print("DEBUG: Dialog opening - HALTING pattern writing")
  initializing_dialog = true
  
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
          current_steps = (value == 2) and 32 or 16
          MAX_STEPS = current_steps -- Update MAX_STEPS
          -- Refresh dialog
          PakettiSliceStepCleanupPlayhead()
          PakettiSliceStepCleanupTrackChangeDetection()
          dialog:close()
          dialog = nil
          PakettiSliceStepCreateDialog()
        end
      },
      
                 vb:text{text = "Master Steps", width = 80, font="bold",style="strong"},
         vb:valuebox{
           min = 1,
           max = 32,
           value = current_steps,
           width = 60,
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
             end
             
             -- Update button colors and write pattern
             PakettiSliceStepUpdateButtonColors()
             PakettiSliceStepWriteToPattern()
             
             renoise.app():show_status("Master steps set to " .. value .. " - all rows updated")
           end
     
       },
       vb:text{text = "Global", font = "bold", style = "strong"},
    
    vb:button{
     text = "Sample Offset",
     width = 100,
     notifier = PakettiSliceStepGlobalSampleOffset
    },
       vb:button{
        text = "Slice",
        width = 50,
        notifier = PakettiSliceStepGlobalSlice

    }
  }}
  
  -- Add row controls
  for row = 1, NUM_ROWS do
    content:add_child(PakettiSliceStepCreateRowControls(vb, row))
  end
  
  -- Global controls
  content:add_child(vb:column{
  vb:row{
    vb:text{text = "Controls", font = "bold", style = "strong"},
      vb:button{
        text = "Clear All",
        width = 80,
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
          -- Use PakettiRender.lua to render current track to new sample
          -- Parameters: muteOriginal=false, justwav=false, newtrack=false, timestretch_mode=false, current_bpm=nil
          pakettiCleanRenderSelection(false, false, false, false, nil)
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

    },

  })
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) 
      dialog = value 
      if not value then
        -- Dialog closed, cleanup
        PakettiSliceStepCleanupPlayhead()
        PakettiSliceStepCleanupTrackChangeDetection()
      end
    end
  )
  
  dialog = renoise.app():show_custom_dialog("Paketti Sample Offset / Slice Step Sequencer", content, keyhandler)
  
  -- Setup playhead and track change detection
  PakettiSliceStepSetupPlayhead()
  PakettiSliceStepSetupTrackChangeDetection()
  
  -- STEP 3: READ PATTERN to populate rows (NOW that UI elements exist)
  print("DEBUG: Dialog opened - READING pattern to populate rows")
  PakettiSliceStepReadExistingPattern()
  
  -- STEP 4: RESTART dialog -> pattern writing
  print("DEBUG: Dialog opened - RESTARTING pattern writing")
  initializing_dialog = false
  
  -- Ensure focus returns to Pattern Editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Menu entries and keybindings
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Slice / Effect Step Sequencer...",invoke = function() PakettiSliceStepCreateDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Slice / Effect Step Sequencer...",
  invoke = function() 
    if renoise.song() then
      PakettiSliceStepCreateDialog()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Slice / Effect Step Sequencer...",
  invoke = function(message)
    if message:is_trigger() and renoise.song() then
      PakettiSliceStepCreateDialog()
    end
  end
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
  
  -- First read step count markers from first line
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
  
  -- Check for ANY sample offsets in the pattern
  for line_idx = 1, pattern.number_of_lines do
    local pattern_line = pattern:track(track_index):line(line_idx)
    for col = 1, #pattern_line.effect_columns do
      local effect_col = pattern_line.effect_columns[col]
      if effect_col.number_string == "0S" then
        has_sample_offsets = true
        print("DEBUG: Found sample offsets in pattern - will use SAMPLE_OFFSET mode")
        break
      end
    end
    if has_sample_offsets then break end
  end
  
  -- Now analyze each row
  for line_idx = 1, math.min(MAX_STEPS, pattern.number_of_lines) do
    local pattern_line = pattern:track(track_index):line(line_idx)
    
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then
        -- Check for Sample Offset (0Sxx in effect columns)
        if row <= #pattern_line.effect_columns then
          local effect_col = pattern_line.effect_columns[row]
          if effect_col.number_string == "0S" then
            detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
            print("DEBUG: Row " .. row .. " detected as SAMPLE_OFFSET (found 0S)")
          end
        end
        
        -- Check for Slice notes (if sliced instrument is available)
        if not detected_modes[row] and slice_info and row <= track.visible_note_columns then
          local note_col = pattern_line:note_column(row)
          if note_col.note_string ~= "---" and note_col.note_string ~= "" then
            -- Try to parse the note and see if it's in slice range
            local note_value = PakettiSliceStepNoteStringToValue(note_col.note_string)
            if note_value and note_value >= slice_info.base_note and note_value <= (slice_info.base_note + slice_info.slice_count) then
              detected_modes[row] = ROW_MODES.SLICE
              print("DEBUG: Row " .. row .. " detected as SLICE (found slice note " .. note_col.note_string .. ")")
            end
          end
        end
      end
    end
  end
  
  -- Apply GLOBAL mode logic based on user requirements:
  -- 6. when opening dialog, and no sample offsets exist? then you're in slice mode
  -- 7. when opening dialog, and sample offsets exist? then set mode to Sample Offset mode
  if not has_sample_offsets and slice_info then
    print("DEBUG: No sample offsets found and slices available - defaulting all rows to SLICE mode")
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then
        detected_modes[row] = ROW_MODES.SLICE
      end
    end
  elseif has_sample_offsets then
    print("DEBUG: Sample offsets found - defaulting remaining rows to SAMPLE_OFFSET mode")
    for row = 1, NUM_ROWS do
      if not detected_modes[row] then
        detected_modes[row] = ROW_MODES.SAMPLE_OFFSET
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
  end
  
  if mode_change_count > 0 then
    print("DEBUG: Auto-detected and changed " .. mode_change_count .. " row modes")
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
          -- Also check effect columns for 0Sxx
          if row <= #pattern_line.effect_columns then
            local effect_col = pattern_line.effect_columns[row]
            if effect_col.number_string == "0S" then
              found_data = true
              -- Update the value from the pattern
              local hex_value = tonumber(effect_col.amount_string, 16)
              if hex_value then
                rows[row].value = hex_value
                -- Update the UI valuebox if it exists
                if sample_offset_valueboxes[row] then
                  sample_offset_valueboxes[row].value = hex_value
                end
                print("DEBUG: Read 0S" .. effect_col.amount_string .. " from row " .. row .. " line " .. line_idx .. " - updated UI valuebox")
              end
            end
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
  
  -- Update UI elements to reflect the read slice note values
  for row = 1, NUM_ROWS do
    if rows[row].mode == ROW_MODES.SLICE and rows[row].slice_note then
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


