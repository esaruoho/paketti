-- PakettiDynamicMacroToolbar.lua
-- A configurable 10-button toolbar with preset save/load, edit mode, dynamic mode, and MIDI mappings.

local vb = renoise.ViewBuilder()
local dialog = nil
local NUM_SLOTS = 10
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 24

-- Edit mode state
local edit_mode = false

-- All available actions: combined from Dialog of Dialogs + menu/keybinding actions
local all_action_names = {}   -- sorted list of display names
local all_action_map = {}     -- display_name -> {type="dialog"|"menu"|"keybinding", func_name=string}

-- Cache for the action list (built once per session)
local actions_built = false

-- Preset directory
local separator = package.config:sub(1,1)
local PRESET_DIR = renoise.tool().bundle_path .. "DynamicMacroToolbar_Presets" .. separator

------------------------------------------------------------------------
-- Action Registry: Build a combined list of all callable actions
------------------------------------------------------------------------
local function build_action_list()
  if actions_built then return end

  all_action_names = {}
  all_action_map = {}

  -- 1) Dialog entries from create_button_list (if available)
  if type(create_button_list) == "function" then
    local ok, buttons = pcall(create_button_list)
    if ok and buttons then
      for _, entry in ipairs(buttons) do
        local display = entry[1]
        local func_ref = entry[2]
        if display and func_ref then
          local key = "[Dialog] " .. display
          all_action_map[key] = {type = "dialog", func_name = func_ref, display = display}
          table.insert(all_action_names, key)
        end
      end
    end
  end

  -- 2) Menu entries registered by the tool
  local menu_entries = renoise.tool().menu_entries
  if menu_entries then
    for _, entry in ipairs(menu_entries) do
      local name = entry.name
      if name and name:find("Paketti") then
        local short = name:gsub("^Main Menu:Tools:", ""):gsub("^Main Menu:File:", ""):gsub("^Main Menu:", "")
        local key = "[Menu] " .. short
        if not all_action_map[key] then
          all_action_map[key] = {type = "menu", menu_name = name, display = short}
          table.insert(all_action_names, key)
        end
      end
    end
  end

  -- 3) Keybinding entries registered by the tool
  local keybindings = renoise.tool().keybindings
  if keybindings then
    for _, entry in ipairs(keybindings) do
      local name = entry.name
      if name and name:find("Paketti") then
        local key = "[Key] " .. name
        if not all_action_map[key] then
          all_action_map[key] = {type = "keybinding", kb_name = name, display = name}
          table.insert(all_action_names, key)
        end
      end
    end
  end

  table.sort(all_action_names)
  actions_built = true
end

------------------------------------------------------------------------
-- Execute an action by its stored key
------------------------------------------------------------------------
local function execute_action(action_key)
  if not action_key or action_key == "" then
    renoise.app():show_status("Dynamic Macro Toolbar: Empty slot")
    return
  end

  local entry = all_action_map[action_key]
  if not entry then
    renoise.app():show_status("Dynamic Macro Toolbar: Action not found - " .. action_key)
    return
  end

  if entry.type == "dialog" then
    local func_ref = entry.func_name
    if type(func_ref) == "function" then
      local ok, err = pcall(func_ref)
      if not ok then renoise.app():show_status("Error: " .. tostring(err)) end
    elseif type(func_ref) == "string" then
      local fn = _G[func_ref]
      if type(fn) == "function" then
        local ok, err = pcall(fn)
        if not ok then renoise.app():show_status("Error: " .. tostring(err)) end
      else
        renoise.app():show_status("Function not found: " .. func_ref)
      end
    end
  elseif entry.type == "menu" then
    -- Invoke via menu entry
    local menu_entries = renoise.tool().menu_entries
    if menu_entries then
      for _, me in ipairs(menu_entries) do
        if me.name == entry.menu_name then
          local ok, err = pcall(me.invoke)
          if not ok then renoise.app():show_status("Error: " .. tostring(err)) end
          return
        end
      end
    end
    renoise.app():show_status("Menu entry not found: " .. entry.menu_name)
  elseif entry.type == "keybinding" then
    -- Invoke keybinding
    local keybindings = renoise.tool().keybindings
    if keybindings then
      for _, kb in ipairs(keybindings) do
        if kb.name == entry.kb_name then
          local ok, err = pcall(kb.invoke, false)
          if not ok then renoise.app():show_status("Error: " .. tostring(err)) end
          return
        end
      end
    end
    renoise.app():show_status("Keybinding not found: " .. entry.kb_name)
  end
end

------------------------------------------------------------------------
-- Preference helpers: read/write slot assignments
------------------------------------------------------------------------
local function get_slot_pref_key(slot_index)
  return "PakettiDMTSlot" .. string.format("%02d", slot_index)
end

local function get_slot_value(slot_index)
  local key = get_slot_pref_key(slot_index)
  if preferences[key] then
    return preferences[key].value
  end
  return ""
end

local function set_slot_value(slot_index, value)
  local key = get_slot_pref_key(slot_index)
  if preferences[key] then
    preferences[key].value = value
    preferences:save_as("preferences.xml")
  end
end

------------------------------------------------------------------------
-- Preset management
------------------------------------------------------------------------
local function ensure_preset_dir()
  if not io.exists(PRESET_DIR) then
    os.execute('mkdir "' .. PRESET_DIR .. '"')
  end
end

local function list_presets()
  ensure_preset_dir()
  local presets = {}
  -- Read directory for .txt files
  local handle
  if os.platform() == "WINDOWS" then
    handle = io.popen('dir /b "' .. PRESET_DIR .. '*.txt" 2>nul')
  else
    handle = io.popen('ls "' .. PRESET_DIR .. '"*.txt 2>/dev/null')
  end
  if handle then
    for line in handle:lines() do
      local name = line:match("(.+)%.txt$")
      if name then
        table.insert(presets, name)
      end
    end
    handle:close()
  end
  table.sort(presets)
  return presets
end

local function save_preset(name)
  ensure_preset_dir()
  local path = PRESET_DIR .. name .. ".txt"
  local f = io.open(path, "w")
  if not f then
    renoise.app():show_warning("Could not save preset to: " .. path)
    return false
  end
  for i = 1, NUM_SLOTS do
    f:write(get_slot_value(i) .. "\n")
  end
  f:close()
  renoise.app():show_status("Preset saved: " .. name)
  return true
end

local function load_preset(name)
  local path = PRESET_DIR .. name .. ".txt"
  local f = io.open(path, "r")
  if not f then
    renoise.app():show_warning("Could not load preset: " .. path)
    return false
  end
  local i = 1
  for line in f:lines() do
    if i <= NUM_SLOTS then
      set_slot_value(i, line)
      i = i + 1
    end
  end
  f:close()
  -- Clear remaining slots if preset has fewer lines
  while i <= NUM_SLOTS do
    set_slot_value(i, "")
    i = i + 1
  end
  renoise.app():show_status("Preset loaded: " .. name)
  return true
end

local function delete_preset(name)
  local path = PRESET_DIR .. name .. ".txt"
  if io.exists(path) then
    os.remove(path)
    renoise.app():show_status("Preset deleted: " .. name)
    return true
  end
  return false
end

------------------------------------------------------------------------
-- Fuzzy match helper
------------------------------------------------------------------------
local function fuzzy_match(query, text)
  if not query or query == "" then return true end
  local q = query:lower()
  local t = text:lower()
  -- Simple substring match
  return t:find(q, 1, true) ~= nil
end

------------------------------------------------------------------------
-- Get short display name for a slot
------------------------------------------------------------------------
local function get_slot_display(slot_index)
  local val = get_slot_value(slot_index)
  if not val or val == "" then
    return "Slot " .. slot_index .. " (empty)"
  end
  -- Strip prefix for display
  local display = val:gsub("^%[Dialog%] ", ""):gsub("^%[Menu%] ", ""):gsub("^%[Key%] ", "")
  -- Truncate if too long
  if #display > 18 then
    display = display:sub(1, 16) .. ".."
  end
  return display
end

------------------------------------------------------------------------
-- Build the dialog content
------------------------------------------------------------------------
local function build_toolbar_content()
  vb = renoise.ViewBuilder()
  build_action_list()

  -- Create button IDs
  local button_ids = {}
  local search_ids = {}
  local popup_ids = {}
  local row_ids = {}
  for i = 1, NUM_SLOTS do
    button_ids[i] = "dmt_btn_" .. i
    search_ids[i] = "dmt_search_" .. i
    popup_ids[i] = "dmt_popup_" .. i
    row_ids[i] = "dmt_editrow_" .. i
  end

  -- Build filtered popup items for each slot
  local function build_popup_items()
    local items = {"(clear slot)"}
    for _, name in ipairs(all_action_names) do
      table.insert(items, name)
    end
    return items
  end

  local popup_items = build_popup_items()

  -- Find popup index for a given value
  local function find_popup_index(val)
    if not val or val == "" then return 1 end
    for idx, item in ipairs(popup_items) do
      if item == val then return idx end
    end
    return 1
  end

  -- Create rows of 5 buttons each (2 rows x 5 = 10 slots)
  local rows = {}
  for row = 1, 2 do
    local row_elements = {}
    for col = 1, 5 do
      local slot = (row - 1) * 5 + col
      local current_val = get_slot_value(slot)

      -- Main action button
      table.insert(row_elements, vb:button{
        id = button_ids[slot],
        text = get_slot_display(slot),
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT,
        pressed = function()
          if edit_mode then
            -- In edit mode, clicking a button does nothing special
            return
          end
          execute_action(get_slot_value(slot))
        end
      })
    end
    table.insert(rows, vb:row{spacing = 2, unpack(row_elements)})

    -- Edit row (hidden by default)
    local edit_elements = {}
    for col = 1, 5 do
      local slot = (row - 1) * 5 + col

      table.insert(edit_elements, vb:column{
        id = row_ids[slot],
        visible = false,
        width = BUTTON_WIDTH,
        vb:popup{
          id = popup_ids[slot],
          items = popup_items,
          value = find_popup_index(get_slot_value(slot)),
          width = BUTTON_WIDTH,
          notifier = function(idx)
            if idx == 1 then
              set_slot_value(slot, "")
            else
              set_slot_value(slot, popup_items[idx])
            end
            -- Update button text
            if vb.views[button_ids[slot]] then
              vb.views[button_ids[slot]].text = get_slot_display(slot)
            end
          end
        }
      })
    end
    table.insert(rows, vb:row{spacing = 2, unpack(edit_elements)})
  end

  -- Edit mode toggle
  local edit_toggle = vb:row{
    spacing = 4,
    vb:checkbox{
      id = "dmt_edit_toggle",
      value = edit_mode,
      notifier = function(val)
        edit_mode = val
        -- Show/hide edit rows
        for i = 1, NUM_SLOTS do
          if vb.views[row_ids[i]] then
            vb.views[row_ids[i]].visible = val
          end
          -- Refresh popups when entering edit mode
          if val and vb.views[popup_ids[i]] then
            vb.views[popup_ids[i]].value = find_popup_index(get_slot_value(i))
          end
        end
      end
    },
    vb:text{text = "Edit Mode", font = "bold"}
  }

  -- Preset controls
  local preset_row = vb:row{
    spacing = 4,
    vb:button{
      text = "Save As...",
      width = 70,
      pressed = function()
        local name = ""
        -- Simple prompt using Renoise prompt
        local result = renoise.app():prompt_for_filename_to_write("txt", "Save Dynamic Macro Toolbar Preset")
        if result and result ~= "" then
          -- Extract just the filename without path and extension
          local fname = result:match("([^/\\]+)$") or result
          fname = fname:gsub("%.txt$", "")
          if fname ~= "" then
            -- Actually save to our preset dir, not the prompted path
            save_preset(fname)
            -- Refresh dialog to show new preset
            if dialog and dialog.visible then
              PakettiDynamicMacroToolbarToggle()
              PakettiDynamicMacroToolbarToggle()
            end
          end
        end
      end
    },
    vb:button{
      text = "Load...",
      width = 60,
      pressed = function()
        local presets = list_presets()
        if #presets == 0 then
          renoise.app():show_status("No presets found in " .. PRESET_DIR)
          return
        end
        local choice = renoise.app():show_prompt("Load Preset",
          "Choose a preset to load:",
          presets)
        if choice and choice ~= "" then
          -- Find which preset was chosen
          for _, p in ipairs(presets) do
            if p == choice then
              load_preset(p)
              -- Refresh dialog
              if dialog and dialog.visible then
                PakettiDynamicMacroToolbarToggle()
                PakettiDynamicMacroToolbarToggle()
              end
              return
            end
          end
        end
      end
    },
    vb:button{
      text = "Delete...",
      width = 60,
      pressed = function()
        local presets = list_presets()
        if #presets == 0 then
          renoise.app():show_status("No presets found")
          return
        end
        local choice = renoise.app():show_prompt("Delete Preset",
          "Choose a preset to delete:",
          presets)
        if choice and choice ~= "" then
          for _, p in ipairs(presets) do
            if p == choice then
              local confirm = renoise.app():show_prompt("Confirm Delete",
                "Delete preset '" .. p .. "'?",
                {"Yes", "No"})
              if confirm == "Yes" then
                delete_preset(p)
              end
              return
            end
          end
        end
      end
    }
  }

  local content = vb:column{
    margin = 4,
    spacing = 2,
    vb:row{
      spacing = 8,
      edit_toggle,
      preset_row
    },
    vb:space{height = 2},
    unpack(rows)
  }

  return content
end

------------------------------------------------------------------------
-- Toggle dialog
------------------------------------------------------------------------
function PakettiDynamicMacroToolbarToggle()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  edit_mode = false
  local content = build_toolbar_content()

  local function keyhandler(dlg, key)
    if key.modifiers == "" and key.name == preferences.pakettiDialogClose.value then
      dlg:close()
      dialog = nil
      return nil
    end
    return key
  end

  dialog = renoise.app():show_custom_dialog("Paketti Dynamic Macro Toolbar", content, keyhandler)
end

------------------------------------------------------------------------
-- MIDI mapping: trigger individual slots
------------------------------------------------------------------------
for slot = 1, NUM_SLOTS do
  renoise.tool():add_midi_mapping{
    name = "Paketti:Dynamic Macro Toolbar:Trigger Slot " .. string.format("%02d", slot),
    invoke = function(message)
      if message:is_trigger() then
        build_action_list()
        execute_action(get_slot_value(slot))
      end
    end
  }
end

------------------------------------------------------------------------
-- Menu entries, keybindings
------------------------------------------------------------------------
renoise.tool():add_keybinding{
  name = "Global:Paketti:Dynamic Macro Toolbar Toggle",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

renoise.tool():add_menu_entry{
  name = "--Pattern Editor:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

renoise.tool():add_menu_entry{
  name = "Mixer:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}
