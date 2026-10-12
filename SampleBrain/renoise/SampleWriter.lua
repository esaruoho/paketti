-- SampleBrain/renoise/SampleWriter.lua
-- Writes float PCM arrays into a new Renoise Instrument / Sample

local SampleWriter = {}

--- Create a new instrument and write mono or stereo PCM buffer into it
-- @param pcm_left table 1-indexed array of float samples for left channel
-- @param pcm_right table (Optional) 1-indexed array of float samples for right channel
-- @param sample_rate number Sample rate (default 44100)
-- @param name_prefix string Instrument name prefix
-- @param insert_idx number (Optional) Target instrument index (defaults to selected_instrument_index + 1)
-- @return renoise.Instrument Created instrument
-- @return renoise.Sample Created sample
function SampleWriter.write_new_instrument(pcm_left, pcm_right, sample_rate, name_prefix, insert_idx)
  sample_rate = sample_rate or 44100
  name_prefix = name_prefix or "Paketti SampleBrain"

  local song = renoise.song()
  if not insert_idx then
    insert_idx = math.min(#song.instruments + 1, song.selected_instrument_index + 1)
  end

  local inst = song:insert_instrument_at(insert_idx)
  inst.name = name_prefix

  local smp = inst:insert_sample_at(1)
  smp.name = name_prefix .. " Render"

  local num_frames = #pcm_left
  if num_frames == 0 then
    return inst, smp
  end

  local num_channels = pcm_right and 2 or 1

  local buffer = smp.sample_buffer
  local ok = buffer:create_sample_data(sample_rate, 32, num_channels, num_frames)
  if not ok then
    song:delete_instrument_at(insert_idx)
    error("SampleBrain: Failed to allocate sample buffer memory in Renoise.")
  end

  buffer:prepare_sample_data_changes()
  if num_channels == 1 then
    for f = 1, num_frames do
      buffer:set_sample_data(1, f, pcm_left[f])
    end
  else
    for f = 1, num_frames do
      buffer:set_sample_data(1, f, pcm_left[f])
      buffer:set_sample_data(2, f, pcm_right[f] or pcm_left[f])
    end
  end
  buffer:finalize_sample_data_changes()

  -- Select newly created instrument
  song.selected_instrument_index = insert_idx

  return inst, smp
end

return SampleWriter
