-- SampleBrain/matching/Matcher.lua
-- Stateful search engine implementing Basic, Reversed, Synaptic, and Synaptic-Slide search algorithms

local Distance = require("SampleBrain.dsp.Distance")
local Constants = require("SampleBrain.Constants")

local Matcher = {}
Matcher.__index = Matcher

function Matcher.create(brain_blocks)
  return setmetatable({
    brain_blocks = brain_blocks or {},
    current_block_index = 1,
    current_error = 0.0
  }, Matcher)
end

function Matcher:reset(seed)
  if seed then
    math.randomseed(seed)
  end
  if #self.brain_blocks > 0 then
    self.current_block_index = math.random(1, #self.brain_blocks)
  else
    self.current_block_index = 1
  end
  self.current_error = 0.0
  for i = 1, #self.brain_blocks do
    self.brain_blocks[i].usage = 0.0
  end
end

function Matcher:deplete_usage(falloff)
  falloff = falloff or Constants.USAGE_FALLOFF
  for i = 1, #self.brain_blocks do
    local b = self.brain_blocks[i]
    b.usage = (b.usage or 0.0) * falloff
  end
end

function Matcher:stickify(target_block, closest_index, dist, options)
  local stickiness = options.stickiness or Constants.DEFAULT_STICKINESS
  local mode = options.stickiness_mode or Constants.STICKINESS_UPSTREAM
  local next_index = self.current_block_index + 1

  if stickiness > 0 and next_index <= #self.brain_blocks then
    local next_blk = self.brain_blocks[next_index]
    
    local allow_stick = false
    if mode == Constants.STICKINESS_SAME_SOURCE then
      allow_stick = next_blk.source_ref.enabled and next_blk.source_ref.id == self.brain_blocks[self.current_block_index].source_ref.id
    else
      -- Upstream: just advance without checking source boundary, as long as it's enabled
      allow_stick = next_blk.source_ref.enabled
    end

    if allow_stick then
      local dist_to_next = Distance.compare_blocks(
        target_block, next_blk,
        options.ratio, options.n_ratio, options.usage_importance,
        options.fft_start, options.fft_end
      )

      if dist_to_next * (1.0 - stickiness) < dist * stickiness then
        self.current_block_index = next_index
        return self.current_block_index
      end
    end
  end

  self.current_block_index = closest_index
  return self.current_block_index
end

--- Basic Minimum Distance Search
function Matcher:search_basic(target_block, options)
  local min_dist = math.huge
  local closest_index = nil

  for i = 1, #self.brain_blocks do
    local b = self.brain_blocks[i]
    if b.source_ref.enabled then
      local dist = Distance.compare_blocks(
        target_block, b,
        options.ratio, options.n_ratio, options.usage_importance,
        options.fft_start, options.fft_end
      )
      if dist < min_dist then
        min_dist = dist
        closest_index = i
      end
    end
  end

  if not closest_index then
    return nil, math.huge, "No enabled brain blocks"
  end

  self:deplete_usage(options.usage_falloff)
  self.brain_blocks[closest_index].usage = (self.brain_blocks[closest_index].usage or 0) + Constants.USAGE_FACTOR
  self.current_error = min_dist

  local chosen_idx = self:stickify(target_block, closest_index, min_dist, options)
  return self.brain_blocks[chosen_idx], min_dist
end

--- Reversed Maximum Distance Search
function Matcher:search_reversed(target_block, options)
  local max_dist = -1.0
  local furthest_index = nil

  for i = 1, #self.brain_blocks do
    local b = self.brain_blocks[i]
    if b.source_ref.enabled then
      local dist = Distance.compare_blocks(
        target_block, b,
        options.ratio, options.n_ratio, options.usage_importance,
        options.fft_start, options.fft_end
      )
      if dist > max_dist then
        max_dist = dist
        furthest_index = i
      end
    end
  end

  if not furthest_index then
    return nil, math.huge, "No enabled brain blocks"
  end

  self:deplete_usage(options.usage_falloff)
  self.brain_blocks[furthest_index].usage = (self.brain_blocks[furthest_index].usage or 0) + Constants.USAGE_FACTOR
  self.current_error = max_dist
  self.current_block_index = furthest_index

  return self.brain_blocks[furthest_index], max_dist
end

--- Synaptic Graph Search
function Matcher:search_synaptic(target_block, options)
  local cur_block = self.brain_blocks[self.current_block_index]
  if not cur_block or not cur_block.synapses or #cur_block.synapses == 0 then
    -- Fallback to basic search if graph not initialized
    return self:search_basic(target_block, options)
  end

  local min_dist = math.huge
  local closest_index = nil
  local num_syn = math.min(#cur_block.synapses, options.num_synapses or Constants.DEFAULT_NUM_SYNAPSES)

  for s = 1, num_syn do
    local syn_idx = cur_block.synapses[s]
    local other_blk = self.brain_blocks[syn_idx]
    if other_blk and other_blk.source_ref.enabled then
      local dist = Distance.compare_blocks(
        target_block, other_blk,
        options.ratio, options.n_ratio, options.usage_importance,
        options.fft_start, options.fft_end
      )
      if dist < min_dist then
        min_dist = dist
        closest_index = syn_idx
      end
    end
  end

  if not closest_index then
    local fallback_mode = options.fallback_mode or Constants.FALLBACK_HOLD_CURRENT
    if fallback_mode == Constants.FALLBACK_HOLD_CURRENT then
      -- If all synapses are disabled or none valid, just hold on current block (Upstream default)
      closest_index = self.current_block_index
    else
      -- Fallback to global basic search across all active blocks
      return self:search_basic(target_block, options)
    end
  end

  self:deplete_usage(options.usage_falloff)
  self.brain_blocks[self.current_block_index].usage = (self.brain_blocks[self.current_block_index].usage or 0) + Constants.USAGE_FACTOR
  self.current_error = min_dist

  local chosen_idx = self:stickify(target_block, closest_index, min_dist, options)
  return self.brain_blocks[chosen_idx], min_dist
end

--- Choose block based on search algorithm
function Matcher:search(target_block, options)
  options = options or {}
  local algo = options.algo or Constants.ALGO_BASIC

  if algo == Constants.ALGO_BASIC then
    return self:search_basic(target_block, options)
  elseif algo == Constants.ALGO_REVERSED then
    return self:search_reversed(target_block, options)
  elseif algo == Constants.ALGO_SYNAPTIC or algo == Constants.ALGO_SYNAPTIC_SLIDE then
    return self:search_synaptic(target_block, options)
  else
    return self:search_basic(target_block, options)
  end
end

return Matcher
