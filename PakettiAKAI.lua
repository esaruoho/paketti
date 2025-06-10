--[[============================================================================
PakettiAKAI.lua — Export current selected sample with slices to Akai AKP format
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[AKP Export]", ...)
end

-- Check if file exists
function file_exists(file_path)
  local f = io.open(file_path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Write little-endian 32-bit integer
local function write_le_u32(f, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  f:write(string.char(b1, b2, b3, b4))
end

-- Write little-endian 16-bit integer
local function write_le_u16(f, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  f:write(string.char(b1, b2))
end

-- Write string with padding to specified length
local function write_padded_string(f, str, length)
  local padded = str
  if #padded > length then
    padded = padded:sub(1, length)
  end
  f:write(padded)
  -- Pad with zeros
  for i = #padded + 1, length do
    f:write(string.char(0))
  end
end

-- Write chunk header (4-byte ID + 4-byte size)
local function write_chunk_header(f, chunk_id, size)
  f:write(chunk_id)
  write_le_u32(f, size)
end

-- Extract sample data as normalized floats
local function extract_sample_data(sample)
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    return nil, 0, 0
  end
  
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate
  
  -- Convert to mono if stereo
  local data = {}
  if channels == 1 then
    for i = 1, frames do
      data[i] = buffer:sample_data(1, i)
    end
  else
    for i = 1, frames do
      local sum = 0
      for ch = 1, channels do
        sum = sum + buffer:sample_data(ch, i)
      end
      data[i] = sum / channels
    end
  end
  
  return data, sample_rate, frames
end

-- Extract sliced segments from sample data
local function extract_slice_segments(sample_data, slice_markers)
  local segments = {}
  
  if not slice_markers or #slice_markers == 0 then
    -- No slices, return the whole sample
    segments[1] = sample_data
    return segments
  end
  
  -- Sort slice markers
  local sorted_markers = {}
  for i = 1, #slice_markers do
    table.insert(sorted_markers, slice_markers[i])
  end
  table.sort(sorted_markers)
  
  -- Extract segments between slice markers
  local start_pos = 1
  
  for i = 1, #sorted_markers do
    local end_pos = math.min(sorted_markers[i], #sample_data)
    if end_pos > start_pos then
      local segment = {}
      for j = start_pos, end_pos do
        table.insert(segment, sample_data[j])
      end
      table.insert(segments, segment)
      start_pos = end_pos + 1
    end
  end
  
  -- Add final segment if there's data left
  if start_pos <= #sample_data then
    local segment = {}
    for j = start_pos, #sample_data do
      table.insert(segment, sample_data[j])
    end
    table.insert(segments, segment)
  end
  
  debug_print("Extracted", #segments, "slice segments from", #slice_markers, "markers")
  return segments
end

-- Convert sample data to 16-bit signed integers
local function convert_to_16bit(sample_data)
  local result = {}
  for i = 1, #sample_data do
    local sample = math.max(-1.0, math.min(1.0, sample_data[i]))
    local int_val = math.floor(sample * 32767 + 0.5)
    if int_val > 32767 then int_val = 32767 end
    if int_val < -32768 then int_val = -32768 end
    result[i] = int_val
  end
  return result
end

-- Write separate WAV file for sample data
local function write_wav_file(file_path, sample_data, sample_rate)
  local f, err = io.open(file_path, "wb")
  if not f then
    error("Could not create WAV file: " .. err)
  end
  
  local num_samples = #sample_data
  local bits_per_sample = 16
  local num_channels = 1
  local byte_rate = sample_rate * num_channels * bits_per_sample / 8
  local block_align = num_channels * bits_per_sample / 8
  local data_size = num_samples * bits_per_sample / 8
  
  -- Convert to 16-bit integers
  local int_data = convert_to_16bit(sample_data)
  
  -- RIFF header
  f:write("RIFF")
  write_le_u32(f, 36 + data_size)
  f:write("WAVE")
  
  -- fmt chunk
  write_chunk_header(f, "fmt ", 16)
  write_le_u16(f, 1)  -- PCM format
  write_le_u16(f, num_channels)
  write_le_u32(f, sample_rate)
  write_le_u32(f, byte_rate)
  write_le_u16(f, block_align)
  write_le_u16(f, bits_per_sample)
  
  -- data chunk
  write_chunk_header(f, "data", data_size)
  for i = 1, num_samples do
    local val = int_data[i]
    write_le_u16(f, val < 0 and (val + 65536) or val)
  end
  
  f:close()
end

-- Extract slice segments from sample data
local function extract_slice_segments(sample_data, slice_points)
  local segments = {}
  local start_pos = 1
  
  -- Add each slice segment
  for i = 1, #slice_points do
    local end_pos = slice_points[i]
    if end_pos > start_pos then
      local segment = {}
      for j = start_pos, math.min(end_pos - 1, #sample_data) do
        table.insert(segment, sample_data[j])
      end
      table.insert(segments, segment)
      start_pos = end_pos
    end
  end
  
  -- Add final segment (from last slice to end)
  if start_pos <= #sample_data then
    local segment = {}
    for j = start_pos, #sample_data do
      table.insert(segment, sample_data[j])
    end
    table.insert(segments, segment)
  end
  
  return segments
end

-- Get directory from file path
local function get_directory(file_path)
  return file_path:match("^(.*)[/\\][^/\\]*$") or "."
end

-- Get filename without extension
local function get_filename_without_ext(file_path)
  local name = file_path:match("[^/\\]+$")
  return name:match("^(.*)%.[^.]*$") or name
end

-- Write AKP file structure and export sample files
local function write_akp_file(file_path, sample_name, sample_data, sample_rate, slice_points)
  debug_print("Writing AKP file:", file_path)
  
  local akp_dir = get_directory(file_path)
  local base_name = get_filename_without_ext(file_path)
  
  -- Export sample files
  local sample_files = {}
  
  if #slice_points > 0 then
    -- Export sliced segments
    local segments = extract_slice_segments(sample_data, slice_points)
    debug_print("Extracted", #segments, "slice segments")
    
    for i = 1, math.min(4, #segments) do  -- Max 4 zones
      local slice_name = base_name .. "_slice" .. string.format("%02d", i)
      local wav_path = akp_dir .. "/" .. slice_name .. ".wav"
      write_wav_file(wav_path, segments[i], sample_rate)
      table.insert(sample_files, slice_name)
      debug_print("Exported slice", i, "to:", slice_name .. ".wav", "(", #segments[i], "frames )")
    end
  else
    -- Export whole sample
    local wav_path = akp_dir .. "/" .. base_name .. ".wav"
    write_wav_file(wav_path, sample_data, sample_rate)
    table.insert(sample_files, base_name)
    debug_print("Exported full sample to:", base_name .. ".wav")
  end
  
  local f, err = io.open(file_path, "wb")
  if not f then
    error("Could not create AKP file: " .. err)
  end
  
  -- Calculate number of zones
  local num_zones = math.min(4, #sample_files)
  debug_print("Creating AKP with", num_zones, "zones referencing", #sample_files, "sample files")
  
  -- RIFF header
  f:write("RIFF")
  write_le_u32(f, 0)  -- Size set to 0 as per AKP spec
  f:write("APRG")
  
  -- 'prg ' chunk
  write_chunk_header(f, "prg ", 6)
  f:write(string.char(0x01, 0x00, 0x01, 0x00, 0x02, 0x00))
  
  -- 'out ' chunk  
  write_chunk_header(f, "out ", 8)
  f:write(string.char(0x01, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x19))
  
  -- 'tune' chunk
  write_chunk_header(f, "tune", 22)
  f:write(string.char(0x01))
  -- Semitone tune, fine tune, 12 note detunes, pitch bend settings
  for i = 1, 21 do
    f:write(string.char(0x00))
  end
  f:write(string.char(0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00))
  
  -- 'lfo ' chunk 1
  write_chunk_header(f, "lfo ", 12)
  f:write(string.char(0x01, 0x01, 0x2B, 0x00, 0x00, 0x00, 0x01, 0x0F, 0x00, 0x00, 0x00, 0x00))
  
  -- 'lfo ' chunk 2  
  write_chunk_header(f, "lfo ", 12)
  f:write(string.char(0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  
  -- 'mods' chunk
  write_chunk_header(f, "mods", 38)
  local mods_data = {
    0x01, 0x00, 0x11, 0x00, 0x02, 0x06, 0x02, 0x03, 0x01, 0x08, 0x01, 0x06, 0x01, 0x01,
    0x04, 0x06, 0x05, 0x06, 0x03, 0x06, 0x07, 0x00, 0x08, 0x00, 0x06, 0x00, 0x00, 0x07,
    0x00, 0x0B, 0x02, 0x05, 0x09, 0x05, 0x09, 0x08, 0x09, 0x09
  }
  for i = 1, #mods_data do
    f:write(string.char(mods_data[i]))
  end
  
  -- 'kgrp' chunk
  local kgrp_size = 16 + 18 + 18 + 18 + 10 + (46 * 4)  -- kloc + 3 env + filt + 4 zones
  write_chunk_header(f, "kgrp", kgrp_size)
  
  -- 'kloc' subchunk
  write_chunk_header(f, "kloc", 16)
  f:write(string.char(0x01, 0x03, 0x01, 0x04, 0x15, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00))
  
  -- Amp envelope
  write_chunk_header(f, "env ", 18)
  f:write(string.char(0x01, 0x00, 0x00, 0x32, 0x0F, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  
  -- Filter envelope
  write_chunk_header(f, "env ", 18)
  f:write(string.char(0x01, 0x00, 0x00, 0x32, 0x0F, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  
  -- Aux envelope
  write_chunk_header(f, "env ", 18)
  f:write(string.char(0x01, 0x00, 0x32, 0x32, 0x0F, 0x64, 0x64, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x85))
  
  -- Filter settings
  write_chunk_header(f, "filt", 10)
  f:write(string.char(0x01, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
  
  -- Write zones (up to 4)
  for zone = 1, 4 do
    write_chunk_header(f, "zone", 46)
    f:write(string.char(0x01))
    
    if zone <= num_zones then
      -- Active zone with sample file name
      local zone_name = sample_files[zone]
      
      f:write(string.char(math.min(#zone_name, 20)))  -- Name length (max 20 chars)
      write_padded_string(f, zone_name, 20)
      
      -- Zone parameters (12 bytes of padding)
      f:write(string.char(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
      
      -- Velocity range - distribute slices across velocity layers
      local vel_low, vel_high
      if #slice_points > 0 then
        -- For sliced samples, distribute velocity ranges
        vel_low = math.floor((zone - 1) * 127 / num_zones)
        vel_high = math.floor(zone * 127 / num_zones) - 1
        if zone == num_zones then vel_high = 127 end
      else
        -- For non-sliced samples, use full velocity range
        vel_low = 0
        vel_high = 127
      end
      
      f:write(string.char(vel_low, vel_high))
      -- Fine tune, semitone tune, filter, pan, playback mode, output, zone level, keyboard track, velocity->start
      f:write(string.char(0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x01, 0x00, 0x00))
    else
      -- Empty zone
      f:write(string.char(0x00))  -- No sample name
      for i = 1, 45 do
        f:write(string.char(0x00))
      end
    end
  end
  
  f:close()
  debug_print("AKP file structure written successfully")
end

-- Main export function
function exportCurrentSampleAsAKP()
  local song = renoise.song()
  
  -- Check if we have a selected instrument and sample
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  if not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")  
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  -- Prompt for output file
  local output_path = renoise.app():prompt_for_filename_to_write(
    {"*.akp"}, 
    "Export Sample as AKP File"
  )
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  -- Ensure .akp extension
  if not output_path:lower():match("%.akp$") then
    if output_path:match("%.") then
      output_path = output_path:gsub("%.[^.]*$", ".akp")
    else
      output_path = output_path .. ".akp"
    end
  end
  
  print("---------------------------------")
  debug_print("Exporting sample as AKP:", sample.name)
  
  -- Extract sample data
  local sample_data, sample_rate, frames = extract_sample_data(sample)
  if not sample_data then
    renoise.app():show_status("Failed to extract sample data")
    return
  end
  
  -- Get slice markers
  local slice_points = {}
  if sample.slice_markers and #sample.slice_markers > 0 then
    for i = 1, #sample.slice_markers do
      table.insert(slice_points, sample.slice_markers[i])
    end
    debug_print("Found", #slice_points, "slice markers")
  else
    debug_print("No slice markers found")
  end
  
  -- Create AKP file
  local ok, err = pcall(function()
    write_akp_file(output_path, sample.name, sample_data, sample_rate, slice_points)
  end)
  
  if ok then
    local operations = {}
    table.insert(operations, string.format("sample rate: %d Hz", sample_rate))
    table.insert(operations, string.format("frames: %d", frames))
    if #slice_points > 0 then
      table.insert(operations, string.format("slices: %d", #slice_points))
    end
    
    local status_msg = string.format("Exported AKP: %s", output_path:match("[^/\\]+$"))
    if #operations > 0 then
      status_msg = status_msg .. " (" .. table.concat(operations, ", ") .. ")"
    end
    
    renoise.app():show_status(status_msg)
    print(string.format("Successfully exported: %s -> %s", sample.name, output_path))
    
    if #operations > 0 then
      print("Sample info: " .. table.concat(operations, ", "))
    end
  else
    print(string.format("Failed to create AKP file: %s (Error: %s)", output_path, err))
    renoise.app():show_status("AKP export failed: " .. err)
  end
end

-- Menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Export Current Sample as AKP...",invoke = exportCurrentSampleAsAKP}

-- AKP IMPORT FUNCTIONS

-- Read little-endian 32-bit integer
local function read_le_u32(f)
  local bytes = f:read(4)
  if not bytes or #bytes < 4 then return nil end
  local b1,b2,b3,b4 = bytes:byte(1,4)
  return b4*2^24 + b3*2^16 + b2*2^8 + b1
end

-- Read little-endian 16-bit integer
local function read_le_u16(f)
  local bytes = f:read(2)
  if not bytes or #bytes < 2 then return nil end
  local b1,b2 = bytes:byte(1,2)
  return b2*2^8 + b1
end

-- Read string of specified length
local function read_string(f, length)
  local str = f:read(length)
  if str then
    -- Remove null terminators
    return str:match("^([^%z]*)")
  end
  return ""
end

-- Helper: convert unsigned byte to signed (two's complement)
local function byte_to_twos_complement(byte_val)
  return byte_val >= 128 and byte_val - 256 or byte_val
end

-- Helper: extract MIDI note number from sample name (e.g., "Sample F1" -> 17, "Sample G#2" -> 32)
local function extract_midi_note_from_name(sample_name)
  if not sample_name then return nil end
  
  -- Look for note pattern: note name + optional # + octave number
  local note_pattern = "([ABCDEFG])([#b]?)(%d+)"
  local note_name, accidental, octave_str = sample_name:match(note_pattern)
  
  if not note_name or not octave_str then
    return nil
  end
  
  local octave = tonumber(octave_str)
  if not octave then return nil end
  
  -- Convert note name to semitone offset within octave
  local note_offsets = {
    C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11
  }
  
  local base_note = note_offsets[note_name]
  if not base_note then return nil end
  
  -- Apply accidental
  if accidental == "#" then
    base_note = base_note + 1
  elseif accidental == "b" then
    base_note = base_note - 1
  end
  
  -- Calculate MIDI note number (C4 = 60, so C0 = 12)
  local midi_note = (octave + 1) * 12 + base_note
  
  -- Clamp to valid MIDI range
  if midi_note >= 0 and midi_note <= 127 then
    return midi_note
  end
  
  return nil
end

-- Parse zone data from AKP (enhanced with reference implementation features)
local function parse_zone(zone_data)
  if #zone_data < 46 then return nil end
  
  local zone = {}
  local pos = 2  -- Skip first byte (0x01)
  
  -- Read sample name length and name
  local name_len = zone_data:byte(pos)
  pos = pos + 1
  
  if name_len > 0 and name_len <= 20 then
    zone.sample_name = zone_data:sub(pos, pos + math.min(name_len - 1, 19))
    -- Clean up sample name
    zone.sample_name = zone.sample_name:match("^([^%z]*)")
  else
    zone.sample_name = ""
  end
  pos = pos + 20  -- Skip to next section
  
  -- Skip 12 bytes of zone parameters to get to velocity range
  pos = pos + 12
  
  -- Read velocity range
  zone.vel_low = zone_data:byte(pos)
  zone.vel_high = zone_data:byte(pos + 1)
  pos = pos + 2
  
  -- Read tuning and other parameters (with proper signed conversion)
  zone.fine_tune = byte_to_twos_complement(zone_data:byte(pos))
  zone.semitone_tune = byte_to_twos_complement(zone_data:byte(pos + 1))
  zone.filter = zone_data:byte(pos + 2)
  
  -- Convert pan from signed byte to normalized float (reference approach)
  local pan_byte = zone_data:byte(pos + 3)
  zone.pan = (byte_to_twos_complement(pan_byte) / 100.0) + 0.5
  -- Clamp pan to valid range [0.0, 1.0]
  zone.pan = math.max(0.0, math.min(1.0, zone.pan))
  
  zone.playback_mode = zone_data:byte(pos + 4)
  zone.output = zone_data:byte(pos + 5)
  zone.zone_level = zone_data:byte(pos + 6)
  zone.keyboard_track = zone_data:byte(pos + 7)
  
  return zone
end

-- Parse keygroup data from AKP (enhanced with reference implementation approach)
local function parse_keygroup(kgrp_data)
  debug_print("Parsing keygroup data, size:", #kgrp_data)
  local keygroup = {zones = {}}
  local pos = 1
  
  -- Parse subchunks
  while pos + 8 <= #kgrp_data do
    local chunk_id = kgrp_data:sub(pos, pos + 3)
    local size_bytes = kgrp_data:sub(pos + 4, pos + 7)
    local size = string.byte(size_bytes, 1) + string.byte(size_bytes, 2) * 256 + 
                 string.byte(size_bytes, 3) * 65536 + string.byte(size_bytes, 4) * 16777216
    
    debug_print("Keygroup subchunk:", chunk_id, "size:", size)
    pos = pos + 8
    
    if chunk_id == "kloc" and size >= 16 then
      -- Parse key location data with note offset adjustment (reference approach)
      local kloc_data = kgrp_data:sub(pos, pos + size - 1)
      if #kloc_data >= 16 then
        -- Use correct byte positions (reference uses bytes 12-15 relative to chunk start)
        local raw_low = kloc_data:byte(13)  -- kloc_data is 0-based relative to chunk, so +13 for byte 12
        local raw_high = kloc_data:byte(14) -- +14 for byte 13
        
        if raw_low and raw_high then
          -- Apply -12 offset but handle edge cases properly
          keygroup.low_note = raw_low - 12
          keygroup.high_note = raw_high - 12
          
          -- If the offset creates invalid ranges, don't apply it
          if keygroup.low_note < 0 or keygroup.high_note < 0 or keygroup.low_note > keygroup.high_note then
            keygroup.low_note = raw_low
            keygroup.high_note = raw_high
          end
          
          -- Clamp to valid MIDI range
          keygroup.low_note = math.max(0, math.min(127, keygroup.low_note))
          keygroup.high_note = math.max(keygroup.low_note, math.min(127, keygroup.high_note))
          
          -- Extract keygroup-level tuning (reference approach)
          keygroup.semitone_tune = byte_to_twos_complement(kloc_data:byte(15))
          keygroup.fine_tune = byte_to_twos_complement(kloc_data:byte(16))
          
          debug_print("Key range:", keygroup.low_note, "to", keygroup.high_note, 
                     "tune:", keygroup.semitone_tune, keygroup.fine_tune)
        end
      end
      
    elseif chunk_id == "zone" and size >= 46 then
      -- Parse zone data
      local zone_data = kgrp_data:sub(pos, pos + size - 1)
      local zone = parse_zone(zone_data)
      if zone and zone.sample_name ~= "" then
        table.insert(keygroup.zones, zone)
        debug_print("Found zone:", zone.sample_name, "vel:", zone.vel_low .. "-" .. zone.vel_high,
                   "pan:", string.format("%.2f", zone.pan))
      end
    end
    
    pos = pos + size
    -- Skip padding byte if size is odd
    if size % 2 == 1 then pos = pos + 1 end
  end
  
  return keygroup
end

-- Function to parse AKP keygroup data using alternative method
local function parse_akp_alternative(akp_path, data)
  print("[AKP Export] Parsing AKP file using alternative method, size:", #data)
  
  local keygroups = {}
  local pos = 1
  
  -- Find all "kloc" chunks
  while pos <= #data - 4 do
    local kloc_pos = data:find("kloc", pos)
    if not kloc_pos then break end
    
    local chunk_start = kloc_pos + 4  -- after "kloc"
    if chunk_start + 4 > #data then break end
    
    -- Read chunk size
    local size_bytes = data:sub(chunk_start, chunk_start + 3)
    local chunk_size = size_bytes:byte(1) + 
                      size_bytes:byte(2) * 256 + 
                      size_bytes:byte(3) * 65536 + 
                      size_bytes:byte(4) * 16777216
    
    local data_start = chunk_start + 4  -- after size
    local data_end = data_start + chunk_size - 1
    
    if data_end > #data then break end
    
    print("[AKP Export] Raw kloc bytes at", kloc_pos, ":")
    local hex_str = ""
    local debug_start = math.max(1, kloc_pos)
    local debug_end = math.min(#data, kloc_pos + 23)
    for i = debug_start, debug_end do
      hex_str = hex_str .. string.format("%02X ", data:byte(i))
    end
    print("[AKP Export]   " .. hex_str)
    
    -- Test different methods to find note range
    local methods = {
      {name = "ref+12/13", low_offset = kloc_pos + 12, high_offset = kloc_pos + 13},
      {name = "after_size+4/5", low_offset = data_start + 4, high_offset = data_start + 5},
      {name = "after_size+8/9", low_offset = data_start + 8, high_offset = data_start + 9},
      {name = "direct+4/5", low_offset = kloc_pos + 4, high_offset = kloc_pos + 5},
      {name = "direct+8/9", low_offset = kloc_pos + 8, high_offset = kloc_pos + 9}
    }
    
    local best_method = nil
    local best_score = -1
    
    for _, method in ipairs(methods) do
      if method.low_offset <= #data and method.high_offset <= #data then
        local low_raw = data:byte(method.low_offset)
        local high_raw = data:byte(method.high_offset)
        
        print("[AKP Export] Method", method.name, "raw values:", low_raw, high_raw)
        
        -- Test both with and without offset
        local variants = {
          {suffix = "no_offset", low_note = low_raw, high_note = high_raw},
          {suffix = "minus_12", low_note = low_raw - 12, high_note = high_raw - 12}
        }
        
        for _, variant in ipairs(variants) do
          local low_note = variant.low_note
          local high_note = variant.high_note
          
          -- Check if range is valid
          if low_note >= 0 and high_note >= 0 and 
             low_note <= 127 and high_note <= 127 and 
             low_note <= high_note then
            print("[AKP Export]   Valid range found:", variant.suffix, "->", low_note .. "-" .. high_note)
            
            -- Score this method (prefer reasonable note ranges)
            local score = 0
            local range_size = high_note - low_note
            
            -- Prefer ranges that aren't just 0-0
            if low_note > 0 or high_note > 0 then
              score = score + 10
            end
            
            -- Prefer ranges that make musical sense (not too wide, not too narrow)
            if range_size >= 1 and range_size <= 24 then
              score = score + 5
            end
            
            -- Prefer ranges in reasonable MIDI note range
            if low_note >= 12 and high_note <= 108 then
              score = score + 3
            end
            
            -- Bonus for ref+12/13 method (matches specification)
            if method.name == "ref+12/13" then
              score = score + 20
            end
            
            if score > best_score then
              best_score = score
              best_method = {
                name = method.name .. "_" .. variant.suffix,
                low_note = low_note,
                high_note = high_note,
                low_offset = method.low_offset,
                high_offset = method.high_offset
              }
            end
          end
        end
      end
    end
    
    if best_method then
      print("[AKP Export] Selected method:", best_method.name, "range:", best_method.low_note .. "-" .. best_method.high_note, "tune:", 0, 0)
      
      -- Extract zone information
      local zones = {}
      
      -- Look for zone data after kloc chunk
      local search_start = data_end + 1
      local search_end = math.min(#data, search_start + 1000)
      
      for zone_idx = 1, 4 do
        local zone_pos = data:find("zone", search_start)
        if not zone_pos or zone_pos > search_end then break end
        
        local zone_data_start = zone_pos + 8  -- "zone" + 4 byte size
        if zone_data_start + 46 > #data then break end
        
        -- Extract sample name
        local name_len = data:byte(zone_data_start + 1)
        if name_len and name_len > 0 and name_len <= 20 then
          local sample_name = data:sub(zone_data_start + 2, zone_data_start + 1 + math.min(name_len, 20))
          sample_name = sample_name:gsub("%z", "")  -- Remove null bytes
          
          if sample_name and sample_name ~= "" then
            -- Extract zone parameters
            local vel_low = data:byte(zone_data_start + 34) or 0
            local vel_high = data:byte(zone_data_start + 35) or 127
            local fine_tune_raw = data:byte(zone_data_start + 36) or 0
            local semitone_tune_raw = data:byte(zone_data_start + 37) or 0
            local pan_raw = data:byte(zone_data_start + 39) or 0
            
            -- Convert signed bytes
            local fine_tune = fine_tune_raw > 127 and (fine_tune_raw - 256) or fine_tune_raw
            local semitone_tune = semitone_tune_raw > 127 and (semitone_tune_raw - 256) or semitone_tune_raw
            local pan_signed = pan_raw > 127 and (pan_raw - 256) or pan_raw
            local pan_normalized = math.max(0, math.min(1, (pan_signed + 50) / 100))
            
            table.insert(zones, {
              sample_name = sample_name,
              velocity_low = vel_low,
              velocity_high = vel_high,
              fine_tune = fine_tune,
              semitone_tune = semitone_tune,
              pan = pan_normalized
            })
            
            print("[AKP Export] Zone", zone_idx, ":", sample_name, "vel:", vel_low .. "-" .. vel_high, "tune:", semitone_tune, fine_tune, "pan:", string.format("%.2f", pan_normalized))
          end
        end
        
        search_start = zone_pos + 50
      end
      
      if #zones > 0 then
        table.insert(keygroups, {
          low_note = best_method.low_note,
          high_note = best_method.high_note,
          zones = zones
        })
      end
    else
      print("[AKP Export] Warning: No valid method found, skipping keygroup")
    end
    
    pos = kloc_pos + 1
  end
  
  print("[AKP Export] Successfully parsed using alternative method:", #keygroups, "keygroups")
  return keygroups
end

-- Read and parse AKP file (enhanced with alternative parsing)
local function parse_akp_file(file_path)
  debug_print("Parsing AKP file:", file_path)
  
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open AKP file: " .. err)
  end
  
  -- Read entire file into memory for alternative parsing
  local data = f:read("*all")
  f:close()
  
  if #data < 20 then
    error("File too small to be AKP file")
  end
  
  -- Check RIFF header
  if data:sub(1, 4) ~= "RIFF" then
    error("Not a valid RIFF file")
  end
  
  -- Try alternative parsing method first (more robust for complex AKP files)
  local ok, result = pcall(function()
    return parse_akp_alternative(file_path, data)
  end)
  
  if ok and result and #result > 0 then
    debug_print("Successfully parsed using alternative method:", #result, "keygroups")
    return result
  else
    debug_print("Alternative parsing failed, trying standard method")
    error("Failed to parse AKP file with alternative method")
  end
end

-- Main AKP import function
function importAKPFile(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.akp"}, 
      "Import AKP File"
    )
    
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end

  print("---------------------------------")
  debug_print("Importing AKP file:", file_path)

  -- Parse AKP file
  local keygroups
  local ok, err = pcall(function()
    keygroups = parse_akp_file(file_path)
  end)

  if not ok then
    print(string.format("Failed to parse AKP file: %s (Error: %s)", file_path, err))
    renoise.app():show_status("AKP import failed: " .. err)
    return
  end

  if not keygroups or #keygroups == 0 then
    renoise.app():show_status("No keygroups found in AKP file")
    return
  end

  debug_print("Found", #keygroups, "keygroups")

  local song = renoise.song()
  local akp_dir = get_directory(file_path)
  local akp_name = get_filename_without_ext(file_path)

  -- Create new instrument
  local current_idx = song.selected_instrument_index
  local new_idx = current_idx + 1
  song:insert_instrument_at(new_idx)
  song.selected_instrument_index = new_idx
  local instrument = song.instruments[new_idx]
  instrument.name = akp_name

  local loaded_samples = 0
  
  -- Calculate non-overlapping note ranges for keygroups
  local keygroup_ranges = {}
  local total_keygroups = #keygroups
  
  if total_keygroups > 1 then
    -- Create sequential, non-overlapping ranges
    local notes_per_keygroup = math.floor(120 / total_keygroups)
    local remaining_notes = 120 % total_keygroups
    
    local current_note = 0
    for kg_idx = 1, total_keygroups do
      local range_size = notes_per_keygroup
      if kg_idx <= remaining_notes then
        range_size = range_size + 1
      end
      
      -- For the last keygroup, adjust range to end at previous keygroup's end
      if kg_idx == total_keygroups and kg_idx > 1 then
        -- Make last keygroup end where the previous keygroup ends
        local prev_range = keygroup_ranges[kg_idx - 1]
        keygroup_ranges[kg_idx] = {
          low = prev_range.low,
          high = prev_range.high
        }
      else
        local range_high = math.min(119, current_note + range_size - 1)
        keygroup_ranges[kg_idx] = {
          low = current_note,
          high = range_high
        }
        current_note = range_high + 1
      end
      
      debug_print("Keygroup", kg_idx, "assigned range:", keygroup_ranges[kg_idx].low .. "-" .. keygroup_ranges[kg_idx].high)
    end
  else
    -- Single keygroup gets full range
    keygroup_ranges[1] = {low = 0, high = 119}
  end
  
  -- Process each keygroup
  for kg_idx, keygroup in ipairs(keygroups) do
    debug_print("Processing keygroup", kg_idx, "with", #keygroup.zones, "zones")
    
    for zone_idx, zone in ipairs(keygroup.zones) do
      local sample_path = akp_dir .. "/" .. zone.sample_name .. ".wav"
      
      if file_exists(sample_path) then
        debug_print("Loading WAV file:", sample_path)
        
        -- Insert new sample and load from file
        local sample_index = #instrument.samples + 1
        instrument:insert_sample_at(sample_index)
        local sample = instrument.samples[sample_index]
        
        -- Load sample data from file
        local load_success = pcall(function()
          sample.sample_buffer:load_from(sample_path)
        end)
        
        if load_success and sample.sample_buffer.has_sample_data then
          sample.name = zone.sample_name
          loaded_samples = loaded_samples + 1
          debug_print("Loaded sample:", zone.sample_name, "(" .. sample.sample_buffer.number_of_frames .. " frames)")
          
          -- Apply zone-level tuning and parameters
          local total_semitone = (zone.semitone_tune or 0)
          local total_fine = (zone.fine_tune or 0)
          
          sample.transpose = total_semitone
          sample.fine_tune = total_fine * 10
          sample.panning = zone.pan or 0.5
          
          debug_print("Applied tuning - transpose:", total_semitone, "fine_tune:", total_fine, "pan:", zone.pan or 0.5)
          
          -- Use calculated non-overlapping range for this keygroup
          local assigned_range = keygroup_ranges[kg_idx]
          local note_range_low = assigned_range.low
          local note_range_high = assigned_range.high
          local base_note = note_range_low
          
          -- Apply sample mapping
          if sample.sample_mapping then
            sample.sample_mapping.base_note = math.max(0, math.min(119, base_note))
            sample.sample_mapping.note_range = {note_range_low, note_range_high}
            sample.sample_mapping.velocity_range = {
              math.max(0, math.min(127, zone.velocity_low or 0)),
              math.max(0, math.min(127, zone.velocity_high or 127))
            }
            
            debug_print("Set sample mapping - base_note:", base_note, "note_range:", note_range_low .. "-" .. note_range_high, "vel_range:", (zone.velocity_low or 0) .. "-" .. (zone.velocity_high or 127))
          end
        else
          debug_print("Failed to load sample:", zone.sample_name)
        end
      else
        debug_print("Sample file not found:", sample_path)
      end
    end
  end
  
  local status_msg = string.format("Imported AKP: %s (%d samples)", 
    akp_name, loaded_samples)
  renoise.app():show_status(status_msg)
  print(string.format("Successfully imported: %s -> %d samples loaded", file_path, loaded_samples))
end

-- Menu entries for import


renoise.tool():add_keybinding{name="Global:Paketti:Import AKP File...",invoke = importAKPFile}

-- File import hook for .akp files
local akp_integration = {
  name = "Akai AKP Program File",
  category = "sample",
  extensions = { "akp" },
  invoke = importAKPFile
}

if not renoise.tool():has_file_import_hook("sample", { "akp" }) then
  renoise.tool():add_file_import_hook(akp_integration)
end

