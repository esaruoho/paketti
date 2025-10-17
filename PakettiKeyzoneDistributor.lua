local dialog = nil
local view_builder = nil
local debug_mode = true -- Set to true to see what's happening

-- Base note calculation modes
local BASE_NOTE_MODES = {
  ORIGINAL = 1,
  LOWEST = 2,
  MIDDLE = 3,
  HIGHEST = 4
}

local function debug_print(...)
  if debug_mode then
    print(...)
  end
end

-- Helper function to ensure we're in the right view and handle dialog state
local function setup_environment()
  -- If dialog is already open, close it and return false
  if dialog and dialog.visible then
    debug_print("Dialog already open, closing...")
    dialog:close()
    dialog = nil
    return false
  end
  
  -- Ensure we're in the keyzone view
  if renoise.app().window.active_middle_frame ~= 
     renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES then
    renoise.app().window.active_middle_frame = 
      renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES
    debug_print("Switched to keyzone view")
  end
  
  return true
end

-- Function to get base note based on mode
local function get_base_note(start_note, end_note, original_base_note, base_note_mode)
  if base_note_mode == BASE_NOTE_MODES.ORIGINAL then
    return original_base_note
  elseif base_note_mode == BASE_NOTE_MODES.LOWEST then
    return start_note
  elseif base_note_mode == BASE_NOTE_MODES.MIDDLE then
    return math.floor(start_note + (end_note - start_note) / 2)
  else -- BASE_NOTE_MODES.HIGHEST
    return end_note
  end
end

-- Store original positions for transpose calculation
local original_positions = {}

-- Note name to MIDI number conversion
function PakettiKeyzoneDistributorNoteToMidi(note_name, octave)
  local note_map = {
    ["c"] = 0, ["c#"] = 1, ["db"] = 1, ["d"] = 2, ["d#"] = 3, ["eb"] = 3,
    ["e"] = 4, ["f"] = 5, ["f#"] = 6, ["gb"] = 6, ["g"] = 7, ["g#"] = 8,
    ["ab"] = 8, ["a"] = 9, ["a#"] = 10, ["bb"] = 10, ["b"] = 11
  }
  
  local clean_note = string.lower(note_name)
  local note_value = note_map[clean_note]
  
  if note_value == nil then
    return nil
  end
  
  -- Convert octave (Renoise uses 0-9, MIDI uses -1 to 9)
  local midi_note = note_value + (octave * 12) + 12 -- +12 to shift from C-1=0 to C0=12
  
  -- Clamp to valid MIDI range
  return math.max(0, math.min(119, midi_note))
end

-- Parse note name from string (handles c-4, c4, c#4, gs4, bb3, etc.)
function PakettiKeyzoneDistributorParseNoteName(str)
  str = string.lower(str)
  
  -- Handle special cases first: GS = G#, BB = Bb, etc.
  str = str:gsub("gs", "g#")
  str = str:gsub("bb", "bb") -- Keep bb as is, it's already correct
  
  -- Try various note name formats
  local patterns = {
    "([a-g][#b]?)-?([0-9])",    -- c-4, c4, c#4, db-3, etc.
    "([a-g][#b]?)([0-9])",      -- Alternative without dash
    "([a-g][bs])([0-9])",       -- Handle single letter + s for sharp (as4, gs4)
  }
  
  for _, pattern in ipairs(patterns) do
    local note, octave = string.match(str, pattern)
    if note and octave then
      -- Handle single letter + 's' for sharp (gs -> g#, as -> a#)
      if note:match("[a-g]s$") then
        note = note:gsub("s", "#")
      end
      
      local midi_note = PakettiKeyzoneDistributorNoteToMidi(note, tonumber(octave))
      if midi_note then
        return midi_note
      end
    end
  end
  
  return nil
end

-- Parse filename to extract keyrange information
function PakettiKeyzoneDistributorParseFilename(filename)
  debug_print("Parsing filename: " .. filename)
  
  -- Remove file extension
  local name_without_ext = string.match(filename, "(.+)%..+$") or filename
  
  -- Pattern 1: Sample number + target key (01_69, 02_72, etc.)
  -- This should be interpreted as sample order + target key, not as a range
  local sample_num, target_key = string.match(name_without_ext, "^(%d%d?)_(%d%d?%d?)$")
  if sample_num and target_key then
    sample_num = tonumber(sample_num)
    target_key = tonumber(target_key)
    
    if sample_num and target_key and target_key >= 0 and target_key <= 119 then
      debug_print(string.format("Found sample number %d with target key %d", sample_num, target_key))
      return {target_key, target_key, sample_num} -- Return target key twice + sample number for special handling
    end
  end
  
  -- Pattern 2: Actual MIDI ranges (drumhit_48_64, etc. - where first number > 12 or context suggests range)
  local low_midi, high_midi = string.match(name_without_ext, "(%d%d?%d?)_(%d%d?%d?)$")
  if low_midi and high_midi then
    low_midi = tonumber(low_midi)
    high_midi = tonumber(high_midi)
    
    -- Only treat as range if it makes sense (first number is higher, suggesting actual range)
    if low_midi and high_midi and low_midi >= 0 and high_midi <= 119 and low_midi <= high_midi and low_midi > 12 then
      debug_print(string.format("Found MIDI range: %d-%d", low_midi, high_midi))
      return {low_midi, high_midi}
    end
  end
  
  -- Pattern 2: Single MIDI number at the end (01_64, sample_72, etc.)
  local single_midi = string.match(name_without_ext, "_(%d%d?%d?)$")
  if single_midi then
    single_midi = tonumber(single_midi)
    if single_midi and single_midi >= 0 and single_midi <= 119 then
      debug_print(string.format("Found single MIDI note: %d", single_midi))
      return {single_midi, single_midi}
    end
  end
  
  -- Pattern 3: Note range (c-4_g-4, c4_g4, etc.)
  local note_patterns = {
    "([a-g][#b]?-?%d)_([a-g][#b]?-?%d)",  -- c-4_g-4, c4_g4
    "([a-g][#b]?%d)_([a-g][#b]?%d)"       -- Alternative format
  }
  
  for _, pattern in ipairs(note_patterns) do
    local note1, note2 = string.match(string.lower(name_without_ext), pattern)
    if note1 and note2 then
      local midi1 = PakettiKeyzoneDistributorParseNoteName(note1)
      local midi2 = PakettiKeyzoneDistributorParseNoteName(note2)
      
      if midi1 and midi2 then
        local low_note = math.min(midi1, midi2)
        local high_note = math.max(midi1, midi2)
        debug_print(string.format("Found note range: %s_%s = %d-%d", note1, note2, low_note, high_note))
        return {low_note, high_note}
      end
    end
  end
  
  -- Pattern 4: Single note name with underscore (01_c-4, sample_g4, etc.)
  local single_note = string.match(string.lower(name_without_ext), "_([a-g][#b]?-?%d)$")
  if single_note then
    local midi_note = PakettiKeyzoneDistributorParseNoteName(single_note)
    if midi_note then
      debug_print(string.format("Found single note with underscore: %s = %d", single_note, midi_note))
      return {midi_note, midi_note}
    end
  end
  
  -- Pattern 5: Note directly attached to end without underscore (kickA4, snareGS4, hatBB3, etc.)
  local direct_patterns = {
    "([a-g][sb])(%d)$",           -- gs4, as4, bb3 (two-letter combinations)
    "([a-g][#b])(%d)$",           -- c#4, db3 (sharp/flat)
    "([a-g])(%d)$"                -- c4, a4 (single letter)
  }
  
  for _, pattern in ipairs(direct_patterns) do
    local note_part, octave_part = string.match(string.lower(name_without_ext), pattern)
    if note_part and octave_part then
      local note_string = note_part .. octave_part
      local midi_note = PakettiKeyzoneDistributorParseNoteName(note_string)
      if midi_note then
        debug_print(string.format("Found direct attached note: %s = %d", note_string, midi_note))
        return {midi_note, midi_note}
      end
    end
  end
  
  -- Pattern 6: Note with dash but no underscore (kick-bb3, sample-c#4, etc.)
  local dash_patterns = {
    "-([a-g][sb])(%d)$",          -- -gs4, -bb3
    "-([a-g][#b])(%d)$",          -- -c#4, -db3  
    "-([a-g])(%d)$"               -- -c4, -a4
  }
  
  for _, pattern in ipairs(dash_patterns) do
    local note_part, octave_part = string.match(string.lower(name_without_ext), pattern)
    if note_part and octave_part then
      local note_string = note_part .. octave_part
      local midi_note = PakettiKeyzoneDistributorParseNoteName(note_string)
      if midi_note then
        debug_print(string.format("Found dash note: %s = %d", note_string, midi_note))
        return {midi_note, midi_note}
      end
    end
  end
  
  debug_print("No keyrange found in filename")
  return nil
end

-- Function to store original keyzone positions
function PakettiKeyzoneDistributorStoreOriginalPositions()
  local instrument = renoise.song().selected_instrument
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  original_positions = {}
  for idx, sample in ipairs(instrument.samples) do
    local smap = sample.sample_mapping
    original_positions[idx] = {
      base_note = smap.base_note,
      note_range = {smap.note_range[1], smap.note_range[2]}
    }
  end
  debug_print("Stored original positions for " .. #original_positions .. " samples")
end

-- Scan folder and collect file information with keyrange detection
function PakettiKeyzoneDistributorScanFolder(folder_path)
  local file_info_list = {}
  
  -- Get all audio files in the directory
  local files = PakettiGetFilesInDirectory(folder_path)
  
  if not files or #files == 0 then
    debug_print("No audio files found in folder: " .. folder_path)
    return file_info_list
  end
  
  debug_print(string.format("Scanning %d audio files for keyrange information...", #files))
  
  local instrument_groups = {}      -- Grouped by instrument number (01_, 02_, etc.)
  local regular_files = {}          -- For other files
  
  for _, file_path in ipairs(files) do
    -- Extract just the filename from the full path
    local filename = string.match(file_path, "([^/\\]+)$") or file_path
    
    -- Parse the filename for keyrange information
    local keyrange = PakettiKeyzoneDistributorParseFilename(filename)
    
    -- Create file info entry
    local file_info = {
      full_path = file_path,
      filename = filename,
      keyrange = keyrange,
      enabled = true  -- Default to enabled
    }
    
    -- Check if this is a sample-numbered file (has 3 elements: low, high, sample_num)
    if keyrange and #keyrange == 3 then
      file_info.instrument_number = keyrange[3]
      file_info.target_key = keyrange[1]
      
      -- Group by instrument number
      if not instrument_groups[file_info.instrument_number] then
        instrument_groups[file_info.instrument_number] = {}
      end
      table.insert(instrument_groups[file_info.instrument_number], file_info)
    else
      table.insert(regular_files, file_info)
    end
  end
  
  -- Process each instrument group to create continuous ranges
  local processed_files = {}
  
  for instrument_num, files_in_group in pairs(instrument_groups) do
    -- Sort files by target key within each instrument group
    table.sort(files_in_group, function(a, b)
      return a.target_key < b.target_key
    end)
    
    debug_print(string.format("Processing instrument %02d with %d files", instrument_num, #files_in_group))
    
    -- Create continuous ranges for this instrument
    for i, file_info in ipairs(files_in_group) do
      if i == 1 then
        -- First sample in this instrument: map from 0 to its target key
        file_info.keyrange = {0, file_info.target_key}
        debug_print(string.format("Instrument %02d, file %d (%s): First sample, mapping 0-%d", 
          instrument_num, i, file_info.filename, file_info.target_key))
      else
        -- Subsequent samples: map from current target key to next target key - 1 (or 119 if last)
        local start_key = file_info.target_key
        local end_key
        
        if i < #files_in_group then
          -- Not the last file - map up to next target key - 1
          end_key = files_in_group[i + 1].target_key - 1
        else
          -- Last file - map to 119
          end_key = 119
        end
        
        file_info.keyrange = {start_key, end_key}
        debug_print(string.format("Instrument %02d, file %d (%s): mapping %d-%d", 
          instrument_num, i, file_info.filename, start_key, end_key))
      end
      
      table.insert(processed_files, file_info)
    end
  end
  
  -- Sort processed files by instrument number, then by target key
  table.sort(processed_files, function(a, b)
    if a.instrument_number == b.instrument_number then
      return a.target_key < b.target_key
    end
    return a.instrument_number < b.instrument_number
  end)
  
  -- Combine processed instrument files with regular files
  for _, file_info in ipairs(processed_files) do
    table.insert(file_info_list, file_info)
  end
  for _, file_info in ipairs(regular_files) do
    table.insert(file_info_list, file_info)
  end
  
  debug_print(string.format("Found keyrange information for %d files (%d instrument-grouped, %d regular)", 
    #file_info_list, #processed_files, #regular_files))
  
  return file_info_list
end

-- Generate text representation of file list for multiline display
function PakettiKeyzoneDistributorGenerateFileListText(file_info_list)
  local text_lines = {}
  
  for i, file_info in ipairs(file_info_list) do
    local status = file_info.enabled and "[x]" or "[ ]"
    local keyrange_text = "No range detected"
    
    if file_info.keyrange then
      if file_info.keyrange[1] == file_info.keyrange[2] then
        keyrange_text = string.format("Note %d", file_info.keyrange[1])
      else
        keyrange_text = string.format("Range %d-%d", file_info.keyrange[1], file_info.keyrange[2])
      end
      
      -- Add instrument info for grouped files
      if file_info.instrument_number then
        keyrange_text = keyrange_text .. string.format(" (Inst %02d)", file_info.instrument_number)
      end
    end
    
    local line = string.format("%s %s | %s", status, file_info.filename, keyrange_text)
    table.insert(text_lines, line)
  end
  
  return table.concat(text_lines, "\n")
end

-- Function to apply Paketti loader preferences to a sample
function PakettiKeyzoneDistributorApplyLoaderSettings(sample)
  if not sample or not preferences then return end
  
  sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = preferences.pakettiLoaderLoopExit.value
  
  debug_print(string.format("Applied Paketti loader settings to sample: %s", sample.name))
end

-- Function to apply special processing options
function PakettiKeyzoneDistributorApplyProcessingOptions(sample)
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then return end
  
  -- Move silence to end if enabled
  if preferences.pakettiLoaderMoveSilenceToEnd and preferences.pakettiLoaderMoveSilenceToEnd.value then
    pakettiSampleBufferMoveSilenceToEnd()
    debug_print(string.format("Moved silence to end for sample: %s", sample.name))
  end
  
  -- Normalize sample if enabled
  if preferences.pakettiLoaderNormalizeSamples and preferences.pakettiLoaderNormalizeSamples.value then
    sample.sample_buffer:prepare_sample_data_changes()
    sample.sample_buffer:normalize()
    sample.sample_buffer:finalize_sample_data_changes()
    debug_print(string.format("Normalized sample: %s", sample.name))
  end
end

-- Load samples from folder and apply filename-based keyrange mapping
function PakettiKeyzoneDistributorApplyFilenameMapping(file_info_list)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  if #file_info_list == 0 then
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    renoise.app():show_status("No files to load!")
    return
  end
  
  debug_print(string.format("Loading and mapping %d files", #file_info_list))
  
  -- Group files by instrument number
  local instrument_groups = {}
  local regular_files = {}
  
  for _, file_info in ipairs(file_info_list) do
    if file_info.enabled and file_info.keyrange and file_info.full_path then
      if file_info.instrument_number then
        -- Group by instrument number
        if not instrument_groups[file_info.instrument_number] then
          instrument_groups[file_info.instrument_number] = {}
        end
        table.insert(instrument_groups[file_info.instrument_number], file_info)
      else
        table.insert(regular_files, file_info)
      end
    end
  end
  
  local total_loaded = 0
  local total_mapped = 0
  local total_failed = 0
  local instruments_created = 0
  local song = renoise.song()
  local starting_instrument_index = song.selected_instrument_index
  
  -- Process each instrument group
  for instrument_num, files_in_group in pairs(instrument_groups) do
    debug_print(string.format("Creating instrument for group %02d with %d files", instrument_num, #files_in_group))
    
    -- Create a new instrument after the current selected instrument
    local new_instrument_index = starting_instrument_index + instruments_created + 1
    local new_instrument = song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    instruments_created = instruments_created + 1
    
    -- Load default XRNI configuration first
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      debug_print("Applied pakettiPreferencesDefaultInstrumentLoader")
      -- Re-get the instrument reference after loading default configuration
      new_instrument = song.selected_instrument
    else
      debug_print("pakettiPreferencesDefaultInstrumentLoader not found")
    end
    
    local loaded_count = 0
    local mapped_count = 0
    local failed_count = 0
    
    -- Sort files in this group by target key
    table.sort(files_in_group, function(a, b)
      return a.target_key < b.target_key
    end)
    
    -- Generate instrument name from first and last filenames
    local first_filename = files_in_group[1].filename:match("(.+)%..+$") or files_in_group[1].filename
    local last_filename = files_in_group[#files_in_group].filename:match("(.+)%..+$") or files_in_group[#files_in_group].filename
    new_instrument.name = string.format("%s-%s", first_filename, last_filename)
    
    -- Load samples into this instrument
    for i, file_info in ipairs(files_in_group) do
      debug_print(string.format("Loading file %d into instrument %02d: %s", i, instrument_num, file_info.full_path))
      
      -- Try to load the sample
      local success, error_msg = pcall(function()
        local new_sample = new_instrument:insert_sample_at(#new_instrument.samples + 1)
        new_sample.sample_buffer:load_from(file_info.full_path)
        loaded_count = loaded_count + 1
        
        -- Apply keyzone mapping immediately after loading
        local smap = new_sample.sample_mapping
        local low_note = file_info.keyrange[1]
        local high_note = file_info.keyrange[2]
        
        -- Set the keyzone range
        smap.note_range = {low_note, high_note}
        
        -- Set base note to the target key from filename (the original pitch of the sample)
        local base_note
        if file_info.target_key then
          -- For instrument-grouped files (01_69, etc.), use the target key from filename
          base_note = file_info.target_key
        else
          -- For other files, use middle of range as fallback
          base_note = math.floor(low_note + (high_note - low_note) / 2)
        end
        smap.base_note = base_note
        
        -- Set sample name to filename (without extension)
        local filename_only = string.match(file_info.filename, "(.+)%..+$") or file_info.filename
        new_sample.name = filename_only
        
        local base_note_source = file_info.target_key and "filename" or "range middle"
        debug_print(string.format("Instrument %02d, Sample %d (%s): loaded and mapped to %d-%d (base: %d from %s)", 
          instrument_num, i, file_info.filename, low_note, high_note, base_note, base_note_source))
        
        mapped_count = mapped_count + 1
      end)
      
      if not success then
        failed_count = failed_count + 1
        debug_print(string.format("Failed to load %s: %s", file_info.filename, tostring(error_msg)))
        print("Error loading sample: " .. tostring(error_msg))
      end
    end
    
    -- Clean up any "Placeholder sample" left behind
    for i = #new_instrument.samples, 1, -1 do
      if new_instrument.samples[i].name == "Placeholder sample" then
        new_instrument:delete_sample_at(i)
        debug_print("Removed placeholder sample")
      end
    end
    
    -- Apply Paketti Loader Settings to all samples
    for i, sample in ipairs(new_instrument.samples) do
      PakettiKeyzoneDistributorApplyLoaderSettings(sample)
      PakettiKeyzoneDistributorApplyProcessingOptions(sample)
    end
    
    total_loaded = total_loaded + loaded_count
    total_mapped = total_mapped + mapped_count
    total_failed = total_failed + failed_count
    
    debug_print(string.format("Instrument %02d complete: %d loaded, %d mapped, %d failed", 
      instrument_num, loaded_count, mapped_count, failed_count))
  end
  
  -- Handle regular files in current selected instrument if any
  if #regular_files > 0 then
    local current_instrument = song.selected_instrument
    if current_instrument then
      debug_print(string.format("Loading %d regular files into current instrument", #regular_files))
      
      -- Clear existing samples first
      while #current_instrument.samples > 0 do
        current_instrument:delete_sample_at(1)
      end
      
      for i, file_info in ipairs(regular_files) do
        local success, error_msg = pcall(function()
          local new_sample = current_instrument:insert_sample_at(#current_instrument.samples + 1)
          new_sample.sample_buffer:load_from(file_info.full_path)
          
          local smap = new_sample.sample_mapping
          local low_note = file_info.keyrange[1]
          local high_note = file_info.keyrange[2]
          smap.note_range = {low_note, high_note}
          smap.base_note = math.floor(low_note + (high_note - low_note) / 2)
          
          local filename_only = string.match(file_info.filename, "(.+)%..+$") or file_info.filename
          new_sample.name = filename_only
          
          -- Apply Paketti Loader Settings
          PakettiKeyzoneDistributorApplyLoaderSettings(new_sample)
          PakettiKeyzoneDistributorApplyProcessingOptions(new_sample)
          
          total_loaded = total_loaded + 1
          total_mapped = total_mapped + 1
        end)
        
        if not success then
          total_failed = total_failed + 1
        end
      end
    end
  end
  
  -- Store the new positions as original for transpose
  PakettiKeyzoneDistributorStoreOriginalPositions()
  
  local status_msg = string.format("Created %d instruments, loaded %d samples, mapped %d ranges", 
    instruments_created, total_loaded, total_mapped)
  
  if total_failed > 0 then
    status_msg = status_msg .. string.format(" (%d failed)", total_failed)
  end
  
  renoise.app():show_status(status_msg)
  debug_print(string.format("Loading complete: %d instruments created, %d loaded, %d mapped, %d failed", 
    instruments_created, total_loaded, total_mapped, total_failed))
end



-- Function to transpose from original positions (not cumulative)
local function transpose_keyzones(transpose_by)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  if #original_positions == 0 then
    PakettiKeyzoneDistributorStoreOriginalPositions()
  end
  
  debug_print(string.format("Transposing %d samples by %d semitones from original", #instrument.samples, transpose_by))
  
  local samples_transposed = 0
  local samples_clamped = 0
  local clamp_info = {}
  
  for idx, sample in ipairs(instrument.samples) do
    if original_positions[idx] then
      local smap = sample.sample_mapping
      local orig = original_positions[idx]
      
      local new_base_note = orig.base_note + transpose_by
      local new_note_range_start = orig.note_range[1] + transpose_by
      local new_note_range_end = orig.note_range[2] + transpose_by
      
      -- Clamp to MIDI range (0-119) instead of skipping
      local clamped_base_note = math.max(0, math.min(119, new_base_note))
      local clamped_range_start = math.max(0, math.min(119, new_note_range_start))
      local clamped_range_end = math.max(0, math.min(119, new_note_range_end))
      
      -- Ensure range is valid (start <= end)
      if clamped_range_start > clamped_range_end then
        clamped_range_end = clamped_range_start
      end
      
      -- Track if any clamping occurred
      local was_clamped = (clamped_base_note ~= new_base_note) or 
                         (clamped_range_start ~= new_note_range_start) or 
                         (clamped_range_end ~= new_note_range_end)
      
      -- Apply the (possibly clamped) values
      smap.base_note = clamped_base_note
      smap.note_range = {clamped_range_start, clamped_range_end}
      samples_transposed = samples_transposed + 1
      
      if was_clamped then
        samples_clamped = samples_clamped + 1
        table.insert(clamp_info, string.format("Sample %d clamped to %d-%d", idx, clamped_range_start, clamped_range_end))
        debug_print(string.format("Sample %d clamped to notes %d-%d (base: %d)", idx, clamped_range_start, clamped_range_end, clamped_base_note))
      else
        debug_print(string.format("Sample %d transposed to notes %d-%d (base: %d)", idx, clamped_range_start, clamped_range_end, clamped_base_note))
      end
    end
  end
  
  -- Show meaningful status message
  if samples_clamped > 0 then
    renoise.app():show_status(string.format("Transposed %d samples by %d semitones (%d clamped to MIDI limits)", 
      samples_transposed, transpose_by, samples_clamped))
    print(string.format("-- Paketti Transpose: %d samples clamped to MIDI range (0-119)", samples_clamped))
  elseif samples_transposed > 0 then
    renoise.app():show_status(string.format("Transposed %d samples by %d semitones", samples_transposed, transpose_by))
  else
    renoise.app():show_status("No samples to transpose")
  end
end

-- Function to distribute samples across velocity layers
local function distribute_velocity_layers(first_is_loudest, min_velocity, max_velocity, layer_count)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  local custom_count = layer_count or #instrument.samples
  debug_print(string.format("Distributing %d samples across velocity layers (count: %d)", #instrument.samples, custom_count))
  
  -- Scale function for velocity ranges
  local function scale_value(value, in_min, in_max, out_min, out_max)
    return (((value - in_min) * (out_max / (in_max - in_min) - (out_min / (in_max - in_min)))) + out_min)
  end
  
  for idx = 1, #instrument.samples do
    local idx_custom = idx
    if custom_count then
      idx_custom = idx % custom_count
      if idx_custom == 0 then
        idx_custom = custom_count
      end
    end
    
    local sample = instrument.samples[idx]
    local smap = sample.sample_mapping
    
    local vel_from, vel_to
    if first_is_loudest then
      vel_from = (128 / custom_count) * (idx_custom - 1)   
      vel_to = ((128 / custom_count) * idx_custom) - 1
    else
      vel_from = (128 / custom_count) * (custom_count - idx_custom)
      vel_to = (128 / custom_count) * (custom_count - (idx_custom - 1)) - 1
    end
    
    vel_from = scale_value(vel_from, 0, 128, min_velocity, max_velocity)
    vel_to = scale_value(vel_to, 0, 128, min_velocity, max_velocity)
    
    -- Clamp to valid velocity range
    vel_from = math.max(0, math.min(127, math.floor(vel_from)))
    vel_to = math.max(0, math.min(127, math.floor(vel_to)))
    
    smap.velocity_range = {vel_from, vel_to}
    
    debug_print(string.format("Sample %d velocity range: %d-%d", idx, vel_from, vel_to))
  end
  
  renoise.app():show_status(string.format("Distributed %d samples across velocity layers", #instrument.samples))
end

-- Function to distribute samples across keyzones
local function distribute_samples(keys_per_sample, base_note_mode)
  local instrument = renoise.song().selected_instrument
  
  if not instrument then
    renoise.app():show_warning("No instrument selected!")
    return
  end
  
  -- Get fresh sample count
  local num_samples = #instrument.samples
  
  if num_samples == 0 then
    renoise.app():show_warning("No samples in instrument!")
    return
  end
  
  -- Clear original positions when distributing fresh
  original_positions = {}
  
  debug_print(string.format("Distributing %d samples with %d keys each", num_samples, keys_per_sample))
  
  -- For each sample, update its mapping to the new range
  local mapped_samples = 0
  local reached_limit = false
  
  for sample_idx = 1, num_samples do
    local sample = instrument.samples[sample_idx]
    if sample then
      -- Calculate the new note range (starting from C-0 which is note 0)
      local start_note = (sample_idx - 1) * keys_per_sample
      local end_note = start_note + (keys_per_sample - 1)
      
      -- Check if we would exceed the MIDI range
      if start_note > 119 then
        -- We've reached the limit, stop mapping
        debug_print(string.format("Sample %d would start at note %d (>119), stopping", sample_idx, start_note))
        break
      end
      
      -- Clamp end_note to valid range
      if end_note > 119 then
        end_note = 119
        reached_limit = true
        debug_print(string.format("Sample %d end note clamped from %d to 119", sample_idx, start_note + (keys_per_sample - 1)))
      end
      
      -- Ensure start_note is also within valid range (safety check)
      start_note = math.max(0, math.min(119, start_note))
      end_note = math.max(0, math.min(119, end_note))
      
      -- Ensure start_note <= end_note
      if start_note > end_note then
        debug_print(string.format("Sample %d: start_note (%d) > end_note (%d), skipping", sample_idx, start_note, end_note))
        break
      end
      
      -- Get the original base note before we change anything
      local original_base_note = sample.sample_mapping.base_note
      
      -- Update the mapping range
      sample.sample_mapping.note_range = {
        start_note,  -- Start note (C-0 based)
        end_note     -- End note
      }
      
      -- Set base note according to selected mode
      local new_base_note = get_base_note(start_note, end_note, original_base_note, base_note_mode)
      -- Clamp base note to valid range
      new_base_note = math.max(0, math.min(119, new_base_note))
      sample.sample_mapping.base_note = new_base_note
      
      mapped_samples = mapped_samples + 1
      
      debug_print(string.format(
        "Sample %d mapped to notes %d-%d with base note %d",
        sample_idx, start_note, end_note, new_base_note
      ))
      
      -- If we reached the limit, stop processing more samples
      if reached_limit then
        debug_print(string.format("Reached MIDI range limit at sample %d", sample_idx))
        break
      end
    else
      debug_print(string.format("Sample %d no longer exists, skipping", sample_idx))
    end
  end
  
  -- Store the new positions as original for transpose
  PakettiKeyzoneDistributorStoreOriginalPositions()
  
  -- Show appropriate status message
  if reached_limit then
    renoise.app():show_status(string.format(
      "Mapped %d samples (%d keys each, last sample fit to maximum)",
      mapped_samples, keys_per_sample
    ))
  else
    renoise.app():show_status(string.format(
      "Distributed %d samples across %d keys each",
      mapped_samples, keys_per_sample
    ))
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Show or toggle the Keyzone Distributor dialog
function pakettiKeyzoneDistributorDialog()
  -- Check environment and handle dialog state
  if not setup_environment() then return end
  
  debug_print("Creating new Keyzone Distributor dialog")
  
  -- Build the UI
  view_builder = renoise.ViewBuilder()
  
  local base_note_mode = BASE_NOTE_MODES.MIDDLE -- Default mode
  local enhanced_mode = false -- Default to simple mode
  
  -- Enhanced mode variables
  local transpose_value = 0
  local velocity_enabled = false
  local first_is_loudest = true
  local min_velocity = 0
  local max_velocity = 127
  local layer_count = nil -- nil means use all samples
  
  -- Filename-based mapping variables
  local current_file_list = {}
  local selected_folder = ""
  
  -- Function to update velocity layers automatically
  local function update_velocity_layers()
    if velocity_enabled then
      distribute_velocity_layers(first_is_loudest, min_velocity, max_velocity, layer_count)
    end
  end
  
  local keys_valuebox = view_builder:valuebox {
    min = 1,
    max = 120, -- Allow full MIDI range per sample
    value = 1, -- Default to single key per sample
    width=50,
    notifier=function(new_value)
      distribute_samples(new_value, base_note_mode)
    end
  }
  
  -- Create quick set buttons
  local function create_quick_set_button(value)
    return view_builder:button {
      text = tostring(value),
      width=35,
      notifier=function()
        keys_valuebox.value = value
        distribute_samples(value, base_note_mode)
      end
    }
  end
  
  local base_note_switch = view_builder:switch {
    width=300,
    items = {"Original", "Lowest Note", "Middle Note", "Highest Note"},
    value = base_note_mode,
    notifier=function(new_mode)
      base_note_mode = new_mode
      -- Redistribute with current keys value but new base note mode
      distribute_samples(keys_valuebox.value, new_mode)
    end
  }
  
  -- Enhanced controls (initially hidden)
  local enhanced_controls = view_builder:column {
    id = "enhanced_section",
    visible = false,
    
    view_builder:row {
      view_builder:text {
        text = "─── Transpose ───",
        style = "strong",
        width = 200
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Transpose by",
        font = "bold",
        style = "strong",
      },
              view_builder:valuebox {
          min = -60,
          max = 60,
          value = 0,
          width = 50,
          id = "transpose_valuebox",
          notifier = function(new_value)
            transpose_value = new_value
          end
        },
        view_builder:button {
          text = "Apply",
          width = 60,
          notifier = function()
            transpose_keyzones(transpose_value)
          end
        },
      view_builder:text {
        text = "semitones"
      }
    },
    
    view_builder:row {
      view_builder:text {
        text = "─── Velocity Layers ───",
        style = "strong",
        width = 200
      }
    },
    
    view_builder:row {
      view_builder:checkbox {
        value = false,
        id = "velocity_checkbox",
        notifier = function(value)
          velocity_enabled = value
          update_velocity_layers()
        end
      },
      view_builder:text {
        text = "Enable velocity distribution"
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Direction",
        font = "bold",
        style = "strong",
      },
      view_builder:switch {
        items = {"First Loudest", "First Softest"},
        value = 1,
        width = 200,
        notifier = function(value)
          first_is_loudest = (value == 1)
          update_velocity_layers()
        end
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Velocity range",
        font = "bold", 
        style = "strong",
      },
      view_builder:valuebox {
        min = 0,
        max = 127,
        value = 0,
        width = 50,
        notifier = function(value)
          min_velocity = value
          update_velocity_layers()
        end
      },
      view_builder:text { text = "to" },
      view_builder:valuebox {
        min = 0,
        max = 127,
        value = 127,
        width = 50,
        notifier = function(value)
          max_velocity = value
          update_velocity_layers()
        end
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Layer count",
        font = "bold",
        style = "strong",
      },
      view_builder:switch {
        items = {"All Samples", "Custom"},
        value = 1,
        width = 150,
        notifier = function(value)
          layer_count = (value == 1) and nil or 4
          update_velocity_layers()
        end
      },
      view_builder:valuebox {
        min = 1,
        max = 16,
        value = 4,
        width = 50,
        visible = false,
        id = "layer_count_valuebox",
        notifier = function(value)
          if layer_count then
            layer_count = value
            update_velocity_layers()
          end
        end
      }
    },
    
    view_builder:row {
      view_builder:text {
        text = "─── Filename-Based Mapping ───",
        style = "strong",
        width = 200
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Select Folder",
        font = "bold",
        style = "strong",
      },
      view_builder:button {
        text = "Browse...",
        width = 80,
        notifier = function()
          local folder = renoise.app():prompt_for_path("Select folder containing samples")
          if folder and folder ~= "" then
            selected_folder = folder
            current_file_list = PakettiKeyzoneDistributorScanFolder(folder)
            
            -- Update the multiline text with the file list
            local file_list_text = view_builder.views.file_list_multiline
            if file_list_text then
              file_list_text.text = PakettiKeyzoneDistributorGenerateFileListText(current_file_list)
            end
            
            renoise.app():show_status(string.format("Scanned %d files from folder", #current_file_list))
          end
        end
      },
      view_builder:text {
        text = "← Browse for samples folder",
        style = "disabled"
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Detected Files",
        font = "bold",
        style = "strong",
      },
      view_builder:multiline_text {
        width = 400,
        height = 120,
                  text = "No folder selected...\n\nThis will create multiple instruments.\n\nSupported filename patterns:\n• 00_59, 00_60... → Creates \"00_59-00_79\" with keyzones\n• 01_59, 01_60... → Creates \"01_59-01_79\" with keyzones\n• 02_72, 02_75... → Creates \"02_72-02_89\" with keyzones\n• etc.\n\n• drumhit_48_64 (MIDI range) → Current instrument\n• sample_c4_g4 (note range) → Current instrument",
        font = "mono",
        id = "file_list_multiline"
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Create Instruments",
        font = "bold",
        style = "strong",
      },
              view_builder:button {
          text = "Create Instruments",
          width = 120,
        notifier = function()
          if #current_file_list == 0 then
            renoise.app():show_status("No files scanned. Please select a folder first.")
            return
          end
          
          PakettiKeyzoneDistributorApplyFilenameMapping(current_file_list)
        end
      },
      view_builder:text {
        text = "← Create instruments from grouped samples"
      }
    },

  }
  
  -- Enhanced mode toggle
  local enhanced_checkbox = view_builder:checkbox {
    value = false,
    notifier = function(value)
      enhanced_mode = value
      enhanced_controls.visible = value
      debug_print("Enhanced mode: " .. tostring(value))
    end
  }
  
  -- Create the dialog
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Keyzone Distributor",
    view_builder:column {
      -- Original interface (always visible)
      view_builder:row {
        view_builder:text {
          width=140,
          text="Distribute Samples by",
          font = "bold",
          style="strong",
        },
        keys_valuebox,
        view_builder:text {
          font="bold",
          style="strong",
          text="keys per sample"
        }
      },
      view_builder:row {
        view_builder:text {
            width=140,
          text="Quick Set",
          font = "bold",
          style="strong",
        },
        create_quick_set_button(1),
        create_quick_set_button(12),
        create_quick_set_button(24)
      },
      view_builder:row {
        view_builder:text {
            width=140,
          text="Base Note",
          font = "bold",
          style="strong",
        },
        base_note_switch
      },
      
      -- Enhanced mode toggle
      view_builder:row {
        enhanced_checkbox,
        view_builder:text {
          text = "Enhanced Mode (Transpose & Velocity)",
          style = "strong"
        }
      },
      
      -- Enhanced controls (hidden by default)
      enhanced_controls
    }, keyhandler
  )
end

-- Show standalone filename-based keyzone mapping dialog
function pakettiKeyzoneDistributorFilenameDialog()
  -- Check environment and handle dialog state
  if not setup_environment() then return end
  
  debug_print("Creating filename-based Keyzone Mapping dialog")
  
  local filename_dialog = nil
  local filename_view_builder = renoise.ViewBuilder()
  
  -- State variables
  local current_file_list = {}
  local selected_folder = ""
  
  -- Create the simplified filename-only dialog
  local keyhandler = create_keyhandler_for_dialog(
    function() return filename_dialog end,
    function(value) filename_dialog = value end
  )
  
  filename_dialog = renoise.app():show_custom_dialog("Paketti Filename-Based Keyzone Mapping",
    filename_view_builder:column {
      filename_view_builder:row {
        filename_view_builder:text {
          text = "Automatically map samples based on filename patterns",
          style = "strong"
        }
      },
      
      filename_view_builder:row {
        filename_view_builder:text {
          text = " "
        }
      },
      
      filename_view_builder:row {
        filename_view_builder:text {
          width = 140,
          text = "Select Folder",
          font = "bold",
          style = "strong",
        },
        filename_view_builder:button {
          text = "Browse...",
          width = 80,
          notifier = function()
            local folder = renoise.app():prompt_for_path("Select folder containing samples")
            if folder and folder ~= "" then
              selected_folder = folder
              current_file_list = PakettiKeyzoneDistributorScanFolder(folder)
              
              -- Update the multiline text with the file list
              local file_list_text = filename_view_builder.views.filename_file_list
              if file_list_text then
                file_list_text.text = PakettiKeyzoneDistributorGenerateFileListText(current_file_list)
              end
              
              renoise.app():show_status(string.format("Scanned %d files from folder", #current_file_list))
            end
          end
        },
        filename_view_builder:text {
          text = "← Browse for samples folder",
          style = "disabled"
        }
      },
      
      filename_view_builder:row {
        filename_view_builder:text {
          width = 140,
          text = "Detected Files",
          font = "bold",
          style = "strong",
        },
        filename_view_builder:multiline_text {
          width = 500,
          height = 200,
          text = "No folder selected...\n\nThis will automatically create multiple instruments.\n\nSupported filename patterns:\n• 00_59, 00_60, 00_61... → Creates \"00_59-00_79\"\n• 01_59, 01_60, 01_61... → Creates \"01_59-01_79\" \n• 02_72, 02_75... → Creates \"02_72-02_89\"\n• etc.\n\n• drumhit_48_64 (MIDI range) → Current instrument\n• sample_c4_g4 (note range) → Current instrument\n• kick_c-4, kickA4, snareGS4, hat-bb3 → Current instrument\n• mc101_b-192_c-4, amf_340_g#2 → Current instrument",
          font = "mono",
          id = "filename_file_list"
        }
      },
      
      filename_view_builder:row {
        filename_view_builder:text {
          width = 140,
          text = "Create Instruments",
          font = "bold",
          style = "strong",
        },
        filename_view_builder:button {
          text = "Load & Map Samples",
          width = 120,
          notifier = function()
            if #current_file_list == 0 then
              renoise.app():show_status("No files scanned. Please select a folder first.")
              return
            end
            
            PakettiKeyzoneDistributorApplyFilenameMapping(current_file_list)
          end
        },
        filename_view_builder:text {
          text = "← Map detected ranges to instrument samples"
        }
      }
    }, keyhandler
  )
end

-- Keybindings and MIDI mappings
renoise.tool():add_keybinding{name="Global:Paketti:Show Keyzone Distributor Dialog...",invoke=function() pakettiKeyzoneDistributorDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Show Keyzone Distributor Dialog...",invoke=function(message) if message:is_trigger() then pakettiKeyzoneDistributorDialog() end end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Keyzone Distributor",invoke=function() pakettiKeyzoneDistributorDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Show Filename-Based Keyzone Mapping...",invoke=function() pakettiKeyzoneDistributorFilenameDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Show Filename-Based Keyzone Mapping...",invoke=function(message) if message:is_trigger() then pakettiKeyzoneDistributorFilenameDialog() end end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Filename-Based Keyzone Mapping",invoke=function() pakettiKeyzoneDistributorFilenameDialog() end}