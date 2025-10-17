-- PakettiOctaCycle.lua
-- Generates multiple octave versions of single-cycle waveforms for Octatrack
-- Based on OctaCycle by Spencer Williams
-- Allows accessing wider pitch ranges on Octatrack (which can only pitch +/- one octave directly)

local ot_sample_rate = 44100
local ot_min_slice_length = 64

-- Round function for Lua 5.1 compatibility
local function round(x)
  return math.floor(x + 0.5)
end

-- Convert cents to frequency ratio
function cents_to_ratio(cents)
  return 2 ^ (cents / 1200)
end

-- Calculate frequency for a given octave, note, and cents offset
-- Uses A4 = 440Hz as reference (octave 5, note 9)
function calculate_pitch(octave, note, offset)
  return (2 ^ (octave - 5)) * 440 * cents_to_ratio(300 + (100 * note) + offset)
end

-- Linear interpolation for resampling
function lerp(t, a, b)
  return a * (1 - t) + b * t
end

-- Resample a single cycle to a specific target length
function resample_cycle(source_data, source_length, target_length, channels)
  local resampled = {}
  
  for ch = 1, channels do
    resampled[ch] = {}
    for i = 1, target_length do
      local source_pos = (i - 1) * source_length / target_length + 1
      local floor_pos = math.floor(source_pos)
      local frac = source_pos - floor_pos
      
      local sample1 = source_data[ch][floor_pos] or 0
      local sample2 = source_data[ch][(floor_pos % source_length) + 1] or 0
      
      resampled[ch][i] = lerp(frac, sample1, sample2)
    end
  end
  
  return resampled
end

-- Main OctaCycle generation function
function PakettiOctaCycle()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local sample = song.selected_sample
  
  -- Validation checks
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected. Please select a single-cycle waveform.")
    return
  end
  
  local buffer = sample.sample_buffer
  local source_length = buffer.number_of_frames
  local channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  
  -- Warn if sample doesn't look like a single cycle
  if source_length > sample_rate then  -- More than 1 second
    local result = renoise.app():show_prompt("Long Sample Warning", 
      "Selected sample is " .. string.format("%.2f", source_length / sample_rate) .. " seconds long.\n" ..
      "OctaCycle works best with short single-cycle waveforms.\n\nContinue anyway?",
      {"Continue", "Cancel"})
    if result == "Cancel" then
      return
    end
  end
  
  print("PakettiOctaCycle: Processing sample '" .. (sample.name or "Unnamed") .. "'")
  print(string.format("PakettiOctaCycle: Source: %d frames, %d channels, %.1fkHz", 
    source_length, channels, sample_rate))
  
  -- Show parameter dialog
  local vb = renoise.ViewBuilder()
  local dialog_content
  local param_dialog = nil
  
  -- Default parameters
  local params = {
    root_note = 1,      -- C (0-11, where 0=C, 1=C#, etc.)
    cents_offset = 0,   -- -100 to +100 cents
    octave_low = 1,     -- 0-7
    octave_high = 7,    -- 0-7
    export_after = true -- Export to OT after creation
  }
  
  local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  
  dialog_content = vb:column {
    margin = 15,
    
    

    vb:text {
      text = "Generate sliced samples with one slice per octave, allowing wider pitch range on Octatrack"
    },
    
    vb:space { height = 5 },
    
    -- Root note selection
    vb:row {
      vb:text {
        text = "Root Note",
        width = 100
      },
      vb:popup {
        items = note_names,
        value = params.root_note,
        width = 60,
        notifier = function(value)
          params.root_note = value - 1  -- Convert to 0-based
        end
      }
    },
    
    -- Cents offset
    vb:row {
      
      vb:text {
        text = "Cents Offset",
        width = 100
      },
      vb:valuebox {
        min = -100,
        max = 100,
        value = params.cents_offset,
        width = 60,
        notifier = function(value)
          params.cents_offset = value
        end
      },
      vb:text {
        text = "cents"
      }
    },
    
    -- Octave range
    vb:row {
      
      vb:text {
        text = "Octave Range",
        width = 100
      },
      vb:valuebox {
        min = 0,
        max = 7,
        value = params.octave_low,
        width = 60,
        notifier = function(value)
          params.octave_low = value
          if params.octave_low > params.octave_high then
            params.octave_high = params.octave_low
            vb.views.octave_high.value = params.octave_high
          end
        end
      },
      vb:text { text = "to" },
      vb:valuebox {
        id = "octave_high",
        min = 0,
        max = 7,
        value = params.octave_high,
        width = 60,
        notifier = function(value)
          params.octave_high = value
          if params.octave_high < params.octave_low then
            params.octave_low = params.octave_high
            vb.views.octave_low.value = params.octave_low
          end
        end
      }
    },
    
    -- Export option
    vb:row {
      
      vb:checkbox {
        value = params.export_after,
        notifier = function(value)
          params.export_after = value
        end},
      vb:text {text = "Export to Octatrack (.wav + .ot) after generation"}
    },
    
    -- Info text
    vb:multiline_text {
      text = "Octatrack normally can only pitch samples +/- one octave. OctaCycle creates multiple octave versions as slices to overcome this limitation. Works best with short single-cycle waveforms.",
      width = 350,
      height = 80,
    },
    
    
    -- Buttons
    vb:horizontal_aligner {
      mode = "distribute",
      vb:button {
        text = "Generate",
        width = 80,
        released = function()
          if param_dialog and param_dialog.visible then
            param_dialog:close()
          end
          generate_octacycle(sample, params)
        end
      },
      vb:button {
        text = "Cancel",
        width = 80,
        released = function()
          if param_dialog and param_dialog.visible then
            param_dialog:close()
          end
        end
      }
    }
  }
  
  param_dialog = renoise.app():show_custom_dialog("OctaCycle Generator", dialog_content)
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Generate the actual OctaCycle sample
function generate_octacycle(source_sample, params)
  local song = renoise.song()
  local source_buffer = source_sample.sample_buffer
  local source_length = source_buffer.number_of_frames
  local channels = source_buffer.number_of_channels
  
  print("PakettiOctaCycle: Generating octave range " .. params.octave_low .. " to " .. params.octave_high)
  print("PakettiOctaCycle: Root note: " .. ({"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"})[params.root_note + 1])
  print("PakettiOctaCycle: Cents offset: " .. params.cents_offset)
  
  -- Convert to 44.1kHz 16-bit if needed (like drumkit generator)
  local sample_rate = source_buffer.sample_rate
  local needs_conversion = (sample_rate ~= 44100) or (source_buffer.bit_depth ~= 16)
  
  if needs_conversion then
    print(string.format("PakettiOctaCycle: Converting %.1fkHz/%dbit to 44.1kHz/16bit for Octatrack compatibility", 
      sample_rate, source_buffer.bit_depth))
    
    -- Create temporary instrument for conversion
    local temp_instrument_index = song.selected_instrument_index + 1
    song:insert_instrument_at(temp_instrument_index)
    song.selected_instrument_index = temp_instrument_index
    local temp_instrument = song.selected_instrument
    
    -- Copy sample to temp instrument
    local temp_sample = temp_instrument:insert_sample_at(1)
    temp_sample.sample_buffer:create_sample_data(
      source_buffer.sample_rate,
      source_buffer.bit_depth,
      source_buffer.number_of_channels,
      source_buffer.number_of_frames
    )
    temp_sample.sample_buffer:prepare_sample_data_changes()
    
    -- Copy sample data
    for ch = 1, channels do
      for frame = 1, source_length do
        temp_sample.sample_buffer:set_sample_data(ch, frame, source_buffer:sample_data(ch, frame))
      end
    end
    temp_sample.sample_buffer:finalize_sample_data_changes()
    
    -- Convert using RenderSampleAtNewRate (same as drumkit generator)
    song.selected_sample_index = 1
    local success = pcall(function()
      RenderSampleAtNewRate(44100, 16)
    end)
    
    if success then
      -- Update our references to use the converted sample
      source_sample = temp_instrument.samples[1]
      source_buffer = source_sample.sample_buffer
      source_length = source_buffer.number_of_frames
      channels = source_buffer.number_of_channels
      sample_rate = source_buffer.sample_rate
      
      print(string.format("PakettiOctaCycle: Conversion successful - now %d frames, %d channels, %.1fkHz, %dbit", 
        source_length, channels, sample_rate, source_buffer.bit_depth))
    else
      print("PakettiOctaCycle: Conversion failed, using original format")
    end
    
    -- Clean up temp instrument and restore original selection
    song:delete_instrument_at(temp_instrument_index)
    song.selected_instrument_index = song.selected_instrument_index - 1
  else
    print("PakettiOctaCycle: Sample already in correct format (44.1kHz/16bit)")
  end
  
  -- Extract source sample data
  local source_data = {}
  for ch = 1, channels do
    source_data[ch] = {}
    for frame = 1, source_length do
      source_data[ch][frame] = source_buffer:sample_data(ch, frame)
    end
  end
  
  -- Calculate segments for each octave
  local segments = {}
  local total_frames = 0
  local slice_positions = {}
  
  for octave = params.octave_low, params.octave_high do
    -- Calculate target frequency and cycle length for this octave
    local frequency = calculate_pitch(octave, params.root_note, params.cents_offset)
    local cycle_length = round(ot_sample_rate / frequency)
    
    -- Ensure minimum slice length by repeating cycles if needed
    local repeat_count = math.ceil(ot_min_slice_length / cycle_length)
    local segment_length = cycle_length * repeat_count
    
    table.insert(segments, {
      octave = octave,
      frequency = frequency,
      cycle_length = cycle_length,
      repeat_count = repeat_count,
      segment_length = segment_length
    })
    
    table.insert(slice_positions, total_frames + 1)  -- 1-based slice position
    total_frames = total_frames + segment_length
    
    print(string.format("PakettiOctaCycle: Octave %d: %.2fHz, %d samples/cycle, %dx repeats = %d samples", 
      octave, frequency, cycle_length, repeat_count, segment_length))
  end
  
  print(string.format("PakettiOctaCycle: Total length: %d frames (%.2f seconds)", total_frames, total_frames / ot_sample_rate))
  
  -- Create new instrument for OctaCycle
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local octacycle_instrument = song.selected_instrument
  
  octacycle_instrument.name = "OctaCycle " .. (source_sample.name or "Unnamed")
  
  -- Create combined sample buffer
  if octacycle_instrument.samples[1] then
    octacycle_instrument:delete_sample_at(1)
  end
  
  local combined_sample = octacycle_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(ot_sample_rate, 16, channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Generate and combine all octave segments
  renoise.app():show_status("OctaCycle: Generating octave segments...")
  local current_pos = 1
  
  for i, segment in ipairs(segments) do
    -- Resample source cycle to target length
    local resampled = resample_cycle(source_data, source_length, segment.cycle_length, channels)
    
    -- Repeat the cycle to fill segment length
    for rep = 1, segment.repeat_count do
      for frame = 1, segment.cycle_length do
        for ch = 1, channels do
          local sample_value = resampled[ch][frame] or 0
          combined_sample.sample_buffer:set_sample_data(ch, current_pos + frame - 1, sample_value)
        end
      end
      current_pos = current_pos + segment.cycle_length
    end
    
    renoise.app():show_status(string.format("OctaCycle: Generated octave %d/%d", i, #segments))
  end
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = octacycle_instrument.name
  
  -- Add slice markers
  renoise.app():show_status("OctaCycle: Adding slice markers...")
  for i, pos in ipairs(slice_positions) do
    combined_sample:insert_slice_marker(pos)
  end
  
  song.selected_sample_index = 1
  
  -- Store OctaCycle metadata in sample name for export compatibility
  local root_note_name = ({"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"})[params.root_note + 1]
  local metadata = string.format("OctaCycle[%s%+d:%d-%d]", 
    root_note_name, params.cents_offset, params.octave_low, params.octave_high)
  combined_sample.name = combined_sample.name .. " " .. metadata
  
  -- Export to Octatrack FIRST (before key mappings) to get pure OctaCycle slicing
  if params.export_after then
    renoise.app():show_status("OctaCycle: Exporting to Octatrack...")
    export_octacycle_to_octatrack(combined_sample, segments)
  end
  
  -- NOW isolate slices to individual samples and set up key mappings
  renoise.app():show_status("OctaCycle: Creating individual samples from slices...")
  
  -- Remember the original instrument index
  local original_instrument_index = song.selected_instrument_index
  
  -- Run PakettiIsolateSlicesToInstrument to create individual samples
  PakettiIsolateSlicesToInstrument()
  
  -- Select the newly created instrument (should be the next one)
  local new_instrument_index = song.selected_instrument_index
  local new_instrument = song.selected_instrument
  
  -- Set up key mappings for each individual sample
  renoise.app():show_status("OctaCycle: Setting up key mappings...")
  
  for i, segment in ipairs(segments) do
    local octave = segment.octave
    local sample_index = i  -- 1-based sample index
    
    -- Check if we have this sample
    if new_instrument.samples[sample_index] then
      local sample = new_instrument.samples[sample_index]
      
      -- Calculate note range for this octave (C to B)
      local octave_start_note = octave * 12  -- C of this octave
      local octave_end_note = octave_start_note + 11  -- B of this octave
      
      -- Clamp to valid MIDI range (0-119)
      octave_start_note = math.max(0, math.min(119, octave_start_note))
      octave_end_note = math.max(0, math.min(119, octave_end_note))
      
      -- Ensure valid range
      if octave_start_note <= octave_end_note then
        -- Set up sample mapping for this octave range
        sample.sample_mapping.note_range = {octave_start_note, octave_end_note}
        sample.sample_mapping.base_note = params.root_note + octave_start_note  -- Root note transposed to this octave
        
        -- Set loop mode to Forward
        sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
        
        print(string.format("PakettiOctaCycle: Sample %d (octave %d) mapped to notes %d-%d (C-%d to B-%d), loop mode: Forward", 
          sample_index, octave, octave_start_note, octave_end_note, octave, octave))
      end
    end
  end
  
  -- Switch to keyzone mappings to show the created key mappings
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES
  
  local status_msg = string.format("OctaCycle created: %d octaves (%s to %s), %d slices with key mappings", 
    #segments, 
    root_note_name .. params.octave_low, 
    root_note_name .. params.octave_high,
    #slice_positions)
  
  renoise.app():show_status(status_msg)
  print("PakettiOctaCycle: " .. status_msg)
end

-- Quick OctaCycle with default parameters (C, 0 cents, octaves 1-7)
function PakettiOctaCycleQuick()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected. Please select a single-cycle waveform.")
    return
  end
  
  local params = {
    root_note = 0,      -- C
    cents_offset = 0,   -- No offset
    octave_low = 1,     -- Octave 1
    octave_high = 7,    -- Octave 7
    export_after = false -- Don't auto-export
  }
  
  generate_octacycle(sample, params)
end

-- OctaCycle-specific .ot export function based on the Clojure OctaCycle implementation
function export_octacycle_to_octatrack(sample, segments)
  -- Create .ot file using OctaCycle method (based on Clojure implementation)
  local function create_octacycle_ot_data(segments)
    -- OctaCycle .ot template structure (832 bytes total)
    -- Based on the Clojure template with these default values:
    -- tempo = 0xb40 (120 * 24), trimLen = 0x3, loopLen = 0x3, 
    -- stretch = 0x0, loop = 0x1, gain = 0x30, quantize = 0xff
    local ot_data = {}
    
    -- Initialize with zeros
    for i = 1, 832 do
      ot_data[i] = 0
    end
    
    -- Header: "FORM" + length + "DPS1" + "SMPA" (bytes 1-16)
    local header = {0x46, 0x4F, 0x52, 0x4D, 0x00, 0x00, 0x00, 0x00, 0x44, 0x50, 0x53, 0x31, 0x53, 0x4D, 0x50, 0x41}
    for i = 1, 16 do
      ot_data[i] = header[i]
    end
    
    -- Unknown section (bytes 17-23)
    local unknown = {0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00}
    for i = 1, 7 do
      ot_data[16 + i] = unknown[i]
    end
    
    -- Main parameters (bytes 24-55)
    -- tempo (32-bit big-endian) - 120 BPM * 24 = 0xb40
    local tempo = 120 * 24
    ot_data[24] = math.floor(tempo / 0x1000000) % 0x100
    ot_data[25] = math.floor(tempo / 0x10000) % 0x100
    ot_data[26] = math.floor(tempo / 0x100) % 0x100
    ot_data[27] = tempo % 0x100
    
    -- trimLen (32-bit) - set to 0x3 (default from template)
    ot_data[31] = 0x03
    
    -- loopLen (32-bit) - set to 0x3 (default from template)  
    ot_data[35] = 0x03
    
    -- stretch (32-bit) - 0x0 (Off)
    -- (already zero)
    
    -- loop (32-bit) - 0x1 (Normal)
    ot_data[47] = 0x01
    
    -- gain (16-bit) - 0x30 (+0 dB)
    ot_data[49] = 0x30
    
    -- quantize (8-bit) - 0xff (Direct)
    ot_data[50] = 0xff
    
    -- trimStart (32-bit) - 0x0
    -- (already zero)
    
    -- trimEnd (32-bit) - will be set to total sample length
    local total_length = 0
    for _, seg in ipairs(segments) do
      total_length = total_length + seg.segment_length
    end
    ot_data[55] = math.floor(total_length / 0x1000000) % 0x100
    ot_data[56] = math.floor(total_length / 0x10000) % 0x100
    ot_data[57] = math.floor(total_length / 0x100) % 0x100
    ot_data[58] = total_length % 0x100
    
    -- loopPoint (32-bit) - 0x0
    -- (already zero)
    
    -- Write slice data starting at offset 0x3a (58 + 1 = 59 in 1-based indexing)
    local slice_start = 0
    local base_offset = 59  -- 0x3a + 1 for 1-based indexing
    
    for i, segment in ipairs(segments) do
      local slice_end = slice_start + segment.segment_length
      local offset = base_offset + (i - 1) * 12  -- 3 * 4 bytes per slice
      
      -- start_point (32-bit big-endian)
      ot_data[offset] = math.floor(slice_start / 0x1000000) % 0x100
      ot_data[offset + 1] = math.floor(slice_start / 0x10000) % 0x100
      ot_data[offset + 2] = math.floor(slice_start / 0x100) % 0x100
      ot_data[offset + 3] = slice_start % 0x100
      
      -- end_point (32-bit big-endian)
      ot_data[offset + 4] = math.floor(slice_end / 0x1000000) % 0x100
      ot_data[offset + 5] = math.floor(slice_end / 0x10000) % 0x100
      ot_data[offset + 6] = math.floor(slice_end / 0x100) % 0x100
      ot_data[offset + 7] = slice_end % 0x100
      
      -- loop_point (32-bit) - 0xffffffff (following Clojure code)
      ot_data[offset + 8] = 0xff
      ot_data[offset + 9] = 0xff
      ot_data[offset + 10] = 0xff
      ot_data[offset + 11] = 0xff
      
      slice_start = slice_end
    end
    
    -- Write slice count at offset 0x33a (826 + 1 = 827 in 1-based indexing)
    local slice_count = #segments
    ot_data[827] = math.floor(slice_count / 0x1000000) % 0x100
    ot_data[828] = math.floor(slice_count / 0x10000) % 0x100
    ot_data[829] = math.floor(slice_count / 0x100) % 0x100
    ot_data[830] = slice_count % 0x100
    
    -- Calculate checksum from 0x10 to 0x33e (17 to 830 in 1-based indexing)
    -- Following the Clojure method exactly
    local checksum = 0
    for i = 17, 830 do
      checksum = checksum + ot_data[i]
    end
    checksum = checksum % 0x10000  -- 16-bit wrap
    
    -- Write checksum at offset 0x33e (830 + 1 = 831 in 1-based indexing)
    ot_data[831] = math.floor(checksum / 0x100) % 0x100
    ot_data[832] = checksum % 0x100
    
    return ot_data
  end
  
  -- Get export filename
  local filename = renoise.app():prompt_for_filename_to_write("*.wav", "Export OctaCycle to Octatrack...")
  
  if not filename or filename == "" then
    return -- User cancelled
  end
  
  -- Export .wav file
  local wav_filename = filename
  local base_name = filename:match("(.+)%..+$") or filename
  if not filename:match("%.wav$") then
    wav_filename = base_name .. ".wav"
  end
  
  sample.sample_buffer:save_as(wav_filename, "wav")
  
  -- Create and export .ot file using OctaCycle method
  local ot_data = create_octacycle_ot_data(segments)
  local ot_filename = base_name .. ".ot"
  
  local f = io.open(ot_filename, "wb")
  if f then
    for i = 1, 832 do
      f:write(string.char(ot_data[i]))
    end
    f:close()
    
    print("OctaCycle: Exported " .. wav_filename .. " + " .. ot_filename)
    renoise.app():show_status("OctaCycle exported: " .. ot_filename:match("([^/\\]+)$"))
  else
    renoise.app():show_error("Could not create .ot file: " .. ot_filename)
  end
end

-- Export current OctaCycle sample to Octatrack (if it was generated by OctaCycle)
function PakettiOctaCycleExport()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected.")
    return
  end
  
  -- Check if this sample was generated by OctaCycle (look for metadata in name)
  local metadata = sample.name:match("OctaCycle%[([^%]]+)%]")
  if not metadata then
    renoise.app():show_error("Selected sample doesn't appear to be generated by OctaCycle.\nUse 'Generate OctaCycle...' to create OctaCycle samples.")
    return
  end
  
  -- Parse metadata to reconstruct segments
  local root_note_name, cents_offset, octave_low, octave_high = metadata:match("([A-G]#?)([%+%-]?%d+):(%d+)%-(%d+)")
  if not root_note_name then
    renoise.app():show_error("Could not parse OctaCycle metadata from sample name.")
    return
  end
  
  -- Convert note name back to number
  local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local root_note = nil
  for i, name in ipairs(note_names) do
    if name == root_note_name then
      root_note = i - 1  -- Convert to 0-based
      break
    end
  end
  
  if not root_note then
    renoise.app():show_error("Could not parse root note from OctaCycle metadata.")
    return
  end
  
  cents_offset = tonumber(cents_offset) or 0
  octave_low = tonumber(octave_low) or 1
  octave_high = tonumber(octave_high) or 7
  
  print("PakettiOctaCycleExport: Reconstructing segments for export")
  print("PakettiOctaCycleExport: Root note: " .. root_note_name .. ", Cents: " .. cents_offset .. ", Octaves: " .. octave_low .. "-" .. octave_high)
  
  -- Reconstruct segments based on slice markers
  local segments = {}
  local slice_markers = sample.slice_markers
  local sample_length = sample.sample_buffer.number_of_frames
  
  if #slice_markers == 0 then
    renoise.app():show_error("OctaCycle sample has no slice markers. Cannot export.")
    return
  end
  
  -- Calculate segments from slice positions
  for i = 1, #slice_markers do
    local octave = octave_low + i - 1
    local frequency = calculate_pitch(octave, root_note, cents_offset)
    local cycle_length = round(ot_sample_rate / frequency)
    
    local slice_start = slice_markers[i] - 1  -- Convert to 0-based
    local slice_end
    if i < #slice_markers then
      slice_end = slice_markers[i + 1] - 1
    else
      slice_end = sample_length
    end
    
    local segment_length = slice_end - slice_start
    local repeat_count = math.max(1, math.ceil(ot_min_slice_length / cycle_length))
    
    table.insert(segments, {
      octave = octave,
      frequency = frequency,
      cycle_length = cycle_length,
      repeat_count = repeat_count,
      segment_length = segment_length
    })
  end
  
  export_octacycle_to_octatrack(sample, segments)
end

-- Menu entries
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Octatrack:Generate OctaCycle...",invoke=function() PakettiOctaCycle() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Quick OctaCycle (C, Oct 1-7)",invoke=function() PakettiOctaCycleQuick() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Export OctaCycle to Octatrack",invoke=function() PakettiOctaCycleExport() end}

renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Octatrack:Generate OctaCycle...",invoke=function() PakettiOctaCycle() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Quick OctaCycle (C, Oct 1-7)",invoke=function() PakettiOctaCycleQuick() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Export OctaCycle to Octatrack",invoke=function() PakettiOctaCycleExport() end}


-- Keybindings
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Generate OctaCycle for Octatrack",invoke=function() PakettiOctaCycle() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Quick OctaCycle for Octatrack",invoke=function() PakettiOctaCycleQuick() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Export OctaCycle to Octatrack",invoke=function() PakettiOctaCycleExport() end}

 