local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

-- Configuration for process yielding (in seconds)
local PROCESS_YIELD_INTERVAL = 1.5  -- Adjust this value to control how often the process yields

-- Frequency analysis functions (from PakettiRePitch.lua)
local function log2(x) return math.log(x)/math.log(2) end
local function midi2freq(x) return 440*(2^((x-69)/12)) end
local function freq2midi(x) return 69+(12*log2(x/440)) end

local function round(x)
  if x>=0 then return math.floor(x+0.5)
  else return math.ceil(x-0.5) end
end

local function get_note_letter(x)
  local note=round(x)
  local octave=math.floor((note-12)/12)
  local letters={"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
  return letters[(note%12)+1]..octave
end

local function analyze_sample_selection(cycles)
  cycles = cycles or 1  -- Default to 1 cycle if not specified
  local s=renoise.song()
  local smp=s.selected_sample
  if not smp then return nil,"No sample selected." end
  local buf=smp.sample_buffer
  if not buf.has_sample_data then return nil,"No sample data." end
  local sel_start=buf.selection_start
  local sel_end=buf.selection_end
  if sel_end<=sel_start then return nil,"Invalid selection." end
  local frames=1+(sel_end-sel_start)
  local rate=buf.sample_rate
  local freq=rate/(frames/cycles)
  local midi=freq2midi(freq)
  local nearest=round(midi)
  local cents=(nearest-midi)*100
  return {
    frames=frames,
    freq=freq,
    midi=midi,
    nearest=nearest,
    cents=cents,
    letter=get_note_letter(midi)
  }
end

-- Analyze slice markers and calculate slice lengths
function analyze_slice_markers()
  print("--- Slice Marker Analysis ---")
  
  local sample = renoise.song().selected_sample
  if not sample then
    print("Error: No sample selected")
    return
  end
  
  if not sample.sample_buffer then
    print("Error: Sample has no sample buffer")
    return
  end
  
  local slice_markers = sample.slice_markers
  local slice_count = #slice_markers
  local sample_rate = sample.sample_buffer.sample_rate
  local total_frames = sample.sample_buffer.number_of_frames
  
  print("Sample Rate: " .. sample_rate .. " Hz")
  print("Total Sample Frames: " .. total_frames)
  print("Number of Slices: " .. slice_count)
  print("")
  
  if slice_count == 0 then
    print("No slices found in selected sample")
    return
  end
  
  -- Print all slice markers first
  print("Raw slice markers:")
  rprint(slice_markers)
  print("")
  
  -- Calculate slice lengths
  print("Slice Analysis:")
  print("Slice#\tStart Frame\tEnd Frame\tLength (frames)\tLength (seconds)\tLength (ms)")
  print("------\t-----------\t---------\t---------------\t----------------\t----------")
  
  local slice_lengths = {}
  
  for i = 1, slice_count do
    local start_frame = slice_markers[i]
    local end_frame
    
    -- Determine end frame for this slice
    if i < slice_count then
      end_frame = slice_markers[i + 1] - 1
    else
      end_frame = total_frames - 1
    end
    
    local length_frames = end_frame - start_frame + 1
    local length_seconds = length_frames / sample_rate
    local length_ms = length_seconds * 1000
    
    slice_lengths[i] = length_frames
    
    print(string.format("%d\t%d\t\t%d\t\t%d\t\t%.4f\t\t\t%.2f", 
          i, start_frame, end_frame, length_frames, length_seconds, length_ms))
  end
  
  print("")
  
  -- Analyze if slice lengths are similar
  print("Slice Length Comparison:")
  
  -- Find unique lengths and sort them
  local unique_lengths = {}
  local length_counts = {}
  
  for i = 1, #slice_lengths do
    local length = slice_lengths[i]
    if not unique_lengths[length] then
      unique_lengths[length] = true
      length_counts[length] = 0
    end
    length_counts[length] = length_counts[length] + 1
  end
  
  -- Convert to sorted array
  local sorted_lengths = {}
  for length, _ in pairs(unique_lengths) do
    table.insert(sorted_lengths, length)
  end
  table.sort(sorted_lengths)
  
  local min_length = sorted_lengths[1]
  local max_length = sorted_lengths[#sorted_lengths]
  local second_shortest = sorted_lengths[2] or min_length
  
  -- Find which slices have min and max lengths
  local shortest_slices = {}
  local longest_slices = {}
  local second_shortest_slices = {}
  
  for i = 1, #slice_lengths do
    if slice_lengths[i] == min_length then
      table.insert(shortest_slices, i)
    elseif slice_lengths[i] == max_length then
      table.insert(longest_slices, i)
    elseif slice_lengths[i] == second_shortest then
      table.insert(second_shortest_slices, i)
    end
  end
  
  local total_length = 0
  for i = 1, #slice_lengths do
    total_length = total_length + slice_lengths[i]
  end
  local average_length = total_length / #slice_lengths
  
  -- Check if shortest slice is the last slice
  local shortest_is_last = false
  local last_slice_number = slice_count
  for i = 1, #shortest_slices do
    if shortest_slices[i] == last_slice_number then
      shortest_is_last = true
      break
    end
  end
  
  print("Shortest slice length: " .. min_length .. " frames (Slice #" .. table.concat(shortest_slices, ", ") .. ")")
  if shortest_is_last then
    print("-> The shortest slice IS the LAST slice (#" .. last_slice_number .. ") - this is a remainder slice")
  else
    print("-> The shortest slice is NOT the last slice - this indicates an irregular slicing pattern")
  end
  print("Second shortest length: " .. second_shortest .. " frames (Slice #" .. table.concat(second_shortest_slices, ", ") .. ")")
  print("Longest slice length: " .. max_length .. " frames (Slice #" .. table.concat(longest_slices, ", ") .. ")")
  print("Average slice length: " .. string.format("%.2f", average_length) .. " frames")
  print("Length difference (max-min): " .. (max_length - min_length) .. " frames")
  
  -- Show unique length distribution
  print("")
  print("Length Distribution:")
  for i = 1, #sorted_lengths do
    local length = sorted_lengths[i]
    local count = length_counts[length]
    print(string.format("%d frames: %d slices", length, count))
  end
  
  -- Analyze the slicing pattern and provide theories
  print("")
  print("Theory Analysis:")
  
  if #sorted_lengths == 2 and (sorted_lengths[2] - sorted_lengths[1]) == 1 then
    print("The 1-frame difference between " .. sorted_lengths[1] .. " and " .. sorted_lengths[2] .. " frames")
    print("is due to rounding when dividing the sample into equal slices.")
    print("When slice positions don't align exactly with frame boundaries,")
    print("some slices get 1 extra frame to maintain timing precision.")
  elseif shortest_is_last and min_length < (max_length * 0.8) then
    print("The shorter final slice (" .. min_length .. " vs ~" .. max_length .. " frames)")
    print("is a REMAINDER SLICE - normal when sample length doesn't divide evenly.")
    print("The last slice contains leftover frames after equal division of slices 1-" .. (last_slice_number - 1) .. ".")
  elseif not shortest_is_last then
    print("WARNING: Shortest slice #" .. table.concat(shortest_slices, ", ") .. " is NOT the last slice!")
    print("This suggests irregular slicing - possibly manual slice placement")
    print("or a non-standard slicing algorithm was used.")
  else
    print("Slices appear to have relatively uniform lengths.")
  end
  
  -- Check if slices are similar (within 10% tolerance, excluding obvious remainder slices)
  local tolerance = average_length * 0.1
  local similar_slices = true
  local outlier_count = 0
  
  for i = 1, #slice_lengths do
    if math.abs(slice_lengths[i] - average_length) > tolerance then
      similar_slices = false
      outlier_count = outlier_count + 1
    end
  end
  
  print("")
  if similar_slices then
    print("Result: All slices are SIMILAR in length (within 10% tolerance)")
  else
    print("Result: Slices have VARYING lengths (" .. outlier_count .. " outliers detected)")
  end
  
  -- Show individual slice length differences from average
  print("")
  print("Individual slice length comparison to average:")
  for i = 1, #slice_lengths do
    local diff = slice_lengths[i] - average_length
    local diff_percent = (diff / average_length) * 100
    print(string.format("Slice %d: %d frames (%.2f%% from average)", i, slice_lengths[i], diff_percent))
  end
  
  print("--- End Analysis ---")
end

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
  renoise.tool():add_menu_entry{name=string.format("Sample Editor:Paketti:Set Sample Zoom:Zoom " .. formatDigits(2,i) .. "x"),invoke=function() setSampleZoom(i) end}
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

-- Note: find_volume_ahdsr_device() is defined globally in main.lua

-- Helper function to apply AHDSR envelope and filter settings after loading an XRNI
function PakettiApplyLoaderModulationSettings(instrument, debug_context)
  if not instrument then return false, "No instrument provided" end
  
  if instrument.sample_modulation_sets and #instrument.sample_modulation_sets > 0 then
    local modset = instrument.sample_modulation_sets[1]
    
    -- Search for Volume AHDSR device by name and activate if preference is enabled
    if preferences.pakettiPitchbendLoaderEnvelope.value and modset.devices then
      for i, device in ipairs(modset.devices) do
        if device.name == "Volume AHDSR" then
          device.is_active = true
          if debug_context then
            print(string.format("%s: Activated Volume AHDSR at position %d", debug_context, i))
          end
          -- Apply filter type if preference is set
          if preferences.pakettiLoaderFilterType.value and modset.filter_type then
            modset.filter_type = preferences.pakettiLoaderFilterType.value
          end
          return true, i
        end
      end
      if debug_context then
        print(string.format("%s: WARNING - Volume AHDSR device not found in modulation set!", debug_context))
      end
      return false, "Volume AHDSR not found"
    end
    
    -- Still apply filter type even if AHDSR preference is disabled
    if preferences.pakettiLoaderFilterType.value and modset.filter_type then
      modset.filter_type = preferences.pakettiLoaderFilterType.value
    end
  end
  
  return false, "No modulation sets"
end

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

  -- Apply modulation settings using helper function
  local instrument = renoise.song().selected_instrument
  PakettiApplyLoaderModulationSettings(instrument, "pakettiPreferencesDefaultInstrumentLoader")
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
    if not safeInsertInstrumentAt(song, current_instrument_index + 1) then return end
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

  -- Apply modulation settings using helper function
  PakettiApplyLoaderModulationSettings(current_instrument, "pitchBendDrumkitLoader")

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
  
  -- Apply all Paketti Loader settings including large sample normalization
  PakettiInjectApplyLoaderSettings(sample)

  -- Iterate over the rest of the selected files and insert them sequentially
  for i = 2, num_samples_to_load do
    selected_sample_filename = selected_sample_filenames[i]

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
    
    -- Apply all Paketti Loader settings including large sample normalization
    PakettiInjectApplyLoaderSettings(sample)
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
   loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
  
  local macro_device = song.selected_track:device(2)
  macro_device.display_name = instrument_name_prefix
  song.selected_track.devices[2].is_maximized = false
end
end 
  -- Additional actions after loading samples
  on_sample_count_change()
  -- showAutomation()
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Drumkit Sample Loader",invoke=function() pitchBendDrumkitLoader() end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti PitchBend Drumkit Sample Loader",invoke=function(message) if message:is_trigger() then pitchBendDrumkitLoader() end end}

function loadRandomDrumkitSamples(num_samples, folder_path, create_automation_device)
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    -- Seed the random number generator with current time
    math.randomseed(os.time())
    -- Add some random calls to further randomize the sequence
    math.random(); math.random(); math.random()

    -- If no folder_path provided, prompt the user to select a folder
    if not folder_path or folder_path == "" then
        folder_path = renoise.app():prompt_for_path("Select Folder to Randomize Drumkit Loading From")
        if not folder_path then
            renoise.app():show_status("No folder selected.")
            return nil
        end
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
        if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then return end
        song.selected_instrument_index = song.selected_instrument_index + 1
        instrument = song.selected_instrument
    end

    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
    
    renoise.app():load_instrument(defaultInstrument)

    -- Update the instrument reference after loading the instrument
    instrument = song.selected_instrument

    -- Apply modulation settings using helper function
    PakettiApplyLoaderModulationSettings(instrument, "loadRandomDrumkitSamples")

    -- Set the instrument name based on slot
    local instrument_slot_hex = string.format("%02X", song.selected_instrument_index - 1)
    instrument.name = instrument_slot_hex .. "_Drumkit"

    -- Limit the number of samples to load to the requested amount
    local num_samples_to_load = math.min(#sample_files, num_samples)

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

        -- Add the *Instr. Macros device like pitchBendDrumkitLoader does
        if create_automation_device ~= false and preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
            -- Load the *Instr. Macros device and rename it
            if song.selected_track.type == 2 then 
                renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") 
            else
                loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
                
                local macro_device = song.selected_track:device(2)
                macro_device.display_name = instrument_slot_hex .. "_Drumkit"
                song.selected_track.devices[2].is_maximized = false
            end
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

    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    
    -- Return the loaded instrument
    return instrument
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function() loadRandomDrumkitSamples(120) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti PitchBend Drumkit Sample Loader (Random)",invoke=function(message) if message:is_trigger() then loadRandomDrumkitSamples(120)  end end}

-- Function to create a new instrument from the selected sample buffer range
function create_new_instrument_from_selection()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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
  if not safeInsertInstrumentAt(song, new_instrument_index) then return end
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
  loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
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

-- Restore AutoSamplify monitoring state
PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Create New Instrument & Loop from Selection",invoke=create_new_instrument_from_selection}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Create New Instrument & Loop from Selection",invoke=create_new_instrument_from_selection}

-- Function to create a new instrument from selection while preserving slice markers and their properties
function create_new_instrument_from_selection_with_slices()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local selected_sample = song.selected_sample
  local selected_instrument_index = song.selected_instrument_index
  local selected_instrument = song.selected_instrument
  
  if selected_sample == nil then
    renoise.app():show_status("There is no sample in the sample slot, doing nothing.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  if not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No sample buffer data found in the selected sample.")
    print("Error: No sample buffer data found in the selected sample.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  print("Sample buffer data is valid.")
  
  local sample_buffer = selected_sample.sample_buffer
  
  if sample_buffer.selection_range == nil or #sample_buffer.selection_range < 2 then
    renoise.app():show_error("No valid selection range found.")
    print("Error: No valid selection range found.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  print("Selection range is valid.")
  
  local selection_start = sample_buffer.selection_range[1]
  local selection_end = sample_buffer.selection_range[2]
  local selection_length = selection_end - selection_start + 1
  
  if selection_start == selection_end then
    renoise.app():show_error("Selection range is too small (start equals end).")
    print("Error: Selection range is too small.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  print(string.format("Selection range: %d to %d (length: %d frames)", selection_start, selection_end, selection_length))
  
  local bit_depth = sample_buffer.bit_depth
  local sample_rate = sample_buffer.sample_rate
  local num_channels = sample_buffer.number_of_channels
  
  print(string.format("Sample properties - Bit depth: %d, Sample rate: %d, Number of channels: %d", bit_depth, sample_rate, num_channels))
  
  -- Get slice markers from the first sample (master sample)
  local first_sample = selected_instrument.samples[1]
  local original_slice_markers = first_sample.slice_markers
  local has_slices = original_slice_markers and #original_slice_markers > 0
  
  -- Find slice markers within the selection and store their original indices
  local slices_in_selection = {}
  if has_slices then
    print(string.format("Original instrument has %d slice markers", #original_slice_markers))
    for i = 1, #original_slice_markers do
      local marker_pos = original_slice_markers[i]
      if marker_pos >= selection_start and marker_pos <= selection_end then
        -- Store: original marker position, original slice index (1-based), new marker position
        local new_marker_pos = marker_pos - selection_start + 1
        table.insert(slices_in_selection, {
          original_pos = marker_pos,
          original_index = i,
          new_pos = new_marker_pos
        })
        print(string.format("  Slice %d at position %d is within selection -> new position: %d", i, marker_pos, new_marker_pos))
      end
    end
    print(string.format("Found %d slice markers within selection", #slices_in_selection))
  else
    print("No slice markers in original instrument")
  end

  -- Insert a new instrument right below the current instrument
  local new_instrument_index = selected_instrument_index + 1
  if not safeInsertInstrumentAt(song, new_instrument_index) then return end
  song.selected_instrument_index = new_instrument_index
  print("Inserted new instrument at index " .. new_instrument_index)

  -- Load the default instrument template
  pakettiPreferencesDefaultInstrumentLoader()
  print("Loaded Default XRNI instrument into the new instrument slot.")

  local new_instrument = song:instrument(new_instrument_index)
  new_instrument.name = "Pitchbend Instrument"
  new_instrument.macros_visible = true
  if new_instrument.sample_modulation_sets[1] then
    new_instrument.sample_modulation_sets[1].name = "Pitchbend"
  end
  print("Configured new instrument properties.")
  
  -- Overwrite the "Placeholder sample" with the selected sample
  local new_sample = new_instrument.samples[1]
  
  -- Create sample data and prepare to make changes
  new_sample.sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, selection_length)
  local new_sample_buffer = new_sample.sample_buffer
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
  
  -- Insert slice markers at their new positions
  if #slices_in_selection > 0 then
    print("Inserting slice markers into new sample...")
    for j = 1, #slices_in_selection do
      local slice_info = slices_in_selection[j]
      new_sample:insert_slice_marker(slice_info.new_pos)
      print(string.format("  Inserted slice marker at position %d", slice_info.new_pos))
    end
    print(string.format("Inserted %d slice markers", #slices_in_selection))
    
    -- Copy per-slice sample properties
    -- Original slice i has properties in selected_instrument.samples[i + 1]
    -- New slice j has properties in new_instrument.samples[j + 1]
    print("Copying per-slice sample properties...")
    for j = 1, #slices_in_selection do
      local slice_info = slices_in_selection[j]
      local original_slice_sample_index = slice_info.original_index + 1
      local new_slice_sample_index = j + 1
      
      -- Calculate the new slice length (from this marker to next marker or end of sample)
      local new_slice_start = slice_info.new_pos
      local new_slice_end
      if j < #slices_in_selection then
        new_slice_end = slices_in_selection[j + 1].new_pos - 1
      else
        new_slice_end = selection_length
      end
      local new_slice_length = new_slice_end - new_slice_start + 1
      
      -- Ensure the original slice sample exists
      if original_slice_sample_index <= #selected_instrument.samples then
        local src_slice_sample = selected_instrument.samples[original_slice_sample_index]
        local dst_slice_sample = new_instrument.samples[new_slice_sample_index]
        
        if dst_slice_sample then
          -- Copy sample properties
          dst_slice_sample.name = src_slice_sample.name
          dst_slice_sample.transpose = src_slice_sample.transpose
          dst_slice_sample.fine_tune = src_slice_sample.fine_tune
          dst_slice_sample.volume = src_slice_sample.volume
          dst_slice_sample.panning = src_slice_sample.panning
          dst_slice_sample.beat_sync_enabled = src_slice_sample.beat_sync_enabled
          dst_slice_sample.beat_sync_lines = src_slice_sample.beat_sync_lines
          dst_slice_sample.beat_sync_mode = src_slice_sample.beat_sync_mode
          dst_slice_sample.autoseek = src_slice_sample.autoseek
          dst_slice_sample.autofade = src_slice_sample.autofade
          dst_slice_sample.loop_mode = src_slice_sample.loop_mode
          
          -- Copy loop_start and loop_end, clamped to the new slice's valid range
          local src_loop_start = src_slice_sample.loop_start
          local src_loop_end = src_slice_sample.loop_end
          -- Clamp loop_start: must be >= 1 and <= new_slice_length
          local new_loop_start = math.max(1, math.min(src_loop_start, new_slice_length))
          -- Clamp loop_end: must be >= loop_start and <= new_slice_length
          local new_loop_end = math.max(new_loop_start, math.min(src_loop_end, new_slice_length))
          dst_slice_sample.loop_start = new_loop_start
          dst_slice_sample.loop_end = new_loop_end
          
          if src_loop_start ~= new_loop_start or src_loop_end ~= new_loop_end then
            print(string.format("    Loop values clamped: start %d->%d, end %d->%d (slice length: %d)",
              src_loop_start, new_loop_start, src_loop_end, new_loop_end, new_slice_length))
          end
          
          dst_slice_sample.loop_release = src_slice_sample.loop_release
          dst_slice_sample.new_note_action = src_slice_sample.new_note_action
          dst_slice_sample.oneshot = src_slice_sample.oneshot
          dst_slice_sample.mute_group = src_slice_sample.mute_group
          dst_slice_sample.interpolation_mode = src_slice_sample.interpolation_mode
          dst_slice_sample.oversample_enabled = src_slice_sample.oversample_enabled
          
          print(string.format("  Copied properties from original slice %d (samples[%d]) to new slice %d (samples[%d])",
            slice_info.original_index, original_slice_sample_index, j, new_slice_sample_index))
        else
          print(string.format("  Warning: New slice sample at index %d does not exist", new_slice_sample_index))
        end
      else
        print(string.format("  Warning: Original slice sample at index %d does not exist", original_slice_sample_index))
      end
    end
  end
  
  -- Set the loop mode based on preferences.selectionNewInstrumentLoop
  local loop_mode_message = ""
  if preferences.selectionNewInstrumentLoop.value == 1 then
    new_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    loop_mode_message = "No Loop"
    print("Set loop mode to 'Off'.")
  elseif preferences.selectionNewInstrumentLoop.value == 2 then
    new_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    loop_mode_message = "Forward Loop"
    print("Set loop mode to 'Forward'.")
  elseif preferences.selectionNewInstrumentLoop.value == 3 then
    new_sample.loop_mode = renoise.Sample.LOOP_MODE_REVERSE
    loop_mode_message = "Backward Loop"
    print("Set loop mode to 'Reverse'.")
  elseif preferences.selectionNewInstrumentLoop.value == 4 then
    new_sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
    loop_mode_message = "PingPong Loop"
    print("Set loop mode to 'Ping-Pong'.")
  end
  
  -- Set the names for the new instrument and sample
  local instrument_slot_hex = string.format("%02X", new_instrument_index - 1)
  local original_sample_name = selected_sample.name
  new_instrument.name = string.format("%s_%s", instrument_slot_hex, original_sample_name)
  new_sample.name = string.format("%s_%s", instrument_slot_hex, original_sample_name)
  print(string.format("Set names for the new instrument and sample: %s_%s", instrument_slot_hex, original_sample_name))
  
  -- Load the *Instr. Macros device and rename it
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
    if renoise.song().selected_track.type == 2 then
      renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.")
    else
      loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
      local macro_device = song.selected_track:device(2)
      if macro_device then
        macro_device.display_name = string.format("%s_%s", instrument_slot_hex, original_sample_name)
        song.selected_track.devices[2].is_maximized = false
        print("Loaded and configured *Instr. Macros device.")
      end
    end
  end
  
  new_sample.new_note_action = 1
  
  -- Apply preferences to the new sample
  new_sample.interpolation_mode = preferences.selectionNewInstrumentInterpolation.value
  new_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  new_sample.autofade = preferences.selectionNewInstrumentAutofade.value
  new_sample.autoseek = preferences.selectionNewInstrumentAutoseek.value
  new_sample.oneshot = preferences.pakettiLoaderOneshot.value
  
  -- Select the new instrument and sample if preferences.selectionNewInstrumentSelect is true
  if preferences.selectionNewInstrumentSelect.value == true then
    song.selected_instrument_index = new_instrument_index
    song.selected_sample_index = 1
    print("Selected the new instrument and sample.")
  else
    song.selected_instrument_index = selected_instrument_index
    print("Stayed in the current sample editor view of the instrument you chopped out of.")
  end
  
  local slice_message = ""
  if #slices_in_selection > 0 then
    slice_message = string.format(" with %d slices", #slices_in_selection)
  end
  renoise.app():show_status("New instrument created from selection" .. slice_message .. " with " .. loop_mode_message .. ".")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Create New Instrument from Selection with Slices",invoke=create_new_instrument_from_selection_with_slices}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Create New Instrument from Selection with Slices",invoke=create_new_instrument_from_selection_with_slices}

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
-- Global progress tracking variables for pitchBend loader
local pitchbend_loader_progress = {
  current_file_index = 0,
  current_filename = "",
  total_files = 0,
  slicer = nil,
  vb = nil,
  dialog = nil
}

function pitchBendMultipleSampleLoader(normalize)
  local selected_sample_filenames = renoise.app():prompt_for_multiple_filenames_to_read({"*.wav", "*.aif", "*.flac", "*.mp3", "*.aiff"}, "Paketti PitchBend Multiple Sample Loader")

  if #selected_sample_filenames == 0 then
    renoise.app():show_status("No file selected.")
    return
  end

  rprint(selected_sample_filenames)
  
  -- Initialize progress tracking
  pitchbend_loader_progress.current_file_index = 0
  pitchbend_loader_progress.current_filename = ""
  pitchbend_loader_progress.total_files = #selected_sample_filenames
  
  -- Create ProcessSlicer for the loading operation
  pitchbend_loader_progress.slicer = ProcessSlicer(pitchBendMultipleSampleLoader_process, selected_sample_filenames, normalize)
  pitchbend_loader_progress.dialog, pitchbend_loader_progress.vb = pitchbend_loader_progress.slicer:create_dialog("Loading Pitchbend Samples...")
  
  -- Start the process
  pitchbend_loader_progress.slicer:start()
  
  -- Update progress text periodically
  renoise.tool():add_timer(pitchBendMultipleSampleLoader_update_progress, 100)
end

function pitchBendMultipleSampleLoader_update_progress()
  local progress = pitchbend_loader_progress
  
  if progress.slicer and progress.vb then
    if progress.slicer:running() and not progress.slicer:was_cancelled() then
      -- Update progress text
      local progress_text = string.format("Processing file %d of %d...", progress.current_file_index, progress.total_files)
      if progress.current_filename ~= "" then
        progress_text = progress_text .. "\n" .. progress.current_filename
      end
      progress.vb.views.progress_text.text = progress_text
    elseif not progress.slicer:running() then
      -- Process completed or stopped
      renoise.tool():remove_timer(pitchBendMultipleSampleLoader_update_progress)
      if progress.dialog and progress.dialog.visible then
        progress.dialog:close()
      end
      if not progress.slicer:was_cancelled() then
        renoise.app():show_status("All samples loaded successfully.")
      else
        renoise.app():show_status("Sample loading cancelled.")
      end
      
      -- Reset progress tracking
      pitchbend_loader_progress = {
        current_file_index = 0,
        current_filename = "",
        total_files = 0,
        slicer = nil,
        vb = nil,
        dialog = nil
      }
    end
  end
end


function pitchBendMultipleSampleLoader_process(selected_sample_filenames, normalize)
  -- Completely stop AutoSamplify monitoring to prevent double-processing
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- DISABLE Sample Range Device Loader to prevent it from creating duplicate instruments
  local SampleRangeLoaderState = preferences.pakettiSampleRangeDeviceLoaderEnabled.value
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = false
  
  for index, filename in ipairs(selected_sample_filenames) do
    pitchbend_loader_progress.current_file_index = index
    pitchbend_loader_progress.current_filename = filename:match("^.+[/\\](.+)$") or filename
    
    -- Check for cancellation
    if pitchbend_loader_progress.slicer and pitchbend_loader_progress.slicer:was_cancelled() then
      renoise.app():show_status("Sample loading cancelled by user.")
      -- Restore states before breaking
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
      break
    end
    
    coroutine.yield()

    -- Check instrument limit before inserting
    local next_instrument = renoise.song().selected_instrument_index + 1
    if not safeInsertInstrumentAt(renoise.song(), next_instrument) then
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
      break
    end
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
        if renoise.song().selected_track.type == 2 then 
          renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") 
        else
                loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true) 
          local macro_device = renoise.song().selected_track:device(2)
          macro_device.display_name = string.format("%s_%s", instrument_slot_hex, filename_only)
          renoise.song().selected_track.devices[2].is_maximized = false
        end
      end
    else
      renoise.app():show_status("Failed to load the sample " .. filename_only)
    end
    
    -- Yield control back to allow UI updates
    coroutine.yield()
  end
  
  -- Restore all states now that we're done
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  preferences.pakettiSampleRangeDeviceLoaderEnabled.value = SampleRangeLoaderState
  
  -- Reset progress tracking when complete
  pitchbend_loader_progress.current_file_index = 0
  pitchbend_loader_progress.current_filename = ""
end
renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti PitchBend Multiple Sample Loader (Normalize)",invoke=function() pitchBendMultipleSampleLoader(true) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti PitchBend Multiple Sample Loader",invoke=function() pitchBendMultipleSampleLoader() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paketti PitchBend Multiple Sample Loader (Normalize)",invoke=function() pitchBendMultipleSampleLoader(true) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti PitchBend Multiple Sample Loader",invoke=function(message) if message:is_trigger() then pitchBendMultipleSampleLoader() end end}

-- StemLoader code moved to PakettiStemLoader.lua

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



-----------------------------------------------------------------------------------------------------------
function addSampleSlot(amount)
for i=1,amount do
renoise.song().instruments[renoise.song().selected_instrument_index]:insert_sample_at(i)
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Add Sample Slot to Instrument",invoke=function() addSampleSlot(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Add 84 Sample Slots to Instrument",invoke=function() addSampleSlot(84) end}

function PakettiSamplesInsertNewSampleSlotAndSelect()
  local song = renoise.song()
  local current_instrument = song.selected_instrument
  
  if current_instrument == nil then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  -- Protection: Check if this is a sliced instrument
  if #current_instrument.samples > 0 and #current_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_status("Cannot modify sample slots on sliced instruments - modify slice markers instead")
    return
  end
  
  local current_sample_index = song.selected_sample_index
  local new_sample_index = current_sample_index + 1
  
  -- Insert new sample slot at the next position
  current_instrument:insert_sample_at(new_sample_index)
  
  -- Select the newly created sample slot
  song.selected_sample_index = new_sample_index
  
  -- Apply PakettiLoader preferences to the new sample slot
  local new_sample = current_instrument.samples[new_sample_index]
  new_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  new_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  new_sample.autofade = preferences.pakettiLoaderAutofade.value
  new_sample.autoseek = preferences.pakettiLoaderAutoseek.value
  new_sample.oneshot = preferences.pakettiLoaderOneshot.value
  new_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  new_sample.new_note_action = preferences.pakettiLoaderNNA.value
  new_sample.loop_release = preferences.pakettiLoaderLoopExit.value
  
  renoise.app():show_status("New sample slot inserted and selected at position " .. new_sample_index .. " (PakettiLoader preferences applied)")
end

function PakettiSamplesDeleteCurrentSampleAndSelectNext()
  local song = renoise.song()
  local current_instrument = song.selected_instrument
  
  if current_instrument == nil then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local num_samples = #current_instrument.samples
  
  -- Protection: Check if there are any samples to delete
  if num_samples == 0 then
    renoise.app():show_status("No sample slots to delete")
    return
  end
  
  -- Protection: Check if this is a sliced instrument
  if #current_instrument.samples > 0 and #current_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_status("Cannot modify sample slots on sliced instruments - modify slice markers instead")
    return
  end
  
  -- Protection: Don't delete the last sample if it's the only one with sample data
  if num_samples == 1 and current_instrument.samples[1].sample_buffer.has_sample_data then
    renoise.app():show_status("Cannot delete the only sample with data - create another sample first")
    return
  end
  
  local current_sample_index = song.selected_sample_index
  
  -- Delete the current sample
  current_instrument:delete_sample_at(current_sample_index)
  
  -- Update sample count after deletion
  num_samples = #current_instrument.samples
  
  -- Protection: If no samples left, don't try to select anything
  if num_samples == 0 then
    renoise.app():show_status("Sample deleted, no samples remaining in instrument")
    return
  end
  
  -- Select next sample, or the last one if we deleted the last sample
  if current_sample_index > num_samples then
    song.selected_sample_index = num_samples
  else
    song.selected_sample_index = current_sample_index
  end
  
  renoise.app():show_status("Sample deleted, selected sample " .. song.selected_sample_index .. " of " .. num_samples)
end

renoise.tool():add_keybinding{name="Global:Paketti:Insert New Sample Slot & Select",invoke=function() PakettiSamplesInsertNewSampleSlotAndSelect() end}
renoise.tool():add_keybinding{name="Global:Paketti:Delete Current Sample & Select Next",invoke=function() PakettiSamplesDeleteCurrentSampleAndSelectNext() end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Insert New Sample Slot & Select",invoke=function(message) if message:is_trigger() then PakettiSamplesInsertNewSampleSlotAndSelect() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Delete Current Sample & Select Next",invoke=function(message) if message:is_trigger() then PakettiSamplesDeleteCurrentSampleAndSelectNext() end end}

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

-- Loop Length helpers for all samples in selected instrument
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set All Samples in Selected Instrument to Full Loop",invoke=function() set_loop_length_for_selected_instrument("full") end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set All Samples in Selected Instrument to End-Half Loop",invoke=function() set_loop_length_for_selected_instrument("half") end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set All Samples in Selected Instrument to Beginning Half Loop",invoke=function() set_loop_length_for_selected_instrument("begin") end}

-- Set Selected Instrument Loop functions (for ALL samples in the instrument)
function pakettiSetSelectedInstrumentLoopOff()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end
  
  local samples = instrument.samples
  local num_samples = #samples
  
  if num_samples < 1 then
    renoise.app():show_status("No samples in the selected instrument.")
    return
  end
  
  for i = 1, num_samples do
    samples[i].loop_mode = renoise.Sample.LOOP_MODE_OFF
  end
  
  renoise.app():show_status("Loop mode set to Off for " .. num_samples .. " samples.")
end

function pakettiSetSelectedInstrumentLoopForward()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end
  
  local samples = instrument.samples
  local num_samples = #samples
  
  if num_samples < 1 then
    renoise.app():show_status("No samples in the selected instrument.")
    return
  end
  
  for i = 1, num_samples do
    samples[i].loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  end
  
  renoise.app():show_status("Loop mode set to Forward for " .. num_samples .. " samples.")
end

function pakettiSetSelectedInstrumentLoopReverse()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end
  
  local samples = instrument.samples
  local num_samples = #samples
  
  if num_samples < 1 then
    renoise.app():show_status("No samples in the selected instrument.")
    return
  end
  
  for i = 1, num_samples do
    samples[i].loop_mode = renoise.Sample.LOOP_MODE_REVERSE
  end
  
  renoise.app():show_status("Loop mode set to Reverse for " .. num_samples .. " samples.")
end

function pakettiSetSelectedInstrumentLoopPingPong()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end
  
  local samples = instrument.samples
  local num_samples = #samples
  
  if num_samples < 1 then
    renoise.app():show_status("No samples in the selected instrument.")
    return
  end
  
  for i = 1, num_samples do
    samples[i].loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
  end
  
  renoise.app():show_status("Loop mode set to PingPong for " .. num_samples .. " samples.")
end

-- Keybindings for Set Selected Instrument Loop functions
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Loop 00 Off", invoke=pakettiSetSelectedInstrumentLoopOff}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Loop 01 Forward", invoke=pakettiSetSelectedInstrumentLoopForward}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Loop 02 Reverse", invoke=pakettiSetSelectedInstrumentLoopReverse}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Loop 03 PingPong", invoke=pakettiSetSelectedInstrumentLoopPingPong}

------------------
function slicerough(changer)
-- Limit changer to 255 (Renoise's maximum slice marker limit)
if changer > 255 then
    print("-- Wipe&Slice: Limited slice count from " .. changer .. " to 255 (Renoise maximum)")
    renoise.app():show_status("Limited to 255 slices (Renoise maximum)")
    changer = 255
end

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
    
    -- Check for sample count vs slice markers
    local first_sample = s.instruments[currInst].samples[1]
    local has_slice_markers = first_sample.slice_markers and #first_sample.slice_markers > 0
    local sample_count = #s.instruments[currInst].samples
    
    -- If no slice markers and more than one sample, show error and return
    if not has_slice_markers and sample_count > 1 then
        renoise.app():show_status("Wipe & Slice detected more than one sample, doing nothing.")
        return
    end
    
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
        local beat_sync_mode = preferences.WipeSlices.WipeSlicesBeatsyncMode.value

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

-- Function to double the number of slices by adding markers between existing ones
function doubleslices()
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
    
    local instrument = s.instruments[currInst]
    local sample = instrument.samples[1]
    
    -- Check if the sample is valid and has sample data
    if not sample or not sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample data available.")
        return
    end
    
    local slice_markers = sample.slice_markers
    local current_slice_count = #slice_markers
    
    -- Need at least 1 slice marker to double
    if current_slice_count < 1 then
        renoise.app():show_status("No slices to double.")
        return
    end
    
    -- Check if doubling would exceed the 255 slice limit
    -- Calculate how many new markers we would add
    local potential_new_markers = current_slice_count + 1  -- +1 for marker between last slice and end
    if current_slice_count + potential_new_markers > 255 then
        renoise.app():show_status("Cannot double: would exceed maximum of 255 slices.")
        return
    end
    
    -- Calculate new slice positions between existing ones
    local new_markers = {}
    local total_frames = sample.sample_buffer.number_of_frames
    
    -- Add marker between start and first slice
    if current_slice_count > 0 then
        local midpoint = math.floor(slice_markers[1] / 2)
        if midpoint > 0 then
            table.insert(new_markers, midpoint)
        end
    end
    
    -- Add markers between consecutive slices
    for i = 1, current_slice_count - 1 do
        local start_pos = slice_markers[i]
        local end_pos = slice_markers[i + 1]
        local midpoint = math.floor((start_pos + end_pos) / 2)
        table.insert(new_markers, midpoint)
    end
    
    -- Add marker between last slice and end
    if current_slice_count > 0 then
        local start_pos = slice_markers[current_slice_count]
        local midpoint = math.floor((start_pos + total_frames) / 2)
        if midpoint < total_frames then
            table.insert(new_markers, midpoint)
        end
    end
    
    -- Insert the new slice markers
    for _, pos in ipairs(new_markers) do
        sample:insert_slice_marker(pos)
    end
    
    local new_slice_count = #sample.slice_markers
    renoise.app():show_status("Doubled slices: " .. current_slice_count .. " -> " .. new_slice_count)
end

-- Function to halve the number of slices by removing every other marker
function halveslices()
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
    
    local instrument = s.instruments[currInst]
    local sample = instrument.samples[1]
    
    -- Check if the sample is valid and has sample data
    if not sample or not sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample data available.")
        return
    end
    
    local slice_markers = sample.slice_markers
    local current_slice_count = #slice_markers
    
    -- Need at least 2 slice markers to halve
    if current_slice_count < 2 then
        renoise.app():show_status("Need at least 2 slices to halve.")
        return
    end
    
    -- Collect markers to remove (every other one, starting from the 2nd)
    local markers_to_remove = {}
    for i = 2, current_slice_count, 2 do
        table.insert(markers_to_remove, slice_markers[i])
    end
    
    -- Remove the markers
    for _, marker_pos in ipairs(markers_to_remove) do
        sample:delete_slice_marker(marker_pos)
    end
    
    local new_slice_count = #sample.slice_markers
    renoise.app():show_status("Halved slices: " .. current_slice_count .. " -> " .. new_slice_count)
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
renoise.tool():add_keybinding{name="Global:Paketti:Double Slices",invoke=function() doubleslices() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Slices",invoke=function() halveslices() end}



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
      tmpvariable=pakettiGetTempFilePath(".wav")
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
    if from_sample.loop_start > 0 and from_sample.loop_end > from_sample.loop_start and to_sample.sample_buffer.has_sample_data then
      local source_length = from_sample.sample_buffer.number_of_frames
      local dest_length = to_sample.sample_buffer.number_of_frames
      
      if source_length > 0 then
        -- Calculate proportional loop points to maintain relative loop position
        local loop_start_ratio = from_sample.loop_start / source_length
        local loop_end_ratio = from_sample.loop_end / source_length
        
        local scaled_loop_start = math.max(1, math.floor(loop_start_ratio * dest_length))
        local scaled_loop_end = math.max(scaled_loop_start + 1, math.floor(loop_end_ratio * dest_length))
        
        -- Ensure loop_end doesn't exceed sample length
        scaled_loop_end = math.min(scaled_loop_end, dest_length)
        
        to_sample.loop_start = scaled_loop_start
        to_sample.loop_end = scaled_loop_end
      else
        -- Fallback to safe defaults
        to_sample.loop_start = 1
        to_sample.loop_end = dest_length
      end
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
  -- Safety check for nil parameters
  if not from_sample or not to_sample then
    return
  end
  
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
  
  -- Scale loop points proportionally to maintain relative loop position
  if from_sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and to_sample.sample_buffer.has_sample_data and from_sample.sample_buffer.has_sample_data then
    local source_length = from_sample.sample_buffer.number_of_frames
    local dest_length = to_sample.sample_buffer.number_of_frames
    
    if source_length > 0 then
      -- Calculate proportional loop points (e.g., if loop was in "endhalf", keep it in endhalf)
      local loop_start_ratio = from_sample.loop_start / source_length
      local loop_end_ratio = from_sample.loop_end / source_length
      
      local scaled_loop_start = math.max(1, math.floor(loop_start_ratio * dest_length))
      local scaled_loop_end = math.max(scaled_loop_start + 1, math.floor(loop_end_ratio * dest_length))
      
      -- Ensure loop_end doesn't exceed sample length
      scaled_loop_end = math.min(scaled_loop_end, dest_length)
      
      to_sample.loop_start = scaled_loop_start
      to_sample.loop_end = scaled_loop_end
    else
      -- Fallback to safe defaults
      to_sample.loop_start = 1
      to_sample.loop_end = dest_length
    end
  else
    -- If no valid loop data or loop mode is off, set safe defaults
    to_sample.loop_start = 1
    to_sample.loop_end = to_sample.sample_buffer.has_sample_data and to_sample.sample_buffer.number_of_frames or 1
  end
  to_sample.mute_group = from_sample.mute_group
  to_sample.new_note_action = from_sample.new_note_action
  to_sample.autoseek = from_sample.autoseek
  to_sample.autofade = from_sample.autofade
  to_sample.oversample_enabled = from_sample.oversample_enabled
  to_sample.interpolation_mode = from_sample.interpolation_mode
  to_sample.name = from_sample.name
end

function PakettiDuplicateAndReverseInstrument()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song=renoise.song()
  local current_index = song.selected_instrument_index
  local current_instrument = song.selected_instrument

  -- Check if the instrument has any samples
  if #current_instrument.samples == 0 then
    renoise.app():show_status("No sample in the Instrument, doing nothing.")
    return
  end

  if not safeInsertInstrumentAt(song, current_index + 1) then
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}


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

function pakettiSampleBufferFlipSelection(direction)
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

  -- Get current selection
  local current_start = sample_buffer.selection_start
  local current_end = sample_buffer.selection_end

  -- Check if there's a valid selection
  if current_start == 1 and current_end == sample_length - 1 then
    renoise.app():show_status("Cannot flip: entire sample is selected.")
    return
  end

  if current_start >= current_end then
    renoise.app():show_status("Cannot flip: no valid selection range.")
    return
  end

  -- Calculate selection length
  local selection_length = current_end - current_start + 1
  local new_start, new_end
  local was_adjusted = false
  local direction_text = direction == -1 and "back" or "forward"

  if direction == -1 then
    -- Flip backward
    new_start = current_start - selection_length
    new_end = current_start - 1
    
    -- Handle edge case where new selection would go before start of sample
    if new_start < 1 then
      new_start = 1
      new_end = current_start - 1
      was_adjusted = true
      if new_end < 1 then
        renoise.app():show_status("Cannot flip back: selection is already at the beginning.")
        return
      end
    end
  else
    -- Flip forward
    new_start = current_end + 1
    new_end = new_start + selection_length - 1
    
    -- Handle edge case where new selection would go beyond end of sample
    if new_end > sample_length - 1 then
      new_end = sample_length - 1
      new_start = new_end - selection_length + 1
      was_adjusted = true
      if new_start <= current_end then
        renoise.app():show_status("Cannot flip forward: selection is already at the end.")
        return
      end
    end
  end

  -- Set the new selection
  sample_buffer.selection_start = new_start
  sample_buffer.selection_end = new_end
  
  -- Show appropriate status message
  local frames_moved = direction == -1 and (current_start - new_end - 1) or (new_start - current_end - 1)
  if was_adjusted then
    local adjustment_text = direction == -1 and "start at frame 1" or ("end at frame " .. (sample_length - 1))
    renoise.app():show_status(string.format("Flipped sample buffer selection %s by %d frames (adjusted to %s): %d-%d to %d-%d", 
      direction_text, frames_moved, adjustment_text, current_start, current_end, new_start, new_end))
  else
    renoise.app():show_status(string.format("Flipped sample buffer selection %s by %d frames: %d-%d to %d-%d", 
      direction_text, frames_moved, current_start, current_end, new_start, new_end))
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Flip Sample Buffer Selection Back",invoke=function()pakettiSampleBufferFlipSelection(-1)end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Flip Sample Buffer Selection Forward",invoke=function()pakettiSampleBufferFlipSelection(1)end}
renoise.tool():add_midi_mapping{name="Paketti:Flip Sample Buffer Selection Back [Trigger]",invoke=function(message) if message:is_trigger() then pakettiSampleBufferFlipSelection(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Flip Sample Buffer Selection Forward [Trigger]",invoke=function(message) if message:is_trigger() then pakettiSampleBufferFlipSelection(1) end end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Selection:Flip Sample Buffer Selection Back",invoke=function()pakettiSampleBufferFlipSelection(-1)end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Selection:Flip Sample Buffer Selection Forward",invoke=function()pakettiSampleBufferFlipSelection(1)end}
renoise.tool():add_menu_entry{name="--Sample Editor Ruler:Flip Sample Buffer Selection Back",invoke=function()pakettiSampleBufferFlipSelection(-1)end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Flip Sample Buffer Selection Forward",invoke=function()pakettiSampleBufferFlipSelection(1)end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Flip Sample Buffer Selection Back",invoke=function()pakettiSampleBufferFlipSelection(-1)end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Flip Sample Buffer Selection Forward",invoke=function()pakettiSampleBufferFlipSelection(1)end}

function pakettiDetectAndSelectSilenceInZoom()
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

  -- Get the current display range (what's visible in zoom)
  local display_range = sample_buffer.display_range
  local start_frame = display_range[1]
  local end_frame = math.min(display_range[2], sample_buffer.number_of_frames)
  local channels = sample_buffer.number_of_channels
  
  -- Define silence threshold (about -60dB)
  local silence_threshold = 0.001
  
  -- Find all silence regions in the visible range
  local silence_regions = {}
  local in_silence = false
  local silence_start = 0
  
  for frame = start_frame, end_frame do
    local is_silent = true
    for channel = 1, channels do
      if math.abs(sample_buffer:sample_data(channel, frame)) > silence_threshold then
        is_silent = false
        break
      end
    end
    
    if is_silent and not in_silence then
      in_silence = true
      silence_start = frame
    elseif not is_silent and in_silence then
      in_silence = false
      local silence_length = frame - silence_start
      table.insert(silence_regions, {silence_start, frame - 1, silence_length})
    end
  end
  
  -- If we ended in silence, add final region
  if in_silence then
    local silence_length = end_frame - silence_start + 1
    table.insert(silence_regions, {silence_start, end_frame, silence_length})
  end
  
  if #silence_regions == 0 then
    renoise.app():show_status("No silence detected in current zoom level.")
    return
  end
  
  -- Find the longest silence region
  local longest_silence = silence_regions[1]
  for i = 2, #silence_regions do
    if silence_regions[i][3] > longest_silence[3] then
      longest_silence = silence_regions[i]
    end
  end
  
  -- Check if detected silence matches current selection
  local current_start = sample_buffer.selection_start
  local current_end = sample_buffer.selection_end
  
  if current_start == longest_silence[1] and current_end == longest_silence[2] then
    -- Same selection, clear it
    sample_buffer.selection_range = {1, 1}
    renoise.app():show_status("Selection cleared.")
  else
    -- Different selection, set new one
    sample_buffer.selection_range = {longest_silence[1], longest_silence[2]}
    
    local silence_duration_ms = (longest_silence[3] / sample_buffer.sample_rate) * 1000
    renoise.app():show_status(string.format("Selected silence: frames %d-%d (%d frames, %.1fms) in zoom range %d-%d", 
      longest_silence[1], longest_silence[2], longest_silence[3], silence_duration_ms, start_frame, end_frame))
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Detect and Select Silence in Zoom",invoke=function()pakettiDetectAndSelectSilenceInZoom()end}
renoise.tool():add_midi_mapping{name="Paketti:Detect and Select Silence in Zoom [Trigger]",invoke=function(message) if message:is_trigger() then pakettiDetectAndSelectSilenceInZoom() end end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Detect and Select Silence in Zoom",invoke=function()pakettiDetectAndSelectSilenceInZoom()end}
renoise.tool():add_menu_entry{name="--Sample Editor Ruler:Detect and Select Silence in Zoom",invoke=function()pakettiDetectAndSelectSilenceInZoom()end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Detect and Select Silence in Zoom",invoke=function()pakettiDetectAndSelectSilenceInZoom()end}

-------
function pakettiSaveSampleRange(format)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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

  if not canInsertInstrument() then
    renoise.app():show_status("Cannot create instrument: maximum of 255 instruments reached")
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Save Selected Sample Range .WAV",invoke=function() pakettiSaveSampleRange("wav") end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Save Selected Sample Range .FLAC",invoke=function() pakettiSaveSampleRange("flac") end}
renoise.tool():add_midi_mapping{name="Paketti:Save Selected Sample Range .WAV",invoke=function(message) if message:is_trigger() then pakettiSaveSampleRange("wav") end end}
renoise.tool():add_midi_mapping{name="Paketti:Save Selected Sample Range .FLAC",invoke=function(message) if message:is_trigger() then pakettiSaveSampleRange("flac") end end}
---
function pakettiMinimizeToLoopEnd()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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

  if not canInsertInstrument() then
    renoise.app():show_status("Cannot create instrument: maximum of 255 instruments reached")
    return
  end

  local temp_file_path = pakettiGetTempFilePath(".wav")
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end



renoise.tool():add_keybinding{name="Global:Paketti:FT2 Minimize Selected Sample",invoke=pakettiMinimizeToLoopEnd}
--------
-- Fast non-yielding version for direct calls (dialog buttons, etc.)
function PakettiTrimByHalfSampleDirect(sample)
  local sample_buffer = sample.sample_buffer
  if not sample_buffer.has_sample_data then
    return false, "No sample data"
  end
  
  local original_frames = sample_buffer.number_of_frames
  if original_frames <= 1 then
    return false, "Sample too short"
  end
  
  local half_frames = math.floor(original_frames / 2)
  if half_frames < 1 then
    return false, "Result would be too short"
  end
  
  -- Show what will be removed by highlighting the second half
  sample_buffer.selection_start = half_frames + 1
  sample_buffer.selection_end = original_frames
  
  -- Store original sample settings
  local original_settings = {
    name = sample.name,
    volume = sample.volume,
    panning = sample.panning,
    transpose = sample.transpose,
    fine_tune = sample.fine_tune,
    beat_sync_enabled = sample.beat_sync_enabled,
    beat_sync_lines = sample.beat_sync_lines,
    beat_sync_mode = sample.beat_sync_mode,
    loop_mode = sample.loop_mode,
    loop_release = sample.loop_release,
    oneshot = sample.oneshot,
    mute_group = sample.mute_group,
    new_note_action = sample.new_note_action,
    autoseek = sample.autoseek,
    autofade = sample.autofade,
    oversample_enabled = sample.oversample_enabled,
    interpolation_mode = sample.interpolation_mode,
    loop_start = sample.loop_start,
    loop_end = sample.loop_end
  }

  -- Create temporary instrument and sample
  local song = renoise.song()
  if not canInsertInstrument() then
    renoise.app():show_status("Cannot create instrument: maximum of 255 instruments reached")
    return
  end
  local temp_instrument = song:insert_instrument_at(song.selected_instrument_index + 1)
  local temp_sample = temp_instrument:insert_sample_at(1)

  -- Create new sample data with half the frames
  temp_sample.sample_buffer:create_sample_data(
    sample_buffer.sample_rate,
    sample_buffer.bit_depth,
    sample_buffer.number_of_channels,
    half_frames
  )
  temp_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy data directly (no yielding)
  local channels = sample_buffer.number_of_channels
  for c = 1, channels do
    for f = 1, half_frames do
      temp_sample.sample_buffer:set_sample_data(c, f, sample_buffer:sample_data(c, f))
    end
  end
  
  temp_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Save to temporary file
  local temp_file_path = pakettiGetTempFilePath(".wav")
  temp_sample.sample_buffer:save_as(temp_file_path, "wav")
  
  -- Load trimmed sample back
  sample.sample_buffer:load_from(temp_file_path)
  
  -- Restore all sample settings
  sample.name = original_settings.name
  sample.volume = original_settings.volume
  sample.panning = original_settings.panning
  sample.transpose = original_settings.transpose
  sample.fine_tune = original_settings.fine_tune
  sample.beat_sync_enabled = original_settings.beat_sync_enabled
  sample.beat_sync_lines = original_settings.beat_sync_lines
  sample.beat_sync_mode = original_settings.beat_sync_mode
  sample.oneshot = original_settings.oneshot
  sample.loop_release = original_settings.loop_release
  sample.mute_group = original_settings.mute_group
  sample.new_note_action = original_settings.new_note_action
  sample.autoseek = original_settings.autoseek
  sample.autofade = original_settings.autofade
  sample.oversample_enabled = original_settings.oversample_enabled
  sample.interpolation_mode = original_settings.interpolation_mode
  
  -- Restore and scale loop points
  local has_loop = (original_settings.loop_mode ~= renoise.Sample.LOOP_MODE_OFF)
  if has_loop then
    sample.loop_mode = original_settings.loop_mode
    local scale_factor = half_frames / original_frames
    local new_loop_start = math.max(1, math.floor(original_settings.loop_start * scale_factor))
    local new_loop_end = math.max(new_loop_start + 1, math.floor(original_settings.loop_end * scale_factor))
    new_loop_end = math.min(new_loop_end, half_frames)
    sample.loop_start = new_loop_start
    sample.loop_end = new_loop_end
  else
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    sample.loop_start = 1
    sample.loop_end = half_frames
  end
  
  -- Clean up
  song:delete_instrument_at(song.selected_instrument_index + 1)
  os.remove(temp_file_path)
  
  return true, original_frames, half_frames
end

-- Optimized coroutine function for trimming a single sample by half with ProcessSlicer
function PakettiTrimByHalfSampleCoroutine(sample, sample_index, total_samples)
  local CHUNK_SIZE = 50000  -- Process 50,000 frames at a time for optimal performance
  
  local sample_buffer = sample.sample_buffer
  if not sample_buffer.has_sample_data then
    return false, "No sample data"
  end
  
  local original_frames = sample_buffer.number_of_frames
  if original_frames <= 1 then
    return false, "Sample too short"
  end
  
  local half_frames = math.floor(original_frames / 2)
  if half_frames < 1 then
    return false, "Result would be too short"
  end
  
  -- Show what will be removed by highlighting the second half
  sample_buffer.selection_start = half_frames + 1
  sample_buffer.selection_end = original_frames
  
  -- Store original sample settings
  local original_settings = {
    name = sample.name,
    volume = sample.volume,
    panning = sample.panning,
    transpose = sample.transpose,
    fine_tune = sample.fine_tune,
    beat_sync_enabled = sample.beat_sync_enabled,
    beat_sync_lines = sample.beat_sync_lines,
    beat_sync_mode = sample.beat_sync_mode,
    loop_mode = sample.loop_mode,
    loop_release = sample.loop_release,
    oneshot = sample.oneshot,
    mute_group = sample.mute_group,
    new_note_action = sample.new_note_action,
    autoseek = sample.autoseek,
    autofade = sample.autofade,
    oversample_enabled = sample.oversample_enabled,
    interpolation_mode = sample.interpolation_mode,
    loop_start = sample.loop_start,
    loop_end = sample.loop_end
  }

  -- Create temporary instrument and sample
  local song = renoise.song()
  if not canInsertInstrument() then
    renoise.app():show_status("Cannot create instrument: maximum of 255 instruments reached")
    return
  end
  local temp_instrument = song:insert_instrument_at(song.selected_instrument_index + 1)
  local temp_sample = temp_instrument:insert_sample_at(1)

  -- Create new sample data with half the frames
  temp_sample.sample_buffer:create_sample_data(
    sample_buffer.sample_rate,
    sample_buffer.bit_depth,
    sample_buffer.number_of_channels,
    half_frames
  )
  temp_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy data in optimized chunks
  local channels = sample_buffer.number_of_channels
  local total_operations = channels * half_frames
  local processed = 0
  
  for c = 1, channels do
    local f = 1
    while f <= half_frames do
      local chunk_end = math.min(f + CHUNK_SIZE - 1, half_frames)
      
      -- Copy chunk of frames
      for frame = f, chunk_end do
        temp_sample.sample_buffer:set_sample_data(c, frame, sample_buffer:sample_data(c, frame))
        processed = processed + 1
      end
      
      -- Yield every chunk for progress updates
      if processed % CHUNK_SIZE == 0 then
        local progress = (processed / total_operations) * 100
        if total_samples > 1 then
          renoise.app():show_status(string.format("Trimming sample %d/%d... %.0f%%", 
            sample_index, total_samples, progress))
        else
          renoise.app():show_status(string.format("Trimming sample... %.0f%%", progress))
        end
        coroutine.yield()
      end
      
      f = chunk_end + 1
    end
  end
  
  temp_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Save to temporary file
  local temp_file_path = pakettiGetTempFilePath(".wav")
  temp_sample.sample_buffer:save_as(temp_file_path, "wav")
  
  -- Load trimmed sample back
  sample.sample_buffer:load_from(temp_file_path)
  
  -- Restore all sample settings
  sample.name = original_settings.name
  sample.volume = original_settings.volume
  sample.panning = original_settings.panning
  sample.transpose = original_settings.transpose
  sample.fine_tune = original_settings.fine_tune
  sample.beat_sync_enabled = original_settings.beat_sync_enabled
  sample.beat_sync_lines = original_settings.beat_sync_lines
  sample.beat_sync_mode = original_settings.beat_sync_mode
  sample.oneshot = original_settings.oneshot
  sample.loop_release = original_settings.loop_release
  sample.mute_group = original_settings.mute_group
  sample.new_note_action = original_settings.new_note_action
  sample.autoseek = original_settings.autoseek
  sample.autofade = original_settings.autofade
  sample.oversample_enabled = original_settings.oversample_enabled
  sample.interpolation_mode = original_settings.interpolation_mode
  
  -- Restore and scale loop points
  local has_loop = (original_settings.loop_mode ~= renoise.Sample.LOOP_MODE_OFF)
  if has_loop then
    sample.loop_mode = original_settings.loop_mode
    local scale_factor = half_frames / original_frames
    local new_loop_start = math.max(1, math.floor(original_settings.loop_start * scale_factor))
    local new_loop_end = math.max(new_loop_start + 1, math.floor(original_settings.loop_end * scale_factor))
    new_loop_end = math.min(new_loop_end, half_frames)
    sample.loop_start = new_loop_start
    sample.loop_end = new_loop_end
  else
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    sample.loop_start = 1
    sample.loop_end = half_frames
  end
  
  -- Clean up
  song:delete_instrument_at(song.selected_instrument_index + 1)
  os.remove(temp_file_path)
  
  return true, original_frames, half_frames
end

function PakettiTrimByHalfSelectedSample()
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local selected_sample = song.selected_sample
  
  if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  -- Switch to Sample Editor to show the visual feedback
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  
  -- Show the second half that will be cut by highlighting it
  local sample_buffer = selected_sample.sample_buffer
  local original_frames = sample_buffer.number_of_frames
  local half_frames = math.floor(original_frames / 2)
  
  sample_buffer.selection_start = half_frames + 1
  sample_buffer.selection_end = original_frames
  
  renoise.app():show_status("Second half of sample highlighted - will be removed...")
  
  local slicer = nil
  local dialog = nil
  local vb = nil
  
  local function process_func()
    local success, result1, result2 = PakettiTrimByHalfSampleCoroutine(selected_sample, 1, 1)
    
    if dialog and dialog.visible then
      dialog:close()
    end
    
    if success then
      renoise.app():show_status(string.format("Sample trimmed by half (%d -> %d frames)", result1, result2))
    else
      renoise.app():show_status("Could not trim sample: " .. result1)
    end
    
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  end
  
  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Trimming Sample by Half")
  slicer:start()
end

function PakettiTrimByHalfAllSamples()
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local selected_instrument = song.selected_instrument
  
  if not selected_instrument then
    renoise.app():show_status("No instrument selected")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  local samples = selected_instrument.samples
  local num_samples = #samples
  
  if num_samples < 1 then
    renoise.app():show_status("No samples in the selected instrument")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  -- Check if the first sample has slice markers
  if #samples[1].slice_markers > 0 then
    renoise.app():show_status("Cannot trim sliced instrument - please unslice first")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  local original_instrument_index = song.selected_instrument_index
  local slicer = nil
  local dialog = nil
  local vb = nil
  
  local function process_func()
    local trimmed_count = 0
    local skipped_count = 0
    
    for sample_index = 1, num_samples do
      -- Check if cancelled
      if slicer and slicer:was_cancelled() then
        if dialog and dialog.visible then
          dialog:close()
        end
        renoise.app():show_status("Trimming cancelled")
        PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
        return
      end
      
      -- Select the sample so user can see what's being processed
      song.selected_sample_index = sample_index
      
      local sample = samples[sample_index]
      local success, result1, result2 = PakettiTrimByHalfSampleCoroutine(sample, sample_index, num_samples)
      
      if success then
        trimmed_count = trimmed_count + 1
      else
        skipped_count = skipped_count + 1
      end
      
      coroutine.yield()
    end
    
    if dialog and dialog.visible then
      dialog:close()
    end
    
    local status_msg = "Trimmed " .. trimmed_count .. " sample(s) by half"
    if skipped_count > 0 then
      status_msg = status_msg .. " (skipped " .. skipped_count .. " sample(s))"
    end
    renoise.app():show_status(status_msg)
    
    song.selected_instrument_index = original_instrument_index
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  end
  
  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Trimming All Samples by Half")
  slicer:start()
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Trim by Half (Selected Sample)",invoke=function() PakettiTrimByHalfSelectedSample() end}
renoise.tool():add_keybinding{name="Global:Paketti:Trim by Half (All Samples in Instrument)",invoke=function() PakettiTrimByHalfAllSamples() end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Process:Trim by Half (Selected Sample)",invoke=function() PakettiTrimByHalfSelectedSample() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Process:Trim by Half (All Samples in Instrument)",invoke=function() PakettiTrimByHalfAllSamples() end}


--------
local previous_value = nil
local rotation_amount = 5  -- You can set this to any desired default value

-- Function to rotate sample buffer content based on knob movement
function rotate_sample_buffer(midi_message, rotation_amount)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Left/Right Fine x[Knob]",invoke=function(midi_message) rotate_sample_buffer(midi_message, rotation_amount) end}
--
local coarse_rotation_amount = 1000  -- Set Coarse rotation amount to 1000
local previous_value_coarse = nil

-- Function to rotate sample buffer content based on coarse knob movement
function rotate_sample_buffer_coarse(midi_message, rotation_amount)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()

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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Left/Right Coarse x[Knob]",invoke=function(midi_message) rotate_sample_buffer_coarse(midi_message, coarse_rotation_amount) end}

-- Function to rotate sample buffer content forward or backward by a specified amount
function rotate_sample_buffer_fixed(rotation_amount)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
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
-- Helper function for log10 (Lua 5.1 doesn't have it)
local function log10(x)
  return math.log(x) / math.log(10)
end

-- Coroutine function for normalization with ProcessSlicer
function PakettiNormalizeSampleCoroutine(sample, normalize_reason)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local buffer = sample.sample_buffer
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  local YIELD_EVERY = 100000 -- Yield every 100,000 frames for even better performance
  
  print("DEBUG: Finding peak amplitude...")
  
  -- Step 1: Find peak value across all channels (optimized)
  local peak = 0
  local processed_frames = 0
  local abs = math.abs  -- Local reference for faster access
  
  -- Process all channels, but with early termination and optimizations
  local peak_found = false
  for c = 1, channels do
    if peak_found then break end
    for f = 1, frames do
      local abs_value = abs(buffer:sample_data(c, f))
      if abs_value > peak then
        peak = abs_value
        -- Early termination: if we find perfect peak, no point continuing
        if peak >= 0.999 then
          processed_frames = frames * channels  -- Set to max for progress calculation
          print("DEBUG: Found perfect peak (≥0.999), early termination")
          peak_found = true
          break
        end
      end
      
      processed_frames = processed_frames + 1
      
      -- Yield less frequently for better performance
      if processed_frames % YIELD_EVERY == 0 then
        local progress = (processed_frames / (frames * channels)) * 50 -- First half of progress
        -- Only print every 10% to avoid spam
        if math.floor(progress / 10) > math.floor((progress - 0.1) / 10) then
          print(string.format("DEBUG: Finding peak amplitude... %.0f%%", progress))
        end
        coroutine.yield()
      end
    end
  end
  
  print(string.format("DEBUG: Peak found = %.6f for %s '%s'", peak, normalize_reason, sample.name))
  
  -- Check if we should normalize (optimized thresholds)
  if peak <= 0 then
    print(string.format("DEBUG: Skipping normalization - %s '%s' is silent (peak = %.6f)", normalize_reason, sample.name, peak))
    return false
  end
  
  -- More precise threshold for already-normalized samples
  if peak >= 0.995 then
    print(string.format("DEBUG: Skipping normalization - %s '%s' already at peak (%.6f)", normalize_reason, sample.name, peak))
    renoise.app():show_status(string.format("%s '%s' already at peak level - no normalization needed", normalize_reason, sample.name))
    return false
  end
  
  -- Skip near-silent samples that would need extreme amplification (>60dB gain)
  if peak < 0.001 then
    local potential_gain = 20 * log10(1.0 / peak)
    print(string.format("DEBUG: Skipping normalization - %s '%s' too quiet (peak: %.6f, would amplify by %.1f dB)", 
                       normalize_reason, sample.name, peak, potential_gain))
    renoise.app():show_status(string.format("Skipped normalizing very quiet %s (would amplify by %.1f dB)", sample.name, potential_gain))
    return false
  end
  
  -- Step 2: Apply normalization
  local scale = 1.0 / peak
  local db_increase = 20 * log10(scale)
  
  print(string.format("DEBUG: Normalizing %s '%s' - Peak: %.6f, Scale: %.6f, dB increase: %.2f", 
                     normalize_reason, sample.name, peak, scale, db_increase))
  
  print("DEBUG: Applying normalization...")
  
  buffer:prepare_sample_data_changes()
  processed_frames = 0
  
  -- Process in channel-major order for better performance
  for c = 1, channels do
    for f = 1, frames do
      local sample_value = buffer:sample_data(c, f)
      buffer:set_sample_data(c, f, sample_value * scale)
      
      processed_frames = processed_frames + 1
      
      -- Yield less frequently during normalization (it's typically faster than peak detection)
      if processed_frames % YIELD_EVERY == 0 then
        local progress = 50 + ((processed_frames / (frames * channels)) * 50) -- Second half of progress
        -- Only print every 10% to avoid spam
        if math.floor(progress / 10) > math.floor((progress - 0.1) / 10) then
          print(string.format("DEBUG: Applying normalization... %.0f%%", progress))
        end
        coroutine.yield()
      end
    end
  end
  
  buffer:finalize_sample_data_changes()
  
  -- Step 3: Verify normalization worked (optimized sampling approach)
  print("DEBUG: Verifying normalization...")
  
  -- Sample-based verification (much faster, still accurate for verification purposes)
  local new_peak = 0
  local sample_step = math.max(1, math.floor(frames / 1000)) -- Sample every ~1000th of the audio
  
  local verification_done = false
  for c = 1, channels do
    if verification_done then break end
    for f = 1, frames, sample_step do
      local abs_value = abs(buffer:sample_data(c, f))
      if abs_value > new_peak then
        new_peak = abs_value
        -- Early exit if we find perfect normalization
        if new_peak >= 0.999 then
          verification_done = true
          break
        end
      end
    end
  end
  
  print(string.format("DEBUG: Normalization complete - Old peak: %.6f, New peak: %.6f", peak, new_peak))
  print(string.format("Normalized %s: %s (%.2f dB increase)", normalize_reason, sample.name, db_increase))
  renoise.app():show_status(string.format("Normalized %s: %s (%.2f dB increase)", normalize_reason, sample.name, db_increase))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  
  -- Normalization complete - coroutine will end and ProcessSlicer will detect completion
  return true
end

-- Helper function to apply Paketti Loader settings to a sample
function PakettiInjectApplyLoaderSettings(sample)
  if not sample or not preferences then return end
  
  -- Debug: Which sample are we working on?
  local song = renoise.song()
  local current_instr = song.selected_instrument_index
  local current_sample = song.selected_sample_index
  print(string.format("DEBUG: PakettiInjectApplyLoaderSettings called for '%s' (currently selected: instr %d, sample %d)", 
                     sample.name, current_instr, current_sample))
  
  -- Apply Paketti Loader preferences to the sample
  sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = preferences.pakettiLoaderLoopExit.value
  
  -- Debug preference values
  print(string.format("DEBUG: Normalization preferences - Regular: %s, Large: %s", 
                     tostring(preferences.pakettiLoaderNormalizeSamples.value), 
                     tostring(preferences.pakettiLoaderNormalizeLargeSamples.value)))
  
  -- Check if normalization is enabled and apply appropriately
  if sample.sample_buffer.has_sample_data then
    local buffer = sample.sample_buffer
    local frames = buffer.number_of_frames
    local channels = buffer.number_of_channels
    local bytes_per_sample = buffer.bit_depth / 8
    local total_bytes = frames * channels * bytes_per_sample
    local size_threshold = 10 * 1024 * 1024  -- 10MB in bytes
    local is_large_sample = total_bytes >= size_threshold
    
    local should_normalize = false
    local normalize_reason = ""
    
    -- Check large sample normalization first (higher priority)
    if preferences.pakettiLoaderNormalizeLargeSamples.value and is_large_sample then
      should_normalize = true
      local size_mb = math.floor(total_bytes / (1024 * 1024) * 10) / 10
      normalize_reason = string.format("large sample (%s MB)", size_mb)
      print(string.format("DEBUG: Will normalize as large sample (%.1f MB)", size_mb))
    -- Check regular normalization (only if not handled by large sample setting)
    elseif preferences.pakettiLoaderNormalizeSamples.value and not is_large_sample then
      should_normalize = true
      normalize_reason = "sample"
      print(string.format("DEBUG: Will normalize as regular sample (%.1f MB)", total_bytes / (1024 * 1024)))
    else
      local reason = "unknown"
      if is_large_sample and not preferences.pakettiLoaderNormalizeLargeSamples.value then
        reason = "large sample but large sample normalization disabled"
      elseif not is_large_sample and not preferences.pakettiLoaderNormalizeSamples.value then
        reason = "regular sample but sample normalization disabled"
      end
      print(string.format("DEBUG: Will NOT normalize - %s", reason))
    end
    
    if should_normalize then
      -- Use ProcessSlicer for normalization with progress dialog
      local dialog_title = string.format("Normalizing %s '%s'", normalize_reason, sample.name)
      
      -- Create ProcessSlicer with our coroutine function
      local slicer = ProcessSlicer(function()
        PakettiNormalizeSampleCoroutine(sample, normalize_reason)
      end)
      
      -- Create progress dialog 
      local dialog, vb = slicer:create_dialog(dialog_title)
      
      -- Start the normalization process
      slicer:start()
      
      -- Add a timer to check for completion and close dialog
      local completion_timer_func
      completion_timer_func = function()
        if not slicer:running() then
          -- Process completed, clean up
          renoise.tool():remove_timer(completion_timer_func)
          if dialog and dialog.visible then
            dialog:close()
          end
          if slicer:was_cancelled() then
            renoise.app():show_status("Normalization cancelled")
          end
        end
      end
      renoise.tool():add_timer(completion_timer_func, 100)  -- Check every 100ms
      
      print(string.format("DEBUG: Started ProcessSlicer normalization for %s '%s'", normalize_reason, sample.name))
    end
  end
  
  print(string.format("Applied Paketti loader settings to sample: %s", sample.name))
end

--------------
function PakettiInjectDefaultXRNI()
  local instVol = renoise.song().selected_instrument.volume
  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local original_instrument = song.selected_instrument

  -- Store the original selected phrase index BEFORE we do anything
  local original_phrase_index = renoise.song().selected_phrase_index
  print(string.format("\nStoring original selected_phrase_index: %d", original_phrase_index))

  if not original_instrument or #original_instrument.samples == 0 then
    renoise.app():show_status("No instrument or samples selected, nothing to Pakettify.")
    return
  end

  -- Check preference to determine whether to replace current instrument or create new one
  if preferences.pakettifyReplaceInstrument.value then
    -- REPLACE CURRENT INSTRUMENT MODE
    -- Store original instrument name
    local original_name = original_instrument.name

    -- Store original samples data - PROPERLY copy the data, not just references
    local original_samples_data = {}
    for i = 1, #original_instrument.samples do
      local from_sample = original_instrument.samples[i]
      local sample_data = {}
      
      -- Store slice markers
      sample_data.slice_markers = {}
      for _, slice_marker in ipairs(from_sample.slice_markers) do
        table.insert(sample_data.slice_markers, slice_marker)
      end
      
      -- Store sample buffer data if it exists
      if from_sample.sample_buffer.has_sample_data then
        local from_buffer = from_sample.sample_buffer
        sample_data.buffer_data = {
          sample_rate = from_buffer.sample_rate,
          bit_depth = from_buffer.bit_depth,
          number_of_channels = from_buffer.number_of_channels,
          number_of_frames = from_buffer.number_of_frames,
          data = {}
        }
        
        -- Copy all audio data
        for channel = 1, from_buffer.number_of_channels do
          sample_data.buffer_data.data[channel] = {}
          for frame = 1, from_buffer.number_of_frames do
            sample_data.buffer_data.data[channel][frame] = from_buffer:sample_data(channel, frame)
          end
        end
      end
      
      -- Store other sample properties
      sample_data.name = from_sample.name
      sample_data.transpose = from_sample.transpose
      sample_data.fine_tune = from_sample.fine_tune
      sample_data.volume = from_sample.volume
      sample_data.panning = from_sample.panning
      sample_data.beat_sync_enabled = from_sample.beat_sync_enabled
      sample_data.beat_sync_lines = from_sample.beat_sync_lines
      sample_data.beat_sync_mode = from_sample.beat_sync_mode
      sample_data.autoseek = from_sample.autoseek
      sample_data.autofade = from_sample.autofade
      sample_data.loop_mode = from_sample.loop_mode
      sample_data.loop_start = from_sample.loop_start
      sample_data.loop_end = from_sample.loop_end
      sample_data.loop_release = from_sample.loop_release
      sample_data.new_note_action = from_sample.new_note_action
      sample_data.oneshot = from_sample.oneshot
      sample_data.mute_group = from_sample.mute_group
      sample_data.interpolation_mode = from_sample.interpolation_mode
      sample_data.oversample_enabled = from_sample.oversample_enabled
      
      -- Store sample mapping properties
      sample_data.sample_mapping = {
        base_note = from_sample.sample_mapping.base_note,
        note_range = {from_sample.sample_mapping.note_range[1], from_sample.sample_mapping.note_range[2]},
        velocity_range = {from_sample.sample_mapping.velocity_range[1], from_sample.sample_mapping.velocity_range[2]},
        map_key_to_pitch = from_sample.sample_mapping.map_key_to_pitch,
        map_velocity_to_volume = from_sample.sample_mapping.map_velocity_to_volume
      }
      
      table.insert(original_samples_data, sample_data)
    end

    -- Store original phrases data
    local original_phrases_data = {}
    for i = 1, #original_instrument.phrases do
      table.insert(original_phrases_data, original_instrument.phrases[i])
    end

    -- Now load the XRNI template into the CURRENT instrument (this will overwrite it)
    pakettiPreferencesDefaultInstrumentLoader()
    
    -- Refresh our reference to the current instrument
    local current_instrument = renoise.song().selected_instrument

    -- Restore the original samples
    for i = 1, #original_samples_data do
      local sample_data = original_samples_data[i]
      
      -- Insert sample slot if needed
      if i > #current_instrument.samples then
        current_instrument:insert_sample_at(i)
      end
      
      local to_sample = current_instrument.samples[i]
      
      -- Restore sample buffer data if it was stored
      if sample_data.buffer_data then
        local buffer_data = sample_data.buffer_data
        to_sample.sample_buffer:create_sample_data(
          buffer_data.sample_rate,
          buffer_data.bit_depth,
          buffer_data.number_of_channels,
          buffer_data.number_of_frames
        )
        
        to_sample.sample_buffer:prepare_sample_data_changes()
        
        -- Restore all audio data
        for channel = 1, buffer_data.number_of_channels do
          for frame = 1, buffer_data.number_of_frames do
            to_sample.sample_buffer:set_sample_data(channel, frame, buffer_data.data[channel][frame])
          end
        end
        
        to_sample.sample_buffer:finalize_sample_data_changes()
        print("Sample buffer data restored for sample #" .. i)
      end
      
      -- Restore sample properties
      to_sample.name = sample_data.name
      to_sample.transpose = sample_data.transpose
      to_sample.fine_tune = sample_data.fine_tune
      to_sample.volume = sample_data.volume
      to_sample.panning = sample_data.panning
      to_sample.beat_sync_enabled = sample_data.beat_sync_enabled
      to_sample.beat_sync_lines = sample_data.beat_sync_lines
      to_sample.beat_sync_mode = sample_data.beat_sync_mode
      to_sample.autoseek = sample_data.autoseek
      to_sample.autofade = sample_data.autofade
      to_sample.loop_mode = sample_data.loop_mode
      to_sample.loop_start = sample_data.loop_start
      to_sample.loop_end = sample_data.loop_end
      to_sample.loop_release = sample_data.loop_release
      to_sample.new_note_action = sample_data.new_note_action
      to_sample.oneshot = sample_data.oneshot
      to_sample.mute_group = sample_data.mute_group
      to_sample.interpolation_mode = sample_data.interpolation_mode
      to_sample.oversample_enabled = sample_data.oversample_enabled
      to_sample.device_chain_index = 1
      
      -- Restore sample mapping properties
      if sample_data.sample_mapping then
        to_sample.sample_mapping.base_note = sample_data.sample_mapping.base_note
        to_sample.sample_mapping.note_range = sample_data.sample_mapping.note_range
        to_sample.sample_mapping.velocity_range = sample_data.sample_mapping.velocity_range
        to_sample.sample_mapping.map_key_to_pitch = sample_data.sample_mapping.map_key_to_pitch
        to_sample.sample_mapping.map_velocity_to_volume = sample_data.sample_mapping.map_velocity_to_volume
        print("Sample mapping properties restored for sample #" .. i)
      end
      
      -- Restore slice markers if any
      if #sample_data.slice_markers > 0 then
        -- Clear existing slice markers (no clear_slice_markers function exists!)
        print("Clearing " .. #to_sample.slice_markers .. " existing slice markers")
        while #to_sample.slice_markers > 0 do
          local marker_pos = to_sample.slice_markers[1]
          print("Deleting slice marker at position: " .. marker_pos)
          to_sample:delete_slice_marker(marker_pos)
        end
        
        -- Insert new slice markers
        for _, slice_marker in ipairs(sample_data.slice_markers) do
          to_sample:insert_slice_marker(slice_marker)
        end
        print("Slices restored for sample #" .. i)
      end
      
      -- Apply Paketti Loader settings to the restored sample
      PakettiInjectApplyLoaderSettings(to_sample)
      
      print("Sample properties restored for sample #" .. i)
    end

    -- Restore original phrases
    if #original_phrases_data > 0 then
      print(string.format("\nRestoring %d phrases to current instrument", #original_phrases_data))
      for i = 1, #original_phrases_data do
        if i > #current_instrument.phrases then
          current_instrument:insert_phrase_at(i)
        end
        current_instrument.phrases[i]:copy_from(original_phrases_data[i])
        print(string.format("Restored phrase %d: '%s' (%d lines)", 
          i, original_phrases_data[i].name, #original_phrases_data[i].lines))
      end
    end

    -- Copy instrument-level properties
    current_instrument.transpose = original_data.transpose
    current_instrument.volume = original_data.volume
    
    -- Restore original name with "(Pakettified)" suffix
    current_instrument.name = original_name .. " (Pakettified)"
    print("Instrument renamed to: " .. current_instrument.name)
    print("Debug: original_name was: " .. original_name)
    print("Debug: Restored instrument transpose: " .. original_data.transpose)

    -- Apply modulation settings using helper function
    PakettiApplyLoaderModulationSettings(current_instrument, "PakettiInjectDefaultXRNI (Replace Mode)")

    -- Remove the placeholder sample from the last slot if it exists
    local num_samples = #current_instrument.samples
    if num_samples > 0 and current_instrument.samples[num_samples].name == "Placeholder sample" then
      current_instrument:delete_sample_at(num_samples)
      print("Removed placeholder sample from last slot")
    end

    current_instrument.sample_modulation_sets[1].name = "Pitchbend"
    current_instrument.volume = instVol

  else
    -- CREATE NEW INSTRUMENT MODE (original behavior)
    local new_instrument_index = selected_instrument_index + 1
    if not safeInsertInstrumentAt(song, new_instrument_index) then return end
    song.selected_instrument_index = new_instrument_index
    local new_instrument = song.selected_instrument

    pakettiPreferencesDefaultInstrumentLoader()
    new_instrument = renoise.song().selected_instrument
    print("Debug: Instrument name after loading preset: " .. new_instrument.name)

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
        -- Ensure the new instrument has enough sample slots
        if i > #new_instrument.samples then
          new_instrument:insert_sample_at(i)
        end
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
        -- Clear existing slice markers (no clear_slice_markers function exists!)
        print("Clearing " .. #to_sample.slice_markers .. " existing slice markers from destination sample")
        while #to_sample.slice_markers > 0 do
          local marker_pos = to_sample.slice_markers[1]
          print("Deleting slice marker at position: " .. marker_pos)
          to_sample:delete_slice_marker(marker_pos)
        end
        
        -- Insert slice markers from source sample
        for _, slice_marker in ipairs(from_sample.slice_markers) do
          to_sample:insert_slice_marker(slice_marker)
        end

        -- Copy basic sample properties for sliced samples (no sample mappings!)
        to_sample.name = from_sample.name
        to_sample.transpose = from_sample.transpose
        to_sample.fine_tune = from_sample.fine_tune
        to_sample.volume = from_sample.volume
        to_sample.panning = from_sample.panning
        to_sample.beat_sync_enabled = from_sample.beat_sync_enabled
        to_sample.beat_sync_lines = from_sample.beat_sync_lines
        to_sample.beat_sync_mode = from_sample.beat_sync_mode
        to_sample.autoseek = from_sample.autoseek
        to_sample.autofade = from_sample.autofade
        to_sample.loop_mode = from_sample.loop_mode
        -- Only copy loop indices if loop mode is not OFF and source has valid sample data
        if from_sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and from_sample.sample_buffer.has_sample_data then
          to_sample.loop_start = from_sample.loop_start
          to_sample.loop_end = from_sample.loop_end
        end
        to_sample.loop_release = from_sample.loop_release
        to_sample.new_note_action = from_sample.new_note_action
        to_sample.oneshot = from_sample.oneshot
        to_sample.mute_group = from_sample.mute_group
        to_sample.interpolation_mode = from_sample.interpolation_mode
        to_sample.oversample_enabled = from_sample.oversample_enabled
        to_sample.device_chain_index = 1

        -- Apply Paketti Loader settings to the main sample
        PakettiInjectApplyLoaderSettings(to_sample)
        
        print("Slices copied for sample #" .. i .. " - name: " .. to_sample.name)
        
        -- Now copy properties for each slice alias (samples 2, 3, 4, etc.)
        for slice_idx = 2, #original_instrument.samples do
          local from_slice = original_instrument.samples[slice_idx]
          -- Ensure the new instrument has enough sample slots for slices
          if slice_idx > #new_instrument.samples then
            new_instrument:insert_sample_at(slice_idx)
          end
          local to_slice = new_instrument.samples[slice_idx]
          
          if to_slice then
            -- Copy ALL slice-specific properties (these are NOT read-only)
            to_slice.transpose = from_slice.transpose
            to_slice.fine_tune = from_slice.fine_tune
            to_slice.volume = from_slice.volume
            to_slice.panning = from_slice.panning
            to_slice.beat_sync_enabled = from_slice.beat_sync_enabled
            to_slice.beat_sync_lines = from_slice.beat_sync_lines
            to_slice.beat_sync_mode = from_slice.beat_sync_mode
            to_slice.autoseek = from_slice.autoseek
            to_slice.autofade = from_slice.autofade
            to_slice.loop_mode = from_slice.loop_mode
            -- Only copy loop indices if loop mode is not OFF and source has sample data
            if from_slice.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and from_slice.sample_buffer and from_slice.sample_buffer.has_sample_data then
              to_slice.loop_start = from_slice.loop_start
              to_slice.loop_end = from_slice.loop_end
            end
            to_slice.loop_release = from_slice.loop_release
            to_slice.new_note_action = from_slice.new_note_action
            to_slice.oneshot = from_slice.oneshot
            to_slice.mute_group = from_slice.mute_group
            to_slice.interpolation_mode = from_slice.interpolation_mode
            to_slice.oversample_enabled = from_slice.oversample_enabled
            
            -- Apply Paketti Loader settings to each slice
            PakettiInjectApplyLoaderSettings(to_slice)
            
            print("Copied ALL properties for slice #" .. slice_idx .. " (transpose: " .. from_slice.transpose .. ", fine_tune: " .. from_slice.fine_tune .. ", loop_mode: " .. from_slice.loop_mode .. ", autofade: " .. tostring(from_slice.autofade) .. ")")
          end
        end
        
        -- STOP HERE - we've processed the master sample and all its slices
        break
      else
        -- Copy sample properties for non-sliced samples
        -- Ensure the new instrument has enough sample slots
        if i > #new_instrument.samples then
          new_instrument:insert_sample_at(i)
        end
        local to_sample = new_instrument:sample(i)
        to_sample:copy_from(from_sample)
        to_sample.device_chain_index = 1 
        
        -- Apply Paketti Loader settings to the copied sample
        PakettiInjectApplyLoaderSettings(to_sample)
        
        print("Sample properties copied from sample #" .. i .. " of instrument index " .. selected_instrument_index)
      end
    end

    -- Apply modulation settings using helper function
    PakettiApplyLoaderModulationSettings(new_instrument, "PakettiInjectDefaultXRNI (Create New Mode)")

    new_instrument.sample_modulation_sets[1].name = "Pitchbend"
    new_instrument.volume = instVol
    
    -- Remove the placeholder sample from the last slot
    local num_samples = #new_instrument.samples
    if num_samples > 0 and new_instrument.samples[num_samples].name == "Placeholder sample" then
      new_instrument:delete_sample_at(num_samples)
      print("Removed placeholder sample from last slot")
    end

    -- Copy instrument-level properties
    new_instrument.transpose = original_instrument.transpose
    new_instrument.volume = original_instrument.volume
    
    -- Set instrument name LAST to ensure it's not overridden
    new_instrument.name = original_instrument.name .. " (Pakettified)"
    print("New Instrument renamed to: " .. new_instrument.name)
    print("Debug: original_instrument.name was: " .. original_instrument.name)
    print("Debug: Copied instrument transpose: " .. original_instrument.transpose)
    
    -- UPDATE ALL PATTERN NOTES TO REFERENCE NEW INSTRUMENT
    print("Updating all pattern notes from instrument " .. selected_instrument_index .. " to " .. new_instrument_index)
    local notes_updated = 0
    local old_instr_value = selected_instrument_index - 1  -- Convert to 0-based for pattern data
    local new_instr_value = new_instrument_index - 1      -- Convert to 0-based for pattern data
    
    for pattern_index = 1, #song.patterns do
      local pattern = song.patterns[pattern_index]
      for track_index = 1, #pattern.tracks do
        local track = pattern.tracks[track_index]
        for line_index = 1, #track.lines do
          local line = track.lines[line_index]
          -- Check all note columns
          for note_column_index = 1, #line.note_columns do
            local note_column = line.note_columns[note_column_index]
            if not note_column.is_empty and note_column.instrument_value == old_instr_value then
              note_column.instrument_value = new_instr_value
              notes_updated = notes_updated + 1
            end
          end
          -- Check all effect columns for instrument effect commands (if any)
          for effect_column_index = 1, #line.effect_columns do
            local effect_column = line.effect_columns[effect_column_index]
            if not effect_column.is_empty then
              -- Check for instrument effect commands like Ixx (instrument change)
              if effect_column.number_string == "0I" and effect_column.amount_value == old_instr_value then
                effect_column.amount_value = new_instr_value
                notes_updated = notes_updated + 1
              end
            end
          end
        end
      end
      
      -- Note: The above pattern loop already processes all pattern tracks and their note columns,
      -- so we don't need a separate loop here. PatternTrack objects don't have a 'type' property.
    end
    
    -- Update phrase patterns within instruments
    for instr_index = 1, #song.instruments do
      local instrument = song.instruments[instr_index]
      for phrase_index = 1, #instrument.phrases do
        local phrase = instrument.phrases[phrase_index]
        for line_index = 1, #phrase.lines do
          local line = phrase.lines[line_index]
          for note_column_index = 1, #line.note_columns do
            local note_column = line.note_columns[note_column_index]
            if not note_column.is_empty and note_column.instrument_value == old_instr_value then
              note_column.instrument_value = new_instr_value
              notes_updated = notes_updated + 1
            end
          end
          for effect_column_index = 1, #line.effect_columns do
            local effect_column = line.effect_columns[effect_column_index]
            if not effect_column.is_empty then
              if effect_column.number_string == "0I" and effect_column.amount_value == old_instr_value then
                effect_column.amount_value = new_instr_value
                notes_updated = notes_updated + 1
              end
            end
          end
        end
      end
    end
    
    if notes_updated > 0 then
      print("Successfully updated " .. notes_updated .. " note references from old instrument to new pakettified instrument")
      renoise.app():show_status("Pakettified instrument created. Updated " .. notes_updated .. " note references.")
    else
      print("No note references found to update")
      renoise.app():show_status("Pakettified instrument created (no existing notes to update)")
    end
  end

  -- At the end, before returning focus:
  renoise.song().selected_phrase_index = original_phrase_index
  print(string.format("Restored selected_phrase_index to: %d", renoise.song().selected_phrase_index))

  -- Return focus to the Instrument Sample Editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Pakettify Current Instrument",invoke=function() PakettiInjectDefaultXRNI() end}


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


-------------------
function BeatsyncFromSelection()
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
BeatsyncFromSelection() end}
--
--
function PakettiFlipSample(fraction)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local sample = song.selected_sample
  
  -- Check if sample exists before accessing buffer
  if not sample then
    renoise.app():show_status("No sample selected, doing nothing.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  local buffer = sample.sample_buffer
  
  -- Check if buffer exists
  if not buffer then
    renoise.app():show_status("No sample buffer available, doing nothing.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
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
        if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then return end
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

    if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then return nil end
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
    if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then return nil end
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1

    -- Run the Paketti default instrument setup function
    pakettiPreferencesDefaultInstrumentLoader()  -- Assuming this is a custom function you have defined

    -- Get the selected instrument to load all samples into
    local instrument = renoise.song().selected_instrument
    instrument:delete_sample_at(1)  -- Clear any default sample slot

    -- Load the specified number of samples into new slots within the same instrument
    local first_sample_name = nil
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
        
        -- Store the first sample name for single sample instruments
        if i == 1 then
            first_sample_name = file_name
        end
        
        renoise.app():show_status("Loaded file into sample slot: " .. selected_file)
    end
    
    -- Set instrument name based on number of samples
    if num_samples == 1 then
        renoise.song().selected_instrument.name = first_sample_name
    else
        renoise.song().selected_instrument.name = string.format("%02d Randomized Samples", num_samples)
    end
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

    if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then
      renoise.app():show_status("Cannot create more instruments: maximum of 255 instruments reached (loaded " .. (i-1) .. " of " .. num_samples .. ")")
      break
    end
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

-- Append random samples to currently selected instrument (doesn't create new instruments)
function PakettiAppendRandomSamplesToInstrument(folder_path, num_samples)
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  if not folder_path or folder_path == "" then
    renoise.app():show_status("No folder path specified")
    return
  end
  
  local wav_files = PakettiGetFilesInDirectory(folder_path)
  
  if #wav_files == 0 then
    renoise.app():show_status("No audio files found in the selected folder")
    return
  end
  
  math.randomseed(os.time())
  math.random(); math.random(); math.random()
  
  local starting_sample_count = #instrument.samples
  local loaded_count = 0
  
  for i = 1, num_samples do
    local random_index = math.random(1, #wav_files)
    local selected_file = wav_files[random_index]
    local file_name = selected_file:match("([^/\\]+)%.%w+$")
    
    local success = pcall(function()
      local sample = instrument:insert_sample_at(#instrument.samples + 1)
      sample.sample_buffer:load_from(selected_file)
      sample.name = file_name
      loaded_count = loaded_count + 1
    end)
    
    if not success then
      print("Failed to load file: " .. selected_file)
    end
  end
  
  renoise.app():show_status(string.format("Appended %d random samples to instrument (total: %d → %d)", 
    loaded_count, starting_sample_count, #instrument.samples))
end

-- Main dialog function
local dialog = nil  -- Add proper dialog variable declaration for User-Defined Samples Dialog

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
      vb:text{ text="Folder " .. formatDigits(2,i),style="strong",font="bold"},
      browse_button,
      textfield,
      vb:button{text="Open Path",notifier=function()
        local sanitized_path = sanitizeFolderPath(textfield.text)
        if sanitized_path then
          renoise.app():open_path(sanitized_path)
        else
          renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
        end
      end},
      vb:text{ text="Random", style="strong", font="bold" },
      vb:button{text="Drumkit", notifier=function() 
        local sanitized_path = sanitizeFolderPath(textfield.text)
        if sanitized_path then
          loadRandomDrumkitSamples(120, sanitized_path) 
        else
          renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
        end
      end},
      vb:button{
        text="01",
        notifier=function()
          local sanitized_path = sanitizeFolderPath(textfield.text)
          if sanitized_path then
            loadRandomSamplesIntoSingleInstrument(1, sanitized_path)
          else
            renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
          end
        end
      },
      vb:button{
        text="12",
        notifier=function()
          local sanitized_path = sanitizeFolderPath(textfield.text)
          if sanitized_path then
            loadRandomSamplesIntoSingleInstrument(12, sanitized_path)
          else
            renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
          end
        end
      },
      vb:button{
        text="32",
        notifier=function()
          local sanitized_path = sanitizeFolderPath(textfield.text)
          if sanitized_path then
            loadRandomSample(32, sanitized_path)
          else
            renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
          end
        end
      },
      vb:text{ text="Append", style="strong", font="bold" },
      vb:button{
        text="01",
        notifier=function()
          local sanitized_path = sanitizeFolderPath(textfield.text)
          if sanitized_path then
            PakettiAppendRandomSamplesToInstrument(sanitized_path, 1)
          else
            renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
          end
        end
      },
      vb:button{
        text="04",
        notifier=function()
          local sanitized_path = sanitizeFolderPath(textfield.text)
          if sanitized_path then
            PakettiAppendRandomSamplesToInstrument(sanitized_path, 4)
          else
            renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
          end
        end
      },
      vb:button{
        text="12",
        notifier=function()
          local sanitized_path = sanitizeFolderPath(textfield.text)
          if sanitized_path then
            PakettiAppendRandomSamplesToInstrument(sanitized_path, 12)
          else
            renoise.app():show_warning("The folder path appears to be invalid or inaccessible.")
          end
        end
      }
    }

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

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti User-Defined Sample Folders", rows, keyhandler)
end




renoise.tool():add_keybinding{name="Global:Paketti:User-Defined Sample Folders...",invoke=pakettiUserDefinedSamplesDialog}
-- Function to get folder path from preferences
function getFolderPath(folderNum)
  local preferences = renoise.tool().preferences
  return preferences["UserDefinedSampleFolders" .. string.format("%02d", folderNum)].value
end

-- Function to create actions for a specific folder
local function createFolderActions(folderNum)
  local folderName = string.format("Folder %02d", folderNum)
  
  -- Open Folder
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti:Quick Sample Folders:%s:Open Folder", folderName), invoke=function() 
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():open_path(folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random Drumkit
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti:Quick Sample Folders:%s:Random Drumkit", folderName), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random Drumkit from " .. folderPath)
      loadRandomDrumkitSamples(120, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random 01
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti:Quick Sample Folders:%s:Random 01", folderName), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 01 sample from " .. folderPath)
      loadRandomSamplesIntoSingleInstrument(1, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random 01 to Pattern
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti:Quick Sample Folders:%s:Random 01 Sample to Pattern", folderName), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 01 sample to pattern from " .. folderPath)
      loadRandomSampleToPattern(folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random 12
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti:Quick Sample Folders:%s:Random 12", folderName), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 12 samples from " .. folderPath)
      loadRandomSamplesIntoSingleInstrument(12, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  -- Random 32
  renoise.tool():add_menu_entry{name=string.format("Main Menu:Tools:Paketti:Quick Sample Folders:%s:Random 32", folderName), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 32 instruments from " .. folderPath)
      loadRandomSample(32, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  

  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Open Folder", folderNum), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():open_path(folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random Drumkit", folderNum), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random Drumkit from " .. folderPath)
      loadRandomDrumkitSamples(120, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random 01", folderNum), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 01 samples from " .. folderPath)
      loadRandomSamplesIntoSingleInstrument(1, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random 01 Sample to Pattern", folderNum), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 01 sample to pattern from " .. folderPath)
      loadRandomSampleToPattern(folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}

  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random 12", folderNum), invoke=function()
    local folderPath = getFolderPath(folderNum)
    if folderPath and folderPath ~= "" then
      renoise.app():show_status("Loading Random 12 samples from " .. folderPath)
      loadRandomSamplesIntoSingleInstrument(12, folderPath)
    else
      renoise.app():show_status(folderName .. " path is not defined")
    end
  end}
  
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Quick Folder %02d Random 32", folderNum), invoke=function()
    local folderPath = getFolderPath(folderNum)
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


function duplicate_sample_with_transpose(transpose_amount)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at -12 transpose",invoke=function() duplicate_sample_with_transpose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at -24 transpose",invoke=function() duplicate_sample_with_transpose(-24) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at +12 transpose",invoke=function() duplicate_sample_with_transpose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sample at +24 transpose",invoke=function() duplicate_sample_with_transpose(24) end}


renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at -12 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(-12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at -24 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(-24) end end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at +12 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selected Sample at +24 transpose",invoke=function(message) if message:is_trigger() then duplicate_sample_with_transpose(24) end end}

-- Octave Slammer (-3 +3 octaves): Creates 6 copies of the selected sample at -3, -2, -1, +1, +2, +3 octaves
function PakettiOctaveSlammer3()
  local song = renoise.song()
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
  
  -- Store original volume for calculations
  local original_volume = original_sample.volume
  
  -- Set volumes so total combined volume = 100% with frequency balance
  original_sample.volume = original_volume * 0.35
  
  -- Octave transpositions: -3, -2, -1, +1, +2, +3 octaves (in semitones)
  local octave_transpositions = {-36, -24, -12, 12, 24, 36}
  local octave_names = {"-3oct", "-2oct", "-1oct", "+1oct", "+2oct", "+3oct"}
  -- Frequency-balanced volumes: lower octaves louder (warm), higher octaves quieter (shrill)
  local octave_volumes = {0.18, 0.15, 0.12, 0.10, 0.06, 0.04}
  
  -- Insert new samples after the current one
  local insert_index = selected_sample_index + 1
  
  for i = 1, #octave_transpositions do
    local transpose_amount = octave_transpositions[i]
    local octave_name = octave_names[i]
    local octave_volume = octave_volumes[i]
    
    -- Insert new sample slot
    instrument:insert_sample_at(insert_index)
    local new_sample = instrument.samples[insert_index]
    
    -- Copy sample buffer data
    new_sample:copy_from(original_sample)
    
    -- Copy all sample settings (finetune, loop mode, loop points, volume, pan, etc.)
    CopySampleSettings(original_sample, new_sample)
    
    -- Set the transpose and rename the sample
    new_sample.transpose = original_sample.transpose + transpose_amount
    new_sample.name = original_sample.name .. " " .. octave_name
    
    -- Set frequency-balanced volume (lower octaves louder, higher octaves quieter)
    new_sample.volume = original_volume * octave_volume
    
    -- Move to next insert position
    insert_index = insert_index + 1
  end

  renoise.app():show_status("Octave Slammer (-3 +3 octaves): Created 6 octave copies of '" .. original_sample.name .. "'")
end

-- Octave Slammer (-2 +2 octaves): Creates 4 copies of the selected sample at -2, -1, +1, +2 octaves
function PakettiOctaveSlammer2()
  local song = renoise.song()
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
  
  -- Store original volume for calculations
  local original_volume = original_sample.volume
  
  -- Set volumes so total combined volume = 100% with frequency balance
  original_sample.volume = original_volume * 0.40
  
  -- Octave transpositions: -2, -1, +1, +2 octaves (in semitones)
  local octave_transpositions = {-24, -12, 12, 24}
  local octave_names = {"-2oct", "-1oct", "+1oct", "+2oct"}
  -- Frequency-balanced volumes: lower octaves louder (warm), higher octaves quieter (shrill)
  local octave_volumes = {0.25, 0.20, 0.10, 0.05}
  
  -- Insert new samples after the current one
  local insert_index = selected_sample_index + 1
  
  for i = 1, #octave_transpositions do
    local transpose_amount = octave_transpositions[i]
    local octave_name = octave_names[i]
    local octave_volume = octave_volumes[i]
    
    -- Insert new sample slot
    instrument:insert_sample_at(insert_index)
    local new_sample = instrument.samples[insert_index]
    
    -- Copy sample buffer data
    new_sample:copy_from(original_sample)
    
    -- Copy all sample settings (finetune, loop mode, loop points, volume, pan, etc.)
    CopySampleSettings(original_sample, new_sample)
    
    -- Set the transpose and rename the sample
    new_sample.transpose = original_sample.transpose + transpose_amount
    new_sample.name = original_sample.name .. " " .. octave_name
    
    -- Set frequency-balanced volume (lower octaves louder, higher octaves quieter)
    new_sample.volume = original_volume * octave_volume
    
    -- Move to next insert position
    insert_index = insert_index + 1
  end

  renoise.app():show_status("Octave Slammer (-2 +2 octaves): Created 4 octave copies of '" .. original_sample.name .. "'")
end

-- Octave Slammer (-1 +1 octaves): Creates 2 copies of the selected sample at -1, +1 octaves
function PakettiOctaveSlammer1()
  local song = renoise.song()
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
  
  -- Store original volume for calculations
  local original_volume = original_sample.volume
  
  -- Set volumes so total combined volume = 100% with frequency balance
  original_sample.volume = original_volume * 0.40
  
  -- Octave transpositions: -1, +1 octaves (in semitones)
  local octave_transpositions = {-12, 12}
  local octave_names = {"-1oct", "+1oct"}
  -- Frequency-balanced volumes: lower octave louder (warm), higher octave quieter (shrill)
  local octave_volumes = {0.35, 0.25}
  
  -- Insert new samples after the current one
  local insert_index = selected_sample_index + 1
  
  for i = 1, #octave_transpositions do
    local transpose_amount = octave_transpositions[i]
    local octave_name = octave_names[i]
    local octave_volume = octave_volumes[i]
    
    -- Insert new sample slot
    instrument:insert_sample_at(insert_index)
    local new_sample = instrument.samples[insert_index]
    
    -- Copy sample buffer data
    new_sample:copy_from(original_sample)
    
    -- Copy all sample settings (finetune, loop mode, loop points, volume, pan, etc.)
    CopySampleSettings(original_sample, new_sample)
    
    -- Set the transpose and rename the sample
    new_sample.transpose = original_sample.transpose + transpose_amount
    new_sample.name = original_sample.name .. " " .. octave_name
    
    -- Set frequency-balanced volume (lower octaves louder, higher octaves quieter)
    new_sample.volume = original_volume * octave_volume
    
    -- Move to next insert position
    insert_index = insert_index + 1
  end

  renoise.app():show_status("Octave Slammer (-1 +1 octaves): Created 2 octave copies of '" .. original_sample.name .. "'")
end

renoise.tool():add_keybinding{name="Global:Paketti:Octave Slammer (-3 +3 octaves)",invoke=PakettiOctaveSlammer3}
renoise.tool():add_keybinding{name="Global:Paketti:Octave Slammer (-2 +2 octaves)",invoke=PakettiOctaveSlammer2}
renoise.tool():add_keybinding{name="Global:Paketti:Octave Slammer (-1 +1 octaves)",invoke=PakettiOctaveSlammer1}

renoise.tool():add_midi_mapping{name="Paketti:Octave Slammer (-3 +3 octaves)",invoke=function(message) if message:is_trigger() then PakettiOctaveSlammer3() end end}
renoise.tool():add_midi_mapping{name="Paketti:Octave Slammer (-2 +2 octaves)",invoke=function(message) if message:is_trigger() then PakettiOctaveSlammer2() end end}
renoise.tool():add_midi_mapping{name="Paketti:Octave Slammer (-1 +1 octaves)",invoke=function(message) if message:is_trigger() then PakettiOctaveSlammer1() end end}
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

renoise.tool():add_keybinding{name="Global:Paketti:Load Drumkit with Overlap Random",invoke=function() pitchBendDrumkitLoader()
DrumKitToOverlay(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Drumkit with Overlap Cycle",invoke=function() pitchBendDrumkitLoader()
DrumKitToOverlay(1) end}
-------
---------------
function PakettiDuplicateInstrumentSamplesWithTranspose(transpose_amount, quiet)
  local song=renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    if not quiet then renoise.app():show_status("No instrument selected.") end
    return
  end

  if #instrument.samples == 0 then
    if not quiet then renoise.app():show_status("No samples in instrument.") end
    return
  end

  -- Check ALL samples for slice markers
  for _, sample in ipairs(instrument.samples) do
    if #sample.slice_markers > 0 then
      if not quiet then renoise.app():show_status("Cannot duplicate: Instrument contains sliced samples.") end
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
    if not quiet then renoise.app():show_status("No original samples found to duplicate.") end
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
  
  -- Check if this specific transpose already exists
  local requested_transpose = (transpose_amount >= 0 and "+" or "") .. transpose_amount
  if seen_transposes[requested_transpose] then
    if not quiet then renoise.app():show_status(string.format("Samples with transpose %s already exist.", requested_transpose)) end
    return
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

  if not quiet then renoise.app():show_status(string.format("Duplicated %d samples with transpose %d", 
    #original_samples, transpose_amount)) end
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at -36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-36) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at -24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-24) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at -12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at +12 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at +24 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(24) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate All Samples at +36 Transpose",invoke=function() PakettiDuplicateInstrumentSamplesWithTranspose(36) end}




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
  if not safeInsertInstrumentAt(song, temp_instrument_index) then return end
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
  
  -- Build the base status message
  local status_msg = string.format(
    "Selection: %d-%d frames (%d frames total) | %.2f-%.2f ms (%.2f ms total) | %.2f-%.2f beats (%.2f total) | %.2f-%.2f divs (%.2f total)", 
    start_frame, end_frame, frames_selected,
    start_ms, end_ms, ms_selected,
    start_beats, end_beats, beats_selected,
    start_divisions, end_divisions, divisions_selected
  )
  
  -- Add frequency analysis if enabled and we have a valid selection
  if preferences.pakettiShowSampleDetailsFrequencyAnalysis.value and frames_selected > 1 then
    local cycles = preferences.pakettiSampleDetailsCycles.value or 1
    local analysis = analyze_sample_selection(cycles)
    
    if analysis then
      local freq_msg = string.format(" | Note: %s (%.1fHz, %+.0f¢)", 
        analysis.letter, analysis.freq, analysis.cents)
      status_msg = status_msg .. freq_msg
    end
  end
  
  renoise.app():show_status(status_msg)
end

-- Function to toggle the sample details display
function toggleSampleDetails()
  -- If not in sample editor, switch to it first
  if not isSampleEditorVisible() then
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end

  preferences.pakettiShowSampleDetails.value = not preferences.pakettiShowSampleDetails.value
  preferences:save_as("preferences.xml")  -- Save after toggle
  
  if preferences.pakettiShowSampleDetails.value then
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
    preferences.pakettiShowSampleDetails.value = false
    preferences:save_as("preferences.xml")
  elseif now_in_sample_editor and preferences.pakettiShowSampleDetails.value then
    startSampleDetailsTimer()
  end
  
  was_in_sample_editor = now_in_sample_editor
end)

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Toggle Sample Selection Info",invoke = toggleSampleDetails}



renoise.tool().app_release_document_observable:add_notifier(function() stopSampleDetailsTimer() end)

-- Initialize sample details display based on preference
function initializeSampleDetails()
  if preferences.pakettiShowSampleDetails.value and isSampleEditorVisible() then
    startSampleDetailsTimer()
  end
end

-- Add the initialization call - ONLY on new document, NOT on idle tick
-- The active_middle_frame_observable already handles view changes
renoise.tool().app_new_document_observable:add_notifier(initializeSampleDetails)
-- REMOVED: app_idle_observable notifier was redundant and caused unnecessary polling
-- The active_middle_frame_observable (line 5784) already handles sample editor visibility changes

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

---------
-- Global dialog reference for Show Largest Samples toggle behavior
local dialog = nil

function pakettiShowLargestSamplesDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local song=renoise.song()
  local vb = renoise.ViewBuilder()
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
        vb:text{width=150, text="Action", font = "bold" },
        vb:text{width=70, text="Size", font = "bold" },
        vb:text{width=30, text="Slot", font = "bold" },
        vb:text{width=150, text="Instrument", font = "bold" },
        vb:text{width=150, text="Sample", font = "bold" }
      }
    }
    
    for i = 1, math.min(40, #samples) do
      local sample = samples[i]
      dialog_content:add_child(vb:row{
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
        
        vb:button{
          width=50,
          text="Cut Half",
          notifier=function()
            local song=renoise.song()
            local target_instrument = song.instruments[sample.instr_idx]
            local target_sample = target_instrument.samples[sample.sample_idx]
            
            -- Select the sample first
            song.selected_instrument_index = sample.instr_idx
            song.selected_sample_index = sample.sample_idx
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
            
            -- Use ProcessSlicer for large samples
            local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
            local slicer = nil
            local progress_dialog = nil
            local progress_vb = nil
            
            local function process_func()
              local success, result1, result2 = PakettiTrimByHalfSampleCoroutine(target_sample, 1, 1)
              
              if progress_dialog and progress_dialog.visible then
                progress_dialog:close()
              end
              
              if success then
                renoise.app():show_status(string.format("Sample trimmed (%d -> %d frames)", result1, result2))
                -- Refresh main dialog
                if dialog and dialog.visible then
                  dialog:close()
                end
                pakettiShowLargestSamplesDialogDialog()
              else
                renoise.app():show_status("Could not trim sample: " .. result1)
              end
              
              PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
            end
            
            slicer = ProcessSlicer(process_func)
            progress_dialog, progress_vb = slicer:create_dialog("Trimming Sample by Half")
            slicer:start()
          end
        },
        
        vb:button{
          width=50,
          text="Delete",
          notifier=function()
            local song=renoise.song()
            local target_instrument = song.instruments[sample.instr_idx]
            local target_sample = target_instrument.samples[sample.sample_idx]
            
            -- Turn sample into 1-frame silent sample to save memory
            if target_sample.sample_buffer.has_sample_data then
              target_sample.sample_buffer:create_sample_data(
                target_sample.sample_buffer.sample_rate,
                target_sample.sample_buffer.bit_depth,
                1, -- mono
                1  -- 1 frame
              )
              target_sample.sample_buffer:prepare_sample_data_changes()
              target_sample.sample_buffer:set_sample_data(1, 1, 0.0)
              target_sample.sample_buffer:finalize_sample_data_changes()
              renoise.app():show_status("Sample reduced to 1 frame")
              
              -- Refresh dialog
              if dialog and dialog.visible then
                dialog:close()
              end
              pakettiShowLargestSamplesDialogDialog()
            end
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
    
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Show Largest Samples (Top 40)",dialog_content, keyhandler)
  end
  
  pakettiShowLargestSamplesDialogDialog()
end

renoise.tool():add_keybinding{name="Global:Paketti:Show Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
---------
-- Core function to duplicate track and instrument with configurable options
-- Parameters:
--   copy_dsp: boolean - whether to copy DSP devices
--   copy_automation: boolean - whether to copy automation
--   jump_to_editor: boolean - whether to jump to Sample Editor and/or open External Editor
function duplicateTrackAndInstrumentCore(copy_dsp, copy_automation, jump_to_editor)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local selected_track = song:track(track_index)
  
  -- Protection: Check if current track is a send track (or master/group track)
  if selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    local track_type_name = ""
    if selected_track.type == renoise.Track.TRACK_TYPE_SEND then
      track_type_name = "send"
    elseif selected_track.type == renoise.Track.TRACK_TYPE_MASTER then
      track_type_name = "master"
    elseif selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
      track_type_name = "group"
    else
      track_type_name = "non-sequencer"
    end
    renoise.app():show_status("Cannot duplicate " .. track_type_name .. " tracks. Please select a sequencer track.")
    return
  end
  
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
  if not safeInsertInstrumentAt(song, instrument_index + 1) then return end
  local new_instrument = song.instruments[instrument_index + 1]
  new_instrument:copy_from(original_instrument)

  -- Copy phrases if they exist
  if #original_instrument.phrases > 0 then
    local existing_phrases = #new_instrument.phrases
    local phrases_to_copy = #original_instrument.phrases
    if existing_phrases + phrases_to_copy > 126 then
      error("Cannot copy phrases: Would exceed maximum of 126 phrases per instrument (currently has " .. existing_phrases .. ", trying to add " .. phrases_to_copy .. ")")
    end
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
  
  -- Copy mixer volume settings
  new_track.prefx_volume.value = selected_track.prefx_volume.value
  new_track.postfx_volume.value = selected_track.postfx_volume.value
  
  -- Copy DSP devices and their settings (if enabled)
  if copy_dsp then
    for device_index = 2, #selected_track.devices do  -- Start from 2 to skip Track Volume device
      local old_device = selected_track.devices[device_index]
      local new_device = new_track:insert_device_at(old_device.device_path, device_index)
      -- Copy device parameters and mixer settings
      for param_index = 1, #old_device.parameters do
        new_device.parameters[param_index].value = old_device.parameters[param_index].value
        new_device.parameters[param_index].show_in_mixer = old_device.parameters[param_index].show_in_mixer
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
    
    -- Copy automation data (if enabled)
    if copy_automation then
      for _, automation in ipairs(source_track.automation) do
        local new_automation = dest_track:create_automation(automation.dest_parameter)
        for _, point in ipairs(automation.points) do
          new_automation:add_point_at(point.time, point.value)
        end
      end
    end
  end
  
  -- Select the new track and instrument
  song.selected_track_index = track_index + 1
  song.selected_instrument_index = instrument_index + 1
  
  -- Check if instrument has samples and plugin (for jump and status)
  local has_samples = #new_instrument.samples > 0 and new_instrument.samples[1].sample_buffer.has_sample_data
  local has_plugin = new_instrument.plugin_properties and new_instrument.plugin_properties.plugin_device
  
  -- Handle editor visibility based on jump_to_editor parameter
  if jump_to_editor then
    -- Jump to Sample Editor if there are samples
    if has_samples then
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
    -- Open External Editor if there's a plugin
    if has_plugin then
      new_instrument.plugin_properties.plugin_device.external_editor_visible = true
    end
  else
    -- Restore external editor state if needed (original behavior)
    if external_editor_open and has_plugin then
      new_instrument.plugin_properties.plugin_device.external_editor_visible = true
    end
  end
  
  -- Build status message
  local status_parts = {"Track and instrument duplicated"}
  if not copy_dsp and not copy_automation then
    status_parts[1] = "Track and instrument duplicated (clean)"
  end
  if jump_to_editor then
    if has_samples then
      table.insert(status_parts, "Sample Editor opened")
    end
    if has_plugin then
      table.insert(status_parts, "External Editor opened")
    end
  end
  renoise.app():show_status(table.concat(status_parts, ", "))
end

renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Track and Instrument",invoke=function() duplicateTrackAndInstrumentCore(true, true, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Track and Instrument",invoke=function() duplicateTrackAndInstrumentCore(true, true, false) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Track and Instrument (Clean)",invoke=function() duplicateTrackAndInstrumentCore(false, false, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Track and Instrument (Clean)",invoke=function() duplicateTrackAndInstrumentCore(false, false, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Track and Instrument (Clean)",invoke=function() duplicateTrackAndInstrumentCore(false, false, false) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Track and Instrument (Clean&Jump)",invoke=function() duplicateTrackAndInstrumentCore(false, false, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Track and Instrument (Clean&Jump)",invoke=function() duplicateTrackAndInstrumentCore(false, false, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Track and Instrument (Clean&Jump)",invoke=function() duplicateTrackAndInstrumentCore(false, false, true) end}

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

  -- STEP 1: Fill EmptiedUnused samples first (preserves existing mappings)
  local filled_count = 0
  for sample_index = 1, #instrument.samples do
      local sample = instrument.samples[sample_index]
      
      -- Check if this sample is marked as EmptiedUnused
      if sample.name == "EmptiedUnused" then
          if #sample_files == 0 then
              renoise.app():show_status(string.format("Filled %d EmptiedUnused slots, ran out of sample files.", filled_count))
              return
          end

          local random_index = math.random(1, #sample_files)
          local selected_file = sample_files[random_index]
          table.remove(sample_files, random_index)

          local success = pcall(function()
              sample.sample_buffer:load_from(selected_file)
          end)

          if success then
            sample.name = selected_file:match("([^/\\]+)%.%w+$")
            filled_count = filled_count + 1
            
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
            -- NOTE: Don't modify mappings - preserve existing ones!
            renoise.app():show_status(string.format("Filled EmptiedUnused slot %d: %s", sample_index, sample.name))
        end
      end
  end
  
  -- STEP 2: If we still have sample files, use original method for unmapped notes
  if #sample_files > 0 then
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
              filled_count = filled_count + 1
              
              -- Set both note_range and base_note to the current note
              local mapping = instrument.sample_mappings[1][sample_index]
              mapping.note_range = {note, note}
              mapping.base_note = note
              
              local note_name = string.format("%s%d", string.char(65 + (note % 12)), math.floor(note / 12))
              renoise.app():show_status(string.format("Mapped %s: %s", note_name, sample.name))
          end 
        end 
    end
  end
  
  if filled_count > 0 then
      renoise.app():show_status(string.format("Filled %d sample slots total", filled_count))
  else
      renoise.app():show_status("No empty slots found to fill")
  end 
end

renoise.tool():add_keybinding{name="Global:Paketti:Fill Empty Sample Slots (Randomized Folder)",invoke=function() fillEmptySampleSlots() end}

-- Function to sanitize and validate folder path
function sanitizeFolderPath(path)
  if not path then return nil end
  
  -- Don't modify the original path - keep native separators
  local sanitized = path
  
  -- Remove any trailing slashes/backslashes
  sanitized = sanitized:gsub("[/\\]*$", "")
  
  -- Check if the path exists using the original path format
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

function pakettiToggleLoopRangeSelection()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected.")
    return
  end
  
  local buffer = sample.sample_buffer
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  
  -- Check if there's a valid selection
  if not selection_start or not selection_end or selection_start >= selection_end then
    renoise.app():show_status("No valid selection range.")
    return
  end
  
  local current_loop_start = sample.loop_start
  local current_loop_end = sample.loop_end
  local current_loop_mode = sample.loop_mode
  
  print("Debug: selection_start=" .. selection_start .. ", selection_end=" .. selection_end)
  print("Debug: current_loop_start=" .. current_loop_start .. ", current_loop_end=" .. current_loop_end)
  print("Debug: current_loop_mode=" .. current_loop_mode)
  
  -- Check if loop points match selection
  local loop_matches_selection = (current_loop_start == selection_start and current_loop_end == selection_end)
  
  if loop_matches_selection then
    -- Loop is where selection is
    if current_loop_mode == renoise.Sample.LOOP_MODE_OFF then
      -- Loop is OFF but matches selection - turn it ON
      sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      renoise.app():show_status("Loop enabled (Forward mode).")
      print("Debug: Enabled loop at selection range")
    else
      -- Loop is ON and matches selection - turn it OFF
      sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      renoise.app():show_status("Loop disabled.")
      print("Debug: Disabled loop")
    end
  else
    -- Loop doesn't match selection - move it there and enable Forward mode
    sample.loop_start = selection_start
    sample.loop_end = selection_end
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    renoise.app():show_status("Loop moved to selection and enabled (Forward mode).")
    print("Debug: Moved loop to selection range and enabled")
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Toggle Loop Range (Selection)",invoke=pakettiToggleLoopRangeSelection}

---
function pakettiSampleEditorSelectionClear()
if renoise.song().selected_sample ~= nil then 

  renoise.song().selected_sample.sample_buffer.selection_range={}
else
  renoise.app():show_status("No sample selected.")
end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Unmark / Clear Selection",invoke=pakettiSampleEditorSelectionClear}

function oneshotcontinue()
  if renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].oneshot then
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].oneshot = false
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].new_note_action = 1
  else
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].oneshot = true
    renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].new_note_action = 3
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set to One-Shot + NNA Continue", invoke=function() oneshotcontinue() end}

function PakettiNNASetAllInstrumentsSamplesCut()
  local song = renoise.song()
  
  -- Check if any instruments exist
  if #song.instruments == 0 then
    renoise.app():show_status("No instruments available.")
    return
  end
  
  local instruments_processed = 0
  local samples_processed = 0
  
  -- Iterate through all instruments
  for instrument_index = 1, #song.instruments do
    local instrument = song.instruments[instrument_index]
    
    -- Check if instrument has samples
    if #instrument.samples > 0 then
      instruments_processed = instruments_processed + 1
      
      -- Iterate through all samples in the instrument
      for sample_index = 1, #instrument.samples do
        local sample = instrument.samples[sample_index]
        
        -- Set NNA to Cut (1)
        sample.new_note_action = 1
        samples_processed = samples_processed + 1
      end
    end
  end
  
  -- Show status message
  if samples_processed > 0 then
    renoise.app():show_status(string.format("Set NNA to Cut for %d samples across %d instruments", samples_processed, instruments_processed))
  else
    renoise.app():show_status("No samples found in any instruments.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set All Instruments Samples NNA to Cut",invoke=function() PakettiNNASetAllInstrumentsSamplesCut() end}

-- Function to toggle frequency analysis
function toggleFrequencyAnalysis()
  if not isSampleEditorVisible() then
    renoise.app():show_status("Frequency analysis only available in Sample Editor")
    return
  end
  
  preferences.pakettiShowSampleDetailsFrequencyAnalysis.value = not preferences.pakettiShowSampleDetailsFrequencyAnalysis.value
  preferences:save_as("preferences.xml")
  
  local status = preferences.pakettiShowSampleDetailsFrequencyAnalysis.value and "ON" or "OFF"
  renoise.app():show_status("Frequency analysis: " .. status)
end

-- Function to cycle through common cycles values
function cycleThroughCycles()
  if not isSampleEditorVisible() then
    renoise.app():show_status("Frequency analysis only available in Sample Editor")
    return
  end
  
  local common_cycles = {1, 2, 4, 8, 16}
  local current = preferences.pakettiSampleDetailsCycles.value
  local next_index = 1
  
  -- Find current index and move to next
  for i, cycles in ipairs(common_cycles) do
    if cycles == current then
      next_index = (i % #common_cycles) + 1
      break
    end
  end
  
  preferences.pakettiSampleDetailsCycles.value = common_cycles[next_index]
  preferences:save_as("preferences.xml")
  
  renoise.app():show_status("Frequency analysis cycles: " .. common_cycles[next_index])
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Toggle Frequency Analysis",invoke = toggleFrequencyAnalysis}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Cycle Frequency Analysis Cycles",invoke = cycleThroughCycles}








-------
function pakettiSampleBufferCenterSelector()
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

  local center = math.floor(sample_length / 2)
  sample_buffer.selection_start = center
  sample_buffer.selection_end = center
  renoise.app():show_status("Center of sample selected (frames " .. center .. "-" .. (center + 1) .. ").")
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select Center of Sample Buffer",invoke=function()pakettiSampleBufferCenterSelector()end}

-- Function to load a random sample directly into the pattern at cursor position
function loadRandomSampleToPattern(folder_path)
  local song = renoise.song()
  
  -- Check if we have a valid song
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end
  
  -- Check if current track is a sequencer track
  local current_track = song.selected_track
  if current_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Current track is not a sequencer track, can't write")
    return
  end
  
  -- Check if a note column is selected
  if song.selected_note_column_index == 0 then
    renoise.app():show_status("No note column selected, can't write")
    return
  end
  
  -- Get folder path
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Folder path is not defined")
    return
  end
  
  -- Get all valid audio files in the specified directory
  local wav_files = PakettiGetFilesInDirectory(folder_path)
  
  -- Check if there are files to choose from
  if #wav_files == 0 then
    renoise.app():show_status("No audio files found in the selected folder")
    return
  end
  
  -- Select a random file
  local random_index = math.random(1, #wav_files)
  local selected_file = wav_files[random_index]
  local file_name = selected_file:match("([^/\\]+)%.%w+$")

  -- Create new instrument and load the sample
  if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then return end
  song.selected_instrument_index = song.selected_instrument_index + 1

  pakettiPreferencesDefaultInstrumentLoader()

  local instrument = song.selected_instrument
  instrument:delete_sample_at(1)  -- Clear default sample slot

  local sample = instrument:insert_sample_at(1)
  sample.sample_buffer:load_from(selected_file)
  sample.name = file_name
  instrument.name = file_name

  -- Get current pattern position
  local current_track_index = song.selected_track_index
  local current_line_index = song.selected_line_index
  local current_note_column_index = song.selected_note_column_index
  local current_pattern_index = song.selected_pattern_index
  
  -- Get the pattern line and note column
  local pattern = song:pattern(current_pattern_index)
  local pattern_track = pattern:track(current_track_index)
  local pattern_line = pattern_track:line(current_line_index)
  local note_column = pattern_line:note_column(current_note_column_index)
  
  -- Write the note into the pattern
  note_column.note_value = 48  -- C-4
  note_column.instrument_value = song.selected_instrument_index - 1  -- 0-based instrument index
  note_column.volume_value = song.transport.keyboard_velocity

  renoise.app():show_status("Loaded random sample '" .. file_name .. "' and placed note at current position")
  print("Random sample loaded: " .. selected_file)
  print("Note placed at Track " .. current_track_index .. ", Line " .. current_line_index .. ", Column " .. current_note_column_index)
end

-- Function to prompt for folder and load random sample to pattern
function loadRandomSampleToPatternDialog()
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
  if folder_path then
    loadRandomSampleToPattern(folder_path)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Random Sample to Pattern (from Dialog)", invoke=loadRandomSampleToPatternDialog}




function isolate_slices_play_all_together()
  print("--- Isolate Slices - Play All Together ---")
  
  local song = renoise.song()
  local original_instrument_index = song.selected_instrument_index
  local instrument = song:instrument(original_instrument_index)
  
  -- Check if we have slices
  local has_slices = instrument.samples[1] and instrument.samples[1].slice_markers and #instrument.samples[1].slice_markers > 0
  
  if not has_slices then
      renoise.app():show_status("No slices found in selected instrument")
      print("Error: No slices found in selected instrument")
      return
  end
  
  print("Found slices - running isolation...")
  PakettiIsolateSlicesToInstrument() -- Creates individual samples from slices
  
  -- Get the newly created instrument
  local new_instrument = song.selected_instrument
  local samples = new_instrument.samples
  local num_samples = #samples
  
  print("Setting up simultaneous play mapping for " .. num_samples .. " samples...")
  
  -- Set up each sample to play across the entire keyboard (0-119)
  for i = 1, num_samples do
      local sample = samples[i]
      
      sample.sample_mapping.map_velocity_to_volume = false
      sample.sample_mapping.base_note = 48 -- C-4
      sample.sample_mapping.note_range = {0, 119} -- Full keyboard range
      sample.sample_mapping.velocity_range = {1, 127} -- Full velocity range
      
      print("Sample " .. i .. " (" .. sample.name .. ") mapped to full keyboard")
  end
  
  renoise.app():show_status("Created simultaneous play instrument - " .. num_samples .. " samples play together")
  print("--- All slices now play simultaneously across full keyboard ---")
  returnpe()
end

renoise.tool():add_keybinding{name="Global:Paketti:Isolate Slices - Play All Together",invoke=function() isolate_slices_play_all_together() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Slice:Isolate Slices - Play All Together",invoke=function() isolate_slices_play_all_together() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Isolate Slices - Play All Together",invoke=function() isolate_slices_play_all_together() end}





--------
-- Write Permission Detection for Wave Batch Operations
--------

-- Test if a directory is writable by attempting to create a temporary file
local function test_directory_writable_xrni(directory_path)
  if not directory_path or directory_path == "" then
    return false, "Invalid directory path"
  end
  
  -- Create a unique temporary filename
  local temp_filename = "paketti_wave_write_test_" .. os.time() .. ".tmp"
  local temp_path = directory_path .. "/" .. temp_filename
  
  -- Try to create and write to the file
  local success, err = pcall(function()
    local file = io.open(temp_path, "w")
    if not file then
      error("Cannot create file")
    end
    file:write("test")
    file:close()
    
    -- Clean up the test file
    os.remove(temp_path)
  end)
  
  return success, err
end

-- Prompt user to select a writable directory for XRNI files
local function prompt_for_xrni_directory()
  local dialog_result = renoise.app():prompt_for_path("Select a writable folder for XRNI files:")
  
  if dialog_result and dialog_result ~= "" then
    local is_writable, error_msg = test_directory_writable_xrni(dialog_result)
    if is_writable then
      return dialog_result
    else
      renoise.app():show_error("Selected directory is not writable: " .. (error_msg or "Unknown error") .. "\nPlease select a different directory.")
      return prompt_for_xrni_directory() -- Recursive call to try again
    end
  end
  
  return nil -- User cancelled or no valid directory selected
end

-- Check and get writable directory for wave batch operations
local function get_writable_xrni_directory(source_directory)
  -- First, test if the source directory is writable
  local is_writable, error_msg = test_directory_writable_xrni(source_directory)
  
  if is_writable then
    return source_directory
  else
    print("Source directory not writable:", source_directory, "Error:", error_msg)
    renoise.app():show_warning(
      "Cannot write to source directory: " .. source_directory .. "\n" ..
      "Error: " .. (error_msg or "Permission denied") .. "\n\n" ..
      "Please select a writable directory for XRNI files."
    )
    
    return prompt_for_xrni_directory()
  end
end

-- Wave Batch Converter: Save XRNI + Optionally Load into Renoise
function PakettiBatchWaveToXRNI(load_into_renoise)
  load_into_renoise = load_into_renoise or false
  
  local dialog_text = load_into_renoise and "Select folder with wave files to convert to XRNI and load" or "Select folder with wave files to convert to XRNI (save only)"
  local folder_path = renoise.app():prompt_for_path(dialog_text)
  
  if not folder_path or folder_path == "" then
    renoise.app():show_status("No folder selected for wave conversion")
    return
  end
  
  -- Define wave file extensions to look for
  local wave_extensions = {".wav", ".WAV", ".aiff", ".AIFF", ".aif", ".AIF", ".flac", ".FLAC"}
  
  -- Function to check if file has wave extension
  local function is_wave_file(filename)
    for _, ext in ipairs(wave_extensions) do
      if filename:sub(-#ext) == ext then
        return true
      end
    end
    return false
  end
  
  -- Function to get all wave files in directory
  local function get_wave_files(directory)
    local files = {}
    local separator = package.config:sub(1,1)
    
    -- Get all files in the directory using Renoise's os.filenames API
    local success, filenames = pcall(os.filenames, directory, "*")
    if not success then
      print("Error accessing directory: " .. tostring(filenames))
      return files
    end
    
    for _, filename in ipairs(filenames) do
      if is_wave_file(filename) then
        table.insert(files, directory .. separator .. filename)
      end
    end
    
    return files
  end
  
  -- Get all wave files from the selected folder
  local files = get_wave_files(folder_path)
  
  if #files == 0 then
    renoise.app():show_status("No wave files found in selected folder")
    return
  end
  
  -- Check write permissions before starting batch conversion
  local output_directory = get_writable_xrni_directory(folder_path)
  
  if not output_directory then
    renoise.app():show_status("Wave batch conversion cancelled - no writable directory selected")
    return
  end
  
  -- Inform user about output directory if it's different from source
  if output_directory ~= folder_path then
    renoise.app():show_status("XRNI files will be saved to: " .. output_directory)
  end
  
  -- Declare variables for ProcessSlicer
  local process_slicer = nil
  local progress_dialog = nil
  local progress_vb = nil
  
  -- Process function that will run with ProcessSlicer
  local function batch_process_func()
    local converted_count = 0
    local failed_count = 0
    local xrni_files = {}
    local temp_index = nil

    -- Step 1: CONVERT all wave files to XRNI with Paketti treatment
    -- Create one temporary instrument slot for conversion
    if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then return end
    temp_index = renoise.song().selected_instrument_index + 1
    renoise.song().selected_instrument_index = temp_index

    for i, file_path in ipairs(files) do
      -- Check if process was cancelled
      if process_slicer and process_slicer:was_cancelled() then
        -- Clean up and exit
        if temp_index then
          renoise.song():delete_instrument_at(temp_index)
        end
        if progress_dialog and progress_dialog.visible then
          progress_dialog:close()
        end
        renoise.app():show_status("Batch conversion cancelled")
        return
      end
      
      local filename = file_path:match("[^/\\]+$")
      -- Remove extension from filename for instrument name and XRNI filename
      local base_name = filename:gsub("%.[^%.]+$", "")
      local output_path = output_directory .. "/" .. base_name .. ".xrni"
      
      -- Update progress dialog
      if progress_dialog and progress_dialog.visible and progress_vb then
        progress_vb.views.progress_text.text = string.format("Converting %d/%d: %s", i, #files, base_name)
      end
      
      local success, error_msg = pcall(function()
        -- Clear temporary instrument for each conversion
        renoise.song().selected_instrument:clear()
        
        -- Load Paketti default instrument into temporary slot
        pakettiPreferencesDefaultInstrumentLoader()
        
        -- Load wave file as sample
        local instrument = renoise.song().selected_instrument
        
        -- Clear the default sample if it exists and load our wave file
        if #instrument.samples > 0 then
          for sample_idx = #instrument.samples, 1, -1 do
            instrument:delete_sample_at(sample_idx)
          end
        end
        
        -- Insert new sample and load the wave file
        instrument:insert_sample_at(1)
        renoise.song().selected_sample_index = 1
        renoise.song().selected_sample.sample_buffer:load_from(file_path)
        
        -- Apply Paketti Loader preferences to the sample
        local sample = renoise.song().selected_sample
        sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        sample.autofade = preferences.pakettiLoaderAutofade.value
        sample.autoseek = preferences.pakettiLoaderAutoseek.value
        sample.oneshot = preferences.pakettiLoaderOneshot.value
        sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        sample.new_note_action = preferences.pakettiLoaderNNA.value
        sample.loop_release = preferences.pakettiLoaderLoopExit.value
        
        -- Name the instrument and the sample
        renoise.song().selected_instrument.name = base_name
        sample.name = base_name
        
        -- Save as XRNI file
        renoise.app():save_instrument(output_path)
        
        -- Track successful conversions
        table.insert(xrni_files, {path = output_path, name = base_name})
      end)
      
      if success then
        converted_count = converted_count + 1
      else
        failed_count = failed_count + 1
        print("Failed to convert " .. base_name .. ": " .. tostring(error_msg))
      end
      
      -- Yield control periodically for UI responsiveness
      if i % 3 == 0 then
        coroutine.yield()
      end
    end
    
    -- Step 2: If load_into_renoise, load each XRNI into separate instrument slots
    if load_into_renoise and #xrni_files > 0 then
      for i, xrni_info in ipairs(xrni_files) do
        -- Check if process was cancelled
        if process_slicer and process_slicer:was_cancelled() then
          -- Clean up and exit
          if temp_index then
            renoise.song():delete_instrument_at(temp_index)
          end
          if progress_dialog and progress_dialog.visible then
            progress_dialog:close()
          end
          renoise.app():show_status("Batch conversion cancelled during loading")
          return
        end
        
        -- Update progress dialog
        if progress_dialog and progress_dialog.visible and progress_vb then
          progress_vb.views.progress_text.text = string.format("Loading %d/%d: %s", i, #xrni_files, xrni_info.name)
        end

        -- Check instrument limit before loading
        if not canInsertInstrument() then
          renoise.app():show_status("Cannot load more instruments: maximum of 255 instruments reached (loaded " .. (i-1) .. " of " .. #xrni_files .. ")")
          if progress_dialog and progress_dialog.visible then
            progress_dialog:close()
          end
          break
        end

        local success, error_msg = pcall(function()
          -- Create new instrument slot for each XRNI
          local new_index = renoise.song().selected_instrument_index + 1
          if not safeInsertInstrumentAt(renoise.song(), new_index) then return end
          renoise.song().selected_instrument_index = new_index

          -- Load the XRNI file
          renoise.app():load_instrument(xrni_info.path)
        end)

        if not success then
          print("Failed to load " .. xrni_info.name .. ": " .. tostring(error_msg))
        end

        -- Yield control periodically for UI responsiveness
        if i % 2 == 0 then
          coroutine.yield()
        end
      end
    end

    -- Clean up: remove the temporary instrument slot
    if temp_index then
      renoise.song():delete_instrument_at(temp_index)
    end
    
    -- Close progress dialog
    if progress_dialog and progress_dialog.visible then
      progress_dialog:close()
    end
    
    local action_text = load_into_renoise and "converted & loaded" or "converted"
    local output_info = (output_directory ~= folder_path) and (" (saved to: " .. output_directory .. ")") or ""
    renoise.app():show_status(string.format("Wave Batch: %d %s, %d failed%s", converted_count, action_text, failed_count, output_info))
  end
  
  -- Create and start the ProcessSlicer
  process_slicer = ProcessSlicer(batch_process_func)
  progress_dialog, progress_vb = process_slicer:create_dialog("Batch Pakettify Progress")
  process_slicer:start()
  
  -- Set focus back to Renoise after dialog opens
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

renoise.tool():add_keybinding{name="Global:Paketti:Batch Pakettify Wave Files in Folder to XRNI (Save Only)...", invoke = PakettiBatchWaveToXRNI}
renoise.tool():add_keybinding{name="Global:Paketti:Batch Pakettify Wave Files in Folder to XRNI & Load...", invoke = function() PakettiBatchWaveToXRNI(true) end}
renoise.tool():add_midi_mapping{name="Paketti:Batch Pakettify Wave Files in Folder to XRNI (Save Only) [Trigger]", invoke = function(message) if message:is_trigger() then PakettiBatchWaveToXRNI() end end}
renoise.tool():add_midi_mapping{name="Paketti:Batch Pakettify Wave Files in Folder to XRNI & Load [Trigger]", invoke = function(message) if message:is_trigger() then PakettiBatchWaveToXRNI(true) end end}

-- Place Sample to End at Pattern End
-- Places the selected sample so it ends exactly at the pattern end
function PakettiPlaceSampleToEndAtPatternEnd()
  local song = renoise.song()
  local selected_instrument = song.selected_instrument
  
  -- Check if we have a valid instrument and sample
  if not selected_instrument or #selected_instrument.samples == 0 then
    renoise.app():show_status("No sample selected or instrument is empty")
    return
  end
  
  local sample = selected_instrument.samples[1]
  local sample_buffer = sample.sample_buffer
  
  if not sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  -- Get current pattern info
  local current_pattern = song.selected_pattern
  local pattern_length = current_pattern.number_of_lines
  local lpb = song.transport.lpb
  local bpm = song.transport.bpm
  
  -- Get sample info
  local sample_frames = sample_buffer.number_of_frames
  local sample_rate = sample_buffer.sample_rate
  
  -- Calculate sample duration in seconds
  local sample_duration_seconds = sample_frames / sample_rate
  
  -- Calculate how long each line is in seconds
  local seconds_per_line = (60 / bpm) / lpb
  
  -- Calculate how many lines the sample takes
  local sample_duration_lines = sample_duration_seconds / seconds_per_line
  
  -- Check if sample is longer than pattern
  if sample_duration_lines > pattern_length then
    renoise.app():show_status("Sample is longer than pattern duration - cannot fit")
    return
  end
  
  -- Calculate start line: pattern_end - sample_duration
  -- Pattern ends at line pattern_length, so sample should start at:
  local start_line_exact = pattern_length - sample_duration_lines + 1
  
  -- Split into line and fractional part
  local note_line = math.max(1, math.floor(start_line_exact))
  local line_fraction = start_line_exact - note_line
  
  -- Convert line fraction to ticks within the line
  local sub_tick = line_fraction * lpb
  
  -- Ensure we don't place beyond pattern length
  if note_line > pattern_length then
    note_line = pattern_length
  end
  
  -- Get current track
  local current_track_index = song.selected_track_index
  local current_track = song.tracks[current_track_index]
  
  -- Check if it's a regular track (not master/send)
  if current_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Please select a regular sequencer track")
    return
  end
  
  -- Get pattern track
  local pattern_track = current_pattern:track(current_track_index)
  local pattern_line = pattern_track:line(note_line)
  
  -- Make delay column visible
  current_track.delay_column_visible = true
  
  -- Place note at C-4 (note value 48)
  local note_column = pattern_line:note_column(1)
  note_column.note_value = 48  -- C-4
  note_column.instrument_value = song.selected_instrument_index - 1
  
  -- Apply delay for sub-tick precision
  if sub_tick > 0 then
    -- Convert sub-tick to delay value (0-255 range)
    local delay_value = math.floor(sub_tick * (256 / lpb))
    delay_value = math.min(255, math.max(0, delay_value))
    note_column.delay_value = delay_value
  end
  
  -- Move cursor to the placed note
  song.selected_line_index = note_line
  
  -- Show status with timing info
  local delay_info = ""
  if sub_tick > 0 then
    local delay_value = math.floor(sub_tick * (256 / lpb))
    delay_value = math.min(255, math.max(0, delay_value))
    delay_info = string.format(" +delay %02X (%.2f ticks)", delay_value, sub_tick)
  end
  local status_msg = string.format("Sample placed at line %d%s - duration %.2f lines (%.3fs)", 
                                   note_line, delay_info, sample_duration_lines, sample_duration_seconds)
  renoise.app():show_status(status_msg)
end

-- Add menu entries and keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Place Sample to End at Pattern End", invoke = PakettiPlaceSampleToEndAtPatternEnd}
renoise.tool():add_midi_mapping{name="Paketti:Place Sample to End at Pattern End [Trigger]", invoke = function(message) if message:is_trigger() then PakettiPlaceSampleToEndAtPatternEnd() end end}


-- Batch XRNI Loader - Load all XRNI files from a folder as new instruments
function PakettiBatchXRNILoader()
  local song = renoise.song()
  
  -- Show folder selection dialog
  local selected_folder = renoise.app():prompt_for_path("Select folder containing XRNI files")
  if selected_folder == "" then
    renoise.app():show_status("PakettiBatchXRNILoader: No folder selected")
    return
  end
  
  -- Scan folder for XRNI files
  local xrni_files = {}
  
  local success, result = pcall(function()
    return os.filenames(selected_folder, "*.xrni")
  end)
  
  if not success or not result then
    renoise.app():show_status("PakettiBatchXRNILoader: Could not scan folder: " .. selected_folder)
    return
  end
  
  -- Collect XRNI files
  for _, filename in ipairs(result) do
    local full_path = selected_folder .. separator .. filename
    table.insert(xrni_files, {
      filename = filename,
      full_path = full_path
    })
  end
  
  if #xrni_files == 0 then
    renoise.app():show_status("PakettiBatchXRNILoader: No XRNI files found in folder")
    return
  end
  
  -- Sort files alphabetically
  table.sort(xrni_files, function(a, b) 
    return a.filename:lower() < b.filename:lower() 
  end)
  
  local loaded_count = 0
  local failed_count = 0
  local failed_files = {}
  
  renoise.app():show_status("PakettiBatchXRNILoader: Loading " .. tostring(#xrni_files) .. " XRNI files...")

  -- Load each XRNI file
  for i, file_info in ipairs(xrni_files) do
    local success_load, err = pcall(function()
      -- Create new instrument after current selected instrument
      if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
        error("Cannot load more instruments: maximum of 255 instruments reached")
      end
      song.selected_instrument_index = song.selected_instrument_index + 1

      -- Load the XRNI file
      renoise.app():load_instrument(file_info.full_path)

      -- Set instrument name to filename without extension
      local instrument_name = file_info.filename:match("(.+)%.xrni$") or file_info.filename
      song.selected_instrument.name = instrument_name
    end)

    if success_load then
      loaded_count = loaded_count + 1
    else
      failed_count = failed_count + 1
      table.insert(failed_files, file_info.filename .. " (" .. tostring(err) .. ")")
      -- If we hit the instrument limit, stop trying
      if tostring(err):match("maximum of 255 instruments reached") then
        renoise.app():show_status("Cannot load more instruments: maximum of 255 instruments reached (loaded " .. (i-1) .. " of " .. #xrni_files .. ")")
        break
      end
    end
  end

  -- Report results
  local status_msg = string.format("PakettiBatchXRNILoader: Loaded %d/%d XRNI files", loaded_count, #xrni_files)
  if failed_count > 0 then
    status_msg = status_msg .. string.format(" (%d failed)", failed_count)
  end
  
  renoise.app():show_status(status_msg)
  
  -- Print detailed results if any failures
  if failed_count > 0 then
    print("PakettiBatchXRNILoader: Failed to load:")
    for _, failed_file in ipairs(failed_files) do
      print("  - " .. failed_file)
    end
  end
end



renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Batch XRNI Loader...", invoke = PakettiBatchXRNILoader}

-- Destructive Repeat Sample Range: Duplicates the selected sample range right after itself
function PakettiSamplesDestructiveRepeatRange()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample = song.selected_sample
  
  if not sample then
    renoise.app():show_status("PakettiSamplesDestructiveRepeatRange: No sample selected")
    return
  end
  
  local buffer = sample.sample_buffer
  
  if not buffer.has_sample_data then
    renoise.app():show_status("PakettiSamplesDestructiveRepeatRange: No sample data available")
    return
  end
  
  if buffer.read_only then
    renoise.app():show_status("PakettiSamplesDestructiveRepeatRange: Sample buffer is read-only")
    return
  end
  
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  local original_frames = buffer.number_of_frames
  
  -- Check if there's an actual selection (not just the whole buffer)
  if selection_start == 1 and selection_end == original_frames then
    renoise.app():show_status("PakettiSamplesDestructiveRepeatRange: Please make a selection first (entire buffer is selected)")
    return
  end
  
  local selection_length = selection_end - selection_start + 1
  local num_channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  local bit_depth = buffer.bit_depth
  
  -- Calculate where we want to paste (right after the selection)
  local paste_start = selection_end + 1
  local paste_end = paste_start + selection_length - 1
  local needs_extension = paste_end > original_frames
  
  if needs_extension then
    -- Need to extend buffer - read selection data first
    local selection_data = {}
    for channel = 1, num_channels do
      selection_data[channel] = {}
      for frame = selection_start, selection_end do
        selection_data[channel][frame] = buffer:sample_data(channel, frame)
      end
    end
    
    -- Read all original data
    local original_data = {}
    for channel = 1, num_channels do
      original_data[channel] = {}
      for frame = 1, original_frames do
        original_data[channel][frame] = buffer:sample_data(channel, frame)
      end
    end
    
    -- Create new buffer with extended size
    local new_frames = paste_end
    local success = buffer:create_sample_data(sample_rate, bit_depth, num_channels, new_frames)
    
    if not success then
      renoise.app():show_status("PakettiSamplesDestructiveRepeatRange: Failed to create extended buffer (out of memory?)")
      return
    end
    
    buffer:prepare_sample_data_changes()
    
    -- Write all original data
    for channel = 1, num_channels do
      for frame = 1, original_frames do
        buffer:set_sample_data(channel, frame, original_data[channel][frame])
      end
    end
    
    -- Write the selection right after itself
    local target_frame = paste_start
    for source_frame = selection_start, selection_end do
      for channel = 1, num_channels do
        buffer:set_sample_data(channel, target_frame, selection_data[channel][source_frame])
      end
      target_frame = target_frame + 1
    end
    
    buffer:finalize_sample_data_changes()
    
    -- Select the newly written range so user can repeat again
    buffer.selection_range = {paste_start, paste_end}
    
    renoise.app():show_status(string.format("PakettiSamplesDestructiveRepeatRange: Extended and repeated %d frames, new total: %d frames", 
      selection_length, new_frames))
  else
    -- Destructive overwrite - just copy selection to right after itself
    buffer:prepare_sample_data_changes()
    
    local target_frame = paste_start
    for source_frame = selection_start, selection_end do
      for channel = 1, num_channels do
        local sample_value = buffer:sample_data(channel, source_frame)
        buffer:set_sample_data(channel, target_frame, sample_value)
      end
      target_frame = target_frame + 1
    end
    
    buffer:finalize_sample_data_changes()
    
    -- Select the newly written range so user can repeat again
    buffer.selection_range = {paste_start, paste_end}
    
    renoise.app():show_status(string.format("PakettiSamplesDestructiveRepeatRange: Repeated %d frames (overwrite)", 
      selection_length))
  end
end

renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Destructive Repeat Sample Range", invoke = PakettiSamplesDestructiveRepeatRange}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Destructive Repeat Sample Range", invoke = PakettiSamplesDestructiveRepeatRange}
renoise.tool():add_menu_entry{name = "--Sample Editor Ruler:Destructive Repeat Sample Range", invoke = PakettiSamplesDestructiveRepeatRange}

-- Append Selection to End: Pastes the selected sample range to the end of the sample
function PakettiSamplesAppendSelectionToEnd()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample then
    renoise.app():show_status("PakettiSamplesAppendSelectionToEnd: No sample selected")
    return
  end
  
  local buffer = sample.sample_buffer
  
  if not buffer.has_sample_data then
    renoise.app():show_status("PakettiSamplesAppendSelectionToEnd: No sample data available")
    return
  end
  
  if buffer.read_only then
    renoise.app():show_status("PakettiSamplesAppendSelectionToEnd: Sample buffer is read-only")
    return
  end
  
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  local original_frames = buffer.number_of_frames
  
  -- Check if there's an actual selection (not just the whole buffer)
  if selection_start == 1 and selection_end == original_frames then
    renoise.app():show_status("PakettiSamplesAppendSelectionToEnd: Please make a selection first (entire buffer is selected)")
    return
  end
  
  local selection_length = selection_end - selection_start + 1
  local num_channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  local bit_depth = buffer.bit_depth
  
  -- Read selection data
  local selection_data = {}
  for channel = 1, num_channels do
    selection_data[channel] = {}
    for frame = selection_start, selection_end do
      selection_data[channel][frame] = buffer:sample_data(channel, frame)
    end
  end
  
  -- Read all original data
  local original_data = {}
  for channel = 1, num_channels do
    original_data[channel] = {}
    for frame = 1, original_frames do
      original_data[channel][frame] = buffer:sample_data(channel, frame)
    end
  end
  
  -- Create new buffer with extended size
  local new_frames = original_frames + selection_length
  local success = buffer:create_sample_data(sample_rate, bit_depth, num_channels, new_frames)
  
  if not success then
    renoise.app():show_status("PakettiSamplesAppendSelectionToEnd: Failed to create extended buffer (out of memory?)")
    return
  end
  
  buffer:prepare_sample_data_changes()
  
  -- Write all original data
  for channel = 1, num_channels do
    for frame = 1, original_frames do
      buffer:set_sample_data(channel, frame, original_data[channel][frame])
    end
  end
  
  -- Append selection to the end
  local target_frame = original_frames + 1
  for source_frame = selection_start, selection_end do
    for channel = 1, num_channels do
      buffer:set_sample_data(channel, target_frame, selection_data[channel][source_frame])
    end
    target_frame = target_frame + 1
  end
  
  buffer:finalize_sample_data_changes()
  
  -- Select the newly appended range at the end
  local append_start = original_frames + 1
  local append_end = new_frames
  buffer.selection_range = {append_start, append_end}
  
  renoise.app():show_status(string.format("PakettiSamplesAppendSelectionToEnd: Appended %d frames to end, new total: %d frames", 
    selection_length, new_frames))
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Append Selection to End", invoke = PakettiSamplesAppendSelectionToEnd}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Append Selection to End", invoke = PakettiSamplesAppendSelectionToEnd}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Append Selection to End", invoke = PakettiSamplesAppendSelectionToEnd}
renoise.tool():add_midi_mapping{name="Paketti:Append Selection to End", invoke = PakettiSamplesAppendSelectionToEnd}

-- Insert Selection After Selection: Inserts the selection right after itself, pushing content forward
function PakettiSamplesInsertSelectionAfterSelection()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample then
    renoise.app():show_status("PakettiSamplesInsertSelectionAfterSelection: No sample selected")
    return
  end
  
  local buffer = sample.sample_buffer
  
  if not buffer.has_sample_data then
    renoise.app():show_status("PakettiSamplesInsertSelectionAfterSelection: No sample data available")
    return
  end
  
  if buffer.read_only then
    renoise.app():show_status("PakettiSamplesInsertSelectionAfterSelection: Sample buffer is read-only")
    return
  end
  
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  local original_frames = buffer.number_of_frames
  
  -- Check if there's an actual selection (not just the whole buffer)
  if selection_start == 1 and selection_end == original_frames then
    renoise.app():show_status("PakettiSamplesInsertSelectionAfterSelection: Please make a selection first (entire buffer is selected)")
    return
  end
  
  local selection_length = selection_end - selection_start + 1
  local num_channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  local bit_depth = buffer.bit_depth
  
  -- Read all original data
  local original_data = {}
  for channel = 1, num_channels do
    original_data[channel] = {}
    for frame = 1, original_frames do
      original_data[channel][frame] = buffer:sample_data(channel, frame)
    end
  end
  
  -- Create new buffer with extended size
  local new_frames = original_frames + selection_length
  local success = buffer:create_sample_data(sample_rate, bit_depth, num_channels, new_frames)
  
  if not success then
    renoise.app():show_status("PakettiSamplesInsertSelectionAfterSelection: Failed to create extended buffer (out of memory?)")
    return
  end
  
  buffer:prepare_sample_data_changes()
  
  -- Write data before selection (unchanged)
  if selection_start > 1 then
    for channel = 1, num_channels do
      for frame = 1, selection_start - 1 do
        buffer:set_sample_data(channel, frame, original_data[channel][frame])
      end
    end
  end
  
  -- Write original selection at its original position
  for channel = 1, num_channels do
    for frame = selection_start, selection_end do
      buffer:set_sample_data(channel, frame, original_data[channel][frame])
    end
  end
  
  -- Insert duplicate of selection right after
  local insert_start = selection_end + 1
  local target_frame = insert_start
  for source_frame = selection_start, selection_end do
    for channel = 1, num_channels do
      buffer:set_sample_data(channel, target_frame, original_data[channel][source_frame])
    end
    target_frame = target_frame + 1
  end
  
  -- Write everything after selection, shifted forward
  local shift_start = selection_end + 1
  if shift_start <= original_frames then
    local target_frame = selection_end + selection_length + 1
    for source_frame = shift_start, original_frames do
      for channel = 1, num_channels do
        buffer:set_sample_data(channel, target_frame, original_data[channel][source_frame])
      end
      target_frame = target_frame + 1
    end
  end
  
  buffer:finalize_sample_data_changes()
  
  -- Select the newly inserted range
  buffer.selection_range = {insert_start, insert_start + selection_length - 1}
  
  renoise.app():show_status(string.format("PakettiSamplesInsertSelectionAfterSelection: Inserted %d frames, new total: %d frames", 
    selection_length, new_frames))
end

-- Detect and correct pitch for single-cycle waveforms
function PakettiSamplesDetectAndCorrectPitch()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample then
    renoise.app():show_status("No sample selected")
    return
  end
  
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  local buffer = sample.sample_buffer
  local wave_length_frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  
  -- Check if this is a standard single-cycle length
  local standard_cycle_lengths = {2, 4, 8, 16, 32, 64, 128, 256, 512, 1024}
  local is_standard_length = false
  for _, length in ipairs(standard_cycle_lengths) do
    if wave_length_frames == length then
      is_standard_length = true
      break
    end
  end
  
  if not is_standard_length then
    renoise.app():show_status(string.format("Sample length (%d frames) is not a standard single-cycle length (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024)", wave_length_frames))
    return
  end
  
  -- Calculate frequency from wave data (1 cycle)
  local freq = sample_rate / wave_length_frames
  local midi_note = freq2midi(freq)
  local nearest_note = round(midi_note)
  local cents = (nearest_note - midi_note) * 100
  local note_letter = get_note_letter(midi_note)
  
  -- Calculate pitch correction values
  local diff = round(midi_note) - 60  -- Difference from C4
  local transpose_value = -diff
  transpose_value = math.max(-120, math.min(120, transpose_value))
  
  -- Calculate fine tune correction (negate to correct the detected deviation)
  local fine_tune_steps = round(cents * 1.275)  -- Scale: 255 steps / 200 cents = 1.275
  fine_tune_steps = math.max(-128, math.min(127, fine_tune_steps))
  
  local cents_deviation = math.abs(cents)
  
  -- Display detection results
  print("=== PITCH DETECTION ===")
  print(string.format("Sample length: %d frames at %d Hz", wave_length_frames, sample_rate))
  print(string.format("Detected frequency: %.2f Hz", freq))
  print(string.format("Detected note: %s", note_letter))
  print(string.format("Cents deviation: %.2f cents", cents))
  print(string.format("Suggested correction: Transpose=%d, Fine Tune=%d", transpose_value, fine_tune_steps))
  
  -- Apply correction if deviation is significant (>2 cents)
  if cents_deviation > 2 then
    sample.transpose = transpose_value
    sample.fine_tune = fine_tune_steps
    renoise.app():show_status(string.format("Pitch corrected to %s (T:%d, F:%d, %.2f cents)", 
      note_letter, transpose_value, fine_tune_steps, cents))
  else
    renoise.app():show_status(string.format("Sample already tuned to %s (deviation: %.2f cents, no correction needed)", 
      note_letter, cents))
  end
end

-- ========================================
-- FREQUENCY TO NOTE ANALYSIS (Mathematical/Logarithmic approach)
-- ========================================
-- This uses a cleaner mathematical formula instead of iterative loops
-- Inspired by WaveformTuner with corrected fine-tune scaling

function PakettiSamplesFrequencyToNoteAnalysis()
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end
  
  local sample = song.selected_sample
  if not sample then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    renoise.app():show_status("Sample has no data")
    return
  end
  
  -- Get sample properties
  local buffer_length = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  
  if buffer_length == 0 then
    renoise.app():show_status("Sample buffer is empty")
    return
  end
  
  -- Calculate the waveform frequency
  local freq = sample_rate / buffer_length
  
  -- Constants for pitch calculation
  local target_note = 60  -- C4 in MIDI
  local A4_midi = 69      -- A4 MIDI note number
  local A4_freq = 440     -- A4 frequency in Hz
  
  -- Derive MIDI note from frequency using logarithmic formula
  -- Formula: note = A4 + 12 * log2(freq / A4_freq)
  local note = A4_midi + 12 * (math.log(freq / A4_freq) / math.log(2))
  
  -- How far off are we from the target note (C4), in semitones
  local delta_semitones = target_note - note
  
  -- Split into coarse semitones and fractional cents
  local semitones = math.floor(delta_semitones)
  local cents = (delta_semitones - semitones) * 100
  
  -- Convert cents to Renoise fine_tune range (-128 to +127)
  -- CORRECTED: Renoise has 255 steps (-128 to +127) covering 200 cents (±100)
  -- Therefore: 255 steps / 200 cents = 1.275 steps per cent
  local fine_tune = math.floor(cents * 1.275 + 0.5)
  
  -- Clamp to valid range
  fine_tune = math.max(-128, math.min(127, fine_tune))
  semitones = math.max(-120, math.min(120, semitones))
  
  -- Get note name for display
  local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local octave = math.floor(note / 12) - 1
  local note_index = math.floor(note) % 12 + 1
  local note_name = note_names[note_index] .. octave
  
  -- Display analysis results
  print("=== FREQUENCY TO NOTE ANALYSIS (Mathematical) ===")
  print(string.format("Sample length: %d frames at %d Hz", buffer_length, sample_rate))
  print(string.format("Detected frequency: %.2f Hz", freq))
  print(string.format("Calculated MIDI note: %.2f (%s)", note, note_name))
  print(string.format("Delta from C4: %.2f semitones", delta_semitones))
  print(string.format("Correction needed: %d semitones + %.2f cents", semitones, cents))
  print(string.format("Renoise values: Transpose=%d, Fine Tune=%d", semitones, fine_tune))
  
  -- Apply tuning values to the sample
  sample.transpose = semitones
  sample.fine_tune = fine_tune
  
  -- Set forward loop (typical for single-cycle waveforms)
  sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  if buffer_length <= 1024 then  -- Only set loop for short samples
    sample.loop_start = 1
    sample.loop_end = buffer_length
  end
  
  -- Show status
  local status = string.format("Tuned: %.2f Hz → %s (T:%d, F:%d, %.1f cents)", 
    freq, note_name, semitones, fine_tune, cents)
  renoise.app():show_status(status)
  print(status)
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Insert Selection After Selection", invoke = PakettiSamplesInsertSelectionAfterSelection}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Insert Selection After Selection", invoke = PakettiSamplesInsertSelectionAfterSelection}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Insert Selection After Selection", invoke = PakettiSamplesInsertSelectionAfterSelection}
renoise.tool():add_midi_mapping{name="Paketti:Insert Selection After Selection", invoke = PakettiSamplesInsertSelectionAfterSelection}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Detect and Correct Single-Cycle Pitch",invoke = PakettiSamplesDetectAndCorrectPitch}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Detect and Correct Single-Cycle Pitch",invoke = PakettiSamplesDetectAndCorrectPitch}
renoise.tool():add_keybinding{name="Global:Paketti:Detect and Correct Single-Cycle Pitch",invoke = PakettiSamplesDetectAndCorrectPitch}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Frequency to Note Analysis",invoke = PakettiSamplesFrequencyToNoteAnalysis}
renoise.tool():add_keybinding{name="Global:Paketti:Frequency to Note Analysis",invoke = PakettiSamplesFrequencyToNoteAnalysis}

-- Select N bars based on current BPM (DRY principle)
function PakettiSamplesSelectBars(num_bars)
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end
  
  local selected_sample = song.selected_sample
  if not selected_sample then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample_buffer = selected_sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data available")
    return
  end
  
  local bpm = song.transport.bpm
  local sample_rate = sample_buffer.sample_rate
  local total_frames = sample_buffer.number_of_frames
  
  -- Calculate frames per beat: (60 seconds / bpm) * sample_rate
  local frames_per_beat = (60 / bpm) * sample_rate
  
  -- Calculate frames for N bars (4 beats per bar)
  local beats_total = num_bars * 4
  local frames_for_bars = math.floor(frames_per_beat * beats_total)
  
  -- Ensure we don't exceed sample bounds
  local end_frame = math.min(frames_for_bars, total_frames)
  
  -- Set the selection range from frame 1 to calculated end
  sample_buffer.selection_range = {1, end_frame}
  
  -- Show status with useful information
  local bars_actual = end_frame / frames_per_beat / 4
  renoise.app():show_status(string.format(
    "Selected %d bar%s at %d BPM: frames 1-%d (%.2f bars of sample)",
    num_bars, num_bars == 1 and "" or "s", bpm, end_frame, bars_actual
  ))
end

-- Menu entries and keybindings
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Select Bars (BPM):Select 1 Bar", invoke = function() PakettiSamplesSelectBars(1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Select Bars (BPM):Select 2 Bars", invoke = function() PakettiSamplesSelectBars(2) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Select Bars (BPM):Select 4 Bars", invoke = function() PakettiSamplesSelectBars(4) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Select Bars (BPM):Select 8 Bars", invoke = function() PakettiSamplesSelectBars(8) end}

renoise.tool():add_menu_entry{name="--Sample Editor Ruler:Select 1 Bar (Based on BPM)", invoke = function() PakettiSamplesSelectBars(1) end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Select 2 Bars (Based on BPM)", invoke = function() PakettiSamplesSelectBars(2) end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Select 4 Bars (Based on BPM)", invoke = function() PakettiSamplesSelectBars(4) end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Select 8 Bars (Based on BPM)", invoke = function() PakettiSamplesSelectBars(8) end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select 1 Bar (Based on BPM)", invoke = function() PakettiSamplesSelectBars(1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select 2 Bars (Based on BPM)", invoke = function() PakettiSamplesSelectBars(2) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select 4 Bars (Based on BPM)", invoke = function() PakettiSamplesSelectBars(4) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Select 8 Bars (Based on BPM)", invoke = function() PakettiSamplesSelectBars(8) end}

-- Quick keybindings for append operations
function PakettiAppendRandomSamplesQuick(num_samples)
  local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end
  PakettiAppendRandomSamplesToInstrument(folder_path, num_samples)
end

renoise.tool():add_keybinding{name="Global:Paketti:Append Random Samples (01) to Instrument", invoke = function() PakettiAppendRandomSamplesQuick(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Append Random Samples (04) to Instrument", invoke = function() PakettiAppendRandomSamplesQuick(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Append Random Samples (12) to Instrument", invoke = function() PakettiAppendRandomSamplesQuick(12) end}
