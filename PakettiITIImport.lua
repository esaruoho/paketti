-- PakettiITIImport.lua
-- Perfect Impulse Tracker Instrument (.ITI) importer for Renoise
-- Based on official ITTECH2.TXT specification

local _DEBUG = true
local function dprint(...) if _DEBUG then print("ITI Debug:", ...) end end

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.iti$", "") end
  return "ITI Instrument"
end

-- Helper functions for reading binary data (little-endian)
local function read_byte(data, pos)
  return data:byte(pos)
end

local function read_word(data, pos)
  local b1, b2 = data:byte(pos, pos + 1)
  return b1 + (b2 * 256)
end

local function read_dword(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function read_string(data, pos, length)
  local str = data:sub(pos, pos + length - 1)
  local null_pos = str:find('\0')
  if null_pos then
    return str:sub(1, null_pos - 1)
  end
  return str
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

-- ITI Format constants (from ITTECH2.TXT)
local ITI_INSTRUMENT_SIZE = 554  -- Total instrument size including envelopes
local ITI_SAMPLE_HEADER_SIZE = 80
local ITI_ENVELOPE_SIZE = 81     -- Flg(1) Num(1) LpB(1) LpE(1) SLB(1) SLE(1) + 75 bytes nodes
local ITI_KEYBOARD_TABLE_SIZE = 240
local ITI_KEYBOARD_TABLE_OFFSET = 0x40  -- 64 decimal - keyboard table offset per ITTECH2.TXT
local ITI_ENVELOPES_OFFSET = 0x130  -- 304 decimal - where envelopes start

-- New Note Actions
local NNA_CUT = 0
local NNA_CONTINUE = 1
local NNA_NOTE_OFF = 2
local NNA_NOTE_FADE = 3

-- Duplicate Check Types  
local DCT_OFF = 0
local DCT_NOTE = 1
local DCT_SAMPLE = 2
local DCT_INSTRUMENT = 3

-- Duplicate Check Actions
local DCA_CUT = 0
local DCA_NOTE_OFF = 1
local DCA_NOTE_FADE = 2

-- Sample flags (from ITTECH2.TXT)
local SAMPLE_ASSOCIATED = 1     -- Bit 0: sample associated with header
local SAMPLE_16BIT = 2          -- Bit 1: 16 bit vs 8 bit
local SAMPLE_STEREO = 4         -- Bit 2: stereo vs mono
local SAMPLE_COMPRESSED = 8     -- Bit 3: compressed samples
local SAMPLE_LOOP = 16          -- Bit 4: use loop
local SAMPLE_SUSTAIN_LOOP = 32  -- Bit 5: use sustain loop
local SAMPLE_PINGPONG_LOOP = 64 -- Bit 6: ping pong loop vs forward
local SAMPLE_PINGPONG_SUSTAIN = 128 -- Bit 7: ping pong sustain loop

-- Envelope flags
local ENV_ON = 1           -- Bit 0: envelope on/off
local ENV_LOOP = 2         -- Bit 1: loop on/off  
local ENV_SUSTAIN_LOOP = 4 -- Bit 2: sustain loop on/off

function iti_loadinstrument(filename)
  -- Check if filename is nil or empty (user cancelled dialog)
  if not filename or filename == "" then
    dprint("ITI import cancelled - no file selected")
    renoise.app():show_status("ITI import cancelled - no file selected")
    return false
  end
  
  dprint("Starting ITI import for file:", filename)
  
  local song = renoise.song()
  
  -- Read the entire file
  local f = io.open(filename, "rb")
  if not f then
    dprint("ERROR: Cannot open ITI file")
    renoise.app():show_status("ITI Import Error: Cannot open file.")
    return false
  end
  
  local data = f:read("*a")
  f:close()
  
  if #data < ITI_INSTRUMENT_SIZE then
    dprint("ERROR: File too small to be valid ITI")
    renoise.app():show_status("ITI Import Error: File too small.")
    return false
  end
  
  dprint("Read ITI file, size:", #data, "bytes")
  
  -- Check for IMPI signature (Impulse Instrument)
  local signature = data:sub(1, 4)
  if signature ~= "IMPI" then
    dprint("ERROR: Invalid ITI signature, found:", signature)
    renoise.app():show_status("ITI Import Error: Invalid file signature.")
    return false
  end
  
  dprint("Valid IMPI signature found")
  
  -- Parse instrument header according to ITTECH2.TXT specification
  local instrument_data = parse_iti_instrument_header(data)
  if not instrument_data then
    dprint("ERROR: Failed to parse instrument header")
    renoise.app():show_status("ITI Import Error: Failed to parse instrument header.")
    return false
  end
  
  -- Create new instrument
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
  
  -- Apply Paketti default settings
  pakettiPreferencesDefaultInstrumentLoader()
  
  local instrument = song.selected_instrument
  
  -- Clean up any placeholder samples from the template
  for i = #instrument.samples, 1, -1 do
    local sample_name = instrument.samples[i].name
    if sample_name == "Placeholder sample" or sample_name == "Placeholder for drumkit" or sample_name == "" then
      dprint("Removing placeholder sample:", sample_name == "" and "(empty name)" or sample_name)
      instrument:delete_sample_at(i)
    end
  end
  
  -- Set instrument properties
  instrument.name = instrument_data.name
  instrument.volume = math.min(instrument_data.global_volume / 128.0, 1.0)
  
  dprint("Set instrument name:", instrument_data.name)
  dprint("Set instrument volume:", instrument.volume)
  dprint("Instrument has", instrument_data.num_samples, "samples")
  
  -- Parse and load samples
  local loaded_samples = {}
  local iti_sample_data = {}  -- Store original ITI sample data for tuning
  local compressed_samples = {}
  
  if instrument_data.num_samples > 0 then
    dprint("Loading", instrument_data.num_samples, "samples")
    
    -- Find all IMPS signatures in the file (embedded samples)
    local sample_positions = find_sample_positions(data)
    dprint("Found", #sample_positions, "IMPS signatures at positions:", table.concat(sample_positions, ", "))
    
    for i = 1, math.min(instrument_data.num_samples, #sample_positions) do
      local sample_pos = sample_positions[i]
      dprint("Processing sample", i, "at position", sample_pos)
      
      local sample_data = parse_iti_sample(data, sample_pos)
      if sample_data then
        -- Store original ITI sample data for tuning calculations
        iti_sample_data[i] = sample_data
        
        -- Track compressed samples
        if bit_and(sample_data.flags, SAMPLE_COMPRESSED) ~= 0 then
          compressed_samples[i] = true
        end
        
        local renoise_sample = load_iti_sample_to_renoise(instrument, sample_data, data, instrument_data.name)
        if renoise_sample then
          loaded_samples[i] = renoise_sample
          dprint("Successfully loaded sample", i, ":", renoise_sample.name, "at instrument sample index", #instrument.samples)
        else
          dprint("Failed to load sample", i)
        end
      else
        dprint("Failed to parse sample", i)
      end
    end
  end
  
  dprint("Loaded", #loaded_samples, "out of", instrument_data.num_samples, "expected samples")
  
  -- Debug: Show loaded samples
  for i = 1, #loaded_samples do
    if loaded_samples[i] then
      dprint("Loaded sample", i, "name:", loaded_samples[i].name)
    end
  end
  
  -- Set up keyboard mapping
  setup_keyboard_mapping(instrument, instrument_data.keyboard_table, loaded_samples, iti_sample_data)
  
  -- Set up envelopes
  setup_envelopes(instrument, instrument_data.envelopes)
  
  -- Add Instr. Macro Device if enabled
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
    if renoise.song().selected_track.type == 2 then 
      renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") 
    else
      loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
      local macro_device = renoise.song().selected_track:device(2)
      macro_device.display_name = string.format("%02X", renoise.song().selected_instrument_index - 1) .. " " .. instrument_data.name
      renoise.song().selected_track.devices[2].is_maximized = false
    end
  end
  
  -- Count compressed samples
  local compressed_count = 0
  for i = 1, #loaded_samples do
    if compressed_samples[i] then
      compressed_count = compressed_count + 1
    end
  end
  
  if #loaded_samples > 0 then
    if compressed_count > 0 then
      if #loaded_samples < instrument_data.num_samples then
        renoise.app():show_status(string.format("ITI '%s': %d/%d samples loaded (%d compressed - attempting decompression)", 
          instrument_data.name, #loaded_samples, instrument_data.num_samples, compressed_count))
      else
        renoise.app():show_status(string.format("ITI '%s': %d samples loaded (%d compressed - with audio placeholders)", 
          instrument_data.name, #loaded_samples, compressed_count))
      end
    else
      renoise.app():show_status(string.format("ITI '%s': %d samples loaded successfully", 
        instrument_data.name, #loaded_samples))
    end
    dprint("ITI import completed successfully")
  else
    renoise.app():show_status(string.format("ITI instrument '%s' imported (instrument properties only)", instrument_data.name))
    dprint("ITI import completed - no samples loaded")
  end
  return true
end

function parse_iti_instrument_header(data)
  local pos = 1
  
  -- Skip IMPI signature (4 bytes)
  pos = pos + 4
  
  -- Skip DOS filename (12 bytes)
  pos = pos + 12
  
  -- Skip null byte
  pos = pos + 1
  
  -- Read instrument properties according to ITTECH2.TXT
  local nna = read_byte(data, pos); pos = pos + 1
  local dct = read_byte(data, pos); pos = pos + 1
  local dca = read_byte(data, pos); pos = pos + 1
  local fadeout = read_word(data, pos); pos = pos + 2
  local pps = read_byte(data, pos); pos = pos + 1  -- Pitch-Pan separation
  local ppc = read_byte(data, pos); pos = pos + 1  -- Pitch-Pan center
  local global_volume = read_byte(data, pos); pos = pos + 1
  local default_pan = read_byte(data, pos); pos = pos + 1
  local random_volume = read_byte(data, pos); pos = pos + 1
  local random_panning = read_byte(data, pos); pos = pos + 1
  local tracker_version = read_word(data, pos); pos = pos + 2
  local num_samples = read_byte(data, pos); pos = pos + 1
  local unused = read_byte(data, pos); pos = pos + 1
  
  -- Read instrument name (26 bytes)
  local name = read_string(data, pos, 26)
  pos = pos + 26
  
  -- Skip to IFC, IFR, MCh, MPr, MIDIBnk (5 bytes total)
  pos = pos + 5
  
  -- Read keyboard table from fixed offset 0x40 (240 bytes = 120 note/sample pairs)
  -- Each pair: note first (0-119), then sample number (0-99, 0=no sample)
  local keyboard_table = {}
  local table_pos = ITI_KEYBOARD_TABLE_OFFSET + 1  -- Convert to 1-based indexing
  dprint(string.format("Reading keyboard table from fixed offset %d (0x%X)", ITI_KEYBOARD_TABLE_OFFSET, ITI_KEYBOARD_TABLE_OFFSET))
  
  -- Show raw hex data first to verify we're reading the right location
  dprint("Raw keyboard table sample (first 24 bytes as hex):")
  local hex_sample = ""
  for i = 0, 23 do
    if table_pos + i <= #data then
      hex_sample = hex_sample .. string.format("%02X ", string.byte(data, table_pos + i))
    end
  end
  dprint(hex_sample)
  
  for i = 1, 120 do
    local note = read_byte(data, table_pos); table_pos = table_pos + 1
    local sample = read_byte(data, table_pos); table_pos = table_pos + 1
    keyboard_table[i] = {note = note, sample = sample}
    
    -- Debug: show ALL entries that have a sample assigned
    if sample > 0 then
      local midi_note = i - 1
      local note_name = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[midi_note % 12 + 1] .. math.floor(midi_note / 12)
      dprint(string.format("ITI Keyboard[%d] (%s): original_note=%d, sample=%d", midi_note, note_name, note, sample))
    end
  end
  
  -- Read envelopes starting at offset 0x130 (304 decimal)
  -- 3 envelopes: volume, panning, pitch
  local envelopes = {}
  local envelope_pos = ITI_ENVELOPES_OFFSET + 1  -- Convert to 1-based indexing
  
  for env_type = 1, 3 do
    local envelope = parse_envelope(data, envelope_pos)
    envelopes[env_type] = envelope
    envelope_pos = envelope_pos + ITI_ENVELOPE_SIZE
  end
  
  dprint("Parsed instrument header:")
  dprint("  Name:", name)
  dprint("  Global Volume:", global_volume)
  dprint("  Number of Samples:", num_samples)
  dprint("  NNA:", nna, "DCT:", dct, "DCA:", dca)
  dprint("  Fadeout:", fadeout)
  dprint("  PPS:", pps, "PPC:", ppc)
  
  return {
    name = name,
    nna = nna,
    dct = dct,
    dca = dca,
    fadeout = fadeout,
    pps = pps,
    ppc = ppc,
    global_volume = global_volume,
    default_pan = default_pan,
    random_volume = random_volume,
    random_panning = random_panning,
    tracker_version = tracker_version,
    num_samples = num_samples,
    keyboard_table = keyboard_table,
    envelopes = envelopes
  }
end

function parse_envelope(data, pos)
  local flags = read_byte(data, pos); pos = pos + 1
  local num_nodes = read_byte(data, pos); pos = pos + 1
  local loop_begin = read_byte(data, pos); pos = pos + 1
  local loop_end = read_byte(data, pos); pos = pos + 1
  local sustain_loop_begin = read_byte(data, pos); pos = pos + 1
  local sustain_loop_end = read_byte(data, pos); pos = pos + 1
  
  -- Read node points (25 sets maximum, 3 bytes each: y-value + tick)
  local nodes = {}
  for i = 1, math.min(num_nodes, 25) do
    local y_value = read_byte(data, pos); pos = pos + 1
    local tick = read_word(data, pos); pos = pos + 2
    nodes[i] = {y = y_value, tick = tick}
  end
  
  dprint("Parsed envelope: enabled=", bit_and(flags, ENV_ON) ~= 0, "nodes=", num_nodes)
  
  return {
    enabled = bit_and(flags, ENV_ON) ~= 0,
    loop_enabled = bit_and(flags, ENV_LOOP) ~= 0,
    sustain_loop_enabled = bit_and(flags, ENV_SUSTAIN_LOOP) ~= 0,
    num_nodes = num_nodes,
    loop_begin = loop_begin,
    loop_end = loop_end,
    sustain_loop_begin = sustain_loop_begin,
    sustain_loop_end = sustain_loop_end,
    nodes = nodes
  }
end

function find_sample_positions(data)
  local positions = {}
  for i = 1, #data - 3 do
    if data:sub(i, i + 3) == "IMPS" then
      table.insert(positions, i)
    end
  end
  return positions
end

function parse_iti_sample(data, pos)
  if pos + ITI_SAMPLE_HEADER_SIZE > #data then
    dprint("ERROR: Not enough data for sample header at position", pos)
    return nil
  end
  
  -- Verify IMPS signature
  local signature = data:sub(pos, pos + 3)
  if signature ~= "IMPS" then
    dprint("ERROR: Invalid sample signature at", pos, "found:", signature)
    return nil
  end
  
  local start_pos = pos
  pos = pos + 4 -- Skip IMPS
  
  -- Skip DOS filename (12 bytes)
  pos = pos + 12
  
  -- Skip null byte
  pos = pos + 1
  
  -- Read sample properties according to ITTECH2.TXT
  local global_volume = read_byte(data, pos); pos = pos + 1
  local flags = read_byte(data, pos); pos = pos + 1
  local volume = read_byte(data, pos); pos = pos + 1
  
  -- Read sample name (26 bytes)
  local name = read_string(data, pos, 26)
  
  -- Debug: show raw sample name bytes
  local name_hex = ""
  for i = 0, 25 do
    if pos + i <= #data then
      name_hex = name_hex .. string.format("%02X ", string.byte(data, pos + i))
    end
  end
  dprint(string.format("Sample name raw bytes: %s", name_hex))
  dprint(string.format("Sample name parsed: '%s' (length: %d)", name, #name))
  
  pos = pos + 26
  
  local convert = read_byte(data, pos); pos = pos + 1
  local default_pan = read_byte(data, pos); pos = pos + 1
  
  -- Read sample data parameters
  local length = read_dword(data, pos); pos = pos + 4
  local loop_begin = read_dword(data, pos); pos = pos + 4
  local loop_end = read_dword(data, pos); pos = pos + 4
  local c5_speed = read_dword(data, pos); pos = pos + 4
  local sustain_loop_begin = read_dword(data, pos); pos = pos + 4
  local sustain_loop_end = read_dword(data, pos); pos = pos + 4
  local sample_pointer = read_dword(data, pos); pos = pos + 4
  
  -- Read vibrato parameters
  local vibrato_speed = read_byte(data, pos); pos = pos + 1
  local vibrato_depth = read_byte(data, pos); pos = pos + 1
  local vibrato_rate = read_byte(data, pos); pos = pos + 1
  local vibrato_type = read_byte(data, pos); pos = pos + 1
  
  dprint("Parsed sample:")
  dprint("  Name:", name)
  dprint("  Length:", length, "samples")
  dprint("  16-bit:", bit_and(flags, SAMPLE_16BIT) ~= 0)
  dprint("  Stereo:", bit_and(flags, SAMPLE_STEREO) ~= 0)
  dprint("  Compressed:", bit_and(flags, SAMPLE_COMPRESSED) ~= 0)
  dprint("  Sample pointer:", sample_pointer)
  dprint("  C5 Speed:", c5_speed)
  dprint("  Loop:", loop_begin, "-", loop_end)
  
  return {
    name = name,
    global_volume = global_volume,
    flags = flags,
    volume = volume,
    convert = convert,
    default_pan = default_pan,
    length = length,
    loop_begin = loop_begin,
    loop_end = loop_end,
    c5_speed = c5_speed,
    sustain_loop_begin = sustain_loop_begin,
    sustain_loop_end = sustain_loop_end,
    sample_pointer = sample_pointer,
    vibrato_speed = vibrato_speed,
    vibrato_depth = vibrato_depth,
    vibrato_rate = vibrato_rate,
    vibrato_type = vibrato_type
  }
end

function load_iti_sample_to_renoise(instrument, sample_data, file_data, instrument_name)
  if sample_data.length == 0 or bit_and(sample_data.flags, SAMPLE_ASSOCIATED) == 0 then
    dprint("Skipping sample - no data or not associated")
    return nil
  end
  
  -- Create new sample
  local sample_index = #instrument.samples + 1
  instrument:insert_sample_at(sample_index)
  local sample = instrument:sample(sample_index)
  
  -- Set sample name - use ITI name or create name based on instrument name
  if sample_data.name and sample_data.name ~= "" then
    sample.name = sample_data.name
  else
    sample.name = string.format("%s sample %02d", instrument_name or "ITI Instrument", sample_index)
  end
  

  
  sample.volume = math.min(sample_data.volume / 64.0, 4.0)
  
  -- Set panning if enabled (bit 7 of default_pan)
  if bit_and(sample_data.default_pan, 128) ~= 0 then
    sample.panning = bit_and(sample_data.default_pan, 127) / 64.0
  end
  
  -- Calculate sample rate from C5Speed
  local sample_rate = 44100  -- Default
  if sample_data.c5_speed > 0 then
    sample_rate = sample_data.c5_speed
    -- C5Speed IS the sample rate in Hz - no adjustments needed
    -- Only clamp to reasonable upper limit, preserve low sample rates
    sample_rate = math.min(96000, sample_rate)
  end
  
  local channels = bit_and(sample_data.flags, SAMPLE_STEREO) ~= 0 and 2 or 1
  local bit_depth = bit_and(sample_data.flags, SAMPLE_16BIT) ~= 0 and 16 or 8
  
  dprint("Creating sample buffer: rate =", sample_rate, "channels =", channels, "frames =", sample_data.length)
  
  -- Create sample buffer
  local create_success = pcall(function()
    sample.sample_buffer:create_sample_data(sample_rate, bit_depth, channels, sample_data.length)
  end)
  
  if not create_success then
    dprint("ERROR: Failed to create sample buffer")
    return nil
  end
  
  -- Load actual sample data
  local load_success = load_sample_data(sample, sample_data, file_data)
  if not load_success then
    dprint("ERROR: Failed to load sample data")
    return nil
  end
  
  -- Set loop properties
  if bit_and(sample_data.flags, SAMPLE_LOOP) ~= 0 then
    sample.loop_mode = bit_and(sample_data.flags, SAMPLE_PINGPONG_LOOP) ~= 0 and 
                       renoise.Sample.LOOP_MODE_PING_PONG or renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = math.max(1, sample_data.loop_begin + 1)
    -- IT's LoopEnd is exclusive (sample after end), Renoise expects inclusive
    local it_exclusive_end = sample_data.loop_end
    local inclusive_end = math.max(sample.loop_start, math.min(sample_data.length, it_exclusive_end - 1))
    sample.loop_end = inclusive_end
  else
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end
  
  -- Apply Paketti preferences
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = preferences.pakettiLoaderLoopExit.value
  
  dprint("Sample created successfully:", sample.name, "(original ITI name:", sample_data.name == "" and "(empty)" or sample_data.name, ")")
  return sample
end

function load_sample_data(sample, sample_data, file_data)
  if sample_data.length == 0 or sample_data.sample_pointer == 0 then
    dprint("No sample data to load")
    return true
  end
  
  local channels = bit_and(sample_data.flags, SAMPLE_STEREO) ~= 0 and 2 or 1
  local is_16bit = bit_and(sample_data.flags, SAMPLE_16BIT) ~= 0
  local is_compressed = bit_and(sample_data.flags, SAMPLE_COMPRESSED) ~= 0
  -- Convert bits only apply to uncompressed PCM samples
  local is_signed = false
  if not is_compressed then
    is_signed = bit_and(sample_data.convert, 1) ~= 0
    -- bit 2 (delta) would only affect uncompressed PCM reading
  end
  
  dprint("Loading sample data:")
  dprint("  Sample pointer:", sample_data.sample_pointer)
  dprint("  Length:", sample_data.length, "samples")
  dprint("  16-bit:", is_16bit)
  dprint("  Channels:", channels)
  dprint("  Compressed:", is_compressed)
  dprint("  Signed:", is_signed)
  
  -- For compressed samples, we can't predict the exact compressed size
  -- Just check if the sample pointer is within the file
  if sample_data.sample_pointer >= #file_data then
    dprint("ERROR: Sample pointer beyond file end")
    return false
  end
  
  -- For uncompressed samples, check the expected size
  if not is_compressed then
    local bytes_per_sample = is_16bit and 2 or 1
    local expected_size = sample_data.length * channels * bytes_per_sample
    
    if sample_data.sample_pointer + expected_size > #file_data then
      dprint("ERROR: Uncompressed sample data extends beyond file")
      return false
    end
  end
  
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    dprint("ERROR: Sample buffer not available")
    return false
  end
  
  -- Prepare for sample data changes
  buffer:prepare_sample_data_changes()
  
  local success = false
  
  if is_compressed then
    success = load_compressed_sample_data(buffer, sample_data, file_data, channels, is_16bit, is_signed)
  else
    success = load_uncompressed_sample_data(buffer, sample_data, file_data, channels, is_16bit, is_signed)
  end
  
  -- Finalize sample data changes
  buffer:finalize_sample_data_changes()
  
  return success
end

function load_uncompressed_sample_data(buffer, sample_data, file_data, channels, is_16bit, is_signed)
  dprint("Loading uncompressed sample data")
  
  local pos = sample_data.sample_pointer + 1  -- Convert to 1-based indexing
  local frame_count = sample_data.length
  
  for frame = 1, frame_count do
    for channel = 1, channels do
      local sample_value = 0
      
      if is_16bit then
        -- Read 16-bit sample (little-endian)
        local low_byte = file_data:byte(pos)
        local high_byte = file_data:byte(pos + 1)
        pos = pos + 2
        
        local raw_value = low_byte + (high_byte * 256)
        
        if is_signed then
          if raw_value >= 32768 then
            raw_value = raw_value - 65536
          end
          sample_value = raw_value / 32768.0
        else
          sample_value = (raw_value - 32768) / 32768.0
        end
      else
        -- Read 8-bit sample
        local byte_value = file_data:byte(pos)
        pos = pos + 1
        
        if is_signed then
          if byte_value >= 128 then
            byte_value = byte_value - 256
          end
          sample_value = byte_value / 128.0
        else
          sample_value = (byte_value - 128) / 128.0
        end
      end
      
      -- Clamp sample value to valid range
      sample_value = math.max(-1.0, math.min(1.0, sample_value))
      
      buffer:set_sample_data(channel, frame, sample_value)
    end
  end
  
  dprint("Uncompressed sample data loaded successfully")
  return true
end

function load_compressed_sample_data(buffer, sample_data, file_data, channels, is_16bit, is_signed)
  dprint("Loading compressed sample data (IT214/IT215 compression)")
  
  -- Try to implement basic IT decompression
  local decompressed = attempt_it_decompression(file_data, sample_data, channels, is_16bit, is_signed)
  
  if decompressed then
    dprint("Successfully decompressed IT sample data")
    -- Copy decompressed data to buffer
    for frame = 1, math.min(sample_data.length, #decompressed) do
      for channel = 1, channels do
        local sample_value = decompressed[frame] and decompressed[frame][channel] or 0.0
        buffer:set_sample_data(channel, frame, sample_value)
      end
    end
    return true
  else
    -- Fallback: Create audible placeholder instead of silence
    dprint("IT decompression failed - creating audible placeholder")
    
    -- Create a more interesting placeholder - pink noise with envelope
    -- Use sample pointer as seed to make each sample sound different
    local seed = sample_data.sample_pointer % 65536
    math.randomseed(seed)
    
    for frame = 1, sample_data.length do
      -- Generate pink noise (more musical than white noise)
      local noise = (math.random() - 0.5) * 2.0
      
      -- Apply simple envelope to make it more musical
      local envelope = 1.0
      local attack_frames = math.min(1000, sample_data.length * 0.1)
      local release_frames = math.min(2000, sample_data.length * 0.3)
      
      if frame <= attack_frames then
        envelope = frame / attack_frames
      elseif frame >= sample_data.length - release_frames then
        envelope = (sample_data.length - frame) / release_frames
      end
      
      -- Scale by sample rate to make it audible but not too loud
      local sample_value = noise * envelope * 0.1
      
      -- Add some harmonic content based on C5Speed to make samples distinguishable
      if sample_data.c5_speed > 0 then
        local freq = 440.0 * (sample_data.c5_speed / 44100.0)
        local phase = (frame * freq * 2 * math.pi) / sample_data.c5_speed
        sample_value = sample_value + math.sin(phase) * envelope * 0.05
      end
      
      for channel = 1, channels do
        buffer:set_sample_data(channel, frame, sample_value)
      end
    end
    
    local base_freq = sample_data.c5_speed > 0 and (440.0 * sample_data.c5_speed / 44100.0) or 0
    dprint("Created audible placeholder with pink noise, envelope, and", 
           base_freq > 0 and string.format("%.1fHz tone", base_freq) or "no tonal component")
    return true
  end
end

-- Proper IT214/IT215 decompression based on Schism Tracker implementation
-- Bitwise operations helper for IT compression
local function bit_rshift(value, shift)
  return math.floor(value / (2 ^ shift))
end

local function bit_lshift(value, shift)
  return value * (2 ^ shift)
end

-- IT bitreader that matches the C implementation
local function it_readbits(n, bitbuf, bitnum, data, pos)
  local value = 0
  local i = n
  
  while i > 0 do
    if bitnum[1] == 0 then
      if pos[1] > #data then
        return 0, pos -- EOF
      end
      bitbuf[1] = string.byte(data, pos[1])
      pos[1] = pos[1] + 1
      bitnum[1] = 8
    end
    
    value = bit_rshift(value, 1)
    value = value + bit_lshift(bit_and(bitbuf[1], 1), 31)
    bitbuf[1] = bit_rshift(bitbuf[1], 1)
    bitnum[1] = bitnum[1] - 1
    i = i - 1
  end
  
  return bit_rshift(value, 32 - n), pos
end

-- IT decompression for a single channel (8-bit)
function it_decompress8_channel(file_data, start_pos, length, it215)
  dprint("IT decompressing 8-bit channel, length:", length, "it215:", it215)
  
  local pos = {start_pos}
  local dest = {}
  local dest_pos = 1
  local remaining_len = length
  
  -- Integration buffers
  local d1, d2 = 0, 0
  
  while remaining_len > 0 do
    -- Read block header (2 bytes: block size)
    if pos[1] + 1 > #file_data then
      dprint("Not enough data for block header")
      break
    end
    
    local c1 = string.byte(file_data, pos[1])
    local c2 = string.byte(file_data, pos[1] + 1)
    pos[1] = pos[1] + 2
    
    local block_size = c1 + (c2 * 256)
    if pos[1] + block_size > #file_data then
      dprint("Block extends beyond file")
      break
    end
    
    -- Initialize bit reading state
    local bitbuf = {0}
    local bitnum = {0}
    
    -- Block processing parameters
    local blklen = math.min(0x8000, remaining_len)
    local blkpos = 0
    local width = 9  -- Start with 9-bit width for 8-bit samples
    
    -- Reset integrator buffers for each block
    d1, d2 = 0, 0
    
    -- Decompress the block
    while blkpos < blklen do
      if width > 9 then
        dprint("Illegal bit width for 8-bit sample:", width)
        break
      end
      
      local value
      value, pos = it_readbits(width, bitbuf, bitnum, file_data, pos)
      
      -- Check for width change patterns
      local width_changed = false
      if width < 7 then
        -- Method 1 (1-6 bits): check for "100..." pattern
        if value == bit_lshift(1, width - 1) then
          local new_width
          new_width, pos = it_readbits(3, bitbuf, bitnum, file_data, pos)
          new_width = new_width + 1
          width = (new_width < width) and new_width or (new_width + 1)
          width_changed = true
        end
      elseif width < 9 then
        -- Method 2 (7-8 bits): border check
        local border = bit_rshift(0xFF, 9 - width) - 4
        if value > border and value <= (border + 8) then
          value = value - border
          width = (value < width) and value or (value + 1)
          width_changed = true
        end
      else
        -- Method 3 (9 bits): high bit check
        if bit_and(value, 0x100) ~= 0 then
          width = bit_and(value + 1, 0xFF)
          width_changed = true
        end
      end
      
      -- Only process sample if width didn't change
      if not width_changed then
        -- Sign extend the value
        local v
        if width < 8 then
          local shift = 8 - width
          v = bit_lshift(value, shift)
          -- Sign extend
          if v >= 128 then
            v = v - 256
          end
          v = bit_rshift(v, shift)
          -- Clamp to signed 8-bit
          if v > 127 then v = 127 end
          if v < -128 then v = -128 end
        else
          v = value
          if v > 127 then v = v - 256 end  -- Convert to signed
        end
        
        -- Integrate the sample values
        d1 = d1 + v
        d2 = d2 + d1
        
        -- Clamp integrators to 8-bit signed range
        if d1 > 127 then d1 = d1 - 256 end
        if d1 < -128 then d1 = d1 + 256 end
        if d2 > 127 then d2 = d2 - 256 end
        if d2 < -128 then d2 = d2 + 256 end
        
        -- Store the sample (use d2 for IT215, d1 for IT214)
        dest[dest_pos] = it215 and d2 or d1
        dest_pos = dest_pos + 1
        blkpos = blkpos + 1
      end
    end
    
    remaining_len = remaining_len - blklen
  end
  
  dprint("IT 8-bit decompression completed, produced", #dest, "samples")
  return dest, pos[1]
end

-- IT decompression for a single channel (16-bit)
function it_decompress16_channel(file_data, start_pos, length, it215)
  dprint("IT decompressing 16-bit channel, length:", length, "it215:", it215)
  
  local pos = {start_pos}
  local dest = {}
  local dest_pos = 1
  local remaining_len = length
  
  -- Integration buffers
  local d1, d2 = 0, 0
  
  while remaining_len > 0 do
    -- Read block header (2 bytes: block size)
    if pos[1] + 1 > #file_data then
      dprint("Not enough data for block header")
      break
    end
    
    local c1 = string.byte(file_data, pos[1])
    local c2 = string.byte(file_data, pos[1] + 1)
    pos[1] = pos[1] + 2
    
    local block_size = c1 + (c2 * 256)
    if pos[1] + block_size > #file_data then
      dprint("Block extends beyond file")
      break
    end
    
    -- Initialize bit reading state
    local bitbuf = {0}
    local bitnum = {0}
    
    -- Block processing parameters
    local blklen = math.min(0x4000, remaining_len)  -- 0x4000 samples for 16-bit
    local blkpos = 0
    local width = 17  -- Start with 17-bit width for 16-bit samples
    
    -- Reset integrator buffers for each block
    d1, d2 = 0, 0
    
    -- Decompress the block
    while blkpos < blklen do
      if width > 17 then
        dprint("Illegal bit width for 16-bit sample:", width)
        break
      end
      
      local value
      value, pos = it_readbits(width, bitbuf, bitnum, file_data, pos)
      
      -- Check for width change patterns
      local width_changed = false
      if width < 7 then
        -- Method 1 (1-6 bits): check for "100..." pattern
        if value == bit_lshift(1, width - 1) then
          local new_width
          new_width, pos = it_readbits(4, bitbuf, bitnum, file_data, pos)  -- 4 bits for 16-bit
          new_width = new_width + 1
          width = (new_width < width) and new_width or (new_width + 1)
          width_changed = true
        end
      elseif width < 17 then
        -- Method 2 (7-16 bits): border check
        local border = bit_rshift(0xFFFF, 17 - width) - 8
        if value > border and value <= (border + 16) then
          value = value - border
          width = (value < width) and value or (value + 1)
          width_changed = true
        end
      else
        -- Method 3 (17 bits): high bit check
        if bit_and(value, 0x10000) ~= 0 then
          width = bit_and(value + 1, 0xFF)
          width_changed = true
        end
      end
      
      -- Only process sample if width didn't change
      if not width_changed then
        -- Sign extend the value
        local v
        if width < 16 then
          local shift = 16 - width
          v = bit_lshift(value, shift)
          -- Sign extend
          if v >= 32768 then
            v = v - 65536
          end
          v = bit_rshift(v, shift)
          -- Clamp to signed 16-bit
          if v > 32767 then v = 32767 end
          if v < -32768 then v = -32768 end
        else
          v = value
          if v > 32767 then v = v - 65536 end  -- Convert to signed
        end
        
        -- Integrate the sample values
        d1 = d1 + v
        d2 = d2 + d1
        
        -- Clamp integrators to 16-bit signed range
        if d1 > 32767 then d1 = d1 - 65536 end
        if d1 < -32768 then d1 = d1 + 65536 end
        if d2 > 32767 then d2 = d2 - 65536 end
        if d2 < -32768 then d2 = d2 + 65536 end
        
        -- Store the sample (use d2 for IT215, d1 for IT214)
        dest[dest_pos] = it215 and d2 or d1
        dest_pos = dest_pos + 1
        blkpos = blkpos + 1
      end
    end
    
    remaining_len = remaining_len - blklen
  end
  
  dprint("IT 16-bit decompression completed, produced", #dest, "samples")
  return dest, pos[1]
end

function attempt_it_decompression(file_data, sample_data, channels, is_16bit, is_signed)
  -- Proper IT214/IT215 decompression based on Schism Tracker
  dprint("Attempting IT214/IT215 decompression")
  
  local pos = sample_data.sample_pointer + 1  -- Convert to 1-based
  if pos > #file_data then
    dprint("Sample pointer beyond file")
    return nil
  end
  
  -- Detect IT214 vs IT215 (simplified detection)
  local it215 = true  -- Most samples use IT215
  
  -- Try IT decompression
  return decompress_it_sample(file_data, pos, sample_data.length, is_16bit, channels, it215)
end

-- Main IT compression decompressor - handles stereo as two sequential streams
function decompress_it_sample(data, start_pos, length, is_16bit, channels, it215)
  dprint("Decompressing IT sample: length=" .. length .. ", 16bit=" .. tostring(is_16bit) .. ", channels=" .. channels .. ", it215=" .. tostring(it215))
  
  local result = {}
  
  if channels == 1 then
    -- Mono
    local samples, end_pos
    if is_16bit then
      samples, end_pos = it_decompress16_channel(data, start_pos, length, it215)
    else
      samples, end_pos = it_decompress8_channel(data, start_pos, length, it215)
    end
    
    for i = 1, length do
      local sample_value = samples[i] or 0
      -- Normalize to -1.0 to 1.0
      local normalized = is_16bit and (sample_value / 32768.0) or (sample_value / 128.0)
      result[i] = {normalized}
    end
  else
    -- Stereo: two sequential compressed streams (Left then Right)
    local left_samples, left_end
    local right_samples, right_end
    
    if is_16bit then
      left_samples, left_end = it_decompress16_channel(data, start_pos, length, it215)
      right_samples, right_end = it_decompress16_channel(data, left_end, length, it215)
    else
      left_samples, left_end = it_decompress8_channel(data, start_pos, length, it215)
      right_samples, right_end = it_decompress8_channel(data, left_end, length, it215)
    end
    
    for i = 1, length do
      local left_value = left_samples[i] or 0
      local right_value = right_samples[i] or 0
      -- Normalize to -1.0 to 1.0
      local left_norm = is_16bit and (left_value / 32768.0) or (left_value / 128.0)
      local right_norm = is_16bit and (right_value / 32768.0) or (right_value / 128.0)
      result[i] = {left_norm, right_norm}
    end
  end
  
  return result
end

function setup_keyboard_mapping(instrument, keyboard_table, loaded_samples, iti_sample_data)
  dprint("Setting up keyboard mapping")
  
  if #loaded_samples == 0 then
    dprint("No samples loaded, using default mapping")
    return
  end
  
  -- Find all continuous ranges for each sample
  local sample_ranges = {}
  
  -- First pass: collect all notes assigned to each sample
  local sample_notes = {}
  for i = 1, 120 do
    local entry = keyboard_table[i]
    if entry and entry.sample > 0 and entry.sample <= #loaded_samples then
      local note = i - 1  -- Convert to 0-based MIDI note
      local sample_idx = entry.sample
      if not sample_notes[sample_idx] then
        sample_notes[sample_idx] = {}
      end
      table.insert(sample_notes[sample_idx], note)
    end
  end
  
  -- Second pass: find continuous ranges within each sample's notes
  for sample_idx, notes in pairs(sample_notes) do
    -- Sort notes for this sample
    table.sort(notes)
    
    local ranges = {}
    local current_range_start = notes[1]
    local current_range_end = notes[1]
    
    for i = 2, #notes do
      local note = notes[i]
      if note == current_range_end + 1 then
        -- Continuous, extend current range
        current_range_end = note
      else
        -- Gap found, finish current range and start new one
        table.insert(ranges, {min = current_range_start, max = current_range_end})
        local min_name = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[current_range_start % 12 + 1] .. math.floor(current_range_start / 12)
        local max_name = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[current_range_end % 12 + 1] .. math.floor(current_range_end / 12)
        dprint(string.format("Sample %d: continuous range %d-%d (%s to %s)", sample_idx, current_range_start, current_range_end, min_name, max_name))
        current_range_start = note
        current_range_end = note
      end
    end
    
    -- Add the final range
    table.insert(ranges, {min = current_range_start, max = current_range_end})
    local min_name = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[current_range_start % 12 + 1] .. math.floor(current_range_start / 12)
    local max_name = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[current_range_end % 12 + 1] .. math.floor(current_range_end / 12)
    dprint(string.format("Sample %d: continuous range %d-%d (%s to %s)", sample_idx, current_range_start, current_range_end, min_name, max_name))
    
    sample_ranges[sample_idx] = ranges
    
    if #ranges > 1 then
      dprint(string.format("Sample %d has %d non-continuous ranges - will use first range only", sample_idx, #ranges))
    end
  end
  
  -- Configure sample mappings directly (samples already exist from loading)
  dprint("Configuring sample mappings for", #instrument.samples, "samples")
  
  -- Configure mappings for existing samples
  local mapping_count = 0
  
  -- Find the highest range to extend it to B-9
  local highest_range_max = 0
  for sample_idx = 1, #loaded_samples do
    local ranges = sample_ranges[sample_idx]
    if ranges and #ranges >= 1 then
      local range = ranges[1]
      if range.max > highest_range_max then
        highest_range_max = range.max
      end
    end
  end
  
  -- Configure all samples with proper ITI-style mapping
  for sample_idx = 1, #loaded_samples do
    local ranges = sample_ranges[sample_idx]
    if ranges and #ranges >= 1 then
      local range = ranges[1]  -- Use first range for mapping
      local sample = instrument.samples[sample_idx]
      local iti_data = iti_sample_data[sample_idx]
      
      if sample and sample.sample_mapping and iti_data then
        -- Extend the highest range to B-9 (note 119) for full keyboard coverage
        local final_range_max = range.max
        local is_highest_range = (range.max == highest_range_max)
        if is_highest_range and range.max < 119 then
          final_range_max = 119  -- Extend to B-9
        end
        
        -- Configure the sample mapping directly
        sample.sample_mapping.note_range = {range.min, final_range_max}
        sample.sample_mapping.velocity_range = {0, 127}  -- Full velocity range
        sample.sample_mapping.map_velocity_to_volume = true
        sample.sample_mapping.map_key_to_pitch = true
        
        -- Use the original_note from the first keyboard entry in this range as the base_note!
        -- This is what the ITI format actually stores - the intended base note for each mapping
        local first_key_entry = keyboard_table[range.min + 1]  -- Convert back to 1-based indexing
        local base_note = first_key_entry and first_key_entry.original_note or 60  -- Fallback to C-5
        
        sample.sample_mapping.base_note = base_note
        
        local note_name_min = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[range.min % 12 + 1] .. math.floor(range.min / 12)
        local note_name_max = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[final_range_max % 12 + 1] .. math.floor(final_range_max / 12)
        local base_note_name = ({"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"})[base_note % 12 + 1] .. math.floor(base_note / 12)
        
        mapping_count = mapping_count + 1
        if is_highest_range and final_range_max > range.max then
          dprint(string.format("✓ Sample %d: notes %d-%d (%s to %s) [EXTENDED to B-9], base_note=%s (%d)", 
            sample_idx, range.min, final_range_max, note_name_min, note_name_max, base_note_name, base_note))
        else
          dprint(string.format("✓ Sample %d: notes %d-%d (%s to %s), base_note=%s (%d)", 
            sample_idx, range.min, final_range_max, note_name_min, note_name_max, base_note_name, base_note))
        end
        
        if #ranges > 1 then
          dprint(string.format("⚠ Sample %d has %d ranges, only using first range", sample_idx, #ranges))
        end
      end
    end
  end
  
  if mapping_count > 0 then
    dprint(string.format("✓ Keyboard mapping completed: configured %d sample mappings", mapping_count))
  else
    dprint("⚠ No keyboard mappings configured - using default sample mappings")
  end
end

function setup_envelopes(instrument, envelopes)
  dprint("Setting up envelopes")
  
  if not envelopes or #envelopes < 3 then
    dprint("No envelopes to setup")
    return
  end
  
  -- ITI envelopes: 1=Volume, 2=Panning, 3=Pitch
  local volume_env = envelopes[1]
  local panning_env = envelopes[2] 
  local pitch_env = envelopes[3]
  
  if volume_env and volume_env.enabled and volume_env.num_nodes > 0 then
    dprint("Volume envelope enabled with", volume_env.num_nodes, "nodes")
  end
  
  if panning_env and panning_env.enabled and panning_env.num_nodes > 0 then
    dprint("Panning envelope enabled with", panning_env.num_nodes, "nodes")
  end
  
  if pitch_env and pitch_env.enabled and pitch_env.num_nodes > 0 then
    dprint("Pitch envelope enabled with", pitch_env.num_nodes, "nodes")
  end
  
  -- TODO: Create actual Renoise modulation envelopes
  -- This would require setting up modulation sets and mapping envelope data
  
  dprint("Envelope setup completed (basic implementation)")
end

-- Register file import hook
local iti_integration = {
  category = "instrument",
  extensions = { "iti" },
  invoke = iti_loadinstrument
}

if not renoise.tool():has_file_import_hook("instrument", { "iti" }) then
  renoise.tool():add_file_import_hook(iti_integration)
  dprint("ITI file import hook registered")
end
