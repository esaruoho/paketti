local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

-- Configuration for process yielding (in seconds)
local PROCESS_YIELD_INTERVAL = 1.5  -- Adjust this value to control how often the process yields

function setSampleZoom(zoom_level)
  -- Ensure we have a valid sample selected
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or no sample data")
    return
  end

  -- Switch to sample editor view
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

  local total_length = sample.sample_buffer.number_of_frames
  
  -- For zoom level 1, show the entire sample
  if zoom_level == 1 then
    sample.sample_buffer.display_start = 1  -- Start at 1, not 0!
    sample.sample_buffer.display_length = total_length
    renoise.app():show_status("Sample zoom set to 1x")
    return
  end
  
  local current_start = sample.sample_buffer.display_start
  local max_possible_length = total_length - current_start
  local display_length = math.min(max_possible_length, math.floor(total_length / zoom_level))
  
  print("Total length:", total_length)
  print("Current start:", current_start)
  print("Max possible length:", max_possible_length)
  print("Display length:", display_length)
  
  sample.sample_buffer.display_length = display_length

  renoise.app():show_status(string.format("Sample zoom set to %dx", zoom_level))
end


for i = 1, 11 do
  renoise.tool():add_keybinding{name=string.format("Sample Editor:Paketti:Set Sample Zoom " .. formatDigits(2,i) .. "x"),invoke=function() setSampleZoom(i) end}
  renoise.tool():add_menu_entry{name=string.format("Sample Editor:Paketti..:Set Sample Zoom..:Zoom " .. formatDigits(2,i) .. "x"),invoke=function() setSampleZoom(i) end}
end
---------
function setSampleZoomFromMidi(midi_value)
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected")
    return
  end

  print("MIDI value:", midi_value)

  -- Switch to sample editor view
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

  local total_length = sample.sample_buffer.number_of_frames
  
  -- If MIDI value is 0, show the entire sample
  if midi_value == 0 then
    sample.sample_buffer.display_start = 1
    sample.sample_buffer.display_length = total_length
    renoise.app():show_status("Sample zoom: Full view")
    return
  end

  -- Quantize MIDI value (1-127) to 11 steps (1x to 11x)
  local zoom_level = math.floor((midi_value / 127) * 10) + 1
  print("Zoom level:", zoom_level)
  
  local current_start = sample.sample_buffer.display_start
  local max_possible_length = total_length - current_start
  local display_length = math.min(max_possible_length, math.floor(total_length / zoom_level))
  
  print("Total length:", total_length)
  print("Current start:", current_start)
  print("Max possible length:", max_possible_length)
  print("Display length:", display_length)
  
  sample.sample_buffer.display_length = display_length

  renoise.app():show_status(string.format("Sample zoom: %dx", zoom_level))
end

renoise.tool():add_midi_mapping{name="Paketti:Midi Sample Zoom (1x-11x) [Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      setSampleZoomFromMidi(message.int_value)
    end
  end
}

function pakettiPreferencesDefaultInstrumentLoader()
  local defaultInstrument = preferences.pakettiDefaultXRNI.value
  local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend.xrni"
  
  -- Function to check if a file exists
  local function file_exists(file)
    local f = io.open(file, "r")
    if f then f:close() end
    return f ~= nil
  end

  -- Check if the defaultInstrument is nil or the file doesn't exist
  if not defaultInstrument or not file_exists(defaultInstrument) then
    defaultInstrument = fallbackInstrument
    renoise.app():show_status("The Default XRNI has not been set, using Paketti/Presets/12st_Pitchbend.xrni")
  end

  print("Loading instrument from path: " .. defaultInstrument)
  renoise.app():load_instrument(defaultInstrument)

  if preferences.pakettiPitchbendLoaderEnvelope.value then
renoise.song().selected_instrument.sample_modulation_sets[1].devices[2].is_active = true end

  if preferences.pakettiLoaderFilterType.value then
  renoise.song().selected_instrument.sample_modulation_sets[1].filter_type=preferences.pakettiLoaderFilterType.value end
end


---------------
function pitchBendDrumkitLoader()
  -- Prompt the user to select multiple sample files to load
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read({"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, "Paketti PitchBend Drumkit Sample Loader")

  -- Check if files are selected, if not, return
  if #selected_sample_filenames == 0 then
    renoise.app():show_status("No files selected.")
    return
  end

  -- Check for any existing instrument with samples or plugins and select a new instrument slot if necessary
  local song=renoise.song()
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
  local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
  

--  renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
renoise.app():load_instrument(defaultInstrument)

  -- Ensure the new instrument is selected
  current_instrument_index = song.selected_instrument_index
  current_instrument = song:instrument(current_instrument_index)

  -- Generate the instrument name based on the instrument slot using hexadecimal format, adjusting by -1
  local instrument_slot_hex = string.format("%02X", current_instrument_index - 1)
  local instrument_name_prefix = instrument_slot_hex .. "_Drumkit"

  -- Limit the number of samples to 120
  local max_samples = 120
  local num_samples_to_load = math.min(#selected_sample_filenames, max_samples)

  -- Overwrite the "Placeholder" with the first sample
  local selected_sample_filename = selected_sample_filenames[1]
  local sample = renoise.song().selected_instrument.samples[1]
  local sample_buffer = sample.sample_buffer
  local samplefilename = selected_sample_filename:match("^.+[/\\](.+)$")

  -- Set names for the instrument and sample
  current_instrument.name = instrument_name_prefix
  sample.name = samplefilename

  -- Load the first sample file into the sample buffer
  if sample_buffer:load_from(selected_sample_filename) then
    renoise.app():show_status("Sample " .. selected_sample_filename .. " loaded successfully.")
  else
    renoise.app():show_status("Failed to load the sample.")
  end
-- Set additional sample properties
  
  sample.interpolation_mode=preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = preferences.pakettiLoaderLoopExit.value

  -- Iterate over the rest of the selected files and insert them sequentially
  for i = 2, num_samples_to_load do
    selected_sample_filename = selected_sample_filenames[i]

  sample.interpolation_mode=preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = preferences.pakettiLoaderLoopExit.value


    -- Insert a new sample slot if necessary
    if #current_instrument.samples < i then
      current_instrument:insert_sample_at(i)
    end

    sample = current_instrument.samples[i]
    sample_buffer = sample.sample_buffer
    samplefilename = selected_sample_filename:match("^.+[/\\](.+)$")

    -- Set names for the sample
    sample.name = (samplefilename)

    -- Load the sample file into the sample buffer
    if sample_buffer:load_from(selected_sample_filename) then
      renoise.app():show_status("Sample " .. selected_sample_filename .. " loaded successfully.")
    else
      renoise.app():show_status("Failed to load the sample.")
    end
    if preferences.pakettiLoaderMoveSilenceToEnd.value ~= false then PakettiMoveSilence() end
    if preferences.pakettiLoaderNormalizeSamples.value ~= false then normalize_selected_sample() end
 
    -- Set additional sample properties
    --sample.oversample_enabled = true
    --sample.autofade = true
    --sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  end

  -- Check if there are more samples than the limit
  if #selected_sample_filenames > max_samples then
    local not_loaded_count = #selected_sample_filenames - max_samples
    renoise.app():show_status("Maximum Drumkit Zones is 120 - was not able to load " .. not_loaded_count .. " samples.")
  end
 
  if preferences.pakettiLoaderNormalizeSamples.value ~= false then normalize_all_samples_in_instrument() end
  if preferences.pakettiLoaderMoveSilenceToEnd.value ~= false then PakettiMoveSilenceAllSamples() end
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
  -- Load the *Instr. Macros device and rename it
if renoise.song().selected_track.type == 2 then renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") return else
  loadnative("Audio/Effects/Native/*Instr. Macros")
  
  local macro_device = song.selected_track:device(2)
  macro_device.display_name = instrument_name_prefix
  song.selected_track.devices[2].is_maximized = false
end
end 
  -- Additional actions after loading samples
  on_sample_count_change()
  -- showAutomation()
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments..:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}

renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti PitchBend Drumkit Sample Loader",invoke=function(message) if message:is_trigger() then pitchBendDrumkitLoader() end end}

function loadRandomDrumkitSamples(num_samples)
    -- Seed the random number generator with current time
    math.randomseed(os.time())
    -- Add some random calls to further randomize the sequence
    math.random(); math.random(); math.random()

    -- Prompt the user to select a folder
    local folder_path = renoise.app():prompt_for_path("Select Folder to Randomize Drumkit Loading From")
    if not folder_path then
        renoise.app():show_status("No folder selected.")
        return nil
    end

    -- Get all valid audio files in the selected directory and subdirectories using global function
    local original_sample_files = PakettiGetFilesInDirectory(folder_path)
    
    -- Check if there are enough files to choose from
    if #original_sample_files == 0 then
        renoise.app():show_status("No audio files found in the selected folder.")
        return nil
    end

    -- Create a working copy of the files table for this run
    local sample_files = {}
    for i, file in ipairs(original_sample_files) do
        sample_files[i] = file
    end

    -- Check if the selected instrument slot is empty or contains a plugin
    local song=renoise.song()
    local instrument = song.selected_instrument
    if #instrument.samples > 0 or instrument.plugin_properties.plugin_loaded then
        song:insert_instrument_at(song.selected_instrument_index + 1)
        song.selected_instrument_index = song.selected_instrument_index + 1
        instrument = song.selected_instrument
    end

    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
    
    renoise.app():load_instrument(defaultInstrument)

    -- Update the instrument reference after loading the instrument
    instrument = song.selected_instrument

    -- Set the instrument name based on slot
    local instrument_slot_hex = string.format("%02X", song.selected_instrument_index - 1)
    instrument.name = instrument_slot_hex .. "_Drumkit"

    -- Limit the number of samples to load to 120
    local max_samples = 120
    local num_samples_to_load = math.min(#sample_files, max_samples)

    -- Create a table to store failed loads
    local failed_loads = {}
    
    -- Create ProcessSlicer instance and dialog
    local slicer = nil
    local dialog = nil
    local vb = nil

    -- Define the process function
    local function process_func()
        -- Load each sample as a new drum zone with specified properties
        for i = 1, num_samples_to_load do
            -- Update progress
            if dialog and dialog.visible then
                vb.views.progress_text.text = string.format("Loading sample %d/%d...", 
                    i, num_samples_to_load)
            end

            -- Get a random file from our working copy
            local random_index = math.random(1, #sample_files)
            local selected_file = sample_files[random_index]
            table.remove(sample_files, random_index)

            local file_name = selected_file:match("([^/\\]+)%.%w+$")

            if #instrument.samples < i then
                instrument:insert_sample_at(i)
            end

            local sample = instrument.samples[i]
            local sample_buffer = sample.sample_buffer

            -- Load the sample file into the sample buffer
            local success, error_message = pcall(function()
                return sample_buffer:load_from(selected_file)
            end)

            if success and error_message then
                sample.name = file_name
                sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
                sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
                sample.oneshot = preferences.pakettiLoaderOneshot.value
                sample.autofade = preferences.pakettiLoaderAutofade.value
                sample.autoseek = preferences.pakettiLoaderAutoseek.value
                sample.loop_mode = preferences.pakettiLoaderLoopMode.value
                sample.new_note_action = preferences.pakettiLoaderNNA.value
                sample.loop_release = preferences.pakettiLoaderLoopExit.value
                
                renoise.app():show_status(formatDigits(3,i) .. ": Loaded sample: " .. file_name)
            else
                -- Get file info for better error reporting
                local folder_path = selected_file:match("(.*[/\\])")
                local file_size = "unknown"
                local file_handle = io.open(selected_file, "rb")
                if file_handle then
                    file_size = string.format("%.2f MB", file_handle:seek("end") / 1024 / 1024)
                    file_handle:close()
                end
                
                -- Store failed loads with their index and error message
                table.insert(failed_loads, {
                    index = i,
                    file = selected_file,
                    folder = folder_path,
                    size = file_size,
                    error = tostring(error_message)
                })
            end

            -- Yield every few samples to keep UI responsive
            if i % 5 == 0 then
                if slicer:was_cancelled() then
                    return
                end
                coroutine.yield()
            end
        end

        if dialog and dialog.visible then
            dialog:close()
        end

        -- Show summary of failed loads if any
        if #failed_loads > 0 then
            local message = "Failed to load " .. #failed_loads .. " samples:\n"
            for _, fail in ipairs(failed_loads) do
                message = message .. string.format("\nIndex %d: %s\nFolder: %s\nSize: %s\nError: %s\n",
                    fail.index, fail.file:match("([^/\\]+)$"), fail.folder, fail.size, fail.error)
            end
            renoise.app():show_warning(message)
        end
    end

    -- Create and start the ProcessSlicer
    slicer = ProcessSlicer(process_func)
    dialog, vb = slicer:create_dialog("Loading Random Drumkit Samples")
    slicer:start()

    -- Return the loaded instrument
    return instrument
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120)  end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function(message) if message:is_trigger() then loadRandomDrumkitSamples(120)  end end}

-- Function to create a new instrument from the selected sample buffer range
function create_new_instrument_from_selection()
  local song=renoise.song()
  local selected_sample = song.selected_sample
  local selected_instrument_index = song.selected_instrument_index
  local selected_instrument = song.selected_instrument

if renoise.song().selected_sample ~= nil then 

  if not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No sample buffer data found in the selected sample.")
    print("Error: No sample buffer data found in the selected sample.")
    return
  end
  print("Sample buffer data is valid.")

  local sample_buffer = selected_sample.sample_buffer

  if sample_buffer.selection_range == nil or #sample_buffer.selection_range < 2 then
    renoise.app():show_error("No valid selection range found.")
    print("Error: No valid selection range found.")
    return
  end
  print("Selection range is valid.")

  local selection_start = sample_buffer.selection_range[1]
  local selection_end = sample_buffer.selection_range[2]
  local selection_length = selection_end - selection_start

  local bit_depth = sample_buffer.bit_depth
  local sample_rate = sample_buffer.sample_rate
  local num_channels = sample_buffer.number_of_channels

  print(string.format("Sample properties - Bit depth: %d, Sample rate: %d, Number of channels: %d", bit_depth, sample_rate, num_channels))

  -- Insert a new instrument right below the current instrument
  local new_instrument_index = selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  print("Inserted new instrument at index " .. new_instrument_index)

  -- Load the 12st_Pitchbend instrument into the new instrument slot
  
  pakettiPreferencesDefaultInstrumentLoader()

  
  print("Loaded Default XRNI instrument into the new instrument slot.")

  local new_instrument = song:instrument(new_instrument_index)
  new_instrument.name="Pitchbend Instrument"
  new_instrument.macros_visible = true
  new_instrument.sample_modulation_sets[1].name="Pitchbend"
  print("Configured new instrument properties.")

  -- Overwrite the "Placeholder sample" with the selected sample
  local placeholder_sample = new_instrument.samples[1]

  -- Create sample data and prepare to make changes
  placeholder_sample.sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, selection_length)
  local new_sample_buffer = placeholder_sample.sample_buffer
  new_sample_buffer:prepare_sample_data_changes()
  print("Created and prepared new sample data.")

  -- Copy the selection range to the new sample buffer
  for channel = 1, num_channels do
    for i = 1, selection_length do
      new_sample_buffer:set_sample_data(channel, i, sample_buffer:sample_data(channel, selection_start + i - 1))
    end
  end
  print("Copied selection range to the new sample buffer.")

  -- Finalize sample data changes
  new_sample_buffer:finalize_sample_data_changes()
  print("Finalized sample data changes.")

  -- Set the loop mode based on preferences.selectionNewInstrumentLoop
  local loop_mode_message = ""
  if preferences.selectionNewInstrumentLoop.value == 1 then
    placeholder_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    loop_mode_message = "No Loop"
    print("Set loop mode to 'Off'.")
  elseif preferences.selectionNewInstrumentLoop.value == 2 then
    placeholder_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    loop_mode_message = "Forward Loop"
    print("Set loop mode to 'Forward'.")
  elseif preferences.selectionNewInstrumentLoop.value == 3 then
    placeholder_sample.loop_mode = renoise.Sample.LOOP_MODE_REVERSE
    loop_mode_message = "Backward Loop"
    print("Set loop mode to 'Reverse'.")
  elseif preferences.selectionNewInstrumentLoop.value == 4 then
    placeholder_sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
    loop_mode_message = "PingPong Loop"
    print("Set loop mode to 'Ping-Pong'.")
  end

  -- Set the names for the new instrument and sample
  local instrument_slot_hex = string.format("%02X", new_instrument_index - 1)
  local original_sample_name = selected_sample.name
  new_instrument.name = string.format("%s_%s", instrument_slot_hex, original_sample_name)
  placeholder_sample.name = string.format("%s_%s", instrument_slot_hex, original_sample_name)
  print(string.format("Set names for the new instrument and sample: %s_%s", instrument_slot_hex, original_sample_name))

  -- Load the *Instr. Macros device and rename it
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
  if renoise.song().selected_track.type == 2 then renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") return else
  loadnative("Audio/Effects/Native/*Instr. Macros")
  end
  local macro_device = song.selected_track:device(2)
  macro_device.display_name = string.format("%s_%s", instrument_slot_hex, original_sample_name)
  song.selected_track.devices[2].is_maximized = false
  print("Loaded and configured *Instr. Macros device.")
end
  placeholder_sample.new_note_action = 1

  -- Select the new instrument and sample if preferences.selectionNewInstrumentSelect is true
  if preferences.selectionNewInstrumentSelect.value == true then
    song.selected_instrument_index = new_instrument_index
    song.selected_sample_index = 1
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[1].interpolation_mode = preferences.selectionNewInstrumentInterpolation.value
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[1].oversample_enabled = preferences.pakettiLoaderOverSampling.value
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[1].autofade = preferences.selectionNewInstrumentAutofade.value
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[1].autoseek = preferences.selectionNewInstrumentAutoseek.value
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[1].oneshot = preferences.pakettiLoaderOneshot.value
    print("Selected the new instrument and sample.")
  else
  local plusOne=renoise.song().selected_instrument_index+1
    song.selected_instrument_index = selected_instrument_index
    renoise.song().instruments[new_instrument_index].samples[1].interpolation_mode=preferences.selectionNewInstrumentInterpolation.value
    renoise.song().instruments[new_instrument_index].samples[1].oversample_enabled=preferences.pakettiLoaderOverSampling.value
    renoise.song().instruments[new_instrument_index].samples[1].autofade=preferences.selectionNewInstrumentAutofade.value
    renoise.song().instruments[new_instrument_index].samples[1].autoseek=preferences.selectionNewInstrumentAutoseek.value
    renoise.song().instruments[new_instrument_index].samples[1].oneshot=preferences.pakettiLoaderOneshot.value
    print("Stayed in the current sample editor view of the instrument you chopped out of.")
  end

  renoise.app():show_status("New instrument created from selection with " .. loop_mode_message .. ".")
else
renoise.app():show_status("There is no sample in the sample slot, doing nothing.")
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Create New Instrument & Loop from Selection",invoke=create_new_instrument_from_selection}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Create New Instrument & Loop from Selection",invoke=create_new_instrument_from_selection}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Create New Instrument & Loop from Selection",invoke=create_new_instrument_from_selection}
------
function G01()
  local s=renoise.song()
  local currTrak=s.selected_track_index
  local currPatt=s.selected_pattern_index
  local rightinstrument=nil
  local rightinstrument=renoise.song().selected_instrument_index-1

  if preferences._0G01_Loader.value then
    local new_track_index = currTrak + 1
    s:insert_track_at(new_track_index)
    s.selected_track_index = new_track_index
    currTrak = new_track_index
    local line=s.patterns[currPatt].tracks[currTrak].lines[1]
    line.note_columns[1].note_string="C-4"
    line.note_columns[1].instrument_value=rightinstrument
    line.effect_columns[1].number_string="0G"
    line.effect_columns[1].amount_string="01" 
  end
end
-------------
function pitchBendMultipleSampleLoader(normalize)
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read({"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, "Paketti PitchBend Multiple Sample Loader")

  if #selected_sample_filenames > 0 then
    rprint(selected_sample_filenames)
    for index, filename in ipairs(selected_sample_filenames) do
      local next_instrument = renoise.song().selected_instrument_index + 1
      renoise.song():insert_instrument_at(next_instrument)
      renoise.song().selected_instrument_index = next_instrument

      pakettiPreferencesDefaultInstrumentLoader()

      local selected_instrument = renoise.song().selected_instrument
      selected_instrument.name = "Pitchbend Instrument"
      selected_instrument.macros_visible = true
      selected_instrument.sample_modulation_sets[1].name = "Pitchbend"

      if #selected_instrument.samples == 0 then
        selected_instrument:insert_sample_at(1)
      end
      renoise.song().selected_sample_index = 1

      local filename_only = filename:match("^.+[/\\](.+)$")
      local instrument_slot_hex = string.format("%02X", next_instrument - 1)

      if selected_instrument.samples[1].sample_buffer:load_from(filename) then
        renoise.app():show_status("Sample " .. filename_only .. " loaded successfully.")
        local current_sample = selected_instrument.samples[1]
        current_sample.name = string.format("%s_%s", instrument_slot_hex, filename_only)
        selected_instrument.name = string.format("%s_%s", instrument_slot_hex, filename_only)

        current_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        current_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        current_sample.autofade = preferences.pakettiLoaderAutofade.value
        current_sample.autoseek = preferences.pakettiLoaderAutoseek.value
        current_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        current_sample.oneshot = preferences.pakettiLoaderOneshot.value
        current_sample.new_note_action = preferences.pakettiLoaderNNA.value
        current_sample.loop_release = preferences.pakettiLoaderLoopExit.value

        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
        G01()
if normalize then normalize_selected_sample() end

if preferences.pakettiLoaderMoveSilenceToEnd.value ~= false then PakettiMoveSilence() end
if preferences.pakettiLoaderNormalizeSamples.value ~= false then normalize_selected_sample() end
if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
if renoise.song().selected_track.type == 2 then renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") return else
        loadnative("Audio/Effects/Native/*Instr. Macros") 
        local macro_device = renoise.song().selected_track:device(2)
        macro_device.display_name = string.format("%s_%s", instrument_slot_hex, filename_only)
        renoise.song().selected_track.devices[2].is_maximized = false
        end
      else
        renoise.app():show_status("Failed to load the sample " .. filename_only)
      end
    else end 
    end
  else
    renoise.app():show_status("No file selected.")
  end
end

renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti..:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:Paketti PitchBend Multiple Sample Loader (Normalize)",invoke=function() pitchBendMultipleSampleLoader(true) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti..:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Multiple Sample Loader (Normalize)",invoke=function() pitchBendMultipleSampleLoader(true) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti PitchBend Multiple Sample Loader",invoke=function(message) if message:is_trigger() then pitchBendMultipleSampleLoader() end end}
-----------
function noteOnToNoteOff(noteoffPitch)
  -- Ensure there are samples in the selected instrument
  if #renoise.song().instruments[renoise.song().selected_instrument_index].samples == 0 then
    return
  end

  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if there are slice markers in any sample
  for _, sample in ipairs(instrument.samples) do
    if #sample.slice_markers > 0 then
      renoise.app():show_status("Operation not performed: Instrument contains sliced samples.")
      return
    end
  end

  -- Clear the note-off layer
  for i = #instrument.samples, 1, -1 do
    if instrument.samples[i].sample_mapping.layer == 2 then
      instrument:delete_sample_at(i)
    end
  end

  -- Iterate over each sample in the note-on layer
  for i = 1, #instrument.samples do
    local note_on_sample = instrument.samples[i]

    -- Determine the mute group for the note-on sample
    local mute_group = note_on_sample.mute_group
    if mute_group == 0 then -- No mute group set
      mute_group = 15 -- Set to Group F (group index is 15)
      note_on_sample.mute_group = mute_group
    end

    -- Insert new sample at the end for the note-off layer
    local new_sample_index = #instrument.samples + 1
    instrument:insert_sample_at(new_sample_index)
    renoise.song().selected_sample_index = new_sample_index

    local note_off_sample = instrument.samples[new_sample_index]

    -- Copy properties from note-on sample to note-off sample
    note_off_sample:copy_from(note_on_sample)
    note_off_sample.sample_mapping.layer = 2 -- Set layer to note-off
    note_off_sample.mute_group = mute_group -- Ensure same mute group

    -- Transpose the note-off sample
    note_off_sample.transpose = noteoffPitch
    note_off_sample.name = note_on_sample.name
  end

  -- Reset selection to the first note-on sample
  renoise.song().selected_sample_index = 1
end

renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Copy Sample in Note-On to Note-Off Layer +24",invoke=function() noteOnToNoteOff(24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Copy Sample in Note-On to Note-Off Layer +12",invoke=function() noteOnToNoteOff(12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Copy Sample in Note-On to Note-Off Layer",invoke=function() noteOnToNoteOff(0) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Copy Sample in Note-On to Note-Off Layer -12",invoke=function() noteOnToNoteOff(-12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Copy Sample in Note-On to Note-Off Layer -24",invoke=function() noteOnToNoteOff(-24) end}

renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Copy Sample in Note-On to Note-Off Layer +24",invoke=function() noteOnToNoteOff(24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Copy Sample in Note-On to Note-Off Layer +12",invoke=function() noteOnToNoteOff(12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Copy Sample in Note-On to Note-Off Layer",invoke=function() noteOnToNoteOff(0) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Copy Sample in Note-On to Note-Off Layer -12",invoke=function() noteOnToNoteOff(-12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Copy Sample in Note-On to Note-Off Layer -24",invoke=function() noteOnToNoteOff(-24) end}

renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Copy Sample in Note-On to Note-Off Layer +24",invoke=function() noteOnToNoteOff(24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Copy Sample in Note-On to Note-Off Layer +12",invoke=function() noteOnToNoteOff(12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Copy Sample in Note-On to Note-Off Layer",invoke=function() noteOnToNoteOff(0) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Copy Sample in Note-On to Note-Off Layer -12",invoke=function() noteOnToNoteOff(-12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Copy Sample in Note-On to Note-Off Layer -24",invoke=function() noteOnToNoteOff(-24) end}
-----------------------------------------------------------------------------------------------------------
function addSampleSlot(amount)
for i=1,amount do
renoise.song().instruments[renoise.song().selected_instrument_index]:insert_sample_at(i)
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Add Sample Slot to Instrument",invoke=function() addSampleSlot(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Initialize..:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Instruments..:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}
-------------------------------------------------------------------------------------------------------------------------------
function oneshotcontinue()
  local s=renoise.song()
  local sli=s.selected_instrument_index
  local ssi=s.selected_sample_index

  if s.instruments[sli].samples[ssi].oneshot
then s.instruments[sli].samples[ssi].oneshot=false
     s.instruments[sli].samples[ssi].new_note_action=1
else s.instruments[sli].samples[ssi].oneshot=true
     s.instruments[sli].samples[ssi].new_note_action=3 end end

renoise.tool():add_keybinding{name="Global:Paketti:Set Sample to One-Shot + NNA Continue",invoke=function() oneshotcontinue() end}
----------------
function LoopState(number)
renoise.song().selected_sample.loop_mode=number
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Loop Mode to 1 Off",invoke=function() LoopState(1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Loop Mode to 2 Forward",invoke=function() LoopState(2) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Loop Mode to 3 Reverse",invoke=function() LoopState(3) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Loop Mode to 4 PingPong",invoke=function() LoopState(4) end}
------------------
function slicerough(changer)
local loopstyle = preferences.WipeSlices.SliceLoopMode.value 
  local G01CurrentState = preferences._0G01_Loader.value
    if preferences._0G01_Loader.value == true or preferences._0G01_Loader.value == false 
    then preferences._0G01_Loader.value = false
    end

manage_sample_count_observer(preferences._0G01_Loader.value)

    local s = renoise.song()
    local currInst = s.selected_instrument_index

    -- Check if the instrument has samples
    if #s.instruments[currInst].samples == 0 then
        renoise.app():show_status("No samples available in the selected instrument.")
        return
    end

    s.selected_sample_index = 1
    local currSamp = s.selected_sample_index
    
    local beatsync_lines={
      [2]=64,
      [4]=32,
      [8]=16,
      [16]=8,
      [32]=4,
      [64]=2,
      [128]=1}
local beatsynclines = nil
local dontsync = nil
if s.instruments[currInst].samples[1].beat_sync_enabled then
beatsynclines = s.instruments[currInst].samples[1].beat_sync_lines
else
  dontsync=true
  beatsynclines = 0
    -- Determine the appropriate beatsync lines from the table or use a default value
 --   renoise.app():show_status("Please set Beatsync Lines Value before Wipe&Slice, for accurate slicing.")
--   beatsynclines = beatsync_lines[changer] or 64
--return
end
    local currentTranspose = s.selected_sample.transpose

    -- Clear existing slice markers from the first sample
    for i = #s.instruments[currInst].samples[1].slice_markers, 1, -1 do
        s.instruments[currInst].samples[1]:delete_slice_marker(s.instruments[currInst].samples[1].slice_markers[i])
    end

    -- Insert new slice markers
    local tw = s.selected_sample.sample_buffer.number_of_frames / changer
    s.instruments[currInst].samples[currSamp]:insert_slice_marker(1)
    for i = 1, changer - 1 do
        s.instruments[currInst].samples[currSamp]:insert_slice_marker(tw * i)
    end

-- Apply settings to all samples created by the slicing
for i, sample in ipairs(s.instruments[currInst].samples) do
    sample.new_note_action = preferences.WipeSlices.WipeSlicesNNA.value
    sample.oneshot = preferences.WipeSlices.WipeSlicesOneShot.value
    sample.autoseek = preferences.WipeSlices.WipeSlicesAutoseek.value
    sample.mute_group = preferences.WipeSlices.WipeSlicesMuteGroup.value

    if dontsync then 
        sample.beat_sync_enabled = false
    else
        local beat_sync_mode = preferences.WipeSlices.WipeSlicesBeatSyncMode.value

        -- Validate the beat_sync_mode value
        if beat_sync_mode < 1 or beat_sync_mode > 3 then
            sample.beat_sync_enabled = false  -- Disable beat sync for invalid mode
        else
            sample.beat_sync_mode = beat_sync_mode

            -- Only set beat_sync_lines if beatsynclines is valid
            if beatsynclines / changer < 1 then 
                sample.beat_sync_lines = beatsynclines
            else 
                sample.beat_sync_lines = beatsynclines / changer
            end

            -- Enable beat sync for this sample since dontsync is false and mode is valid
            sample.beat_sync_enabled = true
        end
    end

    sample.loop_mode = preferences.WipeSlices.WipeSlicesLoopMode.value
    local instrument=renoise.song().selected_instrument

    if loopstyle == true then
      if i > 1 then  -- Skip original sample
          -- Get THIS sample's length
          local max_loop_start = sample.sample_buffer.number_of_frames
          -- Set loop point to middle of THIS sample
          local slice_middle = math.floor(max_loop_start / 2)
          sample.loop_start = slice_middle
      end
  end
    
    sample.loop_release = preferences.WipeSlices.WipeSlicesLoopRelease.value
    sample.transpose = currentTranspose
    sample.autofade = preferences.WipeSlices.WipeSlicesAutofade.value
    sample.interpolation_mode = 4
    sample.oversample_enabled = true
end


    -- Ensure beat sync is enabled for the original sample
--    s.instruments[currInst].samples[1].beat_sync_lines = 128

if dontsync ~= true then 
    s.instruments[currInst].samples[1].beat_sync_lines = beatsynclines
    s.instruments[currInst].samples[1].beat_sync_enabled = true
else end
    -- Show status with sample name and number of slices
    local sample_name = renoise.song().selected_instrument.samples[1].name
    local num_slices = #s.instruments[currInst].samples[currSamp].slice_markers
    renoise.app():show_status(sample_name .. " now has " .. num_slices .. " slices.")
    
preferences._0G01_Loader.value=G01CurrentState 
manage_sample_count_observer(preferences._0G01_Loader.value)
end

function wipeslices()
    -- Retrieve the currently selected instrument index
    local s = renoise.song()
    local currInst = s.selected_instrument_index

    -- Check if there is a valid instrument selected
    if currInst == nil or currInst == 0 then
        renoise.app():show_status("No instrument selected.")
        return
    end

    -- Check if there are any samples in the selected instrument
    if #s.instruments[currInst].samples == 0 then
        renoise.app():show_status("No samples available in the selected instrument.")
        return
    end

    -- Ensure we iterate over all samples in the selected instrument
    local instrument = s.instruments[currInst]
    for i = 1, #instrument.samples do
        local sample = instrument.samples[i]

        -- Check if the sample is valid
        if sample then
            local slice_markers = sample.slice_markers
            local number = #slice_markers

            -- Delete each slice marker if there are any
            if number > 0 then
                for j = number, 1, -1 do
                    sample:delete_slice_marker(slice_markers[j])
                end
            end

            -- Set loop mode to Off and disable beat sync for the sample
            sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
            sample.beat_sync_enabled = false
        end
    end

    -- Confirm slices have been wiped
    renoise.app():show_status(instrument.name .. " now has 0 slices.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_keybinding{name="Global:Paketti:Wipe Slices",invoke=function() wipeslices() end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Wipe&Slice..:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Wipe&Slice..:Wipe Slices",invoke=function() wipeslices() end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Wipe&Slice..:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Wipe&Slice..:Wipe Slices",invoke=function() wipeslices() end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (002)",invoke=function() slicerough(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (004)",invoke=function() slicerough(4) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (008)",invoke=function() slicerough(8) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (016)",invoke=function() slicerough(16) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (032)",invoke=function() slicerough(32) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (064)",invoke=function() slicerough(64) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (128)",invoke=function() slicerough(128) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Wipe&Slice..:Wipe&Slice (256)",invoke=function() slicerough(256) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Wipe&Slice..:Wipe Slices",invoke=function() wipeslices() end}

renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Beatsync/Slices..:Double Beatsync Line",invoke=function() doubleBeatSyncLines() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Beatsync/Slices..:Halve Beatsync Line",invoke=function() halveBeatSyncLines() end}
--------------
function DSPFXChain()
renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS end

renoise.tool():add_keybinding{name="Global:Paketti:Show DSP FX Chain",invoke=function() DSPFXChain() end}
---
function pakettiSaveSample(format)
if renoise.song().selected_sample == nil then return else

local filename = renoise.app():prompt_for_filename_to_write(format, "Paketti Save Selected Sample in ." .. format .. " Format")
if filename == "" then return else 
renoise.song().selected_sample.sample_buffer:save_as(filename, format)
renoise.app():show_status("Saved sample as " .. format .. " in " .. filename)

end 
end
end
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Save Selected Sample .WAV",invoke=function() pakettiSaveSample("WAV") end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Save Selected Sample .FLAC",invoke=function() pakettiSaveSample("FLAC") end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Save..:Paketti Save Selected Sample .WAV",invoke=function() pakettiSaveSample("WAV") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Save..:Paketti Save Selected Sample .FLAC",invoke=function() pakettiSaveSample("FLAC") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Save..:Paketti Save Selected Sample Range .WAV",invoke=function() pakettiSaveSampleRange("WAV") end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Save..:Paketti Save Selected Sample Range .FLAC",invoke=function() pakettiSaveSampleRange("FLAC") end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Save Selected Sample .WAV",invoke=function(message) if message:is_trigger() then pakettiSaveSample("WAV") end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Save Selected Sample .FLAC",invoke=function(message) if message:is_trigger() then pakettiSaveSample("FLAC") end end}
------------
-- Define global variables to store the temporary filename and names
tmpvariable=nil
instrument_name=nil
sample_name=nil

-- Function to wipe the song while retaining the current sample
function WipeRetain()
  local s=renoise.song()
  local selected_sample=s.selected_sample
  local selected_instrument=s.selected_instrument
  if selected_sample and selected_instrument and #selected_instrument.samples>0 then
    local sample_buffer=selected_sample.sample_buffer
    if sample_buffer.has_sample_data then
      tmpvariable=os.tmpname()..".wav"
      instrument_name=selected_instrument.name
      local slice_markers=selected_sample.slice_markers

      -- Check if there are slices
      if slice_markers and #slice_markers>0 then
        -- Determine slice number and get the start and end positions
        local slice_number=selected_sample.slice_number
        local start_pos=slice_number>1 and slice_markers[slice_number-1] or 0
        local end_pos=slice_number<=#slice_markers and slice_markers[slice_number] or sample_buffer.number_of_frames

        -- Extract and save slice data
        sample_name=instrument_name.." - Slice"..slice_number
        local slice_buffer=sample_buffer:create_sample_data(1,sample_buffer.sample_rate,end_pos-start_pos+1)
        sample_buffer:copy_to(slice_buffer,0,start_pos,end_pos-start_pos+1)
        slice_buffer:save_as(tmpvariable,"wav")
      else
        -- No slices, save the entire sample
        sample_name=selected_sample.name
        sample_buffer:save_as(tmpvariable,"wav")
      end

      -- Add notifier and create a new song
      if not renoise.tool().app_new_document_observable:has_notifier(WipeRetainFinish) then
        renoise.tool().app_new_document_observable:add_notifier(WipeRetainFinish)
      end
      renoise.app():new_song()
    else
      renoise.app():show_status("Instrument/Selection has no Sample data")
    end
  else
    renoise.app():show_status("Instrument/Selection has no Sample data")
  end
end

-- Function to finish the process of wiping the song and retaining the sample
function WipeRetainFinish()
  local s=renoise.song()
  pakettiPreferencesDefaultInstrumentLoader()
  
  local instrument=s.instruments[1]
  instrument.name=instrument_name
  
  local sample=instrument:insert_sample_at(1)
  sample.name=sample_name
  sample.sample_buffer:load_from(tmpvariable)
  
  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  os.remove(tmpvariable)
  renoise.tool().app_new_document_observable:remove_notifier(WipeRetainFinish)
end

renoise.tool():add_keybinding{name="Global:Paketti:Wipe Song Retain Sample",invoke=function() WipeRetain() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Wipe Song Retain Sample",invoke=function() WipeRetain() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Wipe Song Retain Sample",invoke=function() WipeRetain() end}
--------
-- TODO: Make one that renders the whole thing and then mutes all the tracks and 0G01


------
-- Define render state (initialized when starting to render)
render_context = {
    source_track = 0,
    target_track = 0,
    target_instrument = 0,
    temp_file_path = ""
}

-- Function to initiate rendering
function start_renderingLPB()
  local song=renoise.song()
  local render_priority = "high"
  local selected_track = song.selected_track

  -- Add DC Offset if enabled in preferences
  if preferences.RenderDCOffset.value then
      local has_dc_offset = false
      for _, device in ipairs(selected_track.devices) do
          if device.display_name == "Render DC Offset" then
              has_dc_offset = true
              break
          end
      end
      
      if not has_dc_offset then
          loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
          local dc_offset_device = selected_track.devices[#selected_track.devices]
          if dc_offset_device.display_name == "Render DC Offset" then
              dc_offset_device.parameters[2].value = 1
          end
      end
  end 

    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
            break
        end
    end

    -- Set up rendering options
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
        end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
    }

    -- Set render context
    render_context.source_track = renoise.song().selected_track_index
    render_context.target_track = render_context.source_track + 1
    render_context.target_instrument = renoise.song().selected_instrument_index + 1
    render_context.temp_file_path = os.tmpname() .. ".wav"

    -- Start rendering with the correct function call
    local success, error_message = renoise.song():render(render_options, render_context.temp_file_path, rendering_done_callbackLPB)
    if not success then
        print("Rendering failed: " .. error_message)
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(monitor_renderingLPB, 500)
    end
end

-- Callback function that gets called when rendering is complete
function rendering_done_callbackLPB()
  local song=renoise.song()
  local renderTrack = render_context.source_track

  -- Remove DC Offset if it was added (FIRST, before other operations)
  if preferences.RenderDCOffset.value then
      local original_track = song:track(renderTrack)
      local last_device = original_track.devices[#original_track.devices]
      if last_device.display_name == "Render DC Offset" then
          original_track:delete_device_at(#original_track.devices)
      end
  end


    local renderedTrack = render_context.target_track
    local renderedInstrument = render_context.target_instrument

    -- Remove the monitoring timer
    renoise.tool():remove_timer(monitor_renderingLPB)

    -- Un-Solo Selected Track
    song.tracks[renderTrack]:solo()

    -- Turn All Render Track Note Columns to "Off"
    for i = 1, song.tracks[renderTrack].max_note_columns do
        song.tracks[renderTrack]:set_column_is_muted(i, true)
    end

    -- Collapse Render Track
    song.tracks[renderTrack].collapsed = true
    -- Change Selected Track to Rendered Track
    renoise.song().selected_track_index = renoise.song().selected_track_index + 1
    pakettiPreferencesDefaultInstrumentLoader()
    -- Add *Instr. Macros to Rendered Track
    --song:insert_instrument_at(renderedInstrument)
    local new_instrument = song:instrument(renoise.song().selected_instrument_index)

    -- Load Sample into New Instrument Sample Buffer
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)

    -- Set the selected_instrument_index to the newly created instrument
    song.selected_instrument_index = renderedInstrument - 1

    -- Insert New Track Next to Render Track
    song:insert_track_at(renderedTrack)
    local renderName = song.tracks[renderTrack].name

local number=nil
local numbertwo=nil
local rs=renoise.song()
write_bpm()
clonePTN()
local nol=nil
      nol=renoise.song().selected_pattern.number_of_lines+renoise.song().selected_pattern.number_of_lines
      renoise.song().selected_pattern.number_of_lines=nol

number=renoise.song().transport.lpb*2
if number == 1 then number = 2 end
if number > 128 then number=128 
renoise.song().transport.lpb=number
  write_bpm()
  Deselect_All()
  MarkTrackMarkPattern()
  MarkTrackMarkPattern()
  ExpandSelection()
  Deselect_All()
  return end
renoise.song().transport.lpb=number
  write_bpm()
  Deselect_All()
  MarkTrackMarkPattern()
  MarkTrackMarkPattern()
  ExpandSelection()
  Deselect_All()

    song.selected_pattern.tracks[renderedTrack].lines[1].note_columns[1].note_string = "C-4"
    song.selected_pattern.tracks[renderedTrack].lines[1].note_columns[1].instrument_value = renoise.song().selected_instrument_index - 1
    --    song.selected_pattern.tracks[renderedTrack].lines[1].effect_columns[1].number_string = "0G"
    --    song.selected_pattern.tracks[renderedTrack].lines[1].effect_columns[1].amount_value = 01 
    -- Add Instr* Macros to selected Track
    if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
    loadnative("Audio/Effects/Native/*Instr. Macros")
    renoise.song().selected_track.devices[2].is_maximized = false
    end
    -- Rename Sample Slot to Render Track
    new_instrument.samples[1].name = renderName .. " (Rendered)"

    -- Select New Track
    print(renderedTrack .. " this was the track but is it really the track?")
    song.selected_track_index = renderedTrack

    -- Rename New Track using Render Track Name
    song.tracks[renderedTrack].name = renderName .. " (Rendered)"
    new_instrument.name = renderName .. " (Rendered)"
    new_instrument.samples[1].autofade = true
    --    new_instrument.samples[1].autoseek = true
if renoise.song().transport.edit_mode then
renoise.song().transport.edit_mode = false
renoise.song().transport.edit_mode = true
else
renoise.song().transport.edit_mode = true
renoise.song().transport.edit_mode = false
end
for i=1,#song.tracks do
  renoise.song().tracks[i].mute_state=1
end 

end

-- Function to monitor rendering progress
function monitor_renderingLPB()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Rendering in progress: " .. (progress * 100) .. "% complete")
    else
        -- Remove the monitoring timer once rendering is complete or if it wasn't started
        renoise.tool():remove_timer(monitor_renderingLPB)
        print("Rendering not in progress or already completed.")
    end
end

-- Function to handle rendering for a group track
function render_group_trackLPB()
    local song=renoise.song()
    local group_track_index = song.selected_track_index
    local group_track = song:track(group_track_index)
    local start_track_index = group_track_index + 1
    local end_track_index = start_track_index + group_track.visible_note_columns - 1

    for i = start_track_index, end_track_index do
        song:track(i):solo()
    end

    -- Set rendering options and start rendering
    start_renderingLPB()
end

function pakettiCleanRenderSelectionLPB()
    local song=renoise.song()
    local renderTrack = song.selected_track_index
    local renderedTrack = renderTrack + 1
    local renderedInstrument = song.selected_instrument_index + 1

    -- Print the initial selected_instrument_index
    print("Initial selected_instrument_index: " .. song.selected_instrument_index)

    -- Create New Instrument
    song:insert_instrument_at(renderedInstrument)

    -- Select New Instrument
    song.selected_instrument_index = renderedInstrument

    -- Print the selected_instrument_index after creating new instrument
    print("selected_instrument_index after creating new instrument: " .. song.selected_instrument_index)

    -- Check if the selected track is a group track
    if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
        -- Render the group track
        render_group_trackLPB()
    else
        -- Solo Selected Track
        song.tracks[renderTrack]:solo()

        -- Render Selected Track
        start_renderingLPB()
    end
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Pattern Editor..:Clean Render..:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Clean Render..:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Clean Render..:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Clean Render..:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Clean Render..:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Clean Render..:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
------
-- Function to adjust a slice marker based on MIDI input
function adjustSlice(slice_index, midivalue)
    local song=renoise.song()
    local sample = song.selected_sample

    -- Ensure there is a selected sample and enough slice markers
    if not sample or #sample.slice_markers < slice_index then
        return
    end

    local slice_markers = sample.slice_markers
    local min_pos, max_pos

    -- Calculate the bounds for the slice marker movement
    if slice_index == 1 then
        min_pos = 1
        max_pos = (slice_markers[slice_index + 1] or sample.sample_buffer.number_of_frames) - 1
    elseif slice_index == #slice_markers then
        min_pos = slice_markers[slice_index - 1] + 1
        max_pos = sample.sample_buffer.number_of_frames - 1
    else
        min_pos = slice_markers[slice_index - 1] + 1
        max_pos = slice_markers[slice_index + 1] - 1
    end

    -- Scale MIDI input (0-127) to the range between min_pos and max_pos
    local new_pos = min_pos + math.floor((max_pos - min_pos) * (midivalue / 127))

    -- Move the slice marker
    sample:move_slice_marker(slice_markers[slice_index], new_pos)
end

-- Create MIDI mappings for up to 16 slice markers
for i = 1, 32 do
    renoise.tool():add_midi_mapping{name="Paketti:Midi Change Slice " .. formatDigits(2,i),
        invoke=function(message) if message:is_abs_value() then adjustSlice(i, message.int_value) end end} end

renoise.tool():add_midi_mapping{name="Paketti:Midi Select Padded Slice (Next)",invoke=function(message) if message:is_trigger() then  selectNextSliceInOriginalSample() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Select Padded Slice (Previous)",invoke=function(message) if message:is_trigger() then  selectPreviousSliceInOriginalSample() end end}
-------------------
function selectNextSliceInOriginalSample()
  local instrument = renoise.song().selected_instrument
  
  local selected_sample_index = renoise.song().selected_sample_index
  if not instrument.samples[selected_sample_index] then
    renoise.app():show_status("No sample selected or invalid sample index.")
    return
  end

  local sample = instrument.samples[selected_sample_index]

  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data.")
    return
  end

  local sliceMarkers = sample.slice_markers
  local sampleLength = sample.sample_buffer.number_of_frames

  if #sliceMarkers < 2 or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Not enough slice markers or sample data is unavailable.")
    return
  end

  local currentSliceIndex = preferences.WipeSlices.sliceCounter.value
  local nextSliceIndex = currentSliceIndex + 1
  if nextSliceIndex > #sliceMarkers then
    nextSliceIndex = 1
  end

  local thisSlice = sliceMarkers[currentSliceIndex] or 0
  local nextSlice = sliceMarkers[nextSliceIndex] or sampleLength

  local thisSlicePadding = (currentSliceIndex == 1 and thisSlice < 1000) and thisSlice or math.max(thisSlice - 1000, 1)
  local nextSlicePadding = (nextSliceIndex == 1) and math.min(nextSlice + sampleLength, sampleLength) or math.min(nextSlice + 1354, sampleLength)

  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  sample.sample_buffer.display_range = {thisSlicePadding, nextSlicePadding}
  sample.sample_buffer.display_length = nextSlicePadding - thisSlicePadding

  renoise.app():show_status(string.format("Slice Info - Current index: %d, Next index: %d, Slice Start: %d, Slice End: %d", currentSliceIndex, nextSliceIndex, thisSlicePadding, nextSlicePadding))
  
  preferences.WipeSlices.sliceCounter.value = nextSliceIndex
end

function selectPreviousSliceInOriginalSample()
  local instrument = renoise.song().selected_instrument
  
  local selected_sample_index = renoise.song().selected_sample_index
  if not instrument.samples[selected_sample_index] then
    renoise.app():show_status("No sample selected or invalid sample index.")
    return
  end

  local sample = instrument.samples[selected_sample_index]

  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data.")
    return
  end

  local sliceMarkers = sample.slice_markers
  local sampleLength = sample.sample_buffer.number_of_frames
  
  if #sliceMarkers < 2 or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Not enough slice markers or sample data unavailable.")
    return
  end
  
  local currentSliceIndex = preferences.WipeSlices.sliceCounter.value
  local previousSliceIndex = currentSliceIndex - 1
  
  if previousSliceIndex < 1 then
    previousSliceIndex = #sliceMarkers  -- Wrap to the last slice
  end

  local previousSlice = sliceMarkers[previousSliceIndex] or 0
  local nextSliceIndex = previousSliceIndex == #sliceMarkers and 1 or previousSliceIndex + 1
  local nextSlice = sliceMarkers[nextSliceIndex] or sampleLength

  local previousSlicePadding = math.max(previousSlice - 1000, 1)
  local nextSlicePadding = math.min(nextSlice + 1354, sampleLength)

  if previousSliceIndex == #sliceMarkers and currentSliceIndex == 1 then
    nextSlicePadding = sampleLength
  end

  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  sample.sample_buffer.display_range = {previousSlicePadding, nextSlicePadding}
  sample.sample_buffer.display_length = nextSlicePadding - previousSlicePadding

  renoise.app():show_status(string.format("Slice Info - Previous index: %d, Current index: %d, Slice Start: %d, Slice End: %d", previousSliceIndex, nextSliceIndex, previousSlicePadding, nextSlicePadding))
  preferences.WipeSlices.sliceCounter.value = previousSliceIndex
end

function resetSliceCounter()
  preferences.WipeSlices.sliceCounter.value = 1
  renoise.app():show_status("Slice counter reset to 1. Will start from the first slice.")
  selectNextSliceInOriginalSample()
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select Padded Slice (Next)",invoke=selectNextSliceInOriginalSample}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select Padded Slice (Previous)",invoke=function() selectPreviousSliceInOriginalSample() end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Slice Counter",invoke=resetSliceCounter}

function selectPaddedSliceFromCurrentSlice()
  local instrument = renoise.song().selected_instrument

  local selected_sample_index = renoise.song().selected_sample_index
  if not instrument.samples[selected_sample_index] then
    renoise.app():show_status("No sample selected or invalid sample index.")
    return
  end

  local currentSliceIndex = selected_sample_index - 1
  if selected_sample_index ~= 1 then
    --print(string.format("Currently in slice index: %d", currentSliceIndex))
    renoise.song().selected_sample_index = 1
  else
    currentSliceIndex = preferences.WipeSlices.sliceCounter.value
  end

  local sample = instrument.samples[1]
  local sliceMarkers = sample.slice_markers
  local sampleLength = sample.sample_buffer.number_of_frames

  if #sliceMarkers < 2 then
    renoise.app():show_status("Not enough slice markers.")
    return
  end

  if currentSliceIndex > #sliceMarkers then
    currentSliceIndex = 1
  end

  local thisSlice = sliceMarkers[currentSliceIndex] or 0
  local nextSlice = sliceMarkers[currentSliceIndex + 1] or sampleLength

  local thisSlicePadding = math.max(thisSlice - 1354, 1)
  local nextSlicePadding = math.min(nextSlice + 1354, sampleLength)

  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  sample.sample_buffer.display_range = {thisSlicePadding, nextSlicePadding}
  sample.sample_buffer.display_length = nextSlicePadding - thisSlicePadding

  renoise.app():show_status(string.format("Slice Info - Current index: %d, Slice Start: %d, Slice End: %d", currentSliceIndex, thisSlicePadding, nextSlicePadding))
  preferences.sliceCounter.value = currentSliceIndex
end

-- Function to reset the slice counter
function resetSliceCounter()
  preferences.sliceCounter.value = 1
  renoise.app():show_status("Slice counter reset to 1. Will start from the first slice.")
  selectNextSliceInOriginalSample()
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select Padded Slice from Current Slice",invoke=selectPaddedSliceFromCurrentSlice}
-------------
local loop_modes = {
  renoise.Sample.LOOP_MODE_OFF,
  renoise.Sample.LOOP_MODE_FORWARD,
  renoise.Sample.LOOP_MODE_REVERSE,
  renoise.Sample.LOOP_MODE_PING_PONG
}

function Global_Paketti_cycle_loop_mode(forwards)
  local sample = renoise.song().selected_sample
  if not sample then 
    renoise.app():show_status("No sample selected.")
    return 
  end
  
  local current_mode = sample.loop_mode
  local current_index
  
  -- Find the current mode index
  for i, mode in ipairs(loop_modes) do
    if mode == current_mode then
      current_index = i
      break
    end
  end
  
  if forwards then current_index = current_index % #loop_modes + 1
  else current_index = (current_index - 2) % #loop_modes + 1 end 
  sample.loop_mode = loop_modes[current_index]
end

-- Function to cycle loop mode for all samples in an instrument
function Global_Paketti_cycle_loop_mode_all_samples(forwards)
  local instrument = renoise.song().selected_instrument
  if not instrument or #instrument.samples == 0 then 
    renoise.app():show_status("No samples in the selected instrument.")
    return 
  end
  
  for _, sample in ipairs(instrument.samples) do
    local current_mode = sample.loop_mode
    local current_index
    
    -- Find the current mode index
    for i, mode in ipairs(loop_modes) do
      if mode == current_mode then
        current_index = i
        break
      end
    end
    
    -- Determine the new mode index
    if forwards then
      current_index = current_index % #loop_modes + 1
    else
      current_index = (current_index - 2) % #loop_modes + 1
    end
    
    -- Set the new loop mode
    sample.loop_mode = loop_modes[current_index]
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Sample Loop Cycler (Forwards)",invoke=function() Global_Paketti_cycle_loop_mode(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Loop Cycler (Backwards)",invoke=function() Global_Paketti_cycle_loop_mode(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:All Samples Loop Cycler (Forwards)",invoke=function() Global_Paketti_cycle_loop_mode_all_samples(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:All Samples Loop Cycler (Backwards)",invoke=function() Global_Paketti_cycle_loop_mode_all_samples(false) end}
-- Function to reverse the sample buffer
function PakettiReverseSampleBuffer(sample_buffer)
  local num_frames = sample_buffer.number_of_frames
  local num_channels = sample_buffer.number_of_channels
  local half_frames = math.floor(num_frames / 2)

  -- In-place reversal, only swap up to the middle
  for frame = 1, half_frames do
    local opposite_frame = num_frames - frame + 1
    for channel = 1, num_channels do
      local temp = sample_buffer:sample_data(channel, frame)
      sample_buffer:set_sample_data(channel, frame, 
        sample_buffer:sample_data(channel, opposite_frame))
      sample_buffer:set_sample_data(channel, opposite_frame, temp)
    end
  end
end

function CopySampleSettings(from_sample, to_sample)
  to_sample.volume = from_sample.volume
  to_sample.panning = from_sample.panning
  to_sample.transpose = from_sample.transpose
  to_sample.fine_tune = from_sample.fine_tune
  to_sample.beat_sync_enabled = from_sample.beat_sync_enabled
  to_sample.beat_sync_lines = from_sample.beat_sync_lines
  to_sample.beat_sync_mode = from_sample.beat_sync_mode
  to_sample.oneshot = from_sample.oneshot
  to_sample.loop_release = from_sample.loop_release

  if from_sample.sample_buffer.has_sample_data and from_sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    to_sample.loop_mode = from_sample.loop_mode
    if from_sample.loop_start > 0 and from_sample.loop_end > from_sample.loop_start then
      to_sample.loop_start = from_sample.loop_start
      to_sample.loop_end = from_sample.loop_end
    end
  else
    to_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end

  to_sample.mute_group = from_sample.mute_group
  to_sample.new_note_action = from_sample.new_note_action
  to_sample.autoseek = from_sample.autoseek
  to_sample.autofade = from_sample.autofade
  to_sample.oversample_enabled = from_sample.oversample_enabled
  to_sample.interpolation_mode = from_sample.interpolation_mode
  to_sample.name = from_sample.name
end

function CopySliceSettings(from_sample, to_sample)
  to_sample.volume = from_sample.volume
  to_sample.panning = from_sample.panning
  to_sample.transpose = from_sample.transpose
  to_sample.fine_tune = from_sample.fine_tune
  to_sample.beat_sync_enabled = from_sample.beat_sync_enabled
  to_sample.beat_sync_lines = from_sample.beat_sync_lines
  to_sample.beat_sync_mode = from_sample.beat_sync_mode
  to_sample.oneshot = from_sample.oneshot
  to_sample.loop_release = from_sample.loop_release
  to_sample.loop_mode = from_sample.loop_mode
  to_sample.loop_start = from_sample.loop_start
  to_sample.loop_end = from_sample.loop_end
  to_sample.mute_group = from_sample.mute_group
  to_sample.new_note_action = from_sample.new_note_action
  to_sample.autoseek = from_sample.autoseek
  to_sample.autofade = from_sample.autofade
  to_sample.oversample_enabled = from_sample.oversample_enabled
  to_sample.interpolation_mode = from_sample.interpolation_mode
  to_sample.name = from_sample.name
end

function PakettiDuplicateAndReverseInstrument()
  local song=renoise.song()
  local current_index = song.selected_instrument_index
  local current_instrument = song.selected_instrument

  -- Check if the instrument has any samples
  if #current_instrument.samples == 0 then
    renoise.app():show_status("No sample in the Instrument, doing nothing.")
    return
  end

  song:insert_instrument_at(current_index + 1)
  
  song.selected_instrument_index = current_index + 1
  pakettiPreferencesDefaultInstrumentLoader()

  local new_instrument = song:instrument(current_index + 1)
  -- Remove the placeholder sample that comes with the default instrument
  new_instrument:delete_sample_at(1)
  local num_samples = #current_instrument.samples

  if num_samples == 1 then
    local sample = current_instrument.samples[1]
    local sample_buffer = sample.sample_buffer
    if #sample.slice_markers == 0 and sample_buffer.has_sample_data then
      local new_sample = new_instrument:insert_sample_at(1)
      new_sample:copy_from(sample)
      new_sample.sample_buffer:prepare_sample_data_changes()
      PakettiReverseSampleBuffer(new_sample.sample_buffer)
      new_sample.sample_buffer:finalize_sample_data_changes()
      CopySampleSettings(sample, new_sample)
    end
  elseif num_samples > 1 then
    local first_sample = current_instrument.samples[1]
    if #first_sample.slice_markers > 0 then
      local sample = current_instrument.samples[1]
      local sample_buffer = sample.sample_buffer
      if sample_buffer.has_sample_data then
        local new_sample = new_instrument:insert_sample_at(1)
        
        new_sample.sample_buffer:create_sample_data(sample_buffer.sample_rate, sample_buffer.bit_depth, sample_buffer.number_of_channels, sample_buffer.number_of_frames)
        for channel = 1, sample_buffer.number_of_channels do
          for frame = 1, sample_buffer.number_of_frames do
            new_sample.sample_buffer:set_sample_data(channel, frame, sample_buffer:sample_data(channel, frame))
          end
        end

        new_sample.sample_buffer:prepare_sample_data_changes()
        PakettiReverseSampleBuffer(new_sample.sample_buffer)
        new_sample.sample_buffer:finalize_sample_data_changes()
        new_sample.slice_markers = sample.slice_markers
        CopySampleSettings(sample, new_sample)
        
        for i, _ in ipairs(sample.slice_markers) do
          CopySliceSettings(current_instrument.samples[i + 1], new_instrument.samples[i + 1])
        end
      end
    else

      for sample_index, sample in ipairs(current_instrument.samples) do
        local sample_buffer = sample.sample_buffer
        if sample_buffer.has_sample_data then
          local new_sample = new_instrument:insert_sample_at(sample_index)
          new_sample:copy_from(sample)
          local new_sample_buffer = new_sample.sample_buffer
          new_sample_buffer:prepare_sample_data_changes()
          PakettiReverseSampleBuffer(new_sample_buffer)
          new_sample_buffer:finalize_sample_data_changes()
          CopySampleSettings(sample, new_sample)
        end
      end
    end
  end

  for i, sample in ipairs(current_instrument.samples) do
    new_instrument.samples[i].name = sample.name
  end

  song.selected_instrument_index = current_index + 1
  renoise.song().selected_instrument.name = renoise.song().instruments[current_index].name .. " (Reversed)"
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments..:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Instruments..:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate and Reverse Instrument [Trigger]",invoke=function(message) if message:is_trigger() then PakettiDuplicateAndReverseInstrument() end end}
-----
function pakettiSampleBufferHalfSelector(half)
  local song=renoise.song()
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  local sample = song.selected_sample
  if not sample then
    renoise.app():show_status("No sample selected.")
    return
  end

  local sample_buffer = sample.sample_buffer
  if not sample_buffer.has_sample_data then
    renoise.app():show_status("Sample slot exists but has no content.")
    return
  end

  local sample_length = sample_buffer.number_of_frames
  if sample_length <= 1 then
    renoise.app():show_status("Sample length is too short.")
    return
  end

  local halfway = math.floor(sample_length / 2)
  if half == 1 then
    sample_buffer.selection_start = 1
    sample_buffer.selection_end = halfway
    renoise.app():show_status("First half of sample selected.")
  elseif half == 2 then
    sample_buffer.selection_start = halfway
    sample_buffer.selection_end = sample_length - 1
    renoise.app():show_status("Second half of sample selected.")
  else
    renoise.app():show_status("Invalid half specified.")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select First Half of Sample Buffer",invoke=function()pakettiSampleBufferHalfSelector(1)end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select Second Half of Sample Buffer",invoke=function()pakettiSampleBufferHalfSelector(2)end}
-------
function pakettiSaveSampleRange(format)
  local song=renoise.song()
  local original_instrument_index = song.selected_instrument_index
  local selected_sample = song.selected_sample
  if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    return
  end
  
  local selection_start, selection_end = selected_sample.sample_buffer.selection_range[1], selected_sample.sample_buffer.selection_range[2]
  if selection_start == selection_end then
    renoise.app():show_status("No selection range is defined")
    return
  end

  local new_instrument = song:insert_instrument_at(#song.instruments + 1)
  local new_sample = new_instrument:insert_sample_at(1)

  local sample_buffer = selected_sample.sample_buffer
  new_sample.sample_buffer:create_sample_data(
    sample_buffer.sample_rate, 
    sample_buffer.bit_depth, 
    sample_buffer.number_of_channels, 
    selection_end - selection_start + 1
  )
  new_sample.sample_buffer:prepare_sample_data_changes()
  
  for c = 1, sample_buffer.number_of_channels do
    for f = selection_start, selection_end do
      new_sample.sample_buffer:set_sample_data(c, f - selection_start + 1, sample_buffer:sample_data(c, f))
    end
  end
  new_sample.sample_buffer:finalize_sample_data_changes()

  local filename = renoise.app():prompt_for_filename_to_write(format, "Paketti Save Selected Sample Range in ." .. format .. " Format")
  
  if filename == "" then
    song:delete_instrument_at(#song.instruments)
    song.selected_instrument_index = original_instrument_index
    renoise.app():show_status("Save operation cancelled")
    return
  end
  
  -- Save the sample and clean up
  new_sample.sample_buffer:save_as(filename, format)
  renoise.app():show_status("Saved sample range as ." .. format .. " in " .. filename)
  
  -- Clean up: delete the instrument and reselect original instrument
  song:delete_instrument_at(#song.instruments)
  song.selected_instrument_index = original_instrument_index
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Save Selected Sample Range .WAV",invoke=function() pakettiSaveSampleRange("wav") end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Save Selected Sample Range .FLAC",invoke=function() pakettiSaveSampleRange("flac") end}
renoise.tool():add_midi_mapping{name="Paketti:Save Selected Sample Range .WAV",invoke=function(message) if message:is_trigger() then pakettiSaveSampleRange("wav") end end}
renoise.tool():add_midi_mapping{name="Paketti:Save Selected Sample Range .FLAC",invoke=function(message) if message:is_trigger() then pakettiSaveSampleRange("flac") end end}
---
function pakettiMinimizeToLoopEnd()
  local song=renoise.song()
  local original_instrument_index = song.selected_instrument_index
  local selected_sample = song.selected_sample
  if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    return
  end

  local loop_end = selected_sample.loop_end
  local sample_buffer = selected_sample.sample_buffer
  
  if loop_end >= sample_buffer.number_of_frames then
    renoise.app():show_status("Nothing to minimize")
    return
  end

  local temp_file_path = os.tmpname() .. ".wav"
  local selection_start, selection_end = 1, loop_end

  local new_instrument = song:insert_instrument_at(#song.instruments + 1)
  local new_sample = new_instrument:insert_sample_at(1)

  new_sample.sample_buffer:create_sample_data(
    sample_buffer.sample_rate, 
    sample_buffer.bit_depth, 
    sample_buffer.number_of_channels, 
    selection_end - selection_start + 1
  )
  new_sample.sample_buffer:prepare_sample_data_changes()

  for c = 1, sample_buffer.number_of_channels do
    for f = selection_start, selection_end do
      new_sample.sample_buffer:set_sample_data(c, f - selection_start + 1, sample_buffer:sample_data(c, f))
    end
  end
  new_sample.sample_buffer:finalize_sample_data_changes()

  new_sample.sample_buffer:save_as(temp_file_path, "wav")
  selected_sample.sample_buffer:load_from(temp_file_path)
  song:delete_instrument_at(#song.instruments)
  song.selected_instrument_index = original_instrument_index
  
  os.remove(temp_file_path)
  renoise.app():show_status("Sample minimized to loop end.")
end

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Process..:FT2 Minimize Selected Sample",invoke=pakettiMinimizeToLoopEnd}
renoise.tool():add_keybinding{name="Global:Paketti:FT2 Minimize Selected Sample",invoke=pakettiMinimizeToLoopEnd}
--------
local previous_value = nil
local rotation_amount = 5  -- You can set this to any desired default value

-- Function to rotate sample buffer content based on knob movement
function rotate_sample_buffer(midi_message, rotation_amount)
if renoise.song().selected_sample.sample_buffer.number_of_frames > 64000 then
renoise.app():show_status("This sample is far too large to be rotated, would cause a significant performance hit and crash Renoise - aborting..")
return
end

  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    local value = midi_message.int_value
    local change = 0
    if previous_value then
      change = value - previous_value
    end
    previous_value = value

    -- No change detected, return
    if change == 0 then
      return
    end

    -- Determine the direction of rotation
    local direction = 0
    if change > 0 then
      direction = 1  -- Rotate forward
    elseif change < 0 then
      direction = -1 -- Rotate backward
    end

    -- Rotate the sample buffer
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + direction * rotation_amount - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()

    local status_direction = direction > 0 and "forward" or "backward"
    renoise.app():show_status("Sample buffer rotated " .. status_direction .. " by " .. rotation_amount .. " frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Left/Right Fine x[Knob]",invoke=function(midi_message) rotate_sample_buffer(midi_message, rotation_amount) end}
--
local coarse_rotation_amount = 1000  -- Set Coarse rotation amount to 1000
local previous_value_coarse = nil

-- Function to rotate sample buffer content based on coarse knob movement
function rotate_sample_buffer_coarse(midi_message, rotation_amount)

if renoise.song().selected_sample.sample_buffer.number_of_frames > 64000 then
renoise.app():show_status("This sample is far too large to be rotated, would cause a significant performance hit and crash Renoise - aborting..")
return
end
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    local value = midi_message.int_value
    local change = 0
    if previous_value_coarse then
      change = value - previous_value_coarse
    end
    previous_value_coarse = value

    -- No change detected, return
    if change == 0 then
      return
    end

    -- Determine the direction of rotation
    local direction = 0
    if change > 0 then
      direction = 1  -- Rotate forward
    elseif change < 0 then
      direction = -1 -- Rotate backward
    end

    -- Rotate the sample buffer
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + direction * rotation_amount - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()

    local status_direction = direction > 0 and "forward" or "backward"
    renoise.app():show_status("Sample buffer rotated " .. status_direction .. " by " .. rotation_amount .. " frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Left/Right Coarse x[Knob]",invoke=function(midi_message) rotate_sample_buffer_coarse(midi_message, coarse_rotation_amount) end}

-- Function to rotate sample buffer content forward or backward by a specified amount
function rotate_sample_buffer_fixed(rotation_amount)
if renoise.song().selected_sample.sample_buffer.number_of_frames > 64000 then
renoise.app():show_status("This sample is far too large to be rotated, would cause a significant performance hit and crash Renoise - aborted")
return
end

  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + rotation_amount - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()

    local status_direction = rotation_amount > 0 and "forward" or "backward"
    renoise.app():show_status("Sample buffer rotated " .. status_direction .. " by " .. math.abs(rotation_amount) .. " frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Right 10",invoke=function() rotate_sample_buffer_fixed(10) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Left 10",invoke=function() rotate_sample_buffer_fixed(-10) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Right 100",invoke=function() rotate_sample_buffer_fixed(100) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Left 100",invoke=function() rotate_sample_buffer_fixed(-100) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Right 1000",invoke=function() rotate_sample_buffer_fixed(1000) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Left 1000",invoke=function() rotate_sample_buffer_fixed(-1000) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Right 10000",invoke=function() rotate_sample_buffer_fixed(10000) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Left 10000",invoke=function() rotate_sample_buffer_fixed(-10000) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Right Coarse",invoke=function() rotate_sample_buffer_fixed(preferences.pakettiRotateSampleBufferCoarse.value) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Left Coarse",invoke=function() rotate_sample_buffer_fixed(-preferences.pakettiRotateSampleBufferCoarse.value) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Right Fine",invoke=function() rotate_sample_buffer_fixed(preferences.pakettiRotateSampleBufferFine.value) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Left Fine",invoke=function() rotate_sample_buffer_fixed(-preferences.pakettiRotateSampleBufferFine.value) end}
---------
function filterTypeRandom()

if renoise.song().selected_instrument ~= nil then
if renoise.song().selected_sample ~= nil then
if renoise.song().selected_instrument.sample_modulation_sets ~= nil then
local randomized=math.random(2, 22)
renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].filter_type=renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].available_filter_types[randomized]
end end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Randomize Selected Instrument Modulation Filter Type",invoke=function()
filterTypeRandom() end}
--------------
-- Define render state (initialized when starting to render)
render_context = {
    source_track = 0,
    target_track = 0,
    target_instrument = 0,
    temp_file_path = ""
}

-- Function to initiate rendering
function CleanRenderAndSaveStart(format)
    local render_priority = "high"
    local selected_track = renoise.song().selected_track

    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
                break
            end
        end

    -- Set up rendering options
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
        end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
    }

    -- Set render context
    render_context.source_track = renoise.song().selected_track_index
    render_context.target_track = render_context.source_track + 1
    render_context.target_instrument = renoise.song().selected_instrument_index + 1
    render_context.temp_file_path = os.tmpname() .. ".wav"

    -- Start rendering with the correct function call
    local success, error_message = renoise.song():render(render_options, render_context.temp_file_path, CleanRenderAndSaveDoneCallback)
    if not success then
        print("Rendering failed: " .. error_message)
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(CleanRenderAndSaveMonitor, 500)
        end
    end
    
-- Callback function that gets called when rendering is complete
function CleanRenderAndSaveDoneCallback()
    local song=renoise.song()
    local sourceTrackName = song.tracks[render_context.source_track].name

    -- Remove the monitoring timer
    renoise.tool():remove_timer(CleanRenderAndSaveMonitor)

    -- Un-solo the source track
    song.tracks[render_context.source_track].solo_state = false

    -- Create a new instrument below the currently selected instrument
    local renderedInstrument = song.selected_instrument_index + 1
    song:insert_instrument_at(renderedInstrument)

    -- Select the newly created instrument
    song.selected_instrument_index = renderedInstrument

    -- Ensure the new instrument has at least one sample slot
    local new_instrument = song:instrument(renderedInstrument)
    if #new_instrument.samples == 0 then
        new_instrument:insert_sample_at(1)
    end

    -- Load the rendered sample into the first Sample Buffer
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)

    -- Clean up the temporary file
    os.remove(render_context.temp_file_path)

    -- Ensure the correct sample is selected
    song.selected_sample_index = 1

    -- Name the new instrument and the sample inside it
    new_instrument.name = sourceTrackName .. " (Rendered)"
    new_instrument.samples[1].name = sourceTrackName .. " (Rendered)"

    -- Save the rendered sample using the specified format
    CleanRenderAndSaveSample(render_context.temp_file_path:match("%.%w+$"):sub(2)) -- Extract format from file extension
end

-- Function to monitor rendering progress
function CleanRenderAndSaveMonitor()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Rendering in progress: " .. (progress * 100) .. "% complete")
    else
        -- Remove the monitoring timer once rendering is complete or if it wasn't started
        renoise.tool():remove_timer(CleanRenderAndSaveMonitor)
        print("Rendering not in progress or already completed.")
    end
end

-- Function to handle rendering for a group track
function CleanRenderAndSaveGroupTrack(format)
    local song=renoise.song()
    local group_track_index = song.selected_track_index
    local group_track = song:track(group_track_index)
    local start_track_index = group_track_index + 1
    local end_track_index = start_track_index + group_track.visible_note_columns - 1

    for i = start_track_index, end_track_index do
        song:track(i):solo()
    end

    -- Set rendering options and start rendering
    CleanRenderAndSaveStart(format)
end

-- Function to clean render and save the selection
function CleanRenderAndSaveSelection(format)
    local song=renoise.song()
    local renderTrack = song.selected_track_index

    -- Check if the selected track is a group track
    if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
        -- Render the group track
        CleanRenderAndSaveGroupTrack(format)
    else
        -- Solo Selected Track
        song.tracks[renderTrack]:solo()

        -- Render Selected Track
        CleanRenderAndSaveStart(format)
    end
end

-- Function to save the rendered sample in the specified format
function CleanRenderAndSaveSample(format)
    if renoise.song().selected_sample == nil then return end

    local filename = renoise.app():prompt_for_filename_to_write(format, "CleanRenderAndSave: Save Selected Sample in ." .. format .. " Format")
    if filename == "" then return end

    renoise.song().selected_sample.sample_buffer:save_as(filename, format)
    renoise.app():show_status("Saved sample as " .. format .. " in " .. filename)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Clean Render..:Clean Render and Save Selected Track/Group as .WAV",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Clean Render..:Clean Render and Save Selected Track/Group as .FLAC",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Clean Render..:Clean Render and Save Selected Track/Group as .WAV",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Clean Render..:Clean Render and Save Selected Track/Group as .FLAC",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Clean Render..:Clean Render and Save Selected Track/Group as .WAV",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Clean Render..:Clean Render and Save Selected Track/Group as .FLAC",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
renoise.tool():add_keybinding{name="Global:Paketti:Clean Render&Save Selected Track/Group (.WAV)",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_keybinding{name="Global:Paketti:Clean Render&Save Selected Track/Group (.FLAC)",invoke=function() CleanRenderAndSaveSelection("FLAC") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Duplicate and Reverse Instrument",invoke=PakettiDuplicateAndReverseInstrument}
---------
function PakettiInjectDefaultXRNI()
  local instVol = renoise.song().selected_instrument.volume
  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local original_instrument = song.selected_instrument

  -- Store the original selected phrase index BEFORE we do anything
  local original_phrase_index = renoise.song().selected_phrase_index
  print(string.format("\nStoring original selected_phrase_index: %d", original_phrase_index))

  if not original_instrument or #original_instrument.samples == 0 then
    renoise.app():show_status("No instrument or samples selected.")
    return
  end

  local new_instrument_index = selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local new_instrument = song.selected_instrument

  pakettiPreferencesDefaultInstrumentLoader()
  new_instrument = renoise.song().selected_instrument

  -- Copy phrases from original instrument if any exist
  if #original_instrument.phrases > 0 then
    print(string.format("\nCopying %d phrases from original instrument", #original_instrument.phrases))
    for i = 1, #original_instrument.phrases do
      new_instrument:insert_phrase_at(i)
      new_instrument.phrases[i]:copy_from(original_instrument.phrases[i])
      print(string.format("Copied phrase %d: '%s' (%d lines)", 
        i, original_instrument.phrases[i].name, #original_instrument.phrases[i].lines))
    end
  end
  -- Copy the samples and their settings from the original instrument to the new instrument
  for i = 1, #original_instrument.samples do
    local from_sample = original_instrument.samples[i]
    
    -- Check if the sample has slice markers
    if #from_sample.slice_markers > 0 then
      local to_sample = new_instrument:sample(i)
      local from_buffer = from_sample.sample_buffer
      local to_sample_buffer = to_sample.sample_buffer
      
      to_sample_buffer:create_sample_data(
        from_buffer.sample_rate,
        from_buffer.bit_depth,
        from_buffer.number_of_channels,
        from_buffer.number_of_frames
      )
      
      to_sample_buffer:prepare_sample_data_changes()

      for channel = 1, from_buffer.number_of_channels do
        for frame = 1, from_buffer.number_of_frames do
          local sample_value = from_buffer:sample_data(channel, frame)
          to_sample_buffer:set_sample_data(channel, frame, sample_value)
        end
      end

      to_sample_buffer:finalize_sample_data_changes()

      -- Copy slice markers
      to_sample:clear_slice_markers()
      for _, slice_marker in ipairs(from_sample.slice_markers) do
        to_sample:insert_slice_marker(slice_marker)
      end

      print("Slices copied for sample #" .. i)
    else
      -- Copy sample properties for non-sliced samples
      new_instrument:insert_sample_at(i)
      local to_sample = new_instrument.samples[i]
      to_sample:copy_from(from_sample)
      to_sample.device_chain_index = 1 
      print("Sample properties copied from sample #" .. i .. " of instrument index " .. selected_instrument_index)
    end
  end

  new_instrument.name = original_instrument.name .. " (Pakettified)"
  print("New Instrument renamed to: " .. new_instrument.name)

  -- Apply modulation and filter settings if needed
  if preferences.pakettiPitchbendLoaderEnvelope.value then
    new_instrument.sample_modulation_sets[1].devices[2].is_active = true
  end

  if preferences.pakettiLoaderFilterType.value then
    new_instrument.sample_modulation_sets[1].filter_type = preferences.pakettiLoaderFilterType.value
  end

  -- At the end, before returning focus:
  renoise.song().selected_phrase_index = original_phrase_index
  print(string.format("Restored selected_phrase_index to: %d", renoise.song().selected_phrase_index))

  -- Return focus to the Instrument Sample Editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  new_instrument.sample_modulation_sets[1].name = "Pitchbend"
  new_instrument.volume = instVol
  -- Remove the placeholder sample from the last slot
  local num_samples = #new_instrument.samples
  if num_samples > 0 and new_instrument.samples[num_samples].name == "Placeholder sample" then
    new_instrument:delete_sample_at(num_samples)
    print("Removed placeholder sample from last slot")
  end  
end

renoise.tool():add_keybinding{name="Global:Paketti:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}
---------
function PakettiToggleMono()
  local sample = renoise.song().selected_sample
  if not sample then
    renoise.app():show_status("No sample selected")
    return
  end

  if sample.device_chain_index == 1 then
    local device_chain = renoise.song().selected_instrument.sample_device_chains[1]
    local mono_device = device_chain:device(2)  -- First device in chain
    
    if mono_device and mono_device.display_name == "Mono" then
      mono_device.is_active = not mono_device.is_active
      local status = mono_device.is_active and "enabled" or "disabled"
      renoise.app():show_status("Mono device " .. status)
    else
      renoise.app():show_status("Please Pakettify this Instrument")
    end
  else
    renoise.app():show_status("Please Pakettify this Instrument")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Toggle Mono Device",invoke=PakettiToggleMono}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Toggle Mono Device",invoke=function() PakettiToggleMono() end}
-------------------
function BeatSyncFromSelection()
  local song=renoise.song()

  if song.selection_in_pattern then
    local startLine=song.selection_in_pattern.start_line
    local endLine=song.selection_in_pattern.end_line

    -- Calculate how long the selection is
    local selectionLength=math.abs(endLine-startLine)+1

    -- Set beat sync lines based on the selection length
    song.selected_sample.beat_sync_lines=selectionLength
    song.selected_sample.beat_sync_enabled=true

    -- Provide feedback in the status bar
    renoise.app():show_status("Beat sync lines set to: "..selectionLength)
  else
    renoise.app():show_status("No pattern selection available.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Smart Beatsync from Selection",invoke=function()
BeatSyncFromSelection() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Smart Beatsync from Selection",invoke=function() BeatSyncFromSelection() end}
--
render_context = {
    source_track = 0,
    target_track = 0,
    target_instrument = 0,
    temp_file_path = "",
    original_pattern_size = 0}

-- Function to resize pattern if necessary
function PakettiSeamlessCheckAndResizePattern()
    local song=renoise.song()
    local pattern_index = song.selected_pattern_index
    local current_pattern = song:pattern(pattern_index)
    local current_pattern_size = current_pattern.number_of_lines

    -- Save the original pattern size
    render_context.original_pattern_size = current_pattern_size

    -- If pattern size is less than 257, double it up to a maximum of 512
    if current_pattern_size < 257 then
        -- Double the pattern size until it's no more than 512
        while current_pattern_size < 512 do
            current_pattern_size = current_pattern_size * 2
        end
        -- Set the pattern size to the new value
    -- Call pakettiResizeAndFill() based on the original size before resizing
    if render_context.original_pattern_size == 256 then pakettiResizeAndFill(512)
    elseif render_context.original_pattern_size == 128 then pakettiResizeAndFill(256)
    elseif render_context.original_pattern_size == 64 then pakettiResizeAndFill(128)
    elseif render_context.original_pattern_size == 32 then pakettiResizeAndFill(64)
    elseif render_context.original_pattern_size == 16 then pakettiResizeAndFill(32)
    end end end

function PakettiSeamlessRestorePatternSize()
    local song=renoise.song()
    local pattern_index = song.selected_pattern_index
    local current_pattern = song:pattern(pattern_index)
    current_pattern.number_of_lines = render_context.original_pattern_size
end

-- Function to initiate rendering
function PakettiSeamlessStartRendering()
  local song=renoise.song()
  local render_priority = "high"
  local selected_track = song.selected_track

  -- Add DC Offset if enabled in preferences
  if preferences.RenderDCOffset.value then
      local has_dc_offset = false
      for _, device in ipairs(selected_track.devices) do
          if device.display_name == "Render DC Offset" then
              has_dc_offset = true
              break
          end
      end
      
      if not has_dc_offset then
          loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
          local dc_offset_device = selected_track.devices[#selected_track.devices]
          if dc_offset_device.display_name == "Render DC Offset" then
              dc_offset_device.parameters[2].value = 1
          end
      end
  end

    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
            break
        end
    end

    -- Set up rendering options
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
        end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
    }

    -- Set render context
    render_context.source_track = renoise.song().selected_track_index
    render_context.target_instrument = renoise.song().selected_instrument_index + 1
    render_context.temp_file_path = os.tmpname() .. ".wav"

    -- Start rendering with the correct function call
    local success, error_message = renoise.song():render(render_options, render_context.temp_file_path, PakettiSeamlessRenderingDoneCallback)
    if not success then
        print("Rendering failed: " .. error_message)
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(PakettiSeamlessMonitorRendering, 500)
    end
end

-- Callback function that gets called when rendering is complete
function PakettiSeamlessRenderingDoneCallback()
  local song=renoise.song()
  local renderTrack = render_context.source_track

  -- Remove DC Offset if it was added (FIRST, before other operations)
  if preferences.RenderDCOffset.value then
      local original_track = song:track(renderTrack)
      local last_device = original_track.devices[#original_track.devices]
      if last_device.display_name == "Render DC Offset" then
          original_track:delete_device_at(#original_track.devices)
      end
  end

    local renderedInstrument = render_context.target_instrument

    -- Remove the monitoring timer
    renoise.tool():remove_timer(PakettiSeamlessMonitorRendering)

    -- Restore the original pattern size after rendering
    PakettiSeamlessRestorePatternSize()

    -- Use pakettiPreferencesDefaultInstrumentLoader before loading the sample
    pakettiPreferencesDefaultInstrumentLoader()

    -- Load rendered sample into the selected instrument
    local new_instrument = song:instrument(renoise.song().selected_instrument_index)
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)

    -- Set the selected_instrument_index to the newly created instrument
    song.selected_instrument_index = renderedInstrument - 1


    -- Switch to instrument sample editor's middle frame
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

    pakettiSampleBufferHalfSelector(1)

renoise.song().selected_sample.loop_start=renoise.song().selected_sample.sample_buffer.selection_end
renoise.song().selected_sample.loop_end=renoise.song().selected_sample.sample_buffer.number_of_frames
renoise.song().selected_sample.loop_mode=2
renoise.song().selected_sample.name = renoise.song().selected_track.name
renoise.song().selected_instrument.name = renoise.song().selected_track.name
    if renoise.song().transport.edit_mode then
        renoise.song().transport.edit_mode = false
        renoise.song().transport.edit_mode = true
    else
        renoise.song().transport.edit_mode = true
        renoise.song().transport.edit_mode = false
    end

    for i=1,#song.tracks do
      renoise.song().tracks[i].mute_state=1
  end     
end

function PakettiSeamlessMonitorRendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Rendering in progress: " .. (progress * 100) .. "% complete")
    else
        renoise.tool():remove_timer(PakettiSeamlessMonitorRendering)
        print("Rendering not in progress or already completed.")
    end
end

function PakettiSeamlessRenderGroupTrack()
    local song=renoise.song()
    local group_track_index = song.selected_track_index
    local group_track = song:track(group_track_index)
    local start_track_index = group_track_index + 1
    local end_track_index = start_track_index + group_track.visible_note_columns - 1

    for i = start_track_index, end_track_index do
        song:track(i):solo()
    end
    PakettiSeamlessStartRendering()
end

function PakettiSeamlessCleanRenderSelection()
    local song=renoise.song()
    local renderTrack = song.selected_track_index
    local renderedInstrument = song.selected_instrument_index + 1

    print("Initial selected_instrument_index: " .. song.selected_instrument_index)
    song:insert_instrument_at(renderedInstrument)
    song.selected_instrument_index = renderedInstrument
    print("selected_instrument_index after creating new instrument: " .. song.selected_instrument_index)
    PakettiSeamlessCheckAndResizePattern()
    if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
        PakettiSeamlessRenderGroupTrack()
    else
        PakettiSeamlessStartRendering()
    end
end

-- Menu and keybinding for rendering
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Clean Render..:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
--
function PakettiFlipSample(fraction)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    local rotation_amount = math.floor(frames * fraction)  -- Calculate the number of frames to rotate
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + rotation_amount - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()

    renoise.app():show_status("Sample flipped by fraction " .. fraction)
  else
    renoise.app():show_status("No sample data to flip.")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Flip Sample by 1/4",invoke=function() PakettiFlipSample(1/4) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Flip Sample by 1/2",invoke=function() PakettiFlipSample(1/2) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Flip Sample by 1/8",invoke=function() PakettiFlipSample(1/8) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Flip Sample by 1/16",invoke=function() PakettiFlipSample(1/16) end}

function PakettiEight120fy()
  local instrument = renoise.song().selected_instrument
  for _, sample in ipairs(instrument.samples) do
    sample.sample_mapping.base_note=48
    sample.sample_mapping.note_range={0,119}
  end
  renoise.app():show_status("Base notes set to C-4 and key mapping adjusted for all samples.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 Eight 120-fy Instrument",invoke=function() PakettiEight120fy() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Paketti Groovebox 8120 Eight 120-fy Instrument",invoke=function() PakettiEight120fy() end}
------------   
 local function select_loop_range_in_sample_editor()
  local song=renoise.song()
  local sample=song.selected_sample
  
  if not sample or not sample.sample_buffer then
    renoise.app():show_status("No Loop exists, doing nothing.")
    return
  end

  local buffer=sample.sample_buffer
  local loop_start, loop_end=sample.loop_start, sample.loop_end
  
  if not sample.loop_mode or loop_start <= 0 or loop_end <= 0 or loop_start >= loop_end then
    renoise.app():show_status("No Loop exists, doing nothing.")
    return
  end

  buffer.selection_start=loop_start
  buffer.selection_end=loop_end
  renoise.app():show_status("Loop range selected in sample editor.")
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select Loop Range",invoke=function()
select_loop_range_in_sample_editor() end}
----
function loadRandomSample(num_samples)
    -- Prompt the user to select a folder
    local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
    if not folder_path then
        renoise.app():show_status("No folder selected.")
        return nil
    end

    -- Get all valid audio files in the selected directory and subdirectories
    local wav_files = PakettiGetFilesInDirectory(folder_path)
    
    -- Check if there are enough files to choose from
    if #wav_files == 0 then
        renoise.app():show_status("No audio files found in the selected folder.")
        return nil
    end

    -- Load the specified number of samples into separate instruments
    for i = 1, num_samples do
        -- Select a random file from the list
        local random_index = math.random(1, #wav_files)
        local selected_file = wav_files[random_index]

        -- Extract the file name without the extension for naming
        local file_name = selected_file:match("([^/\\]+)%.%w+$")

        -- Insert a new instrument and set it as selected
        renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
        renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
        pakettiPreferencesDefaultInstrumentLoader()  -- Assuming this is a custom function you have defined

        local instrument = renoise.song().selected_instrument
        instrument:delete_sample_at(1)  -- Remove any default sample slot

        -- Load the selected file into the new instrument
        local sample = instrument:insert_sample_at(1)
        sample.sample_buffer:load_from(selected_file)

        -- Set both the sample name and instrument name to the file name
        sample.name = file_name
        instrument.name = file_name
        
        renoise.app():show_status("Loaded file into new instrument: " .. selected_file)
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Random Samples (32) from Path",invoke=function() loadRandomSample(32) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Random Samples (01) from Path",invoke=function() loadRandomSample(1) end}
----
local function loadRandomSamplesIntoSingleInstrument(num_samples)
    -- Prompt the user to select a folder
    local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
    if not folder_path then
        renoise.app():show_status("No folder selected.")
        return nil
    end

    -- Get all valid audio files in the selected directory and subdirectories
    local wav_files = PakettiGetFilesInDirectory(folder_path)
    
    -- Check if there are enough files to choose from
    if #wav_files == 0 then
        renoise.app():show_status("No audio files found in the selected folder.")
        return nil
    end

    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
        renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
    
    pakettiPreferencesDefaultInstrumentLoader()  

    -- Get the selected instrument to load all samples into
    local instrument = renoise.song().selected_instrument
    instrument:delete_sample_at(1)  -- Clear any default sample slot

    -- Load the specified number of samples into new slots within the same instrument
    for i = 1, num_samples do
        -- Select a random file from the list
        local random_index = math.random(1, #wav_files)
        local selected_file = wav_files[random_index]

        -- Extract the file name without the extension for naming
        local file_name = selected_file:match("([^/\\]+)%.%w+$")

        -- Insert a new sample slot and load the file
        local sample = instrument:insert_sample_at(#instrument.samples + 1)
        sample.sample_buffer:load_from(selected_file)

        -- Set the sample name to the file name
        sample.name = file_name
        
        renoise.app():show_status("Loaded file into sample slot: " .. selected_file)
    end
instrument.name = num_samples .. " Randomized Samples"
end

-- Shortcut usage example
renoise.tool():add_keybinding{name="Global:Paketti:Load Random Samples (12) into Single Instrument",invoke=function()
loadRandomSamplesIntoSingleInstrument(12)  -- Loads 12 random samples into the selected instrument
end}

renoise.tool():add_keybinding{name="Global:Paketti:Load Random Samples (04) into Single Instrument (XY)",invoke=function()
loadRandomSamplesIntoSingleInstrument(4)
for i=1,#renoise.song().selected_instrument.samples do
renoise.song().selected_instrument.samples[i].volume = 0
end
showXyPaddialog() end}

--------
    local dialog = nil

local function loadRandomSamplesIntoSingleInstrument(num_samples, folder_path)
    if not folder_path or folder_path == "" then
        renoise.app():show_status("Folder path is not defined. Please set a valid path.")
        return nil
    end
    
    -- Get all valid audio files in the specified directory
    local wav_files = PakettiGetFilesInDirectory(folder_path)
    
    -- Check if there are enough files to choose from
    if #wav_files == 0 then
        renoise.app():show_status("No audio files found in the selected folder.")
        return nil
    end

    -- Insert a new instrument and set it up
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1

    -- Run the Paketti default instrument setup function
    pakettiPreferencesDefaultInstrumentLoader()  -- Assuming this is a custom function you have defined

    -- Get the selected instrument to load all samples into
    local instrument = renoise.song().selected_instrument
    instrument:delete_sample_at(1)  -- Clear any default sample slot

    -- Load the specified number of samples into new slots within the same instrument
    for i = 1, num_samples do
        -- Select a random file from the list
        local random_index = math.random(1, #wav_files)
        local selected_file = wav_files[random_index]

        -- Extract the file name without the extension for naming
        local file_name = selected_file:match("([^/\\]+)%.%w+$")

        -- Insert a new sample slot and load the file
        local sample = instrument:insert_sample_at(#instrument.samples + 1)
        sample.sample_buffer:load_from(selected_file)

        -- Set the sample name to the file name
        sample.name = file_name
        
        renoise.app():show_status("Loaded file into sample slot: " .. selected_file)
    end
    renoise.song().selected_instrument.name = "12 Randomized Samples"
end

-- Function to load random samples into separate instruments
local function loadRandomSample(num_samples, folder_path)
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Folder path is not defined. Please set a valid path.")
    return nil
  end

  local wav_files = PakettiGetFilesInDirectory(folder_path)
  if #wav_files == 0 then
    renoise.app():show_status("No audio files found in the selected folder.")
    return nil
  end

  for i = 1, num_samples do
    local random_index = math.random(1, #wav_files)
    local selected_file = wav_files[random_index]
    local file_name = selected_file:match("([^/\\]+)%.%w+$")

    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1

    pakettiPreferencesDefaultInstrumentLoader() 

    local instrument = renoise.song().selected_instrument
    instrument:delete_sample_at(1)

    local sample = instrument:insert_sample_at(1)
    sample.sample_buffer:load_from(selected_file)
    sample.name = file_name
    instrument.name = file_name
    renoise.app():show_status("Loaded file into new instrument: " .. selected_file)
  end
end

-- Function to load random drumkit samples into one instrument
local function loadRandomDrumkitSamples(num_samples, folder_path)
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Folder path is not defined. Please set a valid path.")
    return nil
  end

  local sample_files = PakettiGetFilesInDirectory(folder_path)
  if #sample_files == 0 then
    renoise.app():show_status("No audio files found in the selected folder.")
    return nil
  end

  local song=renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples > 0 or instrument.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    instrument = song.selected_instrument
  end
  local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
  local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"

  renoise.app():load_instrument(defaultInstrument)

  instrument = song.selected_instrument
  instrument.name = string.format("%02X_Drumkit", song.selected_instrument_index - 1)

  local max_samples = 120
  local num_samples_to_load = math.min(#sample_files, max_samples)

  for i = 1, num_samples_to_load do
    local random_index = math.random(1, #sample_files)
    local selected_file = sample_files[random_index]
    table.remove(sample_files, random_index)

    local file_name = selected_file:match("([^/\\]+)%.%w+$")

    if #instrument.samples < i then
      instrument:insert_sample_at(i)
    end

    local sample = instrument.samples[i]
    if sample.sample_buffer:load_from(selected_file) then
      sample.name = file_name
    end
  end
end

-- Main dialog function
function pakettiUserDefinedSamplesDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local preferences = renoise.tool().preferences
  local folder_fields = {}

  local function PakettiUserDefinedSamplesSavePreferences()
    for i = 1, 10 do
      local field = folder_fields[i]
      local sanitized_path = sanitizeFolderPath(field.text)
      preferences["UserDefinedSampleFolders" .. string.format("%02d", i)].value = sanitized_path or field.text
    end
  end

  local rows = vb:column{}

  for i = 1, 10 do
    local index = string.format("%02d", i)
    local path = preferences["UserDefinedSampleFolders" .. index].value or ""
    local textfield = vb:textfield{ width=600, text = path }
    folder_fields[i] = textfield

    local browse_button = vb:button{
      text="Browse",
      notifier=function()
        local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
        if folder_path then
          local sanitized_path = sanitizeFolderPath(folder_path)
          if sanitized_path then
            textfield.text = sanitized_path
            print("-- Paketti Debug: Selected and validated folder path:", sanitized_path)
          else
            renoise.app():show_warning("The selected folder path appears to be invalid or inaccessible.")
          end
        end
      end
    }

    local button_row = vb:row{
      spacing=8,
      vb:text{ text="Folder " .. formatDigits(2,i) .. ":" },
      browse_button,
      textfield,
      vb:button{text="Open Path",notifier=function()
        local sanitized_path = sanitizeFolderPath(textfield.text)
        if sanitized_path then
          renoise.app():open_path(sanitized_path)
        else
          renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
        end
      end}
    }

    button_row:add_child(vb:button{text="Random Drumkit", notifier=function() 
      local sanitized_path = sanitizeFolderPath(textfield.text)
      if sanitized_path then
        loadRandomDrumkitSamples(120, sanitized_path) 
      else
        renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
      end
    end})

    button_row:add_child(vb:button{
      text="Random 12",
      notifier=function()
        local sanitized_path = sanitizeFolderPath(textfield.text)
        if sanitized_path then
          loadRandomSamplesIntoSingleInstrument(12, sanitized_path)
        else
          renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
        end
      end
    })

    button_row:add_child(vb:button{
      text="Random 32",
      notifier=function()
        local sanitized_path = sanitizeFolderPath(textfield.text)
        if sanitized_path then
          loadRandomSample(32, sanitized_path)
        else
          renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
        end
      end
    })

    rows:add_child(button_row)
  end

  rows:add_child(vb:button{
    text="Save & Close",
    notifier=function()
      PakettiUserDefinedSamplesSavePreferences()
      renoise.app():show_status("Sample folders saved successfully.")
      dialog:close()
      dialog = nil
    end
  })

  dialog = renoise.app():show_custom_dialog("Paketti User-Defined Sample Folders", rows, my_keyhandler_func)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Quick Sample Folders..:Paketti User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti..:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
renoise.tool():add_keybinding{name="Global:Paketti:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
-- Function to get folder path from preferences
function getFolderPath(folderNum)
  local preferences = renoise.tool().preferences
  return preferences["UserDefinedSampleFolders" .. string.format("%02d", folderNum)].value
end

-- Function to create actions for a specific folder
local function createFolderActions(folderNum)
  local folderPath = getFolderPath(folderNum)
  local folderName = string.format("Folder %02d", folderNum)
  
  -- Open Folder
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti..:Quick Sample Folders..:%s:Open Folder", folderName), invoke=function() 
    if folderPath and folderPath ~= "" then
      renoise.app():open_path(folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random Drumkit
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti..:Quick Sample Folders..:%s:Random Drumkit", folderName), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random Drumkit from " .. folderPath)
      loadRandomDrumkitSamples(120, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random 12
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti..:Quick Sample Folders..:%s:Random 12", folderName), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 12 samples from " .. folderPath)
      loadRandomSamplesIntoSingleInstrument(12, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random 32
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti..:Quick Sample Folders..:%s:Random 32", folderName), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 32 instruments from " .. folderPath)
      loadRandomSample(32, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  

  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Open Folder", folderNum), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():open_path(folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random Drumkit", folderNum), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random Drumkit from " .. folderPath)
      loadRandomDrumkitSamples(120, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random 12", folderNum), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 12 samples from " .. folderPath)
      loadRandomSamplesIntoSingleInstrument(12, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random 32", folderNum), invoke=function()
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 32 instruments from " .. folderPath)
      loadRandomSample(32, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
end

-- Create actions for all 10 folders
for i = 1, 10 do
  createFolderActions(i)
end
------


local function duplicate_sample_with_transpose(transpose_amount)
  local song=renoise.song()
  local instrument = song.selected_instrument
  local selected_sample_index = song.selected_sample_index

  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  if not selected_sample_index or selected_sample_index < 1 or selected_sample_index > #instrument.samples then
    renoise.app():show_status("No valid sample selected.")
    return
  end

  -- Get the selected sample
  local original_sample = instrument.samples[selected_sample_index]

  -- Create a new sample slot
  local new_sample_index = selected_sample_index + 1
  instrument:insert_sample_at(new_sample_index)
  local new_sample = instrument.samples[new_sample_index]

  -- Copy data from original sample to new sample
  new_sample:copy_from(original_sample)

  -- Set the transpose and rename the sample
  new_sample.transpose = original_sample.transpose + transpose_amount
  new_sample.name = original_sample.name .. " " .. (transpose_amount >= 0 and "+" or "") .. transpose_amount

  -- Confirm the duplication
  renoise.app():show_status("Sample duplicated and transposed by " .. transpose_amount .. ".")
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti..:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at -12 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(-12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at -24 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(-24) end end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at +12 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at +24 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(24) end end}
--------
-- Function to set overlap mode
function setOverlapMode(mode)
  local instrument=renoise.song().selected_instrument
  if instrument and mode>=0 and mode<=2 then
    instrument.sample_mapping_overlap_mode=mode
    renoise.app():show_status("Overlap Mode set to: "..mode)
  else
    renoise.app():show_status("Invalid instrument or mode")
  end
end

-- Function to cycle through overlap modes
function overlayModeCycle()
  local instrument=renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No selected instrument to cycle overlap mode")
    return
  end
  local current_mode=instrument.sample_mapping_overlap_mode or 0
  instrument.sample_mapping_overlap_mode=(current_mode+1)%3
  renoise.app():show_status("Overlap Mode set to: "..instrument.sample_mapping_overlap_mode)
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments..:Cycle Overlap Mode",invoke=overlayModeCycle}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Set Overlap Mode 0 (Play All)",invoke=function() setOverlapMode(0) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Set Overlap Mode 1 (Cycle)",invoke=function() setOverlapMode(1) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Set Overlap Mode 2 (Random)",invoke=function() setOverlapMode(2) end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti..:Cycle Overlap Mode",invoke=overlayModeCycle}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Set Overlap Mode 0 (Play All)",invoke=function() setOverlapMode(0) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Set Overlap Mode 1 (Cycle)",invoke=function() setOverlapMode(1) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Set Overlap Mode 2 (Random)",invoke=function() setOverlapMode(2) end}
renoise.tool():add_midi_mapping{name="Paketti:Cycle Overlap Mode",invoke=function(message) if message:is_trigger() then overlayModeCycle() end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Overlap Mode 0 (Play All)",invoke=function(message) if message:is_trigger() then setOverlapMode(0) end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Overlap Mode 1 (Cycle)",invoke=function(message) if message:is_trigger() then setOverlapMode(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Overlap Mode 2 (Random)",invoke=function(message) if message:is_trigger() then setOverlapMode(2) end end}
renoise.tool():add_keybinding{name="Global:Paketti:Cycle Overlap Mode",invoke=overlayModeCycle}
renoise.tool():add_keybinding{name="Global:Paketti:Set Overlap Mode 0 (Play All)",invoke=function() setOverlapMode(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Overlap Mode 1 (Cycle)",invoke=function() setOverlapMode(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Overlap Mode 2 (Random)",invoke=function() setOverlapMode(2) end}
-------
function DrumKitToOverlay(overlaymode)
for i=1,#renoise.song().selected_instrument.sample_mappings[1] do
renoise.song().selected_instrument.sample_mappings[1][i].note_range={0,119}
renoise.song().selected_instrument.sample_mappings[1][i].base_note=48
renoise.song().selected_instrument.sample_mappings[1][i].velocity_range = {0, 127}

end
renoise.song().selected_instrument.sample_mapping_overlap_mode=overlaymode
renoise.app():show_status("The instrument " .. renoise.song().selected_instrument.name .. " has been formatted to Overlap Random.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Drumkit to Overlap Random",invoke=function() DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Set Drumkit to Overlap Random",invoke=function() DrumKitToOverlay(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Drumkit with Overlap Random",invoke=function() pitchBendDrumkitLoader()
DrumKitToOverlay(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Drumkit with Overlap Cycle",invoke=function() pitchBendDrumkitLoader()
DrumKitToOverlay(1) end}
-------
---------------
function PakettiDuplicateInstrumentSamplesWithTranspose(transpose_amount)
  local song=renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in instrument.")
    return
  end

  -- Check ALL samples for slice markers
  for _, sample in ipairs(instrument.samples) do
    if #sample.slice_markers > 0 then
      renoise.app():show_status("Cannot duplicate: Instrument contains sliced samples.")
      return
    end
  end

  -- Find original samples (those without "PakettiProcessed" in name)
  local original_samples = {}
  for i, sample in ipairs(instrument.samples) do
    if not sample.name:match("PakettiProcessed[%+%-]%d+") then
      table.insert(original_samples, {index = i, sample = sample})
    end
  end

  if #original_samples == 0 then
    renoise.app():show_status("No original samples found to duplicate.")
    return
  end

  -- Count existing processed sets and find original samples
  local processed_sets = 0
  local seen_transposes = {}
  for i, sample in ipairs(instrument.samples) do
    if sample.name:match("PakettiProcessed([%+%-]%d+)") then
      local transpose = sample.name:match("PakettiProcessed([%+%-]%d+)")
      if not seen_transposes[transpose] then
        seen_transposes[transpose] = true
        processed_sets = processed_sets + 1
      end
    end
  end

  -- Calculate volume reduction (gradual curve to -9dB at 6 sets)
  local new_total_sets = processed_sets + 1
  local max_sets = 6
  local max_reduction = -9
  local db_reduction = (max_reduction * math.min(new_total_sets, max_sets)) / max_sets
  -- Convert from dB to linear scale for the new volume
  local new_volume = math.pow(10, db_reduction/20)
  instrument.volume = new_volume

  -- Store original mappings
  local original_mappings = {}
  for _, sample_data in ipairs(original_samples) do
    local sample = sample_data.sample
    original_mappings[sample_data.index] = {
      base_note = sample.sample_mapping.base_note,
      note_range = sample.sample_mapping.note_range,
      velocity_range = sample.sample_mapping.velocity_range
    }
  end

  -- First, create all new sample slots and store the info we need
  local new_samples = {}
  for _, sample_data in ipairs(original_samples) do
    local new_sample = instrument:insert_sample_at(#instrument.samples + 1)
    -- Set volume to absolute zero before doing anything else
    new_sample.volume = 0
    
    table.insert(new_samples, {
      sample = new_sample,
      original = sample_data.sample,
      target_volume = sample_data.sample.volume,
      mapping = original_mappings[sample_data.index]
    })
  end

  -- Now copy all samples while they're muted
  for _, sample_info in ipairs(new_samples) do
    local new_sample = sample_info.sample
    new_sample:copy_from(sample_info.original)
    new_sample.transpose = sample_info.original.transpose + transpose_amount
    
    new_sample.sample_mapping.base_note = sample_info.mapping.base_note
    new_sample.sample_mapping.note_range = sample_info.mapping.note_range
    new_sample.sample_mapping.velocity_range = sample_info.mapping.velocity_range
    
    new_sample.name = sample_info.original.name .. " PakettiProcessed" .. 
      (transpose_amount >= 0 and "+" or "") .. transpose_amount
  end

  -- Finally, after ALL copies are complete, restore volumes
  for _, sample_info in ipairs(new_samples) do
    sample_info.sample.volume = sample_info.target_volume
  end

  renoise.app():show_status(string.format("Duplicated %d samples with transpose %d", 
    #original_samples, transpose_amount))
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}

renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti..:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti..:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}

renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}

----


function add_backwards_effect_to_selection()
  local song=renoise.song()
  local selection = selection_in_pattern_pro()
  
  if not selection then
    renoise.app():show_status("No selection in pattern!")
    return
  end
  
  local pattern = song.selected_pattern
  local pattern_track = pattern.tracks
  local sel = song.selection_in_pattern
  
  -- First pass: check if all notes already have 0B00
  local all_notes_have_0B00 = true
  local any_notes_found = false
  
  for _, track_info in ipairs(selection) do
    local track_index = track_info.track_index
    local pattern_track_data = pattern_track[track_index]
    
    for line_index = sel.start_line, sel.end_line do
      local line = pattern_track_data:line(line_index)
      local has_valid_note = false
      local has_0B00 = false
      
      -- Check for valid notes
      for _, note_col_index in ipairs(track_info.note_columns) do
        local note_column = line:note_column(note_col_index)
        if note_column.note_value < 120 then
          has_valid_note = true
          any_notes_found = true
          break
        end
      end
      
      -- If there's a valid note, check for 0B00
      if has_valid_note then
        for _, fx_col_index in ipairs(track_info.effect_columns) do
          local fx_column = line:effect_column(fx_col_index)
          if fx_column.number_string == "0B" and fx_column.amount_string == "00" then
            has_0B00 = true
            break
          end
        end
        
        if not has_0B00 then
          all_notes_have_0B00 = false
        end
      end
    end
  end
  
  -- Second pass: add or remove 0B00 based on first pass
  if all_notes_have_0B00 and any_notes_found then
    -- Remove all 0B00s
    for _, track_info in ipairs(selection) do
      local track_index = track_info.track_index
      local pattern_track_data = pattern_track[track_index]
      
      for line_index = sel.start_line, sel.end_line do
        local line = pattern_track_data:line(line_index)
        local has_valid_note = false
        
        -- Check if this line has any valid notes
        for _, note_col_index in ipairs(track_info.note_columns) do
          local note_column = line:note_column(note_col_index)
          if note_column.note_value < 120 then
            has_valid_note = true
            break
          end
        end
        
        -- If we found a valid note, remove 0B00
        if has_valid_note then
          for _, fx_col_index in ipairs(track_info.effect_columns) do
            local fx_column = line:effect_column(fx_col_index)
            if fx_column.number_string == "0B" and fx_column.amount_string == "00" then
              fx_column.number_string = ""
              fx_column.amount_string = ""
            end
          end
        end
      end
    end
    renoise.app():show_status("Removed backwards effect (0B00) from notes")
  else
    -- Add 0B00 where missing
    for _, track_info in ipairs(selection) do
      local track_index = track_info.track_index
      local pattern_track_data = pattern_track[track_index]
      
      for line_index = sel.start_line, sel.end_line do
        local line = pattern_track_data:line(line_index)
        local has_valid_note = false
        local has_0B00 = false
        
        -- Check for valid notes
        for _, note_col_index in ipairs(track_info.note_columns) do
          local note_column = line:note_column(note_col_index)
          if note_column.note_value < 120 then
            has_valid_note = true
            break
          end
        end
        
        -- Check if already has 0B00
        if has_valid_note then
          for _, fx_col_index in ipairs(track_info.effect_columns) do
            local fx_column = line:effect_column(fx_col_index)
            if fx_column.number_string == "0B" and fx_column.amount_string == "00" then
              has_0B00 = true
              break
            end
          end
          
          -- Add 0B00 if missing and we have effect columns
          if not has_0B00 and #track_info.effect_columns > 0 then
            local fx_column = line:effect_column(track_info.effect_columns[1])
            fx_column.number_string = "0B"
            fx_column.amount_string = "00"
          end
        end
      end
    end
    renoise.app():show_status("Added backwards effect (0B00) to notes where missing")
  end
end

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Play Samples Backwards in Selection 0B00",invoke=add_backwards_effect_to_selection}
renoise.tool():add_keybinding{name="Global:Paketti:Play Samples Backwards in Selection 0B00",invoke=add_backwards_effect_to_selection}
---
function PakettiRandomIR(ir_path)
  local song=renoise.song()
  local track = song.selected_track
  local device = nil
  
  -- First try to find an existing Convolver in the track
  for _, dev in ipairs(track.devices) do
      if dev.name == "Convolver" then
          device = dev
          break
      end
  end
  
  -- If no Convolver found, create one and wait for it to initialize
  if not device then
      track:insert_device_at("Audio/Effects/Native/Convolver", #track.devices + 1)
      renoise.app():show_status("Added new Convolver to track")
      
      -- Now look for the Convolver device
      for _, dev in ipairs(track.devices) do
          if dev.name == "Convolver" then
              device = dev
              break
          end
      end
      
      if not device then
          renoise.app():show_error("Failed to create Convolver device")
          return
      end
  end

  -- Get all IR files from the path and its subdirectories
  local ir_files = PakettiGetFilesInDirectory(ir_path)
  
  if #ir_files == 0 then
      renoise.app():show_error("No IR files found in " .. ir_path .. " or its subdirectories")
      return
  end

  -- Select a random IR file
  local random_ir = ir_files[math.random(1, #ir_files)]
  local file_name = random_ir:match("([^/\\]+)%.%w+$")

  -- Create temporary instrument
  local temp_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(temp_instrument_index)
  local temp_instrument = song.instruments[temp_instrument_index]
  temp_instrument.name = "IR Loader Temp: " .. file_name
  local temp_sample = temp_instrument:insert_sample_at(1)
  temp_sample.name = "IR: " .. file_name
  
  -- Try to load the sample
  local success = pcall(function()
      temp_sample.sample_buffer:load_from(random_ir)
  end)

  if not success then
      print(string.format("Failed to load IR file into sample buffer: %s", random_ir))
      song:delete_instrument_at(temp_instrument_index)
      renoise.app():show_error("Failed to load IR file: " .. random_ir)
      return
  end

  -- Get the sample data
  local sample_buffer = temp_sample.sample_buffer
  if not sample_buffer.has_sample_data then
      print(string.format("No sample data in IR file: %s", random_ir))
      song:delete_instrument_at(temp_instrument_index)
      renoise.app():show_error("No sample data in IR file: " .. random_ir)
      return
  end

  -- Print sample info
  print(string.format("Loading IR - File: %s\nInstrument: %s\nSample: %s\nChannels: %d\nSample Rate: %d\nFrames: %d", 
      random_ir,
      temp_instrument.name,
      temp_sample.name,
      sample_buffer.number_of_channels,
      sample_buffer.sample_rate,
      sample_buffer.number_of_frames
  ))

  -- Get the sample data as base64
  local left_data = get_channel_data_as_b64(sample_buffer, 1)
  local right_data = sample_buffer.number_of_channels == 2 and get_channel_data_as_b64(sample_buffer, 2) or ""
  local sample_rate = sample_buffer.sample_rate
  local stereo = sample_buffer.number_of_channels == 2

  -- Check if this is a new/default convolver or an existing one
  local current_xml = device.active_preset_data
  local is_init = current_xml:match("<SampleName>(.-)</SampleName>") == "No impulse loaded"
  local is_default = current_xml:match("<ImpulseDataSampleRate>(%d+)</ImpulseDataSampleRate>") == "0"

  local updated_xml
  if is_init or is_default then
      updated_xml = full_update_convolver_preset_data(
          left_data,
          right_data,
          sample_rate,
          file_name,
          stereo,
          ir_path
      )
  else
      updated_xml = soft_update_convolver_preset_data(
          current_xml,
          left_data,
          right_data,
          sample_rate,
          file_name,
          stereo,
          ir_path
      )
  end

  -- Try to apply the XML
  local success, error_message = pcall(function()
      device.active_preset_data = updated_xml
  end)

  -- Clean up the temporary instrument
--  song:delete_instrument_at(temp_instrument_index)

  if success then
      renoise.app():show_status(string.format("Successfully loaded IR: %s", file_name))
      print(string.format("Successfully loaded IR file: %s", random_ir))
  else
      renoise.app():show_error(string.format("Failed to load IR: %s\nError: %s", file_name, error_message))
      print(string.format("Failed to load IR file: %s\nError: %s", random_ir, error_message))
  end
end



------
-- Function to save all samples to a user-selected folder
function saveAllSamplesToFolder()
  -- Prompt for save location
  local dialog_title = "Select Folder to Save All Samples"
  local folder_path = renoise.app():prompt_for_path(dialog_title)
  
  if folder_path == "" then
      renoise.app():show_status("No folder selected, operation cancelled")
      return
  end

  local s = renoise.song()
  local path = folder_path .. "/"
  local saved_samples_count = 0

  for i = 1, #s.instruments do
      local instrument = s.instruments[i]
      if instrument and #instrument.samples > 0 then
          for j = 1, #instrument.samples do
              local sample = instrument.samples[j].sample_buffer
              if sample.has_sample_data then
                  local file_name = instrument.name .. "_" .. j .. ".wav"
                  if sample.bit_depth == 32 then
                      sample:save_as(path .. file_name, "wav")
                  else
                      sample:save_as(path .. file_name, "wav")
                  end
                  saved_samples_count = saved_samples_count + 1
              end
          end
      end
  end

  renoise.app():show_status("Saved " .. saved_samples_count .. " samples to folder " .. path)
  -- Open the folder in system's file explorer
  local os_name = os.platform()
  if os_name == "WINDOWS" then
      os.execute('explorer "' .. folder_path .. '"')
  elseif os_name == "MACINTOSH" then 
      os.execute('open "' .. folder_path .. '"')
  else -- Linux/Unix systems
      os.execute('xdg-open "' .. folder_path .. '"')
  end
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments..:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
renoise.tool():add_menu_entry{name="--Main Menu:File:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}


-------
function showSampleSelectionInfo()
  local song=renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or no sample data")
    return
  end
  
  local buffer = sample.sample_buffer
  local selection = buffer.selection_range
  local start_frame = selection[1]
  local end_frame = selection[2]
  local frames_selected = end_frame - start_frame + 1
  
  -- Calculate milliseconds based on sample rate
  local ms_per_frame = 1000 / buffer.sample_rate
  local start_ms = start_frame * ms_per_frame
  local end_ms = end_frame * ms_per_frame
  local ms_selected = frames_selected * ms_per_frame
  
  renoise.app():show_status(string.format(
    "Selection: %d-%d frames (%d frames total) | %.2f-%.2f ms (%.2f ms total)", 
    start_frame, end_frame, frames_selected,
    start_ms, end_ms, ms_selected
  ))
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Show Selection Info",invoke = showSampleSelectionInfo}

-- Timer for updating the sample details
local sample_details_timer = nil

function isSampleEditorVisible()
  return renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

function startSampleDetailsTimer()
  -- First check if we already have this timer
  if not renoise.tool():has_timer(updateSampleSelectionInfo) then
    sample_details_timer = renoise.tool():add_timer(updateSampleSelectionInfo, 50)
  end
end

function stopSampleDetailsTimer()
  -- First check if the timer exists before trying to remove it
  if renoise.tool():has_timer(updateSampleSelectionInfo) then
    renoise.tool():remove_timer(updateSampleSelectionInfo)
    
    sample_details_timer = nil
  end
end

function updateSampleSelectionInfo()
  -- First check if sample editor is visible
  if not isSampleEditorVisible() then
    stopSampleDetailsTimer()
    return
  end

  local song=renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    return
  end
  
  local buffer = sample.sample_buffer
  local selection = buffer.selection_range
  local start_frame = selection[1]
  local end_frame = selection[2]
  local frames_selected = end_frame - start_frame + 1
  
  -- Calculate milliseconds based on sample rate
  local ms_per_frame = 1000 / buffer.sample_rate
  local start_ms = start_frame * ms_per_frame
  local end_ms = end_frame * ms_per_frame
  local ms_selected = frames_selected * ms_per_frame
  
  -- Calculate beats and divisions based on BPM
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local beats_per_ms = bpm / (60 * 1000) -- beats per millisecond
  local divisions_per_ms = beats_per_ms * lpb -- divisions per millisecond
  
  local start_beats = start_ms * beats_per_ms
  local end_beats = end_ms * beats_per_ms
  local beats_selected = ms_selected * beats_per_ms
  
  local start_divisions = start_ms * divisions_per_ms
  local end_divisions = end_ms * divisions_per_ms
  local divisions_selected = ms_selected * divisions_per_ms
  
  renoise.app():show_status(string.format(
    "Selection: %d-%d frames (%d frames total) | %.2f-%.2f ms (%.2f ms total) | %.2f-%.2f beats (%.2f total) | %.2f-%.2f divs (%.2f total)", 
    start_frame, end_frame, frames_selected,
    start_ms, end_ms, ms_selected,
    start_beats, end_beats, beats_selected,
    start_divisions, end_divisions, divisions_selected
  ))
end

-- Function to toggle the sample details display
function toggleSampleDetails()
  -- Check if sample editor is visible before allowing toggle
  if not isSampleEditorVisible() then
    renoise.app():show_status("Sample selection info only available in Sample Editor")
    return
  end

  preferences.pakettiShowSampleDetails = not preferences.pakettiShowSampleDetails
  preferences:save_as("preferences.xml")  -- Save after toggle
  
  if preferences.pakettiShowSampleDetails then
    startSampleDetailsTimer()
    renoise.app():show_status("Sample selection info display: ON")
  else
    stopSampleDetailsTimer()
    renoise.app():show_status("Sample selection info display: OFF")
  end
end

local was_in_sample_editor = false

renoise.app().window.active_middle_frame_observable:add_notifier(function()
  local now_in_sample_editor = isSampleEditorVisible()
  
  if was_in_sample_editor and not now_in_sample_editor then
    stopSampleDetailsTimer()
    preferences.pakettiShowSampleDetails = false
    preferences:save_as("preferences.xml")
  elseif now_in_sample_editor and preferences.pakettiShowSampleDetails then
    startSampleDetailsTimer()
  end
  
  was_in_sample_editor = now_in_sample_editor
end)

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Toggle Sample Selection Info",invoke = toggleSampleDetails}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti Toggle Sample Selection Info",invoke = toggleSampleDetails}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Toggle Sample Selection Info",invoke = toggleSampleDetails}
renoise.tool().app_release_document_observable:add_notifier(function() stopSampleDetailsTimer() end)

-- Initialize sample details display based on preference
function initializeSampleDetails()
  if preferences.pakettiShowSampleDetails and isSampleEditorVisible() then
    startSampleDetailsTimer()
  end
end

-- Add the initialization call
renoise.tool().app_new_document_observable:add_notifier(initializeSampleDetails)
renoise.tool().app_idle_observable:add_notifier(initializeSampleDetails)

----------
renoise.tool():add_midi_mapping{name="Paketti:Selected Phrase LPB (1-127) x[Knob]",
  invoke=function(midi_message)
    local song=renoise.song()
    if song and song.selected_phrase then
      -- Map MIDI value (0-127) to LPB range (1-127)
      local new_lpb = math.max(1, math.min(127, midi_message.int_value))
      song.selected_phrase.lpb = new_lpb
      renoise.app():show_status("Phrase LPB: " .. new_lpb)
    end
  end
}
renoise.tool():add_midi_mapping{name="Paketti:Selected Phrase LPB (1-64) x[Knob]",
  invoke=function(midi_message)
    local song=renoise.song()
    if song and song.selected_phrase then
      -- Map MIDI value (0-127) to LPB range (1-127)
      local new_lpb = math.max(1, math.min(64, midi_message.int_value))
      song.selected_phrase.lpb = new_lpb
      renoise.app():show_status("Phrase LPB: " .. new_lpb)
    end
  end
}
renoise.tool():add_midi_mapping{name="Paketti:Selected Phrase LPB (Powers of 2) x[Knob]",
  invoke=function(midi_message)
    local song=renoise.song()
    if song and song.selected_phrase then
      -- Define the allowed LPB values
      local lpb_values = {1, 2, 4, 8, 16, 32}
      -- Divide MIDI range (0-127) into sections for each value
      local section_size = 127 / (#lpb_values - 1)
      -- Find the closest LPB value based on MIDI input
      local index = math.floor(midi_message.int_value / section_size + 0.5) + 1
      index = math.max(1, math.min(#lpb_values, index))
      local new_lpb = lpb_values[index]
      song.selected_phrase.lpb = new_lpb
      renoise.app():show_status("Phrase LPB: " .. new_lpb)
    end
  end
}
----------
function adjust_loop_range(multiply_by)
  local song=renoise.song()
  if not song then 
    debug_print("No song available")
    return 
  end

  local instrument = song.selected_instrument
  if not instrument then 
    debug_print("No instrument selected")
    return 
  end

  local sample = song.selected_sample
  if not sample then 
    debug_print("No sample selected")
    return 
  end

  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then 
    debug_print("No sample buffer or no sample data")
    return 
  end

  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then  -- Fixed this line
    local loop_start = sample.loop_start
    local loop_end = sample.loop_end
    local loop_length = loop_end - loop_start
    local total_frames = sample_buffer.number_of_frames
    
    -- For halving, check if loop is too small
    if multiply_by < 1 and loop_length <= 1 then
      debug_print("Loop length too small to halve")
      return
    end
    
    local new_loop_end = loop_start + math.floor(loop_length * multiply_by)
    -- Ensure we don't exceed sample bounds
    if new_loop_end > total_frames then
      new_loop_end = total_frames
    end
    
    sample.loop_end = new_loop_end
    local action = multiply_by < 1 and "Halved" or "Doubled"
    debug_print(action .. " loop range from " .. loop_start .. "-" .. loop_end .. " to " .. loop_start .. "-" .. new_loop_end)
  else
    debug_print("Loop mode is off")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Loop Halve",invoke=function() adjust_loop_range(0.5) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Loop Double",invoke=function() adjust_loop_range(2) end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Sample Loop Halve",invoke=function() adjust_loop_range(0.5) end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Sample Loop Double",invoke=function() adjust_loop_range(2) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Sample Loop Halve",invoke=function() adjust_loop_range(0.5) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Sample Loop Double",invoke=function() adjust_loop_range(2) end}

local function get_next_division(current_rows, going_up)
  local divisions = {1,2,3,4,5,6,7,8,12,16,24,32}
  
  -- Find the nearest division
  local closest_idx = 1
  local closest_diff = math.abs(divisions[1] - current_rows)
  
  for i = 1, #divisions do
    local diff = math.abs(divisions[i] - current_rows)
    if diff < closest_diff then
      closest_idx = i
      closest_diff = diff
    end
  end
  
  -- Move to next or previous division
  if going_up then
    closest_idx = math.min(closest_idx + 1, #divisions)
  else
    closest_idx = math.max(closest_idx - 1, 1)
  end
  
  return divisions[closest_idx]
end

function cycle_loop_division(going_up)
  local song=renoise.song()
  if not song then 
    debug_print("No song available")
    return 
  end

  local instrument = song.selected_instrument
  if not instrument then 
    debug_print("No instrument selected")
    return 
  end

  local sample = song.selected_sample
  if not sample then 
    debug_print("No sample selected")
    return 
  end

  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then 
    debug_print("No sample buffer or no sample data")
    return 
  end

  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    local sample_rate = sample_buffer.sample_rate
    
    -- Calculate frames per row
    local frames_per_row = math.floor((60 / bpm / lpb) * sample_rate)
    
    -- Get current loop length
    local loop_start = sample.loop_start
    local loop_end = sample.loop_end
    local current_length = loop_end - loop_start
    
    -- Calculate current rows and find next division
    local current_rows = math.floor(current_length / frames_per_row)
    local new_rows = get_next_division(current_rows, going_up)
    
    -- Calculate new loop end
    local new_length = frames_per_row * new_rows
    local new_loop_end = loop_start + new_length
    
    -- Ensure we don't exceed sample bounds
    local total_frames = sample_buffer.number_of_frames
    if new_loop_end > total_frames then
      new_loop_end = total_frames
      new_rows = math.floor((new_loop_end - loop_start) / frames_per_row)
      debug_print("Warning: Loop truncated to fit sample length")
    end
    
    sample.loop_end = new_loop_end
    debug_print(string.format(
      "Adjusted loop to %d rows\nBPM: %d, LPB: %d\nLoop range: %d-%d", 
      new_rows, bpm, lpb, loop_start, new_loop_end
    ))
  else
    debug_print("Loop mode is off")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Loop Length Next Division",invoke=function() cycle_loop_division(true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Loop Length Previous Division",invoke=function() cycle_loop_division(false) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Sample Loop Length Next Division",invoke=function() cycle_loop_division(true) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Sample Loop Length Previous Division",invoke=function() cycle_loop_division(false) end}


function snap_loop_to_rows()
  local song=renoise.song()
  if not song then 
    debug_print("No song available")
    return 
  end

  local instrument = song.selected_instrument
  if not instrument then 
    debug_print("No instrument selected")
    return 
  end

  local sample = song.selected_sample
  if not sample then 
    debug_print("No sample selected")
    return 
  end

  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then 
    debug_print("No sample buffer or no sample data")
    return 
  end

  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    local sample_rate = sample_buffer.sample_rate
    
    -- Calculate frames per row
    local frames_per_row = math.floor((60 / bpm / lpb) * sample_rate)
    
    -- Get current loop length
    local loop_start = sample.loop_start
    local loop_end = sample.loop_end
    local current_length = loop_end - loop_start
    
    -- Calculate nearest number of rows
    local rows = math.floor((current_length / frames_per_row) + 0.5)
    if rows < 1 then rows = 1 end
    
    -- Calculate new loop end
    local new_length = frames_per_row * rows
    local new_loop_end = loop_start + new_length
    
    -- Ensure we don't exceed sample bounds
    local total_frames = sample_buffer.number_of_frames
    if new_loop_end > total_frames then
      new_loop_end = total_frames
      rows = math.floor((new_loop_end - loop_start) / frames_per_row)
      debug_print("Warning: Loop truncated to fit sample length")
    end
    
    sample.loop_end = new_loop_end
    debug_print(string.format(
      "Snapped loop to nearest row division (%d rows)\nBPM: %d, LPB: %d\nLoop range: %d-%d", 
      rows, bpm, lpb, loop_start, new_loop_end
    ))
  else
    debug_print("Loop mode is off")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Snap Loop To Nearest Row",invoke=snap_loop_to_rows}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Snap Loop To Nearest Row",invoke=snap_loop_to_rows}

---------
function pakettiShowLargestSamplesDialog()
  local song=renoise.song()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  local used_samples = nil
  
  local function collect_samples()
    used_samples = findUsedSamples()
    local samples_list = {}
    
    for instr_idx, instrument in ipairs(song.instruments) do
      for sample_idx, sample in ipairs(instrument.samples) do
        if sample.sample_buffer and sample.sample_buffer.has_sample_data then
          local sample_size = sample.sample_buffer.number_of_frames * 
                             sample.sample_buffer.number_of_channels * 
                             (sample.sample_buffer.bit_depth / 8)
          
          table.insert(samples_list, {
            size = sample_size,
            formatted_size = formatFileSize(sample_size),
            instr_idx = instr_idx,
            sample_idx = sample_idx,
            instr_name = instrument.name,
            sample_name = sample.name,
            is_used = used_samples[instr_idx][sample_idx]
          })
        end
      end
    end
    
    table.sort(samples_list, function(a, b) return a.size > b.size end)
    return samples_list
  end

  local function pakettiShowLargestSamplesDialogDialog()
    local samples = collect_samples()
    
    if #samples == 0 then
      renoise.app():show_status("No samples found in the song, doing nothing.")
      return
    end

    local dialog_content = vb:column{
      margin=0,
      
      vb:row{
        margin=0,
        vb:button{
          text="Refresh",
          notifier=function()
            if dialog and dialog.visible then
              dialog:close()
            end
            pakettiShowLargestSamplesDialogDialog()
          end
        },
        vb:button{
          text="Delete Unused Samples",
          notifier=function()
            deleteUnusedSamples(true)  -- Skip confirmation since we're in the viewer
            if dialog and dialog.visible then
              dialog:close()
            end
            pakettiShowLargestSamplesDialogDialog()
          end
        },
          vb:text{
          text="Bold items are unused and can be safely deleted",
          font = "italic"
        }
      },      
      vb:row{
        margin=0,
        vb:text{width=40, text="Action", font = "bold" },
        vb:text{width=70, text="Size", font = "bold" },
        vb:text{width=30, text="Slot", font = "bold" },
        vb:text{width=150, text="Instrument", font = "bold" },
        vb:text{width=150, text="Sample", font = "bold" }
      }
    }
    
    for i = 1, math.min(40, #samples) do
      local sample = samples[i]
      dialog_content:add_child(vb:row{
    --    margin=0,
    --    spacing=0,  
        vb:button{
          width=40,
          text="Show",
          notifier=function()
            local song=renoise.song()
            song.selected_instrument_index = sample.instr_idx
            song.selected_sample_index = sample.sample_idx
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
          end
        },
        
        vb:text{
          width=70, 
          text = sample.formatted_size,
          font = sample.is_used and "normal" or "bold",
          style = sample.is_used and "normal" or "strong"
        },
        
        vb:text{
          width=30, 
          text = string.format("%03d", sample.instr_idx),
          font = sample.is_used and "normal" or "bold",
          style = sample.is_used and "normal" or "strong"
        },
        
        vb:text{
          width=150, 
          text = sample.instr_name,
          font = sample.is_used and "normal" or "bold",
          style = sample.is_used and "normal" or "strong"
        },
        
        vb:text{
          width=150, 
          text = sample.sample_name,
          font = sample.is_used and "normal" or "bold",
          style = sample.is_used and "normal" or "strong"
        }
      })
    end
    
    dialog = renoise.app():show_custom_dialog("Show Largest Samples (Top 40)",dialog_content, my_keyhandler_func)
  end
  
  pakettiShowLargestSamplesDialogDialog()
end
renoise.tool():add_menu_entry{name="--Main Menu:File:Show Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Show Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Show Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Show Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
---------
-- Function to duplicate track and instrument with all settings
function duplicateTrackAndInstrument()
  -- Get the current song and important indices
  local song=renoise.song()
  local track_index = song.selected_track_index
  local selected_track = song:track(track_index)
  
  -- First, duplicate the instrument
  local instrument_index = song.selected_instrument_index
  local original_instrument = song.instruments[instrument_index]
  
  -- Store external editor state and close it temporarily if needed
  local external_editor_open = false
  if original_instrument.plugin_properties and original_instrument.plugin_properties.plugin_device then
    external_editor_open = original_instrument.plugin_properties.plugin_device.external_editor_visible
    if external_editor_open then
      original_instrument.plugin_properties.plugin_device.external_editor_visible = false
    end
  end
  
  -- Insert and copy the instrument
  song:insert_instrument_at(instrument_index + 1)
  local new_instrument = song.instruments[instrument_index + 1]
  new_instrument:copy_from(original_instrument)
  
  -- Copy phrases if they exist
  if #original_instrument.phrases > 0 then
    for phrase_index = 1, #original_instrument.phrases do
      new_instrument:insert_phrase_at(phrase_index)
      new_instrument.phrases[phrase_index]:copy_from(original_instrument.phrases[phrase_index])
    end
  end
  
  -- Create new track
  song:insert_track_at(track_index + 1)
  local new_track = song:track(track_index + 1)
  
  -- Copy track settings
  new_track.visible_note_columns = selected_track.visible_note_columns
  new_track.visible_effect_columns = selected_track.visible_effect_columns
  new_track.volume_column_visible = selected_track.volume_column_visible
  new_track.panning_column_visible = selected_track.panning_column_visible
  new_track.delay_column_visible = selected_track.delay_column_visible
  new_track.sample_effects_column_visible = selected_track.sample_effects_column_visible
  new_track.collapsed = selected_track.collapsed
  
  -- Copy DSP devices and their settings
  for device_index = 2, #selected_track.devices do  -- Start from 2 to skip Track Volume device
    local old_device = selected_track.devices[device_index]
    local new_device = new_track:insert_device_at(old_device.device_path, device_index)
    
    -- Copy device parameters
    for param_index = 1, #old_device.parameters do
      new_device.parameters[param_index].value = old_device.parameters[param_index].value
    end
    
    -- Copy device display settings
    new_device.is_maximized = old_device.is_maximized
    
    -- Handle Instrument Automation device specially
    if old_device.device_path:find("Instr. Automation") then
      local old_xml = old_device.active_preset_data
      local new_xml = old_xml:gsub("<instrument>(%d+)</instrument>", 
        function(instr_index)
          return string.format("<instrument>%d</instrument>", instrument_index)
        end)
      new_device.active_preset_data = new_xml
    end
  end
  
  -- Copy pattern data and update instrument references
  for pattern_index = 1, #song.patterns do
    local pattern = song:pattern(pattern_index)
    local source_track = pattern:track(track_index)
    local dest_track = pattern:track(track_index + 1)
    
    -- Copy all lines
    for line_index = 1, pattern.number_of_lines do
      dest_track:line(line_index):copy_from(source_track:line(line_index))
      
      -- Update instrument references in note columns
      for _, note_column in ipairs(dest_track:line(line_index).note_columns) do
        if note_column.instrument_value ~= 255 then  -- Skip empty instrument values
          note_column.instrument_value = instrument_index
        end
      end
    end
    
    -- Copy automation data
    for _, automation in ipairs(source_track.automation) do
      local new_automation = dest_track:create_automation(automation.dest_parameter)
      for _, point in ipairs(automation.points) do
        new_automation:add_point_at(point.time, point.value)
      end
    end
  end
  
  -- Select the new track and instrument
  song.selected_track_index = track_index + 1
  song.selected_instrument_index = instrument_index + 1
  
  -- Restore external editor state if needed
  if external_editor_open and new_instrument.plugin_properties and new_instrument.plugin_properties.plugin_device then
    new_instrument.plugin_properties.plugin_device.external_editor_visible = true
  end
  
  -- Show status message
  renoise.app():show_status("Track and instrument duplicated successfully")
end

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Duplicate Track and Instrument",invoke=duplicateTrackAndInstrument}

renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Track and Instrument",invoke=duplicateTrackAndInstrument}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Duplicate Track and Instrument",invoke=duplicateTrackAndInstrument}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Track and Instrument",invoke=duplicateTrackAndInstrument}


-------
function fillEmptySampleSlots()
     -- Initialize random seed with current time and microseconds
     local seed = os.time() * 1000
     if os.clock then
         seed = seed + math.floor((os.clock() * 10000) % 1000)
     end
     math.randomseed(seed)
     -- Discard first few values as they can be less random
     math.random(); math.random(); math.random()
 
     local instrument = renoise.song().selected_instrument

     
  local instrument = renoise.song().selected_instrument
  if not instrument then return end
  
  local folder_path = renoise.app():prompt_for_path("Select Folder to Fill Empty Slots From")
  if not folder_path then return end

  local sample_files = PakettiGetFilesInDirectory(folder_path)
  if #sample_files == 0 then
      renoise.app():show_status("No audio files found in the selected folder.")
      return
  end

  -- Create table of used notes
  local used_notes = {}
  for _, mapping_group in ipairs(instrument.sample_mappings) do
      for _, mapping in ipairs(mapping_group) do
          if mapping.note_range then
              for note = mapping.note_range[1], mapping.note_range[2] do
                  used_notes[note] = true
              end
          end
      end
  end

  -- Fill empty notes from C0 (0) to B9 (119)
  for note = 0, 119 do
      if not used_notes[note] then
          if #sample_files == 0 then
              renoise.app():show_status("Ran out of sample files.")
              break
          end

          local sample_index = #instrument.samples + 1
          instrument:insert_sample_at(sample_index)
          local sample = instrument.samples[sample_index]

          local random_index = math.random(1, #sample_files)
          local selected_file = sample_files[random_index]
          table.remove(sample_files, random_index)

          local success = pcall(function()
              sample.sample_buffer:load_from(selected_file)
          end)

          if success then
            sample.name = selected_file:match("([^/\\]+)%.%w+$")
            
            -- Apply all preferences from the original loader
--[[            sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
            sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
            sample.oneshot = preferences.pakettiLoaderOneshot.value
            sample.autofade = preferences.pakettiLoaderAutofade.value
            sample.autoseek = preferences.pakettiLoaderAutoseek.value
            sample.loop_mode = preferences.pakettiLoaderLoopMode.value
            sample.new_note_action = preferences.pakettiLoaderNNA.value
            sample.loop_release = preferences.pakettiLoaderLoopExit.value
    ]]--        
            -- Set both note_range and base_note to the current note
            local mapping = instrument.sample_mappings[1][sample_index]
            mapping.note_range = {note, note}
            mapping.base_note = note
            
            local note_name = string.format("%s%d", string.char(65 + (note % 12)), math.floor(note / 12))
            renoise.app():show_status(string.format("Mapped %s: %s", note_name, sample.name))
        end end end end 

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments..:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti..:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}
renoise.tool():add_keybinding{name="Global:Paketti:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}

-- Function to sanitize and validate folder path
function sanitizeFolderPath(path)
  if not path then return nil end
  
  -- Normalize path separators
  local sanitized = path:gsub([[\]], [[/]])
  
  -- Remove any trailing slashes
  sanitized = sanitized:gsub("/*$", "")
  
  -- Check if the path exists
  if not os.rename(sanitized, sanitized) then
    print("-- Paketti Debug: Path does not exist:", sanitized)
    return nil
  end
  
  print("-- Paketti Debug: Sanitized path:", sanitized)
  return sanitized
end


-------
last_index=nil

function pakettiSelectRandomInstrument()
  local s=renoise.song()
  local pool={}
  for i=1,#s.instruments do
    local instr=s.instruments[i]
    local has_sample=#instr.samples>0
    local has_plugin=instr.plugin_properties.plugin_loaded
    local has_midi=instr.midi_output_properties.device_name~=""
    if has_sample or has_plugin or has_midi then
      table.insert(pool,i)
    end
  end
  if #pool==0 then
    renoise.app():show_status("Couldn't find a single instrument.")
    return
  end
  local new_index
  if #pool==1 then
    new_index=pool[1]
  else
    repeat
      new_index=pool[math.random(#pool)]
    until new_index~=last_index
  end
  s.selected_instrument_index=new_index
  last_index=new_index
  renoise.app():show_status("Selected instrument #"..new_index)
end

renoise.tool():add_keybinding {name="Global:Paketti:Select Random Instrument (Sample,Plugin,MIDI)",invoke=function() pakettiSelectRandomInstrument() end}
renoise.tool():add_menu_entry {name="Instrument Box:Paketti..:Select Random Instrument (Sample,Plugin,MIDI)",invoke=function() pakettiSelectRandomInstrument() end}

-------


function double_slices()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    
    -- Check if there is a valid instrument selected
    if currInst == nil or currInst == 0 then
        renoise.app():show_status("No instrument selected.")
        return
    end
    
    -- Check if there are any samples in the selected instrument
    if #s.instruments[currInst].samples == 0 then
        renoise.app():show_status("No samples available in the selected instrument.")
        return
    end
    
    -- Get current slice count
    local current_slices = #s.instruments[currInst].samples[1].slice_markers
    
    -- If no slices, create 2 slices
    if current_slices == 0 then
        slicerough(2)
        return
    end
    
    -- Check if doubling would exceed the 255 slice limit
    if current_slices * 2 > 255 then
        renoise.app():show_status("Cannot double: would exceed maximum of 255 slices.")
        return
    end
    
    -- Double the slice count
    local new_slice_count = current_slices * 2
    slicerough(new_slice_count)
end

function halve_slices()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    
    -- Check if there is a valid instrument selected
    if currInst == nil or currInst == 0 then
        renoise.app():show_status("No instrument selected.")
        return
    end
    
    -- Check if there are any samples in the selected instrument
    if #s.instruments[currInst].samples == 0 then
        renoise.app():show_status("No samples available in the selected instrument.")
        return
    end
    
    -- Get current slice count
    local current_slices = #s.instruments[currInst].samples[1].slice_markers
    
    -- If only one slice, clear all slices
    if current_slices == 1 then
        wipeslices()
        return
    end
    
    -- If no slices, nothing to do
    if current_slices == 0 then
        renoise.app():show_status("No slices to halve.")
        return
    end
    
    -- Halve the slice count (round down to nearest integer)
    local new_slice_count = math.floor(current_slices / 2)
    slicerough(new_slice_count)
end

renoise.tool():add_keybinding{name="Global:Paketti:Double Slice Count",invoke=function() double_slices() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Slice Count",invoke=function() halve_slices() end}

function pakettiSlicesFromSelection()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    
    -- Check if there is a valid instrument selected
    if currInst == nil or currInst == 0 then
        renoise.app():show_status("No instrument selected.")
        return
    end
    
    -- Check if there are any samples in the selected instrument
    if #s.instruments[currInst].samples == 0 then
        renoise.app():show_status("No samples available in the selected instrument.")
        return
    end
    
    local sample = s.selected_sample
    if not sample then
        renoise.app():show_status("No sample selected.")
        return
    end
    
    -- Get selection range
    local sel = sample.sample_buffer.selection_range
    if not sel then
        renoise.app():show_status("Please make a selection in the sample first.")
        return
    end
    
    -- Calculate selection length
    local sel_length = sel[2] - sel[1]
    if sel_length <= 0 then
        renoise.app():show_status("Invalid selection range.")
        return
    end
    
    -- Clear existing slice markers
    for i = #sample.slice_markers, 1, -1 do
        sample:delete_slice_marker(sample.slice_markers[i])
    end
    
    -- Create slices until we reach the end of the buffer
    local total_frames = sample.sample_buffer.number_of_frames
    local slice_count = 0
    local current_pos = 1  -- Start from position 1
    
    -- Always add first slice at position 1
    sample:insert_slice_marker(current_pos)
    slice_count = slice_count + 1
    
    -- Keep adding slices until we reach the end or hit 255 limit
    while (current_pos + sel_length) < total_frames and slice_count < 255 do
        current_pos = current_pos + sel_length
        sample:insert_slice_marker(current_pos)
        slice_count = slice_count + 1
    end
    
    -- Show appropriate status message
    if slice_count == 255 then
        renoise.app():show_status(string.format("Created maximum 255 slices (sample not fully sliced)."))
    else
        renoise.app():show_status(string.format("Created %d slices using entire sample.", slice_count))
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Slice Count From Selection",invoke=function() pakettiSlicesFromSelection() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Slice Count From Selection",invoke=function() pakettiSlicesFromSelection() end}
