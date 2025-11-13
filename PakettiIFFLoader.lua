--[[============================================================================
main.lua — IFF (8SVX/16SV) → WAV converter with debug printing and auto-loading into new instruments
============================================================================]]--

-- Get proper path separator for current OS (\ for Windows, / for Unix)
local separator = package.config:sub(1,1)

-- Helper: debug print
local function debug_print(...)
  print("[IFF→WAV]", ...)
end

-- Utility: extract filename from path
local function filename_from_path(path)
  return path:match("[^/\\]+$")
end

-- Utility: extract directory from path
local function directory_from_path(path)
  return path:match("^(.*)[/\\][^/\\]*$") or "."
end

-- Utility: change file extension
local function change_extension(path, new_ext)
  local name_without_ext = path:match("^(.*)%.[^.]*$") or path
  return name_without_ext .. "." .. new_ext
end

-- read a big-endian unsigned 32-bit integer
local function read_be_u32(f)
  local bytes = f:read(4)
  assert(bytes and #bytes == 4, "Unexpected EOF in read_be_u32")
  local b1,b2,b3,b4 = bytes:byte(1,4)
  return b1*2^24 + b2*2^16 + b3*2^8 + b4
end

-- read a big-endian unsigned 16-bit integer
local function read_be_u16(f)
  local bytes = f:read(2)
  assert(bytes and #bytes == 2, "Unexpected EOF in read_be_u16")
  local b1,b2 = bytes:byte(1,2)
  return b1*2^8 + b2
end

-- skip pad byte if chunk size is odd
local function skip_pad(f, size)
  if size % 2 ~= 0 then
    f:seek("cur", 1)
  end
end

-- convert IFF (8SVX or 16SV) or raw 8-bit sample to buffer data
function convert_iff_to_buffer(iff_path)
  debug_print("Opening IFF file:", iff_path)
  local f, err = io.open(iff_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end

  -- peek header
  local header = f:read(4)
  if header ~= "FORM" then
    -- fallback: raw 8-bit PCM @ 16574 Hz
    debug_print("No FORM header, falling back to raw import")
    f:seek("set", 0)
    local raw = f:read("*all")
    f:close()

    assert(raw and #raw > 0, "Empty file in raw fallback")
    local buf = {}
    for i = 1, #raw do
      local b = raw:byte(i)
      local s8 = (b < 128) and b or (b - 256)
      buf[i] = s8 / 128.0
    end
    return buf, 16574
  end

  -- proper IFF FORM
  local form_size = read_be_u32(f)
  local form_type = f:read(4)
  assert(form_type == "8SVX" or form_type == "16SV",
    "Unsupported IFF type: " .. tostring(form_type))

  local sample_rate, raw_data
  local chunk_count = 0

  while true do
    local hdr = f:read(4)
    if not hdr or #hdr < 4 then break end
    local size = read_be_u32(f)
    chunk_count = chunk_count + 1
    debug_print(string.format("Chunk %d: '%s' (%d bytes)",
      chunk_count, hdr, size))

    if hdr == "VHDR" then
      -- skip oneShotHiSamples, repeatHiSamples, samplesPerHiCycle (3×4 bytes)
      f:seek("cur", 12)
      -- read 16-bit sample rate
      sample_rate = read_be_u16(f)
      debug_print("VHDR sample rate:", sample_rate)
      -- skip ctOctave (1), sCompression (1), volume (4)
      f:seek("cur", size - 14)
    elseif hdr == "BODY" then
      raw_data = f:read(size)
      debug_print("BODY length:", raw_data and #raw_data)
    else
      f:seek("cur", size)
      debug_print("Skipped chunk:", hdr)
    end

    skip_pad(f, size)
  end

  f:close()
  assert(sample_rate and raw_data,
    "Missing VHDR or BODY chunk in IFF")

  debug_print(string.format(
    "Chunks found: %d, Sample rate: %d, Raw bytes: %d",
    chunk_count, sample_rate, #raw_data))

  -- Decode samples into normalized floats
  local buffer_data = {}
  if form_type == "8SVX" then
    for i = 1, #raw_data do
      local b = raw_data:byte(i)
      local s8 = (b < 128) and b or (b - 256)
      buffer_data[i] = s8 / 128.0
    end

  else -- "16SV"
    assert(#raw_data % 2 == 0, "Odd byte count in 16SV body")
    local idx = 1
    for i = 1, #raw_data, 2 do
      local hi, lo = raw_data:byte(i, i+1)
      local val = hi * 256 + lo
      if val >= 0x8000 then val = val - 0x10000 end
      buffer_data[idx] = val / 32768.0
      idx = idx + 1
    end
  end

  debug_print("Converted frames:", #buffer_data)
  return buffer_data, sample_rate
end

-- Track failed imports
local failed_imports = {}

-- File-import hook
local function loadIFFSample(file_path)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local lower = file_path:lower()
  if not (lower:match("%.iff$") or lower:match("%.8svx$")
      or lower:match("%.16sv$")) then
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return nil
  end

  print("---------------------------------")
  debug_print("Import hook for:", file_path)

  local buffer_data, sample_rate
  local ok, err = pcall(function()
    buffer_data, sample_rate = convert_iff_to_buffer(file_path)
  end)
  if not ok then
    failed_imports[file_path] = err
    print(string.format(
      "Failed to convert IFF file: %s (Error: %s)", file_path, err))
    renoise.app():show_status("IFF conversion failed")
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return nil
  end

  -- Insert into Renoise
  local song = renoise.song()
  local idx = song.selected_instrument_index
  if not idx then
    renoise.app():show_status("Select an instrument first")
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return nil
  end

  local new_idx = idx + 1
  song:insert_instrument_at(new_idx)
  song.selected_instrument_index = new_idx
  local inst = song.instruments[new_idx]
  local name = filename_from_path(file_path)
  inst.name = name
  if #inst.samples < 1 then inst:insert_sample_at(1) end
  local sample = inst.samples[1]
  sample.name = name

  local load_ok, load_err = pcall(function()
    local bit_depth = (#buffer_data > 0 and math.floor(#buffer_data / #buffer_data)) and 
                      ((lower:match("%.16sv$") and 16) or 8) or 8
    -- Actually pick bit-depth from form_type:
    load_bit_depth = (lower:match("%.16sv$") and 16) or 8

    sample.sample_buffer:create_sample_data(
      sample_rate, load_bit_depth, 1, #buffer_data)
    sample.sample_buffer:prepare_sample_data_changes()
    for i = 1, #buffer_data do
      sample.sample_buffer:set_sample_data(1, i, buffer_data[i])
    end
    sample.sample_buffer:finalize_sample_data_changes()
  end)

  if not load_ok then
    failed_imports[file_path] = load_err
    print(string.format(
      "Failed to load IFF file: %s (Error: %s)", file_path, load_err))
    song:delete_instrument_at(new_idx)
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return nil
  end

  renoise.app():show_status(
    string.format("Loaded %s at %d Hz", name, sample_rate))
  print(string.format("Successfully loaded: %s", file_path))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  return nil
end

-- Function to prompt for IFF file and load it
function loadIFFSampleFromDialog()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local file_path = renoise.app():prompt_for_filename_to_read(
    {"*.iff", "*.8svx", "*.16sv"}, 
    "Load IFF Sample File"
  )
  
  if file_path and file_path ~= "" then
    loadIFFSample(file_path)
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_file_import_hook{
  name       = "IFF (8SVX+16SV) → WAV converter",
  category   = "sample",
  extensions = {"iff","8svx","16sv"},
  invoke     = loadIFFSample
}

renoise.tool():add_keybinding{name = "Global:Paketti:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}


-- Helper function to get IFF files from directory
local function getIFFFiles(dir)
  local files = {}
  local command
  
  -- Use OS-specific commands to list all files recursively
  if package.config:sub(1,1) == "\\" then  -- Windows
      command = string.format('dir "%s" /b /s', dir:gsub('"', '\\"'))
  else  -- macOS and Linux
      command = string.format("find '%s' -type f", dir:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  if handle then
      for line in handle:lines() do
          local lower_path = line:lower()
          if lower_path:match("%.iff$") or lower_path:match("%.8svx$") or lower_path:match("%.16sv$") then
              table.insert(files, line)
          end
      end
      handle:close()
  end
  
  return files
end

function loadRandomIFF(num_samples)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Prompt the user to select a folder
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing IFF/8SVX Files")
  if not folder_path then
      renoise.app():show_status("No folder selected.")
      -- Restore AutoSamplify monitoring state
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      return nil
  end

  -- Get all IFF files
  local iff_files = getIFFFiles(folder_path)
  
  -- Check if there are enough files to choose from
  if #iff_files == 0 then
      renoise.app():show_status("No IFF/8SVX files found in the selected folder.")
      -- Restore AutoSamplify monitoring state
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      return nil
  end

  -- Load the specified number of samples into separate instruments
  for i = 1, math.min(num_samples, #iff_files) do
      -- Select a random file from the list
      local random_index = math.random(1, #iff_files)
      local selected_file = iff_files[random_index]
      
      -- Remove the selected file from the list to avoid duplicates
      table.remove(iff_files, random_index)

      -- Extract the file name without the extension for naming
      local file_name = selected_file:match("([^/\\]+)%.%w+$")

      print("---------------------------------")
      debug_print("Loading random IFF file:", selected_file)

      -- Convert the IFF file to buffer data
      local buffer_data, sample_rate
      local ok, err = pcall(function()
          buffer_data, sample_rate = convert_iff_to_buffer(selected_file)
      end)

      if ok then
          local song = renoise.song()
          local current_idx = song.selected_instrument_index
          local new_idx = current_idx + 1
          song:insert_instrument_at(new_idx)
          song.selected_instrument_index = new_idx

          local inst = song.instruments[new_idx]
          inst.name = file_name
          if #inst.samples < 1 then inst:insert_sample_at(1) end
          local sample = inst.samples[1]
          sample.name = file_name

          local load_ok, load_err = pcall(function()
              sample.sample_buffer:create_sample_data(sample_rate, 8, 1, #buffer_data)
              sample.sample_buffer:prepare_sample_data_changes()
              for j = 1, #buffer_data do
                  sample.sample_buffer:set_sample_data(1, j, buffer_data[j])
              end
              sample.sample_buffer:finalize_sample_data_changes()
          end)

          if load_ok then
              debug_print("Successfully loaded random IFF file into instrument [" .. new_idx .. "]:", file_name)
              renoise.app():show_status(string.format("Loaded IFF file %d/%d: %s", i, num_samples, file_name))
          else
              print(string.format("Failed to load IFF file: %s (Error: %s)", selected_file, load_err))
              song:delete_instrument_at(new_idx)
          end
      else
          print(string.format("Failed to convert IFF file: %s (Error: %s)", selected_file, err))
      end
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end



-- write a little-endian unsigned 32-bit integer
local function write_le_u32(f, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  f:write(string.char(b1, b2, b3, b4))
end

-- write a little-endian unsigned 16-bit integer
local function write_le_u16(f, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  f:write(string.char(b1, b2))
end

-- write WAV file from buffer data
local function write_wav_file(output_path, buffer_data, sample_rate)
  debug_print("Writing WAV file:", output_path)
  local f, err = io.open(output_path, "wb")
  if not f then
    error("Could not create WAV file: " .. err)
  end

  local num_samples = #buffer_data
  local bits_per_sample = 16
  local num_channels = 1
  local byte_rate = sample_rate * num_channels * bits_per_sample / 8
  local block_align = num_channels * bits_per_sample / 8
  local data_size = num_samples * bits_per_sample / 8
  local file_size = 36 + data_size

  -- RIFF header
  f:write("RIFF")
  write_le_u32(f, file_size)
  f:write("WAVE")

  -- fmt chunk
  f:write("fmt ")
  write_le_u32(f, 16) -- chunk size
  write_le_u16(f, 1)  -- PCM format
  write_le_u16(f, num_channels)
  write_le_u32(f, sample_rate)
  write_le_u32(f, byte_rate)
  write_le_u16(f, block_align)
  write_le_u16(f, bits_per_sample)

  -- data chunk
  f:write("data")
  write_le_u32(f, data_size)

  -- write sample data (convert from normalized float to 16-bit signed int)
  for i = 1, num_samples do
    local sample_value = buffer_data[i]
    -- clamp to [-1.0, 1.0] and convert to 16-bit signed integer
    sample_value = math.max(-1.0, math.min(1.0, sample_value))
    local int_value = math.floor(sample_value * 32767 + 0.5)
    if int_value > 32767 then int_value = 32767 end
    if int_value < -32768 then int_value = -32768 end
    write_le_u16(f, int_value < 0 and (int_value + 65536) or int_value)
  end

  f:close()
  debug_print("WAV file written successfully")
end

-- Function to convert IFF to WAV without loading into Renoise
function convertIFFToWAV()
  local file_path = renoise.app():prompt_for_filename_to_read(
    {"*.iff", "*.8svx", "*.16sv"}, 
    "Select IFF File to Convert to WAV"
  )
  
  if not file_path or file_path == "" then
    renoise.app():show_status("No file selected")
    return
  end

  print("---------------------------------")
  debug_print("Converting IFF to WAV:", file_path)

  local buffer_data, sample_rate
  local ok, err = pcall(function()
    buffer_data, sample_rate = convert_iff_to_buffer(file_path)
  end)

  if not ok then
    print(string.format("Failed to convert IFF file: %s (Error: %s)", file_path, err))
    renoise.app():show_status("IFF conversion failed: " .. err)
    return
  end

  -- Create output WAV path in the same directory
  local output_path = change_extension(file_path, "wav")
  
  local write_ok, write_err = pcall(function()
    write_wav_file(output_path, buffer_data, sample_rate)
  end)

  if write_ok then
    local filename = filename_from_path(output_path)
    renoise.app():show_status(string.format("Converted to WAV: %s", filename))
    print(string.format("Successfully converted: %s -> %s", file_path, output_path))
  else
    print(string.format("Failed to write WAV file: %s (Error: %s)", output_path, write_err))
    renoise.app():show_status("WAV write failed: " .. write_err)
  end
end


renoise.tool():add_keybinding{name = "Global:Paketti:Convert IFF to WAV...",invoke = convertIFFToWAV}

-- WAV to IFF conversion functions

-- read a little-endian unsigned 32-bit integer
local function read_le_u32(f)
  local bytes = f:read(4)
  assert(bytes and #bytes == 4, "Unexpected EOF in read_le_u32")
  local b1,b2,b3,b4 = bytes:byte(1,4)
  return b4*2^24 + b3*2^16 + b2*2^8 + b1
end

-- read a little-endian unsigned 16-bit integer
local function read_le_u16(f)
  local bytes = f:read(2)
  assert(bytes and #bytes == 2, "Unexpected EOF in read_le_u16")
  local b1,b2 = bytes:byte(1,2)
  return b2*2^8 + b1
end

-- write a big-endian unsigned 32-bit integer
local function write_be_u32(f, value)
  local b4 = value % 256
  local b3 = math.floor(value / 256) % 256
  local b2 = math.floor(value / 65536) % 256
  local b1 = math.floor(value / 16777216) % 256
  f:write(string.char(b1, b2, b3, b4))
end

-- write a big-endian unsigned 16-bit integer
local function write_be_u16(f, value)
  local b2 = value % 256
  local b1 = math.floor(value / 256) % 256
  f:write(string.char(b1, b2))
end

-- convert WAV file to buffer data
function convert_wav_to_buffer(wav_path)
  debug_print("Opening WAV file:", wav_path)
  local f, err = io.open(wav_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end

  -- read RIFF header
  local riff_header = f:read(4)
  if riff_header ~= "RIFF" then
    f:close()
    error("Not a valid WAV file (missing RIFF header)")
  end

  local file_size = read_le_u32(f)
  local wave_header = f:read(4)
  if wave_header ~= "WAVE" then
    f:close()
    error("Not a valid WAV file (missing WAVE header)")
  end

  local sample_rate, bits_per_sample, num_channels
  local raw_data

  -- read chunks
  while true do
    local chunk_id = f:read(4)
    if not chunk_id or #chunk_id < 4 then break end
    
    local chunk_size = read_le_u32(f)
    debug_print(string.format("WAV Chunk: '%s' (%d bytes)", chunk_id, chunk_size))

    if chunk_id == "fmt " then
      local format_tag = read_le_u16(f)
      if format_tag ~= 1 then
        f:close()
        error("Unsupported WAV format (not PCM)")
      end
      
      num_channels = read_le_u16(f)
      sample_rate = read_le_u32(f)
      local byte_rate = read_le_u32(f)
      local block_align = read_le_u16(f)
      bits_per_sample = read_le_u16(f)
      
      debug_print("WAV Format - Sample rate:", sample_rate, "Bits:", bits_per_sample, "Channels:", num_channels)
      
      -- skip any extra format bytes
      if chunk_size > 16 then
        f:seek("cur", chunk_size - 16)
      end
      
    elseif chunk_id == "data" then
      raw_data = f:read(chunk_size)
      debug_print("WAV data length:", raw_data and #raw_data)
      
    else
      -- skip unknown chunks
      f:seek("cur", chunk_size)
      debug_print("Skipped WAV chunk:", chunk_id)
    end

    -- skip pad byte if chunk size is odd
    if chunk_size % 2 ~= 0 then
      f:seek("cur", 1)
    end
  end

  f:close()
  
  assert(sample_rate and raw_data and bits_per_sample, "Missing required WAV chunks")
  
  if num_channels ~= 1 then
    error("Only mono WAV files are supported for IFF conversion")
  end

  -- decode samples into normalized floats
  local buffer_data = {}
  
  if bits_per_sample == 8 then
    -- 8-bit WAV is unsigned (0-255)
    for i = 1, #raw_data do
      local b = raw_data:byte(i)
      local normalized = (b - 128) / 128.0
      buffer_data[i] = normalized
    end
    
  elseif bits_per_sample == 16 then
    -- 16-bit WAV is signed little-endian
    assert(#raw_data % 2 == 0, "Odd byte count in 16-bit WAV data")
    local idx = 1
    for i = 1, #raw_data, 2 do
      local lo, hi = raw_data:byte(i, i+1)
      local val = hi * 256 + lo
      if val >= 0x8000 then val = val - 0x10000 end
      buffer_data[idx] = val / 32768.0
      idx = idx + 1
    end
    
  else
    error("Unsupported bit depth: " .. bits_per_sample .. " (only 8 and 16-bit supported)")
  end

  debug_print("Converted WAV frames:", #buffer_data)
  return buffer_data, sample_rate, bits_per_sample
end

-- write IFF file from buffer data
local function write_iff_file(output_path, buffer_data, sample_rate, bits_per_sample)
  debug_print("Writing IFF file:", output_path)
  local f, err = io.open(output_path, "wb")
  if not f then
    error("Could not create IFF file: " .. err)
  end

  local form_type = (bits_per_sample == 16) and "16SV" or "8SVX"
  local num_samples = #buffer_data
  local body_size = (bits_per_sample == 16) and (num_samples * 2) or num_samples
  local vhdr_size = 20
  local form_size = 4 + 8 + vhdr_size + 8 + body_size
  
  -- add padding if body size is odd
  if body_size % 2 ~= 0 then
    form_size = form_size + 1
  end

  debug_print("IFF Format:", form_type, "Body size:", body_size, "Form size:", form_size)

  -- write FORM header
  f:write("FORM")
  write_be_u32(f, form_size)
  f:write(form_type)

  -- write VHDR chunk
  f:write("VHDR")
  write_be_u32(f, vhdr_size)
  write_be_u32(f, num_samples)  -- oneShotHiSamples
  write_be_u32(f, 0)            -- repeatHiSamples
  write_be_u32(f, 0)            -- samplesPerHiCycle
  write_be_u16(f, sample_rate)  -- samplesPerSec
  f:write(string.char(1))       -- ctOctave
  f:write(string.char(0))       -- sCompression
  write_be_u32(f, 65536)        -- volume (fixed point 1.0)

  -- write BODY chunk
  f:write("BODY")
  write_be_u32(f, body_size)

  -- write sample data
  if bits_per_sample == 8 then
    -- convert normalized float to signed 8-bit
    for i = 1, num_samples do
      local sample_value = buffer_data[i]
      sample_value = math.max(-1.0, math.min(1.0, sample_value))
      local int_value = math.floor(sample_value * 128 + 0.5)
      if int_value > 127 then int_value = 127 end
      if int_value < -128 then int_value = -128 end
      local unsigned_val = int_value < 0 and (int_value + 256) or int_value
      f:write(string.char(unsigned_val))
    end
  else
    -- convert normalized float to signed 16-bit big-endian
    for i = 1, num_samples do
      local sample_value = buffer_data[i]
      sample_value = math.max(-1.0, math.min(1.0, sample_value))
      local int_value = math.floor(sample_value * 32767 + 0.5)
      if int_value > 32767 then int_value = 32767 end
      if int_value < -32768 then int_value = -32768 end
      write_be_u16(f, int_value < 0 and (int_value + 65536) or int_value)
    end
  end

  -- add padding byte if body size is odd
  if body_size % 2 ~= 0 then
    f:write(string.char(0))
  end

  f:close()
  debug_print("IFF file written successfully")
end

-- Simple linear resampling function
local function resample_buffer(buffer_data, original_rate, target_rate)
  if original_rate == target_rate then
    return buffer_data
  end
  
  local ratio = original_rate / target_rate
  local new_length = math.floor(#buffer_data / ratio)
  local resampled = {}
  
  debug_print(string.format("Resampling from %d Hz to %d Hz (%d -> %d samples)", 
    original_rate, target_rate, #buffer_data, new_length))
  
  for i = 1, new_length do
    local pos = (i - 1) * ratio + 1
    local index = math.floor(pos)
    local frac = pos - index
    
    if index >= #buffer_data then
      resampled[i] = buffer_data[#buffer_data]
    elseif index < 1 then
      resampled[i] = buffer_data[1]
    else
      -- linear interpolation
      local sample1 = buffer_data[index]
      local sample2 = buffer_data[math.min(index + 1, #buffer_data)]
      resampled[i] = sample1 + frac * (sample2 - sample1)
    end
  end
  
  return resampled
end

-- Function to convert WAV to IFF (always 28604 Hz 8-bit mono .iff)
function convertWAVToIFF()
  local file_path = renoise.app():prompt_for_filename_to_read(
    {"*.wav"}, 
    "Select WAV File to Convert to IFF"
  )
  
  if not file_path or file_path == "" then
    renoise.app():show_status("No file selected")
    return
  end

  print("---------------------------------")
  debug_print("Converting WAV to IFF (28604 Hz 8-bit mono):", file_path)

  local buffer_data, sample_rate, bits_per_sample
  local ok, err = pcall(function()
    buffer_data, sample_rate, bits_per_sample = convert_wav_to_buffer(file_path)
  end)

  if not ok then
    print(string.format("Failed to convert WAV file: %s (Error: %s)", file_path, err))
    renoise.app():show_status("WAV conversion failed: " .. err)
    return
  end

  -- Track what operations were performed
  local operations = {}
  
  -- Always resample to 28604 Hz (A-3 finetune +4)
  local target_rate = 28604
  local resampled_data = resample_buffer(buffer_data, sample_rate, target_rate)
  if sample_rate ~= target_rate then
    table.insert(operations, string.format("resampled from %d Hz to %d Hz", sample_rate, target_rate))
  end
  
  -- Check length and truncate if necessary (IFF limit is 65535 frames)
  if #resampled_data > 65535 then
    debug_print(string.format("Sample too long (%d frames), truncating to 65534 frames", #resampled_data))
    table.insert(operations, string.format("truncated from %d to 65534 frames", #resampled_data))
    local truncated_data = {}
    for i = 1, 65534 do
      truncated_data[i] = resampled_data[i]
    end
    resampled_data = truncated_data
  end
  
  -- Always mention bit depth conversion
  table.insert(operations, "converted to 8-bit")
  
  -- Always output as .iff extension
  local output_path = change_extension(file_path, "iff")
  
  local write_ok, write_err = pcall(function()
    -- Always write as 8-bit (8SVX format)
    write_iff_file(output_path, resampled_data, target_rate, 8)
  end)

  if write_ok then
    local filename = filename_from_path(output_path)
    local status_msg = string.format("Converted to IFF: %s", filename)
    if #operations > 0 then
      status_msg = status_msg .. " (" .. table.concat(operations, ", ") .. ")"
    end
    renoise.app():show_status(status_msg)
    print(string.format("Successfully converted: %s -> %s", file_path, output_path))
    if #operations > 0 then
      print("Operations performed: " .. table.concat(operations, ", "))
    end
  else
    print(string.format("Failed to write IFF file: %s (Error: %s)", output_path, write_err))
    renoise.app():show_status("IFF write failed: " .. write_err)
  end
end

renoise.tool():add_keybinding{name = "Global:Paketti:Convert WAV to IFF...",invoke = convertWAVToIFF}


-- Function to save current selected sample as IFF (28604 Hz 8-bit mono .iff)
function saveCurrentSampleAsIFF()
  local song = renoise.song()
  
  -- Check if we have a selected instrument and sample
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  if not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end

  -- OS-specific extension format (matching PTI loader pattern)
  local os_name = os.platform()
  local ext
  if os_name == "WINDOWS" then
    ext = "iff"  -- Windows: no asterisk, no dot
  else
    ext = "*.iff"  -- macOS/Linux: asterisk + dot
  end
  local output_path = renoise.app():prompt_for_filename_to_write(ext, "Save Sample as IFF File")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  -- Ensure .iff extension
  if not output_path:lower():match("%.iff$") then
    output_path = change_extension(output_path, "iff")
  end

  print("---------------------------------")
  debug_print("Saving current sample as IFF (28604 Hz 8-bit mono):", sample.name)

  local buffer = sample.sample_buffer
  local original_rate = buffer.sample_rate
  local original_frames = buffer.number_of_frames
  local original_channels = buffer.number_of_channels
  
  debug_print(string.format("Original sample: %d Hz, %d frames, %d channels", 
    original_rate, original_frames, original_channels))

  -- Extract sample data (mix to mono if stereo)
  local sample_data = {}
  if original_channels == 1 then
    -- Mono - direct copy
    for i = 1, original_frames do
      sample_data[i] = buffer:sample_data(1, i)
    end
  else
    -- Stereo/Multi - mix to mono
    for i = 1, original_frames do
      local sum = 0
      for ch = 1, original_channels do
        sum = sum + buffer:sample_data(ch, i)
      end
      sample_data[i] = sum / original_channels
    end
  end

  -- Track what operations were performed
  local operations = {}
  
  -- Resample to 28604 Hz (A-3 finetune +4) if needed
  local target_rate = 28604
  if original_rate ~= target_rate then
    sample_data = resample_buffer(sample_data, original_rate, target_rate)
    table.insert(operations, string.format("resampled from %d Hz to %d Hz", original_rate, target_rate))
  end
  
  -- Check length and truncate if necessary
  local was_truncated = false
  if #sample_data > 65535 then
    local original_length = #sample_data
    debug_print(string.format("Sample too long (%d frames), truncating to 65534 frames", original_length))
    local truncated_data = {}
    for i = 1, 65534 do
      truncated_data[i] = sample_data[i]
    end
    sample_data = truncated_data
    was_truncated = true
    table.insert(operations, string.format("truncated from %d to 65534 frames", original_length))
  end
  
  -- Convert to mono if it was stereo
  if original_channels > 1 then
    table.insert(operations, string.format("converted from %d channels to mono", original_channels))
  end
  
  -- Always mention bit depth conversion
  table.insert(operations, "converted to 8-bit")

  local write_ok, write_err = pcall(function()
    write_iff_file(output_path, sample_data, target_rate, 8)
  end)

  if write_ok then
    local filename = filename_from_path(output_path)
    local status_msg = string.format("Saved as IFF: %s", filename)
    if #operations > 0 then
      status_msg = status_msg .. " (" .. table.concat(operations, ", ") .. ")"
    end
    renoise.app():show_status(status_msg)
    print(string.format("Successfully saved: %s -> %s", sample.name, output_path))
    if #operations > 0 then
      print("Operations performed: " .. table.concat(operations, ", "))
    end
  else
    print(string.format("Failed to write IFF file: %s (Error: %s)", output_path, write_err))
    renoise.app():show_status("IFF save failed: " .. write_err)
  end
end

renoise.tool():add_keybinding{name = "Global:Paketti:Save Current Sample as IFF...",invoke = saveCurrentSampleAsIFF}

-- Function to read AIFF files
function convert_aiff_to_buffer(aiff_path)
  debug_print("Opening AIFF file:", aiff_path)
  local f, err = io.open(aiff_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end

  -- read FORM header
  local form_header = f:read(4)
  if form_header ~= "FORM" then
    f:close()
    error("Not a valid AIFF file (missing FORM header)")
  end

  local file_size = read_be_u32(f)
  local aiff_header = f:read(4)
  if aiff_header ~= "AIFF" and aiff_header ~= "AIFC" then
    f:close()
    error("Not a valid AIFF file (missing AIFF/AIFC header)")
  end

  local sample_rate, bits_per_sample, num_channels
  local raw_data

  -- read chunks
  while true do
    local chunk_id = f:read(4)
    if not chunk_id or #chunk_id < 4 then break end
    
    local chunk_size = read_be_u32(f)
    debug_print(string.format("AIFF Chunk: '%s' (%d bytes)", chunk_id, chunk_size))

    if chunk_id == "COMM" then
      num_channels = read_be_u16(f)
      local num_sample_frames = read_be_u32(f)
      bits_per_sample = read_be_u16(f)
      
      -- read 80-bit extended precision sample rate (we'll simplify this)
      local exp_bytes = f:read(10)
      -- Simple conversion from 80-bit extended to integer sample rate
      local exp = exp_bytes:byte(1) * 256 + exp_bytes:byte(2)
      local mantissa_hi = exp_bytes:byte(3) * 16777216 + exp_bytes:byte(4) * 65536 + 
                          exp_bytes:byte(5) * 256 + exp_bytes:byte(6)
      -- approximate conversion
      if exp > 0 then
        sample_rate = math.floor(mantissa_hi * math.pow(2, exp - 16414))
      else
        sample_rate = 44100 -- default fallback
      end
      
      debug_print("AIFF Format - Sample rate:", sample_rate, "Bits:", bits_per_sample, "Channels:", num_channels)
      
      -- skip any extra COMM bytes
      if chunk_size > 18 then
        f:seek("cur", chunk_size - 18)
      end
      
    elseif chunk_id == "SSND" then
      local offset = read_be_u32(f)
      local block_size = read_be_u32(f)
      f:seek("cur", offset) -- skip offset bytes
      raw_data = f:read(chunk_size - 8 - offset)
      debug_print("AIFF sound data length:", raw_data and #raw_data)
      
    else
      -- skip unknown chunks
      f:seek("cur", chunk_size)
      debug_print("Skipped AIFF chunk:", chunk_id)
    end

    -- skip pad byte if chunk size is odd
    if chunk_size % 2 ~= 0 then
      f:seek("cur", 1)
    end
  end

  f:close()
  
  assert(sample_rate and raw_data and bits_per_sample, "Missing required AIFF chunks")
  
  if num_channels ~= 1 then
    error("Only mono AIFF files are supported for IFF conversion")
  end

  -- decode samples into normalized floats
  local buffer_data = {}
  
  if bits_per_sample == 8 then
    -- 8-bit AIFF is signed
    for i = 1, #raw_data do
      local b = raw_data:byte(i)
      local s8 = (b < 128) and b or (b - 256)
      buffer_data[i] = s8 / 128.0
    end
    
  elseif bits_per_sample == 16 then
    -- 16-bit AIFF is signed big-endian
    assert(#raw_data % 2 == 0, "Odd byte count in 16-bit AIFF data")
    local idx = 1
    for i = 1, #raw_data, 2 do
      local hi, lo = raw_data:byte(i, i+1)
      local val = hi * 256 + lo
      if val >= 0x8000 then val = val - 0x10000 end
      buffer_data[idx] = val / 32768.0
      idx = idx + 1
    end
    
  else
    error("Unsupported bit depth: " .. bits_per_sample .. " (only 8 and 16-bit supported)")
  end

  debug_print("Converted AIFF frames:", #buffer_data)
  return buffer_data, sample_rate, bits_per_sample
end

-- Function to save current selected sample as 8SVX (28604 Hz 8-bit mono .8svx)
function saveCurrentSampleAs8SVX()
  local song = renoise.song()
  
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  if not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end

  -- OS-specific extension format (matching PTI loader pattern)
  local os_name = os.platform()
  local ext
  if os_name == "WINDOWS" then
    ext = "8svx"  -- Windows: no asterisk, no dot
  else
    ext = "*.8svx"  -- macOS/Linux: asterisk + dot
  end
  local output_path = renoise.app():prompt_for_filename_to_write(ext, "Save Sample as 8SVX File")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  debug_print("Original path from dialog:", output_path)
  
  -- CRITICAL: Windows may append the filter pattern to the filename! Clean it up
  -- Example: "ropo.8svx*..8svx" needs to become "ropo.8svx"
  output_path = output_path:gsub("%*%.%.8svx$", "")  -- Remove *.8svx suffix if present
  output_path = output_path:gsub("%.8svx%*", ".8svx")  -- Remove * if it appears before extension
  
  debug_print("After cleanup:", output_path)
  
  if not output_path:lower():match("%.8svx$") then
    output_path = change_extension(output_path, "8svx")
    debug_print("Changed extension, new path:", output_path)
  end

  print("---------------------------------")
  debug_print("Saving current sample as 8SVX (28604 Hz 8-bit mono):", sample.name)
  debug_print("Final output path:", output_path)

  local buffer = sample.sample_buffer
  local original_rate = buffer.sample_rate
  local original_frames = buffer.number_of_frames
  local original_channels = buffer.number_of_channels
  
  debug_print(string.format("Original sample: %d Hz, %d frames, %d channels", 
    original_rate, original_frames, original_channels))

  local sample_data = {}
  if original_channels == 1 then
    for i = 1, original_frames do
      sample_data[i] = buffer:sample_data(1, i)
    end
  else
    for i = 1, original_frames do
      local sum = 0
      for ch = 1, original_channels do
        sum = sum + buffer:sample_data(ch, i)
      end
      sample_data[i] = sum / original_channels
    end
  end

  local operations = {}
  local target_rate = 28604
  if original_rate ~= target_rate then
    sample_data = resample_buffer(sample_data, original_rate, target_rate)
    table.insert(operations, string.format("resampled from %d Hz to %d Hz", original_rate, target_rate))
  end
  
  if #sample_data > 65535 then
    debug_print(string.format("Sample too long (%d frames), truncating to 65534 frames", #sample_data))
    local truncated_data = {}
    for i = 1, 65534 do
      truncated_data[i] = sample_data[i]
    end
    sample_data = truncated_data
    table.insert(operations, "truncated to 65534 frames")
  end
  
  if original_channels > 1 then
    table.insert(operations, string.format("converted from %d channels to mono", original_channels))
  end
  
  table.insert(operations, "converted to 8-bit")

  local write_ok, write_err = pcall(function()
    write_iff_file(output_path, sample_data, target_rate, 8)
  end)

  if write_ok then
    local filename = filename_from_path(output_path)
    local status_msg = string.format("Saved as 8SVX: %s", filename)
    if #operations > 0 then
      status_msg = status_msg .. " (" .. table.concat(operations, ", ") .. ")"
    end
    
    renoise.app():show_status(status_msg)
    print(string.format("Successfully saved: %s -> %s", sample.name, output_path))
  else
    -- Show detailed error dialog with path info
    local error_msg = string.format(
      "FAILED TO SAVE 8SVX!\n\n" ..
      "Sample: %s\n" ..
      "Attempted path: %s\n\n" ..
      "Error: %s\n\n" ..
      "OS: %s\n" ..
      "Separator: %s",
      sample.name,
      output_path,
      write_err,
      package.config:sub(1,1) == "\\" and "Windows" or "Unix/Mac",
      package.config:sub(1,1) == "\\" and "\\" or "/"
    )
    renoise.app():show_error(error_msg)
    print(string.format("Failed to write 8SVX file: %s (Error: %s)", output_path, write_err))
  end
end

-- Function to save current selected sample as 16SV (28604 Hz 16-bit mono .16sv)
function saveCurrentSampleAs16SV()
  local song = renoise.song()
  
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  if not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end

  -- OS-specific extension format (matching PTI loader pattern)
  local os_name = os.platform()
  local ext
  if os_name == "WINDOWS" then
    ext = "16sv"  -- Windows: no asterisk, no dot
  else
    ext = "*.16sv"  -- macOS/Linux: asterisk + dot
  end
  local output_path = renoise.app():prompt_for_filename_to_write(ext, "Save Sample as 16SV File")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  debug_print("Original path from dialog:", output_path)
  
  -- CRITICAL: Windows may append the filter pattern to the filename! Clean it up
  -- Example: "ropo.16sv*..16sv" needs to become "ropo.16sv"
  output_path = output_path:gsub("%*%.%.16sv$", "")  -- Remove *..16sv suffix if present
  output_path = output_path:gsub("%.16sv%*", ".16sv")  -- Remove * if it appears before extension
  
  debug_print("After cleanup:", output_path)
  
  if not output_path:lower():match("%.16sv$") then
    output_path = change_extension(output_path, "16sv")
    debug_print("Changed extension, new path:", output_path)
  end

  print("---------------------------------")
  debug_print("Saving current sample as 16SV (28604 Hz 16-bit mono):", sample.name)
  debug_print("Final output path:", output_path)

  local buffer = sample.sample_buffer
  local original_rate = buffer.sample_rate
  local original_frames = buffer.number_of_frames
  local original_channels = buffer.number_of_channels
  
  debug_print(string.format("Original sample: %d Hz, %d frames, %d channels", 
    original_rate, original_frames, original_channels))

  local sample_data = {}
  if original_channels == 1 then
    for i = 1, original_frames do
      sample_data[i] = buffer:sample_data(1, i)
    end
  else
    for i = 1, original_frames do
      local sum = 0
      for ch = 1, original_channels do
        sum = sum + buffer:sample_data(ch, i)
      end
      sample_data[i] = sum / original_channels
    end
  end

  local operations = {}
  
  -- Resample to 28604 Hz (A-3 finetune +4) if needed
  local target_rate = 28604
  if original_rate ~= target_rate then
    sample_data = resample_buffer(sample_data, original_rate, target_rate)
    table.insert(operations, string.format("resampled from %d Hz to %d Hz", original_rate, target_rate))
  end
  
  if #sample_data > 65535 then
    debug_print(string.format("Sample too long (%d frames), truncating to 65534 frames", #sample_data))
    local truncated_data = {}
    for i = 1, 65534 do
      truncated_data[i] = sample_data[i]
    end
    sample_data = truncated_data
    table.insert(operations, "truncated to 65534 frames")
  end
  
  if original_channels > 1 then
    table.insert(operations, string.format("converted from %d channels to mono", original_channels))
  end
  
  table.insert(operations, "converted to 16-bit")

  local write_ok, write_err = pcall(function()
    write_iff_file(output_path, sample_data, target_rate, 16)
  end)

  if write_ok then
    local filename = filename_from_path(output_path)
    local status_msg = string.format("Saved as 16SV: %s", filename)
    if #operations > 0 then
      status_msg = status_msg .. " (" .. table.concat(operations, ", ") .. ")"
    end
    
    renoise.app():show_status(status_msg)
    print(string.format("Successfully saved: %s -> %s", sample.name, output_path))
  else
    -- Show detailed error dialog with path info
    local error_msg = string.format(
      "FAILED TO SAVE 16SV!\n\n" ..
      "Sample: %s\n" ..
      "Attempted path: %s\n\n" ..
      "Error: %s\n\n" ..
      "OS: %s\n" ..
      "Separator: %s",
      sample.name,
      output_path,
      write_err,
      package.config:sub(1,1) == "\\" and "Windows" or "Unix/Mac",
      package.config:sub(1,1) == "\\" and "\\" or "/"
    )
    renoise.app():show_error(error_msg)
    print(string.format("Failed to write 16SV file: %s (Error: %s)", output_path, write_err))
  end
end

-- Batch conversion: folder of WAV/AIFF files to 8SVX
function batchConvertToIFF()
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing WAV/AIFF Files to Convert")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end

  print("---------------------------------")
  debug_print("Batch converting WAV/AIFF files to 8SVX (28604 Hz) from:", folder_path)

  local files = {}
  local command
  
  if package.config:sub(1,1) == "\\" then
    command = string.format('dir "%s" /b /s', folder_path:gsub('"', '\\"'))
  else
    command = string.format("find '%s' -type f", folder_path:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      local lower_path = line:lower()
      if lower_path:match("%.wav$") or lower_path:match("%.aiff$") or lower_path:match("%.aif$") then
        table.insert(files, line)
      end
    end
    handle:close()
  end
  
  if #files == 0 then
    renoise.app():show_status("No WAV/AIFF files found in folder")
    return
  end

  local success_count = 0
  local fail_count = 0

  for i, file_path in ipairs(files) do
    print(string.format("Processing %d/%d: %s", i, #files, filename_from_path(file_path)))
    
    local buffer_data, sample_rate, bits_per_sample
    local ok, err = pcall(function()
      if file_path:lower():match("%.wav$") then
        buffer_data, sample_rate, bits_per_sample = convert_wav_to_buffer(file_path)
      else
        buffer_data, sample_rate, bits_per_sample = convert_aiff_to_buffer(file_path)
      end
    end)

    if ok then
      local target_rate = 28604
      local resampled_data = resample_buffer(buffer_data, sample_rate, target_rate)
      
      if #resampled_data > 65535 then
        local truncated_data = {}
        for j = 1, 65534 do
          truncated_data[j] = resampled_data[j]
        end
        resampled_data = truncated_data
      end
      
      local output_path = change_extension(file_path, "8svx")
      
      local write_ok, write_err = pcall(function()
        write_iff_file(output_path, resampled_data, target_rate, 8)
      end)

      if write_ok then
        success_count = success_count + 1
        debug_print("Converted:", filename_from_path(file_path))
      else
        fail_count = fail_count + 1
        print(string.format("Failed to write: %s (Error: %s)", file_path, write_err))
      end
    else
      fail_count = fail_count + 1
      print(string.format("Failed to read: %s (Error: %s)", file_path, err))
    end
  end

  local status_msg = string.format("Batch conversion complete: %d succeeded, %d failed", success_count, fail_count)
  renoise.app():show_status(status_msg)
  print(status_msg)
end

-- Batch conversion: folder of WAV/AIFF files to 16SV (preserves sample rate)
function batchConvertTo16SV()
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing WAV/AIFF Files to Convert to 16SV")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end

  print("---------------------------------")
  debug_print("Batch converting WAV/AIFF files to 16SV (28604 Hz) from:", folder_path)

  local files = {}
  local command
  
  if package.config:sub(1,1) == "\\" then
    command = string.format('dir "%s" /b /s', folder_path:gsub('"', '\\"'))
  else
    command = string.format("find '%s' -type f", folder_path:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      local lower_path = line:lower()
      if lower_path:match("%.wav$") or lower_path:match("%.aiff$") or lower_path:match("%.aif$") then
        table.insert(files, line)
      end
    end
    handle:close()
  end
  
  if #files == 0 then
    renoise.app():show_status("No WAV/AIFF files found in folder")
    return
  end

  local success_count = 0
  local fail_count = 0

  for i, file_path in ipairs(files) do
    print(string.format("Processing %d/%d: %s", i, #files, filename_from_path(file_path)))
    
    local buffer_data, sample_rate, bits_per_sample
    local ok, err = pcall(function()
      if file_path:lower():match("%.wav$") then
        buffer_data, sample_rate, bits_per_sample = convert_wav_to_buffer(file_path)
      else
        buffer_data, sample_rate, bits_per_sample = convert_aiff_to_buffer(file_path)
      end
    end)

    if ok then
      local target_rate = 28604
      local resampled_data = resample_buffer(buffer_data, sample_rate, target_rate)
      
      if #resampled_data > 65535 then
        local truncated_data = {}
        for j = 1, 65534 do
          truncated_data[j] = resampled_data[j]
        end
        resampled_data = truncated_data
      end
      
      local output_path = change_extension(file_path, "16sv")
      
      local write_ok, write_err = pcall(function()
        write_iff_file(output_path, resampled_data, target_rate, 16)
      end)

      if write_ok then
        success_count = success_count + 1
        debug_print("Converted:", filename_from_path(file_path))
      else
        fail_count = fail_count + 1
        print(string.format("Failed to write: %s (Error: %s)", file_path, write_err))
      end
    else
      fail_count = fail_count + 1
      print(string.format("Failed to read: %s (Error: %s)", file_path, err))
    end
  end

  local status_msg = string.format("Batch conversion complete: %d succeeded, %d failed", success_count, fail_count)
  renoise.app():show_status(status_msg)
  print(status_msg)
end

-- Batch conversion: folder of IFF/8SVX/16SV files to WAV
function batchConvertIFFToWAV()
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing IFF/8SVX/16SV Files to Convert to WAV")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end

  print("---------------------------------")
  debug_print("Batch converting IFF/8SVX/16SV files to WAV from:", folder_path)

  local files = {}
  local command
  
  if package.config:sub(1,1) == "\\" then
    command = string.format('dir "%s" /b /s', folder_path:gsub('"', '\\"'))
  else
    command = string.format("find '%s' -type f", folder_path:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      local lower_path = line:lower()
      if lower_path:match("%.iff$") or lower_path:match("%.8svx$") or lower_path:match("%.16sv$") then
        table.insert(files, line)
      end
    end
    handle:close()
  end
  
  if #files == 0 then
    renoise.app():show_status("No IFF/8SVX/16SV files found in folder")
    return
  end

  local success_count = 0
  local fail_count = 0

  for i, file_path in ipairs(files) do
    print(string.format("Processing %d/%d: %s", i, #files, filename_from_path(file_path)))
    
    local buffer_data, sample_rate
    local ok, err = pcall(function()
      buffer_data, sample_rate = convert_iff_to_buffer(file_path)
    end)

    if ok then
      local output_path = change_extension(file_path, "wav")
      
      local write_ok, write_err = pcall(function()
        write_wav_file(output_path, buffer_data, sample_rate, 16)
      end)

      if write_ok then
        success_count = success_count + 1
        debug_print("Converted:", filename_from_path(file_path))
      else
        fail_count = fail_count + 1
        print(string.format("Failed to write: %s (Error: %s)", file_path, write_err))
      end
    else
      fail_count = fail_count + 1
      print(string.format("Failed to read: %s (Error: %s)", file_path, err))
    end
  end

  local status_msg = string.format("Batch IFF to WAV complete: %d succeeded, %d failed", success_count, fail_count)
  renoise.app():show_status(status_msg)
  print(status_msg)
end

-- Batch conversion: folder of WAV files to IFF (28604 Hz 8-bit)
function batchConvertWAVToIFF()
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing WAV Files to Convert to IFF")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end

  print("---------------------------------")
  debug_print("Batch converting WAV files to IFF (28604 Hz 8-bit) from:", folder_path)

  local files = {}
  local command
  
  if package.config:sub(1,1) == "\\" then
    command = string.format('dir "%s" /b /s', folder_path:gsub('"', '\\"'))
  else
    command = string.format("find '%s' -type f", folder_path:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      local lower_path = line:lower()
      if lower_path:match("%.wav$") then
        table.insert(files, line)
      end
    end
    handle:close()
  end
  
  if #files == 0 then
    renoise.app():show_status("No WAV files found in folder")
    return
  end

  local success_count = 0
  local fail_count = 0

  for i, file_path in ipairs(files) do
    print(string.format("Processing %d/%d: %s", i, #files, filename_from_path(file_path)))
    
    local buffer_data, sample_rate, bits_per_sample
    local ok, err = pcall(function()
      buffer_data, sample_rate, bits_per_sample = convert_wav_to_buffer(file_path)
    end)

    if ok then
      local target_rate = 28604
      local resampled_data = resample_buffer(buffer_data, sample_rate, target_rate)
      
      if #resampled_data > 65535 then
        local truncated_data = {}
        for j = 1, 65534 do
          truncated_data[j] = resampled_data[j]
        end
        resampled_data = truncated_data
      end
      
      local output_path = change_extension(file_path, "iff")
      
      local write_ok, write_err = pcall(function()
        write_iff_file(output_path, resampled_data, target_rate, 8)
      end)

      if write_ok then
        success_count = success_count + 1
        debug_print("Converted:", filename_from_path(file_path))
      else
        fail_count = fail_count + 1
        print(string.format("Failed to write: %s (Error: %s)", file_path, write_err))
      end
    else
      fail_count = fail_count + 1
      print(string.format("Failed to read: %s (Error: %s)", file_path, err))
    end
  end

  local status_msg = string.format("Batch WAV to IFF complete: %d succeeded, %d failed", success_count, fail_count)
  renoise.app():show_status(status_msg)
  print(status_msg)
end

renoise.tool():add_keybinding{name = "Global:Paketti:Save Current Sample as 8SVX...",invoke = saveCurrentSampleAs8SVX}
renoise.tool():add_keybinding{name = "Global:Paketti:Save Current Sample as 16SV...",invoke = saveCurrentSampleAs16SV}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Convert WAV/AIFF to 8SVX...",invoke = batchConvertToIFF}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Convert WAV/AIFF to 16SV...",invoke = batchConvertTo16SV}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Convert IFF/8SVX/16SV to WAV...",invoke = batchConvertIFFToWAV}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Convert WAV to IFF...",invoke = batchConvertWAVToIFF}



