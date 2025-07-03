-- Paketti CCizer Loader Dialog
-- Scans ccizer folder and allows selection/loading of MIDI control configuration files

local dialog = nil
local separator = package.config:sub(1,1)

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
    
    for line in file:lines() do
        line_count = line_count + 1
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace
        
        if line and line ~= "" and not line:match("^#") then -- Skip empty lines and comments
            local cc_number, parameter_name = line:match("^(%d+)%s+(.+)$")
            if cc_number and parameter_name then
                local cc_num = tonumber(cc_number)
                if cc_num and cc_num >= 0 and cc_num <= 127 then
                    table.insert(mappings, {
                        cc = cc_num,
                        name = parameter_name
                    })
                end
            end
        end
    end
    
    file:close()
    
    print(string.format("-- CCizer: Loaded %d MIDI CC mappings from %s", #mappings, filepath))
    return mappings
end

-- Helper function to generate the MIDI Control device XML
local function generate_midi_control_xml(cc_mappings)
    local xml_lines = {}
    
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
            table.insert(xml_lines, '      <Value>0.0</Value>')
            table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
            table.insert(xml_lines, string.format('    <ControllerNumber%d>%d</ControllerNumber%d>', i, mapping.cc, i))
            table.insert(xml_lines, string.format('    <ControllerName%d>%s</ControllerName%d>', i, mapping.name, i))
            table.insert(xml_lines, string.format('    <ControllerType%d>CC</ControllerType%d>', i, i))
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
    
    -- XML footer
    table.insert(xml_lines, '    <VisiblePages>3</VisiblePages>')
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
        renoise.app():show_status(string.format("MIDI Control device '%s' created with %d CC mappings", name_without_ext, #mappings))
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
        text = "Selected: " .. (files[1] and files[1].display_name or "None"),
        width = 400
    }
    
    local content = vb:column{
        margin = 10,
        
        vb:row{
            spacing = 10,
            vb:text{text = "CCizer File:", width = 80},
            vb:popup{
                id = "ccizer_file_popup",
                items = file_items,
                value = selected_file_index,
                width = 300,
                notifier = function(value)
                    selected_file_index = value
                    if files[value] then
                        selected_file_info.text = "Selected: " .. files[value].display_name
                    end
                end
            }
        },
        
        selected_file_info,
        
        vb:text{
            text = "CCizer files contain MIDI CC to parameter mappings.",
            width = 400
        },
        
        vb:horizontal_aligner{
            mode = "distribute",
            vb:button{
                text = "Open Path",
                width = 80,
                notifier = function()
                    renoise.app():open_path(get_ccizer_folder())
                end
            },
            
            vb:button{
                text = "Preview",
                width = 80,
                notifier = function()
                    if files[selected_file_index] then
                        local mappings = load_ccizer_file(files[selected_file_index].full_path)
                        if mappings then
                            local preview = string.format("Preview of %s (%d mappings):\n\n", 
                                files[selected_file_index].display_name, #mappings)
                            for i, mapping in ipairs(mappings) do
                                preview = preview .. string.format("CC %d -> %s\n", mapping.cc, mapping.name)
                            end
                            renoise.app():show_message(preview)
                        end
                    end
                end
            },
            
            vb:button{
                text = "Create MIDI Control",
                width = 120,
                notifier = function()
                    if files[selected_file_index] then
                        local mappings = load_ccizer_file(files[selected_file_index].full_path)
                        if mappings then
                            apply_ccizer_mappings(mappings, files[selected_file_index].display_name)
                            dialog:close()
                            dialog = nil
                        end
                    end
                end
            },
            
            vb:button{
                text = "Cancel",
                width = 80,
                notifier = function()
                    dialog:close()
                    dialog = nil
                end
            }
        }
    }
    
    local function key_handler(dialog, key)
        if key.name == "esc" then
            dialog:close()
            dialog = nil
        end
    end
    
    dialog = renoise.app():show_custom_dialog("CCizer Loader", content, key_handler)
end

-- Menu entries
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
renoise.tool():add_menu_entry{name = "--Mixer:Paketti Gadgets:CCizer Loader...",invoke = PakettiCCizerLoader}
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
    for line in file:lines() do
      line_count = line_count + 1
      if line_count > 34 then
        print("-- MIDI Control Text: Warning - more than 34 lines in file, ignoring excess lines")
        break
      end
      
      -- Parse line format: "54 Cutoff" or "127 SomethingElse"
      local cc_number, cc_name = line:match("^(%d+)%s+(.+)$")
      
      if cc_number and cc_name then
        cc_number = tonumber(cc_number)
        if cc_number >= 0 and cc_number <= 127 then
          table.insert(cc_mappings, {cc = cc_number, name = cc_name})
          print(string.format("-- MIDI Control Text: Parsed CC %d = %s", cc_number, cc_name))
        else
          print(string.format("-- MIDI Control Text: Warning - invalid CC number %d on line %d", cc_number, line_count))
        end
      else
        print(string.format("-- MIDI Control Text: Warning - could not parse line %d: %s", line_count, line))
      end
    end
    
    file:close()
    
    if #cc_mappings == 0 then
      renoise.app():show_error("No valid CC mappings found in text file")
      return
    end
    
    print(string.format("-- MIDI Control Text: Successfully parsed %d CC mappings", #cc_mappings))
    
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
      renoise.app():show_status(string.format("MIDI Control device '%s' created with %d CC mappings", name_without_ext, #cc_mappings))
    else
      renoise.app():show_error("Failed to find or load MIDI Control device")
    end
  end
  
  -- Helper function to generate the MIDI Control device XML
  function generate_midi_control_xml(cc_mappings)
    local xml_lines = {}
    
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
        table.insert(xml_lines, '      <Value>0.0</Value>')
        table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
        table.insert(xml_lines, string.format('    <ControllerNumber%d>%d</ControllerNumber%d>', i, mapping.cc, i))
               table.insert(xml_lines, string.format('    <ControllerName%d>%s</ControllerName%d>', i, mapping.name, i))
         table.insert(xml_lines, string.format('    <ControllerType%d>CC</ControllerType%d>', i, i))
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
     
     -- XML footer
     table.insert(xml_lines, '    <VisiblePages>3</VisiblePages>')
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