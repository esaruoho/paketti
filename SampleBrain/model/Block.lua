-- SampleBrain/model/Block.lua
-- Memory-efficient block model storing descriptors and a SourceRef

local Window = require("SampleBrain.dsp.Window")
local FFT = require("SampleBrain.dsp.FFT")
local MFCC = require("SampleBrain.dsp.MFCC")
local Distance = require("SampleBrain.dsp.Distance")
local Constants = require("SampleBrain.Constants")

local Block = {}
Block.__index = Block

local CANONICAL_ANALYSIS_RATE = 44100

local function windowed_sinc_lpf(pcm, cutoff, filter_size)
  local n = #pcm
  if n == 0 or cutoff >= 0.5 then return pcm end
  filter_size = filter_size or 31
  if filter_size % 2 == 0 then filter_size = filter_size + 1 end
  local half_m = math.floor(filter_size / 2)

  local h = {}
  local sum_h = 0.0
  for k = -half_m, half_m do
    local idx = k + half_m + 1
    local val = 0.0
    if k == 0 then
      val = 2.0 * cutoff
    else
      val = math.sin(2.0 * math.pi * cutoff * k) / (math.pi * k)
    end
    -- Blackman windowing for >50 dB stop-band attenuation
    local w = 0.42 - 0.5 * math.cos(2.0 * math.pi * (k + half_m) / (filter_size - 1)) + 0.08 * math.cos(4.0 * math.pi * (k + half_m) / (filter_size - 1))
    val = val * w
    h[idx] = val
    sum_h = sum_h + val
  end

  if sum_h > 1e-12 then
    for i = 1, #h do h[i] = h[i] / sum_h end
  end

  local out = {}
  for i = 1, n do
    local s = 0.0
    for k = -half_m, half_m do
      local p_idx = i + k
      if p_idx >= 1 and p_idx <= n then
        s = s + pcm[p_idx] * h[k + half_m + 1]
      end
    end
    out[i] = s
  end

  return out
end

local function resample_to_length(in_pcm, target_length)
  local in_len = #in_pcm
  if in_len == target_length then return in_pcm end
  if in_len == 0 or target_length <= 0 then return {} end

  -- Anti-aliasing windowed-sinc FIR pre-filter for downsampling
  local filtered_pcm = in_pcm
  if in_len > target_length then
    local cutoff = (target_length / in_len) * 0.40
    filtered_pcm = windowed_sinc_lpf(in_pcm, cutoff, 31)
  end

  local out_pcm = {}
  local scale = (in_len > 1 and target_length > 1) and ((in_len - 1) / (target_length - 1)) or 1.0
  for i = 1, target_length do
    local src_pos = (i - 1) * scale + 1
    local idx0 = math.floor(src_pos)
    local idx1 = math.min(in_len, idx0 + 1)
    local frac = src_pos - idx0
    local s0 = filtered_pcm[idx0] or 0.0
    local s1 = filtered_pcm[idx1] or 0.0
    out_pcm[i] = s0 * (1.0 - frac) + s1 * frac
  end

  return out_pcm
end

--- Create a new Block linked to a SourceRef
-- @param id number Unique block ID within the system
-- @param source_ref table SourceRef instance providing PCM
-- @param source_block_index number Index of this block within its SourceRef
-- @param start_frame number 1-based start frame within the source_ref
-- @param native_length number Native block size in Renoise samples
-- @param canonical_length number Canonical block size for descriptor analysis (default native_length)
-- @param window_type number Window type constant
-- @return table Block instance
function Block.create(id, source_ref, source_block_index, start_frame, native_length, canonical_length, window_type)
  if type(canonical_length) == "number" and not window_type and (canonical_length <= Constants.WINDOW_DODGY) then
    window_type = canonical_length
    canonical_length = native_length
  end
  canonical_length = canonical_length or native_length
  window_type = window_type or Constants.WINDOW_HANN
  
  -- Extract temporary native PCM slices for mono, left, and right channels
  local pcm_m = source_ref:get_pcm_slice(start_frame, native_length)
  local sample_rate = source_ref.sample_rate

  -- Helper closure to compute descriptor set for a channel PCM array
  local function analyze_channel(ch_pcm)
    local raw_analysis = resample_to_length(ch_pcm, canonical_length)
    local window_coeffs = Window.coefficients(canonical_length, window_type)
    local raw_windowed = {}
    for i = 1, canonical_length do
      raw_windowed[i] = raw_analysis[i] * window_coeffs[i]
    end
    local r_real, r_imag = FFT.forward(raw_windowed)
    local r_n = #r_real
    local fft_v = FFT.samplebrain_spectrum_from_fft(r_real, r_n, Constants.FFT_BINS_CROPPED)
    local mfcc_v = MFCC.compute_from_fft(r_real, r_imag, r_n, CANONICAL_ANALYSIS_RATE, Constants.MFCC_FILTERS)
    local dom_v = FFT.calculate_dominant_freq_from_fft(r_real, r_n, CANONICAL_ANALYSIS_RATE)

    local n_analysis = Distance.normalise(raw_analysis)
    local n_windowed = {}
    for i = 1, canonical_length do
      n_windowed[i] = n_analysis[i] * window_coeffs[i]
    end
    local n_real, n_imag = FFT.forward(n_windowed)
    local nn_n = #n_real
    local n_fft_v = FFT.samplebrain_spectrum_from_fft(n_real, nn_n, Constants.FFT_BINS_CROPPED)
    local n_mfcc_v = MFCC.compute_from_fft(n_real, n_imag, nn_n, CANONICAL_ANALYSIS_RATE, Constants.MFCC_FILTERS)
    local n_dom_v = FFT.calculate_dominant_freq_from_fft(n_real, nn_n, CANONICAL_ANALYSIS_RATE)

    return fft_v, mfcc_v, dom_v, n_fft_v, n_mfcc_v, n_dom_v
  end

  local fft_m, mfcc_m, dom_m, n_fft_m, n_mfcc_m, n_dom_m = analyze_channel(pcm_m)
  
  local fft_l, mfcc_l, dom_l, n_fft_l, n_mfcc_l, n_dom_l
  local fft_r, mfcc_r, dom_r, n_fft_r, n_mfcc_r, n_dom_r

  if source_ref.num_channels == 1 then
    -- Massive speedup: Reuse mono descriptors for left and right if source is Mono
    fft_l, mfcc_l, dom_l, n_fft_l, n_mfcc_l, n_dom_l = fft_m, mfcc_m, dom_m, n_fft_m, n_mfcc_m, n_dom_m
    fft_r, mfcc_r, dom_r, n_fft_r, n_mfcc_r, n_dom_r = fft_m, mfcc_m, dom_m, n_fft_m, n_mfcc_m, n_dom_m
  else
    local pcm_l, pcm_r = source_ref:get_stereo_slice(start_frame, native_length)
    fft_l, mfcc_l, dom_l, n_fft_l, n_mfcc_l, n_dom_l = analyze_channel(pcm_l)
    fft_r, mfcc_r, dom_r, n_fft_r, n_mfcc_r, n_dom_r = analyze_channel(pcm_r)
  end

  local self_obj = setmetatable({
    id = id,
    source_ref = source_ref,
    source_block_index = source_block_index,
    start_frame = start_frame,
    length = native_length,
    canonical_length = canonical_length,
    sample_rate = sample_rate,
    window_type = window_type,

    -- Mono descriptors
    fft = fft_m,
    mfcc = mfcc_m,
    dominant_freq = dom_m,
    n_fft = n_fft_m,
    n_mfcc = n_mfcc_m,
    n_dominant_freq = n_dom_m,

    -- Left channel descriptors
    fft_l = fft_l,
    mfcc_l = mfcc_l,
    dominant_freq_l = dom_l,
    n_fft_l = n_fft_l,
    n_mfcc_l = n_mfcc_l,
    n_dominant_freq_l = n_dom_l,

    -- Right channel descriptors
    fft_r = fft_r,
    mfcc_r = mfcc_r,
    dominant_freq_r = dom_r,
    n_fft_r = n_fft_r,
    n_mfcc_r = n_mfcc_r,
    n_dominant_freq_r = n_dom_r,

    usage = 0.0,
    synapses = {}
  }, Block)

  return self_obj
end

--- Get raw unwindowed PCM for this block
-- @return table Extracted float array
function Block:get_pcm()
  return self.source_ref:get_pcm_slice(self.start_frame, self.length)
end

--- Get DC-removed peak-normalized unwindowed PCM for this block
-- @return table Normalized float array
function Block:get_n_pcm()
  local pcm = self:get_pcm()
  return Distance.normalise(pcm)
end

--- Get windowed raw PCM for this block (upstream compatibility)
-- @return table Windowed float array
function Block:get_windowed_pcm()
  local pcm = self:get_pcm()
  local coeffs = Window.coefficients(self.length, self.window_type)
  for i = 1, self.length do
    pcm[i] = pcm[i] * coeffs[i]
  end
  return pcm
end

--- Get windowed stereo PCM arrays (left, right) for this block
-- @return table Left channel windowed float array
-- @return table Right channel windowed float array
function Block:get_windowed_pcm_stereo()
  local l_pcm, r_pcm = self.source_ref:get_stereo_slice(self.start_frame, self.length)
  local coeffs = Window.coefficients(self.length, self.window_type)
  for i = 1, self.length do
    l_pcm[i] = (l_pcm[i] or 0.0) * coeffs[i]
    r_pcm[i] = (r_pcm[i] or 0.0) * coeffs[i]
  end
  return l_pcm, r_pcm
end

--- Get windowed normalized stereo PCM arrays (left, right) for this block
-- @return table Left channel windowed normalized float array
-- @return table Right channel windowed normalized float array
function Block:get_normalized_windowed_pcm_stereo()
  local l_pcm, r_pcm = self.source_ref:get_stereo_slice(self.start_frame, self.length)
  
  -- Step 1: Remove DC midpoint from each channel individually
  local min_l, max_l = 1e9, -1e9
  local min_r, max_r = 1e9, -1e9
  for i = 1, #l_pcm do
    local vl = l_pcm[i] or 0.0
    local vr = r_pcm[i] or 0.0
    if vl < min_l then min_l = vl end
    if vl > max_l then max_l = vl end
    if vr < min_r then min_r = vr end
    if vr > max_r then max_r = vr end
  end

  local mid_l = (min_l + max_l) * 0.5
  local mid_r = (min_r + max_r) * 0.5

  local max_peak = 0.0
  for i = 1, #l_pcm do
    local cl = (l_pcm[i] or 0.0) - mid_l
    local cr = (r_pcm[i] or 0.0) - mid_r
    l_pcm[i] = cl
    r_pcm[i] = cr
    local abs_l = math.abs(cl)
    local abs_r = math.abs(cr)
    if abs_l > max_peak then max_peak = abs_l end
    if abs_r > max_peak then max_peak = abs_r end
  end

  -- Step 2: Shared peak normalization preserves L/R level balance
  if max_peak > 1e-12 then
    local scale = 1.0 / max_peak
    for i = 1, #l_pcm do
      l_pcm[i] = l_pcm[i] * scale
      r_pcm[i] = r_pcm[i] * scale
    end
  end

  local coeffs = Window.coefficients(self.length, self.window_type)
  for i = 1, self.length do
    l_pcm[i] = (l_pcm[i] or 0.0) * coeffs[i]
    r_pcm[i] = (r_pcm[i] or 0.0) * coeffs[i]
  end
  return l_pcm, r_pcm
end

--- Get windowed normalized PCM for this block (upstream compatibility)
-- @return table Windowed normalized float array
function Block:get_normalized_windowed_pcm()
  local pcm = self:get_n_pcm()
  local coeffs = Window.coefficients(self.length, self.window_type)
  for i = 1, self.length do
    pcm[i] = pcm[i] * coeffs[i]
  end
  return pcm
end

return Block
