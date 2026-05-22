-- PakettiCalculator.lua
-- Lightweight in-Renoise calculator for tracker workflows.
-- Expression evaluator (sandboxed loadstring) with dec/hex/byte outputs,
-- tracker helpers (bpm, lpb, ms_per_line, hz_from_bpm), history, and
-- one-click insert of the result into the selected effect column,
-- volume column, panning column, or delay column.

local paketti_calc_dialog = nil
local paketti_calc_history = {}
local paketti_calc_last_ans = 0
local PAKETTI_CALC_HISTORY_MAX = 12

local function paketti_calc_round(x)
  if x >= 0 then return math.floor(x + 0.5) else return -math.floor(-x + 0.5) end
end

local function paketti_calc_sandbox()
  local env = {
    pi = math.pi,
    e = math.exp(1),
    ans = paketti_calc_last_ans,
    sin = math.sin, cos = math.cos, tan = math.tan,
    asin = math.asin, acos = math.acos, atan = math.atan, atan2 = math.atan2,
    sqrt = math.sqrt, abs = math.abs, exp = math.exp,
    log = math.log,
    log2 = function(x) return math.log(x) / math.log(2) end,
    log10 = math.log10 or function(x) return math.log(x) / math.log(10) end,
    floor = math.floor, ceil = math.ceil, round = paketti_calc_round,
    pow = math.pow or function(a, b) return a ^ b end,
    min = math.min, max = math.max, fmod = math.fmod,
    rand = math.random,
    -- Renoise-aware helpers
    bpm = function() return renoise.song().transport.bpm end,
    lpb = function() return renoise.song().transport.lpb end,
    tpl = function() return renoise.song().transport.tpl end,
    ms_per_line = function()
      local s = renoise.song()
      return 60000 / (s.transport.bpm * s.transport.lpb)
    end,
    ms_per_beat = function() return 60000 / renoise.song().transport.bpm end,
    hz_from_bpm = function() return renoise.song().transport.bpm / 60 end,
    -- Convert between cents and ratio, semitones and ratio
    cents_to_ratio = function(c) return 2 ^ (c / 1200) end,
    ratio_to_cents = function(r) return 1200 * math.log(r) / math.log(2) end,
    semi_to_ratio = function(s) return 2 ^ (s / 12) end,
    ratio_to_semi = function(r) return 12 * math.log(r) / math.log(2) end,
  }
  -- Allow math.* explicitly too
  env.math = math
  return env
end

local function paketti_calc_evaluate(expr)
  if not expr or expr:match("^%s*$") then return nil, "empty" end
  local chunk, err = loadstring("return " .. expr)
  if not chunk then
    chunk, err = loadstring(expr)
    if not chunk then return nil, err end
  end
  setfenv(chunk, paketti_calc_sandbox())
  local ok, val = pcall(chunk)
  if not ok then return nil, tostring(val) end
  if type(val) ~= "number" then
    if val == nil then return nil, "no result" end
    return nil, "result is " .. type(val)
  end
  if val ~= val then return nil, "NaN" end  -- NaN check
  return val
end

local function paketti_calc_format_result(v)
  if v == nil then return "—", "—", "—", "—" end
  local rounded = paketti_calc_round(v)
  local dec_str
  if math.abs(v - rounded) < 1e-9 then
    dec_str = tostring(rounded)
  else
    dec_str = string.format("%.6g", v)
  end
  local int_str = tostring(rounded)
  local hex_full
  if rounded >= 0 then
    hex_full = string.format("0x%X", rounded)
  else
    hex_full = "-" .. string.format("0x%X", -rounded)
  end
  local byte_str
  if rounded >= 0 and rounded <= 255 then
    byte_str = string.format("%02X", rounded)
  else
    byte_str = "—"
  end
  return dec_str, int_str, hex_full, byte_str
end

local function paketti_calc_current_note_column()
  local song = renoise.song()
  local col = song.selected_note_column
  if col then return col end
  -- Fall back to first note column of the current line on the selected track
  local track = song.selected_track
  if not track or track.visible_note_columns < 1 then return nil end
  local line = song.selected_line
  if not line or not line.note_columns or #line.note_columns < 1 then return nil end
  return line.note_columns[1]
end

local function paketti_calc_current_effect_column()
  local song = renoise.song()
  local track = song.selected_track
  if not track then return nil end
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  local col = song.selected_effect_column
  if col then return col end
  local line = song.selected_line
  if not line or not line.effect_columns or #line.effect_columns < 1 then return nil end
  return line.effect_columns[1]
end

local function paketti_calc_set_effect_amount(byte_val)
  local song = renoise.song()
  if not song then return end
  if byte_val < 0 or byte_val > 255 then
    renoise.app():show_status("PakettiCalc: value " .. byte_val .. " out of 0-255 effect range")
    return
  end
  local col = paketti_calc_current_effect_column()
  if not col then
    renoise.app():show_status("PakettiCalc: cannot find an effect column on selected track")
    return
  end
  col.amount_value = byte_val
  renoise.app():show_status(string.format("PakettiCalc: effect amount = %02X (%d)", byte_val, byte_val))
end

local function paketti_calc_set_volume(byte_val)
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if track then track.volume_column_visible = true end
  local col = paketti_calc_current_note_column()
  if not col then
    renoise.app():show_status("PakettiCalc: cannot find a note column on selected track")
    return
  end
  col.volume_value = math.min(math.max(byte_val, 0), 255)
  renoise.app():show_status(string.format("PakettiCalc: volume = %d", col.volume_value))
end

local function paketti_calc_set_panning(byte_val)
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if track then track.panning_column_visible = true end
  local col = paketti_calc_current_note_column()
  if not col then
    renoise.app():show_status("PakettiCalc: cannot find a note column on selected track")
    return
  end
  col.panning_value = math.min(math.max(byte_val, 0), 255)
  renoise.app():show_status(string.format("PakettiCalc: panning = %d", col.panning_value))
end

local function paketti_calc_set_delay(byte_val)
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if track then track.delay_column_visible = true end
  local col = paketti_calc_current_note_column()
  if not col then
    renoise.app():show_status("PakettiCalc: cannot find a note column on selected track")
    return
  end
  col.delay_value = math.min(math.max(byte_val, 0), 255)
  renoise.app():show_status(string.format("PakettiCalc: delay = %02X", col.delay_value))
end

function pakettiCalculatorDialog()
  if paketti_calc_dialog and paketti_calc_dialog.visible then
    paketti_calc_dialog:close()
    paketti_calc_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local do_eval_holder = {fn = function() end}
  local expr_field = vb:textfield{
    width = 360,
    value = "",
    notifier = function(_)
      do_eval_holder.fn()
    end
  }
  local dec_text = vb:text{width = 200, text = "—", style = "strong", font = "bold"}
  local int_text = vb:text{width = 200, text = "—"}
  local hex_text = vb:text{width = 200, text = "—"}
  local byte_text = vb:text{width = 200, text = "—", style = "strong"}
  local err_text = vb:text{width = 360, text = ""}
  local history_text = vb:multiline_text{width = 360, height = 100, text = "", font = "mono"}

  local last_value = nil

  local function refresh_history()
    local lines = {}
    for i = #paketti_calc_history, math.max(1, #paketti_calc_history - PAKETTI_CALC_HISTORY_MAX + 1), -1 do
      table.insert(lines, paketti_calc_history[i])
    end
    history_text.text = table.concat(lines, "\n")
  end

  local function do_eval()
    local expr = expr_field.value
    if expr == nil or expr == "" then return end
    local val, err = paketti_calc_evaluate(expr)
    if val == nil then
      err_text.text = "error: " .. tostring(err)
      last_value = nil
      return
    end
    err_text.text = ""
    paketti_calc_last_ans = val
    last_value = val
    local dec, int, hex, byte = paketti_calc_format_result(val)
    dec_text.text = dec
    int_text.text = int
    hex_text.text = hex
    byte_text.text = byte
    table.insert(paketti_calc_history, string.format("%s = %s", expr, dec))
    if #paketti_calc_history > 64 then
      table.remove(paketti_calc_history, 1)
    end
    refresh_history()
  end

  local function with_value(fn)
    return function()
      if last_value == nil then
        renoise.app():show_status("PakettiCalc: no result yet — press = first")
        return
      end
      fn(paketti_calc_round(last_value))
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    end
  end

  do_eval_holder.fn = do_eval

  local function append_token(token)
    return function()
      expr_field.value = (expr_field.value or "") .. token
      expr_field.edit_mode = true
    end
  end

  refresh_history()

  local content = vb:column{
    margin = 8, spacing = 6,
    vb:text{style = "strong", font = "bold", text = "Paketti Calculator"},
    vb:text{text = "Expression (Lua math + helpers). Press = or Enter to evaluate."},
    vb:row{
      spacing = 4,
      expr_field,
      vb:button{text = "=", width = 30, notifier = do_eval},
      vb:button{text = "C", width = 30, notifier = function()
        expr_field.value = ""
        err_text.text = ""
      end}
    },
    vb:row{spacing = 4, vb:text{width = 60, text = "Decimal:"}, dec_text},
    vb:row{spacing = 4, vb:text{width = 60, text = "Integer:"}, int_text},
    vb:row{spacing = 4, vb:text{width = 60, text = "Hex:"}, hex_text},
    vb:row{spacing = 4, vb:text{width = 60, text = "Byte (00-FF):"}, byte_text},
    err_text,
    vb:text{style = "strong", text = "Insert result into selected column:"},
    vb:row{
      spacing = 4,
      vb:button{text = "Effect Amount", width = 100, notifier = with_value(paketti_calc_set_effect_amount)},
      vb:button{text = "Volume", width = 70, notifier = with_value(paketti_calc_set_volume)},
      vb:button{text = "Panning", width = 70, notifier = with_value(paketti_calc_set_panning)},
      vb:button{text = "Delay", width = 70, notifier = with_value(paketti_calc_set_delay)},
    },
    vb:text{style = "strong", text = "Append token (clicks add to end of expression):"},
    vb:row{
      spacing = 2,
      vb:button{text = "bpm()", width = 50, notifier = append_token("bpm()")},
      vb:button{text = "lpb()", width = 50, notifier = append_token("lpb()")},
      vb:button{text = "tpl()", width = 50, notifier = append_token("tpl()")},
      vb:button{text = "ms/line", width = 65, notifier = append_token("ms_per_line()")},
      vb:button{text = "ms/beat", width = 65, notifier = append_token("ms_per_beat()")},
      vb:button{text = "hz/bpm", width = 65, notifier = append_token("hz_from_bpm()")},
    },
    vb:row{
      spacing = 2,
      vb:button{text = "cents->ratio", width = 80, notifier = append_token("cents_to_ratio(")},
      vb:button{text = "ratio->cents", width = 80, notifier = append_token("ratio_to_cents(")},
      vb:button{text = "semi->ratio", width = 80, notifier = append_token("semi_to_ratio(")},
      vb:button{text = "ratio->semi", width = 80, notifier = append_token("ratio_to_semi(")},
    },
    vb:row{
      spacing = 2,
      vb:button{text = "ans", width = 40, notifier = append_token("ans")},
      vb:button{text = "pi", width = 40, notifier = append_token("pi")},
      vb:button{text = "0x", width = 40, notifier = append_token("0x")},
      vb:button{text = "(", width = 25, notifier = append_token("(")},
      vb:button{text = ")", width = 25, notifier = append_token(")")},
      vb:button{text = "+", width = 25, notifier = append_token("+")},
      vb:button{text = "-", width = 25, notifier = append_token("-")},
      vb:button{text = "*", width = 25, notifier = append_token("*")},
      vb:button{text = "/", width = 25, notifier = append_token("/")},
      vb:button{text = "^", width = 25, notifier = append_token("^")},
    },
    vb:row{
      spacing = 2,
      vb:button{text = "sin(", width = 45, notifier = append_token("sin(")},
      vb:button{text = "cos(", width = 45, notifier = append_token("cos(")},
      vb:button{text = "tan(", width = 45, notifier = append_token("tan(")},
      vb:button{text = "sqrt(", width = 50, notifier = append_token("sqrt(")},
      vb:button{text = "abs(", width = 45, notifier = append_token("abs(")},
      vb:button{text = "log(", width = 45, notifier = append_token("log(")},
      vb:button{text = "log2(", width = 50, notifier = append_token("log2(")},
      vb:button{text = "round(", width = 55, notifier = append_token("round(")},
      vb:button{text = "floor(", width = 50, notifier = append_token("floor(")},
      vb:button{text = "ceil(", width = 45, notifier = append_token("ceil(")},
    },
    vb:text{text = "Examples:  0x40*2   |   60000/(bpm()*lpb())   |   ans+1   |   2^16"},
    vb:text{style = "strong", text = "History (newest first):"},
    history_text,
  }

  local function key_handler(dialog, key)
    if key.modifiers == "" and (key.name == "return" or key.name == "numpad enter") then
      do_eval()
      return nil
    end
    if key.modifiers == "" and key.name == "esc" then
      dialog:close()
      paketti_calc_dialog = nil
      return nil
    end
    return key
  end

  paketti_calc_dialog = renoise.app():show_custom_dialog("Paketti Calculator", content, key_handler)
end

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Calculator...",
  invoke = pakettiCalculatorDialog
}
PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Calculator...",
  invoke = pakettiCalculatorDialog
}
PakettiAddMenuEntry{
  name = "Sample Editor:Paketti:Calculator...",
  invoke = pakettiCalculatorDialog
}
PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:Calculator...",
  invoke = pakettiCalculatorDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Calculator Dialog",
  invoke = pakettiCalculatorDialog
}
