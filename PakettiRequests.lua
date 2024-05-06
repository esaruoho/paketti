-- From Jenoki

function jenokiSystem(bpl,lpb,rowcount)
-- Set Transport LPB and Metronome LPB to x (lpb)
renoise.song().transport.lpb = lpb
renoise.song().transport.metronome_lines_per_beat = lpb
-- Set Transport TPL and Metronome Beats Ber Bar to y (bpl)
renoise.song().transport.tpl = bpl
renoise.song().transport.metronome_beats_per_bar = bpl
-- Set Pattern Row length to z (rowcount)
renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines=rowcount
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Time Signature 3/4 and 48 rows @ LPB 4",invoke=function() jenokiSystem(3,4,48) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Time Signature 7/8 and 56 rows @ LPB 8",invoke=function() jenokiSystem(7,8,56) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Time Signature 6/8 and 48 rows @ LPB 8",invoke=function() jenokiSystem(6,8,48) end}

-- All of these have been requested by tkna91 via 
-- https://github.com/esaruoho/org.lackluster.Paketti.xrnx/issues/
-- Please send requests if you're interested in obscure stuff that Renoise does not support (but really, should)

function loopReleaseToggle()
if renoise.song().selected_sample.loop_release
then renoise.song().selected_sample.loop_release=false 
else renoise.song().selected_sample.loop_release=true end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop Release On/Off",invoke=function() loopReleaseToggle() end}

function oneShotToggle()
if renoise.song().selected_sample.oneshot 
then renoise.song().selected_sample.oneshot=false 
else renoise.song().selected_sample.oneshot=true end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample One-Shot On/Off",invoke=function() oneShotToggle() end}

function selectedSampleLoopSet(number)
renoise.song().selected_sample.oneshot=false
local loop_modet = renoise.song().selected_sample.loop_mode
  if renoise.song().selected_sample.loop_mode==number then renoise.song().selected_sample.loop_mode=1 else loop_modet = number
  renoise.song().selected_sample.loop_mode=loop_modet
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 1 (Off)",invoke=function() selectedSampleLoopSet(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 2 (Forward)",invoke=function() selectedSampleLoopSet(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 3 (Backward)",invoke=function() selectedSampleLoopSet(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Loop 4 (PingPong)",invoke=function() selectedSampleLoopSet(4) end}

function selectedSampleTranspose(amount)
local currentSampleTranspose = renoise.song().selected_sample.transpose
local changedSampleTranspose = currentSampleTranspose + amount
if changedSampleTranspose > 120 then changedSampleTranspose = 120
else if changedSampleTranspose < -120 then changedSampleTranspose = -120 end end
renoise.song().selected_sample.transpose=changedSampleTranspose
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose -1",invoke=function() selectedSampleTranspose(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose +1",invoke=function() selectedSampleTranspose(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose -12",invoke=function() selectedSampleTranspose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose +12",invoke=function() selectedSampleTranspose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample Transpose 0",invoke=function() renoise.song().selected_sample.transpose=0 end}

function selectedSampleFinetune(amount)
local currentSampleFinetune = renoise.song().selected_sample.fine_tune
local changedSampleFinetune = currentSampleFinetune + amount
if changedSampleFinetune > 127 then changedSampleFinetune = 127
else if changedSampleFinetune < -127 then changedSampleFinetune = -127 end end
renoise.song().selected_sample.fine_tune=changedSampleFinetune
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune -1",invoke=function() selectedSampleFinetune(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune +1",invoke=function() selectedSampleFinetune(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune -10",invoke=function() selectedSampleFinetune(-10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune +10",invoke=function() selectedSampleFinetune(10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune 0",invoke=function() renoise.song().selected_sample.fine_tune=0 end}

function selectedSamplePanning(amount)
local currentSamplePanning = renoise.song().selected_sample.panning
local changedSamplePanning = currentSamplePanning + amount
if changedSamplePanning > 1.0 then changedSamplePanning = 1.0
else if changedSamplePanning < 0.0 then changedSamplePanning = 0.0 end end
renoise.song().selected_sample.panning=changedSamplePanning
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning 0.5 (Center)",invoke=function() renoise.song().selected_sample.panning=0.5 end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning 0.0 (Left)",invoke=function() renoise.song().selected_sample.panning=0.0 end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning 1.0 (Right)",invoke=function() renoise.song().selected_sample.panning=1.0 end}
 
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning +0.01",invoke=function() selectedSamplePanning(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning -0.01",invoke=function() selectedSamplePanning(-0.01) end}

function selectedSampleVolume(amount)
local currentSampleVolume = renoise.song().selected_sample.volume
local changedSampleVolume = currentSampleVolume + amount
if changedSampleVolume > 4.0 then changedSampleVolume = 4.0
else if changedSampleVolume < 0.0 then changedSampleVolume = 0.0 end end
renoise.song().selected_sample.volume=changedSampleVolume
end
 
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume +0.01",invoke=function() selectedSampleVolume(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume -0.01",invoke=function() selectedSampleVolume(-0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume Reset (0.0dB)",invoke=function() renoise.song().selected_sample.volume=1 end }

function selectedSampleInterpolation(amount)
renoise.song().selected_sample.interpolation_mode=amount
end

function selectedSampleOversampleOn()
renoise.song().selected_sample.oversample_enabled=true
end

function selectedSampleOversampleOff()
renoise.song().selected_sample.oversample_enabled=false
end

function selectedSampleOversampleToggle()
if renoise.song().selected_sample.oversample_enabled then
 renoise.song().selected_sample.oversample_enabled = false else
 renoise.song().selected_sample.oversample_enabled = true
end end

function selectedSampleAutoseekToggle()
if renoise.song().selected_sample.autoseek then
 renoise.song().selected_sample.autoseek = false else
 renoise.song().selected_sample.autoseek = true
end end

function selectedSampleAutofadeToggle()
if renoise.song().selected_sample.autofade then
 renoise.song().selected_sample.autofade = false else
 renoise.song().selected_sample.autofade = true
end end

function selectedSampleNNA(number)
renoise.song().selected_sample.new_note_action = number
end


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 1 (None)",invoke=function() selectedSampleInterpolation(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 2 (Linear)",invoke=function() selectedSampleInterpolation(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 3 (Cubic)",invoke=function() selectedSampleInterpolation(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Interpolation to 4 (Sinc)",invoke=function() selectedSampleInterpolation(4) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Oversample On",invoke=function() selectedSampleOversampleOn() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Oversample Off",invoke=function() selectedSampleOversampleOff() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Oversample On/Off",invoke=function() selectedSampleOversampleToggle() end}

function selectedSampleBeatsync(number)
renoise.song().selected_sample.beat_sync_mode = number
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync 1 (Repitch)",invoke=function() selectedSampleBeatsync(1) end }
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync 2 (Time-Stretch Percussion)",invoke=function() selectedSampleBeatsync(2) end }
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync 3 (Time-Stretch Texture)",invoke=function() selectedSampleBeatsync(3) end }

function selectedSampleBeatsyncAndToggleOn(number)
if renoise.song().selected_sample == nil then return else

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
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off 1 (Repitch)",invoke=function() selectedSampleBeatsyncAndToggleOn(1) end }
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off 2 (Time-Stretch Percussion)",invoke=function() selectedSampleBeatsyncAndToggleOn(2) end }
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off 3 (Time-Stretch Texture)",invoke=function() selectedSampleBeatsyncAndToggleOn(3) end }


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync On/Off",invoke=function()
if renoise.song().selected_sample == nil then return else

if renoise.song().selected_sample.beat_sync_enabled then
 renoise.song().selected_sample.beat_sync_enabled = false else
 renoise.song().selected_sample.beat_sync_enabled = true
end end end}

function selectedSampleBeatsyncLine(number)
local currentBeatsyncLine = renoise.song().selected_sample.beat_sync_lines
local changedBeatsyncLine = currentBeatsyncLine + number
if changedBeatsyncLine > 512 then changedBeatsyncLine = 512
else if changedBeatsyncLine < 1 then -- renoise.song().selected_sample.beat_sync_enabled = false 
return end end
renoise.song().selected_sample.beat_sync_lines=changedBeatsyncLine
renoise.song().selected_sample.beat_sync_enabled = true
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (+1)",invoke=function() selectedSampleBeatsyncLine(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (-1)",invoke=function() selectedSampleBeatsyncLine(-1) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Autofade On/Off",invoke=function() selectedSampleAutofadeToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Autoseek On/Off",invoke=function() selectedSampleAutoseekToggle() end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample NNA to 1 (Cut)",invoke=function() selectedSampleNNA(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample NNA to 2 (Note-Off)",invoke=function() selectedSampleNNA(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample NNA to 3 (Continue)",invoke=function() selectedSampleNNA(3) end}

function selectedSampleMuteGroup(number)
if renoise.song().selected_sample == nil then return else 
renoise.song().selected_sample.mute_group = number end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 0 (Off)",invoke=function() selectedSampleMuteGroup(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 1",invoke=function() selectedSampleMuteGroup(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 2",invoke=function() selectedSampleMuteGroup(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 3",invoke=function() selectedSampleMuteGroup(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 4",invoke=function() selectedSampleMuteGroup(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 5",invoke=function() selectedSampleMuteGroup(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 6",invoke=function() selectedSampleMuteGroup(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 7",invoke=function() selectedSampleMuteGroup(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 8",invoke=function() selectedSampleMuteGroup(8) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mute Group to 9",invoke=function() selectedSampleMuteGroup(9) end}
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
    local dialog_content = vb:column {
        margin = 10,
        spacing = 5,
        vb:text {
            text = "Select Output Routing:"
        },
        vb:popup {
            id = "popup_output_routings",
            items = available_output_routings,
            value = selected_routing_index or 1, -- Set the popup to the current routing, or default to the first item
            width = 300,
            notifier = function(index)
                -- Update the selected index when a new item is selected
                selected_routing_index = index
            end
        },
        vb:row {
            spacing = 10,
            vb:button {
                text = "OK",
                notifier = function()
                    apply_selected_routing(selected_routing_index)
                    dialog:close()
                end
            },
            vb:button {
                text = "Cancel",
                notifier = function()
                    dialog:close()
                end
            }
        }
    }

    -- Show the dialog
    dialog = renoise.app():show_custom_dialog("Output Routings", dialog_content)
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


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 00 Master" ,invoke=function() simpleOutputRoute(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 01" ,invoke=function() simpleOutputRoute(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 02" ,invoke=function() simpleOutputRoute(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 03" ,invoke=function() simpleOutputRoute(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 04" ,invoke=function() simpleOutputRoute(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 05" ,invoke=function() simpleOutputRoute(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 06" ,invoke=function() simpleOutputRoute(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 07" ,invoke=function() simpleOutputRoute(8) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 08" ,invoke=function() simpleOutputRoute(9) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 09" ,invoke=function() simpleOutputRoute(10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 10" ,invoke=function() simpleOutputRoute(11) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 11" ,invoke=function() simpleOutputRoute(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 12" ,invoke=function() simpleOutputRoute(13) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 13" ,invoke=function() simpleOutputRoute(14) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 14" ,invoke=function() simpleOutputRoute(15) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 15" ,invoke=function() simpleOutputRoute(16) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Track Output Routing 16" ,invoke=function() simpleOutputRoute(17) end}

function setBeatsyncLineAbove()
    local currentBeatsyncLine = renoise.song().selected_sample.beat_sync_lines
    -- Calculate the next higher power of 2
    local power = math.ceil(math.log(currentBeatsyncLine) / math.log(2))
    local nextPowerOfTwo = 2 ^ power
    if nextPowerOfTwo <= currentBeatsyncLine then -- Ensure we actually move up
        nextPowerOfTwo = nextPowerOfTwo * 2
    end
    -- Clamp to maximum allowed value
    if nextPowerOfTwo > 512 then nextPowerOfTwo = 512 end
    renoise.song().selected_sample.beat_sync_lines = nextPowerOfTwo
    renoise.song().selected_sample.beat_sync_enabled = true
end

function setBeatsyncLineBelow()
    local currentBeatsyncLine = renoise.song().selected_sample.beat_sync_lines
    if currentBeatsyncLine <= 1 then -- Prevent going below 1
        return
    end
    local power = math.floor(math.log(currentBeatsyncLine) / math.log(2))
    local prevPowerOfTwo = 2 ^ power
    if prevPowerOfTwo >= currentBeatsyncLine then -- Ensure we actually move down
        prevPowerOfTwo = prevPowerOfTwo / 2
    end
    renoise.song().selected_sample.beat_sync_lines = prevPowerOfTwo
    renoise.song().selected_sample.beat_sync_enabled = true
end


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (Power of Two Above)",invoke=function() setBeatsyncLineAbove() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Line (Power of Two Below)",invoke=function() setBeatsyncLineBelow() end}

-- Shortcuts as requested by Casiino
-- 
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity -16",invoke=function() computerKeyboardVolChange(-16) end}
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity +16",invoke=function() computerKeyboardVolChange(16) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Decrease (-5)",invoke=function() adjust_bpm(-5, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Increase (+5)",invoke=function() adjust_bpm(5, 0) end}

function loopExitToggle()
  if 
  renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].loop_release 
  then 
  renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].loop_release=false
  else
  renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].loop_release=true
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample Exit Loop Note-Off Toggle",invoke=function() loopExitToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample Exit Loop Note-Off Off",invoke=function() 
renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].loop_release=false
 end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample Exit Loop Note-Off On",invoke=function() 
renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].loop_release=true
 end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Autofade On",invoke=function() renoise.song().selected_sample.autofade=true end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Autofade Off",invoke=function() renoise.song().selected_sample.autofade=false end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune -5",invoke=function() selectedSampleFinetune(-5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune +5",invoke=function() selectedSampleFinetune(5) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume +0.05",invoke=function() selectedSampleVolume(0.05) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume -0.05",invoke=function() selectedSampleVolume(-0.05) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning +0.05",invoke=function() selectedSamplePanning(0.05) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning -0.05",invoke=function() selectedSamplePanning(-0.05) end}


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose -5",invoke=function() selectedSampleTranspose(-5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose +5",invoke=function() selectedSampleTranspose(5) end}

-- Function to assign a modulation set to the selected sample based on a given index
function selectedSampleMod(number)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]
  
  -- Check if there are any modulation sets
  if not instrument or #instrument.sample_modulation_sets == 0 then
    print("No modulation sets available or no instrument selected.")
    return
  end
  
  -- Get the number of available modulation sets
  local num_modulation_sets = #instrument.sample_modulation_sets
  
  -- Check if the provided index is within the valid range
  -- Adjusting to include 0 in the check, as it represents no modulation set assigned
  if number < 0 or number > num_modulation_sets then
    -- print("Invalid modulation_set_index value '" .. number .. "'. Valid values are (0 to " .. num_modulation_sets .. ").")
    return
  end

  -- Assign the modulation set index to the selected sample
  -- This assignment now confidently allows setting the index to 0
  instrument.samples[renoise.song().selected_sample_index].modulation_set_index = number
end

-- Function to assign an FX chain to the selected sample based on a given index
function selectedSampleFX(number)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]
  
  -- Check if there are any FX chains
  if not instrument or #instrument.sample_device_chains == 0 then
    print("No FX chains available or no instrument selected.")
    return
  end
  
  -- Get the number of available FX chains
  local num_fx_sets = #instrument.sample_device_chains
  
  -- Check if the provided index is within the valid range
  -- Adjusting to include 0 in the check, as it represents no FX chain assigned
  if number < 0 or number > num_fx_sets then
    -- print("Invalid device_chain_index value '" .. number .. "'. Valid values are (0 to " .. num_fx_sets .. ").")
    return
  end

  -- Assign the FX chain index to the selected sample
  -- This assignment confidently allows setting the index to 0
  instrument.samples[renoise.song().selected_sample_index].device_chain_index = number
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 0",invoke=function() selectedSampleMod(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 1",invoke=function() selectedSampleMod(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 2",invoke=function() selectedSampleMod(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 3",invoke=function() selectedSampleMod(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 4",invoke=function() selectedSampleMod(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 5",invoke=function() selectedSampleMod(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 6",invoke=function() selectedSampleMod(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 7",invoke=function() selectedSampleMod(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 8",invoke=function() selectedSampleMod(8) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 0",invoke=function() selectedSampleFX(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 1",invoke=function() selectedSampleFX(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 2",invoke=function() selectedSampleFX(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 3",invoke=function() selectedSampleFX(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 4",invoke=function() selectedSampleFX(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 5",invoke=function() selectedSampleFX(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 6",invoke=function() selectedSampleFX(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 7",invoke=function() selectedSampleFX(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 8",invoke=function() selectedSampleFX(8) end}

-- Function to assign a modulation set index to all samples in the selected instrument
function selectedInstrumentAllMod(number)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if the instrument and samples are valid
  if not instrument or #instrument.samples == 0 then
    print("No samples are available or no instrument selected.")
    return
  end

  -- Get the number of available modulation sets
  local num_modulation_sets = #instrument.sample_modulation_sets

  -- Check if the provided index is within the valid range
  if number < 0 or number > num_modulation_sets then
    print("Invalid modulation_set_index value '" .. number .. "'. Valid values are (0 to " .. num_modulation_sets .. ").")
    return
  end

  -- Assign the modulation set index to each sample in the instrument
  for i, sample in ipairs(instrument.samples) do
    sample.modulation_set_index = number
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 0",invoke=function() selectedInstrumentAllMod(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 1",invoke=function() selectedInstrumentAllMod(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 2",invoke=function() selectedInstrumentAllMod(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 3",invoke=function() selectedInstrumentAllMod(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 4",invoke=function() selectedInstrumentAllMod(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 5",invoke=function() selectedInstrumentAllMod(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 6",invoke=function() selectedInstrumentAllMod(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 7",invoke=function() selectedInstrumentAllMod(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 8",invoke=function() selectedInstrumentAllMod(8) end}

-- Function to assign an FX chain index to all samples in the selected instrument
function selectedInstrumentAllFx(number)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if the instrument and samples are valid
  if not instrument or #instrument.samples == 0 then
    print("No samples are available or no instrument selected.")
    return
  end

  -- Get the number of available FX chains
  local num_fx_sets = #instrument.sample_device_chains

  -- Check if the provided index is within the valid range
  if number < 0 or number > num_fx_sets then
    print("Invalid device_chain_index value '" .. number .. "'. Valid values are (0 to " .. num_fx_sets .. ").")
    return
  end

  -- Assign the FX chain index to each sample in the instrument
  for i, sample in ipairs(instrument.samples) do
    sample.device_chain_index = number
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 0",invoke=function() selectedInstrumentAllFx(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 1",invoke=function() selectedInstrumentAllFx(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 2",invoke=function() selectedInstrumentAllFx(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 3",invoke=function() selectedInstrumentAllFx(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 4",invoke=function() selectedInstrumentAllFx(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 5",invoke=function() selectedInstrumentAllFx(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 6",invoke=function() selectedInstrumentAllFx(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 7",invoke=function() selectedInstrumentAllFx(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 8",invoke=function() selectedInstrumentAllFx(8) end}


-- Function to toggle the autofade setting for all samples in the selected instrument
function selectedInstrumentAllAutofadeToggle()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if the instrument and samples are valid
  if not instrument or #instrument.samples == 0 then
    print("No samples are available or no instrument selected.")
    return
  end

  -- Iterate through each sample in the instrument and toggle the autofade setting
  for i, sample in ipairs(instrument.samples) do
    sample.autofade = not sample.autofade
  end
end

-- Function to set the autofade setting for all samples in the selected instrument based on a given state
function selectedInstrumentAllAutofadeControl(state)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if the instrument and samples are valid
  if not instrument or #instrument.samples == 0 then
    --print("No samples are available or no instrument selected.")
    return
  end

  -- Convert numerical state to boolean for autofade
  local autofadeState = (state == 1)

  -- Iterate through each sample in the instrument and set the autofade setting
  for i, sample in ipairs(instrument.samples) do
    sample.autofade = autofadeState
  end
end




renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autofade On/Off",invoke=function() selectedInstrumentAllAutofadeToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autofade On",invoke=function() selectedInstrumentAllAutofadeControl(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autofade Off",invoke=function() selectedInstrumentAllAutofadeControl(0) end}

function halveBeatSyncLines()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    local samples = s.instruments[currInst].samples
    if #samples < 2 then
        print("Not enough samples to perform operation.")
        return
    end

    -- Starting the check from the second sample
    local reference_sync_lines = samples[2].beat_sync_lines
    for i = 2, #samples do
        if samples[i].beat_sync_lines ~= reference_sync_lines then
            print("Not all samples (excluding the first) have the same beat_sync_lines.")
            return
        end
    end

    local new_sync_lines = reference_sync_lines * 2
    new_sync_lines = math.min(new_sync_lines, 512)  -- Ensure it does not exceed 512
    for i = 2, #samples do
        samples[i].beat_sync_lines = new_sync_lines
    end

    renoise.app():show_status("Beat sync lines halved for all samples (excluding the first) from " .. reference_sync_lines .. " to " .. new_sync_lines)
end



function doubleBeatSyncLines()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    local samples = s.instruments[currInst].samples
    if #samples < 2 then
        print("Not enough samples to perform operation.")
        return
    end

    -- Starting the check from the second sample
    local reference_sync_lines = samples[2].beat_sync_lines
    for i = 2, #samples do
        if samples[i].beat_sync_lines ~= reference_sync_lines then
            print("Not all samples (excluding the first) have the same beat_sync_lines.")
            return
        end
    end

    local new_sync_lines = reference_sync_lines / 2
    new_sync_lines = math.max(new_sync_lines, 1)  -- Ensure it does not fall below 1
    for i = 2, #samples do
        samples[i].beat_sync_lines = new_sync_lines
    end

    renoise.app():show_status("Beat sync lines doubled for all samples (excluding the first) from " .. reference_sync_lines .. " to " .. new_sync_lines)
end





renoise.tool():add_keybinding{name="Global:Paketti:Halve Beat Sync Lines",invoke=function() halveBeatSyncLines() end}

renoise.tool():add_keybinding{name="Global:Paketti:Double Beat Sync Lines",invoke=function() doubleBeatSyncLines() end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments:Beat Sync Lines Halve",invoke=function() halveBeatSyncLines() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments:Beat Sync Lines Double",invoke=function() doubleBeatSyncLines() end}



function pitchedInstrument(st)
renoise.app():load_instrument("Presets/" .. st .. "st_Pitchbend.xrni")
renoise.song().selected_instrument.name=(st .. "st_Pitchbend Instrument")
renoise.song().instruments[renoise.song().selected_instrument_index].macros_visible = true
renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name=(st .. "st_Pitchbend")
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Instruments:12st PitchBend Instrument Init",invoke=function() pitchedInstrument(12) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments:24st PitchBend Instrument Init",invoke=function() pitchedInstrument(24) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments:36st PitchBend Instrument Init",invoke=function() pitchedInstrument(36) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments:48st PitchBend Instrument Init",invoke=function() pitchedInstrument(48) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments:64st PitchBend Instrument Init",invoke=function() pitchedInstrument(64) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments:96st PitchBend Instrument Init",invoke=function() pitchedInstrument(96) end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:12st PitchBend Instrument Init",invoke=function() pitchedInstrument(12) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:24st PitchBend Instrument Init",invoke=function() pitchedInstrument(24) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:36st PitchBend Instrument Init",invoke=function() pitchedInstrument(36) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:48st PitchBend Instrument Init",invoke=function() pitchedInstrument(48) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:64st PitchBend Instrument Init",invoke=function() pitchedInstrument(64) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:96st PitchBend Instrument Init",invoke=function() pitchedInstrument(96) end}

renoise.tool():add_keybinding{name="Global:Paketti:12st PitchBend Instrument Init", invoke=function() pitchedInstrument(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:24st PitchBend Instrument Init", invoke=function() pitchedInstrument(24) end}
renoise.tool():add_keybinding{name="Global:Paketti:36st PitchBend Instrument Init", invoke=function() pitchedInstrument(36) end}
renoise.tool():add_keybinding{name="Global:Paketti:48st PitchBend Instrument Init", invoke=function() pitchedInstrument(48) end}
renoise.tool():add_keybinding{name="Global:Paketti:64st PitchBend Instrument Init", invoke=function() pitchedInstrument(64) end}
renoise.tool():add_keybinding{name="Global:Paketti:96st PitchBend Instrument Init", invoke=function() pitchedInstrument(96) end}


function transposeAllSamplesInInstrument(amount)
    -- Access the currently selected instrument in Renoise
    local instrument = renoise.song().selected_instrument
    -- Iterate through all samples in the instrument
    for i = 1, #instrument.samples do
        -- Access each sample's transpose property
        local currentTranspose = instrument.samples[i].transpose
        local newTranspose = currentTranspose + amount
        -- Clamp the transpose value to be within the valid range of -120 to 120
        if newTranspose > 120 then
            newTranspose = 120
        elseif newTranspose < -120 then
            newTranspose = -120
        end
        -- Apply the new transpose value to the sample
        instrument.samples[i].transpose = newTranspose
    end
end

renoise.tool():add_keybinding {
    name = "Global:Paketti:Set Selected Instrument Samples Transpose -1",
    invoke = function() transposeAllSamplesInInstrument(-1) end}

renoise.tool():add_keybinding {
    name = "Global:Paketti:Set Selected Instrument Samples Transpose +1",
    invoke = function() transposeAllSamplesInInstrument(1) end}

renoise.tool():add_keybinding {
    name = "Global:Paketti:Set Selected Instrument Samples Transpose -12",
    invoke = function() transposeAllSamplesInInstrument(-12) end}

renoise.tool():add_keybinding {
    name = "Global:Paketti:Set Selected Instrument Samples Transpose +12",
    invoke = function() transposeAllSamplesInInstrument(12) end}

function resetInstrumentTranspose(amount)
    -- Access the currently selected instrument in Renoise
    local instrument = renoise.song().selected_instrument
    -- Iterate through all samples in the instrument
    for i = 1, #instrument.samples do
        -- Apply the new transpose value to the sample
        instrument.samples[i].transpose = 0
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Samples Transpose 0 (Reset)",
invoke=function() resetInstrumentTranspose(0) end}

---
--another from casiino:
-- Access the Renoise song API
-- Jump to Group experimental


--another from casiino
-- Velocity Tracking On/Off for each Sample in the Instrument:
function selectedInstrumentVelocityTracking(enable)
  -- Access the selected instrument
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Determine the new state based on the passed argument
  local newState = (enable == 1)

  -- Iterate over all sample mapping groups
  for group_index, sample_mapping_group in ipairs(instrument.sample_mappings) do
    -- Iterate over each mapping in the group
    for mapping_index, mapping in ipairs(sample_mapping_group) do
      -- Set the map_velocity_to_volume based on newState
      mapping.map_velocity_to_volume = newState
      -- Optionally output the change to the terminal for confirmation
      print(string.format("Mapping Group %d, Mapping %d: map_velocity_to_volume set to %s", group_index, mapping_index, tostring(mapping.map_velocity_to_volume)))
    end
  end
end



renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Velocity Tracking Off",
invoke=function() selectedInstrumentVelocityTracking(0) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Velocity Tracking On",
invoke=function() selectedInstrumentVelocityTracking(1) end}

function selectedSampleVelocityTracking(enable)
  -- Access the selected instrument
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]
  -- Get the selected sample index
  local selected_sample_index = renoise.song().selected_sample_index

  -- Determine the new state based on the passed argument
  local newState = (enable == 1)

  -- Iterate over all mappings in the selected instrument
  for _, mapping in ipairs(instrument.sample_mappings[1]) do  -- Assuming [1] is the correct layer, adjust if needed
    -- Check if the mapping corresponds to the selected sample
    if mapping.sample_index == selected_sample_index then
      -- Set the map_velocity_to_volume based on newState
      mapping.map_velocity_to_volume = newState
      -- Optionally output the change to the terminal for confirmation
      print(string.format("Mapping for Sample %d: map_velocity_to_volume set to %s", selected_sample_index, tostring(mapping.map_velocity_to_volume)))
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Selected Sample Velocity Tracking",
invoke=function() 
if
renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume==true
then renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume=false
else renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume=true
 end
 end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Velocity Tracking On",
invoke=function() 
renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume=true
end}


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Velocity Tracking Off",
invoke=function() 
renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume=false
end}







