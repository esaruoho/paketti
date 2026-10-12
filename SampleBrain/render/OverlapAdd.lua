-- SampleBrain/render/OverlapAdd.lua
-- Granular overlap-add float buffer accumulator

local Window = require("SampleBrain.dsp.Window")
local Constants = require("SampleBrain.Constants")

local OverlapAdd = {}
OverlapAdd.__index = OverlapAdd

function OverlapAdd.create(total_frames)
  total_frames = math.max(1, math.ceil(total_frames or 1))
  local buffer = {}
  for i = 1, total_frames do
    buffer[i] = 0.0
  end

  return setmetatable({
    buffer = buffer,
    length = total_frames
  }, OverlapAdd)
end

function OverlapAdd:resize(new_length)
  new_length = math.max(1, math.ceil(new_length or 1))
  if new_length > self.length then
    for i = self.length + 1, new_length do
      self.buffer[i] = 0.0
    end
    self.length = new_length
  end
end

--- Add a windowed grain block into output buffer at start_frame
-- @param grain_pcm table Array of float PCM
-- @param start_frame integer 1-based start frame in buffer
-- @param gain number Gain multiplier
-- @param window_type integer Window type for synthesis overlap
function OverlapAdd:add_grain(grain_pcm, start_frame, gain, window_type)
  gain = gain or 1.0
  window_type = window_type or Constants.WINDOW_HANN

  local block_size = #grain_pcm
  local window_coeffs = Window.coefficients(block_size, window_type)

  for i = 1, block_size do
    local out_pos = start_frame + i - 1
    if out_pos <= self.length then
      local s = grain_pcm[i] * window_coeffs[i] * gain
      self.buffer[out_pos] = self.buffer[out_pos] + s
    end
  end
end

--- Peak-normalize internal buffer to ceiling (default 0.98)
-- @param ceiling number Max peak value (0.0..1.0)
function OverlapAdd:normalize(ceiling)
  ceiling = ceiling or 0.98

  local max_peak = 0.0
  for i = 1, self.length do
    local abs_val = math.abs(self.buffer[i])
    if abs_val > max_peak then
      max_peak = abs_val
    end
  end

  if max_peak > 1e-12 then
    local scale = ceiling / max_peak
    for i = 1, self.length do
      self.buffer[i] = self.buffer[i] * scale
    end
  end

  return max_peak
end

return OverlapAdd
