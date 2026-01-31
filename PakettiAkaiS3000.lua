--[[============================================================================
PakettiAkaiS3000.lua — Akai S3000 Sample Import/Export (.s format)
192-byte header with enhanced loop support
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[S3000]", ...)
end

-- AKAII character set (same as S1000)
local AKAII_CHARS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

-- Convert AKAII encoding to ASCII
local function akaii_to_ascii(akaii_str)
  local result = ""
  for i = 1, #akaii_str do
    local byte_val = akaii_str:byte(i)
    if byte_val == 0 then
      break -- null terminator
    elseif byte_val >= 32 and byte_val <= 126 then
      result = result .. AKAII_CHARS:sub(byte_val - 31, byte_val - 31)
    else
      result = result .. " " -- fallback for invalid chars
    end
  end
  return result:match("^%s*(.-)%s*$") -- trim whitespace
end

-- Convert ASCII to AKAII encoding
local function ascii_to_akaii(ascii_str)
  local result = {}
  for i = 1, math.min(#ascii_str, 12) do
    local char = ascii_str:sub(i, i)
    local pos = AKAII_CHARS:find(char, 1, true)
    if pos then
      table.insert(result, pos + 31)
    else
      table.insert(result, 32) -- space for invalid chars
    end
  end
  -- Pad with zeros to 12 characters
  while #result < 12 do
    table.insert(result, 0)
  end
  return result
end

-- Read little-endian 16-bit unsigned integer
local function read_u16_le(data, offset)
  local b1, b2 = data:byte(offset, offset + 1)
  return b2 * 256 + b1
end

-- Read little-endian 32-bit unsigned integer
local function read_u32_le(data, offset)
  local b1, b2, b3, b4 = data:byte(offset, offset + 3)
  return b4 * 16777216 + b3 * 65536 + b2 * 256 + b1
end

-- Write little-endian 16-bit unsigned integer
local function write_u16_le(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  return string.char(b1, b2)
end

-- Write little-endian 32-bit unsigned integer
local function write_u32_le(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  return string.char(b1, b2, b3, b4)
end

-- Parse S3000 sample file (192-byte header)
local function parse_s3000_sample(data)
  if #data < 192 then
    error("File too small for S3000 format")
  end
  
  -- Validate S3000 format
  if data:byte(1) ~= 3 then
    error("Invalid S3000 file (byte 1 should be 3)")
  end
  if data:byte(16) ~= 128 then
    error("Invalid S3000 file (byte 16 should be 128)")
  end
  
  local sample = {}
  
  -- Basic info
  sample.filename = akaii_to_ascii(data:sub(4, 15))
  sample.midi_note = data:byte(3)
  sample.fine_tune = data:byte(21)
  if sample.fine_tune > 127 then
    sample.fine_tune = sample.fine_tune - 256 -- convert to signed
  end
  sample.transpose = data:byte(22)
  if sample.transpose > 127 then
    sample.transpose = sample.transpose - 256 -- convert to signed
  end
  
  -- S3000 specific: first active loop (byte 17)
  sample.first_active_loop = data:byte(17)
  sample.active_loop_count = data:byte(23)
  
  -- Sample rate at offset 139 (same as S1000)
  sample.sample_rate = read_u16_le(data, 139)
  
  -- Parse 8 loops (S3000 has enhanced loop support)
  sample.loops = {}
  for i = 1, 8 do
    local loop_offset = 24 + (i - 1) * 16 -- S3000 uses 16 bytes per loop vs 12 for S1000
    local loop = {}
    loop.start = read_u32_le(data, loop_offset)
    loop.length = read_u32_le(data, loop_offset + 4)
    loop.fine_tune = data:byte(loop_offset + 8)
    if loop.fine_tune > 127 then
      loop.fine_tune = loop.fine_tune - 256
    end
    loop.attenuation = data:byte(loop_offset + 9)
    -- S3000 specific loop parameters (bytes 10-15)
    loop.time_stretch = data:byte(loop_offset + 10)
    loop.loop_mode = data:byte(loop_offset + 11)
    loop.reserved1 = data:byte(loop_offset + 12)
    loop.reserved2 = data:byte(loop_offset + 13)
    loop.reserved3 = data:byte(loop_offset + 14)
    loop.reserved4 = data:byte(loop_offset + 15)
    
    table.insert(sample.loops, loop)
  end
  
  -- Sample data starts at byte 192 for S3000
  sample.sample_data = {}
  local sample_start = 193
  for i = sample_start, #data, 2 do
    if i + 1 <= #data then
      local sample_val = read_u16_le(data, i)
      -- Convert from unsigned to signed 16-bit
      if sample_val > 32767 then
        sample_val = sample_val - 65536
      end
      table.insert(sample.sample_data, sample_val / 32768.0)
    end
  end
  
  debug_print("Parsed S3000 sample:", sample.filename, "rate:", sample.sample_rate, "frames:", #sample.sample_data)
  debug_print("First active loop:", sample.first_active_loop, "Active loops:", sample.active_loop_count)
  
  return sample
end

-- Create S3000 sample file (192-byte header)
local function create_s3000_sample(sample, filename)
  debug_print("Creating S3000 sample data for:", filename)
  
  local buffer = sample.sample_buffer
  local sample_rate = buffer.sample_rate
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  
  -- Extract sample data (convert to mono if stereo)
  local sample_data = {}
  if channels == 1 then
    for i = 1, frames do
      sample_data[i] = buffer:sample_data(1, i)
    end
  else
    for i = 1, frames do
      local sum = 0
      for ch = 1, channels do
        sum = sum + buffer:sample_data(ch, i)
      end
      sample_data[i] = sum / channels
    end
  end
  
  -- Build 192-byte header
  local header = {}
  
  -- Bytes 1-3: Format identifier and MIDI note
  table.insert(header, 3) -- S3000 format identifier
  table.insert(header, 1) -- Unknown
  table.insert(header, sample.sample_mapping and sample.sample_mapping.base_note or 60) -- MIDI note
  
  -- Bytes 4-15: AKAII encoded filename
  local akaii_name = ascii_to_akaii(filename)
  for i = 1, 12 do
    table.insert(header, akaii_name[i])
  end
  
  -- Byte 16: Always 128
  table.insert(header, 128)
  
  -- Byte 17: First active loop (S3000 specific)
  local first_active_loop = 0
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    first_active_loop = 1
  end
  table.insert(header, first_active_loop)
  
  -- Bytes 18-20: Reserved
  table.insert(header, 0); table.insert(header, 0); table.insert(header, 0)
  
  -- Byte 21: Fine tune
  local fine_tune = sample.fine_tune or 0
  table.insert(header, fine_tune < 0 and (fine_tune + 256) or fine_tune)
  
  -- Byte 22: Transpose  
  local transpose = sample.transpose or 0
  table.insert(header, transpose < 0 and (transpose + 256) or transpose)
  
  -- Byte 23: Active loop count
  local active_loops = (sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF) and 1 or 0
  table.insert(header, active_loops)
  
  -- Bytes 24-151: 8 loops (16 bytes each for S3000)
  for loop_idx = 1, 8 do
    if loop_idx == 1 and sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
      -- Active loop
      local loop_start = (sample.loop_start or 1) - 1
      local loop_end = sample.loop_end or frames
      local loop_length = loop_end - loop_start
      
      local loop_start_bytes = write_u32_le(loop_start)
      local loop_length_bytes = write_u32_le(loop_length)
      
      for i = 1, 4 do table.insert(header, loop_start_bytes:byte(i)) end
      for i = 1, 4 do table.insert(header, loop_length_bytes:byte(i)) end
      table.insert(header, 0) -- fine tune
      table.insert(header, 0) -- attenuation
      -- S3000 specific loop parameters
      table.insert(header, 0) -- time stretch
      table.insert(header, 0) -- loop mode  
      table.insert(header, 0) -- reserved
      table.insert(header, 0) -- reserved
      table.insert(header, 0) -- reserved
      table.insert(header, 0) -- reserved
    else
      -- Empty loop
      for i = 1, 16 do table.insert(header, 0) end
    end
  end
  
  -- Bytes 152-191: Reserved/padding to reach 192 bytes
  for i = #header + 1, 192 do
    table.insert(header, 0)
  end
  
  -- Add sample rate at offset 139 (overwrite padding)
  local rate_bytes = write_u16_le(sample_rate)
  header[139] = rate_bytes:byte(1)
  header[140] = rate_bytes:byte(2)
  
  -- Convert header to string
  local header_str = ""
  for i, byte_val in ipairs(header) do
    header_str = header_str .. string.char(byte_val)
  end
  
  -- Convert sample data to 16-bit signed little-endian
  local sample_str = ""
  for i = 1, #sample_data do
    local sample_val = sample_data[i]
    -- Convert to 16-bit signed integer
    local int_val = math.floor(sample_val * 32767 + 0.5)
    if int_val > 32767 then int_val = 32767 end
    if int_val < -32768 then int_val = -32768 end
    
    -- Convert to unsigned for writing
    local unsigned_val = int_val < 0 and (int_val + 65536) or int_val
    local sample_bytes = write_u16_le(unsigned_val)
    sample_str = sample_str .. sample_bytes
  end
  
  debug_print("Created S3000 sample data:", #header_str + #sample_str, "bytes")
  return header_str .. sample_str
end

-- Import S3000 sample
function importS3000Sample(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.s"}, "Import S3000 Sample"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  print("---------------------------------")
  debug_print("Importing S3000 sample:", file_path)
  
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end
  local data = f:read("*all")
  f:close()
  
  local s3000_sample = parse_s3000_sample(data)
  
  -- Create new instrument in Renoise
  local song = renoise.song()
  local current_idx = song.selected_instrument_index
  local new_idx = current_idx + 1
  if not safeInsertInstrumentAt(song, new_idx) then return end
  song.selected_instrument_index = new_idx
  
  local instrument = song.instruments[new_idx]
  instrument.name = s3000_sample.filename
  
  -- Create sample
  instrument:insert_sample_at(1)
  local sample = instrument.samples[1]
  sample.name = s3000_sample.filename
  
  -- Load sample data
  sample.sample_buffer:create_sample_data(s3000_sample.sample_rate, 16, 1, #s3000_sample.sample_data)
  sample.sample_buffer:prepare_sample_data_changes()
  for i = 1, #s3000_sample.sample_data do
    sample.sample_buffer:set_sample_data(1, i, s3000_sample.sample_data[i])
  end
  sample.sample_buffer:finalize_sample_data_changes()
  
  -- Apply sample properties
  sample.sample_mapping.base_note = s3000_sample.midi_note
  sample.fine_tune = s3000_sample.fine_tune
  sample.transpose = s3000_sample.transpose
  
  -- Set loop if first active loop exists
  if s3000_sample.first_active_loop > 0 and s3000_sample.active_loop_count > 0 then
    local first_loop = s3000_sample.loops[s3000_sample.first_active_loop]
    if first_loop and first_loop.length > 0 then
      sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      sample.loop_start = first_loop.start + 1
      sample.loop_end = math.min(first_loop.start + first_loop.length, #s3000_sample.sample_data)
      debug_print("Set loop:", sample.loop_start, "to", sample.loop_end)
    end
  end
  
  renoise.app():show_status("Imported S3000 sample: " .. s3000_sample.filename)
  debug_print("Import complete")
end

-- Export current sample as S3000
function exportS3000Sample()
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
  
  local output_path = renoise.app():prompt_for_filename_to_write("*.s", "Export S3000 Sample")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  -- Ensure .s extension
  if not output_path:lower():match("%.s$") then
    output_path = output_path:gsub("%.[^.]*$", "") .. ".s"
  end
  
  print("---------------------------------")
  debug_print("Exporting S3000 sample:", sample.name)
  
  local filename = output_path:match("[^/\\]+$"):gsub("%.s$", "")
  local file_data = create_s3000_sample(sample, filename)
  
  local f, err = io.open(output_path, "wb")
  if not f then
    error("Could not create file: " .. err)
  end
  f:write(file_data)
  f:close()
  
  renoise.app():show_status("Exported S3000 sample: " .. filename)
  debug_print("Export complete:", #file_data, "bytes")
end

-- Menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Export S3000 Sample...",invoke = exportS3000Sample}
renoise.tool():add_keybinding{name = "Global:Paketti:Import S3000 Sample...",invoke = importS3000Sample}

