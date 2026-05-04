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

local triggers, velocity, probability, roll_count, lane_meta

local function reset_model()
  triggers, velocity, probability, roll_count, lane_meta = {}, {}, {}, {}, {}
  for r = 1, NUM_LANES do
    triggers[r], velocity[r], probability[r], roll_count[r] = {}, {}, {}, {}
    for s = 1, 32 do
      triggers[r][s] = false
      velocity[r][s] = 1.0
      probability[r][s] = 1.0
      roll_count[r][s] = 1
    end
    lane_meta[r] = {
      name = ({"kick-808.wav","snare-clap.wav","hat-closed.wav","hat-open.wav",
               "ride-cymbal.wav","bass-sub.wav","— empty —","perc-shot.wav"})[r] or "lane",
      muted   = (r == 5),
      soloed  = false,
      random  = false,
      view    = "triggers",  -- "triggers" / "velocity" / "probability"
    }
  end
  triggers[1][1]=true; triggers[1][5]=true; triggers[1][9]=true; triggers[1][13]=true
  triggers[2][5]=true; triggers[2][13]=true; velocity[2][13]=0.75
  for s=1,16 do
    triggers[3][s] = true
    velocity[3][s] = ({1.0,0.55,0.75,0.45,1.0,0.55,0.75,0.45,1.0,0.55,0.75,0.45,1.0,0.55,0.75,0.45})[s]
  end
  triggers[4][3]=true; triggers[4][11]=true
  triggers[6][1]=true; triggers[6][3]=true; triggers[6][5]=true; triggers[6][7]=true
  triggers[6][9]=true; triggers[6][12]=true; triggers[6][15]=true
  velocity[6][3]=0.7; velocity[6][7]=0.6; velocity[6][12]=0.7; velocity[6][15]=0.8
  triggers[8][1]=true; triggers[8][4]=true; triggers[8][9]=true
  -- demo probability: lane 6 step 15 is "maybe" (rendered with reduced opacity)
  probability[6][15] = 0.5
  -- demo roll: lane 1 step 13 is a 3-roll
  roll_count[1][13] = 3
end

-- selection rectangle: {row1, step1, row2, step2} or nil
local selection = nil
local drag = nil          -- selection drag: {anchor_row, anchor_step}
local edit_drag = nil     -- velocity/probability drag: {row, step, mode}
local clipboard = nil     -- copy/paste buffer

local playhead_lane, playhead_step = 3, 7

-- ---------- canvas geometry ----------

local CANVAS_W = 960
local LANE_H   = 90
local CANVAS_H = NUM_LANES * LANE_H
local LANE_INSET_TOP = 6
local LANE_INNER_H   = LANE_H - 12  -- 78px

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
  selection_fill= rgb(0xb0,0x60,0xd8, 60),
  selection_brd = rgb(0xb0,0x60,0xd8),
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

  -- step number labels in cell corners (top-left)
  local label_px = (MAX_STEPS == 16) and 2 or 1
  for s = 1, MAX_STEPS do
    local color = quadrant_is_dark(s) and C.step_label_d or C.step_label_l
    draw_number(ctx, s, (s-1)*cw + 3, y0 + 3, label_px, color)
  end

  -- view-mode tint band along the bottom of the lane
  local m = lane_meta[row]
  if m.view == "velocity" then
    fill_rect(ctx, 0, y0 + LANE_INNER_H - 6, CANVAS_W, 6, C.velocity_band)
  elseif m.view == "probability" then
    fill_rect(ctx, 0, y0 + LANE_INNER_H - 6, CANVAS_W, 6, C.prob_band)
  end

  -- triggers
  for s = 1, MAX_STEPS do
    if triggers[row][s] then
      local v = velocity[row][s] or 1.0
      local p = probability[row][s] or 1.0
      if v < 0.05 then v = 0.05 end
      local block_h = math.floor(LANE_INNER_H * v) - 4
      if block_h < 4 then block_h = 4 end
      local block_y = y0 + LANE_INNER_H - block_h - 2
      local block_x = (s - 1) * cw + 4
      local block_w = cw - 8
      local base = quadrant_is_dark(s) and C.trig_on_black or C.trig_on_white
      local color = { base[1], base[2], base[3], math.floor(255 * p) }
      fill_rect(ctx, block_x, block_y, block_w, block_h, color)

      -- roll-count badge (top-right of cell) when > 1
      local rc = roll_count[row][s] or 1
      if rc > 1 then
        local px = (MAX_STEPS == 16) and 2 or 1
        local badge_w = 4 * px
        local badge_x = (s - 1) * cw + cw - badge_w - 3
        draw_number(ctx, rc, badge_x, y0 + 3, px, C.playhead_label)
      end
    end
  end

  -- mute overlay
  if m.muted then
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
    local m = lane_meta[row]

    -- velocity / probability mode: drag inside cell adjusts value (only when trigger is on)
    if m.view == "velocity" or m.view == "probability" then
      if triggers[row][step] then
        edit_drag = { row = row, step = step, mode = m.view }
        if m.view == "velocity" then
          velocity[row][step] = norm
        else
          probability[row][step] = norm
        end
        if step_canvas then step_canvas:update() end
        return
      end
      -- if trigger is off in velocity/probability mode, click still toggles it
      triggers[row][step] = true
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
      -- pure click (no drag) in triggers mode: toggle the cell
      local r, s = mouse_down_pos.row, mouse_down_pos.step
      if lane_meta[r].view == "triggers" then
        triggers[r][s] = not triggers[r][s]
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
  for_each_in_selection(function(r, s) triggers[r][s] = not triggers[r][s] end)
  refresh()
end

local function verb_clear()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) triggers[r][s] = false end)
  refresh()
end

local function verb_fill()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) triggers[r][s] = true end)
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
      t[i], v[i], p[i], rc[i] = triggers[r][s], velocity[r][s], probability[r][s], roll_count[r][s]
    end
    for s = s1, s2 do
      local src = n - (s - s1)
      triggers[r][s], velocity[r][s], probability[r][s], roll_count[r][s] = t[src], v[src], p[src], rc[src]
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
      t[i], v[i], p[i], rc[i] = triggers[r][s], velocity[r][s], probability[r][s], roll_count[r][s]
    end
    for s = s1, s2 do
      local idx = s - s1
      local src = ((idx - direction) % n) + 1
      triggers[r][s], velocity[r][s], probability[r][s], roll_count[r][s] = t[src], v[src], p[src], rc[src]
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
      t[i], v[i], p[i], rc[i] = triggers[r][s], velocity[r][s], probability[r][s], roll_count[r][s]
    end
    for r = r1, r2 do
      local idx = r - r1
      local src = ((idx - direction) % nrows) + 1
      triggers[r][s], velocity[r][s], probability[r][s], roll_count[r][s] = t[src], v[src], p[src], rc[src]
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
      if not triggers[r][s] then
        if cur_start == nil then cur_start = s end
        cur_len = cur_len + 1
        if cur_len > best_len then best_len, best_start = cur_len, cur_start end
      else
        cur_start, cur_len = nil, 0
      end
    end
    if best_start then
      local target = best_start + math.floor(best_len / 2)
      triggers[r][target] = true
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
      if triggers[r][s] then
        local v = velocity[r][s] or 1.0
        if v < weakest_v then weakest_v, weakest_s = v, s end
      end
    end
    if weakest_s then triggers[r][weakest_s] = false end
  end
  refresh()
end

local function verb_humanize()
  if not require_selection() then return end
  for_each_in_selection(function(r, s)
    if triggers[r][s] then
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
    if triggers[r][s] then
      roll_count[r][s] = math.min(8, (roll_count[r][s] or 1) + 1)
    end
  end)
  refresh()
end

local function verb_roll_dec()
  if not require_selection() then return end
  for_each_in_selection(function(r, s)
    if triggers[r][s] then
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
        t  = triggers[r][s],
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
        triggers[rr][ss], velocity[rr][ss], probability[rr][ss], roll_count[rr][ss] = c.t, c.v, c.p, c.rc
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

local function show_euclid_dialog()
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
            triggers[r][s] = pattern[s - s1 + 1]
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
  lane_meta[row].view = order[lane_meta[row].view] or "triggers"
  if view and view.view_buttons and view.view_buttons[row] then
    view.view_buttons[row].text = ({triggers="T",velocity="V",probability="P"})[lane_meta[row].view] or "T"
  end
  refresh()
end

-- ---------- dialog construction ----------

local function lane_strip_left(row)
  local m = lane_meta[row]
  local view_btn = vb:button{ text = ({triggers="T",velocity="V",probability="P"})[m.view] or "T",
    width=22, notifier = function() cycle_lane_view(row) end }
  local mute_btn = vb:button{ text="M", width=22,
    color = m.muted and {0xd8,0x50,0x60} or nil,
    notifier = function()
      lane_meta[row].muted = not lane_meta[row].muted
      refresh()
    end }
  return {
    column = vb:column{
      width = 160,
      style = "panel",
      height = LANE_H,
      vb:row{
        mute_btn,
        vb:button{ text="S", width=22 },
        vb:button{ text="R", width=22 },
        view_btn,
        vb:text{ text=string.format(" %02d", row), font="bold", style="strong" },
      },
      vb:text{ text = m.name, style = (m.name=="— empty —") and "disabled" or "normal" },
      vb:row{
        vb:text{ text=string.format("inst %02d", row), style="disabled" },
        vb:text{ text="  ", width=4 },
        vb:text{ text=string.format("trk %02d", row), style="disabled" },
      },
    },
    view_btn = view_btn,
  }
end

local function lane_strip_right(_row)
  return vb:column{
    width = 180,
    style = "panel",
    height = LANE_H,
    vb:row{
      vb:text{ text="pitch", style="disabled" },
      vb:text{ text="  vol", style="disabled" },
      vb:text{ text="  loop", style="disabled" },
    },
    vb:row{
      vb:rotary{ min=-64, max=64, value=0, width=24, height=24 },
      vb:rotary{ min=-1, max=1, value=0, width=24, height=24 },
      vb:switch{ items={"○","→","←","↔"}, width=80, value=2 },
    },
    vb:row{
      vb:text{ text="delay 0ms", style="disabled" },
      vb:button{ text="⚙", width=22 },
    },
  }
end

local function build_view()
  local left_col_children  = { vb:column{} }
  local right_col_children = { vb:column{} }
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
    vb:button{ text="invert",  notifier = verb_invert },
    vb:button{ text="reverse", notifier = verb_reverse },
    vb:button{ text="fill",    notifier = verb_fill },
    vb:button{ text="clear",   notifier = verb_clear },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="density−", notifier = verb_density_minus },
    vb:button{ text="density+", notifier = verb_density_plus },
    vb:button{ text="humanize", notifier = verb_humanize },
  }

  v.verb_palette_2 = vb:row{
    style = "panel",
    vb:text{ text="roll:", style="strong" },
    vb:button{ text="−", width=30, notifier = verb_roll_dec },
    vb:button{ text="+", width=30, notifier = verb_roll_inc },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="copy",  notifier = verb_copy },
    vb:button{ text="paste", notifier = verb_paste },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="euclid…", notifier = show_euclid_dialog },
    vb:button{ text="apply curve…", notifier = show_curve_dialog },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="reset model", notifier = function()
      reset_model(); selection = nil; update_selection_label()
      for r = 1, NUM_LANES do
        if view_buttons[r] then
          view_buttons[r].text = ({triggers="T",velocity="V",probability="P"})[lane_meta[r].view] or "T"
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
  reset_model()
  selection = nil
  local content = build_view()
  update_selection_label()
  dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8ch960samp (MK2 prototype)", content)
end

PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Groovebox:Groovebox 8ch960samp (MK2 prototype)…",
  invoke = PakettiGroovebox8ch960sampShow }
PakettiAddMenuEntry{ name = "Pattern Editor:Paketti:Groovebox 8ch960samp (MK2 prototype)…",
  invoke = PakettiGroovebox8ch960sampShow }

renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Groovebox 8ch960samp (MK2 prototype)",
  invoke = PakettiGroovebox8ch960sampShow
}
