-- SampleBrain/dsp/MFCC.lua
-- Mel-Frequency Cepstral Coefficients (12 filters matching SampleBrain Aquila MFCC)

local FFT = require("SampleBrain.dsp.FFT")
local Constants = require("SampleBrain.Constants")

local MFCC = {}

local function log10(x)
  return math.log(x) / math.log(10)
end

local function hz_to_mel(hz)
  return 2595.0 * log10(1.0 + hz / 700.0)
end

local function mel_to_hz(mel)
  return 700.0 * (10.0 ^ (mel / 2595.0) - 1.0)
end

--- Compute MFCC vector from precomputed FFT
function MFCC.compute_from_fft(real, imag, n, sample_rate, num_coeffs)
  sample_rate = sample_rate or Constants.DEFAULT_SAMPLE_RATE
  num_coeffs = num_coeffs or Constants.MFCC_FILTERS

  local half = math.floor(n / 2)

  -- Power spectrum
  local power = {}
  for i = 1, half do
    local r = real[i]
    local im = imag[i]
    power[i] = (r * r + im * im) / n
  end

  -- Mel filter bank
  local low_hz = 0
  local high_hz = sample_rate / 2
  local low_mel = hz_to_mel(low_hz)
  local high_mel = hz_to_mel(high_hz)

  -- Center points for `num_coeffs` triangular filters (num_coeffs + 2 points)
  local mel_points = {}
  for i = 1, num_coeffs + 2 do
    local m = low_mel + (i - 1) * (high_mel - low_mel) / (num_coeffs + 1)
    mel_points[i] = mel_to_hz(m)
  end

  local bin_points = {}
  for i = 1, num_coeffs + 2 do
    bin_points[i] = math.floor((n + 1) * mel_points[i] / sample_rate) + 1
  end

  -- Calculate log filterbank energies
  local energies = {}
  for m = 1, num_coeffs do
    local f_m_minus = bin_points[m]
    local f_m = bin_points[m + 1]
    local f_m_plus = bin_points[m + 2]

    local sum = 0.0
    for k = f_m_minus, f_m do
      if k >= 1 and k <= half and f_m > f_m_minus then
        local weight = (k - f_m_minus) / (f_m - f_m_minus)
        sum = sum + weight * power[k]
      end
    end
    for k = f_m + 1, f_m_plus do
      if k >= 1 and k <= half and f_m_plus > f_m then
        local weight = (f_m_plus - k) / (f_m_plus - f_m)
        sum = sum + weight * power[k]
      end
    end

    energies[m] = math.log(math.max(sum, 1e-12))
  end

  -- Discrete Cosine Transform (DCT-II) matching Aquila Dct::dct scaling
  local c0 = math.sqrt(1.0 / num_coeffs)
  local cn = math.sqrt(2.0 / num_coeffs)

  local mfcc = {}
  for i = 1, num_coeffs do
    local n_idx = i - 1
    local sum = 0.0
    for j = 1, num_coeffs do
      local k_idx = j - 1
      sum = sum + energies[j] * math.cos((math.pi * (2 * k_idx + 1) * n_idx) / (2.0 * num_coeffs))
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
-- @return table MFCC vector (1-indexed array of floats)
function MFCC.compute(real_in, sample_rate, num_coeffs)
  local real, imag = FFT.forward(real_in)
  return MFCC.compute_from_fft(real, imag, #real, sample_rate, num_coeffs)
end

return MFCC
