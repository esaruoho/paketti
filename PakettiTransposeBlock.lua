-- PakettiTransposeBlock.lua
-- Experimental feature to transpose different blocks/sections of a pattern independently

-- Local storage for transpose block settings per track/pattern
local paketti_transpose_blocks = {}

local dialog = nil
local dialog_content = nil
local current_num_blocks = 2
local valueboxes = {}
local lastrows_valueboxes = {}
local block_rows = {}

-- Helper function to get unique key for current track/pattern
function get_transpose_block_key()
  local song = renoise.song()
  return string.format("track_%d_pattern_%d", song.selected_track_index, song.selected_pattern_index)
end

-- Get stored transpose values for current track/pattern
function get_stored_transpose_blocks(num_blocks)
  local key = get_transpose_block_key()
  if not paketti_transpose_blocks[key] then
    paketti_transpose_blocks[key] = {
      main = {},
      lastrows = {}
    }
  end
  
  -- Initialize with zeros if not set or wrong number of blocks
  if #paketti_transpose_blocks[key].main ~= num_blocks then
    paketti_transpose_blocks[key].main = {}
    paketti_transpose_blocks[key].lastrows = {}
    for i = 1, num_blocks do
      paketti_transpose_blocks[key].main[i] = 0
      paketti_transpose_blocks[key].lastrows[i] = 0
    end
  end
  
  return paketti_transpose_blocks[key]
end

-- Store transpose values for current track/pattern
function store_transpose_blocks(main_values, lastrows_values)
  local key = get_transpose_block_key()
  paketti_transpose_blocks[key] = {
    main = main_values,
    lastrows = lastrows_values
  }
end

-- Keep track of currently applied transpositions
local current_applied_main = {}
local current_applied_lastrows = {}



-- Apply transpose to a specific block of lines
function apply_transpose_to_block(start_line, end_line, transpose_amount)
  if transpose_amount == 0 then return end
  
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  
  print(string.format("Applying transpose %+d to lines %d-%d", transpose_amount, start_line, end_line))
  
  for line_idx = start_line, end_line do
    if line_idx <= pattern.number_of_lines then
      local line = track:line(line_idx)
      for _, note_column in ipairs(line.note_columns) do
        if not note_column.is_empty and note_column.note_value >= 0 and note_column.note_value <= 119 then
          local new_note = note_column.note_value + transpose_amount
          -- Clamp to valid MIDI note range (0-119)
          new_note = math.max(0, math.min(119, new_note))
          note_column.note_value = new_note
        end
      end
    end
  end
end

-- Apply all transpose blocks to the pattern
function apply_transpose_blocks()
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local pattern_length = pattern.number_of_lines
  local block_size = math.floor(pattern_length / current_num_blocks)
  
  -- Determine how many rows to use for "last rows" effect based on pattern length
  local lastrows_count = pattern_length <= 32 and 2 or 4
  
  -- Initialize current_applied arrays if needed
  if #current_applied_main == 0 then
    for i = 1, current_num_blocks do
      current_applied_main[i] = 0
      current_applied_lastrows[i] = 0
    end
  end
  
  -- Get new transpose values from valueboxes
  local new_main_values = {}
  local new_lastrows_values = {}
  for i = 1, current_num_blocks do
    new_main_values[i] = valueboxes[i].value
    new_lastrows_values[i] = lastrows_valueboxes[i].value
  end
  
  print(string.format("Applying transpose blocks: %d blocks, pattern length: %d, last rows: %d", current_num_blocks, pattern_length, lastrows_count))
  
  -- Process each block
  for block_idx = 1, current_num_blocks do
    local start_line = (block_idx - 1) * block_size + 1
    local end_line
    if block_idx == current_num_blocks then
      -- Last block gets any remaining lines
      end_line = pattern_length
    else
      end_line = block_idx * block_size
    end
    
    -- Calculate the difference between current and new transpose values
    local main_diff = new_main_values[block_idx] - current_applied_main[block_idx]
    local lastrows_diff = new_lastrows_values[block_idx] - current_applied_lastrows[block_idx]
    
    -- Apply main transpose difference to entire block
    if main_diff ~= 0 then
      apply_transpose_to_block(start_line, end_line, main_diff)
    end
    
    -- Apply lastrows transpose difference to last rows of this block
    if lastrows_diff ~= 0 then
      local lastrows_start = math.max(start_line, end_line - lastrows_count + 1)
      apply_transpose_to_block(lastrows_start, end_line, lastrows_diff)
    end
  end
  
  -- Update tracking arrays
  for i = 1, current_num_blocks do
    current_applied_main[i] = new_main_values[i]
    current_applied_lastrows[i] = new_lastrows_values[i]
  end
  
  -- Store the values for recall
  store_transpose_blocks(new_main_values, new_lastrows_values)
  
  renoise.app():show_status(string.format("Applied transpose blocks (%d blocks) to track %d", current_num_blocks, song.selected_track_index))
end

-- Reset all transpose values to 0
function reset_transpose_blocks()
  for i = 1, current_num_blocks do
    if valueboxes[i] then
      valueboxes[i].value = 0
    end
    if lastrows_valueboxes[i] then
      lastrows_valueboxes[i].value = 0
    end
  end
  -- Reset applied transpose tracking
  for i = 1, current_num_blocks do
    current_applied_main[i] = 0
    current_applied_lastrows[i] = 0
  end
  renoise.app():show_status("Reset all transpose blocks to 0")
end

-- Set all notes in the track to C-4 (note value 48) and reset all transpose blocks to 0
function set_all_notes_to_c4()
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  
  local note_count = 0
  
  for line_idx = 1, pattern.number_of_lines do
    local line = track:line(line_idx)
    for _, note_column in ipairs(line.note_columns) do
      if not note_column.is_empty and note_column.note_value >= 0 and note_column.note_value <= 119 then
        note_column.note_value = 48  -- C-4
        note_count = note_count + 1
      end
    end
  end
  
  -- Reset all transpose block values to 0
  for i = 1, current_num_blocks do
    if valueboxes[i] then
      valueboxes[i].value = 0
    end
    if lastrows_valueboxes[i] then
      lastrows_valueboxes[i].value = 0
    end
  end
  
  -- Reset applied transpose tracking since we're starting fresh
  for i = 1, current_num_blocks do
    current_applied_main[i] = 0
    current_applied_lastrows[i] = 0
  end
  
  renoise.app():show_status(string.format("Set %d notes to C-4 and reset all transpose blocks to 0", note_count))
  print(string.format("Set %d notes to C-4, reset transpose blocks", note_count))
end

-- Update valuebox visibility based on number of blocks
function update_valuebox_visibility()
  for i = 1, 8 do -- Maximum 8 blocks
    if block_rows[i] then
      block_rows[i].visible = (i <= current_num_blocks)
    end
  end
end

-- Handle number of blocks change
function on_num_blocks_changed(value)
  -- value: 1=2 blocks, 2=4 blocks, 3=8 blocks
  current_num_blocks = value == 1 and 2 or (value == 2 and 4 or 8)
  
  -- Reset applied transpose tracking when changing block configuration
  current_applied_main = {}
  current_applied_lastrows = {}
  for i = 1, current_num_blocks do
    current_applied_main[i] = 0
    current_applied_lastrows[i] = 0
  end
  
  -- Load stored values for new block count
  local stored_values = get_stored_transpose_blocks(current_num_blocks)
  for i = 1, current_num_blocks do
    if valueboxes[i] then
      valueboxes[i].value = stored_values.main[i]
    end
    if lastrows_valueboxes[i] then
      lastrows_valueboxes[i].value = stored_values.lastrows[i]
    end
  end
  
  -- Update visibility
  update_valuebox_visibility()
  
  -- Apply the stored transpositions for the new block configuration
  apply_transpose_blocks()
  
  print(string.format("Changed to %d blocks", current_num_blocks))
end

-- Show the transpose block dialog
function show_transpose_block_dialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end
  
  local song = renoise.song()
  local selected_track = song.selected_track
  
  -- Check if selected track is a sequencer track (contains note data)
  if selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    local track_type_name = ""
    if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
      track_type_name = "Group"
    elseif selected_track.type == renoise.Track.TRACK_TYPE_SEND then
      track_type_name = "Send"
    elseif selected_track.type == renoise.Track.TRACK_TYPE_MASTER then
      track_type_name = "Master"
    else
      track_type_name = "Non-sequencer"
    end
    
    renoise.app():show_status(string.format("Transpose Blocks: Cannot transpose %s track - select a Sequencer track instead", track_type_name))
    return
  end
  
  local vb = renoise.ViewBuilder()
  local pattern = song:pattern(song.selected_pattern_index)
  
  -- Initialize tracking arrays for this session
  current_applied_main = {}
  current_applied_lastrows = {}
  for i = 1, current_num_blocks do
    current_applied_main[i] = 0
    current_applied_lastrows[i] = 0
  end
  
  -- Initialize with stored values
  local stored_values = get_stored_transpose_blocks(current_num_blocks)
  
  -- Determine how many rows for "last rows" effect based on pattern length
  local lastrows_count = pattern.number_of_lines <= 32 and 2 or 4
  
  -- Create valueboxes (max 8 for flexibility)
  valueboxes = {}
  lastrows_valueboxes = {}
  block_rows = {}
  
  for i = 1, 8 do
    valueboxes[i] = vb:valuebox {
      min = -48,
      max = 48,
      value = i <= current_num_blocks and stored_values.main[i] or 0,
      width = 50,
      notifier = function()
        apply_transpose_blocks()
      end
    }
    
    lastrows_valueboxes[i] = vb:valuebox {
      min = -48,
      max = 48,
      value = i <= current_num_blocks and stored_values.lastrows[i] or 0,
      width = 50,
      notifier = function()
        apply_transpose_blocks()
      end
    }
    
    block_rows[i] = vb:row {
      visible = (i <= current_num_blocks),
      spacing = 5,
      vb:text { text = string.format("Block %d:", i), width = 60 },
      valueboxes[i],
      vb:text { text = "semitones", width = 60 },
      lastrows_valueboxes[i],
      vb:text { text = string.format("last %d", lastrows_count), width = 40 }
    }
  end
  
  dialog_content = vb:column {
    margin = 10,
    

    
    vb:text { 
      text = string.format("Pattern: %d, Track: %d (%s), Length: %d lines", 
        song.selected_pattern_index, 
        song.selected_track_index, 
        song.selected_track.name,
        pattern.number_of_lines)
    },
    
    vb:row {
      vb:text { text = "Number of blocks:" },
      vb:switch {
        items = {"2", "4", "8"},
        value = current_num_blocks == 2 and 1 or (current_num_blocks == 4 and 2 or 3),
        width = 120,
        notifier = on_num_blocks_changed
      }
    },
    
    vb:text { text = "Transpose values:" },
    
    -- Add all block rows
    block_rows[1],
    block_rows[2], 
    block_rows[3],
    block_rows[4],
    block_rows[5],
    block_rows[6],
    block_rows[7],
    block_rows[8],
    
    vb:text { 
      text = "Note: Always works on current pattern state. Only affects notes 0-119.",
      style = "disabled"
    },
    
    vb:text { 
      text = string.format("Last rows effect uses %d rows per block (pattern length: %d)", 
        pattern.number_of_lines <= 32 and 2 or 4, pattern.number_of_lines),
      style = "disabled"
    },
    
    -- Buttons
    vb:horizontal_aligner {
      mode = "justify",
      vb:button {
        text = "Apply",
        width = 80,
        notifier = apply_transpose_blocks
      },
      vb:button {
        text = "Reset",
        width = 60,
        notifier = reset_transpose_blocks
      },
      vb:button {
        text = "All → C-4",
        width = 70,
        notifier = set_all_notes_to_c4
      },
      vb:button {
        text = "Remove All",
        width = 80,
        notifier = function()
          -- Set all valueboxes to 0 to remove all transpositions
          for i = 1, current_num_blocks do
            if valueboxes[i] then
              valueboxes[i].value = 0
            end
            if lastrows_valueboxes[i] then
              lastrows_valueboxes[i].value = 0
            end
          end
          renoise.app():show_status("Removed all transpositions")
        end
      },
      vb:button {
        text = "Close",
        width = 60,
        notifier = function()
          if dialog then
            dialog:close()
            dialog = nil
          end
        end
      }
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Paketti Transpose Blocks", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

renoise.tool():add_menu_entry {name = "Pattern Editor:Paketti Gadgets:Transpose Blocks Dialog...",invoke = show_transpose_block_dialog}
renoise.tool():add_menu_entry {name = "Mixer:Paketti GadgetsTranspose Blocks Dialog...",invoke = show_transpose_block_dialog}
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti:Xperimental/WIP:Transpose Blocks Dialog...",invoke = show_transpose_block_dialog}
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti Gadgets:Transpose Blocks Dialog...",invoke = show_transpose_block_dialog}
renoise.tool():add_keybinding {name = "Pattern Editor:Paketti:Transpose Blocks Dialog...",invoke = show_transpose_block_dialog}
renoise.tool():add_keybinding {name = "Mixer:Paketti:Transpose Blocks Dialog...",invoke = show_transpose_block_dialog}
renoise.tool():add_keybinding {name = "Global:Paketti:Transpose Blocks Dialog...",invoke = show_transpose_block_dialog}