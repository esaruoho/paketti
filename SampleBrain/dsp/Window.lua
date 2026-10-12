-- SampleBrain/dsp/Window.lua
-- Pure DSP window functions matching SampleBrain C++ implementation (window.cpp)

local Constants = require("SampleBrain.Constants")

local Window = {}

local window_cache = {}

--- Create window coefficients table (1-indexed Lua table of size `size`)
-- @param size integer Window length
-- @param window_type integer One of Constants.WINDOW_*
-- @return table Array of floats
function Window.coefficients(size, window_type)
  window_type = window_type or Constants.WINDOW_HANN
  local cache_key = size * 100 + window_type
  if window_cache[cache_key] then
    return window_cache[cache_key]
  end

  local w = {}
  local sz = size - 1

  if sz <= 0 then
    for i = 1, size do w[i] = 1.0 end
    window_cache[cache_key] = w
    return w
  end

  if window_type == Constants.WINDOW_RECTANGLE then
    for i = 1, size do
      w[i] = 1.0
    end

  elseif window_type == Constants.WINDOW_HANN then
    for i = 1, size do
      local n = i - 1
      w[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * n / sz))
    end

  elseif window_type == Constants.WINDOW_HAMMING then
    for i = 1, size do
      local n = i - 1
      w[i] = 0.53836 - 0.46164 * math.cos(2.0 * math.pi * n / sz)
    end

  elseif window_type == Constants.WINDOW_BLACKMAN then
    for i = 1, size do
      local n = i - 1
      w[i] = 0.42 - 0.5 * math.cos(2.0 * math.pi * n / sz) + 0.08 * math.cos(4.0 * math.pi * n / sz)
    end

  elseif window_type == Constants.WINDOW_BARTLETT then
    for i = 1, size do
      local n = i - 1
      w[i] = 1.0 - (2.0 * math.abs(n - sz / 2.0)) / sz
    end

  elseif window_type == Constants.WINDOW_GAUSSIAN then
    local sigma = 0.5
    for i = 1, size do
      local n = i - 1
      local val = (n - sz / 2.0) / (sigma * sz / 2.0)
      w[i] = math.exp(-0.5 * val * val)
    end

  elseif window_type == Constants.WINDOW_FLAT_TOP then
    for i = 1, size do
      local n = i - 1
      w[i] = 1.0 - 1.93 * math.cos(2.0 * math.pi * n / sz)
                 + 1.29 * math.cos(4.0 * math.pi * n / sz)
                 - 0.388 * math.cos(6.0 * math.pi * n / sz)
                 + 0.0322 * math.cos(8.0 * math.pi * n / sz)
    end

  elseif window_type == Constants.WINDOW_DODGY then
    local start_t = math.floor(size / 6)
    local end_t = math.floor(size / 6)
    for i = 1, size do
      local n = i - 1
      local val = 1.0
      if n < start_t and start_t > 0 then
        val = n / start_t
      elseif n >= size - end_t and end_t > 0 then
        val = (size - 1 - n) / end_t
      end
      w[i] = val
    end

  else
    -- Default to Hann if unknown
    return Window.coefficients(size, Constants.WINDOW_HANN)
  end

  window_cache[cache_key] = w
  return w
end

--- Apply window in-place to samples array
-- @param samples table Array of floats (1-indexed)
-- @param window_coeffs table Window coefficients array or window_type integer
function Window.apply(samples, window_coeffs)
  local coeffs = window_coeffs
  if type(window_coeffs) == "number" then
    coeffs = Window.coefficients(#samples, window_coeffs)
  end

  for i = 1, #samples do
    samples[i] = samples[i] * (coeffs[i] or 1.0)
  end
  return samples
end

return Window
