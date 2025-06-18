-- PakettiPolyendSuite.lua
-- RX2 to PTI Conversion Tool
-- Combines RX2 loading with PTI export functionality

local bit = require("bit")
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

-- Build a 392-byte header according to .pti spec
local function build_header(inst)
  local header = string.rep("\0", 392) -- Start with 392 zero bytes
  local pos = 1
  
  -- Function to write bytes at specific position
  local function write_at(offset, data)
    local len = #data
    header = header:sub(1, offset-1) .. data .. header:sub(offset + len)
  end
  
  -- File ID and version (offset 0-7)
  write_at(1, "TI")                       -- offset 0-1: ASCII marker "TI"
  write_at(3, string.char(1,0,1,5))       -- offset 2-5: version 1.0.1.5
  write_at(7, string.char(0,1))           -- offset 6-7: flags
  
  -- Wavetable flag (offset 20)  
  write_at(21, string.char(inst.is_wavetable and 1 or 0))
  
  -- Instrument name (offset 21-51, 31 bytes)
  local name = (inst.name or ""):sub(1,31)
  write_at(22, name .. string.rep("\0", 31-#name))
  
  -- Sample length (offset 60-63, 4 bytes little-endian)
  local length_bytes = string.char(
    bit.band(inst.sample_length, 0xFF),
    bit.band(bit.rshift(inst.sample_length, 8), 0xFF),
    bit.band(bit.rshift(inst.sample_length, 16), 0xFF),
    bit.band(bit.rshift(inst.sample_length, 24), 0xFF)
  )
  write_at(61, length_bytes)
  
  -- Map Renoise loop mode to PTI loop mode
  local pti_loop_mode = 0 -- Default: OFF
  local renoise_loop_modes = {
    [renoise.Sample.LOOP_MODE_OFF] = 0,
    [renoise.Sample.LOOP_MODE_FORWARD] = 1,
    [renoise.Sample.LOOP_MODE_REVERSE] = 2,
    [renoise.Sample.LOOP_MODE_PING_PONG] = 3
  }
  
  if inst.loop_mode and renoise_loop_modes[inst.loop_mode] then
    pti_loop_mode = renoise_loop_modes[inst.loop_mode]
  end
  
  -- Write loop mode (offset 76, read at 77 in import)
  write_at(77, string.char(pti_loop_mode))
  print(string.format("-- build_header: Writing loop mode %d at offset 76", pti_loop_mode))
  
  -- Loop points - fix offsets to match what import expects
  -- Import reads from offset 80 and 82, so write to offset 80 and 82
  local loop_start = math.floor(inst.loop_start * 65535 / inst.sample_length)
  local loop_end = math.floor(inst.loop_end * 65535 / inst.sample_length)
  
  print(string.format("-- build_header: Converting loop points: start=%d->%d, end=%d->%d", 
    inst.loop_start, loop_start, inst.loop_end, loop_end))
  
  -- Write loop start at offset 81 (read by read_uint16_le(header, 80))
  write_at(81, string.char(
    bit.band(loop_start, 0xFF),
    bit.band(bit.rshift(loop_start, 8), 0xFF)
  ))
  
  -- Write loop end at offset 83 (read by read_uint16_le(header, 82))  
  write_at(83, string.char(
    bit.band(loop_end, 0xFF),
    bit.band(bit.rshift(loop_end, 8), 0xFF)
  ))
  
  -- Write slice markers (offset 280-375, 48 markers × 2 bytes each)
  local slice_markers = inst.slice_markers or {}
  local num_slices = math.min(48, #slice_markers)
  
  print(string.format("-- build_header: Writing %d slices (from %d total)", num_slices, #slice_markers))
  
  for i = 1, num_slices do
    local slice_pos = slice_markers[i]
    -- Simple proportion: frame_position / total_frames * 65535
    local slice_value = math.floor((slice_pos / inst.sample_length) * 65535)
    local offset = 280 + (i - 1) * 2
    write_at(offset + 1, string.char(
      bit.band(slice_value, 0xFF),
      bit.band(bit.rshift(slice_value, 8), 0xFF)
    ))
    print(string.format("-- Export slice %02d: frame=%d/%d, value=%d (0x%04X)", 
      i, slice_pos, inst.sample_length, slice_value, slice_value))
  end
  
  -- Write slice count (offset 376)
  write_at(377, string.char(num_slices))
  print(string.format("-- build_header: Wrote slice count %d at offset 376", num_slices))
  
  return header
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

  -- Prompt for PTI save location
  local pti_filename = renoise.app():prompt_for_filename_to_write(".pti", "Save converted PTI as...")
  if pti_filename == "" then
    print("-- PTI export cancelled by user")
    return
  end

  print("-- PTI export filename: " .. pti_filename)

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

  -- Write header and get its size for verification
  local header = build_header(data)
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

  -- Show final status
  print("-- RX2 to PTI conversion completed successfully!")
  if original_slice_count > 0 then
    if original_slice_count > 48 then
      renoise.app():show_status(string.format("RX2 converted to PTI with 48 slices (limited from %d)", original_slice_count))
    else
      renoise.app():show_status(string.format("RX2 converted to PTI with %d slices", original_slice_count))
    end
  else
    renoise.app():show_status("RX2 converted to PTI successfully")
  end
end

--------------------------------------------------------------------------------
-- Polyend Buddy Dialog
-- File browser for PTI files from Polyend Tracker device
--------------------------------------------------------------------------------

local polyend_buddy_dialog = nil
local polyend_buddy_root_path = ""
local polyend_buddy_pti_files = {}

-- Function to recursively scan folder for PTI files
local function scan_for_pti_files(root_path)
  local pti_files = {}
  local separator = package.config:sub(1,1)
  
  local function scan_directory(path, relative_path)
    local files = os.filenames(path, "*")
    local dirs = os.dirnames(path)
    
    -- Scan files in current directory
    for _, filename in ipairs(files) do
      if filename:lower():match("%.pti$") then
        local relative_file_path = relative_path == "" and filename or (relative_path .. separator .. filename)
        local full_path = path .. separator .. filename
        table.insert(pti_files, {
          display_name = relative_file_path,
          full_path = full_path
        })
      end
    end
    
    -- Recursively scan subdirectories  
    for _, dirname in ipairs(dirs) do
      local sub_path = path .. separator .. dirname
      local sub_relative = relative_path == "" and dirname or (relative_path .. separator .. dirname)
      scan_directory(sub_path, sub_relative)
    end
  end
  
  if root_path and root_path ~= "" then
    scan_directory(root_path, "")
  end
  
  return pti_files
end

-- Function to update the dropdown with found PTI files
local function update_pti_dropdown(vb)
  polyend_buddy_pti_files = scan_for_pti_files(polyend_buddy_root_path)
  
  local dropdown_items = {"<No PTI files found>"}
  
  if #polyend_buddy_pti_files > 0 then
    dropdown_items = {}
    for _, pti_file in ipairs(polyend_buddy_pti_files) do
      table.insert(dropdown_items, pti_file.display_name)
    end
    table.sort(dropdown_items)
  end
  
  -- Update dropdown
  if vb.views["pti_files_popup"] then
    vb.views["pti_files_popup"].items = dropdown_items
    vb.views["pti_files_popup"].value = 1
  end
  
  -- Update status text
  if vb.views["pti_count_text"] then
    vb.views["pti_count_text"].text = string.format("Found %d PTI files", #polyend_buddy_pti_files)
  end
  
  print(string.format("-- Polyend Buddy: Found %d PTI files in %s", #polyend_buddy_pti_files, polyend_buddy_root_path))
end

-- Function to create the Polyend Buddy dialog content
local function create_polyend_buddy_dialog(vb)
  return vb:column{
    margin = 10,
    spacing = 8,
    
    -- Title
    vb:text{
      text = "Polyend Buddy - PTI File Browser",
      font = "bold"
    },
    
    -- Root folder selection
    vb:row{
      spacing = 5,
      vb:text{
        text = "Root Folder:",
        width = 80
      },
      vb:textfield{
        id = "root_path_textfield",
        text = polyend_buddy_root_path,
        width = 400,
        tooltip = "Path to your Polyend Tracker device or folder containing PTI files"
      },
      vb:button{
        text = "Browse",
        notifier = function()
          local selected_path = renoise.app():prompt_for_path("Select Polyend Tracker Folder")
          if selected_path and selected_path ~= "" then
            polyend_buddy_root_path = selected_path
            vb.views["root_path_textfield"].text = selected_path
            update_pti_dropdown(vb)
          end
        end
      }
    },
    
    -- Status and file count
    vb:row{
      vb:text{
        id = "pti_count_text",
        text = "Found 0 PTI files",
        font = "italic"
      }
    },
    
    -- PTI files dropdown
    vb:row{
      spacing = 5,
      vb:text{
        text = "PTI Files:",
        width = 80
      },
      vb:popup{
        id = "pti_files_popup",
        items = {"<No PTI files found>"},
        width = 400,
        tooltip = "Select a PTI file to load"
      }
    },
    
    -- Action buttons
    vb:row{
      spacing = 10,
      vb:button{
        text = "Refresh",
        tooltip = "Rescan the folder for PTI files",
        notifier = function()
          if polyend_buddy_root_path and polyend_buddy_root_path ~= "" then
            update_pti_dropdown(vb)
            renoise.app():show_status("Refreshed PTI file list")
          else
            renoise.app():show_status("Please select a root folder first")
          end
        end
      },
      vb:button{
        text = "Load PTI",
        tooltip = "Load the selected PTI file",
        notifier = function()
          local selected_index = vb.views["pti_files_popup"].value
          
          if #polyend_buddy_pti_files == 0 then
            renoise.app():show_status("No PTI files found to load")
            return
          end
          
          if selected_index >= 1 and selected_index <= #polyend_buddy_pti_files then
            local selected_pti = polyend_buddy_pti_files[selected_index]
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
        text = "Open Folder", 
        tooltip = "Open the selected PTI file's folder in system file browser",
        notifier = function()
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
      }
    },
    
    -- Close button
    vb:row{
      vb:button{
        text = "Close",
        notifier = function()
          if polyend_buddy_dialog then
            polyend_buddy_dialog:close()
            polyend_buddy_dialog = nil
          end
        end
      }
    }
  }
end

-- Key handler for the Polyend Buddy dialog
local function polyend_buddy_key_handler(dialog, key)
  if key.modifiers == "" and key.name == "esc" then
    dialog:close()
    polyend_buddy_dialog = nil
    return nil
  else
    return key
  end
end

-- Main function to show the Polyend Buddy dialog
function show_polyend_buddy_dialog()
  -- Close existing dialog if open
  if polyend_buddy_dialog and polyend_buddy_dialog.visible then
    polyend_buddy_dialog:close()
    polyend_buddy_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  polyend_buddy_dialog = renoise.app():show_custom_dialog(
    "Polyend Buddy", 
    create_polyend_buddy_dialog(vb), 
    polyend_buddy_key_handler
  )
  
  -- Initial scan if path is already set
  if polyend_buddy_root_path and polyend_buddy_root_path ~= "" then
    update_pti_dropdown(vb)
  end
end

--------------------------------------------------------------------------------
-- Keybindings and Menu Entries for Polyend Buddy
--------------------------------------------------------------------------------

-- Add keybinding for Polyend Buddy dialog
renoise.tool():add_keybinding{
  name = "Global:Paketti:Polyend Buddy (PTI File Browser)",
  invoke = show_polyend_buddy_dialog
}

-- Add menu entry for Polyend Buddy dialog  
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Instruments..:File Formats..:Polyend Buddy (PTI File Browser)",
  invoke = show_polyend_buddy_dialog
}


renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets..:Polyend Buddy (PTI File Browser)",
invoke=show_polyend_buddy_dialog

}