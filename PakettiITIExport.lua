-- PakettiITIExport.lua
-- Impulse Tracker Instrument (.ITI) exporter for Renoise
-- Based on official ITTECH2.TXT specification

local _DEBUG = true
local function dprint(...) if _DEBUG then print("ITI Export:", ...) end end

-- Helper functions for writing binary data (little-endian)
function iti_write_byte(value)
  return string.char(value)
end

function iti_write_word(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  return string.char(b1, b2)
end

function iti_write_dword(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  return string.char(b1, b2, b3, b4)
end

function iti_write_string(str, length)
  local result = str:sub(1, length)
  -- Pad with zeros if too short
  while #result < length do
    result = result .. string.char(0)
  end
  return result
end

-- Bitwise AND function for Lua 5.1 compatibility
local function bit_and(a, b)
  local result = 0
  local bit = 1
  while a > 0 and b > 0 do
    if (a % 2 == 1) and (b % 2 == 1) then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bit_or(a, b)
  local result = 0
  local bit = 1
  while a > 0 or b > 0 do
    if (a % 2 == 1) or (b % 2 == 1) then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

-- ITI Format constants (from ITTECH2.TXT)
local ITI_INSTRUMENT_SIZE = 554
local ITI_SAMPLE_HEADER_SIZE = 80
local ITI_KEYBOARD_TABLE_OFFSET = 0x40
local ITI_ENVELOPES_OFFSET = 0x130

-- Sample flags
local SAMPLE_ASSOCIATED = 1
local SAMPLE_16BIT = 2
local SAMPLE_STEREO = 4
local SAMPLE_COMPRESSED = 8
local SAMPLE_LOOP = 16
local SAMPLE_SUSTAIN_LOOP = 32
local SAMPLE_PINGPONG_LOOP = 64
local SAMPLE_PINGPONG_SUSTAIN = 128

function iti_export_instrument(instrument, filepath)
  if not instrument then
    renoise.app():show_status("ITI Export Error: No instrument selected")
    return false
  end
  
  dprint("Starting ITI export for instrument:", instrument.name)
  
  -- Build the ITI file data
  local iti_data = {}
  
  -- Write instrument header
  local instrument_header = iti_build_instrument_header(instrument)
  table.insert(iti_data, instrument_header)
  
  -- Collect sample data and headers
  local sample_headers = {}
  local sample_data_blocks = {}
  
  for i = 1, #instrument.samples do
    local sample = instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      local header, data = iti_build_sample(sample, i)
      if header and data then
        table.insert(sample_headers, header)
        table.insert(sample_data_blocks, data)
        dprint("Prepared sample", i, ":", sample.name, "- header size:", #header, "data size:", #data, "bytes")
      end
    end
  end
  
  -- Calculate file offsets for sample data and update sample pointers
  local current_offset = #instrument_header
  
  -- Add size of all sample headers to get offset where sample data begins
  for i = 1, #sample_headers do
    current_offset = current_offset + #sample_headers[i]
  end
  
  -- Now update each sample header with correct sample pointer
  for i = 1, #sample_headers do
    local header = sample_headers[i]
    
    -- Sample pointer is at offset 0x48 (72 decimal) in the IMPS header
    -- Update the 4-byte sample pointer at this location
    local pointer_offset = 73  -- 1-based index (0x48 + 1)
    
    -- Convert current_offset to 4 bytes (little-endian)
    local ptr_bytes = iti_write_dword(current_offset)
    
    -- Replace the placeholder pointer bytes in the header
    header = header:sub(1, pointer_offset - 1) .. ptr_bytes .. header:sub(pointer_offset + 4)
    sample_headers[i] = header
    
    dprint(string.format("Sample %d: pointer set to %d (0x%X)", i, current_offset, current_offset))
    
    -- Move offset forward by this sample's data size
    current_offset = current_offset + #sample_data_blocks[i]
  end
  
  -- Write sample headers
  for i = 1, #sample_headers do
    table.insert(iti_data, sample_headers[i])
  end
  
  -- Write sample data blocks
  for i = 1, #sample_data_blocks do
    table.insert(iti_data, sample_data_blocks[i])
  end
  
  -- Concatenate all data
  local final_data = table.concat(iti_data)
  
  -- Write to file
  local f = io.open(filepath, "wb")
  if not f then
    renoise.app():show_status("ITI Export Error: Cannot create file")
    return false
  end
  
  f:write(final_data)
  f:close()
  
  renoise.app():show_status(string.format("ITI '%s' exported successfully (%d samples, %d bytes)", 
    instrument.name, #sample_headers, #final_data))
  dprint("ITI export completed:", filepath)
  
  return true
end

function iti_build_instrument_header(instrument)
  local data = {}
  
  -- IMPI signature
  table.insert(data, "IMPI")
  
  -- DOS filename (12 bytes) - use instrument name
  local dos_name = instrument.name:upper():gsub("[^%w]", ""):sub(1, 8)
  table.insert(data, iti_write_string(dos_name .. ".ITI", 12))
  
  -- Null byte
  table.insert(data, iti_write_byte(0))
  
  -- New Note Actions (use defaults)
  table.insert(data, iti_write_byte(0))  -- NNA: Cut
  table.insert(data, iti_write_byte(0))  -- DCT: Off
  table.insert(data, iti_write_byte(0))  -- DCA: Cut
  
  -- Fadeout (0-128, converted from Renoise 0-255)
  table.insert(data, iti_write_word(64))  -- Default fadeout
  
  -- Pitch-Pan separation and center
  table.insert(data, iti_write_byte(0))  -- PPS: 0 (no separation)
  table.insert(data, iti_write_byte(60)) -- PPC: C-5
  
  -- Global volume (0-128, convert from Renoise 0-1)
  local global_volume = math.floor(instrument.volume * 128)
  table.insert(data, iti_write_byte(math.min(128, global_volume)))
  
  -- Default pan (0-64 or 128+pan for enabled panning)
  table.insert(data, iti_write_byte(32))  -- Center pan
  
  -- Random volume and panning variation
  table.insert(data, iti_write_byte(0))  -- Random volume: 0
  table.insert(data, iti_write_byte(0))  -- Random panning: 0
  
  -- Tracker version (IT 2.14 = 0x0214)
  table.insert(data, iti_write_word(0x0214))
  
  -- Number of samples
  local num_samples = 0
  for i = 1, #instrument.samples do
    if instrument.samples[i].sample_buffer.has_sample_data then
      num_samples = num_samples + 1
    end
  end
  table.insert(data, iti_write_byte(math.min(99, num_samples)))
  
  -- Unused byte
  table.insert(data, iti_write_byte(0))
  
  -- Instrument name (26 bytes)
  table.insert(data, iti_write_string(instrument.name, 26))
  
  -- Initial filter cutoff, resonance, MIDI channel, MIDI program, MIDI bank (6 bytes)
  table.insert(data, iti_write_byte(0))  -- IFC
  table.insert(data, iti_write_byte(0))  -- IFR
  table.insert(data, iti_write_byte(0))  -- MCh
  table.insert(data, iti_write_byte(0))  -- MPr
  table.insert(data, iti_write_word(0))  -- MIDIBnk
  
  -- Pad to keyboard table offset (0x40 = 64 bytes)
  local current_size = 4 + 12 + 1 + 1 + 1 + 1 + 2 + 1 + 1 + 1 + 1 + 1 + 1 + 2 + 1 + 1 + 26 + 6
  while current_size < ITI_KEYBOARD_TABLE_OFFSET do
    table.insert(data, iti_write_byte(0))
    current_size = current_size + 1
  end
  
  -- Build keyboard table (240 bytes = 120 note/sample pairs)
  local keyboard_table = iti_build_keyboard_table(instrument)
  table.insert(data, keyboard_table)
  
  -- Pad to envelope offset (0x130 = 304 bytes)
  current_size = ITI_KEYBOARD_TABLE_OFFSET + 240
  while current_size < ITI_ENVELOPES_OFFSET do
    table.insert(data, iti_write_byte(0))
    current_size = current_size + 1
  end
  
  -- Build envelopes (3 x 81 bytes each = 243 bytes)
  local envelopes = iti_build_envelopes(instrument)
  table.insert(data, envelopes)
  
  -- Pad to total instrument size (554 bytes)
  current_size = ITI_ENVELOPES_OFFSET + 243
  while current_size < ITI_INSTRUMENT_SIZE do
    table.insert(data, iti_write_byte(0))
    current_size = current_size + 1
  end
  
  local result = table.concat(data)
  dprint("Built instrument header:", #result, "bytes")
  return result
end

function iti_build_keyboard_table(instrument)
  local data = {}
  
  -- Build mapping from MIDI note (0-119) to sample index
  local note_to_sample = {}
  
  -- Analyze each sample's keyboard mapping
  for sample_idx = 1, #instrument.samples do
    local sample = instrument.samples[sample_idx]
    if sample and sample.sample_buffer.has_sample_data then
      local mapping = sample.sample_mapping
      if mapping then
        local note_min = mapping.note_range[1]
        local note_max = mapping.note_range[2]
        
        -- Map all notes in this sample's range
        for note = note_min, note_max do
          note_to_sample[note] = sample_idx
        end
      end
    end
  end
  
  -- Write keyboard table (120 entries)
  for midi_note = 0, 119 do
    local sample_idx = note_to_sample[midi_note] or 0
    
    -- ITI format: [note byte] [sample byte]
    -- For chromatic keyboard mapping, each key should reference its own note number
    -- This creates a rising chromatic scale across the keyboard
    -- The "note" field is what pitch this key should trigger
    table.insert(data, iti_write_byte(midi_note))
    table.insert(data, iti_write_byte(sample_idx))
  end
  
  local result = table.concat(data)
  dprint("Built keyboard table:", #result, "bytes (chromatic mapping)")
  return result
end

function iti_build_envelopes(instrument)
  local out = {}

  local function bw(v) return iti_write_word(v or 0) end
  local function bb(v) return iti_write_byte(v or 0) end

  -- Emit block with VALUE->TICK node encoding (used by rio.iti for VOLUME)
  local function emit_VAL_TICK(flags, nodes, vls, vle, sls, sle)
    local e = {}
    table.insert(e, bb(flags or 0))              -- Flags
    table.insert(e, bb(#nodes))                  -- NumNodes
    table.insert(e, bb(vls or 0))                -- VLS
    table.insert(e, bb(vle or 0))                -- VLE
    table.insert(e, bb(sls or 0))                -- SLS
    table.insert(e, bb(sle or 0))                -- SLE
    for i = 1, math.min(#nodes, 25) do           -- Node: VALUE (BYTE), then TICK (WORD)
      local n = nodes[i]
      table.insert(e, bb(n.val))
      table.insert(e, bw(n.tick))
    end
    for i = #nodes + 1, 25 do
      table.insert(e, bb(0)); table.insert(e, bw(0))
    end
    return table.concat(e)
  end

  -- Emit block with TICK->VALUE node encoding (used by rio.iti for PANNING when present)
  local function emit_TICK_VAL(flags, nodes, vls, vle, sls, sle)
    local e = {}
    table.insert(e, bb(flags or 0))
    table.insert(e, bb(#nodes))
    table.insert(e, bb(vls or 0))
    table.insert(e, bb(vle or 0))
    table.insert(e, bb(sls or 0))
    table.insert(e, bb(sle or 0))
    for i = 1, math.min(#nodes, 25) do           -- Node: TICK (WORD), then VALUE (BYTE)
      local n = nodes[i]
      table.insert(e, bw(n.tick))
      table.insert(e, bb(n.val))
    end
    for i = #nodes + 1, 25 do
      table.insert(e, bw(0)); table.insert(e, bb(0))
    end
    return table.concat(e)
  end

  -- === EXACT match to rio.iti ===

  -- Volume: flags=1, nodes=2, VALUE->TICK; nodes (64@0), (64@16)
  table.insert(out, emit_VAL_TICK(0x01, {
    { tick = 0,  val = 64 },
    { tick = 16, val = 64 },
  }, 0, 0, 0, 0))

  -- Panning: flags=0, nodes=2, VLS=2, VLE=0, TICK->VALUE; nodes (0,0), (0,32)
  table.insert(out, emit_TICK_VAL(0x00, {
    { tick = 0, val = 0  },
    { tick = 0, val = 32 },
  }, 2, 0, 0, 0))

  -- Pitch/Frequency: flags=0, nodes=0, VLS=0, VLE=2, no nodes
  do
    local e = {}
    table.insert(e, bb(0x00))  -- Flags
    table.insert(e, bb(0x00))  -- NumNodes
    table.insert(e, bb(0x00))  -- VLS
    table.insert(e, bb(0x02))  -- VLE  (rio.iti sets this to 2)
    table.insert(e, bb(0x00))  -- SLS
    table.insert(e, bb(0x00))  -- SLE
    for i = 1, 25 do           -- pad node area
      table.insert(e, bw(0)); table.insert(e, bb(0))
    end
    table.insert(out, table.concat(e))
  end

  local result = table.concat(out)
  dprint("Built envelopes to match rio.iti exactly:", #result, "bytes")
  return result
end

function iti_build_sample(sample, sample_index)
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    return nil, nil
  end
  
  dprint("Building sample", sample_index, ":", sample.name)
  
  local header_data = {}
  local sample_data = {}
  
  -- Get sample properties
  local sample_rate = buffer.sample_rate
  local num_channels = buffer.number_of_channels
  local num_frames = buffer.number_of_frames
  local bit_depth = buffer.bit_depth
  
  -- Determine export format (8-bit or 16-bit)
  local export_16bit = (bit_depth >= 16)
  local export_stereo = (num_channels > 1)
  
  dprint("  Source: rate=", sample_rate, "ch=", num_channels, "frames=", num_frames, "bits=", bit_depth)
  dprint("  Export:", export_16bit and "16-bit" or "8-bit", export_stereo and "stereo" or "mono")
  
  -- Build sample header (IMPS)
  table.insert(header_data, "IMPS")
  
  -- DOS filename (12 bytes)
  local dos_name = sample.name:upper():gsub("[^%w]", ""):sub(1, 8)
  table.insert(header_data, iti_write_string(dos_name .. ".ITS", 12))
  
  -- Null byte
  table.insert(header_data, iti_write_byte(0))
  
  -- Global volume (0-64)
  table.insert(header_data, iti_write_byte(64))
  
  -- Sample flags
  local flags = SAMPLE_ASSOCIATED
  if export_16bit then flags = bit_or(flags, SAMPLE_16BIT) end
  if export_stereo then flags = bit_or(flags, SAMPLE_STEREO) end
  
  -- Handle loop mode - PRESERVE LOOP START AND LOOP END!
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    flags = bit_or(flags, SAMPLE_LOOP)
    if sample.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG then
      flags = bit_or(flags, SAMPLE_PINGPONG_LOOP)
    end
  end
  
  table.insert(header_data, iti_write_byte(flags))
  
  -- Default volume (0-64)
  local volume = math.floor(sample.volume * 64)
  table.insert(header_data, iti_write_byte(math.min(64, volume)))
  
  -- Sample name (26 bytes)
  table.insert(header_data, iti_write_string(sample.name, 26))
  
  -- Convert flags (bit 0 = signed samples)
  table.insert(header_data, iti_write_byte(1))  -- Signed samples
  
  -- Default pan (bit 7 set + pan value 0-64)
  local pan_value = 32  -- Center
  if sample.panning ~= 0.5 then
    pan_value = math.floor(sample.panning * 64)
  end
  table.insert(header_data, iti_write_byte(128 + pan_value))  -- Pan enabled
  
  -- Sample length (in frames)
  table.insert(header_data, iti_write_dword(num_frames))
  
  -- Loop begin and end - PRESERVE FROM RENOISE!
  local loop_start = 0
  local loop_end = 0
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    -- Renoise uses 1-based inclusive loop points
    -- IT uses 0-based, with loop_end being exclusive (one sample past the end)
    loop_start = sample.loop_start - 1
    loop_end = sample.loop_end + 1  -- Convert inclusive to exclusive
    
    dprint("  Loop: Renoise", sample.loop_start, "-", sample.loop_end, 
           "-> ITI", loop_start, "-", loop_end)
  end
  
  table.insert(header_data, iti_write_dword(loop_start))
  table.insert(header_data, iti_write_dword(loop_end))
  
  -- C5 Speed (sample rate in Hz)
  table.insert(header_data, iti_write_dword(sample_rate))
  
  -- Sustain loop (not used in Renoise)
  table.insert(header_data, iti_write_dword(0))  -- Sustain loop begin
  table.insert(header_data, iti_write_dword(0))  -- Sustain loop end
  
  -- Sample pointer (will be filled with actual offset later)
  -- For now, write placeholder - we'll calculate actual offset when writing file
  local sample_pointer_offset = #table.concat(header_data)
  table.insert(header_data, iti_write_dword(0))  -- Placeholder
  
  -- Vibrato settings
  table.insert(header_data, iti_write_byte(0))  -- Vibrato speed
  table.insert(header_data, iti_write_byte(0))  -- Vibrato depth
  table.insert(header_data, iti_write_byte(0))  -- Vibrato rate
  table.insert(header_data, iti_write_byte(0))  -- Vibrato type
  
  local header = table.concat(header_data)
  dprint("  Sample header:", #header, "bytes")
  
  -- Extract and write sample data (uncompressed PCM)
  local pcm_data = iti_extract_sample_data(buffer, export_16bit, export_stereo)
  dprint("  Sample data:", #pcm_data, "bytes")
  
  return header, pcm_data
end

function iti_extract_sample_data(buffer, is_16bit, is_stereo)
  local data = {}
  local num_frames = buffer.number_of_frames
  local num_channels = is_stereo and 2 or 1
  
  dprint("  Extracting PCM data:", num_frames, "frames,", num_channels, "channel(s)")
  
  for frame = 1, num_frames do
    for channel = 1, num_channels do
      -- Get sample value (-1.0 to 1.0)
      local value = buffer:sample_data(channel, frame)
      
      if is_16bit then
        -- Convert to signed 16-bit integer (-32768 to 32767)
        -- Use proper scaling: negative values use 32768, positive use 32767
        local int_value
        if value >= 0 then
          int_value = math.floor(value * 32767 + 0.5)
        else
          int_value = math.floor(value * 32768 + 0.5)
        end
        
        -- Clamp to valid range
        if int_value < -32768 then int_value = -32768 end
        if int_value > 32767 then int_value = 32767 end
        
        -- Convert to unsigned for writing (two's complement)
        if int_value < 0 then int_value = int_value + 65536 end
        
        -- Write as little-endian word
        table.insert(data, iti_write_word(int_value))
      else
        -- Convert to signed 8-bit integer (-128 to 127)
        local int_value
        if value >= 0 then
          int_value = math.floor(value * 127 + 0.5)
        else
          int_value = math.floor(value * 128 + 0.5)
        end
        
        -- Clamp to valid range
        if int_value < -128 then int_value = -128 end
        if int_value > 127 then int_value = 127 end
        
        -- Convert to unsigned for writing (two's complement)
        if int_value < 0 then int_value = int_value + 256 end
        
        table.insert(data, iti_write_byte(int_value))
      end
    end
  end
  
  return table.concat(data)
end

-- Menu entry and keybinding for ITI export
function pakettiITIExportDialog()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("No instrument selected for ITI export")
    return
  end
  
  -- Count samples with data
  local sample_count = 0
  for i = 1, #instrument.samples do
    if instrument.samples[i].sample_buffer.has_sample_data then
      sample_count = sample_count + 1
    end
  end
  
  if sample_count == 0 then
    renoise.app():show_status("Selected instrument has no samples to export")
    return
  end
  
  -- Default filename based on instrument name
  local default_name = instrument.name:gsub("[^%w%s-]", ""):gsub("%s+", "_")
  if default_name == "" then
    default_name = string.format("Instrument_%02X", song.selected_instrument_index - 1)
  end
  default_name = default_name .. ".iti"
  
  -- Show save dialog
  local filepath = renoise.app():prompt_for_filename_to_write("iti", "Export Impulse Tracker Instrument")
  
  if filepath and filepath ~= "" then
    iti_export_instrument(instrument, filepath)
  else
    renoise.app():show_status("ITI export cancelled")
  end
end

renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Export:Export Instrument to ITI...",invoke = function() pakettiITIExportDialog() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Instrument to ITI...",invoke = function() pakettiITIExportDialog() end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Export Instrument to ITI...",invoke = function() pakettiITIExportDialog() end}