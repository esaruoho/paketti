-- Blacklist of device chain presets that contain v2 DSP devices (API 6.1+ / Renoise 3.3+)
-- These use DigitalFilterDevice or Distortion2Device which don't exist on Renoise 3.2
local v2_only_preset_files = {
  ["ClippyClip.xrdp"] = true,
  ["ClippyClip_.xrdp"] = true,
  ["ClippyClip.xrnt"] = true,
  ["hipass_lopass_dcoffset.xrnt"] = true,
  ["Low - High Cut (flat) (NPC1).xrdp"] = true,
  ["Low - High Cut (halfsteep) (NPC1).xrdp"] = true,
  ["Low - High Cut (steep) (NPC1).xrdp"] = true,
}

function PakettiRandomDeviceChain(path)
  local files = {}
  for file in io.popen('ls "' .. path .. '"'):lines() do
    if file:match("%.xrnt$") or file:match("%.xrdp$") then
      -- On API < 6.1, skip presets containing v2 devices
      if renoise.API_VERSION >= 6.1 or not v2_only_preset_files[file] then
        table.insert(files, file)
      end
    end
  end

  if #files == 0 then
    renoise.app():show_status("No compatible device chains or presets found in the specified folder.")
    return
  end

  local random_index = math.random(1, #files)
  local random_file = path .. files[random_index]

  renoise.song():insert_track_at(renoise.song().selected_track_index + 1)
  renoise.song().selected_track_index = renoise.song().selected_track_index + 1

  local success, err
  if random_file:match("%.xrnt$") then
    success, err = pcall(function() renoise.app():load_track_device_chain(random_file) end)
  elseif random_file:match("%.xrdp$") then
    success, err = pcall(function() renoise.app():load_track_device_preset(random_file) end)
  end

  if success then
    local filename = random_file:match("[^/\\]+$") or random_file
    renoise.app():show_status("Loaded: " .. filename)
  else
    renoise.app():show_status("Failed to load device chain: " .. tostring(err))
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Create New Track&Load Random Device Chain/Preset",invoke=function() PakettiRandomDeviceChain(preferences.PakettiDeviceChainPath.value) end}

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain EQ10 Macro Experimental",invoke=function()
  PakettiLoadDeviceChain("DeviceChains/eq10macrotest.xrnt")
end}

function PakettiLoadDeviceChain(chainName)
  renoise.app():load_track_device_chain(chainName)
end

function PakettiLoadDevicePreset(chainName)
  renoise.app():load_track_device_preset(chainName)
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain SimpleSend",invoke=function()
  PakettiLoadDeviceChain("DeviceChains/SimpleSendMidi.xrnt")
end}

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Paketti Doofer Rudiments",invoke=function()
  PakettiLoadDeviceChain("DeviceChains/PakettiDooferRudiments.xrnt")
end}

-- ClippyClip uses Distortion2Device (API 6.1+ / Renoise 3.3+)
if renoise.API_VERSION >= 6.1 then
  renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain ClippyClip",invoke=function()
    PakettiLoadDevicePreset("DeviceChains/ClippyClip.xrdp")
    for i = 2, #renoise.song().selected_track.devices do
      if renoise.song().selected_track.devices[i].parameters[1].name == "In"
      and renoise.song().selected_track.devices[i].parameters[2].name == "Ceiling"
      and renoise.song().selected_track.devices[i].parameters[3].name == "8x ovrsmpl"
      and renoise.song().selected_track.devices[i].parameters[4].name == "Dry/Wet"
      and renoise.song().selected_track.devices[i].parameters[5].name == "Out"
      then renoise.song().selected_track.devices[i].display_name = "ClippyClip"
      end
    end
  end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Track Compressor (NPC1)",invoke=function()
  PakettiLoadDevicePreset("DeviceChains/Track Compressor (NPC1).xrdp")
end}

-- Low - High Cut presets use DigitalFilterDevice (API 6.1+ / Renoise 3.3+)
if renoise.API_VERSION >= 6.1 then
  renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Low - High Cut (steep) (NPC1)",invoke=function()
    PakettiLoadDevicePreset("DeviceChains/Low - High Cut (steep) (NPC1).xrdp")
  end}
  renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Low - High Cut (halfsteep) (NPC1)",invoke=function()
    PakettiLoadDevicePreset("DeviceChains/Low - High Cut (halfsteep) (NPC1).xrdp")
  end}
  renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Low - High Cut (flat) (NPC1)",invoke=function()
    PakettiLoadDevicePreset("DeviceChains/Low - High Cut (flat) (NPC1).xrdp")
  end}
end
