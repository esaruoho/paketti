-- PakettiExperimental_BlockLoopFollow.lua
-- Experimental: Block Loop follows Edit Cursor
-- Two approaches:
-- 1. Automatic (polling via idle) - Block loop automatically moves when cursor leaves it
-- 2. Manual (keybinding) - Snap block loop to current cursor position on demand

--------------------------------------------------------------------------------
-- STATE VARIABLES
--------------------------------------------------------------------------------

local block_loop_follow_enabled = false

-- Global function to check if Block Loop Follow is enabled (for use by other modules)
function PakettiBlockLoopFollowIsEnabled()
  return block_loop_follow_enabled
end

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Calculate the current block boundaries based on pattern length and coefficient
local function get_block_boundaries(pattern_length, block_coeff, current_line)
  -- Block size is pattern_length / block_coeff
  local block_size = math.floor(pattern_length / block_coeff)
  if block_size < 1 then block_size = 1 end

  -- Which block is the cursor in? (0-indexed block number)
  local block_index = math.floor((current_line - 1) / block_size)

  -- Calculate start and end lines for this block
  local block_start = (block_index * block_size) + 1
  local block_end = block_start + block_size - 1

  -- Clamp to pattern length
  if block_end > pattern_length then
    block_end = pattern_length
  end

  return block_start, block_end, block_index
end

-- Check if cursor is within current block loop range
local function is_cursor_in_block_loop()
  local song = renoise.song()
  local transport = song.transport

  if not transport.loop_block_enabled then
    return true -- If block loop is off, consider cursor "in range"
  end

  local cursor_line = song.selected_line_index
  local cursor_sequence = song.selected_sequence_index

  local block_start_pos = transport.loop_block_start_pos
  local pattern_index = song.sequencer:pattern(cursor_sequence)
  local pattern = song.patterns[pattern_index]
  local pattern_length = pattern.number_of_lines
  local block_coeff = transport.loop_block_range_coeff

  -- Calculate block size and boundaries
  local block_size = math.floor(pattern_length / block_coeff)
  if block_size < 1 then block_size = 1 end

  local block_start = block_start_pos.line
  local block_end = block_start + block_size - 1
  if block_end > pattern_length then
    block_end = pattern_length
  end

  -- Check if cursor is in the same sequence and within block boundaries
  if cursor_sequence ~= block_start_pos.sequence then
    return false
  end

  return cursor_line >= block_start and cursor_line <= block_end
end

-- Move block loop to contain the cursor position
local function move_block_loop_to_cursor()
  local song = renoise.song()
  local transport = song.transport

  if not transport.loop_block_enabled then
    return
  end

  local cursor_line = song.selected_line_index
  local cursor_sequence = song.selected_sequence_index

  local block_start_pos = transport.loop_block_start_pos
  local pattern_index = song.sequencer:pattern(cursor_sequence)
  local pattern = song.patterns[pattern_index]
  local pattern_length = pattern.number_of_lines
  local block_coeff = transport.loop_block_range_coeff

  -- Calculate which block the cursor should be in
  local _, _, cursor_block_index = get_block_boundaries(pattern_length, block_coeff, cursor_line)

  -- Calculate which block is currently active
  local block_size = math.floor(pattern_length / block_coeff)
  if block_size < 1 then block_size = 1 end
  local current_block_index = math.floor((block_start_pos.line - 1) / block_size)

  -- Handle sequence change: toggle off and on to reset to new pattern
  if cursor_sequence ~= block_start_pos.sequence then
    transport.loop_block_enabled = false
    transport.loop_block_enabled = true
    -- Recalculate after reset
    local new_block_start_pos = transport.loop_block_start_pos
    current_block_index = math.floor((new_block_start_pos.line - 1) / block_size)
  end

  -- Move block loop forward or backward to reach cursor's block
  local moves_needed = cursor_block_index - current_block_index

  if moves_needed > 0 then
    for _ = 1, moves_needed do
      transport:loop_block_move_forwards()
    end
  elseif moves_needed < 0 then
    for _ = 1, math.abs(moves_needed) do
      transport:loop_block_move_backwards()
    end
  end
end

--------------------------------------------------------------------------------
-- VERSION 1: AUTOMATIC (POLLING-BASED) BLOCK LOOP FOLLOW
--------------------------------------------------------------------------------

local function block_loop_follow_idle_handler()
  if not block_loop_follow_enabled then
    return
  end

  -- Wrap in pcall to prevent errors from breaking the notifier
  local success, err = pcall(function()
    local song = renoise.song()
    if not song then return end

    local transport = song.transport
    if not transport.loop_block_enabled then
      return
    end

    -- Always check if cursor is outside current block loop
    -- (removed position-change optimization to catch rapid jumps)
    if not is_cursor_in_block_loop() then
      move_block_loop_to_cursor()
    end
  end)

  if not success then
    -- Silent fail but keep notifier running
    -- Debug: renoise.app():show_status("Block loop follow error: " .. tostring(err))
    _ = err -- suppress unused warning
  end
end

-- Global function to enable Block Loop Follow (called from main.lua on startup)
function PakettiBlockLoopFollowEnable()
  if block_loop_follow_enabled then return end -- Already enabled
  block_loop_follow_enabled = true
  if not renoise.tool().app_idle_observable:has_notifier(block_loop_follow_idle_handler) then
    renoise.tool().app_idle_observable:add_notifier(block_loop_follow_idle_handler)
  end
end

local function toggle_block_loop_follow_auto()
  block_loop_follow_enabled = not block_loop_follow_enabled

  -- Save preference
  preferences.PakettiBlockLoopFollowEnabled.value = block_loop_follow_enabled
  preferences:save_as("preferences.xml")

  if block_loop_follow_enabled then
    -- Add idle notifier if not already added
    if not renoise.tool().app_idle_observable:has_notifier(block_loop_follow_idle_handler) then
      renoise.tool().app_idle_observable:add_notifier(block_loop_follow_idle_handler)
    end
    renoise.app():show_status("Paketti: Block Loop Follow ENABLED - Block loop will follow edit cursor")
  else
    -- Remove idle notifier
    if renoise.tool().app_idle_observable:has_notifier(block_loop_follow_idle_handler) then
      renoise.tool().app_idle_observable:remove_notifier(block_loop_follow_idle_handler)
    end
    renoise.app():show_status("Paketti: Block Loop Follow DISABLED")
  end
end

--------------------------------------------------------------------------------
-- VERSION 2: MANUAL SNAP BLOCK LOOP TO CURSOR
--------------------------------------------------------------------------------

local function snap_block_loop_to_cursor()
  local song = renoise.song()
  local transport = song.transport

  -- If block loop is not enabled, enable it first
  if not transport.loop_block_enabled then
    transport.loop_block_enabled = true
  end

  -- Move block loop to cursor position
  move_block_loop_to_cursor()

  local cursor_line = song.selected_line_index
  renoise.app():show_status(("Paketti: Block loop snapped to cursor (line %d)"):format(cursor_line))
end

-- Toggle block loop and snap: if off, turn on and snap. If on, just snap.
local function toggle_and_snap_block_loop()
  local song = renoise.song()
  local transport = song.transport

  if not transport.loop_block_enabled then
    -- Enable and snap
    transport.loop_block_enabled = true
    move_block_loop_to_cursor()
    renoise.app():show_status("Paketti: Block loop ENABLED and snapped to cursor")
  else
    -- Just snap
    move_block_loop_to_cursor()
    local cursor_line = song.selected_line_index
    renoise.app():show_status(("Paketti: Block loop snapped to line %d"):format(cursor_line))
  end
end

--------------------------------------------------------------------------------
-- INITIALIZATION ON TOOL LOAD
--------------------------------------------------------------------------------

renoise.tool().tool_finished_loading_observable:add_notifier(function()
  -- Read preference and enable Block Loop Follow if it was set to on
  if preferences.PakettiBlockLoopFollowEnabled.value then
    PakettiBlockLoopFollowEnable()
  else
    -- Ensure idle notifier is removed if it was somehow left behind
    if renoise.tool().app_idle_observable:has_notifier(block_loop_follow_idle_handler) then
      renoise.tool().app_idle_observable:remove_notifier(block_loop_follow_idle_handler)
    end
  end
end)

--------------------------------------------------------------------------------
-- MENU ENTRIES
--------------------------------------------------------------------------------

-- Main toggle with checkmark in Options menu
renoise.tool():add_menu_entry{
  name = "Main Menu:Options:Block Loop Follows Edit Cursor Toggle",
  invoke = toggle_block_loop_follow_auto,
  selected = function() return block_loop_follow_enabled end
}

-- Experimental entries for manual control
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Experimental:Block Loop Snap to Cursor (Manual)",
  invoke = snap_block_loop_to_cursor
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Experimental:Block Loop Toggle & Snap to Cursor",
  invoke = toggle_and_snap_block_loop
}

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Global:Paketti:Experimental Block Loop Follow (Auto) Toggle",
  invoke = toggle_block_loop_follow_auto
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Experimental Block Loop Snap to Cursor (Manual)",
  invoke = snap_block_loop_to_cursor
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Experimental Block Loop Toggle & Snap to Cursor",
  invoke = toggle_and_snap_block_loop
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Experimental Block Loop Follow (Auto) Toggle",
  invoke = toggle_block_loop_follow_auto
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Experimental Block Loop Snap to Cursor (Manual)",
  invoke = snap_block_loop_to_cursor
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Experimental Block Loop Toggle & Snap to Cursor",
  invoke = toggle_and_snap_block_loop
}

--------------------------------------------------------------------------------
-- MIDI MAPPINGS
--------------------------------------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:Experimental Block Loop Follow (Auto) Toggle",
  invoke = function(message)
    if message:is_trigger() then
      toggle_block_loop_follow_auto()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Experimental Block Loop Snap to Cursor (Manual)",
  invoke = function(message)
    if message:is_trigger() then
      snap_block_loop_to_cursor()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Experimental Block Loop Toggle & Snap to Cursor",
  invoke = function(message)
    if message:is_trigger() then
      toggle_and_snap_block_loop()
    end
  end
}
