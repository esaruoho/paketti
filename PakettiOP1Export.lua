--[[============================================================================
PakettiOP1Export.lua — Teenage Engineering OP-1 drum kit export (.aif)

An OP-1 drum kit is an AIFF carrying an `APPL` chunk of OP-1 JSON:

  FORM ... AIFF
    COMM   18 bytes: channels, frames, bit depth, 80-bit extended sample rate
    APPL   0x1004 bytes: "op-1" then the JSON, NUL padded
    SSND   offset, block size, then BIG-endian 16-bit PCM

The JSON holds 24 fixed-length arrays — volume, pan, pitch, playmode, reverse,
start, end, attack, decay — one entry per pad. Slice positions go into `start`
and `end`, scaled by 2147483646 / (44100 * 20) for stereo or / (44100 * 12) for
mono. Those divisors are also the kit's length limit: about 20 seconds of stereo
or 12 of mono, which is what the device holds.

Getting the PCM out of Renoise without a per-sample loop: Renoise writes the WAV,
and this reads its `data` chunk and flips it to big-endian with a single pattern
substitution. 24-bit sources are narrowed the same way, dropping the low byte.
That keeps a multi-second kit to a couple of string operations instead of a
million-iteration Lua loop.

Layout transcribed from chirashi (github.com/g-lok/chirashi). One deliberate
difference: chirashi declares the APPL chunk as 0x1004 bytes but writes 0x1000 of
content, which leaves the following SSND chunk four bytes adrift of where the
declared size says it starts. Paketti pads to the declared size so the chunk walk
is consistent. Untested on an actual OP-1 either way.
============================================================================]]--

local OP1_MAX_SLICES = 24
local OP1_APPL_SIZE = 0x1004

local function op1_json_escape(s)
  s = tostring(s or "")
  return (s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("[\r\n]", " "))
end

local function be_u32(v)
  return string.char(
    math.floor(v / 16777216) % 256, math.floor(v / 65536) % 256,
    math.floor(v / 256) % 256, v % 256)
end

local function be_u16(v)
  return string.char(math.floor(v / 256) % 256, v % 256)
end

--- AIFF stores its sample rate as an 80-bit IEEE extended float: a 15-bit biased
--- exponent then a 64-bit mantissa whose leading 1 is explicit. Only the top 32
--- mantissa bits are ever needed for a sample rate, so the low four bytes stay
--- zero — but the value has to be normalised into [2^31, 2^32) for those bytes to
--- land in the right place. Normalising to [2^30, 2^31) instead makes every reader
--- report 0 Hz. 44100 must come out as 40 0E AC 44 00 00 00 00 00 00.
local function aiff_extended(rate)
  if not rate or rate <= 0 then return string.rep("\0", 10) end
  local m = rate
  local exp = 16383 + 31
  while m < 2147483648 do m = m * 2; exp = exp - 1 end
  while m >= 4294967296 do m = m / 2; exp = exp + 1 end
  return be_u16(exp) .. be_u32(math.floor(m)) .. string.rep("\0", 4)
end

--- The fmt and data chunks of a RIFF WAV.
local function read_wav(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  if not d or #d < 12 or d:sub(1, 4) ~= "RIFF" then return nil end

  local info, pcm = {}, nil
  local pos = 13
  while pos + 8 <= #d do
    local id = d:sub(pos, pos + 3)
    local b1, b2, b3, b4 = d:byte(pos + 4, pos + 7)
    if not b4 then break end
    local size = ((b4 * 256 + b3) * 256 + b2) * 256 + b1
    local body = d:sub(pos + 8, math.min(#d, pos + 8 + size - 1))
    if id == "fmt " and #body >= 16 then
      local c1, c2 = body:byte(3, 4)
      info.channels = c1 + c2 * 256
      local r1, r2, r3, r4 = body:byte(5, 8)
      info.rate = ((r4 * 256 + r3) * 256 + r2) * 256 + r1
      local d1, d2 = body:byte(15, 16)
      info.bits = d1 + d2 * 256
    elseif id == "data" then
      pcm = body
    end
    pos = pos + 8 + size + (size % 2)
  end
  if not pcm or not info.channels then return nil end
  info.pcm = pcm
  return info
end

--- Little-endian PCM at 16 or 24 bits -> big-endian 16-bit, via pattern
--- substitution rather than a per-sample loop.
local function pcm_to_be16(pcm, bits)
  if bits == 24 then
    -- keep the middle and high bytes, then swap them
    pcm = pcm:gsub("(.)(.)(.)", "%3%2")
    return pcm
  elseif bits == 16 then
    return (pcm:gsub("(.)(.)", "%2%1"))
  elseif bits == 32 then
    -- 32-bit integer PCM: keep the top two bytes, high first
    return (pcm:gsub("(.)(.)(.)(.)", "%4%3"))
  end
  return nil
end

local function op1_metadata(name, category, stereo, slices, total_frames)
  local scale = stereo and (2147483646 / (44100 * 20)) or (2147483646 / (44100 * 12))

  local function fixed(value)
    local t = {}
    for _ = 1, OP1_MAX_SLICES do t[#t + 1] = value end
    return table.concat(t, ",")
  end

  local starts, ends = {}, {}
  for i = 1, OP1_MAX_SLICES do
    if slices[i] then
      starts[i] = string.format("%d", math.floor(slices[i].start_frame * scale))
      ends[i] = string.format("%d", math.floor(slices[i].end_frame * scale))
    else
      starts[i] = "0"
      ends[i] = "0"
    end
  end

  return table.concat({
    '{"name":"', op1_json_escape(name), '","type":"drum","drum_version":2,"stereo":',
    tostring(stereo), ',"octave":0,"original_folder":"', op1_json_escape(category),
    '","mtime":1682173750,',
    '"fx_active":false,"fx_type":"delay","fx_params":[8000,8000,8000,8000,8000,8000,8000,8000],',
    '"lfo_active":false,"lfo_type":"tremolo","lfo_params":[16000,16000,16000,16000,16000,16000,16000,16000],',
    '"dyna_env":[0,8192,0,8192,0,0,0,0],',
    '"volume":[', fixed("8192"), '],',
    '"pan":[', fixed("16384"), '],',
    '"pan_ab":[', fixed("false"), '],',
    '"pitch":[', fixed("0"), '],',
    '"playmode":[', fixed("12288"), '],',
    '"reverse":[', fixed("8192"), '],',
    '"start":[', table.concat(starts, ","), '],',
    '"end":[', table.concat(ends, ","), '],',
    '"attack":[', fixed("0"), '],',
    '"decay":[', fixed("0"), ']}',
  })
end

--- Write the selected instrument as an OP-1 drum kit.
function PakettiOP1Export(aif_path, category)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples == 0 then return false, "the selected instrument has no samples" end
  local parent = instrument.samples[1]
  if not parent.sample_buffer.has_sample_data then
    return false, "the first sample of the selected instrument is empty"
  end

  local base = pakettiFSPath.basename(aif_path):gsub("%.aif$", ""):gsub("%.aiff$", "")

  -- let Renoise render the audio, then reshape the container
  local tmp = os.tmpname() .. ".wav"
  local ok = pcall(function() return parent.sample_buffer:save_as(tmp, "wav") end)
  if not ok or not io.exists(tmp) then return false, "could not render the sample to WAV" end
  local wav = read_wav(tmp)
  os.remove(tmp)
  if not wav then return false, "could not read back the rendered WAV" end

  local pcm = pcm_to_be16(wav.pcm, wav.bits)
  if not pcm then
    return false, string.format("%d-bit audio is not supported by this export", wav.bits)
  end

  local channels = wav.channels
  local frames = math.floor(#pcm / (2 * channels))
  local stereo = (channels == 2)

  local limit_seconds = stereo and 20 or 12
  local seconds = frames / wav.rate

  -- regions, from slice markers when there are any
  local slices = {}
  local markers = parent.slice_markers
  if #markers > 0 then
    local bounds = {}
    for i = 1, #markers do bounds[#bounds + 1] = markers[i] end
    bounds[#bounds + 1] = frames + 1
    for i = 1, math.min(#bounds - 1, OP1_MAX_SLICES) do
      slices[i] = { start_frame = bounds[i] - 1, end_frame = bounds[i + 1] - 2 }
    end
  else
    slices[1] = { start_frame = 0, end_frame = frames - 1 }
  end
  local dropped = math.max(0, #markers - #slices)

  local json = op1_metadata(base, category or "paketti", stereo, slices, frames)
  if #json + 4 > OP1_APPL_SIZE then
    return false, "the OP-1 metadata does not fit in its chunk"
  end
  local appl_body = "op-1" .. json .. string.rep("\0", OP1_APPL_SIZE - 4 - #json)

  local comm = be_u16(channels) .. be_u32(frames) .. be_u16(16) .. aiff_extended(wav.rate)
  local ssnd = be_u32(0) .. be_u32(0) .. pcm

  local body = "AIFF"
    .. "COMM" .. be_u32(#comm) .. comm
    .. "APPL" .. be_u32(#appl_body) .. appl_body
    .. "SSND" .. be_u32(#ssnd) .. ssnd

  local f = io.open(aif_path, "wb")
  if not f then return false, "could not write " .. aif_path end
  f:write("FORM" .. be_u32(#body) .. body)
  f:close()

  local msg = string.format("Wrote %s (%d slice%s, %s, %.1fs)",
    pakettiFSPath.basename(aif_path), #slices, #slices == 1 and "" or "s",
    stereo and "stereo" or "mono", seconds)
  if dropped > 0 then
    msg = msg .. string.format("; %d more dropped, the OP-1 takes %d", dropped, OP1_MAX_SLICES)
  end
  if seconds > limit_seconds then
    msg = msg .. string.format("; longer than the %ds an OP-1 %s kit holds",
      limit_seconds, stereo and "stereo" or "mono")
  end
  return true, msg
end

function PakettiOP1ExportDialog()
  local path = renoise.app():prompt_for_filename_to_write("aif", "Export OP-1 drum kit")
  if not path or path == "" then return end
  if not path:lower():match("%.aiff?$") then path = path .. ".aif" end
  local ok, msg = PakettiOP1Export(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("OP-1 export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiOP1Export: " .. tostring(msg))
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:OP-1 Drum Kit (.aif)...",
  invoke=function() PakettiOP1ExportDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export OP-1 Drum Kit (.aif)...",
  invoke=function() PakettiOP1ExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Export OP-1 Drum Kit (.aif)...",
  invoke=function() PakettiOP1ExportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export OP-1 Drum Kit",
  invoke = function() PakettiOP1ExportDialog() end }
