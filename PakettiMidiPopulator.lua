-- Ensure the renoise API is available
local vb = renoise.ViewBuilder()
local midi_input_devices, midi_output_devices, plugin_dropdown_items, available_plugins, ccizer_files, ccizer_dropdown_items
local dialog_content
local dialog=nil

local prefs = renoise.tool().preferences
local separator = package.config:sub(1,1)
local MAX_CC_LIMIT = 35 -- Maximum CC mappings for MIDI Control device

-- Preferences for storing selected values
local midi_input_device = {}
local midi_input_channel = {}
local midi_output_device = {}
local midi_output_channel = {}
local selected_plugin = {}
local selected_ccizer_file = {}
local selected_ccizer_file_paths = {} -- Store custom file paths for browsed files
local open_external_editor = false

-- Preset storage for MIDI Populator
local recent_presets = {} -- Table of {name, path} for recently used presets
local recent_presets_dropdown_items = {"<None>"} -- Dropdown items for preset selector
local MAX_RECENT_PRESETS = 10 -- Maximum number of recent presets to remember

-- Helper function for table indexing
function table.index_of(tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return index
    end
  end
  return nil
end

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
    local xml_content = paketti_generate_midi_control_xml(mappings)
    
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

-- Initialize variables when needed
local function initialize_variables()
  midi_input_devices = {"<None>"}
  for _, device in ipairs(renoise.Midi.available_input_devices()) do
    table.insert(midi_input_devices, device)
  end

  midi_output_devices = {"<None>"}
  for _, device in ipairs(renoise.Midi.available_output_devices()) do
    table.insert(midi_output_devices, device)
  end

  -- Ensure there are at least two items in the lists
  if #midi_input_devices < 2 then
    table.insert(midi_input_devices, "No MIDI Input Devices - do not select this")
  end
  if #midi_output_devices < 2 then
    table.insert(midi_output_devices, "No MIDI Output Devices - do not select this")
  end

  plugin_dropdown_items = {"<None>"}
  available_plugins = renoise.song().selected_instrument.plugin_properties.available_plugin_infos
  for _, plugin_info in ipairs(available_plugins) do
    if plugin_info.path:find("/AU/") then
      table.insert(plugin_dropdown_items, "AU: " .. plugin_info.short_name)
    elseif plugin_info.path:find("/VST/") then
      table.insert(plugin_dropdown_items, "VST: " .. plugin_info.short_name)
    elseif plugin_info.path:find("/VST3/") then
      table.insert(plugin_dropdown_items, "VST3: " .. plugin_info.short_name)
    end
  end

  -- Scan for CCizer files
  ccizer_files = scan_ccizer_files()
  ccizer_dropdown_items = {"<None>"}
  for _, file in ipairs(ccizer_files) do
    table.insert(ccizer_dropdown_items, file.display_name)
  end
  
  -- Add browse option
  table.insert(ccizer_dropdown_items, "<Browse>")
  
  -- Ensure there's at least one item in the list
  if #ccizer_dropdown_items < 2 then
    table.insert(ccizer_dropdown_items, "No CCizer files found")
  end
  
  for i = 1, 16 do
    midi_input_device[i] = midi_input_devices[1]
    midi_input_channel[i] = i
    midi_output_device[i] = midi_output_devices[1]
    midi_output_channel[i] = i
    selected_plugin[i] = plugin_dropdown_items[1]
    selected_ccizer_file[i] = ccizer_dropdown_items[1]
  end
end

local note_columns_switch, effect_columns_switch, delay_column_switch, volume_column_switch, panning_column_switch, sample_effects_column_switch, collapsed_switch, incoming_audio_switch, populate_sends_switch, external_editor_switch



local function simplifiedSendCreationNaming()
  local send_tracks = {}
  local count = 0

  -- Collect all send tracks
  for i = 1, #renoise.song().tracks do
    if renoise.song().tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
      -- Store the index and name of each send track
      table.insert(send_tracks, {index = count, name = renoise.song().tracks[i].name, track_number = i - 1})
      count = count + 1
    end
  end

  if count == 0 then
    renoise.app():show_status("No Send tracks found")
    return
  end

  -- Check preference for Send device type (1 = Send, 2 = Multiband Send)
  local use_multiband = (prefs.pakettiMidiPopulator.sendDeviceType.value == 2)
  local device_path = use_multiband and "Audio/Effects/Native/#Multiband Send" or "Audio/Effects/Native/#Send"
  local device_name = use_multiband and "#Multiband Send" or "#Send"

  print(string.format("-- Paketti MIDI Populator: Creating %d %s devices", count, device_name))

  -- Create each Send device one at a time using the proper loadnative architecture
  for i = 1, count do
    local send_track = send_tracks[i]
    
    print(string.format("-- Paketti MIDI Populator: Creating device %d/%d for send track '%s' (index %d)", i, count, send_track.name, send_track.index))
    
    -- Use loadnative which should handle XML injection automatically
    loadnative(device_path)
    
    -- Get the newly loaded device (loadnative sets selected_device)
    local device = renoise.song().selected_device
    if device and (device.name == "#Send" or device.name == "#Multiband Send") then
      -- MANUALLY apply the preset data since automatic isn't working
      if use_multiband then
        device.active_preset_data = read_file("Presets/PakettiMultiSend.xml")
      else
        device.active_preset_data = read_file("Presets/PakettiSend.xml")
      end
      
      -- Set send destination parameter(s) AFTER preset is applied
      if use_multiband then
        -- For Multiband Send: set all three bands to the same destination
        device.parameters[2].value = send_track.index  -- Low band send destination
        device.parameters[4].value = send_track.index  -- Mid band send destination  
        device.parameters[6].value = send_track.index  -- High band send destination
      else
        -- For regular Send: parameter 3 is the Receiver (send destination)
        device.parameters[3].value = send_track.index
      end
      
      -- Rename device to send track name
      device.display_name = send_track.name
      print(string.format("-- Paketti MIDI Populator: Successfully created %s device '%s' targeting send track %d", device_name, send_track.name, send_track.index))
    else
      print(string.format("-- Paketti MIDI Populator: ERROR - Failed to load %s device", device_name))
    end
  end

  local device_type = use_multiband and "Multiband Send" or "Send"
  renoise.app():show_status("Created " .. count .. " " .. device_type .. " devices with proper XML injection")
end

local function MidiInitChannelTrackInstrument(track_index)
  local midi_in_device = midi_input_device[track_index]
  local midi_in_channel = midi_input_channel[track_index]
  local midi_out_device = midi_output_device[track_index]
  local midi_out_channel = midi_output_channel[track_index]
  local plugin = selected_plugin[track_index]
  local ccizer_file = selected_ccizer_file[track_index]
  

  local note_columns = note_columns_switch.value
  local effect_columns = effect_columns_switch.value
  local delay_column = (delay_column_switch.value == 2)
  local volume_column = (volume_column_switch.value == 2)
  local panning_column = (panning_column_switch.value == 2)
  local sample_effects_column = (sample_effects_column_switch.value == 2)
  local collapsed = (collapsed_switch.value == 2)
  local incoming_audio = (incoming_audio_switch.value == 2)
  local populate_sends = (populate_sends_switch.value == 2)
  local open_ext_editor = (external_editor_switch.value == 2)

  -- Create a new track
  renoise.song():insert_track_at(track_index)
  local new_track = renoise.song():track(track_index)
  local track_name =  string.format("%02d", midi_in_channel)
  if midi_in_device ~= "<None>" and midi_in_device ~= "No MIDI Input Devices - do not select this" then
    track_name = track_name .. " " .. midi_in_device .. ":" .. string.format("%02d", midi_in_channel) .. ">"
  end
  if plugin and plugin ~= "<None>" then
    track_name = track_name .. " (" .. plugin:sub(5) .. ")"
  end
  if midi_out_device ~= "<None>" and midi_out_device ~= "No MIDI Output Devices - do not select this" then
    track_name = track_name .. " >" .. midi_out_device .. ":" .. string.format("%02d", midi_out_channel)
  end
  new_track.name = track_name
  renoise.song().selected_track_index = track_index

  -- Set track column settings
  new_track.visible_note_columns = note_columns
  new_track.visible_effect_columns = effect_columns
  new_track.delay_column_visible = delay_column
  new_track.volume_column_visible = volume_column
  new_track.panning_column_visible = panning_column
  new_track.sample_effects_column_visible = sample_effects_column
  new_track.collapsed = collapsed

  -- Populate send devices
  if populate_sends then
    simplifiedSendCreationNaming()
  end

  -- Load *Line Input device if incoming audio is set to ON
  if incoming_audio then
    local success, device = pcall(function()
      return loadnative("Audio/Effects/Native/#Line Input")
    end)
    if success and device then
      device:insert_at(#new_track.devices + 1)
    end
  end

  -- Create a new instrument
  renoise.song():insert_instrument_at(track_index)
  local new_instrument = renoise.song():instrument(track_index)
  local instrument_name = "TR" .. string.format("%02d", midi_in_channel)
  if midi_in_device ~= "<None>" and midi_in_device ~= "No MIDI Input Devices - do not select this" then
    instrument_name = instrument_name .. " " .. midi_in_device .. ":" .. string.format("%02d", midi_in_channel) .. ">"
  end
  if plugin and plugin ~= "<None>" then
    instrument_name = instrument_name .. " (" .. plugin:sub(5) .. ")"
  end
  if midi_out_device ~= "<None>" and midi_out_device ~= "No MIDI Output Devices - do not select this" then
    instrument_name = instrument_name .. " >" .. midi_out_device .. ":" .. string.format("%02d", midi_out_channel)
  end
  new_instrument.name = instrument_name

  -- Set MIDI input properties for the new instrument only if a valid device is selected
  if midi_in_device ~= "<None>" and midi_in_device ~= "No MIDI Input Devices - do not select this" then
    -- Check if the device exists in available devices
    local device_exists = false
    for _, device in ipairs(renoise.Midi.available_input_devices()) do
      if device == midi_in_device then
        device_exists = true
        break
      end
    end
    
    if device_exists then
      new_instrument.midi_input_properties.device_name = midi_in_device
      new_instrument.midi_input_properties.channel = midi_in_channel
      new_instrument.midi_input_properties.assigned_track = track_index
    end
  end

  -- Set the output device for the new track only if a valid device is selected
  if midi_out_device ~= "<None>" and midi_out_device ~= "No MIDI Output Devices - do not select this" then
    -- Check if the device exists in available devices
    local device_exists = false
    for _, device in ipairs(renoise.Midi.available_output_devices()) do
      if device == midi_out_device then
        device_exists = true
        break
      end
    end
    
    if device_exists then
      new_instrument.midi_output_properties.device_name = midi_out_device
      new_instrument.midi_output_properties.channel = midi_out_channel
    end
  end

  -- Load the selected plugin for the new instrument
  if plugin and plugin ~= "<None>" then
    local plugin_path
    for _, plugin_info in ipairs(available_plugins) do
      if plugin_info.short_name == plugin:sub(5) then
        plugin_path = plugin_info.path
        break
      end
    end
    if plugin_path then
      new_instrument.plugin_properties:load_plugin(plugin_path)
      -- Rename the instrument with the same format
      local plugin_instrument_name = "TR" .. string.format("%02d", midi_in_channel)
      if midi_in_device ~= "<None>" and midi_in_device ~= "No MIDI Input Devices - do not select this" then
        plugin_instrument_name = plugin_instrument_name .. " " .. midi_in_device .. ":" .. string.format("%02d", midi_in_channel) .. ">"
      end
      plugin_instrument_name = plugin_instrument_name .. " (" .. plugin:sub(5) .. ")"
      if midi_out_device ~= "<None>" and midi_out_device ~= "No MIDI Output Devices - do not select this" then
        plugin_instrument_name = plugin_instrument_name .. " >" .. midi_out_device .. ":" .. string.format("%02d", midi_out_channel)
      end
      new_instrument.name = plugin_instrument_name

      -- Select the instrument to ensure devices are mapped correctly
      renoise.song().selected_instrument_index = track_index

      -- Update track name to match instrument name exactly
      renoise.song().selected_track.name = plugin_instrument_name

      -- Add *Instr. Automation and *Instr. MIDI Control to the track immediately after the plugin is loaded
      local success_auto, instr_automation_device = pcall(function()
        return loadnative("Audio/Effects/Native/*Instr. Automation")
      end)
      if success_auto and instr_automation_device then
        instr_automation_device:insert_at(#new_track.devices + 1)
        instr_automation_device.parameters[1].value = track_index - 1
      end

      local success_midi, instr_midi_control_device = pcall(function()
        return loadnative("Audio/Effects/Native/*Instr. MIDI Control")
      end)
      if success_midi and instr_midi_control_device then
        instr_midi_control_device:insert_at(#new_track.devices + 1)
        instr_midi_control_device.parameters[1].value = track_index - 1
      end

      -- Open external editor if the option is enabled
      if open_ext_editor and new_instrument.plugin_properties.plugin_device then
        new_instrument.plugin_properties.plugin_device.external_editor_visible = true
      end
    end
  end

  -- Apply CCizer mappings if a CCizer file is selected
  if ccizer_file and ccizer_file ~= "<None>" and ccizer_file ~= "No CCizer files found" and ccizer_file ~= "<Browse>" then
    print(string.format("-- CCizer: Track %d selected CCizer file: '%s'", track_index, ccizer_file))
    
    -- Check if this is a custom browsed file first
    local ccizer_file_path = nil
    local ccizer_display_name = ccizer_file
    
    -- Check if this is a browsed file (format: [filename])
    local browsed_name = ccizer_file:match("^%[(.+)%]$")
    if browsed_name and selected_ccizer_file_paths and selected_ccizer_file_paths[track_index] then
      -- Use the custom browsed file path
      ccizer_file_path = selected_ccizer_file_paths[track_index]
      ccizer_display_name = browsed_name
      print(string.format("-- CCizer: Using browsed file: '%s' -> '%s'", ccizer_display_name, ccizer_file_path))
    else
      -- Find the CCizer file info from scanned files
      local ccizer_file_info = nil
      for _, file in ipairs(ccizer_files) do
        if file.display_name == ccizer_file then
          ccizer_file_info = file
          break
        end
      end
      
      if ccizer_file_info then
        ccizer_file_path = ccizer_file_info.full_path
        ccizer_display_name = ccizer_file_info.display_name
        print(string.format("-- CCizer: Using scanned file: '%s' -> '%s'", ccizer_display_name, ccizer_file_path))
      else
        print(string.format("-- CCizer ERROR: Could not find CCizer file info for '%s'", ccizer_file))
        print("-- CCizer ERROR: Available CCizer files:")
        for i, file in ipairs(ccizer_files) do
          print(string.format("  [%d] '%s' -> '%s'", i, file.display_name, file.name))
        end
      end
    end
    
    if ccizer_file_path then
      local mappings = load_ccizer_file(ccizer_file_path)
      if mappings then
        print(string.format("-- CCizer: Successfully loaded %d mappings for track %d", #mappings, track_index))
        print(string.format("-- CCizer: Loading *Instr. MIDI Control device for track %d", track_index))
        
        -- Ensure correct track is selected before loading device
        renoise.song().selected_track_index = track_index
        -- Load the *Instr. MIDI Control device
        print("-- CCizer: Loading *Instr. MIDI Control device...")
        loadnative("Audio/Effects/Native/*Instr. MIDI Control")
        
        -- Get the device that was just loaded (loadnative sets selected_device)
        local instr_midi_control_device = renoise.song().selected_device
        
        if instr_midi_control_device and instr_midi_control_device.name == "*Instr. MIDI Control" then
          -- Set the instrument parameter to point to the correct instrument
          if #instr_midi_control_device.parameters > 0 then
            instr_midi_control_device.parameters[1].value = track_index - 1
          end
          
          -- Generate and apply the CCizer mappings
          local xml_content = paketti_generate_midi_control_xml(mappings)
          
          -- Apply the preset data
          instr_midi_control_device.active_preset_data = xml_content
          
          -- Set the device name to the CCizer file display name
          instr_midi_control_device.display_name = ccizer_display_name
          print(string.format("-- CCizer: Successfully applied %d CC mappings from '%s' to track %d", #mappings, ccizer_display_name, track_index))
          
          -- Show status with CC count information
          local status_message = string.format("MIDI Control device '%s' created with %d/%d CC mappings on track %d", ccizer_display_name, #mappings, MAX_CC_LIMIT, track_index)
          if #mappings == MAX_CC_LIMIT then
              status_message = status_message .. " (max reached)"
          else
              status_message = status_message .. string.format(" (%d slots available)", MAX_CC_LIMIT - #mappings)
          end
          renoise.app():show_status(status_message)
        else
          print(string.format("-- CCizer ERROR: Failed to load *Instr. MIDI Control device for track %d", track_index))
        end
      else
        print(string.format("-- CCizer ERROR: Failed to load mappings from '%s'", ccizer_file_path))
      end
    else
      print(string.format("-- CCizer ERROR: No file path found for '%s'", ccizer_file))
    end
  end
end

local function on_midi_input_switch_changed(value)
  for i = 1, 16 do
    midi_input_device[i] = midi_input_devices[value]
  end
  -- Update the GUI
  for i = 1, 16 do
    local popup = vb.views["midi_input_popup_" .. i]
    if popup then
      popup.value = value
    end
  end
end

local function on_midi_output_switch_changed(value)
  for i = 1, 16 do
    midi_output_device[i] = midi_output_devices[value]
  end
  -- Update the GUI
  for i = 1, 16 do
    local popup = vb.views["midi_output_popup_" .. i]
    if popup then
      popup.value = value
    end
  end
end

-- Randomize plugin selection
local function randomize_plugin_selection(plugin_type)
  local plugins = {}
  for _, plugin_info in ipairs(available_plugins) do
    if plugin_info.path:find(plugin_type) then
      table.insert(plugins, plugin_info.short_name)
    end
  end

  for i = 1, 16 do
    if #plugins > 0 then
      local random_plugin = plugins[math.random(#plugins)]
      for j, item in ipairs(plugin_dropdown_items) do
        if item:find(plugin_type:sub(2, -2)) and item:find(random_plugin) then
          selected_plugin[i] = item
          vb.views["plugin_popup_" .. i].value = j
          break
        end
      end
    end
  end
end

local function randomize_au_plugins()
  randomize_plugin_selection("/AU/")
end

local function randomize_vst_plugins()
  randomize_plugin_selection("/VST/")
end

local function randomize_vst3_plugins()
  randomize_plugin_selection("/VST3/")
end

local function clear_plugin_selection()
  for i = 1, 16 do
    selected_plugin[i] = plugin_dropdown_items[1]
    vb.views["plugin_popup_" .. i].value = 1
  end
end

function horizontal_rule()
    return vb:horizontal_aligner{
      mode="justify", 
      width="100%", 
      vb:space{width=10}, 
      vb:row{height=2, style="panel",width="30%"}, 
      vb:space{width=2}
    }
end


local function save_preferences()
  -- Update preferences based on current switch states
  prefs.pakettiMidiPopulator.volumeColumn.value = (volume_column_switch.value == 2)
  prefs.pakettiMidiPopulator.panningColumn.value = (panning_column_switch.value == 2)
  prefs.pakettiMidiPopulator.delayColumn.value = (delay_column_switch.value == 2)
  prefs.pakettiMidiPopulator.sampleEffectsColumn.value = (sample_effects_column_switch.value == 2)
  prefs.pakettiMidiPopulator.noteColumns.value = tonumber(note_columns_switch.value) or 1.0
  prefs.pakettiMidiPopulator.effectColumns.value = tonumber(effect_columns_switch.value) or 1.0
  prefs.pakettiMidiPopulator.collapsed.value = (collapsed_switch.value == 2)
  prefs.pakettiMidiPopulator.incomingAudio.value = (incoming_audio_switch.value == 2)
  prefs.pakettiMidiPopulator.populateSends.value = (populate_sends_switch.value == 2)
  -- Note: sendDeviceType is managed globally in preferences and doesn't need to be saved here
  -- If you have a preference for external_editor_switch, uncomment the next line
  -- prefs.pakettiMidiPopulator.externalEditor.value = (external_editor_switch.value == 2)
end

-- Add preset to recent list and update dropdown
local function add_preset_to_recent(name, filepath)
  -- Check if already in list
  for i, preset in ipairs(recent_presets) do
    if preset.path == filepath then
      -- Move to top of list
      table.remove(recent_presets, i)
      break
    end
  end
  
  -- Insert at beginning
  table.insert(recent_presets, 1, {name = name, path = filepath})
  
  -- Trim to max size
  while #recent_presets > MAX_RECENT_PRESETS do
    table.remove(recent_presets)
  end
  
  -- Rebuild dropdown items
  recent_presets_dropdown_items = {"<None>"}
  for _, preset in ipairs(recent_presets) do
    table.insert(recent_presets_dropdown_items, preset.name)
  end
  
  -- Update dropdown if it exists
  if vb and vb.views and vb.views["preset_dropdown"] then
    vb.views["preset_dropdown"].items = recent_presets_dropdown_items
    vb.views["preset_dropdown"].value = 2 -- Select the just-added preset
  end
end

-- Remove preset from recent list
local function remove_preset_from_recent(index)
  if index > 1 and index <= #recent_presets_dropdown_items then
    local preset_index = index - 1 -- Account for <None> at position 1
    table.remove(recent_presets, preset_index)
    
    -- Rebuild dropdown items
    recent_presets_dropdown_items = {"<None>"}
    for _, preset in ipairs(recent_presets) do
      table.insert(recent_presets_dropdown_items, preset.name)
    end
    
    -- Update dropdown if it exists
    if vb and vb.views and vb.views["preset_dropdown"] then
      vb.views["preset_dropdown"].items = recent_presets_dropdown_items
      vb.views["preset_dropdown"].value = 1 -- Reset to <None>
    end
  end
end

-- Save MIDI Populator preset to file
local function save_midi_populator_preset(filepath)
  local file = io.open(filepath, "w")
  if not file then
    renoise.app():show_error("Cannot write to file: " .. filepath)
    return false
  end
  
  -- Write header
  file:write("# Paketti MIDI Populator Preset\n")
  file:write("# Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
  
  -- Write global settings
  file:write("# Global Settings\n")
  file:write("note_columns=" .. tostring(note_columns_switch.value) .. "\n")
  file:write("effect_columns=" .. tostring(effect_columns_switch.value) .. "\n")
  file:write("delay_column=" .. (delay_column_switch.value == 2 and "on" or "off") .. "\n")
  file:write("volume_column=" .. (volume_column_switch.value == 2 and "on" or "off") .. "\n")
  file:write("panning_column=" .. (panning_column_switch.value == 2 and "on" or "off") .. "\n")
  file:write("sample_effects_column=" .. (sample_effects_column_switch.value == 2 and "on" or "off") .. "\n")
  file:write("collapsed=" .. (collapsed_switch.value == 2 and "on" or "off") .. "\n")
  file:write("incoming_audio=" .. (incoming_audio_switch.value == 2 and "on" or "off") .. "\n")
  file:write("populate_sends=" .. (populate_sends_switch.value == 2 and "on" or "off") .. "\n")
  file:write("external_editor=" .. (external_editor_switch.value == 2 and "on" or "off") .. "\n")
  file:write("\n")
  
  -- Write track settings
  file:write("# Track 1-16 Settings (midi_in|channel|midi_out|channel|ccizer|plugin)\n")
  for i = 1, 16 do
    local midi_in = midi_input_device[i] or "<None>"
    local midi_in_ch = midi_input_channel[i] or i
    local midi_out = midi_output_device[i] or "<None>"
    local midi_out_ch = midi_output_channel[i] or i
    local ccizer = selected_ccizer_file[i] or "<None>"
    local plugin = selected_plugin[i] or "<None>"
    
    file:write(string.format("track%d=%s|%d|%s|%d|%s|%s\n", 
      i, midi_in, midi_in_ch, midi_out, midi_out_ch, ccizer, plugin))
  end
  
  file:close()
  
  -- Extract filename for display
  local filename = filepath:match("([^/\\]+)$")
  local name_without_ext = filename:match("^(.+)%..+$") or filename
  
  -- Add to recent presets
  add_preset_to_recent(name_without_ext, filepath)
  
  renoise.app():show_status("MIDI Populator preset saved: " .. name_without_ext)
  print("-- MIDI Populator: Preset saved to " .. filepath)
  return true
end

-- Load MIDI Populator preset from file
local function load_midi_populator_preset(filepath)
  local file = io.open(filepath, "r")
  if not file then
    renoise.app():show_error("Cannot open preset file: " .. filepath)
    return false
  end
  
  print("-- MIDI Populator: Loading preset from " .. filepath)
  
  for line in file:lines() do
    line = line:match("^%s*(.-)%s*$") -- Trim whitespace
    
    -- Skip empty lines and comments
    if line and line ~= "" and not line:match("^#") then
      local key, value = line:match("^([^=]+)=(.*)$")
      if key and value then
        key = key:match("^%s*(.-)%s*$") -- Trim key
        value = value:match("^%s*(.-)%s*$") -- Trim value
        
        -- Parse global settings
        if key == "note_columns" then
          local num = tonumber(value)
          if num and num >= 1 and num <= 12 then
            note_columns_switch.value = num
          end
        elseif key == "effect_columns" then
          local num = tonumber(value)
          if num and num >= 1 and num <= 8 then
            effect_columns_switch.value = num
          end
        elseif key == "delay_column" then
          delay_column_switch.value = (value == "on") and 2 or 1
        elseif key == "volume_column" then
          volume_column_switch.value = (value == "on") and 2 or 1
        elseif key == "panning_column" then
          panning_column_switch.value = (value == "on") and 2 or 1
        elseif key == "sample_effects_column" then
          sample_effects_column_switch.value = (value == "on") and 2 or 1
        elseif key == "collapsed" then
          collapsed_switch.value = (value == "on") and 2 or 1
        elseif key == "incoming_audio" then
          incoming_audio_switch.value = (value == "on") and 2 or 1
        elseif key == "populate_sends" then
          populate_sends_switch.value = (value == "on") and 2 or 1
        elseif key == "external_editor" then
          external_editor_switch.value = (value == "on") and 2 or 1
        else
          -- Parse track settings
          local track_num = key:match("^track(%d+)$")
          if track_num then
            local i = tonumber(track_num)
            if i and i >= 1 and i <= 16 then
              -- Parse pipe-separated values: midi_in|channel|midi_out|channel|ccizer|plugin
              local parts = {}
              for part in value:gmatch("[^|]+") do
                table.insert(parts, part)
              end
              
              if #parts >= 6 then
                local midi_in = parts[1]
                local midi_in_ch = tonumber(parts[2]) or i
                local midi_out = parts[3]
                local midi_out_ch = tonumber(parts[4]) or i
                local ccizer = parts[5]
                local plugin = parts[6]
                
                -- Set MIDI input device
                midi_input_device[i] = midi_in
                local midi_in_idx = table.index_of(midi_input_devices, midi_in)
                if midi_in_idx and vb.views["midi_input_popup_" .. i] then
                  vb.views["midi_input_popup_" .. i].value = midi_in_idx
                elseif vb.views["midi_input_popup_" .. i] then
                  vb.views["midi_input_popup_" .. i].value = 1 -- Default to <None>
                end
                
                -- Set MIDI input channel
                midi_input_channel[i] = midi_in_ch
                if vb.views["midi_input_channel_popup_" .. i] then
                  vb.views["midi_input_channel_popup_" .. i].value = midi_in_ch
                end
                
                -- Set MIDI output device
                midi_output_device[i] = midi_out
                local midi_out_idx = table.index_of(midi_output_devices, midi_out)
                if midi_out_idx and vb.views["midi_output_popup_" .. i] then
                  vb.views["midi_output_popup_" .. i].value = midi_out_idx
                elseif vb.views["midi_output_popup_" .. i] then
                  vb.views["midi_output_popup_" .. i].value = 1 -- Default to <None>
                end
                
                -- Set MIDI output channel
                midi_output_channel[i] = midi_out_ch
                if vb.views["midi_output_channel_popup_" .. i] then
                  vb.views["midi_output_channel_popup_" .. i].value = midi_out_ch
                end
                
                -- Set CCizer file
                selected_ccizer_file[i] = ccizer
                local ccizer_idx = table.index_of(ccizer_dropdown_items, ccizer)
                if ccizer_idx and vb.views["ccizer_popup_" .. i] then
                  vb.views["ccizer_popup_" .. i].value = ccizer_idx
                elseif vb.views["ccizer_popup_" .. i] then
                  vb.views["ccizer_popup_" .. i].value = 1 -- Default to <None>
                end
                
                -- Set Plugin
                selected_plugin[i] = plugin
                local plugin_idx = table.index_of(plugin_dropdown_items, plugin)
                if plugin_idx and vb.views["plugin_popup_" .. i] then
                  vb.views["plugin_popup_" .. i].value = plugin_idx
                elseif vb.views["plugin_popup_" .. i] then
                  vb.views["plugin_popup_" .. i].value = 1 -- Default to <None>
                end
              end
            end
          end
        end
      end
    end
  end
  
  file:close()
  
  -- Extract filename for display
  local filename = filepath:match("([^/\\]+)$")
  local name_without_ext = filename:match("^(.+)%..+$") or filename
  
  -- Add to recent presets
  add_preset_to_recent(name_without_ext, filepath)
  
  renoise.app():show_status("MIDI Populator preset loaded: " .. name_without_ext)
  print("-- MIDI Populator: Preset loaded from " .. filepath)
  return true
end

-- Handle preset dropdown selection
local function on_preset_dropdown_changed(value)
  if value > 1 and value <= #recent_presets_dropdown_items then
    local preset_index = value - 1 -- Account for <None> at position 1
    local preset = recent_presets[preset_index]
    if preset and preset.path then
      load_midi_populator_preset(preset.path)
    end
  end
end

-- Handle Load Preset button
local function on_load_preset_button()
  local filepath = renoise.app():prompt_for_filename_to_read({"*.mpp"}, "Load MIDI Populator Preset")
  if filepath and filepath ~= "" then
    load_midi_populator_preset(filepath)
  end
end

-- Handle Save Preset button
local function on_save_preset_button()
  local filepath = renoise.app():prompt_for_filename_to_write("mpp", "Save MIDI Populator Preset")
  if filepath and filepath ~= "" then
    -- Ensure .mpp extension
    if not filepath:match("%.mpp$") then
      filepath = filepath .. ".mpp"
    end
    save_midi_populator_preset(filepath)
  end
end

-- Handle Remove Preset button
local function on_remove_preset_button()
  if vb.views["preset_dropdown"] then
    local current_value = vb.views["preset_dropdown"].value
    if current_value > 1 then
      remove_preset_from_recent(current_value)
    end
  end
end

local function on_ok_button_pressed(dialog_content)
  -- Save preferences before applying
  save_preferences()
  
  for i = 1, 16 do
    MidiInitChannelTrackInstrument(i)
  end
  renoise.song().selected_track_index = 1 -- Select the first track

  -- Close the dialog and restore focus to the pattern editor
  dialog:close()
  dialog = nil
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function on_save_and_close_pressed()
  save_preferences()
  dialog:close()
  dialog = nil
end

function pakettiMIDIPopulator()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  -- Initialize variables
  initialize_variables()

  -- Clear the ViewBuilder to prevent duplicate view IDs
  vb = renoise.ViewBuilder()

  -- Initialize the GUI elements
  local rows = {}
  
  -- Create header row
  local header_row = vb:horizontal_aligner{
    mode = "right",
    vb:text{text="",width=100}, -- Empty space for track label column
    vb:text{text="MIDI Input",width=150, style="strong"},
    vb:text{text="Ch",width=40, style="strong"},
    vb:text{text="MIDI Output",width=150, style="strong"}, 
    vb:text{text="Ch",width=40, style="strong"},
    vb:text{text="CCizer TXTfile",width=150, style="strong"},
    vb:text{text="Plugin Name",width=150, style="strong"}
  }
  
  for i = 1, 16 do
    rows[i] = vb:horizontal_aligner{
      mode = "right",
      vb:text{text="Track " .. i .. ":",width=100},
      vb:popup{
        items = midi_input_devices, 
        width=150, 
        notifier=function(value) midi_input_device[i] = midi_input_devices[value] end, 
        id = "midi_input_popup_" .. i,
        value = table.index_of(midi_input_devices, midi_input_device[i]) or 1
      },
      vb:popup{
        items = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 
        width=40, 
        notifier=function(value) midi_input_channel[i] = value end, 
        id = "midi_input_channel_popup_" .. i,
        value = midi_input_channel[i] or i
      },
      vb:popup{
        items = midi_output_devices, 
        width=150, 
        notifier=function(value) midi_output_device[i] = midi_output_devices[value] end, 
        id = "midi_output_popup_" .. i,
        value = table.index_of(midi_output_devices, midi_output_device[i]) or 1
      },
      vb:popup{
        items = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 
        width=40, 
        notifier=function(value) midi_output_channel[i] = value end, 
        id = "midi_output_channel_popup_" .. i,
        value = midi_output_channel[i] or i
      },
      vb:popup{
        items = ccizer_dropdown_items, 
        width=150, 
        notifier=function(value) 
          local selected_item = ccizer_dropdown_items[value]
          if selected_item == "<Browse>" then
            -- Open file browser for this track
            local selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "MIDI Channel " .. string.format("%02d", i) .. " - Load CCizer Text File")
            if selected_textfile and selected_textfile ~= "" then
              local filename = selected_textfile:match("([^/\\]+)$")
              local name_without_ext = filename:match("^(.+)%..+$") or filename
              selected_ccizer_file[i] = "[" .. name_without_ext .. "]"
              
              -- Store the file path for later use
              if not selected_ccizer_file_paths then
                selected_ccizer_file_paths = {}
              end
              selected_ccizer_file_paths[i] = selected_textfile
              
              -- Add the browsed file to dropdown items and select it
              local browse_display = "[" .. name_without_ext .. "]"
              if not table.index_of(ccizer_dropdown_items, browse_display) then
                table.insert(ccizer_dropdown_items, #ccizer_dropdown_items, browse_display) -- Insert before <Browse>
                vb.views["ccizer_popup_" .. i].items = ccizer_dropdown_items
              end
              vb.views["ccizer_popup_" .. i].value = table.index_of(ccizer_dropdown_items, browse_display)
              print(string.format("-- CCizer: Track %d will use custom file: %s", i, name_without_ext))
            else
              -- User cancelled, reset to <None>
              vb.views["ccizer_popup_" .. i].value = 1
              selected_ccizer_file[i] = ccizer_dropdown_items[1]
              print(string.format("-- CCizer: Track %d browse cancelled, reset to <None>", i))
            end
          else
            selected_ccizer_file[i] = selected_item
            print(string.format("-- CCizer: Track %d selected: '%s'", i, selected_item))
          end
        end, 
        id = "ccizer_popup_" .. i,
        value = table.index_of(ccizer_dropdown_items, selected_ccizer_file[i]) or 1
      },
      vb:popup{
        items = plugin_dropdown_items, 
        width=150, 
        notifier=function(value) selected_plugin[i] = plugin_dropdown_items[value] end, 
        id = "plugin_popup_" .. i,
        value = table.index_of(plugin_dropdown_items, selected_plugin[i]) or 1
      }
    }
  end

  local function bool_to_switch_value(bool)
    return bool and 2 or 1
  end

  -- Initialize switches based on existing preferences
  note_columns_switch = vb:switch{
    items = {"1","2","3","4","5","6","7","8","9","10","11","12"}, 
    width=300, 
    value = prefs.pakettiMidiPopulator.noteColumns.value or 1.0
  }
  effect_columns_switch = vb:switch{
    items = {"1","2","3","4","5","6","7","8"}, 
    width=300, 
    value = prefs.pakettiMidiPopulator.effectColumns.value or 1.0
  }
  delay_column_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.delayColumn.value)
  }
  volume_column_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.volumeColumn.value)
  }
  panning_column_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.panningColumn.value)
  }
  sample_effects_column_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.sampleEffectsColumn.value)
  }
  collapsed_switch = vb:switch{
    items = {"Not Collapsed","Collapsed"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.collapsed.value)
  }
  incoming_audio_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.incomingAudio.value)
  }
  populate_sends_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = bool_to_switch_value(prefs.pakettiMidiPopulator.populateSends.value)
  }
  external_editor_switch = vb:switch{
    items = {"Off","On"}, 
    width=300, 
    value = 1  -- Default to Off; adjust if you have a corresponding preference
  }

  dialog_content = vb:column{
    margin=10, spacing=0,
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Preset:"},
      vb:popup{
        items = recent_presets_dropdown_items,
        width=200,
        id = "preset_dropdown",
        notifier = on_preset_dropdown_changed
      },
      vb:button{text="Load...", width=70, notifier = on_load_preset_button},
      vb:button{text="Save...", width=70, notifier = on_save_preset_button},
      vb:button{text="Remove", width=70, notifier = on_remove_preset_button}
    }},
    horizontal_rule(),
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="MIDI Input Device:"},
      vb:popup{
        items = midi_input_devices, 
        width=700, 
        notifier = on_midi_input_switch_changed
      }
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="MIDI Output Device:"},
      vb:popup{
        items = midi_output_devices, 
        width=700, 
        notifier = on_midi_output_switch_changed
      }
    }},
    horizontal_rule(),
    vb:row{
      vb:button{text="Randomize AU Plugin Selection",width=200, notifier = randomize_au_plugins},
      vb:button{text="Randomize VST Plugin Selection",width=200, notifier = randomize_vst_plugins},
      vb:button{text="Randomize VST3 Plugin Selection",width=200, notifier = randomize_vst3_plugins},
      vb:button{text="Clear Plugin Selection",width=200, notifier = clear_plugin_selection}
    },
    horizontal_rule(),
    header_row,
    vb:column(rows),
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Note Columns:"}, 
      note_columns_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Effect Columns:"}, 
      effect_columns_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Delay Column:"}, 
      delay_column_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Volume Column:"}, 
      volume_column_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Panning Column:"}, 
      panning_column_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Sample Effects Column:"}, 
      sample_effects_column_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Track State:"}, 
      collapsed_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Add #Line-Input Device for each Channel:"}, 
      incoming_audio_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Populate Channels with Send Devices:"}, 
      populate_sends_switch
    }},
    vb:horizontal_aligner{mode = "right", vb:row{
      vb:text{text="Open External Editor for each Plugin:"}, 
      external_editor_switch
    }},
    horizontal_rule(),
    vb:horizontal_aligner{mode="right", vb:row{
      vb:button{
        text="OK", 
        width=100, 
        notifier=function() on_ok_button_pressed(dialog_content) end
      },
      vb:button{
        text="Close", 
        width=100, 
        notifier=function() dialog:close() end
      },
      vb:button{
        text="Save & Close", 
        width=100, 
        notifier = on_save_and_close_pressed  -- Added Save & Close button
      }
    }}
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti MIDI Populator", dialog_content, keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti MIDI Populator Dialog...",invoke=function() pakettiMIDIPopulator() end}

