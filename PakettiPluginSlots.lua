-- PakettiPluginSlots.lua
-- 5 configurable instrument-plugin show/hide slots — the same add/show/hide logic as XO,
-- but user-configurable via a dialog.  Each slot stores a plugin path + display name in
-- preferences.  The keybinding for each slot:
--   • If the plugin is already loaded somewhere → toggle external_editor_visible
--   • If not loaded → load it (new instrument) and show the external editor

local plugin_slots_dialog = nil

-- ─── helpers ────────────────────────────────────────────────────────────────

local function plugin_type_prefix(path)
  local p = path:lower()
  if     p:find("/au/")     then return "AU"
  elseif p:find("/vst3/")   then return "VST3"
  elseif p:find("/vst/")    then return "VST"
  elseif p:find("/ladspa/") then return "LADSPA"
  elseif p:find("/dssi/")   then return "DSSI"
  else                           return "Unknown"
  end
end

-- Returns a sorted list of {display, path} for every available instrument plugin.
-- Must only be called from within a function (not at module load time).
local function build_plugin_list()
  local instrument = renoise.song().selected_instrument
  if not instrument or not instrument.plugin_properties then return {} end
  local infos = instrument.plugin_properties.available_plugin_infos
  if not infos or #infos == 0 then return {} end

  local buckets = { AU={}, VST3={}, VST={}, LADSPA={}, DSSI={} }
  local order   = { "AU", "VST3", "VST", "LADSPA", "DSSI" }

  for _, info in ipairs(infos) do
    local ptype   = plugin_type_prefix(info.path)
    local display = ptype .. ": " .. (info.name or "Unknown")
    local bucket  = buckets[ptype]
    if bucket then
      table.insert(bucket, { display = display, path = info.path })
    end
  end

  local sorter = function(a, b) return a.display < b.display end
  local result = {}
  for _, ptype in ipairs(order) do
    table.sort(buckets[ptype], sorter)
    for _, e in ipairs(buckets[ptype]) do
      table.insert(result, e)
    end
  end
  return result
end

-- ─── core toggle logic ───────────────────────────────────────────────────────

function pakettiPluginSlotToggle(slot_num)
  local prefs     = preferences.PluginSlots
  local slot_key  = string.format("Slot%02d",     slot_num)
  local name_key  = string.format("Slot%02dName", slot_num)

  local plugin_path = prefs[slot_key].value
  local plugin_name = prefs[name_key].value

  if plugin_path == "" or plugin_name == "" then
    renoise.app():show_status(string.format(
      "Plugin Slot %d: not configured — open 'Configure Plugin Slots' to assign a plugin.",
      slot_num))
    return
  end

  -- Search all instruments for an already-loaded instance of this plugin
  for i = 1, #renoise.song().instruments do
    local pd = renoise.song().instruments[i].plugin_properties.plugin_device
    if pd ~= nil and pd.name == plugin_name then
      if not pd.external_editor_available then
        renoise.app():show_status(string.format(
          "Plugin Slot %d: %s has no external editor.", slot_num, plugin_name))
        return
      end
      pd.external_editor_visible = not pd.external_editor_visible
      local state = pd.external_editor_visible and "shown" or "hidden"
      renoise.app():show_status(string.format(
        "Plugin Slot %d: %s %s.", slot_num, plugin_name, state))
      return
    end
  end

  -- Not loaded yet — load it (loadPlugin opens the editor automatically)
  loadPlugin(plugin_path)

  -- Confirm and re-show in case loadPlugin needed a moment
  for i = 1, #renoise.song().instruments do
    local pd = renoise.song().instruments[i].plugin_properties.plugin_device
    if pd ~= nil and pd.name == plugin_name then
      if pd.external_editor_available then
        pd.external_editor_visible = true
      end
      renoise.app():show_status(string.format(
        "Plugin Slot %d: loaded and showing %s.", slot_num, plugin_name))
      return
    end
  end

  renoise.app():show_status(string.format(
    "Plugin Slot %d: '%s' loaded but display name did not match — check plugin availability.",
    slot_num, plugin_name))
end

-- ─── configuration dialog ────────────────────────────────────────────────────

function pakettiPluginSlotsDialog()
  if plugin_slots_dialog and plugin_slots_dialog.visible then
    plugin_slots_dialog:close()
    plugin_slots_dialog = nil
    return
  end

  local vb    = renoise.ViewBuilder()
  local prefs = preferences.PluginSlots

  -- Build the plugin list fresh each time the dialog opens
  local plugin_infos   = build_plugin_list()
  local dropdown_items = { "<None>" }
  for _, entry in ipairs(plugin_infos) do
    table.insert(dropdown_items, entry.display)
  end

  -- Return the dropdown index for the currently saved slot name
  local function current_index_for(slot_num)
    local name_key    = string.format("Slot%02dName", slot_num)
    local stored_name = prefs[name_key].value
    if stored_name == "" then return 1 end
    for i, item in ipairs(dropdown_items) do
      if item == stored_name then return i end
    end
    return 1  -- stored plugin no longer in list → fall back to <None>
  end

  -- Build one slot row
  local function make_slot_row(slot_num)
    local slot_key = string.format("Slot%02d",     slot_num)
    local name_key = string.format("Slot%02dName", slot_num)
    return vb:row {
      spacing = 6,
      vb:text { text = string.format("Slot %d", slot_num), width = 50, font = "bold" },
      vb:popup {
        items   = dropdown_items,
        value   = current_index_for(slot_num),
        width   = 400,
        notifier = function(index)
          if index == 1 then
            prefs[slot_key].value = ""
            prefs[name_key].value = ""
          else
            local entry = plugin_infos[index - 1]
            prefs[slot_key].value = entry.path
            prefs[name_key].value = entry.display
          end
          preferences:save_as("preferences.xml")
        end,
      },
    }
  end

  local content = vb:column {
    margin  = 10,
    spacing = 6,
    vb:text  { text = "Plugin Slots — Configure Instrument Plugins", font = "bold" },
    vb:text  { text = "Assign a plugin to each slot. Use the keybinding or menu entry to load/show/hide.",
               style = "disabled" },
    vb:space { height = 4 },
    make_slot_row(1),
    make_slot_row(2),
    make_slot_row(3),
    make_slot_row(4),
    make_slot_row(5),
    vb:space { height = 4 },
    vb:button {
      text    = "Close",
      width   = 80,
      pressed = function()
        if plugin_slots_dialog and plugin_slots_dialog.visible then
          plugin_slots_dialog:close()
          plugin_slots_dialog = nil
        end
      end,
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function()    return plugin_slots_dialog end,
    function(v)   plugin_slots_dialog = v    end
  )
  plugin_slots_dialog = renoise.app():show_custom_dialog(
    "Paketti: Plugin Slots", content, keyhandler)
end

-- ─── menu entries, keybindings, MIDI mappings ────────────────────────────────

renoise.tool():add_menu_entry {
  name   = "Main Menu:Tools:Paketti:Plugins/Devices:Plugin Slots:Configure Plugin Slots...",
  invoke = function() pakettiPluginSlotsDialog() end,
}
renoise.tool():add_menu_entry {
  name   = "--Instrument Box:Paketti:Plugins/Devices:Plugin Slots:Configure Plugin Slots...",
  invoke = function() pakettiPluginSlotsDialog() end,
}
renoise.tool():add_keybinding {
  name   = "Global:Paketti:Plugin Slots:Configure Plugin Slots",
  invoke = function() pakettiPluginSlotsDialog() end,
}

for i = 1, 5 do
  local slot = i  -- capture loop variable

  renoise.tool():add_menu_entry {
    name   = string.format(
               "Main Menu:Tools:Paketti:Plugins/Devices:Plugin Slots:Toggle Slot %d", slot),
    invoke = function() pakettiPluginSlotToggle(slot) end,
  }
  renoise.tool():add_menu_entry {
    name   = string.format(
               "Instrument Box:Paketti:Plugins/Devices:Plugin Slots:Toggle Slot %d", slot),
    invoke = function() pakettiPluginSlotToggle(slot) end,
  }
  renoise.tool():add_keybinding {
    name   = string.format("Global:Paketti:Plugin Slots:Toggle Slot %d Show/Hide", slot),
    invoke = function() pakettiPluginSlotToggle(slot) end,
  }
  renoise.tool():add_midi_mapping {
    name   = string.format("Paketti:Plugin Slots:Toggle Slot %d Show/Hide", slot),
    invoke = function(message)
      if message:is_trigger() then pakettiPluginSlotToggle(slot) end
    end,
  }
end
