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
local function show_sub_column_status()
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


renoise.tool():add_midi_mapping{name="Paketti:Sub Column Command Absolute Control",invoke = handle_absolute_command}
renoise.tool():add_midi_mapping{name="Paketti:Sub Column Command Relative Control",invoke = handle_relative_command}
renoise.tool():add_midi_mapping{name="Paketti:Sub Column Value Absolute Control",invoke = handle_absolute_value}
renoise.tool():add_midi_mapping{name="Paketti:Sub Column Value Relative Control",invoke = handle_relative_value}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Show Paketti Sub Column Status",invoke = show_sub_column_status}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Paketti Sub Column Status",invoke = show_sub_column_status}