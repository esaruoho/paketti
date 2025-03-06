local vb
local checkboxes = {}
local deviceReadableNames = {}
local addedKeyBindings = {}
local current_device_type = "Native"
local device_types = {"Native", "VST", "VST3", "AudioUnit", "LADSPA", "DSSI"}
local custom_dialog
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
      renoise.tool():add_keybinding{
        name = keyBindingName,
        invoke=function()
          if device_type == "Native" then
            loadnative(path)
          else
            loadvst(path)
          end
        end
      }
      renoise.tool():add_midi_mapping{
        name = midiMappingName,
        invoke = function(message)
          if message:is_trigger() then
            if device_type == "Native" then
              loadnative(path)
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
        loadnative(pluginPath)
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
          renoise.tool():add_keybinding{
            name = keyBindingName,
            invoke=function()
              if device_type == "Native" then
                loadnative(path)
              else
                loadvst(path)
              end
            end
          }
          renoise.tool():add_midi_mapping{
            name = midiMappingName,
            invoke = function(message)
              if message:is_trigger() then
                if device_type == "Native" then
                  loadnative(path)
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
    percentage_text_view.text = "None"
    return
  elseif numSelections >= numDevices then
    percentage_text_view.text = "All"
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

function showDeviceListDialog()

  -- Add dialog management from plugins version
  if custom_dialog and custom_dialog.visible then
    custom_dialog:close()
    custom_dialog = nil
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

  local dropdown = vb:popup{
    items = device_types,
    value = 1,
    notifier = function(index)
      current_device_type = device_types[index]
      updateDeviceList()
    end}

    local random_selection_controls = vb:row{
      vb:text{text = "Random Select:", width = 80, style="strong",font="bold"},
      vb:slider{
        id = "random_select_slider",
        min = 0,
        max = 100,
        value = 0,
        width = 200,
        notifier = function(value)
          random_select_percentage = value
          updateRandomSelection()
        end},
      vb:text{id="random_percentage_text",text="None",width=40, align="center"},
      vb:checkbox{
        id = "favorites_only_checkbox",
        value = false,
        notifier = function() 
          updateRandomSelection() 
        end
      },
      vb:text{text="Favorites Only", width=70},
      vb:button{text="Select All",width=20,
        notifier = function()
          for _, cb_info in ipairs(checkboxes) do
            cb_info.checkbox.value = true
          end
          vb.views["random_select_slider"].value = 100
          vb.views["random_percentage_text"].text = "All"
        end},
      vb:button{text="Reset Selection",width=20,
        notifier = function()
          resetSelection()
          vb.views["random_select_slider"].value = 0
          vb.views["random_percentage_text"].text = "None"
        end}}

  local button_height = renoise.ViewBuilder.DEFAULT_DIALOG_BUTTON_HEIGHT
  local action_buttons = vb:column{
    vb:horizontal_aligner{width="100%",
      vb:button{text="Load Device(s)",width=60,
        notifier = function()
          if loadSelectedDevices() then
            renoise.app():show_status("Devices loaded.")
          end
        end
      },
      vb:button{text="Load & Close",width=60,
        notifier = function()
          if loadSelectedDevices() then
            custom_dialog:close()
            renoise.app():show_status("Devices loaded.")
          end
        end
      },
      vb:button{text="Add Device(s) as Shortcut(s) & MidiMappings",width=140,
        notifier = addDeviceAsShortcut},
      vb:button{text="Cancel",width=30,
        notifier = function() custom_dialog:close() end}}}
        
  device_list_view = vb:column{}
  dialog_content_view = vb:column{margin = 10,spacing = 5,device_list_view,}

  -- Wrap in a column to include the dropdown
  local dialog_content = vb:column{
    vb:horizontal_aligner{
      vb:text{text = "Device Type: ", font="bold",style="strong"},
      dropdown,action_buttons,random_selection_controls},dialog_content_view}

  custom_dialog = renoise.app():show_custom_dialog("Load Device(s)", dialog_content, my_Devicekeyhandler_func)

  updateDeviceList()
end

function my_Devicekeyhandler_func(custom_dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    custom_dialog:close()
    custom_dialog = nil
    return nil
  else
    return key
  end
end

loadDeviceFromPreferences()


-------
--[[---------------------------------------------------------------------------
Quick Load Device Dialog for Paketti
---------------------------------------------------------------------------]]--

local custom_dialog = nil  -- Keep track of dialog state

function showQuickLoadDialog()
  -- Toggle dialog if it exists
  if custom_dialog and custom_dialog.visible then
    custom_dialog:close()
    custom_dialog = nil
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
  
  local content = vb:column {
    margin = 10,
    spacing = 10,
    
    vb:row {
      spacing = 10,
      vb:popup {
        id = "device_selector",
        width = 400,
        items = device_items,
        value = 1
      },
      vb:button {
        text = "Load",
        width = 60,
        notifier = function()
          local selected_name = device_items[vb.views.device_selector.value]
          local device_path = device_paths[selected_name]
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
          local in_sample_fx = false
          if renoise.song().selected_sample_index > 0 then
            in_sample_fx = true
          end
          
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
          
          -- Load the device
          if device_path:find("Native/") then
            loadnative(device_path, line_input_index, in_sample_fx)
          else
            loadvst(device_path, line_input_index, in_sample_fx)
          end
          
          renoise.app():show_status("Loaded: " .. selected_name)
        end
      }
    }
  }
  
  -- Create dialog
  custom_dialog = renoise.app():show_custom_dialog(
    "Quick Load Device", 
    content,
    function(dialog, key)
      local closer = preferences.pakettiDialogClose.value
      if key.modifiers == "" and key.name == closer then
        dialog:close()
        custom_dialog = nil
        return nil
      else
        return key
      end
    end
  )

  -- Set focus to the dropdown
  vb.views.device_selector.value = 1

  -- Set middle frame
  if renoise.app().window.active_middle_frame then
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  end
end

-- Add menu entries and keybinding
renoise.tool():add_keybinding{name="Global:Tools:Quick Load Device", invoke=showQuickLoadDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Quick Load Device...", invoke=showQuickLoadDialog}
renoise.tool():add_menu_entry{name="DSP Device:Paketti..:Quick Load Device...", invoke=showQuickLoadDialog}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Quick Load Device...", invoke=showQuickLoadDialog}
renoise.tool():add_midi_mapping{name="Paketti:Quick Load Device [Trigger]", invoke=function(message) if message:is_trigger() then showQuickLoadDialog() end end}
