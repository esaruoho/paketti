-- Function to combine multiple sample buffers into wavetable
function PakettiWavetablerCombineSamplesIntoWavetable(samples, use_loop)
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
  
  -- Set loop points based on use_loop parameter
  new_sample.loop_start = 1
  new_sample.loop_end = use_loop and frames_per_sample or total_frames
  
  return new_sample
end

-- Modified function to handle both looped and non-looped versions
function PakettiWavetablerCreateRandomAKWFWavetable(num_samples, use_loop)
  -- Default to 64 samples if not specified
  num_samples = num_samples or 64
  -- Default to false if not specified
  use_loop = use_loop or false

  local tool_path = renoise.tool().bundle_path
  local akwf_path = tool_path .. "AKWF/"
  local akwf_list_path = akwf_path .. "akwf.txt"
  local akwf_file = io.open(akwf_list_path, "r")
  if not akwf_file then
    renoise.app():show_status("Could not find AKWF sample list")
    return
  end

  local wav_files = {}
  for line in akwf_file:lines() do
    table.insert(wav_files, akwf_path .. line)
  end
  akwf_file:close()

  if #wav_files == 0 then
    renoise.app():show_status("No AKWF samples found")
    return
  end

  -- Create new instrument
  pakettiPreferencesDefaultInstrumentLoader()
  local instrument = renoise.song().selected_instrument
  local collected_samples = {}

  for i = 1, num_samples do
    local random_index = math.random(1, #wav_files)
    local selected_file = wav_files[random_index]
    
    local sample = instrument:insert_sample_at(i)
    if sample.sample_buffer:load_from(selected_file) then
      table.insert(collected_samples, sample)
    end
  end

  -- Use appropriate combine function based on use_loop parameter
  local wavetable = PakettiWavetablerCombineSamplesIntoWavetable(collected_samples, use_loop)
  
  -- Clean up the temporary samples, but keep the wavetable
  for i = #instrument.samples, 2, -1 do
    instrument:delete_sample_at(i)
  end

  if wavetable then
    wavetable.name = string.format("Random AKWF Wavetable (%03d%s)", 
      num_samples, 
      use_loop and "+loop" or "")
    instrument.name = string.format("Random AKWF Wavetable (%03d%s)", 
      num_samples, 
      use_loop and "+loop" or "")
    wavetable.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    renoise.app():show_status(string.format("Created %sAKWF wavetable from %d random samples", 
      use_loop and "looped " or "", num_samples))
  end
  PakettiFillPitchStepperDigits(0.015,64)
end

renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (032)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(32, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (064)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(64, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (128)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(128, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (256)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(256, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (032,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(32, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (064,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(64, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (128,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(128, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random AKWF Wavetable (256,loop)",invoke=function() PakettiWavetablerCreateRandomAKWFWavetable(256, true) end}




-- Function to calculate and set loop points for a specific cycle index
function PakettiWavetablerSetLoopPointsForCycle(sample, cycle_index)
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
function PakettiWavetablerMoveLoopCycle(offset)
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer then return end
  
  local frames_per_cycle = sample.loop_end - sample.loop_start + 1
  local current_cycle = math.floor(sample.loop_start / frames_per_cycle) + 1
  
  PakettiWavetablerSetLoopPointsForCycle(sample, current_cycle + offset)
end

-- Function to set cycle from MIDI CC value (0-127)
function PakettiWavetablerSetCycleFromMidi(midi_value)
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer then return end
  
  local frames_per_cycle = sample.loop_end - sample.loop_start + 1
  local total_frames = sample.sample_buffer.number_of_frames
  local num_cycles = math.floor(total_frames / frames_per_cycle)
  
  -- Map MIDI value (0-127) to cycle index (1-num_cycles)
  local cycle_index = math.floor((midi_value / 127) * num_cycles) + 1
  PakettiWavetablerSetLoopPointsForCycle(sample, cycle_index)
end

renoise.tool():add_keybinding{name="Global:Paketti:Next Wavetable Cycle",invoke=function() PakettiWavetablerMoveLoopCycle(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Previous Wavetable Cycle",invoke=function() PakettiWavetablerMoveLoopCycle(-1) end}
renoise.tool():add_midi_mapping{name="Paketti:Next Wavetable Cycle",invoke=function(message) if message.boolean_value then PakettiWavetablerMoveLoopCycle(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Previous Wavetable Cycle",invoke=function(message) if message.boolean_value then PakettiWavetablerMoveLoopCycle(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Select Wavetable Cycle [Set]",invoke=function(message) if message.is_value then PakettiWavetablerSetCycleFromMidi(message.value) end end}

