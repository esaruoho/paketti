-- PakettiNotepadRun.lua
-- Execute Lua code stored in Notepad device paragraphs
-- Turns Notepad device into a runnable script container

-- Function to check if selected device is a Notepad device
function is_notepad_device(device)
  if device and device.device_path then
    return device.device_path == "Audio/Effects/Native/Notepad"
  end
  return false
end

-- Function to extract and execute Lua code from Notepad device
function pakettiNotepadRun()
  local song = renoise.song()
  local selected_device = song.selected_device
  
  -- Check if a Notepad device is selected
  if not selected_device or not is_notepad_device(selected_device) then
    renoise.app():show_status("PakettiNotepadRun: Please select a Notepad device first")
    print("PakettiNotepadRun: Error - No Notepad device selected")
    return
  end
  
  -- Get the XML data from the Notepad device
  local xml_data = selected_device.active_preset_data
  if not xml_data or xml_data == "" then
    renoise.app():show_status("PakettiNotepadRun: No content found in Notepad device")
    print("PakettiNotepadRun: Error - No XML data in Notepad device")
    return
  end
  
  print("=== PakettiNotepadRun: Parsing Notepad XML ===")
  print(xml_data)
  print("=== END XML ===")
  
  -- Extract all paragraph content from the XML
  local paragraphs = {}
  local paragraph_count = 0
  
  print("=== PakettiNotepadRun: Extracting Paragraphs ===")
  for paragraph_content in xml_data:gmatch("<Paragraph>([^<]*)</Paragraph>") do
    paragraph_count = paragraph_count + 1
    table.insert(paragraphs, paragraph_content)
    print(string.format("Paragraph %d: %s", paragraph_count, paragraph_content))
  end
  print("=== END Extracting Paragraphs ===")
  
  if paragraph_count == 0 then
    renoise.app():show_status("PakettiNotepadRun: No paragraphs found in Notepad device")
    print("PakettiNotepadRun: No paragraphs to execute")
    return
  end
  
  print(string.format("PakettiNotepadRun: Found %d paragraphs to execute", paragraph_count))
  
  -- Execute each paragraph as Lua code
  local executed_count = 0
  local error_count = 0
  
  print("=== PakettiNotepadRun: Executing Paragraphs ===")
  for i, lua_code in ipairs(paragraphs) do
    -- Skip empty paragraphs
    if lua_code and lua_code:match("%S") then
      print(string.format("Executing paragraph %d: %s", i, lua_code))
      
      -- Try to load and execute the Lua code
      local success, result = pcall(function()
        local func, load_error = loadstring(lua_code)
        if func then
          return func()
        else
          error("Load error: " .. tostring(load_error))
        end
      end)
      
      if success then
        executed_count = executed_count + 1
        print(string.format("Paragraph %d executed successfully", i))
        if result then
          print(string.format("   Result: %s", tostring(result)))
        end
      else
        error_count = error_count + 1
        print(string.format("Paragraph %d failed: %s", i, tostring(result)))
      end
    else
      print(string.format("Skipping empty paragraph %d", i))
    end
  end
  print("=== END Executing Paragraphs ===")
  
  -- Show summary (only print to console, don't interfere with user's status messages)
  local status_message = string.format("PakettiNotepadRun: Executed %d/%d paragraphs", executed_count, paragraph_count)
  if error_count > 0 then
    status_message = status_message .. string.format(" (%d errors)", error_count)
    -- Only show status if there were errors
    renoise.app():show_status(status_message)
  end
  
  print(status_message)
  print("PakettiNotepadRun: Complete!")
end

renoise.tool():add_keybinding{name = "Global:Paketti:Run Notepad Device Code", invoke = pakettiNotepadRun}
renoise.tool():add_midi_mapping{name = "Paketti:Run Notepad Device Code", invoke = function(message) if message:is_trigger() then pakettiNotepadRun() end  end}

