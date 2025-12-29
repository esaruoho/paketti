-- PakettiTrackInstrumentOrganize.lua
-- Functions to organize tracks and instruments to match each other
-- Workflow: One instrument per track, organized left-to-right (tracks) and top-to-bottom (instruments)

-- Helper: Find the most used instrument in a specific track across all patterns
function PakettiOrganizeFindMostUsedInstrumentInTrack(track_index)
  local song = renoise.song()
  local instrument_counts = {}
  
  -- Scan all patterns for this track
  for pattern_index = 1, #song.patterns do
    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern.tracks[track_index]
    
    if pattern_track then
      for line_index = 1, #pattern_track.lines do
        local line = pattern_track.lines[line_index]
        if line and line.note_columns then
          for note_col_index = 1, #line.note_columns do
            local note_column = line.note_columns[note_col_index]
            if not note_column.is_empty and note_column.instrument_value < 255 then
              local instr_idx = note_column.instrument_value + 1  -- Convert to 1-based
              instrument_counts[instr_idx] = (instrument_counts[instr_idx] or 0) + 1
            end
          end
        end
      end
    end
  end
  
  -- Find the instrument with the highest count
  local max_count = 0
  local most_used_instrument = nil
  
  for instr_idx, count in pairs(instrument_counts) do
    if count > max_count then
      max_count = count
      most_used_instrument = instr_idx
    end
  end
  
  return most_used_instrument, max_count
end

-- Helper: Find which track uses a specific instrument the most
function PakettiOrganizeFindPrimaryTrackForInstrument(instrument_index)
  local song = renoise.song()
  local instr_value = instrument_index - 1  -- Convert to 0-based for pattern data
  local track_counts = {}
  
  -- Scan all patterns and all sequencer tracks
  for pattern_index = 1, #song.patterns do
    local pattern = song.patterns[pattern_index]
    
    for track_index = 1, song.sequencer_track_count do
      local pattern_track = pattern.tracks[track_index]
      
      if pattern_track then
        for line_index = 1, #pattern_track.lines do
          local line = pattern_track.lines[line_index]
          if line and line.note_columns then
            for note_col_index = 1, #line.note_columns do
              local note_column = line.note_columns[note_col_index]
              if not note_column.is_empty and note_column.instrument_value == instr_value then
                track_counts[track_index] = (track_counts[track_index] or 0) + 1
              end
            end
          end
        end
      end
    end
  end
  
  -- Find the track with the highest count
  local max_count = 0
  local primary_track = nil
  
  for track_idx, count in pairs(track_counts) do
    if count > max_count then
      max_count = count
      primary_track = track_idx
    end
  end
  
  return primary_track, max_count
end

-- Build a complete mapping of tracks to their most-used instruments (for debugging)
function PakettiOrganizeBuildTrackToInstrumentMapping()
  local song = renoise.song()
  local mapping = {}
  local used_instruments = {}
  
  print("=== Building Track to Instrument Mapping ===")
  
  for track_index = 1, song.sequencer_track_count do
    local most_used, count = PakettiOrganizeFindMostUsedInstrumentInTrack(track_index)
    local track_name = song.tracks[track_index].name
    
    if most_used then
      mapping[track_index] = {
        instrument = most_used,
        count = count
      }
      used_instruments[most_used] = true
      print(string.format("Track %d (%s) -> Instrument %d (%s), count: %d", 
        track_index, track_name, most_used, song.instruments[most_used].name, count))
    else
      print(string.format("Track %d (%s) -> No instrument used", track_index, track_name))
    end
  end
  
  return mapping, used_instruments
end

-- Build a complete mapping of instruments to their primary tracks (for debugging)
function PakettiOrganizeBuildInstrumentToTrackMapping()
  local song = renoise.song()
  local mapping = {}
  local used_tracks = {}
  
  print("=== Building Instrument to Track Mapping ===")
  
  for instrument_index = 1, #song.instruments do
    local primary_track, count = PakettiOrganizeFindPrimaryTrackForInstrument(instrument_index)
    local instrument_name = song.instruments[instrument_index].name
    
    if primary_track then
      mapping[instrument_index] = {
        track = primary_track,
        count = count
      }
      used_tracks[primary_track] = true
      print(string.format("Instrument %d (%s) -> Track %d (%s), count: %d", 
        instrument_index, instrument_name, primary_track, song.tracks[primary_track].name, count))
    else
      print(string.format("Instrument %d (%s) -> No track uses it", instrument_index, instrument_name))
    end
  end
  
  return mapping, used_tracks
end

-- Organize Instruments by Track Use
-- Reorders instruments so that the instrument most used in track N becomes instrument N
-- After this: Track 1 uses Instrument 1, Track 2 uses Instrument 2, etc.
function PakettiOrganizeInstrumentsByTrackUse()
  local song = renoise.song()
  
  print("=== Organize Instruments by Track Use ===")
  
  -- Check if there's any data to organize
  local has_any_instruments = false
  for track_index = 1, song.sequencer_track_count do
    local most_used = PakettiOrganizeFindMostUsedInstrumentInTrack(track_index)
    if most_used then
      has_any_instruments = true
      break
    end
  end
  
  if not has_any_instruments then
    renoise.app():show_status("No instruments found in any tracks")
    return
  end
  
  local swaps_made = 0
  local max_iterations = #song.instruments * #song.instruments  -- Safety limit
  local iteration = 0
  
  -- Repeat until no more swaps needed
  -- For each track position, find which instrument it uses and move that instrument to match the position
  while iteration < max_iterations do
    iteration = iteration + 1
    local made_swap = false
    
    for position = 1, math.min(song.sequencer_track_count, #song.instruments) do
      -- What instrument does this track currently use?
      local used_instrument = PakettiOrganizeFindMostUsedInstrumentInTrack(position)
      
      if used_instrument and used_instrument ~= position then
        -- Track at position N uses instrument M (where M != N)
        -- We need to swap instruments so that after the swap, track N uses instrument N
        -- swap_instruments_at(N, M) will:
        --   1. Move instrument M to slot N
        --   2. Move instrument N to slot M  
        --   3. Remap all pattern notes accordingly
        -- After swap: track N's notes point to the new slot N (containing what was instrument M)
        
        if used_instrument <= #song.instruments then
          print(string.format("Track %d uses Instrument %d - swapping instruments %d and %d", 
            position, used_instrument, position, used_instrument))
          song:swap_instruments_at(position, used_instrument)
          swaps_made = swaps_made + 1
          made_swap = true
          -- After swap, indices changed, so we restart the scan
          break
        end
      end
    end
    
    if not made_swap then
      break
    end
  end
  
  if swaps_made > 0 then
    renoise.app():show_status(string.format("Organized instruments by track use (%d swaps)", swaps_made))
  else
    renoise.app():show_status("Instruments already organized by track use")
  end
  
  print(string.format("=== Done: %d swaps made ===", swaps_made))
end

-- Organize Tracks by Instrument Box
-- Reorders tracks so that the track that uses instrument N becomes track N
-- After this: Track 1 uses Instrument 1, Track 2 uses Instrument 2, etc.
function PakettiOrganizeTracksByInstrumentBox()
  local song = renoise.song()
  
  print("=== Organize Tracks by Instrument Box ===")
  
  -- Check if there's any data to organize
  local has_any_tracks = false
  for instrument_index = 1, #song.instruments do
    local primary_track = PakettiOrganizeFindPrimaryTrackForInstrument(instrument_index)
    if primary_track then
      has_any_tracks = true
      break
    end
  end
  
  if not has_any_tracks then
    renoise.app():show_status("No track uses any instrument")
    return
  end
  
  local swaps_made = 0
  local max_iterations = song.sequencer_track_count * song.sequencer_track_count
  local iteration = 0
  
  -- Repeat until no more swaps needed
  -- For each instrument position, find which track uses it and move that track to match the position
  while iteration < max_iterations do
    iteration = iteration + 1
    local made_swap = false
    
    for position = 1, math.min(#song.instruments, song.sequencer_track_count) do
      -- Which track currently uses instrument at this position?
      local using_track = PakettiOrganizeFindPrimaryTrackForInstrument(position)
      
      if using_track and using_track ~= position then
        -- Instrument N is used by track M (where M != N)
        -- We need to swap tracks so that after the swap, instrument N is used by track N
        -- swap_tracks_at(N, M) will swap the tracks' positions
        -- Note: Track swapping does NOT remap pattern data - the data moves with the track
        
        if using_track <= song.sequencer_track_count and position <= song.sequencer_track_count then
          print(string.format("Instrument %d is used by Track %d - swapping tracks %d and %d", 
            position, using_track, position, using_track))
          song:swap_tracks_at(position, using_track)
          swaps_made = swaps_made + 1
          made_swap = true
          -- After swap, track positions changed, so we restart the scan
          break
        end
      end
    end
    
    if not made_swap then
      break
    end
  end
  
  if swaps_made > 0 then
    renoise.app():show_status(string.format("Organized tracks by instrument box (%d swaps)", swaps_made))
  else
    renoise.app():show_status("Tracks already organized by instrument box")
  end
  
  print(string.format("=== Done: %d swaps made ===", swaps_made))
end

-- Display current Track/Instrument mapping analysis
function PakettiOrganizeShowAnalysis()
  local song = renoise.song()
  
  print("=== Track/Instrument Organization Analysis ===")
  print("")
  
  -- Show track to instrument mapping
  print("TRACKS -> INSTRUMENTS:")
  print("-----------------------")
  local aligned_count = 0
  local misaligned_tracks = {}
  
  for track_index = 1, song.sequencer_track_count do
    local most_used, count = PakettiOrganizeFindMostUsedInstrumentInTrack(track_index)
    local track_name = song.tracks[track_index].name
    
    if most_used then
      local status = ""
      if most_used == track_index then
        status = "[ALIGNED]"
        aligned_count = aligned_count + 1
      else
        status = string.format("[MISALIGNED: should be instrument %d]", track_index)
        table.insert(misaligned_tracks, {track = track_index, instrument = most_used})
      end
      print(string.format("Track %02d %-20s uses Instrument %02d %-20s (count: %d) %s", 
        track_index, "(" .. track_name .. ")", 
        most_used, "(" .. song.instruments[most_used].name .. ")",
        count, status))
    else
      print(string.format("Track %02d %-20s uses no instrument", track_index, "(" .. track_name .. ")"))
    end
  end
  
  print("")
  print(string.format("Aligned: %d/%d tracks", aligned_count, song.sequencer_track_count))
  print(string.format("Misaligned: %d tracks", #misaligned_tracks))
  print("")
  
  if #misaligned_tracks > 0 then
    print("To fix: Use 'Organize Instruments by Track Use' or 'Organize Tracks by Instrument Box'")
  else
    print("Everything is organized correctly!")
  end
  
  print("=== End Analysis ===")
  
  renoise.app():show_status(string.format("Analysis: %d/%d tracks aligned with instruments", aligned_count, song.sequencer_track_count))
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Track/Instrument Organization..:Organize Instruments by Track Use",
  invoke = PakettiOrganizeInstrumentsByTrackUse
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Track/Instrument Organization..:Organize Tracks by Instrument Box",
  invoke = PakettiOrganizeTracksByInstrumentBox
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Track/Instrument Organization..:Show Analysis (Terminal)",
  invoke = PakettiOrganizeShowAnalysis
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Organize Instruments by Track Use",
  invoke = PakettiOrganizeInstrumentsByTrackUse
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Organize Tracks by Instrument Box",
  invoke = PakettiOrganizeTracksByInstrumentBox
}

-- MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Track/Instrument Organization:Organize Instruments by Track Use",
  invoke = function(message)
    if message:is_trigger() then
      PakettiOrganizeInstrumentsByTrackUse()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Track/Instrument Organization:Organize Tracks by Instrument Box",
  invoke = function(message)
    if message:is_trigger() then
      PakettiOrganizeTracksByInstrumentBox()
    end
  end
}

print("PakettiTrackInstrumentOrganize.lua loaded")
