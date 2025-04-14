-- Configuration for process yielding (in seconds)
local PROCESS_YIELD_INTERVAL = 1.5  -- Adjust this value to control how often the process yields

function NormalizeSelectedSliceInSample()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local current_slice = song.selected_sample_index
  local first_sample = instrument.samples[1]
  local current_sample = song.selected_sample
  local last_yield_time = os.clock()
  
  -- Function to check if we should yield
  local function should_yield()
    local current_time = os.clock()
    if current_time - last_yield_time >= PROCESS_YIELD_INTERVAL then
      last_yield_time = current_time
      return true
    end
    return false
  end
  
  -- Check if we have valid data
  if not current_sample or not current_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample available")
    return
  end

  print(string.format("\nSample Selected is Sample Slot %d", song.selected_sample_index))
  print(string.format("Sample Frames Length is 1-%d", current_sample.sample_buffer.number_of_frames))

  -- Case 1: No slice markers - work on current sample
  if #first_sample.slice_markers == 0 then
    local buffer = current_sample.sample_buffer
    local slice_start, slice_end
    
    -- Check for selection in current sample
    if buffer.selection_range[1] and buffer.selection_range[2] then
      slice_start = buffer.selection_range[1]
      slice_end = buffer.selection_range[2]
      print(string.format("Selection in Sample: %d-%d", slice_start, slice_end))
      print("Normalizing: selection in sample")
    else
      slice_start = 1
      slice_end = buffer.number_of_frames
      print("Normalizing: entire sample")
    end
    
    -- Create ProcessSlicer instance and dialog
    local slicer = nil
    local dialog = nil
    local vb = nil
    
    -- Define the process function
    local function process_func()
      local time_start = os.clock()
      local time_reading = 0
      local time_processing = 0
      local total_frames = slice_end - slice_start + 1
      
      print(string.format("\nNormalizing %d frames (%.1f seconds at %dHz)", 
          total_frames, 
          total_frames / buffer.sample_rate,
          buffer.sample_rate))
      
      -- First pass: Find peak and cache data
      local peak = 0
      local processed_frames = 0
      local CHUNK_SIZE = 524288  -- 512KB worth of frames
      
      -- Pre-allocate tables for better performance
      local channel_peaks = {}
      local sample_cache = {}
      for channel = 1, buffer.number_of_channels do
          channel_peaks[channel] = 0
          sample_cache[channel] = {}
      end
      
      buffer:prepare_sample_data_changes()
      
      -- Process in blocks
      for frame = slice_start, slice_end, CHUNK_SIZE do
          local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
          local block_size = block_end - frame + 1
          
          -- Read and process each channel
          for channel = 1, buffer.number_of_channels do
              local read_start = os.clock()
              local channel_peak = 0
              
              -- Cache the data while finding peak
              sample_cache[channel][frame] = {}
              for i = 0, block_size - 1 do
                  local sample_value = buffer:sample_data(channel, frame + i)
                  sample_cache[channel][frame][i] = sample_value
                  local abs_value = math.abs(sample_value)
                  if abs_value > channel_peak then
                      channel_peak = abs_value
                  end
              end
              
              time_reading = time_reading + (os.clock() - read_start)
              if channel_peak > channel_peaks[channel] then
                  channel_peaks[channel] = channel_peak
              end
          end
          
          -- Update progress and check if we should yield
          processed_frames = processed_frames + block_size
          local progress = processed_frames / total_frames
          if dialog and dialog.visible then
              vb.views.progress_text.text = string.format("Finding peak... %.1f%%", progress * 100)
          end
          
          if slicer:was_cancelled() then
              buffer:finalize_sample_data_changes()
              return
          end
          
          if should_yield() then
            coroutine.yield()
          end
      end
      
      -- Find overall peak
      for _, channel_peak in ipairs(channel_peaks) do
          if channel_peak > peak then
              peak = channel_peak
          end
      end
      
      -- Check if sample is silent
      if peak == 0 then
          print("Sample is silent, no normalization needed")
          buffer:finalize_sample_data_changes()
          if dialog and dialog.visible then
              dialog:close()
          end
          return
      end
      
      -- Calculate and display normalization info
      local scale = 1.0 / peak
      local db_increase = 20 * math.log10(scale)
      print(string.format("\nPeak amplitude: %.6f (%.1f dB below full scale)", peak, -db_increase))
      print(string.format("Will increase volume by %.1f dB", db_increase))
      
      -- Reset progress for second pass
      processed_frames = 0
      last_yield_time = os.clock()  -- Reset yield timer for second pass
      
      -- Second pass: Apply normalization using cached data
      for frame = slice_start, slice_end, CHUNK_SIZE do
          local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
          local block_size = block_end - frame + 1
          
          -- Process each channel
          for channel = 1, buffer.number_of_channels do
              local process_start = os.clock()
              
              for i = 0, block_size - 1 do
                  local current_frame = frame + i
                  -- Use cached data instead of reading from buffer again
                  local sample_value = sample_cache[channel][frame][i]
                  buffer:set_sample_data(channel, current_frame, sample_value * scale)
              end
              
              time_processing = time_processing + (os.clock() - process_start)
          end
          
          -- Clear cache for this chunk to free memory
          for channel = 1, buffer.number_of_channels do
              sample_cache[channel][frame] = nil
          end
          
          -- Update progress and check if we should yield
          processed_frames = processed_frames + block_size
          local progress = processed_frames / total_frames
          if dialog and dialog.visible then
              vb.views.progress_text.text = string.format("Normalizing... %.1f%%", progress * 100)
          end
          
          if slicer:was_cancelled() then
              buffer:finalize_sample_data_changes()
              return
          end
          
          if should_yield() then
            coroutine.yield()
          end
      end
      
      -- Clear the entire cache
      sample_cache = nil
      
      -- Finalize changes
      buffer:finalize_sample_data_changes()
      
      -- Calculate and display performance stats
      local total_time = os.clock() - time_start
      local frames_per_second = total_frames / total_time
      print(string.format("\nNormalization complete:"))
      print(string.format("Total time: %.2f seconds (%.1fM frames/sec)", 
          total_time, frames_per_second / 1000000))
      print(string.format("Reading: %.1f%%, Processing: %.1f%%", 
          (time_reading/total_time) * 100,
          ((total_time - time_reading)/total_time) * 100))
      
      -- Close dialog when done
      if dialog and dialog.visible then
          dialog:close()
      end
      
      if buffer.selection_range[1] and buffer.selection_range[2] then
        renoise.app():show_status("Normalized selection in " .. current_sample.name)
      else
        renoise.app():show_status("Normalized " .. current_sample.name)
      end
    end
    
    -- Create and start the ProcessSlicer
    slicer = ProcessSlicer(process_func)
    dialog, vb = slicer:create_dialog("Normalizing Sample")
    slicer:start()
    return
  end

  -- Case 2: Has slice markers
  local buffer = first_sample.sample_buffer
  local slice_start, slice_end
  local slice_markers = first_sample.slice_markers

  -- If we're on the first sample
  if current_slice == 1 then
    -- Check for selection in first sample
    if buffer.selection_range[1] and buffer.selection_range[2] then
      slice_start = buffer.selection_range[1]
      slice_end = buffer.selection_range[2]
      print(string.format("Selection in First Sample: %d-%d", slice_start, slice_end))
      print("Normalizing: selection in first sample")
    else
      slice_start = 1
      slice_end = buffer.number_of_frames
      print("Normalizing: entire first sample")
    end
  else
    -- Get slice boundaries
    slice_start = current_slice > 1 and slice_markers[current_slice - 1] or 1
    local slice_end_marker = slice_markers[current_slice] or buffer.number_of_frames
    local slice_length = slice_end_marker - slice_start + 1

    print(string.format("Selection is within Slice %d", current_slice))
    print(string.format("Slice %d length is %d-%d (length: %d), within 1-%d of sample frames length", 
      current_slice, slice_start, slice_end_marker, slice_length, buffer.number_of_frames))

    -- When in a slice, check the current_sample's selection range (slice view)
    local current_buffer = current_sample.sample_buffer
    
    -- Debug selection values
    print(string.format("Current sample selection range: start=%s, end=%s", 
      tostring(current_buffer.selection_range[1]), tostring(current_buffer.selection_range[2])))
    
    -- Check if there's a selection in the current slice view
    if current_buffer.selection_range[1] and current_buffer.selection_range[2] then
      local rel_sel_start = current_buffer.selection_range[1]
      local rel_sel_end = current_buffer.selection_range[2]
      
      -- Convert slice-relative selection to absolute position in sample
      local abs_sel_start = slice_start + rel_sel_start - 1
      local abs_sel_end = slice_start + rel_sel_end - 1
      
      print(string.format("Selection %d-%d in slice view converts to %d-%d in sample", 
        rel_sel_start, rel_sel_end, abs_sel_start, abs_sel_end))
          
      -- Use the converted absolute positions
      slice_start = abs_sel_start
      slice_end = abs_sel_end
      print("Normalizing: selection in slice")
    else
      -- No selection in slice view - normalize whole slice
      slice_end = slice_end_marker
      print("Normalizing: entire slice (no selection in slice view)")
    end
  end

  -- Ensure we don't exceed buffer bounds
  slice_start = math.max(1, math.min(slice_start, buffer.number_of_frames))
  slice_end = math.max(slice_start, math.min(slice_end, buffer.number_of_frames))
  print(string.format("Final normalize range: %d-%d\n", slice_start, slice_end))

  -- Create ProcessSlicer instance and dialog for sliced processing
  local slicer = nil
  local dialog = nil
  local vb = nil
  
  -- Define the process function for sliced processing
  local function process_func()
    local time_start = os.clock()
    local time_reading = 0
    local time_processing = 0
    local total_frames = slice_end - slice_start + 1
    
    print(string.format("\nNormalizing %d frames (%.1f seconds at %dHz)", 
        total_frames, 
        total_frames / buffer.sample_rate,
        buffer.sample_rate))
    
    -- First pass: Find peak and cache data
    local peak = 0
    local processed_frames = 0
    local CHUNK_SIZE = 524288  -- 512KB worth of frames
    
    -- Pre-allocate tables for better performance
    local channel_peaks = {}
    local sample_cache = {}
    for channel = 1, buffer.number_of_channels do
        channel_peaks[channel] = 0
        sample_cache[channel] = {}
    end
    
    buffer:prepare_sample_data_changes()
    
    -- Process in blocks
    for frame = slice_start, slice_end, CHUNK_SIZE do
        local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
        local block_size = block_end - frame + 1
        
        -- Read and process each channel
        for channel = 1, buffer.number_of_channels do
            local read_start = os.clock()
            local channel_peak = 0
            
            -- Cache the data while finding peak
            sample_cache[channel][frame] = {}
            for i = 0, block_size - 1 do
                local sample_value = buffer:sample_data(channel, frame + i)
                sample_cache[channel][frame][i] = sample_value
                local abs_value = math.abs(sample_value)
                if abs_value > channel_peak then
                    channel_peak = abs_value
                end
            end
            
            time_reading = time_reading + (os.clock() - read_start)
            if channel_peak > channel_peaks[channel] then
                channel_peaks[channel] = channel_peak
            end
        end
        
        -- Update progress and check if we should yield
        processed_frames = processed_frames + block_size
        local progress = processed_frames / total_frames
        if dialog and dialog.visible then
            vb.views.progress_text.text = string.format("Finding peak... %.1f%%", progress * 100)
        end
        
        if slicer:was_cancelled() then
            buffer:finalize_sample_data_changes()
            return
        end
        
        if should_yield() then
          coroutine.yield()
        end
    end
    
    -- Find overall peak
    for _, channel_peak in ipairs(channel_peaks) do
        if channel_peak > peak then
            peak = channel_peak
        end
    end
    
    -- Check if sample is silent
    if peak == 0 then
        print("Sample is silent, no normalization needed")
        buffer:finalize_sample_data_changes()
        if dialog and dialog.visible then
            dialog:close()
        end
        return
    end
    
    -- Calculate and display normalization info
    local scale = 1.0 / peak
    local db_increase = 20 * math.log10(scale)
    print(string.format("\nPeak amplitude: %.6f (%.1f dB below full scale)", peak, -db_increase))
    print(string.format("Will increase volume by %.1f dB", db_increase))
    
    -- Reset progress for second pass
    processed_frames = 0
    last_yield_time = os.clock()  -- Reset yield timer for second pass
    
    -- Second pass: Apply normalization using cached data
    for frame = slice_start, slice_end, CHUNK_SIZE do
        local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
        local block_size = block_end - frame + 1
        
        -- Process each channel
        for channel = 1, buffer.number_of_channels do
            local process_start = os.clock()
            
            for i = 0, block_size - 1 do
                local current_frame = frame + i
                -- Use cached data instead of reading from buffer again
                local sample_value = sample_cache[channel][frame][i]
                buffer:set_sample_data(channel, current_frame, sample_value * scale)
            end
            
            time_processing = time_processing + (os.clock() - process_start)
        end
        
        -- Clear cache for this chunk to free memory
        for channel = 1, buffer.number_of_channels do
            sample_cache[channel][frame] = nil
        end
        
        -- Update progress and check if we should yield
        processed_frames = processed_frames + block_size
        local progress = processed_frames / total_frames
        if dialog and dialog.visible then
            vb.views.progress_text.text = string.format("Normalizing... %.1f%%", progress * 100)
        end
        
        if slicer:was_cancelled() then
            buffer:finalize_sample_data_changes()
            return
        end
        
        if should_yield() then
          coroutine.yield()
        end
    end
    
    -- Clear the entire cache
    sample_cache = nil
    
    -- Finalize changes
    buffer:finalize_sample_data_changes()
    
    -- Calculate and display performance stats
    local total_time = os.clock() - time_start
    local frames_per_second = total_frames / total_time
    print(string.format("\nNormalization complete:"))
    print(string.format("Total time: %.2f seconds (%.1fM frames/sec)", 
        total_time, frames_per_second / 1000000))
    print(string.format("Reading: %.1f%%, Processing: %.1f%%", 
        (time_reading/total_time) * 100,
        ((total_time - time_reading)/total_time) * 100))
    
    -- Close dialog when done
    if dialog and dialog.visible then
        dialog:close()
    end
    
    -- Show appropriate status message
    if current_slice == 1 then
      if buffer.selection_range[1] and buffer.selection_range[2] then
        renoise.app():show_status("Normalized selection in " .. current_sample.name)
      else
        renoise.app():show_status("Normalized entire sample")
      end
    else
      if buffer.selection_range[1] and buffer.selection_range[2] then
        renoise.app():show_status(string.format("Normalized selection in slice %d", current_slice))
      else
        renoise.app():show_status(string.format("Normalized slice %d", current_slice))
      end
      -- Refresh view for slices
      song.selected_sample_index = song.selected_sample_index - 1 
      song.selected_sample_index = song.selected_sample_index + 1
    end
  end
  
  -- Create and start the ProcessSlicer for sliced processing
  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Normalizing Sample")
  slicer:start()
end

-- Add keybinding and menu entries
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_keybinding{name="Global:Paketti:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Normalize Selected Sample or Slice",invoke=NormalizeSelectedSliceInSample}
renoise.tool():add_midi_mapping{name="Paketti:Normalize Selected Sample or Slice",invoke=function(message) if message:is_trigger() then NormalizeSelectedSliceInSample() end end}


function normalize_all_samples_in_instrument()
  local instrument = renoise.song().selected_instrument
  local last_yield_time = os.clock()
  local BATCH_SIZE = 20  -- Process 20 samples before yielding
  
  -- Function to check if we should yield
  local function should_yield()
    local current_time = os.clock()
    if current_time - last_yield_time >= PROCESS_YIELD_INTERVAL then
      last_yield_time = current_time
      return true
    end
    return false
  end
  
  if not instrument then
      renoise.app():show_status("No instrument selected.")
      return
  end
  
  if #instrument.samples == 0 then
      renoise.app():show_status("Selected instrument has no samples.")
      return
  end
  
  -- Store current sample index
  local current_sample_index = renoise.song().selected_sample_index
  
  -- Create ProcessSlicer instance and dialog
  local slicer = nil
  local dialog = nil
  local vb = nil
  
  -- Define the process function
  local function process_func()
      local total_samples = #instrument.samples
      local processed_samples = 0
      local batch_count = 0
      local CHUNK_SIZE = 524288  -- 512KB worth of frames
      
      for i = 1, total_samples do
          -- Update progress
          if dialog and dialog.visible then
              vb.views.progress_text.text = string.format("Processing samples... %d/%d (%.1f%%)", 
                  i, total_samples, (i / total_samples) * 100)
          end
          
          -- Process current sample
          local sample = instrument:sample(i)
          if sample and sample.sample_buffer.has_sample_data then
              local buffer = sample.sample_buffer
              local peak = 0
              local channel_peaks = {}
              local sample_cache = {}
              
              -- Initialize cache and peaks arrays
              for channel = 1, buffer.number_of_channels do
                  channel_peaks[channel] = 0
                  sample_cache[channel] = {}
              end
              
              buffer:prepare_sample_data_changes()
              
              -- First pass: Find peak and cache data
              for frame = 1, buffer.number_of_frames, CHUNK_SIZE do
                  local block_end = math.min(frame + CHUNK_SIZE - 1, buffer.number_of_frames)
                  local block_size = block_end - frame + 1
                  
                  for channel = 1, buffer.number_of_channels do
                      sample_cache[channel][frame] = {}
                      local channel_peak = 0
                      
                      for i = 0, block_size - 1 do
                          local sample_value = buffer:sample_data(channel, frame + i)
                          sample_cache[channel][frame][i] = sample_value
                          local abs_value = math.abs(sample_value)
                          if abs_value > channel_peak then
                              channel_peak = abs_value
                          end
                      end
                      
                      if channel_peak > channel_peaks[channel] then
                          channel_peaks[channel] = channel_peak
                      end
                  end
                  
                  if should_yield() then
                      coroutine.yield()
                  end
              end
              
              -- Find overall peak
              for _, channel_peak in ipairs(channel_peaks) do
                  if channel_peak > peak then
                      peak = channel_peak
                  end
              end
              
              -- Apply normalization if needed
              if peak > 0 then
                  local scale = 1.0 / peak
                  
                  -- Second pass: Apply normalization using cached data
                  for frame = 1, buffer.number_of_frames, CHUNK_SIZE do
                      local block_end = math.min(frame + CHUNK_SIZE - 1, buffer.number_of_frames)
                      local block_size = block_end - frame + 1
                      
                      for channel = 1, buffer.number_of_channels do
                          for i = 0, block_size - 1 do
                              local sample_value = sample_cache[channel][frame][i]
                              buffer:set_sample_data(channel, frame + i, sample_value * scale)
                          end
                      end
                      
                      -- Clear cache for this chunk to free memory
                      for channel = 1, buffer.number_of_channels do
                          sample_cache[channel][frame] = nil
                      end
                      
                      if should_yield() then
                          coroutine.yield()
                      end
                  end
              end
              
              -- Clear the entire cache
              sample_cache = nil
              
              buffer:finalize_sample_data_changes()
              processed_samples = processed_samples + 1
          end
          
          batch_count = batch_count + 1
          
          -- Yield after processing BATCH_SIZE samples
          if batch_count >= BATCH_SIZE or should_yield() then
              if slicer:was_cancelled() then
                  break
              end
              batch_count = 0
              coroutine.yield()
          end
      end
      
      -- Restore original sample selection
      renoise.song().selected_sample_index = current_sample_index
      
      -- Close dialog when done
      if dialog and dialog.visible then
          dialog:close()
      end
      
      renoise.app():show_status(string.format("Normalized %d samples in instrument.", processed_samples))
  end
  
  -- Create and start the ProcessSlicer
  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Normalizing All Samples")
  slicer:start()
end

-- Add keybinding and menu entries
renoise.tool():add_keybinding{name="Global:Paketti:Normalize Sample",invoke=function() normalize_selected_sample() end}
renoise.tool():add_keybinding{name="Global:Paketti:Normalize All Samples in Instrument",invoke=function() normalize_all_samples_in_instrument() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize Sample",invoke=function() normalize_selected_sample() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Normalize Sample",invoke=function() normalize_selected_sample() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize All Samples in Instrument",invoke=function() normalize_all_samples_in_instrument() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Normalize All Samples in Instrument",invoke=function() normalize_all_samples_in_instrument() end}

function normalize_and_reduce(scope, db_reduction)
  local function process_sample(sample, reduction_factor)
    if not sample then return false, "No sample provided!" end
    local buffer = sample.sample_buffer
    if not buffer or not buffer.has_sample_data then return false, "Sample has no data!" end

    buffer:prepare_sample_data_changes()

    local max_amplitude = 0
    for channel = 1, buffer.number_of_channels do
      for frame = 1, buffer.number_of_frames do
        local sample_value = math.abs(buffer:sample_data(channel, frame))
        if sample_value > max_amplitude then max_amplitude = sample_value end
      end
    end

    if max_amplitude > 0 then
      local normalization_factor = 1 / max_amplitude
      for channel = 1, buffer.number_of_channels do
        for frame = 1, buffer.number_of_frames do
          local sample_value = buffer:sample_data(channel, frame)
          buffer:set_sample_data(channel, frame, sample_value * normalization_factor * reduction_factor)
        end
      end
    end

    buffer:finalize_sample_data_changes()
    return true, "Sample processed successfully!"
  end

  local reduction_factor = 10 ^ (db_reduction / 20)

  if scope == "current_sample" then
    local sample = renoise.song().selected_sample
    if not sample then renoise.app():show_error("No sample selected!") return end
    local success, message = process_sample(sample, reduction_factor)
    renoise.app():show_status(message)
  elseif scope == "all_samples" then
    local instrument = renoise.song().selected_instrument
    if not instrument or #instrument.samples == 0 then renoise.app():show_error("No samples in the selected instrument!") return end
    for _, sample in ipairs(instrument.samples) do
      local success, message = process_sample(sample, reduction_factor)
      if not success then renoise.app():show_status(message) end
    end
    renoise.app():show_status("All samples in the selected instrument processed.")
  elseif scope == "all_instruments" then
    for _, instrument in ipairs(renoise.song().instruments) do
      if #instrument.samples > 0 then
        for _, sample in ipairs(instrument.samples) do
          local success, message = process_sample(sample, reduction_factor)
          if not success then renoise.app():show_status("Instrument skipped: " .. message) end
        end
      end
    end
    renoise.app():show_status("All instruments processed.")
  else
    renoise.app():show_error("Invalid processing scope!")
  end
end

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize Selected Sample -12dB",invoke=function() normalize_and_reduce("current_sample", -12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize Selected Instrument -12dB (All Samples & Slices)",invoke=function() normalize_and_reduce("all_samples", -12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize All Instruments -12dB",invoke=function() normalize_and_reduce("all_instruments", -12) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Normalize Selected Sample to -12dB",invoke=function() normalize_and_reduce("current_sample", -12) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Normalize Selected Instrument to -12dB",invoke=function() normalize_and_reduce("all_samples", -12) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Normalize All Instruments to -12dB",invoke=function() normalize_and_reduce("all_instruments", -12) end}
renoise.tool():add_midi_mapping{name="Paketti:Normalize Selected Sample to -12dB",invoke=function(message) if message:is_trigger() then normalize_and_reduce("current_sample", -12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Normalize Selected Instrument to -12dB",invoke=function(message) if message:is_trigger() then normalize_and_reduce("all_samples", -12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Normalize All Instruments to -12dB",invoke=function(message) if message:is_trigger() then normalize_and_reduce("all_instruments", -12) end end}

-- Configuration for process yielding (in seconds)
local PROCESS_YIELD_INTERVAL = 1.5  -- Adjust this value to control how often the process yields

function normalize_selected_sample()
    local song = renoise.song()
    local instrument = song.selected_instrument
    local current_slice = song.selected_sample_index
    local first_sample = instrument.samples[1]
    local current_sample = song.selected_sample
    local last_yield_time = os.clock()
    
    -- Function to check if we should yield
    local function should_yield()
      local current_time = os.clock()
      if current_time - last_yield_time >= PROCESS_YIELD_INTERVAL then
        last_yield_time = current_time
        return true
      end
      return false
    end
    
    -- Check if we have valid data
    if not current_sample or not current_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample available")
        return
    end

    -- Create ProcessSlicer instance and dialog
    local slicer = nil
    local dialog = nil
    local vb = nil
    
    -- Define the process function that will be passed to ProcessSlicer
    local function process_func()
        -- Get the appropriate sample and buffer based on whether we're dealing with a slice
        local sample = current_sample
        local buffer = sample.sample_buffer
        local slice_start = 1
        local slice_end = buffer.number_of_frames
        
        -- If this is a slice, we need to work with the first sample's buffer
        if sample.is_slice_alias then
            buffer = first_sample.sample_buffer
            -- Find the slice boundaries
            if current_slice > 1 and #first_sample.slice_markers > 0 then
                slice_start = first_sample.slice_markers[current_slice - 1]
                slice_end = current_slice < #first_sample.slice_markers 
                    and first_sample.slice_markers[current_slice] - 1 
                    or buffer.number_of_frames
            end
        end
        
        local total_frames = slice_end - slice_start + 1
        
        -- Timing variables
        local time_start = os.clock()
        local time_reading = 0
        local time_processing = 0
        
        print(string.format("\nNormalizing %d frames (%.1f seconds at %dHz)", 
            total_frames, 
            total_frames / buffer.sample_rate,
            buffer.sample_rate))
        
        -- First pass: Find peak and cache data
        local peak = 0
        local processed_frames = 0
        local CHUNK_SIZE = 524288  -- 512KB worth of frames
        
        -- Pre-allocate tables for better performance
        local channel_peaks = {}
        local sample_cache = {}
        for channel = 1, buffer.number_of_channels do
            channel_peaks[channel] = 0
            sample_cache[channel] = {}
        end
        
        buffer:prepare_sample_data_changes()
        
        -- Process in blocks
        for frame = slice_start, slice_end, CHUNK_SIZE do
            local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
            local block_size = block_end - frame + 1
            
            -- Read and process each channel
            for channel = 1, buffer.number_of_channels do
                local read_start = os.clock()
                local channel_peak = 0
                
                -- Cache the data while finding peak
                sample_cache[channel][frame] = {}
                for i = 0, block_size - 1 do
                    local sample_value = buffer:sample_data(channel, frame + i)
                    sample_cache[channel][frame][i] = sample_value
                    local abs_value = math.abs(sample_value)
                    if abs_value > channel_peak then
                        channel_peak = abs_value
                    end
                end
                
                time_reading = time_reading + (os.clock() - read_start)
                if channel_peak > channel_peaks[channel] then
                    channel_peaks[channel] = channel_peak
                end
            end
            
            -- Update progress and check if we should yield
            processed_frames = processed_frames + block_size
            local progress = processed_frames / total_frames
            if dialog and dialog.visible then
                vb.views.progress_text.text = string.format("Finding peak... %.1f%%", progress * 100)
            end
            
            if slicer:was_cancelled() then
                buffer:finalize_sample_data_changes()
                return
            end
            
            if should_yield() then
              coroutine.yield()
            end
        end
        
        -- Find overall peak
        for _, channel_peak in ipairs(channel_peaks) do
            if channel_peak > peak then
                peak = channel_peak
            end
        end
        
        -- Check if sample is silent
        if peak == 0 then
            print("Sample is silent, no normalization needed")
            buffer:finalize_sample_data_changes()
            if dialog and dialog.visible then
                dialog:close()
            end
            return
        end
        
        -- Calculate and display normalization info
        local scale = 1.0 / peak
        local db_increase = 20 * math.log10(scale)
        print(string.format("\nPeak amplitude: %.6f (%.1f dB below full scale)", peak, -db_increase))
        print(string.format("Will increase volume by %.1f dB", db_increase))
        
        -- Reset progress for second pass
        processed_frames = 0
        last_yield_time = os.clock()  -- Reset yield timer for second pass
        
        -- Second pass: Apply normalization using cached data
        for frame = slice_start, slice_end, CHUNK_SIZE do
            local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
            local block_size = block_end - frame + 1
            
            -- Process each channel
            for channel = 1, buffer.number_of_channels do
                local process_start = os.clock()
                
                for i = 0, block_size - 1 do
                    local current_frame = frame + i
                    -- Use cached data instead of reading from buffer again
                    local sample_value = sample_cache[channel][frame][i]
                    buffer:set_sample_data(channel, current_frame, sample_value * scale)
                end
                
                time_processing = time_processing + (os.clock() - process_start)
            end
            
            -- Clear cache for this chunk to free memory
            for channel = 1, buffer.number_of_channels do
                sample_cache[channel][frame] = nil
            end
            
            -- Update progress and check if we should yield
            processed_frames = processed_frames + block_size
            local progress = processed_frames / total_frames
            if dialog and dialog.visible then
                vb.views.progress_text.text = string.format("Normalizing... %.1f%%", progress * 100)
            end
            
            if slicer:was_cancelled() then
                buffer:finalize_sample_data_changes()
                return
            end
            
            if should_yield() then
              coroutine.yield()
            end
        end
        
        -- Clear the entire cache
        sample_cache = nil
        
        -- Finalize changes
        buffer:finalize_sample_data_changes()
        
        -- Calculate and display performance stats
        local total_time = os.clock() - time_start
        local frames_per_second = total_frames / total_time
        print(string.format("\nNormalization complete:"))
        print(string.format("Total time: %.2f seconds (%.1fM frames/sec)", 
            total_time, frames_per_second / 1000000))
        print(string.format("Reading: %.1f%%, Processing: %.1f%%", 
            (time_reading/total_time) * 100,
            ((total_time - time_reading)/total_time) * 100))
        
        -- Close dialog when done
        if dialog and dialog.visible then
            dialog:close()
        end
        
        -- Show appropriate status message
        if sample.is_slice_alias then
            renoise.app():show_status(string.format("Normalized slice %d", current_slice))
        else
            renoise.app():show_status("Sample normalized successfully")
        end
    end
    
    -- Create and start the ProcessSlicer
    slicer = ProcessSlicer(process_func)
    dialog, vb = slicer:create_dialog("Normalizing Sample")
    slicer:start()
end


function ReverseSelectedSliceInSample()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local current_slice = song.selected_sample_index
  local first_sample = instrument.samples[1]
  local current_sample = song.selected_sample
  local current_buffer = current_sample.sample_buffer
  local last_yield_time = os.clock()
  
  -- Function to check if we should yield
  local function should_yield()
    local current_time = os.clock()
    if current_time - last_yield_time >= PROCESS_YIELD_INTERVAL then
      last_yield_time = current_time
      return true
    end
    return false
  end
  
  -- Check if we have valid data
  if not current_sample or not current_buffer.has_sample_data then
    renoise.app():show_status("No sample available")
    return
  end

  print(string.format("\nSample Selected is Sample Slot %d", song.selected_sample_index))
  print(string.format("Sample Frames Length is 1-%d", current_buffer.number_of_frames))

  -- Create ProcessSlicer instance and dialog
  local slicer = nil
  local dialog = nil
  local vb = nil

  -- Define the process function
  local function process_func()
    -- Case 1: No slice markers - work on current sample
    if #first_sample.slice_markers == 0 then
      local slice_start, slice_end
      
      -- Check for selection in current sample
      if current_buffer.selection_range[1] and current_buffer.selection_range[2] then
        slice_start = current_buffer.selection_range[1]
        slice_end = current_buffer.selection_range[2]
        print(string.format("Selection in Sample: %d-%d", slice_start, slice_end))
        print("Reversing: selection in sample")
      else
        slice_start = 1
        slice_end = current_buffer.number_of_frames
        print("Reversing: entire sample")
      end
      
      -- Reverse the range
      current_buffer:prepare_sample_data_changes()
      
      local num_channels = current_buffer.number_of_channels
      local frames_to_process = slice_end - slice_start + 1
      local half_frames = math.floor(frames_to_process / 2)
      local processed_frames = 0

      for offset = 0, half_frames - 1 do
        local frame_a = slice_start + offset
        local frame_b = slice_end - offset
        for channel = 1, num_channels do
          local temp = current_buffer:sample_data(channel, frame_a)
          current_buffer:set_sample_data(channel, frame_a, current_buffer:sample_data(channel, frame_b))
          current_buffer:set_sample_data(channel, frame_b, temp)
        end

        processed_frames = processed_frames + 2
        local progress = (processed_frames / frames_to_process) * 100

        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Reversing... %.1f%%", progress)
        end

        if slicer:was_cancelled() then
          current_buffer:finalize_sample_data_changes()
          return
        end

        if should_yield() then
          coroutine.yield()
        end
      end

      current_buffer:finalize_sample_data_changes()
      
      if current_buffer.selection_range[1] and current_buffer.selection_range[2] then
        renoise.app():show_status("Reversed selection in " .. current_sample.name)
      else
        renoise.app():show_status("Reversed " .. current_sample.name)
      end

      if dialog and dialog.visible then
        dialog:close()
      end
      return
    end

    -- Case 2: Has slice markers
    local buffer = first_sample.sample_buffer
    local slice_start, slice_end
    local slice_markers = first_sample.slice_markers

    -- If we're on the first sample
    if current_slice == 1 then
      -- Check for selection in first sample
      if buffer.selection_range[1] and buffer.selection_range[2] then
        slice_start = buffer.selection_range[1]
        slice_end = buffer.selection_range[2]
        print(string.format("Selection in First Sample: %d-%d", slice_start, slice_end))
        print("Reversing: selection in first sample")
      else
        slice_start = 1
        slice_end = buffer.number_of_frames
        print("Reversing: entire first sample")
      end
    else
      -- Get slice boundaries
      slice_start = current_slice > 1 and slice_markers[current_slice - 1] or 1
      local slice_end_marker = slice_markers[current_slice] or buffer.number_of_frames
      local slice_length = slice_end_marker - slice_start + 1

      print(string.format("Selection is within Slice %d", current_slice))
      print(string.format("Slice %d length is %d-%d (length: %d), within 1-%d of sample frames length", 
        current_slice, slice_start, slice_end_marker, slice_length, buffer.number_of_frames))

      -- Debug selection values
      print(string.format("Current sample selection range: start=%s, end=%s", 
        tostring(current_buffer.selection_range[1]), tostring(current_buffer.selection_range[2])))
      
      -- Check if there's a selection in the current slice view
      if current_buffer.selection_range[1] and current_buffer.selection_range[2] then
        local rel_sel_start = current_buffer.selection_range[1]
        local rel_sel_end = current_buffer.selection_range[2]
        
        -- Convert slice-relative selection to absolute position in sample
        local abs_sel_start = slice_start + rel_sel_start - 1
        local abs_sel_end = slice_start + rel_sel_end - 1
        
        print(string.format("Selection %d-%d in slice view converts to %d-%d in sample", 
          rel_sel_start, rel_sel_end, abs_sel_start, abs_sel_end))
            
        -- Use the converted absolute positions
        slice_start = abs_sel_start
        slice_end = abs_sel_end
        print("Reversing: selection in slice")
      else
        -- No selection in slice view - reverse whole slice
        slice_end = slice_end_marker
        print("Reversing: entire slice (no selection in slice view)")
      end
    end

    -- Reverse the range
    buffer:prepare_sample_data_changes()
    
    local num_channels = buffer.number_of_channels
    local frames_to_process = slice_end - slice_start + 1
    local half_frames = math.floor(frames_to_process / 2)
    local processed_frames = 0

    for offset = 0, half_frames - 1 do
      local frame_a = slice_start + offset
      local frame_b = slice_end - offset
      for channel = 1, num_channels do
        local temp = buffer:sample_data(channel, frame_a)
        buffer:set_sample_data(channel, frame_a, buffer:sample_data(channel, frame_b))
        buffer:set_sample_data(channel, frame_b, temp)
      end

      processed_frames = processed_frames + 2
      local progress = (processed_frames / frames_to_process) * 100

      if dialog and dialog.visible then
        vb.views.progress_text.text = string.format("Reversing... %.1f%%", progress)
      end

      if slicer:was_cancelled() then
        buffer:finalize_sample_data_changes()
        return
      end

      if should_yield() then
        coroutine.yield()
      end
    end

    buffer:finalize_sample_data_changes()

    if current_slice == 1 then
      if current_buffer.selection_range[1] and current_buffer.selection_range[2] then
        renoise.app():show_status("Reversed selection in " .. current_sample.name)
      else
        renoise.app():show_status("Reversed entire sample")
      end
    else
      if current_buffer.selection_range[1] and current_buffer.selection_range[2] then
        renoise.app():show_status(string.format("Reversed selection in slice %d", current_slice))
      else
        renoise.app():show_status(string.format("Reversed slice %d", current_slice))
      end
      -- Refresh view for slices
      song.selected_sample_index = song.selected_sample_index - 1 
      song.selected_sample_index = song.selected_sample_index + 1
    end

    if dialog and dialog.visible then
      dialog:close()
    end
  end

  -- Create and start the ProcessSlicer
  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Reversing Sample")
  slicer:start()
end

-- Add keybinding and menu entries
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_keybinding{name="Sample Keyzones:Paketti:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Process..:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Reverse Selected Sample or Slice",invoke=ReverseSelectedSliceInSample}
renoise.tool():add_midi_mapping{name="Paketti:Reverse Selected Sample or Slice",invoke=function(message) if message:is_trigger() then ReverseSelectedSliceInSample() end end}




function normalize_selected_sample_by_slices()
  local selected_sample = renoise.song().selected_sample
  local last_yield_time = os.clock()
  
  -- Function to check if we should yield
  local function should_yield()
    local current_time = os.clock()
    if current_time - last_yield_time >= PROCESS_YIELD_INTERVAL then
      last_yield_time = current_time
      return true
    end
    return false
  end
  
  if not selected_sample or not selected_sample.sample_buffer or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Normalization failed: No valid sample to normalize.")
    return
  end

  -- Check if sample has slice markers
  if #selected_sample.slice_markers == 0 then
    -- If no slice markers, fall back to regular normalize
    normalize_selected_sample()
    return
  end

  local sbuf = selected_sample.sample_buffer
  local slice_count = #selected_sample.slice_markers
  
  -- Create ProcessSlicer instance and dialog
  local slicer = nil
  local dialog = nil
  local vb = nil
  
  -- Define the process function
  local function process_func()
    local time_start = os.clock()
    local time_reading = 0
    local time_processing = 0
    local CHUNK_SIZE = 16777216  -- 16MB worth of frames
    local total_frames = sbuf.number_of_frames
    local total_slices = slice_count
    local slices_processed = 0
    
    print(string.format("\nProcessing %d frames across %d slices", total_frames, total_slices))
    
    -- Prepare buffer for changes
    sbuf:prepare_sample_data_changes()
    
    -- Process each slice independently
    for slice_idx = 1, slice_count do
      local slice_start = selected_sample.slice_markers[slice_idx]
      local slice_end = (slice_idx < slice_count) 
        and selected_sample.slice_markers[slice_idx + 1] - 1 
        or sbuf.number_of_frames
      
      local slice_frames = slice_end - slice_start + 1
      
      -- Pre-allocate tables for better performance
      local channel_peaks = {}
      local sample_cache = {}
      for channel = 1, sbuf.number_of_channels do
        channel_peaks[channel] = 0
        sample_cache[channel] = {}
      end
      
      -- First pass: Find peak and cache data
      local highest_detected = 0
      
      -- Process in chunks
      for frame = slice_start, slice_end, CHUNK_SIZE do
        local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
        local block_size = block_end - frame + 1
        
        -- Read and process each channel
        for channel = 1, sbuf.number_of_channels do
          local read_start = os.clock()
          local channel_peak = 0
          
          -- Cache the data while finding peak
          sample_cache[channel][frame] = {}
          for i = 0, block_size - 1 do
            local current_frame = frame + i
            local sample_value = sbuf:sample_data(channel, current_frame)
            sample_cache[channel][frame][i] = sample_value
            local abs_value = math.abs(sample_value)
            if abs_value > channel_peak then
              channel_peak = abs_value
            end
          end
          
          time_reading = time_reading + (os.clock() - read_start)
          if channel_peak > channel_peaks[channel] then
            channel_peaks[channel] = channel_peak
          end
        end
        
        -- Calculate actual progress percentage
        local progress = (slice_idx - 1 + (frame - slice_start) / slice_frames) / total_slices * 100
        
        if dialog and dialog.visible then
          vb.views.progress_text.text = string.format("Processing %03d/%03d - %.1f%%", 
            slice_idx, total_slices, progress)
        end
        
        if slicer:was_cancelled() then
          sbuf:finalize_sample_data_changes()
          return
        end
        
        if should_yield() then
          coroutine.yield()
        end
      end
      
      -- Find overall peak for this slice
      for _, channel_peak in ipairs(channel_peaks) do
        if channel_peak > highest_detected then
          highest_detected = channel_peak
        end
      end
      
      -- Only normalize if the slice isn't silent
      if highest_detected > 0 then
        local scale = 1.0 / highest_detected
        
        -- Second pass: Apply normalization using cached data
        for frame = slice_start, slice_end, CHUNK_SIZE do
          local block_end = math.min(frame + CHUNK_SIZE - 1, slice_end)
          local block_size = block_end - frame + 1
          
          -- Process each channel
          for channel = 1, sbuf.number_of_channels do
            local process_start = os.clock()
            
            for i = 0, block_size - 1 do
              local current_frame = frame + i
              -- Use cached data instead of reading from buffer again
              local sample_value = sample_cache[channel][frame][i]
              sbuf:set_sample_data(channel, current_frame, sample_value * scale)
            end
            
            time_processing = time_processing + (os.clock() - process_start)
          end
          
          -- Clear cache for this chunk to free memory
          for channel = 1, sbuf.number_of_channels do
            sample_cache[channel][frame] = nil
          end
          
          -- Calculate actual progress percentage (50-100% range for normalization phase)
          local progress = 50 + (slice_idx - 1 + (frame - slice_start) / slice_frames) / total_slices * 50
          
          if dialog and dialog.visible then
            vb.views.progress_text.text = string.format("Normalizing %03d/%03d - %.1f%%", 
              slice_idx, total_slices, progress)
          end
          
          if slicer:was_cancelled() then
            sbuf:finalize_sample_data_changes()
            return
          end
          
          if should_yield() then
            coroutine.yield()
          end
        end
      end
      
      -- Clear the entire cache for this slice
      sample_cache = nil
      slices_processed = slices_processed + 1
    end
    
    -- Finalize changes
    sbuf:finalize_sample_data_changes()
    
    -- Calculate and display performance stats
    local total_time = os.clock() - time_start
    local frames_per_second = total_frames / total_time
    print(string.format("\nSlice normalization complete for %d frames:", total_frames))
    print(string.format("Total time: %.2f seconds (%.1fM frames/sec)", 
      total_time, frames_per_second / 1000000))
    print(string.format("Reading: %.1f%%, Processing: %.1f%%", 
      (time_reading/total_time) * 100,
      ((total_time - time_reading)/total_time) * 100))
    
    -- Close dialog when done
    if dialog and dialog.visible then
      dialog:close()
    end
    
    renoise.app():show_status(string.format("Normalized %d slices independently", slice_count))
  end
  
  -- Create and start the ProcessSlicer
  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Normalizing Slices")
  slicer:start()
end

-- Add keybinding and menu entries
renoise.tool():add_keybinding{name="Global:Paketti:Normalize Sample Slices Independently",
  invoke=function() normalize_selected_sample_by_slices() end
}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:Normalize Slices Independently",
  invoke=function() normalize_selected_sample_by_slices() end
}
