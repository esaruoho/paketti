-- SampleBrain/matching/BasicMatcher.lua
-- Basic exhaustive search matcher (finds global minimum distance block)

local Distance = require("SampleBrain.dsp.Distance")
local Constants = require("SampleBrain.Constants")

local BasicMatcher = {}

--- Find closest brain block for a given target block
-- @param target_block table Target Block model
-- @param brain_blocks table Array of brain Block models
-- @param ratio number FFT vs MFCC ratio (0..1)
-- @param n_ratio number Raw vs Normalized ratio (0..1)
-- @param usage_importance number Usage/novelty penalty weight
-- @return table Best matching brain Block
-- @return number Minimum distance score
function BasicMatcher.match(target_block, brain_blocks, ratio, n_ratio, usage_importance)
  if #brain_blocks == 0 then return nil, math.huge end

  local min_dist = math.huge
  local best_block = nil

  for i = 1, #brain_blocks do
    local b = brain_blocks[i]
    local dist = Distance.compare_blocks(target_block, b, ratio, n_ratio, usage_importance)
    if dist < min_dist then
      min_dist = dist
      best_block = b
    end
  end

  return best_block, min_dist
end

return BasicMatcher
