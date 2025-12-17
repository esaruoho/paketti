local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

--------------------------------------------------------------------------------
-- Helper: Read and process slice marker file.
-- The file is assumed to contain lines like:
--    renoise.song().selected_sample:insert_slice_marker(12345)
--------------------------------------------------------------------------------
local function load_slice_markers(slice_file_path)
  local file = io.open(slice_file_path, "r")
  if not file then
    renoise.app():show_status("Could not open slice marker file: " .. slice_file_path)
    return false
  end
  
  local marker_count = 0
  local max_markers = 255
  local was_truncated = false
  
  for line in file:lines() do
    -- Extract the number between parentheses, e.g. "insert_slice_marker(12345)"
    local marker = tonumber(line:match("%((%d+)%)"))
    if marker then
      -- Check if we're about to exceed the 255 marker limit
      if marker_count >= max_markers then
        print("Warning: RX2 file contains more than " .. max_markers .. " slice markers.")
        print("Renoise only supports up to " .. max_markers .. " slice markers per instrument.")
        print("Skipping remaining " .. (marker_count + 1) .. "+ markers to avoid crash.")
        was_truncated = true
        break
      end
      
      -- Use pcall to safely insert the slice marker and catch any errors
      local success, error_msg = pcall(function()
        renoise.song().selected_sample:insert_slice_marker(marker)
      end)
      
      if success then
        marker_count = marker_count + 1
        print("Inserted slice marker " .. marker_count .. " at position", marker)
      else
        print("Error inserting slice marker at position " .. marker .. ": " .. tostring(error_msg))
        if string.find(tostring(error_msg), "255 slice markers") or 
           string.find(tostring(error_msg), "only up to 255") then
          print("Reached maximum slice marker limit. Stopping import of additional markers.")
          was_truncated = true
          break
        end
        -- For other errors, continue trying to insert remaining markers
      end
    else
      print("Warning: Could not parse marker from line:", line)
    end
  end
  
  file:close()
  print("Total slice markers imported: " .. marker_count)
  return true, marker_count, was_truncated
end

--------------------------------------------------------------------------------
-- Helper: Check if an instrument is completely empty (no samples with data)
--------------------------------------------------------------------------------
local function is_instrument_empty(instrument)
  if #instrument.samples == 0 then
    return true
  end
  
  for i = 1, #instrument.samples do
    local sample = instrument.samples[i]
    if sample.sample_buffer.has_sample_data then
      return false
    end
  end
  
  return true
end

--------------------------------------------------------------------------------
-- OS-specific configuration and setup
--------------------------------------------------------------------------------
local function setup_os_specific_paths()
  local os_name = os.platform()
  local rex_decoder_path
  local sdk_path
  local setup_success = true
  
  if os_name == "MACINTOSH" then
    -- macOS specific paths and setup
    local bundle_path = renoise.tool().bundle_path .. "rx2/REX Shared Library.bundle"
    rex_decoder_path = renoise.tool().bundle_path .. "rx2/rex2decoder_mac"
    sdk_path = preferences.pakettiREXBundlePath.value
    
    print("Bundle path: " .. bundle_path)
    
    -- Remove quarantine attribute from bundle
    local xattr_cmd = string.format('xattr -dr com.apple.quarantine "%s"', bundle_path)
    local xattr_result = os.execute(xattr_cmd)
    if xattr_result ~= 0 then
      print("Failed to remove quarantine attribute from bundle")
      setup_success = false
    end
    
    -- Check and set executable permissions
    local check_cmd = string.format('test -x "%s"', rex_decoder_path)
    local check_result = os.execute(check_cmd)
    
    if check_result ~= 0 then
      print("rex2decoder_mac is not executable. Setting +x permission.")
      local chmod_cmd = string.format('chmod +x "%s"', rex_decoder_path)
      local chmod_result = os.execute(chmod_cmd)
      if chmod_result ~= 0 then
        print("Failed to set executable permission on rex2decoder_mac")
        setup_success = false
      end
    end
  elseif os_name == "WINDOWS" then
    -- Windows specific paths and setup
    rex_decoder_path = renoise.tool().bundle_path .. "rx2" .. separator .. separator .. "rex2decoder_win.exe"
    sdk_path = renoise.tool().bundle_path .. "rx2" .. separator .. separator
  elseif os_name == "LINUX" then
    rex_decoder_path = renoise.tool().bundle_path .. "rx2" .. separator .. separator .. "rex2decoder_win.exe"
    sdk_path = renoise.tool().bundle_path .. "rx2" .. separator .. separator
    renoise.app():show_status("Hi, Linux user, remember to have WINE installed.")
  end
  
  return setup_success, rex_decoder_path, sdk_path
end

--------------------------------------------------------------------------------
-- Main RX2 import function using the external decoder
--------------------------------------------------------------------------------
function rx2_loadsample(filename)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  if not filename then
    renoise.app():show_error("RX2 Import Error: No filename provided!")
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return false
  end

  -- Set up OS-specific paths and requirements
  local setup_success, rex_decoder_path, sdk_path = setup_os_specific_paths()
  if not setup_success then
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return false
  end

  print("Starting RX2 import for file:", filename)
  
  -- Clean up any empty samples in ALL instruments before creating a new one
  local song = renoise.song()
  for inst_idx = 1, #song.instruments do
    local instrument = song.instruments[inst_idx]
    local samples_to_remove = {}
    
    -- Only clean up if the instrument doesn't have sliced samples
    local has_sliced_samples = false
    for i = 1, #instrument.samples do
      if #instrument.samples[i].slice_markers > 0 then
        has_sliced_samples = true
        break
      end
    end
    
    if not has_sliced_samples then
      for i = 1, #instrument.samples do
        local sample = instrument.samples[i]
        if not sample.sample_buffer.has_sample_data then
          table.insert(samples_to_remove, i)
          print("Found empty sample '" .. sample.name .. "' in instrument " .. inst_idx .. " at sample index " .. i .. " - marking for removal")
        end
      end
      
      -- Remove empty samples from highest index to lowest to avoid index shifting
      for i = #samples_to_remove, 1, -1 do
        local sample_index = samples_to_remove[i]
        print("Removing empty sample from instrument " .. inst_idx .. " at sample index " .. sample_index)
        instrument:delete_sample_at(sample_index)
      end
    else
      print("Skipping cleanup for instrument " .. inst_idx .. " - has sliced samples")
    end
  end
  
  -- Check if we're on instrument 00 (index 1) and if it's empty
  local current_index = renoise.song().selected_instrument_index
  local current_instrument = renoise.song().selected_instrument
  local use_existing_instrument = false
  
  if current_index == 1 and is_instrument_empty(current_instrument) then
    print("Using existing empty instrument 00 instead of creating new instrument")
    use_existing_instrument = true
  else
    -- Create a new instrument as before
    renoise.song():insert_instrument_at(current_index + 1)
    renoise.song().selected_instrument_index = current_index + 1
    print("Inserted new instrument at index:", renoise.song().selected_instrument_index)
  end

  -- Inject the default Paketti instrument configuration if available
  if pakettiPreferencesDefaultInstrumentLoader then
    if not use_existing_instrument then
      pakettiPreferencesDefaultInstrumentLoader()
      print("Injected Paketti default instrument configuration for new instrument")
    else
      pakettiPreferencesDefaultInstrumentLoader()
      print("Injected Paketti default instrument configuration for existing instrument 00")
    end
  else
    print("pakettiPreferencesDefaultInstrumentLoader not found – skipping default configuration")
  end

  local song=renoise.song()
  local instrument = song.selected_instrument
  
  -- Ensure there's at least one sample in the instrument (only if default loader wasn't available)
  if #instrument.samples == 0 then
    if not pakettiPreferencesDefaultInstrumentLoader then
      print("No default instrument loader and no samples - creating first sample")
      instrument:insert_sample_at(1)
    else
      print("Warning: Default instrument loader ran but instrument still has no samples!")
      instrument:insert_sample_at(1)
    end
  end
  
  -- Ensure we're working with the first sample slot and clear any empty samples
  song.selected_sample_index = 1
  local smp = song.selected_sample
  
  -- Remove any additional empty sample slots that might have been created
  while #instrument.samples > 1 do
    if not instrument.samples[#instrument.samples].sample_buffer.has_sample_data then
      instrument:delete_sample_at(#instrument.samples)
      print("Removed empty sample slot")
    else
      break
    end
  end
  
  -- Use the filename (minus the .rx2 extension) to create instrument name
  local rx2_filename_clean = filename:match("[^/\\]+$") or "RX2 Sample"
  local instrument_name = rx2_filename_clean:gsub("%.rx2$", "")
  local rx2_basename = filename:match("([^/\\]+)$") or "RX2 Sample"
  renoise.song().selected_instrument.name = rx2_basename
  renoise.song().selected_sample.name = rx2_basename
 
  -- Define paths for the output WAV file and the slice marker text file
  local TEMP_FOLDER = "/tmp"
  local os_name = os.platform()
  if os_name == "MACINTOSH" then
    TEMP_FOLDER = os.getenv("TMPDIR")
  elseif os_name == "WINDOWS" then
    TEMP_FOLDER = os.getenv("TEMP")
  end


-- Create unique temp file names to avoid conflicts between multiple imports
local timestamp = tostring(os.time())
local wav_output = TEMP_FOLDER .. separator .. instrument_name .. "_" .. timestamp .. ".wav"
local txt_output = TEMP_FOLDER .. separator .. instrument_name .. "_" .. timestamp .. "_slices.txt"

print (wav_output)
print (txt_output)

-- Build and run the command to execute the external decoder
local cmd
if os_name == "LINUX" then
  cmd = string.format("wine %q %q %q %q %q 2>&1", 
    rex_decoder_path,  -- decoder executable
    filename,          -- input file
    wav_output,        -- output WAV file
    txt_output,        -- output TXT file
    sdk_path           -- SDK directory
  )
else
  cmd = string.format("%s %q %q %q %q 2>&1", 
    rex_decoder_path,  -- decoder executable
    filename,          -- input file
    wav_output,        -- output WAV file
    txt_output,        -- output TXT file
    sdk_path           -- SDK directory
  )
end

print("----- Running External Decoder Command -----")
print(cmd)

print("Running external decoder command:", cmd)
local result = os.execute(cmd)

-- Instead of immediately checking for nonzero result, verify output files exist
local function file_exists(name)
  local f = io.open(name, "rb")
  if f then f:close() end
  return f ~= nil
end

if (result ~= 0) then
  -- Check if both output files exist
  if file_exists(wav_output) and file_exists(txt_output) then
    print("Warning: Nonzero exit code (" .. tostring(result) .. ") but output files found.")
    renoise.app():show_status("Decoder returned exit code " .. tostring(result) .. "; using generated files.")
  else
    print("Decoder returned error code", result)
    renoise.app():show_status("External decoder failed with error code " .. tostring(result))
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return false
  end
end

  -- Load the WAV file produced by the external decoder
  print("Loading WAV file from external decoder:", wav_output)
  
  -- Ensure we're still working with the correct instrument and sample
  local target_instrument_index = renoise.song().selected_instrument_index
  local target_sample_index = renoise.song().selected_sample_index
  
  local load_success = pcall(function()
    smp.sample_buffer:load_from(wav_output)
  end)
  if not load_success then
    print("Failed to load WAV file:", wav_output)
    renoise.app():show_status("RX2 Import Error: Failed to load decoded sample.")
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return false
  end
  
  -- Verify we're still on the correct instrument/sample after loading
  if renoise.song().selected_instrument_index ~= target_instrument_index then
    print("Warning: Instrument selection changed during import, restoring...")
    renoise.song().selected_instrument_index = target_instrument_index
    renoise.song().selected_sample_index = target_sample_index
    smp = renoise.song().selected_sample
  end
  
  if not smp.sample_buffer.has_sample_data then
    print("Loaded WAV file has no sample data")
    renoise.app():show_status("RX2 Import Error: No audio data in decoded sample.")
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return false
  end
  print("Sample loaded successfully from external decoder")

  -- Ensure we're still on the correct instrument before loading slice markers
  renoise.song().selected_instrument_index = target_instrument_index
  renoise.song().selected_sample_index = target_sample_index
  
  -- Read the slice marker text file and insert the markers
  local success, marker_count, was_truncated = load_slice_markers(txt_output)
  if success then
    print("Slice markers loaded successfully from file:", txt_output)
  else
    print("Warning: Could not load slice markers from file:", txt_output)
  end
  
  -- Aggressive cleanup after slice loading - remove ALL empty "Sample 01" entries
  local current_instrument = renoise.song().selected_instrument
  print("Post-slice cleanup - instrument has " .. #current_instrument.samples .. " samples")
  
  local removed_count = 0
  local i = 1
  while i <= #current_instrument.samples do
    local sample = current_instrument.samples[i]
    print("Checking sample " .. i .. ": name='" .. sample.name .. "', has_data=" .. tostring(sample.sample_buffer.has_sample_data))
    
    if not sample.sample_buffer.has_sample_data and sample.name == "Sample 01" then
      print("Removing empty 'Sample 01' at index " .. i)
      current_instrument:delete_sample_at(i)
      removed_count = removed_count + 1
      -- Don't increment i since we just removed a sample
    else
      i = i + 1
    end
  end
  
  print("Removed " .. removed_count .. " empty 'Sample 01' entries")

  -- Update instrument name to include slice count info if truncated
  if was_truncated then
    renoise.song().selected_instrument.name = rx2_basename .. " (256 slices imported)"
    renoise.song().selected_sample.name = rx2_basename .. " (256 slices imported)"
  end



  -- Set additional sample properties from preferences
  if preferences then
    smp.autofade = preferences.pakettiLoaderAutofade.value
    smp.autoseek = preferences.pakettiLoaderAutoseek.value
    smp.loop_mode = preferences.pakettiLoaderLoopMode.value
    smp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
    smp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    smp.oneshot = preferences.pakettiLoaderOneshot.value
    smp.new_note_action = preferences.pakettiLoaderNNA.value
    smp.loop_release = preferences.pakettiLoaderLoopExit.value
  end
  
  -- Apply Paketti loader settings to all slice samples
  if preferences and #smp.slice_markers > 0 then
    print("Applying Paketti loader settings to " .. #smp.slice_markers .. " slice samples")
    for i = 1, #smp.slice_markers do
      local slice_sample = current_instrument.samples[i + 1]
      if slice_sample then
        slice_sample.autofade = preferences.pakettiLoaderAutofade.value
        slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
        slice_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
        slice_sample.new_note_action = preferences.pakettiLoaderNNA.value
        slice_sample.loop_release = preferences.pakettiLoaderLoopExit.value
        print("Applied Paketti loader settings to slice sample " .. (i + 1))
      end
    end
  end
  


  -- Clean up temporary files to avoid conflicts with subsequent imports
  pcall(function() os.remove(wav_output) end)
  pcall(function() os.remove(txt_output) end)
  
  renoise.app():show_status("RX2 imported successfully with slice markers")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  return true
end

--------------------------------------------------------------------------------
-- Register the file import hook for RX2 files
--------------------------------------------------------------------------------
-- NOTE: File import hook registration moved to PakettiImport.lua for centralized management

--------------------------------------------------------------------------------
-- Batch RX2 to OT Converter
-- Converts a folder of RX2 files to Octatrack-compatible WAV + .ot files
--------------------------------------------------------------------------------

-- Helper function to get RX2 files from a directory
local function getRX2Files(dir)
  local files = {}
  local command
  
  -- Use OS-specific commands to list files
  if package.config:sub(1,1) == "\\" then  -- Windows
    command = string.format('dir "%s" /b /s', dir:gsub('"', '\\"'))
  else  -- macOS and Linux
    command = string.format("find '%s' -type f -name '*.rx2' -o -name '*.RX2'", dir:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      local lower_path = line:lower()
      if lower_path:match("%.rx2$") then
        table.insert(files, line)
      end
    end
    handle:close()
  end
  
  -- Sort files alphabetically for consistent processing order
  table.sort(files)
  
  return files
end

-- Helper function to read WAV file header information
local function readWavHeader(wav_path)
  local file = io.open(wav_path, "rb")
  if not file then
    return nil, "Could not open WAV file"
  end
  
  -- Read RIFF header
  local riff = file:read(4)
  if riff ~= "RIFF" then
    file:close()
    return nil, "Not a valid RIFF file"
  end
  
  -- Skip file size
  file:read(4)
  
  -- Read WAVE marker
  local wave = file:read(4)
  if wave ~= "WAVE" then
    file:close()
    return nil, "Not a valid WAVE file"
  end
  
  local sample_rate = 44100
  local num_channels = 1
  local bits_per_sample = 16
  local num_frames = 0
  
  -- Read chunks until we find fmt and data
  while true do
    local chunk_id = file:read(4)
    if not chunk_id then break end
    
    -- Read chunk size (little-endian 32-bit)
    local b1, b2, b3, b4 = string.byte(file:read(4), 1, 4)
    if not b1 then break end
    local chunk_size = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    
    if chunk_id == "fmt " then
      -- Read format chunk
      local fmt_data = file:read(chunk_size)
      if fmt_data and #fmt_data >= 16 then
        local f1, f2 = string.byte(fmt_data, 1, 2)
        local audio_format = f1 + f2 * 256
        
        local c1, c2 = string.byte(fmt_data, 3, 4)
        num_channels = c1 + c2 * 256
        
        local s1, s2, s3, s4 = string.byte(fmt_data, 5, 8)
        sample_rate = s1 + s2 * 256 + s3 * 65536 + s4 * 16777216
        
        local bp1, bp2 = string.byte(fmt_data, 15, 16)
        bits_per_sample = bp1 + bp2 * 256
      end
    elseif chunk_id == "data" then
      -- Calculate number of frames from data chunk size
      local bytes_per_sample = bits_per_sample / 8
      num_frames = math.floor(chunk_size / (num_channels * bytes_per_sample))
      break
    else
      -- Skip unknown chunk
      file:seek("cur", chunk_size)
    end
  end
  
  file:close()
  
  return {
    sample_rate = sample_rate,
    num_channels = num_channels,
    bits_per_sample = bits_per_sample,
    num_frames = num_frames
  }
end

-- Helper function to parse slice markers from the decoder's TXT output
local function parseSliceMarkers(txt_path)
  local file = io.open(txt_path, "r")
  if not file then
    return {}
  end
  
  local markers = {}
  for line in file:lines() do
    -- Extract the number between parentheses, e.g. "insert_slice_marker(12345)"
    local marker = tonumber(line:match("%((%d+)%)"))
    if marker then
      table.insert(markers, marker)
    end
  end
  
  file:close()
  return markers
end

-- Create OT table from WAV info and slice markers (standalone, doesn't require Renoise sample)
local function makeOTTableFromData(wav_info, slice_markers, bpm)
  -- OT file header and unknown bytes (same as in PakettiOTExport.lua)
  local header = { 
    0x46, 0x4F, 0x52, 0x4D, 
    0x00, 0x00, 0x00, 0x00, 
    0x44, 0x50, 0x53, 0x31, 
    0x53, 0x4D, 0x50, 0x41 
  }
  
  local unknown = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00 }
  
  local sample_len = wav_info.num_frames
  local sample_rate = wav_info.sample_rate
  local slice_count = #slice_markers
  
  -- Calculate tempo and length values using OctaChainer's bar-based formula
  local tempo_value = math.floor(bpm * 24)
  local bars = math.floor(((bpm * sample_len) / (sample_rate * 60.0 * 4)) + 0.5)
  local trim_loop_value = bars * 25
  local loop_len_value = trim_loop_value
  local stretch_value = 0  -- Off
  local loop_value = 0     -- Off
  local gain_value = 48    -- 0dB
  local trim_end_value = sample_len
  
  -- Limit slice count to 64 (Octatrack maximum)
  local export_slice_count = math.min(slice_count, 64)
  
  print(string.format("RX2->OT: sample_len=%d, sample_rate=%d, slices=%d (exporting %d)", 
    sample_len, sample_rate, slice_count, export_slice_count))
  
  local ot = {}
  
  -- Insert header and unknown
  for k, v in ipairs(header) do
    table.insert(ot, v)
  end
  for k, v in ipairs(unknown) do
    table.insert(ot, v)
  end
  
  -- tempo (32)
  table.insert(ot, tempo_value)
  -- trim_len (32)
  table.insert(ot, trim_loop_value)
  -- loop_len (32)
  table.insert(ot, loop_len_value)
  -- stretch (32)
  table.insert(ot, stretch_value)
  -- loop (32)
  table.insert(ot, loop_value)
  -- gain (16)
  table.insert(ot, gain_value)
  -- quantize (8)
  table.insert(ot, 0xFF)
  -- trim_start (32)
  table.insert(ot, 0x00)
  -- trim_end (32)
  table.insert(ot, trim_end_value)
  -- loop_point (32)
  table.insert(ot, 0x00)
  
  -- Process slices
  for k = 1, export_slice_count do
    local v = slice_markers[k]
    
    -- Convert from 1-based (Renoise) to 0-based (Octatrack) indexing
    -- First slice must start at frame 0 for Octatrack
    local s_start = (k == 1) and 0 or (v - 1)
    
    -- Calculate slice end
    local s_end
    if k < export_slice_count then
      s_end = slice_markers[k + 1] - 2  -- next start - 1, converted to 0-based
    else
      s_end = sample_len - 1  -- last slice ends at sample end - 1
    end
    
    -- Ensure slice end is within sample bounds
    s_end = math.max(s_start, math.min(s_end, sample_len - 1))
    
    -- start_point (32)
    table.insert(ot, s_start)
    -- end_point (32)
    table.insert(ot, s_end)
    -- loop_point (32)
    table.insert(ot, 0xFFFFFFFF)
  end
  
  -- slice_count (32)
  table.insert(ot, export_slice_count)
  
  return ot
end

-- Write OT file (standalone version, same format as PakettiOTExport.lua)
local function writeOTFileStandalone(ot_filename, ot)
  -- Build complete byte array first (832 bytes exactly)
  local byte_array = {}
  
  -- Helper function to append bytes from integer (big-endian)
  local function append_be32(value)
    local b4 = value % 256
    value = math.floor(value / 256)
    local b3 = value % 256
    value = math.floor(value / 256)
    local b2 = value % 256
    value = math.floor(value / 256)
    local b1 = value % 256
    table.insert(byte_array, b1)  -- MSB first
    table.insert(byte_array, b2)
    table.insert(byte_array, b3)
    table.insert(byte_array, b4)  -- LSB last
  end
  
  local function append_be16(value)
    local b2 = value % 256
    value = math.floor(value / 256)
    local b1 = value % 256
    table.insert(byte_array, b1)  -- MSB first
    table.insert(byte_array, b2)  -- LSB last
  end
  
  local function append_byte(value)
    table.insert(byte_array, value)
  end
  
  -- Write header and unknown (bytes 1-23, single bytes)
  for i = 1, 23 do
    append_byte(ot[i])
  end
  
  -- Write main data section
  append_be32(ot[24])  -- tempo
  append_be32(ot[25])  -- trim_len
  append_be32(ot[26])  -- loop_len
  append_be32(ot[27])  -- stretch
  append_be32(ot[28])  -- loop
  append_be16(ot[29])  -- gain
  append_byte(ot[30])  -- quantize
  append_be32(ot[31])  -- trim_start
  append_be32(ot[32])  -- trim_end
  append_be32(ot[33])  -- loop_point
  
  -- Write actual slice data
  local slice_data_start = 34
  local actual_slice_count = ot[#ot]
  local slice_fields_written = 0
  
  -- Write actual slices
  for i = slice_data_start, #ot - 1 do
    append_be32(ot[i])
    slice_fields_written = slice_fields_written + 1
  end
  
  -- Pad remaining slice slots with zeros (up to 64 slices total)
  local max_slice_fields = 64 * 3  -- 64 slices × 3 fields each
  for i = slice_fields_written + 1, max_slice_fields do
    append_be32(0)
  end
  
  -- Write slice_count
  append_be32(actual_slice_count)
  
  -- Calculate checksum using OctaChainer method: sum bytes 16 to 829
  local checksum = 0
  for i = 17, 830 do
    if byte_array[i] then
      checksum = checksum + byte_array[i]
      if checksum > 0xFFFF then
        checksum = checksum % 0x10000  -- 16-bit wrap
      end
    end
  end
  
  -- Append checksum (16-bit big-endian)
  append_be16(checksum)
  
  -- Ensure exactly 832 bytes
  while #byte_array < 832 do
    append_byte(0)
  end
  
  -- Write to file
  local f = io.open(ot_filename, "wb")
  if not f then
    return false, "Could not create OT file: " .. ot_filename
  end
  
  for i = 1, 832 do
    f:write(string.char(byte_array[i] or 0))
  end
  f:close()
  
  print("RX2->OT: Written .ot file: " .. ot_filename)
  return true
end

-- Copy a file from source to destination
local function copyFile(src, dst)
  local src_file = io.open(src, "rb")
  if not src_file then
    return false, "Could not open source file"
  end
  
  local content = src_file:read("*all")
  src_file:close()
  
  local dst_file = io.open(dst, "wb")
  if not dst_file then
    return false, "Could not create destination file"
  end
  
  dst_file:write(content)
  dst_file:close()
  
  return true
end

--------------------------------------------------------------------------------
-- Main Batch RX2 to OT Conversion Function
--------------------------------------------------------------------------------
function PakettiBatchRX2ToOT()
  print("=== Batch RX2 to OT Converter ===")
  
  -- Prompt for input folder containing RX2 files
  local input_folder = renoise.app():prompt_for_path("Select Folder Containing RX2 Files")
  if not input_folder or input_folder == "" then
    renoise.app():show_status("Batch RX2->OT: Cancelled - no input folder selected")
    return
  end
  
  print("Input folder: " .. input_folder)
  
  -- Get list of RX2 files
  local rx2_files = getRX2Files(input_folder)
  
  if #rx2_files == 0 then
    renoise.app():show_error("No RX2 files found in the selected folder.")
    return
  end
  
  print("Found " .. #rx2_files .. " RX2 files")
  
  -- Prompt for output folder
  local output_folder = renoise.app():prompt_for_path("Select Output Folder for WAV+OT Files")
  if not output_folder or output_folder == "" then
    renoise.app():show_status("Batch RX2->OT: Cancelled - no output folder selected")
    return
  end
  
  print("Output folder: " .. output_folder)
  
  -- Get current BPM for OT tempo calculation
  local bpm = renoise.song().transport.bpm
  
  -- Set up OS-specific paths and requirements
  local setup_success, rex_decoder_path, sdk_path = setup_os_specific_paths()
  if not setup_success then
    renoise.app():show_error("Failed to set up RX2 decoder. Check console for details.")
    return
  end
  
  -- Get temp folder
  local TEMP_FOLDER = "/tmp"
  local os_name = os.platform()
  if os_name == "MACINTOSH" then
    TEMP_FOLDER = os.getenv("TMPDIR")
  elseif os_name == "WINDOWS" then
    TEMP_FOLDER = os.getenv("TEMP")
  end
  
  -- Process each RX2 file
  local success_count = 0
  local fail_count = 0
  local skipped_count = 0
  
  for i, rx2_path in ipairs(rx2_files) do
    -- Extract filename without path and extension
    local rx2_filename = rx2_path:match("[^/\\]+$") or "unknown"
    local base_name = rx2_filename:gsub("%.rx2$", ""):gsub("%.RX2$", "")
    
    print(string.format("\n--- Processing %d/%d: %s ---", i, #rx2_files, rx2_filename))
    renoise.app():show_status(string.format("Batch RX2->OT: Processing %d/%d: %s", i, #rx2_files, rx2_filename))
    
    -- Create unique temp file names
    local timestamp = tostring(os.time()) .. "_" .. tostring(i)
    local temp_wav = TEMP_FOLDER .. separator .. base_name .. "_" .. timestamp .. ".wav"
    local temp_txt = TEMP_FOLDER .. separator .. base_name .. "_" .. timestamp .. "_slices.txt"
    
    -- Build and run the decoder command
    local cmd
    if os_name == "LINUX" then
      cmd = string.format("wine %q %q %q %q %q 2>&1", 
        rex_decoder_path, rx2_path, temp_wav, temp_txt, sdk_path)
    else
      cmd = string.format("%s %q %q %q %q 2>&1", 
        rex_decoder_path, rx2_path, temp_wav, temp_txt, sdk_path)
    end
    
    print("Running decoder: " .. cmd)
    local result = os.execute(cmd)
    
    -- Check if output files exist
    local wav_file = io.open(temp_wav, "rb")
    local txt_file = io.open(temp_txt, "r")
    
    if not wav_file then
      print("ERROR: Decoder failed to create WAV file for: " .. rx2_filename)
      fail_count = fail_count + 1
      if txt_file then txt_file:close() end
      -- Cleanup temp files
      pcall(function() os.remove(temp_wav) end)
      pcall(function() os.remove(temp_txt) end)
    else
      wav_file:close()
      if txt_file then txt_file:close() end
      
      -- Read WAV header info
      local wav_info = readWavHeader(temp_wav)
      if not wav_info or wav_info.num_frames == 0 then
        print("ERROR: Could not read WAV info for: " .. rx2_filename)
        fail_count = fail_count + 1
        pcall(function() os.remove(temp_wav) end)
        pcall(function() os.remove(temp_txt) end)
      else
        -- Parse slice markers
        local slice_markers = parseSliceMarkers(temp_txt)
        print(string.format("WAV: %d frames, %dHz, %d slices", 
          wav_info.num_frames, wav_info.sample_rate, #slice_markers))
        
        -- Create OT table
        local ot = makeOTTableFromData(wav_info, slice_markers, bpm)
        
        -- Determine output paths
        local output_wav = output_folder .. separator .. base_name .. ".wav"
        local output_ot = output_folder .. separator .. base_name .. ".ot"
        
        -- Copy WAV to output folder
        local copy_ok, copy_err = copyFile(temp_wav, output_wav)
        if not copy_ok then
          print("ERROR: Could not copy WAV to output: " .. tostring(copy_err))
          fail_count = fail_count + 1
        else
          -- Write OT file
          local ot_ok, ot_err = writeOTFileStandalone(output_ot, ot)
          if not ot_ok then
            print("ERROR: Could not write OT file: " .. tostring(ot_err))
            fail_count = fail_count + 1
          else
            print("SUCCESS: Created " .. base_name .. ".wav + .ot")
            success_count = success_count + 1
          end
        end
        
        -- Cleanup temp files
        pcall(function() os.remove(temp_wav) end)
        pcall(function() os.remove(temp_txt) end)
      end
    end
  end
  
  -- Show final status
  local status_msg = string.format("Batch RX2->OT Complete: %d succeeded, %d failed out of %d files", 
    success_count, fail_count, #rx2_files)
  print("\n=== " .. status_msg .. " ===")
  renoise.app():show_status(status_msg)
  
  if fail_count > 0 then
    renoise.app():show_warning(string.format(
      "Batch RX2 to OT conversion completed.\n\n" ..
      "Successfully converted: %d files\n" ..
      "Failed: %d files\n\n" ..
      "Check the scripting console for details.",
      success_count, fail_count))
  else
    renoise.app():show_message(string.format(
      "Batch RX2 to OT conversion completed successfully!\n\n" ..
      "Converted %d RX2 files to WAV+OT format.\n\n" ..
      "Output folder: %s",
      success_count, output_folder))
  end
end

--------------------------------------------------------------------------------
-- Keybindings for Batch RX2 to OT (Menu entries in PakettiMenuConfig.lua)
--------------------------------------------------------------------------------
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Batch Convert RX2 to OT (WAV+.ot)...",invoke=PakettiBatchRX2ToOT}
renoise.tool():add_keybinding{name="Global:Paketti:Batch Convert RX2 to Octatrack (WAV+.ot)",invoke=PakettiBatchRX2ToOT}
