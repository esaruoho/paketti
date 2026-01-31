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
if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index+1) then return end
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
    if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index+1) then return end
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

function pakettiDeviceChainDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
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
      width=900,  -- Increased width as per requirement
      notifier=function(text)
        get_slot_preference_xrnt(i).value = text
      end
    }
    slot_path_views_xrnt[i] = textfield_xrnt

    -- XRNT Row
    local row_xrnt = vb:row{
     -- margin=2,
      vb:text{text=".XRNT Slot" .. slot_number,width=100 },
      textfield_xrnt,
      vb:button{text="Browse",notifier=function() select_xrnt_file(i) end},
      vb:button{text="Save",notifier=function() save_device_chain_to_slot(i) end},
      vb:button{text="Load",notifier=function() load_device_chain_from_slot(i) end}
    }
    slots_rows_xrnt[#slots_rows_xrnt + 1] = row_xrnt

    -- Create XRNI textfield and store it
    local textfield_xrni = vb:textfield {
      text = get_slot_preference_xrni(i).value or "",
      width=900,  -- Increased width as per requirement
      notifier=function(text)
        get_slot_preference_xrni(i).value = text
      end
    }
    slot_path_views_xrni[i] = textfield_xrni

    -- XRNI Row
    local row_xrni = vb:row{
    --  margin=2,
      vb:text{text=".XRNI Slot" .. slot_number,width=100 },
      textfield_xrni,
      vb:button{
        text="Browse",
        notifier=function()
          select_xrni_file(i)
        end
      },
      vb:button{text="Save",notifier=function() save_instrument_to_slot(i) end},
      vb:button{text="Load",notifier=function() load_instrument_from_slot(i) end}
    }
    slots_rows_xrni[#slots_rows_xrni + 1] = row_xrni

    -- Both XRNI&XRNT Row
    local row_both = vb:row{
      vb:text{text="Load Both Slots" .. slot_number,width=100 },
      vb:button{
        text="Load Both",
        notifier=function()
          load_both_from_slot(i)
        end
      }
    }
    slots_rows_both[#slots_rows_both + 1] = row_both
  end

  -- Define the content of the dialog
  local content = vb:column{
    vb:row{
      vb:text{text="User Save Folder",width=100},
      vb:textfield {
        id = "folder_path_textfield",
        text = preferences.UserDevices.Path.value ~= "" and preferences.UserDevices.Path.value or "<Not Set, Please Set>",
        width=900,  -- Increased width as per requirement
        notifier=function(text)
          preferences.UserDevices.Path.value = text
        end
      },
      vb:button{
        text="Browse",
        notifier=function()
          select_user_xrnt_saving_folder()
        end
      }
    },
    vb:column{vb:text{text="Load Device Chain (.XRNT) Slots (01-10)",font="bold",style="strong"},unpack(slots_rows_xrnt)},
    vb:column{vb:text{text="Load Instrument (.XRNI) Slots (01-10)",font="bold",style="strong"},unpack(slots_rows_xrni)},
    vb:column{vb:text{text="Load Both Instrument&Device Chain (.XRNI&.XRNT) Slots (01-10)",font="bold",style="strong"},unpack(slots_rows_both)},
    vb:row{
      vb:button{
        text="Close",
        notifier=function()
          dialog:close()
          dialog = nil  -- Clear the dialog reference
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Device Chain & Instrument Dialog", content, keyhandler)
  
  -- Assign the folder path textfield reference after dialog creation
  folder_path_view = vb.views["folder_path_textfield"]
end

-- Function to add menu entries and key bindings grouped by functionality
local function add_menu_entries_and_keybindings()
  -- Load Device Chain (.XRNT) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_xrnt = "Mixer:Paketti:Device Chains:Load Device Chain (.XRNT) Slot" .. slot_number
    local menu_entry_name2_xrnt = "DSP Device:Paketti:Device Chains:Load Device Chain (.XRNT) Slot" .. slot_number
    local key_binding_name_xrnt = "Global:Paketti:Load Device Chain (.XRNT) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_xrnt,invoke=function() load_device_chain_from_slot(i) end}
    renoise.tool():add_menu_entry{name=menu_entry_name2_xrnt,invoke=function() load_device_chain_from_slot(i) end}
    renoise.tool():add_keybinding{name=key_binding_name_xrnt,invoke=function() load_device_chain_from_slot(i) end}
  end

  -- Load Instrument (.XRNI) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_xrni = "Mixer:Paketti:Device Chains:Load Instrument (.XRNI) Slot" .. slot_number
    local menu_entry_name2_xrni = "DSP Device:Paketti:Device Chains:Load Instrument (.XRNI) Slot" .. slot_number
    local key_binding_name_xrni = "Global:Paketti:Load Instrument (.XRNI) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_xrni,invoke=function() load_instrument_from_slot(i) end}
    renoise.tool():add_menu_entry{name=menu_entry_name2_xrni,invoke=function() load_instrument_from_slot(i) end}
    renoise.tool():add_keybinding{name=key_binding_name_xrni,invoke=function() load_instrument_from_slot(i) end}
  end

  -- Load Both Instrument&Device Chain (.XRNI&.XRNT) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_load_both = "Mixer:Paketti:Device Chains:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number
    local menu_entry_name2_load_both = "DSP Device:Paketti:Device Chains:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number
    local key_binding_name_load_both = "Global:Paketti:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_load_both,invoke=function() load_both_from_slot(i) end}
    renoise.tool():add_menu_entry{name=menu_entry_name2_load_both,invoke=function() load_both_from_slot(i) end}
    renoise.tool():add_keybinding{name=key_binding_name_load_both,invoke=function() load_both_from_slot(i) end}
  end
end

add_menu_entries_and_keybindings()

