-- Paketti CCizer Loader Dialog
-- Scans ccizer folder and allows selection/loading of MIDI control configuration files

local dialog = nil
local ccizer_surface_dialog = nil
local ccizer_surface_vb = nil
local separator = package.config:sub(1,1)
local bottomButtonWidth = 120
local MAX_CC_LIMIT = 35 -- Maximum CC mappings for MIDI Control device
local CCIZER_SURFACE_COLUMNS = 3

local ccizer_surface_state = {
    out_dev = nil,
    out_name = nil,
    channel = 1,
    filepath = nil,
    filename = nil,
    mappings = {},
    values = {},
    building = false
}

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

local function parse_ccizer_line(line)
    local pb_name = line:match("^PB%s+(.+)$")
    if pb_name then
        return { cc = -1, name = pb_name, type = "PB" }
    end

    local cc_number, parameter_name = line:match("^(%d+)%s+(.+)$")
    if cc_number and parameter_name then
        local cc_num = tonumber(cc_number)
        if cc_num and cc_num >= 0 and cc_num <= 127 then
            return { cc = cc_num, name = parameter_name, type = "CC" }
        end
    end

    return nil
end

local function load_ccizer_surface_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        renoise.app():show_error("Cannot open CCizer file: " .. filepath)
        return nil
    end

    local mappings = {}
    local line_count = 0
    for line in file:lines() do
        line_count = line_count + 1
        line = line:match("^%s*(.-)%s*$")
        if line and line ~= "" and not line:match("^#") then
            local mapping = parse_ccizer_line(line)
            if mapping then
                mappings[#mappings + 1] = mapping
            else
                print(string.format("-- CCizer Surface: Warning - could not parse line %d: %s", line_count, line))
            end
        end
    end
    file:close()

    print(string.format("-- CCizer Surface: Loaded %d mappings from %s", #mappings, filepath))
    return mappings
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

-- Helper function to clean parameter names by removing "CC XX " prefix
-- e.g., "CC 1 (Mod Wheel)" becomes "Mod Wheel"
function paketti_clean_cc_parameter_name(param_name)
  if not param_name then
    return param_name
  end
  
  -- Remove "CC XX " pattern (e.g., "CC 54 (Cutoff)" becomes "(Cutoff)")
  local cleaned = param_name:gsub("^CC %d+ ", "")
  
  -- Remove parentheses if the entire remaining string is wrapped in them
  -- e.g., "(Cutoff)" becomes "Cutoff"
  if cleaned:match("^%((.+)%)$") then
    cleaned = cleaned:match("^%((.+)%)$")
  end
  
  return cleaned
end

-- SHARED: Helper function to generate the MIDI Control device XML
-- This function is used by both CCizer Loader and MIDI Populator
function paketti_generate_midi_control_xml(cc_mappings)
    local xml_lines = {}
    
    -- Calculate visible pages based on number of mappings
    -- Each page typically shows ~5 controllers, so we calculate needed pages
    local num_mappings = #cc_mappings
    local controllers_per_page = 5
    local visible_pages = math.max(1, math.ceil(num_mappings / controllers_per_page))
    
    -- Ensure we don't exceed reasonable page limits for the MIDI Control device
    visible_pages = math.min(visible_pages, 8)
    
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
            -- For pitchbend, use controller number 0 instead of -1 to enable it
            local controller_number = (mapping.type == "PB") and 0 or mapping.cc
            table.insert(xml_lines, string.format('    <ControllerNumber%d>%d</ControllerNumber%d>', i, controller_number, i))
            table.insert(xml_lines, string.format('    <ControllerName%d>%s</ControllerName%d>', i, paketti_clean_cc_parameter_name(mapping.name), i))
            table.insert(xml_lines, string.format('    <ControllerType%d>%s</ControllerType%d>', i, mapping.type or "CC", i))
            table.insert(xml_lines, string.format('    <ControllerEnabled%d>true</ControllerEnabled%d>', i, i))
        else
            -- Default empty controller
            table.insert(xml_lines, string.format('    <ControllerValue%d>', i))
            table.insert(xml_lines, '      <Value>0.0</Value>')
            table.insert(xml_lines, string.format('    </ControllerValue%d>', i))
            table.insert(xml_lines, string.format('    <ControllerNumber%d>-1</ControllerNumber%d>', i, i))
            table.insert(xml_lines, string.format('    <ControllerName%d>Untitled</ControllerName%d>', i, i))
            table.insert(xml_lines, string.format('    <ControllerType%d>CC</ControllerType%d>', i, i))
            table.insert(xml_lines, string.format('    <ControllerEnabled%d>false</ControllerEnabled%d>', i, i))
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
    
    -- Load the MIDI Control device SILENTLY
    print("-- CCizer: Loading *Instr. MIDI Control device silently...")
    loadnative("Audio/Effects/Native/*Instr. MIDI Control", nil, nil, nil, true)
    
    -- Give the device a moment to load, then apply XML and open parameter editor
    renoise.app():show_status("Loading MIDI Control device...")
    
    -- Generate the XML preset with our CC mappings
    local xml_content = paketti_generate_midi_control_xml(mappings)
    local name_without_ext = filename:match("^(.+)%..+$") or filename
    
    -- Using anonymous timer functions prevents multiple registrations
    
    local function apply_xml_and_open_editor()
        -- Find the device that was just loaded
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
            
            -- Wait a tick, then open parameter editor and remove timer
            local didiRun = false
            local timer_func
            timer_func = function()
                didiRun = true
                if didiRun == true then
                    renoise.tool():remove_timer(timer_func)
                end
                if PAKETTI_HAS_CANVAS then
                    PakettiCanvasExperimentsInit()
                end
            end
            renoise.tool():add_timer(timer_func, 100)
        else
            renoise.app():show_error("Failed to find or load MIDI Control device")
        end
    end
    
    -- Wait for device to load before applying XML
    local didiRun = false
    local device_timer_func
    device_timer_func = function()
        didiRun = true
        if didiRun == true then
            renoise.tool():remove_timer(device_timer_func)
        end
        apply_xml_and_open_editor()
    end
    renoise.tool():add_timer(device_timer_func, 200)
end

local function ccizer_surface_close_output()
    if ccizer_surface_state.out_dev then
        pcall(function() ccizer_surface_state.out_dev:close() end)
        ccizer_surface_state.out_dev = nil
        ccizer_surface_state.out_name = nil
    end
end

local function ccizer_surface_open_output(name)
    if ccizer_surface_state.out_dev and ccizer_surface_state.out_name == name then
        return true
    end
    ccizer_surface_close_output()
    if not name or name == "" then return false end
    local ok, dev = pcall(function() return renoise.Midi.create_output_device(name) end)
    if not ok or not dev then
        renoise.app():show_status("CCizer Surface: could not open MIDI output " .. tostring(name))
        return false
    end
    ccizer_surface_state.out_dev = dev
    ccizer_surface_state.out_name = name
    print("-- CCizer Surface: opened MIDI output '" .. tostring(name) .. "'")
    return true
end

local function ccizer_surface_send_mapping(index, value)
    local mapping = ccizer_surface_state.mappings[index]
    if not mapping then return false end
    if not ccizer_surface_state.out_dev then
        renoise.app():show_status("CCizer Surface: no MIDI output selected")
        return false
    end

    value = math.max(0, math.min(127, math.floor((value or 0) + 0.5)))
    ccizer_surface_state.values[index] = value

    local channel = math.max(1, math.min(16, ccizer_surface_state.channel or 1))
    local status = nil
    local bytes = nil
    if mapping.type == "PB" then
        local bend = math.floor((value / 127) * 16383 + 0.5)
        bytes = { 0xE0 + channel - 1, bend % 128, math.floor(bend / 128) % 128 }
    else
        status = 0xB0 + channel - 1
        bytes = { status, mapping.cc, value }
    end

    local ok, err = pcall(function() ccizer_surface_state.out_dev:send(bytes) end)
    if not ok then
        renoise.app():show_status("CCizer Surface: MIDI send failed")
        print("-- CCizer Surface: MIDI send failed: " .. tostring(err))
        return false
    end

    if ccizer_surface_vb and ccizer_surface_vb.views and ccizer_surface_vb.views["ccizer_surface_value_" .. index] then
        ccizer_surface_vb.views["ccizer_surface_value_" .. index].text = tostring(value)
    end
    return true
end

local function ccizer_surface_build_row(index)
    local mapping = ccizer_surface_state.mappings[index]
    local label = mapping.type == "PB" and "PB" or ("CC " .. tostring(mapping.cc))
    local value = ccizer_surface_state.values[index] or (mapping.type == "PB" and 64 or 0)

    return ccizer_surface_vb:row{
        spacing = 4,
        ccizer_surface_vb:text{
            text = label,
            width = 42,
            font = "mono",
            style = "strong"
        },
        ccizer_surface_vb:text{
            text = paketti_clean_cc_parameter_name(mapping.name),
            width = 150
        },
        ccizer_surface_vb:slider{
            id = "ccizer_surface_slider_" .. index,
            min = 0,
            max = 127,
            value = value,
            width = 120,
            notifier = function(v)
                if ccizer_surface_state.building then return end
                ccizer_surface_send_mapping(index, v)
            end
        },
        ccizer_surface_vb:text{
            id = "ccizer_surface_value_" .. index,
            text = tostring(value),
            width = 28,
            align = "right"
        }
    }
end

local function ccizer_surface_reset_values()
    ccizer_surface_state.building = true
    for i, mapping in ipairs(ccizer_surface_state.mappings) do
        local value = mapping.type == "PB" and 64 or 0
        ccizer_surface_state.values[i] = value
        if ccizer_surface_vb and ccizer_surface_vb.views and ccizer_surface_vb.views["ccizer_surface_slider_" .. i] then
            ccizer_surface_vb.views["ccizer_surface_slider_" .. i].value = value
        end
        if ccizer_surface_vb and ccizer_surface_vb.views and ccizer_surface_vb.views["ccizer_surface_value_" .. i] then
            ccizer_surface_vb.views["ccizer_surface_value_" .. i].text = tostring(value)
        end
    end
    ccizer_surface_state.building = false
    for i, mapping in ipairs(ccizer_surface_state.mappings) do
        local value = mapping.type == "PB" and 64 or 0
        ccizer_surface_send_mapping(i, value)
    end
end

local function ccizer_surface_default_file()
    local files = scan_ccizer_files()
    for _, file in ipairs(files) do
        if file.name == "sc88st.txt" then return file end
    end
    return files[1]
end

function PakettiCCizerControlSurface(filepath)
    if ccizer_surface_dialog and ccizer_surface_dialog.visible then
        ccizer_surface_dialog:close()
        ccizer_surface_dialog = nil
        if not filepath then return end
    end

    local files = scan_ccizer_files()
    if #files == 0 then
        renoise.app():show_error("No CCizer files found in: " .. get_ccizer_folder())
        return
    end

    local selected_file = nil
    if filepath then
        local filename = filepath:match("([^/\\]+)$")
        selected_file = { name = filename, display_name = filename:gsub("%.txt$", ""), full_path = filepath }
    else
        selected_file = ccizer_surface_default_file()
    end

    local mappings = load_ccizer_surface_file(selected_file.full_path)
    if not mappings or #mappings == 0 then
        renoise.app():show_error("CCizer Surface: no valid mappings in " .. selected_file.full_path)
        return
    end

    ccizer_surface_state.filepath = selected_file.full_path
    ccizer_surface_state.filename = selected_file.display_name
    ccizer_surface_state.mappings = mappings
    ccizer_surface_state.values = {}
    for i, mapping in ipairs(mappings) do
        ccizer_surface_state.values[i] = mapping.type == "PB" and 64 or 0
    end

    ccizer_surface_vb = renoise.ViewBuilder()
    ccizer_surface_state.building = true

    local file_items = {}
    local file_index = 1
    for i, file in ipairs(files) do
        file_items[#file_items + 1] = file.display_name
        if file.full_path == selected_file.full_path then file_index = i end
    end

    local out_names = renoise.Midi.available_output_devices()
    local port_items = { "<no port>" }
    for _, name in ipairs(out_names) do port_items[#port_items + 1] = name end
    local port_index = 1
    for i, name in ipairs(port_items) do
        if name == ccizer_surface_state.out_name then port_index = i break end
    end

    local columns = ccizer_surface_vb:row{ spacing = 10 }
    local rows_per_column = math.ceil(#mappings / CCIZER_SURFACE_COLUMNS)
    for column_index = 1, CCIZER_SURFACE_COLUMNS do
        local col = ccizer_surface_vb:column{ spacing = 2 }
        local first = (column_index - 1) * rows_per_column + 1
        local last = math.min(#mappings, first + rows_per_column - 1)
        for i = first, last do
            col:add_child(ccizer_surface_build_row(i))
        end
        columns:add_child(col)
    end

    local content = ccizer_surface_vb:column{
        margin = 8,
        spacing = 6,
        ccizer_surface_vb:row{
            spacing = 6,
            ccizer_surface_vb:text{ text = "File", width = 44, font = "bold", style = "strong" },
            ccizer_surface_vb:popup{
                id = "ccizer_surface_file_popup",
                items = file_items,
                value = file_index,
                width = 220,
                notifier = function(index)
                    if ccizer_surface_state.building then return end
                    if files[index] then PakettiCCizerControlSurface(files[index].full_path) end
                end
            },
            ccizer_surface_vb:button{
                text = "Browse",
                width = 70,
                notifier = function()
                    local selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load CCizer Control Surface Text File")
                    if selected_textfile and selected_textfile ~= "" then
                        PakettiCCizerControlSurface(selected_textfile)
                    end
                end
            },
            ccizer_surface_vb:text{
                text = string.format("%d controls", #mappings),
                width = 90
            }
        },
        ccizer_surface_vb:row{
            spacing = 6,
            ccizer_surface_vb:text{ text = "MIDI Out", width = 60, font = "bold", style = "strong" },
            ccizer_surface_vb:popup{
                id = "ccizer_surface_port_popup",
                items = port_items,
                value = port_index,
                width = 220,
                notifier = function(index)
                    if ccizer_surface_state.building then return end
                    if index == 1 then ccizer_surface_close_output()
                    else ccizer_surface_open_output(port_items[index]) end
                end
            },
            ccizer_surface_vb:text{ text = "Channel", width = 56 },
            ccizer_surface_vb:valuebox{
                min = 1,
                max = 16,
                value = ccizer_surface_state.channel,
                width = 60,
                notifier = function(value)
                    if not ccizer_surface_state.building then ccizer_surface_state.channel = value end
                end
            },
            ccizer_surface_vb:button{
                text = "Reset",
                width = 60,
                notifier = function() ccizer_surface_reset_values() end
            }
        },
        columns
    }

    local keyhandler = function(dlg, key)
        if key.name == "esc" then
            dlg:close()
            ccizer_surface_dialog = nil
            return nil
        end
        return key
    end

    ccizer_surface_dialog = renoise.app():show_custom_dialog("Paketti CCizer Control Surface - " .. selected_file.display_name, content, keyhandler)
    ccizer_surface_state.building = false
    if port_index > 1 then ccizer_surface_open_output(port_items[port_index]) end
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
                                preview = preview .. "Reached maximum CC limit for MIDI Control device\n\n"
                            elseif #mappings > 0 then
                                preview = preview .. string.format("Can add %d more CC mappings\n\n", MAX_CC_LIMIT - #mappings)
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

renoise.tool():add_keybinding{name = "Global:Paketti:CCizer Loader...", invoke = PakettiCCizerLoader}


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
    
    -- Load the MIDI Control device SILENTLY  
    print("-- MIDI Control Text: Loading *Instr. MIDI Control device silently...")
    loadnative("Audio/Effects/Native/*Instr. MIDI Control", nil, nil, nil, true)
    
    -- Give the device a moment to load, then apply XML
    renoise.app():show_status("Loading MIDI Control device...")
    
    -- Generate the XML preset with our CC mappings
    local xml_content = paketti_generate_midi_control_xml(cc_mappings)
    
    -- Extract filename without path and extension
    local filename = selected_textfile:match("([^/\\]+)$")  -- Get filename from path
    local name_without_ext = filename:match("^(.+)%..+$") or filename  -- Remove extension, fallback to full filename
    
    local function apply_xml_and_finish()
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
    
    -- Wait for device to load before applying XML
    local didiRun = false
    local device_timer_func
    device_timer_func = function()
        didiRun = true
        if didiRun == true then
            renoise.tool():remove_timer(device_timer_func)
        end
        apply_xml_and_finish()
    end
    renoise.tool():add_timer(device_timer_func, 200)
  end
  

   --[[
   -- Menu entries for the new function
   PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   PakettiAddMenuEntry{name="DSP Device:Paketti:Xperimental/WIP:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   PakettiAddMenuEntry{name="Sample FX Mixer:Paketti:Xperimental/WIP:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   PakettiAddMenuEntry{name="Mixer:Paketti:Xperimental/WIP:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
   renoise.tool():add_keybinding{name="Global:Paketti:Create MIDI Control from Text File", invoke=function() PakettiCreateMIDIControlFromTextFile() end}
]]--
-- Function to apply CCizer mappings to the currently selected device (or create new one if needed)
local function apply_ccizer_to_selected_device(mappings, filename)
    if not mappings or #mappings == 0 then
        renoise.app():show_warning("No valid MIDI CC mappings found in file")
        return
    end

    local song = renoise.song()
    local selected_device = song.selected_device
    
    -- Check if we have a selected MIDI Control device
    if selected_device and selected_device.name == "*Instr. MIDI Control" then
        print("-- CCizer: Applying CCizer mappings to existing selected device")
        print(string.format("-- CCizer: Using %d / %d CC mappings", #mappings, MAX_CC_LIMIT))
        
        -- Generate the XML preset with our CC mappings
        local xml_content = paketti_generate_midi_control_xml(mappings)
        
        -- Apply the XML to the selected device
        selected_device.active_preset_data = xml_content
        selected_device.display_name = filename
        
        print("-- CCizer: Successfully applied CC mappings to selected device with name: " .. filename)
        
        -- Create status message with CC count information
        local status_message = string.format("Applied CCizer '%s' with %d/%d CC mappings to selected device", filename, #mappings, MAX_CC_LIMIT)
        if #mappings == MAX_CC_LIMIT then
            status_message = status_message .. " (max reached)"
        else
            status_message = status_message .. string.format(" (%d slots available)", MAX_CC_LIMIT - #mappings)
        end
        
        renoise.app():show_status(status_message)
        
        -- Wait a tick, then open parameter editor and remove timer
        local didiRun = false
        local timer_func
        timer_func = function()
            didiRun = true
            if didiRun == true then
                renoise.tool():remove_timer(timer_func)
            end
            if PAKETTI_HAS_CANVAS then
                PakettiCanvasExperimentsInit()
            end
        end
        renoise.tool():add_timer(timer_func, 100)
    else
        -- No device selected or wrong device type - create new MIDI Control device
        print("-- CCizer: No MIDI Control device selected, creating new one")
        print(string.format("-- CCizer: Using %d / %d CC mappings", #mappings, MAX_CC_LIMIT))
        
        -- Load the MIDI Control device SILENTLY
        print("-- CCizer: Loading *Instr. MIDI Control device silently...")
        loadnative("Audio/Effects/Native/*Instr. MIDI Control", nil, nil, nil, true)
        
        -- Give the device a moment to load, then apply XML and open parameter editor
        renoise.app():show_status("Loading MIDI Control device...")
        
        -- Generate the XML preset with our CC mappings
        local xml_content = paketti_generate_midi_control_xml(mappings)
        
        -- Using anonymous timer functions prevents multiple registrations
        
        local function apply_xml_and_open_editor()
            -- Find the device that was just loaded
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
                device.display_name = filename
                print("-- CCizer: Successfully applied CC mappings to new device with name: " .. filename)
                
                -- Create status message with CC count information
                local status_message = string.format("Created MIDI Control device '%s' with %d/%d CC mappings", filename, #mappings, MAX_CC_LIMIT)
                if #mappings == MAX_CC_LIMIT then
                    status_message = status_message .. " (max reached)"
                else
                    status_message = status_message .. string.format(" (%d slots available)", MAX_CC_LIMIT - #mappings)
                end
                
                renoise.app():show_status(status_message)
                
                -- Wait a tick, then open parameter editor and remove timer
                local didiRun = false
                local timer_func
                timer_func = function()
                    didiRun = true
                    if didiRun == true then
                        renoise.tool():remove_timer(timer_func)
                    end
                    if PAKETTI_HAS_CANVAS then
                        PakettiCanvasExperimentsInit()
                    end
                end
                renoise.tool():add_timer(timer_func, 100)
            else
                renoise.app():show_error("Failed to find or load MIDI Control device")
            end
        end
        
        -- Wait for device to load before applying XML
        local didiRun = false
        local device_timer_func
        device_timer_func = function()
            didiRun = true
            if didiRun == true then
                renoise.tool():remove_timer(device_timer_func)
            end
            apply_xml_and_open_editor()
        end
        renoise.tool():add_timer(device_timer_func, 200)
    end
end

-- Function to load a specific CCizer file to selected device (or create new one if needed)
local function load_ccizer_file_to_selected_device(ccizer_filename)
    local ccizer_files = scan_ccizer_files()
    local target_file = nil
    
    for _, file in ipairs(ccizer_files) do
        if file.name == ccizer_filename then
            target_file = file
            break
        end
    end
    
    if not target_file then
        renoise.app():show_status("CCizer file '" .. ccizer_filename .. "' not found in ccizer folder")
        return
    end
    
    local mappings = load_ccizer_file(target_file.full_path)
    if mappings then
        apply_ccizer_to_selected_device(mappings, target_file.display_name)
    end
end

-- Function to show CCizer dialog that targets selected device (or creates new one if needed)
function PakettiCCizerLoaderToSelectedDevice()
    local selected_device = renoise.song().selected_device

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
        
        vb:text{
            text = "Loading CCizer file to MIDI Control device:",
            font = "bold",
            style = "strong"
        },
        
        vb:text{
            text = selected_device and selected_device.name == "*Instr. MIDI Control" and 
                   ("Selected Device: " .. selected_device.display_name) or
                   "Will create new MIDI Control device",
            font = "bold"
        },
        
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
                    local selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load CCizer Text File to MIDI Control Device")
                    if selected_textfile and selected_textfile ~= "" then
                        local mappings = load_ccizer_file(selected_textfile)
                        if mappings then
                            local filename = selected_textfile:match("([^/\\]+)$")
                            local name_without_ext = filename:match("^(.+)%..+$") or filename
                            apply_ccizer_to_selected_device(mappings, name_without_ext)
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
                                preview = preview .. "Reached maximum CC limit for MIDI Control device\n\n"
                            elseif #mappings > 0 then
                                preview = preview .. string.format("Can add %d more CC mappings\n\n", MAX_CC_LIMIT - #mappings)
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
                text = "Apply to Device",
                width = bottomButtonWidth + 20,
                notifier = function()
                    if files[selected_file_index] then
                        local mappings = load_ccizer_file(files[selected_file_index].full_path)
                        if mappings then
                            apply_ccizer_to_selected_device(mappings, files[selected_file_index].display_name)
                            dialog:close()
                            dialog = nil
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
        
    dialog = renoise.app():show_custom_dialog("CCizer TXT->MIDI Control Loader", content, my_keyhandler_func)
end

-- Generate menu entries for actual CCizer files found in ccizer folder
local function create_ccizer_menu_entries()
    local ccizer_files = scan_ccizer_files()
    
    -- Limit to first 10 files to avoid menu bloat
    local max_files = math.min(#ccizer_files, 10)
    
    for i = 1, max_files do
        local file = ccizer_files[i]
        local display_name = file.display_name -- Already has .txt removed
        local filename = file.name -- Full filename with .txt
        
        PakettiAddMenuEntry{name = "DSP Device:Paketti:CCizer:Load " .. display_name, invoke = function() load_ccizer_file_to_selected_device(filename) end}
        PakettiAddMenuEntry{name = "Sample FX Mixer:Paketti:CCizer:Load " .. display_name, invoke = function() load_ccizer_file_to_selected_device(filename) end}
        PakettiAddMenuEntry{name = "Mixer:Paketti:CCizer:Load " .. display_name, invoke = function() load_ccizer_file_to_selected_device(filename) end}
        renoise.tool():add_keybinding{name = "Global:Paketti:CCizer Load " .. display_name, invoke = function() load_ccizer_file_to_selected_device(filename) end}
    end
end

-- Create the dynamic menu entries
create_ccizer_menu_entries()

-- Function to load any CCizer file to selected device via file browser (or create new one if needed)
local function load_ccizer_file_browse_to_selected_device()

    local selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load CCizer Text File to MIDI Control Device")
    if selected_textfile and selected_textfile ~= "" then
        local mappings = load_ccizer_file(selected_textfile)
        if mappings then
            local filename = selected_textfile:match("([^/\\]+)$")
            local name_without_ext = filename:match("^(.+)%..+$") or filename
            apply_ccizer_to_selected_device(mappings, name_without_ext)
        end
    end
end

PakettiAddMenuEntry{name = "DSP Device:Paketti:CCizer:Open CCizer Dialog", invoke = PakettiCCizerLoaderToSelectedDevice}
PakettiAddMenuEntry{name = "Sample FX Mixer:Paketti:CCizer:Open CCizer Dialog", invoke = PakettiCCizerLoaderToSelectedDevice}
PakettiAddMenuEntry{name = "Mixer:Paketti:CCizer:Open CCizer Dialog", invoke = PakettiCCizerLoaderToSelectedDevice}

PakettiAddMenuEntry{name = "DSP Device:Paketti:CCizer:Load from File", invoke = load_ccizer_file_browse_to_selected_device}
PakettiAddMenuEntry{name = "Sample FX Mixer:Paketti:CCizer:Load from File", invoke = load_ccizer_file_browse_to_selected_device}
PakettiAddMenuEntry{name = "Mixer:Paketti:CCizer:Load from File", invoke = load_ccizer_file_browse_to_selected_device}

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:MIDI:CCizer Control Surface...", invoke = function() PakettiCCizerControlSurface() end}
renoise.tool():add_keybinding{name = "Global:Paketti:CCizer Control Surface", invoke = function() PakettiCCizerControlSurface() end}
renoise.tool():add_midi_mapping{name = "Paketti:CCizer Control Surface", invoke = function(message) if message:is_trigger() then PakettiCCizerControlSurface() end end}

-- COMPREHENSIVE RECURSIVE RENOISE API EXPLORER
-- This explores EVERY SINGLE subobject, property, method in the entire Renoise API
function paketti_debug_dump_complete_renoise_api()
  print("=== COMPREHENSIVE RECURSIVE RENOISE API EXPLORATION ===")
  
  local explored_count = 0
  local max_objects = 500 -- Prevent runaway
  local visited = {} -- Prevent circular references
  
  -- Function to recursively explore any object using oprint()
  local function explore_object(obj, path, max_depth, current_depth)
    current_depth = current_depth or 0
    max_depth = max_depth or 8
    
    if current_depth >= max_depth or explored_count >= max_objects then
      return
    end
    
    if visited[obj] then
      return
    end
    
    visited[obj] = true
    explored_count = explored_count + 1
    
    print(string.format("\n%s==== %s ====", string.rep("  ", current_depth), path))
    oprint(obj)
    
    -- Try to find and explore all sub-objects
    local obj_type = type(obj)
    
    if obj_type == "userdata" or obj_type == "table" then
      -- Try to explore common properties that might be objects
      local properties_to_explore = {
        -- Window/UI objects
        "window", "dialog", "dialogs", "view", "frame", "panel",
        -- Song structure objects  
        "instruments", "phrases", "samples", "tracks", "patterns", "devices",
        "sequencer", "transport", "selection_in_pattern", "selection_in_phrase",
        -- Device/plugin objects
        "plugin_device", "plugin_properties", "parameters", "presets",
        "midi_input_properties", "midi_output_properties", "macros",
        -- Sample objects
        "sample_buffer", "sample_mapping", "sample_modulation_sets", "sample_device_chains",
        -- Pattern objects
        "lines", "automation", "pattern_track", "pattern_tracks",
        -- Script objects
        "script", "phrase_script", "lua_script"
      }
      
      for _, prop in ipairs(properties_to_explore) do
        local success, sub_obj = pcall(function() return obj[prop] end)
        if success and sub_obj and not visited[sub_obj] then
          explore_object(sub_obj, path .. "." .. prop, max_depth, current_depth + 1)
        end
      end
      
      -- Try to explore numbered array elements
      for i = 1, 10 do
        local success, sub_obj = pcall(function() return obj[i] end)
        if success and sub_obj and not visited[sub_obj] then
          explore_object(sub_obj, path .. "[" .. i .. "]", max_depth, current_depth + 1)
        end
      end
    end
  end
  
  local song = renoise.song()
  local app = renoise.app()
  
  -- Start comprehensive exploration
  print("=== EXPLORING renoise.app() AND ALL SUBOBJECTS ===")
  explore_object(app, "renoise.app()", 6)
  
  print("\n=== EXPLORING renoise.song() AND ALL SUBOBJECTS ===")
  explore_object(song, "renoise.song()", 6)
  
  -- Deep dive into specific areas that might have editor controls
  print("\n=== DEEP DIVE: INSTRUMENT HIERARCHY ===")
  if #song.instruments > 0 then
    local instrument = song.instruments[1]
    explore_object(instrument, "song.instruments[1]", 4)
    
    if #instrument.phrases > 0 then
      for i = 1, math.min(3, #instrument.phrases) do
        local phrase = instrument.phrases[i]
        explore_object(phrase, string.format("song.instruments[1].phrases[%d]", i), 3)
      end
    end
    
    if #instrument.samples > 0 then
      for i = 1, math.min(3, #instrument.samples) do
        local sample = instrument.samples[i]
        explore_object(sample, string.format("song.instruments[1].samples[%d]", i), 3)
      end
    end
  end
  
  print("\n=== DEEP DIVE: TRACK HIERARCHY ===")
  if #song.tracks > 0 then
    for i = 1, math.min(3, #song.tracks) do
      local track = song.tracks[i]
      explore_object(track, string.format("song.tracks[%d]", i), 3)
      
      if #track.devices > 0 then
        for j = 1, math.min(2, #track.devices) do
          local device = track.devices[j]
          explore_object(device, string.format("song.tracks[%d].devices[%d]", i, j), 2)
        end
      end
    end
  end
  
  print("\n=== DEEP DIVE: PATTERN HIERARCHY ===")
  if #song.patterns > 0 then
    for i = 1, math.min(3, #song.patterns) do
      local pattern = song.patterns[i]
      explore_object(pattern, string.format("song.patterns[%d]", i), 3)
      
      if pattern.tracks and #pattern.tracks > 0 then
        for j = 1, math.min(2, #pattern.tracks) do
          local pattern_track = pattern.tracks[j]
          explore_object(pattern_track, string.format("song.patterns[%d].tracks[%d]", i, j), 2)
        end
      end
    end
  end
  
  print(string.format("\n=== COMPREHENSIVE EXPLORATION COMPLETE ==="))
  print(string.format("Total objects explored: %d", explored_count))
  print("Search the output above for ANY method or property related to:")
  print("- editor_visible, script_editor, phrase_editor")
  print("- show_, hide_, toggle_, open_, close_")
  print("- window, dialog, frame, panel visibility")
  print("- ANY function that might control UI state")
  
  renoise.app():show_message(string.format("Comprehensive Renoise API exploration complete!\n\n" ..
    "Explored %d objects recursively.\n" ..
    "Check terminal for EVERYTHING in the Renoise API.\n" ..
    "Search for editor/visible/show/hide/toggle methods!", explored_count))
end

-- Add debug menu entry
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:!Preferences:Debug:Dump Complete Renoise API", invoke = paketti_debug_dump_complete_renoise_api}
