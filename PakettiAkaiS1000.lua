--[[============================================================================
PakettiAkaiS1000.lua — S1000/S1100/S01 Sample and Program Import/Export
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[S1000]", ...)
end

-- AKAII character encoding (S1000 uses this instead of ASCII)
local AKAII_TO_ASCII = {
  [0]="0", [1]="1", [2]="2", [3]="3", [4]="4", [5]="5", [6]="6", [7]="7", [8]="8", [9]="9",
  [10]=" ", [11]="A", [12]="B", [13]="C", [14]="D", [15]="E", [16]="F", [17]="G", [18]="H",
  [19]="I", [20]="J", [21]="K", [22]="L", [23]="M", [24]="N", [25]="O", [26]="P", [27]="Q",
  [28]="R", [29]="S", [30]="T", [31]="U", [32]="V", [33]="W", [34]="X", [35]="Y", [36]="Z",
  [37]="#", [38]="+", [39]="-", [40]="."
}

local ASCII_TO_AKAII = {}
for akaii, ascii in pairs(AKAII_TO_ASCII) do
  ASCII_TO_AKAII[ascii] = akaii
end

-- Convert AKAII to ASCII string
local function akaii_to_string(data, start, length)
  local result = ""
  for i = start, start + length - 1 do
    local akaii_val = data:byte(i)
    result = result .. (AKAII_TO_ASCII[akaii_val] or "?")
  end
  return result:match("^(.-)%s*$") -- trim trailing spaces
end

-- Convert ASCII string to AKAII
local function string_to_akaii(str, length)
  local result = {}
  str = str:upper()
  for i = 1, length do
    local char = str:sub(i, i)
    if char == "" then char = " " end
    table.insert(result, ASCII_TO_AKAII[char] or 10) -- default to space
  end
  return result
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

-- Write little-endian values
local function write_u16_le(val)
  return string.char(val % 256, math.floor(val / 256) % 256)
end

local function write_u32_le(val)
  return string.char(val % 256, math.floor(val / 256) % 256,
                     math.floor(val / 65536) % 256, math.floor(val / 16777216) % 256)
end

-- Parse S1000 sample file
local function parse_s1000_sample(data)
  if #data < 150 then
    error("File too small to be S1000 sample")
  end
  
  local sample = {}
  local pos = 1
  
  -- Header parsing
  sample.format_version = data:byte(pos); pos = pos + 1
  sample.sample_rate_flag = data:byte(pos); pos = pos + 1
  sample.midi_root_note = data:byte(pos); pos = pos + 1
  sample.filename = akaii_to_string(data, pos, 12); pos = pos + 12
  
  pos = pos + 1 -- skip byte 16 (always 128)
  sample.num_active_loops = data:byte(pos); pos = pos + 1
  pos = pos + 2 -- skip 2 zero bytes
  
  sample.loop_mode = data:byte(pos); pos = pos + 1
  sample.cents_tune = data:byte(pos); pos = pos + 1
  if sample.cents_tune >= 128 then sample.cents_tune = sample.cents_tune - 256 end
  sample.semi_tune = data:byte(pos); pos = pos + 1
  if sample.semi_tune >= 128 then sample.semi_tune = sample.semi_tune - 256 end
  
  pos = pos + 4 -- skip 4 bytes
  
  sample.num_sample_words = read_u32_le(data, pos); pos = pos + 4
  sample.start_marker = read_u32_le(data, pos); pos = pos + 4
  sample.end_marker = read_u32_le(data, pos); pos = pos + 4
  
  -- Read loop data (8 loops possible)
  sample.loops = {}
  for i = 1, 8 do
    local loop = {}
    loop.marker = read_u32_le(data, pos); pos = pos + 4
    loop.fine_length = read_u16_le(data, pos); pos = pos + 2
    loop.coarse_length = read_u32_le(data, pos); pos = pos + 4
    loop.time = read_u16_le(data, pos); pos = pos + 2
    table.insert(sample.loops, loop)
    pos = pos + 2 -- skip 2 padding bytes
  end
  
  pos = pos + 4 -- skip 4 bytes
  sample.sampling_frequency = read_u16_le(data, pos); pos = pos + 2
  pos = pos + 10 -- skip final padding
  
  -- Extract sample data (16-bit signed)
  sample.sample_data = {}
  local sample_start = 151 -- after 150-byte header
  for i = 1, sample.num_sample_words do
    local word_pos = sample_start + (i - 1) * 2
    if word_pos + 1 <= #data then
      local val = read_s16_le(data, word_pos)
      table.insert(sample.sample_data, val / 32768.0) -- normalize to -1.0 to 1.0
    end
  end
  
  debug_print("Parsed S1000 sample:", sample.filename)
  debug_print("  Sample rate:", sample.sampling_frequency, "Hz")
  debug_print("  Root note:", sample.midi_root_note)
  debug_print("  Tuning:", sample.semi_tune, "semitones,", sample.cents_tune, "cents")
  debug_print("  Sample words:", sample.num_sample_words)
  debug_print("  Active loops:", sample.num_active_loops)
  
  return sample
end

-- Create S1000 sample file from Renoise sample
local function create_s1000_sample(sample, filename)
  debug_print("Creating S1000 sample from:", sample.name)
  
  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then
    error("Sample has no data")
  end
  
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  
  -- Convert to mono if stereo
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
  
  -- Create header
  local header = {}
  
  -- Basic header data
  table.insert(header, 3) -- format version
  table.insert(header, sample_rate > 30000 and 1 or 0) -- sample rate flag
  table.insert(header, sample.base_note or 60) -- MIDI root note
  
  -- Filename in AKAII format
  local akaii_name = string_to_akaii(filename or sample.name or "SAMPLE", 12)
  for i = 1, 12 do
    table.insert(header, akaii_name[i])
  end
  
  table.insert(header, 128) -- constant
  
  -- Loop information
  local num_loops = 0
  local loop_start = 1
  local loop_end = frames
  
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    num_loops = 1
    loop_start = sample.loop_start or 1
    loop_end = sample.loop_end or frames
  end
  
  table.insert(header, num_loops) -- num active loops
  table.insert(header, 0) -- padding
  table.insert(header, 0) -- padding
  
  -- Loop mode mapping
  local s1000_loop_mode = 2 -- none
  if sample.loop_mode == renoise.Sample.LOOP_MODE_FORWARD then
    s1000_loop_mode = 1 -- until release
  end
  table.insert(header, s1000_loop_mode)
  
  -- Tuning
  local cents = math.floor((sample.fine_tune or 0) + 0.5)
  local semis = sample.transpose or 0
  cents = math.max(-50, math.min(50, cents))
  semis = math.max(-50, math.min(50, semis))
  table.insert(header, cents < 0 and cents + 256 or cents)
  table.insert(header, semis < 0 and semis + 256 or semis)
  
  -- Padding
  for i = 1, 4 do table.insert(header, 0) end
  
  -- Sample word count and markers
  local word_count_bytes = write_u32_le(frames)
  for i = 1, 4 do table.insert(header, word_count_bytes:byte(i)) end
  
  local start_bytes = write_u32_le(0) -- start marker
  for i = 1, 4 do table.insert(header, start_bytes:byte(i)) end
  
  local end_bytes = write_u32_le(frames - 1) -- end marker  
  for i = 1, 4 do table.insert(header, end_bytes:byte(i)) end
  
  -- Loop data (8 loops, but we only use first one)
  for loop_idx = 1, 8 do
    if loop_idx == 1 and num_loops > 0 then
      -- Active loop
      local loop_marker_bytes = write_u32_le(loop_start - 1)
      for i = 1, 4 do table.insert(header, loop_marker_bytes:byte(i)) end
      
      table.insert(header, 0) -- fine length LSB
      table.insert(header, 0) -- fine length MSB
      
      local coarse_len = loop_end - loop_start + 1
      local coarse_bytes = write_u32_le(coarse_len)
      for i = 1, 4 do table.insert(header, coarse_bytes:byte(i)) end
      
      table.insert(header, 255) -- infinite time LSB
      table.insert(header, 39)  -- infinite time MSB (9999)
    else
      -- Inactive loop
      for i = 1, 12 do table.insert(header, 0) end
    end
  end
  
  -- Final header padding
  table.insert(header, 0); table.insert(header, 0)
  table.insert(header, 255); table.insert(header, 255)
  
  local freq_bytes = write_u16_le(sample_rate)
  table.insert(header, freq_bytes:byte(1))
  table.insert(header, freq_bytes:byte(2))
  
  for i = 1, 10 do table.insert(header, 0) end -- final padding
  
  -- Convert header to string
  local header_str = ""
  for i, byte_val in ipairs(header) do
    header_str = header_str .. string.char(byte_val)
  end
  
  -- Convert sample data to 16-bit signed integers
  local sample_str = ""
  for i = 1, frames do
    local val = math.floor(sample_data[i] * 32767 + 0.5)
    val = math.max(-32768, math.min(32767, val))
    local bytes = write_u16_le(val < 0 and val + 65536 or val)
    sample_str = sample_str .. bytes
  end
  
  debug_print("Created S1000 sample data:", #header_str + #sample_str, "bytes")
  return header_str .. sample_str
end

-- Detect Akai .s format (S900/S950/S1000/S3000)
local function detect_akai_s_format(file_path)
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end
  
  -- Read first 200 bytes for analysis
  local header = f:read(200)
  f:close()
  
  if not header or #header < 150 then
    return nil, "File too small"
  end
  
  -- Check common validation bytes
  local byte1 = header:byte(1)
  local byte16 = header:byte(16)
  
  -- S1000/S3000 validation
  if byte1 == 3 and byte16 == 128 then
    -- Check header size to distinguish S1000 vs S3000
    if #header >= 192 then
      -- Check if there are S3000-specific fields
      local first_active_loop = header:byte(17)
      if first_active_loop ~= nil then
        return "S3000", "S3000 format detected (192-byte header)"
      end
    end
    return "S1000", "S1000 format detected (150-byte header)"
  end
  
  -- S900/S950 format detection (would need different validation)
  -- For now, assume S1000 if basic validation fails
  return "S1000", "Assuming S1000 format (fallback)"
end

-- Import S1000/S3000 sample with auto-detection
function importS1000Sample(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.s"}, "Import Akai Sample (.s)"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  print("---------------------------------")
  debug_print("Analyzing Akai .s file:", file_path)
  
  -- Detect format
  local format, reason = detect_akai_s_format(file_path)
  debug_print("Format detection:", format, "-", reason)
  
  -- Route to appropriate importer
  if format == "S3000" then
    debug_print("Routing to S3000 importer")
    importS3000Sample(file_path)
  elseif format == "S900" then
    debug_print("Routing to S900 importer")
    importS900Sample(file_path)
  else
    debug_print("Routing to S1000 importer")
    -- Continue with S1000 import
    print("---------------------------------")
    debug_print("Importing S1000 sample:", file_path)
    
    local f, err = io.open(file_path, "rb")
    if not f then
      error("Could not open file: " .. err)
    end
    local data = f:read("*all")
    f:close()
    
    local s1000_sample = parse_s1000_sample(data)
    
    -- Create new instrument in Renoise
    local song = renoise.song()
    local current_idx = song.selected_instrument_index
    local new_idx = current_idx + 1
    if not safeInsertInstrumentAt(song, new_idx) then return end
    song.selected_instrument_index = new_idx
    
    local instrument = song.instruments[new_idx]
    instrument.name = s1000_sample.filename
    
    -- Create sample
    instrument:insert_sample_at(1)
    local sample = instrument.samples[1]
    sample.name = s1000_sample.filename
    
    -- Load sample data
    sample.sample_buffer:create_sample_data(s1000_sample.sampling_frequency, 16, 1, #s1000_sample.sample_data)
    sample.sample_buffer:prepare_sample_data_changes()
    for i = 1, #s1000_sample.sample_data do
      sample.sample_buffer:set_sample_data(1, i, s1000_sample.sample_data[i])
    end
    sample.sample_buffer:finalize_sample_data_changes()
    
    -- Apply sample properties
    sample.transpose = s1000_sample.semi_tune
    sample.fine_tune = s1000_sample.cents_tune
    sample.sample_mapping.base_note = s1000_sample.midi_root_note
    
    -- Set loop if present
    if s1000_sample.num_active_loops > 0 and s1000_sample.loops[1].marker > 0 then
      sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      sample.loop_start = s1000_sample.loops[1].marker + 1
      sample.loop_end = math.min(sample.loop_start + s1000_sample.loops[1].coarse_length - 1, #s1000_sample.sample_data)
    end
    
    renoise.app():show_status("Imported S1000 sample: " .. s1000_sample.filename)
    debug_print("Import complete")
  end
end

-- Export current sample as S1000
function exportS1000Sample()
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
  
  local output_path = renoise.app():prompt_for_filename_to_write("*.s", "Export S1000 Sample")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  -- Ensure .s extension
  if not output_path:lower():match("%.s$") then
    output_path = output_path:gsub("%.[^.]*$", "") .. ".s"
  end
  
  print("---------------------------------")
  debug_print("Exporting S1000 sample:", sample.name)
  
  local filename = output_path:match("[^/\\]+$"):gsub("%.s$", "")
  local file_data = create_s1000_sample(sample, filename)
  
  local f, err = io.open(output_path, "wb")
  if not f then
    error("Could not create file: " .. err)
  end
  f:write(file_data)
  f:close()
  
  renoise.app():show_status("Exported S1000 sample: " .. filename)
  debug_print("Export complete:", #file_data, "bytes")
end

-- Menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Export S1000 Sample...",invoke = exportS1000Sample}
renoise.tool():add_keybinding{name = "Global:Paketti:Import S1000 Sample...",invoke = importS1000Sample}



-- File import hook for S1000/S3000 samples
local s1000_integration = {
  name = "Akai S1000/S3000 Sample",
  category = "sample", 
  extensions = { "s" },
  invoke = importS1000Sample
}

if not renoise.tool():has_file_import_hook("sample", { "s" }) then
  renoise.tool():add_file_import_hook(s1000_integration)
end 