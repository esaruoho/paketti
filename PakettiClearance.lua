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
  
  -- Scan through all patterns in the song
  for _, pattern in ipairs(song.patterns) do
    for _, track in ipairs(pattern.tracks) do
      for _, line in ipairs(track.lines) do
        for _, note_column in ipairs(line.note_columns) do
          if note_column.instrument_value < 255 then
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
  end
  
  renoise.app():show_status(string.format(
    "Deleted %d unused instruments",
    deleted_count
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Delete Unused Instruments",invoke=deleteUnusedInstruments}
---
function findUsedSamples()
  local song=renoise.song()
  local used_samples = {}
  local used_notes = {}
  
  -- Initialize tables
  for i = 1, #song.instruments do
    used_samples[i] = {}
    used_notes[i] = {}
  end

  -- First pass: Find all notes being played in the song
  for pattern_idx, pattern in ipairs(song.patterns) do
    for track_idx, track in ipairs(pattern.tracks) do
      for line_idx, line in ipairs(track.lines) do
        if line.note_columns then
          for _, note_col in ipairs(line.note_columns) do
            if note_col.note_value then
              local instr_idx = (note_col.instrument_value or 0) + 1
              if instr_idx <= #song.instruments then
                used_notes[instr_idx][note_col.note_value] = true
              end
            end
          end
        end
      end
    end
  end

  -- Additional pass: Check phrases for used notes
  for instr_idx, instrument in ipairs(song.instruments) do
    if instrument.phrases and #instrument.phrases > 0 then
      -- If instrument has any phrases at all, consider all its samples as used
      for sample_idx = 1, #instrument.samples do
        used_samples[instr_idx][sample_idx] = true
        print(string.format("Sample %d in instrument %d is USED - instrument has phrases", 
              sample_idx, instr_idx))
      end
    end
  end

  -- Second pass: Check each sample's mappings
  for instr_idx, notes in pairs(used_notes) do
    local instrument = song.instruments[instr_idx]
    if instrument and instrument.sample_mappings then
      for sample_idx = 1, #instrument.samples do
        local mapping = instrument.sample_mappings[1][sample_idx]
        if mapping then
          -- Print velocity range info first
          print(string.format("DEBUG: Sample %d in instrument %d has velocity range [%d,%d]", 
                sample_idx, instr_idx,
                mapping.velocity_range[1], mapping.velocity_range[2]))

          -- Check if velocity range is [0,0]
          if mapping.velocity_range[1] == 0 and mapping.velocity_range[2] == 0 then
            used_samples[instr_idx][sample_idx] = false
            print(string.format("Sample %d in instrument %d is UNUSED - velocity range is [0,0]", 
                  sample_idx, instr_idx))
          else
            -- Only check note mappings if velocity range is valid
            if mapping.note_range then
              for note_value in pairs(notes) do
                if note_value >= mapping.note_range[1] and 
                   note_value <= mapping.note_range[2] then
                  used_samples[instr_idx][sample_idx] = true
                  print(string.format("Sample %d in instrument %d is USED - mapped to note %s (value %d) with velocity range [%d,%d]", 
                        sample_idx,
                        instr_idx,
                        noteValueToName(note_value), 
                        note_value,
                        mapping.velocity_range[1],
                        mapping.velocity_range[2]))
                end
              end
            end
          end
        end
      end
    end
  end

  return used_samples, used_notes
end


-- Helper function to convert note values to note names
function noteValueToName(value)
  if not value or value < 0 or value > 119 then return "---" end
  local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local octave = math.floor(value / 12)
  local note = value % 12
  return string.format("%s%d", notes[note + 1], octave)
end

function deleteUnusedSamples()
  local function process_samples()
    local song=renoise.song()
    local deleted_count = 0
    local notes_found = 0
    local dialog, vb = ProcessSlicer:create_dialog("Deleting Unused Samples")
    local status_text=""
    
    -- Set the width of the progress text
    vb.views.progress_text.width=300

    local function update_dialog(progress, status, is_error)
      if status then
        if is_error then
          status = "ERROR: " .. status
        end
        status_text = status .. "\n" .. status_text
        local lines = {}
        for line in status_text:gmatch("[^\n]+") do
          table.insert(lines, line)
        end
        if #lines > 8 then
          status_text = table.concat({unpack(lines, 1, 8)}, "\n")
        end
      end
      vb.views.progress_text.text = progress .. "\n\n" .. status_text
      coroutine.yield()
    end

    -- First, find all used notes in the song
    local used_notes = {}
    for i = 1, #song.instruments do
      used_notes[i] = {}
    end

    update_dialog("Scanning for used notes...", nil)
    for pattern_idx, pattern in ipairs(song.patterns) do
      for track_idx, track in ipairs(pattern.tracks) do
        for line_idx, line in ipairs(track.lines) do
          for _, note_col in ipairs(line.note_columns) do
            if note_col.note_value and note_col.instrument_value then
              local instr_idx = note_col.instrument_value + 1
              if instr_idx > 0 and instr_idx <= #song.instruments then
                if not used_notes[instr_idx][note_col.note_value] then
                  notes_found = notes_found + 1
                  used_notes[instr_idx][note_col.note_value] = true
                  if notes_found % 10 == 0 then
                    update_dialog(string.format("Scanning pattern %d/%d... (Found %d notes)", 
                      pattern_idx, #song.patterns, notes_found), nil)
                  end
                end
              end
            end
          end
        end
      end
    end
    update_dialog(string.format("Found %d unique notes in total", notes_found), nil)

    -- Helper function to check if a sample is used by any mappings
    local function is_sample_used(instrument, sample_idx, instr_idx)
      -- Check all velocity layers for mappings that reference this sample
      for layer_idx, layer in ipairs(instrument.sample_mappings) do
        for mapping_idx, mapping in ipairs(layer) do
          -- Check if this mapping points to our sample
          if mapping.sample_index == sample_idx then
            -- Skip mappings with velocity range [0,0] as they're effectively disabled
            if mapping.velocity_range[1] == 0 and mapping.velocity_range[2] == 0 then
              print(string.format("Sample %d has disabled mapping (velocity [0,0])", sample_idx))
            else
              -- Check if any note in the mapping range is used
              if mapping.note_range then
                for note = mapping.note_range[1], mapping.note_range[2] do
                  if used_notes[instr_idx][note] then
                    return true
                  end
                end
              end
            end
          end
        end
      end
      return false
    end

    -- Process each instrument
    for instr_idx, instrument in ipairs(song.instruments) do
      update_dialog(
        string.format("Processing instrument %d/%d", instr_idx, #song.instruments),
        string.format("Checking instrument %d (%s)", instr_idx, instrument.name)
      )
      
      -- Only process instruments that have samples
      if #instrument.samples > 0 then
        -- Check if first sample has slice markers (memory rule about slice handling)
        local first_sample = instrument.samples[1]
        local has_slices = #first_sample.slice_markers > 0
        
        if has_slices then
          update_dialog(
            string.format("Processing instrument %d/%d", instr_idx, #song.instruments),
            string.format("Skipping instrument %d: Contains sliced samples", instr_idx)
          )
        else
          -- Check if instrument is used at all
          local instrument_used = false
          for note, _ in pairs(used_notes[instr_idx]) do
            instrument_used = true
            break
          end

          -- If instrument is not used at all, delete all its samples
          if not instrument_used then
            print(string.format("Instrument %d is completely unused - deleting all samples", instr_idx))
            for sample_idx = #instrument.samples, 1, -1 do
              update_dialog(
                string.format("Processing unused instrument %d/%d", instr_idx, #song.instruments),
                string.format("Deleting sample %d (instrument unused)", sample_idx)
              )
              instrument:delete_sample_at(sample_idx)
              deleted_count = deleted_count + 1
            end
          else
            -- Instrument is used, check each sample individually
            -- Process samples in reverse order to avoid index shifting issues
            for sample_idx = #instrument.samples, 1, -1 do
              update_dialog(
                string.format("Processing instrument %d/%d", instr_idx, #song.instruments),
                string.format("Checking sample %d/%d", sample_idx, #instrument.samples)
              )
              
              local sample = instrument.samples[sample_idx]
              
              -- Only process samples that have actual sample data
              if sample.sample_buffer and sample.sample_buffer.has_sample_data then
                local sample_used = is_sample_used(instrument, sample_idx, instr_idx)
                
                if not sample_used then
                  print(string.format("Deleting unused sample %d in instrument %d", sample_idx, instr_idx))
                  update_dialog(
                    string.format("Processing instrument %d/%d", instr_idx, #song.instruments),
                    string.format("Deleting unused sample %d", sample_idx)
                  )
                  instrument:delete_sample_at(sample_idx)
                  deleted_count = deleted_count + 1
                else
                  print(string.format("Keeping sample %d in instrument %d - it is used", sample_idx, instr_idx))
                end
              else
                -- Sample has no data, safe to delete
                print(string.format("Deleting empty sample %d in instrument %d", sample_idx, instr_idx))
                update_dialog(
                  string.format("Processing instrument %d/%d", instr_idx, #song.instruments),
                  string.format("Deleting empty sample %d", sample_idx)
                )
                instrument:delete_sample_at(sample_idx)
                deleted_count = deleted_count + 1
              end
            end
          end
        end
      end
    end

    -- At completion, just change the Cancel button text to Done
    vb.views.cancel_button.text="Done"
    
    update_dialog(
      deleted_count > 0 
        and string.format("Deleted %d unused samples", deleted_count)
        or "Didn't find any unused samples to delete",
      nil
    )
  end
  local slicer = ProcessSlicer(process_samples)
  slicer:start()
end

renoise.tool():add_keybinding{name="Global:Paketti:Delete Unused Samples",invoke=deleteUnusedSamples}
renoise.tool():add_keybinding{name="Sample Keyzones:Paketti:Delete Unused Samples",invoke=deleteUnusedSamples}
--------
