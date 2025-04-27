-- Paketti XM Importer for Renoise v2.1 (Lua 5.1 compliant, optimized bulk sample import)

local renoise = renoise
local rns     = nil
local bit     = require("bit")

-- Debug settings
local DEBUG_SAMPLES = true
local DEBUG_NOTES   = false

local function sample_debug_print(...)
  if DEBUG_SAMPLES then print(...) end
end

local function note_debug_print(...)
  if DEBUG_NOTES then print(...) end
end

-- Binary read helpers
local function read_bytes(f, n)
  if n <= 0 then return "" end
  local pos, total = f:seek(), f:seek("end")
  f:seek("set", pos)
  if pos + n > total then
    sample_debug_print(string.format(
      "Warning: Hit EOF at %d when trying to read %d bytes (total %d)",
      pos, n, total))
    return string.rep("\0", n)
  end
  local data = f:read(n)
  if not data or #data < n then
    sample_debug_print(string.format(
      "Warning: Short read at %d (got %d of %d bytes)",
      pos, data and #data or 0, n))
    data = data or ""
    return data .. string.rep("\0", n - #data)
  end
  return data
end

local function read_byte(f)
  return string.byte(read_bytes(f, 1), 1)
end

local function read_word_le(f)
  local b1, b2 = string.byte(read_bytes(f, 2), 1, 2)
  return b1 + b2 * 256
end

local function read_dword_le(f)
  local b = { string.byte(read_bytes(f, 4), 1, 4) }
  return b[1] + b[2] * 256 + b[3] * 65536 + b[4] * 16777216
end

local function read_string(f, len)
  local data = read_bytes(f, len)
  local chars = {}
  for i = 1, #data do
    local c = data:byte(i)
    if c == 0 then break end
    chars[#chars+1] = string.char(c)
  end
  return table.concat(chars)
end

-- Sample decoders
local function decode_delta_8(raw)
  local out, old = {}, 0
  for i = 1, #raw do
    local d = raw:byte(i)
    if d > 127 then d = d - 256 end
    old = old + d
    if old > 127  then old = old - 256
    elseif old < -128 then old = old + 256 end
    out[i] = old
  end
  return out
end

local function decode_delta_16(raw)
  local out, old, idx = {}, 0, 1
  for i = 1, #raw-1, 2 do
    local lo, hi = raw:byte(i, i+1)
    local d = lo + hi * 256
    if d > 32767 then d = d - 65536 end
    old = old + d
    if old > 32767    then old = old - 65536
    elseif old < -32768 then old = old + 65536 end
    out[idx], idx = old, idx + 1
  end
  return out
end

local function decode_adpcm(raw, length)
  local table_vals = { raw:byte(1, 16) }
  for i = 1, 16 do
    if table_vals[i] > 127 then table_vals[i] = table_vals[i] - 256 end
  end
  local out, old = {}, 0
  local clen = math.floor((length + 1) / 2)
  local j = 1
  for i = 1, clen do
    local byte = raw:byte(16 + i) or 0
    -- low nibble
    local idx = bit.band(byte, 0xF)
    old = old + table_vals[idx + 1]
    if old > 127  then old = old - 256
    elseif old < -128 then old = old + 256 end
    out[j], j = old, j + 1
    -- high nibble
    if j <= length then
      idx = bit.rshift(byte, 4)
      old = old + table_vals[idx + 1]
      if old > 127  then old = old - 256
      elseif old < -128 then old = old + 256 end
      out[j], j = old, j + 1
    end
  end
  return out
end

-- Read a sample header (per XM spec)
local function read_sample_header(f)
  local length     = read_dword_le(f)
  local loop_start = read_dword_le(f)
  local loop_len   = read_dword_le(f)
  local volume     = read_byte(f)
  local finetune   = read_byte(f); if finetune > 127 then finetune = finetune - 256 end
  local type_b     = read_byte(f)
  local panning    = read_byte(f)
  local rel_note   = read_byte(f); if rel_note > 127 then rel_note = rel_note - 256 end
  local comp       = read_byte(f)  -- 0x00 = delta, 0xAD = ADPCM
  local name       = read_string(f, 22)

  local is_16bit = bit.band(type_b, 0x10) ~= 0
  local is_adpcm = (comp == 0xAD)
  local loop_mode = "OFF"
  if loop_len > 0 then
    local lt = bit.band(type_b, 0x3)
    if lt == 1 then loop_mode = "FORWARD"
    elseif lt == 2 then loop_mode = "PING_PONG" end
  end

  return {
    length      = length,
    loop_start  = loop_start,
    loop_len    = loop_len,
    volume      = volume,
    finetune    = finetune,
    type        = type_b,
    panning     = panning,
    rel_note    = rel_note,
    compression = comp,
    is_16bit    = is_16bit,
    is_adpcm    = is_adpcm,
    loop_mode   = loop_mode,
    name        = name,
    data        = nil
  }
end

-- Read one instrument: header, then all its sample headers+data
local function read_instrument(f)
  local start_pos = f:seek()
  local inst_size = read_dword_le(f)
  local header_end = start_pos + 4 + inst_size

  local name       = read_string(f, 22)
  local inst_type  = read_byte(f)
  local num_samples= read_word_le(f)

  local inst = {
    name        = name,
    type        = inst_type,
    num_samples = num_samples,
    samples     = {}
  }

  -- skip to end of instrument header
  f:seek("set", header_end)

  -- then read each sample header and its data
  for i = 1, num_samples do
    local s = read_sample_header(f)
    if s.length > 0 then
      local raw = read_bytes(f, s.length)
      if s.is_adpcm then
        s.data = decode_adpcm(raw, s.length)
      elseif s.is_16bit then
        s.data = decode_delta_16(raw)
      else
        s.data = decode_delta_8(raw)
      end
      sample_debug_print(
        string.format("Loaded sample %d '%s' (%d frames)", i, s.name, #s.data)
      )
    else
      s.data = {}
    end
    inst.samples[i] = s
  end

  return inst
end

-- Note mapping
local notes = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
local function map_xm_note(n)
  if n == 97 then return "OFF" end
  if n < 1 or n > 96 then return "---" end
  local octave = math.floor((n - 1) / 12)
  local idx    = ((n - 1) % 12) + 1
  return notes[idx] .. octave
end

-- Effect mapping stub
local function map_xm_effect(e, p)
  if e == 0 then return nil, nil end
  return string.format("%02X", e), p
end

-- Main import function
local function import_xm_file(filename)
  print(string.rep("=", 80))
  print("Importing XM:", filename)
  rns = renoise.song()

  local f = io.open(filename, "rb")
  if not f then
    renoise.app():show_error("XM Import Error", "Cannot open: " .. filename)
    return false
  end

  local total = f:seek("end")
  f:seek("set", 0)
  print("File size:", total, "bytes")

  -- XM HEADER
  if read_string(f, 17) ~= "Extended Module: " then
    renoise.app():show_error("XM Import Error", "Invalid XM ID text")
    f:close() return false
  end
  local module_name = read_string(f, 20)
  local magic       = read_byte(f)
  local tracker     = read_string(f, 20)
  local ver_min     = read_byte(f)
  local ver_maj     = read_byte(f)
  print(string.format(
    "Module: '%s'  Tracker: '%s'  Version: %d.%02d",
    module_name, tracker, ver_maj, ver_min
  ))

  local header_size     = read_dword_le(f)
  local song_length     = read_word_le(f)
  local restart_pos     = read_word_le(f)
  local num_channels    = read_word_le(f)
  local num_patterns    = read_word_le(f)
  local num_instruments = read_word_le(f)
  local flags           = read_word_le(f)
  local default_tempo   = read_word_le(f)
  local default_bpm     = read_word_le(f)

  -- skip pattern order table
  f:seek("cur", song_length)

  -- jump to first pattern header
  local first_pattern_offset = 60 + header_size
  if first_pattern_offset > total then
    renoise.app():show_error("XM Import Error",
      string.format("Invalid header_size: %d", header_size))
    f:close() return false
  end
  f:seek("set", first_pattern_offset)

  -- READ PATTERNS
  local patterns = {}
  for pi = 1, num_patterns do
    local phl  = read_dword_le(f)
    local pack = read_byte(f)
    local rows = read_word_le(f)
    local psz  = read_word_le(f)
    local data = (psz > 0) and read_bytes(f, psz) or nil
    patterns[pi] = { rows = rows, data = data }
    sample_debug_print(
      string.format("Pattern %d: %d rows, %d bytes", pi, rows, psz or 0)
    )
  end

  -- READ INSTRUMENTS
  local instruments = {}
  for ii = 1, num_instruments do
    sample_debug_print("Reading instrument " .. ii)
    instruments[ii] = read_instrument(f)
  end

  f:close()

  -- IMPORT INTO RENOISE

  -- reset existing instruments
  while #rns.instruments > 1 do
    rns:delete_instrument_at(2)
  end

  -- ensure enough tracks
  local track_count = 0
  for _, t in ipairs(rns.tracks) do
    if t.type == 1 then track_count = track_count + 1 end
  end
  while track_count < num_channels do
    rns:insert_track_at(track_count + 1)
    track_count = track_count + 1
  end

  -- import instruments & samples
  for idx, inst in ipairs(instruments) do
    local ri = (idx == 1) and rns.instruments[1]
             or rns:insert_instrument_at(idx)
    ri.name = inst.name
    while #ri.samples > 0 do
      ri:delete_sample_at(1)
    end

    for sidx, s in ipairs(inst.samples) do
      if s.data and #s.data > 0 then
        local rs = ri:insert_sample_at(sidx)
        rs.name = s.name
        local buf = rs.sample_buffer
        if buf.has_sample_data then buf:delete_sample_data() end
        buf:create_sample_data(8363, s.is_16bit and 16 or 8, 1, #s.data)
        buf:prepare_sample_data_changes()
        for i = 1, #s.data do
          buf:set_sample_data(1, i, s.data[i])
        end
        buf:finalize_sample_data_changes()
        -- loops
        if s.loop_len > 1 then
          rs.loop_mode = (bit.band(s.type, 3) == 2)
                         and renoise.Sample.LOOP_MODE_PING_PONG
                         or renoise.Sample.LOOP_MODE_FORWARD
          rs.loop_start = math.max(1, math.min(s.loop_start+1, #s.data))
          rs.loop_end   = math.max(rs.loop_start,
                             math.min(s.loop_start + s.loop_len, #s.data))
        else
          rs.loop_mode = renoise.Sample.LOOP_MODE_OFF
        end
        rs.volume    = math.min(4, math.max(0, (s.volume/64)*4))
        rs.transpose = s.rel_note - 24
        rs.fine_tune = s.finetune
        rs.panning   = s.panning / 255
      end
    end
  end

  -- import patterns
  for pi, pat in ipairs(patterns) do
    if pi > #rns.patterns then
      rns.sequencer:insert_new_pattern_at(pi)
    end
    local pat_obj = rns.patterns[pi]
    pat_obj.number_of_lines = math.max(1, math.min(512, pat.rows or 1))
    if pat.data then
      local ptr, plen = 1, #pat.data
      for row = 1, pat.rows do
        for tr = 1, num_channels do
          if ptr > plen then break end
          local track = rns.patterns[pi].tracks[tr]
          local line  = track.lines[row]
          local nc    = line.note_columns[1]
          local ec    = line.effect_columns[1]
          local b     = pat.data:byte(ptr); ptr = ptr + 1
          local note, ins, vol, eff, par = 0, 0, 0, 0, 0
          if b >= 128 then
            if b % 2 == 1   then note = pat.data:byte(ptr); ptr = ptr + 1 end
            if b % 4 >= 2   then ins  = pat.data:byte(ptr); ptr = ptr + 1 end
            if b % 8 >= 4   then vol  = pat.data:byte(ptr); ptr = ptr + 1 end
            if b % 16 >= 8  then eff  = pat.data:byte(ptr); ptr = ptr + 1 end
            if b % 32 >= 16 then par  = pat.data:byte(ptr); ptr = ptr + 1 end
          else
            note = b
            ins  = pat.data:byte(ptr); vol = pat.data:byte(ptr+1)
            eff  = pat.data:byte(ptr+2); par = pat.data:byte(ptr+3)
            ptr  = ptr + 4
          end
          nc.note_string      = map_xm_note(note)
          nc.instrument_value = (ins > 0) and (ins - 1) or 255
          if vol > 0 and vol <= 64 then nc.volume_value = vol end
          if eff > 0 then
            ec.number_string = map_xm_effect(eff, par)
            ec.amount_value  = par
          end
        end
      end
    end
  end

  renoise.app():show_status("XM import completed: " .. filename)
  return true
end

-- Menu & hook
renoise.tool():add_menu_entry{name="Song:Import...:XM File",invoke = function() import_xm_file(renoise.app():prompt_for_filename_to_read{ title="Open XM File" }) end}

local xm_hook = {
  category   = "song",
  extensions = {"xm"},
  invoke     = import_xm_file
}
if not renoise.tool():has_file_import_hook(xm_hook.category, xm_hook.extensions) then
  renoise.tool():add_file_import_hook(xm_hook)
end
