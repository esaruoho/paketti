-- Paketti Sub Column Modifier

-- Constants for sub-column types
local SUB_COLUMN_TYPES = {
  [1] = "Note",
  [2] = "Instrument Number",
  [3] = "Volume",
  [4] = "Panning",
  [5] = "Delay",
  [6] = "Sample Effect Number",
  [7] = "Sample Effect Amount",
  [8] = "Effect Number",
  [9] = "Effect Amount"
}

-- Effect command lists for different column types
local VOLUME_COMMANDS = {
  "G0", "U0", "D0", "I0", "O0", "B0", "Q0", "R0", "Y0", "C0"
}

local PAN_COMMANDS = {
  "G0", "U0", "D0", "J0", "K0", "B0", "Q0", "R0", "Y0", "C0"
}

local SAMPLEFX_COMMANDS = {
  "0A", "0U", "0D", "0G", "0I", "0O", "0C", "0Q", "0M", "0S",
  "0B", "0R", "0Y", "0Z", "0V", "0T", "0N", "0E"
}

local EFFECT_COMMANDS = {
  "0A", "0U", "0D", "0G", "0I", "0O", "0C", "0Q", "0M", "0S",
  "0B", "0R", "0Y", "0Z", "0V", "0T", "0N", "0E", "0L", "0P",
  "0W", "0J", "0X", "ZT", "ZL", "ZK", "ZG", "ZB", "ZD"
}

-- Keep track of current indices for relative mode
local current_indices = {
  volume = 1,
  pan = 1,
  samplefx = 1,
  effect = 1
}

-- Function to get the current sub-column name
local function get_sub_column_name()
  local song=renoise.song()
  local sub_column_type = song.selected_sub_column_type
  return SUB_COLUMN_TYPES[sub_column_type] or "Unknown"
end

-- Function to show current sub-column status
function show_sub_column_status()
  local song=renoise.song()
  local sub_column_type = song.selected_sub_column_type
  local sub_column_name = get_sub_column_name()
  print(string.format("Selected SubColumn is %d (%s)", sub_column_type, sub_column_name))
  renoise.app():show_status(string.format("You are in %s subcolumn (%d)", sub_column_name, sub_column_type))
end

-- Function to write to volume column
local function write_to_volume_column(command)
  local song=renoise.song()
  if not song.selected_note_column then return end
  
  local note_column = song.selected_note_column
  if note_column then
    -- Get existing value to preserve the second character
    local current = note_column.volume_string
    if current == ".." then
      -- If empty, write full command
      note_column.volume_string = command
    else
      -- Preserve second character, replace first with new command
      note_column.volume_string = command:sub(1,1) .. current:sub(2,2)
    end
    print("Writing to volume: " .. note_column.volume_string)
  end
end

-- Function to write to panning column
local function write_to_panning_column(command)
  local song=renoise.song()
  if not song.selected_note_column then return end
  
  local note_column = song.selected_note_column
  if note_column then
    -- Get existing value to preserve the second character
    local current = note_column.panning_string
    if current == ".." then
      -- If empty, write full command
      note_column.panning_string = command
    else
      -- Preserve second character, replace first with new command
      note_column.panning_string = command:sub(1,1) .. current:sub(2,2)
    end
    print("Writing to panning: " .. note_column.panning_string)
  end
end

-- Function to write to sample effect number
local function write_to_sample_effect(command)
  local song=renoise.song()
  if not song.selected_note_column then return end
  
  local note_column = song.selected_note_column
  if not note_column then return end
  
  -- Write to effect_number_string (00-ZZ)
  note_column.effect_number_string = command
  print("Writing to sample effect number: " .. command)
end

-- Function to write sample effect amount (00-FF)
local function write_sample_effect_amount(midi_message)
  local song=renoise.song()
  if not song.selected_note_column then return end
  
  local note_column = song.selected_note_column
  if not note_column then return end
  
  local value
  if midi_message:is_abs_value() then
    -- Map 0-127 to 0-255
    value = math.floor(midi_message.int_value * 255 / 127)
  else
    -- Get current value
    local current = note_column.effect_amount_value
    -- Add relative change (-63 to +63 mapped to full range)
    value = math.max(0, math.min(255, current + midi_message.int_value * 2))
  end
  
  note_column.effect_amount_value = value
  print("Sample effect amount: " .. string.format("%02X", value))
end

-- Function to write to effect column number
local function write_to_effect_column(command)
  local song=renoise.song()
  local effect_column
  
  -- Get the actual pattern line we're writing to
  if song.selected_effect_column then
    effect_column = song.selected_effect_column
  else
    -- If not in effect column, try to write to first effect column
    if song.selected_track.visible_effect_columns > 0 then
      effect_column = song.selected_line:effect_column(1)
    end
  end
  
  if not effect_column then return end
  
  -- Write to number_string (00-ZZ)
  effect_column.number_string = command
  print("Writing to effect number: " .. command)
end

-- Function to write effect column amount (00-FF)
local function write_effect_amount(midi_message)
  local song=renoise.song()
  local effect_column
  
  if song.selected_effect_column then
    effect_column = song.selected_effect_column
  else
    if song.selected_track.visible_effect_columns > 0 then
      effect_column = song.selected_line:effect_column(1)
    end
  end
  
  if not effect_column then return end
  
  local value
  if midi_message:is_abs_value() then
    -- Map 0-127 to 0-255
    value = math.floor(midi_message.int_value * 255 / 127)
  else
    -- Get current value
    local current = effect_column.amount_value
    -- Add relative change (-63 to +63 mapped to full range)
    value = math.max(0, math.min(255, current + midi_message.int_value * 2))
  end
  
  effect_column.amount_value = value
  print("Effect amount: " .. string.format("%02X", value))
end

-- Function to handle MIDI input for commands
local function handle_midi_command(midi_message, is_relative)
  local song=renoise.song()
  local sub_column_type = song.selected_sub_column_type
  
  -- Convert midi_message to number
  local midi_value = midi_message.int_value
  if not midi_value then return end
  
  -- If MIDI value is 0, write ".." to clear the column
  if midi_value == 0 then
    if sub_column_type == 3 then -- Volume
      write_to_volume_column("..")
    elseif sub_column_type == 4 then -- Panning
      write_to_panning_column("..")
    elseif sub_column_type == 6 or sub_column_type == 7 then -- Sample Effect Number
      write_to_sample_effect("..")
    elseif sub_column_type == 8 or sub_column_type == 9 then -- Effect Number
      write_to_effect_column("..")
    end
    return
  end
  
  -- Get the command list and write the command
  local command
  local index
  if sub_column_type == 3 then -- Volume
    index = math.floor((midi_value - 1) * #VOLUME_COMMANDS / 126) + 1
    if index > #VOLUME_COMMANDS then index = #VOLUME_COMMANDS end
    command = VOLUME_COMMANDS[index]
    write_to_volume_column(command)
    
  elseif sub_column_type == 4 then -- Panning
    index = math.floor((midi_value - 1) * #PAN_COMMANDS / 126) + 1
    if index > #PAN_COMMANDS then index = #PAN_COMMANDS end
    command = PAN_COMMANDS[index]
    write_to_panning_column(command)
    
  elseif sub_column_type == 6 or sub_column_type == 7 then -- Sample Effect Number
    index = math.floor((midi_value - 1) * #SAMPLEFX_COMMANDS / 126) + 1
    if index > #SAMPLEFX_COMMANDS then index = #SAMPLEFX_COMMANDS end
    command = SAMPLEFX_COMMANDS[index]
    write_to_sample_effect(command)
    
  elseif sub_column_type == 8 or sub_column_type == 9 then -- Effect Number
    index = math.floor((midi_value - 1) * #EFFECT_COMMANDS / 126) + 1
    if index > #EFFECT_COMMANDS then index = #EFFECT_COMMANDS end
    command = EFFECT_COMMANDS[index]
    write_to_effect_column(command)
  end
  
  if command then
    print("MIDI " .. midi_value .. " -> index " .. index .. " -> command " .. command)
  end
end

-- Function to write values to any column type
local function write_value(midi_message)
  local song=renoise.song()
  local sub_column_type = song.selected_sub_column_type
  
  -- Handle note column values (volume, panning)
  if sub_column_type == 3 or sub_column_type == 4 then -- Volume or Panning
    if not song.selected_note_column then return end
    local note_column = song.selected_note_column
    
    local value
    if midi_message:is_abs_value() then
      -- Map 0-127 to 0-15 (0-F)
      value = math.floor(midi_message.int_value * 15 / 127)
    else
      -- Get current value in hex
      local current = sub_column_type == 3 and note_column.volume_string or note_column.panning_string
      local current_hex = current:sub(2,2)
      local current_value = tonumber(current_hex, 16) or 0
      -- Add relative change (-63 to +63 mapped to smaller range)
      value = math.max(0, math.min(15, current_value + midi_message.int_value / 8))
    end
    
    -- If no command exists (empty or ..), write 0 as first digit
    local current = sub_column_type == 3 and note_column.volume_string or note_column.panning_string
    local first_digit = current == ".." and "0" or current:sub(1,1)
    
    -- Write the value
    if sub_column_type == 3 then
      note_column.volume_string = first_digit .. string.format("%X", value)
      print("Volume value: " .. note_column.volume_string)
    else
      note_column.panning_string = first_digit .. string.format("%X", value)
      print("Panning value: " .. note_column.panning_string)
    end
    
  -- Handle sample effect amount - write in both number and amount columns
  elseif sub_column_type == 6 or sub_column_type == 7 then -- Sample Effect Number or Amount
    if not song.selected_note_column then return end
    local note_column = song.selected_note_column
    
    local value
    if midi_message:is_abs_value() then
      -- Map 0-127 to 0-255
      value = math.floor(midi_message.int_value * 255 / 127)
    else
      local current = tonumber(note_column.effect_amount_string, 16) or 0
      value = math.max(0, math.min(255, current + midi_message.int_value * 2))
    end
    
    note_column.effect_amount_string = string.format("%02X", value)
    print("Sample effect amount: " .. note_column.effect_amount_string)
    
  -- Handle effect column amount - write in both number and amount columns
  elseif sub_column_type == 8 or sub_column_type == 9 then -- Effect Number or Amount
    local effect_column = song.selected_effect_column
    if not effect_column and song.selected_track.visible_effect_columns > 0 then
      effect_column = song.selected_line:effect_column(1)
    end
    if not effect_column then return end
    
    local value
    if midi_message:is_abs_value() then
      -- Map 0-127 to 0-255
      value = math.floor(midi_message.int_value * 255 / 127)
    else
      local current = tonumber(effect_column.amount_string, 16) or 0
      value = math.max(0, math.min(255, current + midi_message.int_value * 2))
    end
    
    effect_column.amount_string = string.format("%02X", value)
    print("Effect amount: " .. effect_column.amount_string)
  end
end

local function handle_absolute_command(midi_message)
  handle_midi_command(midi_message, false)
end

local function handle_relative_command(midi_message)
  handle_midi_command(midi_message, true)
end

local function handle_absolute_value(midi_message)
  write_value(midi_message)
end

local function handle_relative_value(midi_message)
  write_value(midi_message)
end


-- Intelligent Write Values System (adapts to subcolumn context)
-- These functions write values based on which subcolumn you're in:
-- - Note subcolumn -> writes notes (delegates to existing writeNotesMethod)
-- - Volume subcolumn -> writes 00-80 (0-128)
-- - Panning subcolumn -> writes 00-80 (0-128)
-- - Delay subcolumn -> writes 00-FF (0-255)
-- - Sample Effect Amount -> writes 00-FF (0-255)
-- - Effect Amount -> writes 00-FF (0-255)

function PakettiSubColumnWriteValues(method, use_editstep)
  local song = renoise.song()
  local sub_column_type = song.selected_sub_column_type
  
  -- If in Note subcolumn, delegate to existing note writing functions
  if sub_column_type == 1 then -- SUB_COLUMN_NOTE
    if use_editstep then
      if type(writeNotesMethodEditStep) == "function" then
        writeNotesMethodEditStep(method)
      else
        renoise.app():show_status("Write Notes EditStep function not available")
      end
    else
      if type(writeNotesMethod) == "function" then
        writeNotesMethod(method)
      else
        renoise.app():show_status("Write Notes function not available")
      end
    end
    return
  end
  
  -- For other subcolumns, write values
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local current_line = song.selected_line_index
  local selected_note_column = song.selected_note_column_index
  local edit_step = use_editstep and song.transport.edit_step or 1
  
  -- If edit_step is 0, treat it as 1
  if edit_step == 0 then
    edit_step = 1
  end
  
  -- Check for selection
  local start_line = current_line
  local end_line = pattern.number_of_lines
  local has_selection = false
  
  if song.selection_in_pattern then
    local selection = song.selection_in_pattern
    -- Only use selection if it's in the current track
    if selection.start_track == song.selected_track_index and 
       selection.end_track == song.selected_track_index then
      start_line = selection.start_line
      end_line = selection.end_line
      has_selection = true
    end
  end
  
  -- Determine value range based on subcolumn type
  local min_value = 0
  local max_value = 255
  local hex_format = "%02X"
  local column_name = "value"
  
  if sub_column_type == 3 then -- Volume
    max_value = 128
    column_name = "volume"
  elseif sub_column_type == 4 then -- Panning
    max_value = 128
    column_name = "panning"
  elseif sub_column_type == 5 then -- Delay
    max_value = 255
    column_name = "delay"
  elseif sub_column_type == 7 then -- Sample Effect Amount
    max_value = 255
    column_name = "sample effect amount"
  elseif sub_column_type == 9 then -- Effect Amount
    max_value = 255
    column_name = "effect amount"
  else
    renoise.app():show_status("Write Values only works in Volume, Panning, Delay, or Effect Amount columns")
    return
  end
  
  -- Create value table
  local values = {}
  for i = min_value, max_value do
    table.insert(values, i)
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    -- Already in ascending order
  elseif method == "descending" then
    local reversed = {}
    for i = #values, 1, -1 do
      table.insert(reversed, values[i])
    end
    values = reversed
  elseif method == "random" then
    -- Fisher-Yates shuffle with extra-random seeding
    -- Combine os.time() and os.clock() for better randomness
    local seed = os.time() + math.floor(os.clock() * 1000000)
    math.randomseed(seed)
    -- Prime the random generator multiple times
    math.random(); math.random(); math.random(); math.random(); math.random()
    for i = #values, 2, -1 do
      local j = math.random(i)
      values[i], values[j] = values[j], values[i]
    end
  end
  
  -- Clear existing values in the selection/range if using editstep
  if use_editstep then
    local clear_line = start_line
    while clear_line <= end_line do
      local note_column = track:line(clear_line):note_column(selected_note_column or 1)
      if sub_column_type == 3 then
        note_column.volume_value = renoise.PatternLine.EMPTY_VOLUME
      elseif sub_column_type == 4 then
        note_column.panning_value = renoise.PatternLine.EMPTY_PANNING
      elseif sub_column_type == 5 then
        note_column.delay_value = renoise.PatternLine.EMPTY_DELAY
      elseif sub_column_type == 7 then
        note_column.effect_amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
      elseif sub_column_type == 9 then
        local effect_column_index = song.selected_effect_column_index
        if effect_column_index and song.selected_track.visible_effect_columns >= effect_column_index then
          local effect_column = track:line(clear_line):effect_column(effect_column_index)
          effect_column.amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
        end
      end
      clear_line = clear_line + edit_step
    end
  end
  
  -- Write the values within the selection
  local write_line = start_line
  local last_value = -1
  local values_written = 0
  
  for i = 1, #values do
    if write_line <= end_line then
      if sub_column_type == 3 then -- Volume
        local note_column = track:line(write_line):note_column(selected_note_column or 1)
        note_column.volume_value = values[i]
        last_value = values[i]
        values_written = values_written + 1
      elseif sub_column_type == 4 then -- Panning
        local note_column = track:line(write_line):note_column(selected_note_column or 1)
        note_column.panning_value = values[i]
        last_value = values[i]
        values_written = values_written + 1
      elseif sub_column_type == 5 then -- Delay
        local note_column = track:line(write_line):note_column(selected_note_column or 1)
        note_column.delay_value = values[i]
        last_value = values[i]
        values_written = values_written + 1
      elseif sub_column_type == 7 then -- Sample Effect Amount
        local note_column = track:line(write_line):note_column(selected_note_column or 1)
        note_column.effect_amount_value = values[i]
        last_value = values[i]
        values_written = values_written + 1
      elseif sub_column_type == 9 then -- Effect Amount
        local effect_column_index = song.selected_effect_column_index
        if effect_column_index and song.selected_track.visible_effect_columns >= effect_column_index then
          local effect_column = track:line(write_line):effect_column(effect_column_index)
          effect_column.amount_value = values[i]
          last_value = values[i]
          values_written = values_written + 1
        end
      end
      
      if use_editstep then
        write_line = write_line + edit_step
      else
        write_line = write_line + 1
      end
    else
      break
    end
  end
  
  if last_value ~= -1 then
    local hex_value = string.format("%02X", last_value)
    local selection_text = has_selection and " (in selection)" or ""
    renoise.app():show_status(string.format(
      "Wrote %d %s %s values from row %d to %d%s (last: %s/%d)", 
      values_written,
      method,
      column_name,
      start_line,
      write_line - (use_editstep and edit_step or 1),
      selection_text,
      hex_value,
      last_value
    ))
  end
end

-- Wrapper functions for different modes
function PakettiSubColumnWriteRandom()
  PakettiSubColumnWriteValues("random", false)
end

function PakettiSubColumnWriteRandomEditStep()
  PakettiSubColumnWriteValues("random", true)
end

function PakettiSubColumnWriteAscending()
  PakettiSubColumnWriteValues("ascending", false)
end

function PakettiSubColumnWriteAscendingEditStep()
  PakettiSubColumnWriteValues("ascending", true)
end

function PakettiSubColumnWriteDescending()
  PakettiSubColumnWriteValues("descending", false)
end

function PakettiSubColumnWriteDescendingEditStep()
  PakettiSubColumnWriteValues("descending", true)
end

renoise.tool():add_midi_mapping{name="Paketti:Sub Column Command Absolute Control",invoke = handle_absolute_command}
renoise.tool():add_midi_mapping{name="Paketti:Sub Column Command Relative Control",invoke = handle_relative_command}
renoise.tool():add_midi_mapping{name="Paketti:Sub Column Value Absolute Control",invoke = handle_absolute_value}
renoise.tool():add_midi_mapping{name="Paketti:Sub Column Value Relative Control",invoke = handle_relative_value}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Paketti Sub Column Status",invoke = show_sub_column_status}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Values/Notes Random (SubColumn Aware)", invoke=PakettiSubColumnWriteRandom}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Values/Notes Random EditStep (SubColumn Aware)", invoke=PakettiSubColumnWriteRandomEditStep}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Values/Notes Ascending (SubColumn Aware)", invoke=PakettiSubColumnWriteAscending}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Values/Notes Ascending EditStep (SubColumn Aware)", invoke=PakettiSubColumnWriteAscendingEditStep}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Values/Notes Descending (SubColumn Aware)", invoke=PakettiSubColumnWriteDescending}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Values/Notes Descending EditStep (SubColumn Aware)", invoke=PakettiSubColumnWriteDescendingEditStep}