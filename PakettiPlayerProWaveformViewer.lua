-- Paketti PlayerPro Waveform Viewer
-- Realtime horizontal pattern view drawing sample waveforms per track/row
-- Requirements honored:
-- - Lua 5.1
-- - All functions are GLOBAL, defined before first use
-- - Uses my_keyhandler_func from main.lua
-- - After dialog opens, Reactivate middle frame to pass keys to Renoise
-- - Stable ViewBuilder layout; only canvas updates
-- - Print debug info and use show_status for user feedback

-- Global state
PakettiPPWV_dialog = nil
PakettiPPWV_vb = nil
PakettiPPWV_canvas = nil
PakettiPPWV_canvas_width = 1200
PakettiPPWV_lane_height = 40
PakettiPPWV_canvas_height = 400
PakettiPPWV_timer_running = false
PakettiPPWV_timer_interval_ms = 50   -- Balanced: 20 FPS for responsive pattern input, but not the original 50 FPS performance nightmare
PakettiPPWV_last_content_hash = ""
PakettiPPWV_events = {}
PakettiPPWV_selected_event_id = nil
PakettiPPWV_cached_waveforms = {}
PakettiPPWV_reference_scale_cache = {}  -- OPTIMIZATION: Cache reference calculations per zoom
PakettiPPWV_debug = false

-- Double-click tracking
PakettiPPWV_last_click_time_ms = 0
PakettiPPWV_last_click_x = -1000
PakettiPPWV_last_click_y = -1000
PakettiPPWV_double_click_threshold_ms = 450

-- Use shared canvas font helper for labels
function PakettiPPWV_DrawText(ctx, text, x, y, size)
  PakettiCanvasFontDrawText(ctx, text, x, y, size)
end

-- Load preferences into global variables
function PakettiPPWV_LoadPreferences()
  if PakettiPlayerProWaveformViewer then
    PakettiPPWV_show_only_selected_track = PakettiPlayerProWaveformViewer.OnlySelectedTrack.value
    PakettiPPWV_show_sample_names = PakettiPlayerProWaveformViewer.SampleName.value
    PakettiPPWV_show_labels = PakettiPlayerProWaveformViewer.InstrumentName.value
    PakettiPPWV_show_note_names = PakettiPlayerProWaveformViewer.NoteName.value
    PakettiPPWV_vertical_scale_index = PakettiPlayerProWaveformViewer.Zoom.value
    PakettiPPWV_orientation = PakettiPlayerProWaveformViewer.Direction.value
    PakettiPPWV_show_horizontal_playhead = PakettiPlayerProWaveformViewer.HorizontalPlayhead.value
    PakettiPPWV_show_vertical_playhead = PakettiPlayerProWaveformViewer.VerticalPlayhead.value
    print("-- PPWV: Loaded preferences from settings")
  end
end

-- Save preferences from global variables
function PakettiPPWV_SavePreferences()
  if PakettiPlayerProWaveformViewer then
    PakettiPlayerProWaveformViewer.OnlySelectedTrack.value = PakettiPPWV_show_only_selected_track
    PakettiPlayerProWaveformViewer.SampleName.value = PakettiPPWV_show_sample_names
    PakettiPlayerProWaveformViewer.InstrumentName.value = PakettiPPWV_show_labels
    PakettiPlayerProWaveformViewer.NoteName.value = PakettiPPWV_show_note_names
    PakettiPlayerProWaveformViewer.Zoom.value = PakettiPPWV_vertical_scale_index
    PakettiPlayerProWaveformViewer.Direction.value = PakettiPPWV_orientation
    PakettiPlayerProWaveformViewer.HorizontalPlayhead.value = PakettiPPWV_show_horizontal_playhead
    PakettiPlayerProWaveformViewer.VerticalPlayhead.value = PakettiPPWV_show_vertical_playhead
    print("-- PPWV: Saved preferences to settings")
  end
end

-- Function to select all samples that match the currently selected sample when "Select the same" is enabled
function PakettiPPWV_SelectAllMatchingSamples()
  if not PakettiPPWV_select_same_enabled then return end
  
  -- If we have a currently selected event, select all matching ones
  if PakettiPPWV_selected_event_id then
    local anchor_event = nil
    -- Find the anchor event
    for i = 1, #PakettiPPWV_events do
      local e = PakettiPPWV_events[i]
      if e.id == PakettiPPWV_selected_event_id then
        anchor_event = e
        break
      end
    end
    
    if anchor_event then
      -- Clear existing selection and select all matching samples
      PakettiPPWV_selected_ids = {}
      for i = 1, #PakettiPPWV_events do
        local e = PakettiPPWV_events[i]
        if e.track_index == anchor_event.track_index and e.instrument_index == anchor_event.instrument_index and e.sample_index == anchor_event.sample_index then
          PakettiPPWV_selected_ids[e.id] = true
        end
      end
      print(string.format("-- PPWV SELECT SAME (auto): Found and selected %d matching samples for nudge", PakettiPPWV_SelectedCount()))
      -- Show selection highlights immediately for user feedback
      PakettiPPWV_UpdateCanvasThrottled()
    end
  else
    print("-- PPWV SELECT SAME (auto): No sample currently selected to match")
  end
end

-- Viewport/zoom state
PakettiPPWV_zoom_levels = {1.0, 0.5, 0.25, 0.125}
PakettiPPWV_zoom_index = 1 -- 1.0 by default (full pattern)
PakettiPPWV_view_start_line = 1
PakettiPPWV_show_labels = false
PakettiPPWV_show_sample_names = false
PakettiPPWV_show_note_names = false
PakettiPPWV_show_horizontal_playhead = true  -- Enable/disable horizontal playhead (yellow line)
PakettiPPWV_show_vertical_playhead = true    -- Enable/disable vertical playhead (yellow line)
PakettiPPWV_performance_mode = false  -- OPTIMIZATION #7: Performance mode toggle (flat fills vs gradients)
PakettiPPWV_batch_tracks = false     -- OPTIMIZATION #8: Batch multiple tracks per canvas in vertical mode
PakettiPPWV_scrollbar_view = nil
PakettiPPWV_vscrollbar_view = nil
PakettiPPWV_show_only_selected_track = false  -- DEFAULT: Let user choose whether to enable selected track only mode
PakettiPPWV_last_selected_track_index = 0
PakettiPPWV_multi_select_mode = false
PakettiPPWV_selected_ids = {}
PakettiPPWV_orientation = 1 -- 1=horizontal, 2=vertical
PakettiPPWV_shift_click_until_ms = 0
PakettiPPWV_select_same_enabled = false
PakettiPPWV_vertical_scale_index = 1 -- 1x,2x,3x
PakettiPPWV_base_canvas_height = PakettiPPWV_canvas_height
PakettiPPWV_min_redraw_ms = 60
PakettiPPWV_last_redraw_ms = 0
PakettiPPWV_tracks_container = nil
PakettiPPWV_track_canvases = {}
PakettiPPWV_shift_is_down = false
PakettiPPWV_alt_is_down = false
PakettiPPWV_is_dup_dragging = false
PakettiPPWV_gutter_width = 0
PakettiPPWV_gutter_height = 16
PakettiPPWV_header_canvas = nil
PakettiPPWV_ctrl_is_down = false
PakettiPPWV_cmd_is_down = false
PakettiPPWV_dup_anchor_id = nil
PakettiPPWV_dup_total_ticks = 0
PakettiPPWV_track_mute_observers = {}
PakettiPPWV_selected_track_observer = nil
PakettiPPWV_tracks_observable = nil -- Track list observable for add/remove detection
PakettiPPWV_tracks_observer_func = nil -- Store the actual observer function for proper removal
PakettiPPWV_last_playhead_line = -1
PakettiPPWV_timeline_sidebar = nil
PakettiPPWV_last_mute_hash = "" -- Fallback mute state hash for change detection
PakettiPPWV_last_sample_hash = "" -- Sample buffer hash for detecting sample modifications (like reverse, crop, etc.)
PakettiPPWV_last_click_event = nil  -- Store last clicked event for double-click detection

PakettiPPWV_pending_update = false
PakettiPPWV_update_timer = nil


function PakettiPPWV_ScheduleDeferredUpdate()
  if PakettiPPWV_update_timer then
    -- Cancel existing timer to reset the delay
    renoise.tool():remove_timer(PakettiPPWV_update_timer)
  end
  
  PakettiPPWV_pending_update = true
  PakettiPPWV_update_timer = function()
    if PakettiPPWV_pending_update then
      print("-- PPWV: Executing deferred pattern rebuild and canvas update")
      PakettiPPWV_RebuildEvents()
      PakettiPPWV_UpdateCanvasThrottled()
      PakettiPPWV_pending_update = false
      PakettiPPWV_update_timer = nil
    end
  end
  
  -- 150ms delay - batches rapid key presses but feels responsive
  renoise.tool():add_timer(PakettiPPWV_update_timer, 150)
  print("-- PPWV: Scheduled deferred update (150ms)")
end


function PakettiPPWV_UpdateModifierFlags(mods)
  if type(mods) ~= "string" then mods = tostring(mods or "") end
  local m = mods:lower()
  PakettiPPWV_shift_is_down = (string.find(m, "shift", 1, true) ~= nil)
  PakettiPPWV_alt_is_down = (string.find(m, "alt", 1, true) ~= nil) or (string.find(m, "option", 1, true) ~= nil)
  PakettiPPWV_ctrl_is_down = (string.find(m, "control", 1, true) ~= nil) or (string.find(m, "ctrl", 1, true) ~= nil)
  PakettiPPWV_cmd_is_down = (string.find(m, "command", 1, true) ~= nil) or (string.find(m, "cmd", 1, true) ~= nil)
end

function PakettiPPWV_DebugPrintModifierFlags(prefix)
  print(string.format("-- PPWV MODS %s shift=%s alt=%s ctrl=%s cmd=%s", prefix or "", tostring(PakettiPPWV_shift_is_down), tostring(PakettiPPWV_alt_is_down), tostring(PakettiPPWV_ctrl_is_down), tostring(PakettiPPWV_cmd_is_down)))
end

-- Duplicate current pattern below and jump to it (no clearing of muted tracks)
function PakettiPPWV_DuplicatePattern()
  local song = renoise.song()
  local current_pattern_index = song.selected_pattern_index
  local current_sequence_index = song.selected_sequence_index
  local new_sequence_index = current_sequence_index + 1
  local new_pattern_index = song.sequencer:insert_new_pattern_at(new_sequence_index)
  song.patterns[new_pattern_index]:copy_from(song.patterns[current_pattern_index])
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (duplicate)"
  song.selected_sequence_index = new_sequence_index
  
  -- Copy mute states from original sequence slot to the new one
  for track_index = 1, #song.tracks do
    local is_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end
  
  -- Copy automation data explicitly to ensure full duplication
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[new_pattern_index].tracks[track_index]
    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end
  
  renoise.app():show_status("Duplicated pattern below and jumped to it.")
  
  -- Refresh the waveform viewer to show the new pattern
  PakettiPPWV_UpdateCanvasThrottled()
end

function PakettiPPWV_SelectedCount()
  if not PakettiPPWV_selected_ids then return 0 end
  local n = 0
  for _k,_v in pairs(PakettiPPWV_selected_ids) do
    if _v then n = n + 1 end
  end
  return n
end

function PakettiPPWV_HandleClickSelection(evhit)
  if not evhit then return end
  if PakettiPPWV_select_same_enabled then
    PakettiPPWV_selected_ids = {}
    PakettiPPWV_selected_event_id = evhit.id
    for i = 1, #PakettiPPWV_events do
      local e = PakettiPPWV_events[i]
      if e.track_index == evhit.track_index and e.instrument_index == evhit.instrument_index and e.sample_index == evhit.sample_index then
        PakettiPPWV_selected_ids[e.id] = true
      end
    end
    print(string.format("-- PPWV SELECT SAME: anchor=%s size=%d", tostring(evhit.id), PakettiPPWV_SelectedCount()))
    return
  end
  local multi_mode = PakettiPPWV_shift_is_down or PakettiPPWV_multi_select_mode
  if multi_mode then
    if not PakettiPPWV_selected_event_id then
      PakettiPPWV_selected_event_id = evhit.id
      if not PakettiPPWV_selected_ids then PakettiPPWV_selected_ids = {} end
      PakettiPPWV_selected_ids[evhit.id] = true
      print(string.format("-- PPWV MULTI ANCHOR SET: %s size=%d", tostring(evhit.id), PakettiPPWV_SelectedCount()))
    else
      local anchor_track = nil
      for i = 1, #PakettiPPWV_events do
        local e = PakettiPPWV_events[i]
        if e.id == PakettiPPWV_selected_event_id then anchor_track = e.track_index; break end
      end
      if anchor_track == evhit.track_index then
        if PakettiPPWV_selected_ids[evhit.id] then
          PakettiPPWV_selected_ids[evhit.id] = nil
        else
          PakettiPPWV_selected_ids[evhit.id] = true
        end
        print(string.format("-- PPWV MULTI TOGGLE: %s size=%d", tostring(evhit.id), PakettiPPWV_SelectedCount()))
      else
        PakettiPPWV_selected_ids = {}
        PakettiPPWV_selected_event_id = evhit.id
        PakettiPPWV_selected_ids[evhit.id] = true
        print(string.format("-- PPWV MULTI TRACK CHANGED: %s size=%d", tostring(evhit.id), PakettiPPWV_SelectedCount()))
      end
    end
  else
    PakettiPPWV_selected_ids = {}
    PakettiPPWV_selected_event_id = evhit.id
    print(string.format("-- PPWV SINGLE SELECT: %s", tostring(evhit.id)))
  end
end

-- Delete currently selected events from the pattern
function PakettiPPWV_DeleteSelectedEvents()
  local song, patt = PakettiPPWV_GetSongAndPattern(); if not song or not patt then return end
  local ids_to_delete = {}
  if PakettiPPWV_selected_event_id then ids_to_delete[PakettiPPWV_selected_event_id] = true end
  if PakettiPPWV_selected_ids then
    for id, flag in pairs(PakettiPPWV_selected_ids) do if flag then ids_to_delete[id] = true end end
  end
  if next(ids_to_delete) == nil then return end
  -- Delete by walking events and clearing note columns
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ids_to_delete[ev.id] then
      local ptrack = patt:track(ev.track_index)
      local line = ptrack:line(ev.start_line)
      if line and line.note_columns and line.note_columns[ev.column_index] then
        local nc = line.note_columns[ev.column_index]
        if not nc.is_empty then
          nc:clear()
        end
      end
    end
  end
  renoise.app():show_status("PPWV: Deleted selected events")
  PakettiPPWV_selected_ids = {}
  PakettiPPWV_selected_event_id = nil
  PakettiPPWV_RebuildEvents(); PakettiPPWV_UpdateCanvasThrottled()
end

-- CRITICAL: Separate immediate and delayed canvas updates for better UX
function PakettiPPWV_UpdateCanvasImmediate()
  -- Direct canvas update - no throttling for user interactions  
  if PakettiPPWV_canvas then PakettiPPWV_canvas:update() end
  for _, canvas in ipairs(PakettiPPWV_track_canvases) do
    if canvas.visible then canvas:update() end
  end
  if PakettiPPWV_header_canvas then PakettiPPWV_header_canvas:update() end
  if PakettiPPWV_timeline_sidebar then PakettiPPWV_timeline_sidebar:update() end
end


function PakettiPPWV_UpdateCanvasThrottled()
  local now_ms = os.clock() * 1000
  -- Adaptive interval: Sane refresh rates that don't murder Renoise performance
  local song = renoise.song()
  local playing = song and song.transport.playing
  local interval = 200  -- 5 FPS when idle (was 120ms)
  if PakettiPPWV_is_dragging then
    interval = 50      -- 20 FPS when dragging (was 67 FPS!)
  elseif playing then
    interval = 100     -- 10 FPS during playback (was 30-50 FPS!)
  end
  PakettiPPWV_min_redraw_ms = interval
  if (now_ms - PakettiPPWV_last_redraw_ms) >= PakettiPPWV_min_redraw_ms then
    -- Reduced debug output to avoid console spam
    -- print("THROTTLE: updating canvases")
    
    if PakettiPPWV_canvas and PakettiPPWV_canvas.visible then 
      PakettiPPWV_canvas:update()
    end
    if PakettiPPWV_track_canvases and #PakettiPPWV_track_canvases > 0 then
      -- OPTIMIZATION #11: Only update visible canvases, skip off-screen ones in vertical mode
      local is_vertical = (PakettiPPWV_orientation == 2)
      for i = 1, #PakettiPPWV_track_canvases do
        local c = PakettiPPWV_track_canvases[i]
        if c and c.visible then
          -- Additional optimization: in vertical scrolled mode, could check if canvas is in view
          -- For now, basic visible check is sufficient as ViewBuilder handles most visibility
          c:update() 
        end
      end
    end
    if PakettiPPWV_header_canvas and PakettiPPWV_header_canvas.visible then PakettiPPWV_header_canvas:update() end
    if PakettiPPWV_timeline_sidebar and PakettiPPWV_timeline_sidebar.visible then PakettiPPWV_timeline_sidebar:update() end
    PakettiPPWV_last_redraw_ms = now_ms
  end
end

function PakettiPPWV_GetWindowLines(num_lines)
  local z = PakettiPPWV_zoom_levels[PakettiPPWV_zoom_index] or 1.0
  local win = math.max(1, math.floor(num_lines * z + 0.5))
  if win > num_lines then win = num_lines end
  return win
end

function PakettiPPWV_ClampView(num_lines)
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local max_start = math.max(1, num_lines - win + 1)
  if PakettiPPWV_view_start_line < 1 then PakettiPPWV_view_start_line = 1 end
  if PakettiPPWV_view_start_line > max_start then PakettiPPWV_view_start_line = max_start end
end

function PakettiPPWV_UpdateScrollbars()
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return end
  local num_lines = patt.number_of_lines
  PakettiPPWV_ClampView(num_lines)
  if PakettiPPWV_scrollbar_view then
    local win = PakettiPPWV_GetWindowLines(num_lines)
    PakettiPPWV_scrollbar_view.min = 1
    PakettiPPWV_scrollbar_view.max = num_lines + 1 -- to allow last window
    PakettiPPWV_scrollbar_view.pagestep = win
    PakettiPPWV_scrollbar_view.value = PakettiPPWV_view_start_line  -- Already 1-based, no conversion needed
  end
  if PakettiPPWV_vscrollbar_view then
    local win = PakettiPPWV_GetWindowLines(num_lines)
    PakettiPPWV_vscrollbar_view.min = 1
    PakettiPPWV_vscrollbar_view.max = num_lines + 1
    PakettiPPWV_vscrollbar_view.pagestep = win
    PakettiPPWV_vscrollbar_view.value = PakettiPPWV_view_start_line  -- Already 1-based, no conversion needed
  end
end

function PakettiPPWV_SetZoomIndex(idx)
  PakettiPPWV_zoom_index = math.max(1, math.min(#PakettiPPWV_zoom_levels, idx))
  PakettiPPWV_UpdateScrollbars()
  PakettiPPWV_UpdateCanvasThrottled()
end

function PakettiPPWV_MapTimeToX(t, num_lines)
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local view_start_t = (PakettiPPWV_view_start_line - 1)
  -- Account for gutters - use effective width, not full canvas width
  local eff_w = math.max(1, PakettiPPWV_canvas_width - (2*PakettiPPWV_gutter_width))
  if win <= 1 then
    return PakettiPPWV_gutter_width + eff_w / 2
  end
  local divisor = win  -- Expand content to fill space while leaving room for end boundary
  local x = PakettiPPWV_gutter_width + ((t - view_start_t) / divisor) * eff_w
  return x
end

function PakettiPPWV_MapTimeToY(t, num_lines, canvas_height)
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local view_start_t = PakettiPPWV_view_start_line  -- Keep 1-based for proper alignment
  local H = canvas_height or PakettiPPWV_canvas_height
  -- Map pattern rows across canvas height with proper alignment
  if win <= 1 then
    return H / 2
  end
  -- Ensure line 1 maps to y = 0, line 2 maps to y = H/win, etc.
  local divisor = win
  local y = ((t - view_start_t) / divisor) * H
  return y
end

-- Draw text via shared font if available
function PakettiPPWV_DrawTextShared(ctx, text, x, y, size)
  if type(PakettiCanvasFontDrawText) == "function" then
    PakettiCanvasFontDrawText(ctx, text, x, y, size)
  else
    PakettiPPWV_DrawText(ctx, text, x, y, size)
  end
end

-- Get raw mute state name for debugging
function PakettiPPWV_GetTrackMuteStateName(track)
  if not track then return "INVALID_TRACK" end
  if track.type == renoise.Track.TRACK_TYPE_MASTER then return "MASTER_NO_MUTE" end
  
  local ok, state = pcall(function() return track.mute_state end)
  if ok and state ~= nil then
    if state == renoise.Track.MUTE_STATE_ACTIVE then
      return "ACTIVE"
    elseif state == renoise.Track.MUTE_STATE_MUTED then
      return "MUTED" 
    elseif state == renoise.Track.MUTE_STATE_OFF then
      return "OFF"
    else
      return "OTHER(" .. tostring(state) .. ")"
    end
  end
  return "UNKNOWN"
end

-- Determine if a track is muted (covers solo-other-tracks cases as they become muted)
function PakettiPPWV_IsTrackMuted(track)
  if not track then return false end
  if track.type == renoise.Track.TRACK_TYPE_MASTER then return false end
  
  -- Check for all muted states: MUTED and OFF should both be considered as muted
  local ok, state = pcall(function() return track.mute_state end)
  if ok and state ~= nil then
    return (state == renoise.Track.MUTE_STATE_MUTED) or (state == renoise.Track.MUTE_STATE_OFF)
  end
  return false
end

-- Toggle track mute state
function PakettiPPWV_ToggleTrackMute(track_index)
  print("-- PPWV: PakettiPPWV_ToggleTrackMute called with track_index=" .. track_index)
  local song = renoise.song()
  if not song then 
    print("-- PPWV: No song available, cannot toggle mute")
    return 
  end
  if track_index < 1 or track_index > #song.tracks then 
    print("-- PPWV: Invalid track_index " .. track_index .. " (song has " .. #song.tracks .. " tracks)")
    return 
  end
  
  local track = song.tracks[track_index]
  print("-- PPWV: Track " .. track_index .. " type=" .. track.type .. " name='" .. (track.name or "") .. "'")
  
  -- Master track doesn't have mute state
  if track.type == renoise.Track.TRACK_TYPE_MASTER then 
    print("-- PPWV: Cannot toggle mute on master track")
    return 
  end
  
  local current_state = PakettiPPWV_GetTrackMuteStateName(track)
  print("-- PPWV: Current mute state: " .. current_state)
  
  if track.mute_state == renoise.Track.MUTE_STATE_MUTED or track.mute_state == renoise.Track.MUTE_STATE_OFF then
    print("-- PPWV: Unmuting track...")
    track:unmute()
    renoise.app():show_status("PPWV: Unmuted Track " .. string.format("%02d", track_index) .. (track.name and (" (" .. track.name .. ")") or ""))
  else
    print("-- PPWV: Muting track...")
    track:mute()
    renoise.app():show_status("PPWV: Muted Track " .. string.format("%02d", track_index) .. (track.name and (" (" .. track.name .. ")") or ""))
  end
  
  local new_state = PakettiPPWV_GetTrackMuteStateName(track)
  print("-- PPWV: New mute state: " .. new_state)
end

-- Debug function to scan and print all track mute states
function PakettiPPWV_DebugTrackMuteStates()
  local song = renoise.song(); if not song then return end
  print("-- PPWV: === TRACK MUTE STATE DEBUG ===")
  for i = 1, #song.tracks do
    local track = song.tracks[i]
    if track then
      local raw_state = PakettiPPWV_GetTrackMuteStateName(track)
      local detected_muted = PakettiPPWV_IsTrackMuted(track)
      
      print(string.format("-- PPWV: Track %02d (type:%d) raw_state=%s detected_muted=%s name='%s'", 
        i, track.type, raw_state, tostring(detected_muted), track.name or ""))
    end
  end
  print("-- PPWV: === END TRACK MUTE DEBUG ===")
end

-- Attach observers for all sequencer tracks to catch mute state changes
function PakettiPPWV_AttachTrackMuteObservers()
  local song = renoise.song(); if not song then return end
  
  -- Debug all track states when attaching observers
  PakettiPPWV_DebugTrackMuteStates()
  
  -- Attach track list observable (for when tracks are added/removed) - only if not already attached
  if song.tracks_observable then
    local already_attached = PakettiPPWV_tracks_observer_func and 
                           song.tracks_observable:has_notifier(PakettiPPWV_tracks_observer_func)
    if not already_attached then
      PakettiPPWV_tracks_observer_func = function() 
        print("-- PPWV: Tracks changed callback triggered")
        PakettiPPWV_OnTracksChanged() 
      end
      song.tracks_observable:add_notifier(PakettiPPWV_tracks_observer_func) 
      PakettiPPWV_tracks_observable = song.tracks_observable
      print("-- PPWV: Attached tracks_observable")
    else
      print("-- PPWV: tracks_observable already attached, skipping")
    end
  end
  
  -- Attach individual track mute state observables - only if not already attached
  local observer_count = 0
  local already_attached_count = 0
  for i = 1, #song.tracks do
    local tr = song.tracks[i]
    if tr and tr.type ~= renoise.Track.TRACK_TYPE_MASTER and tr.mute_state_observable then
      
      -- Check if we already have an observer for this track
      local existing_observer = PakettiPPWV_track_mute_observers[i]
      local already_attached = false
      
      if existing_observer and type(existing_observer) == "table" and existing_observer.observer then
        -- Check if the observer is actually attached
        already_attached = tr.mute_state_observable:has_notifier(existing_observer.observer)
      end
      
      if already_attached then
        already_attached_count = already_attached_count + 1
        print("-- PPWV: Track " .. i .. " observer already attached, skipping")
      else
        -- Create unique observer function for each track with closure
        local track_index = i  -- Capture the index in closure
        local obs = function() 
          local raw_state = PakettiPPWV_GetTrackMuteStateName(tr)
          local detected_muted = PakettiPPWV_IsTrackMuted(tr)
          print("-- PPWV: Track " .. track_index .. " mute state changed! Raw: " .. raw_state .. 
            " Detected: " .. (detected_muted and "MUTED" or "ACTIVE"))
          -- Immediate update for track mute changes (essential UX feedback)
          PakettiPPWV_UpdateCanvasThrottled()
        end
        
        -- Try to add observer
        local success = pcall(function()
          tr.mute_state_observable:add_notifier(obs)
        end)
        
        if success then
          PakettiPPWV_track_mute_observers[i] = {observer = obs, track = tr}
          observer_count = observer_count + 1
          print("-- PPWV: Successfully attached mute observer for track " .. i .. " (type: " .. tr.type .. ")")
        else
          print("-- PPWV: Failed to attach mute observer for track " .. i)
        end
      end
    else
      if tr then
        print("-- PPWV: Skipping track " .. i .. " (type: " .. tr.type .. ", has_observable: " .. tostring(tr.mute_state_observable ~= nil) .. ")")
      end
    end
  end
  print("-- PPWV: Successfully attached " .. observer_count .. " new mute observers (+ " .. already_attached_count .. " already attached) out of " .. #song.tracks .. " tracks")
end

function PakettiPPWV_DetachTrackMuteObservers()
  local song = renoise.song(); if not song then return end
  
  -- Clean up tracks observable with proper function reference - only if actually attached
  if PakettiPPWV_tracks_observable and PakettiPPWV_tracks_observer_func then
    if PakettiPPWV_tracks_observable:has_notifier(PakettiPPWV_tracks_observer_func) then
      PakettiPPWV_tracks_observable:remove_notifier(PakettiPPWV_tracks_observer_func)
      print("-- PPWV: Detached tracks_observable")
    else
      print("-- PPWV: tracks_observable not attached, skipping detach")
    end
    PakettiPPWV_tracks_observable = nil
    PakettiPPWV_tracks_observer_func = nil
  end
  
  -- Clean up individual track mute observables - only if actually attached
  if not PakettiPPWV_track_mute_observers then PakettiPPWV_track_mute_observers = {} end
  local detached_count = 0
  local not_attached_count = 0
  
  for i, obs_data in pairs(PakettiPPWV_track_mute_observers) do
    if type(obs_data) == "table" and obs_data.observer and obs_data.track then
      -- New format with table storage
      local tr = obs_data.track
      if tr and tr.mute_state_observable then
        -- Only remove if actually attached
        if tr.mute_state_observable:has_notifier(obs_data.observer) then
          pcall(function() 
            tr.mute_state_observable:remove_notifier(obs_data.observer)
            detached_count = detached_count + 1
            print("-- PPWV: Detached mute observer for track " .. i)
          end)
        else
          not_attached_count = not_attached_count + 1
          print("-- PPWV: Track " .. i .. " observer not attached, skipping detach")
        end
      end
    elseif type(obs_data) == "function" and i <= #song.tracks then
      -- Old format with function storage (backward compatibility)
      local tr = song.tracks[i]
      if tr and tr.mute_state_observable then
        if tr.mute_state_observable:has_notifier(obs_data) then
          pcall(function() 
            tr.mute_state_observable:remove_notifier(obs_data)
            detached_count = detached_count + 1
          end)
        else
          not_attached_count = not_attached_count + 1
        end
      end
    end
  end
  PakettiPPWV_track_mute_observers = {}
  print("-- PPWV: Detached " .. detached_count .. " mute observers (" .. not_attached_count .. " were not attached)")
end

-- Detach only track mute observers (not the tracks observable) - only if attached
function PakettiPPWV_DetachTrackMuteObserversOnly()
  local song = renoise.song(); if not song then return end
  
  -- Clean up individual track mute observables only - only if attached
  if not PakettiPPWV_track_mute_observers then PakettiPPWV_track_mute_observers = {} end
  local detached_count = 0
  local not_attached_count = 0
  
  for i, obs_data in pairs(PakettiPPWV_track_mute_observers) do
    if type(obs_data) == "table" and obs_data.observer and obs_data.track then
      -- New format with table storage
      local tr = obs_data.track
      if tr and tr.mute_state_observable then
        if tr.mute_state_observable:has_notifier(obs_data.observer) then
          pcall(function() 
            tr.mute_state_observable:remove_notifier(obs_data.observer)
            detached_count = detached_count + 1
            print("-- PPWV: Detached mute observer for track " .. i)
          end)
        else
          not_attached_count = not_attached_count + 1
          print("-- PPWV: Track " .. i .. " observer not attached, skipping detach")
        end
      end
    elseif type(obs_data) == "function" and i <= #song.tracks then
      -- Old format with function storage (backward compatibility)
      local tr = song.tracks[i]
      if tr and tr.mute_state_observable then
        if tr.mute_state_observable:has_notifier(obs_data) then
          pcall(function() 
            tr.mute_state_observable:remove_notifier(obs_data)
            detached_count = detached_count + 1
          end)
        else
          not_attached_count = not_attached_count + 1
        end
      end
    end
  end
  PakettiPPWV_track_mute_observers = {}
  print("-- PPWV: Detached " .. detached_count .. " track mute observers (" .. not_attached_count .. " were not attached)")
end

-- Attach only track mute observers (not the tracks observable) - only if not already attached
function PakettiPPWV_AttachTrackMuteObserversOnly()
  local song = renoise.song(); if not song then return end
  
  -- Debug all track states when attaching observers
  PakettiPPWV_DebugTrackMuteStates()
  
  -- Attach individual track mute state observables - only if not already attached
  local observer_count = 0
  local already_attached_count = 0
  for i = 1, #song.tracks do
    local tr = song.tracks[i]
    if tr and tr.type ~= renoise.Track.TRACK_TYPE_MASTER and tr.mute_state_observable then
      
      -- Check if we already have an observer for this track
      local existing_observer = PakettiPPWV_track_mute_observers[i]
      local already_attached = false
      
      if existing_observer and type(existing_observer) == "table" and existing_observer.observer then
        -- Check if the observer is actually attached
        already_attached = tr.mute_state_observable:has_notifier(existing_observer.observer)
      end
      
      if already_attached then
        already_attached_count = already_attached_count + 1
        print("-- PPWV: Track " .. i .. " observer already attached, skipping")
      else
        -- Create unique observer function for each track with closure
        local track_index = i  -- Capture the index in closure
        local obs = function() 
          local raw_state = PakettiPPWV_GetTrackMuteStateName(tr)
          local detected_muted = PakettiPPWV_IsTrackMuted(tr)
          print("-- PPWV: Track " .. track_index .. " mute state changed! Raw: " .. raw_state .. 
            " Detected: " .. (detected_muted and "MUTED" or "ACTIVE"))
          -- Immediate update for track mute changes (essential UX feedback)
          PakettiPPWV_UpdateCanvasThrottled()
        end
        
        -- Try to add observer
        local success = pcall(function()
          tr.mute_state_observable:add_notifier(obs)
        end)
        
        if success then
          PakettiPPWV_track_mute_observers[i] = {observer = obs, track = tr}
          observer_count = observer_count + 1
          print("-- PPWV: Successfully attached mute observer for track " .. i .. " (type: " .. tr.type .. ")")
        else
          print("-- PPWV: Failed to attach mute observer for track " .. i)
        end
      end
    else
      if tr then
        print("-- PPWV: Skipping track " .. i .. " (type: " .. tr.type .. ", has_observable: " .. tostring(tr.mute_state_observable ~= nil) .. ")")
      end
    end
  end
  print("-- PPWV: Successfully attached " .. observer_count .. " new track mute observers (+ " .. already_attached_count .. " already attached) out of " .. #song.tracks .. " tracks")
end

-- Observe selected track changes so selected-track mode follows the user selection
function PakettiPPWV_AttachSelectedTrackObserver()
  local song = renoise.song(); if not song then return end
  if song.selected_track_index_observable then
    -- Check if already attached to prevent duplicate notifiers
    local already_attached = PakettiPPWV_selected_track_observer and 
                           song.selected_track_index_observable:has_notifier(PakettiPPWV_selected_track_observer)
    
    if not already_attached then
      -- Detach any existing observer first (defensive cleanup)
      PakettiPPWV_DetachSelectedTrackObserver()
      
      PakettiPPWV_selected_track_observer = function()
        if PakettiPPWV_show_only_selected_track then
          PakettiPPWV_RebuildTrackCanvases()
          PakettiPPWV_UpdateCanvasThrottled()
        end
      end
      song.selected_track_index_observable:add_notifier(PakettiPPWV_selected_track_observer)
      print("-- PPWV: Attached selected_track_index_observable")
    else
      print("-- PPWV: selected_track_index_observable already attached, skipping")
    end
  end
end

function PakettiPPWV_DetachSelectedTrackObserver()
  local song = renoise.song(); if not song then return end
  if PakettiPPWV_selected_track_observer and song.selected_track_index_observable then
    pcall(function() song.selected_track_index_observable:remove_notifier(PakettiPPWV_selected_track_observer) end)
  end
  PakettiPPWV_selected_track_observer = nil
end

-- Store last known track count to detect actual changes
PakettiPPWV_last_track_count = 0

-- Callback for track list changes (add/remove tracks)
function PakettiPPWV_OnTracksChanged()
  if not PakettiPPWV_dialog or not PakettiPPWV_dialog.visible then return end
  
  local song = renoise.song()
  if not song then return end
  
  -- Check if track count actually changed to avoid unnecessary observer refresh
  local current_track_count = #song.tracks
  if current_track_count == PakettiPPWV_last_track_count then
    print("-- PPWV: Tracks callback fired but count unchanged (" .. current_track_count .. "), ignoring")
    return
  end
  
  print("-- PPWV: Track count changed from " .. PakettiPPWV_last_track_count .. " to " .. current_track_count)
  PakettiPPWV_last_track_count = current_track_count
  
  -- Only refresh observers for individual tracks, don't re-attach tracks observable
  PakettiPPWV_DetachTrackMuteObserversOnly() -- New function that skips tracks observable
  PakettiPPWV_AttachTrackMuteObserversOnly() -- New function that skips tracks observable
  
  -- Force refresh display including canvas size adjustments for new track count
  local lanes = song.sequencer_track_count
  PakettiPPWV_canvas_height = math.max(200, lanes * PakettiPPWV_lane_height)
  
  -- Rebuild track canvases and events
  PakettiPPWV_RebuildEvents()
  PakettiPPWV_RebuildTrackCanvases()
  PakettiPPWV_UpdateScrollbars()
  PakettiPPWV_UpdateCanvasThrottled()
  
  renoise.app():show_status("PPWV: Track list changed - updated display")
end

-- Check if there's a Note Off event at a specific position
function PakettiPPWV_FindNoteOffAt(patt, track_index, column_index, start_line, end_line)
  for line_index = math.floor(start_line), math.floor(end_line) do
    if line_index >= 1 and line_index <= patt.number_of_lines then
      local ptrack = patt:track(track_index)
      local line = ptrack:line(line_index)
      if line and line.note_columns and line.note_columns[column_index] then
        local nc = line.note_columns[column_index]
        if not nc.is_empty and nc.note_value == 120 then
          -- Found Note Off, calculate exact time including delay
          local note_off_time = line_index + (nc.delay_value or 0) / 256
          -- Only return if it's in the range we're checking
          if note_off_time >= start_line and note_off_time <= end_line then
            return note_off_time
          end
        end
      end
    end
  end
  return nil
end

-- Global cache for consistent sample+note length calculations
PakettiPPWV_sample_length_cache = {}

-- Calculate actual sample length in pattern lines based on sample data, note pitch, BPM, LPB
function PakettiPPWV_CalculateSampleLengthInLines(sample, ev, song, patt)
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return 4.0 -- Fallback to reasonable default
  end
  
  -- Get note value - prefer from ev if available, otherwise from pattern
  local note_value = 48 -- Default C-4
  if ev.note_value then
    note_value = ev.note_value
  elseif ev.track_index and ev.start_line and ev.column_index and patt then
    local ptrack = patt:track(ev.track_index)
    local line = ptrack:line(ev.start_line)
    if line and line.note_columns and line.note_columns[ev.column_index] then
      local nc = line.note_columns[ev.column_index]
      if not nc.is_empty and nc.note_value and nc.note_value <= 119 then
        note_value = nc.note_value
      end
    end
  end
  
  -- DEBUG: Print what we found
  if PakettiPPWV_debug then print(string.format("-- PPWV DEBUG: Track %d Line %d Col %d -> Note %d, Instr %d, Sample %d", 
    ev.track_index, ev.start_line, ev.column_index, note_value, 
    ev.instrument_index or -1, ev.sample_index or -1)) end
  
  -- Create cache key: instrument_index + sample_index + note_value + bpm + lpb
  local cache_key = string.format("%d:%d:%d:%.1f:%d", 
    ev.instrument_index or 0, ev.sample_index or 0, note_value, 
    song.transport.bpm, song.transport.lpb)
  
  -- Check if we already calculated this combination
  if PakettiPPWV_sample_length_cache[cache_key] then
    if PakettiPPWV_debug then print(string.format("-- PPWV: Using cached length %.3f for %s", PakettiPPWV_sample_length_cache[cache_key], cache_key)) end
    return PakettiPPWV_sample_length_cache[cache_key]
  end
  
  local buffer = sample.sample_buffer
  local sample_frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  
  -- Calculate pitch factor based on note and sample settings
  local base_note = 48 -- Default base note
  local ok, bn = pcall(function() return sample.sample_mapping and sample.sample_mapping.base_note end)
  if ok and type(bn) == "number" then base_note = bn end
  
  local transpose = 0
  local ok2, tp = pcall(function() return sample.transpose end)
  if ok2 and type(tp) == "number" then transpose = tp end
  
  local fine_tune = 0
  local ok3, ft = pcall(function() return sample.fine_tune end)
  if ok3 and type(ft) == "number" then fine_tune = ft end
  
  -- Calculate total semitone offset
  local semitones = (note_value - base_note) + transpose + (fine_tune / 128.0)
  
  -- Calculate pitch factor (2^(semitones/12))
  local pitch_factor = math.pow(2, semitones / 12)
  
  -- Calculate sample duration in seconds at this pitch
  local sample_duration_seconds = (sample_frames / sample_rate) / pitch_factor
  
  -- Get transport settings
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  
  -- Calculate how long each line is in seconds
  local seconds_per_line = (60 / bpm) / lpb
  
  -- Calculate how many lines the sample takes
  local sample_duration_lines = sample_duration_seconds / seconds_per_line
  
  -- Return the actual calculated length, with a reasonable minimum
  local result = math.max(0.25, sample_duration_lines)
  
  -- Cache this result for consistency
  PakettiPPWV_sample_length_cache[cache_key] = result
  if PakettiPPWV_debug then print(string.format("-- PPWV: Calculated length %.3f for %s (note=%d, frames=%d, pitch_factor=%.3f)", 
    result, cache_key, note_value, sample_frames, pitch_factor)) end
  
  return result
end


-- Render a single track into its own canvas (horizontal or vertical)
function PakettiPPWV_RenderTrackCanvas(track_index, canvas_w, canvas_h, skip_clear)
  return function(ctx)
    -- Reduced debug output to avoid console spam
    -- print("TRACK CANVAS RENDER: track=" .. track_index .. " w=" .. canvas_w .. " h=" .. canvas_h)
    local song, patt = PakettiPPWV_GetSongAndPattern()
    local W = canvas_w or PakettiPPWV_canvas_width
    local H = canvas_h or PakettiPPWV_lane_height
    
    -- CRITICAL FIX: No local window calculation needed - always render full viewport
    
    -- MICRO-OPTIMIZATION: Color constants as locals to reduce GC churn  
    local COL_BACKGROUND_1 = {25,25,35,255}
    local COL_BACKGROUND_2 = {15,15,25,255}
    local COL_GRID_BEAT = {70,70,100,220}
    local COL_GRID_LINE = {40,40,60,140}
    local COL_GRID_SPARSE = {50,50,70,255}
    local COL_GRID_MEGA = {40,40,50,200}
    local COL_WAVEFORM = {100,255,150,200}
    local COL_WAVEFORM_SEL = {255,200,120,255}
    local COL_LABEL_TEXT = {255,255,255,255}
    local COL_LABEL_BRIGHT = {255,255,120,255}
    local COL_GUTTER_1 = {18,18,24,255}
    local COL_GUTTER_2 = {14,14,20,255}
    local COL_MUTED_DIM = {200,200,200,255}
    
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local is_vertical = (PakettiPPWV_orientation == 2)
    local win = PakettiPPWV_GetWindowLines(num_lines)
    local view_start = PakettiPPWV_view_start_line
    local view_end = math.min(num_lines, view_start + win - 1)
    
    local draw_start, draw_end = view_start, view_end
    
    -- ALWAYS draw background - immediate-mode rendering requires it
    if not skip_clear then
      ctx:clear_rect(0, 0, W, H)
      -- OPTIMIZATION #7: Performance mode - use flat fill instead of gradient
      if PakettiPPWV_performance_mode then
        ctx.fill_color = COL_BACKGROUND_1
        ctx:fill_rect(0, 0, W, H)
      else
        ctx:set_fill_linear_gradient(0, 0, 0, H)
        ctx:add_fill_color_stop(0, COL_BACKGROUND_1)
        ctx:add_fill_color_stop(1, COL_BACKGROUND_2)
        ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
      end
    end
    
    -- MICRO-OPTIMIZATION #2: Memoize Line→X for the current viewport to avoid repeated function calls
    local LineToX_cache = {}
    local function LineToX(line)
      local cached = LineToX_cache[line]
      if cached then return cached end
      local result = PakettiPPWV_LineDelayToX(line, 0, num_lines)
      LineToX_cache[line] = result
      return result
    end
    
    -- DEBUG: print("TRACK VIEW: track=" .. track_index .. " start=" .. view_start .. " end=" .. view_end .. " draw=" .. draw_start .. "-" .. draw_end .. " win=" .. win .. " num_lines=" .. num_lines .. " (1-based internal)")
    local lpb = song.transport.lpb
    local eff_w = (not is_vertical) and math.max(1, W - (2*PakettiPPWV_gutter_width)) or W
    local pixels_per_line = (not is_vertical) and (eff_w / win) or (H / win)

    -- Grid (OPTIMIZED: More aggressive density switching for vertical mode)
    -- DEBUG: print("GRID: pixels_per_line=" .. pixels_per_line .. " threshold=" .. (is_vertical and "12" or "6"))
    local grid_threshold = is_vertical and 12 or 6  -- Higher threshold for vertical mode
    
    if pixels_per_line >= grid_threshold then
      -- Full detail grid
      local slope = is_vertical and (H / PakettiPPWV_GetWindowLines(num_lines)) or nil
      local base_y = is_vertical and PakettiPPWV_MapTimeToY(PakettiPPWV_view_start_line, num_lines, H) or nil
      for line = view_start, view_end do
        local pos = not is_vertical and LineToX(line) or (base_y + (line - PakettiPPWV_view_start_line) * slope)
        if ((line-1) % lpb) == 0 then ctx.stroke_color = COL_GRID_BEAT; ctx.line_width = 2 else ctx.stroke_color = COL_GRID_LINE; ctx.line_width = 1 end
        ctx:begin_path(); if not is_vertical then ctx:move_to(pos, 0); ctx:line_to(pos, H) else ctx:move_to(0, pos); ctx:line_to(W, pos) end; ctx:stroke()
      end
    elseif pixels_per_line >= (is_vertical and 4 or 3) then
      -- Beat lines only
      ctx.stroke_color = COL_GRID_SPARSE; ctx.line_width = 1
      local slope = is_vertical and (H / PakettiPPWV_GetWindowLines(num_lines)) or nil
      local base_y = is_vertical and PakettiPPWV_MapTimeToY(PakettiPPWV_view_start_line, num_lines, H) or nil
      for line = draw_start, draw_end do
        if ((line-1) % lpb) == 0 then
          local pos = not is_vertical and LineToX(line) or (base_y + (line - PakettiPPWV_view_start_line) * slope)
          ctx:begin_path(); if not is_vertical then ctx:move_to(pos, 0); ctx:line_to(pos, H) else ctx:move_to(0, pos); ctx:line_to(W, pos) end; ctx:stroke()
        end
      end
    elseif is_vertical and pixels_per_line >= 2 then
      -- OPTIMIZED: Super sparse grid - every 4th beat when severely zoomed out
      ctx.stroke_color = COL_GRID_MEGA; ctx.line_width = 1
      local slope = H / PakettiPPWV_GetWindowLines(num_lines)
      local base_y = PakettiPPWV_MapTimeToY(PakettiPPWV_view_start_line, num_lines, H)
      local mega_beat = lpb * 4  -- Every 4 beats
      for line = draw_start, draw_end do
        if ((line-1) % mega_beat) == 0 then
          local pos = base_y + (line - PakettiPPWV_view_start_line) * slope
          ctx:begin_path(); ctx:move_to(0, pos); ctx:line_to(W, pos); ctx:stroke()
        end
      end
    end
    
    -- Always draw the end boundary line after the last row
    local final_line = view_end + 1
    if final_line <= num_lines + 1 then  -- Allow boundary at num_lines + 1 to close the last row
      local final_x = not is_vertical and LineToX(final_line) or PakettiPPWV_MapTimeToY(final_line, num_lines, H)
      ctx.stroke_color = {50,50,70,255}  -- Same pale grey as normal grid lines
      ctx.line_width = 1
      ctx:begin_path()
      if not is_vertical then 
        ctx:move_to(final_x, 0)
        ctx:line_to(final_x, H)
      else 
        ctx:move_to(0, final_x)
        ctx:line_to(W, final_x)
      end
      ctx:stroke()
    end

    -- Get track and mute state (needed for waveform rendering)
    local tr = song.tracks[track_index]
    local is_muted = PakettiPPWV_IsTrackMuted(tr)
    
    -- Label + mute state overlay
    -- Gutters (visual margins) on both sides to align with header (no numbering here)
    local gutter = PakettiPPWV_gutter_width
    ctx.fill_color = {18,18,24,255}; ctx:fill_rect(0, 0, gutter, H)
    ctx.fill_color = {14,14,20,255}; ctx:fill_rect(W - gutter, 0, gutter, H)
    -- Track label drawn to align with timeline step 00 (line 1)
    local label_text = tr and tr.name or ("Track " .. string.format("%02d", track_index))
    local mute_text = "(MUTED - CLICK TO UNMUTE)"
    if is_muted then
      ctx.stroke_color = {200,200,200,255} -- Dimmed text for muted tracks
      if not is_vertical then
        label_text = label_text .. " " .. mute_text  -- Horizontal: single line
      end
    else
      ctx.stroke_color = {255,255,255,255}
    end
    -- In vertical mode, use small consistent offset; in horizontal mode, align with timeline
    local label_x = is_vertical and 8 or (LineToX(1) + 2)
    PakettiPPWV_DrawTextShared(ctx, label_text, label_x, 4, 8)
    -- In vertical mode, draw mute text on second line
    if is_muted and is_vertical then
      PakettiPPWV_DrawTextShared(ctx, mute_text, label_x, 16, 7)  -- Second line, smaller font
    end
    if is_muted then
      ctx.fill_color = {28,28,28,210}; ctx:fill_rect(gutter, 0, W - (2*gutter), H)
      ctx.stroke_color = {220,220,220,240}
      PakettiCanvasFontDrawText(ctx, "MUTED", math.floor(W/2 - 40), math.floor(H/2 - 6), 12)
    end

    -- Waveforms - with event culling during drag for better performance
    for i = 1, #PakettiPPWV_events do
      local ev = PakettiPPWV_events[i]
      if ev.track_index == track_index then
        
        -- Standard waveform rendering - draw all events for this track  
        local should_draw_event = true
        
        -- CRITICAL FIX: ALWAYS draw ALL events - NO culling whatsoever (except during dirty pass)
        -- User wants all waveforms to stay visible during drag operations
        if should_draw_event then
        local cache
        if ev.sample_index and ev.instrument_index and song.instruments[ev.instrument_index] then
          local instr = song.instruments[ev.instrument_index]
          if instr.samples[ev.sample_index] and instr.samples[ev.sample_index].sample_buffer and instr.samples[ev.sample_index].sample_buffer.has_sample_data then
            cache = PakettiPPWV_GetCachedWaveform(ev.instrument_index, ev.sample_index)
          end
        end
        if cache and not is_muted then
          if ev.id == PakettiPPWV_selected_event_id or (PakettiPPWV_selected_ids and PakettiPPWV_selected_ids[ev.id]) then
            ctx.stroke_color = {255,200,120,255}; ctx.line_width = 2
          else
            ctx.stroke_color = {100,255,150,200}; ctx.line_width = 1
          end
          ctx:begin_path()
          local lane_mid = not is_vertical and (H/2) or (W/2)
          
          -- OPTIMIZATION: Use pre-computed sample length instead of recalculating
          local actual_sample_length_lines = ev.natural_length_lines or 4.0
          
          -- Find next waveform on same track/column to determine clipping point (OPTIMIZED: O(1) lookup)
          -- OPTIMIZATION: Use pre-computed actual start time
          local current_actual_start_time = ev.actual_start_time or (ev.start_line + (ev.start_delay or 0) / 256)
          local natural_end_time = current_actual_start_time + actual_sample_length_lines
          local clip_at_line = ev.next_start_time or natural_end_time
          
          -- Also check for Note Off events that could cut off this sample (OPTIMIZED: fast path)
          -- Only scan for Note-Off if the range is reasonable (< 8 lines) to avoid expensive scans
          local note_off_time = nil
          if (clip_at_line - current_actual_start_time) <= 8 then
            note_off_time = PakettiPPWV_FindNoteOffAt(patt, ev.track_index, ev.column_index, current_actual_start_time, clip_at_line)
          end
          if note_off_time and note_off_time < clip_at_line then
            clip_at_line = note_off_time
          end
          
          -- Limit to pattern end
          clip_at_line = math.min(clip_at_line, num_lines + 1)
          
          if not is_vertical then
            local x1 = PakettiPPWV_LineDelayToX(ev.start_line, ev.start_delay or 0, num_lines)
            local x2 = PakettiPPWV_LineDelayToX(clip_at_line, 0, num_lines)
            if x2 < x1 + 1 then x2 = x1 + 1 end
            local clip_width = x2 - x1
            local points = #cache
            
            -- OPTIMIZED: Cache reference calculations to avoid repeated math per redraw
            local cache_key = string.format("h_%.3f_%d_%d", actual_sample_length_lines, W, PakettiPPWV_GetWindowLines(num_lines))
            local pixels_per_sample = PakettiPPWV_reference_scale_cache[cache_key]
            if not pixels_per_sample then
              local reference_start = 1.0  -- Use line 1 as reference point
              local reference_width = PakettiPPWV_LineDelayToX(reference_start + actual_sample_length_lines, 0, num_lines) - PakettiPPWV_LineDelayToX(reference_start, 0, num_lines)
              pixels_per_sample = reference_width / points
              PakettiPPWV_reference_scale_cache[cache_key] = pixels_per_sample
            end
            
            -- DEBUG: Print rendering details
            if PakettiPPWV_debug then print(string.format("-- PPWV RENDER: Track %d Line %d -> Length=%.3f, PPS=%.3f, Points=%d", 
              ev.track_index, ev.start_line, actual_sample_length_lines, pixels_per_sample, points)) end
            
            -- CRITICAL FIX: Draw waveform ONLY for actual sample length, not collision clip length
            local actual_sample_width = PakettiPPWV_LineDelayToX(current_actual_start_time + actual_sample_length_lines, 0, num_lines) - x1
            local sample_draw_width = math.min(clip_width, actual_sample_width)  -- Don't exceed actual sample
            for px = 0, math.floor(sample_draw_width) do
              local sample_idx = math.floor(px / pixels_per_sample) + 1
              if sample_idx < 1 then sample_idx = 1 end
              if sample_idx > points then sample_idx = points end
              local sample_v = cache[sample_idx]
              local x = x1 + px
              local y = lane_mid - (sample_v * (H * 0.45))
              if px == 0 then ctx:move_to(x,y) else ctx:line_to(x,y) end
            end
          else
            local y1 = PakettiPPWV_MapTimeToY(ev.start_line, num_lines, H)
            local y2 = PakettiPPWV_MapTimeToY(clip_at_line, num_lines, H)
            if y2 < y1 + 1 then y2 = y1 + 1 end
            local clip_height = y2 - y1
            local points = #cache
            
            -- OPTIMIZED: Cache reference calculations to avoid repeated math per redraw
            local cache_key = string.format("v_%.3f_%d_%d", actual_sample_length_lines, H, PakettiPPWV_GetWindowLines(num_lines))
            local pixels_per_sample = PakettiPPWV_reference_scale_cache[cache_key]
            if not pixels_per_sample then
              local win = PakettiPPWV_GetWindowLines(num_lines)
              local slope = H / win  -- pixels per line  
              local reference_height = actual_sample_length_lines * slope
              pixels_per_sample = reference_height / points
              PakettiPPWV_reference_scale_cache[cache_key] = pixels_per_sample
            end
            
            -- Draw waveform at fixed scale, but only up to clip point (OPTIMIZED: adaptive step)
            -- CRITICAL FIX: Draw waveform ONLY for actual sample length, not collision clip length
            local win = PakettiPPWV_GetWindowLines(num_lines)
            local actual_sample_height_pixels = actual_sample_length_lines * (H / win)
            local sample_draw_height = math.min(clip_height, actual_sample_height_pixels)  -- Don't exceed actual sample
            local step = math.max(1, math.floor(pixels_per_sample * 0.75))
            for py = 0, math.floor(sample_draw_height), step do
              local sample_idx = math.floor(py / pixels_per_sample) + 1
              if sample_idx < 1 then sample_idx = 1 end
              if sample_idx > points then sample_idx = points end
              local sample_v = cache[sample_idx]
              local y = y1 + py
              local x = lane_mid - (sample_v * (W * 0.45))
              if py == 0 then ctx:move_to(x,y) else ctx:line_to(x,y) end
            end
          end
          ctx:stroke()
          
          -- Optional labels above the start of the waveform (only for selected events)
          local is_selected = (ev.id == PakettiPPWV_selected_event_id or (PakettiPPWV_selected_ids and PakettiPPWV_selected_ids[ev.id]))
          if is_selected and (PakettiPPWV_show_labels or PakettiPPWV_show_sample_names or PakettiPPWV_show_note_names) then
            local instrument_name = ""
            local sample_name = ""
            local note_txt = ""
            
            -- Get instrument name if requested
            if PakettiPPWV_show_labels then
              local instr = song.instruments[ev.instrument_index]
              if instr and instr.name and instr.name ~= "" then instrument_name = instr.name end
            end
            
            -- Get sample name if requested
            if PakettiPPWV_show_sample_names then
              local instr = song.instruments[ev.instrument_index]
              local sample = instr and instr.samples and instr.samples[ev.sample_index]
              if sample and sample.name and sample.name ~= "" then sample_name = sample.name end
            end
            
            -- Get note name if requested - OPTIMIZATION: Use pre-computed note name
            if PakettiPPWV_show_note_names then
              note_txt = ev.note_name or ""
            end
            
            -- Build label from components
            local label = ""
            if instrument_name ~= "" then
              label = instrument_name
            end
            if sample_name ~= "" then
              if label ~= "" then label = label .. "  " .. sample_name else label = sample_name end
            end
            if note_txt ~= "" then
              if label ~= "" then label = label .. "  " .. note_txt else label = note_txt end
            end
            
            -- Only draw label if we have something to show
            if label ~= "" then
              ctx.stroke_color = COL_LABEL_BRIGHT  -- Brighter yellow color
              ctx.line_width = 1
              if not is_vertical then
                local x1 = PakettiPPWV_LineDelayToX(ev.start_line, ev.start_delay or 0, num_lines)
                PakettiPPWV_DrawText(ctx, label, x1 + 2, 2, 9)  -- Larger font size
              else
                local y1 = PakettiPPWV_MapTimeToY(ev.start_line, num_lines, H)
                PakettiPPWV_DrawText(ctx, label, 2, y1 + 2, 9)  -- Larger font size
              end
            end
          end
        end
        -- End of event rendering block
        end -- end if should_draw_event
      end
    end

    -- No playhead on track canvases - playhead is only in header (horizontal) or timeline sidebar (vertical)
  end
end


-- Vertical timeline sidebar renderer: draws timeline row numbers and playhead (left sidebar in vertical mode)
function PakettiPPWV_RenderVerticalTimeline(canvas_w, canvas_h)
  return function(ctx)
    local song, patt = PakettiPPWV_GetSongAndPattern()
    local W = canvas_w or 50
    local H = canvas_h or PakettiPPWV_canvas_height
    ctx:clear_rect(0, 0, W, H)
    -- OPTIMIZATION #7: Performance mode - use flat fill instead of gradient
    if PakettiPPWV_performance_mode then
      ctx.fill_color = {22,22,30,255}
      ctx:fill_rect(0, 0, W, H)
    else
      ctx:set_fill_linear_gradient(0, 0, W, 0)
      ctx:add_fill_color_stop(0, {22,22,30,255})
      ctx:add_fill_color_stop(1, {12,12,20,255})
      ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
    end
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local win = PakettiPPWV_GetWindowLines(num_lines)
    local view_start = PakettiPPWV_view_start_line
    local view_end = math.min(num_lines, view_start + win - 1)
    local lpb = song.transport.lpb
    
    -- Row labels and ticks (vertical layout) - OPTIMIZED: use slope calculation
    local slope = H / PakettiPPWV_GetWindowLines(num_lines)
    local base_y = PakettiPPWV_MapTimeToY(PakettiPPWV_view_start_line, num_lines, H)
    for line = view_start, view_end do
      local y = base_y + (line - PakettiPPWV_view_start_line) * slope
      local is_beat_start = ((line-1) % lpb) == 0
      local should_show_label = is_beat_start
      
      if should_show_label then
        ctx.stroke_color = {120,120,150,255}
        ctx.line_width = is_beat_start and 2 or 1
      else
        ctx.stroke_color = {90,90,120,255}
        ctx.line_width = 1
      end
      
      -- Vertical tick line
      ctx:begin_path(); ctx:move_to(W-8, y); ctx:line_to(W, y); ctx:stroke()
      
      if should_show_label then
        local label = string.format("%03d", (line - 1))  -- Convert 1-based internal to 0-based visual display
        ctx.stroke_color = {255,255,255,255}
        PakettiCanvasFontDrawText(ctx, label, 2, y + 10, 8)  -- Position below the grid line
      end
    end
    
    -- Playhead (vertical line moving up/down in timeline sidebar)
    if PakettiPPWV_show_vertical_playhead then
      local play_pos = nil
      local play_line = nil
      if song.transport.playing then
        local pos = song.transport.playback_pos
        if pos and pos.sequence and pos.line and pos.sequence == renoise.song().selected_sequence_index then
          play_line = pos.line
        end
      else
        play_line = song.selected_line_index
      end
      if play_line then
        play_pos = PakettiPPWV_MapTimeToY(play_line, num_lines, H)
      end
      if play_pos then
        ctx.stroke_color = {255,200,120,255}
        ctx.line_width = 2
        ctx:begin_path()
        -- Horizontal line across timeline sidebar width showing current position
        ctx:move_to(0, play_pos); ctx:line_to(W, play_pos)
        ctx:stroke()
      end
    end
  end
end

-- Header canvas renderer: draws timeline row numbers and playhead (top bar above first track)
function PakettiPPWV_RenderHeaderCanvas(canvas_w, canvas_h)
  local function on_mouse(ev)
    if not ev or ev.type ~= "down" then return end
    local song, patt = PakettiPPWV_GetSongAndPattern(); if not song or not patt then return end
    local x = ev.position.x
    local num_lines = patt.number_of_lines
    local win = PakettiPPWV_GetWindowLines(num_lines)
    local divisor = (win > 1) and win or 1
    local target_line = math.floor(((x / (canvas_w or PakettiPPWV_canvas_width)) * divisor) + (PakettiPPWV_view_start_line - 1)) + 1
    if target_line < 1 then target_line = 1 end
    if target_line > num_lines then target_line = num_lines end
    song.selected_line_index = target_line
    song.transport:start_at{sequence = renoise.song().selected_sequence_index, line = target_line}
  end
  return function(ctx)
    local song, patt = PakettiPPWV_GetSongAndPattern()
    local W = canvas_w or PakettiPPWV_canvas_width
    local H = canvas_h or (PakettiPPWV_gutter_height + 4)
    ctx:clear_rect(0, 0, W, H)
    -- Background - OPTIMIZATION #7: Performance mode toggle
    if PakettiPPWV_performance_mode then
      ctx.fill_color = {22,22,30,255}
      ctx:fill_rect(0, 0, W, H)
    else
      ctx:set_fill_linear_gradient(0, 0, 0, H)
      ctx:add_fill_color_stop(0, {22,22,30,255})
      ctx:add_fill_color_stop(1, {12,12,20,255})
      ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
    end
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local win = PakettiPPWV_GetWindowLines(num_lines)
    local view_start = PakettiPPWV_view_start_line
    local view_end = math.min(num_lines, view_start + win - 1)
    local lpb = song.transport.lpb
    local gutter = PakettiPPWV_gutter_width
    -- Gutters at both sides
    ctx.fill_color = {18,18,24,255}; ctx:fill_rect(0, 0, gutter, H)
    ctx.fill_color = {14,14,20,255}; ctx:fill_rect(W - gutter, 0, gutter, H)
    -- Grid ticks and row labels along the header timeline
    local row_label_size = 7
    local eff_w = math.max(1, W - (2*PakettiPPWV_gutter_width))
    local pixels_per_line = eff_w / win
    -- Use smaller step size when zoomed in enough to show individual lines
    local step = (pixels_per_line >= 12) and 1 or ((lpb >= 2) and lpb or 1)
    -- DEBUG: print("HEADER: drawing from " .. view_start .. " to " .. view_end .. " step=" .. step)
    for line = view_start, view_end, step do
      local x = PakettiPPWV_LineDelayToX(line, 0, num_lines)
      -- tick
      ctx.stroke_color = {90,90,120,255}
      ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
      
      -- Smart row labeling: every 4th line when > 32 lines, otherwise every line
      local should_show_label = true
      if num_lines > 32 then
        -- Only show labels on "Grey Lines" (every 4th line: 1, 5, 9, 13, etc.)
        should_show_label = ((line - 1) % 4 == 0)
      end
      
      if should_show_label then
        -- label above the tick - show full range without artificial 100-limit
        local label = string.format("%03d", (line - 1))  -- Convert 1-based internal to 0-based visual display
        -- Set bright white color for better visibility
        ctx.stroke_color = {255,255,255,255}
        PakettiCanvasFontDrawText(ctx, label, x + 2, 2, row_label_size)
        -- Restore original color for tick marks
        ctx.stroke_color = {90,90,120,255}
      end
    end
    -- Playhead (only in horizontal mode - vertical mode uses timeline sidebar playhead)
    local is_vertical = (PakettiPPWV_orientation == 2)
    if not is_vertical and PakettiPPWV_show_horizontal_playhead then
      local play_pos = nil
      local play_line = nil
      if song.transport.playing then
        local pos = song.transport.playback_pos
        if pos and pos.sequence and pos.line and pos.sequence == renoise.song().selected_sequence_index then
          play_line = pos.line
        end
      else
        play_line = song.selected_line_index
      end
      if play_line then
        play_pos = PakettiPPWV_LineDelayToX(play_line, 0, num_lines)
      end
      if play_pos then
        ctx.stroke_color = {255,200,120,255}
        ctx.line_width = 2
        ctx:begin_path()
        -- Vertical playhead line in horizontal mode
        ctx:move_to(play_pos, 0); ctx:line_to(play_pos, H)
        ctx:stroke()
      end
    end
  end
end

-- Mouse handling for track canvases (horizontal only for drag now)
function PakettiPPWV_TrackMouse(track_index, ev)
  local song, patt = PakettiPPWV_GetSongAndPattern(); if not song or not patt then return end
  local num_lines = patt.number_of_lines
  local is_vertical = (PakettiPPWV_orientation == 2)
  local x = ev.position.x; local y = ev.position.y
  if ev.type == "down" then
    PakettiPPWV_DebugPrintModifierFlags("track-mouse-down")
    
    local track = song.tracks[track_index]
    local is_track_muted = PakettiPPWV_IsTrackMuted(track)
    
    -- Check if click is specifically on TRACK TITLE (top area AND left side where title text is)
    local is_in_title_area = (y <= 14) and (x <= 200)  -- Title text area is roughly first 200 pixels
    
    if PakettiPPWV_debug then print(string.format("-- PPWV: Track %d click at x=%.1f y=%.1f (title_area=%s, track_muted=%s)", 
      track_index, x, y, tostring(is_in_title_area), tostring(is_track_muted))) end
    
    if is_in_title_area then
      -- Click on track title - always toggle mute
      print("-- PPWV: Click on track title! Toggling mute for track " .. track_index)
      PakettiPPWV_ToggleTrackMute(track_index)
      PakettiPPWV_UpdateCanvasThrottled()
      return
    elseif is_track_muted then
      -- Click anywhere on a muted track - unmute it
      print("-- PPWV: Click on muted track " .. track_index .. " - unmuting!")
      PakettiPPWV_ToggleTrackMute(track_index)
      PakettiPPWV_UpdateCanvasThrottled()
      return
    else
      print("-- PPWV: Click on active track outside title area, proceeding with normal handling")
    end
    
    -- Hit test: check actual visual waveform boundaries (same as rendering logic)
    local picked = nil
    for i = 1, #PakettiPPWV_events do
      local evn = PakettiPPWV_events[i]
      if evn.track_index == track_index then
        -- Calculate same visual boundaries as rendering
        local sample = song.instruments[evn.instrument_index].samples[evn.sample_index]
        local actual_sample_length_lines = PakettiPPWV_CalculateSampleLengthInLines(sample, evn, song, patt)
        
        -- Same collision detection as rendering
        local current_actual_start_time = evn.start_line + (evn.start_delay or 0) / 256
        local natural_end_time = current_actual_start_time + actual_sample_length_lines
        local clip_at_line = natural_end_time
        local earliest_collision_time = natural_end_time
        for j = 1, #PakettiPPWV_events do
          local next_ev = PakettiPPWV_events[j]
          if next_ev.track_index == evn.track_index and next_ev.column_index == evn.column_index and next_ev.id ~= evn.id then
            local next_start_time = next_ev.start_line + (next_ev.start_delay or 0) / 256
            if next_start_time > current_actual_start_time and next_start_time < earliest_collision_time then
              earliest_collision_time = next_start_time
            end
          end
        end
        clip_at_line = earliest_collision_time
        
        -- Check for Note Off events
        local note_off_time = PakettiPPWV_FindNoteOffAt(patt, evn.track_index, evn.column_index, current_actual_start_time, clip_at_line)
        if note_off_time and note_off_time < clip_at_line then
          clip_at_line = note_off_time
        end
        
        -- Limit to pattern end
        clip_at_line = math.min(clip_at_line, num_lines + 1)
        
        -- Calculate actual visual boundaries
        if not is_vertical then
          -- Horizontal mode
          local x1 = PakettiPPWV_LineDelayToX(evn.start_line, evn.start_delay or 0, num_lines)
          local x2 = PakettiPPWV_LineDelayToX(clip_at_line, 0, num_lines)
          
          -- Account for gutters in per-track canvas
          x1 = x1 + PakettiPPWV_gutter_width
          x2 = x2 + PakettiPPWV_gutter_width
          
          -- Check if mouse is within the actual rendered waveform area (extended 3px to the left for easier selection)
          local hotspot_x1 = x1 - 3
          if x >= hotspot_x1 and x <= x2 then
            if PakettiPPWV_debug then print(string.format("-- PPWV TRACK HIT: Found event %s at mouse %.1f (waveform bounds %.1f to %.1f, hotspot starts at %.1f)", 
              evn.id, x, x1, x2, hotspot_x1)) end
            picked = evn
            break
          end
        else
          -- Vertical mode - get actual canvas height
          local canvas_h = PakettiPPWV_GetCurrentCanvasHeight()
          local y1 = PakettiPPWV_MapTimeToY(evn.start_line, num_lines, canvas_h)
          local y2 = PakettiPPWV_MapTimeToY(clip_at_line, num_lines, canvas_h)
          
          -- Check if mouse is within a small hotspot around the sample start (prevents overlapping hotspots)
          local hotspot_y1 = y1 - 5
          local hotspot_y2 = y1 + 10  -- Small 15px tall hotspot around sample start
          if y >= hotspot_y1 and y <= hotspot_y2 then
            if PakettiPPWV_debug then print(string.format("-- PPWV VERTICAL HIT: Found event %s at mouse %.1f (hotspot bounds %.1f to %.1f)", 
              evn.id, y, hotspot_y1, hotspot_y2)) end
            picked = evn
            break
          end
        end
      end
    end
    if picked then
      -- Check for double-click using existing infrastructure
      local current_time_ms = os.clock() * 1000
      local dx = x - PakettiPPWV_last_click_x
      local dy = y - PakettiPPWV_last_click_y
      local dist2 = dx*dx + dy*dy
      local is_double_click = (current_time_ms - PakettiPPWV_last_click_time_ms) < PakettiPPWV_double_click_threshold_ms and 
                            dist2 < 100 and 
                            PakettiPPWV_last_click_event and 
                            PakettiPPWV_last_click_event.id == picked.id
      
      if is_double_click then
        print("-- PPWV: Track canvas double-click detected on event " .. picked.id .. " (time_diff=" .. 
              string.format("%.1f", current_time_ms - PakettiPPWV_last_click_time_ms) .. "ms)")
      end
      
      if is_double_click then
        -- Double-click: Select sample and open sample editor
        song.selected_track_index = picked.track_index
        song.selected_line_index = picked.start_line
        if picked.instrument_index then
          song.selected_instrument_index = picked.instrument_index
          if picked.sample_index then
            local instr = song.instruments[picked.instrument_index]
            if instr and instr.samples[picked.sample_index] then
              song.selected_sample_index = picked.sample_index
              print("-- PPWV: Double-click sample selection - Instrument:" .. picked.instrument_index .. " Sample:" .. picked.sample_index)
              renoise.app():show_status("PPWV: Selected Sample " .. string.format("%02d", picked.sample_index) .. " in Instrument " .. string.format("%02d", picked.instrument_index))
              
              -- Switch to sample editor tab
              if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
                renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
                print("-- PPWV: Switched to Sample Editor")
              end
            end
          end
        end
        -- Don't start dragging on double-click - clear click tracking
        PakettiPPWV_last_click_event = nil
        PakettiPPWV_last_click_time_ms = 0
      else
        -- Single click: Normal selection and prepare for potential drag
        PakettiPPWV_selected_event_id = picked.id
        PakettiPPWV_HandleClickSelection(picked)
        PakettiPPWV_is_dup_dragging = PakettiPPWV_alt_is_down
        PakettiPPWV_is_dragging = true; PakettiPPWV_drag_start = {x=x,y=y,id=picked.id}
        
        -- CRITICAL: Pattern editor changes FIRST (immediate)
        song.selected_track_index = picked.track_index
        song.selected_line_index = picked.start_line  
        song.selected_instrument_index = picked.instrument_index or song.selected_instrument_index
        print(string.format("-- PPWV TRACK SELECT id=%s dup_drag=%s shift=%s alt=%s", tostring(picked.id), tostring(PakettiPPWV_is_dup_dragging), tostring(PakettiPPWV_shift_is_down), tostring(PakettiPPWV_alt_is_down)))
        
        -- Store this click for potential double-click detection
        PakettiPPWV_last_click_time_ms = current_time_ms
        PakettiPPWV_last_click_x = x
        PakettiPPWV_last_click_y = y
        PakettiPPWV_last_click_event = picked
      end
      
      -- Single delayed canvas update (removed double-update)
      renoise.tool():add_timer(function() PakettiPPWV_UpdateCanvasImmediate() end, 50)
    end
  elseif ev.type == "move" then
    if PakettiPPWV_is_dragging and PakettiPPWV_drag_start and PakettiPPWV_selected_event_id then
      local delta_px = (not is_vertical) and (x - PakettiPPWV_drag_start.x) or (y - PakettiPPWV_drag_start.y)
      local eff_w = (not is_vertical) and math.max(1, PakettiPPWV_canvas_width - (2*PakettiPPWV_gutter_width)) or PakettiPPWV_GetCurrentCanvasHeight()
      local ticks_per_pixel = (num_lines * 256) / eff_w
      local delta_ticks = math.floor(delta_px * ticks_per_pixel)
      if math.abs(delta_ticks) >= 1 then
        local moved = false
        if PakettiPPWV_multi_select_mode and PakettiPPWV_selected_ids and PakettiPPWV_SelectedCount() > 0 then
          for i = 1, #PakettiPPWV_events do
            local e = PakettiPPWV_events[i]
            if e.track_index == track_index and PakettiPPWV_selected_ids[e.id] then
              local ok = PakettiPPWV_is_dup_dragging and PakettiPPWV_DuplicateEventByTicks(e, delta_ticks) or PakettiPPWV_MoveEventByTicks(e, delta_ticks)
              if ok then moved = true end
            end
          end
        else
          for i = 1, #PakettiPPWV_events do
            local e = PakettiPPWV_events[i]
            if e.id == PakettiPPWV_selected_event_id then
              local ok = PakettiPPWV_is_dup_dragging and PakettiPPWV_DuplicateEventByTicks(e, delta_ticks) or PakettiPPWV_MoveEventByTicks(e, delta_ticks)
              if ok then moved = true end
              break
            end
          end
        end
        if moved then 
          PakettiPPWV_drag_start.x = x; PakettiPPWV_drag_start.y = y; PakettiPPWV_RebuildEvents()
          -- Immediate update for track mute changes (essential UX feedback)
          PakettiPPWV_UpdateCanvasThrottled()
        end
      end
    end
  elseif ev.type == "up" then
    PakettiPPWV_is_dragging = false; PakettiPPWV_drag_start = nil
  end
end

-- Build or rebuild per-track canvases
function PakettiPPWV_RebuildTrackCanvases()
  if not PakettiPPWV_tracks_container then return end
  -- Hide old children
  if PakettiPPWV_tracks_container.views then
    while #PakettiPPWV_tracks_container.views > 0 do
      PakettiPPWV_tracks_container:remove_child(PakettiPPWV_tracks_container.views[1])
    end
  end
  PakettiPPWV_track_canvases = {}
  local song = renoise.song(); if not song then return end
  local lanes = song.sequencer_track_count
  local is_vertical = (PakettiPPWV_orientation == 2)
  local scale = PakettiPPWV_GetVerticalScale()
  if not is_vertical then
    local tracks_to_draw = PakettiPPWV_show_only_selected_track and 1 or lanes
    for i = 1, tracks_to_draw do
      local t = PakettiPPWV_show_only_selected_track and song.selected_track_index or i
      local cw = PakettiPPWV_canvas_width
      local ch = PakettiPPWV_GetCurrentCanvasHeight()
      
      -- Standard single canvas per track
      local c = PakettiPPWV_vb:canvas{ 
        width = cw, height = ch, mode = "plain", 
        render = PakettiPPWV_RenderTrackCanvas(t, cw, ch),
        mouse_handler = function(ev) PakettiPPWV_TrackMouse(t, ev) end, 
        mouse_events = {"down","up","move"} 
      }
      
      PakettiPPWV_tracks_container:add_child(c)
      PakettiPPWV_track_canvases[#PakettiPPWV_track_canvases+1] = c
    end
    -- Hide the legacy monolithic canvas
    if PakettiPPWV_canvas then PakettiPPWV_canvas.visible = false end
  else
    -- Vertical: use consistent fixed track width to prevent progressive widening
    local row = PakettiPPWV_vb:row{ spacing = 0 }
    local tracks_to_draw = PakettiPPWV_show_only_selected_track and 1 or lanes
    -- Use simple fixed width per track for consistent alignment
    local each_w = PakettiPPWV_GetVerticalTrackWidth()  -- DRY: Use centralized width
    
    -- OPTIMIZATION #8: Batch multiple tracks per canvas to reduce canvas count
    if PakettiPPWV_batch_tracks and not PakettiPPWV_show_only_selected_track and tracks_to_draw > 4 then
      local tracks_per_batch = 4
      local num_batches = math.ceil(tracks_to_draw / tracks_per_batch)
      for batch = 1, num_batches do
        local start_track = (batch - 1) * tracks_per_batch + 1
        local end_track = math.min(batch * tracks_per_batch, tracks_to_draw)
        local batch_width = (end_track - start_track + 1) * each_w
        local ch = PakettiPPWV_GetCurrentCanvasHeight()
        local c = PakettiPPWV_vb:canvas{ 
          width = batch_width, 
          height = ch, 
          mode = "plain", 
          render = PakettiPPWV_RenderBatchedTracks(start_track, end_track, each_w, ch),
          mouse_handler = function(ev) PakettiPPWV_BatchedTrackMouse(start_track, end_track, each_w, ev) end,
          mouse_events = {"down","up","move"} 
        }
        row:add_child(c)
        PakettiPPWV_track_canvases[#PakettiPPWV_track_canvases+1] = c
      end
    else
      -- Original single-track-per-canvas approach
      for i = 1, tracks_to_draw do
        local t = PakettiPPWV_show_only_selected_track and song.selected_track_index or i
        local cw = each_w
        local ch = PakettiPPWV_GetCurrentCanvasHeight()
        local c = PakettiPPWV_vb:canvas{ width = cw, height = ch, mode = "plain", render = PakettiPPWV_RenderTrackCanvas(t, cw, ch), mouse_handler = function(ev) PakettiPPWV_TrackMouse(t, ev) end, mouse_events = {"down","up","move"} }
        row:add_child(c)
        PakettiPPWV_track_canvases[#PakettiPPWV_track_canvases+1] = c
      end
    end
    PakettiPPWV_tracks_container:add_child(row)
    if PakettiPPWV_canvas then PakettiPPWV_canvas.visible = false end
  end
  PakettiPPWV_UpdateScrollbars()
end

-- OPTIMIZATION #8: Render multiple tracks in one canvas with Y offsets
function PakettiPPWV_RenderBatchedTracks(start_track, end_track, track_width, canvas_h)
  return function(ctx)
    local W = (end_track - start_track + 1) * track_width
    local H = canvas_h
    
    -- Always clear the batch canvas - individual tracks handle their own intelligent clearing
    ctx:clear_rect(0, 0, W, H)
    
    for track_offset = 0, end_track - start_track do
      local track_index = start_track + track_offset
      local x_offset = track_offset * track_width
      
      -- Save and translate context for this track
      ctx:save()
      ctx:translate(x_offset, 0)
      
      -- Render individual track with clipped width - skip clearing since we handle it at batch level
      local track_renderer = PakettiPPWV_RenderTrackCanvas(track_index, track_width, H, true)
      track_renderer(ctx)
      
      ctx:restore()
    end
  end
end

-- OPTIMIZATION #8: Mouse handler for batched tracks
function PakettiPPWV_BatchedTrackMouse(start_track, end_track, track_width, ev)
  local x = ev.position.x
  local track_offset = math.floor(x / track_width)
  local track_index = start_track + track_offset
  if track_index >= start_track and track_index <= end_track then
    -- Adjust mouse position to track-relative coordinates
    local adjusted_ev = table.copy(ev)
    adjusted_ev.position = {x = x % track_width, y = ev.position.y}
    PakettiPPWV_TrackMouse(track_index, adjusted_ev)
  end
end

-- Get current vertical scale factor
function PakettiPPWV_GetVerticalScale()
  return (PakettiPPWV_vertical_scale_index == 2) and 2 or ((PakettiPPWV_vertical_scale_index == 3) and 3 or 1)
end

-- DRY PRINCIPLE: Centralized size calculations
function PakettiPPWV_GetSelectedTrackHeight()
  local scale = PakettiPPWV_GetVerticalScale()
  return math.floor((PakettiPPWV_base_canvas_height * scale) / 2)  -- Half height for performance
end

function PakettiPPWV_GetLaneHeight()
  local scale = PakettiPPWV_GetVerticalScale()
  if PakettiPPWV_show_only_selected_track then
    return PakettiPPWV_GetSelectedTrackHeight()
  else
    return PakettiPPWV_lane_height * scale
  end
end

-- DRY: Centralized track width for vertical mode
function PakettiPPWV_GetVerticalTrackWidth()
  return 96  -- OPTIMIZED: Reduced width for better performance (was 120px)
end

-- Get current canvas height with scaling applied
function PakettiPPWV_GetCurrentCanvasHeight()
  local scale = PakettiPPWV_GetVerticalScale()
  local is_vertical = (PakettiPPWV_orientation == 2)
  
  if PakettiPPWV_show_only_selected_track then
    return PakettiPPWV_GetSelectedTrackHeight()
  else
    if is_vertical then
      -- Vertical mode: use much larger base height (like 400px minimum)
      local vertical_base_height = math.max(400, PakettiPPWV_base_canvas_height)
      return vertical_base_height * scale
    else
      -- Horizontal mode: use small lane height for stacked tracks
      return PakettiPPWV_GetLaneHeight()
    end
  end
end

-- Adjust canvas size for orientation and vertical scaling
function PakettiPPWV_ApplyCanvasSizePolicy()
  local scale = PakettiPPWV_GetVerticalScale()
  if PakettiPPWV_orientation == 2 then
    -- Vertical: per-track canvases will be rebuilt to new height
    PakettiPPWV_RebuildTrackCanvases()
  else
    -- Horizontal: lane heights stay fixed, but we still rebuild to reflect any mode toggles
    PakettiPPWV_RebuildTrackCanvases()
  end
end

-- Manual refresh: clear waveform cache and redraw
function PakettiPlayerProWaveformViewerRefresh()
  PakettiPPWV_cached_waveforms = {}
  PakettiPPWV_reference_scale_cache = {}  -- Clear reference cache with waveforms
  PakettiPPWV_sample_length_cache = {} -- Clear sample length cache too
  print("-- PPWV: FORCED CACHE CLEAR - Regenerating all waveforms with DC correction")
  PakettiPPWV_RebuildEvents()
  PakettiPPWV_UpdateScrollbars()
  PakettiPPWV_UpdateCanvasThrottled()
  renoise.app():show_status("PPWV: Refreshed (waveform and length caches cleared)")
end

-- Invalidate cache for specific instrument:sample (useful when samples are modified)
function PakettiPPWV_InvalidateSampleCache(instrument_index, sample_index)
  local key = tostring(instrument_index) .. ":" .. tostring(sample_index)
  if PakettiPPWV_cached_waveforms[key] then
    PakettiPPWV_cached_waveforms[key] = nil
    if PakettiPPWV_debug then print(string.format("-- PPWV: Invalidated waveform cache for %s", key)) end
  end
  -- Also clear related sample length cache entries
  for cache_key in pairs(PakettiPPWV_sample_length_cache) do
    if cache_key:find("^" .. instrument_index .. ":" .. sample_index .. ":") then
      PakettiPPWV_sample_length_cache[cache_key] = nil
      if PakettiPPWV_debug then print(string.format("-- PPWV: Invalidated length cache for %s", cache_key)) end
    end
  end
  PakettiPPWV_UpdateCanvasThrottled()
end

-- Utility: safe get current song and selected pattern
function PakettiPPWV_GetSongAndPattern()
  local song = renoise.song()
  if not song then return nil, nil end
  local patt_idx = song.selected_pattern_index
  if patt_idx < 1 or patt_idx > #song.patterns then return song, nil end
  local patt = song:pattern(patt_idx)
  return song, patt
end

-- Utility: build a short content hash for the currently selected pattern
function PakettiPPWV_BuildPatternHash()
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return "" end
  local sequencer_track_count = song.sequencer_track_count
  local num_lines = patt.number_of_lines
  local acc = {tostring(patt.number_of_lines), tostring(#song.tracks), tostring(sequencer_track_count)}
  
  -- Include track count and mute states for change detection
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if track then
      local mute_state = "active"
      if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
        if track.mute_state == renoise.Track.MUTE_STATE_MUTED then
          mute_state = "muted"
        elseif track.mute_state == renoise.Track.MUTE_STATE_OFF then
          mute_state = "off"
        end
      end
      acc[#acc+1] = "t" .. tostring(track_index) .. ":" .. mute_state .. ":" .. (track.name or "")
    end
  end
  
  -- Include pattern content hash
  for track_index = 1, sequencer_track_count do
    local ptrack = patt:track(track_index)
    local sum = 0
    for line_index = 1, num_lines do
      local line = ptrack:line(line_index)
      if not line.is_empty then
        for col = 1, #line.note_columns do
          local nc = line.note_columns[col]
          if not nc.is_empty then
            sum = sum + (nc.note_value or 0) * 3 + (nc.instrument_value or 0) * 7 + (nc.delay_value or 0)
          end
        end
      end
    end
    acc[#acc+1] = tostring(sum)
  end
  return table.concat(acc, ":")
end

-- Utility: obtain a sample index within instrument for a given note value
function PakettiPPWV_FindSampleIndexForNote(instrument, note_value)
  if not instrument then return nil end
  if #instrument.samples == 0 then return nil end
  -- Try keyzone containment first
  for sidx = 1, #instrument.samples do
    local smap = instrument.samples[sidx].sample_mapping
    if note_value >= smap.note_range[1] and note_value <= smap.note_range[2] then
      return sidx
    end
  end
  -- No mapping found for this note
  return nil
end

-- Cache downsampled waveform for an instrument/sample pair
-- OPTIMIZATION #5: Adaptive waveform resolution based on zoom level
function PakettiPPWV_TargetPointsForZoom(is_vertical)
  local win = PakettiPPWV_GetWindowLines(renoise.song() and renoise.song().selected_pattern.number_of_lines or 64)
  if is_vertical then
    if win >= 256 then return 128 end      -- Far zoom-out: low resolution
    if win >= 128 then return 192 end      -- Medium zoom: medium resolution
    return 256                             -- Close zoom: full resolution
  else
    return 256  -- Horizontal always uses full resolution
  end
end

function PakettiPPWV_GetCachedWaveform(instrument_index, sample_index)
  local song = renoise.song()
  if not song then return nil end
  
  -- OPTIMIZATION: Dynamic resolution based on current zoom level
  local is_vertical = (PakettiPPWV_orientation == 2)
  local target_points = PakettiPPWV_TargetPointsForZoom(is_vertical)
  local key = tostring(instrument_index) .. ":" .. tostring(sample_index) .. "@" .. tostring(target_points)
  
  if PakettiPPWV_cached_waveforms[key] then
    if PakettiPPWV_debug then print(string.format("-- PPWV WAVEFORM: Using cached waveform for %s", key)) end
    return PakettiPPWV_cached_waveforms[key]
  end
  if PakettiPPWV_debug then print(string.format("-- PPWV WAVEFORM: Creating new waveform cache for %s (points=%d)", key, target_points)) end
  local instr = song.instruments[instrument_index]
  if not instr or not instr.samples[sample_index] then return nil end
  local sample = instr.samples[sample_index]
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then return nil end
  local buffer = sample.sample_buffer
  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  local cache = {}
  
  -- FIRST PASS: Calculate raw sample values
  for i = 1, target_points do
    local frame_pos = math.floor((i - 1) / (target_points - 1) * (num_frames - 1)) + 1
    frame_pos = math.max(1, math.min(num_frames, frame_pos))
    local v = 0
    for c = 1, num_channels do
      v = v + buffer:sample_data(c, frame_pos)
    end
    v = v / num_channels
    if v < -1 then v = -1 end
    if v > 1 then v = 1 end
    cache[i] = v
  end
  
  -- SECOND PASS: DC CORRECTION - Remove average offset to center silence at zero
  local dc_offset = 0
  for i = 1, target_points do
    dc_offset = dc_offset + cache[i]
  end
  dc_offset = dc_offset / target_points
  
  -- Apply DC correction to center waveform
  for i = 1, target_points do
    cache[i] = cache[i] - dc_offset
    -- Re-clamp after DC correction
    if cache[i] < -1 then cache[i] = -1 end
    if cache[i] > 1 then cache[i] = 1 end
  end
  
  -- DEBUG: Show DC correction amount
  if PakettiPPWV_debug and math.abs(dc_offset) > 0.001 then
    print(string.format("-- PPWV DC CORRECTION: %s offset=%.4f", key, dc_offset))
  end
  
  PakettiPPWV_cached_waveforms[key] = cache
  return cache
end

-- Build event list for selected pattern
function PakettiPPWV_RebuildEvents()
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return end
  local sequencer_track_count = song.sequencer_track_count
  local num_lines = patt.number_of_lines
  local new_events = {}

  for track_index = 1, sequencer_track_count do
    local ptrack = patt:track(track_index)
    local open_by_column = {}
    for col = 1, song.tracks[track_index].visible_note_columns do
      open_by_column[col] = nil
    end
    for line_index = 1, num_lines do
      local line = ptrack:line(line_index)
      if not line.is_empty then
        for col = 1, #line.note_columns do
          local nc = line.note_columns[col]
          if not nc.is_empty then
            if nc.note_value == 120 then
              -- Note off: close any running event on this column
              if open_by_column[col] then
                open_by_column[col].end_line = line_index
                new_events[#new_events+1] = open_by_column[col]
                open_by_column[col] = nil
              end
            elseif nc.note_value <= 119 then
              -- New note: close running one first
              if open_by_column[col] then
                open_by_column[col].end_line = line_index
                new_events[#new_events+1] = open_by_column[col]
              end
              local instrument_index = (nc.instrument_value ~= 255) and (nc.instrument_value + 1) or song.selected_instrument_index
              if instrument_index < 1 or instrument_index > #song.instruments then instrument_index = song.selected_instrument_index end
              local instr = song.instruments[instrument_index]
              local sample_index = PakettiPPWV_FindSampleIndexForNote(instr, nc.note_value)
              local event_id = string.format("%02d:%03d:%02d", track_index, line_index, col)
              
              -- MICRO-OPTIMIZATION #3: Freeze event facts to avoid pattern access during render
              local note_value = nc.note_value or 48
              local actual_start_time = line_index + (nc.delay_value or 0) / 256
              local note_name = nil
              if note_value and note_value <= 119 then
                local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
                local oct = math.floor(note_value/12)
                note_name = names[(note_value%12)+1] .. tostring(oct)
              end
              
              -- Pre-calculate sample length to avoid computation during rendering
              local natural_length_lines = 4.0  -- Default fallback
              if instr.samples[sample_index] then
                local sample = instr.samples[sample_index]
                if sample.sample_buffer and sample.sample_buffer.has_sample_data then
                  natural_length_lines = PakettiPPWV_CalculateSampleLengthInLines(sample, {note_value=note_value, track_index=track_index, start_line=line_index, column_index=col}, song, patt) or 4.0
                end
              end
              
              open_by_column[col] = {
                id = event_id,
                track_index = track_index,
                column_index = col,
                start_line = line_index,  -- Keep 1-based for API compatibility
                end_line = num_lines + 1, -- provisional until closed
                instrument_index = instrument_index,
                sample_index = sample_index,
                start_delay = nc.delay_value or 0,
                -- OPTIMIZATION: Frozen facts to avoid pattern access during render
                note_value = note_value,
                actual_start_time = actual_start_time,
                note_name = note_name,
                natural_length_lines = natural_length_lines
              }
            end
          end
        end
      end
    end
    -- Close any still-open events at pattern end
    for col, ev in pairs(open_by_column) do
      if ev then
        ev.end_line = num_lines + 1
        new_events[#new_events+1] = ev
      end
    end
  end

  -- OPTIMIZATION: Precompute next_start_time for each event to avoid O(N²) lookups during rendering
  for i = 1, #new_events do
    local ev = new_events[i]
    local current_actual_start_time = ev.start_line + (ev.start_delay or 0) / 256
    ev.next_start_time = nil -- Default to no next event
    local earliest_next_time = math.huge
    
    for j = 1, #new_events do
      local next_ev = new_events[j]
      if next_ev.track_index == ev.track_index and next_ev.column_index == ev.column_index and next_ev.id ~= ev.id then
        local next_start_time = next_ev.start_line + (next_ev.start_delay or 0) / 256
        if next_start_time > current_actual_start_time and next_start_time < earliest_next_time then
          earliest_next_time = next_start_time
        end
      end
    end
    
    if earliest_next_time < math.huge then
      ev.next_start_time = earliest_next_time
    end
  end

  PakettiPPWV_events = new_events
end

-- Convert line+delay to pixel X
function PakettiPPWV_LineDelayToX(line_index, delay_value, num_lines)
  local t = (line_index - 1) + (delay_value or 0) / 256
  return PakettiPPWV_MapTimeToX(t, num_lines)
end

-- ADD: Reverse coordinate conversion functions (Lua 5.1 compatible)
function PakettiPPWV_XToLine(x, num_lines)
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local eff_w = math.max(1, PakettiPPWV_canvas_width - (2*PakettiPPWV_gutter_width))
  local t = (x / eff_w) * win + PakettiPPWV_view_start_line
  return math.max(1, math.min(num_lines, math.floor(t + 0.5)))
end

function PakettiPPWV_YToLine(y, num_lines, canvas_height)
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local t = (y / canvas_height) * win + PakettiPPWV_view_start_line
  return math.max(1, math.min(num_lines, math.floor(t + 0.5)))
end

-- MAJOR OPTIMIZATION: Returns local window [win_s, win_e] (1-based, inclusive) for the selected event on this track
function PakettiPPWV_LocalWindowForSelected(track_index, num_lines)
  if not PakettiPPWV_selected_event_id then return nil end
  local sel = nil
  for i = 1, #PakettiPPWV_events do
    local e = PakettiPPWV_events[i]
    if e.id == PakettiPPWV_selected_event_id then sel = e; break end
  end
  if not sel or sel.track_index ~= track_index then return nil end

  -- Find prev/next on same track+column
  local prev_start, next_start = 1, num_lines+1
  for i = 1, #PakettiPPWV_events do
    local e = PakettiPPWV_events[i]
    if e.track_index == sel.track_index and e.column_index == sel.column_index then
      local s = e.start_line + (e.start_delay or 0)/256
      local sel_s = sel.start_line + (sel.start_delay or 0)/256
      if s < sel_s and s > prev_start then prev_start = e.start_line end
      if s > sel_s and s < next_start then next_start = e.start_line end
    end
  end

  -- Clamp to pattern; add small padding to avoid visual clipping
  local pad = 2
  local win_s = math.max(1, prev_start - pad)
  local win_e = math.min(num_lines, (next_start == (num_lines+1) and num_lines or next_start) + pad)
  if win_e < win_s then return nil end
  return win_s, win_e
end

-- Find event under mouse position - matches actual visual waveform rendering
function PakettiPPWV_FindEventAt(x, y)
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return nil end
  local num_lines = patt.number_of_lines
  local lane_height = PakettiPPWV_GetLaneHeight()  -- DRY: Use centralized calculation
  local track_lane = math.floor(y / lane_height) + 1
  if track_lane < 1 or track_lane > song.sequencer_track_count then return nil end
  
  -- Check each event's actual visual boundaries (same as rendering logic)
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.track_index == track_lane then
      -- Calculate same visual boundaries as rendering
      local sample = song.instruments[ev.instrument_index].samples[ev.sample_index]
      local actual_sample_length_lines = PakettiPPWV_CalculateSampleLengthInLines(sample, ev, song, patt)
      
      -- Same collision detection as rendering
      local current_actual_start_time = ev.start_line + (ev.start_delay or 0) / 256
      local natural_end_time = current_actual_start_time + actual_sample_length_lines
      local clip_at_line = natural_end_time
      local earliest_collision_time = natural_end_time
      for j = 1, #PakettiPPWV_events do
        local next_ev = PakettiPPWV_events[j]
        if next_ev.track_index == ev.track_index and next_ev.column_index == ev.column_index and next_ev.id ~= ev.id then
          local next_start_time = next_ev.start_line + (next_ev.start_delay or 0) / 256
          if next_start_time > current_actual_start_time and next_start_time < earliest_collision_time then
            earliest_collision_time = next_start_time
          end
        end
      end
      clip_at_line = earliest_collision_time
      
      -- Check for Note Off events
      local note_off_time = PakettiPPWV_FindNoteOffAt(patt, ev.track_index, ev.column_index, current_actual_start_time, clip_at_line)
      if note_off_time and note_off_time < clip_at_line then
        clip_at_line = note_off_time
      end
      
      -- Limit to pattern end
      clip_at_line = math.min(clip_at_line, num_lines + 1)
      
      -- Calculate actual visual boundaries
      local x1 = PakettiPPWV_LineDelayToX(ev.start_line, ev.start_delay or 0, num_lines)
      local x2 = PakettiPPWV_LineDelayToX(clip_at_line, 0, num_lines)
      
      -- Check if mouse x is within the actual rendered waveform area (extended 3px to the left for easier selection)
      local hotspot_x1 = x1 - 3
      if x >= hotspot_x1 and x <= x2 then
        print(string.format("-- PPWV HIT: Found event %s at mouse %.1f (waveform bounds %.1f to %.1f, hotspot starts at %.1f)", 
          ev.id, x, x1, x2, hotspot_x1))
        return ev
      end
    end
  end
  print(string.format("-- PPWV HIT: No event found at mouse %.1f, %.1f", x, y))
  return nil
end

-- Move a note event by delta ticks (positive right, negative left). 256 ticks = 1 line.
function PakettiPPWV_MoveEventByTicks(ev, delta_ticks)
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return false end
  local num_lines = patt.number_of_lines
  local ptrack = patt:track(ev.track_index)
  local src_line = ev.start_line
  local src_col = ev.column_index
  local src_nc = ptrack:line(src_line).note_columns[src_col]
  if not src_nc or src_nc.is_empty or src_nc.note_value > 119 then
    renoise.app():show_status("Paketti PPWV: Source note not found or not a note")
    return false
  end
  local start_ticks = (src_line - 1) * 256 + (src_nc.delay_value or 0)
  local new_ticks = start_ticks + delta_ticks
  if new_ticks < 0 then new_ticks = 0 end
  local max_ticks = (num_lines - 1) * 256 + 255
  if new_ticks > max_ticks then new_ticks = max_ticks end
  local dst_line = math.floor(new_ticks / 256) + 1
  local dst_delay = new_ticks % 256
  -- Destination
  local dst_nc = ptrack:line(dst_line).note_columns[src_col]
  if not dst_nc then
    renoise.app():show_status("Paketti PPWV: Destination column missing")
    return false
  end
  if not dst_nc.is_empty then
    -- If destination occupied by the very same note (same id), allow; else reject
    if not (dst_line == src_line) then
      renoise.app():show_status("Paketti PPWV: Destination occupied")
      return false
    end
  end
  -- Copy note data
  local note_value = src_nc.note_value
  local instrument_value = src_nc.instrument_value
  local volume_value = src_nc.volume_value
  local panning_value = src_nc.panning_value
  local effect_number_value = src_nc.effect_number_value
  local effect_amount_value = src_nc.effect_amount_value
  -- Clear source
  src_nc:clear()
  -- Write destination
  dst_nc.note_value = note_value
  dst_nc.instrument_value = instrument_value
  dst_nc.volume_value = volume_value
  dst_nc.panning_value = panning_value
  dst_nc.effect_number_value = effect_number_value
  dst_nc.effect_amount_value = effect_amount_value
  dst_nc.delay_value = dst_delay
  -- Ensure delay column is visible after nudging
  renoise.song().tracks[ev.track_index].delay_column_visible = true
  -- Update selection id and keep selection mapping
  local old_id = ev.id
  ev.start_line = dst_line  -- Keep 1-based for API compatibility
  ev.start_delay = dst_delay
  ev.id = string.format("%02d:%03d:%02d", ev.track_index, dst_line, ev.column_index)
  if PakettiPPWV_selected_event_id == old_id then
    PakettiPPWV_selected_event_id = ev.id
  end
  if PakettiPPWV_selected_ids and PakettiPPWV_selected_ids[old_id] then
    PakettiPPWV_selected_ids[old_id] = nil
    PakettiPPWV_selected_ids[ev.id] = true
  end
  if PakettiPPWV_debug then print(string.format("-- Paketti PPWV: Moved event to line %d, delay %d", dst_line, dst_delay)) end
  -- Move pattern cursor to new location for continued nudging
  local song3 = renoise.song()
  song3.selected_track_index = ev.track_index
  song3.selected_line_index = dst_line
  renoise.app():show_status(string.format("PPWV: Track %02d Line %03d Delay %03d", ev.track_index, dst_line, dst_delay))
  return true
end

-- Duplicate a note event by delta ticks without clearing the source. 256 ticks = 1 line.
function PakettiPPWV_DuplicateEventByTicks(ev, delta_ticks)
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return false end
  local num_lines = patt.number_of_lines
  local ptrack = patt:track(ev.track_index)
  local src_line = ev.start_line
  local src_col = ev.column_index
  local src_nc = ptrack:line(src_line).note_columns[src_col]
  if not src_nc or src_nc.is_empty or src_nc.note_value > 119 then
    renoise.app():show_status("Paketti PPWV: Source note not found or not a note")
    return false
  end
  local start_ticks = (src_line - 1) * 256 + (src_nc.delay_value or 0)
  local new_ticks = start_ticks + delta_ticks
  if new_ticks < 0 then new_ticks = 0 end
  local max_ticks = (num_lines - 1) * 256 + 255
  if new_ticks > max_ticks then new_ticks = max_ticks end
  local dst_line = math.floor(new_ticks / 256) + 1
  local dst_delay = new_ticks % 256
  -- Try same column first
  local dst_col = src_col
  local dst_nc = ptrack:line(dst_line).note_columns[dst_col]
  if not dst_nc or not dst_nc.is_empty then
    -- Find next free column on this track
    local max_cols = song.tracks[ev.track_index].visible_note_columns
    for c = 1, max_cols do
      if ptrack:line(dst_line).note_columns[c] and ptrack:line(dst_line).note_columns[c].is_empty then
        dst_col = c
        dst_nc = ptrack:line(dst_line).note_columns[dst_col]
        break
      end
    end
  end
  if not dst_nc or not dst_nc.is_empty then
    renoise.app():show_status("Paketti PPWV: No free destination column")
    return false
  end
  -- Copy note data from source to destination
  dst_nc.note_value = src_nc.note_value
  dst_nc.instrument_value = src_nc.instrument_value
  dst_nc.volume_value = src_nc.volume_value
  dst_nc.panning_value = src_nc.panning_value
  dst_nc.effect_number_value = src_nc.effect_number_value
  dst_nc.effect_amount_value = src_nc.effect_amount_value
  dst_nc.delay_value = dst_delay
  -- Ensure delay column visible
  local song2 = renoise.song()
  if song2 and song2.tracks[ev.track_index] and song2.tracks[ev.track_index].delay_column_visible ~= nil then
    song2.tracks[ev.track_index].delay_column_visible = true
  end
  -- Update selection to the new duplicate
  local new_id = string.format("%02d:%03d:%02d", ev.track_index, dst_line, dst_col)
  PakettiPPWV_selected_event_id = new_id
  if not PakettiPPWV_selected_ids then PakettiPPWV_selected_ids = {} end
  PakettiPPWV_selected_ids[new_id] = true
  -- Cursor to new location
  local song3 = renoise.song()
  song3.selected_track_index = ev.track_index
  song3.selected_line_index = dst_line
  renoise.app():show_status(string.format("PPWV: Duplicated -> Track %02d Line %03d Delay %03d", ev.track_index, dst_line, dst_delay))
  return true
end

-- Select next/previous event helper
function PakettiPPWV_SelectAdjacentEvent(direction)
  if #PakettiPPWV_events == 0 then return end
  local idx = 1
  for i = 1, #PakettiPPWV_events do
    if PakettiPPWV_events[i].id == PakettiPPWV_selected_event_id then
      idx = i
      break
    end
  end
  idx = idx + direction
  if idx < 1 then idx = 1 end
  if idx > #PakettiPPWV_events then idx = #PakettiPPWV_events end
  PakettiPPWV_selected_event_id = PakettiPPWV_events[idx].id
  if PakettiPPWV_canvas then PakettiPPWV_canvas:update() end
end

-- Keyboard-driven nudges - REVERTED TO WORKING VERSION WITH OPTIMIZED DEBOUNCING
function PakettiPPWV_NudgeSelectedTicks(delta_ticks)
  if not PakettiPPWV_selected_event_id then return end
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      if PakettiPPWV_MoveEventByTicks(ev, delta_ticks) then
        PakettiPPWV_ScheduleDeferredUpdate()
      end
      break
    end
  end
end

-- Nudge multiple selected events on the same track - ATOMIC BATCH OPERATION
function PakettiPPWV_NudgeMultipleOnSameTrack(delta_ticks)
  if not PakettiPPWV_selected_event_id then return end
  if PakettiPPWV_SelectedCount() == 0 then return end
  
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return end
  
  -- Determine track from anchor event
  local anchor_track = nil
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      anchor_track = ev.track_index
      break
    end
  end
  if not anchor_track then return end
  
  -- ATOMIC BATCH OPERATION: Collect all operations first, then execute in one go
  local batch_operations = {}
  local num_lines = patt.number_of_lines
  local ptrack = patt:track(anchor_track)
  
  -- Phase 1: Plan all moves (don't touch pattern yet)
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.track_index == anchor_track and PakettiPPWV_selected_ids[ev.id] then
      local src_line = ev.start_line
      local src_col = ev.column_index
      local src_nc = ptrack:line(src_line).note_columns[src_col]
      
      if src_nc and not src_nc.is_empty and src_nc.note_value <= 119 then
        -- Calculate new position
        local start_ticks = (src_line - 1) * 256 + (src_nc.delay_value or 0)
        local new_ticks = math.max(0, math.min((num_lines - 1) * 256 + 255, start_ticks + delta_ticks))
        local dst_line = math.floor(new_ticks / 256) + 1
        local dst_delay = new_ticks % 256
        
        -- Check if destination is free (or same as source)
        local dst_nc = ptrack:line(dst_line).note_columns[src_col]
        if dst_nc and (dst_nc.is_empty or dst_line == src_line) then
          -- Queue this operation
          table.insert(batch_operations, {
            src_line = src_line,
            src_col = src_col, 
            dst_line = dst_line,
            dst_delay = dst_delay,
            note_data = {
              note_value = src_nc.note_value,
              instrument_value = src_nc.instrument_value,
              volume_value = src_nc.volume_value,
              panning_value = src_nc.panning_value,
              effect_number_value = src_nc.effect_number_value,
              effect_amount_value = src_nc.effect_amount_value
            },
            event = ev
          })
        end
      end
    end
  end
  
  if #batch_operations == 0 then return end
  
  -- Phase 2: Execute all moves atomically (no intermediate UI updates)
  print(string.format("-- PPWV: Executing atomic batch nudge of %d samples, delta=%d", #batch_operations, delta_ticks))
  
  -- Clear all source notes first
  for _, op in ipairs(batch_operations) do
    ptrack:line(op.src_line).note_columns[op.src_col]:clear()
  end
  
  -- Write all destination notes
  for _, op in ipairs(batch_operations) do
    local dst_nc = ptrack:line(op.dst_line).note_columns[op.src_col]
    dst_nc.note_value = op.note_data.note_value
    dst_nc.instrument_value = op.note_data.instrument_value
    dst_nc.volume_value = op.note_data.volume_value
    dst_nc.panning_value = op.note_data.panning_value
    dst_nc.effect_number_value = op.note_data.effect_number_value
    dst_nc.effect_amount_value = op.note_data.effect_amount_value
    dst_nc.delay_value = op.dst_delay
    
    -- Update event object
    op.event.start_line = op.dst_line
    op.event.start_delay = op.dst_delay
    op.event.id = string.format("%02d:%03d:%02d", op.event.track_index, op.dst_line, op.event.column_index)
  end
  
  -- Ensure delay column is visible after batch nudging
  renoise.song().tracks[anchor_track].delay_column_visible = true
  
  -- Keep selection after atomic move - update selection IDs to match new positions
  local new_selected = {}
  for _, op in ipairs(batch_operations) do
    new_selected[op.event.id] = true
  end
  PakettiPPWV_selected_ids = new_selected
  
  -- Single deferred update for smooth performance
  PakettiPPWV_ScheduleDeferredUpdate()
end

function PakettiPPWV_SnapSelectedToNearestRow()
  if not PakettiPPWV_selected_event_id then return end
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return end
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      local ptrack = patt:track(ev.track_index)
      local src_nc = ptrack:line(ev.start_line).note_columns[ev.column_index]
      if not src_nc or src_nc.is_empty then return end
      local delay = src_nc.delay_value or 0
      local delta = 0
      if delay >= 128 then
        delta = 256 - delay
      else
        delta = -delay
      end
      if PakettiPPWV_MoveEventByTicks(ev, delta) then
        PakettiPPWV_RebuildEvents()
        PakettiPPWV_UpdateCanvasThrottled()
      end
      break
    end
  end
end

-- Key handler for dialog: arrow keys control selection/nudging, fallback to my_keyhandler_func
function PakettiPPWV_KeyHandler(dialog, key)
  local name = tostring(key.name)
  local mods = tostring(key.modifiers)
  
  -- CRITICAL FIX: Only handle specific navigation keys to prevent double note triggering
  -- Let note entry keys (letters, numbers, etc.) pass through directly without any processing
  local waveform_viewer_keys = {
    left = true, right = true, up = true, down = true,
    back = true, delete = true
  }
  
  -- If this isn't a key we specifically handle, pass it directly to normal handler
  if not waveform_viewer_keys[name] then
    return my_keyhandler_func(dialog, key)
  end
  
  -- Debug only for keys we actually handle
  PakettiPPWV_UpdateModifierFlags(mods)
  print(string.format("-- PPWV KEY name=%s mods=%s", name, mods))
  PakettiPPWV_DebugPrintModifierFlags("key")
  PakettiPPWV_shift_is_down = (mods == "shift")
  if mods == "" then
    if name == "left" then
      -- If "Select the same" is enabled, automatically populate matching selections
      if PakettiPPWV_select_same_enabled then
        PakettiPPWV_SelectAllMatchingSamples()
      end
      
      local selected_count = PakettiPPWV_SelectedCount()
      local events_count = #PakettiPPWV_events
      
      if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and events_count > 0 and selected_count > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(-1)
      else
        PakettiPPWV_NudgeSelectedTicks(-1)
      end
      return nil
    elseif name == "right" then
      -- If "Select the same" is enabled, automatically populate matching selections
      if PakettiPPWV_select_same_enabled then
        PakettiPPWV_SelectAllMatchingSamples()
      end
      
      local selected_count = PakettiPPWV_SelectedCount()
      local events_count = #PakettiPPWV_events
      
      if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and events_count > 0 and selected_count > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(1)
      else
        PakettiPPWV_NudgeSelectedTicks(1)
      end
      return nil
    elseif name == "up" and PakettiPPWV_orientation == 2 then
      -- Vertical nudge: up/down
      -- If "Select the same" is enabled, automatically populate matching selections
      if PakettiPPWV_select_same_enabled then
        PakettiPPWV_SelectAllMatchingSamples()
      end
      
      if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and #PakettiPPWV_events > 0 and PakettiPPWV_SelectedCount() > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(-1)
      else
        PakettiPPWV_NudgeSelectedTicks(-1)
      end
      return nil
    elseif name == "down" and PakettiPPWV_orientation == 2 then
      -- If "Select the same" is enabled, automatically populate matching selections
      if PakettiPPWV_select_same_enabled then
        PakettiPPWV_SelectAllMatchingSamples()
      end
      
      if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and #PakettiPPWV_events > 0 and PakettiPPWV_SelectedCount() > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(1)
      else
        PakettiPPWV_NudgeSelectedTicks(1)
      end
      return nil
    elseif name == "up" then
      PakettiPPWV_SelectAdjacentEvent(-1)
      return nil
    elseif name == "down" then
      PakettiPPWV_SelectAdjacentEvent(1)
      return nil
    elseif name == "back" or name == "delete" then
      PakettiPPWV_DeleteSelectedEvents()
      return nil
    end
  elseif mods == "shift" then
    -- keep flag true during shift handling for mouse selection
    PakettiPPWV_shift_is_down = true
    if name == "left" then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(-256)
      else
        PakettiPPWV_NudgeSelectedTicks(-256)
      end
      return nil
    elseif name == "right" then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(256)
      else
        PakettiPPWV_NudgeSelectedTicks(256)
      end
      return nil
    elseif name == "up" and PakettiPPWV_orientation == 2 then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(-256)
      else
        PakettiPPWV_NudgeSelectedTicks(-256)
      end
      return nil
    elseif name == "down" and PakettiPPWV_orientation == 2 then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(256)
      else
        PakettiPPWV_NudgeSelectedTicks(256)
      end
      return nil
    end
  end
  -- reset the flag for non-shift events so accidental sticky doesn't happen
  if mods ~= "shift" then PakettiPPWV_shift_is_down = false end
  PakettiPPWV_alt_is_down = (mods == "alt" or mods == "option")
  -- Fallback to global keyhandler for closing, etc.
  return my_keyhandler_func(dialog, key)
end

-- Render canvas
function PakettiPPWV_RenderCanvas(ctx)
  print("RENDER CANVAS CALLED")
  local song, patt = PakettiPPWV_GetSongAndPattern()
  print("Song and pattern loaded")
  ctx:clear_rect(0, 0, PakettiPPWV_canvas_width, PakettiPPWV_canvas_height)
  -- Background
  ctx:set_fill_linear_gradient(0, 0, 0, PakettiPPWV_canvas_height)
  ctx:add_fill_color_stop(0, {25,25,35,255})
  ctx:add_fill_color_stop(1, {15,15,25,255})
  ctx:begin_path(); ctx:rect(0,0,PakettiPPWV_canvas_width,PakettiPPWV_canvas_height); ctx:fill()

  if not song or not patt then return end

  local num_lines = patt.number_of_lines
  local lanes = song.sequencer_track_count
  local selected_track = song.selected_track_index
  local lanes_to_draw = lanes
  if PakettiPPWV_show_only_selected_track then lanes_to_draw = 1 end
  local lane_height = PakettiPPWV_GetLaneHeight()  -- DRY: Use centralized calculation
  local total_height = lanes_to_draw * lane_height

  -- Orientation switch: Vertical mode transposes axes
  local is_vertical = (PakettiPPWV_orientation == 2)
  local W = PakettiPPWV_canvas_width
  local H = PakettiPPWV_canvas_height

  local function draw_line(x1,y1,x2,y2)
    if not is_vertical then
      ctx:begin_path(); ctx:move_to(x1,y1); ctx:line_to(x2,y2); ctx:stroke()
    else
      -- Swap axes for vertical: x<->y and flip
      ctx:begin_path(); ctx:move_to(y1, x1); ctx:line_to(y2, x2); ctx:stroke()
    end
  end
  local function draw_rect(x,y,w,h)
    if not is_vertical then
      ctx:begin_path(); ctx:rect(x,y,w,h); ctx:fill()
    else
      ctx:begin_path(); ctx:rect(y, x, h, w); ctx:fill()
    end
  end

  -- Grid by LPB and per-row when zoomed in + horizontal gutters with row numbers
  local lpb = song.transport.lpb
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local view_start = PakettiPPWV_view_start_line
  local view_end = math.min(num_lines, view_start + win - 1)
  print("VIEW CALCULATION:")
  print("view_start = " .. view_start)
  print("view_end = " .. view_end) 
  print("win = " .. win)
  print("num_lines = " .. num_lines)
  local eff_w = math.max(1, W - (2*PakettiPPWV_gutter_width))
  local pixels_per_line = eff_w / win
  local gutter = PakettiPPWV_gutter_width
  print("PIXELS:")
  print("eff_w = " .. eff_w)
  print("pixels_per_line = " .. pixels_per_line)
  print("gutter = " .. gutter)
  -- draw gutters left/right
  ctx:set_fill_linear_gradient(0, 0, 0, H)
  ctx:add_fill_color_stop(0, {18,18,24,255})
  ctx:add_fill_color_stop(1, {14,14,20,255})
  ctx:begin_path(); ctx:rect(0, 0, gutter, H); ctx:fill()
  ctx:begin_path(); ctx:rect(W - gutter, 0, gutter, H); ctx:fill()
  print("GRID CHECK:")
  print("pixels_per_line = " .. pixels_per_line)
  print("threshold = 6")
  if pixels_per_line >= 6 then
    print("USING DETAILED GRID MODE")
    print("Drawing lines from " .. view_start .. " to " .. view_end)
    for line = view_start, view_end do
      local x = PakettiPPWV_LineDelayToX(line, 0, num_lines)
      if ((line - 1) % lpb) == 0 then
        ctx.stroke_color = {70,70,100,220}
        ctx.line_width = 2
      else
        ctx.stroke_color = {40,40,60,140}
        ctx.line_width = 1
      end
      draw_line(x, 0, x, H)
    end
    print("BOUNDARY LINE:")
    local final_line = view_end + 1
    local final_x = PakettiPPWV_LineDelayToX(final_line, 0, num_lines)
    print("final_line = " .. final_line)
    print("final_x = " .. final_x)
    print("W-gutter = " .. (W - gutter))
    -- Only draw if the boundary line would be within canvas bounds
    if final_x <= W - gutter then
      print("Drawing boundary line")
      ctx.stroke_color = {40,40,60,140}
      ctx.line_width = 1
      draw_line(final_x, 0, final_x, H)
    else
      print("Boundary line out of bounds - skipping")
    end
  else
    print("USING SIMPLIFIED LPB-ONLY GRID MODE")
    -- Only draw LPB beats
    ctx.line_width = 1
    for line = view_start, view_end do
      if ((line - 1) % lpb) == 0 then
        local x = PakettiPPWV_LineDelayToX(line, 0, num_lines)
        ctx.stroke_color = {50,50,70,255}
        draw_line(x, 0, x, H)
      end
    end
  end

  -- Row numbers on gutters at LPB intervals (horizontal)
  local row_label_size = 7
  local step = (lpb >= 2) and lpb or 1
  for line = view_start, view_end, step do
    local x = PakettiPPWV_LineDelayToX(line, 0, num_lines + 1)
    
    -- Smart row labeling: every 4th line when > 32 lines, otherwise every line
    local should_show_label = true
    if num_lines > 32 then
      -- Only show labels on "Grey Lines" (every 4th line: 1, 5, 9, 13, etc.)
      should_show_label = ((line - 1) % 4 == 0)
    end
    
    if should_show_label then
      local label = string.format("%03d", (line-1))  -- Show full range without artificial 100-limit, 3 digits for patterns up to 999
      -- Set bright white color for better visibility
      ctx.stroke_color = {255,255,255,255}
      PakettiCanvasFontDrawText(ctx, label, 2, 2, row_label_size)
      PakettiCanvasFontDrawText(ctx, label, W - gutter + 2, 2, row_label_size)
      -- Restore original color for tick marks
      ctx.stroke_color = {90,90,120,255}
    end
    
    ctx.stroke_color = {90,90,120,255}
    ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, 4); ctx:stroke()
  end

  -- Lane separators
  ctx.stroke_color = {60,60,80,255}
  for lane = 1, lanes_to_draw - 1 do
    local y = lane * lane_height
    draw_line(0, y, W, y)
  end

  -- Track labels for each lane and muted overlay
  for lane = 1, lanes_to_draw do
    local track_index = PakettiPPWV_show_only_selected_track and selected_track or lane
    local track = song.tracks[track_index]
    local lane_top = (lane - 1) * lane_height
    local name_text = track and track.name or ("Track " .. string.format("%02d", track_index))
    local label = name_text
    local mute_text = "(MUTED - CLICK TO UNMUTE)"
    local trk2 = song.tracks[track_index]
    local is_muted = PakettiPPWV_IsTrackMuted(trk2)
    
    if is_muted then
      ctx.stroke_color = {200,200,200,255} -- Dimmed text for muted tracks
      if not is_vertical then
        label = label .. " " .. mute_text  -- Horizontal: single line
      end
    else
      ctx.stroke_color = {255,255,255,255}
    end
    ctx.line_width = 1
    PakettiPPWV_DrawText(ctx, label, 6, lane_top + 4, 8)
    -- In vertical mode, draw mute text on second line
    if is_muted and is_vertical then
      PakettiPPWV_DrawText(ctx, mute_text, 6, lane_top + 16, 7)  -- Second line, smaller font
    end
    
    if is_muted then
      -- Solid grey overlay and big MUTE text. Skip waveform drawing later for this lane.
      ctx.fill_color = {80,80,80,220}
      ctx:begin_path(); ctx:rect(0, lane_top, W, lane_height); ctx:fill()
      ctx.stroke_color = {230,230,230,240}
      PakettiPPWV_DrawTextShared(ctx, "MUTE", math.floor(W/2 - 24), math.floor(lane_top + (lane_height/2) - 8), 12)
    end
  end

  -- Draw events as waveforms
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    local should_draw = true
    if PakettiPPWV_show_only_selected_track and ev.track_index ~= selected_track then
      should_draw = false
    end
    if should_draw then
      -- Skip drawing waveforms on muted tracks (rendered as grey with MUTE)
      local trk_muted = PakettiPPWV_IsTrackMuted(song.tracks[ev.track_index])
      if trk_muted then
        should_draw = false
      end
    end
    if should_draw then
      local lane_idx = PakettiPPWV_show_only_selected_track and 1 or ev.track_index
      local lane_top = (lane_idx - 1) * lane_height
      local lane_mid = lane_top + lane_height / 2
      local x1 = PakettiPPWV_LineDelayToX(ev.start_line, ev.start_delay or 0, num_lines)
      local cache = nil
      if ev.sample_index and ev.instrument_index and song.instruments[ev.instrument_index] then
        local instr = song.instruments[ev.instrument_index]
        if instr.samples[ev.sample_index] and instr.samples[ev.sample_index].sample_buffer and instr.samples[ev.sample_index].sample_buffer.has_sample_data then
          cache = PakettiPPWV_GetCachedWaveform(ev.instrument_index, ev.sample_index)
        end
      end
      if cache then
        -- Color: selected vs normal
        if ev.id == PakettiPPWV_selected_event_id or (PakettiPPWV_selected_ids and PakettiPPWV_selected_ids[ev.id]) then
          ctx.stroke_color = {255,200,120,255}
          ctx.line_width = 2
        else
          ctx.stroke_color = {100,255,150,200}
          ctx.line_width = 1
        end
        ctx:begin_path()
        
        -- Calculate actual sample length in pattern lines based on sample data, pitch, BPM, LPB
        local sample = song.instruments[ev.instrument_index].samples[ev.sample_index]
        local actual_sample_length_lines = PakettiPPWV_CalculateSampleLengthInLines(sample, ev, song, patt)
        
        -- Find next waveform on same track/column to determine clipping point
        -- Account for current event's delay when calculating natural end time
        local current_actual_start_time = ev.start_line + (ev.start_delay or 0) / 256
        local natural_end_time = current_actual_start_time + actual_sample_length_lines
        local clip_at_line = natural_end_time
        local earliest_collision_time = natural_end_time
        for j = 1, #PakettiPPWV_events do
          local next_ev = PakettiPPWV_events[j]
          if next_ev.track_index == ev.track_index and next_ev.column_index == ev.column_index and next_ev.id ~= ev.id then
            local next_start_time = next_ev.start_line + (next_ev.start_delay or 0) / 256
            -- Only consider events that start after the current event's actual start time
            if next_start_time > current_actual_start_time and next_start_time < earliest_collision_time then
              earliest_collision_time = next_start_time
            end
          end
        end
        clip_at_line = earliest_collision_time
        
        -- Also check for Note Off events that could cut off this sample
        local note_off_time = PakettiPPWV_FindNoteOffAt(patt, ev.track_index, ev.column_index, current_actual_start_time, clip_at_line)
        if note_off_time and note_off_time < clip_at_line then
          clip_at_line = note_off_time
        end
        
        -- Limit to pattern end
        clip_at_line = math.min(clip_at_line, num_lines + 1)
        
        local fixed_x2 = PakettiPPWV_LineDelayToX(clip_at_line, 0, num_lines)
        if fixed_x2 < x1 + 1 then fixed_x2 = x1 + 1 end
        local width = fixed_x2 - x1
        local points = #cache
        
        -- Fixed visual scale: use position-independent reference to ensure identical visual scale
        -- Calculate pixels per sample based on a standard reference width (not position-dependent)
        local reference_start = 1.0  -- Use line 1 as reference point
        local reference_width = PakettiPPWV_LineDelayToX(reference_start + actual_sample_length_lines, 0, num_lines) - PakettiPPWV_LineDelayToX(reference_start, 0, num_lines)
        local pixels_per_sample = reference_width / points
        
        -- DEBUG: Print rendering details
        print(string.format("-- PPWV MAIN RENDER: Track %d Line %d -> Length=%.3f, RefWidth=%.1f, PPS=%.3f, Points=%d", 
          ev.track_index, ev.start_line, actual_sample_length_lines, reference_width, pixels_per_sample, points))
        
        -- CRITICAL FIX: Draw waveform ONLY for actual sample length, not collision clip length  
        local actual_sample_width = PakettiPPWV_LineDelayToX(current_actual_start_time + actual_sample_length_lines, 0, num_lines) - x1
        local sample_draw_width = math.min(width, actual_sample_width)  -- Don't exceed actual sample
        for px = 0, math.floor(sample_draw_width) do
          local sample_idx = math.floor(px / pixels_per_sample) + 1
          if sample_idx < 1 then sample_idx = 1 end
          if sample_idx > points then sample_idx = points end
          local sample_v = cache[sample_idx]
          local y = lane_mid - (sample_v * (lane_height * 0.45))
          local x = x1 + px
          if px == 0 then
            if not is_vertical then ctx:move_to(x, y) else ctx:move_to(x, y) end
          else
            if not is_vertical then ctx:line_to(x, y) else ctx:line_to(x, y) end
          end
        end
        ctx:stroke()

        -- Optional labels above the start of the waveform
        if PakettiPPWV_show_labels or PakettiPPWV_show_sample_names or PakettiPPWV_show_note_names then
          local instrument_name = ""
          local sample_name = ""
          local note_txt = ""
          
          -- Get instrument name if requested
          if PakettiPPWV_show_labels then
            local instr = song.instruments[ev.instrument_index]
            if instr and instr.name and instr.name ~= "" then instrument_name = instr.name end
          end
          
          -- Get sample name if requested
          if PakettiPPWV_show_sample_names then
            local instr = song.instruments[ev.instrument_index]
            local sample = instr and instr.samples and instr.samples[ev.sample_index]
            if sample and sample.name and sample.name ~= "" then sample_name = sample.name end
          end
          
          -- Get note name if requested  
          if PakettiPPWV_show_note_names then
            local ptrack = patt:track(ev.track_index)
            local ln = ptrack:line(ev.start_line)
            if ln and ln.note_columns and ln.note_columns[ev.column_index] then
              local nc = ln.note_columns[ev.column_index]
              if not nc.is_empty and nc.note_value and nc.note_value <= 119 then
                local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
                local oct = math.floor(nc.note_value/12)
                note_txt = names[(nc.note_value%12)+1] .. tostring(oct)
              end
            end
          end
          
          -- Build label from components
          local label = ""
          if instrument_name ~= "" then
            label = instrument_name
          end
          if sample_name ~= "" then
            if label ~= "" then label = label .. "  " .. sample_name else label = sample_name end
          end
          if note_txt ~= "" then
            if label ~= "" then label = label .. "  " .. note_txt else label = note_txt end
          end
          
          -- Only draw label if we have something to show
          if label ~= "" then
            ctx.stroke_color = {255,255,120,255}  -- Brighter yellow color
            ctx.line_width = 1
            if not is_vertical then
              PakettiPPWV_DrawText(ctx, label, x1 + 2, lane_top + 2, 9)  -- Larger font size
            else
              PakettiPPWV_DrawText(ctx, label, lane_top + 2, x1 + 2, 9)  -- Larger font size
            end
          end
        end
      end
    end
  end

  -- Playback cursor
  local tp = song.transport
  local x_play = nil
  local play_line = nil
  if tp.playing then
    local playpos = tp.playback_pos
    if playpos and playpos.sequence and playpos.line and playpos.sequence == renoise.song().selected_sequence_index then
      play_line = playpos.line
    end
  else
    play_line = song.selected_line_index
  end
  if play_line then
    x_play = PakettiPPWV_LineDelayToX(play_line, 0, num_lines)
  end
  if x_play then
    ctx.stroke_color = {255,200,120,255}
    ctx.line_width = 2
    draw_line(x_play, 0, x_play, H)
  end
end

-- Mouse handler
PakettiPPWV_is_dragging = false
PakettiPPWV_drag_start = nil

function PakettiPPWV_MouseHandler(ev)
  if ev.type == "down" and ev.button == "left" then
    PakettiPPWV_DebugPrintModifierFlags("mouse-down")
    
    -- Check if click is on track title area for mute toggle (main canvas view)
    local song = renoise.song()
    if song then
      local lane_height = PakettiPPWV_GetLaneHeight()  -- DRY: Use centralized calculation
      local lane_idx = math.floor(ev.position.y / lane_height) + 1
      local y_in_lane = ev.position.y % lane_height
      local track_index = PakettiPPWV_show_only_selected_track and song.selected_track_index or lane_idx
      
      if track_index >= 1 and track_index <= #song.tracks then
        local track = song.tracks[track_index]
        local is_track_muted = PakettiPPWV_IsTrackMuted(track)
        local is_in_title_area = (y_in_lane <= 14) and (ev.position.x <= 200)  -- Title text area
        
        print(string.format("-- PPWV: Main canvas click - track=%d, x=%.1f, y_in_lane=%.1f, title_area=%s, muted=%s", 
          track_index, ev.position.x, y_in_lane, tostring(is_in_title_area), tostring(is_track_muted)))
        
        if is_in_title_area then
          -- Click on track title - always toggle mute
          print("-- PPWV: Main canvas title click! Toggling mute for track " .. track_index)
          PakettiPPWV_ToggleTrackMute(track_index)
          -- Immediate update for track mute changes (essential UX feedback)
          PakettiPPWV_UpdateCanvasThrottled()
          return
        elseif is_track_muted then
          -- Click anywhere on a muted track - unmute it
          print("-- PPWV: Main canvas click on muted track " .. track_index .. " - unmuting!")
          PakettiPPWV_ToggleTrackMute(track_index)
          -- Immediate update for track mute changes (essential UX feedback)
          PakettiPPWV_UpdateCanvasThrottled()
          return
        end
      end
    end
    
    local evhit = PakettiPPWV_FindEventAt(ev.position.x, ev.position.y)
    if evhit then
      -- Double-click logic
      local now_ms = os.clock() * 1000
      local dx = ev.position.x - PakettiPPWV_last_click_x
      local dy = ev.position.y - PakettiPPWV_last_click_y
      local dist2 = dx*dx + dy*dy
      local is_double = (now_ms - PakettiPPWV_last_click_time_ms) < PakettiPPWV_double_click_threshold_ms and dist2 < 100

      local song = renoise.song()
      -- Select track and instrument/sample
      song.selected_track_index = evhit.track_index
      song.selected_instrument_index = evhit.instrument_index
      if song.instruments[evhit.instrument_index] and #song.instruments[evhit.instrument_index].samples >= evhit.sample_index then
        song.selected_sample_index = evhit.sample_index
      end
      -- CRITICAL: Move pattern cursor FIRST (immediate)
      song.selected_line_index = evhit.start_line
      -- Ensure delay column visible
      local trk = song.tracks[evhit.track_index]
      if trk and trk.delay_column_visible ~= nil then trk.delay_column_visible = true end

      if is_double then
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      else
        -- Selection logic: support shift-click multi-select on same track
        if not PakettiPPWV_selected_ids then PakettiPPWV_selected_ids = {} end
        PakettiPPWV_HandleClickSelection(evhit)

        PakettiPPWV_is_dragging = true
        PakettiPPWV_drag_start = {x = ev.position.x, y = ev.position.y, id = evhit.id}
        PakettiPPWV_is_dup_dragging = PakettiPPWV_alt_is_down
        
        -- ADD: Start dirty window for drag (horizontal mode)
        PPWV_DirtyBegin(evhit.start_line, evhit.start_line)
        print(string.format("-- PPWV SELECT id=%s dup_drag=%s shift=%s alt=%s ctrl=%s cmd=%s", evhit.id, tostring(PakettiPPWV_is_dup_dragging), tostring(PakettiPPWV_shift_is_down), tostring(PakettiPPWV_alt_is_down), tostring(PakettiPPWV_ctrl_is_down), tostring(PakettiPPWV_cmd_is_down)))
        -- Canvas update after pattern editor change
        renoise.tool():add_timer(function() PakettiPPWV_UpdateCanvasImmediate() end, 50)  -- Reduced from 1ms to 50ms
      end

      PakettiPPWV_last_click_time_ms = now_ms
      PakettiPPWV_last_click_x = ev.position.x
      PakettiPPWV_last_click_y = ev.position.y
    end
  elseif ev.type == "move" then
    if PakettiPPWV_is_dragging and PakettiPPWV_drag_start and PakettiPPWV_selected_event_id then
      local dx = ev.position.x - PakettiPPWV_drag_start.x
      local song, patt = PakettiPPWV_GetSongAndPattern()
      if song and patt then
        local num_lines = patt.number_of_lines
        local ticks_per_pixel = (num_lines * 256) / PakettiPPWV_canvas_width
        local delta_ticks = math.floor(dx * ticks_per_pixel)
        if math.abs(delta_ticks) >= 1 then
          -- find event
          for i = 1, #PakettiPPWV_events do
            local e = PakettiPPWV_events[i]
            if e.id == PakettiPPWV_selected_event_id then
              local applied = false
              if PakettiPPWV_is_dup_dragging then
                applied = PakettiPPWV_DuplicateEventByTicks(e, delta_ticks)
              else
                applied = PakettiPPWV_MoveEventByTicks(e, delta_ticks)
              end
              if applied then
                PakettiPPWV_drag_start.x = ev.position.x
                PakettiPPWV_RebuildEvents()
                
                -- ADD: Update dirty window during drag (horizontal mode)
                local current_line = PakettiPPWV_XToLine(ev.position.x, num_lines)
                PPWV_DirtyUpdate(current_line, current_line)
                
                if PakettiPPWV_canvas then PakettiPPWV_canvas:update() end
              end
              break
            end
          end
        end
      end
    end
  elseif ev.type == "up" and ev.button == "left" then
    PakettiPPWV_is_dragging = false
    PakettiPPWV_drag_start = nil
    PakettiPPWV_is_dup_dragging = false
    
    -- ADD: End dirty window on drag end (horizontal mode)
    PPWV_DirtyEnd()
  end
end

-- Build hash for mute states only (fallback detection)
function PakettiPPWV_BuildMuteStateHash()
  local song = renoise.song()
  if not song then return "" end
  local acc = {}
  for i = 1, #song.tracks do
    local track = song.tracks[i]
    if track then
      local mute_state = "active"
      if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
        if track.mute_state == renoise.Track.MUTE_STATE_MUTED then
          mute_state = "muted"
        elseif track.mute_state == renoise.Track.MUTE_STATE_OFF then
          mute_state = "off"
        end
      end
      acc[#acc+1] = "t" .. tostring(i) .. ":" .. mute_state
    end
  end
  return table.concat(acc, ":")
end

-- Build hash for sample buffer states to detect modifications (reverse, crop, etc.)
function PakettiPPWV_BuildSampleBufferHash()
  local song = renoise.song()
  if not song then return "" end
  local acc = {}
  
  -- Check all instruments and their samples for buffer changes
  for inst_idx = 1, #song.instruments do
    local instrument = song.instruments[inst_idx]
    if instrument and #instrument.samples > 0 then
      for samp_idx = 1, #instrument.samples do
        local sample = instrument.samples[samp_idx]
        if sample and sample.sample_buffer and sample.sample_buffer.has_sample_data then
          local buffer = sample.sample_buffer
          -- Use number of frames + sample rate + bit depth as basic change detection
          -- This will change when samples are reversed, cropped, resampled, etc.
          local buffer_info = string.format("%d:%d:%d:%d", 
            buffer.number_of_frames or 0,
            buffer.sample_rate or 0, 
            buffer.bit_depth or 0,
            buffer.number_of_channels or 0
          )
          acc[#acc+1] = "i" .. tostring(inst_idx) .. "s" .. tostring(samp_idx) .. ":" .. buffer_info
        end
      end
    end
  end
  
  return table.concat(acc, ":")
end

-- Timer callback
function PakettiPPWV_TimerTick()
  if not PakettiPPWV_dialog or not PakettiPPWV_dialog.visible then return end
  
  -- Check for mute state changes (fallback if observers don't work)
  local mute_hash = PakettiPPWV_BuildMuteStateHash()
  local mute_changed = (mute_hash ~= PakettiPPWV_last_mute_hash)
  if mute_changed then
    print("-- PPWV: Mute state changed (fallback detection)")
    PakettiPPWV_last_mute_hash = mute_hash
  end
  
  -- Check for sample buffer changes (reverse, crop, resample, etc.)
  local sample_hash = PakettiPPWV_BuildSampleBufferHash()
  local samples_changed = (sample_hash ~= PakettiPPWV_last_sample_hash)
  if samples_changed then
    print("-- PPWV: Sample buffer changes detected, clearing waveform cache")
    PakettiPPWV_last_sample_hash = sample_hash
    -- Clear entire waveform cache when any sample changes
    PakettiPPWV_cached_waveforms = {}
    PakettiPPWV_sample_length_cache = {}
  end
  
  -- Check for pattern content changes  
  local hash = PakettiPPWV_BuildPatternHash()
  local pattern_changed = (hash ~= PakettiPPWV_last_content_hash)
  if pattern_changed then
    print("-- PPWV: Pattern hash changed, updating display")
    PakettiPPWV_last_content_hash = hash
  end
  
  -- Update if any changes detected
  if pattern_changed or mute_changed or samples_changed then
    PakettiPPWV_RebuildEvents()
    PakettiPPWV_UpdateCanvasThrottled()
  else
    -- Only redraw during playback if playheads are enabled (otherwise pointless!)
    local song = renoise.song()
    if song and song.transport.playing and (PakettiPPWV_show_horizontal_playhead or PakettiPPWV_show_vertical_playhead) then
      PakettiPPWV_UpdateCanvasThrottled()
    end
  end
end

-- Cleanup observers/timer
function PakettiPPWV_Cleanup()
  if PakettiPPWV_timer_running then
    renoise.tool():remove_timer(PakettiPPWV_TimerTick)
    PakettiPPWV_timer_running = false
  end
  -- Detach all observers
  PakettiPPWV_DetachTrackMuteObservers()
  PakettiPPWV_DetachSelectedTrackObserver()
  
  -- Clear state
  PakettiPPWV_dialog = nil
  PakettiPPWV_vb = nil
  PakettiPPWV_canvas = nil
  PakettiPPWV_track_canvases = {}
  PakettiPPWV_tracks_observable = nil
  PakettiPPWV_tracks_observer_func = nil
  PakettiPPWV_selected_event_id = nil
  PakettiPPWV_cached_waveforms = {}
  PakettiPPWV_reference_scale_cache = {}  -- Clear reference cache with waveforms
  PakettiPPWV_last_content_hash = ""
  PakettiPPWV_last_mute_hash = ""
  PakettiPPWV_last_sample_hash = ""  -- Clear sample buffer hash
  PakettiPPWV_last_track_count = 0
  PakettiPPWV_last_click_event = nil
  print("-- Paketti PPWV: Cleaned up")
end

-- Build dialog content for current orientation
function PakettiPPWV_BuildContent()
  -- Controls row (zoom, orientation, vertical scale)
  local controls_row = PakettiPPWV_vb:row{
    
    PakettiPPWV_vb:switch{
      id = "ppwv_zoom_switch",
      items = {"Full","1/2","1/4","1/8"},
      width = 100,
      value = PakettiPPWV_zoom_index,
      notifier = function(val) PakettiPPWV_SetZoomIndex(val) end
    },
    PakettiPPWV_vb:switch{
      id = "ppwv_orient_switch",
      items = {"Horizontal","Vertical"},
      width = 150,
      value = PakettiPPWV_orientation,
      notifier = function(val)
        PakettiPPWV_orientation = val
        PakettiPPWV_SavePreferences()
        PakettiPPWV_ReopenDialog()
      end
    },
    PakettiPPWV_vb:text{ text = "Zoom", style = "strong", font="bold" },
    PakettiPPWV_vb:switch{
      id = "ppwv_vscale_switch_top",
      items = {"1x","2x","3x"},
      width = 180,
      value = PakettiPPWV_vertical_scale_index,
      notifier = function(val)
        PakettiPPWV_vertical_scale_index = val
        PakettiPPWV_SavePreferences()
        -- Reopen dialog to resize timeline sidebar to match new track canvas heights
        PakettiPPWV_ReopenDialog()
      end
    },
    PakettiPPWV_vb:text{ text = "Show", style = "strong", font="bold" },
    PakettiPPWV_vb:checkbox{ id = "ppwv_show_labels_cb", value = PakettiPPWV_show_labels, notifier = function(v) PakettiPPWV_show_labels = v; PakettiPPWV_SavePreferences(); PakettiPPWV_UpdateCanvasThrottled() end }, 
    PakettiPPWV_vb:text{ text = "Instrument Name" },
    PakettiPPWV_vb:checkbox{ id = "ppwv_show_sample_names_cb", value = PakettiPPWV_show_sample_names, notifier = function(v) PakettiPPWV_show_sample_names = v; PakettiPPWV_SavePreferences(); PakettiPPWV_UpdateCanvasThrottled() end }, 
    PakettiPPWV_vb:text{ text = "Sample Name" },
    PakettiPPWV_vb:checkbox{ id = "ppwv_show_note_names_cb", value = PakettiPPWV_show_note_names, notifier = function(v) PakettiPPWV_show_note_names = v; PakettiPPWV_SavePreferences(); PakettiPPWV_UpdateCanvasThrottled() end }, 
    PakettiPPWV_vb:text{ text = "Note" }
  }

  -- Options row (checkbox + label pairs)
  local options_row = PakettiPPWV_vb:row{
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_multi_cb", value = PakettiPPWV_multi_select_mode, notifier = function(v) PakettiPPWV_multi_select_mode = v; if not v then PakettiPPWV_selected_ids = {} end; PakettiPPWV_UpdateCanvasThrottled() end }, PakettiPPWV_vb:text{ text = "Multi-select)" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_select_same_cb", value = PakettiPPWV_select_same_enabled, notifier = function(v) PakettiPPWV_select_same_enabled = v; if v then PakettiPPWV_SelectAllMatchingSamples() end end }, PakettiPPWV_vb:text{ text = "Select the same sample" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_only_selected_cb", value = PakettiPPWV_show_only_selected_track, notifier = function(v) PakettiPPWV_show_only_selected_track = v; PakettiPPWV_SavePreferences(); PakettiPPWV_ReopenDialog() end }, PakettiPPWV_vb:text{ text = "Show Selected Track" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_performance_cb", value = PakettiPPWV_performance_mode, notifier = function(v) PakettiPPWV_performance_mode = v; PakettiPPWV_UpdateCanvasThrottled() end }, PakettiPPWV_vb:text{ text = "Simpler Canvas" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_horizontal_playhead_cb", value = PakettiPPWV_show_horizontal_playhead, notifier = function(v) PakettiPPWV_show_horizontal_playhead = v; PakettiPPWV_SavePreferences(); PakettiPPWV_UpdateCanvasThrottled() end }, PakettiPPWV_vb:text{ text = "Horizontal playhead" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_vertical_playhead_cb", value = PakettiPPWV_show_vertical_playhead, notifier = function(v) PakettiPPWV_show_vertical_playhead = v; PakettiPPWV_SavePreferences(); PakettiPPWV_UpdateCanvasThrottled() end }, PakettiPPWV_vb:text{ text = "Vertical playhead" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_batch_tracks_cb", value = PakettiPPWV_batch_tracks, notifier = function(v) PakettiPPWV_batch_tracks = v; PakettiPPWV_ReopenDialog() end }, PakettiPPWV_vb:text{ text = "Batch tracks (4 per canvas in vertical)" } },
    PakettiPPWV_vb:row{ PakettiPPWV_vb:checkbox{ id = "ppwv_debug_cb", value = PakettiPPWV_debug, notifier = function(v) PakettiPPWV_debug = v end }, PakettiPPWV_vb:text{ text = "Debug messages" } },
    PakettiPPWV_vb:button{ id = "ppwv_refresh_button", text = "Refresh", width = 60, notifier = function() PakettiPlayerProWaveformViewerRefresh() end },
    PakettiPPWV_vb:button{ id = "ppwv_duplicate_pattern_button", text = "Duplicate Pattern", width = 100, notifier = function() PakettiPPWV_DuplicatePattern() end }
  }

  if PakettiPPWV_orientation == 2 then
    -- Vertical: timeline as left sidebar, tracks in middle, scrollbar on right (no horizontal header)
    local vertical_header = PakettiPPWV_vb:column{ controls_row, options_row } -- No header_row with timeline in vertical mode
    
    -- Calculate actual canvas height with scaling applied
    local actual_canvas_height = PakettiPPWV_GetCurrentCanvasHeight()
    
    local timeline_sidebar = PakettiPPWV_vb:canvas{ id = "ppwv_timeline_sidebar", width = 50, height = actual_canvas_height, mode = "plain", 
      mouse_events = {"down"}, 
      mouse_handler = function(ev)
        if ev.type == "down" then
          local song, patt = PakettiPPWV_GetSongAndPattern(); if not song or not patt then return end
          local y = ev.position.y
          local num_lines = patt.number_of_lines
          local win = PakettiPPWV_GetWindowLines(num_lines)
          local divisor = (win > 1) and win or 1
          local target_line = math.floor(((y / actual_canvas_height) * divisor) + (PakettiPPWV_view_start_line - 1)) + 1
          if target_line < 1 then target_line = 1 end
          if target_line > num_lines then target_line = num_lines end
          -- CRITICAL: Pattern editor changes FIRST (immediate)
          song.selected_line_index = target_line
          song.transport:start_at{sequence = renoise.song().selected_sequence_index, line = target_line}
          -- THEN canvas update with delay for responsiveness 
          renoise.tool():add_timer(function() PakettiPPWV_UpdateCanvasImmediate() end, 50)  -- Reduced from 1ms to 50ms
        end
      end,
      render = PakettiPPWV_RenderVerticalTimeline(50, actual_canvas_height) 
    }
    local main_content = PakettiPPWV_vb:row{
      spacing = 0,
      timeline_sidebar,
      PakettiPPWV_vb:column{ id = "ppwv_tracks_container", spacing = 0 },
      PakettiPPWV_vb:scrollbar{ id = "ppwv_vscrollbar", min = 1, max = 2, value = 1, step = 1, pagestep = 1, autohide = false, width = 20, height = 200, notifier = function(val) PakettiPPWV_view_start_line = val; PakettiPPWV_UpdateScrollbars(); PakettiPPWV_UpdateCanvasThrottled() end }
    }
    return PakettiPPWV_vb:column{vertical_header, main_content }
  else
    -- Horizontal: with horizontal header and scrollbar
    local header_row = PakettiPPWV_vb:row{ spacing = 0, PakettiPPWV_vb:canvas{ id = "ppwv_header_canvas", width = PakettiPPWV_canvas_width, height = PakettiPPWV_gutter_height + 6, mode = "plain", mouse_events = {"down"}, mouse_handler = function(ev) 
        -- simple click-to-jump handler mapped to header canvas
        local song, patt = PakettiPPWV_GetSongAndPattern(); if not song or not patt then return end
        if ev.type == "down" then
          local x = ev.position.x
          local num_lines = patt.number_of_lines
          local win = PakettiPPWV_GetWindowLines(num_lines)
          local divisor = (win > 1) and win or 1
          local target_line = math.floor(((x / (PakettiPPWV_canvas_width)) * divisor) + (PakettiPPWV_view_start_line - 1)) + 1
          if target_line < 1 then target_line = 1 end
          if target_line > num_lines then target_line = num_lines end
          -- CRITICAL: Pattern editor changes FIRST (immediate)
          song.selected_line_index = target_line
          song.transport:start_at{sequence = renoise.song().selected_sequence_index, line = target_line}
          -- THEN canvas update with delay for responsiveness 
          renoise.tool():add_timer(function() PakettiPPWV_UpdateCanvasImmediate() end, 50)  -- Reduced from 1ms to 50ms
        end
      end, render = PakettiPPWV_RenderHeaderCanvas(PakettiPPWV_canvas_width, PakettiPPWV_gutter_height + 6) } }
    local horizontal_header = PakettiPPWV_vb:column{ controls_row, options_row, header_row }
    
    local tracks_col = PakettiPPWV_vb:column{ id = "ppwv_tracks_container", spacing = 0 }
    local bottom_row = PakettiPPWV_vb:row{
      PakettiPPWV_vb:text{ text = "Scroll:" }, PakettiPPWV_vb:space{ width = 10 },
      PakettiPPWV_vb:scrollbar{ id = "ppwv_scrollbar", min = 1, max = 2, value = 1, step = 1, pagestep = 1, autohide = false, width = 400, height = 20, notifier = function(val) PakettiPPWV_view_start_line = val; PakettiPPWV_UpdateScrollbars(); PakettiPPWV_UpdateCanvasThrottled() end }
    }
    return PakettiPPWV_vb:column{horizontal_header, tracks_col, bottom_row }
  end
end

function PakettiPPWV_ReopenDialog()
  if PakettiPPWV_dialog and PakettiPPWV_dialog.visible then PakettiPPWV_dialog:close() end
  PakettiPPWV_vb = renoise.ViewBuilder()
  local content = PakettiPPWV_BuildContent()
  PakettiPPWV_dialog = renoise.app():show_custom_dialog("Paketti PlayerPro Waveform Viewer", content, PakettiPPWV_KeyHandler)
  PakettiPPWV_tracks_container = PakettiPPWV_vb.views.ppwv_tracks_container
  PakettiPPWV_scrollbar_view = PakettiPPWV_vb.views.ppwv_scrollbar
  PakettiPPWV_vscrollbar_view = PakettiPPWV_vb.views.ppwv_vscrollbar
  PakettiPPWV_header_canvas = PakettiPPWV_vb.views.ppwv_header_canvas
  PakettiPPWV_timeline_sidebar = PakettiPPWV_vb.views.ppwv_timeline_sidebar
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Initialize track count for change detection
  local song = renoise.song()
  if song then
    PakettiPPWV_last_track_count = #song.tracks
    print("-- PPWV: Initialized track count to " .. PakettiPPWV_last_track_count)
  end
  
  -- Initialize hashes for change detection
  PakettiPPWV_last_content_hash = PakettiPPWV_BuildPatternHash()
  PakettiPPWV_last_mute_hash = PakettiPPWV_BuildMuteStateHash()
  
  PakettiPPWV_AttachTrackMuteObservers()
  PakettiPPWV_AttachSelectedTrackObserver()
  PakettiPPWV_RebuildEvents(); PakettiPPWV_UpdateScrollbars(); PakettiPPWV_RebuildTrackCanvases(); PakettiPPWV_UpdateCanvasThrottled()
  if not PakettiPPWV_timer_running then renoise.tool():add_timer(PakettiPPWV_TimerTick, PakettiPPWV_timer_interval_ms); PakettiPPWV_timer_running = true end
  cleanup_observers = PakettiPPWV_Cleanup
end

-- Open dialog
function PakettiPlayerProWaveformViewerShowDialog()
  if PakettiPPWV_dialog and PakettiPPWV_dialog.visible then
    PakettiPPWV_dialog:close()
    PakettiPPWV_Cleanup()
    return
  end

  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then
    renoise.app():show_status("Paketti PPWV: No song/pattern available")
    return
  end

  -- Load preferences before opening dialog
  PakettiPPWV_LoadPreferences()

  local lanes = song.sequencer_track_count
  PakettiPPWV_canvas_height = math.max(200, lanes * PakettiPPWV_lane_height)

  PakettiPPWV_ReopenDialog()
  print("-- Paketti PPWV: Dialog opened")
end

-- Public helpers for keybindings
function PakettiPlayerProWaveformViewerNudgeLeftTick()
  if not PakettiPPWV_selected_event_id then return end
  
  -- If "Select the same" is enabled, automatically populate matching selections
  if PakettiPPWV_select_same_enabled then
    PakettiPPWV_SelectAllMatchingSamples()
  end
  
  -- Handle multi-selection if enabled and multiple items selected
  if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and PakettiPPWV_selected_ids and PakettiPPWV_SelectedCount() > 0 then
    PakettiPPWV_NudgeMultipleOnSameTrack(-1)
    return
  end
  
  -- Handle single selection
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      if PakettiPPWV_MoveEventByTicks(ev, -1) then
        PakettiPPWV_ScheduleDeferredUpdate()
      end
      break
    end
  end
end

function PakettiPlayerProWaveformViewerNudgeRightTick()
  if not PakettiPPWV_selected_event_id then return end
  
  -- If "Select the same" is enabled, automatically populate matching selections
  if PakettiPPWV_select_same_enabled then
    PakettiPPWV_SelectAllMatchingSamples()
  end
  
  -- Handle multi-selection if enabled and multiple items selected
  if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and PakettiPPWV_selected_ids and PakettiPPWV_SelectedCount() > 0 then
    PakettiPPWV_NudgeMultipleOnSameTrack(1)
    return
  end
  
  -- Handle single selection
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      if PakettiPPWV_MoveEventByTicks(ev, 1) then
        PakettiPPWV_ScheduleDeferredUpdate()
      end
      break
    end
  end
end

function PakettiPlayerProWaveformViewerNudgeLeftLine()
  if not PakettiPPWV_selected_event_id then return end
  
  -- If "Select the same" is enabled, automatically populate matching selections
  if PakettiPPWV_select_same_enabled then
    PakettiPPWV_SelectAllMatchingSamples()
  end
  
  -- Handle multi-selection if enabled and multiple items selected
  if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and PakettiPPWV_selected_ids and PakettiPPWV_SelectedCount() > 0 then
    PakettiPPWV_NudgeMultipleOnSameTrack(-256)
    return
  end
  
  -- Handle single selection
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      if PakettiPPWV_MoveEventByTicks(ev, -256) then
        PakettiPPWV_ScheduleDeferredUpdate()
      end
      break
    end
  end
end

function PakettiPlayerProWaveformViewerNudgeRightLine()
  if not PakettiPPWV_selected_event_id then return end
  
  -- If "Select the same" is enabled, automatically populate matching selections
  if PakettiPPWV_select_same_enabled then
    PakettiPPWV_SelectAllMatchingSamples()
  end
  
  -- Handle multi-selection if enabled and multiple items selected
  if (PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled) and PakettiPPWV_selected_ids and PakettiPPWV_SelectedCount() > 0 then
    PakettiPPWV_NudgeMultipleOnSameTrack(256)
    return
  end
  
  -- Handle single selection
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      if PakettiPPWV_MoveEventByTicks(ev, 256) then
        PakettiPPWV_ScheduleDeferredUpdate()
      end
      break
    end
  end
end

function PakettiPlayerProWaveformViewerSnapToRow()
  if not PakettiPPWV_selected_event_id then return end
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return end
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      local ptrack = patt:track(ev.track_index)
      local src_nc = ptrack:line(ev.start_line).note_columns[ev.column_index]
      if not src_nc or src_nc.is_empty then return end
      local delay = src_nc.delay_value or 0
      local delta = 0
      if delay >= 128 then
        delta = 256 - delay
      else
        delta = -delay
      end
      if PakettiPPWV_MoveEventByTicks(ev, delta) then
        PakettiPPWV_ScheduleDeferredUpdate()
      end
      break
    end
  end
end

function PakettiPlayerProWaveformViewerSelectPrev()
  if #PakettiPPWV_events == 0 then return end
  local idx = 1
  for i = 1, #PakettiPPWV_events do
    if PakettiPPWV_events[i].id == PakettiPPWV_selected_event_id then
      idx = i
      break
    end
  end
  idx = idx + (-1)
  if idx < 1 then idx = 1 end
  if idx > #PakettiPPWV_events then idx = #PakettiPPWV_events end
  PakettiPPWV_selected_event_id = PakettiPPWV_events[idx].id
  if PakettiPPWV_canvas then PakettiPPWV_canvas:update() end
end

function PakettiPlayerProWaveformViewerSelectNext()
  if #PakettiPPWV_events == 0 then return end
  local idx = 1
  for i = 1, #PakettiPPWV_events do
    if PakettiPPWV_events[i].id == PakettiPPWV_selected_event_id then
      idx = i
      break
    end
  end
  idx = idx + 1
  if idx < 1 then idx = 1 end
  if idx > #PakettiPPWV_events then idx = #PakettiPPWV_events end
  PakettiPPWV_selected_event_id = PakettiPPWV_events[idx].id
  if PakettiPPWV_canvas then PakettiPPWV_canvas:update() end
end

renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Paketti:Xperimental/WIP:PlayerPro:Waveform Viewer", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end }
renoise.tool():add_menu_entry{ name = "Main Menu:Tools:PlayerPro Waveform Viewer", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}
renoise.tool():add_menu_entry{ name = "Pattern Editor:Paketti:PlayerPro:Waveform Viewer", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Open Viewer", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}
renoise.tool():add_keybinding{ name = "Global:Paketti:PlayerPro Waveform Viewer Open Viewer", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}

renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Left (Tick)", invoke = PakettiPlayerProWaveformViewerNudgeLeftTick }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Right (Tick)", invoke = PakettiPlayerProWaveformViewerNudgeRightTick }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Left (Line)", invoke = PakettiPlayerProWaveformViewerNudgeLeftLine }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Right (Line)", invoke = PakettiPlayerProWaveformViewerNudgeRightLine }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Snap Selected To Row", invoke = PakettiPlayerProWaveformViewerSnapToRow }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Select Previous Event", invoke = PakettiPlayerProWaveformViewerSelectPrev }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Select Next Event", invoke = PakettiPlayerProWaveformViewerSelectNext }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Refresh", invoke = PakettiPlayerProWaveformViewerRefresh }

renoise.tool():add_midi_mapping{ name = "Paketti:PlayerPro Waveform Viewer Open Viewer", invoke = function(message) if message:is_trigger() then PakettiPlayerProWaveformViewerShowDialog() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:PlayerPro Waveform Viewer Nudge Left (Tick)", invoke = function(message) if message:is_trigger() then PakettiPlayerProWaveformViewerNudgeLeftTick() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:PlayerPro Waveform Viewer Nudge Right (Tick)", invoke = function(message) if message:is_trigger() then PakettiPlayerProWaveformViewerNudgeRightTick() end end }