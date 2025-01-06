-- All of these have been requested by tkna91 via 
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

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (-1)",invoke=function() selectedSampleTranspose(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (+1)",invoke=function() selectedSampleTranspose(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (-12)",invoke=function() selectedSampleTranspose(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (+12)",invoke=function() selectedSampleTranspose(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample Transpose (0)",invoke=function() renoise.song().selected_sample.transpose=0 end}

function selectedSampleFinetune(amount)
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
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (0)",invoke=function() renoise.song().selected_sample.fine_tune=0 end}

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
 
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning (+0.01)",invoke=function() selectedSamplePanning(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning (-0.01)",invoke=function() selectedSamplePanning(-0.01) end}

function selectedSampleVolume(amount)
local currentSampleVolume = renoise.song().selected_sample.volume
local changedSampleVolume = currentSampleVolume + amount
if changedSampleVolume > 4.0 then changedSampleVolume = 4.0
else if changedSampleVolume < 0.0 then changedSampleVolume = 0.0 end end
renoise.song().selected_sample.volume=changedSampleVolume
end
 
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume (+0.01)",invoke=function() selectedSampleVolume(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume (-0.01)",invoke=function() selectedSampleVolume(-0.01) end}
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

function my_keyhandler_func(dialog, key)
  -- Check for specific keys to handle in the dialog
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
dialog:close()
dialog=nil
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

return nil
else
  return key
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
            text = "Select Output Routing for Selected Track:"
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
    dialog = renoise.app():show_custom_dialog("Output Routing for Selected Track", dialog_content, my_keyhandler_func)
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
  renoise.tool():add_keybinding{
    name="Global:Paketti:Set Selected Track Output Routing "..formatDigits(2,i),
    invoke=function() simpleOutputRoute(i+1) end
  }
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
  renoise.tool():add_keybinding{
    name="Global:Paketti:Set Master Track Output Routing "..string.format("%02d",i),
    invoke=function() pakettiMasterOutputRoutings(i+1) end
  }
end







-----
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
  local keybinding_name = "Global:Paketti:Toggle Sequence Selection " .. padded_number

  -- Create a keybinding for each sequence number
  renoise.tool():add_keybinding{name=keybinding_name, invoke=function() tknaToggleSequenceSelection(i - 1) end}
end


-- Function to toggle the sequence selection based on the provided sequence number
-- If there is a selection_range, turn it into a sequence loop
function SequenceSelectionToLoop()
  local song = renoise.song()
  local selection_start = song.sequencer.selection_range[1]
  local selection_end = song.sequencer.selection_range[2]

  -- Check if the loop range matches the current selection
  if song.transport.loop_sequence_range[1] == selection_start and 
     song.transport.loop_sequence_range[2] == selection_end then
    -- If it matches, disable the loop by setting it to nil
    song.transport.loop_sequence_range = {}
  else
    -- Otherwise, set the loop range to the current selection
    song.transport.loop_sequence_range = { selection_start, selection_end }
  end
end

-- Adding a key binding for the function
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Sequence Selection to Loop",invoke=function() SequenceSelectionToLoop() end}

-- Adding a menu entry for the function
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Toggle Sequence Selection to Loop",invoke=function() SequenceSelectionToLoop() end}

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Sequence Selection (All) On/Off",invoke=function()
local sequencerCount=#renoise.song().sequencer.pattern_sequence
--if renoise.song().sequencer.selection_range=={1,sequencerCount} 
--then renoise.song().sequencer.selection_range={} else
renoise.song().sequencer.selection_range={1,#renoise.song().sequencer.pattern_sequence}
--end
end
}

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

-- Add keybinding for the function
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Current Sequence Selection On/Off", invoke=tknaToggleCurrentSequenceSelection}




-- Helper function to select and loop a specific section
function select_and_loop_section(section_number)
  local song = renoise.song()
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
  local song = renoise.song()
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
  local song = renoise.song()
  song.transport.loop_sequence_range = {0, 0}
  renoise.app():show_status("Sequence selection turned off.")
end

-- Function to select and loop a specific section, or deselect it if already selected
function select_and_loop_section(section_index)
  local song = renoise.song()
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

for section_number = 1, 32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Select and Loop Sequence Section " .. string.format("%02d", section_number),
    invoke=function() select_and_loop_section(section_number) end
  }
end

renoise.tool():add_keybinding{name="Global:Paketti:Select and Loop Section (Next)",invoke=select_and_loop_section_next}
renoise.tool():add_keybinding{name="Global:Paketti:Select and Loop Section (Previous)",invoke=select_and_loop_section_previous}

renoise.tool():add_keybinding{name="Global:Paketti:Set Sequence Loop Selection Off",invoke=set_sequence_selection_off}




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
  
  -- Add keybinding for each sequence
  renoise.tool():add_keybinding{name="Global:Paketti:Continue Sequence " .. padded_number .. " From Same Line", invoke=function() 
  if i < #renoise.song().sequencer.pattern_sequence then
  tknaContinueSequenceFromSameLine(i) 
  else
  renoise.song():show_status("Sequence does not exist, doing nothing.")
  end
  end}

end
--------

function tknaContinueCurrentSequenceFromCurrentLine()
  local song = renoise.song()

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


  renoise.tool():add_keybinding{name="Global:Paketti:Continue Current Sequence From Same Line", invoke=function() 
  tknaContinueCurrentSequenceFromCurrentLine() 
end}
---------
function tknaMidiMapSequence(value)
  local max_seq = #renoise.song().sequencer.pattern_sequence - 1
  local sequence_num = math.floor((value / 127) * max_seq) + 1
  tknaContinueSequenceFromSameLine(sequence_num)
end

-- Add MIDI mapping
renoise.tool():add_midi_mapping{name="Paketti:Continue Sequence From Same Line [Set Sequence]", invoke=function(message)
  if message:is_abs_value() then
    tknaMidiMapSequence(message.int_value)
  end
end}

--------
for i = 1, 32 do
  -- Zero-pad the number for sequence naming
  local padded_number = string.format("%02d", i - 1)
  
  -- Add keybinding for each sequence
  renoise.tool():add_keybinding{name="Global:Paketti:Selected Specific Sequence " .. padded_number, invoke=function() 
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
  renoise.tool():add_keybinding{name="Global:Paketti:Trigger Sequence " .. padded_number, invoke=function() tknaTriggerSequence(i) end}
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
  
  -- Add keybinding for each sequence
  renoise.tool():add_keybinding{name="Global:Paketti:Set Sequence " .. padded_number .. " as Scheduled List", invoke=function() tknaSetSequenceAsScheduledList(i) end}
end

  renoise.tool():add_keybinding{name="Global:Paketti:Set Current Sequence as Scheduled List", invoke=function() 
  
  renoise.song().transport:set_scheduled_sequence(renoise.song().selected_sequence_index) end}

  renoise.tool():add_keybinding{name="Global:Paketti:Add Current Sequence to Scheduled List", invoke=function() 
  
  renoise.song().transport:add_scheduled_sequence(renoise.song().selected_sequence_index) end}


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
  
  -- Add keybinding for each sequence
  renoise.tool():add_keybinding{name="Global:Paketti:Add Sequence " .. padded_number .. " to Scheduled List", invoke=function() tknaAddSequenceToScheduledList(i) end}
end


for i = 1, 32 do
  local padded_number = string.format("%02d", i - 1)
  renoise.tool():add_keybinding{
    name="Global:Paketti:Toggle Sequence Loop to " .. padded_number,
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

renoise.tool():add_keybinding{name="Global:Paketti:Clear Pattern Sequence Loop",invoke=function()
renoise.song().transport.loop_sequence_range = {} end}

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
  local song = renoise.song()
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
  local song = renoise.song()
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

-- Adding keybindings for the functions
renoise.tool():add_keybinding{name="Global:Paketti:Set Current Section as Scheduled Sequence",invoke=tknaSetCurrentSectionAsScheduledSequence}
renoise.tool():add_keybinding{name="Global:Paketti:Add Current Section to Scheduled Sequences",invoke=tknaAddCurrentSectionToScheduledSequences}

-- Adding menu entries for the functions
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Set Current Section as Scheduled Sequence",invoke=tknaSetCurrentSectionAsScheduledSequence}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Add Current Section to Scheduled Sequences",invoke=tknaAddCurrentSectionToScheduledSequences}

-- Adding MIDI mappings for the functions
renoise.tool():add_midi_mapping{name="Paketti:Set Current Section as Scheduled Sequence",invoke=tknaSetCurrentSectionAsScheduledSequence}
renoise.tool():add_midi_mapping{name="Paketti:Add Current Section to Scheduled Sequences",invoke=tknaAddCurrentSectionToScheduledSequences}


-- Function to expand the section loop step-by-step, adding the next section
function expandSectionLoopNext()
  local song = renoise.song()
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
  local song = renoise.song()
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

-- Adding keybinding for the functions
renoise.tool():add_keybinding{name="Global:Paketti:Section Loop (Next)",invoke=expandSectionLoopNext}
renoise.tool():add_keybinding{name="Global:Paketti:Section Loop (Previous)",invoke=expandSectionLoopPrevious}

-- Adding menu entry for the functions
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Section Loop (Next)",invoke=expandSectionLoopNext}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Section Loop (Previous)",invoke=expandSectionLoopPrevious}

-- Adding MIDI mapping for the functions
renoise.tool():add_midi_mapping{name="Paketti:Section Loop (Next)",invoke=expandSectionLoopNext}
renoise.tool():add_midi_mapping{name="Paketti:Section Loop (Previous)",invoke=expandSectionLoopPrevious}



-- Function to expand the sequence selection step-by-step
function tknaSequenceSelectionPlusOne()
  local song = renoise.song()
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
  local song = renoise.song()
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

-- Adding keybinding for the functions
renoise.tool():add_keybinding{name="Global:Paketti:Sequence Selection (Next)",invoke=tknaSequenceSelectionPlusOne}
renoise.tool():add_keybinding{name="Global:Paketti:Sequence Selection (Previous)",invoke=tknaSequenceSelectionMinusOne}

-- Adding menu entry for the functions
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Sequence Selection (Next)",invoke=tknaSequenceSelectionPlusOne}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Sequence Selection (Previous)",invoke=tknaSequenceSelectionMinusOne}

-- Adding MIDI mapping for the functions
renoise.tool():add_midi_mapping{name="Paketti:Sequence Selection (Next)",invoke=tknaSequenceSelectionPlusOne}
renoise.tool():add_midi_mapping{name="Paketti:Sequence Selection (Previous)",invoke=tknaSequenceSelectionMinusOne}

-- Function to expand the loop selection to the next sequence
function tknaSequenceLoopSelectionNext()
  local song = renoise.song()
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
  local song = renoise.song()
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

-- Adding keybindings for the functions
renoise.tool():add_keybinding{name="Global:Paketti:Sequence Loop Selection (Next)",invoke=tknaSequenceLoopSelectionNext}
renoise.tool():add_keybinding{name="Global:Paketti:Sequence Loop Selection (Previous)",invoke=tknaSequenceLoopSelectionPrevious}

-- Adding menu entries for the functions
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Sequence Loop Selection (Next)",invoke=tknaSequenceLoopSelectionNext}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Sequences/Sections..:Sequence Loop Selection (Previous)",invoke=tknaSequenceLoopSelectionPrevious}

-- Adding MIDI mappings for the functions
renoise.tool():add_midi_mapping{name="Paketti:Sequence Loop Selection (Next)",invoke=tknaSequenceLoopSelectionNext}
renoise.tool():add_midi_mapping{name="Paketti:Sequence Loop Selection (Previous)",invoke=tknaSequenceLoopSelectionPrevious}

-- Function to add a loop to the current section content and schedule the section to play from the first sequence
function tknaAddLoopAndScheduleSection()
  local song = renoise.song()
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

-- Add a global keybinding
renoise.tool():add_keybinding{name="Global:Paketti:Set Section Loop and Schedule Section",
  invoke=tknaAddLoopAndScheduleSection
}

-- Add a global MIDI mapping
renoise.tool():add_midi_mapping{name="Paketti:Set Section Loop and Schedule Section [Knob]",
  invoke=function(message)
    if message:is_trigger() then
      tknaAddLoopAndScheduleSection()
    end
  end
}

function tknaSetScheduledSequenceToCurrentSequenceAndLoop()
  local song = renoise.song()
  local selection_start = song.selected_sequence_index
  local selection_end = song.selected_sequence_index

  if song.transport.loop_sequence_range[1] == selection_start and 
     song.transport.loop_sequence_range[2] == selection_end then
    song.transport.loop_sequence_range = {}
  else
    song.transport.loop_sequence_range = { selection_start, selection_end }
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

-- Add keybinding for the new function
renoise.tool():add_keybinding{name="Global:Paketti:Set Current Sequence as Scheduled and Loop", invoke=tknaSetScheduledSequenceToCurrentSequenceAndLoop}


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
  local song = renoise.song()
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
  local song = renoise.song()
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
  local song = renoise.song()
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
  local song = renoise.song()
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
  local song = renoise.song()
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

  -- Keybinding: Select, Trigger and Loop the next occurrence of the Section
  renoise.tool():add_keybinding {
    name = "Global:Paketti:Select, Trigger and Loop Section " .. section_id,
    invoke = function() tknaSelectTriggerLoopSection(i) end
  }

  -- MIDI Mapping: Select, Trigger and Loop the next occurrence of the Section
  renoise.tool():add_midi_mapping {
    name = "Paketti:Select, Trigger and Loop Section " .. section_id,
    invoke = function(message) 
      if message:is_trigger() then
        tknaSelectTriggerLoopSection(i)
      end
    end
  }

  -- Keybinding: Select, Schedule and Loop the next occurrence of the Section
  renoise.tool():add_keybinding {
    name = "Global:Paketti:Select, Schedule and Loop Section " .. section_id,
    invoke = function() tknaSelectScheduleLoopSection(i) end
  }

  -- MIDI Mapping: Select, Schedule and Loop the next occurrence of the Section
  renoise.tool():add_midi_mapping {
    name = "Paketti:Select, Schedule and Loop Section " .. section_id,
    invoke = function(message) 
      if message:is_trigger() then
        tknaSelectScheduleLoopSection(i)
      end
    end
  }

  -- Keybinding: Select, Add to Schedule and Loop the next occurrence of the Section
  renoise.tool():add_keybinding {
    name = "Global:Paketti:Select, Add to Schedule and Loop Section " .. section_id,
    invoke = function() tknaSelectAddScheduleLoopSection(i) end
  }

  -- MIDI Mapping: Select, Add to Schedule and Loop the next occurrence of the Section
  renoise.tool():add_midi_mapping {
    name = "Paketti:Select, Add to Schedule and Loop Section " .. section_id,
    invoke = function(message) 
      if message:is_trigger() then
        tknaSelectAddScheduleLoopSection(i)
      end
    end
  }
end

