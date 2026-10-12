-- SampleBrain/tests/test_dsp.lua
-- Comprehensive unit tests for SampleBrain Lua engine

package.path = "?.lua;?/init.lua;" .. package.path

local Window = require("SampleBrain.dsp.Window")
local FFT = require("SampleBrain.dsp.FFT")
local MFCC = require("SampleBrain.dsp.MFCC")
local Distance = require("SampleBrain.dsp.Distance")
local SourceRef = require("SampleBrain.model.SourceRef")
local Block = require("SampleBrain.model.Block")
local BlockGenerator = require("SampleBrain.analysis.BlockGenerator")
local SynapseBuilder = require("SampleBrain.analysis.SynapseBuilder")
local Matcher = require("SampleBrain.matching.Matcher")
local Renderer = require("SampleBrain.render.Renderer")
local Constants = require("SampleBrain.Constants")

print("--- Running SampleBrain Pure Lua DSP & Engine Tests ---")

local sr = 44100

-- Test 1: Window functions
local size = 1024
local hann = Window.coefficients(size, Constants.WINDOW_HANN)
assert(#hann == size, "Window length mismatch")
assert(math.abs(hann[1]) < 1e-4, "Hann start should be approx 0")
assert(math.abs(hann[size]) < 1e-4, "Hann end should be approx 0")
print("[PASS] Window functions")

-- Test 2: FFT & Dominant Frequency
local sine = {}
for i = 1, 1024 do sine[i] = math.sin(2.0 * math.pi * 440 * (i - 1) / sr) end
local dom_f = FFT.calculate_dominant_freq(sine, sr)
assert(math.abs(dom_f - 440) < 50, "FFT dominant freq error")
print(string.format("[PASS] FFT dominant frequency (440 Hz -> %.1f Hz)", dom_f))

-- Test 3: MFCC
local mfcc_vec = MFCC.compute(sine, sr, 12)
assert(#mfcc_vec == 12, "MFCC vector size mismatch")
print("[PASS] MFCC calculation (12 filters)")

-- Test 4: Distance Metric & SourceRef
local target_pcm = {}
for i = 1, 4096 do target_pcm[i] = math.sin(2.0 * math.pi * 440 * (i - 1) / sr) end
local target_src = SourceRef.create(1, "Target", target_pcm, sr)
local blk1 = Block.create(1, target_src, 1, 1, 1024, Constants.WINDOW_HANN)

local sine880 = {}
for i = 1, 1024 do sine880[i] = math.sin(2.0 * math.pi * 880 * (i - 1) / sr) end
local brain_src = SourceRef.create(2, "Brain1", sine880, sr)
local blk2 = Block.create(2, brain_src, 1, 1, 1024, Constants.WINDOW_HANN)

local self_dist = Distance.compare_blocks(blk1, blk1, 0.5, 0.5, 0.0)
local diff_dist = Distance.compare_blocks(blk1, blk2, 0.5, 0.5, 0.0)
assert(self_dist < 1e-6 and diff_dist > self_dist, "Distance metric logic error")
print("[PASS] Distance metric & SourceRef comparison")

-- Test 5: Brain Generation
local brain_pcm = {}
for i = 1, 8192 do brain_pcm[i] = math.sin(2.0 * math.pi * 220 * (i - 1) / sr) end
local brain_src2 = SourceRef.create(3, "Brain2", brain_pcm, sr)
local brain_blocks = BlockGenerator.generate(brain_src2, 1024, 0.5, Constants.WINDOW_HANN, 1)
assert(#brain_blocks == 15, string.format("Brain block count mismatch: expected 15, got %d", #brain_blocks))
print("[PASS] Brain generation (15 blocks)")

-- Test 6: Synapse Builder
local synapses_created = SynapseBuilder.build_fixed(brain_blocks, 5, 0.5, 0.5)
assert(synapses_created == 15 * 5, "Synapse creation count mismatch")
assert(#brain_blocks[1].synapses == 5, "Block synapse list mismatch")
print(string.format("[PASS] Synapse graph building (%d synapses created)", synapses_created))

-- Test 7: Matcher Search Modes (Basic, Reversed, Synaptic)
local matcher = Matcher.create(brain_blocks)

local basic_match, b_dist = matcher:search(blk1, { algo = Constants.ALGO_BASIC })
assert(basic_match ~= nil, "Basic search failed")

local rev_match, r_dist = matcher:search(blk1, { algo = Constants.ALGO_REVERSED })
assert(rev_match ~= nil and r_dist >= b_dist, "Reversed search failed")

local syn_match, s_dist = matcher:search(blk1, { algo = Constants.ALGO_SYNAPTIC, num_synapses = 5 })
assert(syn_match ~= nil, "Synaptic search failed")
print("[PASS] Matcher search algorithms (Basic, Reversed, Synaptic)")

-- Test 8: End-to-End Multi-Algorithm Rendering
local target_blocks = BlockGenerator.generate(target_src, 1024, 0.5, Constants.WINDOW_HANN, 1)

for algo_id, algo_name in ipairs({ "Basic", "Reversed", "Synaptic", "Synaptic Slide" }) do
  local out_pcm = Renderer.render(brain_blocks, target_blocks, {
    block_size = 1024,
    overlap = 0.5,
    algo = algo_id,
    autotune = 0.5,
    stretch = 1,
    stickiness = 0.2,
    usage_importance = 0.1,
    usage_falloff = 0.9
  })
  assert(#out_pcm > 0, "Render output should not be empty")
  print(string.format("[PASS] Render mode %s (%d frames output)", algo_name, #out_pcm))
end

-- Test 9: Safe Session Serialization
local Session = require("SampleBrain.persistence.Session")
local test_state = {
  version = 1,
  params = { ratio = 0.7, stickiness = 0.25, is_active = true, name = "Test Session" }
}
local tmp_path = "/tmp/test_samplebrain_session.sb_session"
local save_ok = Session.save(tmp_path, test_state)
assert(save_ok, "Session save failed")

local loaded_state = Session.load(tmp_path)
assert(loaded_state ~= nil and loaded_state.params.ratio == 0.7 and loaded_state.params.is_active == true, "Safe Session load failed")
os.remove(tmp_path)
print("[PASS] Safe Session serialization (save & safe load)")

-- Test 10: Linked Stereo Rendering Test
local stereo_l = {}
local stereo_r = {}
for i = 1, 4096 do
  stereo_l[i] = math.sin(2.0 * math.pi * 440 * (i - 1) / sr)
  stereo_r[i] = math.sin(2.0 * math.pi * 880 * (i - 1) / sr)
end
local stereo_brain_src = SourceRef.create(3, "StereoBrain", stereo_l, sr, nil, nil, 1, 4096, stereo_l, stereo_r, 2)
local stereo_brain_blocks = BlockGenerator.generate(stereo_brain_src, 1024, 0.5, Constants.WINDOW_HANN, 1)

local out_l, out_r = Renderer.render(stereo_brain_blocks, target_blocks, {
  block_size = 1024,
  overlap = 0.5,
  algo = Constants.ALGO_BASIC
})

assert(out_l and out_r and #out_l == #out_r, "Stereo render output buffers missing")
local diff_count = 0
for i = 1, #out_l do
  if math.abs(out_l[i] - out_r[i]) > 1e-4 then
    diff_count = diff_count + 1
  end
end
assert(diff_count > 0, "Stereo render channels should differ when source left != right")
print("[PASS] Linked Stereo rendering (separate left/right channels verified)")

print("\nALL SAMPLEBRAIN SYSTEM TESTS PASSED SUCCESSFULLY!")
