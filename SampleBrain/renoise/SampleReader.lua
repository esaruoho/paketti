-- SampleBrain/renoise/SampleReader.lua
-- Reads Renoise SampleBuffer into 1-indexed mono float array, with channel selection

local Constants = require("SampleBrain.Constants")

local SampleReader = {}

--- Read sample buffer into mono float array, based on channel_mode
-- @param renoise_sample renoise.Sample instance (default selected_sample)
-- @param channel_mode integer Channel to read (Constants.CHANNEL_MIX, LEFT, RIGHT)
-- @return table 1-indexed mono float array
-- @return number Sample rate
-- @return integer Source number of channels
function SampleReader.read_channel(renoise_sample, channel_mode)
  channel_mode = channel_mode or Constants.CHANNEL_MIX
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
    if channel_mode == Constants.CHANNEL_LEFT then
      for f = 1, num_frames do
        pcm[f] = buffer:sample_data(1, f)
      end
    elseif channel_mode == Constants.CHANNEL_RIGHT then
      for f = 1, num_frames do
        pcm[f] = buffer:sample_data(2, f)
      end
    else
      -- Mono mix down
      for f = 1, num_frames do
        local l = buffer:sample_data(1, f)
        local r = buffer:sample_data(2, f)
        pcm[f] = (l + r) * 0.5
      end
    end
  end

  return pcm, sample_rate, num_channels
end

return SampleReader
