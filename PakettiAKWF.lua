function load_random_akwf_sample(amount)
  local tool_folder = renoise.tool().bundle_path .. "AKWF/"
  local file_path = tool_folder .. "akwf.txt"
  local wav_files = {}

  -- Load .wav file paths from akwf.txt
  local file = io.open(file_path, "r")
  if file then
    for line in file:lines() do
      table.insert(wav_files, tool_folder .. line)  -- Combine relative path with tool_folder
    end
    file:close()
  else
    renoise.app():show_status("akwf.txt not found in " .. tool_folder)
    return
  end

  -- Determine the number of samples to load
  local num_samples
  if amount == "random" then
    num_samples = math.random(1, 12)
  else
    num_samples = math.min(amount, #wav_files)
  end

  -- Ensure there are enough .wav files to choose from
  if #wav_files > 0 then
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
    pakettiPreferencesDefaultInstrumentLoader()
    local instrument = renoise.song().selected_instrument
    renoise.song().selected_instrument:delete_sample_at(1)
    
    -- Calculate volume reduction factor based on the number of samples
    local volume_reduction_factor = math.min(1.0, 1 / math.sqrt(num_samples))

    -- Load the specified number of samples
    for i = 1, num_samples do
      local random_index = math.random(1, #wav_files)
      local selected_file = wav_files[random_index]

      -- Create a new sample slot for each loaded file
      local sample = instrument:insert_sample_at(instrument.samples[1] and #instrument.samples + 1 or 1)

      sample.sample_buffer:load_from(selected_file)
      sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      sample.autofade = preferences.pakettiLoaderAutofade.value
      sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      -- Set the volume of each sample to the calculated reduction factor
      sample.volume = volume_reduction_factor
      renoise.song().selected_instrument.volume = volume_reduction_factor

      -- Extract filename for setting sample name
      local filename = selected_file:match("([^/]+)%.wav$") or "Sample"
      sample.name = filename
      sample.transpose = -2

      -- Set finetune based on index: -10 for odd, +10 for even
      sample.fine_tune = (i % 2 == 1) and -10 or 10

      -- Update instrument name for clarity, using the last loaded file
      instrument.name = "AKWF - " .. filename
    end

    -- Display a message with the number of loaded samples
    renoise.app():show_status("Loaded " .. num_samples .. " samples into instrument with volume scaling.")
  else
    renoise.app():show_status("No .wav files found in AKWF folder.")
  end
  PakettiFillPitchStepperDigits(0.015,64)
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Random AKWF Sample",invoke=function() load_random_akwf_sample(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Random amount (1...12) of AKWF Samples",invoke=function() load_random_akwf_sample("random") end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 05 AKWF Samples",invoke=function() load_random_akwf_sample(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 05 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 05 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 12 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 12 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 12 AKWF Samples",invoke=function() load_random_akwf_sample(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Load 02 AKWF Samples",invoke=function() load_random_akwf_sample(2) end}

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:AKWF..:Load Random AKWF Sample",invoke=function() load_random_akwf_sample(1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:AKWF..:Load Random amount (1...12) of AKWF Samples",invoke=function() load_random_akwf_sample("random") end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:AKWF..:Load 02 AKWF Samples",invoke=function() load_random_akwf_sample(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:AKWF..:Load 05 AKWF Samples",invoke=function() load_random_akwf_sample(5) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:AKWF..:Load 12 AKWF Samples",invoke=function() load_random_akwf_sample(12) end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:AKWF..:Load 05 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:AKWF..:Load 05 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:AKWF..:Load 12 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:AKWF..:Load 12 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(1) end}

renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti..:AKWF..:Load Random AKWF Sample",invoke=function() load_random_akwf_sample(1) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:AKWF..:Load Random amount (1...12) of AKWF Samples",invoke=function() load_random_akwf_sample("random") end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti..:AKWF..:Load 02 AKWF Samples",invoke=function() load_random_akwf_sample(2) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:AKWF..:Load 05 AKWF Samples",invoke=function() load_random_akwf_sample(5) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:AKWF..:Load 12 AKWF Samples",invoke=function() load_random_akwf_sample(12) end}
renoise.tool():add_menu_entry{name="--Disk Browser Files:Paketti..:AKWF..:Load 05 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:AKWF..:Load 05 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(5) DrumKitToOverlay(1) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:AKWF..:Load 12 AKWF Samples with Overlap Random",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(2) end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:AKWF..:Load 12 AKWF Samples with Overlap Cycle",invoke=function() load_random_akwf_sample(12) DrumKitToOverlay(1) end}

renoise.tool():add_keybinding{name="Global:Paketti:Load 04 AKWF Samples (XY)",invoke=function() load_random_akwf_sample(4)
  for i = 1,#renoise.song().selected_instrument.samples do
  renoise.song().selected_instrument.samples[i].volume = 0
  end
  renoise.song().selected_instrument.volume=0.25
  showXyPaddialog()
   end}
  
  
  --[[local function generate_akwf_txt()
    local tool_folder = renoise.tool().bundle_path .. "AKWF/"
    local output_file = tool_folder .. "akwf.txt"
    local file = io.open(output_file, "w")
  
    local function scan_folder(path, relative_path)
      for entry in io.popen('ls "' .. path .. '"'):lines() do
        local full_entry_path = path .. entry
        local relative_entry_path = relative_path .. entry
  
        if entry:match("%.wav$") then
          file:write(relative_entry_path .. "\n")
        elseif io.popen('ls -d "' .. full_entry_path .. '"'):lines()() then
          scan_folder(full_entry_path .. "/", relative_entry_path .. "/")
        end
      end
    end
  
    scan_folder(tool_folder, "")
    file:close()
    renoise.app():show_status("akwf.txt generated successfully in " .. tool_folder)
  end
  
  generate_akwf_txt()
  
  ]]--
  