-- SampleBrain/dsp/MFCC.lua
-- Mel-Frequency Cepstral Coefficients matching Aquila DSP Library (24 Mel filters -> 12 DCT-II coefficients)

local FFT = require("SampleBrain.dsp.FFT")
local Constants = require("SampleBrain.Constants")

local MFCC = {}

local function log10(x)
  return math.log(x) / math.log(10)
end

local function mel_to_linear(mel)
  -- Exact Aquila Mel constants
  return 700.0 * (math.exp(mel / 1127.01048) - 1.0)
end

--- Compute MFCC vector from precomputed FFT using Aquila 24-filter bank
-- @param real table Real spectrum
-- @param imag table Imaginary spectrum
-- @param n integer FFT length
-- @param sample_rate number Sample rate
-- @param num_coeffs integer Number of output coefficients (default 12)
-- @return table 12-coefficient MFCC array
function MFCC.compute_from_fft(real, imag, n, sample_rate, num_coeffs)
  sample_rate = sample_rate or Constants.DEFAULT_SAMPLE_RATE
  num_coeffs = num_coeffs or Constants.MFCC_FILTERS
  local bank_size = 24
  local mel_filter_width = 200.0

  local half = math.floor(n / 2)
  local valid_bins = half + 1

  -- Magnitude spectrum (Aquila uses std::abs(complex))
  local mags = {}
  for i = 1, valid_bins do
    local r = real[i] or 0.0
    local im = imag[i] or 0.0
    mags[i] = math.sqrt(r * r + im * im)
  end

  -- Aquila Mel Filterbank (24 triangular filters)
  local filter_outputs = {}

  for filter_num = 0, bank_size - 1 do
    local mel_min = filter_num * mel_filter_width / 2.0
    local mel_center = mel_min + mel_filter_width / 2.0
    local mel_max = mel_min + mel_filter_width

    local min_freq = mel_to_linear(mel_min)
    local center_freq = mel_to_linear(mel_center)
    local max_freq = mel_to_linear(mel_max)

    -- Following exact Aquila minPos / maxPos logic
    local min_pos = math.floor(n * min_freq / sample_rate)
    local max_pos = math.floor(n * max_freq / sample_rate)
    max_pos = math.min(max_pos, n - 1)

    local val = 0.0
    if max_pos > min_pos then
      for k = min_pos, max_pos do
        if k < valid_bins then
          local cur_freq = k * sample_rate / n
          if cur_freq >= min_freq then
            local weight = 0.0
            if cur_freq < center_freq then
              if center_freq > min_freq then
                weight = (cur_freq - min_freq) / (center_freq - min_freq)
              end
            else
              if cur_freq < max_freq and max_freq > center_freq then
                weight = (max_freq - cur_freq) / (max_freq - center_freq)
              end
            end
            val = val + mags[k + 1] * weight
          end
        end
      end
    end
    filter_outputs[filter_num + 1] = val
  end

  -- Aquila DCT-II on 24 filter outputs, returning top `num_coeffs` (12)
  local c0 = math.sqrt(1.0 / bank_size)
  local cn = math.sqrt(2.0 / bank_size)

  local mfcc = {}
  for i = 1, num_coeffs do
    local n_idx = i - 1
    local sum = 0.0
    for j = 1, bank_size do
      local k_idx = j - 1
      sum = sum + filter_outputs[j] * math.cos((math.pi * (2 * k_idx + 1) * n_idx) / (2.0 * bank_size))
    end
    local scale = (n_idx == 0) and c0 or cn
    mfcc[i] = sum * scale
  end

  return mfcc
end

--- Compute MFCC vector (12 coefficients by default)
-- @param real_in table Array of real floats (PCM block)
-- @param sample_rate number Sample rate
-- @param num_coeffs integer Number of coefficients (default 12)
-- @return table MFCC vector
function MFCC.compute(real_in, sample_rate, num_coeffs)
  local real, imag = FFT.forward(real_in)
  return MFCC.compute_from_fft(real, imag, #real, sample_rate, num_coeffs)
end

return MFCC
