--[[============================================================================
PakettiRX2Reader.lua — pure-Lua reader for the REX2 container

Paketti's existing .rx2 import shells out to a Windows decoder under Wine, which
blocks Renoise's UI thread and simply is not available on many machines. This
reads the container itself, in Lua, on every platform: tempo, time signature,
sample rate, bit depth, channel count, loop points, creator metadata, and the
full slice table with each slice's position, length and mute/lock state.

What it does NOT do is decode the audio. REX2 stores its PCM in a proprietary
DPCM scheme ("DWOP") built on a five-state predictor, and porting that is a
separate piece of work. So this answers "what is in this file" without Wine —
which is what slice counts, BPM detection and batch triage need — and leaves the
audio to the existing decoder path.

Structure, verified against real files:

  CAT  REX2                     an IFF container, big-endian, chunks padded to even
    HEAD   magic 490cf18d bc, version byte
    CREI   creator: name, copyright, URL, email, free text, each a u32 length + bytes
    GLOB   slice count, bars, beats, time signature, sensitivities, tempo (x1000)
    SINF   channels, bit-depth code, sample rate, frames, loop start/end
    SLCE   one per slice: sample start, length, PPQ position, flags
    SDAT / DWOP                 the compressed audio

Bit-depth codes are 1/3/5/7 for 8/16/24/32 bits. Tempo is milli-BPM. PPQ is 15360
per beat.

One thing to be careful about: slice positions here are frames in the FILE'S OWN
timeline. The Propellerhead decoder renders the loop time-stretched to a target
tempo, so its output has a different frame count and its markers sit elsewhere --
on one break, 212852 frames here against 151200 from the decoder, every marker
scaled by that same ratio. Both are right about their own timeline; they cannot be
mixed.
============================================================================]]--

local REX_PPQ = 15360

local function be_u16(d, p)
  local a, b = d:byte(p, p + 1)
  if not b then return nil end
  return a * 256 + b
end

local function be_u32(d, p)
  local a, b, c, e = d:byte(p, p + 3)
  if not e then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + e
end

--- Read every chunk of an IFF tree, calling handler(id, body, offset).
local function walk_iff(data, start_pos, stop_pos, handler)
  local pos = start_pos
  while pos + 8 <= stop_pos and pos + 8 <= #data + 1 do
    local id = data:sub(pos, pos + 3)
    local size = be_u32(data, pos + 4)
    if not size then break end
    local body_pos = pos + 8
    if body_pos + size - 1 > #data then break end

    if id == "CAT " and size >= 4 then
      -- a nested container: its first four bytes are the type, then more chunks
      walk_iff(data, body_pos + 4, body_pos + size, handler)
    else
      handler(id, data:sub(body_pos, body_pos + size - 1), body_pos)
    end

    pos = body_pos + size
    if pos % 2 == 0 then pos = pos + 1 end
  end
end

--- Parse a .rx2 / .rex / .rcy file's container. Returns a table, or nil + reason.
function PakettiRX2ReadInfo(path)
  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. tostring(path) end
  local data = f:read("*a")
  f:close()
  if not data or #data < 12 then return nil, "file is too short to be a REX file" end

  if data:sub(1, 15) == "<!DOCTYPE html>" then
    return nil, "this is an HTML page, not a REX file — the download failed"
  end
  if data:sub(1, 4) == "FORM" and data:sub(9, 12) == "AIFF" then
    return nil, "this is a legacy AIFF-based REX file, which this reader does not handle"
  end
  if data:sub(1, 4) ~= "CAT " then
    return nil, "not a REX container (no 'CAT ' signature)"
  end

  local info = {
    path = path,
    channels = 1, sample_rate = 44100, bit_depth = 16,
    tempo = 120.0, time_sig_num = 4, time_sig_den = 4,
    total_frames = 0, loop_start = 0, loop_end = 0,
    slice_count = 0, slices = {}, creator = {},
    has_audio_chunk = false, audio_bytes = 0,
  }

  local bars, beats = 0, 0

  walk_iff(data, 13, #data + 1, function(id, body, body_pos)
    if id == "SINF" and #body >= 18 then
      info.channels = body:byte(1)
      local code = body:byte(2)
      info.bit_depth = (code == 1 and 8) or (code == 3 and 16)
        or (code == 5 and 24) or (code == 7 and 32) or 16
      info.sample_rate = be_u32(body, 3) or 44100
      info.total_frames = be_u32(body, 7) or 0
      info.loop_start = be_u32(body, 11) or 0
      info.loop_end = be_u32(body, 15) or 0
      if info.channels ~= 1 and info.channels ~= 2 then info.channels = 1 end

    elseif id == "GLOB" and #body >= 22 then
      info.slice_count = be_u32(body, 1) or 0
      bars = be_u16(body, 5) or 0
      beats = body:byte(7) or 0
      info.time_sig_num = body:byte(8) or 4
      info.time_sig_den = body:byte(9) or 4
      info.analysis_sensitivity = body:byte(10)
      info.gate_sensitivity = be_u16(body, 11)
      local tempo = be_u32(body, 17)
      -- stored as milli-BPM, and REX clamps to a sane musical range
      if tempo and tempo >= 20000 and tempo <= 450000 then
        info.tempo = tempo / 1000
      end

    elseif id == "SLCE" and #body >= 10 then
      local entry = {
        sample_start = be_u32(body, 1) or 0,
        sample_length = be_u32(body, 5) or 0,
        ppq = be_u16(body, 9) or 0,
        muted = false, locked = false, selected = false,
      }
      if #body > 10 then
        local flags = body:byte(11)
        entry.selected = (bit.band(flags, 0x04) ~= 0)
        if bit.band(flags, 0x02) ~= 0 then entry.locked = true
        elseif bit.band(flags, 0x01) ~= 0 then entry.muted = true end
      end
      info.slices[#info.slices + 1] = entry

    elseif id == "CREI" then
      local off = 1
      local function read_str()
        local n = be_u32(body, off)
        if not n then return nil end
        off = off + 4
        if off + n - 1 > #body then off = #body + 1 return nil end
        local s = body:sub(off, off + n - 1)
        off = off + n
        return s
      end
      info.creator.name = read_str()
      info.creator.copyright = read_str()
      info.creator.url = read_str()
      info.creator.email = read_str()
      info.creator.text = read_str()

    elseif id == "SDAT" or id == "DWOP" then
      if not info.has_audio_chunk then
        info.has_audio_chunk = true
        info.audio_bytes = #body
        info.audio_offset = body_pos
      end
    end
  end)

  if info.total_frames == 0 then
    return nil, "no SINF chunk: the file is corrupt or not a REX2 file"
  end

  -- A REX2 file carries far more slice boundaries than ReCycle ever showed. The
  -- table is the raw analysis; which of those are real slices depends on the
  -- file's own analysis sensitivity, on whether a boundary was locked or selected
  -- by hand, and on whether it delimits an actual region. Reporting the raw count
  -- disagrees with every other tool -- one break here reads 44 raw against the 30
  -- the Propellerhead decoder produces.
  local visible = {}
  -- REX2 scales its sensitivity over 0..99; ReCycle documents use 0..1000, which
  -- is a different formula and lives in the legacy parser below.
  local sens = math.min(info.analysis_sensitivity or 0, 99)
  local threshold = 0x7FFF - math.floor((sens * 0x7FFF + 98) / 99)
  for _, sl in ipairs(info.slices) do
    local keep
    if sl.muted then keep = false
    elseif sl.sample_length and sl.sample_length > 1 then keep = true
    elseif sl.locked or sl.selected then keep = true
    else keep = (sl.ppq or 0) > threshold end
    -- and nothing beyond the loop end is played
    if keep and info.loop_end > info.loop_start
       and sl.sample_start < info.total_frames
       and sl.sample_start >= info.loop_end then
      keep = false
    end
    if keep then visible[#visible + 1] = sl end
  end
  table.sort(visible, function(a, b) return a.sample_start < b.sample_start end)
  info.all_slices = info.slices
  info.slices = visible

  -- REX derives the loop's musical length from the bar/beat counts
  local total_beats = bars * math.max(1, info.time_sig_num) + beats
  if total_beats <= 0 then total_beats = 4 end
  info.ppq_length = total_beats * REX_PPQ
  info.beats = total_beats

  -- and the "original" tempo from the loop length in frames
  local frames = info.total_frames
  if info.loop_end > info.loop_start then frames = info.loop_end - info.loop_start end
  if frames > 0 and info.sample_rate > 0 then
    info.original_tempo = (info.ppq_length / REX_PPQ) * 60 * info.sample_rate / frames
  else
    info.original_tempo = info.tempo
  end

  info.duration_seconds = info.total_frames / math.max(1, info.sample_rate)
  return info
end

--- A one-line summary, for status bars and batch reports.
function PakettiRX2Describe(info)
  return string.format(
    "%s: %.2f BPM, %d slices, %.2fs, %d Hz %d-bit %s%s",
    pakettiFSPath.basename(info.path), info.tempo, #info.slices,
    info.duration_seconds, info.sample_rate, info.bit_depth,
    info.channels == 2 and "stereo" or "mono",
    (info.creator.name and info.creator.name ~= "") and (", by " .. info.creator.name) or "")
end

function PakettiRX2ShowInfoDialog()
  local path = renoise.app():prompt_for_filename_to_read(
    { "*.rx2", "*.rex", "*.rcy" }, "Inspect a REX file")
  if not path or path == "" then return end

  local info, err = PakettiRXReadAny(path)
  if not info then
    renoise.app():show_error("Could not read that REX file.\n\n" .. tostring(err))
    return
  end

  local lines = {
    pakettiFSPath.basename(info.path),
    "",
    string.format("Tempo            %.3f BPM", info.tempo),
    string.format("Detected tempo   %.3f BPM", info.original_tempo),
    string.format("Time signature   %d/%d", info.time_sig_num, info.time_sig_den),
    string.format("Length           %.3f s, %d frames, %d beats",
      info.duration_seconds, info.total_frames, info.beats),
    string.format("Audio            %d Hz, %d-bit, %s",
      info.sample_rate, info.bit_depth, info.channels == 2 and "stereo" or "mono"),
    string.format("Loop             %d .. %d", info.loop_start, info.loop_end),
    string.format("Slices           %d visible, %d in the table, header says %d",
      #info.slices, info.all_slices and #info.all_slices or #info.slices, info.slice_count),
    string.format("Compressed audio %d bytes", info.audio_bytes),
  }
  if info.creator.name and info.creator.name ~= "" then
    lines[#lines + 1] = "Creator          " .. info.creator.name
  end
  if info.creator.copyright and info.creator.copyright ~= "" then
    lines[#lines + 1] = "Copyright        " .. info.creator.copyright
  end
  if info.creator.url and info.creator.url ~= "" then
    lines[#lines + 1] = "URL              " .. info.creator.url
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "Slice positions (frames):"
  local pos = {}
  for i = 1, math.min(#info.slices, 32) do
    pos[#pos + 1] = tostring(info.slices[i].sample_start)
  end
  lines[#lines + 1] = "  " .. table.concat(pos, ", ")
  if #info.slices > 32 then
    lines[#lines + 1] = string.format("  ... and %d more", #info.slices - 32)
  end

  local text = table.concat(lines, "\n")
  print("------------\n" .. text .. "\n------------")
  renoise.app():show_message(text)
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Inspect REX File (.rx2/.rex/.rcy)...",
  invoke=function() PakettiRX2ShowInfoDialog() end}
PakettiAddMenuEntry{name="Main Menu:File:Paketti Import:Inspect REX File (.rx2/.rex/.rcy)...",
  invoke=function() PakettiRX2ShowInfoDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Inspect REX File",
  invoke = function() PakettiRX2ShowInfoDialog() end }

--------------------------------------------------------------------------------
-- Legacy REX 1 and ReCycle documents (.rex, .rcy)
--
-- These are NOT the CAT/REX2 container above. They are AIFF files —
-- FORM ... AIFF with COMM and SSND — carrying an APPL chunk whose application
-- signature is "REX " or "ReCy", and that chunk holds the tempo and the slice
-- table.
--
-- The important consequence: **their audio is uncompressed PCM**, big-endian, in
-- the SSND chunk. None of the DPCM machinery REX2 needs applies, so these can be
-- read completely in Lua — container, slices and audio — with no decoder binary
-- on any platform.
--
-- Slice tables differ between the two:
--   REX   magic d1d1d1da, PPQ length at +6, count at +0x0a, records of 12 bytes
--         from +0x3f8: start, length, ppq/16
--   ReCy  magic d1daded0, sensitivity at +0x14, count at +0x9e, records of 8
--         bytes from +0xa0: state/selected byte, 4-byte start, 2-byte points.
--         Slices below the sensitivity threshold are hidden in ReCycle and are
--         filtered out the same way here.
--------------------------------------------------------------------------------

local function be_u64_mant(d, p)
  local m = 0
  for i = 0, 7 do
    local b = d:byte(p + i)
    if not b then return 0 end
    m = m * 256 + b
  end
  return m
end

--- Decode AIFF's 80-bit extended sample rate.
local function aiff_rate(d, p)
  local expon = be_u16(d, p)
  if not expon then return 0 end
  local mant = be_u64_mant(d, p + 2)
  if expon == 0 or mant == 0 then return 0 end
  local sign = 1
  if bit.band(expon, 0x8000) ~= 0 then sign = -1 end
  local exp = bit.band(expon, 0x7FFF) - 16383
  local value = sign * mant * 2 ^ (exp - 63)
  if value <= 0 or value > 2147483647 then return 0 end
  return math.floor(value + 0.5)
end

local function recycle_filter_points(sensitivity)
  local sens = math.min(sensitivity or 0, 1000)
  local visible = math.floor((sens * 0x7FFF + 999) / 1000)
  return 0x7FFF - visible
end

local function parse_rex_slices(body)
  local b = body:sub(5)
  if #b < 0x3F8 or be_u32(b, 1) ~= 0xd1d1d1da then return nil end
  local ppq_length = be_u32(b, 7)
  if not ppq_length or ppq_length == 0 then return nil end
  local count = be_u16(b, 0x0B)
  if not count or count == 0 or count > 1000 then return nil end
  if #b < 0x3F8 + count * 12 then return nil end

  local slices = {}
  for i = 0, count - 1 do
    local p = 0x3F8 + i * 12 + 1
    local start = be_u32(b, p)
    local length = be_u32(b, p + 4)
    local ppq16 = be_u32(b, p + 8)
    if not ppq16 or ppq16 > ppq_length then return nil end
    if length and length ~= 0 then
      slices[#slices + 1] = { sample_start = start, sample_length = length, ppq = ppq16 * 16 }
    end
  end
  return slices, ppq_length
end

local function parse_recycle_slices(body)
  local b = body:sub(5)
  if #b < 0xA0 or be_u32(b, 1) ~= 0xd1daded0 then return nil end
  local sensitivity = be_u16(b, 0x15)
  local threshold = recycle_filter_points(sensitivity)
  local count = be_u16(b, 0x9F)
  if not count or count == 0 or count > 1000 then return nil end
  if #b < 0xA0 + count * 8 then return nil end

  local slices = {}
  for i = 0, count - 1 do
    local p = 0xA0 + i * 8 + 1
    local flag = b:byte(p)
    local state = bit.band(flag, 0x7F)
    local selected = bit.band(flag, 0x80) ~= 0
    local b1, b2, b3, b4 = b:byte(p + 1, p + 4)
    local start = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    local points = be_u16(b, p + 6)
    -- ReCycle hides slices whose transient strength is under the threshold
    if selected or state ~= 0 or (points or 0) > threshold then
      slices[#slices + 1] = { sample_start = start, sample_length = 0, ppq = 0,
                              muted = (state == 1), locked = (state == 2) }
    end
  end
  return slices
end

--- Parse a legacy REX 1 / ReCycle document. Returns info plus, optionally, the
--- raw big-endian PCM and where it sat.
function PakettiRXLegacyReadInfo(path)
  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. tostring(path) end
  local data = f:read("*a")
  f:close()
  if not data or #data < 12 then return nil, "file is too short" end
  if data:sub(1, 4) ~= "FORM" or data:sub(9, 12) ~= "AIFF" then
    return nil, "not a legacy REX/ReCycle document (no FORM/AIFF header)"
  end

  local info = {
    path = path, legacy = true,
    channels = 1, sample_rate = 44100, bit_depth = 16,
    tempo = 120.0, time_sig_num = 4, time_sig_den = 4,
    total_frames = 0, loop_start = 0, loop_end = 0,
    slices = {}, creator = {}, ppq_length = REX_PPQ * 4,
  }
  local pcm_pos, pcm_size, app_kind

  local form_end = math.min((be_u32(data, 5) or 0) + 9, #data + 1)
  local pos = 13
  while pos + 8 <= form_end and pos + 8 <= #data + 1 do
    local id = data:sub(pos, pos + 3)
    local size = be_u32(data, pos + 4)
    if not size then break end
    local body_pos = pos + 8
    if body_pos + size - 1 > #data then break end

    if id == "COMM" and size >= 18 then
      info.channels = be_u16(data, body_pos) or 1
      info.total_frames = be_u32(data, body_pos + 2) or 0
      info.bit_depth = be_u16(data, body_pos + 6) or 16
      info.sample_rate = aiff_rate(data, body_pos + 8)

    elseif id == "SSND" and size >= 8 then
      local data_offset = be_u32(data, body_pos) or 0
      local start = body_pos + 8 + data_offset
      if start <= body_pos + size then
        pcm_pos = start
        pcm_size = (body_pos + size) - start
      end

    elseif id == "MARK" and size >= 2 then
      local count = be_u16(data, body_pos) or 0
      local p = body_pos + 2
      for _ = 1, count do
        if p + 6 > body_pos + size then break end
        local marker_pos = be_u32(data, p + 2) or 0
        local name_len = data:byte(p + 6) or 0
        p = p + 7
        local name = data:sub(p, p + name_len - 1)
        if name == "Loop start" then info.loop_start = marker_pos
        elseif name == "Loop end" then info.loop_end = marker_pos end
        p = p + name_len
        if (name_len + 1) % 2 ~= 0 then p = p + 1 end
      end

    elseif id == "APPL" and size >= 8 then
      local app = data:sub(body_pos, body_pos + 3)
      local body = data:sub(body_pos, body_pos + size - 1)
      if app == "ReCy" or app == "REX " then
        app_kind = app
        -- tempo sits at a different offset in each, as milli-BPM
        local tempo_off = (app == "ReCy") and 15 or 17
        local v = be_u32(body, tempo_off)
        if v and v >= 20000 and v <= 450000 then info.tempo = v / 1000 end
        if app == "ReCy" then
          info.slices = parse_recycle_slices(body) or {}
        else
          local sl, ppq = parse_rex_slices(body)
          info.slices = sl or {}
          if ppq and ppq > 0 then info.ppq_length = ppq end
        end
      end
    end

    pos = body_pos + size
    if pos % 2 == 0 then pos = pos + 1 end
  end

  if not app_kind then
    return nil, "an AIFF file, but not a REX or ReCycle document"
  end
  if info.total_frames == 0 or not pcm_pos then
    return nil, "no COMM or SSND chunk: the document is corrupt"
  end
  if info.channels < 1 or info.channels > 2 then info.channels = 1 end

  -- clamp the frame count to what SSND actually holds
  local bytes_per_sample = math.floor((info.bit_depth + 7) / 8)
  local frame_bytes = bytes_per_sample * info.channels
  if frame_bytes > 0 then
    local available = math.floor(pcm_size / frame_bytes)
    if available < info.total_frames then info.total_frames = available end
  end

  if info.loop_end <= info.loop_start then info.loop_end = info.total_frames end
  info.duration_seconds = info.total_frames / math.max(1, info.sample_rate)
  info.kind = (app_kind == "ReCy") and "ReCycle" or "REX 1"
  info.pcm_offset, info.pcm_bytes = pcm_pos, pcm_size
  info.bytes_per_sample = bytes_per_sample
  info.source = data
  return info
end

--- Read either container. Legacy documents come back with `legacy = true`.
function PakettiRXReadAny(path)
  local info, err = PakettiRX2ReadInfo(path)
  if info then return info end
  local legacy, lerr = PakettiRXLegacyReadInfo(path)
  if legacy then return legacy end
  return nil, (err or "") .. " / " .. (lerr or "")
end

--------------------------------------------------------------------------------
-- Importing a legacy document
--------------------------------------------------------------------------------

local function le_u32(v)
  return string.char(v % 256, math.floor(v / 256) % 256,
    math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

local function le_u16(v)
  return string.char(v % 256, math.floor(v / 256) % 256)
end

--- Wrap big-endian AIFF PCM in a RIFF WAV, flipping byte order with one pattern
--- substitution rather than a per-sample loop.
local function aiff_pcm_to_wav(pcm, channels, rate, bits)
  local swapped
  if bits == 8 then swapped = pcm
  elseif bits == 16 then swapped = pcm:gsub("(.)(.)", "%2%1")
  elseif bits == 24 then swapped = pcm:gsub("(.)(.)(.)", "%3%2%1")
  elseif bits == 32 then swapped = pcm:gsub("(.)(.)(.)(.)", "%4%3%2%1")
  else return nil end

  local block_align = channels * math.floor(bits / 8)
  local fmt = le_u16(1) .. le_u16(channels) .. le_u32(rate)
    .. le_u32(rate * block_align) .. le_u16(block_align) .. le_u16(bits)
  local body = "WAVE" .. "fmt " .. le_u32(#fmt) .. fmt
    .. "data" .. le_u32(#swapped) .. swapped
  return "RIFF" .. le_u32(#body) .. body
end

--- Load a .rex or .rcy into a new instrument: audio, slice markers and tempo,
--- with no decoder binary involved.
function PakettiRXLegacyImport(path)
  local info, err = PakettiRXLegacyReadInfo(path)
  if not info then return false, err end

  local pcm = info.source:sub(info.pcm_offset,
    info.pcm_offset + info.total_frames * info.bytes_per_sample * info.channels - 1)
  local wav = aiff_pcm_to_wav(pcm, info.channels, info.sample_rate, info.bit_depth)
  if not wav then
    return false, string.format("%d-bit audio is not supported", info.bit_depth)
  end

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
  local loaded = pcall(function() return sample.sample_buffer:load_from(tmp) end)
  os.remove(tmp)

  if not loaded or not sample.sample_buffer.has_sample_data then
    return false, "Renoise could not load the extracted audio"
  end
  sample.name = name

  local placed = 0
  local frames = sample.sample_buffer.number_of_frames
  local last = -1
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

  return true, string.format("%s %s: %d slices, %.2fs, %d Hz %d-bit %s, %.2f BPM",
    info.kind, name, placed, info.duration_seconds, info.sample_rate, info.bit_depth,
    info.channels == 2 and "stereo" or "mono", info.tempo)
end

function PakettiRXLegacyImportDialog()
  local path = renoise.app():prompt_for_filename_to_read(
    { "*.rex", "*.rcy" }, "Import a REX 1 / ReCycle document")
  if not path or path == "" then return end
  local ok, msg = PakettiRXLegacyImport(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("REX import failed.\n\n" .. tostring(msg)) end
  print("-- PakettiRXLegacyImport: " .. tostring(msg))
end

function PakettiRXLegacyImportHook(path)
  local ok, msg = PakettiRXLegacyImport(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("REX import failed.\n\n" .. tostring(msg)) end
  return true
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Import:REX 1 / ReCycle Document (.rex/.rcy)...",
  invoke=function() PakettiRXLegacyImportDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Import REX 1 / ReCycle (.rex/.rcy)...",
  invoke=function() PakettiRXLegacyImportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Import REX 1 ReCycle Document",
  invoke = function() PakettiRXLegacyImportDialog() end }
