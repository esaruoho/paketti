local bit = require("bit")

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then 
    return filename:gsub("%.pti$", "") 
  end
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

  -- Detect if PCM data is mono or stereo
  local expected_mono_bytes = sample_length * 2
  local expected_stereo_bytes = sample_length * 4
  local is_stereo = #pcm_data >= expected_stereo_bytes

  print(string.format("-- PCM data size = %d bytes | Expected mono = %d | Expected stereo = %d | Detected: %s",
    #pcm_data, expected_mono_bytes, expected_stereo_bytes, is_stereo and "Stereo" or "Mono"))

  -- Insert a new instrument and setup with Paketti defaults
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1

  pakettiPreferencesDefaultInstrumentLoader()
  local smp = renoise.song().selected_instrument.samples[1]
  local clean_name = get_clean_filename(filepath)
  renoise.song().selected_instrument.name = clean_name
  smp.name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index]
      .sample_modulation_sets[1].name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index]
      .sample_device_chains[1].name = clean_name

  -- Create the sample buffer using the stereo flag
  smp.sample_buffer:create_sample_data(44100, 16, is_stereo and 2 or 1, sample_length)
  local buffer = smp.sample_buffer

  -- Read the number of valid slices from the header (1-indexed Lua)
  local slice_count = string.byte(header, 377)

  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames, sliceCount = %d", 
    is_stereo and "Stereo" or "Mono", 44100, 16, sample_length, slice_count))
  print(string.format("-- Stereo detected by blockwise comparison: %s", tostring(is_stereo)))

  buffer:prepare_sample_data_changes()

  if is_stereo then
    -- For stereo, left and right channels are stored in two separate blocks.
    local left_offset = 0
    local right_offset = sample_length * 2
  
    for i = 1, sample_length do
      local byteL = left_offset + (i - 1) * 2 + 1
      local byteR = right_offset + (i - 1) * 2 + 1
  
      local loL = pcm_data:byte(byteL) or 0
      local hiL = pcm_data:byte(byteL + 1) or 0
      local loR = pcm_data:byte(byteR) or 0
      local hiR = pcm_data:byte(byteR + 1) or 0
  
      local sampleL = bit.bor(bit.lshift(hiL, 8), loL)
      local sampleR = bit.bor(bit.lshift(hiR, 8), loR)
  
      if sampleL >= 32768 then sampleL = sampleL - 65536 end
      if sampleR >= 32768 then sampleR = sampleR - 65536 end
  
      buffer:set_sample_data(1, i, sampleL / 32768)
      buffer:set_sample_data(2, i, sampleR / 32768)
    end
  else
    for i = 1, sample_length do
      local byte_offset = (i - 1) * 2 + 1
      local lo = pcm_data:byte(byte_offset) or 0
      local hi = pcm_data:byte(byte_offset + 1) or 0
      local sample = bit.bor(bit.lshift(hi, 8), lo)
      if sample >= 32768 then sample = sample - 65536 end
      buffer:set_sample_data(1, i, sample / 32768)
    end
  end
  
  buffer:finalize_sample_data_changes()

  -- Read loop data from the header
  local loop_mode_byte = string.byte(header, 77)
  local loop_start_raw = read_uint16_le(header, 80)
  local loop_end_raw = read_uint16_le(header, 82)

  local loop_mode_names = {
    [0] = "OFF",
    [1] = "Forward",
    [2] = "Reverse",
    [3] = "PingPong"
  }

  local function map_loop_point(value, sample_len)
    value = math.max(1, math.min(value, 65534))
    return math.max(1, math.min(math.floor(((value - 1) / 65533) * (sample_len - 1)) + 1, sample_len))
  end

  local loop_start_frame = map_loop_point(loop_start_raw, sample_length)
  local loop_end_frame = map_loop_point(loop_end_raw, sample_length)
  loop_end_frame = math.max(loop_start_frame + 1, math.min(loop_end_frame, sample_length))
  local loop_length = loop_end_frame - loop_start_frame

  local loop_modes = {
    [0] = renoise.Sample.LOOP_MODE_OFF,
    [1] = renoise.Sample.LOOP_MODE_FORWARD,
    [2] = renoise.Sample.LOOP_MODE_REVERSE,
    [3] = renoise.Sample.LOOP_MODE_PING_PONG
  }

  smp.loop_mode = loop_modes[loop_mode_byte] or renoise.Sample.LOOP_MODE_OFF
  smp.loop_start = loop_start_frame
  smp.loop_end = loop_end_frame

  print(string.format("-- Loopmode: %s, Start: %d, End: %d, Looplength: %d", 
    loop_mode_names[loop_mode_byte] or "OFF",
    loop_start_frame,
    loop_end_frame,
    loop_length))
 
  -- Wavetable detection
  local is_wavetable = string.byte(header, 21)
  local wavetable_window = read_uint16_le(header, 64)
  local wavetable_total_positions = read_uint16_le(header, 68)
  local wavetable_position = read_uint16_le(header, 88)

  if is_wavetable == 1 then
    print(string.format("-- Wavetable Mode: TRUE, Window: %d, Total Positions: %d, Position: %d (%.2f%%)", 
      wavetable_window,
      wavetable_total_positions,
      wavetable_position,
      (wavetable_total_positions > 0) and (wavetable_position / wavetable_total_positions * 100) or 0))

  
    local loop_start = wavetable_position * wavetable_window
    local loop_end = loop_start + wavetable_window
    loop_start = math.max(1, math.min(loop_start, sample_length - wavetable_window))
    loop_end = loop_start + wavetable_window

    print(string.format("-- Original Wavetable Loop: Start = %d, End = %d (Position %03d of %d)", 
      loop_start, loop_end, wavetable_position, wavetable_total_positions))

    local original_pcm_data = pcm_data
    local original_sample_length = sample_length

    -- Overwrite the current buffer with the complete wavetable data
    smp.sample_buffer:create_sample_data(44100, 16, is_stereo and 2 or 1, sample_length)
    local wavetable_buffer = smp.sample_buffer
    wavetable_buffer:prepare_sample_data_changes()

    if is_stereo then
      local left_offset = 0
      local right_offset = sample_length * 2
      for i = 1, original_sample_length do
        local byteL = left_offset + (i - 1) * 2 + 1
        local byteR = right_offset + (i - 1) * 2 + 1
        local loL = string.byte(original_pcm_data, byteL) or 0
        local hiL = string.byte(original_pcm_data, byteL + 1) or 0
        local loR = string.byte(original_pcm_data, byteR) or 0
        local hiR = string.byte(original_pcm_data, byteR + 1) or 0
        local sampleL = bit.bor(bit.lshift(hiL, 8), loL)
        local sampleR = bit.bor(bit.lshift(hiR, 8), loR)
        if sampleL >= 32768 then sampleL = sampleL - 65536 end
        if sampleR >= 32768 then sampleR = sampleR - 65536 end
        wavetable_buffer:set_sample_data(1, i, sampleL / 32768)
        wavetable_buffer:set_sample_data(2, i, sampleR / 32768)
      end
    else
      for i = 1, original_sample_length do
        local byte_offset = (i - 1) * 2 + 1
        local lo = string.byte(original_pcm_data, byte_offset) or 0
        local hi = string.byte(original_pcm_data, byte_offset + 1) or 0
        local sample = bit.bor(bit.lshift(hi, 8), lo)
        if sample >= 32768 then sample = sample - 65536 end
        wavetable_buffer:set_sample_data(1, i, sample / 32768)
      end
    end

    wavetable_buffer:finalize_sample_data_changes()
    
    -- Set properties for the wavetable slot
    smp.name = clean_name .. " (Wavetable)"
    smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    smp.loop_start = loop_start
    smp.loop_end = loop_end
    smp.volume = 1.0
    smp.sample_mapping.note_range = {0, 119}
    smp.sample_mapping.velocity_range = {0, 0}

    local current_instrument = renoise.song().selected_instrument
    while #current_instrument.samples > 1 do
      current_instrument:delete_sample_at(#current_instrument.samples)
    end

    for pos = 0, wavetable_total_positions - 1 do
      local pos_start = pos * wavetable_window
      local new_sample = current_instrument:insert_sample_at(pos + 2)
      new_sample.sample_buffer:create_sample_data(44100, 16, is_stereo and 2 or 1, wavetable_window)
      local new_buffer = new_sample.sample_buffer
      new_buffer:prepare_sample_data_changes()
      
      if is_stereo then
        local left_offset = 0
        local right_offset = sample_length * 2
        for i = 1, wavetable_window do
          local byteL = left_offset + (pos_start + i - 1) * 2 + 1
          local byteR = right_offset + (pos_start + i - 1) * 2 + 1
          local loL = string.byte(original_pcm_data, byteL) or 0
          local hiL = string.byte(original_pcm_data, byteL + 1) or 0
          local loR = string.byte(original_pcm_data, byteR) or 0
          local hiR = string.byte(original_pcm_data, byteR + 1) or 0
          local sampleL = bit.bor(bit.lshift(hiL, 8), loL)
          local sampleR = bit.bor(bit.lshift(hiR, 8), loR)
          if sampleL >= 32768 then sampleL = sampleL - 65536 end
          if sampleR >= 32768 then sampleR = sampleR - 65536 end
          new_buffer:set_sample_data(1, i, sampleL / 32768)
          new_buffer:set_sample_data(2, i, sampleR / 32768)
        end
      else
        for i = 1, wavetable_window do
          local byte_offset = ((pos_start + i - 1) * 2) + 1
          local lo = string.byte(original_pcm_data, byte_offset) or 0
          local hi = string.byte(original_pcm_data, byte_offset + 1) or 0
          local sample = bit.bor(bit.lshift(hi, 8), lo)
          if sample >= 32768 then sample = sample - 65536 end
          new_buffer:set_sample_data(1, i, sample / 32768)
        end
      end
      
      new_buffer:finalize_sample_data_changes()
      
      local first_val = new_buffer:sample_data(1, 1)
      print(string.format("-- Position %03d first sample value: %.6f", pos, first_val))
  
      new_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      new_sample.loop_start = 1
      new_sample.loop_end = wavetable_window
      new_sample.name = string.format("%s (Pos %03d)", clean_name, pos)
      new_sample.volume = 1.0
      new_sample.sample_mapping.note_range = {0, 119}
  
      if pos == wavetable_position then
        new_sample.sample_mapping.velocity_range = {0, 127}
        print(string.format("-- Setting full velocity range for position %03d", pos))
      else
        new_sample.sample_mapping.velocity_range = {0, 0}
      end
    end
  
    print(string.format("-- Created wavetable with %d positions, window size %d",
      wavetable_total_positions, wavetable_window))
  else
    print("-- Wavetable Mode: FALSE")
  end

  -- Process slice markers. (Note: slice_count was taken from header at offset 377.)
  local slice_frames = {}
  print(string.format("-- DEBUG: Reading slice markers from header, slice_count = %d", slice_count))
  for i = 0, slice_count - 1 do
    local offset = 280 + i * 2
    local raw_value = read_uint16_le(header, offset)
    print(string.format("-- DEBUG: Slice %02d: offset=%d, raw_value=0x%04X (%d)", i+1, offset, raw_value, raw_value))
    if raw_value >= 0 and raw_value <= 65535 then
      local frame = math.floor((raw_value / 65535) * sample_length)
      table.insert(slice_frames, frame)
      print(string.format("-- DEBUG: Slice %02d: calculated frame = %d", i+1, frame))
    end
  end

  table.sort(slice_frames)

  -- Detect audio content length for possible trimming
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

    local rescaled_slices = {}
    for _, old_frame in ipairs(slice_frames) do
      local new_frame = math.floor((old_frame / sample_length) * last_content_frame)
      table.insert(rescaled_slices, new_frame)
    end

    -- Save current sample data before trimming
    local trimmed_length = last_content_frame
    local old_data = {}
    for i = 1, trimmed_length do
      if is_stereo then
        old_data[i] = {
          left = buffer:sample_data(1, i),
          right = buffer:sample_data(2, i)
        }
      else
        old_data[i] = buffer:sample_data(1, i)
      end
    end

    -- Recreate the buffer with the trimmed length, using the stereo flag
    smp.sample_buffer:create_sample_data(44100, 16, is_stereo and 2 or 1, trimmed_length)
    buffer = smp.sample_buffer
    buffer:prepare_sample_data_changes()
    for i = 1, trimmed_length do
      if is_stereo then
        buffer:set_sample_data(1, i, old_data[i].left)
        buffer:set_sample_data(2, i, old_data[i].right)
      else
        buffer:set_sample_data(1, i, old_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    sample_length = trimmed_length  -- update sample_length for later use

    -- Apply rescaled slice markers
    for i, frame in ipairs(rescaled_slices) do
      print(string.format("-- Slice %02d at frame: %d", i, frame))
      smp:insert_slice_marker(frame + 1)
    end

    -- Enable oversampling for all slices
    for i = 1, #smp.slice_markers do
      local slice_sample = renoise.song().selected_instrument.samples[i + 1]
      if slice_sample then
        slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        slice_sample.autofade = preferences.pakettiLoaderAutofade.value
        slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
        slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
        slice_sample.new_note_action = preferences.pakettiLoaderNNA.value

      end
    end

  else
    -- Apply original slices if no trim is necessary
    if #slice_frames > 0 then
      print(string.format("-- DEBUG: Applying %d slice markers without trimming", #slice_frames))
      for i, frame in ipairs(slice_frames) do
        print(string.format("-- Slice %02d at frame: %d", i, frame))
        smp:insert_slice_marker(frame + 1)
      end    
      for i = 1, #smp.slice_markers do
        local slice_sample = renoise.song().selected_instrument.samples[i + 1]
        if slice_sample then
          slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
          slice_sample.autofade = preferences.pakettiLoaderAutofade.value
          slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
          slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
          slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
          slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
          slice_sample.new_note_action = preferences.pakettiLoaderNNA.value
        

        end
      end
    end
  end

  -- Apply Paketti Loader preferences to the sample
  smp.autofade = preferences.pakettiLoaderAutofade.value
  smp.autoseek = preferences.pakettiLoaderAutoseek.value
  smp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  smp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  smp.oneshot = preferences.pakettiLoaderOneshot.value
  smp.new_note_action = preferences.pakettiLoaderNNA.value
  -- smp.loop_release = preferences.pakettiLoaderLoopExit.value

  local total_slices = #renoise.song().selected_instrument.samples[1].slice_markers
  print(string.format("-- DEBUG: Final total slice count: %d", total_slices))
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

renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:Import .PTI (Polyend Tracker Instrument)",
  invoke=function()
    local f = renoise.app():prompt_for_filename_to_read({"*.PTI"}, "Select PTI to import")
    if f and f ~= "" then pti_loadsample(f) end
  end
}







---------
local bit = require("bit")

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
  
  -- Determine playback mode based on slices
  local playback_mode = 0 -- Default: 1-Shot
  if #(inst.slice_markers or {}) > 0 then
    playback_mode = 4 -- Slice mode
  end
  
  -- Sample playback mode (offset 76)
  write_at(77, string.char(playback_mode))
  
  -- Loop points (offset 80-83)
  local loop_start = math.floor(inst.loop_start * 65535 / inst.sample_length)
  local loop_end = math.floor(inst.loop_end * 65535 / inst.sample_length)
  
  write_at(81, string.char(
    bit.band(loop_start, 0xFF),
    bit.band(bit.rshift(loop_start, 8), 0xFF)
  ))
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

-- Main save
local function pti_savesample()
  local song = renoise.song()
  local inst = song.selected_instrument
  local smp = inst.samples[1]

  -- Check if we have a valid instrument and sample
  if not inst or #inst.samples == 0 then
    renoise.app():show_error("No instrument or sample selected")
    return
  end

  -- Prompt for save location with local variable assignment
  local filename = renoise.app():prompt_for_filename_to_write(".pti", "Save .PTI as...")
  if filename == "" then
    return
  end

  print("------------")
  print(string.format("-- PTI: Export filename: %s", filename))

  -- Handle slice count limitation (max 48 in PTI format)
  local original_slice_count = #(smp.slice_markers or {})
  local limited_slice_count = math.min(48, original_slice_count)
  
  if original_slice_count > 48 then
    print(string.format("-- NOTE: Sample has %d slices - limiting to 48 slices for PTI format", original_slice_count))
    renoise.app():show_status(string.format("PTI format supports max 48 slices - limiting from %d", original_slice_count))
  end

  -- gather simple inst params
  local data = {
    name = inst.name,
    is_wavetable = false,
    sample_length = smp.sample_buffer.number_of_frames,
    loop_mode = smp.loop_mode,
    loop_start = smp.loop_start,
    loop_end = smp.loop_end,
    channels = smp.sample_buffer.number_of_channels,
    slice_markers = {} -- Initialize empty slice markers table
  }

  -- Copy up to 48 slice markers
  print(string.format("-- Copying %d slice markers from Renoise sample", limited_slice_count))
  for i = 1, limited_slice_count do
    data.slice_markers[i] = smp.slice_markers[i]
    print(string.format("-- Export slice %02d: Renoise frame position = %d", i, smp.slice_markers[i]))
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
    loop_mode_names[smp.loop_mode] or "OFF",
    smp.loop_start,
    smp.loop_end,
    smp.loop_end - smp.loop_start
  ))

  print(string.format("-- Wavetable Mode: %s", data.is_wavetable and "TRUE" or "FALSE"))

  local f = io.open(filename, "wb")
  if not f then 
    renoise.app():show_error("Cannot write file: "..filename)
    return 
  end

  -- Write header and get its size for verification
  local header = build_header(data)
  print(string.format("-- Header size: %d bytes", #header))
  f:write(header)

  -- Debug first few frames before writing
  local buf = smp.sample_buffer
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
  write_pcm(f, { sample_buffer = smp.sample_buffer, sample_length = data.sample_length, channels = data.channels })
  local pcm_end_pos = f:seek()
  local pcm_size = pcm_end_pos - pcm_start_pos
  
  print(string.format("-- PCM data size: %d bytes", pcm_size))
  print(string.format("-- Total file size: %d bytes", pcm_end_pos))

  f:close()

  -- Show final status
  if original_slice_count > 0 then
    if original_slice_count > 48 then
      renoise.app():show_status(string.format("PTI exported with 48 slices (limited from %d) in Slice mode", original_slice_count))
    else
      renoise.app():show_status(string.format("PTI exported with %d slices in Slice mode", original_slice_count))
    end
  else
    renoise.app():show_status("PTI exported to "..filename)
  end
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Disk Browser Files:Paketti..:Export .PTI Instrument",
  invoke = pti_savesample
}

renoise.tool():add_menu_entry{
  name = "--Sample Editor:Paketti..:Save..:Export .PTI Instrument",
  invoke = pti_savesample
}

renoise.tool():add_menu_entry{
  name = "--Instrument Box:Paketti..:Save..:Export .PTI Instrument",
  invoke = pti_savesample
}

renoise.tool():add_menu_entry{
  name = "--Sample Navigator:Paketti..:Save..:Export .PTI Instrument",
  invoke = pti_savesample
}

renoise.tool():add_menu_entry{
  name = "--Sample Mappings:Paketti..:Save..:Export .PTI Instrument",
  invoke = pti_savesample
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:PTI Export",
  invoke = pti_savesample
}

_AUTO_RELOAD_DEBUG = true

