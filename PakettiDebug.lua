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
    (and "N dropped files = N instruments" becomes buildable). The hook stays
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
-- Additive WAV/AIFF/AIF/FLAC/MP3 import hook
--
-- Renoise owns .wav loading, so this is a live test of whether Paketti can
-- intercept a dragged .wav at all. When the "Paketti WAV Import Hook"
-- preference is on, Paketti registers sample import hooks for these formats. If Renoise
-- honours it, each dragged .wav is imported by Paketti -- one new pakettified
-- instrument per file (which is exactly "N dropped files = N instruments"). If
-- Renoise refuses the registration, we learn that and nothing changes.
--
-- Import hooks cannot be removed at runtime, so the hook stays registered for
-- the session once added; it re-reads the preference on every call, so turning
-- the preference off makes it fall back to a plain add instead of breaking .wav.
--------------------------------------------------------------------------------
local paketti_wav_hook_registered = false

-- REPORT-CARD >> features/wav-import-destination.feature
-- Remember pre-existing slots between drops, including intentionally empty ones.
-- Only a new, blank destination created by Renoise during this drop is reusable.
local paketti_wav_existing = {}
local paketti_wav_pending = {}

local function paketti_wav_finish_sample(inst, smp, cues)
  -- The host may have inserted placeholders after invoke returned. Locate the
  -- exact loaded sample rather than assuming it is still at sample index 1.
  local present = false
  for _, sample in ipairs(inst.samples) do
    if sample == smp then present = true; break end
  end
  if not present or not smp.sample_buffer.has_sample_data then return end
  for i = #inst.samples, 1, -1 do
    if inst.samples[i] ~= smp and not inst.samples[i].is_slice_alias
        and not inst.samples[i].sample_buffer.has_sample_data then
      inst:delete_sample_at(i)
    end
  end
  smp.sample_mapping.base_note = 48
  smp.sample_mapping.note_range = {0, 119}
  smp.sample_mapping.velocity_range = {0, 127}
  if cues and #cues > 1 then
    -- RIFF cue offsets are zero-based sample frames; Renoise slices are one-based.
    local positions, seen = {1}, {[1] = true}
    local frames = smp.sample_buffer.number_of_frames
    for _, cue in ipairs(cues) do
      local pos = cue.offset + 1
      if pos >= 1 and pos <= frames and pos == math.floor(pos) and not seen[pos] then
        positions[#positions + 1] = pos
        seen[pos] = true
      end
    end
    table.sort(positions)
    -- Replace any native cue interpretation to avoid duplicate/off-by-one slices.
    local old = {}
    for _, pos in ipairs(smp.slice_markers) do old[#old + 1] = pos end
    for _, pos in ipairs(old) do smp:delete_slice_marker(pos) end
    for i = 1, math.min(255, #positions) do smp:insert_slice_marker(positions[i]) end
  end
end

local function paketti_wav_remember_instruments()
  local ok, song = pcall(renoise.song)
  if not ok or not song then return end
  local pending = paketti_wav_pending
  paketti_wav_pending = {}
  for _, item in ipairs(pending) do
    -- A document switch or instrument deletion invalidates the queued target.
    if item.song == song then
      for _, inst in ipairs(song.instruments) do
        if inst == item.instrument then
          local ok_finish, err = pcall(paketti_wav_finish_sample, inst, item.sample, item.cues)
          if not ok_finish then
            print("-- Paketti WAV post-drop cleanup failed: " .. tostring(err))
            renoise.app():show_status("Paketti WAV cleanup failed: " .. tostring(err))
          end
          break
        end
      end
    end
  end
  paketti_wav_existing = {}
  for _, inst in ipairs(song.instruments) do paketti_wav_existing[inst] = true end
end
paketti_wav_remember_instruments()
renoise.tool().app_idle_observable:add_notifier(paketti_wav_remember_instruments)

local function paketti_wav_blank_destination(inst)
  if not inst or paketti_wav_existing[inst] or inst.name ~= "" then return false end
  if #inst.phrases > 0 or #inst.sample_device_chains > 0 then return false end
  if inst.plugin_properties.plugin_loaded then return false end
  if inst.midi_output_properties.device_name ~= "" then return false end
  for _, sample in ipairs(inst.samples) do
    if sample.sample_buffer.has_sample_data then return false end
  end
  return true
end


local function paketti_wav_basename(file_name)
  local n = tostring(file_name):match("[^/\\]+$") or "Sample"
  return (n:gsub("%.[^.]+$", ""))
end

--- The actual import. Returns true if Renoise should consider the file handled.
function PakettiWavImportHookInvoke(file_name)
  local on = preferences and preferences.pakettiWavImportHook
    and preferences.pakettiWavImportHook.value

  if not on then
    -- Preference off: load the file as a plain sample in the current
    -- instrument, so .wav loading is never left broken when the hook is still
    -- registered from earlier in the session.
    local ok = pcall(function()
      local song = renoise.song()
      local inst = song.selected_instrument
      local idx = #inst.samples + 1
      inst:insert_sample_at(idx)
      song.selected_sample_index = idx
      inst.samples[idx].sample_buffer:load_from(file_name)
      inst.samples[idx].name = paketti_wav_basename(file_name)
    end)
    return ok
  end

  -- Preference on: one new pakettified instrument per dragged .wav.
  local mon
  if type(rawget(_G, "PakettiTemporarilyDisableNewSampleMonitoring")) == "function" then
    mon = PakettiTemporarilyDisableNewSampleMonitoring()
  end
  local ok, err = pcall(function()
    local song = renoise.song()
    if not paketti_wav_blank_destination(song.selected_instrument) then
      local index = song.selected_instrument_index + 1
      if not safeInsertInstrumentAt(song, index) then
        error("could not insert instrument")
      end
      song.selected_instrument_index = index
    end
    paketti_wav_existing[song.selected_instrument] = true
    if type(rawget(_G, "pakettiPreferencesDefaultInstrumentLoader")) == "function" then
      pakettiPreferencesDefaultInstrumentLoader()  -- pakettify (loads the 12st template)
    end
    local inst = song.selected_instrument
    if #inst.samples == 0 then inst:insert_sample_at(1) end
    song.selected_sample_index = 1
    local smp = inst.samples[1]
    local cues
    if tostring(file_name):lower():match("%.wav$")
        and type(rawget(_G, "PakettiWavCueParseWavCues")) == "function" then
      local parsed, info = pcall(PakettiWavCueParseWavCues, file_name)
      if parsed and info and info.cues and #info.cues > 1 then cues = info.cues end
    end
    if not smp.sample_buffer:load_from(file_name) then
      error("could not load WAV sample: " .. tostring(file_name))
    end
    local name = paketti_wav_basename(file_name)
    inst.name = name
    smp.name = name

    paketti_wav_finish_sample(inst, smp)
    -- Renoise completes its sample-slot allocation and key mapping AFTER this
    -- callback. Finalize every imported destination again on the next idle.
    paketti_wav_pending[#paketti_wav_pending + 1] = {
      song = song, instrument = inst, sample = smp, cues = cues
    }

    renoise.app():show_status("Paketti WAV hook: imported '" .. name .. "' as a new instrument")
    print("-- PakettiWavImportHook: imported '" .. name .. "' from " .. tostring(file_name))
  end)
  if type(rawget(_G, "PakettiRestoreNewSampleMonitoring")) == "function" then
    PakettiRestoreNewSampleMonitoring(mon)
  end
  if not ok then
    renoise.app():show_status("Paketti WAV hook failed: " .. tostring(err))
    print("-- PakettiWavImportHook: FAILED on " .. tostring(file_name) .. ": " .. tostring(err))
    return false
  end
  return true
end

--- Register the hook if it isn't already. Returns ok, message.
function PakettiWavImportHookRegister()
  if paketti_wav_hook_registered then return true, "already registered" end
  local ok, err = pcall(function()
    for _, ext in ipairs({"wav", "aiff", "aif", "flac", "mp3"}) do
      if not renoise.tool():has_file_import_hook("sample", {ext}) then
        renoise.tool():add_file_import_hook{
          category = "sample",
          extensions = {ext},
          invoke = function(file_name) return PakettiWavImportHookInvoke(file_name) end,
        }
      end
    end
  end)
  if ok then paketti_wav_hook_registered = true end
  return ok, err
end

--- Menu/keybinding toggle: flips the preference and registers on first enable.
function PakettiToggleWavImportHook()
  local p = preferences.pakettiWavImportHook
  p.value = not p.value
  preferences:save_as("preferences.xml")
  if p.value then
    local ok, err = PakettiWavImportHookRegister()
    if ok then
      renoise.app():show_message(
        "Paketti Audio Import Hook ENABLED.\n\n"
        .. "Drag WAV, AIFF, AIF, FLAC or MP3 into Renoise. Each file "
        .. "becomes its own pakettified instrument.\n\n"
        .. "If dragging audio still behaves the way Renoise normally does, then "
        .. "Renoise did not intercept that audio format.")
    else
      p.value = false
      preferences:save_as("preferences.xml")
      renoise.app():show_message(
        "Renoise refused an audio import hook:\n\n" .. tostring(err)
        .. "\n\nPaketti cannot intercept those audio drops on this Renoise, so 'N "
        .. "dropped files = N instruments' has to be done after the fact with "
        .. "'Isolate Slices or Samples to New Instruments'.")
    end
  else
    renoise.app():show_message(
      "Paketti Audio Import Hook set to OFF.\n\n"
      .. "New audio drags load the normal way again. (The hook itself only fully "
      .. "clears when you restart Renoise, but it honours this OFF setting.)")
  end
end

-- Register at load if the preference is already on.
if preferences and preferences.pakettiWavImportHook
   and preferences.pakettiWavImportHook.value then
  local ok, err = PakettiWavImportHookRegister()
  if ok then
    print("-- Paketti WAV import hook: registered at load")
  else
    print("-- Paketti WAV import hook: registration refused -> " .. tostring(err))
  end
end

-- Primary user-facing switch: Main Menu:Options:Paketti Advanced WAV Loading.
-- ON = Paketti intercepts WAV/AIFF/AIF/FLAC/MP3 drags + Disk Browser loads (one
-- pakettified instrument per file, .wav cue headers become slices). OFF = plain
-- Renoise loading. The custom invoke registers the hook on first enable and shows
-- the explanatory message; pref= derives the strict-boolean checkmark (house rule 2).
PakettiAddMenuOptionsEntry{
  name = "Paketti Advanced WAV Loading",
  invoke = PakettiToggleWavImportHook,
  pref = preferences.pakettiWavImportHook }
PakettiAddMenuToggleEntry{
  name = "Main Menu:Tools:Paketti:Experimental:Paketti Advanced WAV Loading (WAV/AIFF/AIF/FLAC/MP3)",
  invoke = PakettiToggleWavImportHook,
  pref = preferences.pakettiWavImportHook }
renoise.tool():add_keybinding{name="Global:Paketti:Toggle WAV Import Hook",
  invoke=function() PakettiToggleWavImportHook() end}
