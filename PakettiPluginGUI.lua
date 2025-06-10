function show_plugin_list_dialog()
    local vb = renoise.ViewBuilder()

    local checkboxes = {}
    local custom_dialog

    -- Fetch plugin and device information
    local instrument = renoise.song().selected_instrument
    local track_index = renoise.song().selected_track_index
    local available_plugins = instrument.plugin_properties.available_plugins
    local available_plugin_infos = instrument.plugin_properties.available_plugin_infos
    local available_devices = renoise.song().tracks[track_index].available_devices
    local available_device_infos = renoise.song().tracks[track_index].available_device_infos

    -- Prepare mappings for readable names
    local pluginReadableNames = {}
    for i, plugin_info in ipairs(available_plugin_infos) do
        pluginReadableNames[available_plugins[i]] = plugin_info.short_name
    end

    local deviceReadableNames = {}
    for i, device_info in ipairs(available_device_infos) do
        deviceReadableNames[available_devices[i]] = device_info.short_name
    end

    local categorized_plugins = {
        VST = {}, -- VST Effects
        AU = {}, -- AU Effects
        Native = {},
        SynthVST = {}, -- VST Instruments
        SynthAU = {} -- AU Instruments
    }

    -- Categorize plugins for instruments and devices for effects, then sort alphabetically
    function sortAndCategorizePlugins()
        for _, plugin in ipairs(available_plugins) do
            local name = pluginReadableNames[plugin] or plugin:match("([^/]+)$")
            if plugin:find("VSTi") or plugin:find("VST3") then
                table.insert(categorized_plugins.SynthVST, name)
            elseif plugin:find("aumf") or plugin:find("aumu") then
                table.insert(categorized_plugins.SynthAU, name)
            end
        end

        for _, device in ipairs(available_devices) do
            local name = deviceReadableNames[device] or device:match("([^/]+)$")
            if device:find("VST") then
                table.insert(categorized_plugins.VST, name)
            elseif device:find("AU") then
                table.insert(categorized_plugins.AU, name)
            elseif device:find("Native/") then
                table.insert(categorized_plugins.Native, name)
            end
        end

        for _, list in pairs(categorized_plugins) do
            table.sort(list)
        end
    end




    local pluginPathMap = {} -- Mapping table for short name to original path
    local auPluginPathMap = {} -- Dedicated map for AU plugins
    
    function populateMap()
    for i, plugin_info in ipairs(available_plugin_infos) do
        local shortName = plugin_info.short_name
        local originalPath = available_plugins[i] -- Assuming this is the full path or a unique identifier you need
        pluginPathMap[shortName] = originalPath
        print("Adding to pluginPathMap:", shortName, originalPath)
    end
    for i, device_info in ipairs(available_device_infos) do
        local shortName = device_info.short_name
        local originalPath = available_devices[i] -- Assuming this is the full path or a unique identifier you need
        pluginPathMap[shortName] = originalPath
        print("Adding to pluginPathMap:", shortName, originalPath)
    end


    end

-- Function to filter AU plugins and populate auPluginPathMap
function filterAUPlugins()
    for shortName, originalPath in pairs(pluginPathMap) do
        if string.find(originalPath, "AU") then
            auPluginPathMap[shortName] = originalPath
            print("Filtered AU Plugin:", shortName, originalPath)
        end
    end
end

    sortAndCategorizePlugins()
    populateMap()
    filterAUPlugins()

    function create_scrollable_plugin_list(title, plugins)
        local columns = {vb:vertical_aligner {mode = "top", spacing=2},
                         vb:vertical_aligner {mode = "top", spacing=2},
                         vb:vertical_aligner {mode = "top", spacing=2}} -- Three columns initialized

        local numColumns = title == "VST Effects" and 3 or 2

        for i, plugin_name in ipairs(plugins) do
            local target_column = columns[((i - 1) % numColumns) + 1]
            local checkbox = vb:checkbox{value = false, id = "checkbox_" .. title .. "_" .. tostring(i)}
            checkboxes[#checkboxes + 1] = {checkbox = checkbox, name = plugin_name, type = title}
            target_column:add_child(vb:row{
                checkbox,
                vb:text{text = plugin_name}
            })
        end

        local columnContainer = vb:row{}
        for i = 1, numColumns do
            columnContainer:add_child(columns[i])
        end

        return vb:column{
            margin=5,
            vb:text{text = title, font = "bold"},
            vb:row{
                style = "panel",
                height = 680, -- Adjusted height for effects
                width=title == "VST Effects" and 660 or 440, -- Adjusted width for VST Effects
                columnContainer
            }
        }
    end

    local plugin_lists = vb:row{
        margin=10,
        spacing=10,
        create_scrollable_plugin_list("VST Effects", categorized_plugins.VST),
        create_scrollable_plugin_list("AU Effects", categorized_plugins.AU),
        create_scrollable_plugin_list("Native", categorized_plugins.Native),
        create_scrollable_plugin_list("VST Instruments", categorized_plugins.SynthVST),
        create_scrollable_plugin_list("AU Instruments", categorized_plugins.SynthAU)
    }
    

    
    function loadSelectedPlugin()
        for _, cb_info in ipairs(checkboxes) do
            if cb_info.checkbox.value then
                local path = cb_info.name 
                local shortName = cb_info.name  -- This is the short name selected by the user
                  if cb_info.type == "AU Effects" then
                      if auPluginPathMap[shortName] then
                          local originalPath = auPluginPathMap[shortName]  -- Retrieve the original path
                          local pluginPath = originalPath
                          print("Attempting to load AU Effect:", pluginPath)  -- Debugging print
                          local loadResult = loadvst(pluginPath)  -- Assuming loadvst might return a success/failure status
                          if not loadResult then
                              print("Failed to load AU plugin:", pluginPath)
                          end
                      else
                          print("Original path not found for short name:", shortName)
                      end                               
                elseif cb_info.type == "VST Effects" then
                  local pluginPath = "Audio/Effects/" .. (cb_info.type == "VST Effects" and "VST/") .. path
                    print(pluginPath)
                    loadvst(pluginPath)
                elseif cb_info.type == "Native" then
                  local pluginPath = "Audio/Effects/" .. (cb_info.type == "Native" and "Native/") .. path
                    print (pluginPath)
                    loadnative(pluginPath)
                elseif cb_info.type == "VST Instruments" or cb_info.type == "AU Instruments" then
                    local instrumentIndex = renoise.song().selected_instrument_index
                    local pluginPath = "Audio/Generators/" .. (cb_info.type == "VST Instruments" and "VST/" or "AU/") .. path
                    print (pluginPath)
                    renoise.song().instruments[instrumentIndex].plugin_properties:load_plugin(pluginPath)
                    local pd = renoise.song().selected_instrument.plugin_properties.plugin_device
                    if not pd.external_editor_visible then
                        pd.external_editor_visible = true
                    end
                end
                break  -- Assuming only one plugin can be selected at a time for loading
            end
        end
    end

    local action_buttons = vb:horizontal_aligner{
        mode = "right",
        spacing=10,
        vb:button{
            text="Load Selected Plugin",
            notifier=function()
                loadSelectedPlugin()
            end
        },
        vb:button{
            text="Generate Shortcuts",
            notifier=function()
                local selected_plugins_text=""
                for _, cb_info in ipairs(checkboxes) do
                    if cb_info.checkbox.value then
                        selected_plugins_text = selected_plugins_text .. cb_info.name .. "\n"
                    end
                end
                
                custom_dialog:close()
                
                renoise.app():show_message("Selected Plugins:\n" .. selected_plugins_text)
            end
        },
        vb:button{
            text="Cancel",
            notifier=function() custom_dialog:close() end
        }
    }

    local dialog_content = vb:column{action_buttons, plugin_lists }
    custom_dialog = renoise.app():show_custom_dialog("Plugin List", dialog_content)
end

