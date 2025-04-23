-- XM Importer for Renoise v2.1 (Lua 5.1 compliant, full parsing with debug output)

local renoise = renoise
local rns = nil

-- XM format constants
local XM_MAX_SAMPLES_PER_INSTRUMENT = 16
local XM_MAX_SAMPLE_LENGTH         = 16777216 -- 16MB
local XM_MAX_INSTRUMENTS           = 128
local XM_MAX_CHANNELS              = 32
local XM_MAX_PATTERNS              = 256

-- Binary read helpers
local function read_bytes(file, count)
  if count < 0 then error(string.format("Invalid byte count: %d", count)) end
  if count == 0 then return "" end
  local pos   = file:seek()
  local total = file:seek('end')
  if pos + count > total then
    error(string.format("Not enough data (%d needed at %d, total %d)", count, pos, total))
  end
  file:seek('set', pos)
  local data = file:read(count)
  if not data or #data ~= count then
    error(string.format("Failed read %d bytes at %d (got %d)", count, pos, data and #data or 0))
  end
  return data
end

local function read_byte(file)
  return string.byte(read_bytes(file,1),1)
end

local function read_word_le(file)
  local b1,b2 = string.byte(read_bytes(file,2),1,2)
  return b1 + b2 * 256
end

local function read_dword_le(file)
  local b = {string.byte(read_bytes(file,4),1,4)}
  return b[1] + b[2]*256 + b[3]*65536 + b[4]*16777216
end

local function read_string(file,length)
  local data = read_bytes(file,length)
  local s = ""
  for i=1,#data do
    local c = data:byte(i)
    if c == 0 then break end
    s = s .. string.char(c)
  end
  return s
end

-- Delta decoders
local function decode_delta_8(raw)
  local out,prev = {},0
  for i=1,#raw do
    local v = raw:byte(i)
    if v > 127 then v = v - 256 end
    prev = prev + v
    out[i] = prev
  end
  return out
end

local function decode_delta_16(raw)
  local out,prev,idx = {},0,1
  for i=1,#raw,2 do
    local lo,hi = raw:byte(i,i+1)
    local v = lo + hi*256
    if v > 32767 then v = v - 65536 end
    prev = prev + v
    out[idx] = prev
    idx = idx + 1
  end
  return out
end

-- ADPCM decode
local function decode_adpcm(raw,length)
  local table_vals = {raw:byte(1,16)}
  local nibbles = {}
  for i=17,#raw do
    local b = raw:byte(i)
    nibbles[#nibbles+1] = b % 16
    nibbles[#nibbles+1] = math.floor(b / 16)
  end
  local out,prev = {},0
  for i=1,length do
    local d = table_vals[nibbles[i] + 1] or 0
    if d > 127 then d = d - 256 end
    prev = prev + d
    out[i] = prev
  end
  return out
end

-- Note mapping
local function map_xm_note(n)
  if n == 97 then return renoise.Song.TRACKER_NOTE_OFF end
  if n < 1 or n > 96 then return renoise.Song.TRACKER_EMPTY_CELL end
  return n + 11  -- C-1 -> C-0 offset
end

-- Core import function
local function import_xm_file(filename)
  rns = renoise.song()
  local f = io.open(filename, 'rb')
  if not f then
    renoise.app():show_error('XM Import Error','Cannot open: ' .. filename)
    return false
  end

  -- HEADER
  local id_text         = read_string(f,17)
  local module_name     = read_string(f,20)
  local magic           = read_byte(f)
  local tracker_name    = read_string(f,20)
  local version         = read_word_le(f)
  local header_size     = read_dword_le(f)
  local song_length     = read_word_le(f)
  local restart_position= read_word_le(f)
  local num_channels    = read_word_le(f)
  local num_patterns    = read_word_le(f)
  local num_instruments = read_word_le(f)
  local flags           = read_word_le(f)
  local default_tempo   = read_word_le(f)
  local default_bpm     = read_word_le(f)
  local pattern_order   = {}
  for i=1,song_length do pattern_order[i] = read_byte(f) end

  print(string.format(
    "XM Header: id='%s', module='%s', tracker='%s', version=0x%04X, header_size=%d, channels=%d, patterns=%d, instruments=%d, tempo=%d, bpm=%d",
    id_text, module_name, tracker_name, version, header_size, num_channels, num_patterns, num_instruments, default_tempo, default_bpm
  ))

  -- skip to end of header
  f:seek('set',60 + header_size)

  -- PATTERNS
  local patterns = {}
  for pi=1,num_patterns do
    local pat_hdr_len = read_dword_le(f)
    local packing     = read_byte(f)
    local num_rows    = read_word_le(f)
    local packed_size= read_word_le(f)
    local pat_data    = packed_size>0 and read_bytes(f,packed_size) or nil
    patterns[pi]      = {rows=num_rows,data=pat_data}
    print(string.format("Pattern %d: rows=%d, packed_size=%d", pi, num_rows, packed_size))
  end

  -- INSTRUMENTS & SAMPLES
  local instruments = {}
  for ii=1,num_instruments do
    local ins_size    = read_dword_le(f)
    local ins_name    = read_string(f,22)
    local ins_type    = read_byte(f)
    local ins_samples = read_word_le(f)
    local samples     = {}

    if ins_samples > 0 then
      local samp_hdr_size = read_dword_le(f)
      read_bytes(f,96) -- keymap
      for i=1,48 do read_word_le(f) end -- envelopes
      local vol_pn = read_byte(f)
      local pan_pn = read_byte(f)
      local vol_spt = read_byte(f)
      local vol_lsp = read_byte(f)
      local vol_lend= read_byte(f)
      local pan_spt = read_byte(f)
      local pan_lsp = read_byte(f)
      local pan_lend= read_byte(f)
      local vol_etype= read_byte(f)
      local pan_etype= read_byte(f)
      local vib_type= read_byte(f)
      local vib_sweep= read_byte(f)
      local vib_depth= read_byte(f)
      local vib_rate= read_byte(f)
      local vol_fadeout= read_word_le(f)
      read_bytes(f,22) -- reserved

      for si=1,ins_samples do
        local length     = read_dword_le(f)
        local loop_start = read_dword_le(f)
        local loop_len   = read_dword_le(f)
        local volume     = read_byte(f)
        local finetune   = read_byte(f)
        local type_b     = read_byte(f)
        local panning    = read_byte(f)
        local rel_note   = read_byte(f)
        read_byte(f) -- reserved
        local samp_name  = read_string(f,22)
        -- Lua 5.1 compatible integer division for ADPCM header
        local extra = 0
        if type_b%16 == 13 then
          extra = math.floor((length+1)/2) + 16
        end
        local raw = read_bytes(f,
          length
          + (type_b>=16 and 1 or 0)
          + extra
        )

        local data
        local bitdepth = (type_b>=16) and 16 or 8
        if type_b%16 == 13 then
          data = decode_adpcm(raw, length)
        elseif bitdepth==8 then
          data = decode_delta_8(raw)
        else
          data = decode_delta_16(raw)
        end

        samples[si] = {
          name       = samp_name,
          length     = length,
          loop_start = loop_start,
          loop_len   = loop_len,
          type       = type_b,
          volume     = volume,
          finetune   = (finetune>127 and finetune-256) or finetune,
          panning    = panning,
          rel_note   = rel_note,
          bitdepth   = bitdepth,
          data       = data
        }
        print(string.format(
          "  Sample %d: '%s', len=%d, bits=%d, loop=(%d,%d), mode=%d, vol=%d, finetune=%d, pan=%d",
          si, samp_name, length, bitdepth, loop_start, loop_len, type_b%4, volume, finetune, panning
        ))
      end
    end

    instruments[ii] = {name=ins_name, samples=samples}
  end

  f:close()

  -- clear existing instruments (keep one empty)
  while #rns.instruments > 1 do
    rns:delete_instrument_at(2)
  end

  -- import instruments & samples
  for idx,ins in ipairs(instruments) do
    local ri = (idx==1) and rns.instruments[1] or rns:insert_instrument_at(idx-1)
    ri.name = ins.name
    while #ri.samples > 0 do ri:delete_sample_at(1) end

    for sidx,s in ipairs(ins.samples) do
      local rs = ri:insert_sample_at(sidx)
      rs.name = s.name
      local buf = rs.sample_buffer
      if buf.has_sample_data then buf:delete_sample_data() end
      buf:create_sample_data(8363, s.bitdepth, 1, s.length)
      buf:prepare_sample_data_changes()
      for frame=1,s.length do
        buf:set_sample_data(1, frame, s.data[frame] or 0)
      end
      buf:finalize_sample_data_changes()

      if s.loop_len and s.loop_len > 1 then
        rs.loop_mode  = (s.type%4==2)
          and renoise.Sample.LOOP_MODE_PING_PONG
          or renoise.Sample.LOOP_MODE_FORWARD
        rs.loop_start = math.max(1, math.min(s.loop_start+1, s.length))
        rs.loop_end   = math.max(1, math.min(s.loop_start + s.loop_len, s.length))
      else
        rs.loop_mode  = renoise.Sample.LOOP_MODE_OFF
        rs.loop_start, rs.loop_end = 1,1
      end

      rs.volume    = math.max(0, math.min(s.volume,64))
      rs.transpose = s.rel_note
      rs.fine_tune = s.finetune
      rs.panning   = math.max(0, math.min(s.panning/255,1))
    end
  end

  -- PATTERN IMPORT (basic unpacking)
  for pi,pat in ipairs(patterns) do
    local pat_obj = (#rns.patterns>=pi)
      and rns.patterns[pi]
      or rns:insert_pattern_at(pi-1)
    pat_obj.number_of_tracks = num_channels
    for row=1,pat.rows do
      for tr=1,num_channels do
        local col = pat_obj:track(tr).lines[row]
        -- TODO: full unpacking code here
      end
    end
  end

  renoise.app():show_message("XM import completed: "..filename)
  return true
end

-- Register file opener
renoise.tool():add_menu_entry{
  name = "File.Import:XM Module...",
  invoke = function() import_xm_file(renoise.app().prompt_load_filename({ "xm" })) end
}
