function PakettiCreateUnisonSamples()
  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument

  -- Store current 0G01 state and temporarily disable it to prevent unwanted track creation
  local G01CurrentState = preferences._0G01_Loader.value
  if preferences._0G01_Loader.value == true or preferences._0G01_Loader.value == false 
  then preferences._0G01_Loader.value = false
  end
  manage_sample_count_observer(preferences._0G01_Loader.value)

  if not instrument then
    renoise.app():show_status("No instrument selected.")
    -- Restore 0G01 state before returning
    preferences._0G01_Loader.value=G01CurrentState 
    manage_sample_count_observer(preferences._0G01_Loader.value)
    return
  end

  if #instrument.samples == 0 then
    renoise.app():show_status("The selected instrument has no samples.")
    -- Restore 0G01 state before returning
    preferences._0G01_Loader.value=G01CurrentState 
    manage_sample_count_observer(preferences._0G01_Loader.value)
    return
  end

  -- Determine the selected sample index
  local selected_sample_index = song.selected_sample_index
  if not selected_sample_index or selected_sample_index < 1 or selected_sample_index > #instrument.samples then
    renoise.app():show_status("No valid sample selected.")
    -- Restore 0G01 state before returning
    preferences._0G01_Loader.value=G01CurrentState 
    manage_sample_count_observer(preferences._0G01_Loader.value)
    return
  end

  local original_sample = instrument.samples[selected_sample_index]
  -- Clean up the original sample name by removing everything after and including "(Unison"
  local original_sample_name = original_sample.name:gsub("%s*%(Unison.*$", ""):gsub("^%s*(.-)%s*$", "%1")
  local original_instrument_name = instrument.name:gsub("%s*%(Unison%)%s*", "")
  original_sample.loop_mode = 2

    -- Store the original selected phrase index
    local original_phrase_index = renoise.song().selected_phrase_index
    print(string.format("\nStoring original selected_phrase_index: %d", original_phrase_index))

    
  print("DEBUG: Starting Unison Generator")
  print("DEBUG: Original instrument has", #instrument.samples, "samples")
  print("DEBUG: Selected sample index:", selected_sample_index)
  
  local new_instrument_index = selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local new_instrument = renoise.song().selected_instrument
  
  print("DEBUG: Created new instrument at index:", new_instrument_index)


  local phrases_to_copy = #instrument.phrases
  print(string.format("\nORIGINAL: Instrument[%d:'%s'] has %d phrases:", 
    selected_instrument_index, instrument.name, phrases_to_copy))
  for i = 1, phrases_to_copy do
    print(string.format("  Source Instrument[%d:'%s'] Phrase[%d:'%s'] (%d lines)", 
      selected_instrument_index, instrument.name, i, instrument.phrases[i].name, #instrument.phrases[i].lines))
  end
  
  print(string.format("\nNEW: Created empty Instrument[%d:'%s']", new_instrument_index, new_instrument.name))
  
  -- First load the XRNI
  print("\nLoading XRNI template...")
  print(string.format("Pre-XRNI state: Instrument[%d:'%s']", new_instrument_index, new_instrument.name))
  pakettiPreferencesDefaultInstrumentLoader()
  print(string.format("Immediate post-XRNI state: Instrument[%d:'%s']", new_instrument_index, new_instrument.name))
  
  -- Force refresh our reference to the instrument
  new_instrument = renoise.song().instruments[new_instrument_index]
  print(string.format("After refresh: Instrument[%d:'%s']", new_instrument_index, new_instrument.name))

  -- NOW copy the phrases after the XRNI is loaded
  if phrases_to_copy > 0 then
    print(string.format("\nCopying %d phrases from Instrument[%d:'%s'] to Instrument[%d:'%s']:", 
      phrases_to_copy, selected_instrument_index, instrument.name, 
      new_instrument_index, new_instrument.name))
    for i = 1, phrases_to_copy do
      print(string.format("  Creating phrase slot %d in Instrument[%d:'%s']...", 
        i, new_instrument_index, new_instrument.name))
      new_instrument:insert_phrase_at(i)
      print(string.format("  Copying from Instrument[%d:'%s'] Phrase[%d:'%s'] (%d lines)", 
        selected_instrument_index, instrument.name, i, instrument.phrases[i].name, #instrument.phrases[i].lines))
      new_instrument.phrases[i]:copy_from(instrument.phrases[i])
      print(string.format("  Result: Instrument[%d:'%s'] Phrase[%d:'%s'] (%d lines)", 
        new_instrument_index, new_instrument.name, i, new_instrument.phrases[i].name, #new_instrument.phrases[i].lines))
    end
  end

  print(string.format("\nFINAL STATE: Instrument[%d:'%s'] has %d phrases:", 
    new_instrument_index, new_instrument.name, #new_instrument.phrases))
  for i = 1, #new_instrument.phrases do
    print(string.format("  Instrument[%d:'%s'] Phrase[%d:'%s'] (%d lines)", 
      new_instrument_index, new_instrument.name, i, new_instrument.phrases[i].name, #new_instrument.phrases[i].lines))
  end
  print("") -- Empty line for readability


  if preferences.pakettiPitchbendLoaderEnvelope.value then
    if new_instrument.sample_modulation_sets[1] and new_instrument.sample_modulation_sets[1].devices[2] then
      new_instrument.sample_modulation_sets[1].devices[2].is_active = true
      print("DEBUG: Activated pitchbend envelope")
    else
      print("DEBUG: Pitchbend envelope device not available")
    end
  end

  -- Ensure we have at least one sample slot before copying
  if #new_instrument.samples == 0 then
    new_instrument:insert_sample_at(1)
    print("DEBUG: Created first sample slot in new instrument")
  end
  
  -- Validate sample slot exists before copying
  if #new_instrument.samples >= 1 and new_instrument.samples[1] then
    -- Copy sample buffer from the original instrument's selected sample to the new instrument
    new_instrument.samples[1]:copy_from(original_sample)
    -- Reset the first sample's panning to center
    new_instrument.samples[1].panning = 0.5
    new_instrument.samples[1].interpolation_mode = preferences.pakettiLoaderInterpolation.value
    new_instrument.samples[1].oversample_enabled = preferences.pakettiLoaderOverSampling.value
    new_instrument.samples[1].autofade = preferences.pakettiLoaderAutofade.value
    new_instrument.samples[1].name = string.format("%s (Unison 0 [0] (Center))", original_sample_name)
    print("DEBUG: Successfully copied original sample to slot 1")
  else
    renoise.app():show_status("Failed to create first sample slot")
    print("DEBUG: Failed to create or access first sample slot")
    -- Restore 0G01 state before returning
    preferences._0G01_Loader.value=G01CurrentState 
    manage_sample_count_observer(preferences._0G01_Loader.value)
    return
  end

  -- Rename the new instrument to match the original instrument's name with " (Unison)" appended
  new_instrument.name = original_instrument_name .. " (Unison)"

  -- Create 7 additional sample slots for unison
  for i = 2, 8 do
    local success, error_msg = pcall(function()
      new_instrument:insert_sample_at(i)
    end)
    
    if not success then
      print("DEBUG: Failed to create sample slot", i, ":", tostring(error_msg))
      break
    end
    
    -- Validate sample slot exists before copying
    if #new_instrument.samples >= i and new_instrument.samples[i] and new_instrument.samples[1] then
      new_instrument.samples[i]:copy_from(new_instrument.samples[1])
      new_instrument.samples[i].loop_mode = 2
      new_instrument.samples[i].interpolation_mode = preferences.pakettiLoaderInterpolation.value
      new_instrument.samples[i].oversample_enabled = preferences.pakettiLoaderOverSampling.value
      new_instrument.samples[i].autofade = preferences.pakettiLoaderAutofade.value
      print("DEBUG: Successfully created and configured sample slot", i)
    else
      print("DEBUG: Sample slot", i, "not accessible after creation")
      break
    end
  end

  -- Define the finetune and panning adjustments
  local fraction_values = {1/8, 2/8, 3/8, 4/8, 5/8, 6/8, 7/8}
  local unison_range = preferences.pakettiUnisonDetune.value or 25  -- Use preference value, default to 25 if nil
  local original_fine_tune = original_sample.fine_tune  -- Get the original sample's fine tune value

  -- Check if sample is too large for fractional shifting
  local skip_fractional_shifting = false
  if original_sample.sample_buffer.has_sample_data and original_sample.sample_buffer.number_of_frames > 500000 then
    skip_fractional_shifting = true
    print(string.format("Sample has %d frames - skipping fractional shifting to avoid slowdown", original_sample.sample_buffer.number_of_frames))
  end

  -- Adjust finetune and panning for each unison sample
  for i = 2, 8 do
    -- Validate sample exists before modifying
    if #new_instrument.samples < i or not new_instrument.samples[i] then
      print("DEBUG: Sample slot", i, "not available for detune adjustment")
      break
    end
    
    local sample = new_instrument.samples[i]
    local fraction = fraction_values[i - 1]
    -- Alternate between left and right panning
    sample.panning = (i % 2 == 0) and 0.0 or 1.0  -- Even indices get left (0.0), odd get right (1.0)
    
    local detune_offset = 0
    -- Calculate detune offset based on hard sync and fluctuation settings
    if preferences.pakettiUnisonDetuneHardSync.value then
      -- Hard sync: alternating -value, +value, -value, +value...
      detune_offset = (i % 2 == 0) and -unison_range or unison_range
    elseif preferences.pakettiUnisonDetuneFluctuation.value then
      -- Random fluctuation between -value and +value
      detune_offset = math.random(-unison_range, unison_range)
    else
      -- Fixed detune values distributed evenly
      local detune_step = unison_range / 4  -- Spread across 7 samples (2-8)
      local sample_offset = i - 5  -- Center around sample 5, so: -3,-2,-1,0,1,2,3
      detune_offset = math.floor(sample_offset * detune_step)
    end
    
    -- Apply offset to original fine tune, clamping to valid range
    sample.fine_tune = math.max(-127, math.min(127, original_fine_tune + detune_offset))
    
    sample.loop_mode = 2

    -- Adjust sample buffer if sample data exists and sample is not too large
    if original_sample.sample_buffer.has_sample_data and not skip_fractional_shifting then
      local success, error_msg = pcall(function()
        local new_sample_buffer = sample.sample_buffer
        
        -- Validate sample buffer exists and has data
        if not new_sample_buffer or not new_sample_buffer.has_sample_data then
          error("Sample buffer not available for fractional shifting")
        end
        
        -- Cache buffer dimensions to prevent race conditions
        local orig_channels = original_sample.sample_buffer.number_of_channels
        local orig_frames = original_sample.sample_buffer.number_of_frames
        local new_channels = new_sample_buffer.number_of_channels
        local new_frames = new_sample_buffer.number_of_frames
        
        -- Validate buffer dimensions match
        if orig_channels ~= new_channels or orig_frames ~= new_frames then
          error("Buffer dimension mismatch between original and new sample")
        end
        
        -- Validate buffer dimensions are reasonable
        if orig_channels <= 0 or orig_frames <= 0 or orig_channels > 8 or orig_frames > 10000000 then
          error("Invalid buffer dimensions")
        end
        
        new_sample_buffer:prepare_sample_data_changes()
        
        -- Double-check buffer state after prepare
        if not new_sample_buffer.has_sample_data then
          error("Sample buffer lost data after prepare_sample_data_changes")
        end
        
        for channel = 1, orig_channels do
          for frame = 1, orig_frames do
            local new_frame_index = frame + math.floor(orig_frames * fraction)
            
            -- Proper bounds checking with wrap-around
            while new_frame_index > orig_frames do
              new_frame_index = new_frame_index - orig_frames
            end
            while new_frame_index < 1 do
              new_frame_index = new_frame_index + orig_frames
            end
            
            -- Additional bounds validation before buffer access
            if channel >= 1 and channel <= orig_channels and 
               frame >= 1 and frame <= orig_frames and
               new_frame_index >= 1 and new_frame_index <= orig_frames then
              
              -- Validate buffer still has data before each access
              if original_sample.sample_buffer.has_sample_data and new_sample_buffer.has_sample_data then
                local sample_data = original_sample.sample_buffer:sample_data(channel, frame)
                new_sample_buffer:set_sample_data(channel, new_frame_index, sample_data)
              else
                error("Buffer lost data during processing")
              end
            else
              error("Buffer index out of bounds during fractional shifting")
            end
          end
        end
        
        -- Final validation before finalize
        if not new_sample_buffer.has_sample_data then
          error("Sample buffer lost data before finalize")
        end
        
        new_sample_buffer:finalize_sample_data_changes()
      end)
      
      if not success then
        print("DEBUG: Failed to apply fractional shifting to sample", i, ":", tostring(error_msg))
      else
        print("DEBUG: Successfully applied fractional shifting to sample", i)
      end
    end

    -- Rename the sample to include unison details
    local panning_label = sample.panning == 0 and "50L" or "50R"
    sample.name = string.format("%s (Unison %d [%d] (%s))", original_sample_name, i - 1, sample.fine_tune, panning_label)
  end

  -- Set the volume to -14 dB for each sample in the new instrument
  local volume = math.db2lin(-18)
  for i = 1, #new_instrument.samples do
    if new_instrument.samples[i] then
      new_instrument.samples[i].volume = volume
    else
      print("DEBUG: Sample slot", i, "not available for volume setting")
    end
  end

  -- Apply loop mode and other settings to all samples in the new instrument
  for i = 1, #new_instrument.samples do
    if new_instrument.samples[i] then
      local sample = new_instrument.samples[i]
      sample.device_chain_index = 1
      sample.loop_mode = 2
    else
      print("DEBUG: Sample slot", i, "not available for final settings")
    end
  end

  -- Set the instrument volume
--  new_instrument.volume = 0.3
PakettiFillPitchStepperDigits(0.015,64)

renoise.song().selected_phrase_index = original_phrase_index
print(string.format("Restored selected_phrase_index to: %d", renoise.song().selected_phrase_index))


  renoise.app():show_status("Unison samples created successfully.")

  -- Restore 0G01 state before returning
  preferences._0G01_Loader.value=G01CurrentState 
  manage_sample_count_observer(preferences._0G01_Loader.value)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Unison Generator",invoke=PakettiCreateUnisonSamples}
