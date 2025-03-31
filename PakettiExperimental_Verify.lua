-- Function to ensure EQ10 exists on selected track and return its index
local function ensure_eq10_exists()
  local song = renoise.song()
  local track = song.selected_track
  
  -- First check if EQ10 already exists
  for i, device in ipairs(track.devices) do
    if device.name == "EQ 10" then
      -- Show the device in DSP chain
      device.is_maximized = true
      return i
    end
  end
  
  -- If not found, add EQ10 after the track volume device
  loadnative("Audio/Effects/Native/EQ 10")
  
  -- Find the newly added EQ10
  for i, device in ipairs(track.devices) do
    if device.name == "EQ 10" then
      device.is_maximized = true
      return i
    end
  end
  
  return nil
end

-- Function to get current EQ10 parameters
local function get_eq10_params(device)
  local params = {}
  for i = 1, 10 do
    params[i] = {
      gain = device.parameters[i].value,              -- Gains are parameters 1-10
      freq = device.parameters[i + 10].value,         -- Frequencies are parameters 11-20
      bandwidth = device.parameters[i + 20].value     -- Bandwidths are parameters 21-30
    }
  end
  return params
end

-- Function to normalize gain value to 0-1 range
local function normalize_gain(gain)
  -- EQ10 gain range is -12 to +12
  local normalized = (gain + 12) / 24
  -- Ensure value is between 0 and 1
  return math.max(0, math.min(1, normalized))
end

-- Function to create the EQ10 dialog
function show_eq10_dialog()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  
  -- Ensure EQ10 exists and get its index
  local eq10_index = ensure_eq10_exists()
  local eq10_device = renoise.song().selected_track.devices[eq10_index]
  
  -- Create single row of XY pads
  local content = vb:column {
    margin = 5,
    spacing = 5
  }
  
  -- Create the single row for all XY pads
  local row_content = vb:row {
    margin = 5,
    spacing = 10
  }
  
  -- Add all 10 bands
  for band_idx = 1, 10 do
    -- Parameter indices for this band
    local gain_idx = band_idx           -- Gains are parameters 1-10
    local freq_idx = band_idx + 10      -- Frequencies are parameters 11-20
    local bw_idx = band_idx + 20        -- Bandwidths are parameters 21-30
    
    -- Get current values
    local gain_param = eq10_device.parameters[gain_idx]
    local freq_param = eq10_device.parameters[freq_idx]
    local bw_param = eq10_device.parameters[bw_idx]
    
    -- Calculate normalized values
    local x_value = (freq_param.value - freq_param.value_min) / 
                   (freq_param.value_max - freq_param.value_min)
    local y_value = normalize_gain(gain_param.value)
    
    local band_group = vb:column {
      margin = 2,
      vb:text { text = string.format("Band %d", band_idx) },
      vb:xypad {
        id = string.format("xy_band_%d", band_idx),
        width = 80,
        height = 80,
        value = { x = x_value, y = y_value },
        notifier = function(value)
          -- Update frequency (X axis)
          local new_freq = freq_param.value_min + 
                         value.x * (freq_param.value_max - freq_param.value_min)
          freq_param.value = new_freq
          
          -- Update gain and bandwidth (Y axis)
          local gain = (value.y * 24) - 12
          gain_param.value = gain
          
          -- Adjust bandwidth based on gain (higher bandwidth when further from center)
          -- Scale to 0.0001 to 1 range
          local bw_factor = math.abs(gain) / 12  -- 0 to 1 based on gain
          local new_bw = 0.0001 + (bw_factor * 0.9999)  -- Scale to valid range
          bw_param.value = new_bw
        end
      }
    }
    row_content:add_child(band_group)
  end
  
  -- Add the row to the content
  content:add_child(row_content)

  -- Key handler for the dialog
  local function key_handler(dialog, key)
    local closer = preferences.pakettiDialogClose.value
    if key.modifiers == "" and key.name == closer then
      dialog:close()
      return
    end
    return key
  end

  -- Show dialog
  dialog = renoise.app():show_custom_dialog(
    "EQ10 XY Control", 
    content,
    key_handler
  )
end

renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti..:EQ10 XY Control...",invoke = show_eq10_dialog}
renoise.tool():add_keybinding {name = "Global:Tools:Show EQ10 XY Control",invoke = show_eq10_dialog}

-----
local match_editstep_enabled = false
local last_line_index = nil
local tick_counter = 0 -- To track the "tick-tick-tick-skip" cycle

-- Function to find the next valid delay value in the track
local function find_next_delay_line(start_line_index)
  local song = renoise.song()
  local track = song.selected_pattern_track
  local num_lines = song.selected_pattern.number_of_lines

  for line_index = start_line_index + 1, num_lines do
    local line = track:line(line_index)
    if line.note_columns[1] and not line.note_columns[1].is_empty then
      local delay_value = line.note_columns[1].delay_value
      if delay_value == 0x00 or delay_value == 0x55 or delay_value == 0xAA then
        return line_index
      end
    end
  end

  -- Wrap around: search from the top if no match is found below
  for line_index = 1, start_line_index do
    local line = track:line(line_index)
    if line.note_columns[1] and not line.note_columns[1].is_empty then
      local delay_value = line.note_columns[1].delay_value
      if delay_value == 0x00 or delay_value == 0x55 or delay_value == 0xAA then
        return line_index
      end
    end
  end

  return nil -- No valid delays found
end

-- Main function to dynamically adjust editstep
local function match_editstep_with_delay_pattern()
  local song = renoise.song()
  local current_line_index = song.selected_line_index

  -- Only act when the selected line changes
  if last_line_index ~= current_line_index then
    last_line_index = current_line_index

    -- Cycle through the "tick-tick-tick-skip" pattern
    local editstep = 0
    tick_counter = (tick_counter % 4) + 1 -- Cycle between 1-4

    if tick_counter == 4 then
      -- Skip step
      local next_line_index = find_next_delay_line(current_line_index)
      if next_line_index then
        editstep = next_line_index - current_line_index
        if editstep <= 0 then
          -- Wrap-around case
          editstep = (song.selected_pattern.number_of_lines - current_line_index) + next_line_index
        end
      else
        -- No valid delay found, reset to default behavior
        editstep = 1
      end
    else
      -- Standard tick step
      editstep = 1
    end

    -- Apply the editstep
    song.transport.edit_step = editstep
    renoise.app():show_status("EditStep set to " .. tostring(editstep) ..
      " (Cycle position: " .. tostring(tick_counter) .. ")")
  end
end

-- Toggle the functionality on or off
local function toggle_match_editstep()
  match_editstep_enabled = not match_editstep_enabled
  if match_editstep_enabled then
    if not renoise.tool().app_idle_observable:has_notifier(match_editstep_with_delay_pattern) then
      renoise.tool().app_idle_observable:add_notifier(match_editstep_with_delay_pattern)
    end
    renoise.app():show_status("Match EditStep with Delay Pattern: ENABLED")
  else
    if renoise.tool().app_idle_observable:has_notifier(match_editstep_with_delay_pattern) then
      renoise.tool().app_idle_observable:remove_notifier(match_editstep_with_delay_pattern)
    end
    renoise.app():show_status("Match EditStep with Delay Pattern: DISABLED")
  end
end

-- Add menu entry for toggling
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/..:Match EditStep with Delay Pattern",invoke=function() toggle_match_editstep() end}
renoise.tool():add_keybinding{name="Global:Tools:Toggle Match EditStep with Delay Pattern",invoke=function() toggle_match_editstep() end}


if preferences.SelectedSampleBeatSyncLines.value == true then 

for i=1,512 do
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample BeatSync Lines to " .. i,invoke=function()SelectedSampleBeatSyncLine(i)end}
end 
end



function AutoAssignOutputs()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local samples = instrument.samples
  local sample_device_chains = instrument.sample_device_chains
  local available_outputs = sample_device_chains[1] 
    and sample_device_chains[1].available_output_routings 
    or {}

  -- Ensure sufficient output routings exist
  if #available_outputs < 2 then
    renoise.app():show_status("Not enough available output routings.")
    return
  end

  -- Determine the starting chain index based on pre-existing chains
  local pre_existing_chains = #sample_device_chains
  local start_chain_index = math.max(pre_existing_chains + 1, 1)
  if pre_existing_chains >= 2 then
    start_chain_index = 3
  elseif pre_existing_chains == 1 then
    start_chain_index = 2
  end

  -- Calculate the required number of chains (one per sample)
  local required_chains = start_chain_index + #samples - 1

  -- Add new chains if necessary
  for i = pre_existing_chains + 1, required_chains do
    instrument:insert_sample_device_chain_at(i)
  end

  -- Assign output routings and name the chains
  for i = 1, #samples do
    local chain_index = start_chain_index + i - 1
    local routing_index = (i - 1) % (#available_outputs - 1) + 2 -- Skip "Current Track"

    -- Fetch the chain
    local chain = sample_device_chains[chain_index]
    if not chain then
      renoise.app():show_status("Failed to fetch FX chain at index: " .. tostring(chain_index))
      return
    end

    -- Assign output routing and name the chain
    local routing_name = available_outputs[routing_index]
    chain.output_routing = routing_name
    chain.name = routing_name
  end

  renoise.app():show_status("FX chains assigned and outputs routed successfully.")
end



--AutoAssignOutputs()




-- Initialize ViewBuilder
local vb = renoise.ViewBuilder()
local dialog = nil  -- Initialize dialog as nil

-- Tables to hold references to textfields for XRNT and XRNI slots
local slot_path_views_xrnt = {}
local slot_path_views_xrni = {}

-- Reference to the folder path textfield
local folder_path_view = nil

-- Helper functions to get slot preferences
local function get_slot_preference_xrnt(slot_number)
  return preferences.UserDevices["Slot" .. string.format("%02d", slot_number)]
end

local function get_slot_preference_xrni(slot_number)
  return preferences.UserInstruments["Slot" .. string.format("%02d", slot_number)]
end

-- Function to select the User XRNT Saving Folder
local function select_user_xrnt_saving_folder()
  local selected_folder = renoise.app():prompt_for_path("Select User-defined Saving Folder")
  if selected_folder then
    preferences.UserDevices.Path.value = selected_folder
    if folder_path_view then
      folder_path_view.text = preferences.UserDevices.Path.value
    end
    renoise.app():show_status("Saving folder set to: " .. selected_folder)
  end
end

-- Function to save a device chain to a XRNT slot
local function save_device_chain_to_slot(slot_number)
  if preferences.UserDevices.Path.value == "" then
    renoise.app():show_status("Please set the User XRNT Saving Folder first.")
    return
  end

  local file_name = "Slot" .. string.format("%02d", slot_number) .. ".xrnt"
  local full_path = preferences.UserDevices.Path.value .. "/" .. file_name

  local success, err = pcall(function()
    renoise.app():save_track_device_chain(full_path)
  end)

  if success then
    get_slot_preference_xrnt(slot_number).value = full_path
    if slot_path_views_xrnt[slot_number] then
      slot_path_views_xrnt[slot_number].text = full_path
    end
    renoise.app():show_status("Device chain saved to Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to save device chain to Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to load a device chain from a XRNT slot
local function load_device_chain_from_slot(slot_number)
  local file_path = get_slot_preference_xrnt(slot_number).value
  if file_path == "" then
    renoise.app():show_status("No XRNT file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("File not found: " .. file_path)
    return
  else
    file:close()
  end

  local success, err = pcall(function()
    renoise.app():load_track_device_chain(file_path)
  end)

  if success then
    renoise.app():show_status("Device chain loaded from Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to load device chain from Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to select a XRNT file for a slot
local function select_xrnt_file(slot_number)
  local file = renoise.app():prompt_for_filename_to_read({"*.xrnt"}, "Select XRNT File")
  if file then
    get_slot_preference_xrnt(slot_number).value = file
    if slot_path_views_xrnt[slot_number] then
      slot_path_views_xrnt[slot_number].text = file
    end
    renoise.app():show_status("XRNT file set for Slot " .. string.format("%02d", slot_number))
  end
end

-- Function to save an instrument to a XRNI slot
local function save_instrument_to_slot(slot_number)
  if preferences.UserDevices.Path.value == "" then
    renoise.app():show_status("Please set the User XRNT Saving Folder first.")
    return
  end

  local file_name = "Slot" .. string.format("%02d", slot_number) .. ".xrni"
  local full_path = preferences.UserDevices.Path.value .. "/" .. file_name

  local selected_instrument = renoise.song().selected_instrument
  if not selected_instrument then
    renoise.app():show_status("No instrument selected to save.")
    return
  end

  local success, err = pcall(function()
    renoise.app():save_instrument(full_path)
  end)

  if success then
    get_slot_preference_xrni(slot_number).value = full_path
    if slot_path_views_xrni[slot_number] then
      slot_path_views_xrni[slot_number].text = full_path
    end
    renoise.app():show_status("Instrument saved to Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to save instrument to Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to load an instrument from a XRNI slot
local function load_instrument_from_slot(slot_number)
  local file_path = get_slot_preference_xrni(slot_number).value
  if file_path == "" then
    renoise.app():show_status("No XRNI file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("File not found: " .. file_path)
    return
  else
    file:close()
  end

  local success, err = pcall(function()
renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
renoise.song().selected_instrument_index=renoise.song().selected_instrument_index+1
    renoise.app():load_instrument(file_path)
  end)

  if success then
    renoise.app():show_status("Instrument loaded from Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to load instrument from Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to select a XRNI file for a slot
local function select_xrni_file(slot_number)
  local file = renoise.app():prompt_for_filename_to_read({"*.xrni"}, "Select XRNI File")
  if file then
    get_slot_preference_xrni(slot_number).value = file
    if slot_path_views_xrni[slot_number] then
      slot_path_views_xrni[slot_number].text = file
    end
    renoise.app():show_status("XRNI file set for Slot " .. string.format("%02d", slot_number))
  end
end

-- Function to load both XRNI and XRNT from a slot
local function load_both_from_slot(slot_number)
  -- Load XRNI
  local xrni_path = get_slot_preference_xrni(slot_number).value
  if xrni_path == "" then
    renoise.app():show_status("No XRNI file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  -- Load XRNT
  local xrnt_path = get_slot_preference_xrnt(slot_number).value
  if xrnt_path == "" then
    renoise.app():show_status("No XRNT file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  -- Validate XRNI file
  local xrni_file = io.open(xrni_path, "r")
  if not xrni_file then
    renoise.app():show_status("XRNI file not found: " .. xrni_path)
    return
  else
    xrni_file:close()
  end

  -- Validate XRNT file
  local xrnt_file = io.open(xrnt_path, "r")
  if not xrnt_file then
    renoise.app():show_status("XRNT file not found: " .. xrnt_path)
    return
  else
    xrnt_file:close()
  end

  -- Load XRNI
  local success_xrni, err_xrni = pcall(function()
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
    renoise.song().selected_instrument_index=renoise.song().selected_instrument_index+1
    renoise.app():load_instrument(xrni_path)
  end)

  if not success_xrni then
    renoise.app():show_status("Failed to load Instrument (.XRNI) from Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err_xrni))
    return
  end

  -- Load XRNT
  local success_xrnt, err_xrnt = pcall(function()
    renoise.app():load_track_device_chain(xrnt_path)
  end)

  if success_xrnt then
    renoise.app():show_status("Both Instrument (.XRNI) and Device Chain (.XRNT) loaded from Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Instrument (.XRNI) loaded from Slot " .. string.format("%02d", slot_number) .. " but failed to load Device Chain (.XRNT): " .. tostring(err_xrnt))
  end
end

-- Function to show the Paketti Device Chain Dialog with XRNI functionality
local function show_paketti_device_chain_dialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  -- Reset the references
  slot_path_views_xrnt = {}
  slot_path_views_xrni = {}
  folder_path_view = nil

  local slots_rows_xrnt = {}
  local slots_rows_xrni = {}
  local slots_rows_both = {}

  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    -- Create XRNT textfield and store it
    local textfield_xrnt = vb:textfield {
      text = get_slot_preference_xrnt(i).value or "",
      width = 900,  -- Increased width as per requirement
      notifier = function(text)
        get_slot_preference_xrnt(i).value = text
      end
    }
    slot_path_views_xrnt[i] = textfield_xrnt

    -- XRNT Row
    local row_xrnt = vb:row {
     -- margin = 2,
      vb:text { text = "Load Device Chain (.XRNT) Slot" .. slot_number .. ":", width = 200 },
      textfield_xrnt,
      vb:button {
        text = "Browse",
        notifier = function()
          select_xrnt_file(i)
        end
      },
      vb:button {
        text = "Save",
        notifier = function()
          save_device_chain_to_slot(i)
        end
      },
      vb:button {
        text = "Load",
        notifier = function()
          load_device_chain_from_slot(i)
        end
      }
    }
    slots_rows_xrnt[#slots_rows_xrnt + 1] = row_xrnt

    -- Create XRNI textfield and store it
    local textfield_xrni = vb:textfield {
      text = get_slot_preference_xrni(i).value or "",
      width = 900,  -- Increased width as per requirement
      notifier = function(text)
        get_slot_preference_xrni(i).value = text
      end
    }
    slot_path_views_xrni[i] = textfield_xrni

    -- XRNI Row
    local row_xrni = vb:row {
    --  margin = 2,
      vb:text { text = "Load Instrument (.XRNI) Slot" .. slot_number .. ":", width = 200 },
      textfield_xrni,
      vb:button {
        text = "Browse",
        notifier = function()
          select_xrni_file(i)
        end
      },
      vb:button {
        text = "Save",
        notifier = function()
          save_instrument_to_slot(i)
        end
      },
      vb:button {
        text = "Load",
        notifier = function()
          load_instrument_from_slot(i)
        end
      }
    }
    slots_rows_xrni[#slots_rows_xrni + 1] = row_xrni

    -- Both XRNI&XRNT Row
    local row_both = vb:row {
      vb:text { text = "Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number .. ":", width = 200 },
      vb:button {
        text = "Load Both",
        notifier = function()
          load_both_from_slot(i)
        end
      }
    }
    slots_rows_both[#slots_rows_both + 1] = row_both
  end

  -- Define the content of the dialog
  local content = vb:column {
    vb:row {
      vb:text { text = "User XRNT/XRNI Save Folder:", width = 200 },
      vb:textfield {
        text = preferences.UserDevices.Path.value ~= "" and preferences.UserDevices.Path.value or "<Not Set, Please Set>",
        width = 900,  -- Increased width as per requirement
        notifier = function(text)
          preferences.UserDevices.Path.value = text
        end
      },
      vb:button {
        text = "Browse",
        notifier = function()
          select_user_xrnt_saving_folder()
        end
      }
    },
    vb:column {
      vb:text { text = "Load Device Chain (.XRNT) Slots (01-10)", font = "bold" },
      unpack(slots_rows_xrnt)
    },
    vb:column {
      vb:text { text = "Load Instrument (.XRNI) Slots (01-10)", font = "bold" },
      unpack(slots_rows_xrni)
    },
    vb:column {
      vb:text { text = "Load Both Instrument&Device Chain (.XRNI&.XRNT) Slots (01-10)", font = "bold" },
      unpack(slots_rows_both)
    },
    vb:row {
      vb:button {
        text = "Close",
        notifier = function()
          dialog:close()
          dialog = nil  -- Clear the dialog reference
        end
      }
    }
  }

  -- Create and show the dialog
  dialog = renoise.app():show_custom_dialog("Paketti Device Chain & Instrument Dialog", content, nil, nil, keyhandlerfunc_dcid)
end

function keyhandlerfunc_dcid(dialog,key)
  local closer = preferences.pakettiDialogClose.value
  if key.name == closer then
    dialog:close()
  end
  return key
end

-- Function to add menu entries and key bindings grouped by functionality
local function add_menu_entries_and_keybindings()
  -- Load Device Chain (.XRNT) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_xrnt = "Mixer:Paketti..:Device Chains..:Load Device Chain (.XRNT) Slot" .. slot_number
    local menu_entry_name2_xrnt = "DSP Device:Paketti..:Device Chains..:Load Device Chain (.XRNT) Slot" .. slot_number
    local key_binding_name_xrnt = "Global:Paketti:Load Device Chain (.XRNT) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_xrnt,invoke=function() load_device_chain_from_slot(i) end }
    renoise.tool():add_menu_entry{name=menu_entry_name2_xrnt,invoke=function() load_device_chain_from_slot(i) end }
    renoise.tool():add_keybinding{name=key_binding_name_xrnt,invoke=function() load_device_chain_from_slot(i) end }
  end

  -- Load Instrument (.XRNI) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_xrni = "Mixer:Paketti..:Device Chains..:Load Instrument (.XRNI) Slot" .. slot_number
    local menu_entry_name2_xrni = "DSP Device:Paketti..:Device Chains..:Load Instrument (.XRNI) Slot" .. slot_number
    local key_binding_name_xrni = "Global:Paketti:Load Instrument (.XRNI) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_xrni,invoke=function() load_instrument_from_slot(i) end }
    renoise.tool():add_menu_entry{name=menu_entry_name2_xrni,invoke=function() load_instrument_from_slot(i) end }
    renoise.tool():add_keybinding{name=key_binding_name_xrni,invoke=function() load_instrument_from_slot(i) end }
  end

  -- Load Both Instrument&Device Chain (.XRNI&.XRNT) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_load_both = "Mixer:Paketti..:Device Chains..:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number
    local menu_entry_name2_load_both = "DSP Device:Paketti..:Device Chains..:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number
    local key_binding_name_load_both = "Global:Paketti:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_load_both,invoke=function() load_both_from_slot(i) end }
    renoise.tool():add_menu_entry{name=menu_entry_name2_load_both,invoke=function() load_both_from_slot(i) end }
    renoise.tool():add_keybinding{name=key_binding_name_load_both,invoke=function() load_both_from_slot(i) end }
  end
end

add_menu_entries_and_keybindings()
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:Device Chains..:Open Track DSP Device & Instrument Loader...",invoke=function() show_paketti_device_chain_dialog() end }
renoise.tool():add_menu_entry{name="--DSP Device:Paketti..:Device Chains..:Open Track DSP Device & Instrument Loader...",invoke=function() show_paketti_device_chain_dialog() end }
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Paketti Track DSP Device & Instrument Loader...",invoke=function() show_paketti_device_chain_dialog() end }

------------------------
local vb = renoise.ViewBuilder()
local dialog = nil
local dialog_content = nil

local function my_keyhandler_func(dialog, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
   dialog:close()
   return end
   
    if key.name == "!" then
      dialog:close()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    else
      return key
    end
end

local function update_sample_volumes(x, y)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples < 4 then
    renoise.app():show_status("Selected instrument must have at least 4 samples.")
    return
  end

  -- Calculate volumes based on the x, y position of the xypad
  local volumes = {
    (1 - x) * y, -- Top-left (Sample 1)
    x * y,       -- Top-right (Sample 2)
    (1 - x) * (1 - y), -- Bottom-left (Sample 3)
    x * (1 - y)  -- Bottom-right (Sample 4)
  }

  -- Normalize volumes to range 0.0 - 1.0
  for i, volume in ipairs(volumes) do
    instrument.samples[i].volume = math.min(1.0, math.max(0.0, volume))
  end

  renoise.app():show_status(
    ("Sample volumes updated: S1=%.2f, S2=%.2f, S3=%.2f, S4=%.2f"):
    format(volumes[1], volumes[2], volumes[3], volumes[4])
  )
end

dialog_content = vb:column {
  vb:xypad {
    width = 200,
    height = 200,
    value = {x=0.5, y=0.5},
    notifier = function(value)
      update_sample_volumes(value.x, value.y)
    end
  }
}

function showXyPaddialog()
  if dialog and dialog.visible then
    dialog:close()
  else
    dialog = renoise.app():show_custom_dialog("XY Pad Sound Mixer", dialog_content, my_keyhandler_func)
  end
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:XY Pad Sound Mixer",invoke=function() showXyPaddialog() end}










local vb = renoise.ViewBuilder()
local dialog = nil
local monitoring_enabled = false -- Tracks the monitoring state
local active = false

-- Tracks all SB0/SBX pairs in the Master Track
local loop_pairs = {}

-- Scan the Master Track for all SB0/SBX pairs

function analyze_loops()
  local song = renoise.song()
  local master_track_index = renoise.song().sequencer_track_count + 1
  local master_track = song.selected_pattern.tracks[master_track_index]
  loop_pairs = {}

  for line_idx, line in ipairs(master_track.lines) do
    if #line.effect_columns > 0 then
      local col = line.effect_columns[1]
      if col.number_string == "0S" then
        local parameter = col.amount_value - 176 -- Decode by subtracting `B0`

        if parameter == 0 then
          -- Found SB0 (start)
          table.insert(loop_pairs, {start_line = line_idx, end_line = nil, repeat_count = 0, max_repeats = 0})
        elseif parameter >= 1 and parameter <= 15 then
          -- Found SBX (end) for the last SB0
          local last_pair = loop_pairs[#loop_pairs]
          if last_pair and not last_pair.end_line then
            last_pair.end_line = line_idx
            last_pair.max_repeats = parameter
          end
        end
      end
    end
  end

  if #loop_pairs == 0 then
    print("Error: No valid SB0/SBX pairs found in the Master Track.")
    return false
  end

  print("Detected SB0/SBX pairs in Master Track:")
  for i, pair in ipairs(loop_pairs) do
    print("Pair " .. i .. ": Start=" .. pair.start_line .. ", End=" .. pair.end_line .. ", Max Repeats=" .. pair.max_repeats)
  end

  return true
end

-- Playback Monitoring Function
local function monitor_playback()
  local song = renoise.song()
  local play_pos = song.transport.playback_pos
  local current_line = play_pos.line
  local max_row = renoise.song().selected_pattern.number_of_lines - 1 -- Last row in the pattern

  -- Reset all repeat counts at the end of the pattern
  if current_line == max_row then
    for _, pair in ipairs(loop_pairs) do
      pair.repeat_count = 0
    end
    print("Resetting all repeat counts at the end of the pattern.")
    return
  end

  -- Handle looping logic for each pair
  for i, pair in ipairs(loop_pairs) do
    if current_line == pair.end_line then
      if pair.repeat_count < pair.max_repeats then
        pair.repeat_count = pair.repeat_count + 1
        print("Pair " .. i .. ": Looping back to SB0 (line " .. pair.start_line .. "). Repeat count: " .. pair.repeat_count)
        song.transport.playback_pos = renoise.SongPos(play_pos.sequence, pair.start_line)
        return
      else
        print("Pair " .. i .. ": Completed all repeats for this iteration.")
      end
    end
  end
end
--]]
-- Global Reset Function
function reset_repeat_counts()
  if not monitoring_enabled then
    print("Monitoring is disabled. Reset operation skipped.")
    return
  end

  print("Checking Master Track for SB0/SBX pairs...")
  if not analyze_loops() then
    print("No valid SB0/SBX pairs found in the Master Track. Reset operation aborted.")
    return
  end

  for i, pair in ipairs(loop_pairs) do
    pair.repeat_count = 0
    print("Reset Pair " .. i .. ": Start=" .. pair.start_line .. ", End=" .. pair.end_line .. ", Max Repeats=" .. pair.max_repeats)
  end

  print("All repeat counts reset to 0. Monitoring restarted.")
  InitSBx() -- Reinitialize SBX monitoring
end

-- Initialize SBX Monitoring
function InitSBx()
  if monitoring_enabled then
    print("Monitoring is enabled. Checking Master Track for SBX...")
    if not analyze_loops() then
      print("No valid SBX commands found in the Master Track. Monitoring will not start.")
      return
    end
    if not active then
      renoise.tool().app_idle_observable:add_notifier(monitor_playback)
      print("SBX Monitoring started.")
      active = true
    end
  else
    print("Monitoring is disabled. SBX initialization skipped.")
  end
end

-- Enable Monitoring
local function enable_monitoring()
  monitoring_enabled = true
  InitSBx()
end

-- Disable Monitoring
local function disable_monitoring()
  monitoring_enabled = false
  if active and renoise.tool().app_idle_observable:has_notifier(monitor_playback) then
    renoise.tool().app_idle_observable:remove_notifier(monitor_playback)
    print("SBX Monitoring stopped.")
    active = false
  end
end

-- GUI for Triggering the Script
function showSBX_dialog()
  if dialog and dialog.visible then dialog:close() return end
  local content = vb:column {
    margin = 10,
    vb:text { text = "Trigger SBX Loop Handler" },
    vb:button {
      text = "Enable Monitoring",
      released = function()
        enable_monitoring()
      end
    },
    vb:button {
      text = "Disable Monitoring",
      released = function()
        disable_monitoring()
      end
    }
  }
  dialog = renoise.app():show_custom_dialog("SBX Playback Handler", content, keyhandlerfunc_sbx)
end

function keyhandlerfunc_sbx(dialog,key)
  local closer = preferences.pakettiDialogClose.value
  if key.name == closer then
    dialog:close()
  end
  return key
end

-- Add Menu Entry
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:SBx Loop Playback",invoke=showSBX_dialog}

-- Add Shortcut for Reset and Playback
renoise.tool():add_keybinding{name="Global:Transport:Reset SBx and Start Playback",
  invoke=function()
    reset_repeat_counts()
    renoise.song().transport:start() -- Start playback
  end}
--]]
-- Tool Initialization
  monitoring_enabled = true
--InitSBx()



function crossfade_loop(crossfade_length)
  -- User-adjustable fade length for loop start/end fades
  local fade_length = 20

  -- Check for an active instrument
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  -- Check for an active sample
  local sample = instrument:sample(1)
  if not sample then
    renoise.app():show_status("No sample available.")
    return
  end

  -- Check if sample has data and looping is enabled
  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then
    renoise.app():show_status("Sample has no data.")
    return
  end

  if sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
    renoise.app():show_status("Loop mode is off.")
    return
  end

  local loop_start = sample.loop_start
  local loop_end = sample.loop_end
  local num_frames = sample_buffer.number_of_frames

  -- Validate frame ranges for crossfade and fade operations
  if loop_start <= crossfade_length + fade_length then
    renoise.app():show_status("Not enough frames before loop_start for crossfade and fades.")
    return
  end

  if loop_end <= crossfade_length + fade_length then
    renoise.app():show_status("Not enough frames before loop_end for crossfade and fades.")
    return
  end

  if loop_start + fade_length - 1 > num_frames then
    renoise.app():show_status("Not enough frames after loop_start for fade-in.")
    return
  end

  if loop_end - fade_length < 1 then
    renoise.app():show_status("Not enough frames before loop_end for fade-out.")
    return
  end

  -- Define crossfade regions:
  -- a-b (fade-in region) is before loop_start
  local fade_in_start = loop_start - crossfade_length
  local fade_in_end = loop_start - 1

  -- c-d (fade-out region) is before loop_end
  local fade_out_start = loop_end - crossfade_length
  local fade_out_end = loop_end - 1

  -- Prepare sample data changes
  sample_buffer:prepare_sample_data_changes()

  ---------------------------------------------------
  -- Crossfade: Mix a-b region into c-d region
  ---------------------------------------------------
  for i = 0, crossfade_length - 1 do
    local fade_in_pos = fade_in_start + i
    local fade_out_pos = fade_out_start + i

    -- Fade ratios: fade_in ramps 0->1, fade_out ramps 1->0
    local fade_in_ratio = i / (crossfade_length - 1)
    local fade_out_ratio = 1 - fade_in_ratio

    for c = 1, sample_buffer.number_of_channels do
      local fade_in_val = sample_buffer:sample_data(c, fade_in_pos)
      local fade_out_val = sample_buffer:sample_data(c, fade_out_pos)

      -- Blend the two segments
      local blended_val = (fade_in_val * fade_in_ratio) + (fade_out_val * fade_out_ratio)

      -- Write the blended value back to the fade_out region (c-d)
      sample_buffer:set_sample_data(c, fade_out_pos, blended_val)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-out at loop_end
  -- Ensures silence right at loop_end
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_end - fade_length + i
    local fade_ratio = 1 - (i / (fade_length - 1))
    for c = 1, sample_buffer.number_of_channels do
      local sample_val = sample_buffer:sample_data(c, pos)
      sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-in at loop_start
  -- Ensures sound ramps up from silence at loop_start
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_start + i
    local fade_ratio = i / (fade_length - 1)
    for c = 1, sample_buffer.number_of_channels do
      local sample_val = sample_buffer:sample_data(c, pos)
      sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-out before loop_start
  -- Ensures silence leading into the loop_start region
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_start - fade_length + i
    if pos >= 1 and pos <= num_frames then
      local fade_ratio = 1 - (i / (fade_length - 1))
      for c = 1, sample_buffer.number_of_channels do
        local sample_val = sample_buffer:sample_data(c, pos)
        sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
      end
    end
  end

  -- Finalize changes
  sample_buffer:finalize_sample_data_changes()

  renoise.app():show_status("Crossfade and 20-frame fades applied to create a smooth X-shaped loop.")
end

-- Helper function to determine crossfade_length based on the current selection
local function get_dynamic_crossfade_length()
  local song = renoise.song()
  local sample = song and song.selected_sample or nil
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected.")
    return nil
  end

  local loop_end = sample.loop_end
  local sel = sample.sample_buffer.selection_range

  if not sel or #sel < 2 then
    renoise.app():show_status("No sample selection made.")
    return nil
  end

  -- According to the updated math:
  -- crossfade_length = loop_end - selection_end
  local selection_end = sel[2]

  if selection_end >= loop_end then
    renoise.app():show_status("Selection end must be before loop_end.")
    return nil
  end

  local crossfade_length = loop_end - selection_end
  return crossfade_length
end


-- Keybinding: Use the dynamic crossfade length based on selection_end
renoise.tool():add_keybinding{name="Global:Paketti:Crossfade Loop",
  invoke=function()
    local crossfade_length = get_dynamic_crossfade_length()
    if crossfade_length then
      renoise.app():show_status("Using crossfade length: " .. tostring(crossfade_length))
      crossfade_loop(crossfade_length)
    end
  end
}


-- Menu Entry: Use the dynamic crossfade length based on selection_end
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Experimental/WIP..:Crossfade Loop",
  invoke=function()
    local crossfade_length = get_dynamic_crossfade_length()
    if crossfade_length then
      renoise.app():show_status("Using crossfade length: " .. tostring(crossfade_length))
      crossfade_loop(crossfade_length)
    end
  end
}





















-- MIDI Mapping for adjusting selected instrument transpose
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Transpose (-64-+64)",
  invoke=function(message)
    -- Ensure the selected instrument exists
    local instrument=renoise.song().selected_instrument
    if not instrument then return end
    
    -- Map the MIDI message value (0-127) to transpose range (-64 to 64)
    local transpose_value=math.floor((message.int_value/127)*128 - 64)
    instrument.transpose=math.max(-64,math.min(transpose_value,64))
    
    -- Status update for debugging
    renoise.app():show_status("Transpose adjusted to "..instrument.transpose)
  end
}







local function flood_fill_column()

  local song = renoise.song()
  local track = song.selected_track
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local line_index = song.selected_line_index
  local lines = pattern.tracks[song.selected_track_index].lines

  local cursor_pos = song.transport.edit_pos
  local sel_effect_col = song.selected_effect_column_index
  local sel_note_col = song.selected_note_column_index

  -- Check if we are in an effect column
  if sel_effect_col ~= 0 then
    -- Get the effect value in the current row
    local current_effect = lines[line_index].effect_columns[sel_effect_col]
    if current_effect.is_empty then
      renoise.app():show_status("No effect to flood fill from the current row.")
      return
    end
    -- Loop through rows from current position to the end of the pattern
    for i = line_index + 1, #lines do
      lines[i].effect_columns[sel_effect_col]:copy_from(current_effect)
    end

  elseif sel_note_col ~= 0 then
    -- Get note column properties (note, instrument, etc.)
    local current_note_col = lines[line_index].note_columns[sel_note_col]
    if current_note_col.is_empty then
      renoise.app():show_status("No note to flood fill from the current row.")
      return
    end
    -- Loop through rows from current position to the end of the pattern
    for i = line_index + 1, #lines do
      lines[i].note_columns[sel_note_col]:copy_from(current_note_col)
    end

  else
    renoise.app():show_status("Neither an effect nor note column selected.")
    return
  end

  -- Return focus to the pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Flood fill completed.")

end

renoise.tool():add_keybinding{name="Global:Paketti:Flood Fill Column with Row",invoke=function() flood_fill_column() end}

--------
-- Define the path to the mixpaste.xml file within the tool's directory
local tool_dir = renoise.tool().bundle_path
local xml_file_path = tool_dir .. "mixpaste.xml"

-- Function to save the current pattern selection to mixpaste.xml
function save_selection_as_xml()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if not selection then 
    renoise.app():show_status("No selection available.") 
    return 
  end

  local pattern_index = song.selected_pattern_index
  local xml_data = '<?xml version="1.0" encoding="UTF-8"?>\n<PatternClipboard.BlockBuffer doc_version="0">\n  <Columns>\n'

  for track_index = selection.start_track, selection.end_track do
    local track = song.tracks[track_index]
    local pattern_track = song.patterns[pattern_index].tracks[track_index]
    xml_data = xml_data .. '    <Column>\n'

    -- Handle NoteColumns
    local note_columns = track.visible_note_columns
    xml_data = xml_data .. '      <Column>\n        <Lines>\n'
    for line_index = selection.start_line, selection.end_line do
      local line = pattern_track:line(line_index)
      local has_data = false
      xml_data = xml_data .. '          <Line index="' .. (line_index - selection.start_line) .. '">\n            <NoteColumns>\n'
      for note_column_index = selection.start_column, selection.end_column do
        local note_column = line:note_column(note_column_index)
        if not note_column.is_empty then
          xml_data = xml_data .. '              <NoteColumn>\n'
          xml_data = xml_data .. '                <Note>' .. note_column.note_string .. '</Note>\n'
          xml_data = xml_data .. '                <Instrument>' .. note_column.instrument_string .. '</Instrument>\n'
          xml_data = xml_data .. '              </NoteColumn>\n'
          has_data = true
        end
      end
      xml_data = xml_data .. '            </NoteColumns>\n'
      if not has_data then
        xml_data = xml_data .. '          <Line />\n'
      end
      xml_data = xml_data .. '          </Line>\n'
    end
    xml_data = xml_data .. '        </Lines>\n        <ColumnType>NoteColumn</ColumnType>\n'
    xml_data = xml_data .. '        <SubColumnMask>' .. get_sub_column_mask(track, 'note') .. '</SubColumnMask>\n'
    xml_data = xml_data .. '      </Column>\n'

    -- Handle EffectColumns
    local effect_columns = track.visible_effect_columns
    xml_data = xml_data .. '      <Column>\n        <Lines>\n'
    for line_index = selection.start_line, selection.end_line do
      local line = pattern_track:line(line_index)
      local has_data = false
      xml_data = xml_data .. '          <Line>\n            <EffectColumns>\n'
      for effect_column_index = 1, effect_columns do
        local effect_column = line:effect_column(effect_column_index)
        if not effect_column.is_empty then
          xml_data = xml_data .. '              <EffectColumn>\n'
          xml_data = xml_data .. '                <EffectNumber>' .. effect_column.number_string .. '</EffectNumber>\n'
          xml_data = xml_data .. '                <EffectValue>' .. effect_column.amount_string .. '</EffectValue>\n'
          xml_data = xml_data .. '              </EffectColumn>\n'
          has_data = true
        end
      end
      xml_data = xml_data .. '            </EffectColumns>\n'
      if not has_data then
        xml_data = xml_data .. '          <Line />\n'
      end
      xml_data = xml_data .. '          </Line>\n'
    end
    xml_data = xml_data .. '        </Lines>\n        <ColumnType>EffectColumn</ColumnType>\n'
    xml_data = xml_data .. '        <SubColumnMask>' .. get_sub_column_mask(track, 'effect') .. '</SubColumnMask>\n'
    xml_data = xml_data .. '      </Column>\n'
    xml_data = xml_data .. '    </Column>\n'
  end

  xml_data = xml_data .. '  </Columns>\n</PatternClipboard.BlockBuffer>\n'

  -- Write XML to file
  local file = io.open(xml_file_path, "w")
  if file then
    file:write(xml_data)
    file:close()
    renoise.app():show_status("Selection saved to mixpaste.xml.")
    print("Saved selection to mixpaste.xml")
  else
    renoise.app():show_status("Error writing to mixpaste.xml.")
    print("Error writing to mixpaste.xml")
  end
end

-- Utility function to generate the SubColumnMask for note or effect columns
function get_sub_column_mask(track, column_type)
  local mask = {}
  if column_type == 'note' then
    for i = 1, track.visible_note_columns do
      mask[i] = 'true'
    end
  elseif column_type == 'effect' then
    for i = 1, track.visible_effect_columns do
      mask[i] = 'true'
    end
  end
  for i = #mask + 1, 8 do
    mask[i] = 'false'
  end
  return table.concat(mask, ' ')
end

-- Function to load the pattern data from mixpaste.xml and paste at the current cursor line
function load_xml_into_selection()
  local song = renoise.song()
  local cursor_line = song.selected_line_index
  local cursor_track = song.selected_track_index

  -- Open the mixpaste.xml file
  local xml_file = io.open(xml_file_path, "r")
  if not xml_file then
    renoise.app():show_status("Error reading mixpaste.xml.")
    print("Error reading mixpaste.xml.")
    return
  end

  local xml_data = xml_file:read("*a")
  xml_file:close()

  -- Parse the XML data manually (basic parsing for this use case)
  local parsed_data = parse_xml_data(xml_data)
  if not parsed_data or #parsed_data.lines == 0 then
    renoise.app():show_status("No valid data in mixpaste.xml.")
    print("No valid data in mixpaste.xml.")
    return
  end

  print("Parsed XML data successfully.")

  -- Insert parsed data starting at the cursor position
  local total_lines = #parsed_data.lines
  for line_index, line_data in ipairs(parsed_data.lines) do
    local target_line = cursor_line + line_index - 1
    if target_line > #song.patterns[song.selected_pattern_index].tracks[cursor_track].lines then
      break -- Avoid exceeding pattern length
    end

    local pattern_track = song.patterns[song.selected_pattern_index].tracks[cursor_track]
    local pattern_line = pattern_track:line(target_line)
    
    -- Handle NoteColumns
    for column_index, note_column_data in ipairs(line_data.note_columns) do
      local note_column = pattern_line:note_column(column_index)
      if note_column_data.note ~= "" then
        note_column.note_string = note_column_data.note
        note_column.instrument_string = note_column_data.instrument
        print("Pasting note: " .. (note_column_data.note or "nil") .. " at line " .. target_line .. ", column " .. column_index)
      end
    end

    -- Handle EffectColumns
    for column_index, effect_column_data in ipairs(line_data.effect_columns) do
      local effect_column = pattern_line:effect_column(column_index)
      if effect_column_data.effect_number ~= "" then
        effect_column.number_string = effect_column_data.effect_number
        effect_column.amount_string = effect_column_data.effect_value
        print("Pasting effect: " .. (effect_column_data.effect_number or "nil") .. " with value " .. (effect_column_data.effect_value or "nil") .. " at line " .. target_line .. ", column " .. column_index)
      end
    end
  end

  renoise.app():show_status("Pattern data loaded from mixpaste.xml.")
  print("Pattern data loaded from mixpaste.xml.")
end

-- Basic XML parsing function
function parse_xml_data(xml_string)
  local parsed_data = { lines = {} }
  local line_count = 0
  for line_content in xml_string:gmatch("<Line.-index=\"(.-)\">(.-)</Line>") do
    local line_index = tonumber(line_content:match("index=\"(.-)\""))
    local line_data = { note_columns = {}, effect_columns = {} }

    -- Parsing NoteColumns
    for note_column_content in line_content:gmatch("<NoteColumn>(.-)</NoteColumn>") do
      local note = note_column_content:match("<Note>(.-)</Note>") or ""
      local instrument = note_column_content:match("<Instrument>(.-)</Instrument>") or ""
      table.insert(line_data.note_columns, { note = note, instrument = instrument })
    end

    -- Parsing EffectColumns
    for effect_column_content in line_content:gmatch("<EffectColumn>(.-)</EffectColumn>") do
      local effect_number = effect_column_content:match("<EffectNumber>(.-)</EffectNumber>") or ""
      local effect_value = effect_column_content:match("<EffectValue>(.-)</EffectValue>") or ""
      table.insert(line_data.effect_columns, { effect_number = effect_number, effect_value = effect_value })
    end

    table.insert(parsed_data.lines, line_data)
    line_count = line_count + 1
  end
  print("Parsed " .. line_count .. " lines from XML.")
  return parsed_data
end

-- Keybindings to invoke the save and load functions
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Save",
  invoke=function() save_selection_as_xml() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Load",
  invoke=function() load_xml_into_selection() end}














-- Define the simplified table for base time divisions from 1/1 to 1/128
local base_time_divisions = {
  [1] = "1 / 1", [2] = "1 / 2", [3] = "1 / 4", [4] = "1 / 8", 
  [5] = "1 / 16", [6] = "1 / 32", [7] = "1 / 64", [8] = "1 / 128"
}

-- Function to load and apply parameters to the Repeater device
function PakettiRepeaterParameters(step, mode)
  -- Check if the Repeater device is already on the selected track
  local track = renoise.song().selected_track
  local device_found = false
  local device_index = nil
  
  for i, device in ipairs(track.devices) do
    if device.display_name == "Repeater" then
      device_found = true
      device_index = i
      break
    end
  end
  
  -- Determine the mode name based on mode value
  local mode_name = "Even"
  if mode == 3 then
    mode_name = "Triplet"
  elseif mode == 4 then
    mode_name = "Dotted"
  end

  -- If the device is found, check if the mode/step match
  if device_found then
    local device = track.devices[device_index]
    local current_mode = device.parameters[1].value
    local current_step_string = device.parameters[2].value_string -- Use value_string for step comparison
    
    -- If mode/step matches and device is active, deactivate the device
    if device.is_active then
      if current_mode == mode and current_step_string == base_time_divisions[step] then
        device.is_active = false
        renoise.app():show_status("Repeater bypassed")
      else
        -- If mode/step doesn't match, update parameters
        device.parameters[1].value = mode -- Set the correct mode
        device.parameters[2].value_string = base_time_divisions[step] -- Set the correct step using value_string
        renoise.app():show_status("Repeater mode/step updated to: "..base_time_divisions[step].." "..mode_name)
      end
    else
      -- If device is bypassed, update parameters and activate
      device.parameters[1].value = mode -- Set the correct mode
      device.parameters[2].value_string = base_time_divisions[step] -- Set the correct step using value_string
      device.is_active = true
      renoise.app():show_status("Repeater activated with mode/step: "..base_time_divisions[step].." "..mode_name)
    end
  else
    -- If the device is not found, load it and apply the parameters
    loadnative("Audio/Effects/Native/Repeater",nil,"./Presets/PakettiRepeaterHoldOff.xml")
    renoise.app():show_status("Repeater loaded and parameters set")
    
    -- Set the mode (parameter 1)
    track.devices[#track.devices].parameters[1].value = mode
    
    -- Set the step parameter using value_string
    if step ~= nil then
      track.devices[#track.devices].parameters[2].value_string = base_time_divisions[step] -- Set the chosen step using value_string
      renoise.app():show_status("Repeater step set to: "..base_time_divisions[step].." "..mode_name)
    end
  end
end

-- Create keybindings for "Even", "Dotted", and "Triplet" for each base time division
for step = 1, #base_time_divisions do
  -- Even (mode 2)
  renoise.tool():add_keybinding{name="Global:Paketti:Repeater " .. base_time_divisions[step] .. " Even",
    invoke=function() PakettiRepeaterParameters(step, 2) end} -- Mode 2 is Even
 
  
  -- Triplet (mode 3)
  renoise.tool():add_keybinding{name="Global:Paketti:Repeater " .. base_time_divisions[step] .. " Triplet",
    invoke=function() PakettiRepeaterParameters(step, 3) end} -- Mode 3 is Triplet
  
  -- Dotted (mode 4)
  renoise.tool():add_keybinding{name="Global:Paketti:Repeater " .. base_time_divisions[step] .. " Dotted",
    invoke=function() PakettiRepeaterParameters(step, 4) end} -- Mode 4 is Dotted
end
---------------



function shrink_to_triplets()
    local song = renoise.song()
    local track = song.selected_pattern.tracks[renoise.song().selected_track_index]
    local pattern_length = song.selected_pattern.number_of_lines

    local note_positions = {}

    -- Collect all notes and their positions
    for line_index = 1, pattern_length do
        local line = track:line(line_index)
        local note_column = line.note_columns[1]

        if not note_column.is_empty then
            -- Manually clone the note data
            table.insert(note_positions, {line_index, {
                note_value = note_column.note_value,
                instrument_value = note_column.instrument_value,
                volume_value = note_column.volume_value,
                panning_value = note_column.panning_value,
                delay_value = note_column.delay_value
            }})
        end
    end

    -- Ensure we have enough notes to work with
    if #note_positions < 2 then
        renoise.app():show_status("Not enough notes to apply triplet structure.")
        return
    end

    -- Calculate the original spacing between notes
    local original_spacing = note_positions[2][1] - note_positions[1][1]

    -- Determine the modifier based on the spacing
    local modifier = math.floor(original_spacing / 2)  -- Will be 1 for 2-row spacing and 2 for 4-row spacing
    local cycle_step = 0

    -- Clear the pattern before applying the triplets
    for line_index = 1, pattern_length do
        track:line(line_index):clear()
    end

    -- Apply triplet logic based on the original spacing
    local new_index = note_positions[1][1]  -- Start at the first note

    for i = 1, #note_positions do
        local note_data = note_positions[i][2]
        local target_line = track:line(new_index)

        -- Triplet Logic
        if original_spacing == 2 then
            -- Case for notes every 2 rows
            if cycle_step == 0 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x00
            elseif cycle_step == 1 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x55
            elseif cycle_step == 2 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0xAA

                -- Add extra empty row after AA
                new_index = new_index + 1
            end

            -- Move to the next row
            new_index = new_index + 1
            cycle_step = (cycle_step + 1) % 3

        elseif original_spacing == 4 then
            -- Case for notes every 4 rows
            if cycle_step == 0 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x00
            elseif cycle_step == 1 then
                -- Move the note up by 2 rows and apply AA delay
                new_index = new_index + 2
                target_line = track:line(new_index)
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0xAA

                -- Add one empty row after AA
                new_index = new_index + 1
            elseif cycle_step == 2 then
                -- Apply 55 delay and move up by 1 row
                target_line = track:line(new_index)
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x55

                -- Add one empty row after 55
                new_index = new_index + 1
            end

            -- Move to the next row
            new_index = new_index + 1
            cycle_step = (cycle_step + 1) % 3
        end
    end

    renoise.app():show_status("Shrink to triplets applied successfully.")
end

-- Keybinding for the script
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Shrink to Triplets",invoke=function() shrink_to_triplets() end}

function triple(first,second,where)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index+first].note_columns[1]:copy_from(renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[1])
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index+second].note_columns[1]:copy_from(renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[1])


local wherenext=renoise.song().selected_line_index+where

if wherenext > renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines then
wherenext=1 
renoise.song().selected_line_index = wherenext return
else  renoise.song().selected_line_index=renoise.song().selected_line_index+where
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Triple (Experimental)",invoke=function() triple(3,6,8) end}

--------
function xypad()
local vb = renoise.ViewBuilder()
local dialog = nil

-- Initial center position
local initial_position = 0.5
local prev_x = initial_position
local prev_y = initial_position

-- Adjust the shift and rotation amounts
local shift_amount = 1  -- Reduced shift amount for smaller up/down changes
local rotation_amount = 2000  -- Adjusted rotation amount for left/right to be less intense

-- Custom key handler function
local function my_keyhandler_func(dialog, key)
  if not (key.modifiers == "" and key.name == "exclamation") then
    return key
  else
    dialog:close()
    dialog = nil
    return nil
  end
end

-- Set the middle frame to the instrument sample editor
renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

-- Function to wrap the sample value
local function wrap_sample_value(value)
  if value > 1.0 then
    return value - 2.0
  elseif value < -1.0 then
    return value + 2.0
  else
    return value
  end
end

-- Function to shift the sample buffer upwards with wrap-around
local function PakettiXYPadSampleRotatorUp(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value * 1000  -- Adjusted to match the desired intensity
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted upwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to shift the sample buffer downwards with wrap-around
local function PakettiXYPadSampleRotatorDown(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value * 1000  -- Adjusted to match the desired intensity
        local new_value = wrap_sample_value(current_value - shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted downwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to rotate sample buffer content forwards by a specified number of frames
local function PakettiXYPadSampleRotatorRight(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + rotation_amount * knob_value - 1) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer rotated forward by "..(rotation_amount * knob_value).." frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

-- Function to rotate sample buffer content backwards by a specified number of frames
local function PakettiXYPadSampleRotatorLeft(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i - rotation_amount * knob_value - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer rotated backward by "..(rotation_amount * knob_value).." frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

-- Function to handle XY pad changes and call appropriate rotator functions
local function on_xy_change(value)
  local x = value.x
  local y = value.y

  -- Compare current x and y with previous values to determine direction
  if x > prev_x then
    PakettiXYPadSampleRotatorRight(x - prev_x) -- Moving right
  elseif x < prev_x then
    PakettiXYPadSampleRotatorLeft(prev_x - x) -- Moving left
  end

  if y > prev_y then
    PakettiXYPadSampleRotatorUp(y - prev_y) -- Moving up
  elseif y < prev_y then
    PakettiXYPadSampleRotatorDown(prev_y - y) -- Moving down
  end

  -- Update previous x and y with the current position
  prev_x = x
  prev_y = y

  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to handle vertical slider change (up/down)
local function on_vertical_slider_change(value)
  if value > initial_position then
    PakettiXYPadSampleRotatorUp(value - initial_position)
  elseif value < initial_position then
    PakettiXYPadSampleRotatorDown(initial_position - value)
  end
  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to handle horizontal slider change (left/right)
local function on_horizontal_slider_change(value)
  if value > initial_position then
    PakettiXYPadSampleRotatorRight(value - initial_position)
  elseif value < initial_position then
    PakettiXYPadSampleRotatorLeft(initial_position - value)
  end
  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to display the dialog with the XY pad and sliders
local function show_paketti_sample_rotator_dialog()
  -- Reset the XY pad to the center (0.5, 0.5)
  prev_x = initial_position
  prev_y = initial_position

  if dialog and dialog.visible then
    dialog:show()
    return
  end

  dialog = renoise.app():show_custom_dialog("Paketti XYPad Sample Rotator",
    vb:column{
      vb:row{
        vb:xypad{
          width = 200,
          height = 200,
          notifier = on_xy_change,
          value = {x = initial_position, y = initial_position} -- Center the XY pad
        },
        vb:vertical_aligner{
          mode = "center",
          vb:slider{
            height = 200,
            min = 0.0,
            max = 1.0,
            value = initial_position,
            notifier = on_vertical_slider_change
          }
        }
      },
      vb:horizontal_aligner{
        mode = "center",
        vb:slider{
          width = 200,
          min = 0.0,
          max = 1.0,
          value = initial_position,
          notifier = on_horizontal_slider_change
        }
      }
    },
    my_keyhandler_func
  )
end

-- Show the dialog when the script is run
--show_paketti_sample_rotator_dialog()

end


------------------
-- Updated shift amount
local shift_amount = 0.01  -- Default value for subtle shifts

-- Function to wrap the sample value
local function wrap_sample_value(value)
  if value > 1.0 then
    return value - 2.0
  elseif value < -1.0 then
    return value + 2.0
  else
    return value
  end
end

-- Function to shift the sample buffer upwards with wrap-around
function PakettiShiftSampleBufferUpwards(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted upwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to wrap the sample value correctly
local function wrap_sample_value(value)
  if value < -1.0 then
      return value + 2.0  -- Simple wrap from bottom to top
  elseif value > 1.0 then
      return value - 2.0  -- Simple wrap from top to bottom
  end
  return value
end

function PakettiShiftSampleBufferDownwards(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
      -- First, read ALL values before modifying anything
      local values = {}
      for c = 1, buffer.number_of_channels do
          values[c] = {}
          for i = 1, buffer.number_of_frames do
              values[c][i] = buffer:sample_data(c, i)
          end
      end

      print("\nBefore shift (all frames):")
      for c = 1, buffer.number_of_channels do
          print("Channel " .. c .. ":")
          for i = 1, buffer.number_of_frames do
              print(string.format("Frame %d: %.12f", i, values[c][i]))
          end
      end

      buffer:prepare_sample_data_changes()
      
      local shift_value = shift_amount * knob_value
      
      -- Calculate new values before writing any of them
      local new_values = {}
      for c = 1, buffer.number_of_channels do
          new_values[c] = {}
          for i = 1, buffer.number_of_frames do
              local current_value = values[c][i]
              if math.abs(current_value + 1.0) < 0.000001 then
                  new_values[c][i] = 1.0 - shift_value
              else
                  new_values[c][i] = current_value - shift_value
              end
              
              print(string.format(
                  "Frame %d: %.12f %s shifted by %.12f = %.12f",
                  i,
                  current_value,
                  (math.abs(current_value + 1.0) < 0.000001) and "wrapped to 1.0 then" or "",
                  shift_value,
                  new_values[c][i]
              ))
          end
      end
      
      -- Now write all the new values
      for c = 1, buffer.number_of_channels do
          for i = 1, buffer.number_of_frames do
              buffer:set_sample_data(c, i, new_values[c][i])
              print(string.format("   Frame %d actually stored as: %.12f", i, buffer:sample_data(c, i)))
          end
      end
      
      buffer:finalize_sample_data_changes()

      print("\nAfter shift (all frames):")
      for c = 1, buffer.number_of_channels do
          print("Channel " .. c .. ":")
          for i = 1, buffer.number_of_frames do
              print(string.format("Frame %d: %.12f", i, buffer:sample_data(c, i)))
          end
      end

      print("\nShift parameters:")
      print(string.format("knob_value: %.12f", knob_value))
      print(string.format("shift_amount: %.12f", shift_amount))
      print(string.format("total shift: %.12f", shift_amount * knob_value))

      renoise.app():show_status("Sample buffer shifted downwards with wrap-around.")
  else
      renoise.app():show_status("No sample data to shift.")
  end
end










-- Function to shift the sample buffer based on knob position (Up/Down)
function PakettiShiftSampleBuffer(knob_value)
  local song = renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local direction = 0
    if knob_value <= 63 then
      direction = -1  -- Shift downwards
    else
      direction = 1  -- Shift upwards
    end
    local adjusted_knob_value = math.abs(knob_value - 64) / 63  -- Normalize to 0...1 range
    
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * adjusted_knob_value * direction
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted " .. (direction > 0 and "upwards" or "downwards") .. " with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up x[Trigger]",invoke=function(message) if message:is_trigger() then PakettiShiftSampleBufferUpwards(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Down x[Trigger]",invoke=function(message) if message:is_trigger() then PakettiShiftSampleBufferDownwards(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up x[Knob]",invoke=function(message) local knob_value = message.int_value / 127 PakettiShiftSampleBufferUpwards(knob_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Down x[Knob]",invoke=function(message) local knob_value = message.int_value / 127 PakettiShiftSampleBufferDownwards(knob_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up/Down x[Knob]",invoke=function(message) PakettiShiftSampleBuffer(message.int_value) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Upwards",invoke=function() PakettiShiftSampleBufferUpwards(1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Downwards",invoke=function() PakettiShiftSampleBufferDownwards(1) end}















--[[
local function randomizeSmatterEffectColumnCustom(effect_command)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local selection = song.selection_in_pattern
  local randomize = function()
    return string.format("%02X", math.random(1, 255))
  end

  local apply_command = function(line)
    local effect_column = line.effect_columns[1]
    if math.random() > 0.5 then
      effect_column.number_string = effect_command
      effect_column.amount_string = randomize()
    else
      effect_column:clear()
    end
  end

  if selection then
    for line_index = selection.start_line, selection.end_line do
      local line = pattern:track(track_index).lines[line_index]
      apply_command(line)
    end
  else
    for sequence_index, sequence in ipairs(song.sequencer.pattern_sequence) do
      if song:pattern(sequence).tracks[track_index] then
        local lines = song:pattern(sequence).number_of_lines
        for line_index = 1, lines do
          local line = song:pattern(sequence).tracks[track_index].lines[line_index]
          apply_command(line)
        end
      end
    end
  end

  renoise.app():show_status("Random " .. effect_command .. " commands applied to the first effect column of the selected track.")
end
]]--
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (C00/C0F)",invoke=function() randomizeSmatterEffectColumnCustom("0C", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (0G Glide)",invoke=function() randomizeSmatterEffectColumnCustom("0G", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (0U Slide Up)",invoke=function() randomizeSmatterEffectColumnCustom("0U", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (0D Slide Down)",invoke=function() randomizeSmatterEffectColumnCustom("0D", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (0R Retrig)",invoke=function() randomizeSmatterEffectColumnCustom("0R", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (0P Panning)",invoke=function() randomizeSmatterEffectColumnCustom("0P", false,0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Smatter (0B00/0B01)",invoke=function() randomizeSmatterEffectColumnCustom("0B", false, 0x00, 0xFF) end}


renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (C00/C0F)",invoke=function() randomizeSmatterEffectColumnCustom("0C", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (0G Glide)",invoke=function() randomizeSmatterEffectColumnCustom("0G", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (0U Slide Up)",invoke=function() randomizeSmatterEffectColumnCustom("0U", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (0D Slide Down)",invoke=function() randomizeSmatterEffectColumnCustom("0D", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (0R Retrig)",invoke=function() randomizeSmatterEffectColumnCustom("0R", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (0P Panning)",invoke=function() randomizeSmatterEffectColumnCustom("0P", true,0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Tools:Randomize Effect Column Fill (0B00/0B01)",invoke=function() randomizeSmatterEffectColumnCustom("0B", true, 0x00, 0xFF) end}



------------------------





----
-- Utility function to check if a table contains a value
function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

-- Function to unmute all tracks and send tracks except the master track
function PakettiToggleSoloTracksUnmuteAllTracks()
  local song = renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  print("----")
  print("Unmuting all tracks")
  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end
end

-- Function to mute all tracks except a specific range, and not the master track
function PakettiToggleSoloTracksMuteAllExceptRange(start_track, end_track)
  local song = renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count
  local group_parents = {}

  print("----")
  print("Muting all tracks except range: " .. start_track .. " to " .. end_track)
  for i = start_track, end_track do
    if song:track(i).group_parent then
      local group_parent = song:track(i).group_parent.name
      if not table_contains(group_parents, group_parent) then
        table.insert(group_parents, group_parent)
      end
    end
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      if i < start_track or i > end_track then
        song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
        print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
      end
    end
  end

  for i = start_track, end_track do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end

  for _, group_parent_name in ipairs(group_parents) do
    local group_parent_index = nil
    for i = 1, song.sequencer_track_count do
      if song:track(i).name == group_parent_name then
        group_parent_index = i
        break
      end
    end
    if group_parent_index then
      local group_parent = song:track(group_parent_index)
      group_parent.mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting group track: " .. group_parent.name)
    end
  end
end

-- Function to mute all tracks except a specific track and its group, and not the master track
function PakettiToggleSoloTracksMuteAllExceptSelectedTrack(track_index)
  local song = renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count
  local selected_track = song:track(track_index)
  local group_tracks = {}

  print("----")
  print("Muting all tracks except selected track: " .. track_index .. " (" .. selected_track.name .. ")")

  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    table.insert(group_tracks, track_index)
    print("Group name is " .. selected_track.name .. ", Number of Members is " .. #selected_track.members)
    for i = track_index + 1, track_index + #selected_track.members do
      if song:track(i).group_parent and song:track(i).group_parent.name == selected_track.name then
        table.insert(group_tracks, i)
        print("Member index: " .. i .. " (" .. song:track(i).name .. ")")
      else
        break
      end
    end
  elseif selected_track.group_parent then
    local group_parent = selected_track.group_parent.name
    for i = 1, song.sequencer_track_count do
      if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == group_parent then
        table.insert(group_tracks, i)
        print("Group parent: " .. group_parent .. " at index " .. i)
        break
      end
    end
    table.insert(group_tracks, track_index)
    print("Member index: " .. track_index .. " (" .. selected_track.name .. ")")
  else
    table.insert(group_tracks, track_index)
    print("Single track index: " .. track_index .. " (" .. selected_track.name .. ")")
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and not table_contains(group_tracks, i) then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
      print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end

  for _, group_track in ipairs(group_tracks) do
    if song:track(group_track).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(group_track).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. group_track .. " (" .. song:track(group_track).name .. ")")
    end
  end
end

-- Function to check if all tracks and send tracks are unmuted
function PakettiToggleSoloTracksAllTracksUnmuted()
  local song = renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      return false
    end
  end
  return true
end

-- Function to check if all tracks except the selected track and its group are muted
function PakettiToggleSoloTracksAllOthersMutedExceptSelected(track_index)
  local song = renoise.song()
  local selected_track = song:track(track_index)
  local group_tracks = {}
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    table.insert(group_tracks, track_index)
    for i = track_index + 1, song.sequencer_track_count do
      if song:track(i).group_parent and song:track(i).group_parent.name == selected_track.name then
        table.insert(group_tracks, i)
      else
        break
      end
    end
  elseif selected_track.group_parent then
    local group_parent = selected_track.group_parent.name
    for i = 1, song.sequencer_track_count do
      if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == group_parent then
        table.insert(group_tracks, i)
        break
      end
    end
    table.insert(group_tracks, track_index)
  else
    table.insert(group_tracks, track_index)
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and not table_contains(group_tracks, i) and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_OFF then
      return false
    end
  end
  return selected_track.mute_state == renoise.Track.MUTE_STATE_ACTIVE
end

-- Function to check if all tracks except the selected range are muted
function PakettiToggleSoloTracksAllOthersMutedExceptRange(start_track, end_track)
  local song = renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count
  local group_parents = {}

  print("Selection In Pattern is from index " .. start_track .. " to index " .. end_track)
  for i = start_track, end_track do
    print("Track index: " .. i .. " (" .. song:track(i).name .. ")")
    if song:track(i).group_parent then
      local group_parent = song:track(i).group_parent.name
      if not table_contains(group_parents, group_parent) then
        table.insert(group_parents, group_parent)
        print("Group parent: " .. group_parent)
      end
    end
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and (i < start_track or i > end_track) and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_OFF then
      return false
    end
  end
  for i = start_track, end_track do
    if song:track(i).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      return false
    end
  end

  for _, group_parent_name in ipairs(group_parents) do
    local group_parent_index = nil
    for i = 1, song.sequencer_track_count do
      if song:track(i).name == group_parent_name then
        group_parent_index = i
        break
      end
    end
    if group_parent_index then
      local group_parent = song:track(group_parent_index)
      if group_parent.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
        return false
      end
    end
  end
  return true
end

-- Main function to toggle mute states
function PakettiToggleSoloTracks()
  local song = renoise.song()
  local sip = song.selection_in_pattern
  local selected_track_index = song.selected_track_index
  local selected_track = song:track(selected_track_index)

  print("----")
  print("Running PakettiToggleSoloTracks")

  if sip then
    -- If a selection in pattern exists
    print("Selection In Pattern is from index " .. sip.start_track .. " to " .. sip.end_track)
    for i = sip.start_track, sip.end_track do
      print("Track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
    if PakettiToggleSoloTracksAllOthersMutedExceptRange(sip.start_track, sip.end_track) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      print("Detecting Muting situation")
      PakettiToggleSoloTracksMuteAllExceptRange(sip.start_track, sip.end_track)
    end
  elseif selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    -- If the selected track is a group, mute all tracks and then unmute the group and its members
    print("Selected track is a group")
    print("Group name is " .. selected_track.name .. ", Number of Members is " .. #selected_track.members)
    if PakettiToggleSoloTracksAllOthersMutedExceptSelected(selected_track_index) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      for i = 1, song.sequencer_track_count + song.send_track_count do
        if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
          song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
          print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
        end
      end
      for i = selected_track_index - #selected_track.members, selected_track_index do
        song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
        print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
      end
    end
  else
    -- If no selection in pattern and selected track is not a group
    print("No selection in pattern, using selected track: " .. selected_track_index .. " (" .. selected_track.name .. ")")
    if PakettiToggleSoloTracksAllOthersMutedExceptSelected(selected_track_index) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      print("Detecting Muting situation")
      PakettiToggleSoloTracksMuteAllExceptSelectedTrack(selected_track_index)
    end
  end
end

-- Add menu entry, keybinding, and MIDI mapping for the toggle solo tracks function
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Pattern Editor..:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}

-- Define the function to toggle mute state
function toggle_mute_tracks()
  -- Get the current song
  local song = renoise.song()

  -- Determine the range of selected tracks
  local selection = song.selection_in_pattern

  -- Check if there is a valid selection
  local start_track, end_track
  if selection then
    start_track = selection.start_track
    end_track = selection.end_track
  end

  -- If no specific selection is made, operate on the currently selected track
  if not start_track or not end_track then
    start_track = song.selected_track_index
    end_track = song.selected_track_index
  end

  -- Check if any track in the selection is muted, ignoring the master track
  local any_track_muted = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
      any_track_muted = true
      break
    end
  end

  -- Determine the desired mute state for all tracks
  local new_mute_state
  if any_track_muted then
    new_mute_state = renoise.Track.MUTE_STATE_OFF
  else
    new_mute_state = renoise.Track.MUTE_STATE_ACTIVE
  end

  -- Iterate over the range of tracks and set the new mute state, ignoring the master track
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      track.mute_state = new_mute_state
    end
  end

  -- Additionally, handle groups if they are within the selected range
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_GROUP then
      local group = track.group_parent
      if group then
        -- Set the mute state for the group and its member tracks, ignoring the master track
        set_group_mute_state(group, new_mute_state)
      end
    end
  end
end

-- Helper function to set mute state for a group and its member tracks
function set_group_mute_state(group, mute_state)
  -- Ensure we don't attempt to mute the master track
  if group.type ~= renoise.Track.TRACK_TYPE_MASTER then
    group.mute_state = mute_state
  end

  -- Set mute state for all member tracks of the group, ignoring the master track
  for _, track in ipairs(group.members) do
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      track.mute_state = mute_state
    end
  end
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute Tracks",invoke=toggle_mute_tracks}








--------
-- Function to initialize selection if it is nil
function PakettiImpulseTrackerShiftInitializeSelection()
  local song = renoise.song()
  local pos = song.transport.edit_pos
  local selected_track_index = song.selected_track_index
  local selected_column_index = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index

  song.selection_in_pattern = {
    start_track = selected_track_index,
    end_track = selected_track_index,
    start_column = selected_column_index,
    end_column = selected_column_index,
    start_line = pos.line,
    end_line = pos.line
  }
end

-- Function to ensure selection is valid and swap if necessary
function PakettiImpulseTrackerShiftEnsureValidSelection()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if selection.start_track > selection.end_track then
    local temp = selection.start_track
    selection.start_track = selection.end_track
    selection.end_track = temp
  end

  if selection.start_column > selection.end_column then
    local temp = selection.start_column
    selection.start_column = selection.end_column
    selection.end_column = temp
  end

  if selection.start_line > selection.end_line then
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  song.selection_in_pattern = selection
end

-- Debug function to print selection details
local function debug_print_selection(message)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  print(message)
print("--------")
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)
print("--------")

end

-- Function to select the next column or track to the right
function PakettiImpulseTrackerShiftRight()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Right Shift")

  if song.selected_track_index == selection.end_track and (song.selected_note_column_index == selection.end_column or song.selected_effect_column_index == selection.end_column) then
    if selection.end_column < song:track(selection.end_track).visible_note_columns then
      selection.end_column = selection.end_column + 1
    elseif selection.end_track < #song.tracks then
      selection.end_track = selection.end_track + 1
      local track = song:track(selection.end_track)
      if track.visible_note_columns > 0 then
        selection.end_column = 1
      else
        selection.end_column = track.visible_effect_columns > 0 and 1 or 0
      end
    else
      renoise.app():show_status("You are on the last track. No more can be selected in that direction.")
      return
    end
  else
    if song.selected_track_index < selection.start_track then
      local temp_track = selection.start_track
      selection.start_track = selection.end_track
      selection.end_track = temp_track

      local temp_column = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp_column
    end
    selection.start_track = song.selected_track_index
    selection.start_column = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  if song:track(selection.end_track).visible_note_columns > 0 then
    song.selected_note_column_index = selection.end_column
  else
    song.selected_effect_column_index = selection.end_column
  end

  debug_print_selection("After Right Shift")
end

-- Function to select the previous column or track to the left
function PakettiImpulseTrackerShiftLeft()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Left Shift")

  if song.selected_track_index == selection.end_track and (song.selected_note_column_index == selection.end_column or song.selected_effect_column_index == selection.end_column) then
    if selection.end_column > 1 then
      selection.end_column = selection.end_column - 1
    elseif selection.end_track > 1 then
      selection.end_track = selection.end_track - 1
      local track = song:track(selection.end_track)
      if track.visible_note_columns > 0 then
        selection.end_column = track.visible_note_columns
      else
        selection.end_column = track.visible_effect_columns > 0 and track.visible_effect_columns or 0
      end
    else
      renoise.app():show_status("You are on the first track. No more can be selected in that direction.")
      return
    end
  else
    if song.selected_track_index > selection.start_track then
      local temp_track = selection.start_track
      selection.start_track = selection.end_track
      selection.end_track = temp_track

      local temp_column = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp_column
    end
    selection.start_track = song.selected_track_index
    selection.start_column = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  if song:track(selection.end_track).visible_note_columns > 0 then
    song.selected_note_column_index = selection.end_column
  else
    song.selected_effect_column_index = selection.end_column
  end

  debug_print_selection("After Left Shift")
end

-- Function to extend the selection down by one line
function PakettiImpulseTrackerShiftDown()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  local current_pattern = song.selected_pattern_index

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Down Shift")

  if song.transport.edit_pos.line == selection.end_line then
    if selection.end_line < song:pattern(current_pattern).number_of_lines then
      selection.end_line = selection.end_line + 1
    else
      renoise.app():show_status("You are at the end of the pattern. No more can be selected.")
      return
    end
  else
    if song.transport.edit_pos.line < selection.start_line then
      local temp_line = selection.start_line
      selection.start_line = selection.end_line
      selection.end_line = temp_line
    end
    selection.start_line = song.transport.edit_pos.line
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection
  song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)

  debug_print_selection("After Down Shift")
end

-- Main function to determine which shift up function to call
function PakettiImpulseTrackerShiftUp()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  if selection.start_column == selection.end_column then
    PakettiImpulseTrackerShiftUpSingleColumn()
  else
    PakettiImpulseTrackerShiftUpMultipleColumns()
  end
end

-- Function to extend the selection up by one line in a single column
function PakettiImpulseTrackerShiftUpSingleColumn()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  local edit_pos = song.transport.edit_pos

  debug_print_selection("Before Up Shift (Single Column)")

  -- Determine the current column index based on the track type
  local current_column_index
  if song:track(song.selected_track_index).visible_note_columns > 0 then
    current_column_index = song.selected_note_column_index
  else
    current_column_index = song.selected_effect_column_index
  end

  -- Check if the cursor is within the current selection
  local cursor_in_selection = song.selected_track_index == selection.start_track and
                              song.selected_track_index == selection.end_track and
                              current_column_index == selection.start_column and
                              edit_pos.line >= selection.start_line and
                              edit_pos.line <= selection.end_line

  if not cursor_in_selection then
    -- Reset the selection to start from the current cursor position if the cursor is not within the selection
    selection.start_track = song.selected_track_index
    selection.end_track = song.selected_track_index
    selection.start_column = current_column_index
    selection.end_column = current_column_index
    selection.start_line = edit_pos.line
    selection.end_line = edit_pos.line

    if selection.start_line > 1 then
      selection.start_line = selection.start_line - 1
      song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
    else
      renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
      return
    end
  else
    -- Extend the selection upwards if the cursor is within the selection
    if edit_pos.line == selection.end_line then
      if selection.end_line > selection.start_line then
        selection.end_line = selection.end_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      elseif selection.end_line == selection.start_line then
        if selection.start_line > 1 then
          selection.start_line = selection.start_line - 1
          song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
        else
          renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
          return
        end
      end
    elseif edit_pos.line == selection.start_line then
      if selection.start_line > 1 then
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    else
      if edit_pos.line < selection.start_line then
        selection.start_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        selection.end_line = edit_pos.line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      end
    end
  end

  -- Ensure start_line is always <= end_line
  if selection.start_line > selection.end_line then
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  debug_print_selection("After Up Shift (Single Column)")
end

-- Function to extend the selection up by one line in multiple columns
function PakettiImpulseTrackerShiftUpMultipleColumns()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  local edit_pos = song.transport.edit_pos

  -- Print separator and current state
  print("----")
  print("Before Up Shift (Multiple Columns)")
  print("Current Line Index: " .. edit_pos.line)
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)

  -- Determine the current column index based on the track type
  local current_column_index
  if song:track(song.selected_track_index).visible_note_columns > 0 then
    current_column_index = song.selected_note_column_index
  else
    current_column_index = song.selected_effect_column_index
  end

  -- Print the current column index and edit position line
  print("Current Column Index: " .. current_column_index)
  print("Edit Position Line: " .. edit_pos.line)

  -- Check if the cursor is within the current selection
  local cursor_in_selection = song.selected_track_index == selection.start_track and
                              song.selected_track_index == selection.end_track and
                              current_column_index >= selection.start_column and
                              current_column_index <= selection.end_column and
                              edit_pos.line >= selection.start_line and
                              edit_pos.line <= selection.end_line

  print("Cursor in Selection: " .. tostring(cursor_in_selection))

  if not cursor_in_selection then
    -- Reset the selection to start from the current cursor position if the cursor is not within the selection
    print("Cursor not in selection, resetting selection.")
    selection.start_track = song.selected_track_index
    selection.end_track = song.selected_track_index
    selection.start_column = current_column_index
    selection.end_column = current_column_index
    selection.start_line = edit_pos.line
    selection.end_line = edit_pos.line

    if selection.start_line > 1 then
      selection.start_line = selection.start_line - 1
      song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
    else
      renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
      return
    end
  else
    -- Extend the selection upwards if the cursor is within the selection
    print("Cursor in selection, extending selection upwards.")
    if edit_pos.line == selection.end_line and current_column_index == selection.end_column then
      if selection.end_line > selection.start_line then
        print("Decrementing end_line")
        selection.end_line = selection.end_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      elseif selection.start_line > 1 then
        print("Decrementing start_line")
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    elseif edit_pos.line == selection.start_line and current_column_index == selection.start_column then
      if selection.start_line > 1 then
        print("Decrementing start_line")
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    else
      if edit_pos.line < selection.start_line then
        print("Adjusting start_line to edit position")
        selection.start_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        print("Adjusting end_line to edit position")
        selection.end_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      end
    end
  end

  -- Ensure start_line is always <= end_line
  if selection.start_line > selection.end_line then
    print("Swapping start_line and end_line to ensure start_line <= end_line")
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  -- Print separator and current state after the operation
  print("After Up Shift (Multiple Columns)")
  print("Current Line Index: " .. song.transport.edit_pos.line)
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)
  print("----")
end


















-- Add key bindings for the functions
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Right Selection In Pattern",invoke=PakettiImpulseTrackerShiftRight}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Left Selection In Pattern",invoke=PakettiImpulseTrackerShiftLeft}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Down Selection In Pattern",invoke=PakettiImpulseTrackerShiftDown}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Up Selection In Pattern",invoke=PakettiImpulseTrackerShiftUp}


-- Function to copy a single note column
function PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src, dst)
  if src and dst then
    dst.note_value = src.note_value
    dst.instrument_value = src.instrument_value
    dst.volume_value = src.volume_value
    dst.panning_value = src.panning_value
    dst.delay_value = src.delay_value
    dst.effect_number_value = src.effect_number_value
    dst.effect_amount_value = src.effect_amount_value
  elseif dst then
    dst:clear()
  end
end

-- Function to copy a single effect column
function PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src, dst)
  if src and dst then
    dst.number_value = src.number_value
    dst.amount_value = src.amount_value
  elseif dst then
    dst:clear()
  end
end

-- Slide selected column content down by one row in the current pattern
function PakettiImpulseTrackerSlideSelectedColumnDown()
  local song = renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines
  local column_index = song.selected_note_column_index
  local is_note_column = column_index > 0

  if not is_note_column then
    column_index = song.selected_effect_column_index
  end

  -- Store the content of the last row to move it to the first row
  local last_row_content
  if is_note_column then
    last_row_content = track:line(number_of_lines).note_columns[column_index]
  else
    last_row_content = track:line(number_of_lines).effect_columns[column_index]
  end

  -- Slide content down
  for line = number_of_lines, 2, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    if is_note_column then
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    else
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  -- Move the last row content to the first row and clear the last row
  local first_line = track:line(1)
  if is_note_column then
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(last_row_content, first_line.note_columns[column_index])
    track:line(number_of_lines).note_columns[column_index]:clear()
  else
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(last_row_content, first_line.effect_columns[column_index])
    track:line(number_of_lines).effect_columns[column_index]:clear()
  end
end

-- Slide selected column content up by one row in the current pattern
function PakettiImpulseTrackerSlideSelectedColumnUp()
  local song = renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines
  local column_index = song.selected_note_column_index
  local is_note_column = column_index > 0

  if not is_note_column then
    column_index = song.selected_effect_column_index
  end

  -- Store the content of the first row to move it to the last row
  local first_row_content
  if is_note_column then
    first_row_content = track:line(1).note_columns[column_index]
  else
    first_row_content = track:line(1).effect_columns[column_index]
  end

  -- Slide content up
  for line = 1, number_of_lines - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    if is_note_column then
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    else
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  -- Move the first row content to the last row and clear the first row
  local last_line = track:line(number_of_lines)
  if is_note_column then
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(first_row_content, last_line.note_columns[column_index])
    track:line(1).note_columns[column_index]:clear()
  else
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(first_row_content, last_line.effect_columns[column_index])
    track:line(1).effect_columns[column_index]:clear()
  end
end

-- Functions to slide selected columns up or down within a selection
local function slide_selected_columns_up(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  local first_row_content_note_columns = {}
  local first_row_content_effect_columns = {}

  for _, column_index in ipairs(selected_note_columns) do
    first_row_content_note_columns[column_index] = track:line(start_line).note_columns[column_index]
  end
  for _, column_index in ipairs(selected_effect_columns) do
    first_row_content_effect_columns[column_index] = track:line(start_line).effect_columns[column_index]
  end

  for line = start_line, end_line - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    for _, column_index in ipairs(selected_note_columns) do
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    end
    for _, column_index in ipairs(selected_effect_columns) do
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  local last_line = track:line(end_line)
  for _, column_index in ipairs(selected_note_columns) do
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(first_row_content_note_columns[column_index], last_line.note_columns[column_index])
    track:line(start_line).note_columns[column_index]:clear()
  end
  for _, column_index in ipairs(selected_effect_columns) do
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(first_row_content_effect_columns[column_index], last_line.effect_columns[column_index])
    track:line(start_line).effect_columns[column_index]:clear()
  end
end

local function slide_selected_columns_down(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  local last_row_content_note_columns = {}
  local last_row_content_effect_columns = {}

  for _, column_index in ipairs(selected_note_columns) do
    last_row_content_note_columns[column_index] = track:line(end_line).note_columns[column_index]
  end
  for _, column_index in ipairs(selected_effect_columns) do
    last_row_content_effect_columns[column_index] = track:line(end_line).effect_columns[column_index]
  end

  for line = end_line, start_line + 1, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    for _, column_index in ipairs(selected_note_columns) do
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    end
    for _, column_index in ipairs(selected_effect_columns) do
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  local first_line = track:line(start_line)
  for _, column_index in ipairs(selected_note_columns) do
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(last_row_content_note_columns[column_index], first_line.note_columns[column_index])
  end
  for _, column_index in ipairs(selected_effect_columns) do
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(last_row_content_effect_columns[column_index], first_line.effect_columns[column_index])
  end
end

-- Function to get selected columns in the current selection
local function get_selected_columns(track, start_line, end_line)
  local selected_note_columns = {}
  local selected_effect_columns = {}

  for column_index = 1, #track:line(start_line).note_columns do
    for line = start_line, end_line do
      if track:line(line).note_columns[column_index].is_selected then
        table.insert(selected_note_columns, column_index)
        break
      end
    end
  end

  for column_index = 1, #track:line(start_line).effect_columns do
    for line = start_line, end_line do
      if track:line(line).effect_columns[column_index].is_selected then
        table.insert(selected_effect_columns, column_index)
        break
      end
    end
  end

  return selected_note_columns, selected_effect_columns
end

-- Slide selected column content down by one row or the selection if it exists
function PakettiImpulseTrackerSlideDown()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if selection then
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(track_index)
    local start_line = selection.start_line
    local end_line = math.min(selection.end_line, pattern.number_of_lines)
    local selected_note_columns, selected_effect_columns = get_selected_columns(track, start_line, end_line)
    slide_selected_columns_down(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  else
    PakettiImpulseTrackerSlideSelectedColumnDown()
  end
end

-- Slide selected column content up by one row or the selection if it exists
function PakettiImpulseTrackerSlideUp()
  local song = renoise.song()
  local selection = song.selection_in_pattern

  if selection then
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(track_index)
    local start_line = selection.start_line
    local end_line = math.min(selection.end_line, pattern.number_of_lines)
    local selected_note_columns, selected_effect_columns = get_selected_columns(track, start_line, end_line)
    slide_selected_columns_up(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  else
    PakettiImpulseTrackerSlideSelectedColumnUp()
  end
end

-- Add menu entry for sliding selected column content down
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}

renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Other Trackers..:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}





--------------
-- Function to copy note columns
function PakettiImpulseTrackerSlideTrackCopyNoteColumns(src, dst)
  for i = 1, #src do
    if src[i] and dst[i] then
      dst[i].note_value = src[i].note_value
      dst[i].instrument_value = src[i].instrument_value
      dst[i].volume_value = src[i].volume_value
      dst[i].panning_value = src[i].panning_value
      dst[i].delay_value = src[i].delay_value
      dst[i].effect_number_value = src[i].effect_number_value
      dst[i].effect_amount_value = src[i].effect_amount_value
    elseif dst[i] then
      dst[i]:clear()
    end
  end
end

-- Function to copy effect columns
function PakettiImpulseTrackerSlideTrackCopyEffectColumns(src, dst)
  for i = 1, #src do
    if src[i] and dst[i] then
      dst[i].number_value = src[i].number_value
      dst[i].amount_value = src[i].amount_value
    elseif dst[i] then
      dst[i]:clear()
    end
  end
end

-- Slide selected track content down by one row in the current pattern
function PakettiImpulseTrackerSlideTrackDown()
  local song = renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines

  -- Store the content of the last row to move it to the first row
  local last_row_note_columns = {}
  local last_row_effect_columns = {}

  for pos, column in song.pattern_iterator:note_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == number_of_lines then
      table.insert(last_row_note_columns, column)
    end
  end

  for pos, column in song.pattern_iterator:effect_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == number_of_lines then
      table.insert(last_row_effect_columns, column)
    end
  end

  -- Slide content down
  for line = number_of_lines, 2, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    PakettiImpulseTrackerSlideTrackCopyNoteColumns(src_line.note_columns, dst_line.note_columns)
    PakettiImpulseTrackerSlideTrackCopyEffectColumns(src_line.effect_columns, dst_line.effect_columns)
  end

  -- Move the last row content to the first row
  local first_line = track:line(1)
  PakettiImpulseTrackerSlideTrackCopyNoteColumns(last_row_note_columns, first_line.note_columns)
  PakettiImpulseTrackerSlideTrackCopyEffectColumns(last_row_effect_columns, first_line.effect_columns)
end

-- Slide selected track content up by one row in the current pattern
function PakettiImpulseTrackerSlideTrackUp()
  local song = renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines

  -- Store the content of the first row to move it to the last row
  local first_row_note_columns = {}
  local first_row_effect_columns = {}

  for pos, column in song.pattern_iterator:note_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == 1 then
      table.insert(first_row_note_columns, column)
    end
  end

  for pos, column in song.pattern_iterator:effect_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == 1 then
      table.insert(first_row_effect_columns, column)
    end
  end

  -- Slide content up
  for line = 1, number_of_lines - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    PakettiImpulseTrackerSlideTrackCopyNoteColumns(src_line.note_columns, dst_line.note_columns)
    PakettiImpulseTrackerSlideTrackCopyEffectColumns(src_line.effect_columns, dst_line.effect_columns)
  end

  -- Move the first row content to the last row
  local last_line = track:line(number_of_lines)
  PakettiImpulseTrackerSlideTrackCopyNoteColumns(first_row_note_columns, last_line.note_columns)
  PakettiImpulseTrackerSlideTrackCopyEffectColumns(first_row_effect_columns, last_line.effect_columns)
end

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}

renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}






-----------
-- Define the XML content as a string
local InstrautomationXML = [[
<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="InstrumentAutomationDevice">
    <IsMaximized>true</IsMaximized>
    <ParameterNumber0>0</ParameterNumber0>
    <ParameterNumber1>1</ParameterNumber1>
    <ParameterNumber2>2</ParameterNumber2>
    <ParameterNumber3>3</ParameterNumber3>
    <ParameterNumber4>4</ParameterNumber4>
    <ParameterNumber5>5</ParameterNumber5>
    <ParameterNumber6>6</ParameterNumber6>
    <ParameterNumber7>7</ParameterNumber7>
    <ParameterNumber8>8</ParameterNumber8>
    <ParameterNumber9>9</ParameterNumber9>
    <ParameterNumber10>10</ParameterNumber10>
    <ParameterNumber11>11</ParameterNumber11>
    <ParameterNumber12>12</ParameterNumber12>
    <ParameterNumber13>13</ParameterNumber13>
    <ParameterNumber14>14</ParameterNumber14>
    <ParameterNumber15>15</ParameterNumber15>
    <ParameterNumber16>16</ParameterNumber16>
    <ParameterNumber17>17</ParameterNumber17>
    <ParameterNumber18>18</ParameterNumber18>
    <ParameterNumber19>19</ParameterNumber19>
    <ParameterNumber20>20</ParameterNumber20>
    <ParameterNumber21>21</ParameterNumber21>
    <ParameterNumber22>22</ParameterNumber22>
    <ParameterNumber23>23</ParameterNumber23>
    <ParameterNumber24>24</ParameterNumber24>
    <ParameterNumber25>25</ParameterNumber25>
    <ParameterNumber26>26</ParameterNumber26>
    <ParameterNumber27>27</ParameterNumber27>
    <ParameterNumber28>28</ParameterNumber28>
    <ParameterNumber29>29</ParameterNumber29>
    <ParameterNumber30>30</ParameterNumber30>
    <ParameterNumber31>31</ParameterNumber31>
    <ParameterNumber32>32</ParameterNumber32>
    <ParameterNumber33>33</ParameterNumber33>
    <ParameterNumber34>34</ParameterNumber34>
    <VisiblePages>8</VisiblePages>
  </DeviceSlot>
</FilterDevicePreset>
]]

-- Function to load the preset XML directly into the Instr. Automation device
function openVisiblePagesToFitParameters()
  local song = renoise.song()

  -- Load the Instr. Automation device into the selected track using insert_device_at
  local track = song.selected_track
  track:insert_device_at("Audio/Effects/Native/*Instr. Automation", 2)

  -- Set the active_preset_data to the provided XML content
  renoise.song().selected_track.devices[2].active_preset_data = InstrautomationXML

  -- Debug logging: Confirm the preset has been loaded
  renoise.app():show_status("Preset loaded into Instr. Automation device.")
end

-- Register the function to a menu entry
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Open Visible Pages to Fit Plugin Parameter Count",invoke=openVisiblePagesToFitParameters}
renoise.tool():add_menu_entry{name="DSP Device:Paketti..:Open Visible Pages to Fit Plugin Parameter Count",invoke=openVisiblePagesToFitParameters}

-- Register a keybinding for easier access (optional)
renoise.tool():add_keybinding{name="Global:Paketti:Open Visible Pages to Fit Parameters",invoke=openVisiblePagesToFitParameters}

--------------
-- Mix-Paste Tool for Renoise
-- This tool will mix clipboard data with the pattern data in Renoise

local temp_text_path = renoise.tool().bundle_path .. "temp_mixpaste.txt"
local mix_paste_mode = false

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker MixPaste",invoke=function()
  mix_paste()
end}

function mix_paste()
  if not mix_paste_mode then
    -- First invocation: save selection to text file and perform initial paste
    save_selection_to_text()
    local clipboard_data = load_pattern_data_from_text()
    if clipboard_data then
      print("Debug: Clipboard data loaded for initial paste:\n" .. clipboard_data)
      perform_initial_paste(clipboard_data)
      renoise.app():show_status("Initial mix-paste performed. Run Mix-Paste again to perform the final mix.")
    else
      renoise.app():show_error("Failed to load clipboard data from text file.")
    end
    mix_paste_mode = true
  else
    -- Second invocation: load from text file and perform final mix-paste
    local clipboard_data = load_pattern_data_from_text()
    if clipboard_data then
      print("Debug: Clipboard data loaded for final paste:\n" .. clipboard_data)
      perform_final_mix_paste(clipboard_data)
      mix_paste_mode = false
      -- Clear the temp text file
      local file = io.open(temp_text_path, "w")
      file:write("")
      file:close()
    else
      renoise.app():show_error("Failed to load clipboard data from text file.")
    end
  end
end

function save_selection_to_text()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_error("Please make a selection in the pattern first.")
    return
  end

  -- Capture pattern data using rprint and save to text file
  local pattern_data = {}
  local pattern = song:pattern(song.selected_pattern_index)
  local track_index = song.selected_track_index

  for line_index = selection.start_line, selection.end_line do
    local line_data = {}
    local line = pattern:track(track_index):line(line_index)
    for col_index = 1, #line.note_columns do
      local note_column = line:note_column(col_index)
      table.insert(line_data, string.format("%s %02X %02X %02X %02X", 
        note_column.note_string, note_column.instrument_value, 
        note_column.volume_value, note_column.effect_number_value, 
        note_column.effect_amount_value))
    end
    for col_index = 1, #line.effect_columns do
      local effect_column = line:effect_column(col_index)
      table.insert(line_data, string.format("%02X %02X", 
        effect_column.number_value, effect_column.amount_value))
    end
    table.insert(pattern_data, table.concat(line_data, " "))
  end

  -- Save pattern data to text file
  local file = io.open(temp_text_path, "w")
  file:write(table.concat(pattern_data, "\n"))
  file:close()

  print("Debug: Saved pattern data to text file:\n" .. table.concat(pattern_data, "\n"))
end

function load_pattern_data_from_text()
  local file = io.open(temp_text_path, "r")
  if not file then
    return nil
  end
  local clipboard = file:read("*a")
  file:close()
  return clipboard
end

function perform_initial_paste(clipboard_data)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(track_index)

  local clipboard_lines = parse_clipboard_data(clipboard_data)

  for i, clipboard_line in ipairs(clipboard_lines) do
    local line = track:line(line_index + i - 1)
    for col_index, clipboard_note_col in ipairs(clipboard_line.note_columns) do
      if col_index <= #line.note_columns then
        local note_col = line:note_column(col_index)
        if note_col.is_empty then
          note_col.note_string = clipboard_note_col.note_string
          note_col.instrument_value = clipboard_note_col.instrument_value
          note_col.volume_value = clipboard_note_col.volume_value
          note_col.effect_number_value = clipboard_note_col.effect_number_value
          note_col.effect_amount_value = clipboard_note_col.effect_amount_value
        end
      end
    end
    for col_index, clipboard_effect_col in ipairs(clipboard_line.effect_columns) do
      if col_index <= #line.effect_columns then
        local effect_col = line:effect_column(col_index)
        if effect_col.is_empty then
          effect_col.number_value = clipboard_effect_col.number_value
          effect_col.amount_value = clipboard_effect_col.amount_value
        end
      end
    end
  end
end

function perform_final_mix_paste(clipboard_data)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(track_index)

  local clipboard_lines = parse_clipboard_data(clipboard_data)

  for i, clipboard_line in ipairs(clipboard_lines) do
    local line = track:line(line_index + i - 1)
    for col_index, clipboard_note_col in ipairs(clipboard_line.note_columns) do
      if col_index <= #line.note_columns then
        local note_col = line:note_column(col_index)
        if not note_col.is_empty then
          if clipboard_note_col.effect_number_value > 0 then
            note_col.effect_number_value = clipboard_note_col.effect_number_value
            note_col.effect_amount_value = clipboard_note_col.effect_amount_value
          end
        end
      end
    end
    for col_index, clipboard_effect_col in ipairs(clipboard_line.effect_columns) do
      if col_index <= #line.effect_columns then
        local effect_col = line:effect_column(col_index)
        if not effect_col.is_empty then
          if clipboard_effect_col.number_value > 0 then
            effect_col.number_value = clipboard_effect_col.number_value
            effect_col.amount_value = clipboard_effect_col.amount_value
          end
        end
      end
    end
  end
end

function parse_clipboard_data(clipboard)
  local lines = {}
  for line in clipboard:gmatch("[^\r\n]+") do
    table.insert(lines, parse_line(line))
  end
  return lines
end

function parse_line(line)
  local note_columns = {}
  local effect_columns = {}
  for note_col_data in line:gmatch("(%S+ %S+ %S+ %S+ %S+)") do
    table.insert(note_columns, parse_note_column(note_col_data))
  end
  for effect_col_data in line:gmatch("(%S+ %S+)") do
    table.insert(effect_columns, parse_effect_column(effect_col_data))
  end
  return {note_columns=note_columns,effect_columns=effect_columns}
end

function parse_note_column(data)
  local note, instrument, volume, effect_number, effect_amount = data:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
  return {
    note_string=note,
    instrument_value=tonumber(instrument, 16),
    volume_value=tonumber(volume, 16),
    effect_number_value=tonumber(effect_number, 16),
    effect_amount_value=tonumber(effect_amount, 16),
  }
end

function parse_effect_column(data)
  local number, amount = data:match("(%S+) (%S+)")
  return {
    number_value=tonumber(number, 16),
    amount_value=tonumber(amount, 16),
  }
end










--Wipes the pattern data, but not the samples or instruments.
--WARNING: Does not reset current filename.
-- TODO
--[[
function wipeSongPattern()
local s=renoise.song()
  for i=1,300 do
    if s.patterns[i].is_empty==false then
    s.patterns[i]:clear()
    renoise.song().patterns[i].number_of_lines=64
    else 
    print ("Encountered empty pattern, not deleting")
    renoise.song().patterns[i].number_of_lines=64
    end
  end
end
renoise.tool():add_keybinding{name="Global:Paketti:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
----
--]]
function get_master_track_index()
  for k,v in ripairs(renoise.song().tracks)
    do if v.type == renoise.Track.TRACK_TYPE_MASTER then return k end  
  end
end

function AutoGapper()
renoise.song().tracks[get_master_track_index()].visible_effect_columns = 4  
local gapper=nil
renoise.app().window.active_lower_frame=1
renoise.app().window.lower_frame_is_visible=true
  loadnative("Audio/Effects/Native/Filter")
  loadnative("Audio/Effects/Native/*LFO")
  renoise.song().selected_track.devices[2].parameters[2].value=2
  renoise.song().selected_track.devices[2].parameters[3].value=1
  renoise.song().selected_track.devices[2].parameters[7].value=2
--  renoise.song().selected_track.devices[3].parameters[5].value=0.0074
local gapper=renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines*2*4
  renoise.song().selected_track.devices[2].parameters[6].value_string=tostring(gapper)
renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[4].number_string = "18"
end

renoise.tool():add_keybinding{name="Global:Paketti:Add Filter & LFO (AutoGapper)",invoke=function() AutoGapper() end}


------------
function start_stop_sample_and_loop_oh_my()
local w=renoise.app().window
local s=renoise.song()
local t=s.transport
local ss=s.selected_sample
local currTrak=s.selected_track_index
local currPatt=s.selected_pattern_index

if w.sample_record_dialog_is_visible then
    -- we are recording, stop
    t:start_stop_sample_recording()
    -- write note
     ss.autoseek=true
     s.patterns[currPatt].tracks[currTrak].lines[1].effect_columns[1].number_string="0G"
     s.patterns[currPatt].tracks[currTrak].lines[1].effect_columns[1].amount_string="01"

for i= 1,12 do
if s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].is_empty==true then
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].note_string="C-4"
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].instrument_value=s.selected_instrument_index-1
else
 if i == renoise.song().tracks[currTrak].visible_note_columns and i == 12
  then renoise.song():insert_track_at(renoise.song().selected_track_index)
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[1].note_string="C-4"
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[1].instrument_value=s.selected_instrument_index-1
end
end
end
-- hide dialog
    w.sample_record_dialog_is_visible = false
  else
    -- not recording. show dialog, start recording.
    w.sample_record_dialog_is_visible = true
    t:start_stop_sample_recording()
  end
end

----------------------------
-- has-line-input + add-line-input
function has_line_input()
-- Write some code to find the line input in the correct place
local tr = renoise.song().selected_track
 if tr.devices[2] and tr.devices[2].device_path=="Audio/Effects/Native/#Line Input" 
  then return true
 else
  return false
 end
end

function add_line_input()
-- Write some code to add the line input in the correct place
 loadnative("Audio/Effects/Native/#Line Input")
end

function remove_line_input()
-- Write some code to remove the line input if it's in the correct place
 renoise.song().selected_track:delete_device_at(2)
end

-- recordamajic
function recordamajic9000(running)
    if running then
    renoise.song().transport.playing=true
        -- start recording code here
renoise.app().window.sample_record_dialog_is_visible=true
renoise.app().window.lock_keyboard_focus=true
renoise.song().transport:start_stop_sample_recording()
    else
    -- Stop recording here
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Recordammajic9000",
invoke=function() if has_line_input() then 
      recordtocurrenttrack()    
      G01()
 else add_line_input()
      recordtocurrenttrack()
      G01()
 end end}

-- turn samplerecorder ON
function SampleRecorderOn()
local howmany = table.count(renoise.song().selected_track.devices)

if renoise.app().window.sample_record_dialog_is_visible==false then
renoise.app().window.sample_record_dialog_is_visible=true 

  if howmany == 1 then 
    loadnative("Audio/Effects/Native/#Line Input")
    return
  else
    if renoise.song().selected_track.devices[2].name=="#Line Input" then
    renoise.song().selected_track:delete_device_at(2)
    renoise.app().window.sample_record_dialog_is_visible=false
    else
    loadnative("Audio/Effects/Native/#Line Input")
    return
end    
  end  

else renoise.app().window.sample_record_dialog_is_visible=false
  if renoise.song().selected_track.devices[2].name=="#Line Input" then
  renoise.song().selected_track:delete_device_at(2)
  end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Display Sample Recorder with #Line Input",invoke=function() SampleRecorderOn() end}

function glideamount(amount)
local counter=nil 
for i=renoise.song().selection_in_pattern.start_line,renoise.song().selection_in_pattern.end_line 
do renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].number_string="0G" 
counter=renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].amount_value+amount 

if counter > 255 then counter=255 end
if counter < 1 then counter=0 
end
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].amount_value=counter 
end
end

local s = nil

function startup_()
  local s=renoise.song()
--   renoise.app().window:select_preset(1)
   
   renoise.song().instruments[s.selected_instrument_index].active_tab=1
    if renoise.app().window.active_middle_frame==0 and s.selected_sample.sample_buffer_observable:has_notifier(sample_loaded_change_to_sample_editor) then 
    s.selected_sample.sample_buffer_observable:remove_notifier(sample_loaded_change_to_sample_editor)
    else
  --s.selected_sample.sample_buffer_observable:add_notifier(sample_loaded_change_to_sample_editor)

    return
    end
end

  function sample_loaded_change_to_sample_editor()
--    renoise.app().window.active_middle_frame=4
  end

if not renoise.tool().app_new_document_observable:has_notifier(startup_) 
   then renoise.tool().app_new_document_observable:add_notifier(startup_)
   else renoise.tool().app_new_document_observable:remove_notifier(startup_)
end
--------------------------------------------------------------------------------
function PakettiCapsLockNoteOffNextPtn()   
local s=renoise.song()
local wrapping=s.transport.wrapped_pattern_edit
local editstep=s.transport.edit_step

local currLine=s.selected_line_index
local currPatt=s.selected_pattern_index

local counter=nil
local addlineandstep=nil
local counting=nil
local seqcount=nil
local resultPatt=nil

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=="0O" and 
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=="FF"
then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=""
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=""
return
else
end

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=="0O" and s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=="CF"
then s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="00"  
     s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="00"
return
end

if renoise.song().transport.edit_mode==true then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="0O"  
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="CF"
return
end

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=="0O" and 
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=="CF"

then s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="00" 
     s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="00"
return
end

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string~=nil then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="0O"
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="FF"
return
else 
if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=="OFF" then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=""
return
else
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string="OFF"
end

--s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string="OFF"
end

addlineandstep=currLine+editstep
seqcount = currPatt+1

if addlineandstep > s.patterns[currPatt].number_of_lines then
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
counting=addlineandstep-s.patterns[currPatt].number_of_lines
 if seqcount > (table.count(renoise.song().sequencer.pattern_sequence)) then 
 seqcount = (table.count(renoise.song().sequencer.pattern_sequence))
 s.selected_sequence_index=seqcount
 end
 
resultPatt=currPatt+1 
 if resultPatt > #renoise.song().sequencer.pattern_sequence then 
 resultPatt = (table.count(renoise.song().sequencer.pattern_sequence))
s.selected_sequence_index=resultPatt
s.selected_line_index=counting
end
else 
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
--s.selected_sequence_index=currPatt+1
s.selected_line_index=addlineandstep

counter = addlineandstep-1

renoise.app():show_status("Now on: " .. counter .. "/" .. s.patterns[currPatt].number_of_lines .. " In Pattern: " .. currPatt)
end
end
----
function PakettiCapsLockNoteOff()   
local s=renoise.song()
local st=s.transport
local wrapping=st.wrapped_pattern_edit
local editstep=st.edit_step

local currLine=s.selected_line_index
local currPatt=s.selected_sequence_index

local counter=nil
local addlineandstep=nil
local counting=nil
local seqcount=nil

if renoise.song().patterns[renoise.song().selected_sequence_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index].note_string=="OFF" then 

s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=""
return
else end

if not s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=="OFF"
then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string="OFF"
else s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=""
end

addlineandstep=currLine+editstep
seqcount = currPatt+1

if addlineandstep > s.patterns[currPatt].number_of_lines then
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
counting=addlineandstep-s.patterns[currPatt].number_of_lines
 if seqcount > (table.count(renoise.song().sequencer.pattern_sequence)) then 
 seqcount = (table.count(renoise.song().sequencer.pattern_sequence))
 s.selected_sequence_index=seqcount
 end
--s.selected_sequence_index=currPatt+1
s.selected_line_index=counting
else 
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
--s.selected_sequence_index=currPatt+1
s.selected_line_index=addlineandstep

counter = addlineandstep-1

renoise.app():show_status("Now on: " .. counter .. "/" .. s.patterns[currPatt].number_of_lines .. " In Pattern: " .. currPatt)
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Note Off / Caps Lock replacement",invoke=function() 
if renoise.song().transport.wrapped_pattern_edit == false then PakettiCapsLockNoteOffNextPtn() 
else PakettiCapsLockNoteOff() end
end}
----------------------------------------
function move_up(chg)
local sindex=renoise.song().selected_line_index
local s= renoise.song()
local note=s.selected_note_column
--This switches currently selected row but doesn't 
--move the note
--s.selected_line_index = (sindex+chg)
-- moving note up, applying correct delay value and moving cursor up goes here
end
--movedown
function move_down(chg)
local sindex=renoise.song().selected_line_index
local s= renoise.song()
--This switches currently selected row but doesn't 
--move the note
--s.selected_line_index = (sindex+chg)
-- moving note down, applying correct delay value and moving cursor down goes here
end


-- Function to adjust the delay value of the selected note column within the current phrase
function delay(seconds)
    local command = "sleep " .. tonumber(seconds)
    os.execute(command)
end

----------

---------------------------
function GenerateDelayValue(scope)
  local s = renoise.song()
  local track = s.tracks[s.selected_track_index]
  track.delay_column_visible = true
  
  local num_columns = track.visible_note_columns
  local base_delay = 256 / num_columns
  
  -- Get target lines based on scope
  local lines = {}
  if scope == "row" then
      table.insert(lines, s.selected_line_index)
  elseif scope == "pattern" then
      for i = 1, s.selected_pattern.number_of_lines do
          table.insert(lines, i)
      end
  elseif scope == "selection" then
      local selection = s.selection_in_pattern
      if not selection then
          renoise.app():show_status("No selection found!")
          return
      end
      for i = selection.start_line, selection.end_line do
          table.insert(lines, i)
      end
  end
  
  -- Apply to all target lines
  for _, line_index in ipairs(lines) do
      for i = 1, num_columns do
          local delay_value = math.floor(base_delay * (i - 1))
          s.patterns[s.selected_pattern_index].tracks[s.selected_track_index]
              .lines[line_index].note_columns[i].delay_value = delay_value
      end
  end
  
  s.selected_note_column_index = 1
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Note Columns",invoke=function() GenerateDelayValue("row") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Generate Delay Value on Note Columns",invoke=function() GenerateDelayValue("row") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Entire Pattern",invoke=function() GenerateDelayValue("pattern") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Generate Delay Value on Entire Pattern",invoke=function() GenerateDelayValue("pattern") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Selection",invoke=function() GenerateDelayValue("selection") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Generate Delay Value on Selection",invoke=function() GenerateDelayValue("selection") end}
-------

-- Function to get selected columns in the current selection
local function get_selected_columns(track, start_line, end_line)
  local selected_note_columns = {}
  local selected_effect_columns = {}

  for column_index = 1, #track:line(start_line).note_columns do
    for line = start_line, end_line do
      if track:line(line).note_columns[column_index].is_selected then
        table.insert(selected_note_columns, column_index)
        break
      end
    end
  end

  return selected_note_columns, selected_effect_columns
end

function GenerateDelayValueNotes(scope)
  local s = renoise.song()
  local track = s.tracks[s.selected_track_index]
  track.delay_column_visible = true
  
  local lines = {}
  if scope == "row" then
      table.insert(lines, s.selected_line_index)
  elseif scope == "pattern" then
      for i = 1, s.selected_pattern.number_of_lines do
          table.insert(lines, i)
      end
  elseif scope == "selection" then
      local selection = s.selection_in_pattern
      if not selection then
          renoise.app():show_status("No selection found!")
          return
      end
      for i = selection.start_line, selection.end_line do
          table.insert(lines, i)
      end
  end
  
  for _, line_index in ipairs(lines) do
      local line = s.patterns[s.selected_pattern_index].tracks[s.selected_track_index]:line(line_index)
      
      local actual_notes = 0
      for i = 1, track.visible_note_columns do
          local note_column = line.note_columns[i]
          if note_column and note_column.note_string ~= "" and 
             note_column.note_string ~= "OFF" and note_column.note_value < 120 then
              actual_notes = actual_notes + 1
          end
      end
      
      if actual_notes > 1 then
          local current_note = 0
          for i = 1, track.visible_note_columns do
              local note_column = line.note_columns[i]
              if note_column and note_column.note_string ~= "" and 
                 note_column.note_string ~= "OFF" and note_column.note_value < 120 then
                  local delay = math.floor(256 * current_note / actual_notes)
                  note_column.delay_value = delay
                  current_note = current_note + 1
              end
          end
      end
  end
end


-- Add new keybindings for note-specific version
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Row)",invoke=function() GenerateDelayValueNotes("row") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Generate Delay Value (Notes Only, Row)",invoke=function() GenerateDelayValueNotes("row") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Pattern)",invoke=function() GenerateDelayValueNotes("pattern") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Generate Delay Value (Notes Only, Pattern)",invoke=function() GenerateDelayValueNotes("pattern") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Selection)",invoke=function() GenerateDelayValueNotes("selection") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Generate Delay Value (Notes Only, Selection)",invoke=function() GenerateDelayValueNotes("selection") end}

-------
function pattern_line_notifier(pos)
  local s = renoise.song()
  local t = s.transport
  local pattern = s.patterns[s.selected_pattern_index]
  
  if t.edit_step == 0 then
    local new_col = s.selected_note_column_index + 1
    local max_cols = s.tracks[s.selected_track_index].visible_note_columns
    
    if new_col > max_cols then
      -- When reaching last column, move to next line or wrap
      local new_line = s.selected_line_index + 1
      
      if new_line > pattern.number_of_lines then
        new_line = 1  -- Wrap to first line if at end of pattern
      end
      
      s.selected_line_index = new_line
      s.selected_note_column_index = 1
    else
      s.selected_note_column_index = new_col
    end
    return
  end

  -- Existing code for edit_step > 0 cases
  local countline = s.selected_line_index + 1
  if t.edit_step > 1 then
    countline = countline - 1
  end
  
  if countline > pattern.number_of_lines then
    countline = 1
  end
  
  s.selected_line_index = countline
  local colnumber = s.selected_note_column_index + 1
  
  if colnumber > s.tracks[s.selected_track_index].visible_note_columns then
    s.selected_note_column_index = 1
    return
  end
  
  s.selected_note_column_index = colnumber
end

  function startcolumncycling(number)
    local s = renoise.song()
    local pattern = s.patterns[s.selected_pattern_index]
    local was_active = pattern:has_line_notifier(pattern_line_notifier)
  
    -- Always remove existing notifier first when changing columns
    if number and was_active then
      pattern:remove_line_notifier(pattern_line_notifier)
    end
  
    -- Column-specific activation
    if number then
      if not was_active or s.selected_note_column_index ~= number then
        pattern:add_line_notifier(pattern_line_notifier)
        renoise.app():show_status(number .. " Column Cycle Keyjazz On")
      else
        renoise.app():show_status(number .. " Column Cycle Keyjazz Off")
      end
    -- General toggle
    else
      if was_active then
        pattern:remove_line_notifier(pattern_line_notifier)
        renoise.app():show_status("Column Cycling Off")
      else
        pattern:add_line_notifier(pattern_line_notifier)
        renoise.app():show_status(s.selected_note_column_index .. " Column Cycle Keyjazz On")
      end
    end
  end
  
for cck=1,12 do 
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz " .. formatDigits(2,cck),invoke=function() displayNoteColumn(cck) startcolumncycling(cck) end} 
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Column Cycle Keyjazz..:Column Cycle Keyjazz " .. formatDigits(2,cck),invoke=function() displayNoteColumn(cck) startcolumncycling(cck) end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Start/Stop Column Cycling",invoke=function() startcolumncycling() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Start/Stop Column Cycling",invoke=function() startcolumncycling() end}

function ColumnCycleKeyjazzSpecial(number)
displayNoteColumn(number) 
GenerateDelayValue("pattern")
renoise.song().transport.edit_mode=true
renoise.song().transport.edit_step=0
renoise.song().selected_note_column_index=1
startcolumncycling(number)
end

for ccks=2,12 do
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz Special (" .. ccks .. ")",invoke=function() ColumnCycleKeyjazzSpecial(ccks) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Column Cycle Keyjazz..:Column Cycle Keyjazz Special (" .. ccks .. ")",invoke=function() ColumnCycleKeyjazzSpecial(ccks) end}
end
----------------------------

