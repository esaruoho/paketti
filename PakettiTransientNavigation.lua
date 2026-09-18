-- PakettiTransientNavigation.lua
-- Tab-to-transient navigation for the Renoise Sample Editor.
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
  lowpass_freq = 150, rtime_low = 0.02, peak_on_low = 0.04, peak_off_low = 0.005,
  highpass_freq = 3000, rtime_high = 0.02, peak_on_high = 0.04, peak_off_high = 0.005,
  min_slice_distance_ms = 35, zero_crossing = 1,
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
local tn_detecting = false        -- a ProcessSlicer detection is currently running

--------------------------------------------------------------------------------
-- Local helpers (declared BEFORE any function that calls them - Paketti rule 28)
--------------------------------------------------------------------------------

-- Zero-crossing snap. PakettiBeatDetect's own copy is file-local, so we keep a
-- small equivalent here rather than reaching across files.
local function tn_find_zero_crossing(buffer, pos, search_range_samples, zero_threshold)
  local start_pos = math.max(1, pos - search_range_samples)
  local end_pos = math.min(buffer.number_of_frames, pos + search_range_samples)
  local zero_crossing_pos = pos
  local min_amplitude = math.abs(buffer:sample_data(1, pos))
  for i = pos, start_pos, -1 do
    local v = math.abs(buffer:sample_data(1, i))
    if v <= zero_threshold then zero_crossing_pos = i break
    elseif v < min_amplitude then min_amplitude = v zero_crossing_pos = i end
  end
  if zero_crossing_pos == pos then
    for i = pos, end_pos do
      local v = math.abs(buffer:sample_data(1, i))
      if v <= zero_threshold then zero_crossing_pos = i break
      elseif v < min_amplitude then min_amplitude = v zero_crossing_pos = i end
    end
  end
  return zero_crossing_pos
end

-- Return the selected sample, or nil (with a status message) if there is nothing
-- usable to navigate.
local function tn_current_sample()
  local song = renoise.song()
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
-- count so any content resize (including our own crops) invalidates it.
local function tn_sample_key(sample)
  local song = renoise.song()
  local buffer = sample.sample_buffer
  return string.format("%d:%d:%d:%d:%d:%s",
    song.selected_instrument_index, song.selected_sample_index,
    buffer.number_of_frames, buffer.sample_rate, buffer.number_of_channels,
    sample.name)
end

-- True when the cache is valid for the given sample.
local function tn_cache_valid(sample)
  return tn_cached_positions ~= nil and tn_cached_key == tn_sample_key(sample)
end

-- Called after any destructive edit so the next navigation re-detects.
function PakettiTransientNavInvalidate()
  tn_cached_positions = nil
  tn_cached_key = nil
end

-- Run the combined detector over the sample inside a ProcessSlicer (non-blocking),
-- fill the cache, then call on_done (used to auto-perform the requested jump).
local function tn_start_detection(sample, on_done)
  if tn_detecting then
    renoise.app():show_status("Transient Nav: detection already in progress...")
    return
  end
  tn_detecting = true
  local buffer = sample.sample_buffer
  local nframes = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  local key = tn_sample_key(sample)

  local min_slice_distance_samples = math.floor((TN_DEFAULTS.min_slice_distance_ms / 1000) * sample_rate)
  local zero_crossing_threshold = TN_DEFAULTS.zero_crossing / 100
  local search_range_samples = math.floor((10 / 1000) * sample_rate)

  local slicer = ProcessSlicer(function()
    local det_low = BeatDetector(TN_DEFAULTS.lowpass_freq, TN_DEFAULTS.rtime_low,
      TN_DEFAULTS.peak_on_low, TN_DEFAULTS.peak_off_low, 'lowpass')
    det_low:setSampleRate(sample_rate)
    local det_high = BeatDetector(TN_DEFAULTS.highpass_freq, TN_DEFAULTS.rtime_high,
      TN_DEFAULTS.peak_on_high, TN_DEFAULTS.peak_off_high, 'highpass')
    det_high:setSampleRate(sample_rate)

    local raw = {}
    for i = 1, nframes do
      local input = buffer:sample_data(1, i)
      -- Process BOTH detectors every frame; never short-circuit or the second
      -- one desyncs and stops finding transients.
      local low_hit = det_low:Process(input)
      local high_hit = det_high:Process(input)
      if low_hit == true or high_hit == true then
        raw[#raw + 1] = i
      end
      if i % 16384 == 0 then
        renoise.app():show_status(string.format("Transient Nav: detecting transients... %d%%",
          math.floor((i / nframes) * 100)))
        coroutine.yield()
      end
    end

    table.sort(raw)
    local filtered = {}
    local last = nil
    for _, pos in ipairs(raw) do
      if not last or (pos - last) >= min_slice_distance_samples then
        local zc = tn_find_zero_crossing(buffer, pos, search_range_samples, zero_crossing_threshold)
        filtered[#filtered + 1] = zc
        last = zc
      end
    end

    tn_cached_positions = filtered
    tn_cached_key = key
    tn_detecting = false
    renoise.app():show_status(string.format("Transient Nav: %d transients detected.", #filtered))
    if on_done then on_done() end
  end)
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
  disp_start = math.max(1, math.min(disp_start, nframes - disp_len + 1))
  tn_ensure_sample_editor()
  -- When fully zoomed out (display_length == number_of_frames) Renoise refuses to
  -- set display_start ("no display_start's are available"). So bring display_start
  -- back to 1 ONLY while zoomed in, then set the (smaller) length, which makes
  -- display_start settable again, then move it. Every step keeps
  -- display_start + display_length - 1 <= number_of_frames.
  if buffer.display_length < nframes then buffer.display_start = 1 end
  buffer.display_length = disp_len
  if disp_len < nframes then buffer.display_start = disp_start end
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

-- Augmented boundary list: 1, transients..., number_of_frames.
local function tn_boundaries(sample)
  local positions = tn_cached_positions or {}
  local buffer = sample.sample_buffer
  local B = {}
  if positions[1] ~= 1 then B[#B + 1] = 1 end
  for _, p in ipairs(positions) do B[#B + 1] = p end
  local nf = buffer.number_of_frames
  if B[#B] ~= nf then B[#B + 1] = nf end
  return B
end

-- Index k of the chunk [B[k]..B[k+1]] that contains `ref`.
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
  local k = tn_current_chunk_index(B, ref)
  k = math.min(k + 1, #B - 1)
  tn_show_region(buffer, B[k], B[k + 1])
  renoise.app():show_status(string.format("Transient Nav: region %d/%d  frames %d..%d (%d)",
    k, #B - 1, B[k], B[k + 1], B[k + 1] - B[k] + 1))
end

function PakettiTransientPreviousRegion()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientPreviousRegion) then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_selection_is_whole(buffer) and (buffer.number_of_frames + 1) or buffer.selection_start
  local k = tn_current_chunk_index(B, ref)
  k = math.max(k - 1, 1)
  tn_show_region(buffer, B[k], B[k + 1])
  renoise.app():show_status(string.format("Transient Nav: region %d/%d  frames %d..%d (%d)",
    k, #B - 1, B[k], B[k + 1], B[k + 1] - B[k] + 1))
end

--------------------------------------------------------------------------------
-- Onset navigation (cursor on the transient, zoomed IN close on the attack) -
-- "next transient with zoom".
--------------------------------------------------------------------------------
function PakettiTransientNextOnset()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientNextOnset) then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_ref_next(buffer)
  local ti = nil
  for i = 1, #B do if B[i] > ref then ti = i break end end
  if not ti then renoise.app():show_status("Transient Nav: already at the last transient."); return end
  local region_end = B[ti + 1] or buffer.number_of_frames
  tn_show_onset(buffer, B[ti], region_end)
  renoise.app():show_status(string.format("Transient Nav: onset at frame %d (zoomed)", B[ti]))
end

function PakettiTransientPreviousOnset()
  local sample = tn_current_sample(); if not sample then return end
  if not tn_ensure_positions(sample, PakettiTransientPreviousOnset) then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = tn_ref_prev(buffer)
  local ti = nil
  for i = #B, 1, -1 do if B[i] < ref then ti = i break end end
  if not ti then renoise.app():show_status("Transient Nav: already at the first transient."); return end
  local region_end = B[ti + 1] or buffer.number_of_frames
  tn_show_onset(buffer, B[ti], region_end)
  renoise.app():show_status(string.format("Transient Nav: onset at frame %d (zoomed)", B[ti]))
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
  if not target then renoise.app():show_status("Transient Nav: already at the last transient."); return end
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
  if not target then renoise.app():show_status("Transient Nav: already at the first transient."); return end
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
  if sample.is_slice_alias then
    renoise.app():show_status("Transient Nav: cannot crop a slice alias.")
    return
  end
  local buffer = sample.sample_buffer
  local nframes = buffer.number_of_frames
  keep_start = math.max(1, math.min(keep_start, nframes))
  keep_end = math.max(1, math.min(keep_end, nframes))
  if keep_end <= keep_start then
    renoise.app():show_status("Transient Nav: nothing left to keep - crop aborted.")
    return
  end
  local new_len = keep_end - keep_start + 1
  local nch = buffer.number_of_channels
  local rate = buffer.sample_rate
  local depth = buffer.bit_depth

  -- Remember frame-referenced properties so we can remap them.
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
  buffer:create_sample_data(rate, depth, nch, new_len)
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
  if ne < ns then ne = new_len end
  pcall(function() sample.loop_start = ns end)
  pcall(function() sample.loop_end = ne end)

  PakettiTransientNavInvalidate()

  local caret = (cursor_after == "end") and new_len or 1
  buffer.selection_start = caret
  buffer.selection_end = caret
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

--------------------------------------------------------------------------------
-- Registrations (LAST in the file - definitions above; Paketti rule 18)
--------------------------------------------------------------------------------
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient", invoke=function() PakettiTransientNext() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient", invoke=function() PakettiTransientPrevious() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient (Zoom to Onset)", invoke=function() PakettiTransientNextOnset() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient (Zoom to Onset)", invoke=function() PakettiTransientPreviousOnset() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient in Full (Zoom to Fit Region)", invoke=function() PakettiTransientNextRegion() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient in Full (Zoom to Fit Region)", invoke=function() PakettiTransientPreviousRegion() end}
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
