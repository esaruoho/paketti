-- PakettiTransientNavigation.lua
-- Tab-to-transient navigation for the Renoise Sample Editor.
--
-- The idea (from Pro Tools / REAPER / Acon Acoustica, requested by le(m)on on
-- Discord): jump the edit cursor straight to the next/previous detected attack
-- transient WITHOUT populating the sample with slice markers. Then optionally
-- slice at the cursor, or crop away everything to the left / right of it.
--
-- Reuses the transient detector already living in PakettiBeatDetect.lua:
--   * BeatDetector (global class) - filtered envelope-follower + Schmitt trigger
--   * the same lowpass+highpass "combined" defaults BeatSlicerDetect uses
-- The per-frame scan is expensive, so detected positions are computed ONCE and
-- cached per sample; navigation keystrokes then just read the cached list.

--------------------------------------------------------------------------------
-- Detection defaults (mirror PakettiBeatDetectSliceHeadless "combined" mode)
--------------------------------------------------------------------------------
local TN_DEFAULTS = {
  lowpass_freq = 150, rtime_low = 0.02, peak_on_low = 0.12, peak_off_low = 0.005,
  highpass_freq = 3000, rtime_high = 0.02, peak_on_high = 0.12, peak_off_high = 0.005,
  min_slice_distance_ms = 50, zero_crossing = 1,
}

--------------------------------------------------------------------------------
-- Cache
--------------------------------------------------------------------------------
local tn_cached_positions = nil   -- sorted array of transient frame indices (1-based)
local tn_cached_key = nil         -- fingerprint of the sample the cache belongs to

--------------------------------------------------------------------------------
-- Local helpers (declared BEFORE any function that calls them - see Paketti rule 28)
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

-- Run the combined lowpass+highpass detector over the sample and return a sorted,
-- zero-crossing-snapped, minimum-distance-filtered list of transient frames.
local function tn_detect_positions(sample)
  local buffer = sample.sample_buffer
  local sample_rate = buffer.sample_rate
  local min_slice_distance_samples = math.floor((TN_DEFAULTS.min_slice_distance_ms / 1000) * sample_rate)
  local zero_crossing_threshold = TN_DEFAULTS.zero_crossing / 100
  local search_range_samples = math.floor((10 / 1000) * sample_rate)

  local det_low = BeatDetector(TN_DEFAULTS.lowpass_freq, TN_DEFAULTS.rtime_low,
    TN_DEFAULTS.peak_on_low, TN_DEFAULTS.peak_off_low, 'lowpass')
  det_low:setSampleRate(sample_rate)
  local det_high = BeatDetector(TN_DEFAULTS.highpass_freq, TN_DEFAULTS.rtime_high,
    TN_DEFAULTS.peak_on_high, TN_DEFAULTS.peak_off_high, 'highpass')
  det_high:setSampleRate(sample_rate)

  local raw = {}
  local nframes = buffer.number_of_frames
  for i = 1, nframes do
    local input = buffer:sample_data(1, i)
    -- Process BOTH detectors every frame; never short-circuit or the second one
    -- desyncs and stops finding transients.
    local low_hit = det_low:Process(input)
    local high_hit = det_high:Process(input)
    if low_hit == true or high_hit == true then
      raw[#raw + 1] = i
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
  return filtered
end

-- Cached getter. Recomputes when the selected sample changed or force==true.
local function tn_get_positions(sample, force)
  local key = tn_sample_key(sample)
  if force or tn_cached_key ~= key or tn_cached_positions == nil then
    renoise.app():show_status("Transient Nav: detecting transients...")
    tn_cached_positions = tn_detect_positions(sample)
    tn_cached_key = key
  end
  return tn_cached_positions
end

-- Scroll the zoomed waveform view so `frame` is visible (centred) when it would
-- otherwise be off-screen. No-op when fully zoomed out.
local function tn_follow_view(buffer, frame)
  local view_len = buffer.display_length
  local nframes = buffer.number_of_frames
  if view_len >= nframes then return end
  local vs = buffer.display_start
  local ve = vs + view_len - 1
  if frame < vs or frame > ve then
    local new_start = math.floor(frame - view_len / 2)
    new_start = math.max(1, math.min(new_start, nframes - view_len + 1))
    buffer.display_start = new_start
  end
end

-- Set the selection to [a..b], order-safe so selection_start is never > end
-- mid-assignment (Renoise would clamp/refuse). a==b places a point cursor.
local function tn_select_range(buffer, a, b)
  local nframes = buffer.number_of_frames
  a = math.max(1, math.min(a, nframes))
  b = math.max(1, math.min(b, nframes))
  if a > b then a, b = b, a end
  local cur_end = buffer.selection_end
  if a > cur_end then
    buffer.selection_end = b
    buffer.selection_start = a
  else
    buffer.selection_start = a
    buffer.selection_end = b
  end
  tn_follow_view(buffer, a)
end

-- Augmented boundary list: 1, transients..., number_of_frames (for chunk select).
local function tn_boundaries(sample)
  local positions = tn_get_positions(sample)
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

--------------------------------------------------------------------------------
-- Point-cursor navigation
--------------------------------------------------------------------------------
function PakettiTransientNextPoint()
  local sample = tn_current_sample(); if not sample then return end
  local buffer = sample.sample_buffer
  local positions = tn_get_positions(sample)
  if #positions == 0 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = math.max(buffer.selection_start, buffer.selection_end)
  local target = nil
  for _, p in ipairs(positions) do if p > ref then target = p break end end
  if not target then renoise.app():show_status("Transient Nav: already at the last transient."); return end
  tn_select_range(buffer, target, target)
  renoise.app():show_status(string.format("Transient Nav: cursor at frame %d", target))
end

function PakettiTransientPreviousPoint()
  local sample = tn_current_sample(); if not sample then return end
  local buffer = sample.sample_buffer
  local positions = tn_get_positions(sample)
  if #positions == 0 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local ref = math.min(buffer.selection_start, buffer.selection_end)
  local target = nil
  for i = #positions, 1, -1 do if positions[i] < ref then target = positions[i] break end end
  if not target then renoise.app():show_status("Transient Nav: already at the first transient."); return end
  tn_select_range(buffer, target, target)
  renoise.app():show_status(string.format("Transient Nav: cursor at frame %d", target))
end

--------------------------------------------------------------------------------
-- Chunk-select navigation (highlight hit-to-hit)
--------------------------------------------------------------------------------
function PakettiTransientNextSelect()
  local sample = tn_current_sample(); if not sample then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local k = tn_current_chunk_index(B, buffer.selection_start)
  k = math.min(k + 1, #B - 1)
  tn_select_range(buffer, B[k], B[k + 1])
  renoise.app():show_status(string.format("Transient Nav: selected frames %d..%d (%d)", B[k], B[k + 1], B[k + 1] - B[k] + 1))
end

function PakettiTransientPreviousSelect()
  local sample = tn_current_sample(); if not sample then return end
  local buffer = sample.sample_buffer
  local B = tn_boundaries(sample)
  if #B < 2 then renoise.app():show_status("Transient Nav: no transients detected."); return end
  local k = tn_current_chunk_index(B, buffer.selection_start)
  k = math.max(k - 1, 1)
  tn_select_range(buffer, B[k], B[k + 1])
  renoise.app():show_status(string.format("Transient Nav: selected frames %d..%d (%d)", B[k], B[k + 1], B[k + 1] - B[k] + 1))
end

--------------------------------------------------------------------------------
-- Unified Next/Previous (dispatch on the Select-Mode preference) + toggle
--------------------------------------------------------------------------------
function PakettiTransientNext()
  if preferences.pakettiTransientNavSelectMode.value then
    PakettiTransientNextSelect()
  else
    PakettiTransientNextPoint()
  end
end

function PakettiTransientPrevious()
  if preferences.pakettiTransientNavSelectMode.value then
    PakettiTransientPreviousSelect()
  else
    PakettiTransientPreviousPoint()
  end
end

function PakettiTransientToggleSelectMode()
  local v = not preferences.pakettiTransientNavSelectMode.value
  preferences.pakettiTransientNavSelectMode.value = v
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Transient Nav: Next/Previous now " .. (v and "SELECT next chunk" or "place a POINT cursor"))
end

--------------------------------------------------------------------------------
-- Re-detect (force recompute; report count)
--------------------------------------------------------------------------------
function PakettiTransientRedetect()
  local sample = tn_current_sample(); if not sample then return end
  local positions = tn_get_positions(sample, true)
  renoise.app():show_status(string.format("Transient Nav: detected %d transients.", #positions))
end

-- Called after any destructive edit so the next navigation re-detects.
function PakettiTransientNavInvalidate()
  tn_cached_positions = nil
  tn_cached_key = nil
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
  renoise.app():show_status(string.format("Transient Nav: cropped to %d frames (kept %d..%d).", new_len, keep_start, keep_end))
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
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient (Point Cursor)", invoke=function() PakettiTransientNextPoint() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient (Point Cursor)", invoke=function() PakettiTransientPreviousPoint() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Next Transient (Select Chunk)", invoke=function() PakettiTransientNextSelect() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Previous Transient (Select Chunk)", invoke=function() PakettiTransientPreviousSelect() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Toggle Next/Previous Select Mode", invoke=function() PakettiTransientToggleSelectMode() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Slice at Cursor", invoke=function() PakettiTransientSliceAtCursor() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Delete Left of Cursor", invoke=function() PakettiTransientDeleteLeft() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Delete Right of Cursor", invoke=function() PakettiTransientDeleteRight() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Transient Navigation:Re-detect Transients", invoke=function() PakettiTransientRedetect() end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next", invoke=function() PakettiTransientNext() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous", invoke=function() PakettiTransientPrevious() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next Point Cursor", invoke=function() PakettiTransientNextPoint() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous Point Cursor", invoke=function() PakettiTransientPreviousPoint() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Next Select Chunk", invoke=function() PakettiTransientNextSelect() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Previous Select Chunk", invoke=function() PakettiTransientPreviousSelect() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Toggle Select Mode", invoke=function() PakettiTransientToggleSelectMode() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Slice at Cursor", invoke=function() PakettiTransientSliceAtCursor() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Delete Left of Cursor", invoke=function() PakettiTransientDeleteLeft() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Delete Right of Cursor", invoke=function() PakettiTransientDeleteRight() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Transient Re-detect", invoke=function() PakettiTransientRedetect() end}

renoise.tool():add_midi_mapping{name="Paketti:Transient Next", invoke=function(message) if message:is_trigger() then PakettiTransientNext() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Previous", invoke=function(message) if message:is_trigger() then PakettiTransientPrevious() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Toggle Select Mode", invoke=function(message) if message:is_trigger() then PakettiTransientToggleSelectMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Slice at Cursor", invoke=function(message) if message:is_trigger() then PakettiTransientSliceAtCursor() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Delete Left of Cursor", invoke=function(message) if message:is_trigger() then PakettiTransientDeleteLeft() end end}
renoise.tool():add_midi_mapping{name="Paketti:Transient Delete Right of Cursor", invoke=function(message) if message:is_trigger() then PakettiTransientDeleteRight() end end}
