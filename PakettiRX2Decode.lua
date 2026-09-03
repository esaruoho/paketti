--[[============================================================================
PakettiRX2Decode.lua — the REX2 audio codec ("DWOP") in pure Lua

REX2 stores its PCM with a lossless predictive codec. Paketti has always needed
an external binary for this: a native decoder on macOS and Windows, and on Linux
the *Windows* one under Wine, which blocks Renoise's UI thread and often is not
installed at all. This decodes it directly.

How the codec works, since it is documented nowhere:

  * A bit stream read from 32-bit big-endian words, MSB first.
  * Five predictors of increasing order run in parallel, each keeping a delta
    history. Per sample the decoder picks whichever predictor currently has the
    smallest running average error — so the choice is implicit and costs no bits.
  * Each running average is updated as a leaky integrator:
    `avg += |delta| - avg/32`.
  * The residual is Golomb-like: a unary prefix counted in units of `step`
    (derived from the winning average), then `rbits` binary digits, with `rbits`
    adapted up or down as the signal gets louder or quieter, plus one extra bit
    when the remainder crosses a threshold.
  * Sign is folded into the low bit: `signed = -(v & 1) ^ v`.
  * Everything is carried at double amplitude and halved on output, which is how
    stereo works: the left channel is stored plainly and the right is a
    difference, recovered as `(left + delta) >> 1`.

Lua has no integers, so the 32-bit semantics are explicit throughout: the bit
reader keeps its words as plain numbers under 2^32 and shifts by multiplying and
dividing, while the predictor state uses `bit.tobit` to wrap exactly as int32
would. Getting either wrong yields audio that sounds almost right, which is why
this is verified sample-for-sample against reference PCM rather than by ear.
============================================================================]]--

local tobit, band, bxor, arshift = bit.tobit, bit.band, bit.bxor, bit.arshift
local floor = math.floor

local TWO32 = 4294967296
local TWO31 = 2147483648

--------------------------------------------------------------------------------
-- Bit reader: 32-bit big-endian words, most significant bit first
--------------------------------------------------------------------------------

local BitReader = {}
BitReader.__index = BitReader

local function new_bit_reader(data)
  local words = {}
  local n = floor(#data / 4)
  for i = 1, n do
    local p = (i - 1) * 4 + 1
    local a, b, c, d = data:byte(p, p + 3)
    words[i] = ((a * 256 + b) * 256 + c) * 256 + d
  end
  return setmetatable(
    { words = words, count = n, pos = 1, current = 0, bits_left = 0, eof = false },
    BitReader)
end

function BitReader:read_bit()
  self.bits_left = self.bits_left - 1
  if self.bits_left < 0 then
    if self.pos > self.count then self.eof = true return false end
    self.current = self.words[self.pos]
    self.pos = self.pos + 1
    self.bits_left = 31
  end
  local set = self.current >= TWO31
  self.current = (self.current * 2) % TWO32
  return set
end

function BitReader:read_bits(n)
  if n <= 0 or n > 31 then self.eof = true return 0 end
  local result = floor(self.current / 2 ^ (32 - n))
  self.current = (self.current * 2 ^ n) % TWO32
  local before = self.bits_left
  self.bits_left = self.bits_left - n
  if before - n < 0 then
    if self.pos > self.count then self.eof = true return result end
    local nxt = self.words[self.pos]
    self.pos = self.pos + 1
    self.bits_left = self.bits_left + 32
    local bl = self.bits_left
    result = result + floor(nxt / 2 ^ bl)
    self.current = (bl == 0) and 0 or ((nxt * 2 ^ (32 - bl)) % TWO32)
  end
  return result
end

--------------------------------------------------------------------------------
-- Predictor bank
--------------------------------------------------------------------------------

--- |v| for an int32, the branchless way the codec does it
local function mag(v)
  local m = bxor(v, arshift(v, 31))
  if m < 0 then m = m + TWO32 end
  return m
end

--- Advance the winning predictor and roll the delta history.
local function apply_predictor(idx, s2x, d)
  if idx == 0 then
    local t0 = tobit(s2x - d[1])
    local t1 = tobit(t0 - d[2])
    local t2 = tobit(t1 - d[3])
    d[5] = tobit(t2 - d[4]); d[4] = t2; d[3] = t1; d[2] = t0; d[1] = s2x
    return s2x
  elseif idx == 1 then
    local t1 = tobit(s2x - d[2])
    local t2 = tobit(t1 - d[3])
    local n0 = tobit(d[1] + s2x)
    d[5] = tobit(t2 - d[4]); d[4] = t2; d[3] = t1; d[2] = s2x; d[1] = n0
    return n0
  elseif idx == 2 then
    local n1 = tobit(d[2] + s2x)
    local n0 = tobit(d[1] + n1)
    local t = tobit(s2x - d[3])
    d[5] = tobit(t - d[4]); d[4] = t; d[3] = s2x; d[2] = n1; d[1] = n0
    return n0
  elseif idx == 3 then
    local n2 = tobit(d[3] + s2x)
    local n1 = tobit(d[2] + n2)
    local n0 = tobit(d[1] + n1)
    d[5] = tobit(s2x - d[4]); d[4] = s2x; d[3] = n2; d[2] = n1; d[1] = n0
    return n0
  elseif idx == 4 then
    local n3 = tobit(d[4] + s2x)
    local n2 = tobit(d[3] + n3)
    local n1 = tobit(d[2] + n2)
    local n0 = tobit(d[1] + n1)
    d[5] = s2x; d[4] = n3; d[3] = n2; d[2] = n1; d[1] = n0
    return n0
  end
  return d[1]
end

--- `j` is the current binary-part span and `rbits` its width; both track `step`.
local function adjust_j_rbits(state, step)
  local j, rbits = state.j, state.rbits
  if step < j then
    local jt = floor(j / 2)
    while step < jt do
      j = jt
      rbits = rbits - 1
      jt = floor(j / 2)
    end
  else
    while step >= j do
      local prev = j
      j = (j * 2) % TWO32
      rbits = rbits + 1
      if j <= prev then j = prev break end
    end
  end
  state.j, state.rbits = j, rbits
end

--------------------------------------------------------------------------------
-- One sample
--------------------------------------------------------------------------------

local function decode_frame(r, state)
  local a = state.avg
  local min_avg, min_idx = a[1], 0
  if a[2] < min_avg then min_avg = a[2]; min_idx = 1 end
  if a[3] < min_avg then min_avg = a[3]; min_idx = 2 end
  if a[4] < min_avg then min_avg = a[4]; min_idx = 3 end
  if a[5] < min_avg then min_avg = a[5]; min_idx = 4 end

  local step = floor((((min_avg * 3) % TWO32 + 36) % TWO32) / 128)

  -- unary prefix, counted in units of `step`, widening every seven zeros
  local prefix, zeros_win = 0, 7
  while true do
    local set = r:read_bit()
    if r.eof then return nil end
    if set then break end
    if step > 0 and prefix > (TWO32 - 1 - step) then r.eof = true return nil end
    prefix = prefix + step
    zeros_win = zeros_win - 1
    if zeros_win == 0 then
      step = (step * 4) % TWO32
      zeros_win = 7
    end
  end

  adjust_j_rbits(state, step)

  local rem = 0
  if state.rbits > 0 then
    rem = r:read_bits(state.rbits)
    if r.eof then return nil end
  end

  local thresh = state.j - step
  if rem - thresh >= 0 then
    local extra = r:read_bits(1)
    if r.eof then return nil end
    rem = rem * 2 - thresh + extra
  end

  local code = (rem + prefix) % TWO32
  -- fold the sign out of the low bit
  local signed2x = bxor(tobit(-(code % 2)), tobit(code))

  local s2x = apply_predictor(min_idx, signed2x, state.d)

  local d = state.d
  a[1] = (a[1] + mag(d[1]) - floor(a[1] / 32)) % TWO32
  a[2] = (a[2] + mag(d[2]) - floor(a[2] / 32)) % TWO32
  a[3] = (a[3] + mag(d[3]) - floor(a[3] / 32)) % TWO32
  a[4] = (a[4] + mag(d[4]) - floor(a[4] / 32)) % TWO32
  a[5] = (a[5] + mag(d[5]) - floor(a[5] / 32)) % TWO32

  return s2x
end

local function new_channel_state()
  return { d = { 0, 0, 0, 0, 0 }, avg = { 2560, 2560, 2560, 2560, 2560 },
           j = 2, rbits = 0 }
end

local function clamp_sample(v, bit_depth)
  local hi, lo = 32767, -32768
  if bit_depth == 24 then hi, lo = 8388607, -8388608 end
  if v > hi then return hi end
  if v < lo then return lo end
  return v
end

--------------------------------------------------------------------------------
-- Whole-stream decode
--------------------------------------------------------------------------------

--- Decode `frames` of DWOP data. Returns an array of interleaved samples, or
--- nil plus how many frames were recovered before the stream ran out.
--- `yield_fn`, if given, is called every 4096 frames.
function PakettiRX2DecodeDWOP(data, frames, channels, bit_depth, yield_fn)
  local r = new_bit_reader(data)
  local out = {}
  local n = 0

  if channels == 1 then
    local st = new_channel_state()
    for f = 1, frames do
      local s2x = decode_frame(r, st)
      if not s2x then return nil, f - 1, out end
      n = n + 1
      out[n] = clamp_sample(arshift(s2x, 1), bit_depth)
      if yield_fn and f % 4096 == 0 then yield_fn(f, frames) end
    end
  else
    local st0, st1 = new_channel_state(), new_channel_state()
    for f = 1, frames do
      local l = decode_frame(r, st0)
      if not l then return nil, f - 1, out end
      local rdelta = decode_frame(r, st1)
      if not rdelta then return nil, f - 1, out end
      out[n + 1] = clamp_sample(arshift(l, 1), bit_depth)
      -- the second channel is stored as a difference from the first
      out[n + 2] = clamp_sample(floor((l + rdelta) / 2), bit_depth)
      n = n + 2
      if yield_fn and f % 4096 == 0 then yield_fn(f, frames) end
    end
  end

  return out
end

--- Decode a whole .rx2 file to interleaved samples, using the container reader
--- to find the audio chunk. Returns samples, info.
function PakettiRX2DecodeFile(path, yield_fn)
  local info, err = PakettiRX2ReadInfo(path)
  if not info then return nil, err end
  if not info.audio_offset then
    return nil, "no SDAT/DWOP chunk in this file"
  end

  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. path end
  local data = f:read("*a")
  f:close()

  local payload = data:sub(info.audio_offset, info.audio_offset + info.audio_bytes - 1)
  local pcm, got = PakettiRX2DecodeDWOP(
    payload, info.total_frames, info.channels, info.bit_depth, yield_fn)
  if not pcm then
    return nil, string.format("the audio stream ended after %d of %d frames",
      got or 0, info.total_frames)
  end
  return pcm, info
end

--------------------------------------------------------------------------------
-- Importing
--
-- The decoded stream is written as a WAV and handed to Renoise, then the
-- container's slice positions are placed as markers. Those positions and this
-- audio share a timeline, which the external-decoder path does not: that decoder
-- renders the loop time-stretched to a target tempo, so its markers and its audio
-- agree with each other but not with the file's own frame numbers.
--
-- The reference decoder also applies 5/6 headroom gain and starts 56 frames in.
-- Paketti keeps the raw stream instead: it is what the file contains, it lines up
-- with the slice table, and any gain is the user's to apply.
--------------------------------------------------------------------------------

local function le16(v)
  v = v % 65536
  return string.char(v % 256, math.floor(v / 256))
end

local function le32(v)
  return string.char(v % 256, math.floor(v / 256) % 256,
    math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

--- Turn decoded samples into a 16-bit RIFF WAV.
local function pcm_to_wav(pcm, channels, rate)
  local parts = {}
  local chunk = {}
  for i = 1, #pcm do
    local v = pcm[i]
    if v < 0 then v = v + 65536 end
    chunk[#chunk + 1] = string.char(v % 256, math.floor(v / 256) % 256)
    if #chunk >= 4096 then
      parts[#parts + 1] = table.concat(chunk)
      chunk = {}
    end
  end
  if #chunk > 0 then parts[#parts + 1] = table.concat(chunk) end
  local audio = table.concat(parts)

  local block_align = channels * 2
  local fmt = le16(1) .. le16(channels) .. le32(rate)
    .. le32(rate * block_align) .. le16(block_align) .. le16(16)
  local body = "WAVE" .. "fmt " .. le32(#fmt) .. fmt .. "data" .. le32(#audio) .. audio
  return "RIFF" .. le32(#body) .. body
end

--- Import a .rx2 with the built-in decoder: no external binary, any platform.
function PakettiRX2ImportNative(path, yield_fn, status_fn)
  status_fn = status_fn or function() end

  status_fn("Reading the REX container...")
  local pcm, info = PakettiRX2DecodeFile(path, function(done, total)
    status_fn(string.format("Decoding audio... %d%%", math.floor(done / total * 100)))
    if yield_fn then yield_fn() end
  end)
  if not pcm then return false, info end

  status_fn("Building the sample...")
  if yield_fn then yield_fn() end
  local wav = pcm_to_wav(pcm, info.channels, info.sample_rate)

  local tmp = os.tmpname() .. ".wav"
  local wf = io.open(tmp, "wb")
  if not wf then return false, "could not write a temporary WAV" end
  wf:write(wav)
  wf:close()

  local song = renoise.song()
  if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
    os.remove(tmp)
    return false, "could not create an instrument"
  end
  song.selected_instrument_index = song.selected_instrument_index + 1
  pakettiPreferencesDefaultInstrumentLoader()

  local instrument = song.selected_instrument
  local name = pakettiFSPath.basename(path):gsub("%.[^.]+$", "")
  instrument.name = name
  local sample = instrument.samples[1]
  local ok = pcall(function() return sample.sample_buffer:load_from(tmp) end)
  os.remove(tmp)
  if not ok or not sample.sample_buffer.has_sample_data then
    return false, "Renoise could not load the decoded audio"
  end
  sample.name = name

  local placed, last = 0, -1
  local frames = sample.sample_buffer.number_of_frames
  for _, s in ipairs(info.slices) do
    if placed >= 255 then break end
    local frame = (s.sample_start or 0) + 1
    if frame >= 1 and frame < frames and frame ~= last then
      if pcall(function() sample:insert_slice_marker(frame) end) then
        placed = placed + 1
        last = frame
      end
    end
  end

  return true, string.format("%s: %d slices, %.2fs, %d Hz %d-bit %s, %.2f BPM",
    name, placed, info.duration_seconds, info.sample_rate, info.bit_depth,
    info.channels == 2 and "stereo" or "mono", info.tempo)
end

--- Sliced version, since decoding is a per-sample loop in Lua and a long loop
--- takes seconds. Errors stay inside the worker.
function PakettiRX2ImportNativeSliced(path)
  local dialog, vb

  local slicer = ProcessSlicer(function()
    local ran, ok, msg = pcall(function()
      return PakettiRX2ImportNative(path,
        function() coroutine.yield() end,
        function(text)
          if vb and vb.views and vb.views.progress_text then
            vb.views.progress_text.text = text
          end
        end)
    end)
    if dialog and dialog.visible then dialog:close() end
    if not ran then
      renoise.app():show_error("RX2 import failed.\n\n" .. tostring(ok))
    elseif ok then
      renoise.app():show_status(msg)
      print("-- PakettiRX2ImportNative: " .. tostring(msg))
    else
      renoise.app():show_error("RX2 import failed.\n\n" .. tostring(msg))
    end
  end)

  dialog, vb = slicer:create_dialog("Decoding REX2 audio...")
  slicer:start()
end

function PakettiRX2ImportNativeDialog()
  local path = renoise.app():prompt_for_filename_to_read(
    { "*.rx2" }, "Import RX2 with Paketti's own decoder")
  if not path or path == "" then return end
  PakettiRX2ImportNativeSliced(path)
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Import:RX2 with Paketti's Own Decoder (no Wine)...",
  invoke=function() PakettiRX2ImportNativeDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import RX2 with Paketti's Own Decoder...",
  invoke=function() PakettiRX2ImportNativeDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Import RX2 with Paketti Decoder",
  invoke = function() PakettiRX2ImportNativeDialog() end }
