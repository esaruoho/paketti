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
    local song=renoise.song()
    if song.selected_sample == nil or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample data available.")
        return
    end

    local temp_file_path = os.tmpname() .. ".wav"
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
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection1.value ~= "" and preferences.AppSelection.AppSelection1.value or "None"),
                    width=600,
                    font="bold", style="strong"}
                app_paths[1] = path
                return path
            end)()
        },
        vb:row{
            vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(2) end},
            vb:button{text="Send Selected Sample to App",notifier=function() saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection2.value) end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection2.value ~= "" and preferences.AppSelection.AppSelection2.value or "None"),
                    width=600,
                    font="bold",style="strong"}
                app_paths[2] = path
                return path
            end)()
        },
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(3) end},
            vb:button{text="Send Selected Sample to App",notifier=function() 
                    saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection3.value) end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection3.value ~= "" and preferences.AppSelection.AppSelection3.value or "None"),
                    width=600,
                    font="bold",style="strong"}
                app_paths[3] = path
                return path
            end)()},
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(4) end},
            vb:button{text="Send Selected Sample to App",
                notifier=function() 
                    saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection4.value) 
                end,width=200},
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection4.value ~= "" and preferences.AppSelection.AppSelection4.value or "None"),
                    width=600,
                    font="bold",style="strong"}
                app_paths[4] = path
                return path
            end)()},
        vb:row{vb:button{text="Browse",notifier=function() appSelectionBrowseForApp(5) end},
            vb:button{text="Send Selected Sample to App",
                notifier=function() saveSelectedSampleToTempAndOpen(preferences.AppSelection.AppSelection5.value) end, width=200
            },
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection5.value ~= "" and preferences.AppSelection.AppSelection5.value or "None"),
                    width=600,
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
            (function()
                local path = vb:text{
                    text=(preferences.AppSelection.AppSelection6.value ~= "" and preferences.AppSelection.AppSelection6.value or "None"),
                    width=600,
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

    dialog = renoise.app():show_custom_dialog("App Selection & Smart Folders / Backup Folders", create_dialog_content(function()
        dialog:close()
        appSelectionUpdateMenuEntries() 
    end), my_keyhandler_func)
end

for i=1, 6 do
  local app_path = preferences.AppSelection["AppSelection"..i].value
  -- Only create entries if app_path exists and isn't empty
  if app_path and app_path ~= "" then
      renoise.tool():add_keybinding{name="Global:Paketti:Send Selected Sample to AppSelection" .. i,
          invoke=function()
              saveSelectedSampleToTempAndOpen(app_path)
          end
      }
      renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Launch App:Send Selected Sample to AppSelection" .. i,
          invoke=function()
              saveSelectedSampleToTempAndOpen(app_path)
          end
      }
      renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Launch App:Send Selected Sample to AppSelection" .. i,
          invoke=function()
              saveSelectedSampleToTempAndOpen(app_path)
          end
      }

      renoise.tool():add_midi_mapping{name="Paketti:Send Selected Sample to AppSelection" .. i,
          invoke=function(message)
              if message:is_trigger() then 
                  saveSelectedSampleToTempAndOpen(app_path)
              end
          end
      }
  end
end

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
        renoise.app():show_custom_dialog("Set Smart Folder Path", create_dialog_content())
        return
    end

    local lsfvariable = nil
    lsfvariable = os.tmpname("wav")
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
        renoise.app():show_custom_dialog("Set Smart Folder Path", create_dialog_content())
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
  renoise.app():show_status("Launched app " .. app_path:match("([^/\\]+)%.app$"))
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
  for i, app_path in ipairs(app_selections) do
    if app_path ~= "" then
      apps_present = true
--      local app_name = app_path:match("([^/\\]+)%.app$")
local prefix = (i == 1) and "--" or ""  -- Add prefix only for first item
  
local app_name = app_path:match("([^/\\]+)%.app$") or app_path:match("([^/\\]+)$")
      local menu_entry_name = "Instrument Box:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,invoke=function() appSelectionLaunchApp(app_path) end}
        table.insert(added_menu_entries, menu_entry_name)
      end

      menu_entry_name = "Main Menu:Tools:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() appSelectionLaunchApp(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      menu_entry_name = "Sample Navigator:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() appSelectionLaunchApp(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
      end
      menu_entry_name = "Sample Editor:Paketti:Launch App:Launch App "..i.." "..app_name
      if not renoise.tool():has_menu_entry(menu_entry_name) then
        renoise.tool():add_menu_entry{name=menu_entry_name,
          invoke=function() appSelectionLaunchApp(app_path) end
        }
        table.insert(added_menu_entries, menu_entry_name)
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