-----------------------------------------------------------------------
-- Automatic Sample Loader Settings Application System
-- Monitors instruments and applies Paketti loader settings when new samples are detected
-----------------------------------------------------------------------

-- Global state tracking for selected sample slot only
local previous_selected_sample_state = nil
local monitoring_enabled = true  -- Will be initialized from preferences on startup

-- Global state tracking for all instruments and samples
local previous_instrument_states = {}
local previous_sample_counts = {}

-- Track samples that were just created by AutoSamplify to prevent loops
local recently_created_samples = {}

-- Simple approach: track files being loaded and process them once
local files_being_loaded = {}
local loaded_files_tracker = {}
local last_instrument_count = 0

-- Re-entrancy guard: prevents the monitoring timer from triggering a second
-- processing pass while AutoSamplify is already creating/copying instruments.
-- Also used as a "processing" flag so PakettiCheckForNewSamplesComprehensive
-- skips mid-batch: timer fires every 100 ms and instrument creation can take
-- longer than that if pakettiPreferencesDefaultInstrumentLoader is slow.
local autosamplify_processing = false


-----------------------------------------------------------------------
-- Helper Functions for Copying Instrument Data (FX Chains, Modulation, Phrases)
-----------------------------------------------------------------------

-- Copy Sample Device Chains (Sample FX) from source instrument to target instrument
-- Returns a mapping table: source_chain_index -> target_chain_index
function PakettiCopySampleDeviceChains(source_instrument, target_instrument)
  if not source_instrument or not target_instrument then
    print("DEBUG: PakettiCopySampleDeviceChains - Invalid instruments provided")
    return {}
  end
  
  local chain_mapping = {}
  local source_chains = source_instrument.sample_device_chains
  local target_chains_offset = #target_instrument.sample_device_chains
  
  print(string.format("DEBUG: Copying %d FX chains from source (target has %d existing chains)", 
                     #source_chains, target_chains_offset))
  
  -- Copy each source chain
  for source_chain_idx = 1, #source_chains do
    local source_chain = source_chains[source_chain_idx]
    
    -- Create new chain in target instrument
    local new_chain_idx = target_chains_offset + source_chain_idx
    target_instrument:insert_sample_device_chain_at(new_chain_idx)
    local target_chain = target_instrument.sample_device_chains[new_chain_idx]
    
    -- Copy chain name
    target_chain.name = source_chain.name
    
    -- Copy output routing if available
    if source_chain.output_routing then
      -- Check if the routing is available in the target
      local routing_available = false
      for _, available_routing in ipairs(target_chain.available_output_routings) do
        if available_routing == source_chain.output_routing then
          routing_available = true
          break
        end
      end
      if routing_available then
        target_chain.output_routing = source_chain.output_routing
      end
    end
    
    -- Copy devices (skip index 1 which is the mixer device - it's always present)
    local source_devices = source_chain.devices
    for device_idx = 2, #source_devices do
      local source_device = source_devices[device_idx]
      local device_path = source_device.device_path
      
      if device_path and device_path ~= "" then
        -- Check if device is available
        local device_available = false
        for _, available_device in ipairs(target_chain.available_devices) do
          if available_device == device_path then
            device_available = true
            break
          end
        end
        
        if device_available then
          -- Insert the device at the end of the chain
          local new_device_idx = #target_chain.devices + 1
          local new_device = target_chain:insert_device_at(device_path, new_device_idx)
          
          if new_device then
            -- Copy device state using active_preset_data (XML)
            local success, err = pcall(function()
              new_device.active_preset_data = source_device.active_preset_data
            end)
            
            if not success then
              print(string.format("DEBUG: Could not copy preset data for device '%s': %s", 
                                 source_device.name, tostring(err)))
              -- Fallback: copy individual parameters
              for param_idx = 1, #source_device.parameters do
                local source_param = source_device.parameters[param_idx]
                local target_param = new_device.parameters[param_idx]
                if target_param and source_param then
                  pcall(function()
                    target_param.value = source_param.value
                  end)
                end
              end
            end
            
            -- Copy display settings
            new_device.is_active = source_device.is_active
            new_device.is_maximized = source_device.is_maximized
            if source_device.display_name and source_device.display_name ~= "" then
              new_device.display_name = source_device.display_name
            end
            
            print(string.format("DEBUG: Copied device '%s' to chain %d", source_device.name, new_chain_idx))
          else
            print(string.format("DEBUG: Failed to insert device '%s' at path '%s'", 
                               source_device.name, device_path))
          end
        else
          print(string.format("DEBUG: Device '%s' (path: %s) not available in target chain", 
                             source_device.name, device_path))
        end
      end
    end
    
    -- Store the mapping
    chain_mapping[source_chain_idx] = new_chain_idx
    print(string.format("DEBUG: Mapped source chain %d -> target chain %d ('%s')", 
                       source_chain_idx, new_chain_idx, source_chain.name))
  end
  
  return chain_mapping
end

-- Copy Sample Modulation Sets from source instrument to target instrument
-- Returns a mapping table: source_set_index -> target_set_index
function PakettiCopySampleModulationSets(source_instrument, target_instrument)
  if not source_instrument or not target_instrument then
    print("DEBUG: PakettiCopySampleModulationSets - Invalid instruments provided")
    return {}
  end
  
  local modset_mapping = {}
  local source_modsets = source_instrument.sample_modulation_sets
  local target_modsets_offset = #target_instrument.sample_modulation_sets
  
  print(string.format("DEBUG: Copying %d modulation sets from source (target has %d existing sets)", 
                     #source_modsets, target_modsets_offset))
  
  -- Copy each source modulation set
  for source_set_idx = 1, #source_modsets do
    local source_modset = source_modsets[source_set_idx]
    
    -- Create new modulation set in target instrument
    local new_set_idx = target_modsets_offset + source_set_idx
    target_instrument:insert_sample_modulation_set_at(new_set_idx)
    local target_modset = target_instrument.sample_modulation_sets[new_set_idx]
    
    -- Use copy_from to copy all modulation set contents
    local success, err = pcall(function()
      target_modset:copy_from(source_modset)
    end)
    
    if success then
      print(string.format("DEBUG: Copied modulation set %d -> %d ('%s')", 
                         source_set_idx, new_set_idx, source_modset.name))
    else
      print(string.format("DEBUG: Error copying modulation set %d: %s", source_set_idx, tostring(err)))
      -- Fallback: copy basic properties manually
      target_modset.name = source_modset.name
      if source_modset.filter_type then
        target_modset.filter_type = source_modset.filter_type
      end
      if source_modset.pitch_range then
        target_modset.pitch_range = source_modset.pitch_range
      end
    end
    
    -- Store the mapping
    modset_mapping[source_set_idx] = new_set_idx
  end
  
  return modset_mapping
end

-- Copy Phrases from source instrument to target instrument
function PakettiCopyPhrases(source_instrument, target_instrument)
  if not source_instrument or not target_instrument then
    print("DEBUG: PakettiCopyPhrases - Invalid instruments provided")
    return
  end
  
  local source_phrases = source_instrument.phrases
  
  if #source_phrases == 0 then
    print("DEBUG: No phrases to copy from source instrument")
    return
  end
  
  print(string.format("DEBUG: Copying %d phrases from source instrument", #source_phrases))
  
  -- Copy each source phrase
  for phrase_idx = 1, #source_phrases do
    local source_phrase = source_phrases[phrase_idx]
    
    -- Insert new phrase in target instrument
    local new_phrase = target_instrument:insert_phrase_at(phrase_idx)
    
    if new_phrase then
      -- Use copy_from to copy phrase contents
      local success, err = pcall(function()
        new_phrase:copy_from(source_phrase)
      end)
      
      if success then
        print(string.format("DEBUG: Copied phrase %d ('%s')", phrase_idx, source_phrase.name))
      else
        print(string.format("DEBUG: Error copying phrase %d: %s", phrase_idx, tostring(err)))
      end
    else
      print(string.format("DEBUG: Failed to create phrase at index %d", phrase_idx))
    end
  end
  
  -- Copy phrase mappings if any exist
  if #source_instrument.phrase_mappings > 0 then
    print(string.format("DEBUG: Source has %d phrase mappings (note: mappings are auto-created with phrases)", 
                       #source_instrument.phrase_mappings))
  end
  
  -- Copy phrase playback mode
  target_instrument.phrase_playback_mode = source_instrument.phrase_playback_mode
  target_instrument.phrase_program = source_instrument.phrase_program
end

-- Helper function to check if source instrument has content worth copying
function PakettiSourceHasContentToCopy(source_instrument)
  if not source_instrument then return false end
  
  local has_fx_chains = #source_instrument.sample_device_chains > 0
  local has_modulation = #source_instrument.sample_modulation_sets > 0
  local has_phrases = #source_instrument.phrases > 0
  
  -- Check if any sample actually uses the FX chains or modulation
  local uses_fx = false
  local uses_modulation = false
  
  for _, sample in ipairs(source_instrument.samples) do
    if sample.device_chain_index > 0 then
      uses_fx = true
    end
    if sample.modulation_set_index > 0 then
      uses_modulation = true
    end
  end
  
  return (has_fx_chains and uses_fx) or (has_modulation and uses_modulation) or has_phrases
end

-----------------------------------------------------------------------
-- End of Helper Functions
-----------------------------------------------------------------------


-- AutoSamplify version of PakettiInjectApplyLoaderSettings (NO normalization)
function PakettiAutoSamplifyApplyLoaderSettings(sample)
  if not sample or not preferences then return end
  
  print(string.format("DEBUG: PakettiAutoSamplifyApplyLoaderSettings called for '%s'", sample.name))
  
  -- Check if PCM Writer is currently creating samples - if so, skip AutoSamplify processing
  if PCMWriterIsCreatingSamples and PCMWriterIsCreatingSamples() then
    print(string.format("DEBUG: Skipping AutoSamplify processing for '%s' - PCM Writer is creating samples", sample.name))
    return
  end
  
  -- Detect if this is a PCM Writer sample (they have specific naming patterns)
  local is_pcm_writer_sample = string.find(sample.name, "^PCM ") ~= nil
  
  -- Apply Paketti Loader preferences to the sample
  sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  
  -- For PCM Writer samples, preserve their loop_mode and NNA (they set these explicitly)
  if not is_pcm_writer_sample then
    sample.loop_mode = preferences.pakettiLoaderLoopMode.value
    sample.new_note_action = preferences.pakettiLoaderNNA.value
  else
    print(string.format("DEBUG: Preserving loop_mode and NNA for PCM Writer sample '%s'", sample.name))
  end
  
  sample.loop_release = preferences.pakettiLoaderLoopExit.value
  
  -- NO normalization in AutoSamplify - just apply sample settings
  print(string.format("Applied Paketti loader settings to sample: %s (no normalization)%s", sample.name, is_pcm_writer_sample and " - loop_mode and NNA preserved" or ""))
end

-- Function to get the current selected sample slot state
function PakettiGetSelectedSampleState()
  local song = renoise.song()
  if not song then
    return { exists = false, has_data = false, instrument_index = nil, sample_index = nil }
  end
  
  local instrument_index = song.selected_instrument_index
  local sample_index = song.selected_sample_index
  
  if instrument_index < 1 or instrument_index > #song.instruments then
    return { exists = false, has_data = false, instrument_index = instrument_index, sample_index = sample_index }
  end
  
  local instrument = song.instruments[instrument_index]
  if not instrument then
    return { exists = false, has_data = false, instrument_index = instrument_index, sample_index = sample_index }
  end
  
  -- Check if sample slot exists
  local sample_exists = (sample_index >= 1 and sample_index <= #instrument.samples)
  local has_sample_data = false
  
  if sample_exists then
    local sample = instrument.samples[sample_index]
    has_sample_data = (sample.sample_buffer and sample.sample_buffer.has_sample_data)
  end
  
  return {
    exists = sample_exists,
    has_data = has_sample_data,
    instrument_index = instrument_index,
    sample_index = sample_index
  }
end

-- Function to get state of all instruments and their samples
function PakettiGetAllInstrumentStates()
  local song = renoise.song()
  if not song then
    return {}
  end
  
  local states = {}
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    local sample_states = {}
    
    for j = 1, #instrument.samples do
      local sample = instrument.samples[j]
      local has_data = (sample.sample_buffer and sample.sample_buffer.has_sample_data)
      sample_states[j] = {
        exists = true,
        has_data = has_data,
        name = sample.name,
        -- Snapshot is_slice_alias so PakettiFindNewlyLoadedSamples can filter
        -- alias samples without needing a live song reference.
        is_slice_alias = sample.is_slice_alias,
        -- Frame count for richer deduplication: two files both named "Kick.wav"
        -- from different folders are distinguished by their length in frames,
        -- preventing false-positive deduplication of genuinely different samples.
        frame_count = has_data and sample.sample_buffer.number_of_frames or 0
      }
    end
    
    states[i] = {
      instrument_index = i,
      sample_count = #instrument.samples,
      sample_states = sample_states,
      name = instrument.name
    }
  end
  
  return states
end

-- Simple function to find newly loaded samples by comparing states
function PakettiFindNewlyLoadedSamples(current_states, previous_states)
  local new_samples = {}
  
  -- Check each instrument
  for i = 1, #current_states do
    local current_instr = current_states[i]
    local previous_instr = previous_states[i]
    
    if not previous_instr then
      -- New instrument - check if it was created by AutoSamplify.
      -- Match by BOTH index and name: after a previous insertion shifts all
      -- indices by 1, the index stored in recently_created_samples can be stale,
      -- but the instrument_name we recorded at creation time remains correct.
      local is_autosamplify_created = false
      for _, created_sample in ipairs(recently_created_samples) do
        if created_sample.instrument_index == i then
          is_autosamplify_created = true
          break
        end
        if created_sample.instrument_name and created_sample.instrument_name ~= ""
           and current_instr.name == created_sample.instrument_name then
          is_autosamplify_created = true
          break
        end
      end
      
      -- Only process if it wasn't created by AutoSamplify
      if not is_autosamplify_created then
        for j = 1, current_instr.sample_count do
          local sample = current_instr.sample_states[j]
          -- Skip slice alias samples: they are auto-created by Renoise from the
          -- parent sample's slice markers and must never be processed separately.
          if sample and sample.has_data and not sample.is_slice_alias then
            -- Richer dedup key: name + frame count so two "Kick.wav" files from
            -- different folders are not falsely collapsed into one tracker entry.
            local sample_key = sample.name .. "|" .. tostring(sample.frame_count or 0)

            -- Only process if we haven't seen this exact sample before
            if not loaded_files_tracker[sample_key] then
              table.insert(new_samples, {
                instrument_index = i,
                sample_index = j,
                sample_name = sample.name,
                dedup_key = sample_key
              })
              print(string.format("DEBUG: Found new sample: %s in instrument %d, slot %d", sample.name, i, j))
            else
              print(string.format("DEBUG: Skipping already processed sample: %s (already processed elsewhere)", sample.name))
            end
          end
        end
      else
        print(string.format("DEBUG: Skipping new instrument %d - created by AutoSamplify", i))
      end
    else
      -- Existing instrument - check for new samples
      for j = 1, current_instr.sample_count do
        local current_sample = current_instr.sample_states[j]
        local previous_sample = previous_instr.sample_states[j]
        
        -- Skip slice alias samples: auto-created by Renoise from slice markers on
        -- the parent sample; processing them separately causes duplicates.
        if current_sample and current_sample.has_data and not current_sample.is_slice_alias then
          local is_new = false
          
          if not previous_sample then
            -- Sample slot didn't exist before
            is_new = true
          elseif not previous_sample.has_data and current_sample.has_data then
            -- Sample slot was empty before, now has data
            is_new = true
          end
          
          if is_new then
            -- Check if this sample was just created by AutoSamplify
            local is_autosamplify_created = false
            for _, created_sample in ipairs(recently_created_samples) do
              if created_sample.instrument_index == i and created_sample.sample_index == j then
                is_autosamplify_created = true
                break
              end
            end
            
            if not is_autosamplify_created then
              -- Richer dedup key: name + frame count so two "Kick.wav" files from
              -- different folders are not falsely collapsed into one tracker entry.
              local sample_key = current_sample.name .. "|" .. tostring(current_sample.frame_count or 0)

              -- Only process if we haven't seen this exact sample before
              if not loaded_files_tracker[sample_key] then
                table.insert(new_samples, {
                  instrument_index = i,
                  sample_index = j,
                  sample_name = current_sample.name,
                  dedup_key = sample_key
                })
                print(string.format("DEBUG: Found new sample: %s in instrument %d, slot %d", current_sample.name, i, j))
              else
                print(string.format("DEBUG: Skipping already processed sample: %s (already processed elsewhere)", current_sample.name))
              end
            else
              print(string.format("DEBUG: Skipping sample %d in instrument %d - created by AutoSamplify", j, i))
            end
          end
        end
      end
    end
  end
  
  return new_samples
end

-- Function to check if instrument is already Pakettified
-- A "pakettified" instrument has the Volume AHDSR device present, regardless of whether it's active
function PakettiIsInstrumentPakettified(instrument)
  -- Check for plugins
  if instrument.plugin_properties and instrument.plugin_properties.plugin_device then
    return true
  end
  
  -- Check for Volume AHDSR device using helper function
  if find_volume_ahdsr_device(instrument) then
    return true
  end
  
  -- Check for macro assignments (if any macros are assigned to parameters)
  for i = 1, 8 do
    if instrument.macros[i] and #instrument.macros[i].mappings > 0 then
      return true
    end
  end
  
  return false
end

-- Function to apply Paketti loader settings to a specific sample
function PakettiApplyLoaderSettingsToSample(instrument_index, sample_index)
  if not monitoring_enabled then return end
  
  -- Check if we should skip automatic processing (e.g., when CTRL-O Pattern to Sample is handling it)
  if PakettiDontRunAutomaticSampleLoader then return end
  
  local song = renoise.song()
  if not song then return end
  
  if instrument_index < 1 or instrument_index > #song.instruments then
    return
  end
  
  local source_instrument = song.instruments[instrument_index]
  if not source_instrument or sample_index < 1 or sample_index > #source_instrument.samples then
    return
  end
  
  local source_sample = source_instrument.samples[sample_index]
  if not source_sample or not source_sample.sample_buffer or not source_sample.sample_buffer.has_sample_data then
    return
  end
  
  -- Store sample data before processing
  local sample_name = source_sample.name
  local is_pakettified = PakettiIsInstrumentPakettified(source_instrument)
  local has_other_samples = #source_instrument.samples > 1 or (sample_index > 1)
  
  -- Mark this sample as processed BEFORE doing any work.
  -- Use name + frame_count as key to distinguish two "Kick.wav" files from
  -- different folders that happen to share the same filename.
  local _fc = (source_sample.sample_buffer and source_sample.sample_buffer.has_sample_data)
              and source_sample.sample_buffer.number_of_frames or 0
  local _tracker_key = sample_name .. "|" .. tostring(_fc)
  loaded_files_tracker[_tracker_key] = true
  print(string.format("DEBUG: Marking sample '%s' (frames: %d) as processed", sample_name, _fc))
  
  print(string.format("Processing sample '%s' from instrument %d, slot %d (pakettified: %s, has_other_samples: %s)", 
                     sample_name, instrument_index, sample_index, 
                     tostring(is_pakettified), tostring(has_other_samples)))
  
  -- Check AutoSamplify Pakettify preference
  local should_pakettify = true
  if preferences and preferences.pakettiAutoSamplifyPakettify then
    should_pakettify = preferences.pakettiAutoSamplifyPakettify.value
  end
  
  -- If Pakettify is Off, just apply sample settings and normalize in place
  if not should_pakettify then
    print("AutoSamplify Pakettify is OFF - applying sample settings and normalization in place")
    PakettiAutoSamplifyApplyLoaderSettings(source_sample)
    renoise.app():show_status(string.format("Applied sample settings to '%s' (Pakettify OFF)", sample_name))
    return
  end
  
  -- If instrument is already pakettified and has other samples, just apply loader settings in place
  if is_pakettified and has_other_samples then
    print("Instrument already pakettified with other samples - applying loader settings in place")
    PakettiAutoSamplifyApplyLoaderSettings(source_sample)
    renoise.app():show_status(string.format("Applied Paketti settings to '%s' in existing pakettified instrument", sample_name))
    return
  end
  
  -- Store source sample's FX chain and modulation set indices BEFORE creating new instrument
  local source_device_chain_index = source_sample.device_chain_index
  local source_modulation_set_index = source_sample.modulation_set_index
  local source_has_content = PakettiSourceHasContentToCopy(source_instrument)
  
  print(string.format("DEBUG: Source sample indices - device_chain: %d, modulation_set: %d, has_content: %s",
                     source_device_chain_index, source_modulation_set_index, tostring(source_has_content)))
  
  -- Create new instrument after current one.
  -- Wrapped in pcall so any mid-creation Renoise API error becomes a logged
  -- warning rather than a hard crash that leaves monitoring permanently broken.
  local _create_ok, _create_err = pcall(function()
    local new_instrument_index = instrument_index + 1
    if not safeInsertInstrumentAt(song, new_instrument_index) then return end
    song.selected_instrument_index = new_instrument_index

    -- Track the newly created instrument to prevent loops.
    -- Store instrument_name (= sample_name) in addition to the index so the guard
    -- in PakettiFindNewlyLoadedSamples can still identify this instrument even
    -- after subsequent instrument insertions shift all indices by 1.
    table.insert(recently_created_samples, {
      instrument_index = new_instrument_index,
      instrument_name  = sample_name,
      sample_index     = 1,
      created_by_autosamplify = true,
    })
    print(string.format("DEBUG: Tracked new instrument %d ('%s') as AutoSamplify-created", new_instrument_index, sample_name))
  
  -- Apply the default XRNI settings to the new instrument
  print(string.format("Loading default XRNI into new instrument %d", new_instrument_index))
  pakettiPreferencesDefaultInstrumentLoader()

  -- Verify the new instrument is still accessible.
  -- pakettiPreferencesDefaultInstrumentLoader() can silently fail if no default XRNI
  -- is configured, or can change selected_instrument_index in unexpected ways.
  local new_instrument = song.instruments[new_instrument_index]
  if not new_instrument then
    print(string.format("ERROR: Expected instrument at index %d after loading XRNI, but got nil - aborting", new_instrument_index))
    return
  end

  -- Store the number of default chains and modulation sets from the loaded XRNI
  local default_chain_count = #new_instrument.sample_device_chains
  local default_modset_count = #new_instrument.sample_modulation_sets
  print(string.format("DEBUG: Default XRNI has %d FX chains and %d modulation sets",
                     default_chain_count, default_modset_count))

  -- Copy FX chains, modulation sets, and phrases from source instrument if it has content
  local chain_mapping = {}
  local modset_mapping = {}
  
  if source_has_content then
    print("DEBUG: Source instrument has content to copy - copying FX chains, modulation sets, and phrases")
    
    -- Copy Sample FX Chains from source (appending after default chains)
    if #source_instrument.sample_device_chains > 0 then
      chain_mapping = PakettiCopySampleDeviceChains(source_instrument, new_instrument)
    end
    
    -- Copy Sample Modulation Sets from source (appending after default sets)
    if #source_instrument.sample_modulation_sets > 0 then
      modset_mapping = PakettiCopySampleModulationSets(source_instrument, new_instrument)
    end
    
    -- Copy Phrases from source
    if #source_instrument.phrases > 0 then
      PakettiCopyPhrases(source_instrument, new_instrument)
    end
  end
  
  -- Clear default samples if they exist
  if #new_instrument.samples > 0 then
    for i = #new_instrument.samples, 1, -1 do
      new_instrument:delete_sample_at(i)
    end
  end
  
  -- Insert new sample slot and copy the sample data
  new_instrument:insert_sample_at(1)
  song.selected_sample_index = 1
  local new_sample = new_instrument.samples[1]
  
  -- Check if source sample is a slice alias - cannot use copy_from on slice alias samples
  if source_sample.is_slice_alias then
    print(string.format("DEBUG: Source sample '%s' is a slice alias, copying properties and buffer manually", sample_name))
    -- Copy sample properties manually
    new_sample.panning = source_sample.panning
    new_sample.volume = source_sample.volume
    new_sample.transpose = source_sample.transpose
    new_sample.fine_tune = source_sample.fine_tune
    new_sample.beat_sync_enabled = source_sample.beat_sync_enabled
    new_sample.beat_sync_lines = source_sample.beat_sync_lines
    new_sample.beat_sync_mode = source_sample.beat_sync_mode
    new_sample.interpolation_mode = source_sample.interpolation_mode
    new_sample.oversample_enabled = source_sample.oversample_enabled
    new_sample.new_note_action = source_sample.new_note_action
    new_sample.oneshot = source_sample.oneshot
    new_sample.mute_group = source_sample.mute_group
    new_sample.autoseek = source_sample.autoseek
    new_sample.autofade = source_sample.autofade
    new_sample.loop_mode = source_sample.loop_mode
    new_sample.loop_release = source_sample.loop_release
    
    -- Copy buffer data manually from alias sample
    local source_buffer = source_sample.sample_buffer
    local dest_buffer = new_sample.sample_buffer
    if source_buffer.has_sample_data then
      local success = dest_buffer:create_sample_data(
        source_buffer.sample_rate,
        source_buffer.bit_depth,
        source_buffer.number_of_channels,
        source_buffer.number_of_frames
      )
      if success then
        dest_buffer:prepare_sample_data_changes()
        for ch = 1, source_buffer.number_of_channels do
          for fr = 1, source_buffer.number_of_frames do
            dest_buffer:set_sample_data(ch, fr, source_buffer:sample_data(ch, fr))
          end
        end
        dest_buffer:finalize_sample_data_changes()
        -- Copy loop points after buffer is created
        if source_sample.loop_start <= source_buffer.number_of_frames then
          new_sample.loop_start = source_sample.loop_start
        end
        if source_sample.loop_end <= source_buffer.number_of_frames then
          new_sample.loop_end = source_sample.loop_end
        end
        print(string.format("DEBUG: Successfully copied alias sample buffer (%d frames, %d channels)", 
                           source_buffer.number_of_frames, source_buffer.number_of_channels))
      else
        print(string.format("ERROR: Failed to create sample buffer for alias sample '%s'", sample_name))
      end
    end
  else
    -- Normal copy for non-alias samples
    new_sample:copy_from(source_sample)
  end
  new_sample.name = sample_name
  new_instrument.name = sample_name
  
  -- Update sample's device_chain_index and modulation_set_index to point to copied chains/sets
  if source_device_chain_index > 0 and chain_mapping[source_device_chain_index] then
    new_sample.device_chain_index = chain_mapping[source_device_chain_index]
    print(string.format("DEBUG: Updated sample device_chain_index: %d -> %d",
                       source_device_chain_index, new_sample.device_chain_index))
  end
  
  if source_modulation_set_index > 0 and modset_mapping[source_modulation_set_index] then
    new_sample.modulation_set_index = modset_mapping[source_modulation_set_index]
    print(string.format("DEBUG: Updated sample modulation_set_index: %d -> %d",
                       source_modulation_set_index, new_sample.modulation_set_index))
  end
  
  -- Apply sample-specific loader settings to the new sample
  PakettiAutoSamplifyApplyLoaderSettings(new_sample)

  local copied_content = ""
  if source_has_content then
    local parts = {}
    if #chain_mapping > 0 then table.insert(parts, string.format("%d FX chains", #chain_mapping)) end
    if #modset_mapping > 0 then table.insert(parts, string.format("%d mod sets", #modset_mapping)) end
    if #source_instrument.phrases > 0 then table.insert(parts, string.format("%d phrases", #source_instrument.phrases)) end
    if #parts > 0 then
      copied_content = " + copied " .. table.concat(parts, ", ")
    end
  end

  print(string.format("Successfully Pakettified '%s' in new instrument %d with XRNI + loader settings%s", 
                     sample_name, new_instrument_index, copied_content))
  
    renoise.app():show_status(string.format("Auto-Pakettified '%s' to new instrument %d%s",
                                          sample_name, new_instrument_index, copied_content))
  end)  -- end pcall (instrument creation)
  if not _create_ok then
    print("ERROR: PakettiApplyLoaderSettingsToSample: instrument creation failed: " .. tostring(_create_err))
    renoise.app():show_status("AutoSamplify: instrument creation error - see Renoise log")
  end
end

-- Function to apply Paketti loader settings to the selected sample (legacy compatibility)
function PakettiApplyLoaderSettingsToSelectedSample()
  -- Set the re-entrancy flag so a concurrent 100 ms monitoring tick does not
  -- treat the partially-created instrument as a new unprocessed sample.
  if autosamplify_processing then
    print("DEBUG: PakettiApplyLoaderSettingsToSelectedSample skipped - already processing")
    return
  end
  autosamplify_processing = true
  local _ok, _err = pcall(function()
    local current_state = PakettiGetSelectedSampleState()
    if current_state.exists and current_state.has_data then
      PakettiApplyLoaderSettingsToSample(current_state.instrument_index, current_state.sample_index)
    end
  end)
  if not _ok then
    print("ERROR: PakettiApplyLoaderSettingsToSelectedSample: " .. tostring(_err))
    renoise.app():show_status("AutoSamplify: error applying settings - see Renoise log")
  end
  autosamplify_processing = false
end

-- Function to apply settings to multiple newly loaded samples
function PakettiApplyLoaderSettingsToNewSamples(new_samples)
  if not monitoring_enabled then return end
  
  -- Check if we should skip automatic processing
  if PakettiDontRunAutomaticSampleLoader then return end
  
  if #new_samples == 0 then return end

  -- Re-entrancy guard: if AutoSamplify is already creating instruments, skip this
  -- call. The monitoring timer fires every 100 ms and instrument creation can take
  -- longer (pakettiPreferencesDefaultInstrumentLoader is blocking), so a second
  -- invocation can arrive while the first is still running.
  if autosamplify_processing then
    print("DEBUG: AutoSamplify re-entrancy detected - skipping nested invocation")
    return
  end
  autosamplify_processing = true

  -- Wrap entire batch in pcall so any mid-batch Renoise API error:
  --   (a) produces a clear log message rather than a silent crash, and
  --   (b) always resets the re-entrancy flag so future timer ticks run normally.
  local _processing_ok, _processing_err = pcall(function()
    print(string.format("Processing %d newly loaded samples", #new_samples))
  
  -- Check AutoSamplify Pakettify preference
  local should_pakettify = true
  if preferences and preferences.pakettiAutoSamplifyPakettify then
    should_pakettify = preferences.pakettiAutoSamplifyPakettify.value
  end
  
  local song = renoise.song()
  if not song then return end
  
  -- Group samples by instrument for batch processing
  local samples_by_instrument = {}
  for _, sample_info in ipairs(new_samples) do
    local instr_idx = sample_info.instrument_index
    if not samples_by_instrument[instr_idx] then
      samples_by_instrument[instr_idx] = {}
    end
    table.insert(samples_by_instrument[instr_idx], sample_info)
  end
  
  -- Process each instrument's new samples.
  -- Iterate in DESCENDING index order so that when we insert a new instrument
  -- at instr_idx + 1, the shift only affects higher indices that have already
  -- been processed -- lower indices remain stable for subsequent iterations.
  local _sorted_instr_indices = {}
  for _idx in pairs(samples_by_instrument) do table.insert(_sorted_instr_indices, _idx) end
  table.sort(_sorted_instr_indices, function(a, b) return a > b end)
  for _, instr_idx in ipairs(_sorted_instr_indices) do
    local samples = samples_by_instrument[instr_idx]
    local instrument = song.instruments[instr_idx]
    if instrument then
      local is_pakettified = PakettiIsInstrumentPakettified(instrument)
      local total_samples = #instrument.samples
      local new_sample_count = #samples
      
      -- Check if this instrument has samples that were loaded from external sources
      -- (not created by AutoSamplify)
      local has_external_samples = false
      for i = 1, total_samples do
        local sample = instrument.samples[i]
        if sample and sample.sample_buffer.has_sample_data then
          -- Check if this sample is not in our recently created list
          local is_autosamplify_created = false
          for _, created_sample in ipairs(recently_created_samples) do
            if created_sample.instrument_index == instr_idx and created_sample.sample_index == i then
              is_autosamplify_created = true
              break
            end
          end
          if not is_autosamplify_created then
            has_external_samples = true
            break
          end
        end
      end
      
      if not should_pakettify then
        -- Pakettify OFF: Apply settings to all samples in place
        print(string.format("Pakettify OFF: Applying settings to %d samples in instrument %d", new_sample_count, instr_idx))
        for _, sample_info in ipairs(samples) do
          local sample = instrument.samples[sample_info.sample_index]
          if sample then
            -- Mark as processed before applying settings (name|frames key)
            local _fc = (sample.sample_buffer and sample.sample_buffer.has_sample_data)
                        and sample.sample_buffer.number_of_frames or 0
            loaded_files_tracker[sample.name .. "|" .. tostring(_fc)] = true
            print(string.format("DEBUG: Marking sample '%s' as processed (Pakettify OFF)", sample.name))
            PakettiAutoSamplifyApplyLoaderSettings(sample)
          end
        end
        renoise.app():show_status(string.format("Applied sample settings to %d samples in instrument %d (Pakettify OFF)", new_sample_count, instr_idx))
        
      elseif is_pakettified then
        -- Instrument already pakettified: Apply settings in place
        print(string.format("Instrument %d already pakettified: Applying settings to %d samples in place", instr_idx, new_sample_count))
        for _, sample_info in ipairs(samples) do
          local sample = instrument.samples[sample_info.sample_index]
          if sample then
            -- Mark as processed before applying settings (name|frames key)
            local _fc = (sample.sample_buffer and sample.sample_buffer.has_sample_data)
                        and sample.sample_buffer.number_of_frames or 0
            loaded_files_tracker[sample.name .. "|" .. tostring(_fc)] = true
            print(string.format("DEBUG: Marking sample '%s' as processed (already pakettified)", sample.name))
            PakettiAutoSamplifyApplyLoaderSettings(sample)
          end
        end
        renoise.app():show_status(string.format("Applied Paketti settings to %d samples in existing pakettified instrument %d", new_sample_count, instr_idx))
        
      elseif has_external_samples and new_sample_count > 1 then
        -- Multiple external samples in one instrument: Create one new instrument for all samples
        print(string.format("Multiple external samples (%d) in instrument %d: Creating single new instrument", new_sample_count, instr_idx))
        
        -- Store source sample indices BEFORE creating new instrument
        local source_indices = {}
        for _, sample_info in ipairs(samples) do
          local source_sample = instrument.samples[sample_info.sample_index]
          if source_sample then
            source_indices[sample_info.sample_index] = {
              device_chain_index = source_sample.device_chain_index,
              modulation_set_index = source_sample.modulation_set_index
            }
          end
        end
        local source_has_content = PakettiSourceHasContentToCopy(instrument)
        
        -- Create new instrument after current one
        local new_instrument_index = instr_idx + 1
        if not safeInsertInstrumentAt(song, new_instrument_index) then return end
        song.selected_instrument_index = new_instrument_index
        
        -- Track the newly created instrument to prevent loops.
        -- Store instrument_name alongside the index so we can still recognise this
        -- instrument even if a later insertion shifts all indices by 1.
        local _first_sample_name = (#samples > 0) and samples[1].sample_name or ""
        table.insert(recently_created_samples, {
          instrument_index = new_instrument_index,
          instrument_name  = _first_sample_name,
          sample_index     = 1,
          created_by_autosamplify = true,
        })
        print(string.format("DEBUG: Tracked new instrument %d ('%s') as AutoSamplify-created", new_instrument_index, _first_sample_name))
        
        -- Apply the default XRNI settings to the new instrument
        print(string.format("Loading default XRNI into new instrument %d", new_instrument_index))
        pakettiPreferencesDefaultInstrumentLoader()

        -- Verify the new instrument is still accessible after loading the XRNI.
        local new_instrument = song.instruments[new_instrument_index]
        if not new_instrument then
          print(string.format("ERROR: Expected instrument at index %d after XRNI load, got nil - aborting batch", new_instrument_index))
          return
        end

        -- Log default chains/modsets loaded from XRNI (informational only)
        print(string.format("DEBUG: Default XRNI has %d FX chains and %d modulation sets",
                           #new_instrument.sample_device_chains, #new_instrument.sample_modulation_sets))
        
        -- Copy FX chains, modulation sets, and phrases from source instrument if it has content
        local chain_mapping = {}
        local modset_mapping = {}
        
        if source_has_content then
          print("DEBUG: Source instrument has content to copy - copying FX chains, modulation sets, and phrases")
          
          -- Copy Sample FX Chains from source (appending after default chains)
          if #instrument.sample_device_chains > 0 then
            chain_mapping = PakettiCopySampleDeviceChains(instrument, new_instrument)
          end
          
          -- Copy Sample Modulation Sets from source (appending after default sets)
          if #instrument.sample_modulation_sets > 0 then
            modset_mapping = PakettiCopySampleModulationSets(instrument, new_instrument)
          end
          
          -- Copy Phrases from source
          if #instrument.phrases > 0 then
            PakettiCopyPhrases(instrument, new_instrument)
          end
        end
        
        -- Clear any slice markers from the default XRNI samples BEFORE deletion.
        -- Renoise forbids delete_sample_at on an instrument that has sliced samples
        -- (i.e. any sample with slice_markers), so we must clear those markers first.
        for si = 1, #new_instrument.samples do
          local s = new_instrument.samples[si]
          if s and #s.slice_markers > 0 then
            local markers_snapshot = {}
            for _, m in ipairs(s.slice_markers) do table.insert(markers_snapshot, m) end
            for _, m in ipairs(markers_snapshot) do s:delete_slice_marker(m) end
            print(string.format("DEBUG: Cleared %d slice markers from default-XRNI sample %d before deletion", #markers_snapshot, si))
          end
        end
        -- Clear default samples if they exist
        if #new_instrument.samples > 0 then
          for i = #new_instrument.samples, 1, -1 do
            new_instrument:delete_sample_at(i)
          end
        end

        -- Copy all new samples to the new instrument.
        --
        -- IMPORTANT: slice markers must NOT be inserted during this loop.
        -- As soon as any sample in new_instrument acquires slice markers, Renoise
        -- locks the sample list and subsequent insert_sample_at calls crash with:
        --   "can not modify sample list of sliced samples. modify 'slice_markers' instead."
        --
        -- Strategy:
        --   1. Skip slice alias samples (is_slice_alias=true). They are auto-created
        --      by Renoise when slice markers are applied to their parent sample.
        --   2. Copy parent samples (including those with slice markers) manually,
        --      but DEFER slice marker insertion until after all samples are inserted.
        --   3. Apply deferred slice markers in a second pass below.
        local slice_marker_jobs = {}  -- {dest_idx=n, markers={...}}
        local dest_idx = 0
        for _, sample_info in ipairs(samples) do
          local source_sample = instrument.samples[sample_info.sample_index]
          if source_sample then
            -- Skip slice aliases: auto-recreated by Renoise via slice markers on the parent.
            if source_sample.is_slice_alias then
              print(string.format("DEBUG: Skipping slice alias '%s' (auto-recreated via slice markers)", source_sample.name))
            else
              -- Mark as processed before copying (name|frames key)
              local _fc = (source_sample.sample_buffer and source_sample.sample_buffer.has_sample_data)
                          and source_sample.sample_buffer.number_of_frames or 0
              loaded_files_tracker[source_sample.name .. "|" .. tostring(_fc)] = true
              print(string.format("DEBUG: Marking sample '%s' as processed (multiple samples)", source_sample.name))

              dest_idx = dest_idx + 1

              -- Insert new sample slot
              new_instrument:insert_sample_at(dest_idx)
              local new_sample = new_instrument.samples[dest_idx]

              -- Samples with slice markers cannot use copy_from (it would copy the markers
              -- and immediately lock the sample list). Copy buffer + properties manually instead.
              if #source_sample.slice_markers > 0 then
                print(string.format("DEBUG: Source sample '%s' has slice markers - manual copy, markers deferred", source_sample.name))
                -- Copy sample properties manually
                new_sample.panning = source_sample.panning
                new_sample.volume = source_sample.volume
                new_sample.transpose = source_sample.transpose
                new_sample.fine_tune = source_sample.fine_tune
                new_sample.beat_sync_enabled = source_sample.beat_sync_enabled
                new_sample.beat_sync_lines = source_sample.beat_sync_lines
                new_sample.beat_sync_mode = source_sample.beat_sync_mode
                new_sample.interpolation_mode = source_sample.interpolation_mode
                new_sample.oversample_enabled = source_sample.oversample_enabled
                new_sample.new_note_action = source_sample.new_note_action
                new_sample.oneshot = source_sample.oneshot
                new_sample.mute_group = source_sample.mute_group
                new_sample.autoseek = source_sample.autoseek
                new_sample.autofade = source_sample.autofade
                new_sample.loop_mode = source_sample.loop_mode
                new_sample.loop_release = source_sample.loop_release

                -- Copy buffer data manually
                local source_buffer = source_sample.sample_buffer
                local dest_buffer = new_sample.sample_buffer
                if source_buffer.has_sample_data then
                  local success = dest_buffer:create_sample_data(
                    source_buffer.sample_rate,
                    source_buffer.bit_depth,
                    source_buffer.number_of_channels,
                    source_buffer.number_of_frames
                  )
                  if success then
                    dest_buffer:prepare_sample_data_changes()
                    for ch = 1, source_buffer.number_of_channels do
                      for fr = 1, source_buffer.number_of_frames do
                        dest_buffer:set_sample_data(ch, fr, source_buffer:sample_data(ch, fr))
                      end
                    end
                    dest_buffer:finalize_sample_data_changes()
                    -- Copy loop points after buffer is created
                    if source_sample.loop_start <= source_buffer.number_of_frames then
                      new_sample.loop_start = source_sample.loop_start
                    end
                    if source_sample.loop_end <= source_buffer.number_of_frames then
                      new_sample.loop_end = source_sample.loop_end
                    end
                    -- Defer slice markers - inserting them now would lock the sample list
                    local deferred_markers = {}
                    for _, marker in ipairs(source_sample.slice_markers) do
                      table.insert(deferred_markers, marker)
                    end
                    table.insert(slice_marker_jobs, {dest_idx = dest_idx, markers = deferred_markers})
                    print(string.format("DEBUG: Deferred %d slice markers for dest sample %d", #deferred_markers, dest_idx))
                    print(string.format("DEBUG: Successfully copied sample buffer (%d frames, %d channels)",
                                       source_buffer.number_of_frames, source_buffer.number_of_channels))
                  else
                    print(string.format("ERROR: Failed to create sample buffer for '%s'", source_sample.name))
                  end
                end
                new_sample.name = source_sample.name
              else
                -- Normal copy for samples without slice markers
                new_sample:copy_from(source_sample)
                new_sample.name = source_sample.name
              end

              -- Update sample's device_chain_index and modulation_set_index to point to copied chains/sets
              local orig_indices = source_indices[sample_info.sample_index]
              if orig_indices then
                if orig_indices.device_chain_index > 0 and chain_mapping[orig_indices.device_chain_index] then
                  new_sample.device_chain_index = chain_mapping[orig_indices.device_chain_index]
                  print(string.format("DEBUG: Updated sample '%s' device_chain_index: %d -> %d",
                                     new_sample.name, orig_indices.device_chain_index, new_sample.device_chain_index))
                end

                if orig_indices.modulation_set_index > 0 and modset_mapping[orig_indices.modulation_set_index] then
                  new_sample.modulation_set_index = modset_mapping[orig_indices.modulation_set_index]
                  print(string.format("DEBUG: Updated sample '%s' modulation_set_index: %d -> %d",
                                     new_sample.name, orig_indices.modulation_set_index, new_sample.modulation_set_index))
                end
              end

              -- Apply sample-specific loader settings
              PakettiAutoSamplifyApplyLoaderSettings(new_sample)
            end  -- not is_slice_alias
          end
        end

        -- Second pass: apply deferred slice markers now that all samples are inserted.
        -- Adding slice markers to a sample locks the instrument's sample list, so this
        -- MUST happen after all insert_sample_at calls are complete.
        for _, job in ipairs(slice_marker_jobs) do
          local new_sample = new_instrument.samples[job.dest_idx]
          if new_sample then
            for _, marker in ipairs(job.markers) do
              new_sample:insert_slice_marker(marker)
            end
            print(string.format("DEBUG: Applied %d deferred slice markers to dest sample %d", #job.markers, job.dest_idx))
          end
        end
        
        -- Set instrument name to the first sample's name
        if #samples > 0 then
          local first_sample = instrument.samples[samples[1].sample_index]
          if first_sample then
            new_instrument.name = first_sample.name
          end
        end
        
        local copied_content = ""
        if source_has_content then
          local parts = {}
          if #chain_mapping > 0 then table.insert(parts, string.format("%d FX chains", #chain_mapping)) end
          if #modset_mapping > 0 then table.insert(parts, string.format("%d mod sets", #modset_mapping)) end
          if #instrument.phrases > 0 then table.insert(parts, string.format("%d phrases", #instrument.phrases)) end
          if #parts > 0 then
            copied_content = " + copied " .. table.concat(parts, ", ")
          end
        end
        
        print(string.format("Successfully Pakettified %d samples from instrument %d to new instrument %d%s", 
                           new_sample_count, instr_idx, new_instrument_index, copied_content))
        renoise.app():show_status(string.format("Auto-Pakettified %d samples to new instrument %d%s", 
                                              new_sample_count, new_instrument_index, copied_content))
        
      else
        -- Single external sample: Create new instrument for this sample
        print(string.format("Single external sample in instrument %d: Creating new instrument", instr_idx))
        for _, sample_info in ipairs(samples) do
          PakettiApplyLoaderSettingsToSample(instr_idx, sample_info.sample_index)
        end
      end
    end
  end
  end)  -- end pcall (batch processing)
  if not _processing_ok then
    print("ERROR: PakettiApplyLoaderSettingsToNewSamples: " .. tostring(_processing_err))
    renoise.app():show_status("AutoSamplify: processing error - see Renoise log")
  end
  autosamplify_processing = false
end

-- Function to check for new samples across all instruments
function PakettiCheckForNewSamplesComprehensive()
  if not monitoring_enabled then return end

  -- Skip if AutoSamplify is currently creating instruments. The timer fires every
  -- 100 ms and instrument creation is a blocking operation, so re-entrant calls
  -- would observe a partially-constructed instrument list and misdetect new samples.
  if autosamplify_processing then return end

  -- Check if we should skip automatic processing (e.g., when CTRL-O Pattern to Sample is handling it)
  if PakettiDontRunAutomaticSampleLoader then return end
  
  -- Check if PCM Writer is currently creating samples
  if PCMWriterIsCreatingSamples and PCMWriterIsCreatingSamples() then return end
  
  local song = renoise.song()
  if not song then return end
  
  -- Check if the song was cleared (instrument count dropped significantly)
  local current_instrument_count = #song.instruments
  if current_instrument_count < last_instrument_count - 5 then
    -- Song was likely cleared, reset file tracking
    loaded_files_tracker = {}
    recently_created_samples = {}
    print("DEBUG: Song appears to have been cleared, resetting file tracking")
  end
  last_instrument_count = current_instrument_count
  
  -- Get current state of all instruments
  local current_states = PakettiGetAllInstrumentStates()
  
  -- Initialize previous states if this is the first run
  if #previous_instrument_states == 0 then
    previous_instrument_states = current_states
    return
  end
  
  -- Find newly loaded samples
  local new_samples = PakettiFindNewlyLoadedSamples(current_states, previous_instrument_states)
  
  if #new_samples > 0 then
    print(string.format("COMPREHENSIVE CHECK: Found %d newly loaded samples", #new_samples))
    for _, sample_info in ipairs(new_samples) do
      print(string.format("  - Instrument %d, Sample %d: '%s'", 
                         sample_info.instrument_index, sample_info.sample_index, sample_info.sample_name))
    end
    
    -- Filter out samples already marked as processed.
    -- Previous approach: if ANY sample was in the tracker, reset the ENTIRE tracker.
    -- Problem: that wipe briefly left ALL samples unguarded, risking re-processing.
    -- New approach: remove only the already-processed samples from the work list and
    -- leave the tracker intact. Samples not yet processed will proceed normally.
    local unprocessed_samples = {}
    for _, sample_info in ipairs(new_samples) do
      -- Use the richer dedup_key (name|frames) when available; fall back to
      -- sample_name for entries created before this hardening was in place.
      local _lookup_key = sample_info.dedup_key or sample_info.sample_name
      if loaded_files_tracker[_lookup_key] then
        print(string.format("DEBUG: Skipping already-processed sample '%s' (still in tracker)", sample_info.sample_name))
      else
        table.insert(unprocessed_samples, sample_info)
      end
    end

    -- Cap batch size to prevent a very large drag-and-drop import (50+ samples)
    -- from blocking Renoise for multiple seconds in a single timer tick.
    -- Any samples beyond the cap are left untracked, so the next 100 ms timer
    -- tick will detect them as still-new and process the next batch.
    local BATCH_CAP = 20
    if #unprocessed_samples > BATCH_CAP then
      print(string.format("DEBUG: Batch capped at %d (detected %d new samples); remainder will be processed on next timer tick",
                         BATCH_CAP, #unprocessed_samples))
      local capped = {}
      for k = 1, BATCH_CAP do
        table.insert(capped, unprocessed_samples[k])
      end
      unprocessed_samples = capped
    end

    -- Apply settings to unprocessed samples only
    if #unprocessed_samples > 0 then
      PakettiApplyLoaderSettingsToNewSamples(unprocessed_samples)
    end
  end

-- Clean up old tracking entries (keep only last 50 to prevent memory leaks).
-- 50 is large enough to cover any realistic rapid-fire batch import session
-- (e.g. dragging 40 samples at once) without the list going stale mid-batch.
if #recently_created_samples > 50 then
  local keep_count = 50
  local new_tracking = {}
  for i = #recently_created_samples - keep_count + 1, #recently_created_samples do
    table.insert(new_tracking, recently_created_samples[i])
  end
  recently_created_samples = new_tracking
  print(string.format("DEBUG: Cleaned up AutoSamplify tracking list, kept %d entries", #recently_created_samples))
end

-- Clean up old file tracking entries (keep only last 50 to prevent memory leaks)
local file_tracker_count = 0
for _ in pairs(loaded_files_tracker) do
  file_tracker_count = file_tracker_count + 1
end

if file_tracker_count > 50 then
  -- Clear the tracker periodically to prevent memory leaks
  loaded_files_tracker = {}
  print("DEBUG: Cleared file tracking to prevent memory leaks")
end

-- Update previous states
previous_instrument_states = current_states
end

-- Function to check for new samples in the currently selected sample slot (legacy)
function PakettiCheckForNewSamples()
  if not monitoring_enabled then return end
  
  -- Check if we should skip automatic processing (e.g., when CTRL-O Pattern to Sample is handling it)
  if PakettiDontRunAutomaticSampleLoader then return end
  
  -- Check if PCM Writer is currently creating samples
  if PCMWriterIsCreatingSamples and PCMWriterIsCreatingSamples() then return end
  
  local song = renoise.song()
  if not song then return end
  
  local current_state = PakettiGetSelectedSampleState()
  
  -- Only log when there are actual changes
  local state_changed = false
  if previous_selected_sample_state ~= nil then
    state_changed = (previous_selected_sample_state.exists ~= current_state.exists or
                    previous_selected_sample_state.has_data ~= current_state.has_data or
                    previous_selected_sample_state.instrument_index ~= current_state.instrument_index or
                    previous_selected_sample_state.sample_index ~= current_state.sample_index)
  end
  
  -- Check if we should apply settings
  local should_apply = false
  
  if previous_selected_sample_state == nil then
    -- First run, just initialize
    previous_selected_sample_state = current_state
    return
  end
  
  -- Only show debug info when state actually changes
  if state_changed then
    print(string.format("STATE CHANGE: Instr %d, Slot %d", 
                       current_state.instrument_index, current_state.sample_index))
    print(string.format("  Previous: exists=%s, has_data=%s", 
                       tostring(previous_selected_sample_state.exists), 
                       tostring(previous_selected_sample_state.has_data)))
    print(string.format("  Current:  exists=%s, has_data=%s", 
                       tostring(current_state.exists), 
                       tostring(current_state.has_data)))
  end
  
  -- Check for transitions that should trigger settings application:
  -- 1. Sample slot didn't exist before, now exists with data
  -- 2. Sample slot existed but was empty before, now has data
  if current_state.exists and current_state.has_data then
    local was_nonexistent = not previous_selected_sample_state.exists
    local was_empty = previous_selected_sample_state.exists and not previous_selected_sample_state.has_data
    local same_slot = (previous_selected_sample_state.instrument_index == current_state.instrument_index and 
                      previous_selected_sample_state.sample_index == current_state.sample_index)
    
    if same_slot and (was_nonexistent or was_empty) then
      should_apply = true
      print(string.format("TRIGGER: Detected new sample in slot %d of instrument %d (was %s, now has data)", 
                         current_state.sample_index, current_state.instrument_index,
                         was_nonexistent and "nonexistent" or "empty"))
    end
  end
  
  -- Apply settings if needed
  if should_apply then
    PakettiApplyLoaderSettingsToSelectedSample()
  end
  
  -- Update previous state
  previous_selected_sample_state = current_state
end

-- Function to initialize the monitoring system
function PakettiInitializeNewSampleMonitoring()
  local song = renoise.song()
  if not song then return end
  
  -- Initialize instrument count tracking
  last_instrument_count = #song.instruments
  
  -- Initialize with current selected sample state (legacy)
  previous_selected_sample_state = PakettiGetSelectedSampleState()
  
  -- Initialize comprehensive monitoring
  previous_instrument_states = PakettiGetAllInstrumentStates()
  
  print("Paketti sample monitoring system initialized for comprehensive sample detection")
end

-- Function to enable/disable monitoring
function PakettiToggleNewSampleMonitoring()
  monitoring_enabled = not monitoring_enabled
  
  -- Update preference to match
  if preferences and preferences.pakettiAutoSamplifyMonitoring then
    preferences.pakettiAutoSamplifyMonitoring.value = monitoring_enabled
  end
  
  -- Actually start/stop monitoring
  if monitoring_enabled then
    PakettiStartNewSampleMonitoring()
  else
    PakettiStopNewSampleMonitoring()
  end
  
  local status = monitoring_enabled and "enabled" or "disabled"
  renoise.app():show_status("Paketti new sample monitoring: " .. status)
  print("Paketti new sample monitoring: " .. status)
end

-- Function to toggle Pakettify
function PakettiToggleAutoSamplifyPakettify()
  if preferences and preferences.pakettiAutoSamplifyPakettify then
    preferences.pakettiAutoSamplifyPakettify.value = not preferences.pakettiAutoSamplifyPakettify.value
    local status = preferences.pakettiAutoSamplifyPakettify.value and "enabled" or "disabled"
    renoise.app():show_status("Paketti Auto-samplify Pakettify: " .. status)
  end
end

-- Function to temporarily disable monitoring (returns previous state)
function PakettiTemporarilyDisableNewSampleMonitoring()
  local was_enabled = monitoring_enabled
  monitoring_enabled = false
  print("Paketti sample monitoring temporarily disabled")
  return was_enabled
end

-- Function to restore monitoring to previous state
function PakettiRestoreNewSampleMonitoring(previous_state)
  monitoring_enabled = previous_state
  local status = monitoring_enabled and "enabled" or "disabled"
  print("Paketti sample monitoring restored to: " .. status)
end

-- Timer-based monitoring function
function PakettiMonitorNewSamplesTimer()
  -- Use comprehensive checking to detect multiple samples
  PakettiCheckForNewSamplesComprehensive()
end

-- Set up the monitoring system with observers and timer
local sample_monitoring_timer = nil

function PakettiStartNewSampleMonitoring()
  -- Guard: Check if song is available before setting up observables
  local song = renoise.song()
  if not song then
    print("Paketti AutoSamplify: Cannot start monitoring - no song loaded")
    return
  end
  
  -- Initialize states
  PakettiInitializeNewSampleMonitoring()
  
  -- Set up timer for periodic checking (every 100ms)
  if not renoise.tool():has_timer(PakettiMonitorNewSamplesTimer) then
    sample_monitoring_timer = renoise.tool():add_timer(PakettiMonitorNewSamplesTimer, 100)
  end
  
  -- Add notifiers for song changes
  if song.selected_instrument_index_observable:has_notifier(PakettiCheckForNewSamples) then
    song.selected_instrument_index_observable:remove_notifier(PakettiCheckForNewSamples)
  end
  song.selected_instrument_index_observable:add_notifier(PakettiCheckForNewSamples)
  
  -- Also monitor selected sample changes (note: uses selected_sample_observable, not selected_sample_index_observable)
  if song.selected_sample_observable:has_notifier(PakettiCheckForNewSamples) then
    song.selected_sample_observable:remove_notifier(PakettiCheckForNewSamples)
  end
  song.selected_sample_observable:add_notifier(PakettiCheckForNewSamples)
  
  print("Paketti new sample monitoring started")
end

function PakettiStopNewSampleMonitoring()
  -- Remove timer
  if renoise.tool():has_timer(PakettiMonitorNewSamplesTimer) then
    renoise.tool():remove_timer(PakettiMonitorNewSamplesTimer)
    sample_monitoring_timer = nil
  end
  
  -- Remove notifiers
  if renoise.song() and renoise.song().selected_instrument_index_observable:has_notifier(PakettiCheckForNewSamples) then
    renoise.song().selected_instrument_index_observable:remove_notifier(PakettiCheckForNewSamples)
  end
  
  if renoise.song() and renoise.song().selected_sample_observable:has_notifier(PakettiCheckForNewSamples) then
    renoise.song().selected_sample_observable:remove_notifier(PakettiCheckForNewSamples)
  end
  
  print("Paketti new sample monitoring stopped")
end

-- Named handler functions for proper notifier management
local function PakettiAutoSamplifyNewDocumentHandler()
  -- Check preference before starting monitoring
  if preferences and preferences.pakettiAutoSamplifyMonitoring and preferences.pakettiAutoSamplifyMonitoring.value then
    monitoring_enabled = true
    PakettiStartNewSampleMonitoring()
  else
    monitoring_enabled = false
  end
end

local function PakettiAutoSamplifyReleaseDocumentHandler()
  PakettiStopNewSampleMonitoring()
end

-- Add notifiers for app events (with guards to prevent duplicates)
if not renoise.tool().app_new_document_observable:has_notifier(PakettiAutoSamplifyNewDocumentHandler) then
  renoise.tool().app_new_document_observable:add_notifier(PakettiAutoSamplifyNewDocumentHandler)
end

if not renoise.tool().app_release_document_observable:has_notifier(PakettiAutoSamplifyReleaseDocumentHandler) then
  renoise.tool().app_release_document_observable:add_notifier(PakettiAutoSamplifyReleaseDocumentHandler)
end

-- Initialize monitoring when tool loads (only if preference is enabled and song is available)
local song_available, song = pcall(function() return renoise.song() end)
if song_available and song then
  -- Initialize monitoring_enabled from preferences
  if preferences and preferences.pakettiAutoSamplifyMonitoring then
    monitoring_enabled = preferences.pakettiAutoSamplifyMonitoring.value
    if monitoring_enabled then
      PakettiStartNewSampleMonitoring()
    end
  else
    -- Default to true if preference doesn't exist yet (first run)
    monitoring_enabled = true
    PakettiStartNewSampleMonitoring()
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle New Sample Auto-Settings", invoke=PakettiToggleNewSampleMonitoring}
