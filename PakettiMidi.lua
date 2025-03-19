--- This is the way
-- function(message) if message:is_trigger() then
-------------------------------------------------------------------------------------------------------------------------------
renoise.tool():add_midi_mapping{name="Paketti:Groove Settings Groove #2&4 x[Knob]",
  invoke=function(midi_message)
  local ga=renoise.song().transport.groove_amounts
    if not renoise.song().transport.groove_enabled then renoise.song().transport.groove_enabled=true end
    renoise.app().window.active_lower_frame=1
    renoise.song().transport.groove_amounts = {ga[1], midi_message.int_value/127, ga[3], midi_message.int_value/127}
    end}

--Groove Settings, re-written and simplified by mxb
--Control Grooves with a slider
renoise.tool():add_midi_mapping{name="Paketti:Groove Settings Groove #1 x[Knob]",
  invoke=function(midi_message)
  local ga=renoise.song().transport.groove_amounts
    if not renoise.song().transport.groove_enabled then renoise.song().transport.groove_enabled=true end
    renoise.app().window.active_lower_frame=1
    renoise.song().transport.groove_amounts = {midi_message.int_value/127, ga[2], ga[3], ga[4]}
    end}

renoise.tool():add_midi_mapping{name="Paketti:Groove Settings Groove #2 x[Knob]",
  invoke=function(midi_message)
  local ga=renoise.song().transport.groove_amounts
    if not renoise.song().transport.groove_enabled then renoise.song().transport.groove_enabled=true end    
    renoise.app().window.active_lower_frame=1
    renoise.song().transport.groove_amounts = {ga[1], midi_message.int_value/127, ga[3], ga[4]}
    end}

renoise.tool():add_midi_mapping{name="Paketti:Groove Settings Groove #3 x[Knob]",
  invoke=function(midi_message)
  local ga=renoise.song().transport.groove_amounts
    if not renoise.song().transport.groove_enabled then renoise.song().transport.groove_enabled=true end
    renoise.app().window.active_lower_frame=1
    renoise.song().transport.groove_amounts = {ga[1], ga[2], midi_message.int_value/127, ga[4]}
    end}

renoise.tool():add_midi_mapping{name="Paketti:Groove Settings Groove #4 x[Knob]",
  invoke=function(midi_message)
  local ga=renoise.song().transport.groove_amounts
    if not renoise.song().transport.groove_enabled then renoise.song().transport.groove_enabled=true end
    renoise.app().window.active_lower_frame=1
    renoise.song().transport.groove_amounts = {ga[1], ga[2], ga[3], midi_message.int_value/127}
    end}
-----------------------------------------------------------------------------------------------------------------------------------------
-- Control Computer Keyboard Velocity with a slider.
renoise.tool():add_midi_mapping{name="Paketti:Computer Keyboard Velocity Slider x[Knob]",
  invoke=function(midi_message) 
  local t=renoise.song().transport
  if t.keyboard_velocity_enabled==false then t.keyboard_velocity_enabled=true end
     t.keyboard_velocity=midi_message.int_value end}

-- Destructively control Sample volume with a slider
renoise.tool():add_midi_mapping{name="Paketti:Change Selected Sample Volume x[Slider]",invoke=function(midi_message)
renoise.app().window.active_middle_frame=5
renoise.song().selected_sample.volume=midi_message.int_value/127
end}

renoise.tool():add_midi_mapping{name="Paketti:Delay Column (DEPRECATED) x[Slider]",invoke=function(midi_message)
renoise.song().selected_track.delay_column_visible=true
renoise.app().window.active_middle_frame=1
local results = nil

results=midi_message.int_value/127
renoise.song().selected_note_column.delay_value = math.max(0, math.min(257, midi_message.int_value * 2))

-- if midi_message.int_value > 64 then columns(1,1)
-- else if midi_message.int_value < 64 then columns(-1,1)
-- end
-- end

end}
-------------------------------------------------------------------------------------------------------------------------------------
--Midi Mapping for Metronome On/Off Toggle
renoise.tool():add_midi_mapping{name="Paketti:Metronome On/Off x[Toggle]",invoke=function(message) if message:is_trigger() then MetronomeOff() end end}
--Midi Mapping for Expand/Collapse
renoise.tool():add_midi_mapping{name="Paketti:Uncollapser",invoke=function(message) if message:is_trigger() then Uncollapser() end end}
renoise.tool():add_midi_mapping{name="Paketti:Collapser",invoke=function(message) if message:is_trigger() then Collapser() end end} 
-------------------------------------------------------------------------------------------------------------------------------------
--- Show or hide pattern matrix
function showhidepatternmatrix()
local pmi=renoise.app().window.pattern_matrix_is_visible
  if pmi==true then pmi=false else pmi=true end
end

renoise.tool():add_midi_mapping{name="Paketti:Show/Hide Pattern Matrix x[Toggle]",invoke=function(message) if message:is_trigger() then showhidepatternmatrix() end end}
-----------------------------------------------------------------------------------------------------------------------------------------
--- Show or hide pattern matrix
function MidiRecordAndFollowToggle()
local t=renoise.song().transport
local w=renoise.app().window
if t.edit_mode == true then 
t.edit_mode = false
t.follow_player = false
t.playing = false
else
t.edit_mode = true
t.follow_player = true
t.playing = true
w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
w.lock_keyboard_focus = true

end
end

renoise.tool():add_midi_mapping{name="Paketti:Record and Follow x[Toggle]",invoke=function(message) if message:is_trigger() then MidiRecordAndFollowToggle() end end}

renoise.tool():add_midi_mapping{name="Paketti:Record and Follow On/Off x[Knob]",invoke=function(midi_message) 
--Aided by dblue
local t=renoise.song().transport
local w=renoise.app().window
if (midi_message.int_value == 127) then t.edit_mode = true t.follow_player = true t.playing = true
  w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR 
  w.lock_keyboard_focus = true
else end
if (midi_message.int_value == 0) then t.edit_mode = false t.follow_player = false t.playing = false
else end

    if (midi_message.int_value >= 100) then
      t.edit_mode = true
      t.follow_player = true 
      w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR 
      w.lock_keyboard_focus = true      
    else 
      t.edit_mode = false
      t.follow_player = false
    end
end}
---------------------------------------------------------------------------------------------------------------------------
--Record Quantize On/Off for Midi_Mapping
renoise.tool():add_midi_mapping{name="Paketti:Record Quantize On/Off x[Toggle]",
invoke=function(message) if message:is_trigger() then
  if renoise.song().transport.record_quantize_enabled==true then
     renoise.song().transport.record_quantize_enabled=false
  else
     renoise.song().transport.record_quantize_enabled=true
   end end
end}
-----------------------------------------------------------------------------------------------------------------------------------------
renoise.tool():add_midi_mapping{name="Paketti:Impulse Tracker F7 Start Playback from Cursor Row x[Toggle]",  invoke=function(message) if message:is_trigger() then ImpulseTrackerPlayFromLine() end end}
renoise.tool():add_midi_mapping{name="Paketti:Stop Playback (Panic) x[Toggle]",  invoke=function(message) if message:is_trigger() then  ImpulseTrackerStop() end end}
renoise.tool():add_midi_mapping{name="Paketti:Play Current Line & Advance by EditStep x[Toggle]",invoke=function(message) if message:is_trigger() then  PlayCurrentLine() end end}
renoise.tool():add_midi_mapping{name="Paketti:Impulse Tracker Pattern (Next) x[Toggle]",invoke=function(message) if message:is_trigger() then ImpulseTrackerNextPattern() end end}
renoise.tool():add_midi_mapping{name="Paketti:Impulse Tracker Pattern (Previous) x[Toggle]",invoke=function(message) if message:is_trigger() then ImpulseTrackerPrevPattern() end end}

renoise.tool():add_midi_mapping{name="Paketti:Impulse Tracker F5 Start Playback x[Toggle]",invoke=function(message) if message:is_trigger() then  ImpulseTrackerPlaySong() end end}
renoise.tool():add_midi_mapping{name="Paketti:Impulse Tracker F8 Stop Playback (Panic) x[Toggle]",invoke=function(message) if message:is_trigger() then ImpulseTrackerStop() end end}
renoise.tool():add_midi_mapping{name="Paketti:Switch to Automation",invoke=function(message) if message:is_trigger() then  
  local w=renoise.app().window
  local raw=renoise.ApplicationWindow
if raw.MIDDLE_FRAME_MIXER == false and w.active_lower_frame == raw.LOWER_FRAME_TRACK_AUTOMATION 
then w.active_middle_frame=raw.MIDDLE_FRAME_MIXER return
else w.active_middle_frame=raw.MIDDLE_FRAME_MIXER end
showAutomation() end end}

renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (004) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (008) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(8) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (016) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(16) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (032) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(32) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (064) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(64) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (128) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(128) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe&Slice (256) x[Toggle]",invoke=function(message) if message:is_trigger() then slicerough(256) end end}

renoise.tool():add_midi_mapping{name="Paketti:Set Delay (+1) x[Toggle]",invoke=function(message) if message:is_trigger() then delayInput(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Delay (-1) x[Toggle]",invoke=function(message) if message:is_trigger() then delayInput(-1) end end}


-----------------------------------------------------------------------------------------------------------------------------------------
-- //TODO check that these work

renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 0 x[Toggle]",  invoke=function(message) if message:is_trigger() then selectplay(0) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 1 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 2 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(2) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 3 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(3) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 4 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 5 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(5) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 6 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(6) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 7 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(7) end end}
renoise.tool():add_midi_mapping{name="Paketti:Numpad SelectPlay 8 x[Toggle]",  invoke=function(message) if message:is_trigger() then  selectplay(8) end end}

renoise.tool():add_midi_mapping{name="Paketti:Capture Nearest Instrument and Octave",invoke=function(message) if message:is_trigger() then capture_ins_oct() end end} 
renoise.tool():add_midi_mapping{name="Paketti:Simple Play",invoke=function(message) if message:is_trigger() then simpleplay() end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Delay Increase (+1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columns(1,1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Delay Decrease (-1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columns(-1,1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Panning Increase (+1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columns(1,2) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Panning Decrease (-1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columns(-1,2) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Volume Increase (+1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columns(1,3) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Volume Decrease (-1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columns(-1,3) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Effect Number Increase (+1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columnspart2(1,4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Effect Number Decrease (-1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columnspart2(-1,4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Effect Amount Increase (+1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columnspart2(1,5) end end}
renoise.tool():add_midi_mapping{name="Paketti:Columnizer Effect Amount Decrease (-1) x[Toggle]",invoke=function(message) if message:is_trigger() then  columnspart2(-1,5) end end}

--[[renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Disk Browser Focus",invoke=function()
renoise.app().window.lock_keyboard_focus=false
renoise.app().window:select_preset(7) end}

renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Disk Browser Focus",invoke=function() renoise.app().window:select_preset(8) end}
]]--

renoise.tool():add_midi_mapping{name="Paketti:Change Selected Sample Loop Mode x[Knob]",
  invoke = function(midi_message)
    local value = midi_message.int_value
    local loop_modes = {
      [0] = 1,   -- No Loop
      [1] = 2,   -- Forward Loop
      [2] = 3,   -- Backward Loop
      [3] = 4    -- PingPong Loop
    }
    if value == 0 then
      renoise.song().selected_sample.loop_mode = loop_modes[0] -- No Loop
    elseif value >= 1 and value <= 63 then
      renoise.song().selected_sample.loop_mode = loop_modes[1] -- Forward Loop
    elseif value >= 64 and value <= 126 then
      renoise.song().selected_sample.loop_mode = loop_modes[2] -- Backward Loop
    elseif value == 127 then
      renoise.song().selected_sample.loop_mode = loop_modes[3] -- PingPong Loop
    end
  end
}

function selectedSampleLoopTo(loopMode)
renoise.song().selected_sample.loop_mode=loopMode
end

function toggleSelectedSampleLoopTo(loopMode)
      if renoise.song().selected_sample.loop_mode==loopMode
      then renoise.song().selected_sample.loop_mode = 1
      else renoise.song().selected_sample.loop_mode=loopMode
      end
end

renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 1 No Loop x[On]",invoke=function() selectedSampleLoopTo(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 2 Forward x[On]",invoke=function() selectedSampleLoopTo(2) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 3 Backward x[On]",invoke=function() selectedSampleLoopTo(3) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 4 PingPong x[On]",invoke=function() selectedSampleLoopTo(4) end}

renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 1 No Loop x[Toggle]",invoke=function() toggleSelectedSampleLoopTo(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 2 Forward x[Toggle]",invoke=function() toggleSelectedSampleLoopTo(2) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 3 Backward x[Toggle]",invoke=function() toggleSelectedSampleLoopTo(3) end}
renoise.tool():add_midi_mapping{name="Paketti:Selected Sample Loop to 4 PingPong x[Toggle]",invoke=function() toggleSelectedSampleLoopTo(4) end}

renoise.tool():add_midi_mapping{name="Paketti:Record to Current Track x[Toggle]",invoke=function() 
  recordtocurrenttrack()
  local t=renoise.song().transport
  if t.playing==false then t.playing=true end
  t.loop_block_enabled=false
  t.follow_player=true
  renoise.app().window.active_lower_frame=2
  renoise.app().window.lower_frame_is_visible=true
  -- Uncomment and refine these for specific playback position control if needed:
  -- local startpos = t.playback_pos  
  -- startpos.line = renoise.song().selected_line_index
  -- startpos.sequence = renoise.song().selected_sequence_index
  -- t.playback_pos = startpos
  -- t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN)
end}

renoise.tool():add_midi_mapping{name="Paketti:Simple Play Record Follow",invoke=function() simpleplayrecordfollow() end}

--------------
function midiEnableDSP(deviceNumber,onOrOff)
if #renoise.song().selected_track.devices < 2 then return
else 
local deviceNumberActual = deviceNumber+1
if #renoise.song().selected_track.devices < deviceNumberActual then return
else
renoise.song().selected_track.devices[deviceNumberActual].is_active = onOrOff
end
end
end

function midiToggleDSP(deviceNumber)

if #renoise.song().selected_track.devices < 2 then return
else 
local deviceNumberActual = deviceNumber+1
if #renoise.song().selected_track.devices < deviceNumberActual then return
else
if renoise.song().selected_track.devices[deviceNumberActual].is_active == true then
renoise.song().selected_track.devices[deviceNumberActual].is_active = false
else
renoise.song().selected_track.devices[deviceNumberActual].is_active = true
end
end
end
end

for i = 1, 9 do 
renoise.tool():add_midi_mapping{name="Paketti:Enable Track DSP Device 0" .. i,invoke=function() midiEnableDSP(i, true) end}
end

for i = 10, 32 do 
renoise.tool():add_midi_mapping{name="Paketti:Enable Track DSP Device " .. i,invoke=function() midiEnableDSP(i, true) end}
end


for i = 1, 9 do 
renoise.tool():add_midi_mapping{name="Paketti:Disable Track DSP Device 0" .. i,invoke=function() midiEnableDSP(i, false) end}
end

for i = 10, 32 do 
renoise.tool():add_midi_mapping{name="Paketti:Disable Track DSP Device " .. i,invoke=function() midiEnableDSP(i, false) end}
end

for i = 1, 9 do 
renoise.tool():add_midi_mapping{name="Paketti:Toggle Track DSP Device 0" .. i,invoke=function() midiToggleDSP(i) end}
end

for i = 10, 32 do 
renoise.tool():add_midi_mapping{name="Paketti:Toggle Track DSP Device " .. i,invoke=function() midiToggleDSP(i) end}
end

-------
renoise.tool():add_midi_mapping{name="Paketti:Midi Change EditStep 1-64 x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      -- Pass the actual property object, not just the value
      midiValues(1, 64, renoise.song().transport, 'edit_step', message.int_value)
    end
  end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Change EditStep 0-64 x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      -- Pass the actual property object, not just the value
      midiValues(0, 64, renoise.song().transport, 'edit_step', message.int_value)
    end
  end}

  renoise.tool():add_midi_mapping{name="Paketti:Midi Change LPB 1-64 x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      -- Pass the actual property object, not just the value
      midiValues(1, 64, renoise.song().transport, 'lpb', message.int_value)
    end
  end}



-- A function to handle MIDI input and map it to a specified range and property
function midiValues(minValue, maxValue, object, propertyName, midiInput)
  local scaledValue = scaleValue(midiInput, 0, 127, minValue, maxValue)
  -- Set the property on the object using propertyName
  object[propertyName] = math.floor(math.max(minValue, math.min(scaledValue, maxValue)))
end

-- Scales an input value from a given input range to a specified output range
function scaleValue(input, inputMin, inputMax, outputMin, outputMax)
  local scale = (outputMax - outputMin) / (inputMax - inputMin)
  local output = (input - inputMin) * scale + outputMin
  return output
end


function midiMappedEditStep(stepNumber)
renoise.song().transport.edit_step = stepNumber
end

for i=0,9 do
renoise.tool():add_midi_mapping{name="Paketti:Set EditStep to 0" .. i,invoke=function() midiMappedEditStep(i) end}
end

for i=10,64 do
renoise.tool():add_midi_mapping{name="Paketti:Set EditStep to " .. i,invoke=function() midiMappedEditStep(i) end}
end
------
renoise.tool():add_midi_mapping{name="Paketti:Midi Select Group (Previous)",invoke=function(message) if message:is_trigger() then selectPreviousGroupTrack() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Select Group (Next)",invoke=function(message) if message:is_trigger() then  selectNextGroupTrack() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Select Track (Previous)",invoke=function(message) if message:is_trigger() then  selectPreviousTrack() end end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Select Track (Next)",invoke=function(message) if message:is_trigger() then  selectNextTrack() end end}
-----
-- Retrieve all group track indices
function groupTrackIndices()
    local song = renoise.song()
    local indices = {}
    for i = 1, #song.tracks do
        if song.tracks[i].type == renoise.Track.TRACK_TYPE_GROUP then
            table.insert(indices, i)
        end
    end
    return indices
end

-- Function to select a group track by index
function selectGroupTrackByIndex(index)
    local song = renoise.song()
    local groups = groupTrackIndices()
    if #groups > 0 and index >= 1 and index <= #groups then
        song.selected_track_index = groups[index]
    end
end

-- Handle MIDI input and map it to group track selection
function changeGroupTrackWithMidi(message)
    if message:is_abs_value() then
        local group_count = #groupTrackIndices()
        local index = scaleValue(message.int_value, 0, 127, 1, group_count)
        selectGroupTrackByIndex(math.floor(index))
    end
end


renoise.tool():add_midi_mapping{name="Paketti:Midi Select Group Tracks x[Knob]",invoke=changeGroupTrackWithMidi}
--------
--
renoise.tool():add_midi_mapping{name="Paketti:Midi Change Octave x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      midiValues(0, 8, renoise.song().transport, 'octave', message.int_value)
    end
end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Change Selected Track x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local trackCount = #renoise.song().tracks
      midiValues(1, trackCount, renoise.song(), 'selected_track_index', message.int_value)
    end
end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Change Selected Track DSP Device x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local deviceCount = #renoise.song().selected_track.devices
    if deviceCount < 2 then 
    renoise.app():show_status("There are no Track DSP Devices on this channel.")
    else
      midiValues(2, deviceCount, renoise.song(), 'selected_device_index', message.int_value)
    end
    end
end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Change Selected Instrument x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local instrumentCount = #renoise.song().instruments
      midiValues(1, instrumentCount, renoise.song(), 'selected_instrument_index', message.int_value)
    end
end}
----------------
renoise.tool():add_midi_mapping{name="Paketti:Midi Change Selected Sample Loop 01 Start x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local sampleEndPosition = renoise.song().selected_sample.loop_end -1
      midiValues(1, sampleEndPosition, renoise.song().selected_sample, 'loop_start', message.int_value)
    end
end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Change Selected Sample Loop 02 End x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local loopStart = renoise.song().selected_sample.loop_start
      midiValues(loopStart, renoise.song().selected_sample.sample_buffer.number_of_frames, renoise.song().selected_sample, 'loop_end', message.int_value)
    end
end}

renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Sample Buffer Selection 01 Start x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local selectionEnd=renoise.song().selected_sample.sample_buffer.selection_end
    local selectionStart=renoise.song().selected_sample.sample_buffer.selection_start
    local range=renoise.song().selected_sample.sample_buffer.selection_range 
      midiValues(1, renoise.song().selected_sample.sample_buffer.number_of_frames, renoise.song().selected_sample.sample_buffer, 'selection_start', message.int_value)
    end
end}

renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Sample Buffer Selection 02 End x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
    local selectionEnd=renoise.song().selected_sample.sample_buffer.selection_end
    local selectionStart=renoise.song().selected_sample.sample_buffer.selection_start
    local range=renoise.song().selected_sample.sample_buffer.selection_range
      midiValues(1, renoise.song().selected_sample.sample_buffer.number_of_frames, renoise.song().selected_sample.sample_buffer, 'selection_end', message.int_value)
    end
end}
----------
-- List of available automation curve functions
local automation_curves = {
  "apply_constant_automation_bottom_to_bottom", -- 0 to 0
  "apply_selection_up_linear", -- line 0..1
  "apply_exponential_automation_curveUP", -- curve 0..1
  "apply_constant_automation_top_to_top", -- 1 to 1
  "apply_selection_down_linear", -- line 1..0
  "apply_exponential_automation_curveDOWN", -- exp 1..0
  "apply_constant_automation_bottom_to_bottom", -- 0 to 0
}

-- Function to apply the selected automation curve based on index
function apply_automation_curve_by_index(index, curves)
  local curve_function_name = curves[index]
  if curve_function_name and _G[curve_function_name] then
    _G[curve_function_name]()
  end
end

renoise.tool():add_midi_mapping{name="Track Automation:Paketti:Midi Automation Curve Draw Selection x[Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      local selected_parameter = renoise.song().selected_automation_parameter
      local curves_to_use = automation_curves
      local num_curves = #automation_curves

      -- Check if the selected automation parameter is PitchBend, Pitch, or Panning
      if selected_parameter and (
        selected_parameter.name == "PitchBend" or
        selected_parameter.name == "Pitchbend" or
        selected_parameter.name == "Pitch" or
        selected_parameter.name == "Panning"
      ) then
        -- Filter the curves for the specific parameter
        curves_to_use = {
          "set_to_center",
          "center_up_linear", -- line center->up 
          "apply_exponential_automation_curve_center_to_top", -- curve center->up
          "apply_constant_automation_top_to_top", -- max up
          "up_center_linear", -- line up->center
          "apply_exponential_automation_curve_top_to_center", -- curve up->center
          "center_down_linear", -- line center->down
          "apply_exponential_automation_curve_center_to_bottom", -- curve center->down
          "apply_constant_automation_bottom_to_bottom", -- min bottom
          "down_center_linear", -- line down->center
          "apply_exponential_automation_curve_bottom_to_center", -- curve down->center
          "set_to_center" -- set to center
        }
        num_curves = #curves_to_use
      end

      local step = 128 / num_curves
      local index = math.floor(message.int_value / step) + 1
      index = math.min(index, num_curves) -- Ensure the index is within bounds

      apply_automation_curve_by_index(index, curves_to_use)
    end
  end
}

-- Define the function to set the automation point value based on MIDI input
function midiValuesAutomation(start_point, end_point, automation, property, value)
  -- Convert MIDI value (0-127) to automation range (start_point to end_point)
  local converted_value = start_point + (value / 127) * (end_point - start_point)
  local selection_range = automation.selection_range

  if property == 'selection_start' then
    selection_range[1] = converted_value
    if selection_range[2] < selection_range[1] then
      selection_range[2] = selection_range[1]
    end
  elseif property == 'selection_end' then
    selection_range[2] = converted_value
    if selection_range[1] > selection_range[2] then
      selection_range[1] = selection_range[2]
    end
  end

  automation.selection_range = selection_range
end

-- MIDI mapping for changing the start point of the automation selection
renoise.tool():add_midi_mapping{name="Paketti:Midi Automation Selection 01 Start x[Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      local automation = renoise.song().selected_pattern_track:find_automation(renoise.song().selected_automation_parameter)
      if automation then
        local start_point = 1
        local end_point = automation.length + 1
        midiValuesAutomation(start_point, end_point, automation, 'selection_start', message.int_value)
      end
    end
  end
}

-- MIDI mapping for changing the end point of the automation selection
renoise.tool():add_midi_mapping{name="Paketti:Midi Automation Selection 02 End x[Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      local automation = renoise.song().selected_pattern_track:find_automation(renoise.song().selected_automation_parameter)
      if automation then
        local start_point = 1
        local end_point = automation.length + 1
        midiValuesAutomation(start_point, end_point, automation, 'selection_end', message.int_value)
      end
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Create New Instrument & Loop from Selection",invoke=function(message) if message:is_trigger() then create_new_instrument_from_selection() end end}
--------------

-- Global table to keep track of added MIDI mappings
local added_midi_mappings = {}

-- Function to map MIDI values to macro values
function map_midi_value_to_macro(macro_index, midi_value)
  -- Ensure renoise.song() is available
  if not pcall(renoise.song) then
    renoise.app():show_status("No song is currently loaded.")
    return
  end

  -- Ensure the macro index is within the valid range (1 to 8)
  if macro_index < 1 or macro_index > 8 then
    renoise.app():show_status("Macro index must be between 1 and 8")
    return
  end

  -- Ensure the MIDI value is within the valid range (0 to 127)
  if midi_value < 0 or midi_value > 127 then
    renoise.app():show_status("MIDI value must be between 0 and 127")
    return
  end

  -- Convert the MIDI value to a range of 0 to 1
  local macro_value = midi_value / 127

  -- Set the value of the specified macro
  renoise.song().selected_instrument.macros[macro_index].value = macro_value
end

-- Static MIDI mappings for each of the 8 macros
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 1 (PitchBend)",invoke=function(midi_message) map_midi_value_to_macro(1, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 2 (Cutoff)",invoke=function(midi_message) map_midi_value_to_macro(2, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 3 (Resonance)",invoke=function(midi_message) map_midi_value_to_macro(3, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 4 (Cutoff LfoAmp)",invoke=function(midi_message) map_midi_value_to_macro(4, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 5 (Cutoff LfoFreq)",invoke=function(midi_message) map_midi_value_to_macro(5, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 6 (Overdrive)",invoke=function(midi_message) map_midi_value_to_macro(6, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 7 (ParallelCompression)",invoke=function(midi_message) map_midi_value_to_macro(7, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 8 (PB Inertia)",invoke=function(midi_message) map_midi_value_to_macro(8, midi_message.int_value) end}

renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 1 (2nd) (PitchBend)",invoke=function(midi_message) map_midi_value_to_macro(1, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 2 (2nd) (Cutoff)",invoke=function(midi_message) map_midi_value_to_macro(2, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 3 (2nd) (Resonance)",invoke=function(midi_message) map_midi_value_to_macro(3, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 4 (2nd) (Cutoff LfoAmp)",invoke=function(midi_message) map_midi_value_to_macro(4, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 5 (2nd) (Cutoff LfoFreq)",invoke=function(midi_message) map_midi_value_to_macro(5, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 6 (2nd) (Overdrive)",invoke=function(midi_message) map_midi_value_to_macro(6, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 7 (2nd) (ParallelCompression)",invoke=function(midi_message) map_midi_value_to_macro(7, midi_message.int_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Macro 8 (2nd) (PB Inertia)",invoke=function(midi_message) map_midi_value_to_macro(8, midi_message.int_value) end}


----------------
-- Script to map MIDI values to sample modulation set filter types in Renoise
-- Ensure this script is named 'Paketti_Midi_Change_Sample_Modulation_Set_Filter.lua'

-- Define a function to change the sample modulation set filter type based on MIDI value
function change_sample_modulation_set_filter(midi_value)
  -- Get the current song
  local song = renoise.song()
  
  -- Check if a sample and modulation set are selected
  if song.selected_sample and song.selected_sample_modulation_set then
    -- Get the available filter types
    local filter_types = song.selected_sample_modulation_set.available_filter_types
    
    -- Calculate the index in the filter types list based on the MIDI value
    local index = math.floor((midi_value / 127) * (#filter_types - 1)) + 1
    
    -- Set the filter type
    song.selected_sample_modulation_set.filter_type = filter_types[index]
    
    -- Show status message with the selected filter type
    renoise.app():show_status("Selected Filter Type: " .. filter_types[index])
  else
    -- Show status message if no sample or modulation set is selected
    renoise.app():show_status("No sample or modulation set selected")
  end
end

-- Add MIDI mapping for the function
renoise.tool():add_midi_mapping{name="Paketti:Midi Change Sample Modulation Set Filter",invoke=function(message)
  -- Call the function with the MIDI value
  change_sample_modulation_set_filter(message.int_value)
end}

---------
function midiprogram(change)  
local midi=renoise.song().selected_instrument.midi_output_properties  
local currentprg=midi.program  
 currentprg = math.max(0, math.min(128, currentprg + change))  
 rprint (currentprg)  
renoise.song().selected_instrument.midi_output_properties.program = currentprg  
renoise.song().transport:panic()  
end  
  
renoise.tool():add_keybinding{name="Global:Paketti:Selected Instrument Midi Program +1 (Next)",invoke=function() midiprogram(1) end}  
renoise.tool():add_keybinding{name="Global:Paketti:Selected Instrument Midi Program -1 (Previous)",invoke=function() midiprogram(-1) end}  
renoise.tool():add_midi_mapping{name="Paketti:Selected Instrument Midi Program +1 (Next)",invoke=function(message) if message:is_trigger() then midiprogram(1) end end}  
renoise.tool():add_midi_mapping{name="Paketti:Selected Instrument Midi Program -1 (Previous)",invoke=function(message) if message:is_trigger() then midiprogram(-1) end end}  
-----------
function pakettiMidiValuesColumn(minValue, maxValue, note_column_index, propertyName, midiInput)
  local scaledValue = pakettiScaleValuesColumn(midiInput, 0, 127, minValue, maxValue)
  local song = renoise.song()
  local selection = song.selection_in_pattern

  -- Handle cases where no note column is selected
  if renoise.song().selected_note_column_index == nil or renoise.song().selected_note_column_index == 0 then 
    note_column_index = 1
  end
  
  if selection then
    -- Loop through the selected tracks
    for track_idx = selection.start_track, selection.end_track do
      local track = song:track(track_idx)

      -- Skip group, send, or master tracks (track types 2, 3, 4)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER  then
        local visible_note_columns = track.visible_note_columns or 0 -- Handle cases with 0 or no note columns

        -- Only process if the track has visible note columns
        if visible_note_columns > 0 then
          -- Loop through the selected lines
          for line = selection.start_line, selection.end_line do
            local line_data = song:pattern(song.selected_pattern_index):track(track_idx):line(line)
            
            -- Determine the column range for this track
            local start_column = (track_idx == selection.start_track) and selection.start_column or 1
            local end_column = (track_idx == selection.end_track) and selection.end_column or visible_note_columns

            -- Modify the note columns in the selected range
            for col_idx = start_column, end_column do
              if col_idx <= visible_note_columns then
                local note_col = line_data.note_columns[col_idx]
                if note_col then
                  note_col[propertyName] = math.floor(math.max(minValue, math.min(scaledValue, maxValue)))
                end
              end
            end
          end
        end
      end
    end
  else
    -- Single-line modification if no selection
    local track = song:track(song.selected_track_index)

    -- Skip group, send, or master tracks
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      if track.visible_note_columns and track.visible_note_columns > 0 then
        local note_col = song.selected_line.note_columns[note_column_index]
        if note_col then
          note_col[propertyName] = math.floor(math.max(minValue, math.min(scaledValue, maxValue)))
        end
      end
    end
  end
end

-- Scales an input value from a given input range to a specified output range
function pakettiScaleValuesColumn(input, inputMin, inputMax, outputMin, outputMax)
  local scale = (outputMax - outputMin) / (inputMax - inputMin)
  local output = (input - inputMin) * scale + outputMin
  return output
end




-- Volume Column MIDI Mapping
renoise.tool():add_midi_mapping{name="Paketti:Midi Change 01 Volume Column Value x[Knob]",invoke=function(message)
  if message:is_abs_value() then
    local song = renoise.song()
    local selection = song.selection_in_pattern
    
    -- Check if there's an active selection in the pattern
    if selection then
      -- Iterate over all tracks in the selection
      for track_idx = selection.start_track, selection.end_track do
        local track = song:track(track_idx)
        -- Set the volume column visible if the track is a sequencer track
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          track.volume_column_visible = true
        end
      end
    else
      -- If no selection, apply to the currently selected track
      local track = song.selected_track
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.volume_column_visible = true
      end
    end
    
    -- Apply the volume value change using the pakettiMidiValuesColumn function
    pakettiMidiValuesColumn(0, 128, song.selected_note_column_index, 'volume_value', message.int_value)
  end
end}

-- Panning Column MIDI Mapping
renoise.tool():add_midi_mapping{name="Paketti:Midi Change 02 Panning Column Value x[Knob]",invoke=function(message)
  if message:is_abs_value() then
    local song = renoise.song()
    local selection = song.selection_in_pattern
    
    -- Check if there's an active selection in the pattern
    if selection then
      -- Iterate over all tracks in the selection
      for track_idx = selection.start_track, selection.end_track do
        local track = song:track(track_idx)
        -- Set the panning column visible if the track is a sequencer track
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          track.panning_column_visible = true
        end
      end
    else
      -- If no selection, apply to the currently selected track
      local track = song.selected_track
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.panning_column_visible = true
      end
    end
    
    -- Apply the panning value change using the pakettiMidiValuesColumn function
    pakettiMidiValuesColumn(0, 128, song.selected_note_column_index, 'panning_value', message.int_value)
  end
end}

-- Delay Column MIDI Mapping
renoise.tool():add_midi_mapping{name="Paketti:Midi Change 03 Delay Column Value x[Knob]",invoke=function(message)
  if message:is_abs_value() then
    local song = renoise.song()
    local selection = song.selection_in_pattern
    
    -- Check if there's an active selection in the pattern
    if selection then
      -- Iterate over all tracks in the selection
      for track_idx = selection.start_track, selection.end_track do
        local track = song:track(track_idx)
        -- Set the delay column visible if the track is a sequencer track
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          track.delay_column_visible = true
        end
      end
    else
      -- If no selection, apply to the currently selected track
      local track = song.selected_track
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.delay_column_visible = true
      end
    end
    
    -- Apply the delay value change using the pakettiMidiValuesColumn function
    pakettiMidiValuesColumn(0, 255, song.selected_note_column_index, 'delay_value', message.int_value)
  end
end}

-- Sample FX Column MIDI Mapping
renoise.tool():add_midi_mapping{name="Paketti:Midi Change 04 Sample FX Column Value x[Knob]",invoke=function(message)
  if message:is_abs_value() then
    local song = renoise.song()
    local selection = song.selection_in_pattern
    
    -- Check if there's an active selection in the pattern
    if selection then
      -- Iterate over all tracks in the selection
      for track_idx = selection.start_track, selection.end_track do
        local track = song:track(track_idx)
        -- Set the sample effects column visible if the track is a sequencer track
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          track.sample_effects_column_visible = true
        end
      end
    else
      -- If no selection, apply to the currently selected track
      local track = song.selected_track
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.sample_effects_column_visible = true
      end
    end
    
    -- Apply the sample FX value change using the pakettiMidiValuesColumn function
    pakettiMidiValuesColumn(0, 255, song.selected_note_column_index, 'effect_amount_value', message.int_value)
  end
end}

-- Function to process MIDI values and set the appropriate property
function pakettiMidiValuesEffectColumn(minValue, maxValue, effect_column_index, propertyName, midiInput)
  local scaledValue = pakettiScaleValuesColumn(midiInput, 0, 127, minValue, maxValue)
local song = renoise.song()
local selection = song.selection_in_pattern

if selection then
  for track_idx = selection.start_track, selection.end_track do
    local track = song:track(track_idx)
    local visible_note_columns = track.visible_note_columns or 0 -- Handle cases where note columns might be 0 or nil
    local visible_effect_columns = track.visible_effect_columns
    local total_visible_columns = visible_note_columns + visible_effect_columns

    -- For each line within the selected range
    for line = selection.start_line, selection.end_line do
      local line_data = song:pattern(song.selected_pattern_index):track(track_idx):line(line)

      -- Determine the column range based on track index
      local start_column = (track_idx == selection.start_track) and selection.start_column or 1
      local end_column = (track_idx == selection.end_track) and selection.end_column or total_visible_columns

      -- Adjust the selected columns to match the effect columns in this track
      for col_idx = start_column, end_column do
        if col_idx > visible_note_columns then
          local effect_col_idx = col_idx - visible_note_columns
          if effect_col_idx <= visible_effect_columns then
            -- Modify the effect column
            local effect_column = line_data.effect_columns[effect_col_idx]
            if effect_column then
              effect_column[propertyName] = math.floor(math.max(minValue, math.min(scaledValue, maxValue)))
            end
          end
        end
      end
    end
  end
else
  -- Handle single-line modification if no selection is available
  if renoise.song().selected_effect_column_index ~= 0 then 
      local effect_col_idx = renoise.song().selected_effect_column_index
      local effect_column = song.selected_line.effect_columns[effect_col_idx]
      if effect_column then
        effect_column[propertyName] = math.floor(math.max(minValue, math.min(scaledValue, maxValue)))
      end
  else 
  local effect_column = song.selected_line.effect_columns[1]
  if effect_column then
    effect_column[propertyName] = math.floor(math.max(minValue, math.min(scaledValue, maxValue)))
  end 
  end
  end

end
-- Scales an input value from a given input range to a specified output range
function pakettiScaleValuesEffectColumn(input, inputMin, inputMax, outputMin, outputMax)
  local scale = (outputMax - outputMin) / (inputMax - inputMin)
  local output = (input - inputMin) * scale + outputMin
  return output
end


renoise.tool():add_midi_mapping{name="Paketti:Midi Change 05 Effect Column Value x[Knob]",invoke=function(message)
  if message:is_abs_value() then
    if renoise.song().selected_track.visible_effect_columns == 0 then 
    renoise.song().selected_track.visible_effect_columns = 1 end
    
        pakettiMidiValuesEffectColumn(0, 255, 1, 'amount_value', message.int_value)
  end
end}


--------
-- Function to double the edit step
function PakettiEditStepDouble()
  local transport = renoise.song().transport
  local current_step = transport.edit_step
  if current_step == 0 then
    current_step = 1
  else
    current_step = current_step * 2
  end
  transport.edit_step = math.min(current_step, 64)
  renoise.app():show_status("EditStep doubled to " .. transport.edit_step)
end

-- Function to halve the edit step
function PakettiEditStepHalve()
  local transport = renoise.song().transport
  local current_step = transport.edit_step
  if current_step > 1 then
    current_step = math.floor(current_step / 2)
  end
  transport.edit_step = current_step
  renoise.app():show_status("EditStep halved to " .. transport.edit_step)
end

-- Adding the MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:EditStep Double x[Button]",invoke=function(message) if message:is_trigger() then PakettiEditStepDouble() end end}
renoise.tool():add_midi_mapping{name="Paketti:EditStep Halve x[Button]",invoke=function(message) if message:is_trigger() then PakettiEditStepHalve() end end}

------
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Left by 10",invoke=function(message) if message:is_trigger() then move_slice_start_left_10() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Right by 10",invoke=function(message) if message:is_trigger() then move_slice_start_right_10() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Left by 10",invoke=function(message) if message:is_trigger() then move_slice_end_left_10() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Right by 10",invoke=function(message) if message:is_trigger() then move_slice_end_right_10() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Left by 100",invoke=function(message) if message:is_trigger() then move_slice_start_left_100() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Right by 100",invoke=function(message) if message:is_trigger() then move_slice_start_right_100() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Left by 100",invoke=function(message) if message:is_trigger() then move_slice_end_left_100() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Right by 100",invoke=function(message) if message:is_trigger() then move_slice_end_right_100() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Left by 300",invoke=function(message) if message:is_trigger() then move_slice_start_left_300() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Right by 300",invoke=function(message) if message:is_trigger() then move_slice_start_right_300() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Left by 300",invoke=function(message) if message:is_trigger() then move_slice_end_left_300() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Right by 300",invoke=function(message) if message:is_trigger() then move_slice_end_right_300() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Left by 500",invoke=function(message) if message:is_trigger() then move_slice_start_left_500() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice Start Right by 500",invoke=function(message) if message:is_trigger() then move_slice_start_right_500() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Left by 500",invoke=function(message) if message:is_trigger() then move_slice_end_left_500() end end}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Move Slice End Right by 500",invoke=function(message) if message:is_trigger() then move_slice_end_right_500() end end}

----------------
renoise.tool():add_midi_mapping{name="Paketti:Set Beatsync Value x[Knob]",invoke=function(message) 
  if message:is_abs_value() then
  if renoise.song().selected_instrument ~= nil and renoise.song().selected_sample ~= nil then
    renoise.song().selected_sample.beat_sync_enabled=true
    midiValues(1, 128, renoise.song().selected_sample, 'beat_sync_lines', message.int_value)
  else renoise.app():show_status("There is no Instrument and no Sample.") end
  end
  end}
  
---
function PakettiMidiSendBang(number)
  local selected_track = renoise.song().selected_track
  local send_devices = {}
  
  -- Collect indices of all send devices on the track
  for i = 1, #selected_track.devices do
    local device = selected_track.devices[i]
    if device.device_path == "Audio/Effects/Native/#Send" or 
       device.device_path == "Audio/Effects/Native/#Multiband Send" then
      table.insert(send_devices, i)
    end
  end
  
  -- Check if there are any send devices
  if #send_devices == 0 then
    renoise.app():show_status("No send tracks available.")
    return
  end
  
  -- Check if the requested send number exists
  if #send_devices < number then
    renoise.app():show_status("The Send at " .. number .. " does not exist, doing nothing.")
    return
  end
  
  -- Toggle the is_active state of the appropriate send device
  local send_device_index = send_devices[number]
  local send_device = selected_track.devices[send_device_index]
  
  send_device.is_active = not send_device.is_active
  renoise.app():show_status("Toggled Send " .. number .. " to " .. tostring(send_device.is_active))
end

-- Setup the MIDI mappings for the first 63 sends
for i = 2, 64 do
  local actual_number = i - 1
  renoise.tool():add_midi_mapping{name="Paketti:Selected Track Send " .. string.format("%02d", actual_number) .. " On/Off Toggle",
    invoke = function(message)
      if message:is_trigger() then
        PakettiMidiSendBang(actual_number)
      end
    end
  }
end


renoise.tool():add_midi_mapping{name="Paketti:Selected Track Mute x[Toggle]",invoke=function(message) if message:is_trigger() then 
if renoise.song().tracks[renoise.song().selected_track_index].mute_state == 1 then
renoise.song().selected_track:mute()
else
renoise.song().selected_track:unmute() end end end}


for i=1,64 do
renoise.tool():add_midi_mapping{name="Paketti:Selected Track Mute " .. string.format("%02d", i) .. " x[Toggle]",invoke=function(message) if message:is_trigger() then 
if renoise.song().tracks[i] ~= nil then
if renoise.song().tracks[i].mute_state == 1 then
renoise.song().tracks[i]:mute()
else
renoise.song().tracks[i]:unmute() end end end 
renoise.app():show_status("The selected track " .. string.format("%02d", i) .. " does not exist, doing nothing.")

end}


end

---------
local previous_value = nil

function transpose_notes_by_midi_knob(message)
  local song = renoise.song()

  -- Extract the MIDI value from the message
  local value = message.int_value

  -- Determine the change in MIDI value
  local change = 0
  if previous_value then
    change = value - previous_value
  end
  previous_value = value

  -- No change detected, return
  if change == 0 then
    return
  end

  -- Determine the direction of transpose
  local transpose_amount = 0
  if change > 0 then
    transpose_amount = 1
  elseif change < 0 then
    transpose_amount = -1
  end

  -- Transpose the notes based on the selection or the selected note column
  if song.selection_in_pattern then
    local selection = song.selection_in_pattern
    for track_idx = selection.start_track, selection.end_track do
      for line_idx = selection.start_line, selection.end_line do
        local line = song:pattern(song.selected_pattern_index):track(track_idx):line(line_idx)
        for col_idx = selection.start_column, selection.end_column do
          local note_col = line:note_column(col_idx)
          if note_col and not note_col.is_empty then
            note_col.note_value = math.max(0, math.min(note_col.note_value + transpose_amount, 119))
          end
        end
      end
    end
  else
    local line = song.selected_line
    local note_col = line:note_column(song.selected_note_column_index)
    if note_col and not note_col.is_empty and note_col.note_value < 120 then
      note_col.note_value = math.max(0, math.min(note_col.note_value + transpose_amount, 119))
    end
  end

  -- Ensure focus returns to the pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Add MIDI mapping for the transpose function
renoise.tool():add_midi_mapping{name="Paketti:Transpose Notes in Selection/Row x[Knob]",invoke=transpose_notes_by_midi_knob}
-----------------
renoise.tool():add_midi_mapping{name="Paketti:Change Selected Instrument (Next) x[Knob]",
invoke= function(message) if message:is_trigger() then
local currInst= renoise.song().selected_instrument_index
local newInst = currInst + 1
if newInst > #renoise.song().instruments then newInst = #renoise.song().instruments end
renoise.song().selected_instrument_index = newInst
end end}

renoise.tool():add_midi_mapping{name="Paketti:Change Selected Instrument (Previous) x[Knob]",
invoke= function(message) if message:is_trigger() then
local currInst= renoise.song().selected_instrument_index
local newInst = currInst - 1
if newInst < 1 then newInst = 1 end
renoise.song().selected_instrument_index = newInst
end end}



-------
-- Clamp the value between 0.0 and 1.0
local function clamp_value(value)
  return math.max(0.0, math.min(1.0, value))
end

-- Function to modify the selected device parameter directly or record to automation
function MidiSelectedAutomationParameter(number, message)
  local song = renoise.song()
  local selected_device = song.selected_device
  local playback_active = song.transport.playing
  local edit_mode = song.transport.edit_mode
  local follow_pattern = song.transport.follow_player

  -- Check if a device is selected
  if selected_device == nil then
    print("No device selected.")
    return
  end

  -- Validate that the parameter exists at the given index (1-128)
  local device_parameter = selected_device.parameters[number]
  if device_parameter == nil then
    print("No parameter found for index " .. number)
    return
  end

  -- Clamp the message value
  local clamped_message = clamp_value(message)

  -- Always allow editing the device parameter directly with MIDI knobs
  device_parameter.value = clamped_message
  print("Changed device parameter '" .. device_parameter.name ..
        "' directly on device '" .. selected_device.name .. "' to value: " .. tostring(clamped_message))

  -- Scenario: If Edit Mode = True, write automation
  if edit_mode then
    -- Get the selected pattern and track
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index

    -- Get the track automation for the parameter
    local track_automation = song:pattern(pattern_index):track(track_index)
    local envelope = track_automation:find_automation(device_parameter)

    -- Create the automation if it doesn't exist
    if not envelope then
      envelope = track_automation:create_automation(device_parameter)
      print("Created new automation for parameter '" .. device_parameter.name ..
            "' on device '" .. selected_device.name .. "'")
    end

    -- Determine where to write automation:
    -- 1. If Playback is OFF, always write to the cursor position (selected line).
    -- 2. If Playback is ON:
    --    - If Follow Pattern is ON, write to the playhead position.
    --    - If Follow Pattern is OFF, write to the cursor position (selected line).
    local line_to_write
    if not playback_active then
      line_to_write = song.selected_line_index  -- Write to cursor if Playback is off
    elseif follow_pattern then
      line_to_write = song.transport.playback_pos.line  -- Write to playhead if Follow Pattern is on
    else
      line_to_write = song.selected_line_index  -- Write to cursor if Follow Pattern is off
    end

    -- Record the value to the automation envelope at the determined line
    envelope:add_point_at(line_to_write, clamped_message)

    -- Debug output
    print("Recorded automation parameter '" .. device_parameter.name ..
          "' on device '" .. selected_device.name ..
          "' at line " .. line_to_write ..
          " to value: " .. tostring(clamped_message))
  end
end

-- Generate MIDI mappings for automation parameters 001-128
for i = 1, 128 do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Selected Device Automation Parameter %03d", i),
    invoke = function(message)
      -- Normalize the MIDI message (0-127) to a range of 0.0 - 1.0
      local normalized_message = message.int_value / 127
      -- Change device parameter or record to automation based on the logic
      MidiSelectedAutomationParameter(i, normalized_message)
    end
  }
end




------


local function clamp_value(value)
  -- Ensure the value is clamped between 0.0 and 1.0
  return math.max(0.0, math.min(1.0, value))
end

function record_midi_value(value)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  -- Check if the automation parameter is valid and automatable
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  -- Find or create the automation envelope for the selected parameter
  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)
  
  if not envelope then
    envelope = track_automation:create_automation(automation_parameter)
    print("Created new automation envelope for parameter: " .. automation_parameter.name)
  end

  -- Ensure the value is clamped between 0.0 and 1.0
  local clamped_value = clamp_value(value)

  -- Check for a valid selection range
  local selection = envelope.selection_range

  -- Case 1: If not playing and a selection exists, clear the selection range and write new points
  if not song.transport.playing and selection then
    local start_line = selection[1]
    local end_line = selection[2]
    
    -- Clear the range before writing
    envelope:clear_range(start_line, end_line)
    print("Cleared automation range from line " .. start_line .. " to line " .. end_line)

    -- Write the automation points in the cleared range
    for line = start_line, end_line do
      local time = line -- Time in pattern lines
      -- Create or modify an automation point at the specified time
      envelope:add_point_at(time, clamped_value)
--      print("Added automation point at time: " .. time .. " with value: " .. tostring(clamped_value))
    end
    
    renoise.app():show_status("Automation points written to cleared selection from line " .. start_line .. " to line " .. end_line)
    return -- We return after writing to the selection range
  end

  -- Case 2: If playing, Follow Pattern is off, and a selection exists, clear the selection and write
  if song.transport.playing and not song.transport.follow_player and selection then
    local start_line = selection[1]
    local end_line = selection[2]
    
    -- Clear the range before writing
    envelope:clear_range(start_line, end_line)
    print("Cleared automation range from line " .. start_line .. " to line " .. end_line)

    -- Write the automation points in the cleared range
    for line = start_line, end_line do
      local time = line -- Time in pattern lines
      -- Create or modify an automation point at the specified time
      envelope:add_point_at(time, clamped_value)
--      print("Added automation point at time: " .. time .. " with value: " .. tostring(clamped_value))
    end
    
    renoise.app():show_status("Automation points written to cleared selection from line " .. start_line .. " to line " .. end_line)
    return -- We return after writing to the selection range
  end

  -- If no selection exists or other conditions aren't met, write to playhead
  local playhead_line = song.transport.playback_pos.line
  envelope:add_point_at(playhead_line, clamped_value)
--  renoise.app():show_status("Automation recorded at playhead: " .. playhead_line .. " with value: " .. tostring(clamped_value))
--  print("Automation recorded at playhead: " .. playhead_line .. " with value: " .. tostring(clamped_value))
end

renoise.tool():add_midi_mapping{name="Paketti:Record Automation to Selected Parameter",
  invoke = function(midi_msg)
    -- Normalize the MIDI value (0-127) to a range of 0.0 - 1.0
    renoise.song().transport.record_parameter_mode=renoise.Transport.RECORD_PARAMETER_MODE_AUTOMATION
    local normalized_value = midi_msg.int_value / 127
--    print("Received MIDI value: " .. tostring(midi_msg.int_value) .. " (normalized: " .. tostring(normalized_value) .. ")")  
    record_midi_value(normalized_value)
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Record Automation to Selected Parameter (2nd)",
  invoke = function(midi_msg)
    -- Normalize the MIDI value (0-127) to a range of 0.0 - 1.0
    renoise.song().transport.record_parameter_mode=renoise.Transport.RECORD_PARAMETER_MODE_AUTOMATION
    local normalized_value = midi_msg.int_value / 127
--    print("Received MIDI value: " .. tostring(midi_msg.int_value) .. " (normalized: " .. tostring(normalized_value) .. ")")
    
    record_midi_value(normalized_value)
  end
}


------------
-- Helper function to introduce a short delay (via the idle observer)
local idle_observable = renoise.tool().app_idle_observable
local function short_delay(callback,int_value)
  local idle_func -- Declare it beforehand
  local idle_count = 0
  idle_func = function()
  
  if int_value == 0 then
  for i, device in ipairs(track.devices) do
    if device.display_name == "Repeater" then
      device_found = true
      device_index = i
      device.is_active = false
      break
    end
  end

      
  end
  
    idle_count = idle_count + 1
    if idle_count >= 2 then -- Roughly a millisecond delay
      idle_observable:remove_notifier(idle_func)
      callback()
    end
  end
  idle_observable:add_notifier(idle_func)
end

-- Define the table for base time divisions, starting with OFF at [1], followed by divisions from 1/1 to 1/128
local base_time_divisions = {
  [1] = "OFF",  -- OFF state
  [2] = "1 / 1", [3] = "1 / 2", [4] = "1 / 4", [5] = "1 / 8", 
  [6] = "1 / 16", [7] = "1 / 32", [8] = "1 / 64", [9] = "1 / 128"
}

-- Define the modes as a list for easy cycling (Even, Triplet, Dotted)
local modes = {
  [1] = "Even",
  [2] = "Triplet",
  [3] = "Dotted"
}

-- MIDI mapping logic for the first knob (doesn't change the track name, only shows status)
renoise.tool():add_midi_mapping{name="Paketti:Set Repeater Value x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local int_value = message.int_value

      if int_value <= 5 then
        deactivate_repeater(false) -- Pass false to not change the track name
        return -- Exit early as it's in the OFF range
      end
      update_repeater_with_midi_value(int_value, false)
    end
  end}

renoise.tool():add_midi_mapping{name="Paketti:Set Repeater Value (Name Tracks) x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local int_value = message.int_value
      if int_value <= 5 then
        deactivate_repeater(true) -- Pass true to change the track name
        return -- Exit early as it's in the OFF range
      end
      update_repeater_with_midi_value(int_value, true)
    end
  end}

renoise.tool():add_midi_mapping{name="Paketti:Set Repeater Value (2nd) x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local int_value = message.int_value

      if int_value <= 5 then
        deactivate_repeater(false) -- Pass false to not change the track name
        return -- Exit early as it's in the OFF range
      end
      update_repeater_with_midi_value(int_value, false)
    end
  end}

renoise.tool():add_midi_mapping{name="Paketti:Set Repeater Value (Name Tracks) (2nd) x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local int_value = message.int_value
      if int_value <= 5 then
        deactivate_repeater(true) -- Pass true to change the track name
        return -- Exit early as it's in the OFF range
      end
      update_repeater_with_midi_value(int_value, true)
    end
  end}


-- Function to deactivate the Repeater without making any other parameter changes
-- track_name_change: if true, changes the track name
function deactivate_repeater(track_name_change)
  local track = renoise.song().selected_track
  local device_found = false
  local device_index = nil

  -- Check if the Repeater device already exists on the track
  for i, device in ipairs(track.devices) do
    if device.display_name == "Repeater" then
      device_found = true
      device_index = i
      break
    end
  end

  if device_found then
    local device = track.devices[device_index]
    
    -- Deactivate the device without updating parameters
    if device.is_active then
      device.is_active = false
      -- Show status when the repeater is turned off
      renoise.app():show_status("Repeater is now Off")
      print("Repeater deactivated")

      -- Optionally change track name to "OFF"
      if track_name_change then
        track.name = "OFF"
      end
    end
  else
    print("No Repeater device found on the selected track")
  end
end


-- Function to handle MIDI knob input and update the Repeater accordingly
-- track_name_change: if true, changes the track name
function update_repeater_with_midi_value(int_value, track_name_change)
  local track = renoise.song().selected_track
  local device_found = false
  local device_index = nil

  -- Check if the Repeater device already exists on the track
  for i, device in ipairs(track.devices) do
    if device.display_name == "Repeater" then
      device_found = true
      device_index = i
      break
    end
  end

  -- If no device is found, insert a new Repeater
  if not device_found then
    renoise.song().selected_track:insert_device_at("Audio/Effects/Native/Repeater", #track.devices + 1)
    device_index = #track.devices -- Index of the newly added device
    device_found = true
    renoise.song().selected_track.devices[device_index].parameters[2].show_in_mixer=true
--    print("Repeater device added")
  end

  if device_found then
    -- Get time division and mode based on MIDI value (6 to 127)
    local time_division, mode = get_time_division_from_midi(int_value)

    -- Show status of the new division
    renoise.app():show_status("Repeater is now " .. time_division .. " " .. mode)

    -- Optionally change the track name to the new division
    if track_name_change then
      track.name = time_division .. " " .. mode
    end

    -- Map mode to the Repeater's mode parameter
    local mode_value = 2 -- Default to Even
    if mode == "Triplet" then
      mode_value = 3 -- Triplet
    elseif mode == "Dotted" then
      mode_value = 4 -- Dotted
    end

    -- Update the Repeater parameters and briefly toggle it off and on
    update_and_toggle_repeater(time_division, mode_value, int_value)
  end
end

-- Function to update the Repeater with the appropriate parameters, deactivate for a millisecond, and reactivate
function update_and_toggle_repeater(time_division, mode_value, midi_int_value)
  local track = renoise.song().selected_track
  local device_found = false
  local device_index = nil

  -- Check if the Repeater device already exists on the track
  for i, device in ipairs(track.devices) do
    if device.display_name == "Repeater" then
      device_found = true
      device_index = i
      break
    end
  end

  if device_found then
    local device = track.devices[device_index]

    -- Apply time division and mode
    device.parameters[1].value = mode_value -- Set the mode (Even, Triplet, Dotted)
    device.parameters[2].value_string = time_division -- Set the time division (1 / 1 to 1 / 128)

    -- Deactivate the device before updating
    device.is_active = false
    print("Repeater deactivated for parameter update")

    -- Short delay before reactivating the device
    short_delay(function()
      if midi_int_value ~= 0 then
        -- Reactivate the device after a brief delay
        device.is_active = true
      else
        device.is_active = false
        print("Repeater remains off")
      end
    end)
  end
end

-- Function to get time division and mode based on MIDI int_value (6 to 127 range)
function get_time_division_from_midi(int_value)
  -- Ensure int_value is within 6-127 range
  int_value = math.max(6, math.min(int_value, 127))

  -- Special handling for the last three values: 125, 126, and 127 map to 1/128 Dotted
  if int_value >= 125 then
    return base_time_divisions[9], modes[3] -- 1/128 Dotted
  end

  -- Map the int_value to a spread of 21 steps for divisions up to 1/128 Triplet
  local total_steps = 21 -- 7 divisions * 3 modes (Even, Triplet, Dotted), up to 1/128 Triplet
  local midi_range = 124 - 6 + 1 -- Total MIDI values to distribute (6 to 124)
  local step_size = math.floor(midi_range / total_steps) -- Calculate size per step

  -- Calculate the index in the range (spread evenly)
  local index = math.floor((int_value - 6) / step_size) + 1

  -- Calculate the time division (step) and mode
  local step = math.floor((index - 1) / 3) + 2 -- Adjust to map from 1/1 to 1/128 Triplet
  local mode = (index - 1) % 3 + 1 -- Mode: Even, Triplet, Dotted

  -- Return the time division and mode
  return base_time_divisions[step] or "Unknown Division", modes[mode] or "Unknown Mode"
end






-------


-- Define target devices and their respective parameters
local target_devices = {
  {path="Audio/Effects/Native/Compressor", params={"Threshold", "Ratio", "Release", "Makeup"}},
  {path="Audio/Effects/Native/Comb Filter 2", params={"Note", "Transpose", "Feedback", "Dry/Wet"}},
  {path="Audio/Effects/Native/RingMod 2", params={"Note", "Transpose", "Dry/Wet"}},
  {path="Audio/Effects/Native/mpReverb 2", params={"Duration", "Color", "Wet Mix", "Width"}},
  {path="Audio/Effects/Native/Phaser 2", params={"Floor", "Ceiling", "Rate", "Feedback", "Depth", "Stages"}},
  {path="Audio/Effects/Native/LofiMat 2", params={"Bit Crunch", "Rate", "Noise", "Wet Mix","Dry Mix"}},
  {path="Audio/Effects/Native/Delay", params={"L Delay", "R Delay", "L Feedb.", "R Feedb.", "Send", "L Sync Time", "R Sync Time"}},
  {path="Audio/Effects/Native/Analog Filter", params={"Type", "Cutoff", "Resonance", "Drive", "Inertia"}},
  {path="Audio/Effects/Native/EQ 10", params={}} -- EQ 10 now explicitly handled
}


-- Function to map MIDI value to parameter range
local function scale_midi_to_param(midi_value, param)
  return param.value_min + ((param.value_max - param.value_min) * (midi_value / 127))
end

-- Function to find and modify parameters of the target devices
local function modify_device_param(device_path, param_identifier, midi_value)
  local track = renoise.song().selected_track
  local found_device = false
  
  -- Loop through the devices in the selected track
  for device_index, device in ipairs(track.devices) do
    if device.device_path == device_path then
      found_device = true
      local param

      -- Handle numeric parameter indices (for EQ 10)
      if type(param_identifier) == "number" then
        param = device.parameters[param_identifier]
      else
        -- Handle parameter names (for other devices)
        for _, parameter in ipairs(device.parameters) do
          if parameter.name == param_identifier then
            param = parameter
            break
          end
        end
      end

      -- Check if we found the parameter
      if param then
        param.value = scale_midi_to_param(midi_value, param)
        renoise.app():show_status(param.name .. " of " .. device.name .. " modified.")
      else
        renoise.app():show_status("Parameter not found in " .. device.name)
        return
      end
      
      -- Set focus back to the pattern editor after modification
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      return
    end
  end

  -- If device not found, show a status message
  if not found_device then
    renoise.app():show_status("The device " .. device_path .. " is not present on selected track.")
  end
end


-- Helper function to remove " 2" from the device names for clean mapping names
local function clean_device_name(device_name)
  return device_name:gsub(" 2$", "")  -- Remove the " 2" at the end of the device name
end

-- Auto-generate MIDI mappings for all the device parameters
for _, device_info in ipairs(target_devices) do
  local device_path = device_info.path
  local device_name_clean = clean_device_name(device_path:match("[^/]+$"))

  -- Generate mappings for EQ 10 parameters directly
  if device_path == "Audio/Effects/Native/EQ 10" then
    -- Generate 10 Gain mappings
    for i = 1, 10 do
      local mapping_name="Paketti:Selected Track Dev EQ 10 Gain " .. string.format("%02d", i)
      renoise.tool():add_midi_mapping{name=mapping_name,
        invoke = function(message)
          local midi_value = message.int_value
          modify_device_param(device_path, i, midi_value) -- Map to parameter index 1-10 (Gain)
        end
      }
    end
    
    -- Generate 10 Frequency mappings
    for i = 11, 20 do
      local mapping_name="Paketti:Selected Track Dev EQ 10 Frequency " .. string.format("%02d", i - 10)
      renoise.tool():add_midi_mapping{name = mapping_name,
        invoke = function(message)
          local midi_value = message.int_value
          modify_device_param(device_path, i, midi_value) -- Map to parameter index 11-20 (Frequency)
        end
      }
    end

    -- Generate 10 Bandwidth mappings
    for i = 21, 30 do
      local mapping_name="Paketti:Selected Track Dev EQ 10 Bandwidth " .. string.format("%02d", i - 20)
      renoise.tool():add_midi_mapping{
        name = mapping_name,
        invoke = function(message)
          local midi_value = message.int_value
          modify_device_param(device_path, i, midi_value) -- Map to parameter index 21-30 (Bandwidth)
        end
      }
    end
  else
    -- For other devices (Compressor, Comb Filter, RingMod)
    for _, param_name in ipairs(device_info.params) do
      local mapping_name="Paketti:Selected Track Dev " .. device_name_clean .. " " .. param_name

      -- Add MIDI mapping for each parameter
      renoise.tool():add_midi_mapping{
        name = mapping_name,
        invoke = function(message)
          local midi_value = message.int_value
          modify_device_param(device_path, param_name, midi_value)
        end
      }
    end
  end
end
----------
local filter_types = {
  "2P K35",
  "2P Moog", 
  "4P Moog",
  "4P Diode"
}

-- Function to modify only the filter type in XML
local function modify_filter_type(midi_value)
  local track = renoise.song().selected_track
  local found_device = false
  
  -- Find the Analog Filter device
  for _, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/Analog Filter" then
      found_device = true
      
      -- Get current XML data
      local xml_data = device.active_preset_data
      
      -- Calculate which filter type to use based on MIDI value (0-127)
      local type_index = math.floor((midi_value / 127) * (#filter_types - 0.01)) + 1
      type_index = math.min(type_index, #filter_types)
      local new_type = filter_types[type_index]
      
      -- Replace only the Model tag in XML
      local new_xml = xml_data:gsub(
        '<Model>[^<]+</Model>',
        '<Model>' .. new_type .. '</Model>'
      )
      
      -- Apply the modified XML
      device.active_preset_data = new_xml
      
      -- Show status message
      renoise.app():show_status("Analog Filter Type changed to: " .. new_type)
      return
    end
  end
  
  if not found_device then
    renoise.app():show_status("Analog Filter device not found on selected track")
  end
end

renoise.tool():add_midi_mapping{
  name = "Paketti:Selected Track Dev Analog Filter Filter Type",
  invoke = function(message)
    if message:is_abs_value() then
      modify_filter_type(message.int_value)
    end
  end
}

---------


renoise.tool():add_midi_mapping{name="Paketti:Clear Current Track in Pattern",invoke=function()
renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]:clear()
end}
-------

-- Function to write MIDI-controlled effect command to pattern
function MidiWriteEffectToLine(effect_number, range_min, range_max, clear_on_zero)
  return function(midi_value)
    local song = renoise.song()
    local pattern = song:pattern(song.selected_pattern_index)
    local track = pattern:track(song.selected_track_index)
    local selection = song.selection_in_pattern
    
    -- Function to write effect to a specific line
    local function write_effect_to_line(line)
      -- Ensure at least one effect column is visible
      if song.selected_track.visible_effect_columns == 0 then
        song.selected_track.visible_effect_columns = 1
      end
      
      -- Get the first effect column
      local effect_column = line.effect_columns[1]
      if effect_column then
        if clear_on_zero and midi_value == 0 then
          -- Clear the effect column
          effect_column:clear()
        else
          -- Scale MIDI value (0-127) to desired range
          local scaled_value = math.floor(range_min + (midi_value * (range_max - range_min) / 127))
          local hex_value = string.format("%02X", scaled_value)
          
          effect_column.number_string = effect_number
          effect_column.amount_string = hex_value
        end
      end
    end
    
    if selection then
      -- Write to selection
      for line_idx = selection.start_line, selection.end_line do
        local line = track:line(line_idx)
        write_effect_to_line(line)
      end
      if clear_on_zero and midi_value == 0 then
        renoise.app():show_status("Cleared effect columns in selection")
      else
        local scaled_value = math.floor(range_min + (midi_value * (range_max - range_min) / 127))
        local hex_value = string.format("%02X", scaled_value)
        renoise.app():show_status(string.format("Wrote %s%s to selection", effect_number, hex_value))
      end
    else
      -- Write to current line only
      write_effect_to_line(song.selected_line)
      if clear_on_zero and midi_value == 0 then
        renoise.app():show_status("Cleared effect column in current line")
      else
        local scaled_value = math.floor(range_min + (midi_value * (range_max - range_min) / 127))
        local hex_value = string.format("%02X", scaled_value)
        renoise.app():show_status(string.format("Wrote %s%s to current line", effect_number, hex_value))
      end
    end
  end
end

-- Example mappings using the new system
renoise.tool():add_midi_mapping{
  name = "Paketti:Write 0Sxx Command x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local slice_count = get_slice_marker_count()
      if slice_count then
        -- If we have slice markers, adjust range to match slice count (1 to slice_count)
        MidiWriteEffectToLine("0S", 1, slice_count)(message.int_value)
        -- Show additional info about slice mapping
        renoise.app():show_status(string.format("Using slice range: 1 to %d", slice_count))
      else
        -- No slice markers, use full range
        MidiWriteEffectToLine("0S", 0, 255)(message.int_value)
      end
    end
  end}
  

renoise.tool():add_midi_mapping{
  name = "Paketti:Write ZLxx Command x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      MidiWriteEffectToLine("ZL", 1, 64, true)(message.int_value)
    end
  end}

renoise.tool():add_midi_mapping{
  name = "Paketti:Write ZTxx Command x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      MidiWriteEffectToLine("ZT", 20, 255)(message.int_value)
    end
  end}

-- Function to get slice marker count for current instrument
function get_slice_marker_count()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Check if we have an instrument with samples and slice markers
  if instrument and instrument.samples[1] then
    local sample = instrument.samples[1]
    if sample.slice_markers and #sample.slice_markers > 0 then
      return #sample.slice_markers
    end
  end
  return nil
end

-- Function to write random slice or offset commands
function write_random_slice_command()
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local selection = song.selection_in_pattern
  local slice_count = get_slice_marker_count()
  
  -- Function to write effect to a specific line
  local function write_random_to_line(line)
    if song.selected_track.visible_effect_columns == 0 then
      song.selected_track.visible_effect_columns = 1
    end
    
    local effect_column = line.effect_columns[1]
    if effect_column then
      local random_value = slice_count and math.random(1, slice_count) or math.random(0, 255)
      effect_column.number_string = "0S"
      effect_column.amount_string = string.format("%02X", random_value)
    end
  end
  
  if selection then
    -- Write to selection
    for line_idx = selection.start_line, selection.end_line do
      write_random_to_line(track:line(line_idx))
    end
  else
    -- Write to current line only
    write_random_to_line(song.selected_line)
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Write 0Sxx Command Random Slice/Offset x[Toggle]",invoke=function(message) if message:is_trigger() then write_random_slice_command() end end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write 0Sxx Command Random Slice/Offset",invoke = function() write_random_slice_command() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Write 0Sxx Command Random Slice/Offset",invoke = function() write_random_slice_command() end}

-- Function to rename tracks based on actual samples being played
function rename_tracks_by_played_samples()
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  
  -- Store used samples for each track
  local track_samples = {}
  
  -- Scan pattern for used samples
  for track_idx, track in ipairs(pattern.tracks) do
    local song_track = song.tracks[track_idx]
    track_samples[track_idx] = {}
    
    -- Skip master, send tracks, and group tracks
    if song_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      for line_idx, line in ipairs(track.lines) do
        for _, note_col in ipairs(line.note_columns) do
          if note_col.note_value >= 0 and note_col.instrument_value >= 0 then
            local instr = song.instruments[note_col.instrument_value + 1]
            if instr then
              local found_sample = false
              
              print(string.format("\nTrack %d Line %d: Note %d Instrument '%s'", 
                track_idx, line_idx, note_col.note_value, instr.name))
              
              -- Check each mapping group
              for map_group_idx, map_group in ipairs(instr.sample_mappings) do
                -- Check each individual mapping in the group
                for map_idx = 1, #map_group do
                  local mapping = map_group[map_idx]
                  if mapping and mapping.note_range then
                    print(string.format("  Checking mapping group %d index %d", map_group_idx, map_idx))
                    print(string.format("  Note range: %d to %d", mapping.note_range[1], mapping.note_range[2]))
                    
                    -- Check if note is in range
                    if note_col.note_value >= mapping.note_range[1] and 
                       note_col.note_value <= mapping.note_range[2] then
                      -- Get the sample directly from the mapping
                      if mapping.sample then
                        local name = mapping.sample.name
                        if name and name ~= "" then
                          track_samples[track_idx][name] = true
                          found_sample = true
                          print(string.format("  Found match! Using sample '%s'", name))
                          break
                        end
                      end
                    end
                  end
                end
                if found_sample then break end
              end
              
              -- Only use first sample as fallback if no mapping was found
              if not found_sample and #instr.samples > 0 then
                local sample = instr.samples[1]
                if sample and sample.sample_buffer.has_sample_data then
                  local name = sample.name
                  if name and name ~= "" then
                    track_samples[track_idx][name] = true
                    print(string.format("No mapping found, using first sample '%s'", name))
                  end
                end
              end
            end
          end
        end
      end
      
      -- Rename track based on found samples
      local samples_found = {}
      for sample_name, _ in pairs(track_samples[track_idx]) do
        table.insert(samples_found, sample_name)
      end
      
      if #samples_found > 0 then
        if #samples_found == 1 then
          song_track.name = samples_found[1]
        else
          local max_samples = math.min(3, #samples_found)
          local new_name = samples_found[1]
          for i = 2, max_samples do
            new_name = new_name .. "+" .. samples_found[i]
          end
          if #samples_found > 3 then
            new_name = new_name .. "+..."
          end
          song_track.name = new_name
        end
        renoise.app():show_status("Renamed track " .. track_idx .. " to: " .. song_track.name)
      else
        print(string.format("No samples found for track %d", track_idx))
      end
    end
  end
end

-- Add keybinding and menu entry for the rename function
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Rename Tracks By Played Samples",invoke = function() rename_tracks_by_played_samples() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Rename Tracks By Played Samples",invoke = function() rename_tracks_by_played_samples() end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:Rename Tracks By Played Samples",invoke = function() rename_tracks_by_played_samples() end}



