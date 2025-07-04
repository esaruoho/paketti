-- Paketti CCizer Loader Dialog
-- Scans ccizer folder and allows selection/loading of MIDI control configuration files

local dialog = nil
local separator = package.config:sub(1,1)
local bottomButtonWidth = 120
local MAX_CC_LIMIT = 35 -- Maximum CC mappings for MIDI Control device

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
    
    -- Sort files alphabetically
    table.sort(files, function(a, b) return a.display_name:lower() < b.display_name:lower() end)
    
    return files
end

-- Load and parse a CCizer file
local function load_ccizer_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        renoise.app():show_error("Cannot open CCizer file: " .. filepath)
        return nil
    end
    
    local mappings = {}
    local line_count = 0
    local valid_cc_count = 0
    
    for line in file:lines() do
        line_count = line_count + 1
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace
        
        if line and line ~= "" and not line:match("^#") then -- Skip empty lines and comments
            -- Check for Pitchbend first
            local pb_name = line:match("^PB%s+(.+)$")
            if pb_name then
                valid_cc_count = valid_cc_count + 1
                
                -- Check if we're exceeding the MIDI Control device limit
                if valid_cc_count > MAX_CC_LIMIT then
                    print(string.format("-- CCizer: Warning - CC mapping #%d exceeds MIDI Control device limit of %d CCs, ignoring excess mappings", valid_cc_count, MAX_CC_LIMIT))
                    break
                end
                
                table.insert(mappings, {
                    cc = -1,
                    name = pb_name,
                    type = "PB"
                })
                print(string.format("-- CCizer: Valid PB mapping #%d: PB -> %s", valid_cc_count, pb_name))
            else
                -- Regular CC parsing
                local cc_number, parameter_name = line:match("^(%d+)%s+(.+)$")
                if cc_number and parameter_name then
                    local cc_num = tonumber(cc_number)
                    if cc_num and cc_num >= 0 and cc_num <= 127 then
                        valid_cc_count = valid_cc_count + 1
                        
                        -- Check if we're exceeding the MIDI Control device limit
                        if valid_cc_count > MAX_CC_LIMIT then
                            print(string.format("-- CCizer: Warning - CC mapping #%d exceeds MIDI Control device limit of %d CCs, ignoring excess mappings", valid_cc_count, MAX_CC_LIMIT))
                            break
                        end
                        
                        table.insert(mappings, {
                            cc = cc_num,
                            name = parameter_name,
                            type = "CC"
                        })
                        print(string.format("-- CCizer: Valid CC mapping #%d: CC %d -> %s", valid_cc_count, cc_num, parameter_name))
                    else
                        print(string.format("-- CCizer: Warning - invalid CC number %d on line %d (must be 0-127)", cc_num or -1, line_count))
                    end
                else
                    print(string.format("-- CCizer: Warning - could not parse line %d: %s", line_count, line))
                end
            end
        end
    end
    
    file:close()
    
    local status_message = string.format("-- CCizer: Loaded %d valid MIDI CC mappings from %s", #mappings, filepath)
    if #mappings == MAX_CC_LIMIT then
        status_message = status_message .. string.format(" (reached maximum limit of %d CCs)", MAX_CC_LIMIT)
    elseif #mappings > 0 then
        status_message = status_message .. string.format(" (can add %d more CCs)", MAX_CC_LIMIT - #mappings)
    end
    
    print(status_message)
    return mappings
end

-- Helper function to generate the MIDI Control device XML
local function generate_midi_control_xml(cc_mappings)
    local xml_lines = {}
    
    -- Calculate visible pages based on number of mappings
    -- Each page typically shows ~4-5 controllers, so we calculate needed pages
    local num_mappings = #cc_mappings
    local visible_pages = 3 -- Default minimum
    
    if num_mappings > 15 then
        visible_pages = 5
    end
    if num_mappings > 20 then
        visible_pages = 6
    end
    if num_mappings > 25 then
        visible_pages = 7
    end
    if num_mappings > 30 then
        visible_pages = 8
    end
    
    -- XML header
    table.insert(xml_lines, '<?xml version="1.0" encoding="UTF-8"?>')
    table.insert(xml_lines, '<FilterDevicePreset doc_version="12">')
    table.insert(xml_lines, '  <DeviceSlot type="MidiControlDevice">')
    table.insert(xml_lines, '    <IsMaximized>true</IsMaximized>')
    
    -- Generate 35 controllers (0-34)
    for i = 0, 34 do
        local mapping = cc_mappings[i + 1] -- Lua is 1-based, controllers are 0-based
        
        if mapping then
            -- Use the mapping from CCizer file
            table.insert(xml_lines, string.format('    <ControllerValue%d>', i))
            if mapping.type == "PB" then
                table.insert(xml_lines, '      <Value>63.5</Value>') -- Center value for pitchbend
            else
                table.insert(xml_lines, '      <Value>0.0</Value>')
            end
            table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
            table.insert(xml_lines, string.format('    <ControllerNumber%d>%d</ControllerNumber%d>', i, mapping.cc, i))
            table.insert(xml_lines, string.format('    <ControllerName%d>%s</ControllerName%d>', i, mapping.name, i))
            table.insert(xml_lines, string.format('    <ControllerType%d>%s</ControllerType%d>', i, mapping.type or "CC", i))
        else
            -- Default empty controller
            table.insert(xml_lines, string.format('    <ControllerValue%d>', i))
            table.insert(xml_lines, '      <Value>0.0</Value>')
            table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
            table.insert(xml_lines, string.format('    <ControllerNumber%d>-1</ControllerNumber%d>', i, i))
            table.insert(xml_lines, string.format('    <ControllerName%d>Untitled</ControllerName%d>', i, i))
            table.insert(xml_lines, string.format('    <ControllerType%d>CC</ControllerType%d>', i, i))
        end
    end
    
    -- XML footer with calculated visible pages
    table.insert(xml_lines, string.format('    <VisiblePages>%d</VisiblePages>', visible_pages))
    table.insert(xml_lines, '  </DeviceSlot>')
    table.insert(xml_lines, '</FilterDevicePreset>')
    
    return table.concat(xml_lines, '\n')
end

-- Create MIDI Control device from CCizer mappings
local function apply_ccizer_mappings(mappings, filename)
    if not mappings or #mappings == 0 then
        renoise.app():show_warning("No valid MIDI CC mappings found in file")
        return
    end
    
    local song = renoise.song()
    
    print("-- CCizer: Creating MIDI Control device from CCizer mappings")
    print(string.format("-- CCizer: Using %d / %d CC mappings", #mappings, MAX_CC_LIMIT))
    
    -- Load the MIDI Control device
    print("-- CCizer: Loading *Instr. MIDI Control device...")
    loadnative("Audio/Effects/Native/*Instr. MIDI Control")
    
    -- Give the device a moment to load
    renoise.app():show_status("Loading MIDI Control device...")
    
    -- Generate the XML preset with our CC mappings
    local xml_content = generate_midi_control_xml(mappings)
    
    -- Apply the XML to the device
    local device = nil
    if renoise.app().window.active_middle_frame == 7 or renoise.app().window.active_middle_frame == 6 then
        -- Sample FX chain
        device = song.selected_sample_device
    else
        -- Track DSP chain
        device = song.selected_device
    end
    
    if device and device.name == "*Instr. MIDI Control" then
        device.active_preset_data = xml_content
        -- Use CCizer filename as device name
        local name_without_ext = filename:match("^(.+)%..+$") or filename
        device.display_name = name_without_ext
        print("-- CCizer: Successfully applied CC mappings to device with name: " .. name_without_ext)
        
        -- Create status message with CC count information
        local status_message = string.format("MIDI Control device '%s' created with %d/%d CC mappings", name_without_ext, #mappings, MAX_CC_LIMIT)
        if #mappings == MAX_CC_LIMIT then
            status_message = status_message .. " (max reached)"
        else
            status_message = status_message .. string.format(" (%d slots available)", MAX_CC_LIMIT - #mappings)
        end
        
        renoise.app():show_status(status_message)
    else
        renoise.app():show_error("Failed to find or load MIDI Control device")
    end
end

-- Create the CCizer loader dialog
function PakettiCCizerLoader()
    if dialog and dialog.visible then
        dialog:close()
        return
    end
    
    local vb = renoise.ViewBuilder()
    local files = scan_ccizer_files()
    
    if #files == 0 then
        renoise.app():show_error("No CCizer files found in: " .. get_ccizer_folder())
        return
    end
    
    -- Create file list for popup
    local file_items = {}
    for _, file in ipairs(files) do
        table.insert(file_items, file.display_name)
    end
    
    local selected_file_index = 1
    
    local selected_file_info = vb:text{
        text = "Loading...",
        width = 400
    }
    
    -- Function to update file info with CC count
    local function update_selected_file_info(file_index)
        if files[file_index] then
            local mappings = load_ccizer_file(files[file_index].full_path)
            if mappings then
                local info_text = string.format("%s (%d/%d CCs)", 
                    files[file_index].display_name, #mappings, MAX_CC_LIMIT)
                if #mappings == MAX_CC_LIMIT then
                    info_text = info_text .. " - MAX REACHED"
                elseif #mappings > 0 then
                    info_text = info_text .. string.format(" - %d slots available", MAX_CC_LIMIT - #mappings)
                end
                selected_file_info.text = info_text
            else
                selected_file_info.text = files[file_index].display_name .. " - ERROR LOADING"
            end
        else
            selected_file_info.text = "None"
        end
    end
    
    local content = vb:column{
        margin = 10,
        
        vb:row{
            
            vb:text{text = "CCizer File", width = 100, font = "bold", style = "strong"},
            vb:popup{
                id = "ccizer_file_popup",
                items = file_items,
                value = selected_file_index,
                width = 300,
                notifier = function(value)
                    selected_file_index = value
                    update_selected_file_info(value)
                end
            },
            vb:button{
                text = "Browse",
                width = 80,
                notifier = function()
                    local selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load CCizer Text File")
                    if selected_textfile and selected_textfile ~= "" then
                        local mappings = load_ccizer_file(selected_textfile)
                        if mappings then
                            local filename = selected_textfile:match("([^/\\]+)$")
                            local name_without_ext = filename:match("^(.+)%..+$") or filename
                            apply_ccizer_mappings(mappings, name_without_ext)
                            dialog:close()
                            dialog = nil
                        end
                    end
                end
            }
        },
        
        vb:row{
            vb:text{text = "Selected", width = 100, font = "bold", style = "strong"},
            selected_file_info
        },
        
        vb:text{
            text = "CCizer files contain MIDI CC to parameter mappings.",
            width = 400
        },
        
        vb:horizontal_aligner{
            
            vb:button{
                text = "Open Path",
                width = bottomButtonWidth,
                notifier = function()
                    renoise.app():open_path(get_ccizer_folder())
                end
            },
            
            vb:button{
                text = "Preview",
                width = bottomButtonWidth,
                notifier = function()
                    if files[selected_file_index] then
                        local mappings = load_ccizer_file(files[selected_file_index].full_path)
                        if mappings then
                            local preview = string.format("Preview of %s\n", files[selected_file_index].display_name)
                            preview = preview .. string.format("Valid CC mappings: %d / %d (max for MIDI Control device)\n\n", #mappings, MAX_CC_LIMIT)
                            
                            if #mappings == MAX_CC_LIMIT then
                                preview = preview .. "⚠️ Reached maximum CC limit for MIDI Control device\n\n"
                            elseif #mappings > 0 then
                                preview = preview .. string.format("✓ Can add %d more CC mappings\n\n", MAX_CC_LIMIT - #mappings)
                            end
                            
                            for i, mapping in ipairs(mappings) do
                                if mapping.type == "PB" then
                                    preview = preview .. string.format("PB -> %s\n", mapping.name)
                                else
                                    preview = preview .. string.format("CC %d -> %s\n", mapping.cc, mapping.name)
                                end
                            end
                            renoise.app():show_message(preview)
                        end
                    end
                end
            },
            
            vb:button{
                text = "Create MIDI Control",
                width = bottomButtonWidth,
                notifier = function()
                    if files[selected_file_index] then
                        local mappings = load_ccizer_file(files[selected_file_index].full_path)
                        if mappings then
                            apply_ccizer_mappings(mappings, files[selected_file_index].display_name)
                        end
                    end
                end
            },
            
            vb:button{
                text = "Cancel",
                width = bottomButtonWidth,
                notifier = function()
                    dialog:close()
                    dialog = nil
                end
            }
        }
    }
    
    -- Update the selected file info for the default selection
    update_selected_file_info(selected_file_index)
        
    dialog = renoise.app():show_custom_dialog("CCizer TXT->CC Loader", content, my_keyhandler_func)
end

-- Menu entries
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_menu_entry{name = "--Mixer:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_menu_entry{name = "--Instrument Box:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_menu_entry{name = "--DSP Device:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_menu_entry{name = "--Sample FX Mixer:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_keybinding{name = "Global:Paketti:CCizer Loader...",invoke = PakettiCCizerLoader}


-- Function to create MIDI Control device from text file with CC mappings
function PakettiCreateMIDIControlFromTextFile()
    local song = renoise.song()
    
    print("-- MIDI Control Text: Starting MIDI Control device creation from text file")
    
    -- First, prompt for the text file
    local selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load Textfile with CC Mappings")
    
    if not selected_textfile or selected_textfile == "" then
      renoise.app():show_status("No text file selected, cancelling operation")
      return
    end
    
    print("-- MIDI Control Text: Selected file: " .. selected_textfile)
    
    -- Read and parse the text file
    local cc_mappings = {}
    local file = io.open(selected_textfile, "r")
    
    if not file then
      renoise.app():show_error("Could not open text file: " .. selected_textfile)
      return
    end
    
    local line_count = 0
    local valid_cc_count = 0
    
    for line in file:lines() do
      line_count = line_count + 1
      line = line:match("^%s*(.-)%s*$") -- Trim whitespace
      
      if line and line ~= "" and not line:match("^#") then -- Skip empty lines and comments
        -- Check for Pitchbend first
        local pb_name = line:match("^PB%s+(.+)$")
        if pb_name then
          valid_cc_count = valid_cc_count + 1
          
          -- Check if we're exceeding the MIDI Control device limit
          if valid_cc_count > MAX_CC_LIMIT then
            print(string.format("-- MIDI Control Text: Warning - CC mapping #%d exceeds MIDI Control device limit of %d CCs, ignoring excess mappings", valid_cc_count, MAX_CC_LIMIT))
            break
          end
          
          table.insert(cc_mappings, {cc = -1, name = pb_name, type = "PB"})
          print(string.format("-- MIDI Control Text: Valid PB mapping #%d: PB -> %s", valid_cc_count, pb_name))
        else
          -- Parse line format: "54 Cutoff" or "127 SomethingElse"
          local cc_number, cc_name = line:match("^(%d+)%s+(.+)$")
          
          if cc_number and cc_name then
            cc_number = tonumber(cc_number)
            if cc_number and cc_number >= 0 and cc_number <= 127 then
              valid_cc_count = valid_cc_count + 1
              
              -- Check if we're exceeding the MIDI Control device limit
              if valid_cc_count > MAX_CC_LIMIT then
                print(string.format("-- MIDI Control Text: Warning - CC mapping #%d exceeds MIDI Control device limit of %d CCs, ignoring excess mappings", valid_cc_count, MAX_CC_LIMIT))
                break
              end
              
              table.insert(cc_mappings, {cc = cc_number, name = cc_name, type = "CC"})
              print(string.format("-- MIDI Control Text: Valid CC mapping #%d: CC %d -> %s", valid_cc_count, cc_number, cc_name))
            else
              print(string.format("-- MIDI Control Text: Warning - invalid CC number %d on line %d (must be 0-127)", cc_number or -1, line_count))
            end
          else
            print(string.format("-- MIDI Control Text: Warning - could not parse line %d: %s", line_count, line))
          end
        end
      end
    end
    
    file:close()
    
    if #cc_mappings == 0 then
      renoise.app():show_error("No valid CC mappings found in text file")
      return
    end
    
    local status_message = string.format("-- MIDI Control Text: Successfully parsed %d valid CC mappings", #cc_mappings)
    if #cc_mappings == MAX_CC_LIMIT then
        status_message = status_message .. string.format(" (reached maximum limit of %d CCs)", MAX_CC_LIMIT)
    elseif #cc_mappings > 0 then
        status_message = status_message .. string.format(" (can add %d more CCs)", MAX_CC_LIMIT - #cc_mappings)
    end
    
    print(status_message)
    
    -- Load the MIDI Control device
    print("-- MIDI Control Text: Loading *Instr. MIDI Control device...")
    loadnative("Audio/Effects/Native/*Instr. MIDI Control")
    
    -- Give the device a moment to load
    renoise.app():show_status("Loading MIDI Control device...")
    
    -- Generate the XML preset with our CC mappings
    local xml_content = generate_midi_control_xml(cc_mappings)
    
    -- Apply the XML to the device
    local device = nil
    if renoise.app().window.active_middle_frame == 7 or renoise.app().window.active_middle_frame == 6 then
      -- Sample FX chain
      device = song.selected_sample_device
    else
      -- Track DSP chain
      device = song.selected_device
    end
    
    if device and device.name == "*Instr. MIDI Control" then
      device.active_preset_data = xml_content
      -- Extract filename without path and extension
      local filename = selected_textfile:match("([^/\\]+)$")  -- Get filename from path
      local name_without_ext = filename:match("^(.+)%..+$") or filename  -- Remove extension, fallback to full filename
      device.display_name = name_without_ext
      print("-- MIDI Control Text: Successfully applied CC mappings to device with name: " .. name_without_ext)
      
      -- Create status message with CC count information
      local status_message = string.format("MIDI Control device '%s' created with %d/%d CC mappings", name_without_ext, #cc_mappings, MAX_CC_LIMIT)
      if #cc_mappings == MAX_CC_LIMIT then
          status_message = status_message .. " (max reached)"
      else
          status_message = status_message .. string.format(" (%d slots available)", MAX_CC_LIMIT - #cc_mappings)
      end
      
      renoise.app():show_status(status_message)
    else
      renoise.app():show_error("Failed to find or load MIDI Control device")
    end
  end
  
  -- Helper function to generate the MIDI Control device XML
  function generate_midi_control_xml(cc_mappings)
    local xml_lines = {}
    
    -- Calculate visible pages based on number of mappings
    -- Each page typically shows ~4-5 controllers, so we calculate needed pages
    local num_mappings = #cc_mappings
    local visible_pages = 3 -- Default minimum
    
    if num_mappings > 15 then
        visible_pages = 5
    end
    if num_mappings > 20 then
        visible_pages = 6
    end
    if num_mappings > 25 then
        visible_pages = 7
    end
    if num_mappings > 30 then
        visible_pages = 8
    end
    
    -- XML header
    table.insert(xml_lines, '<?xml version="1.0" encoding="UTF-8"?>')
    table.insert(xml_lines, '<FilterDevicePreset doc_version="12">')
    table.insert(xml_lines, '  <DeviceSlot type="MidiControlDevice">')
    table.insert(xml_lines, '    <IsMaximized>true</IsMaximized>')
    
    -- Generate 35 controllers (0-34)
    for i = 0, 34 do
      local mapping = cc_mappings[i + 1] -- Lua is 1-based, controllers are 0-based
      
             if mapping then
         -- Use the mapping from text file
         table.insert(xml_lines, string.format('    <ControllerValue%d>', i))
         if mapping.type == "PB" then
             table.insert(xml_lines, '      <Value>63.5</Value>') -- Center value for pitchbend
         else
             table.insert(xml_lines, '      <Value>0.0</Value>')
         end
         table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
         table.insert(xml_lines, string.format('    <ControllerNumber%d>%d</ControllerNumber%d>', i, mapping.cc, i))
               table.insert(xml_lines, string.format('    <ControllerName%d>%s</ControllerName%d>', i, mapping.name, i))
         table.insert(xml_lines, string.format('    <ControllerType%d>%s</ControllerType%d>', i, mapping.type or "CC", i))
       else
         -- Default empty controller
         table.insert(xml_lines, string.format('    <ControllerValue%d>', i))
         table.insert(xml_lines, '      <Value>0.0</Value>')
         table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
         table.insert(xml_lines, string.format('    <ControllerNumber%d>-1</ControllerNumber%d>', i, i))
         table.insert(xml_lines, string.format('    <ControllerName%d>Untitled</ControllerName%d>', i, i))
         table.insert(xml_lines, string.format('    <ControllerType%d>CC</ControllerType%d>', i, i))
       end
     end
     
     -- XML footer with calculated visible pages
     table.insert(xml_lines, string.format('    <VisiblePages>%d</VisiblePages>', visible_pages))
     table.insert(xml_lines, '  </DeviceSlot>')
     table.insert(xml_lines, '</FilterDevicePreset>')
     
     return table.concat(xml_lines, '\n')
   end
   
   -- Menu entries for the new function
   renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Experimental..:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   renoise.tool():add_menu_entry{name="DSP Device:Paketti..:Experimental..:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   renoise.tool():add_menu_entry{name="Sample FX Mixer:Paketti..:Experimental..:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   renoise.tool():add_menu_entry{name="Mixer:Paketti..:Experimental..:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   
   renoise.tool():add_keybinding{name="Global:Paketti:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}