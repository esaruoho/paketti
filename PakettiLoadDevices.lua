local vb
local checkboxes = {}
local deviceReadableNames = {}
local addedKeyBindings = {}
local current_device_type = "Native"
local device_types = {"Native", "VST", "VST3", "AudioUnit", "LADSPA", "DSSI"}
local dialog
local dialog_content_view
local device_list_view
local current_device_list_content = nil

local DEVICES_PER_COLUMN = 39
local random_select_percentage = 0

-- Function to check if a keybinding exists
function doesKeybindingExist(keyBindingName)
  for _, binding in ipairs(renoise.tool().keybindings) do
    if binding.name == keyBindingName then
      return true
    end
  end
  return false
end

function saveDeviceToPreferences(entryName, path, device_type)
  if not entryName or not path or not device_type then
    print("Error: Cannot save to preferences. Missing data.")
    return
  end

  local loaders = preferences.PakettiDeviceLoaders

  -- Check for duplicates
  for i = 1, #loaders do
    local device = loaders:property(i)
    if device.name.value == entryName and device.device_type.value == device_type then
      print("Device entry already exists. Skipping addition for:", entryName)
      return
    end
  end

  -- Add new device entry
  local newDevice = create_device_entry(entryName, path, device_type)
  loaders:insert(#loaders + 1, newDevice)

  print(string.format("Saved Device '%s' to preferences.", entryName))
end

-- Load from Preferences
function loadDeviceFromPreferences()
  if not preferences.PakettiDeviceLoaders then
    print("No PakettiDeviceLoaders found in preferences.")
    return
  end

  local loaders = preferences.PakettiDeviceLoaders
  for i = 1, #loaders do
    local device = loaders:property(i)
    local device_name = device.name.value
    local path = device.path.value
    local device_type = device.device_type.value

    -- Generate keybinding and midi mapping names
    local entryName = device_name
    local keyBindingName="Global:Paketti:Load Device (" .. device_type .. ") " .. entryName
    local midiMappingName="Paketti:Load Device (" .. device_type .. ") " .. entryName

    -- Re-add keybinding and midi mapping
    local success, err = pcall(function()
      renoise.tool():add_keybinding{name=keyBindingName,invoke=function()
          if device_type == "Native" then
            loadnative(path, nil, nil, nil, false)
          else
            loadvst(path)
          end
        end
      }
      renoise.tool():add_midi_mapping{name=midiMappingName,invoke=function(message)
          if message:is_trigger() then
            if device_type == "Native" then
              loadnative(path, nil, nil, nil, false)
            else
              loadvst(path)
            end
          end
        end
      }
    end)
    if not success then
      print("Could not add keybinding or midi mapping for " .. device_name .. ": " .. err)
    else
      addedKeyBindings[keyBindingName] = true
    end
  end
end

function isAnyDeviceSelected()
  for _, cb_info in ipairs(checkboxes) do
    if cb_info.checkbox.value then
      return true
    end
  end
  return false
end

function loadSelectedDevices()
  if not isAnyDeviceSelected() then
    renoise.app():show_status("Nothing was selected, doing nothing.")
    return false
  end

  local track_index = renoise.song().selected_track_index
  for _, cb_info in ipairs(checkboxes) do
    if cb_info.checkbox.value then
      local pluginPath = cb_info.path
      if current_device_type == "Native" then
        loadnative(pluginPath, nil, nil, nil, false)
      else
        loadvst(pluginPath)
      end
    end
  end
  return true
end

function addDeviceAsShortcut()
  if not isAnyDeviceSelected() then
    renoise.app():show_status("Nothing was selected, doing nothing.")
    return
  end

  for _, cb_info in ipairs(checkboxes) do
    if cb_info.checkbox.value then
      local device_type = current_device_type
      local path = cb_info.path
      local device_name = cb_info.name

      local entryName = device_name

      local keyBindingName="Global:Paketti:Load Device (" .. device_type .. ") " .. entryName
      local midiMappingName="Paketti:Load Device (" .. device_type .. ") " .. entryName

      if not addedKeyBindings[keyBindingName] then
        print("Adding shortcut for: " .. device_name)

        local success, err = pcall(function()
          renoise.tool():add_keybinding{name=keyBindingName,
            invoke=function()
              if device_type == "Native" then
                loadnative(path, nil, nil, nil, false)
              else
                loadvst(path)
              end
            end
          }
          renoise.tool():add_midi_mapping{name=midiMappingName,invoke=function(message)
              if message:is_trigger() then
                if device_type == "Native" then
                  loadnative(path, nil, nil, nil, false)
                else
                  loadvst(path)
                end
              end
            end
          }
        end)

        if success then
          addedKeyBindings[keyBindingName] = true
          saveDeviceToPreferences(entryName, path, device_type)
        else
          print("Could not add keybinding for " .. device_name .. ". It might already exist.")
        end
      else
        print("Keybinding for " .. device_name .. " already added.")
      end
    end
  end
  renoise.app():show_status("Devices added. Open Settings -> Keys, search for 'Load Device' or MIDI Mappings and search for 'Load Device'")
end

function resetSelection()
  for _, cb_info in ipairs(checkboxes) do
    cb_info.checkbox.value = false
  end
end

function updateRandomSelection()
  if #checkboxes == 0 then
    renoise.app():show_status("Nothing to randomize from.")
    return
  end

  resetSelection()

  -- Check if "Favorites Only" is enabled
  local favorites_only = vb.views["favorites_only_checkbox"].value

  -- Filter devices based on the "Favorites Only" checkbox
  local filtered_devices = {}
  for _, cb_info in ipairs(checkboxes) do
    if not favorites_only or (favorites_only and cb_info.is_favorite) then
      table.insert(filtered_devices, cb_info)
    end
  end

  local numDevices = #filtered_devices
  local percentage = random_select_percentage
  local numSelections = math.floor((percentage / 100) * numDevices + 0.5)

  local percentage_text_view = vb.views["random_percentage_text"]

  if numSelections == 0 then
    percentage_text_view.text="None"
    return
  elseif numSelections >= numDevices then
    percentage_text_view.text="All"
    for _, cb_info in ipairs(filtered_devices) do
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

  -- Shuffle indices using Fisher-Yates algorithm
  for i = numDevices, 2, -1 do
    local j = math.random(1, i)
    indices[i], indices[j] = indices[j], indices[i]
  end

  -- Select the randomized devices from filtered list
  for i = 1, numSelections do
    local idx = indices[i]
    filtered_devices[idx].checkbox.value = true
  end
end

function createDeviceList(plugins, title)
  if #plugins == 0 then
    return vb:column{vb:text{text="No Devices found for this type.", font="italic", height=20}}
  end

  local num_devices = #plugins
  local devices_per_column = DEVICES_PER_COLUMN
  local num_columns = math.ceil(num_devices / devices_per_column)

  local columns = {}
  for i = 1, num_columns do
    columns[i] = vb:column{spacing=2}
  end

  local device_index = 1
  for col = 1, num_columns do
    for row = 1, devices_per_column do
      if device_index > num_devices then break end
      local plugin = plugins[device_index]
      local checkbox_id = "checkbox_" .. title .. "_" .. tostring(device_index) .. "_" .. tostring(math.random(1000000))
      local checkbox = vb:checkbox{value=false, id=checkbox_id}
      
      -- Add favorite styling
      local display_name = plugin.name
      if plugin.is_favorite then
        display_name = display_name .. "*"
      end

      checkboxes[#checkboxes + 1] = {
        checkbox=checkbox, 
        path=plugin.path, 
        name=plugin.name,
        is_favorite=plugin.is_favorite
      }

      local plugin_row = vb:row{
        spacing=4,
        checkbox,
        vb:text{
          text=display_name,
          font=plugin.is_favorite and "italic" or "normal",
          style=plugin.is_favorite and "strong" or "normal"
        }
      }
      columns[col]:add_child(plugin_row)
      device_index = device_index + 1
    end
  end

  local column_container = vb:row{spacing=20}
  for _, column in ipairs(columns) do
    column_container:add_child(column)
  end

  return vb:column{
    vb:horizontal_aligner{mode="center",column_container}}
end

function updateDeviceList()
  checkboxes = {}
  deviceReadableNames = {}
  local track_index = renoise.song().selected_track_index
  local available_devices = renoise.song().tracks[track_index].available_devices
  local available_device_infos = renoise.song().tracks[track_index].available_device_infos

  local pluginReadableNames = {}
  for i, plugin_info in ipairs(available_device_infos) do
    pluginReadableNames[available_devices[i]] = plugin_info.short_name
  end

  local device_list_content

  if current_device_type == "Native" then
    local native_devices = {}
    local hidden_devices = {
      {name="(Hidden) Chorus", path = "Audio/Effects/Native/Chorus"},
      {name="(Hidden) Comb Filter", path = "Audio/Effects/Native/Comb Filter"},
      {name="(Hidden) Distortion", path = "Audio/Effects/Native/Distortion"},
      {name="(Hidden) Filter", path = "Audio/Effects/Native/Filter"},
      {name="(Hidden) Filter 2", path = "Audio/Effects/Native/Filter 2"},
      {name="(Hidden) Filter 3", path = "Audio/Effects/Native/Filter 3"},
      {name="(Hidden) Flanger", path = "Audio/Effects/Native/Flanger"},
      {name="(Hidden) Gate", path = "Audio/Effects/Native/Gate"},
      {name="(Hidden) LofiMat", path = "Audio/Effects/Native/LofiMat"},
      {name="(Hidden) mpReverb", path = "Audio/Effects/Native/mpReverb"},
      {name="(Hidden) Phaser", path = "Audio/Effects/Native/Phaser"},
      {name="(Hidden) RingMod", path = "Audio/Effects/Native/RingMod"},
      {name="(Hidden) Scream Filter", path = "Audio/Effects/Native/Scream Filter"},
      {name="(Hidden) Shaper", path = "Audio/Effects/Native/Shaper"},
      {name="(Hidden) Stutter", path = "Audio/Effects/Native/Stutter"}}

      for i, device_path in ipairs(available_devices) do
        if device_path:find("Native/") then
          local normalized_path = device_path:gsub("\\", "/")
          local device_name = normalized_path:match("([^/]+)$")
          local is_favorite = available_device_infos[i].is_favorite
          
          table.insert(native_devices, {
            name = device_name, 
            path = normalized_path,
            is_favorite = is_favorite
          })
        end
      end
  
      table.sort(native_devices, function(a, b)
        return a.name:lower() < b.name:lower()
      end)

    for _, hidden_device in ipairs(hidden_devices) do
      table.insert(native_devices, hidden_device)
    end

    device_list_content = createDeviceList(native_devices, "Native Devices")

  elseif current_device_type == "VST" then
    local vst_devices = {}
    for i, device_path in ipairs(available_devices) do
      if device_path:find("VST") and not device_path:find("VST3") then
        local normalized_path = device_path:gsub("\\", "/")
        local device_name = pluginReadableNames[device_path] or normalized_path:match("([^/]+)$")
        local is_favorite = available_device_infos[i].is_favorite
        
        table.insert(vst_devices, {
          name = device_name, 
          path = normalized_path,
          is_favorite = is_favorite
        })
      end
    end
    device_list_content = createDeviceList(vst_devices, "VST Devices")

  elseif current_device_type == "VST3" then
    local vst3_devices = {}
    for i, device_path in ipairs(available_devices) do
      if device_path:find("VST3") then
        local normalized_path = device_path:gsub("\\", "/")
        local device_name = pluginReadableNames[device_path] or normalized_path:match("([^/]+)$")
        local is_favorite = available_device_infos[i].is_favorite
        
        table.insert(vst3_devices, {
          name = device_name, 
          path = normalized_path,
          is_favorite = is_favorite
        })
      end
    end

    table.sort(vst3_devices, function(a, b)
      return a.name:lower() < b.name:lower()
    end)

    device_list_content = createDeviceList(vst3_devices, "VST3 Devices")

  elseif current_device_type == "AudioUnit" then
    local au_devices = {}
    for i, device_path in ipairs(available_devices) do
      if device_path:find("AU") then
        local normalized_path = device_path:gsub("\\", "/")
        local device_name = pluginReadableNames[device_path] or normalized_path:match("([^/]+)$")
        local is_favorite = available_device_infos[i].is_favorite
        
        table.insert(au_devices, {
          name = device_name, 
          path = normalized_path,
          is_favorite = is_favorite
        })
      end
    end

    table.sort(au_devices, function(a, b)
      return a.name:lower() < b.name:lower()
    end)

    device_list_content = createDeviceList(au_devices, "AudioUnit Devices")

  elseif current_device_type == "LADSPA" then
    local ladspa_devices = {}
    for i, device_path in ipairs(available_devices) do
      if device_path:find("LADSPA") then
        local normalized_path = device_path:gsub("\\", "/")
        local device_name = pluginReadableNames[device_path] or normalized_path:match("([^/]+)$")
        device_name = device_name:match("([^:]+)$") or device_name
        local is_favorite = available_device_infos[i].is_favorite
        
        table.insert(ladspa_devices, {
          name = device_name, 
          path = normalized_path,
          is_favorite = is_favorite
        })
      end
    end

    table.sort(ladspa_devices, function(a, b)
      return a.name:lower() < b.name:lower()
    end)

    device_list_content = createDeviceList(ladspa_devices, "LADSPA Devices")

  elseif current_device_type == "DSSI" then
    local dssi_devices = {}
    for i, device_path in ipairs(available_devices) do
      if device_path:find("DSSI") then
        local normalized_path = device_path:gsub("\\", "/")
        local device_name = pluginReadableNames[device_path] or normalized_path:match("([^/]+)$")
        device_name = device_name:match("([^:]+)$") or device_name
        local is_favorite = available_device_infos[i].is_favorite
        
        table.insert(dssi_devices, {
          name = device_name, 
          path = normalized_path,
          is_favorite = is_favorite
        })
      end
    end

    table.sort(dssi_devices, function(a, b)
      return a.name:lower() < b.name:lower()
    end)

    device_list_content = createDeviceList(dssi_devices, "DSSI Devices")
  end

  if current_device_list_content then
    device_list_view:remove_child(current_device_list_content)
  end

  device_list_view:add_child(device_list_content)
  current_device_list_content = device_list_content
end

function pakettiLoadDevicesDialog()

  -- Add dialog management from plugins version
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    current_device_list_content = nil
    return
  end

  -- Add display name mapping at top
  local device_type_display_names = {
    Native = "Native Instruments",
    VST = "VST",
    VST3 = "VST3",
    AudioUnit = "AudioUnit",
    LADSPA = "LADSPA",
    DSSI = "DSSI"
  }


  current_device_list_content = nil

  vb = renoise.ViewBuilder()
  checkboxes = {}
  local track_index = renoise.song().selected_track_index

  -- Find the index of the current device type for proper dropdown initialization
  local current_device_index = 1
  for i, device_type in ipairs(device_types) do
    if device_type == current_device_type then
      current_device_index = i
      break
    end
  end

  local dropdown = vb:popup{
    items = device_types,
    value = current_device_index,
    notifier=function(index)
      current_device_type = device_types[index]
      updateDeviceList()
    end}

    local random_selection_controls = vb:row{
      vb:text{text="Random Select:",width=80, style="strong",font="bold"},
      vb:slider{
        id = "random_select_slider",
        min = 0,
        max = 100,
        value = 0,
        width=200,
        notifier=function(value)
          random_select_percentage = value
          updateRandomSelection()
        end},
      vb:text{id="random_percentage_text",text="None",width=40, align="center"},
      vb:checkbox{
        id = "favorites_only_checkbox",
        value = false,
        notifier=function() 
          updateRandomSelection() 
        end
      },
      vb:text{text="Favorites Only",width=70},
      vb:button{text="Select All",width=20,
        notifier=function()
          for _, cb_info in ipairs(checkboxes) do
            cb_info.checkbox.value = true
          end
          vb.views["random_select_slider"].value = 100
          vb.views["random_percentage_text"].text="All"
        end},
      vb:button{text="Reset Selection",width=20,
        notifier=function()
          resetSelection()
          vb.views["random_select_slider"].value = 0
          vb.views["random_percentage_text"].text="None"
        end}}

  local button_height = renoise.ViewBuilder.DEFAULT_DIALOG_BUTTON_HEIGHT
  local action_buttons = vb:column{
    vb:horizontal_aligner{width="100%",
      vb:button{text="Load Device(s)",width=60,
        notifier=function()
          if loadSelectedDevices() then
            renoise.app():show_status("Devices loaded.")
          end
        end
      },
      vb:button{text="Load & Close",width=60,
        notifier=function()
          if loadSelectedDevices() then
            dialog:close()
            renoise.app():show_status("Devices loaded.")
          end
        end
      },
      vb:button{text="Add Device(s) as Shortcut(s) & MidiMappings",width=140,
        notifier = addDeviceAsShortcut},
      vb:button{text="Cancel",width=30,
        notifier=function() dialog:close() end}}}
        
  device_list_view = vb:column{}
  dialog_content_view = vb:column{margin=10,spacing=5,device_list_view,}

  -- Wrap in a column to include the dropdown
  local dialog_content = vb:column{
    vb:horizontal_aligner{
      vb:text{text="Device Type: ", font="bold",style="strong"},
      dropdown,action_buttons,random_selection_controls},dialog_content_view}

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Load Device(s)", dialog_content, keyhandler)

  updateDeviceList()
end

loadDeviceFromPreferences()
-------
local dialog = nil  -- Keep track of dialog state

function pakettiQuickLoadDialog()
  -- Toggle dialog if it exists
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  
  -- Get current track's available devices and their info
  local track = renoise.song().selected_track
  local available_devices = track.available_devices
  local available_device_infos = track.available_device_infos
  
  -- Create category-specific arrays
  local native_devices = {}
  local au_devices = {}
  local vst_devices = {}
  local vst3_devices = {}
  local ladspa_devices = {}
  local dssi_devices = {}
  
  -- Create readable names mapping
  local device_items = {}
  local device_paths = {}
  
  -- Add hidden native devices first
  local hidden_devices = {
    {name="Native: (Hidden) Chorus", path="Audio/Effects/Native/Chorus"},
    {name="Native: (Hidden) Comb Filter", path="Audio/Effects/Native/Comb Filter"},
    {name="Native: (Hidden) Distortion", path="Audio/Effects/Native/Distortion"},
    {name="Native: (Hidden) Filter", path="Audio/Effects/Native/Filter"},
    {name="Native: (Hidden) Filter 2", path="Audio/Effects/Native/Filter 2"},
    {name="Native: (Hidden) Filter 3", path="Audio/Effects/Native/Filter 3"},
    {name="Native: (Hidden) Flanger", path="Audio/Effects/Native/Flanger"},
    {name="Native: (Hidden) Gate", path="Audio/Effects/Native/Gate"},
    {name="Native: (Hidden) LofiMat", path="Audio/Effects/Native/LofiMat"},
    {name="Native: (Hidden) mpReverb", path="Audio/Effects/Native/mpReverb"},
    {name="Native: (Hidden) Phaser", path="Audio/Effects/Native/Phaser"},
    {name="Native: (Hidden) RingMod", path="Audio/Effects/Native/RingMod"},
    {name="Native: (Hidden) Scream Filter", path="Audio/Effects/Native/Scream Filter"},
    {name="Native: (Hidden) Shaper", path="Audio/Effects/Native/Shaper"},
    {name="Native: (Hidden) Stutter", path="Audio/Effects/Native/Stutter"}
  }
  
  for _, device in ipairs(hidden_devices) do
    table.insert(native_devices, device)
  end
  
  -- Sort devices into categories
  for i, device_path in ipairs(available_devices) do
    local device_name
    local normalized_path = device_path:gsub("\\", "/")
    
    if device_path:find("Native/") then
      device_name = "Native: " .. normalized_path:match("([^/]+)$")
      table.insert(native_devices, {name=device_name, path=normalized_path})
    elseif device_path:find("VST3") then
      device_name = "VST3: " .. (available_device_infos[i].short_name or normalized_path:match("([^/]+)$"))
      table.insert(vst3_devices, {name=device_name, path=normalized_path})
    elseif device_path:find("VST") and not device_path:find("VST3") then
      device_name = "VST: " .. (available_device_infos[i].short_name or normalized_path:match("([^/]+)$"))
      table.insert(vst_devices, {name=device_name, path=normalized_path})
    elseif device_path:find("AU") then
      device_name = "AU: " .. (available_device_infos[i].short_name or normalized_path:match("([^/]+)$"))
      table.insert(au_devices, {name=device_name, path=normalized_path})
    elseif device_path:find("LADSPA") then
      local short_name = (available_device_infos[i].short_name or normalized_path:match("([^/]+)$")):match("([^:]+)$")
      device_name = "LADSPA: " .. short_name
      table.insert(ladspa_devices, {name=device_name, path=normalized_path})
    elseif device_path:find("DSSI") then
      local short_name = (available_device_infos[i].short_name or normalized_path:match("([^/]+)$")):match("([^:]+)$")
      device_name = "DSSI: " .. short_name
      table.insert(dssi_devices, {name=device_name, path=normalized_path})
    end
  end
  
  -- Sort each category internally
  local function sort_devices(devices)
    table.sort(devices, function(a, b) return a.name:lower() < b.name:lower() end)
  end
  
  sort_devices(native_devices)
  sort_devices(au_devices)
  sort_devices(vst_devices)
  sort_devices(vst3_devices)
  sort_devices(ladspa_devices)
  sort_devices(dssi_devices)
  
  -- Combine all devices in the desired order
  local all_categories = {
    {devices = native_devices},
    {devices = au_devices},
    {devices = vst_devices},
    {devices = vst3_devices},
    {devices = ladspa_devices},
    {devices = dssi_devices}
  }
  
  -- Add devices to the final list only if the category has items
  for _, category in ipairs(all_categories) do
    if #category.devices > 0 then
      for _, device in ipairs(category.devices) do
        table.insert(device_items, device.name)
        device_paths[device.name] = device.path
      end
    end
  end

  -- Fuzzy search state and helpers (autocomplete-style key handling)
  local all_device_items = {}
  for i = 1, #device_items do all_device_items[i] = device_items[i] end
  local search_text = ""
  local search_display = nil
  local function filter_items()
    local lower_search = string.lower(search_text)
    if lower_search == "" then
      device_items = {}
      for i = 1, #all_device_items do device_items[i] = all_device_items[i] end
    else
      local terms = {}
      for t in lower_search:gmatch("%S+") do table.insert(terms, t) end
      local filtered = {}
      for _, name in ipairs(all_device_items) do
        local ln = string.lower(name)
        local ok = true
        for _, term in ipairs(terms) do
          if not string.find(ln, term, 1, true) then ok = false break end
        end
        if ok then table.insert(filtered, name) end
      end
      device_items = filtered
    end
    if vb and vb.views and vb.views.device_selector then
      local items_for_popup = device_items
      if #device_items == 0 then
        items_for_popup = {"<No matches>"}
      end
      vb.views.device_selector.items = items_for_popup
      vb.views.device_selector.value = 1
    end
    if search_display then
      local count = #device_items
      search_display.text = "Type to search: '" .. search_text .. "' (" .. tostring(count) .. ")"
    end
    renoise.app():show_status("Quick Load: '" .. search_text .. "' - " .. tostring(#device_items) .. " matches")
  end

  -- Helper function to load device to all FX chains
  local function load_to_all_fx_chains(device_path)
    local instrument = renoise.song().selected_instrument
    if not instrument or #instrument.sample_device_chains == 0 then
      renoise.app():show_status("No sample FX chains available")
      return false
    end
    
    local num_chains = #instrument.sample_device_chains
    local loaded_count = 0
    
    for chain_index = 1, num_chains do
      local chain = instrument.sample_device_chains[chain_index]
      if chain then
        -- Determine insertion position (same logic as loadnative)
        local sample_devices = chain.devices
        local load_at_end = preferences.pakettiLoadOrder and preferences.pakettiLoadOrder.value or false
        local checkline
        
        if load_at_end then
          checkline = #sample_devices + 1
        else
          checkline = (table.count and table.count(sample_devices) or #sample_devices) < 2 and 2 or 
                     (sample_devices[2] and sample_devices[2].name == "#Line Input" and 3 or 2)
        end
        checkline = math.min(checkline, #sample_devices + 1)
        
        -- Insert the device
        local success, err = pcall(function()
          chain:insert_device_at(device_path, checkline)
        end)
        
        if success then
          loaded_count = loaded_count + 1
          print("Loaded device to FX chain " .. chain_index .. " at position " .. checkline)
        else
          print("Failed to load device to FX chain " .. chain_index .. ": " .. tostring(err))
        end
      end
    end
    
    if loaded_count > 0 then
      renoise.app():show_status("Loaded device to " .. loaded_count .. "/" .. num_chains .. " FX chains")
      return true
    else
      renoise.app():show_status("Failed to load device to any FX chains")
      return false
    end
  end

  -- Helper function to load device to all sequencer tracks
  local function load_to_all_tracks(device_path)
    local song = renoise.song()
    local tracks = song.tracks
    local loaded_count = 0
    local total_sequencer_tracks = 0
    
    -- Count sequencer tracks first
    for i = 1, #tracks do
      local track = tracks[i]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        total_sequencer_tracks = total_sequencer_tracks + 1
      end
    end
    
    if total_sequencer_tracks == 0 then
      renoise.app():show_status("No sequencer tracks found")
      return false
    end
    
    -- Check device restrictions for sequencer tracks
    if device_path:find("*Instr.") or device_path:find("*Key Tracker") or 
       device_path:find("*Velocity Tracker") or device_path:find("*MIDI Control") then
      renoise.app():show_status("Cannot load MIDI/Instrument devices on sequencer tracks")
      return false
    end
    
    -- Load device to all sequencer tracks
    for i = 1, #tracks do
      local track = tracks[i]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local track_devices = track.devices
        local load_at_end = preferences.pakettiLoadToAllTracksPosition and preferences.pakettiLoadToAllTracksPosition.value or false
        local checkline
        
        if load_at_end then
          -- Load at end of track devices
          checkline = #track_devices + 1
        else
          -- Load at start (after mixer device at position 1)
          checkline = 2
        end
        
        -- Insert the device
        local success, err = pcall(function()
          track:insert_device_at(device_path, checkline)
        end)
        
        if success then
          -- Minimize the device after loading
          local device = track.devices[checkline]
          if device and device.is_maximized ~= nil then
            device.is_maximized = false
          end
          
          loaded_count = loaded_count + 1
          print("Loaded device to track " .. i .. " (" .. track.name .. ") at position " .. checkline .. " (minimized)")
        else
          print("Failed to load device to track " .. i .. " (" .. track.name .. "): " .. tostring(err))
        end
      end
    end
    
    if loaded_count > 0 then
      local position_text = preferences.pakettiLoadToAllTracksPosition and preferences.pakettiLoadToAllTracksPosition.value and "last" or "first"
      renoise.app():show_status("Loaded device to " .. loaded_count .. "/" .. total_sequencer_tracks .. " sequencer tracks (" .. position_text .. " position, minimized)")
      return true
    else
      renoise.app():show_status("Failed to load device to any sequencer tracks")
      return false
    end
  end

  -- Helper function to find all instances of a device across all tracks
  local function find_all_device_instances(device_name, device_path)
    local song = renoise.song()
    local instances = {}
    
    -- Search track devices
    for track_idx = 1, #song.tracks do
      local track = song.tracks[track_idx]
      for device_idx = 1, #track.devices do
        local device = track.devices[device_idx]
        
        -- Try matching by name first, then by device_path if available
        if device.name == device_name or (device.device_path and device.device_path == device_path) then
          table.insert(instances, {
            type = "track",
            track_idx = track_idx,
            device_idx = device_idx,
            device = device,
            track_name = track.name
          })
        end
      end
    end
    
    -- Search sample FX chain devices
    for instr_idx = 1, #song.instruments do
      local instrument = song.instruments[instr_idx]
      for chain_idx = 1, #instrument.sample_device_chains do
        local chain = instrument.sample_device_chains[chain_idx]
        for device_idx = 1, #chain.devices do
          local device = chain.devices[device_idx]
          
          -- Try matching by name first, then by device_path if available
          if device.name == device_name or (device.device_path and device.device_path == device_path) then
            table.insert(instances, {
              type = "sample_fx",
              instr_idx = instr_idx,
              chain_idx = chain_idx,
              device_idx = device_idx,
              device = device,
              instrument_name = instrument.name,
              chain_name = chain.name
            })
          end
        end
      end
    end
    
    return instances
  end

  -- Helper function to toggle all instances of a device
  local function toggle_all_device_instances(device_name, device_path)
    local instances = find_all_device_instances(device_name, device_path)
    
    if #instances == 0 then
      renoise.app():show_status("No instances of '" .. device_name .. "' found")
      return
    end
    
    local toggled_count = 0
    local current_state = nil
    
    for _, instance in ipairs(instances) do
      local device = instance.device
      -- Store the first device's state to determine toggle direction
      if current_state == nil then
        current_state = device.is_active
      end
      
      -- Toggle the device
      device.is_active = not current_state
      toggled_count = toggled_count + 1
      
      local location = ""
      if instance.type == "track" then
        location = "Track " .. instance.track_idx .. " (" .. instance.track_name .. ")"
      else
        location = "Instrument " .. instance.instr_idx .. " (" .. instance.instrument_name .. ") FX Chain " .. instance.chain_idx
      end
      print("Toggled " .. device_name .. " on " .. location .. " to " .. (device.is_active and "ON" or "OFF"))
    end
    
    local new_state = current_state and "OFF" or "ON"
    renoise.app():show_status("Toggled " .. toggled_count .. " instances of '" .. device_name .. "' to " .. new_state)
  end

  -- Helper function to toggle external editors for all instances of a device
  local function toggle_all_device_editors(device_name, device_path)
    local instances = find_all_device_instances(device_name, device_path)
    
    if #instances == 0 then
      renoise.app():show_status("No instances of '" .. device_name .. "' found")
      return
    end
    
    local toggled_count = 0
    local current_editor_state = nil
    local devices_with_editors = 0
    
    for _, instance in ipairs(instances) do
      local device = instance.device
      if device.external_editor_available then
        devices_with_editors = devices_with_editors + 1
        
        -- Store the first device's editor state to determine toggle direction
        if current_editor_state == nil then
          current_editor_state = device.external_editor_visible
        end
        
        -- Toggle the external editor
        device.external_editor_visible = not current_editor_state
        toggled_count = toggled_count + 1
        
        local location = ""
        if instance.type == "track" then
          location = "Track " .. instance.track_idx .. " (" .. instance.track_name .. ")"
        else
          location = "Instrument " .. instance.instr_idx .. " (" .. instance.instrument_name .. ") FX Chain " .. instance.chain_idx
        end
        print("Toggled " .. device_name .. " external editor on " .. location .. " to " .. (device.external_editor_visible and "VISIBLE" or "HIDDEN"))
      end
    end
    
    if devices_with_editors == 0 then
      renoise.app():show_status("No instances of '" .. device_name .. "' have external editors available")
    else
      local new_state = current_editor_state and "HIDDEN" or "VISIBLE"
      renoise.app():show_status("Toggled external editors for " .. toggled_count .. "/" .. devices_with_editors .. " instances of '" .. device_name .. "' to " .. new_state)
    end
  end

  local function execute_selected()
    if #device_items == 0 then return end
    local idx = vb.views.device_selector.value
    if idx < 1 or idx > #device_items then return end
    local selected_name = device_items[idx]
    local device_path = device_paths[selected_name]
    print("QuickLoad Execute: selected='" .. tostring(selected_name) .. "' path='" .. tostring(device_path) .. "'")
    if not device_path or device_path == "" then
      renoise.app():show_status("Quick Load: No path found for '" .. tostring(selected_name) .. "'")
      return
    end
    local track = renoise.song().selected_track
    if device_path:find("*Instr.") or device_path:find("*Key Tracker") or 
       device_path:find("*Velocity Tracker") or device_path:find("*MIDI Control") then
      if track.type == renoise.Track.TRACK_TYPE_GROUP then
        renoise.app():show_status("Cannot load MIDI/Instrument devices on Group tracks")
        return
      elseif track.type == renoise.Track.TRACK_TYPE_SEND then
        renoise.app():show_status("Cannot load MIDI/Instrument devices on Send tracks")
        return
      elseif track.type == renoise.Track.TRACK_TYPE_MASTER then
        renoise.app():show_status("Cannot load MIDI/Instrument devices on Master track")
        return
      end
    end
    local in_sample_fx = (
      renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
      and renoise.song().selected_sample_index > 0
    )
    local line_input_index = nil
    if not in_sample_fx then
      for i, dev in ipairs(track.devices) do
        if dev.name == "Line Input" then line_input_index = i break end
      end
    end

    if in_sample_fx and string.find(device_path, "#Line Input", 1, true) then
      renoise.app():show_status("Cannot load Line Input in Sample FX chain")
      return
    end
    
    -- Check if "Load to All FX Chains" is enabled and we're in sample FX mode
    if in_sample_fx and vb.views.load_to_all_fx_checkbox and vb.views.load_to_all_fx_checkbox.value then
      load_to_all_fx_chains(device_path)
      return
    end
    
    -- Check if "Load to All Tracks" is enabled and we're NOT in sample FX mode
    if not in_sample_fx and vb.views.load_to_all_tracks_checkbox and vb.views.load_to_all_tracks_checkbox.value then
      load_to_all_tracks(device_path)
      return
    end
    
    print("QuickLoad Execute: in_sample_fx=" .. tostring(in_sample_fx) .. " line_input_index=" .. tostring(line_input_index))
    if device_path:find("Native/") then
      print(string.format("QuickLoad Execute: calling loadnative(\"%s\", %s, %s, nil, false)", tostring(device_path), tostring(line_input_index), tostring(in_sample_fx)))
      loadnative(device_path, line_input_index, in_sample_fx, nil, false)
    else
      print(string.format("QuickLoad Execute: calling loadvst(\"%s\", %s, %s, nil, false)", tostring(device_path), tostring(line_input_index), tostring(in_sample_fx)))
      loadvst(device_path, line_input_index, in_sample_fx, nil, false)
    end
    renoise.app():show_status("Loaded: " .. selected_name)
  end
  
  -- Check if we're in sample FX mode to show the checkbox
  local in_sample_fx = (
    renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
    and renoise.song().selected_sample_index > 0
  )
  
  local content = vb:column{
    vb:row{
      (function()
        search_display = vb:text{ text = "Type to search: ''", width = 300, style = "strong" }
        return search_display
      end)()
    },
    -- Add the "Load to All FX Chains" checkbox if we're in sample FX mode
    (in_sample_fx and vb:row{
      vb:checkbox{
        id = "load_to_all_fx_checkbox",
        value = false
      },
      vb:text{ text = "Load to All FX Chains", width = 150 }
    } or vb:space{}),
    -- Add the "Load to All Tracks" checkbox if we're NOT in sample FX mode
    (not in_sample_fx and vb:row{
      vb:checkbox{
        id = "load_to_all_tracks_checkbox",
        value = false
      },
      vb:text{ text = "Load to All Tracks (" .. (preferences.pakettiLoadToAllTracksPosition and preferences.pakettiLoadToAllTracksPosition.value and "Last" or "First") .. ")", width = 200 }
    } or vb:space{}),
    vb:row{
      vb:popup{
        id = "device_selector",
        width=300,
        items = device_items,
        value = 1
      },
      vb:button{
        text="Load",
        width=80,
        notifier=function()
          local selected_name = device_items[vb.views.device_selector.value]
          local device_path = device_paths[selected_name]
          print("QuickLoad Button: selected='" .. tostring(selected_name) .. "' path='" .. tostring(device_path) .. "'")
          if not device_path or device_path == "" then
            renoise.app():show_status("Quick Load: No path found for '" .. tostring(selected_name) .. "'")
            return
          end
          local track = renoise.song().selected_track
          
          -- Check device restrictions based on track type
          if device_path:find("*Instr.") or device_path:find("*Key Tracker") or 
             device_path:find("*Velocity Tracker") or device_path:find("*MIDI Control") then
            if track.type == renoise.Track.TRACK_TYPE_GROUP then
              renoise.app():show_status("Cannot load MIDI/Instrument devices on Group tracks")
              return
            elseif track.type == renoise.Track.TRACK_TYPE_SEND then
              renoise.app():show_status("Cannot load MIDI/Instrument devices on Send tracks")
              return
            elseif track.type == renoise.Track.TRACK_TYPE_MASTER then
              renoise.app():show_status("Cannot load MIDI/Instrument devices on Master track")
              return
            end
          end
          
          -- Check if we're in sample fx mode
          local in_sample_fx = (
            renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
            and renoise.song().selected_sample_index > 0
          )
          
          -- Find Line Input position for insertion
          local line_input_index = nil
          if not in_sample_fx then
            for i, device in ipairs(track.devices) do
              if device.name == "Line Input" then
                line_input_index = i
                break
              end
            end
          end

          if in_sample_fx and string.find(device_path, "#Line Input", 1, true) then
            renoise.app():show_status("Cannot load Line Input in Sample FX chain")
            return
          end
          
          -- Check if "Load to All FX Chains" is enabled and we're in sample FX mode
          if in_sample_fx and vb.views.load_to_all_fx_checkbox and vb.views.load_to_all_fx_checkbox.value then
            load_to_all_fx_chains(device_path)
            return
          end
          
          -- Check if "Load to All Tracks" is enabled and we're NOT in sample FX mode
          if not in_sample_fx and vb.views.load_to_all_tracks_checkbox and vb.views.load_to_all_tracks_checkbox.value then
            load_to_all_tracks(device_path)
            return
          end
          
          -- Load the device normally
          print("QuickLoad Button: in_sample_fx=" .. tostring(in_sample_fx) .. " line_input_index=" .. tostring(line_input_index))
          if device_path:find("Native/") then
            print(string.format("QuickLoad Button: calling loadnative(\"%s\", %s, %s, nil, false)", tostring(device_path), tostring(line_input_index), tostring(in_sample_fx)))
            loadnative(device_path, line_input_index, in_sample_fx, nil, false)
          else
            print(string.format("QuickLoad Button: calling loadvst(\"%s\", %s, %s, nil, false)", tostring(device_path), tostring(line_input_index), tostring(in_sample_fx)))
            loadvst(device_path, line_input_index, in_sample_fx, nil, false)
          end
          
          renoise.app():show_status("Loaded: " .. selected_name)
        end
      },
      vb:button{
        text="Enable/Disable",
        width=100,
        notifier=function()
          local selected_name = device_items[vb.views.device_selector.value]
          local device_path = device_paths[selected_name]
          if not device_path or device_path == "" then
            renoise.app():show_status("Quick Load: No path found for '" .. tostring(selected_name) .. "'")
            return
          end
          
          -- Extract device name from path for matching
          local device_name = device_path:match("([^/]+)$")
          if not device_name then
            renoise.app():show_status("Could not extract device name from path")
            return
          end
          
          -- Toggle all instances of this device across all tracks
          toggle_all_device_instances(device_name, device_path)
        end
      },
      vb:button{
        text="Show/Hide Editors",
        width=120,
        notifier=function()
          local selected_name = device_items[vb.views.device_selector.value]
          local device_path = device_paths[selected_name]
          if not device_path or device_path == "" then
            renoise.app():show_status("Quick Load: No path found for '" .. tostring(selected_name) .. "'")
            return
          end
          
          -- Extract device name from path for matching
          local device_name = device_path:match("([^/]+)$")
          if not device_name then
            renoise.app():show_status("Could not extract device name from path")
            return
          end
          
          -- Toggle external editors for all instances of this device
          toggle_all_device_editors(device_name, device_path)
        end
      }
    }
  }
  
  -- Create dialog
  dialog = renoise.app():show_custom_dialog("Paketti Quick Load Device", 
    content,
    function(dlg, key)
      -- Autocomplete-style keyhandler (no textfield)
      if key and (key.name == "<" or key.name == ">") then return key end
      if key.name == "return" then
        execute_selected()
        return nil
      elseif key.name == "up" then
        if #device_items > 0 then
          local v = vb.views.device_selector.value
          if v <= 1 then v = #device_items else v = v - 1 end
          vb.views.device_selector.value = v
        end
        return nil
      elseif key.name == "down" then
        if #device_items > 0 then
          local maxv = math.max(1, #device_items)
          local v = vb.views.device_selector.value
          if v < 1 or v >= maxv then v = 1 else v = v + 1 end
          vb.views.device_selector.value = v
        end
        return nil
      elseif key.name == "prior" then
        if #device_items > 0 then
          local maxv = math.max(1, #device_items)
          local v = vb.views.device_selector.value
          if v < 1 then v = 1 end
          v = math.max(1, v - 10)
          vb.views.device_selector.value = v
        end
        return nil
      elseif key.name == "next" then
        if #device_items > 0 then
          local maxv = math.max(1, #device_items)
          local v = vb.views.device_selector.value
          if v < 1 then v = 1 end
          v = math.min(maxv, v + 10)
          vb.views.device_selector.value = v
        end
        return nil
      elseif key.name == "wheel_up" then
        if #device_items > 0 then
          local v = vb.views.device_selector.value
          if v < 1 then v = 1 end
          v = math.max(1, v - 3)
          vb.views.device_selector.value = v
        end
        return nil
      elseif key.name == "wheel_down" then
        if #device_items > 0 then
          local maxv = math.max(1, #device_items)
          local v = vb.views.device_selector.value
          if v < 1 then v = 1 end
          v = math.min(maxv, v + 3)
          vb.views.device_selector.value = v
        end
        return nil
      elseif key.name == "esc" then
        if search_text ~= "" then
          search_text = ""
          filter_items()
          return nil
        end
        return my_keyhandler_func(dlg, key)
      elseif key.name == "back" then
        if #search_text > 0 then
          search_text = search_text:sub(1, #search_text - 1)
          filter_items()
        end
        return nil
      elseif key.name == "delete" then
        search_text = ""
        filter_items()
        return nil
      elseif key.name == "space" then
        search_text = search_text .. " "
        filter_items()
        return nil
      elseif string.len(key.name) == 1 then
        search_text = search_text .. key.name
        filter_items()
        return nil
      else
        return my_keyhandler_func(dlg, key)
      end
    end)

  -- Set focus to the dropdown
  vb.views.device_selector.value = 1

  -- Set middle frame
  if renoise.app().window.active_middle_frame then
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  end
end

-- Global functions for device control that can be called from keybindings and MIDI mappings
function PakettiToggleAllDeviceInstances(device_name)
  if not device_name or device_name == "" then
    renoise.app():show_status("No device name provided")
    return
  end
  
  local song = renoise.song()
  local instances = {}
  
  print("DEBUG: Global function searching for device_name='" .. tostring(device_name) .. "'")
  
  -- Search track devices
  for track_idx = 1, #song.tracks do
    local track = song.tracks[track_idx]
    for device_idx = 1, #track.devices do
      local device = track.devices[device_idx]
      print("DEBUG: Global Track " .. track_idx .. " Device " .. device_idx .. " name='" .. tostring(device.name) .. "' path='" .. tostring(device.device_path) .. "'")
      
      if device.name == device_name then
        table.insert(instances, {
          type = "track",
          track_idx = track_idx,
          device_idx = device_idx,
          device = device,
          track_name = track.name
        })
        print("DEBUG: Global found match on track " .. track_idx .. " device " .. device_idx)
      end
    end
  end
  
  -- Search sample FX chain devices
  for instr_idx = 1, #song.instruments do
    local instrument = song.instruments[instr_idx]
    for chain_idx = 1, #instrument.sample_device_chains do
      local chain = instrument.sample_device_chains[chain_idx]
      for device_idx = 1, #chain.devices do
        local device = chain.devices[device_idx]
        print("DEBUG: Global SampleFX Instr " .. instr_idx .. " Chain " .. chain_idx .. " Device " .. device_idx .. " name='" .. tostring(device.name) .. "' path='" .. tostring(device.device_path) .. "'")
        
        if device.name == device_name then
          table.insert(instances, {
            type = "sample_fx",
            instr_idx = instr_idx,
            chain_idx = chain_idx,
            device_idx = device_idx,
            device = device,
            instrument_name = instrument.name,
            chain_name = chain.name
          })
          print("DEBUG: Global found match on sample FX instr " .. instr_idx .. " chain " .. chain_idx .. " device " .. device_idx)
        end
      end
    end
  end
  
  print("DEBUG: Global found " .. #instances .. " total instances")
  
  if #instances == 0 then
    renoise.app():show_status("No instances of '" .. device_name .. "' found")
    return
  end
  
  local toggled_count = 0
  local current_state = nil
  
  for _, instance in ipairs(instances) do
    local device = instance.device
    -- Store the first device's state to determine toggle direction
    if current_state == nil then
      current_state = device.is_active
    end
    
    -- Toggle the device
    device.is_active = not current_state
    toggled_count = toggled_count + 1
  end
  
  local new_state = current_state and "OFF" or "ON"
  renoise.app():show_status("Toggled " .. toggled_count .. " instances of '" .. device_name .. "' to " .. new_state)
end


renoise.tool():add_keybinding{name="Global:Paketti:Quick Load Device Dialog...", invoke=pakettiQuickLoadDialog}

-- Add keybindings for common device control functions
--renoise.tool():add_keybinding{name="Global:Paketti:Toggle All EQ 10 Instances", invoke=function() PakettiToggleAllDeviceInstances("EQ 10") end}
--renoise.tool():add_keybinding{name="Global:Paketti:Toggle All Filter Instances", invoke=function() PakettiToggleAllDeviceInstances("Filter") end}
--renoise.tool():add_keybinding{name="Global:Paketti:Toggle All Reverb Instances", invoke=function() PakettiToggleAllDeviceInstances("Reverb") end}
--renoise.tool():add_keybinding{name="Global:Paketti:Toggle All Delay Instances", invoke=function() PakettiToggleAllDeviceInstances("Delay") end}
--renoise.tool():add_keybinding{name="Global:Paketti:Toggle All Compressor Instances", invoke=function() PakettiToggleAllDeviceInstances("Compressor") end}

renoise.tool():add_midi_mapping{name="Paketti:Quick Load Device Dialog... [Trigger]", invoke=function(message) if message:is_trigger() then pakettiQuickLoadDialog() end end}
