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
local rx2_integration = {
  category = "sample",
  extensions = { "rx2" },
  invoke = rx2_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "rx2" }) then
  renoise.tool():add_file_import_hook(rx2_integration)
end


  