-- SampleBrain/render/Renderer.lua
-- Concatenative synthesis renderer matching C++ SampleBrain renderer.cpp

local Matcher = require("SampleBrain.matching.Matcher")
local OverlapAdd = require("SampleBrain.render.OverlapAdd")
local Constants = require("SampleBrain.Constants")
local JobRunner = require("SampleBrain.jobs.JobRunner")

local Renderer = {}

--- Resample grain PCM array by pitch_scale ratio (linear interpolation)
-- @param pcm table Original PCM array
-- @param scale number Pitch ratio (1.0 = normal speed)
-- @return table Resampled PCM array
local function resample_grain(pcm, scale)
  if math.abs(scale - 1.0) < 1e-4 or scale <= 0 then
    return pcm
  end

  local src_len = #pcm
  local dst_len = math.max(1, math.floor(src_len / scale))
  local out = {}

  for i = 1, dst_len do
    local src_pos = (i - 1) * scale + 1
    local idx0 = math.floor(src_pos)
    local idx1 = math.min(src_len, idx0 + 1)
    local frac = src_pos - idx0

    if idx0 >= src_len then
      out[i] = pcm[src_len] or 0.0
    else
      local s0 = pcm[idx0] or 0.0
      local s1 = pcm[idx1] or 0.0
      out[i] = s0 * (1.0 - frac) + s1 * frac
    end
  end

  return out
end

--- Render concatenative output from brain and target blocks
-- @param brain_blocks table Array of brain Block instances
-- @param target_blocks table Array of target Block instances
-- @param options table Render options table
-- @return table Output float PCM array
function Renderer.render(brain_blocks, target_blocks, options)
  options = options or {}
  local block_size = options.block_size or Constants.DEFAULT_BLOCK_SIZE
  local overlap = options.overlap or Constants.DEFAULT_OVERLAP
  local window_type = options.window_type or Constants.WINDOW_HANN
  local ratio = options.ratio or Constants.DEFAULT_RATIO
  local n_ratio = options.n_ratio or Constants.DEFAULT_N_RATIO
  local usage_importance = options.usage_importance or Constants.DEFAULT_USAGE_IMPORTANCE
  local stickiness = options.stickiness or Constants.DEFAULT_STICKINESS
  local algo = options.algo or Constants.ALGO_BASIC
  local stretch = options.stretch or 1
  local autotune = options.autotune or 0.0
  local n_mix = options.n_mix or 0.0
  local brain_gain = options.brain_gain or 1.0
  local slide_error = options.slide_error or Constants.DEFAULT_SLIDE_ERROR

  local matcher = Matcher.create(brain_blocks)
  matcher:reset()

  local hop = math.max(1, math.floor(block_size * (1.0 - overlap)))
  local total_output_frames = (#target_blocks * stretch - 1) * hop + block_size

  local ola = OverlapAdd.create(total_output_frames)

  local target_idx = 1
  local render_step = 0

  while target_idx <= #target_blocks do
    local target_blk = target_blocks[target_idx]
    local matched_blk, dist = matcher:search(target_blk, {
      algo = algo,
      ratio = ratio,
      n_ratio = n_ratio,
      usage_importance = usage_importance,
      stickiness = stickiness,
      num_synapses = options.num_synapses
    })

    if matched_blk and (matched_blk.pcm or matched_blk.n_fft) then
      local pcm_raw = matched_blk.pcm or {}
      local pcm_n = matched_blk.n_pcm or pcm_raw

      -- Construct grain blending raw and normalized PCM, and target mix
      local grain = {}
      local len = math.max(#pcm_raw, #pcm_n)
      local target_pcm = target_blk:get_pcm() or {}
      for i = 1, len do
        local r_s = pcm_raw[i] or 0.0
        local n_s = pcm_n[i] or 0.0
        local brain_sample = r_s * (1.0 - n_mix) + n_s * n_mix
        
        local t_s = target_pcm[i] or 0.0
        grain[i] = brain_sample * (1.0 - target_mix) + t_s * target_mix
      end

      -- Autotune pitch shifting
      if autotune > 0 and target_blk.dominant_freq and matched_blk.dominant_freq and matched_blk.dominant_freq > 0 then
        local pitch_scale = target_blk.dominant_freq / matched_blk.dominant_freq
        local max_scale = 1.0 + (autotune * autotune) * 100.0
        if pitch_scale > max_scale then pitch_scale = max_scale end
        if pitch_scale < 1.0 / max_scale then pitch_scale = 1.0 / max_scale end

        grain = resample_grain(grain, pitch_scale)
      end

      local start_frame = render_step * hop + 1
      ola:add_grain(grain, start_frame, brain_gain, window_type)
    end

    -- Target step logic (incorporating Synaptic Slide & Stretch)
    if algo == Constants.ALGO_SYNAPTIC_SLIDE then
      if matcher.current_error < slide_error and (render_step % stretch == 0) then
        target_idx = target_idx + 1
      end
    else
      if render_step % stretch == 0 then
        target_idx = target_idx + 1
      end
    end

    render_step = render_step + 1
    
    if options.job and render_step % 20 == 0 then
      JobRunner.yield(options.job, target_idx / #target_blocks, string.format("Rendering blocks %d / %d", target_idx, #target_blocks))
    end

    -- Safety check to prevent infinite loop
    if render_step > #target_blocks * stretch * 10 then
      break
    end
  end

  ola:normalize(0.98)
  return ola.buffer
end

return Renderer
