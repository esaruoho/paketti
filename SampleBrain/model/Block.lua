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

local function resample_to_length(in_pcm, target_length)
  local in_len = #in_pcm
  if in_len == target_length then return in_pcm end
  if in_len == 0 or target_length <= 0 then return {} end

  local out_pcm = {}
  local scale = (in_len > 1 and target_length > 1) and ((in_len - 1) / (target_length - 1)) or 1.0
  for i = 1, target_length do
    local src_pos = (i - 1) * scale + 1
    local idx0 = math.floor(src_pos)
    local idx1 = math.min(in_len, idx0 + 1)
    local frac = src_pos - idx0
    local s0 = in_pcm[idx0] or 0.0
    local s1 = in_pcm[idx1] or 0.0
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
  
  -- Extract temporary native PCM slice for analysis
  local pcm = source_ref:get_pcm_slice(start_frame, native_length)
  local sample_rate = source_ref.sample_rate

  -- Resample native PCM slice directly to canonical_length points
  local raw_analysis_pcm = resample_to_length(pcm, canonical_length)

  local window_coeffs = Window.coefficients(canonical_length, window_type)

  -- Raw windowed copy
  local raw_windowed = {}
  for i = 1, canonical_length do
    raw_windowed[i] = raw_analysis_pcm[i] * window_coeffs[i]
  end

  local r_real, r_imag = FFT.forward(raw_windowed)
  local r_n = #r_real
  local fft = FFT.samplebrain_spectrum_from_fft(r_real, r_n, Constants.FFT_BINS_CROPPED)
  local mfcc = MFCC.compute_from_fft(r_real, r_imag, r_n, CANONICAL_ANALYSIS_RATE, Constants.MFCC_FILTERS)
  local dom_freq = FFT.calculate_dominant_freq_from_fft(r_real, r_n, CANONICAL_ANALYSIS_RATE)

  -- Peak-normalize AFTER canonical resampling (Section 5 fix)
  local n_analysis_pcm = Distance.normalise(raw_analysis_pcm)
  local n_windowed = {}
  for i = 1, canonical_length do
    n_windowed[i] = n_analysis_pcm[i] * window_coeffs[i]
  end

  local n_real, n_imag = FFT.forward(n_windowed)
  local nn_n = #n_real
  local n_fft = FFT.samplebrain_spectrum_from_fft(n_real, nn_n, Constants.FFT_BINS_CROPPED)
  local n_mfcc = MFCC.compute_from_fft(n_real, n_imag, nn_n, CANONICAL_ANALYSIS_RATE, Constants.MFCC_FILTERS)
  local n_dom_freq = FFT.calculate_dominant_freq_from_fft(n_real, nn_n, CANONICAL_ANALYSIS_RATE)

  local self_obj = setmetatable({
    id = id,
    source_ref = source_ref,
    source_block_index = source_block_index,
    start_frame = start_frame,
    length = native_length,
    canonical_length = canonical_length,
    sample_rate = sample_rate,
    window_type = window_type,

    fft = fft,
    mfcc = mfcc,
    dominant_freq = dom_freq,

    n_fft = n_fft,
    n_mfcc = n_mfcc,
    n_dominant_freq = n_dom_freq,

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
