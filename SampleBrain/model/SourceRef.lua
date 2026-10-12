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

--- Get the Renoise Sample object, if valid and identity matches
function SourceRef:get_renoise_sample()
  if not self.instrument_index or not self.sample_index then return nil end
  if not renoise or not renoise.song then return nil end
  local song = renoise.song()
  local inst = song.instruments[self.instrument_index]
  if not inst then return nil end
  local smp = inst.samples[self.sample_index]
  if not smp then return nil end
  
  -- Validate sample identity by name to prevent reading the wrong sample after structural edits
  if self.name and self.name ~= "" and smp.name ~= self.name then
    return nil
  end
  return smp
end

--- Re-read source PCM buffer from Renoise using current settings
-- @param channel_mode integer Channel mode
-- @param use_selection boolean Selection flag
-- @return boolean true if reload succeeded
-- @return string error message if reload failed
function SourceRef:reload(channel_mode, use_selection)
  local smp = self:get_renoise_sample()
  if not smp or not smp.sample_buffer or not smp.sample_buffer.has_sample_data then
    return false, string.format("Source sample '%s' no longer exists in Renoise.", self.name)
  end

  local SampleReader = require("SampleBrain.renoise.SampleReader")
  
  -- When reloading, use the exact range captured when the sample was added,
  -- UNLESS the user explicitly toggled "Selection Only" off, in which case we read the whole buffer.
  local start_f = use_selection and self.captured_range_start or 1
  local end_f = use_selection and self.captured_range_end or smp.sample_buffer.number_of_frames

  local pcm, rate, num_ch = SampleReader.read_channel_exact(smp, channel_mode, start_f, end_f)
  if not pcm then
    return false, string.format("Failed to read audio data for '%s'.", self.name)
  end

  local pcm_l, pcm_r = SampleReader.read_stereo_exact(smp, start_f, end_f)

  self.pcm = pcm
  self.pcm_left = pcm_l
  self.pcm_right = pcm_r
  self.num_channels = num_ch
  self.sample_rate = rate
  self.range_start = 1
  self.range_end = #pcm
  return true
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

--- Get stereo PCM slices (left, right) from this source
-- @param start_frame number 1-based frame relative to source's range_start
-- @param length number Length of slice
-- @return table Left channel slice
-- @return table Right channel slice
function SourceRef:get_stereo_slice(start_frame, length)
  if not self.pcm_left or not self.pcm_right or self.num_channels == 1 then
    local mono = self:get_pcm_slice(start_frame, length)
    return mono, mono
  end

  local slice_l = {}
  local slice_r = {}
  local abs_start = self.range_start + start_frame - 1
  for i = 1, length do
    local idx = abs_start + i - 1
    if idx <= self.range_end then
      slice_l[i] = self.pcm_left[idx] or 0.0
      slice_r[i] = self.pcm_right[idx] or 0.0
    else
      slice_l[i] = 0.0
      slice_r[i] = 0.0
    end
  end
  return slice_l, slice_r
end

return SourceRef
