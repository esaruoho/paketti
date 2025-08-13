-- Paketti PlayerPro Waveform Viewer (SkunkWorks)
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
PakettiPPWV_timer_interval_ms = 200
PakettiPPWV_last_content_hash = ""
PakettiPPWV_events = {}
PakettiPPWV_selected_event_id = nil
PakettiPPWV_cached_waveforms = {}
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

-- Viewport/zoom state
PakettiPPWV_zoom_levels = {1.0, 0.5, 0.25, 0.125}
PakettiPPWV_zoom_index = 1 -- 1.0 by default (full pattern)
PakettiPPWV_view_start_line = 1
PakettiPPWV_show_labels = false
PakettiPPWV_scrollbar_view = nil
PakettiPPWV_vscrollbar_view = nil
PakettiPPWV_show_only_selected_track = false
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

function PakettiPPWV_UpdateCanvasThrottled()
  local now_ms = os.clock() * 1000
  -- Adaptive interval: fast when dragging, medium when playing, slow when idle
  local song = renoise.song()
  local playing = song and song.transport.playing
  local interval = 120
  if PakettiPPWV_is_dragging then interval = 15
  elseif playing then interval = 33 end
  PakettiPPWV_min_redraw_ms = interval
  if (now_ms - PakettiPPWV_last_redraw_ms) >= PakettiPPWV_min_redraw_ms then
    if PakettiPPWV_canvas and PakettiPPWV_canvas.visible then
      PakettiPPWV_canvas:update()
    end
    if PakettiPPWV_track_canvases and #PakettiPPWV_track_canvases > 0 then
      for i = 1, #PakettiPPWV_track_canvases do
        local c = PakettiPPWV_track_canvases[i]
        if c and c.visible then c:update() end
      end
    end
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
    PakettiPPWV_scrollbar_view.value = PakettiPPWV_view_start_line
  end
  if PakettiPPWV_vscrollbar_view then
    local win = PakettiPPWV_GetWindowLines(num_lines)
    PakettiPPWV_vscrollbar_view.min = 1
    PakettiPPWV_vscrollbar_view.max = num_lines + 1
    PakettiPPWV_vscrollbar_view.pagestep = win
    PakettiPPWV_vscrollbar_view.value = PakettiPPWV_view_start_line
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
  local x = ((t - view_start_t) / win) * PakettiPPWV_canvas_width
  return x
end

function PakettiPPWV_MapTimeToY(t, num_lines, canvas_height)
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local view_start_t = (PakettiPPWV_view_start_line - 1)
  local H = canvas_height or PakettiPPWV_canvas_height
  local y = ((t - view_start_t) / win) * H
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

-- Render a single track into its own canvas (horizontal or vertical)
function PakettiPPWV_RenderTrackCanvas(track_index)
  return function(ctx)
    local song, patt = PakettiPPWV_GetSongAndPattern()
    local W = ctx.width or PakettiPPWV_canvas_width
    local H = ctx.height or PakettiPPWV_lane_height
    ctx:clear_rect(0, 0, W, H)
    ctx:set_fill_linear_gradient(0, 0, 0, H)
    ctx:add_fill_color_stop(0, {25,25,35,255})
    ctx:add_fill_color_stop(1, {15,15,25,255})
    ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local is_vertical = (PakettiPPWV_orientation == 2)
    local win = PakettiPPWV_GetWindowLines(num_lines)
    local view_start = PakettiPPWV_view_start_line
    local view_end = math.min(num_lines, view_start + win - 1)
    local lpb = song.transport.lpb
    local pixels_per_line = (not is_vertical) and (W / win) or (H / win)

    -- Grid
    if pixels_per_line >= 6 then
      for line = view_start, view_end do
        local pos = not is_vertical and PakettiPPWV_LineDelayToX(line,0,num_lines) or PakettiPPWV_MapTimeToY(line, num_lines, H)
        if ((line-1) % lpb) == 0 then ctx.stroke_color = {70,70,100,220}; ctx.line_width = 2 else ctx.stroke_color = {40,40,60,140}; ctx.line_width = 1 end
        ctx:begin_path(); if not is_vertical then ctx:move_to(pos, 0); ctx:line_to(pos, H) else ctx:move_to(0, pos); ctx:line_to(W, pos) end; ctx:stroke()
      end
    else
      ctx.stroke_color = {50,50,70,255}; ctx.line_width = 1
      for line = view_start, view_end do
        if ((line-1) % lpb) == 0 then
          local pos = not is_vertical and PakettiPPWV_LineDelayToX(line,0,num_lines) or PakettiPPWV_MapTimeToY(line, num_lines, H)
          ctx:begin_path(); if not is_vertical then ctx:move_to(pos, 0); ctx:line_to(pos, H) else ctx:move_to(0, pos); ctx:line_to(W, pos) end; ctx:stroke()
        end
      end
    end

    -- Label
    ctx.stroke_color = {255,255,255,255}
    PakettiPPWV_DrawTextShared(ctx, string.format("%02d: %s", track_index, song.tracks[track_index].name or "Track"), 6, 4, 8)

    -- Waveforms
    for i = 1, #PakettiPPWV_events do
      local ev = PakettiPPWV_events[i]
      if ev.track_index == track_index then
        local cache
        if ev.sample_index and ev.instrument_index and song.instruments[ev.instrument_index] then
          local instr = song.instruments[ev.instrument_index]
          if instr.samples[ev.sample_index] and instr.samples[ev.sample_index].sample_buffer and instr.samples[ev.sample_index].sample_buffer.has_sample_data then
            cache = PakettiPPWV_GetCachedWaveform(ev.instrument_index, ev.sample_index)
          end
        end
        if cache then
          if ev.id == PakettiPPWV_selected_event_id or (PakettiPPWV_selected_ids and PakettiPPWV_selected_ids[ev.id]) then ctx.stroke_color = {255,200,120,255}; ctx.line_width = 2 else ctx.stroke_color = {100,255,150,200}; ctx.line_width = 1 end
          ctx:begin_path()
          local lane_mid = H/2
          if not is_vertical then
            local x1 = PakettiPPWV_LineDelayToX(ev.start_line, ev.start_delay or 0, num_lines)
            local x2 = PakettiPPWV_LineDelayToX(ev.end_line, 0, num_lines); if x2 < x1 + 1 then x2 = x1 + 1 end
            local width = x2 - x1
            local points = #cache
            for px = 0, math.floor(width) do
              local u = (px / math.max(1,width))
              local idx = math.floor(u * (points-1)) + 1; if idx<1 then idx=1 end; if idx>points then idx=points end
              local sample_v = cache[idx]
              local x = x1 + px
              local y = lane_mid - (sample_v * (H * 0.45))
              if px == 0 then ctx:move_to(x,y) else ctx:line_to(x,y) end
            end
          else
            local y1 = PakettiPPWV_MapTimeToY(ev.start_line, num_lines, H)
            local y2 = PakettiPPWV_MapTimeToY(ev.end_line, num_lines, H); if y2 < y1 + 1 then y2 = y1 + 1 end
            local height = y2 - y1
            local points = #cache
            for py = 0, math.floor(height) do
              local u = (py / math.max(1,height))
              local idx = math.floor(u * (points-1)) + 1; if idx<1 then idx=1 end; if idx>points then idx=points end
              local sample_v = cache[idx]
              local y = y1 + py
              local x = lane_mid - (sample_v * (H * 0.45))
              if py == 0 then ctx:move_to(x,y) else ctx:line_to(x,y) end
            end
          end
          ctx:stroke()
        end
      end
    end

    -- Playhead
    local tp = song.transport
    if tp.playing then
      local playpos = tp.playback_pos
      if playpos and playpos.sequence then
        local patt_at_seq = song.sequencer:pattern(playpos.sequence)
        if patt_at_seq == song.selected_pattern_index then
          local pos = not is_vertical and PakettiPPWV_LineDelayToX(playpos.line,0,num_lines) or PakettiPPWV_MapTimeToY(playpos.line, num_lines, H)
          ctx.stroke_color = {255,255,255,200}; ctx.line_width = 2; ctx:begin_path(); if not is_vertical then ctx:move_to(pos,0); ctx:line_to(pos,H) else ctx:move_to(0,pos); ctx:line_to(W,pos) end; ctx:stroke()
        end
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
    -- Hit test: compute line_pos from x (horizontal) or y (vertical)
    local win = PakettiPPWV_GetWindowLines(num_lines)
    local t = (not is_vertical) and ((x / PakettiPPWV_canvas_width) * win + (PakettiPPWV_view_start_line - 1)) or ((y / PakettiPPWV_canvas_height) * win + (PakettiPPWV_view_start_line - 1))
    local line_pos = math.floor(t) + 1
    for i = 1, #PakettiPPWV_events do
      local evn = PakettiPPWV_events[i]
      if evn.track_index == track_index and line_pos >= evn.start_line and line_pos < evn.end_line then
        PakettiPPWV_selected_event_id = evn.id; PakettiPPWV_is_dragging = true; PakettiPPWV_drag_start = {x=x,y=y,id=evn.id}
        song.selected_track_index = evn.track_index; song.selected_line_index = evn.start_line; song.selected_instrument_index = evn.instrument_index or song.selected_instrument_index
        PakettiPPWV_UpdateCanvasThrottled(); return
      end
    end
  elseif ev.type == "move" then
    if PakettiPPWV_is_dragging and PakettiPPWV_drag_start and PakettiPPWV_selected_event_id then
      local delta_px = (not is_vertical) and (x - PakettiPPWV_drag_start.x) or (y - PakettiPPWV_drag_start.y)
      local ticks_per_pixel = (num_lines * 256) / ((not is_vertical) and PakettiPPWV_canvas_width or PakettiPPWV_canvas_height)
      local delta_ticks = math.floor(delta_px * ticks_per_pixel)
      if math.abs(delta_ticks) >= 1 then
        for i = 1, #PakettiPPWV_events do
          local e = PakettiPPWV_events[i]
          if e.id == PakettiPPWV_selected_event_id then if PakettiPPWV_MoveEventByTicks(e, delta_ticks) then PakettiPPWV_drag_start.x = x; PakettiPPWV_drag_start.y = y; PakettiPPWV_RebuildEvents(); end; break end
        end
        PakettiPPWV_UpdateCanvasThrottled()
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
  while #PakettiPPWV_tracks_container.children > 0 do PakettiPPWV_tracks_container:remove_child(1) end
  PakettiPPWV_track_canvases = {}
  local song = renoise.song(); if not song then return end
  local lanes = song.sequencer_track_count
  local is_vertical = (PakettiPPWV_orientation == 2)
  local scale = (PakettiPPWV_vertical_scale_index == 2) and 2 or ((PakettiPPWV_vertical_scale_index == 3) and 3 or 1)
  if not is_vertical then
    local tracks_to_draw = PakettiPPWV_show_only_selected_track and 1 or lanes
    for i = 1, tracks_to_draw do
      local t = PakettiPPWV_show_only_selected_track and song.selected_track_index or i
      local c = PakettiPPWV_vb:canvas{ width = PakettiPPWV_canvas_width, height = (PakettiPPWV_show_only_selected_track and (PakettiPPWV_base_canvas_height*scale) or PakettiPPWV_lane_height), mode = "plain", render = PakettiPPWV_RenderTrackCanvas(t), mouse_handler = function(ev) PakettiPPWV_TrackMouse(t, ev) end, mouse_events = {"down","up","move"} }
      PakettiPPWV_tracks_container:add_child(c)
      PakettiPPWV_track_canvases[#PakettiPPWV_track_canvases+1] = c
    end
    -- Hide the legacy monolithic canvas
    if PakettiPPWV_canvas then PakettiPPWV_canvas.visible = false end
  else
    -- Vertical: one row of canvases spanning width
    local row = PakettiPPWV_vb:row{ spacing = 0 }
    local tracks_to_draw = PakettiPPWV_show_only_selected_track and 1 or lanes
    local each_w = math.max(60, math.floor(PakettiPPWV_canvas_width / tracks_to_draw))
    for i = 1, tracks_to_draw do
      local t = PakettiPPWV_show_only_selected_track and song.selected_track_index or i
      local c = PakettiPPWV_vb:canvas{ width = each_w, height = PakettiPPWV_base_canvas_height*scale, mode = "plain", render = PakettiPPWV_RenderTrackCanvas(t), mouse_handler = function(ev) PakettiPPWV_TrackMouse(t, ev) end, mouse_events = {"down","up","move"} }
      row:add_child(c)
      PakettiPPWV_track_canvases[#PakettiPPWV_track_canvases+1] = c
    end
    PakettiPPWV_tracks_container:add_child(row)
    if PakettiPPWV_canvas then PakettiPPWV_canvas.visible = false end
  end
  PakettiPPWV_UpdateScrollbars()
end

-- Adjust canvas size for orientation and vertical scaling
function PakettiPPWV_ApplyCanvasSizePolicy()
  local scale = (PakettiPPWV_vertical_scale_index == 2) and 2 or ((PakettiPPWV_vertical_scale_index == 3) and 3 or 1)
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
  PakettiPPWV_RebuildEvents()
  PakettiPPWV_UpdateScrollbars()
        PakettiPPWV_UpdateCanvasThrottled()
  renoise.app():show_status("PPWV: Refreshed (waveform cache cleared)")
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
  local acc = {tostring(patt.number_of_lines)}
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
    local t = song.tracks[track_index]
    if t and t.name then acc[#acc+1] = t.name end
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
function PakettiPPWV_GetCachedWaveform(instrument_index, sample_index)
  local song = renoise.song()
  if not song then return nil end
  local key = tostring(instrument_index) .. ":" .. tostring(sample_index)
  if PakettiPPWV_cached_waveforms[key] then
    return PakettiPPWV_cached_waveforms[key]
  end
  local instr = song.instruments[instrument_index]
  if not instr or not instr.samples[sample_index] then return nil end
  local sample = instr.samples[sample_index]
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then return nil end
  local buffer = sample.sample_buffer
  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  local target_points = 256 -- compact shape
  local cache = {}
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
              open_by_column[col] = {
                id = event_id,
                track_index = track_index,
                column_index = col,
                start_line = line_index,
                end_line = num_lines + 1, -- provisional until closed
                instrument_index = instrument_index,
                sample_index = sample_index,
                start_delay = nc.delay_value or 0
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

  PakettiPPWV_events = new_events
end

-- Convert line+delay to pixel X
function PakettiPPWV_LineDelayToX(line_index, delay_value, num_lines)
  local t = (line_index - 1) + (delay_value or 0) / 256
  return PakettiPPWV_MapTimeToX(t, num_lines)
end

-- Find event under mouse position
function PakettiPPWV_FindEventAt(x, y)
  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then return nil end
  local num_lines = patt.number_of_lines
  local lane_height = PakettiPPWV_show_only_selected_track and PakettiPPWV_canvas_height or PakettiPPWV_lane_height
  local track_lane = math.floor(y / lane_height) + 1
  if track_lane < 1 or track_lane > song.sequencer_track_count then return nil end
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local t = (x / PakettiPPWV_canvas_width) * win + (PakettiPPWV_view_start_line - 1)
  local line_pos = math.floor(t) + 1
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.track_index == track_lane then
      if line_pos >= ev.start_line and line_pos < ev.end_line then
        return ev
      end
    end
  end
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
  local song2 = renoise.song()
  if song2 and song2.tracks[ev.track_index] and song2.tracks[ev.track_index].delay_column_visible ~= nil then
    song2.tracks[ev.track_index].delay_column_visible = true
  end
  -- Update selection id and keep selection mapping
  local old_id = ev.id
  ev.start_line = dst_line
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

-- Keyboard-driven nudges
function PakettiPPWV_NudgeSelectedTicks(delta_ticks)
  if not PakettiPPWV_selected_event_id then return end
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.id == PakettiPPWV_selected_event_id then
      if PakettiPPWV_MoveEventByTicks(ev, delta_ticks) then
        PakettiPPWV_RebuildEvents()
        PakettiPPWV_UpdateCanvasThrottled()
      end
      break
    end
  end
end

-- Nudge multiple selected events on the same track
function PakettiPPWV_NudgeMultipleOnSameTrack(delta_ticks)
  if not PakettiPPWV_selected_event_id then return end
  if #PakettiPPWV_selected_ids == 0 then return end
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
  -- Apply move in event order (to reduce collisions)
  local moved = false
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if ev.track_index == anchor_track and PakettiPPWV_selected_ids[ev.id] then
      if PakettiPPWV_MoveEventByTicks(ev, delta_ticks) then
        moved = true
      end
    end
  end
  if moved then
    PakettiPPWV_RebuildEvents()
    -- Keep selection by reselecting items that moved: reselect by same track and approximate time window
    local new_selected = {}
    for i = 1, #PakettiPPWV_events do
      local e = PakettiPPWV_events[i]
      -- Heuristic: if original id existed, prefer same id; otherwise preserve anchor
      if PakettiPPWV_selected_ids and PakettiPPWV_selected_ids[e.id] then
        new_selected[e.id] = true
      end
    end
    PakettiPPWV_selected_ids = new_selected
    PakettiPPWV_UpdateCanvasThrottled()
  end
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
  -- Debug
  -- print("PPWV KEY:", name, mods)
  if mods == "" then
    if name == "left" then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(-1)
      else
        PakettiPPWV_NudgeSelectedTicks(-1)
      end
      return nil
    elseif name == "right" then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(1)
      else
        PakettiPPWV_NudgeSelectedTicks(1)
      end
      return nil
    elseif name == "up" and PakettiPPWV_orientation == 2 then
      -- Vertical nudge: up/down
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
        PakettiPPWV_NudgeMultipleOnSameTrack(-1)
      else
        PakettiPPWV_NudgeSelectedTicks(-1)
      end
      return nil
    elseif name == "down" and PakettiPPWV_orientation == 2 then
      if PakettiPPWV_multi_select_mode and #PakettiPPWV_events > 0 and #PakettiPPWV_selected_ids > 0 then
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
    end
  elseif mods == "shift" then
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
  -- Fallback to global keyhandler for closing, etc.
  return my_keyhandler_func(dialog, key)
end

-- Render canvas
function PakettiPPWV_RenderCanvas(ctx)
  local song, patt = PakettiPPWV_GetSongAndPattern()
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
  -- If only selected track: use full canvas height as one lane
  local lane_height = PakettiPPWV_show_only_selected_track and PakettiPPWV_canvas_height or PakettiPPWV_lane_height
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

  -- Grid by LPB and per-row when zoomed in
  local lpb = song.transport.lpb
  local win = PakettiPPWV_GetWindowLines(num_lines)
  local view_start = PakettiPPWV_view_start_line
  local view_end = math.min(num_lines, view_start + win - 1)
  local pixels_per_line = W / win
  if pixels_per_line >= 6 then
    -- Draw every row in faint color, highlight beats
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
  else
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

  -- Lane separators
  ctx.stroke_color = {60,60,80,255}
  for lane = 1, lanes_to_draw - 1 do
    local y = lane * lane_height
    draw_line(0, y, W, y)
  end

  -- Track labels for each lane
  for lane = 1, lanes_to_draw do
    local track_index = PakettiPPWV_show_only_selected_track and selected_track or lane
    local track = song.tracks[track_index]
    local lane_top = (lane - 1) * lane_height
    local idx_text = string.format("%02d", lane)
    local name_text = track and track.name or "Track"
    local label = idx_text .. ": " .. name_text
    ctx.stroke_color = {255,255,255,255}
    ctx.line_width = 1
    PakettiPPWV_DrawText(ctx, label, 6, lane_top + 4, 8)
  end

  -- Draw events as waveforms
  for i = 1, #PakettiPPWV_events do
    local ev = PakettiPPWV_events[i]
    if PakettiPPWV_show_only_selected_track and ev.track_index ~= selected_track then
      goto continue_event
    end
    local lane_idx = PakettiPPWV_show_only_selected_track and 1 or ev.track_index
    local lane_top = (lane_idx - 1) * lane_height
    local lane_mid = lane_top + lane_height / 2
    local x1 = PakettiPPWV_LineDelayToX(ev.start_line, ev.start_delay or 0, num_lines)
    local x2 = PakettiPPWV_LineDelayToX(ev.end_line, 0, num_lines)
    if x2 < x1 + 1 then x2 = x1 + 1 end
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
      local width = x2 - x1
      local points = #cache
      for px = 0, math.floor(width) do
        local u = (px / math.max(1, width))
        local idx = math.floor(u * (points - 1)) + 1
        if idx < 1 then idx = 1 end
        if idx > points then idx = points end
        local sample_v = cache[idx]
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
      if PakettiPPWV_show_labels then
        local instr = song.instruments[ev.instrument_index]
        local sample = instr and instr.samples and instr.samples[ev.sample_index]
        local instr_num = string.format("%02d", ev.instrument_index)
        local sample_name = sample and (sample.name ~= "" and sample.name or ("Sample " .. tostring(ev.sample_index))) or "Sample"
        -- Attempt to read note from start line/column for clarity
        local note_txt = ""
        local ptrack = patt:track(ev.track_index)
        local ln = ptrack:line(ev.start_line)
        if ln and ln.note_columns and ln.note_columns[ev.column_index] then
          local nc = ln.note_columns[ev.column_index]
          if not nc.is_empty and nc.note_value and nc.note_value <= 119 then
            -- Convert to simple C/D/E form
            local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
            local oct = math.floor(nc.note_value/12)
            local n = names[(nc.note_value%12)+1] .. tostring(oct)
            note_txt = n
          end
        end
        local label = instr_num .. " " .. sample_name
        if note_txt ~= "" then label = label .. " (" .. note_txt .. ")" end
        ctx.stroke_color = {220,220,220,255}
        ctx.line_width = 1
        if not is_vertical then
          PakettiPPWV_DrawText(ctx, label, x1 + 2, lane_top + 2, 7)
        else
          PakettiPPWV_DrawText(ctx, label, lane_top + 2, x1 + 2, 7)
        end
      end
    end
    ::continue_event::
  end

  -- Playback cursor
  local tp = song.transport
  if tp.playing then
    local playpos = tp.playback_pos
    if playpos and playpos.sequence then
      local patt_at_seq = song.sequencer:pattern(playpos.sequence)
      if patt_at_seq == song.selected_pattern_index then
        local x = PakettiPPWV_LineDelayToX(playpos.line, 0, num_lines)
        ctx.stroke_color = {255,255,255,200}
        ctx.line_width = 2
        draw_line(x, 0, x, H)
      end
    end
  end
end

-- Mouse handler
PakettiPPWV_is_dragging = false
PakettiPPWV_drag_start = nil

function PakettiPPWV_MouseHandler(ev)
  if ev.type == "down" and ev.button == "left" then
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
      -- Move pattern cursor to event start
      song.selected_line_index = evhit.start_line
      -- Ensure delay column visible
      local trk = song.tracks[evhit.track_index]
      if trk and trk.delay_column_visible ~= nil then trk.delay_column_visible = true end

      if is_double then
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      else
        -- Selection logic: support multi-select on same track when multi mode enabled and shift key held
        local key_shift = false -- mouse event doesn't carry modifiers; rely on multi-select toggle
        if PakettiPPWV_multi_select_mode or PakettiPPWV_select_same_enabled then
          -- Initialize selection set if empty
          if not PakettiPPWV_selected_ids then PakettiPPWV_selected_ids = {} end
          if PakettiPPWV_select_same_enabled then
            -- Auto-select all on same track with same instrument/sample
            PakettiPPWV_selected_ids = {}
            PakettiPPWV_selected_event_id = evhit.id
            for i = 1, #PakettiPPWV_events do
              local e = PakettiPPWV_events[i]
              if e.track_index == evhit.track_index and e.instrument_index == evhit.instrument_index and e.sample_index == evhit.sample_index then
                PakettiPPWV_selected_ids[e.id] = true
              end
            end
          else
            -- Manual multi toggle within the same track
            if not PakettiPPWV_selected_event_id then
              PakettiPPWV_selected_event_id = evhit.id
              PakettiPPWV_selected_ids[evhit.id] = true
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
              else
                PakettiPPWV_selected_ids = {}
                PakettiPPWV_selected_event_id = evhit.id
                PakettiPPWV_selected_ids[evhit.id] = true
              end
            end
          end
        else
          PakettiPPWV_selected_ids = {}
          PakettiPPWV_selected_event_id = evhit.id
        end

        PakettiPPWV_is_dragging = true
        PakettiPPWV_drag_start = {x = ev.position.x, y = ev.position.y, id = evhit.id}
        print(string.format("-- Paketti PPWV: Selected %s", evhit.id))
        PakettiPPWV_UpdateCanvasThrottled()
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
              local applied = PakettiPPWV_MoveEventByTicks(e, delta_ticks)
              if applied then
                PakettiPPWV_drag_start.x = ev.position.x
                PakettiPPWV_RebuildEvents()
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
  end
end

-- Timer callback
function PakettiPPWV_TimerTick()
  if not PakettiPPWV_dialog or not PakettiPPWV_dialog.visible then return end
  local hash = PakettiPPWV_BuildPatternHash()
  if hash ~= PakettiPPWV_last_content_hash then
    PakettiPPWV_last_content_hash = hash
    PakettiPPWV_RebuildEvents()
    PakettiPPWV_UpdateCanvasThrottled()
  else
    local song = renoise.song()
    if song and song.transport.playing then
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
  PakettiPPWV_dialog = nil
  PakettiPPWV_vb = nil
  PakettiPPWV_canvas = nil
  PakettiPPWV_selected_event_id = nil
  PakettiPPWV_cached_waveforms = {}
  print("-- Paketti PPWV: Cleaned up")
end

-- Build dialog content for current orientation
function PakettiPPWV_BuildContent()
  local header = PakettiPPWV_vb:row{
    spacing = 10,
    PakettiPPWV_vb:switch{
      id = "ppwv_zoom_switch",
      items = {"Full","1/2","1/4","1/8"},
      width = 300,
      value = PakettiPPWV_zoom_index,
      notifier = function(val) PakettiPPWV_SetZoomIndex(val) end
    },
    PakettiPPWV_vb:switch{
      id = "ppwv_orient_switch",
      items = {"Horizontal","Vertical"},
      width = 200,
      value = PakettiPPWV_orientation,
      notifier = function(val)
        PakettiPPWV_orientation = val
        PakettiPPWV_ReopenDialog()
      end
    },
    PakettiPPWV_vb:text{ text = "Scale:" },
    PakettiPPWV_vb:switch{
      id = "ppwv_vscale_switch_top",
      items = {"1x","2x","3x"},
      width = 180,
      value = PakettiPPWV_vertical_scale_index,
      notifier = function(val)
        PakettiPPWV_vertical_scale_index = val
        PakettiPPWV_ApplyCanvasSizePolicy()
        if PakettiPPWV_vb and PakettiPPWV_vb.views and PakettiPPWV_vb.views.ppwv_vscale_switch then
          PakettiPPWV_vb.views.ppwv_vscale_switch.value = val
        end
        PakettiPPWV_UpdateCanvasThrottled()
      end
    },
    PakettiPPWV_vb:checkbox{ id = "ppwv_show_labels_cb", value = PakettiPPWV_show_labels, notifier = function(v) PakettiPPWV_show_labels = v; PakettiPPWV_UpdateCanvasThrottled() end },
    PakettiPPWV_vb:text{ text = "Show instrument/sample/note labels" },
    PakettiPPWV_vb:checkbox{ id = "ppwv_multi_cb", value = PakettiPPWV_multi_select_mode, notifier = function(v) PakettiPPWV_multi_select_mode = v; if not v then PakettiPPWV_selected_ids = {} end; PakettiPPWV_UpdateCanvasThrottled() end },
    PakettiPPWV_vb:text{ text = "Multi-select (same track)" },
    PakettiPPWV_vb:checkbox{ id = "ppwv_select_same_cb", value = PakettiPPWV_select_same_enabled, notifier = function(v) PakettiPPWV_select_same_enabled = v end },
    PakettiPPWV_vb:text{ text = "Select the same (track+instrument+sample)" },
    PakettiPPWV_vb:checkbox{ id = "ppwv_only_selected_cb", value = PakettiPPWV_show_only_selected_track, notifier = function(v) PakettiPPWV_show_only_selected_track = v; PakettiPPWV_ReopenDialog() end },
    PakettiPPWV_vb:text{ text = "Only selected track (full height)" },
    PakettiPPWV_vb:button{ id = "ppwv_refresh_button", text = "Refresh", width = 80, notifier = function() PakettiPlayerProWaveformViewerRefresh() end }
  }

  if PakettiPPWV_orientation == 2 then
    -- Vertical: only vertical scrollbar
    local row_tracks = PakettiPPWV_vb:row{
      spacing = 0,
      PakettiPPWV_vb:column{ id = "ppwv_tracks_container", spacing = 0 },
      PakettiPPWV_vb:scrollbar{ id = "ppwv_vscrollbar", min = 1, max = 2, value = 1, step = 1, pagestep = 1, autohide = false, notifier = function(val) PakettiPPWV_view_start_line = val; PakettiPPWV_UpdateScrollbars(); PakettiPPWV_UpdateCanvasThrottled() end }
    }
    return PakettiPPWV_vb:column{
      margin = 10, spacing = 6,
      PakettiPPWV_vb:text{ text = "PlayerPro Waveform Viewer (SkunkWorks)", font = "bold", width = PakettiPPWV_canvas_width },
      header,
      row_tracks
    }
  else
    -- Horizontal: only horizontal scrollbar
    local tracks_col = PakettiPPWV_vb:column{ id = "ppwv_tracks_container", spacing = 0 }
    local bottom_row = PakettiPPWV_vb:row{
      PakettiPPWV_vb:text{ text = "Scroll:" }, PakettiPPWV_vb:space{ width = 10 },
      PakettiPPWV_vb:scrollbar{ id = "ppwv_scrollbar", min = 1, max = 2, value = 1, step = 1, pagestep = 1, autohide = false, notifier = function(val) PakettiPPWV_view_start_line = val; PakettiPPWV_UpdateScrollbars(); PakettiPPWV_UpdateCanvasThrottled() end },
      PakettiPPWV_vb:text{ text = "Scale:" },
      PakettiPPWV_vb:switch{ id = "ppwv_vscale_switch", items = {"1x","2x","3x"}, width = 180, value = PakettiPPWV_vertical_scale_index, notifier = function(val) PakettiPPWV_vertical_scale_index = val; if PakettiPPWV_vb.views.ppwv_vscale_switch_top then PakettiPPWV_vb.views.ppwv_vscale_switch_top.value = val end; PakettiPPWV_ApplyCanvasSizePolicy(); PakettiPPWV_UpdateCanvasThrottled() end }
    }
    return PakettiPPWV_vb:column{
      margin = 10, spacing = 6,
      PakettiPPWV_vb:text{ text = "PlayerPro Waveform Viewer (SkunkWorks)", font = "bold", width = PakettiPPWV_canvas_width },
      header,
      tracks_col,
      bottom_row
    }
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
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  PakettiPPWV_RebuildEvents(); PakettiPPWV_UpdateScrollbars(); PakettiPPWV_RebuildTrackCanvases(); PakettiPPWV_UpdateCanvasThrottled()
  if not PakettiPPWV_timer_running then renoise.tool():add_timer(PakettiPPWV_TimerTick, PakettiPPWV_timer_interval_ms); PakettiPPWV_timer_running = true end
  cleanup_observers = PakettiPPWV_Cleanup
end

-- Open dialog
function PakettiPlayerProWaveformViewerShowDialog()
  if PakettiPPWV_dialog and PakettiPPWV_dialog.visible then
    PakettiPPWV_Cleanup()
    PakettiPPWV_dialog:close()
    return
  end

  local song, patt = PakettiPPWV_GetSongAndPattern()
  if not song or not patt then
    renoise.app():show_status("Paketti PPWV: No song/pattern available")
    return
  end

  local lanes = song.sequencer_track_count
  PakettiPPWV_canvas_height = math.max(200, lanes * PakettiPPWV_lane_height)

  PakettiPPWV_ReopenDialog()
  print("-- Paketti PPWV: Dialog opened")
end

-- Public helpers for keybindings
function PakettiPlayerProWaveformViewerNudgeLeftTick()
  PakettiPPWV_NudgeSelectedTicks(-1)
end

function PakettiPlayerProWaveformViewerNudgeRightTick()
  PakettiPPWV_NudgeSelectedTicks(1)
end

function PakettiPlayerProWaveformViewerNudgeLeftLine()
  PakettiPPWV_NudgeSelectedTicks(-256)
end

function PakettiPlayerProWaveformViewerNudgeRightLine()
  PakettiPPWV_NudgeSelectedTicks(256)
end

function PakettiPlayerProWaveformViewerSnapToRow()
  PakettiPPWV_SnapSelectedToNearestRow()
end

function PakettiPlayerProWaveformViewerSelectPrev()
  PakettiPPWV_SelectAdjacentEvent(-1)
end

function PakettiPlayerProWaveformViewerSelectNext()
  PakettiPPWV_SelectAdjacentEvent(1)
end

-- Menu entries
renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Paketti:PlayerPro:Waveform Viewer (SkunkWorks)", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end }
renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Waveform Viewer (SkunkWorks)", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}
renoise.tool():add_menu_entry{ name = "Pattern Editor:Paketti:PlayerPro:Waveform Viewer (SkunkWorks)", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}

-- Keybindings
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Open Viewer", invoke = function() PakettiPlayerProWaveformViewerShowDialog() end}
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Left (Tick)", invoke = PakettiPlayerProWaveformViewerNudgeLeftTick }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Right (Tick)", invoke = PakettiPlayerProWaveformViewerNudgeRightTick }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Left (Line)", invoke = PakettiPlayerProWaveformViewerNudgeLeftLine }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Nudge Right (Line)", invoke = PakettiPlayerProWaveformViewerNudgeRightLine }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Snap Selected To Row", invoke = PakettiPlayerProWaveformViewerSnapToRow }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Select Previous Event", invoke = PakettiPlayerProWaveformViewerSelectPrev }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Select Next Event", invoke = PakettiPlayerProWaveformViewerSelectNext }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:PlayerPro Waveform Viewer Refresh", invoke = PakettiPlayerProWaveformViewerRefresh }

-- MIDI mappings (basic triggers)
renoise.tool():add_midi_mapping{ name = "Paketti:PlayerPro Waveform Viewer Open Viewer", invoke = function(message) if message:is_trigger() then PakettiPlayerProWaveformViewerShowDialog() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:PlayerPro Waveform Viewer Nudge Left (Tick)", invoke = function(message) if message:is_trigger() then PakettiPlayerProWaveformViewerNudgeLeftTick() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:PlayerPro Waveform Viewer Nudge Right (Tick)", invoke = function(message) if message:is_trigger() then PakettiPlayerProWaveformViewerNudgeRightTick() end end }


