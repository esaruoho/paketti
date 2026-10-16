--[[============================================================================
PakettiDebug.lua — diagnostics for support reports

Two tools live here:

  * PakettiDumpAllSettings() — writes a single text file with EVERY Paketti
    preference (every path, checkbox and value), plus an environment header and
    the resolved RX2 decoder paths. This is the "give me all the info" method:
    when something misbehaves, dump this and send it in.

  * PakettiWavHookProbeRegister() — an experiment. Renoise is supposed to own
    .wav loading, so Paketti cannot normally intercept a dragged .wav. This
    registers a .wav sample import hook at runtime and, on the next .wav, shows
    a dialog proving the hook fired. If it fires, Paketti CAN control .wav drops
    (and "N dropped wavs = N instruments" becomes buildable). The hook stays
    active until Renoise is restarted.
============================================================================]]--

local separator = package.config:sub(1,1)

--------------------------------------------------------------------------------
-- Full settings dump
--------------------------------------------------------------------------------

local function paketti_debug_desktop_dir()
  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if home and home ~= "" then return home .. separator .. "Desktop" end
  return nil
end

--- Turn the preferences XML into a flat "Section.Name = value" listing.
local function paketti_flatten_xml(xml)
  local out, stack = {}, {}
  for raw in (xml .. "\n"):gmatch("(.-)\n") do
    local line = raw:gsub("\r", "")
    local tag, val = line:match("^%s*<([%w_]+)>(.-)</[%w_]+>%s*$")
    if tag then
      local prefix = (#stack > 0) and (table.concat(stack, ".") .. ".") or ""
      out[#out + 1] = prefix .. tag .. " = " .. val
    else
      local open = line:match("^%s*<([%w_]+)>%s*$")
      if open then
        stack[#stack + 1] = open
      else
        local close = line:match("^%s*</([%w_]+)>%s*$")
        if close and #stack > 0 then stack[#stack] = nil end
      end
    end
  end
  return table.concat(out, "\n")
end

function PakettiDumpAllSettings()
  local bundle = renoise.tool().bundle_path
  local xml_name = "PakettiSettingsDump.xml"
  local xml_path = bundle .. xml_name

  -- Write the complete preferences document to XML (relative = bundle folder).
  local saved = pcall(function() preferences:save_as(xml_name) end)

  local xml = ""
  if saved then
    local f = io.open(xml_path, "r")
    if f then xml = f:read("*a") or "" f:close() end
    pcall(function() os.remove(xml_path) end)
  end

  -- Build the report.
  local L = {}
  local function add(s) L[#L + 1] = s end

  add("PAKETTI SETTINGS DUMP")
  add("Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
  add("")
  add("-- Environment --")
  add("OS platform:   " .. tostring(os.platform()))
  add("Renoise:       " .. tostring(renoise.RENOISE_VERSION))
  add("API version:   " .. tostring(renoise.API_VERSION))
  add("Tool bundle:   " .. tostring(bundle))
  add("TEMP/TMPDIR:   " .. tostring(os.getenv("TEMP") or os.getenv("TMPDIR") or "(unset)"))
  add("HOME:          " .. tostring(os.getenv("HOME") or os.getenv("USERPROFILE") or "(unset)"))
  add("")

  -- Resolved RX2 decoder paths, since those are a common support question.
  if type(rawget(_G, "PakettiRX2SetupDecoderPaths")) == "function" then
    local ok, _, rex_path, sdk = pcall(PakettiRX2SetupDecoderPaths)
    add("-- RX2 decoder (resolved) --")
    if ok then
      add("Decoder path:  " .. tostring(rex_path))
      add("SDK path:      " .. tostring(sdk))
      add("Decoder exists: " .. tostring(rex_path and io.exists(rex_path) or false))
    else
      add("Could not resolve decoder paths.")
    end
    add("")
  end

  add("-- All Paketti preferences (flattened) --")
  if xml ~= "" then
    add(paketti_flatten_xml(xml))
  else
    add("(could not read preferences XML)")
  end
  add("")
  add("-- All Paketti preferences (raw XML) --")
  add(xml ~= "" and xml or "(none)")

  local report = table.concat(L, "\n")

  -- Write the text file somewhere easy to find.
  local dir = paketti_debug_desktop_dir() or bundle
  local out_path = dir .. separator .. "PakettiSettingsDump.txt"
  local wf = io.open(out_path, "w")
  if not wf then
    -- fall back to the bundle folder
    out_path = bundle .. "PakettiSettingsDump.txt"
    wf = io.open(out_path, "w")
  end
  if wf then wf:write(report) wf:close() end

  print("================ PAKETTI SETTINGS DUMP ================")
  print(report)
  print("======================================================")

  -- Show a dialog with the path and a preview.
  local vb = renoise.ViewBuilder()
  local dialog
  local content = vb:column{
    margin = 10, spacing = 8,
    vb:text{ text = "Paketti settings dumped", style = "strong" },
    vb:text{ text = "Saved to:" },
    vb:text{ text = out_path, font = "mono" },
    vb:multiline_text{ text = report, width = 600, height = 420, font = "mono" },
    vb:row{ spacing = 8,
      vb:button{ text = "Email the file to esaruoho@gmail.com", width = 300,
        notifier = function()
          local url = "mailto:esaruoho@gmail.com?subject="
            .. "Paketti%20settings%20dump&body="
            .. "Paketti%20settings%20dump%20is%20attached.%20File%20is%20at%3A%20"
            .. (out_path:gsub("[^%w%-_%.~]", function(c)
                 return string.format("%%%02X", string.byte(c)) end))
            .. "%20%28please%20attach%20it%29."
          if os.platform() == "WINDOWS" then
            pcall(function() os.execute('cmd /c start "" "' .. url .. '"') end)
          elseif os.platform() == "MACINTOSH" then
            pcall(function() os.execute('open "' .. url .. '"') end)
          else
            pcall(function() os.execute('xdg-open "' .. url .. '" >/dev/null 2>&1 &') end)
          end
        end },
      vb:button{ text = "Close", width = 100,
        notifier = function() if dialog and dialog.visible then dialog:close() end end },
    },
  }
  dialog = renoise.app():show_custom_dialog("Paketti Settings Dump", content)
  renoise.app():show_status("Paketti settings dumped to: " .. out_path)
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:!Preferences:Dump All Settings to Text File...",
  invoke=function() PakettiDumpAllSettings() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Dump All Paketti Settings to Text File...",
  invoke=function() PakettiDumpAllSettings() end}
renoise.tool():add_keybinding{name="Global:Paketti:Dump All Settings to Text File",
  invoke=function() PakettiDumpAllSettings() end}

--------------------------------------------------------------------------------
-- Experimental .wav import hook probe
--------------------------------------------------------------------------------

function PakettiWavHookProbeRegister()
  if renoise.tool():has_file_import_hook("sample", {"wav"}) then
    renoise.app():show_message(
      "A .wav sample import hook is already registered this session.\n\n"
      .. "Drag a .wav in to see whether the hook fires. To start over, restart "
      .. "Renoise (import hooks cannot be removed at runtime).")
    return
  end

  local ok, err = pcall(function()
    renoise.tool():add_file_import_hook{
      category = "sample",
      extensions = { "wav" },
      invoke = function(file_name)
        renoise.app():show_message(
          "WOW PAKETTI LOADED THIS .WAV WOO\n\n"
          .. tostring(file_name)
          .. "\n\n(This is the Paketti wav-hook probe. The hook fired, which "
          .. "means Paketti CAN control .wav drops. It now deliberately does "
          .. "NOT load the file, to prove the interception. Restart Renoise to "
          .. "restore normal .wav loading.)")
        return false  -- deliberately fail, so we can see the hook intercepted it
      end,
    }
  end)

  if ok then
    renoise.app():show_message(
      "Paketti registered an experimental .wav import hook.\n\n"
      .. "Now drag a .wav into Renoise. If a 'WOW PAKETTI...' dialog appears, "
      .. "the hook controls .wav loading and we can build 'N dropped wavs = N "
      .. "instruments'.\n\nWARNING: while this hook is active, dragging a .wav "
      .. "shows the dialog and then FAILS to load (that is the test). Restart "
      .. "Renoise to restore normal .wav loading.")
    print("-- PakettiWavHookProbe: wav import hook registered successfully")
  else
    renoise.app():show_message(
      "Renoise REFUSED the .wav import hook:\n\n" .. tostring(err)
      .. "\n\nThat means Paketti cannot intercept .wav drops, and 'N dropped "
      .. "wavs = N instruments' has to be done after the fact with "
      .. "'Isolate Slices or Samples to New Instruments'.")
    print("-- PakettiWavHookProbe: registration FAILED: " .. tostring(err))
  end
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Experimental:[TEST] Register .wav Import Hook Probe...",
  invoke=function() PakettiWavHookProbeRegister() end}
renoise.tool():add_keybinding{name="Global:Paketti:[TEST] Register wav Import Hook Probe",
  invoke=function() PakettiWavHookProbeRegister() end}
