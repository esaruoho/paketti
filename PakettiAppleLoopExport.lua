--[[============================================================================
PakettiAppleLoopExport.lua — Apple Loops export (.caf)

Core Audio Format with the two UUID chunks Logic Pro and GarageBand look for:
one carrying loop metadata (tempo, beat count, time signature, category) and one
carrying beat markers, which is where slice positions go. Drop the result into
Logic or GarageBand and it behaves as an Apple Loop rather than a plain file.

  caff  version 1, flags 0
  desc  sample rate (a big-endian float64), lpcm, signed packed, block align
  data  edit count, then BIG-endian PCM
  info  a genre string
  uuid  29 81 92 73 ...   loop metadata, key/value pairs
  uuid  03 52 81 1b ...   beat markers, one per slice plus the end

Apple Loops are 44.1 kHz only, and the export says so rather than writing
something Logic will refuse.

As with the OP-1 export, Renoise renders the audio and the PCM is flipped to
big-endian with one pattern substitution instead of a per-sample loop.

Layout transcribed from chirashi (github.com/g-lok/chirashi).
============================================================================]]--

local CAF_LOOP_META_UUID = string.char(
  0x29, 0x81, 0x92, 0x73, 0xb5, 0xbf, 0x4a, 0xef,
  0xb7, 0x8d, 0x62, 0xd1, 0xef, 0x90, 0xbb, 0x2c)

local CAF_BEAT_MARKER_UUID = string.char(
  0x03, 0x52, 0x81, 0x1b, 0x9d, 0x5d, 0x42, 0xe1,
  0x88, 0x2d, 0x6a, 0xf6, 0x1a, 0x6b, 0x33, 0x0c)

local function be16(v) return string.char(math.floor(v / 256) % 256, v % 256) end

local function be32(v)
  return string.char(
    math.floor(v / 16777216) % 256, math.floor(v / 65536) % 256,
    math.floor(v / 256) % 256, v % 256)
end

local function be64(v)
  return string.rep("\0", 4) .. be32(v)  -- sizes here never exceed 32 bits
end

--- IEEE 754 binary64, big-endian. CAF stores the sample rate this way.
local function be_double(x)
  if x == 0 then return string.rep("\0", 8) end
  local sign = 0
  if x < 0 then sign = 1; x = -x end
  local exp = 0
  while x >= 2 do x = x / 2; exp = exp + 1 end
  while x < 1 do x = x * 2; exp = exp - 1 end
  local frac = x - 1
  local biased = exp + 1023

  -- 52 fraction bits, taken a byte at a time
  local bytes = {}
  bytes[1] = sign * 128 + math.floor(biased / 16)
  bytes[2] = (biased % 16) * 16
  local f = frac
  f = f * 16
  bytes[2] = bytes[2] + math.floor(f)
  for i = 3, 8 do
    f = (f - math.floor(f)) * 256
    bytes[i] = math.floor(f)
  end
  return string.char(unpack(bytes))
end

local function caf_chunk(id, body)
  return id .. be64(#body) .. body
end

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
      local q1, q2 = body:byte(15, 16)
      info.bits = q1 + q2 * 256
    elseif id == "data" then
      pcm = body
    end
    pos = pos + 8 + size + (size % 2)
  end
  if not pcm or not info.channels then return nil end
  info.pcm = pcm
  return info
end

local function pcm_to_be16(pcm, bits)
  if bits == 16 then return (pcm:gsub("(.)(.)", "%2%1")) end
  if bits == 24 then return (pcm:gsub("(.)(.)(.)", "%3%2")) end
  if bits == 32 then return (pcm:gsub("(.)(.)(.)(.)", "%4%3")) end
  return nil
end

--- Write the selected instrument's first sample as an Apple Loop.
function PakettiAppleLoopExport(caf_path)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then return false, "the selected instrument has no samples" end
  local sample = instrument.samples[1]
  if not sample.sample_buffer.has_sample_data then
    return false, "the first sample of the selected instrument is empty"
  end

  if sample.sample_buffer.sample_rate ~= 44100 then
    return false, string.format(
      "Apple Loops are 44100 Hz only; this sample is %d Hz. Resample it first.",
      sample.sample_buffer.sample_rate)
  end

  local tmp = os.tmpname() .. ".wav"
  local ok = pcall(function() return sample.sample_buffer:save_as(tmp, "wav") end)
  if not ok or not io.exists(tmp) then return false, "could not render the sample to WAV" end
  local wav = read_wav(tmp)
  os.remove(tmp)
  if not wav then return false, "could not read back the rendered WAV" end

  local pcm = pcm_to_be16(wav.pcm, wav.bits)
  if not pcm then
    return false, string.format("%d-bit audio is not supported by this export", wav.bits)
  end

  local channels = wav.channels
  local block_align = channels * 2
  local frames = math.floor(#pcm / block_align)
  local seconds = frames / wav.rate

  -- beat markers: every slice, plus the end of the file
  local positions, seen = {}, {}
  for _, m in ipairs(sample.slice_markers) do
    local p = math.max(0, m - 1)
    if not seen[p] then seen[p] = true; positions[#positions + 1] = p end
  end
  if not seen[frames] then positions[#positions + 1] = frames end
  table.sort(positions)

  -- beat count from the song tempo when the sample carries none of its own
  local bpm = song.transport.bpm
  local beats = math.floor(bpm / 60 * seconds + 0.5)
  if beats < 1 then beats = 4 end

  -- mFormatFlags: signed integer (1<<2) | packed (1<<3)
  local CAF_FLAG_SIGNED_INT, CAF_FLAG_PACKED = 4, 8
  local desc = be_double(wav.rate) .. "lpcm"
    .. be32(CAF_FLAG_SIGNED_INT + CAF_FLAG_PACKED) .. be32(block_align)
    .. be32(1) .. be32(channels) .. be32(16)

  local info = be32(1) .. "genre\0Other Genre\0"

  local meta_pairs = {
    { "category", "Mixed" },
    { "subcategory", "Loop" },
    { "genre", "Other Genre" },
    { "beat count", tostring(beats) },
    { "time signature", string.format("%d/4", song.transport.lpb > 0 and 4 or 4) },
    { "descriptors", "Loop,Grooving" },
    { "tempo", string.format("%.3f", bpm) },
  }
  local meta = { be32(#meta_pairs) }
  for _, kv in ipairs(meta_pairs) do
    meta[#meta + 1] = kv[1] .. "\0" .. kv[2] .. "\0"
  end

  local beat = { be32(0), be32(0x00010000), be16(0x0032), be16(0x0010), be32(0),
                 be32(#positions) }
  for _, p in ipairs(positions) do
    beat[#beat + 1] = be16(1) .. be16(0) .. be32(0) .. be32(p)
  end

  local out = table.concat({
    "caff", be16(1), be16(0),
    caf_chunk("desc", desc),
    caf_chunk("data", be32(0) .. pcm),
    caf_chunk("info", info),
    caf_chunk("uuid", CAF_LOOP_META_UUID .. table.concat(meta)),
    caf_chunk("uuid", CAF_BEAT_MARKER_UUID .. table.concat(beat)),
  })

  local f = io.open(caf_path, "wb")
  if not f then return false, "could not write " .. caf_path end
  f:write(out)
  f:close()

  return true, string.format("Wrote %s (%.1fs, %s, %d beat marker%s, %d beats at %.1f BPM)",
    pakettiFSPath.basename(caf_path), seconds, channels == 2 and "stereo" or "mono",
    #positions, #positions == 1 and "" or "s", beats, bpm)
end

function PakettiAppleLoopExportDialog()
  local path = renoise.app():prompt_for_filename_to_write("caf", "Export Apple Loop")
  if not path or path == "" then return end
  if not path:lower():match("%.caf$") then path = path .. ".caf" end
  local ok, msg = PakettiAppleLoopExport(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("Apple Loop export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiAppleLoopExport: " .. tostring(msg))
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:Apple Loop (.caf)...",
  invoke=function() PakettiAppleLoopExportDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export Apple Loop (.caf)...",
  invoke=function() PakettiAppleLoopExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Export Apple Loop (.caf)...",
  invoke=function() PakettiAppleLoopExportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export Apple Loop",
  invoke = function() PakettiAppleLoopExportDialog() end }
