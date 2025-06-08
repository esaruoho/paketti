function pakettiGrooveToDelay()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_lines = song.patterns[pattern_index].number_of_lines
  local lpb = song.transport.lpb
  local selected_track = song.selected_track
  
  -- Check for master or send tracks
  if selected_track.type == renoise.Track.TRACK_TYPE_MASTER then
    renoise.app():show_status("Cannot apply groove to delay conversion on Master track.")
    return
  elseif selected_track.type == renoise.Track.TRACK_TYPE_SEND then
    renoise.app():show_status("Cannot apply groove to delay conversion on Send track.")
    return
  end
  
  -- Check if pattern exists
  if not song.patterns[pattern_index] then
    renoise.app():show_status("Invalid pattern index.")
    return
  end
  
  -- Check for empty group tracks
  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    if #selected_track.members == 0 then
      renoise.app():show_status("Cannot process empty group track. Group track must have member tracks.")
      return
    end
  end
  
  -- Validate LPB is a power of 2 and at least 4
  local function is_power_of_two(n)
    return n > 0 and math.floor(math.log(n)/math.log(2)) == math.log(n)/math.log(2)
  end
  
  if not is_power_of_two(lpb) or lpb < 4 then
    renoise.app():show_warning(string.format(
      "This tool works best with LPB values that are powers of 2 (4,8,16,32,64...). Current LPB: %d", lpb))
    return
  end
  
  -- Determine which tracks to process
  local tracks_to_process = {}
  if selected_track.type == 4 then -- Group track
    -- Process all member tracks in the group
    print("Selected track is a group track - processing all member tracks...")
    -- Calculate member track indices by counting backwards from group track
    local member_count = #selected_track.members
    local first_member_index = track_index - member_count
    
    -- First make all delay columns visible for all member tracks
    for i = 1, member_count do
      local member_track = selected_track.members[member_count - i + 1]
      if not member_track.delay_column_visible then
        member_track.delay_column_visible = true
        print(string.format("Made delay column visible for member track '%s' (#%02d)", 
          member_track.name ~= "" and member_track.name or string.format("#%02d", first_member_index + i - 1),
          first_member_index + i - 1))
      end
      -- Add all member tracks to processing list since we made their delay columns visible
      table.insert(tracks_to_process, {track = member_track, index = first_member_index + i - 1})
      print(string.format("Added member track '%s' (#%02d) with %d visible note columns", 
        member_track.name ~= "" and member_track.name or string.format("#%02d", first_member_index + i - 1),
        first_member_index + i - 1,
        member_track.visible_note_columns))
    end
  else
    -- Process just the selected track
    if not selected_track.delay_column_visible then
      selected_track.delay_column_visible = true
      print("Made delay column visible for track " .. track_index)
    end
    table.insert(tracks_to_process, {track = selected_track, index = track_index})
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
  
  -- Process each track
  for _, track_info in ipairs(tracks_to_process) do
    local track = track_info.track
    local current_track_index = track_info.index
    
    -- Get the number of visible note columns for THIS track specifically
    local visible_note_columns = track.visible_note_columns
    print(string.format("Processing track: %s (#%02d) with %d visible note columns", 
      track.name ~= "" and track.name or string.format("#%02d", current_track_index),
      current_track_index,
      visible_note_columns))
    
    -- Write delays for the entire pattern length
    for i = 0, pattern_lines - 1 do
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
        -- LPB16 and higher: First shift notes down by one line and then apply delays
        local cycle_length = lpb * 2
        local scale = lpb / 8
        local base_positions = {
          3 * scale,
          7 * scale,
          11 * scale,
          15 * scale
        }
        
        -- Process each visible note column for THIS track
        for col = 1, visible_note_columns do
          -- Get the pattern line for THIS track
          local pattern_line = song.patterns[pattern_index].tracks[current_track_index].lines[current_line]
          -- Get the note column for THIS track
          local note_column = pattern_line.note_columns[col]
          
          -- For LPB16: Check if we need to move the note down (groove >= 0.5) or just apply delay
          if lpb == 16 then
            for idx, pos in ipairs(base_positions) do
              -- Adjust position check for LPB16
              if current_line % cycle_length == (pos - 1) % cycle_length then
                -- Calculate delay first
                local delay = groove_to_delay(ga[idx])
                
                -- If groove >= 0.5 and there's a note, move it down
                if ga[idx] >= 0.5 and note_column.note_value ~= 121 then -- 121 is empty note
                  if current_line < pattern_lines then
                    -- Get the target line for THIS track
                    local next_line = song.patterns[pattern_index].tracks[current_track_index].lines[current_line + 1]
                    -- Get the note column for THIS track
                    local next_note_column = next_line.note_columns[col]
                    
                    -- Move the note data
                    next_note_column.note_value = note_column.note_value
                    next_note_column.instrument_value = note_column.instrument_value
                    next_note_column.volume_value = note_column.volume_value
                    next_note_column.panning_value = note_column.panning_value
                    next_note_column.effect_number_value = note_column.effect_number_value
                    next_note_column.effect_amount_value = note_column.effect_amount_value
                    next_note_column.delay_value = delay
                    
                    -- Clear the original line
                    note_column.note_value = 121 -- Empty note
                    note_column.instrument_value = 255 -- Empty instrument
                    note_column.volume_value = 255 -- Empty volume
                    note_column.panning_value = 255 -- Empty panning
                    note_column.delay_value = 0 -- No delay
                    note_column.effect_number_value = 0 -- No effect
                    note_column.effect_amount_value = 0 -- No effect amount
                    
                    print(string.format("Track %s Col %d/%d Line %d: Groove %.3f >= 0.5, moved note to line %d with delay %d (0x%02X)", 
                        track.name, col, visible_note_columns, current_line, ga[idx], current_line + 1, delay, delay))
                  end
                else
                  -- Just apply delay to current position if there's a note
                  if note_column.note_value ~= 121 then
                    note_column.delay_value = delay
                    print(string.format("Track %s Col %d/%d Line %d: Groove %.3f < 0.5, keeping note in place with delay %d (0x%02X)", 
                        track.name, col, visible_note_columns, current_line, ga[idx], delay, delay))
                  end
                end
                break
              end
            end
          else
            -- Non-LPB16 higher LPB values just check position
            for idx, pos in ipairs(base_positions) do
              if current_line % cycle_length == pos % cycle_length then
                should_delay = true
                groove_index = idx
                break
              end
            end
          end
        end
      end
      
      -- Only apply delays for non-LPB16 modes here
      if should_delay and lpb ~= 16 then
        local delay = groove_to_delay(ga[groove_index])
        -- Get the pattern line for THIS track
        local pattern_line = song.patterns[pattern_index].tracks[current_track_index].lines[current_line]
        -- Apply delay to all visible note columns for THIS track
        for col = 1, visible_note_columns do
          local note_column = pattern_line.note_columns[col]
          note_column.delay_value = delay
        end
        print(string.format("Track %s Line %d: Applying delay %d (0x%02X) from Groove %d (%.3f) - %.1f%% of max delay to %d columns", 
            track.name, current_line, delay, delay, groove_index, ga[groove_index], (delay/170)*100, visible_note_columns))
      elseif lpb ~= 16 then
        -- Get the pattern line for THIS track
        local pattern_line = song.patterns[pattern_index].tracks[current_track_index].lines[current_line]
        -- Clear delays on non-delay lines for all columns in THIS track
        for col = 1, visible_note_columns do
          local note_column = pattern_line.note_columns[col]
          note_column.delay_value = 0
        end
        print(string.format("Track %s Line %d: No delay (base line) - cleared %d columns", track.name, current_line, visible_note_columns))
      end
    end
  end
  
  -- Disable global groove
  song.transport.groove_enabled = false
  
  -- Create status message
  local status_msg
  if selected_track.type == 4 then
    local track_names = {}
    for _, track_info in ipairs(tracks_to_process) do
      table.insert(track_names, track_info.track.name ~= "" and track_info.track.name or string.format("#%02d", track_info.index))
    end
    status_msg = string.format("LPB%d - Global Groove 0&1: %d%% (%02X), 2&3: %d%% (%02X), 4&5: %d%% (%02X), 6&7: %d%% (%02X) -> Group: %s [%s]",
      lpb,
      math.floor(ga[1] * 100), delays[1],
      math.floor(ga[2] * 100), delays[2],
      math.floor(ga[3] * 100), delays[3],
      math.floor(ga[4] * 100), delays[4],
      selected_track.name,
      table.concat(track_names, ", "))
  else
    local track_name = selected_track.name
    if track_name == "" then
      track_name = string.format("#%02d", track_index)
    end
    status_msg = string.format("LPB%d - Global Groove 0&1: %d%% (%02X), 2&3: %d%% (%02X), 4&5: %d%% (%02X), 6&7: %d%% (%02X) -> %s",
      lpb,
      math.floor(ga[1] * 100), delays[1],
      math.floor(ga[2] * 100), delays[2],
      math.floor(ga[3] * 100), delays[3],
      math.floor(ga[4] * 100), delays[4],
      track_name)
  end
  print(status_msg)
  
  -- Show warning for LPB16 users
  if lpb == 16 then
    renoise.app():show_status(status_msg .. " -- LPB16 Global Groove to Delay Column Values is not precise, please contact esaruoho@icloud.com and provide details of expected result")
  else
    renoise.app():show_status(status_msg)
  end
end

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Tracks..:Convert Global Groove to Delay on Selected Track/Group",invoke=pakettiGrooveToDelay}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Convert Global Groove to Delay on Selected Track/Group",invoke=pakettiGrooveToDelay}
renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Convert Global Groove to Delay on Selected Track/Group",invoke=function(message) if message:is_trigger() then pakettiGrooveToDelay() end end}
