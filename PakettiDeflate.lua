--[[============================================================================
PakettiDeflate.lua — pure-Lua DEFLATE / gzip primitives

Paketti had no compression code at all, which is what kept every gzip- and
zip-wrapped instrument format out of reach: Ableton .adv/.adg/.als (gzipped XML),
OP-XY .preset.zip, Digitakt II .dt2pst, and .xrni itself. This module is that
missing layer, in pure Lua so it works identically on macOS, Windows and Linux
with no shell tools and no external binaries.

What is here:

  PakettiCRC32(data)              CRC-32/ISO-HDLC (poly 0xEDB88320) — the CRC
                                  both gzip and zip use.
  PakettiInflate(data, pos)       RFC 1951 raw DEFLATE decoder.
  PakettiGunzip(data)             RFC 1952 gzip container -> plain string.
  PakettiGzip(data, filename)     gzip container writer.

Why the writer never compresses: DEFLATE defines a "stored" block type (BTYPE=00)
that carries bytes verbatim. Every conforming reader — Ableton Live included —
must accept it. Emitting stored blocks means Paketti needs a *decompressor* but
never a *compressor*, which removes the single largest piece of work while
producing files that are byte-for-byte legal gzip. The cost is file size, and an
Ableton preset is XML measured in kilobytes.

Decoder notes: the hot loop is inlined rather than factored into a bit-reader
function, because Lua 5.1 function-call overhead dominates otherwise. Output is
accumulated as a byte array so LZ77 back-references are plain table indexing,
then flushed to string chunks. A ~1 MB Drum Rack decodes in roughly a second.
============================================================================]]--

local band, bor, lshift, rshift, bxor =
  bit.band, bit.bor, bit.lshift, bit.rshift, bit.bxor
local byte, char, sub, concat = string.byte, string.char, string.sub, table.concat

--------------------------------------------------------------------------------
-- CRC-32
--------------------------------------------------------------------------------

local crc_table = nil

local function build_crc_table()
  crc_table = {}
  for i = 0, 255 do
    local crc = i
    for _ = 1, 8 do
      if band(crc, 1) == 1 then
        crc = bxor(rshift(crc, 1), 0xEDB88320)
      else
        crc = rshift(crc, 1)
      end
    end
    crc_table[i] = crc
  end
end

function PakettiCRC32(data)
  if not crc_table then build_crc_table() end
  local crc = 0xFFFFFFFF
  local t = crc_table
  for i = 1, #data do
    crc = bxor(rshift(crc, 8), t[band(bxor(crc, byte(data, i)), 0xFF)])
  end
  crc = bxor(crc, 0xFFFFFFFF)
  -- bit ops hand back a signed 32-bit value; normalise to unsigned
  if crc < 0 then crc = crc + 4294967296 end
  return crc
end

--------------------------------------------------------------------------------
-- Huffman tables
--
-- Canonical Huffman, stored as one flat lookup per code length. first[len] is
-- the numeric value of the first code of that length and sym[len] is an array of
-- the symbols in canonical order, so decoding is "accumulate one bit, index".
--------------------------------------------------------------------------------

local function build_huffman(lengths, n)
  local count = {}
  for i = 0, 15 do count[i] = 0 end
  for i = 1, n do
    local l = lengths[i]
    count[l] = count[l] + 1
  end
  count[0] = 0

  local offs = {}
  local total = 0
  for l = 1, 15 do
    offs[l] = total
    total = total + count[l]
  end

  local sorted = {}
  for i = 1, n do
    local l = lengths[i]
    if l ~= 0 then
      offs[l] = offs[l] + 1
      sorted[offs[l]] = i - 1
    end
  end

  -- first code and symbol-array base per length
  local first, base = {}, {}
  local code, idx = 0, 1
  for l = 1, 15 do
    first[l] = code
    base[l] = idx
    idx = idx + count[l]
    code = lshift(code + count[l], 1)
  end

  return { count = count, first = first, base = base, sorted = sorted }
end

--------------------------------------------------------------------------------
-- Fixed tables (RFC 1951 section 3.2.6), built once
--------------------------------------------------------------------------------

local fixed_lit, fixed_dist = nil, nil

local function build_fixed()
  local l = {}
  for i = 1, 144 do l[i] = 8 end
  for i = 145, 256 do l[i] = 9 end
  for i = 257, 280 do l[i] = 7 end
  for i = 281, 288 do l[i] = 8 end
  fixed_lit = build_huffman(l, 288)

  local d = {}
  for i = 1, 30 do d[i] = 5 end
  fixed_dist = build_huffman(d, 30)
end

local LENGTH_BASE = {
  3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258 }
local LENGTH_EXTRA = {
  0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0 }
local DIST_BASE = {
  1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,
  4097,6145,8193,12289,16385,24577 }
local DIST_EXTRA = {
  0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13 }
local CLEN_ORDER = {17,18,19,1,9,8,10,7,11,6,12,5,13,4,14,3,15,2,16}

--------------------------------------------------------------------------------
-- PakettiInflate — RFC 1951 raw DEFLATE
--
-- Returns decompressed string, or nil plus an error message.
--------------------------------------------------------------------------------

--- on_progress, when given, is called roughly every 32 KB of output with the
--- number of bytes produced so far. Running under a ProcessSlicer, pass a
--- function that yields: a megabyte of Ableton XML takes about a second to
--- decode, which is long enough for Renoise to report the tool unresponsive.
function PakettiInflate(data, start_pos, on_progress)
  if type(data) ~= "string" or #data == 0 then
    return nil, "inflate: no data"
  end
  if not fixed_lit then build_fixed() end

  local pos = start_pos or 1
  local len_data = #data
  local bitbuf, bitcnt = 0, 0

  -- output as a byte array; back-references index straight into it
  local out, outn = {}, 0
  local chunks = {}
  local flushed = 0
  local progress_mark = 0

  local function flush_chunk()
    -- string.char has an argument-count ceiling, so move in slices
    local i = 1
    local parts = {}
    while i <= outn do
      local j = i + 4095
      if j > outn then j = outn end
      parts[#parts + 1] = char(unpack(out, i, j))
      i = j + 1
    end
    chunks[#chunks + 1] = concat(parts)
    out, outn = {}, 0
  end

  local function need_bits(n)
    while bitcnt < n do
      if pos > len_data then return false end
      bitbuf = bor(bitbuf, lshift(byte(data, pos), bitcnt))
      pos = pos + 1
      bitcnt = bitcnt + 8
    end
    return true
  end

  local function get_bits(n)
    if n == 0 then return 0 end
    if not need_bits(n) then return nil end
    local v = band(bitbuf, lshift(1, n) - 1)
    bitbuf = rshift(bitbuf, n)
    bitcnt = bitcnt - n
    return v
  end

  local function decode(huff)
    local count, first, base, sorted = huff.count, huff.first, huff.base, huff.sorted
    local code, len = 0, 0
    for l = 1, 15 do
      if bitcnt < 1 then
        if pos > len_data then return nil end
        bitbuf = bor(bitbuf, lshift(byte(data, pos), bitcnt))
        pos = pos + 1
        bitcnt = bitcnt + 8
      end
      code = code * 2 + band(bitbuf, 1)
      bitbuf = rshift(bitbuf, 1)
      bitcnt = bitcnt - 1
      len = l
      local c = count[l]
      if c > 0 and code - first[l] < c then
        return sorted[base[l] + (code - first[l])]
      end
    end
    return nil
  end

  while true do
    local bfinal = get_bits(1)
    if bfinal == nil then return nil, "inflate: truncated at block header" end
    local btype = get_bits(2)
    if btype == nil then return nil, "inflate: truncated at block type" end

    if btype == 0 then
      -- stored: discard partial byte, then LEN/NLEN and a verbatim copy
      bitbuf, bitcnt = 0, 0
      if pos + 3 > len_data then return nil, "inflate: truncated stored header" end
      local l1, l2, n1, n2 = byte(data, pos, pos + 3)
      pos = pos + 4
      local blen = l1 + l2 * 256
      local nlen = n1 + n2 * 256
      if blen + nlen ~= 65535 then return nil, "inflate: stored length check failed" end
      if pos + blen - 1 > len_data then return nil, "inflate: truncated stored block" end
      for i = pos, pos + blen - 1 do
        outn = outn + 1
        out[outn] = byte(data, i)
      end
      pos = pos + blen

    elseif btype == 1 or btype == 2 then
      local lit_huff, dist_huff

      if btype == 1 then
        lit_huff, dist_huff = fixed_lit, fixed_dist
      else
        local hlit = get_bits(5)
        local hdist = get_bits(5)
        local hclen = get_bits(4)
        if hlit == nil or hdist == nil or hclen == nil then
          return nil, "inflate: truncated dynamic header"
        end
        hlit = hlit + 257
        hdist = hdist + 1
        hclen = hclen + 4

        local clen = {}
        for i = 1, 19 do clen[i] = 0 end
        for i = 1, hclen do
          local v = get_bits(3)
          if v == nil then return nil, "inflate: truncated code lengths" end
          clen[CLEN_ORDER[i]] = v
        end
        local clen_huff = build_huffman(clen, 19)

        local lengths = {}
        local i = 1
        while i <= hlit + hdist do
          local sym = decode(clen_huff)
          if sym == nil then return nil, "inflate: bad code-length symbol" end
          if sym < 16 then
            lengths[i] = sym
            i = i + 1
          elseif sym == 16 then
            if i == 1 then return nil, "inflate: repeat with no previous length" end
            local prev = lengths[i - 1]
            local r = get_bits(2)
            if r == nil then return nil, "inflate: truncated repeat" end
            for _ = 1, r + 3 do lengths[i] = prev; i = i + 1 end
          elseif sym == 17 then
            local r = get_bits(3)
            if r == nil then return nil, "inflate: truncated zero-run" end
            for _ = 1, r + 3 do lengths[i] = 0; i = i + 1 end
          else
            local r = get_bits(7)
            if r == nil then return nil, "inflate: truncated zero-run" end
            for _ = 1, r + 11 do lengths[i] = 0; i = i + 1 end
          end
        end

        local litlen = {}
        for k = 1, hlit do litlen[k] = lengths[k] or 0 end
        local distlen = {}
        for k = 1, hdist do distlen[k] = lengths[hlit + k] or 0 end

        lit_huff = build_huffman(litlen, hlit)
        dist_huff = build_huffman(distlen, hdist)
      end

      while true do
        if on_progress and outn - progress_mark >= 32768 then
          progress_mark = outn
          on_progress(flushed + outn)
        end

        local sym = decode(lit_huff)
        if sym == nil then return nil, "inflate: bad literal/length symbol" end
        if sym < 256 then
          outn = outn + 1
          out[outn] = sym
        elseif sym == 256 then
          break
        else
          local li = sym - 256
          if li > 29 then return nil, "inflate: length symbol out of range" end
          local extra = get_bits(LENGTH_EXTRA[li])
          if extra == nil then return nil, "inflate: truncated length extra" end
          local length = LENGTH_BASE[li] + extra

          local dsym = decode(dist_huff)
          if dsym == nil then return nil, "inflate: bad distance symbol" end
          local di = dsym + 1
          if di > 30 then return nil, "inflate: distance symbol out of range" end
          local dextra = get_bits(DIST_EXTRA[di])
          if dextra == nil then return nil, "inflate: truncated distance extra" end
          local dist = DIST_BASE[di] + dextra

          local from = outn - dist + 1
          if from < 1 then return nil, "inflate: distance before start of output" end
          for k = from, from + length - 1 do
            outn = outn + 1
            out[outn] = out[k]
          end
        end

        -- keep the byte array from growing without bound on large streams;
        -- 64 KB of history is enough for any DEFLATE back-reference (32 KB max)
        if outn > 1048576 then
          local keep = 65536
          local tail = {}
          for k = 1, keep do tail[k] = out[outn - keep + k] end
          local head = outn - keep
          local parts = {}
          local i2 = 1
          while i2 <= head do
            local j2 = i2 + 4095
            if j2 > head then j2 = head end
            parts[#parts + 1] = char(unpack(out, i2, j2))
            i2 = j2 + 1
          end
          chunks[#chunks + 1] = concat(parts)
          flushed = flushed + head
          out, outn = tail, keep
          progress_mark = 0
          -- the retained tail must stay addressable by the same relative offsets,
          -- which it does: back-references are computed from outn downward
        end
      end

    else
      return nil, "inflate: reserved block type"
    end

    if bfinal == 1 then break end
  end

  flush_chunk()
  return concat(chunks)
end

--------------------------------------------------------------------------------
-- PakettiGunzip — RFC 1952 container
--------------------------------------------------------------------------------

function PakettiGunzip(data, on_progress)
  if type(data) ~= "string" or #data < 18 then
    return nil, "gunzip: too short to be a gzip file"
  end
  local id1, id2, cm, flg = byte(data, 1, 4)
  if id1 ~= 0x1F or id2 ~= 0x8B then
    return nil, "gunzip: not gzip (bad magic)"
  end
  if cm ~= 8 then
    return nil, "gunzip: unsupported compression method " .. tostring(cm)
  end

  local pos = 11 -- past magic, CM, FLG, MTIME(4), XFL, OS

  if band(flg, 0x04) ~= 0 then -- FEXTRA
    local x1, x2 = byte(data, pos, pos + 1)
    if not x1 or not x2 then return nil, "gunzip: truncated FEXTRA" end
    pos = pos + 2 + x1 + x2 * 256
  end
  if band(flg, 0x08) ~= 0 then -- FNAME
    while pos <= #data and byte(data, pos) ~= 0 do pos = pos + 1 end
    pos = pos + 1
  end
  if band(flg, 0x10) ~= 0 then -- FCOMMENT
    while pos <= #data and byte(data, pos) ~= 0 do pos = pos + 1 end
    pos = pos + 1
  end
  if band(flg, 0x02) ~= 0 then -- FHCRC
    pos = pos + 2
  end
  if pos > #data then return nil, "gunzip: truncated header" end

  local out, err = PakettiInflate(data, pos, on_progress)
  if not out then return nil, err end
  return out
end

--------------------------------------------------------------------------------
-- PakettiGzip — RFC 1952 container using stored (uncompressed) DEFLATE blocks
--------------------------------------------------------------------------------

function PakettiGzip(data, filename)
  if type(data) ~= "string" then
    return nil, "gzip: expected a string"
  end

  local parts = {}
  local flg = 0
  if filename and filename ~= "" then flg = 0x08 end

  parts[#parts + 1] = char(0x1F, 0x8B, 0x08, flg, 0, 0, 0, 0, 0, 3)
  if filename and filename ~= "" then
    parts[#parts + 1] = filename .. char(0)
  end

  local total = #data
  if total == 0 then
    -- an empty final stored block
    parts[#parts + 1] = char(1, 0, 0, 0xFF, 0xFF)
  else
    local pos = 1
    while pos <= total do
      local blen = total - pos + 1
      if blen > 65535 then blen = 65535 end
      local final = (pos + blen > total) and 1 or 0
      local nlen = 65535 - blen
      parts[#parts + 1] = char(
        final,
        band(blen, 0xFF), band(rshift(blen, 8), 0xFF),
        band(nlen, 0xFF), band(rshift(nlen, 8), 0xFF))
      parts[#parts + 1] = sub(data, pos, pos + blen - 1)
      pos = pos + blen
    end
  end

  local crc = PakettiCRC32(data)
  local isize = total % 4294967296
  local function u32le(v)
    return char(band(v, 0xFF), band(rshift(v, 8), 0xFF),
                band(rshift(v, 16), 0xFF), band(rshift(v, 24), 0xFF))
  end
  parts[#parts + 1] = u32le(crc)
  parts[#parts + 1] = u32le(isize)

  return concat(parts)
end

--------------------------------------------------------------------------------
-- File-level convenience wrappers
--------------------------------------------------------------------------------

function PakettiGunzipFile(path, on_progress)
  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. tostring(path) end
  local data = f:read("*a")
  f:close()
  if not data then return nil, "cannot read " .. tostring(path) end
  return PakettiGunzip(data, on_progress)
end

function PakettiGzipToFile(path, data, filename)
  local packed, err = PakettiGzip(data, filename)
  if not packed then return false, err end
  local f = io.open(path, "wb")
  if not f then return false, "cannot write " .. tostring(path) end
  f:write(packed)
  f:close()
  return true
end

--------------------------------------------------------------------------------
-- PakettiZipWrite — minimal ZIP writer using stored (uncompressed) entries
--
-- Same reasoning as the gzip writer above: the ZIP spec's method 0 stores bytes
-- verbatim and every reader must accept it, so Paketti can produce legal archives
-- without a compressor. This is what the container-based instrument formats need
-- — Digitakt II .dt2pst today, OP-XY .preset.zip and .xrni later.
--
-- entries is an array of { name = "path/in/zip", data = "..." }, written in order.
--------------------------------------------------------------------------------

local function zip_u16(v)
  return string.char(bit.band(v, 0xFF), bit.band(bit.rshift(v, 8), 0xFF))
end

local function zip_u32(v)
  -- v may exceed 2^31, so fold it down rather than using bit ops on the top byte
  local b1 = v % 256; v = math.floor(v / 256)
  local b2 = v % 256; v = math.floor(v / 256)
  local b3 = v % 256; v = math.floor(v / 256)
  return string.char(b1, b2, b3, v % 256)
end

function PakettiZipWrite(path, entries)
  if type(entries) ~= "table" or #entries == 0 then
    return false, "zip: nothing to write"
  end

  local locals, central = {}, {}
  local offset = 0
  -- a fixed timestamp keeps output reproducible: 2025-01-01 00:00:00
  local mod_time, mod_date = 0, 45 * 512 + 1 * 32 + 1

  for i = 1, #entries do
    local name = entries[i].name
    local data = entries[i].data or ""
    local crc = PakettiCRC32(data)
    local size = #data

    local header = "PK\3\4"
      .. zip_u16(20) .. zip_u16(0) .. zip_u16(0)      -- version, flags, method 0
      .. zip_u16(mod_time) .. zip_u16(mod_date)
      .. zip_u32(crc) .. zip_u32(size) .. zip_u32(size)
      .. zip_u16(#name) .. zip_u16(0)
      .. name

    locals[#locals + 1] = header
    locals[#locals + 1] = data

    central[#central + 1] = "PK\1\2"
      .. zip_u16(20) .. zip_u16(20) .. zip_u16(0) .. zip_u16(0)
      .. zip_u16(mod_time) .. zip_u16(mod_date)
      .. zip_u32(crc) .. zip_u32(size) .. zip_u32(size)
      .. zip_u16(#name) .. zip_u16(0) .. zip_u16(0)
      .. zip_u16(0) .. zip_u16(0) .. zip_u32(0)
      .. zip_u32(offset)
      .. name

    offset = offset + #header + size
  end

  local central_str = table.concat(central)
  local eocd = "PK\5\6"
    .. zip_u16(0) .. zip_u16(0)
    .. zip_u16(#entries) .. zip_u16(#entries)
    .. zip_u32(#central_str) .. zip_u32(offset)
    .. zip_u16(0)

  local f = io.open(path, "wb")
  if not f then return false, "zip: cannot write " .. tostring(path) end
  f:write(table.concat(locals))
  f:write(central_str)
  f:write(eocd)
  f:close()
  return true
end
