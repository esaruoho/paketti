-- PakettiSampleFXChainSlicer.lua
-- Sample Range Device Loader - copies sample selection to new pakettified instrument

-- Note: Toggle state is now persisted in preferences.pakettiSampleRangeDeviceLoaderEnabled

-- Function to prepare the sample range in a new instrument
function PakettiSampleRangePrepareNewInstrument()
  local song = renoise.song()
  local w = renoise.app().window
  local raw = renoise.ApplicationWindow
  
  -- Check if Sample Editor is displayed
  if w.active_middle_frame ~= raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
    renoise.app():show_status("Sample Editor is not displayed.")
    return false
  end
  
  local selected_sample = song.selected_sample
  if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    return false
  end
  
  local sample_buffer = selected_sample.sample_buffer
  
  -- Read the sample editor's sample range
  if not sample_buffer.selection_range or #sample_buffer.selection_range < 2 then
    renoise.app():show_status("No selection range defined.")
    return false
  end
  
  local selection_start = sample_buffer.selection_range[1]
  local selection_end = sample_buffer.selection_range[2]
  
  if selection_start == selection_end then
    renoise.app():show_status("No selection range defined.")
    return false
  end
  
  -- Temporarily disable AutoSamplify monitoring
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Store and disable 0G01 state
  local G01CurrentState = preferences._0G01_Loader.value
  if preferences._0G01_Loader.value == true or preferences._0G01_Loader.value == false then
    preferences._0G01_Loader.value = false
  end
  manage_sample_count_observer(preferences._0G01_Loader.value)
  
  -- Store and disable AutoSamplify Pakettify state
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false then
    preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  local original_sample_name = selected_sample.name
  
  -- Create instrument under current instrument
  local new_instrument_index = song.selected_instrument_index + 1
  if not safeInsertInstrumentAt(song, new_instrument_index) then return end
  song.selected_instrument_index = new_instrument_index
  
  -- Load the default XRNI instrument
  pakettiPreferencesDefaultInstrumentLoader()
  
  -- Copy the sample editor sample range to the sample slot
  local new_instrument = song.instruments[new_instrument_index]
  local new_sample = new_instrument.samples[1]
  
  -- Create new sample buffer with the selection range data
  new_sample.sample_buffer:create_sample_data(
    sample_buffer.sample_rate,
    sample_buffer.bit_depth,
    sample_buffer.number_of_channels,
    selection_end - selection_start + 1
  )
  
  new_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy sample data from selection range
  for c = 1, sample_buffer.number_of_channels do
    for f = selection_start, selection_end do
      new_sample.sample_buffer:set_sample_data(c, f - selection_start + 1, sample_buffer:sample_data(c, f))
    end
  end
  
  new_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Copy sample properties
  new_sample.name = original_sample_name .. " (FX)"
  new_sample.volume = selected_sample.volume
  new_sample.panning = selected_sample.panning
  new_sample.transpose = selected_sample.transpose
  new_sample.fine_tune = selected_sample.fine_tune
  new_sample.beat_sync_lines = selected_sample.beat_sync_lines
  new_sample.interpolation_mode = selected_sample.interpolation_mode
  new_sample.oversample_enabled = selected_sample.oversample_enabled
  new_sample.new_note_action = selected_sample.new_note_action
  new_sample.oneshot = selected_sample.oneshot
  new_sample.autoseek = selected_sample.autoseek
  new_sample.autofade = selected_sample.autofade
  new_sample.loop_mode = selected_sample.loop_mode
  
  -- Set loop points if loop mode is enabled
  if selected_sample.loop_mode ~= 1 then
    new_sample.loop_start = 1
    new_sample.loop_end = selection_end - selection_start + 1
  end
  
  -- Copy sample mapping
  new_sample.sample_mapping.base_note = selected_sample.sample_mapping.base_note
  new_sample.sample_mapping.map_velocity_to_volume = selected_sample.sample_mapping.map_velocity_to_volume
  new_sample.sample_mapping.note_range = {selected_sample.sample_mapping.note_range[1], selected_sample.sample_mapping.note_range[2]}
  new_sample.sample_mapping.velocity_range = {selected_sample.sample_mapping.velocity_range[1], selected_sample.sample_mapping.velocity_range[2]}
  
  -- Temporarily set names (will be updated with effect name later)
  new_instrument.name = original_sample_name .. " Region Excerpt"
  new_sample.name = original_sample_name .. " Region Excerpt"
  
  -- Assign sample to first FX chain
  if #new_instrument.sample_device_chains > 0 then
    new_sample.device_chain_index = 1
  end
  
  -- Switch to Sample FX Chain view
  w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
  
  -- Restore states
  preferences._0G01_Loader.value = G01CurrentState
  manage_sample_count_observer(preferences._0G01_Loader.value)
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  
  -- Return true with original sample name for later updating
  return true, original_sample_name
end

-- Toggle function
function PakettiSampleRangeDeviceLoaderToggle()
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = not preferences.pakettiSampleRangeDeviceLoaderEnabled.value
  
  if preferences.pakettiSampleRangeDeviceLoaderEnabled.value then
    renoise.app():show_status("Sample Range Device Loader: ON - LoadNative/LoadVST will copy selection to new instrument first")
  else
    renoise.app():show_status("Sample Range Device Loader: OFF")
  end
end

-- Keybindings
renoise.tool():add_keybinding{
  name="Global:Paketti:Sample Range Device Loader Toggle",
  invoke=function() PakettiSampleRangeDeviceLoaderToggle() end
}

renoise.tool():add_keybinding{
  name="Sample Editor:Paketti:Sample Range Device Loader Toggle",
  invoke=function() PakettiSampleRangeDeviceLoaderToggle() end
}

-- MIDI mappings
renoise.tool():add_midi_mapping{
  name="Paketti:Sample Range Device Loader Toggle",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiSampleRangeDeviceLoaderToggle() 
    end 
  end
}


