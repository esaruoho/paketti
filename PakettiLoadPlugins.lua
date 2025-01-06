-- Plugin Loader Dialog with Randomize Slider and Separate Dropdowns

local vb -- ViewBuilder will be initialized within the function scope
local plugins = {}
local addedEntries = {}
local current_plugin_type = "VST"
local plugin_types = { "VST", "VST3", "AU", "LADSPA", "DSSI" }
local plugin_type_display_names = {
  VST = "VST",
  VST3 = "VST3",
  AU = "AudioUnit",
  LADSPA = "LADSPA",
  DSSI = "DSSI"
}
local custom_dialog = nil  -- Reference to the custom dialog
local plugin_list_view = nil
local current_plugin_list_content = nil  -- Variable to keep track of current content

-- Variable for random selection percentage
local random_select_percentage = 0  -- Initialized to 0%


if not preferences.PakettiPluginLoaders then
  preferences.PakettiPluginLoaders = renoise.Document.DocumentList()
end



function saveToPreferences(entryName, path)
  if not entryName or not path then
    print("Error: Cannot save to preferences. entryName or path is nil.")
    return
  end

  local loaders = preferences.PakettiPluginLoaders
  local count = #loaders

  for i = 1, count do
    local plugin = loaders:property(i)
    if plugin.name.value == entryName then
      print("Plugin entry already exists. Skipping addition for:", entryName)
      return
    end
  end

  -- Add new plugin entry
  local newPlugin = create_plugin_entry(entryName, path)
  loaders:insert(#loaders + 1, newPlugin)

  print(string.format("Saved Plugin '%s' to preferences.", entryName))
end



-- Load from Preferences
function loadFromPreferences()
  if not preferences.PakettiPluginLoaders then
    print("No PakettiPluginLoaders found in preferences.")
    return
  end

  local loaders = preferences.PakettiPluginLoaders
  local count = #loaders
  for i = 1, count do
    local plugin = loaders:property(i)
    local pluginName = plugin.name.value
    local path = plugin.path.value

    -- Create KeyBinding
    local keyBindingName = "Global:Paketti:Load Plugin " .. pluginName
    renoise.tool():add_keybinding{
      name = keyBindingName,
      invoke = function() loadPlugin(path) end
    }

    -- Create MIDIMapping
    local midiMappingName = "Paketti:Load Plugin " .. pluginName
    renoise.tool():add_midi_mapping{
      name = midiMappingName,
      invoke = function(message)
        if message:is_trigger() then
          loadPlugin(path)
        end
      end
    }

    addedEntries[pluginName] = true
  end
end


-- Load Plugin Function
function loadPlugin(pluginPath)
  local selected_index = renoise.song().selected_instrument_index
  local currentView = renoise.app().window.active_middle_frame
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index = selected_index + 1

  if currentView == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then 
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  else
    renoise.app().window.active_middle_frame = currentView
  end

  local new_instrument = renoise.song().selected_instrument
  new_instrument.plugin_properties:load_plugin(pluginPath)
  if new_instrument.plugin_properties.plugin_device and new_instrument.plugin_properties.plugin_device.external_editor_available then
    new_instrument.plugin_properties.plugin_device.external_editor_visible = true
  end
  -- openVisiblePagesToFitParameters()  -- Uncomment if you have this function defined elsewhere
end

-- Check if any plugins are selected
local function isAnyPluginSelected()
  for _, cb_info in ipairs(plugins) do
    if cb_info.checkbox.value then
      return true
    end
  end
  return false
end

-- Load Selected Plugins
local function loadSelectedPlugins()
  if not isAnyPluginSelected() then
    renoise.app():show_status("Nothing was selected, doing nothing.")
    return false  -- Indicate that no plugins were loaded
  end

  for _, cb_info in ipairs(plugins) do
    if cb_info.checkbox.value then
      local pluginPath = cb_info.path
      print("Loading Plugin:", pluginPath)
      loadPlugin(pluginPath)
    end
  end
  return true  -- Indicate that plugins were loaded
end

-- Add as Shortcut
local function addAsShortcut()
  if not isAnyPluginSelected() then
    renoise.app():show_status("Nothing was selected, doing nothing.")
    return
  end

  for _, cb_info in ipairs(plugins) do
    if cb_info.checkbox.value then
      -- Ensure cb_info.path is not nil before using :find
      if cb_info.path then
        local plugin_type = ""
        if cb_info.path:find("/VST/") then
          plugin_type = " (VST)"
        elseif cb_info.path:find("/VST3/") then
          plugin_type = " (VST3)"
        elseif cb_info.path:find("/AU/") then
          plugin_type = " (AU)"
        elseif cb_info.path:find("/LADSPA/") then
          plugin_type = " (LADSPA)"
        elseif cb_info.path:find("/DSSI/") then
          plugin_type = " (DSSI)"
        end

        local pluginName = cb_info.name
        local entryName = pluginName .. plugin_type

        -- Ensure pluginName and entryName are not nil
        if pluginName and entryName then
          -- Check if we've already added this entry
          if not addedEntries[entryName] then
            -- Attempt to add the keybinding and midi mapping
            local success, err = pcall(function()
              renoise.tool():add_keybinding{
                name = "Global:Paketti:Load Plugin " .. entryName,
                invoke = function() loadPlugin(cb_info.path) end
              }
              renoise.tool():add_midi_mapping{
                name = "Paketti:Load Plugin " .. entryName,
                invoke = function(message)
                  if message:is_trigger() then
                    loadPlugin(cb_info.path)
                  end
                end
              }
            end)

            if success then
              addedEntries[entryName] = true
              saveToPreferences(entryName, cb_info.path)
            else
              print("Could not add entry for", cb_info.name .. plugin_type, "Error:", err)
            end
          else
            print("Entry for", cb_info.name .. plugin_type, "already added.")
          end
        else
          print("Error: Missing pluginName or entryName for plugin.")
          print("cb_info.name:", tostring(cb_info.name))
          print("cb_info.path:", tostring(cb_info.path))
        end
      else
        print("Error: cb_info.path is nil for plugin:", tostring(cb_info.name))
        -- Skip to next iteration
      end
    end
  end

  renoise.app():show_status("Plugins added. Open Settings -> Keys and MIDI Mappings to manage your shortcuts.")
end



-- Reset Selection
local function resetSelection()
  for _, cb_info in ipairs(plugins) do
    cb_info.checkbox.value = false
  end
end

-- Update Random Selection based on Slider
local function updateRandomSelection()
  if #plugins == 0 then
    renoise.app():show_status("Nothing to randomize from.")
    return
  end

  resetSelection()  -- Clear previous selections

  local numDevices = #plugins
  local percentage = random_select_percentage
  local numSelections = math.floor((percentage / 100) * numDevices + 0.5)

  local percentage_text_view = vb.views["random_percentage_text"]

  if numSelections == 0 then
    percentage_text_view.text = "None"
    return
  elseif numSelections >= numDevices then
    percentage_text_view.text = "All"
    for _, cb_info in ipairs(plugins) do
      cb_info.checkbox.value = true
    end
    return
  else
    percentage_text_view.text = tostring(math.floor(percentage + 0.5)) .. "%"
  end

  local indices = {}
  for i = 1, numDevices do
    indices[i] = i
  end

  -- Shuffle indices
  for i = numDevices, 2, -1 do
    local j = math.random(1, i)
    indices[i], indices[j] = indices[j], indices[i]
  end

  -- Select the first numSelections devices
  for i = 1, numSelections do
    local idx = indices[i]
    plugins[idx].checkbox.value = true
  end
end

-- Create Plugin List
local function createPluginList(plugins_list, title)
  if #plugins_list == 0 then
    return vb:column{
      vb:text{text=title, font="bold", height=20},
      vb:text{text="No Plugins found for this type.", font="italic", height=20}
    }
  end

  -- Sort the plugins alphabetically, case-insensitive
  table.sort(plugins_list, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  -- Determine number of columns based on plugins per column
  local num_plugins = #plugins_list
  local plugins_per_column = 28
  local num_columns = math.ceil(num_plugins / plugins_per_column)

  local columns = {}
  for i = 1, num_columns do
    columns[i] = vb:column{spacing=2}
  end

  -- Split plugins into columns sequentially
  local plugin_index = 1

  for col = 1, num_columns do
    for row = 1, plugins_per_column do
      if plugin_index > num_plugins then break end
      local plugin = plugins_list[plugin_index]
      local checkbox_id = "checkbox_" .. title .. "_" .. tostring(plugin_index) .. "_" .. tostring(math.random(1000000))
      local checkbox = vb:checkbox{value=false, id=checkbox_id}
      plugins[#plugins + 1] = {checkbox=checkbox, path=plugin.path, name=plugin.name}
      local plugin_row = vb:row{
        spacing=4,
        checkbox,
        vb:text{text=plugin.name}
      }
      columns[col]:add_child(plugin_row)
      plugin_index = plugin_index + 1
    end
  end

  local column_container = vb:row{spacing=20}
  for _, column in ipairs(columns) do
    column_container:add_child(column)
  end

  return vb:column{
    vb:text{text=title, font="bold", height=20},
    vb:horizontal_aligner{
      mode = "center",
      column_container
    }
  }
end

-- Update Plugin List
local function updatePluginList()
  plugins = {}  -- Clear previous checkboxes

  local available_plugins = renoise.song().selected_instrument.plugin_properties.available_plugins
  local available_plugin_infos = renoise.song().selected_instrument.plugin_properties.available_plugin_infos

  local plugin_list = {}

  for i, plugin_path in ipairs(available_plugins) do
    local plugin_info = available_plugin_infos[i]
    if plugin_info then
      local short_name = plugin_info.short_name or "Unknown"
      if plugin_path:find("/" .. current_plugin_type .. "/") then
        table.insert(plugin_list, {name = short_name, path = plugin_path})
      end
    end
  end

  local display_title = plugin_type_display_names[current_plugin_type] .. " Plugins"
  local plugin_list_content = createPluginList(plugin_list, display_title)

  -- Remove existing content from plugin_list_view
  if current_plugin_list_content then
    plugin_list_view:remove_child(current_plugin_list_content)
  end

  -- Add new content
  plugin_list_view:add_child(plugin_list_content)
  current_plugin_list_content = plugin_list_content
end

-- Show Plugin List Dialog
function showPluginListDialog()
  -- Close the dialog if it's already open
  if custom_dialog and custom_dialog.visible then
    custom_dialog:close()
    custom_dialog = nil
    current_plugin_list_content = nil  -- Reset current content
    return
  end

  vb = renoise.ViewBuilder()
  plugins = {}
  random_select_percentage = 0  -- Reset the random selection percentage
  current_plugin_list_content = nil  -- Reset current content

  -- Dropdown Menu
  local dropdown_items = {}
  for _, plugin_type in ipairs(plugin_types) do
    table.insert(dropdown_items, plugin_type_display_names[plugin_type])
  end

  local dropdown = vb:popup{
    items = dropdown_items,
    value = 1,
    notifier = function(index)
      current_plugin_type = plugin_types[index]
      updatePluginList()
    end
  }

  -- Random Selection Slider
  local random_selection_controls = vb:row{
    spacing = 10,
    vb:text{text = "Random Select:", width = 100},
    vb:slider{
      id = "random_select_slider",
      min = 0,
      max = 100,
      value = 0,
      width = 200,
      notifier = function(value)
        random_select_percentage = value
        updateRandomSelection()
      end
    },
    vb:text{
      id = "random_percentage_text",
      text = "None",
      width = 40,
      align = "center"
    }
  }

  -- Action Buttons
  local button_height = renoise.ViewBuilder.DEFAULT_DIALOG_BUTTON_HEIGHT
  local action_buttons = vb:column{
    uniform = true,
    width = "100%",
    vb:button{
      text = "Add Plugin(s) as Shortcut(s) & MIDI Mappings",
      height = button_height,
      width = "100%",
      notifier = addAsShortcut
    },
    vb:horizontal_aligner{
      width = "100%",
      vb:button{
        text = "Select All",
        height = button_height,
        width = "50%",
        notifier = function()
          for _, cb_info in ipairs(plugins) do
            cb_info.checkbox.value = true
          end
          vb.views["random_select_slider"].value = 100
          vb.views["random_percentage_text"].text = "All"
        end
      },
      vb:button{
        text = "Reset Selection",
        height = button_height,
        width = "50%",
        notifier = function()
          resetSelection()
          vb.views["random_select_slider"].value = 0
          vb.views["random_percentage_text"].text = "None"
        end
      }
    },
    vb:horizontal_aligner{
      width = "100%",
      vb:button{
        text = "Load Plugin(s)",
        width = "33%",
        height = button_height,
        notifier = function()
          if loadSelectedPlugins() then
            renoise.app():show_status("Plugins loaded.")
          else
            renoise.app():show_status("Nothing was selected, doing nothing.")
          end
        end
      },
      vb:button{
        text = "Load Plugin(s) & Close",
        width = "33%",
        height = button_height,
        notifier = function()
          if loadSelectedPlugins() then
            custom_dialog:close()
            custom_dialog = nil
            current_plugin_list_content = nil
          else
            renoise.app():show_status("Nothing was selected, doing nothing.")
          end
        end
      },
      vb:button{
        text = "Cancel",
        height = button_height,
        width = "34%",
        notifier = function()
          custom_dialog:close()
          custom_dialog = nil
          current_plugin_list_content = nil
        end
      }
    }
  }

  -- Placeholder for Plugin List
  plugin_list_view = vb:column{}

  -- Main Dialog Content
  local dialog_content_view = vb:column{
    margin = 10,
    spacing = 5,
    plugin_list_view,
    random_selection_controls,
    action_buttons
  }

  -- Wrap in a column to include the dropdown
  local dialog_content = vb:column{
    vb:horizontal_aligner{
      mode = "center",
      vb:text{text = "Select Plugin Type: "},
      dropdown
    },
    dialog_content_view
  }

  custom_dialog = renoise.app():show_custom_dialog("Load Plugin(s)", dialog_content, my_pluginLoaderkeyhandlerfunc)

  -- Initial Update
  updatePluginList()
end

function my_pluginLoaderkeyhandlerfunc(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    custom_dialog:close()
    custom_dialog = nil
    current_plugin_list_content = nil  -- Reset current content
    return nil
  else
    return key
  end
end

-- Initialize preferences file and load keybindings and MIDI mappings
loadFromPreferences()

-- Register the menu entry to show the plugin list dialog
renoise.tool():add_menu_entry{
  name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Load Plugins...",
  invoke=function() showPluginListDialog() end
}
