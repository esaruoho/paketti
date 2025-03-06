
function PakettiCreateUnisonSamples()
  local song = renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument

  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  if #instrument.samples == 0 then
    renoise.app():show_status("The selected instrument has no samples.")
    return
  end

  -- Determine the selected sample index
  local selected_sample_index = song.selected_sample_index
  if not selected_sample_index or selected_sample_index < 1 or selected_sample_index > #instrument.samples then
    renoise.app():show_status("No valid sample selected.")
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

    
  local new_instrument_index = selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local new_instrument = renoise.song().selected_instrument


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
    renoise.song().selected_instrument.sample_modulation_sets[1].devices[2].is_active = true
  end

  -- Copy sample buffer from the original instrument's selected sample to the new instrument
  renoise.song().selected_instrument.samples[1]:copy_from(original_sample)
  -- Reset the first sample's panning to center
  renoise.song().selected_instrument.samples[1].panning = 0.5
  renoise.song().selected_instrument.samples[1].interpolation_mode = preferences.pakettiLoaderInterpolation.value
  renoise.song().selected_instrument.samples[1].oversample_enabled = preferences.pakettiLoaderOverSampling.value
  renoise.song().selected_instrument.samples[1].autofade = preferences.pakettiLoaderAutoFade.value
  renoise.song().selected_instrument.samples[1].name = string.format("%s (Unison 0 [0] (Center))", original_sample_name)

  -- Rename the new instrument to match the original instrument's name with " (Unison)" appended
  renoise.song().selected_instrument.name = original_instrument_name .. " (Unison)"

  -- Create 7 additional sample slots for unison
  for i = 2, 8 do
    renoise.song().selected_instrument:insert_sample_at(i)
    local new_sample = renoise.song().selected_instrument:sample(i)
    renoise.song().selected_instrument.samples[i]:copy_from(renoise.song().selected_instrument.samples[1])
    renoise.song().selected_instrument.samples[i].loop_mode = 2
    renoise.song().selected_instrument.samples[i].interpolation_mode = preferences.pakettiLoaderInterpolation.value
    renoise.song().selected_instrument.samples[i].oversample_enabled = preferences.pakettiLoaderOverSampling.value
    renoise.song().selected_instrument.samples[i].autofade = preferences.pakettiLoaderAutoFade.value
end

  -- Define the finetune and panning adjustments
  local fraction_values = {1/8, 2/8, 3/8, 4/8, 5/8, 6/8, 7/8}
  local unison_range = 8  -- Adjust as needed

  -- Adjust finetune and panning for each unison sample
  for i = 2, 8 do
    local sample = renoise.song().selected_instrument.samples[i]
    local fraction = fraction_values[i - 1]
    -- Alternate between left and right panning
    sample.panning = (i % 2 == 0) and 0.0 or 1.0  -- Even indices get left (0.0), odd get right (1.0)
    sample.fine_tune = math.random(-unison_range, unison_range)
    sample.loop_mode = 2

    -- Adjust sample buffer if sample data exists
    if original_sample.sample_buffer.has_sample_data then
      local new_sample_buffer = sample.sample_buffer
      new_sample_buffer:prepare_sample_data_changes()
      for channel = 1, original_sample.sample_buffer.number_of_channels do
        for frame = 1, original_sample.sample_buffer.number_of_frames do
          local new_frame_index = frame + math.floor(original_sample.sample_buffer.number_of_frames * fraction)
          if new_frame_index > original_sample.sample_buffer.number_of_frames then
            new_frame_index = new_frame_index - original_sample.sample_buffer.number_of_frames
          end
          new_sample_buffer:set_sample_data(channel, new_frame_index, original_sample.sample_buffer:sample_data(channel, frame))
        end
      end
      new_sample_buffer:finalize_sample_data_changes()
    end

    -- Rename the sample to include unison details
    local panning_label = sample.panning == 0 and "50L" or "50R"
    sample.name = string.format("%s (Unison %d [%d] (%s))", original_sample_name, i - 1, sample.fine_tune, panning_label)
  end

  -- Set the volume to -14 dB for each sample in the new instrument
  local volume = math.db2lin(-18)
  for i = 1, #renoise.song().selected_instrument.samples do
    renoise.song().selected_instrument.samples[i].volume = volume
  end

  -- Apply loop mode and other settings to all samples in the new instrument
  for i = 1, #renoise.song().selected_instrument.samples do
    local sample = renoise.song().selected_instrument.samples[i]
    renoise.song().selected_instrument.samples[i].device_chain_index = 1
    sample.loop_mode = 2
  end

  -- Set the instrument volume
--  renoise.song().selected_instrument.volume = 0.3
PakettiFillPitchStepperDigits(0.015,64)

renoise.song().selected_phrase_index = original_phrase_index
print(string.format("Restored selected_phrase_index to: %d", renoise.song().selected_phrase_index))


  renoise.app():show_status("Unison samples created successfully.")
end

-- Adding keybinding and menu entries
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti..:Unison Generator",invoke=PakettiCreateUnisonSamples}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Unison Generator",invoke=PakettiCreateUnisonSamples}
