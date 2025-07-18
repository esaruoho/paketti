


-- PakettiPolyendSuite.lua
-- RX2 to PTI Conversion Tool
-- Combines RX2 loading with PTI export functionality

local bit = require("bit")
local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

-- Standardized error messages
local POLYEND_DEVICE_NOT_CONNECTED_MSG = "Connect the Polyend device, set to USB Storage Mode and press Refresh."
local POLYEND_SAVE_PATH_ERROR_MSG = "If saving to Polyend device:\n• Connect your Polyend device\n• Set to USB Storage Mode\n• Press Refresh to reconnect"
local POLYEND_DEVICE_NOT_CONNECTED_TITLE = "Polyend device not connected!"

-- Dialog reference and variables for Polyend Buddy (to be refactored to use preferences directly)
local dialog = nil
local polyend_buddy_root_path = ""
local polyend_buddy_pti_files = {}
local polyend_buddy_wav_files = {}
local polyend_buddy_folders = {}
local computer_pti_path = ""
local computer_pti_files = {}
local computer_backup_files = {}

-- Global refresh function for operations outside dialog context
local polyend_refresh_callback = nil

-- UI visibility state tracking
local save_paths_section_visible = false
local backup_section_visible = false

-- Helper function to get current Polyend root path from preferences
local function get_polyend_root_path()
  if preferences and preferences.PolyendRoot and preferences.PolyendRoot.value then
    return preferences.PolyendRoot.value
  end
  return ""
end

-- Helper function to get current local PTI path from preferences  
local function get_computer_pti_path()
  if preferences and preferences.PolyendLocalPath and preferences.PolyendLocalPath.value then
    return preferences.PolyendLocalPath.value
  end
  return ""
end

-- Helper function to get PTI save path from preferences
local function get_pti_save_path()
  if preferences and preferences.PolyendPTISavePath and preferences.PolyendPTISavePath.value then
    return preferences.PolyendPTISavePath.value
  end
  return ""
end

-- Helper function to get WAV save path from preferences
local function get_wav_save_path()
  if preferences and preferences.PolyendWAVSavePath and preferences.PolyendWAVSavePath.value then
    return preferences.PolyendWAVSavePath.value
  end
  return ""
end

-- Helper function to check if use save paths is enabled
local function get_use_save_paths()
  if preferences and preferences.PolyendUseSavePaths and preferences.PolyendUseSavePaths.value then
    return preferences.PolyendUseSavePaths.value
  end
  return false
end

-- Helper function to get local backup path from preferences
local function get_computer_backup_path()
  if preferences and preferences.PolyendLocalBackupPath and preferences.PolyendLocalBackupPath.value then
    return preferences.PolyendLocalBackupPath.value
  end
  return ""
end

-- Helper function to check if use local backup is enabled
local function get_use_computer_backup()
  if preferences and preferences.PolyendUseLocalBackup and preferences.PolyendUseLocalBackup.value then
    return preferences.PolyendUseLocalBackup.value
  end
  return false
end

-- Helper function to generate unique filename when file already exists
local function generate_unique_filename(base_path)
  local file_exists = io.open(base_path, "rb")
  if not file_exists then
    return base_path -- File doesn't exist, use original name
  end
  file_exists:close()
  
  -- Extract directory, base name, and extension
  local separator = package.config:sub(1,1)
  local dir = base_path:match("(.+)[/\\][^/\\]*$") or ""
  local filename_with_ext = base_path:match("[^/\\]+$") or base_path
  local base_name = filename_with_ext:match("(.+)%.[^%.]+$") or filename_with_ext
  local extension = filename_with_ext:match("%.([^%.]+)$") or ""
  
  -- Add separator if directory exists
  if dir ~= "" then
    dir = dir .. separator
  end
  
  -- Try numbered versions
  local counter = 1
  while counter <= 999 do -- Reasonable limit
    local numbered_name = string.format("%s_%03d", base_name, counter)
    local new_path = dir .. numbered_name .. (extension ~= "" and ("." .. extension) or "")
    
    local test_file = io.open(new_path, "rb")
    if not test_file then
      return new_path -- This filename is available
    end
    test_file:close()
    counter = counter + 1
  end
  
  -- If we get here, we couldn't find a unique name
  return base_path -- Return original and let it overwrite
end

-- Helper function to auto-save drumkit using save paths
local function auto_save_drumkit_if_enabled(drumkit_type, vb)
  if get_use_save_paths() and get_pti_save_path() ~= "" then
    local pti_save_path = get_pti_save_path()
    local path_exists = check_polyend_path_exists(pti_save_path)
    if path_exists then
      local song = renoise.song()
      local instrument_name = song.selected_instrument.name or ("Drumkit_" .. drumkit_type)
      local safe_name = instrument_name:gsub("[^%w%-%_]", "_")
      local separator = package.config:sub(1,1)
      local full_path = pti_save_path .. separator .. safe_name .. ".pti"
      
      -- Generate unique filename if file already exists
      local unique_path = generate_unique_filename(full_path)
      local final_filename = unique_path:match("[^/\\]+$") or "drumkit.pti"
      
      if pti_savesample_to_path then
        local success = pti_savesample_to_path(unique_path)
        if success then
          -- Create local backup copy if enabled
          if create_local_backup_copy then
            create_local_backup_copy(unique_path, "Drumkit_" .. drumkit_type)
          end
          
          -- Refresh the dropdowns to show the new file
          if vb then
            update_pti_dropdown(vb)
            update_computer_backup_dropdown(vb)
          end
          
          renoise.app():show_status(string.format("%s drumkit saved to %s", drumkit_type, unique_path))
          
          return true
        else
          renoise.app():show_error("Failed to auto-save drumkit PTI file")
          return false
        end
      else
        renoise.app():show_status("pti_savesample_to_path not available - drumkit created but not auto-saved")
        return false
      end
    else
      renoise.app():show_error("PTI save path not accessible:\n" .. pti_save_path)
      return false
    end
  end
  return false -- Save paths not enabled or not configured
end

-- Helper function to create local backup copy when enabled
local function create_local_backup_copy(source_file_path, operation_name)
  if not get_use_computer_backup() then
    return false -- Local backup not enabled
  end
  
  local backup_path = get_computer_backup_path()
  if not backup_path or backup_path == "" then
    print("-- Local Backup: No backup path configured - skipping backup copy")
    return false
  end
  
  -- Check if backup path is accessible
  local path_exists = check_polyend_path_exists(backup_path)
  if not path_exists then
    print("-- Local Backup: Backup path not accessible - skipping backup copy: " .. backup_path)
    return false
  end
  
  -- Extract filename from source path
  local filename = source_file_path:match("[^/\\]+$") or "backup_file"
  local separator = package.config:sub(1,1)
  
  -- Create timestamped backup filename to avoid conflicts
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local name_part = filename:match("(.+)%.[^%.]+$") or filename
  local ext_part = filename:match("%.([^%.]+)$") or ""
  local backup_filename = string.format("%s_%s_%s.%s", name_part, operation_name, timestamp, ext_part)
  
  local backup_file_path = backup_path .. separator .. backup_filename
  
  -- Copy the file to backup location
  local success, error_msg = pcall(function()
    -- Read source file
    local source_file = io.open(source_file_path, "rb")
    if not source_file then
      error("Cannot open source file: " .. source_file_path)
    end
    
    local file_data = source_file:read("*all")
    source_file:close()
    
    if not file_data or #file_data == 0 then
      error("Source file is empty or unreadable")
    end
    
    -- Write to backup location
    local backup_file = io.open(backup_file_path, "wb")
    if not backup_file then
      error("Cannot create backup file: " .. backup_file_path)
    end
    
    backup_file:write(file_data)
    backup_file:close()
    
    print(string.format("-- Local Backup: Created backup copy: %s (%d bytes)", backup_filename, #file_data))
  end)
  
  if success then
    renoise.app():show_status(string.format("Saved + Local backup: %s", backup_filename))
    return true
  else
    print("-- Local Backup: Failed to create backup copy: " .. (error_msg or "Unknown error"))
    return false
  end
end

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

function wav_loadsample(filename)
  local selected_sample_filenames
  
  -- Handle both single strings and tables
  if type(filename) == "string" then
    selected_sample_filenames = {filename}
  else
    selected_sample_filenames = filename
  end

print (selected_sample_filenames[1] or "No filename")

  if #selected_sample_filenames > 0 then
    rprint(selected_sample_filenames)
    for index, filename in ipairs(selected_sample_filenames) do
      local next_instrument = renoise.song().selected_instrument_index + 1
      renoise.song():insert_instrument_at(next_instrument)
      renoise.song().selected_instrument_index = next_instrument

      pakettiPreferencesDefaultInstrumentLoader()

      local selected_instrument = renoise.song().selected_instrument
      selected_instrument.name = "Pitchbend Instrument"
      selected_instrument.macros_visible = true
      selected_instrument.sample_modulation_sets[1].name = "Pitchbend"

      if #selected_instrument.samples == 0 then
        selected_instrument:insert_sample_at(1)
      end
      renoise.song().selected_sample_index = 1

      local filename_only = filename:match("^.+[/\\](.+)$")
      local instrument_slot_hex = string.format("%02X", next_instrument - 1)

      if selected_instrument.samples[1].sample_buffer:load_from(filename) then
        renoise.app():show_status("Sample " .. filename_only .. " loaded successfully.")
        local current_sample = selected_instrument.samples[1]
        current_sample.name = string.format("%s_%s", instrument_slot_hex, filename_only)
        selected_instrument.name = string.format("%s_%s", instrument_slot_hex, filename_only)

        current_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        current_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        current_sample.autofade = preferences.pakettiLoaderAutofade.value
        current_sample.autoseek = preferences.pakettiLoaderAutoseek.value
        current_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        current_sample.oneshot = preferences.pakettiLoaderOneshot.value
        current_sample.new_note_action = preferences.pakettiLoaderNNA.value
        current_sample.loop_release = preferences.pakettiLoaderLoopExit.value

        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
        G01()
--if normalize then normalize_selected_sample() end

if preferences.pakettiLoaderMoveSilenceToEnd.value ~= false then PakettiMoveSilence() end
if preferences.pakettiLoaderNormalizeSamples.value ~= false then normalize_selected_sample() end
if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
if renoise.song().selected_track.type == 2 then renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") return else
        loadnative("Audio/Effects/Native/*Instr. Macros") 
        local macro_device = renoise.song().selected_track:device(2)
        macro_device.display_name = string.format("%s_%s", instrument_slot_hex, filename_only)
        renoise.song().selected_track.devices[2].is_maximized = false
        end
      else
        renoise.app():show_status("Failed to load the sample " .. filename_only)
      end
    else end 
    end
  else
    renoise.app():show_status("No file selected.")
  end
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
-- PTI Export Helper Functions
--------------------------------------------------------------------------------

-- Helper writers
local function write_uint8(f, v)
  f:write(string.char(bit.band(v, 0xFF)))
end

local function write_uint16_le(f, v)
  f:write(string.char(
    bit.band(v, 0xFF),
    bit.band(bit.rshift(v, 8), 0xFF)
  ))
end

local function write_uint32_le(f, v)
  f:write(string.char(
    bit.band(v, 0xFF),
    bit.band(bit.rshift(v, 8), 0xFF),
    bit.band(bit.rshift(v, 16), 0xFF),
    bit.band(bit.rshift(v, 24), 0xFF)
  ))
end


-- Write PCM data mono or stereo
local function write_pcm(f, inst)
  local buf = inst.sample_buffer
  local channels = inst.channels or 1
  
  if channels == 2 then
    -- For stereo: write all left channel data first, then all right channel data
    -- This matches the format expected by the import function
    
    -- Write left channel block
    for i = 1, inst.sample_length do
      local v = buf:sample_data(1, i)
      -- Clamp the value between -1 and 1
      v = math.min(math.max(v, -1.0), 1.0)
      -- Convert to 16-bit integer range
      local int = math.floor(v * 32767)
      -- Handle negative values
      if int < 0 then int = int + 65536 end
      -- Write as 16-bit LE
      write_uint16_le(f, int)
    end
    
    -- Write right channel block  
    for i = 1, inst.sample_length do
      local v = buf:sample_data(2, i)
      -- Clamp the value between -1 and 1
      v = math.min(math.max(v, -1.0), 1.0)
      -- Convert to 16-bit integer range
      local int = math.floor(v * 32767)
      -- Handle negative values
      if int < 0 then int = int + 65536 end
      -- Write as 16-bit LE
      write_uint16_le(f, int)
    end
  else
    -- Mono: write samples sequentially
    for i = 1, inst.sample_length do
      local v = buf:sample_data(1, i)
      -- Clamp the value between -1 and 1
      v = math.min(math.max(v, -1.0), 1.0)
      -- Convert to 16-bit integer range
      local int = math.floor(v * 32767)
      -- Handle negative values
      if int < 0 then int = int + 65536 end
      -- Write as 16-bit LE
      write_uint16_le(f, int)
    end
  end
end

--------------------------------------------------------------------------------
-- RX2 to PTI Conversion Function
--------------------------------------------------------------------------------
function rx2_to_pti_convert()
  -- Step 1: Browse for RX2 file
  local rx2_filename = renoise.app():prompt_for_filename_to_read({"*.RX2"}, "Select RX2 file to convert to PTI")
  if not rx2_filename or rx2_filename == "" then
    return
  end

  print("------------")
  print("-- RX2 to PTI Conversion Started")
  print("-- Source RX2 file: " .. rx2_filename)

  -- Set up OS-specific paths and requirements
  local setup_success, rex_decoder_path, sdk_path = setup_os_specific_paths()
  if not setup_success then
    renoise.app():show_error("Failed to setup RX2 decoder paths")
    return
  end

  -- Do NOT overwrite an existing instrument:
  local current_index = renoise.song().selected_instrument_index
  renoise.song():insert_instrument_at(current_index + 1)
  renoise.song().selected_instrument_index = current_index + 1
  print("-- Inserted new instrument at index:", renoise.song().selected_instrument_index)

  -- Inject the default Paketti instrument configuration if available
  if pakettiPreferencesDefaultInstrumentLoader then
    pakettiPreferencesDefaultInstrumentLoader()
    print("-- Injected Paketti default instrument configuration")
  else
    print("-- pakettiPreferencesDefaultInstrumentLoader not found – skipping default configuration")
  end

  local song = renoise.song()
  local smp = song.selected_sample
  
  -- Use the filename (minus the .rx2 extension) to create instrument name
  local rx2_filename_clean = rx2_filename:match("[^/\\]+$") or "RX2 Sample"
  local instrument_name = rx2_filename_clean:gsub("%.rx2$", "")
  local rx2_basename = rx2_filename:match("([^/\\]+)$") or "RX2 Sample"
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

  print("-- WAV output: " .. wav_output)
  print("-- TXT output: " .. txt_output)

  -- Build and run the command to execute the external decoder
  local cmd
  if os_name == "LINUX" then
    cmd = string.format("wine %q %q %q %q %q 2>&1", 
      rex_decoder_path,  -- decoder executable
      rx2_filename,      -- input file
      wav_output,        -- output WAV file
      txt_output,        -- output TXT file
      sdk_path           -- SDK directory
    )
  else
    cmd = string.format("%s %q %q %q %q 2>&1", 
      rex_decoder_path,  -- decoder executable
      rx2_filename,      -- input file
      wav_output,        -- output WAV file
      txt_output,        -- output TXT file
      sdk_path           -- SDK directory
    )
  end

  print("-- Running External Decoder Command:")
  print("-- " .. cmd)

  local result = os.execute(cmd)

  -- Check if output files exist
  local function file_exists(name)
    local f = io.open(name, "rb")
    if f then f:close() end
    return f ~= nil
  end

  if (result ~= 0) then
    -- Check if both output files exist
    if file_exists(wav_output) and file_exists(txt_output) then
      print("-- Warning: Nonzero exit code (" .. tostring(result) .. ") but output files found.")
      renoise.app():show_status("Decoder returned exit code " .. tostring(result) .. "; using generated files.")
    else
      print("-- Decoder returned error code", result)
      renoise.app():show_error("External decoder failed with error code " .. tostring(result))
      return
    end
  end

  -- Load the WAV file produced by the external decoder
  print("-- Loading WAV file from external decoder:", wav_output)
  local load_success = pcall(function()
    smp.sample_buffer:load_from(wav_output)
  end)
  if not load_success then
    print("-- Failed to load WAV file:", wav_output)
    renoise.app():show_error("RX2 Import Error: Failed to load decoded sample.")
    return
  end
  if not smp.sample_buffer.has_sample_data then
    print("-- Loaded WAV file has no sample data")
    renoise.app():show_error("RX2 Import Error: No audio data in decoded sample.")
    return
  end
  print("-- Sample loaded successfully from external decoder")

  -- Read the slice marker text file and insert the markers
  local success = load_slice_markers(txt_output)
  if success then
    print("-- Slice markers loaded successfully from file:", txt_output)
  else
    print("-- Warning: Could not load slice markers from file:", txt_output)
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
  
  print("-- RX2 imported successfully with slice markers")

  -- Step 2: Now export as PTI
  print("-- Starting PTI export...")

  -- Check if we should use save paths
  local pti_filename = ""
  if get_use_save_paths() and get_pti_save_path() ~= "" then
    -- Use configured save path
    local pti_save_path = get_pti_save_path()
    local path_exists = check_polyend_path_exists(pti_save_path)
    if path_exists then
      local safe_name = instrument_name:gsub("[^%w%-%_]", "_") -- Replace unsafe characters
      local separator = package.config:sub(1,1)
      local base_path = pti_save_path .. separator .. safe_name .. ".pti"
      
      -- Generate unique filename if file already exists
      pti_filename = generate_unique_filename(base_path)
      local final_filename = pti_filename:match("[^/\\]+$") or "converted.pti"
      
      print("-- PTI export using save path: " .. pti_filename)
    else
      renoise.app():show_error("PTI save path not accessible:\n" .. pti_save_path)
      return
    end
  else
    -- Prompt for PTI save location
    pti_filename = renoise.app():prompt_for_filename_to_write("pti", "Save converted PTI as...")
    if pti_filename == "" then
      print("-- PTI export cancelled by user")
      return
    end
    print("-- PTI export filename: " .. pti_filename)
  end

  local inst = song.selected_instrument
  local export_smp = inst.samples[1]

  -- Handle slice count limitation (max 48 in PTI format)
  local original_slice_count = #(export_smp.slice_markers or {})
  local limited_slice_count = math.min(48, original_slice_count)
  
  if original_slice_count > 48 then
    print(string.format("-- NOTE: Sample has %d slices - limiting to 48 slices for PTI format", original_slice_count))
    renoise.app():show_status(string.format("PTI format supports max 48 slices - limiting from %d", original_slice_count))
  end

  -- Gather simple inst params
  local data = {
    name = inst.name,
    is_wavetable = false,
    sample_length = export_smp.sample_buffer.number_of_frames,
    loop_mode = export_smp.loop_mode,
    loop_start = export_smp.loop_start,
    loop_end = export_smp.loop_end,
    channels = export_smp.sample_buffer.number_of_channels,
    slice_markers = {} -- Initialize empty slice markers table
  }

  -- Copy up to 48 slice markers
  print(string.format("-- Copying %d slice markers from Renoise sample", limited_slice_count))
  for i = 1, limited_slice_count do
    data.slice_markers[i] = export_smp.slice_markers[i]
    print(string.format("-- Export slice %02d: Renoise frame position = %d", i, export_smp.slice_markers[i]))
  end

  -- Determine playback mode
  local playback_mode = "1-Shot"
  if #data.slice_markers > 0 then
    playback_mode = "Slice"
    print("-- Sample Playback Mode: Slice (mode 4)")
  end

  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames, sliceCount = %d", 
    data.channels > 1 and "Stereo" or "Mono",
    44100,
    16,
    data.sample_length,
    limited_slice_count
  ))

  local loop_mode_names = {
    [renoise.Sample.LOOP_MODE_OFF] = "OFF",
    [renoise.Sample.LOOP_MODE_FORWARD] = "Forward",
    [renoise.Sample.LOOP_MODE_REVERSE] = "Reverse",
    [renoise.Sample.LOOP_MODE_PING_PONG] = "PingPong"
  }

  print(string.format("-- Loopmode: %s, Start: %d, End: %d, Looplength: %d",
    loop_mode_names[export_smp.loop_mode] or "OFF",
    export_smp.loop_start,
    export_smp.loop_end,
    export_smp.loop_end - export_smp.loop_start
  ))

  print(string.format("-- Wavetable Mode: %s", data.is_wavetable and "TRUE" or "FALSE"))

  local f = io.open(pti_filename, "wb")
  if not f then 
    renoise.app():show_error("Cannot write file: " .. pti_filename)
    return 
  end

  -- Write header and get its size for verification (using Beat Slice mode for RX2)
  local header = buildPTIHeader(data, true)
  print(string.format("-- Header size: %d bytes", #header))
  f:write(header)

  -- Debug first few frames before writing
  local buf = export_smp.sample_buffer
  print("-- Sample value ranges:")
  local min_val, max_val = 0, 0
  for i = 1, math.min(100, data.sample_length) do
    for ch = 1, data.channels do
      local v = buf:sample_data(ch, i)
      min_val = math.min(min_val, v)
      max_val = math.max(max_val, v)
    end
  end
  print(string.format("-- First 100 frames min/max: %.6f to %.6f", min_val, max_val))

  -- Write PCM data
  local pcm_start_pos = f:seek()
  write_pcm(f, { sample_buffer = export_smp.sample_buffer, sample_length = data.sample_length, channels = data.channels })
  local pcm_end_pos = f:seek()
  local pcm_size = pcm_end_pos - pcm_start_pos
  
  print(string.format("-- PCM data size: %d bytes", pcm_size))
  print(string.format("-- Total file size: %d bytes", pcm_end_pos))

  f:close()

  -- Create local backup copy if enabled
  if create_local_backup_copy then
    create_local_backup_copy(pti_filename, "RX2_Convert")
  end

  -- Show final status
  print("-- RX2 to PTI conversion completed successfully!")
  local final_filename = pti_filename:match("[^/\\]+$") or "converted.pti"
  
  -- Refresh the dropdown to show the new file
  if polyend_refresh_callback then
    polyend_refresh_callback()
  end
  
  if original_slice_count > 0 then
          if original_slice_count > 48 then
        renoise.app():show_status(string.format("RX2 converted to PTI saved to %s with 48 slices (limited from %d)", pti_filename, original_slice_count))
      else
        renoise.app():show_status(string.format("RX2 converted to PTI saved to %s with %d slices", pti_filename, original_slice_count))
      end
    else
      renoise.app():show_status(string.format("RX2 converted to PTI saved to %s", pti_filename))
    end
end

--------------------------------------------------------------------------------
-- Firmware Download Functions
-- Advanced firmware download and extraction functionality
--------------------------------------------------------------------------------

-- Function to download and extract firmware
function download_and_extract_firmware(device_name, download_url)
  print(string.format("-- Firmware Download: Starting download for %s", device_name))
  print(string.format("-- Firmware Download: URL: %s", download_url))
  
  -- Get temporary directory
  local TEMP_FOLDER = "/tmp"
  local os_name = os.platform()
  if os_name == "MACINTOSH" then
    TEMP_FOLDER = os.getenv("TMPDIR") or "/tmp"
  elseif os_name == "WINDOWS" then
    TEMP_FOLDER = os.getenv("TEMP") or "C:\\temp"
  end
  
  -- Create device-specific temp folder
  local device_folder_name = device_name:lower():gsub("%+", "plus"):gsub("%s", "_") .. "_firmware"
  local device_temp_folder = TEMP_FOLDER .. package.config:sub(1,1) .. device_folder_name
  
  -- Extract filename from URL
  local filename = download_url:match("([^/]+%.zip)$") or "firmware.zip"
  local download_path = device_temp_folder .. package.config:sub(1,1) .. filename
  local extract_path = device_temp_folder .. package.config:sub(1,1) .. "extracted"
  
  print(string.format("-- Firmware Download: Device folder: %s", device_temp_folder))
  print(string.format("-- Firmware Download: Download path: %s", download_path))
  print(string.format("-- Firmware Download: Extract path: %s", extract_path))
  
  -- Create temp directories
  local mkdir_cmd
  if os_name == "WINDOWS" then
    mkdir_cmd = string.format('mkdir "%s" 2>nul & mkdir "%s" 2>nul', device_temp_folder, extract_path)
  else
    mkdir_cmd = string.format('mkdir -p "%s" && mkdir -p "%s"', device_temp_folder, extract_path)
  end
  
  local mkdir_result = os.execute(mkdir_cmd)
  print(string.format("-- Firmware Download: Created directories (result: %s)", tostring(mkdir_result)))
  
  -- Download the firmware file
  renoise.app():show_status("Downloading firmware... Please wait...")
  
  local download_cmd
  if os_name == "MACINTOSH" or os_name == "LINUX" then
    -- Use curl on Unix systems
    download_cmd = string.format('curl -L -o "%s" "%s"', download_path, download_url)
  elseif os_name == "WINDOWS" then
    -- Use PowerShell on Windows
    download_cmd = string.format('powershell -Command "Invoke-WebRequest -Uri \'%s\' -OutFile \'%s\'"', download_url, download_path)
  else
    renoise.app():show_error("Unsupported operating system for firmware download")
    return false
  end
  
  print(string.format("-- Firmware Download: Download command: %s", download_cmd))
  local download_result = os.execute(download_cmd)
  
  if download_result ~= 0 then
    renoise.app():show_error(string.format("Failed to download firmware (exit code: %d)", download_result))
    return false
  end
  
  -- Verify download
  local download_file = io.open(download_path, "rb")
  if not download_file then
    renoise.app():show_error("Download failed - file not found")
    return false
  end
  download_file:seek("end")
  local file_size = download_file:seek()
  download_file:close()
  
  print(string.format("-- Firmware Download: Downloaded %d bytes", file_size))
  
  if file_size < 1000 then
    renoise.app():show_error("Download failed - file too small (likely download error)")
    return false
  end
  
  -- Extract the ZIP file
  renoise.app():show_status("Extracting firmware...")
  
  local extract_cmd
  if os_name == "MACINTOSH" or os_name == "LINUX" then
    -- Use unzip on Unix systems
    extract_cmd = string.format('cd "%s" && unzip -o "%s"', extract_path, download_path)
  elseif os_name == "WINDOWS" then
    -- Use PowerShell on Windows
    extract_cmd = string.format('powershell -Command "Expand-Archive -Path \'%s\' -DestinationPath \'%s\' -Force"', download_path, extract_path)
  end
  
  print(string.format("-- Firmware Download: Extract command: %s", extract_cmd))
  local extract_result = os.execute(extract_cmd)
  
  if extract_result ~= 0 then
    print(string.format("-- Firmware Download: Extract failed (exit code: %d), but opening download folder anyway", extract_result))
    -- Still open the folder even if extraction failed
    renoise.app():open_path(device_temp_folder)
    renoise.app():show_status(string.format("Firmware downloaded to: %s (extraction may have failed)", device_temp_folder))
    return device_temp_folder
  end
  
  -- Success - ask user what to do next
  renoise.app():show_status(string.format("Firmware downloaded and extracted successfully"))
  print(string.format("-- Firmware Download: Success! Firmware extracted to: %s", extract_path))
  
  return extract_path
end

-- Function to scrape firmware download URL from Polyend website
function scrape_firmware_url(device_name, page_url)
  print(string.format("-- Firmware Scraper: Scraping %s firmware URL from: %s", device_name, page_url))
  
  -- Get temporary directory for HTML download
  local TEMP_FOLDER = "/tmp"
  local os_name = os.platform()
  if os_name == "MACINTOSH" then
    TEMP_FOLDER = os.getenv("TMPDIR") or "/tmp"
  elseif os_name == "WINDOWS" then
    TEMP_FOLDER = os.getenv("TEMP") or "C:\\temp"
  end
  
  local html_file = TEMP_FOLDER .. package.config:sub(1,1) .. "polyend_page.html"
  
  -- Download the HTML page with proper browser headers to bypass Cloudflare
  local download_cmd
  if os_name == "MACINTOSH" or os_name == "LINUX" then
    -- Use curl with browser-like headers and automatic decompression
    download_cmd = string.format('curl -s -L --compressed -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" -H "Accept-Language: en-US,en;q=0.5" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -o "%s" "%s"', html_file, page_url)
  elseif os_name == "WINDOWS" then
    -- Use PowerShell with browser-like headers
    download_cmd = string.format('powershell -Command "$headers = @{\'User-Agent\'=\'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\'; \'Accept\'=\'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8\'}; Invoke-WebRequest -Uri \'%s\' -OutFile \'%s\' -Headers $headers"', page_url, html_file)
  else
    renoise.app():show_error("Unsupported operating system for web scraping")
    return nil
  end
  
  print(string.format("-- Firmware Scraper: Download command: %s", download_cmd))
  
  -- Add a small delay to appear more human-like
  if os_name == "MACINTOSH" or os_name == "LINUX" then
    os.execute("sleep 1")
  elseif os_name == "WINDOWS" then
    os.execute("timeout /t 1 /nobreak >nul 2>&1")
  end
  
  local result = os.execute(download_cmd)
  
  if result ~= 0 then
    print(string.format("-- Firmware Scraper: Failed to download page (exit code: %d)", result))
    return nil
  end
  
  -- Read and parse the HTML file
  local file = io.open(html_file, "r")
  if not file then
    print("-- Firmware Scraper: Failed to open downloaded HTML file")
    return nil
  end
  
  local html_content = file:read("*all")
  file:close()
  
  -- Clean up temp file
  os.remove(html_file)
  
  print(string.format("-- Firmware Scraper: Downloaded %d bytes of HTML", #html_content))
  
  -- Debug: Save HTML content to file for inspection
  local debug_file = TEMP_FOLDER .. package.config:sub(1,1) .. "polyend_debug.html"
  local debug_f = io.open(debug_file, "w")
  if debug_f then
    debug_f:write(html_content)
    debug_f:close()
    print(string.format("-- Firmware Scraper: DEBUG - Saved HTML to: %s", debug_file))
  end
  
  -- Debug: Show first 500 characters of HTML
  print("-- Firmware Scraper: DEBUG - First 500 chars of HTML:")
  print(string.sub(html_content, 1, 500))
  print("-- Firmware Scraper: DEBUG - End of HTML preview")
  
  -- Parse HTML to find firmware download link
  -- Look for patterns like: href="https://polyend-website.fra1.digitaloceanspaces.com/wp-content/uploads/.../TrackerPlus_X.X.X.zip"
  -- or similar patterns for different devices
  
  local firmware_patterns = {
    -- Tracker+ patterns
    'href="(https://[^"]*TrackerPlus[^"]*%.zip)"',
    'href="(https://[^"]*Tracker%+[^"]*%.zip)"',
    'href="(https://[^"]*tracker[_%-]?plus[^"]*%.zip)"',
    'href="(https://[^"]*tracker%+[^"]*%.zip)"',
    -- Tracker patterns (but not Tracker+ or TrackerMini)
    'href="(https://[^"]*Tracker[^Plus][^Mini][^"]*%.zip)"',
    'href="(https://[^"]*tracker[^plus][^mini][^"]*%.zip)"',
    -- Mini patterns
    'href="(https://[^"]*TrackerMini[^"]*%.zip)"',
    'href="(https://[^"]*Tracker[_%-]?Mini[^"]*%.zip)"',
    'href="(https://[^"]*Mini[^"]*%.zip)"',
    'href="(https://[^"]*mini[^"]*%.zip)"',
    'href="(https://[^"]*tracker[_%-]?mini[^"]*%.zip)"'
  }
  
  -- Try each pattern to find a firmware download URL
  print("-- Firmware Scraper: DEBUG - Testing patterns...")
  for i, pattern in ipairs(firmware_patterns) do
    print(string.format("-- Firmware Scraper: DEBUG - Pattern %d: %s", i, pattern))
    local url = html_content:match(pattern)
    if url then
      print(string.format("-- Firmware Scraper: Found firmware URL with pattern %d: %s", i, url))
      return url
    else
      print(string.format("-- Firmware Scraper: DEBUG - Pattern %d: NO MATCH", i))
    end
  end
  
  -- Debug: Look for any ZIP files at all
  print("-- Firmware Scraper: DEBUG - Looking for any ZIP files...")
  local all_zips = {}
  for zip_url in html_content:gmatch('href="([^"]*%.zip)"') do
    table.insert(all_zips, zip_url)
    print(string.format("-- Firmware Scraper: DEBUG - Found ZIP: %s", zip_url))
  end
  
  if #all_zips == 0 then
    print("-- Firmware Scraper: DEBUG - No ZIP files found at all!")
  else
    print(string.format("-- Firmware Scraper: DEBUG - Found %d total ZIP files", #all_zips))
  end
  
  -- Debug: Look for any download links
  print("-- Firmware Scraper: DEBUG - Looking for any download links...")
  local download_count = 0
  for download_link in html_content:gmatch('href="([^"]*download[^"]*)"') do
    download_count = download_count + 1
    print(string.format("-- Firmware Scraper: DEBUG - Download link %d: %s", download_count, download_link))
    if download_count >= 5 then -- Limit output
      print("-- Firmware Scraper: DEBUG - (showing first 5 download links only)")
      break
    end
  end
  
  -- If no specific pattern matches, look for any ZIP file from polyend domains
  local generic_url = html_content:match('href="(https://polyend[^"]*%.zip)"')
  if generic_url then
    print(string.format("-- Firmware Scraper: Found generic firmware URL: %s", generic_url))
    return generic_url
  end
  
  print("-- Firmware Scraper: No firmware download URL found")
  return nil
end

--------------------------------------------------------------------------------
-- Copy Firmware to Polyend Device Function
-- Copies firmware files from temp folder to Polyend device /Firmware folder
--------------------------------------------------------------------------------
function copy_firmware_to_device(firmware_folder_path, device_name)
  print(string.format("-- Copy Firmware: Starting copy to device for %s", device_name))
  print(string.format("-- Copy Firmware: Source folder: %s", firmware_folder_path))
  
  -- Get the Polyend root path from preferences
  local polyend_root_path = ""
  if preferences and preferences.PolyendRoot and preferences.PolyendRoot.value then
    polyend_root_path = preferences.PolyendRoot.value
  end
  
  -- First check if Polyend device is connected
  local path_exists = check_polyend_path_exists(polyend_root_path)
  if not path_exists then
    renoise.app():show_error(POLYEND_DEVICE_NOT_CONNECTED_TITLE .. "\n\n" .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
    print("-- Copy Firmware: Polyend device not accessible: " .. (polyend_root_path or ""))
    return false
  end
  
  -- Check if firmware folder exists on device, create if needed
  local separator = package.config:sub(1,1)
  local device_firmware_path = polyend_root_path .. separator .. "Firmware"
  
  -- Check if Firmware folder exists
  local firmware_folder_exists = check_polyend_path_exists(device_firmware_path)
  if not firmware_folder_exists then
    print("-- Copy Firmware: Creating Firmware folder on device: " .. device_firmware_path)
    
    -- Try to create the Firmware folder
    local os_name = os.platform()
    local mkdir_cmd
    if os_name == "WINDOWS" then
      mkdir_cmd = string.format('mkdir "%s"', device_firmware_path)
    else
      mkdir_cmd = string.format('mkdir -p "%s"', device_firmware_path)
    end
    
    local mkdir_result = os.execute(mkdir_cmd)
    if mkdir_result ~= 0 then
      renoise.app():show_error("Failed to create Firmware folder on Polyend device:\n" .. device_firmware_path)
      print("-- Copy Firmware: Failed to create Firmware folder.")
      return false
    end
    
    print("-- Copy Firmware: Successfully created Firmware folder.")
  else
    print("-- Copy Firmware: Firmware folder already exists on device.")
  end
  
  -- Get list of files in source firmware folder
  local success, firmware_files = pcall(os.filenames, firmware_folder_path, "*")
  if not success or not firmware_files then
    renoise.app():show_error("Cannot read firmware files from:\n" .. firmware_folder_path)
    print("-- Copy Firmware: Cannot read source firmware files")
    return false
  end
  
  print(string.format("-- Copy Firmware: Found %d files to copy", #firmware_files))
  
  -- Check for existing firmware files and ask about overwrite
  local existing_files = {}
  for _, filename in ipairs(firmware_files) do
    local dest_file_path = device_firmware_path .. separator .. filename
    local file_exists = io.open(dest_file_path, "rb")
    if file_exists then
      file_exists:close()
      table.insert(existing_files, filename)
    end
  end
  
  if #existing_files > 0 then
    local overwrite_msg = string.format("The following firmware files already exist on the device:\n\n%s\n\nDo you want to overwrite them?", 
      table.concat(existing_files, "\n"))
    local overwrite = renoise.app():show_prompt("Firmware Files Exist", overwrite_msg, {"Yes", "No"})
    if overwrite == "No" then
      print("-- Copy Firmware: User cancelled - files already exist")
      return false
    end
  end
  
  -- Copy all files
  local copied_count = 0
  local failed_count = 0
  
  for _, filename in ipairs(firmware_files) do
    local source_file_path = firmware_folder_path .. separator .. filename
    local dest_file_path = device_firmware_path .. separator .. filename
    
    print(string.format("-- Copy Firmware: Copying %s...", filename))
    
    -- Copy the file
    local copy_success, error_msg = pcall(function()
      -- Read source file
      local source_file = io.open(source_file_path, "rb")
      if not source_file then
        error("Cannot open source file: " .. source_file_path)
      end
      
      local file_data = source_file:read("*all")
      source_file:close()
      
      if not file_data or #file_data == 0 then
        error("Source file is empty or unreadable: " .. filename)
      end
      
      -- Write to destination
      local dest_file = io.open(dest_file_path, "wb")
      if not dest_file then
        error("Cannot create destination file: " .. dest_file_path)
      end
      
      dest_file:write(file_data)
      dest_file:close()
      
      print(string.format("-- Copy Firmware: Successfully copied %s (%d bytes)", filename, #file_data))
    end)
    
    if copy_success then
      copied_count = copied_count + 1
    else
      failed_count = failed_count + 1
      print(string.format("-- Copy Firmware: Failed to copy %s: %s", filename, error_msg or "Unknown error"))
    end
  end
  
  -- Report results
  if copied_count > 0 and failed_count == 0 then
    renoise.app():show_status(string.format("%s firmware copied to device (%d files)", device_name, copied_count))
    print(string.format("-- Copy Firmware: Success! Copied %d files to device", copied_count))
    
    -- Show success and ask about opening folder in one dialog
    local open_folder = renoise.app():show_prompt("Firmware Copy Complete", 
      string.format("Firmware copied to device successfully!\n\n%s firmware files copied to:\n%s\n\nFiles copied: %d\n\nWould you like to open the device Firmware folder?", 
        device_name, device_firmware_path, copied_count),
      {"Yes", "No"})
    if open_folder == "Yes" then
      renoise.app():open_path(device_firmware_path)
    end
    
    return true
  else
    local error_message = string.format("❌ Firmware copy failed!\n\nCopied: %d files\nFailed: %d files\n\nPlease check:\n• Device has enough free space\n• You have write permissions\n• Device connection is stable", 
      copied_count, failed_count)
    renoise.app():show_error(error_message)
    print(string.format("-- Copy Firmware: Copy completed with errors - %d copied, %d failed", copied_count, failed_count))
    return false
  end
end

--------------------------------------------------------------------------------
-- Polyend Buddy Dialog
-- File browser for PTI files from Polyend device device
--------------------------------------------------------------------------------



-- Initialize root path from preferences
function initialize_polyend_root_path()
  if preferences and preferences.PolyendRoot and preferences.PolyendRoot.value then
    polyend_buddy_root_path = preferences.PolyendRoot.value
  end
end

-- Initialize local PTI path from preferences
function initialize_computer_pti_path()
  if preferences and preferences.PolyendLocalPath and preferences.PolyendLocalPath.value then
    computer_pti_path = preferences.PolyendLocalPath.value
  end
end

-- Initialize save paths from preferences
local polyend_pti_save_path = ""
local polyend_wav_save_path = ""
local polyend_use_save_paths = false
local polyend_computer_backup_path = ""
local polyend_use_computer_backup = false

function initialize_save_paths()
  polyend_pti_save_path = get_pti_save_path()
  polyend_wav_save_path = get_wav_save_path()
  polyend_use_save_paths = get_use_save_paths()
  polyend_computer_backup_path = get_computer_backup_path()
  polyend_use_computer_backup = get_use_computer_backup()
  
  -- Initialize visibility states
  save_paths_section_visible = polyend_use_save_paths
  backup_section_visible = polyend_use_computer_backup
end

-- Function to update section visibility in the dialog
local function update_section_visibility(vb)
  if vb and vb.views then
    -- Update save paths section visibility
    if vb.views["save_paths_section"] then
      vb.views["save_paths_section"].visible = save_paths_section_visible
    end
    
    -- Update backup section visibility  
    if vb.views["backup_section"] then
      vb.views["backup_section"].visible = backup_section_visible
    end
  end
end

-- Function to check if the Polyend device path exists
function check_polyend_path_exists(path)
  if not path or path == "" then
    return false
  end
  
  -- Try to access the directory
  local success, files = pcall(os.filenames, path, "*")
  return success
end

-- Function to recursively scan folder for PTI/WAV files and collect folders
function scan_for_pti_files_and_folders(root_path)
  local pti_files = {}
  local wav_files = {}
  local folders = {}
  local separator = package.config:sub(1,1)
  
  local function scan_directory(path, relative_path)
    -- Check if directory exists and is accessible
    local success, files = pcall(os.filenames, path, "*")
    if not success then
      print(string.format("-- Polyend Buddy: Warning - Cannot access directory: %s", path))
      print(string.format("-- Polyend Buddy: Error details: %s", tostring(files)))
      return
    end
    
    local success2, dirs = pcall(os.dirnames, path)
    if not success2 then
      print(string.format("-- Polyend Buddy: Warning - Cannot list subdirectories in: %s", path))
      dirs = {}
    end
    
    print(string.format("-- Polyend Buddy: Scanning %s - found %d files, %d dirs", path, #files, #dirs))
    
    -- Add current directory to folders list (if not root and not hidden)
    if relative_path ~= "" and not relative_path:match("^%.") and not relative_path:match("%..*$") then
      table.insert(folders, {
        display_name = relative_path,
        full_path = path
      })
    end
    
    -- Scan files in current directory
    for _, filename in ipairs(files) do
      local relative_file_path = relative_path == "" and filename or (relative_path .. separator .. filename)
      local full_path = path .. separator .. filename
      
      if filename:lower():match("%.pti$") and not filename:match("^%._") then
        table.insert(pti_files, {
          display_name = relative_file_path,
          full_path = full_path
        })
        print(string.format("-- Polyend Buddy: Found PTI file: %s", relative_file_path))
      elseif filename:lower():match("%.wav$") and not filename:match("^%._") then
        table.insert(wav_files, {
          display_name = relative_file_path,
          full_path = full_path
        })
        print(string.format("-- Polyend Buddy: Found WAV file: %s", relative_file_path))
      elseif filename:match("^%._") then
        print(string.format("-- Polyend Buddy: Skipping macOS metadata file: %s", relative_file_path))
      end
    end
    
    -- Recursively scan subdirectories (skip hidden/system folders)
    for _, dirname in ipairs(dirs) do
      -- Skip hidden folders (starting with .) and common system folders
      if not dirname:match("^%.") and 
         dirname ~= "System Volume Information" and 
         dirname ~= "$RECYCLE.BIN" and
         dirname ~= "Thumbs.db" then
        local sub_path = path .. separator .. dirname
        local sub_relative = relative_path == "" and dirname or (relative_path .. separator .. dirname)
        scan_directory(sub_path, sub_relative)
      else
        print(string.format("-- Polyend Buddy: Skipping system/hidden folder: %s", dirname))
      end
    end
  end
  
  if root_path and root_path ~= "" then
    -- Check if root path exists before scanning
    local success, test_files = pcall(os.filenames, root_path, "*")
    if not success then
      print(string.format("-- Polyend Buddy: Error - Root path does not exist or is not accessible: %s", root_path))
      print(string.format("-- Polyend Buddy: Error details: %s", tostring(test_files)))
      return pti_files, folders
    end
    
    print(string.format("-- Polyend Buddy: Root path accessible, found %d files", #test_files))
    
    -- Always add root folder as an option
    table.insert(folders, {
      display_name = "(Root Folder)",
      full_path = root_path
    })
    scan_directory(root_path, "")
  end
  
  return pti_files, wav_files, folders
end

-- Function to scan local PTI path for PTI and WAV files (recursively)
function scan_computer_pti_files(root_path)
  local pti_files = {}
  local separator = package.config:sub(1,1)
  
  if not root_path or root_path == "" then
    return pti_files
  end
  
  local function scan_directory(path, relative_path)
    -- Check if directory exists and is accessible
    local success, files = pcall(os.filenames, path, "*")
    if not success then
      print(string.format("-- Local PTI: Warning - Cannot access directory: %s", path))
      print(string.format("-- Local PTI: Error details: %s", tostring(files)))
      return
    end
    
    local success2, dirs = pcall(os.dirnames, path)
    if not success2 then
      print(string.format("-- Local PTI: Warning - Cannot list subdirectories in: %s", path))
      dirs = {}
    end
    
    print(string.format("-- Local PTI: Scanning %s - found %d files, %d dirs", path, #files, #dirs))
    
    -- Scan files in current directory
    for _, filename in ipairs(files) do
      local relative_file_path = relative_path == "" and filename or (relative_path .. separator .. filename)
      local full_path = path .. separator .. filename
      
             if (filename:lower():match("%.pti$") or filename:lower():match("%.wav$")) and not filename:match("^%._") then
         table.insert(pti_files, {
           display_name = relative_file_path,
           full_path = full_path
         })
         local file_type = filename:lower():match("%.pti$") and "PTI" or "WAV"
         print(string.format("-- Local PTI: Found %s file: %s", file_type, relative_file_path))
       elseif filename:match("^%._") then
         print(string.format("-- Local PTI: Skipping macOS metadata file: %s", relative_file_path))
       end
    end
    
    -- Recursively scan subdirectories (skip hidden/system folders)
    for _, dirname in ipairs(dirs) do
      -- Skip hidden folders (starting with .) and common system folders
      if not dirname:match("^%.") and 
         dirname ~= "System Volume Information" and 
         dirname ~= "$RECYCLE.BIN" and
         dirname ~= "Thumbs.db" then
        local sub_path = path .. separator .. dirname
        local sub_relative = relative_path == "" and dirname or (relative_path .. separator .. dirname)
        scan_directory(sub_path, sub_relative)
      else
        print(string.format("-- Local PTI: Skipping system/hidden folder: %s", dirname))
      end
    end
  end
  
  -- Check if root path exists before scanning
  local success, test_files = pcall(os.filenames, root_path, "*")
  if not success then
    print(string.format("-- Local PTI: Error - Root path does not exist or is not accessible: %s", root_path))
    print(string.format("-- Local PTI: Error details: %s", tostring(test_files)))
    return pti_files
  end
  
  print(string.format("-- Local PTI: Root path accessible, found %d files", #test_files))
  
  -- Start recursive scanning
  scan_directory(root_path, "")
  
  -- Sort by display name (case-insensitive)
  table.sort(pti_files, function(a, b)
    return a.display_name:lower() < b.display_name:lower()
  end)
  
  return pti_files
end

-- Function to scan local backup path for PTI and WAV files (recursively)
function scan_computer_backup_files(root_path)
  local backup_files = {}
  local separator = package.config:sub(1,1)
  
  if not root_path or root_path == "" then
    return backup_files
  end
  
  local function scan_directory(path, relative_path)
    -- Check if directory exists and is accessible
    local success, files = pcall(os.filenames, path, "*")
    if not success then
      print(string.format("-- Local Backup: Warning - Cannot access directory: %s", path))
      print(string.format("-- Local Backup: Error details: %s", tostring(files)))
      return
    end
    
    local success2, dirs = pcall(os.dirnames, path)
    if not success2 then
      print(string.format("-- Local Backup: Warning - Cannot list subdirectories in: %s", path))
      dirs = {}
    end
    
    print(string.format("-- Local Backup: Scanning %s - found %d files, %d dirs", path, #files, #dirs))
    
    -- Scan files in current directory
    for _, filename in ipairs(files) do
      local relative_file_path = relative_path == "" and filename or (relative_path .. separator .. filename)
      local full_path = path .. separator .. filename
      
      if (filename:lower():match("%.pti$") or filename:lower():match("%.wav$")) and not filename:match("^%._") then
        table.insert(backup_files, {
          display_name = relative_file_path,
          full_path = full_path
        })
        local file_type = filename:lower():match("%.pti$") and "PTI" or "WAV"
        print(string.format("-- Local Backup: Found %s file: %s", file_type, relative_file_path))
      elseif filename:match("^%._") then
        print(string.format("-- Local Backup: Skipping macOS metadata file: %s", relative_file_path))
      end
    end
    
    -- Recursively scan subdirectories (skip hidden/system folders)
    for _, dirname in ipairs(dirs) do
      -- Skip hidden folders (starting with .) and common system folders
      if not dirname:match("^%.") and 
         dirname ~= "System Volume Information" and 
         dirname ~= "$RECYCLE.BIN" and
         dirname ~= "Thumbs.db" then
        local sub_path = path .. separator .. dirname
        local sub_relative = relative_path == "" and dirname or (relative_path .. separator .. dirname)
        scan_directory(sub_path, sub_relative)
      else
        print(string.format("-- Local Backup: Skipping system/hidden folder: %s", dirname))
      end
    end
  end
  
  -- Check if root path exists before scanning
  local success, test_files = pcall(os.filenames, root_path, "*")
  if not success then
    print(string.format("-- Local Backup: Error - Root path does not exist or is not accessible: %s", root_path))
    print(string.format("-- Local Backup: Error details: %s", tostring(test_files)))
    return backup_files
  end
  
  print(string.format("-- Local Backup: Root path accessible, found %d files", #test_files))
  
  -- Start recursive scanning
  scan_directory(root_path, "")
  
  -- Sort by display name (case-insensitive)
  table.sort(backup_files, function(a, b)
    return a.display_name:lower() < b.display_name:lower()
  end)
  
  return backup_files
end

-- Function to update the dropdowns with found PTI/WAV files and folders
function update_pti_dropdown(vb)
  -- Check if path exists first
  local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
  
  if not path_exists then
    -- Clear all data
    polyend_buddy_pti_files = {}
    polyend_buddy_wav_files = {}
    polyend_buddy_folders = {}
    
    -- Update status to show connection error
    if vb.views["pti_count_text"] then
      vb.views["pti_count_text"].text = "⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG
    end
    
    -- Set dropdowns to empty state
    if vb.views["pti_files_popup"] then
      vb.views["pti_files_popup"].items = {"<" .. POLYEND_DEVICE_NOT_CONNECTED_MSG .. ">"}
      vb.views["pti_files_popup"].value = 1
    end
    
    if vb.views["wav_files_popup"] then
      vb.views["wav_files_popup"].items = {"<" .. POLYEND_DEVICE_NOT_CONNECTED_MSG .. ">"}
      vb.views["wav_files_popup"].value = 1
    end
    

    
    -- Show status message
    renoise.app():show_status(POLYEND_DEVICE_NOT_CONNECTED_TITLE .. " - check path: " .. (polyend_buddy_root_path or ""))
    print(string.format("-- Polyend Buddy: Path not accessible: %s", polyend_buddy_root_path or ""))
    return
  end
  
  -- Path exists, scan for files
  polyend_buddy_pti_files, polyend_buddy_wav_files, polyend_buddy_folders = scan_for_pti_files_and_folders(polyend_buddy_root_path)
  
  -- Update PTI files dropdown
  local file_dropdown_items = {"<No PTI files found, connect device in USB Storage Mode and press Refresh>"}
  if #polyend_buddy_pti_files > 0 then
    -- Sort the actual file array by display_name first (case-insensitive)
    table.sort(polyend_buddy_pti_files, function(a, b)
      return a.display_name:lower() < b.display_name:lower()
    end)
    
    -- Then create dropdown items in the same order
    file_dropdown_items = {}
    for _, pti_file in ipairs(polyend_buddy_pti_files) do
      table.insert(file_dropdown_items, pti_file.display_name)
    end
    -- No need to sort file_dropdown_items since polyend_buddy_pti_files is already sorted
  end
  
  if vb.views["pti_files_popup"] then
    vb.views["pti_files_popup"].items = file_dropdown_items
    vb.views["pti_files_popup"].value = 1
  end
  
  -- Update WAV files dropdown
  local wav_dropdown_items = {"<No WAV files found, connect device in USB Storage Mode and press Refresh>"}
  if #polyend_buddy_wav_files > 0 then
    -- Sort the actual file array by display_name first (case-insensitive)
    table.sort(polyend_buddy_wav_files, function(a, b)
      return a.display_name:lower() < b.display_name:lower()
    end)
    
    -- Then create dropdown items in the same order
    wav_dropdown_items = {}
    for _, wav_file in ipairs(polyend_buddy_wav_files) do
      table.insert(wav_dropdown_items, wav_file.display_name)
    end
    -- No need to sort wav_dropdown_items since polyend_buddy_wav_files is already sorted
  end
  
  if vb.views["wav_files_popup"] then
    vb.views["wav_files_popup"].items = wav_dropdown_items
    vb.views["wav_files_popup"].value = 1
  end
  
  -- Update folders dropdown
  local folder_dropdown_items = {"<No folders found, " .. POLYEND_DEVICE_NOT_CONNECTED_MSG:lower() .. ">"}
  if #polyend_buddy_folders > 0 then
    -- Sort the actual folder array by display_name first (case-insensitive)
    table.sort(polyend_buddy_folders, function(a, b)
      return a.display_name:lower() < b.display_name:lower()
    end)
    
    -- Then create dropdown items in the same order
    folder_dropdown_items = {}
    for _, folder in ipairs(polyend_buddy_folders) do
      table.insert(folder_dropdown_items, folder.display_name)
    end
    -- No need to sort folder_dropdown_items since polyend_buddy_folders is already sorted
  end
  
  -- Update status text with success message
  if vb.views["pti_count_text"] then
    if #polyend_buddy_pti_files == 0 and #polyend_buddy_wav_files == 0 then
      vb.views["pti_count_text"].text = "Polyend device connected - No PTI/WAV files found. Try adding some files to your device!"
    else
      vb.views["pti_count_text"].text = string.format("Polyend device connected - Found %d PTI files, %d WAV files", #polyend_buddy_pti_files, #polyend_buddy_wav_files)
    end
  end
  
  -- Show success status
  if #polyend_buddy_pti_files == 0 and #polyend_buddy_wav_files == 0 then
    renoise.app():show_status("Polyend device connected - No PTI/WAV files found")
  else
    renoise.app():show_status(string.format("Polyend device connected - Found %d PTI files, %d WAV files", #polyend_buddy_pti_files, #polyend_buddy_wav_files))
  end
  print(string.format("-- Polyend Buddy: Found %d PTI files, %d WAV files and %d folders in %s", #polyend_buddy_pti_files, #polyend_buddy_wav_files, #polyend_buddy_folders, polyend_buddy_root_path))
end

-- Function to update the local PTI dropdown
function update_computer_pti_dropdown(vb)
  -- Check if path exists first
  local path_exists = check_polyend_path_exists(computer_pti_path)
  
  if not path_exists then
    -- Clear data
    computer_pti_files = {}
    
    -- Set dropdown to empty state
            if vb.views["computer_pti_popup"] then
          vb.views["computer_pti_popup"].items = {"<Set Local PTI Path>"}
          vb.views["computer_pti_popup"].value = 1
        end
    
    print(string.format("-- Local PTI: Path not accessible: %s", computer_pti_path or ""))
    return
  end
  
  -- Path exists, scan for PTI files
  computer_pti_files = scan_computer_pti_files(computer_pti_path)
  
  -- Update local PTI files dropdown
  local dropdown_items = {"<No PTI/WAV files found>"}
  if #computer_pti_files > 0 then
    dropdown_items = {}
    for _, pti_file in ipairs(computer_pti_files) do
      table.insert(dropdown_items, pti_file.display_name)
    end
  end
  
  if vb.views["computer_pti_popup"] then
    vb.views["computer_pti_popup"].items = dropdown_items
    vb.views["computer_pti_popup"].value = 1
  end
  
  print(string.format("-- Local PTI: Found %d PTI files in %s", #computer_pti_files, computer_pti_path))
end

-- Function to update the local backup dropdown
function update_computer_backup_dropdown(vb)
  -- Check if path exists first
  local backup_path = get_computer_backup_path()
  local path_exists = check_polyend_path_exists(backup_path)
  
  if not path_exists then
    -- Clear data
    computer_backup_files = {}
    
    -- Set dropdown to empty state
    if vb.views["computer_backup_popup"] then
      vb.views["computer_backup_popup"].items = {"<Set Local Backup Path>"}
      vb.views["computer_backup_popup"].value = 1
    end
    
    print(string.format("-- Local Backup: Path not accessible: %s", backup_path or ""))
    return
  end
  
  -- Path exists, scan for PTI files
  computer_backup_files = scan_computer_backup_files(backup_path)
  
  -- Update local backup files dropdown
  local dropdown_items = {"<No PTI/WAV files found>"}
  if #computer_backup_files > 0 then
    dropdown_items = {}
    for _, backup_file in ipairs(computer_backup_files) do
      table.insert(dropdown_items, backup_file.display_name)
    end
  end
  
  if vb.views["computer_backup_popup"] then
    vb.views["computer_backup_popup"].items = dropdown_items
    vb.views["computer_backup_popup"].value = 1
  end
  
  print(string.format("-- Local Backup: Found %d PTI files in %s", #computer_backup_files, backup_path))
end

--------------------------------------------------------------------------------
-- Backup P_Tracker Function
-- Creates a complete backup of the Polyend device folder structure
--------------------------------------------------------------------------------
function backup_polyend_tracker()
  -- First check if Polyend device is connected
  local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
  if not path_exists then
    renoise.app():show_error(POLYEND_DEVICE_NOT_CONNECTED_TITLE .. "\n\n" .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
    print("-- Backup Polyend device: Source path not accessible: " .. (polyend_buddy_root_path or ""))
    return
  end
  
  -- Always prompt user for backup destination folder
  local backup_destination = renoise.app():prompt_for_path("Select Backup Destination Folder")
  if not backup_destination or backup_destination == "" then
    print("-- Backup Polyend device: User cancelled backup destination selection")
    return
  end
  
  print("-- Backup Polyend device: Starting backup process")
  print("-- Source: " .. polyend_buddy_root_path)
  print("-- Destination: " .. backup_destination)
  
  -- Create timestamped backup folder name with unique naming
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local backup_folder_name = "P_Tracker_Backup_" .. timestamp
  local base_backup_path = backup_destination .. separator .. backup_folder_name
  
  -- Generate unique backup folder name if folder already exists
  local full_backup_path = generate_unique_filename(base_backup_path)
  local final_backup_folder = full_backup_path:match("[^/\\]+$") or backup_folder_name
  
  -- Detect OS and prepare appropriate copy command
  local os_name = os.platform()
  local copy_command
  local success_code = 0
  
  if os_name == "MACINTOSH" or os_name == "LINUX" then
    -- Use rsync for Unix-like systems (handles all files including hidden ones)
    -- -a: archive mode (preserves permissions, timestamps, etc.)
    -- -v: verbose (but we'll capture output)
    -- --progress: show progress
    copy_command = string.format('rsync -av --progress "%s/" "%s" 2>&1', 
      polyend_buddy_root_path, full_backup_path)
  elseif os_name == "WINDOWS" then
    -- Check if robocopy is available first
    local robocopy_check = os.execute('robocopy /? >nul 2>&1')
    if robocopy_check == 0 then
      -- Use robocopy for Windows (handles hidden files and system files)
      -- /E: copy subdirectories including empty ones
      -- /H: copy hidden and system files
      -- /R:3: retry 3 times on failure
      -- /W:10: wait 10 seconds between retries
      -- /NP: no progress (to avoid flooding output)
      copy_command = string.format('robocopy "%s" "%s" /E /H /R:3 /W:10 /NP', 
        polyend_buddy_root_path, full_backup_path)
      -- Robocopy success codes are different (0-7 are success, 8+ are errors)
      success_code = 7
      print("-- Backup Polyend device: Using robocopy for Windows backup")
    else
      -- Fallback to xcopy (available on all Windows versions)
      -- /E: copy directories and subdirectories including empty ones
      -- /H: copy hidden and system files
      -- /K: copy attributes
      -- /Y: suppress prompting to confirm overwrite
      copy_command = string.format('xcopy "%s" "%s" /E /H /K /Y', 
        polyend_buddy_root_path, full_backup_path)
      success_code = 0
      print("-- Backup Polyend device: Using xcopy fallback for Windows backup")
    end
  else
    renoise.app():show_error("Unsupported operating system for backup operation")
    return
  end
  
  print("-- Backup Polyend device: Executing command: " .. copy_command)
  renoise.app():show_status("Starting Polyend device backup - this may take several minutes...")
  
  -- Execute the backup command
  local result = os.execute(copy_command)
  
  -- Check if backup was successful
  local backup_successful = false
  if os_name == "WINDOWS" then
    -- Windows robocopy: exit codes 0-7 indicate success
    backup_successful = (result >= 0 and result <= success_code)
  else
    -- Unix systems: exit code 0 indicates success
    backup_successful = (result == success_code)
  end
  
  -- Verify backup by checking if destination folder exists and has content
  local verification_success = false
  local file_count = 0
  
  -- Function to recursively count all files in backup directory
  local function count_files_recursive(path)
    local total_files = 0
    local separator = package.config:sub(1,1)
    
    local success, files = pcall(os.filenames, path, "*")
    if success and files then
      total_files = total_files + #files
      
      local success2, dirs = pcall(os.dirnames, path)
      if success2 and dirs then
        for _, dirname in ipairs(dirs) do
          -- Skip hidden folders and system folders
          if not dirname:match("^%.") and 
             dirname ~= "System Volume Information" and 
             dirname ~= "$RECYCLE.BIN" and
             dirname ~= "Thumbs.db" then
            local sub_path = path .. separator .. dirname
            total_files = total_files + count_files_recursive(sub_path)
          end
        end
      end
    end
    
    return total_files
  end
  
  if backup_successful then
    local verify_success, verify_files = pcall(os.filenames, full_backup_path, "*")
    if verify_success and verify_files then
      file_count = count_files_recursive(full_backup_path)
      verification_success = (file_count > 0)
      print(string.format("-- Backup Polyend device: Verification found %d total files in backup (recursive count)", file_count))
    end
  end
  
  -- Report results
  if backup_successful and verification_success then
    print("-- Backup Polyend device: Backup completed successfully")
    print("-- Backup location: " .. full_backup_path)
    
    -- Show success and ask about opening folder in one dialog
    local open_folder = renoise.app():show_prompt("Backup Complete", 
      string.format("Polyend device backup completed successfully!\n\nBackup folder: %s\nBackup location: %s\nFiles backed up: %d\n\nWould you like to open the backup folder?", 
        final_backup_folder, full_backup_path, file_count),
      {"Yes", "No"})
    if open_folder == "Yes" then
      renoise.app():open_path(backup_destination)
    end
  else
    local error_message = string.format("❌ Polyend device backup failed!\n\nCommand exit code: %d\nPlease check:\n• Source path is accessible\n• Destination has enough free space\n• You have write permissions to destination", 
      result or -1)
    renoise.app():show_error(error_message)
    print(string.format("-- Backup Polyend device: Backup failed with exit code %d", result or -1))
  end
end

--------------------------------------------------------------------------------
-- Normalize PTI Slices Function
-- Universal function for normalizing PTI slices with automatic save
--------------------------------------------------------------------------------
function normalize_pti_slices_and_save(pti_filepath, save_path, completion_callback)
  print(string.format("-- PTI Normalize: Starting normalization for: %s", pti_filepath))
  
  -- Step 1: Check if PTI file exists
  print("-- PTI Normalize: Step 1 - Checking PTI file exists...")
  local pti_file = io.open(pti_filepath, "rb")
  if not pti_file then
    local error_msg = string.format("PTI file not found or not accessible:\n%s", pti_filepath)
    renoise.app():show_error(error_msg)
    print("-- PTI Normalize: PTI file does not exist: " .. pti_filepath)
    if completion_callback then completion_callback(false, error_msg) end
    return
  end
  pti_file:close()
  
  -- Step 2: Load the PTI file
  print("-- PTI Normalize: Step 2 - Loading PTI file...")
  pti_loadsample(pti_filepath)
  
  -- Check if we have a valid sample with slices
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    local error_msg = "Failed to load PTI file or no sample data found"
    renoise.app():show_error(error_msg)
    if completion_callback then completion_callback(false, error_msg) end
    return
  end
  
  if #sample.slice_markers == 0 then
    local error_msg = "PTI file has no slices to normalize"
    renoise.app():show_status(error_msg)
    print("-- PTI Normalize: PTI file has no slices - skipping normalize operation")
    if completion_callback then completion_callback(false, error_msg) end
    return
  end
  
  print(string.format("-- PTI Normalize: Loaded PTI with %d slices", #sample.slice_markers))
  
  -- Step 3: Normalize slices with automatic save
  print("-- PTI Normalize: Step 3 - Normalizing slices...")
  renoise.app():show_status("Normalizing slices...")
  
  -- Call the callback-enabled normalize function
  if normalize_selected_sample_by_slices_with_callback then
    normalize_selected_sample_by_slices_with_callback(function(success)
      if success then
        print("-- PTI Normalize: Step 4 - Saving normalized PTI...")
        renoise.app():show_status("Saving normalized PTI...")
        
        -- Use pti_savesample_to_path to save to the specified path
        if pti_savesample_to_path then
          local save_success = pti_savesample_to_path(save_path)
          if save_success then
            local filename = save_path:match("[^/\\]+$") or "normalized.pti"
            
            -- Create local backup copy if enabled
            if create_local_backup_copy then
              create_local_backup_copy(save_path, "Normalize")
            end
            
            -- Trigger global refresh if available (from dialog context)
            if polyend_refresh_callback then
              polyend_refresh_callback()
            end
            
            renoise.app():show_status(string.format("Normalized slices and saved PTI: %s", filename))
            print("-- PTI Normalize: Normalize slices operation completed successfully")
            if completion_callback then completion_callback(true, filename) end
          else
            local error_msg = "Failed to save normalized PTI file"
            renoise.app():show_error(error_msg)
            print("-- PTI Normalize: Failed to save normalized PTI file")
            if completion_callback then completion_callback(false, error_msg) end
          end
        else
          -- Fallback: use regular pti_savesample and let user choose location
          print("-- PTI Normalize: pti_savesample_to_path not found, using regular save dialog")
          pti_savesample()
          renoise.app():show_status("Slices normalized - PTI saved via dialog")
          if completion_callback then completion_callback(true, "PTI saved via dialog") end
        end
      else
        local error_msg = "Slice normalization was cancelled or failed"
        renoise.app():show_error(error_msg)
        print("-- PTI Normalize: Slice normalization failed")
        if completion_callback then completion_callback(false, error_msg) end
      end
    end)
  else
    local error_msg = "normalize_selected_sample_by_slices_with_callback function not found"
    renoise.app():show_error(error_msg)
    if completion_callback then completion_callback(false, error_msg) end
    return
  end
end

--------------------------------------------------------------------------------
-- PTI Analyzer Function
-- Analyzes PTI files and displays detailed information
--------------------------------------------------------------------------------
function analyze_pti_file(pti_filepath)
  print("-- PTI Analyzer: Starting analysis of: " .. pti_filepath)
  
  -- Check if file exists
  local file = io.open(pti_filepath, "rb")
  if not file then
    renoise.app():show_error("Cannot open PTI file: " .. pti_filepath)
    return
  end
  
  -- Read the entire file to get file size
  file:seek("end")
  local file_size = file:seek()
  file:seek("set", 0)
  
  print(string.format("-- PTI Analyzer: File size: %d bytes", file_size))
  
  -- Read PTI header (392 bytes)
  local header = file:read(392)
  if not header or #header < 392 then
    file:close()
    renoise.app():show_error("Invalid PTI file: header too short")
    return
  end
  
  -- Helper function to read little-endian values from header
  local function read_uint32_le(data, offset)
    local b1, b2, b3, b4 = string.byte(data, offset + 1, offset + 4)
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
  end
  
  local function read_uint16_le(data, offset)
    local b1, b2 = string.byte(data, offset + 1, offset + 2)
    return b1 + (b2 * 256)
  end
  
  local function read_uint8(data, offset)
    return string.byte(data, offset + 1)
  end
  
  -- Extract information from PTI header (based on buildPTIHeader structure)
  local sample_length = read_uint32_le(header, 60)     -- Offset 60: Sample length in frames
  local sample_rate = 44100                            -- PTI files are always 44.1kHz
  local channels = 2                                   -- Assume stereo for now (need to determine from file size)
  local bit_depth = read_uint8(header, 386)            -- Offset 386: Bit depth
  local playback_mode = read_uint8(header, 76)         -- Offset 76: Playback mode
  local slice_count = read_uint8(header, 376)          -- Offset 376: Number of slices
  local volume = read_uint8(header, 272)               -- Offset 272: Volume
  local panning = read_uint8(header, 276)              -- Offset 276: Panning
  
  -- Determine channel count from file size
  local expected_pcm_size = sample_length * 2 * (bit_depth / 8)  -- Stereo
  local actual_pcm_size = file_size - 392
  if math.abs(expected_pcm_size - actual_pcm_size) > 4 then
    -- Try mono
    expected_pcm_size = sample_length * 1 * (bit_depth / 8)
    if math.abs(expected_pcm_size - actual_pcm_size) <= 4 then
      channels = 1
    end
  end
  
  -- Calculate duration
  local duration_seconds = sample_length / sample_rate
  local duration_minutes = math.floor(duration_seconds / 60)
  local duration_secs = duration_seconds % 60
  
  -- Decode playback mode
  local playback_modes = {
    [1] = "1-Shot",
    [2] = "Loop",
    [3] = "Ping-Pong",
    [4] = "Slice",
    [5] = "Beat Slice",
    [6] = "Wavetable"
  }
  local playback_mode_name = playback_modes[playback_mode] or string.format("Unknown (%d)", playback_mode)
  
  -- Read slice positions if there are slices
  local slice_info = ""
  if slice_count > 0 then
    -- Slice positions start at offset 280 (48 markers × 2 bytes each)
    local slice_positions = {}
    for i = 0, math.min(slice_count - 1, 47) do  -- Max 48 slices in PTI format
      local slice_value = read_uint16_le(header, 280 + (i * 2))
      -- Convert slice value back to frame position: (slice_value / 65535) * sample_length
      local slice_frame = math.floor((slice_value / 65535) * sample_length)
      table.insert(slice_positions, slice_frame)
    end
    
    slice_info = string.format("\n\nSlice Information:\n")
    for i, pos in ipairs(slice_positions) do
      local slice_time = pos / sample_rate
      slice_info = slice_info .. string.format("  Slice %02d: Frame %d (%.3fs)\n", i, pos, slice_time)
    end
  end

  
  -- Convert volume and panning to dB and position
  local volume_db = ""
  if volume == 50 then
    volume_db = "0.0 dB"
  elseif volume == 98 then
    volume_db = "0.0 dB"
  elseif volume == 100 then
    volume_db = "0.9 dB"
  else
    -- Don't show approximations - only known accurate values
    volume_db = ""
  end
  
  local panning_pos = "Center"
  if panning < 50 then
    panning_pos = string.format("Left %d", 50 - panning)
  elseif panning > 50 then
    panning_pos = string.format("Right %d", panning - 50)
  end
  
  file:close()
  
  -- Create analysis report
  local analysis_report = string.format([[PTI File Analysis Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• File: %s
• File Size: %d bytes (%.2f KB)
• Duration: %d:%05.2f (%d samples, %d frames)
• Details: %d Hz, %d-bit, %s
• Playback Mode: %s

Mixing Settings:
• Volume: %d%s
• Panning: %d (%s)

Slice Information:
• Slice Count: %d
• Sliced: %s%s]], 
    pti_filepath:match("[^/\\]+$") or pti_filepath,
    file_size, file_size / 1024,
    duration_minutes, duration_secs, sample_length, sample_length,
    sample_rate,
    bit_depth,
    channels == 1 and "Mono" or "Stereo",
    playback_mode_name,
    volume, volume_db ~= "" and (" (" .. volume_db .. ")") or "",
    panning, panning_pos,
    slice_count,
    slice_count > 0 and "Yes" or "No",
    slice_info
  )
  
  -- Show the analysis in a dialog
  renoise.app():show_message(analysis_report)
  
  -- Also print to console for debugging
  print("-- PTI Analyzer: Analysis completed")
  print("-- PTI Analyzer: " .. string.format("Sample: %d frames, %dHz, %d-bit, %s", 
    sample_length, sample_rate, bit_depth, channels == 1 and "mono" or "stereo"))
  print("-- PTI Analyzer: " .. string.format("Playback: %s, Slices: %d", playback_mode_name, slice_count))
end

--------------------------------------------------------------------------------
-- Dump PTI to Device Function
-- Copies PTI files from local directly to Polyend device
--------------------------------------------------------------------------------
function dump_pti_to_device()
  -- First check if Polyend device is connected
  local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
  if not path_exists then
    renoise.app():show_error(POLYEND_DEVICE_NOT_CONNECTED_TITLE .. "\n\n" .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
    print("-- Dump PTI to Device: Polyend device not accessible: " .. (polyend_buddy_root_path or ""))
    return
  end
  
  -- Step 1: Browse for PTI file to copy
  local source_pti = renoise.app():prompt_for_filename_to_read({"*.pti"}, "Select PTI file to copy to Polyend device")
  if not source_pti or source_pti == "" then
    print("-- Dump PTI to Device: User cancelled PTI file selection")
    return
  end
  
  print("-- Dump PTI to Device: Selected source PTI: " .. source_pti)
  
  -- Extract filename from path
  local pti_filename = source_pti:match("[^/\\]+$") or "unknown.pti"
  print("-- Dump PTI to Device: PTI filename: " .. pti_filename)
  
  -- Step 2: Let user choose destination folder on Polyend device
  local destination_folder = renoise.app():prompt_for_path("Select destination folder on Polyend device")
  if not destination_folder or destination_folder == "" then
    print("-- Dump PTI to Device: User cancelled destination folder selection")
    return
  end
  
  print("-- Dump PTI to Device: Destination folder: " .. destination_folder)
  
  -- Verify destination folder exists and is accessible
  local dest_exists = check_polyend_path_exists(destination_folder)
  if not dest_exists then
    renoise.app():show_error("Destination folder is not accessible:\n" .. destination_folder)
    print("-- Dump PTI to Device: Destination folder not accessible: " .. destination_folder)
    return
  end
  
  -- Create full destination path
  local separator = package.config:sub(1,1)
  local destination_path = destination_folder .. separator .. pti_filename
  
  -- Check if file already exists
  local file_exists = io.open(destination_path, "rb")
  if file_exists then
    file_exists:close()
    local overwrite = renoise.app():show_prompt("File Exists", 
      string.format("File already exists:\n%s\n\nDo you want to overwrite it?", pti_filename),
      {"Yes", "No"})
    if overwrite == "No" then
      print("-- Dump PTI to Device: User cancelled - file already exists")
      return
    end
  end
  
  print("-- Dump PTI to Device: Copying file...")
  print("-- Source: " .. source_pti)
  print("-- Destination: " .. destination_path)
  
  -- Copy the file
  local success, error_msg = pcall(function()
    -- Read source file
    local source_file = io.open(source_pti, "rb")
    if not source_file then
      error("Cannot open source PTI file: " .. source_pti)
    end
    
    local file_data = source_file:read("*all")
    source_file:close()
    
    if not file_data or #file_data == 0 then
      error("Source PTI file is empty or unreadable")
    end
    
    -- Write to destination
    local dest_file = io.open(destination_path, "wb")
    if not dest_file then
      error("Cannot create destination file: " .. destination_path)
    end
    
    dest_file:write(file_data)
    dest_file:close()
    
    print(string.format("-- Dump PTI to Device: Successfully copied %d bytes", #file_data))
  end)
  
  if success then
    -- Verify the copy was successful
    local verify_file = io.open(destination_path, "rb")
    if verify_file then
      verify_file:seek("end")
      local copied_size = verify_file:seek()
      verify_file:close()
      
      renoise.app():show_status(string.format("PTI copied to %s", destination_path))
      print("-- Dump PTI to Device: Copy operation completed successfully")
      
      -- Refresh the dropdown to show the new file
      if polyend_refresh_callback then
        polyend_refresh_callback()
      end
      
      -- Show success and ask about opening folder in one dialog
      local open_folder = renoise.app():show_prompt("Copy Complete", 
        string.format("PTI file copied successfully!\n\nFile: %s\nSize: %d bytes (%.2f KB)\nDestination: %s\n\nWould you like to open the destination folder?", 
          pti_filename, copied_size, copied_size / 1024, destination_folder),
        {"Yes", "No"})
      if open_folder == "Yes" then
        renoise.app():open_path(destination_folder)
      end
    else
      renoise.app():show_error("Copy appeared successful but cannot verify destination file")
      print("-- Dump PTI to Device: Copy completed but verification failed")
    end
  else
    local error_message = string.format("❌ Failed to copy PTI file!\n\nError: %s\n\nPlease check:\n• Source file is accessible\n• Destination has enough free space\n• You have write permissions", 
      error_msg or "Unknown error")
    renoise.app():show_error(error_message)
    print("-- Dump PTI to Device: Copy failed: " .. (error_msg or "Unknown error"))
  end
end

-- Function to send local PTI file to device
function send_computer_pti_to_device(pti_filepath)
  -- First check if Polyend device is connected
  local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
  if not path_exists then
    renoise.app():show_error(POLYEND_DEVICE_NOT_CONNECTED_TITLE .. "\n\n" .. POLYEND_DEVICE_NOT_CONNECTED_MSG .. "\n\nThen try Send to Device again.")
    print("-- Send Local PTI: Polyend device not accessible: " .. (polyend_buddy_root_path or ""))
    return
  end
  
  print("-- Send Local PTI: Sending PTI file: " .. pti_filepath)
  
  -- Extract filename from path
  local pti_filename = pti_filepath:match("[^/\\]+$") or "unknown.pti"
  print("-- Send Local PTI: PTI filename: " .. pti_filename)
  
  -- Determine destination folder - use PTI save path if enabled, otherwise prompt
  local destination_folder
  local use_save_paths = get_use_save_paths()
  local pti_save_path = get_pti_save_path()
  
  if use_save_paths and pti_save_path ~= "" then
    -- Use configured PTI save path
    local path_exists = check_polyend_path_exists(pti_save_path)
    if path_exists then
      destination_folder = pti_save_path
      print("-- Send Local PTI: Using PTI save path: " .. destination_folder)
    else
      renoise.app():show_error("PTI save path not accessible:\n" .. pti_save_path .. "\n\nPlease choose destination manually.")
      destination_folder = renoise.app():prompt_for_path("Select destination folder on Polyend device")
      if not destination_folder or destination_folder == "" then
        print("-- Send Local PTI: User cancelled destination folder selection")
        return
      end
    end
  else
    -- Prompt user for destination folder
    destination_folder = renoise.app():prompt_for_path("Select destination folder on Polyend device")
    if not destination_folder or destination_folder == "" then
      print("-- Send Local PTI: User cancelled destination folder selection")
      return
    end
  end
  
  print("-- Send Local PTI: Destination folder: " .. destination_folder)
  
  -- Verify destination folder exists and is accessible
  local dest_exists = check_polyend_path_exists(destination_folder)
  if not dest_exists then
    renoise.app():show_error("Destination folder is not accessible:\n" .. destination_folder)
    print("-- Send Local PTI: Destination folder not accessible: " .. destination_folder)
    return
  end
  
  -- Create full destination path with unique filename if needed
  local separator = package.config:sub(1,1)
  local base_destination_path = destination_folder .. separator .. pti_filename
  local destination_path = generate_unique_filename(base_destination_path)
  local final_filename = destination_path:match("[^/\\]+$") or pti_filename
  
  print("-- Send Local PTI: Copying file...")
  print("-- Source: " .. pti_filepath)
  print("-- Destination: " .. destination_path)
  
  -- Copy the file
  local success, error_msg = pcall(function()
    -- Read source file
    local source_file = io.open(pti_filepath, "rb")
    if not source_file then
      error("Cannot open source PTI file: " .. pti_filepath)
    end
    
    local file_data = source_file:read("*all")
    source_file:close()
    
    if not file_data or #file_data == 0 then
      error("Source PTI file is empty or unreadable")
    end
    
    -- Write to destination
    local dest_file = io.open(destination_path, "wb")
    if not dest_file then
      error("Cannot create destination file: " .. destination_path)
    end
    
    dest_file:write(file_data)
    dest_file:close()
    
    print(string.format("-- Send Local PTI: Successfully copied %d bytes", #file_data))
  end)
  
  if success then
    -- Verify the copy was successful
    local verify_file = io.open(destination_path, "rb")
    if verify_file then
      verify_file:seek("end")
      local copied_size = verify_file:seek()
      verify_file:close()
      
      renoise.app():show_status(string.format("PTI sent to device: %s (%.2f KB) → %s", 
        final_filename, copied_size / 1024, destination_folder:match("[^/\\]+$") or destination_folder))
      print("-- Send Local PTI: Send operation completed successfully")
    else
      renoise.app():show_error("Copy appeared successful but cannot verify destination file")
      print("-- Send Local PTI: Copy completed but verification failed")
    end
  else
    local error_message = string.format("❌ Failed to send PTI file!\n\nError: %s\n\nPlease check:\n• Source file is accessible\n• Destination has enough free space\n• You have write permissions", 
      error_msg or "Unknown error")
    renoise.app():show_error(error_message)
    print("-- Send Local PTI: Send failed: " .. (error_msg or "Unknown error"))
  end
end


--------------------------------------------------------------------------------
-- Save PTI as Drumkit Functions
-- Combines all samples in current instrument into a single sliced drumkit sample
--------------------------------------------------------------------------------

-- Deprecated ProcessSlicer function (now integrated into main functions)
function save_pti_as_drumkit_stereo_ProcessSlicer(skip_save_prompt)
  -- Deprecated: Use save_pti_as_drumkit_stereo() instead (now includes ProcessSlicer by default)
  save_pti_as_drumkit_stereo(skip_save_prompt)
end

-- Worker function for ProcessSlicer stereo drumkit
function save_pti_as_drumkit_stereo_Worker(source_instrument, num_samples, skip_save_prompt, dialog, vb)
  local song = renoise.song()
  
  print("-- Save PTI as Drumkit: Starting drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- Save PTI as Drumkit: Will process %d samples (max 48)", num_samples))
  
  -- Detect if any sample is stereo
  local has_stereo = false
  local stereo_samples = {}
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_channels == 2 then
      has_stereo = true
      table.insert(stereo_samples, i)
    end
  end
  
  local target_channels = has_stereo and 2 or 1
  print(string.format("-- Save PTI as Drumkit: Target format: %s, 44100Hz, 16-bit", target_channels == 2 and "Stereo" or "Mono"))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "Drumkit Combo of Instrument " .. source_instrument.name
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress dialog and status
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Processing sample %d/%d...", i, num_samples)
    end
    local progress_msg = string.format("PTI Smart: Processing sample %d/%d...", i, num_samples)
    renoise.app():show_status(progress_msg)
    print(string.format("-- Save PTI as Drumkit: Processing sample %d/%d (slot %02d)...", i, num_samples, i))
    
    -- Note: ProcessSlicer cancellation is handled automatically by the framework
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      print(string.format("-- Save PTI as Drumkit: Processing slot %02d...", i))
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data (yield periodically for UI responsiveness)
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
          -- Yield every 1000 frames to maintain UI responsiveness
          if frame % 1000 == 0 then
            coroutine.yield()
          end
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to 44.1kHz 16-bit if needed
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local original_channels = temp_sample.sample_buffer.number_of_channels
      local needs_rate_bit_conversion = (original_rate ~= 44100) or (original_bit ~= 16)
      
      if needs_rate_bit_conversion then
        song.selected_sample_index = 1
        local channel_mode = (original_channels == 2) and "stereo" or "mono"
        process_sample_adjust(channel_mode, 44100, 16, "none")
      end
      
      -- Store processed sample data (yield periodically)
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data with yielding for UI responsiveness
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
          -- Yield every 500 frames during data copying
          if frame % 500 == 0 then
            coroutine.yield()
          end
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- Save PTI as Drumkit: ✓ Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- Save PTI as Drumkit: ✗ Skipping slot %02d: no sample data", i))
    end
    
    -- Yield after each sample to maintain UI responsiveness
    coroutine.yield()
  end
  
  -- Calculate total length and create combined sample
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating combined sample..."
  end
  renoise.app():show_status("PTI Smart: Creating combined sample...")
  print(string.format("-- Save PTI as Drumkit: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer (with yielding)
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Combining samples into drumkit..."
  end
  renoise.app():show_status("PTI Smart: Combining samples into drumkit...")
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    for frame = 1, sample_data.frames do
      for ch = 1, target_channels do
        local source_value = 0.0
        if sample_data.channels == target_channels then
          source_value = sample_data.data[ch][frame]
        elseif sample_data.channels == 1 and target_channels == 2 then
          source_value = sample_data.data[1][frame]
        elseif sample_data.channels == 2 and target_channels == 1 then
          source_value = (sample_data.data[1][frame] + sample_data.data[2][frame]) / 2
        else
          if sample_data.channels >= 1 then
            source_value = sample_data.data[1][frame]
          else
            source_value = 0.0
          end
        end
        combined_sample.sample_buffer:set_sample_data(ch, current_position + frame - 1, source_value)
      end
      -- Yield every 1000 frames during combination
      if frame % 1000 == 0 then
        coroutine.yield()
      end
    end
    current_position = current_position + sample_data.frames
  end
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating slice markers..."
  end
  renoise.app():show_status("PTI Smart: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
    -- Yield every 10 slices
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  
  song.selected_sample_index = 1
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status(string.format("PTI Smart Drumkit created: %d slices, %s", #slice_positions, target_channels == 2 and "Stereo" or "Mono"))
  print("-- Save PTI as Drumkit: Drumkit creation completed successfully")
  
  -- Save PTI file (skip prompt if requested)
  if not skip_save_prompt then
    pti_savesample()
  end
end

-- Stereo version - converts to stereo if any sample is stereo, otherwise mono (ProcessSlicer integrated)
function save_pti_as_drumkit_stereo(skip_save_prompt)
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety checks
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  -- Determine how many samples to process (max 48)
  local num_samples = math.min(48, #source_instrument.samples)
  
  local dialog, vb
  
  -- Create ProcessSlicer and start the process
  local process_slicer = ProcessSlicer(function()
    save_pti_as_drumkit_stereo_Worker(source_instrument, num_samples, skip_save_prompt, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Creating Polyend Drumkit...")
  process_slicer:start()
end

-- Deprecated ProcessSlicer function (now integrated into main functions)
function save_pti_as_drumkit_mono_ProcessSlicer(skip_save_prompt)
  -- Deprecated: Use save_pti_as_drumkit_mono() instead (now includes ProcessSlicer by default)
  save_pti_as_drumkit_mono(skip_save_prompt)
end

-- Worker function for ProcessSlicer mono drumkit
function save_pti_as_drumkit_mono_Worker(source_instrument, num_samples, skip_save_prompt, dialog, vb)
  local song = renoise.song()
  
  print("-- Save PTI as Drumkit: Starting mono drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- Save PTI as Drumkit: Will process %d samples (max 48)", num_samples))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "Mono Drumkit Combo of Instrument " .. source_instrument.name
  
  local target_channels = 1  -- Always mono for this version
  print("-- Save PTI as Drumkit: Target format: Mono, 44100Hz, 16-bit")
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress dialog and status
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Processing sample %d/%d...", i, num_samples)
    end
    local progress_msg = string.format("PTI Mono: Processing sample %d/%d...", i, num_samples)
    renoise.app():show_status(progress_msg)
    print(string.format("-- Save PTI as Drumkit (Mono): Processing sample %d/%d (slot %02d)...", i, num_samples, i))
    
    -- Note: ProcessSlicer cancellation is handled automatically by the framework
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data (yield periodically for UI responsiveness)
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
          -- Yield every 1000 frames to maintain UI responsiveness
          if frame % 1000 == 0 then
            coroutine.yield()
          end
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to mono 44.1kHz 16-bit
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local original_channels = temp_sample.sample_buffer.number_of_channels
      local needs_conversion = (original_rate ~= 44100) or (original_bit ~= 16) or (original_channels ~= 1)
      
      if needs_conversion then
        song.selected_sample_index = 1
        -- Force mono conversion regardless of original format
        process_sample_adjust("mono", 44100, 16, "none")
      end
      
      -- Store processed sample data (yield periodically)
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data with yielding for UI responsiveness
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
          -- Yield every 500 frames during data copying
          if frame % 500 == 0 then
            coroutine.yield()
          end
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- Save PTI as Drumkit: ✓ Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- Save PTI as Drumkit: ✗ Skipping slot %02d: no sample data", i))
    end
    
    -- Yield after each sample to maintain UI responsiveness
    coroutine.yield()
  end
  
  -- Calculate total length and create combined sample
  renoise.app():show_status("PTI Mono: Creating combined sample...")
  print(string.format("-- Save PTI as Drumkit: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer (with yielding)
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Combining samples into drumkit..."
  end
  renoise.app():show_status("PTI Mono: Combining samples into drumkit...")
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    for frame = 1, sample_data.frames do
      -- For mono target, always use channel 1 (already converted to mono above)
      local source_value = sample_data.data[1][frame]
      combined_sample.sample_buffer:set_sample_data(1, current_position + frame - 1, source_value)
      -- Yield every 1000 frames during combination
      if frame % 1000 == 0 then
        coroutine.yield()
      end
    end
    current_position = current_position + sample_data.frames
  end
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating slice markers..."
  end
  renoise.app():show_status("PTI Mono: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
    -- Yield every 10 slices
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  
  song.selected_sample_index = 1
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status(string.format("PTI Mono: Drumkit created with %d slices", #slice_positions))
  print("-- Save PTI as Drumkit: Mono drumkit creation completed successfully")
  
  -- Save PTI file (skip prompt if requested)
  if not skip_save_prompt then
    pti_savesample()
  end
end

-- Mono version - converts all samples to mono (ProcessSlicer integrated)
function save_pti_as_drumkit_mono(skip_save_prompt)
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety checks
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  -- Determine how many samples to process (max 48)
  local num_samples = math.min(48, #source_instrument.samples)
  
  local dialog, vb
  
  -- Create ProcessSlicer and start the process
  local process_slicer = ProcessSlicer(function()
    save_pti_as_drumkit_mono_Worker(source_instrument, num_samples, skip_save_prompt, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Creating Polyend Mono Drumkit...")
  process_slicer:start()
end

local textWidth = 130
local polyendButtonWidth = 70
-- Function to create the Polyend Buddy dialog content
function create_polyend_buddy_dialog(vb)
  return vb:column{
    margin = 5,
    
    
    
    -- Root folder selection
    vb:row{
    
      vb:text{
        text = "Polyend device Root",
        width = textWidth, style="strong",font="bold"},
      vb:textfield{
        id = "root_path_textfield",
        text = polyend_buddy_root_path,
        width = 400,
        tooltip = "Path to your Polyend device device or folder containing PTI files"
      },
      vb:button{
        text = "Browse",
        width = polyendButtonWidth,
        notifier = function()
          local selected_path = renoise.app():prompt_for_path("Select Polyend device Folder")
          if selected_path and selected_path ~= "" then
            polyend_buddy_root_path = selected_path
            vb.views["root_path_textfield"].text = selected_path
            
            -- Save to preferences
            if preferences and preferences.PolyendRoot then
              preferences.PolyendRoot.value = selected_path
              preferences:save_as("preferences.xml")
              print(string.format("-- Polyend Buddy: Saved root path to preferences: %s", selected_path))
            end
            
            update_pti_dropdown(vb)
          end
        end
      },
      vb:button{
        text = "Open Path",
        width = polyendButtonWidth,
        tooltip = "Open the Polyend device root folder in system file browser",
        notifier = function()
          -- Check if root path is configured and exists
          if not polyend_buddy_root_path or polyend_buddy_root_path == "" then
            renoise.app():show_status("Please configure Polyend device root path first")
            print("-- Polyend Buddy: No root path configured for Open Path operation")
            return
          end
          
          -- Check if the path exists
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            renoise.app():show_status("⚠️ Polyend device root path not accessible - check connection")
            print("-- Polyend Buddy: Root path not accessible for Open Path operation: " .. polyend_buddy_root_path)
            return
          end
          
          -- Open the root path
          renoise.app():open_path(polyend_buddy_root_path)
          renoise.app():show_status("Opened Polyend device root folder")
          print("-- Polyend Buddy: Opened root path: " .. polyend_buddy_root_path)
        end
      }
    },
    
    -- PTI files dropdown with Load button
    vb:row{
      vb:text{
        text = "Polyend PTI Files",
        width = textWidth, style="strong",font="bold"
      },
      vb:popup{
        id = "pti_files_popup",
        items = {"<No PTI files found, set device to USB Storage Mode and press Refresh>"},
        width = 400,
        tooltip = "Select a PTI file to load"
      },
      vb:button{
        text = "Load PTI",
        width = polyendButtonWidth,
        tooltip = "Load the selected PTI file",
        notifier = function()
          -- First check if Polyend device is still connected
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            print("-- Polyend Buddy: Connection lost during Load PTI operation")
            renoise.app():show_status("⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
            update_pti_dropdown(vb) -- This will show the error state
            return
          end
          
          local selected_index = vb.views["pti_files_popup"].value
          
          if #polyend_buddy_pti_files == 0 then
            renoise.app():show_status("No PTI files found to load")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_pti_files then
            local selected_pti = polyend_buddy_pti_files[selected_index]
            local dropdown_display_name = vb.views["pti_files_popup"].items[selected_index]
            print(string.format("-- Polyend Buddy: Selected dropdown item #%d: '%s'", selected_index, dropdown_display_name))
            print(string.format("-- Polyend Buddy: Loading PTI file: %s", selected_pti.full_path))
            
            -- Load the PTI file using the existing loader
            pti_loadsample(selected_pti.full_path)
            
            renoise.app():show_status(string.format("Loaded PTI: %s", selected_pti.display_name))
          else
            renoise.app():show_status("Please select a valid PTI file")
          end
        end
      },
      vb:button{
        text = "Open Path", 
        width = polyendButtonWidth,
        tooltip = "Open the selected PTI file's folder in system file browser",
        notifier = function()
          -- First check if Polyend device is connected
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            print("-- Polyend Buddy: Connection lost during Open PTI Folder operation")
            renoise.app():show_status("⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
            return
          end
          
          local selected_index = vb.views["pti_files_popup"].value
          
          if #polyend_buddy_pti_files == 0 then
            renoise.app():show_status("No PTI files found")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_pti_files then
            local selected_pti = polyend_buddy_pti_files[selected_index]
            local folder_path = selected_pti.full_path:match("(.+)[/\\][^/\\]*$")
            
            if folder_path then
              renoise.app():open_path(folder_path)
            end
          else
            renoise.app():show_status("Please select a valid PTI file")
          end
        end
      },
      vb:button{
        text = "Analyze", 
        width = polyendButtonWidth,
        tooltip = "Analyze the selected PTI file and show detailed information (slices, format, etc.)",
        notifier = function()
          -- First check if Polyend device is connected
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            print("-- Polyend Buddy: Connection lost during Analyze PTI operation")
            renoise.app():show_status("⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
            return
          end
          
          local selected_index = vb.views["pti_files_popup"].value
          
          if #polyend_buddy_pti_files == 0 then
            renoise.app():show_status("No PTI files found to analyze")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_pti_files then
            local selected_pti = polyend_buddy_pti_files[selected_index]
            local dropdown_display_name = vb.views["pti_files_popup"].items[selected_index]
            print(string.format("-- Polyend Buddy: Analyzing PTI file: %s", selected_pti.full_path))
            
            -- Analyze the PTI file
            analyze_pti_file(selected_pti.full_path)
            
            renoise.app():show_status(string.format("Analyzed PTI: %s", selected_pti.display_name))
          else
            renoise.app():show_status("Please select a valid PTI file to analyze")
          end
        end
      },
      vb:button{
        text = "Normalize Slices", 
        width = polyendButtonWidth *2,
        tooltip = "Load PTI file, normalize all slices, then save as PTI with _normalized suffix",
        notifier = function()
          -- First check if Polyend device is connected
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            print("-- Polyend Buddy: Connection lost during Normalize Slices operation")
            renoise.app():show_status("⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
            return
          end
          
          local selected_index = vb.views["pti_files_popup"].value
          
          if #polyend_buddy_pti_files == 0 then
            renoise.app():show_status("No PTI files found to normalize")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_pti_files then
            local selected_pti = polyend_buddy_pti_files[selected_index]
            local dropdown_display_name = vb.views["pti_files_popup"].items[selected_index]
            print(string.format("-- Polyend Buddy: Normalizing slices in PTI file: %s", selected_pti.full_path))
            
                         
            
            -- Create normalized filename in same directory as source file
            local base_path = selected_pti.full_path:gsub("%.pti$", "_normalized.pti")
            local normalized_path = generate_unique_filename(base_path)
            
            normalize_pti_slices_and_save(selected_pti.full_path, normalized_path, function(success, result)
              if success then
                -- Refresh the Polyend device dropdown to show the new file
                update_pti_dropdown(vb)
              end
            end)
            
          else
            renoise.app():show_status("Please select a valid PTI file to normalize")
          end
        end
      },


    },
    
    -- WAV files dropdown with Load button
    vb:row{
      vb:text{
        text = "Polyend WAV Files",
        width = textWidth, style="strong",font="bold"
      },
      vb:popup{
        id = "wav_files_popup",
        items = {"<No WAV files found, set device to USB Storage Mode and press Refresh>"},
        width = 400,
        tooltip = "Select a WAV file to load"
      },
      vb:button{
        text = "Load WAV",
        width = polyendButtonWidth,
        tooltip = "Load the selected WAV file",
        notifier = function()
          -- First check if Polyend device is still connected
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            print("-- Polyend Buddy: Connection lost during Load WAV operation")
            renoise.app():show_status("⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
            update_pti_dropdown(vb) -- This will show the error state
            return
          end
          
          local selected_index = vb.views["wav_files_popup"].value
          
          if #polyend_buddy_wav_files == 0 then
            renoise.app():show_status("No WAV files found to load")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_wav_files then
            local selected_wav = polyend_buddy_wav_files[selected_index]
            local dropdown_display_name = vb.views["wav_files_popup"].items[selected_index]
            print(string.format("-- Polyend Buddy: Selected dropdown item #%d: '%s'", selected_index, dropdown_display_name))
            print(string.format("-- Polyend Buddy: Loading WAV file: %s", selected_wav.full_path))
            
            -- Load the WAV file using the existing loader
            wav_loadsample(selected_wav.full_path)
            
            renoise.app():show_status(string.format("Loaded WAV: %s", selected_wav.display_name))
          else
            renoise.app():show_status("Please select a valid WAV file")
          end
        end
      },
      vb:button{
        text = "Open Path", 
        width = polyendButtonWidth,
        tooltip = "Open the selected WAV file's folder in system file browser",
        notifier = function()
          -- First check if Polyend device is connected
          local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
          if not path_exists then
            print("-- Polyend Buddy: Connection lost during Open WAV Folder operation")
            renoise.app():show_status("⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG)
            return
          end
          
          local selected_index = vb.views["wav_files_popup"].value
          
          if #polyend_buddy_wav_files == 0 then
            renoise.app():show_status("No WAV files found")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_wav_files then
            local selected_wav = polyend_buddy_wav_files[selected_index]
            local folder_path = selected_wav.full_path:match("(.+)[/\\][^/\\]*$")
            
            if folder_path then
              renoise.app():open_path(folder_path)
            end
          else
            renoise.app():show_status("Please select a valid WAV file")
          end
        end
      }

    },
    
    -- Use save paths checkbox (moved above the folders)
    vb:row{
      vb:text{
        text = "",
        width = textWidth
      },
      vb:checkbox{
        id = "use_save_paths_checkbox",
        value = polyend_use_save_paths,
        tooltip = "Use configured save paths instead of prompting for location",
        notifier = function(value)
          polyend_use_save_paths = value
          save_paths_section_visible = value
          -- Save to preferences
          if preferences and preferences.PolyendUseSavePaths then
            preferences.PolyendUseSavePaths.value = value
            preferences:save_as("preferences.xml")
            print(string.format("-- Polyend Buddy: Saved use save paths preference: %s", tostring(value)))
          end
          -- Update section visibility
          update_section_visibility(vb)
        end
      },
      vb:text{
        text = "Use Save Paths (saves to configured folders on device)",
        font = "bold", style="strong"
      }
    },
    
    -- Save paths configuration section (collapsible)
    vb:column{
      id = "save_paths_section",
      visible = save_paths_section_visible,
      
      -- PTI Save path configuration
      vb:row{
        vb:text{
          text = "PTI Save Folder",
          width = textWidth, style="strong",font="bold"
        },
        vb:textfield{
          id = "pti_save_path_textfield",
          text = polyend_pti_save_path ~= "" and polyend_pti_save_path or "<Set this Default Folder to save PTI files to your Polyend device>",
          width = 400,
          tooltip = "Default folder for saving PTI files"
        },
        vb:button{
          text = "Browse",
          width = polyendButtonWidth,
          notifier = function()
            local selected_path = renoise.app():prompt_for_path("Select PTI Save Folder")
            if selected_path and selected_path ~= "" then
              polyend_pti_save_path = selected_path
              vb.views["pti_save_path_textfield"].text = selected_path
              
              -- Save to preferences
              if preferences and preferences.PolyendPTISavePath then
                preferences.PolyendPTISavePath.value = selected_path
                preferences:save_as("preferences.xml")
                print(string.format("-- Polyend Buddy: Saved PTI save path to preferences: %s", selected_path))
              end
            end
          end
        },
        vb:button{
          text = "Open Path",
          width = polyendButtonWidth,
          tooltip = "Open the PTI save folder in system file browser",
          notifier = function()
            if not polyend_pti_save_path or polyend_pti_save_path == "" then
              renoise.app():show_status("Please configure PTI save path first.")
              return
            end
            
            local path_exists = check_polyend_path_exists(polyend_pti_save_path)
            if not path_exists then
              renoise.app():show_status("⚠️ PTI save path not accessible - check path")
              return
            end
            
            renoise.app():open_path(polyend_pti_save_path)
            renoise.app():show_status("Opened PTI save folder")
          end
        }
      },
      
      -- WAV save path configuration
      vb:row{
        vb:text{
          text = "WAV Save Folder",
          width = textWidth, style="strong",font="bold"
        },
        vb:textfield{
          id = "wav_save_path_textfield",
          text = polyend_wav_save_path ~= "" and polyend_wav_save_path or "<Set this Default Folder to save WAV files to your Polyend device>",
          width = 400,
          tooltip = "Default folder for saving WAV files"
        },
        vb:button{
          text = "Browse",
          width = polyendButtonWidth,
          notifier = function()
            local selected_path = renoise.app():prompt_for_path("Select WAV Save Folder")
            if selected_path and selected_path ~= "" then
              polyend_wav_save_path = selected_path
              vb.views["wav_save_path_textfield"].text = selected_path
              
              -- Save to preferences
              if preferences and preferences.PolyendWAVSavePath then
                preferences.PolyendWAVSavePath.value = selected_path
                preferences:save_as("preferences.xml")
                print(string.format("-- Polyend Buddy: Saved WAV save path to preferences: %s", selected_path))
              end
            end
          end
        },
        vb:button{
          text = "Open Path",
          width = polyendButtonWidth,
          tooltip = "Open the WAV save folder in system file browser",
          notifier = function()
            if not polyend_wav_save_path or polyend_wav_save_path == "" then
              renoise.app():show_status("Please configure WAV save path first.")
              return
            end
            
            local path_exists = check_polyend_path_exists(polyend_wav_save_path)
            if not path_exists then
              renoise.app():show_status("⚠️ WAV save path not accessible - check path")
              return
            end
            
            renoise.app():open_path(polyend_wav_save_path)
            renoise.app():show_status("Opened WAV save folder")
          end
        }
      }
    },
    
    -- Local PTI Path selection
    vb:row{
    
      vb:text{
        text = "Local PTI Path",
        width = textWidth, style="strong",font="bold"},
      vb:textfield{
        id = "computer_pti_path_textfield",
        text = computer_pti_path,
        width = 400,
        tooltip = "Path to your local folder containing PTI files"
      },
      vb:button{
        text = "Browse",
        width = polyendButtonWidth,
        notifier = function()
          local selected_path = renoise.app():prompt_for_path("Select Local PTI Folder")
          if selected_path and selected_path ~= "" then
            computer_pti_path = selected_path
            vb.views["computer_pti_path_textfield"].text = selected_path
            
            -- Save to preferences
            if preferences and preferences.PolyendLocalPath then
              preferences.PolyendLocalPath.value = selected_path
              preferences:save_as("preferences.xml")
              print(string.format("-- Local PTI: Saved local path to preferences: %s", selected_path))
            end
            
            update_computer_pti_dropdown(vb)
          end
        end
      },
      vb:button{
        text = "Open Path",
        width = polyendButtonWidth,
        tooltip = "Open the local PTI folder in system file browser",
        notifier = function()
          -- Check if local PTI path is configured and exists
          if not computer_pti_path or computer_pti_path == "" then
            renoise.app():show_status("Please configure Local PTI path first")
            print("-- Local PTI: No local PTI path configured for Open Path operation")
            return
          end
          
          -- Check if the path exists
          local path_exists = check_polyend_path_exists(computer_pti_path)
          if not path_exists then
            renoise.app():show_status("⚠️ Local PTI path not accessible - check path")
            print("-- Local PTI: Local PTI path not accessible for Open Path operation: " .. computer_pti_path)
            return
          end
          
          -- Open the local PTI path
          renoise.app():open_path(computer_pti_path)
          renoise.app():show_status("Opened Local PTI folder")
          print("-- Local PTI: Opened local PTI path: " .. computer_pti_path)
        end
      }
    },
    
    -- Local PTI files dropdown with Send button
    vb:row{
      vb:text{
        text = "Local PTI/WAV Files",
        width = textWidth, style="strong",font="bold"
      },
      vb:popup{
        id = "computer_pti_popup",
        items = {"<Set Local PTI Path>"},
        width = 400,
        tooltip = "Select a PTI or WAV file from your local folder to send to device"
      },
      vb:button{
        text = "Send to Device",
        width = polyendButtonWidth*2,
        tooltip = "Send the selected PTI or WAV file directly to Polyend device (choose destination folder)",
        notifier = function()
          local selected_index = vb.views["computer_pti_popup"].value
          
          if #computer_pti_files == 0 then
            renoise.app():show_status("No local PTI files found - set Local PTI Path first")
            return
          end
          
          if selected_index >= 1 and selected_index <= #computer_pti_files then
            local selected_pti = computer_pti_files[selected_index]
            local dropdown_display_name = vb.views["computer_pti_popup"].items[selected_index]
            print(string.format("-- Local PTI: Selected dropdown item #%d: '%s'", selected_index, dropdown_display_name))
            print(string.format("-- Local PTI: Sending PTI file: %s", selected_pti.full_path))
            
            -- Send the PTI file to device
            send_computer_pti_to_device(selected_pti.full_path)
            
            renoise.app():show_status(string.format("Sent PTI to device: %s", selected_pti.display_name))
          else
            renoise.app():show_status("Please select a valid local PTI file")
          end
        end
      },
      vb:button{
        text = "Analyze", 
        width = polyendButtonWidth,
        tooltip = "Analyze the selected local PTI file and show detailed information (slices, format, etc.)",
        notifier = function()
          local selected_index = vb.views["computer_pti_popup"].value
          
          if #computer_pti_files == 0 then
            renoise.app():show_status("No local PTI files found to analyze - set Local PTI Path first")
            return
          end
          
          if selected_index >= 1 and selected_index <= #computer_pti_files then
            local selected_pti = computer_pti_files[selected_index]
            local dropdown_display_name = vb.views["computer_pti_popup"].items[selected_index]
            print(string.format("-- Local PTI: Analyzing PTI file: %s", selected_pti.full_path))
            
            -- Analyze the PTI file
            analyze_pti_file(selected_pti.full_path)
            
            renoise.app():show_status(string.format("Analyzed local PTI: %s", selected_pti.display_name))
          else
            renoise.app():show_status("Please select a valid local PTI file to analyze")
          end
        end
      },
      vb:button{
        text = "Normalize Slices", 
        width = polyendButtonWidth *2,
        tooltip = "Load local PTI file, normalize all slices, then save as PTI with _normalized suffix",
        notifier = function()
          local selected_index = vb.views["computer_pti_popup"].value
          
          if #computer_pti_files == 0 then
            renoise.app():show_status("No local PTI files found to normalize - set Local PTI Path first")
            return
          end
          
          if selected_index >= 1 and selected_index <= #computer_pti_files then
            local selected_pti = computer_pti_files[selected_index]
            local dropdown_display_name = vb.views["computer_pti_popup"].items[selected_index]
            print(string.format("-- Local PTI: Normalizing slices in PTI file: %s", selected_pti.full_path))
            
            
            
            -- Create normalized filename in same directory as source file
            local base_path = selected_pti.full_path:gsub("%.pti$", "_normalized.pti")
            local normalized_path = generate_unique_filename(base_path)
            
            normalize_pti_slices_and_save(selected_pti.full_path, normalized_path, function(success, result)
              if success then
                -- Refresh the local PTI dropdown to show the new file
                update_computer_pti_dropdown(vb)
              end
            end)
            
          else
            renoise.app():show_status("Please select a valid local PTI file to normalize")
          end
        end
      }
    },
    
    -- Use local backup checkbox (moved above the backup section)
    vb:row{
      vb:text{
        text = "",
        width = textWidth
      },
      vb:checkbox{
        id = "use_computer_backup_checkbox",
        value = polyend_use_computer_backup,
        tooltip = "Automatically create backup copies of saved PTI/WAV files in the local backup folder",
        notifier = function(value)
          polyend_use_computer_backup = value
          backup_section_visible = value
          -- Save to preferences
          if preferences and preferences.PolyendUseLocalBackup then
            preferences.PolyendUseLocalBackup.value = value
            preferences:save_as("preferences.xml")
            print(string.format("-- Polyend Buddy: Saved use local backup preference: %s", tostring(value)))
          end
          -- Update section visibility
          update_section_visibility(vb)
        end
      },
      vb:text{
        text = "Auto-Backup Files (creates backup copies of saved PTI/WAV files)",
        font = "bold", style="strong"
      }
    },
    
    -- Local backup section (collapsible)
    vb:column{
      id = "backup_section",
      visible = backup_section_visible,
      
      -- Local backup path configuration
      vb:row{
        vb:text{
          text = "Local Backup Path",
          width = textWidth, style="strong",font="bold"
        },
        vb:textfield{
          id = "computer_backup_path_textfield",
          text = polyend_computer_backup_path ~= "" and polyend_computer_backup_path or "<Set this Local Folder for saving processed files to>",
          width = 400,
          tooltip = "Default folder for backing up Polyend device to local storage"
        },
        vb:button{
          text = "Browse",
          width = polyendButtonWidth,
          notifier = function()
            local selected_path = renoise.app():prompt_for_path("Select Local Backup Folder")
            if selected_path and selected_path ~= "" then
              polyend_computer_backup_path = selected_path
              vb.views["computer_backup_path_textfield"].text = selected_path
              
              -- Save to preferences
              if preferences and preferences.PolyendLocalBackupPath then
                preferences.PolyendLocalBackupPath.value = selected_path
                preferences:save_as("preferences.xml")
                print(string.format("-- Polyend Buddy: Saved local backup path to preferences: %s", selected_path))
              end
              
              update_computer_backup_dropdown(vb)
            end
          end
        },
        vb:button{
          text = "Open Path",
          width = polyendButtonWidth,
          tooltip = "Open the local backup folder in system file browser",
          notifier = function()
            if not polyend_computer_backup_path or polyend_computer_backup_path == "" then
              renoise.app():show_status("Please configure local backup path first.")
              return
            end
            
            local path_exists = check_polyend_path_exists(polyend_computer_backup_path)
            if not path_exists then
              renoise.app():show_status("⚠️ Local backup path not accessible - check path.")
              return
            end
            
            renoise.app():open_path(polyend_computer_backup_path)
            renoise.app():show_status("Opened local backup folder.")
          end
        }
      },
      
      -- Local backup files dropdown with Send button
      vb:row{
        vb:text{
          text = "Local Backup Files",
          width = textWidth, style="strong",font="bold"
        },
        vb:popup{
          id = "computer_backup_popup",
          items = {"<Set Local Backup Path>"},
          width = 400,
          tooltip = "Select a PTI or WAV file from your local backup folder to send to device"
        },
        vb:button{
          text = "Send to Device",
          width = polyendButtonWidth*2,
          tooltip = "Send the selected backup PTI or WAV file directly to Polyend device (choose destination folder)",
          notifier = function()
            local selected_index = vb.views["computer_backup_popup"].value
            
            if #computer_backup_files == 0 then
              renoise.app():show_status("No local backup files found - set Local Backup Path first")
              return
            end
            
            if selected_index >= 1 and selected_index <= #computer_backup_files then
              local selected_backup = computer_backup_files[selected_index]
              local dropdown_display_name = vb.views["computer_backup_popup"].items[selected_index]
              print(string.format("-- Local Backup: Selected dropdown item #%d: '%s'", selected_index, dropdown_display_name))
              print(string.format("-- Local Backup: Sending PTI file: %s", selected_backup.full_path))
              
              -- Send the PTI file to device
              send_computer_pti_to_device(selected_backup.full_path)
              
              renoise.app():show_status(string.format("Sent backup PTI to device: %s", selected_backup.display_name))
            else
              renoise.app():show_status("Please select a valid local backup file")
            end
          end
        },
        vb:button{
          text = "Analyze", 
          width = polyendButtonWidth,
          tooltip = "Analyze the selected local backup PTI file and show detailed information (slices, format, etc.)",
          notifier = function()
            local selected_index = vb.views["computer_backup_popup"].value
            
            if #computer_backup_files == 0 then
              renoise.app():show_status("No local backup files found to analyze - set Local Backup Path first")
              return
            end
            
            if selected_index >= 1 and selected_index <= #computer_backup_files then
              local selected_backup = computer_backup_files[selected_index]
              local dropdown_display_name = vb.views["computer_backup_popup"].items[selected_index]
              print(string.format("-- Local Backup: Analyzing PTI file: %s", selected_backup.full_path))
              
              -- Analyze the PTI file
              analyze_pti_file(selected_backup.full_path)
              
              renoise.app():show_status(string.format("Analyzed backup PTI: %s", selected_backup.display_name))
            else
              renoise.app():show_status("Please select a valid local backup file to analyze")
            end
          end
        },
        vb:button{
          text = "Normalize Slices", 
          width = polyendButtonWidth *2,
          tooltip = "Load local backup PTI file, normalize all slices, then save as PTI with _normalized suffix",
          notifier = function()
            local selected_index = vb.views["computer_backup_popup"].value
            
            if #computer_backup_files == 0 then
              renoise.app():show_status("No local backup files found to normalize - set Local Backup Path first")
              return
            end
            
            if selected_index >= 1 and selected_index <= #computer_backup_files then
              local selected_backup = computer_backup_files[selected_index]
              local dropdown_display_name = vb.views["computer_backup_popup"].items[selected_index]
              print(string.format("-- Local Backup: Normalizing slices in PTI file: %s", selected_backup.full_path))
              
              -- Create normalized filename in same directory as source file
              local base_path = selected_backup.full_path:gsub("%.pti$", "_normalized.pti")
              local normalized_path = generate_unique_filename(base_path)
              
              normalize_pti_slices_and_save(selected_backup.full_path, normalized_path, function(success, result)
                if success then
                  -- Refresh the local backup dropdown to show the new file
                  update_computer_backup_dropdown(vb)
                end
              end)
              
            else
              renoise.app():show_status("Please select a valid local backup file to normalize")
            end
          end
        }
      }
    },
    
    -- Save row
    vb:row{
      
      vb:text{
        text = "Save from Renoise",
        width = textWidth, style="strong",font="bold"
      },
      vb:button{
        text = "Save PTI",
        width = polyendButtonWidth,
        tooltip = "Save current instrument/sample as PTI file",
        notifier = function()
          -- Check if use save paths is enabled
          local use_save_paths = vb.views["use_save_paths_checkbox"].value
          local pti_save_path = vb.views["pti_save_path_textfield"].text
          
          if use_save_paths and pti_save_path and pti_save_path ~= "" then
            -- Check if PTI save path is accessible (could be on Polyend device)
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
            
            -- Generate filename based on instrument/sample name
            local song = renoise.song()
            local instrument_name = song.selected_instrument.name or "Untitled"
            local safe_name = instrument_name:gsub("[^%w%-%_]", "_") -- Replace unsafe characters
            local separator = package.config:sub(1,1)
            local base_path = pti_save_path .. separator .. safe_name .. ".pti"
            
            -- Generate unique filename if file already exists
            local unique_path = generate_unique_filename(base_path)
            local final_filename = unique_path:match("[^/\\]+$") or "untitled.pti"
            
            -- Save using pti_savesample_to_path if available
            if pti_savesample_to_path then
              local success = pti_savesample_to_path(unique_path)
              if success then
                -- Create local backup copy if enabled
                if create_local_backup_copy then
                  create_local_backup_copy(unique_path, "Save_PTI")
                end
                
                -- Refresh the dropdowns to show the new file
                update_pti_dropdown(vb)
                update_computer_backup_dropdown(vb)
                
                renoise.app():show_status(string.format("PTI saved to %s", unique_path))
              else
                renoise.app():show_error("Failed to save PTI file")
              end
            else
              -- Fallback to regular save dialog
              renoise.app():show_status("pti_savesample_to_path not available - using dialog")
              pti_savesample()
            end
          else
            -- Use regular save dialog
            pti_savesample()
          end
        end
      },
      vb:button{
        text = "Save WAV",
        width = polyendButtonWidth,
        tooltip = "Save current instrument/sample as WAV file",
        notifier = function()
          -- Check if use save paths is enabled
          local use_save_paths = vb.views["use_save_paths_checkbox"].value
          local wav_save_path = vb.views["wav_save_path_textfield"].text
          
          if use_save_paths and wav_save_path and wav_save_path ~= "" then
            -- Check if WAV save path is accessible (could be on Polyend device)
            local path_exists = check_polyend_path_exists(wav_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ WAV save path not accessible:\n" .. wav_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
            
            -- Generate filename based on instrument/sample name
            local song = renoise.song()
            local instrument_name = song.selected_instrument.name or "Untitled"
            local safe_name = instrument_name:gsub("[^%w%-%_]", "_") -- Replace unsafe characters
            local separator = package.config:sub(1,1)
            local base_path = wav_save_path .. separator .. safe_name .. ".wav"
            
            -- Generate unique filename if file already exists
            local unique_path = generate_unique_filename(base_path)
            local final_filename = unique_path:match("[^/\\]+$") or "untitled.wav"
            
            -- Save WAV file directly
            local success, error_msg = pcall(function()
              local sample = song.selected_sample
              if not sample or not sample.sample_buffer.has_sample_data then
                error("No sample data to save")
              end
              sample.sample_buffer:save_as(unique_path, "wav")
            end)
            
            if success then
              -- Create local backup copy if enabled
              if create_local_backup_copy then
                create_local_backup_copy(unique_path, "Save_WAV")
              end
              
              -- Refresh the dropdowns to show the new file
              update_pti_dropdown(vb)
              update_computer_backup_dropdown(vb)
              
              renoise.app():show_status(string.format("WAV saved to %s", unique_path))
            else
              renoise.app():show_error("Failed to save WAV file: " .. (error_msg or "Unknown error"))
            end
          else
            -- Use regular save function
            pakettiSaveSample("WAV")
          end
        end
      },
      vb:button{
        text = "PTI Drumkit (Stereo)",
        width = polyendButtonWidth *2,
        tooltip = "Combine all samples in current instrument into a single sliced drumkit (stereo if any sample is stereo, otherwise mono)",
        notifier = function()
          -- Check if we should use save paths
          local use_save_paths = vb.views["use_save_paths_checkbox"].value and vb.views["pti_save_path_textfield"].text ~= ""
          
          -- If using save paths, check if PTI save path is accessible (could be on device)
          if use_save_paths then
            local pti_save_path = vb.views["pti_save_path_textfield"].text
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
          end
          
          -- Generate the drumkit (skip save prompt if we're using save paths)
          save_pti_as_drumkit_stereo(use_save_paths)
          
          -- Auto-save if save paths are enabled, otherwise user already handled saving via prompt
          if use_save_paths then
            auto_save_drumkit_if_enabled("Stereo", vb)
          end
        end
      },
      vb:button{
        text = "PTI Drumkit (Mono)",
        width = polyendButtonWidth *2,
        tooltip = "Combine all samples in current instrument into a single sliced mono drumkit (all samples converted to mono)",
        notifier = function()
          -- Check if we should use save paths
          local use_save_paths = vb.views["use_save_paths_checkbox"].value and vb.views["pti_save_path_textfield"].text ~= ""
          
          -- If using save paths, check if PTI save path is accessible (could be on device)
          if use_save_paths then
            local pti_save_path = vb.views["pti_save_path_textfield"].text
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
          end
          
          -- Generate the drumkit (skip save prompt if we're using save paths)
          save_pti_as_drumkit_mono(use_save_paths)
          
          -- Auto-save if save paths are enabled, otherwise user already handled saving via prompt
          if use_save_paths then
            auto_save_drumkit_if_enabled("Mono", vb)
          end
        end
      }
    },
    
    -- Dump row
    vb:row{
      
      vb:text{
        text = "Dump",
        width = textWidth, style="strong",font="bold"
      },
      vb:button{
        text = "Dump PTI to Device",
        width = polyendButtonWidth*2,
        tooltip = "Copy any PTI file from your computer directly to the Polyend device (no conversion)",
        notifier = function()
          -- Call the dump PTI function
          dump_pti_to_device()
        end
      },
      vb:button{
        text = "PTI→Normalize Slices→PTI",
        width = polyendButtonWidth*4,
        tooltip = "Browse for any PTI file, normalize all slices, then save with _normalized suffix",
        notifier = function()
          -- Step 1: Browse for PTI file
          local source_pti = renoise.app():prompt_for_filename_to_read({"*.pti"}, "Select PTI file to normalize slices")
          if not source_pti or source_pti == "" then
            print("-- PTI Normalize: User cancelled PTI file selection")
            return
          end
          
          print("-- PTI Normalize: Selected PTI file: " .. source_pti)
          
          -- Extract filename from path
          local pti_filename = source_pti:match("[^/\\]+$") or "unknown.pti"
          local normalized_filename = pti_filename:gsub("%.pti$", "_normalized.pti")
          
          
          
          -- Create normalized filename in same directory as source file
          local source_dir = source_pti:match("(.+)[/\\][^/\\]*$")
          local separator = package.config:sub(1,1)
          local base_path = source_dir .. separator .. normalized_filename
          local normalized_path = generate_unique_filename(base_path)
          
          -- Call universal normalize function
          normalize_pti_slices_and_save(source_pti, normalized_path, function(success, result)
            if success then
              local final_filename = normalized_path:match("[^/\\]+$") or normalized_filename
              local final_dir = normalized_path:match("(.+)[/\\][^/\\]*$") or ""
              -- Optionally open the folder containing the normalized file
              local open_folder = renoise.app():show_prompt("Normalize Complete", 
                string.format("Normalized PTI saved successfully!\n\nFile: %s\n\nWould you like to open the folder?", final_filename),
                {"Yes", "No"})
              if open_folder == "Yes" then
                renoise.app():open_path(final_dir)
              end
            end
          end)
        end
      }
    },
    
    -- Load samples and generate drumkit row
    vb:row{
      
      vb:text{
        text = "Load & Drumkit",
        width = textWidth, style="strong",font="bold"
      },
      vb:button{
        text = "Load 48→Drumkit Mono",
        width = polyendButtonWidth*2,
        tooltip = "Load 48 samples manually, then generate a mono drumkit PTI",
        notifier = function()
          -- Load 48 samples using the existing pitchbend drumkit loader (synchronous)
          pitchBendDrumkitLoader()
          
          -- Check if we should use save paths
          local use_save_paths = get_use_save_paths() and get_pti_save_path() ~= ""
          
          -- If using save paths, check if PTI save path is accessible (could be on device)
          if use_save_paths then
            local pti_save_path = get_pti_save_path()
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
          end
          
          -- Generate the drumkit (skip save prompt if we're using save paths)
          save_pti_as_drumkit_mono(use_save_paths)
          
          -- Auto-save if save paths are enabled, otherwise user already handled saving via prompt
          if use_save_paths then
            auto_save_drumkit_if_enabled("Mono", nil)
            -- Trigger global refresh if available (from dialog context)
            if polyend_refresh_callback then
              polyend_refresh_callback()
            end
          end
        end
      },
      vb:button{
        text = "Load 48→Drumkit Stereo",
        width = polyendButtonWidth*2,
        tooltip = "Load 48 samples manually, then generate a stereo drumkit PTI",
        notifier = function()
          -- Load 48 samples using the existing pitchbend drumkit loader (synchronous)
          pitchBendDrumkitLoader()
          
          -- Check if we should use save paths
          local use_save_paths = get_use_save_paths() and get_pti_save_path() ~= ""
          
          -- If using save paths, check if PTI save path is accessible (could be on device)
          if use_save_paths then
            local pti_save_path = get_pti_save_path()
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
          end
          
          -- Generate the drumkit (skip save prompt if we're using save paths)
          save_pti_as_drumkit_stereo(use_save_paths)
          
          -- Auto-save if save paths are enabled, otherwise user already handled saving via prompt
          if use_save_paths then
            auto_save_drumkit_if_enabled("Stereo", nil)
            -- Trigger global refresh if available (from dialog context)
            if polyend_refresh_callback then
              polyend_refresh_callback()
            end
          end
        end
      },
      vb:button{
        text = "Load 48 Random→Drumkit Mono",
        width = polyendButtonWidth*3,
        tooltip = "Load 48 random samples, then generate a mono drumkit PTI",
        notifier = function()
          -- Check if we should use save paths and if path is accessible upfront
          local use_save_paths = get_use_save_paths() and get_pti_save_path() ~= ""
          if use_save_paths then
            local pti_save_path = get_pti_save_path()
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
          end
          
          -- Load 48 random samples (asynchronous with ProcessSlicer)
          -- We need to poll for completion since loadRandomDrumkitSamples uses ProcessSlicer
          local original_instrument_index = renoise.song().selected_instrument_index
          loadRandomDrumkitSamples(48)
          
          -- Poll for completion by checking if the target number of samples are loaded
          local timer_function
          timer_function = function()
            -- Check if the loading is complete by seeing if we have 48 samples in the new instrument
            local current_instrument = renoise.song().selected_instrument
            if current_instrument and #current_instrument.samples >= 48 then
              -- Loading completed, remove timer and generate drumkit
              renoise.tool():remove_timer(timer_function)
              
              -- Generate the drumkit (skip save prompt if we're using save paths)
              save_pti_as_drumkit_mono(use_save_paths)
              
              -- Auto-save if save paths are enabled, otherwise user already handled saving via prompt
              if use_save_paths then
                auto_save_drumkit_if_enabled("Mono", nil)
                -- Trigger global refresh if available (from dialog context)
                if polyend_refresh_callback then
                  polyend_refresh_callback()
              end
            end
            end
          end
          if renoise.tool():has_timer(timer_function) then
            renoise.tool():remove_timer(timer_function)
          end
          renoise.tool():add_timer(timer_function, 500) -- Check every 500ms
        end
      },
      vb:button{
        text = "Load 48 Random→Drumkit Stereo",
        width = polyendButtonWidth*3,
        tooltip = "Load 48 random samples, then generate a stereo drumkit PTI",
        notifier = function()
          -- Check if we should use save paths and if path is accessible upfront
          local use_save_paths = get_use_save_paths() and get_pti_save_path() ~= ""
          if use_save_paths then
            local pti_save_path = get_pti_save_path()
            local path_exists = check_polyend_path_exists(pti_save_path)
            if not path_exists then
              renoise.app():show_error("⚠️ PTI save path not accessible:\n" .. pti_save_path .. "\n\nPOLYEND_SAVE_PATH_ERROR_MSG")
              return
            end
          end
          
          -- Load 48 random samples (asynchronous with ProcessSlicer)
          -- We need to poll for completion since loadRandomDrumkitSamples uses ProcessSlicer
          local original_instrument_index = renoise.song().selected_instrument_index
          loadRandomDrumkitSamples(48)
          
          -- Poll for completion by checking if the target number of samples are loaded
          local timer_function
          timer_function = function()
            -- Check if the loading is complete by seeing if we have 48 samples in the new instrument
            local current_instrument = renoise.song().selected_instrument
            if current_instrument and #current_instrument.samples >= 48 then
              -- Loading completed, remove timer and generate drumkit
              renoise.tool():remove_timer(timer_function)
              
              -- Generate the drumkit (skip save prompt if we're using save paths)
              save_pti_as_drumkit_stereo(use_save_paths)
              
              -- Auto-save if save paths are enabled, otherwise user already handled saving via prompt
              if use_save_paths then
                auto_save_drumkit_if_enabled("Stereo", nil)
                -- Trigger global refresh if available (from dialog context)
                if polyend_refresh_callback then
                  polyend_refresh_callback()
              end
            end
            end
          end
          if renoise.tool():has_timer(timer_function) then
            renoise.tool():remove_timer(timer_function)
          end
          renoise.tool():add_timer(timer_function, 500) -- Check every 500ms
        end
      }
    },
    
    -- Convert row
    vb:row{
      
      vb:text{
        text = "Convert",
        width = textWidth, style="strong",font="bold"
      },
      vb:button{
        text = "RX2→PTI",
        width = polyendButtonWidth*2,
        tooltip = "Convert RX2 file to PTI format",
        notifier = function()
          -- Call the existing RX2 to PTI conversion function
          rx2_to_pti_convert()
        end
      }
    },
    
    -- Backup row
    vb:row{
      
      vb:text{
        text = "Backup",
        width = textWidth, style="strong",font="bold"
      },
      vb:button{
        text = "Backup to Folder",
        width = polyendButtonWidth*2,
        tooltip = "Create a complete backup of the entire Polyend device folder structure including all files and hidden files",
        notifier = function()
          -- Call the backup function
          backup_polyend_tracker()
        end
      }
    },
    
    -- Firmware row
    vb:row{
      
      vb:text{
        text = "Firmware",
        width = textWidth, style="strong",font="bold"
      },
      vb:popup{
        id = "firmware_device_popup",
        items = {"Tracker+", "Tracker", "Mini"},
        value = 1,
        width = polyendButtonWidth*2,
        tooltip = "Select which Polyend device to get firmware for"
      },
      vb:button{
        text = "Open Downloads",
        width = polyendButtonWidth*2,
        tooltip = "Open the firmware downloads page for the selected device",
        notifier = function()
          local selected_device = vb.views["firmware_device_popup"].value
          local firmware_urls = {
            "https://polyend.com/downloads/tracker-plus-downloads/",  -- Tracker+
            "https://polyend.com/downloads/tracker-downloads/",       -- Tracker
            "https://polyend.com/downloads/tracker-mini-downloads/"   -- Mini
          }
          
          local url = firmware_urls[selected_device]
          if url then
            print(string.format("-- Polyend Buddy: Opening firmware downloads page: %s", url))
            renoise.app():open_url(url)
            renoise.app():show_status("Opened firmware downloads page in browser")
          else
            renoise.app():show_status("Error: Invalid device selection")
          end
        end
      },
      vb:button{
        text = "Download Firmware",
        width = polyendButtonWidth*2,
        tooltip = "Automatically find, download and extract the latest firmware for the selected device",
        notifier = function()
          local selected_device = vb.views["firmware_device_popup"].value
          local device_names = {"Tracker+", "Tracker", "Mini"}
          local firmware_urls = {
            "https://polyend.com/downloads/tracker-plus-downloads/",  -- Tracker+
            "https://polyend.com/downloads/tracker-downloads/",       -- Tracker
            "https://polyend.com/downloads/tracker-mini-downloads/"   -- Mini
          }
          
          local device_name = device_names[selected_device]
          local page_url = firmware_urls[selected_device]
          
          if not device_name or not page_url then
            renoise.app():show_status("Error: Invalid device selection")
            return
          end
          
          print(string.format("-- Polyend Buddy: Starting automatic firmware download for %s", device_name))
          renoise.app():show_status(string.format("Searching for %s firmware...", device_name))
          
          -- Scrape the download URL from the page
          local download_url = scrape_firmware_url(device_name, page_url)
          
          if not download_url then
            -- Fallback: open the downloads page if scraping failed
            renoise.app():show_error(string.format("Could not automatically find %s firmware download URL.\n\nOpening downloads page instead.", device_name))
            renoise.app():open_url(page_url)
            return
          end
          
          -- Download and extract the firmware
          local firmware_path = download_and_extract_firmware(device_name, download_url)
          
          if not firmware_path then
            -- Fallback: open the downloads page if download failed
            renoise.app():show_error(string.format("Firmware download failed for %s.\n\nOpening downloads page for manual download.", device_name))
            renoise.app():open_url(page_url)
          else
            -- Success! Ask user what to do next
            local user_choice = renoise.app():show_prompt("Firmware Downloaded", 
              string.format("%s firmware downloaded and extracted successfully!\n\nWhat would you like to do next?", device_name),
              {"Open in Temp Folder", "Send to Polyend Device", "Cancel"})
            
            if user_choice == "Open in Temp Folder" then
              -- Open the temp folder (original behavior)
              renoise.app():open_path(firmware_path)
              print(string.format("-- Firmware Download: User chose to open temp folder: %s", firmware_path))
            elseif user_choice == "Send to Polyend Device" then
              -- Copy firmware to Polyend device
              print(string.format("-- Firmware Download: User chose to send to device"))
              copy_firmware_to_device(firmware_path, device_name)
            else
              -- User cancelled, do nothing
              print("-- Firmware Download: User cancelled post-download action")
            end
          end
        end
      }
    },
    
    -- Palettes row
    vb:row{
      
      vb:text{
        text = "Sample Packs",
        width = textWidth, style="strong",font="bold"
      },
      vb:button{
        text = "Open Polyend Palettes / Sample Packs",
        width = polyendButtonWidth*6,
        tooltip = "Open the Polyend Palettes sample packs store in your browser",
        notifier = function()
          local palettes_url = "https://polyend.com/palettes/"
          print(string.format("-- Polyend Buddy: Opening Palettes store: %s", palettes_url))
          renoise.app():open_url(palettes_url)
          renoise.app():show_status("Opened Polyend Palettes sample packs store in browser")
        end
      }
    },
    
    -- Other action buttons
    vb:row{
      
      vb:button{
        text = "Refresh",
        width = polyendButtonWidth*2,
        tooltip = "Rescan the folder for PTI files or reconnect Polyend device",
        notifier = function()
          if polyend_buddy_root_path and polyend_buddy_root_path ~= "" then
            print("-- Polyend Buddy: Refreshing connection...")
            update_pti_dropdown(vb)
            update_computer_pti_dropdown(vb)
            update_computer_backup_dropdown(vb)
            -- Status message is handled by update_pti_dropdown
          else
            renoise.app():show_status("Please select a root folder first")
          end
        end
      },
    },
    

    -- Close button
    vb:row{
      vb:button{
        text = "Close",
        width = polyendButtonWidth*2,
        notifier = function()
            if dialog then
    dialog:close()
    dialog = nil
    polyend_refresh_callback = nil  -- Clear global refresh callback
          end
        end
      }
    },
        -- Status and file count (moved to bottom)
        vb:row{
          vb:text{
            id = "pti_count_text",
            text = "⚠️ " .. POLYEND_DEVICE_NOT_CONNECTED_MSG,
            font = "italic", font="bold", style="strong"
          }
        },
  }
end

-- Main function to show the Polyend Buddy dialog
function show_polyend_buddy_dialog()
  -- Close existing dialog if open
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  -- Initialize root path from preferences
  initialize_polyend_root_path()
  initialize_computer_pti_path()
  initialize_save_paths()
  
  local vb = renoise.ViewBuilder()
  
  -- Set up global refresh callback for operations outside dialog context
  polyend_refresh_callback = function()
    update_pti_dropdown(vb)
    update_computer_pti_dropdown(vb)
    update_computer_backup_dropdown(vb)
    update_section_visibility(vb)
  end
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog(
    "Polyend Buddy - PTI File Browser", 
    create_polyend_buddy_dialog(vb), 
    keyhandler
  )
  
  -- Check connection status on startup with retry logic
  if polyend_buddy_root_path and polyend_buddy_root_path ~= "" then
    local path_exists = check_polyend_path_exists(polyend_buddy_root_path)
    if path_exists then
      update_pti_dropdown(vb)
    else
      -- First attempt failed, show status and try once more after 1 second
      renoise.app():show_status("Polyend device not found - retrying in 1 second...")
      print("-- Polyend Buddy: Polyend device not connected at startup, retrying in 1 second...")
      
      -- Add timer for single retry attempt
      local retry_timer
      retry_timer = function()
        -- Remove this timer (single use only)
        if renoise.tool():has_timer(retry_timer) then
          renoise.tool():remove_timer(retry_timer)
        end
        
        local path_exists_retry = check_polyend_path_exists(polyend_buddy_root_path)
        if path_exists_retry then
          print("-- Polyend Buddy: Device found on retry!")
          update_pti_dropdown(vb)
          renoise.app():show_status("Polyend device connected")
        else
          -- Final failure after retry
      renoise.app():show_status(POLYEND_DEVICE_NOT_CONNECTED_TITLE .. " - check path: " .. polyend_buddy_root_path)
          print("-- Polyend Buddy: Polyend device still not connected after retry")
        end
      end
      
      -- Set timer for 1 second retry (check if exists first)
      if renoise.tool():has_timer(retry_timer) then
        renoise.tool():remove_timer(retry_timer)
      end
      renoise.tool():add_timer(retry_timer, 1000)
    end
  else
    -- No path configured - don't update dropdown, keep default message
    renoise.app():show_status("Please configure Polyend device root path")
  end
  
  -- Check local PTI path on startup
  if computer_pti_path and computer_pti_path ~= "" then
    local computer_path_exists = check_polyend_path_exists(computer_pti_path)
    if computer_path_exists then
      update_computer_pti_dropdown(vb)
    else
      print("-- Local PTI: Local PTI path not accessible at startup: " .. computer_pti_path)
    end
  else
    print("-- Local PTI: No local PTI path configured")
  end
  
  -- Check local backup path on startup
  local backup_path = get_computer_backup_path()
  if backup_path and backup_path ~= "" then
    local backup_path_exists = check_polyend_path_exists(backup_path)
    if backup_path_exists then
      update_computer_backup_dropdown(vb)
    else
      print("-- Local Backup: Local backup path not accessible at startup: " .. backup_path)
    end
  else
    print("-- Local Backup: No local backup path configured")
  end
end

--------------------------------------------------------------------------------
renoise.tool():add_keybinding{name="Global:Paketti:Polyend Buddy (PTI File Browser)",invoke = show_polyend_buddy_dialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/Work in Progress:Polyend:Polyend Buddy (PTI File Browser)",invoke = show_polyend_buddy_dialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Xperimental/Work in Progress:Polyend:Polyend Buddy (PTI File Browser)",invoke=show_polyend_buddy_dialog}