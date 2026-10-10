-- SampleBrain/renoise/SampleWriter.lua
-- Writes float PCM array into a new Renoise Instrument / Sample

local SampleWriter = {}

--- Create a new instrument and write mono PCM buffer into it
-- @param pcm table 1-indexed array of float samples
-- @param sample_rate number Sample rate (default 44100)
-- @param name_prefix string Instrument name prefix
-- @return renoise.Instrument Created instrument
-- @return renoise.Sample Created sample
function SampleWriter.write_new_instrument(pcm, sample_rate, name_prefix)
  sample_rate = sample_rate or 44100
  name_prefix = name_prefix or "SampleBrain"

  local song = renoise.song()
  local inst = song:insert_instrument_at(#song.instruments + 1)
  inst.name = name_prefix .. " Output"

  local smp = inst:insert_sample_at(1)
  smp.name = name_prefix .. " Render"

  local num_frames = #pcm
  if num_frames == 0 then
    return inst, smp
  end

  local buffer = smp.sample_buffer
  buffer:create_sample_data(sample_rate, 32, 1, num_frames)

  buffer:prepare_sample_data_changes()
  for f = 1, num_frames do
    buffer:set_sample_data(1, f, pcm[f])
  end
  buffer:finalize_sample_data_changes()

  -- Select newly created instrument
  song.selected_instrument_index = #song.instruments

  return inst, smp
end

return SampleWriter
