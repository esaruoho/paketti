function tknaSelectedTrackVolume0to1Toggle(number)
  renoise.song().tracks[renoise.song().selected_track_index].postfx_volume.value=number
  end
  

  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Volume to -INF dB",invoke=function() tknaSelectedTrackVolume0to1Toggle(0) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Volume to 0.0dB",invoke=function() tknaSelectedTrackVolume0to1Toggle(1) end}
  
  function tknaMasterTrackVolume0to1Toggle(number)
  local masterTrackIndex=renoise.song().sequencer_track_count+1
  renoise.song().tracks[masterTrackIndex].postfx_volume.value=number
  end
  
  renoise.tool():add_keybinding{name="Global:Paketti:Set Master Track Volume to -INF dB",invoke=function() tknaMasterTrackVolume0to1Toggle(0) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Set Master Track Volume to 0.0dB",invoke=function() tknaMasterTrackVolume0to1Toggle(1) end}
  -------------

  -----
  function tknaChangeMasterTrackVolumeBy(dB_change)
    local masterTrackIndex=renoise.song().sequencer_track_count+1
    local masterTrack=renoise.song().tracks[masterTrackIndex]
    local currentVolumeString=masterTrack.postfx_volume.value_string
    local currentVolumeValue=masterTrack.postfx_volume.value
  
    -- Debug: Current state
    print("-----")
    print("Starting with dB change: "..dB_change.." dB")
    print("Current Volume String: "..currentVolumeString)
    print("Current Volume Value: "..currentVolumeValue)
  
    -- Extract the numeric value from the value_string
    local currentdB=tonumber(currentVolumeString:match("[-]?%d+%.?%d*")) or -200
  
    -- Debug: Extracted current dB
    print("Current dB: "..currentdB)
  
    -- Handle the case where the volume is at -INF
    if currentVolumeString=="-INF dB" then
      if dB_change>0 then
        currentdB=-48 -- Jump to -48dB when increasing from -INF
        print("New dB set to: "..currentdB.." because current volume is at -INF and change is positive")
      else
        renoise.app():show_status("Master Track Volume is already at -INF, cannot go lower.")
        return
      end
    end
  
    local newdB=currentdB+dB_change
    print("New dB after change: "..newdB)
  
    -- Correctly handle the transitions
    if newdB>3 then
      newdB=3
      renoise.app():show_status("Master Track Volume is already at 3.0dB, cannot go higher.")
    elseif newdB>=2.9 and newdB<3 and currentdB<2.9 then
      newdB=math.floor((currentdB+dB_change)*100+0.5)/100
    elseif newdB==3.0 and dB_change<0 then
      newdB=math.floor((currentdB+dB_change)*100+0.5)/100
    elseif newdB<=-48 and dB_change<0 then
      newdB=-200 -- Transition to -INF
    elseif newdB<=-47.9 and newdB>-48.1 and dB_change>0 then
      newdB=math.floor((currentdB+dB_change)*100+0.5)/100
    end
  
    newdB=math.floor(newdB*100+0.5)/100 -- Reduce to 2 decimals
    local newVolumeString
    if newdB<=-200 then
      newVolumeString="-INF dB"
    else
      newVolumeString=string.format("%.2f dB", newdB)
    end
  
    -- Debug: What we are going to do
    print("Setting New Volume String: "..newVolumeString)
    print("Setting New Volume Value: "..newdB)
  
    masterTrack.postfx_volume.value_string=newVolumeString
  
    -- Debug: New state
    print("New Volume String: "..masterTrack.postfx_volume.value_string)
    print("New Volume Value: "..masterTrack.postfx_volume.value)
  
    renoise.app():show_status("Master Track Volume: "..masterTrack.postfx_volume.value_string)
  end
  
  renoise.tool():add_keybinding{name="Global:Paketti:Change Master Track Volume by +0.1dB",invoke=function() tknaChangeMasterTrackVolumeBy(0.1) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Change Master Track Volume by -0.1dB",invoke=function() tknaChangeMasterTrackVolumeBy(-0.1) end}

  ---
  


function tknaMidiSelectedTrackOutputRoutings(midi_value)
  local track=renoise.song().selected_track
  local routings=#track.available_output_routings
  local output=math.floor((midi_value/127)*routings)+1
  if output<=routings then
    track.output_routing=track.available_output_routings[output]
    renoise.app():show_status("Selected Track Output Routing set to "..output)
  else
    renoise.app():show_status("Selected Track Output Routing value out of range.")
  end
end

function tknaMidiMasterOutputRoutings(midi_value)
  local song=renoise.song()
  local masterTrack=song:track(song.sequencer_track_count+1)
  local routings=#masterTrack.available_output_routings
  local output=math.floor((midi_value/127)*routings)+1
  if output<=routings then
    masterTrack.output_routing=masterTrack.available_output_routings[output]
    renoise.app():show_status("Master Track Output Routing set to "..output)
  else
    renoise.app():show_status("Master Track Output Routing value out of range.")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Midi Change Selected Track Output Routings",
  invoke=function(midi_message)
    local midi_value=midi_message.int_value
    tknaMidiSelectedTrackOutputRoutings(midi_value)
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Midi Change Master Output Routings",
  invoke=function(midi_message)
    local midi_value=midi_message.int_value
    tknaMidiMasterOutputRoutings(midi_value)
  end
}

-- Cycle Selected Track Output Routing +1/-1
function cycleSelectedTrackOutputRouting(direction)
  local track = renoise.song().selected_track
  local available_routings = track.available_output_routings
  local total_routings = #available_routings
  
  -- Check if there's only one routing available
  if total_routings <= 1 then
    renoise.app():show_status("There are no channels to move to")
    return
  end
  
  -- Find current routing index
  local current_index = 1
  for i = 1, total_routings do
    if available_routings[i] == track.output_routing then
      current_index = i
      break
    end
  end
  
  -- Calculate new index with wrapping
  local new_index = current_index + direction
  if new_index > total_routings then
    new_index = 1  -- Wrap to first
  elseif new_index < 1 then
    new_index = total_routings  -- Wrap to last
  end
  
  -- Set new routing
  track.output_routing = available_routings[new_index]
  renoise.app():show_status("Selected Track Output: " .. available_routings[new_index] .. " (" .. new_index .. "/" .. total_routings .. ")")
end

-- Cycle Master Track Output Routing +1/-1
function cycleMasterTrackOutputRouting(direction)
  local song = renoise.song()
  local master_track = song:track(song.sequencer_track_count + 1)
  local available_routings = master_track.available_output_routings
  local total_routings = #available_routings
  
  -- Check if there's only one routing available
  if total_routings <= 1 then
    renoise.app():show_status("There are no channels to move to")
    return
  end
  
  -- Find current routing index
  local current_index = 1
  for i = 1, total_routings do
    if available_routings[i] == master_track.output_routing then
      current_index = i
      break
    end
  end
  
  -- Calculate new index with wrapping
  local new_index = current_index + direction
  if new_index > total_routings then
    new_index = 1  -- Wrap to first
  elseif new_index < 1 then
    new_index = total_routings  -- Wrap to last
  end
  
  -- Set new routing
  master_track.output_routing = available_routings[new_index]
  renoise.app():show_status("Master Track Output: " .. available_routings[new_index] .. " (" .. new_index .. "/" .. total_routings .. ")")
end


renoise.tool():add_keybinding{name="Global:Paketti:Selected Track Output Routing +1", invoke=function() cycleSelectedTrackOutputRouting(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Track Output Routing -1", invoke=function() cycleSelectedTrackOutputRouting(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Master Track Output Routing +1", invoke=function() cycleMasterTrackOutputRouting(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Master Track Output Routing -1", invoke=function() cycleMasterTrackOutputRouting(-1) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Track Output Routing +1 x[Trigger]", invoke=function(message) if message:is_trigger() then cycleSelectedTrackOutputRouting(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Track Output Routing -1 x[Trigger]", invoke=function(message) if message:is_trigger() then cycleSelectedTrackOutputRouting(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Master Track Output Routing +1 x[Trigger]", invoke=function(message) if message:is_trigger() then cycleMasterTrackOutputRouting(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Master Track Output Routing -1 x[Trigger]", invoke=function(message) if message:is_trigger() then cycleMasterTrackOutputRouting(-1) end end}


--

-- All of these have been requested by tkna91 via GitHub or Discord
function loopReleaseToggle()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
if renoise.song().selected_sample.loop_release
then renoise.song().selected_sample.loop_release=false 
else renoise.song().selected_sample.loop_release=true end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop Release On/Off",invoke=function() loopReleaseToggle() end}

function oneShotToggle()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
if renoise.song().selected_sample.oneshot 
then renoise.song().selected_sample.oneshot=false 
else renoise.song().selected_sample.oneshot=true end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample One-Shot On/Off",invoke=function() oneShotToggle() end}

function selectedSampleLoopSet(number)
  if renoise.song().selected_sample ~= nil then 
renoise.song().selected_sample.oneshot=false
local loop_modet = renoise.song().selected_sample.loop_mode
  if renoise.song().selected_sample.loop_mode==number then renoise.song().selected_sample.loop_mode=1 else loop_modet = number
  renoise.song().selected_sample.loop_mode=loop_modet
  end
else renoise.app():show_status("No sample selected, doing nothing.")
end
end
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 1 (Off)",invoke=function() selectedSampleLoopSet(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 2 (Forward)",invoke=function() selectedSampleLoopSet(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 3 (Backward)",invoke=function() selectedSampleLoopSet(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 4 (PingPong)",invoke=function() selectedSampleLoopSet(4) end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Selected Sample Loop 1 (Off)",invoke=function() selectedSampleLoopSet(1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Selected Sample Loop 2 (Forward)",invoke=function() selectedSampleLoopSet(2) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Selected Sample Loop 3 (Backward)",invoke=function() selectedSampleLoopSet(3) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set Selected Sample Loop 4 (PingPong)",invoke=function() selectedSampleLoopSet(4) end}



function selectedSampleTranspose(amount)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
local currentSampleTranspose = renoise.song().selected_sample.transpose
local changedSampleTranspose = currentSampleTranspose + amount
if changedSampleTranspose > 120 then changedSampleTranspose = 120
else if changedSampleTranspose < -120 then changedSampleTranspose = -120 end end
renoise.song().selected_sample.transpose=changedSampleTranspose
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (-1)",invoke=function() selectedSampleTranspose(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (+1)",invoke=function() selectedSampleTranspose(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (-12)",invoke=function() selectedSampleTranspose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (+12)",invoke=function() selectedSampleTranspose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample Transpose (0)",invoke=function() 
  if not renoise.song().selected_sample then 
    renoise.app():show_status("No sample selected, doing nothing.")
    return 
  end
  renoise.song().selected_sample.transpose=0 
end}

function selectedSampleFinetune(amount)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
local currentSampleFinetune = renoise.song().selected_sample.fine_tune
local changedSampleFinetune = currentSampleFinetune + amount
if changedSampleFinetune > 127 then changedSampleFinetune = 127
else if changedSampleFinetune < -127 then changedSampleFinetune = -127 end end
renoise.song().selected_sample.fine_tune=changedSampleFinetune
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (-1)",invoke=function() selectedSampleFinetune(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (+1)",invoke=function() selectedSampleFinetune(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (-10)",invoke=function() selectedSampleFinetune(-10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (+10)",invoke=function() selectedSampleFinetune(10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (0)",invoke=function() 
  if not renoise.song().selected_sample then 
    renoise.app():show_status("No sample selected, doing nothing.")
    return 
  end
  renoise.song().selected_sample.fine_tune=0 
end}

function selectedSamplePanning(amount)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
local currentSamplePanning = renoise.song().selected_sample.panning
local changedSamplePanning = currentSamplePanning + amount
if changedSamplePanning > 1.0 then changedSamplePanning = 1.0
else if changedSamplePanning < 0.0 then changedSamplePanning = 0.0 end end
renoise.song().selected_sample.panning=changedSamplePanning
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning 0.5 (Center)",invoke=function() 
  if not renoise.song().selected_sample then 
    renoise.app():show_status("No sample selected, doing nothing.")
    return 
  end
  renoise.song().selected_sample.panning=0.5 
end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning 0.0 (Left)",invoke=function() 
  if not renoise.song().selected_sample then 
    renoise.app():show_status("No sample selected, doing nothing.")
    return 
  end
  renoise.song().selected_sample.panning=0.0 
end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning 1.0 (Right)",invoke=function() 
  if not renoise.song().selected_sample then 
    renoise.app():show_status("No sample selected, doing nothing.")
    return 
  end
  renoise.song().selected_sample.panning=1.0 
end}
 
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning (+0.01)",invoke=function() selectedSamplePanning(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning (-0.01)",invoke=function() selectedSamplePanning(-0.01) end}

function selectedSampleVolume(amount)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
local currentSampleVolume = renoise.song().selected_sample.volume
local changedSampleVolume = currentSampleVolume + amount
if changedSampleVolume > 4.0 then changedSampleVolume = 4.0
else if changedSampleVolume < 0.0 then changedSampleVolume = 0.0 end end
renoise.song().selected_sample.volume=changedSampleVolume
end
 
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume (+0.01)",invoke=function() selectedSampleVolume(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume (-0.01)",invoke=function() selectedSampleVolume(-0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume Reset (0.0dB)",invoke=function() 
  if not renoise.song().selected_sample then 
    renoise.app():show_status("No sample selected, doing nothing.")
    return 
  end
  renoise.song().selected_sample.volume=1 
end}

function selectedSampleInterpolation(amount)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
renoise.song().selected_sample.interpolation_mode=amount
end

function selectedSampleOversampleOn()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
renoise.song().selected_sample.oversample_enabled=true
end

function selectedSampleOversampleOff()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
renoise.song().selected_sample.oversample_enabled=false
end

function selectedSampleOversampleToggle()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
if renoise.song().selected_sample.oversample_enabled then
 renoise.song().selected_sample.oversample_enabled = false else
 renoise.song().selected_sample.oversample_enabled = true
end end

function selectedSampleAutoseekToggle()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
if renoise.song().selected_sample.autoseek then
 renoise.song().selected_sample.autoseek = false else
 renoise.song().selected_sample.autoseek = true
end end

function selectedSampleAutofadeToggle()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
if renoise.song().selected_sample.autofade then
 renoise.song().selected_sample.autofade = false else
 renoise.song().selected_sample.autofade = true
end end

function selectedSampleNNA(number)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
renoise.song().selected_sample.new_note_action = number
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 1 (None)",invoke=function() selectedSampleInterpolation(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 2 (Linear)",invoke=function() selectedSampleInterpolation(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 3 (Cubic)",invoke=function() selectedSampleInterpolation(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 4 (Sinc)",invoke=function() selectedSampleInterpolation(4) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Oversample On",invoke=function() selectedSampleOversampleOn() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Oversample Off",invoke=function() selectedSampleOversampleOff() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Oversample On/Off",invoke=function() selectedSampleOversampleToggle() end}

function selectedSampleBeatSync(number)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
renoise.song().selected_sample.beat_sync_mode = number
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync 1 (Repitch)",invoke=function() selectedSampleBeatSync(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync 2 (Time-Stretch Percussion)",invoke=function() selectedSampleBeatSync(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync 3 (Time-Stretch Texture)",invoke=function() selectedSampleBeatSync(3) end}

function selectedSampleBeatSyncAndToggleOn(number)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end

if renoise.song().selected_sample.beat_sync_enabled and renoise.song().selected_sample.beat_sync_mode ~= number then
renoise.song().selected_sample.beat_sync_mode = number
return end
renoise.song().selected_sample.beat_sync_mode = number


if renoise.song().selected_sample.beat_sync_enabled == false then
renoise.song().selected_sample.beat_sync_enabled = true
renoise.song().selected_sample.beat_sync_mode = number
else 
renoise.song().selected_sample.beat_sync_enabled = false
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off 1 (Repitch)",invoke=function() selectedSampleBeatSyncAndToggleOn(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off 2 (Time-Stretch Percussion)",invoke=function() selectedSampleBeatSyncAndToggleOn(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off 3 (Time-Stretch Texture)",invoke=function() selectedSampleBeatSyncAndToggleOn(3) end}


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off",invoke=function()
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end

if renoise.song().selected_sample.beat_sync_enabled then
 renoise.song().selected_sample.beat_sync_enabled = false else
 renoise.song().selected_sample.beat_sync_enabled = true
end end}

function selectedSampleBeatSyncLine(number)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
local currentBeatSyncLine = renoise.song().selected_sample.beat_sync_lines
local changedBeatSyncLine = currentBeatSyncLine + number
if changedBeatSyncLine > 512 then changedBeatSyncLine = 512
else if changedBeatSyncLine < 1 then -- renoise.song().selected_sample.beat_sync_enabled = false 
return end end
renoise.song().selected_sample.beat_sync_lines=changedBeatSyncLine
renoise.song().selected_sample.beat_sync_enabled = true
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (+1)",invoke=function() selectedSampleBeatSyncLine(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (-1)",invoke=function() selectedSampleBeatSyncLine(-1) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Autofade On/Off",invoke=function() selectedSampleAutofadeToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Autoseek On/Off",invoke=function() selectedSampleAutoseekToggle() end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample NNA to 1 (Cut)",invoke=function() selectedSampleNNA(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample NNA to 2 (Note-Off)",invoke=function() selectedSampleNNA(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample NNA to 3 (Continue)",invoke=function() selectedSampleNNA(3) end}

function selectedSampleMuteGroup(number)
if not renoise.song().selected_sample then 
  renoise.app():show_status("No sample selected, doing nothing.")
  return 
end
renoise.song().selected_sample.mute_group = number
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 0 (Off)",invoke=function() selectedSampleMuteGroup(0) end}
for i=1,9 do
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to ".. i,invoke=function() selectedSampleMuteGroup(i) end}
end
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to A",invoke=function() selectedSampleMuteGroup(10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to B",invoke=function() selectedSampleMuteGroup(11) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to C",invoke=function() selectedSampleMuteGroup(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to D",invoke=function() selectedSampleMuteGroup(13) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to E",invoke=function() selectedSampleMuteGroup(14) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to F",invoke=function() selectedSampleMuteGroup(15) end}

-- Change Output Routing per Selected Track
function set_output_routing_by_index(number)
    local available_output_routings = renoise.song().tracks[renoise.song().selected_track_index].available_output_routings

    if number >= 1 and number <= #available_output_routings then
        renoise.song().tracks[renoise.song().selected_track_index].output_routing = available_output_routings[number]
    else
        print("Index out of range. Please use an index between 1 and " .. #available_output_routings)
    end
end

function find_current_routing_index(available_routings, current_routing)
    for index, routing in ipairs(available_routings) do
        if routing == current_routing then
            return index
        end
    end
    return nil -- Return nil if the current routing is not found
end

function apply_selected_routing(selected_index)
    local selected_track_index = renoise.song().selected_track_index
    local available_output_routings = renoise.song().tracks[selected_track_index].available_output_routings

    if selected_index and selected_index >= 1 and selected_index <= #available_output_routings then
        renoise.song().tracks[selected_track_index].output_routing = available_output_routings[selected_index]
    else
        print("Index out of range. Please use an index between 1 and " .. #available_output_routings)
    end
end

-- Function to open a dialog with the list of available output routings using a popup
function showAvailableRoutings()
    local selected_track_index = renoise.song().selected_track_index
    local available_output_routings = renoise.song().tracks[selected_track_index].available_output_routings
    local current_routing = renoise.song().tracks[selected_track_index].output_routing
    local selected_routing_index = find_current_routing_index(available_output_routings, current_routing)

    -- Create a ViewBuilder object
    local vb = renoise.ViewBuilder()

    local dialog -- Pre-declare the dialog variable so it can be referenced inside button callbacks

    -- Define the content of the dialog
    local dialog_content = vb:column{
        margin=10,
        spacing=5,
        vb:text{
            text="Select Output Routing for Selected Track:"
        },
        vb:popup{
            id = "popup_output_routings",
            items = available_output_routings,
            value = selected_routing_index or 1, -- Set the popup to the current routing, or default to the first item
            width=300,
            notifier=function(index)
                -- Update the selected index when a new item is selected
                selected_routing_index = index
            end
        },
        vb:row{
            spacing=10,
            vb:button{
                text="OK",
                notifier=function()
                    apply_selected_routing(selected_routing_index)
                    dialog:close()
                end
            },
            vb:button{
                text="Cancel",
                notifier=function()
                    dialog:close()
                end
            }
        }
    }

    -- Show the dialog
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Output Routing for Selected Track", dialog_content, keyhandler)
end




function simpleOutputRoute(output)
  -- Get the selected track from the current song
  local track = renoise.song().tracks[renoise.song().selected_track_index]
  
  -- Check if the desired output index is within the range of available output routings
  if output <= #track.available_output_routings then
    -- If the index is valid, set the output routing
    track.output_routing = track.available_output_routings[output]
  else
    -- If the index is invalid (i.e., the output doesn't exist), do nothing.
  end
end


for i=0,63 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing "..formatDigits(2,i),
    invoke=function() simpleOutputRoute(i+1) end}
end
--------

function pakettiMasterOutputRoutings(output)
  local song=renoise.song()
  local masterTrack=song:track(song.sequencer_track_count+1)
  if output<=#masterTrack.available_output_routings then
    masterTrack.output_routing=masterTrack.available_output_routings[output]
  else
    renoise.app():show_status("This Master Output Routing Channel is not available on the selected sound device.")
  end
end

for i=0,63 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Master Track Output Routing "..string.format("%02d",i),
    invoke=function() pakettiMasterOutputRoutings(i+1) end}
end







-----
function setBeatSyncLineAbove()
    local currentBeatSyncLine = renoise.song().selected_sample.beat_sync_lines
    -- Calculate the next higher power of 2
    local power = math.ceil(math.log(currentBeatSyncLine) / math.log(2))
    local nextPowerOfTwo = 2 ^ power
    if nextPowerOfTwo <= currentBeatSyncLine then -- Ensure we actually move up
        nextPowerOfTwo = nextPowerOfTwo * 2
    end
    -- Clamp to maximum allowed value
    if nextPowerOfTwo > 512 then nextPowerOfTwo = 512 end
    renoise.song().selected_sample.beat_sync_lines = nextPowerOfTwo
    renoise.song().selected_sample.beat_sync_enabled = true
end

function setBeatSyncLineBelow()
    local currentBeatSyncLine = renoise.song().selected_sample.beat_sync_lines
    if currentBeatSyncLine <= 1 then -- Prevent going below 1
        return
    end
    local power = math.floor(math.log(currentBeatSyncLine) / math.log(2))
    local prevPowerOfTwo = 2 ^ power
    if prevPowerOfTwo >= currentBeatSyncLine then -- Ensure we actually move down
        prevPowerOfTwo = prevPowerOfTwo / 2
    end
    renoise.song().selected_sample.beat_sync_lines = prevPowerOfTwo
    renoise.song().selected_sample.beat_sync_enabled = true
end


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (Power of Two Above)",invoke=function() setBeatSyncLineAbove() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (Power of Two Below)",invoke=function() setBeatSyncLineBelow() end}


-- Function to toggle the sequence selection based on the provided sequence number
function tknaToggleSequenceSelection(number)
  local seq_index = number + 1 -- Adjusting to 1-based index as required by Renoise

  -- Check if the current selection matches the specified sequence number
  if renoise.song().sequencer.selection_range and
     #renoise.song().sequencer.selection_range == 2 and
     renoise.song().sequencer.selection_range[1] == seq_index and
     renoise.song().sequencer.selection_range[2] == seq_index then
    -- If so, clear the selection
    renoise.song().sequencer.selection_range = {}
  else
    -- Otherwise, set the selection to the specified sequence number
    renoise.song().sequencer.selection_range = {seq_index, seq_index}
  end
end

-- Loop to create keybindings for sequence numbers 00 to 32
for i = 1, 33 do
  local padded_number = string.format("%02d", i - 1)
  local keybinding_name="Global:Paketti:Toggle Sequence Selection " .. padded_number

  -- Create a keybinding for each sequence number
  renoise.tool():add_keybinding{name=keybinding_name,invoke=function() tknaToggleSequenceSelection(i - 1) end}
end


-- Function to toggle the sequence selection based on the provided sequence number
-- If there is a selection_range, turn it into a sequence loop
function SequenceSelectionToLoop()
  local song=renoise.song()
  local selection_start = song.sequencer.selection_range[1]
  local selection_end = song.sequencer.selection_range[2]

  -- Check if the loop range matches the current selection
  if song.transport.loop_sequence_range[1] == selection_start and 
     song.transport.loop_sequence_range[2] == selection_end then
    -- If it matches, disable the loop by setting it to nil
    song.transport.loop_sequence_range = {}
  else
    -- Otherwise, set the loop range to the current selection
    song.transport.loop_sequence_range = { selection_start, selection_end}
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Sequence Selection to Loop",invoke=function() SequenceSelectionToLoop() end}


function TKNAToggleSequenceSelectionAll()
  local sequencerCount=#renoise.song().sequencer.pattern_sequence
  --if renoise.song().sequencer.selection_range=={1,sequencerCount} 
  --then renoise.song().sequencer.selection_range={} else
  renoise.song().sequencer.selection_range={1,#renoise.song().sequencer.pattern_sequence}
  --end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Sequence Selection (All) On/Off",invoke=function() TKNAToggleSequenceSelectionAll() end}

function tknaUnselectSequenceSelection()
renoise.song().sequencer.selection_range={}
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Sequence Selection Off",invoke=tknaUnselectSequenceSelection}

-- Function to toggle the current sequence selection
function tknaToggleCurrentSequenceSelection()
  -- Check if the current selection matches the selected sequence index
  if renoise.song().sequencer.selection_range and
     #renoise.song().sequencer.selection_range == 2 and
     renoise.song().sequencer.selection_range[1] == renoise.song().selected_sequence_index and
     renoise.song().sequencer.selection_range[2] == renoise.song().selected_sequence_index then
    -- If so, clear the selection
    renoise.song().sequencer.selection_range = {}
  else
    -- Otherwise, set the selection to the current sequence index
    renoise.song().sequencer.selection_range = {renoise.song().selected_sequence_index, renoise.song().selected_sequence_index}
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Current Sequence Selection On/Off",invoke=tknaToggleCurrentSequenceSelection}

-- Helper function to select and loop a specific section
function select_and_loop_section(section_number)
  local song=renoise.song()
  local sequencer = song.sequencer
  local sequence_count = #sequencer.pattern_sequence

  local current_section_start = nil
  local current_section_index = 0

  -- Find the start index of the specific section
  for i = 1, sequence_count do
    if sequencer:sequence_is_start_of_section(i) then
      current_section_index = current_section_index + 1
      if current_section_index == section_number then
        current_section_start = i
        break
      end
    end
  end

  -- If the specified section is not found, exit the function
  if not current_section_start then
    renoise.app():show_status("No such Section exists, doing nothing.")
    return
  end

  -- Find the end index of the current section
  local current_section_end = sequence_count
  for i = current_section_start + 1, sequence_count do
    if sequencer:sequence_is_start_of_section(i) then
      current_section_end = i - 1
      break
    end
  end

  -- Set the loop to the current section
  song.transport.loop_sequence_range = {current_section_start, current_section_end}
  
  -- Notify the user
  renoise.app():show_status("Loop set to section " .. section_number .. " from sequence " .. current_section_start .. " to " .. current_section_end)
end

-- Helper function to find the current section index
function find_current_section_index()
  local song=renoise.song()
  local sequencer = song.sequencer
  local sequence_count = #sequencer.pattern_sequence
  local current_pos = song.transport.edit_pos.sequence
  local loop_start = song.transport.loop_sequence_range[1]
  local loop_end = song.transport.loop_sequence_range[2]

  -- Check if a section is currently selected
  if loop_start > 0 and loop_end > 0 and loop_start <= loop_end then
    local current_section_index = 0
    for i = 1, sequence_count do
      if sequencer:sequence_is_start_of_section(i) then
        current_section_index = current_section_index + 1
        if loop_start == i then
          return current_section_index
        end
      end
    end
  end

  -- If no section is selected, find the section based on the current edit position
  local current_section_index = 0
  for i = 1, sequence_count do
    if sequencer:sequence_is_start_of_section(i) then
      current_section_index = current_section_index + 1
      if i > current_pos then
        return current_section_index - 1
      end
    end
  end
  return current_section_index
end

-- Function to select and loop the next section
function select_and_loop_section_next()
  local current_section_index = find_current_section_index()
  if current_section_index < 32 then
    select_and_loop_section(current_section_index + 1)
  else
    renoise.app():show_status("There is no Next Section available.")
  end
end

-- Function to select and loop the previous section
function select_and_loop_section_previous()
  local current_section_index = find_current_section_index()
  if current_section_index > 1 then
    select_and_loop_section(current_section_index - 1)
  else
    renoise.app():show_status("There is no Previous Section available.")
  end
end

-- Function to turn off the sequence selection
function set_sequence_selection_off()
  local song=renoise.song()
  song.transport.loop_sequence_range = {0, 0}
  renoise.app():show_status("Sequence selection turned off.")
end

-- Function to select and loop a specific section, or deselect it if already selected
function select_and_loop_section(section_index)
  local song=renoise.song()
  local sequencer = song.sequencer
  local sequence_count = #sequencer.pattern_sequence
  local current_section_index = 0
  local loop_start = 0
  local loop_end = 0

  for i = 1, sequence_count do
    if sequencer:sequence_is_start_of_section(i) then
      current_section_index = current_section_index + 1
      if current_section_index == section_index then
        loop_start = i
        for j = i + 1, sequence_count do
          if sequencer:sequence_is_start_of_section(j) then
            loop_end = j - 1
            break
          end
        end
        if loop_end == 0 then
          loop_end = sequence_count
        end
        break
      end
    end
  end

  if song.transport.loop_sequence_range[1] == loop_start and song.transport.loop_sequence_range[2] == loop_end then
    set_sequence_selection_off()
  else
    song.transport.loop_sequence_range = {loop_start, loop_end}
    renoise.app():show_status("Looped section " .. section_index)
  end
end


renoise.tool():add_keybinding{name="Global:Paketti:Select and Loop Section (Next)",invoke=select_and_loop_section_next}
renoise.tool():add_keybinding{name="Global:Paketti:Select and Loop Section (Previous)",invoke=select_and_loop_section_previous}

renoise.tool():add_keybinding{name="Global:Paketti:Set Sequence Loop Selection Off",invoke=set_sequence_selection_off}

---
function tknaNextSequence(count)
local currSeq = renoise.song().selected_sequence_index
local nextSeq = currSeq + count
local total_sequences = #renoise.song().sequencer.pattern_sequence

if nextSeq < 1 then renoise.app():show_status("You are on the first sequence.") return else

  if nextSeq <= total_sequences then
    renoise.song().selected_sequence_index = nextSeq
    else
    renoise.app():show_status("No more sequences available.")
  end
end

end

renoise.tool():add_keybinding{name="Global:Paketti:Jump to Sequence (Next)",invoke=function() tknaNextSequence(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Jump to Sequence (Previous)",invoke=function() tknaNextSequence(-1) end}

function tknaContinueSequenceFromSameLine(number)
local storedSequence = renoise.song().selected_sequence_index
local storedRow = renoise.song().selected_line_index
  if number <= #renoise.song().sequencer.pattern_sequence then
if renoise.song().transport.follow_player then
renoise.song().selected_sequence_index = number
else

renoise.song().transport.follow_player = true 
renoise.song().selected_sequence_index = number
renoise.song().transport.follow_player = false
renoise.song().selected_sequence_index=storedSequence
renoise.song().selected_line_index=storedRow 
end
    else
    renoise.app():show_status("Sequence does not exist, doing nothing.")
  end

end


for i = 1, 32 do
  -- Zero-pad the number for sequence naming
  local padded_number = string.format("%02d", i - 1)
  
  renoise.tool():add_keybinding{name="Global:Paketti:Continue Sequence " .. padded_number .. " From Same Line",invoke=function() 
  if i < #renoise.song().sequencer.pattern_sequence then
  tknaContinueSequenceFromSameLine(i) 
  else
  renoise.song():show_status("Sequence does not exist, doing nothing.")
  end
  end}

end
--------

function tknaContinueCurrentSequenceFromCurrentLine()
  local song=renoise.song()

  local storedSequence = song.selected_sequence_index
  local step = 1

  local function processStep()
    if step == 1 then
      renoise.song().transport.follow_player = true
      renoise.app():show_status("Jumping to Previously Selected (Current) Sequence")
      step = step + 1
    elseif step == 2 then
      renoise.song().selected_sequence_index = storedSequence
      step = step + 1
    elseif step == 3 then
      renoise.song().transport.follow_player = false
      renoise.tool().app_idle_observable:remove_notifier(processStep)
    end
  end

  renoise.tool().app_idle_observable:add_notifier(processStep)
end



  renoise.tool():add_keybinding{name="Global:Paketti:Continue Current Sequence From Same Line",invoke=function() 
    tknaContinueCurrentSequenceFromCurrentLine() end}




  ---------
function tknaMidiMapSequence(value)
  local max_seq = #renoise.song().sequencer.pattern_sequence - 1
  local sequence_num = math.floor((value / 127) * max_seq) + 1
  tknaContinueSequenceFromSameLine(sequence_num)
end

renoise.tool():add_midi_mapping{name="Paketti:Continue Sequence From Same Line [Set Sequence]",invoke=function(message) if message:is_abs_value() then tknaMidiMapSequence(message.int_value) end end}

--------
for i = 1, 32 do
  -- Zero-pad the number for sequence naming
  local padded_number = string.format("%02d", i - 1)
  
  renoise.tool():add_keybinding{name="Global:Paketti:Selected Specific Sequence " .. padded_number,invoke=function() 
  if i < #renoise.song().sequencer.pattern_sequence then 
  renoise.song().selected_sequence_index = i
  else renoise.app():show_status("Sequence does not exist, doing nothing.")
  end
     end}
end

function tknaTriggerSequence(number)
  local total_sequences = #renoise.song().sequencer.pattern_sequence
  if number < total_sequences then
    renoise.song().transport:trigger_sequence(number)
  else
    renoise.app():show_status("This sequence position does not exist.")
  end
end

for i = 1, 32 do
  local padded_number = string.format("%02d", i - 1)
  renoise.tool():add_keybinding{name="Global:Paketti:Trigger Sequence " .. padded_number,invoke=function() tknaTriggerSequence(i) end}
end

function tknaSetSequenceAsScheduledList(number)
if renoise.song().transport.playing then  else renoise.song().transport.playing=true
end
local total_sequences = #renoise.song().sequencer.pattern_sequence
if number < total_sequences then
renoise.song().transport:set_scheduled_sequence(number)
else
renoise.app():show_status("This sequence position does not exist.")
end
end

for i = 1,32 do
  local padded_number = string.format("%02d", i - 1)
  renoise.tool():add_keybinding{name="Global:Paketti:Set Sequence " .. padded_number .. " as Scheduled List",invoke=function() tknaSetSequenceAsScheduledList(i) end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Set Sequence as Scheduled List:Set Sequence " .. padded_number .. " as Scheduled List",invoke=function() tknaSetSequenceAsScheduledList(i) end}
end

  renoise.tool():add_keybinding{name="Global:Paketti:Set Current Sequence as Scheduled List",invoke=function() renoise.song().transport:set_scheduled_sequence(renoise.song().selected_sequence_index) end}

  ---
function tknaAddSequenceToScheduledList(number)
if renoise.song().transport.playing then  else renoise.song().transport.playing=true
end
local total_sequences = #renoise.song().sequencer.pattern_sequence
if number < total_sequences then
renoise.song().transport:add_scheduled_sequence(number)
else
renoise.app():show_status("This sequence position does not exist.")
end
end

for i = 1,32 do
  local padded_number = string.format("%02d", i - 1)
  renoise.tool():add_keybinding{name="Global:Paketti:Add Sequence " .. padded_number .. " to Scheduled List",invoke=function() tknaAddSequenceToScheduledList(i) end}
end


for i = 1, 32 do
  local padded_number = string.format("%02d", i - 1)
  renoise.tool():add_keybinding{name="Global:Paketti:Toggle Sequence Loop to " .. padded_number,
    invoke=function()
      local total_sequences = #renoise.song().sequencer.pattern_sequence
      if i <= total_sequences then
        local current_range = renoise.song().transport.loop_sequence_range
        if current_range[1] == i and current_range[2] == i then
          -- Turn off the loop
          renoise.song().transport.loop_sequence_range = {}
          renoise.app():show_status("Sequence loop turned off.")
        else
          -- Set the loop to the specified range
          renoise.song().transport.loop_sequence_range = {i, i}
          renoise.app():show_status("Sequence loop set to " .. padded_number)
        end
      else
        renoise.app():show_status("This sequence does not exist.")
      end
    end
  }
end

function TKNAClearPatternSequenceLoop()
  renoise.song().transport.loop_sequence_range = {}
end
renoise.tool():add_keybinding{name="Global:Paketti:Clear Pattern Sequence Loop",invoke=function() TKNAClearPatternSequenceLoop() end}

-- Function to compare two tables for value equality
function tables_equal(t1, t2)
  if #t1 ~= #t2 then
    return false
  end
  for i = 1, #t1 do
    if t1[i] ~= t2[i] then
      return false
    end
  end
  return true
end

-- Function to set the sequence loop from current loop position to specified position
function setSequenceLoopFromCurrentTo(position)
  local total_sequences = #renoise.song().sequencer.pattern_sequence
  local current_range = renoise.song().transport.loop_sequence_range

  -- Ensure the specified position is within the valid range
  if position > total_sequences then
    renoise.app():show_status("This sequence does not exist.")
    return
  end

  -- Check if current_range is {0,0} using the tables_equal function
  if tables_equal(current_range, {0,0}) then
    renoise.song().transport.loop_sequence_range = {position, position}
    return
  end

  local current_start = current_range[1]

  -- Check if the specified position is valid for setting the loop
  if position < current_start then
    renoise.song().transport.loop_sequence_range = {position, current_start}
    renoise.app():show_status("Sequence loop set from " .. position .. " to " .. current_start)
  else
    renoise.song().transport.loop_sequence_range = {current_start, position}
    renoise.app():show_status("Sequence loop set from " .. current_start .. " to " .. position)
  end
end

-- Loop to create keybindings for setting the loop range from current to specified position
for i = 1, 32 do
  local padded_number = string.format("%02d", i - 1)
  renoise.tool():add_keybinding{name="Global:Paketti:Set Sequence Loop from Current to " .. padded_number,invoke=function()
    setSequenceLoopFromCurrentTo(i)
  end}
end

-- Function to set the scheduled sequence as the current section
function tknaSetCurrentSectionAsScheduledSequence()
  local song=renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence

  -- Helper function to find all sections
  local function findSections()
    local sections = {}
    for i = 1, total_sequences do
      if sequencer:sequence_is_start_of_section(i) then
        table.insert(sections, i)
      end
    end
    return sections
  end

  -- Helper function to find the section index for a given sequence index
  local function findSectionIndex(sections, sequence_index)
    local total_sections = #sections
    for i, section_start in ipairs(sections) do
      local section_end = (i < total_sections) and (sections[i + 1] - 1) or total_sequences
      if sequence_index >= section_start and sequence_index <= section_end then
        return i, section_start, section_end
      end
    end
    return nil
  end

  local sections = findSections()
  local current_section_index, current_section_start, current_section_end = findSectionIndex(sections, current_sequence_index)

  -- Set the scheduled sequence to the current section if it exists
  if current_section_index then
    transport:set_scheduled_sequence(current_section_start)
    for i = current_section_start + 1, current_section_end do
      transport:add_scheduled_sequence(i)
    end
    renoise.app():show_status("Set scheduled sequence to current section: " .. current_section_start .. " to " .. current_section_end)
  else
    renoise.app():show_status("Current sequence is not inside any section.")
  end
end

-- Function to add the current section to the scheduled sequences
function tknaAddCurrentSectionToScheduledSequences()
  local song=renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence

  -- Helper function to find all sections
  local function findSections()
    local sections = {}
    for i = 1, total_sequences do
      if sequencer:sequence_is_start_of_section(i) then
        table.insert(sections, i)
      end
    end
    return sections
  end

  -- Helper function to find the section index for a given sequence index
  local function findSectionIndex(sections, sequence_index)
    local total_sections = #sections
    for i, section_start in ipairs(sections) do
      local section_end = (i < total_sections) and (sections[i + 1] - 1) or total_sequences
      if sequence_index >= section_start and sequence_index <= section_end then
        return i, section_start, section_end
      end
    end
    return nil
  end

  local sections = findSections()
  local current_section_index, current_section_start, current_section_end = findSectionIndex(sections, current_sequence_index)

  -- Add the current section to the scheduled sequences if it exists
  if current_section_index then
    for i = current_section_start, current_section_end do
      transport:add_scheduled_sequence(i)
    end
    renoise.app():show_status("Added current section to scheduled sequences: " .. current_section_start .. " to " .. current_section_end)
  else
    renoise.app():show_status("Current sequence is not inside any section.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Current Section as Scheduled Sequence",invoke=tknaSetCurrentSectionAsScheduledSequence}
renoise.tool():add_keybinding{name="Global:Paketti:Add Current Section to Scheduled Sequences",invoke=tknaAddCurrentSectionToScheduledSequences}
renoise.tool():add_midi_mapping{name="Paketti:Set Current Section as Scheduled Sequence",invoke=tknaSetCurrentSectionAsScheduledSequence}
renoise.tool():add_midi_mapping{name="Paketti:Add Current Section to Scheduled Sequences",invoke=tknaAddCurrentSectionToScheduledSequences}


-- Function to expand the section loop step-by-step, adding the next section
function expandSectionLoopNext()
  local song=renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence

  -- Helper function to find all sections
  local function findSectionsA()
    local sections = {}
    for i = 1, total_sequences do
      if sequencer:sequence_is_start_of_section(i) then
        table.insert(sections, i)
      end
    end
    return sections
  end

  local sections = findSectionsA()
  local total_sections = #sections

  -- Helper function to find the section index for a given sequence index
  local function findSectionIndexA(sequence_index)
    for i, section_start in ipairs(sections) do
      local section_end = (i < total_sections) and (sections[i + 1] - 1) or total_sequences
      if sequence_index >= section_start and sequence_index <= section_end then
        return i, section_start, section_end
      end
    end
    return nil
  end

  local current_section_index, current_section_start, current_section_end = findSectionIndexA(current_sequence_index)
  local loop_range = transport.loop_sequence_range

  -- If no loop range or an invalid loop range exists, set it to the current section
  if not loop_range or #loop_range ~= 2 or 
      (loop_range[1] == 0 and loop_range[2] == 0) then
    if current_section_index then
      transport.loop_sequence_range = {current_section_start, current_section_end}
    else
      renoise.app():show_status("Current sequence is not inside any section.")
    end
  else
    local loop_end = loop_range[2]
    local next_section_index = findSectionIndexA(loop_end + 1)

    -- If there's a next section to add
    if next_section_index then
      local next_section_start, next_section_end = sections[next_section_index], (next_section_index < total_sections) and (sections[next_section_index + 1] - 1) or total_sequences
      transport.loop_sequence_range = {loop_range[1], next_section_end}
    else
      -- No more sections to add to the loop
      renoise.app():show_status("No more sections to add to the loop.")
    end
  end
end

-- Function to expand the section loop step-by-step, adding the previous section
function expandSectionLoopPrevious()
  local song=renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence

  -- Helper function to find all sections
  local function findSectionsB()
    local sections = {}
    for i = 1, total_sequences do
      if sequencer:sequence_is_start_of_section(i) then
        table.insert(sections, i)
      end
    end
    return sections
  end

  local sections = findSectionsB()
  local total_sections = #sections

  -- Helper function to find the section index for a given sequence index
  local function findSectionIndexB(sequence_index)
    for i, section_start in ipairs(sections) do
      local section_end = (i < total_sections) and (sections[i + 1] - 1) or total_sequences
      if sequence_index >= section_start and sequence_index <= section_end then
        return i, section_start, section_end
      end
    end
    return nil
  end

  local current_section_index, current_section_start, current_section_end = findSectionIndexB(current_sequence_index)
  local loop_range = transport.loop_sequence_range

  -- If no loop range or an invalid loop range exists, set it to the current section
  if not loop_range or #loop_range ~= 2 or 
      (loop_range[1] == 0 and loop_range[2] == 0) then
    if current_section_index then
      transport.loop_sequence_range = {current_section_start, current_section_end}
    else
      renoise.app():show_status("Current sequence is not inside any section.")
    end
  else
    local loop_start = loop_range[1]
    local previous_section_index = findSectionIndexB(loop_start - 1)

    -- If there's a previous section to add
    if previous_section_index then
      local previous_section_start, previous_section_end = sections[previous_section_index], (previous_section_index < total_sections) and (sections[previous_section_index + 1] - 1) or total_sequences
      transport.loop_sequence_range = {previous_section_start, loop_range[2]}
    else
      -- No more sections to add to the loop
      renoise.app():show_status("No more sections to add to the loop.")
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Section Loop (Next)",invoke=expandSectionLoopNext}
renoise.tool():add_keybinding{name="Global:Paketti:Section Loop (Previous)",invoke=expandSectionLoopPrevious}
renoise.tool():add_midi_mapping{name="Paketti:Section Loop (Next)",invoke=expandSectionLoopNext}
renoise.tool():add_midi_mapping{name="Paketti:Section Loop (Previous)",invoke=expandSectionLoopPrevious}



-- Function to expand the sequence selection step-by-step
function tknaSequenceSelectionPlusOne()
  local song=renoise.song()
  local sequencer = song.sequencer
  local current_sequence_index = song.selected_sequence_index
  local selection_range = sequencer.selection_range
  local total_sequences = #sequencer.pattern_sequence

  -- If no selection range exists or if it is {0, 0}, select the current sequence
  if not selection_range or #selection_range ~= 2 or 
      (selection_range[1] == 0 and selection_range[2] == 0) then
    sequencer.selection_range = {current_sequence_index, current_sequence_index}
  else
    local start_index = selection_range[1]
    local end_index = selection_range[2]

    -- If the end index is less than the total number of sequences
    if end_index < total_sequences then
      -- Extend the selection range by including the next sequence
      sequencer.selection_range = {start_index, end_index + 1}
    else
      -- No more sequences to add to the selection
      renoise.app():show_status("No more sequences left to add to the selection.")
    end
  end
end

-- Function to reduce the sequence selection step-by-step
function tknaSequenceSelectionMinusOne()
  local song=renoise.song()
  local sequencer = song.sequencer
  local current_sequence_index = song.selected_sequence_index
  local selection_range = sequencer.selection_range

  -- If no selection range exists or if it is {0, 0}, select the current sequence
  if not selection_range or #selection_range ~= 2 or 
      (selection_range[1] == 0 and selection_range[2] == 0) then
    sequencer.selection_range = {current_sequence_index, current_sequence_index}
  else
    local start_index = selection_range[1]
    local end_index = selection_range[2]

    -- If the start index is greater than 1
    if start_index > 1 then
      -- Reduce the selection range by excluding the first sequence
      sequencer.selection_range = {start_index - 1, end_index}
    else
      -- No more sequences to remove from the selection
      renoise.app():show_status("No more sequences left to add to the selection.")
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Sequence Selection (Next)",invoke=tknaSequenceSelectionPlusOne}
renoise.tool():add_keybinding{name="Global:Paketti:Sequence Selection (Previous)",invoke=tknaSequenceSelectionMinusOne}

renoise.tool():add_midi_mapping{name="Paketti:Sequence Selection (Next)",invoke=tknaSequenceSelectionPlusOne}
renoise.tool():add_midi_mapping{name="Paketti:Sequence Selection (Previous)",invoke=tknaSequenceSelectionMinusOne}

-- Function to expand the loop selection to the next sequence
function tknaSequenceLoopSelectionNext()
  local song=renoise.song()
  local transport = song.transport
  local sequencer = song.sequencer
  local total_sequences = #sequencer.pattern_sequence
  local loop_range = transport.loop_sequence_range
  local current_sequence_index = song.selected_sequence_index

  -- If no loop range or an invalid loop range exists, select the current sequence
  if not loop_range or #loop_range ~= 2 or (loop_range[1] == 0 and loop_range[2] == 0) then
    transport.loop_sequence_range = {current_sequence_index, current_sequence_index}
  else
    local loop_start = loop_range[1]
    local loop_end = loop_range[2]

    -- If the loop end is less than the total number of sequences
    if loop_end < total_sequences then
      -- Extend the loop range by including the next sequence
      transport.loop_sequence_range = {loop_start, loop_end + 1}
    else
      -- No more sequences to add to the loop
      renoise.app():show_status("No more to add, at end of song")
    end
  end
end

-- Function to expand the loop selection to the previous sequence
function tknaSequenceLoopSelectionPrevious()
  local song=renoise.song()
  local transport = song.transport
  local sequencer = song.sequencer
  local total_sequences = #sequencer.pattern_sequence
  local loop_range = transport.loop_sequence_range
  local current_sequence_index = song.selected_sequence_index

  -- If no loop range or an invalid loop range exists, select the current sequence
  if not loop_range or #loop_range ~= 2 or (loop_range[1] == 0 and loop_range[2] == 0) then
    transport.loop_sequence_range = {current_sequence_index, current_sequence_index}
  else
    local loop_start = loop_range[1]
    local loop_end = loop_range[2]

    -- If the loop start is greater than 1
    if loop_start > 1 then
      -- Extend the loop range by including the previous sequence
      transport.loop_sequence_range = {loop_start - 1, loop_end}
    else
      -- No more sequences to add to the loop
      renoise.app():show_status("No more to add, at beginning of song")
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Sequence Loop Selection (Next)",invoke=tknaSequenceLoopSelectionNext}
renoise.tool():add_keybinding{name="Global:Paketti:Sequence Loop Selection (Previous)",invoke=tknaSequenceLoopSelectionPrevious}


renoise.tool():add_midi_mapping{name="Paketti:Sequence Loop Selection (Next)",invoke=tknaSequenceLoopSelectionNext}
renoise.tool():add_midi_mapping{name="Paketti:Sequence Loop Selection (Previous)",invoke=tknaSequenceLoopSelectionPrevious}
-- Function to add a loop to the current section content and schedule the section to play from the first sequence
function tknaAddLoopAndScheduleSection()
  local song=renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence

  -- Helper function to find all sections
  local function findSections()
    local sections = {}
    for i = 1, total_sequences do
      if sequencer:sequence_is_start_of_section(i) then
        table.insert(sections, i)
      end
    end
    return sections
  end

  -- Helper function to find the section index for a given sequence index
  local function findSectionIndex(sections, sequence_index)
    local total_sections = #sections
    for i, section_start in ipairs(sections) do
      local section_end = (i < total_sections) and (sections[i + 1] - 1) or total_sequences
      if sequence_index >= section_start and sequence_index <= section_end then
        return i, section_start, section_end
      end
    end
    return nil
  end

  local sections = findSections()
  local current_section_index, current_section_start, current_section_end = findSectionIndex(sections, current_sequence_index)

  -- Set the loop and schedule sequence to the current section if it exists
  if current_section_index then
    -- Set loop sequence range
    transport.loop_sequence_range = {current_section_start, current_section_end}
    
    -- Set scheduled sequence
    transport:set_scheduled_sequence(current_section_start)

    -- Show status message
    renoise.app():show_status("Loop added to current section and scheduled to play from the first sequence.")
  else
    renoise.app():show_status("Current sequence is not inside any section.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Section Loop and Schedule Section",invoke=tknaAddLoopAndScheduleSection}

renoise.tool():add_midi_mapping{name="Paketti:Set Section Loop and Schedule Section [Knob]",invoke=function(message) if message:is_trigger() then tknaAddLoopAndScheduleSection() end end}
---
function tknaSetScheduledSequenceToCurrentSequenceAndLoop()
  local song=renoise.song()
  local selection_start = song.selected_sequence_index
  local selection_end = song.selected_sequence_index

  if song.transport.loop_sequence_range[1] == selection_start and 
     song.transport.loop_sequence_range[2] == selection_end then
    song.transport.loop_sequence_range = {}
  else
    song.transport.loop_sequence_range = { selection_start, selection_end}
  end

  local current_sequence_index = song.selected_sequence_index
  if song.transport.playing then else song.transport.playing=true end
  local total_sequences = #song.sequencer.pattern_sequence
  if current_sequence_index <= total_sequences then
    song.transport:set_scheduled_sequence(current_sequence_index)
  else
    renoise.app():show_status("This sequence position does not exist.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Current Sequence as Scheduled and Loop",invoke=tknaSetScheduledSequenceToCurrentSequenceAndLoop}

---
-- Function to normalize the section name to a two-digit string, allowing for '.', '-', or ',' as separators
local function normalizeSectionName(section_name)
  -- Extract the numeric part before the separator (e.g., "01.", "01-", "01," -> "01")
  local number_part = section_name:match("^(%d+)[.,%-]?")
  if number_part then
    return string.format("%02d.", tonumber(number_part))
  end
  return nil
end

-- Helper function to find all occurrences of a section by number
local function findAllOccurrences(number)
  local song=renoise.song()
  local sequencer = song.sequencer
  local total_sequences = #sequencer.pattern_sequence
  local occurrences = {}

  local section_prefix = string.format("%02d.", number)

  for i = 1, total_sequences do
    if sequencer:sequence_is_start_of_section(i) then
      local section_name = sequencer:sequence_section_name(i)
      local normalized_section_name = normalizeSectionName(section_name)

      if normalized_section_name == section_prefix then
        table.insert(occurrences, i)
      end
    end
  end

  return occurrences
end

-- Function to select the next occurrence of a section (or the first if none is currently selected)
local function findNextOccurrence(occurrences, current_index)
  for _, section_start in ipairs(occurrences) do
    if section_start > current_index then
      return section_start
    end
  end
  return occurrences[1]  -- If no later occurrence, return the first occurrence
end

-- Helper function to find the section end based on the start index
local function findSectionEnd(section_start)
  local song=renoise.song()
  local total_sequences = #song.sequencer.pattern_sequence

  for j = section_start + 1, total_sequences do
    if song.sequencer:sequence_is_start_of_section(j) then
      return j - 1
    end
  end

  return total_sequences
end

-- Function to select, trigger, and loop the next occurrence of the section
function tknaSelectTriggerLoopSection(number)
  local song=renoise.song()
  local transport = song.transport
  local occurrences = findAllOccurrences(number)

  if #occurrences > 0 then
    local current_index = song.selected_sequence_index
    local next_section_start = findNextOccurrence(occurrences, current_index)

    -- Find the end of the next section
    local next_section_end = findSectionEnd(next_section_start)

    -- Select, trigger, and loop the next section
    song.selected_sequence_index = next_section_start
    transport.loop_sequence_range = {next_section_start, next_section_end}
    transport:trigger_sequence(next_section_start)
    
    renoise.app():show_status("Section '" .. string.format("%02d", number) .. "' triggered and looped.")
  else
    renoise.app():show_status("No section found starting with '" .. string.format("%02d", number) .. "'")
  end
end


-- Function to select, schedule, and loop the next occurrence of the section
function tknaSelectScheduleLoopSection(number)
  local song=renoise.song()
  local transport = song.transport
  local occurrences = findAllOccurrences(number)

  if #occurrences > 0 then
    local current_index = song.selected_sequence_index
    local next_section_start = findNextOccurrence(occurrences, current_index)

    -- Find the end of the next section
    local next_section_end = findSectionEnd(next_section_start)

    -- Select, schedule, and loop the next section
    song.selected_sequence_index = next_section_start
    transport.loop_sequence_range = {next_section_start, next_section_end}
    transport:set_scheduled_sequence(next_section_start)
    
    renoise.app():show_status("Section '" .. string.format("%02d", number) .. "' scheduled and looped.")
  else
    renoise.app():show_status("No section found starting with '" .. string.format("%02d", number) .. "'")
  end
end

-- Function to select, add to schedule, and loop the next occurrence of the section
function tknaSelectAddScheduleLoopSection(number)
  local song=renoise.song()
  local transport = song.transport
  local occurrences = findAllOccurrences(number)

  if #occurrences > 0 then
    local current_index = song.selected_sequence_index
    local next_section_start = findNextOccurrence(occurrences, current_index)

    -- Find the end of the next section
    local next_section_end = findSectionEnd(next_section_start)

    -- Select, add to schedule, and loop the next section
    song.selected_sequence_index = next_section_start
    transport.loop_sequence_range = {next_section_start, next_section_end}
    transport:add_scheduled_sequence(next_section_start)
    
    renoise.app():show_status("Section '" .. string.format("%02d", number) .. "' added to schedule and looped.")
  else
    renoise.app():show_status("No section found starting with '" .. string.format("%02d", number) .. "'")
  end
end

-- Create keybindings and MIDI mappings for Select, Trigger, Schedule, and Add to Schedule for Sections 00 to 64
for i = 0, 64 do
  local section_id = string.format("%02d", i)

  renoise.tool():add_keybinding{name="Global:Paketti:Select, Trigger and Loop Section " .. section_id,invoke=function() tknaSelectTriggerLoopSection(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Select&Trigger&Loop Section " .. section_id,invoke=function(message) if message:is_trigger() then tknaSelectTriggerLoopSection(i) end end}
  renoise.tool():add_keybinding{name="Global:Paketti:Select, Schedule and Loop Section " .. section_id,invoke=function() tknaSelectScheduleLoopSection(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Select&Schedule&Loop Section " .. section_id,invoke=function(message) if message:is_trigger() then tknaSelectScheduleLoopSection(i) end end}
  renoise.tool():add_keybinding{name="Global:Paketti:Select, Add to Schedule and Loop Section " .. section_id,invoke=function() tknaSelectAddScheduleLoopSection(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Select&Add to Schedule&Loop Section " .. section_id,invoke=function(message) if message:is_trigger() then tknaSelectAddScheduleLoopSection(i) end end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select, Trigger and Loop:Select, Trigger and Loop Section " .. section_id,invoke=function() tknaSelectTriggerLoopSection(i) end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select, Schedule and Loop:Select, Schedule and Loop Section " .. section_id,invoke=function() tknaSelectScheduleLoopSection(i) end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select, Add to Schedule and Loop:Select, Add to Schedule and Loop Section " .. section_id,invoke=function() tknaSelectAddScheduleLoopSection(i) end}
end
-----
-- Slice mode settings
local SLICE_SETTINGS = {
  percussion = {
    original = {
      beat_sync_enabled = true,
      beat_sync_mode = 2,    -- Percussion
      loop_mode = 2,         -- Forward
      mute_group = 1,
      autoseek = true
    },
    slices = {
      beat_sync_enabled = false,
      oneshot = true,
      autofade = true
    }
  },
  texture = {
    original = {
      beat_sync_enabled = true,
      beat_sync_mode = 3,    -- Texture
      loop_mode = 2,         -- Forward
      mute_group = 1,
      autoseek = true
    },
    slices = {
      beat_sync_enabled = false,
      oneshot = true,
      autofade = true
    }
  }
}

function sliceDrumKit(mode)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local s = renoise.song()
  
  -- Check if any instruments exist
  if #s.instruments == 0 then
    renoise.app():show_status("No instruments available.")
    return
  end
  
  local currInst = s.selected_instrument_index
  
  -- Check if instrument has samples
  if #s.instruments[currInst].samples == 0 then
    renoise.app():show_status("No samples in selected instrument.")
    return
  end
  
  s.selected_sample_index = 1
  local settings = SLICE_SETTINGS[mode]
  local sample = s.instruments[currInst].samples[1]
  
  -- Apply original sample settings
  for key, value in pairs(settings.original) do
    sample[key] = value
  end
  
  -- Create slices if none exist
  if #sample.slice_markers == 0 then
    local buffer_size = sample.sample_buffer.number_of_frames
    sample:insert_slice_marker(1)
    for i = 1, 7 do  -- Create 8 equal slices
      sample:insert_slice_marker(buffer_size * i / 8)
    end
  end
  
  -- Apply settings to slices
  for i = 2, #s.instruments[currInst].samples do
    local slice = s.instruments[currInst].samples[i]
    for key, value in pairs(settings.slices) do
      slice[key] = value
    end
  end
  
  renoise.app():show_status(string.format("Applied %s drum kit slice settings", mode))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

function slicePercussionDrumKit() sliceDrumKit("percussion") end
function sliceTextureDrumKit() sliceDrumKit("texture") end

  renoise.tool():add_keybinding{name="Sample Editor:Paketti:Slice Drumkit (Percussion)", invoke=slicePercussionDrumKit}
  renoise.tool():add_keybinding{name="Sample Editor:Paketti:Slice Drumkit (Texture)", invoke=sliceTextureDrumKit}




-------
-- Function to double the LPB value
function PakettiLPBDouble()
  local song=renoise.song()
  local current_lpb=song.transport.lpb
  
  if current_lpb >= 128 then
    if current_lpb * 2 > 256 then
      renoise.app():show_status("LPB Cannot be doubled to over 256")
      return
    end
  end
  
  local new_lpb=current_lpb*2
  song.transport.lpb=new_lpb
  renoise.app():show_status("Doubled LPB from "..current_lpb.." to "..new_lpb)
--  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to halve the LPB value
function PakettiLPBHalve()
  local song=renoise.song()
  local current_lpb=song.transport.lpb
  
  if current_lpb == 1 then
    renoise.app():show_status("LPB cannot be smaller than 1")
    return
  end
  
  if current_lpb % 2 ~= 0 then
    renoise.app():show_status("LPB is odd number, cannot halve LPB.")
    return
  end
  
  local new_lpb=math.floor(current_lpb/2)
  song.transport.lpb=new_lpb
  renoise.app():show_status("Halved LPB from "..current_lpb.." to "..new_lpb)
--  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Double LPB",invoke=function() PakettiLPBDouble() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve LPB",invoke=function() PakettiLPBHalve() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Double LPB",invoke=function() PakettiLPBDouble() PakettiLPBDouble() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Halve LPB",invoke=function() PakettiLPBHalve() PakettiLPBHalve() end}
--------
-- Studio Session Workflow: Make track mono and set hard left/right panning
-- For treating stereo output as two mono channels to output to two amplifiers

-- Helper function to insert or toggle mono device for a specific track
function insertOrToggleMonoDevice(track)
  local mono_device_index = nil
  
  -- Check for existing "Mono" device in the track
  for i = 2, #track.devices do
    if track.devices[i].display_name == "Mono" then
      mono_device_index = i
      break
    end
  end
  
  if mono_device_index then
    -- Toggle existing Mono device state
    local mono_device = track:device(mono_device_index)
    mono_device.is_active = not mono_device.is_active
    return mono_device.is_active
  else
    -- Insert new Mono device (Stereo Expander configured as Mono) at the end of DSP chain
    local mono_device = track:insert_device_at("Audio/Effects/Native/Stereo Expander", #track.devices + 1)
    mono_device.display_name = "Mono"
    mono_device.parameters[1].value = 0
    mono_device.is_maximized = false
    return true
  end
end

-- Selected Track to Mono and Hard Left
function selectedTrackToMonoAndHardLeft()
  local track = renoise.song().selected_track
  local mono_active = insertOrToggleMonoDevice(track)
  
  if mono_active then
    track.prefx_panning.value = 0.5   -- CENTER: proper stereo signal to Mono device
    track.postfx_panning.value = 0.0  -- Hard left: final output direction
    renoise.app():show_status("Selected Track: Mono ON, Hard Left")
  else
    renoise.app():show_status("Selected Track: Mono OFF")
  end
end

-- Selected Track to Mono and Hard Right
function selectedTrackToMonoAndHardRight()
  local track = renoise.song().selected_track
  local mono_active = insertOrToggleMonoDevice(track)
  
  if mono_active then
    track.prefx_panning.value = 0.5   -- CENTER: proper stereo signal to Mono device
    track.postfx_panning.value = 1.0  -- Hard right: final output direction
    renoise.app():show_status("Selected Track: Mono ON, Hard Right")
  else
    renoise.app():show_status("Selected Track: Mono OFF")
  end
end

-- Master Track to Mono and Hard Left
function masterTrackToMonoAndHardLeft()
  local song = renoise.song()
  local masterTrack = song:track(song.sequencer_track_count + 1)
  local mono_active = insertOrToggleMonoDevice(masterTrack)
  
  if mono_active then
    masterTrack.prefx_panning.value = 0.5   -- Hard left
    masterTrack.postfx_panning.value = 0.0  -- Hard left
    renoise.app():show_status("Master Track: Mono ON, Hard Left")
  else
    renoise.app():show_status("Master Track: Mono OFF")
  end
end

-- Master Track to Mono and Hard Right
function masterTrackToMonoAndHardRight()
  local song = renoise.song()
  local masterTrack = song:track(song.sequencer_track_count + 1)
  local mono_active = insertOrToggleMonoDevice(masterTrack)
  
  if mono_active then
    masterTrack.prefx_panning.value = 0.5   -- Hard right
    masterTrack.postfx_panning.value = 1.0  -- Hard right
    renoise.app():show_status("Master Track: Mono ON, Hard Right")
  else
    renoise.app():show_status("Master Track: Mono OFF")
  end
end

-- Add keybindings for the new studio session workflow functions
renoise.tool():add_keybinding{name="Global:Paketti:Selected Track to Mono and Hard Left",invoke=function() selectedTrackToMonoAndHardLeft() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Track to Mono and Hard Right",invoke=function() selectedTrackToMonoAndHardRight() end}
renoise.tool():add_keybinding{name="Global:Paketti:Master Track to Mono and Hard Left",invoke=function() masterTrackToMonoAndHardLeft() end}
renoise.tool():add_keybinding{name="Global:Paketti:Master Track to Mono and Hard Right",invoke=function() masterTrackToMonoAndHardRight() end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:TKNA:Selected Track to Mono and Hard Left",invoke=function() selectedTrackToMonoAndHardLeft() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:TKNA:Selected Track to Mono and Hard Right",invoke=function() selectedTrackToMonoAndHardRight() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:TKNA:Master Track to Mono and Hard Left",invoke=function() masterTrackToMonoAndHardLeft() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:TKNA:Master Track to Mono and Hard Right",invoke=function() masterTrackToMonoAndHardRight() end}

renoise.tool():add_midi_mapping{name="Paketti:Selected Track to Mono and Hard Left",invoke=function(message) if message:is_trigger() then selectedTrackToMonoAndHardLeft() end end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Track to Mono and Hard Right",invoke=function(message) if message:is_trigger() then selectedTrackToMonoAndHardRight() end end}
renoise.tool():add_midi_mapping{name="Paketti:Master Track to Mono and Hard Left",invoke=function(message) if message:is_trigger() then masterTrackToMonoAndHardLeft() end end}
renoise.tool():add_midi_mapping{name="Paketti:Master Track to Mono and Hard Right",invoke=function(message) if message:is_trigger() then masterTrackToMonoAndHardRight() end end}

--------
-- Mono Cycler: Cycles through mono device modes and panning
-- Cycle order: 
-- 1. Mono L only 
-- 2. Mono R only
-- 3. Mono L+R
-- 4. No mono, Hard Left pan
-- 5. No mono, Hard Right pan
-- 6. No mono, Center pan

function PakettiSelectedTrackMonoCycle()
  local track = renoise.song().selected_track
  local mono_device_index = nil
  local mono_device = nil
  
  -- Check for existing "Mono" device in the track
  for i = 2, #track.devices do
    if track.devices[i].display_name == "Mono" then
      mono_device_index = i
      mono_device = track.devices[i]
      break
    end
  end
  
  if mono_device then
    -- Mono device exists, check its state via parameter 3 (Mono Mix)
    -- Parameter 3: -1.0 = L only, 0.0 = L+R, 1.0 = R only
    local mono_mix = mono_device.parameters[3].value
    
    if mono_mix < -0.3 then
      -- Currently L only, cycle to R only
      mono_device.parameters[3].value = 1.0
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Selected Track: Mono R only")
    elseif mono_mix > 0.3 then
      -- Currently R only, cycle to L+R
      mono_device.parameters[3].value = 0.0
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Selected Track: Mono L+R")
    else
      -- Currently L+R, cycle to remove mono and set Hard Left pan
      track:delete_device_at(mono_device_index)
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.0
      renoise.app():show_status("Selected Track: Hard Left Pan")
    end
  else
    -- No mono device exists, check panning state
    local postfx_pan = track.postfx_panning.value
    
    if postfx_pan < 0.2 then
      -- Currently Hard Left, cycle to Hard Right
      track.postfx_panning.value = 1.0
      renoise.app():show_status("Selected Track: Hard Right Pan")
    elseif postfx_pan > 0.8 then
      -- Currently Hard Right, cycle to Center
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Selected Track: Center Pan")
    else
      -- Currently Center (or other), cycle to Mono L only
      local new_mono = track:insert_device_at("Audio/Effects/Native/Stereo Expander", #track.devices + 1)
      new_mono.display_name = "Mono"
      new_mono.parameters[1].value = 0     -- Width to 0 (mono)
      new_mono.parameters[3].value = -1.0  -- Mono Mix to L only
      new_mono.is_maximized = false
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Selected Track: Mono L only")
    end
  end
end

function PakettiMasterTrackMonoCycle()
  local song = renoise.song()
  local track = song:track(song.sequencer_track_count + 1)
  local mono_device_index = nil
  local mono_device = nil
  
  -- Check for existing "Mono" device in the track
  for i = 2, #track.devices do
    if track.devices[i].display_name == "Mono" then
      mono_device_index = i
      mono_device = track.devices[i]
      break
    end
  end
  
  if mono_device then
    -- Mono device exists, check its state via parameter 3 (Mono Mix)
    -- Parameter 3: -1.0 = L only, 0.0 = L+R, 1.0 = R only
    local mono_mix = mono_device.parameters[3].value
    
    if mono_mix < -0.3 then
      -- Currently L only, cycle to R only
      mono_device.parameters[3].value = 1.0
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Master Track: Mono R only")
    elseif mono_mix > 0.3 then
      -- Currently R only, cycle to L+R
      mono_device.parameters[3].value = 0.0
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Master Track: Mono L+R")
    else
      -- Currently L+R, cycle to remove mono and set Hard Left pan
      track:delete_device_at(mono_device_index)
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.0
      renoise.app():show_status("Master Track: Hard Left Pan")
    end
  else
    -- No mono device exists, check panning state
    local postfx_pan = track.postfx_panning.value
    
    if postfx_pan < 0.2 then
      -- Currently Hard Left, cycle to Hard Right
      track.postfx_panning.value = 1.0
      renoise.app():show_status("Master Track: Hard Right Pan")
    elseif postfx_pan > 0.8 then
      -- Currently Hard Right, cycle to Center
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Master Track: Center Pan")
    else
      -- Currently Center (or other), cycle to Mono L only
      local new_mono = track:insert_device_at("Audio/Effects/Native/Stereo Expander", #track.devices + 1)
      new_mono.display_name = "Mono"
      new_mono.parameters[1].value = 0     -- Width to 0 (mono)
      new_mono.parameters[3].value = -1.0  -- Mono Mix to L only
      new_mono.is_maximized = false
      track.prefx_panning.value = 0.5
      track.postfx_panning.value = 0.5
      renoise.app():show_status("Master Track: Mono L only")
    end
  end
end

-- Add keybindings for mono cycler functions
renoise.tool():add_keybinding{name="Global:Paketti:Selected Track Mono/Pan Cycle",invoke=function() PakettiSelectedTrackMonoCycle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Master Track Mono/Pan Cycle",invoke=function() PakettiMasterTrackMonoCycle() end}

renoise.tool():add_menu_entry{name="Mixer:Paketti:TKNA:Selected Track Mono/Pan Cycle",invoke=function() PakettiSelectedTrackMonoCycle() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:TKNA:Master Track Mono/Pan Cycle",invoke=function() PakettiMasterTrackMonoCycle() end}

renoise.tool():add_midi_mapping{name="Paketti:Selected Track Mono/Pan Cycle",invoke=function(message) if message:is_trigger() then PakettiSelectedTrackMonoCycle() end end}
renoise.tool():add_midi_mapping{name="Paketti:Master Track Mono/Pan Cycle",invoke=function(message) if message:is_trigger() then PakettiMasterTrackMonoCycle() end end}

-- Helper function to find current section boundaries
function findCurrentSectionBounds()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence
  
  -- Find the start of current section
  local section_start = current_sequence_index
  while section_start > 1 and not sequencer:sequence_is_start_of_section(section_start) do
    section_start = section_start - 1
  end
  
  -- Find the end of current section
  local section_end = total_sequences
  for i = section_start + 1, total_sequences do
    if sequencer:sequence_is_start_of_section(i) then
      section_end = i - 1
      break
    end
  end
  
  return section_start, section_end
end

-- MIDI knob for selecting pattern within current section
function midiSelectPatternWithinSection(midi_value)
  local song = renoise.song()
  local section_start, section_end = findCurrentSectionBounds()
  local section_length = section_end - section_start + 1
  
  if section_length <= 1 then
    renoise.app():show_status("Current section only has 1 pattern")
    return
  end
  
  -- Map 0-127 to 1-section_length
  local pattern_index = math.floor((midi_value / 127) * (section_length - 1)) + 1
  local target_sequence = section_start + pattern_index - 1
  
  if target_sequence <= section_end then
    song.selected_sequence_index = target_sequence
    renoise.app():show_status(string.format("Selected pattern %d of %d in current section", pattern_index, section_length))
  end
end

-- Function to jump to specific pattern number within current section
function jumpToPatternInSection(pattern_number)
  local song = renoise.song()
  local section_start, section_end = findCurrentSectionBounds()
  local section_length = section_end - section_start + 1
  
  if pattern_number > section_length then
    renoise.app():show_status(string.format("Pattern %d not available in current section (only has %d patterns)", pattern_number, section_length))
    return
  end
  
  local target_sequence = section_start + pattern_number - 1
  song.selected_sequence_index = target_sequence
  renoise.app():show_status(string.format("Jumped to pattern %d of %d in current section", pattern_number, section_length))
end

-- Function to jump to next section
function jumpToNextSection()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_sequence_index = song.selected_sequence_index
  local total_sequences = #sequencer.pattern_sequence
  
  -- Find current section end
  local _, section_end = findCurrentSectionBounds()
  
  -- Look for next section start
  local next_section_start = nil
  for i = section_end + 1, total_sequences do
    if sequencer:sequence_is_start_of_section(i) then
      next_section_start = i
      break
    end
  end
  
  if next_section_start then
    song.selected_sequence_index = next_section_start
    renoise.app():show_status("Jumped to next section")
  else
    renoise.app():show_status("There are no further sections to jump to")
  end
end

-- Function to jump to previous section
function jumpToPreviousSection()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_sequence_index = song.selected_sequence_index
  
  -- Find current section start
  local section_start, _ = findCurrentSectionBounds()
  
  if section_start == 1 then
    renoise.app():show_status("You are already on the first section")
    return
  end
  
  -- Look for previous section start
  local previous_section_start = 1
  for i = section_start - 1, 1, -1 do
    if sequencer:sequence_is_start_of_section(i) then
      previous_section_start = i
      break
    end
  end
  
  song.selected_sequence_index = previous_section_start
  renoise.app():show_status("Jumped to previous section")
end

renoise.tool():add_midi_mapping{name="Paketti:Select Pattern Within Section [Knob]", invoke=function(message) if message:is_abs_value() then midiSelectPatternWithinSection(message.int_value) end end}

for i = 1, 16 do
  renoise.tool():add_midi_mapping{name="Paketti:Jump to Pattern " .. formatDigits(2, i) .. " in Section [Trigger]", invoke=function(message) if message:is_trigger() then jumpToPatternInSection(i) end end}
end

for i=1,16 do
  renoise.tool():add_keybinding{name="Global:Paketti:Jump to Pattern " .. formatDigits(2, i) .. " in Section", invoke=function() jumpToPatternInSection(i) end}
end

-- Create keybindings and MIDI mappings for pattern triggering within sections
for i = 1, 16 do
  local pattern_id = formatDigits(2, i)
  
  -- Keybindings for trigger, schedule, and add to schedule
  renoise.tool():add_keybinding{name="Global:Paketti:Select and Trigger Pattern " .. pattern_id .. " in Current Section", invoke=function() selectAndTriggerPatternInSection(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Select and Schedule Pattern " .. pattern_id .. " in Current Section", invoke=function() selectAndSchedulePatternInSection(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Select and Add to Schedule Pattern " .. pattern_id .. " in Current Section", invoke=function() selectAndAddSchedulePatternInSection(i) end}
  
  -- MIDI mappings for trigger, schedule, and add to schedule
  renoise.tool():add_midi_mapping{name="Paketti:Select and Trigger Pattern " .. pattern_id .. " in Current Section [Trigger]", invoke=function(message) if message:is_trigger() then selectAndTriggerPatternInSection(i) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Select and Schedule Pattern " .. pattern_id .. " in Current Section [Trigger]", invoke=function(message) if message:is_trigger() then selectAndSchedulePatternInSection(i) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Select and Add to Schedule Pattern " .. pattern_id .. " in Current Section [Trigger]", invoke=function(message) if message:is_trigger() then selectAndAddSchedulePatternInSection(i) end end}
end

-- MIDI knob mapping for triggering patterns within current section
renoise.tool():add_midi_mapping{name="Paketti:Trigger Pattern Within Section [Knob]", invoke=function(message) if message:is_abs_value() then midiTriggerPatternWithinSection(message.int_value) end end}

renoise.tool():add_midi_mapping{name="Paketti:Jump to Section (Next) [Trigger]", invoke=function(message) if message:is_trigger() then jumpToNextSection() end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump to Section (Previous) [Trigger]", invoke=function(message) if message:is_trigger() then jumpToPreviousSection() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Jump to Section (Next)", invoke=jumpToNextSection}
renoise.tool():add_keybinding{name="Global:Paketti:Jump to Section (Previous)", invoke=jumpToPreviousSection}

-- Function to select and trigger pattern within current section with different actions (DRY approach)
function tknaSelectTriggerPatternInSection(pattern_number, action)
  local song = renoise.song()
  local section_start, section_end = findCurrentSectionBounds()
  local section_length = section_end - section_start + 1
  
  if pattern_number > section_length then
    renoise.app():show_status(string.format("Pattern %d not available in current section (only has %d patterns)", pattern_number, section_length))
    return
  end
  
  local target_sequence = section_start + pattern_number - 1
  
  -- Select the pattern
  song.selected_sequence_index = target_sequence
  
  -- Perform the specified action
  local action_text = ""
  if action == "trigger" then
    song.transport:trigger_sequence(target_sequence)
    action_text = "triggered"
  elseif action == "schedule" then
    song.transport:set_scheduled_sequence(target_sequence)
    action_text = "scheduled"
  elseif action == "add_schedule" then
    song.transport:add_scheduled_sequence(target_sequence)
    action_text = "added to schedule"
  end
  
  renoise.app():show_status(string.format("Pattern %d of %d in current section %s", pattern_number, section_length, action_text))
end

-- Wrapper functions for different actions
function selectAndTriggerPatternInSection(pattern_number)
  tknaSelectTriggerPatternInSection(pattern_number, "trigger")
end

function selectAndSchedulePatternInSection(pattern_number)
  tknaSelectTriggerPatternInSection(pattern_number, "schedule")
end

function selectAndAddSchedulePatternInSection(pattern_number)
  tknaSelectTriggerPatternInSection(pattern_number, "add_schedule")
end

-- MIDI knob function for triggering patterns within current section
function midiTriggerPatternWithinSection(midi_value)
  local song = renoise.song()
  local section_start, section_end = findCurrentSectionBounds()
  local section_length = section_end - section_start + 1
  
  if section_length <= 1 then
    renoise.app():show_status("Current section only has 1 pattern")
    return
  end
  
  -- Map 0-127 to 1-section_length
  local pattern_index = math.floor((midi_value / 127) * (section_length - 1)) + 1
  local target_sequence = section_start + pattern_index - 1
  
  if target_sequence <= section_end then
    song.selected_sequence_index = target_sequence
    song.transport:trigger_sequence(target_sequence)
    renoise.app():show_status(string.format("Triggered pattern %d of %d in current section", pattern_index, section_length))
  end
end

-- Function to select section with knob and performance lock (can't change sections while playing)
function tknaSelectSectionWithPerformanceLock(midi_value)
  local song = renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local total_sequences = #sequencer.pattern_sequence
  
  -- If transport is playing, don't allow section changes (performance lock)
  if transport.playing then
    renoise.app():show_status("Section locked during playback - stop transport to change sections")
    return
  end
  
  -- Find all section start positions
  local sections = {}
  for i = 1, total_sequences do
    if sequencer:sequence_is_start_of_section(i) then
      table.insert(sections, i)
    end
  end
  
  -- Check if there are any sections
  if #sections == 0 then
    renoise.app():show_status("No sections found in song")
    return
  end
  
  -- Map MIDI value (0-127) to section number (1-N)
  local section_number = math.floor((midi_value / 127) * (#sections - 1)) + 1
  section_number = math.min(section_number, #sections) -- Ensure we don't exceed available sections
  
  local section_start = sections[section_number]
  
  -- Find the end of this section
  local section_end = total_sequences
  if section_number < #sections then
    section_end = sections[section_number + 1] - 1
  end
  
  -- Select, loop, and start playing the section
  song.selected_sequence_index = section_start
  transport.loop_sequence_range = {section_start, section_end}
  
  -- Start playback if not already playing
  if not transport.playing then
    transport.playing = true
  end
  
  -- Trigger the section
  transport:trigger_sequence(section_start)
  
  renoise.app():show_status("Section " .. section_number .. " (pos " .. section_start .. "-" .. section_end .. ") playing (LOCKED)")
end

-- Add MIDI mapping for performance lock section selection
renoise.tool():add_midi_mapping{name="Paketti:Select Section with Performance Lock [Knob]", invoke=function(message) if message:is_abs_value() then tknaSelectSectionWithPerformanceLock(message.int_value) end end}

-- Function to select and loop section by position with different actions (DRY approach)
function tknaSelectLoopSectionByPosition(section_number, action)
  local song=renoise.song()
  local sequencer = song.sequencer
  local transport = song.transport
  local total_sequences = #sequencer.pattern_sequence
  
  -- Find all section start positions
  local sections = {}
  for i = 1, total_sequences do
    if sequencer:sequence_is_start_of_section(i) then
      table.insert(sections, i)
    end
  end
  
  -- Check if the requested section exists
  if section_number > #sections or section_number < 1 then
    renoise.app():show_status("Section " .. section_number .. " does not exist (only " .. #sections .. " sections available)")
    return
  end
  
  local section_start = sections[section_number]
  
  -- Find the end of this section
  local section_end = total_sequences
  if section_number < #sections then
    section_end = sections[section_number + 1] - 1
  end
  
  -- Select and loop the section
  song.selected_sequence_index = section_start
  transport.loop_sequence_range = {section_start, section_end}
  
  -- Perform the specified action
  local action_text = ""
  if action == "trigger" then
    transport:trigger_sequence(section_start)
    action_text = "triggered"
  elseif action == "schedule" then
    transport:set_scheduled_sequence(section_start)
    action_text = "scheduled"
  elseif action == "add_schedule" then
    transport:add_scheduled_sequence(section_start)
    action_text = "added to schedule"
  end
  
  renoise.app():show_status("Section " .. section_number .. " (pos " .. section_start .. "-" .. section_end .. ") " .. action_text .. " and looped.")
end

-- Wrapper functions for backwards compatibility and clarity
function tknaSelectTriggerLoopSectionByPosition(section_number)
  tknaSelectLoopSectionByPosition(section_number, "trigger")
end

function tknaSelectScheduleLoopSectionByPosition(section_number)
  tknaSelectLoopSectionByPosition(section_number, "schedule")
end

function tknaSelectAddScheduleLoopSectionByPosition(section_number)
  tknaSelectLoopSectionByPosition(section_number, "add_schedule")
end

-- Create keybindings and MIDI mappings for Select, Trigger, Schedule, and Add to Schedule for Sections by Position 01 to 32
for i = 1, 32 do
  local section_id = string.format("%02d", i)

  renoise.tool():add_keybinding{name="Global:Paketti:Select&Trigger&Loop Section by Position " .. section_id,invoke=function() tknaSelectTriggerLoopSectionByPosition(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Select&Trigger&Loop Section by Position " .. section_id,invoke=function(message) if message:is_trigger() then tknaSelectTriggerLoopSectionByPosition(i) end end}
  renoise.tool():add_keybinding{name="Global:Paketti:Select&Schedule&Loop Section by Position " .. section_id,invoke=function() tknaSelectScheduleLoopSectionByPosition(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Select&Schedule&Loop Section by Position " .. section_id,invoke=function(message) if message:is_trigger() then tknaSelectScheduleLoopSectionByPosition(i) end end}
  renoise.tool():add_keybinding{name="Global:Paketti:Select&Add to Schedule&Loop Section by Position " .. section_id,invoke=function() tknaSelectAddScheduleLoopSectionByPosition(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Select&Add to Schedule&Loop Section by Position " .. section_id,invoke=function(message) if message:is_trigger() then tknaSelectAddScheduleLoopSectionByPosition(i) end end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select, Trigger and Loop by Position:Select, Trigger and Loop Section by Position " .. section_id,invoke=function() tknaSelectTriggerLoopSectionByPosition(i) end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select, Schedule and Loop by Position:Select, Schedule and Loop Section by Position " .. section_id,invoke=function() tknaSelectScheduleLoopSectionByPosition(i) end}
  renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Sequences/Sections:Select, Add to Schedule and Loop by Position:Select, Add to Schedule and Loop Section by Position " .. section_id,invoke=function() tknaSelectAddScheduleLoopSectionByPosition(i) end}
end

