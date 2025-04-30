function pakettiGrooveToDelay()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_lines = song.patterns[pattern_index].number_of_lines
  local lpb = song.transport.lpb
  
  -- Validate LPB is a power of 2 and at least 4
  local function is_power_of_two(n)
    return n > 0 and math.floor(math.log(n)/math.log(2)) == math.log(n)/math.log(2)
  end
  
  if not is_power_of_two(lpb) or lpb < 4 then
    renoise.app():show_warning(string.format(
      "This tool works best with LPB values that are powers of 2 (4,8,16,32,64...). Current LPB: %d", lpb))
    return
  end
  
  -- Make sure delay column is visible
  if not song.tracks[track_index].delay_column_visible then
    song.tracks[track_index].delay_column_visible = true
    print("Made delay column visible for track " .. track_index)
  end

  -- Get groove amounts
  local ga = song.transport.groove_amounts
  
  -- Debug print
  print("Converting grooves to delays:")
  print(string.format("Current LPB: %d", lpb))
  
  if lpb == 4 then
    print("LPB4 Mode - Delay on every second row:")
    print(string.format("GA1: %.3f (affects odd lines)", ga[1]))
    print(string.format("GA2: %.3f (affects odd lines)", ga[2]))
    print(string.format("GA3: %.3f (affects odd lines)", ga[3]))
    print(string.format("GA4: %.3f (affects odd lines)", ga[4]))
  elseif lpb == 8 then
    print("LPB8 Mode - Specific line positions:")
    print(string.format("GA1: %.3f (affects line 03)", ga[1]))
    print(string.format("GA2: %.3f (affects line 07)", ga[2]))
    print(string.format("GA3: %.3f (affects line 11)", ga[3]))
    print(string.format("GA4: %.3f (affects line 15)", ga[4]))
  else
    -- For LPB16 and higher, we double the LPB8 positions and subtract 1
    local scale = lpb / 8 -- This gives us 2 for LPB16, 4 for LPB32, etc.
    local base_positions = {3, 7, 11, 15} -- LPB8 base positions
    local scaled_positions = {
      base_positions[1] * scale - 1,
      base_positions[2] * scale - 1,
      base_positions[3] * scale - 1,
      base_positions[4] * scale - 1
    }
    print(string.format("LPB%d Mode - Scaled from LPB8 positions (x%d, then -1):", lpb, scale))
    for i = 1, 4 do
      print(string.format("GA%d: %.3f (affects line %02d)", i, ga[i], scaled_positions[i]))
    end
  end
  
  -- Convert groove to delay using the correct formula
  -- 100% groove = 170 (0xAA) which is 2/3 of 256
  local function groove_to_delay(groove)
      -- RENOISE_GROOVE_MAX = 170 (0xAA) which represents 2/3 of a line
      local RENOISE_GROOVE_MAX = 170
      -- Scale the groove percentage to the max delay value
      local delay = math.floor((groove * RENOISE_GROOVE_MAX) + 0.5)
      
      -- Different scaling for different LPB values
      if lpb == 8 then
        -- LPB8 uses 2x scaling
        delay = delay * 2
      elseif lpb >= 16 then
        -- LPB16+ uses lpb/8 scaling (2 for LPB16, 4 for LPB32, etc)
        delay = delay * (lpb / 8)
      end
      
      -- Make sure we don't exceed FF
      if delay > 255 then delay = 255 end
      return delay
  end
  
  -- Calculate all delays first for status message
  local delays = {}
  for i = 1, 4 do
    delays[i] = groove_to_delay(ga[i])
  end
  
  -- Write delays for the entire pattern length
  for i = 0, pattern_lines - 1 do
    local note_column = song.patterns[pattern_index].tracks[track_index].lines[i + 1].note_columns[1]
    local current_line = i + 1
    local should_delay = false
    local groove_index = 1
    
    if lpb == 4 then
      -- LPB4: Every second line gets a delay
      if i % 2 == 1 then -- Odd lines (1,3,5,7...)
        should_delay = true
        groove_index = ((i % 8) + 1) / 2 -- Maps 1->1, 3->2, 5->3, 7->4
      end
    elseif lpb == 8 then
      -- LPB8: Specific line positions
      local cycle_length = lpb * 2
      local base_positions = {3, 7, 11, 15} -- LPB8 positions (1-based)
      
      -- Check if current line matches any position
      for idx, pos in ipairs(base_positions) do
        if current_line % cycle_length == pos % cycle_length then
          should_delay = true
          groove_index = idx
          break
        end
      end
    else
      -- LPB16 and higher: Scale up from LPB8 positions and subtract 1
      local cycle_length = lpb * 2
      local scale = lpb / 8
      local base_positions = {
        (3 * scale) - 1,
        (7 * scale) - 1,
        (11 * scale) - 1,
        (15 * scale) - 1
      }
      
      -- Check if current line matches any position
      for idx, pos in ipairs(base_positions) do
        if current_line % cycle_length == pos % cycle_length then
          should_delay = true
          groove_index = idx
          break
        end
      end
    end
    
    if should_delay then
      local delay = groove_to_delay(ga[groove_index])
      note_column.delay_value = delay
      print(string.format("Line %d: Applying delay %d (0x%02X) from Groove %d (%.3f) - %.1f%% of max delay", 
          current_line, delay, delay, groove_index, ga[groove_index], (delay/170)*100))
    else
      note_column.delay_value = 0
      print(string.format("Line %d: No delay (base line)", current_line))
    end
  end
  
  -- Disable global groove
  song.transport.groove_enabled = false
  
  -- Get track name
  local track_name = song.tracks[track_index].name
  if track_name == "" then
    track_name = string.format("#%02d", track_index)
  end
  
  local status_msg = string.format("LPB%d - Global Groove 0&1: %d%% (%02X), 2&3: %d%% (%02X), 4&5: %d%% (%02X), 6&7: %d%% (%02X) -> %s",
    lpb,
    math.floor(ga[1] * 100), delays[1],
    math.floor(ga[2] * 100), delays[2],
    math.floor(ga[3] * 100), delays[3],
    math.floor(ga[4] * 100), delays[4],
    track_name)
  print(status_msg)  
  renoise.app():show_status(status_msg)
end

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Convert Global Groove to Delay on Selected Track",invoke = pakettiGrooveToDelay}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Convert Global Groove to Delay on Selected Track",invoke = pakettiGrooveToDelay}
renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Convert Global Groove to Delay on Selected Track",invoke = function(message) if message:is_trigger() then pakettiGrooveToDelay() end end}
