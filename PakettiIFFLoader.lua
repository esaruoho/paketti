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

-- Add menu entries and keybinding for manual file selection
renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti..:Load..:Load IFF Sample File...",
  invoke = loadIFFSampleFromDialog
}

renoise.tool():add_menu_entry{
  name = "Sample Navigator:Paketti..:Load..:Load IFF Sample File...",
  invoke = loadIFFSampleFromDialog
}

renoise.tool():add_menu_entry{
  name = "Sample Mappings:Paketti..:Load..:Load IFF Sample File...",
  invoke = loadIFFSampleFromDialog
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Load IFF Sample File...",
  invoke = loadIFFSampleFromDialog
}

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
