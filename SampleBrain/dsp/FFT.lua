-- SampleBrain/dsp/FFT.lua
-- Pure Lua Radix-2 Cooley-Tukey FFT & Spectrum Computation

local FFT = {}

-- Twiddle factor and bit reversal cache per FFT size
local cache = {}

local function is_power_of_two(n)
  return n > 0 and math.pow(2, math.floor(math.log(n) / math.log(2))) == n
end

local function check_power_of_two(n)
  return (n > 0) and (math.log(n) / math.log(2)) % 1 == 0
end

local function next_power_of_two(n)
  local p = 1
  while p < n do
    p = p * 2
  end
  return p
end

local function get_cache(n)
  if cache[n] then return cache[n] end

  local bit_rev = {}
  local bits = math.floor(math.log(n) / math.log(2) + 0.5)

  for i = 0, n - 1 do
    local rev = 0
    local val = i
    for b = 1, bits do
      rev = rev * 2 + (val % 2)
      val = math.floor(val / 2)
    end
    bit_rev[i + 1] = rev + 1
  end

  local twiddle_cos = {}
  local twiddle_sin = {}
  for i = 0, n / 2 - 1 do
    local angle = -2.0 * math.pi * i / n
    twiddle_cos[i + 1] = math.cos(angle)
    twiddle_sin[i + 1] = math.sin(angle)
  end

  local entry = {
    bit_rev = bit_rev,
    cos = twiddle_cos,
    sin = twiddle_sin,
    size = n
  }
  cache[n] = entry
  return entry
end

--- Forward FFT on real array (auto-padded to power of 2)
-- @param real_in table Array of real floats (1-indexed)
-- @return real table Real output array
-- @return imag table Imaginary output array
function FFT.forward(real_in)
  local n_in = #real_in
  local n = next_power_of_two(n_in)
  local c = get_cache(n)

  local real = {}
  local imag = {}

  -- Bit reversal ordering & zero-padding
  for i = 1, n do
    local rev_idx = c.bit_rev[i]
    real[i] = (rev_idx <= n_in) and real_in[rev_idx] or 0.0
    imag[i] = 0.0
  end

  -- Cooley-Tukey Radix-2
  local step = 1
  while step < n do
    local jump = step * 2
    local twiddle_step = math.floor(n / jump)

    for k = 1, step do
      local tw_idx = (k - 1) * twiddle_step + 1
      local wr = c.cos[tw_idx]
      local wi = c.sin[tw_idx]

      for i = k, n, jump do
        local j = i + step
        local tr = wr * real[j] - wi * imag[j]
        local ti = wr * imag[j] + wi * real[j]

        real[j] = real[i] - tr
        imag[j] = imag[i] - ti
        real[i] = real[i] + tr
        imag[i] = imag[i] + ti
      end
    end

    step = jump
  end

  return real, imag
end

--- Calculate magnitude spectrum from real input array
-- @param real_in table Array of real floats
-- @param crop_bins integer Optional bin limit (e.g. 100 for SampleBrain)
-- @return table Magnitude spectrum array
function FFT.magnitude_spectrum(real_in, crop_bins)
  local real, imag = FFT.forward(real_in)
  local n = #real
  local half = math.floor(n / 2)
  local limit = crop_bins and math.min(crop_bins, half) or half

  local mags = {}
  for i = 1, limit do
    local r = real[i]
    local im = imag[i]
    mags[i] = math.sqrt(r * r + im * im)
  end

  return mags
end

--- Calculate dominant frequency from real input array
-- @param real_in table Array of real floats
-- @param sample_rate number Sample rate (e.g. 44100)
-- @return number Dominant frequency in Hz
function FFT.calculate_dominant_freq(real_in, sample_rate)
  sample_rate = sample_rate or 44100
  local mags = FFT.magnitude_spectrum(real_in)
  local max_mag = -1
  local max_bin = 1

  for i = 2, #mags do -- Skip DC bin
    if mags[i] > max_mag then
      max_mag = mags[i]
      max_bin = i
    end
  end

  local fft_size = next_power_of_two(#real_in)
  return (max_bin - 1) * sample_rate / fft_size
end

return FFT
