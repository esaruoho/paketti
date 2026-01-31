-----------
-- Paketti Stem Loader
-- Loads multiple audio files (stems), each into its own instrument on its own track,
-- with C-4 triggers and automatic BPM detection from file metadata.
-- Autoseek mode: simple C-4 trigger with autoseek ON
-- Slice mode: creates slices and patterns with XRNI preset + Instr. Macros
-----------

-- Pattern mode: "current" (default, safer) or "all" (modify all patterns)
local stem_randomizer_pattern_mode = "current"

-- Selection only mode: when true, randomization only affects the pattern editor selection
local stem_randomizer_selection_only = false

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

-- Reverse a sample buffer in-place
-- This swaps audio frames from start to end, creating a backwards version
local function pakettiStemLoaderReverseSampleBuffer(sample)
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then 
    print("Stem Loader Reverse: No sample data to reverse")
    return false
  end
  
  buffer:prepare_sample_data_changes()
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  
  print(string.format("Stem Loader Reverse: Reversing %d frames, %d channels", frames, channels))
  
  -- Swap frames from start to end for each channel
  for ch = 1, channels do
    for f = 1, math.floor(frames / 2) do
      local front_val = buffer:sample_data(ch, f)
      local back_val = buffer:sample_data(ch, frames - f + 1)
      buffer:set_sample_data(ch, f, back_val)
      buffer:set_sample_data(ch, frames - f + 1, front_val)
    end
  end
  
  buffer:finalize_sample_data_changes()
  print("Stem Loader Reverse: Completed")
  return true
end

-- Global registry of forwards/reverse track pairs for Stem Loader
-- Format: { {fwd_track=1, rev_track=2, fwd_instrument=1, rev_instrument=2, name="stem"}, ... }
stem_forwards_reverse_pairs = {}

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
  local filename_bpms_found = 0
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
    
    -- Third: Try filename BPM detection if no ACID BPMs found
    if #detected_bpms == 0 then
      print("Paketti Stem Loader: No ACID BPM found, checking filenames...")
      for _, filepath in ipairs(selected_sample_filenames) do
        local filename = filepath:match("([^/]+)$")  -- Extract just filename
        if filename then
          local bpm = pakettiStemLoaderExtractBpmFromString(filename)
          if bpm then
            table.insert(detected_bpms, bpm)
            filename_bpms_found = filename_bpms_found + 1
            print("Paketti Stem Loader: Filename BPM " .. bpm .. " found in: " .. filename)
          end
        end
      end
      print("Paketti Stem Loader: Found BPM in " .. filename_bpms_found .. " of " .. #selected_sample_filenames .. " filenames")
    end
  else
    -- Folder BPM takes priority - add it to the list
    table.insert(detected_bpms, folder_bpm)
    print("Paketti Stem Loader: Using folder name BPM (" .. folder_bpm .. "), skipping ACID chunk and filename detection")
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
      elseif acid_bpms_found > 0 then
        bpm_source = "file metadata"
        print("Paketti Stem Loader: Set BPM to " .. majority_bpm .. " (detected from " .. count .. " of " .. #detected_bpms .. " files)")
        renoise.app():show_status("Stem Loader: Set BPM to " .. majority_bpm .. " (detected from " .. count .. " files)")
      else
        bpm_source = "filename"
        print("Paketti Stem Loader: Set BPM to " .. majority_bpm .. " (from " .. count .. " of " .. #detected_bpms .. " filenames)")
        renoise.app():show_status("Stem Loader: Set BPM to " .. majority_bpm .. " (from " .. count .. " filenames)")
      end
    end
  else
    print("Paketti Stem Loader: No BPM found in folder name, files, or filenames, keeping current BPM: " .. renoise.song().transport.bpm)
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
      if not safeInsertInstrumentAt(song, next_instrument) then return end
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

-----------
-- Forwards+Reverse Stem Loader
-- Loads each stem twice: original (forwards) and reversed copy on paired tracks
-- Enables randomization between forwards/reverse versions during playback
-----------

-- Progress tracking for Forwards+Reverse loader
local stem_fwdrev_loader_progress = {
  current_file_index = 0,
  current_filename = "",
  total_files = 0,
  slicer = nil,
  vb = nil,
  dialog = nil
}

-- Main Forwards+Reverse Stem Loader function
-- normalize: boolean - whether to normalize samples after loading
function pakettiStemLoaderForwardsReverse(normalize)
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read(
    {"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, 
    "Paketti Stem Loader (Forwards+Reverse)"
  )

  if #selected_sample_filenames == 0 then
    renoise.app():show_status("No files selected.")
    return
  end

  print("Paketti Stem Loader (Forwards+Reverse): " .. #selected_sample_filenames .. " files selected")
  rprint(selected_sample_filenames)
  
  -- Clear previous pairing registry
  stem_forwards_reverse_pairs = {}
  
  -- BPM detection (same as regular stem loader)
  local folder_bpm = nil
  local first_file = selected_sample_filenames[1]
  local folder_path = first_file:match("^(.+)/")
  
  if folder_path then
    folder_bpm = pakettiStemLoaderExtractBpmFromFolderName(folder_path)
    if folder_bpm then
      print("Paketti Stem Loader FwdRev: Found BPM " .. folder_bpm .. " in folder name")
    end
  end
  
  -- Detect BPM from files if no folder BPM
  local detected_bpms = {}
  local acid_bpms_found = 0
  local filename_bpms_found = 0
  if not folder_bpm then
    -- Try ACID chunk detection first
    for _, filename in ipairs(selected_sample_filenames) do
      local bpm = pakettiStemLoaderDetectBPM(filename)
      if bpm then
        table.insert(detected_bpms, bpm)
        acid_bpms_found = acid_bpms_found + 1
      end
    end
    
    -- Try filename BPM detection if no ACID BPMs found
    if #detected_bpms == 0 then
      print("Paketti Stem Loader FwdRev: No ACID BPM found, checking filenames...")
      for _, filepath in ipairs(selected_sample_filenames) do
        local filename = filepath:match("([^/]+)$")  -- Extract just filename
        if filename then
          local bpm = pakettiStemLoaderExtractBpmFromString(filename)
          if bpm then
            table.insert(detected_bpms, bpm)
            filename_bpms_found = filename_bpms_found + 1
            print("Paketti Stem Loader FwdRev: Filename BPM " .. bpm .. " found in: " .. filename)
          end
        end
      end
    end
  else
    table.insert(detected_bpms, folder_bpm)
  end
  
  -- Set BPM if found
  if #detected_bpms > 0 then
    local majority_bpm, count = pakettiStemLoaderFindMajorityBPM(detected_bpms)
    if majority_bpm then
      renoise.song().transport.bpm = majority_bpm
      local source = "unknown"
      if folder_bpm then
        source = "folder name"
      elseif acid_bpms_found > 0 then
        source = "file metadata"
      else
        source = "filename"
      end
      print("Paketti Stem Loader FwdRev: Set BPM to " .. majority_bpm .. " (from " .. source .. ")")
      renoise.app():show_status("Stem Loader FwdRev: Set BPM to " .. majority_bpm .. " (from " .. source .. ")")
    end
  end
  
  -- Destructive mode: clear song before loading
  if preferences.pakettiStemLoaderDestructive.value then
    local song = renoise.song()
    print("Paketti Stem Loader FwdRev: Destructive mode enabled - clearing song...")
    
    while #song.sequencer.pattern_sequence > 1 do
      song.sequencer:delete_sequence_at(2)
    end
    
    local first_pattern_index = song.sequencer.pattern_sequence[1]
    song.patterns[first_pattern_index]:clear()
    
    while song.sequencer_track_count > 1 do
      song:delete_track_at(1)
    end
    
    if song.tracks[1] then
      song.tracks[1].name = "Track 01"
    end
    
    if song.instruments[1] then
      song.instruments[1]:clear()
      song.instruments[1].name = ""
    end
    song.selected_instrument_index = 1
    song.selected_track_index = 1
  end
  
  -- Initialize progress tracking
  stem_fwdrev_loader_progress.current_file_index = 0
  stem_fwdrev_loader_progress.current_filename = ""
  stem_fwdrev_loader_progress.total_files = #selected_sample_filenames
  
  local options = {
    filenames = selected_sample_filenames,
    normalize = normalize or false,
    destructive_mode = preferences.pakettiStemLoaderDestructive.value or false
  }
  
  -- Create ProcessSlicer for the loading operation
  stem_fwdrev_loader_progress.slicer = ProcessSlicer(pakettiStemLoaderForwardsReverse_process, options)
  stem_fwdrev_loader_progress.dialog, stem_fwdrev_loader_progress.vb = stem_fwdrev_loader_progress.slicer:create_dialog("Loading Stems (Forwards+Reverse)...")
  
  -- Start the process
  stem_fwdrev_loader_progress.slicer:start()
  
  -- Update progress text periodically
  renoise.tool():add_timer(pakettiStemLoaderForwardsReverse_update_progress, 100)
end

function pakettiStemLoaderForwardsReverse_update_progress()
  local progress = stem_fwdrev_loader_progress
  
  if progress.slicer and progress.vb then
    if progress.slicer:running() and not progress.slicer:was_cancelled() then
      local progress_text = string.format("Processing stem %d of %d (fwd+rev)...", progress.current_file_index, progress.total_files)
      if progress.current_filename ~= "" then
        progress_text = progress_text .. "\n" .. progress.current_filename
      end
      progress.vb.views.progress_text.text = progress_text
    elseif not progress.slicer:running() then
      renoise.tool():remove_timer(pakettiStemLoaderForwardsReverse_update_progress)
      if progress.dialog and progress.dialog.visible then
        progress.dialog:close()
      end
      if not progress.slicer:was_cancelled() then
        renoise.app():show_status("All stems loaded with forwards+reverse pairs.")
      else
        renoise.app():show_status("Stem loading cancelled.")
      end
      
      stem_fwdrev_loader_progress = {
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

function pakettiStemLoaderForwardsReverse_process(options)
  local selected_sample_filenames = options.filenames
  local normalize = options.normalize
  local destructive_mode = options.destructive_mode
  
  print("Stem Loader FwdRev Process: STARTING (ONE track, TWO instruments per stem)")
  print("  file count = " .. #selected_sample_filenames)
  
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  local SampleRangeLoaderState = preferences.pakettiSampleRangeDeviceLoaderEnabled.value
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = false
  local G01LoaderState = preferences._0G01_Loader.value
  preferences._0G01_Loader.value = false
  
  local song = renoise.song()
  local loaded_instruments_info = {}
  
  for index, filename in ipairs(selected_sample_filenames) do
    stem_fwdrev_loader_progress.current_file_index = index
    stem_fwdrev_loader_progress.current_filename = filename:match("^.+[/\\](.+)$") or filename
    
    if stem_fwdrev_loader_progress.slicer and stem_fwdrev_loader_progress.slicer:was_cancelled() then
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
      preferences._0G01_Loader.value = G01LoaderState
      break
    end
    
    coroutine.yield()
    
    local filename_only = filename:match("^.+[/\\](.+)$") or filename
    local track_index, fwd_instrument_index, rev_instrument_index
    
    -- === CREATE ONE TRACK for this stem ===
    if destructive_mode and index == 1 then
      track_index = 1
      fwd_instrument_index = 1
      song.selected_track_index = 1
      song.selected_instrument_index = 1
      if #song.instruments[1].samples == 0 then
        song.instruments[1]:insert_sample_at(1)
      end
    else
      track_index = song.sequencer_track_count + 1
      song:insert_track_at(track_index)
      song.selected_track_index = track_index
      
      fwd_instrument_index = song.selected_instrument_index + 1
      if not safeInsertInstrumentAt(song, fwd_instrument_index) then return end
      song.selected_instrument_index = fwd_instrument_index
    end
    
    -- === FORWARDS INSTRUMENT ===
    local fwd_instrument = song.instruments[fwd_instrument_index]
    if #fwd_instrument.samples == 0 then
      fwd_instrument:insert_sample_at(1)
    end
    song.selected_sample_index = 1
    
    local fwd_display_name = string.format("%02X_%s", fwd_instrument_index - 1, filename_only)
    
    local sample_info = nil
    local fwd_load_success = fwd_instrument.samples[1].sample_buffer:load_from(filename)
    
    if fwd_load_success then
      print("Stem Loader FwdRev: Loaded FORWARDS: " .. filename_only)
      local fwd_sample = fwd_instrument.samples[1]
      
      fwd_sample.name = fwd_display_name
      fwd_instrument.name = fwd_display_name
      fwd_instrument.macros_visible = true
      
      fwd_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      fwd_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      fwd_sample.autofade = false
      fwd_sample.autoseek = false
      fwd_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
      fwd_sample.oneshot = preferences.pakettiLoaderOneshot.value
      fwd_sample.new_note_action = preferences.pakettiLoaderNNA.value
      fwd_sample.loop_release = preferences.pakettiLoaderLoopExit.value
      
      song.tracks[track_index].name = filename_only
      
      if normalize then 
        normalize_selected_sample() 
      end
      
      local sample_buffer = fwd_sample.sample_buffer
      if sample_buffer and sample_buffer.has_sample_data then
        sample_info = {
          frames = sample_buffer.number_of_frames,
          sample_rate = sample_buffer.sample_rate,
          bit_depth = sample_buffer.bit_depth,
          channels = sample_buffer.number_of_channels
        }
        table.insert(loaded_instruments_info, {
          name = fwd_display_name,
          frames = sample_buffer.number_of_frames,
          sample_rate = sample_buffer.sample_rate,
          bit_depth = sample_buffer.bit_depth,
          channels = sample_buffer.number_of_channels,
          instrument_index = fwd_instrument_index,
          track_index = track_index,
          is_reversed = false
        })
      end
      
      coroutine.yield()
      
      -- === REVERSED INSTRUMENT (same track, new instrument) ===
      local rev_instrument_index = song.selected_instrument_index + 1
      if not safeInsertInstrumentAt(song, rev_instrument_index) then return end
      song.selected_instrument_index = rev_instrument_index
      
      local rev_instrument = song.instruments[rev_instrument_index]
      if #rev_instrument.samples == 0 then
        rev_instrument:insert_sample_at(1)
      end
      song.selected_sample_index = 1
      
      local rev_display_name = string.format("%02X_%s [Rev]", rev_instrument_index - 1, filename_only)
      
      if rev_instrument.samples[1].sample_buffer:load_from(filename) then
        print("Stem Loader FwdRev: Loaded for REVERSE: " .. filename_only)
        local rev_sample = rev_instrument.samples[1]
        
        if pakettiStemLoaderReverseSampleBuffer(rev_sample) then
          print("Stem Loader FwdRev: Reversed sample: " .. filename_only)
        end
        
        rev_sample.name = rev_display_name
        rev_instrument.name = rev_display_name
        rev_instrument.macros_visible = true
        
        rev_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        rev_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        rev_sample.autofade = false
        rev_sample.autoseek = false
        rev_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        rev_sample.oneshot = preferences.pakettiLoaderOneshot.value
        rev_sample.new_note_action = preferences.pakettiLoaderNNA.value
        rev_sample.loop_release = preferences.pakettiLoaderLoopExit.value
        
        if normalize then 
          normalize_selected_sample() 
        end
        
        if sample_info then
          table.insert(loaded_instruments_info, {
            name = rev_display_name,
            frames = sample_info.frames,
            sample_rate = sample_info.sample_rate,
            bit_depth = sample_info.bit_depth,
            channels = sample_info.channels,
            instrument_index = rev_instrument_index,
            track_index = track_index,
            is_reversed = true
          })
        end
      end
      
      -- Register the forwards/reverse pair (ONE track, TWO instruments)
      table.insert(stem_forwards_reverse_pairs, {
        track = track_index,
        fwd_instrument = fwd_instrument_index,
        rev_instrument = rev_instrument_index,
        name = filename_only
      })
      
      print(string.format("Stem Loader FwdRev: Track %d - Fwd Instr %d, Rev Instr %d, Name: %s",
        track_index, fwd_instrument_index, rev_instrument_index, filename_only))
    else
      print("Stem Loader FwdRev: FAILED to load: " .. filename_only)
    end
    
    coroutine.yield()
  end
  
  -- Restore states
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
  preferences._0G01_Loader.value = G01LoaderState
  
  -- Create slices and patterns (using only forwards instruments for calculation)
  local fwd_instruments_info = {}
  for _, info in ipairs(loaded_instruments_info) do
    if not info.is_reversed then
      table.insert(fwd_instruments_info, info)
    end
  end
  
  if #fwd_instruments_info > 0 then
    -- Create slices in ALL loaded instruments (both fwd and rev)
    pakettiStemLoaderCreateSlicesAndPatternsForFwdRev(loaded_instruments_info, fwd_instruments_info)
  end
  
  print(string.format("Paketti Stem Loader FwdRev: Completed - %d stems on %d tracks, %d instrument pairs",
    #selected_sample_filenames, #stem_forwards_reverse_pairs, #stem_forwards_reverse_pairs * 2))
end

-- Create slices and patterns specifically for forwards+reverse mode
-- This ensures both fwd and rev samples get identical slices
local function pakettiStemLoaderCreateSlicesAndPatternsForFwdRev(all_instruments_info, fwd_instruments_info)
  local song = renoise.song()
  
  -- Find the longest sample (from forwards tracks only)
  local longest_frames = 0
  local longest_sample_rate = 44100
  local longest_name = ""
  
  for _, info in ipairs(fwd_instruments_info) do
    if info.frames > longest_frames then
      longest_frames = info.frames
      longest_sample_rate = info.sample_rate
      longest_name = info.name
    end
  end
  
  if longest_frames <= 0 then
    print("Stem Loader FwdRev Slices: No valid samples found")
    return
  end
  
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local pattern_length = song.patterns[1].number_of_lines
  
  print(string.format("Stem Loader FwdRev Slices: Longest sample '%s': %d frames @ %d Hz", 
    longest_name, longest_frames, longest_sample_rate))
  
  local sample_length_seconds = longest_frames / longest_sample_rate
  local lines_per_second = (bpm / 60) * lpb
  local total_lines = sample_length_seconds * lines_per_second
  local slice_count = math.ceil(total_lines / pattern_length)
  
  if slice_count < 1 then slice_count = 1 end
  
  print(string.format("Stem Loader FwdRev Slices: %.2f seconds @ %d BPM = %d slices needed",
    sample_length_seconds, bpm, slice_count))
  
  -- Create slices in ALL loaded instruments (both forwards and reversed)
  for _, info in ipairs(all_instruments_info) do
    local instrument = song.instruments[info.instrument_index]
    if instrument and instrument.samples[1] then
      local sample = instrument.samples[1]
      
      -- Clear existing slices
      while #sample.slice_markers > 0 do
        sample:delete_slice_marker(sample.slice_markers[1])
      end
      
      local seconds_per_pattern = (pattern_length / lpb) * (60 / bpm)
      local frames_per_pattern = seconds_per_pattern * info.sample_rate
      
      for s = 0, slice_count - 1 do
        local slice_pos = math.floor(s * frames_per_pattern) + 1
        if slice_pos < 1 then slice_pos = 1 end
        if slice_pos > info.frames then slice_pos = info.frames end
        sample:insert_slice_marker(slice_pos)
      end
      
      sample.autoseek = false
      
      print(string.format("Stem Loader FwdRev: Created %d slices in '%s'", slice_count, info.name))
    end
  end
  
  -- Create additional patterns if needed
  local current_sequence_length = #song.sequencer.pattern_sequence
  if slice_count > current_sequence_length then
    local patterns_to_create = slice_count - current_sequence_length
    for i = 1, patterns_to_create do
      local new_pattern_index = song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
      song.patterns[new_pattern_index].number_of_lines = pattern_length
    end
  end
  
  -- Write slice notes to patterns (only for FORWARDS tracks initially)
  for slice_index = 1, slice_count do
    local seq_pos = slice_index
    if seq_pos > #song.sequencer.pattern_sequence then break end
    
    local pattern_index = song.sequencer.pattern_sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    
    for _, info in ipairs(fwd_instruments_info) do
      local track_index = info.track_index
      local instrument_index = info.instrument_index - 1
      
      local instrument = song.instruments[info.instrument_index]
      local base_note = 48
      if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
        base_note = instrument.samples[1].sample_mapping.base_note
      end
      
      local slice_note = base_note + slice_index
      if slice_note > 119 then slice_note = 119 end
      
      if pattern.tracks[track_index] then
        local line = pattern.tracks[track_index].lines[1]
        line.note_columns[1].note_value = slice_note
        line.note_columns[1].instrument_value = instrument_index
        
        if song.tracks[track_index].visible_note_columns < 1 then
          song.tracks[track_index].visible_note_columns = 1
        end
      end
    end
    
    pattern.name = string.format("Slice %02d", slice_index)
  end
  
  renoise.app():show_status(string.format("Stem Loader FwdRev: Created %d slices, %d patterns, %d track pairs", 
    slice_count, slice_count, #stem_forwards_reverse_pairs))
end

--------------------------------------------------------------------------------
-- PHRASE AUTO-CREATION FROM LOADED STEMS
--------------------------------------------------------------------------------

-- Create phrases for each slice in a loaded stem instrument
-- This creates one phrase per slice, playing that slice's note
function PakettiStemLoaderCreatePhrasesFromSlices(instrument_index, slice_count)
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.instruments[instrument_index]
  if not instrument then
    print("StemLoader Phrases: Invalid instrument index " .. instrument_index)
    return nil
  end
  
  local sample = instrument.samples[1]
  if not sample then
    print("StemLoader Phrases: No sample in instrument " .. instrument_index)
    return nil
  end
  
  -- Get base note for slice triggering
  local base_note = 48  -- C-4
  if sample.sample_mapping then
    base_note = sample.sample_mapping.base_note
  end
  
  local lpb = song.transport.lpb
  local phrases_created = {}
  
  print("StemLoader Phrases: Creating " .. slice_count .. " phrases for instrument " .. instrument_index)
  
  for slice_index = 1, slice_count do
    -- Create a new phrase
    local phrase_index = #instrument.phrases + 1
    instrument:insert_phrase_at(phrase_index)
    local phrase = instrument.phrases[phrase_index]
    
    if phrase then
      -- Configure phrase
      phrase.name = "Slice " .. string.format("%02d", slice_index)
      phrase.number_of_lines = lpb  -- One beat per slice phrase
      phrase.lpb = lpb
      phrase.is_empty = false
      phrase.autoseek = false
      phrase.loop_start = 1
      phrase.loop_end = lpb
      phrase.looping = true
      
      -- Ensure at least 1 note column
      if phrase.visible_note_columns < 1 then
        phrase.visible_note_columns = 1
      end
      
      -- Write the slice trigger note on line 1
      local slice_note = base_note + slice_index
      if slice_note > 119 then slice_note = 119 end  -- Clamp to B-9
      
      local line = phrase:line(1)
      line.note_columns[1].note_value = slice_note
      line.note_columns[1].instrument_value = 0  -- Self-reference
      line.note_columns[1].volume_value = 128  -- 0x80 = full volume
      
      phrases_created[slice_index] = phrase_index
      print("StemLoader Phrases: Created phrase " .. phrase_index .. " for slice " .. slice_index)
    end
  end
  
  -- Create a PhraseGrid bank if the function is available
  if PakettiPhraseBankCreate then
    local stem_name = instrument.name or "Stem"
    local bank_index = PakettiPhraseBankCreate(instrument_index, "Stem: " .. stem_name)
    
    if bank_index and PakettiPhraseBanks and PakettiPhraseBanks[bank_index] then
      -- Assign created phrases to bank slots (up to 8)
      local max_slots = math.min(slice_count, 8)
      for slot = 1, max_slots do
        if phrases_created[slot] then
          PakettiPhraseBankSetSlot(bank_index, slot, phrases_created[slot])
        end
      end
      print("StemLoader Phrases: Created PhraseGrid bank " .. bank_index .. " with " .. max_slots .. " slots")
    end
  end
  
  renoise.app():show_status("Created " .. slice_count .. " phrases for stem: " .. (instrument.name or "Instrument"))
  return phrases_created
end

-- Create phrases for all loaded stem instruments
function PakettiStemLoaderCreatePhrasesFromLoadedStems(loaded_instruments_info)
  local song = renoise.song()
  if not song then return end
  
  if not loaded_instruments_info or #loaded_instruments_info == 0 then
    print("StemLoader Phrases: No loaded instruments info")
    return
  end
  
  local total_phrases = 0
  
  for _, info in ipairs(loaded_instruments_info) do
    local instrument = song.instruments[info.instrument_index]
    if instrument and instrument.samples[1] then
      local sample = instrument.samples[1]
      local slice_count = #sample.slice_markers
      
      if slice_count > 0 then
        local phrases = PakettiStemLoaderCreatePhrasesFromSlices(info.instrument_index, slice_count)
        if phrases then
          total_phrases = total_phrases + slice_count
        end
      end
    end
  end
  
  if total_phrases > 0 then
    renoise.app():show_status("Created " .. total_phrases .. " phrases across " .. #loaded_instruments_info .. " stems")
  end
end

-- Manually trigger phrase creation for all loaded stem tracks
function PakettiStemLoaderCreatePhrasesNow()
  local song = renoise.song()
  if not song then return end
  
  -- Look for instruments that have slice markers (likely stems)
  local stem_instruments = {}
  
  for i, instrument in ipairs(song.instruments) do
    if instrument.samples[1] then
      local sample = instrument.samples[1]
      if #sample.slice_markers > 0 then
        table.insert(stem_instruments, {
          instrument_index = i,
          name = instrument.name,
          slice_count = #sample.slice_markers
        })
      end
    end
  end
  
  if #stem_instruments == 0 then
    renoise.app():show_status("No sliced instruments found")
    return
  end
  
  local total_phrases = 0
  for _, info in ipairs(stem_instruments) do
    local phrases = PakettiStemLoaderCreatePhrasesFromSlices(info.instrument_index, info.slice_count)
    if phrases then
      total_phrases = total_phrases + info.slice_count
    end
  end
  
  renoise.app():show_status("Created " .. total_phrases .. " phrases from " .. #stem_instruments .. " sliced instruments")
end

-- Keybindings for phrase creation
renoise.tool():add_keybinding{name="Global:Paketti:Stem Loader Create Phrases from Slices",invoke=PakettiStemLoaderCreatePhrasesNow}
renoise.tool():add_midi_mapping{name="Paketti:Stem Loader Create Phrases from Slices [Trigger]",invoke=function(message) if message:is_trigger() then PakettiStemLoaderCreatePhrasesNow() end end}

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

-- Forwards+Reverse Stem Loader keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Forwards+Reverse)",invoke=function() pakettiStemLoaderForwardsReverse() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Stem Loader (Forwards+Reverse + Normalize)",invoke=function() pakettiStemLoaderForwardsReverse(true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (Forwards+Reverse)",invoke=function() pakettiStemLoaderForwardsReverse() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti Stem Loader (Forwards+Reverse + Normalize)",invoke=function() pakettiStemLoaderForwardsReverse(true) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Stem Loader (Forwards+Reverse)",invoke=function(message) if message:is_trigger() then pakettiStemLoaderForwardsReverse() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Stem Loader (Forwards+Reverse + Normalize)",invoke=function(message) if message:is_trigger() then pakettiStemLoaderForwardsReverse(true) end end}

-----------
-- Stem Slice Randomization Functions
-- Randomize which slices play in which patterns after stems are loaded
-----------

-- Helper function to find all tracks with sliced instruments
local function pakettiStemFindSlicedTracks()
  local song = renoise.song()
  local sliced_tracks = {}
  
  for track_index = 1, song.sequencer_track_count do
    local track = song.tracks[track_index]
    -- Check if this track has a note on line 1 of pattern 1
    local first_pattern_index = song.sequencer.pattern_sequence[1]
    local pattern = song.patterns[first_pattern_index]
    if pattern and pattern.tracks[track_index] then
      local line = pattern.tracks[track_index].lines[1]
      local note_col = line.note_columns[1]
      if note_col.instrument_value < 255 then
        local instrument_index = note_col.instrument_value + 1  -- Convert to 1-based
        local instrument = song.instruments[instrument_index]
        if instrument and instrument.samples[1] then
          local slice_count = #instrument.samples[1].slice_markers
          if slice_count > 0 then
            table.insert(sliced_tracks, {
              track_index = track_index,
              instrument_index = instrument_index,
              slice_count = slice_count,
              track_name = track.name
            })
          end
        end
      end
    end
  end
  
  return sliced_tracks
end

-- Randomize stem slices independently (each track gets its own random order)
function pakettiStemRandomizeSlicesIndependent()
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found. Load stems with 'Slice to Patterns' first.")
    return
  end
  
  local pattern_count = #song.sequencer.pattern_sequence
  print(string.format("Stem Randomize Independent: Found %d sliced tracks, %d patterns", #sliced_tracks, pattern_count))
  
  -- Randomize each track independently
  for _, track_info in ipairs(sliced_tracks) do
    local instrument = song.instruments[track_info.instrument_index]
    local base_note = 48  -- Default to C-4
    if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
      base_note = instrument.samples[1].sample_mapping.base_note
    end
    
    -- Write random slice to each pattern
    for seq_pos = 1, pattern_count do
      local pattern_index = song.sequencer.pattern_sequence[seq_pos]
      local pattern = song.patterns[pattern_index]
      
      if pattern and pattern.tracks[track_info.track_index] then
        -- Pick a random slice (1 to slice_count)
        local random_slice = math.random(1, track_info.slice_count)
        local slice_note = base_note + random_slice
        if slice_note > 119 then slice_note = 119 end
        
        local line = pattern.tracks[track_info.track_index].lines[1]
        line.note_columns[1].note_value = slice_note
        line.note_columns[1].instrument_value = track_info.instrument_index - 1
      end
    end
    
    print(string.format("Stem Randomize: Randomized '%s' with %d slices across %d patterns", 
      track_info.track_name, track_info.slice_count, pattern_count))
  end
  
  renoise.app():show_status(string.format("Randomized %d stem tracks independently across %d patterns", #sliced_tracks, pattern_count))
end

-- Randomize stem slices synchronized (all tracks play the same slice number per pattern)
function pakettiStemRandomizeSlicesSynchronized()
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found. Load stems with 'Slice to Patterns' first.")
    return
  end
  
  local pattern_count = #song.sequencer.pattern_sequence
  
  -- Find the minimum slice count across all tracks (to avoid out-of-range slices)
  local min_slice_count = sliced_tracks[1].slice_count
  for _, track_info in ipairs(sliced_tracks) do
    if track_info.slice_count < min_slice_count then
      min_slice_count = track_info.slice_count
    end
  end
  
  print(string.format("Stem Randomize Synchronized: Found %d sliced tracks, %d patterns, using %d slices", 
    #sliced_tracks, pattern_count, min_slice_count))
  
  -- Generate one random slice order for all tracks
  local random_slices = {}
  for seq_pos = 1, pattern_count do
    random_slices[seq_pos] = math.random(1, min_slice_count)
  end
  
  -- Apply the same random order to all tracks
  for _, track_info in ipairs(sliced_tracks) do
    local instrument = song.instruments[track_info.instrument_index]
    local base_note = 48  -- Default to C-4
    if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
      base_note = instrument.samples[1].sample_mapping.base_note
    end
    
    -- Write the synchronized random slice to each pattern
    for seq_pos = 1, pattern_count do
      local pattern_index = song.sequencer.pattern_sequence[seq_pos]
      local pattern = song.patterns[pattern_index]
      
      if pattern and pattern.tracks[track_info.track_index] then
        local slice_note = base_note + random_slices[seq_pos]
        if slice_note > 119 then slice_note = 119 end
        
        local line = pattern.tracks[track_info.track_index].lines[1]
        line.note_columns[1].note_value = slice_note
        line.note_columns[1].instrument_value = track_info.instrument_index - 1
      end
    end
  end
  
  print(string.format("Stem Randomize Synchronized: Applied same random order to %d tracks", #sliced_tracks))
  renoise.app():show_status(string.format("Randomized %d stem tracks synchronized across %d patterns", #sliced_tracks, pattern_count))
end

-- Duplicate current pattern and jump to it (for building variations)
function pakettiStemDuplicatePatternAndJump()
  local song = renoise.song()
  local current_seq_pos = song.selected_sequence_index
  local current_pattern_index = song.sequencer.pattern_sequence[current_seq_pos]
  local current_pattern = song.patterns[current_pattern_index]
  
  -- Create a new pattern (copy of current)
  local new_pattern_index = song.sequencer:insert_new_pattern_at(current_seq_pos + 1)
  local new_pattern = song.patterns[new_pattern_index]
  
  -- Copy pattern properties
  new_pattern.number_of_lines = current_pattern.number_of_lines
  new_pattern.name = current_pattern.name .. " (var)"
  
  -- Copy all track data from current pattern to new pattern
  for track_idx = 1, #song.tracks do
    if current_pattern.tracks[track_idx] and new_pattern.tracks[track_idx] then
      for line_idx = 1, current_pattern.number_of_lines do
        local src_line = current_pattern.tracks[track_idx].lines[line_idx]
        local dst_line = new_pattern.tracks[track_idx].lines[line_idx]
        dst_line:copy_from(src_line)
      end
    end
  end
  
  -- Jump to the new sequence position
  song.selected_sequence_index = current_seq_pos + 1
  
  print(string.format("Stem Duplicate: Copied pattern %d to new pattern %d at seq pos %d",
    current_pattern_index, new_pattern_index, current_seq_pos + 1))
  renoise.app():show_status(string.format("Duplicated to pattern %02X at sequence %d", 
    new_pattern_index, current_seq_pos + 1))
  
  return new_pattern_index
end

-- Reset stem slices to sequential order (undo randomization)
function pakettiStemResetSlicesToSequential()
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found.")
    return
  end
  
  -- Selection-only mode handling
  local sel_start_line = nil
  local sel_start_track, sel_end_track = nil, nil
  
  if stem_randomizer_selection_only then
    local selection = song.selection_in_pattern
    if not selection then
      renoise.app():show_status("Selection Only mode enabled but no selection in pattern")
      return
    end
    sel_start_line = selection.start_line
    sel_start_track = selection.start_track
    sel_end_track = selection.end_track
    
    -- Filter sliced_tracks to only those within selection
    local filtered_tracks = {}
    for _, track_info in ipairs(sliced_tracks) do
      if track_info.track_index >= sel_start_track and track_info.track_index <= sel_end_track then
        table.insert(filtered_tracks, track_info)
      end
    end
    sliced_tracks = filtered_tracks
    
    if #sliced_tracks == 0 then
      renoise.app():show_status("No sliced stem tracks within selection")
      return
    end
  end
  
  -- Determine which patterns to process based on mode
  local seq_positions = {}
  if stem_randomizer_pattern_mode == "current" then
    seq_positions = {song.selected_sequence_index}
  else
    for i = 1, #song.sequencer.pattern_sequence do
      seq_positions[i] = i
    end
  end
  
  -- Reset each track to sequential slices
  for _, track_info in ipairs(sliced_tracks) do
    local instrument = song.instruments[track_info.instrument_index]
    local base_note = 48  -- Default to C-4
    if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
      base_note = instrument.samples[1].sample_mapping.base_note
    end
    
    -- Write sequential slice to each pattern
    for _, seq_pos in ipairs(seq_positions) do
      local pattern_index = song.sequencer.pattern_sequence[seq_pos]
      local pattern = song.patterns[pattern_index]
      
      if pattern and pattern.tracks[track_info.track_index] then
        -- Sequential: pattern 1 = slice 1, pattern 2 = slice 2, etc.
        -- Wrap around if more patterns than slices
        local slice_index = ((seq_pos - 1) % track_info.slice_count) + 1
        local slice_note = base_note + slice_index
        if slice_note > 119 then slice_note = 119 end
        
        -- Use selection start line if in selection-only mode, otherwise line 1
        local target_line = sel_start_line or 1
        local line = pattern.tracks[track_info.track_index].lines[target_line]
        line.note_columns[1].note_value = slice_note
        line.note_columns[1].instrument_value = track_info.instrument_index - 1
      end
    end
  end
  
  local mode_text = stem_randomizer_pattern_mode == "current" and "current pattern" or string.format("%d patterns", #seq_positions)
  if stem_randomizer_selection_only then
    mode_text = mode_text .. " (selection only)"
  end
  renoise.app():show_status(string.format("Reset %d stem tracks to sequential - %s", #sliced_tracks, mode_text))
end

-- Randomize stem slices at specified step interval (independent - each track gets its own random slices)
-- step_size: 1, 2, 4, 8, 16, or 32 (number of rows between triggers)
function pakettiStemRandomizeSlicesStepIndependent(step_size)
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found. Load stems with 'Slice to Patterns' first.")
    return
  end
  
  -- Selection-only mode handling
  local sel_start_line, sel_end_line = nil, nil
  local sel_start_track, sel_end_track = nil, nil
  
  if stem_randomizer_selection_only then
    local selection = song.selection_in_pattern
    if not selection then
      renoise.app():show_status("Selection Only mode enabled but no selection in pattern")
      return
    end
    sel_start_line = selection.start_line
    sel_end_line = selection.end_line
    sel_start_track = selection.start_track
    sel_end_track = selection.end_track
    
    -- Filter sliced_tracks to only those within selection
    local filtered_tracks = {}
    for _, track_info in ipairs(sliced_tracks) do
      if track_info.track_index >= sel_start_track and track_info.track_index <= sel_end_track then
        table.insert(filtered_tracks, track_info)
      end
    end
    sliced_tracks = filtered_tracks
    
    if #sliced_tracks == 0 then
      renoise.app():show_status("No sliced stem tracks within selection")
      return
    end
  end
  
  -- Determine which patterns to process based on mode
  local seq_positions = {}
  if stem_randomizer_pattern_mode == "current" then
    seq_positions = {song.selected_sequence_index}
  else
    for i = 1, #song.sequencer.pattern_sequence do
      seq_positions[i] = i
    end
  end
  
  -- Calculate number of triggers per 64-row pattern and generate offset values
  local triggers_per_64 = math.floor(64 / step_size)
  local offset_values = {}
  for i = 0, triggers_per_64 - 1 do
    offset_values[i + 1] = math.floor(i * 256 / triggers_per_64)
  end
  
  local selection_text = stem_randomizer_selection_only and " (selection only)" or ""
  print(string.format("Stem Randomize %d-Step Independent: Found %d sliced tracks, %d patterns (%s mode)%s, %d offsets", 
    step_size, #sliced_tracks, #seq_positions, stem_randomizer_pattern_mode, selection_text, #offset_values))
  
  local total_chunks = 0
  
  for _, seq_pos in ipairs(seq_positions) do
    local pattern_index = song.sequencer.pattern_sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    local pattern_length = pattern.number_of_lines
    
    -- Determine line range to process
    local start_line = sel_start_line or 1
    local end_line = sel_end_line or pattern_length
    if end_line > pattern_length then end_line = pattern_length end
    
    local chunks_per_pattern = math.floor(pattern_length / step_size)
    if chunks_per_pattern < 1 then chunks_per_pattern = 1 end
    
    for _, track_info in ipairs(sliced_tracks) do
      local instrument = song.instruments[track_info.instrument_index]
      local base_note = 48
      if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
        base_note = instrument.samples[1].sample_mapping.base_note
      end
      
      -- Clear lines on this track in this pattern (only within selection if applicable)
      for row = start_line, end_line do
        local line = pattern.tracks[track_info.track_index].lines[row]
        if line then
          line.note_columns[1]:clear()
          line.effect_columns[1]:clear()
        end
      end
      
      -- Write new triggers at the specified step interval (only within selection if applicable)
      for chunk = 0, chunks_per_pattern - 1 do
        local row = (chunk * step_size) + 1
        if row >= start_line and row <= end_line then
          local random_slice = math.random(1, track_info.slice_count)
          local slice_note = base_note + random_slice
          if slice_note > 119 then slice_note = 119 end
          
          local offset = offset_values[(chunk % #offset_values) + 1]
          
          local line = pattern.tracks[track_info.track_index].lines[row]
          if line then
            line.note_columns[1].note_value = slice_note
            line.note_columns[1].instrument_value = track_info.instrument_index - 1
            line.effect_columns[1].number_string = "0S"
            line.effect_columns[1].amount_value = offset
            
            if song.tracks[track_info.track_index].visible_effect_columns < 1 then
              song.tracks[track_info.track_index].visible_effect_columns = 1
            end
          end
          
          total_chunks = total_chunks + 1
        end
      end
    end
  end
  
  local mode_text = stem_randomizer_pattern_mode == "current" and "current pattern" or string.format("%d patterns", #seq_positions)
  if stem_randomizer_selection_only then
    mode_text = mode_text .. " (selection only)"
  end
  print(string.format("Stem Randomize %d-Step Independent: Wrote %d slice triggers", step_size, total_chunks))
  renoise.app():show_status(string.format("Randomized %d tracks every %d steps (independent) - %s", #sliced_tracks, step_size, mode_text))
end

-- Randomize stem slices at specified step interval (synchronized - all tracks play same slice per chunk)
-- step_size: 1, 2, 4, 8, 16, or 32 (number of rows between triggers)
function pakettiStemRandomizeSlicesStepSynchronized(step_size)
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found. Load stems with 'Slice to Patterns' first.")
    return
  end
  
  -- Selection-only mode handling
  local sel_start_line, sel_end_line = nil, nil
  local sel_start_track, sel_end_track = nil, nil
  
  if stem_randomizer_selection_only then
    local selection = song.selection_in_pattern
    if not selection then
      renoise.app():show_status("Selection Only mode enabled but no selection in pattern")
      return
    end
    sel_start_line = selection.start_line
    sel_end_line = selection.end_line
    sel_start_track = selection.start_track
    sel_end_track = selection.end_track
    
    -- Filter sliced_tracks to only those within selection
    local filtered_tracks = {}
    for _, track_info in ipairs(sliced_tracks) do
      if track_info.track_index >= sel_start_track and track_info.track_index <= sel_end_track then
        table.insert(filtered_tracks, track_info)
      end
    end
    sliced_tracks = filtered_tracks
    
    if #sliced_tracks == 0 then
      renoise.app():show_status("No sliced stem tracks within selection")
      return
    end
  end
  
  -- Determine which patterns to process based on mode
  local seq_positions = {}
  if stem_randomizer_pattern_mode == "current" then
    seq_positions = {song.selected_sequence_index}
  else
    for i = 1, #song.sequencer.pattern_sequence do
      seq_positions[i] = i
    end
  end
  
  local min_slice_count = sliced_tracks[1].slice_count
  for _, track_info in ipairs(sliced_tracks) do
    if track_info.slice_count < min_slice_count then
      min_slice_count = track_info.slice_count
    end
  end
  
  -- Calculate number of triggers per 64-row pattern and generate offset values
  local triggers_per_64 = math.floor(64 / step_size)
  local offset_values = {}
  for i = 0, triggers_per_64 - 1 do
    offset_values[i + 1] = math.floor(i * 256 / triggers_per_64)
  end
  
  local selection_text = stem_randomizer_selection_only and " (selection only)" or ""
  print(string.format("Stem Randomize %d-Step Synchronized: Found %d sliced tracks, %d patterns (%s mode)%s, using %d slices, %d offsets", 
    step_size, #sliced_tracks, #seq_positions, stem_randomizer_pattern_mode, selection_text, min_slice_count, #offset_values))
  
  local total_chunks = 0
  
  for _, seq_pos in ipairs(seq_positions) do
    local pattern_index = song.sequencer.pattern_sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    local pattern_length = pattern.number_of_lines
    
    -- Determine line range to process
    local start_line = sel_start_line or 1
    local end_line = sel_end_line or pattern_length
    if end_line > pattern_length then end_line = pattern_length end
    
    local chunks_per_pattern = math.floor(pattern_length / step_size)
    if chunks_per_pattern < 1 then chunks_per_pattern = 1 end
    
    local chunk_slices = {}
    for chunk = 0, chunks_per_pattern - 1 do
      chunk_slices[chunk] = math.random(1, min_slice_count)
    end
    
    for _, track_info in ipairs(sliced_tracks) do
      local instrument = song.instruments[track_info.instrument_index]
      local base_note = 48
      if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
        base_note = instrument.samples[1].sample_mapping.base_note
      end
      
      -- Clear lines on this track in this pattern (only within selection if applicable)
      for row = start_line, end_line do
        local line = pattern.tracks[track_info.track_index].lines[row]
        if line then
          line.note_columns[1]:clear()
          line.effect_columns[1]:clear()
        end
      end
      
      -- Write new triggers at the specified step interval (only within selection if applicable)
      for chunk = 0, chunks_per_pattern - 1 do
        local row = (chunk * step_size) + 1
        if row >= start_line and row <= end_line then
          local slice_note = base_note + chunk_slices[chunk]
          if slice_note > 119 then slice_note = 119 end
          
          local offset = offset_values[(chunk % #offset_values) + 1]
          
          local line = pattern.tracks[track_info.track_index].lines[row]
          if line then
            line.note_columns[1].note_value = slice_note
            line.note_columns[1].instrument_value = track_info.instrument_index - 1
            line.effect_columns[1].number_string = "0S"
            line.effect_columns[1].amount_value = offset
            
            if song.tracks[track_info.track_index].visible_effect_columns < 1 then
              song.tracks[track_info.track_index].visible_effect_columns = 1
            end
          end
          
          total_chunks = total_chunks + 1
        end
      end
    end
  end
  
  local mode_text = stem_randomizer_pattern_mode == "current" and "current pattern" or string.format("%d patterns", #seq_positions)
  if stem_randomizer_selection_only then
    mode_text = mode_text .. " (selection only)"
  end
  print(string.format("Stem Randomize %d-Step Synchronized: Wrote %d slice triggers", step_size, total_chunks))
  renoise.app():show_status(string.format("Randomized %d tracks every %d steps (synchronized) - %s", #sliced_tracks, step_size, mode_text))
end

-- Wrapper functions for backwards compatibility and menu/keybinding convenience
function pakettiStemRandomizeSlices16Independent() pakettiStemRandomizeSlicesStepIndependent(16) end
function pakettiStemRandomizeSlices16Synchronized() pakettiStemRandomizeSlicesStepSynchronized(16) end
function pakettiStemRandomizeSlices8Independent() pakettiStemRandomizeSlicesStepIndependent(8) end
function pakettiStemRandomizeSlices8Synchronized() pakettiStemRandomizeSlicesStepSynchronized(8) end
function pakettiStemRandomizeSlices4Independent() pakettiStemRandomizeSlicesStepIndependent(4) end
function pakettiStemRandomizeSlices4Synchronized() pakettiStemRandomizeSlicesStepSynchronized(4) end
function pakettiStemRandomizeSlices2Independent() pakettiStemRandomizeSlicesStepIndependent(2) end
function pakettiStemRandomizeSlices2Synchronized() pakettiStemRandomizeSlicesStepSynchronized(2) end
function pakettiStemRandomizeSlices1Independent() pakettiStemRandomizeSlicesStepIndependent(1) end
function pakettiStemRandomizeSlices1Synchronized() pakettiStemRandomizeSlicesStepSynchronized(1) end
function pakettiStemRandomizeSlices32Independent() pakettiStemRandomizeSlicesStepIndependent(32) end
function pakettiStemRandomizeSlices32Synchronized() pakettiStemRandomizeSlicesStepSynchronized(32) end

-- Wrapper functions for odd step sizes
function pakettiStemRandomizeSlices3Independent() pakettiStemRandomizeSlicesStepIndependent(3) end
function pakettiStemRandomizeSlices3Synchronized() pakettiStemRandomizeSlicesStepSynchronized(3) end
function pakettiStemRandomizeSlices5Independent() pakettiStemRandomizeSlicesStepIndependent(5) end
function pakettiStemRandomizeSlices5Synchronized() pakettiStemRandomizeSlicesStepSynchronized(5) end
function pakettiStemRandomizeSlices7Independent() pakettiStemRandomizeSlicesStepIndependent(7) end
function pakettiStemRandomizeSlices7Synchronized() pakettiStemRandomizeSlicesStepSynchronized(7) end
function pakettiStemRandomizeSlices9Independent() pakettiStemRandomizeSlicesStepIndependent(9) end
function pakettiStemRandomizeSlices9Synchronized() pakettiStemRandomizeSlicesStepSynchronized(9) end
function pakettiStemRandomizeSlices11Independent() pakettiStemRandomizeSlicesStepIndependent(11) end
function pakettiStemRandomizeSlices11Synchronized() pakettiStemRandomizeSlicesStepSynchronized(11) end
function pakettiStemRandomizeSlices13Independent() pakettiStemRandomizeSlicesStepIndependent(13) end
function pakettiStemRandomizeSlices13Synchronized() pakettiStemRandomizeSlicesStepSynchronized(13) end
function pakettiStemRandomizeSlices15Independent() pakettiStemRandomizeSlicesStepIndependent(15) end
function pakettiStemRandomizeSlices15Synchronized() pakettiStemRandomizeSlicesStepSynchronized(15) end
function pakettiStemRandomizeSlices17Independent() pakettiStemRandomizeSlicesStepIndependent(17) end
function pakettiStemRandomizeSlices17Synchronized() pakettiStemRandomizeSlicesStepSynchronized(17) end
function pakettiStemRandomizeSlices19Independent() pakettiStemRandomizeSlicesStepIndependent(19) end
function pakettiStemRandomizeSlices19Synchronized() pakettiStemRandomizeSlicesStepSynchronized(19) end
function pakettiStemRandomizeSlices21Independent() pakettiStemRandomizeSlicesStepIndependent(21) end
function pakettiStemRandomizeSlices21Synchronized() pakettiStemRandomizeSlicesStepSynchronized(21) end
function pakettiStemRandomizeSlices23Independent() pakettiStemRandomizeSlicesStepIndependent(23) end
function pakettiStemRandomizeSlices23Synchronized() pakettiStemRandomizeSlicesStepSynchronized(23) end
function pakettiStemRandomizeSlices25Independent() pakettiStemRandomizeSlicesStepIndependent(25) end
function pakettiStemRandomizeSlices25Synchronized() pakettiStemRandomizeSlicesStepSynchronized(25) end
function pakettiStemRandomizeSlices27Independent() pakettiStemRandomizeSlicesStepIndependent(27) end
function pakettiStemRandomizeSlices27Synchronized() pakettiStemRandomizeSlicesStepSynchronized(27) end
function pakettiStemRandomizeSlices29Independent() pakettiStemRandomizeSlicesStepIndependent(29) end
function pakettiStemRandomizeSlices29Synchronized() pakettiStemRandomizeSlicesStepSynchronized(29) end
function pakettiStemRandomizeSlices31Independent() pakettiStemRandomizeSlicesStepIndependent(31) end
function pakettiStemRandomizeSlices31Synchronized() pakettiStemRandomizeSlicesStepSynchronized(31) end

-- Sequential slices at specified step interval (NOT randomized - "Go Forwards" mode)
-- This writes slices in order: slice 1, slice 2, slice 3... progressing through the song
function pakettiStemSequentialSlicesAtStep(step_size)
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found. Load stems with 'Slice to Patterns' first.")
    return
  end
  
  -- Selection-only mode handling
  local sel_start_line, sel_end_line = nil, nil
  local sel_start_track, sel_end_track = nil, nil
  
  if stem_randomizer_selection_only then
    local selection = song.selection_in_pattern
    if not selection then
      renoise.app():show_status("Selection Only mode enabled but no selection in pattern")
      return
    end
    sel_start_line = selection.start_line
    sel_end_line = selection.end_line
    sel_start_track = selection.start_track
    sel_end_track = selection.end_track
    
    -- Filter sliced_tracks to only those within selection
    local filtered_tracks = {}
    for _, track_info in ipairs(sliced_tracks) do
      if track_info.track_index >= sel_start_track and track_info.track_index <= sel_end_track then
        table.insert(filtered_tracks, track_info)
      end
    end
    sliced_tracks = filtered_tracks
    
    if #sliced_tracks == 0 then
      renoise.app():show_status("No sliced stem tracks within selection")
      return
    end
  end
  
  -- Determine which patterns to process based on mode
  local seq_positions = {}
  if stem_randomizer_pattern_mode == "current" then
    seq_positions = {song.selected_sequence_index}
  else
    for i = 1, #song.sequencer.pattern_sequence do
      seq_positions[i] = i
    end
  end
  
  -- Calculate offsets for step size
  local triggers_per_64 = math.floor(64 / step_size)
  local offset_values = {}
  for i = 0, triggers_per_64 - 1 do
    offset_values[i + 1] = math.floor(i * 256 / triggers_per_64)
  end
  
  local selection_text = stem_randomizer_selection_only and " (selection only)" or ""
  print(string.format("Stem Sequential %d-Step: Found %d sliced tracks, %d patterns (%s mode)%s", 
    step_size, #sliced_tracks, #seq_positions, stem_randomizer_pattern_mode, selection_text))
  
  local total_triggers = 0
  
  for pos_idx, seq_pos in ipairs(seq_positions) do
    local pattern_index = song.sequencer.pattern_sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    local pattern_length = pattern.number_of_lines
    
    -- Determine line range to process
    local start_line = sel_start_line or 1
    local end_line = sel_end_line or pattern_length
    if end_line > pattern_length then end_line = pattern_length end
    
    local chunks_per_pattern = math.floor(pattern_length / step_size)
    if chunks_per_pattern < 1 then chunks_per_pattern = 1 end
    
    -- For sequential mode, use sequence position to determine starting slice
    local base_slice_offset = (seq_pos - 1) * chunks_per_pattern
    
    for _, track_info in ipairs(sliced_tracks) do
      local instrument = song.instruments[track_info.instrument_index]
      local base_note = 48
      if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
        base_note = instrument.samples[1].sample_mapping.base_note
      end
      
      -- Clear lines on this track in this pattern (only within selection if applicable)
      for row = start_line, end_line do
        local line = pattern.tracks[track_info.track_index].lines[row]
        if line then
          line.note_columns[1]:clear()
          line.effect_columns[1]:clear()
        end
      end
      
      -- Write sequential triggers at the specified step interval (only within selection if applicable)
      for chunk = 0, chunks_per_pattern - 1 do
        local row = (chunk * step_size) + 1
        if row >= start_line and row <= end_line then
          -- Sequential slice: progress through slices in order, wrapping if needed
          local slice_index = ((base_slice_offset + chunk) % track_info.slice_count) + 1
          local slice_note = base_note + slice_index
          if slice_note > 119 then slice_note = 119 end
          
          local offset = offset_values[(chunk % #offset_values) + 1]
          
          local line = pattern.tracks[track_info.track_index].lines[row]
          if line then
            line.note_columns[1].note_value = slice_note
            line.note_columns[1].instrument_value = track_info.instrument_index - 1
            line.effect_columns[1].number_string = "0S"
            line.effect_columns[1].amount_value = offset
            
            if song.tracks[track_info.track_index].visible_effect_columns < 1 then
              song.tracks[track_info.track_index].visible_effect_columns = 1
            end
          end
          
          total_triggers = total_triggers + 1
        end
      end
    end
  end
  
  local mode_text = stem_randomizer_pattern_mode == "current" and "current pattern" or string.format("%d patterns", #seq_positions)
  if stem_randomizer_selection_only then
    mode_text = mode_text .. " (selection only)"
  end
  print(string.format("Stem Sequential %d-Step: Wrote %d sequential triggers", step_size, total_triggers))
  renoise.app():show_status(string.format("Sequential slices every %d steps - %s", step_size, mode_text))
end

-- Write consecutive sequential slices to the current selection
-- This ALWAYS writes to the selection (ignores Selection Only checkbox)
-- Writes slices in order: 1, 2, 3... wrapping when slice count is exceeded
function pakettiStemSelectionSequentialSlices(step_size)
  local song = renoise.song()
  local sliced_tracks = pakettiStemFindSlicedTracks()
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks found. Load stems with 'Slice to Patterns' first.")
    return
  end
  
  -- This function ALWAYS requires a selection
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No selection in pattern - make a selection first")
    return
  end
  
  local sel_start_line = selection.start_line
  local sel_end_line = selection.end_line
  local sel_start_track = selection.start_track
  local sel_end_track = selection.end_track
  
  -- Filter sliced_tracks to only those within selection
  local filtered_tracks = {}
  for _, track_info in ipairs(sliced_tracks) do
    if track_info.track_index >= sel_start_track and track_info.track_index <= sel_end_track then
      table.insert(filtered_tracks, track_info)
    end
  end
  sliced_tracks = filtered_tracks
  
  if #sliced_tracks == 0 then
    renoise.app():show_status("No sliced stem tracks within selection")
    return
  end
  
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local pattern_length = pattern.number_of_lines
  
  -- Clamp selection to pattern bounds
  local start_line = sel_start_line
  local end_line = sel_end_line
  if end_line > pattern_length then end_line = pattern_length end
  
  -- Calculate how many rows are in the selection
  local selection_rows = (end_line - start_line) + 1
  
  -- Calculate how many triggers fit in the selection
  local triggers_count = math.floor(selection_rows / step_size)
  if triggers_count < 1 then triggers_count = 1 end
  
  -- Calculate offset values for sub-slice positioning
  local triggers_per_64 = math.floor(64 / step_size)
  if triggers_per_64 < 1 then triggers_per_64 = 1 end
  local offset_values = {}
  for i = 0, triggers_per_64 - 1 do
    offset_values[i + 1] = math.floor(i * 256 / triggers_per_64)
  end
  
  print(string.format("Stem Selection Sequential %d-Step: Found %d sliced tracks, selection rows %d-%d", 
    step_size, #sliced_tracks, start_line, end_line))
  
  local total_triggers = 0
  
  for _, track_info in ipairs(sliced_tracks) do
    local instrument = song.instruments[track_info.instrument_index]
    local base_note = 48
    if instrument and instrument.samples[1] and instrument.samples[1].sample_mapping then
      base_note = instrument.samples[1].sample_mapping.base_note
    end
    
    -- Clear lines on this track within selection
    for row = start_line, end_line do
      local line = pattern.tracks[track_info.track_index].lines[row]
      if line then
        line.note_columns[1]:clear()
        line.effect_columns[1]:clear()
      end
    end
    
    -- Write consecutive sequential slices at step intervals within selection
    local slice_counter = 0
    for trigger = 0, triggers_count - 1 do
      local row = start_line + (trigger * step_size)
      if row <= end_line then
        -- Sequential slice: 1, 2, 3, ... wrapping when exceeding slice count
        local slice_index = (slice_counter % track_info.slice_count) + 1
        local slice_note = base_note + slice_index
        if slice_note > 119 then slice_note = 119 end
        
        local offset = offset_values[(trigger % #offset_values) + 1]
        
        local line = pattern.tracks[track_info.track_index].lines[row]
        if line then
          line.note_columns[1].note_value = slice_note
          line.note_columns[1].instrument_value = track_info.instrument_index - 1
          line.effect_columns[1].number_string = "0S"
          line.effect_columns[1].amount_value = offset
          
          if song.tracks[track_info.track_index].visible_effect_columns < 1 then
            song.tracks[track_info.track_index].visible_effect_columns = 1
          end
        end
        
        slice_counter = slice_counter + 1
        total_triggers = total_triggers + 1
      end
    end
  end
  
  print(string.format("Stem Selection Sequential %d-Step: Wrote %d sequential triggers to selection", step_size, total_triggers))
  renoise.app():show_status(string.format("Sequential slices every %d steps to selection (rows %d-%d)", step_size, start_line, end_line))
end

-- Wrapper functions for Selection Sequential Slices at different step sizes
function pakettiStemSelectionSequential1() pakettiStemSelectionSequentialSlices(1) end
function pakettiStemSelectionSequential2() pakettiStemSelectionSequentialSlices(2) end
function pakettiStemSelectionSequential4() pakettiStemSelectionSequentialSlices(4) end
function pakettiStemSelectionSequential8() pakettiStemSelectionSequentialSlices(8) end
function pakettiStemSelectionSequential16() pakettiStemSelectionSequentialSlices(16) end
function pakettiStemSelectionSequential32() pakettiStemSelectionSequentialSlices(32) end
function pakettiStemSelectionSequential3() pakettiStemSelectionSequentialSlices(3) end
function pakettiStemSelectionSequential5() pakettiStemSelectionSequentialSlices(5) end
function pakettiStemSelectionSequential7() pakettiStemSelectionSequentialSlices(7) end
function pakettiStemSelectionSequential9() pakettiStemSelectionSequentialSlices(9) end
function pakettiStemSelectionSequential11() pakettiStemSelectionSequentialSlices(11) end
function pakettiStemSelectionSequential13() pakettiStemSelectionSequentialSlices(13) end
function pakettiStemSelectionSequential15() pakettiStemSelectionSequentialSlices(15) end
function pakettiStemSelectionSequential17() pakettiStemSelectionSequentialSlices(17) end
function pakettiStemSelectionSequential19() pakettiStemSelectionSequentialSlices(19) end
function pakettiStemSelectionSequential21() pakettiStemSelectionSequentialSlices(21) end
function pakettiStemSelectionSequential23() pakettiStemSelectionSequentialSlices(23) end
function pakettiStemSelectionSequential25() pakettiStemSelectionSequentialSlices(25) end
function pakettiStemSelectionSequential27() pakettiStemSelectionSequentialSlices(27) end
function pakettiStemSelectionSequential29() pakettiStemSelectionSequentialSlices(29) end
function pakettiStemSelectionSequential31() pakettiStemSelectionSequentialSlices(31) end

-----------
-- Forwards+Reverse Slice Randomization
-- Randomly chooses between forwards and reversed versions based on probability
-----------

-- Current reverse probability (0-100, where 50 = random, 0 = all forwards, 100 = all reverse)
local current_reverse_probability = 50

-- Find forwards/reverse pairs that have slices (ONE track, TWO instruments)
local function pakettiStemFindFwdRevSlicedPairs()
  local song = renoise.song()
  local valid_pairs = {}
  
  for _, pair in ipairs(stem_forwards_reverse_pairs) do
    local fwd_instrument = song.instruments[pair.fwd_instrument]
    local rev_instrument = song.instruments[pair.rev_instrument]
    
    if fwd_instrument and fwd_instrument.samples[1] and
       rev_instrument and rev_instrument.samples[1] then
      local fwd_slice_count = #fwd_instrument.samples[1].slice_markers
      local rev_slice_count = #rev_instrument.samples[1].slice_markers
      
      if fwd_slice_count > 0 and rev_slice_count > 0 then
        table.insert(valid_pairs, {
          track = pair.track,  -- Single track for both fwd and rev
          fwd_instrument = pair.fwd_instrument,
          rev_instrument = pair.rev_instrument,
          slice_count = math.min(fwd_slice_count, rev_slice_count),
          name = pair.name
        })
      end
    end
  end
  
  return valid_pairs
end

-- Randomize forwards/reverse with probability control at specified step interval
-- Uses ONE track per stem, alternates between fwd/rev INSTRUMENT numbers
-- step_size: 1, 2, 4, 8, 16, or 32
-- reverse_probability: 0-100 (0 = all forwards, 50 = random, 100 = all reverse)
function pakettiStemRandomizeSlicesForwardsReverse(step_size, reverse_probability)
  local song = renoise.song()
  local fwdrev_pairs = pakettiStemFindFwdRevSlicedPairs()
  
  if #fwdrev_pairs == 0 then
    renoise.app():show_status("No forwards/reverse pairs found. Use 'Stem Loader (Forwards+Reverse)' first.")
    return
  end
  
  -- Selection-only mode handling
  local sel_start_line, sel_end_line = nil, nil
  local sel_start_track, sel_end_track = nil, nil
  
  if stem_randomizer_selection_only then
    local selection = song.selection_in_pattern
    if not selection then
      renoise.app():show_status("Selection Only mode enabled but no selection in pattern")
      return
    end
    sel_start_line = selection.start_line
    sel_end_line = selection.end_line
    sel_start_track = selection.start_track
    sel_end_track = selection.end_track
    
    -- Filter fwdrev_pairs to only those within selection
    local filtered_pairs = {}
    for _, pair in ipairs(fwdrev_pairs) do
      if pair.track >= sel_start_track and pair.track <= sel_end_track then
        table.insert(filtered_pairs, pair)
      end
    end
    fwdrev_pairs = filtered_pairs
    
    if #fwdrev_pairs == 0 then
      renoise.app():show_status("No forwards/reverse pairs within selection")
      return
    end
  end
  
  -- Determine which patterns to process based on mode
  local seq_positions = {}
  if stem_randomizer_pattern_mode == "current" then
    seq_positions = {song.selected_sequence_index}
  else
    for i = 1, #song.sequencer.pattern_sequence do
      seq_positions[i] = i
    end
  end
  
  local prob = reverse_probability or current_reverse_probability
  
  -- Calculate offsets for step size
  local triggers_per_64 = math.floor(64 / step_size)
  local offset_values = {}
  for i = 0, triggers_per_64 - 1 do
    offset_values[i + 1] = math.floor(i * 256 / triggers_per_64)
  end
  
  local selection_text = stem_randomizer_selection_only and " (selection only)" or ""
  print(string.format("Stem Randomize FwdRev: %d pairs, %d patterns (%s mode)%s, step=%d, reverse_prob=%d%%",
    #fwdrev_pairs, #seq_positions, stem_randomizer_pattern_mode, selection_text, step_size, prob))
  
  local total_fwd = 0
  local total_rev = 0
  
  for _, seq_pos in ipairs(seq_positions) do
    local pattern_index = song.sequencer.pattern_sequence[seq_pos]
    local pattern = song.patterns[pattern_index]
    local pattern_length = pattern.number_of_lines
    
    -- Determine line range to process
    local start_line = sel_start_line or 1
    local end_line = sel_end_line or pattern_length
    if end_line > pattern_length then end_line = pattern_length end
    
    local chunks_per_pattern = math.floor(pattern_length / step_size)
    if chunks_per_pattern < 1 then chunks_per_pattern = 1 end
    
    for _, pair in ipairs(fwdrev_pairs) do
      local track_index = pair.track  -- ONE track for both fwd and rev
      
      -- Get base notes for both instruments
      local fwd_instrument = song.instruments[pair.fwd_instrument]
      local rev_instrument = song.instruments[pair.rev_instrument]
      
      local fwd_base_note = 48
      local rev_base_note = 48
      if fwd_instrument and fwd_instrument.samples[1] and fwd_instrument.samples[1].sample_mapping then
        fwd_base_note = fwd_instrument.samples[1].sample_mapping.base_note
      end
      if rev_instrument and rev_instrument.samples[1] and rev_instrument.samples[1].sample_mapping then
        rev_base_note = rev_instrument.samples[1].sample_mapping.base_note
      end
      
      -- Clear the track in this pattern (only within selection if applicable)
      for row = start_line, end_line do
        if pattern.tracks[track_index] then
          local line = pattern.tracks[track_index].lines[row]
          if line then
            line.note_columns[1]:clear()
            line.effect_columns[1]:clear()
          end
        end
      end
      
      -- Write triggers at step intervals, alternating between fwd/rev instruments (only within selection if applicable)
      for chunk = 0, chunks_per_pattern - 1 do
        local row = (chunk * step_size) + 1
        if row >= start_line and row <= end_line then
          -- Decide forwards or reverse based on probability
          local use_reverse = (math.random(100) <= prob)
          
          local instrument_index, base_note
          if use_reverse then
            instrument_index = pair.rev_instrument - 1  -- 0-based
            base_note = rev_base_note
            total_rev = total_rev + 1
          else
            instrument_index = pair.fwd_instrument - 1  -- 0-based
            base_note = fwd_base_note
            total_fwd = total_fwd + 1
          end
          
          -- Random slice
          local random_slice = math.random(1, pair.slice_count)
          local slice_note = base_note + random_slice
          if slice_note > 119 then slice_note = 119 end
          
          local offset = offset_values[(chunk % #offset_values) + 1]
          
          if pattern.tracks[track_index] then
            local line = pattern.tracks[track_index].lines[row]
            if line then
              line.note_columns[1].note_value = slice_note
              line.note_columns[1].instrument_value = instrument_index
              line.effect_columns[1].number_string = "0S"
              line.effect_columns[1].amount_value = offset
              
              if song.tracks[track_index].visible_effect_columns < 1 then
                song.tracks[track_index].visible_effect_columns = 1
              end
            end
          end
        end
      end
    end
  end
  
  local mode_text = stem_randomizer_pattern_mode == "current" and "current pattern" or string.format("%d patterns", #seq_positions)
  if stem_randomizer_selection_only then
    mode_text = mode_text .. " (selection only)"
  end
  print(string.format("Stem Randomize FwdRev: %d forwards, %d reversed triggers",
    total_fwd, total_rev))
  renoise.app():show_status(string.format("FwdRev: %d%% reverse - %d fwd, %d rev - %s",
    prob, total_fwd, total_rev, mode_text))
end

-- Wrapper with current probability
function pakettiStemRandomizeSlicesForwardsReverseWithCurrentProb(step_size)
  pakettiStemRandomizeSlicesForwardsReverse(step_size, current_reverse_probability)
end

-- Set the reverse probability
function pakettiStemSetReverseProbability(prob)
  if prob < 0 then prob = 0 end
  if prob > 100 then prob = 100 end
  current_reverse_probability = prob
end

-- Get the current reverse probability
function pakettiStemGetReverseProbability()
  return current_reverse_probability
end

-----------
-- Stem Slice Randomizer Dialog
-----------

local stem_slice_randomizer_dialog = nil
local stem_slice_randomizer_vb = nil

-- Carry Selection feature - preserves line range across track changes
PakettiCarrySelectionEnabled = false
PakettiCarrySelectionRange = nil
PakettiCarrySelectionLastTrack = nil

-- Idle notifier for Carry Selection feature
function PakettiCarrySelectionIdleNotifier()
  if not PakettiCarrySelectionEnabled then
    return
  end
  
  if not PakettiCarrySelectionRange then
    return
  end
  
  local song
  local success = pcall(function()
    song = renoise.song()
  end)
  
  if not success or not song then
    return
  end
  
  -- Only work in pattern editor
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    return
  end
  
  local current_track = song.selected_track_index
  
  -- Check if track changed
  if current_track ~= PakettiCarrySelectionLastTrack then
    PakettiCarrySelectionLastTrack = current_track
    
    -- Get track info for column range
    local track = song.selected_track
    local last_column = track.visible_note_columns + track.visible_effect_columns
    
    -- Apply the saved line range to the new track
    song.selection_in_pattern = {
      start_line = PakettiCarrySelectionRange.start_line,
      end_line = PakettiCarrySelectionRange.end_line,
      start_track = current_track,
      end_track = current_track,
      start_column = 1,
      end_column = last_column
    }
  end
end

-- Attach the Keep Selection idle notifier
function PakettiCarrySelectionAttachNotifier()
  if not renoise.tool().app_idle_observable:has_notifier(PakettiCarrySelectionIdleNotifier) then
    renoise.tool().app_idle_observable:add_notifier(PakettiCarrySelectionIdleNotifier)
  end
end

-- Detach the Keep Selection idle notifier
function PakettiCarrySelectionDetachNotifier()
  if renoise.tool().app_idle_observable:has_notifier(PakettiCarrySelectionIdleNotifier) then
    renoise.tool().app_idle_observable:remove_notifier(PakettiCarrySelectionIdleNotifier)
  end
end

-- Toggle Keep Selection feature
function PakettiCarrySelectionToggle()
  PakettiCarrySelectionEnabled = not PakettiCarrySelectionEnabled
  
  if PakettiCarrySelectionEnabled then
    local song = renoise.song()
    local selection = song.selection_in_pattern
    
    if selection then
      -- Save the current selection's line range
      PakettiCarrySelectionRange = {
        start_line = selection.start_line,
        end_line = selection.end_line
      }
      PakettiCarrySelectionLastTrack = song.selected_track_index
      
      PakettiCarrySelectionAttachNotifier()
      
      renoise.app():show_status("Carry Selection: ON (Lines " .. 
        PakettiCarrySelectionRange.start_line .. "-" .. 
        PakettiCarrySelectionRange.end_line .. ")")
    else
      -- No selection exists, create one for current line to end of pattern
      local pattern = song.selected_pattern
      PakettiCarrySelectionRange = {
        start_line = song.selected_line_index,
        end_line = pattern.number_of_lines
      }
      PakettiCarrySelectionLastTrack = song.selected_track_index
      
      PakettiCarrySelectionAttachNotifier()
      
      renoise.app():show_status("Carry Selection: ON (Lines " .. 
        PakettiCarrySelectionRange.start_line .. "-" .. 
        PakettiCarrySelectionRange.end_line .. ")")
    end
  else
    PakettiCarrySelectionDetachNotifier()
    PakettiCarrySelectionRange = nil
    PakettiCarrySelectionLastTrack = nil
    
    renoise.app():show_status("Carry Selection: OFF")
  end
end

-- Return enabled state for checkbox
function PakettiCarrySelectionIsEnabled()
  return PakettiCarrySelectionEnabled
end

-- Valid step sizes for the sliders
local stem_slice_step_sizes = {1, 2, 4, 8, 16, 32}

-- Convert slider value (1-6) to step size
local function sliderToStepSize(slider_value)
  return stem_slice_step_sizes[slider_value] or 1
end

-- Convert step size to slider value (1-6)
local function stepSizeToSlider(step_size)
  for i, size in ipairs(stem_slice_step_sizes) do
    if size == step_size then return i end
  end
  return 1
end

-- Valid step sizes for odd signatures
local stem_slice_odd_step_sizes = {3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31}

-- Convert slider value (1-15) to odd step size
local function sliderToOddStepSize(slider_value)
  return stem_slice_odd_step_sizes[slider_value] or 3
end

-- Convert odd step size to slider value (1-15)
local function oddStepSizeToSlider(step_size)
  for i, size in ipairs(stem_slice_odd_step_sizes) do
    if size == step_size then return i end
  end
  return 1
end

-- Current step sizes for display
local current_independent_step = 16
local current_synchronized_step = 16
local current_odd_independent_step = 3
local current_odd_synchronized_step = 3

function pakettiStemSliceRandomizerDialog()
  if stem_slice_randomizer_dialog and stem_slice_randomizer_dialog.visible then
    -- Disable Selection Follow to End if it was enabled via checkbox
    if PakettiSelectionFollowToEndEnabled then
      PakettiSelectionFollowToEndToggle()
    end
    -- Disable Keep Selection if it was enabled via checkbox
    if PakettiCarrySelectionEnabled then
      PakettiCarrySelectionToggle()
    end
    stem_slice_randomizer_dialog:close()
    stem_slice_randomizer_dialog = nil
    return
  end
  
  stem_slice_randomizer_vb = renoise.ViewBuilder()
  local vb = stem_slice_randomizer_vb
  
  -- Track last triggered step to avoid duplicate triggers
  local last_independent_step = current_independent_step
  local last_synchronized_step = current_synchronized_step
  local last_odd_independent_step = current_odd_independent_step
  local last_odd_synchronized_step = current_odd_synchronized_step
  local last_reverse_prob = current_reverse_probability
  local last_fwdrev_step = current_independent_step  -- Use independent step for fwd/rev
  
  local dialog_content = vb:column{
    vb:row{
      vb:text{text = "Independent", font="bold", style="strong", width=80},
      vb:slider{
        id = "independent_slider",
        min = 1,
        max = 6,
        steps = {1, 1},
        default = stepSizeToSlider(current_independent_step),
        value = stepSizeToSlider(current_independent_step),
        width = 120,
        notifier = function(value)
          local snapped = math.floor(value + 0.5)
          if snapped < 1 then snapped = 1 end
          if snapped > 6 then snapped = 6 end
          local new_step = stem_slice_step_sizes[snapped]
          vb.views.independent_label.text = tostring(new_step)
          if new_step ~= last_independent_step then
            last_independent_step = new_step
            current_independent_step = new_step
            pakettiStemRandomizeSlicesStepIndependent(new_step)
          end
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:text{id = "independent_label", text = tostring(current_independent_step), width=30}
    },
    vb:row{
      vb:text{text = "Synchronized", font="bold", style="strong", width=80},
      vb:slider{
        id = "synchronized_slider",
        min = 1,
        max = 6,
        steps = {1, 1},
        default = stepSizeToSlider(current_synchronized_step),
        value = stepSizeToSlider(current_synchronized_step),
        width = 120,
        notifier = function(value)
          local snapped = math.floor(value + 0.5)
          if snapped < 1 then snapped = 1 end
          if snapped > 6 then snapped = 6 end
          local new_step = stem_slice_step_sizes[snapped]
          vb.views.synchronized_label.text = tostring(new_step)
          if new_step ~= last_synchronized_step then
            last_synchronized_step = new_step
            current_synchronized_step = new_step
            pakettiStemRandomizeSlicesStepSynchronized(new_step)
          end
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:text{id = "synchronized_label", text = tostring(current_synchronized_step), width=30}
    },
    vb:row{
      vb:text{text = "Odd Indep", font="bold", style="strong", width=80},
      vb:slider{
        id = "odd_independent_slider",
        min = 1,
        max = 15,
        steps = {1, 1},
        default = oddStepSizeToSlider(current_odd_independent_step),
        value = oddStepSizeToSlider(current_odd_independent_step),
        width = 120,
        notifier = function(value)
          local snapped = math.floor(value + 0.5)
          if snapped < 1 then snapped = 1 end
          if snapped > 15 then snapped = 15 end
          local new_step = stem_slice_odd_step_sizes[snapped]
          vb.views.odd_independent_label.text = tostring(new_step)
          if new_step ~= last_odd_independent_step then
            last_odd_independent_step = new_step
            current_odd_independent_step = new_step
            pakettiStemRandomizeSlicesStepIndependent(new_step)
          end
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:text{id = "odd_independent_label", text = tostring(current_odd_independent_step), width=30}
    },
    vb:row{
      vb:text{text = "Odd Synced", font="bold", style="strong", width=80},
      vb:slider{
        id = "odd_synchronized_slider",
        min = 1,
        max = 15,
        steps = {1, 1},
        default = oddStepSizeToSlider(current_odd_synchronized_step),
        value = oddStepSizeToSlider(current_odd_synchronized_step),
        width = 120,
        notifier = function(value)
          local snapped = math.floor(value + 0.5)
          if snapped < 1 then snapped = 1 end
          if snapped > 15 then snapped = 15 end
          local new_step = stem_slice_odd_step_sizes[snapped]
          vb.views.odd_synchronized_label.text = tostring(new_step)
          if new_step ~= last_odd_synchronized_step then
            last_odd_synchronized_step = new_step
            current_odd_synchronized_step = new_step
            pakettiStemRandomizeSlicesStepSynchronized(new_step)
          end
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:text{id = "odd_synchronized_label", text = tostring(current_odd_synchronized_step), width=30}
    },
    vb:row{
      vb:text{text = "Reverse %", font="bold", style="strong", width=80},
      vb:slider{
        id = "reverse_slider",
        min = 0,
        max = 100,
        steps = {1, 10},
        default = current_reverse_probability,
        value = current_reverse_probability,
        width = 120,
        notifier = function(value)
          local new_prob = math.floor(value + 0.5)
          if new_prob < 0 then new_prob = 0 end
          if new_prob > 100 then new_prob = 100 end
          vb.views.reverse_label.text = tostring(new_prob) .. "%"
          if new_prob ~= last_reverse_prob then
            last_reverse_prob = new_prob
            current_reverse_probability = new_prob
            pakettiStemRandomizeSlicesForwardsReverse(current_independent_step, new_prob)
          end
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:text{id = "reverse_label", text = tostring(current_reverse_probability) .. "%", width=40}
    },
    vb:row{
      vb:text{text = "Mode:", font="bold", style="strong", width=80},
      vb:switch{
        id = "mode_switch",
        items = {"Current", "All"},
        value = stem_randomizer_pattern_mode == "current" and 1 or 2,
        width = 150,
        notifier = function(index)
          if index == 1 then
            stem_randomizer_pattern_mode = "current"
          else
            stem_randomizer_pattern_mode = "all"
          end
          print("Stem Randomizer: Mode set to " .. stem_randomizer_pattern_mode)
        end
      }
    },
    vb:row{
      vb:checkbox{
        id = "selection_checkbox",
        value = stem_randomizer_selection_only,
        notifier = function(value)
          stem_randomizer_selection_only = value
          print("Stem Randomizer: Selection only = " .. tostring(value))
        end
      },
      vb:text{text = "Selection Only", style = "strong", font = "bold"}
    },
    vb:row{
      vb:checkbox{
        id = "select_till_end_checkbox",
        value = PakettiSelectionFollowToEndEnabled or false,
        notifier = function(value)
          if value then
            -- Enable Selection Follow to End
            if not PakettiSelectionFollowToEndEnabled then
              PakettiSelectionFollowToEndToggle()
            end
            -- Also enable Selection Only when Select till End is enabled
            if not stem_randomizer_selection_only then
              stem_randomizer_selection_only = true
              vb.views.selection_checkbox.value = true
            end
            -- Disable Keep Selection if it's enabled (mutually exclusive)
            if PakettiCarrySelectionEnabled then
              PakettiCarrySelectionToggle()
              vb.views.carry_selection_checkbox.value = false
            end
          else
            -- Disable Selection Follow to End
            if PakettiSelectionFollowToEndEnabled then
              PakettiSelectionFollowToEndToggle()
            end
          end
        end
      },
      vb:text{text = "Select till End of Pattern", style = "strong", font = "bold"}
    },
    vb:row{
      vb:checkbox{
        id = "carry_selection_checkbox",
        value = PakettiCarrySelectionEnabled or false,
        notifier = function(value)
          if value then
            -- Enable Keep Selection
            if not PakettiCarrySelectionEnabled then
              PakettiCarrySelectionToggle()
            end
            -- Also enable Selection Only when Keep Selection is enabled
            if not stem_randomizer_selection_only then
              stem_randomizer_selection_only = true
              vb.views.selection_checkbox.value = true
            end
            -- Disable Select till End if it's enabled (mutually exclusive)
            if PakettiSelectionFollowToEndEnabled then
              PakettiSelectionFollowToEndToggle()
              vb.views.select_till_end_checkbox.value = false
            end
          else
            -- Disable Keep Selection
            if PakettiCarrySelectionEnabled then
              PakettiCarrySelectionToggle()
            end
          end
        end
      },
      vb:text{text = "Carry Selection", style = "strong", font = "bold"}
    },
    vb:row{
      vb:button{
        text = "Dupe",
        width = 40,
        notifier = function()
          pakettiStemDuplicatePatternAndJump()
        end
      },
      vb:button{
        text = "Roll",
        width = 40,
        notifier = function()
          -- Re-roll using the last used step size (synchronized)
          pakettiStemRandomizeSlicesStepSynchronized(current_synchronized_step)
        end
      },
      vb:button{
        text = "Fwd",
        width = 40,
        notifier = function()
          pakettiStemSequentialSlicesAtStep(current_independent_step)
        end
      },
      vb:button{
        text = "Sel",
        width = 40,
        tooltip = "Write sequential slices to selection",
        notifier = function()
          pakettiStemSelectionSequentialSlices(current_independent_step)
        end
      },
      vb:button{
        text = "Reset",
        width = 40,
        notifier = function()
          pakettiStemResetSlicesToSequential()
        end
      },
      vb:button{
        text = "Close",
        width = 40,
        notifier = function()
          if stem_slice_randomizer_dialog and stem_slice_randomizer_dialog.visible then
            -- Disable Selection Follow to End if it was enabled via checkbox
            if PakettiSelectionFollowToEndEnabled then
              PakettiSelectionFollowToEndToggle()
            end
            -- Disable Keep Selection if it was enabled via checkbox
            if PakettiCarrySelectionEnabled then
              PakettiCarrySelectionToggle()
            end
            stem_slice_randomizer_dialog:close()
          end
        end
      }
    }
  }
  
  stem_slice_randomizer_dialog = renoise.app():show_custom_dialog(
    "Paketti Stem Slice Randomizer",
    dialog_content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- MIDI knob handlers for continuous control
-- Maps MIDI CC value (0-127) to step sizes (1, 2, 4, 8, 16, 32)
local function midiValueToStepSize(midi_value)
  -- Divide 0-127 into 6 zones for the 6 step sizes
  local zone = math.floor(midi_value / 21.33)  -- 127 / 6 ≈ 21.33
  if zone < 0 then zone = 0 end
  if zone > 5 then zone = 5 end
  return stem_slice_step_sizes[zone + 1]
end

local last_independent_midi_step = nil
local last_synchronized_midi_step = nil

local function pakettiStemSliceRandomizerMidiIndependent(message)
  if message:is_abs_value() then
    local step_size = midiValueToStepSize(message.int_value)
    -- Only trigger if step size changed (prevents repeated triggers)
    if step_size ~= last_independent_midi_step then
      last_independent_midi_step = step_size
      current_independent_step = step_size
      pakettiStemRandomizeSlicesStepIndependent(step_size)
      -- Update dialog slider if open
      if stem_slice_randomizer_vb and stem_slice_randomizer_dialog and stem_slice_randomizer_dialog.visible then
        stem_slice_randomizer_vb.views.independent_slider.value = stepSizeToSlider(step_size)
        stem_slice_randomizer_vb.views.independent_label.text = tostring(step_size)
      end
    end
  end
end

local function pakettiStemSliceRandomizerMidiSynchronized(message)
  if message:is_abs_value() then
    local step_size = midiValueToStepSize(message.int_value)
    -- Only trigger if step size changed (prevents repeated triggers)
    if step_size ~= last_synchronized_midi_step then
      last_synchronized_midi_step = step_size
      current_synchronized_step = step_size
      pakettiStemRandomizeSlicesStepSynchronized(step_size)
      -- Update dialog slider if open
      if stem_slice_randomizer_vb and stem_slice_randomizer_dialog and stem_slice_randomizer_dialog.visible then
        stem_slice_randomizer_vb.views.synchronized_slider.value = stepSizeToSlider(step_size)
        stem_slice_randomizer_vb.views.synchronized_label.text = tostring(step_size)
      end
    end
  end
end

-- MIDI knob handlers for odd step sizes
-- Maps MIDI CC value (0-127) to odd step sizes (3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31)
local function midiValueToOddStepSize(midi_value)
  -- Divide 0-127 into 15 zones for the 15 odd step sizes
  local zone = math.floor(midi_value / 8.47)  -- 127 / 15 ≈ 8.47
  if zone < 0 then zone = 0 end
  if zone > 14 then zone = 14 end
  return stem_slice_odd_step_sizes[zone + 1]
end

local last_odd_independent_midi_step = nil
local last_odd_synchronized_midi_step = nil

local function pakettiStemSliceRandomizerMidiOddIndependent(message)
  if message:is_abs_value() then
    local step_size = midiValueToOddStepSize(message.int_value)
    -- Only trigger if step size changed (prevents repeated triggers)
    if step_size ~= last_odd_independent_midi_step then
      last_odd_independent_midi_step = step_size
      current_odd_independent_step = step_size
      pakettiStemRandomizeSlicesStepIndependent(step_size)
      -- Update dialog slider if open
      if stem_slice_randomizer_vb and stem_slice_randomizer_dialog and stem_slice_randomizer_dialog.visible then
        stem_slice_randomizer_vb.views.odd_independent_slider.value = oddStepSizeToSlider(step_size)
        stem_slice_randomizer_vb.views.odd_independent_label.text = tostring(step_size)
      end
    end
  end
end

local function pakettiStemSliceRandomizerMidiOddSynchronized(message)
  if message:is_abs_value() then
    local step_size = midiValueToOddStepSize(message.int_value)
    -- Only trigger if step size changed (prevents repeated triggers)
    if step_size ~= last_odd_synchronized_midi_step then
      last_odd_synchronized_midi_step = step_size
      current_odd_synchronized_step = step_size
      pakettiStemRandomizeSlicesStepSynchronized(step_size)
      -- Update dialog slider if open
      if stem_slice_randomizer_vb and stem_slice_randomizer_dialog and stem_slice_randomizer_dialog.visible then
        stem_slice_randomizer_vb.views.odd_synchronized_slider.value = oddStepSizeToSlider(step_size)
        stem_slice_randomizer_vb.views.odd_synchronized_label.text = tostring(step_size)
      end
    end
  end
end

-- Keybindings for slice randomization
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices (Independent)",invoke=function() pakettiStemRandomizeSlicesIndependent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices (Synchronized)",invoke=function() pakettiStemRandomizeSlicesSynchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Stem Slices to Sequential",invoke=function() pakettiStemResetSlicesToSequential() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 16 (Independent)",invoke=function() pakettiStemRandomizeSlices16Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 16 (Synchronized)",invoke=function() pakettiStemRandomizeSlices16Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 8 (Independent)",invoke=function() pakettiStemRandomizeSlices8Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 8 (Synchronized)",invoke=function() pakettiStemRandomizeSlices8Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 4 (Independent)",invoke=function() pakettiStemRandomizeSlices4Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 4 (Synchronized)",invoke=function() pakettiStemRandomizeSlices4Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 2 (Independent)",invoke=function() pakettiStemRandomizeSlices2Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 2 (Synchronized)",invoke=function() pakettiStemRandomizeSlices2Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 1 (Independent)",invoke=function() pakettiStemRandomizeSlices1Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 1 (Synchronized)",invoke=function() pakettiStemRandomizeSlices1Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 32 (Independent)",invoke=function() pakettiStemRandomizeSlices32Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 32 (Synchronized)",invoke=function() pakettiStemRandomizeSlices32Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Stem Slice Randomizer Dialog...",invoke=function() pakettiStemSliceRandomizerDialog() end}

-- Keybindings for odd step sizes
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 3 (Independent)",invoke=function() pakettiStemRandomizeSlices3Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 3 (Synchronized)",invoke=function() pakettiStemRandomizeSlices3Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 5 (Independent)",invoke=function() pakettiStemRandomizeSlices5Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 5 (Synchronized)",invoke=function() pakettiStemRandomizeSlices5Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 7 (Independent)",invoke=function() pakettiStemRandomizeSlices7Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 7 (Synchronized)",invoke=function() pakettiStemRandomizeSlices7Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 9 (Independent)",invoke=function() pakettiStemRandomizeSlices9Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 9 (Synchronized)",invoke=function() pakettiStemRandomizeSlices9Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 11 (Independent)",invoke=function() pakettiStemRandomizeSlices11Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 11 (Synchronized)",invoke=function() pakettiStemRandomizeSlices11Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 13 (Independent)",invoke=function() pakettiStemRandomizeSlices13Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 13 (Synchronized)",invoke=function() pakettiStemRandomizeSlices13Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 15 (Independent)",invoke=function() pakettiStemRandomizeSlices15Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 15 (Synchronized)",invoke=function() pakettiStemRandomizeSlices15Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 17 (Independent)",invoke=function() pakettiStemRandomizeSlices17Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 17 (Synchronized)",invoke=function() pakettiStemRandomizeSlices17Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 19 (Independent)",invoke=function() pakettiStemRandomizeSlices19Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 19 (Synchronized)",invoke=function() pakettiStemRandomizeSlices19Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 21 (Independent)",invoke=function() pakettiStemRandomizeSlices21Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 21 (Synchronized)",invoke=function() pakettiStemRandomizeSlices21Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 23 (Independent)",invoke=function() pakettiStemRandomizeSlices23Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 23 (Synchronized)",invoke=function() pakettiStemRandomizeSlices23Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 25 (Independent)",invoke=function() pakettiStemRandomizeSlices25Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 25 (Synchronized)",invoke=function() pakettiStemRandomizeSlices25Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 27 (Independent)",invoke=function() pakettiStemRandomizeSlices27Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 27 (Synchronized)",invoke=function() pakettiStemRandomizeSlices27Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 29 (Independent)",invoke=function() pakettiStemRandomizeSlices29Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 29 (Synchronized)",invoke=function() pakettiStemRandomizeSlices29Synchronized() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 31 (Independent)",invoke=function() pakettiStemRandomizeSlices31Independent() end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Stem Slices Every 31 (Synchronized)",invoke=function() pakettiStemRandomizeSlices31Synchronized() end}

-- Keybindings for Selection Sequential Slices
renoise.tool():add_keybinding{name="Global:Paketti:Selection Sequential Slices Every 1",invoke=function() pakettiStemSelectionSequential1() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selection Sequential Slices Every 2",invoke=function() pakettiStemSelectionSequential2() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selection Sequential Slices Every 4",invoke=function() pakettiStemSelectionSequential4() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selection Sequential Slices Every 8",invoke=function() pakettiStemSelectionSequential8() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selection Sequential Slices Every 16",invoke=function() pakettiStemSelectionSequential16() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selection Sequential Slices Every 32",invoke=function() pakettiStemSelectionSequential32() end}

-- MIDI mappings for slice randomization
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlicesIndependent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlicesSynchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Reset Stem Slices to Sequential",invoke=function(message) if message:is_trigger() then pakettiStemResetSlicesToSequential() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 16 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices16Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 16 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices16Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 8 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices8Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 8 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices8Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 4 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices4Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 4 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices4Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 2 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices2Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 2 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices2Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 1 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices1Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 1 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices1Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 32 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices32Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 32 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices32Synchronized() end end}

-- MIDI mappings for odd step sizes
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 3 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices3Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 3 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices3Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 5 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices5Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 5 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices5Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 7 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices7Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 7 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices7Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 9 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices9Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 9 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices9Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 11 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices11Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 11 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices11Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 13 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices13Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 13 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices13Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 15 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices15Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 15 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices15Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 17 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices17Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 17 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices17Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 19 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices19Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 19 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices19Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 21 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices21Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 21 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices21Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 23 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices23Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 23 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices23Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 25 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices25Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 25 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices25Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 27 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices27Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 27 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices27Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 29 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices29Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 29 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices29Synchronized() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 31 (Independent)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices31Independent() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Randomize Stem Slices Every 31 (Synchronized)",invoke=function(message) if message:is_trigger() then pakettiStemRandomizeSlices31Synchronized() end end}

-- MIDI mappings for Selection Sequential Slices
renoise.tool():add_midi_mapping{name="Paketti:Midi Selection Sequential Slices Every 1",invoke=function(message) if message:is_trigger() then pakettiStemSelectionSequential1() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selection Sequential Slices Every 2",invoke=function(message) if message:is_trigger() then pakettiStemSelectionSequential2() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selection Sequential Slices Every 4",invoke=function(message) if message:is_trigger() then pakettiStemSelectionSequential4() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selection Sequential Slices Every 8",invoke=function(message) if message:is_trigger() then pakettiStemSelectionSequential8() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selection Sequential Slices Every 16",invoke=function(message) if message:is_trigger() then pakettiStemSelectionSequential16() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selection Sequential Slices Every 32",invoke=function(message) if message:is_trigger() then pakettiStemSelectionSequential32() end end}

-- MIDI knob mappings for continuous control (use with MIDI knobs/encoders)
renoise.tool():add_midi_mapping{name="Paketti:Midi Knob Stem Slice Randomizer (Independent)",invoke=pakettiStemSliceRandomizerMidiIndependent}
renoise.tool():add_midi_mapping{name="Paketti:Midi Knob Stem Slice Randomizer (Synchronized)",invoke=pakettiStemSliceRandomizerMidiSynchronized}
renoise.tool():add_midi_mapping{name="Paketti:Midi Knob Stem Slice Randomizer Odd (Independent)",invoke=pakettiStemSliceRandomizerMidiOddIndependent}
renoise.tool():add_midi_mapping{name="Paketti:Midi Knob Stem Slice Randomizer Odd (Synchronized)",invoke=pakettiStemSliceRandomizerMidiOddSynchronized}

