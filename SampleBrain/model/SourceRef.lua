-- SampleBrain/model/SourceRef.lua
-- Memory-efficient reference to audio source (replaces per-block PCM duplication)

local SourceRef = {}
SourceRef.__index = SourceRef

--- Create a new reference to an audio source (e.g. Renoise sample)
-- @param id number Unique ID for this source
-- @param name string Display name for the source
-- @param pcm table The full PCM float array for the entire source
-- @param sample_rate number Sample rate
-- @param range_start number (Optional) 1-based start frame in PCM
-- @param range_end number (Optional) 1-based end frame in PCM
function SourceRef.create(id, name, pcm, sample_rate, range_start, range_end)
  local self_obj = setmetatable({
    id = id,
    name = name,
    pcm = pcm,
    sample_rate = sample_rate,
    range_start = range_start or 1,
    range_end = range_end or #pcm,
    enabled = true
  }, SourceRef)
  
  return self_obj
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
