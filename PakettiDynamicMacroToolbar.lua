-- PakettiDynamicMacroToolbar.lua
-- A configurable 10-button toolbar with preset save/load, edit mode, dynamic mode, and MIDI mappings.

local vb = renoise.ViewBuilder()
local dialog = nil
local NUM_SLOTS = 10
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 24

-- Edit mode state
local edit_mode = false
local current_preset_name = nil

-- All available actions: combined from Dialog of Dialogs + menu/keybinding actions
local all_action_names = {}   -- sorted list of display names
local all_action_map = {}     -- display_name -> {type="dialog"|"menu"|"keybinding", func_name=string}

-- Cache for the action list (built once per session)
local actions_built = false

-- Preset directory
local separator = package.config:sub(1,1)
local PRIMARY_PRESET_DIR = renoise.tool().bundle_path .. "DynamicMacro" .. separator
local LEGACY_PRESET_DIR = renoise.tool().bundle_path .. "DynamicMacroToolbar_Presets" .. separator

-- Optional additional folder the user can point at.
-- Presets here are scanned in addition to the bundle's DynamicMacro folder,
-- and when set it becomes the SAVE target (see save_preset).
--
-- Persistence: preferences.xml lives inside the tool bundle, so installing a
-- new Paketti wipes it along with the rest of the bundle. To make the custom
-- path survive a reinstall we also mirror it into a sidecar file kept in the
-- parent "Tools" directory, which is NOT touched when a single tool is
-- replaced. On load we self-heal the preference from the sidecar if it was
-- reset. The sidecar is only a pointer (a path string); the user's actual
-- preset .txt files live in the folder that path points at.
local DMT_PATH_SIDECAR
do
  -- bundle_path = ".../Tools/org.lackluster.Paketti.xrnx/"  (trailing separator)
  local bp = renoise.tool().bundle_path
  local tools_dir = bp:match("^(.*[/\\])[^/\\]+[/\\]$") or bp
  DMT_PATH_SIDECAR = tools_dir .. "PakettiDMTCustomPresetPath.cfg"
end

local function read_sidecar_path()
  if not io.exists(DMT_PATH_SIDECAR) then return "" end
  local f = io.open(DMT_PATH_SIDECAR, "r")
  if not f then return "" end
  local line = f:read("*l") or ""
  f:close()
  return line
end

local function write_sidecar_path(path)
  local f = io.open(DMT_PATH_SIDECAR, "w")
  if not f then return false end
  f:write((path or "") .. "\n")
  f:close()
  return true
end

local function get_custom_preset_dir()
  local p = ""
  if preferences.PakettiDMTCustomPresetPath then
    p = preferences.PakettiDMTCustomPresetPath.value or ""
  end
  -- Self-heal: after a reinstall the in-bundle preference is gone but the
  -- out-of-bundle sidecar remains. Restore it so the user's folder reappears.
  if p == "" then
    local recovered = read_sidecar_path()
    if recovered ~= "" then
      p = recovered
      if preferences.PakettiDMTCustomPresetPath then
        preferences.PakettiDMTCustomPresetPath.value = recovered
        preferences:save_as("preferences.xml")
      end
    end
  end
  if p == "" then return "" end
  -- Ensure trailing separator so we can concatenate filenames safely.
  if p:sub(-1) ~= "/" and p:sub(-1) ~= "\\" then
    p = p .. separator
  end
  return p
end

local function set_custom_preset_dir(path)
  path = path or ""
  if preferences.PakettiDMTCustomPresetPath then
    preferences.PakettiDMTCustomPresetPath.value = path
    preferences:save_as("preferences.xml")
  end
  -- Mirror out-of-bundle so a Paketti reinstall cannot lose the pointer.
  write_sidecar_path(path)
end

------------------------------------------------------------------------
-- Action Registry: Build a combined list of all callable actions
-- Uses create_button_list() from PakettiMainMenuEntries.lua (global function)
------------------------------------------------------------------------
local function build_action_list()
  if actions_built then return end

  all_action_names = {}
  all_action_map = {}

  -- Get dialog entries from the global create_button_list function
  if type(create_button_list) == "function" then
    local ok, buttons = pcall(create_button_list)
    if ok and buttons then
      for _, entry in ipairs(buttons) do
        local display = entry[1]
        local func_ref = entry[2]
        if display and func_ref then
          all_action_map[display] = {type = "dialog", func_name = func_ref, display = display}
          table.insert(all_action_names, display)
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
  -- FEATURE-CARD >> features/dynamic-toolbar-actions.feature
  if not action_key or action_key == "" then
    renoise.app():show_status("Dynamic Macro Toolbar: Empty slot")
    return
  end

  local entry = all_action_map[action_key]
  if not entry then
    renoise.app():show_status("Dynamic Macro Toolbar: Action not found - " .. action_key)
    return
  end

  local func_ref = entry.func_name
  if type(func_ref) == "function" then
    local ok, err = pcall(func_ref)
    if not ok then renoise.app():show_status("Error: " .. tostring(err)) end
  elseif type(func_ref) == "string" then
    local fn = rawget(_G, func_ref)
    if type(fn) == "function" then
      local ok, err = pcall(fn)
      if not ok then renoise.app():show_status("Error: " .. tostring(err)) end
    else
      renoise.app():show_status("Function not found: " .. func_ref)
    end
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
local function ensure_dir(dir)
  if dir == nil or dir == "" then return false end
  if not io.exists(dir) then
    if type(os.mkdir) == "function" then
      pcall(os.mkdir, dir)
    end
    if not io.exists(dir) then
      local cmd
      if os.platform() == "WINDOWS" then
        cmd = 'mkdir "' .. dir .. '"'
      else
        cmd = 'mkdir -p "' .. dir .. '"'
      end
      os.execute(cmd)
    end
  end
  return io.exists(dir)
end

local function ensure_preset_dir()
  ensure_dir(PRIMARY_PRESET_DIR)
end

-- Where a "Save Preset" should write: the custom folder if one is set and
-- usable, otherwise the bundle's DynamicMacro folder. Returns the directory
-- (with trailing separator) that was actually prepared.
local function get_save_dir()
  local custom = get_custom_preset_dir()
  if custom ~= "" and ensure_dir(custom) then
    return custom
  end
  ensure_preset_dir()
  return PRIMARY_PRESET_DIR
end

local function preset_name_from_path(path)
  local filename = path:match("([^/\\]+)$") or path
  if not filename:lower():match("%.txt$") then return nil end
  return filename:gsub("%.[Tt][Xx][Tt]$", "")
end

local function collect_presets_from_dir(dir, source_label, presets, by_name)
  if not io.exists(dir) then return end

  local ok, files = pcall(os.filenames, dir, "*.txt")
  if not ok or not files then return end

  for _, path in ipairs(files) do
    local name = preset_name_from_path(path)
    if name and name ~= "" and not by_name[name] then
      local full_path = path
      if not full_path:find("[/\\]") then
        full_path = dir .. path
      end
      local record = {
        name = name,
        path = full_path,
        source = source_label
      }
      table.insert(presets, record)
      by_name[name] = record
    end
  end
end

local function list_preset_records()
  ensure_preset_dir()

  local presets = {}
  local by_name = {}
  collect_presets_from_dir(PRIMARY_PRESET_DIR, "DynamicMacro", presets, by_name)
  local custom_dir = get_custom_preset_dir()
  if custom_dir ~= "" then
    collect_presets_from_dir(custom_dir, "Custom", presets, by_name)
  end
  collect_presets_from_dir(LEGACY_PRESET_DIR, "Legacy", presets, by_name)

  table.sort(presets, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return presets
end

local function list_presets()
  local records = list_preset_records()
  local names = {}
  for _, record in ipairs(records) do
    table.insert(names, record.name)
  end
  return names
end

local function find_preset_record(name)
  if not name or name == "" then return nil end
  for _, record in ipairs(list_preset_records()) do
    if record.name == name then return record end
  end
  return nil
end

local function save_preset(name)
  -- Save into the custom folder when one is set, otherwise the bundle folder.
  local dir = get_save_dir()
  local path = dir .. name .. ".txt"
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
  current_preset_name = name
  return true
end

local function load_preset(name)
  local record = find_preset_record(name)
  local path = record and record.path or (PRIMARY_PRESET_DIR .. name .. ".txt")
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
  current_preset_name = name
  return true
end

local function delete_preset(name)
  local record = find_preset_record(name)
  local path = record and record.path or (PRIMARY_PRESET_DIR .. name .. ".txt")
  if io.exists(path) then
    os.remove(path)
    renoise.app():show_status("Preset deleted: " .. name)
    if current_preset_name == name then
      current_preset_name = nil
    end
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
  -- Truncate if too long
  if #val > 18 then
    return val:sub(1, 16) .. ".."
  end
  return val
end

------------------------------------------------------------------------
-- Build the dialog content
------------------------------------------------------------------------
local function build_toolbar_content()
  vb = renoise.ViewBuilder()
  build_action_list()

  -- Create button IDs
  local button_ids = {}
  local popup_ids = {}
  local row_ids = {}
  for i = 1, NUM_SLOTS do
    button_ids[i] = "dmt_btn_" .. i
    popup_ids[i] = "dmt_popup_" .. i
    row_ids[i] = "dmt_editrow_" .. i
  end

  local find_popup_index

  local function refresh_slot_buttons()
    for i = 1, NUM_SLOTS do
      if vb.views[button_ids[i]] then
        vb.views[button_ids[i]].text = get_slot_display(i)
      end
      if vb.views[popup_ids[i]] then
        vb.views[popup_ids[i]].value = find_popup_index(get_slot_value(i))
      end
    end
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
  local preset_records = list_preset_records()
  local preset_items = {"Select preset..."}
  for _, record in ipairs(preset_records) do
    table.insert(preset_items, record.name)
  end

  -- Find popup index for a given value
  find_popup_index = function(val)
    if not val or val == "" then return 1 end
    for idx, item in ipairs(popup_items) do
      if item == val then return idx end
    end
    return 1
  end

  local function find_preset_popup_index(name)
    if not name or name == "" then return 1 end
    for idx, item in ipairs(preset_items) do
      if item == name then return idx end
    end
    return 1
  end

  -- Create rows of 5 buttons each (2 rows x 5 = 10 slots)
  local rows = {}
  for row = 1, 2 do
    local row_elements = {}
    for col = 1, 5 do
      local slot = (row - 1) * 5 + col

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
            refresh_slot_buttons()
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
    vb:popup{
      id = "dmt_preset_popup",
      items = preset_items,
      value = find_preset_popup_index(current_preset_name),
      width = 180,
      notifier = function(idx)
        if idx <= 1 then return end
        local name = preset_items[idx]
        if load_preset(name) then
          refresh_slot_buttons()
        end
      end
    },
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
          fname = fname:gsub("%.[Tt][Xx][Tt]$", "")
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
          renoise.app():show_status("No presets found in " .. PRIMARY_PRESET_DIR)
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
              refresh_slot_buttons()
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
                -- Refresh dialog so the deleted preset disappears from the dropdown.
                if dialog and dialog.visible then
                  PakettiDynamicMacroToolbarToggle()
                  PakettiDynamicMacroToolbarToggle()
                end
              end
              return
            end
          end
        end
      end
    }
  }

  -- Folder controls: reveal the presets folder in Finder/Explorer and set an
  -- optional additional folder that is scanned alongside the bundle's DynamicMacro folder.
  local function custom_path_label()
    local p = get_custom_preset_dir()
    if p == "" then return "Extra Folder: (none) - presets save inside Paketti" end
    return "Extra Folder (presets save here): " .. p
  end

  local folder_row = vb:row{
    spacing = 4,
    vb:button{
      text = "Open Presets Folder",
      width = 130,
      pressed = function()
        ensure_preset_dir()
        pcall(function() renoise.app():open_path(PRIMARY_PRESET_DIR) end)
        local custom_dir = get_custom_preset_dir()
        if custom_dir ~= "" and io.exists(custom_dir) then
          pcall(function() renoise.app():open_path(custom_dir) end)
        end
        renoise.app():show_status("Dynamic Macro Toolbar: revealed presets folder - send your .txt macros to Esa!")
      end
    },
    vb:button{
      text = "Set Extra Folder...",
      width = 110,
      pressed = function()
        local chosen = renoise.app():prompt_for_path("Select additional Dynamic Macro Toolbar preset folder")
        if chosen and chosen ~= "" then
          set_custom_preset_dir(chosen)
          if vb.views["dmt_custom_path_text"] then
            vb.views["dmt_custom_path_text"].text = custom_path_label()
          end
          -- Refresh dialog so the extra folder's presets appear in the dropdown.
          if dialog and dialog.visible then
            PakettiDynamicMacroToolbarToggle()
            PakettiDynamicMacroToolbarToggle()
          end
        end
      end
    },
    vb:button{
      text = "Clear",
      width = 45,
      pressed = function()
        set_custom_preset_dir("")
        if vb.views["dmt_custom_path_text"] then
          vb.views["dmt_custom_path_text"].text = custom_path_label()
        end
        if dialog and dialog.visible then
          PakettiDynamicMacroToolbarToggle()
          PakettiDynamicMacroToolbarToggle()
        end
      end
    },
    vb:text{
      id = "dmt_custom_path_text",
      text = custom_path_label()
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
    folder_row,
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
-- Keybindings: trigger individual slots
------------------------------------------------------------------------
for slot = 1, NUM_SLOTS do
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Dynamic Macro Toolbar Trigger Slot " .. string.format("%02d", slot),
    invoke = function()
      build_action_list()
      execute_action(get_slot_value(slot))
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

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

PakettiAddMenuEntry{
  name = "--Pattern Editor:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

PakettiAddMenuEntry{
  name = "Mixer:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}

PakettiAddMenuEntry{
  name = "Sample Editor:Paketti Gadgets:Dynamic Macro Toolbar...",
  invoke = function() PakettiDynamicMacroToolbarToggle() end
}
