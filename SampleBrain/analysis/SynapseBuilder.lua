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
function SynapseBuilder.build_fixed(brain_blocks, max_synapses, ratio, n_ratio, fft_start, fft_end, job, channel)
  max_synapses = math.min(max_synapses or 1000, 1000)
  ratio = ratio or Constants.DEFAULT_RATIO
  n_ratio = n_ratio or Constants.DEFAULT_N_RATIO
  fft_start = fft_start or 1

  local total_blocks = #brain_blocks
  if total_blocks == 0 then return 0 end

  local num_to_store_limit = math.min(max_synapses, total_blocks - 1)
  local total_synapses_created = 0

  -- 1. Extract feature arrays to avoid heavy table/property lookups in inner loops
  local features = {}
  for i = 1, total_blocks do
    local b = brain_blocks[i]
    if channel == "left" then
      features[i] = { fft = b.fft_l or b.fft, mfcc = b.mfcc_l or b.mfcc, n_fft = b.n_fft_l or b.n_fft, n_mfcc = b.n_mfcc_l or b.n_mfcc }
    elseif channel == "right" then
      features[i] = { fft = b.fft_r or b.fft, mfcc = b.mfcc_r or b.mfcc, n_fft = b.n_fft_r or b.n_fft, n_mfcc = b.n_mfcc_r or b.n_mfcc }
    else
      features[i] = { fft = b.fft, mfcc = b.mfcc, n_fft = b.n_fft, n_mfcc = b.n_mfcc }
    end
  end

  -- 2. Build symmetric distance matrix (cuts math by exactly half)
  local distances = {}
  for i = 1, total_blocks do distances[i] = {} end

  for i = 1, total_blocks do
    if job and job.cancelled then return 0 end
    local f_a = features[i]
    for j = i + 1, total_blocks do
      local f_b = features[j]
      
      -- Inline Distance.compare_descriptors math to avoid function call overhead
      local fft_len = math.max(0, math.min(fft_end or #f_a.fft, #f_a.fft, #f_b.fft) - (fft_start or 1) + 1)
      local mfcc_len = math.min(#f_a.mfcc, #f_b.mfcc)
      
      local raw_dist = 0.0
      if ratio < 1.0 and fft_len > 0 then
        local acc = 0.0
        for k = fft_start, fft_start + fft_len - 1 do
          local diff = f_a.fft[k] - f_b.fft[k]
          acc = acc + (diff * diff)
        end
        raw_dist = (acc / #f_a.fft) * Constants.FFT_BIAS
      end
      if ratio > 0.0 and mfcc_len > 0 then
        local acc = 0.0
        for k = 1, mfcc_len do
          local diff = f_a.mfcc[k] - f_b.mfcc[k]
          acc = acc + (diff * diff)
        end
        local m_dist = (acc / mfcc_len)
        if ratio == 1.0 then raw_dist = m_dist else raw_dist = raw_dist * (1.0 - ratio) + m_dist * ratio end
      end

      local n_dist = 0.0
      if n_ratio > 0.0 then
        local n_fft_len = math.max(0, math.min(fft_end or #f_a.n_fft, #f_a.n_fft, #f_b.n_fft) - (fft_start or 1) + 1)
        local n_mfcc_len = math.min(#f_a.n_mfcc, #f_b.n_mfcc)
        if ratio < 1.0 and n_fft_len > 0 then
          local acc = 0.0
          for k = fft_start, fft_start + n_fft_len - 1 do
            local diff = f_a.n_fft[k] - f_b.n_fft[k]
            acc = acc + (diff * diff)
          end
          n_dist = (acc / #f_a.n_fft) * Constants.FFT_BIAS
        end
        if ratio > 0.0 and n_mfcc_len > 0 then
          local acc = 0.0
          for k = 1, n_mfcc_len do
            local diff = f_a.n_mfcc[k] - f_b.n_mfcc[k]
            acc = acc + (diff * diff)
          end
          local m_dist = (acc / n_mfcc_len)
          if ratio == 1.0 then n_dist = m_dist else n_dist = n_dist * (1.0 - ratio) + m_dist * ratio end
        end
      end

      local dist = (n_ratio == 0.0) and raw_dist or (raw_dist * (1.0 - n_ratio) + n_dist * n_ratio)

      distances[i][j] = dist
      distances[j][i] = dist
    end

    if job and (i % 20 == 0) then
      JobRunner.yield(job, (i / total_blocks) * 0.5, "Building distance matrix...", false)
    end
  end

  -- 3. Extract Nearest Neighbors from symmetric matrix
  local temp_graph = {}
  for i = 1, total_blocks do
    if job and job.cancelled then return 0 end
    local candidates = {}
    local row = distances[i]
    for j = 1, total_blocks do
      if i ~= j then
        candidates[#candidates + 1] = { index = j, distance = row[j] }
      end
    end

    table.sort(candidates, function(a, b) return a.distance < b.distance end)

    local block_synapses = {}
    local num_to_store = math.min(num_to_store_limit, #candidates)
    for n = 1, num_to_store do
      block_synapses[n] = candidates[n].index
    end
    temp_graph[i] = block_synapses
    total_synapses_created = total_synapses_created + #block_synapses

    if job and (i % 50 == 0) then
      JobRunner.yield(job, 0.5 + (i / total_blocks) * 0.5, "Sorting graph...", false)
    end
  end

  -- Atomic commit to live blocks
  for i = 1, total_blocks do
    if channel == "left" then
      brain_blocks[i].synapses_l = temp_graph[i]
    elseif channel == "right" then
      brain_blocks[i].synapses_r = temp_graph[i]
    else
      brain_blocks[i].synapses = temp_graph[i]
    end
  end

  return total_synapses_created
end

return SynapseBuilder
