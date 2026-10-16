-- REPORT-CARD >> features/rx2-24bit-import.feature
-- Run: luajit tests/rx2_wav_regression.lua [path/to/real.rx2]
bit = require("bit")
PakettiAddMenuEntry = function() end
renoise = { tool = function() return { add_keybinding = function() end } end }
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
        if v >= 2 ^ (depth - 1) then v = v - 2 ^ depth end
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
for _, depth in ipairs({24, 16}) do
  for _, channels in ipairs({1, 2}) do
    local hi = 2 ^ (depth - 1) - 1
    local pcm = {-hi - 1, -hi, -655, -1, 0, 1, 655, hi, 42}
    if channels == 2 then pcm[#pcm + 1] = -42 end
    verify(pcm, { bit_depth = depth, channels = channels, sample_rate = 44100,
      slices = {}, duration_seconds = 1, tempo = 115 })
  end
end
if arg[1] then
  dofile("PakettiRX2Reader.lua")
  local pcm, info = real_decode(arg[1]); assert(pcm, info)
  verify(pcm, info)
  print(string.format("Real RX2: %d-bit, %d channels, %d frames", info.bit_depth, info.channels, info.total_frames))
end
print("PASS: " .. checks .. " PCM samples preserved exactly")
