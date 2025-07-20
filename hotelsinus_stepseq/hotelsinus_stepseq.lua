-- Step Sequencer Tool for Renoise
-- Creates a step sequencer interface with checkboxes for each track
local vb = renoise.ViewBuilder()

-- Removed old keyhandler function - now using standardized system


-- Table with note names for display
local note_names = {
  "C-0", "C#0", "D-0", "D#0", "E-0", "F-0", "F#0", "G-0", "G#0", "A-0", "A#0", "B-0",
  "C-1", "C#1", "D-1", "D#1", "E-1", "F-1", "F#1", "G-1", "G#1", "A-1", "A#1", "B-1",
  "C-2", "C#2", "D-2", "D#2", "E-2", "F-2", "F#2", "G-2", "G#2", "A-2", "A#2", "B-2",
  "C-3", "C#3", "D-3", "D#3", "E-3", "F-3", "F#3", "G-3", "G#3", "A-3", "A#3", "B-3",
  "C-4", "C#4", "D-4", "D#4", "E-4", "F-4", "F#4", "G-4", "G#4", "A-4", "A#4", "B-4",
  "C-5", "C#5", "D-5", "D#5", "E-5", "F-5", "F#5", "G-5", "G#5", "A-5", "A#5", "B-5",
  "C-6", "C#6", "D-6", "D#6", "E-6", "F-6", "F#6", "G-6", "G#6", "A-6", "A#6", "B-6",
  "C-7", "C#7", "D-7", "D#7", "E-7", "F-7", "F#7", "G-7", "G#7", "A-7", "A#7", "B-7",
  "C-8", "C#8", "D-8", "D#8", "E-8", "F-8", "F#8", "G-8", "G#8", "A-8", "A#8", "B-8",
  "C-9", "C#9", "D-9", "D#9", "E-9", "F-9", "F#9", "G-9", "G#9", "A-9", "A#9", "B-9"
}

-- Global storage for track values
local instrument_values = {}
local volume_values = {}
local note_values = {}
local switch_states = {}
local current_note = 48 -- Default to C-4

-- Global reference to matrix content for updates
local matrix_container = nil

-- Global storage for checkbox references (for Clear All functionality)
local all_checkboxes = {}

-- Global dialog reference to close it when switching step counts
local dialog = nil

-- Dynamic UI sizing constants
local CHECKBOX_SIZE = 28 -- 1.75x larger (16 * 1.75 = 28)
local VALUEBOX_WIDTH = 62  -- Half size + 25% (50 * 1.25 = 62.5, rounded to 62)
local BUTTON_HEIGHT = 24
local ROW_SPACING = 4
local GRID_SPACING = 6

-- Step count configuration
local STEP_COUNT = 16  -- Can be 16 or 32

-- Pattern Data Loading Functions
--------------------------------

-- Check if a pattern line has any notes
local function hasNotesInLine(pattern_line)
  local note_columns = pattern_line.note_columns
  for _, note_column in ipairs(note_columns) do
    if not note_column.is_empty and note_column.note_value < 120 then  -- Only real notes (0-119)
      return true
    end
  end
  return false
end

-- Check if a pattern line has instrument values
local function hasInstrumentInLine(pattern_line)
  local note_columns = pattern_line.note_columns
  for _, note_column in ipairs(note_columns) do
    if note_column.instrument_value ~= 255 then  -- Only 255 is empty, 0 is valid (first instrument)
      return true
    end
  end
  return false
end

-- Check if a pattern line has volume values
local function hasVolumeInLine(pattern_line)
  local note_columns = pattern_line.note_columns
  for _, note_column in ipairs(note_columns) do
    if note_column.volume_value ~= 0 then
      return true
    end
  end
  return false
end


-- Initialize track values from existing pattern data
local function initializeTrackValues(pattern, track_index)
  if renoise.song() == nil then return end
  print("Loading data for track " .. track_index)
  
  -- First pass: collect all instrument and note values from the track
  local track_instrument_values = {}
  local track_note_values = {}
  
  for i = 1, STEP_COUNT do
    local line = pattern:track(track_index):line(i)
    local line_has_notes = hasNotesInLine(line)
    local line_has_instrument = hasInstrumentInLine(line)
    
    -- Check for notes in the note column
    local has_note = false
    local note_value = 0
    if line_has_notes then
      local note_column = line:note_column(1)
      if not note_column.is_empty and note_column.note_value < 120 then  -- Only real notes
        has_note = true
        note_value = note_column.note_value
        table.insert(track_note_values, note_value)  -- Collect valid notes
      end
    end
    
    -- Set checkbox state based on found notes
    local key = track_index * STEP_COUNT + i
    switch_states[key] = has_note

    -- Store instrument value
    if line_has_instrument then
      local instrument_column = line:note_column(1)
      local inst_val = instrument_column.instrument_value
      print("Track " .. track_index .. " line " .. i .. " has instrument value: " .. inst_val)
      -- Check if it's actually a valid instrument (not empty = 255)
      if inst_val ~= 255 then
        instrument_values[key] = inst_val  -- 0 is valid (first instrument)
        table.insert(track_instrument_values, inst_val)  -- Collect valid instruments
        print("Setting instrument_values[" .. key .. "] = " .. inst_val)
      else
        -- Empty instrument, use currently selected
        local song = renoise.song()
        local current_selected_instrument = song and (song.selected_instrument_index - 1) or 0
        instrument_values[key] = current_selected_instrument
        print("Empty instrument, setting instrument_values[" .. key .. "] = " .. current_selected_instrument)
      end
    else
      -- If no instrument data, use currently selected instrument
      local song = renoise.song()
      local current_selected_instrument = song and (song.selected_instrument_index - 1) or 0
      instrument_values[key] = current_selected_instrument
      print("No instrument data, setting instrument_values[" .. key .. "] = " .. current_selected_instrument)
    end

    -- Store volume value (default: 127, clamp to 0-127 range)
    local volume_value = 127
    if line_has_notes then
      local volume_column = line:note_column(1)
      if not volume_column.is_empty then
        volume_value = math.max(0, math.min(127, volume_column.volume_value))
      end
    end
    volume_values[key] = volume_value

    -- Store note value
    note_values[key] = note_value
  end
  
  -- Set track-wide defaults - use first valid values from track, or sensible defaults
  if not instrument_values[track_index] then
    local song = renoise.song()
    local current_selected_instrument = song and (song.selected_instrument_index - 1) or 0
    instrument_values[track_index] = track_instrument_values[1] or current_selected_instrument
    print("Track " .. track_index .. " default instrument set to: " .. instrument_values[track_index] .. " (first valid from track or selected)")
  end
  if not volume_values[track_index] then
    volume_values[track_index] = 127
  end
  if not note_values[track_index] then
    note_values[track_index] = track_note_values[1] or current_note  -- Use first valid note from track
    print("Track " .. track_index .. " default note set to: " .. note_values[track_index] .. " (first valid from track or C-4)")
  end
end

-- UI Creation Functions
-----------------------

-- Create value boxes for note, instrument, and volume
local function createControlBoxes(row, pattern, track_index)
  -- Get currently selected instrument as a sensible default
  local song = renoise.song()
  local current_selected_instrument = song and (song.selected_instrument_index - 1) or 0  -- Convert to 0-based
  
  -- Debug: Check values before creating valueboxes
  local note_val = note_values[track_index] or current_note
  local inst_val = instrument_values[track_index] or current_selected_instrument  -- Use current instrument instead of 0
  local vol_val = volume_values[track_index] or 127  -- Default to 127 instead of 100
  
  print("Track " .. track_index .. " values: Note=" .. note_val .. ", Inst=" .. inst_val .. ", Vol=" .. vol_val)
  print("Current selected instrument: " .. current_selected_instrument)
  
  -- Get instrument count for capping instrument valuebox
  local max_instrument = song and #song.instruments or 127  -- 1-based max
  
  -- Note value box
  local note_valuebox = vb:valuebox {
    min = 0,
    max = 119,  -- B-9 is the maximum note value in Renoise
    width = VALUEBOX_WIDTH,
    height = CHECKBOX_SIZE,
    value = math.min(119, math.max(0, note_val)),
    tooltip = "Note value for this track (0-119, C-0 to B-9)",
    tostring = function(value)
      return note_names[value + 1] or ("Note " .. value)  -- Fallback if note_names doesn't have the value
    end,
    tonumber = function(text)
      for i, name in ipairs(note_names) do
        if text == name then
          return i - 1
        end
      end
      return note_values[track_index] or current_note
    end,
    notifier = function(new_value)
      note_values[track_index] = new_value
      -- Update all active notes in the track
      for line_idx = 1, pattern.number_of_lines do
        local note_column = pattern:track(track_index):line(line_idx):note_column(1)
        if not note_column.is_empty then
          note_column.note_value = new_value
        end
      end
      local note_name = note_names[new_value + 1] or ("Note " .. new_value)
      print("Track " .. track_index .. " note changed to: " .. note_name)
    end
  }
  
  -- Instrument value box
  local instrument_valuebox = vb:valuebox {
    min = 1,
    max = max_instrument,
    width = VALUEBOX_WIDTH,
    height = CHECKBOX_SIZE,
    value = math.min(max_instrument, math.max(1, (inst_val or current_selected_instrument) + 1)),  -- Convert to 1-based and clamp to valid range
    tooltip = "Instrument number for this track (1-" .. max_instrument .. ")",
    notifier = function(new_value)
      instrument_values[track_index] = new_value - 1  -- Convert back to 0-based for internal storage
      -- Update all active notes in the track
      for line_idx = 1, pattern.number_of_lines do
        local note_column = pattern:track(track_index):line(line_idx):note_column(1)
        if not note_column.is_empty then
          note_column.instrument_value = new_value - 1  -- Renoise uses 0-based internally
        end
      end
      print("Track " .. track_index .. " instrument changed to: " .. new_value .. " (internal: " .. (new_value - 1) .. ")")
    end
  }

  -- Volume value box
  local volume_valuebox = vb:valuebox {
    min = 0,
    max = 127,
    width = VALUEBOX_WIDTH,
    height = CHECKBOX_SIZE,
    value = math.min(127, math.max(0, vol_val)),
    tooltip = "Volume level for this track (0-127)",
    notifier = function(new_value)
      volume_values[track_index] = new_value
      -- Update all active notes in the track
      for line_idx = 1, pattern.number_of_lines do
        local note_column = pattern:track(track_index):line(line_idx):note_column(1)
        if not note_column.is_empty then
          note_column.volume_value = new_value
        end
      end
      print("Track " .. track_index .. " volume changed to: " .. new_value)
    end
  }

  row:add_child(note_valuebox)
  row:add_child(instrument_valuebox) 
  row:add_child(volume_valuebox)
end

-- Create step checkboxes for pattern sequencing
local function createStepCheckboxes(row, pattern, track_index)
  local checkboxes = {}

  for i = 1, STEP_COUNT do
    local key = track_index * STEP_COUNT + i
    local switch_state = switch_states[key] or false
    
    local checkbox = vb:checkbox {
      width = CHECKBOX_SIZE,
      height = CHECKBOX_SIZE,
      value = switch_state,
      tooltip = "Step " .. i .. " - Click to toggle note on/off",
      notifier = function(checked)
        switch_states[key] = checked
        
        local line = pattern:track(track_index):line(i)
        local note_column = line:note_column(1)
        
        if checked then
          -- Place note with current track settings
          local song = renoise.song()
          local current_selected_instrument = song and (song.selected_instrument_index - 1) or 0
          note_column.note_value = note_values[track_index] or current_note
          note_column.instrument_value = instrument_values[track_index] or current_selected_instrument
          note_column.volume_value = volume_values[track_index] or 127
          
          print("Step " .. i .. " activated on track " .. track_index .. 
                " - Note: " .. note_names[(note_values[track_index] or current_note) + 1] ..
                ", Instrument: " .. (instrument_values[track_index] or 0) ..
                ", Volume: " .. (volume_values[track_index] or 127))
        else
          -- Clear note
          note_column.note_string = ""
          note_column.instrument_string = ""
          note_column.volume_string = ""
          
          print("Step " .. i .. " deactivated on track " .. track_index)
        end
        
        -- Matrix will update automatically via its own timer (if running)
      end
    }
    
    checkboxes[i] = checkbox
    row:add_child(checkbox)
    
    -- Store checkbox reference globally for Clear All functionality
    all_checkboxes[key] = checkbox
  end
  
  return checkboxes
end

-- Create delete button for track
local function createDeleteButton(row, pattern, track_index, checkboxes)
  local delete_button = vb:button {
    width = 60,
    height = CHECKBOX_SIZE,  -- Match checkbox height
    text = "Clear",
    tooltip = "Clear all notes from this track",
    pressed = function()
      -- Clear all notes in the track
      for line_idx = 1, pattern.number_of_lines do
        local note_column = pattern:track(track_index):line(line_idx):note_column(1)
        note_column.note_string = ""
        note_column.instrument_string = ""
        note_column.volume_string = ""
      end
      
      -- Turn off all checkboxes
      for i = 1, STEP_COUNT do
        if checkboxes[i] then
          checkboxes[i].value = false
          switch_states[track_index * STEP_COUNT + i] = false
        end
      end
      
      print("Track " .. track_index .. " cleared")
    end
  }

  row:add_child(delete_button)
end

-- Create a complete row for one track
local function createTrackRow(pattern, track_index)
  if renoise.song() == nil then return nil end
  local track = renoise.song():track(track_index)
  
  local row = vb:row {
    --spacing = ROW_SPACING  -- Match header row spacing exactly
  }

  -- Track label with consistent width
  local track_label = vb:text {
    text = string.format("T%02d", track_index),  -- T01, T02, T10, etc.
    width = 30,  -- Increased width for double digits
    font = "bold",
    style="strong",
    align = "center"

  }
  row:add_child(track_label)

  -- Control boxes (note, instrument, volume)
  createControlBoxes(row, pattern, track_index)
  
  -- Step checkboxes
  local checkboxes = createStepCheckboxes(row, pattern, track_index)
  
  -- Delete button
  createDeleteButton(row, pattern, track_index, checkboxes)

  return row
end

-- Main Dialog Creation
----------------------

-- Create the main step sequencer dialog
function createStepSequencerDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  if renoise.song() == nil then 
    print("No song loaded - cannot create Step Sequencer")
    return 
  end
  local song = renoise.song()
  if song == nil then
    print("Song is nil - cannot create Step Sequencer")
    return
  end
  local pattern = song.patterns[song.selected_pattern_index]
  
  print("Creating Step Sequencer for pattern " .. song.selected_pattern_index)
  
  -- Clear global checkbox storage for new dialog
  all_checkboxes = {}
  
  -- Initialize track values from existing pattern data
  for track_index = 1, #song.tracks do
    if song:track(track_index).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      initializeTrackValues(pattern, track_index)
    end
  end

  -- Create main dialog container
  local dialog_content = vb:vertical_aligner {
    --spacing = 2,
    margin = 10
  }

  -- Add step count controls at the top
  local step_controls = vb:row {
    spacing = 10,
    vb:button {
      text = "Fetch Pattern Data",
      width = 150,
      height = BUTTON_HEIGHT,
      tooltip = "Reload pattern data and update all checkboxes to match current pattern",
      pressed = function()
        print("Fetching pattern data...")
        
        -- Clear existing data
        instrument_values = {}
        volume_values = {}
        note_values = {}
        switch_states = {}
        
        -- Reload pattern data for all tracks
        for track_index = 1, #song.tracks do
          if song:track(track_index).type == renoise.Track.TRACK_TYPE_SEQUENCER then
            initializeTrackValues(pattern, track_index)
          end
        end
        
        -- Update all checkboxes to match the reloaded data
        for key, checkbox in pairs(all_checkboxes) do
          if switch_states[key] ~= nil then
            checkbox.value = switch_states[key]
          end
        end
        
        print("Pattern data fetched and UI updated")
      end
    },
    vb:text { text = "Steps", font = "bold", style = "strong" },
    vb:button {
      text = "16",
      width = 40,
      height = BUTTON_HEIGHT,
      color = STEP_COUNT == 16 and {0x22 / 255, 0xaa / 255, 0xff / 255} or nil,
      pressed = function()
        STEP_COUNT = 16
        if dialog then
          dialog:close()  -- Close the current dialog first
        end
        createStepSequencerDialog()  -- Recreate dialog with new step count
      end
    },
    vb:button {
      text = "32",
      width = 40,
      height = BUTTON_HEIGHT,
      color = STEP_COUNT == 32 and {0x22 / 255, 0xaa / 255, 0xff / 255} or nil,
      pressed = function()
        STEP_COUNT = 32
        if dialog then
          dialog:close()  -- Close the current dialog first
        end
        createStepSequencerDialog()  -- Recreate dialog with new step count
      end
    }
  }
  dialog_content:add_child(step_controls)
  dialog_content:add_child(vb:space { height = 10 })

  -- Add Pattern Overview
  dialog_content:add_child(vb:text { text = "Current Pattern Overview", font = "bold", style = "strong" })
  
  -- Create matrix overview grid
  local matrix_container = vb:column {
    height = 50,  -- Smaller height since we only show current pattern
    style = "group",
    margin = 3
  }
  local matrix_content = createMatrixGrid(song)
  if matrix_content then
    matrix_container:add_child(matrix_content)
  end
  dialog_content:add_child(matrix_container)
  
  -- Add separator before step sequencer
  dialog_content:add_child(vb:space { height = 10 })

  -- Create single group that contains header and all tracks together
  local sequencer_group = vb:column {
    --spacing = 1,
    --margin = 3,
    style = "group"  -- Use group style instead of panel
  }

  -- Add header inside the group
  local header = vb:horizontal_aligner {
    vb:space {},  -- This pushes everything to the sides
    vb:text { text = "Pattern: " .. song.selected_pattern_index, style="strong", font="bold" }
  }
  sequencer_group:add_child(header)
  sequencer_group:add_child(vb:space { height = 5 })

  -- Create a proper grid structure where header and tracks are all rows in the same container
  local track_count = 0
  
  -- First, add the header row
  local column_header = vb:row {
    --spacing = ROW_SPACING,  -- Match track row spacing exactly
    --style="panel"
  }
  
  -- Track label spacer
  column_header:add_child(vb:text { text = "Trk", width = 30, height = CHECKBOX_SIZE, font = "bold", style = "strong", align = "center" })
  
  -- Column labels
  column_header:add_child(vb:text { text = "Note", width = VALUEBOX_WIDTH, height = CHECKBOX_SIZE, font = "bold", style = "strong", align = "center" })
  column_header:add_child(vb:text { text = "Instr.", width = VALUEBOX_WIDTH, height = CHECKBOX_SIZE, font = "bold", style = "strong", align = "center" })
  column_header:add_child(vb:text { text = "Vel.", width = VALUEBOX_WIDTH, height = CHECKBOX_SIZE, font = "bold", style = "strong", align = "center" })
  
  -- Step buttons (01-XX based on STEP_COUNT)
  local normal_color, highlight_color = nil, {0x22 / 255, 0xaa / 255, 0xff / 255}
  
  for i = 1, STEP_COUNT do
    local is_highlight = (i % 4 == 1)  -- Highlight every 4th step: 1, 5, 9, 13, 17, 21, 25, 29...
    
    column_header:add_child(vb:button {
      text = string.format("%02d", i),
      width = CHECKBOX_SIZE,
      height = CHECKBOX_SIZE,
      color = is_highlight and highlight_color or normal_color,
      tooltip = "Step " .. i,
      active = true,  -- Make buttons active
      pressed = function()
        -- Optional: Could add functionality here later
      end
    })
  end
  
  -- Clear All button
  column_header:add_child(vb:button {
    text = "Clear All",
    width = 60,
    height = CHECKBOX_SIZE,  -- Match checkbox height
    tooltip = "Clear all notes from all tracks",
    pressed = function()
      -- Clear all tracks
      for track_index, track in ipairs(song.tracks) do
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          -- Clear all notes in the track
          for line_idx = 1, pattern.number_of_lines do
            local note_column = pattern:track(track_index):line(line_idx):note_column(1)
            note_column.note_string = ""
            note_column.instrument_string = ""
            note_column.volume_string = ""
          end
          -- Clear switch states for this track and update checkboxes
          for i = 1, STEP_COUNT do
            local key = track_index * STEP_COUNT + i
            switch_states[key] = false
            -- Update the actual checkbox in the UI
            if all_checkboxes[key] then
              all_checkboxes[key].value = false
            end
          end
        end
      end
      print("All tracks cleared")
    end
  })
  
  sequencer_group:add_child(column_header)

  -- Then add all track rows to the same group (they're all rows in the same container now)
  for track_index, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local track_row = createTrackRow(pattern, track_index)
      sequencer_group:add_child(track_row)  -- Same container as header
      track_count = track_count + 1
    end
  end

  if track_count == 0 then
    sequencer_group:add_child(vb:text { text = "No sequencer tracks found!" })
  else
    print("Created interface for " .. track_count .. " sequencer tracks")
  end

  dialog_content:add_child(sequencer_group)

  -- Show the dialog
  local dialog_title = "Hotelsinus Step Sequencer - " .. track_count .. " Tracks"
  -- Create keyhandler that can manage dialog variable
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog(dialog_title, dialog_content, keyhandler)
  local result = dialog

  if result then
    print("Step Sequencer dialog confirmed")
  else
    print("Step Sequencer dialog closed")
  end
end

-- Matrix Overview Functions
-- Shows which tracks have data across all patterns in the song

-- Global storage for matrix grid container
local matrix_grid_container = nil

-- Global references for UI elements that need updating
local matrix_pattern_label = nil
local matrix_track_bitmaps = {}

-- Function to refresh the current pattern matrix
function refreshMatrixView()
  if renoise.song() == nil or not matrix_track_bitmaps then return end
  
  local song = renoise.song()
  local current_pattern_index = song.selected_pattern_index
  local pattern = song:pattern(current_pattern_index)
  
  -- Update pattern label
  if matrix_pattern_label then
    matrix_pattern_label.text = "P" .. string.format("%02d", current_pattern_index)
  end
  
  -- Update each track bitmap
  for track_index, bitmap in pairs(matrix_track_bitmaps) do
    if track_index <= #song.tracks and song:track(track_index).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local track_has_data = false
      
      -- Check if track has data
      for line_index, line in ipairs(pattern:track(track_index).lines) do
        local line_empty = true
        for _, note_column in ipairs(line.note_columns) do
          if not note_column.is_empty then
            line_empty = false
            break
          end
        end
        if not line_empty then
          track_has_data = true
          break
        end
      end
      
      -- Update bitmap
      local new_bitmap = track_has_data and "hotelsinus_stepseq/default_8x8.png" or "hotelsinus_stepseq/default_8x8_none.png"
      bitmap.bitmap = new_bitmap
      
      -- Update tooltip
      local track_name = song:track(track_index).name
      bitmap.tooltip = "Pattern " .. current_pattern_index .. ", Track " .. track_index .. " (" .. track_name .. ")"
    end
  end
end

-- Create matrix grid component for CURRENT PATTERN ONLY
function createMatrixGrid(song)
  if song == nil then 
    return nil
  end
  
  -- Get current pattern only
  local pattern = song:pattern(song.selected_pattern_index)
  
  -- Create header row with track labels
  local header_row = vb:row {
    spacing = 1
  }
  
  header_row:add_child(vb:text { text = "Track", width = 40, font = "bold", align = "center" })
  
  -- Only show headers for sequencer tracks
  for track_index, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      header_row:add_child(vb:text {
        text = tostring(track_index),
        width = 10,
        font = "mono",
        align = "center",
        tooltip = "Track " .. track_index .. " (" .. track.name .. ")"
      })
    end
  end
  
  -- Create data row for current pattern
  local data_row = vb:row {
    spacing = 1
  }
  
  -- Add pattern label (store reference for updates)
  matrix_pattern_label = vb:text {
    text = "P" .. string.format("%02d", song.selected_pattern_index),
    width = 40,
    font = "mono",
    align = "center"
  }
  data_row:add_child(matrix_pattern_label)
  
  -- Initialize storage
  matrix_track_bitmaps = {}
  
  -- Check each track for data (only sequencer tracks)
  for track_index, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local track_has_data = false
      local track_bitmap = "hotelsinus_stepseq/default_8x8_none.png"

      for line_index, line in ipairs(pattern:track(track_index).lines) do
        local line_empty = true
        for _, note_column in ipairs(line.note_columns) do
          if not note_column.is_empty then
            line_empty = false
            break
          end
        end
        if not line_empty then
          track_has_data = true
          track_bitmap = "hotelsinus_stepseq/default_8x8.png"
          break
        end
      end

      -- Create bitmap element
      local bitmap_element = vb:bitmap {
        bitmap = track_bitmap,
        width = 8,
        height = 8,
        tooltip = "Pattern " .. song.selected_pattern_index .. ", Track " .. track_index .. " (" .. track.name .. ")"
      }

      -- Store bitmap reference for updates
      matrix_track_bitmaps[track_index] = bitmap_element

      -- Add bitmap with container for consistent spacing
      local bitmap_container = vb:horizontal_aligner {
        width = 10,
        bitmap_element
      }
      data_row:add_child(bitmap_container)
    end
  end

  -- Create simple matrix area
  local matrix_content = vb:column {
    spacing = 2,
    header_row,
    data_row
  }

  return matrix_content
end

-- Global reference for standalone matrix dialog
local matrix_dialog = nil
local matrix_update_timer = nil
local current_pattern_index = nil

-- Create the standalone matrix overview dialog (for menu/keybinding)
function createMatrixOverview()
  -- Close existing dialog if open
  if matrix_dialog and matrix_dialog.visible then
    matrix_dialog:close()
    matrix_dialog = nil
  end
  
  if renoise.song() == nil then 
    return 
  end
  
  local song = renoise.song()
  local dialog_title = "Current Pattern Overview"
  
  -- Initialize current pattern tracking
  current_pattern_index = song.selected_pattern_index
  
  -- Create container for the matrix grid that can be rebuilt
  matrix_grid_container = vb:column {
    margin = 3
  }
  
  -- Initialize the grid
  local initial_grid = createMatrixGrid(song)
  if initial_grid then
    matrix_grid_container:add_child(initial_grid)
  end

  local dialog_content = vb:column {
    margin = 10,
    matrix_grid_container
  }

  -- Simple update function that just refreshes the UI
  local function updateMatrix()
    if not matrix_dialog or not matrix_dialog.visible then return end
    if not renoise.song() then return end
    
    local new_pattern_index = renoise.song().selected_pattern_index
    
    -- Update current pattern tracking
    current_pattern_index = new_pattern_index
    
    -- Just refresh the existing UI - it handles pattern changes automatically
    refreshMatrixView()
  end

  -- Display window
  local keyhandler = create_keyhandler_for_dialog(
    function() return matrix_dialog end,
    function(value) 
      matrix_dialog = value 
      if not value then
        -- Dialog closed, stop timer and clear references
        if matrix_update_timer then
          matrix_update_timer:stop()
          matrix_update_timer = nil
        end
        
                 -- Clear global matrix references
         matrix_grid_container = nil
         matrix_track_bitmaps = {}
         matrix_pattern_label = nil
         current_pattern_index = nil
      end
    end
  )
  
  matrix_dialog = renoise.app():show_custom_dialog(dialog_title, dialog_content, keyhandler)
  
  -- Start timer after dialog is created
  if matrix_dialog then
    matrix_update_timer = renoise.tool():add_timer(updateMatrix, 250)
  end
  
  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Hotelsinus Matrix Overview",invoke = function() createMatrixOverview() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Hotelsinus Step Sequencer",invoke = function() createStepSequencerDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Hotelsinus Matrix Overview", invoke = function() createMatrixOverview() end}
renoise.tool():add_keybinding{name="Global:Paketti:Hotelsinus Step Sequencer",invoke=function() createStepSequencerDialog() end}
