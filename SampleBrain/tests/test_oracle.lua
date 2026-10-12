-- SampleBrain/tests/test_oracle.lua
-- Differential test comparing Lua engine against executable C++ upstream oracle fixtures

local Window = require("SampleBrain.dsp.Window")
local FFT = require("SampleBrain.dsp.FFT")
local MFCC = require("SampleBrain.dsp.MFCC")
local Distance = require("SampleBrain.dsp.Distance")
local SourceRef = require("SampleBrain.model.SourceRef")
local Block = require("SampleBrain.model.Block")
local Constants = require("SampleBrain.Constants")

print("--- Running SampleBrain C++ Upstream Oracle Differential Tests ---")

-- Executable C++ Oracle Reference Fixture Data (from ~/work/samplebrain)
local oracle = {
  dominant_freq_440 = 430.664,
  dominant_freq_880 = 861.328,
  dist_self = 0.0,
  dist_diff = 6.52162e7,
  mfcc_440 = { 108.82105, 122.03632, 40.363277, -55.926151, -126.2543, -142.43542, -100.39603, -20.800356, 61.192501, 111.92574, 113.53488, 70.287796 }
}

local sr = 44100
local block_size = 1024

-- Test 1: Dominant Frequency Parity
local s440_pcm = {}
for i = 1, block_size do s440_pcm[i] = math.sin(2.0 * math.pi * 440.0 * (i - 1) / sr) end
local ref440 = SourceRef.create(1, "s440.wav", s440_pcm, sr)
local blk440 = Block.create(1, ref440, 1, 1, block_size, Constants.WINDOW_HANN)

local freq_diff = math.abs(blk440.dominant_freq - oracle.dominant_freq_440)
assert(freq_diff < 1.0, string.format("440Hz Dominant Freq mismatch: Lua %.3f vs C++ %.3f", blk440.dominant_freq, oracle.dominant_freq_440))
print(string.format("[PASS] Dominant frequency parity: Lua %.3f Hz vs C++ %.3f Hz", blk440.dominant_freq, oracle.dominant_freq_440))

-- Test 2: MFCC 12-Coefficient Parity
for idx = 1, 12 do
  local c_lua = blk440.mfcc[idx] or 0.0
  local c_cpp = oracle.mfcc_440[idx]
  local rel_diff = math.abs(c_lua - c_cpp) / math.max(math.abs(c_cpp), 1.0)
  assert(rel_diff < 0.001, string.format("MFCC coef %d relative mismatch: Lua %.5f vs C++ %.5f", idx, c_lua, c_cpp))
end
print("[PASS] Aquila MFCC 12-coefficient vector matches C++ oracle within 0.1% relative tolerance")

-- Test 3: Distance Metric Parity
local s880_pcm = {}
for i = 1, block_size do s880_pcm[i] = math.sin(2.0 * math.pi * 880.0 * (i - 1) / sr) end
local ref880 = SourceRef.create(2, "s880.wav", s880_pcm, sr)
local blk880 = Block.create(2, ref880, 1, 1, block_size, Constants.WINDOW_HANN)

local dist_self = Distance.compare_blocks(blk440, blk440, 0.5, 0.5, 0.0)
local dist_diff = Distance.compare_blocks(blk440, blk880, 0.5, 0.5, 0.0)

assert(dist_self == 0.0, "Self distance should be exactly 0.0")
local dist_rel_err = math.abs(dist_diff - oracle.dist_diff) / oracle.dist_diff
assert(dist_rel_err < 0.001, string.format("Distance metric relative error too high: Lua %.3e vs C++ %.3e", dist_diff, oracle.dist_diff))
print(string.format("[PASS] Distance metric parity: self_dist = %.1f, diff_dist = %.5e (matches C++ oracle)", dist_self, dist_diff))

print("\nALL C++ ORACLE DIFFERENTIAL TESTS PASSED SUCCESSFULLY!")
