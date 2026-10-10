-- SampleBrain/renoise/SampleReader.lua
-- Reads Renoise SampleBuffer into 1-indexed mono float array, with channel selection

local Constants = require("SampleBrain.Constants")

local SampleReader = {}

--- Read sample buffer into mono float array, based on channel_mode
-- @param renoise_sample renoise.Sample instance (default selected_sample)
-- @param channel_mode integer Channel to read (Constants.CHANNEL_MIX, LEFT, RIGHT)
-- @param use_selection boolean Whether to respect sample selection_range
-- @return table 1-indexed mono float array
-- @return number Sample rate
-- @return integer Source number of channels
function SampleReader.read_channel(renoise_sample, channel_mode, use_selection)
  channel_mode = channel_mode or Constants.CHANNEL_MIX
  renoise_sample = renoise_sample or renoise.song().selected_sample
  
  if not renoise_sample or not renoise_sample.sample_buffer or not renoise_sample.sample_buffer.has_sample_data then
    return nil, "No sample data available"
  end

  local buffer = renoise_sample.sample_buffer
  local start_frame = 1
  local end_frame = buffer.number_of_frames

  if use_selection and renoise_sample.selection_range and #renoise_sample.selection_range == 2 then
    start_frame = math.max(1, renoise_sample.selection_range[1])
    end_frame = math.min(buffer.number_of_frames, renoise_sample.selection_range[2])
  end

  local num_channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate

  local pcm = {}

  if num_channels == 1 then
    for f = start_frame, end_frame do
      pcm[#pcm + 1] = buffer:sample_data(1, f)
    end
  else
    if channel_mode == Constants.CHANNEL_LEFT then
      for f = start_frame, end_frame do
        pcm[#pcm + 1] = buffer:sample_data(1, f)
      end
    elseif channel_mode == Constants.CHANNEL_RIGHT then
      for f = start_frame, end_frame do
        pcm[#pcm + 1] = buffer:sample_data(2, f)
      end
    else
      -- Mono mix down
      for f = start_frame, end_frame do
        local l = buffer:sample_data(1, f)
        local r = buffer:sample_data(2, f)
        pcm[#pcm + 1] = (l + r) * 0.5
      end
    end
  end

  return pcm, sample_rate, num_channels
end

return SampleReader
