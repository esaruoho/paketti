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





function HipassPlusPlus()
-- 1. Load Device (with Line Input protection)
loadnative("Audio/Effects/Native/Digital Filter")
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
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:Hipass", invoke = HipassPlusPlus}
renoise.tool():add_keybinding{name="DSP Device:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}
renoise.tool():add_keybinding{name="Mixer:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}
renoise.tool():add_keybinding{name="Global:Paketti:Hipass (Preset++)", invoke = HipassPlusPlus}


function LFOEnvelopePanPresetPlusPlus()
-- === TRACK DEVICE CHAIN RECREATION ===
-- Track: Track 06
-- Total devices (excluding Track Vol/Pan): 1
-- Debug prints: false
-- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER
-- Loading LAST device first, then second-last, etc. to maintain correct order
-- Loading device 1: *LFO (LFOEnvelopePan)
loadnative("Audio/Effects/Native/*LFO", nil, nil, false)
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
      device.external_editor_visible = false
    end
    break
  end
end
-- TRACK DEVICE CHAIN RECREATION COMPLETE
-- Total devices processed: 1

end

renoise.tool():add_keybinding{name="Global:Paketti:LFOEnvelopePan (Preset++)", invoke = LFOEnvelopePanPresetPlusPlus}
renoise.tool():add_menu_entry{name="--DSP Device:Paketti:Preset++:LFOEnvelopePan", invoke = LFOEnvelopePanPresetPlusPlus}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Preset++:LFOEnvelopePan", invoke = LFOEnvelopePanPresetPlusPlus}


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
loadnative("Audio/Effects/Native/Maximizer", nil, nil, false)
renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_003"
print("DEBUG: Loaded device 3 (Maximizer) with placeholder PAKETTI_PLACEHOLDER_003")
-- Loading device 2: *LFO (*LFO (2))
loadnative("Audio/Effects/Native/*LFO", nil, nil, false)
renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_002"
print("DEBUG: Loaded device 2 (*LFO) with placeholder PAKETTI_PLACEHOLDER_002")
-- Loading device 1: *LFO (*LFO)
loadnative("Audio/Effects/Native/*LFO", nil, nil, false)
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


