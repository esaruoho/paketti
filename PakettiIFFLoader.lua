--[[============================================================================
main.lua — IFF (8SVX/16SV) → WAV converter with debug printing and auto-loading into new instruments
============================================================================]]--

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
  local lower = file_path:lower()
  if not (lower:match("%.iff$") or lower:match("%.8svx$")
      or lower:match("%.16sv$")) then
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
    return nil
  end

  -- Insert into Renoise
  local song = renoise.song()
  local idx = song.selected_instrument_index
  if not idx then
    renoise.app():show_status("Select an instrument first")
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
    return nil
  end

  renoise.app():show_status(
    string.format("Loaded %s at %d Hz", name, sample_rate))
  print(string.format("Successfully loaded: %s", file_path))
  return nil
end

-- Function to prompt for IFF file and load it
function loadIFFSampleFromDialog()
  local file_path = renoise.app():prompt_for_filename_to_read(
    {"*.iff", "*.8svx", "*.16sv"}, 
    "Load IFF Sample File"
  )
  
  if file_path and file_path ~= "" then
    loadIFFSample(file_path)
  end
end

renoise.tool():add_file_import_hook{
  name       = "IFF (8SVX+16SV) → WAV converter",
  category   = "sample",
  extensions = {"iff","8svx","16sv"},
  invoke     = loadIFFSample
}

renoise.tool():add_menu_entry{name = "Sample Editor:Paketti..:Load..:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name = "Sample Navigator:Paketti..:Load..:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
renoise.tool():add_menu_entry{name = "Sample Mappings:Paketti..:Load..:Load IFF Sample File...",invoke = loadIFFSampleFromDialog}
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
  -- Prompt the user to select a folder
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing IFF/8SVX Files")
  if not folder_path then
      renoise.app():show_status("No folder selected.")
      return nil
  end

  -- Get all IFF files
  local iff_files = getIFFFiles(folder_path)
  
  -- Check if there are enough files to choose from
  if #iff_files == 0 then
      renoise.app():show_status("No IFF/8SVX files found in the selected folder.")
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
end

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Load Random 128 IFFs",invoke=function() loadRandomIFF(128) end }

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

renoise.tool():add_menu_entry{name = "Sample Editor:Paketti..:Load..:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name = "Sample Navigator:Paketti..:Load..:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name = "Sample Mappings:Paketti..:Load..:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_keybinding{name = "Global:Paketti:Convert IFF to WAV...",invoke = convertIFFToWAV}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:File Formats..:Convert IFF to WAV...",invoke=convertIFFToWAV}

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

-- Function to convert WAV to IFF (always 22kHz 8-bit mono .iff)
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
  debug_print("Converting WAV to IFF (22kHz 8-bit mono):", file_path)

  local buffer_data, sample_rate, bits_per_sample
  local ok, err = pcall(function()
    buffer_data, sample_rate, bits_per_sample = convert_wav_to_buffer(file_path)
  end)

  if not ok then
    print(string.format("Failed to convert WAV file: %s (Error: %s)", file_path, err))
    renoise.app():show_status("WAV conversion failed: " .. err)
    return
  end

  -- Always resample to 22050 Hz
  local target_rate = 22050
  local resampled_data = resample_buffer(buffer_data, sample_rate, target_rate)
  
  -- Always output as .iff extension
  local output_path = change_extension(file_path, "iff")
  
  local write_ok, write_err = pcall(function()
    -- Always write as 8-bit (8SVX format)
    write_iff_file(output_path, resampled_data, target_rate, 8)
  end)

  if write_ok then
    local filename = filename_from_path(output_path)
    renoise.app():show_status(string.format("Converted to IFF: %s (22kHz 8-bit)", filename))
    print(string.format("Successfully converted: %s -> %s (22kHz 8-bit)", file_path, output_path))
  else
    print(string.format("Failed to write IFF file: %s (Error: %s)", output_path, write_err))
    renoise.app():show_status("IFF write failed: " .. write_err)
  end
end

renoise.tool():add_menu_entry{name = "Sample Editor:Paketti..:Load..:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name = "Sample Navigator:Paketti..:Load..:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name = "Sample Mappings:Paketti..:Load..:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_keybinding{name = "Global:Paketti:Convert WAV to IFF...",invoke = convertWAVToIFF}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:File Formats..:Convert WAV to IFF...",invoke=convertWAVToIFF}
