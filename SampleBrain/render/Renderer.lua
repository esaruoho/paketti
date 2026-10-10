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
  local usage_falloff = options.usage_falloff or Constants.USAGE_FALLOFF
  local stickiness = options.stickiness or Constants.DEFAULT_STICKINESS
  local fft_start = options.fft_start or 1
  local fft_end = options.fft_end or Constants.FFT_BINS_CROPPED
  local algo = options.algo or Constants.ALGO_BASIC
  local stretch = options.stretch or 1
  local autotune = options.autotune or 0.0
  local n_mix = options.n_mix or 0.0
  local target_mix = options.target_mix or 0.0
  local brain_gain = options.brain_gain or 1.0
  local slide_error = options.slide_error or Constants.DEFAULT_SLIDE_ERROR

  local matcher = Matcher.create(brain_blocks)
  matcher:reset(options.seed)

  local hop = math.max(1, math.floor(block_size * (1.0 - overlap)))
  local decisions = {}

  local target_idx = 1
  local render_step = 0

  -- Phase 1: Search & Decision Stream Generation
  while target_idx <= #target_blocks do
    local target_blk = target_blocks[target_idx]
    local matched_blk, dist, err = matcher:search(target_blk, {
      algo = algo,
      ratio = ratio,
      n_ratio = n_ratio,
      usage_importance = usage_importance,
      usage_falloff = usage_falloff,
      stickiness = stickiness,
      fft_start = fft_start,
      fft_end = fft_end,
      num_synapses = options.num_synapses
    })

    if not matched_blk then
      return nil, err or "Matcher returned no block"
    end

    decisions[#decisions + 1] = {
        target_blk = target_blk,
        matched_blk = matched_blk,
        render_step = render_step,
        dist = dist
      }

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
      JobRunner.yield(options.job, target_idx / #target_blocks, string.format("Matching block %d / %d", target_idx, #target_blocks))
    end

    -- Safety check to prevent infinite loop in slide mode
    if render_step > #target_blocks * stretch * 10 then
      break
    end
  end

  -- Phase 2: Overlap-Add Rendering from Decision Stream
  local total_output_frames = math.max(1, (render_step - 1) * hop + block_size)
  local ola = OverlapAdd.create(total_output_frames)

  for idx = 1, #decisions do
    local dec = decisions[idx]
    local target_blk = dec.target_blk
    local matched_blk = dec.matched_blk

    local pcm_raw = matched_blk:get_windowed_pcm() or {}
    local pcm_n = matched_blk:get_normalized_windowed_pcm() or pcm_raw

    local target_pcm = target_blk:get_windowed_pcm() or {}
    local target_len = #target_pcm

    local grain = {}
    local pitch_scale = 1.0

    -- Autotune pitch shifting scale
    if autotune > 0 and target_blk.dominant_freq and matched_blk.dominant_freq and matched_blk.dominant_freq > 0 then
      pitch_scale = target_blk.dominant_freq / matched_blk.dominant_freq
      local max_scale = 1.0 + (autotune * autotune) * 100.0
      if pitch_scale > max_scale then pitch_scale = max_scale end
      if pitch_scale < 1.0 / max_scale then pitch_scale = 1.0 / max_scale end
    end

    local src_len = math.max(#pcm_raw, #pcm_n)
    
    -- Source cursor rendering matching upstream SampleBrain
    for i = 1, target_len do
      local src_pos = ((i - 1) * pitch_scale) % src_len
      local idx0 = math.floor(src_pos)
      local idx1 = (idx0 + 1) % src_len
      local frac = src_pos - idx0

      -- +1 for 1-based indexing in Lua
      local s0_r = pcm_raw[idx0 + 1] or 0.0
      local s1_r = pcm_raw[idx1 + 1] or 0.0
      local r_s = s0_r * (1.0 - frac) + s1_r * frac

      local s0_n = pcm_n[idx0 + 1] or 0.0
      local s1_n = pcm_n[idx1 + 1] or 0.0
      local n_s = s0_n * (1.0 - frac) + s1_n * frac

      local brain_sample = r_s * (1.0 - n_mix) + n_s * n_mix
      local t_s = target_pcm[i] or 0.0

      grain[i] = brain_sample * (1.0 - target_mix) + t_s * target_mix
    end

    local start_frame = dec.render_step * hop + 1
    ola:add_grain(grain, start_frame, brain_gain, Constants.WINDOW_RECTANGLE)
  end

  if options.normalize then
    ola:normalize(0.98)
  end
  return ola.buffer
end

return Renderer
