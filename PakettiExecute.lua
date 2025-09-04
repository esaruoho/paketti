-- PakettiExecute.lua
-- External Application Execution Manager
-- Provides a dialog to configure and execute external applications with arguments

local vb = renoise.ViewBuilder()
local dialog = nil

-- Cross-platform command execution
function PakettiExecuteSafeCommand(app_path, arguments)
  if not app_path or app_path == "" then
    renoise.app():show_status("No application specified")
    return false
  end
  
  local os_name = os.platform()
  local command = ""
  
  -- Handle arguments
  local args = arguments or ""
  
  -- Cross-platform path and argument handling
  if os_name == "WINDOWS" then
    -- On Windows, wrap paths with spaces in quotes
    if app_path:find(" ") and not (app_path:sub(1,1) == '"' and app_path:sub(-1,-1) == '"') then
      command = 'start "" "' .. app_path .. '"'
    else
      command = 'start "" "' .. app_path .. '"'
    end
    
    -- Add arguments if provided
    if args ~= "" then
      command = command .. " " .. args
    end
  elseif os_name == "MACINTOSH" then
    -- On macOS, handle .app bundles and regular executables following PakettiLaunchApp pattern
    if app_path:match("%.app/?$") then
      -- For .app bundles, use open -a with the full app path
      command = 'open -a "' .. app_path .. '"'
      
      -- Add arguments if provided (open -a handles them with --args)
      if args ~= "" then
        command = command .. " --args " .. args
      end
    else
      -- Regular executable on macOS
      command = 'exec "' .. app_path .. '"'
      
      -- Add arguments if provided
      if args ~= "" then
        command = command .. " " .. args
      end
    end
    
    -- Add background execution for macOS
    command = command .. " &"
  else
    -- On Linux, escape spaces and special characters
    command = 'exec "' .. app_path .. '"'
    
    -- Add arguments if provided
    if args ~= "" then
      command = command .. " " .. args
    end
    
    -- Add background execution for Linux
    command = command .. " &"
  end
  
  print("PakettiExecute: Executing command: " .. command)
  
  -- Execute the command
  local success = os.execute(command)
  
  if success then
    renoise.app():show_status("Command executed successfully")
    return true
  else
    renoise.app():show_status("Command execution failed")
    return false
  end
end

-- Execute a specific application slot
function PakettiExecuteRunSlot(slot_number)
  if not slot_number or slot_number < 1 or slot_number > 10 then
    renoise.app():show_status("Invalid slot number")
    return
  end
  
  local app_key = string.format("App%02d", slot_number)
  local arg_key = string.format("App%02dArgument", slot_number)
  
  local app_path = PakettiExecute[app_key].value
  local arguments = PakettiExecute[arg_key].value
  
  if app_path == "" then
    renoise.app():show_status("No application configured for slot " .. slot_number)
    return
  end
  
  PakettiExecuteSafeCommand(app_path, arguments)
end

-- Create the Execute Applications dialog
function PakettiExecuteShowDialog()
  if dialog and dialog.visible then
    dialog:close()
    return
  end
  
      local dialog_content = vb:column{
    }
  
  -- Create 10 rows for applications
  for i = 1, 10 do
    local app_key = string.format("App%02d", i)
    local arg_key = string.format("App%02dArgument", i)
    local app_textfield_id = "app_textfield_" .. i
    local arg_textfield_id = "arg_textfield_" .. i
    
    local app_row = vb:row{
      spacing = 5,
      vb:text{
        text = string.format("App %02d", i),
        width = 50,style="strong",font="bold"
      },
      vb:textfield{
        id = app_textfield_id,
        text = PakettiExecute[app_key].value,
        width = 300,
        tooltip = "Path to executable application",
        notifier = function(text)
          PakettiExecute[app_key].value = text
          renoise.tool().preferences:save_as("preferences.xml")
        end
      },
      vb:button{
        text = "Browse",
        width = 60,
        notifier = function()
          local extensions = {"*"}
          if os.platform() == "WINDOWS" then
            extensions = {"*.exe", "*.bat", "*.cmd"}
          elseif os.platform() == "MACINTOSH" then
            extensions = {"*.app", "*"}
          end
          
          local file_path = renoise.app():prompt_for_filename_to_read(
            extensions, 
            "Select Application for Slot " .. i
          )
          
          if file_path and file_path ~= "" then
            PakettiExecute[app_key].value = file_path
            -- Update the textfield directly using the ID
            vb.views[app_textfield_id].text = file_path
            renoise.tool().preferences:save_as("preferences.xml")
            renoise.app():show_status("Selected application: " .. file_path)
          else
            renoise.app():show_status("No application selected")
          end
        end
      },
      vb:text{
        text = "Args",
        width = 35,style="strong",font="bold"
      },
      vb:textfield{
        id = arg_textfield_id,
        text = PakettiExecute[arg_key].value,
        width = 200,
        tooltip = "Command line arguments",
        notifier = function(text)
          PakettiExecute[arg_key].value = text
          renoise.tool().preferences:save_as("preferences.xml")
        end
      },
      vb:button{
        text = "Run",
        width = 50,
        notifier = function()
          PakettiExecuteRunSlot(i)
        end
      }
    }
    
    dialog_content:add_child(app_row)
    
    -- Add some spacing between rows
    if i < 10 then
      dialog_content:add_child(vb:space{height = 5})
    end
  end
  
  -- Add control buttons at the bottom
  dialog_content:add_child(vb:space{height = 15})
  dialog_content:add_child(
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          dialog:close()
        end
      }
    }
  )
  
  dialog = renoise.app():show_custom_dialog(
    "Paketti Execute", 
    dialog_content, 
    my_keyhandler_func
  )
  
  -- Ensure Renoise gets keyboard focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Menu entries and keybindings
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:!Execute Applications...",
  invoke = PakettiExecuteShowDialog
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Execute Applications Dialog",
  invoke = PakettiExecuteShowDialog
}

-- Individual slot execution keybindings
for i = 1, 10 do
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Execute Application Slot " .. string.format("%02d", i),
    invoke = function() PakettiExecuteRunSlot(i) end
  }
end

print("PakettiExecute.lua loaded successfully")
