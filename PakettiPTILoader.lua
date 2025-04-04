local bit = require("bit")

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.pti$", "") end
  return "PTI Sample"
end

local function read_uint16_le(data, offset)
  return string.byte(data, offset + 1) + string.byte(data, offset + 2) * 256
end

local function read_uint32_le(data, offset)
  return string.byte(data, offset + 1) +
         string.byte(data, offset + 2) * 256 +
         string.byte(data, offset + 3) * 65536 +
         string.byte(data, offset + 4) * 16777216
end

local function pti_loadsample(filepath)
  local file = io.open(filepath, "rb")
  if not file then
    renoise.app():show_error("Cannot open file: " .. filepath)
    return
  end

  local header = file:read(392)
  local sample_length = read_uint32_le(header, 60)
  local pcm_data = file:read("*a")
  file:close()

  -- Always create a new instrument instead of overwriting
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index

  -- Initialize with Paketti default instrument
  pakettiPreferencesDefaultInstrumentLoader()
  
  -- Create and fill sample buffer in the first slot
  local smp = renoise.song().selected_instrument.samples[1]
  smp.sample_buffer:create_sample_data(44100, 16, 1, sample_length)
  local buffer = smp.sample_buffer
  buffer:prepare_sample_data_changes()

  for i = 1, sample_length do
    local byte_offset = (i - 1) * 2 + 1
    local lo = pcm_data:byte(byte_offset) or 0
    local hi = pcm_data:byte(byte_offset + 1) or 0
    local sample = bit.bor(bit.lshift(hi, 8), lo)
    if sample >= 32768 then sample = sample - 65536 end
    buffer:set_sample_data(1, i, sample / 32768)
  end

  buffer:finalize_sample_data_changes()

  -- Set names for instrument, sample, and related components
  local clean_name = get_clean_filename(filepath)
  renoise.song().selected_instrument.name = clean_name
  renoise.song().selected_instrument.samples[1].name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_device_chains[1].name = clean_name

  -- Apply Paketti Loader defaults before slicing
  smp.autofade = preferences.pakettiLoaderAutofade.value
  smp.autoseek = preferences.pakettiLoaderAutoseek.value
  smp.loop_mode = preferences.pakettiLoaderLoopMode.value
  smp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  smp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  smp.oneshot = preferences.pakettiLoaderOneshot.value
  smp.new_note_action = preferences.pakettiLoaderNNA.value
  smp.loop_release = preferences.pakettiLoaderLoopExit.value

  -- Process slices
  local slice_frames = {}
  for i = 0, 47 do
    local offset = 280 + i * 2
    local raw_value = read_uint16_le(header, offset)
    if raw_value > 0 and raw_value <= 65535 then
      local frame = math.floor((raw_value / 65535) * sample_length)
      table.insert(slice_frames, frame)
    end
  end

  table.sort(slice_frames)

  -- Apply slices if they exist
  if #slice_frames > 0 then
    print("-- Sample length: " .. sample_length .. " frames")
    print("-- Found " .. #slice_frames .. " slice markers")
    
    -- First marker at the very beginning
    renoise.song().selected_instrument.samples[1]:insert_slice_marker(1)
    
    for _, frame in ipairs(slice_frames) do
      renoise.song().selected_instrument.samples[1]:insert_slice_marker(frame)
    end
    
    -- Enable oversampling for all slices
    for i = 1, #renoise.song().selected_instrument.samples[1].slice_markers do
      renoise.song().selected_instrument.samples[i+1].oversample_enabled = preferences.pakettiLoaderOverSampling.value
    end
  end

  -- Add Instr Macro device if enabled in preferences
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
    if renoise.song().selected_track.type == 2 then 
      renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") 
    else
      loadnative("Audio/Effects/Native/*Instr. Macros") 
      local macro_device = renoise.song().selected_track:device(2)
      macro_device.display_name = string.format("%02X", renoise.song().selected_instrument_index - 1) .. " " .. clean_name
      renoise.song().selected_track.devices[2].is_maximized = false
    end
  end

  -- Show status message
  if #slice_frames > 0 then
    renoise.app():show_status(string.format("PTI imported with %d slice markers", #slice_frames))
  else
    renoise.app():show_status("PTI imported successfully")
  end
end

local pti_integration = {
  category = "sample",
  extensions = { "pti" },
  invoke = pti_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "pti" }) then
  renoise.tool():add_file_import_hook(pti_integration)
end
