-- PakettiM8Export.lua
-- DirtyWave M8 sample chain export/import tool
-- Based on DigiChain's M8 implementation using WAV cue point markers for slice data

local dialog = nil
local separator = package.config:sub(1,1)

-- M8 audio format specifications
local M8_SAMPLE_RATE = 44100
local M8_BIT_DEPTH = 16
local M8_CHANNELS = 1  -- M8 uses mono samples

-- Function to write WAV file with cue point markers for M8 slice compatibility
local function write_wav_with_cue_points(filename, sample_data, slice_markers, sample_rate, bit_depth, channels)
  print("-- M8 Export: Writing WAV with cue point markers for M8 compatibility")
  
  local file = io.open(filename, "wb")
  if not file then
    return false
  end
  
  local num_samples = #sample_data
  local byte_rate = sample_rate * channels * (bit_depth / 8)
  local block_align = channels * (bit_depth / 8)
  local data_size = num_samples * (bit_depth / 8)
  
  -- Calculate cue chunk size
  local num_cue_points = #slice_markers
  local cue_chunk_size = 4 + (num_cue_points * 24)  -- 4 bytes for count + 24 bytes per cue point
  
  -- Calculate total file size
  local file_size = 36 + data_size + (num_cue_points > 0 and (8 + cue_chunk_size) or 0)
  
  -- Helper functions to write little-endian data
  local function write_le32(value)
    file:write(string.char(
      value % 256,
      math.floor(value / 256) % 256,
      math.floor(value / 65536) % 256,
      math.floor(value / 16777216) % 256
    ))
  end
  
  local function write_le16(value)
    file:write(string.char(
      value % 256,
      math.floor(value / 256) % 256
    ))
  end
  
  local function write_string(str)
    file:write(str)
  end
  
  -- RIFF header
  write_string("RIFF")
  write_le32(file_size)
  write_string("WAVE")
  
  -- fmt chunk
  write_string("fmt ")
  write_le32(16)  -- fmt chunk size
  write_le16(1)   -- PCM format
  write_le16(channels)
  write_le32(sample_rate)
  write_le32(byte_rate)
  write_le16(block_align)
  write_le16(bit_depth)
  
  -- cue chunk (M8 slice markers)
  if num_cue_points > 0 then
    write_string("cue ")
    write_le32(cue_chunk_size)
    write_le32(num_cue_points)
    
    for i, marker_pos in ipairs(slice_markers) do
      write_le32(i)  -- cue point ID
      write_le32(0)  -- play order position
      write_string("data")  -- chunk ID
      write_le32(0)  -- chunk start
      write_le32(0)  -- block start
      write_le32(marker_pos - 1)  -- sample offset (convert to 0-based)
    end
  end
  
  -- data chunk
  write_string("data")
  write_le32(data_size)
  
  -- Write sample data
  if bit_depth == 16 then
    for _, sample in ipairs(sample_data) do
      local int_sample = math.floor(sample * 32767 + 0.5)
      int_sample = math.max(-32768, math.min(32767, int_sample))
      write_le16(int_sample >= 0 and int_sample or (65536 + int_sample))
    end
  elseif bit_depth == 24 then
    for _, sample in ipairs(sample_data) do
      local int_sample = math.floor(sample * 8388607 + 0.5)
      int_sample = math.max(-8388608, math.min(8388607, int_sample))
      if int_sample < 0 then int_sample = 16777216 + int_sample end
      file:write(string.char(
        int_sample % 256,
        math.floor(int_sample / 256) % 256,
        math.floor(int_sample / 65536) % 256
      ))
    end
  end
  
  file:close()
  return true
end

-- Helper functions for reading little-endian data in Lua 5.1
local function read_le16(file)
  local bytes = file:read(2)
  if not bytes or #bytes < 2 then return nil end
  local b1, b2 = bytes:byte(1, 2)
  return b1 + (b2 * 256)
end

local function read_le32(file)
  local bytes = file:read(4)
  if not bytes or #bytes < 4 then return nil end
  local b1, b2, b3, b4 = bytes:byte(1, 4)
  return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function read_le16_from_bytes(bytes, offset)
  local b1, b2 = bytes:byte(offset, offset + 1)
  return b1 + (b2 * 256)
end

local function read_le32_from_bytes(bytes, offset)
  local b1, b2, b3, b4 = bytes:byte(offset, offset + 3)
  return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

-- Function to read WAV file and extract cue point markers
local function read_wav_cue_points(filename)
  print("-- M8 Import: Reading WAV cue point markers")
  
  local file = io.open(filename, "rb")
  if not file then
    return nil
  end
  
  -- Read RIFF header
  local riff = file:read(4)
  if riff ~= "RIFF" then
    file:close()
    return nil
  end
  
  local file_size = read_le32(file)
  local wave = file:read(4)
  if wave ~= "WAVE" then
    file:close()
    return nil
  end
  
  local cue_points = {}
  local fmt_data = {}
  
  -- Read chunks
  while true do
    local chunk_id = file:read(4)
    if not chunk_id or #chunk_id < 4 then break end
    
    local chunk_size = read_le32(file)
    
    if chunk_id == "fmt " then
      local fmt_chunk = file:read(chunk_size)
      fmt_data.format = read_le16_from_bytes(fmt_chunk, 1)
      fmt_data.channels = read_le16_from_bytes(fmt_chunk, 3)
      fmt_data.sample_rate = read_le32_from_bytes(fmt_chunk, 5)
      fmt_data.bit_depth = read_le16_from_bytes(fmt_chunk, 15)
    elseif chunk_id == "cue " then
      local num_cue_points = read_le32(file)
      print("-- M8 Import: Found " .. num_cue_points .. " cue points")
      
      for i = 1, num_cue_points do
        local cue_id = read_le32(file)
        local play_order = read_le32(file)
        local chunk_id = file:read(4)
        local chunk_start = read_le32(file)
        local block_start = read_le32(file)
        local sample_offset = read_le32(file)
        
        table.insert(cue_points, sample_offset + 1)  -- Convert to 1-based
        print(string.format("-- M8 Import: Cue point %d at sample %d", cue_id, sample_offset + 1))
      end
    else
      -- Skip unknown chunks
      file:seek("cur", chunk_size)
      if chunk_size % 2 == 1 then
        file:seek("cur", 1)  -- Skip padding byte
      end
    end
  end
  
  file:close()
  return {
    cue_points = cue_points,
    format = fmt_data
  }
end

-- M8 .m8i sample instrument support (based on Kaitai Struct specification)
-- Only supports M8 sample instruments (type 0x02) - other synth types not supported in Renoise
-- Format: https://github.com/colonel-blimp/m8s-kaitai-struct

-- Helper function to write little-endian 32-bit integer  
local function write_le32(file, value)
  local b1 = bit_and(value, 0xFF)
  local b2 = bit_and(bit_rshift(value, 8), 0xFF)
  local b3 = bit_and(bit_rshift(value, 16), 0xFF)
  local b4 = bit_and(bit_rshift(value, 24), 0xFF)
  file:write(string.char(b1, b2, b3, b4))
end

-- Function to write M8 sample instrument (.m8i)
local function write_m8_sample_instrument(filename, instrument_data)
  print("-- M8 Export: Writing M8 sample instrument: " .. filename)
  
  local file = io.open(filename, "wb")
  if not file then
    print("-- M8 Export: Error - Could not create .m8i file")
    return false
  end
  
  -- M8 Header: "M8VERSION" + null + version + file_type
  file:write("M8VERSION\0")
  file:write(string.char(0x02, 0x06, 0x00)) -- version 2.6.0 (example)
  file:write(string.char(0x00, 0x10)) -- 0x1000 = instrument_file (little-endian)
  
  -- Instrument data
  file:write(string.char(0x02)) -- instrument_type: sample
  
  -- Instrument name (12 chars, null-terminated)
  local name = instrument_data.name:sub(1, 11) -- leave room for null
  while #name < 11 do
    name = name .. "\0"
  end
  file:write(name .. "\0")
  
  -- Transpose and table tic rate
  file:write(string.char(instrument_data.transpose or 0x80))
  file:write(string.char(instrument_data.table_tic_rate or 0x00))
  
  -- Sample-specific data (8 bytes)
  file:write(string.char(instrument_data.pitch or 0x80))      -- pitch
  file:write(string.char(instrument_data.finetune or 0x80))   -- finetune  
  file:write(string.char(instrument_data.play_mode or 0x00))  -- play_mode
  file:write(string.char(instrument_data.slices or 0x00))     -- slices
  file:write(string.char(instrument_data.start or 0x00))      -- start
  file:write(string.char(instrument_data.loop_start or 0x00)) -- loop_start
  file:write(string.char(instrument_data.length or 0xFF))     -- length
  file:write(string.char(instrument_data.degrade or 0x00))    -- degrade
  
  -- Common instrument data (simplified - 22 bytes minimum)
  file:write(string.char(instrument_data.filter or 0x00))     -- filter
  file:write(string.char(instrument_data.cutoff or 0xFF))     -- cutoff
  file:write(string.char(instrument_data.res or 0x00))        -- resonance
  file:write(string.char(instrument_data.amp or 0x80))        -- amp
  file:write(string.char(instrument_data.lim or 0x00))        -- limiter
  file:write(string.char(instrument_data.pan or 0x80))        -- pan
  file:write(string.char(instrument_data.dry or 0xFF))        -- dry
  file:write(string.char(instrument_data.cho or 0x00))        -- chorus
  file:write(string.char(instrument_data.del or 0x00))        -- delay
  file:write(string.char(instrument_data.rev or 0x00))        -- reverb
  
  -- Mystery 2 bytes + simplified envelopes (12 bytes) + LFOs (12 bytes)
  file:write(string.rep("\0", 26))
  
  -- Unknown data length (27 for song context, 25 for instrument)
  file:write(string.rep("\0", 25))
  
  -- Sample path (127 bytes, null-terminated)
  local sample_path = instrument_data.sample_path or ""
  sample_path = sample_path:sub(1, 126) -- leave room for null
  while #sample_path < 126 do
    sample_path = sample_path .. "\0"
  end
  file:write(sample_path .. "\0")
  
  file:close()
  print("-- M8 Export: Successfully wrote M8 sample instrument")
  return true
end

-- Function to read M8 sample instrument (.m8i)
local function read_m8_sample_instrument(filename)
  print("-- M8 Import: Reading M8 sample instrument: " .. filename)
  
  local file = io.open(filename, "rb")
  if not file then
    print("-- M8 Import: Error - Could not open .m8i file")
    return nil
  end
  
  -- Read and verify M8 header
  local magic = file:read(10)
  if magic ~= "M8VERSION\0" then
    print("-- M8 Import: Error - Invalid M8 file format")
    file:close()
    return nil
  end
  
  -- Read version (3 bytes)
  local version_z = string.byte(file:read(1))
  local version_y = string.byte(file:read(1))  
  local version_x = string.byte(file:read(1))
  
  -- Read file type (2 bytes, little-endian)
  local ft1 = string.byte(file:read(1))
  local ft2 = string.byte(file:read(1))
  local file_type = ft1 + (ft2 * 256)
  
  if file_type ~= 0x1000 then
    print("-- M8 Import: Error - Not an M8 instrument file")
    file:close()
    return nil
  end
  
  -- Read instrument type
  local instrument_type = string.byte(file:read(1))
  if instrument_type ~= 0x02 then
    print("-- M8 Import: Error - Not an M8 sample instrument (type: " .. instrument_type .. ")")
    file:close()
    return nil
  end
  
  -- Read instrument name (12 bytes)
  local name_data = file:read(12)
  local name = name_data:match("([^%z]*)")
  
  -- Read transpose and table tic rate
  local transpose = string.byte(file:read(1))
  local table_tic_rate = string.byte(file:read(1))
  
  -- Read sample-specific data
  local pitch = string.byte(file:read(1))
  local finetune = string.byte(file:read(1))
  local play_mode = string.byte(file:read(1))
  local slices = string.byte(file:read(1))
  local start = string.byte(file:read(1))
  local loop_start = string.byte(file:read(1))
  local length = string.byte(file:read(1))
  local degrade = string.byte(file:read(1))
  
  -- Read common instrument data (simplified)
  local filter = string.byte(file:read(1))
  local cutoff = string.byte(file:read(1))
  local res = string.byte(file:read(1))
  local amp = string.byte(file:read(1))
  local lim = string.byte(file:read(1))
  local pan = string.byte(file:read(1))
  local dry = string.byte(file:read(1))
  local cho = string.byte(file:read(1))
  local del = string.byte(file:read(1))
  local rev = string.byte(file:read(1))
  
  -- Skip mystery data + envelopes + LFOs (26 bytes)
  file:read(26)
  
  -- Skip unknown data (25 bytes)  
  file:read(25)
  
  -- Read sample path (127 bytes)
  local sample_path_data = file:read(127)
  local sample_path = sample_path_data:match("([^%z]*)")
  
  file:close()
  
  return {
    name = name,
    version = string.format("%d.%d.%d", version_x, version_y, version_z),
    transpose = transpose,
    pitch = pitch,
    finetune = finetune,
    play_mode = play_mode,
    slices = slices,
    start = start,
    loop_start = loop_start,
    length = length,
    degrade = degrade,
    filter = filter,
    cutoff = cutoff,
    res = res,
    amp = amp,
    pan = pan,
    dry = dry,
    cho = cho,
    del = del,
    rev = rev,
    sample_path = sample_path
  }
end

-- Function to export M8 sample chain
function PakettiM8Export()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_error("No samples found in selected instrument")
    return
  end
  
  if #instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot export from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  print("-- M8 Export: Starting M8 sample chain export")
  print("-- M8 Export: Processing " .. #instrument.samples .. " samples")
  
  -- Process and combine samples
  local combined_data = {}
  local slice_markers = {}
  local current_position = 1
  local processed_count = 0
  
  for i, sample in ipairs(instrument.samples) do
    if sample and sample.sample_buffer.has_sample_data then
      renoise.app():show_status(string.format("M8 Export: Processing sample %d/%d", i, #instrument.samples))
      
      local buffer = sample.sample_buffer
      local frames = buffer.number_of_frames
      local channels = buffer.number_of_channels
      
      -- Add slice marker at start of this sample
      table.insert(slice_markers, current_position)
      
      -- Convert sample to mono M8 format
      for frame = 1, frames do
        local mono_value = 0
        if channels == 1 then
          mono_value = buffer:sample_data(1, frame)
        else
          -- Mix stereo to mono
          local left = buffer:sample_data(1, frame)
          local right = channels > 1 and buffer:sample_data(2, frame) or left
          mono_value = (left + right) / 2
        end
        table.insert(combined_data, mono_value)
        current_position = current_position + 1
      end
      
      processed_count = processed_count + 1
      print(string.format("-- M8 Export: Processed sample %d: %d frames", i, frames))
    end
  end
  
  if processed_count == 0 then
    renoise.app():show_error("No valid samples found to export")
    return
  end
  
  -- Get output filename
  local filename = renoise.app():prompt_for_filename_to_write("*.wav", "Save M8 sample chain...")
  if not filename or filename == "" then
    renoise.app():show_status("M8 export cancelled")
    return
  end
  
  -- Ensure .wav extension
  if not filename:match("%.wav$") then
    filename = filename .. ".wav"
  end
  
  -- Write WAV file with cue points for M8
  local success = write_wav_with_cue_points(filename, combined_data, slice_markers, M8_SAMPLE_RATE, M8_BIT_DEPTH, M8_CHANNELS)
  
  if success then
    renoise.app():show_status(string.format("M8 Export: Created %s with %d slices", filename:match("([^/\\]+)$"), #slice_markers))
    print(string.format("-- M8 Export: Successfully exported %d samples as %d slices", processed_count, #slice_markers))
  else
    renoise.app():show_error("Failed to write M8 sample chain file")
  end
end

-- Function to export M8 sample instrument
function PakettiM8ExportInstrument()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument.samples[1] or not instrument.samples[1].sample_buffer.has_sample_data then
    renoise.app():show_error("M8 Export: No sample data found in selected instrument")
    return
  end
  
  print("-- M8 Export: Starting M8 sample instrument export")
  
  -- Get export path
  local export_path = renoise.app():prompt_for_filename_to_write("*.m8i", "Export M8 Sample Instrument")
  if not export_path or export_path == "" then
    print("-- M8 Export: Export cancelled")
    return
  end
  
  -- Ensure .m8i extension
  if not export_path:match("%.m8i$") then
    export_path = export_path .. ".m8i"
  end
  
  -- Prepare M8 sample instrument data
  local sample = instrument.samples[1]
  local sample_filename = export_path:gsub("%.m8i$", ".wav"):match("([^/\\]+)$")
  
  local instrument_data = {
    name = instrument.name:sub(1, 11),
    transpose = 0x80, -- centered
    pitch = 0x80, -- centered
    finetune = 0x80, -- centered
    play_mode = 0x00, -- forward
    slices = math.min(#sample.slice_markers, 0xFF),
    start = 0x00,
    loop_start = 0x00,
    length = 0xFF, -- full sample
    degrade = 0x00,
    filter = 0x00, -- off
    cutoff = 0xFF, -- open
    res = 0x00, -- no resonance
    amp = 0x80, -- centered
    pan = 0x80, -- centered
    dry = 0xFF, -- full
    cho = 0x00, -- no chorus
    del = 0x00, -- no delay  
    rev = 0x00, -- no reverb
    sample_path = sample_filename
  }
  
  -- Write M8 sample instrument file
  if write_m8_sample_instrument(export_path, instrument_data) then
    -- Also export the sample as WAV for M8 to use
    local wav_path = export_path:gsub("%.m8i$", ".wav")
    
    -- Export sample in M8 format (44.1kHz, 16-bit, mono)
    local export_success = pcall(function()
      sample.sample_buffer:save_as(wav_path, "wav")
    end)
    
    if export_success then
      renoise.app():show_status("M8 Export: Exported " .. instrument.name .. " as M8 sample instrument")
      print("-- M8 Export: Successfully exported M8 sample instrument + WAV")
    else
      renoise.app():show_error("M8 Export: Failed to export sample WAV file")
    end
  else
    renoise.app():show_error("M8 Export: Failed to create .m8i file")
  end
end

-- Function to import M8 sample chain
function PakettiM8Import()
  local filename = renoise.app():prompt_for_filename_to_read({"*.wav"}, "Load M8 sample chain...")
  if not filename or filename == "" then
    return
  end
  
  -- Read cue points from WAV file
  local wav_data = read_wav_cue_points(filename)
  if not wav_data or not wav_data.cue_points then
    renoise.app():show_error("No M8 cue points found in WAV file")
    return
  end
  
  local cue_points = wav_data.cue_points
  print("-- M8 Import: Found " .. #cue_points .. " M8 slice markers")
  
  -- Create new instrument
  local song = renoise.song()
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local instrument = song.selected_instrument
  
  -- Set instrument name
  local base_name = filename:match("([^/\\]+)$"):gsub("%.wav$", "")
  instrument.name = "M8 " .. base_name
  
  -- Load WAV file into first sample
  local sample = instrument.samples[1]
  local success = pcall(function()
    sample.sample_buffer:load_from(filename)
  end)
  
  if not success or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("Failed to load WAV file: " .. filename)
    return
  end
  
  -- Apply M8 cue points as slice markers
  sample.name = base_name .. " M8 Chain"
  
  -- Clear any existing slice markers
  local existing_markers = {}
  for _, marker in ipairs(sample.slice_markers) do
    table.insert(existing_markers, marker)
  end
  for _, marker in ipairs(existing_markers) do
    sample:delete_slice_marker(marker)
  end
  
  -- Insert M8 cue points as slice markers
  local applied_slices = 0
  for _, cue_pos in ipairs(cue_points) do
    if cue_pos > 0 and cue_pos <= sample.sample_buffer.number_of_frames then
      local success, error_msg = pcall(function()
        sample:insert_slice_marker(cue_pos)
      end)
      if success then
        applied_slices = applied_slices + 1
      else
        print("-- M8 Import: Error inserting slice at " .. cue_pos .. ": " .. tostring(error_msg))
      end
    end
  end
  
  -- Switch to sample editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  
  renoise.app():show_status(string.format("M8 Import: Loaded %s with %d slices", base_name, applied_slices))
  print(string.format("-- M8 Import: Successfully applied %d M8 slice markers", applied_slices))
end

-- Function to import M8 sample instrument
function PakettiM8ImportInstrument()
  local song = renoise.song()
  
  print("-- M8 Import: Starting M8 sample instrument import")
  
  -- Get import path
  local import_path = renoise.app():prompt_for_filename_to_read({"*.m8i"}, "Import M8 Sample Instrument")
  if not import_path or import_path == "" then
    print("-- M8 Import: Import cancelled")
    return
  end
  
  -- Read M8 sample instrument
  local m8_data = read_m8_sample_instrument(import_path)
  if not m8_data then
    renoise.app():show_error("M8 Import: Failed to read M8 sample instrument")
    return
  end
  
  print("-- M8 Import: Successfully read M8 sample instrument: " .. m8_data.name)
  print("-- M8 Import: Sample path: " .. (m8_data.sample_path or "none"))
  
  -- Try to find the associated WAV file
  local wav_path = nil
  if m8_data.sample_path and m8_data.sample_path ~= "" then
    -- First try same directory as .m8i file
    local m8i_dir = import_path:match("(.+[/\\])")
    if m8i_dir then
      local test_path = m8i_dir .. m8_data.sample_path
      local test_file = io.open(test_path, "rb")
      if test_file then
        test_file:close()
        wav_path = test_path
        print("-- M8 Import: Found WAV file: " .. wav_path)
      end
    end
    
    -- If not found, try with .m8i extension replaced by .wav
    if not wav_path then
      local test_path = import_path:gsub("%.m8i$", ".wav")
      local test_file = io.open(test_path, "rb")
      if test_file then
        test_file:close()
        wav_path = test_path
        print("-- M8 Import: Found WAV file: " .. wav_path)
      end
    end
  end
  
  if not wav_path then
    -- Prompt user to select WAV file
    wav_path = renoise.app():prompt_for_filename_to_read({"*.wav"}, "Select WAV file for M8 sample instrument")
    if not wav_path or wav_path == "" then
      renoise.app():show_error("M8 Import: No WAV file selected")
      return
    end
  end
  
  -- Create new instrument
  local new_instrument_index = #song.instruments + 1
  song:insert_instrument_at(new_instrument_index)
  local new_instrument = song.instruments[new_instrument_index]
  
  -- Set instrument name
  new_instrument.name = m8_data.name
  
  -- Load sample
  local sample_success = pcall(function()
    new_instrument.samples[1].sample_buffer:load_from(wav_path)
  end)
  
  if not sample_success then
    renoise.app():show_error("M8 Import: Failed to load WAV file")
    return
  end
  
  -- Apply M8 parameters to Renoise instrument
  local sample = new_instrument.samples[1]
  
  -- Set basic sample properties
  sample.name = m8_data.name
  
  -- Convert M8 transpose to Renoise (M8: 0x80 = center, Renoise: 0 = center)
  local transpose_offset = m8_data.transpose - 0x80
  sample.transpose = math.max(-120, math.min(120, transpose_offset))
  
  -- Convert M8 pitch to Renoise finetune (M8: 0x80 = center, Renoise: 0 = center)
  local pitch_offset = m8_data.pitch - 0x80
  sample.fine_tune = math.max(-127, math.min(127, pitch_offset))
  
  -- Set loop mode based on M8 play_mode
  if m8_data.play_mode == 0x01 then -- loop forward
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  elseif m8_data.play_mode == 0x02 then -- loop ping-pong
    sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
  else -- forward (default)
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end
  
  song.selected_instrument_index = new_instrument_index
  
  renoise.app():show_status("M8 Import: Imported " .. m8_data.name .. " as Renoise instrument")
  print("-- M8 Import: Successfully imported M8 sample instrument")
  
  -- Show summary
  local summary = string.format("M8 Sample Instrument Import Summary:\n\n" ..
    "Name: %s\n" ..
    "M8 Version: %s\n" ..
    "Transpose: %d\n" ..
    "Pitch: %d\n" ..
    "Play Mode: %d\n" ..
    "Slices: %d\n" ..
    "Filter: %d\n" ..
    "Cutoff: %d\n" ..
    "Sample Path: %s",
    m8_data.name,
    m8_data.version,
    m8_data.transpose,
    m8_data.pitch,
    m8_data.play_mode,
    m8_data.slices,
    m8_data.filter,
    m8_data.cutoff,
    m8_data.sample_path or "none")
  
  renoise.app():show_message(summary)
end

-- File import hook for M8 .m8i files
local function import_m8i_file(filename)
  print("-- M8 Import Hook: Processing .m8i file: " .. filename)
  
  -- Read M8 sample instrument
  local m8_data = read_m8_sample_instrument(filename)
  if not m8_data then
    renoise.app():show_error("M8 Import: Failed to read M8 sample instrument")
    return
  end
  
  print("-- M8 Import: Successfully read M8 sample instrument: " .. m8_data.name)
  
  -- Try to find the associated WAV file
  local wav_path = nil
  if m8_data.sample_path and m8_data.sample_path ~= "" then
    -- First try same directory as .m8i file
    local m8i_dir = filename:match("(.+[/\\])")
    if m8i_dir then
      local test_path = m8i_dir .. m8_data.sample_path
      local test_file = io.open(test_path, "rb")
      if test_file then
        test_file:close()
        wav_path = test_path
        print("-- M8 Import: Found WAV file: " .. wav_path)
      end
    end
    
    -- If not found, try with .m8i extension replaced by .wav
    if not wav_path then
      local test_path = filename:gsub("%.m8i$", ".wav")
      local test_file = io.open(test_path, "rb")
      if test_file then
        test_file:close()
        wav_path = test_path
        print("-- M8 Import: Found WAV file: " .. wav_path)
      end
    end
  end
  
  if not wav_path then
    -- Prompt user to select WAV file
    wav_path = renoise.app():prompt_for_filename_to_read({"*.wav"}, "Select WAV file for M8 sample instrument")
    if not wav_path or wav_path == "" then
      renoise.app():show_error("M8 Import: No WAV file selected")
      return
    end
  end
  
  -- Create new instrument using common M8 import logic
  local song = renoise.song()
  local new_instrument_index = #song.instruments + 1
  song:insert_instrument_at(new_instrument_index)
  local new_instrument = song.instruments[new_instrument_index]
  
  -- Set instrument name
  new_instrument.name = m8_data.name
  
  -- Load sample
  local sample_success = pcall(function()
    new_instrument.samples[1].sample_buffer:load_from(wav_path)
  end)
  
  if not sample_success then
    renoise.app():show_error("M8 Import: Failed to load WAV file")
    return
  end
  
  -- Apply M8 parameters to Renoise instrument
  local sample = new_instrument.samples[1]
  sample.name = m8_data.name
  
  -- Convert M8 transpose to Renoise (M8: 0x80 = center, Renoise: 0 = center)
  local transpose_offset = m8_data.transpose - 0x80
  sample.transpose = math.max(-120, math.min(120, transpose_offset))
  
  -- Convert M8 pitch to Renoise finetune (M8: 0x80 = center, Renoise: 0 = center)
  local pitch_offset = m8_data.pitch - 0x80
  sample.fine_tune = math.max(-127, math.min(127, pitch_offset))
  
  -- Set loop mode based on M8 play_mode
  if m8_data.play_mode == 0x01 then -- loop forward
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  elseif m8_data.play_mode == 0x02 then -- loop ping-pong
    sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
  else -- forward (default)
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end
  
  song.selected_instrument_index = new_instrument_index
  
  renoise.app():show_status("M8 Import: Imported " .. m8_data.name .. " as Renoise instrument")
  print("-- M8 Import: Successfully imported M8 sample instrument")
end

-- Export menu entries
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:M8:Export Sample Chain", invoke = PakettiM8Export}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:M8:Export Instrument", invoke = PakettiM8ExportInstrument}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:M8:Import Sample Chain", invoke = PakettiM8Import}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:M8:Import Instrument", invoke = PakettiM8ImportInstrument}

renoise.tool():add_keybinding{name = "Global:Paketti:M8 Export Sample Chain", invoke = PakettiM8Export}
renoise.tool():add_keybinding{name = "Global:Paketti:M8 Export Instrument", invoke = PakettiM8ExportInstrument}

renoise.tool():add_keybinding{name = "Global:Paketti:M8 Import Sample Chain", invoke = PakettiM8Import}
renoise.tool():add_keybinding{name = "Global:Paketti:M8 Import Instrument", invoke = PakettiM8ImportInstrument}

-- Register file import hook for M8 .m8i files
local m8i_integration = {
  category = "sample",
  extensions = { "m8i" },
  invoke = import_m8i_file
}

if not renoise.tool():has_file_import_hook("sample", { "m8i" }) then
  renoise.tool():add_file_import_hook(m8i_integration)
end

 