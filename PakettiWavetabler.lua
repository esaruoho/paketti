-- Function to combine multiple sample buffers into wavetable and set loop points
function combine_samples_into_wavetable_with_loop(samples)
  if #samples == 0 then
    renoise.app():show_status("No samples provided to combine")
    return nil
  end

  -- Get properties from first sample for reference
  local first_sample = samples[1]
  local sample_rate = first_sample.sample_buffer.sample_rate
  local bit_depth = first_sample.sample_buffer.bit_depth
  local frames_per_sample = first_sample.sample_buffer.number_of_frames
  local total_frames = frames_per_sample * #samples

  -- Store the original single cycle length
  local loop_length = frames_per_sample

  -- Create new sample buffer for the wavetable
  local instrument = renoise.song().selected_instrument
  local new_sample = instrument:insert_sample_at(1)
  local wavetable_buffer = new_sample.sample_buffer

  -- Create the combined sample data buffer
  wavetable_buffer:create_sample_data(sample_rate, bit_depth, 1, total_frames)
  wavetable_buffer:prepare_sample_data_changes()

  -- Copy each sample's data into the wavetable buffer
  for i, sample in ipairs(samples) do
    local start_frame = (i-1) * frames_per_sample + 1
    for frame = 1, frames_per_sample do
      local value = sample.sample_buffer:sample_data(1, frame)
      wavetable_buffer:set_sample_data(1, start_frame + frame - 1, value)
    end
  end

  wavetable_buffer:finalize_sample_data_changes()
  
  -- Set loop points based on original single cycle length
  new_sample.loop_start = 1
  new_sample.loop_end = loop_length
  
  return new_sample
end

-- Function to load specified number of random AKWF samples and create wavetable with proper loop points
function create_random_akwf_wavetable_with_loop(num_samples)
  -- Default to 64 if no number specified
  num_samples = num_samples or 64
  
  -- Reference the existing AKWF file loading code
  local valid_extensions = { ".wav" }
  
  local function is_valid_audio_file(filename)
    for _, ext in ipairs(valid_extensions) do
      if filename:lower():match(ext .. "$") then
        return true
      end
    end
    return false
  end

  -- Get the AKWF folder path from the tool's bundle path
  local tool_path = renoise.tool().bundle_path
  local akwf_path = tool_path .. "AKWF/"

  -- Read and parse the akwf.txt file that contains all sample paths
  local akwf_list_path = akwf_path .. "akwf.txt"
  local akwf_file = io.open(akwf_list_path, "r")
  if not akwf_file then
    renoise.app():show_status("Could not find AKWF sample list")
    return
  end

  -- Read all AKWF file paths
  local wav_files = {}
  for line in akwf_file:lines() do
    if is_valid_audio_file(line) then
      table.insert(wav_files, akwf_path .. line)
    end
  end
  akwf_file:close()

  if #wav_files == 0 then
    renoise.app():show_status("No AKWF samples found")
    return
  end

  -- Create temporary instrument to hold our samples
  local temp_instrument = renoise.song():insert_instrument_at(renoise.song().selected_instrument_index)
  local collected_samples = {}

  -- Load specified number of random samples
  for i = 1, num_samples do
    local random_index = math.random(1, #wav_files)
    local selected_file = wav_files[random_index]
    
    local sample = temp_instrument:insert_sample_at(i)
    if sample.sample_buffer:load_from(selected_file) then
      table.insert(collected_samples, sample)
    end
  end

  -- Combine all samples into wavetable
  local wavetable = combine_samples_into_wavetable_with_loop(collected_samples)
  
  -- Delete all samples except the first one (our wavetable)
  for i = #temp_instrument.samples, 2, -1 do
    temp_instrument:delete_sample_at(i)
  end

  if wavetable then
    wavetable.name = "AKWF Wavetable (Looped)"
    wavetable.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    renoise.app():show_status(string.format("Created looped AKWF wavetable from %d random samples", num_samples))
  end
end

-- Regular version (full sample loop)
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (032)", invoke = function() create_random_akwf_wavetable(32) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (064)", invoke = function() create_random_akwf_wavetable(64) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (128)", invoke = function() create_random_akwf_wavetable(128) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (256)", invoke = function() create_random_akwf_wavetable(256) end}

renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (032)", invoke = function() create_random_akwf_wavetable(32) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (064)", invoke = function() create_random_akwf_wavetable(64) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (128)", invoke = function() create_random_akwf_wavetable(128) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (256)", invoke = function() create_random_akwf_wavetable(256) end}

-- Single-cycle loop version
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (032,loop)", invoke = function() create_random_akwf_wavetable_with_loop(32) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (064,loop)", invoke = function() create_random_akwf_wavetable_with_loop(64) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (128,loop)", invoke = function() create_random_akwf_wavetable_with_loop(128) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create Random AKWF Wavetable (256,loop)", invoke = function() create_random_akwf_wavetable_with_loop(256) end}

renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (032,loop)", invoke = function() create_random_akwf_wavetable_with_loop(32) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (064,loop)", invoke = function() create_random_akwf_wavetable_with_loop(64) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (128,loop)", invoke = function() create_random_akwf_wavetable_with_loop(128) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti..:Create Random AKWF Wavetable (256,loop)", invoke = function() create_random_akwf_wavetable_with_loop(256) end}

-- Function to calculate and set loop points for a specific cycle index
function set_loop_points_for_cycle(sample, cycle_index)
  if not sample or not sample.sample_buffer then return end
  
  local frames_per_cycle = sample.loop_end - sample.loop_start + 1
  local total_frames = sample.sample_buffer.number_of_frames
  local num_cycles = math.floor(total_frames / frames_per_cycle)
  
  -- Ensure cycle_index is within bounds
  cycle_index = math.max(1, math.min(cycle_index, num_cycles))
  
  local new_start = 1 + (cycle_index - 1) * frames_per_cycle
  local new_end = new_start + frames_per_cycle - 1
  
  sample.loop_start = new_start
  sample.loop_end = new_end
  
  renoise.app():show_status(string.format("Loop cycle: %d/%d", cycle_index, num_cycles))
end

-- Function to move to next/previous cycle
function move_loop_cycle(offset)
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer then return end
  
  local frames_per_cycle = sample.loop_end - sample.loop_start + 1
  local current_cycle = math.floor(sample.loop_start / frames_per_cycle) + 1
  
  set_loop_points_for_cycle(sample, current_cycle + offset)
end

-- Function to set cycle from MIDI CC value (0-127)
function set_cycle_from_midi(midi_value)
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer then return end
  
  local frames_per_cycle = sample.loop_end - sample.loop_start + 1
  local total_frames = sample.sample_buffer.number_of_frames
  local num_cycles = math.floor(total_frames / frames_per_cycle)
  
  -- Map MIDI value (0-127) to cycle index (1-num_cycles)
  local cycle_index = math.floor((midi_value / 127) * num_cycles) + 1
  set_loop_points_for_cycle(sample, cycle_index)
end

-- Add keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Next Wavetable Cycle",
  invoke = function() move_loop_cycle(1) end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Previous Wavetable Cycle",
  invoke = function() move_loop_cycle(-1) end
}

-- Add MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Next Wavetable Cycle",
  invoke = function(message) 
    if message.boolean_value then 
      move_loop_cycle(1)
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Previous Wavetable Cycle",
  invoke = function(message)
    if message.boolean_value then 
      move_loop_cycle(-1)
    end
  end
}

-- Add MIDI CC mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Select Wavetable Cycle [Set]",
  invoke = function(message)
    if message.is_value then
      set_cycle_from_midi(message.value)
    end
  end
}
