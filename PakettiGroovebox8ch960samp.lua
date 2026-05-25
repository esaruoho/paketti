-- PakettiGroovebox8ch960samp.lua
-- Groovebox 8ch960samp (MK2) — canvas-rendered design prototype.
--
-- Visual scratchpad for the rethought 8120. No song integration yet:
-- everything you click here lives in module-local state. The point is
-- to nail the look and the feel of the canvas grid, the selection
-- model, the per-lane view modes, and the verb palette before wiring
-- to the EightOneTwenty data model.
--
-- Visual rules:
--   - 8 lanes, each lane is a horizontal strip of 16 (or 32) cells
--   - Quadrant backgrounds: cells 1-4 white, 5-8 black, 9-12 white, 13-16 black
--   - For 32 steps: same rule scaled to 8 quadrants of 4
--   - Active trigger draws inside the cell, contrast-inverted vs. quadrant
--   - Velocity = block height, probability = block opacity
--   - Roll count > 1 shown as a small number in cell corner
--   - Playhead = 2px amber border around the cell
--   - Selection = purple wash + 2px purple border
--
-- Interaction:
--   - View mode "triggers": click cell = toggle on/off
--   - View mode "velocity": drag inside cell = set velocity (height)
--   - View mode "probability": drag inside cell = set probability
--   - Click lane name to cycle view mode (T → V → P → T)
--   - Click + drag on cells = range/rectangle selection
--   - Alt+click = select the entire quadrant containing the cell
--   - Shift+click = extend selection to the cell (anchor stays put)
--   - Verb buttons act on the active selection

local vb = renoise.ViewBuilder()
local dialog = nil
local view = nil
local step_canvas = nil

-- ---------- model ----------

local NUM_LANES = 8
local MAX_STEPS = 16  -- toggleable to 32

-- 8ch960samp is a CANVAS-RENDERED ALTERNATE VIEW of 8120, not a separate
-- engine. Trigger state lives in 8120's rows[] table; we read it on every
-- repaint and write back through the same checkbox.value assignment 8120's
-- own dialog uses (which fires 8120's print_to_pattern notifier). Velocity,
-- probability, and roll_count are local-only for now (8120's data model
-- doesn't expose those concepts directly).
--
-- velocity[r][s] is initialised to 1.0 so cells render at full height when
-- the trigger is on. probability defaults to 1.0 (full alpha). roll_count
-- defaults to 1 (no badge).

local velocity, probability, roll_count, lane_view = {}, {}, {}, {}

local function ensure_local_state()
  for r = 1, NUM_LANES do
    velocity[r]    = velocity[r]    or {}
    probability[r] = probability[r] or {}
    roll_count[r]  = roll_count[r]  or {}
    for s = 1, 32 do
      if velocity[r][s]    == nil then velocity[r][s]    = 1.0 end
      if probability[r][s] == nil then probability[r][s] = 1.0 end
      if roll_count[r][s]  == nil then roll_count[r][s]  = 1   end
    end
    lane_view[r] = lane_view[r] or "triggers"
  end
end

-- ---------- 8120 read-through ----------

local function rows_table()
  return rawget(_G, "rows")  -- 8120's per-row state table
end

local function row_elements(r)
  local t = rows_table()
  return t and t[r] or nil
end

local function read_trigger(r, s)
  local re = row_elements(r)
  if re and re.checkboxes and re.checkboxes[s] then
    return re.checkboxes[s].value and true or false
  end
  return false
end

local function write_trigger(r, s, v)
  local re = row_elements(r)
  if re and re.checkboxes and re.checkboxes[s] then
    re.checkboxes[s].value = v and true or false
    -- 8120's own checkbox notifier writes to the pattern.
  end
end

local function read_lane_name(r)
  local song = renoise.song and renoise.song()
  if not song then return "—" end
  local instrument = song.instruments and song.instruments[r]
  if instrument and instrument.name and instrument.name ~= "" then
    return instrument.name
  end
  return "—"
end

local function read_lane_muted(r)
  local re = row_elements(r)
  if re and re.mute_checkbox then return re.mute_checkbox.value and true or false end
  local song = renoise.song and renoise.song()
  if not song then return false end
  local track = song.tracks and song.tracks[r]
  if track and track.mute_state then
    return track.mute_state == renoise.Track.MUTE_STATE_MUTED
       or  track.mute_state == renoise.Track.MUTE_STATE_OFF
  end
  return false
end

local function read_lane_soloed(r)
  local re = row_elements(r)
  if re and re.solo_checkbox then return re.solo_checkbox.value and true or false end
  return false
end

local function set_lane_muted(r, v)
  local re = row_elements(r)
  if re and re.mute_checkbox then
    re.mute_checkbox.value = v and true or false
  end
end

-- selection rectangle: {row1, step1, row2, step2} or nil
local selection = nil
local drag = nil          -- selection drag: {anchor_row, anchor_step}
local edit_drag = nil     -- velocity/probability drag: {row, step, mode}
local clipboard = nil     -- copy/paste buffer

local playhead_lane, playhead_step = 3, 7

-- ---------- canvas geometry ----------

local CANVAS_W = 960
-- LANE_H is the natural height of a single vb:row of buttons (M/S/R/T + index +
-- name on one line) — the side strip is built as exactly that one row, so the
-- canvas's per-lane band matches the strip pixel-for-pixel without padding
-- tricks. If you change side strip layout, change LANE_H to match.
local LANE_H   = 28
local CANVAS_H = NUM_LANES * LANE_H
local LANE_INSET_TOP = 2
local LANE_INNER_H   = LANE_H - 4

local function cell_w() return CANVAS_W / MAX_STEPS end

local function quadrant_is_dark(step)
  local q = math.floor((step - 1) / 4)
  return (q % 2) == 1
end

-- ---------- colors ----------

local function rgb(r,g,b,a) return {r,g,b,a or 255} end
local C = {
  bg            = rgb(0x1e,0x1e,0x22),
  quad_white    = rgb(0xe8,0xe8,0xec),
  quad_black    = rgb(0x18,0x18,0x1c),
  trig_on_white = rgb(0x18,0x18,0x1c),
  trig_on_black = rgb(0xe8,0xe8,0xec),
  cell_grid     = rgb(0x3a,0x3a,0x42),
  selection_fill= rgb(0xb0,0x60,0xd8, 170),
  selection_brd = rgb(0xc0,0x80,0xe8),
  playhead      = rgb(0xff,0xb0,0x40),
  lane_div      = rgb(0x4a,0x4a,0x54),
  muted_overlay = rgb(0x18,0x18,0x1c, 130),
  velocity_band = rgb(0x60,0xa0,0xd0, 90),
  prob_band     = rgb(0xd0,0xa0,0x60, 90),
  step_label_l  = rgb(0x6a,0x6a,0x70),
  step_label_d  = rgb(0x9a,0x9a,0xa6),
  playhead_label= rgb(0xff,0xd0,0x80),
  view_badge    = rgb(0x40,0x60,0x90),
}

local function fill_rect(ctx, x, y, w, h, color)
  ctx.fill_color = color
  ctx:fill_rect(x, y, w, h)
end

local function stroke_rect(ctx, x, y, w, h, color, width)
  ctx.stroke_color = color
  ctx.line_width = width or 1
  ctx:begin_path()
  ctx:rect(x, y, w, h)
  ctx:stroke()
end

-- ---------- digit-glyph painter (no canvas-font dependency: tiny pixel digits) ----------
-- 3x5 pixel font for cell labels, drawn via small rects

local DIGIT_GLYPHS = {
  ["0"] = {{1,1,1},{1,0,1},{1,0,1},{1,0,1},{1,1,1}},
  ["1"] = {{0,1,0},{1,1,0},{0,1,0},{0,1,0},{1,1,1}},
  ["2"] = {{1,1,1},{0,0,1},{1,1,1},{1,0,0},{1,1,1}},
  ["3"] = {{1,1,1},{0,0,1},{1,1,1},{0,0,1},{1,1,1}},
  ["4"] = {{1,0,1},{1,0,1},{1,1,1},{0,0,1},{0,0,1}},
  ["5"] = {{1,1,1},{1,0,0},{1,1,1},{0,0,1},{1,1,1}},
  ["6"] = {{1,1,1},{1,0,0},{1,1,1},{1,0,1},{1,1,1}},
  ["7"] = {{1,1,1},{0,0,1},{0,1,0},{0,1,0},{0,1,0}},
  ["8"] = {{1,1,1},{1,0,1},{1,1,1},{1,0,1},{1,1,1}},
  ["9"] = {{1,1,1},{1,0,1},{1,1,1},{0,0,1},{1,1,1}},
}

local function draw_digit(ctx, ch, x, y, px)
  local g = DIGIT_GLYPHS[ch]
  if not g then return end
  for row = 1, 5 do
    for col = 1, 3 do
      if g[row][col] == 1 then
        ctx:fill_rect(x + (col-1)*px, y + (row-1)*px, px, px)
      end
    end
  end
end

local function draw_number(ctx, n, x, y, px, color)
  ctx.fill_color = color
  local s = tostring(n)
  for i = 1, #s do
    draw_digit(ctx, s:sub(i,i), x + (i-1) * (4*px), y, px)
  end
end

-- ---------- lane rendering ----------

local function draw_lane(ctx, row)
  local y0 = (row - 1) * LANE_H + LANE_INSET_TOP
  local cw = cell_w()
  local quad_w = cw * 4

  -- quadrant backgrounds
  for q = 0, (MAX_STEPS / 4) - 1 do
    fill_rect(ctx, q * quad_w, y0, quad_w, LANE_INNER_H,
      (q % 2 == 0) and C.quad_white or C.quad_black)
  end

  -- subtle inner cell grid (skip quadrant boundaries — color does that)
  ctx.stroke_color = C.cell_grid
  ctx.line_width = 1
  for s = 1, MAX_STEPS - 1 do
    if (s % 4) ~= 0 then
      local x = s * cw
      ctx:begin_path()
      ctx:move_to(x, y0)
      ctx:line_to(x, y0 + LANE_INNER_H)
      ctx:stroke()
    end
  end

  -- view-mode tint band along the bottom of the lane
  local view_mode = lane_view[row] or "triggers"
  if view_mode == "velocity" then
    fill_rect(ctx, 0, y0 + LANE_INNER_H - 4, CANVAS_W, 4, C.velocity_band)
  elseif view_mode == "probability" then
    fill_rect(ctx, 0, y0 + LANE_INNER_H - 4, CANVAS_W, 4, C.prob_band)
  end

  -- triggers (read-through from 8120's rows[])
  for s = 1, MAX_STEPS do
    if read_trigger(row, s) then
      local v = velocity[row][s] or 1.0
      local p = probability[row][s] or 1.0
      if v < 0.05 then v = 0.05 end
      local block_h = math.floor(LANE_INNER_H * v) - 3
      if block_h < 3 then block_h = 3 end
      local block_y = y0 + LANE_INNER_H - block_h - 1
      local block_x = (s - 1) * cw + 3
      local block_w = cw - 6
      local base = quadrant_is_dark(s) and C.trig_on_black or C.trig_on_white
      local color = { base[1], base[2], base[3], math.floor(255 * p) }
      fill_rect(ctx, block_x, block_y, block_w, block_h, color)

      local rc = roll_count[row][s] or 1
      if rc > 1 then
        local px = 1
        local badge_w = 4 * px
        local badge_x = (s - 1) * cw + cw - badge_w - 2
        draw_number(ctx, rc, badge_x, y0 + 2, px, C.playhead_label)
      end
    end
  end

  if read_lane_muted(row) then
    fill_rect(ctx, 0, y0, CANVAS_W, LANE_INNER_H, C.muted_overlay)
  end

  -- selection
  if selection then
    local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
    if row >= r1 and row <= r2 then
      local sx = (s1 - 1) * cw
      local sw = (s2 - s1 + 1) * cw
      fill_rect(ctx, sx, y0, sw, LANE_INNER_H, C.selection_fill)
      stroke_rect(ctx, sx, y0, sw, LANE_INNER_H, C.selection_brd, 2)
    end
  end

  -- playhead
  if row == playhead_lane and playhead_step >= 1 and playhead_step <= MAX_STEPS then
    local px = (playhead_step - 1) * cw
    stroke_rect(ctx, px, y0, cw, LANE_INNER_H, C.playhead, 2.5)
  end

  -- step number labels — drawn LAST so the selection wash, mute overlay,
  -- triggers etc. can never hide them
  local label_px = (MAX_STEPS == 16) and 2 or 1
  for s = 1, MAX_STEPS do
    local color = quadrant_is_dark(s) and C.step_label_d or C.step_label_l
    draw_number(ctx, s, (s-1)*cw + 3, y0 + 3, label_px, color)
  end

  -- lane divider
  if row < NUM_LANES then
    ctx.stroke_color = C.lane_div
    ctx.line_width = 1
    ctx:begin_path()
    ctx:move_to(0, row * LANE_H)
    ctx:line_to(CANVAS_W, row * LANE_H)
    ctx:stroke()
  end
end

local function render_canvas(ctx)
  ctx:clear_rect(0, 0, CANVAS_W, CANVAS_H)
  fill_rect(ctx, 0, 0, CANVAS_W, CANVAS_H, C.bg)
  for r = 1, NUM_LANES do
    draw_lane(ctx, r)
  end
end

-- ---------- mouse ----------

local function hit_test(x, y)
  if x < 0 or x >= CANVAS_W or y < 0 or y >= CANVAS_H then return nil, nil, 0 end
  local row = math.floor(y / LANE_H) + 1
  local local_y = y - (row - 1) * LANE_H
  if local_y < LANE_INSET_TOP or local_y > LANE_INSET_TOP + LANE_INNER_H then
    return nil, nil, 0
  end
  local step = math.floor(x / cell_w()) + 1
  if step < 1 then step = 1 end
  if step > MAX_STEPS then step = MAX_STEPS end
  -- normalized 0..1 from top of lane (1.0 at bottom — for velocity drag)
  local norm = 1.0 - (local_y - LANE_INSET_TOP) / LANE_INNER_H
  if norm < 0 then norm = 0 end
  if norm > 1 then norm = 1 end
  return row, step, norm
end

local function set_selection(r1, s1, r2, s2)
  if r2 < r1 then r1, r2 = r2, r1 end
  if s2 < s1 then s1, s2 = s2, s1 end
  selection = { r1, s1, r2, s2 }
end

local function update_selection_label()
  if not view or not view.selection_label then return end
  if not selection then
    view.selection_label.text = "selection: (none)"
    return
  end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local cells = (r2 - r1 + 1) * (s2 - s1 + 1)
  if r1 == r2 then
    view.selection_label.text = string.format("selection: row %d · steps %d–%d (%d cells)", r1, s1, s2, cells)
  else
    view.selection_label.text = string.format("selection: rows %d–%d · steps %d–%d (%d cells)", r1, r2, s1, s2, cells)
  end
end

local function quadrant_of(step)
  local q = math.floor((step - 1) / 4)
  return q * 4 + 1, q * 4 + 4
end

local mouse_down_pos = nil
local mouse_did_drag = false

local function handle_mouse(ev)
  if ev.type == "exit" then return end
  local x, y = ev.position.x, ev.position.y
  local mods = ev.modifiers or ""
  local has_alt   = mods:find("alt")   or mods:find("option")
  local has_shift = mods:find("shift")

  if ev.type == "down" then
    local row, step, norm = hit_test(x, y)
    if not row then return end
    local view_mode = lane_view[row] or "triggers"

    if view_mode == "velocity" or view_mode == "probability" then
      if read_trigger(row, step) then
        edit_drag = { row = row, step = step, mode = view_mode }
        if view_mode == "velocity" then
          velocity[row][step] = norm
        else
          probability[row][step] = norm
        end
        if step_canvas then step_canvas:update() end
        return
      end
      write_trigger(row, step, true)
      if step_canvas then step_canvas:update() end
      return
    end

    -- triggers mode
    if has_alt then
      local q1, q2 = quadrant_of(step)
      set_selection(row, q1, row, q2)
      update_selection_label()
      if step_canvas then step_canvas:update() end
      return
    end
    if has_shift and selection then
      local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
      local anchor_r = (row >= r1 and row <= r2) and r2 or r1
      local anchor_s = (step >= s1 and step <= s2) and s2 or s1
      set_selection(anchor_r, anchor_s, row, step)
      update_selection_label()
      if step_canvas then step_canvas:update() end
      return
    end
    mouse_down_pos = { row = row, step = step }
    mouse_did_drag = false
    drag = { anchor_row = row, anchor_step = step }
    set_selection(row, step, row, step)
    update_selection_label()
    if step_canvas then step_canvas:update() end

  elseif ev.type == "move" then
    if edit_drag then
      local row, step, norm = hit_test(x, y)
      if row == edit_drag.row and step == edit_drag.step then
        if edit_drag.mode == "velocity" then
          velocity[row][step] = norm
        else
          probability[row][step] = norm
        end
        if step_canvas then step_canvas:update() end
      end
      return
    end
    if not drag then return end
    local row, step = hit_test(x, y)
    if not row then return end
    if row ~= drag.anchor_row or step ~= drag.anchor_step then
      mouse_did_drag = true
    end
    set_selection(drag.anchor_row, drag.anchor_step, row, step)
    update_selection_label()
    if step_canvas then step_canvas:update() end

  elseif ev.type == "up" then
    if edit_drag then
      edit_drag = nil
      return
    end
    if mouse_down_pos and not mouse_did_drag then
      local r, s = mouse_down_pos.row, mouse_down_pos.step
      if (lane_view[r] or "triggers") == "triggers" then
        write_trigger(r, s, not read_trigger(r, s))
        if step_canvas then step_canvas:update() end
      end
    end
    drag = nil
    mouse_down_pos = nil
    mouse_did_drag = false
  end
end

-- ---------- verbs ----------

local function require_selection()
  if not selection then
    renoise.app():show_status("Groovebox 8ch960samp: no selection — click a cell or drag a range first")
    return false
  end
  return true
end

local function for_each_in_selection(fn)
  if not selection then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  for r = r1, r2 do
    for s = s1, s2 do
      fn(r, s)
    end
  end
end

local function refresh()
  if step_canvas then step_canvas:update() end
end

local function verb_invert()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) write_trigger(r, s, not read_trigger(r, s)) end)
  refresh()
end

local function verb_clear()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) write_trigger(r, s, false) end)
  refresh()
end

local function verb_fill()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) write_trigger(r, s, true) end)
  refresh()
end

local function verb_reverse()
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local n = s2 - s1 + 1
  for r = r1, r2 do
    local t, v, p, rc = {}, {}, {}, {}
    for s = s1, s2 do
      local i = s - s1 + 1
      t[i], v[i], p[i], rc[i] = read_trigger(r, s), velocity[r][s], probability[r][s], roll_count[r][s]
    end
    for s = s1, s2 do
      local src = n - (s - s1)
      write_trigger(r, s, t[src]); velocity[r][s], probability[r][s], roll_count[r][s] = v[src], p[src], rc[src]
    end
  end
  refresh()
end

local function nudge(direction)
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local n = s2 - s1 + 1
  for r = r1, r2 do
    local t, v, p, rc = {}, {}, {}, {}
    for s = s1, s2 do
      local i = s - s1 + 1
      t[i], v[i], p[i], rc[i] = read_trigger(r, s), velocity[r][s], probability[r][s], roll_count[r][s]
    end
    for s = s1, s2 do
      local idx = s - s1
      local src = ((idx - direction) % n) + 1
      write_trigger(r, s, t[src]); velocity[r][s], probability[r][s], roll_count[r][s] = v[src], p[src], rc[src]
    end
  end
  refresh()
end

-- nudge across rows (move pattern between lanes)
local function nudge_rows(direction)
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local nrows = r2 - r1 + 1
  if nrows < 2 then
    renoise.app():show_status("Groovebox 8ch960samp: row-nudge needs a multi-row selection")
    return
  end
  for s = s1, s2 do
    local t, v, p, rc = {}, {}, {}, {}
    for r = r1, r2 do
      local i = r - r1 + 1
      t[i], v[i], p[i], rc[i] = read_trigger(r, s), velocity[r][s], probability[r][s], roll_count[r][s]
    end
    for r = r1, r2 do
      local idx = r - r1
      local src = ((idx - direction) % nrows) + 1
      write_trigger(r, s, t[src])
      velocity[r][s], probability[r][s], roll_count[r][s] = v[src], p[src], rc[src]
    end
  end
  refresh()
end

local function verb_density_plus()
  if not require_selection() then return end
  -- find longest empty stretch in each row of the selection, place a trigger in its middle
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  for r = r1, r2 do
    local best_start, best_len, cur_start, cur_len = nil, 0, nil, 0
    for s = s1, s2 do
      if not read_trigger(r, s) then
        if cur_start == nil then cur_start = s end
        cur_len = cur_len + 1
        if cur_len > best_len then best_len, best_start = cur_len, cur_start end
      else
        cur_start, cur_len = nil, 0
      end
    end
    if best_start then
      local target = best_start + math.floor(best_len / 2)
      write_trigger(r, target, true)
      velocity[r][target] = 0.7
    end
  end
  refresh()
end

local function verb_density_minus()
  if not require_selection() then return end
  -- remove the lowest-velocity trigger in each row of the selection
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  for r = r1, r2 do
    local weakest_s, weakest_v = nil, 2.0
    for s = s1, s2 do
      if read_trigger(r, s) then
        local v = velocity[r][s] or 1.0
        if v < weakest_v then weakest_v, weakest_s = v, s end
      end
    end
    if weakest_s then write_trigger(r, weakest_s, false) end
  end
  refresh()
end

local function verb_humanize()
  if not require_selection() then return end
  for_each_in_selection(function(r, s)
    if read_trigger(r, s) then
      local jitter = (math.random() - 0.5) * 0.3  -- ±15%
      local v = (velocity[r][s] or 1.0) + jitter
      if v < 0.15 then v = 0.15 end
      if v > 1.0 then v = 1.0 end
      velocity[r][s] = v
    end
  end)
  refresh()
end

local function verb_roll_inc()
  if not require_selection() then return end
  for_each_in_selection(function(r, s)
    if read_trigger(r, s) then
      roll_count[r][s] = math.min(8, (roll_count[r][s] or 1) + 1)
    end
  end)
  refresh()
end

local function verb_roll_dec()
  if not require_selection() then return end
  for_each_in_selection(function(r, s)
    if read_trigger(r, s) then
      roll_count[r][s] = math.max(1, (roll_count[r][s] or 1) - 1)
    end
  end)
  refresh()
end

local function verb_copy()
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  clipboard = { rows = r2 - r1 + 1, steps = s2 - s1 + 1, cells = {} }
  for r = r1, r2 do
    local row_cells = {}
    for s = s1, s2 do
      table.insert(row_cells, {
        t  = read_trigger(r, s),
        v  = velocity[r][s],
        p  = probability[r][s],
        rc = roll_count[r][s],
      })
    end
    table.insert(clipboard.cells, row_cells)
  end
  renoise.app():show_status(string.format("Groovebox 8ch960samp: copied %dx%d cells", clipboard.rows, clipboard.steps))
end

local function verb_paste()
  if not clipboard then
    renoise.app():show_status("Groovebox 8ch960samp: clipboard is empty")
    return
  end
  if not require_selection() then return end
  local r1, s1 = selection[1], selection[2]
  for ri = 1, clipboard.rows do
    for si = 1, clipboard.steps do
      local rr, ss = r1 + ri - 1, s1 + si - 1
      if rr <= NUM_LANES and ss <= MAX_STEPS then
        local c = clipboard.cells[ri][si]
        write_trigger(rr, ss, c.t)
        velocity[rr][ss], probability[rr][ss], roll_count[rr][ss] = c.v, c.p, c.rc
      end
    end
  end
  refresh()
end

-- Euclidean: pulses k distributed across n steps (Bjorklund-ish, simple variant)
local function euclidean(k, n, offset)
  local pattern = {}
  for i = 1, n do pattern[i] = false end
  if k <= 0 then return pattern end
  if k >= n then for i = 1, n do pattern[i] = true end; return pattern end
  for i = 0, k - 1 do
    local idx = math.floor(i * n / k) + 1
    pattern[((idx - 1 + (offset or 0)) % n) + 1] = true
  end
  return pattern
end

function show_euclid_dialog()
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local n = s2 - s1 + 1
  local d = nil
  local pulses_box = vb:valuebox{ min=0, max=n, value=math.max(1, math.floor(n/4)) }
  local offset_box = vb:valuebox{ min=0, max=n-1, value=0 }
  local content = vb:column{
    margin = 6, spacing = 4,
    vb:text{ text = string.format("Euclidean fill across %d steps × %d rows", n, r2-r1+1), font="bold", style="strong" },
    vb:row{ vb:text{ text="pulses ", width=60 }, pulses_box },
    vb:row{ vb:text{ text="offset ", width=60 }, offset_box },
    vb:row{
      vb:button{ text="Apply", notifier = function()
        local pattern = euclidean(pulses_box.value, n, offset_box.value)
        for r = r1, r2 do
          for s = s1, s2 do
            write_trigger(r, s, pattern[s - s1 + 1])
          end
        end
        refresh()
        if d then d:close() end
      end },
      vb:button{ text="Cancel", notifier = function() if d then d:close() end end },
    }
  }
  d = renoise.app():show_custom_dialog("Euclidean Fill", content)
end

-- sample a curve at normalized t in [0,1], using linear interpolation between control points
local function sample_curve(values, t)
  if not values or #values == 0 then return 0 end
  if t <= values[1][1] then return values[1][2] end
  if t >= values[#values][1] then return values[#values][2] end
  for i = 1, #values - 1 do
    local t0, v0 = values[i][1], values[i][2]
    local t1, v1 = values[i+1][1], values[i+1][2]
    if t >= t0 and t <= t1 then
      local span = t1 - t0
      if span <= 0 then return v0 end
      local f = (t - t0) / span
      return v0 + (v1 - v0) * f
    end
  end
  return values[#values][2]
end

local function show_curve_dialog()
  if not require_selection() then return end
  if not PakettiAutomationCurvesShapes then
    renoise.app():show_status("Groovebox 8ch960samp: PakettiAutomationCurvesShapes not loaded")
    return
  end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local n = s2 - s1 + 1

  -- collect shape names sorted
  local names = {}
  for k, _ in pairs(PakettiAutomationCurvesShapes) do table.insert(names, k) end
  table.sort(names)

  local d = nil
  local target_switch = vb:switch{ items={"velocity","probability"}, width=200, value=1 }
  local shape_popup   = vb:popup{ items=names, width=200, value=1 }

  local function apply()
    local shape = PakettiAutomationCurvesShapes[names[shape_popup.value]]
    if not shape or not shape.values then return end
    local target = (target_switch.value == 1) and "velocity" or "probability"
    for r = r1, r2 do
      for s = s1, s2 do
        local t = (n == 1) and 0.5 or ((s - s1) / (n - 1))
        local v = sample_curve(shape.values, t)
        if v < 0 then v = 0 end
        if v > 1 then v = 1 end
        if target == "velocity" then
          velocity[r][s] = v
        else
          probability[r][s] = v
        end
      end
    end
    refresh()
  end

  local content = vb:column{
    margin = 6, spacing = 4,
    vb:text{ text = string.format("Apply curve across %d steps × %d rows", n, r2-r1+1), font="bold", style="strong" },
    vb:text{ text = "Curve sampled at each step's normalized position; output written into the chosen lane parameter.", style="disabled" },
    vb:row{ vb:text{ text="curve ", width=60 }, shape_popup },
    vb:row{ vb:text{ text="target", width=60 }, target_switch },
    vb:row{
      vb:button{ text="Apply", notifier = function() apply(); if d then d:close() end end },
      vb:button{ text="Apply & keep open", notifier = apply },
      vb:button{ text="Close", notifier = function() if d then d:close() end end },
    }
  }
  d = renoise.app():show_custom_dialog("Apply Curve to Selection", content)
end

local function toggle_step_count()
  MAX_STEPS = (MAX_STEPS == 16) and 32 or 16
  selection = nil
  update_selection_label()
  if view and view.step_toggle_text then
    view.step_toggle_text.text = string.format("Steps: %d", MAX_STEPS)
  end
  refresh()
end

local function cycle_lane_view(row)
  local order = { triggers = "velocity", velocity = "probability", probability = "triggers" }
  lane_view[row] = order[lane_view[row] or "triggers"] or "triggers"
  if view and view.view_buttons and view.view_buttons[row] then
    view.view_buttons[row].text = ({triggers="T",velocity="V",probability="P"})[lane_view[row]] or "T"
  end
  refresh()
end

-- ---------- dialog construction ----------

-- Each lane strip is a SINGLE vb:row with explicit height=LANE_H so the side
-- columns are exactly NUM_LANES * LANE_H tall — matching the canvas pixel-for-
-- pixel. Mixed-height children inside (buttons ~22px, text ~16px) all top-
-- align within the row, but the row itself is forced to LANE_H so 8 stacked
-- rows = canvas height. The wrapping vb:column uses spacing=0 to remove
-- inter-row gaps.

local function truncate(s, n)
  if not s then return "" end
  if #s <= n then return s end
  return s:sub(1, n - 1) .. "…"
end

local function lane_strip_left(row)
  local name     = read_lane_name(row)
  local is_muted = read_lane_muted(row)
  local view_btn = vb:button{
    text = ({triggers="T",velocity="V",probability="P"})[lane_view[row] or "triggers"] or "T",
    width = 22,
    notifier = function() cycle_lane_view(row) end
  }
  local mute_btn = vb:button{
    text = "M", width = 22,
    color = is_muted and {0xd8,0x50,0x60} or nil,
    notifier = function()
      set_lane_muted(row, not read_lane_muted(row))
      refresh()
    end
  }
  local strip = vb:row{
    height = LANE_H,
    mute_btn,
    vb:button{ text="S", width=22 },
    vb:button{ text="R", width=22 },
    view_btn,
    vb:text{ text=string.format(" %02d ", row), font="bold", style="strong", width=24 },
    vb:text{ text=truncate(name, 18), width=130, style = (name == "—") and "disabled" or "normal" },
  }
  return { column = strip, view_btn = view_btn }
end

local function lane_strip_right(row)
  -- Sample slider read-through to 8120's rows[row].slider; same notifier
  -- fires (selects the sample, swaps pakettified sample, restores
  -- automation). Headless fallback selects the sample directly.
  local re = row_elements(row)
  local slider_initial = 1
  if re and re.slider then slider_initial = re.slider.value or 1 end
  local sample_slider = vb:slider{
    min = 1, max = 120,
    value = slider_initial,
    width = 150,
    notifier = function(value)
      value = math.floor(value)
      local re_now = row_elements(row)
      if re_now and re_now.slider then
        re_now.slider.value = value
      else
        local song = renoise.song()
        if row <= #song.instruments then
          song.selected_instrument_index = row
          local inst = song.instruments[row]
          if inst and inst.samples and #inst.samples > 0 then
            local idx = value
            if idx > #inst.samples then idx = #inst.samples end
            if idx < 1 then idx = 1 end
            song.selected_sample_index = idx
          end
        end
      end
    end
  }
  return vb:row{
    height = LANE_H,
    vb:text{ text=" smp ", style="disabled", width=30 },
    sample_slider,
  }
end

local function build_view()
  -- spacing=0 + margin=0 so 8 strips of height=LANE_H stack to exactly
  -- NUM_LANES * LANE_H — same as the canvas — and the lane bands align.
  local left_col_children  = { spacing = 0, margin = 0 }
  local right_col_children = { spacing = 0, margin = 0 }
  local view_buttons = {}
  for r = 1, NUM_LANES do
    local strip = lane_strip_left(r)
    table.insert(left_col_children, strip.column)
    view_buttons[r] = strip.view_btn
    table.insert(right_col_children, lane_strip_right(r))
  end

  step_canvas = vb:canvas{
    width = CANVAS_W,
    height = CANVAS_H,
    mode = "plain",
    render = render_canvas,
    mouse_handler = handle_mouse,
    mouse_events = {"down","up","move","exit"},
  }

  local v = { view_buttons = view_buttons }
  v.step_toggle_text = vb:text{ text = string.format("Steps: %d", MAX_STEPS), font="bold", style="strong" }
  v.selection_label  = vb:text{ text = "selection: (none)", style="strong" }

  v.transport_bar = vb:row{
    style = "panel",
    vb:button{ text="▶", width=28 }, vb:button{ text="■", width=28 }, vb:button{ text="●", width=28 },
    vb:text{ text="  BPM 124", font="bold", style="strong" },
    vb:text{ text="  follow ✓  groove ✓  rand gates  fill 35%", style="disabled" },
    vb:button{ text="16 / 32", width=70, notifier = toggle_step_count },
    v.step_toggle_text,
  }

  v.verb_palette_1 = vb:row{
    style = "panel",
    vb:text{ text="step:", style="strong" },
    vb:button{ text="←",  width=30, notifier=function() nudge(-1) end },
    vb:button{ text="→",  width=30, notifier=function() nudge( 1) end },
    vb:text{ text=" row:", style="strong" },
    vb:button{ text="↑",  width=30, notifier=function() nudge_rows(-1) end },
    vb:button{ text="↓",  width=30, notifier=function() nudge_rows( 1) end },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="invert",   width=60, notifier = verb_invert },
    vb:button{ text="reverse",  width=70, notifier = verb_reverse },
    vb:button{ text="fill",     width=50, notifier = verb_fill },
    vb:button{ text="clear",    width=50, notifier = verb_clear },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="density−", width=72, notifier = verb_density_minus },
    vb:button{ text="density+", width=72, notifier = verb_density_plus },
    vb:button{ text="humanize", width=82, notifier = verb_humanize },
  }

  v.verb_palette_2 = vb:row{
    style = "panel",
    vb:text{ text="roll:", style="strong" },
    vb:button{ text="−", width=30, notifier = verb_roll_dec },
    vb:button{ text="+", width=30, notifier = verb_roll_inc },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="copy",  width=50, notifier = verb_copy },
    vb:button{ text="paste", width=50, notifier = verb_paste },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="euclid…",      width=72, notifier = show_euclid_dialog },
    vb:button{ text="apply curve…", width=110, notifier = show_curve_dialog },
    vb:text{ text=" |", style="disabled" },
    -- Sequential Load family — populates actual song instruments via 8120's
    -- existing functions. Always available so you don't have to bounce
    -- dialogs to load samples.
    vb:button{ text="Load…",          width=70,  notifier = function()
      if loadSequentialSamplesWithFolderPrompts then loadSequentialSamplesWithFolderPrompts()
      else renoise.app():show_status("loadSequentialSamplesWithFolderPrompts not available") end
    end },
    vb:button{ text="RandomLoad…",    width=110, notifier = function()
      if loadSequentialDrumkitSamples then loadSequentialDrumkitSamples()
      else renoise.app():show_status("loadSequentialDrumkitSamples not available") end
    end },
    vb:button{ text="RandomLoadAll…", width=130, notifier = function()
      if loadSequentialRandomLoadAll then loadSequentialRandomLoadAll()
      else renoise.app():show_status("loadSequentialRandomLoadAll not available") end
    end },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="refresh", width=64, notifier = function()
      ensure_local_state(); selection = nil; update_selection_label()
      for r = 1, NUM_LANES do
        if view_buttons[r] then
          view_buttons[r].text = ({triggers="T",velocity="V",probability="P"})[lane_view[r] or "triggers"] or "T"
        end
      end
      refresh()
    end },
  }

  v.body = vb:row{
    vb:column(left_col_children),
    step_canvas,
    vb:column(right_col_children),
  }

  v.status = vb:row{
    style = "panel",
    v.selection_label,
    vb:text{ text = "  ·  click cell · drag = range · alt+click = quadrant · shift+click = extend · T/V/P button cycles lane mode (drag inside cell to edit V/P)",
      style="disabled" },
  }

  v.root = vb:column{
    margin = 6,
    spacing = 4,
    v.transport_bar,
    v.verb_palette_1,
    v.verb_palette_2,
    v.body,
    v.status,
  }
  view = v
  return v.root
end

-- ---------- entry point ----------

function PakettiGroovebox8ch960sampShow()
  if not PAKETTI_HAS_CANVAS then
    renoise.app():show_status("Groovebox 8ch960samp requires Renoise 3.5+ (Canvas API 6.2+)")
    return
  end
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  -- 8ch960samp is a view of 8120's state. Open 8120 first so rows[] is
  -- populated; otherwise the canvas will render empty cells with no way
  -- for clicks to land anywhere meaningful.
  if pakettiEightSlotsByOneTwentyDialog then
    local ok, _ = pcall(function()
      if not (rows_table() and rows_table()[1]) then
        pakettiEightSlotsByOneTwentyDialog()
      end
    end)
    if not ok then
      renoise.app():show_status("Groovebox 8ch960samp: could not open 8120 backend; canvas will be read-only")
    end
  end
  ensure_local_state()
  selection = nil
  local content = build_view()
  update_selection_label()
  dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8ch960samp (MK2 prototype — view of 8120)", content)
  -- No idle-redraw loop: it caused visible "animation" between user input
  -- frames and made selection feel laggy. Use the "refresh" verb button to
  -- pull external 8120 changes when needed.
end

PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Groovebox:Groovebox 8ch960samp (MK2 prototype)…",
  invoke = PakettiGroovebox8ch960sampShow }
PakettiAddMenuEntry{ name = "Pattern Editor:Paketti:Groovebox 8ch960samp (MK2 prototype)…",
  invoke = PakettiGroovebox8ch960sampShow }

renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Groovebox 8ch960samp (MK2 prototype)",
  invoke = PakettiGroovebox8ch960sampShow
}
