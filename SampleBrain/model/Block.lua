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

  local fft = FFT.magnitude_spectrum(raw_windowed, Constants.FFT_BINS_CROPPED)
  local mfcc = MFCC.compute(raw_windowed, sample_rate, Constants.MFCC_FILTERS)
  local dom_freq = FFT.calculate_dominant_freq(raw_windowed, sample_rate)

  -- Peak-normalized windowed copy
  local n_pcm = Distance.normalise(pcm)
  local n_windowed = {}
  for i = 1, length do
    n_windowed[i] = n_pcm[i] * window_coeffs[i]
  end

  local n_fft = FFT.magnitude_spectrum(n_windowed, Constants.FFT_BINS_CROPPED)
  local n_mfcc = MFCC.compute(n_windowed, sample_rate, Constants.MFCC_FILTERS)
  local n_dom_freq = FFT.calculate_dominant_freq(n_windowed, sample_rate)

  local self_obj = setmetatable({
    id = id,
    source_ref = source_ref,
    source_block_index = source_block_index,
    start_frame = start_frame,
    length = length,
    sample_rate = sample_rate,

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

return Block
