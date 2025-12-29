-- PakettiMultitapExperiment.lua
-- Multitap Delay performance canvas with 10 live-jam control proposals

-- Global state (Lua 5.1 compatible)
vb = vb
PakettiMultitap_dialog = nil
PakettiMultitap_canvas = nil
PakettiMultitap_current_mode = 1
PakettiMultitap_canvas_width = 1280
PakettiMultitap_canvas_height = 480
PakettiMultitap_content_margin = 40
PakettiMultitap_autofocus_enabled = true
PakettiMultitap_devices_minimized = false
PakettiMultitap_swap_half_colors = false
PakettiMultitap_device_observers = {}
PakettiMultitap_update_timer = nil

-- Colors
PakettiMultitap_COLOR_BG_GRID = {32, 32, 48, 255}
PakettiMultitap_COLOR_ZERO = {160, 160, 160, 255}
PakettiMultitap_COLOR_BAR = {60, 180, 255, 220}
PakettiMultitap_COLOR_BAR_ALT = {255, 140, 60, 220}
PakettiMultitap_COLOR_BORDER = {200, 200, 200, 255}
PakettiMultitap_COLOR_TEXT = {220, 220, 220, 255}
PakettiMultitap_COLOR_PAN = {100, 220, 100, 220}
PakettiMultitap_MOUSE_IS_DOWN = false
PakettiMultitap_LAST_MOUSE_X = -1
PakettiMultitap_LAST_MOUSE_Y = -1

-- Proportional stairs state
PakettiMultitap_prop_divisions_items = {"2/1","1/1","1/2","1/3","1/4","1/6","1/8","1/12","1/16","1/24","1/32"}
PakettiMultitap_prop_divisions_beats = {8.0, 4.0, 2.0, 4.0/3.0, 1.0, 2.0/3.0, 0.5, 1.0/3.0, 0.25, 1.0/6.0, 0.125}
PakettiMultitap_prop_base_div_index = 2
PakettiMultitap_prop_ratio_steps = {
  {label = "x1", value = 1.0},
  {label = "3/4", value = 0.75},
  {label = "2/3", value = 2.0/3.0},
  {label = "1/2", value = 0.5},
  {label = "3/8", value = 0.375},
  {label = "1/3", value = 1.0/3.0},
  {label = "1/4", value = 0.25},
  {label = "1/6", value = 1.0/6.0},
  {label = "1/8", value = 0.125},
  {label = "1/12", value = 1.0/12.0},
  {label = "1/16", value = 1.0/16.0}
}
PakettiMultitap_prop_ratios = {1.0, 0.5, 0.25, 0.125}
PakettiMultitap_prop_patterns = {"Halves", "Triplets", "SwingDown", "Reverse", "WideHalves", "Stair34"}
PakettiMultitap_prop_pattern_index = 1

-- Linked taps state for proportional stairs
PakettiMultitap_link_enabled = false
PakettiMultitap_link_anchor_tap = 1
PakettiMultitap_link_flags = {false, false, false, false}

function PakettiMultitap_is_tap_linked(tap_index)
  if not PakettiMultitap_link_enabled then return false end
  if tap_index == PakettiMultitap_link_anchor_tap then return false end
  return PakettiMultitap_link_flags[tap_index] == true
end

function PakettiMultitap_set_link_flag(tap_index, value)
  PakettiMultitap_link_flags[tap_index] = (value == true)
end

function PakettiMultitap_nearest_allowed_ratio(target)
  local best_val = PakettiMultitap_prop_ratio_steps[1].value
  local best_err = math.abs(best_val - target)
  local i
  for i = 2, #PakettiMultitap_prop_ratio_steps do
    local v = PakettiMultitap_prop_ratio_steps[i].value
    local e = math.abs(v - target)
    if e < best_err then
      best_err = e
      best_val = v
    end
  end
  return best_val
end

-- General Tap Chain (parameter-level) state
PakettiMultitap_chain_enabled = false
PakettiMultitap_chain_anchor_tap = 1
PakettiMultitap_chain_link_flags = {false, false, false, false}
PakettiMultitap_chain_ratios = {1.0, 1.0, 1.0, 1.0}
PakettiMultitap_chain_param_observers = {}
PakettiMultitap_chain_applying = false

function PakettiMultitap_chain_is_linked(tap_index)
  if not PakettiMultitap_chain_enabled then return false end
  if tap_index == PakettiMultitap_chain_anchor_tap then return false end
  return PakettiMultitap_chain_link_flags[tap_index] == true
end

function PakettiMultitap_chain_set_flag(tap_index, value)
  PakettiMultitap_chain_link_flags[tap_index] = (value == true)
end

function PakettiMultitap_get_tap_delay_ms(tap_index)
  local l = PakettiMultitap_get_param(PakettiMultitap_param_index(tap_index, PakettiMultitap_SLOT.DLY_L)) or 0
  local r = PakettiMultitap_get_param(PakettiMultitap_param_index(tap_index, PakettiMultitap_SLOT.DLY_R)) or 0
  if l <= 0 and r > 0 then return r end
  if r <= 0 and l > 0 then return l end
  return (l + r) * 0.5
end

function PakettiMultitap_set_tap_delay_ms(tap_index, delay_ms)
  PakettiMultitap_set_param(PakettiMultitap_param_index(tap_index, PakettiMultitap_SLOT.DLY_L), delay_ms)
  PakettiMultitap_set_param(PakettiMultitap_param_index(tap_index, PakettiMultitap_SLOT.DLY_R), delay_ms)
end

function PakettiMultitap_chain_learn_from_current()
  if not PakettiMultitap_ensure_device_exists() then return end
  local song = renoise.song()
  local bpm = song.transport.bpm
  local beat_ms = 60000.0 / bpm
  local base_tap = PakettiMultitap_chain_anchor_tap
  local base_ms = PakettiMultitap_get_tap_delay_ms(base_tap)
  if base_ms <= 0 then base_ms = 1 end
  local i
  for i = 1, 4 do
    if i == base_tap then
      PakettiMultitap_chain_ratios[i] = 1.0
    else
      local ms = PakettiMultitap_get_tap_delay_ms(i)
      if ms <= 0 then ms = base_ms end
      local ratio = (ms / beat_ms) / (base_ms / beat_ms)
      PakettiMultitap_chain_ratios[i] = ratio
    end
  end
  renoise.app():show_status("Tap Chain: learned ratios from current delays")
end

function PakettiMultitap_chain_apply_from_anchor()
  if not PakettiMultitap_chain_enabled then return end
  if PakettiMultitap_chain_applying then return end
  if not PakettiMultitap_ensure_device_exists() then return end
  PakettiMultitap_chain_applying = true
  local song = renoise.song()
  local bpm = song.transport.bpm
  local beat_ms = 60000.0 / bpm
  local base_ms = PakettiMultitap_get_tap_delay_ms(PakettiMultitap_chain_anchor_tap)
  if base_ms <= 0 then base_ms = beat_ms end
  local base_beats = base_ms / beat_ms
  local t
  for t = 1, 4 do
    if PakettiMultitap_chain_is_linked(t) then
      local target_beats = base_beats * (PakettiMultitap_chain_ratios[t] or 1.0)
      local target_ms = target_beats * beat_ms
      PakettiMultitap_set_tap_delay_ms(t, target_ms)
    end
  end
  PakettiMultitap_chain_applying = false
end

function PakettiMultitap_chain_remove_observers()
  for parameter, fn in pairs(PakettiMultitap_chain_param_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(fn) then
        parameter.value_observable:remove_notifier(fn)
      end
    end)
  end
  PakettiMultitap_chain_param_observers = {}
end

function PakettiMultitap_chain_setup_observers()
  PakettiMultitap_chain_remove_observers()
  if not PakettiMultitap_chain_enabled then return end
  local device = PakettiMultitap_get_device()
  if not device then return end
  local idx_l = PakettiMultitap_param_index(PakettiMultitap_chain_anchor_tap, PakettiMultitap_SLOT.DLY_L)
  local idx_r = PakettiMultitap_param_index(PakettiMultitap_chain_anchor_tap, PakettiMultitap_SLOT.DLY_R)
  local p_l = device.parameters[idx_l]
  local p_r = device.parameters[idx_r]
  if p_l and p_l.value_observable then
    local fnl = function()
      if PakettiMultitap_chain_applying then return end
      PakettiMultitap_chain_apply_from_anchor()
      if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
    end
    p_l.value_observable:add_notifier(fnl)
    PakettiMultitap_chain_param_observers[p_l] = fnl
  end
  if p_r and p_r.value_observable then
    local fnr = function()
      if PakettiMultitap_chain_applying then return end
      PakettiMultitap_chain_apply_from_anchor()
      if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
    end
    p_r.value_observable:add_notifier(fnr)
    PakettiMultitap_chain_param_observers[p_r] = fnr
  end
end

function PakettiMultitap_chain_set_enabled(v)
  PakettiMultitap_chain_enabled = (v == true)
  if PakettiMultitap_chain_enabled then
    PakettiMultitap_chain_learn_from_current()
    PakettiMultitap_chain_setup_observers()
  else
    PakettiMultitap_chain_remove_observers()
  end
end

-- Simple canvas font (subset borrowed from PakettiCanvasExperiments)
function PakettiMultitap_draw_letter_A(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y + size); ctx:line_to(x + size/2, y); ctx:line_to(x + size, y + size);
  ctx:move_to(x + size/4, y + size/2); ctx:line_to(x + 3*size/4, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_letter_B(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x, y + size); ctx:line_to(x + 3*size/4, y + size);
  ctx:line_to(x + 3*size/4, y + size/2); ctx:line_to(x, y + size/2); ctx:line_to(x + 3*size/4, y + size/2);
  ctx:line_to(x + 3*size/4, y); ctx:line_to(x, y); ctx:stroke()
end
function PakettiMultitap_draw_letter_D(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x, y + size); ctx:line_to(x + 3*size/4, y + size);
  ctx:line_to(x + size, y + 3*size/4); ctx:line_to(x + size, y + size/4); ctx:line_to(x + 3*size/4, y); ctx:line_to(x, y); ctx:stroke()
end
function PakettiMultitap_draw_letter_C(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size, y); ctx:line_to(x, y); ctx:line_to(x, y + size); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_letter_F(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y + size); ctx:line_to(x, y); ctx:line_to(x + size, y);
  ctx:move_to(x, y + size/2); ctx:line_to(x + 3*size/4, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_letter_L(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x, y + size); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_letter_E(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size, y); ctx:line_to(x, y); ctx:line_to(x, y + size); ctx:line_to(x + size, y + size);
  ctx:move_to(x, y + size/2); ctx:line_to(x + 3*size/4, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_letter_N(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y + size); ctx:line_to(x, y); ctx:line_to(x + size, y + size); ctx:line_to(x + size, y); ctx:stroke()
end
function PakettiMultitap_draw_letter_P(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y + size); ctx:line_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size, y + size/2); ctx:line_to(x, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_letter_R(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y + size); ctx:line_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size, y + size/2); ctx:line_to(x, y + size/2); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_letter_T(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:move_to(x + size/2, y); ctx:line_to(x + size/2, y + size); ctx:stroke()
end
function PakettiMultitap_draw_letter_Y(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size/2, y + size/2); ctx:line_to(x + size, y);
  ctx:move_to(x + size/2, y + size/2); ctx:line_to(x + size/2, y + size); ctx:stroke()
end
function PakettiMultitap_draw_letter_G(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size, y); ctx:line_to(x, y); ctx:line_to(x, y + size); ctx:line_to(x + size, y + size);
  ctx:line_to(x + size, y + size/2); ctx:line_to(x + size/2, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_letter_H(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x, y + size); ctx:move_to(x + size, y); ctx:line_to(x + size, y + size);
  ctx:move_to(x, y + size/2); ctx:line_to(x + size, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_letter_I(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:move_to(x + size/2, y); ctx:line_to(x + size/2, y + size);
  ctx:move_to(x, y + size); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_letter_K(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x, y + size);
  ctx:move_to(x + size, y); ctx:line_to(x, y + size/2); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_space(ctx, x, y, size) end

-- Digits 0-9 for labels like TAP 1, 2, 3, 4
function PakettiMultitap_draw_digit_0(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size, y + size);
  ctx:line_to(x, y + size); ctx:line_to(x, y); ctx:stroke()
end
function PakettiMultitap_draw_digit_1(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size/2, y); ctx:line_to(x + size/2, y + size); ctx:stroke()
end
function PakettiMultitap_draw_digit_2(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size, y + size/2);
  ctx:line_to(x, y + size/2); ctx:line_to(x, y + size); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_digit_3(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size, y + size/2);
  ctx:line_to(x, y + size/2); ctx:move_to(x + size, y + size/2); ctx:line_to(x + size, y + size);
  ctx:line_to(x, y + size); ctx:stroke()
end
function PakettiMultitap_draw_digit_4(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x, y + size/2); ctx:line_to(x + size, y + size/2);
  ctx:move_to(x + size, y); ctx:line_to(x + size, y + size); ctx:stroke()
end
function PakettiMultitap_draw_digit_5(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size, y); ctx:line_to(x, y); ctx:line_to(x, y + size/2);
  ctx:line_to(x + size, y + size/2); ctx:line_to(x + size, y + size); ctx:line_to(x, y + size); ctx:stroke()
end
function PakettiMultitap_draw_digit_6(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size, y); ctx:line_to(x, y); ctx:line_to(x, y + size);
  ctx:line_to(x + size, y + size); ctx:line_to(x + size, y + size/2); ctx:line_to(x, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_digit_7(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size/2, y + size); ctx:stroke()
end
function PakettiMultitap_draw_digit_8(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x + size, y); ctx:line_to(x + size, y + size);
  ctx:line_to(x, y + size); ctx:line_to(x, y); ctx:move_to(x, y + size/2); ctx:line_to(x + size, y + size/2); ctx:stroke()
end
function PakettiMultitap_draw_digit_9(ctx, x, y, size)
  ctx:begin_path(); ctx:move_to(x + size, y + size); ctx:line_to(x + size, y); ctx:line_to(x, y);
  ctx:line_to(x, y + size/2); ctx:line_to(x + size, y + size/2); ctx:stroke()
end

PakettiMultitap_letter_functions = {
  A = PakettiMultitap_draw_letter_A,
  B = PakettiMultitap_draw_letter_B,
  D = PakettiMultitap_draw_letter_D,
  C = PakettiMultitap_draw_letter_C,
  E = PakettiMultitap_draw_letter_E,
  G = PakettiMultitap_draw_letter_G,
  H = PakettiMultitap_draw_letter_H,
  I = PakettiMultitap_draw_letter_I,
  K = PakettiMultitap_draw_letter_K,
  F = PakettiMultitap_draw_letter_F,
  L = PakettiMultitap_draw_letter_L,
  N = PakettiMultitap_draw_letter_N,
  P = PakettiMultitap_draw_letter_P,
  R = PakettiMultitap_draw_letter_R,
  T = PakettiMultitap_draw_letter_T,
  Y = PakettiMultitap_draw_letter_Y,
  ["0"] = PakettiMultitap_draw_digit_0,
  ["1"] = PakettiMultitap_draw_digit_1,
  ["2"] = PakettiMultitap_draw_digit_2,
  ["3"] = PakettiMultitap_draw_digit_3,
  ["4"] = PakettiMultitap_draw_digit_4,
  ["5"] = PakettiMultitap_draw_digit_5,
  ["6"] = PakettiMultitap_draw_digit_6,
  ["7"] = PakettiMultitap_draw_digit_7,
  ["8"] = PakettiMultitap_draw_digit_8,
  ["9"] = PakettiMultitap_draw_digit_9,
  [" "] = PakettiMultitap_draw_space
}

function PakettiMultitap_draw_canvas_text(ctx, text, x, y, size)
  local cx = x
  local spacing = size * 1.2
  local i
  for i = 1, #text do
    local ch = text:sub(i, i):upper()
    local fn = PakettiMultitap_letter_functions[ch]
    if fn then fn(ctx, cx, y, size) end
    cx = cx + spacing
  end
end

function PakettiMultitap_draw_vertical_text(ctx, text, cx, top_y, size)
  local spacing = size + 4
  local i
  for i = 1, #text do
    local ch = text:sub(i, i):upper()
    local fn = PakettiMultitap_letter_functions[ch]
    if fn then fn(ctx, cx - size/2, top_y + (i - 1) * spacing, size) end
  end
end

-- Tap base colors (R,G,B, no alpha)
PakettiMultitap_TAP_COLORS = {
  {160, 80, 200},   -- TAP1 deep purple
  {220, 200, 60},   -- TAP2 yellow
  {100, 220, 100},  -- TAP3 green
  {80, 140, 240}    -- TAP4 blue
}

function PakettiMultitap_clamp8(v)
  if v < 0 then return 0 end
  if v > 255 then return 255 end
  return math.floor(v + 0.5)
end

-- Dynamic update: parameter observers
function PakettiMultitap_setup_parameter_observers()
  PakettiMultitap_remove_parameter_observers()
  local device = PakettiMultitap_get_device()
  if not device then return end
  local i
  for i = 1, #device.parameters do
    local p = device.parameters[i]
    if p and p.value_observable then
      local observer = function()
        if PakettiMultitap_dialog and PakettiMultitap_dialog.visible and PakettiMultitap_canvas then
          PakettiMultitap_canvas:update()
        end
      end
      p.value_observable:add_notifier(observer)
      PakettiMultitap_device_observers[p] = observer
    end
  end
end

function PakettiMultitap_remove_parameter_observers()
  for parameter, observer in pairs(PakettiMultitap_device_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  PakettiMultitap_device_observers = {}
end

-- Fallback periodic updater (in case some changes don't fire observers)
function PakettiMultitap_setup_update_timer()
  if PakettiMultitap_update_timer then
    renoise.tool():remove_timer(PakettiMultitap_update_timer)
  end
  PakettiMultitap_update_timer = function()
    if PakettiMultitap_dialog and PakettiMultitap_dialog.visible and PakettiMultitap_canvas then
      PakettiMultitap_canvas:update()
    end
  end
  renoise.tool():add_timer(PakettiMultitap_update_timer, 200)
end

function PakettiMultitap_remove_update_timer()
  if PakettiMultitap_update_timer then
    pcall(function() renoise.tool():remove_timer(PakettiMultitap_update_timer) end)
    PakettiMultitap_update_timer = nil
  end
end

function PakettiMultitap_shade_color(rgb, factor, alpha)
  local r = PakettiMultitap_clamp8(rgb[1] * factor)
  local g = PakettiMultitap_clamp8(rgb[2] * factor)
  local b = PakettiMultitap_clamp8(rgb[3] * factor)
  local a = alpha or 255
  return {r, g, b, a}
end

function PakettiMultitap_lerp(a, b, t)
  return a + (b - a) * t
end

function PakettiMultitap_lerp_color(c1, c2, t)
  return {
    PakettiMultitap_clamp8(PakettiMultitap_lerp(c1[1], c2[1], t)),
    PakettiMultitap_clamp8(PakettiMultitap_lerp(c1[2], c2[2], t)),
    PakettiMultitap_clamp8(PakettiMultitap_lerp(c1[3], c2[3], t)),
    PakettiMultitap_clamp8(PakettiMultitap_lerp((c1[4] or 255), (c2[4] or 255), t))
  }
end

-- Simple vertical gradient fill using many small horizontal rects
function PakettiMultitap_fill_rect_vertical_gradient(ctx, x, y, w, h, top_color, bottom_color)
  local steps = math.max(1, math.floor(h))
  local i
  for i = 0, steps - 1 do
    local t = i / (steps - 1)
    local c = PakettiMultitap_lerp_color(top_color, bottom_color, t)
    ctx.fill_color = c
    ctx:fill_rect(x, y + i, w, 1)
  end
end

-- Computed content rect
function PakettiMultitap_get_content_rect()
  local x = PakettiMultitap_content_margin
  local y = PakettiMultitap_content_margin
  local w = PakettiMultitap_canvas_width - (PakettiMultitap_content_margin * 2)
  local h = PakettiMultitap_canvas_height - (PakettiMultitap_content_margin * 2)
  return x, y, w, h
end

-- Utility: ensure selected device exists and is Multitap
function PakettiMultitap_ensure_device_exists()
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return false
  end

  local track = song.selected_track
  -- Try to find existing Multitap on selected track
  local first_multitap_index = nil
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/Multitap" then
      first_multitap_index = i
      break
    end
  end

  if not first_multitap_index then
    print("PakettiMultitap: inserting Multitap device")
    local success, err = pcall(function()
      track:insert_device_at("Audio/Effects/Native/Multitap", #track.devices + 1)
    end)
    if not success then
      renoise.app():show_status("Failed to insert Multitap: " .. tostring(err))
      return false
    end
    first_multitap_index = #track.devices
  end

  -- Focus and maximize
  local dev = track.devices[first_multitap_index]
  if dev then
    dev.display_name = "Multitap Delay"
    dev.is_maximized = true
    if PakettiMultitap_autofocus_enabled then
      song.selected_device_index = first_multitap_index
      renoise.app().window.lower_frame_is_visible = true
      renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
    end
    return true
  end
  return false
end

-- Helpers to access Multitap parameters by tap and slot
-- Base index map per tap (Tap1 starts at 3)
function PakettiMultitap_base_index_for_tap(tap_index)
  return 3 + (tap_index - 1) * 22
end

-- Slot offsets inside a tap block
PakettiMultitap_SLOT = {
  DLY_L = 0,        -- Delay Left
  DLY_R = 1,        -- Delay Right
  IN_AMT = 2,       -- Input Amount
  OUT_AMT = 3,      -- Amount
  FB_L = 4,         -- Left Feedback
  FB_R = 5,         -- Right Feedback
  PINGPONG = 6,     -- Ping Pong / Invert Feedback
  PREV_IN = 7,      -- Previous Tap Input
  PAN_L = 8,        -- Left Pan
  PAN_R = 9,        -- Right Pan
  FLT_MODE = 10,    -- Filter Mode
  FLT_TYPE = 11,    -- Filter Type
  FLT_FREQ = 12,    -- Filter Freq
  FLT_Q = 13,       -- Filter Q (not used)
  FLT_DRV = 14,     -- Filter Drive
  LINE_SYNC = 15,   -- Line Sync On/Off
  SYNC_L_DLY = 16,  -- Sync L DelayTime (enum)
  SYNC_R_DLY = 17,  -- Sync R DelayTime (enum)
  SYNC_L_TIME = 18, -- L Sync Time
  SYNC_R_TIME = 19, -- R Sync Time
  L_OFFSET = 20,    -- L Sync Offset
  R_OFFSET = 21     -- R Sync Offset
}

function PakettiMultitap_param_index(tap_index, slot)
  return PakettiMultitap_base_index_for_tap(tap_index) + slot
end

-- Safe parameter getters/setters with scaling (0..1 normalized -> param range)
function PakettiMultitap_get_device()
  local song = renoise.song()
  if not song or not song.selected_track then return nil end
  local track = song.selected_track
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/Multitap" then
      return device, i
    end
  end
  return nil
end

function PakettiMultitap_set_param(idx, value)
  local device = PakettiMultitap_get_device()
  if not device then return end
  local p = device.parameters[idx]
  if not p then return end
  local v = value
  if v < p.value_min then v = p.value_min end
  if v > p.value_max then v = p.value_max end
  p.value = v
end

function PakettiMultitap_set_param_normalized(idx, norm)
  local device = PakettiMultitap_get_device()
  if not device then return end
  local p = device.parameters[idx]
  if not p then return end
  if norm < 0 then norm = 0 end
  if norm > 1 then norm = 1 end
  local v = p.value_min + (p.value_max - p.value_min) * norm
  p.value = v
end

function PakettiMultitap_get_param(idx)
  local device = PakettiMultitap_get_device()
  if not device then return 0 end
  local p = device.parameters[idx]
  if not p then return 0 end
  return p.value
end

function PakettiMultitap_get_param_normalized(idx)
  local device = PakettiMultitap_get_device()
  if not device then return 0 end
  local p = device.parameters[idx]
  if not p then return 0 end
  if p.value_max == p.value_min then return 0 end
  return (p.value - p.value_min) / (p.value_max - p.value_min)
end

-- Draw primitives
function PakettiMultitap_draw_grid(ctx)
  local x, y, w, h = PakettiMultitap_get_content_rect()
  ctx:clear_rect(0, 0, PakettiMultitap_canvas_width, PakettiMultitap_canvas_height)
  ctx.stroke_color = PakettiMultitap_COLOR_BG_GRID
  ctx.line_width = 1
  local v_lines = 8
  local h_lines = 8
  local i
  for i = 0, v_lines do
    local gx = x + (i / v_lines) * w
    ctx:begin_path(); ctx:move_to(gx, y); ctx:line_to(gx, y + h); ctx:stroke()
  end
  for i = 0, h_lines do
    local gy = y + (i / h_lines) * h
    ctx:begin_path(); ctx:move_to(x, gy); ctx:line_to(x + w, gy); ctx:stroke()
  end
  ctx.stroke_color = PakettiMultitap_COLOR_BORDER
  ctx.line_width = 2
  ctx:begin_path(); ctx:rect(x, y, w, h); ctx:stroke()
end

-- Mode descriptors (10 proposals)
PakettiMultitap_MODE_NAMES = {
  "1) Delay L/R",
  "2) Feedback L/R",
  "3) Pan Spread",
  "4) Ping-Pong Toggles",
  "5) Input/Amount Mixer",
  "6) Filter Frequency",
  "7) Filter Type/Mode",
  "8) Sync Grid",
  "9) Global XY: Time/FB",
  "10) Scenes/Random",
  "11) Proportional Stairs",
  "12) Delay Symm",
  "13) Feedback Symm",
  "14) Per-Side D/F/P"
}

-- Render per mode
function PakettiMultitap_render(ctx)
  PakettiMultitap_draw_grid(ctx)
  local x, y, w, h = PakettiMultitap_get_content_rect()
  local taps = 4
  local channels = 2 -- L,R
  local groups = taps * channels -- 8 columns
  local col_w = w / groups
  local i

  if PakettiMultitap_current_mode == 1 then
    -- Delay + Feedback per channel (side-by-side sub-columns within each channel column)
    local dly_color = PakettiMultitap_swap_half_colors and PakettiMultitap_COLOR_BAR_ALT or PakettiMultitap_COLOR_BAR
    local fb_color = PakettiMultitap_swap_half_colors and PakettiMultitap_COLOR_BAR or PakettiMultitap_COLOR_BAR_ALT
    local sub_gap = 0
    for i = 1, taps do
      local dly_l = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_L))
      local dly_r = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_R))
      local fb_l = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_L))
      local fb_r = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_R))
      local idx_l = (i - 1) * 2
      local idx_r = idx_l + 1
      local groups = 8
      local col_group_w = w / groups
      local bx_l = x + idx_l * col_group_w
      local bx_r = x + idx_r * col_group_w
      local bw = col_group_w
      local pad = 0
      bx_l = bx_l + pad; bx_r = bx_r + pad; bw = bw - pad * 2

      -- left side: two sub-columns (Delay | Feedback)
      local sub_w = (bw - sub_gap) / 2
      -- Compute gradient colors based on tap color family
      local base_rgb = PakettiMultitap_TAP_COLORS[i]
      local dly_top = PakettiMultitap_shade_color(base_rgb, 1.20, 255)
      local dly_bot = PakettiMultitap_shade_color(base_rgb, 0.80, 255)
      local fb_top  = PakettiMultitap_shade_color(base_rgb, 0.90, 255)
      local fb_bot  = PakettiMultitap_shade_color(base_rgb, 0.60, 255)
      if PakettiMultitap_swap_half_colors then
        -- swap roles if user toggled
        local tt, bb = dly_top, dly_bot
        dly_top, dly_bot = fb_top, fb_bot
        fb_top, fb_bot = tt, bb
      end
      -- left delay
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_l, y + (h - dly_l * h), sub_w, dly_l * h, dly_top, dly_bot)
      -- left feedback
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_l + sub_w + sub_gap, y + (h - fb_l * h), sub_w, fb_l * h, fb_top, fb_bot)

      -- right side: two sub-columns (Delay | Feedback)
      -- right delay
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_r, y + (h - dly_r * h), sub_w, dly_r * h, dly_top, dly_bot)
      -- right feedback
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_r + sub_w + sub_gap, y + (h - fb_r * h), sub_w, fb_r * h, fb_top, fb_bot)

      -- Labels above each sub-column
      ctx.stroke_color = PakettiMultitap_COLOR_TEXT
      ctx.line_width = 2
      local label_color
      if i == 1 then label_color = {160, 80, 200, 255} -- deep purple
      elseif i == 2 then label_color = {220, 200, 60, 255} -- yellow
      elseif i == 3 then label_color = {100, 220, 100, 255} -- green
      else label_color = {80, 140, 240, 255} -- blue
      end
      ctx.stroke_color = {255,255,255,255}
      PakettiMultitap_draw_vertical_text(ctx, "TAP"..i.." LEFT DELAY", bx_l + sub_w/2, y + 8, 8)
      PakettiMultitap_draw_vertical_text(ctx, "TAP"..i.." LEFT FEEDBACK", bx_l + sub_w + sub_gap + sub_w/2, y + 8, 8)
      PakettiMultitap_draw_vertical_text(ctx, "TAP"..i.." RIGHT DELAY", bx_r + sub_w/2, y + 8, 8)
      PakettiMultitap_draw_vertical_text(ctx, "TAP"..i.." RIGHT FEEDBACK", bx_r + sub_w + sub_gap + sub_w/2, y + 8, 8)
    end
  elseif PakettiMultitap_current_mode == 2 then
    -- Feedback per channel (8 columns)
    for i = 1, taps do
      local nl = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_L))
      local nr = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_R))
      local idx_l = (i - 1) * 2
      local idx_r = idx_l + 1
      local groups = 8
      local col_group_w = w / groups
      local bx_l = x + idx_l * col_group_w
      local bx_r = x + idx_r * col_group_w
      local bw = col_group_w
      local pad = 0
      bx_l = bx_l + pad; bx_r = bx_r + pad; bw = bw - pad * 2
      local base_rgb = PakettiMultitap_TAP_COLORS[i]
      local top_c = PakettiMultitap_shade_color(base_rgb, 0.90, 255)
      local bot_c = PakettiMultitap_shade_color(base_rgb, 0.60, 255)
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_l, y + h - nl * h, bw, nl * h, top_c, bot_c)
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_r, y + h - nr * h, bw, nr * h, top_c, bot_c)
      ctx.stroke_color = PakettiMultitap_COLOR_TEXT
      ctx.line_width = 2
      local label_y = y + 8
      PakettiMultitap_draw_vertical_text(ctx, "TAP "..i.." LEFT FEEDBACK", bx_l + bw/2, label_y, 8)
      PakettiMultitap_draw_vertical_text(ctx, "TAP "..i.." RIGHT FEEDBACK", bx_r + bw/2, label_y, 8)
    end
  elseif PakettiMultitap_current_mode == 3 then
    -- Pan per channel (8 columns), vertical magnitude from center
    for i = 1, taps do
      local nl = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.PAN_L))
      local nr = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.PAN_R))
      local idx_l = (i - 1) * 2
      local idx_r = idx_l + 1
      local groups = 8
      local col_group_w = w / groups
      local bx_l = x + idx_l * col_group_w
      local bx_r = x + idx_r * col_group_w
      local bw = col_group_w
      local pad = 0
      bx_l = bx_l + pad; bx_r = bx_r + pad; bw = bw - pad * 2
      local mid = y + h * 0.5
      local lh = nl * (h * 0.45)
      local rh = nr * (h * 0.45)
      local base_rgb = PakettiMultitap_TAP_COLORS[i]
      local top_c = PakettiMultitap_shade_color(base_rgb, 1.10, 255)
      local bot_c = PakettiMultitap_shade_color(base_rgb, 0.75, 255)
      -- left pan (upwards from center)
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_l, mid - lh, bw, lh, top_c, bot_c)
      -- right pan (downwards from center)
      PakettiMultitap_fill_rect_vertical_gradient(ctx, bx_r, mid, bw, rh, top_c, bot_c)
      ctx.stroke_color = PakettiMultitap_COLOR_TEXT
      ctx.line_width = 2
      PakettiMultitap_draw_vertical_text(ctx, "TAP "..i.." LEFT PAN", bx_l + bw/2, y + 8, 8)
      PakettiMultitap_draw_vertical_text(ctx, "TAP "..i.." RIGHT PAN", bx_r + bw/2, y + 8, 8)
    end
  elseif PakettiMultitap_current_mode == 14 then
    -- Per-Side D/F/P: each of 8 columns split into 3 stacked sub-bars (Delay/Feedback/Pan)
    local rows = 3
    local row_h = h / rows
    local labels = {"DELAY", "FEEDBACK", "PAN"}
    local r
    for i = 1, taps do
      local idx_l = (i - 1) * 2
      local idx_r = idx_l + 1
      local bx_l = x + idx_l * col_w
      local bx_r = x + idx_r * col_w
      local bw = col_w
      local pad = 0
      bx_l = bx_l + pad; bx_r = bx_r + pad; bw = bw - pad * 2

      -- left side
      local vals_l = {
        PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_L)),
        PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_L)),
        PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.PAN_L))
      }
      -- right side
      local vals_r = {
        PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_R)),
        PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_R)),
        PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.PAN_R))
      }

      for r = 1, rows do
        local by = y + (r - 1) * row_h
        -- left column cell
        local vh_l = vals_l[r] * row_h
        if r == 1 then ctx.fill_color = PakettiMultitap_COLOR_BAR
        elseif r == 2 then ctx.fill_color = PakettiMultitap_COLOR_BAR_ALT
        else ctx.fill_color = PakettiMultitap_COLOR_PAN end
        ctx:fill_rect(bx_l, by + (row_h - vh_l), bw, vh_l)

        -- right column cell
        local vh_r = vals_r[r] * row_h
        if r == 1 then ctx.fill_color = PakettiMultitap_COLOR_BAR
        elseif r == 2 then ctx.fill_color = PakettiMultitap_COLOR_BAR_ALT
        else ctx.fill_color = PakettiMultitap_COLOR_PAN end
        ctx:fill_rect(bx_r, by + (row_h - vh_r), bw, vh_r)

        -- labels on top area of each cell
        ctx.stroke_color = PakettiMultitap_COLOR_TEXT
        ctx.line_width = 2
        PakettiMultitap_draw_vertical_text(ctx, "TAP "..i.." LEFT "..labels[r], bx_l + bw/2, by + 4, 8)
        PakettiMultitap_draw_vertical_text(ctx, "TAP "..i.." RIGHT "..labels[r], bx_r + bw/2, by + 4, 8)
      end
    end
  elseif PakettiMultitap_current_mode == 4 then
    -- Ping-Pong toggles (draw button squares)
    ctx.stroke_color = PakettiMultitap_COLOR_BORDER
    ctx.line_width = 2
    for i = 1, taps do
      local bx = x + (i - 1) * col_w + col_w * 0.25
      local by = y + h * 0.25
      local bw = col_w * 0.5
      local bh = h * 0.5
      ctx:begin_path(); ctx:rect(bx, by, bw, bh); ctx:stroke()
      local val = PakettiMultitap_get_param(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.PINGPONG))
      if val > 0.5 then
        ctx.fill_color = {120, 255, 120, 160}
      else
        ctx.fill_color = {255, 120, 120, 120}
      end
      ctx:fill_rect(bx + 4, by + 4, bw - 8, bh - 8)
    end
  elseif PakettiMultitap_current_mode == 5 then
    -- Input/Amount Mixer (two side-by-side bars)
    for i = 1, taps do
      local nin = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.IN_AMT))
      local nout = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.OUT_AMT))
      local bx = x + (i - 1) * col_w + 8
      local bw = col_w - 16
      local half = bw * 0.48
      ctx.fill_color = PakettiMultitap_COLOR_BAR
      ctx:fill_rect(bx, y + h - nin * h, half, nin * h)
      ctx.fill_color = PakettiMultitap_COLOR_BAR_ALT
      ctx:fill_rect(bx + bw - half, y + h - nout * h, half, nout * h)
    end
  elseif PakettiMultitap_current_mode == 6 then
    -- Filter Frequency (vertical bars)
    ctx.fill_color = PakettiMultitap_COLOR_BAR
    for i = 1, taps do
      local nf = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FLT_FREQ))
      local bar_h = nf * h
      local bx = x + (i - 1) * col_w + 8
      local bw = col_w - 16
      ctx:fill_rect(bx, y + h - bar_h, bw, bar_h)
    end
  elseif PakettiMultitap_current_mode == 7 then
    -- Filter Type/Mode (draw two stacked selectors)
    ctx.stroke_color = PakettiMultitap_COLOR_BORDER
    ctx.line_width = 2
    for i = 1, taps do
      local bx = x + (i - 1) * col_w + 8
      local bw = col_w - 16
      local seg_h = (h - 16) / 4
      local j
      for j = 0, 3 do
        local by = y + 8 + j * seg_h
        ctx:begin_path(); ctx:rect(bx, by, bw, seg_h - 6); ctx:stroke()
      end
      local mode_val = PakettiMultitap_get_param(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FLT_MODE))
      local type_val = PakettiMultitap_get_param(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FLT_TYPE))
      local mode_sel = math.floor((mode_val or 0) + 0.5)
      local type_sel = math.floor((type_val or 0) + 0.5)
      ctx.fill_color = {120, 200, 255, 120}
      ctx:fill_rect(bx + 4, y + 8 + mode_sel * seg_h + 4, bw - 8, seg_h - 14)
      ctx.fill_color = {255, 200, 120, 120}
      ctx:fill_rect(bx + 4, y + 8 + type_sel * seg_h + 4, bw - 8, seg_h - 14)
    end
  elseif PakettiMultitap_current_mode == 12 then
    -- Delay Symm (both L/R averaged)
    ctx.fill_color = PakettiMultitap_COLOR_BAR
    for i = 1, taps do
      local n1 = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_L))
      local n2 = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_R))
      local norm = (n1 + n2) * 0.5
      local bar_h = norm * h
      local bx = x + (i - 1) * col_w + 8
      local bw = col_w - 16
      ctx:fill_rect(bx, y + h - bar_h, bw, bar_h)
    end
  elseif PakettiMultitap_current_mode == 13 then
    -- Feedback Symm (average)
    ctx.fill_color = PakettiMultitap_COLOR_BAR
    for i = 1, taps do
      local n1 = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_L))
      local n2 = PakettiMultitap_get_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_R))
      local norm = (n1 + n2) * 0.5
      local bar_h = norm * h
      local bx = x + (i - 1) * col_w + 8
      local bw = col_w - 16
      ctx:fill_rect(bx, y + h - bar_h, bw, bar_h)
    end
  elseif PakettiMultitap_current_mode == 8 then
    -- Sync Grid (enable Line Sync and pick L/R times)
    ctx.stroke_color = PakettiMultitap_COLOR_BORDER
    ctx.line_width = 1
    local cols = 8
    local rows = 2
    local cell_w = (w - 16) / (taps * cols)
    local cell_h = (h - 16) / rows
    local ti, ci, ri
    for ti = 1, taps do
      for ri = 0, rows - 1 do
        for ci = 0, cols - 1 do
          local bx = x + 8 + (ti - 1) * cols * cell_w + ci * cell_w
          local by = y + 8 + ri * cell_h
          ctx:begin_path(); ctx:rect(bx, by, cell_w - 4, cell_h - 6); ctx:stroke()
        end
      end
    end
  elseif PakettiMultitap_current_mode == 9 then
    -- Global XY pad: X scales delay time, Y scales feedback
    ctx.stroke_color = PakettiMultitap_COLOR_BORDER
    ctx.line_width = 2
    ctx:begin_path(); ctx:rect(x + w * 0.1, y + h * 0.1, w * 0.8, h * 0.8); ctx:stroke()
    if PakettiMultitap_MOUSE_IS_DOWN then
      ctx.stroke_color = {255, 0, 0, 255}
      ctx.line_width = 2
      ctx:begin_path(); ctx:arc(PakettiMultitap_LAST_MOUSE_X, PakettiMultitap_LAST_MOUSE_Y, 4, 0, math.pi * 2, false); ctx:stroke()
    end
  elseif PakettiMultitap_current_mode == 10 then
    -- Scenes / Randomizers: draw buttons outline only (actual buttons are in UI panel)
    ctx.stroke_color = PakettiMultitap_COLOR_BORDER
    ctx.line_width = 1
    local i2
    for i2 = 0, 9 do
      local bx = x + 8 + (i2 % 5) * (w - 16) / 5
      local by = y + 8 + math.floor(i2 / 5) * (h - 16) / 2
      ctx:begin_path(); ctx:rect(bx, by, (w - 16) / 5 - 10, (h - 16) / 2 - 10); ctx:stroke()
    end
  end
  
  if PakettiMultitap_current_mode == 11 then
    -- Proportional stairs: 4 columns (taps), rows = ratio steps
    local steps = #PakettiMultitap_prop_ratio_steps
    local col_w = w / 4
    local row_h = h / steps
    local ti, si
    ctx.stroke_color = PakettiMultitap_COLOR_BORDER
    ctx.line_width = 1
    for ti = 1, 4 do
      for si = 1, steps do
        local bx = x + (ti - 1) * col_w + 4
        local by = y + (si - 1) * row_h + 4
        local bw = col_w - 8
        local bh = row_h - 8
        ctx:begin_path(); ctx:rect(bx, by, bw, bh); ctx:stroke()
        local target_val = PakettiMultitap_prop_ratio_steps[si].value
        if math.abs((PakettiMultitap_prop_ratios[ti] or 0) - target_val) < 0.0001 then
          ctx.fill_color = {120, 200, 120, 120}
          ctx:fill_rect(bx + 2, by + 2, bw - 4, bh - 4)
        end
      end
    end
    -- labels on right side
    ctx.stroke_color = PakettiMultitap_COLOR_TEXT
    ctx.line_width = 2
    local si2
    for si2 = 1, steps do
      local lbl = PakettiMultitap_prop_ratio_steps[si2].label
      local ty = y + (si2 - 1) * row_h + row_h * 0.5
      ctx:begin_path(); ctx:move_to(x + w + 6, ty); ctx:line_to(x + w + 6, ty); ctx:stroke() -- anchor
      -- simple label ticks drawn as short dashes; full text labels are not rendered by canvas API, so skipping
    end
    -- Highlight anchor tap if linking is enabled
    if PakettiMultitap_link_enabled then
      local ax = x + (PakettiMultitap_link_anchor_tap - 1) * col_w
      ctx.stroke_color = {255, 255, 255, 180}
      ctx.line_width = 2
      ctx:begin_path(); ctx:rect(ax + 1, y + 1, col_w - 2, h - 2); ctx:stroke()
    end
  end
end

-- Mouse handling per mode
function PakettiMultitap_mouse(ev)
  if ev.type == "exit" then
    PakettiMultitap_MOUSE_IS_DOWN = false
    PakettiMultitap_LAST_MOUSE_X = -1
    PakettiMultitap_LAST_MOUSE_Y = -1
    return
  end

  local x, y, w, h = PakettiMultitap_get_content_rect()
  local inside = ev.position.x >= x and ev.position.x <= x + w and ev.position.y >= y and ev.position.y <= y + h
  if not inside and ev.type ~= "up" then return end

  PakettiMultitap_LAST_MOUSE_X = ev.position.x
  PakettiMultitap_LAST_MOUSE_Y = ev.position.y

  local taps = 4
  local col_w = w / taps

  if ev.type == "down" and ev.button == "left" then
    PakettiMultitap_MOUSE_IS_DOWN = true
  elseif ev.type == "up" and ev.button == "left" then
    PakettiMultitap_MOUSE_IS_DOWN = false
  end

  if not PakettiMultitap_MOUSE_IS_DOWN then
    if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
    return
  end

  local local_x = ev.position.x - x
  local local_y = ev.position.y - y
  -- Use 8 equal columns for per-channel modes
  local groups = 8
  local col_group_w = w / groups
  local group = math.floor(local_x / col_group_w) + 1 -- 1..8 (T1L,T1R,...)
  if group < 1 then group = 1 end
  if group > 8 then group = 8 end
  local tap = math.floor((group - 1) / 2) + 1
  local is_right = ((group - 1) % 2) == 1
  local norm_y = 1 - (local_y / h)
  if norm_y < 0 then norm_y = 0 end
  if norm_y > 1 then norm_y = 1 end

  if PakettiMultitap_current_mode == 1 then
    -- Delay/Feedback side-by-side sub-columns within each channel column
    local groups = 8
    local col_group_w = w / groups
    local idx_l = (tap - 1) * 2
    local bx_base = x + (is_right and (idx_l + 1) or idx_l) * col_group_w
    local bw = col_group_w
    local pad = 4
    local sub_gap = 4
    local bx = bx_base + pad
    local inner_w = bw - pad * 2
    local sub_w = (inner_w - sub_gap) / 2
    local is_delay_zone = (ev.position.x <= bx + sub_w)
    local slot
    if is_delay_zone then
      slot = is_right and PakettiMultitap_SLOT.DLY_R or PakettiMultitap_SLOT.DLY_L
    else
      slot = is_right and PakettiMultitap_SLOT.FB_R or PakettiMultitap_SLOT.FB_L
    end
    local ny = 1 - (local_y / h)
    if ny < 0 then ny = 0 end
    if ny > 1 then ny = 1 end
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, slot), ny)
    renoise.app():show_status(string.format("Tap %d %s %s", tap, is_right and "R" or "L", is_delay_zone and "Delay" or "Feedback"))
  elseif PakettiMultitap_current_mode == 2 then
    local slot = is_right and PakettiMultitap_SLOT.FB_R or PakettiMultitap_SLOT.FB_L
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, slot), norm_y)
    renoise.app():show_status(string.format("Tap %d %s Feedback %.2f", tap, is_right and "R" or "L", norm_y))
  elseif PakettiMultitap_current_mode == 3 then
    local slot = is_right and PakettiMultitap_SLOT.PAN_R or PakettiMultitap_SLOT.PAN_L
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, slot), norm_y)
    renoise.app():show_status(string.format("Tap %d %s Pan", tap, is_right and "R" or "L"))
  elseif PakettiMultitap_current_mode == 4 then
    -- Toggle ping-pong on release inside the tap cell
    if ev.type == "down" then
      local idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.PINGPONG)
      local cur = PakettiMultitap_get_param(idx)
      local newv = (cur > 0.5) and 0 or 1
      PakettiMultitap_set_param(idx, newv)
      renoise.app():show_status(string.format("Tap %d Ping-Pong %s", tap, (newv == 1) and "ON" or "OFF"))
    end
  elseif PakettiMultitap_current_mode == 5 then
    -- Left half = Input Amount, Right half = Output Amount
    local cx = (local_x - (tap - 1) * col_w) / col_w
    if cx <= 0.5 then
      PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.IN_AMT), norm_y)
    else
      PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.OUT_AMT), norm_y)
    end
    renoise.app():show_status(string.format("Tap %d In/Out mix adjusted", tap))
  elseif PakettiMultitap_current_mode == 6 then
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.FLT_FREQ), norm_y)
    renoise.app():show_status(string.format("Tap %d Filter Freq", tap))
  elseif PakettiMultitap_current_mode == 7 then
    -- Four vertical segments: 0..3. Top two rows map to Mode, bottom two to Type
    local seg = math.floor((local_y / h) * 4)
    if seg < 0 then seg = 0 end
    if seg > 3 then seg = 3 end
    if seg <= 1 then
      PakettiMultitap_set_param(PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.FLT_MODE), seg)
      renoise.app():show_status(string.format("Tap %d Filter Mode -> %d", tap, seg))
    else
      PakettiMultitap_set_param(PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.FLT_TYPE), seg - 2)
      renoise.app():show_status(string.format("Tap %d Filter Type -> %d", tap, seg - 2))
    end
  elseif PakettiMultitap_current_mode == 8 then
    -- Sync Grid: enable Line Sync, pick L or R row by half, column by 8 divisions
    PakettiMultitap_set_param(PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.LINE_SYNC), 1)
    local cx = (local_x - (tap - 1) * col_w) / col_w
    if cx < 0 then cx = 0 end
    if cx > 1 then cx = 1 end
    local ri = (local_y / h) < 0.5 and 0 or 1
    local ci = math.floor(cx * 8)
    if ci > 7 then ci = 7 end
    -- Map to Sync Time range 0..1 normalized by 8 slots
    local norm = (ci + 0.5) / 8
    local slot_idx = (ri == 0) and PakettiMultitap_SLOT.SYNC_L_TIME or PakettiMultitap_SLOT.SYNC_R_TIME
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, slot_idx), norm)
    renoise.app():show_status(string.format("Tap %d Sync %s slot %d", tap, (ri == 0) and "L" or "R", ci + 1))
  elseif PakettiMultitap_current_mode == 9 then
    -- Global XY pad inside center rect
    local rx = (ev.position.x - (x + w * 0.1)) / (w * 0.8)
    local ry = 1 - ((ev.position.y - (y + h * 0.1)) / (h * 0.8))
    if rx < 0 then rx = 0 end
    if rx > 1 then rx = 1 end
    if ry < 0 then ry = 0 end
    if ry > 1 then ry = 1 end
    local i
    for i = 1, 4 do
      PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_L), rx)
      PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.DLY_R), rx)
      PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_L), ry)
      PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(i, PakettiMultitap_SLOT.FB_R), ry)
    end
    renoise.app():show_status(string.format("Global scale Time=%.2f FB=%.2f", rx, ry))
  elseif PakettiMultitap_current_mode == 11 then
    -- Pick ratio step per tap
    local x0, y0, w0, h0 = PakettiMultitap_get_content_rect()
    local steps = #PakettiMultitap_prop_ratio_steps
    local col_w = w0 / 4
    local row_h = h0 / steps
    local tap = math.floor((ev.position.x - x0) / col_w) + 1
    if tap < 1 then tap = 1 end
    if tap > 4 then tap = 4 end
    local row = math.floor((ev.position.y - y0) / row_h) + 1
    if row < 1 then row = 1 end
    if row > steps then row = steps end
    local chosen = PakettiMultitap_prop_ratio_steps[row].value
    local old_anchor = PakettiMultitap_prop_ratios[PakettiMultitap_link_anchor_tap] or 1.0
    if PakettiMultitap_link_enabled and tap == PakettiMultitap_link_anchor_tap then
      local new_anchor = chosen
      local scale = 1.0
      if old_anchor ~= 0 then scale = new_anchor / old_anchor end
      PakettiMultitap_prop_ratios[tap] = new_anchor
      local t2
      for t2 = 1, 4 do
        if PakettiMultitap_is_tap_linked(t2) then
          local current = PakettiMultitap_prop_ratios[t2] or 1.0
          local proposed = current * scale
          PakettiMultitap_prop_ratios[t2] = PakettiMultitap_nearest_allowed_ratio(proposed)
        end
      end
      PakettiMultitap_apply_proportional()
      renoise.app():show_status(string.format("Anchor Tap %d scaled linked taps", tap))
    else
      PakettiMultitap_prop_ratios[tap] = chosen
      PakettiMultitap_apply_proportional()
      renoise.app():show_status(string.format("Tap %d ratio -> %s", tap, PakettiMultitap_prop_ratio_steps[row].label))
    end
  elseif PakettiMultitap_current_mode == 14 then
    -- Per-Side D/F/P hit-test: 8 columns, each split into 3 vertical rows
    local groups = 8
    local col_group_w = w / groups
    local group = math.floor((ev.position.x - x) / col_group_w) + 1
    if group < 1 then group = 1 end
    if group > 8 then group = 8 end
    local tap = math.floor((group - 1) / 2) + 1
    local is_right = ((group - 1) % 2) == 1
    local rows = 3
    local row_h = h / rows
    local row = math.floor((ev.position.y - y) / row_h) + 1
    if row < 1 then row = 1 end
    if row > 3 then row = 3 end
    local norm = 1 - ((ev.position.y - y - (row - 1) * row_h) / row_h)
    if norm < 0 then norm = 0 end
    if norm > 1 then norm = 1 end
    local slot
    if row == 1 then
      slot = is_right and PakettiMultitap_SLOT.DLY_R or PakettiMultitap_SLOT.DLY_L
    elseif row == 2 then
      slot = is_right and PakettiMultitap_SLOT.FB_R or PakettiMultitap_SLOT.FB_L
    else
      slot = is_right and PakettiMultitap_SLOT.PAN_R or PakettiMultitap_SLOT.PAN_L
    end
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(tap, slot), norm)
    local side = is_right and "RIGHT" or "LEFT"
    local label = (row == 1) and "DELAY" or ((row == 2) and "FEEDBACK" or "PAN")
    renoise.app():show_status(string.format("Tap %d %s %s", tap, side, label))
  end

  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
end

-- Apply proportional stairs to delays (in milliseconds) based on BPM
function PakettiMultitap_apply_proportional()
  if not PakettiMultitap_ensure_device_exists() then return end
  local song = renoise.song()
  local bpm = song.transport.bpm
  local beat_ms = 60000.0 / bpm
  local base_beats = PakettiMultitap_prop_divisions_beats[PakettiMultitap_prop_base_div_index] or 4.0
  local t
  for t = 1, 4 do
    local ratio = PakettiMultitap_prop_ratios[t] or 1.0
    local delay_ms = base_beats * ratio * beat_ms
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_L), delay_ms)
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_R), delay_ms)
  end
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
end

-- Set preset ratio patterns
function PakettiMultitap_set_pattern_by_index(idx)
  PakettiMultitap_prop_pattern_index = idx
  local name = PakettiMultitap_prop_patterns[idx]
  if name == "Halves" then
    PakettiMultitap_prop_ratios = {1.0, 0.5, 0.25, 0.125}
  elseif name == "Triplets" then
    PakettiMultitap_prop_ratios = {1.0, 2.0/3.0, 1.0/3.0, 1.0/6.0}
  elseif name == "SwingDown" then
    PakettiMultitap_prop_ratios = {1.0, 0.75, 0.5, 0.25}
  elseif name == "Reverse" then
    PakettiMultitap_prop_ratios = {0.125, 0.25, 0.5, 1.0}
  elseif name == "WideHalves" then
    PakettiMultitap_prop_ratios = {1.0, 0.5, 0.125, 0.0625}
  elseif name == "Stair34" then
    PakettiMultitap_prop_ratios = {1.0, 0.75, 0.5, 0.375}
  end
  PakettiMultitap_apply_proportional()
end

-- Status text
function PakettiMultitap_update_status()
  if not PakettiMultitap_dialog or not PakettiMultitap_dialog.visible then return end
  local song = renoise.song()
  if not song or not song.selected_track then
    if vb and vb.views and vb.views.PakettiMultitap_status then
      vb.views.PakettiMultitap_status.text = "No track selected"
    end
    return
  end
  local has = PakettiMultitap_get_device() ~= nil
  if vb and vb.views and vb.views.PakettiMultitap_status then
    vb.views.PakettiMultitap_status.text = has and "Multitap ready" or "Multitap not found (click Ensure)"
  end
end

-- Toggle device size
function PakettiMultitap_toggle_devices_size()
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return
  end
  local track = song.selected_track
  local cnt = 0
  local i
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/Multitap" then
      device.is_maximized = not PakettiMultitap_devices_minimized
      cnt = cnt + 1
    end
  end
  if cnt > 0 then
    renoise.app():show_status(string.format("%d Multitap device(s) %s", cnt, PakettiMultitap_devices_minimized and "minimized" or "maximized"))
  else
    renoise.app():show_status("No Multitap device found to resize")
  end
end

-- Reset to sensible state
function PakettiMultitap_reset()
  if not PakettiMultitap_ensure_device_exists() then return end
  local t
  for t = 1, 4 do
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_L), 0.2)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_R), 0.2)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.IN_AMT), 1.0)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.OUT_AMT), (t == 1) and 1.0 or 0.0)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.FB_L), 0.5)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.FB_R), 0.5)
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PINGPONG), 0)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PAN_L), 0.0)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PAN_R), 1.0)
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.LINE_SYNC), 0)
  end
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
  renoise.app():show_status("Multitap reset to baseline")
end

-- Scenes / Randomizers
function PakettiMultitap_scene_dub()
  if not PakettiMultitap_ensure_device_exists() then return end
  local t
  for t = 1, 4 do
    local fb = (t <= 2) and 0.65 or 0.5
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.FB_L), fb)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.FB_R), fb)
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PINGPONG), (t % 2 == 0) and 1 or 0)
  end
  renoise.app():show_status("Scene: Dub echoes")
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
end

function PakettiMultitap_scene_granular()
  if not PakettiMultitap_ensure_device_exists() then return end
  local t
  for t = 1, 4 do
    local d = (t - 1) * 0.18 + 0.12
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_L), d)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_R), d * 0.95)
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.LINE_SYNC), 0)
  end
  renoise.app():show_status("Scene: Granular taps")
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
end

function PakettiMultitap_scene_wide()
  if not PakettiMultitap_ensure_device_exists() then return end
  local t
  for t = 1, 4 do
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PAN_L), 0.0)
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PAN_R), 1.0)
    PakettiMultitap_set_param(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.PINGPONG), 1)
  end
  renoise.app():show_status("Scene: Wide ping-pong")
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
end

function PakettiMultitap_scene_random_safe()
  if not PakettiMultitap_ensure_device_exists() then return end
  math.randomseed(os.time())
  local t
  for t = 1, 4 do
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_L), math.random())
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.DLY_R), math.random())
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.FB_L), 0.2 + 0.6 * math.random())
    PakettiMultitap_set_param_normalized(PakettiMultitap_param_index(t, PakettiMultitap_SLOT.FB_R), 0.2 + 0.6 * math.random())
  end
  renoise.app():show_status("Scene: Random (safe range)")
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
end

-- UI creation
function PakettiMultitap_create_dialog()
  if PakettiMultitap_dialog and PakettiMultitap_dialog.visible then
    PakettiMultitap_dialog:close()
  end

  vb = renoise.ViewBuilder()

  local header = vb:row {
    vb:text { text = "Multitap Delay Performance (14 modes)", style = "strong" },
    vb:space { width = 16 },
    vb:text { id = "PakettiMultitap_status", text = "", style = "normal" },
  }

  local mode_selector = vb:row {
    vb:text { text = "Mode:", width = 50 },
    vb:popup {
      width = 360,
      items = PakettiMultitap_MODE_NAMES,
      value = PakettiMultitap_current_mode,
      notifier = function(val)
        PakettiMultitap_current_mode = val
        -- Recreate the entire dialog for stable layout
        PakettiMultitap_create_dialog()
      end
    }
  }

  local proportional_row = vb:row {
    vb:text { text = "Proportional:", width = 90 },
    vb:text { text = "Base", width = 36 },
    vb:popup {
      id = "PakettiMultitap_prop_base_popup",
      width = 120,
      items = PakettiMultitap_prop_divisions_items,
      value = PakettiMultitap_prop_base_div_index,
      notifier = function(val)
        PakettiMultitap_prop_base_div_index = val
        PakettiMultitap_apply_proportional()
      end
    },
    vb:space { width = 8 },
    vb:text { text = "Pattern", width = 60 },
    vb:popup {
      id = "PakettiMultitap_prop_pattern_popup",
      width = 140,
      items = PakettiMultitap_prop_patterns,
      value = PakettiMultitap_prop_pattern_index,
      notifier = function(val)
        PakettiMultitap_set_pattern_by_index(val)
      end
    },
    vb:space { width = 8 },
    vb:checkbox {
      id = "PakettiMultitap_link_enable_cb",
      value = PakettiMultitap_link_enabled,
      width = 20,
      notifier = function(v)
        PakettiMultitap_link_enabled = v
        renoise.app():show_status(string.format("Link %s", v and "enabled" or "disabled"))
        if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
      end
    },
    vb:text { text = "Link" },
    vb:text { text = "Anchor", width = 50 },
    vb:popup {
      id = "PakettiMultitap_link_anchor_popup",
      width = 60,
      items = {"Tap 1","Tap 2","Tap 3","Tap 4"},
      value = PakettiMultitap_link_anchor_tap,
      notifier = function(val)
        PakettiMultitap_link_anchor_tap = val
        renoise.app():show_status(string.format("Anchor set to Tap %d", val))
        if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
      end
    },
    vb:text { text = "Link Taps:", width = 70 },
    vb:row {
      spacing = 6,
      vb:checkbox {
        id = "PakettiMultitap_link_t1_cb",
        value = PakettiMultitap_link_flags[1],
        width = 20,
        notifier = function(v) PakettiMultitap_set_link_flag(1, v) end
      }, vb:text { text = "1" },
      vb:checkbox {
        id = "PakettiMultitap_link_t2_cb",
        value = PakettiMultitap_link_flags[2],
        width = 20,
        notifier = function(v) PakettiMultitap_set_link_flag(2, v) end
      }, vb:text { text = "2" },
      vb:checkbox {
        id = "PakettiMultitap_link_t3_cb",
        value = PakettiMultitap_link_flags[3],
        width = 20,
        notifier = function(v) PakettiMultitap_set_link_flag(3, v) end
      }, vb:text { text = "3" },
      vb:checkbox {
        id = "PakettiMultitap_link_t4_cb",
        value = PakettiMultitap_link_flags[4],
        width = 20,
        notifier = function(v) PakettiMultitap_set_link_flag(4, v) end
      }, vb:text { text = "4" }
    },
    vb:space { width = 8 },
    vb:button {
      text = "Apply Now",
      width = 100,
      notifier = function()
        PakettiMultitap_apply_proportional()
        renoise.app():show_status("Applied proportional stairs to delays")
      end
    }
  }

  local canvas_view = vb:canvas {
    id = "PakettiMultitap_canvas",
    width = PakettiMultitap_canvas_width,
    height = PakettiMultitap_canvas_height,
    mode = "plain",
    render = PakettiMultitap_render,
    mouse_handler = PakettiMultitap_mouse,
    mouse_events = {"down", "up", "move", "exit"}
  }

  local controls_row1 = vb:row {
    vb:button {
      text = "Ensure Device",
      width = 120,
      notifier = function()
        PakettiMultitap_ensure_device_exists()
        PakettiMultitap_update_status()
        PakettiMultitap_setup_parameter_observers()
        PakettiMultitap_setup_update_timer()
      end
    },
    vb:button {
      text = "Update Canvas",
      width = 120,
      notifier = function()
        if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
      end
    },
    vb:checkbox {
      id = "PakettiMultitap_swap_colors_cb",
      value = PakettiMultitap_swap_half_colors,
      width = 20,
      notifier = function(v)
        PakettiMultitap_swap_half_colors = v
        if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
        renoise.app():show_status(string.format("Mode1 colors swapped: %s", v and "Delay=Orange, Feedback=Cyan" or "Delay=Cyan, Feedback=Orange"))
      end
    },
    vb:text { text = "Swap Delay/Feedback Colors" },
    vb:button {
      text = "Reset",
      width = 80,
      notifier = function()
        PakettiMultitap_reset()
      end
    },
    vb:button {
      text = "Recreate",
      width = 90,
      tooltip = "Remove and insert one fresh Multitap",
      notifier = function()
        local song = renoise.song()
        if not song or not song.selected_track then return end
        local track = song.selected_track
        local i
        for i = #track.devices, 1, -1 do
          if track.devices[i].device_path == "Audio/Effects/Native/Multitap" then
            track:delete_device_at(i)
          end
        end
        PakettiMultitap_ensure_device_exists()
        PakettiMultitap_update_status()
        PakettiMultitap_setup_parameter_observers()
      end
    },
    vb:checkbox {
      id = "PakettiMultitap_autofocus_cb",
      value = PakettiMultitap_autofocus_enabled,
      width = 20,
      notifier = function(v)
        PakettiMultitap_autofocus_enabled = v
        renoise.app():show_status(string.format("Multitap autofocus %s", v and "enabled" or "disabled"))
      end
    },
    vb:text { text = "Autofocus" },
    vb:space { width = 16 },
    vb:checkbox {
      id = "PakettiMultitap_chain_enable_cb",
      value = PakettiMultitap_chain_enabled,
      width = 20,
      notifier = function(v)
        PakettiMultitap_chain_set_enabled(v)
        renoise.app():show_status(string.format("Tap Chain %s", v and "enabled" or "disabled"))
      end
    },
    vb:text { text = "Tap Chain" },
    vb:text { text = "Anchor", width = 50 },
    vb:popup {
      id = "PakettiMultitap_chain_anchor_popup",
      width = 60,
      items = {"Tap 1","Tap 2","Tap 3","Tap 4"},
      value = PakettiMultitap_chain_anchor_tap,
      notifier = function(val)
        PakettiMultitap_chain_anchor_tap = val
        if PakettiMultitap_chain_enabled then
          PakettiMultitap_chain_setup_observers()
          PakettiMultitap_chain_learn_from_current()
        end
        renoise.app():show_status(string.format("Tap Chain anchor -> Tap %d", val))
      end
    },
    vb:text { text = "Link:", width = 36 },
    vb:row {
      spacing = 6,
      vb:checkbox { id = "PakettiMultitap_chain_t1", value = PakettiMultitap_chain_link_flags[1], width = 20, notifier = function(v) PakettiMultitap_chain_set_flag(1, v) end }, vb:text { text = "1" },
      vb:checkbox { id = "PakettiMultitap_chain_t2", value = PakettiMultitap_chain_link_flags[2], width = 20, notifier = function(v) PakettiMultitap_chain_set_flag(2, v) end }, vb:text { text = "2" },
      vb:checkbox { id = "PakettiMultitap_chain_t3", value = PakettiMultitap_chain_link_flags[3], width = 20, notifier = function(v) PakettiMultitap_chain_set_flag(3, v) end }, vb:text { text = "3" },
      vb:checkbox { id = "PakettiMultitap_chain_t4", value = PakettiMultitap_chain_link_flags[4], width = 20, notifier = function(v) PakettiMultitap_chain_set_flag(4, v) end }, vb:text { text = "4" }
    },
    vb:button {
      text = "Learn Ratios",
      width = 110,
      notifier = function()
        PakettiMultitap_chain_learn_from_current()
      end
    },
    vb:button {
      text = "Apply Chain",
      width = 110,
      notifier = function()
        PakettiMultitap_chain_apply_from_anchor()
        renoise.app():show_status("Tap Chain applied")
      end
    },
    vb:checkbox {
      id = "PakettiMultitap_minimize_cb",
      value = PakettiMultitap_devices_minimized,
      width = 20,
      notifier = function(v)
        PakettiMultitap_devices_minimized = v
        PakettiMultitap_toggle_devices_size()
      end
    },
    vb:text { text = "Minimize Device" },
    vb:space { width = 16 },
    vb:button {
      text = "Close",
      width = 80,
      notifier = function()
        if PakettiMultitap_dialog then PakettiMultitap_dialog:close(); PakettiMultitap_dialog = nil end
      end
    }
  }

  local scenes_row = vb:row {
    vb:text { text = "Scenes:", width = 60 },
    vb:button { text = "Dub", width = 70, notifier = PakettiMultitap_scene_dub },
    vb:button { text = "Granular", width = 90, notifier = PakettiMultitap_scene_granular },
    vb:button { text = "Wide", width = 70, notifier = PakettiMultitap_scene_wide },
    vb:button { text = "Random", width = 80, notifier = PakettiMultitap_scene_random_safe }
  }

  local content = vb:column {
    margin = 10,
    header,
    mode_selector,
    proportional_row,
    canvas_view,
    controls_row1,
    scenes_row
  }

  PakettiMultitap_dialog = renoise.app():show_custom_dialog("Paketti Multitap Experiment", content, my_keyhandler_func)

  PakettiMultitap_canvas = vb.views.PakettiMultitap_canvas

  -- Give Renoise keyboard focus as requested
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame

  PakettiMultitap_update_status()
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
  PakettiMultitap_setup_parameter_observers()
  PakettiMultitap_setup_update_timer()
end

-- Entry point
function PakettiMultitapExperimentInit()
  PakettiMultitap_ensure_device_exists()
  PakettiMultitap_create_dialog()
end

renoise.tool():add_keybinding { name = "Global:Paketti:Paketti Multitap Experiment", invoke = PakettiMultitapExperimentInit }
renoise.tool():add_menu_entry { name = "Main Menu:Tools:Paketti..:Experimental/WIP:Multitap Experiment", invoke = PakettiMultitapExperimentInit }

--------------------------------------------------------------------------------
-- PHRASEGRID INTEGRATION: Multitap Scene Snapshots & Delay Phrase Creation
--------------------------------------------------------------------------------

-- Get current Multitap state for PhraseGrid storage
function PakettiMultitapGetSnapshot()
  local song = renoise.song()
  if not song then return nil end
  
  local track = song.selected_track
  if not track then return nil end
  
  -- Find the Multitap Delay device
  local device = nil
  for i, d in ipairs(track.devices) do
    if d.display_name == "Multitap Delay" then
      device = d
      break
    end
  end
  
  if not device then
    return nil
  end
  
  -- Capture all tap parameters
  local snapshot = {
    track_index = song.selected_track_index,
    tap_delays = {},
    tap_feedbacks = {},
    tap_pans = {},
    prop_ratios = {},
    prop_base_div_index = PakettiMultitap_prop_base_div_index or 1,
    prop_pattern_index = PakettiMultitap_prop_pattern_index or 1,
    mode = PakettiMultitap_current_mode or "proportional"
  }
  
  -- Store ratio values
  for t = 1, 4 do
    snapshot.prop_ratios[t] = PakettiMultitap_prop_ratios[t] or 1.0
  end
  
  -- Capture device parameters for each tap
  for tap = 1, 4 do
    local delay_l_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.DLY_L)
    local fb_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.FB)
    local pan_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.PAN)
    
    if delay_l_idx and device.parameters[delay_l_idx] then
      snapshot.tap_delays[tap] = device.parameters[delay_l_idx].value
    end
    if fb_idx and device.parameters[fb_idx] then
      snapshot.tap_feedbacks[tap] = device.parameters[fb_idx].value
    end
    if pan_idx and device.parameters[pan_idx] then
      snapshot.tap_pans[tap] = device.parameters[pan_idx].value
    end
  end
  
  print("Multitap Snapshot: Captured 4 tap settings")
  return snapshot
end

-- Restore Multitap state from PhraseGrid snapshot
function PakettiMultitapRestoreFromSnapshot(snapshot)
  if not snapshot then return false end
  
  local song = renoise.song()
  if not song then return false end
  
  -- Find device on the snapshot's track or current track
  local track_index = snapshot.track_index or song.selected_track_index
  local track = song.tracks[track_index]
  if not track then return false end
  
  local device = nil
  for i, d in ipairs(track.devices) do
    if d.display_name == "Multitap Delay" then
      device = d
      song.selected_track_index = track_index
      break
    end
  end
  
  if not device then
    print("Multitap Restore: Device not found")
    return false
  end
  
  -- Restore ratio state
  if snapshot.prop_ratios then
    for t = 1, 4 do
      PakettiMultitap_prop_ratios[t] = snapshot.prop_ratios[t] or 1.0
    end
  end
  
  if snapshot.prop_base_div_index then
    PakettiMultitap_prop_base_div_index = snapshot.prop_base_div_index
  end
  
  if snapshot.prop_pattern_index then
    PakettiMultitap_prop_pattern_index = snapshot.prop_pattern_index
  end
  
  -- Restore device parameters
  for tap = 1, 4 do
    if snapshot.tap_delays[tap] then
      local delay_l_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.DLY_L)
      local delay_r_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.DLY_R)
      if delay_l_idx and device.parameters[delay_l_idx] then
        device.parameters[delay_l_idx].value = snapshot.tap_delays[tap]
      end
      if delay_r_idx and device.parameters[delay_r_idx] then
        device.parameters[delay_r_idx].value = snapshot.tap_delays[tap]
      end
    end
    if snapshot.tap_feedbacks[tap] then
      local fb_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.FB)
      if fb_idx and device.parameters[fb_idx] then
        device.parameters[fb_idx].value = snapshot.tap_feedbacks[tap]
      end
    end
    if snapshot.tap_pans[tap] then
      local pan_idx = PakettiMultitap_param_index(tap, PakettiMultitap_SLOT.PAN)
      if pan_idx and device.parameters[pan_idx] then
        device.parameters[pan_idx].value = snapshot.tap_pans[tap]
      end
    end
  end
  
  -- Update canvas if open
  if PakettiMultitap_canvas then PakettiMultitap_canvas:update() end
  
  print("Multitap Restore: Restored 4 tap settings")
  renoise.app():show_status("Restored Multitap scene")
  return true
end

-- Create a phrase with delay commands from Multitap timings
function PakettiMultitapCreateDelayPhrase(phrase_length)
  local song = renoise.song()
  if not song then return nil end
  
  local snapshot = PakettiMultitapGetSnapshot()
  if not snapshot then
    renoise.app():show_status("Multitap: No device found")
    return nil
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return nil
  end
  
  phrase_length = phrase_length or 16
  
  -- Create a new phrase
  local phrase_index = #instrument.phrases + 1
  instrument:insert_phrase_at(phrase_index)
  local phrase = instrument.phrases[phrase_index]
  
  if not phrase then
    renoise.app():show_status("Failed to create phrase")
    return nil
  end
  
  -- Configure phrase
  phrase.name = "Multitap Delays"
  phrase.number_of_lines = phrase_length
  phrase.lpb = song.transport.lpb
  phrase.is_empty = false
  phrase.looping = true
  phrase.loop_start = 1
  phrase.loop_end = phrase_length
  
  -- Ensure effect column is visible
  if phrase.visible_effect_columns < 1 then
    phrase.visible_effect_columns = 1
  end
  
  -- Calculate line positions for each tap based on delay times
  local bpm = song.transport.bpm
  local beat_ms = 60000 / bpm
  local lpb = phrase.lpb
  local ms_per_line = beat_ms / lpb
  
  -- Write delay commands at appropriate positions
  -- Use 0Dxx (note delay) to shift timing
  for tap = 1, 4 do
    local delay_ms = snapshot.tap_delays[tap] or 0
    local line_position = math.floor(delay_ms / ms_per_line) + 1
    
    if line_position >= 1 and line_position <= phrase_length then
      local line = phrase:line(line_position)
      
      -- Calculate sub-line delay (0-FF)
      local remainder_ms = delay_ms - ((line_position - 1) * ms_per_line)
      local delay_value = math.floor((remainder_ms / ms_per_line) * 255)
      if delay_value < 0 then delay_value = 0 end
      if delay_value > 255 then delay_value = 255 end
      
      -- Write note delay command
      line.effect_columns[1].number_value = 0x0D  -- Note delay
      line.effect_columns[1].amount_value = delay_value
      
      print(string.format("Multitap Phrase: Tap %d at line %d with delay 0D%02X", tap, line_position, delay_value))
    end
  end
  
  renoise.app():show_status("Created Multitap delay phrase with " .. phrase_length .. " lines")
  return phrase_index
end

-- Create phrase with echo notes based on Multitap timing
function PakettiMultitapCreateEchoPhrase(base_note, phrase_length)
  local song = renoise.song()
  if not song then return nil end
  
  local snapshot = PakettiMultitapGetSnapshot()
  if not snapshot then
    renoise.app():show_status("Multitap: No device found")
    return nil
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return nil
  end
  
  base_note = base_note or 48  -- C-4
  phrase_length = phrase_length or 32
  
  -- Create a new phrase
  local phrase_index = #instrument.phrases + 1
  instrument:insert_phrase_at(phrase_index)
  local phrase = instrument.phrases[phrase_index]
  
  if not phrase then
    renoise.app():show_status("Failed to create phrase")
    return nil
  end
  
  -- Configure phrase
  phrase.name = "Multitap Echo"
  phrase.number_of_lines = phrase_length
  phrase.lpb = song.transport.lpb
  phrase.is_empty = false
  phrase.looping = true
  phrase.loop_start = 1
  phrase.loop_end = phrase_length
  
  if phrase.visible_note_columns < 1 then
    phrase.visible_note_columns = 1
  end
  
  -- Calculate ms per line
  local bpm = song.transport.bpm
  local beat_ms = 60000 / bpm
  local lpb = phrase.lpb
  local ms_per_line = beat_ms / lpb
  
  -- Write first note at line 1
  local line1 = phrase:line(1)
  line1.note_columns[1].note_value = base_note
  line1.note_columns[1].instrument_value = 0
  line1.note_columns[1].volume_value = 128
  
  -- Write echo notes based on tap delays with decreasing velocity
  for tap = 1, 4 do
    local delay_ms = snapshot.tap_delays[tap] or 0
    local line_position = math.floor(delay_ms / ms_per_line) + 1
    
    if line_position >= 1 and line_position <= phrase_length and line_position > 1 then
      local line = phrase:line(line_position)
      
      -- Velocity based on feedback (lower feedback = quieter echo)
      local feedback = snapshot.tap_feedbacks[tap] or 0.5
      local velocity = math.floor(128 * feedback * (1 - (tap - 1) * 0.15))
      if velocity < 1 then velocity = 1 end
      if velocity > 128 then velocity = 128 end
      
      line.note_columns[1].note_value = base_note
      line.note_columns[1].instrument_value = 0
      line.note_columns[1].volume_value = velocity
      
      print(string.format("Multitap Echo: Tap %d at line %d with velocity %d", tap, line_position, velocity))
    end
  end
  
  renoise.app():show_status("Created Multitap echo phrase")
  return phrase_index
end

-- Snapshot Multitap to PhraseGrid state
function PakettiMultitapSnapshotToPhraseGrid(state_index)
  if not state_index then
    state_index = (PakettiPhraseGridCurrentState and PakettiPhraseGridCurrentState > 0) and PakettiPhraseGridCurrentState or 1
  end
  
  local snapshot = PakettiMultitapGetSnapshot()
  if not snapshot then
    renoise.app():show_status("No Multitap device to snapshot")
    return false
  end
  
  if PakettiPhraseGridStates then
    if not PakettiPhraseGridStates[state_index] then
      if PakettiPhraseGridCreateEmptyState then
        PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
      else
        PakettiPhraseGridStates[state_index] = {}
      end
    end
    
    PakettiPhraseGridStates[state_index].multitap = snapshot
    renoise.app():show_status(string.format("Multitap snapshot stored to PhraseGrid State %02d", state_index))
    return true
  else
    renoise.app():show_status("PhraseGrid not available")
    return false
  end
end

-- Restore Multitap from PhraseGrid state
function PakettiMultitapRestoreFromPhraseGrid(state_index)
  if not state_index then
    state_index = (PakettiPhraseGridCurrentState and PakettiPhraseGridCurrentState > 0) and PakettiPhraseGridCurrentState or 1
  end
  
  if not PakettiPhraseGridStates or not PakettiPhraseGridStates[state_index] then
    renoise.app():show_status("No PhraseGrid state at index " .. state_index)
    return false
  end
  
  local snapshot = PakettiPhraseGridStates[state_index].multitap
  if not snapshot then
    renoise.app():show_status("No Multitap snapshot in state " .. state_index)
    return false
  end
  
  return PakettiMultitapRestoreFromSnapshot(snapshot)
end

-- Keybindings
renoise.tool():add_keybinding{name = "Global:Paketti:Multitap Snapshot to PhraseGrid State", invoke = function() PakettiMultitapSnapshotToPhraseGrid() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Multitap Restore from PhraseGrid State", invoke = function() PakettiMultitapRestoreFromPhraseGrid() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Multitap Create Delay Phrase", invoke = function() PakettiMultitapCreateDelayPhrase(16) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Multitap Create Echo Phrase", invoke = function() PakettiMultitapCreateEchoPhrase(nil, 32) end}

-- MIDI Mappings
renoise.tool():add_midi_mapping{name = "Paketti:Multitap Snapshot to PhraseGrid [Trigger]", invoke = function(message) if message:is_trigger() then PakettiMultitapSnapshotToPhraseGrid() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Multitap Restore from PhraseGrid [Trigger]", invoke = function(message) if message:is_trigger() then PakettiMultitapRestoreFromPhraseGrid() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Multitap Create Delay Phrase [Trigger]", invoke = function(message) if message:is_trigger() then PakettiMultitapCreateDelayPhrase(16) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Multitap Create Echo Phrase [Trigger]", invoke = function(message) if message:is_trigger() then PakettiMultitapCreateEchoPhrase(nil, 32) end end}

