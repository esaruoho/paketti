-- Paketti Melodic Slice Export
-- Creates sample chains from multiple samples, then exports as PTI with slice markers
-- REVERSE of PTI import: Takes 48 individual samples -> creates 1 sample chain with slices
-- Maximum 48 samples, concatenated into one sample with slice markers at boundaries

-- Function to load max 48 manually selected samples for melodic slice (ProcessSlicer version)
function PakettiMelodicSliceLoadSamples()
  -- Prompt the user to select multiple sample files to load
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read({"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, "Select Melodic Samples (Max 48)")

  -- Check if files are selected, if not, return
  if #selected_sample_filenames == 0 then
    renoise.app():show_status("No files selected.")
    return
  end

  -- Limit to first 48 files only
  local max_samples = 48
  local files_to_load = {}
  for i = 1, math.min(#selected_sample_filenames, max_samples) do
    table.insert(files_to_load, selected_sample_filenames[i])
  end
  
  if #selected_sample_filenames > max_samples then
    renoise.app():show_status(string.format("Selected %d files - loading only first %d", #selected_sample_filenames, max_samples))
  end

  -- Start ProcessSlicer for sample loading
  local dialog, vb
  local process_slicer = ProcessSlicer(function()
    PakettiMelodicSliceLoadSamples_Worker(files_to_load, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Loading Melodic Slice Samples...")
  process_slicer:start()
end

--- ProcessSlicer worker function for loading melodic slice samples
function PakettiMelodicSliceLoadSamples_Worker(files_to_load, dialog, vb)
  -- Check for any existing instrument with samples or plugins and select a new instrument slot if necessary
  local song = renoise.song()
  local current_instrument_index = song.selected_instrument_index
  local current_instrument = song:instrument(current_instrument_index)

  if #current_instrument.samples > 0 or current_instrument.plugin_properties.plugin_loaded then
    song:insert_instrument_at(current_instrument_index + 1)
    song.selected_instrument_index = current_instrument_index + 1
  end

  -- Ensure the new instrument is selected
  current_instrument_index = song.selected_instrument_index
  current_instrument = song:instrument(current_instrument_index)

  -- Load the preset instrument
  local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
  renoise.app():load_instrument(defaultInstrument)

  -- Update the instrument reference after loading the instrument
  current_instrument = song.selected_instrument
  
  -- Set the instrument name
  local instrument_slot_hex = string.format("%02X", song.selected_instrument_index - 1)
  current_instrument.name = instrument_slot_hex .. "_Melodic"

  -- Load samples with ProcessSlicer yielding
  for i, filename in ipairs(files_to_load) do
    -- Update progress dialog
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Loading sample %d/%d...", i, #files_to_load)
    end
    renoise.app():show_status(string.format("Loading melodic sample %d/%d...", i, #files_to_load))
    
    if i == 1 then
      -- Replace first sample
      current_instrument.samples[1].sample_buffer:load_from(filename)
      local fn = (filename:match("[^/\\]+$") or filename):gsub("%.%w+$", "")
      current_instrument.samples[1].name = fn
    else
      -- Insert new samples
      current_instrument:insert_sample_at(i)
      current_instrument.samples[i].sample_buffer:load_from(filename)
      local fn = (filename:match("[^/\\]+$") or filename):gsub("%.%w+$", "")
      current_instrument.samples[i].name = fn
    end
    
    -- Apply Paketti preferences to each sample
    local sample = current_instrument.samples[i]
    sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
    sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    sample.autofade = preferences.pakettiLoaderAutofade.value
    sample.autoseek = preferences.pakettiLoaderAutoseek.value
    sample.loop_mode = preferences.pakettiLoaderLoopMode.value
    sample.new_note_action = preferences.pakettiLoaderNNA.value
    sample.loop_release = preferences.pakettiLoaderLoopExit.value
    sample.oneshot = preferences.pakettiLoaderOneshot.value
    
    -- Set to full key range and C-5 base note
    sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
    sample.sample_mapping.base_note = 60 -- C-5
    
    -- Yield every 5 samples to keep UI responsive
    if i % 5 == 0 then
      coroutine.yield()
    end
  end

  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end

  print(string.format("-- Loaded %d melodic samples for melodic slice processing", #files_to_load))
  renoise.app():show_status(string.format("Loaded %d melodic samples ready for slice processing", #files_to_load))
end

-- One-shot melodic slice creation and export function (SIMPLE DRY approach!)
function PakettiMelodicSliceExport()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have a valid instrument and samples
  if not inst or #inst.samples == 0 then
    renoise.app():show_error("No instrument or samples selected for melodic slice export")
    return
  end
  
  -- Follow drumkit loading pattern: only process max 48 samples
  local max_samples = 48
  local total_samples = math.min(#inst.samples, max_samples)
  
  if #inst.samples > max_samples then
    renoise.app():show_status(string.format("Instrument has %d samples - processing only first %d", #inst.samples, max_samples))
  end
  
  print("------------")
  print(string.format("-- PakettiMelodicSlice: ONE-SHOT melodic slice export from %d samples", total_samples))
  
  -- STEP 1: Set up velocity switching (first active, others inactive)
  print("-- PakettiMelodicSlice: Setting up velocity switching...")
  for i = 1, total_samples do
    local sample = inst.samples[i]
    if sample then
      -- Set full key range for all samples
      sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
      sample.sample_mapping.base_note = 60 -- C-5 (MIDI note 60)
      
      -- Set velocity range: first sample active, others inactive
      if i == 1 then
        sample.sample_mapping.velocity_range = {0, 127} -- First sample active
        print(string.format("-- Sample %02d: '%s' - ACTIVE (velocity 00-7F, base note C-5)", i, sample.name))
      else
        sample.sample_mapping.velocity_range = {0, 0} -- Others inactive
        print(string.format("-- Sample %02d: '%s' - inactive (velocity 00-00, base note C-5)", i, sample.name))
      end
    end
  end
  
  -- STEP 2: Use existing sample chain creation, then export as SLICE mode (not Beat Slice!)
  current_selected_slice = 0 -- First sample = slice 0 for PTI
  paketti_melodic_slice_mode = true -- Set melodic slice mode flag for PTI export
  print("-- PakettiMelodicSlice: Creating sample chain for MELODIC SLICE export...")
  renoise.app():show_status("Creating melodic slice sample chain...")
  
  -- Call existing sample chain creation logic - it will now handle PTI export internally
  save_pti_as_drumkit_stereo(true) -- Skip save prompt, ProcessSlicer will call pti_savesample() at the end
  
  -- CRITICAL FIX: ProcessSlicer is ASYNCHRONOUS! The pti_savesample() call is now handled
  -- within the ProcessSlicer worker function, so we don't need to call it here.
  -- The sample chain creation and PTI export will happen in the background.
end



-- Function to create melodic slice instrument (INDIVIDUAL SAMPLES with velocity switching)
function PakettiMelodicSliceCreateChain()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have a valid instrument and samples
  if not inst or #inst.samples == 0 then
    renoise.app():show_error("No instrument or samples selected")
    return
  end
  
  -- Follow drumkit loading pattern: only process max 48 samples
  local max_samples = 48
  local total_samples = math.min(#inst.samples, max_samples)
  
  if #inst.samples > max_samples then
    renoise.app():show_status(string.format("Instrument has %d samples - processing only first %d", #inst.samples, max_samples))
  end
  
  print("------------")
  print(string.format("-- PakettiMelodicSlice: Setting up melodic slice instrument with %d INDIVIDUAL samples", total_samples))
  
  -- Set up velocity ranges: first sample active (00-7F), others inactive (00-00)
  for i = 1, total_samples do
    local sample = inst.samples[i]
    if sample then
      -- Set full key range for all samples
      sample.sample_mapping.note_range = {0, 119} -- C-0 to B-9
      sample.sample_mapping.base_note = 60 -- C-5 (MIDI note 60)
      
      -- Set velocity range based on position
      if i == 1 then
        sample.sample_mapping.velocity_range = {0, 127} -- First sample active
        print(string.format("-- Sample %02d: '%s' - ACTIVE (velocity 00-7F, base note C-5)", i, sample.name))
      else
        sample.sample_mapping.velocity_range = {0, 0} -- Others inactive
        print(string.format("-- Sample %02d: '%s' - inactive (velocity 00-00, base note C-5)", i, sample.name))
      end
    end
  end
  
  -- Slice Switcher will automatically work with this instrument since it has multiple samples
  print(string.format("-- Melodic slice instrument ready: %d samples, first sample active", total_samples))
  print("-- Use 'Open Slice Switcher' to switch between samples")
  
  -- Update instrument name
  inst.name = inst.name .. " (Melodic Slice Setup)"
  
  print(string.format("-- PakettiMelodicSlice: Melodic slice instrument setup complete: %d individual samples", total_samples))
  print("-- Use 'Open Slice Switcher' to audition and switch between samples")
  print("-- Use 'Export as Melodic Slice' to create sample chain and export PTI")
  renoise.app():show_status(string.format("Melodic slice setup complete: %d samples, first sample active", total_samples))
end

-- Function to export current velocity-mapped instrument as sample chain PTI (SIMPLE DRY approach!)
function PakettiMelodicSliceExportCurrent()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have a valid instrument with multiple samples
  if not inst or #inst.samples == 0 then
    renoise.app():show_error("No instrument selected for melodic slice export")
    return
  end
  
  if #inst.samples == 1 then
    renoise.app():show_error("Need multiple samples for melodic slice export. Use 'Create Melodic Slice Instrument' first.")
    return
  end
  
  -- Find which sample is currently active (velocity 00-7F) - that becomes the selected slice
  local active_sample_index = 1 -- Default to first
  local total_samples = math.min(48, #inst.samples)
  
  for i = 1, total_samples do
    local sample = inst.samples[i]
    if sample and sample.sample_mapping.velocity_range[2] > 0 then -- Active velocity range
      active_sample_index = i
      print(string.format("-- Found active sample: %d ('%s') with velocity %d-%d", 
        i, sample.name, sample.sample_mapping.velocity_range[1], sample.sample_mapping.velocity_range[2]))
      break
    end
  end
  
  print("------------")
  print(string.format("-- PakettiMelodicSlice: Exporting melodic slice instrument with %d samples", total_samples))
  print(string.format("-- Active sample: %d ('%s') - will be selected slice %d in PTI", active_sample_index, inst.samples[active_sample_index].name, active_sample_index - 1))
  
  -- SIMPLE: Set selected slice to the active sample (convert 1-based to 0-based for PTI)
  current_selected_slice = active_sample_index - 1
  paketti_melodic_slice_mode = true -- Set melodic slice mode flag for PTI export
  print(string.format("-- PakettiMelodicSlice: Set selected slice = %d for PTI export", current_selected_slice))
  
  -- Create sample chain, then export as SLICE mode (not Beat Slice!)
  print("-- PakettiMelodicSlice: Creating sample chain for MELODIC SLICE export...")
  renoise.app():show_status("Creating melodic slice sample chain...")
  
  -- DEBUG: Before sample chain creation
  print("-- DEBUG BEFORE: Selected instrument: '" .. inst.name .. "' (index " .. song.selected_instrument_index .. ")")
  print("-- DEBUG BEFORE: Total instruments in song: " .. #song.instruments)
  
  -- Call existing sample chain creation logic - it will now handle PTI export internally
  save_pti_as_drumkit_stereo(true) -- Skip save prompt, ProcessSlicer will call pti_savesample() at the end
  
  -- CRITICAL FIX: ProcessSlicer is ASYNCHRONOUS! The pti_savesample() call is now handled
  -- within the ProcessSlicer worker function, so we don't need to call it here.
  -- The sample chain creation and PTI export will happen in the background.
end

renoise.tool():add_keybinding{name="Global:Paketti:Melodic Slice Export (One-Shot)", invoke=PakettiMelodicSliceExport}
renoise.tool():add_keybinding{name="Global:Paketti:Melodic Slice Create Chain", invoke=PakettiMelodicSliceCreateChain}
renoise.tool():add_keybinding{name="Global:Paketti:Melodic Slice Export Current", invoke=PakettiMelodicSliceExportCurrent}

