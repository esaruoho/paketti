-- SampleBrain/renoise/SampleReader.lua
-- Reads Renoise SampleBuffer into 1-indexed mono float array

local SampleReader = {}

--- Read sample buffer into mono float array
-- @param renoise_sample renoise.Sample instance (default selected_sample)
-- @return table 1-indexed mono float array
-- @return number Sample rate
function SampleReader.read_mono(renoise_sample)
  renoise_sample = renoise_sample or renoise.song().selected_sample
  if not renoise_sample or not renoise_sample.sample_buffer or not renoise_sample.sample_buffer.has_sample_data then
    return nil, "No sample data available"
  end

  local buffer = renoise_sample.sample_buffer
  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate

  local pcm = {}

  if num_channels == 1 then
    for f = 1, num_frames do
      pcm[f] = buffer:sample_data(1, f)
    end
  else
    -- Mono mix down
    for f = 1, num_frames do
      local l = buffer:sample_data(1, f)
      local r = buffer:sample_data(2, f)
      pcm[f] = (l + r) * 0.5
    end
  end

  return pcm, sample_rate
end

return SampleReader
