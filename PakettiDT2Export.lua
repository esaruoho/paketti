--[[============================================================================
PakettiDT2Export.lua — Elektron Digitakt II preset export (.dt2pst)

A .dt2pst is a ZIP holding three members:

  manifest.json                          what the device reads first
  Samples/transfers-YYMMDD/<NAME>.wav    the audio
  <NAME>                                 a binary preset, no extension

The binary preset is a fixed header, then one 8-byte entry per slice
(00 22, uint32 LE frame position, 00 08), then a fixed footer. Two fields are
patched into the header afterwards: the payload name at offset 0x34, twelve bytes
NUL-padded, and a CRC-32 of the WAV's PCM at 0xBB, big-endian. The same CRC goes
into the manifest as a decimal string.

The device is fussy about the payload name -- letters, digits and spaces only,
twelve characters at most -- and takes 64 slices.

Written using Paketti's stored-entry ZIP writer (PakettiDeflate.lua), so no
compressor is needed; ZIP method 0 is legal and every reader accepts it. Header
and footer byte tables are transcribed from the format as implemented by
chirashi (github.com/g-lok/chirashi), which is the only public description of
this layout.
============================================================================]]--

local DT2_HEADER =
  "\172\17\211\3\2\0\4\0\16\48\48\55\48\0\0\0" ..
  "\3\0\0\0\3\0\0\1\0\0\0\4\90\1\12\0" ..
  "\0\1\58\145\0\0\0\3\0\190\239\186\206\9\0\241" ..
  "\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" ..
  "\0\1\0\17\112\2\0\81\0\0\1\0\3\35\0\17" ..
  "\64\2\0\1\27\0\1\2\0\17\1\6\0\14\2\0" ..
  "\0\38\0\0\40\0\17\64\54\0\38\0\17\34\0\81" ..
  "\100\0\0\0\127\26\0\0\20\0\0\6\0\0\4\0" ..
  "\2\20\0\0\2\0\112\127\0\6\0\127\0\32\11\0" ..
  "\1\38\0\17\110\102\0\49\63\0\39\16\0\15\2\0" ..
  "\17\127\6\0\4\0\0\1\2\43\0\17\15\2\0\18" ..
  "\17\2\180\0\241\2\0\0\0\156\97\0\0\0\0\0" ..
  "\2\223\226\0\0\135\218\19\0\54\0\22\252\8"

local DT2_FOOTER =
  "\0\19\252\128\0\97\252\218\0\1\19\214\24\0\0\8" ..
  "\0\50\1\42\211\12\0\98\42\211\0\1\65\207\12\0" ..
  "\98\65\207\0\1\88\204\12\0\97\88\204\0\1\111\201" ..
  "\12\0\15\2\0\255\255\47\108\13\0\14\15\255\255\70" ..
  "\2\80\0\186\206\240\12\0\0\0\0\242\244\68\17\0" ..
  "\0\1\66\170\161\218\170"

local DT2_MAX_SLICES = 64
local DT2_NAME_OFFSET = 0x34
local DT2_NAME_LENGTH = 12
local DT2_HASH_OFFSET = 0xBB

--- Letters, digits and spaces survive; everything else becomes an underscore.
local function dt2_payload_name(name)
  local out = {}
  for i = 1, #tostring(name) do
    local c = tostring(name):sub(i, i)
    if c:match("[%w ]") then out[#out + 1] = c else out[#out + 1] = "_" end
  end
  local s = table.concat(out):match("^%s*(.-)%s*$")
  if #s > DT2_NAME_LENGTH then s = s:sub(1, DT2_NAME_LENGTH) end
  if s == "" then s = "OUTPUT" end
  return s
end

local function u32le(v)
  local b1 = v % 256; v = math.floor(v / 256)
  local b2 = v % 256; v = math.floor(v / 256)
  local b3 = v % 256; v = math.floor(v / 256)
  return string.char(b1, b2, b3, v % 256)
end

--- The PCM bytes of a RIFF WAV, which is what the device hashes -- not the file.
local function wav_pcm_bytes(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  if not data or #data < 12 or data:sub(1, 4) ~= "RIFF" then return nil end

  local pos = 13
  while pos + 8 <= #data do
    local id = data:sub(pos, pos + 3)
    local b1, b2, b3, b4 = data:byte(pos + 4, pos + 7)
    if not b4 then break end
    local size = ((b4 * 256 + b3) * 256 + b2) * 256 + b1
    if id == "data" then
      return data:sub(pos + 8, math.min(#data, pos + 8 + size - 1)), #data
    end
    pos = pos + 8 + size + (size % 2)
  end
  return nil
end

local function dt2_preset_binary(slice_frames, payload_name, hash)
  local count = #slice_frames
  if count == 0 then count = 1 end
  if count > DT2_MAX_SLICES then count = DT2_MAX_SLICES end

  local parts = { DT2_HEADER }
  for i = 1, count do
    parts[#parts + 1] = string.char(0x00, 0x22) .. u32le(slice_frames[i] or 0)
      .. string.char(0x00, 0x08)
  end
  parts[#parts + 1] = DT2_FOOTER
  local bin = table.concat(parts)

  -- patch the name, NUL padded to twelve bytes
  local name_field = payload_name .. string.rep("\0", DT2_NAME_LENGTH - #payload_name)
  bin = bin:sub(1, DT2_NAME_OFFSET) .. name_field:sub(1, DT2_NAME_LENGTH)
    .. bin:sub(DT2_NAME_OFFSET + DT2_NAME_LENGTH + 1)

  -- and the CRC, big-endian
  local h = string.char(
    math.floor(hash / 16777216) % 256,
    math.floor(hash / 65536) % 256,
    math.floor(hash / 256) % 256,
    hash % 256)
  bin = bin:sub(1, DT2_HASH_OFFSET) .. h .. bin:sub(DT2_HASH_OFFSET + 5)

  return bin
end

--- Write the selected instrument as a Digitakt II preset.
function PakettiDT2Export(dt2_path)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "the selected instrument has no samples"
  end
  local sample = instrument.samples[1]
  if not sample.sample_buffer.has_sample_data then
    return false, "the first sample of the selected instrument is empty"
  end

  local base = pakettiFSPath.basename(dt2_path):gsub("%.dt2pst$", "")
  local payload = dt2_payload_name(base)

  -- Renoise writes the audio; only the container is ours
  local tmp_wav = os.tmpname() .. ".wav"
  local ok = pcall(function() return sample.sample_buffer:save_as(tmp_wav, "wav") end)
  if not ok or not io.exists(tmp_wav) then
    return false, "could not render the sample to WAV"
  end

  local wav_file = io.open(tmp_wav, "rb")
  local wav_data = wav_file and wav_file:read("*a") or nil
  if wav_file then wav_file:close() end
  if not wav_data then
    os.remove(tmp_wav)
    return false, "could not read the rendered WAV"
  end

  local pcm = wav_pcm_bytes(tmp_wav)
  os.remove(tmp_wav)
  if not pcm then return false, "the rendered WAV has no data chunk" end
  local hash = PakettiCRC32(pcm)

  -- slice markers are 1-based frames in Renoise, 0-based positions here
  local slice_frames = {}
  local markers = sample.slice_markers
  for i = 1, #markers do
    if #slice_frames >= DT2_MAX_SLICES then break end
    slice_frames[#slice_frames + 1] = math.max(0, markers[i] - 1)
  end
  if #slice_frames == 0 then slice_frames[1] = 0 end

  local dropped = math.max(0, #markers - #slice_frames)

  local transfer_dir = "Samples/transfers-" .. os.date("%y%m%d")
  local sample_path = transfer_dir .. "/" .. payload .. ".wav"

  local manifest = string.format(
    '{"FormatVersion":"1.0","ProductType":[],"Payload":"%s","FileType":"Sound",' ..
    '"FirmwareVersion":"1.15B","MetaInfo":{"Tags":[]},' ..
    '"Samples":[{"FileName":"%s","FileSize":%d,"Hash":"%d"}]}',
    payload, sample_path, #wav_data, hash)

  local wrote, err = PakettiZipWrite(dt2_path, {
    { name = "manifest.json", data = manifest },
    { name = sample_path, data = wav_data },
    { name = payload, data = dt2_preset_binary(slice_frames, payload, hash) },
  })
  if not wrote then return false, err end

  local msg = string.format("Wrote %s (payload '%s', %d slice%s%s)",
    pakettiFSPath.basename(dt2_path), payload, #slice_frames,
    #slice_frames == 1 and "" or "s",
    dropped > 0 and string.format(
      "; %d more dropped, the device takes 64", dropped) or "")
  return true, msg
end

function PakettiDT2ExportDialog()
  local path = renoise.app():prompt_for_filename_to_write(
    "dt2pst", "Export Digitakt II preset")
  if not path or path == "" then return end
  if not path:lower():match("%.dt2pst$") then path = path .. ".dt2pst" end
  local ok, msg = PakettiDT2Export(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("Digitakt II export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiDT2Export: " .. tostring(msg))
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export Digitakt II Preset (.dt2pst)...",
  invoke=function() PakettiDT2ExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Export Digitakt II Preset (.dt2pst)...",
  invoke=function() PakettiDT2ExportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export Digitakt II Preset",
  invoke = function() PakettiDT2ExportDialog() end }
