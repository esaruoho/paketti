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




