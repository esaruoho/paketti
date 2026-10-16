-- REPORT-CARD >> features/rx2-24bit-import.feature
-- Run: luajit tests/rx2_wav_regression.lua [path/to/real.rx2]
bit = require("bit")
PakettiAddMenuEntry = function() end
renoise = { tool = function() return { add_keybinding = function() end, add_midi_mapping = function() end } end }
dofile("PakettiRX2Decode.lua")
local real_decode = PakettiRX2DecodeFile
local tmp = os.tmpname()
pakettiGetTempFilePath = function() return tmp end
safeInsertInstrumentAt = function() return true end
pakettiPreferencesDefaultInstrumentLoader = function() end
pakettiFSPath = { basename = function(p) return p end }
local function uint(s, p, n)
  local v = 0
  for i = n - 1, 0, -1 do v = v * 256 + s:byte(p + i) end
  return v
end
local checks = 0
local function verify(pcm, info)
  local sample = { insert_slice_marker = function() end }
  sample.sample_buffer = { has_sample_data = true, number_of_frames = #pcm / info.channels,
    load_from = function(_, path)
      local f = assert(io.open(path, "rb")); local wav = f:read("*a"); f:close()
      local depth = uint(wav, 35, 2)
      assert(depth == info.bit_depth, "WAV depth: expected " .. info.bit_depth .. ", got " .. depth)
      local bytes = depth / 8
      assert(uint(wav, 33, 2) == info.channels * bytes, "block alignment")
      assert(uint(wav, 29, 4) == info.sample_rate * info.channels * bytes, "byte rate")
      assert(uint(wav, 41, 4) == #pcm * bytes, "data length")
      assert(uint(wav, 5, 4) == #wav - 8, "RIFF length")
      assert(#wav % 2 == 0, "RIFF word padding")
      for i, expected in ipairs(pcm) do
        local v = uint(wav, 45 + (i - 1) * bytes, bytes)
        if depth == 8 then v = v - 128
        elseif v >= 2 ^ (depth - 1) then v = v - 2 ^ depth end
        assert(v == expected, "PCM mismatch at " .. i)
      end
      checks = checks + #pcm
      return true
    end }
  local song = { selected_instrument_index = 1, selected_instrument = { samples = { sample } } }
  renoise.song = function() return song end
  PakettiRX2DecodeFile = function() return pcm, info end
  local ok, err = PakettiRX2ImportNative("fixture.rx2")
  assert(ok, err)
end
for _, depth in ipairs({8, 16, 24}) do
  for _, channels in ipairs({1, 2}) do
    local hi = 2 ^ (depth - 1) - 1
    local pcm = {-hi - 1, -hi, -42, -1, 0, 1, 42, hi, 42}
    if channels == 2 then pcm[#pcm + 1] = -42 end
    verify(pcm, { bit_depth = depth, channels = channels, sample_rate = 44100,
      slices = {}, duration_seconds = 1, tempo = 115 })
  end
end
-- Exercise the codec as well as the WAV boundary for all supported depths.
dofile("PakettiRX2Encode.lua")
for _, depth in ipairs({8, 16, 24}) do
  for _, channels in ipairs({1, 2}) do
    local hi = 2 ^ (depth - 1) - 1
    local pcm = {-hi - 1, hi, -1, 0, 1, -42, 42, hi}
    local packed = PakettiRX2EncodeDWOP(pcm, channels)
    local decoded = assert(PakettiRX2DecodeDWOP(packed, #pcm / channels, channels, depth))
    for i, v in ipairs(pcm) do assert(decoded[i] == v, "codec roundtrip") end
  end
end
-- Out-of-range 8-bit decoder output must clamp to the signed 8-bit range.
local packed = PakettiRX2EncodeDWOP({-200, 200}, 1)
local decoded = assert(PakettiRX2DecodeDWOP(packed, 2, 1, 8))
assert(decoded[1] == -128 and decoded[2] == 127, "8-bit decoder clamp")
-- Unsupported metadata must fail before opening/decoding the file.
PakettiRX2ReadInfo = function() return {bit_depth = 32} end
local unsupported, why = real_decode("nonexistent-32bit.rx2")
assert(not unsupported and why:find("32%-bit"), "reject unsupported depth")
-- Run the real platform-independent dispatch preamble with Windows selected.
local f = assert(io.open("PakettiRX2Loader.lua", "rb"))
local source = f:read("*a"); f:close()
local start = assert(source:find("function rx2_loadsample(filename, opts)", 1, true))
local stop = assert(source:find("  -- Temporarily disable AutoSamplify", start, true))
assert(loadstring(source:sub(start, stop - 1) .. "return 'external' end"))()
OS = "WINDOWS"
preferences = {pakettiRX2NativeDecoder = {value = true}}
local calls = 0
PakettiRX2ImportNativeSliced = function() calls = calls + 1 end
assert(rx2_loadsample("fixture.RX2") == true and calls == 1, "Windows Lua routing")
assert(rx2_loadsample("fixture.rx2", {force_exe = true}) == "external" and calls == 1,
  "external fallback bypasses Lua")
if arg[1] then
  dofile("PakettiRX2Reader.lua")
  local pcm, info = real_decode(arg[1]); assert(pcm, info)
  verify(pcm, info)
  print(string.format("Real RX2: %d-bit, %d channels, %d frames", info.bit_depth, info.channels, info.total_frames))
end
print("PASS: " .. checks .. " PCM samples preserved exactly")
