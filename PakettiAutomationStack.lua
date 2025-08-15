-- PakettiAutomationStack.lua
-- Visualize all automation envelopes on the selected track within the selected pattern
-- Requirements honored:
-- - Lua 5.1 only
-- - All functions are GLOBAL and defined before first use
-- - Uses my_keyhandler_func from main.lua
-- - After dialog opens, reactivate middle frame to pass keys back to Renoise
-- - Stable ViewBuilder layout (rebuild content instead of toggling visibility)
-- - Uses shared PakettiCanvasFontDrawText when available

-- Global state
PakettiAutomationStack_dialog = nil
PakettiAutomationStack_vb = nil
PakettiAutomationStack_header_canvas = nil
PakettiAutomationStack_container = nil
PakettiAutomationStack_track_canvases = {}
PakettiAutomationStack_canvas_width = 1200
PakettiAutomationStack_lane_height = 80
PakettiAutomationStack_gutter_height = 18
PakettiAutomationStack_gutter_width = 28
PakettiAutomationStack_zoom_levels = {1.0, 0.5, 0.25, 0.125}
PakettiAutomationStack_zoom_index = 1
PakettiAutomationStack_view_start_line = 1
PakettiAutomationStack_scrollbar_view = nil
PakettiAutomationStack_timer_running = false
PakettiAutomationStack_timer_interval_ms = 120
PakettiAutomationStack_last_hash = ""
PakettiAutomationStack_automations = {}
PakettiAutomationStack_vertical_page_index = 1
PakettiAutomationStack_vertical_page_size = 8
PakettiAutomationStack_vscrollbar_view = nil
PakettiAutomationStack_min_redraw_ms = 60
PakettiAutomationStack_last_redraw_ms = 0
PakettiAutomationStack_is_drawing = false
PakettiAutomationStack_last_draw_line = -1
PakettiAutomationStack_last_draw_idx = -1
PakettiAutomationStack_last_draw_value = -1
PakettiAutomationStack_draw_playmode_index = 2 -- 1=Points,2=Lines,3=Curves

-- Utility draw text helper
function PakettiAutomationStack_DrawText(ctx, text, x, y, size)
  if type(PakettiCanvasFontDrawText) == "function" then
    PakettiCanvasFontDrawText(ctx, text, x, y, size)
  else
    -- Minimal fallback: small tick + no real text (keeps code safe if font not present)
    ctx.stroke_color = {200,200,200,255}
    ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x+6, y); ctx:stroke()
  end
end

-- Safe access helpers
function PakettiAutomationStack_GetSongPatternTrack()
  local song = renoise.song()
  if not song then return nil, nil, nil end
  local patt_idx = song.selected_pattern_index
  if patt_idx < 1 or patt_idx > #song.patterns then return song, nil, nil end
  local patt = song:pattern(patt_idx)
  local track_idx = song.selected_track_index
  if track_idx < 1 or track_idx > #song.tracks then return song, patt, nil end
  local ptrack = patt:track(track_idx)
  return song, patt, ptrack
end

-- Zoom and mapping
function PakettiAutomationStack_GetWindowLines(total_lines)
  local z = PakettiAutomationStack_zoom_levels[PakettiAutomationStack_zoom_index] or 1.0
  local win = math.max(1, math.floor(total_lines * z + 0.5))
  if win > total_lines then win = total_lines end
  return win
end

function PakettiAutomationStack_ClampView(total_lines)
  local win = PakettiAutomationStack_GetWindowLines(total_lines)
  local max_start = math.max(1, total_lines - win + 1)
  if PakettiAutomationStack_view_start_line < 1 then PakettiAutomationStack_view_start_line = 1 end
  if PakettiAutomationStack_view_start_line > max_start then PakettiAutomationStack_view_start_line = max_start end
end

function PakettiAutomationStack_MapTimeToX(t, total_lines)
  local win = PakettiAutomationStack_GetWindowLines(total_lines)
  local view_start_t = (PakettiAutomationStack_view_start_line - 1)
  local x = ((t - view_start_t) / win) * PakettiAutomationStack_canvas_width
  return x
end

function PakettiAutomationStack_LineToX(line_index, total_lines)
  return PakettiAutomationStack_MapTimeToX((line_index - 1), total_lines)
end

-- Inverse mapping: canvas x to pattern line
function PakettiAutomationStack_XToLine(x, total_lines)
  local win = PakettiAutomationStack_GetWindowLines(total_lines)
  local t = (x / PakettiAutomationStack_canvas_width) * win + (PakettiAutomationStack_view_start_line - 1)
  local line = math.floor(t) + 1
  if line < 1 then line = 1 end
  if line > total_lines then line = total_lines end
  return line
end

function PakettiAutomationStack_UpdateScrollbars()
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt then return end
  local num_lines = patt.number_of_lines
  PakettiAutomationStack_ClampView(num_lines)
  if PakettiAutomationStack_scrollbar_view then
    local win = PakettiAutomationStack_GetWindowLines(num_lines)
    PakettiAutomationStack_scrollbar_view.min = 1
    PakettiAutomationStack_scrollbar_view.max = num_lines + 1
    PakettiAutomationStack_scrollbar_view.pagestep = win
    PakettiAutomationStack_scrollbar_view.value = PakettiAutomationStack_view_start_line
  end
end

function PakettiAutomationStack_SetZoomIndex(idx)
  PakettiAutomationStack_zoom_index = math.max(1, math.min(#PakettiAutomationStack_zoom_levels, idx))
  PakettiAutomationStack_UpdateScrollbars()
  PakettiAutomationStack_RequestUpdate()
end

-- Hash builder for quick change detection
function PakettiAutomationStack_BuildAutomationHash()
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt or not ptrack then return "" end
  local acc = {tostring(patt.number_of_lines), tostring(song.selected_track_index)}
  local track = song.tracks[song.selected_track_index]
  if not track then return table.concat(acc, ":") end
  for d = 1, #track.devices do
    local dev = track.devices[d]
    for pi = 1, #dev.parameters do
      local param = dev.parameters[pi]
      if param.is_automatable then
        local a = ptrack:find_automation(param)
        if a then
          local ok1, pm = pcall(function() return a.playmode end)
          acc[#acc+1] = tostring(pm or "?")
          acc[#acc+1] = tostring(param.name or "?")
          local points = a.points
          if points then
            acc[#acc+1] = tostring(#points)
            local sumt = 0; local sumv = 0
            for j = 1, #points do
              local p = points[j]
              sumt = sumt + (p.time or 0)
              sumv = sumv + math.floor(((p.value or 0)*1000)+0.5)
            end
            acc[#acc+1] = tostring(sumt)
            acc[#acc+1] = tostring(sumv)
          end
        end
      end
    end
  end
  return table.concat(acc, ":")
end

-- Rebuild automation list
function PakettiAutomationStack_RebuildAutomations()
  PakettiAutomationStack_automations = {}
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt or not ptrack then return end
  local track = song.tracks[song.selected_track_index]
  if not track then return end
  for d = 1, #track.devices do
    local dev = track.devices[d]
    for pi = 1, #dev.parameters do
      local param = dev.parameters[pi]
      if param.is_automatable then
        local a = ptrack:find_automation(param)
        if a then
          local entry = {
            automation = a,
            parameter = param,
            name = param.name or "Parameter",
            device_name = dev.display_name or "Device",
            playmode = a.playmode
          }
          PakettiAutomationStack_automations[#PakettiAutomationStack_automations+1] = entry
        end
      end
    end
  end
end

-- Redraw throttling
function PakettiAutomationStack_RequestUpdate()
  local now_ms = os.clock() * 1000
  if (now_ms - PakettiAutomationStack_last_redraw_ms) >= PakettiAutomationStack_min_redraw_ms then
    if PakettiAutomationStack_header_canvas and PakettiAutomationStack_header_canvas.visible then PakettiAutomationStack_header_canvas:update() end
    if PakettiAutomationStack_track_canvases and #PakettiAutomationStack_track_canvases > 0 then
      for i = 1, #PakettiAutomationStack_track_canvases do
        local c = PakettiAutomationStack_track_canvases[i]
        if c and c.visible then c:update() end
      end
    end
    PakettiAutomationStack_last_redraw_ms = now_ms
  end
end

-- Rendering helpers
function PakettiAutomationStack_DrawGrid(ctx, W, H, num_lines, lpb)
  local win = PakettiAutomationStack_GetWindowLines(num_lines)
  local pixels_per_line = W / win
  -- background
  ctx:set_fill_linear_gradient(0, 0, 0, H)
  ctx:add_fill_color_stop(0, {25,25,35,255})
  ctx:add_fill_color_stop(1, {15,15,25,255})
  ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
  -- gutters
  local gutter = PakettiAutomationStack_gutter_width
  ctx.fill_color = {18,18,24,255}; ctx:fill_rect(0, 0, gutter, H)
  ctx.fill_color = {14,14,20,255}; ctx:fill_rect(W - gutter, 0, gutter, H)
  -- grid
  if pixels_per_line >= 6 then
    for line = PakettiAutomationStack_view_start_line, math.min(num_lines, PakettiAutomationStack_view_start_line + win - 1) do
      local x = PakettiAutomationStack_LineToX(line, num_lines)
      if ((line-1) % lpb) == 0 then ctx.stroke_color = {70,70,100,220}; ctx.line_width = 2 else ctx.stroke_color = {40,40,60,140}; ctx.line_width = 1 end
      ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
    end
  else
    ctx.line_width = 1
    for line = PakettiAutomationStack_view_start_line, math.min(num_lines, PakettiAutomationStack_view_start_line + win - 1) do
      if ((line-1) % lpb) == 0 then
        local x = PakettiAutomationStack_LineToX(line, num_lines)
        ctx.stroke_color = {50,50,70,255}
        ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
      end
    end
  end
end

function PakettiAutomationStack_ValueToY(v, H)
  if v < 0 then v = 0 end
  if v > 1 then v = 1 end
  return (H - (v * H))
end

function PakettiAutomationStack_YToValue(y, H)
  local v = 1.0 - (y / H)
  if v < 0 then v = 0 end
  if v > 1 then v = 1 end
  return v
end

function PakettiAutomationStack_PlaymodeForIndex(idx)
  if idx == 1 then return renoise.PatternTrackAutomation.PLAYMODE_POINTS end
  if idx == 3 then return renoise.PatternTrackAutomation.PLAYMODE_CURVES end
  return renoise.PatternTrackAutomation.PLAYMODE_LINES
end

-- Write or remove point for a lane
function PakettiAutomationStack_WritePoint(automation_index, line, value, remove)
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt or not ptrack then return end
  local entry = PakettiAutomationStack_automations[automation_index]; if not entry then return end
  local a = entry.automation
  if not a then return end
  -- Ensure envelope playmode follows current draw mode
  local desired = PakettiAutomationStack_PlaymodeForIndex(PakettiAutomationStack_draw_playmode_index)
  if a.playmode ~= desired then a.playmode = desired end
  if remove then
    if a:has_point_at(line) then a:remove_point_at(line) end
  else
    -- Normalize already 0..1
    if a:has_point_at(line) then a:remove_point_at(line) end
    a:add_point_at(line, value)
  end
end

-- Mouse handler per lane
function PakettiAutomationStack_LaneMouse(automation_index, ev, lane_h)
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
  local num_lines = patt.number_of_lines
  local x = ev.position.x
  local y = ev.position.y
  local line = PakettiAutomationStack_XToLine(x, num_lines)
  local value = PakettiAutomationStack_YToValue(y, lane_h)
  local mods = tostring(ev.modifiers or "")
  local is_alt = (string.find(mods:lower(), "alt", 1, true) ~= nil) or (string.find(mods:lower(), "option", 1, true) ~= nil)

  if ev.type == "down" and ev.button == "left" then
    PakettiAutomationStack_is_drawing = true
    PakettiAutomationStack_last_draw_line = line
    PakettiAutomationStack_last_draw_idx = automation_index
    PakettiAutomationStack_last_draw_value = value
    PakettiAutomationStack_WritePoint(automation_index, line, value, is_alt)
    PakettiAutomationStack_RequestUpdate()
  elseif ev.type == "move" then
    if PakettiAutomationStack_is_drawing and PakettiAutomationStack_last_draw_idx == automation_index then
      if line ~= PakettiAutomationStack_last_draw_line or math.abs(value - PakettiAutomationStack_last_draw_value) >= 0.001 then
        -- Continuous draw: write point on the current line and interpolate if we skipped lines
        local start_l = PakettiAutomationStack_last_draw_line
        local end_l = line
        if start_l and end_l then
          local step = (end_l >= start_l) and 1 or -1
          local count = math.abs(end_l - start_l)
          if count <= 1 then
            PakettiAutomationStack_WritePoint(automation_index, line, value, is_alt)
          else
            -- interpolate values across lines
            for L = start_l, end_l, step do
              local t = (count > 0) and (math.abs(L - start_l) / count) or 1.0
              local v = PakettiAutomationStack_last_draw_value + (value - PakettiAutomationStack_last_draw_value) * t
              PakettiAutomationStack_WritePoint(automation_index, L, v, is_alt)
            end
          end
        end
        PakettiAutomationStack_last_draw_line = line
        PakettiAutomationStack_last_draw_value = value
        PakettiAutomationStack_RequestUpdate()
      end
    end
  elseif ev.type == "up" and ev.button == "left" then
    PakettiAutomationStack_is_drawing = false
    PakettiAutomationStack_last_draw_idx = -1
    PakettiAutomationStack_RequestUpdate()
  end
end

-- Render a single automation lane
function PakettiAutomationStack_RenderLaneCanvas(automation_index, canvas_w, canvas_h)
  return function(ctx)
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
    local W = canvas_w or PakettiAutomationStack_canvas_width
    local H = canvas_h or PakettiAutomationStack_lane_height
    ctx:clear_rect(0, 0, W, H)
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local lpb = song.transport.lpb

    PakettiAutomationStack_DrawGrid(ctx, W, H, num_lines, lpb)

    local entry = PakettiAutomationStack_automations[automation_index]
    if not entry or not entry.automation then return end

    -- Label
    local label = string.format("%s — %s", entry.device_name or "Device", entry.name or "Param")
    ctx.stroke_color = {255,255,255,255}
    PakettiAutomationStack_DrawText(ctx, label, PakettiAutomationStack_gutter_width + 4, 4, 8)

    local a = entry.automation
    local points = a.points or {}
    local mode = a.playmode or renoise.PatternTrackAutomation.PLAYMODE_POINTS
    local gutter = PakettiAutomationStack_gutter_width

    -- Draw zero-line reference
    ctx.stroke_color = {80,80,100,200}
    ctx.line_width = 1
    ctx:begin_path(); ctx:move_to(gutter, PakettiAutomationStack_ValueToY(0.5, H)); ctx:line_to(W - gutter, PakettiAutomationStack_ValueToY(0.5, H)); ctx:stroke()

    if #points == 0 then
      -- Nothing to draw
      return
    end

    if mode == renoise.PatternTrackAutomation.PLAYMODE_POINTS then
      -- Vertical bars with dots at values
      ctx.stroke_color = {100,255,150,220}
      ctx.line_width = 2
      for i = 1, #points do
        local p = points[i]
        local x = PakettiAutomationStack_MapTimeToX(p.time, num_lines)
        local y = PakettiAutomationStack_ValueToY(p.value, H)
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
        ctx:begin_path(); ctx:move_to(x, H-1); ctx:line_to(x, y); ctx:stroke()
        ctx.stroke_color = {180,240,255,255}
        ctx.line_width = 3
        ctx:begin_path(); ctx:move_to(x-1, y); ctx:line_to(x+1, y); ctx:stroke()
        ctx.stroke_color = {100,255,150,220}; ctx.line_width = 2
      end
    elseif mode == renoise.PatternTrackAutomation.PLAYMODE_LINES then
      -- Linear segments between points
      ctx.stroke_color = {100,255,150,220}
      ctx.line_width = 2
      ctx:begin_path()
      local p1 = points[1]
      local x1 = PakettiAutomationStack_MapTimeToX(p1.time, num_lines)
      local y1 = PakettiAutomationStack_ValueToY(p1.value, H)
      if x1 < gutter then x1 = gutter end
      if x1 > W - gutter then x1 = W - gutter end
      ctx:move_to(x1, y1)
      for i = 2, #points do
        local p = points[i]
        local x = PakettiAutomationStack_MapTimeToX(p.time, num_lines)
        local y = PakettiAutomationStack_ValueToY(p.value, H)
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
        ctx:line_to(x, y)
      end
      ctx:stroke()
    else
      -- Curves: smooth by Catmull-Rom / Hermite sampling between points
      ctx.stroke_color = {255,200,120,240}
      ctx.line_width = 2
      for seg = 1, (#points - 1) do
        local p0 = points[math.max(1, seg-1)]
        local p1c = points[seg]
        local p2 = points[seg+1]
        local p3 = points[math.min(#points, seg+2)]
        local x1 = PakettiAutomationStack_MapTimeToX(p1c.time, num_lines)
        local y1 = PakettiAutomationStack_ValueToY(p1c.value, H)
        local x2 = PakettiAutomationStack_MapTimeToX(p2.time, num_lines)
        local y2 = PakettiAutomationStack_ValueToY(p2.value, H)
        if x2 <= x1 then x2 = x1 + 1 end
        local steps = math.max(8, math.floor((x2 - x1) / 6))
        local function hermite(t, y_0, y_1, y_2, y_3)
          local m1 = 0.5 * (y_2 - y_0)
          local m2 = 0.5 * (y_3 - y_1)
          local t2 = t * t
          local t3 = t2 * t
          local h00 = 2*t3 - 3*t2 + 1
          local h10 = t3 - 2*t2 + t
          local h01 = -2*t3 + 3*t2
          local h11 = t3 - t2
          return h00*y_1 + h10*m1 + h01*y_2 + h11*m2
        end
        ctx:begin_path()
        for s = 0, steps do
          local t = s / steps
          local x = x1 + (x2 - x1) * t
          local y = hermite(t, PakettiAutomationStack_ValueToY(p0.value, H), y1, y2, PakettiAutomationStack_ValueToY(p3.value, H))
          if s == 0 then ctx:move_to(x, y) else ctx:line_to(x, y) end
        end
        ctx:stroke()
      end
    end
  end
end

-- Header canvas renderer (timeline + playhead) and click-to-jump
function PakettiAutomationStack_RenderHeaderCanvas(canvas_w, canvas_h)
  local function on_mouse(ev)
    if not ev or ev.type ~= "down" then return end
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
    local x = ev.position.x
    local num_lines = patt.number_of_lines
    local target_line = math.floor(((x / (canvas_w or PakettiAutomationStack_canvas_width)) * PakettiAutomationStack_GetWindowLines(num_lines)) + (PakettiAutomationStack_view_start_line - 1)) + 1
    if target_line < 1 then target_line = 1 end
    if target_line > num_lines then target_line = num_lines end
    song.selected_line_index = target_line
    song.transport:start_at{sequence = renoise.song().selected_sequence_index, line = target_line}
  end
  return function(ctx)
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
    local W = canvas_w or PakettiAutomationStack_canvas_width
    local H = canvas_h or (PakettiAutomationStack_gutter_height + 4)
    ctx:clear_rect(0, 0, W, H)
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local win = PakettiAutomationStack_GetWindowLines(num_lines)
    local view_start = PakettiAutomationStack_view_start_line
    local view_end = math.min(num_lines, view_start + win - 1)
    local lpb = song.transport.lpb
    local gutter = PakettiAutomationStack_gutter_width
    -- background and gutters
    ctx:set_fill_linear_gradient(0, 0, 0, H)
    ctx:add_fill_color_stop(0, {22,22,30,255})
    ctx:add_fill_color_stop(1, {12,12,20,255})
    ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
    ctx.fill_color = {18,18,24,255}; ctx:fill_rect(0, 0, gutter, H)
    ctx.fill_color = {14,14,20,255}; ctx:fill_rect(W - gutter, 0, gutter, H)
    -- ticks + labels
    local row_label_size = 7
    local step = (lpb >= 2) and lpb or 1
    for line = view_start, view_end, step do
      local x = PakettiAutomationStack_LineToX(line, num_lines)
      ctx.stroke_color = {90,90,120,255}
      ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
      local label = string.format("%02d", (line-1) % 100)
      PakettiAutomationStack_DrawText(ctx, label, x + 2, 2, row_label_size)
    end
    -- playhead
    local x_play = nil
    local play_line = nil
    if song.transport.playing then
      local pos = song.transport.playback_pos
      if pos and pos.sequence and pos.line and pos.sequence == renoise.song().selected_sequence_index then
        play_line = pos.line
      end
    else
      play_line = song.selected_line_index
    end
    if play_line then x_play = PakettiAutomationStack_LineToX(play_line, num_lines) end
    if x_play then
      ctx.stroke_color = {255,200,120,255}; ctx.line_width = 2
      ctx:begin_path(); ctx:move_to(x_play, 0); ctx:line_to(x_play, H); ctx:stroke()
    end
  end, on_mouse
end

-- Build canvases for current page of automations
function PakettiAutomationStack_RebuildCanvases()
  if not PakettiAutomationStack_container then return end
  -- Remove existing children
  if PakettiAutomationStack_container.views then
    while #PakettiAutomationStack_container.views > 0 do
      PakettiAutomationStack_container:remove_child(PakettiAutomationStack_container.views[1])
    end
  end
  PakettiAutomationStack_track_canvases = {}

  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
  local total = #PakettiAutomationStack_automations
  local start_idx = ((PakettiAutomationStack_vertical_page_index - 1) * PakettiAutomationStack_vertical_page_size) + 1
  if start_idx < 1 then start_idx = 1 end
  if start_idx > total then start_idx = math.max(1, total - PakettiAutomationStack_vertical_page_size + 1) end
  local end_idx = math.min(total, start_idx + PakettiAutomationStack_vertical_page_size - 1)

  for i = start_idx, end_idx do
    local cw = PakettiAutomationStack_canvas_width
    local ch = PakettiAutomationStack_lane_height
    local idx_for_canvas = i
    local c = PakettiAutomationStack_vb:canvas{
      width = cw,
      height = ch,
      mode = "plain",
      render = PakettiAutomationStack_RenderLaneCanvas(idx_for_canvas, cw, ch),
      mouse_events = {"down","up","move"},
      mouse_handler = function(ev) PakettiAutomationStack_LaneMouse(idx_for_canvas, ev, ch) end
    }
    PakettiAutomationStack_container:add_child(c)
    PakettiAutomationStack_track_canvases[#PakettiAutomationStack_track_canvases+1] = c
  end

  -- Update vertical scrollbar bounds
  if PakettiAutomationStack_vscrollbar_view then
    local pages = math.max(1, math.ceil(total / PakettiAutomationStack_vertical_page_size))
    PakettiAutomationStack_vscrollbar_view.min = 1
    PakettiAutomationStack_vscrollbar_view.max = math.max(2, pages)
    if PakettiAutomationStack_vertical_page_index > pages then PakettiAutomationStack_vertical_page_index = pages end
    PakettiAutomationStack_vscrollbar_view.value = PakettiAutomationStack_vertical_page_index
  end
end

-- Build the ViewBuilder content
function PakettiAutomationStack_BuildContent()
  local controls_row = PakettiAutomationStack_vb:row{
    PakettiAutomationStack_vb:switch{
      id = "pas_zoom_switch",
      items = {"Full","1/2","1/4","1/8"},
      width = 300,
      value = PakettiAutomationStack_zoom_index,
      notifier = function(val) PakettiAutomationStack_SetZoomIndex(val) end
    },
    PakettiAutomationStack_vb:text{ text = "Mode:" },
    PakettiAutomationStack_vb:switch{
      id = "pas_mode_switch",
      items = {"Points","Lines","Curves"},
      width = 300,
      value = PakettiAutomationStack_draw_playmode_index,
      notifier = function(val)
        PakettiAutomationStack_draw_playmode_index = val
        -- Apply immediately to visible envelopes
        for i = 1, #PakettiAutomationStack_automations do
          local e = PakettiAutomationStack_automations[i]
          if e and e.automation then e.automation.playmode = PakettiAutomationStack_PlaymodeForIndex(val) end
        end
        PakettiAutomationStack_RequestUpdate()
      end
    },
    PakettiAutomationStack_vb:text{ text = "Page:" },
    PakettiAutomationStack_vb:scrollbar{ id = "pas_vscroll", min = 1, max = 2, value = PakettiAutomationStack_vertical_page_index, step = 1, pagestep = 1, autohide = false, notifier = function(val)
      PakettiAutomationStack_vertical_page_index = val
      PakettiAutomationStack_RebuildCanvases()
      PakettiAutomationStack_RequestUpdate()
    end },
    PakettiAutomationStack_vb:button{ text = "Refresh", width = 80, notifier = function() PakettiAutomationStack_ForceRefresh() end }
  }

  local header_row = PakettiAutomationStack_vb:row{ spacing = 0, PakettiAutomationStack_vb:canvas{ id = "pas_header_canvas", width = PakettiAutomationStack_canvas_width, height = PakettiAutomationStack_gutter_height + 6, mode = "plain", mouse_events = {"down"}, mouse_handler = function(ev)
      local _render, on_mouse = PakettiAutomationStack_RenderHeaderCanvas(PakettiAutomationStack_canvas_width, PakettiAutomationStack_gutter_height + 6)
      if on_mouse then on_mouse(ev) end
    end, render = (function()
      local render_func = PakettiAutomationStack_RenderHeaderCanvas(PakettiAutomationStack_canvas_width, PakettiAutomationStack_gutter_height + 6)
      return render_func
    end)() } }

  local tracks_col = PakettiAutomationStack_vb:column{ id = "pas_tracks_container", spacing = 0 }
  local bottom_row = PakettiAutomationStack_vb:row{
    PakettiAutomationStack_vb:text{ text = "Scroll:" }, PakettiAutomationStack_vb:space{ width = 10 },
    PakettiAutomationStack_vb:scrollbar{ id = "pas_hscroll", min = 1, max = 2, value = 1, step = 1, pagestep = 1, autohide = false, notifier = function(val)
      PakettiAutomationStack_view_start_line = val
      PakettiAutomationStack_UpdateScrollbars()
      PakettiAutomationStack_RequestUpdate()
    end }
  }

  return PakettiAutomationStack_vb:column{ controls_row, header_row, tracks_col, bottom_row }
end

-- Reopen / build dialog
function PakettiAutomationStack_ReopenDialog()
  if PakettiAutomationStack_dialog and PakettiAutomationStack_dialog.visible then PakettiAutomationStack_dialog:close() end
  PakettiAutomationStack_vb = renoise.ViewBuilder()
  local content = PakettiAutomationStack_BuildContent()
  PakettiAutomationStack_dialog = renoise.app():show_custom_dialog("Paketti Automation Stack", content, my_keyhandler_func)
  PakettiAutomationStack_header_canvas = PakettiAutomationStack_vb.views.pas_header_canvas
  PakettiAutomationStack_scrollbar_view = PakettiAutomationStack_vb.views.pas_hscroll
  PakettiAutomationStack_vscrollbar_view = PakettiAutomationStack_vb.views.pas_vscroll
  PakettiAutomationStack_container = PakettiAutomationStack_vb.views.pas_tracks_container
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  PakettiAutomationStack_RebuildAutomations()
  PakettiAutomationStack_UpdateScrollbars()
  PakettiAutomationStack_RebuildCanvases()
  PakettiAutomationStack_RequestUpdate()
  if not PakettiAutomationStack_timer_running then renoise.tool():add_timer(PakettiAutomationStack_TimerTick, PakettiAutomationStack_timer_interval_ms); PakettiAutomationStack_timer_running = true end
end

-- Public entry
function PakettiAutomationStackShowDialog()
  if PakettiAutomationStack_dialog and PakettiAutomationStack_dialog.visible then
    PakettiAutomationStack_dialog:close()
    PakettiAutomationStack_Cleanup()
    return
  end
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt then
    renoise.app():show_status("Automation Stack: No song/pattern available")
    return
  end
  PakettiAutomationStack_ReopenDialog()
end

-- Force refresh from UI button
function PakettiAutomationStack_ForceRefresh()
  PakettiAutomationStack_RebuildAutomations()
  PakettiAutomationStack_UpdateScrollbars()
  PakettiAutomationStack_RebuildCanvases()
  PakettiAutomationStack_RequestUpdate()
  renoise.app():show_status("Automation Stack: Refreshed")
end

-- Timer: detect changes and update
function PakettiAutomationStack_TimerTick()
  if not PakettiAutomationStack_dialog or not PakettiAutomationStack_dialog.visible then return end
  local hash = PakettiAutomationStack_BuildAutomationHash()
  if hash ~= PakettiAutomationStack_last_hash then
    PakettiAutomationStack_last_hash = hash
    PakettiAutomationStack_RebuildAutomations()
    PakettiAutomationStack_RebuildCanvases()
    PakettiAutomationStack_RequestUpdate()
  else
    PakettiAutomationStack_RequestUpdate()
  end
end

-- Cleanup
function PakettiAutomationStack_Cleanup()
  if PakettiAutomationStack_timer_running then
    renoise.tool():remove_timer(PakettiAutomationStack_TimerTick)
    PakettiAutomationStack_timer_running = false
  end
  PakettiAutomationStack_dialog = nil
  PakettiAutomationStack_vb = nil
  PakettiAutomationStack_header_canvas = nil
  PakettiAutomationStack_container = nil
  PakettiAutomationStack_track_canvases = {}
  PakettiAutomationStack_scrollbar_view = nil
  PakettiAutomationStack_vscrollbar_view = nil
end

-- Menu + Keybinding entries
renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Automation Stack", invoke = function() PakettiAutomationStackShowDialog() end }
renoise.tool():add_menu_entry{ name = "Pattern Editor:Paketti:Automation:Automation Stack", invoke = function() PakettiAutomationStackShowDialog() end }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:Automation Stack...", invoke = function() PakettiAutomationStackShowDialog() end }



