-- PakettiDWVW.lua
-- DWVW (Delta With Variable Word Width) import / export / batch conversion.
--
-- DWVW is the lossless codec used by Typhoon OS for the Yamaha TX16W sampler
-- and by the Cyclone emulator. It was invented 1991 by Magnus Lidstrom and is
-- copyright 1993 by NuEdge Development. Files are AIFF-C (FORM/AIFC) with the
-- compression type "DWVW"; the TX16W ships them as .C01 .. .C99.
--
-- The codec below is a verified 1:1 port of the reference implementation
-- (dwvw.c by Jacob Vosmaer, from the fmt_typh.rtf specification). Encoder
-- output is byte-identical to the reference for mono, stereo, silence and
-- maximum-delta wraparound material.
--
-- Pure Lua 5.1: no bit library, no 64-bit integers. Every value stays under
-- 2^53 so plain doubles are exact.

local floor = math.floor

-- Outcome of the most recent import / export / batch run, for troubleshooting.
PakettiDWVWLastStatus = "never run"

-- The TX16W cannot hold a wave longer than this. The longest sample in a
-- 1006-file survey of real TX16W libraries is 262016 frames, just under it.
PAKETTI_DWVW_MAX_FRAMES = 262144

--------------------------------------------------------------------------------
-- Byte helpers (big-endian, 1-based string positions)
--------------------------------------------------------------------------------

local function getuint(s, pos, width)
  local x = 0
  for i = 0, width / 8 - 1 do x = x * 256 + s:byte(pos + i) end
  return x
end

local function getint(s, pos, width)
  local x = getuint(s, pos, width)
  if x >= 2 ^ (width - 1) then x = x - 2 ^ width end
  return x
end

local function putint(x, width)
  if x < 0 then x = x + 2 ^ width end
  local out = {}
  for shift = width - 8, 0, -8 do
    out[#out + 1] = string.char(floor(x / 2 ^ shift) % 256)
  end
  return table.concat(out)
end

-- AIFF stores the sample rate as an IEEE 754 80-bit extended float.
local function put_extended(rate)
  if rate <= 0 then return string.rep("\0", 10) end
  -- The 80-bit format carries an explicit integer bit, so the mantissa is
  -- normalised into [1, 2) and scaled by 2^63.
  local m, exp = rate, 16383
  while m >= 2.0 do m = m / 2 ; exp = exp + 1 end
  while m < 1.0 do m = m * 2 ; exp = exp - 1 end
  local hi = floor(m * 2 ^ 31)
  local lo = floor((m * 2 ^ 31 - hi) * 2 ^ 32)
  return putint(exp, 16) .. putint(hi, 32) .. putint(lo, 32)
end

local function get_extended(s, pos)
  local exp = getuint(s, pos, 16) % 32768
  local hi, lo = getuint(s, pos + 2, 32), getuint(s, pos + 6, 32)
  if exp == 0 and hi == 0 and lo == 0 then return 0 end
  return floor((hi * 2 ^ 32 + lo) * 2 ^ (exp - 16383 - 63) + 0.5)
end

local function fourcc(s, pos) return s:sub(pos, pos + 3) end
local function nextchunk(size) return 8 + size + (size % 2) end

--------------------------------------------------------------------------------
-- Bit writer / reader
--------------------------------------------------------------------------------

local BW = {}
BW.__index = BW
local function bitwriter() return setmetatable({bytes = {}, n = 0, cur = 0}, BW) end

function BW:put(v)
  local shift = 7 - self.n % 8
  if shift == 7 then self.cur = 0 end
  if v ~= 0 then self.cur = self.cur + 2 ^ shift end
  self.n = self.n + 1
  if self.n % 8 == 0 then self.bytes[#self.bytes + 1] = string.char(self.cur) end
end

function BW:finish()
  if self.n % 8 ~= 0 then self.bytes[#self.bytes + 1] = string.char(self.cur) end
  return table.concat(self.bytes)
end

local BR = {}
BR.__index = BR
local function bitreader(s, pos, len)
  return setmetatable({s = s, pos = pos, size = len, n = 0}, BR)
end

function BR:get()
  local b = 0
  local byte = floor(self.n / 8)
  if byte < self.size then
    b = floor(self.s:byte(self.pos + byte) / 2 ^ (7 - self.n % 8)) % 2
    self.n = self.n + 1
  end
  return b
end

--------------------------------------------------------------------------------
-- Codec
--------------------------------------------------------------------------------

-- ints: array of signed integers already at `wordsize` resolution.
-- yield_every: when non-nil, coroutine.yield() is called every N samples so a
-- ProcessSlicer can keep the Renoise UI alive during long encodes.
function PakettiDWVWEncodeChannel(ints, nsamples, wordsize, yield_every)
  local bw = bitwriter()
  local lastsample, lastwidth = 0, 0
  local half = floor(wordsize / 2)
  local top = 2 ^ (wordsize - 1)
  local full = 2 ^ wordsize

  for j = 1, nsamples do
    local sampledelta = ints[j] - lastsample
    lastsample = ints[j]
    -- The delta is stored as (wordsize-1) magnitude bits plus a sign bit, so it
    -- has to wrap around to fit.
    if sampledelta >= top then sampledelta = sampledelta - full
    elseif sampledelta < -top then sampledelta = sampledelta + full end

    local sampledeltasign = sampledelta < 0 and 1 or 0
    if sampledeltasign == 1 then sampledelta = -sampledelta end

    -- The delta encoding has no room for the lowest two's-complement value
    -- (-2^(wordsize-1)), so the spec stores it as one greater (magnitude
    -- 2^(wordsize-1)-1) and flags it with the extra bit after the sign. The
    -- reference C encoder instead lets the width run to `wordsize` here, which
    -- wraps the word width back to zero and desynchronises every decoder; we
    -- follow the specification.
    local escape = 0
    if sampledeltasign == 1 and sampledelta == top then
      sampledelta = top - 1
      escape = 1
    end

    local width = 0
    while 2 ^ width <= sampledelta do width = width + 1 end

    local widthdelta = width - lastwidth
    lastwidth = width
    if widthdelta > half then widthdelta = widthdelta - wordsize
    elseif widthdelta < -half then widthdelta = widthdelta + wordsize end

    local widthdeltasign = widthdelta < 0 and 1 or 0
    if widthdeltasign == 1 then widthdelta = -widthdelta end

    for _ = 1, widthdelta do bw:put(0) end        -- word width modifier, unary
    if widthdelta < half then bw:put(1) end       -- stop bit (omitted at max)
    if widthdelta ~= 0 then bw:put(widthdeltasign) end

    for i = 1, width - 1 do                       -- magnitude, top bit implied
      bw:put(floor(sampledelta / 2 ^ (width - 1 - i)) % 2)
    end
    if sampledelta ~= 0 then bw:put(sampledeltasign) end
    -- Extra bit that separates the two lowest representable negative values.
    if sampledeltasign == 1 and sampledelta >= top - 1 then
      bw:put(escape)
    end

    if yield_every and j % yield_every == 0 then coroutine.yield() end
  end

  return bw:finish()
end

-- Returns the decoded integer array and the number of bytes consumed.
function PakettiDWVWDecodeChannel(data, pos, avail, nsamples, wordsize, yield_every)
  local br = bitreader(data, pos, avail)
  local width, sample = 0, 0
  local out = {}
  local half = floor(wordsize / 2)
  local top = 2 ^ (wordsize - 1)
  local full = 2 ^ wordsize

  for j = 1, nsamples do
    local widthdelta = 0
    while widthdelta < half and br:get() == 0 do widthdelta = widthdelta + 1 end
    if widthdelta ~= 0 and br:get() == 1 then widthdelta = -widthdelta end

    width = width + widthdelta
    if width >= wordsize then width = width - wordsize
    elseif width < 0 then width = width + wordsize end

    local sampledelta = 0
    if width ~= 0 then
      sampledelta = 1
      for _ = 2, width do sampledelta = sampledelta * 2 + br:get() end
      if br:get() == 1 then sampledelta = -sampledelta end
      if sampledelta == 1 - top then sampledelta = sampledelta - br:get() end
    end

    sample = sample + sampledelta
    if sample >= top then sample = sample - full
    elseif sample < -top then sample = sample + full end
    out[j] = sample

    if yield_every and j % yield_every == 0 then coroutine.yield() end
  end

  return out, floor((br.n + 7) / 8)
end

--------------------------------------------------------------------------------
-- AIFF-C container
--------------------------------------------------------------------------------

-- channels: array (per channel) of integer arrays at `wordsize` resolution.
function PakettiDWVWBuildFile(channels, nsamples, rate, wordsize, yield_every, meta)
  local nch = #channels

  local comm = putint(nch, 16) .. putint(nsamples, 32) .. putint(wordsize, 16)
    .. put_extended(rate)
    -- Compression type, then a pascal string. Real Typhoon files use a length
    -- byte of 30 for "Delta With Variable Word Width" and pad to even length.
    .. "DWVW" .. "\030" .. "Delta With Variable Word Width" .. "\0"

  -- Root note and loop points, the way real TX16W files carry them: a MARK
  -- chunk holding the two loop positions, and an INST chunk whose sustain loop
  -- points at those markers. meta = {base_note, loop_mode, loop_start, loop_end}
  -- with loop positions as 1-based frame numbers; loop_mode uses the AIFF
  -- values 0 = none, 1 = forward, 2 = forward/backward.
  local inst, mark = "", ""
  if meta then
    local ls = math.max(0, math.min(nsamples, (meta.loop_start or 1) - 1))
    local le = math.max(0, math.min(nsamples, (meta.loop_end or nsamples) - 1))
    local mode = meta.loop_mode or 0
    mark = putint(2, 16)
      .. putint(1, 16) .. putint(ls, 32) .. "\010loop start\0"
      .. putint(2, 16) .. putint(le, 32) .. "\008loop end\0"
    inst = putint(meta.base_note or 60, 8) .. putint(0, 8)
      .. putint(meta.low_note or 0, 8) .. putint(meta.high_note or 127, 8)
      .. putint(0, 8) .. putint(127, 8) .. putint(0, 16)
      .. putint(mode, 16) .. putint(1, 16) .. putint(2, 16)   -- sustain loop
      .. putint(0, 16) .. putint(1, 16) .. putint(2, 16)      -- release loop
  end

  local ssnd = {putint(0, 32), putint(0, 32)}   -- offset, blockSize
  local n = 16                                   -- chunk header + those 8 bytes
  for c = 1, nch do
    local enc = PakettiDWVWEncodeChannel(channels[c], nsamples, wordsize, yield_every)
    ssnd[#ssnd + 1] = enc
    n = n + #enc
    -- Each channel's bit run starts on an even 16-bit word boundary.
    if n % 2 == 1 then ssnd[#ssnd + 1] = "\0" ; n = n + 1 end
  end
  ssnd = table.concat(ssnd)

  -- AIFF-C format version chunk; real TX16W/Typhoon files carry it and the
  -- AIFF-C specification requires it.
  local fver = putint(2726318400, 32)   -- 0xA2805140, AIFC version 1

  local body = "AIFC"
  -- Typhoon's own signature chunk, carrying the wave's id. A .O01 voice file
  -- references its waves by that id, so it has to come along.
  if meta and meta.appl then body = body .. meta.appl end
  body = body
    .. "FVER" .. putint(#fver, 32) .. fver
    .. "COMM" .. putint(#comm, 32) .. comm .. ((#comm % 2 == 1) and "\0" or "")
  if inst ~= "" then
    body = body .. "INST" .. putint(#inst, 32) .. inst
                .. "MARK" .. putint(#mark, 32) .. mark .. ((#mark % 2 == 1) and "\0" or "")
  end
  body = body
    .. "SSND" .. putint(#ssnd, 32) .. ssnd .. ((#ssnd % 2 == 1) and "\0" or "")
  return "FORM" .. putint(#body, 32) .. body
end

-- Returns a table: {nchannels, nsamples, wordsize, rate, channels = {ints,...}}
function PakettiDWVWParseFile(data, yield_every)
  if #data < 12 or fourcc(data, 1) ~= "FORM" then
    error("not an AIFF/AIFC file (no FORM header)")
  end
  local filetype = fourcc(data, 9)
  if filetype ~= "AIFC" then
    error("not an AIFF-C file (found '" .. filetype .. "')")
  end

  -- Trust the FORM size over the file size: real TX16W files can carry junk
  -- past the end of the FORM chunk, and walking into it looks like a corrupt
  -- chunk header.
  local formend = math.min(#data, 8 + getuint(data, 5, 32))

  local info, ssndpos, ssndsize, instchunk, markchunk, marksize
  local p = 13
  while p <= formend - 8 do
    local id, size = fourcc(data, p), getint(data, p + 4, 32)
    if size < 0 or size > formend - p - 7 then
      error(string.format("chunk '%s' has an invalid size (%d)", id, size))
    end
    if id == "COMM" then
      info = {
        nchannels = getint(data, p + 8, 16),
        nsamples  = getuint(data, p + 10, 32),
        wordsize  = getint(data, p + 14, 16),
        rate      = get_extended(data, p + 16),
        comptype  = (size >= 22) and fourcc(data, p + 26) or "NONE",
      }
    elseif id == "SSND" then
      ssndpos, ssndsize = p, size
    elseif id == "INST" and size >= 20 then
      instchunk = p + 8
    elseif id == "MARK" and size >= 2 then
      markchunk, marksize = p + 8, size
    end
    p = p + nextchunk(size)
  end

  if not info then error("no COMM chunk found") end
  if not ssndpos then error("no SSND chunk found") end
  if info.comptype ~= "DWVW" then
    error("compression is '" .. info.comptype .. "', not DWVW")
  end
  if info.nchannels < 1 or info.nchannels > 2 then
    error("unsupported channel count: " .. info.nchannels)
  end
  if info.wordsize < 1 or info.wordsize > 32 then
    error("unsupported bit depth: " .. info.wordsize)
  end

  -- Root note and loop points, if the file carries them.
  if instchunk then
    info.base_note = getint(data, instchunk, 8)
    info.low_note = getint(data, instchunk + 2, 8)
    info.high_note = getint(data, instchunk + 3, 8)
    info.loop_mode = getint(data, instchunk + 8, 16)
    info.loop_begin_marker = getuint(data, instchunk + 10, 16)
    info.loop_end_marker = getuint(data, instchunk + 12, 16)
  end
  if markchunk then
    local markers = {}
    local n = getuint(data, markchunk, 16)
    local q = markchunk + 2
    for _ = 1, n do
      if q + 6 > markchunk + marksize then break end
      local mid = getuint(data, q, 16)
      markers[mid] = getuint(data, q + 2, 32)
      local len = data:byte(q + 6) or 0
      q = q + 7 + len
      if (1 + len) % 2 == 1 then q = q + 1 end
    end
    info.markers = markers
    if info.loop_begin_marker and markers[info.loop_begin_marker] then
      info.loop_start = markers[info.loop_begin_marker] + 1
    end
    if info.loop_end_marker and markers[info.loop_end_marker] then
      info.loop_end = markers[info.loop_end_marker] + 1
    end
  end

  local pos = ssndpos + 16
  local endpos = ssndpos + nextchunk(ssndsize)
  info.channels = {}
  for c = 1, info.nchannels do
    local ints, used = PakettiDWVWDecodeChannel(
      data, pos, endpos - pos, info.nsamples, info.wordsize, yield_every)
    info.channels[c] = ints
    pos = pos + used
    if (pos - ssndpos) % 2 == 1 then pos = pos + 1 end
  end
  return info
end

--------------------------------------------------------------------------------
-- File helpers
--------------------------------------------------------------------------------

local function read_whole_file(path)
  local f, err = io.open(path, "rb")
  if not f then error("cannot open " .. tostring(path) .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  if not data or #data == 0 then error("file is empty: " .. path) end
  return data
end

local function write_whole_file(path, data)
  local f, err = io.open(path, "wb")
  if not f then error("cannot write " .. tostring(path) .. ": " .. tostring(err)) end
  f:write(data)
  f:close()
end

local function basename(path)
  return path:match("[^/\\]+$") or path
end

local function strip_extension(name)
  return (name:gsub("%.[^%.]+$", ""))
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]+$") or "."
end

local function path_sep()
  return package.config:sub(1, 1)
end

--------------------------------------------------------------------------------
-- TX16W-safe file naming
--------------------------------------------------------------------------------

-- Typhoon reads plain 720K DOS floppies, so every name has to be 8.3 uppercase.
-- Real TX16W libraries also show what happens on a collision: several different
-- samples share one 8-character base name and are told apart by the numeric
-- extension (SAMPLE_R.C01 .. SAMPLE_R.C06 are six notes of one string patch).
-- `used` is a table carried across one batch run so the same thing happens here.
local DOS_OK = "[^A-Z0-9_%-#&!%(%)~%$%%@%^{}`']"

function PakettiDWVWDosName(name, used, ext_letter)
  ext_letter = ext_letter or "C"
  local n = tostring(name or ""):upper():gsub(DOS_OK, "_")
  n = n:gsub("^_+", ""):gsub("_+$", "")
  if n == "" then n = "SAMPLE" end
  n = n:sub(1, 8)
  used = used or {}
  for i = 1, 99 do
    local full = n .. "." .. string.format("%s%02d", ext_letter, i)
    if not used[full] then
      used[full] = true
      return full
    end
  end
  -- 99 collisions on one base name: fall back to a numbered stem.
  for i = 1, 9999 do
    local stem = n:sub(1, 8 - #tostring(i)) .. tostring(i)
    local full = stem .. "." .. ext_letter .. "01"
    if not used[full] then used[full] = true return full end
  end
  error("cannot find a free 8.3 name for " .. tostring(name))
end

--------------------------------------------------------------------------------
-- Conversion between Renoise float sample data and DWVW integers
--------------------------------------------------------------------------------

-- Reads a Renoise sample buffer, resamples to target_rate (linear), optionally
-- mixes to mono, and quantises to signed `wordsize` integers.
-- Returns: channels (array of integer arrays), frame count, channel count.
function PakettiDWVWBufferToChannels(buffer, target_rate, force_mono, wordsize, yield_every)
  local src_frames = buffer.number_of_frames
  local src_rate = buffer.sample_rate
  local src_ch = buffer.number_of_channels
  -- 0 (or nil) means "keep the sample's own rate", so nothing is resampled.
  if not target_rate or target_rate <= 0 then target_rate = src_rate end
  local out_ch = (force_mono or src_ch == 1) and 1 or src_ch

  local ratio = src_rate / target_rate
  local out_frames = math.max(1, floor(src_frames / ratio))
  local scale = 2 ^ (wordsize - 1)
  local maxv, minv = scale - 1, -scale

  local channels = {}
  for c = 1, out_ch do channels[c] = {} end

  for i = 1, out_frames do
    local pos = (i - 1) * ratio + 1
    local idx = floor(pos)
    local frac = pos - idx
    local idx2 = math.min(idx + 1, src_frames)
    if idx < 1 then idx = 1 end
    if idx > src_frames then idx = src_frames end

    if out_ch == 1 and src_ch > 1 then
      local acc = 0
      for c = 1, src_ch do
        local a, b = buffer:sample_data(c, idx), buffer:sample_data(c, idx2)
        acc = acc + (a + frac * (b - a))
      end
      local v = floor((acc / src_ch) * scale + 0.5)
      channels[1][i] = (v > maxv and maxv) or (v < minv and minv) or v
    else
      for c = 1, out_ch do
        local a, b = buffer:sample_data(c, idx), buffer:sample_data(c, idx2)
        local v = floor((a + frac * (b - a)) * scale + 0.5)
        channels[c][i] = (v > maxv and maxv) or (v < minv and minv) or v
      end
    end

    if yield_every and i % yield_every == 0 then coroutine.yield() end
  end

  return channels, out_frames, out_ch
end

-- Collects the root note and loop of a Renoise sample as DWVW/AIFF metadata,
-- rescaling the loop positions when the export changed the frame count.
function PakettiDWVWSampleMeta(sample, buffer, out_frames)
  local src_frames = buffer.number_of_frames
  if src_frames < 1 or out_frames < 1 then return nil end
  local scale = out_frames / src_frames

  local modes = {}
  modes[renoise.Sample.LOOP_MODE_OFF] = 0
  modes[renoise.Sample.LOOP_MODE_FORWARD] = 1
  modes[renoise.Sample.LOOP_MODE_REVERSE] = 1     -- AIFF has no reverse loop
  modes[renoise.Sample.LOOP_MODE_PING_PONG] = 2

  local ls = math.floor((sample.loop_start - 1) * scale) + 1
  local le = math.floor((sample.loop_end - 1) * scale) + 1
  return {
    base_note = sample.sample_mapping.base_note,
    low_note = sample.sample_mapping.note_range[1],
    high_note = sample.sample_mapping.note_range[2],
    loop_mode = modes[sample.loop_mode] or 0,
    loop_start = math.max(1, math.min(out_frames, ls)),
    loop_end = math.max(1, math.min(out_frames, le)),
  }
end

--------------------------------------------------------------------------------
-- Preference-backed settings
--------------------------------------------------------------------------------

function PakettiDWVWTargetRate()
  if preferences and preferences.pakettiDWVWSampleRate then
    local r = preferences.pakettiDWVWSampleRate.value
    -- 0 is a real setting: "keep the sample's own rate".
    if r and r >= 0 then return r end
  end
  return 33333
end

function PakettiDWVWWordSize()
  if preferences and preferences.pakettiDWVWWordSize then
    local w = preferences.pakettiDWVWWordSize.value
    if w == 8 or w == 12 or w == 16 then return w end
  end
  return 12
end

function PakettiDWVWForceMono()
  if preferences and preferences.pakettiDWVWForceMono then
    return preferences.pakettiDWVWForceMono.value and true or false
  end
  return true
end

--------------------------------------------------------------------------------
-- Import
--------------------------------------------------------------------------------

local dwvw_import_slicer = nil

local function dwvw_import_process(path, into_current_instrument)
  local dialog, dvb = nil, nil
  local slicer = dwvw_import_slicer
  if slicer then dialog, dvb = slicer:create_dialog("Paketti DWVW Import") end

  local ok, err = pcall(function()
    if dvb then dvb.views.progress_text.text = "Reading " .. basename(path) .. "..." end
    coroutine.yield()

    local data = read_whole_file(path)
    local info = PakettiDWVWParseFile(data, 4096)

    if dvb then dvb.views.progress_text.text = "Building sample..." end
    coroutine.yield()

    local song = renoise.song()
    if not into_current_instrument then
      song.selected_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(song.selected_instrument_index)
      pakettiPreferencesDefaultInstrumentLoader()
    end

    local instrument = song.selected_instrument
    if #instrument.samples < 1 then instrument:insert_sample_at(1) end
    local sample = instrument.samples[1]

    local scale = 2 ^ (info.wordsize - 1)
    sample.sample_buffer:create_sample_data(
      info.rate > 0 and info.rate or PakettiDWVWTargetRate(),
      (info.wordsize <= 16) and 16 or 32,
      info.nchannels, info.nsamples)
    sample.sample_buffer:prepare_sample_data_changes()
    for c = 1, info.nchannels do
      local ints = info.channels[c]
      for i = 1, info.nsamples do
        sample.sample_buffer:set_sample_data(c, i, ints[i] / scale)
        if i % 8192 == 0 then
          if dvb then
            dvb.views.progress_text.text = string.format(
              "Writing channel %d/%d: %d%%", c, info.nchannels,
              floor(i / info.nsamples * 100))
          end
          coroutine.yield()
        end
      end
    end
    sample.sample_buffer:finalize_sample_data_changes()

    sample.name = strip_extension(basename(path))
    instrument.name = sample.name

    -- Root note and loop points, when the file carries an INST/MARK pair.
    if info.base_note and info.base_note >= 0 and info.base_note <= 119 then
      sample.sample_mapping.base_note = info.base_note
    end
    if info.loop_start and info.loop_end and info.loop_end > info.loop_start then
      local ls = math.max(1, math.min(info.nsamples, info.loop_start))
      local le = math.max(ls + 1, math.min(info.nsamples, info.loop_end))
      sample.loop_start = ls
      sample.loop_end = le
      local modes = {
        [0] = renoise.Sample.LOOP_MODE_OFF,
        [1] = renoise.Sample.LOOP_MODE_FORWARD,
        [2] = renoise.Sample.LOOP_MODE_PING_PONG,
      }
      sample.loop_mode = modes[info.loop_mode or 0] or renoise.Sample.LOOP_MODE_OFF
      print(string.format("PakettiDWVW: loop %d-%d, mode %d, base note %s",
        ls, le, info.loop_mode or 0, tostring(info.base_note)))
    end

    renoise.app():show_status(string.format(
      "Paketti DWVW: imported %s (%d frames, %d ch, %d-bit, %d Hz)",
      basename(path), info.nsamples, info.nchannels, info.wordsize, info.rate))
    print(string.format("PakettiDWVW: imported %s - %d frames, %d channels, %d-bit, %d Hz",
      path, info.nsamples, info.nchannels, info.wordsize, info.rate))
  end)

  if dialog and dialog.visible then dialog:close() end
  dwvw_import_slicer = nil

  PakettiDWVWLastStatus = ok and "import ok" or ("import failed: " .. tostring(err))
  if not ok then
    renoise.app():show_status("Paketti DWVW import failed: " .. tostring(err))
    print("PakettiDWVW import error: " .. tostring(err))
  end
end

function PakettiDWVWImportFile(path, into_current_instrument)
  if not path or path == "" then return false end
  if dwvw_import_slicer and dwvw_import_slicer:running() then
    renoise.app():show_status("Paketti DWVW: an import is already running")
    return false
  end
  dwvw_import_slicer = ProcessSlicer(function()
    dwvw_import_process(path, into_current_instrument)
  end)
  dwvw_import_slicer:start()
  return true
end

function PakettiDWVWImportDialog()
  local path = renoise.app():prompt_for_filename_to_read(
    {"*.C01", "*.c01", "*.dwvw", "*.aifc", "*.aif", "*.aiff", "*.*"},
    "Paketti: Import DWVW Sample")
  if not path or path == "" then
    renoise.app():show_status("Paketti DWVW: no file selected")
    return
  end
  PakettiDWVWImportFile(path)
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

local dwvw_export_slicer = nil

local function dwvw_export_process(path, target_rate, force_mono, wordsize)
  local dialog, dvb = nil, nil
  local slicer = dwvw_export_slicer
  if slicer then dialog, dvb = slicer:create_dialog("Paketti DWVW Export") end

  local ok, err = pcall(function()
    local sample = renoise.song().selected_sample
    local buffer = sample.sample_buffer

    if dvb then
      dvb.views.progress_text.text = (target_rate > 0)
        and ("Resampling to " .. target_rate .. " Hz...") or "Reading sample..."
    end
    coroutine.yield()

    if target_rate <= 0 then target_rate = buffer.sample_rate end

    local channels, frames, nch =
      PakettiDWVWBufferToChannels(buffer, target_rate, force_mono, wordsize, 8192)

    if dvb then dvb.views.progress_text.text = "Encoding DWVW..." end
    coroutine.yield()

    local data = PakettiDWVWBuildFile(channels, frames, target_rate, wordsize, 8192,
      PakettiDWVWSampleMeta(sample, buffer, frames))
    write_whole_file(path, data)
    if frames > PAKETTI_DWVW_MAX_FRAMES then
      renoise.app():show_status(string.format(
        "Paketti DWVW: %d frames exceeds the TX16W's %d-frame limit - the sampler will not load this",
        frames, PAKETTI_DWVW_MAX_FRAMES))
    end

    local src_bytes = buffer.number_of_frames * buffer.number_of_channels * 2
    renoise.app():show_status(string.format(
      "Paketti DWVW: wrote %s (%d frames, %d ch, %d-bit, %d Hz, %.1f%% of 16-bit source)",
      basename(path), frames, nch, wordsize, target_rate,
      src_bytes > 0 and (#data / src_bytes * 100) or 0))
    print(string.format("PakettiDWVW: exported %s - %d frames, %d channels, %d-bit, %d Hz, %d bytes",
      path, frames, nch, wordsize, target_rate, #data))
  end)

  if dialog and dialog.visible then dialog:close() end
  dwvw_export_slicer = nil

  PakettiDWVWLastStatus = ok and "export ok" or ("export failed: " .. tostring(err))
  if not ok then
    renoise.app():show_status("Paketti DWVW export failed: " .. tostring(err))
    print("PakettiDWVW export error: " .. tostring(err))
  end
end

function PakettiDWVWExportSelectedSample()
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Paketti DWVW: no sample data in the selected sample slot")
    return
  end
  if dwvw_export_slicer and dwvw_export_slicer:running() then
    renoise.app():show_status("Paketti DWVW: an export is already running")
    return
  end

  local suggested = PakettiDWVWDosName(
    strip_extension(sample.name ~= "" and sample.name or "Sample"), {})
  local path = renoise.app():prompt_for_filename_to_write(
    "C01", "Paketti: Export DWVW (suggested TX16W name: " .. suggested .. ")")
  if not path or path == "" then
    renoise.app():show_status("Paketti DWVW: export cancelled")
    return
  end
  if not path:lower():match("%.c%d%d$") and not path:lower():match("%.dwvw$") then
    path = strip_extension(path) .. ".C01"
  end

  dwvw_export_slicer = ProcessSlicer(function()
    dwvw_export_process(path, PakettiDWVWTargetRate(), PakettiDWVWForceMono(), PakettiDWVWWordSize())
  end)
  dwvw_export_slicer:start()
end

--------------------------------------------------------------------------------
-- Batch convert a folder of WAV/AIFF into .C01
--------------------------------------------------------------------------------

local dwvw_batch_slicer = nil

local function collect_audio_files(folder, recursive)
  local files = {}
  local seen = {}
  local exts = {"wav", "aif", "aiff", "aifc", "flac", "ogg", "snd"}

  local function add(p)
    if not seen[p] then seen[p] = true ; files[#files + 1] = p end
  end

  if recursive then
    local command
    if path_sep() == "\\" then
      command = string.format('dir "%s" /b /s', folder:gsub('"', '\\"'))
    else
      command = string.format("find '%s' -type f", folder:gsub("'", "'\\''"))
    end
    local handle = io.popen(command)
    if handle then
      for line in handle:lines() do
        local lower = line:lower()
        for _, e in ipairs(exts) do
          if lower:match("%." .. e .. "$") then add(line) break end
        end
      end
      handle:close()
    end
  else
    local patterns = {}
    for _, e in ipairs(exts) do patterns[#patterns + 1] = "*." .. e end
    -- os.filenames matches case-insensitively, so .WAV and .Aiff are covered.
    local ok, names = pcall(os.filenames, folder, patterns)
    if ok and names then
      for _, n in ipairs(names) do
        add(folder .. (folder:match("[/\\]$") and "" or path_sep()) .. n)
      end
    end
  end

  table.sort(files)
  return files
end

local function dwvw_batch_process(folder, outfolder, opts)
  local dialog, dvb = nil, nil
  local slicer = dwvw_batch_slicer
  if slicer then dialog, dvb = slicer:create_dialog("Paketti DWVW Batch Convert") end

  local song = renoise.song()
  local files = collect_audio_files(folder, opts.recursive)
  local done, failed, oversize = 0, 0, 0
  local used_names = {}

  if #files == 0 then
    if dialog and dialog.visible then dialog:close() end
    dwvw_batch_slicer = nil
    renoise.app():show_status("Paketti DWVW: no WAV/AIFF files found in " .. folder)
    return
  end

  print(string.format("PakettiDWVW: batch converting %d file(s) from %s at %s, %d-bit, %s",
    #files, folder, (opts.rate > 0) and (opts.rate .. " Hz") or "each file's own rate",
    opts.wordsize, opts.force_mono and "mono" or "source channels"))

  -- One scratch instrument is created up front and reused for every file, then
  -- removed at the end, so the user's instrument list is left as it was.
  local scratch_index = #song.instruments + 1
  song:insert_instrument_at(scratch_index)

  for n, file in ipairs(files) do
    if slicer and slicer:was_cancelled() then break end

    if dvb then
      dvb.views.progress_text.text = string.format(
        "%d/%d  %s", n, #files, basename(file))
    end
    coroutine.yield()

    local ok, err = pcall(function()
      local instrument = song.instruments[scratch_index]
      while #instrument.samples > 0 do instrument:delete_sample_at(1) end
      instrument:insert_sample_at(1)
      local buffer = instrument.samples[1].sample_buffer
      if not buffer:load_from(file) then
        error("Renoise could not read this file")
      end

      local rate = (opts.rate > 0) and opts.rate or buffer.sample_rate
      local channels, frames, nch =
        PakettiDWVWBufferToChannels(buffer, rate, opts.force_mono, opts.wordsize, 8192)
      local data = PakettiDWVWBuildFile(channels, frames, rate, opts.wordsize, 8192,
        PakettiDWVWSampleMeta(instrument.samples[1], buffer, frames))

      local outname
      if opts.dos_names == false then
        outname = strip_extension(basename(file)) .. ".C01"
      else
        outname = PakettiDWVWDosName(strip_extension(basename(file)), used_names)
      end
      local target = outfolder .. (outfolder:match("[/\\]$") and "" or path_sep())
        .. outname
      write_whole_file(target, data)
      if frames > PAKETTI_DWVW_MAX_FRAMES then oversize = oversize + 1 end
      print(string.format("PakettiDWVW: %s -> %s (%d frames, %d ch, %d bytes)%s",
        basename(file), basename(target), frames, nch, #data,
        (frames > PAKETTI_DWVW_MAX_FRAMES) and "  [TOO LONG FOR TX16W]" or ""))
    end)

    if ok then done = done + 1 else
      failed = failed + 1
      print(string.format("PakettiDWVW: FAILED %s - %s", basename(file), tostring(err)))
    end
  end

  if song.instruments[scratch_index] then
    song:delete_instrument_at(scratch_index)
  end

  if dialog and dialog.visible then dialog:close() end
  local cancelled = slicer and slicer:was_cancelled()
  dwvw_batch_slicer = nil

  local msg = string.format("Paketti DWVW batch%s: %d converted, %d failed (%s, %d-bit)%s",
    cancelled and " (cancelled)" or "", done, failed,
    (opts.rate > 0) and (opts.rate .. " Hz") or "each sample's own rate", opts.wordsize,
    (oversize > 0) and string.format(" - %d too long for the TX16W (over %d frames)",
      oversize, PAKETTI_DWVW_MAX_FRAMES) or "")
  PakettiDWVWLastStatus = msg
  renoise.app():show_status(msg)
  print(msg)
end

-- Starts a batch run. opts = {rate, wordsize, force_mono, recursive}; any
-- missing field falls back to the saved preference.
function PakettiDWVWBatchConvert(folder, outfolder, opts)
  if not folder or folder == "" then
    renoise.app():show_status("Paketti DWVW: no source folder given")
    return false
  end
  if dwvw_batch_slicer and dwvw_batch_slicer:running() then
    renoise.app():show_status("Paketti DWVW: a batch conversion is already running")
    return false
  end
  opts = opts or {}
  local resolved = {
    rate = (opts.rate ~= nil) and opts.rate or PakettiDWVWTargetRate(),
    wordsize = opts.wordsize or PakettiDWVWWordSize(),
    force_mono = (opts.force_mono ~= nil) and opts.force_mono or PakettiDWVWForceMono(),
    recursive = opts.recursive or false,
    dos_names = (opts.dos_names ~= false),
  }
  local dst = (outfolder and outfolder ~= "") and outfolder or folder
  dwvw_batch_slicer = ProcessSlicer(function()
    dwvw_batch_process(folder, dst, resolved)
  end)
  dwvw_batch_slicer:start()
  return true
end

local dwvw_batch_dialog = nil

function PakettiDWVWBatchConvertDialog()
  if dwvw_batch_dialog and dwvw_batch_dialog.visible then
    dwvw_batch_dialog:close()
    dwvw_batch_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local rates = {"33333 Hz (TX16W standard)", "50000 Hz (TX16W high rate)",
                 "20008 Hz (TX16W low rate)", "16666 Hz (TX16W half rate)",
                 "44100 Hz", "22050 Hz", "8000 Hz",
                 "Keep each sample's own rate (no resampling)"}
  local rate_values = {33333, 50000, 20008, 16666, 44100, 22050, 8000, 0}
  local rate_index = 1
  for i, r in ipairs(rate_values) do
    if r == PakettiDWVWTargetRate() then rate_index = i end
  end
  local depths = {"12-bit (TX16W native)", "8-bit", "16-bit"}
  local depth_values = {12, 8, 16}
  local depth_index = 1
  for i, d in ipairs(depth_values) do
    if d == PakettiDWVWWordSize() then depth_index = i end
  end

  local source_folder, output_folder = "", ""

  local content = vb:column{
    margin = 10, spacing = 4,

    vb:row{
      vb:text{text = "Source Folder", width = 90},
      vb:textfield{id = "src", width = 320, text = "", edit_mode = false},
      vb:button{text = "Browse", width = 60, notifier = function()
        local p = renoise.app():prompt_for_path("Folder of WAV/AIFF files to convert to DWVW")
        if p and p ~= "" then
          source_folder = p
          vb.views.src.text = p
          if vb.views.dst.text == "" then
            output_folder = p
            vb.views.dst.text = p
          end
        end
      end},
    },
    vb:row{
      vb:text{text = "Output Folder", width = 90},
      vb:textfield{id = "dst", width = 320, text = "", edit_mode = false},
      vb:button{text = "Browse", width = 60, notifier = function()
        local p = renoise.app():prompt_for_path("Where to write the .C01 files")
        if p and p ~= "" then output_folder = p ; vb.views.dst.text = p end
      end},
    },
    vb:row{
      vb:text{text = "Sample Rate", width = 90},
      vb:popup{id = "rate", items = rates, value = rate_index, width = 200,
        notifier = function(v)
          if preferences and preferences.pakettiDWVWSampleRate then
            preferences.pakettiDWVWSampleRate.value = rate_values[v]
            preferences:save_as("preferences.xml")
          end
        end},
    },
    vb:row{
      vb:text{text = "Bit Depth", width = 90},
      vb:popup{id = "depth", items = depths, value = depth_index, width = 200,
        notifier = function(v)
          if preferences and preferences.pakettiDWVWWordSize then
            preferences.pakettiDWVWWordSize.value = depth_values[v]
            preferences:save_as("preferences.xml")
          end
        end},
    },
    vb:row{
      vb:text{text = "", width = 90},
      vb:checkbox{id = "mono", value = PakettiDWVWForceMono(), notifier = function(v)
        if preferences and preferences.pakettiDWVWForceMono then
          preferences.pakettiDWVWForceMono.value = v
          preferences:save_as("preferences.xml")
        end
      end},
      vb:text{text = "Mix to mono (TX16W is mono)", width = 220},
    },
    vb:row{
      vb:text{text = "", width = 90},
      vb:checkbox{id = "recursive", value = false},
      vb:text{text = "Include subfolders", width = 220},
    },
    vb:row{
      vb:text{text = "", width = 90},
      vb:checkbox{id = "dosnames", value = true},
      vb:text{text = "TX16W-safe 8.3 filenames (KICK_01.C01)", width = 260},
    },

    vb:row{
      vb:text{text = "", width = 90},
      vb:button{text = "Convert Folder to DWVW", width = 200, notifier = function()
        if source_folder == "" then
          renoise.app():show_status("Paketti DWVW: pick a source folder first")
          return
        end
        if output_folder == "" then output_folder = source_folder end
        if dwvw_batch_slicer and dwvw_batch_slicer:running() then
          renoise.app():show_status("Paketti DWVW: a batch conversion is already running")
          return
        end
        local opts = {
          rate = rate_values[vb.views.rate.value],
          wordsize = depth_values[vb.views.depth.value],
          force_mono = vb.views.mono.value,
          recursive = vb.views.recursive.value,
          dos_names = vb.views.dosnames.value,
        }
        local src, dst = source_folder, output_folder
        if dwvw_batch_dialog and dwvw_batch_dialog.visible then dwvw_batch_dialog:close() end
        dwvw_batch_dialog = nil
        PakettiDWVWBatchConvert(src, dst, opts)
      end},
      vb:button{text = "Close", width = 60, notifier = function()
        if dwvw_batch_dialog and dwvw_batch_dialog.visible then dwvw_batch_dialog:close() end
        dwvw_batch_dialog = nil
      end},
    },
  }

  dwvw_batch_dialog = renoise.app():show_custom_dialog(
    "Paketti Batch Convert to DWVW", content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- One-shot: convert a folder straight to .C01 using the saved preferences.
function PakettiDWVWBatchConvertFolder()
  local folder = renoise.app():prompt_for_path("Folder of WAV/AIFF files to convert to DWVW")
  if not folder or folder == "" then
    renoise.app():show_status("Paketti DWVW: no folder selected")
    return
  end
  PakettiDWVWBatchConvert(folder, folder, nil)
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Export DWVW Sample (.C01)...", invoke = PakettiDWVWExportSelectedSample}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Batch Convert WAV/AIFF to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Batch Convert Folder to DWVW (.C01) with Saved Settings...", invoke = PakettiDWVWBatchConvertFolder}

PakettiAddMenuEntry{name = "Sample Editor:Paketti:Load:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Export DWVW Sample (.C01)...", invoke = PakettiDWVWExportSelectedSample}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Batch Convert WAV/AIFF to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Batch Convert Folder to DWVW (.C01) with Saved Settings...", invoke = PakettiDWVWBatchConvertFolder}

PakettiAddMenuEntry{name = "Sample Navigator:Paketti:Load:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Sample Navigator:Paketti:Export:Export DWVW Sample (.C01)...", invoke = PakettiDWVWExportSelectedSample}

PakettiAddMenuEntry{name = "Sample Mappings:Paketti:Load:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Sample Mappings:Paketti:Save:Export DWVW Sample (.C01)...", invoke = PakettiDWVWExportSelectedSample}

PakettiAddMenuEntry{name = "Instrument Box:Paketti:Load:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Load:Batch Convert WAV/AIFF to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export DWVW Sample (.C01)...", invoke = PakettiDWVWExportSelectedSample}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Batch Convert WAV/AIFF to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Batch Convert Folder to DWVW (.C01) with Saved Settings...", invoke = PakettiDWVWBatchConvertFolder}

PakettiAddMenuEntry{name = "Disk Browser Files:Paketti:Import/Export:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
PakettiAddMenuEntry{name = "Disk Browser Files:Paketti:Import/Export:Batch Convert WAV/AIFF to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}

PakettiAddMenuEntry{name = "Disk Browser:Paketti:Batch Convert Folder to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}
PakettiAddMenuEntry{name = "Disk Browser:Paketti:Batch Convert Folder to DWVW (.C01) with Saved Settings...", invoke = PakettiDWVWBatchConvertFolder}

renoise.tool():add_keybinding{name = "Global:Paketti:Import DWVW Sample (.C01)...", invoke = PakettiDWVWImportDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Export DWVW Sample (.C01)...", invoke = PakettiDWVWExportSelectedSample}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Convert WAV/AIFF to DWVW (.C01)...", invoke = PakettiDWVWBatchConvertDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Convert Folder to DWVW with Saved Settings", invoke = PakettiDWVWBatchConvertFolder}

renoise.tool():add_midi_mapping{name = "Paketti:Import DWVW Sample (.C01)", invoke = function(message) if message:is_trigger() then PakettiDWVWImportDialog() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Export DWVW Sample (.C01)", invoke = function(message) if message:is_trigger() then PakettiDWVWExportSelectedSample() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Batch Convert WAV/AIFF to DWVW (.C01)", invoke = function(message) if message:is_trigger() then PakettiDWVWBatchConvertDialog() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Batch Convert Folder to DWVW with Saved Settings", invoke = function(message) if message:is_trigger() then PakettiDWVWBatchConvertFolder() end end}

-- File import hook: dropping a TX16W .C01 (or a .dwvw) into Renoise imports it.
local function dwvw_import_hook(filename)
  PakettiDWVWImportFile(filename)
  return true
end

-- Renoise matches import-hook extensions CASE-SENSITIVELY, and real TX16W
-- files are named .C01 (uppercase), so both cases have to be registered or
-- drag-and-drop silently does nothing.
local dwvw_extensions = {"dwvw", "DWVW"}
for n = 1, 99 do
  local nn = string.format("%02d", n)
  dwvw_extensions[#dwvw_extensions + 1] = "c" .. nn
  dwvw_extensions[#dwvw_extensions + 1] = "C" .. nn
end

local function dwvw_hooks_enabled()
  if not preferences then return true end
  if preferences.pakettiImportHooksEnabled and not preferences.pakettiImportHooksEnabled.value then
    return false
  end
  if preferences.pakettiImportDWVW and not preferences.pakettiImportDWVW.value then
    return false
  end
  return true
end

if dwvw_hooks_enabled() then
  if not renoise.tool():has_file_import_hook("sample", dwvw_extensions) then
    renoise.tool():add_file_import_hook{
      name = "DWVW (TX16W/Typhoon) -> Sample",
      category = "sample",
      extensions = dwvw_extensions,
      invoke = dwvw_import_hook
    }
  end
end
