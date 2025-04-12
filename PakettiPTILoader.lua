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
  for i = 0, slice_count - 1 do
    local offset = 280 + i * 2
    local raw_value = read_uint16_le(header, offset)
    if raw_value >= 0 and raw_value <= 65535 then
      local frame = math.floor((raw_value / 65535) * sample_length)
      table.insert(slice_frames, frame)
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
