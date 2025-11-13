-- Polyend Slice Switcher for Paketti
-- Manages velocity-mapped slices for polyphonic slice playback

local vb = renoise.ViewBuilder()
local dialog = nil
local current_vb = nil -- Store reference to current ViewBuilder for updates
current_selected_slice = 0
local total_slices = 0
local slice_instrument = nil

-- Global variables to track polyend slice state
paketti_polyend_slice_active = false
paketti_melodic_slice_mode = false -- Track if we're in melodic slice export mode
paketti_polyend_slice_instrument_index = nil
paketti_polyend_slice_notifier_added = false

-- Function to check if current instrument has polyend slice setup
function PakettiPolyendSliceSwitcherIsActive()
  local song = renoise.song()
  local inst = song.selected_instrument
  -- Active if instrument has multiple samples (up to 48)
  return inst and #inst.samples > 1 and #inst.samples <= 48
end

-- Function to setup velocity ranges for slices
function PakettiPolyendSliceSwitcherSetSliceVelocity(slice_index)
  if not slice_instrument then return end
  
  -- Limit to max 48 samples for melodic slice switching
  local max_samples = math.min(48, #slice_instrument.samples)
  
  -- Set all samples to 00-00 velocity range (inactive)
  for i = 1, max_samples do
    local sample = slice_instrument.samples[i]
    if sample then
      sample.sample_mapping.velocity_range = {0, 0}
    end
  end
  
  -- Set selected sample to 00-7F velocity range (active)
  -- slice_index is 0-based, but samples array is 1-based
  if slice_index >= 0 and slice_index < max_samples then
    local selected_sample = slice_instrument.samples[slice_index + 1] -- Lua 1-based indexing
    if selected_sample then
      selected_sample.sample_mapping.velocity_range = {0, 127}
      current_selected_slice = slice_index
      print(string.format("-- Updated velocity: Sample %02d active (00-7F), others inactive (00-00)", slice_index + 1))
    end
  end
end

-- Function to update the dialog display
function PakettiPolyendSliceSwitcherUpdateDialog()
  if not dialog or not dialog.visible or not current_vb then return end
  
  local slice_text = string.format("Sample: %02d/%02d", current_selected_slice + 1, total_slices)
  current_vb.views.slice_display.text = slice_text
  current_vb.views.slice_slider.value = current_selected_slice
  
  -- Update status
  renoise.app():show_status(string.format("Melodic Sample: %02d (00-7F velocity)", current_selected_slice + 1))
end

-- Function to change selected slice
function PakettiPolyendSliceSwitcherChangeSlice(new_slice)
  if not slice_instrument then return end
  
  -- Clamp to valid range
  new_slice = math.max(0, math.min(new_slice, total_slices - 1))
  
  if new_slice ~= current_selected_slice then
    PakettiPolyendSliceSwitcherSetSliceVelocity(new_slice)
    PakettiPolyendSliceSwitcherUpdateDialog()
    
    -- Select the sample in Renoise interface
    local selected_sample_index = new_slice + 1  -- Convert 0-based to 1-based
    if selected_sample_index >= 1 and selected_sample_index <= #slice_instrument.samples then
      renoise.song().selected_sample_index = selected_sample_index
    end
    
    -- Show sample name if available
    local sample = slice_instrument.samples[new_slice + 1]
    if sample then
      local sample_name = sample.name
      if sample_name and sample_name ~= "" then
        renoise.app():show_status(string.format("Polyend Slice %02d: %s (velocity 00-7F)", new_slice + 1, sample_name))
      end
    end
  end
end

-- Function to go to next slice
function PakettiPolyendSliceSwitcherNextSlice()
  if not PakettiPolyendSliceSwitcherIsActive() then
    renoise.app():show_status("No Polyend Slice instrument active")
    return
  end
  
  PakettiPolyendSliceSwitcherChangeSlice(current_selected_slice + 1)
end

-- Function to go to previous slice
function PakettiPolyendSliceSwitcherPrevSlice()
  if not PakettiPolyendSliceSwitcherIsActive() then
    renoise.app():show_status("No Polyend Slice instrument active")
    return
  end
  
  PakettiPolyendSliceSwitcherChangeSlice(current_selected_slice - 1)
end

-- Function to handle MIDI slice selection (0-127 mapped to slices 01-49)
function PakettiPolyendSliceSwitcherMidiSliceSelect(midi_value)
  if not PakettiPolyendSliceSwitcherIsActive() then
    return
  end
  
  -- Map MIDI 0-127 to slice indices (displays as slices 01-49)
  local max_slice_index = math.min(total_slices - 1, 48)
  local mapped_slice = math.floor((midi_value / 127) * max_slice_index)
  
  PakettiPolyendSliceSwitcherChangeSlice(mapped_slice)
end

-- Function to create the slice switcher dialog
function PakettiPolyendSliceSwitcherCreateDialog()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have a valid instrument with multiple samples
  if not inst or #inst.samples <= 1 then
    renoise.app():show_error("No instrument with multiple samples selected. Need at least 2 samples to switch between.")
    return
  end
  
  -- Set up working variables from current instrument
  slice_instrument = inst
  total_slices = math.min(48, #inst.samples) -- Limit to 48 samples max
  
  -- Find which sample is currently active (has velocity > 0)
  current_selected_slice = 0 -- Default to first
  for i = 1, total_slices do
    local sample = inst.samples[i]
    if sample and sample.sample_mapping.velocity_range[2] > 0 then
      current_selected_slice = i - 1 -- Convert to 0-based
      break
    end
  end
  
  print(string.format("-- Slice Switcher: Found %d samples, active sample: %d", total_slices, current_selected_slice + 1))
  
  -- Close existing dialog if open (to handle new PTI loads)
  if dialog and dialog.visible then
    dialog:close()
  end
  
  -- Reset current ViewBuilder reference
  current_vb = nil
  
  -- Create a fresh ViewBuilder instance to avoid ID conflicts
  local fresh_vb = renoise.ViewBuilder()
  current_vb = fresh_vb  -- Store reference for update functions
  
  local dialog_content = fresh_vb:column {
    fresh_vb:row {
      fresh_vb:text {
        id = "slice_display",
        text = string.format("Sample: %02d/%02d", current_selected_slice + 1, total_slices),
        font = "bold"
      }
    },
    fresh_vb:row {
      fresh_vb:slider {
        id = "slice_slider",
        min = 0,
        max = math.max(0, total_slices - 1), -- Ensure max is never negative
        value = math.min(current_selected_slice, math.max(0, total_slices - 1)), -- Clamp value to valid range
        width = 300,
        notifier = function(value)
          PakettiPolyendSliceSwitcherChangeSlice(math.floor(value))
        end
      }
    },
    fresh_vb:row {
      fresh_vb:button {
        text = "Previous",
        width = 70,
        notifier = function()
          PakettiPolyendSliceSwitcherPrevSlice()
        end
      },
      fresh_vb:button {
        text = "Next",
        width = 70,
        notifier = function()
          PakettiPolyendSliceSwitcherNextSlice()
        end
      },
      fresh_vb:button {
        text = "Close",
        width = 70,
        notifier = function()
          current_vb = nil  -- Reset ViewBuilder reference
          dialog:close()
        end
      }
    },
    fresh_vb:text {
      text = "Velocity: Selected slice = 00-7F, Others = 00-00",
      style = "disabled"
    },
    fresh_vb:text {
      text = "Key Range: C-0 to B-9 (All slices)",
      style = "disabled"
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Polyend Slice Switcher", dialog_content, my_keyhandler_func)
  
  -- Set focus back to Renoise after dialog opens
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Function to process instrument for polyend slice setup
function PakettiPolyendSliceSwitcherProcessInstrument(instrument, slice_markers, original_sample_name, selected_slice_index)
  -- Start ProcessSlicer for slice processing  
  local dialog, vb
  local process_slicer = ProcessSlicer(function()
    PakettiPolyendSliceSwitcherProcessInstrument_Worker(instrument, slice_markers, original_sample_name, selected_slice_index, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Creating Individual Slice Samples...")
  process_slicer:start()
  return true -- Return success immediately since ProcessSlicer handles the work
end

--- ProcessSlicer worker for slice processing
function PakettiPolyendSliceSwitcherProcessInstrument_Worker(instrument, slice_markers, original_sample_name, selected_slice_index, dialog, vb)
  print("-- Processing instrument for Polyend Slice setup")
  
  -- Set the selected slice from PTI file (default to 0 if not provided)
  selected_slice_index = selected_slice_index or 0
  print(string.format("-- PTI selected slice index: %d", selected_slice_index))
  
  -- Store references  
  slice_instrument = instrument
  total_slices = #slice_markers -- Only the slice count, no base sample
  current_selected_slice = math.min(selected_slice_index, total_slices - 1) -- Ensure within bounds
  
  -- Mark as active polyend slice instrument
  paketti_polyend_slice_active = true
  paketti_polyend_slice_instrument_index = renoise.song().selected_instrument_index
  
  -- Setup instrument change notifier
  PakettiPolyendSliceSwitcherSetupNotifier()
  
  print(string.format("-- Total slices to create: %d", total_slices))
  
  -- Get the original sample data (this should be the full sample from normal PTI loading)
  local original_sample = instrument.samples[1]
  if not original_sample or not original_sample.sample_buffer.has_sample_data then
    print("-- Error: No sample data to process")
    return false
  end
  
  local sample_rate = original_sample.sample_buffer.sample_rate
  local bit_depth = original_sample.sample_buffer.bit_depth
  local num_channels = original_sample.sample_buffer.number_of_channels
  local total_frames = original_sample.sample_buffer.number_of_frames
  
  print("-- Using existing loaded sample data to create individual slice samples")
  
  -- Create individual samples for each slice
  for i, slice_start in ipairs(slice_markers) do
    
    -- Update progress dialog
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Processing slice %d/%d...", i, total_slices)
    end
    renoise.app():show_status(string.format("Polyend Slice: Processing slice %d/%d", i, total_slices))
    
    -- Ensure slice_start is at least 1 (Renoise uses 1-based indexing)
    local original_slice_start = slice_start
    slice_start = math.max(1, slice_start)
    local slice_end = (i < #slice_markers) and slice_markers[i + 1] or total_frames
    local slice_length = slice_end - slice_start
    
    print(string.format("-- Processing slice %02d: original_start=%d, adjusted_start=%d, end=%d, length=%d", 
      i, original_slice_start, slice_start, slice_end, slice_length))
    
    if slice_length > 0 then
      -- Create new sample (always insert at the end)
      local new_sample = instrument:insert_sample_at(#instrument.samples + 1)
      new_sample.sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, slice_length)
      
      -- Copy slice data with yielding for large slices
      local new_buffer = new_sample.sample_buffer
      new_buffer:prepare_sample_data_changes()
      
      -- Calculate yield interval for this slice (every 75000 frames max)
      local yield_interval = math.min(75000, math.max(5000, math.floor(slice_length / 50)))
      
      for frame = 1, slice_length do
        for channel = 1, num_channels do
          local source_frame = slice_start + frame
          if source_frame >= 1 and source_frame <= total_frames then
            local sample_value = original_sample.sample_buffer:sample_data(channel, source_frame)
            new_buffer:set_sample_data(channel, frame, sample_value)
          end
        end
        
        -- Yield periodically for large slices to keep UI responsive
        if frame % yield_interval == 0 then
          if dialog and dialog.visible then
            vb.views.progress_text.text = string.format("Processing slice %d/%d (%d%%)...", i, total_slices, math.floor((frame / slice_length) * 100))
          end
          coroutine.yield()
        end
      end
      
      new_buffer:finalize_sample_data_changes()
      
      -- Set up sample properties  
      new_sample.name = string.format("%s (Slice %02d)", original_sample_name or "Slice", i)
      new_sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
      
      -- Set velocity range based on whether this is the selected slice
      if (i - 1) == current_selected_slice then
        new_sample.sample_mapping.velocity_range = {0, 127} -- Selected slice: 00-7F
        print(string.format("-- Set slice %02d as SELECTED (velocity 00-7F)", i))
      else
        new_sample.sample_mapping.velocity_range = {0, 0} -- Other slices: inactive (00-00)
      end
      
      -- Apply Paketti loader preferences to the new sample
      new_sample.autofade = preferences.pakettiLoaderAutofade.value
      new_sample.autoseek = preferences.pakettiLoaderAutoseek.value
      new_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      new_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      new_sample.oneshot = preferences.pakettiLoaderOneshot.value
      new_sample.new_note_action = preferences.pakettiLoaderNNA.value
      
      print(string.format("-- Created slice %02d: frames %d-%d (%d frames)", i, slice_start, slice_end - 1, slice_length))
    end
    
    -- Yield after each slice to keep UI responsive
    coroutine.yield()
  end
  
  -- Clean up: Remove the original full sample (it's at position 1)
  if #instrument.samples > total_slices then
    print("-- Removing original full sample")
    instrument:delete_sample_at(1)
  end
  
  -- Remove any placeholder samples or extra samples beyond our slice count
  while #instrument.samples > total_slices do
    print(string.format("-- Removing extra sample at position %d", #instrument.samples))
    instrument:delete_sample_at(#instrument.samples)
  end
  
  print(string.format("-- Cleanup complete: %d slice samples remaining", #instrument.samples))
  
  -- Ensure the correct slice is selected and has proper velocity mapping
  PakettiPolyendSliceSwitcherSetSliceVelocity(current_selected_slice)
  
  -- Select the correct sample in Renoise interface
  local selected_sample_index = current_selected_slice + 1  -- Convert 0-based to 1-based
  if selected_sample_index >= 1 and selected_sample_index <= #instrument.samples then
    renoise.song().selected_sample_index = selected_sample_index
    print(string.format("-- Selected sample index set to %d (slice %02d)", selected_sample_index, current_selected_slice + 1))
  end
  
  -- Set instrument name
  instrument.name = string.format("%s (Polyend Slice Mode)", original_sample_name or "Polyend Slice Mode")
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  print(string.format("-- Polyend Slice processing complete: %d slices created", total_slices))
  print(string.format("-- Selected slice %02d set to velocity 00-7F, others set to 00-00", current_selected_slice + 1))
  
  -- Check if dialog should be opened
  if preferences and preferences.pakettiPolyendOpenDialog and preferences.pakettiPolyendOpenDialog.value then
    -- Open dialog directly - processing is complete
    PakettiPolyendSliceSwitcherCreateDialog()
  end
  
  return true
end

-- MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Polyend Slice Select (0-48) x[Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      PakettiPolyendSliceSwitcherMidiSliceSelect(message.int_value)
    end
  end
}

-- Keyboard shortcuts
renoise.tool():add_keybinding{name="Global:Paketti:Polyend Slice Next",
  invoke=function() PakettiPolyendSliceSwitcherNextSlice() end
}

renoise.tool():add_keybinding{name="Global:Paketti:Polyend Slice Previous", 
  invoke=function() PakettiPolyendSliceSwitcherPrevSlice() end
}

renoise.tool():add_keybinding{name="Global:Paketti:Polyend Slice Dialog Toggle",
  invoke=function()
    if not PakettiPolyendSliceSwitcherIsActive() then
      renoise.app():show_status("No Polyend Slice instrument active")
      return
    end
    
    if dialog and dialog.visible then
      dialog:close()
    else
      PakettiPolyendSliceSwitcherCreateDialog()
    end
  end
}



-- Instrument selection observable to deactivate when switching instruments
function PakettiPolyendSliceSwitcherCheckInstrumentChange()
  if paketti_polyend_slice_active and 
     paketti_polyend_slice_instrument_index and
     paketti_polyend_slice_instrument_index ~= renoise.song().selected_instrument_index then
    
    print("-- Deactivating Polyend Slice (instrument changed)")
    paketti_polyend_slice_active = false
    paketti_polyend_slice_instrument_index = nil
    slice_instrument = nil
    
    -- Remove the notifier when deactivating
    PakettiPolyendSliceSwitcherRemoveNotifier()
    
    if dialog and dialog.visible then
      dialog:close()
    end
  end
end

-- Function to setup observable notifier (called when polyend slice is activated)
function PakettiPolyendSliceSwitcherSetupNotifier()
  if not paketti_polyend_slice_notifier_added then
    local song = renoise.song()
    if song then
      song.selected_instrument_index_observable:add_notifier(PakettiPolyendSliceSwitcherCheckInstrumentChange)
      paketti_polyend_slice_notifier_added = true
      print("-- Polyend Slice instrument change notifier added")
    end
  end
end

-- Function to remove observable notifier
function PakettiPolyendSliceSwitcherRemoveNotifier()
  if paketti_polyend_slice_notifier_added then
    local song = renoise.song()
    if song then
      song.selected_instrument_index_observable:remove_notifier(PakettiPolyendSliceSwitcherCheckInstrumentChange)
      paketti_polyend_slice_notifier_added = false
      print("-- Polyend Slice instrument change notifier removed")
    end
  end
end
