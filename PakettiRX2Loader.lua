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
  
  for line in file:lines() do
    -- Extract the number between parentheses, e.g. "insert_slice_marker(12345)"
    local marker = tonumber(line:match("%((%d+)%)"))
    if marker then
      renoise.song().selected_sample:insert_slice_marker(marker)
      print("Inserted slice marker at position", marker)
    else
      print("Warning: Could not parse marker from line:", line)
    end
  end
  
  file:close()
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
  if not filename then
    renoise.app():show_error("RX2 Import Error: No filename provided!")
    return false
  end

  -- Set up OS-specific paths and requirements
  local setup_success, rex_decoder_path, sdk_path = setup_os_specific_paths()
  if not setup_success then
    return false
  end

  print("Starting RX2 import for file:", filename)
  
  -- Do NOT overwrite an existing instrument:
  local current_index = renoise.song().selected_instrument_index
  renoise.song():insert_instrument_at(current_index + 1)
  renoise.song().selected_instrument_index = current_index + 1
  print("Inserted new instrument at index:", renoise.song().selected_instrument_index)

  -- Inject the default Paketti instrument configuration if available
  if pakettiPreferencesDefaultInstrumentLoader then
    pakettiPreferencesDefaultInstrumentLoader()
    print("Injected Paketti default instrument configuration")
  else
    print("pakettiPreferencesDefaultInstrumentLoader not found – skipping default configuration")
  end

  local song = renoise.song()
  local smp = song.selected_sample
  
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


  local wav_output = TEMP_FOLDER .. separator .. instrument_name .. "_output.wav"
  local txt_output = TEMP_FOLDER .. separator .. instrument_name .. "_slices.txt"

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
    return false
  end
end

  -- Load the WAV file produced by the external decoder
  print("Loading WAV file from external decoder:", wav_output)
  local load_success = pcall(function()
    smp.sample_buffer:load_from(wav_output)
  end)
  if not load_success then
    print("Failed to load WAV file:", wav_output)
    renoise.app():show_status("RX2 Import Error: Failed to load decoded sample.")
    return false
  end
  if not smp.sample_buffer.has_sample_data then
    print("Loaded WAV file has no sample data")
    renoise.app():show_status("RX2 Import Error: No audio data in decoded sample.")
    return false
  end
  print("Sample loaded successfully from external decoder")

  -- Read the slice marker text file and insert the markers
  local success = load_slice_markers(txt_output)
  if success then
    print("Slice markers loaded successfully from file:", txt_output)
  else
    print("Warning: Could not load slice markers from file:", txt_output)
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
  
  renoise.app():show_status("RX2 imported successfully with slice markers")
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