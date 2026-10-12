-- SampleBrain/analysis/SynapseBuilder.lua
-- Builds synaptic similarity graph across brain blocks

local Distance = require("SampleBrain.dsp.Distance")
local Constants = require("SampleBrain.Constants")
local JobRunner = require("SampleBrain.jobs.JobRunner")

local SynapseBuilder = {}

--- Build fixed nearest-neighbor synaptic graph for brain blocks (up to 1000 synapses)
-- @param brain_blocks table Array of Block instances
-- @param max_synapses integer Maximum synapses per block to store (default 1000)
-- @param ratio number FFT/MFCC mix ratio
-- @param n_ratio number Raw/Norm mix ratio
-- @param fft_start integer Optional FFT start bin
-- @param fft_end integer Optional FFT end bin
-- @param job table Optional job object for yielding
-- @return integer Total synapses created
function SynapseBuilder.build_fixed(brain_blocks, max_synapses, ratio, n_ratio, fft_start, fft_end, job)
  max_synapses = math.min(max_synapses or 1000, 1000)
  ratio = ratio or Constants.DEFAULT_RATIO
  n_ratio = n_ratio or Constants.DEFAULT_N_RATIO

  local total_blocks = #brain_blocks
  if total_blocks == 0 then return 0 end

  local num_to_store_limit = math.min(max_synapses, total_blocks - 1)
  local total_synapses_created = 0

  for i = 1, total_blocks do
    local block_a = brain_blocks[i]
    local candidates = {}

    for j = 1, total_blocks do
      if i ~= j then
        local block_b = brain_blocks[j]
        local dist = Distance.compare_blocks(block_a, block_b, ratio, n_ratio, 0.0, fft_start, fft_end)
        candidates[#candidates + 1] = { index = j, distance = dist }
      end
    end

    table.sort(candidates, function(a, b) return a.distance < b.distance end)

    block_a.synapses = {}
    local num_to_store = math.min(num_to_store_limit, #candidates)
    for n = 1, num_to_store do
      block_a.synapses[n] = candidates[n].index
    end

    total_synapses_created = total_synapses_created + #block_a.synapses

    if job then
      JobRunner.yield(job, i / total_blocks, string.format("Building synapses %d%%", math.floor(i / total_blocks * 100)), false)
    end
  end

  return total_synapses_created
end

return SynapseBuilder
