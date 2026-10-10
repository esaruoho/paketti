-- SampleBrain/analysis/BlockGenerator.lua
-- Generates Blocks from a SourceRef using memory-efficient referencing

local Block = require("SampleBrain.model.Block")
local Constants = require("SampleBrain.Constants")

local BlockGenerator = {}

--- Generate array of Blocks from a SourceRef
-- @param source_ref table SourceRef instance
-- @param block_size integer Block size in samples (e.g. 1024)
-- @param overlap number Overlap fraction 0.0..0.9 (default 0.5)
-- @param window_type integer Window type constant
-- @param start_id integer Starting ID for generated blocks (default 1)
-- @return table Array of Block instances
-- @return integer Next available block ID
function BlockGenerator.generate(source_ref, block_size, overlap, window_type, start_id)
  block_size = block_size or Constants.DEFAULT_BLOCK_SIZE
  overlap = overlap or Constants.DEFAULT_OVERLAP
  window_type = window_type or Constants.WINDOW_HANN
  local block_id = start_id or 1

  local hop = math.max(1, math.floor(block_size * (1.0 - overlap)))
  local total_samples = source_ref.range_end - source_ref.range_start + 1
  local blocks = {}
  
  local pos = 1
  local source_block_index = 1
  
  while pos + block_size - 1 <= total_samples do
    local blk = Block.create(block_id, source_ref, source_block_index, pos, block_size, window_type)
    blocks[#blocks + 1] = blk
    
    block_id = block_id + 1
    source_block_index = source_block_index + 1
    pos = pos + hop
  end

  return blocks, block_id
end

return BlockGenerator
