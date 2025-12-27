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
local dialog = nil
local plugin_list_view = nil
local current_plugin_list_content = nil  -- Variable to keep track of current content

-- Variable for random selection percentage
local random_select_percentage = 0  -- Initialized to 0%

-- CCizer integration variables
local separator = package.config:sub(1,1)
local ccizer_files = {}
local selected_ccizer_index = 1
local auto_apply_ccizer = false


if not preferences.PakettiPluginLoaders then
  preferences.PakettiPluginLoaders = renoise.Document.DocumentList()
end

-- ===== CCIZER INTEGRATION FUNCTIONS =====

-- Get path to ccizer folder
local function get_ccizer_folder()
    return renoise.tool().bundle_path .. "ccizer" .. separator
end

-- Scan for available CCizer files
local function scan_ccizer_files()
    local ccizer_path = get_ccizer_folder()
    local files = {}
    
    -- Try to get .txt files from the ccizer folder
    local success, result = pcall(function()
        return os.filenames(ccizer_path, "*.txt")
    end)
    
    if success and result then
        for _, filename in ipairs(result) do
            -- Extract just the filename without path
            local clean_name = filename:match("[^"..separator.."]+$")
            if clean_name then
                table.insert(files, {
                    name = clean_name,
                    display_name = clean_name:gsub("%.txt$", ""), -- Remove .txt extension for display
                    full_path = ccizer_path .. clean_name
                })
            end
        end
    end
    
    -- Sort files alphabetically and add "None" option at the beginning
    table.sort(files, function(a, b) return a.display_name:lower() < b.display_name:lower() end)
    table.insert(files, 1, {name = "None", display_name = "None", full_path = ""})
    
    return files
end

-- Load and parse a CCizer file (simplified from PakettiCCizerLoader.lua)
local function load_ccizer_file_for_plugin(filepath)
    if not filepath or filepath == "" then
        return nil
    end
    
    local file = io.open(filepath, "r")
    if not file then
        print("-- Plugin+CCizer: Cannot open CCizer file: " .. filepath)
        return nil
    end
    
    local mappings = {}
    local line_count = 0
    local valid_cc_count = 0
    local MAX_CC_LIMIT = 35
    
    for line in file:lines() do
        line_count = line_count + 1
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace
        
        if line and line ~= "" and not line:match("^#") then -- Skip empty lines and comments
            -- Check for Pitchbend first
            local pb_name = line:match("^PB%s+(.+)$")
            if pb_name then
                valid_cc_count = valid_cc_count + 1
                if valid_cc_count <= MAX_CC_LIMIT then
                    table.insert(mappings, {cc = -1, name = pb_name, type = "PB"})
                    print(string.format("-- Plugin+CCizer: Valid PB mapping #%d: PB -> %s", valid_cc_count, pb_name))
                end
            else
                -- Regular CC parsing
                local cc_number, parameter_name = line:match("^(%d+)%s+(.+)$")
                if cc_number and parameter_name then
                    local cc_num = tonumber(cc_number)
                    if cc_num and cc_num >= 0 and cc_num <= 127 then
                        valid_cc_count = valid_cc_count + 1
                        if valid_cc_count <= MAX_CC_LIMIT then
                            table.insert(mappings, {cc = cc_num, name = parameter_name, type = "CC"})
                            print(string.format("-- Plugin+CCizer: Valid CC mapping #%d: CC %d -> %s", valid_cc_count, cc_num, parameter_name))
                        end
                    end
                end
            end
        end
    end
    
    file:close()
    print(string.format("-- Plugin+CCizer: Loaded %d valid MIDI CC mappings from %s", #mappings, filepath))
    return mappings
end

-- Enhanced auto-detect CCizer file based on plugin name
local function auto_detect_ccizer_file(plugin_name)
  if not plugin_name then return nil end
  
  -- Normalize plugin name: remove common prefixes/suffixes and convert to lowercase
  local plugin_normalized = plugin_name:lower()
  -- Remove common plugin suffixes/prefixes
  plugin_normalized = plugin_normalized:gsub("%s*vst[23]?$", "")
  plugin_normalized = plugin_normalized:gsub("%s*au$", "")
  plugin_normalized = plugin_normalized:gsub("%s*audiounit$", "")
  plugin_normalized = plugin_normalized:gsub("^vst:?%s*", "")
  plugin_normalized = plugin_normalized:gsub("^au:?%s*", "")
  plugin_normalized = plugin_normalized:gsub("^audiounit:?%s*", "")
  plugin_normalized = plugin_normalized:match("^%s*(.-)%s*$") -- trim spaces
  
  -- Try exact matches first, then increasingly flexible partial matches
  for _, file in ipairs(ccizer_files) do
    if file.display_name ~= "None" then
      local ccizer_lower = file.display_name:lower()
      
      -- Remove common suffixes from CCizer filename
      local ccizer_normalized = ccizer_lower:gsub("macros?$", ""):gsub("controls?$", ""):gsub("ccs?$", "")
      ccizer_normalized = ccizer_normalized:match("^%s*(.-)%s*$") -- trim spaces
      
      -- 1. Exact match (normalized)
      if ccizer_normalized == plugin_normalized then
        print(string.format("-- Plugin+CCizer: Auto-detected exact match: '%s' -> '%s'", plugin_name, file.display_name))
        return file
      end
      
      -- 2. Plugin name starts with ccizer name (e.g., "Surge XT" matches "surge")
      if plugin_normalized:find("^" .. ccizer_normalized) then
        print(string.format("-- Plugin+CCizer: Auto-detected prefix match: '%s' -> '%s'", plugin_name, file.display_name))
        return file
      end
      
      -- 3. CCizer name starts with plugin name (e.g., "surgemacros" matches "Surge")
      if ccizer_normalized:find("^" .. plugin_normalized) then
        print(string.format("-- Plugin+CCizer: Auto-detected prefix match: '%s' -> '%s'", plugin_name, file.display_name))
        return file
      end
      
      -- 4. Fallback: partial match anywhere in the name
      if plugin_normalized:find(ccizer_normalized, 1, true) or ccizer_normalized:find(plugin_normalized, 1, true) then
        print(string.format("-- Plugin+CCizer: Auto-detected partial match: '%s' -> '%s'", plugin_name, file.display_name))
        return file
      end
    end
  end
  
  return nil
end

-- Apply CCizer mappings after loading plugin
local function apply_ccizer_after_plugin_load(ccizer_file, plugin_name)
    if not ccizer_file or ccizer_file.display_name == "None" then
        return
    end
    
    local mappings = load_ccizer_file_for_plugin(ccizer_file.full_path)
    if not mappings or #mappings == 0 then
        print("-- Plugin+CCizer: No valid CCizer mappings found")
        return
    end
    
    print(string.format("-- Plugin+CCizer: Applying %d CCizer mappings for plugin '%s'", #mappings, plugin_name))
    
    -- Load MIDI Control device and apply mappings (reuse function from PakettiCCizerLoader.lua)
    loadnative("Audio/Effects/Native/*Instr. MIDI Control")
    
    -- Small delay to ensure device loads
    renoise.app():show_status("Applying CCizer mappings...")
    
    -- Generate the XML preset with our CC mappings
    local xml_content = paketti_generate_midi_control_xml(mappings)
    
    -- Apply the XML to the device
    local song = renoise.song()
    local device = song.selected_device
    
    if device and device.name == "*Instr. MIDI Control" then
        device.active_preset_data = xml_content
        device.display_name = ccizer_file.display_name
        
        local status_message = string.format("Plugin '%s' loaded with CCizer '%s' (%d/%d CCs)", 
            plugin_name, ccizer_file.display_name, #mappings, 35)
        renoise.app():show_status(status_message)
        print("-- Plugin+CCizer: " .. status_message)
    else
        print("-- Plugin+CCizer: Failed to find MIDI Control device")
    end
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
    local keyBindingName="Global:Paketti:Load Plugin " .. pluginName
    renoise.tool():add_keybinding{name=keyBindingName,
      invoke=function() loadPlugin(path) end
    }

    -- Create MIDIMapping
    local midiMappingName="Paketti:Load Plugin " .. pluginName
    renoise.tool():add_midi_mapping{name=midiMappingName,invoke=function(message) if message:is_trigger() then loadPlugin(path) end end}

    addedEntries[pluginName] = true
  end
end


-- Enhanced Load Plugin Function with optional CCizer integration
function loadPlugin(pluginPath, apply_ccizer_file, plugin_display_name)
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
  
  -- Apply CCizer mappings if requested
  if apply_ccizer_file then
    apply_ccizer_after_plugin_load(apply_ccizer_file, plugin_display_name or "Unknown Plugin")
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

-- Load Selected Plugins with CCizer integration
local function loadSelectedPlugins()
  if not isAnyPluginSelected() then
    renoise.app():show_status("Nothing was selected, doing nothing.")
    return false  -- Indicate that no plugins were loaded
  end

  for _, cb_info in ipairs(plugins) do
    if cb_info.checkbox.value then
      local pluginPath = cb_info.path
      local pluginName = cb_info.name
      print("Loading Plugin:", pluginPath)
      
      -- Determine CCizer file to apply
      local ccizer_to_apply = nil
      
      if selected_ccizer_index > 1 and ccizer_files[selected_ccizer_index] then
        -- Manual override: use specifically selected CCizer file for ALL plugins
        ccizer_to_apply = ccizer_files[selected_ccizer_index]
        print(string.format("-- Plugin+CCizer: Manual override - applying %s for plugin %s", ccizer_to_apply.display_name, pluginName))
      elseif auto_apply_ccizer then
        -- Auto-apply mode: try to find matching CCizer file
        local auto_detected = auto_detect_ccizer_file(pluginName)
        if auto_detected then
          ccizer_to_apply = auto_detected
          print(string.format("-- Plugin+CCizer: Auto-detected and shooting in %s for plugin %s", auto_detected.display_name, pluginName))
        else
          print(string.format("-- Plugin+CCizer: No matching CCizer file found for plugin %s", pluginName))
        end
      end
      
      -- Load plugin with optional CCizer
      loadPlugin(pluginPath, ccizer_to_apply, pluginName)
    end
  end
  return true  -- Indicate that plugins were loaded
end

-- Enhanced Add as Shortcut with CCizer Integration
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
        
        -- Determine CCizer file for this plugin (same logic as loading)
        local ccizer_to_apply = nil
        local ccizer_suffix = ""
        
        if selected_ccizer_index > 1 and ccizer_files[selected_ccizer_index] then
          -- Manual override: use specifically selected CCizer file
          ccizer_to_apply = ccizer_files[selected_ccizer_index]
          ccizer_suffix = " + " .. ccizer_to_apply.display_name
          print(string.format("-- Plugin+CCizer Shortcut: Manual override - will apply %s for plugin %s", ccizer_to_apply.display_name, pluginName))
        elseif auto_apply_ccizer then
          -- Auto-apply mode: try to find matching CCizer file
          local auto_detected = auto_detect_ccizer_file(pluginName)
          if auto_detected then
            ccizer_to_apply = auto_detected
            ccizer_suffix = " + " .. auto_detected.display_name
            print(string.format("-- Plugin+CCizer Shortcut: Auto-detected %s for plugin %s", auto_detected.display_name, pluginName))
          end
        end
        
        -- Update entry name to include CCizer info
        local final_entry_name = entryName .. ccizer_suffix

        -- Ensure pluginName and entryName are not nil
        if pluginName and entryName then
          -- Check if we've already added this entry
          if not addedEntries[final_entry_name] then
            -- Create the shortcut function that loads plugin + CCizer
            local shortcut_function = function()
              loadPlugin(cb_info.path, ccizer_to_apply, pluginName)
            end
            
            -- Attempt to add the keybinding and midi mapping
            local success, err = pcall(function()
              renoise.tool():add_keybinding{name="Global:Paketti:Load Plugin " .. final_entry_name,
                invoke=shortcut_function
              }
              renoise.tool():add_midi_mapping{name="Paketti:Load Plugin " .. final_entry_name,
                invoke=function(message)
                  if message:is_trigger() then
                    shortcut_function()
                  end
                end
              }
            end)

            if success then
              addedEntries[final_entry_name] = true
              -- Save to preferences with CCizer info
              saveToPreferences(final_entry_name, cb_info.path)
              
              local status_msg = ccizer_to_apply and
                string.format("Added shortcut: '%s' (Plugin + CCizer)", final_entry_name) or
                string.format("Added shortcut: '%s' (Plugin only)", final_entry_name)
              print("-- Plugin+CCizer Shortcut: " .. status_msg)
            else
              print("Could not add entry for", final_entry_name, "Error:", err)
            end
          else
            print("Entry for", final_entry_name, "already added.")
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

  renoise.app():show_status("Plugin shortcuts added with CCizer integration. Check Settings -> Keys and MIDI Mappings.")
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

  -- Check if "Favorites Only" is enabled
  local favorites_only = vb.views["favorites_only_checkbox"].value

  -- Filter plugins based on the "Favorites Only" checkbox
  local filtered_plugins = {}
  for _, cb_info in ipairs(plugins) do
    if not favorites_only or (favorites_only and cb_info.is_favorite) then
      table.insert(filtered_plugins, cb_info)
    end
  end

  local numDevices = #filtered_plugins
  local percentage = random_select_percentage
  local numSelections = math.floor((percentage / 100) * numDevices + 0.5)

  local percentage_text_view = vb.views["random_percentage_text"]

  if numSelections == 0 then
    percentage_text_view.text="None"
    return
  elseif numSelections >= numDevices then
    percentage_text_view.text="All"
    for _, cb_info in ipairs(filtered_plugins) do
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
    filtered_plugins[idx].checkbox.value = true
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

      local display_name = plugin.name

      -- Debug: Print plugin info before applying styling
      print("Creating Plugin Row for:", display_name)
      print("Is Favorite:", plugin.is_favorite)

      if plugin.is_favorite then
        display_name = display_name .. "*"  -- Add * for favorites
      end

      plugins[#plugins + 1] = {
        checkbox = checkbox,
        path = plugin.path,
        name = plugin.name,
        is_favorite = plugin.is_favorite  -- Pass the is_favorite flag
      }

      local plugin_row = vb:row{
        spacing=4,
        checkbox,
        vb:text{
          text = display_name,
          font = plugin.is_favorite and "italic" or "normal",  -- Set font to italic for favorites
          style = plugin.is_favorite and "strong" or "normal"  -- Set style to strong for favorites
        }
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

      -- Normalize the path for comparison (replace backslashes with forward slashes)
      local normalized_path = plugin_path:gsub("\\", "/")

      -- Debug: Print plugin info
      print("Plugin Path:", normalized_path)
      print("Plugin Name:", short_name)
      print("Is Favorite:", plugin_info.is_favorite)

      -- Check if the plugin type matches the current selection
      if normalized_path:lower():find("/" .. current_plugin_type:lower() .. "/") then
        table.insert(plugin_list, {
          name = short_name,
          path = plugin_path,
          is_favorite = plugin_info.is_favorite  -- Pass the is_favorite flag to the plugin list
        })
      end
    end
  end

  -- Debug: Print the filtered plugin list
  print("Filtered Plugin List for", current_plugin_type)
  for _, plugin in ipairs(plugin_list) do
    print("Name:", plugin.name, "Is Favorite:", plugin.is_favorite)
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
function pakettiLoadPluginsDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    current_plugin_list_content = nil  -- Reset current content
    return
  end

  vb = renoise.ViewBuilder()
  plugins = {}
  random_select_percentage = 0  -- Reset the random selection percentage
  current_plugin_list_content = nil  -- Reset current content
  
  -- Initialize CCizer integration
  ccizer_files = scan_ccizer_files()
  selected_ccizer_index = 1  -- Default to "None"
  auto_apply_ccizer = true  -- Default to auto-apply mode

  -- Dropdown Menu
  local dropdown_items = {}
  for _, plugin_type in ipairs(plugin_types) do
    table.insert(dropdown_items, plugin_type_display_names[plugin_type])
  end

  -- Find the index of the current plugin type for proper dropdown initialization
  local current_plugin_index = 1
  for i, plugin_type in ipairs(plugin_types) do
    if plugin_type == current_plugin_type then
      current_plugin_index = i
      break
    end
  end

  local dropdown = vb:popup{
    items = dropdown_items,
    value = current_plugin_index,
    notifier=function(index)
      current_plugin_type = plugin_types[index]
      updatePluginList()
    end
  }

  -- Random Selection Slider
  local random_selection_controls = vb:row{
    spacing=10,
    vb:text{text="Random Select:",width=100},
    vb:slider{
      id = "random_select_slider",
      min = 0,
      max = 100,
      value = 0,
      width=200,
      notifier=function(value)
        random_select_percentage = value
        updateRandomSelection()
      end
    },
    vb:text{
      id = "random_percentage_text",
      text="None",
      width=40,
      align="center"
    },

    vb:checkbox{
      id = "favorites_only_checkbox",
      value = false,
      notifier=function(value)
        updateRandomSelection()
      end
    },
    vb:text{text="Favorites Only",width=70},
  
  }

  -- CCizer Integration Controls
  local ccizer_file_items = {}
  for _, file in ipairs(ccizer_files) do
    table.insert(ccizer_file_items, file.display_name)
  end
  
  local ccizer_controls = vb:column{
    spacing=5,
    vb:text{text="CCizer MIDI Mapping Integration:", style="strong", font="bold"},
    vb:row{
      spacing=10,
      vb:text{text="CCizer File:", width=100},
      vb:popup{
        id = "ccizer_popup",
        items = ccizer_file_items,
        value = selected_ccizer_index,
        width = 300,
        notifier = function(index)
          selected_ccizer_index = index
          if index > 1 then
            auto_apply_ccizer = false  -- Disable auto mode when manually selecting
            vb.views["auto_ccizer_checkbox"].value = false
          end
        end
      },
             vb:text{
         id = "ccizer_info_text",
         text = string.format("(%d CCizer files found)", math.max(0, #ccizer_files - 1)),
         font = "italic",
         width = 100
       },
       vb:button{
         text = "Browse...",
         width = 80,
         notifier = function()
           local selected_file = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Select CCizer File")
           if selected_file and selected_file ~= "" then
             local filename = selected_file:match("([^/\\]+)$")
             local display_name = filename:gsub("%.txt$", "")
             
             -- Add to ccizer_files temporarily
             local custom_file = {
               name = filename,
               display_name = display_name .. " (Custom)",
               full_path = selected_file
             }
             
             -- Add to the list and update UI
             table.insert(ccizer_files, custom_file)
             table.insert(ccizer_file_items, custom_file.display_name)
             vb.views["ccizer_popup"].items = ccizer_file_items
             vb.views["ccizer_popup"].value = #ccizer_files  -- Select the new file
             selected_ccizer_index = #ccizer_files
             auto_apply_ccizer = false
             vb.views["auto_ccizer_checkbox"].value = false
           end
         end
       }
    },
         vb:row{
       spacing=10,
       vb:checkbox{
         id = "auto_ccizer_checkbox",
         value = auto_apply_ccizer,
         notifier = function(value)
           auto_apply_ccizer = value
           if value then
             selected_ccizer_index = 1  -- Reset to "None" when enabling auto mode
             vb.views["ccizer_popup"].value = 1
           end
         end
       },
       vb:text{text="Auto-apply matching CCizer files (enabled by default)", width=400},
     },
     vb:text{
       text="Automatically shoots in matching CCizer files (e.g., 'Surge' plugin → 'surgemacros.txt'). Uncheck to disable.",
       font="italic",
       width=500
     }
  }

  -- Action Buttons
  local button_height = renoise.ViewBuilder.DEFAULT_DIALOG_BUTTON_HEIGHT
  local action_buttons = vb:column{
    uniform = true,
    width="100%",
    vb:button{
      text="Add Plugin(s) + CCizer as Shortcut(s) & MIDI Mappings",
      height = button_height,
      width="100%",
      notifier = addAsShortcut
    },
    vb:horizontal_aligner{
      width="100%",
      vb:button{
        text="Select All",
        height = button_height,
        width="50%",
        notifier=function()
          for _, cb_info in ipairs(plugins) do
            cb_info.checkbox.value = true
          end
          vb.views["random_select_slider"].value = 100
          vb.views["random_percentage_text"].text="All"
        end
      },
      vb:button{
        text="Reset Selection",
        height = button_height,
        width="50%",
        notifier=function()
          resetSelection()
          vb.views["random_select_slider"].value = 0
          vb.views["random_percentage_text"].text="None"
        end
      }
    },
    vb:horizontal_aligner{
      width="100%",
      vb:button{
        text="Load Plugin(s)",
        width="33%",
        height = button_height,
        notifier=function()
          if loadSelectedPlugins() then
            renoise.app():show_status("Plugins loaded.")
          else
            renoise.app():show_status("Nothing was selected, doing nothing.")
          end
        end
      },
      vb:button{
        text="Load Plugin(s) & Close",
        width="33%",
        height = button_height,
        notifier=function()
          if loadSelectedPlugins() then
            dialog:close()
            dialog = nil
            current_plugin_list_content = nil
          else
            renoise.app():show_status("Nothing was selected, doing nothing.")
          end
        end
      },
      vb:button{
        text="Cancel",
        height = button_height,
        width="34%",
        notifier=function()
          dialog:close()
          dialog = nil
          current_plugin_list_content = nil
        end
      }
    }
  }

  -- Placeholder for Plugin List
  plugin_list_view = vb:column{}

  -- Main Dialog Content
  local dialog_content_view = vb:column{
    margin=10,
    spacing=5,
    plugin_list_view,
    random_selection_controls,
    ccizer_controls,
    action_buttons
  }

  -- Wrap in a column to include the dropdown
  local dialog_content = vb:column{
    vb:horizontal_aligner{
      mode = "center",
      vb:text{text="Select Plugin Type: "},
      dropdown
    },
    dialog_content_view
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Load Plugin(s)", dialog_content, keyhandler)

  -- Initial Update
  updatePluginList()
end

function my_pluginLoaderkeyhandlerfunc(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    current_plugin_list_content = nil  -- Reset current content
    return nil
  else
    return key
  end
end

-- Initialize preferences file and load keybindings and MIDI mappings
loadFromPreferences()

