-- PakettiParameterLock.lua
-- A proper Elektron-style parameter-lock (p-lock) system for Renoise.
--
-- Concept: an Elektron p-lock stores a per-trig override for a parameter. When
-- that trig plays the parameter jumps to the locked value for that trig, then
-- falls back to the pattern's baseline ("kit") on the next trig. Renoise effect
-- commands set-and-hold, so a true p-lock needs a baseline restore written after
-- the locked step. This tool makes that a real system:
--   * pick the parameter from the selected DSP knob (no typing raw codes)
--   * capture an explicit baseline ("kit") value per (track, device, parameter)
--   * Lock a step, choosing the scope of the restore
--   * Un-lock / Clear that restore back to baseline
-- Two substrates ("engines"):
--   * effect  - the authentic tracker p-lock: a device-parameter command in the
--               effect column (visible, plays exactly on the step). Limited to
--               devices/params reachable by the <device><param> encoding and to
--               00-FF resolution.
--   * automation - PatternTrackAutomation points in POINTS playmode. Reaches any
--               automatable parameter at full resolution; used automatically when
--               the effect encoding can't address the parameter.
--
-- Scopes:
--   short   - lock on the step, baseline on the next line/edit-step (reverts at once)
--   trig    - lock on the step, baseline on the next note trig (Elektron default)
--   pattern - rebuild the whole-pattern kit: every un-locked trig carries baseline,
--             each locked step its own value (most robust, composable)

--------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------

-- Baselines keyed "trackIndex/deviceIndex/paramIndex" -> native parameter value.
-- Plain assignment (never `X = X or {}`) so strict-globals doesn't abort the load.
PakettiParameterLockBaselines = {}
PakettiParameterLockEngine = "effect"   -- "effect" | "automation"
PakettiParameterLockScope  = "trig"      -- "short" | "trig" | "pattern"
PakettiParameterLockDialog = nil

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------

local function PPL_Round(v) return math.floor((tonumber(v) or 0) + 0.5) end

local function PPL_IsRealNote(note_value)
  return note_value ~= nil and note_value >= 0 and note_value < renoise.PatternLine.NOTE_OFF
end

-- Resolve the currently selected DSP parameter into everything the engines need.
-- Returns a table {track, track_index, device, device_index, param, param_index}
-- or nil (with a status message) when nothing usable is selected.
local function PPL_ResolveSelectedParameter()
  local song = renoise.song()
  local track = song.selected_track
  local track_index = song.selected_track_index
  local device = song.selected_device
  local param = song.selected_parameter
  if not device or not param then
    renoise.app():show_status("Paketti Parameter Lock: select a device parameter first")
    return nil
  end

  local device_index = nil
  for i, d in ipairs(track.devices) do
    if rawequal(d, device) then device_index = i break end
  end
  local param_index = nil
  for i, p in ipairs(device.parameters) do
    if rawequal(p, param) then param_index = i break end
  end
  if not device_index or not param_index then
    renoise.app():show_status("Paketti Parameter Lock: selected parameter is not on the selected track")
    return nil
  end

  return {
    track = track, track_index = track_index,
    device = device, device_index = device_index,
    param = param, param_index = param_index
  }
end

local function PPL_Key(ctx)
  return ctx.track_index .. "/" .. ctx.device_index .. "/" .. ctx.param_index
end

local function PPL_Baseline(ctx)
  local key = PPL_Key(ctx)
  if PakettiParameterLockBaselines[key] ~= nil then
    return PakettiParameterLockBaselines[key]
  end
  return ctx.param.value
end

-- Value scaling between native parameter units and the 0..255 effect amount.
local function PPL_ValueToAmount(param, value)
  local span = param.value_max - param.value_min
  if span == 0 then return 0 end
  return math.max(0, math.min(255, PPL_Round(255 / span * (value - param.value_min))))
end

local function PPL_AmountToValue(param, amount)
  local span = param.value_max - param.value_min
  return param.value_min + (amount / 255) * span
end

--------------------------------------------------------------------------
-- Effect-column encoding
-- Renoise's effect column controls a track DSP parameter with a two-character
-- command: first char = device index in the chain (0-based, hex), second char =
-- parameter selector. The mandatory Track Vol/Pan/Width device (device 0) uses
-- letters: 0L volume, 0P panning, 0W width. Amount 00-FF is the value.
-- Returns the number_string, or nil if the parameter can't be addressed this way
-- (caller then uses the automation engine).
--------------------------------------------------------------------------

local function PPL_EncodeEffect(ctx)
  local dev0 = ctx.device_index - 1
  if dev0 < 0 or dev0 > 15 then return nil end

  if ctx.device_index == 1 then
    -- Track Vol/Pan/Width device: only volume/panning/width are addressable
    local name = ctx.param.name
    if name == "Volume" or name == "Pre Volume" then return "0L"
    elseif name == "Panning" or name == "Pre Panning" then return "0P"
    elseif name == "Width" then return "0W"
    else return nil end
  end

  if ctx.param_index < 1 or ctx.param_index > 15 then return nil end
  return string.format("%X%X", dev0, ctx.param_index)
end

-- Does an effect column already hold OUR command (same device/param code)?
local function PPL_ColumnHoldsCode(effect_column, code)
  return effect_column.number_string == code
end

local function PPL_ColumnIsEmpty(effect_column)
  return effect_column.number_string == "00" or effect_column.number_string == ".."
end

-- Pick the effect column to use: the selected one if it already carries our code
-- or is empty, otherwise the first column that carries our code or is empty.
-- Ensures at least one effect column is visible. Returns column index or nil.
local function PPL_PickEffectColumn(ctx, code)
  local song = renoise.song()
  local track = ctx.track
  if track.visible_effect_columns < 1 then track.visible_effect_columns = 1 end
  local pattern_track = song.selected_pattern:track(ctx.track_index)
  local line = pattern_track:line(song.selected_line_index)

  local selected = song.selected_effect_column_index
  if selected and selected >= 1 and selected <= track.visible_effect_columns then
    local ec = line.effect_columns[selected]
    if PPL_ColumnHoldsCode(ec, code) or PPL_ColumnIsEmpty(ec) then return selected end
  end
  for i = 1, track.visible_effect_columns do
    local ec = line.effect_columns[i]
    if PPL_ColumnHoldsCode(ec, code) or PPL_ColumnIsEmpty(ec) then return i end
  end
  -- none free: try to reveal one more column
  if track.visible_effect_columns < track.max_effect_columns then
    track.visible_effect_columns = track.visible_effect_columns + 1
    return track.visible_effect_columns
  end
  return nil
end

--------------------------------------------------------------------------
-- Effect-column engine
--------------------------------------------------------------------------

local function PPL_EffectWrite(pattern_track, line_index, col, code, amount)
  local ec = pattern_track:line(line_index).effect_columns[col]
  ec.number_string = code
  ec.amount_value = amount
end

-- Clear one of OUR restore/lock commands (only if it carries our code).
local function PPL_EffectClearIfOurs(pattern_track, line_index, col, code)
  local ec = pattern_track:line(line_index).effect_columns[col]
  if ec.number_string == code then
    ec.number_string = "00"
    ec.amount_value = 0
  end
end

-- Find the next note-trig line at or after from_line in a track (returns line or nil).
local function PPL_NextTrigLine(pattern_track, from_line, last_line)
  for line_index = from_line, last_line do
    local nc = pattern_track:line(line_index).note_columns[1]
    if PPL_IsRealNote(nc.note_value) then return line_index end
  end
  return nil
end

local function PPL_EffectLock(ctx, code, lock_value, scope)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local pattern_track = pattern:track(ctx.track_index)
  local line_index = song.selected_line_index
  local last_line = pattern.number_of_lines
  local col = PPL_PickEffectColumn(ctx, code)
  if not col then
    renoise.app():show_status("Paketti Parameter Lock: no free effect column on this track")
    return false
  end

  local baseline = PPL_Baseline(ctx)
  local lock_amount = PPL_ValueToAmount(ctx.param, lock_value)
  local base_amount = PPL_ValueToAmount(ctx.param, baseline)

  song:describe_undo("Paketti Parameter Lock (effect)")

  if scope == "pattern" then
    -- Whole-pattern kit: baseline on every trig, lock on this step.
    for line = 1, last_line do
      local nc = pattern_track:line(line).note_columns[1]
      if PPL_IsRealNote(nc.note_value) then
        PPL_EffectWrite(pattern_track, line, col, code, base_amount)
      end
    end
    PPL_EffectWrite(pattern_track, line_index, col, code, lock_amount)
  else
    -- lock on this step
    PPL_EffectWrite(pattern_track, line_index, col, code, lock_amount)
    -- baseline restore after it
    local restore_line
    if scope == "short" then
      local step = song.transport.edit_step
      if step < 1 then step = 1 end
      restore_line = line_index + step
    else -- "trig"
      restore_line = PPL_NextTrigLine(pattern_track, line_index + 1, last_line)
    end
    if restore_line and restore_line >= 1 and restore_line <= last_line then
      local ec = pattern_track:line(restore_line).effect_columns[col]
      if PPL_ColumnIsEmpty(ec) or PPL_ColumnHoldsCode(ec, code) then
        PPL_EffectWrite(pattern_track, restore_line, col, code, base_amount)
      end
    end
  end
  return true, col
end

local function PPL_EffectUnlock(ctx, code)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local pattern_track = pattern:track(ctx.track_index)
  local line_index = song.selected_line_index
  local baseline = PPL_Baseline(ctx)
  local base_amount = PPL_ValueToAmount(ctx.param, baseline)

  song:describe_undo("Paketti Parameter Lock Unlock (effect)")
  -- restore the step itself to baseline (or clear it if it was our command)
  for col = 1, ctx.track.visible_effect_columns do
    local ec = pattern_track:line(line_index).effect_columns[col]
    if ec.number_string == code then
      ec.amount_value = base_amount
      return true
    end
  end
  renoise.app():show_status("Paketti Parameter Lock: no lock for this parameter on this line")
  return false
end

local function PPL_EffectClearAll(ctx, code)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local pattern_track = pattern:track(ctx.track_index)
  local last_line = pattern.number_of_lines
  song:describe_undo("Paketti Parameter Lock Clear All (effect)")
  local cleared = 0
  for line = 1, last_line do
    for col = 1, ctx.track.visible_effect_columns do
      local ec = pattern_track:line(line).effect_columns[col]
      if ec.number_string == code then
        ec.number_string = "00"
        ec.amount_value = 0
        cleared = cleared + 1
      end
    end
  end
  return cleared
end

--------------------------------------------------------------------------
-- Automation engine (POINTS playmode). Baseline everywhere, lock at the trig.
--------------------------------------------------------------------------

local function PPL_GetEnvelope(ctx, create)
  if not ctx.param.is_automatable then
    renoise.app():show_status("Paketti Parameter Lock: parameter is not automatable")
    return nil
  end
  local song = renoise.song()
  local pattern_track = song:pattern(song.selected_pattern_index):track(ctx.track_index)
  local envelope = pattern_track:find_automation(ctx.param)
  if not envelope and create then
    envelope = pattern_track:create_automation(ctx.param)
  end
  if envelope then envelope.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS end
  return envelope
end

-- Automation value is normalized 0..1 across the parameter range.
local function PPL_ValueToNorm(param, value)
  local span = param.value_max - param.value_min
  if span == 0 then return 0 end
  return math.max(0.0, math.min(1.0, (value - param.value_min) / span))
end

local function PPL_AutomationLock(ctx, lock_value, scope)
  local song = renoise.song()
  local envelope = PPL_GetEnvelope(ctx, true)
  if not envelope then return false end
  local pattern = song.selected_pattern
  local pattern_track = pattern:track(ctx.track_index)
  local line_index = song.selected_line_index
  local last_line = pattern.number_of_lines
  local baseline = PPL_Baseline(ctx)
  local lock_norm = PPL_ValueToNorm(ctx.param, lock_value)
  local base_norm = PPL_ValueToNorm(ctx.param, baseline)

  song:describe_undo("Paketti Parameter Lock (automation)")

  if scope == "pattern" then
    envelope:clear()
    for line = 1, last_line do
      local nc = pattern_track:line(line).note_columns[1]
      if PPL_IsRealNote(nc.note_value) then
        envelope:add_point_at(line, base_norm)
      end
    end
    envelope:add_point_at(line_index, lock_norm)
  else
    envelope:add_point_at(line_index, lock_norm)
    local restore_line
    if scope == "short" then
      local step = song.transport.edit_step
      if step < 1 then step = 1 end
      restore_line = line_index + step
    else
      restore_line = PPL_NextTrigLine(pattern_track, line_index + 1, last_line)
    end
    if restore_line and restore_line >= 1 and restore_line <= last_line then
      envelope:add_point_at(restore_line, base_norm)
    end
  end
  return true
end

local function PPL_AutomationUnlock(ctx)
  local song = renoise.song()
  local envelope = PPL_GetEnvelope(ctx, false)
  if not envelope then renoise.app():show_status("Paketti Parameter Lock: no automation for this parameter") return false end
  local line_index = song.selected_line_index
  local base_norm = PPL_ValueToNorm(ctx.param, PPL_Baseline(ctx))
  song:describe_undo("Paketti Parameter Lock Unlock (automation)")
  envelope:add_point_at(line_index, base_norm)
  return true
end

local function PPL_AutomationClearAll(ctx)
  local envelope = PPL_GetEnvelope(ctx, false)
  if not envelope then return 0 end
  renoise.song():describe_undo("Paketti Parameter Lock Clear All (automation)")
  envelope:clear()
  return 1
end

--------------------------------------------------------------------------
-- Public actions (engine dispatch + effect->automation fallback)
--------------------------------------------------------------------------

function PakettiParameterLockSetBaseline()
  local ctx = PPL_ResolveSelectedParameter()
  if not ctx then return end
  PakettiParameterLockBaselines[PPL_Key(ctx)] = ctx.param.value
  renoise.app():show_status(string.format("Paketti Parameter Lock: baseline for %s = %s",
    ctx.param.name, ctx.param.value_string))
end

-- lock_value: native value; nil = use the parameter's current value.
function PakettiParameterLockLock(scope, lock_value)
  local ctx = PPL_ResolveSelectedParameter()
  if not ctx then return end
  scope = scope or PakettiParameterLockScope
  if lock_value == nil then lock_value = ctx.param.value end

  local engine = PakettiParameterLockEngine
  if engine == "effect" then
    local code = PPL_EncodeEffect(ctx)
    if code then
      local ok = PPL_EffectLock(ctx, code, lock_value, scope)
      if ok then
        renoise.app():show_status(string.format("Paketti Parameter Lock: locked %s (%s, effect %s)", ctx.param.name, scope, code))
      end
      return
    end
    renoise.app():show_status("Paketti Parameter Lock: parameter not effect-addressable, using automation")
  end
  if PPL_AutomationLock(ctx, lock_value, scope) then
    renoise.app():show_status(string.format("Paketti Parameter Lock: locked %s (%s, automation)", ctx.param.name, scope))
  end
end

function PakettiParameterLockUnlock()
  local ctx = PPL_ResolveSelectedParameter()
  if not ctx then return end
  if PakettiParameterLockEngine == "effect" then
    local code = PPL_EncodeEffect(ctx)
    if code then PPL_EffectUnlock(ctx, code) return end
  end
  PPL_AutomationUnlock(ctx)
end

function PakettiParameterLockClear()
  local ctx = PPL_ResolveSelectedParameter()
  if not ctx then return end
  local cleared = 0
  if PakettiParameterLockEngine == "effect" then
    local code = PPL_EncodeEffect(ctx)
    if code then cleared = PPL_EffectClearAll(ctx, code)
    else cleared = PPL_AutomationClearAll(ctx) end
  else
    cleared = PPL_AutomationClearAll(ctx)
  end
  renoise.app():show_status(string.format("Paketti Parameter Lock: cleared %d lock command(s) for %s", cleared, ctx.param.name))
end

--------------------------------------------------------------------------
-- Dialog
--------------------------------------------------------------------------

function PakettiParameterLockDialogShow()
  if PakettiParameterLockDialog and PakettiParameterLockDialog.visible then
    PakettiParameterLockDialog:close()
    PakettiParameterLockDialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local scope_ids = {"short", "trig", "pattern"}
  local scope_labels = {"This trig only (Short)", "Until next trig (Elektron)", "Whole-pattern kit"}
  local engine_ids = {"effect", "automation"}

  local function scope_value_from_id(id) for i, v in ipairs(scope_ids) do if v == id then return i end end return 2 end
  local function engine_value_from_id(id) for i, v in ipairs(engine_ids) do if v == id then return i end end return 1 end

  local param_label = vb:text{text = "(no parameter selected)", width = 300, font = "bold"}
  local function refresh_param_label()
    local song = renoise.song()
    if song.selected_device and song.selected_parameter then
      param_label.text = string.format("%s : %s = %s", song.selected_device.display_name,
        song.selected_parameter.name, song.selected_parameter.value_string)
    else
      param_label.text = "(select a device parameter)"
    end
  end
  refresh_param_label()

  local content = vb:column{
    margin = 8, spacing = 6,
    vb:row{spacing = 6, vb:text{text = "Parameter", width = 70}, param_label,
      vb:button{text = "Refresh", width = 60, pressed = refresh_param_label}},
    vb:row{spacing = 6,
      vb:text{text = "Engine", width = 70},
      vb:popup{id = "ppl_engine", width = 160, items = {"Effect column", "Automation"}, value = engine_value_from_id(PakettiParameterLockEngine),
        notifier = function(v) PakettiParameterLockEngine = engine_ids[v] end}},
    vb:row{spacing = 6,
      vb:text{text = "Scope", width = 70},
      vb:popup{id = "ppl_scope", width = 200, items = scope_labels, value = scope_value_from_id(PakettiParameterLockScope),
        notifier = function(v) PakettiParameterLockScope = scope_ids[v] end}},
    vb:row{spacing = 6,
      vb:button{text = "Set Baseline (kit)", width = 130, tooltip = "Snapshot the parameter's current value as the restore/kit value", pressed = function() PakettiParameterLockSetBaseline() refresh_param_label() end}},
    vb:row{spacing = 6,
      vb:button{text = "Lock at cursor", width = 110, tooltip = "Write the parameter's current value as a p-lock on this step", pressed = function() PakettiParameterLockLock(PakettiParameterLockScope, nil) end},
      vb:button{text = "Un-lock", width = 80, pressed = function() PakettiParameterLockUnlock() end},
      vb:button{text = "Clear all", width = 80, tooltip = "Remove every lock for this parameter in the pattern", pressed = function() PakettiParameterLockClear() end}},
    vb:text{text = "Tip: move the knob to the value you want, then Lock at cursor.", font = "italic"}
  }

  local function keyhandler(dialog, key)
    if key.name == "esc" then dialog:close() PakettiParameterLockDialog = nil else return key end
  end
  PakettiParameterLockDialog = renoise.app():show_custom_dialog("Paketti Parameter Lock", content, keyhandler)
end

--------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock Dialog...", invoke=function() PakettiParameterLockDialogShow() end}
renoise.tool():add_keybinding{name="Global:Paketti:Parameter Lock Dialog...", invoke=function() PakettiParameterLockDialogShow() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock Set Baseline", invoke=function() PakettiParameterLockSetBaseline() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock at Cursor (Until Next Trig)", invoke=function() PakettiParameterLockLock("trig", nil) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock at Cursor (Short)", invoke=function() PakettiParameterLockLock("short", nil) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock at Cursor (Whole Pattern Kit)", invoke=function() PakettiParameterLockLock("pattern", nil) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock Un-lock at Cursor", invoke=function() PakettiParameterLockUnlock() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Parameter Lock Clear All for Parameter", invoke=function() PakettiParameterLockClear() end}

renoise.tool():add_midi_mapping{name="Paketti:Parameter Lock Dialog [Trigger]", invoke=function(message) if message:is_trigger() then PakettiParameterLockDialogShow() end end}
renoise.tool():add_midi_mapping{name="Paketti:Parameter Lock Set Baseline [Trigger]", invoke=function(message) if message:is_trigger() then PakettiParameterLockSetBaseline() end end}
renoise.tool():add_midi_mapping{name="Paketti:Parameter Lock at Cursor (Until Next Trig) [Trigger]", invoke=function(message) if message:is_trigger() then PakettiParameterLockLock("trig", nil) end end}
renoise.tool():add_midi_mapping{name="Paketti:Parameter Lock Un-lock at Cursor [Trigger]", invoke=function(message) if message:is_trigger() then PakettiParameterLockUnlock() end end}

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Parameter Lock Dialog...", invoke=function() PakettiParameterLockDialogShow() end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Parameter Lock Dialog...", invoke=function() PakettiParameterLockDialogShow() end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Set Baseline (Kit)", invoke=function() PakettiParameterLockSetBaseline() end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Lock at Cursor (Until Next Trig)", invoke=function() PakettiParameterLockLock("trig", nil) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Lock at Cursor (Short)", invoke=function() PakettiParameterLockLock("short", nil) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Lock at Cursor (Whole Pattern Kit)", invoke=function() PakettiParameterLockLock("pattern", nil) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Un-lock at Cursor", invoke=function() PakettiParameterLockUnlock() end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Parameter Lock:Clear All for Parameter", invoke=function() PakettiParameterLockClear() end}
