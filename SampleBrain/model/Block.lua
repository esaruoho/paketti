-- SampleBrain/model/Block.lua
-- Memory-efficient block model storing descriptors and a SourceRef

local Window = require("SampleBrain.dsp.Window")
local FFT = require("SampleBrain.dsp.FFT")
local MFCC = require("SampleBrain.dsp.MFCC")
local Distance = require("SampleBrain.dsp.Distance")
local Constants = require("SampleBrain.Constants")

local Block = {}
Block.__index = Block

--- Create a new Block linked to a SourceRef
-- @param id number Unique block ID within the system
-- @param source_ref table SourceRef instance providing PCM
-- @param source_block_index number Index of this block within its SourceRef
-- @param start_frame number 1-based start frame within the source_ref
-- @param length number Block size in samples
-- @param window_type number Window type constant
-- @return table Block instance
function Block.create(id, source_ref, source_block_index, start_frame, length, window_type)
  local window_type = window_type or Constants.WINDOW_HANN
  
  -- Extract temporary PCM slice for analysis
  local pcm = source_ref:get_pcm_slice(start_frame, length)
  local sample_rate = source_ref.sample_rate

  local window_coeffs = Window.coefficients(length, window_type)

  -- Raw windowed copy
  local raw_windowed = {}
  for i = 1, length do
    raw_windowed[i] = pcm[i] * window_coeffs[i]
  end

  local r_real, r_imag = FFT.forward(raw_windowed)
  local r_n = #r_real
  local fft = FFT.samplebrain_spectrum_from_fft(r_real, r_n, Constants.FFT_BINS_CROPPED)
  local mfcc = MFCC.compute_from_fft(r_real, r_imag, r_n, sample_rate, Constants.MFCC_FILTERS)
  local dom_freq = FFT.calculate_dominant_freq_from_fft(r_real, r_n, sample_rate)

  -- Peak-normalized windowed copy
  local n_pcm = Distance.normalise(pcm)
  local n_windowed = {}
  for i = 1, length do
    n_windowed[i] = n_pcm[i] * window_coeffs[i]
  end

  local n_real, n_imag = FFT.forward(n_windowed)
  local nn_n = #n_real
  local n_fft = FFT.samplebrain_spectrum_from_fft(n_real, nn_n, Constants.FFT_BINS_CROPPED)
  local n_mfcc = MFCC.compute_from_fft(n_real, n_imag, nn_n, sample_rate, Constants.MFCC_FILTERS)
  local n_dom_freq = FFT.calculate_dominant_freq_from_fft(n_real, nn_n, sample_rate)

  local self_obj = setmetatable({
    id = id,
    source_ref = source_ref,
    source_block_index = source_block_index,
    start_frame = start_frame,
    length = length,
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
