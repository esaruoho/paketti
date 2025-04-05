local bit = require("bit")

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.pti$", "") end
  return "PTI Sample"
end

local function read_uint16_le(data, offset)
  return string.byte(data, offset + 1) + string.byte(data, offset + 2) * 256
end

local function read_uint32_le(data, offset)
  return string.byte(data, offset + 1) +
         string.byte(data, offset + 2) * 256 +
         string.byte(data, offset + 3) * 65536 +
         string.byte(data, offset + 4) * 16777216
end

local function pti_loadsample(filepath)
  local file = io.open(filepath, "rb")
  if not file then
    renoise.app():show_error("Cannot open file: " .. filepath)
    return
  end

  print("------------")
  print(string.format("-- PTI: Import filename: %s", filepath))

  local header = file:read(392)
  local sample_length = read_uint32_le(header, 60)
  local pcm_data = file:read("*a")
  file:close()

  -- Initialize with Paketti default instrument
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1

  pakettiPreferencesDefaultInstrumentLoader()
  local smp = renoise.song().selected_instrument.samples[1]

  -- Set names for instrument, sample, and related components immediately after creation
  local clean_name = get_clean_filename(filepath)
  renoise.song().selected_instrument.name = clean_name
  smp.name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_device_chains[1].name = clean_name

  -- Create and fill sample buffer in the first slot
  smp.sample_buffer:create_sample_data(44100, 16, 1, sample_length)
  local buffer = smp.sample_buffer
  
  -- Read number of valid slices from offset 376
  local slice_count = string.byte(header, 377) -- Lua strings are 1-indexed
  
  -- Print format information with slice count
  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames, sliceCount = %d", 
    "Mono", 44100, 16, sample_length, slice_count))

  buffer:prepare_sample_data_changes()

  for i = 1, sample_length do
    local byte_offset = (i - 1) * 2 + 1
    local lo = pcm_data:byte(byte_offset) or 0
    local hi = pcm_data:byte(byte_offset + 1) or 0
    local sample = bit.bor(bit.lshift(hi, 8), lo)
    if sample >= 32768 then sample = sample - 65536 end
    buffer:set_sample_data(1, i, sample / 32768)
  end

  buffer:finalize_sample_data_changes()

  -- Read loop data
  local loop_mode_byte = string.byte(header, 77) -- offset 76 in 1-based Lua
  local loop_start_raw = read_uint16_le(header, 80)
  local loop_end_raw = read_uint16_le(header, 82)

  local loop_mode_names = {
    [0] = "OFF",
    [1] = "Forward",
    [2] = "Reverse",
    [3] = "PingPong"
  }

  -- Convert to sample frames (PTI spec defines range as 1-65534)
  -- We need to map from 1-65534 to 1-sample_length
  local function map_loop_point(value, sample_len)
    -- Ensure value is in valid range
    value = math.max(1, math.min(value, 65534))
    -- Map from 1-65534 to 1-sample_length
    return math.max(1, math.min(math.floor(((value - 1) / 65533) * (sample_len - 1)) + 1, sample_len))
  end

  local loop_start_frame = map_loop_point(loop_start_raw, sample_length)
  local loop_end_frame = map_loop_point(loop_end_raw, sample_length)

  -- Ensure end is after start and within sample bounds
  loop_end_frame = math.max(loop_start_frame + 1, math.min(loop_end_frame, sample_length))

  -- Calculate loop length
  local loop_length = loop_end_frame - loop_start_frame

  -- Set loop mode
  local loop_modes = {
    [0] = renoise.Sample.LOOP_MODE_OFF,
    [1] = renoise.Sample.LOOP_MODE_FORWARD,
    [2] = renoise.Sample.LOOP_MODE_REVERSE,
    [3] = renoise.Sample.LOOP_MODE_PING_PONG
  }

  smp.loop_mode = loop_modes[loop_mode_byte] or renoise.Sample.LOOP_MODE_OFF
  smp.loop_start = loop_start_frame
  smp.loop_end = loop_end_frame

  -- Print loop information (ensure we show OFF for mode 0)
  print(string.format("-- Loopmode: %s, Start: %d, End: %d, Looplength: %d", 
    loop_mode_names[loop_mode_byte] or "OFF",
    loop_start_frame,
    loop_end_frame,
    loop_length))
 
-- Wavetable detection
local is_wavetable = string.byte(header, 21) -- offset 20 in 1-based Lua
local wavetable_window = read_uint16_le(header, 64)
local wavetable_total_positions = read_uint16_le(header, 68)
local wavetable_position = read_uint16_le(header, 88)

if is_wavetable == 1 then
  print(string.format("-- Wavetable Mode: TRUE, Window: %d, Total Positions: %d, Position: %d (%.2f%%)", 
    wavetable_window,
    wavetable_total_positions,
    wavetable_position,
    (wavetable_total_positions > 0) and (wavetable_position / wavetable_total_positions * 100) or 0))

  -- Calculate wavetable loop points
  local loop_start = wavetable_position * wavetable_window
  local loop_end = loop_start + wavetable_window

  -- Clamp to sample bounds
  loop_start = math.max(1, math.min(loop_start, sample_length - 1))
  loop_end = math.max(loop_start + 1, math.min(loop_end, sample_length))

  print(string.format("-- Original Wavetable Loop: Start = %d, End = %d (Position %d of %d)", 
    loop_start, loop_end, wavetable_position, wavetable_total_positions))

  -- Trim everything before loop start
  local trimmed_length = sample_length - (loop_start - 1)
  local old_data = {}

  -- Store the loop section and everything after it
  for i = 1, trimmed_length do
    old_data[i] = buffer:sample_data(1, i + loop_start - 1)
  end

  -- Recreate the buffer with only the trimmed content
  smp.sample_buffer:create_sample_data(44100, 16, 1, trimmed_length)
  buffer = smp.sample_buffer
  buffer:prepare_sample_data_changes()

  -- Copy the data starting from the loop point
  for i = 1, trimmed_length do
    buffer:set_sample_data(1, i, old_data[i])
  end

  buffer:finalize_sample_data_changes()
  sample_length = trimmed_length -- update for future use

  -- Apply loop to the trimmed sample (loop now starts at beginning)
  smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  smp.loop_start = 1
  smp.loop_end = wavetable_window

  print(string.format("-- Trimmed Wavetable: Total Length = %d, Loop Window = %d", 
    trimmed_length, wavetable_window))
else
  print("-- Wavetable Mode: FALSE")
end


    
-- Process only actual slices
local slice_frames = {}
for i = 0, slice_count - 1 do
  local offset = 280 + i * 2
  local raw_value = read_uint16_le(header, offset)
  if raw_value >= 0 and raw_value <= 65535 then
    local frame = math.floor((raw_value / 65535) * sample_length)
    table.insert(slice_frames, frame)
  end
end

table.sort(slice_frames)

-- Detect audio content length
local abs_threshold = 0.001
local function find_trim_range()
  local nonzero_found = false
  local first, last = 1, sample_length
  for i = 1, sample_length do
    local val = math.abs(buffer:sample_data(1, i))
    if not nonzero_found and val > abs_threshold then
      first = i
      nonzero_found = true
    end
    if val > abs_threshold then
      last = i
    end
  end
  return first, last
end

local _, last_content_frame = find_trim_range()
local keep_ratio = last_content_frame / sample_length

if math.abs(keep_ratio - 0.5) < 0.01 then
  print(string.format("-- Detected 50%% silence: trimming to %d frames", last_content_frame))

  -- Rescale slice markers
  local rescaled_slices = {}
  for _, old_frame in ipairs(slice_frames) do
    local new_frame = math.floor((old_frame / sample_length) * last_content_frame)
    table.insert(rescaled_slices, new_frame)
  end

  -- Trim sample buffer by recreating it
  local trimmed_length = last_content_frame
  local old_data = {}

  for i = 1, trimmed_length do
    old_data[i] = buffer:sample_data(1, i)
  end

  -- Recreate the buffer with only the trimmed content
  smp.sample_buffer:create_sample_data(44100, 16, 1, trimmed_length)
  buffer = smp.sample_buffer
  buffer:prepare_sample_data_changes()

  for i = 1, trimmed_length do
    buffer:set_sample_data(1, i, old_data[i])
  end

  buffer:finalize_sample_data_changes()
  sample_length = trimmed_length -- update for future use

  -- Apply rescaled slices
  for i, frame in ipairs(rescaled_slices) do
    print(string.format("-- Slice %02d at frame: %d", i, frame))
    smp:insert_slice_marker(frame + 1)
  end

  -- Enable oversampling for all slices
  for i = 1, #smp.slice_markers do
    local slice_sample = renoise.song().selected_instrument.samples[i+1]
    if slice_sample then
      slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    end
  end

else
  -- Apply original slices
  if #slice_frames > 0 then
    for i, frame in ipairs(slice_frames) do
      print(string.format("-- Slice %02d at frame: %d", i, frame))
      smp:insert_slice_marker(frame + 1)
    end    
    -- Enable oversampling for all slices
    for i = 1, #smp.slice_markers do
      local slice_sample = renoise.song().selected_instrument.samples[i+1]
      if slice_sample then
        slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      end
    end
  end
end
  -- Apply Paketti Loader defaults before slicing
  smp.autofade = preferences.pakettiLoaderAutofade.value
  smp.autoseek = preferences.pakettiLoaderAutoseek.value
  --  smp.loop_mode = preferences.pakettiLoaderLoopMode.value
  smp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  smp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  smp.oneshot = preferences.pakettiLoaderOneshot.value
  smp.new_note_action = preferences.pakettiLoaderNNA.value
  -- smp.loop_release = preferences.pakettiLoaderLoopExit.value

  -- Show status message
local total_slices = #renoise.song().selected_instrument.samples[1].slice_markers
if total_slices > 0 then
  renoise.app():show_status(string.format("PTI imported with %d slice markers", total_slices))
else
  renoise.app():show_status("PTI imported successfully")
end
end

local pti_integration = {
  category = "sample",
  extensions = { "pti" },
  invoke = pti_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "pti" }) then
  renoise.tool():add_file_import_hook(pti_integration)
end
