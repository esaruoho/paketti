local dialog = nil
local dialog_content = nil
local vb = renoise.ViewBuilder()

local app_paths = {}
local smart_folder_paths = {}

-- Function to browse for an app and update the corresponding field
function appSelectionBrowseForApp(index)
    local file_extensions = {"*.*"}
    local dialog_title = "Select an Application"

    local selected_file = renoise.app():prompt_for_filename_to_read(file_extensions, dialog_title)
    if selected_file ~= "" then
        -- Detect the operating system
        local os_name = os.platform()
        if os_name == "WINDOWS" then
            -- Replace backslashes with double backslashes for Windows paths
            selected_file = string.gsub(selected_file, "\\", "\\\\")
        end
        preferences.AppSelection["AppSelection"..index].value = selected_file
        if app_paths[index] then
            app_paths[index].text = selected_file
        end
        renoise.app():show_status("Selected file: " .. selected_file)
    else
        renoise.app():show_status("No file selected")
    end
end

-- Function to browse for a smart folder and update the corresponding field
function browseForSmartFolder(index)
    local dialog_title = "Select a Smart Folder / Backup Folder"

    local selected_folder = renoise.app():prompt_for_path(dialog_title)
    if selected_folder ~= "" then
        preferences.AppSelection["SmartFoldersApp"..index].value = selected_folder
        if smart_folder_paths[index] then
            smart_folder_paths[index].text = selected_folder
        end
        renoise.app():show_status("Selected folder: " .. selected_folder)
    else
        renoise.app():show_status("No folder selected")
    end
end

-- Function to save selected sample to temp and open with the selected app
function saveSelectedSampleToTempAndOpen(app_path)
    if renoise.song() == nil then return end
    
    -- Check if app path is valid
    if app_path == nil or app_path == "" or app_path == "None" then
        renoise.app():show_status("No application selected. Please configure an app first.")
        return
    end
    
    local song=renoise.song()
    if song.selected_sample == nil or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample data available.")
        return
    end

    -- Use sample name with -tmpSave before .wav extension
    local sample_name = song.selected_sample.name
    if sample_name == "" then
        sample_name = "UnnamedSample"
    end
    -- Remove any existing .wav extension and add -tmpSave.wav
    sample_name = sample_name:gsub("%.wav$", "")
    local temp_file_path = pakettiGetTempFilePath(".wav"):gsub("[^/\\]*[^/\\]*$", sample_name .. "-tmpSave.wav")
    song.selected_sample.sample_buffer:save_as(temp_file_path, "wav")
    
    -- Detect the operating system
    local os_name = os.platform()
    local command

    if os_name == "WINDOWS" then
        command = 'start "" "' .. app_path .. '" "' .. temp_file_path .. '"'
    elseif os_name == "MACINTOSH" then
        command = 'open -a "' .. app_path .. '" "' .. temp_file_path .. '"'
    else
        command = 'exec "' .. app_path .. '" "' .. temp_file_path .. '" &'
    end

    os.execute(command)
    renoise.app():show_status("Sample sent to " .. app_path)
end

-- Function to save selected sample range to temp and open with the selected app
function saveSelectedSampleRangeToTempAndOpen(app_path)
    if renoise.song() == nil then return end
    
    -- Check if app path is valid
    if app_path == nil or app_path == "" or app_path == "None" then
        renoise.app():show_status("No application selected. Please configure an app first.")
        return
    end
    
    local song = renoise.song()
    local selected_sample = song.selected_sample
    
    if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample data available.")
        return
    end
    
    local sample_buffer = selected_sample.sample_buffer
    
    -- Check if there's a valid selection range
    if not sample_buffer.selection_range or #sample_buffer.selection_range < 2 then
        renoise.app():show_status("No valid selection range found. Please select a range in the sample editor.")
        return
    end
    
    local selection_start = sample_buffer.selection_range[1]
    local selection_end = sample_buffer.selection_range[2]
    
    -- Check if selection is valid
    if selection_start == selection_end then
        renoise.app():show_status("No selection range is defined. Please select a range in the sample editor.")
        return
    end
    
    -- Create a temporary instrument and sample to hold the range
    local original_instrument_index = song.selected_instrument_index
    local new_instrument = song:insert_instrument_at(#song.instruments + 1)
    local new_sample = new_instrument:insert_sample_at(1)
    
    -- Create new sample buffer with the selection range data
    new_sample.sample_buffer:create_sample_data(
        sample_buffer.sample_rate,
        sample_buffer.bit_depth,
        sample_buffer.number_of_channels,
        selection_end - selection_start + 1
    )
    
    new_sample.sample_buffer:prepare_sample_data_changes()
    
    -- Copy the selection range to the new sample buffer
    for c = 1, sample_buffer.number_of_channels do
        for f = selection_start, selection_end do
            new_sample.sample_buffer:set_sample_data(c, f - selection_start + 1, sample_buffer:sample_data(c, f))
        end
    end
    
    new_sample.sample_buffer:finalize_sample_data_changes()
    
    -- Save the range to a temporary file using sample name with -tmpSave before .wav extension
    local sample_name = selected_sample.name
    if sample_name == "" then
        sample_name = "UnnamedSample"
    end
    -- Remove any existing .wav extension and add -tmpSave.wav
    sample_name = sample_name:gsub("%.wav$", "")
    local temp_file_path = pakettiGetTempFilePath(".wav"):gsub("[^/\\]*[^/\\]*$", sample_name .. "-tmpSave.wav")
    new_sample.sample_buffer:save_as(temp_file_path, "wav")
    
    -- Clean up: delete the temporary instrument and reselect original instrument
    song:delete_instrument_at(#song.instruments)
    song.selected_instrument_index = original_instrument_index
    
    -- Detect the operating system and launch the app
    local os_name = os.platform()
    local command

    if os_name == "WINDOWS" then
        command = 'start "" "' .. app_path .. '" "' .. temp_file_path .. '"'
    elseif os_name == "MACINTOSH" then
        command = 'open -a "' .. app_path .. '" "' .. temp_file_path .. '"'
    else
        command = 'exec "' .. app_path .. '" "' .. temp_file_path .. '" &'
    end

    os.execute(command)
    
    local selection_length = selection_end - selection_start + 1
    local duration_ms = (selection_length / sample_buffer.sample_rate) * 1000
    renoise.app():show_status(string.format("Sample range sent to %s (frames %d-%d, %.1fms)", 
        app_path, selection_start, selection_end, duration_ms))
end

-- Create the dialog UI
local function create_dialog_content(closeLA_dialog)
    app_paths = {}
    smart_folder_paths = {}

    return vb:column{
        style="group",
        width=900,
        vb:row{vb:text{text="App Selection", font="bold", style="strong"}},
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(1) end},
            vb:button{text="Send Selected Sample to App",
                notifier=function() saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection1.value) 
                end,
                width=200},
            vb:button{text="Send Sample Range to App",
                notifier=function() saveSelectedSampleRangeToTempAndOpen(preferences.AppSelection.AppSelection1.value) 
                end,
                width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection1.value ~= "" and preferences.AppSelection.AppSelection1.value or "None"),
                    width=400,
                    font="bold", style="strong"}
                app_paths[1] = path
                return path
            end)()
        },
        vb:row{
            vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(2) end},
            vb:button{text="Send Selected Sample to App",notifier=function() saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection2.value) end,width=200},
            vb:button{text="Send Sample Range to App",notifier=function() saveSelectedSampleRangeToTempAndOpen(preferences.AppSelection.AppSelection2.value) end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection2.value ~= "" and preferences.AppSelection.AppSelection2.value or "None"),
                    width=400,
                    font="bold",style="strong"}
                app_paths[2] = path
                return path
            end)()
        },
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(3) end},
            vb:button{text="Send Selected Sample to App",notifier=function() 
                    saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection3.value) end,width=200},
            vb:button{text="Send Sample Range to App",notifier=function() 
                    saveSelectedSampleRangeToTempAndOpen(preferences.AppSelection.AppSelection3.value) end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection3.value ~= "" and preferences.AppSelection.AppSelection3.value or "None"),
                    width=400,
                    font="bold",style="strong"}
                app_paths[3] = path
                return path
            end)()},
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(4) end},
            vb:button{text="Send Selected Sample to App",
                notifier=function() 
                    saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection4.value) 
                end,width=200},
            vb:button{text="Send Sample Range to App",
                notifier=function() 
                    saveSelectedSampleRangeToTempAndOpen(preferences.AppSelection.AppSelection4.value) 
                end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection4.value ~= "" and preferences.AppSelection.AppSelection4.value or "None"),
                    width=400,
                    font="bold",style="strong"}
                app_paths[4] = path
                return path
            end)()},
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(5) end},
            vb:button{text="Send Selected Sample to App",
                notifier=function() saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection5.value) end, width=200
            },
            vb:button{text="Send Sample Range to App",
                notifier=function() saveSelectedSampleRangeToTempAndOpen(preferences.AppSelection.AppSelection5.value) end, width=200
            },
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection5.value ~= "" and preferences.AppSelection.AppSelection5.value or "None"),
                    width=400,
                    font="bold",style="strong"}
                app_paths[5] = path
                return path
            end)()},
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(6) end},
            vb:button{
                text="Send Selected Sample to App",
                notifier=function() 
                    saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection6.value) 
                end,
                width=200},
            vb:button{
                text="Send Sample Range to App",
                notifier=function() 
                    saveSelectedSampleRangeToTempAndOpen(preferences.AppSelection.AppSelection6.value) 
                end,
                width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection6.value ~= "" and preferences.AppSelection.AppSelection6.value or "None"),
                    width=400,
                    font="bold",style="strong"}
                app_paths[6] = path
                return path
            end)()
        },
        vb:row{vb:text{text="Smart Folders / Backup Folders", font="bold", style="strong"}},
        vb:row{
            vb:button{text="Browse",notifier=function() browseForSmartFolder(1) end},
            vb:button{text="Save Selected Sample to Folder",notifier=function() saveSampleToSmartFolder(1) end,width=200},
            vb:button{text="Save All Samples to Folder",notifier=function() saveSamplesToSmartFolder(1) end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.SmartFoldersApp1.value ~= "" and preferences.AppSelection.SmartFoldersApp1.value or "None"),
                    width=600,font="bold", style="strong"}
                smart_folder_paths[1] = path
                return path
            end)()
        },
        vb:row{vb:button{text="Browse",notifier=function() browseForSmartFolder(2) end},
            vb:button{text="Save Selected Sample to Folder",
                notifier=function() 
                    saveSampleToSmartFolder(2) 
                end,
                width=200},
            vb:button{
                text="Save All Samples to Folder",
                notifier=function() 
                    saveSamplesToSmartFolder(2) 
                end,
                width=200
            },
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.SmartFoldersApp2.value ~= "" and preferences.AppSelection.SmartFoldersApp2.value or "None"),
                    width=600,font="bold",style="strong"}
                smart_folder_paths[2] = path
                return path
            end)()
        },
        vb:row{
        
            vb:button{
                text="Browse",
                notifier=function() browseForSmartFolder(3) end
            },
            vb:button{text="Save Selected Sample to Folder",notifier=function() saveSampleToSmartFolder(3) end,width=200},
            vb:button{text="Save All Samples to Folder",notifier=function() saveSamplesToSmartFolder(3) end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.SmartFoldersApp3.value ~= "" and preferences.AppSelection.SmartFoldersApp3.value or "None"),
                    width=600,font="bold",style="strong"}
                smart_folder_paths[3] = path
                return path
            end)()
        },
        vb:button{text="OK",notifier=function()
                appSelectionUpdateMenuEntries()
                dialog:close()
                dialog = nil
            end
        }
    }
end

function pakettiAppSelectionDialog()
    if dialog and dialog.visible then 
        dialog:close()
        dialog = nil
        return
    end    

    local keyhandler = create_keyhandler_for_dialog(
        function() return dialog end,
        function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("App Selection & Smart Folders / Backup Folders", create_dialog_content(function()
        dialog:close()
        appSelectionUpdateMenuEntries() 
    end), keyhandler)
end

-- Static keybindings and MIDI mappings moved to dynamic creation in appSelectionCreateMenuEntries()

for i=1, 3 do
    renoise.tool():add_keybinding{name="Global:Paketti:Save Sample to Smart/Backup Folder " .. i,invoke=function() saveSampleToSmartFolder(i) end}
    renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Save:Save Sample to Smart/Backup Folder " .. i,invoke=function() saveSampleToSmartFolder(i) end}
    renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Save:Save Sample to Smart/Backup Folder " .. i,invoke=function() saveSampleToSmartFolder(i) end}
    renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Save:Save Sample to Smart/Backup Folder " .. i,invoke=function() saveSampleToSmartFolder(i) end}
    renoise.tool():add_midi_mapping{name="Paketti:Save Sample to Smart/Backup Folder " .. i,invoke=function(message) if message:is_trigger() then saveSampleToSmartFolder(i) end end}
end

for i=1, 3 do
    renoise.tool():add_keybinding{name="Global:Paketti:Save All Samples to Smart/Backup Folder " .. i,invoke=function() saveSamplesToSmartFolder(i) end}
    renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Save:Save All Samples to Smart/Backup Folder " .. i,invoke=function() saveSamplesToSmartFolder(i) end}
    renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Save:Save All Samples to Smart/Backup Folder " .. i,invoke=function() saveSamplesToSmartFolder(i) end}
    renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Save:Save All Samples to Smart/Backup Folder " .. i,invoke=function() saveSamplesToSmartFolder(i) end}
    renoise.tool():add_midi_mapping{name="Paketti:Save All Samples to Smart/Backup Folder " .. i,invoke=function(message)
    if message:is_trigger() then saveSamplesToSmartFolder(i) end end}
end

----------------
-- Function to save selected sample to the specified Smart Folder
function saveSampleToSmartFolder(index)
    local smart_folder_path = preferences.AppSelection["SmartFoldersApp"..index].value
    if smart_folder_path == "" then
        renoise.app():show_status("Please set the Smart Folder path for " .. index)
        local keyhandler = create_keyhandler_for_dialog()
        renoise.app():show_custom_dialog("Set Smart Folder Path", create_dialog_content(), keyhandler)
        return
    end

    local lsfvariable = nil
    lsfvariable = pakettiGetTempFilePath(".wav")
    local path = smart_folder_path .. "/"
    local s = renoise.song()
    local instboxname = s.selected_instrument.name

    if not s.selected_sample or not s.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample data available.")
        return
    end

    local sample = s.selected_sample.sample_buffer
    local file_name = instboxname .. ".wav"
    
    if sample.bit_depth == 32 then
        -- local temp_sample = sample:clone()
        -- temp_sample.bit_depth = 24
        -- temp_sample:save_as(path .. file_name, "wav")
        sample:save_as(path .. file_name, "wav")
    else
        sample:save_as(path .. file_name, "wav")
    end
    renoise.app():show_status("Saved " .. file_name .. " to Smart Folder " .. path)
end

-- Function to save all samples to the specified Smart Folder
function saveSamplesToSmartFolder(index)
    local smart_folder_path = preferences.AppSelection["SmartFoldersApp"..index].value
    if smart_folder_path == "" then
        renoise.app():show_status("Please set the Smart Folder path for " .. index)
        local keyhandler = create_keyhandler_for_dialog()
        renoise.app():show_custom_dialog("Set Smart Folder Path", create_dialog_content(), keyhandler)
        return
    end

    local s = renoise.song()
    local path = smart_folder_path .. "/"
    local saved_samples_count = 0

    for i = 1, #s.instruments do
        local instrument = s.instruments[i]
        if instrument and #instrument.samples > 0 then
            for j = 1, #instrument.samples do
                local sample = instrument.samples[j].sample_buffer
                if sample.has_sample_data then
                    local file_name = instrument.name .. "_" .. j .. ".wav"
                    if sample.bit_depth == 32 then
                        -- local temp_sample = sample:clone()
                        -- temp_sample.bit_depth = 24
                        -- temp_sample:save_as(path .. file_name, "wav")
                        sample:save_as(path .. file_name, "wav")
                    else
                        sample:save_as(path .. file_name, "wav")
                    end
                    saved_samples_count = saved_samples_count + 1
                end
            end
        end
    end

    renoise.app():show_status("Saved " .. saved_samples_count .. " samples to Smart Folder " .. path)
     -- Open the folder in system's file explorer
     local os_name = os.platform()
     if os_name == "WINDOWS" then
         os.execute('explorer "' .. smart_folder_path .. '"')
     elseif os_name == "MACINTOSH" then 
         os.execute('open "' .. smart_folder_path .. '"')
     else -- Linux/Unix systems
         os.execute('xdg-open "' .. smart_folder_path .. '"')
     end
end


------
-- Table to keep track of added menu entries
local added_menu_entries = {}

-- Global function to launch the applications
function appSelectionLaunchApp(app_path)
  local os_name = os.platform()
  local command

  if os_name == "WINDOWS" then
    command = 'start "" "' .. app_path .. '"'
  elseif os_name == "MACINTOSH" then
    command = 'open -a "' .. app_path .. '"'
  else
    command = 'exec "' .. app_path .. '" &'
  end

  os.execute(command)
  -- Extract app name from path, handling different platforms
  local app_name = app_path:match("([^/\\]+)%.app$") or app_path:match("([^/\\]+)$") or app_path
  renoise.app():show_status("Launched app " .. app_name)
end

function appSelectionRemoveMenuEntries()
  for _, entry in ipairs(added_menu_entries) do
    if renoise.tool():has_menu_entry(entry) then
      renoise.tool():remove_menu_entry(entry)
    end
  end
  -- Clear the tracking table
  added_menu_entries = {}
end
function appSelectionCreateMenuEntries()
  local preferences = renoise.tool().preferences
  
  -- Safety check: ensure AppSelection preferences exist
  if not preferences.AppSelection then
    print("WARNING: AppSelection preferences not found, skipping menu creation")
    return
  end
  
  local app_selections = {
    preferences.AppSelection.AppSelection1 and preferences.AppSelection.AppSelection1.value or "",
    preferences.AppSelection.AppSelection2 and preferences.AppSelection.AppSelection2.value or "",
    preferences.AppSelection.AppSelection3 and preferences.AppSelection.AppSelection3.value or "",
    preferences.AppSelection.AppSelection4 and preferences.AppSelection.AppSelection4.value or "",
    preferences.AppSelection.AppSelection5 and preferences.AppSelection.AppSelection5.value or "",
    preferences.AppSelection.AppSelection6 and preferences.AppSelection.AppSelection6.value or ""
  }

  local apps_present = false

  -- Create menu entries for each app selection
  -- First pass: Add "Send Selected Sample" entries with dynamic names
  for i, app_path in ipairs(app_selections) do
    if app_path ~= "" then
      apps_present = true
      local app_name = app_path:match("([^/\\]+)%.app$") or app_path:match("([^/\\]+)$") or app_path
      
      -- Send Selected Sample entries (with dynamic app names)
      local menu_entry_name = "Instrument Box:Paketti:Launch App:Send Selected Sample to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,invoke=function() saveSelectedSampleToTempAndOpen(app_path) end}
        table.insert(added_menu_entries, menu_entry_name)
      end

      menu_entry_name = "Main Menu:Tools:Paketti:Launch App:Send Selected Sample to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() saveSelectedSampleToTempAndOpen(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      menu_entry_name = "Sample Navigator:Paketti:Launch App:Send Selected Sample to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() saveSelectedSampleToTempAndOpen(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      menu_entry_name = "Sample Editor:Paketti:Launch App:Send Selected Sample to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() saveSelectedSampleToTempAndOpen(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      -- Dynamic keybindings and MIDI mappings for Send Selected Sample
      local keybinding_name = "Global:Paketti:Send Selected Sample to App "..i.." "..app_name
      if not renoise.tool():has_keybinding(keybinding_name) then
        renoise.tool():add_keybinding{name=keybinding_name,
            invoke=function()
                saveSelectedSampleToTempAndOpen(app_path)
            end
        }
      end
      
      local midi_mapping_name = "Paketti:Send Selected Sample to App "..i.." "..app_name
      if not renoise.tool():has_midi_mapping(midi_mapping_name) then
        renoise.tool():add_midi_mapping{name=midi_mapping_name,
            invoke=function(message)
                if message:is_trigger() then 
                    saveSelectedSampleToTempAndOpen(app_path)
                end
            end
        }
      end
    end
  end
  
  -- Second pass: Add "Send Selected Sample Range" entries with separators
  for i, app_path in ipairs(app_selections) do
    if app_path ~= "" then
      local app_name = app_path:match("([^/\\]+)%.app$") or app_path:match("([^/\\]+)$") or app_path
      local prefix = (i == 1) and "--" or ""  -- Add separator only for first range item
      
      -- Send Selected Sample Range entries
      local menu_entry_name = prefix.."Instrument Box:Paketti:Launch App:Send Selected Sample Range to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,invoke=function() saveSelectedSampleRangeToTempAndOpen(app_path) end}
        table.insert(added_menu_entries, menu_entry_name)
      end

      menu_entry_name = prefix.."Main Menu:Tools:Paketti:Launch App:Send Selected Sample Range to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() saveSelectedSampleRangeToTempAndOpen(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      menu_entry_name = prefix.."Sample Navigator:Paketti:Launch App:Send Selected Sample Range to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() saveSelectedSampleRangeToTempAndOpen(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      menu_entry_name = prefix.."Sample Editor:Paketti:Launch App:Send Selected Sample Range to App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() saveSelectedSampleRangeToTempAndOpen(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      -- Dynamic keybindings and MIDI mappings for Send Selected Sample Range
      local keybinding_name = "Global:Paketti:Send Selected Sample Range to App "..i.." "..app_name
      if not renoise.tool():has_keybinding(keybinding_name) then
        renoise.tool():add_keybinding{name=keybinding_name,
            invoke=function()
                saveSelectedSampleRangeToTempAndOpen(app_path)
            end
        }
      end
      
      local midi_mapping_name = "Paketti:Send Selected Sample Range to App "..i.." "..app_name
      if not renoise.tool():has_midi_mapping(midi_mapping_name) then
        renoise.tool():add_midi_mapping{name=midi_mapping_name,
            invoke=function(message)
                if message:is_trigger() then 
                    saveSelectedSampleRangeToTempAndOpen(app_path)
                end
            end
        }
      end
    end
  end
  
  -- Third pass: Add "Launch App" entries with separators
  for i, app_path in ipairs(app_selections) do
    if app_path ~= "" then
      local app_name = app_path:match("([^/\\]+)%.app$") or app_path:match("([^/\\]+)$") or app_path
      local prefix = (i == 1) and "--" or ""  -- Add separator only for first launch item
      
      -- Launch App entries
      local menu_entry_name = prefix.."Instrument Box:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,invoke=function() appSelectionLaunchApp(app_path) end}
        table.insert(added_menu_entries, menu_entry_name)
      end

      menu_entry_name = prefix.."Main Menu:Tools:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() appSelectionLaunchApp(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      menu_entry_name = prefix.."Sample Navigator:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() appSelectionLaunchApp(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      menu_entry_name = prefix.."Sample Editor:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() appSelectionLaunchApp(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      
      -- Dynamic keybindings and MIDI mappings for Launch App
      local keybinding_name = "Global:Paketti:Launch App "..i.." "..app_name
      if not renoise.tool():has_keybinding(keybinding_name) then
        renoise.tool():add_keybinding{name=keybinding_name,
            invoke=function()
                appSelectionLaunchApp(app_path)
            end
        }
      end
      
      local midi_mapping_name = "Paketti:Launch App "..i.." "..app_name
      if not renoise.tool():has_midi_mapping(midi_mapping_name) then
        renoise.tool():add_midi_mapping{name=midi_mapping_name,
            invoke=function(message)
                if message:is_trigger() then 
                    appSelectionLaunchApp(app_path)
                end
            end
        }
      end
    end
  end

  -- If no app selections are set, show the app selection dialog
  if not apps_present then
    renoise.app():show_status("No apps have been configured in Paketti:Launch App:Configure Launch App Selection, cannot populate Menu.")
  end

  local configure_entry_name="--Instrument Box:Paketti:Launch App:Configure Launch App Selection..."
  if not renoise.tool():has_menu_entry(configure_entry_name) then
    renoise.tool():add_menu_entry{name=configure_entry_name,
      invoke=pakettiAppSelectionDialog
    }
    table.insert(added_menu_entries, configure_entry_name)
  end

  configure_entry_name="--Main Menu:Tools:Paketti:Launch App:Configure Launch App Selection..."
  if not renoise.tool():has_menu_entry(configure_entry_name) then
    renoise.tool():add_menu_entry{name=configure_entry_name,
      invoke=pakettiAppSelectionDialog
    }
    table.insert(added_menu_entries, configure_entry_name)
  end

  configure_entry_name="--Sample Navigator:Paketti:Launch App:Configure Launch App Selection..."
  if not renoise.tool():has_menu_entry(configure_entry_name) then
    renoise.tool():add_menu_entry{name=configure_entry_name,
      invoke=pakettiAppSelectionDialog
    }
    table.insert(added_menu_entries, configure_entry_name)
  end  
  configure_entry_name="--Sample Editor:Paketti:Launch App:Configure Launch App Selection..."
  if not renoise.tool():has_menu_entry(configure_entry_name) then
    renoise.tool():add_menu_entry{name=configure_entry_name,
      invoke=pakettiAppSelectionDialog
    }
    table.insert(added_menu_entries, configure_entry_name)
  end 
end

renoise.tool():add_keybinding{name="Global:Paketti:Configure Launch App Selection...",invoke=pakettiAppSelectionDialog}

function appSelectionUpdateMenuEntries()
  if renoise.song() == nil then return end
  appSelectionRemoveMenuEntries()
  appSelectionCreateMenuEntries()
end

-- Idle notifier function
local function handle_idle_notifier()
  if renoise.song() then
    appSelectionUpdateMenuEntries()
    -- Remove this notifier to prevent repeated execution
    renoise.tool().app_idle_observable:remove_notifier(handle_idle_notifier)
  end
end

-- Ensure menu entries are created only after renoise.song() is initialized
local function handle_new_document()
  if not renoise.tool().app_idle_observable:has_notifier(handle_idle_notifier) then
    renoise.tool().app_idle_observable:add_notifier(handle_idle_notifier)
  end
end

renoise.tool().app_new_document_observable:add_notifier(handle_new_document)

-- Ensure menu entries are created only after renoise.song() is initialized (initial load)
if not renoise.tool().app_idle_observable:has_notifier(handle_idle_notifier) then
  renoise.tool().app_idle_observable:add_notifier(handle_idle_notifier)
end