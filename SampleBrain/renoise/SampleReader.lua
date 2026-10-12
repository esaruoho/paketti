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

  if use_selection then
    local s = buffer.selection_start
    local e = buffer.selection_end
    if s and e and e >= s and s > 0 then
      start_frame = s
      end_frame = math.min(buffer.number_of_frames, e)
    end
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
      -- Mono sum (SampleBrain upstream compatibility)
      for f = start_frame, end_frame do
        local l = buffer:sample_data(1, f)
        local r = buffer:sample_data(2, f)
        pcm[#pcm + 1] = l + r
      end
    end
  end

  return pcm, sample_rate, num_channels
end

--- Extract exactly a given block of samples without using dynamic properties
function SampleReader.read_channel_exact(renoise_sample, channel_mode, start_frame, end_frame)
  channel_mode = channel_mode or Constants.CHANNEL_MIX
  renoise_sample = renoise_sample or renoise.song().selected_sample
  
  if not renoise_sample or not renoise_sample.sample_buffer or not renoise_sample.sample_buffer.has_sample_data then
    return nil, "No sample data available"
  end

  local buffer = renoise_sample.sample_buffer
  start_frame = math.max(1, start_frame or 1)
  end_frame = math.min(end_frame or buffer.number_of_frames, buffer.number_of_frames)

  if start_frame > end_frame then return nil, "Invalid sample range" end

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
      -- Mono sum (SampleBrain upstream compatibility)
      for f = start_frame, end_frame do
        local l = buffer:sample_data(1, f)
        local r = buffer:sample_data(2, f)
        pcm[#pcm + 1] = l + r
      end
    end
  end

  return pcm, sample_rate, num_channels
end

--- Read stereo sample buffer arrays (pcm_left, pcm_right)
function SampleReader.read_stereo_exact(renoise_sample, start_frame, end_frame)
  renoise_sample = renoise_sample or renoise.song().selected_sample
  if not renoise_sample or not renoise_sample.sample_buffer or not renoise_sample.sample_buffer.has_sample_data then
    return nil, nil, "No sample data available"
  end

  local buffer = renoise_sample.sample_buffer
  start_frame = math.max(1, start_frame or 1)
  end_frame = math.min(end_frame or buffer.number_of_frames, buffer.number_of_frames)

  local num_channels = buffer.number_of_channels
  local sample_rate = buffer.sample_rate

  local pcm_l = {}
  local pcm_r = {}

  if num_channels == 1 then
    for f = start_frame, end_frame do
      local s = buffer:sample_data(1, f)
      pcm_l[#pcm_l + 1] = s
      pcm_r[#pcm_r + 1] = s
    end
  else
    for f = start_frame, end_frame do
      pcm_l[#pcm_l + 1] = buffer:sample_data(1, f)
      pcm_r[#pcm_r + 1] = buffer:sample_data(2, f)
    end
  end

  return pcm_l, pcm_r, sample_rate, num_channels
end

return SampleReader
