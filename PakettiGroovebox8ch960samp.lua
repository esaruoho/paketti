-- PakettiGroovebox8ch960samp.lua
-- Groovebox 8ch960samp (MK2) — canvas-rendered design prototype.
--
-- This file is a *visual scratchpad* for the rethought Groovebox 8120.
-- It deliberately does NOT touch song data: no pattern writing, no track
-- manipulation, no instrument selection. Everything you click here lives
-- in module-local state. The point is to nail the look and the feel of
-- the canvas grid, the selection model, and the verb palette — and only
-- then wire it to the EightOneTwenty data model.
--
-- The mockup that this implements:
--   manual/Screenshots/groovebox_8ch960samp_mockup.png
--
-- Visual rules:
--   - 8 lanes, each lane is a horizontal strip of 16 (or 32) cells
--   - Quadrant backgrounds: cells 1-4 white, 5-8 black, 9-12 white, 13-16 black
--   - For 32 steps: same rule scaled to 8 quadrants of 4
--   - Active trigger draws inside the cell, contrast-inverted vs. quadrant
--   - Velocity = block height
--   - Playhead = 2px amber border around the cell (preserves quadrant identity)
--   - Selection = purple wash + 2px purple border
--
-- Interaction:
--   - Click cell = toggle on/off
--   - Click + drag horizontally on same lane = range-select cells
--   - Shift+drag across lanes = rectangular cross-lane selection (TODO)
--   - Alt+click = select the whole quadrant containing that cell (TODO)
--   - Verb buttons act on the active selection

local vb = renoise.ViewBuilder()
local dialog = nil
local view = nil
local step_canvas = nil

-- ---------- model ----------

local NUM_LANES = 8
local MAX_STEPS = 16  -- toggleable to 32

-- triggers[lane][step] = bool ; velocity[lane][step] = 0..1
local triggers, velocity, lane_meta

local function reset_model()
  triggers, velocity, lane_meta = {}, {}, {}
  for r = 1, NUM_LANES do
    triggers[r] = {}
    velocity[r] = {}
    for s = 1, 32 do  -- always allocate 32 so toggling 16<->32 keeps state
      triggers[r][s] = false
      velocity[r][s] = 1.0
    end
    lane_meta[r] = {
      name = ({"kick-808.wav","snare-clap.wav","hat-closed.wav","hat-open.wav",
               "ride-cymbal.wav","bass-sub.wav","— empty —","perc-shot.wav"})[r] or "lane",
      muted = (r == 5),
      soloed = false,
      random = false,
    }
  end
  -- seed some triggers so the prototype is interesting on first open
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
end

-- selection: rectangle in lane/step coords, inclusive
-- {row1, step1, row2, step2} or nil
local selection = nil
-- transient drag state
local drag = nil  -- {anchor_row, anchor_step}

-- mock playhead (just for visual demo — no actual playback wiring yet)
local playhead_lane, playhead_step = 3, 7

-- ---------- canvas geometry ----------

local CANVAS_W = 940
local LANE_H   = 90
local CANVAS_H = NUM_LANES * LANE_H
local LANE_INSET_TOP = 6
local LANE_INNER_H   = LANE_H - 12  -- 78px

local function cell_w() return CANVAS_W / MAX_STEPS end

local function quadrant_is_dark(step)
  -- step 1..MAX_STEPS, returns true if it's a "black" quadrant (2 or 4)
  local q = math.floor((step - 1) / 4)
  return (q % 2) == 1
end

-- ---------- render ----------

local function rgb(r,g,b,a) return {r,g,b,a or 255} end
local C = {
  bg            = rgb(0x1e,0x1e,0x22),
  panel         = rgb(0x2a,0x2a,0x30),
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

local function draw_lane(ctx, row)
  local y0 = (row - 1) * LANE_H + LANE_INSET_TOP
  local cw = cell_w()
  local quad_cells = 4
  local quad_w = cw * quad_cells

  -- quadrant backgrounds
  for q = 0, (MAX_STEPS / 4) - 1 do
    local color = (q % 2 == 0) and C.quad_white or C.quad_black
    fill_rect(ctx, q * quad_w, y0, quad_w, LANE_INNER_H, color)
  end

  -- subtle cell grid (skip the heavy quadrant boundaries; those are implicit by color)
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

  -- triggers
  for s = 1, MAX_STEPS do
    if triggers[row][s] then
      local v = velocity[row][s] or 1.0
      if v < 0.05 then v = 0.05 end
      local block_h = math.floor(LANE_INNER_H * v) - 4
      if block_h < 4 then block_h = 4 end
      local block_y = y0 + LANE_INNER_H - block_h - 2
      local block_x = (s - 1) * cw + 4
      local block_w = cw - 8
      local color = quadrant_is_dark(s) and C.trig_on_black or C.trig_on_white
      fill_rect(ctx, block_x, block_y, block_w, block_h, color)
    end
  end

  -- mute overlay
  if lane_meta[row].muted then
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

  -- lane divider underneath
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
  if x < 0 or x >= CANVAS_W or y < 0 or y >= CANVAS_H then return nil, nil end
  local row = math.floor(y / LANE_H) + 1
  local local_y = y - (row - 1) * LANE_H
  if local_y < LANE_INSET_TOP or local_y > LANE_INSET_TOP + LANE_INNER_H then
    return nil, nil
  end
  local step = math.floor(x / cell_w()) + 1
  if step < 1 then step = 1 end
  if step > MAX_STEPS then step = MAX_STEPS end
  return row, step
end

local function set_selection(r1, s1, r2, s2)
  if r2 < r1 then r1, r2 = r2, r1 end
  if s2 < s1 then s1, s2 = s2, s1 end
  selection = { r1, s1, r2, s2 }
end

local function update_selection_label()
  if not selection then
    if view and view.selection_label then view.selection_label.text = "selection: (none)" end
    return
  end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  local cells = (r2 - r1 + 1) * (s2 - s1 + 1)
  local txt
  if r1 == r2 then
    txt = string.format("selection: row %d · steps %d–%d (%d cells)", r1, s1, s2, cells)
  else
    txt = string.format("selection: rows %d–%d · steps %d–%d (%d cells)", r1, r2, s1, s2, cells)
  end
  if view and view.selection_label then view.selection_label.text = txt end
end

local mouse_down_pos = nil
local mouse_did_drag = false

local function handle_mouse(ev)
  if ev.type == "exit" then return end
  local x, y = ev.position.x, ev.position.y

  if ev.type == "down" then
    local row, step = hit_test(x, y)
    if not row then return end
    mouse_down_pos = { row = row, step = step, x = x, y = y }
    mouse_did_drag = false
    drag = { anchor_row = row, anchor_step = step }
    set_selection(row, step, row, step)
    update_selection_label()
    if step_canvas then step_canvas:update() end

  elseif ev.type == "move" then
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
    if mouse_down_pos and not mouse_did_drag then
      -- a click (not a drag): toggle the trigger at the anchor cell
      local r, s = mouse_down_pos.row, mouse_down_pos.step
      triggers[r][s] = not triggers[r][s]
      if step_canvas then step_canvas:update() end
    end
    drag = nil
    mouse_down_pos = nil
    mouse_did_drag = false
  end
end

-- ---------- verbs (operate on selection) ----------

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

local function verb_invert()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) triggers[r][s] = not triggers[r][s] end)
  if step_canvas then step_canvas:update() end
end

local function verb_reverse()
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  for r = r1, r2 do
    local trig_copy, vel_copy = {}, {}
    for s = s1, s2 do
      trig_copy[s - s1 + 1] = triggers[r][s]
      vel_copy[s - s1 + 1]  = velocity[r][s]
    end
    local n = s2 - s1 + 1
    for s = s1, s2 do
      triggers[r][s] = trig_copy[n - (s - s1)]
      velocity[r][s] = vel_copy[n - (s - s1)]
    end
  end
  if step_canvas then step_canvas:update() end
end

local function nudge(direction)
  if not require_selection() then return end
  local r1, s1, r2, s2 = selection[1], selection[2], selection[3], selection[4]
  for r = r1, r2 do
    local trig_copy, vel_copy = {}, {}
    local n = s2 - s1 + 1
    for s = s1, s2 do
      trig_copy[s - s1 + 1] = triggers[r][s]
      vel_copy[s - s1 + 1]  = velocity[r][s]
    end
    for s = s1, s2 do
      local idx = (s - s1)
      local src = ((idx - direction) % n) + 1
      triggers[r][s] = trig_copy[src]
      velocity[r][s] = vel_copy[src]
    end
  end
  if step_canvas then step_canvas:update() end
end

local function verb_clear()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) triggers[r][s] = false end)
  if step_canvas then step_canvas:update() end
end

local function verb_fill()
  if not require_selection() then return end
  for_each_in_selection(function(r, s) triggers[r][s] = true end)
  if step_canvas then step_canvas:update() end
end

local function verb_stub(name)
  return function()
    if not require_selection() then return end
    renoise.app():show_status("Groovebox 8ch960samp: '" .. name .. "' verb is a stub — wires next pass")
  end
end

local function toggle_step_count()
  MAX_STEPS = (MAX_STEPS == 16) and 32 or 16
  selection = nil
  update_selection_label()
  if view and view.step_toggle_text then
    view.step_toggle_text.text = string.format("Steps: %d", MAX_STEPS)
  end
  if step_canvas then step_canvas:update() end
end

-- ---------- dialog ----------

local function lane_strip_left(row)
  local r = row
  local m = lane_meta[r]
  return vb:column{
    width = 160,
    style = "panel",
    height = LANE_H,
    vb:row{
      vb:button{ text="M", width=22, color = m.muted and {0xd8,0x50,0x60} or nil,
        notifier = function()
          lane_meta[r].muted = not lane_meta[r].muted
          if step_canvas then step_canvas:update() end
        end },
      vb:button{ text="S", width=22 },
      vb:button{ text="R", width=22 },
      vb:text{ text=string.format("  %02d", r), font="bold", style="strong" },
    },
    vb:text{ text = m.name, style = (m.name=="— empty —") and "disabled" or "normal" },
    vb:row{
      vb:text{ text=string.format("inst %02d", r), style="disabled" },
      vb:text{ text="  ", width=4 },
      vb:text{ text=string.format("trk %02d", r), style="disabled" },
    },
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
  for r = 1, NUM_LANES do
    table.insert(left_col_children,  lane_strip_left(r))
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

  local v = {}

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

  v.verb_palette = vb:row{
    style = "panel",
    vb:text{ text="verbs (act on selection):", style="strong" },
    vb:button{ text="←", width=30, notifier=function() nudge(-1) end },
    vb:button{ text="→", width=30, notifier=function() nudge( 1) end },
    vb:button{ text="invert",  notifier = verb_invert },
    vb:button{ text="reverse", notifier = verb_reverse },
    vb:button{ text="fill",    notifier = verb_fill },
    vb:button{ text="clear",   notifier = verb_clear },
    vb:button{ text="density−", notifier = verb_stub("density−") },
    vb:button{ text="density+", notifier = verb_stub("density+") },
    vb:button{ text="humanize", notifier = verb_stub("humanize") },
    vb:button{ text="roll",     notifier = verb_stub("roll") },
    vb:button{ text="copy",     notifier = verb_stub("copy") },
    vb:button{ text="paste",    notifier = verb_stub("paste") },
    vb:button{ text="euclid…",  notifier = verb_stub("euclid") },
    vb:button{ text="curve…",   notifier = verb_stub("apply curve") },
  }

  v.body = vb:row{
    vb:column(left_col_children),
    step_canvas,
    vb:column(right_col_children),
  }

  v.status = vb:row{
    style = "panel",
    v.selection_label,
    vb:text{ text = "  ·  click cell to toggle  ·  click+drag (same row or across rows) to select", style="disabled" },
  }

  v.root = vb:column{
    margin = 6,
    spacing = 4,
    v.transport_bar,
    v.verb_palette,
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
