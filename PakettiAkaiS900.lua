--[[============================================================================
PakettiAkaiS900.lua — S900/S950 Sample Import/Export
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[S900]", ...)
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

-- Write little-endian values
local function write_u16_le(val)
  return string.char(val % 256, math.floor(val / 256) % 256)
end

local function write_u32_le(val)
  return string.char(val % 256, math.floor(val / 256) % 256,
                     math.floor(val / 65536) % 256, math.floor(val / 16777216) % 256)
end

-- Read ASCII string
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
      table.insert(result, 0) -- null padding for S900
    end
  end
  return result
end

-- Decode S900/S950 12-bit sample data
-- This format is very strange: 
-- For N words, first N bytes contain lower 4 bits of first N/2 words and first N/2 words
-- Next N/2 bytes contain upper 8 bits of last N/2 words
local function decode_s900_samples(data, start_pos, num_words)
  local samples = {}
  
  if num_words == 0 then return samples end
  
  debug_print("Decoding S900 samples: start_pos=" .. start_pos .. ", num_words=" .. num_words)
  
  -- First N bytes: interleaved lower 4 bits
  local half_words = math.floor(num_words / 2)
  
  for i = 1, half_words do
    local byte_pos = start_pos + i - 1
    if byte_pos <= #data then
      local byte_val = data:byte(byte_pos)
      
      -- Lower 4 bits of first word (i)
      local lower_4_first = byte_val % 16 -- lower 4 bits
      -- Lower 4 bits of second word (i + half_words)  
      local lower_4_second = math.floor(byte_val / 16) % 16 -- upper 4 bits
      
      -- Get upper 8 bits from the N+1 to N+N/2 section
      local upper_8_first_pos = start_pos + num_words + i - 1
      local upper_8_second_pos = start_pos + num_words + i + half_words - 1
      
      -- First word: combine lower 4 bits with upper 8 bits
      if upper_8_first_pos <= #data then
        local upper_8_first = data:byte(upper_8_first_pos)
        local sample_val_first = lower_4_first + upper_8_first * 16
        -- Convert 12-bit signed to normalized float
        if sample_val_first >= 2048 then sample_val_first = sample_val_first - 4096 end
        table.insert(samples, sample_val_first / 2048.0)
      end
      
      -- Second word (if exists)
      if i + half_words <= num_words and upper_8_second_pos <= #data then
        local upper_8_second = data:byte(upper_8_second_pos)
        local sample_val_second = lower_4_second + upper_8_second * 16
        -- Convert 12-bit signed to normalized float
        if sample_val_second >= 2048 then sample_val_second = sample_val_second - 4096 end
        table.insert(samples, sample_val_second / 2048.0)
      end
    end
  end
  
  -- Handle odd number of words
  if num_words % 2 == 1 then
    local last_word_idx = num_words
    local byte_pos = start_pos + half_words
    if byte_pos <= #data then
      local byte_val = data:byte(byte_pos)
      local lower_4 = byte_val % 16
      
      local upper_8_pos = start_pos + num_words + half_words
      if upper_8_pos <= #data then
        local upper_8 = data:byte(upper_8_pos)
        local sample_val = lower_4 + upper_8 * 16
        if sample_val >= 2048 then sample_val = sample_val - 4096 end
        table.insert(samples, sample_val / 2048.0)
      end
    end
  end
  
  debug_print("Decoded", #samples, "samples from", num_words, "words")
  return samples
end

-- Encode samples to S900/S950 12-bit format
local function encode_s900_samples(samples)
  local num_words = #samples
  if num_words == 0 then return "" end
  
  debug_print("Encoding", num_words, "samples to S900 format")
  
  local result = {}
  local half_words = math.floor(num_words / 2)
  
  -- Convert normalized floats to 12-bit signed values
  local sample_values = {}
  for i = 1, num_words do
    local val = math.floor(samples[i] * 2047 + 0.5)
    val = math.max(-2048, math.min(2047, val))
    if val < 0 then val = val + 4096 end -- convert to unsigned 12-bit
    sample_values[i] = val
  end
  
  -- First N bytes: interleaved lower 4 bits
  for i = 1, half_words do
    local first_idx = i
    local second_idx = i + half_words
    
    local lower_4_first = sample_values[first_idx] % 16
    local lower_4_second = (second_idx <= num_words) and (sample_values[second_idx] % 16) or 0
    
    local combined_byte = lower_4_first + lower_4_second * 16
    table.insert(result, combined_byte)
  end
  
  -- Handle odd number - add the last word's lower 4 bits
  if num_words % 2 == 1 then
    local last_lower_4 = sample_values[num_words] % 16
    table.insert(result, last_lower_4)
  end
  
  -- Next N/2 bytes: upper 8 bits of first N/2 words
  for i = 1, half_words do
    local upper_8 = math.floor(sample_values[i] / 16)
    table.insert(result, upper_8)
  end
  
  -- Next N/2 bytes: upper 8 bits of last N/2 words
  for i = half_words + 1, num_words do
    local upper_8 = math.floor(sample_values[i] / 16)
    table.insert(result, upper_8)
  end
  
  -- Convert to string
  local result_str = ""
  for i, byte_val in ipairs(result) do
    result_str = result_str .. string.char(byte_val % 256)
  end
  
  debug_print("Encoded to", #result_str, "bytes")
  return result_str
end

-- Parse S900/S950 sample file
local function parse_s900_sample(data)
  if #data < 60 then
    error("File too small to be S900/S950 sample")
  end
  
  local sample = {}
  local pos = 1
  
  -- Header parsing (60 bytes for S900/S950)
  sample.filename = read_ascii_string(data, pos, 10); pos = pos + 10
  pos = pos + 6 -- skip 6 zero bytes
  sample.num_sample_words = read_u32_le(data, pos); pos = pos + 4
  sample.sample_rate = read_u16_le(data, pos); pos = pos + 2
  sample.tuning = read_u16_le(data, pos); pos = pos + 2 -- 16ths of semitone, C3=960
  pos = pos + 2 -- skip 2 zero bytes
  sample.loop_mode = string.char(data:byte(pos)); pos = pos + 1 -- O=one-shot, L=loop, A=alt
  pos = pos + 1 -- skip 1 zero byte
  sample.end_marker = read_u32_le(data, pos); pos = pos + 4
  sample.start_marker = read_u32_le(data, pos); pos = pos + 4
  sample.loop_length = read_u32_le(data, pos); pos = pos + 4
  pos = pos + 20 -- skip final 20 bytes
  
  -- Convert tuning from S900 format to more standard values
  -- C3=960 in S900 format, C3=60 in MIDI (each semitone = 16 units)
  local midi_note = math.floor((sample.tuning - 960) / 16) + 60
  local cents = ((sample.tuning - 960) % 16) * 6.25 -- 16 units per semitone = 6.25 cents per unit
  
  sample.midi_note = midi_note
  sample.cents = cents
  
  -- Extract sample data using the complex S900 12-bit packing
  sample.sample_data = decode_s900_samples(data, 61, sample.num_sample_words)
  
  debug_print("Parsed S900/S950 sample:", sample.filename)
  debug_print("  Sample rate:", sample.sample_rate, "Hz")
  debug_print("  Tuning:", sample.tuning, "(MIDI note " .. midi_note .. ", " .. cents .. " cents)")
  debug_print("  Loop mode:", sample.loop_mode)
  debug_print("  Sample words:", sample.num_sample_words)
  debug_print("  Start/End markers:", sample.start_marker, sample.end_marker)
  debug_print("  Loop length:", sample.loop_length)
  debug_print("  Decoded samples:", #sample.sample_data)
  
  return sample
end

-- Create S900/S950 sample file from Renoise sample
local function create_s900_sample(sample, filename)
  debug_print("Creating S900/S950 sample from:", sample.name)
  
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
  
  -- Create header (60 bytes for S900/S950)
  local header = {}
  
  -- Filename (10 bytes, null padded)
  local ascii_name = write_ascii_string(filename or sample.name or "SAMPLE", 10)
  for i = 1, 10 do
    table.insert(header, ascii_name[i])
  end
  
  -- 6 zero bytes
  for i = 1, 6 do table.insert(header, 0) end
  
  -- Number of sample words
  local word_count_bytes = write_u32_le(frames)
  for i = 1, 4 do table.insert(header, word_count_bytes:byte(i)) end
  
  -- Sample rate
  local rate_bytes = write_u16_le(sample_rate)
  table.insert(header, rate_bytes:byte(1))
  table.insert(header, rate_bytes:byte(2))
  
  -- Tuning (16ths of semitone, C3=960)
  local base_note = sample.sample_mapping.base_note or 60
  local fine_tune = sample.fine_tune or 0
  local transpose = sample.transpose or 0
  local total_semitones = (base_note - 60) + transpose + (fine_tune / 100)
  local tuning = 960 + math.floor(total_semitones * 16 + 0.5)
  tuning = math.max(0, math.min(65535, tuning))
  local tuning_bytes = write_u16_le(tuning)
  table.insert(header, tuning_bytes:byte(1))
  table.insert(header, tuning_bytes:byte(2))
  
  -- 2 zero bytes
  table.insert(header, 0); table.insert(header, 0)
  
  -- Loop mode
  local loop_char = "O" -- one-shot
  if sample.loop_mode == renoise.Sample.LOOP_MODE_FORWARD then
    loop_char = "L" -- loop
  end
  table.insert(header, loop_char:byte(1))
  
  -- 1 zero byte
  table.insert(header, 0)
  
  -- End marker
  local end_bytes = write_u32_le(frames - 1)
  for i = 1, 4 do table.insert(header, end_bytes:byte(i)) end
  
  -- Start marker
  local start_bytes = write_u32_le(0)
  for i = 1, 4 do table.insert(header, start_bytes:byte(i)) end
  
  -- Loop length
  local loop_length = 0
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    local loop_start = sample.loop_start or 1
    local loop_end = sample.loop_end or frames
    loop_length = loop_end - loop_start + 1
  end
  local loop_length_bytes = write_u32_le(loop_length)
  for i = 1, 4 do table.insert(header, loop_length_bytes:byte(i)) end
  
  -- Final 20 bytes (magic values from spec)
  local magic = {140,185,0,78,0,0,0,0,0,0,0,0,0,0,224,43,38,0,0,0}
  for i = 1, 20 do
    table.insert(header, magic[i])
  end
  
  -- Convert header to string
  local header_str = ""
  for i, byte_val in ipairs(header) do
    header_str = header_str .. string.char(byte_val)
  end
  
  -- Encode sample data in S900 12-bit format
  local sample_str = encode_s900_samples(sample_data)
  
  debug_print("Created S900/S950 sample data:", #header_str + #sample_str, "bytes")
  return header_str .. sample_str
end

-- Import S900/S950 sample
function importS900Sample(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.s"}, "Import S900/S950 Sample"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  print("---------------------------------")
  debug_print("Importing S900/S950 sample:", file_path)
  
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end
  local data = f:read("*all")
  f:close()
  
  local s900_sample = parse_s900_sample(data)
  
  -- Create new instrument in Renoise
  local song = renoise.song()
  local current_idx = song.selected_instrument_index
  local new_idx = current_idx + 1
  song:insert_instrument_at(new_idx)
  song.selected_instrument_index = new_idx
  
  local instrument = song.instruments[new_idx]
  instrument.name = s900_sample.filename
  
  -- Create sample
  instrument:insert_sample_at(1)
  local sample = instrument.samples[1]
  sample.name = s900_sample.filename
  
  -- Load sample data (convert from 12-bit to 16-bit)
  sample.sample_buffer:create_sample_data(s900_sample.sample_rate, 16, 1, #s900_sample.sample_data)
  sample.sample_buffer:prepare_sample_data_changes()
  for i = 1, #s900_sample.sample_data do
    sample.sample_buffer:set_sample_data(1, i, s900_sample.sample_data[i])
  end
  sample.sample_buffer:finalize_sample_data_changes()
  
  -- Apply sample properties
  sample.sample_mapping.base_note = s900_sample.midi_note
  sample.fine_tune = s900_sample.cents
  
  -- Set loop if present
  if s900_sample.loop_mode == "L" and s900_sample.loop_length > 0 then
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = s900_sample.start_marker + 1
    sample.loop_end = math.min(sample.loop_start + s900_sample.loop_length - 1, #s900_sample.sample_data)
  end
  
  renoise.app():show_status("Imported S900/S950 sample: " .. s900_sample.filename)
  debug_print("Import complete")
end

-- Export current sample as S900/S950
function exportS900Sample()
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
  
  local output_path = renoise.app():prompt_for_filename_to_write("*.s", "Export S900/S950 Sample")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  -- Ensure .s extension
  if not output_path:lower():match("%.s$") then
    output_path = output_path:gsub("%.[^.]*$", "") .. ".s"
  end
  
  print("---------------------------------")
  debug_print("Exporting S900/S950 sample:", sample.name)
  
  local filename = output_path:match("[^/\\]+$"):gsub("%.s$", "")
  local file_data = create_s900_sample(sample, filename)
  
  local f, err = io.open(output_path, "wb")
  if not f then
    error("Could not create file: " .. err)
  end
  f:write(file_data)
  f:close()
  
  renoise.app():show_status("Exported S900/S950 sample: " .. filename)
  debug_print("Export complete:", #file_data, "bytes")
end

-- Menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Import S900/S950 Sample...",invoke = importS900Sample}

renoise.tool():add_keybinding{name = "Global:Paketti:Export S900/S950 Sample...",invoke = exportS900Sample}


-- File import hook for S900/S950 samples  
local s900_integration = {
  name = "Akai S900/S950 Sample",
  category = "sample", 
  extensions = { "s" },
  invoke = importS900Sample
}

if not renoise.tool():has_file_import_hook("sample", { "s" }) then
  renoise.tool():add_file_import_hook(s900_integration)
end 