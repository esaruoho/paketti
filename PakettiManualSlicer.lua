-- PakettiManualSlicer.lua
-- Creates a new sample where all slices are normalized to the longest slice duration

function paketti_manual_slicer()
  print("--- Paketti Manual Slicer ---")
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Protection: Check if there's a selected instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    print("Error: No instrument selected")
    return
  end
  
  -- Protection: Check if instrument has samples
  if not instrument.samples or #instrument.samples == 0 then
    renoise.app():show_status("Selected instrument has no samples")
    print("Error: Selected instrument has no samples")
    return
  end
  
  local sample = instrument.samples[1]
  
  -- Determine mode: Slice-based or Sample-based
  local has_slices = sample.sample_buffer and sample.sample_buffer.has_sample_data and sample.slice_markers and #sample.slice_markers > 0
  local has_multiple_samples = #instrument.samples > 1
  
  if has_slices then
    print("Mode: Slice-based processing (found " .. #sample.slice_markers .. " slices)")
    
    -- Direct processing without ProcessSlicer (works fine for slices)
    paketti_manual_slicer_slices_worker(instrument, sample)
    
  elseif has_multiple_samples then
    print("Mode: Sample-based processing (found " .. #instrument.samples .. " samples)")
    
    -- Calculate num_samples (limit to 120 samples maximum)
    local num_samples = math.min(120, #instrument.samples)
    
    local dialog, vb
    local process_slicer = ProcessSlicer(function()
      paketti_manual_slicer_samples_worker(instrument, num_samples, dialog, vb)
    end)
    
    dialog, vb = process_slicer:create_dialog("Processing Samples...")
    process_slicer:start()
    
  else
    renoise.app():show_status("No slices or multiple samples found")
    print("Error: Instrument needs either slices in first sample or multiple samples")
    return
  end
end

-- Original slice-based processing (direct, no ProcessSlicer)
function paketti_manual_slicer_slices_worker(instrument, sample)
  local song = renoise.song()
  print("--- Processing Slices ---")
  
  local slice_markers = sample.slice_markers
  local slice_count = #slice_markers
  local sample_buffer = sample.sample_buffer
  local total_frames = sample_buffer.number_of_frames
  local sample_rate = sample_buffer.sample_rate
  local bit_depth = sample_buffer.bit_depth
  local num_channels = sample_buffer.number_of_channels
  
  print("Found " .. slice_count .. " slices in sample")
  print("Original sample: " .. total_frames .. " frames, " .. sample_rate .. "Hz, " .. bit_depth .. "bit, " .. num_channels .. " channels")
  
  -- Calculate target slice count (next power of 2, max 255)
  local target_slice_count = 2
  while target_slice_count < slice_count do
    target_slice_count = target_slice_count * 2
  end
  target_slice_count = math.min(target_slice_count, 255)  -- Cap at 255 (Renoise limit)
  
  local extra_slices = target_slice_count - slice_count
  print("Target slice count: " .. target_slice_count .. " (adding " .. extra_slices .. " silent slices)")
  
  -- Calculate slice lengths and find the longest one
  local slice_lengths = {}
  local longest_slice_frames = 0
  
  for i = 1, slice_count do
    local start_frame = slice_markers[i]
    local end_frame
    
    -- Determine end frame for this slice
    if i < slice_count then
      end_frame = slice_markers[i + 1] - 1
    else
      end_frame = total_frames - 1
    end
    
    local slice_length = end_frame - start_frame + 1
    slice_lengths[i] = slice_length
    
    if slice_length > longest_slice_frames then
      longest_slice_frames = slice_length
    end
    
    print(string.format("Slice %d: frames %d-%d, length = %d frames", 
          i, start_frame, end_frame, slice_length))
  end
  
  print("Longest slice: " .. longest_slice_frames .. " frames")
  
  -- Calculate total frames needed for new sample  
  local new_total_frames = target_slice_count * longest_slice_frames
  print("New sample will be: " .. new_total_frames .. " frames (" .. target_slice_count .. " x " .. longest_slice_frames .. ")")
  
  -- Create new instrument
  local new_instrument = song:insert_instrument_at(song.selected_instrument_index + 1)
  local new_sample = new_instrument:insert_sample_at(1)
  
  -- Create new sample buffer
  new_sample.sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, new_total_frames)
  
  print("Created new sample buffer")
  
  -- Prepare for sample data changes
  new_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Processing slice data directly
  
  -- Copy each slice to the new buffer with padding
  for slice_index = 1, slice_count do
    
    print(string.format("Copying slice %d/%d...", slice_index, slice_count))
    local start_frame = slice_markers[slice_index]
    local end_frame
    
    -- Determine end frame for this slice
    if slice_index < slice_count then
      end_frame = slice_markers[slice_index + 1] - 1
    else
      end_frame = total_frames - 1
    end
    
    local slice_length = slice_lengths[slice_index]
    local new_start_frame = (slice_index - 1) * longest_slice_frames + 1
    
    print(string.format("Copying slice %d: original frames %d-%d (%d frames) -> new frames %d-%d", 
          slice_index, start_frame, end_frame, slice_length, 
          new_start_frame, new_start_frame + slice_length - 1))
    
          -- Copy the actual slice data
      for channel = 1, num_channels do
        for frame = 0, slice_length - 1 do
          local original_frame = start_frame + frame
          local new_frame = new_start_frame + frame
          
          if original_frame <= total_frames and new_frame <= new_total_frames then
            local sample_value = sample_buffer:sample_data(channel, original_frame)
            
            -- Apply 20-frame fadeout at the end of the slice
            local fadeout_frames = 20
            if slice_length > fadeout_frames and frame >= slice_length - fadeout_frames then
              local fade_position = frame - (slice_length - fadeout_frames)
              local fade_factor = 1.0 - (fade_position / fadeout_frames)
              sample_value = sample_value * fade_factor
            end
            
            new_sample.sample_buffer:set_sample_data(channel, new_frame, sample_value)
          end
        end
        
        -- Fill remaining frames with silence (0.0)
        for frame = slice_length, longest_slice_frames - 1 do
          local new_frame = new_start_frame + frame
          if new_frame <= new_total_frames then
            new_sample.sample_buffer:set_sample_data(channel, new_frame, 0.0)
          end
        end
      end
  end
  
  -- Fill extra slices with complete silence
  if extra_slices > 0 then
    print("Filling " .. extra_slices .. " extra slices with silence")

    
    for extra_slice = 1, extra_slices do
      local slice_index = slice_count + extra_slice
      local new_start_frame = (slice_index - 1) * longest_slice_frames + 1
      
      print(string.format("Creating silent slice %d at frames %d-%d", 
            slice_index, new_start_frame, new_start_frame + longest_slice_frames - 1))
      
      -- Fill entire slice with silence
      for channel = 1, num_channels do
        for frame = 0, longest_slice_frames - 1 do
          local new_frame = new_start_frame + frame
          if new_frame <= new_total_frames then
            new_sample.sample_buffer:set_sample_data(channel, new_frame, 0.0)
          end
        end
      end
    end
  end
  
  -- Finalize sample data changes
  new_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Create new slice markers at regular intervals
  print("Creating slice markers...")
  
  for i = 1, target_slice_count do
    local marker_position = (i - 1) * longest_slice_frames + 1
    
    -- Protection: Check Renoise slice marker limit
    local success, error_msg = pcall(function()
      new_sample:insert_slice_marker(marker_position)
    end)
    
    if success then
      print(string.format("Created slice marker %d at frame %d", i, marker_position))
    else
      print(string.format("Warning: Could not create slice marker %d (Renoise limit reached): %s", i, tostring(error_msg)))
      renoise.app():show_status(string.format("Warning: Created %d slices (Renoise limit reached)", i - 1))
      break  -- Stop creating more markers
    end
  end
  
  -- Copy sample settings from original
  new_sample.name = sample.name .. " (Manual Sliced)"
  new_sample.transpose = sample.transpose
  new_sample.fine_tune = sample.fine_tune
  new_sample.volume = sample.volume
  new_sample.panning = sample.panning
  new_sample.loop_mode = sample.loop_mode
  new_sample.loop_start = sample.loop_start
  new_sample.loop_end = sample.loop_end
  
  -- Set instrument name with slice count
  new_instrument.name = instrument.name .. " (" .. target_slice_count .. ") Slice Padded"
  
  -- Select the new instrument
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  local success_message = string.format("Manual Slicer: Created %d slices of %d frames each (%d total frames)",
                                      target_slice_count, longest_slice_frames, new_total_frames)
  renoise.app():show_status(success_message)
  print(success_message)
  print("--- Manual Slicer Complete ---")
end

-- New sample-based processing (convert multiple samples to single sliced sample)
function paketti_manual_slicer_samples_worker(source_instrument, num_samples, dialog, vb)
  local song = renoise.song()
  
  print("-- Manual Slicer Samples: Starting optimized sample processing for instrument: " .. source_instrument.name)
  print(string.format("-- Manual Slicer Samples: Will process %d samples", num_samples))
  
  -- STEP 1: LIGHTWEIGHT SCAN - Calculate max duration without processing
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Scanning sample durations..."
  end
  renoise.app():show_status("Manual Slicer: Scanning sample durations...")
  
  local max_duration_frames = 0
  local sample_info = {}  -- Store basic info for each sample
  
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      local duration_at_48k = math.ceil((sample.sample_buffer.number_of_frames / sample.sample_buffer.sample_rate) * 48000)
      max_duration_frames = math.max(max_duration_frames, duration_at_48k)
      
      -- Store sample info for later processing
      sample_info[i] = {
        original_frames = sample.sample_buffer.number_of_frames,
        original_rate = sample.sample_buffer.sample_rate,
        original_bit = sample.sample_buffer.bit_depth,
        original_channels = sample.sample_buffer.number_of_channels,
        target_frames_48k = duration_at_48k,
        needs_conversion = (sample.sample_buffer.sample_rate ~= 48000) or 
                          (sample.sample_buffer.bit_depth ~= 16) or 
                          (sample.sample_buffer.number_of_channels ~= 1)
      }
      
      print(string.format("-- Manual Slicer: Sample %d: %d frames @ %.1fkHz → %d frames @ 48kHz (convert: %s)", 
        i, sample.sample_buffer.number_of_frames, sample.sample_buffer.sample_rate, 
        duration_at_48k, sample_info[i].needs_conversion and "YES" or "NO"))
    end
    
    -- Lightweight yield every 10 samples during scan
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  
  -- Calculate power of 2 slice count
  local target_slice_count = 2
  while target_slice_count < num_samples do
    target_slice_count = target_slice_count * 2
  end
  target_slice_count = math.min(target_slice_count, 255)  -- Cap at 255 (Renoise limit)
  
  print(string.format("-- Manual Slicer: Max duration: %d frames @ 48kHz", max_duration_frames))
  print(string.format("-- Manual Slicer: Target slice count: %d (from %d samples)", target_slice_count, num_samples))
  
  -- STEP 2: CREATE NEW INSTRUMENT WITH OPTIMIZED PROCESSING
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local new_instrument = song.selected_instrument
  new_instrument.name = string.format("%s (%d) Sample Padded", source_instrument.name, target_slice_count)
  
  -- Calculate total length (all samples padded to max duration)
  local total_frames = max_duration_frames * target_slice_count
  
  -- Create the master sample buffer
  if new_instrument.samples[1] then
    new_instrument:delete_sample_at(1)
  end
  local master_sample = new_instrument:insert_sample_at(1)
  master_sample.sample_buffer:create_sample_data(48000, 16, 1, total_frames)
  master_sample.sample_buffer:prepare_sample_data_changes()
  master_sample.name = new_instrument.name
  
  -- STEP 3: PROCESS AND PAD IN SINGLE PASS
  local current_position = 1
  local slice_positions = {}
  
  for i = 1, target_slice_count do
    table.insert(slice_positions, current_position)
    
    if i <= num_samples then
      local sample = source_instrument.samples[i]
      if sample and sample.sample_buffer.has_sample_data and sample_info[i] then
        
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Processing sample %d/%d...", i, num_samples)
        end
        renoise.app():show_status(string.format("Manual Slicer: Processing sample %d/%d...", i, num_samples))
        
        local info = sample_info[i]
        local processed_frames = 0
        
        if info.needs_conversion then
          -- CONVERT ONLY WHAT'S NEEDED (granular conversion)
          local convert_details = {}
          if info.original_rate ~= 48000 then table.insert(convert_details, string.format("rate %.1f→48kHz", info.original_rate)) end
          if info.original_bit ~= 16 then table.insert(convert_details, string.format("bit %d→16bit", info.original_bit)) end
          if info.original_channels ~= 1 then table.insert(convert_details, string.format("channels %d→1", info.original_channels)) end
          
          print(string.format("-- Manual Slicer: Converting sample %d (%s)", i, table.concat(convert_details, ", ")))
          
          -- Create temp instrument for conversion
          local temp_instrument_index = song.selected_instrument_index + 1
          song:insert_instrument_at(temp_instrument_index)
          song.selected_instrument_index = temp_instrument_index
          local temp_instrument = song.selected_instrument
          
          -- Copy to temp
          local temp_sample = temp_instrument:insert_sample_at(1)
          temp_sample.sample_buffer:create_sample_data(
            info.original_rate, info.original_bit, info.original_channels, info.original_frames)
          temp_sample.sample_buffer:prepare_sample_data_changes()
          
          -- Copy original data with aggressive yielding
          for ch = 1, info.original_channels do
            for frame = 1, info.original_frames do
              temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
              if frame % 100000 == 0 then  -- Yield every 100k frames
                coroutine.yield()
              end
            end
          end
          temp_sample.sample_buffer:finalize_sample_data_changes()
          
          -- GRANULAR CONVERSION: Only convert what needs changing
          song.selected_sample_index = 1
          local target_rate = info.original_rate ~= 48000 and 48000 or info.original_rate
          local target_bit = info.original_bit ~= 16 and 16 or info.original_bit
          -- Always mono output (but only convert if not already mono)
          
          process_sample_adjust("mono", target_rate, target_bit, "none")
          
          -- Copy converted data to master buffer
          processed_frames = temp_sample.sample_buffer.number_of_frames
          for frame = 1, processed_frames do
            master_sample.sample_buffer:set_sample_data(1, current_position + frame - 1, temp_sample.sample_buffer:sample_data(1, frame))
            if frame % 100000 == 0 then  -- Yield every 100k frames
              coroutine.yield()
            end
          end
          
          -- Cleanup temp
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = new_instrument_index
          
          -- CRITICAL: Re-prepare master sample buffer after instrument switching
          master_sample.sample_buffer:prepare_sample_data_changes()
          
        else
          -- NO CONVERSION NEEDED - DIRECT COPY
          print(string.format("-- Manual Slicer: Direct copy sample %d (already 48kHz 16-bit mono)", i))
          processed_frames = info.original_frames
          
          for frame = 1, processed_frames do
            master_sample.sample_buffer:set_sample_data(1, current_position + frame - 1, sample.sample_buffer:sample_data(1, frame))
            if frame % 100000 == 0 then  -- Yield every 100k frames
              coroutine.yield()
            end
          end
        end
        
        -- ADD FADEOUT AND PADDING
        local fadeout_start = current_position + processed_frames - 20
        local fadeout_end = current_position + processed_frames - 1
        
        if fadeout_start > current_position then
          -- Apply 20-frame fadeout
          for frame = fadeout_start, fadeout_end do
            local fade_factor = 1.0 - ((frame - fadeout_start) / 20.0)
            local current_value = master_sample.sample_buffer:sample_data(1, frame)
            master_sample.sample_buffer:set_sample_data(1, frame, current_value * fade_factor)
          end
        end
        
        -- Pad with silence to max duration (remaining frames already zero)
        print(string.format("-- Manual Slicer: Sample %d: %d frames + %d silence = %d total", 
          i, processed_frames, max_duration_frames - processed_frames, max_duration_frames))
        
      else
        -- Empty sample - entire slice is silence (already zero)
        print(string.format("-- Manual Slicer: Sample %d: Empty, filled with silence", i))
      end
    else
      -- Extra power-of-2 slices - entire slice is silence (already zero)
      print(string.format("-- Manual Slicer: Slice %d: Extra power-of-2 slice, filled with silence", i))
    end
    
    current_position = current_position + max_duration_frames
    
    -- Yield every slice
    coroutine.yield()
  end
  
  -- SAFETY: Handle potential prepare/finalize mismatch from instrument switching
  local success, error_msg = pcall(function()
    master_sample.sample_buffer:finalize_sample_data_changes()
  end)
  
  if not success then
    print("-- Manual Slicer: Finalize failed, re-preparing buffer: " .. tostring(error_msg))
    master_sample.sample_buffer:prepare_sample_data_changes()
    master_sample.sample_buffer:finalize_sample_data_changes()
  end
  
  -- STEP 4: CREATE SLICE MARKERS
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating slice markers..."
  end
  renoise.app():show_status("Manual Slicer: Creating slice markers...")
  
  for i = 1, #slice_positions do
    -- Protection: Check Renoise slice marker limit
    local success, error_msg = pcall(function()
      master_sample:insert_slice_marker(slice_positions[i])
    end)
    
    if not success then
      print(string.format("Warning: Could not create slice marker %d (Renoise limit reached): %s", i, tostring(error_msg)))
      renoise.app():show_status(string.format("Warning: Created %d slices (Renoise limit reached)", i - 1))
      break  -- Stop creating more markers
    end
    
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  
  song.selected_sample_index = 1
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status(string.format("✅ Manual Slicer: Created %d uniform slices (max duration: %.2fs)", 
    target_slice_count, max_duration_frames / 48000.0))
  print("-- Manual Slicer Samples: Completed successfully")
end

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Manual Slicer:Fit Slices to Longest Slice with Power of 2 Padding",invoke = paketti_manual_slicer} 
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Fit Slices to Longest Slice with Power of 2 Padding",invoke = paketti_manual_slicer} 