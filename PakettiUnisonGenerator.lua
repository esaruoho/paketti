function PakettiUpdateTrackDeviceInstrumentReferences(old_instrument_index, new_instrument_index)
  local song = renoise.song()
  local devices_updated = 0
  
  print("DEBUG: Scanning track devices for instrument references (old:", old_instrument_index, "-> new:", new_instrument_index, ")")
  
  -- Scan all tracks for devices that might reference instruments
  for track_index, track in ipairs(song.tracks) do
    for device_index, device in ipairs(track.devices) do
      -- Check for *Instr. Macros devices
      if device.display_name and (string.find(device.display_name, "Instr") or string.find(device.display_name, "Macro")) then
        -- Parameter 2 is typically the instrument index for *Instr. Macros
        if device.parameters and #device.parameters >= 2 then
          local current_target = device.parameters[2].value
          -- Convert to 1-based index for comparison (Renoise uses 0-based internally for this parameter)
          local current_instrument = math.floor(current_target) + 1
          
          if current_instrument == old_instrument_index then
            -- Update to point to the new unison instrument (convert back to 0-based)
            device.parameters[2].value = new_instrument_index - 1
            devices_updated = devices_updated + 1
            print("DEBUG: Updated " .. device.display_name .. " on track " .. track_index .. " from instrument " .. old_instrument_index .. " to " .. new_instrument_index)
          end
        end
      end
      
      -- Check for LFO devices that might target instruments
      if device.display_name and string.find(device.display_name, "LFO") then
        -- Some LFO devices might have instrument targeting parameters
        -- This would need to be checked case by case, but typically they target other parameters
        -- For now, we'll just log that we found an LFO device
        print("DEBUG: Found LFO device: " .. device.display_name .. " on track " .. track_index .. " (no instrument reference update needed)")
      end
    end
  end
  
  if devices_updated > 0 then
    print("DEBUG: Updated " .. devices_updated .. " track device(s) to point to the new unison instrument")
    renoise.app():show_status("Updated " .. devices_updated .. " track device(s) to target unison instrument")
  else
    print("DEBUG: No track devices found that were targeting the original instrument")
  end
end

function PakettiApplyFractionalShifting(sample, original_sample, fraction)
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
    print("DEBUG: Failed to apply fractional shifting:", tostring(error_msg))
  end
end

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
  print("DEBUG: Duplicate whole instrument preference:", preferences.pakettiUnisonDuplicateInstrument.value)
  
  -- Check if instrument is already pakettified
  local is_pakettified = false
  
  -- Check for plugins
  if instrument.plugin_properties and instrument.plugin_properties.plugin_device then
    is_pakettified = true
    print("DEBUG: Instrument has plugin - considered pakettified")
  end
  
  -- Check for active AHDSR envelope
  if instrument.sample_modulation_sets[1] and instrument.sample_modulation_sets[1].devices[2] and instrument.sample_modulation_sets[1].devices[2].is_active then
    is_pakettified = true
    print("DEBUG: Instrument has active AHDSR envelope - considered pakettified")
  end
  
  -- Check for macro assignments (if any macros are assigned to parameters)
  for i = 1, 8 do
    if instrument.macros[i] and #instrument.macros[i].mappings > 0 then
      is_pakettified = true
      print("DEBUG: Instrument has macro", i, "assigned - considered pakettified")
      break
    end
  end
  
  print("DEBUG: Instrument is pakettified:", is_pakettified)
  
  local new_instrument_index = selected_instrument_index + 1
  local new_instrument
  local external_editor_open = false
  
  if preferences.pakettiUnisonDuplicateInstrument.value and is_pakettified then
    -- Store external editor state and close it temporarily if needed
    if instrument.plugin_properties and instrument.plugin_properties.plugin_device then
      external_editor_open = instrument.plugin_properties.plugin_device.external_editor_visible
      if external_editor_open then
        instrument.plugin_properties.plugin_device.external_editor_visible = false
        print("DEBUG: Closed external plugin editor")
      end
    end
    
    -- Duplicate the entire instrument using copy_from
    song:insert_instrument_at(new_instrument_index)
    new_instrument = song.instruments[new_instrument_index]
    new_instrument:copy_from(instrument)
    
    -- Copy phrases if they exist
    if #instrument.phrases > 0 then
      for phrase_index = 1, #instrument.phrases do
        new_instrument:insert_phrase_at(phrase_index)
        new_instrument.phrases[phrase_index]:copy_from(instrument.phrases[phrase_index])
      end
    end
    
    song.selected_instrument_index = new_instrument_index
    print("DEBUG: Duplicated pakettified instrument using copy_from at index:", new_instrument_index)
  else
    -- Create new instrument for non-pakettified instruments or when preference is disabled
    song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    new_instrument = renoise.song().selected_instrument
    print("DEBUG: Created new instrument at index:", new_instrument_index, "(will be pakettified)")
  end


  local phrases_to_copy = #instrument.phrases
  print(string.format("\nORIGINAL: Instrument[%d:'%s'] has %d phrases:", 
    selected_instrument_index, instrument.name, phrases_to_copy))
  for i = 1, phrases_to_copy do
    print(string.format("  Source Instrument[%d:'%s'] Phrase[%d:'%s'] (%d lines)", 
      selected_instrument_index, instrument.name, i, instrument.phrases[i].name, #instrument.phrases[i].lines))
  end
  
  print(string.format("\nNEW: Created empty Instrument[%d:'%s']", new_instrument_index, new_instrument.name))
  
  -- Only load XRNI template if we're not duplicating a pakettified instrument
  if not (preferences.pakettiUnisonDuplicateInstrument.value and is_pakettified) then
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
  else
    print("\nSkipping XRNI template loading - using duplicated pakettified instrument")
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

  if preferences.pakettiUnisonDuplicateInstrument.value and is_pakettified then
    -- When duplicating a pakettified instrument, we already have all samples
    -- We need to prepare the selected sample for unison processing
    if selected_sample_index <= #new_instrument.samples and new_instrument.samples[selected_sample_index] then
      local base_sample = new_instrument.samples[selected_sample_index]
      base_sample.panning = 0.5
      base_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      base_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      base_sample.autofade = preferences.pakettiLoaderAutofade.value
      base_sample.name = string.format("%s (Unison 0 [0] (Center))", original_sample_name)
      print("DEBUG: Prepared existing sample", selected_sample_index, "for unison processing")
    else
      renoise.app():show_status("Selected sample not found in duplicated instrument")
      print("DEBUG: Selected sample", selected_sample_index, "not found in duplicated instrument")
      -- Restore 0G01 state before returning
      preferences._0G01_Loader.value=G01CurrentState 
      manage_sample_count_observer(preferences._0G01_Loader.value)
      return
    end
  else
    -- Original behavior: ensure we have at least one sample slot before copying
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
  end

  -- Rename the new instrument to match the original instrument's name with " (Unison)" appended
  new_instrument.name = original_instrument_name .. " (Unison)"

  -- Determine base sample for copying
  local base_sample_index = (preferences.pakettiUnisonDuplicateInstrument.value and is_pakettified) and selected_sample_index or 1
  local base_sample = new_instrument.samples[base_sample_index]
  
  if not base_sample then
    renoise.app():show_status("Base sample not found for unison processing")
    print("DEBUG: Base sample at index", base_sample_index, "not found")
    -- Restore 0G01 state before returning
    preferences._0G01_Loader.value=G01CurrentState 
    manage_sample_count_observer(preferences._0G01_Loader.value)
    return
  end

  
  -- Check if there are 2 samples routed to different FX chains OR old-style PCM Wave naming
  local use_dual_fx_chain_mode = false
  if #new_instrument.samples >= 2 and new_instrument.samples[1] and new_instrument.samples[2] then
    local sample1_name = new_instrument.samples[1].name or ""
    local sample2_name = new_instrument.samples[2].name or ""
    local sample1_fx_chain = new_instrument.samples[1].device_chain_index
    local sample2_fx_chain = new_instrument.samples[2].device_chain_index
    
    -- Check for FX chain routing (sample 1 -> chain 1, sample 2 -> chain 2)
    if sample1_fx_chain == 1 and sample2_fx_chain == 2 then
      use_dual_fx_chain_mode = true
      print("DEBUG: Found samples routed to different FX chains (1->1, 2->2) - using dual FX chain mode")
    -- Fallback: Check for old-style PCM Wave naming
    elseif string.find(sample1_name, "PCM Wave A") == 1 and string.find(sample2_name, "PCM Wave B") == 1 then
      use_dual_fx_chain_mode = true
      print("DEBUG: Found PCM Wave A and PCM Wave B names - using dual FX chain mode")
    end
  end
  
  if use_dual_fx_chain_mode then
    print("DEBUG: Using wavetable mode - 5 copies each of Wave A and Wave B with fifths fractions")
    
    -- Store original sample names for both waves
    local original_wave_a_name = new_instrument.samples[1].name:gsub("%s*%(Unison.*$", ""):gsub("^%s*(.-)%s*$", "%1")
    local original_wave_b_name = new_instrument.samples[2].name:gsub("%s*%(Unison.*$", ""):gsub("^%s*(.-)%s*$", "%1")
    
    -- Set up the original Wave A and Wave B samples
    local wave_a_sample = new_instrument.samples[1]
    local wave_b_sample = new_instrument.samples[2]
    
    -- Configure original samples
    wave_a_sample.panning = 0.5
    wave_a_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
    wave_a_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    wave_a_sample.autofade = preferences.pakettiLoaderAutofade.value
    wave_a_sample.loop_mode = 2
    wave_a_sample.device_chain_index = 1  -- FX Chain 1
    wave_a_sample.name = string.format("%s (Unison 0 [0] (Center))", original_wave_a_name)
    
    wave_b_sample.panning = 0.5
    wave_b_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
    wave_b_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    wave_b_sample.autofade = preferences.pakettiLoaderAutofade.value
    wave_b_sample.loop_mode = 2
    wave_b_sample.device_chain_index = 2  -- FX Chain 2
    wave_b_sample.name = string.format("%s (Unison 0 [0] (Center))", original_wave_b_name)
    
    -- Create 5 copies of Wave A for FX Chain 1 (wavetable mode)
    for i = 1, 5 do
      local new_index = #new_instrument.samples + 1
      new_instrument:insert_sample_at(new_index)
      if new_instrument.samples[new_index] then
        new_instrument.samples[new_index]:copy_from(wave_a_sample)
        new_instrument.samples[new_index].device_chain_index = 1  -- FX Chain 1
        print("DEBUG: Created Wave A copy", i, "at index", new_index)
      end
    end
    
    -- Create 5 copies of Wave B for FX Chain 2 (wavetable mode)
    for i = 1, 5 do
      local new_index = #new_instrument.samples + 1
      new_instrument:insert_sample_at(new_index)
      if new_instrument.samples[new_index] then
        new_instrument.samples[new_index]:copy_from(wave_b_sample)
        new_instrument.samples[new_index].device_chain_index = 2  -- FX Chain 2
        print("DEBUG: Created Wave B copy", i, "at index", new_index)
      end
    end
    
    -- Apply unison processing to both sets of samples (wavetable mode with fifths)
    local fraction_values = {1/5, 2/5, 3/5, 4/5}
    local unison_range = preferences.pakettiUnisonDetune.value or 25
    local original_fine_tune_a = wave_a_sample.fine_tune
    local original_fine_tune_b = wave_b_sample.fine_tune
    
    -- Check if samples are too large for fractional shifting
    local skip_fractional_shifting_a = wave_a_sample.sample_buffer.has_sample_data and wave_a_sample.sample_buffer.number_of_frames > 500000
    local skip_fractional_shifting_b = wave_b_sample.sample_buffer.has_sample_data and wave_b_sample.sample_buffer.number_of_frames > 500000
    
    -- Process Wave A copies (samples 3-7, since 1=original A, 2=original B)
    for i = 1, 5 do
      local sample_index = 2 + i  -- Start after the two original samples
      if new_instrument.samples[sample_index] then
        local sample = new_instrument.samples[sample_index]
        
        -- Alternate panning
        sample.panning = (i % 2 == 0) and 0.0 or 1.0
        
        -- Calculate detune offset
        local detune_offset = 0
        if preferences.pakettiUnisonDetuneHardSync.value then
          detune_offset = (i % 2 == 0) and -unison_range or unison_range
        elseif preferences.pakettiUnisonDetuneFluctuation.value then
          detune_offset = math.random(-unison_range, unison_range)
        else
          local detune_step = unison_range / 2.5  -- Adjusted for 5 samples
          local sample_offset = i - 3  -- Center around sample 3
          detune_offset = math.floor(sample_offset * detune_step)
        end
        
        sample.fine_tune = math.max(-127, math.min(127, original_fine_tune_a + detune_offset))
        sample.loop_mode = 2
        
        -- Apply fractional shifting only to first 4 copies (1/5, 2/5, 3/5, 4/5)
        if i <= 4 and not skip_fractional_shifting_a then
          local fraction = fraction_values[i]
          PakettiApplyFractionalShifting(sample, wave_a_sample, fraction)
        end
        
        -- Rename sample
        local panning_label = sample.panning == 0 and "50L" or "50R"
        sample.name = string.format("%s (Unison %d [%d] (%s))", original_wave_a_name, i, sample.fine_tune, panning_label)
      end
    end
    
    -- Process Wave B copies (samples 8-12)
    for i = 1, 5 do
      local sample_index = 7 + i  -- Start after the Wave A copies
      if new_instrument.samples[sample_index] then
        local sample = new_instrument.samples[sample_index]
        
        -- Alternate panning
        sample.panning = (i % 2 == 0) and 0.0 or 1.0
        
        -- Calculate detune offset
        local detune_offset = 0
        if preferences.pakettiUnisonDetuneHardSync.value then
          detune_offset = (i % 2 == 0) and -unison_range or unison_range
        elseif preferences.pakettiUnisonDetuneFluctuation.value then
          detune_offset = math.random(-unison_range, unison_range)
        else
          local detune_step = unison_range / 2.5  -- Adjusted for 5 samples
          local sample_offset = i - 3  -- Center around sample 3
          detune_offset = math.floor(sample_offset * detune_step)
        end
        
        sample.fine_tune = math.max(-127, math.min(127, original_fine_tune_b + detune_offset))
        sample.loop_mode = 2
        
        -- Apply fractional shifting only to first 4 copies (1/5, 2/5, 3/5, 4/5)
        if i <= 4 and not skip_fractional_shifting_b then
          local fraction = fraction_values[i]
          PakettiApplyFractionalShifting(sample, wave_b_sample, fraction)
        end
        
        -- Rename sample
        local panning_label = sample.panning == 0 and "50L" or "50R"
        sample.name = string.format("%s (Unison %d [%d] (%s))", original_wave_b_name, i, sample.fine_tune, panning_label)
      end
    end
    
    -- Set volume for all samples (adjusted for 12 samples instead of 8)
    local volume = math.db2lin(-21.5)  -- Adjusted for 12 samples: -18 - 20*log10(12/8) ≈ -21.5dB
    for i = 1, #new_instrument.samples do
      if new_instrument.samples[i] then
        new_instrument.samples[i].volume = volume
      end
    end
    

    
  else
    print("DEBUG: Using standard unison mode")
    
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
    if #new_instrument.samples >= i and new_instrument.samples[i] and base_sample then
      new_instrument.samples[i]:copy_from(base_sample)
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

  -- Set the volume to -18 dB for each sample in the new instrument (8 samples total)
  local volume = math.db2lin(-18)
  for i = 1, #new_instrument.samples do
    if new_instrument.samples[i] then
      new_instrument.samples[i].volume = volume
    else
      print("DEBUG: Sample slot", i, "not available for volume setting")
    end
  end

PakettiFillPitchStepperDigits(0.015,64)

  -- Apply loop mode and other settings to all samples in the new instrument
  for i = 1, #new_instrument.samples do
    if new_instrument.samples[i] then
      local sample = new_instrument.samples[i]
      -- Check if device chain 1 exists, otherwise use default chain 0
      if #new_instrument.sample_device_chains > 1 then
        sample.device_chain_index = 1
        print("DEBUG: Assigned sample", i, "to device chain 1")
      else
        sample.device_chain_index = 0
        print("DEBUG: Assigned sample", i, "to device chain 0 (chain 1 not available)")
      end
      sample.loop_mode = 2
    else
      print("DEBUG: Sample slot", i, "not available for final settings")
    end
  end
  end  -- Close the else block for standard unison mode

  -- Set the instrument volume
--  new_instrument.volume = 0.3

renoise.song().selected_phrase_index = original_phrase_index
print(string.format("Restored selected_phrase_index to: %d", renoise.song().selected_phrase_index))

  -- Update any track devices that were targeting the original instrument
  PakettiUpdateTrackDeviceInstrumentReferences(selected_instrument_index, new_instrument_index)

  -- Restore external editor state if needed (only for pakettified duplicate mode)
  if preferences.pakettiUnisonDuplicateInstrument.value and is_pakettified and external_editor_open and new_instrument.plugin_properties and new_instrument.plugin_properties.plugin_device then
    new_instrument.plugin_properties.plugin_device.external_editor_visible = true
    print("DEBUG: Restored external plugin editor")
  end

  if use_dual_fx_chain_mode then
    renoise.app():show_status("Wavetable unison samples created successfully (5+5 copies with fifths fractions).")
  else
    renoise.app():show_status("Unison samples created successfully.")
  end

  -- Restore 0G01 state before returning
  preferences._0G01_Loader.value=G01CurrentState 
  manage_sample_count_observer(preferences._0G01_Loader.value)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Unison Generator",invoke=PakettiCreateUnisonSamples}
