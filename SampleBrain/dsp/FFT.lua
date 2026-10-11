-- SampleBrain/dsp/FFT.lua
-- Pure Lua Mixed-Radix FFT supporting arbitrary lengths via Bluestein's Algorithm

local FFT = {}

-- Twiddle factor and bit reversal cache per FFT size
local cache = {}

local function is_power_of_two(n)
  return n > 0 and (2 ^ math.floor(math.log(n) / math.log(2))) == n
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

--- Forward Radix-2 FFT (internal)
-- @param real_in table Array of real floats (1-indexed)
-- @param imag_in table Array of imag floats (1-indexed)
-- @return real table Real output array
-- @return imag table Imaginary output array
local function forward_radix2(real_in, imag_in)
  local n = #real_in
  local c = get_cache(n)

  local real = {}
  local imag = {}

  -- Bit reversal ordering
  for i = 1, n do
    local rev_idx = c.bit_rev[i]
    real[i] = real_in[rev_idx] or 0.0
    imag[i] = imag_in and imag_in[rev_idx] or 0.0
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

--- Inverse Radix-2 FFT (internal)
local function inverse_radix2(real_in, imag_in)
  local n = #real_in
  local conj_imag = {}
  for i = 1, n do
    conj_imag[i] = -(imag_in[i] or 0.0)
  end
  
  local out_r, out_i = forward_radix2(real_in, conj_imag)
  for i = 1, n do
    out_r[i] = out_r[i] / n
    out_i[i] = -out_i[i] / n
  end
  return out_r, out_i
end

--- Forward FFT supporting arbitrary length via Bluestein's Algorithm
-- @param real_in table Array of real floats (1-indexed)
-- @return real table Real output array
-- @return imag table Imaginary output array
function FFT.forward(real_in)
  local n = #real_in
  if n == 0 then return {}, {} end
  if is_power_of_two(n) then
    return forward_radix2(real_in, {})
  end

  -- Bluestein chirp-z transform
  local m = next_power_of_two(n * 2 - 1)
  
  local a_real, a_imag = {}, {}
  local b_real, b_imag = {}, {}
  
  for i = 1, m do
    a_real[i], a_imag[i] = 0.0, 0.0
    b_real[i], b_imag[i] = 0.0, 0.0
  end
  
  for i = 0, n - 1 do
    local angle = math.pi * i * i / n
    local c = math.cos(angle)
    local s = math.sin(angle)
    
    local rn = real_in[i+1] or 0.0
    a_real[i+1] = rn * c
    a_imag[i+1] = -rn * s
    
    b_real[i+1] = c
    b_imag[i+1] = s
    if i > 0 then
      b_real[m - i + 1] = c
      b_imag[m - i + 1] = s
    end
  end
  
  local A_r, A_i = forward_radix2(a_real, a_imag)
  local B_r, B_i = forward_radix2(b_real, b_imag)
  
  local C_r, C_i = {}, {}
  for i = 1, m do
    C_r[i] = A_r[i] * B_r[i] - A_i[i] * B_i[i]
    C_i[i] = A_r[i] * B_i[i] + A_i[i] * B_r[i]
  end
  
  local c_r, c_i = inverse_radix2(C_r, C_i)
  
  local out_real, out_imag = {}, {}
  for i = 0, n - 1 do
    local angle = math.pi * i * i / n
    local c = math.cos(angle)
    local s = math.sin(angle)
    
    local r_val = c_r[i+1]
    local i_val = c_i[i+1]
    
    out_real[i+1] = r_val * c - i_val * (-s)
    out_imag[i+1] = r_val * (-s) + i_val * c
  end
  
  return out_real, out_imag
end

--- Calculate upstream SampleBrain compatible FFT descriptor from precomputed FFT
function FFT.samplebrain_spectrum_from_fft(real, n, output_bins)
  output_bins = output_bins or 100
  local half = math.floor(n / 2)

  local bins = {}
  for b = 1, output_bins do
    local start_idx = math.floor((b - 1) / output_bins * half) + 1
    local end_idx = math.floor(b / output_bins * half) + 1
    if end_idx < start_idx then end_idx = start_idx end

    local sum_val = 0.0
    for i = start_idx, end_idx do
      if i <= half then
        sum_val = sum_val + (real[i] * real[i])
      end
    end
    bins[b] = math.abs(sum_val)
  end

  return bins
end

--- Calculate upstream SampleBrain compatible FFT descriptor
-- @param real_in table Array of real floats
-- @param output_bins integer Number of output bins (e.g., 100)
-- @return table 1-indexed descriptor array matching SampleBrain semantics
function FFT.samplebrain_spectrum(real_in, output_bins)
  local real, imag = FFT.forward(real_in)
  return FFT.samplebrain_spectrum_from_fft(real, #real, output_bins)
end

--- Calculate upstream SampleBrain compatible dominant frequency from precomputed FFT
function FFT.calculate_dominant_freq_from_fft(real, n, sample_rate)
  sample_rate = sample_rate or 44100
  local half = math.floor(n / 2)
  local max_mag = -1.0
  local max_bin = 1

  -- Upstream scans from bin 0 and uses real_component^2
  for i = 1, half do
    local r = real[i]
    local mag = r * r
    if mag > max_mag then
      max_mag = mag
      max_bin = i
    end
  end

  local freq = (max_bin - 1) * sample_rate / n
  return math.max(freq, 0.01) -- Upstream clamps to 0.01 minimum
end

--- Calculate upstream SampleBrain compatible dominant frequency
-- @param real_in table Array of real floats
-- @param sample_rate number Sample rate (e.g. 44100)
-- @return number Dominant frequency in Hz
function FFT.calculate_dominant_freq(real_in, sample_rate)
  local real, imag = FFT.forward(real_in)
  return FFT.calculate_dominant_freq_from_fft(real, #real, sample_rate)
end

return FFT
