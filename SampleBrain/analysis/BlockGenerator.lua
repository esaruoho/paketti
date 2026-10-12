-- SampleBrain/analysis/BlockGenerator.lua
-- Generates Blocks from a SourceRef using memory-efficient referencing

local Block = require("SampleBrain.model.Block")
local Constants = require("SampleBrain.Constants")
local JobRunner = require("SampleBrain.jobs.JobRunner")

local BlockGenerator = {}

--- Generate array of Blocks from a SourceRef
-- @param source_ref table SourceRef instance
-- @param block_size integer Block size in samples (e.g. 1024)
-- @param overlap number Overlap fraction 0.0..0.9 (default 0.5)
-- @param window_type integer Window type constant
-- @param start_id integer Starting ID for generated blocks (default 1)
-- @param job table Optional job object for yielding
-- @return table Array of Block instances
-- @return integer Next available block ID
function BlockGenerator.generate(source_ref, block_size, overlap, window_type, start_id, job)
  block_size = block_size or Constants.DEFAULT_BLOCK_SIZE
  overlap = overlap or Constants.DEFAULT_OVERLAP
  window_type = window_type or Constants.WINDOW_HANN
  local block_id = start_id or 1

  local CANONICAL_RATE = 44100
  local rate_ratio = (source_ref.sample_rate and source_ref.sample_rate > 0) and (source_ref.sample_rate / CANONICAL_RATE) or 1.0
  local native_block_size = math.max(1, math.floor(block_size * rate_ratio + 0.5))
  local canonical_hop = math.max(1, math.floor(block_size * (1.0 - overlap)))
  local native_hop = math.max(1, math.floor(canonical_hop * rate_ratio + 0.5))

  local total_samples = source_ref.range_end - source_ref.range_start + 1
  local blocks = {}
  
  local block_number = 0
  local source_block_index = 1
  local estimated_total_blocks = math.max(1, math.floor((total_samples - native_block_size) / math.max(1, native_hop)) + 1)

  while true do
    local pos = math.floor(block_number * canonical_hop * rate_ratio + 0.5) + 1
    if pos + native_block_size - 1 > total_samples then break end

    local blk = Block.create(block_id, source_ref, source_block_index, pos, native_block_size, block_size, window_type)
    blocks[#blocks + 1] = blk
    
    block_id = block_id + 1
    source_block_index = source_block_index + 1
    block_number = block_number + 1

    if job then
      local pct = math.min(1.0, pos / math.max(1, total_samples))
      JobRunner.yield(job, pct, string.format("Block %d/%d (%d%%)", source_block_index, estimated_total_blocks, math.floor(pct * 100)), false)
    end
  end

  return blocks, block_id
end

return BlockGenerator
