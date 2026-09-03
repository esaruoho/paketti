--[[============================================================================
PakettiRemoveMissingPlugins.lua

Finds effect plugins a song refers to that are not installed any more, and
optionally removes them.

When you open a song on a machine that is missing a VST/VST3/AU/LADSPA/DSSI it
used, Renoise keeps the device in the chain as a dead placeholder. They pile up
in old songs and on machines you moved to. This finds every one of them.

Three places are checked:
  - track DSP chains        (removable)
  - sample FX chains        (removable)
  - instrument plugins      (REPORTED ONLY - removing one guts the instrument,
                             so that stays your decision)

A device is judged missing by comparing its device_path against the chain's own
available_devices list. Native, routing and meta devices are never touched,
because only paths under Audio/Effects/<VST|VST3|AU|LADSPA|DSSI>/ are
considered in the first place.

Scan first, remove second: the plain command only reports and hands you a
"Remove Them" button, so a destructive sweep is never one misclick away.
============================================================================]]--

local PakettiRMPPluginTypes = {VST = true, VST3 = true, AU = true, LADSPA = true, DSSI = true}
local PakettiRMPDialog = nil

local function PakettiRMPSafeString(getter, fallback)
  local ok, value = pcall(getter)
  if ok and type(value) == "string" and value ~= "" then return value end
  return fallback or ""
end

-- Only Audio/Effects/<TYPE>/... paths are plugins; everything else is native.
local function PakettiRMPPluginType(path)
  if type(path) ~= "string" or path == "" then return nil end
  local plugin_type = path:match("^Audio/Effects/([^/]+)/")
  if plugin_type and PakettiRMPPluginTypes[plugin_type] then return plugin_type end
  return nil
end

local function PakettiRMPDeviceLabel(device, path)
  local label = PakettiRMPSafeString(function() return device.display_name end)
  if label == "" then label = PakettiRMPSafeString(function() return device.name end) end
  if label == "" then label = PakettiRMPSafeString(function() return device.short_name end) end
  if label == "" and type(path) == "string" then label = path:match("([^/]+)$") or path end
  if label == "" then label = "Unknown plugin" end
  return label
end

-- Walks one device chain and appends anything missing to findings.
local function PakettiRMPScanChain(chain, location, kind, instrument_index, chain_index, track_index, findings)
  local available = {}
  local ok = pcall(function()
    for _, path in ipairs(chain.available_devices) do available[path] = true end
  end)
  if not ok then return end

  -- Index 1 is the chain's own mixer device, but it is a Native path so the
  -- plugin-type filter below already excludes it. No index juggling needed.
  for device_index = 1, #chain.devices do
    local device = chain.devices[device_index]
    local path = PakettiRMPSafeString(function() return device.device_path end)
    local plugin_type = PakettiRMPPluginType(path)
    if plugin_type and not available[path] then
      findings[#findings + 1] = {
        kind = kind,
        location = location,
        track_index = track_index,
        instrument_index = instrument_index,
        chain_index = chain_index,
        device_index = device_index,
        plugin_type = plugin_type,
        plugin_name = PakettiRMPDeviceLabel(device, path),
        device_path = path
      }
    end
  end
end

-- Returns removable findings, plus report-only findings for instrument plugins.
function PakettiScanMissingPlugins()
  local song = renoise.song()
  local findings, instrument_findings = {}, {}

  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    local name = PakettiRMPSafeString(function() return track.name end)
    local location = string.format("Track %02d%s", track_index,
      name ~= "" and (" '" .. name .. "'") or "")
    PakettiRMPScanChain(track, location, "track", nil, nil, track_index, findings)
  end

  for instrument_index = 1, #song.instruments do
    local instrument = song.instruments[instrument_index]
    local instrument_name = PakettiRMPSafeString(function() return instrument.name end)

    local ok_chains = pcall(function() return instrument.sample_device_chains end)
    if ok_chains and instrument.sample_device_chains then
      for chain_index = 1, #instrument.sample_device_chains do
        local chain = instrument.sample_device_chains[chain_index]
        local chain_name = PakettiRMPSafeString(function() return chain.name end)
        local location = string.format("Instrument %02X%s - FX chain %d%s",
          instrument_index - 1,
          instrument_name ~= "" and (" '" .. instrument_name .. "'") or "",
          chain_index,
          chain_name ~= "" and (" '" .. chain_name .. "'") or "")
        PakettiRMPScanChain(chain, location, "samplechain", instrument_index, chain_index, nil, findings)
      end
    end

    -- Instrument plugins are reported only. Deleting one throws away the
    -- instrument's plugin settings, which is not a housekeeping decision.
    local ok_plugin, missing = pcall(function()
      local properties = instrument.plugin_properties
      return properties ~= nil
        and PakettiRMPSafeString(function() return properties.plugin_path end) ~= ""
        and not properties.plugin_loaded
    end)
    if ok_plugin and missing then
      instrument_findings[#instrument_findings + 1] = {
        location = string.format("Instrument %02X%s", instrument_index - 1,
          instrument_name ~= "" and (" '" .. instrument_name .. "'") or ""),
        device_path = PakettiRMPSafeString(function() return instrument.plugin_properties.plugin_path end)
      }
    end
  end

  return findings, instrument_findings
end

local function PakettiRMPBuildReport(findings, instrument_findings, removed_count, failed)
  local lines = {}

  if removed_count then
    lines[#lines + 1] = string.format("Removed %d missing plugin%s.",
      removed_count, removed_count == 1 and "" or "s")
    lines[#lines + 1] = ""
  elseif #findings == 0 and #instrument_findings == 0 then
    return "No missing plugins found - every plugin this song uses is installed."
  else
    lines[#lines + 1] = string.format("Found %d missing effect plugin%s.",
      #findings, #findings == 1 and "" or "s")
    lines[#lines + 1] = ""
  end

  local current = nil
  for _, item in ipairs(findings) do
    if item.location ~= current then
      if current ~= nil then lines[#lines + 1] = "" end
      lines[#lines + 1] = item.location
      current = item.location
    end
    lines[#lines + 1] = string.format("   %s: %s", item.plugin_type, item.plugin_name)
  end

  if failed and #failed > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("%d removal%s failed:", #failed, #failed == 1 and "" or "s")
    for _, item in ipairs(failed) do
      lines[#lines + 1] = string.format("   %s - %s: %s",
        item.location, item.plugin_name, item.error or "unknown error")
    end
  end

  if #instrument_findings > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format(
      "%d instrument plugin%s missing - NOT removed, since that would throw away the instrument's settings:",
      #instrument_findings, #instrument_findings == 1 and " is" or "s are")
    for _, item in ipairs(instrument_findings) do
      lines[#lines + 1] = string.format("   %s: %s", item.location, item.device_path)
    end
  end

  return table.concat(lines, "\n")
end

-- Deletes highest index first so earlier indices stay valid.
local function PakettiRMPRemove(findings)
  local song = renoise.song()

  table.sort(findings, function(a, b)
    local ak = (a.track_index or 0) * 100000 + (a.instrument_index or 0) * 1000 + (a.chain_index or 0)
    local bk = (b.track_index or 0) * 100000 + (b.instrument_index or 0) * 1000 + (b.chain_index or 0)
    if ak ~= bk then return ak > bk end
    return a.device_index > b.device_index
  end)

  song:describe_undo("Paketti: Remove Missing Plugins")

  local removed, failed = {}, {}
  for _, item in ipairs(findings) do
    local ok, err = pcall(function()
      if item.kind == "track" then
        song.tracks[item.track_index]:delete_device_at(item.device_index)
      else
        song.instruments[item.instrument_index].sample_device_chains[item.chain_index]
          :delete_device_at(item.device_index)
      end
    end)
    if ok then removed[#removed + 1] = item else
      item.error = tostring(err)
      failed[#failed + 1] = item
    end
  end

  return removed, failed
end

local function PakettiRMPShowDialog(text, findings, instrument_findings, allow_remove)
  if PakettiRMPDialog and PakettiRMPDialog.visible then PakettiRMPDialog:close() end

  local vb = renoise.ViewBuilder()
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTROL_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

  local buttons = vb:row{spacing = CONTROL_SPACING}

  if allow_remove and #findings > 0 then
    buttons:add_child(vb:button{
      text = string.format("Remove These %d", #findings),
      width = 140,
      notifier = function()
        local removed, failed = PakettiRMPRemove(findings)
        local report = PakettiRMPBuildReport(removed, instrument_findings, #removed, failed)
        print(report)
        renoise.app():show_status(string.format(
          "Remove Missing Plugins: removed %d, %d failed.", #removed, #failed))
        PakettiRMPShowDialog(report, {}, instrument_findings, false)
      end})
  end

  buttons:add_child(vb:button{
    text = "Close", width = 90,
    notifier = function()
      if PakettiRMPDialog and PakettiRMPDialog.visible then PakettiRMPDialog:close() end
      PakettiRMPDialog = nil
    end})

  local content = vb:column{
    margin = DIALOG_MARGIN,
    spacing = CONTROL_SPACING,
    vb:multiline_text{text = text, width = 560, height = 300, font = "mono"},
    buttons
  }

  PakettiRMPDialog = renoise.app():show_custom_dialog(
    "Paketti Remove Missing Plugins", content,
    function(dialog, key)
      if key.modifiers == "" and key.name == "esc" then
        dialog:close()
        PakettiRMPDialog = nil
        return nil
      end
      return key
    end)
end

-- Scans and reports, offering removal as a button.
function PakettiFindMissingPlugins()
  local findings, instrument_findings = PakettiScanMissingPlugins()
  local report = PakettiRMPBuildReport(findings, instrument_findings, nil, nil)
  print(report)

  if #findings == 0 and #instrument_findings == 0 then
    renoise.app():show_status("Remove Missing Plugins: no missing plugins found.")
  else
    renoise.app():show_status(string.format(
      "Remove Missing Plugins: %d missing effect plugin(s), %d missing instrument plugin(s).",
      #findings, #instrument_findings))
  end

  PakettiRMPShowDialog(report, findings, instrument_findings, true)
end

-- Scans and removes straight away, for when you already know.
function PakettiRemoveMissingPlugins()
  local findings, instrument_findings = PakettiScanMissingPlugins()

  if #findings == 0 then
    local report = PakettiRMPBuildReport(findings, instrument_findings, nil, nil)
    print(report)
    renoise.app():show_status("Remove Missing Plugins: nothing to remove.")
    PakettiRMPShowDialog(report, {}, instrument_findings, false)
    return
  end

  local removed, failed = PakettiRMPRemove(findings)
  local report = PakettiRMPBuildReport(removed, instrument_findings, #removed, failed)
  print(report)
  renoise.app():show_status(string.format(
    "Remove Missing Plugins: removed %d missing plugin(s)%s.",
    #removed, #failed > 0 and string.format(", %d failed", #failed) or ""))
  PakettiRMPShowDialog(report, {}, instrument_findings, false)
end

----------------------------------------------------------------------------
-- Menu entries, keybindings, MIDI mappings
----------------------------------------------------------------------------

local PakettiRMPActions = {
  {label = "Find Missing Plugins...", run = PakettiFindMissingPlugins},
  {label = "Remove Missing Plugins", run = PakettiRemoveMissingPlugins}
}

for _, action in ipairs(PakettiRMPActions) do
  local label, run = action.label, action.run
  PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Plugins/Devices:" .. label, invoke=run}
  PakettiAddMenuEntry{name="Mixer:Paketti:" .. label, invoke=run}
  PakettiAddMenuEntry{name="DSP Chain:Paketti:" .. label, invoke=run}
  renoise.tool():add_keybinding{name="Global:Paketti:" .. label, invoke=run}
  renoise.tool():add_midi_mapping{name="Paketti:" .. label, invoke=function(message)
    if message:is_trigger() then run() end
  end}
end
