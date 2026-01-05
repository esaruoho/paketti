function findUsedInstruments()
  local song=renoise.song()
  local used_instruments = {}
  local used_samples = {}
  
  -- Initialize tracking tables for each instrument and sample
  for i=1, #song.instruments do
    used_instruments[i] = false
    used_samples[i] = {}
    for s=1, #song.instruments[i].samples do
      used_samples[i][s] = false
    end
  end
  
  -- Scan through all patterns in the song (OPTIMIZED)
  local pattern_count = 0
  for _, pattern in ipairs(song.patterns) do
    pattern_count = pattern_count + 1
    -- Yield every 10 patterns to prevent script timeout
    if pattern_count % 10 == 0 then
      renoise.app():process_idle()
    end
    for track_idx, track in ipairs(pattern.tracks) do
      -- Skip non-sequencer tracks (master, send tracks can't trigger instruments)
      if song.tracks[track_idx].type == renoise.Track.TRACK_TYPE_SEQUENCER then
        for _, line in ipairs(track.lines) do
          -- Skip empty lines entirely
          if not line.is_empty then
            for _, note_column in ipairs(line.note_columns) do
              -- Skip empty note columns
              if not note_column.is_empty and note_column.instrument_value < 255 then
                local instr_idx = note_column.instrument_value + 1
                used_instruments[instr_idx] = true
                
                if note_column.note_value < 120 then  -- Valid note
                  local instrument = song.instruments[instr_idx]
                  if instrument then
                    for sample_idx, sample in ipairs(instrument.samples) do
                      if sample.sample_mapping then
                        local note_range = sample.sample_mapping.note_range
                        if note_column.note_value >= note_range[1] and 
                           note_column.note_value <= note_range[2] then
                          used_samples[instr_idx][sample_idx] = true
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  return used_instruments, used_samples
end

function calculateTotalSize(unused_list)
  local total_bytes = 0
  for _, item in ipairs(unused_list) do
    if item.sample_buffer and item.sample_buffer.has_sample_data then
      local sample_size = item.sample_buffer.number_of_frames * 
                         item.sample_buffer.number_of_channels * 
                         (item.sample_buffer.bit_depth / 8)
      total_bytes = total_bytes + sample_size
    end
  end
  return total_bytes
end

function formatFileSize(bytes)
  local units = {'B', 'KB', 'MB', 'GB'}
  local unit_index = 1
  local size = bytes
  
  while size > 1024 and unit_index < #units do
    size = size / 1024
    unit_index = unit_index + 1
  end
  
  return string.format("%.2f %s", size, units[unit_index])
end

function saveUnusedSamples()
  local song=renoise.song()
  local used_instruments, used_samples = findUsedInstruments()
  
  -- Build list of unused samples
  local unused_list = {}
  local unused_instruments = {}
  
  for instr_idx, instrument in ipairs(song.instruments) do
    local has_unused_samples = false
    
    if not used_instruments[instr_idx] then
      for sample_idx, sample in ipairs(instrument.samples) do
        if sample.sample_buffer and sample.sample_buffer.has_sample_data then
          table.insert(unused_list, {
            instrument = instrument,
            sample = sample,
            instr_idx = instr_idx,
            sample_idx = sample_idx
          })
        end
      end
      if #instrument.samples > 0 then
        table.insert(unused_instruments, {
          instrument = instrument,
          instr_idx = instr_idx
        })
      end
    else
      for sample_idx, sample in ipairs(instrument.samples) do
        if not used_samples[instr_idx][sample_idx] and 
           sample.sample_buffer and 
           sample.sample_buffer.has_sample_data then
          table.insert(unused_list, {
            instrument = instrument,
            sample = sample,
            instr_idx = instr_idx,
            sample_idx = sample_idx
          })
          has_unused_samples = true
        end
      end
      if has_unused_samples then
        table.insert(unused_instruments, {
          instrument = instrument,
          instr_idx = instr_idx
        })
      end
    end
  end
  
  if #unused_list == 0 then
    renoise.app():show_status("No unused samples found in the song")
    return
  end

  local dialog_title = string.format(
    "Save %d unused samples - Select destination folder",
    #unused_list
  )
  
  local folder_path = renoise.app():prompt_for_path(dialog_title)
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Save operation cancelled")
    return
  end
  
  -- Save samples
  local saved_count = 0
  local current_instrument_index = song.selected_instrument_index
  local current_sample_index = song.selected_sample_index
  
  for _, item in ipairs(unused_list) do
    song.selected_instrument_index = item.instr_idx
    local safe_instr_name = item.instrument.name:gsub("[^%w%s-]", "_")
    local safe_sample_name = item.sample.name:gsub("[^%w%s-]", "_")
    
    local filename = string.format(
      "%s_-_%03d_-_%s.wav",
      safe_instr_name,
      item.sample_idx,
      safe_sample_name
    )
    
    local full_path = folder_path .. "/" .. filename
    song.selected_sample_index = item.sample_idx
    
    if song.selected_sample.sample_buffer:save_as(full_path, "wav") then
      saved_count = saved_count + 1
    end
  end
  
  -- Save unused instruments as XRNI
  local saved_instruments = 0
  for _, item in ipairs(unused_instruments) do
    song.selected_instrument_index = item.instr_idx
    local safe_name = item.instrument.name:gsub("[^%w%s-]", "_")
    local full_path = folder_path .. "/" .. safe_name .. ".xrni"
    
    renoise.app():save_instrument(full_path)
    saved_instruments = saved_instruments + 1
  end
  
  -- Restore original selection
  song.selected_instrument_index = current_instrument_index
  song.selected_sample_index = current_sample_index
  
  renoise.app():show_status(string.format(
    "Saved %d samples and %d instruments to %s",
    saved_count,
    saved_instruments,
    folder_path
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Save Unused Samples (.WAV&.XRNI)",invoke=saveUnusedSamples}
--------
function saveUnusedInstruments()
  local song=renoise.song()
  local used_instruments, _ = findUsedInstruments()
  
  -- Build list of unused instruments
  local unused_instruments = {}
  
  for instr_idx, instrument in ipairs(song.instruments) do
    if not used_instruments[instr_idx] and #instrument.samples > 0 then
      table.insert(unused_instruments, {
        instrument = instrument,
        instr_idx = instr_idx
      })
    end
  end
  
  if #unused_instruments == 0 then
    renoise.app():show_status("No unused instruments found in the song")
    return
  end

  local dialog_title = string.format(
    "Save %d unused instruments - Select destination folder",
    #unused_instruments
  )
  
  local folder_path = renoise.app():prompt_for_path(dialog_title)
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Save operation cancelled")
    return
  end
  
  -- Save instruments
  local saved_count = 0
  local current_instrument_index = song.selected_instrument_index
  
  for _, item in ipairs(unused_instruments) do
    song.selected_instrument_index = item.instr_idx
    local safe_name = item.instrument.name:gsub("[^%w%s-]", "_")
    local filename = string.format(
      "%03d_%s.xrni",
      item.instr_idx,
      safe_name
    )
    local full_path = folder_path .. "/" .. filename
    
    renoise.app():save_instrument(full_path)
    saved_count = saved_count + 1
  end
  
  -- Restore original selection
  song.selected_instrument_index = current_instrument_index
  
  renoise.app():show_status(string.format(
    "Saved %d unused instruments to %s",
    saved_count,
    folder_path
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Save Unused Instruments (.XRNI)",invoke=saveUnusedInstruments}
----
function deleteUnusedInstruments()
  local song=renoise.song()
  local used_instruments, _ = findUsedInstruments()
  
  -- Build list of unused instruments
  local unused_instruments = {}
  
  for instr_idx, instrument in ipairs(song.instruments) do
    if not used_instruments[instr_idx] and #instrument.samples > 0 then
      table.insert(unused_instruments, {
        instrument = instrument,
        instr_idx = instr_idx
      })
    end
  end
  
  if #unused_instruments == 0 then
    renoise.app():show_status("No unused instruments found in the song")
    return
  end

  -- Ask for confirmation before deletion
  local message = string.format(
    "Are you sure you want to delete %d unused instruments?",
    #unused_instruments
  )
  local ok = renoise.app():show_prompt("Delete Unused Instruments", message, {"Yes", "No"})
  if ok ~= "Yes" then
    renoise.app():show_status("Delete operation cancelled")
    return
  end
  
  -- Delete instruments (starting from highest index to avoid reindexing issues)
  table.sort(unused_instruments, function(a, b) return a.instr_idx > b.instr_idx end)
  local deleted_count = 0
  
  for _, item in ipairs(unused_instruments) do
    song:delete_instrument_at(item.instr_idx)
    deleted_count = deleted_count + 1
    -- Yield every 10 deletions to prevent script timeout
    if deleted_count % 10 == 0 then
      renoise.app():process_idle()
    end
  end
  
  renoise.app():show_status(string.format(
    "Deleted %d unused instruments",
    deleted_count
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Delete Unused Instruments",invoke=deleteUnusedInstruments}
---




function findUsedSamples()
  print ("Finding used samples")

  local song = renoise.song()
  local used_samples = {}
  local used_notes = {}
  local used_velocities = {}
  
  -- Initialize tracking tables
  for instr_idx, instrument in ipairs(song.instruments) do
    used_samples[instr_idx] = {}
    used_notes[instr_idx] = {}
    used_velocities[instr_idx] = {}
    for sample_idx = 1, #instrument.samples do
      used_samples[instr_idx][sample_idx] = false
    end
  end
  
  -- First pass: Find notes/velocities from patterns (OPTIMIZED)
  local pattern_count = 0
  for _, pattern in ipairs(song.patterns) do
    pattern_count = pattern_count + 1
    -- Yield every 10 patterns to prevent script timeout
    if pattern_count % 10 == 0 then
      renoise.app():process_idle()
    end
    for track_idx, track in ipairs(pattern.tracks) do
      -- Skip non-sequencer tracks (master, send tracks can't trigger instruments)
      if song.tracks[track_idx].type == renoise.Track.TRACK_TYPE_SEQUENCER then
        for _, line in ipairs(track.lines) do
          -- Skip empty lines entirely
          if not line.is_empty then
            for _, note_col in ipairs(line.note_columns) do
              -- Skip empty note columns
              if not note_col.is_empty then
                local instr_val = note_col.instrument_value
                -- 255 means no instrument specified
                if instr_val ~= 255 then
                  local instr_idx = instr_val + 1
                  if instr_idx > 0 and instr_idx <= #song.instruments then
                    local note_val = note_col.note_value
                    if note_val and note_val < 120 then
                      used_notes[instr_idx][note_val] = true
                      local vol_val = note_col.volume_value
                      if vol_val and vol_val ~= 255 then
                        used_velocities[instr_idx][vol_val] = true
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  -- Check phrases for each instrument (OPTIMIZED)
  for instr_idx, instrument in ipairs(song.instruments) do
    if instrument.phrases and #instrument.phrases > 0 then
      for _, phrase in ipairs(instrument.phrases) do
        for _, line in ipairs(phrase.lines) do
          -- Skip empty lines entirely
          if not line.is_empty then
            for _, note_col in ipairs(line.note_columns) do
              -- Skip empty note columns
              if not note_col.is_empty then
                local note_val = note_col.note_value
                if note_val and note_val < 120 then
                  used_notes[instr_idx][note_val] = true
                  local vol_val = note_col.volume_value
                  if vol_val and vol_val ~= 255 then
                    used_velocities[instr_idx][vol_val] = true
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  -- Second pass: Check each instrument's type and handle accordingly (OPTIMIZED with early exits)
  for instr_idx, instrument in ipairs(song.instruments) do
    -- Skip instruments with no samples
    if #instrument.samples == 0 then
      -- Nothing to check, skip to next instrument
    else
      -- First check for phrases - if instrument has phrases, we need to be more careful
      local has_phrases = instrument.phrases and #instrument.phrases > 0
      
      -- Check for slice markers
      local has_slices = instrument.samples[1].slice_markers and 
                        #instrument.samples[1].slice_markers > 0
      
      if has_slices then
        -- Mark all samples as used in sliced instruments
        for sample_idx = 1, #instrument.samples do
          used_samples[instr_idx][sample_idx] = true
        end
      else
        -- Check if this is a velocity-mapped instrument
        local is_velocity_mapped = false
        if instrument.sample_mappings and #instrument.sample_mappings > 0 then
          for sample_idx = 1, #instrument.samples do
            local mapping = instrument.sample_mappings[1][sample_idx]
            if mapping and mapping.velocity_range and 
               (mapping.velocity_range[1] > 0 or mapping.velocity_range[2] < 127) then
              is_velocity_mapped = true
              break
            end
          end
        end

        -- Handle based on instrument type
        if is_velocity_mapped then
          -- For velocity-mapped instruments, check both note and velocity ranges
          for sample_idx = 1, #instrument.samples do
            -- EARLY EXIT: Skip if sample already marked as used
            if not used_samples[instr_idx][sample_idx] then
              local mapping = instrument.sample_mappings[1][sample_idx]
              if mapping and mapping.note_range then
                local sample_marked = false
                for note in pairs(used_notes[instr_idx]) do
                  if sample_marked then break end
                  if note >= mapping.note_range[1] and note <= mapping.note_range[2] then
                    -- For velocity-mapped samples, check velocity range
                    if has_phrases then
                      -- If instrument has phrases, be more conservative with velocity-mapped samples
                      used_samples[instr_idx][sample_idx] = true
                      sample_marked = true
                    elseif mapping.velocity_range then
                      for vel in pairs(used_velocities[instr_idx]) do
                        if vel >= mapping.velocity_range[1] and vel <= mapping.velocity_range[2] then
                          used_samples[instr_idx][sample_idx] = true
                          sample_marked = true
                          break
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        else
          -- For regular instruments, only check note ranges
          for sample_idx = 1, #instrument.samples do
            -- EARLY EXIT: Skip if sample already marked as used
            if not used_samples[instr_idx][sample_idx] then
              local mapping = instrument.sample_mappings[1][sample_idx]
              if mapping and mapping.note_range then
                for note in pairs(used_notes[instr_idx]) do
                  if note >= mapping.note_range[1] and note <= mapping.note_range[2] then
                    used_samples[instr_idx][sample_idx] = true
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  return used_samples
end


function deleteUnusedSamples(skip_confirmation)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local used_samples = findUsedSamples()
  local total_unused = 0
  
  -- Count unused samples and build a list of what will be deleted
  local samples_to_delete = {}
  for instr_idx, instrument in ipairs(song.instruments) do
    if #instrument.samples > 0 then
      samples_to_delete[instr_idx] = {}
      for sample_idx = 1, #instrument.samples do
        if not used_samples[instr_idx][sample_idx] then
          total_unused = total_unused + 1
          table.insert(samples_to_delete[instr_idx], sample_idx)
        end
      end
    end
  end
  
  if total_unused == 0 then
    renoise.app():show_status("No unused samples found in the song")
    return
  end

  -- If confirmation is needed, show the dialog
  if not skip_confirmation then
    local message = string.format(
      "Found %d samples that appear to be unused.\n" ..
      "This will only remove samples that are unmapped and in instruments that are never triggered.\n" ..
      "Are you sure you want to continue?",
      total_unused
    )
    local ok = renoise.app():show_prompt("Delete Unused Samples", message, {"Yes", "No"})
    if ok ~= "Yes" then
      renoise.app():show_status("Delete operation cancelled")
      return
    end
  end
  
  -- Clear unused sample data (keep slots to preserve mappings)
  local deleted_count = 0
  local operation_count = 0
  for instr_idx = 1, #song.instruments do
    local instrument = song.instruments[instr_idx]
    for sample_idx = 1, #instrument.samples do
      if not used_samples[instr_idx][sample_idx] then
        local sample = instrument.samples[sample_idx]
        if sample.sample_buffer.has_sample_data then
          -- Clear sample data but keep the slot to preserve mappings
          sample.sample_buffer:delete_sample_data()
          -- Create minimal 1-frame placeholder
          sample.sample_buffer:create_sample_data(44100, 16, 1, 1)
          -- Mark as cleared
          sample.name = "EmptiedUnused"
          deleted_count = deleted_count + 1
          operation_count = operation_count + 1
          -- Yield every 10 deletions to prevent script timeout
          if operation_count % 10 == 0 then
            renoise.app():process_idle()
          end
        end
      end
    end
  end
  
  renoise.app():show_status(string.format(
    "Deleted %d unused samples",
    deleted_count
  ))

print("Like I deleted stuff or something")

  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end


renoise.tool():add_keybinding{name="Global:Paketti:Delete Unused Samples",invoke=deleteUnusedSamples}
renoise.tool():add_keybinding{name="Sample Keyzones:Paketti:Delete Unused Samples",invoke=deleteUnusedSamples}
--------

function PakettiClearanceRemoveEmptyTracks()
  local song = renoise.song()
  
  -- Check if we have tracks to work with
  if #song.tracks <= 1 then
    renoise.app():show_status("Cannot remove tracks - song must have at least one track")
    return
  end
  
  local tracks_to_delete = {}
  
  -- Check each track for emptiness across all patterns
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    
    -- Skip master track (cannot be deleted)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      local is_empty_across_all_patterns = true
      
      -- Check if track is empty across all patterns
      for pattern_index = 1, #song.patterns do
        local pattern_track = song.patterns[pattern_index].tracks[track_index]
        if not pattern_track.is_empty then
          is_empty_across_all_patterns = false
          break
        end
      end
      
      if is_empty_across_all_patterns then
        table.insert(tracks_to_delete, track_index)
      end
    end
  end
  
  if #tracks_to_delete == 0 then
    renoise.app():show_status("No empty tracks found")
    return
  end
  
  -- Sort in descending order to avoid reindexing issues
  table.sort(tracks_to_delete, function(a, b) return a > b end)
  
  -- Check if we would delete all regular tracks
  local remaining_regular_tracks = 0
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local will_be_deleted = false
      for _, delete_index in ipairs(tracks_to_delete) do
        if delete_index == track_index then
          will_be_deleted = true
          break
        end
      end
      if not will_be_deleted then
        remaining_regular_tracks = remaining_regular_tracks + 1
      end
    end
  end
  
  if remaining_regular_tracks == 0 then
    renoise.app():show_status("Cannot remove all regular tracks - song must have at least one regular track")
    return
  end
  
  local deleted_count = 0
  for _, track_index in ipairs(tracks_to_delete) do
    song:delete_track_at(track_index)
    deleted_count = deleted_count + 1
  end
  
  renoise.app():show_status(string.format("Removed %d empty tracks", deleted_count))
end

function PakettiClearanceRemoveEmptyTracksAndDSP()
  local song = renoise.song()
  
  -- Check if we have tracks to work with
  if #song.tracks <= 1 then
    renoise.app():show_status("Cannot remove tracks - song must have at least one track")
    return
  end
  
  local tracks_to_delete = {}
  
  -- Check each track for emptiness across all patterns AND no DSP devices
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    
    -- Skip master track (cannot be deleted)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      local is_empty_across_all_patterns = true
      
      -- Check if track is empty across all patterns
      for pattern_index = 1, #song.patterns do
        local pattern_track = song.patterns[pattern_index].tracks[track_index]
        if not pattern_track.is_empty then
          is_empty_across_all_patterns = false
          break
        end
      end
      
      -- Check if track has only the mixer device (device count <= 1 means only mixer)
      local has_no_dsp = #track.devices <= 1
      
      if is_empty_across_all_patterns and has_no_dsp then
        table.insert(tracks_to_delete, track_index)
      end
    end
  end
  
  if #tracks_to_delete == 0 then
    renoise.app():show_status("No empty tracks (with no DSP) found")
    return
  end
  
  -- Sort in descending order to avoid reindexing issues
  table.sort(tracks_to_delete, function(a, b) return a > b end)
  
  -- Check if we would delete all regular tracks
  local remaining_regular_tracks = 0
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local will_be_deleted = false
      for _, delete_index in ipairs(tracks_to_delete) do
        if delete_index == track_index then
          will_be_deleted = true
          break
        end
      end
      if not will_be_deleted then
        remaining_regular_tracks = remaining_regular_tracks + 1
      end
    end
  end
  
  if remaining_regular_tracks == 0 then
    renoise.app():show_status("Cannot remove all regular tracks - song must have at least one regular track")
    return
  end
  
  local deleted_count = 0
  for _, track_index in ipairs(tracks_to_delete) do
    song:delete_track_at(track_index)
    deleted_count = deleted_count + 1
  end
  
  renoise.app():show_status(string.format("Removed %d empty tracks (with no DSP)", deleted_count))
end

renoise.tool():add_keybinding{name="Global:Paketti:Remove Empty Tracks", invoke=PakettiClearanceRemoveEmptyTracks}
renoise.tool():add_keybinding{name="Global:Paketti:Remove Empty Tracks (No Notes, No DSP)", invoke=PakettiClearanceRemoveEmptyTracksAndDSP}
--------

