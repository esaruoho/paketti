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

  walk_iff(data, 13, #data + 1, function(id, body)
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
      end
    end
  end)

  if info.total_frames == 0 then
    return nil, "no SINF chunk: the file is corrupt or not a REX2 file"
  end

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

  local info, err = PakettiRX2ReadInfo(path)
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
    string.format("Slices           %d (header says %d)", #info.slices, info.slice_count),
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
