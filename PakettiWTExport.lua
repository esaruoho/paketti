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
    renoise.app():show_message("No samples in selected instrument to export!")
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
    renoise.app():show_message("Wavetable exported successfully!\n" .. file_path)
  else
    renoise.app():show_message("Failed to export wavetable!")
  end
end

-- Add menu entries
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Export Wavetable...", invoke = paketti_export_wavetable}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Export Wavetable...", invoke = paketti_export_wavetable}
renoise.tool():add_keybinding{name="Global:Paketti:Export Wavetable", invoke = paketti_export_wavetable} 