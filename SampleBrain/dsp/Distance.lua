-- SampleBrain/dsp/Distance.lua
-- Distance & Feature Comparison matching SampleBrain block.cpp

local Constants = require("SampleBrain.Constants")

local Distance = {}

local function blend(a, b, t)
  return a * (1.0 - t) + b * t
end

local function square(x)
  return x * x
end

--- DC-remove and peak-normalize PCM block in-place (returns new array)
-- @param pcm table Array of floats
-- @return table Peak-normalized array
function Distance.normalise(pcm)
  local len = #pcm
  if len == 0 then return {} end

  local min_val = pcm[1]
  local max_val = pcm[1]

  for i = 2, len do
    local v = pcm[i]
    if v < min_val then min_val = v end
    if v > max_val then max_val = v end
  end

  local mid = min_val + (max_val - min_val) / 2.0
  local out = {}

  -- DC Removal
  for i = 1, len do
    out[i] = pcm[i] - mid
  end

  local norm_min = min_val - mid
  local norm_max = max_val - mid

  local div = math.abs(norm_min)
  if div < norm_max then div = norm_max end

  if div > 1e-12 then
    local scale = 1.0 / div
    for i = 1, len do
      out[i] = out[i] * scale
    end
  end

  return out
end

--- Internal compare function between descriptor pairs
-- @param fft_a table FFT spectrum A
-- @param mfcc_a table MFCC vector A
-- @param fft_b table FFT spectrum B
-- @param mfcc_b table MFCC vector B
-- @param ratio number FFT/MFCC mix ratio (0 = FFT only, 1 = MFCC only)
-- @param fft_start integer Optional FFT start bin (1-based)
-- @param fft_end integer Optional FFT end bin (1-based, up to Constants.FFT_BINS_CROPPED)
-- @return number Distance score
function Distance.compare_descriptors(fft_a, mfcc_a, fft_b, mfcc_b, ratio, fft_start, fft_end)
  ratio = ratio or Constants.DEFAULT_RATIO
  fft_start = fft_start or 1
  fft_end = math.min(fft_end or #fft_a, #fft_a, #fft_b)

  local fft_acc = 0.0
  local fft_len = fft_end - fft_start + 1
  
  if fft_len > 0 and ratio < 1.0 then
    for i = fft_start, fft_end do
      fft_acc = fft_acc + square(fft_a[i] - fft_b[i])
    end
  end

  local mfcc_acc = 0.0
  local mfcc_len = math.min(#mfcc_a, #mfcc_b)
  
  if mfcc_len > 0 and ratio > 0.0 then
    for i = 1, mfcc_len do
      mfcc_acc = mfcc_acc + square(mfcc_a[i] - mfcc_b[i])
    end
  end

  local fft_norm = (fft_len > 0) and (fft_acc / fft_len) or 0.0
  local mfcc_norm = (mfcc_len > 0) and (mfcc_acc / mfcc_len) or 0.0

  if ratio == 0 then
    return fft_norm * Constants.FFT_BIAS
  elseif ratio == 1 then
    return mfcc_norm
  else
    return blend(fft_norm, mfcc_norm, ratio)
  end
end

--- Full comparison between block A and block B
-- @param block_a table Target block model
-- @param block_b table Candidate brain block model
-- @param ratio number FFT vs MFCC weight ratio (0..1)
-- @param n_ratio number Raw vs Normalized weight ratio (0..1)
-- @param usage_importance number Weight of usage/novelty penalty
-- @param fft_start integer Optional FFT start bin for comparison
-- @param fft_end integer Optional FFT end bin for comparison
-- @return number Total distance score (lower is closer match)
function Distance.compare_blocks(block_a, block_b, ratio, n_ratio, usage_importance, fft_start, fft_end)
  ratio = ratio or Constants.DEFAULT_RATIO
  n_ratio = n_ratio or Constants.DEFAULT_N_RATIO
  usage_importance = usage_importance or Constants.DEFAULT_USAGE_IMPORTANCE

  local raw_dist = Distance.compare_descriptors(
    block_a.fft, block_a.mfcc,
    block_b.fft, block_b.mfcc,
    ratio, fft_start, fft_end
  )

  local norm_dist = Distance.compare_descriptors(
    block_a.n_fft, block_a.n_mfcc,
    block_b.n_fft, block_b.n_mfcc,
    ratio, fft_start, fft_end
  )

  local feat_dist = blend(raw_dist, norm_dist, n_ratio)
  local usage = block_b.usage or 0.0

  return blend(feat_dist, usage, usage_importance)
end

return Distance
