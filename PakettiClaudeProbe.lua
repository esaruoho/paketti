-- PakettiClaudeProbe.lua
-- The Claude×Renoise feedback loop.
--
-- A keybinding/menu/OSC-callable function that evaluates a Lua expression
-- IN TOOL CONTEXT (full io access, unlike /renoise/evaluate's sandbox),
-- serializes the result, and writes it to /tmp/paketti-probe.txt for Claude
-- to read.
--
-- Public API:
--   PakettiClaudeProbeRun(expr_string [, label])
--     -- Eval expr, dump result to /tmp/paketti-probe.txt
--   PakettiClaudeProbeQuick(label, value)
--     -- Skip eval, dump an already-computed value (used by quick probes)
--   PakettiClaudeProbeDialog()
--     -- Open a prompt for a custom expression, then run it
--
-- Output file format:
--   ===== PAKETTI CLAUDE PROBE =====
--   timestamp: 2026-05-08 17:55:03
--   label: <label>
--   expression: <expr_string or N/A>
--   type: <lua type of result>
--   ok: true|false
--   ===============================
--   <serialized result or error message>

local PROBE_OUT = "/tmp/paketti-probe.txt"

local function serialize(v, depth, seen, max_depth)
  depth = depth or 0
  seen = seen or {}
  max_depth = max_depth or 8
  if depth > max_depth then return "<max-depth>" end

  local t = type(v)
  if t == "nil" then return "nil"
  elseif t == "boolean" or t == "number" then return tostring(v)
  elseif t == "string" then return string.format("%q", v)
  elseif t == "function" then return "<function>"
  elseif t == "thread" then return "<thread>"
  elseif t == "userdata" then
    -- Renoise userdata's tostring usually gives a useful description
    local ok, s = pcall(tostring, v)
    return ok and s or "<userdata>"
  elseif t == "table" then
    if seen[v] then return "<cycle>" end
    seen[v] = true
    local parts = {}
    local indent = string.rep("  ", depth)
    -- Stable key order: numeric keys first (sorted), then string keys (sorted), then others
    local nkeys, skeys, okeys = {}, {}, {}
    for k in pairs(v) do
      local kt = type(k)
      if kt == "number" then nkeys[#nkeys+1] = k
      elseif kt == "string" then skeys[#skeys+1] = k
      else okeys[#okeys+1] = k
      end
    end
    table.sort(nkeys)
    table.sort(skeys)
    local function emit(k)
      parts[#parts+1] = indent .. "  [" .. serialize(k, depth+1, seen, max_depth) .. "] = "
                         .. serialize(v[k], depth+1, seen, max_depth)
    end
    for _, k in ipairs(nkeys) do emit(k) end
    for _, k in ipairs(skeys) do emit(k) end
    for _, k in ipairs(okeys) do emit(k) end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
  end
  return "<" .. t .. ">"
end

local function write_probe(label, expr_string, ok, value)
  local f, err = io.open(PROBE_OUT, "w")
  if not f then
    renoise.app():show_status("Paketti probe: cannot write " .. PROBE_OUT .. ": " .. tostring(err))
    return false
  end
  f:write("===== PAKETTI CLAUDE PROBE =====\n")
  f:write("timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
  f:write("label: " .. tostring(label or "(none)") .. "\n")
  f:write("expression: " .. tostring(expr_string or "N/A") .. "\n")
  f:write("type: " .. type(value) .. "\n")
  f:write("ok: " .. tostring(ok) .. "\n")
  f:write("===============================\n")
  if ok then
    local body = serialize(value)
    -- Truncate ridiculously huge dumps to keep the file useful
    if #body > 500000 then
      body = body:sub(1, 500000) .. "\n... [truncated, " .. #body .. " bytes total]"
    end
    f:write(body)
  else
    f:write("ERROR: " .. tostring(value))
  end
  f:write("\n")
  f:close()
  return true
end

-- Programmatic API: evaluate a Lua expression string in tool context
function PakettiClaudeProbeRun(expr_string, label)
  if type(expr_string) ~= "string" or expr_string == "" then
    renoise.app():show_status("Paketti probe: empty expression")
    return
  end
  -- Try as expression first (so "song().bpm" returns the value), fall back to chunk
  local chunk, err = loadstring("return (" .. expr_string .. "\n)")
  if not chunk then chunk, err = loadstring(expr_string) end
  if not chunk then
    write_probe(label, expr_string, false, "parse error: " .. tostring(err))
    renoise.app():show_status("Paketti probe: parse error → " .. PROBE_OUT)
    return
  end
  local ok, result = pcall(chunk)
  write_probe(label, expr_string, ok, result)
  if ok then
    renoise.app():show_status("Paketti probe: dumped (" .. type(result) .. ") → " .. PROBE_OUT)
  else
    renoise.app():show_status("Paketti probe: runtime error → " .. PROBE_OUT)
  end
end

-- Skip eval, dump an already-computed value (used by quick keybindings that
-- want to bypass the loadstring step entirely)
function PakettiClaudeProbeQuick(label, value)
  write_probe(label, nil, true, value)
  renoise.app():show_status("Paketti probe: " .. tostring(label) .. " (" .. type(value) .. ") → " .. PROBE_OUT)
end

-- Custom expression dialog
function PakettiClaudeProbeDialog()
  local vb = renoise.ViewBuilder()
  local input = vb:textfield {
    width = 600,
    text = "renoise.song().selected_track.name"
  }
  local dialog
  local function run_it()
    local expr = input.text
    if dialog then dialog:close() end
    PakettiClaudeProbeRun(expr, "custom")
  end
  local content = vb:column {
    margin = 8, spacing = 6,
    vb:text { text = "Lua expression to dump for Claude (result → " .. PROBE_OUT .. "):" },
    input,
    vb:row {
      spacing = 4,
      vb:button { text = "Run", width = 70, notifier = run_it },
      vb:button { text = "Cancel", width = 70, notifier = function() if dialog then dialog:close() end end }
    }
  }
  local function key_handler(d, key)
    if key.name == "return" then run_it() return nil end
    if key.name == "esc" then d:close() return nil end
    return key
  end
  dialog = renoise.app():show_custom_dialog("Paketti × Claude Probe", content, key_handler)
end

-- Quick probes (no typing required, just hit a keybinding)
function PakettiClaudeProbeSelectedTrack()
  local t = renoise.song().selected_track
  local devices = {}
  for i, d in ipairs(t.devices) do
    devices[i] = { index = i, name = d.name, display_name = d.display_name, device_path = d.device_path }
  end
  PakettiClaudeProbeQuick("selected_track", {
    name = t.name,
    type = t.type,
    color = t.color,
    mute_state = t.mute_state,
    devices_count = #t.devices,
    devices = devices,
    visible_note_columns = t.visible_note_columns,
    visible_effect_columns = t.visible_effect_columns,
  })
end

function PakettiClaudeProbeAvailableDevices()
  local t = renoise.song().selected_track
  PakettiClaudeProbeQuick("available_device_infos", t.available_device_infos)
end

function PakettiClaudeProbeSelectedInstrument()
  local i = renoise.song().selected_instrument
  local samples = {}
  for idx, s in ipairs(i.samples) do
    samples[idx] = {
      name = s.name,
      transpose = s.transpose,
      fine_tune = s.fine_tune,
      volume = s.volume,
      panning = s.panning,
      slice_count = #(s.slice_markers or {}),
    }
  end
  PakettiClaudeProbeQuick("selected_instrument", {
    name = i.name,
    samples_count = #i.samples,
    samples = samples,
    plugin_name = i.plugin_properties and i.plugin_properties.plugin_loaded
                  and i.plugin_properties.plugin_device.name or nil,
    phrases_count = #i.phrases,
  })
end

function PakettiClaudeProbeSong()
  local s = renoise.song()
  PakettiClaudeProbeQuick("song", {
    bpm = s.transport.bpm,
    lpb = s.transport.lpb,
    name = s.name,
    artist = s.artist,
    tracks_count = #s.tracks,
    instruments_count = #s.instruments,
    patterns_count = #s.patterns,
    selected_track_index = s.selected_track_index,
    selected_instrument_index = s.selected_instrument_index,
    selected_pattern_index = s.selected_pattern_index,
  })
end

-- Keybindings (3 colon parts only — flat names!)
renoise.tool():add_keybinding{
  name = "Global:Paketti:Claude Probe Custom Expression",
  invoke = PakettiClaudeProbeDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Claude Probe Selected Track",
  invoke = PakettiClaudeProbeSelectedTrack
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Claude Probe Available Devices",
  invoke = PakettiClaudeProbeAvailableDevices
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Claude Probe Selected Instrument",
  invoke = PakettiClaudeProbeSelectedInstrument
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Claude Probe Song",
  invoke = PakettiClaudeProbeSong
}

-- Menu entries
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:Claude Probe Custom Expression...",
  invoke = PakettiClaudeProbeDialog
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:Claude Probe Selected Track",
  invoke = PakettiClaudeProbeSelectedTrack
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:Claude Probe Available Devices",
  invoke = PakettiClaudeProbeAvailableDevices
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:Claude Probe Selected Instrument",
  invoke = PakettiClaudeProbeSelectedInstrument
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:Claude Probe Song",
  invoke = PakettiClaudeProbeSong
}
