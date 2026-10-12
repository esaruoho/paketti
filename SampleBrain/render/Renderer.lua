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

  local independent_stereo = options.independent_stereo or false
  local matcher_l = Matcher.create(brain_blocks)
  local matcher_r = independent_stereo and Matcher.create(brain_blocks) or matcher_l
  matcher_l:reset(options.seed)
  if independent_stereo then matcher_r:reset((options.seed or 12345) + 1) end

  local target_rate = (target_blocks[1] and target_blocks[1].sample_rate) or Constants.DEFAULT_SAMPLE_RATE
  local canonical_hop = math.max(1, math.floor(block_size * (1.0 - overlap)))
  local exact_output_hop = canonical_hop * target_rate / Constants.DEFAULT_SAMPLE_RATE
  local decisions = {}

  local target_idx = 1
  local render_step = 0

  local slide_attempts = 0
  local max_slide_attempts = options.max_slide_attempts or 100

  -- Phase 1: Search & Decision Stream Generation
  while target_idx <= #target_blocks do
    local target_blk = target_blocks[target_idx]
    local search_opts_l = {
      algo = algo,
      ratio = ratio,
      n_ratio = n_ratio,
      usage_importance = usage_importance,
      usage_falloff = usage_falloff,
      stickiness = stickiness,
      fft_start = fft_start,
      fft_end = fft_end,
      num_synapses = options.num_synapses,
      channel = "left"
    }

    local matched_blk_l, dist_l, err_l = matcher_l:search(target_blk, search_opts_l)
    if not matched_blk_l then
      return nil, err_l or "Left matcher returned no block"
    end

    local matched_blk_r = matched_blk_l
    local dist_r = dist_l
    if independent_stereo then
      local search_opts_r = {
        algo = algo,
        ratio = ratio,
        n_ratio = n_ratio,
        usage_importance = usage_importance,
        usage_falloff = usage_falloff,
        stickiness = stickiness,
        fft_start = fft_start,
        fft_end = fft_end,
        num_synapses = options.num_synapses,
        channel = "right"
      }
      local m_r, d_r, e_r = matcher_r:search(target_blk, search_opts_r)
      if not m_r then
        return nil, e_r or "Right matcher returned no block"
      end
      matched_blk_r = m_r
      dist_r = d_r
    end

    decisions[#decisions + 1] = {
      target_blk = target_blk,
      matched_blk = matched_blk_l,
      matched_blk_l = matched_blk_l,
      matched_blk_r = matched_blk_r,
      render_step = render_step,
      dist = dist_l
    }

    -- Target step logic (incorporating Synaptic Slide & Stretch)
    if algo == Constants.ALGO_SYNAPTIC_SLIDE then
      if slide_attempts >= max_slide_attempts then
        -- Force target advance if slide_error threshold cannot be satisfied within repeat limit
        target_idx = target_idx + 1
        slide_attempts = 0
      elseif matcher_l.current_error < slide_error and (render_step % stretch == 0) then
        target_idx = target_idx + 1
        slide_attempts = 0
      else
        slide_attempts = slide_attempts + 1
      end
    else
      if render_step % stretch == 0 then
        target_idx = target_idx + 1
      end
    end

    render_step = render_step + 1

    if options.job then
      JobRunner.yield(options.job, target_idx / #target_blocks, string.format("Matching block %d / %d", target_idx, #target_blocks), false)
    end
  end

  -- Phase 2: Overlap-Add Rendering from Decision Stream
  local total_output_frames = math.max(1, math.ceil((render_step - 1) * exact_output_hop + block_size))
  local ola_l = OverlapAdd.create(total_output_frames)
  local ola_r = OverlapAdd.create(total_output_frames)

  for idx = 1, #decisions do
    local dec = decisions[idx]
    local target_blk = dec.target_blk
    local matched_l = dec.matched_blk_l or dec.matched_blk
    local matched_r = dec.matched_blk_r or dec.matched_blk

    local raw_l, _ = matched_l:get_windowed_pcm_stereo()
    local _, raw_r = matched_r:get_windowed_pcm_stereo()
    local n_raw_l, _ = matched_l:get_normalized_windowed_pcm_stereo()
    local _, n_raw_r = matched_r:get_normalized_windowed_pcm_stereo()
    local targ_l, targ_r = target_blk:get_windowed_pcm_stereo()

    local target_len = #targ_l
    local grain_l = {}
    local grain_r = {}

    local src_len_l = math.max(#raw_l, #n_raw_l)
    local src_len_r = math.max(#raw_r, #n_raw_r)
    local comp_gain = brain_gain * (options.normalize and 1.0 or 0.2)

    -- Sample-rate compensation scale for Left and Right channels
    local dst_rate = target_blk.sample_rate or Constants.DEFAULT_SAMPLE_RATE
    local src_rate_l = matched_l.sample_rate or Constants.DEFAULT_SAMPLE_RATE
    local src_rate_r = matched_r.sample_rate or Constants.DEFAULT_SAMPLE_RATE

    -- Independent pitch scales
    local pitch_scale_l = 1.0
    local pitch_scale_r = 1.0

    if autotune > 0 then
      local dom_target_l = target_blk.dominant_freq_l or target_blk.dominant_freq
      local dom_target_r = target_blk.dominant_freq_r or target_blk.dominant_freq
      local dom_match_l = matched_l.dominant_freq_l or matched_l.dominant_freq
      local dom_match_r = matched_r.dominant_freq_r or matched_r.dominant_freq

      if dom_target_l and dom_match_l and dom_match_l > 0 then
        pitch_scale_l = dom_target_l / dom_match_l
        local max_scale = 1.0 + (autotune * autotune) * 100.0
        if pitch_scale_l > max_scale then pitch_scale_l = max_scale end
        if pitch_scale_l < 1.0 / max_scale then pitch_scale_l = 1.0 / max_scale end
      end

      if dom_target_r and dom_match_r and dom_match_r > 0 then
        pitch_scale_r = dom_target_r / dom_match_r
        local max_scale = 1.0 + (autotune * autotune) * 100.0
        if pitch_scale_r > max_scale then pitch_scale_r = max_scale end
        if pitch_scale_r < 1.0 / max_scale then pitch_scale_r = 1.0 / max_scale end
      end
    end

    local cursor_step_l = pitch_scale_l * ((src_rate_l > 0 and dst_rate > 0) and (src_rate_l / dst_rate) or 1.0)
    local cursor_step_r = pitch_scale_r * ((src_rate_r > 0 and dst_rate > 0) and (src_rate_r / dst_rate) or 1.0)

    -- Upstream Source Cursor Rendering Semantics (Independent L/R Cursors)
    local source_position_l = 0.0
    local source_position_r = 0.0
    local block_pos = 0

    while (source_position_l < src_len_l or source_position_r < src_len_r) do
      local idx0_l = math.floor(source_position_l)
      local idx0_r = math.floor(source_position_r)
      local r_s_l, r_s_r, n_s_l, n_s_r

      if idx0_l >= src_len_l - 1 then
        r_s_l = raw_l[src_len_l] or 0.0
        n_s_l = n_raw_l[src_len_l] or 0.0
      else
        local frac = source_position_l - idx0_l
        r_s_l = (raw_l[idx0_l + 1] or 0.0) * (1.0 - frac) + (raw_l[idx0_l + 2] or 0.0) * frac
        n_s_l = (n_raw_l[idx0_l + 1] or 0.0) * (1.0 - frac) + (n_raw_l[idx0_l + 2] or 0.0) * frac
      end

      if idx0_r >= src_len_r - 1 then
        r_s_r = raw_r[src_len_r] or 0.0
        n_s_r = n_raw_r[src_len_r] or 0.0
      else
        local frac = source_position_r - idx0_r
        r_s_r = (raw_r[idx0_r + 1] or 0.0) * (1.0 - frac) + (raw_r[idx0_r + 2] or 0.0) * frac
        n_s_r = (n_raw_r[idx0_r + 1] or 0.0) * (1.0 - frac) + (n_raw_r[idx0_r + 2] or 0.0) * frac
      end

      local brain_sample_l = r_s_l * (1.0 - n_mix) + n_s_l * n_mix
      local brain_sample_r = r_s_r * (1.0 - n_mix) + n_s_r * n_mix

      local t_s_l = 0.0
      local t_s_r = 0.0

      if block_pos < target_len then
        t_s_l = targ_l[block_pos + 1] or 0.0
        t_s_r = targ_r[block_pos + 1] or 0.0
      end

      grain_l[block_pos + 1] = brain_sample_l * (1.0 - target_mix) + t_s_l * target_mix
      grain_r[block_pos + 1] = brain_sample_r * (1.0 - target_mix) + t_s_r * target_mix

      source_position_l = source_position_l + cursor_step_l
      source_position_r = source_position_r + cursor_step_r

      if block_pos < src_len_l and source_position_l > src_len_l then
        source_position_l = 0.0
      end
      if block_pos < src_len_r and source_position_r > src_len_r then
        source_position_r = 0.0
      end

      block_pos = block_pos + 1

      -- Dynamic rate-aware watchdog cap (accounting for both L and R lifespans)
      local max_len_l = math.max(src_len_l, math.ceil(src_len_l / math.max(cursor_step_l, 1e-6)))
      local max_len_r = math.max(src_len_r, math.ceil(src_len_r / math.max(cursor_step_r, 1e-6)))
      local watchdog_cap = (math.max(max_len_l, max_len_r) + target_len) * 5
      if block_pos > watchdog_cap then
        break
      end
    end

    -- Update total bounds based on actual rendered grain tails
    local start_frame = math.floor(dec.render_step * exact_output_hop + 0.5) + 1
    local end_frame = start_frame + #grain_l - 1
    if end_frame > total_output_frames then
      total_output_frames = end_frame
      ola_l:resize(total_output_frames)
      ola_r:resize(total_output_frames)
    end

    ola_l:add_grain(grain_l, start_frame, comp_gain, Constants.WINDOW_RECTANGLE)
    ola_r:add_grain(grain_r, start_frame, comp_gain, Constants.WINDOW_RECTANGLE)
  end

  if options.normalize then
    -- Shared peak normalization to preserve stereo balance
    local max_l = 0.0
    for i = 1, ola_l.length do local v = math.abs(ola_l.buffer[i]); if v > max_l then max_l = v end end
    local max_r = 0.0
    for i = 1, ola_r.length do local v = math.abs(ola_r.buffer[i]); if v > max_r then max_r = v end end
    local shared_peak = math.max(max_l, max_r)
    if shared_peak > 1e-12 then
      local scale = 0.98 / shared_peak
      for i = 1, ola_l.length do ola_l.buffer[i] = ola_l.buffer[i] * scale end
      for i = 1, ola_r.length do ola_r.buffer[i] = ola_r.buffer[i] * scale end
    end
  end

  return ola_l.buffer, ola_r.buffer
end

return Renderer
