--[[============================================================================
PakettiAkaiMPC2000.lua — MPC2000 SND Sample Import/Export
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[MPC2000]", ...)
end

-- Read little-endian values
local function read_u16_le(data, pos)
  if pos + 1 > #data then return 0 end
  return data:byte(pos) + data:byte(pos + 1) * 256
end

local function read_u32_le(data, pos)
  if pos + 3 > #data then return 0 end
  return data:byte(pos) + data:byte(pos + 1) * 256 + 
         data:byte(pos + 2) * 65536 + data:byte(pos + 3) * 16777216
end

local function read_s16_le(data, pos)
  local val = read_u16_le(data, pos)
  return val >= 32768 and val - 65536 or val
end

local function read_s8(data, pos)
  local val = data:byte(pos)
  return val >= 128 and val - 256 or val
end

-- Write little-endian values
local function write_u16_le(val)
  return string.char(val % 256, math.floor(val / 256) % 256)
end

local function write_u32_le(val)
  return string.char(val % 256, math.floor(val / 256) % 256,
                     math.floor(val / 65536) % 256, math.floor(val / 16777216) % 256)
end

-- Read ASCII string with padding
local function read_ascii_string(data, start, length)
  local result = ""
  for i = start, start + length - 1 do
    local char = data:byte(i)
    if char == 0 then break end
    result = result .. string.char(char)
  end
  return result:match("^(.-)%s*$") -- trim trailing spaces
end

-- Write ASCII string with padding
local function write_ascii_string(str, length)
  local result = {}
  for i = 1, length do
    if i <= #str then
      table.insert(result, str:byte(i))
    else
      table.insert(result, 32) -- space padding
    end
  end
  return result
end

-- Helper function: convert unsigned byte to signed (two's complement)
local function byte_to_twos_complement(byte_val)
  return byte_val >= 128 and byte_val - 256 or byte_val
end

-- Parse MPC2000 SND file (combining detailed parsing with reference validation)
local function parse_mpc2000_snd(data)
  if #data < 42 then
    error("File too small to be MPC2000 SND file")
  end
  
  -- Validation using reference approach (cleaner)
  local header_validation = read_u16_le(data, 1)
  if header_validation ~= 1025 then -- 1025 = bytes [1,4] as word
    error("Invalid MPC2000 SND file (header validation failed: " .. header_validation .. ")")
  end
  
  local sample = {}
  
  -- Extract metadata using direct byte reading (reference approach)
  sample.filename = read_ascii_string(data, 3, 16) -- bytes 3-18
  sample.level = data:byte(20) -- 0-200, default 100
  sample.tune = byte_to_twos_complement(data:byte(21)) -- -120 to +120 cents
  sample.channels = data:byte(22) -- 0=mono, 1=stereo
  
  -- Sample boundaries and loop info
  sample.start = read_u32_le(data, 23)
  sample.loop_end = read_u32_le(data, 27)
  sample.end_marker = read_u32_le(data, 31) 
  sample.loop_length = read_u32_le(data, 35)
  sample.loop_mode = data:byte(39) -- 0=off, 1=on
  sample.beats_in_loop = data:byte(40) -- 1-16, default 1
  sample.sampling_frequency = read_u16_le(data, 41)
  
  -- Calculate loop start using reference approach (cleaner logic)
  local loop_start = 0
  local loop_end = sample.loop_end
  if sample.loop_mode == 1 then
    -- Validate loop_end against actual end
    if loop_end > sample.end_marker then
      loop_end = sample.end_marker
    end
    -- Calculate loop start: loop_end - loop_length + 1
    loop_start = loop_end - sample.loop_length + 1
    if loop_start < 0 then
      loop_start = 0
    end
  end
  sample.calculated_loop_start = loop_start
  sample.calculated_loop_end = loop_end
  
  -- Extract sample data with manual stereo handling
  sample.sample_data = {}
  local sample_data_start = 43 -- after 42-byte header
  local is_stereo = (sample.channels == 1) -- MPC2000: 0=mono, 1=stereo
  local total_frames = sample.end_marker - sample.start
  
  if is_stereo then
    -- Stereo: deinterleave channels for Renoise (which expects separate channel arrays)
    local left_channel = {}
    local right_channel = {}
    
    for frame = 1, total_frames do
      local left_pos = sample_data_start + (frame - 1) * 4 -- 2 samples * 2 bytes each
      local right_pos = left_pos + 2
      
      if right_pos + 1 <= #data then
        local left_val = read_s16_le(data, left_pos) / 32768.0
        local right_val = read_s16_le(data, right_pos) / 32768.0
        table.insert(left_channel, left_val)
        table.insert(right_channel, right_val)
      end
    end
    
    sample.sample_data = {left_channel, right_channel}
    sample.num_channels = 2
    debug_print("Deinterleaved stereo data:", #left_channel, "frames per channel")
  else
    -- Mono
    for frame = 1, total_frames do
      local sample_pos = sample_data_start + (frame - 1) * 2
      if sample_pos + 1 <= #data then
        local val = read_s16_le(data, sample_pos) / 32768.0
        table.insert(sample.sample_data, val)
      end
    end
    sample.num_channels = 1
    debug_print("Extracted mono data:", #sample.sample_data, "frames")
  end
  
  debug_print("Parsed MPC2000 SND sample:", sample.filename)
  debug_print("  Sample rate:", sample.sampling_frequency, "Hz")
  debug_print("  Channels:", is_stereo and "stereo" or "mono")
  debug_print("  Tuning:", sample.tune, "cents")
  debug_print("  Level:", sample.level)
  debug_print("  Start:", sample.start, "End:", sample.end_marker, "Frames:", total_frames)
  debug_print("  Loop mode:", sample.loop_mode == 1 and "on" or "off")
  if sample.loop_mode == 1 then
    debug_print("  Loop: start=" .. loop_start .. " end=" .. loop_end .. " length=" .. sample.loop_length)
    debug_print("  Beats in loop:", sample.beats_in_loop)
  end
  
  return sample
end

-- Create MPC2000 SND file from Renoise sample
local function create_mpc2000_snd(sample, filename)
  debug_print("Creating MPC2000 SND from:", sample.name)
  
  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then
    error("Sample has no data")
  end
  
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  
  -- Extract sample data with proper stereo interleaving
  local sample_data = {}
  if channels == 1 then
    -- Mono
    for i = 1, frames do
      sample_data[i] = buffer:sample_data(1, i)
    end
    debug_print("Extracted mono data:", frames, "frames")
  else
    -- Stereo - manually interleave channels for MPC2000 format
    for i = 1, frames do
      table.insert(sample_data, buffer:sample_data(1, i)) -- left
      table.insert(sample_data, buffer:sample_data(2, i)) -- right
    end
    debug_print("Interleaved stereo data:", frames, "frames ->", #sample_data, "samples")
  end
  
  -- Create header (42 bytes for MPC2000)
  local header = {}
  
  -- Header ID (1,4)
  table.insert(header, 1)
  table.insert(header, 4)
  
  -- Filename (16 bytes, space padded)
  local ascii_name = write_ascii_string(filename or sample.name or "SAMPLE", 16)
  for i = 1, 16 do
    table.insert(header, ascii_name[i])
  end
  
  table.insert(header, 0) -- zero byte
  
  -- Level (0-200, default 100)
  table.insert(header, 100)
  
  -- Tune (-120 to +120 cents) - use reference approach
  local tune = (sample.transpose or 0) + math.floor((sample.fine_tune or 0) / 100)
  tune = math.max(-120, math.min(120, tune))
  table.insert(header, tune < 0 and tune + 256 or tune)
  
  -- Channels (0=mono, 1=stereo)
  table.insert(header, channels > 1 and 1 or 0)
  
  -- Start point (always 0)
  local start_bytes = write_u32_le(0)
  for i = 1, 4 do table.insert(header, start_bytes:byte(i)) end
  
  -- Loop end
  local loop_end = frames
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    loop_end = sample.loop_end or frames
  end
  local loop_end_bytes = write_u32_le(loop_end - 1)
  for i = 1, 4 do table.insert(header, loop_end_bytes:byte(i)) end
  
  -- End point
  local end_bytes = write_u32_le(frames - 1)
  for i = 1, 4 do table.insert(header, end_bytes:byte(i)) end
  
  -- Loop length
  local loop_length = 0
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    local loop_start = sample.loop_start or 1
    loop_length = loop_end - loop_start + 1
  end
  local loop_length_bytes = write_u32_le(loop_length)
  for i = 1, 4 do table.insert(header, loop_length_bytes:byte(i)) end
  
  -- Loop mode (0=off, 1=on)
  local loop_mode = (sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF) and 1 or 0
  table.insert(header, loop_mode)
  
  -- Beats in loop (1-16, default 1)
  table.insert(header, 1)
  
  -- Sampling frequency
  local freq_bytes = write_u16_le(sample_rate)
  table.insert(header, freq_bytes:byte(1))
  table.insert(header, freq_bytes:byte(2))
  
  -- Convert header to string
  local header_str = ""
  for i, byte_val in ipairs(header) do
    header_str = header_str .. string.char(byte_val)
  end
  
  -- Convert sample data to 16-bit signed integers
  local sample_str = ""
  for i = 1, #sample_data do
    local val = math.floor(sample_data[i] * 32767 + 0.5)
    val = math.max(-32768, math.min(32767, val))
    local bytes = write_u16_le(val < 0 and val + 65536 or val)
    sample_str = sample_str .. bytes
  end
  
  debug_print("Created MPC2000 SND data:", #header_str + #sample_str, "bytes")
  return header_str .. sample_str
end

-- Import MPC2000 SND sample
function importMPC2000Sample(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.snd"}, "Import MPC2000 SND Sample"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  print("---------------------------------")
  debug_print("Importing MPC2000 SND sample:", file_path)
  
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end
  local data = f:read("*all")
  f:close()
  
  local mpc_sample = parse_mpc2000_snd(data)
  
  -- Create new instrument in Renoise
  local song = renoise.song()
  local current_idx = song.selected_instrument_index
  local new_idx = current_idx + 1
  song:insert_instrument_at(new_idx)
  song.selected_instrument_index = new_idx
  
  local instrument = song.instruments[new_idx]
  instrument.name = mpc_sample.filename
  
  -- Create sample
  instrument:insert_sample_at(1)
  local sample = instrument.samples[1]
  sample.name = mpc_sample.filename
  
  -- Load sample data (improved stereo handling from new parsing)
  if mpc_sample.num_channels == 2 then
    -- Stereo data (already deinterleaved by parser)
    local left_data = mpc_sample.sample_data[1]
    local right_data = mpc_sample.sample_data[2]
    local frame_count = #left_data
    
    sample.sample_buffer:create_sample_data(mpc_sample.sampling_frequency, 16, 2, frame_count)
    sample.sample_buffer:prepare_sample_data_changes()
    for i = 1, frame_count do
      sample.sample_buffer:set_sample_data(1, i, left_data[i])
      sample.sample_buffer:set_sample_data(2, i, right_data[i])
    end
    sample.sample_buffer:finalize_sample_data_changes()
    debug_print("Loaded stereo sample data:", frame_count, "frames")
  else
    -- Mono data
    sample.sample_buffer:create_sample_data(mpc_sample.sampling_frequency, 16, 1, #mpc_sample.sample_data)
    sample.sample_buffer:prepare_sample_data_changes()
    for i = 1, #mpc_sample.sample_data do
      sample.sample_buffer:set_sample_data(1, i, mpc_sample.sample_data[i])
    end
    sample.sample_buffer:finalize_sample_data_changes()
    debug_print("Loaded mono sample data:", #mpc_sample.sample_data, "frames")
  end
  
  -- Apply sample properties (combination approach - reference tune handling + detailed mapping)
  sample.name = mpc_sample.filename
  sample.transpose = byte_to_twos_complement(mpc_sample.tune) -- Use reference approach for transpose
  sample.sample_mapping.base_note = 60 -- C-4, MPC default
  
  -- Set loop using reference calculation (cleaner logic)
  if mpc_sample.loop_mode == 1 then
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = math.max(1, mpc_sample.calculated_loop_start + 1) -- convert to 1-based
    sample.loop_end = math.min(sample.sample_buffer.number_of_frames, mpc_sample.calculated_loop_end + 1)
    debug_print("Set loop using reference calc:", sample.loop_start, "to", sample.loop_end)
  end
  
  renoise.app():show_status("Imported MPC2000 sample: " .. mpc_sample.filename)
  debug_print("Import complete")
end

-- Export current sample as MPC2000 SND
function exportMPC2000Sample()
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
  if not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  local output_path = renoise.app():prompt_for_filename_to_write("*.snd", "Export MPC2000 SND Sample")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  -- Ensure .snd extension
  if not output_path:lower():match("%.snd$") then
    output_path = output_path:gsub("%.[^.]*$", "") .. ".snd"
  end
  
  print("---------------------------------")
  debug_print("Exporting MPC2000 SND sample:", sample.name)
  
  local filename = output_path:match("[^/\\]+$"):gsub("%.snd$", "")
  local file_data = create_mpc2000_snd(sample, filename)
  
  local f, err = io.open(output_path, "wb")
  if not f then
    error("Could not create file: " .. err)
  end
  f:write(file_data)
  f:close()
  
  renoise.app():show_status("Exported MPC2000 SND sample: " .. filename)
  debug_print("Export complete:", #file_data, "bytes")
end

-- Batch import MPC2000 samples from folder
function importMPC2000Folder()
  local folder_path = renoise.app():prompt_for_path("Select Folder with MPC2000 SND Files")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end
  
  print("---------------------------------")
  debug_print("Batch importing MPC2000 samples from:", folder_path)
  
  -- Get list of .snd files
  local command
  if package.config:sub(1,1) == "\\" then  -- Windows
    command = string.format('dir "%s\\*.snd" /b', folder_path:gsub('"', '\\"'))
  else  -- macOS and Linux
    command = string.format("find '%s' -name '*.snd' -type f", folder_path:gsub("'", "'\\''"))
  end
  
  local handle = io.popen(command)
  local files = {}
  if handle then
    for line in handle:lines() do
      if package.config:sub(1,1) == "\\" then
        table.insert(files, folder_path .. "\\" .. line)
      else
        table.insert(files, line)
      end
    end
    handle:close()
  end
  
  if #files == 0 then
    renoise.app():show_status("No .snd files found in folder")
    return
  end
  
  local imported_count = 0
  for _, file_path in ipairs(files) do
    local ok, err = pcall(function()
      importMPC2000Sample(file_path)
      imported_count = imported_count + 1
    end)
    
    if not ok then
      debug_print("Failed to import:", file_path, "Error:", err)
    end
  end
  
  renoise.app():show_status(string.format("Imported %d/%d MPC2000 samples", imported_count, #files))
  debug_print("Batch import complete:", imported_count, "successful imports")
end

-- Menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Import MPC2000 SND Sample...",invoke = importMPC2000Sample}
renoise.tool():add_keybinding{name = "Global:Paketti:Export MPC2000 SND Sample...",invoke = exportMPC2000Sample}



-- File import hook for MPC2000 samples
local mpc2000_integration = {
  name = "MPC2000 SND Sample",
  category = "sample", 
  extensions = { "snd" },
  invoke = importMPC2000Sample
}

if not renoise.tool():has_file_import_hook("sample", { "snd" }) then
  renoise.tool():add_file_import_hook(mpc2000_integration)
end 