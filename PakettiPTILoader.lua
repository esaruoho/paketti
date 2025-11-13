local bit = require("bit")

function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then 
    -- Handle both PTI and MTI files
    local clean = filename:gsub("%.pti$", ""):gsub("%.mti$", "")
    return clean
  end
  return "Sample"
end

function read_uint16_le(data, offset)
  return string.byte(data, offset + 1) + string.byte(data, offset + 2) * 256
end

local function read_uint32_le(data, offset)
  return string.byte(data, offset + 1) +
         string.byte(data, offset + 2) * 256 +
         string.byte(data, offset + 3) * 65536 +
         string.byte(data, offset + 4) * 16777216
end

function PakettiPTIDetectAndPrintSliceNotes(playback_mode, slice_count, slice_frames, instrument_name)
  -- Only process for Slice (4) or Beat Slice (5) modes
  if not (playback_mode == 4 or playback_mode == 5) or slice_count == 0 then
    return
  end

  local mode_name = (playback_mode == 4) and "Slice" or "Beat Slice"
  print(string.format("-- PTI %s Mode Detected: %s", mode_name, instrument_name))
  print(string.format("-- Slice Count: %d", slice_count))
  print("-- Expected Slice Notes:")

  -- Note names for chromatic mapping starting from C-2 (note 36) - standard drum machine mapping
  local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  
  for i = 0, slice_count - 1 do
    -- Calculate note number starting from C-2 (36) - matches MTP and standard drum machine mapping
    local note_number = 36 + i
    local octave = math.floor(note_number / 12) - 1
    local note_index = (note_number % 12) + 1
    local note_name = note_names[note_index] .. octave
    
    -- Get slice frame position if available
    local frame_info = ""
    if slice_frames and slice_frames[i + 1] then
      frame_info = string.format(" (frame: %d)", slice_frames[i + 1])
    end
    
    print(string.format("   Slice %02d -> %s%s", i, note_name, frame_info))
  end
  print("-- End of slice note mapping")
end

function pti_loadsample(filepath)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Start ProcessSlicer for PTI loading
  local dialog, vb
  local process_slicer = ProcessSlicer(function()
    pti_loadsample_Worker(filepath, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Loading PTI Sample...")
  process_slicer:start()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

--- ProcessSlicer worker function for PTI loading
function pti_loadsample_Worker(filepath, dialog, vb)
  local file = io.open(filepath, "rb")
  if not file then
    _G.pti_is_loading = false -- Clear loading flag on error
    renoise.app():show_error("Cannot open file: " .. filepath)
    return
  end

  print("------------")
  print(string.format("-- PTI: Import filename: %s", filepath))

  local header = file:read(392)
  local sample_length = read_uint32_le(header, 60)
  local pcm_data = file:read("*a")
  file:close()

  -- Validate sample length
  if sample_length == 0 then
    _G.pti_is_loading = false -- Clear loading flag on error
    renoise.app():show_error("PTI Import Error: Sample has no audio data (0 frames)")
    print("-- PTI: Import failed - sample_length is 0")
    return
  end

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
  
  -- Safely access sample_modulation_sets and sample_device_chains with nil checks
  local selected_instrument = renoise.song().instruments[renoise.song().selected_instrument_index]
  if selected_instrument and selected_instrument.sample_modulation_sets and #selected_instrument.sample_modulation_sets > 0 then
    selected_instrument.sample_modulation_sets[1].name = clean_name
  end
  if selected_instrument and selected_instrument.sample_device_chains and #selected_instrument.sample_device_chains > 0 then
    selected_instrument.sample_device_chains[1].name = clean_name
  end

  -- Create the sample buffer using the stereo flag
  smp.sample_buffer:create_sample_data(44100, 16, is_stereo and 2 or 1, sample_length)
  local buffer = smp.sample_buffer

  -- Read slice data according to PTI format specification
  local slice_count = string.byte(header, 377)  -- Offset 376 + 1 for Lua 1-based indexing
  local active_slice = string.byte(header, 378)  -- Offset 377 + 1 for Lua 1-based indexing

  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames", 
    is_stereo and "Stereo" or "Mono", 44100, 16, sample_length))

  -- DEBUG: Read additional header values to compare with export
  local playback_mode = string.byte(header, 77)
  local volume = string.byte(header, 273)
  local panning = string.byte(header, 277)
  local wavetable_flag = string.byte(header, 21)
  
  buffer:prepare_sample_data_changes()

  -- Update progress dialog
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Processing sample data..."
  end
  renoise.app():show_status("PTI Import: Processing sample data...")

  -- Calculate yield interval for reasonable yielding (every 75000 frames max) 
  local yield_interval = math.min(75000, math.max(5000, math.floor(sample_length / 50)))

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
      
      -- Yield periodically to keep UI responsive
      if i % yield_interval == 0 then
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Processing sample data %d%%...", math.floor((i / sample_length) * 100))
          coroutine.yield()
        end
      end
    end
  else
    for i = 1, sample_length do
      local byte_offset = (i - 1) * 2 + 1
      local lo = pcm_data:byte(byte_offset) or 0
      local hi = pcm_data:byte(byte_offset + 1) or 0
      local sample = bit.bor(bit.lshift(hi, 8), lo)
      if sample >= 32768 then sample = sample - 65536 end
      buffer:set_sample_data(1, i, sample / 32768)
      
      -- Yield periodically to keep UI responsive
      if i % yield_interval == 0 then
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Processing sample data %d%%...", math.floor((i / sample_length) * 100))
          coroutine.yield()
        end
      end
    end
  end
  
  -- Safely finalize sample data changes
  local finalize_success, finalize_error = pcall(function()
    buffer:finalize_sample_data_changes()
  end)
  
  if not finalize_success then
    print(string.format("-- PTI Import: WARNING - Failed to finalize sample buffer: %s", finalize_error))
    renoise.app():show_status("PTI Import: Warning - Sample buffer finalize failed")
    return
  end

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

    -- Update progress for wavetable processing
    if dialog and dialog.visible then
      vb.views.progress_text.text = "Processing wavetable data..."
    end
    renoise.app():show_status("PTI Import: Processing wavetable data...")

    local wavetable_yield_interval = math.min(75000, math.max(5000, math.floor(original_sample_length / 50)))

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
        
        -- Yield for wavetable processing
        if i % wavetable_yield_interval == 0 then
          if dialog and dialog.visible then
            vb.views.progress_text.text = string.format("Processing wavetable %d%%...", math.floor((i / original_sample_length) * 100))
            coroutine.yield()
          end
        end
      end
    else
      for i = 1, original_sample_length do
        local byte_offset = (i - 1) * 2 + 1
        local lo = string.byte(original_pcm_data, byte_offset) or 0
        local hi = string.byte(original_pcm_data, byte_offset + 1) or 0
        local sample = bit.bor(bit.lshift(hi, 8), lo)
        if sample >= 32768 then sample = sample - 65536 end
        wavetable_buffer:set_sample_data(1, i, sample / 32768)
        
        -- Yield for wavetable processing
        if i % wavetable_yield_interval == 0 then
          if dialog and dialog.visible then
            vb.views.progress_text.text = string.format("Processing wavetable %d%%...", math.floor((i / original_sample_length) * 100))
            coroutine.yield()
          end
        end
      end
    end

    -- Safely finalize wavetable sample data changes
    local finalize_success, finalize_error = pcall(function()
      wavetable_buffer:finalize_sample_data_changes()
    end)
    
    if not finalize_success then
      print(string.format("-- PTI Wavetable: WARNING - Failed to finalize wavetable buffer: %s", finalize_error))
      renoise.app():show_status("PTI Import: Warning - Wavetable buffer finalize failed")
      return
    end
    
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
      -- Update progress for wavetable position processing
      if dialog and dialog.visible then
        vb.views.progress_text.text = string.format("Creating wavetable position %d/%d...", pos + 1, wavetable_total_positions)
      end
      
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
      
      -- Yield every wavetable position to keep UI responsive
      if dialog and dialog.visible then
        coroutine.yield()
      end
    end
  
    print(string.format("-- Created wavetable with %d positions, window size %d",
      wavetable_total_positions, wavetable_window))
  else
    print("-- Wavetable Mode: FALSE")
  end

  -- Process slice markers. (Note: slice_count was taken from header at offset 377.)
  local slice_frames = {}
  if slice_count > 0 then
    print(string.format("-- Reading %d slice markers", slice_count))
  end
  for i = 0, slice_count - 1 do
    local offset = 280 + i * 2
    local raw_value = read_uint16_le(header, offset)
    if raw_value >= 0 and raw_value <= 65535 then
      local frame = math.floor((raw_value / 65535) * sample_length)
      table.insert(slice_frames, frame)
    end
  end

  -- Check if we should use Polyend Slice processing instead of normal slice processing
  -- Only process if it's mode 4 (Slice), NOT mode 5 (Beat Slice)
  if slice_count > 0 and playback_mode == 4 and type(PakettiPolyendSliceSwitcherProcessInstrument) == "function" then
    print("-- Attempting Polyend Slice processing")
    local success = PakettiPolyendSliceSwitcherProcessInstrument(
      renoise.song().selected_instrument,
      slice_frames,
      clean_name,
      active_slice or 0
    )
    
    if success then
      renoise.app():show_status(string.format("PTI imported as Polyend Slices: %d slices", slice_count))
      print("-- PTI loaded successfully with Polyend Slice processing")
      return -- Exit early, Polyend processing handles everything
    else
      print("-- Polyend processing failed, continuing with normal slice processing")
    end
  else
    if slice_count > 0 then
      if playback_mode == 5 then
        print(string.format("-- Beat Slice mode (5) PTI detected with %d slices - using normal Renoise slice processing", slice_count))
      else
        print(string.format("-- PTI with %d slices but playback mode %d (not Slice mode 4) - using normal processing", slice_count, playback_mode))
      end
    end
  end

  table.sort(slice_frames)

  -- Print slice notes for Drum Slice PTIs (Slice mode 4 or Beat Slice mode 5)
  PakettiPTIDetectAndPrintSliceNotes(playback_mode, slice_count, slice_frames, clean_name)

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

    -- Set base sample base_note and note_range to B-1 BEFORE inserting slices
    local instrument = renoise.song().selected_instrument
    if instrument.samples[1] then
      instrument.samples[1].sample_mapping.base_note = 35 -- B-1
      instrument.samples[1].sample_mapping.note_range = {35, 35} -- B-1 only
      instrument.samples[1].sample_mapping.velocity_range = {0, 127}
      print(string.format("-- Set base sample base_note=35 (B-1) and note_range={35,35} - slices will auto-map from C-2"))
    end

    -- Apply rescaled slice markers
    for i, frame in ipairs(rescaled_slices) do
      smp:insert_slice_marker(frame + 1)
    end
    
    -- Enable oversampling and preferences for all slices
    for i = 1, #smp.slice_markers do
      local slice_sample = instrument.samples[i + 1]
      if slice_sample then
        -- Apply Paketti loader preferences (slice keyzone mappings are automatic)
        slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        slice_sample.autofade = preferences.pakettiLoaderAutofade.value
        slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
        slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
        slice_sample.new_note_action = preferences.pakettiLoaderNNA.value

      end
    end
    
    print(string.format("-- Applied preferences to %d slice samples", #smp.slice_markers))

  else
    -- Apply original slices if no trim is necessary
    if #slice_frames > 0 then
      -- Set base sample base_note and note_range to B-1 BEFORE inserting slices
      local instrument = renoise.song().selected_instrument
      if instrument.samples[1] then
        instrument.samples[1].sample_mapping.base_note = 35 -- B-1
        instrument.samples[1].sample_mapping.note_range = {35, 35} -- B-1 only
        instrument.samples[1].sample_mapping.velocity_range = {0, 127}
        print(string.format("-- Set base sample base_note=35 (B-1) and note_range={35,35} - slices will auto-map from C-2"))
      end
      
      for i, frame in ipairs(slice_frames) do
        smp:insert_slice_marker(frame + 1)
      end
      
      -- Enable oversampling and preferences for all slices
      for i = 1, #smp.slice_markers do
        local slice_sample = instrument.samples[i + 1]
        if slice_sample then
          -- Apply Paketti loader preferences (slice keyzone mappings are automatic)
          slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
          slice_sample.autofade = preferences.pakettiLoaderAutofade.value
          slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
          slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
          slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
          slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
          slice_sample.new_note_action = preferences.pakettiLoaderNNA.value
        

        end
      end
      
      print(string.format("-- Applied preferences to %d slice samples", #smp.slice_markers))
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
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end

  -- Clear the loading flag 
  _G.pti_is_loading = false

  if total_slices > 0 then
    renoise.app():show_status(string.format("PTI imported with %d slice markers", total_slices))
    print(string.format("-- SUCCESS: PTI loaded with slices - check Sample Editor for slice markers"))
    
    -- Switch to Sample Editor to show the slices
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    print("-- Switched to Sample Editor to display slice markers")
  else
    renoise.app():show_status("PTI imported successfully")
  end
end

-- Separate the hooks - PTI only now
local pti_integration = {
  category = "sample",
  extensions = { "pti" },
  invoke = pti_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "pti" }) then
  renoise.tool():add_file_import_hook(pti_integration)
end

-- New MTI loader function
function find_corresponding_wav(mti_filepath)
  local mti_dir = mti_filepath:match("^(.*[/\\])")
  local mti_filename = mti_filepath:match("([^/\\]+)%.mti$")
  
  if not mti_filename then
    return nil
  end
  
  print(string.format("-- MTI: Looking for WAV file for: %s", mti_filename))
  
  -- Pattern 1: Extract number from instrument_33 or instrument33 patterns
  local inst_num = mti_filename:match("^instrument_?(%d+)$")
  if inst_num then
    local wav_filename = string.format("inst%s.wav", inst_num)
    local wav_path = mti_dir .. wav_filename
    print(string.format("-- MTI: Checking same folder: %s", wav_path))
    
    if io.exists(wav_path) then
      print(string.format("-- MTI: Found WAV file: %s", wav_path))
      return wav_path
    end
  end
  
  -- Pattern 2: If MTI is in instruments/ folder (case-insensitive), look in ../Samples/
  if mti_dir:match("[Ii]nstruments[/\\]?$") then
    local samples_dir = mti_dir:gsub("[Ii]nstruments[/\\]?$", "Samples/")
    print(string.format("-- MTI: Samples directory: %s", samples_dir))
    
    if inst_num then
      local wav_filename = string.format("inst%s.wav", inst_num)
      local wav_path = samples_dir .. wav_filename
      print(string.format("-- MTI: Checking Samples folder: %s", wav_path))
      
      if io.exists(wav_path) then
        print(string.format("-- MTI: Found WAV file in Samples: %s", wav_path))
        return wav_path
      end
    end
    
    -- Also try other common patterns in Samples folder
    local base_patterns = {
      string.format("instr%s.wav", inst_num or ""),
      string.format("instrument%s.wav", inst_num or ""),
      string.format("inst_%s.wav", inst_num or ""),
      string.format("instrument_%s.wav", inst_num or ""),
      mti_filename .. ".wav",
      mti_filename:gsub("instrument_?", "inst") .. ".wav"
    }
    
    for _, pattern in ipairs(base_patterns) do
      if pattern ~= ".wav" and pattern ~= "inst.wav" then -- Skip empty patterns
        local wav_path = samples_dir .. pattern
        print(string.format("-- MTI: Checking pattern: %s", wav_path))
        
        if io.exists(wav_path) then
          print(string.format("-- MTI: Found WAV file with pattern: %s", wav_path))
          return wav_path
        end
      end
    end
  end
  
  -- Pattern 3: Try common variations in same folder
  local variations = {
    mti_filename:gsub("instrument_?", "inst") .. ".wav",
    mti_filename .. ".wav",
    "inst" .. (inst_num or "") .. ".wav",
    "inst_" .. (inst_num or "") .. ".wav"
  }
  
  for _, variation in ipairs(variations) do
    local wav_path = mti_dir .. variation
    print(string.format("-- MTI: Checking variation: %s", wav_path))
    
    if io.exists(wav_path) then
      print(string.format("-- MTI: Found WAV file: %s", wav_path))
      return wav_path
    end
  end
  
  print("-- MTI: No corresponding WAV file found")
  return nil
end

function mti_loadsample(filepath)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  print("------------")
  print(string.format("-- MTI: Import filename: %s", filepath))
  
  -- Find the corresponding WAV file
  local wav_path = find_corresponding_wav(filepath)
  
  if not wav_path then
    renoise.app():show_error("MTI Import Error: Cannot find corresponding WAV file for " .. filepath)
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  print(string.format("-- MTI: Loading audio from: %s", wav_path))
  
  -- Create new instrument and load the WAV file
  local song = renoise.song()
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  -- Apply Paketti defaults first
  pakettiPreferencesDefaultInstrumentLoader()
  
  local instrument = song.selected_instrument
  local sample = instrument.samples[1]
  
  -- Load the WAV file into the sample buffer
  local success, load_result = pcall(function()
    return sample.sample_buffer:load_from(wav_path)
  end)
  
  if not success or not load_result then
    renoise.app():show_error("MTI Import Error: Failed to load WAV file: " .. wav_path)
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  -- Now we have the WAV loaded, let's try to parse the MTI file for additional settings
  local mti_file = io.open(filepath, "rb")
  if not mti_file then
    renoise.app():show_warning("MTI Import Warning: Cannot read MTI file for settings: " .. filepath)
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  local mti_data = mti_file:read("*a")
  mti_file:close()
  
  -- Get the clean filename for naming
  local clean_name = get_clean_filename(filepath)
  
  -- Apply the name to the instrument and sample
  instrument.name = clean_name
  sample.name = clean_name
  
  -- Parse MTI file format 
  print(string.format("-- MTI: Parsing header for slice and loop information (file size: %d bytes)", #mti_data))
  
  if #mti_data >= 392 then
    -- MTI format analysis from hex dumps:
    -- Files start with "TI" (54 49) at offset 0
    -- Look for actual slice count in MTI format
    
    local slice_count = 0
    
    -- Check the filename embedded in the MTI to see if it suggests slicing
    local filename_start = 21 -- Based on hex dumps, filename starts around offset 21
    local embedded_filename = ""
    for i = filename_start, math.min(filename_start + 30, #mti_data) do
      local byte_val = string.byte(mti_data, i)
      if byte_val == 0 then break end
      if byte_val >= 32 and byte_val <= 126 then -- Printable ASCII
        embedded_filename = embedded_filename .. string.char(byte_val)
      end
    end
    
    print(string.format("-- MTI: Embedded filename: '%s'", embedded_filename))
    
    -- For now, most MTI files seem to be single samples, not sliced
    -- Only attempt slicing if the filename suggests it (contains numbers, "slice", etc.)
    if embedded_filename:match("%d+") or embedded_filename:lower():match("slice") or embedded_filename:lower():match("chop") then
      print("-- MTI: Filename suggests possible slicing, checking for slice data...")
      
      -- Try PTI-style slice count as fallback
      local pti_style_slice_count = string.byte(mti_data, 377)
      if pti_style_slice_count > 0 and pti_style_slice_count <= 16 then
        slice_count = pti_style_slice_count
        print(string.format("-- MTI: Using PTI-style slice count: %d", slice_count))
      end
    else
      print("-- MTI: Filename suggests single sample, skipping slice detection")
    end
    
    -- Process slice data if we found a valid slice count
     
         if slice_count > 0 then
      print(string.format("-- MTI: Attempting to read %d slices", slice_count))
      local slice_frames = {}
      local sample_length = sample.sample_buffer.number_of_frames
      
      -- Try PTI-style slice reading 
      for i = 0, slice_count - 1 do
        local offset = 280 + i * 2
        if offset + 1 <= #mti_data then
          local raw_value = read_uint16_le(mti_data, offset)
          if raw_value > 0 and raw_value <= 65535 then -- Only accept non-zero values
            local frame = math.floor((raw_value / 65535) * sample_length)
            if frame > 0 and frame < sample_length then -- Valid frame range
              table.insert(slice_frames, frame)
              print(string.format("-- MTI: Found slice at frame %d", frame))
            end
          end
        end
      end
       
      if #slice_frames > 0 then
        table.sort(slice_frames)
        
        -- Apply slice markers to the loaded sample
        local actually_applied = 0
        
        for i, frame in ipairs(slice_frames) do
          if frame > 1 and frame < sample_length then
            sample:insert_slice_marker(frame)
            actually_applied = actually_applied + 1
            print(string.format("-- MTI: Applied slice %02d at frame: %d", actually_applied, frame))
          end
        end
         
         -- Apply Paketti preferences to slices
         for i = 1, #sample.slice_markers do
           local slice_sample = instrument.samples[i + 1]
           if slice_sample then
             slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
             slice_sample.autofade = preferences.pakettiLoaderAutofade.value
             slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
             slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
             slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
             slice_sample.new_note_action = preferences.pakettiLoaderNNA.value
           end
         end
         
         print(string.format("-- MTI: Applied %d slice markers to sample (found %d potential slices)", actually_applied, #slice_frames))
         if actually_applied > 0 then
           renoise.app():show_status(string.format("MTI imported: %s with %d slices (from %s)", clean_name, actually_applied, wav_path:match("([^/\\]+)$")))
         else
           renoise.app():show_status(string.format("MTI imported: %s (no valid slices found, from %s)", clean_name, wav_path:match("([^/\\]+)$")))
         end
       else
         print("-- MTI: No valid slice markers found")
         renoise.app():show_status(string.format("MTI imported: %s (from %s)", clean_name, wav_path:match("([^/\\]+)$")))
       end
     else
       print("-- MTI: No slice count indicator found")
       renoise.app():show_status(string.format("MTI imported: %s (from %s)", clean_name, wav_path:match("([^/\\]+)$")))
     end
    
    -- Read and apply loop information (same logic as PTI)
    local loop_mode_byte = string.byte(mti_data, 77)
    local loop_start_raw = read_uint16_le(mti_data, 80)
    local loop_end_raw = read_uint16_le(mti_data, 82)
    
    local loop_modes = {
      [0] = renoise.Sample.LOOP_MODE_OFF,
      [1] = renoise.Sample.LOOP_MODE_FORWARD,
      [2] = renoise.Sample.LOOP_MODE_REVERSE,
      [3] = renoise.Sample.LOOP_MODE_PING_PONG
    }
    
    if loop_modes[loop_mode_byte] then
      local sample_length = sample.sample_buffer.number_of_frames
      local function map_loop_point(value, sample_len)
        value = math.max(1, math.min(value, 65534))
        return math.max(1, math.min(math.floor(((value - 1) / 65533) * (sample_len - 1)) + 1, sample_len))
      end
      
      local loop_start_frame = map_loop_point(loop_start_raw, sample_length)
      local loop_end_frame = map_loop_point(loop_end_raw, sample_length)
      loop_end_frame = math.max(loop_start_frame + 1, math.min(loop_end_frame, sample_length))
      
      sample.loop_mode = loop_modes[loop_mode_byte]
      sample.loop_start = loop_start_frame
      sample.loop_end = loop_end_frame
      
      local loop_mode_names = { [0] = "OFF", [1] = "Forward", [2] = "Reverse", [3] = "PingPong" }
      print(string.format("-- MTI: Applied loop mode: %s, Start: %d, End: %d", 
        loop_mode_names[loop_mode_byte] or "OFF", loop_start_frame, loop_end_frame))
    end
  else
    print(string.format("-- MTI: Header too small (%d bytes), skipping slice/loop parsing", #mti_data))
    renoise.app():show_status(string.format("MTI imported: %s (from %s)", clean_name, wav_path:match("([^/\\]+)$")))
  end
  
  print("-- MTI: Import complete")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- New MTI integration hook
local mti_integration = {
  category = "sample",
  extensions = { "mti" },
  invoke = mti_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "mti" }) then
  renoise.tool():add_file_import_hook(mti_integration)
end

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

-- Build a 392-byte header according to .pti spec (GLOBAL)
-- inst: instrument data table
-- beat_slice_mode: optional boolean, if true uses Beat Slice (5) instead of Slice (4)
function buildPTIHeader(inst, beat_slice_mode)
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
  write_at(6, string.char(9))             -- offset 5: format indicator (9 for working files)
  write_at(7, string.char(1))             -- offset 6: should be 1 for working files
  write_at(8, string.char(0))             -- offset 7: padding
  
  -- Additional header fields for proper PTI format (offset 8-19)
  write_at(9, string.char(9,9,9,9))        -- offset 8-11: unknown block (9,9,9,9 for working)
  write_at(13, string.char(116))           -- offset 12: unknown (116 for working)
  write_at(14, string.char(1))             -- offset 13: unknown (1 for working)
  write_at(17, string.char(1))             -- offset 16: unknown (1 for working)
  
  -- Wavetable flag (offset 20) - always false for sliced samples
  local is_wavetable = inst.is_wavetable and not (inst.slice_markers and #inst.slice_markers > 0)
  write_at(21, string.char(is_wavetable and 1 or 0))
  print(string.format("-- buildPTIHeader: Writing wavetable flag = %s at offset 20", is_wavetable and "true" or "false"))
  
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
  
  -- Additional fields for proper PTI format (offsets 56-70)
  write_at(57, string.char(1,0,0,0))       -- offset 56-59: unknown non-zero block
  write_at(65, string.char(0))             -- offset 64: padding  
  write_at(66, string.char(8))             -- offset 65: wavetable window size high byte (8 = 2048)
  write_at(69, string.char(94))            -- offset 68: wavetable total positions (94 for working)
  
  -- Determine PTI playback mode
  local pti_playback_mode = 0 -- Default: 1-Shot
  
  -- Check if sample has slices - if so, use Slice or Beat Slice mode
  local has_slices = inst.slice_markers and #inst.slice_markers > 0
  
  if has_slices then
    -- Use Beat Slice mode (5) for drumkits, Slice mode (4) for melodic slices
    if beat_slice_mode then
      pti_playback_mode = 5 -- Beat slice mode for drumkits
      print("-- buildPTIHeader: Setting playback mode to Beat Slice (5) for drumkit")
    else
      pti_playback_mode = 4 -- Slice mode for melodic slices  
      print("-- buildPTIHeader: Setting playback mode to Slice (4) for melodic slice")
    end
  else
    -- Map Renoise loop mode to PTI loop mode (for non-sliced samples)
    local renoise_loop_modes = {
      [renoise.Sample.LOOP_MODE_OFF] = 0,        -- 1-Shot
      [renoise.Sample.LOOP_MODE_FORWARD] = 1,    -- Forward loop
      [renoise.Sample.LOOP_MODE_REVERSE] = 2,    -- Backward loop
      [renoise.Sample.LOOP_MODE_PING_PONG] = 3   -- PingPong loop
    }
    
    if inst.loop_mode and renoise_loop_modes[inst.loop_mode] then
      pti_playback_mode = renoise_loop_modes[inst.loop_mode]
    end
  end
  
  -- Handle playback start/end and loop points based on slice vs loop mode
  if has_slices then
    -- SLICE MODE: Set playback to full range, ignore any loop settings
    print("-- buildPTIHeader: SLICE MODE - ignoring loop settings, using full playback range")
    
    -- Write playback start (offset 78-79) - 0 for full start
    write_at(79, string.char(0, 0))
    print("-- buildPTIHeader: Writing playback start = 0 (slice mode)")
    
    -- Write loop start/end to default values (not used in slice mode but set for safety)
    write_at(81, string.char(1, 0))  -- loop start = 1
    write_at(83, string.char(254, 255))  -- loop end = 65534
    print("-- buildPTIHeader: Writing default loop points (ignored in slice mode)")
    
    -- Write playback end (offset 84-85) - full range for slices
    write_at(85, string.char(255, 255))  -- playback end = 65535 (full range)
    print("-- buildPTIHeader: Writing playback end = 65535 (full range for slices)")
    
  else
    -- LOOP MODE: Handle loop points properly, ignore any slice markers
    print("-- buildPTIHeader: LOOP MODE - using loop settings, ignoring any slice markers")
    
    -- Write playback start (offset 78-79) - set to 0 for start of sample
    write_at(79, string.char(0, 0))
    print("-- buildPTIHeader: Writing playback start = 0 (loop mode)")
    
    -- Write loop start at offset 81 (read by read_uint16_le(header, 80))
    -- Use inverse of import mapping: ((frame - 1) / (sample_len - 1)) * 65533 + 1
    local loop_start_raw = math.floor(((inst.loop_start - 1) / (inst.sample_length - 1)) * 65533) + 1
    loop_start_raw = math.max(1, math.min(loop_start_raw, 65534))
    write_at(81, string.char(
      bit.band(loop_start_raw, 0xFF),
      bit.band(bit.rshift(loop_start_raw, 8), 0xFF)
    ))
    
    -- Write loop end at offset 83 (read by read_uint16_le(header, 82))  
    -- Use inverse of import mapping: ((frame - 1) / (sample_len - 1)) * 65533 + 1
    local loop_end_raw = math.floor(((inst.loop_end - 1) / (inst.sample_length - 1)) * 65533) + 1
    loop_end_raw = math.max(1, math.min(loop_end_raw, 65534))
    write_at(83, string.char(
      bit.band(loop_end_raw, 0xFF),
      bit.band(bit.rshift(loop_end_raw, 8), 0xFF)
    ))
    
    -- Write playback end (offset 84-85) - set for better zoom if sample has loops
    local playback_end = 65535 -- Default to full range
    
    -- If sample has loop points, use loop end as playback end for better zoom
    if inst.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and inst.loop_end > inst.loop_start then
      -- Use the same inverse mapping as loop points for consistency
      playback_end = math.floor(((inst.loop_end - 1) / (inst.sample_length - 1)) * 65535) + 0
      playback_end = math.max(0, math.min(playback_end, 65535))
      print(string.format("-- buildPTIHeader: Using loop end for playback end: %d", playback_end))
    end
    
    write_at(85, string.char(
      bit.band(playback_end, 0xFF),
      bit.band(bit.rshift(playback_end, 8), 0xFF)
    ))
    print(string.format("-- buildPTIHeader: Writing playback end = %d at offset 84", playback_end))
    
    print(string.format("-- buildPTIHeader: Converting loop points: start=%d->%d, end=%d->%d", 
      inst.loop_start, loop_start_raw, inst.loop_end, loop_end_raw))
  end
  
  -- Write playback mode (offset 76)
  write_at(77, string.char(pti_playback_mode))
  print(string.format("-- buildPTIHeader: Writing playback mode %d at offset 76", pti_playback_mode))
  
  -- Handle slice markers - only write if in slice mode
  if has_slices then
    -- Write slice markers (offset 280-375, 48 markers × 2 bytes each)
    local slice_markers = inst.slice_markers or {}
    local num_slices = math.min(48, #slice_markers)
    
    print(string.format("-- buildPTIHeader: Writing %d slices (from %d total)", num_slices, #slice_markers))
    
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
    print(string.format("-- buildPTIHeader: Wrote slice count %d at offset 376", num_slices))
    
  else
    -- LOOP MODE: Zero out slice data to be safe
    print("-- buildPTIHeader: LOOP MODE - zeroing slice markers")
    -- Zero out all slice marker positions (offset 280-375)
    for i = 0, 47 do
      local offset = 280 + i * 2
      write_at(offset + 1, string.char(0, 0))
    end
    -- Write slice count = 0 (offset 376)
    write_at(377, string.char(0))
    print("-- buildPTIHeader: Wrote slice count = 0 (loop mode)")
  end
  
  -- Write volume (offset 272) - 50 for working files  
  write_at(273, string.char(50))
  print("-- buildPTIHeader: Writing volume = 50 (working file standard) at offset 272")
  
  -- Write panning (offset 276) - 50 = center (0), 0-100 maps to -50/+50
  write_at(277, string.char(50))
  print("-- buildPTIHeader: Writing panning = 50 (center) at offset 276")
  
  -- Write active slice (offset 377) - which slice is selected
  if has_slices then
    local slice_count = math.min(48, #(inst.slice_markers or {}))
    -- Only use current_selected_slice for melodic slice exports (when paketti_melodic_slice_mode is true)
    -- For regular beat slice PTI saves, always use 0 as active slice
    local active_slice = 0
    if paketti_melodic_slice_mode and current_selected_slice then
      active_slice = current_selected_slice
      print(string.format("-- buildPTIHeader: Melodic slice mode - using selected slice %d", active_slice))
    else
      print("-- buildPTIHeader: Regular beat slice PTI - using slice 0")
    end
    write_at(378, string.char(active_slice))
    print(string.format("-- buildPTIHeader: Wrote active slice %d at offset 377", active_slice))
  end
  
  -- Additional missing fields for proper PTI format
  -- Only write granular length for non-sliced samples (granular mode)
  if not has_slices then
    -- Granular length (offset 378-379) - 441 = 10ms for working files
    write_at(379, string.char(185, 1))       -- 441 as 16-bit LE (185 + 1*256 = 441)
    print("-- buildPTIHeader: Writing granular length = 441 (10ms) at offset 378-379")
  end
  
  -- Bit depth (offset 386) - 16 for working files
  write_at(387, string.char(16))
  print("-- buildPTIHeader: Writing bit depth = 16 at offset 386")
  
  return header
end

-- Write PCM data mono or stereo
local function write_pcm(f, inst, dialog, vb)
  local buf = inst.sample_buffer
  local channels = inst.channels or 1
  
  -- Calculate yield interval for reasonable yielding (every 75000 frames max)
  local yield_interval = math.min(75000, math.max(5000, math.floor(inst.sample_length / 50)))
  
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
      
      -- Yield periodically for left channel
      if i % yield_interval == 0 then
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Writing left channel %d%%...", math.floor((i / inst.sample_length) * 50))
        end
        if dialog and dialog.visible then
          coroutine.yield()
        end
      end
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
      
      -- Yield periodically for right channel  
      if i % yield_interval == 0 then
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Writing right channel %d%%...", 50 + math.floor((i / inst.sample_length) * 50))
        end
        if dialog and dialog.visible then
          coroutine.yield()
        end
      end
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
      
      -- Yield periodically for mono
      if i % yield_interval == 0 then
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Writing sample data %d%%...", math.floor((i / inst.sample_length) * 100))
        end
        if dialog and dialog.visible then
          coroutine.yield()
        end
      end
    end
  end
end

-- Main save with path parameter
function pti_savesample_to_path(filepath)
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have a valid instrument and sample
  if not inst or #inst.samples == 0 then
    renoise.app():show_error("No instrument or sample selected")
    return false
  end
  
  -- SMART DETECTION: Check if this is a melodic slice instrument
  local is_melodic_slice = PakettiPTIIsMelodicSliceInstrument(inst)
  
  if is_melodic_slice and not paketti_melodic_slice_mode then
    print("-- PTI Save (path): Detected melodic slice instrument - routing to melodic slice export")
    renoise.app():show_status("Detected melodic slice setup - exporting as melodic slice PTI")
    
    -- Route to melodic slice export (which will set paketti_melodic_slice_mode = true and handle saving)
    if PakettiMelodicSliceExportCurrent then
      PakettiMelodicSliceExportCurrent()
      return true -- Export handled by melodic slice function
    else
      print("-- PTI Save (path): PakettiMelodicSliceExportCurrent not available, falling back to regular save")
    end
  end

  -- SLICE DETECTION: Check if samples[1] has slice markers
  local base_sample = inst.samples[1]
  local has_slices = base_sample and #(base_sample.slice_markers or {}) > 0
  
  -- Choose sample to export: samples[1] for slices, selected sample otherwise
  local selected_sample_index = song.selected_sample_index
  local smp
  local export_info
  
  if has_slices then
    -- For slices: always export samples[1] (the base sample with slice markers)
    smp = base_sample
    export_info = string.format("base sample with %d slices", #base_sample.slice_markers)
    print(string.format("-- SLICE MODE: Exporting base sample (Sample 1) with %d slice markers", #base_sample.slice_markers))
  else
    -- For non-sliced: export selected sample
    smp = inst.samples[selected_sample_index]
    if not smp then
      renoise.app():show_error("No sample selected")
      return false
    end
    export_info = string.format("Sample %d: '%s'", selected_sample_index, smp.name)
    print(string.format("-- REGULAR MODE: Exporting selected Sample %d: '%s'", selected_sample_index, smp.name))
  end

  -- PTI FORMAT INFO: Check for multiple samples (info only)
  local total_samples = #inst.samples
  local has_multiple_samples = total_samples > 1

  print("------------")
  print(string.format("-- PTI: Export filename: %s", filepath))
  
  -- Print info about what's being exported
  if has_multiple_samples and not has_slices then
    print(string.format("-- INFO: Instrument has %d samples, exporting %s", total_samples, export_info))
    renoise.app():show_status(string.format("PTI Export: %s", export_info))
  end

  -- Handle slice count limitation (max 48 in PTI format)
  local original_slice_count = #(smp.slice_markers or {})
  local limited_slice_count = math.min(48, original_slice_count)
  
  if original_slice_count > 48 then
    print(string.format("-- NOTE: Sample has %d slices - limiting to 48 slices for PTI format", original_slice_count))
    renoise.app():show_status(string.format("PTI format supports max 48 slices - limiting from %d", original_slice_count))
  end

  -- Extract filename without path and extension for PTI header name
  local pti_name = filepath:match("([^/\\]+)%.pti$") or filepath:match("([^/\\]+)$")
  if pti_name:match("%.pti$") then
    pti_name = pti_name:gsub("%.pti$", "")
  end
  print(string.format("-- PTI Header Name: '%s' (from chosen filename)", pti_name))
  
  -- gather simple inst params
  local data = {
    name = pti_name,
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

  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames", 
    data.channels > 1 and "Stereo" or "Mono",
    44100,
    16,
    data.sample_length
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
  print("-- PTI Format: Full velocity range (0-127), full key range (0-119) as per specification")

  local f = io.open(filepath, "wb")
  if not f then 
    renoise.app():show_error("Cannot write file: " .. filepath)
    return false
  end

  -- Write header and get its size for verification  
  -- Determine if this should be Beat Slice mode (5) or Slice mode (4)
  local use_beat_slice_mode = not paketti_melodic_slice_mode -- Beat Slice for regular saves, Slice for melodic exports
  local header = buildPTIHeader(data, use_beat_slice_mode)
  print(string.format("-- Header size: %d bytes", #header))
  print(string.format("-- PTI Mode: %s", use_beat_slice_mode and "Beat Slice (5)" or "Slice (4)"))
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

  -- Write PCM data (without ProcessSlicer for pti_savesample_to_path)
  local pcm_start_pos = f:seek()
  write_pcm(f, { sample_buffer = smp.sample_buffer, sample_length = data.sample_length, channels = data.channels }, nil, nil)
  local pcm_end_pos = f:seek()
  local pcm_size = pcm_end_pos - pcm_start_pos
  
  print(string.format("-- PCM data size: %d bytes", pcm_size))
  print(string.format("-- Total file size: %d bytes", pcm_end_pos))

  f:close()

  -- Show final status
  if original_slice_count > 0 then
    if original_slice_count > 48 then
      renoise.app():show_status(string.format("PTI exported: '%s' with 48 slices (limited from %d)", smp.name, original_slice_count))
    else
      renoise.app():show_status(string.format("PTI exported: '%s' with %d slices", smp.name, original_slice_count))
    end
  else
    renoise.app():show_status(string.format("PTI exported: '%s'", smp.name))
  end
  
  -- Clear melodic slice mode flag after PTI export is complete
  paketti_melodic_slice_mode = false
  
  return true
end

-- Main save
function pti_savesample()
  -- Start ProcessSlicer for PTI saving
  local dialog, vb
  local process_slicer = ProcessSlicer(function()
    pti_savesample_Worker(dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Saving PTI Sample...")
  process_slicer:start()
end

-- Function to detect if instrument is set up as melodic slice instrument
function PakettiPTIIsMelodicSliceInstrument(inst)
  if not inst or #inst.samples < 2 or #inst.samples > 48 then
    return false
  end
  
  -- Check if first sample is active (00-7F) and others are inactive (00-00)
  local first_sample = inst.samples[1]
  if not first_sample then return false end
  
  local first_vel = first_sample.sample_mapping.velocity_range
  if not first_vel or first_vel[1] ~= 0 or first_vel[2] ~= 127 then
    return false -- First sample should be 00-7F
  end
  
  -- Check that remaining samples are all inactive (00-00)
  for i = 2, #inst.samples do
    local sample = inst.samples[i]
    if sample then
      local vel_range = sample.sample_mapping.velocity_range
      if not vel_range or vel_range[1] ~= 0 or vel_range[2] ~= 0 then
        return false -- Other samples should be 00-00
      end
    end
  end
  
  print(string.format("-- PTI Save: Detected melodic slice instrument: %d samples (first active 00-7F, others inactive 00-00)", #inst.samples))
  return true
end

--- ProcessSlicer worker function for PTI saving
function pti_savesample_Worker(dialog, vb)
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have a valid instrument and sample
  if not inst or #inst.samples == 0 then
    renoise.app():show_status("No instrument or sample selected")
    if dialog and dialog.visible then
      dialog:close()
    end
    paketti_melodic_slice_mode = false -- Clear flag on error
    return
  end
  
  -- SMART DETECTION: Check if this is a melodic slice instrument
  local is_melodic_slice = PakettiPTIIsMelodicSliceInstrument(inst)
  
  if is_melodic_slice and not paketti_melodic_slice_mode then
    print("-- PTI Save: Detected melodic slice instrument - routing to melodic slice export")
    renoise.app():show_status("Detected melodic slice setup - exporting as melodic slice PTI")
    
    -- Close current dialog
    if dialog and dialog.visible then
      dialog:close()
    end
    
    -- Route to melodic slice export (which will set paketti_melodic_slice_mode = true)
    if PakettiMelodicSliceExportCurrent then
      PakettiMelodicSliceExportCurrent()
    else
      print("-- PTI Save: PakettiMelodicSliceExportCurrent not available, falling back to regular save")
    end
    return
  end
  
  -- For regular PTI saves (not melodic slice exports), clear the melodic slice mode
  if not paketti_melodic_slice_mode then
    current_selected_slice = nil -- Clear any leftover value from previous melodic operations
    print("-- PTI Save: Regular save mode - cleared current_selected_slice")
  else
    print("-- PTI Save: Melodic slice export mode - using current_selected_slice")
  end

  -- MELODIC SLICE DETECTION: Check for melodic slice pattern
  local total_samples = #inst.samples
  local is_melodic_slice = false
  local melodic_full_sample = nil
  
  if total_samples > 1 then
    local zero_velocity_samples = 0
    local full_velocity_sample = nil
    local full_velocity_sample_index = nil
    
    print(string.format("-- MELODIC SLICE DETECTION: Checking %d samples for velocity pattern", total_samples))
    
    -- Check velocity ranges of all samples
    for i, sample in ipairs(inst.samples) do
      -- Safe access to velocity range
      local velocity_min, velocity_max
      if sample.sample_mapping and sample.sample_mapping.velocity_range then
        velocity_min = sample.sample_mapping.velocity_range[1]
        velocity_max = sample.sample_mapping.velocity_range[2]
        
        print(string.format("-- Sample %d (%s) velocity range: %02X-%02X", i, sample.name or "unnamed", velocity_min, velocity_max))
        
        if velocity_min == 0 and velocity_max == 0 then
          -- This sample has 00-00 velocity (not velocity mapped)
          zero_velocity_samples = zero_velocity_samples + 1
          print(string.format("-- Sample %d: Zero velocity (00-00) - count now %d", i, zero_velocity_samples))
        elseif velocity_min == 0 and velocity_max == 127 then
          -- This sample has 00-7F velocity (full velocity range)
          full_velocity_sample = sample
          full_velocity_sample_index = i
          print(string.format("-- Sample %d: Full velocity (00-7F) - marked as full velocity sample", i))
        else
          print(string.format("-- Sample %d: Other velocity range (%02X-%02X) - doesn't match melodic pattern", i, velocity_min, velocity_max))
        end
      else
        print(string.format("-- Sample %d: No velocity mapping found, skipping", i))
      end
    end
    
    print(string.format("-- MELODIC SLICE ANALYSIS: %d zero velocity samples, %s full velocity sample", 
      zero_velocity_samples, full_velocity_sample and "1" or "0"))
    
    -- Melodic slice pattern: all samples except one have 00-00, one has 00-7F
    if zero_velocity_samples == (total_samples - 1) and full_velocity_sample then
      is_melodic_slice = true
      melodic_full_sample = full_velocity_sample
      print(string.format("-- MELODIC SLICE DETECTED! Pattern confirmed: %d samples with 00-00, 1 sample (index %d) with 00-7F", 
        zero_velocity_samples, full_velocity_sample_index))
    else
      print(string.format("-- MELODIC SLICE NOT DETECTED: Expected %d zero velocity samples, got %d. Expected 1 full velocity sample, got %s", 
        total_samples - 1, zero_velocity_samples, full_velocity_sample and "1" or "0"))
    end
  else
    print("-- MELODIC SLICE DETECTION: Only 1 sample found, skipping melodic slice detection")
  end
  
  -- SLICE DETECTION: Check if samples[1] has slice markers
  local base_sample = inst.samples[1]
  local has_slices = base_sample and #(base_sample.slice_markers or {}) > 0
  
  -- Choose sample to export based on detection results
  local selected_sample_index = song.selected_sample_index
  local smp
  local export_info
  
  if is_melodic_slice then
    -- MELODIC SLICE MODE: Use existing melodic slice export function (handles everything)
    print(string.format("-- MELODIC SLICE MODE: Detected melodic slice pattern - calling PakettiMelodicSliceExportCurrent()"))
    PakettiMelodicSliceExportCurrent()
    
    -- Close dialog if it exists since the export is complete
    if dialog and dialog.visible then
      dialog:close()
    end
    
    -- Early return - PakettiMelodicSliceExportCurrent handles the entire export process
    return
    
  elseif has_slices then
    -- For traditional slices: always export samples[1] (the base sample with slice markers)
    smp = base_sample
    export_info = string.format("base sample with %d slices", #base_sample.slice_markers)
    print(string.format("-- SLICE MODE: Exporting base sample (Sample 1) with %d slice markers", #base_sample.slice_markers))
    
  else
    -- For regular samples: export selected sample
    smp = inst.samples[selected_sample_index]
    if not smp then
      renoise.app():show_status("No sample selected")
      if dialog and dialog.visible then
        dialog:close()
      end
      return
    end
    export_info = string.format("Sample %d: '%s'", selected_sample_index, smp.name)
    print(string.format("-- REGULAR MODE: Exporting selected Sample %d: '%s'", selected_sample_index, smp.name))
  end

  -- PTI FORMAT INFO: Check for multiple samples (info only)
  local has_multiple_samples = total_samples > 1

  -- Prompt for save location with OS-specific error handling
  local filename = ""
  local os_name = os.platform()
  local success, result = pcall(function()
    if os_name == "WINDOWS" then
      -- Windows has issues with *.pti pattern - use just "pti"
      return renoise.app():prompt_for_filename_to_write("pti", "Save .PTI as...")
    else
      -- macOS and Linux work fine with *.pti pattern
      return renoise.app():prompt_for_filename_to_write("*.pti", "Save .PTI as...")
    end
  end)
  
  if success then
    filename = result
    if filename == "" then
      print("-- PTI Export: User cancelled file dialog")
      renoise.app():show_status("No filename was provided, cancelling Export")
      if dialog and dialog.visible then
        dialog:close()
      end
      return
    end
    
    -- Ensure filename ends with .pti extension (especially important for Windows)
    if not filename:match("%.pti$") then
      filename = filename .. ".pti"
    end
    print("-- PTI Export: Final filename: " .. filename)
  else
    -- File dialog failed - show error and provide alternative
    print("-- PTI Export: File dialog failed - " .. tostring(result))
    renoise.app():show_status("File dialog failed - will use default filename in home directory")
    
    -- Create fallback filename in home directory
    local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
    if home_dir == "" then
      renoise.app():show_error("Cannot determine home directory for fallback save location")
      return
    end
    
    -- Generate safe filename
    local song = renoise.song()
    local inst = song.selected_instrument
    local safe_name = (inst.name or "Sample"):gsub("[^%w%-%_]", "_")
    
    -- Add timestamp to make filename unique
    local timestamp = os.date("%Y%m%d_%H%M%S")
    filename = home_dir .. "/" .. safe_name .. "_" .. timestamp .. ".pti"
    
    print("-- PTI Export: Using fallback filename: " .. filename)
    renoise.app():show_status("Saving to fallback location: " .. filename)
  end

  print("------------")
  print(string.format("-- PTI: Export filename: %s", filename))
  
  -- Print info about what's being exported
  if has_multiple_samples and not has_slices then
    print(string.format("-- INFO: Instrument has %d samples, exporting %s", total_samples, export_info))
    renoise.app():show_status(string.format("PTI Export: %s", export_info))
  end

  -- Handle slice count limitation (max 48 in PTI format)
  local original_slice_count = #(smp.slice_markers or {})
  local limited_slice_count = math.min(48, original_slice_count)
  
  if original_slice_count > 48 then
    print(string.format("-- NOTE: Sample has %d slices - limiting to 48 slices for PTI format", original_slice_count))
    renoise.app():show_status(string.format("PTI format supports max 48 slices - limiting from %d", original_slice_count))
  end

  -- Extract filename without path and extension for PTI header name
  local pti_name = filename:match("([^/\\]+)%.pti$") or filename:match("([^/\\]+)$")
  if pti_name:match("%.pti$") then
    pti_name = pti_name:gsub("%.pti$", "")
  end
  print(string.format("-- PTI Header Name: '%s' (from chosen filename)", pti_name))
  
  -- gather simple inst params
  local data = {
    name = pti_name,
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

  print(string.format("-- Format: %s, %dHz, %d-bit, %d frames", 
    data.channels > 1 and "Stereo" or "Mono",
    44100,
    16,
    data.sample_length
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
  print("-- PTI Format: Full velocity range (0-127), full key range (0-119) as per specification")

  local f = io.open(filename, "wb")
  if not f then 
    renoise.app():show_error("Cannot write file: "..filename)
    return 
  end

  -- Write header and get its size for verification
  -- Determine if this should be Beat Slice mode (5) or Slice mode (4)
  local use_beat_slice_mode = not paketti_melodic_slice_mode -- Beat Slice for regular saves, Slice for melodic exports
  local header = buildPTIHeader(data, use_beat_slice_mode)
  print(string.format("-- Header size: %d bytes", #header))
  print(string.format("-- PTI Mode: %s", use_beat_slice_mode and "Beat Slice (5)" or "Slice (4)"))
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

  -- Write PCM data with ProcessSlicer
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Writing PCM sample data..."
  end
  renoise.app():show_status("PTI Export: Writing PCM sample data...")
  
  local pcm_start_pos = f:seek()
  write_pcm(f, { sample_buffer = smp.sample_buffer, sample_length = data.sample_length, channels = data.channels }, dialog, vb)
  local pcm_end_pos = f:seek()
  local pcm_size = pcm_end_pos - pcm_start_pos
  
  print(string.format("-- PCM data size: %d bytes", pcm_size))
  print(string.format("-- Total file size: %d bytes", pcm_end_pos))

  f:close()

  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end

  -- Show final status
  if original_slice_count > 0 then
    if original_slice_count > 48 then
      renoise.app():show_status(string.format("PTI exported: '%s' with 48 slices (limited from %d)", smp.name, original_slice_count))
    else
      renoise.app():show_status(string.format("PTI exported: '%s' with %d slices", smp.name, original_slice_count))
    end
  else
    renoise.app():show_status(string.format("PTI exported: '%s'", smp.name))
  end
  
  -- Clear melodic slice mode flag after PTI export is complete
  paketti_melodic_slice_mode = false
  print("-- PTI Save: Export complete - cleared melodic slice mode flag")
end

-- PTI Subfolder Export Functions (GLOBAL)
function PakettiExportSubfoldersAsMelodicSlices()
  -- Prompt user to select parent folder
  local parent_folder = renoise.app():prompt_for_path("Select parent folder containing subfolders to export as melodic slice PTIs")
  if not parent_folder or parent_folder == "" then
    renoise.app():show_status("No parent folder selected")
    return
  end
  
  print("------------")
  print("-- PTI Subfolder Export: Melodic Slices from " .. parent_folder)
  
  -- Get subdirectories using existing Renoise function
  local success, subdirs = pcall(os.dirnames, parent_folder)
  if not success or not subdirs or #subdirs == 0 then
    renoise.app():show_status("No subdirectories found in selected folder")
    print("-- No subdirectories found or error accessing: " .. parent_folder)
    return
  end
  
  local separator = package.config:sub(1, 1)
  local exported_count = 0
  
  for _, subdir_name in ipairs(subdirs) do
    -- Skip hidden directories and system folders
    if not subdir_name:match("^%.") then
      local subdir_path = parent_folder .. separator .. subdir_name
      local audio_files = PakettiGetFilesInDirectory(subdir_path)
      
      if #audio_files > 0 and #audio_files <= 48 then
        print(string.format("-- Processing subfolder: %s (%d audio files)", subdir_name, #audio_files))
        
        if #audio_files == 1 then
          -- Single file: create simple instrument mapped C-0 to B-9
          renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
          renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
          
          pakettiPreferencesDefaultInstrumentLoader()
          
          local inst = renoise.song().selected_instrument
          local sample = inst.samples[1]
          
          -- Load the single audio file
          local success_load, load_result = pcall(function()
            return sample.sample_buffer:load_from(audio_files[1])
          end)
          
          if success_load and load_result then
            inst.name = subdir_name
            sample.name = subdir_name
            sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
            sample.sample_mapping.velocity_range = {0, 127}
            
            -- Export as PTI
            local pti_path = parent_folder .. separator .. subdir_name .. ".pti"
            local export_success = pti_savesample_to_path(pti_path)
            if export_success then
              exported_count = exported_count + 1
              print(string.format("-- Exported single sample PTI: %s", pti_path))
            end
          else
            print(string.format("-- Failed to load audio file from %s", subdir_name))
          end
          
        else
          -- Multiple files: create melodic slice setup
          renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
          renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
          
          pakettiPreferencesDefaultInstrumentLoader()
          
          local inst = renoise.song().selected_instrument
          inst.name = subdir_name
          
          -- Delete default sample
          if #inst.samples > 0 then
            inst:delete_sample_at(1)
          end
          
          -- Load up to 48 audio files as separate samples
          local loaded_count = 0
          for i, audio_file in ipairs(audio_files) do
            if i <= 48 then
              local sample = inst:insert_sample_at(#inst.samples + 1)
              local success_load, load_result = pcall(function()
                return sample.sample_buffer:load_from(audio_file)
              end)
              
              if success_load and load_result then
                local file_name = audio_file:match("([^/\\]+)%.%w+$") or ("Sample_" .. i)
                sample.name = file_name
                
                -- Set up melodic slice mapping: first sample active (00-7F), others inactive (00-00)
                if i == 1 then
                  sample.sample_mapping.velocity_range = {0, 127} -- Active sample
                  sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
                else
                  sample.sample_mapping.velocity_range = {0, 0} -- Inactive samples
                  sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
                end
                
                loaded_count = loaded_count + 1
              else
                print(string.format("-- Failed to load audio file: %s", audio_file))
              end
            end
          end
          
          if loaded_count > 0 then
            -- Set melodic slice mode and export
            paketti_melodic_slice_mode = true
            current_selected_slice = 0 -- First slice selected
            
            local pti_path = parent_folder .. separator .. subdir_name .. ".pti"
            local export_success = pti_savesample_to_path(pti_path)
            if export_success then
              exported_count = exported_count + 1
              print(string.format("-- Exported melodic slice PTI: %s (%d samples)", pti_path, loaded_count))
            end
            
            -- Clear melodic slice mode
            paketti_melodic_slice_mode = false
            current_selected_slice = nil
          end
        end
      elseif #audio_files > 48 then
        print(string.format("-- Skipping subfolder %s: too many files (%d), max 48", subdir_name, #audio_files))
      else
        print(string.format("-- Skipping subfolder %s: no audio files found", subdir_name))
      end
    end
  end
  
  renoise.app():show_status(string.format("Melodic slice export complete: %d PTI files created from subfolders", exported_count))
  print(string.format("-- PTI Subfolder Export: Completed melodic slices export - %d PTIs created", exported_count))
end

-- PTI Subfolder Export Functions (GLOBAL)  
function PakettiExportSubfoldersAsDrumSlices()
  -- Prompt user to select parent folder
  local parent_folder = renoise.app():prompt_for_path("Select parent folder containing subfolders to export as drum slice PTIs")
  if not parent_folder or parent_folder == "" then
    renoise.app():show_status("No parent folder selected")
    return
  end
  
  print("------------")
  print("-- PTI Subfolder Export: Drum Slices from " .. parent_folder)
  
  -- Get subdirectories using existing Renoise function
  local success, subdirs = pcall(os.dirnames, parent_folder)
  if not success or not subdirs or #subdirs == 0 then
    renoise.app():show_status("No subdirectories found in selected folder")
    print("-- No subdirectories found or error accessing: " .. parent_folder)
    return
  end
  
  local separator = package.config:sub(1, 1)
  local exported_count = 0
  
  for _, subdir_name in ipairs(subdirs) do
    -- Skip hidden directories and system folders
    if not subdir_name:match("^%.") then
      local subdir_path = parent_folder .. separator .. subdir_name
      local audio_files = PakettiGetFilesInDirectory(subdir_path)
      
      if #audio_files > 0 and #audio_files <= 48 then
        print(string.format("-- Processing subfolder: %s (%d audio files)", subdir_name, #audio_files))
        
        if #audio_files == 1 then
          -- Single file: create simple instrument mapped C-0 to B-9
          renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
          renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
          
          pakettiPreferencesDefaultInstrumentLoader()
          
          local inst = renoise.song().selected_instrument
          local sample = inst.samples[1]
          
          -- Load the single audio file
          local success_load, load_result = pcall(function()
            return sample.sample_buffer:load_from(audio_files[1])
          end)
          
          if success_load and load_result then
            inst.name = subdir_name
            sample.name = subdir_name
            sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
            sample.sample_mapping.velocity_range = {0, 127}
            
            -- Export as PTI (will use Beat Slice mode since paketti_melodic_slice_mode is false)
            local pti_path = parent_folder .. separator .. subdir_name .. ".pti"
            local export_success = pti_savesample_to_path(pti_path)
            if export_success then
              exported_count = exported_count + 1
              print(string.format("-- Exported single sample PTI: %s", pti_path))
            end
          else
            print(string.format("-- Failed to load audio file from %s", subdir_name))
          end
          
        else
          -- Multiple files: create drum slice setup using sample chaining
          renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
          renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
          
          pakettiPreferencesDefaultInstrumentLoader()
          
          local inst = renoise.song().selected_instrument
          inst.name = subdir_name
          local base_sample = inst.samples[1]
          
          -- Create sample chain by concatenating audio files
          local chain_data = {}
          local slice_positions = {}
          local total_frames = 0
          local sample_rate = 44100
          local is_stereo = false
          
          -- First pass: analyze files and determine if we need stereo
          for i, audio_file in ipairs(audio_files) do
            if i <= 48 then
              -- Create temporary instrument to load and analyze file
              local temp_inst_idx = #renoise.song().instruments + 1
              renoise.song():insert_instrument_at(temp_inst_idx)
              local temp_sample = renoise.song().instruments[temp_inst_idx].samples[1]
              
              local success_load = pcall(function()
                temp_sample.sample_buffer:load_from(audio_file)
              end)
              
              if success_load and temp_sample.sample_buffer.has_sample_data then
                local channels = temp_sample.sample_buffer.number_of_channels
                local frames = temp_sample.sample_buffer.number_of_frames
                
                if channels == 2 then
                  is_stereo = true
                end
                
                -- Store sample data temporarily
                chain_data[i] = {
                  frames = frames,
                  channels = channels,
                  data = temp_sample.sample_buffer
                }
                
                slice_positions[i] = total_frames + 1 -- +1 for 1-based indexing
                total_frames = total_frames + frames
                
                print(string.format("-- Sample %d: %d frames, %s", i, frames, channels == 2 and "stereo" or "mono"))
              end
              
              -- Clean up temporary instrument
              renoise.song():delete_instrument_at(temp_inst_idx)
            end
          end
          
          if total_frames > 0 then
            -- Create the chained sample buffer
            base_sample.sample_buffer:create_sample_data(sample_rate, 16, is_stereo and 2 or 1, total_frames)
            base_sample.sample_buffer:prepare_sample_data_changes()
            
            -- Copy data from individual samples into chain
            local current_pos = 1
            for i, sample_info in ipairs(chain_data) do
              if sample_info and sample_info.data and sample_info.data.has_sample_data then
                local frames = sample_info.frames
                local channels = sample_info.channels
                
                for frame = 1, frames do
                  for ch = 1, (is_stereo and 2 or 1) do
                    local value = 0
                    if ch <= channels then
                      value = sample_info.data:sample_data(ch, frame)
                    end
                    base_sample.sample_buffer:set_sample_data(ch, current_pos + frame - 1, value)
                  end
                end
                current_pos = current_pos + frames
              end
            end
            
            base_sample.sample_buffer:finalize_sample_data_changes()
            
            -- Add slice markers for drum slices
            for i = 2, #slice_positions do -- Skip first position (start of sample)
              base_sample:insert_slice_marker(slice_positions[i])
            end
            
            base_sample.name = subdir_name .. " (Drum Chain)"
            
            -- Export as drum slice PTI (Beat Slice mode)
            local pti_path = parent_folder .. separator .. subdir_name .. ".pti"
            local export_success = pti_savesample_to_path(pti_path)
            if export_success then
              exported_count = exported_count + 1
              print(string.format("-- Exported drum slice PTI: %s (%d slices)", pti_path, #slice_positions))
            end
          end
        end
      elseif #audio_files > 48 then
        print(string.format("-- Skipping subfolder %s: too many files (%d), max 48", subdir_name, #audio_files))
      else
        print(string.format("-- Skipping subfolder %s: no audio files found", subdir_name))
      end
    end
  end
  
  renoise.app():show_status(string.format("Drum slice export complete: %d PTI files created from subfolders", exported_count))
  print(string.format("-- PTI Subfolder Export: Completed drum slices export - %d PTIs created", exported_count))
end

renoise.tool():add_keybinding{name="Global:Paketti:PTI Export",invoke = pti_savesample}
renoise.tool():add_keybinding{name="Global:Paketti:Export Subfolders as Melodic Slices",invoke = PakettiExportSubfoldersAsMelodicSlices}
renoise.tool():add_keybinding{name="Global:Paketti:Export Subfolders as Drum Slices",invoke = PakettiExportSubfoldersAsDrumSlices}



