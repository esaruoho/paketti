-- PakettiTransientNavigation.lua
-- Tab-to-transient navigation for the Renoise Sample Editor.
-- REPORT-CARD >> features/transient-navigation-detection.feature
-- FEATURE-CARD >> features/transient-integration.feature
local tn_analysis = require("PakettiTransientAnalysis")
--
-- The idea (from Pro Tools / REAPER / Acon Acoustica, requested by le(m)on on
-- Discord): step through a sample by detected attack transients the way Renoise
-- lets you step through slices - WITHOUT populating the sample with slice
-- markers. "Next Transient" jumps to the next transient region, selects it, and
-- zooms the waveform so that region is shown in full (like "next slice").
--
-- Detection reuses the BeatDetector engine already in PakettiBeatDetect.lua
-- (filtered envelope-follower + Schmitt trigger, combined lowpass+highpass). The
-- per-frame scan is expensive, so it runs inside a ProcessSlicer (non-blocking,
-- with a progress % in the status bar) and the result is cached per sample. The
-- first navigation kicks off detection and auto-jumps when ready; after that,
-- navigation reads the cache instantly.

--------------------------------------------------------------------------------
-- Detection defaults (tuned lower than the slice tool so an amen break yields
-- its full set of hits, not just the loudest few).
--------------------------------------------------------------------------------
local TN_DEFAULTS = {
  lowpass_freq = 150, highpass_freq = 3000,
  adaptive_fast_ms = 10, adaptive_slow_ms = 120,
  adaptive_on = 0.012, adaptive_off = 0.004,
  adaptive_min_amp = 0.02, adaptive_ratio = 1.25,
  legacy_rtime = 0.02, legacy_peak_on = 0.04, legacy_peak_off = 0.03,
  min_slice_distance_ms = 10, zero_crossing = 1,
}

-- Fraction of the region length padded on each side when zooming "to fit".
local TN_ZOOM_PAD = 0.04

-- Onset-zoom window: how much of the attack to show, and a little pre-roll so
-- the transient sits just inside the left edge, when zooming in on a transient.
local TN_ONSET_WINDOW_MS = 120
local TN_ONSET_PREROLL_MS = 4

--------------------------------------------------------------------------------
-- Cache + detection state
--------------------------------------------------------------------------------
local tn_cached_positions = nil   -- sorted array of transient frame indices (1-based)
local tn_cached_key = nil         -- fingerprint of the sample the cache belongs to
local tn_caches, tn_cache_order = {}, {} -- bounded to eight analyzed samples
local tn_generation = 0
local tn_job_key = nil
local tn_pending_action = nil
local tn_slicer = nil
local tn_settings_dialog = nil
local tn_detecting = false        -- a ProcessSlicer detection is currently running

--------------------------------------------------------------------------------
-- Local helpers (declared BEFORE any function that calls them - Paketti rule 28)
--------------------------------------------------------------------------------

-- Zero-crossing snap. PakettiBeatDetect's own copy is file-local, so we keep a
-- small equivalent here rather than reaching across files.
local function tn_find_zero_crossing(buffer, pos, search_range_samples, zero_threshold)
  local start_pos = math.max(1, pos - search_range_samples)
  local end_pos = math.min(buffer.number_of_frames, pos + search_range_samples)
  local function amplitude(frame)
    local peak = 0
    for channel = 1, buffer.number_of_channels do
      peak = math.max(peak, math.abs(buffer:sample_data(channel, frame)))
    end
    return peak
  end
  local zero_crossing_pos = pos
  local min_amplitude = amplitude(pos)
  for i = pos, start_pos, -1 do
    local v = amplitude(i)
    if v <= zero_threshold then zero_crossing_pos = i break
    elseif v < min_amplitude then min_amplitude = v zero_crossing_pos = i end
  end
  if zero_crossing_pos == pos then
    for i = pos, end_pos do
      local v = amplitude(i)
      if v <= zero_threshold then zero_crossing_pos = i break
      elseif v < min_amplitude then min_amplitude = v zero_crossing_pos = i end
    end
  end
  return zero_crossing_pos
end

-- Return the selected sample, or nil (with a status message) if there is nothing
-- usable to navigate.
local function tn_current_sample()
  local ok, song = pcall(renoise.song)
  if not ok or not song then return nil end
  local sample = song.selected_sample
  if not sample then
    renoise.app():show_status("Transient Nav: no sample selected.")
    return nil
  end
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    renoise.app():show_status("Transient Nav: the selected sample has no audio data.")
    return nil
  end
  return sample
end

-- Fingerprint identifying which sample the cache belongs to. Includes the frame
-- count, object identity, settings and audio probes on both channels. Probes
-- catch many same-size edits but are not a full content hash; Re-detect remains
-- available for edits between probe positions.
local function tn_sample_key(sample)
  local song = renoise.song()
  local buffer = sample.sample_buffer
  local probes = {}
  for channel = 1, buffer.number_of_channels do
    for i = 0, 63 do
      local frame = 1 + math.floor(i * (buffer.number_of_frames - 1) / 63)
      probes[#probes + 1] = string.format("%.9g", buffer:sample_data(channel, frame))
    end
  end
  local pref = preferences
  return table.concat({tostring(sample), tostring(song), buffer.number_of_frames,
    buffer.sample_rate, buffer.number_of_channels, sample.name,
    pref.pakettiTransientNavDetector.value, pref.pakettiTransientNavSensitivity.value,
    pref.pakettiTransientNavThreshold.value, pref.pakettiTransientNavGapMs.value,
    pref.pakettiTransientNavSnapMode.value, tostring(pref.pakettiTransientNavZeroCross.value),
    table.concat(probes, ",")}, ":")
end

local function tn_remember(key, positions)
  if not tn_caches[key] then tn_cache_order[#tn_cache_order + 1] = key end
  tn_caches[key] = positions
  while #tn_cache_order > 8 do tn_caches[table.remove(tn_cache_order, 1)] = nil end
  tn_cached_key, tn_cached_positions = key, positions
end

-- Restore an analyzed sample instantly, with content/settings-aware identity.
local function tn_cache_valid(sample)
  local key = tn_sample_key(sample)
  local cached = tn_caches[key]
  if cached then
    tn_cached_key, tn_cached_positions = key, cached
    return true
  end
  return false
end

local function tn_positions_to_string(positions)
  local out = {}
  for i, pos in ipairs(positions or {}) do
    out[i] = tostring(pos)
  end
  return table.concat(out, ", ")
end

local function tn_debug_positions(label, positions)
  print(string.format("Transient Nav Debug: %s (%d): %s",
    label, #(positions or {}), tn_positions_to_string(positions)))
end

local function tn_debug_suppressed(label, suppressed)
  local out = {}
  for i, item in ipairs(suppressed or {}) do
    out[i] = string.format("%d(+%d)", item.pos, item.distance)
  end
  print(string.format("Transient Nav Debug: %s (%d): %s",
    label, #(suppressed or {}), table.concat(out, ", ")))
end

local function tn_create_adaptive_schmitt(filter_freq, filter_type, sample_rate)
  local t_filter = 1.0 / (2.0 * math.pi * filter_freq)
  local k_filter = 1.0 / (sample_rate * t_filter)
  local fast_release = math.exp(-1.0 / (sample_rate * (TN_DEFAULTS.adaptive_fast_ms / 1000)))
  local slow_coeff = 1.0 - math.exp(-1.0 / (sample_rate * (TN_DEFAULTS.adaptive_slow_ms / 1000)))

  return {
    filter1 = 0.0,
    filter2 = 0.0,
    fast_env = 0.0,
    slow_env = 0.0,
    trigger = false,
    prev_trigger = false,

    process = function(self, input)
      self.filter1 = self.filter1 + (k_filter * (input - self.filter1))
      self.filter2 = self.filter2 + (k_filter * (self.filter1 - self.filter2))

      local filtered = filter_type == "lowpass" and self.filter2 or (input - self.filter2)
      local env_in = math.abs(filtered)

      if env_in > self.fast_env then
        self.fast_env = env_in
      else
        self.fast_env = self.fast_env * fast_release + (1.0 - fast_release) * env_in
      end
      self.slow_env = self.slow_env + (slow_coeff * (env_in - self.slow_env))

      local novelty = math.max(0.0, self.fast_env - self.slow_env)
      local ratio = self.fast_env / (self.slow_env + 0.000000001)
      local should_trigger = self.fast_env > TN_DEFAULTS.adaptive_min_amp
        and novelty > TN_DEFAULTS.adaptive_on
        and ratio > TN_DEFAULTS.adaptive_ratio
      local should_release = novelty < TN_DEFAULTS.adaptive_off or ratio < 1.05

      if not self.trigger then
        if should_trigger then self.trigger = true end
      elseif should_release then
        self.trigger = false
      end

      local pulse = self.trigger and not self.prev_trigger
      self.prev_trigger = self.trigger
      return pulse, novelty, self.fast_env, self.slow_env
    end
  }
end

-- Called after any destructive edit so the next navigation re-detects.
function PakettiTransientNavInvalidate()
  tn_generation = tn_generation + 1
  if tn_slicer and tn_slicer:running() then tn_slicer:stop() end
  tn_slicer = nil
  tn_job_key, tn_pending_action = nil, nil
  tn_detecting = false
  tn_cached_positions = nil
  tn_cached_key = nil
  tn_caches, tn_cache_order = {}, {}
end

-- Run the combined detector over the sample inside a ProcessSlicer (non-blocking),
-- fill the cache, then call on_done (used to auto-perform the requested jump).
local function tn_start_detection(sample, on_done)
  if tn_detecting and tn_job_key == tn_sample_key(sample) then
    tn_pending_action = on_done
    return
  end
  if tn_detecting then PakettiTransientNavInvalidate() end
  tn_detecting = true
  local buffer = sample.sample_buffer
  local nframes = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  local key = tn_sample_key(sample)
  tn_job_key, tn_pending_action = key, on_done
  local generation = tn_generation
  local owner_song = renoise.song()
  local function still_current()
    local ok, song = pcall(renoise.song)
    return generation == tn_generation and ok and song == owner_song
      and song.selected_sample == sample and sample.sample_buffer.has_sample_data
      and tn_sample_key(sample) == key
  end

  local min_slice_distance_samples = math.floor((TN_DEFAULTS.min_slice_distance_ms / 1000) * sample_rate)
  local zero_crossing_threshold = TN_DEFAULTS.zero_crossing / 100
  local search_range_samples = math.floor((10 / 1000) * sample_rate)

  local slicer = ProcessSlicer(function()
    -- pcall is yieldable in Renoise's LuaJIT. Always release the job state,
    -- including a deleted sample or a sample_data error during the scan.
    local ok, err = pcall(function()
      if not still_current() then return end
      if preferences.pakettiTransientNavDetector.value == 2 then
        local positions = tn_analysis.detect(buffer, {
          sensitivity=preferences.pakettiTransientNavSensitivity.value,
          threshold=preferences.pakettiTransientNavThreshold.value,
          min_gap_ms=preferences.pakettiTransientNavGapMs.value,
          snap_mode=preferences.pakettiTransientNavSnapMode.value,
          zero_cross=preferences.pakettiTransientNavZeroCross.value,
        }, function(progress)
          renoise.app():show_status(string.format("Transient Nav: level-rise analysis %d%%", math.floor(progress*100)))
          coroutine.yield()
          if not still_current() then error("sample or detection settings changed") end
        end)
        if still_current() then
          tn_remember(key, positions)
          tn_detecting = false
          renoise.app():show_status("Transient Nav: " .. #positions .. " level-rise transients detected.")
          if tn_pending_action then tn_pending_action() end
        end
        return
      end
      local legacy_low = BeatDetector(TN_DEFAULTS.lowpass_freq, TN_DEFAULTS.legacy_rtime,
        TN_DEFAULTS.legacy_peak_on, TN_DEFAULTS.legacy_peak_off, 'lowpass')
      legacy_low:setSampleRate(sample_rate)
      local legacy_high = BeatDetector(TN_DEFAULTS.highpass_freq, TN_DEFAULTS.legacy_rtime,
        TN_DEFAULTS.legacy_peak_on, TN_DEFAULTS.legacy_peak_off, 'highpass')
      legacy_high:setSampleRate(sample_rate)
      local adaptive = {}
      for channel = 1, buffer.number_of_channels do
        adaptive[channel] = {
          tn_create_adaptive_schmitt(TN_DEFAULTS.lowpass_freq, "lowpass", sample_rate),
          tn_create_adaptive_schmitt(TN_DEFAULTS.highpass_freq, "highpass", sample_rate)}
      end

      local legacy_raw = {}
      local adaptive_raw = {}
      for i = 1, nframes do
        local input = buffer:sample_data(1, i)
        local legacy_low_hit = legacy_low:Process(input)
        local legacy_high_hit = legacy_high:Process(input)
        if legacy_low_hit == true or legacy_high_hit == true then
          legacy_raw[#legacy_raw + 1] = i
        end

        local hit = false
        for channel, detectors in ipairs(adaptive) do
          local value = buffer:sample_data(channel, i)
          local low, high = detectors[1]:process(value), detectors[2]:process(value)
          if low or high then hit = true end
        end
        if hit then adaptive_raw[#adaptive_raw + 1] = i end
        if i % 16384 == 0 then
          renoise.app():show_status(string.format("Transient Nav: detecting transients... %d%%",
            math.floor((i / nframes) * 100)))
          coroutine.yield()
          if not still_current() then return end
        end
      end

      table.sort(adaptive_raw)
      local filtered = {}
      local last = nil
      local suppressed = {}
      for _, pos in ipairs(adaptive_raw) do
        if not last or (pos - last) >= min_slice_distance_samples then
          local zc = preferences.pakettiTransientNavZeroCross.value
            and tn_find_zero_crossing(buffer, pos, search_range_samples, zero_crossing_threshold) or pos
          filtered[#filtered + 1] = zc
          last = zc
        else
          suppressed[#suppressed + 1] = {pos = pos, distance = pos - last}
        end
      end

      tn_debug_positions("Legacy level-Schmitt raw hits", legacy_raw)
      tn_debug_positions("Adaptive Schmitt raw hits", adaptive_raw)
      tn_debug_suppressed("Suppressed by min spacing", suppressed)
      tn_debug_positions("Final snapped transients", filtered)

      table.sort(filtered)
      local unique = {}
      for _, pos in ipairs(filtered) do
        if pos ~= unique[#unique] then unique[#unique + 1] = pos end
      end
      filtered = unique
      if not still_current() then return end
      tn_remember(key, filtered)
      tn_detecting = false
      renoise.app():show_status(string.format("Transient Nav: %d transients detected.", #filtered))
      if tn_pending_action then tn_pending_action() end
    end)
    if generation == tn_generation then
      tn_detecting = false
      tn_slicer = nil
      tn_job_key, tn_pending_action = nil, nil
    end
    if not ok then renoise.app():show_status("Transient Nav: detection stopped: " .. tostring(err)) end
  end)
  tn_slicer = slicer
  slicer:start()
end

-- Ensure the cache is populated. Returns true if ready now; false if it kicked
-- off a background detection (which will call retry_action when done).
local function tn_ensure_positions(sample, retry_action)
  if tn_cache_valid(sample) then return true end
  tn_start_detection(sample, retry_action)
  renoise.app():show_status("Transient Nav: detecting transients, will jump when ready...")
  return false
end

-- display_start / display_length can only be SET while the Sample Editor is the
-- active middle frame (otherwise: "no display_start's are available"). The
-- keybindings are Sample-Editor-scoped so this is normally already true, but make
-- it robust when triggered from a menu on another frame.
local function tn_ensure_sample_editor()
  local w = renoise.app().window
  local target = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  if w.active_middle_frame ~= target then w.active_middle_frame = target end
end

-- Set the zoom window in a 3-step, always-valid order so display_start +
-- display_length - 1 never transiently exceeds the sample length (Renoise throws
-- and wedges the display otherwise).
local function tn_set_display(buffer, disp_start, disp_len)
  local nframes = buffer.number_of_frames
  disp_len = math.max(1, math.min(disp_len, nframes))
  tn_ensure_sample_editor()
  -- Wrapped in pcall so a display quirk can never crash navigation.
  pcall(function()
    -- When fully zoomed out (display_length == number_of_frames) Renoise refuses
    -- to set display_start ("no display_start's are available"). Bring it back to 1
    -- ONLY while zoomed in, then set the (smaller) length, which makes display_start
    -- settable again.
    if buffer.display_length < nframes then buffer.display_start = 1 end
    buffer.display_length = disp_len
    -- The valid max for display_start is number_of_frames - display_length (NOT
    -- +1, confirmed live) - one over gives "invalid display_start index" near the
    -- end of the sample (the crash le(m)on hit on the last transient). Read the
    -- length back in case Renoise adjusted it, and clamp against nframes - length.
    local actual_len = buffer.display_length
    if actual_len < nframes then
      local max_start = math.max(1, nframes - actual_len)
      buffer.display_start = math.max(1, math.min(disp_start, max_start))
    end
  end)
end

-- Scroll the zoomed waveform so `frame` is visible (centred) when off-screen.
local function tn_follow_view(buffer, frame)
  local view_len = buffer.display_length
  local nframes = buffer.number_of_frames
  if view_len >= nframes then return end
  local vs = buffer.display_start
  local ve = vs + view_len - 1
  if frame < vs or frame > ve then
    local new_start = math.floor(frame - view_len / 2)
    new_start = math.max(1, math.min(new_start, nframes - view_len + 1))
    tn_set_display(buffer, new_start, view_len)
  end
end

-- Order-safe selection set (selection_start is never > end mid-assignment).
local function tn_set_selection(buffer, a, b)
  local cur_end = buffer.selection_end
  if a > cur_end then
    buffer.selection_end = b
    buffer.selection_start = a
  else
    buffer.selection_start = a
    buffer.selection_end = b
  end
end

-- Place a point cursor at `frame` and scroll it into view.
local function tn_show_point(buffer, frame)
  local nframes = buffer.number_of_frames
  frame = math.max(1, math.min(frame, nframes))
  tn_set_selection(buffer, frame, frame)
  tn_follow_view(buffer, frame)
end

-- Select [a..b] and ZOOM the display so that region fills the editor (with a
-- little padding) - the "show it in full" / next-slice behaviour.
local function tn_show_region(buffer, a, b)
  local nframes = buffer.number_of_frames
  a = math.max(1, math.min(a, nframes))
  b = math.max(1, math.min(b, nframes))
  if a > b then a, b = b, a end
  tn_set_selection(buffer, a, b)

  local len = b - a + 1
  local pad = math.floor(len * TN_ZOOM_PAD)
  tn_set_display(buffer, a - pad, len + pad * 2)
end

-- Place a point cursor at `frame` and zoom IN CLOSE on the onset - the transient
-- sits just inside the left edge, showing the attack in detail ("with zoom").
-- region_end bounds the window so we never show past the next transient.
local function tn_show_onset(buffer, frame, region_end)
  local nframes = buffer.number_of_frames
  local sr = buffer.sample_rate
  frame = math.max(1, math.min(frame, nframes))
  tn_set_selection(buffer, frame, frame)

  local preroll = math.floor((TN_ONSET_PREROLL_MS / 1000) * sr)
  local win = math.floor((TN_ONSET_WINDOW_MS / 1000) * sr)
  if region_end then win = math.min(win, (region_end - frame) + preroll + 1) end
  tn_set_display(buffer, frame - preroll, win)
end

-- Augmented exclusive-edge list: 1, transients..., number_of_frames + 1.
local function tn_boundaries(sample)
  local positions = tn_cached_positions or {}
  local buffer = sample.sample_buffer
  local B = {}
  if positions[1] ~= 1 then B[#B + 1] = 1 end
  for _, p in ipairs(positions) do B[#B + 1] = p end
  local nf = buffer.number_of_frames + 1
  if B[#B] ~= nf then B[#B + 1] = nf end
  return B
end

-- Index k of the chunk [B[k]..B[k+1]-1] that contains `ref`.
local function tn_current_chunk_index(B, ref)
  for k = 1, #B - 1 do
    if ref >= B[k] and ref < B[k + 1] then return k end
  end
  if ref >= B[#B] then return #B - 1 end
  return 1
end

-- When no explicit selection is made, Renoise reports the selection as the WHOLE
-- sample (selection_start = 1, selection_end = number_of_frames). That must be
-- treated as "no cursor yet", not "at both ends", or Next/Previous always report
-- being at the last/first transient. (This is the bug le(m)on hit.)
local function tn_selection_is_whole(buffer)
  return buffer.selection_start <= 1 and buffer.selection_end >= buffer.number_of_frames
end

-- Reference frame for stepping FORWARD: before-everything when no cursor,
-- otherwise the right edge of the current selection/point.
local function tn_ref_next(buffer)
  if tn_selection_is_whole(buffer) then return 0 end
  return math.max(buffer.selection_start, buffer.selection_end)
end

-- Reference frame for stepping BACKWARD: after-everything when no cursor,
-- otherwise the left edge of the current selection/point.
local function tn_ref_prev(buffer)
  if tn_selection_is_whole(buffer) then return buffer.number_of_frames + 1 end
  return math.min(buffer.selection_start, buffer.selection_end)
end

--------------------------------------------------------------------------------
-- Region navigation (select + zoom to fit) - the primary "next slice, but
-- transient" behaviour.
--------------------------------------------------------------------------------
function PakettiTransientNextRegion()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientNextRegion) then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_selection_is_whole(buffer) and 0 or buffer.selection_start
  local k = tn_selection_is_whole(buffer) and 1 or tn_current_chunk_index(B, ref) + 1
  if k > #B - 1 then k = 1 end   -- wrap past the last region back to the first
  tn_show_region(buffer, B[k], B[k + 1] - 1)
  renoise.app():show_status(string.format("Transient Nav: region %d/%d  frames %d..%d (%d)",
    k, #B - 1, B[k], B[k + 1] - 1, B[k + 1] - B[k]))
end

function PakettiTransientPreviousRegion()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientPreviousRegion) then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_selection_is_whole(buffer) and (buffer.number_of_frames + 1) or buffer.selection_start
  local k = tn_selection_is_whole(buffer) and (#B - 1) or tn_current_chunk_index(B, ref) - 1
  if k < 1 then k = #B - 1 end   -- wrap before the first region round to the last
  tn_show_region(buffer, B[k], B[k + 1] - 1)
  renoise.app():show_status(string.format("Transient Nav: region %d/%d  frames %d..%d (%d)",
    k, #B - 1, B[k], B[k + 1] - 1, B[k + 1] - B[k]))
end

--------------------------------------------------------------------------------
-- Onset navigation (cursor on the transient, zoomed IN close on the attack) -
-- "next transient with zoom".
--------------------------------------------------------------------------------
function PakettiTransientNextOnset()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientNextOnset) then return end
  local buffer = sample.sample_buffer
  local positions = tn_cached_positions
  if #positions == 0 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_ref_next(buffer)
  local j = nil
  for i = 1, #positions do if positions[i] > ref then j = i break end end
  if not j then j = 1 end   -- wrap past the last transient back to the first
  local region_end = positions[j + 1] and (positions[j + 1] - 1) or buffer.number_of_frames
  tn_show_onset(buffer, positions[j], region_end)
  renoise.app():show_status(string.format("Transient Nav: onset %d/%d at frame %d (zoomed)", j, #positions, positions[j]))
end

function PakettiTransientPreviousOnset()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientPreviousOnset) then return end
  local buffer = sample.sample_buffer
  local positions = tn_cached_positions
  if #positions == 0 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_ref_prev(buffer)
  local j = nil
  for i = #positions, 1, -1 do if positions[i] < ref then j = i break end end
  if not j then j = #positions end   -- wrap before the first transient round to the last
  local region_end = positions[j + 1] and (positions[j + 1] - 1) or buffer.number_of_frames
  tn_show_onset(buffer, positions[j], region_end)
  renoise.app():show_status(string.format("Transient Nav: onset %d/%d at frame %d (zoomed)", j, #positions, positions[j]))
end

--------------------------------------------------------------------------------
-- Point-cursor navigation (place a caret on the transient, scroll into view, no
-- zoom change) - secondary, for when you don't want the view to zoom.
--------------------------------------------------------------------------------
function PakettiTransientNextPoint()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientNextPoint) then return end
  local buffer = sample.sample_buffer
  local positions = tn_cached_positions
  if #positions == 0 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_ref_next(buffer)
  local target = nil
  for _, p in ipairs(positions) do if p > ref then target = p break end end
  if not target then target = positions[1] end   -- wrap past the last back to the first
  tn_show_point(buffer, target)
  renoise.app():show_status(string.format("Transient Nav: cursor at frame %d", target))
end

function PakettiTransientPreviousPoint()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientPreviousPoint) then return end
  local buffer = sample.sample_buffer
  local positions = tn_cached_positions
  if #positions == 0 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_ref_prev(buffer)
  local target = nil
  for i = #positions, 1, -1 do if positions[i] < ref then target = positions[i] break end end
  if not target then target = positions[#positions] end   -- wrap before the first round to the last
  tn_show_point(buffer, target)
  renoise.app():show_status(string.format("Transient Nav: cursor at frame %d", target))
end

--------------------------------------------------------------------------------
-- Unified Next/Previous. The preference toggles between the two zoom styles
-- le(m)on asked for: false = onset zoom ("with zoom"), true = whole region in
-- full ("in full with zoom").
--------------------------------------------------------------------------------
function PakettiTransientNext()
  if preferences.pakettiTransientNavSelectMode.value then
    PakettiTransientNextRegion()
  else
    PakettiTransientNextOnset()
  end
end

function PakettiTransientPrevious()
  if preferences.pakettiTransientNavSelectMode.value then
    PakettiTransientPreviousRegion()
  else
    PakettiTransientPreviousOnset()
  end
end

function PakettiTransientToggleSelectMode()
  local v = not preferences.pakettiTransientNavSelectMode.value
  preferences.pakettiTransientNavSelectMode.value = v
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Transient Nav: Next/Previous now " ..
    (v and "select WHOLE REGION in full (zoom to fit)" or "zoom IN on the onset"))
end

--------------------------------------------------------------------------------
-- Re-detect (force recompute; report count)
--------------------------------------------------------------------------------
function PakettiTransientRedetect()
  local sample = tn_current_sample(); if not sample then return end
  PakettiTransientNavInvalidate()
  tn_start_detection(sample, function()
    renoise.app():show_status(string.format("Transient Nav: detected %d transients.",
      #(tn_cached_positions or {})))
  end)
end

--------------------------------------------------------------------------------
-- Slice at cursor
--------------------------------------------------------------------------------
function PakettiTransientSliceAtCursor()
  local sample = tn_current_sample(); if not sample then return end
  if sample.is_slice_alias then
    renoise.app():show_status("Transient Nav: this is a slice alias - slice the master sample instead.")
    return
  end
  if #sample.slice_markers >= 255 then
    renoise.app():show_status("Transient Nav: cannot add slice, 255-marker limit reached.")
    return
  end
  local frame = sample.sample_buffer.selection_start
  local ok, err = pcall(function() sample:insert_slice_marker(frame) end)
  if ok then
    renoise.app():show_status(string.format("Transient Nav: inserted slice marker at frame %d", frame))
  else
    renoise.app():show_status("Transient Nav: could not insert slice marker (" .. tostring(err) .. ")")
  end
end

--------------------------------------------------------------------------------
-- Destructive crop: keep only [keep_start..keep_end], rebuild the buffer in place
--------------------------------------------------------------------------------
local function tn_crop(keep_start, keep_end, cursor_after)
  local sample = tn_current_sample(); if not sample then return end
  if sample.is_slice_alias or sample.sample_buffer.read_only then
    renoise.app():show_status("Transient Nav: cannot crop a slice alias or read-only buffer.")
    return
  end
  local buffer = sample.sample_buffer
  local nframes = buffer.number_of_frames
  keep_start = math.max(1, math.min(keep_start, nframes))
  keep_end = math.max(1, math.min(keep_end, nframes))
  if keep_end < keep_start then
    renoise.app():show_status("Transient Nav: nothing left to keep - crop aborted.")
    return
  end
  if keep_start == 1 and keep_end == nframes then
    renoise.app():show_status("Transient Nav: already the whole sample.")
    return
  end
  PakettiTransientNavInvalidate()
  local new_len = keep_end - keep_start + 1
  local nch = buffer.number_of_channels
  local rate = buffer.sample_rate
  local depth = buffer.bit_depth

  -- Remember frame-referenced properties so we can remap them.
  local old_loop_mode = sample.loop_mode
  local old_loop_start = sample.loop_start
  local old_loop_end = sample.loop_end
  local surviving_markers = {}
  for _, m in ipairs(sample.slice_markers) do
    if m >= keep_start and m <= keep_end then
      surviving_markers[#surviving_markers + 1] = m - keep_start + 1
    end
  end

  -- Read the kept region into memory FIRST (create_sample_data wipes the buffer).
  local data = {}
  for ch = 1, nch do
    local col = {}
    for i = 1, new_len do
      col[i] = buffer:sample_data(ch, keep_start + i - 1)
    end
    data[ch] = col
  end

  -- Rebuild in place.
  renoise.song():describe_undo("Transient Navigation: Crop Sample")
  if not buffer:create_sample_data(rate, depth, nch, new_len) then
    renoise.app():show_status("Transient Nav: crop failed to allocate the new buffer.")
    return
  end
  buffer:prepare_sample_data_changes()
  for ch = 1, nch do
    local col = data[ch]
    for i = 1, new_len do
      buffer:set_sample_data(ch, i, col[i])
    end
  end
  buffer:finalize_sample_data_changes()

  -- Remap slice markers (existing markers are cleared by the buffer rebuild).
  for i = #sample.slice_markers, 1, -1 do
    sample:delete_slice_marker(sample.slice_markers[i])
  end
  for _, m in ipairs(surviving_markers) do
    if #sample.slice_markers < 255 then
      pcall(function() sample:insert_slice_marker(m) end)
    end
  end

  -- Clamp loop points into the new length.
  local ns = math.max(1, math.min(old_loop_start - keep_start + 1, new_len))
  local ne = math.max(1, math.min(old_loop_end - keep_start + 1, new_len))
  if old_loop_end >= keep_start and old_loop_start <= keep_end and ne > ns then
    sample.loop_start = 1
    sample.loop_end = ne
    sample.loop_start = ns
    sample.loop_mode = old_loop_mode
  else
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end

  PakettiTransientNavInvalidate()

  local caret = (cursor_after == "end") and new_len or 1
  tn_set_selection(buffer, caret, caret)
  renoise.app():show_status(string.format("Transient Nav: cropped to %d frames (kept %d..%d).",
    new_len, keep_start, keep_end))
end

-- Delete everything to the LEFT of the cursor (keep [selection_start..end]).
function PakettiTransientDeleteLeft()
  local sample = tn_current_sample(); if not sample then return end
  local buffer = sample.sample_buffer
  tn_crop(buffer.selection_start, buffer.number_of_frames, "start")
end

-- Delete everything to the RIGHT of the cursor (keep [1..selection_end]).
function PakettiTransientDeleteRight()
  local sample = tn_current_sample(); if not sample then return end
  local buffer = sample.sample_buffer
  tn_crop(1, buffer.selection_end, "end")
end

-- Independent edges use exclusive end positions, so an end at transient T
-- selects through T-1 and never includes the next attack.
function PakettiTransientSelectionEdge(which, direction)
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, function() PakettiTransientSelectionEdge(which, direction) end) then return end
  local buffer, boundaries = sample.sample_buffer, tn_boundaries(sample)
  local lo, hi = buffer.selection_start, buffer.selection_end + 1
  if lo == buffer.selection_end then hi = lo end -- point cursor
  if tn_selection_is_whole(buffer) then lo, hi = 1, buffer.number_of_frames + 1 end
  local function stop(edge, dir)
    if dir > 0 then
      for _, f in ipairs(boundaries) do if f > edge then return f end end
    else
      for i=#boundaries,1,-1 do if boundaries[i] < edge then return boundaries[i] end end
    end
  end
  local a,b=lo,hi
  if which == "both" then
    if direction > 0 then a,b=stop(lo,-1) or lo,stop(hi,1) or hi
    else a,b=stop(lo,1),stop(hi,-1) end
  else
    -- A point starts a selection toward the requested direction.
    if lo == hi then which = direction > 0 and "end" or "start" end
    if which == "start" then a=stop(lo,direction) else b=stop(hi,direction) end
  end
  if not a or not b or b <= a then
    renoise.app():show_status("Transient Nav: selection cannot shrink further or move past the sample edge.")
    return
  end
  tn_set_selection(buffer,a,b-1)
  tn_follow_view(buffer,which == "start" and a or math.min(b-1,buffer.number_of_frames))
  renoise.app():show_status(string.format("Transient Nav: selected frames %d..%d",a,b-1))
end

function PakettiTransientCropSelection()
  local sample = tn_current_sample(); if not sample then return end
  local buffer=sample.sample_buffer
  tn_crop(buffer.selection_start,buffer.selection_end,"start")
end

function PakettiTransientSettingsDialog()
  if tn_settings_dialog and tn_settings_dialog.visible then tn_settings_dialog:close(); tn_settings_dialog=nil; return end
  local vb=renoise.ViewBuilder()
  local p=preferences
  local function changed(pref,value)
    pref.value=value
    PakettiTransientNavInvalidate()
    preferences:save_as("preferences.xml")
  end
  local content=vb:column{margin=10,spacing=6,
    vb:text{text="Choose the detector; Next/Previous and selection edges share its results."},
    vb:row{vb:text{text="Detector",width=130},vb:popup{width=230,
      items={"Paketti Adaptive Schmitt","Phaos Level Rise / Treble"},value=p.pakettiTransientNavDetector.value,
      notifier=function(v) changed(p.pakettiTransientNavDetector,v) end}},
    vb:text{text="Level Rise / Treble settings (adaptive keeps its existing tuning):"},
    vb:row{vb:text{text="Sensitivity (%)",width=130},vb:valuebox{min=0,max=100,value=p.pakettiTransientNavSensitivity.value,
      notifier=function(v) changed(p.pakettiTransientNavSensitivity,v) end}},
    vb:row{vb:text{text="Threshold (dB below peak)",width=180},vb:valuebox{min=6,max=90,value=p.pakettiTransientNavThreshold.value,
      notifier=function(v) changed(p.pakettiTransientNavThreshold,v) end}},
    vb:row{vb:text{text="Minimum gap (ms)",width=130},vb:valuebox{min=10,max=2000,value=p.pakettiTransientNavGapMs.value,
      notifier=function(v) changed(p.pakettiTransientNavGapMs,v) end}},
    vb:row{vb:text{text="Snap to",width=130},vb:popup{items={"Onset","Peak"},value=p.pakettiTransientNavSnapMode.value,
      notifier=function(v) changed(p.pakettiTransientNavSnapMode,v) end}},
    vb:row{vb:checkbox{value=p.pakettiTransientNavZeroCross.value,
      notifier=function(v) changed(p.pakettiTransientNavZeroCross,v) end},vb:text{text="Zero-crossing snap (both detectors)"}},
    vb:button{text="Re-detect Selected Sample",pressed=PakettiTransientRedetect}}
  tn_settings_dialog=renoise.app():show_custom_dialog("Paketti Transient Detection Settings",content,
    create_keyhandler_for_dialog(function() return tn_settings_dialog end,function(v) tn_settings_dialog=v end))
end

local function tn_release_document()
  PakettiTransientNavInvalidate()
  if tn_settings_dialog and tn_settings_dialog.visible then tn_settings_dialog:close() end
  tn_settings_dialog=nil
end
renoise.tool().app_release_document_observable:add_notifier(tn_release_document)
renoise.tool().app_new_document_observable:add_notifier(tn_release_document)

--------------------------------------------------------------------------------
-- Registrations (LAST in the file - definitions above; Paketti rule 18)
--------------------------------------------------------------------------------
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient", invoke=function() PakettiTransientNext() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient", invoke=function() PakettiTransientPrevious() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient (Zoom to Onset)", invoke=function() PakettiTransientNextOnset() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient (Zoom to Onset)", invoke=function() PakettiTransientPreviousOnset() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient in Full (Zoom to Fit Region)", invoke=function() PakettiTransientNextRegion() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient in Full (Zoom to Fit Region)", invoke=function() PakettiTransientPreviousRegion() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient (No Zoom)", invoke=function() PakettiTransientNextPoint() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient (No Zoom)", invoke=function() PakettiTransientPreviousPoint() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient (Point Cursor, No Zoom)", invoke=function() PakettiTransientNextPoint() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient (Point Cursor, No Zoom)", invoke=function() PakettiTransientPreviousPoint() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Toggle Next/Previous Mode (Region/Point)", invoke=function() PakettiTransientToggleSelectMode() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Slice at Cursor", invoke=function() PakettiTransientSliceAtCursor() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Delete Left of Cursor", invoke=function() PakettiTransientDeleteLeft() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Delete Right of Cursor", invoke=function() PakettiTransientDeleteRight() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Re-detect Transients", invoke=function() PakettiTransientRedetect() end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next", invoke=function() PakettiTransientNext() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous", invoke=function() PakettiTransientPrevious() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next Zoom Onset", invoke=function() PakettiTransientNextOnset() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous Zoom Onset", invoke=function() PakettiTransientPreviousOnset() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next in Full Zoom Region", invoke=function() PakettiTransientNextRegion() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous in Full Zoom Region", invoke=function() PakettiTransientPreviousRegion() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next Without Zoom", invoke=function() PakettiTransientNextPoint() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous Without Zoom", invoke=function() PakettiTransientPreviousPoint() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next Point Cursor", invoke=function() PakettiTransientNextPoint() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous Point Cursor", invoke=function() PakettiTransientPreviousPoint() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Toggle Mode", invoke=function() PakettiTransientToggleSelectMode() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Slice at Cursor", invoke=function() PakettiTransientSliceAtCursor() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Delete Left of Cursor", invoke=function() PakettiTransientDeleteLeft() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Delete Right of Cursor", invoke=function() PakettiTransientDeleteRight() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Re-detect", invoke=function() PakettiTransientRedetect() end}

renoise.tool():add_midi_mapping{name="Paketti:Transient Next", invoke=function(message) if message:is_trigger() then PakettiTransientNext() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Previous", invoke=function(message) if message:is_trigger() then PakettiTransientPrevious() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Toggle Mode", invoke=function(message) if message:is_trigger() then PakettiTransientToggleSelectMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Slice at Cursor", invoke=function(message) if message:is_trigger() then PakettiTransientSliceAtCursor() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Delete Left of Cursor", invoke=function(message) if message:is_trigger() then PakettiTransientDeleteLeft() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Delete Right of Cursor", invoke=function(message) if message:is_trigger() then PakettiTransientDeleteRight() end end}

-- FEATURE-CARD >> features/transient-integration.feature
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Detection Settings...",invoke=PakettiTransientSettingsDialog}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Transient Navigation:Detection Settings...",invoke=PakettiTransientSettingsDialog}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Detection Settings...",invoke=PakettiTransientSettingsDialog}
for _, command in ipairs({
  {"Selection Start to Previous Transient","start",-1},
  {"Selection Start to Next Transient","start",1},
  {"Selection End to Previous Transient","end",-1},
  {"Selection End to Next Transient","end",1},
  {"Selection Both Edges Out","both",1},
  {"Selection Both Edges In","both",-1},
}) do
  local which,direction=command[2],command[3]
  local function invoke() PakettiTransientSelectionEdge(which,direction) end
  PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:"..command[1],invoke=invoke}
  renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient "..command[1],invoke=invoke}
  renoise.tool():add_midi_mapping{name="Paketti:Transient "..command[1],invoke=function(message) if message:is_trigger() then invoke() end end}
end
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Crop to Selection",invoke=PakettiTransientCropSelection}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Crop to Selection",invoke=function(repeated) if not repeated then PakettiTransientCropSelection() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Crop to Selection",invoke=function(message) if message:is_trigger() then PakettiTransientCropSelection() end end}
