function inspectEffect()
  local devices = renoise.song().selected_track.devices
  local selected_device = renoise.song().selected_device

  -- Check if there is a selected effect
  if not selected_device then
    renoise.app():show_status("No effect has been selected, doing nothing.")
    return
  end


  oprint (renoise.song().selected_device.active_preset_data)
  -- Print details of the selected effect
  oprint("Effect Displayname: " .. selected_device.display_name)
  oprint("Effect Name: " .. selected_device.name)
  oprint("Effect Path: " .. selected_device.device_path)

  -- Iterate over the effect parameters and print their details
  for i = 1, #selected_device.parameters do
    oprint(
      selected_device.name .. ": " .. i .. ": " .. selected_device.parameters[i].name .. ": " ..
      "renoise.song().selected_device.parameters[" .. i .. "].value=" .. selected_device.parameters[i].value
    )
  end
  
  -- Output parameters that are exposed in Mixer
  oprint("")
  oprint("-- Exposed Parameters:")
  local mixer_params = {}
  for i = 1, #selected_device.parameters do
    if selected_device.parameters[i].show_in_mixer then
      table.insert(mixer_params, {index = i, name = selected_device.parameters[i].name})
      oprint("--   " .. selected_device.name .. " " .. i .. " " .. selected_device.parameters[i].name)
    end
  end
  
  if #mixer_params == 0 then
    oprint("--   No parameters are currently exposed in Mixer")
  else
    oprint("")
    oprint("Copy-Pasteable Commands:")
    for _, param in ipairs(mixer_params) do
      oprint("renoise.song().selected_device.parameters[" .. param.index .. "].show_in_mixer=true")
    end
  end
  
  -- Device State Information and Workflow (always show regardless of mixer params)
  oprint("")
  oprint("Device State Information:")
  oprint("Device display name: " .. selected_device.display_name)
  oprint("Device is active: " .. tostring(selected_device.is_active))
  oprint("Device is maximized: " .. tostring(selected_device.is_maximized))
  oprint("External editor available: " .. tostring(selected_device.external_editor_available))
  if selected_device.external_editor_available then
    oprint("External editor visible: " .. tostring(selected_device.external_editor_visible))
  end
  
  oprint("")
  oprint("Complete Device Recreation Workflow:")
  oprint('-- 1. Load Device (with Line Input protection)')
  if selected_device.device_path:find("Native/") then
    oprint('loadnative("' .. selected_device.device_path .. '")')
  else
    oprint('loadvst("' .. selected_device.device_path .. '")')
  end
  
  -- Generate XML with current device state
  local xml_data = selected_device.active_preset_data
  if xml_data and xml_data ~= "" then
    oprint('-- 2. Inject Current Device State XML')
    oprint('local device_xml = [=[' .. xml_data .. ']=]')
    oprint('renoise.song().selected_device.active_preset_data = device_xml')
  else
    oprint('-- 2. No preset data available for XML injection')
  end
  
  oprint('-- 3. Set Mixer Parameter Visibility')
  for _, param in ipairs(mixer_params) do
    oprint('renoise.song().selected_device.parameters[' .. param.index .. '].show_in_mixer = true')
  end
  
  oprint('-- 4. Set Device Maximized State')
  oprint('renoise.song().selected_device.is_maximized = ' .. tostring(selected_device.is_maximized))
  
  oprint('-- 5. Set External Editor State')
  if selected_device.external_editor_available then
    oprint('renoise.song().selected_device.external_editor_visible = ' .. tostring(selected_device.external_editor_visible))
  else
    oprint('-- External editor not available for this device')
  end
  
  oprint('-- 6. Set Device Display Name')
  oprint('renoise.song().selected_device.display_name = "' .. selected_device.display_name .. '"')
  
  oprint('-- 7. Set Device Enabled/Disabled State')
  if selected_device.is_active then
    oprint('-- renoise.song().selected_device.is_active = true (default)')
  else
    oprint('renoise.song().selected_device.is_active = false')
  end
  
  oprint("")
  oprint("-- Total parameters exposed in Mixer: " .. #mixer_params)
end

renoise.tool():add_keybinding{name="Global:Paketti:Inspect Selected Device",invoke=function() inspectEffect() end}

function inspectSampleDevice()
  local selected_device = renoise.song().selected_sample_device

  -- Check if there is a selected sample device
  if not selected_device then
    renoise.app():show_status("No sample device has been selected, doing nothing.")
    return
  end

  oprint (renoise.song().selected_sample_device.active_preset_data)
  -- Print details of the selected sample device
  oprint("Sample Device Displayname: " .. selected_device.display_name)
  oprint("Sample Device Name: " .. selected_device.name)
  oprint("Sample Device Path: " .. selected_device.device_path)

  -- Iterate over the device parameters and print their details
  for i = 1, #selected_device.parameters do
    oprint(
      selected_device.name .. ": " .. i .. ": " .. selected_device.parameters[i].name .. ": " ..
      "renoise.song().selected_sample_device.parameters[" .. i .. "].value=" .. selected_device.parameters[i].value
    )
  end
  
  -- Output parameters that are exposed in Mixer
  oprint("")
  oprint("-- Exposed Parameters:")
  local mixer_params = {}
  for i = 1, #selected_device.parameters do
    if selected_device.parameters[i].show_in_mixer then
      table.insert(mixer_params, {index = i, name = selected_device.parameters[i].name})
      oprint("--   " .. selected_device.name .. " " .. i .. " " .. selected_device.parameters[i].name)
    end
  end
  
  if #mixer_params == 0 then
    oprint("--   No parameters are currently exposed in Mixer")
  else
    oprint("")
    oprint("Copy-Pasteable Commands:")
    for _, param in ipairs(mixer_params) do
      oprint("renoise.song().selected_sample_device.parameters[" .. param.index .. "].show_in_mixer=true")
    end
  end
  
  -- Device State Information and Workflow (always show regardless of mixer params)
  oprint("")
  oprint("Sample Device State Information:")
  oprint("Device display name: " .. selected_device.display_name)
  oprint("Device is active: " .. tostring(selected_device.is_active))
  oprint("Device is maximized: " .. tostring(selected_device.is_maximized))
  oprint("External editor available: " .. tostring(selected_device.external_editor_available))
  if selected_device.external_editor_available then
    oprint("External editor visible: " .. tostring(selected_device.external_editor_visible))
  end
  
  oprint("")
  oprint("Complete Sample Device Recreation Workflow:")
  oprint('-- 1. Load Sample Device')
  if selected_device.device_path:find("Native/") then
    oprint('-- Insert native sample device: "' .. selected_device.device_path .. '"')
    oprint('renoise.song().selected_sample_device_chain:insert_device_at("' .. selected_device.device_path .. '", device_position)')
  else
    oprint('-- Insert VST sample device: "' .. selected_device.device_path .. '"')
    oprint('renoise.song().selected_sample_device_chain:insert_device_at("' .. selected_device.device_path .. '", device_position)')
  end
  
  -- Generate XML with current device state
  local xml_data = selected_device.active_preset_data
  if xml_data and xml_data ~= "" then
    oprint('-- 2. Inject Current Sample Device State XML')
    oprint('local device_xml = [=[' .. xml_data .. ']=]')
    oprint('renoise.song().selected_sample_device.active_preset_data = device_xml')
  else
    oprint('-- 2. No preset data available for XML injection')
  end
  
  oprint('-- 3. Set Mixer Parameter Visibility')
  for _, param in ipairs(mixer_params) do
    oprint('renoise.song().selected_sample_device.parameters[' .. param.index .. '].show_in_mixer = true')
  end
  
  oprint('-- 4. Set Device Maximized State')
  oprint('renoise.song().selected_sample_device.is_maximized = ' .. tostring(selected_device.is_maximized))
  
  oprint('-- 5. Set External Editor State')
  if selected_device.external_editor_available then
    oprint('renoise.song().selected_sample_device.external_editor_visible = ' .. tostring(selected_device.external_editor_visible))
  else
    oprint('-- External editor not available for this device')
  end
  
  oprint('-- 6. Set Device Display Name')
  oprint('renoise.song().selected_sample_device.display_name = "' .. selected_device.display_name .. '"')
  
  oprint('-- 7. Set Device Enabled/Disabled State')
  if selected_device.is_active then
    oprint('-- renoise.song().selected_sample_device.is_active = true (default)')
  else
    oprint('renoise.song().selected_sample_device.is_active = false')
  end
  
  oprint("")
  oprint("-- Total parameters exposed in Mixer: " .. #mixer_params)
end

renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Inspect Selected Sample Device", invoke = inspectSampleDevice}

function inspectTrackDeviceChain(debug_mode)
  -- Set to true for debug output, false for clean script generation
  local generate_debug_prints = debug_mode ~= false  -- Default to true unless explicitly set to false
  
  local track = renoise.song().selected_track
  local devices = track.devices
  
  -- Check if there are any devices beyond Track Vol/Pan (index 1)
  if #devices <= 1 then
    renoise.app():show_status("Nothing to inspect, doing nothing.")
    return
  end
  
  -- Get actual devices (skip Track Vol/Pan at index 1)
  local actual_devices = {}
  local original_display_names = {}  -- Store original display names
  for i = 2, #devices do  -- Start from index 2 to skip Track Vol/Pan
    table.insert(actual_devices, devices[i])
    original_display_names[#actual_devices] = devices[i].display_name  -- Store original name
  end
  oprint ("--------------------------")
  oprint ("--------------------------")
  oprint ("--------------------------")
  oprint ("--------------------------")
  oprint ("--------------------------")
  oprint("-- === TRACK DEVICE CHAIN RECREATION ===")
  oprint("-- Track: " .. track.name)
  oprint("-- Total devices (excluding Track Vol/Pan): " .. #actual_devices)
  oprint("-- Debug prints: " .. tostring(generate_debug_prints))
  
  -- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER
  oprint("")
  oprint("-- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER")
  oprint("-- Loading LAST device first, then second-last, etc. to maintain correct order")
  oprint("")
  
  -- Load devices in REVERSE order (last first, first last) with placeholders
  for i = #actual_devices, 1, -1 do
    local device = actual_devices[i]
    oprint("-- Loading device " .. i .. ": " .. device.name .. " (" .. device.display_name .. ")")
    if device.device_path:find("Native/") then
      oprint('loadnative("' .. device.device_path .. '", nil, nil, false)')
    else
      oprint('loadvst("' .. device.device_path .. '", nil, nil, false)')  
    end
    -- Set placeholder on the currently selected device (just loaded)
    oprint('renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_' .. string.format("%03d", i) .. '"')
    if generate_debug_prints then
      oprint('print("DEBUG: Loaded device ' .. i .. ' (' .. device.name .. ') with placeholder PAKETTI_PLACEHOLDER_' .. string.format("%03d", i) .. '")')
    end
    oprint("")
  end
  
  -- PHASE 2: Apply XML to ALL devices (Last to First)
  oprint("-- PHASE 2: Apply XML to ALL devices (Last to First)")
  oprint("")
  
  for i = #actual_devices, 1, -1 do
    local device = actual_devices[i]
    local placeholder = "PAKETTI_PLACEHOLDER_" .. string.format("%03d", i)
    
    if device.active_preset_data and device.active_preset_data ~= "" then
      oprint("-- Apply XML for device " .. i .. ": " .. device.name)
      oprint("for i, device in ipairs(renoise.song().selected_track.devices) do")
      oprint('  if device.display_name == "' .. placeholder .. '" then')
      if generate_debug_prints then
        oprint('    print("DEBUG: Starting XML injection for device ' .. i .. ' (' .. device.name .. ')")')
      end
      oprint('    device.active_preset_data = [=[' .. device.active_preset_data .. ']=]')
      if generate_debug_prints then
        oprint('    print("DEBUG: XML injection completed for device ' .. i .. '")')
      end
      oprint('    break')
      oprint('  end')
      oprint('end')
      oprint("")
    else
      oprint("-- No XML data for device " .. i .. ": " .. device.name)
      oprint("")
    end
  end
  
  -- PHASE 3: Apply Parameters to ALL devices (Last to First)
  oprint("-- PHASE 3: Apply Parameters to ALL devices (Last to First)")
  oprint("")
  
  for i = #actual_devices, 1, -1 do
    local device = actual_devices[i]
    local placeholder = "PAKETTI_PLACEHOLDER_" .. string.format("%03d", i)
    
    -- Check if device has any parameter values to set
    local has_params = false
    for j, param in ipairs(device.parameters) do
      if param.value ~= param.value_default then
        has_params = true
        break
      end
    end
    
    if has_params then
      oprint("-- Apply parameters for device " .. i .. ": " .. device.name)
      oprint("for i, device in ipairs(renoise.song().selected_track.devices) do")
      oprint('  if device.display_name == "' .. placeholder .. '" then')
      for j, param in ipairs(device.parameters) do
        if param.value ~= param.value_default then
          oprint('    device.parameters[' .. j .. '].value = ' .. param.value)
        end
      end
             if generate_debug_prints then
         oprint('    print("DEBUG: Applied parameters for device ' .. i .. '")')
       end
       oprint('    break')
       oprint('  end')
       oprint('end')
      oprint("")
    else
      oprint("-- No parameters to set for device " .. i .. ": " .. device.name)
      oprint("")
    end
  end
  
  -- PHASE 4: Apply Mixer Visibility to ALL devices (Last to First)
  oprint("-- PHASE 4: Apply Mixer Visibility to ALL devices (Last to First)")
  oprint("")
  
  for i = #actual_devices, 1, -1 do
    local device = actual_devices[i]
    local placeholder = "PAKETTI_PLACEHOLDER_" .. string.format("%03d", i)
    
    local mixer_param_count = 0
    for j, param in ipairs(device.parameters) do
      if param.show_in_mixer then
        mixer_param_count = mixer_param_count + 1
      end
    end
    
    if mixer_param_count > 0 then
      oprint("-- Apply mixer visibility for device " .. i .. ": " .. device.name)
      oprint("for i, device in ipairs(renoise.song().selected_track.devices) do")
      oprint('  if device.display_name == "' .. placeholder .. '" then')
      for j, param in ipairs(device.parameters) do
        if param.show_in_mixer then
          oprint('    device.parameters[' .. j .. '].show_in_mixer = true')
        end
      end
             if generate_debug_prints then
         oprint('    print("DEBUG: Set ' .. mixer_param_count .. ' mixer parameters visible for device ' .. i .. '")')
       end
       oprint('    break')
       oprint('  end')
       oprint('end')
      oprint("")
    else
      oprint("-- No mixer parameters to set for device " .. i .. ": " .. device.name)
      oprint("")
    end
  end
  
  -- PHASE 5: Apply Device Properties to ALL devices (Last to First)
  oprint("-- PHASE 5: Apply Device Properties to ALL devices (Last to First)")
  oprint("")
  
  for i = #actual_devices, 1, -1 do
    local device = actual_devices[i]
    local placeholder = "PAKETTI_PLACEHOLDER_" .. string.format("%03d", i)
    
    oprint("-- Apply properties for device " .. i .. ": " .. device.name)
    oprint("for i, device in ipairs(renoise.song().selected_track.devices) do")
    oprint('  if device.display_name == "' .. placeholder .. '" then')
    
    -- Smart display name restoration: preserve custom names, allow default names to be auto-renamed
    local original_name = original_display_names[i]
    local is_default_lfo_name = (original_name == "*LFO" or original_name:match("^%*LFO %(%d+%)$"))
    
    if not is_default_lfo_name then
      -- Custom name (like "LFOEnvelopePan") - always restore it
      oprint('    device.display_name = "' .. original_name .. '"')
    else
      -- Default name (like "*LFO" or "*LFO (2)") - let parameters/routing rename it
      oprint('    -- Keeping default LFO name "' .. original_name .. '" - allowing parameter-based renaming')
    end
    
    oprint('    device.is_maximized = ' .. tostring(device.is_maximized))
    oprint('    device.is_active = ' .. tostring(device.is_active))
    if device.external_editor_available then
      oprint('    if device.external_editor_available then')
      oprint('      device.external_editor_visible = ' .. tostring(device.external_editor_visible))
      oprint('    end')
    end
    if generate_debug_prints then
      oprint('    print("DEBUG: Applied properties for device ' .. i .. '")')
    end
    oprint('    break')
    oprint('  end')
    oprint('end')
    oprint("")
  end
  
  oprint("-- TRACK DEVICE CHAIN RECREATION COMPLETE")
  oprint("-- Total devices processed: " .. #actual_devices)
  oprint("")
  if generate_debug_prints then
    oprint("-- Final verification:")
    for i, device in ipairs(actual_devices) do
      oprint('print("DEBUG: Final check - Device ' .. i .. ' (' .. device.name .. ') should be at track position " .. (#renoise.song().selected_track.devices - ' .. (#actual_devices - i) .. '))')
    end
  end
end

function inspectTrackDeviceChainClean()
  inspectTrackDeviceChain(false)  -- Generate clean script without debug prints
end

renoise.tool():add_keybinding{name="Global:Paketti:Inspect Track Device Chain",invoke=function() inspectTrackDeviceChain() end}
renoise.tool():add_keybinding{name="Global:Paketti:Inspect Track Device Chain (Clean)",invoke=function() inspectTrackDeviceChainClean() end}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Inspect Track Device Chain", invoke = inspectTrackDeviceChain}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Inspect Track Device Chain (Clean)", invoke = inspectTrackDeviceChainClean}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Inspect Track Device Chain", invoke = inspectTrackDeviceChain}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Inspect Track Device Chain (Clean)", invoke = inspectTrackDeviceChainClean}



-- Helper function to load SeparateSyncLFO preset into container device
function loadSeparateSyncLFOIntoContainer(device)
  -- Define the SeparateSyncLFO device XML that should be injected
  local formula_device_xml = [=[        <FormulaMetaDevice type="FormulaMetaDevice">
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <CustomDeviceName>Separate Sync LFO</CustomDeviceName>
          <IsMaximized>true</IsMaximized>
          <IsSelected>true</IsSelected>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <FormulaParagraphs>
            <FormulaParagraph>calculation(A,B)</FormulaParagraph>
          </FormulaParagraphs>
          <FunctionsParagraphs>
            <FunctionsParagraph>--[[</FunctionsParagraph>
            <FunctionsParagraph>Simple formula for calculating LFO per pattern length</FunctionsParagraph>
            <FunctionsParagraph>]]</FunctionsParagraph>
            <FunctionsParagraph/>
            <FunctionsParagraph>--[[</FunctionsParagraph>
            <FunctionsParagraph>]]</FunctionsParagraph>
            <FunctionsParagraph/>
            <FunctionsParagraph>local function calculation(x,y)</FunctionsParagraph>
            <FunctionsParagraph>  local spd_array = {16, 8, 4, 2, 1, 0.5, 0.25, 0.10, 0.01}</FunctionsParagraph>
            <FunctionsParagraph>  local off_array  = {1, 0.66, 0.75, 0.8}</FunctionsParagraph>
            <FunctionsParagraph>  local spd = x == 0 and spd_array[1] or spd_array[ceil(#spd_array*x)]</FunctionsParagraph>
            <FunctionsParagraph>  local off = y == 0 and off_array[1] or off_array[ceil(#off_array*y)]</FunctionsParagraph>
            <FunctionsParagraph>  return (((LINE)%(LPB*(spd*off)))/(LPB*(spd*off)))</FunctionsParagraph>
            <FunctionsParagraph>end</FunctionsParagraph>
          </FunctionsParagraphs>
          <InputNameA>SPD</InputNameA>
          <InputNameB>STR,TRP,DOT</InputNameB>
          <InputNameC>NOT USED</InputNameC>
          <EditorVisible>true</EditorVisible>
          <InputA>
            <Value>0.359402984</Value>
          </InputA>
          <InputB>
            <Value>0.635881007</Value>
          </InputB>
          <InputC>
            <Value>0.0</Value>
          </InputC>
        </FormulaMetaDevice>]=]
  
  -- Define which parameters should be mapped to macros (based on original SeparateSyncLFO mixer exposure)
  local mixer_params = {
    {name = "SPD", index = 1, value = "0.359402984"},
    {name = "STR,TRP,DOT", index = 2, value = "0.635881007"}
  }
  
  loadPresetIntoContainer(device, formula_device_xml, "Separate Sync LFO", mixer_params)
end

function SeparateSyncLFOBeatsgo()
  local selected_device = renoise.song().selected_device
  
  -- Check if we have a selected device that is a container
  if selected_device and isContainerDevice(selected_device) then
    loadSeparateSyncLFOIntoContainer(selected_device)
    return
  end
  
  -- Original behavior: load directly on track
  -- 1. Load Device (with Line Input protection)
  loadnative("Audio/Effects/Native/*Formula")
  -- 2. Inject Current Device State XML
  local device_xml = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="FormulaMetaDevice">
    <IsMaximized>true</IsMaximized>
    <FormulaParagraphs>
      <FormulaParagraph>calculation(A,B)</FormulaParagraph>
    </FormulaParagraphs>
    <FunctionsParagraphs>
      <FunctionsParagraph>--[[</FunctionsParagraph>
      <FunctionsParagraph>Simple formula for calculating LFO per pattern length</FunctionsParagraph>
      <FunctionsParagraph>]]</FunctionsParagraph>
      <FunctionsParagraph/>
      <FunctionsParagraph>--[[</FunctionsParagraph>
      <FunctionsParagraph>]]</FunctionsParagraph>
      <FunctionsParagraph/>
      <FunctionsParagraph>local function calculation(x,y)</FunctionsParagraph>
      <FunctionsParagraph>  local spd_array = {16, 8, 4, 2, 1, 0.5, 0.25, 0.10, 0.01}</FunctionsParagraph>
      <FunctionsParagraph>  local off_array  = {1, 0.66, 0.75, 0.8}</FunctionsParagraph>
      <FunctionsParagraph>  local spd = x == 0 and spd_array[1] or spd_array[ceil(#spd_array*x)]</FunctionsParagraph>
      <FunctionsParagraph>  local off = y == 0 and off_array[1] or off_array[ceil(#off_array*y)]</FunctionsParagraph>
      <FunctionsParagraph>  return (((LINE)%(LPB*(spd*off)))/(LPB*(spd*off)))</FunctionsParagraph>
      <FunctionsParagraph>end</FunctionsParagraph>
    </FunctionsParagraphs>
    <InputNameA>SPD</InputNameA>
    <InputNameB>STR,TRP,DOT</InputNameB>
    <InputNameC>NOT USED</InputNameC>
    <EditorVisible>true</EditorVisible>
    <InputA>
      <Value>0.359402984</Value>
    </InputA>
    <InputB>
      <Value>0.635881007</Value>
    </InputB>
    <InputC>
      <Value>0.0</Value>
    </InputC>
  </DeviceSlot>
</FilterDevicePreset>
]=]
  renoise.song().selected_device.active_preset_data = device_xml
  -- 3. Set Mixer Parameter Visibility
  renoise.song().selected_device.parameters[1].show_in_mixer = true
  renoise.song().selected_device.parameters[2].show_in_mixer = true
  -- 4. Set Device Maximized State
  renoise.song().selected_device.is_maximized = true
  -- 5. Set External Editor State
  -- External editor not available for this device
  -- 6. Set Device Display Name
  renoise.song().selected_device.display_name = "Separate Sync LFO"
  -- 7. Set Device Enabled/Disabled State
  -- renoise.song().selected_device.is_active = true (default)
  -- Total parameters exposed in Mixer: 2
end

renoise.tool():add_keybinding{name="Global:Paketti:SeparateSyncLFO (Beatsgo) (Preset++)", invoke = SeparateSyncLFOBeatsgo}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:SeparateSyncLFO (Beatsgo LFO)", invoke = SeparateSyncLFOBeatsgo}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:SeparateSyncLFO (Beatsgo) (Preset++)", invoke = SeparateSyncLFOBeatsgo}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:SeparateSyncLFO (Beatsgo LFO)", invoke = SeparateSyncLFOBeatsgo}




-- ==========================================
-- CONTAINER DEVICE SUPPORT (SPLITTER & DOOFER)
-- ==========================================
-- 
-- This system allows any Preset++ device to be loaded directly into
-- Splitter or Doofer devices instead of onto the track.
--
-- How it works:
-- 1. Each Preset++ function checks if selected device is a container
-- 2. If so, it calls the appropriate "loadXIntoContainer" helper
-- 3. The helper uses loadPresetIntoContainer() with device-specific XML
-- 4. The XML is injected into DeviceChain0 for Splitter or main chain for Doofer
--
-- To add container support to a new Preset++ function:
-- 1. Create a "loadXIntoContainer" helper with device XML (see examples below)
-- 2. Add container detection at start of main function (see HipassPlusPlus example)
-- 3. Call the helper and return early if container device detected
--
-- ==========================================

-- Helper function to check if device is a container (Splitter or Doofer)
function isContainerDevice(device)
  if not device then return false end
  return device.device_path == "Audio/Effects/Native/Splitter" or device.device_path == "Audio/Effects/Native/Doofer"
end

-- Helper function to create macro mapping XML for container devices
function createMacroMapping(macro_index, param_name, param_index, chain_index, device_index, param_value)
  local mapping_xml = string.format([=[    <Macro%d>
      <Value>%s</Value>
      <Name>%s</Name>
      <Mappings>
        <Mapping>
          <DestChainIndex>%d</DestChainIndex>
          <DestDeviceIndex>%d</DestDeviceIndex>
          <DestParameterIndex>%d</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro%d>]=], 
    macro_index, param_value or "50", param_name, chain_index, device_index, param_index, macro_index)
  
  return mapping_xml
end

-- Helper function to find the next available macro slot
function findNextAvailableMacro(xml_content, max_macros)
  max_macros = max_macros or 16  -- Default to 16 macros max
  
  for i = 0, max_macros - 1 do
    local macro_pattern = "<Macro" .. i .. ">.-<Mappings>.-</Mappings>.-</Macro" .. i .. ">"
    if not xml_content:find(macro_pattern) then
      -- Check if it has any non-default content (not just name/value)
      local basic_macro_pattern = "<Macro" .. i .. ">.-<Name>([^<]*)</Name>.-</Macro" .. i .. ">"
      local name_match = xml_content:match(basic_macro_pattern)
      if not name_match or name_match == "Macro " .. (i + 1) then
        -- This macro is available (either doesn't exist or has default name)
        return i
      end
    end
  end
  
  return nil  -- No available macros found
end

-- Generic helper function to load any preset device into container device with macro mapping
function loadPresetIntoContainer(device, device_xml, device_name, mixer_params)
  local current_xml = device.active_preset_data
  if not current_xml or current_xml == "" then
    oprint("ERROR: Container device has no preset data to modify")
    renoise.app():show_status("Container device has no preset data to modify")
    return
  end
  
  oprint("=== CONTAINER DEVICE DEBUG INFO ===")
  oprint("Device path: " .. device.device_path)
  oprint("Device name: " .. device_name)
  oprint("Current XML length: " .. string.len(current_xml))
  
  -- Find available macro slots for this container device
  local available_macros = {}
  if mixer_params then
    local start_macro = findNextAvailableMacro(current_xml, 16)
    if start_macro then
      oprint("Found available macro starting at: " .. start_macro)
      for i = 1, #mixer_params do
        local macro_index = start_macro + i - 1
        if macro_index < 16 then  -- Don't exceed 16 macros
          table.insert(available_macros, macro_index)
          oprint("  Will use Macro" .. macro_index .. " for " .. mixer_params[i].name)
        else
          oprint("  WARNING: Ran out of available macros at parameter " .. i)
          break
        end
      end
    else
      oprint("ERROR: No available macros found!")
      renoise.app():show_status("No available macros in container device")
      return
    end
  end
  
  -- Process mixer parameters for macro mapping (will be updated with correct chain for Splitter)
  local macro_mappings = {}
  local macro_params_to_expose = {}
  local mixer_params_copy = mixer_params  -- Keep original for later processing
  
  -- For Splitter: inject into the currently visible chain 
  if device.device_path == "Audio/Effects/Native/Splitter" then
    oprint("Processing Splitter device...")
    
    -- Parse the currently visible chain from XML
    local visible_chain_match = current_xml:match("<CurrentlyVisibleChain>(%d+)</CurrentlyVisibleChain>")
    local visible_chain = visible_chain_match and tonumber(visible_chain_match) or 0
    local target_chain_name = "DeviceChain" .. visible_chain
    local layer_name = visible_chain == 0 and "Layer 1" or "Layer 2"
    
    oprint("Currently visible chain: " .. visible_chain .. " (" .. layer_name .. ")")
    oprint("Target chain: " .. target_chain_name)
    
    -- Setup macro mappings with correct chain index for Splitter
    if mixer_params_copy and #available_macros > 0 then
      oprint("Setting up macro mappings for " .. #mixer_params_copy .. " parameters:")
      for i, param_info in ipairs(mixer_params_copy) do
        if i <= #available_macros then
          local macro_index = available_macros[i]
          oprint("  Macro" .. macro_index .. " -> " .. param_info.name .. " (param index " .. param_info.index .. ", chain " .. visible_chain .. ")")
          table.insert(macro_mappings, createMacroMapping(macro_index, param_info.name, param_info.index, visible_chain, 0, param_info.value))
          table.insert(macro_params_to_expose, macro_index + 1) -- Macro parameter indices (1-based for Splitter params)
        else
          oprint("  Skipping " .. param_info.name .. " - no more available macros")
        end
      end
    end
    
    -- Debug: Check if target DeviceChain exists
    local target_pattern = "<" .. target_chain_name .. ">"
    if current_xml:find(target_pattern) then
      oprint("Found " .. target_chain_name .. " in XML")
    else
      oprint("ERROR: " .. target_chain_name .. " not found in XML!")
      oprint("XML content preview:")
      oprint(current_xml:sub(1, 500) .. "...")
      return
    end
    
    -- Check if Devices exists within the target chain
    local devices_pattern = "<" .. target_chain_name .. ">.-<Devices>"
    local has_devices = current_xml:find(devices_pattern)
    local pattern, replacement, new_xml
    
    if has_devices then
      oprint("Found <Devices> within " .. target_chain_name .. " - injecting into existing devices")
      -- Inject into existing <Devices> section
      pattern = "(<" .. target_chain_name .. ">.-<Devices>)"
      replacement = "%1\n" .. device_xml
      new_xml = current_xml:gsub(pattern, replacement)
    else
      oprint("No <Devices> found in " .. target_chain_name .. " - creating new devices section")
      -- Create a new <Devices> section before the closing tag
      pattern = "(<" .. target_chain_name .. ">.-)(</DeviceChain" .. visible_chain .. ">)"
      replacement = "%1\n      <Devices>\n" .. device_xml .. "\n      </Devices>\n    %2"
      new_xml = current_xml:gsub(pattern, replacement)
    end
    
    if new_xml ~= current_xml then
      oprint("SUCCESS: Device XML injected")
      
      -- Now replace macro mappings if we have any
      if #macro_mappings > 0 then
        oprint("Injecting macro mappings...")
        for i, macro_xml in ipairs(macro_mappings) do
          if i <= #available_macros then
            local macro_index = available_macros[i]
            local macro_pattern = "(<Macro" .. macro_index .. ">.-</Macro" .. macro_index .. ">)"
            new_xml = new_xml:gsub(macro_pattern, macro_xml)
            oprint("  Replaced Macro" .. macro_index .. " with mapping")
          end
        end
      end
      
      device.active_preset_data = new_xml
      
      -- Expose macro parameters to mixer
      if #macro_params_to_expose > 0 then
        oprint("Exposing macro parameters to mixer...")
        for _, param_index in ipairs(macro_params_to_expose) do
          device.parameters[param_index].show_in_mixer = true
          oprint("  Exposed parameter " .. param_index .. " (" .. device.parameters[param_index].name .. ") to mixer")
        end
      end
      
      oprint(device_name .. " loaded into Splitter " .. target_chain_name .. " (" .. layer_name .. ") with macro mappings")
      renoise.app():show_status(device_name .. " loaded into Splitter " .. layer_name .. " with macro mappings")
    else
      oprint("ERROR: Pattern replacement failed")
      oprint("Pattern used: " .. pattern)
      renoise.app():show_status("Could not modify Splitter XML - pattern not found")
    end
    
  -- For Doofer: inject into the main device chain
  elseif device.device_path == "Audio/Effects/Native/Doofer" then
    oprint("Processing Doofer device...")
    
    -- Setup macro mappings for Doofer (always uses chain 0, device 0)
    if mixer_params_copy and #available_macros > 0 then
      oprint("Setting up macro mappings for " .. #mixer_params_copy .. " parameters:")
      for i, param_info in ipairs(mixer_params_copy) do
        if i <= #available_macros then
          local macro_index = available_macros[i]
          oprint("  Macro" .. macro_index .. " -> " .. param_info.name .. " (param index " .. param_info.index .. ", chain 0)")
          table.insert(macro_mappings, createMacroMapping(macro_index, param_info.name, param_info.index, 0, 0, param_info.value))
          table.insert(macro_params_to_expose, macro_index + 1) -- Macro parameter indices (1-based for Doofer params)
        else
          oprint("  Skipping " .. param_info.name .. " - no more available macros")
        end
      end
    end
    
    -- Debug: Check if Devices exists
    if current_xml:find("<Devices>") then
      oprint("Found <Devices> in XML")
    else
      oprint("ERROR: <Devices> not found in XML!")
      oprint("XML content preview:")
      oprint(current_xml:sub(1, 500) .. "...")
      return
    end
    
    -- Look for the <Devices> section and inject the device
    local pattern = "(<Devices>)"
    local replacement = "%1\n" .. device_xml
    local new_xml = current_xml:gsub(pattern, replacement)
    
    if new_xml ~= current_xml then
      oprint("SUCCESS: Device XML injected")
      
      -- Now replace macro mappings if we have any
      if #macro_mappings > 0 then
        oprint("Injecting macro mappings...")
        for i, macro_xml in ipairs(macro_mappings) do
          if i <= #available_macros then
            local macro_index = available_macros[i]
            local macro_pattern = "(<Macro" .. macro_index .. ">.-</Macro" .. macro_index .. ">)"
            new_xml = new_xml:gsub(macro_pattern, macro_xml)
            oprint("  Replaced Macro" .. macro_index .. " with mapping")
          end
        end
      end
      
      device.active_preset_data = new_xml
      
      -- Expose macro parameters to mixer
      if #macro_params_to_expose > 0 then
        oprint("Exposing macro parameters to mixer...")
        for _, param_index in ipairs(macro_params_to_expose) do
          device.parameters[param_index].show_in_mixer = true
          oprint("  Exposed parameter " .. param_index .. " (" .. device.parameters[param_index].name .. ") to mixer")
        end
      end
      
      oprint(device_name .. " loaded into Doofer with macro mappings")
      renoise.app():show_status(device_name .. " loaded into Doofer with macro mappings")
    else
      oprint("ERROR: Pattern replacement failed")
      oprint("Pattern used: " .. pattern)
      renoise.app():show_status("Could not modify Doofer XML - pattern not found")
    end
  end
  
  oprint("=== END DEBUG INFO ===")
end

-- Generic helper function to load multiple devices (device chain) into container device
function loadDeviceChainIntoContainer(device, device_xmls, chain_name, mixer_params)
  local current_xml = device.active_preset_data
  if not current_xml or current_xml == "" then
    renoise.app():show_status("Container device has no preset data to modify")
    return
  end
  
  -- Combine all device XMLs
  local combined_xml = ""
  for _, device_xml in ipairs(device_xmls) do
    combined_xml = combined_xml .. "\n" .. device_xml
  end
  
  -- Find available macro slots for this container device (device chain version)
  local available_macros = {}
  if mixer_params then
    local start_macro = findNextAvailableMacro(current_xml, 16)
    if start_macro then
      for i = 1, #mixer_params do
        local macro_index = start_macro + i - 1
        if macro_index < 16 then  -- Don't exceed 16 macros
          table.insert(available_macros, macro_index)
        else
          break
        end
      end
    end
  end
  
  -- Process mixer parameters for macro mapping (will be set correctly per device type)
  local macro_mappings = {}
  local macro_params_to_expose = {}
  
  -- For Splitter: inject into the currently visible chain
  if device.device_path == "Audio/Effects/Native/Splitter" then
    -- Parse the currently visible chain from XML
    local visible_chain_match = current_xml:match("<CurrentlyVisibleChain>(%d+)</CurrentlyVisibleChain>")
    local visible_chain = visible_chain_match and tonumber(visible_chain_match) or 0
    local target_chain_name = "DeviceChain" .. visible_chain
    local layer_name = visible_chain == 0 and "Layer 1" or "Layer 2"
    
    -- Setup macro mappings for Splitter device chain
    if mixer_params then
      for i, param_info in ipairs(mixer_params) do
        if i <= #available_macros then
          local macro_index = available_macros[i]
          table.insert(macro_mappings, createMacroMapping(macro_index, param_info.name, param_info.index, visible_chain, param_info.device_index or 0, param_info.value))
          table.insert(macro_params_to_expose, macro_index + 1)
        end
      end
    end
    
    -- Look for the target DeviceChain section and inject the devices
    local pattern = "(<" .. target_chain_name .. ">.-<Devices>)"
    local replacement = "%1" .. combined_xml
    local new_xml = current_xml:gsub(pattern, replacement)
    
    if new_xml ~= current_xml then
      -- Apply macro mappings if we have any
      if #macro_mappings > 0 then
        for i, macro_xml in ipairs(macro_mappings) do
          if i <= #available_macros then
            local macro_index = available_macros[i]
            local macro_pattern = "(<Macro" .. macro_index .. ">.-</Macro" .. macro_index .. ">)"
            new_xml = new_xml:gsub(macro_pattern, macro_xml)
          end
        end
      end
      
      device.active_preset_data = new_xml
      
      -- Expose macro parameters to mixer
      if #macro_params_to_expose > 0 then
        for _, param_index in ipairs(macro_params_to_expose) do
          device.parameters[param_index].show_in_mixer = true
        end
      end
      
      renoise.app():show_status(chain_name .. " device chain loaded into Splitter " .. layer_name .. " with macro mappings")
    else
      renoise.app():show_status("Could not modify Splitter XML - pattern not found")
    end
    
  -- For Doofer: inject into the main device chain
  elseif device.device_path == "Audio/Effects/Native/Doofer" then
    -- Setup macro mappings for Doofer device chain
    if mixer_params then
      for i, param_info in ipairs(mixer_params) do
        if i <= #available_macros then
          local macro_index = available_macros[i]
          table.insert(macro_mappings, createMacroMapping(macro_index, param_info.name, param_info.index, 0, param_info.device_index or 0, param_info.value))
          table.insert(macro_params_to_expose, macro_index + 1)
        end
      end
    end
    
    -- Look for the <Devices> section and inject the devices
    local pattern = "(<Devices>)"
    local replacement = "%1" .. combined_xml
    local new_xml = current_xml:gsub(pattern, replacement)
    
    if new_xml ~= current_xml then
      -- Apply macro mappings if we have any
      if #macro_mappings > 0 then
        for i, macro_xml in ipairs(macro_mappings) do
          if i <= #available_macros then
            local macro_index = available_macros[i]
            local macro_pattern = "(<Macro" .. macro_index .. ">.-</Macro" .. macro_index .. ">)"
            new_xml = new_xml:gsub(macro_pattern, macro_xml)
          end
        end
      end
      
      device.active_preset_data = new_xml
      
      -- Expose macro parameters to mixer
      if #macro_params_to_expose > 0 then
        for _, param_index in ipairs(macro_params_to_expose) do
          device.parameters[param_index].show_in_mixer = true
        end
      end
      
      renoise.app():show_status(chain_name .. " device chain loaded into Doofer with macro mappings")
    else
      renoise.app():show_status("Could not modify Doofer XML - pattern not found")
    end
  end
end

-- Helper function to load Hipass preset into container device
function loadHipassIntoContainer(device)
  -- Define the Hipass device XML that should be injected
  local hipass_device_xml = [=[        <DigitalFilterDevice type="DigitalFilterDevice">
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <CustomDeviceName>Hipass (Preset++)</CustomDeviceName>
          <IsMaximized>true</IsMaximized>
          <IsSelected>true</IsSelected>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <OversamplingFactor>2x</OversamplingFactor>
          <Model>Biquad</Model>
          <Type>
            <Value>3</Value>
            <Visualization>Device only</Visualization>
          </Type>
          <Cutoff>
            <Value>0.0</Value>
            <Visualization>Mixer and Device</Visualization>
          </Cutoff>
          <Q>
            <Value>0.125</Value>
            <Visualization>Device only</Visualization>
          </Q>
          <Ripple>
            <Value>0.0</Value>
            <Visualization>Device only</Visualization>
          </Ripple>
          <Inertia>
            <Value>0.0078125</Value>
            <Visualization>Device only</Visualization>
          </Inertia>
          <ShowResponseView>true</ShowResponseView>
          <ResponseViewMaxGain>18</ResponseViewMaxGain>
        </DigitalFilterDevice>]=]
  
  -- Define which parameters should be mapped to macros (based on original Hipass++ mixer exposure)
  local mixer_params = {
    {name = "Cutoff", index = 2, value = "0.0"}  -- Cutoff parameter (index 2) from DigitalFilter device
  }
  
  loadPresetIntoContainer(device, hipass_device_xml, "Hipass (Preset++)", mixer_params)
end

-- Helper function to load LFOEnvelopePan preset into container device
function loadLFOEnvelopePanIntoContainer(device)
  -- Define the LFO device XML that should be injected
  local lfo_device_xml = [=[        <LfoDevice type="LfoDevice">
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <CustomDeviceName>LFOEnvelopePan</CustomDeviceName>
          <IsMaximized>true</IsMaximized>
          <IsSelected>true</IsSelected>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <Amplitude>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </Amplitude>
          <Offset>
            <Value>0.0</Value>
            <Visualization>Device only</Visualization>
          </Offset>
          <Frequency>
            <Value>0.0292968769</Value>
            <Visualization>Mixer and Device</Visualization>
          </Frequency>
          <Type>
            <Value>4</Value>
            <Visualization>Device only</Visualization>
          </Type>
          <CustomEnvelope>
            <PlayMode>Lines</PlayMode>
            <Length>1024</Length>
            <ValueQuantum>0.0</ValueQuantum>
            <Polarity>Unipolar</Polarity>
            <Points>
              <Point>0,0.5,0.0</Point>
              <Point>1,0.5,0.0</Point>
              <Point>2,0.5,0.0</Point>
              <Point>3,0.5,0.0</Point>
              <Point>4,0.5,0.0</Point>
              <Point>5,0.5,0.0</Point>
              <Point>6,0.5,0.0</Point>
              <Point>7,0.5,0.0</Point>
              <Point>8,0.5,0.0</Point>
              <Point>9,0.5,0.0</Point>
              <Point>10,0.5,0.0</Point>
              <Point>11,0.5,0.0</Point>
              <Point>12,0.5,0.0</Point>
              <Point>13,0.5,0.0</Point>
              <Point>14,0.5,0.0</Point>
              <Point>15,0.5,0.0</Point>
              <Point>1008,0.501805007,0.0</Point>
              <Point>1009,0.501805007,0.0</Point>
              <Point>1010,0.501805007,0.0</Point>
              <Point>1011,0.501805007,0.0</Point>
              <Point>1012,0.501805007,0.0</Point>
              <Point>1013,0.501805007,0.0</Point>
              <Point>1014,0.501805007,0.0</Point>
              <Point>1015,0.501805007,0.0</Point>
              <Point>1016,0.501805007,0.0</Point>
              <Point>1017,0.501805007,0.0</Point>
              <Point>1018,0.501805007,0.0</Point>
              <Point>1019,0.501805007,0.0</Point>
              <Point>1020,0.501805007,0.0</Point>
              <Point>1021,0.501805007,0.0</Point>
              <Point>1022,0.501805007,0.0</Point>
              <Point>1023,0.501805007,0.0</Point>
            </Points>
          </CustomEnvelope>
          <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
          <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
        </LfoDevice>]=]
  
  -- Define which parameters should be mapped to macros (based on original LFOEnvelopePan mixer exposure)
  local mixer_params = {
    {name = "Amplitude", index = 4, value = "1.0"},
    {name = "Offset", index = 5, value = "0.0"},
    {name = "Frequency", index = 6, value = "0.0292968769"}
  }
  
  loadPresetIntoContainer(device, lfo_device_xml, "LFOEnvelopePan", mixer_params)
end

function HipassPlusPlus()
  local selected_device = renoise.song().selected_device
  
  -- Check if we have a selected device that is a container
  if selected_device and isContainerDevice(selected_device) then
    loadHipassIntoContainer(selected_device)
    return
  end
  
  -- Original behavior: load directly on track
  -- 1. Load Device (with Line Input protection)
  loadnative("Audio/Effects/Native/Digital Filter", nil, nil, nil, true)
  -- 2. Inject Current Device State XML
  local device_xml = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="DigitalFilterDevice">
    <IsMaximized>true</IsMaximized>
    <OversamplingFactor>2x</OversamplingFactor>
    <Model>Biquad</Model>
    <Type>
      <Value>3</Value>
    </Type>
    <Cutoff>
      <Value>0.0</Value>
    </Cutoff>
    <Q>
      <Value>0.125</Value>
    </Q>
    <Ripple>
      <Value>0.0</Value>
    </Ripple>
    <Inertia>
      <Value>0.0078125</Value>
    </Inertia>
    <ShowResponseView>true</ShowResponseView>
    <ResponseViewMaxGain>18</ResponseViewMaxGain>
  </DeviceSlot>
</FilterDevicePreset>
]=]
  renoise.song().selected_device.active_preset_data = device_xml
  -- 3. Set Mixer Parameter Visibility
  renoise.song().selected_device.parameters[2].show_in_mixer = true
  -- 4. Set Device Maximized State
  renoise.song().selected_device.is_maximized = true
  -- 5. Set External Editor State
  -- External editor not available for this device
  -- 6. Set Device Display Name
  renoise.song().selected_device.display_name = "Hipass (Preset++)"
  -- Total parameters exposed in Mixer: 1

end


renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:Hipass", invoke = HipassPlusPlus}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:Hipass", invoke = HipassPlusPlus}
renoise.tool():add_keybinding{name="DSP Device:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}
renoise.tool():add_keybinding{name="Mixer:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}
renoise.tool():add_keybinding{name="Global:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}


function LFOEnvelopePanPresetPlusPlus()
  local selected_device = renoise.song().selected_device
  
  -- Check if we have a selected device that is a container
  if selected_device and isContainerDevice(selected_device) then
    loadLFOEnvelopePanIntoContainer(selected_device)
    return
  end
  
  -- Original behavior: load directly on track using device chain recreation
-- === TRACK DEVICE CHAIN RECREATION ===
-- Track: Track 06
-- Total devices (excluding Track Vol/Pan): 1
-- Debug prints: false
-- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER
-- Loading LAST device first, then second-last, etc. to maintain correct order
-- Loading device 1: *LFO (LFOEnvelopePan)
loadnative("Audio/Effects/Native/*LFO", nil, nil, false, true)
renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_001"
-- PHASE 2: Apply XML to ALL devices (Last to First)
-- Apply XML for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>1.0</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>0.0292968769</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>1024</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.5,0.0</Point>
        <Point>1,0.5,0.0</Point>
        <Point>2,0.5,0.0</Point>
        <Point>3,0.5,0.0</Point>
        <Point>4,0.5,0.0</Point>
        <Point>5,0.5,0.0</Point>
        <Point>6,0.5,0.0</Point>
        <Point>7,0.5,0.0</Point>
        <Point>8,0.5,0.0</Point>
        <Point>9,0.5,0.0</Point>
        <Point>10,0.5,0.0</Point>
        <Point>11,0.5,0.0</Point>
        <Point>12,0.5,0.0</Point>
        <Point>13,0.5,0.0</Point>
        <Point>14,0.5,0.0</Point>
        <Point>15,0.5,0.0</Point>
        <Point>1008,0.501805007,0.0</Point>
        <Point>1009,0.501805007,0.0</Point>
        <Point>1010,0.501805007,0.0</Point>
        <Point>1011,0.501805007,0.0</Point>
        <Point>1012,0.501805007,0.0</Point>
        <Point>1013,0.501805007,0.0</Point>
        <Point>1014,0.501805007,0.0</Point>
        <Point>1015,0.501805007,0.0</Point>
        <Point>1016,0.501805007,0.0</Point>
        <Point>1017,0.501805007,0.0</Point>
        <Point>1018,0.501805007,0.0</Point>
        <Point>1019,0.501805007,0.0</Point>
        <Point>1020,0.501805007,0.0</Point>
        <Point>1021,0.501805007,0.0</Point>
        <Point>1022,0.501805007,0.0</Point>
        <Point>1023,0.501805007,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>
]=]
    break
  end
end
-- PHASE 3: Apply Parameters to ALL devices (Last to First)
-- Apply parameters for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    device.parameters[2].value = 0
    device.parameters[3].value = 1
    device.parameters[4].value = 1
    device.parameters[6].value = 0.029296876862645
    device.parameters[7].value = 4
    break
  end
end
-- PHASE 4: Apply Mixer Visibility to ALL devices (Last to First)
-- Apply mixer visibility for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    device.parameters[4].show_in_mixer = true
    device.parameters[5].show_in_mixer = true
    device.parameters[6].show_in_mixer = true
    break
  end
end
-- PHASE 5: Apply Device Properties to ALL devices (Last to First)
-- Apply properties for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    device.display_name = "LFOEnvelopePan"
    device.is_maximized = true
    device.is_active = true
    if device.external_editor_available then
      device.external_editor_visible = true
    end
    break
  end
end
-- TRACK DEVICE CHAIN RECREATION COMPLETE
-- Total devices processed: 1

end

renoise.tool():add_keybinding{name="Global:Paketti:LFOEnvelopePan (Preset++)", invoke = LFOEnvelopePanPresetPlusPlus}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:LFOEnvelopePan", invoke = LFOEnvelopePanPresetPlusPlus}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:LFOEnvelopePan (Preset++)", invoke = LFOEnvelopePanPresetPlusPlus}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:LFOEnvelopePan", invoke = LFOEnvelopePanPresetPlusPlus}

-- Standalone Send Device Preset++ Function
function PakettiSendDevicePresetPlusPlus(send_track_name)
  -- Collect all send tracks to find the target
  local send_tracks = {}
  local target_send_index = nil
  local count = 0

  for i = 1, #renoise.song().tracks do
    if renoise.song().tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
      local send_info = {index = count, name = renoise.song().tracks[i].name, track_number = i - 1}
      table.insert(send_tracks, send_info)
      
      -- If we found the target send track name, store its index
      if send_track_name and renoise.song().tracks[i].name == send_track_name then
        target_send_index = count
      end
      count = count + 1
    end
  end

  if count == 0 then
    renoise.app():show_status("No Send tracks found")
    return
  end

  -- If no specific send track name was provided, use the first send track
  if not target_send_index then
    target_send_index = 0
    send_track_name = send_tracks[1].name
  end

  -- Load Send device using loadnative (which handles XML injection automatically)
  loadnative("Audio/Effects/Native/#Send")
  
  -- Get the newly loaded device and configure it
  local device = renoise.song().selected_device
  if device and device.name == "#Send" then
    -- Set send destination
    device.parameters[3].value = target_send_index
    
    -- Rename device to send track name
    device.display_name = send_track_name
    renoise.app():show_status("Send device '" .. send_track_name .. "' created with Preset++ XML injection")
  else
    renoise.app():show_status("ERROR - Failed to load Send device")
  end
end

-- Standalone Multiband Send Device Preset++ Function
function PakettiMultibandSendDevicePresetPlusPlus(send_track_name)
  -- Collect all send tracks to find the target
  local send_tracks = {}
  local target_send_index = nil
  local count = 0

  for i = 1, #renoise.song().tracks do
    if renoise.song().tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
      local send_info = {index = count, name = renoise.song().tracks[i].name, track_number = i - 1}
      table.insert(send_tracks, send_info)
      
      -- If we found the target send track name, store its index
      if send_track_name and renoise.song().tracks[i].name == send_track_name then
        target_send_index = count
      end
      count = count + 1
    end
  end

  if count == 0 then
    renoise.app():show_status("No Send tracks found")
    return
  end

  -- If no specific send track name was provided, use the first send track
  if not target_send_index then
    target_send_index = 0
    send_track_name = send_tracks[1].name
  end

  -- Load Multiband Send device using loadnative (which handles XML injection automatically)
  loadnative("Audio/Effects/Native/#Multiband Send")
  
  -- Get the newly loaded device and configure it
  local device = renoise.song().selected_device
  if device and device.name == "#Multiband Send" then
    -- Set send destination for all three bands
    device.parameters[2].value = target_send_index  -- Low band send destination
    device.parameters[4].value = target_send_index  -- Mid band send destination  
    device.parameters[6].value = target_send_index  -- High band send destination
    
    -- Rename device to send track name
    device.display_name = send_track_name .. " (MB)"
    renoise.app():show_status("Multiband Send device '" .. send_track_name .. " (MB)' created with Preset++ XML injection")
  else
    renoise.app():show_status("ERROR - Failed to load Multiband Send device")
  end
end

-- ADD SEND DEVICE ONLY (connects to existing send tracks via dropdown)
renoise.tool():add_keybinding{name="Global:Paketti:Send Device (Preset++)", invoke = function() PakettiSendDevicePresetPlusPlus() end}
renoise.tool():add_keybinding{name="Global:Paketti:Multiband Send Device (Preset++)", invoke = function() PakettiMultibandSendDevicePresetPlusPlus() end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:Send Device", invoke = function() PakettiSendDevicePresetPlusPlus() end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:Multiband Send Device", invoke = function() PakettiMultibandSendDevicePresetPlusPlus() end}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Send Device (Preset++)", invoke = function() PakettiSendDevicePresetPlusPlus() end}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Multiband Send Device (Preset++)", invoke = function() PakettiMultibandSendDevicePresetPlusPlus() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:Send Device", invoke = function() PakettiSendDevicePresetPlusPlus() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:Multiband Send Device", invoke = function() PakettiMultibandSendDevicePresetPlusPlus() end}

-- Helper function to load Send preset into container device
function loadSendIntoContainer(device, send_index, send_name)
  local send_device_xml = string.format([=[        <SendDevice type="SendDevice">
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <CustomDeviceName>%s</CustomDeviceName>
          <IsMaximized>false</IsMaximized>
          <IsSelected>true</IsSelected>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <Volume>
            <Value>0.706923366</Value>
            <Visualization>Mixer and Device</Visualization>
          </Volume>
          <SmoothParameterChanges>true</SmoothParameterChanges>
          <DestSendTrack>%d</DestSendTrack>
          <Mute>false</Mute>
        </SendDevice>]=], send_name or "Send (Preset++)", send_index or 0)
  
  local mixer_params = {
    {name = "Volume", index = 1, value = "0.706923366"}
  }
  
  loadPresetIntoContainer(device, send_device_xml, send_name or "Send (Preset++)", mixer_params)
end

-- Helper function to load Multiband Send preset into container device
function loadMultibandSendIntoContainer(device, send_index, send_name)
  local multiband_send_device_xml = string.format([=[        <MultibandSendDevice type="MultibandSendDevice">
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <CustomDeviceName>%s</CustomDeviceName>
          <IsMaximized>false</IsMaximized>
          <IsSelected>true</IsSelected>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <Band1Volume>
            <Value>0.706923366</Value>
            <Visualization>Mixer and Device</Visualization>
          </Band1Volume>
          <Band2Volume>
            <Value>0.706923366</Value>
            <Visualization>Mixer and Device</Visualization>
          </Band2Volume>
          <Band3Volume>
            <Value>0.706923366</Value>
            <Visualization>Mixer and Device</Visualization>
          </Band3Volume>
          <SmoothParameterChanges>true</SmoothParameterChanges>
          <DestSendTrack>%d</DestSendTrack>
          <Mute>false</Mute>
          <Band1Mute>false</Band1Mute>
          <Band2Mute>false</Band2Mute>
          <Band3Mute>false</Band3Mute>
          <SplitFrequency1>
            <Value>0.25</Value>
            <Visualization>Mixer and Device</Visualization>
          </SplitFrequency1>
          <SplitFrequency2>
            <Value>0.75</Value>
            <Visualization>Mixer and Device</Visualization>
          </SplitFrequency2>
        </MultibandSendDevice>]=], send_name or "Multiband Send (Preset++)", send_index or 0)
  
  local mixer_params = {
    {name = "Band1Volume", index = 1, value = "0.706923366"},
    {name = "Band2Volume", index = 2, value = "0.706923366"},
    {name = "Band3Volume", index = 3, value = "0.706923366"},
    {name = "SplitFreq1", index = 7, value = "0.25"},
    {name = "SplitFreq2", index = 8, value = "0.75"}
  }
  
  loadPresetIntoContainer(device, multiband_send_device_xml, send_name or "Multiband Send (Preset++)", mixer_params)
end

function SendPresetPlusPlus()
  local selected_device = renoise.song().selected_device
  
  -- Check if we have a selected device that is a container
  if selected_device and isContainerDevice(selected_device) then
    loadSendIntoContainer(selected_device, 0, "Send (Preset++)")
    return
  end
  
  -- Original behavior: load directly on track
  loadnative("Audio/Effects/Native/#Send", nil, nil, nil, true)
  
  local device_xml = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="SendDevice">
    <IsMaximized>false</IsMaximized>
    <Volume>
      <Value>0.706923366</Value>
    </Volume>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <DestSendTrack>0</DestSendTrack>
    <Mute>false</Mute>
  </DeviceSlot>
</FilterDevicePreset>
]=]
  
  renoise.song().selected_device.active_preset_data = device_xml
  renoise.song().selected_device.parameters[1].show_in_mixer = true
  renoise.song().selected_device.is_maximized = false
  renoise.song().selected_device.display_name = "Send (Preset++)"
end

function MultibandSendPresetPlusPlus()
  local selected_device = renoise.song().selected_device
  
  -- Check if we have a selected device that is a container
  if selected_device and isContainerDevice(selected_device) then
    loadMultibandSendIntoContainer(selected_device, 0, "Multiband Send (Preset++)")
    return
  end
  
  -- Original behavior: load directly on track
  loadnative("Audio/Effects/Native/#Multiband Send", nil, nil, nil, true)
  
  local device_xml = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="MultibandSendDevice">
    <IsMaximized>false</IsMaximized>
    <Band1Volume>
      <Value>0.706923366</Value>
    </Band1Volume>
    <Band2Volume>
      <Value>0.706923366</Value>
    </Band2Volume>
    <Band3Volume>
      <Value>0.706923366</Value>
    </Band3Volume>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <DestSendTrack>0</DestSendTrack>
    <Mute>false</Mute>
    <Band1Mute>false</Band1Mute>
    <Band2Mute>false</Band2Mute>
    <Band3Mute>false</Band3Mute>
    <SplitFrequency1>
      <Value>0.25</Value>
    </SplitFrequency1>
    <SplitFrequency2>
      <Value>0.75</Value>
    </SplitFrequency2>
  </DeviceSlot>
</FilterDevicePreset>
]=]
  
  renoise.song().selected_device.active_preset_data = device_xml
  renoise.song().selected_device.parameters[1].show_in_mixer = true
  renoise.song().selected_device.parameters[2].show_in_mixer = true
  renoise.song().selected_device.parameters[3].show_in_mixer = true
  renoise.song().selected_device.parameters[7].show_in_mixer = true
  renoise.song().selected_device.parameters[8].show_in_mixer = true
  renoise.song().selected_device.is_maximized = false
  renoise.song().selected_device.display_name = "Multiband Send (Preset++)"
end

-- ADD SEND/MULTIBAND DEVICE TO EXISTING SEND TRACKS (legacy functions)
renoise.tool():add_keybinding{name="Global:Paketti:Send (Preset++)", invoke = SendPresetPlusPlus}
renoise.tool():add_keybinding{name="Global:Paketti:Multiband Send (Preset++)", invoke = MultibandSendPresetPlusPlus}


function inspectTrackDeviceChainTEST()

--------------------------
--------------------------
--------------------------
--------------------------
-- === TRACK DEVICE CHAIN RECREATION ===
-- Track: 8120_03[016]
-- Total devices (excluding Track Vol/Pan): 3
-- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER
-- Loading LAST device first, then second-last, etc. to maintain correct order
-- Loading device 3: Maximizer (Maximizer)
loadnative("Audio/Effects/Native/Maximizer", nil, nil, false, true)
renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_003"
print("DEBUG: Loaded device 3 (Maximizer) with placeholder PAKETTI_PLACEHOLDER_003")
-- Loading device 2: *LFO (*LFO (2))
loadnative("Audio/Effects/Native/*LFO", nil, nil, false, true)
renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_002"
print("DEBUG: Loaded device 2 (*LFO) with placeholder PAKETTI_PLACEHOLDER_002")
-- Loading device 1: *LFO (*LFO)
loadnative("Audio/Effects/Native/*LFO", nil, nil, false, true)
renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_001"
print("DEBUG: Loaded device 1 (*LFO) with placeholder PAKETTI_PLACEHOLDER_001")
-- PHASE 2: Apply XML to ALL devices (Last to First)
-- Apply XML for device 3: Maximizer
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_003" then
    print("DEBUG: Starting XML injection for device 3 (Maximizer)")
    device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="MaximizerDevice">
    <IsMaximized>true</IsMaximized>
    <InputGain>
      <Value>9.69028282</Value>
    </InputGain>
    <Threshold>
      <Value>-0.0199999996</Value>
    </Threshold>
    <TransientRelease>
      <Value>1.0</Value>
    </TransientRelease>
    <LongTermRelease>
      <Value>80</Value>
    </LongTermRelease>
    <Ceiling>
      <Value>0.0</Value>
    </Ceiling>
  </DeviceSlot>
</FilterDevicePreset>
]=]
    print("DEBUG: XML injection completed for device 3")
    break
  end
end
-- Apply XML for device 2: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_002" then
    print("DEBUG: Starting XML injection for device 2 (*LFO)")
    device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>0.30647099</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>1.44000101</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>64</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.0,0.0</Point>
        <Point>6,0.169527903,0.0</Point>
        <Point>8,0.293991417,0.0</Point>
        <Point>10,0.306866944,0.0</Point>
        <Point>12,0.212446347,0.0</Point>
        <Point>14,0.197424889,0.0</Point>
        <Point>16,0.221030042,0.0</Point>
        <Point>18,0.358369112,0.0</Point>
        <Point>20,0.328326166,0.0</Point>
        <Point>22,0.276824027,0.0</Point>
        <Point>24,0.2360515,0.0</Point>
        <Point>26,0.240343347,0.0</Point>
        <Point>28,0.317596555,0.0</Point>
        <Point>30,0.285407722,0.0</Point>
        <Point>32,0.278969944,0.0</Point>
        <Point>34,0.28111589,0.0</Point>
        <Point>36,0.296137333,0.0</Point>
        <Point>38,0.313304722,0.0</Point>
        <Point>40,0.540772557,0.0</Point>
        <Point>42,0.568669558,0.0</Point>
        <Point>44,0.551502168,0.0</Point>
        <Point>46,0.521459222,0.0</Point>
        <Point>48,0.504291832,0.0</Point>
        <Point>50,0.497854084,0.0</Point>
        <Point>52,0.506437778,0.0</Point>
        <Point>54,0.542918444,0.0</Point>
        <Point>56,0.568669558,0.0</Point>
        <Point>58,0.538626611,0.0</Point>
        <Point>60,0.497854084,0.0</Point>
        <Point>63,1.0,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>
]=]
    print("DEBUG: XML injection completed for device 2")
    break
  end
end
-- Apply XML for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    print("DEBUG: Starting XML injection for device 1 (*LFO)")
    device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>0.5</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>1.85837531</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>64</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.0,0.0</Point>
        <Point>6,0.115879826,0.0</Point>
        <Point>8,0.0793991387,0.0</Point>
        <Point>10,0.0321888402,0.0</Point>
        <Point>12,0.00858369097,0.0</Point>
        <Point>14,0.0815450624,0.0</Point>
        <Point>16,0.173819736,0.0</Point>
        <Point>18,0.105150215,0.0</Point>
        <Point>20,0.0858369097,0.0</Point>
        <Point>22,0.0944206044,0.0</Point>
        <Point>24,0.139484972,0.0</Point>
        <Point>26,0.124463521,0.0</Point>
        <Point>28,0.109442063,0.0</Point>
        <Point>30,0.100858368,0.0</Point>
        <Point>32,0.0987124443,0.0</Point>
        <Point>34,0.0987124443,0.0</Point>
        <Point>36,0.0987124443,0.0</Point>
        <Point>38,0.128755361,0.0</Point>
        <Point>40,0.156652361,0.0</Point>
        <Point>42,0.197424889,0.0</Point>
        <Point>44,0.28111589,0.0</Point>
        <Point>46,0.326180249,0.0</Point>
        <Point>48,0.297567934,0.0</Point>
        <Point>50,0.25,0.0</Point>
        <Point>52,0.223175973,0.0</Point>
        <Point>54,0.261802584,0.0</Point>
        <Point>56,0.326180249,0.0</Point>
        <Point>58,0.324034333,0.0</Point>
        <Point>60,0.2918455,0.0</Point>
        <Point>62,0.268240333,0.0</Point>
        <Point>63,1.0,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>
]=]
    print("DEBUG: XML injection completed for device 1")
    break
  end
end
-- PHASE 3: Apply Parameters to ALL devices (Last to First)
-- Apply parameters for device 3: Maximizer
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_003" then
    device.parameters[1].value = 9.9192905426025
    print("DEBUG: Applied parameters for device 3")
    break
  end
end
-- Apply parameters for device 2: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_002" then
    device.parameters[2].value = 3
    device.parameters[3].value = 1
    device.parameters[4].value = 0.30524969100952
    device.parameters[6].value = 1.4400010108948
    device.parameters[7].value = 4
    print("DEBUG: Applied parameters for device 2")
    break
  end
end
-- Apply parameters for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    device.parameters[2].value = 2
    device.parameters[3].value = 4
    device.parameters[6].value = 1.8583753108978
    device.parameters[7].value = 4
    print("DEBUG: Applied parameters for device 1")
    break
  end
end
-- PHASE 4: Apply Mixer Visibility to ALL devices (Last to First)
-- Apply mixer visibility for device 3: Maximizer
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_003" then
    device.parameters[1].show_in_mixer = true
    device.parameters[5].show_in_mixer = true
    print("DEBUG: Set 2 mixer parameters visible for device 3")
    break
  end
end
-- Apply mixer visibility for device 2: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_002" then
    device.parameters[4].show_in_mixer = true
    print("DEBUG: Set 1 mixer parameters visible for device 2")
    break
  end
end
-- No mixer parameters to set for device 1: *LFO
-- PHASE 5: Apply Device Properties to ALL devices (Last to First)
-- Apply properties for device 3: Maximizer
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_003" then
    device.display_name = "Maximizer"
    device.is_maximized = true
    device.is_active = true
    print("DEBUG: Applied properties for device 3")
    break
  end
end
-- Apply properties for device 2: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_002" then
    device.display_name = "*LFO (2)"
    device.is_maximized = true
    device.is_active = true
    if device.external_editor_available then
      device.external_editor_visible = false
    end
    print("DEBUG: Applied properties for device 2")
    break
  end
end
-- Apply properties for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    device.display_name = "*LFO"
    device.is_maximized = true
    device.is_active = true
    if device.external_editor_available then
      device.external_editor_visible = false
    end
    print("DEBUG: Applied properties for device 1")
    break
  end
end
-- TRACK DEVICE CHAIN RECREATION COMPLETE
-- Total devices processed: 3
-- Final verification:
print("DEBUG: Final check - Device 1 (*LFO) should be at track position " .. (#renoise.song().selected_track.devices - 2))
print("DEBUG: Final check - Device 2 (*LFO) should be at track position " .. (#renoise.song().selected_track.devices - 1))
print("DEBUG: Final check - Device 3 (Maximizer) should be at track position " .. (#renoise.song().selected_track.devices - 0))

end

--inspectTrackDeviceChainTEST()

-- Create New Send function for PakettiPresetPlusPlus
function PakettiPresetPlusPlusCreateNewSend()
  local song = renoise.song()
  
  -- Get current track info
  local current_track = song.selected_track
  local current_track_name = current_track.name
  
  -- Count existing send tracks to determine numbering
  local send_track_count = song.send_track_count
  local next_send_number = send_track_count + 1
  
  -- Calculate position for new send track
  local new_send_position
  if send_track_count == 0 then
    -- No send tracks exist: sequencer_track_count + 2 (sequencer + master + after master)
    new_send_position = song.sequencer_track_count + 2
  else
    -- Send tracks exist: sequencer_track_count + 1 + send_track_count
    new_send_position = song.sequencer_track_count + 1 + send_track_count
  end
  
  -- Create new send track name
  local send_track_name = string.format("S%02d %s", next_send_number, current_track_name)
  
  -- Insert new send track
  song:insert_track_at(new_send_position)
  local new_send_track = song.tracks[new_send_position]
  new_send_track.name = send_track_name
  
  -- Select the original track to add the send device
  song.selected_track_index = song.selected_track_index
  
  -- Load Send device using XML injection
  loadnative("Audio/Effects/Native/#Send", nil, nil, nil, true)
  
  local device_xml = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="SendDevice">
    <IsMaximized>false</IsMaximized>
    <Volume>
      <Value>0.706923366</Value>
    </Volume>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <DestSendTrack>]=] .. (send_track_count) .. [=[</DestSendTrack>
    <Mute>false</Mute>
  </DeviceSlot>
</FilterDevicePreset>
]=]
  
  -- Apply XML and configure the Send device
  local send_device = song.selected_device
  if send_device and send_device.name == "#Send" then
    send_device.active_preset_data = device_xml
    send_device.parameters[3].value = send_track_count  -- Set send destination to the new send track
    send_device.parameters[1].show_in_mixer = true      -- Show volume in mixer
    send_device.is_maximized = false
    send_device.display_name = send_track_name
    
    renoise.app():show_status("Created Send Track '" .. send_track_name .. "' and connected Send device")
  else
    renoise.app():show_status("ERROR - Failed to load Send device")
  end
end

-- Create New Multiband Send function for PakettiPresetPlusPlus
function PakettiPresetPlusPlusCreateNewMultibandSend()
  local song = renoise.song()
  
  -- Get current track info
  local current_track = song.selected_track
  local current_track_name = current_track.name
  
  -- Count existing send tracks to determine numbering
  local send_track_count = song.send_track_count
  local next_send_number = send_track_count + 1
  
  -- Calculate position for new send track
  local new_send_position
  if send_track_count == 0 then
    -- No send tracks exist: sequencer_track_count + 2 (sequencer + master + after master)
    new_send_position = song.sequencer_track_count + 2
  else
    -- Send tracks exist: sequencer_track_count + 1 + send_track_count
    new_send_position = song.sequencer_track_count + 1 + send_track_count
  end
  
  -- Create new send track name
  local send_track_name = string.format("S%02d %s", next_send_number, current_track_name)
  
  -- Insert new send track
  song:insert_track_at(new_send_position)
  local new_send_track = song.tracks[new_send_position]
  new_send_track.name = send_track_name
  
  -- Select the original track to add the send device
  song.selected_track_index = song.selected_track_index
  
  -- Load Multiband Send device using existing working preset (like PakettiLoaders.lua does)
  loadnative("Audio/Effects/Native/#Multiband Send", nil, "./Presets/PakettiMultiSend.xml", nil, true)
  
  -- Configure parameters based on mode
  local status_msg
  local send_device = song.selected_device
  if send_device and send_device.name == "#Multiband Send" then
    -- Set send destination (find DestSendTrack parameter)
    for i = 1, #send_device.parameters do
      if send_device.parameters[i].name == "DestSendTrack" then
        send_device.parameters[i].value = send_track_count
        break
      end
    end
    
    -- Configure volume and mute based on mode
    if mode == "mute" then
      send_device.parameters[1].value = 1.0  -- Band1Volume MAXIMUM
      send_device.parameters[3].value = 1.0  -- Band2Volume MAXIMUM
      send_device.parameters[5].value = 1.0  -- Band3Volume MAXIMUM
      -- Note: MultibandSend doesn't have MuteSource parameter
      status_msg = "with Mute Source Multiband Send device"
-- Silent mode removed
    else -- "keep" mode (default)
      send_device.parameters[1].value = 0.0  -- Band1Volume MINIMUM (-inf dB)
      send_device.parameters[3].value = 0.0  -- Band2Volume MINIMUM (-inf dB)
      send_device.parameters[5].value = 0.0  -- Band3Volume MINIMUM (-inf dB)
      status_msg = "and connected Multiband Send device"
    end
    
    -- Show parameters in mixer (following PakettiLoaders.lua style)
    send_device.parameters[1].show_in_mixer = false
    send_device.parameters[3].show_in_mixer = false
    send_device.parameters[5].show_in_mixer = false
    send_device.parameters[7].show_in_mixer = true  -- SplitFrequency1
    send_device.parameters[8].show_in_mixer = true  -- SplitFrequency2
    
    send_device.is_maximized = false
    send_device.display_name = send_track_name
    
    -- Select the newly created send track
    song.selected_track_index = new_send_position
    
    renoise.app():show_status("Created Send Track '" .. send_track_name .. "' " .. status_msg)
  else
    renoise.app():show_status("ERROR - Failed to load Multiband Send device")
  end
end

-- CREATE NEW SEND TRACK + DEVICE (creates both track and device)
renoise.tool():add_keybinding{name="Global:Paketti:Create New Send Track (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:Create New Send Track", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Create New Send Track (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:Create New Send Track", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Preset++:Create New Send Track (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Preset++:Create New Send Track (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}

-- DRY Create New Send function with mode parameter
-- mode: "keep" (keep source, send at minimum volume), "mute" (mute source, send at maximum volume)
function PakettiPresetPlusPlusCreateNewSendWithMode(mode)
  local song = renoise.song()
  mode = mode or "keep"
  
  -- Get current track info
  local current_track = song.selected_track
  local current_track_name = current_track.name
  
  -- Count existing send tracks to determine numbering
  local send_track_count = song.send_track_count
  local next_send_number
  
  -- Use preference to determine naming scheme
  if PakettiCreateNewSends.SendNamingPerTrack.value then
    -- Per-track naming: count sends for this specific track
    local track_send_count = 0
    for i = 1, #song.tracks do
      if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
        -- Check if this send track name contains our current track name
        if song.tracks[i].name:find(current_track_name, 1, true) then
          track_send_count = track_send_count + 1
        end
      end
    end
    next_send_number = track_send_count + 1
  else
    -- Global naming: increment across all tracks
    next_send_number = send_track_count + 1
  end
  
  -- Calculate position for new send track
  local new_send_position
  if send_track_count == 0 then
    -- No send tracks exist: after master track
    new_send_position = song.sequencer_track_count + 2
  else
    -- Send tracks exist: after the last existing send track
    new_send_position = song.sequencer_track_count + 1 + send_track_count + 1
  end
  
  -- Create new send track name
  local send_track_name = string.format("S%02d %s", next_send_number, current_track_name)
  
  -- Insert new send track
  song:insert_track_at(new_send_position)
  local new_send_track = song.tracks[new_send_position]
  new_send_track.name = send_track_name
  
  -- Set collapsed state based on preference
  if renoise.tool().preferences.pakettiCreateNewSends.Collapsed.value then
    new_send_track.collapsed = true
  end
  
  -- Select the original track to add the send device
  song.selected_track_index = song.selected_track_index
  
  -- Load Send device using existing working preset (like PakettiLoaders.lua does)
  loadnative("Audio/Effects/Native/#Send", nil, "./Presets/PakettiSend.xml", nil, true)
  
  -- Configure parameters based on mode
  local status_msg
  local send_device = song.selected_device
  if send_device and send_device.name == "#Send" then
    -- Set send destination to the newly created send track (send_track_count = index of new track)
    send_device.parameters[3].value = send_track_count
    
    -- Configure volume based on mode
    if mode == "mute" then
      send_device.parameters[1].value = 1.0  -- SendAmount to MAXIMUM volume
      status_msg = "with Send device at maximum volume"
    else -- "keep" mode (default)
      send_device.parameters[1].value = 0.0  -- SendAmount to MINIMUM volume (-inf dB)
      status_msg = "and connected Send device"
    end
    
    send_device.parameters[2].show_in_mixer = false
    send_device.is_maximized = false
    send_device.display_name = send_track_name
    
    -- Select the newly created send track
    song.selected_track_index = new_send_position
    
    renoise.app():show_status("Created Send Track '" .. send_track_name .. "' " .. status_msg)
  else
    renoise.app():show_status("ERROR - Failed to load Send device")
  end
end

-- DRY Create New Multiband Send function with mode parameter
-- mode: "keep" (keep source, send at minimum volume), "mute" (send at maximum volume)
function PakettiPresetPlusPlusCreateNewMultibandSendWithMode(mode)
  local song = renoise.song()
  mode = mode or "keep"
  
  -- Get current track info
  local current_track = song.selected_track
  local current_track_name = current_track.name
  
  -- Count existing send tracks to determine numbering
  local send_track_count = song.send_track_count
  local next_send_number
  
  -- Use preference to determine naming scheme
  if PakettiCreateNewSends.SendNamingPerTrack.value then
    -- Per-track naming: count sends for this specific track
    local track_send_count = 0
    for i = 1, #song.tracks do
      if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
        -- Check if this send track name contains our current track name
        if song.tracks[i].name:find(current_track_name, 1, true) then
          track_send_count = track_send_count + 1
        end
      end
    end
    next_send_number = track_send_count + 1
  else
    -- Global naming: increment across all tracks
    next_send_number = send_track_count + 1
  end
  
  -- Calculate position for new send track
  local new_send_position
  if send_track_count == 0 then
    -- No send tracks exist: after master track
    new_send_position = song.sequencer_track_count + 2
  else
    -- Send tracks exist: after the last existing send track
    new_send_position = song.sequencer_track_count + 1 + send_track_count + 1
  end
  
  -- Create new send track name
  local send_track_name = string.format("S%02d %s", next_send_number, current_track_name)
  
  -- Insert new send track
  song:insert_track_at(new_send_position)
  local new_send_track = song.tracks[new_send_position]
  new_send_track.name = send_track_name
  
  -- Set collapsed state based on preference
  if renoise.tool().preferences.pakettiCreateNewSends.Collapsed.value then
    new_send_track.collapsed = true
  end
  
  -- Select the original track to add the send device
  song.selected_track_index = song.selected_track_index
  
  -- Load Multiband Send device using existing working preset (like PakettiLoaders.lua does)
  loadnative("Audio/Effects/Native/#Multiband Send", nil, "./Presets/PakettiMultiSend.xml", nil, true)
  
  -- Configure parameters based on mode
  local status_msg
  local send_device = song.selected_device
  if send_device and send_device.name == "#Multiband Send" then
    -- Set send destination (find DestSendTrack parameter)
    for i = 1, #send_device.parameters do
      if send_device.parameters[i].name == "DestSendTrack" then
        send_device.parameters[i].value = send_track_count
        break
      end
    end
    
    -- Configure volume and mute based on mode
    if mode == "mute" then
      send_device.parameters[1].value = 1.0  -- Band1Volume MAXIMUM
      send_device.parameters[3].value = 1.0  -- Band2Volume MAXIMUM
      send_device.parameters[5].value = 1.0  -- Band3Volume MAXIMUM
      -- Note: MultibandSend doesn't have MuteSource parameter
      status_msg = "with Mute Source Multiband Send device"
-- Silent mode removed
    else -- "keep" mode (default)
      send_device.parameters[1].value = 0.0  -- Band1Volume MINIMUM (-inf dB)
      send_device.parameters[3].value = 0.0  -- Band2Volume MINIMUM (-inf dB)
      send_device.parameters[5].value = 0.0  -- Band3Volume MINIMUM (-inf dB)
      status_msg = "and connected Multiband Send device"
    end
    
    -- Show parameters in mixer (following PakettiLoaders.lua style)
    send_device.parameters[1].show_in_mixer = false
    send_device.parameters[3].show_in_mixer = false
    send_device.parameters[5].show_in_mixer = false
    send_device.parameters[7].show_in_mixer = true  -- SplitFrequency1
    send_device.parameters[8].show_in_mixer = true  -- SplitFrequency2
    
    send_device.is_maximized = false
    send_device.display_name = send_track_name
    
    renoise.app():show_status("Created Send Track '" .. send_track_name .. "' " .. status_msg)
  else
    renoise.app():show_status("ERROR - Failed to load Multiband Send device")
  end
end


-- COMPLETE DRY KEYBINDINGS (4 total - all modes covered)
renoise.tool():add_keybinding{name="Global:Paketti:Create New Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_keybinding{name="Global:Paketti:Create New Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("mute") end}
renoise.tool():add_keybinding{name="Global:Paketti:Create New Multiband Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("keep") end}
renoise.tool():add_keybinding{name="Global:Paketti:Create New Multiband Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("mute") end}

renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Create New Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Create New Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Create New Multiband Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="DSP Chain:Paketti:Create New Multiband Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:Create New Send Track (Keep Source)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Preset++:Create New Send Track (Mute Source)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Preset++:Create New Multiband Send Track (Keep Source)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti:Preset++:Create New Multiband Send Track (Mute Source)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:Create New Send Track (Keep Source)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Preset++:Create New Send Track (Mute Source)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Preset++:Create New Multiband Send Track (Keep Source)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Preset++:Create New Multiband Send Track (Mute Source)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Preset++:Create New Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Preset++:Create New Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Preset++:Create New Multiband Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Preset++:Create New Multiband Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Create New Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Create New Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewSendWithMode("mute") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Create New Multiband Send Track (Keep Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("keep") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Create New Multiband Send Track (Mute Source) (Preset++)", invoke = function() PakettiPresetPlusPlusCreateNewMultibandSendWithMode("mute") end}

-- Create New Track with Channelstrip function
function PakettiCreateNewTrackWithChannelstrip()
  local song = renoise.song()
  local current_track_index = song.selected_track_index
  local new_track_index = current_track_index + 1
  
  -- Insert new track at the position after current track
  song:insert_track_at(new_track_index)
  
  -- Select the newly created track
  song.selected_track_index = new_track_index
  
  -- Get device chain path from preferences
  local device_chain_path = renoise.tool().preferences.pakettiPresetPlusPlusDeviceChain.value
  
  -- If it's a relative path, make it absolute from tool bundle
  if not device_chain_path:match("^[/\\]") and not device_chain_path:match("^%a:") then
    device_chain_path = renoise.tool().bundle_path .. device_chain_path
  end
  
  -- Load the device chain to the selected track with error handling
  local success, error_message = pcall(function()
    renoise.app():load_track_device_chain(device_chain_path)
  end)
  
  if success then
    local chain_name = device_chain_path:match("[^/\\]+$") or device_chain_path
    renoise.app():show_status("Created new track with device chain: " .. chain_name)
  else
    renoise.app():show_status("ERROR: Could not load device chain - " .. (error_message or "file not found"))
  end
end


-- Add keybinding and menu entries for Create New Track with Channelstrip
renoise.tool():add_keybinding{name="Global:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_keybinding{name="Mixer:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Create New Track with Channelstrip", invoke = PakettiCreateNewTrackWithChannelstrip}

