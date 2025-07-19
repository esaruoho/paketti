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

--HipassPlusPlus()