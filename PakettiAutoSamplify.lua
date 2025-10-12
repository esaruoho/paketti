-----------------------------------------------------------------------
-- Automatic Sample Loader Settings Application System
-- Monitors instruments and applies Paketti loader settings when new samples are detected
-----------------------------------------------------------------------

-- Global state tracking for selected sample slot only
local previous_selected_sample_state = nil
local monitoring_enabled = true

-- Global state tracking for all instruments and samples
local previous_instrument_states = {}
local previous_sample_counts = {}

-- Track samples that were just created by AutoSamplify to prevent loops
local recently_created_samples = {}

-- Simple approach: track files being loaded and process them once
local files_being_loaded = {}
local loaded_files_tracker = {}
local last_instrument_count = 0


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
        name = sample.name
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
      -- New instrument - check if it was created by AutoSamplify
      local is_autosamplify_created = false
      for _, created_sample in ipairs(recently_created_samples) do
        if created_sample.instrument_index == i then
          is_autosamplify_created = true
          break
        end
      end
      
      -- Only process if it wasn't created by AutoSamplify
      if not is_autosamplify_created then
        for j = 1, current_instr.sample_count do
          local sample = current_instr.sample_states[j]
          if sample and sample.has_data then
            -- Create a unique key based on sample name only (not instrument position)
            local sample_key = sample.name
            
            -- Only process if we haven't seen this exact sample before
            if not loaded_files_tracker[sample_key] then
              table.insert(new_samples, {
                instrument_index = i,
                sample_index = j,
                sample_name = sample.name
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
        
        if current_sample and current_sample.has_data then
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
              -- Create a unique key based on sample name only (not instrument position)
              local sample_key = current_sample.name
              
              -- Only process if we haven't seen this exact sample before
              if not loaded_files_tracker[sample_key] then
                table.insert(new_samples, {
                  instrument_index = i,
                  sample_index = j,
                  sample_name = current_sample.name
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
function PakettiIsInstrumentPakettified(instrument)
  -- Check for plugins
  if instrument.plugin_properties and instrument.plugin_properties.plugin_device then
    return true
  end
  
  -- Check for active AHDSR envelope
  if instrument.sample_modulation_sets[1] and instrument.sample_modulation_sets[1].devices[2] and instrument.sample_modulation_sets[1].devices[2].is_active then
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
  
  -- Mark this sample as processed BEFORE doing any work
  loaded_files_tracker[sample_name] = true
  print(string.format("DEBUG: Marking sample '%s' as processed", sample_name))
  
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
  
  -- Create new instrument after current one
  local new_instrument_index = instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  
  -- Track the newly created instrument to prevent loops
  table.insert(recently_created_samples, {
    instrument_index = new_instrument_index,
    sample_index = 1, -- New instruments typically have sample in slot 1
    created_by_autosamplify = true
  })
  print(string.format("DEBUG: Tracked new instrument %d as AutoSamplify-created", new_instrument_index))
  
  -- Apply the default XRNI settings to the new instrument
  print(string.format("Loading default XRNI into new instrument %d", new_instrument_index))
  pakettiPreferencesDefaultInstrumentLoader()
  
  -- Get the new instrument and clear its default sample if it exists
  local new_instrument = song.instruments[new_instrument_index]
  if #new_instrument.samples > 0 then
    for i = #new_instrument.samples, 1, -1 do
      new_instrument:delete_sample_at(i)
    end
  end
  
  -- Insert new sample slot and copy the sample data
  new_instrument:insert_sample_at(1)
  song.selected_sample_index = 1
  local new_sample = new_instrument.samples[1]
  
  -- Copy sample data (use copy_from on the sample, not the buffer!)
  new_sample:copy_from(source_sample)
  new_sample.name = sample_name
  new_instrument.name = sample_name
  
  -- Apply sample-specific loader settings to the new sample
  PakettiAutoSamplifyApplyLoaderSettings(new_sample)

  print(string.format("Successfully Pakettified '%s' in new instrument %d with XRNI + loader settings", 
                     sample_name, new_instrument_index))
  
  renoise.app():show_status(string.format("Auto-Pakettified '%s' to new instrument %d", 
                                        sample_name, new_instrument_index))
end

-- Function to apply Paketti loader settings to the selected sample (legacy compatibility)
function PakettiApplyLoaderSettingsToSelectedSample()
  local current_state = PakettiGetSelectedSampleState()
  if current_state.exists and current_state.has_data then
    PakettiApplyLoaderSettingsToSample(current_state.instrument_index, current_state.sample_index)
  end
end

-- Function to apply settings to multiple newly loaded samples
function PakettiApplyLoaderSettingsToNewSamples(new_samples)
  if not monitoring_enabled then return end
  
  -- Check if we should skip automatic processing
  if PakettiDontRunAutomaticSampleLoader then return end
  
  if #new_samples == 0 then return end
  
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
  
  -- Process each instrument's new samples
  for instr_idx, samples in pairs(samples_by_instrument) do
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
            -- Mark as processed before applying settings
            loaded_files_tracker[sample.name] = true
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
            -- Mark as processed before applying settings
            loaded_files_tracker[sample.name] = true
            print(string.format("DEBUG: Marking sample '%s' as processed (already pakettified)", sample.name))
            PakettiAutoSamplifyApplyLoaderSettings(sample)
          end
        end
        renoise.app():show_status(string.format("Applied Paketti settings to %d samples in existing pakettified instrument %d", new_sample_count, instr_idx))
        
      elseif has_external_samples and new_sample_count > 1 then
        -- Multiple external samples in one instrument: Create one new instrument for all samples
        print(string.format("Multiple external samples (%d) in instrument %d: Creating single new instrument", new_sample_count, instr_idx))
        
        -- Create new instrument after current one
        local new_instrument_index = instr_idx + 1
        song:insert_instrument_at(new_instrument_index)
        song.selected_instrument_index = new_instrument_index
        
        -- Track the newly created instrument to prevent loops
        table.insert(recently_created_samples, {
          instrument_index = new_instrument_index,
          sample_index = 1,
          created_by_autosamplify = true
        })
        print(string.format("DEBUG: Tracked new instrument %d as AutoSamplify-created", new_instrument_index))
        
        -- Apply the default XRNI settings to the new instrument
        print(string.format("Loading default XRNI into new instrument %d", new_instrument_index))
        pakettiPreferencesDefaultInstrumentLoader()
        
        -- Get the new instrument and clear its default sample if it exists
        local new_instrument = song.instruments[new_instrument_index]
        if #new_instrument.samples > 0 then
          for i = #new_instrument.samples, 1, -1 do
            new_instrument:delete_sample_at(i)
          end
        end
        
        -- Copy all new samples to the new instrument
        for sample_idx, sample_info in ipairs(samples) do
          local source_sample = instrument.samples[sample_info.sample_index]
          if source_sample then
            -- Mark as processed before copying
            loaded_files_tracker[source_sample.name] = true
            print(string.format("DEBUG: Marking sample '%s' as processed (multiple samples)", source_sample.name))
            
            -- Insert new sample slot
            new_instrument:insert_sample_at(sample_idx)
            local new_sample = new_instrument.samples[sample_idx]
            
            -- Copy sample data
            new_sample:copy_from(source_sample)
            new_sample.name = source_sample.name
            
            -- Apply sample-specific loader settings
            PakettiAutoSamplifyApplyLoaderSettings(new_sample)
          end
        end
        
        -- Set instrument name to the first sample's name
        if #samples > 0 then
          local first_sample = instrument.samples[samples[1].sample_index]
          if first_sample then
            new_instrument.name = first_sample.name
          end
        end
        
        print(string.format("Successfully Pakettified %d samples from instrument %d to new instrument %d", 
                           new_sample_count, instr_idx, new_instrument_index))
        renoise.app():show_status(string.format("Auto-Pakettified %d samples to new instrument %d", 
                                              new_sample_count, new_instrument_index))
        
      else
        -- Single external sample: Create new instrument for this sample
        print(string.format("Single external sample in instrument %d: Creating new instrument", instr_idx))
        for _, sample_info in ipairs(samples) do
          PakettiApplyLoaderSettingsToSample(instr_idx, sample_info.sample_index)
        end
      end
    end
  end
end

-- Function to check for new samples across all instruments
function PakettiCheckForNewSamplesComprehensive()
  if not monitoring_enabled then return end
  
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
    
    -- Check if any of the new samples are already marked as processed
    local has_processed_samples = false
    for _, sample_info in ipairs(new_samples) do
      if loaded_files_tracker[sample_info.sample_name] then
        has_processed_samples = true
        break
      end
    end
    
    -- If we have new samples but they're all marked as processed, reset tracking
    if has_processed_samples then
      loaded_files_tracker = {}
      print("DEBUG: Found new samples that were previously processed, resetting file tracking")
    end
    
    -- Apply settings to all newly loaded samples
    PakettiApplyLoaderSettingsToNewSamples(new_samples)
  end

-- Clean up old tracking entries (keep only last 10 to prevent memory leaks)
if #recently_created_samples > 10 then
  local keep_count = 10
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
  local status = monitoring_enabled and "enabled" or "disabled"
  renoise.app():show_status("Paketti new sample monitoring: " .. status)
  print("Paketti new sample monitoring: " .. status)
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
  -- Initialize states
  PakettiInitializeNewSampleMonitoring()
  
  -- Set up timer for periodic checking (every 100ms)
  if not renoise.tool():has_timer(PakettiMonitorNewSamplesTimer) then
    sample_monitoring_timer = renoise.tool():add_timer(PakettiMonitorNewSamplesTimer, 100)
  end
  
  -- Add notifiers for song changes
  if renoise.song().selected_instrument_index_observable:has_notifier(PakettiCheckForNewSamples) then
    renoise.song().selected_instrument_index_observable:remove_notifier(PakettiCheckForNewSamples)
  end
  renoise.song().selected_instrument_index_observable:add_notifier(PakettiCheckForNewSamples)
  
  -- Also monitor selected sample changes (note: uses selected_sample_observable, not selected_sample_index_observable)
  if renoise.song().selected_sample_observable:has_notifier(PakettiCheckForNewSamples) then
    renoise.song().selected_sample_observable:remove_notifier(PakettiCheckForNewSamples)
  end
  renoise.song().selected_sample_observable:add_notifier(PakettiCheckForNewSamples)
  
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

-- Add notifiers for app events
renoise.tool().app_new_document_observable:add_notifier(function()
  if monitoring_enabled then
    PakettiStartNewSampleMonitoring()
  end
end)

renoise.tool().app_release_document_observable:add_notifier(function()
  PakettiStopNewSampleMonitoring()
end)

-- Initialize monitoring when tool loads
if renoise.song() then
  PakettiStartNewSampleMonitoring()
end

-- Add keybindings and menu entries for manual control
renoise.tool():add_keybinding{name="Global:Paketti:Toggle New Sample Auto-Settings", invoke=PakettiToggleNewSampleMonitoring}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Toggle New Sample Auto-Settings", invoke=PakettiToggleNewSampleMonitoring}

