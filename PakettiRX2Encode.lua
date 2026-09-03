--[[============================================================================
PakettiRX2Encode.lua — write REX2 files (.rx2), audio and all

The companion to PakettiRX2Decode.lua. Paketti could read REX2 two ways and
write it none, so a Renoise break could come in from a .rx2 and never go back
out as one. This closes that: a sliced instrument becomes a real .rx2 with its
slices, tempo and DWOP-compressed audio, needing no external tool.

The codec is the decoder run backwards, and the awkward part is that it is not a
straightforward inverse. The decoder reads a unary prefix, adapts `j` and
`rbits` from the resulting `step`, then reads that many bits; the encoder has to
choose a prefix length such that the remainder it still has to send *fits* the
width that prefix will produce. So writeCodeValue searches: for each candidate
prefix it works out what `j`/`rbits` the decoder would arrive at, asks whether
the remainder can be expressed there, and only commits once it can. That is why
this is a search and not an arithmetic inverse.

Everything else mirrors the decoder exactly -- five predictors, the winner
chosen by smallest running average, sign folded into the low bit, double
amplitude throughout, the right channel carried as a difference from the left.
The predictor and average updates are literally the same functions, because any
divergence between them would produce a file that decodes to almost-right audio.

Verified by round-trip: PCM -> encode -> PakettiRX2DecodeDWOP -> compared sample
for sample against the input.

Layout of the container follows the format notes in rex2-format.txt.
============================================================================]]--

local tobit, band, bxor, arshift = bit.tobit, bit.band, bit.bxor, bit.arshift
local floor = math.floor

local TWO32 = 4294967296

--------------------------------------------------------------------------------
-- Bit writer: 32-bit big-endian words, most significant bit first
--------------------------------------------------------------------------------

local BitWriter = {}
BitWriter.__index = BitWriter

local function new_bit_writer()
  return setmetatable({ words = {}, current = 0, nbits = 0 }, BitWriter)
end

function BitWriter:write_bit(one)
  if one then
    -- current is kept as a plain number below 2^32; adding the bit's weight is
    -- the same as OR here because each position is written exactly once
    self.current = self.current + 2 ^ (31 - self.nbits)
  end
  self.nbits = self.nbits + 1
  if self.nbits == 32 then self:flush_word() end
end

function BitWriter:write_bits(value, count)
  for i = count - 1, 0, -1 do
    self:write_bit(floor(value / 2 ^ i) % 2 == 1)
  end
end

function BitWriter:flush_word()
  local v = self.current
  self.words[#self.words + 1] = string.char(
    floor(v / 16777216) % 256, floor(v / 65536) % 256,
    floor(v / 256) % 256, v % 256)
  self.current, self.nbits = 0, 0
end

function BitWriter:finish()
  if self.nbits > 0 then self:flush_word() end
  -- Every real REX2 ends its stream with one further zero word. Checked across
  -- the files to hand: each one's SDAT is exactly four bytes longer than the
  -- data needs, and those four bytes are zero. Without it the bitstream is a
  -- prefix of what ReCycle writes rather than the same file.
  self.words[#self.words + 1] = "\0\0\0\0"
  return table.concat(self.words)
end

--------------------------------------------------------------------------------
-- Predictors — the same state machine the decoder runs
--------------------------------------------------------------------------------

local function mag(v)
  local m = bxor(v, arshift(v, 31))
  if m < 0 then m = m + TWO32 end
  return m
end

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

--- Which sample value a given predictor must be fed to land on `s2x`.
--- Read straight off apply_predictor: predictor 0 stores the sample itself,
--- and each higher one subtracts one more level of the delta history.
local function predictor_residual(idx, s2x, d)
  if idx == 0 then return s2x end
  if idx == 1 then return tobit(s2x - d[1]) end
  if idx == 2 then return tobit(tobit(s2x - d[1]) - d[2]) end
  if idx == 3 then return tobit(tobit(tobit(s2x - d[1]) - d[2]) - d[3]) end
  if idx == 4 then
    return tobit(tobit(tobit(tobit(s2x - d[1]) - d[2]) - d[3]) - d[4])
  end
  return s2x
end

local function update_averages(a, d)
  a[1] = (a[1] + mag(d[1]) - floor(a[1] / 32)) % TWO32
  a[2] = (a[2] + mag(d[2]) - floor(a[2] / 32)) % TWO32
  a[3] = (a[3] + mag(d[3]) - floor(a[3] / 32)) % TWO32
  a[4] = (a[4] + mag(d[4]) - floor(a[4] / 32)) % TWO32
  a[5] = (a[5] + mag(d[5]) - floor(a[5] / 32)) % TWO32
end

--- `j`/`rbits` track `step` exactly as the decoder makes them.
local function adjust_j_rbits(j, rbits, step)
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
  return j, rbits
end

--- Fold the sign into the low bit, the inverse of `signed = -(code & 1) ~ code`.
local function to_code_value(signed2x)
  if signed2x >= 0 then return signed2x end
  return -signed2x - 1
end

--------------------------------------------------------------------------------
-- One sample
--------------------------------------------------------------------------------

--- Can `raw` be sent as the binary part, given this `step`/`j`/`rbits`?
--- Mirrors the decoder's remainder read, including the extra bit it takes when
--- the value crosses the threshold.
local function encode_remainder(raw, step, j, rbits)
  if rbits < 0 or rbits > 31 then return nil end
  local limit = (rbits == 31) and 2147483648 or 2 ^ rbits
  local thresh = j - step
  if thresh < 0 then return nil end

  if raw < thresh then
    if raw >= limit then return nil end
    return raw, false, false
  end

  local folded = raw + thresh
  local rem = floor(folded / 2)
  if rem < thresh or rem >= limit then return nil end
  return rem, true, (folded % 2 == 1)
end

--- Write one residual. The prefix length is searched rather than computed:
--- lengthening it raises `step`, which changes the `j`/`rbits` the decoder will
--- use, so the first prefix whose remainder fits is the one written.
local function write_code_value(bw, code_val, base_step, j, rbits)
  local prefix, step, zeros_win = 0, base_step, 7

  for zeros = 0, 0xFFFFF do
    if code_val >= prefix then
      local tj, tr = adjust_j_rbits(j, rbits, step)
      local rem, has_extra, extra = encode_remainder(code_val - prefix, step, tj, tr)
      if rem then
        for _ = 1, zeros do bw:write_bit(false) end
        bw:write_bit(true)
        if tr > 0 then bw:write_bits(rem, tr) end
        if has_extra then bw:write_bit(extra) end
        return tj, tr
      end
    end
    -- a zero step never advances the prefix, so there is nothing left to try
    if base_step == 0 then break end
    if (TWO32 - 1) - prefix < step then break end
    prefix = prefix + step
    if prefix > code_val and step ~= 0 then break end
    zeros_win = zeros_win - 1
    if zeros_win == 0 then
      step = (step * 4) % TWO32
      zeros_win = 7
    end
  end

  bw:write_bit(true)
  return j, rbits
end

local function new_channel_state()
  return { d = { 0, 0, 0, 0, 0 }, avg = { 2560, 2560, 2560, 2560, 2560 },
           j = 2, rbits = 0 }
end

local function encode_channel(bw, s2x, st)
  local a = st.avg
  local min_avg, min_idx = a[1], 0
  if a[2] < min_avg then min_avg = a[2]; min_idx = 1 end
  if a[3] < min_avg then min_avg = a[3]; min_idx = 2 end
  if a[4] < min_avg then min_avg = a[4]; min_idx = 3 end
  if a[5] < min_avg then min_avg = a[5]; min_idx = 4 end

  local step = floor((((min_avg * 3) % TWO32 + 36) % TWO32) / 128)
  local residual = predictor_residual(min_idx, s2x, st.d)

  st.j, st.rbits = write_code_value(bw, to_code_value(residual), step, st.j, st.rbits)

  apply_predictor(min_idx, residual, st.d)
  update_averages(a, st.d)
end

--------------------------------------------------------------------------------
-- Whole-stream compress
--------------------------------------------------------------------------------

--- samples is a flat array of interleaved integer samples.
--- Returns the DWOP byte stream. `yield_fn`, if given, is called every 4096
--- frames, so this can run under a ProcessSlicer without freezing the UI.
function PakettiRX2EncodeDWOP(samples, channels, yield_fn)
  local bw = new_bit_writer()

  if channels == 1 then
    local st = new_channel_state()
    for i = 1, #samples do
      encode_channel(bw, samples[i] * 2, st)
      if yield_fn and i % 4096 == 0 then yield_fn(i) end
    end
  else
    local l, r = new_channel_state(), new_channel_state()
    local frames = floor(#samples / 2)
    for f = 0, frames - 1 do
      local left2x = samples[f * 2 + 1] * 2
      local right2x = samples[f * 2 + 2] * 2
      encode_channel(bw, left2x, l)
      encode_channel(bw, tobit(right2x - left2x), r)
      if yield_fn and f % 4096 == 0 then yield_fn(f) end
    end
  end

  return bw:finish()
end

--------------------------------------------------------------------------------
-- Container
--------------------------------------------------------------------------------

local function be32(v)
  v = floor(v) % TWO32
  return string.char(floor(v / 16777216) % 256, floor(v / 65536) % 256,
                     floor(v / 256) % 256, v % 256)
end

local function be16(v)
  v = floor(v) % 65536
  return string.char(floor(v / 256), v % 256)
end

--- An IFF chunk: four-character id, big-endian size, body, padded to even.
local function chunk(id, body)
  return id .. be32(#body) .. body .. ((#body % 2 == 1) and "\0" or "")
end

--- A container chunk carries its type inside the size, like IFF's CAT.
local function cat(kind, body)
  return "CAT " .. be32(#body + 4) .. kind .. body
end

local function pstring(s)
  s = tostring(s or "")
  if #s > 255 then s = s:sub(1, 255) end
  return be32(#s) .. s
end

local BIT_DEPTH_CODE = { [8] = 1, [16] = 3, [24] = 5, [32] = 7 }

--- Build a complete .rx2.
---
--- info: channels, sample_rate, bit_depth, total_frames, tempo (BPM),
---       time_sig_num, time_sig_den, loop_start, loop_end
--- slices: array of { sample_start = , sample_length = }
function PakettiRX2EncodeFile(samples, info, slices, creator, yield_fn)
  info = info or {}
  slices = slices or {}
  local channels = (info.channels == 2) and 2 or 1
  local frames = info.total_frames or floor(#samples / channels)
  if frames <= 0 then return nil, "there are no frames to write" end

  local num = (info.time_sig_num and info.time_sig_num > 0) and info.time_sig_num or 4
  local den = (info.time_sig_den and info.time_sig_den > 0) and info.time_sig_den or 4

  -- REX counts musical length in PPQ; without one, assume a bar of the metre.
  local PPQ = 15360
  local ppq_total = info.ppq_length
  if not ppq_total or ppq_total <= 0 then ppq_total = PPQ * num end
  local total_beats = floor(ppq_total / PPQ)
  local bars = floor(total_beats / num)
  local beats = total_beats % num

  -- Stored as milli-BPM, and REX only accepts a musical range.
  local tempo = floor((info.tempo or 120) * 1000 + 0.5)
  if tempo < 20000 or tempo > 450000 then tempo = 120000 end

  local parts = {}
  parts[#parts + 1] = chunk("HEAD", be32(0x490cf18d) .. string.char(0xbc, 0x00))

  creator = creator or {}
  if creator.name or creator.copyright or creator.url or creator.email or creator.text then
    parts[#parts + 1] = chunk("CREI",
      pstring(creator.name) .. pstring(creator.copyright) .. pstring(creator.url)
      .. pstring(creator.email) .. pstring(creator.text))
  end

  parts[#parts + 1] = chunk("GLOB",
    be32(#slices) .. be16(bars) .. string.char(beats % 256, num % 256, den % 256, 0)
    .. be16(0) .. be16(1000) .. be16(0) .. be32(tempo) .. be16(0))

  if #slices > 0 then
    -- REX wants slices in ascending start order; a Renoise instrument's markers
    -- already are, but a caller's list may not be.
    local sorted = {}
    for i, s in ipairs(slices) do sorted[i] = s end
    table.sort(sorted, function(a, b)
      return (a.sample_start or 0) < (b.sample_start or 0)
    end)
    local slce = {}
    for _, s in ipairs(sorted) do
      slce[#slce + 1] = chunk("SLCE",
        be32(s.sample_start or 0) .. be32(s.sample_length or 0)
        .. be16(0x7fff) .. string.char(0))
    end
    parts[#parts + 1] = cat("SLCL", table.concat(slce))
  end

  parts[#parts + 1] = chunk("SINF",
    string.char(channels, BIT_DEPTH_CODE[info.bit_depth or 16] or 3)
    .. be32(info.sample_rate or 44100) .. be32(frames)
    .. be32(info.loop_start or 0) .. be32(info.loop_end or 0))

  local audio = PakettiRX2EncodeDWOP(samples, channels, yield_fn)
  parts[#parts + 1] = chunk("SDAT", audio)

  return cat("REX2", table.concat(parts))
end

--------------------------------------------------------------------------------
-- Exporting the selected instrument
--------------------------------------------------------------------------------

--- Read the selected sample's audio as a flat interleaved array, and its slice
--- markers as REX slice entries.
local function gather_instrument()
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return nil, "the selected instrument has no samples"
  end
  local sample = instrument.samples[1]
  local buf = sample.sample_buffer
  if not buf.has_sample_data then
    return nil, "the first sample of the selected instrument is empty"
  end

  local channels = math.min(2, buf.number_of_channels)
  local frames = buf.number_of_frames
  local bit_depth = buf.bit_depth
  if bit_depth ~= 8 and bit_depth ~= 16 and bit_depth ~= 24 and bit_depth ~= 32 then
    bit_depth = 16
  end
  -- REX carries integer PCM; Renoise hands out floats, so scale by the depth
  -- the file will claim rather than always by 16-bit.
  local peak = (bit_depth == 24 and 8388607) or (bit_depth == 8 and 127) or 32767

  local samples = {}
  local n = 0
  for f = 1, frames do
    for c = 1, channels do
      local v = floor(buf:sample_data(c, f) * peak + 0.5)
      if v > peak then v = peak elseif v < -peak - 1 then v = -peak - 1 end
      n = n + 1
      samples[n] = v
    end
  end

  local slices = {}
  local markers = sample.slice_markers
  if #markers > 0 then
    local bounds = {}
    bounds[1] = 0
    for i = 1, #markers do bounds[#bounds + 1] = markers[i] - 1 end
    bounds[#bounds + 1] = frames
    for i = 1, #bounds - 1 do
      slices[#slices + 1] = {
        sample_start = bounds[i],
        sample_length = bounds[i + 1] - bounds[i],
      }
    end
  else
    slices[1] = { sample_start = 0, sample_length = frames }
  end

  local info = {
    channels = channels,
    sample_rate = buf.sample_rate,
    bit_depth = bit_depth,
    total_frames = frames,
    tempo = song.transport.bpm,
    time_sig_num = 4, time_sig_den = 4,
    loop_start = 0, loop_end = 0,
  }
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    info.loop_start = math.max(0, sample.loop_start - 1)
    info.loop_end = math.max(0, sample.loop_end - 1)
  end

  return { samples = samples, info = info, slices = slices,
           name = (instrument.name ~= "" and instrument.name) or "Paketti" }
end

local rx2_export_slicer = nil

local function rx2_export_process(path)
  local dialog, dvb = nil, nil
  if rx2_export_slicer then
    dialog, dvb = rx2_export_slicer:create_dialog("Paketti RX2 Export")
  end
  local slicer = rx2_export_slicer

  local ok, err = pcall(function()
    if dvb then dvb.views.progress_text.text = "Reading the sample..." end
    coroutine.yield()

    local gathered, gerr = gather_instrument()
    if not gathered then error(gerr) end

    local total = math.floor(#gathered.samples / gathered.info.channels)
    local data, derr = PakettiRX2EncodeFile(
      gathered.samples, gathered.info, gathered.slices,
      { name = "Paketti", text = "Written by Paketti" },
      function(done)
        if slicer and slicer:was_cancelled() then error("cancelled") end
        if dvb then
          dvb.views.progress_text.text = string.format(
            "Compressing %d/%d frames...", done, total)
        end
        coroutine.yield()
      end)
    if not data then error(derr) end

    local f = io.open(path, "wb")
    if not f then error("could not write " .. path) end
    f:write(data)
    f:close()

    local msg = string.format("Paketti: wrote %s (%d slice%s, %d frames, %s, %.1f kB)",
      pakettiFSPath.basename(path), #gathered.slices,
      #gathered.slices == 1 and "" or "s", total,
      gathered.info.channels == 2 and "stereo" or "mono", #data / 1024)
    renoise.app():show_status(msg)
    print(msg)
  end)

  if dialog and dialog.visible then dialog:close() end
  rx2_export_slicer = nil
  if not ok then
    renoise.app():show_status("Paketti RX2 export failed: " .. tostring(err))
    print("PakettiRX2Encode error: " .. tostring(err))
  end
end

--- Write the selected instrument out as a .rx2.
function PakettiRX2Export(path)
  if rx2_export_slicer and rx2_export_slicer:running() then
    renoise.app():show_status("Paketti: an RX2 export is already running")
    return false
  end
  if not path or path == "" then return false end
  if not path:lower():match("%.rx2$") then path = path .. ".rx2" end
  rx2_export_slicer = ProcessSlicer(function() rx2_export_process(path) end)
  rx2_export_slicer:start()
  return true
end

function PakettiRX2ExportDialog()
  local song = renoise.song()
  if #song.selected_instrument.samples == 0 then
    renoise.app():show_status("Paketti: the selected instrument has no samples")
    return
  end
  local path = renoise.app():prompt_for_filename_to_write("rx2", "Export as REX2 (.rx2)")
  if not path or path == "" then return end
  PakettiRX2Export(path)
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:REX2 (.rx2)...",
  invoke=function() PakettiRX2ExportDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export REX2 (.rx2)...",
  invoke=function() PakettiRX2ExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Save:Export REX2 (.rx2)...",
  invoke=function() PakettiRX2ExportDialog() end}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Save:Export REX2 (.rx2)...",
  invoke=function() PakettiRX2ExportDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Export REX2",
  invoke=function() PakettiRX2ExportDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Export REX2",
  invoke=function(message) if message:is_trigger() then PakettiRX2ExportDialog() end end}
