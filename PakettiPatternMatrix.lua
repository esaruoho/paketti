-- Show or hide Pattern Matrix
function showhidepatternmatrix()
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    then renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR 
    renoise.app().window.pattern_matrix_is_visible = true
    return
  end
  if renoise.app().window.pattern_matrix_is_visible == true
    then renoise.app().window.pattern_matrix_is_visible = false
    else renoise.app().window.pattern_matrix_is_visible = true
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide Pattern Matrix",invoke=function() showhidepatternmatrix() end}
-------
function duplicate_pattern_and_clear_muted_above()
  local song=renoise.song()
  local current_pattern_index=song.selected_pattern_index
  local current_sequence_index=song.selected_sequence_index

  -- Insert a new, unreferenced pattern above the current sequence index
  local new_sequence_index = current_sequence_index
  local new_pattern_index = song.sequencer:insert_new_pattern_at(new_sequence_index)

  -- Set the new pattern length to match the original pattern length
  song.patterns[new_pattern_index].number_of_lines = song.patterns[current_pattern_index].number_of_lines
  
  -- Copy the current pattern into the newly created pattern
  song.patterns[new_pattern_index]:copy_from(song.patterns[current_pattern_index])

  -- Set the name of the new pattern based on the original name or default to "Pattern <number> (mutes cleared)"
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (mutes cleared)"

  -- Select the new sequence index
  song.selected_sequence_index = new_sequence_index

  -- Apply mute states from the original pattern to the new pattern in the sequencer
  for track_index = 1, #song.tracks do
    local is_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
    if is_muted then
      print("Track " .. track_index .. " was muted in the original sequence; muting in new sequence.")
    end
  end

  -- Copy all automation data from the original pattern to the new pattern
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[new_pattern_index].tracks[track_index]

    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter

      -- Find or create the corresponding automation in the new track
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end

      -- Copy the entire automation data using copy_from
      new_automation:copy_from(automation)
      print("Copied complete automation for parameter in track " .. track_index)
    end
  end

  -- Identify tracks that are muted or off, then clear them in the new pattern
  local muted_tracks = {}
  for i, track in ipairs(song.tracks) do
    if track.mute_state == renoise.Track.MUTE_STATE_MUTED or track.mute_state == renoise.Track.MUTE_STATE_OFF then
      table.insert(muted_tracks, i)
      print("Track " .. i .. " is muted or off. Preparing to clear it.")
    end
  end

  for _, track_index in ipairs(muted_tracks) do
    song.patterns[new_pattern_index].tracks[track_index]:clear()
    print("Cleared track " .. track_index .. " in duplicated pattern.")
  end

  renoise.app():show_status("Duplicated pattern above current sequence with mute states, complete automation, and cleared muted tracks.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Pattern Above & Clear Muted Tracks",invoke=duplicate_pattern_and_clear_muted_above}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Pattern Above & Clear Muted Tracks",invoke=duplicate_pattern_and_clear_muted_above}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate Pattern Above & Clear Muted Tracks",invoke=duplicate_pattern_and_clear_muted_above}


renoise.tool():add_midi_mapping{name="Paketti:Duplicate Pattern Above & Clear Muted",invoke=duplicate_pattern_and_clear_muted_above}



function duplicate_pattern_and_clear_muted()
  local song=renoise.song()
  local current_pattern_index=song.selected_pattern_index
  local current_sequence_index=song.selected_sequence_index

  -- Insert a new, unreferenced pattern below the current sequence index
  local new_sequence_index = current_sequence_index + 1
  local new_pattern_index = song.sequencer:insert_new_pattern_at(new_sequence_index)

  -- Set the new pattern length to match the original pattern length
  song.patterns[new_pattern_index].number_of_lines = song.patterns[current_pattern_index].number_of_lines
  
  -- Copy the current pattern into the newly created pattern
  song.patterns[new_pattern_index]:copy_from(song.patterns[current_pattern_index])

  -- Set the name of the new pattern based on the original name or default to "Pattern <number> (mutes cleared)"
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (mutes cleared)"

  -- Select the new sequence index
  song.selected_sequence_index = new_sequence_index

  -- Apply mute states from the original pattern to the new pattern in the sequencer
  for track_index = 1, #song.tracks do
    local is_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
    if is_muted then
    end
  end

  -- Copy all automation data from the original pattern to the new pattern
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[new_pattern_index].tracks[track_index]

    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter

      -- Find or create the corresponding automation in the new track
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end

      -- Copy the entire automation data using copy_from
      new_automation:copy_from(automation)
    end
  end

  -- Identify tracks that are muted or off, then clear them in the new pattern
  local muted_tracks = {}
  for i, track in ipairs(song.tracks) do
    if track.mute_state == renoise.Track.MUTE_STATE_MUTED or track.mute_state == renoise.Track.MUTE_STATE_OFF then
      table.insert(muted_tracks, i)
    end
  end

  for _, track_index in ipairs(muted_tracks) do
    song.patterns[new_pattern_index].tracks[track_index]:clear()
  end

  renoise.app():show_status("Duplicated pattern below current sequence with mute states, complete automation, and cleared muted tracks.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Pattern Below & Clear Muted Tracks",invoke=duplicate_pattern_and_clear_muted}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Pattern Below & Clear Muted Tracks",invoke=duplicate_pattern_and_clear_muted}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate Pattern Below & Clear Muted Tracks",invoke=duplicate_pattern_and_clear_muted}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Pattern Below & Clear Muted",invoke=duplicate_pattern_and_clear_muted}





-- Duplicate Pattern (no clearing), standalone function to reuse in menus/shortcuts
function PakettiDuplicatePattern()
  local song=renoise.song()
  local current_pattern_index=song.selected_pattern_index
  local current_sequence_index=song.selected_sequence_index

  local new_sequence_index = current_sequence_index + 1
  local new_pattern_index = song.sequencer:insert_new_pattern_at(new_sequence_index)

  -- Set the new pattern length to match the original pattern length
  song.patterns[new_pattern_index].number_of_lines = song.patterns[current_pattern_index].number_of_lines
  
  song.patterns[new_pattern_index]:copy_from(song.patterns[current_pattern_index])

  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (duplicate)"

  -- Jump to the new pattern in the sequence
  song.selected_sequence_index = new_sequence_index

  -- Keep the mute states identical between sequence slots
  for track_index = 1, #song.tracks do
    local is_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end

  -- Ensure all automation is copied as well
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[new_pattern_index].tracks[track_index]
    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end

  renoise.app():show_status("Duplicated pattern below and jumped to it.")
end

-- Menu entry, keybindings, and MIDI mapping for Duplicate Pattern
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}

renoise.tool():add_midi_mapping{name="Paketti:Duplicate Pattern (No Clear)",invoke=PakettiDuplicatePattern}

-- Swap pattern slot with the one above
function PakettiSwapPatternSlotWithAbove()
  local song = renoise.song()
  local current_sequence_index = song.selected_sequence_index
  local current_track_index = song.selected_track_index
  
  -- Check if there's a pattern above
  if current_sequence_index <= 1 then
    renoise.app():show_status("There is no pattern above the one you're on, doing nothing")
    return
  end
  
  local target_sequence_index = current_sequence_index - 1
  local current_pattern_index = song.sequencer.pattern_sequence[current_sequence_index]
  local target_pattern_index = song.sequencer.pattern_sequence[target_sequence_index]
  
  -- Get pattern data for both positions
  local current_pattern = song.patterns[current_pattern_index]
  local target_pattern = song.patterns[target_pattern_index]
  
  -- Swap the track data between patterns
  PakettiSwapTrackDataBetweenPatterns(current_pattern, target_pattern, current_track_index)
  
  renoise.app():show_status("Swapped pattern slot with the one above")
end

-- Swap pattern slot with the one below
function PakettiSwapPatternSlotWithBelow()
  local song = renoise.song()
  local current_sequence_index = song.selected_sequence_index
  local current_track_index = song.selected_track_index
  
  -- Check if there's a pattern below
  if current_sequence_index >= #song.sequencer.pattern_sequence then
    renoise.app():show_status("There is no pattern below the one you're on, doing nothing")
    return
  end
  
  local target_sequence_index = current_sequence_index + 1
  local current_pattern_index = song.sequencer.pattern_sequence[current_sequence_index]
  local target_pattern_index = song.sequencer.pattern_sequence[target_sequence_index]
  
  -- Get pattern data for both positions
  local current_pattern = song.patterns[current_pattern_index]
  local target_pattern = song.patterns[target_pattern_index]
  
  -- Swap the track data between patterns
  PakettiSwapTrackDataBetweenPatterns(current_pattern, target_pattern, current_track_index)
  
  renoise.app():show_status("Swapped pattern slot with the one below")
end

-- Helper function to swap track data between two patterns, handling different lengths
function PakettiSwapTrackDataBetweenPatterns(pattern_a, pattern_b, track_index)
  local current_track_a = pattern_a.tracks[track_index]
  local current_track_b = pattern_b.tracks[track_index]
  
  local pattern_a_lines = pattern_a.number_of_lines
  local pattern_b_lines = pattern_b.number_of_lines
  
  -- Create temporary storage for track data
  local temp_track_data = {}
  local temp_automation_data = {}
  
  -- Store track A data (all lines, even beyond pattern B length)
  temp_track_data.lines = {}
  for line_index = 1, pattern_a_lines do
    temp_track_data.lines[line_index] = {}
    temp_track_data.lines[line_index].note_columns = {}
    temp_track_data.lines[line_index].effect_columns = {}
    
    -- Store note columns
    for col_index = 1, #current_track_a.lines[line_index].note_columns do
      local note_col = current_track_a.lines[line_index].note_columns[col_index]
      temp_track_data.lines[line_index].note_columns[col_index] = {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value,
        effect_number_value = note_col.effect_number_value,
        effect_amount_value = note_col.effect_amount_value
      }
    end
    
    -- Store effect columns
    for col_index = 1, #current_track_a.lines[line_index].effect_columns do
      local effect_col = current_track_a.lines[line_index].effect_columns[col_index]
      temp_track_data.lines[line_index].effect_columns[col_index] = {
        number_value = effect_col.number_value,
        amount_value = effect_col.amount_value
      }
    end
  end
  
  -- Store automation data for track A
  temp_automation_data = {}
  for _, automation in ipairs(current_track_a.automation) do
    local temp_automation = {
      parameter = automation.dest_parameter,
      points = {}
    }
    for _, point in ipairs(automation.points) do
      table.insert(temp_automation.points, {time = point.time, value = point.value})
    end
    table.insert(temp_automation_data, temp_automation)
  end
  
  -- Clear track A
  current_track_a:clear()
  
  -- Copy track B to track A, handling length differences
  if pattern_b_lines <= pattern_a_lines then
    -- Pattern B is shorter or same length - copy and loop if necessary
    for line_index = 1, pattern_a_lines do
      local source_line_index = ((line_index - 1) % pattern_b_lines) + 1
      current_track_a:line(line_index):copy_from(current_track_b:line(source_line_index))
    end
  else
    -- Pattern B is longer - copy all lines (only what fits will play)
    for line_index = 1, pattern_b_lines do
      if line_index <= pattern_a_lines then
        current_track_a:line(line_index):copy_from(current_track_b:line(line_index))
      end
    end
  end
  
  -- Copy automation from B to A
  for _, automation in ipairs(current_track_b.automation) do
    local parameter = automation.dest_parameter
    local new_automation = current_track_a:find_automation(parameter)
    if not new_automation then
      new_automation = current_track_a:create_automation(parameter)
    end
    new_automation:copy_from(automation)
  end
  
  -- Clear track B
  current_track_b:clear()
  
  -- Copy stored track A data to track B, handling length differences
  if pattern_a_lines <= pattern_b_lines then
    -- Stored data is shorter or same length - copy and loop if necessary
    for line_index = 1, pattern_b_lines do
      local source_line_index = ((line_index - 1) % pattern_a_lines) + 1
      local source_line = temp_track_data.lines[source_line_index]
      
      -- Copy note columns
      for col_index, note_col_data in pairs(source_line.note_columns) do
        if current_track_b.lines[line_index].note_columns[col_index] then
          local note_col = current_track_b.lines[line_index].note_columns[col_index]
          note_col.note_value = note_col_data.note_value
          note_col.instrument_value = note_col_data.instrument_value
          note_col.volume_value = note_col_data.volume_value
          note_col.panning_value = note_col_data.panning_value
          note_col.delay_value = note_col_data.delay_value
          note_col.effect_number_value = note_col_data.effect_number_value
          note_col.effect_amount_value = note_col_data.effect_amount_value
        end
      end
      
      -- Copy effect columns
      for col_index, effect_col_data in pairs(source_line.effect_columns) do
        if current_track_b.lines[line_index].effect_columns[col_index] then
          local effect_col = current_track_b.lines[line_index].effect_columns[col_index]
          effect_col.number_value = effect_col_data.number_value
          effect_col.amount_value = effect_col_data.amount_value
        end
      end
    end
  else
    -- Stored data is longer - copy all lines (only what fits will play)
    for line_index = 1, pattern_a_lines do
      if line_index <= pattern_b_lines then
        local source_line = temp_track_data.lines[line_index]
        
        -- Copy note columns
        for col_index, note_col_data in pairs(source_line.note_columns) do
          if current_track_b.lines[line_index].note_columns[col_index] then
            local note_col = current_track_b.lines[line_index].note_columns[col_index]
            note_col.note_value = note_col_data.note_value
            note_col.instrument_value = note_col_data.instrument_value
            note_col.volume_value = note_col_data.volume_value
            note_col.panning_value = note_col_data.panning_value
            note_col.delay_value = note_col_data.delay_value
            note_col.effect_number_value = note_col_data.effect_number_value
            note_col.effect_amount_value = note_col_data.effect_amount_value
          end
        end
        
        -- Copy effect columns
        for col_index, effect_col_data in pairs(source_line.effect_columns) do
          if current_track_b.lines[line_index].effect_columns[col_index] then
            local effect_col = current_track_b.lines[line_index].effect_columns[col_index]
            effect_col.number_value = effect_col_data.number_value
            effect_col.amount_value = effect_col_data.amount_value
          end
        end
      end
    end
  end
  
  -- Copy stored automation from A to B
  for _, temp_automation in ipairs(temp_automation_data) do
    local parameter = temp_automation.parameter
    local new_automation = current_track_b:find_automation(parameter)
    if not new_automation then
      new_automation = current_track_b:create_automation(parameter)
    end
    
    -- Clear existing points and add the stored ones
    new_automation:clear()
    for _, point in ipairs(temp_automation.points) do
      new_automation:add_point_at(point.time, point.value)
    end
  end
end

-- Menu entries for Swap Pattern Slot functions
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}

renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}

-- Keybindings for Swap Pattern Slot functions
renoise.tool():add_keybinding{name="Global:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}

renoise.tool():add_keybinding{name="Global:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}

-- MIDI mappings for Swap Pattern Slot functions
renoise.tool():add_midi_mapping{name="Paketti:Swap Pattern Slot with Above",invoke=PakettiSwapPatternSlotWithAbove}
renoise.tool():add_midi_mapping{name="Paketti:Swap Pattern Slot with Below",invoke=PakettiSwapPatternSlotWithBelow}

-- Swap two complete pattern sequence slots (all tracks and data)
function PakettiSwapTwoPatternSlots()
  local song = renoise.song()
  local current_sequence_index = song.selected_sequence_index
  
  -- Check if we have at least 2 patterns in sequence
  if #song.sequencer.pattern_sequence < 2 then
    renoise.app():show_status("Need at least 2 patterns in sequence to swap")
    return
  end
  
  -- For now, let's swap current slot with the next one
  -- TODO: In the future, this could be enhanced to detect actual selection range
  local target_sequence_index
  if current_sequence_index >= #song.sequencer.pattern_sequence then
    target_sequence_index = current_sequence_index - 1
  else
    target_sequence_index = current_sequence_index + 1
  end
  
  local current_pattern_index = song.sequencer.pattern_sequence[current_sequence_index]
  local target_pattern_index = song.sequencer.pattern_sequence[target_sequence_index]
  
  -- Get the actual pattern objects
  local current_pattern = song.patterns[current_pattern_index]
  local target_pattern = song.patterns[target_pattern_index]
  
  -- Swap all tracks between the two patterns
  PakettiSwapCompletePatternData(current_pattern, target_pattern)
  
  -- Also swap the mute states in the sequencer for all tracks
  for track_index = 1, #song.tracks do
    local current_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    local target_muted = song.sequencer:track_sequence_slot_is_muted(track_index, target_sequence_index)
    
    song.sequencer:set_track_sequence_slot_is_muted(track_index, current_sequence_index, target_muted)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, target_sequence_index, current_muted)
  end
  
  renoise.app():show_status("Swapped pattern slots " .. current_sequence_index .. " and " .. target_sequence_index .. " completely")
end

-- Helper function to swap complete pattern data (all tracks and automation)
function PakettiSwapCompletePatternData(pattern_a, pattern_b)
  local pattern_a_lines = pattern_a.number_of_lines
  local pattern_b_lines = pattern_b.number_of_lines
  local num_tracks = #pattern_a.tracks
  
  -- Store complete pattern A data
  local temp_pattern_data = {}
  temp_pattern_data.tracks = {}
  temp_pattern_data.name = pattern_a.name
  
  for track_index = 1, num_tracks do
    local current_track_a = pattern_a.tracks[track_index]
    temp_pattern_data.tracks[track_index] = {}
    temp_pattern_data.tracks[track_index].lines = {}
    temp_pattern_data.tracks[track_index].automation = {}
    
    -- Store all line data for track A
    for line_index = 1, pattern_a_lines do
      temp_pattern_data.tracks[track_index].lines[line_index] = {}
      temp_pattern_data.tracks[track_index].lines[line_index].note_columns = {}
      temp_pattern_data.tracks[track_index].lines[line_index].effect_columns = {}
      
      -- Store note columns
      for col_index = 1, #current_track_a.lines[line_index].note_columns do
        local note_col = current_track_a.lines[line_index].note_columns[col_index]
        temp_pattern_data.tracks[track_index].lines[line_index].note_columns[col_index] = {
          note_value = note_col.note_value,
          instrument_value = note_col.instrument_value,
          volume_value = note_col.volume_value,
          panning_value = note_col.panning_value,
          delay_value = note_col.delay_value,
          effect_number_value = note_col.effect_number_value,
          effect_amount_value = note_col.effect_amount_value
        }
      end
      
      -- Store effect columns
      for col_index = 1, #current_track_a.lines[line_index].effect_columns do
        local effect_col = current_track_a.lines[line_index].effect_columns[col_index]
        temp_pattern_data.tracks[track_index].lines[line_index].effect_columns[col_index] = {
          number_value = effect_col.number_value,
          amount_value = effect_col.amount_value
        }
      end
    end
    
    -- Store automation data for track A
    for _, automation in ipairs(current_track_a.automation) do
      local temp_automation = {
        parameter = automation.dest_parameter,
        points = {}
      }
      for _, point in ipairs(automation.points) do
        table.insert(temp_automation.points, {time = point.time, value = point.value})
      end
      table.insert(temp_pattern_data.tracks[track_index].automation, temp_automation)
    end
  end
  
  -- Now copy pattern B data to pattern A
  pattern_a.name = pattern_b.name
  for track_index = 1, num_tracks do
    local current_track_a = pattern_a.tracks[track_index]
    local current_track_b = pattern_b.tracks[track_index]
    
    -- Clear track A
    current_track_a:clear()
    
    -- Copy track B to track A, handling length differences
    if pattern_b_lines <= pattern_a_lines then
      -- Pattern B is shorter or same length - copy and loop if necessary
      for line_index = 1, pattern_a_lines do
        local source_line_index = ((line_index - 1) % pattern_b_lines) + 1
        current_track_a:line(line_index):copy_from(current_track_b:line(source_line_index))
      end
    else
      -- Pattern B is longer - copy all lines (only what fits will play)
      for line_index = 1, pattern_b_lines do
        if line_index <= pattern_a_lines then
          current_track_a:line(line_index):copy_from(current_track_b:line(line_index))
        end
      end
    end
    
    -- Copy automation from B to A
    for _, automation in ipairs(current_track_b.automation) do
      local parameter = automation.dest_parameter
      local new_automation = current_track_a:find_automation(parameter)
      if not new_automation then
        new_automation = current_track_a:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end
  
  -- Now copy stored pattern A data to pattern B
  pattern_b.name = temp_pattern_data.name
  for track_index = 1, num_tracks do
    local current_track_b = pattern_b.tracks[track_index]
    
    -- Clear track B
    current_track_b:clear()
    
    -- Copy stored track A data to track B, handling length differences
    if pattern_a_lines <= pattern_b_lines then
      -- Stored data is shorter or same length - copy and loop if necessary
      for line_index = 1, pattern_b_lines do
        local source_line_index = ((line_index - 1) % pattern_a_lines) + 1
        local source_line = temp_pattern_data.tracks[track_index].lines[source_line_index]
        
        -- Copy note columns
        for col_index, note_col_data in pairs(source_line.note_columns) do
          if current_track_b.lines[line_index].note_columns[col_index] then
            local note_col = current_track_b.lines[line_index].note_columns[col_index]
            note_col.note_value = note_col_data.note_value
            note_col.instrument_value = note_col_data.instrument_value
            note_col.volume_value = note_col_data.volume_value
            note_col.panning_value = note_col_data.panning_value
            note_col.delay_value = note_col_data.delay_value
            note_col.effect_number_value = note_col_data.effect_number_value
            note_col.effect_amount_value = note_col_data.effect_amount_value
          end
        end
        
        -- Copy effect columns
        for col_index, effect_col_data in pairs(source_line.effect_columns) do
          if current_track_b.lines[line_index].effect_columns[col_index] then
            local effect_col = current_track_b.lines[line_index].effect_columns[col_index]
            effect_col.number_value = effect_col_data.number_value
            effect_col.amount_value = effect_col_data.amount_value
          end
        end
      end
    else
      -- Stored data is longer - copy all lines (only what fits will play)
      for line_index = 1, pattern_a_lines do
        if line_index <= pattern_b_lines then
          local source_line = temp_pattern_data.tracks[track_index].lines[line_index]
          
          -- Copy note columns
          for col_index, note_col_data in pairs(source_line.note_columns) do
            if current_track_b.lines[line_index].note_columns[col_index] then
              local note_col = current_track_b.lines[line_index].note_columns[col_index]
              note_col.note_value = note_col_data.note_value
              note_col.instrument_value = note_col_data.instrument_value
              note_col.volume_value = note_col_data.volume_value
              note_col.panning_value = note_col_data.panning_value
              note_col.delay_value = note_col_data.delay_value
              note_col.effect_number_value = note_col_data.effect_number_value
              note_col.effect_amount_value = note_col_data.effect_amount_value
            end
          end
          
          -- Copy effect columns
          for col_index, effect_col_data in pairs(source_line.effect_columns) do
            if current_track_b.lines[line_index].effect_columns[col_index] then
              local effect_col = current_track_b.lines[line_index].effect_columns[col_index]
              effect_col.number_value = effect_col_data.number_value
              effect_col.amount_value = effect_col_data.amount_value
            end
          end
        end
      end
    end
    
    -- Copy stored automation from A to B
    for _, temp_automation in ipairs(temp_pattern_data.tracks[track_index].automation) do
      local parameter = temp_automation.parameter
      local new_automation = current_track_b:find_automation(parameter)
      if not new_automation then
        new_automation = current_track_b:create_automation(parameter)
      end
      
      -- Clear existing points and add the stored ones
      new_automation:clear()
      for _, point in ipairs(temp_automation.points) do
        new_automation:add_point_at(point.time, point.value)
      end
    end
  end
end

-- Menu entries for Swap Two Pattern Slots function
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}

-- Keybindings for Swap Two Pattern Slots function
renoise.tool():add_keybinding{name="Global:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}

-- MIDI mapping for Swap Two Pattern Slots function
renoise.tool():add_midi_mapping{name="Paketti:Swap Two Pattern Slots",invoke=PakettiSwapTwoPatternSlots}

-- Resize all patterns to current pattern length
function PakettiResizeAllPatternsToCurrentLength()
  local song = renoise.song()
  local current_pattern_index = song.selected_pattern_index
  local current_pattern_length = song.patterns[current_pattern_index].number_of_lines
  
  local patterns_resized = 0
  local total_patterns = #song.patterns
  
  -- Loop through all patterns and resize them to match current pattern length
  for pattern_index = 1, total_patterns do
    local pattern = song.patterns[pattern_index]
    if pattern.number_of_lines ~= current_pattern_length then
      pattern.number_of_lines = current_pattern_length
      patterns_resized = patterns_resized + 1
    end
  end
  
  if patterns_resized > 0 then
    renoise.app():show_status("Resized " .. patterns_resized .. " patterns to " .. current_pattern_length .. " lines (current pattern length)")
  else
    renoise.app():show_status("All patterns already have " .. current_pattern_length .. " lines (current pattern length)")
  end
end

-- Menu entries for Resize All Patterns function
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}

-- Keybindings for Resize All Patterns function
renoise.tool():add_keybinding{name="Global:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}

-- MIDI mapping for Resize All Patterns function
renoise.tool():add_midi_mapping{name="Paketti:Resize All Patterns to Current Length",invoke=PakettiResizeAllPatternsToCurrentLength}

-- Toggle Track Sequence Slot Mute for a specific track at current sequence position
function PakettiToggleTrackSlotMute(track_index)
  local song = renoise.song()
  local sequence_index = song.selected_sequence_index
  local track_num_str = string.format("%02d", track_index)
  
  -- Validate track exists
  if track_index > #song.tracks then
    renoise.app():show_status("Track " .. track_num_str .. " does not exist")
    return
  end
  
  local sequencer = song.sequencer
  local is_muted = sequencer:track_sequence_slot_is_muted(track_index, sequence_index)
  
  -- Toggle the mute state
  sequencer:set_track_sequence_slot_is_muted(track_index, sequence_index, not is_muted)
  
  if is_muted then
    renoise.app():show_status("Track " .. track_num_str .. " Slot Unmuted")
  else
    renoise.app():show_status("Track " .. track_num_str .. " Slot Muted")
  end
end

-- Toggle Track Sequence Slot Mute for all tracks (01-32) at current sequence position
function PakettiToggleAllTrackSlotMute()
  local song = renoise.song()
  local sequence_index = song.selected_sequence_index
  local sequencer = song.sequencer
  local max_tracks = math.min(32, #song.tracks)
  
  if max_tracks == 0 then
    renoise.app():show_status("No tracks to toggle")
    return
  end
  
  for track_index = 1, max_tracks do
    local is_muted = sequencer:track_sequence_slot_is_muted(track_index, sequence_index)
    sequencer:set_track_sequence_slot_is_muted(track_index, sequence_index, not is_muted)
  end
  
  renoise.app():show_status("Toggled Slot Mute for " .. max_tracks .. " tracks")
end

-- Keybindings and MIDI mappings for Toggle Track Slot Mute (01-32)
for i = 1, 32 do
  local track_num_str = string.format("%02d", i)
  
  -- Keybindings
  renoise.tool():add_keybinding{name="Global:Paketti:Toggle Track Slot Mute " .. track_num_str, invoke=function() PakettiToggleTrackSlotMute(i) end}
  renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Toggle Track Slot Mute " .. track_num_str, invoke=function() PakettiToggleTrackSlotMute(i) end}
  
  -- MIDI mappings
  renoise.tool():add_midi_mapping{name="Paketti:Toggle Track Slot Mute " .. track_num_str, invoke=function(message) if message:is_trigger() then PakettiToggleTrackSlotMute(i) end end}
end

-- Keybindings for Toggle All Track Slot Mutes
renoise.tool():add_keybinding{name="Global:Paketti:Toggle All Track Slot Mutes", invoke=PakettiToggleAllTrackSlotMute}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Toggle All Track Slot Mutes", invoke=PakettiToggleAllTrackSlotMute}

-- MIDI mapping for Toggle All Track Slot Mutes
renoise.tool():add_midi_mapping{name="Paketti:Toggle All Track Slot Mutes", invoke=function(message) if message:is_trigger() then PakettiToggleAllTrackSlotMute() end end}

