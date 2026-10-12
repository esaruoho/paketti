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

-- Test 11: Deterministic Channel-Specific Independent Stereo Search Test
local pcm_440, pcm_880, pcm_2000 = {}, {}, {}
for i = 1, 1024 do
  pcm_440[i]  = math.sin(2.0 * math.pi * 440  * (i - 1) / sr)
  pcm_880[i]  = math.sin(2.0 * math.pi * 880  * (i - 1) / sr)
  pcm_2000[i] = math.sin(2.0 * math.pi * 2000 * (i - 1) / sr)
end

-- Brain A: Left=440Hz, Right=2000Hz
local src_a = SourceRef.create(10, "BrainA", pcm_440, sr, nil, nil, 1, 1024, pcm_440, pcm_2000, 2)
local blk_a = Block.create(10, src_a, 1, 1, 1024, Constants.WINDOW_HANN)

-- Brain B: Left=2000Hz, Right=880Hz
local src_b = SourceRef.create(11, "BrainB", pcm_2000, sr, nil, nil, 1, 1024, pcm_2000, pcm_880, 2)
local blk_b = Block.create(11, src_b, 1, 1, 1024, Constants.WINDOW_HANN)

-- Target: Left=440Hz, Right=880Hz
local src_t = SourceRef.create(12, "TargetLR", pcm_440, sr, nil, nil, 1, 1024, pcm_440, pcm_880, 2)
local blk_t = Block.create(12, src_t, 1, 1, 1024, Constants.WINDOW_HANN)

local brain_set = { blk_a, blk_b }
local target_set = { blk_t }

local Matcher = require("SampleBrain.matching.Matcher")
local matcher_l = Matcher.create(brain_set)
local matcher_r = Matcher.create(brain_set)

local match_l = matcher_l:search(blk_t, { algo = Constants.ALGO_BASIC, channel = "left" })
local match_r = matcher_r:search(blk_t, { algo = Constants.ALGO_BASIC, channel = "right" })

assert(match_l and match_l.id == 10, string.format("Left channel should match Brain A (id 10), got %s", tostring(match_l and match_l.id)))
assert(match_r and match_r.id == 11, string.format("Right channel should match Brain B (id 11), got %s", tostring(match_r and match_r.id)))

local ind_out_l, ind_out_r = Renderer.render(brain_set, target_set, {
  block_size = 1024,
  overlap = 0.5,
  algo = Constants.ALGO_BASIC,
  independent_stereo = true
})

assert(ind_out_l and ind_out_r and #ind_out_l == #ind_out_r, "Independent stereo render failed")
print("[PASS] Channel-Specific Independent Stereo Search (Left matched Brain A id 10, Right matched Brain B id 11)")

-- Test 12: Resampler Aliasing Suppression Test (96 kHz 30 kHz sine -> 44.1 kHz)
local sr_96k = 96000
local len_96k = 2229
local sine_30k = {}
for i = 1, len_96k do
  sine_30k[i] = math.sin(2.0 * math.pi * 30000.0 * (i - 1) / sr_96k)
end
local src_96k = SourceRef.create(99, "Sine30k_96k", sine_30k, sr_96k)
local blk_96k = Block.create(99, src_96k, 1, 1, len_96k, 1024, Constants.WINDOW_HANN)

local max_fft_mag = 0.0
for i = 1, #blk_96k.fft do
  if blk_96k.fft[i] > max_fft_mag then max_fft_mag = blk_96k.fft[i] end
end
assert(max_fft_mag < 0.1, string.format("Windowed-sinc LPF aliasing suppression failed: max mag = %.3f", max_fft_mag))
print(string.format("[PASS] Resampler aliasing suppression: 30kHz tone at 96kHz suppressed below Nyquist (max aliased mag = %.4f)", max_fft_mag))

-- Test 13: Resampler Pass-Band Verification Test (96 kHz 10 kHz sine -> 44.1 kHz)
local sine_10k = {}
for i = 1, len_96k do
  sine_10k[i] = math.sin(2.0 * math.pi * 10000.0 * (i - 1) / sr_96k)
end
local src_10k = SourceRef.create(100, "Sine10k_96k", sine_10k, sr_96k)
local blk_10k = Block.create(100, src_10k, 1, 1, len_96k, 1024, Constants.WINDOW_HANN)

local freq_10k_err = math.abs(blk_10k.dominant_freq - 10000.0)
assert(freq_10k_err < 500.0, string.format("Pass-band frequency verification failed: dominant freq = %.1f Hz", blk_10k.dominant_freq))
print(string.format("[PASS] Resampler pass-band verification: 10kHz tone at 96kHz preserved (dominant freq = %.1f Hz)", blk_10k.dominant_freq))

-- Test 14: Matcher Usage State Isolation Test
local m_left = Matcher.create(brain_set)
local m_right = Matcher.create(brain_set)
m_left:reset(100)
m_right:reset(200)

local match_l_res = m_left:search(blk_t, { algo = Constants.ALGO_BASIC, channel = "left", usage_importance = 1.0 })

assert(m_left.usage_table[1] ~= nil and m_left.usage_table[1] > 0, "Left matcher should record usage")
assert(m_right.usage_table[1] == nil, "Right matcher usage_table must remain isolated from Left matcher operations")
print("[PASS] Matcher usage state isolation verified (Left matcher search leaves Right matcher usage untouched)")

print("\nALL SAMPLEBRAIN SYSTEM TESTS PASSED SUCCESSFULLY!")
