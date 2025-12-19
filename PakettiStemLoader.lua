-----------
-- Paketti Stem Loader
-- Loads multiple audio files (stems), each into its own instrument on its own track,
-- with C-4 triggers and automatic BPM detection from file metadata.
-- Autoseek mode: simple C-4 trigger with autoseek ON
-- Slice mode: creates slices and patterns with XRNI preset + Instr. Macros
-----------

-- Lua 5.1 compatible IEEE 754 float reader (little-endian)
local function pakettiStemLoaderReadFloatLE(str, pos)
  local b1, b2, b3, b4 = str:byte(pos, pos+3)
  if not b1 or not b2 or not b3 or not b4 then return 0 end
  local sign = (b4 >= 128) and -1 or 1
  local exp = ((b4 % 128) * 2) + math.floor(b3 / 128) - 127
  local mantissa = 1 + ((b3 % 128) * 65536 + b2 * 256 + b1) / 8388608
  if exp == -127 then return 0 end
  return sign * mantissa * (2 ^ exp)
end

-- Detect BPM from WAV file ACID chunk
-- Returns BPM as integer, or nil if not found
function pakettiStemLoaderDetectBPM(filepath)
  local f = io.open(filepath, "rb")
  if not f then 
    print("Stem Loader BPM: Could not open file: " .. filepath)
    return nil 
  end
  
  local header = f:read(12)
  if not header or #header < 12 then
    f:close()
    print("Stem Loader BPM: File too small: " .. filepath)
    return nil
  end
  
  -- Check for RIFF/WAVE header
  if header:sub(1,4) ~= "RIFF" or header:sub(9,12) ~= "WAVE" then
    f:close()
    -- Not a WAV file, skip BPM detection
    return nil
  end
  
  -- Parse chunks looking for 'acid'
  while true do
    local chunk_header = f:read(8)
    if not chunk_header or #chunk_header < 8 then break end
    
    local chunk_id = chunk_header:sub(1,4)
    local chunk_len = PakettiWavCueU32LE(chunk_header, 5)
    
    if chunk_id == "acid" and chunk_len >= 24 then
      local data = f:read(chunk_len)
      if data and #data >= 24 then
        -- Tempo is at offset 16 (1-indexed: 17)
        local bpm = pakettiStemLoaderReadFloatLE(data, 17)
        f:close()
        if bpm > 20 and bpm < 999 then
          local rounded_bpm = math.floor(bpm + 0.5)
          print("Stem Loader BPM: Detected " .. rounded_bpm .. " BPM from ACID chunk in: " .. filepath)
          return rounded_bpm
        end
      end
      f:close()
      return nil
    else
      -- Skip this chunk (with padding for odd lengths)
      local skip_amount = chunk_len + (chunk_len % 2)
      f:seek("cur", skip_amount)
    end
  end
  
  f:close()
  return nil
end

-- Find majority BPM from a list of detected BPMs
local function pakettiStemLoaderFindMajorityBPM(bpm_list)
  if #bpm_list == 0 then return nil, 0 end
  
  local counts = {}
  for _, bpm in ipairs(bpm_list) do
    counts[bpm] = (counts[bpm] or 0) + 1
  end
  
  local max_count = 0
  local majority_bpm = nil
  for bpm, count in pairs(counts) do
    if count > max_count then
      max_count = count
      majority_bpm = bpm
    end
  end
  
  return majority_bpm, max_count
end

-- Extract BPM from a single folder name string
-- Looks for patterns like: 146BPM, _146bpm, BPM146, 146-bpm, 146_BPM, etc.
local function pakettiStemLoaderExtractBpmFromString(folder_name)
  if not folder_name or folder_name == "" then
    return nil
  end
  
  local lower_name = folder_name:lower()
  local detected_bpm = nil
  
  -- Pattern 1: Number followed by "bpm" (e.g., "146BPM", "146bpm", "146_bpm", "146-bpm", "146 bpm")
  local bpm_after = lower_name:match("(%d+)%s*bpm")
  if bpm_after then
    detected_bpm = tonumber(bpm_after)
  end
  
  -- Pattern 2: "bpm" followed by number (e.g., "BPM146", "bpm_146", "bpm-146", "bpm 146")
  if not detected_bpm then
    local bpm_before = lower_name:match("bpm%s*(%d+)")
    if bpm_before then
      detected_bpm = tonumber(bpm_before)
    end
  end
  
  -- Pattern 3: Number with underscore/hyphen before "bpm" (e.g., "song_116_bpm", "track-90-bpm")
  if not detected_bpm then
    local bpm_with_sep = lower_name:match("(%d+)[_%-]bpm")
    if bpm_with_sep then
      detected_bpm = tonumber(bpm_with_sep)
    end
  end
  
  -- Validate BPM is in reasonable range (20-999)
  if detected_bpm and detected_bpm >= 20 and detected_bpm <= 999 then
    return detected_bpm
  end
  
  return nil
end

-- Extract BPM from folder path by checking ALL folders in the path (not just immediate parent)
-- Searches from deepest to shallowest, returns first BPM found
local function pakettiStemLoaderExtractBpmFromFolderName(folder_path)
  print("Stem Loader BPM: === Starting folder path BPM detection ===")
  print("Stem Loader BPM: Full path: '" .. tostring(folder_path) .. "'")
  
  if not folder_path or folder_path == "" then
    print("Stem Loader BPM: folder_path is nil or empty, returning nil")
    return nil
  end
  
  -- Remove trailing slashes
  local clean_path = folder_path:gsub("/+$", "")
  
  -- Split path into folder components and check each one
  local folders = {}
  for folder in clean_path:gmatch("([^/]+)") do
    table.insert(folders, folder)
  end
  
  print("Stem Loader BPM: Checking " .. #folders .. " folders in path...")
  
  -- Check from deepest folder up to root (reverse order)
  for i = #folders, 1, -1 do
    local folder_name = folders[i]
    print("Stem Loader BPM: Checking folder: '" .. folder_name .. "'")
    
    local bpm = pakettiStemLoaderExtractBpmFromString(folder_name)
    if bpm then
      print("Stem Loader BPM: === SUCCESS: Found BPM " .. bpm .. " in folder '" .. folder_name .. "' ===")
      return bpm
    end
  end
  
  print("Stem Loader BPM: === No BPM pattern found in any folder ===")
  return nil
end

-- Calculate the number of patterns needed based on sample length, BPM, and LPB
local function pakettiStemLoaderCalculatePatternsNeeded(frames, sample_rate, bpm, lpb, pattern_length)
  if frames <= 0 or sample_rate <= 0 or bpm <= 0 or lpb <= 0 or pattern_length <= 0 then
    return 1
  end
  
  -- Calculate sample length in seconds
  local sample_length_seconds = frames / sample_rate
  
  -- Calculate lines per second: (BPM / 60) * LPB
  local lines_per_second = (bpm / 60) * lpb
  
  -- Calculate total lines needed
  local total_lines_needed = sample_length_seconds * lines_per_second
  
  -- Calculate patterns needed (ceiling)
  local patterns_needed = math.ceil(total_lines_needed / pattern_length)
  
  -- Ensure at least 1 pattern
  if patterns_needed < 1 then patterns_needed = 1 end
  
  print(string.format("Stem Loader Patterns: %.2f seconds @ %d BPM, %d LPB, %d lines/pattern = %d patterns needed (%.1f total lines)",
    sample_length_seconds, bpm, lpb, pattern_length, patterns_needed, total_lines_needed))
  
  return patterns_needed
end

-- Create slices and pattern sequence for slice-to-patterns mode
-- This creates equal-length slices in each stem and writes slice notes to patterns
local function pakettiStemLoaderCreateSlicesAndPatterns(loaded_instruments_info)
  local song = renoise.song()
  
  -- Find the longest sample
  local longest_frames = 0
  local longest_sample_rate = 44100
  local longest_name = ""
  
  for _, info in ipairs(loaded_instruments_info) do
    if info.frames > longest_frames then
      longest_frames = info.frames
      longest_sample_rate = info.sample_rate
      longest_name = info.name
    end
  end
  
  if longest_frames <= 0 then
    print("Stem Loader Slices: No valid samples found, skipping slice creation")
    return
  end
  
  -- Get current song settings
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local pattern_length = song.patterns[1].number_of_lines
  
  print(string.format("Stem Loader Slices: Longest sample '%s': %d frames @ %d Hz", 
    longest_name, longest_frames, longest_sample_rate))
  
  -- Calculate how many slices needed (one per pattern)
  local sample_length_seconds = longest_frames / longest_sample_rate
  local lines_per_second = (bpm / 60) * lpb
  local total_lines = sample_length_seconds * lines_per_second
  local slice_count = math.ceil(total_lines / pattern_length)
  
  if slice_count < 1 then slice_count = 1 end
  
  print(string.format("Stem Loader Slices: %.2f seconds @ %d BPM, %d LPB, %d lines/pattern = %d slices needed",
    sample_length_seconds, bpm, lpb, pattern_length, slice_count))
  
  -- Create slices in each loaded instrument
  for _, info in ipairs(loaded_instruments_info) do
    local instrument = song.instruments[info.instrument_index]
    if instrument and instrument.samples[1] then
      local sample = instrument.samples[1]
      
      -- Clear existing slices
      while #sample.slice_markers > 0 do
        sample:delete_slice_marker(sample.slice_markers[1])
      end
      
      -- Calculate exact frames per pattern based on musical timing
      -- frames_per_pattern = (seconds_per_pattern) * sample_rate
      -- seconds_per_pattern = (pattern_length / lpb) * (60 / bpm)
      local seconds_per_pattern = (pattern_length / lpb) * (60 / bpm)
      local frames_per_pattern = seconds_per_pattern * info.sample_rate
      
      -- Create slices at exact musical boundaries
      -- Last slice will be shorter if sample doesn't fill complete pattern
      for s = 0, slice_count - 1 do
        local slice_pos = math.floor(s * frames_per_pattern) + 1
        if slice_pos < 1 then slice_pos = 1 end
        if slice_pos > info.frames then slice_pos = info.frames end
        sample:insert_slice_marker(slice_pos)
      end
      
      -- Set autoseek OFF for slice mode
      sample.autoseek = false
      
      -- Debug: report if last slice is shorter
      local last_slice_start = math.floor((slice_count - 1) * frames_per_pattern) + 1
      local last_slice_length = info.frames - last_slice_start + 1
      local expected_length = math.floor(frames_per_pattern)
      if last_slice_length < expected_length then
        print(string.format("Stem Loader Slices: Created %d slices in '%s' (last slice is %d frames, %.1f%% of full pattern)",
          slice_count, info.name, last_slice_length, (last_slice_length / expected_length) * 100))
      else
        print(string.format("Stem Loader Slices: Created %d slices in '%s'", slice_count, info.name))
      end
    end
  end
  
  -- Get current pattern sequence length
  local current_sequence_length = #song.sequencer.pattern_sequence
  
  -- Create additional patterns if needed
  if slice_count > current_sequence_length then
    local patterns_to_create = slice_count - current_sequence_length
    print(string.format("Stem Loader Slices: Creating %d additional patterns (have %d, need %d)",
      patterns_to_create, current_sequence_length, slice_count))
    
    for i = 1, patterns_to_create do
      local new_pattern_index = song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
      song.patterns[new_pattern_index].number_of_lines = pattern_length
      print(string.format("Stem Loader Slices: Created pattern %d (sequence position %d)", 
        new_pattern_index, #song.sequencer.pattern_sequence))
    end
  end
  
  -- Write slice notes to each pattern
  -- Slices in Renoise are triggered by notes starting from the base note + 1
  -- For a sliced instrument, slice 1 is at base_note + 1, slice 2 at base_note + 2, etc.
  for slice_index = 1, slice_count do
    local seq_pos = slice_index
    if seq_pos > #song.sequencer.pattern_sequence then break end
    
    local pattern_index = song.sequencer.pattern_sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    
    -- Write slice note to each stem track
    for _, info in ipairs(loaded_instruments_info) do
      local track_index = info.track_index
      local instrument_index = info.instrument_index - 1  -- 0-based for pattern
      
      -- Get the base note of the instrument (usually C-4 = 48)
      local instrument = song.instruments[info.instrument_index]
      local base_note = 48  -- Default to C-4
      if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
        base_note = instrument.samples[1].sample_mapping.base_note
      end
      
      -- Slice note: base_note + slice_index (slice 1 = base_note + 1, etc.)
      local slice_note = base_note + slice_index
      if slice_note > 119 then slice_note = 119 end  -- Clamp to B-9
      
      -- Write to first line of pattern
      if pattern.tracks[track_index] then
        local line = pattern.tracks[track_index].lines[1]
        line.note_columns[1].note_value = slice_note
        line.note_columns[1].instrument_value = instrument_index
        
        -- Ensure note column is visible
        if song.tracks[track_index].visible_note_columns < 1 then
          song.tracks[track_index].visible_note_columns = 1
        end
      end
    end
    
    -- Name the pattern
    pattern.name = string.format("Slice %02d", slice_index)
  end
  
  renoise.app():show_status(string.format("Stem Loader: Created %d slices and patterns for %.1f second stems @ %d BPM", 
    slice_count, sample_length_seconds, bpm))
  print(string.format("Stem Loader Slices: Completed - %d slices, %d patterns, %d stems",
    slice_count, slice_count, #loaded_instruments_info))
end

-- Create pattern sequence based on the longest loaded sample (autoseek mode)
local function pakettiStemLoaderCreatePatternSequence(loaded_instruments_info)
  local song = renoise.song()
  
  -- Find the longest sample
  local longest_frames = 0
  local longest_sample_rate = 44100
  local longest_name = ""
  
  for _, info in ipairs(loaded_instruments_info) do
    if info.frames > longest_frames then
      longest_frames = info.frames
      longest_sample_rate = info.sample_rate
      longest_name = info.name
    end
  end
  
  if longest_frames <= 0 then
    print("Stem Loader Patterns: No valid samples found, skipping pattern creation")
    return
  end
  
  -- Get current song settings
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local pattern_length = song.patterns[1].number_of_lines
  
  print(string.format("Stem Loader Patterns: Longest sample '%s': %d frames @ %d Hz", 
    longest_name, longest_frames, longest_sample_rate))
  
  -- Calculate patterns needed
  local patterns_needed = pakettiStemLoaderCalculatePatternsNeeded(
    longest_frames, longest_sample_rate, bpm, lpb, pattern_length
  )
  
  -- Get current pattern sequence length
  local current_sequence_length = #song.sequencer.pattern_sequence
  
  if patterns_needed <= current_sequence_length then
    print(string.format("Stem Loader Patterns: Already have %d patterns, need %d - no new patterns created",
      current_sequence_length, patterns_needed))
    return
  end
  
  -- Create additional patterns
  local patterns_to_create = patterns_needed - current_sequence_length
  print(string.format("Stem Loader Patterns: Creating %d additional patterns (have %d, need %d)",
    patterns_to_create, current_sequence_length, patterns_needed))
  
  for i = 1, patterns_to_create do
    -- Insert new pattern at end of sequence
    local new_pattern_index = song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
    -- Set the same pattern length as pattern 1
    song.patterns[new_pattern_index].number_of_lines = pattern_length
    print(string.format("Stem Loader Patterns: Created pattern %d (sequence position %d)", 
      new_pattern_index, #song.sequencer.pattern_sequence))
  end
  
  local sample_length_seconds = longest_frames / longest_sample_rate
  renoise.app():show_status(string.format("Stem Loader: Created %d patterns for %.1f second stems @ %d BPM", 
    patterns_needed, sample_length_seconds, bpm))
end

-- Global progress tracking variables for Stem Loader
local stem_loader_progress = {
  current_file_index = 0,
  current_filename = "",
  total_files = 0,
  slicer = nil,
  vb = nil,
  dialog = nil
}

-- Main Stem Loader function
-- normalize: boolean - whether to normalize samples after loading
-- skip_preset: boolean - whether to skip XRNI preset loading and Instr. Macros device
-- slice_mode: boolean - whether to use slice-to-patterns mode instead of autoseek
function pakettiStemLoader(normalize, skip_preset, slice_mode)
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read(
    {"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, 
    "Paketti Stem Loader"
  )

  if #selected_sample_filenames == 0 then
    renoise.app():show_status("No files selected.")
    return
  end

  print("Paketti Stem Loader: " .. #selected_sample_filenames .. " files selected")
  rprint(selected_sample_filenames)
  
  -- First: Try folder name BPM detection (prioritized because user intentionally named folder)
  local folder_bpm = nil
  local first_file = selected_sample_filenames[1]
  local folder_path = first_file:match("^(.+)/")
  print("Paketti Stem Loader: First file: " .. first_file)
  print("Paketti Stem Loader: Extracted folder path: " .. tostring(folder_path))
  
  if folder_path then
    folder_bpm = pakettiStemLoaderExtractBpmFromFolderName(folder_path)
    if folder_bpm then
      print("Paketti Stem Loader: Found BPM " .. folder_bpm .. " in folder name")
    else
      print("Paketti Stem Loader: No BPM found in folder name")
    end
  else
    print("Paketti Stem Loader: Could not extract folder path from file")
  end
  
  -- Second: Detect BPM from all files (ACID chunks) - only if no folder BPM found
  local detected_bpms = {}
  local acid_bpms_found = 0
  if not folder_bpm then
    print("Paketti Stem Loader: Checking files for ACID chunk BPM data...")
    for _, filename in ipairs(selected_sample_filenames) do
      local bpm = pakettiStemLoaderDetectBPM(filename)
      if bpm then
        table.insert(detected_bpms, bpm)
        acid_bpms_found = acid_bpms_found + 1
        print("Paketti Stem Loader: ACID BPM " .. bpm .. " found in: " .. filename:match("([^/]+)$"))
      end
    end
    print("Paketti Stem Loader: Found ACID BPM data in " .. acid_bpms_found .. " of " .. #selected_sample_filenames .. " files")
  else
    -- Folder BPM takes priority - add it to the list
    table.insert(detected_bpms, folder_bpm)
    print("Paketti Stem Loader: Using folder name BPM (" .. folder_bpm .. "), skipping ACID chunk detection")
  end
  
  -- Set BPM if we found any
  local bpm_source = ""
  if #detected_bpms > 0 then
    local majority_bpm, count = pakettiStemLoaderFindMajorityBPM(detected_bpms)
    if majority_bpm then
      print("Paketti Stem Loader: Setting transport.bpm to " .. majority_bpm)
      renoise.song().transport.bpm = majority_bpm
      if folder_bpm then
        bpm_source = "folder name"
        print("Paketti Stem Loader: Set BPM to " .. majority_bpm .. " (from folder name)")
        renoise.app():show_status("Stem Loader: Set BPM to " .. majority_bpm .. " (from folder name)")
      else
        bpm_source = "file metadata"
        print("Paketti Stem Loader: Set BPM to " .. majority_bpm .. " (detected from " .. count .. " of " .. #detected_bpms .. " files)")
        renoise.app():show_status("Stem Loader: Set BPM to " .. majority_bpm .. " (detected from " .. count .. " files)")
      end
    end
  else
    print("Paketti Stem Loader: No BPM found in folder name or files, keeping current BPM: " .. renoise.song().transport.bpm)
    renoise.app():show_status("Stem Loader: No BPM detected, keeping current BPM")
  end
  
  -- Destructive mode: clear all tracks and patterns before loading
  if preferences.pakettiStemLoaderDestructive.value then
    local song = renoise.song()
    print("Paketti Stem Loader: Destructive mode enabled - clearing song...")
    
    -- Delete all pattern sequences except the first one
    while #song.sequencer.pattern_sequence > 1 do
      song.sequencer:delete_sequence_at(2)
    end
    print("Paketti Stem Loader: Reduced pattern sequence to 1 pattern")
    
    -- Clear the first pattern
    local first_pattern_index = song.sequencer.pattern_sequence[1]
    song.patterns[first_pattern_index]:clear()
    print("Paketti Stem Loader: Cleared first pattern")
    
    -- Delete all sequencer tracks except one (keep at least one track)
    local tracks_deleted = 0
    while song.sequencer_track_count > 1 do
      song:delete_track_at(1)
      tracks_deleted = tracks_deleted + 1
    end
    print("Paketti Stem Loader: Deleted " .. tracks_deleted .. " tracks, kept 1")
    
    -- Clear the remaining track
    if song.tracks[1] then
      song.tracks[1].name = "Track 01"
    end
    
    -- Clear the first instrument for clean start
    if song.instruments[1] then
      song.instruments[1]:clear()
      song.instruments[1].name = ""
    end
    song.selected_instrument_index = 1
    song.selected_track_index = 1
    
    renoise.app():show_status("Stem Loader: Destructive mode - cleared song for fresh stem loading")
  end
  
  -- Initialize progress tracking
  stem_loader_progress.current_file_index = 0
  stem_loader_progress.current_filename = ""
  stem_loader_progress.total_files = #selected_sample_filenames
  
  -- Pass destructive mode flag to process function
  local destructive_mode = preferences.pakettiStemLoaderDestructive.value
  print("Paketti Stem Loader: destructive_mode preference = " .. tostring(destructive_mode))
  
  -- Create options table to avoid Lua 5.1 unpack nil issue
  -- (unpack stops at first nil, so we bundle everything in one table)
  local options = {
    filenames = selected_sample_filenames,
    normalize = normalize or false,
    skip_preset = skip_preset or false,
    slice_mode = slice_mode or false,
    destructive_mode = destructive_mode or false
  }
  print("Paketti Stem Loader: options.destructive_mode = " .. tostring(options.destructive_mode))
  
  -- Create ProcessSlicer for the loading operation
  stem_loader_progress.slicer = ProcessSlicer(pakettiStemLoader_process, options)
  stem_loader_progress.dialog, stem_loader_progress.vb = stem_loader_progress.slicer:create_dialog("Loading Stems...")
  
  -- Start the process
  stem_loader_progress.slicer:start()
  
  -- Update progress text periodically
  renoise.tool():add_timer(pakettiStemLoader_update_progress, 100)
end

function pakettiStemLoader_update_progress()
  local progress = stem_loader_progress
  
  if progress.slicer and progress.vb then
    if progress.slicer:running() and not progress.slicer:was_cancelled() then
      -- Update progress text
      local progress_text = string.format("Processing stem %d of %d...", progress.current_file_index, progress.total_files)
      if progress.current_filename ~= "" then
        progress_text = progress_text .. "\n" .. progress.current_filename
      end
      progress.vb.views.progress_text.text = progress_text
    elseif not progress.slicer:running() then
      -- Process completed or stopped
      renoise.tool():remove_timer(pakettiStemLoader_update_progress)
      if progress.dialog and progress.dialog.visible then
        progress.dialog:close()
      end
      if not progress.slicer:was_cancelled() then
        renoise.app():show_status("All stems loaded successfully.")
      else
        renoise.app():show_status("Stem loading cancelled.")
      end
      
      -- Reset progress tracking
      stem_loader_progress = {
        current_file_index = 0,
        current_filename = "",
        total_files = 0,
        slicer = nil,
        vb = nil,
        dialog = nil
      }
    end
  end
end

function pakettiStemLoader_process(options)
  -- Unpack options table (avoids Lua 5.1 unpack nil issue)
  local selected_sample_filenames = options.filenames
  local normalize = options.normalize
  local skip_preset = options.skip_preset
  local slice_mode = options.slice_mode
  local destructive_mode = options.destructive_mode
  
  print("Stem Loader Process: STARTING")
  print("  destructive_mode = " .. tostring(destructive_mode))
  print("  normalize = " .. tostring(normalize))
  print("  skip_preset = " .. tostring(skip_preset))
  print("  slice_mode = " .. tostring(slice_mode))
  print("  file count = " .. #selected_sample_filenames)
  
  -- Completely stop AutoSamplify monitoring to prevent double-processing
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- DISABLE Sample Range Device Loader to prevent it from creating duplicate instruments
  local SampleRangeLoaderState = preferences.pakettiSampleRangeDeviceLoaderEnabled.value
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = false
  
  -- Store initial 0G01 loader state and disable it (we handle track creation ourselves)
  local G01LoaderState = preferences._0G01_Loader.value
  preferences._0G01_Loader.value = false
  
  local song = renoise.song()
  
  -- Track loaded sample info for pattern sequence calculation
  local loaded_instruments_info = {}
  
  for index, filename in ipairs(selected_sample_filenames) do
    stem_loader_progress.current_file_index = index
    stem_loader_progress.current_filename = filename:match("^.+[/\\](.+)$") or filename
    
    -- Check for cancellation
    if stem_loader_progress.slicer and stem_loader_progress.slicer:was_cancelled() then
      renoise.app():show_status("Stem loading cancelled by user.")
      -- Restore states before breaking
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
      preferences._0G01_Loader.value = G01LoaderState
      break
    end
    
    coroutine.yield()
    
    local new_track_index
    local next_instrument
    
    print(string.format("Stem Loader: Processing file %d, destructive_mode=%s, index=%d", 
      index, tostring(destructive_mode), index))
    
    -- In destructive mode, use track 1 and instrument 1 for the first stem
    if destructive_mode and index == 1 then
      -- Use existing track 1 and instrument 1
      new_track_index = 1
      next_instrument = 1
      song.selected_track_index = 1
      song.selected_instrument_index = 1
      -- Ensure instrument 1 has a sample slot (clear removes all samples)
      if #song.instruments[1].samples == 0 then
        song.instruments[1]:insert_sample_at(1)
      end
      print("Stem Loader: DESTRUCTIVE MODE - Using track 1 and instrument 1 for first stem")
    else
      -- 1. Create new track at end of sequencer tracks (before send/master)
      new_track_index = song.sequencer_track_count + 1
      song:insert_track_at(new_track_index)
      song.selected_track_index = new_track_index
      print("Stem Loader: Created track at index " .. new_track_index)
      
      -- 2. Create new instrument
      next_instrument = song.selected_instrument_index + 1
      song:insert_instrument_at(next_instrument)
      song.selected_instrument_index = next_instrument
      print("Stem Loader: Created instrument at index " .. next_instrument)
    end
    
    -- 3. Load the default XRNI preset (Pakettification) - only for slice mode, skip if skip_preset is true
    -- Autoseek mode does NOT use XRNI preset (simpler, just loads raw samples)
    if slice_mode and not skip_preset then
      pakettiPreferencesDefaultInstrumentLoader()
    end
    
    local selected_instrument = song.selected_instrument
    
    -- Ensure there's a sample slot
    if #selected_instrument.samples == 0 then
      selected_instrument:insert_sample_at(1)
    end
    song.selected_sample_index = 1
    
    -- 4. Load the sample
    local filename_only = filename:match("^.+[/\\](.+)$") or filename
    local instrument_slot_hex = string.format("%02X", next_instrument - 1)
    local display_name = string.format("%s_%s", instrument_slot_hex, filename_only)
    
    if selected_instrument.samples[1].sample_buffer:load_from(filename) then
      print("Stem Loader: Sample loaded successfully: " .. filename_only)
      local current_sample = selected_instrument.samples[1]
      
      -- 5. Name sample and instrument
      current_sample.name = display_name
      selected_instrument.name = display_name
      selected_instrument.macros_visible = true
      
      -- 6. Apply loader settings - autoseek ON for normal mode, OFF for slice mode
      -- Autofade is always OFF for stems (causes timing issues with long samples)
      current_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      current_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      current_sample.autofade = false
      current_sample.autoseek = not slice_mode  -- ON for autoseek mode, OFF for slice mode
      current_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
      current_sample.oneshot = preferences.pakettiLoaderOneshot.value
      current_sample.new_note_action = preferences.pakettiLoaderNNA.value
      current_sample.loop_release = preferences.pakettiLoaderLoopExit.value
      
      -- 7. Rename track to match instrument
      song.tracks[new_track_index].name = display_name
      print("Stem Loader: Renamed track to: " .. display_name)
      
      -- 8. Write C-4 to line 1 of first pattern in sequence (only for autoseek mode, not slice mode)
      -- No 0G01 effect - autoseek handles playback position automatically
      if not slice_mode then
        -- Get the actual pattern index at sequence position 1 (might not be pattern index 1!)
        local first_pattern_index = song.sequencer.pattern_sequence[1]
        local pattern = song.patterns[first_pattern_index]
        if pattern and pattern.tracks[new_track_index] then
          local line = pattern.tracks[new_track_index].lines[1]
          local instrument_value = next_instrument - 1  -- 0-based for display
          
          line.note_columns[1].note_string = "C-4"
          line.note_columns[1].instrument_value = instrument_value
          
          print(string.format("Stem Loader: Wrote C-4 (instrument %02X) to Track %d, Pattern %d, Line 1", 
            instrument_value, new_track_index, first_pattern_index))
        end
      end
      
      -- 9. Load *Instr. Macros device on the track - only for slice mode, skip if skip_preset is true
      -- Autoseek mode does NOT load Instr. Macros (simpler setup)
      if slice_mode and not skip_preset and song.tracks[new_track_index].type ~= 2 then  -- Not master track
        loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
        local macro_device = song.tracks[new_track_index]:device(2)
        if macro_device then
          macro_device.display_name = display_name
          song.tracks[new_track_index].devices[2].is_maximized = false
          print("Stem Loader: Loaded *Instr. Macros device for: " .. display_name)
        end
      end
      
      -- 10. Optionally normalize
      if normalize then 
        normalize_selected_sample() 
      end
      
      -- 11. Apply additional loader preferences
      if preferences.pakettiLoaderMoveSilenceToEnd.value ~= false then 
        PakettiMoveSilence() 
      end
      if preferences.pakettiLoaderNormalizeSamples.value ~= false then 
        normalize_selected_sample() 
      end
      
      -- 12. Track sample info for pattern sequence calculation
      local sample_buffer = current_sample.sample_buffer
      if sample_buffer and sample_buffer.has_sample_data then
        table.insert(loaded_instruments_info, {
          name = display_name,
          frames = sample_buffer.number_of_frames,
          sample_rate = sample_buffer.sample_rate,
          bit_depth = sample_buffer.bit_depth,
          channels = sample_buffer.number_of_channels,
          instrument_index = next_instrument,
          track_index = new_track_index
        })
        print(string.format("Stem Loader: Sample info - %d frames @ %d Hz, %d-bit, %d ch",
          sample_buffer.number_of_frames, sample_buffer.sample_rate, 
          sample_buffer.bit_depth, sample_buffer.number_of_channels))
      end
      
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    else
      renoise.app():show_status("Failed to load stem: " .. filename_only)
      print("Stem Loader: Failed to load: " .. filename_only)
    end
    
    -- Yield control back to allow UI updates
    coroutine.yield()
  end
  
  -- Restore all states now that we're done
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
  preferences._0G01_Loader.value = G01LoaderState
  
  -- 13. Check for mixed sample rates
  local mixed_rates = false
  local rate_list = {}
  if #loaded_instruments_info > 0 then
    local sample_rates = {}
    for _, info in ipairs(loaded_instruments_info) do
      sample_rates[info.sample_rate] = (sample_rates[info.sample_rate] or 0) + 1
    end
    local rate_count = 0
    for rate, count in pairs(sample_rates) do
      rate_count = rate_count + 1
      table.insert(rate_list, string.format("%d Hz (%d files)", rate, count))
    end
    mixed_rates = (rate_count > 1)
    if mixed_rates then
      local status_msg = "Mixed sample rates detected: " .. table.concat(rate_list, ", ")
      print("Paketti Stem Loader: " .. status_msg)
      renoise.app():show_status(status_msg)
    end
  end
  
  -- 14. Determine if we should use slice mode (explicit or auto-fallback)
  local use_slice_mode = slice_mode
  if not use_slice_mode and mixed_rates and preferences.pakettiStemLoaderAutoSliceOnMixedRates.value then
    use_slice_mode = true
    print("Paketti Stem Loader: Auto-switching to slice mode due to mixed sample rates")
    renoise.app():show_status("Mixed sample rates - using slice mode for perfect alignment")
  end
  
  -- 15. Create pattern sequence (slice mode or autoseek mode)
  if #loaded_instruments_info > 0 then
    if use_slice_mode then
      pakettiStemLoaderCreateSlicesAndPatterns(loaded_instruments_info)
    else
      pakettiStemLoaderCreatePatternSequence(loaded_instruments_info)
    end
  end
  
  -- Reset progress tracking when complete
  stem_loader_progress.current_file_index = 0
  stem_loader_progress.current_filename = ""
  
  print("Paketti Stem Loader: Completed loading " .. #selected_sample_filenames .. " stems")
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader",invoke=function() pakettiStemLoader() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Normalize)",invoke=function() pakettiStemLoader(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (No Preset)",invoke=function() pakettiStemLoader(false, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (No Preset + Normalize)",invoke=function() pakettiStemLoader(true, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Slice to Patterns)",invoke=function() pakettiStemLoader(false, false, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Slice to Patterns + Normalize)",invoke=function() pakettiStemLoader(true, false, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Slice to Patterns + No Preset)",invoke=function() pakettiStemLoader(false, true, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Slice to Patterns + No Preset + Normalize)",invoke=function() pakettiStemLoader(true, true, true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader",invoke=function() pakettiStemLoader() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (Normalize)",invoke=function() pakettiStemLoader(true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (No Preset)",invoke=function() pakettiStemLoader(false, true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (No Preset + Normalize)",invoke=function() pakettiStemLoader(true, true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (Slice to Patterns)",invoke=function() pakettiStemLoader(false, false, true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (Slice to Patterns + Normalize)",invoke=function() pakettiStemLoader(true, false, true) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Stem Loader",invoke=function(message) if message:is_trigger() then pakettiStemLoader() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Stem Loader (No Preset)",invoke=function(message) if message:is_trigger() then pakettiStemLoader(false, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Stem Loader (Slice to Patterns)",invoke=function(message) if message:is_trigger() then pakettiStemLoader(false, false, true) end end}

