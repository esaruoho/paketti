-- REPORT-CARD >> features/master-bandpass.feature
-- Paketti Master Bandpass: master-track audition filter inspired by
-- ledger.scripts.MasterBandpass_V0.54, pakettified with richer control.

local PAKETTI_MASTER_BANDPASS_TAG = "Paketti Master Bandpass"
local PAKETTI_MASTER_BANDPASS_DEFAULT_MODEL = "Butterworth 4n"
local PAKETTI_MASTER_BANDPASS_DEFAULT_CUTOFF = 50.4000015
local PAKETTI_MASTER_BANDPASS_DEFAULT_Q = 16.0000000
local PAKETTI_MASTER_BANDPASS_DEFAULT_GAIN = 41.5999565

local paketti_master_bandpass_dialog = nil
local paketti_master_bandpass_vb = nil
local paketti_master_bandpass_device = nil
local paketti_master_bandpass_model = PAKETTI_MASTER_BANDPASS_DEFAULT_MODEL

local paketti_master_bandpass_presets = {
  {name = "Butterworth", model = "Butterworth 4n", cutoff = 50.4000015, q = 16.0000000, gain = 41.5999565},
  {name = "Chebyshev", model = "Chebyshev 4n", cutoff = 50.0000000, q = 39.5999985, gain = 41.5999565},
  {name = "Tight Focus", model = "Butterworth 8n", cutoff = 50.4000015, q = 28.0000000, gain = 41.5999565},
  {name = "Gentle Sweep", model = "Butterworth 2n", cutoff = 50.4000015, q = 10.0000000, gain = 50.0000000},
}

local function paketti_master_bandpass_status(message)
  renoise.app():show_status("Paketti Master Bandpass: " .. message)
end

local function paketti_master_bandpass_master_track()
  local song = renoise.song()
  if not song then return nil end
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_MASTER then
      return song.tracks[i], i
    end
  end
  return nil
end

local function paketti_master_bandpass_find(master)
  if not master then master = paketti_master_bandpass_master_track() end
  if not master then return nil, nil end
  for i = 2, #master.devices do
    local dev = master.devices[i]
    if dev.device_path == "Audio/Effects/Native/Doofer" and dev.display_name == PAKETTI_MASTER_BANDPASS_TAG then
      paketti_master_bandpass_device = dev
      return dev, i
    end
  end
  return nil, nil
end

local function paketti_master_bandpass_preset_xml(model, cutoff, q, gain)
  model = model or PAKETTI_MASTER_BANDPASS_DEFAULT_MODEL
  cutoff = cutoff or PAKETTI_MASTER_BANDPASS_DEFAULT_CUTOFF
  q = q or PAKETTI_MASTER_BANDPASS_DEFAULT_Q
  gain = gain or PAKETTI_MASTER_BANDPASS_DEFAULT_GAIN

  local cutoff_inner = cutoff / 100
  local q_inner = q / 200
  local gain_inner = gain / 25

  return string.format([=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="DooferDevice">
    <IsMaximized>true</IsMaximized>
    <Macro0>
      <Value>%.7f</Value>
      <Name>Cutoff</Name>
      <Mappings>
        <Mapping>
          <DestChainIndex>0</DestChainIndex>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>2</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro0>
    <Macro1>
      <Value>%.7f</Value>
      <Name>Q</Name>
      <Mappings>
        <Mapping>
          <DestChainIndex>0</DestChainIndex>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>3</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro1>
    <Macro2>
      <Value>%.7f</Value>
      <Name>Gain</Name>
      <Mappings>
        <Mapping>
          <DestChainIndex>0</DestChainIndex>
          <DestDeviceIndex>1</DestDeviceIndex>
          <DestParameterIndex>1</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro2>
    <Macro3><Value>50</Value><Name>Macro 4</Name></Macro3>
    <Macro4><Value>50</Value><Name>Macro 5</Name></Macro4>
    <Macro5><Value>50</Value><Name>Macro 6</Name></Macro5>
    <Macro6><Value>50</Value><Name>Macro 7</Name></Macro6>
    <Macro7><Value>50</Value><Name>Macro 8</Name></Macro7>
    <NumActiveMacros>3</NumActiveMacros>
    <ShowDevices>true</ShowDevices>
    <DeviceChain>
      <SelectedPresetName>Init</SelectedPresetName>
      <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
      <SelectedPresetIsModified>true</SelectedPresetIsModified>
      <Devices>
        <DigitalFilterDevice type="DigitalFilterDevice">
          <SelectedPresetName>Init</SelectedPresetName>
          <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <IsMaximized>true</IsMaximized>
          <IsSelected>true</IsSelected>
          <IsActive><Value>1.0</Value><Visualization>Device only</Visualization></IsActive>
          <OversamplingFactor>2x</OversamplingFactor>
          <Model>%s</Model>
          <Type><Value>1.0</Value><Visualization>Device only</Visualization></Type>
          <Cutoff><Value>%.9f</Value><Visualization>Device only</Visualization></Cutoff>
          <Q><Value>%.9f</Value><Visualization>Device only</Visualization></Q>
          <Ripple><Value>0.0</Value><Visualization>Device only</Visualization></Ripple>
          <Inertia><Value>0.0078125</Value><Visualization>Device only</Visualization></Inertia>
          <ShowResponseView>true</ShowResponseView>
          <ResponseViewMaxGain>18</ResponseViewMaxGain>
        </DigitalFilterDevice>
        <GainerDevice type="GainerDevice">
          <SelectedPresetName>Init</SelectedPresetName>
          <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <IsMaximized>false</IsMaximized>
          <IsSelected>false</IsSelected>
          <IsActive><Value>1.0</Value><Visualization>Device only</Visualization></IsActive>
          <Volume><Value>%.9f</Value><Visualization>Mixer and Device</Visualization></Volume>
          <Panning><Value>0.5</Value><Visualization>Device only</Visualization></Panning>
          <LPhaseInvert>false</LPhaseInvert>
          <RPhaseInvert>false</RPhaseInvert>
          <SmoothParameterChanges>true</SmoothParameterChanges>
        </GainerDevice>
      </Devices>
    </DeviceChain>
  </DeviceSlot>
</FilterDevicePreset>
]=], cutoff, q, gain, model, cutoff_inner, q_inner, gain_inner)
end

local function paketti_master_bandpass_param(dev, wanted_name, fallback_index)
  if not dev then return nil end
  local wanted = wanted_name:lower()
  for i = 1, #dev.parameters do
    local p = dev.parameters[i]
    if (p.name or ""):lower() == wanted then return p end
  end
  return dev.parameters[fallback_index]
end

local function paketti_master_bandpass_update_labels()
  if not paketti_master_bandpass_vb then return end
  local dev = paketti_master_bandpass_find()
  if not dev then return end
  local cutoff = paketti_master_bandpass_param(dev, "Cutoff", 1)
  local q = paketti_master_bandpass_param(dev, "Q", 2)
  local gain = paketti_master_bandpass_param(dev, "Gain", 3)
  if paketti_master_bandpass_vb.views.bandpass_active then
    paketti_master_bandpass_vb.views.bandpass_active.value = dev.is_active
  end
  if paketti_master_bandpass_vb.views.bandpass_cutoff_value and cutoff then
    paketti_master_bandpass_vb.views.bandpass_cutoff_value.text = cutoff.value_string or string.format("%.2f", cutoff.value)
  end
  if paketti_master_bandpass_vb.views.bandpass_q_value and q then
    paketti_master_bandpass_vb.views.bandpass_q_value.text = q.value_string or string.format("%.2f", q.value)
  end
  if paketti_master_bandpass_vb.views.bandpass_gain_value and gain then
    paketti_master_bandpass_vb.views.bandpass_gain_value.text = gain.value_string or string.format("%.2f", gain.value)
  end
end

local function paketti_master_bandpass_apply_preset(dev, preset)
  if not dev or not preset then return end
  local cutoff = paketti_master_bandpass_param(dev, "Cutoff", 1)
  local q = paketti_master_bandpass_param(dev, "Q", 2)
  local gain = paketti_master_bandpass_param(dev, "Gain", 3)
  local cutoff_value = cutoff and cutoff.value or preset.cutoff
  local q_value = q and q.value or preset.q
  local gain_value = gain and gain.value or preset.gain

  paketti_master_bandpass_model = preset.model
  dev.active_preset_data = paketti_master_bandpass_preset_xml(preset.model, cutoff_value, q_value, gain_value)
  dev.display_name = PAKETTI_MASTER_BANDPASS_TAG
  dev.is_active = true

  cutoff = paketti_master_bandpass_param(dev, "Cutoff", 1)
  q = paketti_master_bandpass_param(dev, "Q", 2)
  gain = paketti_master_bandpass_param(dev, "Gain", 3)
  if cutoff then cutoff.value = cutoff_value end
  if q then q.value = q_value end
  if gain then gain.value = gain_value end
  paketti_master_bandpass_update_labels()
end

function PakettiMasterBandpassEnsure()
  if PAKETTI_API < 6.1 then
    paketti_master_bandpass_status("requires Renoise API 6.1 or newer")
    return nil
  end

  local master = paketti_master_bandpass_master_track()
  if not master then
    paketti_master_bandpass_status("no master track found")
    return nil
  end

  local dev = paketti_master_bandpass_find(master)
  if dev then return dev end

  local ok, err = pcall(function()
    paketti_master_bandpass_device = master:insert_device_at("Audio/Effects/Native/Doofer", #master.devices + 1)
  end)
  if not ok or not paketti_master_bandpass_device then
    paketti_master_bandpass_status("could not insert Doofer - " .. tostring(err))
    return nil
  end

  paketti_master_bandpass_device.active_preset_data =
    paketti_master_bandpass_preset_xml(PAKETTI_MASTER_BANDPASS_DEFAULT_MODEL,
      PAKETTI_MASTER_BANDPASS_DEFAULT_CUTOFF,
      PAKETTI_MASTER_BANDPASS_DEFAULT_Q,
      PAKETTI_MASTER_BANDPASS_DEFAULT_GAIN)
  paketti_master_bandpass_device.display_name = PAKETTI_MASTER_BANDPASS_TAG
  paketti_master_bandpass_device.is_active = true
  return paketti_master_bandpass_device
end

function PakettiMasterBandpassSetActive(active)
  local dev = PakettiMasterBandpassEnsure()
  if not dev then return end
  dev.is_active = active and true or false
  paketti_master_bandpass_status(dev.is_active and "ON" or "OFF")
  paketti_master_bandpass_update_labels()
end

function PakettiMasterBandpassToggleActive()
  local existing = paketti_master_bandpass_find()
  local dev = existing or PakettiMasterBandpassEnsure()
  if not dev then return end
  if not existing then
    dev.is_active = true
    paketti_master_bandpass_status("ON")
    paketti_master_bandpass_update_labels()
    return
  end
  PakettiMasterBandpassSetActive(not dev.is_active)
end

function PakettiMasterBandpassMomentary(message)
  local on
  if message:is_switch() then
    on = message.boolean_value
  elseif message:is_abs_value() then
    on = (message.int_value or 0) > 0
  elseif message:is_trigger() then
    on = true
  else
    return
  end
  PakettiMasterBandpassSetActive(on)
end

function PakettiMasterBandpassFocusDevice()
  local master, master_index = paketti_master_bandpass_master_track()
  local dev, device_index = paketti_master_bandpass_find(master)
  if not dev then dev = PakettiMasterBandpassEnsure() end
  if not dev then return end
  if not device_index then
    dev, device_index = paketti_master_bandpass_find(master)
  end
  if master_index and device_index then
    renoise.song().selected_track_index = master_index
    renoise.song().selected_device_index = device_index
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
  end
end

local function paketti_master_bandpass_close_dialog()
  if paketti_master_bandpass_dialog and paketti_master_bandpass_dialog.visible then
    paketti_master_bandpass_dialog:close()
  end
  paketti_master_bandpass_dialog = nil
  paketti_master_bandpass_vb = nil
end

local function paketti_master_bandpass_timer()
  if not paketti_master_bandpass_dialog or not paketti_master_bandpass_dialog.visible then
    if renoise.tool():has_timer(paketti_master_bandpass_timer) then
      renoise.tool():remove_timer(paketti_master_bandpass_timer)
    end
    local dev = paketti_master_bandpass_find()
    if dev then dev.is_active = false end
    paketti_master_bandpass_dialog = nil
    paketti_master_bandpass_vb = nil
    return
  end
  paketti_master_bandpass_update_labels()
end

local function paketti_master_bandpass_keyhandler(dialog, key)
  renoise.app().window.lock_keyboard_focus = not renoise.app().window.lock_keyboard_focus
  renoise.app().window.lock_keyboard_focus = not renoise.app().window.lock_keyboard_focus
  return key
end

function PakettiMasterBandpassShowDialog()
  local dev = PakettiMasterBandpassEnsure()
  if not dev then return end

  if paketti_master_bandpass_dialog and paketti_master_bandpass_dialog.visible then
    paketti_master_bandpass_dialog:close()
    paketti_master_bandpass_dialog = nil
    paketti_master_bandpass_vb = nil
  end

  local vb = renoise.ViewBuilder()
  paketti_master_bandpass_vb = vb

  local cutoff = paketti_master_bandpass_param(dev, "Cutoff", 1)
  local q = paketti_master_bandpass_param(dev, "Q", 2)
  local gain = paketti_master_bandpass_param(dev, "Gain", 3)
  if not cutoff or not q or not gain then
    paketti_master_bandpass_status("expected Cutoff, Q, and Gain macros were not available")
    return
  end
  local preset_names = {}
  local selected_preset = 1
  for i, preset in ipairs(paketti_master_bandpass_presets) do
    preset_names[i] = preset.name
    if preset.model == paketti_master_bandpass_model then selected_preset = i end
  end

  local function macro_rotary(id, label, param)
    return vb:column{
      width = 96,
      vb:text{text = label, width = 96, align = "center"},
      vb:rotary{
        id = id,
        width = 64,
        height = 64,
        min = param.value_min,
        max = param.value_max,
        value = param.value,
        notifier = function(value)
          local current = PakettiMasterBandpassEnsure()
          if not current then return end
          local p = paketti_master_bandpass_param(current, label, id == "bandpass_cutoff" and 1 or id == "bandpass_q" and 2 or 3)
          if p then p.value = value end
          current.is_active = true
          paketti_master_bandpass_update_labels()
        end
      },
      vb:text{id = id .. "_value", text = param.value_string or "", width = 96, align = "center"}
    }
  end

  local content = vb:column{
    margin = 8,
    spacing = 6,
    vb:row{
      spacing = 8,
      vb:checkbox{
        id = "bandpass_active",
        value = dev.is_active,
        notifier = function(value) PakettiMasterBandpassSetActive(value) end
      },
      vb:text{text = "Active", width = 50},
      vb:popup{
        id = "bandpass_preset",
        width = 132,
        items = preset_names,
        value = selected_preset,
        notifier = function(index)
          local current = PakettiMasterBandpassEnsure()
          if current then paketti_master_bandpass_apply_preset(current, paketti_master_bandpass_presets[index]) end
        end
      },
      vb:button{
        text = "Reset",
        width = 58,
        notifier = function()
          local index = vb.views.bandpass_preset.value
          local current = PakettiMasterBandpassEnsure()
          if current then
            local preset = paketti_master_bandpass_presets[index]
            current.active_preset_data = paketti_master_bandpass_preset_xml(preset.model, preset.cutoff, preset.q, preset.gain)
            current.display_name = PAKETTI_MASTER_BANDPASS_TAG
            current.is_active = true
            paketti_master_bandpass_model = preset.model
            paketti_master_bandpass_update_labels()
          end
        end
      }
    },
    vb:row{
      spacing = 8,
      macro_rotary("bandpass_cutoff", "Cutoff", cutoff),
      macro_rotary("bandpass_q", "Q", q),
      macro_rotary("bandpass_gain", "Gain", gain)
    },
    vb:row{
      spacing = 8,
      vb:button{text = "View Device", width = 104, notifier = PakettiMasterBandpassFocusDevice},
      vb:button{text = "Close", width = 68, notifier = paketti_master_bandpass_close_dialog}
    }
  }

  paketti_master_bandpass_dialog = renoise.app():show_custom_dialog(
    "Paketti Master Bandpass", content, paketti_master_bandpass_keyhandler)

  if not renoise.tool():has_timer(paketti_master_bandpass_timer) then
    renoise.tool():add_timer(paketti_master_bandpass_timer, 120)
  end
  paketti_master_bandpass_update_labels()
end

function PakettiMasterBandpassToggleDialog()
  if paketti_master_bandpass_dialog and paketti_master_bandpass_dialog.visible then
    paketti_master_bandpass_close_dialog()
  else
    PakettiMasterBandpassShowDialog()
  end
end

renoise.tool():add_keybinding{
  name = "Global:Paketti:Master Bandpass Dialog...",
  invoke = PakettiMasterBandpassToggleDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Master Bandpass Toggle Active",
  invoke = PakettiMasterBandpassToggleActive
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Master Bandpass View Device",
  invoke = PakettiMasterBandpassFocusDevice
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Master Bandpass Toggle Active",
  invoke = function(message) if message:is_trigger() then PakettiMasterBandpassToggleActive() end end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Master Bandpass Hold Active",
  invoke = function(message) PakettiMasterBandpassMomentary(message) end
}

if preferences.pakettiMenuConfig.MainMenuTools.value then
  renoise.tool():add_menu_entry{
    name = "Main Menu:Tools:Paketti:Master Bandpass Dialog...",
    invoke = PakettiMasterBandpassToggleDialog
  }
  renoise.tool():add_menu_entry{
    name = "Main Menu:Tools:Paketti:Master Bandpass Toggle Active",
    invoke = PakettiMasterBandpassToggleActive
  }
  renoise.tool():add_menu_entry{
    name = "Main Menu:Tools:Paketti:Master Bandpass View Device",
    invoke = PakettiMasterBandpassFocusDevice
  }
end
