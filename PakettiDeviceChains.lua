function PakettiRandomDeviceChain(path)
  local files={}
  for file in io.popen('ls "'..path..'"'):lines() do
    if file:match("%.xrnt$") or file:match("%.xrdp$") then
      table.insert(files,file)
    end
  end

  if #files==0 then
    renoise.app():show_status("No device chains or presets found in the specified folder.")
    return
  end

  local random_index=math.random(1,#files)
  local random_file=path..files[random_index]

  renoise.song():insert_track_at(renoise.song().selected_track_index+1)
  renoise.song().selected_track_index=renoise.song().selected_track_index+1

  if random_file:match("%.xrnt$") then
    renoise.app():load_track_device_chain(random_file)
  elseif random_file:match("%.xrdp$") then
    renoise.app():load_track_device_preset(random_file)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Create New Track&Load Random Device Chain/Preset",invoke=function() PakettiRandomDeviceChain(preferences.PakettiDeviceChainPath.value) end}

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain EQ10 Macro Experimental",invoke=function()
PakettiLoadDeviceChain("DeviceChains/eq10macrotest.xrnt")
end}

function PakettiLoadDeviceChain(chainName) renoise.app():load_track_device_chain(chainName) end
function PakettiLoadDevicePreset(chainName) renoise.app():load_track_device_preset(chainName) end

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain SimpleSend",invoke=function()
PakettiLoadDeviceChain("DeviceChains/SimpleSendMidi.xrnt") end}

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Paketti Doofer Rudiments",invoke=function()
PakettiLoadDeviceChain("DeviceChains/PakettiDooferRudiments.xrnt") end}

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain ClippyClip",invoke=function()
PakettiLoadDevicePreset("DeviceChains/ClippyClip.xrdp")
for i=2,#renoise.song().selected_track.devices do
if renoise.song().selected_track.devices[i].parameters[1].name == "In"
and renoise.song().selected_track.devices[i].parameters[2].name == "Ceiling"
and renoise.song().selected_track.devices[i].parameters[3].name == "8x ovrsmpl"
and renoise.song().selected_track.devices[i].parameters[4].name == "Dry/Wet"
and renoise.song().selected_track.devices[i].parameters[5].name == "Out"
then renoise.song().selected_track.devices[i].display_name="ClippyClip"
end end end}

function PakettiLoadDeviceChain(chainName)
renoise.app():load_track_device_chain(chainName)
end

function PakettiLoadDevicePreset(chainName)
renoise.app():load_track_device_preset(chainName) 
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Track Compressor (NPC1)",invoke=function()
PakettiLoadDevicePreset("DeviceChains/Track Compressor (NPC1).xrdp") end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Low - High Cut (steep) (NPC1)",invoke=function()
PakettiLoadDevicePreset("DeviceChains/Low - High Cut (steep) (NPC1).xrdp") end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Low - High Cut (halfsteep) (NPC1)",invoke=function()
PakettiLoadDevicePreset("DeviceChains/Low - High Cut (halfsteep) (NPC1).xrdp") end}
renoise.tool():add_keybinding{name="Global:Paketti:Load Device Chain Low - High Cut (flat) (NPC1)",invoke=function()
PakettiLoadDevicePreset("DeviceChains/Low - High Cut (flat) (NPC1).xrdp") end}
