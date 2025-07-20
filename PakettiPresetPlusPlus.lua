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

function inspectTrackDeviceChain()
  local track = renoise.song().selected_track
  local devices = track.devices
  
  -- Check if there are any devices beyond Track Vol/Pan (index 1)
  if #devices <= 1 then
    renoise.app():show_status("Nothing to inspect, doing nothing.")
    return
  end
  
  -- Get actual devices (skip Track Vol/Pan at index 1)
  local actual_devices = {}
  for i = 2, #devices do  -- Start from index 2 to skip Track Vol/Pan
    table.insert(actual_devices, devices[i])
  end
  
  oprint("-- === TRACK DEVICE CHAIN RECREATION ===")
  oprint("-- Track: " .. track.name)
  oprint("-- Total devices (excluding Track Vol/Pan): " .. #actual_devices)
  
  -- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER
  oprint("")
  oprint("-- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER")
  oprint("-- Loading LAST device first, then second-last, etc. to maintain correct order")
  oprint("local base_index = #renoise.song().selected_track.devices + 1")
  oprint("")
  
  -- Load devices in REVERSE order (last first, first last) with placeholders
  for i = #actual_devices, 1, -1 do
    local device = actual_devices[i]
    oprint("-- Loading device " .. i .. ": " .. device.name .. " (" .. device.display_name .. ")")
    if device.device_path:find("Native/") then
      oprint('loadnative("' .. device.device_path .. '")')
    else
      oprint('loadvst("' .. device.device_path .. '")')  
    end
    -- Calculate correct insertion position and set placeholder
    local placeholder_index = #actual_devices - i
    oprint('renoise.song().selected_track.devices[base_index + ' .. placeholder_index .. '].display_name = "PAKETTI_PLACEHOLDER_' .. string.format("%03d", i) .. '"')
    oprint('print("DEBUG: Loaded device ' .. i .. ' (' .. device.name .. ') at slot " .. (base_index + ' .. placeholder_index .. ') .. " with placeholder PAKETTI_PLACEHOLDER_' .. string.format("%03d", i) .. '")')
    oprint("")
  end
  
  -- PHASE 2: Configure Devices Using Placeholders
  oprint("-- PHASE 2: Configure Devices Using Placeholders")
  oprint("")
  
  for i, device in ipairs(actual_devices) do
    local placeholder = "PAKETTI_PLACEHOLDER_" .. string.format("%03d", i)
    
    oprint("-- Configure device " .. i .. ": " .. device.name .. " (" .. device.display_name .. ")")
    oprint("for i, device in ipairs(renoise.song().selected_track.devices) do")
    oprint('  if device.display_name == "' .. placeholder .. '" then')
    oprint('    print("DEBUG: Configuring device ' .. i .. ' (' .. device.name .. ') found at index " .. i)')
    
    -- Set mixer parameter visibility
    local mixer_param_count = 0
    for j, param in ipairs(device.parameters) do
      if param.show_in_mixer then
        mixer_param_count = mixer_param_count + 1
        oprint('    device.parameters[' .. j .. '].show_in_mixer = true')
      end
    end
    
    if mixer_param_count > 0 then
      oprint('    print("DEBUG: Set ' .. mixer_param_count .. ' mixer parameters visible")')
    else
      oprint('    print("DEBUG: No mixer parameters to set")')
    end
    
    -- Set device properties
    oprint('    device.display_name = "' .. device.display_name .. '"')
    oprint('    device.is_maximized = ' .. tostring(device.is_maximized))
    oprint('    device.is_active = ' .. tostring(device.is_active))
    oprint('    print("DEBUG: Set device properties - name: ' .. device.display_name .. ', maximized: ' .. tostring(device.is_maximized) .. ', active: ' .. tostring(device.is_active) .. '")')
    
    -- External editor state (ALWAYS generate safe code)
    oprint('    print("DEBUG: Checking external editor availability before XML injection: " .. tostring(device.external_editor_available))')
    oprint('    if device.external_editor_available then')
    if device.external_editor_available then
      oprint('      device.external_editor_visible = ' .. tostring(device.external_editor_visible))
      oprint('      print("DEBUG: Set external editor visible to ' .. tostring(device.external_editor_visible) .. '")')
    else
      oprint('      print("DEBUG: Device has no external editor before XML injection")')
    end
    oprint('    end')
    
    oprint('    break')
    oprint('  end')
    oprint('end')
    oprint("")
  end
  
  -- PHASE 3: XML Injection (FINAL)
  oprint("-- PHASE 3: XML Injection (FINAL)")
  oprint("")
  
  for i, device in ipairs(actual_devices) do
    local placeholder = "PAKETTI_PLACEHOLDER_" .. string.format("%03d", i)
    
    if device.active_preset_data and device.active_preset_data ~= "" then
      oprint("-- Inject XML for device " .. i .. ": " .. device.name)
      oprint("for i, device in ipairs(renoise.song().selected_track.devices) do")
      oprint('  if device.display_name == "' .. placeholder .. '" then')
      oprint('    print("DEBUG: Starting XML injection for device ' .. i .. ' (' .. device.name .. ')")')
      oprint('    device.active_preset_data = [=[' .. device.active_preset_data .. ']=]')
      oprint('    print("DEBUG: XML injection completed for device ' .. i .. '")')
      oprint('    print("DEBUG: External editor now available: " .. tostring(device.external_editor_available))')
      oprint('    if device.external_editor_available then')
      oprint('      print("DEBUG: SUCCESS - XML injection enabled external editor for device ' .. i .. '")')
      oprint('    else')
      oprint('      print("DEBUG: WARNING - XML injection did not enable external editor for device ' .. i .. '")')
      oprint('    end')
      oprint('    break')
      oprint('  end')
      oprint('end')
      oprint("")
    else
      oprint("-- No XML data for device " .. i .. ": " .. device.name)
      oprint('print("DEBUG: No XML data available for device ' .. i .. ' (' .. device.name .. ')")')
      oprint("")
    end
  end
  
  oprint("-- TRACK DEVICE CHAIN RECREATION COMPLETE")
  oprint("-- Total devices processed: " .. #actual_devices)
  oprint("")
  oprint("-- Final verification:")
  for i, device in ipairs(actual_devices) do
    oprint('print("DEBUG: Final check - Device ' .. i .. ' (' .. device.name .. ') should be at track position " .. (#renoise.song().selected_track.devices - ' .. (#actual_devices - i) .. '))')
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Inspect Track Device Chain",invoke=function() inspectTrackDeviceChain() end}
renoise.tool():add_menu_entry{name="--DSP Chain:Paketti:Inspect Track Device Chain", invoke = inspectTrackDeviceChain}
renoise.tool():add_menu_entry{name="--Mixer:Paketti:Inspect Track Device Chain", invoke = inspectTrackDeviceChain}





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



function heyYo()

-- === TRACK DEVICE CHAIN RECREATION ===
-- Track: 8120_03[016]
-- Total devices (excluding Track Vol/Pan): 3
-- PHASE 1: Load All Devices (with Placeholders) - REVERSE ORDER
-- Loading LAST device first, then second-last, etc. to maintain correct order
local base_index = #renoise.song().selected_track.devices + 1
-- Loading device 3: Maximizer (Maximizer)
loadnative("Audio/Effects/Native/Maximizer")
renoise.song().selected_track.devices[base_index + 0].display_name = "PAKETTI_PLACEHOLDER_003"
print("DEBUG: Loaded device at position " .. (base_index + 0) .. " with placeholder PAKETTI_PLACEHOLDER_003")
-- Loading device 2: *LFO (*LFO (2))
loadnative("Audio/Effects/Native/*LFO")
renoise.song().selected_track.devices[base_index + 1].display_name = "PAKETTI_PLACEHOLDER_002"
print("DEBUG: Loaded device at position " .. (base_index + 1) .. " with placeholder PAKETTI_PLACEHOLDER_002")
-- Loading device 1: *LFO (*LFO)
loadnative("Audio/Effects/Native/*LFO")
renoise.song().selected_track.devices[base_index + 2].display_name = "PAKETTI_PLACEHOLDER_001"
print("DEBUG: Loaded device at position " .. (base_index + 2) .. " with placeholder PAKETTI_PLACEHOLDER_001")
-- PHASE 2: Set Parameters and Device States
-- Configure device 1: *LFO (*LFO)
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    print("DEBUG: Found placeholder PAKETTI_PLACEHOLDER_001 at device index " .. i .. ", configuring as *LFO")
    -- No parameters exposed in mixer
    device.display_name = "*LFO"
    device.is_maximized = true
    device.is_active = true
    device.external_editor_visible = false
    break
  end
end
-- Configure device 2: *LFO (*LFO (2))
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_002" then
    print("DEBUG: Found placeholder PAKETTI_PLACEHOLDER_002 at device index " .. i .. ", configuring as *LFO (2)")
    device.parameters[4].show_in_mixer = true
    device.display_name = "*LFO (2)"
    device.is_maximized = true
    device.is_active = true
    -- LFO devices don't have external editors, skip this
    break
  end
end
-- Configure device 3: Maximizer (Maximizer)
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_003" then
    print("DEBUG: Found placeholder PAKETTI_PLACEHOLDER_003 at device index " .. i .. ", configuring as Maximizer")
    device.parameters[1].show_in_mixer = true
    device.parameters[5].show_in_mixer = true
    device.display_name = "Maximizer"
    device.is_maximized = true
    device.is_active = true
    -- External editor not available
    break
  end
end
-- PHASE 3: XML Injection (FINAL)
-- Inject XML for device 1: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_001" then
    print("DEBUG: Injecting XML for PAKETTI_PLACEHOLDER_001 -> *LFO")
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
    break
  end
end
-- Inject XML for device 2: *LFO
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_002" then
    print("DEBUG: Injecting XML for PAKETTI_PLACEHOLDER_002 -> *LFO (2)")
    device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>0.371529877</Value>
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
    break
  end
end
-- Inject XML for device 3: Maximizer
for i, device in ipairs(renoise.song().selected_track.devices) do
  if device.display_name == "PAKETTI_PLACEHOLDER_003" then
    print("DEBUG: Injecting XML for PAKETTI_PLACEHOLDER_003 -> Maximizer")
    device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="MaximizerDevice">
    <IsMaximized>true</IsMaximized>
    <InputGain>
      <Value>8.52731228</Value>
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
    break
  end
end
-- TRACK DEVICE CHAIN RECREATION COMPLETE
-- Total devices processed: 3
-- EXPECTED FINAL DEVICE ORDER:
-- Device 1: *LFO (*LFO)
-- Device 2: *LFO (*LFO (2))
-- Device 3: Maximizer (Maximizer)
-- ⚠️  IMPORTANT LIMITATION NOTICE ⚠️
-- This script recreates device presets but NOT parameter routing/connections.
-- If your original chain had LFO→Device parameter routing, you'll need to:
-- 1. Look for *Hydra devices (parameter routing)
-- 2. Check for *Instr. Macros connections
-- 3. Manually reconnect LFO outputs to target device inputs
-- 4. Check pattern automation that may link parameters
-- ? ROUTING LIKELY MISSING: Found LFO devices but no routing devices!
-- Your original chain probably used parameter connections not captured here.
end

heyYo()

