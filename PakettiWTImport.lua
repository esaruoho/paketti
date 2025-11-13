-- PakettiWTImport.lua
-- Wavetable Import for Paketti
-- Supports wavetable files with 'vawt' header format

local function read_uint32_le(file)
  local b1, b2, b3, b4 = file:read(1), file:read(1), file:read(1), file:read(1)
  if not b1 or not b2 or not b3 or not b4 then
    error("Unexpected end of file while reading uint32")
  end
  local bytes = {b1:byte(), b2:byte(), b3:byte(), b4:byte()}
  return bytes[1] + (bytes[2] * 256) + (bytes[3] * 65536) + (bytes[4] * 16777216)
end

local function read_uint16_le(file)
  local b1, b2 = file:read(1), file:read(1)
  if not b1 or not b2 then
    error("Unexpected end of file while reading uint16")
  end
  local bytes = {b1:byte(), b2:byte()}
  return bytes[1] + (bytes[2] * 256)
end

local function read_int16_le(file)
  local value = read_uint16_le(file)
  if value >= 32768 then
    return value - 65536
  end
  return value
end

-- Bit operations for Lua 5.1 compatibility
local function band(a, b)
  local result = 0
  local bitval = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bitval
    end
    bitval = bitval * 2
    a = math.floor(a / 2)
    b = math.floor(b / 2)
  end
  return result
end

local function bor(a, b)
  local result = 0
  local bitval = 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bitval
    end
    bitval = bitval * 2
    a = math.floor(a / 2)
    b = math.floor(b / 2)
  end
  return result
end

local function lshift(a, b)
  return a * (2 ^ b)
end

local function rshift(a, b)
  return math.floor(a / (2 ^ b))
end

local function read_float32_le(file)
  local b1, b2, b3, b4 = file:read(1), file:read(1), file:read(1), file:read(1)
  if not b1 or not b2 or not b3 or not b4 then
    error("Unexpected end of file while reading float32")
  end
  local bytes = {b1:byte(), b2:byte(), b3:byte(), b4:byte()}
  
  -- Convert bytes to float32 (IEEE 754) - simplified approach
  local sign = band(bytes[4], 0x80) ~= 0
  local exponent = bor(lshift(band(bytes[4], 0x7F), 1), rshift(bytes[3], 7))
  local mantissa = bor(bor(lshift(band(bytes[3], 0x7F), 16), lshift(bytes[2], 8)), bytes[1])
  
  if exponent == 0 then
    if mantissa == 0 then
      return sign and -0.0 or 0.0
    else
      -- Denormalized number
      local value = mantissa * math.pow(2, -149)
      return sign and -value or value
    end
  elseif exponent == 255 then
    if mantissa == 0 then
      return sign and -math.huge or math.huge
    else
      return 0/0 -- NaN
    end
  else
    -- Normalized number
    local value = (1 + mantissa * math.pow(2, -23)) * math.pow(2, exponent - 127)
    return sign and -value or value
  end
end

local function parse_wavetable_file(filepath)
  local file = io.open(filepath, "rb")
  if not file then
    print("ERROR:","Could not open file: " .. filepath)
    return nil
  end
  
  print("DEBUG: Parsing wavetable file: " .. filepath)
  
  -- Wrap parsing in pcall for error handling
  local success, result = pcall(function()
  
  -- Read header: 'vawt' as big-endian
  local header = file:read(4)
  if header ~= "vawt" then
    file:close()
    print("ERROR:","Invalid wavetable file: missing 'vawt' header")
    return nil
  end
  print("DEBUG: Valid 'vawt' header found")
  
  -- Read wave_size (little-endian uint32)
  local wave_size = read_uint32_le(file)
  print("DEBUG: Wave size: " .. wave_size)
  
  -- Validate wave_size (must be power of 2, between 2 and 4096)
  local function is_power_of_2(n)
    return n > 0 and band(n, n - 1) == 0
  end
  
  if wave_size < 2 or wave_size > 4096 or not is_power_of_2(wave_size) then
    file:close()
    print("ERROR:","Invalid wave size: " .. wave_size .. " (must be power of 2, 2-4096)")
    return nil
  end
  
  -- Read wave_count (little-endian uint16)
  local wave_count = read_uint16_le(file)
  print("DEBUG: Wave count: " .. wave_count)
  
  -- Validate wave_count (1-512)
  if wave_count < 1 or wave_count > 512 then
    file:close()
    print("ERROR:","Invalid wave count: " .. wave_count .. " (must be 1-512)")
    return nil
  end
  
  -- Read flags (little-endian uint16)
  local flags = read_uint16_le(file)
  print("DEBUG: Flags: " .. string.format("0x%04X", flags))
  
  local is_sample = band(flags, 0x0001) ~= 0
  local is_looped = band(flags, 0x0002) ~= 0
  local is_int16 = band(flags, 0x0004) ~= 0
  local use_full_range = band(flags, 0x0008) ~= 0
  local has_metadata = band(flags, 0x0010) ~= 0
  
  print("DEBUG: Is sample: " .. tostring(is_sample))
  print("DEBUG: Is looped: " .. tostring(is_looped))
  print("DEBUG: Format: " .. (is_int16 and "int16" or "float32"))
  print("DEBUG: Full range: " .. tostring(use_full_range))
  print("DEBUG: Has metadata: " .. tostring(has_metadata))
  
  -- Read wave data
  local waves = {}
  local sample_data_size = is_int16 and (2 * wave_size * wave_count) or (4 * wave_size * wave_count)
  print("DEBUG: Reading " .. sample_data_size .. " bytes of wave data")
  
  for wave = 1, wave_count do
    waves[wave] = {}
    for sample = 1, wave_size do
      if is_int16 then
        local value = read_int16_le(file)
        if use_full_range then
          -- Full 16-bit range: -32768 to 32767 maps to -1.0 to ~1.0
          waves[wave][sample] = value / 32768.0
        else
          -- 15-bit range (-6 dBFS peak): -16384 to 16383 maps to -0.5 to ~0.5
          waves[wave][sample] = value / 32768.0
        end
      else
        -- Float32 format
        waves[wave][sample] = read_float32_le(file)
      end
    end
  end
  
  -- Read metadata if present
  local metadata = nil
  if has_metadata then
    print("DEBUG: Reading metadata")
    local metadata_bytes = {}
    local byte = file:read(1)
    while byte and byte:byte() ~= 0 do
      table.insert(metadata_bytes, byte)
      byte = file:read(1)
    end
    if #metadata_bytes > 0 then
      metadata = table.concat(metadata_bytes)
      print("DEBUG: Metadata: " .. metadata)
    end
  end
  
    return {
      wave_size = wave_size,
      wave_count = wave_count,
      is_sample = is_sample,
      is_looped = is_looped,
      is_int16 = is_int16,
      use_full_range = use_full_range,
      waves = waves,
      metadata = metadata
    }
  end)
  
  file:close()
  
  if not success then
    print("ERROR:","Error parsing wavetable file: " .. tostring(result))
    return nil
  end
  
  return result
end

local function create_sample_from_wave(wave_data, sample_rate)
  sample_rate = sample_rate or 44100
  
  -- This function will return the wave data, not create the buffer
  -- The buffer creation happens in the main import function
  return wave_data, sample_rate
end

local function import_wavetable_to_instrument(wavetable_data, instrument_name)
  local song = renoise.song()
  
  -- Initialize with Paketti default instrument (like REX loader)
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  -- Apply default settings if available
  if pakettiPreferencesDefaultInstrumentLoader then
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
  local instrument = song.selected_instrument
  
  print("DEBUG: Created instrument")
  print("DEBUG: Importing " .. wavetable_data.wave_count .. " waves")
  
  -- Clear default sample
  if #instrument.samples > 0 then
    instrument:delete_sample_at(1)
  end
  
  -- Import each wave as a separate sample with its own device chain
  for i = 1, wavetable_data.wave_count do
    local wave_data, sample_rate = create_sample_from_wave(wavetable_data.waves[i])
    
    -- Insert sample
    instrument:insert_sample_at(i)
    local sample = instrument.samples[i]
    
    print("DEBUG: Creating sample buffer for wave " .. i .. " - size: " .. #wave_data .. " samples")
    
    -- Create sample buffer with correct size
    local create_success, create_error = pcall(function()
      sample.sample_buffer:create_sample_data(sample_rate, 16, 1, #wave_data)
    end)
    
    if not create_success then
      print("DEBUG: Failed to create sample buffer for wave " .. i .. " - Error:", create_error)
      error("Failed to create sample buffer for wave " .. i .. ": " .. tostring(create_error))
    end
    
    print("DEBUG: Sample buffer created successfully for wave " .. i)
    
    -- Copy wave data to buffer
    print("DEBUG: Writing sample data for wave " .. i .. " (" .. #wave_data .. " samples)")
    local write_success, write_error = pcall(function()
      -- Prepare for sample data changes
      sample.sample_buffer:prepare_sample_data_changes()
      
      for j = 1, #wave_data do
        -- Clamp values to valid range
        local value = math.max(-1.0, math.min(1.0, wave_data[j]))
        sample.sample_buffer:set_sample_data(1, j, value)
      end
      
      -- Finalize sample data changes
      sample.sample_buffer:finalize_sample_data_changes()
    end)
    
    if not write_success then
      print("DEBUG: Failed to write sample data for wave " .. i .. " - Error:", write_error)
      error("Failed to write sample data for wave " .. i .. ": " .. tostring(write_error))
    end
    
    print("DEBUG: Sample data written successfully for wave " .. i)
    
    -- Add filename to sample name: "filename(XXX)"
    local base_name = (instrument_name or "Wavetable"):gsub("%.wt$", "") -- Remove .wt extension
    sample.name = base_name .. "(" .. string.format("%03d", i) .. ")"
    
    -- Apply Paketti loader preferences if available (but skip loop settings for wavetables)
    if preferences and preferences.pakettiLoaderAutofade then
      sample.autofade = preferences.pakettiLoaderAutofade.value
      sample.autoseek = preferences.pakettiLoaderAutoseek.value
      -- Skip: sample.loop_mode = preferences.pakettiLoaderLoopMode.value (wavetables need specific loop settings)
      sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      sample.oneshot = preferences.pakettiLoaderOneshot.value
      sample.new_note_action = preferences.pakettiLoaderNNA.value
      sample.loop_release = preferences.pakettiLoaderLoopExit.value
    end
    
    -- FORCE loop mode for wavetables (essential for wavetable functionality) - MUST be after preferences
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = #wave_data
    print("DEBUG: Forced loop for wave " .. i .. " - mode:" .. sample.loop_mode .. " start:" .. sample.loop_start .. " end:" .. sample.loop_end)
    

    -- All wavetable samples should have the same base note (C-4 = 48)
    sample.sample_mapping.base_note = 48 -- C-4
    
    print("DEBUG: Imported wave " .. i .. " (" .. #wave_data .. " samples)")
  end
  
  -- Set sample modulation set and device chain names
  song.instruments[song.selected_instrument_index].sample_modulation_sets[1].name = instrument_name
  song.instruments[song.selected_instrument_index].sample_device_chains[1].name = instrument_name
  
  -- Apply velocity range choke to first sample (enables sample 1, disables all others)
  local function pakettiSampleVelocityRangeChoke_local(sample_index)
    local ing = song.selected_instrument
    if not ing or #ing.samples == 0 then
      return
    end
    
    -- Set all samples' velocity ranges to {0, 0}, except the selected one
    for i = 1, #ing.samples do
      if i ~= sample_index then
        local mapping = ing.sample_mappings[1][i]
        if mapping then
          mapping.velocity_range = {0, 0} -- Disable all other samples
        end
      end
    end
    
    -- Set the selected sample's velocity range to {0, 127}
    local selected_mapping = ing.sample_mappings[1][sample_index]
    if selected_mapping then
      selected_mapping.velocity_range = {0, 127} -- Enable selected sample
    end
    
    song.selected_sample_index = sample_index
  end
  
  -- Apply velocity choke to first sample
  if wavetable_data.wave_count > 0 then
    pakettiSampleVelocityRangeChoke_local(1)
  end
end

-- Main wavetable loader function (file import hook)
function wt_loadsample(filename)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Check if filename is nil or empty (user cancelled dialog)
  if not filename or filename == "" then
    print("DEBUG: WT import cancelled - no file selected")
    print("STATUS:","WT import cancelled - no file selected")
    return false
  end
  
  print("DEBUG: Starting WT import for file:", filename)
  
  local wavetable_data = parse_wavetable_file(filename)
  if not wavetable_data then
    print("DEBUG: Failed to parse wavetable file")
    return false
  end
  
  -- Extract filename for instrument name (keep .wt extension)
  local instrument_name = filename:match("([^/\\]+)$") or "Wavetable"
  -- Don't remove extension - we want to keep .wt in the name
  
  local success, error_msg = pcall(function()
    import_wavetable_to_instrument(wavetable_data, instrument_name)
  end)
  
  if not success then
    print("DEBUG: Failed to import wavetable to instrument - Error:", error_msg)
    print("ERROR:","Failed to import wavetable: " .. filename .. "\nError: " .. tostring(error_msg))
    return false
  end
  
  print("DEBUG: Wavetable import completed successfully")
  
  -- Final naming at the very end - AFTER completion message
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Add wave count to instrument name: "filename (count)" - done at the end
  instrument.name = (instrument_name or "Imported Wavetable") .. " (" .. wavetable_data.wave_count .. ")"
  
  print("STATUS:","Imported wavetable: " .. instrument.name .. " with " .. wavetable_data.wave_count .. " waves, " .. 
                           wavetable_data.wave_size .. " samples each (all looped + velocity choke on first sample)")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  
  return true
end

-- Manual import function (for menu entries)
function paketti_import_wavetable()
  local file_path = renoise.app():prompt_for_filename_to_read({"*.wt", "*.*"}, "Import Wavetable")
  
  if file_path == "" then
    return
  end
  
  wt_loadsample(file_path)
end

-- Register file import hook for automatic .wt file handling
local wt_integration = {
  category = "sample",
  extensions = { "wt" },
  invoke = wt_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "wt" }) then
  renoise.tool():add_file_import_hook(wt_integration)
else
end


-- PakettiWTExport.lua
-- Wavetable Export for Paketti
-- Exports Renoise instruments to 'vawt' header format

local function write_uint32_le(file, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  file:write(string.char(b1, b2, b3, b4))
end

local function write_uint16_le(file, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  file:write(string.char(b1, b2))
end

local function write_float32_le(file, value)
  -- Convert float32 to bytes (simplified IEEE 754)
  if value == 0.0 then
    file:write(string.char(0, 0, 0, 0))
    return
  end
  
  local sign = value < 0 and 1 or 0
  value = math.abs(value)
  
  if value == math.huge then
    -- Infinity
    local b4 = sign == 1 and 0xFF or 0x7F
    file:write(string.char(0, 0, 0x80, b4))
    return
  end
  
  -- Normalize to get exponent and mantissa
  local exponent = 127
  while value >= 2.0 do
    value = value / 2.0
    exponent = exponent + 1
  end
  while value < 1.0 and value > 0.0 do
    value = value * 2.0
    exponent = exponent - 1
  end
  
  -- Clamp exponent
  if exponent < 0 then
    exponent = 0
    value = 0
  elseif exponent > 255 then
    exponent = 255
    value = 0
  end
  
  local mantissa = math.floor((value - 1.0) * 8388608) -- 2^23
  mantissa = math.max(0, math.min(8388607, mantissa))
  
  local b1 = mantissa % 256
  local b2 = math.floor(mantissa / 256) % 256
  local b3 = math.floor(mantissa / 65536) % 128 + (exponent % 2) * 128
  local b4 = math.floor(exponent / 2) + sign * 128
  
  file:write(string.char(b1, b2, b3, b4))
end

local function get_next_power_of_2(n)
  local power = 2
  while power < n do
    power = power * 2
  end
  return power
end

local function resample_or_pad_wave(sample_data, target_size)
  local current_size = #sample_data
  local result = {}
  
  if current_size == target_size then
    -- Perfect match
    for i = 1, current_size do
      result[i] = sample_data[i]
    end
  elseif current_size > target_size then
    -- Downsample (simple decimation)
    local ratio = current_size / target_size
    for i = 1, target_size do
      local source_index = math.floor((i - 1) * ratio) + 1
      result[i] = sample_data[source_index] or 0.0
    end
  else
    -- Upsample/pad (repeat last value or zero-pad)
    for i = 1, target_size do
      if i <= current_size then
        result[i] = sample_data[i]
      else
        result[i] = sample_data[current_size] or 0.0 -- Repeat last sample
      end
    end
  end
  
  return result
end

local function extract_sample_data(sample)
  local sample_data = {}
  local buffer = sample.sample_buffer
  
  if not buffer.has_sample_data then
    print("DEBUG: Sample has no data, using silence")
    return {0.0} -- Return single zero sample
  end
  
  local num_samples = buffer.number_of_frames
  print("DEBUG: Extracting " .. num_samples .. " samples from: " .. sample.name)
  
  -- Extract mono data (mix down if stereo)
  for i = 1, num_samples do
    local value = buffer:sample_data(1, i) -- Channel 1
    if buffer.number_of_channels > 1 then
      -- Mix stereo to mono
      local value2 = buffer:sample_data(2, i)
      value = (value + value2) * 0.5
    end
    sample_data[i] = value
  end
  
  return sample_data
end

local function export_instrument_to_wavetable(instrument, filepath, use_float32, add_metadata)
  use_float32 = use_float32 ~= false -- Default to true
  add_metadata = add_metadata or false
  
  print("DEBUG: Starting wavetable export for: " .. instrument.name)
  
  if #instrument.samples == 0 then
    print("ERROR: Instrument has no samples to export")
    return false
  end
  
  -- Extract all sample data
  local waves = {}
  local max_size = 0
  
  for i = 1, #instrument.samples do
    local sample_data = extract_sample_data(instrument.samples[i])
    waves[i] = sample_data
    max_size = math.max(max_size, #sample_data)
  end
  
  -- Determine target wave size (next power of 2)
  local wave_size = get_next_power_of_2(max_size)
  wave_size = math.max(2, math.min(4096, wave_size)) -- Clamp to valid range
  
  print("DEBUG: Target wave size: " .. wave_size .. " (from max: " .. max_size .. ")")
  
  -- Resample/pad all waves to target size
  for i = 1, #waves do
    waves[i] = resample_or_pad_wave(waves[i], wave_size)
  end
  
  local wave_count = #waves
  print("DEBUG: Exporting " .. wave_count .. " waves of " .. wave_size .. " samples each")
  
  -- Open file for writing
  local file = io.open(filepath, "wb")
  if not file then
    print("ERROR: Could not create file: " .. filepath)
    return false
  end
  
  -- Write header: 'vawt' as big-endian
  file:write("vawt")
  
  -- Write wave_size (little-endian uint32)
  write_uint32_le(file, wave_size)
  
  -- Write wave_count (little-endian uint16)
  write_uint16_le(file, wave_count)
  
  -- Write flags (little-endian uint16)
  local flags = 0
  -- flags = flags + 0x0001 -- is_sample (usually false for wavetables)
  flags = flags + 0x0002 -- is_looped (wavetables should be looped)
  if not use_float32 then
    flags = flags + 0x0004 -- is_int16
  end
  -- flags = flags + 0x0008 -- use_full_range (can be enabled if needed)
  if add_metadata then
    flags = flags + 0x0010 -- has_metadata
  end
  
  write_uint16_le(file, flags)
  print("DEBUG: Flags: " .. string.format("0x%04X", flags))
  
  -- Write wave data
  print("DEBUG: Writing wave data (" .. (use_float32 and "float32" or "int16") .. " format)")
  for wave_idx = 1, wave_count do
    for sample_idx = 1, wave_size do
      local value = waves[wave_idx][sample_idx]
      
      if use_float32 then
        write_float32_le(file, value)
      else
        -- Convert to int16
        local int_value = math.floor(value * 32767 + 0.5)
        int_value = math.max(-32768, math.min(32767, int_value))
        write_uint16_le(file, int_value >= 0 and int_value or (65536 + int_value))
      end
    end
  end
  
  -- Write metadata if requested
  if add_metadata then
    local metadata = "Exported from Renoise: " .. instrument.name
    file:write(metadata)
    file:write(string.char(0)) -- Null terminator
    print("DEBUG: Wrote metadata: " .. metadata)
  end
  
  file:close()
  
  print("STATUS: Exported wavetable: " .. filepath)
  print("STATUS: " .. wave_count .. " waves, " .. wave_size .. " samples each (" .. 
        (use_float32 and "float32" or "int16") .. " format)")
  
  return true
end

-- Main export function
function paketti_export_wavetable()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if #instrument.samples == 0 then
    print("STATUS: No samples in selected instrument to export!")
    return
  end
  
  -- Suggest filename based on instrument name
  local suggested_name = instrument.name:gsub("[^%w%s%-_]", "") -- Remove invalid chars
  suggested_name = suggested_name:gsub("%s+", "_") -- Replace spaces with underscores
  if suggested_name == "" then
    suggested_name = "Exported_Wavetable"
  end
  suggested_name = suggested_name .. ".wt"
  
  local file_path = renoise.app():prompt_for_filename_to_write("wt", "Export Wavetable As...")
  
  if file_path == "" then
    return
  end
  
  -- Add .wt extension if not present
  if not file_path:match("%.wt$") then
    file_path = file_path .. ".wt"
  end
  
  -- Export with float32 format and metadata
  local success = export_instrument_to_wavetable(instrument, file_path, true, true)
  
  if success then
    print("STATUS: Wavetable exported successfully!")
    print("STATUS: " .. file_path)
  else
    print("ERROR: Failed to export wavetable!")
  end
end




-- PakettiWTDialog.lua
-- Simple Wavetable Control Dialog for Paketti

-- ViewBuilder and dialog variables - MOVED TO TOP
local vb = renoise.ViewBuilder()
local wavetable_dialog = nil
local wavetable_content = nil
local current_sample_count = 0
local ignore_knob_change = false

-- Global function for MIDI mapping
function paketti_wavetable_knob_midi(message)
  if not wavetable_dialog or not wavetable_dialog.visible or not wavetable_content then
    print("DEBUG: MIDI - Dialog not available")
    return
  end
  
  -- Check if views exist
  if not wavetable_content.views or not wavetable_content.views.wt_knob then
    print("DEBUG: MIDI - Views not available")
    return
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    print("DEBUG: MIDI - No instrument or samples")
    return
  end
  
  local sample_count = #instrument.samples
  if sample_count <= 1 then
    print("DEBUG: MIDI - Only one sample, skipping")
    return
  end
  
  -- Map 0-127 MIDI to 1-sample_count
  local target_sample = math.floor((message.int_value / 127) * (sample_count - 1)) + 1
  target_sample = math.max(1, math.min(sample_count, target_sample))
  
  print("DEBUG: MIDI " .. message.int_value .. " -> sample " .. target_sample .. " (of " .. sample_count .. ")")
  
  -- Update knob without triggering change
  ignore_knob_change = true
  wavetable_content.views.wt_knob.value = target_sample
  ignore_knob_change = false
  
  -- Apply velocity choke
  paketti_wt_set_sample(target_sample)
end

-- Set active sample using velocity choke
function paketti_wt_set_sample(sample_index)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    print("DEBUG: No instrument or samples")
    return
  end
  
  -- CLAMP to actual sample count - don't let knob go beyond available samples
  local sample_count = #instrument.samples
  sample_index = math.max(1, math.min(sample_count, sample_index))
  
  -- Use the EXACT same velocity choke logic as the import function
  local function pakettiSampleVelocityRangeChoke_local(sample_index)
    local ing = song.selected_instrument
    if not ing or #ing.samples == 0 then
      return
    end
    
    -- Set all samples' velocity ranges to {0, 0}, except the selected one
    for i = 1, #ing.samples do
      if i ~= sample_index then
        local mapping = ing.sample_mappings[1][i]
        if mapping then
          mapping.velocity_range = {0, 0} -- Disable all other samples
        end
      end
    end
    
    -- Set the selected sample's velocity range to {0, 127}
    local selected_mapping = ing.sample_mappings[1][sample_index]
    if selected_mapping then
      selected_mapping.velocity_range = {0, 127} -- Enable selected sample
    end
    
    song.selected_sample_index = sample_index

  end
  
  pakettiSampleVelocityRangeChoke_local(sample_index)
end

-- Wavetable dialog variables (declared before functions that use them)
local vb = nil
local wavetable_dialog = nil
local wavetable_content = nil
local current_sample_count = 0
local ignore_knob_change = false
local wavetable_dialog_observer = nil

-- Dialog observer functions (must be before browse function)
function PakettiWTCreateDialogObserver(dialog_ref)
  local function update_instrument_observer()
    
    if not dialog_ref or not dialog_ref.visible then
      print("DEBUG: Observer called but dialog not visible, skipping")
      return
    end
    
    print("DEBUG: Instrument changed - auto-updating wavetable dialog")
    -- Call our refresh function
    update_wavetable_dialog_simple()
  end
  
  -- Always remove first, then add (to ensure clean state)
  pcall(function()
    if renoise.song().selected_instrument_index_observable:has_notifier(update_instrument_observer) then
      renoise.song().selected_instrument_index_observable:remove_notifier(update_instrument_observer)
      print("DEBUG: Removed old observer before adding new one")
    end
  end)
  
  -- Add the observer
  renoise.song().selected_instrument_index_observable:add_notifier(update_instrument_observer)
  print("DEBUG: Added wavetable instrument observer")
  
  return update_instrument_observer
end


local function PakettiWTRemoveDialogObserver(update_function)
  if update_function then
    pcall(function()
      if renoise.song().selected_instrument_index_observable:has_notifier(update_function) then
        renoise.song().selected_instrument_index_observable:remove_notifier(update_function)
        print("DEBUG: Removed wavetable instrument observer")
      end
    end)
  end
end

-- Simple dialog update function
function update_wavetable_dialog_simple()
  print("*** REFRESH VERSION 3.0 ***")
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    print("STATUS: No instrument selected")
    return
  end
  
  local sample_count = #instrument.samples
  local instrument_index = song.selected_instrument_index
  local new_name = string.format("%02d: %s", instrument_index - 1, instrument.name)
  
  print("STATUS: Updating to: " .. new_name .. " (" .. sample_count .. " samples)")
  
  -- Access views through the ViewBuilder instance, not wavetable_content
  if vb and vb.views then
    if vb.views.wt_name then
      vb.views.wt_name.text = new_name
      print("STATUS: Name updated via vb.views")
    else
      print("ERROR: vb.views.wt_name not found")
    end
    
    if vb.views.wt_knob then
      ignore_knob_change = true
      if sample_count > 0 then
        vb.views.wt_knob.min = 1
        vb.views.wt_knob.max = sample_count
        vb.views.wt_knob.value = 1
        vb.views.wt_knob.active = true
        print("STATUS: Knob updated to 1-" .. sample_count .. " via vb.views")
      else
        vb.views.wt_knob.min = 1
        vb.views.wt_knob.max = 1
        vb.views.wt_knob.value = 1
        vb.views.wt_knob.active = false
        print("STATUS: Knob disabled - no samples in instrument")
      end
      ignore_knob_change = false
      current_sample_count = sample_count
    else
      print("ERROR: vb.views.wt_knob not found")
    end
  else
    print("ERROR: vb or vb.views not available")
  end
end

-- Browse for wavetable file
function browse_wavetable()
  local file_path = renoise.app():prompt_for_filename_to_read({"*.wt", "*.*"}, "Import Wavetable")
  if file_path == "" then
    return
  end
  
  local success = wt_loadsample(file_path)
  if success then
    update_wavetable_dialog_simple()
    
    -- Re-add observer after browse (in case it got disconnected during instrument creation)
    if wavetable_dialog and wavetable_dialog.visible then
      print("DEBUG: Re-adding observer after browse")
      if wavetable_dialog_observer then
        PakettiWTRemoveDialogObserver(wavetable_dialog_observer)
      end
      wavetable_dialog_observer = PakettiWTCreateDialogObserver(wavetable_dialog)
    end
  end
end

-- Create dialog content
function create_wavetable_dialog_content()
  -- Get current instrument info for initial setup
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample_count = 1
  local instrument_text = "No Instrument"
  
  if instrument then
    sample_count = math.max(1, #instrument.samples)
    local instrument_index = song.selected_instrument_index
    instrument_text = string.format("%02d: %s", instrument_index - 1, instrument.name)
    print("DEBUG: Dialog setup - instrument: " .. instrument_text .. ", samples: " .. sample_count)
  end
  
  return vb:column {
    margin = 4,
    
    vb:button {
      text = "Import .WT",
      width = 150,
      height = 24,
      notifier = browse_wavetable
    },
    vb:button {
      text = "Refresh",
      width = 150,
      height = 20,
      notifier = update_wavetable_dialog_simple
    },
    vb:text {
      id = "wt_name",
      text = instrument_text,
      width = 150,
      style = "strong"
    },
    vb:rotary {
      id = "wt_knob",
      min = 1,
      max = sample_count,
      value = 1,
      width = 150,
      height = 150,
      notifier = function(value)
        if ignore_knob_change then return end
        -- Round to integer before sending
        value = math.floor(value + 0.5)
        paketti_wt_set_sample(value)
      end
    }
  }
end

-- Show wavetable dialog
function show_wavetable_dialog()
  -- If dialog is already open, close it (toggle behavior)
  if wavetable_dialog and wavetable_dialog.visible then
    -- Clean up observer
    if wavetable_dialog_observer then
      PakettiWTRemoveDialogObserver(wavetable_dialog_observer)
      wavetable_dialog_observer = nil
    end
    wavetable_dialog:close()
    wavetable_dialog = nil
    wavetable_content = nil
    vb = nil
    return
  end
  
  -- Create fresh ViewBuilder instance to avoid ID conflicts
  vb = renoise.ViewBuilder()
  
  wavetable_content = create_wavetable_dialog_content()
  
  wavetable_dialog = renoise.app():show_custom_dialog("Paketti Wavetable", wavetable_content, my_keyhandler_func)
  
  print("DEBUG: Dialog created")
  
  -- Set focus to Renoise
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Add observer after dialog is created
  wavetable_dialog_observer = PakettiWTCreateDialogObserver(wavetable_dialog)
end

renoise.tool():add_keybinding{name="Global:Paketti:Wavetable Control", invoke = show_wavetable_dialog}
renoise.tool():add_keybinding{name="Global:Paketti:Export Wavetable", invoke = paketti_export_wavetable} 
renoise.tool():add_keybinding{name="Global:Paketti:Import Wavetable", invoke = paketti_import_wavetable}

renoise.tool():add_midi_mapping{name="Paketti:Wavetable Sample Selector x[Knob]", invoke = paketti_wavetable_knob_midi} 
