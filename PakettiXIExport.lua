-- PakettiXIExport.lua
-- FastTracker II Extended Instrument (.xi) export for Renoise instruments
-- Based on xi.c from Schism Tracker - the authoritative XI implementation

-- Debug function
local function dprint(...)
  print("XI Export:", ...)
end

-- Binary write helper functions
local function write_byte(file, value)
  local clamped_value = math.max(0, math.min(255, math.floor(value or 0)))
  file:write(string.char(clamped_value))
end

local function write_word_le(file, value)
  local val = math.max(0, math.min(65535, math.floor(value or 0)))
  local b1 = val % 256
  local b2 = math.floor(val / 256) % 256
  file:write(string.char(b1, b2))
end

local function write_dword_le(file, value)
  local val = math.max(0, math.min(4294967295, math.floor(value or 0)))
  local b1 = val % 256
  local b2 = math.floor(val / 256) % 256
  local b3 = math.floor(val / 65536) % 256
  local b4 = math.floor(val / 16777216) % 256
  file:write(string.char(b1, b2, b3, b4))
end

local function write_string_fixed(file, str, length)
  local padded = (str or ""):sub(1, length)
  while #padded < length do
    padded = padded .. string.char(0)
  end
  file:write(padded)
end

-- Signed 16-bit little-endian writer for FT2-style delta data (Lua 5.1 compatible)
local function write_signed_word_le(file, val)
  -- Convert to unsigned 16-bit representation (Lua 5.1 compatible)
  local s = val % 65536  -- Equivalent to val & 0xFFFF
  if val < 0 then
    s = 65536 + val  -- Handle negative values
  end
  
  -- Split into low and high bytes (Lua 5.1 compatible)
  local low_byte = s % 256  -- Equivalent to s & 0xFF
  local high_byte = math.floor(s / 256) % 256  -- Equivalent to (s >> 8) & 0xFF
  
  file:write(string.char(low_byte, high_byte))
end

-- XI format constants (from xi.c)
local XI_ENV_ENABLED = 0x01
local XI_ENV_SUSTAIN = 0x02
local XI_ENV_LOOP = 0x04

-- Convert Renoise sample to FT2-style delta-compressed 16-bit PCM
local function convert_sample_data(sample)
  dprint("Converting sample: " .. (sample.name or "Unnamed"))

  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    dprint("  No sample data!")
    return {}
  end

  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  local is_stereo = (num_channels == 2)
  local delta_data = {}

  dprint("  Frames: " .. num_frames .. ", Channels: " .. num_channels)

  -- Helper to convert float [-1.0, 1.0] to signed 16-bit
  local function float_to_int16(val)
    local s = math.floor(val * 32767 + 0.5)
    return math.max(-32768, math.min(32767, s))
  end

  -- Mono: delta encode directly
  if not is_stereo then
    local prev = 0
    for i = 1, num_frames do
      local s = float_to_int16(buffer:sample_data(1, i))
      local delta = s - prev
      table.insert(delta_data, delta)
      prev = s
      
      -- Debug first few values
      if i <= 3 then
        dprint("    Frame " .. i .. ": sample=" .. s .. " -> delta=" .. delta)
      end
    end
    dprint("  Converted mono sample: " .. #delta_data .. " delta values")
    return delta_data
  end

  -- Stereo: process Left then Right as separate blocks (FT2-style)
  local left_block = {}
  local right_block = {}

  -- Left channel delta block
  do
    local prev = 0
    for i = 1, num_frames do
      local s = float_to_int16(buffer:sample_data(1, i))
      local delta = s - prev
      table.insert(left_block, delta)
      prev = s
    end
  end

  -- Right channel delta block
  do
    local prev = 0
    for i = 1, num_frames do
      local s = float_to_int16(buffer:sample_data(2, i))
      local delta = s - prev
      table.insert(right_block, delta)
      prev = s
    end
  end

  -- Concatenate blocks: [L0, L1, ..., Ln, R0, R1, ..., Rn]
  for _, d in ipairs(left_block) do table.insert(delta_data, d) end
  for _, d in ipairs(right_block) do table.insert(delta_data, d) end

  dprint("  Converted stereo sample: " .. #delta_data .. " delta values (L+R)")
  return delta_data
end

-- Create sample mapping - export ALL samples in instrument
local function create_sample_mapping(instrument)
  local xi_invmap = {}
  local xi_nalloc = #instrument.samples  -- Export ALL samples
  
  -- Create direct mapping - sample 1 = index 0, sample 2 = index 1, etc.
  for i = 1, xi_nalloc do
    xi_invmap[i-1] = i  -- 0-based mapping for XI, 1-based for Renoise
  end
  
  local snum = {}
  
  -- Create note-to-sample mapping for the 96 notes
  for note = 1, 96 do
    local renoise_note = note + 11  -- XI note 1 = Renoise note C-1 (12)
    local sample_idx = 1  -- Default to first sample
    
    -- Find which sample is mapped to this note
    if instrument.sample_mappings then
      for idx, mapping in ipairs(instrument.sample_mappings) do
        if mapping.note_range and 
           renoise_note >= mapping.note_range[1] and 
           renoise_note <= mapping.note_range[2] then
          sample_idx = idx
          break
        end
      end
    end
    
    -- Clamp sample index and convert to 0-based
    if sample_idx > #instrument.samples then
      sample_idx = #instrument.samples
    end
    if sample_idx < 1 then
      sample_idx = 1
    end
    
    snum[note] = sample_idx - 1  -- Convert to 0-based for XI format
  end
  
  dprint("Exporting ALL " .. xi_nalloc .. " samples in instrument")
  return snum, xi_invmap, xi_nalloc
end

-- Get envelope data from instrument - extract REAL envelope data
local function get_envelope_data(instrument, is_volume)
  local target_type = is_volume and 1 or 2  -- 1=Volume, 2=Panning
  local envelope_name = is_volume and "VOLUME" or "PANNING"
  
  dprint("=== EXTRACTING " .. envelope_name .. " ENVELOPE DATA ===")
  
  local envelope = {
    enabled = false,
    points = {},
    num_points = 2,
    sustain_point = 0,
    loop_start = 0,
    loop_end = 0,
    type_flags = 0
  }
  
  -- Search through all modulation sets and devices
  dprint("Instrument has " .. #instrument.sample_modulation_sets .. " modulation sets")
  
  for set_index, modulation_set in ipairs(instrument.sample_modulation_sets) do
    dprint("  Checking modulation set " .. set_index .. " with " .. #modulation_set.devices .. " devices")
    
    for device_index, device in ipairs(modulation_set.devices) do
      dprint("    Device " .. device_index .. ":")
      dprint("      name: " .. tostring(device.name))
      dprint("      enabled: " .. tostring(device.enabled))
      if device.target then
        dprint("      target: " .. tostring(device.target))
      end
      
      -- Check if this is a SampleEnvelopeModulationDevice with the right target
      if device.name == "Envelope" and device.target == target_type and device.enabled then
        dprint("    *** FOUND ACTIVE " .. envelope_name .. " ENVELOPE! ***")
        
        -- Check if device has envelope properties (SampleEnvelopeModulationDevice)
        if device.points and device.sustain_enabled ~= nil and device.loop_mode ~= nil then
          dprint("    Device has " .. #device.points .. " envelope points:")
          
          envelope.enabled = true
          envelope.points = {}
          
          -- Extract all envelope points
          for i, point in ipairs(device.points) do
            local xi_val = math.floor(point.value * 64 + 0.5)  -- Convert 0.0-1.0 to 0-64
            table.insert(envelope.points, {
              ticks = point.time,
              val = xi_val
            })
            dprint("      Point " .. i .. ": time=" .. point.time .. ", value=" .. point.value .. " -> XI val=" .. xi_val)
          end
          
          envelope.num_points = math.min(#envelope.points, 12)  -- XI max is 12 points
          
          -- Extract sustain settings
          envelope.sustain_point = device.sustain_position or 0
          dprint("    Sustain enabled: " .. tostring(device.sustain_enabled))
          dprint("    Sustain position: " .. envelope.sustain_point)
          
          -- Extract loop settings  
          envelope.loop_start = device.loop_start or 0
          envelope.loop_end = device.loop_end or 0
          dprint("    Loop mode: " .. tostring(device.loop_mode))
          dprint("    Loop start: " .. envelope.loop_start)
          dprint("    Loop end: " .. envelope.loop_end)
          
          -- Set type flags (XI format)
          envelope.type_flags = 0
          if device.enabled then 
            envelope.type_flags = envelope.type_flags + XI_ENV_ENABLED 
          end
          if device.sustain_enabled then 
            envelope.type_flags = envelope.type_flags + XI_ENV_SUSTAIN 
          end
          if device.loop_mode and device.loop_mode ~= renoise.SampleEnvelopeModulationDevice.LOOP_MODE_OFF then 
            envelope.type_flags = envelope.type_flags + XI_ENV_LOOP 
          end
          
          -- Extract fade amount for volume envelopes
          if is_volume and device.fade_amount then
            dprint("    Fade amount: " .. device.fade_amount)
          end
          
          dprint("    Final type flags: " .. envelope.type_flags)
          dprint("    Successfully extracted " .. envelope.num_points .. " points for " .. envelope_name .. " envelope")
          
          return envelope
        else
          dprint("    Device missing envelope properties (not SampleEnvelopeModulationDevice)")
        end
      else
        if device.name == "Envelope" then
          if device.target ~= target_type then
            dprint("    Envelope device but wrong target (target=" .. tostring(device.target) .. ", need " .. target_type .. ")")
          end
          if not device.enabled then
            dprint("    Envelope device but disabled")
          end
        end
      end
    end
  end
  
  dprint("  No " .. envelope_name .. " envelope found - using defaults")
  
  -- Create default envelope points if no envelope found
  if is_volume then
    envelope.points = {{ticks = 0, val = 64}, {ticks = 100, val = 64}}
  else
    envelope.points = {{ticks = 0, val = 32}, {ticks = 100, val = 32}}
  end
  
  dprint("  Default " .. envelope_name .. " envelope: " .. #envelope.points .. " points")
  for i, point in ipairs(envelope.points) do
    dprint("    Default point " .. i .. ": ticks=" .. point.ticks .. ", val=" .. point.val)
  end
  
  return envelope
end

-- Export XI file following xi.c exactly
function PakettiXIExport()
  if not renoise.song() then
    renoise.app():show_status("No song loaded")
    return
  end
  
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  if not instrument.samples or #instrument.samples == 0 then
    renoise.app():show_status("Selected instrument has no samples")
    return
  end
  
  -- Get filename
  local filename = renoise.app():prompt_for_filename_to_write("xi", "Export XI file")
  if not filename then
    return
  end
  
  if not filename:match("%.xi$") then
    filename = filename .. ".xi"
  end
  
  local file = io.open(filename, "wb")
  if not file then
    renoise.app():show_error("Cannot create file: " .. filename)
    return
  end
  
  dprint("Exporting: " .. filename)
  dprint("=== EXPORT SCOPE CLARIFICATION ===")
  dprint("EXPORTING: ENTIRE INSTRUMENT (not just selected sample)")
  dprint("Instrument name: '" .. (instrument.name or "[Unnamed]") .. "'")
  dprint("Total samples in instrument: " .. #instrument.samples)
  
  -- Create sample mapping (following xi.c)
  local snum, xi_invmap, xi_nalloc = create_sample_mapping(instrument)
  
  if xi_nalloc < 1 then
    file:close()
    renoise.app():show_error("No samples to export")
    return
  end
  
  -- Get envelope data
  local vol_env = get_envelope_data(instrument, true)
  local pan_env = get_envelope_data(instrument, false)
  
  dprint("=== ENVELOPE DATA ===")
  dprint("Volume envelope: " .. #vol_env.points .. " points")
  for i, point in ipairs(vol_env.points) do
    dprint("  Vol point " .. i .. ": ticks=" .. point.ticks .. ", val=" .. point.val)
  end
  dprint("Panning envelope: " .. #pan_env.points .. " points")
  for i, point in ipairs(pan_env.points) do
    dprint("  Pan point " .. i .. ": ticks=" .. point.ticks .. ", val=" .. point.val)
  end
  dprint("Vol flags=" .. vol_env.type_flags .. ", Pan flags=" .. pan_env.type_flags)
  
  -- Write XI file header (following xi.c struct xi_file_header)
  write_string_fixed(file, "Extended Instrument: ", 0x15)  -- header[0x15]
  write_string_fixed(file, instrument.name or "Untitled", 0x16)  -- name[0x16]
  write_byte(file, 0x1A)  -- magic
  write_string_fixed(file, "Paketti         ", 0x14)  -- tracker[0x14]
  write_word_le(file, 0x0102)  -- version (little-endian, xi.c uses bswapLE16)
  
  -- Write sample number mapping (snum[96])
  for i = 1, 96 do
    write_byte(file, snum[i])
  end
  
  -- Write volume envelope points (venv[12])
  dprint("Writing volume envelope points to XI:")
  for i = 1, 12 do
    if i <= #vol_env.points then
      local ticks = vol_env.points[i].ticks
      local val = vol_env.points[i].val
      write_word_le(file, ticks)
      write_word_le(file, val)
      dprint("  XI vol point " .. i .. ": ticks=" .. ticks .. ", val=" .. val)
    else
      write_word_le(file, 0)
      write_word_le(file, 0)
    end
  end
  
  -- Write panning envelope points (penv[12])
  dprint("Writing panning envelope points to XI:")
  for i = 1, 12 do
    if i <= #pan_env.points then
      local ticks = pan_env.points[i].ticks
      local val = pan_env.points[i].val
      write_word_le(file, ticks)
      write_word_le(file, val)
      dprint("  XI pan point " .. i .. ": ticks=" .. ticks .. ", val=" .. val)
    else
      write_word_le(file, 0)
      write_word_le(file, 0)
    end
  end
  
  -- Write envelope info
  dprint("Writing envelope info:")
  dprint("  vnum=" .. vol_env.num_points .. ", pnum=" .. pan_env.num_points)
  dprint("  vsustain=" .. vol_env.sustain_point .. ", vloop=" .. vol_env.loop_start .. "-" .. vol_env.loop_end)
  dprint("  psustain=" .. pan_env.sustain_point .. ", ploop=" .. pan_env.loop_start .. "-" .. pan_env.loop_end)
  dprint("  vtype=" .. vol_env.type_flags .. ", ptype=" .. pan_env.type_flags)
  
  write_byte(file, vol_env.num_points)  -- vnum
  write_byte(file, pan_env.num_points)  -- pnum
  write_byte(file, vol_env.sustain_point)  -- vsustain
  write_byte(file, vol_env.loop_start)  -- vloops
  write_byte(file, vol_env.loop_end)  -- vloope
  write_byte(file, pan_env.sustain_point)  -- psustain
  write_byte(file, pan_env.loop_start)  -- ploops
  write_byte(file, pan_env.loop_end)  -- ploope
  write_byte(file, vol_env.type_flags)  -- vtype
  write_byte(file, pan_env.type_flags)  -- ptype
  
  -- Write vibrato info (extract from instrument properties)
  local vibrato_type = 0
  local vibrato_sweep = 0
  local vibrato_depth = 0
  local vibrato_rate = 0
  
  -- Try to extract vibrato from instrument (Renoise doesn't have direct vibrato properties in XI format)
  -- For now, use safe defaults but could be enhanced to extract from LFO devices
  write_byte(file, vibrato_type)  -- vibtype (0=sine, 1=square, 2=saw, 3=random)
  write_byte(file, vibrato_sweep)  -- vibsweep (0-255)
  write_byte(file, vibrato_depth)  -- vibdepth (0-15)
  write_byte(file, vibrato_rate)  -- vibrate (0-63)
  
  -- Write volume fadeout (extract from volume envelope fade amount if available)
  local volume_fadeout = 0
  -- Try to get fadeout from volume envelope
  if vol_env.enabled and instrument.sample_modulation_sets then
    for _, modulation_set in ipairs(instrument.sample_modulation_sets) do
      for _, device in ipairs(modulation_set.devices) do
        if device.name == "Envelope" and device.target == 1 and device.enabled and device.fade_amount then
          -- Convert Renoise fade amount to XI format (0-4095, where 4095 = no fade)
          volume_fadeout = math.floor((1.0 - device.fade_amount) * 4095)
          volume_fadeout = math.max(0, math.min(4095, volume_fadeout))
          dprint("Extracted volume fadeout: " .. device.fade_amount .. " -> " .. volume_fadeout)
          break
        end
      end
      if volume_fadeout > 0 then break end
    end
  end
  dprint("Writing volume fadeout: " .. volume_fadeout)
  write_word_le(file, volume_fadeout)  -- volfade (0-4095, higher = faster fade)
  
  -- Write reserved bytes (reserved1[0x16])
  for i = 1, 0x16 do
    write_byte(file, 0)
  end
  
  -- Write number of samples
  write_word_le(file, xi_nalloc)  -- nsamples
  
  -- Collect sample data
  local sample_data_list = {}
  
  -- Write sample headers (following struct xm_sample_header exactly)
  for k = 0, xi_nalloc - 1 do
    local sample_idx = xi_invmap[k]
    local sample = instrument.samples[sample_idx]
    
    if not sample then
      dprint("Error: Sample " .. sample_idx .. " not found")
      break
    end
    
    local buffer = sample.sample_buffer
    local sample_length = buffer and buffer.number_of_frames or 0
    local num_channels = buffer and buffer.number_of_channels or 1
    local is_16bit = true  -- Always export as 16-bit
    local is_stereo = (num_channels > 1)
    
    -- === ANALYZE AND DEBUG SAMPLE INFO IN DETAIL ===
    dprint("=== SAMPLE " .. k .. " ANALYSIS ===")
    dprint("  Sample index: " .. sample_idx .. " (0-based: " .. k .. ")")
    dprint("  Sample name: '" .. (sample.name or "[Unnamed]") .. "'")
    
    -- Check if sample has data
    if not buffer then
      dprint("  ERROR: Sample has no buffer!")
    elseif not buffer.has_sample_data then
      dprint("  WARNING: Sample buffer exists but has no audio data!")
    else
      dprint("  Sample has audio data")
      dprint("  Sample frames: " .. buffer.number_of_frames)
      dprint("  Sample rate: " .. buffer.sample_rate .. " Hz")
      dprint("  Channels: " .. buffer.number_of_channels)
      dprint("  Bit depth: " .. buffer.bit_depth .. " bit")
    end
    
    -- Analyze loop settings in detail
    local loop_start = 0
    local loop_length = 0
    local sample_type = 0
    
    local loop_mode = sample.loop_mode
    dprint("  Loop mode enum: " .. tostring(loop_mode))
    
    if loop_mode == renoise.Sample.LOOP_MODE_FORWARD then
      sample_type = sample_type + 1
      dprint("  Loop mode: FORWARD")
    elseif loop_mode == renoise.Sample.LOOP_MODE_REVERSE then
      sample_type = sample_type + 2
      dprint("  Loop mode: REVERSE")
    elseif loop_mode == renoise.Sample.LOOP_MODE_PING_PONG then
      sample_type = sample_type + 3
      dprint("  Loop mode: PING-PONG")
    else
      dprint("  Loop mode: OFF")
    end
    
    if loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
      local loop_start_frame = sample.loop_start or 1
      local loop_end_frame = sample.loop_end or (buffer and buffer.number_of_frames or 0)
      loop_start = (loop_start_frame - 1) * num_channels * 2  -- Convert to byte offset
      loop_length = ((loop_end_frame - loop_start_frame) + 1) * num_channels * 2
      
      dprint("  Loop start frame: " .. loop_start_frame)
      dprint("  Loop end frame: " .. loop_end_frame)
      dprint("  Loop length frames: " .. ((loop_end_frame - loop_start_frame) + 1))
      dprint("  Loop start bytes: " .. loop_start)
      dprint("  Loop length bytes: " .. loop_length)
    else
      dprint("  No loop - start: 0, length: 0")
    end
    
    -- Show other sample properties
    dprint("  Volume: " .. (sample.volume or 1.0))
    dprint("  Panning: " .. (sample.panning or 0.5))
    dprint("  Transpose: " .. (sample.transpose or 0))
    dprint("  Fine tune: " .. (sample.fine_tune or 0))
    
    -- Convert and store sample data first to get accurate length
    dprint("  Converting sample data...")
    local delta_data
    
    if not buffer or not buffer.has_sample_data then
      dprint("  SKIPPING sample conversion - no audio data!")
      -- Create empty delta data for samples with no audio
      delta_data = {}
      sample_length = 0
    else
      dprint("  PROCEEDING with sample conversion...")
      delta_data = convert_sample_data(sample)
      sample_length = #delta_data * 2  -- 2 bytes per 16-bit sample
      dprint("  Converted " .. #delta_data .. " delta values, " .. sample_length .. " bytes")
    end
    
    -- Set sample type flags
    if is_16bit then
      sample_type = sample_type + 0x10
    end
    
    if is_stereo then
      sample_type = sample_type + 0x20
    end
    
    dprint("  Final sample type flags: " .. sample_type)
    
    -- Get sample name and ensure it fits (NO LENGTH BYTE!)
    local sample_name = sample.name or ""
    if #sample_name > 22 then
      sample_name = sample_name:sub(1, 22)
    end
    
    -- Show final header values before writing
    dprint("  === FINAL HEADER VALUES ===")
    dprint("  Sample length (bytes): " .. sample_length)
    dprint("  Loop start (bytes): " .. loop_start)
    dprint("  Loop length (bytes): " .. loop_length)
    dprint("  Volume (0-64): " .. math.floor((sample.volume or 1.0) * 64))
    dprint("  Fine tune: " .. (sample.fine_tune or 0))
    dprint("  Sample type: " .. sample_type)
    dprint("  Panning (0-255): " .. math.floor((sample.panning or 0.5) * 255))
    dprint("  Transpose: " .. (sample.transpose or 0))
    dprint("  Sample name: '" .. sample_name .. "' (length: " .. #sample_name .. ")")
    
    -- Write sample header (exactly 40 bytes, no sample name length!)
    write_dword_le(file, sample_length)  -- samplen (4 bytes)
    write_dword_le(file, loop_start)  -- loopstart (4 bytes)
    write_dword_le(file, loop_length)  -- looplen (4 bytes)
    write_byte(file, math.floor((sample.volume or 1.0) * 64))  -- vol (1 byte, 0-64)
    write_byte(file, sample.fine_tune or 0)  -- finetune (1 byte, signed)
    write_byte(file, sample_type)  -- type (1 byte)
    write_byte(file, math.floor((sample.panning or 0.5) * 255))  -- pan (1 byte, 0-255)
    write_byte(file, sample.transpose or 0)  -- relnote (1 byte, signed)
    write_byte(file, 0)  -- reserved byte (1 byte) - NO SAMPLE NAME LENGTH!
    write_string_fixed(file, sample_name, 22)  -- name[22] (22 bytes, zero-padded)
    
    -- Store the delta data (already converted above)
    table.insert(sample_data_list, delta_data)
    
    dprint("Sample " .. k .. " header written: " .. sample_length .. " bytes, type=" .. sample_type)
    dprint("=== END SAMPLE " .. k .. " ANALYSIS ===\n")
  end
  
  -- Write sample data (FT2-style delta encoding)
  dprint("=== WRITING SAMPLE DATA ===")
  local total_bytes_written = 0
  
  for k, delta_data in ipairs(sample_data_list) do
    local sample_bytes = #delta_data * 2  -- 2 bytes per 16-bit sample
    total_bytes_written = total_bytes_written + sample_bytes
    dprint("Writing sample data " .. (k-1) .. ": " .. #delta_data .. " values (" .. sample_bytes .. " bytes)")
    
    if #delta_data == 0 then
      dprint("  WARNING: Sample " .. (k-1) .. " has no data!")
    end
    
    for i, delta_value in ipairs(delta_data) do
      -- Write as signed 16-bit little-endian (FT2-style delta encoding)
      write_signed_word_le(file, delta_value)
      
      -- Debug first few values
      if i <= 3 then
        dprint("    Value " .. i .. ": delta=" .. delta_value)
      end
    end
  end
  
  dprint("Total sample data written: " .. total_bytes_written .. " bytes")
  
  file:close()
  
  local file_size = io.open(filename, "rb"):seek("end")
  io.close()
  
  renoise.app():show_status("XI export complete: " .. filename .. " (" .. file_size .. " bytes)")
  dprint("Export complete: " .. #instrument.samples .. " samples, " .. xi_nalloc .. " used")
  dprint("=== FT2-COMPATIBLE EXPORT FIXES APPLIED ===")
  dprint("No sample name length byte (removed)")
  dprint("FT2-style delta encoding (corrected)")
  dprint("Stereo L+R block layout (not interleaved)")
  dprint("Signed 16-bit little-endian sample data")
  dprint("Standard 40-byte sample headers")
end

-- Add menu entries
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Export XI (FastTracker II Extended Instrument)",invoke=function() PakettiXIExport() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Export XI (FastTracker II Extended Instrument)", invoke=function() PakettiXIExport() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti Export:Export XI (FastTracker II Extended Instrument)", invoke=function() PakettiXIExport() end}
renoise.tool():add_keybinding{name="Global:Paketti:Export XI (FastTracker II Extended Instrument)",invoke=function() PakettiXIExport() end}
