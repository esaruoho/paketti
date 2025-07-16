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
  
  -- Protection: Check if sample has sample buffer
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no sample data")
    print("Error: Selected sample has no sample data")
    return
  end
  
  -- Protection: Check if there are slices
  if not sample.slice_markers or #sample.slice_markers == 0 then
    renoise.app():show_status("Selected sample has no slices")
    print("Error: Selected sample has no slices")
    return
  end
  
  local slice_markers = sample.slice_markers
  local slice_count = #slice_markers
  local sample_buffer = sample.sample_buffer
  local total_frames = sample_buffer.number_of_frames
  local sample_rate = sample_buffer.sample_rate
  local bit_depth = sample_buffer.bit_depth
  local num_channels = sample_buffer.number_of_channels
  
  print("Found " .. slice_count .. " slices in sample")
  print("Original sample: " .. total_frames .. " frames, " .. sample_rate .. "Hz, " .. bit_depth .. "bit, " .. num_channels .. " channels")
  
  -- Calculate target slice count (next power of 2)
  local target_slice_count = 2
  while target_slice_count < slice_count do
    target_slice_count = target_slice_count * 2
  end
  
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
  
  -- Copy each slice to the new buffer with padding
  for slice_index = 1, slice_count do
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
  for i = 1, target_slice_count do
    local marker_position = (i - 1) * longest_slice_frames + 1
    new_sample:insert_slice_marker(marker_position)
    print(string.format("Created slice marker %d at frame %d", i, marker_position))
  end
  
  -- Copy sample settings from original
  new_sample.name = sample.name .. " (Manual Sliced)"
  --new_sample.base_note = sample.base_note
  --new_sample.fine_tune = sample.fine_tune
  --new_sample.volume = sample.volume
  --new_sample.panning = sample.panning
  --new_sample.loop_mode = sample.loop_mode
  --new_sample.loop_start = sample.loop_start
  --new_sample.loop_end = sample.loop_end
  
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

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Manual Slicer:Fit Slices to Longest Slice with Power of 2 Padding",invoke = paketti_manual_slicer} 
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Fit Slices to Longest Slice with Power of 2 Padding",invoke = paketti_manual_slicer} 