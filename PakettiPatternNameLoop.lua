-- PakettiPatternNameLoop.lua
-- Pattern name-based sequence loop markers
-- Uses [ ] and [] in pattern names to define loop regions
--
-- Pattern name markers:
--   [] = Single pattern loop (start and end on same pattern)
--   [  = Start of multi-pattern loop region
--   ]  = End of multi-pattern loop region
--
-- Example pattern names:
--   "Intro []"           -> Loop just this pattern
--   "Verse ["            -> Start of loop region
--   "Verse 2"            -> Middle of loop region (no marker)
--   "Verse End ]"        -> End of loop region
--   "[Chorus]"           -> Single pattern loop (has both [ and ])
--   "Bridge"             -> Not part of any marked loop

-- Helper function to check if a pattern name contains a loop start marker
-- Returns true if name contains "[" but not "[]" as a single-pattern marker
local function has_loop_start_marker(name)
  if not name or name == "" then
    return false
  end
  -- Check for "[" that is NOT part of "[]"
  -- First, check if it has "[]" - if so, it's a single-pattern loop, not just a start
  if string.find(name, "%[%]") then
    return false
  end
  -- Check for "[" without immediately following "]"
  if string.find(name, "%[") then
    return true
  end
  return false
end

-- Helper function to check if a pattern name contains a loop end marker
-- Returns true if name contains "]" but not "[]" as a single-pattern marker
local function has_loop_end_marker(name)
  if not name or name == "" then
    return false
  end
  -- Check for "[]" - if so, it's a single-pattern loop, not just an end
  if string.find(name, "%[%]") then
    return false
  end
  -- Check for "]" without immediately preceding "["
  if string.find(name, "%]") then
    return true
  end
  return false
end

-- Helper function to check if a pattern name contains a single-pattern loop marker []
local function has_single_loop_marker(name)
  if not name or name == "" then
    return false
  end
  -- Check for "[]" anywhere in the name
  if string.find(name, "%[%]") then
    return true
  end
  -- Also check for patterns like "[Something]" where [ is at start and ] at end
  if string.find(name, "^%[") and string.find(name, "%]$") then
    return true
  end
  return false
end

-- Find all loop regions defined by pattern names
-- Returns a table of loop regions: { {start_seq, end_seq}, ... }
local function find_all_pattern_name_loop_regions()
  local song = renoise.song()
  local sequencer = song.sequencer
  local total_sequences = #sequencer.pattern_sequence
  local regions = {}
  
  local i = 1
  while i <= total_sequences do
    local pattern_index = sequencer.pattern_sequence[i]
    local pattern_name = song.patterns[pattern_index].name
    
    print(string.format("Checking sequence %d, pattern %d, name: '%s'", i, pattern_index, pattern_name))
    
    -- Check for single-pattern loop marker []
    if has_single_loop_marker(pattern_name) then
      print(string.format("  Found single-loop marker [] at sequence %d", i))
      table.insert(regions, {start_seq = i, end_seq = i})
      i = i + 1
    -- Check for loop start marker [
    elseif has_loop_start_marker(pattern_name) then
      print(string.format("  Found loop start marker [ at sequence %d", i))
      local loop_start = i
      local loop_end = nil
      
      -- Search forward for the matching end marker ]
      for j = i + 1, total_sequences do
        local end_pattern_index = sequencer.pattern_sequence[j]
        local end_pattern_name = song.patterns[end_pattern_index].name
        
        -- Check for single-pattern marker or end marker
        if has_single_loop_marker(end_pattern_name) then
          -- Found a new single-pattern loop before finding our end
          -- Close current region at previous pattern
          loop_end = j - 1
          print(string.format("  Found new single-loop marker before end, closing at sequence %d", loop_end))
          break
        elseif has_loop_start_marker(end_pattern_name) then
          -- Found a new start marker before finding our end
          -- Close current region at previous pattern
          loop_end = j - 1
          print(string.format("  Found new start marker before end, closing at sequence %d", loop_end))
          break
        elseif has_loop_end_marker(end_pattern_name) then
          -- Found the matching end marker
          loop_end = j
          print(string.format("  Found matching end marker ] at sequence %d", loop_end))
          break
        end
      end
      
      -- If no end marker found, extend to end of sequence
      if not loop_end then
        loop_end = total_sequences
        print(string.format("  No end marker found, using last sequence %d", loop_end))
      end
      
      table.insert(regions, {start_seq = loop_start, end_seq = loop_end})
      i = loop_end + 1
    else
      i = i + 1
    end
  end
  
  print(string.format("Found %d loop regions total", #regions))
  for idx, region in ipairs(regions) do
    print(string.format("  Region %d: sequences %d to %d", idx, region.start_seq, region.end_seq))
  end
  
  return regions
end

-- Find the current loop region index based on the current sequence loop
local function find_current_loop_region_index(regions)
  local song = renoise.song()
  local transport = song.transport
  local loop_range = transport.loop_sequence_range
  
  -- Check if there's an active loop
  if not loop_range or #loop_range ~= 2 or (loop_range[1] == 0 and loop_range[2] == 0) then
    return nil
  end
  
  local current_start = loop_range[1]
  local current_end = loop_range[2]
  
  -- Find which region matches the current loop
  for i, region in ipairs(regions) do
    if region.start_seq == current_start and region.end_seq == current_end then
      return i
    end
  end
  
  return nil
end

-- Find the next loop region after the current position or loop
-- Returns region index, or nil if no next region exists
-- If no_current_loop is true, finds region at or after current position
local function find_next_loop_region_index(regions, no_current_loop)
  local song = renoise.song()
  local transport = song.transport
  local loop_range = transport.loop_sequence_range
  local current_sequence = song.selected_sequence_index
  
  -- Determine starting point for search
  local search_from = current_sequence
  
  -- If there's an active loop, search from after that loop ends
  if not no_current_loop and loop_range and #loop_range == 2 and loop_range[1] > 0 and loop_range[2] > 0 then
    search_from = loop_range[2]
  end
  
  print(string.format("Searching for next loop region after sequence %d (no_current_loop=%s)", search_from, tostring(no_current_loop)))
  
  -- If no current loop, first check if we're inside a region
  if no_current_loop then
    for i, region in ipairs(regions) do
      if current_sequence >= region.start_seq and current_sequence <= region.end_seq then
        print(string.format("  Found region %d containing current sequence %d", i, current_sequence))
        return i
      end
    end
  end
  
  -- Find the first region that starts after our current position
  for i, region in ipairs(regions) do
    if region.start_seq > search_from then
      print(string.format("  Found next region %d starting at sequence %d", i, region.start_seq))
      return i
    end
  end
  
  -- No next region found - return nil (don't wrap)
  print("  No next region found")
  return nil
end

-- Find the previous loop region before the current position or loop
-- Returns region index, or nil if no previous region exists
-- If no_current_loop is true, finds region at or before current position
local function find_previous_loop_region_index(regions, no_current_loop)
  local song = renoise.song()
  local transport = song.transport
  local loop_range = transport.loop_sequence_range
  local current_sequence = song.selected_sequence_index
  
  -- Determine starting point for search
  local search_from = current_sequence
  
  -- If there's an active loop, search from before that loop starts
  if not no_current_loop and loop_range and #loop_range == 2 and loop_range[1] > 0 and loop_range[2] > 0 then
    search_from = loop_range[1]
  end
  
  print(string.format("Searching for previous loop region before sequence %d (no_current_loop=%s)", search_from, tostring(no_current_loop)))
  
  -- If no current loop, first check if we're inside a region
  if no_current_loop then
    for i, region in ipairs(regions) do
      if current_sequence >= region.start_seq and current_sequence <= region.end_seq then
        print(string.format("  Found region %d containing current sequence %d", i, current_sequence))
        return i
      end
    end
  end
  
  -- Find the last region that ends before our current position
  local found_index = nil
  for i, region in ipairs(regions) do
    if region.end_seq < search_from then
      found_index = i
    else
      break
    end
  end
  
  if found_index then
    print(string.format("  Found previous region %d ending at sequence %d", found_index, regions[found_index].end_seq))
    return found_index
  end
  
  -- No previous region found - return nil (don't wrap)
  print("  No previous region found")
  return nil
end

-- Set the sequence loop to a specific region
local function set_loop_to_region(region)
  local song = renoise.song()
  local transport = song.transport
  
  -- Turn off pattern loop - we're using sequence loop instead
  if transport.loop_pattern then
    transport.loop_pattern = false
    print("Turned off pattern loop")
  end
  
  print(string.format("Setting loop to sequences %d - %d", region.start_seq, region.end_seq))
  transport.loop_sequence_range = {region.start_seq, region.end_seq}
  
  -- Get the pattern name for status message
  local pattern_index = song.sequencer.pattern_sequence[region.start_seq]
  local pattern_name = song.patterns[pattern_index].name
  
  if region.start_seq == region.end_seq then
    renoise.app():show_status(string.format("Loop set to sequence %d: %s", region.start_seq, pattern_name))
  else
    local end_pattern_index = song.sequencer.pattern_sequence[region.end_seq]
    local end_pattern_name = song.patterns[end_pattern_index].name
    renoise.app():show_status(string.format("Loop set to sequences %d-%d: %s to %s", region.start_seq, region.end_seq, pattern_name, end_pattern_name))
  end
end

-- Clear the current sequence loop
local function clear_sequence_loop()
  local song = renoise.song()
  song.transport.loop_sequence_range = {}
  print("Sequence loop cleared")
end

---------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
---------------------------------------------------------------------------

-- Set the sequence loop based on pattern name markers at current position
function PakettiPatternNameLoopSetAtCurrent()
  local song = renoise.song()
  local current_sequence = song.selected_sequence_index
  local regions = find_all_pattern_name_loop_regions()
  
  if #regions == 0 then
    renoise.app():show_status("No loop markers found in pattern names. Use [ ] or [] in pattern names.")
    return
  end
  
  -- Find a region that contains the current sequence
  for i, region in ipairs(regions) do
    if current_sequence >= region.start_seq and current_sequence <= region.end_seq then
      set_loop_to_region(region)
      return
    end
  end
  
  -- No region at current position, find the next one (passing true for no_current_loop)
  local next_index = find_next_loop_region_index(regions, true)
  if next_index then
    set_loop_to_region(regions[next_index])
  else
    -- No next region, try the first region
    if #regions > 0 then
      set_loop_to_region(regions[1])
    else
      renoise.app():show_status("No loop region found at or after current position")
    end
  end
end

-- Go to the next pattern name loop region
function PakettiPatternNameLoopNext()
  local song = renoise.song()
  local transport = song.transport
  local loop_range = transport.loop_sequence_range
  local regions = find_all_pattern_name_loop_regions()
  
  if #regions == 0 then
    renoise.app():show_status("No loop markers found in pattern names. Use [ ] or [] in pattern names.")
    return
  end
  
  -- Check if there's currently a loop set
  local has_current_loop = loop_range and #loop_range == 2 and loop_range[1] > 0 and loop_range[2] > 0
  
  if has_current_loop then
    -- There's a current loop, find the next one after it
    local next_index = find_next_loop_region_index(regions, false)
    if next_index then
      set_loop_to_region(regions[next_index])
    else
      -- No more regions after current loop, turn off the loop
      clear_sequence_loop()
      renoise.app():show_status("No more loop regions - sequence loop turned off")
    end
  else
    -- No current loop, find region at or after current position
    local next_index = find_next_loop_region_index(regions, true)
    if next_index then
      set_loop_to_region(regions[next_index])
    else
      -- No region at or after current position, start from first region
      if #regions > 0 then
        set_loop_to_region(regions[1])
      end
    end
  end
end

-- Go to the previous pattern name loop region
function PakettiPatternNameLoopPrevious()
  local song = renoise.song()
  local transport = song.transport
  local loop_range = transport.loop_sequence_range
  local regions = find_all_pattern_name_loop_regions()
  
  if #regions == 0 then
    renoise.app():show_status("No loop markers found in pattern names. Use [ ] or [] in pattern names.")
    return
  end
  
  -- Check if there's currently a loop set
  local has_current_loop = loop_range and #loop_range == 2 and loop_range[1] > 0 and loop_range[2] > 0
  
  if has_current_loop then
    -- There's a current loop, find the previous one before it
    local prev_index = find_previous_loop_region_index(regions, false)
    if prev_index then
      set_loop_to_region(regions[prev_index])
    else
      -- No more regions before current loop, turn off the loop
      clear_sequence_loop()
      renoise.app():show_status("No more loop regions - sequence loop turned off")
    end
  else
    -- No current loop, find region at or before current position
    local prev_index = find_previous_loop_region_index(regions, true)
    if prev_index then
      set_loop_to_region(regions[prev_index])
    else
      -- No region at or before current position, start from last region
      if #regions > 0 then
        set_loop_to_region(regions[#regions])
      end
    end
  end
end

-- Clear the pattern name-based loop
function PakettiPatternNameLoopClear()
  clear_sequence_loop()
  renoise.app():show_status("Pattern name loop cleared")
end

-- Toggle loop at current position (set if not set, clear if set)
function PakettiPatternNameLoopToggle()
  local song = renoise.song()
  local transport = song.transport
  local loop_range = transport.loop_sequence_range
  
  -- Check if there's an active loop
  if loop_range and #loop_range == 2 and loop_range[1] > 0 and loop_range[2] > 0 then
    -- There's a loop, clear it
    clear_sequence_loop()
    renoise.app():show_status("Pattern name loop cleared")
  else
    -- No loop, set one at current position
    PakettiPatternNameLoopSetAtCurrent()
  end
end

-- List all loop regions in pattern names (debug/info function)
function PakettiPatternNameLoopList()
  local regions = find_all_pattern_name_loop_regions()
  local song = renoise.song()
  
  if #regions == 0 then
    renoise.app():show_status("No loop markers found in pattern names. Use [ ] or [] in pattern names.")
    return
  end
  
  print("=== Pattern Name Loop Regions ===")
  for i, region in ipairs(regions) do
    local start_pattern_index = song.sequencer.pattern_sequence[region.start_seq]
    local start_name = song.patterns[start_pattern_index].name
    
    if region.start_seq == region.end_seq then
      print(string.format("Region %d: Sequence %d - '%s' (single pattern)", i, region.start_seq, start_name))
    else
      local end_pattern_index = song.sequencer.pattern_sequence[region.end_seq]
      local end_name = song.patterns[end_pattern_index].name
      print(string.format("Region %d: Sequences %d-%d - '%s' to '%s'", i, region.start_seq, region.end_seq, start_name, end_name))
    end
  end
  print("=================================")
  
  renoise.app():show_status(string.format("Found %d loop regions in pattern names", #regions))
end

-- Jump to a specific loop region by number (1-based)
function PakettiPatternNameLoopGoToRegion(region_number)
  local regions = find_all_pattern_name_loop_regions()
  
  if #regions == 0 then
    renoise.app():show_status("No loop markers found in pattern names. Use [ ] or [] in pattern names.")
    return
  end
  
  if region_number < 1 or region_number > #regions then
    renoise.app():show_status(string.format("Invalid region number. Valid range: 1-%d", #regions))
    return
  end
  
  -- Clear current loop
  clear_sequence_loop()
  
  -- Set the specified region
  set_loop_to_region(regions[region_number])
end

---------------------------------------------------------------------------
-- KEYBINDINGS
---------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Name Loop - Set at Current",
  invoke = PakettiPatternNameLoopSetAtCurrent
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Name Loop - Next",
  invoke = PakettiPatternNameLoopNext
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Name Loop - Previous",
  invoke = PakettiPatternNameLoopPrevious
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Name Loop - Clear",
  invoke = PakettiPatternNameLoopClear
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Name Loop - Toggle",
  invoke = PakettiPatternNameLoopToggle
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Name Loop - List Regions",
  invoke = PakettiPatternNameLoopList
}

-- Pattern Sequencer context keybindings
renoise.tool():add_keybinding{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Set at Current",
  invoke = PakettiPatternNameLoopSetAtCurrent
}

renoise.tool():add_keybinding{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Next",
  invoke = PakettiPatternNameLoopNext
}

renoise.tool():add_keybinding{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Previous",
  invoke = PakettiPatternNameLoopPrevious
}

renoise.tool():add_keybinding{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Clear",
  invoke = PakettiPatternNameLoopClear
}

renoise.tool():add_keybinding{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Toggle",
  invoke = PakettiPatternNameLoopToggle
}

---------------------------------------------------------------------------
-- MIDI MAPPINGS
---------------------------------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Name Loop - Next",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPatternNameLoopNext()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Name Loop - Previous",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPatternNameLoopPrevious()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Name Loop - Toggle",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPatternNameLoopToggle()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Name Loop - Clear",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPatternNameLoopClear()
    end
  end
}

---------------------------------------------------------------------------
-- MENU ENTRIES
---------------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Set at Current",
  invoke = PakettiPatternNameLoopSetAtCurrent
}

renoise.tool():add_menu_entry{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Next",
  invoke = PakettiPatternNameLoopNext
}

renoise.tool():add_menu_entry{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Previous",
  invoke = PakettiPatternNameLoopPrevious
}

renoise.tool():add_menu_entry{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Clear",
  invoke = PakettiPatternNameLoopClear
}

renoise.tool():add_menu_entry{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - Toggle",
  invoke = PakettiPatternNameLoopToggle
}

renoise.tool():add_menu_entry{
  name = "Pattern Sequencer:Paketti:Pattern Name Loop - List Regions",
  invoke = PakettiPatternNameLoopList
}

-- Keybindings for jumping directly to specific loop regions (1-16)
for region_num = 1, 16 do
  renoise.tool():add_keybinding{
    name = string.format("Global:Paketti:Pattern Name Loop - Go To Region %02d", region_num),
    invoke = function()
      PakettiPatternNameLoopGoToRegion(region_num)
    end
  }
end

print("PakettiPatternNameLoop.lua loaded - Use [ ] and [] markers in pattern names to define loop regions")
