-- Paketti XM Importer for Renoise v2.1 (Lua 5.1 compliant, optimized bulk sample import)

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
  local id_text          = read_string(f,17)
  local module_name      = read_string(f,20)
  local magic            = read_byte(f)
  local tracker_name     = read_string(f,20)
  local version          = read_word_le(f)
  local header_size      = read_dword_le(f)
  local song_length      = read_word_le(f)
  local restart_position = read_word_le(f)
  local num_channels     = read_word_le(f)
  local num_patterns     = read_word_le(f)
  local num_instruments  = read_word_le(f)
  local flags            = read_word_le(f)
  local default_tempo    = read_word_le(f)
  local default_bpm      = read_word_le(f)
  local pattern_order    = {}
  for i=1,song_length do pattern_order[i] = read_byte(f) end

  -- Seek to pattern data
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
      read_bytes(f,96)           -- keymap
      for i=1,48 do read_word_le(f) end -- envelopes
      local vol_pn,pan_pn = read_byte(f),read_byte(f)
      local vol_spt,vol_lsp,vol_lend = read_byte(f),read_byte(f),read_byte(f)
      local pan_spt,pan_lsp,pan_lend = read_byte(f),read_byte(f),read_byte(f)
      local vol_etype,pan_etype = read_byte(f),read_byte(f)
      local vib_type,vib_sweep,vib_depth,vib_rate = read_byte(f),read_byte(f),read_byte(f),read_byte(f)
      local vol_fadeout = read_word_le(f)
      read_bytes(f,22)         -- reserved

      for si=1,ins_samples do
        local length     = read_dword_le(f)
        local loop_start = read_dword_le(f)
        local loop_len   = read_dword_le(f)
        local volume     = read_byte(f)
        local finetune   = read_byte(f)
        local type_b     = read_byte(f)
        local panning    = read_byte(f)
        local rel_note   = read_byte(f)
        read_byte(f)    -- reserved
        local samp_name  = read_string(f,22)

        local extra = 0
        if type_b%16 == 13 then
          extra = math.floor((length+1)/2) + 16
        end
        local raw = read_bytes(f,length + (type_b>=16 and 1 or 0) + extra)

        local data,bitdepth
        if type_b%16 == 13 then
          data,bitdepth = decode_adpcm(raw,length),8
        elseif type_b>=16 then
          data,bitdepth = decode_delta_16(raw),16
        else
          data,bitdepth = decode_delta_8(raw),8
        end

        samples[si] = {
          name=samp_name, length=length, loop_start=loop_start,
          loop_len=loop_len, type=type_b, volume=volume,
          finetune=(finetune>127 and finetune-256) or finetune,
          panning=panning, rel_note=rel_note,
          vol_fadeout=vol_fadeout, bitdepth=bitdepth, data=data
        }
      end
    end

    instruments[ii] = {name=ins_name,samples=samples}
  end
  f:close()

  -- RESET EXISTING INSTRUMENTS
  while #rns.instruments > 1 do rns:delete_instrument_at(2) end

  -- IMPORT INSTRUMENTS & SAMPLES with bulk sample set
  for idx,ins in ipairs(instruments) do
    local ri = (idx==1) and rns.instruments[1] or rns:insert_instrument_at(idx)
    ri.name = ins.name
    while #ri.samples > 0 do ri:delete_sample_at(1) end

    for sidx,s in ipairs(ins.samples) do
      local rs = ri:insert_sample_at(sidx)
      rs.name = s.name
      local buf = rs.sample_buffer
      if buf.has_sample_data then buf:delete_sample_data() end
      buf:create_sample_data(8363,s.bitdepth,1,#s.data)
      buf:prepare_sample_data_changes()
      -- write each sample frame into track 1:
for frame_idx = 1, s.length do
  buf:set_sample_data(
    1,          -- channel_index (mono → always 1)
    frame_idx,  -- frame_index
    s.data[frame_idx] or 0
  )
end

      buf:finalize_sample_data_changes()

      if s.loop_len>1 then
        rs.loop_mode = (s.type%4==2) and renoise.Sample.LOOP_MODE_PING_PONG or renoise.Sample.LOOP_MODE_FORWARD
        rs.loop_start = math.max(1, math.min((s.loop_start or 0)+1,#s.data))
        rs.loop_end   = math.max(rs.loop_start, math.min((s.loop_start or 0) + (s.loop_len or 0),#s.data))
      else
        rs.loop_mode = renoise.Sample.LOOP_MODE_OFF
      end
      -- Scale XM volume (0-64) to Renoise volume (0-4)
      rs.volume           = (s.volume / 64) * 4
      rs.transpose        = s.rel_note - 24
      rs.fine_tune        = s.finetune
  --    rs.volume_fade_out  = s.vol_fadeout or 0
      rs.panning          = s.panning / 255
    end
  end

  -- PATTERN IMPORT
  for pi,pat in ipairs(patterns) do
    local pat_obj = (#rns.patterns>=pi) and rns.patterns[pi] or rns:insert_pattern_at(pi-1)
    -- Ensure we have enough tracks
    if pi == 1 then
      -- Add tracks until we match the required XM channel count
      while #rns.tracks < num_channels do
        rns:insert_track_at(#rns.tracks + 1)
      end
    end
    -- Set the number of lines for this pattern
    pat_obj.number_of_lines = pat.rows
    if pat.data then
      local ptr=1
      for row=1,pat.rows do
        for tr=1,num_channels do
          local col = pat_obj:track(tr).lines[row].note_columns[1]
          local b = pat.data:byte(ptr); ptr=ptr+1
          local note,ins,vol,eff,par = 0,0,0,0,0
          if b>=128 then
            if b%2==1 then note=pat.data:byte(ptr); ptr=ptr+1 end
            if b%4>=2 then ins =pat.data:byte(ptr); ptr=ptr+1 end
            if b%8>=4 then vol =pat.data:byte(ptr); ptr=ptr+1 end
            if b%16>=8 then eff =pat.data:byte(ptr); ptr=ptr+1 end
            if b%32>=16 then par=pat.data:byte(ptr); ptr=ptr+1 end
          else
            note=b; ins=pat.data:byte(ptr); vol=pat.data:byte(ptr+1)
            eff=pat.data:byte(ptr+2); par=pat.data:byte(ptr+3)
            ptr=ptr+4
          end
          col.note_string       = map_xm_note(note)
          col.instrument_string = (ins > 0) and string.format("%02X",ins) or ""
          col.volume_string     = (vol<=64) and string.format("%02X",vol) or ""
          col.effect_number_string    = (eff > 0) and string.format("%02X",eff) or ""
          col.effect_amount_string    = (par > 0) and string.format("%02X",par) or ""
        end
      end
    end
  end

  renoise.app():show_status("XM import completed: "..filename)
  return true
end

-- Menu entry & import hook
renoise.tool():add_menu_entry{
  name   = 'Song:Import...:XM File',
  invoke = function()
    import_xm_file(renoise.app():prompt_for_filename_to_read({title='Open XM File'}))
  end
}

local xm_hook = { category="song", extensions={"xm"}, invoke=import_xm_file }
if not renoise.tool():has_file_import_hook(xm_hook.category, xm_hook.extensions) then
  renoise.tool():add_file_import_hook(xm_hook)
end
