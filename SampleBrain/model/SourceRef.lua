-- SampleBrain/model/SourceRef.lua
-- Memory-efficient reference to audio source (replaces per-block PCM duplication)

local SourceRef = {}
SourceRef.__index = SourceRef

--- Create a new reference to an audio source (e.g. Renoise sample)
-- @param id number Unique ID for this source
-- @param name string Display name for the source
-- @param pcm table The full PCM float array for the entire source
-- @param sample_rate number Sample rate
-- @param instrument_index integer (Optional) Renoise instrument index
-- @param sample_index integer (Optional) Renoise sample index
-- @param range_start number Fixed selection start captured at add time
-- @param range_end number Fixed selection end captured at add time
function SourceRef.create(id, name, pcm, sample_rate, instrument_index, sample_index, range_start, range_end)
  local self_obj = setmetatable({
    id = id,
    name = name,
    pcm = pcm,
    sample_rate = sample_rate,
    instrument_index = instrument_index,
    sample_index = sample_index,
    -- Store the explicit bounds provided when added.
    -- Default to the size of the PCM array if none provided.
    captured_range_start = range_start or 1,
    captured_range_end = range_end or #pcm,
    range_start = 1,
    range_end = #pcm,
    enabled = true
  }, SourceRef)
  
  return self_obj
end

--- Get the Renoise Sample object, if valid
function SourceRef:get_renoise_sample()
  if not self.instrument_index or not self.sample_index then return nil end
  if not renoise or not renoise.song then return nil end
  local song = renoise.song()
  local inst = song.instruments[self.instrument_index]
  if not inst then return nil end
  local smp = inst.samples[self.sample_index]
  if not smp then return nil end
  if smp.name ~= self.name then
    -- Optional fallback warning if reordered, but for now we trust the indices.
    -- To be robust against reorders, we'd loop instruments/samples seeking id/name pairs.
  end
  return smp
end

--- Re-read source PCM buffer from Renoise using current settings
-- @param channel_mode integer Channel mode
-- @param use_selection boolean Selection flag
function SourceRef:reload(channel_mode, use_selection)
  local smp = self:get_renoise_sample()
  if smp then
    local SampleReader = require("SampleBrain.renoise.SampleReader")
    
    -- When reloading, use the exact range captured when the sample was added,
    -- UNLESS the user explicitly toggled "Selection Only" off, in which case we read the whole buffer.
    local start_f = use_selection and self.captured_range_start or 1
    local end_f = use_selection and self.captured_range_end or smp.sample_buffer.number_of_frames

    local pcm, rate = SampleReader.read_channel_exact(smp, channel_mode, start_f, end_f)
    if pcm then
      self.pcm = pcm
      self.sample_rate = rate
      self.range_start = 1
      self.range_end = #pcm
    end
  end
end

--- Get a slice of PCM data from this source
-- @param start_frame number 1-based frame relative to the source's range_start
-- @param length number Number of frames to extract
-- @return table Extracted float array
function SourceRef:get_pcm_slice(start_frame, length)
  local slice = {}
  local abs_start = self.range_start + start_frame - 1
  for i = 1, length do
    local idx = abs_start + i - 1
    if idx <= self.range_end then
      slice[i] = self.pcm[idx]
    else
      slice[i] = 0.0 -- Zero pad if asking beyond end
    end
  end
  return slice
end

return SourceRef
