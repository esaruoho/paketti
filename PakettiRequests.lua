local separator = package.config:sub(1,1)

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Selection in Pattern to Group",
  invoke=function()
    if renoise.song().selection_in_pattern ~= nil then
      local selection = renoise.song().selection_in_pattern
      local groupPos = selection.end_track + 1
      
      -- Ensure the group position is valid
      if groupPos > renoise.song().sequencer_track_count then
        groupPos = renoise.song().sequencer_track_count + 1
      end
      
      -- Insert the group at the adjusted position
      renoise.song():insert_group_at(groupPos)

      -- Add tracks to the group one by one, skipping Master and Send tracks
      for i = selection.start_track, selection.end_track do
        if i <= renoise.song().sequencer_track_count then
          renoise.song():add_track_to_group(selection.start_track, groupPos)
        end
      end
    end
  end
}

function SelectionInPatternMatrixToGroup()
  local song=renoise.song()
  local selected_tracks = {}

  -- Function to read selected tracks in the pattern matrix
  local function read_pattern_matrix_selection()
    local sequencer = song.sequencer
    local total_tracks = song.sequencer_track_count
    local total_patterns = #sequencer.pattern_sequence

    -- Iterate over all tracks and patterns to find selected tracks
    for track_index = 1, total_tracks do
      for sequence_index = 1, total_patterns do
        if sequencer:track_sequence_slot_is_selected(track_index, sequence_index) then
          if not selected_tracks[track_index] then
            table.insert(selected_tracks, track_index)
          end
          break -- Stop checking this track, as we already know it's selected
        end
      end
    end
  end

  -- Read selection from the Pattern Matrix
  read_pattern_matrix_selection()

  -- Fallback to the currently selected track if no valid selection exists
  if #selected_tracks == 0 then
    table.insert(selected_tracks, song.selected_track_index)
  end

  -- Remove any invalid tracks (Send or Master Tracks)
  for i = #selected_tracks, 1, -1 do
    if selected_tracks[i] > song.sequencer_track_count then
      table.remove(selected_tracks, i)
    end
  end

  -- Ensure there are valid tracks to group
  if #selected_tracks == 0 then return end

  -- Insert the group after the last selected track
  local groupPos = selected_tracks[#selected_tracks] + 1
  if groupPos > song.sequencer_track_count then
    groupPos = song.sequencer_track_count + 1
  end
  song:insert_group_at(groupPos)

  -- Add selected tracks to the group in their original order
  -- Add selected tracks to the group in their original order
  for i = #selected_tracks, 1, -1 do
    local track_index = selected_tracks[i]
    song:add_track_to_group(track_index, groupPos)
  end
end

renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Selection in Pattern Matrix to Group",invoke=function() SelectionInPatternMatrixToGroup() end}
------------
------------
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

-- Shortcuts as requested by Casiino
-- 
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (-16)",invoke=function() computerKeyboardVolChange(-16) end}
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (+16)",invoke=function() computerKeyboardVolChange(16) end}
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

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (-5)",invoke=function() selectedSampleFinetune(-5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Finetune (+5)",invoke=function() selectedSampleFinetune(5) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume (+0.05)",invoke=function() selectedSampleVolume(0.05) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume (-0.05)",invoke=function() selectedSampleVolume(-0.05) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning (+0.05)",invoke=function() selectedSamplePanning(0.05) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Panning (-0.05)",invoke=function() selectedSamplePanning(-0.05) end}


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (-5)",invoke=function() selectedSampleTranspose(-5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Transpose (+5)",invoke=function() selectedSampleTranspose(5) end}

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

for i = 0, 9 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to 0" .. i,
    invoke=function() selectedSampleMod(i) end}
end

for i = 10, 32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod to " .. i,
    invoke=function() selectedSampleMod(i) end}
end


for i = 0, 9 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to 0" .. i,invoke=function() selectedSampleFX(i) end}
end

for i = 10, 32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX to " .. i,invoke=function() selectedSampleFX(i) end}
end

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


for i = 0, 9 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to 0" .. i,invoke=function() selectedInstrumentAllMod(i) end}
end
for i = 10, 32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Mod to " .. i,invoke=function() selectedInstrumentAllMod(i) end}
end

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

for i = 1, 9 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to 0" .. i,invoke=function() selectedInstrumentAllFx(i) end}
end

for i = 10, 32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Fx to " .. i,invoke=function() selectedInstrumentAllFx(i) end}
end


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

function selectedInstrumentAllAutoseekToggle()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if the instrument and samples are valid
  if not instrument or #instrument.samples == 0 then
    print("No samples are available or no instrument selected.")
    return
  end

  -- Iterate through each sample in the instrument and toggle the autoseek setting
  for i, sample in ipairs(instrument.samples) do
    sample.autoseek = not sample.autoseek
  end
end

function selectedInstrumentAllAutoseekControl(state)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if the instrument and samples are valid
  if not instrument or #instrument.samples == 0 then
    --print("No samples are available or no instrument selected.")
    return
  end

  -- Convert numerical state to boolean for autoseek
  local autoseekState = (state == 1)

  -- Iterate through each sample in the instrument and set the autoseek setting
  for i, sample in ipairs(instrument.samples) do
    sample.autoseek = autoseekState
  end
end


function setAllInstrumentsAllSamplesAutoseek(state)
  local song=renoise.song()
  
  -- Convert numerical state to boolean for autoseek
  local autoseekState = (state == 1)
  
  -- Iterate through all instruments
  for _, instrument in ipairs(song.instruments) do
    -- Skip instruments with no samples
    if #instrument.samples > 0 then
      -- Iterate through each sample in the instrument and set autoseek
      for _, sample in ipairs(instrument.samples) do
        sample.autoseek = autoseekState
      end
    end
  end
  
  -- Show status message
  local stateText = autoseekState and "ON" or "OFF"
  renoise.app():show_status("Set Autoseek " .. stateText .. " for all samples in all instruments")
end



renoise.tool():add_keybinding{name="Global:Paketti:Set All Instruments All Samples Autoseek On",invoke=function() setAllInstrumentsAllSamplesAutoseek(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set All Instruments All Samples Autoseek Off",invoke=function() setAllInstrumentsAllSamplesAutoseek(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autofade On/Off",invoke=function() selectedInstrumentAllAutofadeToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autofade On",invoke=function() selectedInstrumentAllAutofadeControl(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autofade Off",invoke=function() selectedInstrumentAllAutofadeControl(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autoseek On/Off",invoke=function() selectedInstrumentAllAutoseekToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autoseek On",invoke=function() selectedInstrumentAllAutoseekControl(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument All Autoseek Off",invoke=function() selectedInstrumentAllAutoseekControl(0) end}

function setAllInstrumentsAllSamplesAutofade(state)
  local song=renoise.song()
  
  -- Convert numerical state to boolean for autofade
  local autofadeState = (state == 1)
  
  -- Iterate through all instruments
  for _, instrument in ipairs(song.instruments) do
    -- Skip instruments with no samples
    if #instrument.samples > 0 then
      -- Iterate through each sample in the instrument and set autofade
      for _, sample in ipairs(instrument.samples) do
        sample.autofade = autofadeState
      end
    end
  end
  
  -- Show status message
  local stateText = autofadeState and "ON" or "OFF"
  renoise.app():show_status("Set Autofade " .. stateText .. " for all samples in all instruments")
end

renoise.tool():add_keybinding{name="Global:Paketti:Set All Instruments All Samples Autofade On",invoke=function() setAllInstrumentsAllSamplesAutofade(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set All Instruments All Samples Autofade Off",invoke=function() setAllInstrumentsAllSamplesAutofade(0) end}
-----------
function halveBeatSyncLinesAll()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    if currInst == nil or not s.instruments[currInst] then
        print("No instrument selected.")
        return
    end
    local samples = s.instruments[currInst].samples
    if #samples < 1 then
        print("No samples available in the selected instrument.")
        return
    end

    local start_index = 1
    if #samples > 1 and #samples[1].slice_markers > 0 then
        start_index = 2
    end

    local reference_sync_lines = samples[start_index].beat_sync_lines
    if not samples[start_index].beat_sync_enabled then
        samples[start_index].beat_sync_enabled = true
        reference_sync_lines = samples[start_index].beat_sync_lines
    end
    if not reference_sync_lines then
        print("No valid samples found to reference for beatsync lines.")
        return
    end

    local new_sync_lines = math.max(math.floor(reference_sync_lines / 2), 1)

    -- Apply new sync lines
    for i = start_index, #samples do
        if samples[i].sample_buffer and samples[i].sample_buffer.has_sample_data then
            if not samples[i].beat_sync_enabled then
                samples[i].beat_sync_enabled = true
            end
            samples[i].beat_sync_lines = new_sync_lines
        end
    end
    renoise.app():show_status("Beatsync lines halved for all applicable samples from " .. reference_sync_lines .. " to " .. new_sync_lines)
end

function halveBeatSyncLinesSelected()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    if currInst == nil or not s.instruments[currInst] then
        print("No instrument selected.")
        return
    end
    local samples = s.instruments[currInst].samples
    local currSample = s.selected_sample_index
    if currSample == nil or currSample < 1 or currSample > #samples then
        print("Selected sample is invalid or does not exist.")
        return
    end
    if not samples[currSample].sample_buffer or not samples[currSample].sample_buffer.has_sample_data then
        print("Selected sample slot contains no sample data.")
        return
    end
    if not samples[currSample].beat_sync_enabled then
        samples[currSample].beat_sync_enabled = true
    end
    local reference_sync_lines = samples[currSample].beat_sync_lines
    local new_sync_lines = math.max(math.floor(reference_sync_lines / 2), 1)
    samples[currSample].beat_sync_lines = new_sync_lines
    renoise.app():show_status("Beatsync lines halved for the selected sample from " .. reference_sync_lines .. " to " .. new_sync_lines)
end

function doubleBeatSyncLinesAll()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    if currInst == nil or not s.instruments[currInst] then
        print("No instrument selected.")
        return
    end
    local samples = s.instruments[currInst].samples
    if #samples < 1 then
        print("No samples available in the selected instrument.")
        return
    end

    local start_index = 1
    if #samples > 1 and #samples[1].slice_markers > 0 then
        start_index = 2
    end

    local reference_sync_lines = samples[start_index].beat_sync_lines
    if not samples[start_index].beat_sync_enabled then
        samples[start_index].beat_sync_enabled = true
        reference_sync_lines = samples[start_index].beat_sync_lines
    end
    if not reference_sync_lines then
        print("No valid samples found to reference for beatsync lines.")
        return
    end
    if reference_sync_lines >= 512 then
        renoise.app():show_status("Maximum Beatsync line amount is 512, cannot go higher.")
        return
    end
    local new_sync_lines = math.min(reference_sync_lines * 2, 512)
    if reference_sync_lines == 1 then new_sync_lines = 2 end

    -- Apply new sync lines
    for i = start_index, #samples do
        if samples[i].sample_buffer and samples[i].sample_buffer.has_sample_data then
            if not samples[i].beat_sync_enabled then
                samples[i].beat_sync_enabled = true
            end
            samples[i].beat_sync_lines = new_sync_lines
        end
    end
    renoise.app():show_status("Beatsync lines doubled for all applicable samples from " .. reference_sync_lines .. " to " .. new_sync_lines)
end

function doubleBeatSyncLinesSelected()
    local s = renoise.song()
    local currInst = s.selected_instrument_index
    if currInst == nil or not s.instruments[currInst] then
        print("No instrument selected.")
        return
    end
    local samples = s.instruments[currInst].samples
    local currSample = s.selected_sample_index
    if currSample == nil or currSample < 1 or currSample > #samples then
        print("Selected sample is invalid or does not exist.")
        return
    end
    if not samples[currSample].sample_buffer or not samples[currSample].sample_buffer.has_sample_data then
        print("Selected sample slot contains no sample data.")
        return
    end
    if not samples[currSample].beat_sync_enabled then
        samples[currSample].beat_sync_enabled = true
    end
    local reference_sync_lines = samples[currSample].beat_sync_lines
    if reference_sync_lines >= 512 then
        renoise.app():show_status("Maximum Beatsync line amount is 512, cannot go higher.")
        return
    end
    local new_sync_lines = math.min(reference_sync_lines * 2, 512)
    if reference_sync_lines == 1 then new_sync_lines = 2 end
    samples[currSample].beat_sync_lines = new_sync_lines
    renoise.app():show_status("Beatsync lines doubled for the selected sample from " .. reference_sync_lines .. " to " .. new_sync_lines)
end

renoise.tool():add_keybinding{name="Global:Paketti:Halve Beatsync Lines (All)",invoke=function() halveBeatSyncLinesAll() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Beatsync Lines (Selected Sample)",invoke=function() halveBeatSyncLinesSelected() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Beatsync Lines (All)",invoke=function() doubleBeatSyncLinesAll() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Beatsync Lines (Selected Sample)",invoke=function() doubleBeatSyncLinesSelected() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Halve Beatsync Lines (All)",invoke=function() halveBeatSyncLinesAll() halveBeatSyncLinesAll()end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Halve Beatsync Lines (Selected Sample)",invoke=function() halveBeatSyncLinesSelected() halveBeatSyncLinesSelected() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Double Beatsync Lines (All)",invoke=function() doubleBeatSyncLinesAll() doubleBeatSyncLinesAll() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Double Beatsync Lines (Selected Sample)",invoke=function() doubleBeatSyncLinesSelected() doubleBeatSyncLinesSelected()  end}
-- Function to load a pitchbend instrument
function pitchedInstrument(st)
  renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets" .. separator .. st .. "st_Pitchbend.xrni")
  local selected_instrument = renoise.song().selected_instrument
  selected_instrument.name = st .. "st_Pitchbend Instrument"
  selected_instrument.macros_visible = true
  selected_instrument.sample_modulation_sets[1].name = st .. "st_Pitchbend"
end

function pitchedDrumkit()
  local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
  local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"

--  renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
renoise.app():load_instrument(defaultInstrument)


renoise.song().selected_instrument.name="Pitchbend Drumkit"
renoise.song().instruments[renoise.song().selected_instrument_index].macros_visible = true
renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name=("Pitchbend Drumkit")
end


renoise.tool():add_keybinding{name="Global:Paketti:12st PitchBend Instrument Init",invoke=function() pitchedInstrument(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:PitchBend Drumkit Instrument Init",invoke=function() pitchedDrumkit() end}

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

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Transpose (-1)",invoke=function() transposeAllSamplesInInstrument(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Transpose (+1)",invoke=function() transposeAllSamplesInInstrument(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Transpose (-12)",invoke=function() transposeAllSamplesInInstrument(-12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Transpose (+12)",invoke=function() transposeAllSamplesInInstrument(12) end}

function resetInstrumentTranspose(amount)
    local instrument = renoise.song().selected_instrument
    for i = 1, #instrument.samples do
        instrument.samples[i].transpose = 0
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Transpose 0 (Reset)",
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



renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Velocity Tracking On",
invoke=function() selectedInstrumentVelocityTracking(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Velocity Tracking Off",
invoke=function() selectedInstrumentVelocityTracking(0) end}


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
if renoise.song().selected_sample ~= nil then 

renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume=true
end
end}


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Velocity Tracking Off",
invoke=function() 
if renoise.song().selected_sample ~= nil then 

renoise.song().instruments[renoise.song().selected_instrument_index].sample_mappings[1][renoise.song().selected_sample_index].map_velocity_to_volume=false
end
end}



-------------
function selectInstrumentShortcut(instrumentNumber)
local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

local instCount = #renoise.song().instruments
  
if  instCount < instrumentNumber then 
renoise.app():show_status("This Instrument Number does not exist: " .. instrumentNumber)

else
renoise.song().selected_instrument_index = instrumentNumber
end
end


for i = 0, 32 do 
renoise.tool():add_keybinding{name="Global:Paketti:Select Instrument " .. formatDigits(2,i),invoke=function() selectInstrumentShortcut(i) end}
end
------
function selectNextGroupTrack()
    local song=renoise.song()
    local current_index = song.selected_track_index
    local num_tracks = #song.tracks

    -- Start from the next track of the currently selected one and loop around if necessary
    for i = current_index + 1, num_tracks + current_index do
        -- Use modulo operation to wrap around the track index when it exceeds the number of tracks
        local track_index = (i - 1) % num_tracks + 1
        if song.tracks[track_index].type == renoise.Track.TRACK_TYPE_GROUP then
            song.selected_track_index = track_index
            print("Moved to next group track: " .. song.tracks[track_index].name)
            return -- Exit after finding and moving to the next group track
        end
    end
end

function selectPreviousGroupTrack()
    local song=renoise.song()
    local current_index = song.selected_track_index
    local num_tracks = #song.tracks

    -- Start from the track just before the currently selected one and loop around if necessary
    for i = current_index - 1, current_index - num_tracks, -1 do
        -- Use modulo operation to wrap around the track index when it goes below 1
        local track_index = (i - 1) % num_tracks + 1
        if song.tracks[track_index].type == renoise.Track.TRACK_TYPE_GROUP then
            song.selected_track_index = track_index
            print("Moved to previous group track: " .. song.tracks[track_index].name)
            return -- Exit after finding and moving to the previous group track
        end
    end
end
renoise.tool():add_keybinding{name="Global:Paketti:Select Group (Next)",invoke=function() selectNextGroupTrack() end}
renoise.tool():add_keybinding{name="Global:Paketti:Select Group (Previous)",invoke=function() selectPreviousGroupTrack() end}
------
renoise.tool():add_keybinding{name="Global:Paketti:Delete/Clear/Wipe Entire Row",invoke=function() renoise.song().selected_line:clear() end}
renoise.tool():add_midi_mapping{name="Paketti:Delete/Clear/Wipe Entire Row x[Toggle]",
  invoke=function(message) if message:is_trigger() then clear_current_line() end end}

  function PakettiDeleteClearWipeSelectedNoteColumnWithEditStep()
  local song=renoise.song()
  local pattern = song.selected_pattern
  local num_lines = pattern.number_of_lines
  local edit_step = song.transport.edit_step
  local line_index = song.selected_line_index
  local note_column = song.selected_note_column

  -- Ensure we have a selected note column
  if note_column then
    -- Wipe the selected note column contents (note, instrument, volume, panning, delay, samplefx)
    note_column:clear()
  end

  -- Calculate the next line index
  local next_line_index = line_index + edit_step
  if next_line_index > num_lines then
    next_line_index = next_line_index - num_lines
  end

  -- Move to the next line
  song.selected_line_index = next_line_index

  -- Show status to notify the action performed
  renoise.app():show_status("Wiped selected note column and moved by edit step")
end

renoise.tool():add_midi_mapping{name="Paketti:Delete/Clear/Wipe Selected Note Column with EditStep x[Toggle]",
  invoke=function(message) if message:is_trigger() then PakettiDeleteClearWipeSelectedNoteColumnWithEditStep() end end}

  function PakettiDeleteClearWipeEntireRowWithEditStep()
    local song=renoise.song()
    local pattern = song.selected_pattern
    local num_lines = pattern.number_of_lines
    local edit_step = song.transport.edit_step
    local line_index = song.selected_line_index
  
    -- Clear the entire current line
    song.selected_line:clear()
  
    -- Calculate the next line index
    local next_line_index = line_index + edit_step
    if next_line_index > num_lines then
      next_line_index = next_line_index - num_lines
    end
  
    -- Move to the next line
    song.selected_line_index = next_line_index
  
    -- Show status to notify the action performed
    renoise.app():show_status("Wiped entire row and moved by edit step")
  end
  
  renoise.tool():add_keybinding{name="Global:Paketti:Delete/Clear/Wipe Entire Row with EditStep",invoke=function() 
      PakettiDeleteClearWipeEntireRowWithEditStep() 
    end
  }
  
  renoise.tool():add_midi_mapping{name="Paketti:Delete/Clear/Wipe Entire Row with EditStep x[Toggle]",
    invoke=function(message) 
      if message:is_trigger() then 
        PakettiDeleteClearWipeEntireRowWithEditStep() 
      end 
    end
  }


function SelectedNoteColumnClear()
  if renoise.song().selected_note_column_index ~= nil then
    renoise.song().selected_note_column:clear()
  else
    renoise.app():show_status("You are not on a Note Column, doing nothing.")
  end
end
renoise.tool():add_midi_mapping{name="Paketti:Delete/Clear/Wipe Selected Note Column x[Toggle]",
invoke=function(message) if message:is_trigger() then SelectedNoteColumnClear() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Delete/Clear/Wipe Selected Note Column",
invoke=function() SelectedNoteColumnClear() end}


renoise.tool():add_keybinding{name="Global:Paketti:Delete/Clear/Wipe Selected Note Column with EditStep", 
  invoke=function() PakettiDeleteClearWipeSelectedNoteColumnWithEditStep() end}

-----

function setInstrumentVolume(amount)
    -- Access the currently selected instrument in Renoise
    local instrument = renoise.song().selected_instrument

    -- Iterate through all samples in the instrument
    for i = 1, #instrument.samples do
        -- Access each sample's volume property
        local currentVolume = instrument.samples[i].volume
        local newVolume = currentVolume + amount

        -- Clamp the volume value to be within the valid range of 0.0 to 4.0
        if newVolume > 4.0 then
            newVolume = 4.0
        elseif newVolume < 0.0 then
            newVolume = 0.0
        end

        -- Apply the new volume value to the sample
        instrument.samples[i].volume = newVolume
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Volume (All) (+0.01)",invoke=function() setInstrumentVolume(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Volume (All) (-0.01)",invoke=function() setInstrumentVolume(-0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Volume Reset (All) (0.0dB)",invoke=function()
    local instrument = renoise.song().selected_instrument
    for i=1, #instrument.samples do instrument.samples[i].volume=1 end end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Volume (All) (-INF dB)",invoke=function()
    local instrument = renoise.song().selected_instrument
    for i=1, #instrument.samples do instrument.samples[i].volume=0 end end}

function setActualInstrumentVolume(amount)
  local instrument = renoise.song().selected_instrument
  
  if not instrument then
    renoise.app():show_status("Cannot set volume: No instrument selected.")
    return
  end
  
  local currentVolume = instrument.volume
  local newVolume = currentVolume + amount
  
  -- Clamp the volume value to be within the valid range of 0.0 to 1.99526
  if newVolume > 1.99526 then
    newVolume = 1.99526
  elseif newVolume < 0.0 then
    newVolume = 0.0
  end
  
  -- Apply the new volume value to the instrument
  instrument.volume = newVolume
  renoise.app():show_status("Instrument volume set to " .. newVolume)
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Global Volume (+0.01)",invoke=function() setActualInstrumentVolume(0.01) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Global Volume (-0.01)",invoke=function() setActualInstrumentVolume(-0.01) end}


renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Global Volume (0.0dB)",invoke=function()
    renoise.song().selected_instrument.volume=1 end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Global Volume (-INF dB)",invoke=function()
    renoise.song().selected_instrument.volume=0 end}

function setInstrumentPanning(amount)
    -- Access the currently selected instrument in Renoise
    local instrument = renoise.song().selected_instrument

    -- Iterate through all samples in the instrument
    for i = 1, #instrument.samples do
        -- Access each sample's panning property
        local currentPanning = instrument.samples[i].panning
        local newPanning = currentPanning + amount

        -- Clamp the panning value to be within the valid range of 0.0 to 1.0
        if newPanning > 1.0 then
            newPanning = 1.0
        elseif newPanning < 0.0 then
            newPanning = 0.0
        end

        -- Apply the new panning value to the sample
        instrument.samples[i].panning = newPanning
    end
end

function setInstrumentPanningValue(value)
    -- Access the currently selected instrument in Renoise
    local instrument = renoise.song().selected_instrument

    -- Iterate through all samples in the instrument
    for i = 1, #instrument.samples do
        -- Set the panning value to the sample
        instrument.samples[i].panning = value
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Panning (+0.01)",invoke=function() setInstrumentPanning(0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Panning (-0.01)",invoke=function() setInstrumentPanning(-0.01) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Panning Reset (Center)",invoke=function() setInstrumentPanningValue(0.5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Panning 0.0 (Left)",invoke=function() setInstrumentPanningValue(0.0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Panning 1.0 (Right)",invoke=function() setInstrumentPanningValue(1.0) end}
---------
-- Global flag to track whether the Catch Octave notifier is enabled
catch_octave_enabled = false

-- Function to update the octave based on the note string of the currently selected note column
function update_octave_from_selected_note_column()
  -- Check if renoise.song() is not nil
  if not renoise.song() then
    return
  end

  local song=renoise.song()
  local window = renoise.app().window

  -- Only proceed if the active middle frame is the Pattern Editor
  if window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    return
  end

  local selected_line = song.selected_line
  local selected_note_column_index = song.selected_note_column_index
  local selected_effect_column_index = song.selected_effect_column_index

  -- Check if the current selection is a note column and not an effect column
  if selected_note_column_index > 0 and selected_effect_column_index == 0 then
    local note_column = selected_line.note_columns[selected_note_column_index]

    -- Check if the note string is not empty
    if note_column.note_string ~= "" then
      -- Extract the octave part from the note string (last character)
      local note_string = note_column.note_string
      local octave = tonumber(note_string:sub(-1))

      -- Clamp the octave value to the range 0-8
      if octave then
        if octave > 8 then
          octave = 8
        end
        song.transport.octave = octave
      end
    end
  end
end

-- Function to add notifiers
function add_notifiers()
  -- Check if renoise.song() is not nil
  if not renoise.song() then
    return
  end

  -- Add notifiers to trigger the function when the selected track or pattern changes
  local song=renoise.song()
  song.selected_track_index_observable:add_notifier(update_octave_from_selected_note_column)
  song.selected_pattern_observable:add_notifier(update_octave_from_selected_note_column)

  -- Periodic check for changes in the selected line index
  renoise.tool().app_idle_observable:add_notifier(update_octave_from_selected_note_column)
end

-- Function to remove notifiers
function remove_notifiers()
  -- Check if renoise.song() is not nil
  if not renoise.song() then
    return
  end

  -- Remove the notifiers
  local song=renoise.song()
  pcall(function() song.selected_track_index_observable:remove_notifier(update_octave_from_selected_note_column) end)
  pcall(function() song.selected_pattern_observable:remove_notifier(update_octave_from_selected_note_column) end)
  pcall(function() renoise.tool().app_idle_observable:remove_notifier(update_octave_from_selected_note_column) end)
end

-- Function to toggle the Catch Octave state
function toggle_catch_octave()
  if catch_octave_enabled then
    remove_notifiers()
    catch_octave_enabled = false
    renoise.app():show_status("Catch Octave disabled")
  else
    add_notifiers()
    catch_octave_enabled = true
    renoise.app():show_status("Catch Octave enabled")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Catch Octave",invoke=toggle_catch_octave}

-- Initial call to add notifiers if enabled
if catch_octave_enabled then
  add_notifiers()
end


-----
-- Function to adjust the slice marker by a specified delta
function adjustSliceKeyshortcut(slice_index, delta)
    local song=renoise.song()
    local sample = song.selected_sample

    -- Ensure there is a selected sample and enough slice markers
    if not sample or #sample.slice_markers < slice_index then
        return
    end

    local slice_markers = sample.slice_markers
    local min_pos, max_pos

    -- Calculate the bounds for the slice marker movement
    if slice_index == 1 then
        min_pos = 1
        max_pos = (slice_markers[slice_index + 1] or sample.sample_buffer.number_of_frames) - 1
    elseif slice_index == #slice_markers then
        min_pos = slice_markers[slice_index - 1] + 1
        max_pos = sample.sample_buffer.number_of_frames - 1
    else
        min_pos = slice_markers[slice_index - 1] + 1
        max_pos = slice_markers[slice_index + 1] - 1
    end

    -- Get the current position of the slice marker and calculate new position
    local current_pos = slice_markers[slice_index]
    local new_pos = current_pos + delta

    -- Ensure the new position is within the allowed bounds
    if new_pos < min_pos then
        new_pos = min_pos
    elseif new_pos > max_pos then
        new_pos = max_pos
    end

    -- Move the slice marker
    sample:move_slice_marker(slice_markers[slice_index], new_pos)
end

-- List of deltas with their corresponding keybinding names
local deltas = {["+1"] = 1, ["-1"] = -1, ["+10"] = 10, ["-10"] = -10, ["+16"] = 16, ["-16"] = -16, ["+32"] = 32, ["-32"] = -32}

-- Create key bindings for each slice and each delta
for i = 1, 32 do
    for name, delta in pairs(deltas) do
        renoise.tool():add_keybinding{name="Sample Editor:Paketti:Nudge Slice " .. formatDigits(2,i) .. " by (" .. name .. ")",invoke=function() adjustSliceKeyshortcut(i, delta) end}
    end
end
-----------
-- Function to set the interpolation mode for all samples within the selected instrument
function setSelectedInstrumentInterpolation(amount)
  local instrument = renoise.song().selected_instrument
  for _, sample in ipairs(instrument.samples) do
    sample.interpolation_mode = amount
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Interpolation to 1 (None)",invoke=function() setSelectedInstrumentInterpolation(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Interpolation to 2 (Linear)",invoke=function() setSelectedInstrumentInterpolation(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Interpolation to 3 (Cubic)",invoke=function() setSelectedInstrumentInterpolation(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Interpolation to 4 (Sinc)",invoke=function() setSelectedInstrumentInterpolation(4) end}



function selectedInstrumentFinetune(amount)
local currentSampleFinetune = renoise.song().selected_sample.fine_tune
local changedSampleFinetune = currentSampleFinetune + amount
if changedSampleFinetune > 127 then changedSampleFinetune = 127
else if changedSampleFinetune < -127 then changedSampleFinetune = -127 end end
renoise.song().selected_sample.fine_tune=changedSampleFinetune
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Finetune (-1)",invoke=function()  selectedInstrumentFinetune(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Finetune (+1)",invoke=function()  selectedInstrumentFinetune(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Finetune (-10)",invoke=function() selectedInstrumentFinetune(-10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Finetune (+10)",invoke=function() selectedInstrumentFinetune(10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Finetune (0)",invoke=function() renoise.song().selected_sample.fine_tune=0 end}


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
    return
  end

  -- Assign the FX chain index to the selected sample
  -- This assignment confidently allows setting the index to 0
  instrument.samples[renoise.song().selected_sample_index].device_chain_index = number
end

-- Function to select the next modulation set
function selectNextModGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_modulation_sets == 0 then
    print("No modulation sets available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.modulation_set_index
  local next_index = (current_index % #instrument.sample_modulation_sets) + 1

  selectedSampleMod(next_index)
end

-- Function to select the previous modulation set
function selectPreviousModGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_modulation_sets == 0 then
    print("No modulation sets available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.modulation_set_index
  local previous_index = (current_index - 2 + #instrument.sample_modulation_sets) % #instrument.sample_modulation_sets + 1

  selectedSampleMod(previous_index)
end

-- Function to select the next FX chain
function selectNextFXGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_device_chains == 0 then
    print("No FX chains available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.device_chain_index
  local next_index = (current_index % #instrument.sample_device_chains) + 1

  selectedSampleFX(next_index)
end

-- Function to select the previous FX chain
function selectPreviousFXGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_device_chains == 0 then
    print("No FX chains available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.device_chain_index
  local previous_index = (current_index - 2 + #instrument.sample_device_chains) % #instrument.sample_device_chains + 1

  selectedSampleFX(previous_index)
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod Group (Next)",invoke=function() selectNextModGroup() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Mod Group (Previous)",invoke=function() selectPreviousModGroup() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX Group (Next)",invoke=function() selectNextFXGroup() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX Group (Previous)",invoke=function() selectPreviousFXGroup() end}


-- Function to assign a modulation set to all samples based on a given index
function selectedInstrumentSampleMod(number)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if there are any modulation sets
  if not instrument or #instrument.sample_modulation_sets == 0 then
    print("No modulation sets available or no instrument selected.")
    return
  end

  -- Get the number of available modulation sets
  local num_modulation_sets = #instrument.sample_modulation_sets

  -- Check if the provided index is within the valid range
  if number < 0 or number > num_modulation_sets then
    return
  end

  -- Assign the modulation set index to all samples
  for i = 1, #instrument.samples do
    instrument.samples[i].modulation_set_index = number
  end
end

-- Function to assign an FX chain to all samples based on a given index
function selectedInstrumentSampleFX(number)
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  -- Check if there are any FX chains
  if not instrument or #instrument.sample_device_chains == 0 then
    print("No FX chains available or no instrument selected.")
    return
  end

  -- Get the number of available FX chains
  local num_fx_sets = #instrument.sample_device_chains

  -- Check if the provided index is within the valid range
  if number < 0 or number > num_fx_sets then
    return
  end

  -- Assign the FX chain index to all samples
  for i = 1, #instrument.samples do
    instrument.samples[i].device_chain_index = number
  end
end

-- Function to select the next modulation set for all samples
function selectedInstrumentNextModGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_modulation_sets == 0 then
    print("No modulation sets available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.modulation_set_index
  local next_index = (current_index % #instrument.sample_modulation_sets) + 1

  selectedInstrumentSampleMod(next_index)
end

-- Function to select the previous modulation set for all samples
function selectedInstrumentPreviousModGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_modulation_sets == 0 then
    print("No modulation sets available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.modulation_set_index
  local previous_index = (current_index - 2 + #instrument.sample_modulation_sets) % #instrument.sample_modulation_sets + 1

  selectedInstrumentSampleMod(previous_index)
end

-- Function to select the next FX chain for all samples
function selectedInstrumentNextFXGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_device_chains == 0 then
    print("No FX chains available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.device_chain_index
  local next_index = (current_index % #instrument.sample_device_chains) + 1

  selectedInstrumentSampleFX(next_index)
end

-- Function to select the previous FX chain for all samples
function selectedInstrumentPreviousFXGroup()
  local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]

  if not instrument or #instrument.sample_device_chains == 0 then
    print("No FX chains available or no instrument selected.")
    return
  end

  local selected_sample = instrument.samples[renoise.song().selected_sample_index]
  local current_index = selected_sample.device_chain_index
  local previous_index = (current_index - 2 + #instrument.sample_device_chains) % #instrument.sample_device_chains + 1

  selectedInstrumentSampleFX(previous_index)
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Mod Group (Next)",invoke=function() selectedInstrumentNextModGroup() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument Mod Group (Previous)",invoke=function() selectedInstrumentPreviousModGroup() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument FX Group (Next)",invoke=function() selectedInstrumentNextFXGroup() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Instrument FX Group (Previous)",invoke=function() selectedInstrumentPreviousFXGroup() end}
---
-- Function to print debug information
function debug_print(message)
  renoise.app():show_status(message)
  print(message)
end

-- Function to halve the selection range
function halve_selection_range()
  local song=renoise.song()
  if not song then 
    debug_print("No song available")
    return 
  end

  local instrument = song.selected_instrument
  if not instrument then 
    debug_print("No instrument selected")
    return 
  end

  local sample = song.selected_sample
  if not sample then 
    debug_print("No sample selected")
    return 
  end

  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then 
    debug_print("No sample buffer or no sample data")
    return 
  end

  local selection = sample_buffer.selection_range
  if #selection == 2 then
    local start_pos = selection[1]
    local end_pos = selection[2]
    if start_pos == end_pos then
      debug_print("Selection range is of zero length: " .. start_pos .. "-" .. end_pos)
      return
    end
    local new_end_pos = start_pos + math.floor((end_pos - start_pos) / 2)

    sample_buffer.selection_range = {start_pos, new_end_pos}
    debug_print("Halved selection range from " .. start_pos .. "-" .. end_pos .. " to " .. start_pos .. "-" .. new_end_pos)
  else
    debug_print("Selection range is not valid: " .. #selection)
  end
end

-- Function to double the selection range
function double_selection_range()
  local song=renoise.song()
  if not song then 
    debug_print("No song available")
    return 
  end

  local instrument = song.selected_instrument
  if not instrument then 
    debug_print("No instrument selected")
    return 
  end

  local sample = song.selected_sample
  if not sample then 
    debug_print("No sample selected")
    return 
  end

  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then 
    debug_print("No sample buffer or no sample data")
    return 
  end

  local selection = sample_buffer.selection_range
  local total_frames = sample_buffer.number_of_frames
  if #selection == 2 then
    local start_pos = selection[1]
    local end_pos = selection[2]
    local selection_length = end_pos - start_pos
    local new_end_pos

    if selection_length == 0 then
      new_end_pos = start_pos + 1
    else
      new_end_pos = start_pos + selection_length * 2
    end

    if new_end_pos > total_frames then
      new_end_pos = total_frames
    end

    sample_buffer.selection_range = {start_pos, new_end_pos}
    debug_print("Doubled selection range from " .. start_pos .. "-" .. end_pos .. " to " .. start_pos .. "-" .. new_end_pos)
  else
    debug_print("Selection range is not valid: " .. #selection)
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Buffer Selection Halve",invoke=halve_selection_range}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Buffer Selection Double",invoke=double_selection_range}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Sample Buffer Selection Halve",invoke=halve_selection_range}
renoise.tool():add_midi_mapping{name="Sample Editor:Paketti:Sample Buffer Selection Double",invoke=double_selection_range}
-----------
-- Import the necessary modules
local vb = renoise.ViewBuilder()
local dialog = nil

-- Function to create a vertical ruler that matches the height of the columns
function trackOutputRoutingsGUI_vertical_rule(height)
  return vb:vertical_aligner{
    mode="center",
    vb:space{height=2},
    vb:column{
      width=2,
      style="panel",
      height=height
    },
    vb:space{height=2}
  }
end

-- Function to create a horizontal rule
function trackOutputRoutingsGUI_horizontal_rule()
  return vb:horizontal_aligner{
    mode="justify", 
    width="100%", 
    vb:space{width=2}, 
    vb:row{
      height=2, 
      style="panel", 
      width="100%"
    }, 
    vb:space{width=2}
  }
end

-- Function to create the GUI
function pakettiTrackOutputRoutingsDialog()
if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end


  -- Get the number of tracks
  local num_tracks = #renoise.song().tracks
  local tracks_per_column = 18
  local num_columns = math.ceil(num_tracks / tracks_per_column)
  local track_row_height = 24 -- Approximate height of each track row
  local column_height = tracks_per_column * track_row_height

  -- Create a view for the dialog content
  local content = vb:row{
   -- margin=10,
   -- spacing=10
  }

  -- Table to store dropdown elements
  local dropdowns = {}

  -- Loop through each column
  for col = 1, num_columns do
    -- Create a column to hold up to 18 tracks
    local column_content = vb:column{
      --margin=5,
      --spacing=5,
      width=200 -- Set column width to accommodate track name and dropdown
    }

    -- Add tracks to the column
    for i = 1, tracks_per_column do
      local track_index = (col - 1) * tracks_per_column + i
      if track_index > num_tracks then break end

      local track = renoise.song().tracks[track_index]
      local track_name = track.name
      local available_output_routings = track.available_output_routings
      local current_output_routing = track.output_routing

      -- Determine if the track is a group
      local is_group = track.type == renoise.Track.TRACK_TYPE_GROUP

      -- Create the dropdown
      local dropdown = vb:popup{
        items = available_output_routings,
        value = table.find(available_output_routings, current_output_routing),
        width=220 -- Set width to 200% of 60 to be 120
      }
      
      -- Store the dropdown element
      table.insert(dropdowns, {dropdown = dropdown, track_index = track_index})

      -- Add the track name and dropdown in the same row, align dropdown to the right
      column_content:add_child(vb:row{
        vb:text{
          text = track_name,
          font = is_group and "bold" or "normal",
          style = is_group and "strong" or "normal",
          width=140 -- Allocate 70% width for track name
        },
        dropdown
      })
    end

    -- Add the column to the content
    content:add_child(column_content)

    -- Add a vertical rule between columns, but not after the last column
    if col < num_columns then
      content:add_child(trackOutputRoutingsGUI_vertical_rule(column_height))
    end
  end

  -- Add a horizontal rule
  content:add_child(trackOutputRoutingsGUI_horizontal_rule())

  -- OK and Cancel buttons
  content:add_child(vb:row{
    --spacing=5,
    vb:button{
      text="OK",
      width="50%", -- Set OK button width to 50%
      notifier=function()
        -- Apply changes to the output routings
        for _, entry in ipairs(dropdowns) do
          local dropdown = entry.dropdown
          local track_index = entry.track_index
          local track = renoise.song().tracks[track_index]
          local selected_routing = dropdown.items[dropdown.value]
          if selected_routing ~= track.output_routing then
            track.output_routing = selected_routing
          end
        end
        dialog:close()
      end
    },
  vb:button{
    text="Refresh",
    width="33%", -- Equal width for all buttons
    notifier=function()
      dialog:close()
      pakettiTrackOutputRoutingsDialog()
    end
  },

    vb:button{
      text="Cancel",
      width="50%", -- Set Cancel button width to 50%
      notifier=function()
        dialog:close()
      end
    }
  })

  -- Show the dialog
  dialog = renoise.app():show_custom_dialog("Track Output Routings", content, my_keyhandler_func)
end
------------
-- Function to adjust the delay, panning, or volume column within the selected area in the pattern editor
function adjust_column(column_type, adjustment)
  -- Check if there's a valid song
  local song=renoise.song()
  if not song then
    renoise.app():show_status("No active song found.")
    return
  end
  
  -- Get the current selection in the pattern editor
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No selection in the pattern editor.")
    return
  end

  -- Loop through the selected tracks
  for track_index = selection.start_track, selection.end_track do
    local track = song:track(track_index)
    
    -- Make the appropriate column visible if it's not already
    if column_type == "delay" and not track.delay_column_visible then
      track.delay_column_visible = true
    elseif column_type == "panning" and not track.panning_column_visible then
      track.panning_column_visible = true
    elseif column_type == "volume" and not track.volume_column_visible then
      track.volume_column_visible = true
    end
    
    -- Loop through the selected lines
    for line_index = selection.start_line, selection.end_line do
      local pattern_index = song.selected_pattern_index
      local pattern = song:pattern(pattern_index)
      local line = pattern:track(track_index):line(line_index)
      
      -- Loop through the columns in the selected line
      for note_column_index = selection.start_column, selection.end_column do
        local note_column = line:note_column(note_column_index)
        if note_column then
          -- Adjust or reset the appropriate column value
          if adjustment == 0 then
            -- Wipe the column content
            if column_type == "delay" then
              note_column.delay_value = 0
            elseif column_type == "panning" then
              note_column.panning_string = ".."
            elseif column_type == "volume" then
              note_column.volume_string = ".."
            end
          else
            -- Adjust the column value
            if column_type == "delay" then
              local new_value = math.min(0xFF, math.max(0, note_column.delay_value + adjustment))
              note_column.delay_value = new_value
            elseif column_type == "panning" then
              local new_value = note_column.panning_value + adjustment
              if new_value < 0 then
                note_column.panning_string = ".."
              else
                note_column.panning_value = math.min(0x80, new_value)
              end
            elseif column_type == "volume" then
              local new_value = note_column.volume_value + adjustment
              if new_value < 0 then
                note_column.volume_string = ".."
              else
                note_column.volume_value = math.min(0x80, new_value)
              end
            end
          end
        end
      end
    end
  end
  
  -- Show a status message indicating the operation was successful
  renoise.app():show_status(column_type:gsub("^%l", string.upper) .. " Column adjustment (" .. adjustment .. ") applied successfully.")
end

-- Function to wipe the volume column within the selected area in the pattern editor
function wipe_volume_column()
  adjust_column("volume", 0)
end

-- Function to wipe the panning column within the selected area in the pattern editor
function wipe_panning_column()
  adjust_column("panning", 0)
end

-- Define the menu entries, keybindings, and MIDI mappings for the different adjustments
local function add_tool_entries(column_type, adjustment)
  local adj_str = (adjustment > 0) and "+" .. adjustment or tostring(adjustment)
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Note Columns..:Adjust Selection " .. column_type:gsub("^%l", string.upper) .. " Column " .. adj_str,invoke=function() adjust_column(column_type, adjustment) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Adjust Selection " .. column_type:gsub("^%l", string.upper) .. " Column (" .. adj_str .. ")",invoke=function() adjust_column(column_type, adjustment) end}
  renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Adjust Selection " .. column_type:gsub("^%l", string.upper) .. " Column (" .. adj_str .. ")",invoke=function() adjust_column(column_type, adjustment) end}
end

-- Define the menu entries, keybindings, and MIDI mappings for wiping the columns
local function add_wipe_entries(column_type)
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Note Columns..:Wipe Selection " .. column_type:gsub("^%l", string.upper) .. " Column",invoke=function() adjust_column(column_type, 0) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe Selection " .. column_type:gsub("^%l", string.upper) .. " Column",invoke=function() adjust_column(column_type, 0) end}
  renoise.tool():add_midi_mapping{name="Paketti:Clear/Wipe Selection " .. column_type:gsub("^%l", string.upper) .. " Column",invoke=function() adjust_column(column_type, 0) end}
end

for _, column_type in ipairs({"delay", "panning", "volume"}) do
  for _, adjustment in ipairs({1, -1, 10, -10}) do
    add_tool_entries(column_type, adjustment)
  end
end

for _, column_type in ipairs({"delay", "panning", "volume"}) do
  add_wipe_entries(column_type)
end

-----------
-- Function to duplicate the current track and set notes to the selected instrument
function setToSelectedInstrument_DuplicateTrack()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index

  -- Insert a new track
  song:insert_track_at(track_index + 1)
  song.selected_track_index = track_index + 1

  local new_track = song.tracks[track_index + 1]
  local old_track = song.tracks[track_index]

  -- Copy the content of the current track to the new track
  for i = 1, #song.patterns do
    local old_pattern_track = song.patterns[i].tracks[track_index]
    local new_pattern_track = song.patterns[i].tracks[track_index + 1]

    for line = 1, #old_pattern_track.lines do
      new_pattern_track:line(line):copy_from(old_pattern_track:line(line))
    end

    -- Change pattern data to use the selected instrument
    for line = 1, #new_pattern_track.lines do
      for _, note_column in ipairs(new_pattern_track:line(line).note_columns) do
        if note_column.instrument_value ~= 255 then
          note_column.instrument_value = selected_instrument_index - 1
        end
      end
    end
  end

  -- Copy Track DSPs and handle Instr. Automation
  local has_instr_automation = false
  local old_instr_automation_device = nil
  for dsp_index = 2, #old_track.devices do
    local old_device = old_track.devices[dsp_index]

    if old_device.device_path:find("Instr. Automation") then
      has_instr_automation = true
      old_instr_automation_device = old_device
    else
      local new_device = new_track:insert_device_at(old_device.device_path, dsp_index)
      for parameter_index = 1, #old_device.parameters do
        new_device.parameters[parameter_index].value = old_device.parameters[parameter_index].value
      end
      new_device.is_maximized = old_device.is_maximized
    end
  end

  -- Create a new Instr. Automation device if the original track had one
  if has_instr_automation then
    local new_device = new_track:insert_device_at("Audio/Effects/Native/*Instr. Automation", #new_track.devices + 1)

    -- Extract XML from the old device
    local old_device_xml = old_instr_automation_device.active_preset_data
    -- Modify the XML to update the instrument references
    local new_device_xml = old_device_xml:gsub("<instrument>(%d+)</instrument>", function(instr_index)
      return string.format("<instrument>%d</instrument>", selected_instrument_index - 1)
    end)
    -- Apply the modified XML to the new device
    new_device.active_preset_data = new_device_xml
    new_device.is_maximized = old_instr_automation_device.is_maximized
  end

  -- Adjust visibility settings for the new track
  new_track.visible_note_columns = old_track.visible_note_columns
  new_track.visible_effect_columns = old_track.visible_effect_columns
  new_track.volume_column_visible = old_track.volume_column_visible
  new_track.panning_column_visible = old_track.panning_column_visible
  new_track.delay_column_visible = old_track.delay_column_visible

  -- Handle automation duplication after fixing XML
  for i = 1, #song.patterns do
    local old_pattern_track = song.patterns[i].tracks[track_index]
    local new_pattern_track = song.patterns[i].tracks[track_index + 1]

    for _, automation in ipairs(old_pattern_track.automation) do
      local new_automation = new_pattern_track:create_automation(automation.dest_parameter)
      for _, point in ipairs(automation.points) do
        new_automation:add_point_at(point.time, point.value)
      end
    end
  end

  -- Select the new track
  song.selected_track_index = track_index + 1

  -- Ready the new track for transposition (select all notes)
  Deselect_All()
  MarkTrackMarkPattern()
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Track, set to Selected Instrument",invoke=function() setToSelectedInstrument_DuplicateTrack() end}

----------


-- Function to duplicate the current track and instrument, then copy notes and prepare the new track for editing
function duplicateTrackDuplicateInstrument()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index

  -- Detect the instrument used in the current track and select it
  local found_instrument_index = nil
  for _, line in ipairs(song.patterns[pattern_index].tracks[track_index].lines) do
    for _, note_column in ipairs(line.note_columns) do
      if note_column.instrument_value ~= 255 then
        found_instrument_index = note_column.instrument_value + 1
        break
      end
    end
    if found_instrument_index then break end
  end

  if found_instrument_index then
    song.selected_instrument_index = found_instrument_index
  else
    song.selected_instrument_index = 1
  end

  local instrument_index = song.selected_instrument_index
  local external_editor_open = false

  -- Check if the external editor is open and close it if necessary
  if song.instruments[instrument_index].plugin_properties.plugin_device then
    external_editor_open = song.instruments[instrument_index].plugin_properties.plugin_device.external_editor_visible
    if external_editor_open then
      song.instruments[instrument_index].plugin_properties.plugin_device.external_editor_visible = false
    end
  end

  -- Duplicate the current instrument
  song:insert_instrument_at(instrument_index + 1)
  local new_instrument_index = instrument_index + 1
  song.instruments[new_instrument_index]:copy_from(song.instruments[instrument_index])

  -- Handle phrases
  if #song.instruments[instrument_index].phrases > 0 then
    for phrase_index = 1, #song.instruments[instrument_index].phrases do
      song.instruments[new_instrument_index]:insert_phrase_at(phrase_index)
      song.instruments[new_instrument_index].phrases[phrase_index]:copy_from(song.instruments[instrument_index].phrases[phrase_index])
    end
  end

  -- Insert a new track
  song:insert_track_at(track_index + 1)
  song.selected_track_index = track_index + 1

  local new_track = song.tracks[track_index + 1]
  local old_track = song.tracks[track_index]

  -- Copy the content of the current track to the new track
  for i = 1, #song.patterns do
    local old_pattern_track = song.patterns[i].tracks[track_index]
    local new_pattern_track = song.patterns[i].tracks[track_index + 1]

    for line = 1, #old_pattern_track.lines do
      new_pattern_track:line(line):copy_from(old_pattern_track:line(line))
    end

    -- Change pattern data to use the new instrument
    for line = 1, #new_pattern_track.lines do
      for _, note_column in ipairs(new_pattern_track:line(line).note_columns) do
        if note_column.instrument_value == instrument_index - 1 then
          note_column.instrument_value = new_instrument_index - 1
        end
      end
    end
  end

  -- Copy Track DSPs and handle Instr. Automation
  local has_instr_automation = false
  local old_instr_automation_device = nil
  for dsp_index = 2, #old_track.devices do
    local old_device = old_track.devices[dsp_index]

    if old_device.device_path:find("Instr. Automation") then
      has_instr_automation = true
      old_instr_automation_device = old_device
    else
      local new_device = new_track:insert_device_at(old_device.device_path, dsp_index)
      for parameter_index = 1, #old_device.parameters do
        new_device.parameters[parameter_index].value = old_device.parameters[parameter_index].value
      end
      new_device.is_maximized = old_device.is_maximized
    end
  end

  -- Create a new Instr. Automation device if the original track had one
  if has_instr_automation then
    -- Select the new instrument
    song.selected_instrument_index = new_instrument_index

    local new_device = new_track:insert_device_at("Audio/Effects/Native/*Instr. Automation", #new_track.devices + 1)

    -- Extract XML from the old device
    local old_device_xml = old_instr_automation_device.active_preset_data
    -- Modify the XML to update the instrument references
    local new_device_xml = old_device_xml:gsub("<instrument>(%d+)</instrument>", function(instr_index)
      return string.format("<instrument>%d</instrument>", new_instrument_index - 1)
    end)
    -- Apply the modified XML to the new device
    new_device.active_preset_data = new_device_xml
    new_device.is_maximized = old_instr_automation_device.is_maximized
  end

  -- Adjust visibility settings for the new track
  new_track.visible_note_columns = old_track.visible_note_columns
  new_track.visible_effect_columns = old_track.visible_effect_columns
  new_track.volume_column_visible = old_track.volume_column_visible
  new_track.panning_column_visible = old_track.panning_column_visible
  new_track.delay_column_visible = old_track.delay_column_visible

  -- Handle automation duplication after fixing XML
  for i = 1, #song.patterns do
    local old_pattern_track = song.patterns[i].tracks[track_index]
    local new_pattern_track = song.patterns[i].tracks[track_index + 1]

    for _, automation in ipairs(old_pattern_track.automation) do
      local new_automation = new_pattern_track:create_automation(automation.dest_parameter)
      for _, point in ipairs(automation.points) do
        new_automation:add_point_at(point.time, point.value)
      end
    end
  end

  -- Select the new instrument
  song.selected_instrument_index = new_instrument_index

  -- Select the new track
  song.selected_track_index = track_index + 1

  -- Ready the new track for transposition (select all notes)
  Deselect_All()
  MarkTrackMarkPattern()

  -- Reopen the external editor if it was open
  if external_editor_open then
    song.instruments[new_instrument_index].plugin_properties.plugin_device.external_editor_visible = true
  end
end


renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Track Duplicate Instrument",invoke=function() duplicateTrackDuplicateInstrument() end}
------------
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Notes",invoke=function() note_interpolation() end}
renoise.tool():add_midi_mapping{name="Paketti:Interpolate Notes",invoke=function() note_interpolation() end}

-- Main function for note interpolation
function note_interpolation()
  -- Get the current song, pattern, and track
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local pattern_length = pattern.number_of_lines

  -- Determine the number of visible note columns in the track
  local visible_note_columns = renoise.song().selected_track.visible_note_columns

  -- Variables for start and end lines
  local start_line, end_line
  local start_column, end_column

  -- Determine start and end lines and columns based on selection in pattern
  if song.selection_in_pattern then
    local selection = song.selection_in_pattern
    start_line = selection.start_line
    end_line = selection.end_line
    start_column = selection.start_column
    end_column = selection.end_column

    -- Clip the end_column to the number of visible note columns
    if end_column > visible_note_columns then
      end_column = visible_note_columns
    end
  else
    start_column = song.selected_note_column_index
    end_column = start_column
    start_line = 1
    end_line = pattern_length
  end

  -- Debug output for selection
  print("Selection in Pattern:")
  print("Start Line:", start_line)
  print("End Line:", end_line)
  print("Start Column:", start_column)
  print("End Column:", end_column)
  print("Visible Note Columns:", visible_note_columns)

  -- Ensure that a note column is selected
  if start_column == 0 then
    renoise.app():show_error("No note column selected.")
    return
  end

  -- Ensure there is a difference between start and end lines
  if start_line == end_line then
    renoise.app():show_error("The selection must span at least two lines.")
    return
  end

  -- Iterate over each note column in the range
  for note_column_index = start_column, end_column do
    -- Retrieve note columns from start and end lines
    local start_note = track:line(start_line):note_column(note_column_index)
    local end_note = track:line(end_line):note_column(note_column_index)

    -- Debug output for start and end notes
    print("Note Column Index:", note_column_index)
    print("Start Note:", start_note)
    print("End Note:", end_note)

    -- Check if start and end notes are not empty
    if not start_note.is_empty and not end_note.is_empty then
      -- Calculate note difference and step
      local note_diff = end_note.note_value - start_note.note_value
      local steps = end_line - start_line
      local step_size = note_diff / steps

      -- Interpolate notes between start and end lines
      for i = 1, steps - 1 do
        local interpolated_note_value = math.floor(start_note.note_value + (i * step_size))
        local line_index = start_line + i
        local line = track:line(line_index)
        local note_column = line:note_column(note_column_index)
        note_column:copy_from(start_note)
        note_column.note_value = interpolated_note_value
      end
    else
      renoise.app():show_status("Both start and end lines must contain notes in column " .. note_column_index .. ".")
    end
  end
end





----------------------

-- Function to select the first track in the next or previous group
function select_first_track_in_next_group(direction)
  local song=renoise.song()
  local current_index = song.selected_track_index
  local group_indices = {}

  -- Collect all group indices
  for i = 1, song.sequencer_track_count do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_GROUP then
      local members = song.tracks[i].members
      local theCorrectIndex = i - #members
      table.insert(group_indices, theCorrectIndex)
    end
  end

  -- Check if there are no groups in the song
  if #group_indices == 0 then
    renoise.app():show_status("There are no Groups in this Song")
    return
  end

  -- Determine the next group index
  if direction == 1 then
    for _, index in ipairs(group_indices) do
      if current_index < index then
        song.selected_track_index = index
        return
      end
    end
    -- If no group found, wrap around to the first group
    song.selected_track_index = group_indices[1]
  elseif direction == 0 then
    for i = #group_indices, 1, -1 do
      if current_index > group_indices[i] then
        song.selected_track_index = group_indices[i]
        return
      end
    end
    -- If no group found, wrap around to the last group
    song.selected_track_index = group_indices[#group_indices]
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Jump to First Track In Next Group",invoke=function() select_first_track_in_next_group(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Jump to First Track In Previous Group",invoke=function() select_first_track_in_next_group(0) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Jump to First Track In Next Group",invoke=function() select_first_track_in_next_group(1) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Jump to First Track In Previous Group",invoke=function() select_first_track_in_next_group(0) end}
renoise.tool():add_midi_mapping{name="Paketti:Jump to First Track in Next Group",invoke=function() select_first_track_in_next_group(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Jump to First Track in Previous Group",invoke=function() select_first_track_in_next_group(0) end}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Jump to First Track In Next Group",invoke=function() select_first_track_in_next_group(1) end}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Jump to First Track In Previous Group",invoke=function() select_first_track_in_next_group(0) end}


function toggle_bypass_selected_device()
  local song=renoise.song()
  local selected_device = song.selected_device
  local selected_track = song.selected_track

  if selected_device == nil then
    renoise.app():show_status("No Track DSP Device is Selected, Doing Nothing.")
    return
  end

  local selected_device_index = song.selected_device_index
  local selected_device_name = selected_device.name
  local all_others_active = true
  local any_other_active = false

  for i = 2, #selected_track.devices do
    if i ~= selected_device_index then
      if selected_track.devices[i].is_active then
        any_other_active = true
      else
        all_others_active = false
      end
    end
  end

  if selected_device.is_active then
    if all_others_active then
      for i = 2, #selected_track.devices do
        if i ~= selected_device_index then
          selected_track.devices[i].is_active = false
        end
      end
      renoise.app():show_status("Device " .. selected_device_name .. " activated, all other track DSP devices deactivated.")
    else
      selected_device.is_active = false
      for i = 2, #selected_track.devices do
        if i ~= selected_device_index then
          selected_track.devices[i].is_active = true
        end
      end
      renoise.app():show_status("Device " .. selected_device_name .. " deactivated, all other track DSP devices activated.")
    end
  else
    selected_device.is_active = true
    for i = 2, #selected_track.devices do
      if i ~= selected_device_index then
        selected_track.devices[i].is_active = false
      end
    end
    renoise.app():show_status("Device " .. selected_device_name .. " activated, all other track DSP devices deactivated.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Bypass All Other Track DSP Devices (Toggle)",invoke=function() toggle_bypass_selected_device() end}
renoise.tool():add_midi_mapping{name="Paketti:Bypass All Other Track DSP Devices (Toggle)",invoke=function() toggle_bypass_selected_device() end}

------------
function globalToggleVisibleColumnState(columnName)
  -- Get the current state of the specified column from the selected track
  local currentState = false
  local selected_track = renoise.song().selected_track

  if columnName == "delay" then
    currentState = selected_track.delay_column_visible
  elseif columnName == "volume" then
    currentState = selected_track.volume_column_visible
  elseif columnName == "panning" then
    currentState = selected_track.panning_column_visible
  elseif columnName == "sample_effects" then
    currentState = selected_track.sample_effects_column_visible
  else
    renoise.app():show_status("Invalid column name: " .. columnName)
    return
  end

  -- Toggle the state for all tracks of type 1
  for i=1, renoise.song().sequencer_track_count do
    if renoise.song().tracks[i].type == 1 then
      if columnName == "delay" then
        renoise.song().tracks[i].delay_column_visible = not currentState
      elseif columnName == "volume" then
        renoise.song().tracks[i].volume_column_visible = not currentState
      elseif columnName == "panning" then
        renoise.song().tracks[i].panning_column_visible = not currentState
      elseif columnName == "sample_effects" then
        renoise.song().tracks[i].sample_effects_column_visible = not currentState
      end
    end
  end
end

function globalChangeVisibleColumnState(columnName,toggle)
  for i=1, renoise.song().sequencer_track_count do
    if renoise.song().tracks[i].type == 1 and columnName == "delay" then
      renoise.song().tracks[i].delay_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "volume" then
      renoise.song().tracks[i].volume_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "panning" then
      renoise.song().tracks[i].panning_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "sample_effects" then
      renoise.song().tracks[i].sample_effects_column_visible = toggle
    else
      renoise.app():show_status("Invalid column name: " .. columnName)
    end
  end
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Volume)",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Panning)",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Delay)",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Sample Effects)",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}






-----------
-- Create Identical Track Function
function create_identical_track()
  -- Get the current song
  local song=renoise.song()
  -- Get the selected track index
  local selected_track_index = song.selected_track_index
  -- Get the selected track
  local selected_track = song:track(selected_track_index)
  
  -- Check if the selected track type is 1 (Sequencer Track)
  if selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    -- Create a new track next to the selected track
    song:insert_track_at(selected_track_index + 1)
    -- Get the new track
    local new_track = song:track(selected_track_index + 1)
    
    -- Copy note and effect column visibility settings
    new_track.visible_note_columns = selected_track.visible_note_columns
    new_track.visible_effect_columns = selected_track.visible_effect_columns
    
    -- Copy volume, panning, delay, and sample effects column visibility settings
    new_track.volume_column_visible = selected_track.volume_column_visible
    new_track.panning_column_visible = selected_track.panning_column_visible
    new_track.delay_column_visible = selected_track.delay_column_visible
    new_track.sample_effects_column_visible = selected_track.sample_effects_column_visible
    
    -- Copy track collapsed state
    new_track.collapsed = selected_track.collapsed
    
    -- Copy DSP devices and their settings
    for device_index = 2, #selected_track.devices do  -- Start from 2 to skip the Track Volume device
      local old_device = selected_track.devices[device_index]
      local new_device = new_track:insert_device_at(old_device.device_path, device_index)
      
      -- Copy device parameters
      for param_index = 1, #old_device.parameters do
        new_device.parameters[param_index].value = old_device.parameters[param_index].value
      end
      
      -- Copy device display settings
      new_device.is_maximized = old_device.is_maximized
      
      -- If the device has preset data, copy it
      if old_device.active_preset_data then
        new_device.active_preset_data = old_device.active_preset_data
      end
    end
    
    -- Copy pattern data for all patterns
    for pattern_index = 1, #song.patterns do
      local pattern = song:pattern(pattern_index)
      local source_track = pattern:track(selected_track_index)
      local dest_track = pattern:track(selected_track_index + 1)
      
      -- Copy all lines in the pattern
      for line_index = 1, pattern.number_of_lines do
        dest_track:line(line_index):copy_from(source_track:line(line_index))
      end
      
      -- Copy automation data
      for _, automation in ipairs(source_track.automation) do
        local new_automation = dest_track:create_automation(automation.dest_parameter)
        for _, point in ipairs(automation.points) do
          new_automation:add_point_at(point.time, point.value)
        end
      end
    end
    
    -- Select the new track
    song.selected_track_index = selected_track_index + 1
  else
    -- If the selected track is not of type 1, show an error message
    renoise.app():show_error("Selected track is not a sequencer track (type 1).")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Create Identical Track",invoke=create_identical_track}
renoise.tool():add_keybinding{name="Mixer:Paketti:Create Identical Track",invoke=create_identical_track}
-------

-- Function to toggle solo state for note columns in the selected track
function noteColumnSoloToggle()
  local song=renoise.song()
  local selected_track = song.tracks[song.selected_track_index]

  -- Check if any note column is muted in the selected track
  local any_muted = false
  for i = 1, selected_track.max_note_columns do
    if selected_track:column_is_muted(i) then
      any_muted = true
      break
    end
  end

  -- Toggle mute state for all note columns in the selected track
  for i = 1, selected_track.max_note_columns do
    selected_track:set_column_is_muted(i, not any_muted)
  end

  -- Show status message for the selected track
  renoise.app():show_status(any_muted and "Unmuted all note columns in the selected track" or "Muted all note columns in the selected track")
end

-- Function to toggle mute state for note columns in all tracks within the same group, except the selected track
function groupTracksNoteColumnSoloToggle()
  local song=renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_track = song.tracks[selected_track_index]
  local selected_track_group = selected_track.group_parent

  -- Debug: Log selected track information
  print("Selected Track Index: ", selected_track_index)
  if selected_track_group then
    print("Selected Track Group Name: ", selected_track_group.name)
  else
    print("Selected Track Group: None")
  end

  -- Check if the selected track is part of a group
  if not selected_track_group then
    renoise.app():show_status("Selected track is not part of any group")
    return
  end

  -- Collect indices of all tracks in the group except the selected track
  local group_member_indices = {}
  for i, track in ipairs(song.tracks) do
    if track.group_parent and track.group_parent.name == selected_track_group.name and i ~= selected_track_index then
      table.insert(group_member_indices, i)
    end
  end

  -- Check if any note column is muted in any of the group tracks except the selected track
  local any_muted = false
  for _, member_index in ipairs(group_member_indices) do
    local track = song.tracks[member_index]
    for i = 1, track.max_note_columns do
      if track:column_is_muted(i) then
        any_muted = true
        break
      end
    end
    if any_muted then break end
  end

  -- Toggle mute state for all note columns in the group tracks
  for _, member_index in ipairs(group_member_indices) do
    local track = song.tracks[member_index]
    for i = 1, track.max_note_columns do
      track:set_column_is_muted(i, not any_muted)
    end
  end

  -- Show status message for the group tracks
  renoise.app():show_status(any_muted and "Unmuted all note columns in the group tracks" or "Muted all note columns in the group tracks")
end

renoise.tool():add_keybinding{name="Global:Paketti:Note Column Solo Toggle",invoke=function() noteColumnSoloToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Group Tracks Note Column Solo Toggle",invoke=function() groupTracksNoteColumnSoloToggle() end}
------------------------
-- Function to check if the selected sample is a slice
function is_slice_selected()
  local song=renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    return false
  end
  
  local sample = instrument.samples[1]
  if not sample or #sample.slice_markers == 0 then
    return false
  end
  
  return true
end

-- Function to log messages for debugging
function debug_log(message)
  renoise.app():show_status(message)
  print(message)
end

-- Function to move slice marker by a given amount
function move_slice_marker(slice_index, amount)
  local song=renoise.song()
  local selected_instrument = song.selected_instrument
  local selected_sample = selected_instrument.samples[1]

  if not selected_sample or #selected_sample.slice_markers == 0 then
    debug_log("No valid sample with slice markers selected.")
    return
  end

  if slice_index <= 0 or slice_index > #selected_sample.slice_markers then
    debug_log("Invalid slice index: " .. string.format("%X", slice_index))
    return
  end

  local old_marker_pos = selected_sample.slice_markers[slice_index]
  local new_marker_pos = old_marker_pos + amount

  if new_marker_pos < 1 then new_marker_pos = 1 end
  if new_marker_pos > selected_sample.sample_buffer.number_of_frames - 1 then
    new_marker_pos = selected_sample.sample_buffer.number_of_frames - 1
  end

  selected_sample:move_slice_marker(old_marker_pos, new_marker_pos)
  debug_log(string.format("Moved slice marker #%X from %d to %d", slice_index, old_marker_pos, new_marker_pos))
end

-- Helper function to create slice movement function
local function create_slice_move_function(is_start, amount)
  return function()
    local slice_index = is_start and (renoise.song().selected_sample_index - 1) or renoise.song().selected_sample_index
    move_slice_marker(slice_index, amount)
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Left by 10",invoke=create_slice_move_function(true, -10)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Right by 10",invoke=create_slice_move_function(true, 10)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Left by 10",invoke=create_slice_move_function(false, -10)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Right by 10",invoke=create_slice_move_function(false, 10)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Left by 100",invoke=create_slice_move_function(true, -100)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Right by 100",invoke=create_slice_move_function(true, 100)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Left by 100",invoke=create_slice_move_function(false, -100)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Right by 100",invoke=create_slice_move_function(false, 100)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Left by 300",invoke=create_slice_move_function(true, -300)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Right by 300",invoke=create_slice_move_function(true, 300)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Left by 300",invoke=create_slice_move_function(false, -300)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Right by 300",invoke=create_slice_move_function(false, 300)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Left by 500",invoke=create_slice_move_function(true, -500)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start Right by 500",invoke=create_slice_move_function(true, 500)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Left by 500",invoke=create_slice_move_function(false, -500)}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End Right by 500",invoke=create_slice_move_function(false, 500)}

renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Left by 10",invoke=create_slice_move_function(true, -10)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Right by 10",invoke=create_slice_move_function(true, 10)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Left by 10",invoke=create_slice_move_function(false, -10)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Right by 10",invoke=create_slice_move_function(false, 10)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Left by 100",invoke=create_slice_move_function(true, -100)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Right by 100",invoke=create_slice_move_function(true, 100)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Left by 100",invoke=create_slice_move_function(false, -100)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Right by 100",invoke=create_slice_move_function(false, 100)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Left by 300",invoke=create_slice_move_function(true, -300)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Right by 300",invoke=create_slice_move_function(true, 300)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Left by 300",invoke=create_slice_move_function(false, -300)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Right by 300",invoke=create_slice_move_function(false, 300)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Left by 500",invoke=create_slice_move_function(true, -500)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice Start Right by 500",invoke=create_slice_move_function(true, 500)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Left by 500",invoke=create_slice_move_function(false, -500)}
renoise.tool():add_keybinding{name="Sample Navigator:Paketti:Move Slice End Right by 500",invoke=create_slice_move_function(false, 500)}

renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Left by 10",invoke=create_slice_move_function(true, -10)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Right by 10",invoke=create_slice_move_function(true, 10)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Left by 10",invoke=create_slice_move_function(false, -10)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Right by 10",invoke=create_slice_move_function(false, 10)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Left by 100",invoke=create_slice_move_function(true, -100)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Right by 100",invoke=create_slice_move_function(true, 100)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Left by 100",invoke=create_slice_move_function(false, -100)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Right by 100",invoke=create_slice_move_function(false, 100)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Left by 300",invoke=create_slice_move_function(true, -300)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Right by 300",invoke=create_slice_move_function(true, 300)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Left by 300",invoke=create_slice_move_function(false, -300)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Right by 300",invoke=create_slice_move_function(false, 300)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Left by 500",invoke=create_slice_move_function(true, -500)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice Start Right by 500",invoke=create_slice_move_function(true, 500)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Left by 500",invoke=create_slice_move_function(false, -500)}
renoise.tool():add_keybinding{name="Global:Paketti:Move Slice End Right by 500",invoke=create_slice_move_function(false, 500)}
----------
-- Main function to isolate slices or samples into new instruments
function PakettiIsolateSlices()
  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  local selected_sample_index = song.selected_sample_index

  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No valid instrument with samples selected.")
    return
  end

  -- Helper function to create a new instrument with given sample data
  local function create_new_instrument(sample, start_frame, end_frame, name_suffix, index)
    song:insert_instrument_at(index)
    song.selected_instrument_index = index
    pakettiPreferencesDefaultInstrumentLoader()
    local new_instrument = song.instruments[index]
    new_instrument.name = instrument.name .. " (" .. sample.name .. ")" .. name_suffix

    new_instrument:insert_sample_at(1)
    local new_sample = new_instrument.samples[1]
    new_sample.name = sample.name .. name_suffix

    local slice_length = end_frame - start_frame + 1
    new_sample.sample_buffer:create_sample_data(
      sample.sample_buffer.sample_rate,
      sample.sample_buffer.bit_depth,
      sample.sample_buffer.number_of_channels,
      slice_length
    )
    new_sample.sample_buffer:prepare_sample_data_changes()

    for ch = 1, sample.sample_buffer.number_of_channels do
      for frame = 1, slice_length do
        new_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, start_frame + frame - 1))
      end
    end

    new_sample.sample_buffer:finalize_sample_data_changes()
  end

  local sample = instrument.samples[1]
  local insert_index = selected_instrument_index + 1

  if #sample.slice_markers > 0 then
    for i, slice_start in ipairs(sample.slice_markers) do
      local slice_end = (i == #sample.slice_markers) and sample.sample_buffer.number_of_frames or sample.slice_markers[i + 1] - 1
      local slice_length = slice_end - slice_start + 1

      if slice_length > 0 then
        create_new_instrument(sample, slice_start, slice_end, " (S#" .. string.format("%02X", i) .. ")", insert_index)
        insert_index = insert_index + 1
      else
        renoise.app():show_status("Invalid slice length calculated.")
        return
      end
    end
    song.selected_instrument_index = selected_instrument_index + selected_sample_index - 1
  else
    for i = 1, #instrument.samples do
      local sample = instrument.samples[i]
      create_new_instrument(sample, 1, sample.sample_buffer.number_of_frames, " (Sample " .. string.format("%02X", i) .. ")", insert_index)
      insert_index = insert_index + 1
    end
    song.selected_instrument_index = selected_instrument_index + selected_sample_index
  end

  song.transport.octave = 3
  renoise.app():show_status(#sample.slice_markers > 0 and #sample.slice_markers .. " Slices isolated to new Instruments" or #instrument.samples .. " Samples isolated to new Instruments")
end

renoise.tool():add_keybinding{name="Global:Paketti:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}
renoise.tool():add_midi_mapping{name="Paketti:Isolate Slices or Samples to New Instruments",invoke=PakettiIsolateSlices}

-- Main function to isolate slices into a new instrument or samples into new instruments
function PakettiIsolateSlicesToInstrument()
  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  local selected_sample_index = song.selected_sample_index

  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No valid instrument with samples selected.")
    return
  end

  -- Helper function to create a new instrument
  local function create_new_instrumentWithSlices(name_suffix, index)
    song:insert_instrument_at(index)
    song.selected_instrument_index = index
    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
    
  
  --  renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
  renoise.app():load_instrument(defaultInstrument)
    local new_instrument = song.instruments[index]
    new_instrument.name = instrument.name .. name_suffix
    return new_instrument
  end

  -- Helper function to create a new sample with given sample data
  local function create_new_sample(new_instrument, sample, start_frame, end_frame, sample_name)
    local new_sample = new_instrument:insert_sample_at(#new_instrument.samples + 1)
    new_sample.name = sample_name

    local slice_length = end_frame - start_frame + 1
    new_sample.sample_buffer:create_sample_data(
      sample.sample_buffer.sample_rate,
      sample.sample_buffer.bit_depth,
      sample.sample_buffer.number_of_channels,
      slice_length
    )
    new_sample.sample_buffer:prepare_sample_data_changes()

    for ch = 1, sample.sample_buffer.number_of_channels do
      for frame = 1, slice_length do
        new_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, start_frame + frame - 1))
      end
    end

    new_sample.sample_buffer:finalize_sample_data_changes()

    -- Copy additional sample properties
    new_sample.autofade = sample.autofade
    new_sample.autoseek = sample.autoseek
    new_sample.loop_mode = sample.loop_mode
 --   new_sample.loop_start = sample.loop_start -- i had to comment these away because they don't work
 --   new_sample.loop_end = sample.loop_end
    new_sample.beat_sync_mode = sample.beat_sync_mode
    new_sample.beat_sync_lines = sample.beat_sync_lines
    new_sample.fine_tune = sample.fine_tune
    new_sample.volume = sample.volume
    new_sample.panning = sample.panning
    new_sample.new_note_action = sample.new_note_action
    new_sample.mute_group = sample.mute_group
    new_sample.new_note_action = sample.new_note_action
    new_sample.oversample_enabled = sample.oversample_enabled
    new_sample.interpolation_mode = sample.interpolation_mode
  end

  local sample = instrument.samples[1]
  local insert_index = selected_instrument_index + 1

  if #sample.slice_markers > 0 then
    -- Create one new instrument for all slices
    local new_instrument = create_new_instrumentWithSlices(" (Isolated Slices)", insert_index)
    for i, slice_start in ipairs(sample.slice_markers) do
      local slice_end = (i == #sample.slice_markers) and sample.sample_buffer.number_of_frames or sample.slice_markers[i + 1] - 1
      local slice_length = slice_end - slice_start + 1

      if slice_length > 0 then
        local sample_name = "Slice " .. string.format("%02X", i)
        create_new_sample(new_instrument, sample, slice_start, slice_end, sample_name)
      else
        renoise.app():show_status("Invalid slice length calculated.")
        return
      end
    end
    song.selected_instrument_index = insert_index
  else
    -- No slices, handle samples as before
    for i = 1, #instrument.samples do
      local sample = instrument.samples[i]
      -- Create a new instrument for each sample
      local new_instrument = create_new_instrumentWithSlices(" (Sample " .. string.format("%02X", i) .. ")", insert_index)
      create_new_sample(new_instrument, sample, 1, sample.sample_buffer.number_of_frames, sample.name)
      insert_index = insert_index + 1
    end
    song.selected_instrument_index = selected_instrument_index + selected_sample_index
  end

  song.transport.octave = 3
  renoise.app():show_status(
    #sample.slice_markers > 0 and
    #sample.slice_markers .. " Slices isolated into a new Instrument" or
    #instrument.samples .. " Samples isolated into new Instruments"
  )
  renoise.song().selected_instrument:delete_sample_at(1)
end

renoise.tool():add_keybinding{name="Global:Paketti:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}
renoise.tool():add_midi_mapping{name="Paketti:Isolate Slices to New Instrument as Samples",invoke=PakettiIsolateSlicesToInstrument}
-------------
-- Function to isolate selected sample to new instrument
function PakettiIsolateSelectedSampleToInstrument()
  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  local selected_sample_index = song.selected_sample_index

  -- Validate instrument and sample selection
  if not instrument or #instrument.samples == 0 or not selected_sample_index then
    renoise.app():show_status("No valid instrument or sample selected.")
    return
  end

  local sample = instrument.samples[selected_sample_index]
  if not sample then
    renoise.app():show_status("Invalid sample selection.")
    return
  end

  -- Create new instrument
  local insert_index = selected_instrument_index + 1
  song:insert_instrument_at(insert_index)
  song.selected_instrument_index = insert_index
  local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
  local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
  

--  renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
renoise.app():load_instrument(defaultInstrument)
  local new_instrument = song.instruments[insert_index]
  new_instrument.name = sample.name .. " (Isolated)"

  -- Create new sample in the new instrument
  local new_sample = new_instrument:insert_sample_at(1)
  new_sample.name = sample.name

  -- Copy sample data
  new_sample.sample_buffer:create_sample_data(
    sample.sample_buffer.sample_rate,
    sample.sample_buffer.bit_depth,
    sample.sample_buffer.number_of_channels,
    sample.sample_buffer.number_of_frames
  )
  new_sample.sample_buffer:prepare_sample_data_changes()

  for ch = 1, sample.sample_buffer.number_of_channels do
    for frame = 1, sample.sample_buffer.number_of_frames do
      new_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
    end
  end

  new_sample.sample_buffer:finalize_sample_data_changes()

  -- Copy sample properties
  new_sample.autofade = sample.autofade
  new_sample.autoseek = sample.autoseek
  new_sample.loop_mode = sample.loop_mode
  new_sample.beat_sync_mode = sample.beat_sync_mode
  new_sample.beat_sync_lines = sample.beat_sync_lines
  new_sample.fine_tune = sample.fine_tune
  new_sample.volume = sample.volume
  new_sample.panning = sample.panning
  new_sample.new_note_action = sample.new_note_action
  new_sample.mute_group = sample.mute_group
  new_sample.oversample_enabled = sample.oversample_enabled
  new_sample.interpolation_mode = sample.interpolation_mode

  -- Set up key mapping for the full range (C-0 to B-9)
  local mapping = new_sample.sample_mapping
  mapping.base_note = sample.sample_mapping.base_note  -- C-0
  mapping.note_range = { 0, 119 }  -- C-0 to B-9
  mapping.velocity_range = { 0, 127 }
  mapping.map_velocity_to_volume = true

  -- Set octave and show status
  song.transport.octave = 3
  renoise.app():show_status("Sample '" .. sample.name .. "' isolated to new instrument")
end



renoise.tool():add_keybinding{name="Global:Paketti:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}
renoise.tool():add_midi_mapping{name="Paketti:Isolate Selected Sample to New Instrument",invoke=PakettiIsolateSelectedSampleToInstrument}
---------
function PakettiReverseNotesInSelection()
  local song=renoise.song()
  local selection = selection_in_pattern_pro()

  if not selection then
    renoise.app():show_status("No selection in the pattern.")
    return
  end

  -- Get the global start and end lines from song.selection_in_pattern
  local pattern_selection = song.selection_in_pattern
  local start_line = pattern_selection.start_line
  local end_line = pattern_selection.end_line
  local selection_length = end_line - start_line + 1

  -- Create a structure to store all notes and effects
  local all_data = {}
  
  -- First, collect all data from the selection
  for _, track_info in ipairs(selection) do
    local track_index = track_info.track_index
    local pattern_track = song.selected_pattern.tracks[track_index]
    
    -- Initialize track data if not exists
    if not all_data[track_index] then
      all_data[track_index] = {
        note_columns = {},
        effect_columns = {}
      }
    end

    -- Collect note columns data
    for _, col in ipairs(track_info.note_columns) do
      all_data[track_index].note_columns[col] = {}
      for line = start_line, end_line do
        local note_col = pattern_track:line(line).note_columns[col]
        all_data[track_index].note_columns[col][line - start_line + 1] = {
          note_value = note_col.note_value,
          instrument_value = note_col.instrument_value,
          volume_value = note_col.volume_value,
          panning_value = note_col.panning_value,
          delay_value = note_col.delay_value
        }
      end
    end

    -- Collect effect columns data
    for _, col in ipairs(track_info.effect_columns) do
      all_data[track_index].effect_columns[col] = {}
      for line = start_line, end_line do
        local fx_col = pattern_track:line(line).effect_columns[col]
        all_data[track_index].effect_columns[col][line - start_line + 1] = {
          number_value = fx_col.number_value,
          amount_value = fx_col.amount_value
        }
      end
    end
  end

  -- Now reverse and write back the data for each track and column
  for track_index, track_data in pairs(all_data) do
    local pattern_track = song.selected_pattern.tracks[track_index]

    -- Reverse and write note columns
    for col, column_data in pairs(track_data.note_columns) do
      for i = 1, selection_length do
        local source_idx = selection_length - i + 1
        local target_line = start_line + i - 1
        local note_col = pattern_track:line(target_line).note_columns[col]
        local reversed_data = column_data[source_idx]

        note_col.note_value = reversed_data.note_value
        note_col.instrument_value = reversed_data.instrument_value
        note_col.volume_value = reversed_data.volume_value
        note_col.panning_value = reversed_data.panning_value
        note_col.delay_value = reversed_data.delay_value
      end
    end

    -- Reverse and write effect columns
    for col, column_data in pairs(track_data.effect_columns) do
      for i = 1, selection_length do
        local source_idx = selection_length - i + 1
        local target_line = start_line + i - 1
        local fx_col = pattern_track:line(target_line).effect_columns[col]
        local reversed_data = column_data[source_idx]

        fx_col.number_value = reversed_data.number_value
        fx_col.amount_value = reversed_data.amount_value
      end
    end
  end

  renoise.app():show_status("Notes and effects reversed across all selected tracks and columns.")
end



renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Reverse Notes in Selection",invoke=function() PakettiReverseNotesInSelection() end}

-- Randomize or swap notes in a pattern selection (using selection_in_pattern_pro)
function randomize_notes_in_selection()
  local song=renoise.song()
  local selection = selection_in_pattern_pro()

  -- Check if a valid selection is returned
  if not selection then 
    renoise.app():show_status("No selection in pattern")
    return 
  end

  local notes = {}
  local note_positions = {}

  -- Step 1: Collect all notes in the selection
  for _, track_info in ipairs(selection) do
    local track_index = track_info.track_index
    local note_columns = track_info.note_columns

    for _, col in ipairs(note_columns) do
      for line_idx = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
        local note_column = song:pattern(song.selected_pattern_index):track(track_index):line(line_idx):note_column(col)
        
        -- Check if there's a note in this column
        if note_column and note_column.note_string ~= "---" then
          table.insert(notes, {
            note = note_column.note_string,
            instr = note_column.instrument_value,
            vol = note_column.volume_value,
            pann = note_column.panning_value,
            delay = note_column.delay_value
          })
          table.insert(note_positions, {
            line = line_idx,
            track = track_index,
            column = col
          })

          -- Clear the note in preparation for rearranging
          note_column:clear()
        end
      end
    end
  end

  -- Step 2: Handle the notes based on their count
  local note_count = #notes

  if note_count < 2 then
    renoise.app():show_status("Not enough notes to randomize")
    return
  elseif note_count == 2 then
    -- Swap the two notes
    local temp = note_positions[1]
    note_positions[1] = note_positions[2]
    note_positions[2] = temp
  else
    -- Randomize note positions
    local random_pos = {}

    while #note_positions > 0 do
      local idx = math.random(#note_positions)
      table.insert(random_pos, note_positions[idx])
      table.remove(note_positions, idx)
    end

    note_positions = random_pos
  end

  -- Step 3: Reapply the notes in their new positions
  for i, note_data in ipairs(notes) do
    local pos = note_positions[i]
    local note_column = song:pattern(song.selected_pattern_index):track(pos.track):line(pos.line):note_column(pos.column)
    note_column.note_string = note_data.note
    note_column.instrument_value = note_data.instr
    note_column.volume_value = note_data.vol
    note_column.panning_value = note_data.pann
    note_column.delay_value = note_data.delay
  end

  renoise.app():show_status("Notes randomized successfully")
end



renoise.tool():add_keybinding{name="Global:Paketti:Roll the Dice on Notes",invoke=function()
randomize_notes_in_selection() end}



-------
--[[
local MIN_SHIFT = -12
local MAX_SHIFT = 12

-- Main function to adjust base notes
local function PakettiBaseNoteShifter(interval, scope)
  local song=renoise.song()
  
  -- Validate interval
  if interval == 0 then
    renoise.app():show_status("No shift applied (interval is 0)")
    return
  end
  
  -- Helper function to adjust the base note
  local function adjust_base_note(sample, interval, instrument_index, sample_index)
    if sample.sample_mapping ~= nil then
      local base_note = sample.sample_mapping.base_note
      local new_base_note = base_note + interval
      
      -- Ensure the new base note is within MIDI range (0 to 108)
      if new_base_note > 108 then
        renoise.app():show_status("Basenote cannot exceed C-9. Skipping (Instrument " .. instrument_index .. ", Sample " .. sample_index .. ")")
        return
      elseif new_base_note < 0 then
        renoise.app():show_status("Basenote cannot be below C-0. Skipping (Instrument " .. instrument_index .. ", Sample " .. sample_index .. ")")
        return
      end
      
      sample.sample_mapping.base_note = new_base_note
    end
  end

  -- Function to process a single instrument
  local function process_instrument(instrument, instrument_index, interval)
    if #instrument.samples == 0 then
      renoise.app():show_status("Instrument " .. instrument_index .. " has no samples.")
      return
    end

    local first_sample = instrument.samples[1]
    local has_slice_markers = first_sample.slice_markers and #first_sample.slice_markers > 0

    if has_slice_markers then
      -- Only adjust the first sample
      adjust_base_note(first_sample, interval, instrument_index, 1)
    else
      -- Adjust all samples
      for j, sample in ipairs(instrument.samples) do
        adjust_base_note(sample, interval, instrument_index, j)
      end
    end
  end

  -- Determine the shift direction for status messages
  local direction = (interval > 0) and ("+" .. interval) or tostring(interval)

  -- Process all instruments or only the selected instrument
  if scope == "all" then
    for i, instrument in ipairs(song.instruments) do
      process_instrument(instrument, i, interval)
    end
    renoise.app():show_status("Basenote shifted by " .. direction .. " semitones for all instruments.")
  elseif scope == "current" then
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
      renoise.app():show_status("No selected instrument or no samples in the current instrument.")
      return
    end
    local instrument_index = song.selected_instrument_index
    process_instrument(instrument, instrument_index, interval)
    renoise.app():show_status("Basenote shifted by " .. direction .. " semitones for the current instrument.")
  else
    renoise.app():show_status("Invalid scope parameter: use 'all' or 'current'.")
  end
end

-- Generate controls for each semitone shift from -12 to +12, excluding 0
for interval = MIN_SHIFT, MAX_SHIFT do
  if interval ~= 0 then
    local shift_label = (interval > 0) and ("+" .. interval) or tostring(interval)

    -- Define menu labels under "Main Menu:Tools:Paketti..:Pattern Editor..:"
    local menu_label_all_main = "Main Menu:Tools:Paketti..:Pattern Editor..:Basenote..:Basenote Shift " .. shift_label .. " (All Instruments)"
    local menu_label_current_main = "Main Menu:Tools:Paketti..:Pattern Editor..:Basenote..:Basenote Shift " .. shift_label .. " (Selected Instrument)"
    local key_label_all_main = "Sample Mappings:Paketti..:Basenote..:Basenote Shift " .. shift_label .. " (All Instruments)"
    local key_label_current_main = "Sample Mappings:Paketti..:Basenote..:Basenote Shift " .. shift_label .. " (Selected Instrument)"
    
    -- Define menu labels under "Pattern Editor:Paketti..:"
    local menu_label_all_pattern = "Sample Editor:Paketti..:Basenote..:Basenote Shift " .. shift_label .. " (All Instruments)"
    local menu_label_current_pattern = "Sample Editor:Paketti..:Basenote..:Basenote Shift " .. shift_label .. " (Selected Instrument)"
    
    -- Define unique identifiers for keybindings
    local keybinding_label_all = "Global:Paketti:Basenote Shift " .. shift_label .. " (All Instruments)"
    local keybinding_label_current = "Global:Paketti:Basenote Shift " .. shift_label .. " (Selected Instrument)"
    
    -- Define MIDI mapping labels
    local midi_mapping_all = "Paketti:Basenote Shift " .. shift_label .. " (All Instruments)"
    local midi_mapping_current = "Paketti:Basenote Shift " .. shift_label .. " (Selected Instrument)"

    -- Add menu entries under "Main Menu:Tools:Paketti..:Pattern Editor..:"
    renoise.tool():add_menu_entry{name=menu_label_all_main,invoke=function() PakettiBaseNoteShifter(interval, "all") end}    
    renoise.tool():add_menu_entry{name=key_label_current_main,invoke=function() PakettiBaseNoteShifter(interval, "current") end}
    renoise.tool():add_menu_entry{name=key_label_all_main,invoke=function() PakettiBaseNoteShifter(interval, "all") end}
    renoise.tool():add_menu_entry{name=menu_label_current_main,invoke=function() PakettiBaseNoteShifter(interval, "current") end}
    renoise.tool():add_menu_entry{name=menu_label_all_pattern,invoke=function() PakettiBaseNoteShifter(interval, "all") end}
    renoise.tool():add_menu_entry{name=menu_label_current_pattern,invoke=function() PakettiBaseNoteShifter(interval, "current") end}
    renoise.tool():add_keybinding{name=keybinding_label_all,invoke=function() PakettiBaseNoteShifter(interval, "all") end}
    
    renoise.tool():add_keybinding{name=keybinding_label_current,invoke=function() PakettiBaseNoteShifter(interval, "current") end}
    renoise.tool():add_midi_mapping{name=midi_mapping_all,invoke=function() PakettiBaseNoteShifter(interval, "all") end}
    renoise.tool():add_midi_mapping{name=midi_mapping_current,invoke=function() PakettiBaseNoteShifter(interval, "current") end}
  end
end
]]--

local MIN_SHIFT = -12
local MAX_SHIFT = 12

-- Main function to adjust instrument transpose
function PakettiTransposeShifter(interval, scope)
  local song=renoise.song()
  
  -- Validate interval
  if interval == 0 then
    renoise.app():show_status("No shift applied (interval is 0)")
    return
  end
  
  -- Function to process a single instrument
  local function process_instrument(instrument, instrument_index, interval)
    local new_transpose = instrument.transpose + interval
    
    -- Ensure the new transpose is within valid range (-120 to +120)
    if new_transpose > 120 then
      renoise.app():show_status("Transpose cannot exceed +120. Skipping Instrument " .. instrument_index)
      return
    elseif new_transpose < -120 then
      renoise.app():show_status("Transpose cannot be below -120. Skipping Instrument " .. instrument_index)
      return
    end
    
    instrument.transpose = new_transpose
  end
  
  -- Determine the shift direction for status messages
  local direction = (interval > 0) and ("+" .. interval) or tostring(interval)
  
  -- Process all instruments or only the selected instrument
  if scope == "all" then
    for i, instrument in ipairs(song.instruments) do
      process_instrument(instrument, i, interval)
    end
    renoise.app():show_status("Transpose shifted by " .. direction .. " semitones for all instruments.")
  elseif scope == "current" then
    local instrument = song.selected_instrument
    if not instrument then
      renoise.app():show_status("No selected instrument.")
      return
    end
    local instrument_index = song.selected_instrument_index
    process_instrument(instrument, instrument_index, interval)
    renoise.app():show_status("Transpose shifted by " .. direction .. " semitones for the current instrument.")
  else
    renoise.app():show_status("Invalid scope parameter: use 'all' or 'current'.")
  end
end

-- First create all "All Instruments" entries
for interval = MIN_SHIFT, MAX_SHIFT do
  if interval ~= 0 then
    local shift_label = (interval > 0) and ("+" .. interval) or tostring(interval)
    
    -- Define labels for "All Instruments"
    local menu_label_all_main = "Main Menu:Tools:Paketti..:Instruments..:Transpose..:Transpose Shift " .. shift_label .. " (All Instruments)"
    local menu_label_all_pattern = "Sample Editor:Paketti..:Transpose..:Transpose Shift " .. shift_label .. " (All Instruments)"
    local keybinding_label_all = "Global:Paketti:Transpose Shift " .. shift_label .. " (All Instruments)"
    local midi_mapping_all = "Paketti:Transpose Shift " .. shift_label .. " (All Instruments)"

    renoise.tool():add_menu_entry{name=menu_label_all_main,invoke=function() PakettiTransposeShifter(interval, "all") end}
    renoise.tool():add_menu_entry{name=menu_label_all_pattern,invoke=function() PakettiTransposeShifter(interval, "all") end}
    renoise.tool():add_keybinding{name=keybinding_label_all,invoke=function() PakettiTransposeShifter(interval, "all") end}
    renoise.tool():add_midi_mapping{name=midi_mapping_all,invoke=function() PakettiTransposeShifter(interval, "all") end}
  end
end

-- Then create all "Selected Instrument" entries
for interval = MIN_SHIFT, MAX_SHIFT do
  if interval ~= 0 then
    local shift_label = (interval > 0) and ("+" .. interval) or tostring(interval)
    
    local menu_label_current_main = "Main Menu:Tools:Paketti..:Instruments..:Transpose..:Transpose Shift " .. shift_label .. " (Selected Instrument)"
    local menu_label_current_pattern = "Sample Editor:Paketti..:Transpose..:Transpose Shift " .. shift_label .. " (Selected Instrument)"
    local keybinding_label_current = "Global:Paketti:Transpose Shift " .. shift_label .. " (Selected Instrument)"
    local midi_mapping_current = "Paketti:Transpose Shift " .. shift_label .. " (Selected Instrument)"

    renoise.tool():add_menu_entry{name=menu_label_current_main,invoke=function() PakettiTransposeShifter(interval, "current") end}
    renoise.tool():add_menu_entry{name=menu_label_current_pattern,invoke=function() PakettiTransposeShifter(interval, "current") end}
    renoise.tool():add_keybinding{name=keybinding_label_current,invoke=function() PakettiTransposeShifter(interval, "current") end}
    renoise.tool():add_midi_mapping{name=midi_mapping_current,invoke=function() PakettiTransposeShifter(interval, "current") end}
  end
end

---------

-- Utility function to read file contents
local function PakettiSendPopulatorReadFile(file_path)
  local file = io.open(file_path, "r")
  if not file then
    error("Could not open file at: " .. file_path)
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Function to create and configure send devices for all tracks in the song
function PakettiPopulateSendTracksAllTracks()
  local song=renoise.song()
  local send_tracks = {}
  local count = 0

  -- Collect all send tracks
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
      table.insert(send_tracks, {index = count, name = song.tracks[i].name, track_number = i - 1})
      count = count + 1
    end
  end

  -- Path to the XML preset file
  local PakettiSend_xml_file_path = "Presets" .. separator .. "PakettiSend.XML"
  local PakettiSend_xml_data = PakettiSendPopulatorReadFile(PakettiSend_xml_file_path)

  -- Create the appropriate number of #Send devices in each track
  for _, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER or track.type == renoise.Track.TRACK_TYPE_GROUP then
      -- Collect existing send devices' target indices (parameter 3)
      local existing_sends = {}
      for _, device in ipairs(track.devices) do
        if device.name == "#Send" then
          table.insert(existing_sends, device.parameters[3].value)
        end
      end

      local sendcount = #track.devices + 1 -- Start after existing devices

      -- Add send devices only if they don't already target the same send track
      for i = 1, count do
        local send_track = send_tracks[i]
        local send_index = send_track.index
        if not table.contains(existing_sends, send_index) then
          track:insert_device_at("Audio/Effects/Native/#Send", sendcount)
          local send_device = track.devices[sendcount]
          send_device.active_preset_data = PakettiSend_xml_data
          send_device.parameters[3].value = send_index
          send_device.display_name = send_track.name
          sendcount = sendcount + 1
        else
          -- Update the display name if the send already exists but was renamed
          for _, device in ipairs(track.devices) do
            if device.name == "#Send" and device.parameters[3].value == send_index then
              device.display_name = send_track.name
            end
          end
        end
      end
    end
  end
end

-- Function to create and configure send devices for the selected track
function PakettiPopulateSendTracksSelectedTrack()
  local song=renoise.song()
  local current_track = song.selected_track

  if current_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER and current_track.type ~= renoise.Track.TRACK_TYPE_GROUP then
    renoise.app():show_status("Selected track does not support adding send devices.")
    return
  end

  local send_tracks = {}
  local count = 0

  -- Collect all send tracks
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
      table.insert(send_tracks, {index = count, name = song.tracks[i].name, track_number = i - 1})
      count = count + 1
    end
  end

  -- Path to the XML preset file
  local PakettiSend_xml_file_path = "Presets" .. separator .. "PakettiSend.XML"
  local PakettiSend_xml_data = PakettiSendPopulatorReadFile(PakettiSend_xml_file_path)

  -- Collect existing send devices' target indices (parameter 3)
  local existing_sends = {}
  for _, device in ipairs(current_track.devices) do
    if device.name == "#Send" then
      table.insert(existing_sends, device.parameters[3].value)
    end
  end

  local sendcount = #current_track.devices + 1 -- Start after existing devices

  -- Add send devices only if they don't already target the same send track
  for i = 1, count do
    local send_track = send_tracks[i]
    local send_index = send_track.index
    if not table.contains(existing_sends, send_index) then
      current_track:insert_device_at("Audio/Effects/Native/#Send", sendcount)
      local send_device = current_track.devices[sendcount]
      send_device.active_preset_data = PakettiSend_xml_data
      send_device.parameters[3].value = send_index
      send_device.display_name = send_track.name
      sendcount = sendcount + 1
    else
      -- Update the display name if the send already exists but was renamed
      for _, device in ipairs(current_track.devices) do
        if device.name == "#Send" and device.parameters[3].value == send_index then
          device.display_name = send_track.name
        end
      end
    end
  end
end

-- Helper function to check if a table contains a value
function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

renoise.tool():add_keybinding{name="Global:Paketti:Populate Send Tracks for All Tracks",invoke=PakettiPopulateSendTracksAllTracks}
renoise.tool():add_keybinding{name="Global:Paketti:Populate Send Tracks for Selected Track",invoke=PakettiPopulateSendTracksSelectedTrack}
-- Function to populate send tracks for all tracks in the selected range
function PakettiPopulateSendTracksToSelectionInPattern()
  local song=renoise.song()
  local selection_range = song.selection_in_pattern
  
  -- Check if selection exists
  if not selection_range then
    renoise.app():show_status("There is no Selection in Pattern, doing nothing.")
    return
  end
  
  local send_tracks = {}
  local count = 0

  -- Collect all send tracks
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEND then
      table.insert(send_tracks, {index = count, name = song.tracks[i].name, track_number = i - 1})
      count = count + 1
    end
  end

  -- Path to the XML preset file
  local PakettiSend_xml_file_path = "Presets" .. separator .. "PakettiSend.XML"
  local PakettiSend_xml_data = PakettiSendPopulatorReadFile(PakettiSend_xml_file_path)

  -- Loop through each track in the selected range
  for track_index = selection_range.start_track, selection_range.end_track do
    local track = song.tracks[track_index]
    
    -- Only process sequencer and group tracks
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER or track.type == renoise.Track.TRACK_TYPE_GROUP then
      local existing_sends = {}

      -- Collect existing send devices' target indices
      for _, device in ipairs(track.devices) do
        if device.name == "#Send" then
          table.insert(existing_sends, device.parameters[3].value)
        end
      end

      local sendcount = #track.devices + 1 -- Start after existing devices

      -- Add send devices only if they don't already target the same send track
      for i = 1, count do
        local send_track = send_tracks[i]
        local send_index = send_track.index
        if not table.contains(existing_sends, send_index) then
          track:insert_device_at("Audio/Effects/Native/#Send", sendcount)
          local send_device = track.devices[sendcount]
          send_device.active_preset_data = PakettiSend_xml_data
          send_device.parameters[3].value = send_index
          send_device.display_name = send_track.name
          sendcount = sendcount + 1
        else
          -- Update the display name if the send already exists but was renamed
          for _, device in ipairs(track.devices) do
            if device.name == "#Send" and device.parameters[3].value == send_index then
              device.display_name = send_track.name
            end
          end
        end
      end
    else
      renoise.app():show_status("Skipping unsupported track type for track index: " .. track_index)
    end
  end
  renoise.app():show_status("Send tracks populated for all selected tracks.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Populate Send Tracks for All Selected Tracks",invoke=PakettiPopulateSendTracksToSelectionInPattern}
--------
-- Function to fully update the Convolver preset XML
function full_update_convolver_preset_data(left_sample_data, right_sample_data, sample_rate, sample_name, stereo, sample_directory_path)
  print("Full updating Convolver preset data")
  local xml_template = [==[
<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="ConvolverDevice">
    <IsMaximized>true</IsMaximized>
    <Gain>
      <Value>0.501187205</Value>
    </Gain>
    <Start>
      <Value>0.0</Value>
    </Start>
    <Length>
      <Value>1.0</Value>
    </Length>
    <Resample>
      <Value>0.5</Value>
    </Resample>
    <PreDelay>
      <Value>0.0</Value>
    </PreDelay>
    <Color>
      <Value>0.5</Value>
    </Color>
    <Dry>
      <Value>1.0</Value>
    </Dry>
    <Wet>
      <Value>0.25</Value>
    </Wet>
    <Stereo>%s</Stereo>
    <ImpulseDataLeft><![CDATA[%s]]></ImpulseDataLeft>
    <ImpulseDataRight><![CDATA[%s]]></ImpulseDataRight>
    <ImpulseDataSampleRate>%d</ImpulseDataSampleRate>
    <SampleName>%s</SampleName>
    <SampleDirectoryPath>%s</SampleDirectoryPath>
  </DeviceSlot>
</FilterDevicePreset>
]==]
  return string.format(xml_template, stereo and "true" or "false", left_sample_data, right_sample_data, sample_rate, sample_name, sample_directory_path)
end

-- Function to update specific fields in the Convolver preset XML
function soft_update_convolver_preset_data(current_xml, left_sample_data, right_sample_data, sample_rate, sample_name, stereo, sample_directory_path)
  print("Soft updating Convolver preset data")
  print("Current XML:", current_xml)
  if stereo then
    print(string.format("New data - Left: %d, Right: %d, Sample Rate: %d, Name: %s, Stereo: true, Path: %s",
      #left_sample_data, #right_sample_data, sample_rate, sample_name, sample_directory_path))
  else
    print(string.format("New data - Left: %d, Sample Rate: %d, Name: %s, Stereo: false, Path: %s",
      #left_sample_data, sample_rate, sample_name, sample_directory_path))
  end

  local updated_xml = current_xml
  updated_xml = updated_xml:gsub("<ImpulseDataLeft><!%[CDATA%[(.-)%]%]></ImpulseDataLeft>", 
    string.format("<ImpulseDataLeft><![CDATA[%s]]></ImpulseDataLeft>", left_sample_data))
  updated_xml = updated_xml:gsub("<ImpulseDataRight><!%[CDATA%[(.-)%]%]></ImpulseDataRight>", 
    string.format("<ImpulseDataRight><![CDATA[%s]]></ImpulseDataRight>", right_sample_data))
  updated_xml = updated_xml:gsub("<ImpulseDataSampleRate>(%d+)</ImpulseDataSampleRate>", 
    string.format("<ImpulseDataSampleRate>%d</ImpulseDataSampleRate>", sample_rate))
  updated_xml = updated_xml:gsub("<SampleName>(.-)</SampleName>", 
    string.format("<SampleName>%s</SampleName>", sample_name))
  updated_xml = updated_xml:gsub("<Stereo>(.-)</Stereo>", 
    string.format("<Stereo>%s</Stereo>", stereo and "true" or "false"))
  updated_xml = updated_xml:gsub("<SampleDirectoryPath>(.-)</SampleDirectoryPath>", 
    string.format("<SampleDirectoryPath>%s</SampleDirectoryPath>", sample_directory_path))

  print("Updated XML:", updated_xml)
  return updated_xml
end

function get_channel_data_as_b64(sample_buffer, channel)
  local data = {}
  for frame = 1, sample_buffer.number_of_frames do
    data[#data + 1] = sample_buffer:sample_data(channel, frame)
  end
  return renderb64(data)
end

-- Function to save the current instrument's sample buffer to a Convolver preset
function save_instrument_to_convolver(convolver_device, track_index, device_index)
  print(string.format("Saving instrument to Convolver at track %d, device %d", track_index, device_index))
  local selected_instrument = renoise.song().selected_instrument
  if #selected_instrument.samples == 0 then
    print("No sample data available in the selected instrument.")
    renoise.app():show_status("No sample data available in the selected instrument.")
    return
  end
  local selected_sample = selected_instrument:sample(1)
  local sample_buffer = selected_sample.sample_buffer
  if not sample_buffer.has_sample_data then
    print("No sample data available in the selected instrument.")
    renoise.app():show_status("No sample data available in the selected instrument.")
    return
  end
  local sample_name = selected_instrument.name
  local left_data = get_channel_data_as_b64(sample_buffer, 1)
  local right_data = sample_buffer.number_of_channels == 2 and get_channel_data_as_b64(sample_buffer, 2) or ""
  local sample_rate = sample_buffer.sample_rate
  local stereo = sample_buffer.number_of_channels == 2
  local sample_directory_path = "Custom/Path/To/Sample" -- Customize this path as needed
  local current_xml = convolver_device.active_preset_data
  print(string.format("Active preset data before update: %s", current_xml))
  print(string.format("Updating Convolver preset data with sample name: %s, sample rate: %d, stereo: %s, sample path: %s", sample_name, sample_rate, tostring(stereo), sample_directory_path))
  
  local is_init = current_xml:match("<SampleName>(.-)</SampleName>") == "No impulse loaded"
  local is_default = current_xml:match("<ImpulseDataSampleRate>(%d+)</ImpulseDataSampleRate>") == "0"

  local updated_xml
  if is_init or is_default then
    updated_xml = full_update_convolver_preset_data(left_data, right_data, sample_rate, sample_name, stereo, sample_directory_path)
  else
    updated_xml = soft_update_convolver_preset_data(current_xml, left_data, right_data, sample_rate, sample_name, stereo, sample_directory_path)
  end

  convolver_device.active_preset_data = updated_xml
  print(string.format("Active preset data after update: %s", convolver_device.active_preset_data))
  local length_left = string.len(left_data)
  local length_right = string.len(right_data)
  renoise.app():show_status(string.format("Added '%s' of length %d (left), %d (right), sample rate %d to Convolver %d", sample_name, length_left, length_right, sample_rate, device_index))
end

-- Function to create a new instrument and load sample data into the sample buffer
function create_instrument_from_convolver(convolver_device, track_index, device_index)
  print(string.format("Creating instrument from Convolver at track %d, device %d", track_index, device_index))
  local current_xml = convolver_device.active_preset_data
  if not current_xml or current_xml == "" then
    print(string.format("No preset data found in the selected device at track %d, device %d.", track_index, device_index))
    renoise.app():show_status("No preset data found in the selected device.")
    return
  end

  print("Active preset data before extraction:", current_xml)

  local left_sample_data = current_xml:match("<ImpulseDataLeft><!%[CDATA%[(.-)%]%]></ImpulseDataLeft>")
  local right_sample_data = current_xml:match("<ImpulseDataRight><!%[CDATA%[(.-)%]%]></ImpulseDataRight>")
  local sample_rate = tonumber(current_xml:match("<ImpulseDataSampleRate>(%d+)</ImpulseDataSampleRate>"))
  local sample_name = current_xml:match("<SampleName>(.-)</SampleName>")
  local stereo = right_sample_data and right_sample_data:match("%S") and true or false

  print(string.format("Sample rate: %d, Stereo: %s", sample_rate, tostring(stereo)))
  print(string.format("Left sample data length: %d", left_sample_data and #left_sample_data or 0))
  print(string.format("Right sample data length: %d", right_sample_data and #right_sample_data or 0))

  if not left_sample_data or left_sample_data == "" then
    print(string.format("No sample data available in the Convolver at track %d, device %d", track_index, device_index))
    renoise.app():show_status("No sample data available in the Convolver.")
    return
  end

  print("Sample data found, creating instrument...")

  local left_samples = parseb64(left_sample_data)
  local right_samples = stereo and parseb64(right_sample_data) or nil
  local selected_instrument_index = renoise.song().selected_instrument_index
  local new_instrument = renoise.song():insert_instrument_at(selected_instrument_index + 1)
  new_instrument.name = sample_name or "Loaded Convolver IR"
  local new_sample = new_instrument:insert_sample_at(1)
  local new_buffer = new_sample.sample_buffer
  new_sample.name = sample_name or "Loaded Convolver IR"
  local num_channels = stereo and 2 or 1
  local num_frames = #left_samples
  new_buffer:create_sample_data(sample_rate, 16, num_channels, num_frames)
  new_buffer:prepare_sample_data_changes()
  for frame = 1, num_frames do
    new_buffer:set_sample_data(1, frame, left_samples[frame])
  end
  if stereo and right_samples then
    for frame = 1, num_frames do
      new_buffer:set_sample_data(2, frame, right_samples[frame])
    end
  end
  new_buffer:finalize_sample_data_changes()
  renoise.song().selected_instrument_index = selected_instrument_index + 1
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app():show_status("Convolver IR loaded into new instrument and Sample Editor opened.")
  print(string.format("Exported '%s' of length %d, sample rate %d, stereo: %s to new instrument", sample_name, num_frames, sample_rate, tostring(stereo)))
end

-- Function to show the GUI for selecting or adding a Convolver device
function pakettiConvolverSelectionDialog(callback)
  print("Showing Convolver selection dialog")
  local vb = renoise.ViewBuilder()
  local dialog
  local function create_dialog_content()
    local dialog_content = vb:column{}
    local sample_name_text = vb:text{
      text="Selected Sample: " .. (renoise.song().selected_sample and renoise.song().selected_sample.name or "None"),
      style = "strong", font="bold"
    }
    dialog_content:add_child(sample_name_text)
    dialog_content:add_child(vb:button{
      text="Refresh",
      notifier=function()
        dialog:close()
        pakettiConvolverSelectionDialog(callback)
      end
    })
    renoise.song().selected_sample_observable:add_notifier(function()
      sample_name_text.text="Selected Sample: " .. (renoise.song().selected_sample and renoise.song().selected_sample.name or "None")
    end)
    for t = 1, #renoise.song().tracks do
      local track = renoise.song().tracks[t]
      local track_type = "Unknown"
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then track_type = "Track"
      elseif track.type == renoise.Track.TRACK_TYPE_SEND then track_type = "Send"
      elseif track.type == renoise.Track.TRACK_TYPE_GROUP then track_type = "Group"
      elseif track.type == renoise.Track.TRACK_TYPE_MASTER then track_type = "Master"
      end
      local row = vb:row{}
      row:add_child(vb:column{width=200, vb:text{text=string.format("%s, %s", track_type, track.name) } })
      local button_column = vb:row{width="100%" }
      local convolver_count = 0
      for d = 1, #track.devices do
        local device = track.devices[d]
        if device.name == "Convolver" then
          convolver_count = convolver_count + 1
          button_column:add_child(vb:button{
            text = string.format("Convolver #%d Import", convolver_count),
            notifier=function()
              renoise.song().selected_track_index = t
              renoise.song().selected_device_index = d
              print(string.format("Importing Convolver IR from track %d, device %d", t, d))
              callback(device, t, d, "import")
            end
          })
          button_column:add_child(vb:button{
            text = string.format("Convolver #%d Export", convolver_count),
            notifier=function()
              renoise.song().selected_track_index = t
              renoise.song().selected_device_index = d
              print(string.format("Exporting Convolver IR from track %d, device %d", t, d))
              callback(device, t, d, "export")
            end
          })
        end
      end
      row:add_child(button_column)
      row:add_child(vb:button{
        text="Insert Convolver as First",
        notifier=function()
          local device = track:insert_device_at("Audio/Effects/Native/Convolver", 2)
          renoise.song().selected_track_index = t
          renoise.song().selected_device_index = 2
          dialog:close()
          pakettiConvolverSelectionDialog(callback)
        end
      })
      row:add_child(vb:button{
        text="Insert Convolver as Last",
        notifier=function()
          local device_position = #renoise.song().tracks[t].devices + 1
          local device = track:insert_device_at("Audio/Effects/Native/Convolver", device_position)
          renoise.song().selected_track_index = t
          renoise.song().selected_device_index = device_position
          dialog:close()
          pakettiConvolverSelectionDialog(callback)
        end
      })
      dialog_content:add_child(row)
    end
    return dialog_content
  end
  dialog = renoise.app():show_custom_dialog("Load, Import/Export Convolver Device", create_dialog_content(), my_keyhandler_func)
end

function handle_convolver_action(device, track_index, device_index, action)
  if action == "import" then
    save_instrument_to_convolver(device, track_index, device_index)
  elseif action == "export" then
    create_instrument_from_convolver(device, track_index, device_index)
  end
end



renoise.tool():add_keybinding{name="Global:Paketti:Load Random IR from User Set Folder", invoke=function() PakettiRandomIR(preferences.PakettiIRPath.value) end}

--------
function pakettiMidiSimpleOutputRoute(output)
  local track=renoise.song().selected_track
  if output<=#track.available_output_routings then
    track.output_routing=track.available_output_routings[output]
    renoise.app():show_status("Selected Track Output Routing set to "..output)
  else
    renoise.app():show_status("Selected Track Output Routing value out of range.")
  end
end

function pakettiMidiMasterOutputRoutings(output)
  local song=renoise.song()
  local masterTrack=song:track(song.sequencer_track_count+1)
  if output<=#masterTrack.available_output_routings then
    masterTrack.output_routing=masterTrack.available_output_routings[output]
    renoise.app():show_status("Master Track Output Routing set to "..output)
  else
    renoise.app():show_status("Master Track Output Routing value out of range.")
  end
end

for i=0,63 do renoise.tool():add_midi_mapping{name="Paketti:Midi Set Selected Track Output Routing "..string.format("%02d",i),
    invoke=function(midi_message)
      pakettiMidiSimpleOutputRoute(i+1)
    end
  }
end

for i=0,63 do renoise.tool():add_midi_mapping{name="Paketti:Midi Set Master Track Output Routing "..string.format("%02d",i),
    invoke=function(midi_message)
      pakettiMidiMasterOutputRoutings(i+1)
    end
  }
end
----------------------
-- Function to toggle the MuteSource value in the XML data
function sendTest()
  -- Define the XML data with MuteSource as false
  local xml_data_false = [[
  <?xml version="1.0" encoding="UTF-8"?>
  <FilterDevicePreset doc_version="13">
    <DeviceSlot type="SendDevice">
      <IsMaximized>true</IsMaximized>
      <SendAmount>
        <Value>0.0</Value>
      </SendAmount>
      <SendPan>
        <Value>0.5</Value>
      </SendPan>
      <DestSendTrack>
        <Value>0.0</Value>
      </DestSendTrack>
      <MuteSource>false</MuteSource>
      <SmoothParameterChanges>true</SmoothParameterChanges>
      <ApplyPostVolume>true</ApplyPostVolume>
    </DeviceSlot>
  </FilterDevicePreset>
  ]]

  -- Define the XML data with MuteSource as true
  local xml_data_true = [[
  <?xml version="1.0" encoding="UTF-8"?>
  <FilterDevicePreset doc_version="13">
    <DeviceSlot type="SendDevice">
      <IsMaximized>true</IsMaximized>
      <SendAmount>
        <Value>0.0</Value>
      </SendAmount>
      <SendPan>
        <Value>0.5</Value>
      </SendPan>
      <DestSendTrack>
        <Value>0.0</Value>
      </DestSendTrack>
      <MuteSource>true</MuteSource>
      <SmoothParameterChanges>true</SmoothParameterChanges>
      <ApplyPostVolume>true</ApplyPostVolume>
    </DeviceSlot>
  </FilterDevicePreset>
  ]]

  -- Read the current active preset data
  local active_preset_data = renoise.song().selected_track.devices[2].active_preset_data

  -- Determine the current state of MuteSource in active_preset_data
  local mute_source_current = string.match(active_preset_data, "<MuteSource>(.-)</MuteSource>")

  -- Toggle the MuteSource value
  if mute_source_current == "true" then
    active_preset_data = xml_data_false
  else
    active_preset_data = xml_data_true
  end

  -- Set the modified XML data back to the active preset
  renoise.song().selected_track.devices[2].active_preset_data = active_preset_data
end

renoise.tool():add_keybinding{name="Global:Paketti:Send Reverser",invoke=function() sendTest() end}
-------------
function pakettiDumpAllTrackVolumes(db_change)
  local song=renoise.song()
  local tracks_modified = 0
  
  for _, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local current_db = track.postfx_volume.value_string:match("[-]?%d+%.?%d*") or 0
      current_db = tonumber(current_db)
      local new_db = current_db + db_change
      
      if new_db <= -200 then
        track.postfx_volume.value = 0 -- Set to -INF
      else
        track.postfx_volume.value_string = string.format("%.1f dB", new_db)
      end
      
      tracks_modified = tracks_modified + 1
    end
  end
  
  local msg = db_change >= 0 and "Increased" or "Decreased"
  renoise.app():show_status(string.format("%s volume by %.1fdB for %d tracks", msg, math.abs(db_change), tracks_modified))
end



renoise.tool():add_keybinding{name="--Global:Paketti:Decrease All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(-3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Increase All Track Volumes by 3dB", invoke=function() pakettiDumpAllTrackVolumes(3) end}
-------
function pakettiResizeAndFill(patternSize)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local current_length = pattern.number_of_lines
  local filled = false

  if current_length == patternSize then
    renoise.app():show_status("Pattern is already " .. patternSize .. " rows.")
    return
  end

  if current_length > patternSize then
    pattern.number_of_lines = patternSize
    renoise.app():show_status("Resized to " .. patternSize)
    return
  end

  while current_length < patternSize do
    local new_length = current_length * 2

    if new_length > renoise.Pattern.MAX_NUMBER_OF_LINES then
      renoise.app():show_status("Cannot resize pattern beyond the maximum limit of " .. renoise.Pattern.MAX_NUMBER_OF_LINES .. " lines.")
      return
    end

    pattern.number_of_lines = new_length

    for track_index, pattern_track in ipairs(pattern.tracks) do
      if not pattern_track.is_empty then
        for line_index = 1, current_length do
          local line = pattern_track:line(line_index)
          local new_line = pattern_track:line(line_index + current_length)
          new_line:copy_from(line)
        end
      end

      local track_automations = song.patterns[song.selected_pattern_index].tracks[track_index].automation
      for _, automation in pairs(track_automations) do
        local points = automation.points
        local new_points = {}
        for _, point in ipairs(points) do
          local new_time = point.time + current_length
          if new_time <= new_length then
            table.insert(new_points, {time = new_time, value = point.value})
          end
        end
        for _, new_point in ipairs(new_points) do
          automation:add_point_at(new_point.time, new_point.value)
        end
      end
    end

    current_length = new_length
    filled = true
  end

  if filled then
    renoise.app():show_status("Resized to " .. patternSize .. " and filled with pattern length " .. (patternSize / 2) .. " content")
  else
    renoise.app():show_status("Resized to " .. patternSize)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Pattern Resize and Fill 032",invoke=function() pakettiResizeAndFill(32) end}
renoise.tool():add_keybinding{name="Global:Paketti:Pattern Resize and Fill 064",invoke=function() pakettiResizeAndFill(64) end}
renoise.tool():add_keybinding{name="Global:Paketti:Pattern Resize and Fill 128",invoke=function() pakettiResizeAndFill(128) end}
renoise.tool():add_keybinding{name="Global:Paketti:Pattern Resize and Fill 256",invoke=function() pakettiResizeAndFill(256) end}
renoise.tool():add_keybinding{name="Global:Paketti:Pattern Resize and Fill 512",invoke=function() pakettiResizeAndFill(512) end}
-----
-- Define the function to flood fill with the selection
function floodfill_with_selection()
  -- Get the current song within the function
  local song=renoise.song()
  
  -- Ensure there's a selection in the pattern
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No selection in pattern.")
    return
  end

  local start_row = selection.start_line
  local end_row = selection.end_line
  local num_lines = song.selected_pattern.number_of_lines

  -- Determine the length of the selection
  local selection_length = end_row - start_row + 1

  -- Get the track indices in the selection
  local start_track = selection.start_track
  local end_track = selection.end_track

  -- Store the selected data
  local selection_data = {}

  -- Iterate over the selected tracks
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    local pattern_track = song:pattern(song.selected_pattern_index):track(track_idx)
    local num_note_columns = track.visible_note_columns
    local num_effect_columns = track.visible_effect_columns
    local total_columns = num_note_columns + num_effect_columns

    -- Determine start and end columns for the current track
    local track_start_column = track_idx == start_track and selection.start_column or 1
    local track_end_column = track_idx == end_track and selection.end_column or total_columns

    -- Debug: print track info
    rprint({
      track_idx = track_idx,
      track_start_column = track_start_column,
      track_end_column = track_end_column,
      num_note_columns = num_note_columns,
      num_effect_columns = num_effect_columns
    })

    -- Store the data for this track
    selection_data[track_idx] = {}

    -- Iterate over the selected rows and columns to capture data
    for row = start_row, end_row do
      selection_data[track_idx][row] = {}
      for col_idx = track_start_column, track_end_column do
        if col_idx <= num_note_columns then
          -- Capture note column data
          local note_column = pattern_track:line(row).note_columns[col_idx]
          selection_data[track_idx][row][col_idx] = {
            note = note_column.note_value,
            instrument = note_column.instrument_value,
            volume = note_column.volume_value,
            panning = note_column.panning_value,
            delay = note_column.delay_value
          }
        elseif col_idx > num_note_columns and col_idx <= total_columns then
          -- Capture effect column data
          local effect_col_idx = col_idx - num_note_columns
          local effect_column = pattern_track:line(row).effect_columns[effect_col_idx]
          selection_data[track_idx][row][col_idx] = {
            effect_number = effect_column.number_value,
            effect_amount = effect_column.amount_value
          }
        end
      end
    end

    -- Debug: print selection data for current track
    --rprint(selection_data[track_idx])
  end

  -- Repeat the selection data throughout the pattern
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    local pattern_track = song:pattern(song.selected_pattern_index):track(track_idx)
    local num_note_columns = track.visible_note_columns
    local num_effect_columns = track.visible_effect_columns
    local total_columns = num_note_columns + num_effect_columns

    -- Determine start and end columns for the current track
    local track_start_column = track_idx == start_track and selection.start_column or 1
    local track_end_column = track_idx == end_track and selection.end_column or total_columns

    for i = 0, math.floor((num_lines - end_row - 1) / selection_length) do
      for row = start_row, end_row do
        for col_idx = track_start_column, track_end_column do
          local target_row = end_row + (i * selection_length) + (row - start_row) + 1
          if target_row > num_lines then break end

          if col_idx <= num_note_columns then
            -- Copy the note data to the new position
            local note_data = selection_data[track_idx][row][col_idx]
            local target_note_column = pattern_track:line(target_row).note_columns[col_idx]

            target_note_column.note_value = note_data.note
            target_note_column.instrument_value = note_data.instrument
            target_note_column.volume_value = note_data.volume
            target_note_column.panning_value = note_data.panning
            target_note_column.delay_value = note_data.delay

          elseif col_idx > num_note_columns and col_idx <= total_columns then
            -- Copy the effect data to the new position
            local effect_data = selection_data[track_idx][row][col_idx]
            local effect_col_idx = col_idx - num_note_columns
            local target_effect_column = pattern_track:line(target_row).effect_columns[effect_col_idx]

            target_effect_column.number_value = effect_data.effect_number
            target_effect_column.amount_value = effect_data.effect_amount
          end

          -- Debug: print copied data
 --         print(string.format("Copied data from track %d, row %d, col %d to row %d", track_idx, row, col_idx, target_row))
        end
      end
    end
  end

  renoise.app():show_status("Flood fill with selection completed.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Flood Fill with Selection",invoke=floodfill_with_selection}
-----
-- Define the function to rotate track content
function rotate_track_content_to_selection_start_first()
  -- Get the current song
  local song=renoise.song()
  
  -- Check if there's a selection in the pattern
  local selection = song.selection_in_pattern
  local start_line
  local num_lines = song.selected_pattern.number_of_lines

  if selection then
    start_line = selection.start_line
  else
    start_line = song.selected_line_index
  end

  -- Determine the range of tracks to rotate
  local start_track = selection and selection.start_track or song.selected_track_index
  local end_track = selection and selection.end_track or song.selected_track_index

  -- Store the data to be rotated (Part 1 and Part 2)
  local part1_data = {}
  local part2_data = {}

  -- Iterate over the selected tracks
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    local pattern_track = song:pattern(song.selected_pattern_index):track(track_idx)
    local num_note_columns = track.visible_note_columns
    local num_effect_columns = track.visible_effect_columns
    local total_columns = num_note_columns + num_effect_columns

    -- Determine start and end columns for the current track
    local track_start_column = (selection and track_idx == start_track) and selection.start_column or 1
    local track_end_column = (selection and track_idx == end_track) and selection.end_column or total_columns

    -- Store the data for this track
    part1_data[track_idx] = {}
    part2_data[track_idx] = {}

    -- Capture data from `start_line` to the end of the pattern (Part 1)
    for line = start_line, num_lines do
      part1_data[track_idx][line] = {}
      for col_idx = track_start_column, track_end_column do
        if col_idx <= num_note_columns then
          local note_column = pattern_track:line(line).note_columns[col_idx]
          part1_data[track_idx][line][col_idx] = {
            note = note_column.note_value,
            instrument = note_column.instrument_value,
            volume = note_column.volume_value,
            panning = note_column.panning_value,
            delay = note_column.delay_value
          }
        elseif col_idx > num_note_columns and col_idx <= total_columns then
          local effect_col_idx = col_idx - num_note_columns
          local effect_column = pattern_track:line(line).effect_columns[effect_col_idx]
          part1_data[track_idx][line][col_idx] = {
            effect_number = effect_column.number_value,
            effect_amount = effect_column.amount_value
          }
        end
      end
    end

    -- Capture data from the start of the pattern to `start_line - 1` (Part 2)
    for line = 1, start_line - 1 do
      part2_data[track_idx][line] = {}
      for col_idx = track_start_column, track_end_column do
        if col_idx <= num_note_columns then
          local note_column = pattern_track:line(line).note_columns[col_idx]
          part2_data[track_idx][line][col_idx] = {
            note = note_column.note_value,
            instrument = note_column.instrument_value,
            volume = note_column.volume_value,
            panning = note_column.panning_value,
            delay = note_column.delay_value
          }
        elseif col_idx > num_note_columns and col_idx <= total_columns then
          local effect_col_idx = col_idx - num_note_columns
          local effect_column = pattern_track:line(line).effect_columns[effect_col_idx]
          part2_data[track_idx][line][col_idx] = {
            effect_number = effect_column.number_value,
            effect_amount = effect_column.amount_value
          }
        end
      end
    end
  end

  -- Apply the rotation
  for track_idx = start_track, end_track do
    local pattern_track = song:pattern(song.selected_pattern_index):track(track_idx)
    local num_note_columns = song:track(track_idx).visible_note_columns
    local num_effect_columns = song:track(track_idx).visible_effect_columns
    local total_columns = num_note_columns + num_effect_columns
    local track_start_column = (selection and track_idx == start_track) and selection.start_column or 1
    local track_end_column = (selection and track_idx == end_track) and selection.end_column or total_columns

    -- Part 1: Move data to the top
    local line_counter = 1
    for line = start_line, num_lines do
      for col_idx = track_start_column, track_end_column do
        if col_idx <= num_note_columns then
          local note_data = part1_data[track_idx][line][col_idx]
          local target_note_column = pattern_track:line(line_counter).note_columns[col_idx]

          target_note_column.note_value = note_data.note
          target_note_column.instrument_value = note_data.instrument
          target_note_column.volume_value = note_data.volume
          target_note_column.panning_value = note_data.panning
          target_note_column.delay_value = note_data.delay
        elseif col_idx > num_note_columns and col_idx <= total_columns then
          local effect_data = part1_data[track_idx][line][col_idx]
          local effect_col_idx = col_idx - num_note_columns
          local target_effect_column = pattern_track:line(line_counter).effect_columns[effect_col_idx]

          target_effect_column.number_value = effect_data.effect_number
          target_effect_column.amount_value = effect_data.effect_amount
        end
      end
      line_counter = line_counter + 1
    end

    -- Part 2: Move data after Part 1
    for line = 1, start_line - 1 do
      for col_idx = track_start_column, track_end_column do
        if col_idx <= num_note_columns then
          local note_data = part2_data[track_idx][line][col_idx]
          local target_note_column = pattern_track:line(line_counter).note_columns[col_idx]

          target_note_column.note_value = note_data.note
          target_note_column.instrument_value = note_data.instrument
          target_note_column.volume_value = note_data.volume
          target_note_column.panning_value = note_data.panning
          target_note_column.delay_value = note_data.delay
        elseif col_idx > num_note_columns and col_idx <= total_columns then
          local effect_data = part2_data[track_idx][line][col_idx]
          local effect_col_idx = col_idx - num_note_columns
          local target_effect_column = pattern_track:line(line_counter).effect_columns[effect_col_idx]

          target_effect_column.number_value = effect_data.effect_number
          target_effect_column.amount_value = effect_data.effect_amount
        end
      end
      line_counter = line_counter + 1
    end
  end

  renoise.app():show_status(string.format("Set Line %d as First Line", start_line))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Rotate Track Content to SelectionStart First",invoke = rotate_track_content_to_selection_start_first}

-----
local vb = renoise.ViewBuilder()
local rs = math.random
local strategies
local dialog -- Holds the reference to the dialog
local message
local img_path = "External/catinhat.png"
local file_path = "External/obliquestrategies.txt"

local function load_strategies()
  local file, err = io.open(file_path, "r")
  if not file then
    renoise.app():show_message("Failed to open file: "..err)
    return
  end
  strategies = {}
  for line in file:lines() do
    table.insert(strategies, line)
  end
  file:close()
end

local function get_random_message()
  if #strategies > 0 then
    return strategies[rs(#strategies)]
  else
    return "No strategies found."
  end
end

function pakettiObliqueStrategiesDialog()
  -- Check if dialog is already visible
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  load_strategies()
  message = get_random_message()
  
  local message_text=vb:text{width=300,font="big",style="strong",align="center",text=message}

  local dialog_content=vb:column{
    margin=20,spacing=10,
    vb:horizontal_aligner{
      mode = "center",
      vb:text{style="strong",align="center",text="Click Image to Roll Again"}},
    vb:horizontal_aligner{
      mode = "center",
      vb:bitmap{
        mode="body_color",
        bitmap=img_path,
        notifier=function()
          message = get_random_message()
          message_text.text = message
        end
      }
    },
    vb:horizontal_aligner{
      mode = "center",
      message_text
    },
    vb:horizontal_aligner{
      mode = "center",
      vb:space{
        width=320,
        height = 2,
      }
    },
    vb:horizontal_aligner{
      mode = "center",
      spacing=10,
      vb:button{text="OK", released = function()
        renoise.app():show_status("Oblique Strategies: " .. message)
        dialog:close()
      end},
      vb:button{text="Cancel", released = function() dialog:close() end},
      vb:button{text="Next", released = function() message =get_random_message() message_text.text = message end}
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Oblique Strategies", dialog_content, my_keyhandler_func)
end

function shuffle_oblique_strategies()
  load_strategies()
  message = get_random_message()
  renoise.app():show_status("Oblique Strategies: " .. message)
end

renoise.tool():add_keybinding{name="Global:Paketti:Open Oblique Strategies Dialog...",invoke=function() pakettiObliqueStrategiesDialog()  end}
renoise.tool():add_keybinding{name="Global:Paketti:Shuffle Oblique Strategies Cards",invoke=shuffle_oblique_strategies}
-------
-- Paketti Track Titler
local dialog
local vb = renoise.ViewBuilder()
local default_file_path = "External/wordlist.txt" -- Default file path
local selected_file_path = default_file_path -- Initial file path
local default_notes_file_path = "External/notes.txt" -- Default notes file path
local notes_file_path = default_notes_file_path -- Initial notes file path
local use_dash_format = false
local no_date = false
local text_format = 1 -- 1=Off, 2=lowercase, 3=Capital, 4=UPPERCASE, 5=eLiTe
local before_name_text=""
local date_format_option = "YYYY-MM-DD" -- default date format
local date_formats = { -- list of possible date formats
  "YYYY-MM-DD",
  "DD-MM-YY",
  "DD-MM-YYYY",
  "YYYY-DD-MM",
  "MM-DD-YY",
  "MM-DD-YYYY"
}
--local prefs_path = renoise.tool().bundle_path .. "preferencesSave.xml"

-- Function to apply the selected text format
local function PakettiTitlerApplyTextFormat(text)
  if text_format == 3 then
    return text:gsub("(%a)(%w*)", function(a, b) return string.upper(a) .. string.lower(b) end)
  elseif text_format == 4 then
    return string.upper(text)
  elseif text_format == 5 then
    return text:gsub("%a", function(c)
      if c:lower():match("[aeiouåäöéèêëòóôöüûú]") then
        return c:lower()
      else
        return c:upper()
      end
    end)
  elseif text_format == 2 then
    return text:lower()
  else
    return text -- "Off" leaves the text unchanged
  end
end

-- Function to generate a random string
local function PakettiTitlerGenerateRandomString(length)
  local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local result = {}
  for i = 1, length do
    local index = math.random(1, #charset)
    result[i] = charset:sub(index, index)
  end
  return table.concat(result)
end

-- Function to randomize from a textfile
local function PakettiTitlerRandomizeFromTextfile(file_path, count)
  local words = {}
  for line in io.lines(file_path) do
    for word in line:gmatch("%w+") do
      table.insert(words, word)
    end
  end
  local selected_words = {}
  for i = 1, count do
    table.insert(selected_words, words[math.random(#words)])
  end
  return table.concat(selected_words, " ")
end

-- Function to format the current date based on the selected format
local function PakettiTitlerGetFormattedDate()
  if no_date then
    return ""
  end

  local date = os.date("*t")
  local separator = use_dash_format and "-" or "_"

  local year_full = string.format("%04d", date.year)
  local year_short = string.sub(year_full, 3, 4) -- last two digits of the year
  local month = string.format("%02d", date.month)
  local day = string.format("%02d", date.day)

  if date_format_option == "YYYY-MM-DD" then
    return year_full .. separator .. month .. separator .. day
  elseif date_format_option == "DD-MM-YY" then
    return day .. separator .. month .. separator .. year_short
  elseif date_format_option == "DD-MM-YYYY" then
    return day .. separator .. month .. separator .. year_full
  elseif date_format_option == "YYYY-DD-MM" then
    return year_full .. separator .. day .. separator .. month
  elseif date_format_option == "MM-DD-YY" then
    return month .. separator .. day .. separator .. year_short
  elseif date_format_option == "MM-DD-YYYY" then
    return month .. separator .. day .. separator .. year_full
  else
    -- Default to YYYY-MM-DD if unknown format
    return year_full .. separator .. month .. separator .. day
  end
end

-- Function to split a string by a given separator
local function PakettiTitlerSplitString(input, separator)
  if separator == nil then
    separator = "%s"
  end
  local t = {}
  for str in string.gmatch(input, "([^" .. separator .. "]+)") do
    table.insert(t, str)
  end
  return t
end

-- Function to save the song with the generated filename
local function PakettiTitlerSaveSongWithTitle(title)
  local date = PakettiTitlerGetFormattedDate()
  local separator = use_dash_format and "-" or "_"
  local filename = (no_date and "" or date .. separator)
  if before_name_text ~= "" then
    filename = filename .. PakettiTitlerApplyTextFormat(before_name_text) .. separator
  end
  filename = filename .. PakettiTitlerApplyTextFormat(title) .. ".xrns"
  local folder = renoise.app():prompt_for_path("Save Current Song (" .. filename .. ") to Folder")
  if folder and folder ~= "" then
    local full_path = folder .. "/" .. filename
    renoise.app():save_song_as(full_path)
    renoise.app():show_status("Song Saved as: " .. full_path)
  else
    renoise.app():show_status("Did not Save " .. filename .. ", saving operation canceled.")
  end
end

-- Function to update the full filename display
local function PakettiTitlerUpdateFilenameDisplay()
  local date = PakettiTitlerGetFormattedDate()
  local title = vb.views.title_field.text
  local separator = use_dash_format and "-" or "_"
  local full_filename = (no_date and "" or date .. separator)
  if before_name_text ~= "" then
    full_filename = full_filename .. PakettiTitlerApplyTextFormat(before_name_text) .. separator
  end
  full_filename = full_filename .. PakettiTitlerApplyTextFormat(title) .. ".xrns"
  vb.views.filename_display.text = full_filename
end

-- Function to load preferences from XML
local function PakettiTitlerPreferencesLoad()
  selected_file_path = renoise.tool().preferences.pakettiTitler.textfile_path.value
  notes_file_path = renoise.tool().preferences.pakettiTitler.notes_file_path.value
  date_format_option = renoise.tool().preferences.pakettiTitler.trackTitlerDateFormat.value
end

-- Function to save preferences to XML
local function PakettiTitlerPreferencesSave()
renoise.tool().preferences.pakettiTitler.textfile_path.value= selected_file_path
renoise.tool().preferences.pakettiTitler.notes_file_path.value = notes_file_path
renoise.tool().preferences.pakettiTitler.trackTitlerDateFormat.value = date_format_option
end

-- Function to get the index of the current date format
local function PakettiTitlerGetDateFormatIndex()
  for i, format in ipairs(date_formats) do
    if format == date_format_option then
      return i
    end
  end
  return 1 -- default to first item if not found
end

-- Function to show the date & title dialog
function pakettiTitlerDialog()
  vb = renoise.ViewBuilder()
  local date = PakettiTitlerGetFormattedDate()
  local default_title = ""

  local function PakettiTitlerCloseDialog()
    if dialog and dialog.visible then
      PakettiTitlerPreferencesSave()
      dialog:close()
    end
  end

  local function PakettiTitlerHandleSave()
    local title = vb.views.title_field.text
    PakettiTitlerSaveSongWithTitle(title)
  end

  local function PakettiTitlerRandomString()
    local random_string = PakettiTitlerGenerateRandomString(8)
    vb.views.title_field.text = random_string
    PakettiTitlerUpdateFilenameDisplay()
  end

  local function PakettiTitlerBrowseTextfile()
    selected_file_path = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Browse Textfile")
    if selected_file_path and selected_file_path ~= "" then
      PakettiTitlerPreferencesSave() -- Save the selected file path
      vb.views.textfile_display.text="Path: " .. selected_file_path -- Display the file path
    else
      selected_file_path = default_file_path
      vb.views.textfile_display.text="Path: " .. default_file_path -- Revert to default
    end
  end

  local function PakettiTitlerBrowseNotesFile()
    local new_path = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Select Notes File")
    if new_path and new_path ~= "" then
      notes_file_path = new_path
      vb.views.notes_file_field.text = notes_file_path
      PakettiTitlerPreferencesSave()
    end
  end

  local function PakettiTitlerSaveTitleToNotes()
    local title = vb.views.title_field.text
    if title and title ~= "" then
      local file, err = io.open(notes_file_path, "a")
      if not file then
        renoise.app():show_error("Failed to open file: " .. tostring(err))
        return
      end
      file:write(title .. "\n")
      file:close()
      renoise.app():show_status("Title saved to notes file.")
    else
      renoise.app():show_warning("Title is empty. Nothing to save.")
    end
  end

  local function PakettiTitlerOpenNotesPath()
    local path = notes_file_path:match("(.*)[/\\]")
    if not path then
      path = '.'
    end
    renoise.app():open_path(path)
  end

  local function PakettiTitlerRandomWords()
    -- Check if file exists before using it
    local file = io.open(selected_file_path, "r")
    if not file then
      renoise.app():show_status("Error: No valid textfile selected or file does not exist.")
      PakettiTitlerBrowseTextfile()
      return
    end
    file:close()
    local count = vb.views.word_count.value
    local random_title = PakettiTitlerRandomizeFromTextfile(selected_file_path, count)
    vb.views.title_field.text = random_title
    PakettiTitlerUpdateFilenameDisplay()
  end

  local function PakettiTitlerSwitchDateSeparator(value)
    use_dash_format = (value == 2)
    PakettiTitlerUpdateFilenameDisplay()
  end

  local function PakettiTitlerHandleNoDate(value)
    no_date = value
    PakettiTitlerUpdateFilenameDisplay()
  end

  local function PakettiTitlerHandleBeforeNameChange(new_value)
    before_name_text = new_value
    PakettiTitlerUpdateFilenameDisplay()
  end

  local function PakettiTitlerHandleTextFormat(value)
    text_format = value
    PakettiTitlerUpdateFilenameDisplay()
  end

  local function PakettiTitlerHandleDateFormatChange(value)
    date_format_option = date_formats[value]
    PakettiTitlerPreferencesSave()
    PakettiTitlerUpdateFilenameDisplay()
  end

  -- Function to shift words to the left
  local function PakettiTitlerShiftWordsLeft()
    local words = PakettiTitlerSplitString(vb.views.title_field.text, " ")
    if #words > 1 then
      table.insert(words, table.remove(words, 1)) -- Move first word to the end
      vb.views.title_field.text = table.concat(words, " ")
      PakettiTitlerUpdateFilenameDisplay()
    end
  end

  -- Function to shift words to the right
  local function PakettiTitlerShiftWordsRight()
    local words = PakettiTitlerSplitString(vb.views.title_field.text, " ")
    if #words > 1 then
      table.insert(words, 1, table.remove(words)) -- Move last word to the beginning
      vb.views.title_field.text = table.concat(words, " ")
      PakettiTitlerUpdateFilenameDisplay()
    end
  end

  -- Load preferences
  PakettiTitlerPreferencesLoad()

  local dialog_content = vb:column{
    margin=10,
    width=580,
    vb:row{
      vb:text{text="Before Name:", font = "mono"},
      vb:textfield{
        id = "before_name_field",
        text = before_name_text,
        width=200,
        notifier=function(text)
          PakettiTitlerHandleBeforeNameChange(text)
        end
      }
    },
    vb:row{
      vb:text{text="Actual Name:", font = "mono"},
      vb:textfield{
        id = "title_field",
        text = default_title,
        width=400,
        edit_mode = true,
        notifier=function(text)
          PakettiTitlerUpdateFilenameDisplay()
        end
      },
      vb:text{text=".xrns"}
    },
    vb:row{
      vb:text{
        id = "filename_display",
        text="",
        font = "bold",
        width=800
      }
    },
    vb:row{
      vb:button{text="Save As",width=135, notifier = PakettiTitlerHandleSave},
      vb:button{text="Cancel",width=135, notifier = PakettiTitlerCloseDialog}
    },
    vb:row{
      vb:button{text="Random String",width=135, notifier = PakettiTitlerRandomString},
      vb:button{text="Browse Textfile",width=135, notifier = PakettiTitlerBrowseTextfile}
    },
    vb:row{
      vb:text{id = "textfile_display", text="Path: " .. selected_file_path}
    },
    vb:row{
      vb:button{text="Random Words",width=135, notifier = PakettiTitlerRandomWords},
      vb:button{text="Shift Left",width=135, notifier = PakettiTitlerShiftWordsLeft},
      vb:button{text="Shift Right",width=135, notifier = PakettiTitlerShiftWordsRight}
    },
    vb:row{
      vb:text{text="Wordcount:"},
      vb:valuebox{
        id = "word_count",
        min = 1,
        max = 16,
        value = 2,
        notifier = PakettiTitlerRandomWords
      }
    },
    vb:row{
      vb:checkbox{
        id = "no_date_checkbox",
        value = no_date,
        notifier = PakettiTitlerHandleNoDate
      },
      vb:text{text="No Date"}
    },
    vb:row{
      vb:text{text="Separator",width=70},
      vb:switch{
        id = "date_separator_switch",
        items = {"_", "-"},
        width=50,
        value = use_dash_format and 2 or 1,
        notifier = PakettiTitlerSwitchDateSeparator
      }
    },
    vb:row{
      vb:text{text="Date Format",width=70},
      vb:popup{
        width= 150,
        id = "date_format_popup",
        items = date_formats,
        value = PakettiTitlerGetDateFormatIndex(),
        notifier = PakettiTitlerHandleDateFormatChange
      }
    },
    vb:row{
      vb:text{text="Text Format",width=70},
      vb:switch{
        id = "text_format_switch",
        items = {"Off", "lowercase", "Capital", "UPPERCASE", "eLiTe"},
        width=350,
        value = text_format,
        notifier = PakettiTitlerHandleTextFormat
      }
    },
    vb:row{
      vb:text{text="Save notes:",width=70},
      vb:textfield{
        id = "notes_file_field",
        text = notes_file_path,
        width=200,
        notifier=function(text)
          notes_file_path = text
          PakettiTitlerPreferencesSave()
        end
      },
      vb:button{text="Browse",notifier = PakettiTitlerBrowseNotesFile},
      vb:button{text="Save",notifier = PakettiTitlerSaveTitleToNotes},
      vb:button{text="Open Path",notifier = PakettiTitlerOpenNotesPath}}
  }

  -- Initialize filename display
  PakettiTitlerUpdateFilenameDisplay()

  dialog = renoise.app():show_custom_dialog("Paketti Track Dater & Titler", dialog_content, my_keyhandler_func)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Track Dater & Titler",invoke=pakettiTitlerDialog}
------
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume to -INF dB",
  invoke=function() 
    local song=renoise.song()
    local instrument = song.selected_instrument
    local sample = song.selected_sample

    if instrument and sample and sample.sample_buffer then
      sample.volume = 0
      renoise.app():show_status("Sample volume set to -INF dB.")
    else
      renoise.app():show_status("Cannot set volume: No valid sample selected.")
    end
  end
}


function sampleVolumeSwitcharoo()
local ing=renoise.song().selected_instrument
local s=renoise.song().selected_sample

s.volume=1
for i=1,#ing.samples do
ing.samples[i].volume = 0
end
s.volume=1
renoise.app():show_status("Current Sample " .. renoise.song().selected_sample_index .. ":" .. renoise.song().selected_sample.name .. " set to 0.0dB, all other Samples in Selected Instrument set to -INF dB.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Volume 0.0dB, others -INF",invoke=function() sampleVolumeSwitcharoo() end}

------



function PakettiRecordFollowMetronomePrecountPatternEditor(bars)
renoise.app().window.active_middle_frame=1
renoise.song().transport.edit_mode=true
renoise.song().transport.follow_player=true
renoise.song().transport.playback_pos.line=1
renoise.song().transport.metronome_precount_enabled=true
renoise.song().transport.metronome_precount_bars=bars
renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
--renoise.song().transport.playing=true

end

renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow+Metronome Precount 1 Bar",invoke=function()
PakettiRecordFollowMetronomePrecountPatternEditor(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow+Metronome Precount 2 Bar",invoke=function()
PakettiRecordFollowMetronomePrecountPatternEditor(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow+Metronome Precount 3 Bar",invoke=function()
PakettiRecordFollowMetronomePrecountPatternEditor(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow+Metronome Precount 4 Bar",invoke=function()
PakettiRecordFollowMetronomePrecountPatternEditor(4) end}
------







-- Main function to adjust sample velocity range
function pakettiSampleVelocityRangeChoke(sample_index)
  local song=renoise.song()
  local ing = song.selected_instrument

  -- Edge case: no instrument or no samples
  if not ing or #ing.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Set all samples' velocity ranges to {0, 0}, except the selected one
  for i = 1, #ing.samples do
    if i ~= sample_index then
      local mapping = ing.sample_mappings[1][i]
      if mapping then
        mapping.velocity_range = {0, 0} -- Disable all other samples
      end
    end
  end

  -- Set the selected sample's velocity range to {0, 127}
  local selected_mapping = ing.sample_mappings[1][sample_index]
  if selected_mapping then
    selected_mapping.velocity_range = {0, 127} -- Enable selected sample
  end
  
  renoise.song().selected_sample_index=sample_index
renoise.app():show_status("Sample " .. sample_index .. ": " .. renoise.song().selected_sample.name .. " selected.")
  -- Update status
  --renoise.app():show_status("Sample " .. sample_index .. " set to velocity range 00-7F, all other samples set to 00-00.")
end

function midi_sample_velocity_switcharoo(value)
  local song=renoise.song()
  local ing = song.selected_instrument

  -- Edge case: no instrument or no samples
  if not ing or #ing.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Map the MIDI knob value (0-127) to the sample index
  local selected_sample_index = math.floor((value / 127) * (#ing.samples - 1)) + 1


  -- Set velocity ranges for all samples based on the selected sample
  pakettiSampleVelocityRangeChoke(selected_sample_index)
end

-- "One-up" keybinding: Decreases selected_sample_index by 1
function sample_one_up()
  local song=renoise.song()
  local ing = song.selected_instrument
  local current_index = song.selected_sample_index

  -- Ensure boundary conditions
  if current_index > 1 then
    song.selected_sample_index = current_index - 1
    pakettiSampleVelocityRangeChoke(song.selected_sample_index)
  end
  end

-- "One-down" keybinding: Increases selected_sample_index by 1
function sample_one_down()
  local song=renoise.song()
  local ing = song.selected_instrument
  local current_index = song.selected_sample_index

  -- Ensure boundary conditions
  if current_index < #ing.samples then
    song.selected_sample_index = current_index + 1
    pakettiSampleVelocityRangeChoke(song.selected_sample_index)
  end
  end

-- "Random" keybinding: Selects a random sample and mutes others
function sample_random()
  local song=renoise.song()
  local ing = song.selected_instrument

  -- Edge case: no instrument or no samples
  if not ing or #ing.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Pick a random sample index
  local random_index = math.random(1, #ing.samples)
  song.selected_sample_index = random_index

  -- Set velocity ranges accordingly
  pakettiSampleVelocityRangeChoke(random_index)
end

renoise.tool():add_midi_mapping{name="Paketti:Midi Set Selected Sample Velocity Range 7F",invoke=function(midi_message) midi_sample_velocity_switcharoo(midi_message.int_value) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample (+1) Velocity Range 7F others 00",invoke=function() sample_one_down() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample (-1) Velocity Range 7F others 00",invoke=function() sample_one_up() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample (Random) Velocity Range 7F others 00",invoke=function() sample_random() end}
renoise.tool():add_midi_mapping{name="Paketti:Set Selected Sample (+1) Velocity Range 7F others 00",invoke=function(message) if message:is_trigger() then sample_one_down() end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Selected Sample (-1) Velocity Range 7F others 00",invoke=function(message) if message:is_trigger() then sample_one_up() end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Selected Sample (Random) Velocity Range 7F others 00",invoke=function(message) if message:is_trigger() then sample_random() end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Selected Sample Velocity Range 7F",invoke=function(message) if message:is_trigger() then SelectedSampleVelocityRange(0,127) end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Selected Sample Velocity Range 00",invoke=function(message) if message:is_trigger() then SelectedSampleVelocityRange(0,0) end end}
---
function SelectedSampleVelocityRange(number1,number2)
  local ing = renoise.song().selected_instrument

  -- Edge case: no instrument or no samples
  if not ing or #ing.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Set all samples' velocity ranges to {0, 0}, except the selected one
      local mapping = ing.sample_mappings[1][renoise.song().selected_sample_index]
      if mapping then
        if mapping.velocity_range[1] == number1 and mapping.velocity_range[2] == number2 then
          renoise.app():show_status("The Velocity Range of this Sample is already set to " .. number1 .. "-" .. number2 .. ".")
          return 
      end 
        mapping.velocity_range = {number1,number2} -- Disable all other samples
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Velocity Range 7F",invoke=function() SelectedSampleVelocityRange(0,127) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Velocity Range 00",invoke=function() SelectedSampleVelocityRange(0,0) end}

--[[ 
  Renoise Tool: Paketti - Set Sample Slot Velocity Range
  Description: Allows setting the velocity range for individual sample slots (01 to 32) via keybindings and MIDI mappings.
--]]



-- Function to set the velocity range for a specific sample slot
local function SetSampleSlotVelocity(sample_slot_number, velocity)
  local song=renoise.song()
  local instrument = song.selected_instrument

  -- Edge case: no instrument selected or no samples
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Validate sample slot number
  if sample_slot_number < 1 or sample_slot_number > 32 then
    renoise.app():show_status(string.format("Sample slot %02d is out of range (01-32).", sample_slot_number))
    return
  end

  -- Check if the sample slot exists
  if not instrument.samples[sample_slot_number] then
    renoise.app():show_status(string.format("Sample slot %02d does not exist.", sample_slot_number))
    return
  end

  -- Access the sample mapping for the given sample slot
  local mapping_group = 1 -- Assuming group 1; adjust if necessary
  if not instrument.sample_mappings[mapping_group] then
    renoise.app():show_status("Sample mapping group does not exist.")
    return
  end

  local mapping = instrument.sample_mappings[mapping_group][sample_slot_number]

  if not mapping then
    renoise.app():show_status(string.format("Sample mapping for slot %02d not found.", sample_slot_number))
    return
  end

  -- Set the velocity range based on the velocity argument
  if velocity == 0 then
    mapping.velocity_range = {0, 0}
  elseif velocity == 127 then
    mapping.velocity_range = {0, 127}
  else
    renoise.app():show_status("Invalid velocity value. Use 0 or 127.")
    return
  end

  renoise.app():show_status(string.format("Set velocity range of Sample Slot %02d to {%d, %d}", 
                                         sample_slot_number, 
                                         mapping.velocity_range[1], 
                                         mapping.velocity_range[2]))
end

  for i = 1, 32 do
      local sample_slot_name = formatDigits(2, i)
      renoise.tool():add_keybinding{name="Global:Paketti:Set Sample Slot " .. sample_slot_name .. " Velocity to 00",
        invoke=function() SetSampleSlotVelocity(i, 0) end}
      renoise.tool():add_keybinding{name="Global:Paketti:Set Sample Slot " .. sample_slot_name .. " Velocity to 7F",
        invoke=function() SetSampleSlotVelocity(i, 127) end}

      renoise.tool():add_midi_mapping{name="Paketti:Set Sample Slot " .. sample_slot_name .. " Velocity to 00",
        invoke=function(message) if message:is_trigger() then SetSampleSlotVelocity(i, 0) end end}
      renoise.tool():add_midi_mapping{name="Paketti:Set Sample Slot " .. sample_slot_name .. " Velocity to 7F",
        invoke=function(message) if message:is_trigger() then SetSampleSlotVelocity(i, 127) end end}
  end

  function SelectedAllSamplesVelocityRange(number1,number2)
    local song=renoise.song()
    local ing = song.selected_instrument
  
    -- Edge case: no instrument or no samples
    if not ing or #ing.samples == 0 then
      renoise.app():show_status("No instrument or samples available.")
      return
    end
  
    for i = 1, #ing.samples do
        local mapping = ing.sample_mappings[1][i]
        if mapping then
          mapping.velocity_range = {number1, number2}  -- Use the input parameters
        end
    end
  end


renoise.tool():add_keybinding{name="Global:Paketti:Set All Samples Velocity Range 7F",
invoke=function() SelectedAllSamplesVelocityRange(0,127)
end}

renoise.tool():add_keybinding{name="Global:Paketti:Set All Samples Velocity Range 00",
invoke=function() SelectedAllSamplesVelocityRange(0,0)
end}

-----
-- Resize all non-empty patterns to <rowvalue> lines
function resize_all_non_empty_patterns_to(rowvalue)
  local song=renoise.song()
  for i = 1, #song.patterns do
    if not song.patterns[i].is_empty then
      song.patterns[i].number_of_lines = rowvalue
    end
  end
  renoise.app():show_status("Resized all non-empty patterns to " .. rowvalue .. " lines.")
end

-- Resize all non-empty patterns to the current pattern's length
function resize_all_non_empty_patterns_to_current_pattern_length()
  local song=renoise.song()
  local current_pattern_length = song.patterns[song.selected_pattern_index].number_of_lines
  for i = 1, #song.patterns do
    if not song.patterns[i].is_empty then
      song.patterns[i].number_of_lines = current_pattern_length
    end
  end
  renoise.app():show_status("Resized all non-empty patterns to the current pattern's length (" .. song.patterns[song.selected_pattern_index].number_of_lines .. ")")
end

renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to current Pattern length",invoke = resize_all_non_empty_patterns_to_current_pattern_length}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 012",invoke=function() resize_all_non_empty_patterns_to(12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 016",invoke=function() resize_all_non_empty_patterns_to(016) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 024",invoke=function() resize_all_non_empty_patterns_to(024) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 032",invoke=function() resize_all_non_empty_patterns_to(032) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 048",invoke=function() resize_all_non_empty_patterns_to(048) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 064",invoke=function() resize_all_non_empty_patterns_to(064) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 096",invoke=function() resize_all_non_empty_patterns_to(96) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 128",invoke=function() resize_all_non_empty_patterns_to(128) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 192",invoke=function() resize_all_non_empty_patterns_to(192) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 256",invoke=function() resize_all_non_empty_patterns_to(256) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 384",invoke=function() resize_all_non_empty_patterns_to(384) end}
renoise.tool():add_keybinding{name="Global:Paketti:Resize all non-empty Patterns to 512",invoke=function() resize_all_non_empty_patterns_to(512) end}
-------
-- Function to copy sample settings from one sample to another
local function DuplicateSampleRangeMuteOriginalCopySampleSettings(from_sample, to_sample)
  to_sample.volume = 1.0 -- Set volume to 1.0 (0 dB) for the duplicated sample
  to_sample.panning = from_sample.panning
  to_sample.transpose = from_sample.transpose
  to_sample.fine_tune = from_sample.fine_tune
  to_sample.beat_sync_enabled = from_sample.beat_sync_enabled
  to_sample.beat_sync_lines = from_sample.beat_sync_lines
  to_sample.beat_sync_mode = from_sample.beat_sync_mode
  to_sample.oneshot = from_sample.oneshot
  to_sample.loop_release = from_sample.loop_release
  to_sample.loop_mode = from_sample.loop_mode
  to_sample.mute_group = from_sample.mute_group
  to_sample.new_note_action = from_sample.new_note_action
  to_sample.autoseek = from_sample.autoseek
  to_sample.autofade = from_sample.autofade
  to_sample.oversample_enabled = from_sample.oversample_enabled
  to_sample.interpolation_mode = from_sample.interpolation_mode
  to_sample.name = from_sample.name
end

-- Function to duplicate the selected sample range and mute the original sample
function duplicate_sample_range_and_mute_original()
  local song=renoise.song()
  local selected_sample = song.selected_sample
  if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    return
  end

  -- Get the selection range
  local selection_start, selection_end = selected_sample.sample_buffer.selection_range[1], selected_sample.sample_buffer.selection_range[2]
  if selection_start == selection_end then
    renoise.app():show_status("No selection range is defined")
    return
  end

  -- Set the original sample's volume to -INF dB
  selected_sample.volume = 0.0

  -- Create a new sample in the same instrument
  local new_sample = song.selected_instrument:insert_sample_at(#song.selected_instrument.samples + 1)

  -- Copy the sample settings from the original sample to the new one, with volume set to 1.0
  DuplicateSampleRangeMuteOriginalCopySampleSettings(selected_sample, new_sample)

  -- Copy the selected range to the new sample buffer
  local sample_buffer = selected_sample.sample_buffer
  new_sample.sample_buffer:create_sample_data(
    sample_buffer.sample_rate, 
    sample_buffer.bit_depth, 
    sample_buffer.number_of_channels, 
    selection_end - selection_start + 1
  )
  new_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy sample data
  for c = 1, sample_buffer.number_of_channels do
    for f = selection_start, selection_end do
      new_sample.sample_buffer:set_sample_data(c, f - selection_start + 1, sample_buffer:sample_data(c, f))
    end
  end
  new_sample.sample_buffer:finalize_sample_data_changes()

  -- Select the new sample
  song.selected_sample_index = #song.selected_instrument.samples
  renoise.app():show_status("Sample range duplicated and original muted")
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Duplicate Sample Range, Mute Original",invoke = duplicate_sample_range_and_mute_original}


------
-- Define the function for randomizing pitch and finetune with custom ranges
local function randomize_sample_pitch_and_finetune(random_range_pitch, random_range_finetune)
  local sample=renoise.song().selected_sample

  -- Check if a sample is selected
  if sample then
    -- Randomize the transpose value within the specified limited range
    local transpose_delta=math.random(-random_range_pitch,random_range_pitch)
    local new_transpose=math.max(-6,math.min(6,sample.transpose+transpose_delta))
    sample.transpose=new_transpose
    
    -- Randomize the fine_tune value within the full range if specified
    local fine_tune_delta=math.random(-random_range_finetune,random_range_finetune)
    local new_fine_tune=math.max(-127,math.min(127,sample.fine_tune+fine_tune_delta))
    sample.fine_tune=new_fine_tune
    
    -- Show status in Renoise
    renoise.app():show_status("Randomized Sample " .. sample.name .. " to finetune " .. new_fine_tune .. " and pitch " .. new_transpose)
  else
    renoise.app():show_status("No sample selected.")
  end
end


renoise.tool():add_keybinding{name="Global:Paketti:Randomize Selected Sample Finetune/Transpose +6/-6",invoke=function() randomize_sample_pitch_and_finetune(6,6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Selected Sample Transpose +6/-6 Finetune +127/-127",invoke=function() randomize_sample_pitch_and_finetune(6,127) end}

renoise.tool():add_midi_mapping{name="Paketti:Randomize Selected Sample Finetune/Transpose +6/-6",invoke=function() randomize_sample_pitch_and_finetune(6,6) end}
renoise.tool():add_midi_mapping{name="Paketti:Randomize Selected Sample Transpose +6/-6 Finetune +127/-127",invoke=function() randomize_sample_pitch_and_finetune(6,127) end}
----------
function DuplicateMaximizeConvertAndSave(format)
  local song=renoise.song()
  local selected_sample = song.selected_sample
  
  if selected_sample == nil or not selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No sample selected or no sample data available.")
    return
  end
  
  -- Step 1: Create a New Instrument Below the Selected Instrument Index
  local selected_instrument_index = song.selected_instrument_index
  local new_instrument = song:insert_instrument_at(selected_instrument_index + 1)
  
  if new_instrument == nil then
    renoise.app():show_error("Failed to create a new instrument.")
    return
  else
    renoise.app():show_status("New instrument created below the selected instrument.")
  end
  
  -- Set the new instrument's name to match the selected sample's name
  new_instrument.name = selected_sample.name
  
  -- Step 2: Copy the Original Sample to the New Instrument and Set Sample Name
  local new_sample = new_instrument:insert_sample_at(1)
  local original_sample_buffer = selected_sample.sample_buffer
  new_sample.name = selected_sample.name -- Copy the sample name
  
  new_sample.sample_buffer:create_sample_data(
    original_sample_buffer.sample_rate,
    original_sample_buffer.bit_depth,
    original_sample_buffer.number_of_channels,
    original_sample_buffer.number_of_frames
  )
  
  new_sample.sample_buffer:prepare_sample_data_changes()
  
  for c = 1, original_sample_buffer.number_of_channels do
    for i = 1, original_sample_buffer.number_of_frames do
      new_sample.sample_buffer:set_sample_data(c, i, original_sample_buffer:sample_data(c, i))
    end
  end
  
  new_sample.sample_buffer:finalize_sample_data_changes()
  
  if new_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Sample successfully copied to the new instrument.")
  else
    renoise.app():show_error("Failed to copy the sample to the new instrument.")
    return
  end
  
  -- Step 3: Select the New Instrument
  song.selected_instrument_index = selected_instrument_index + 1
  
  -- Step 4: Maximize the Volume (Normalize)
  local sbuf = new_sample.sample_buffer
  local highest_detected = 0
  
  for frame_idx = 1, sbuf.number_of_frames do
    if sbuf.number_of_channels == 2 then
      highest_detected = math.max(math.abs(sbuf:sample_data(1, frame_idx)), highest_detected)
      highest_detected = math.max(math.abs(sbuf:sample_data(2, frame_idx)), highest_detected)
    else
      highest_detected = math.max(math.abs(sbuf:sample_data(1, frame_idx)), highest_detected)
    end
  end
  
  if highest_detected == 0 then
    renoise.app():show_error("Normalization failed: highest detected peak is 0.")
    return
  end
  
  sbuf:prepare_sample_data_changes()
  
  for frame_idx = 1, sbuf.number_of_frames do
    if sbuf.number_of_channels == 2 then
      local normalized_sdata = sbuf:sample_data(1, frame_idx) / highest_detected
      sbuf:set_sample_data(1, frame_idx, normalized_sdata)
      normalized_sdata = sbuf:sample_data(2, frame_idx) / highest_detected
      sbuf:set_sample_data(2, frame_idx, normalized_sdata)
    else
      local normalized_sdata = sbuf:sample_data(1, frame_idx) / highest_detected
      sbuf:set_sample_data(1, frame_idx, normalized_sdata)
    end
  end
  
  sbuf:finalize_sample_data_changes()
  
  if sbuf.has_sample_data then
    renoise.app():show_status("Sample successfully normalized (maximized volume).")
  else
    renoise.app():show_error("Normalization failed.")
    return
  end
  
  -- Step 5: Convert the Sample to 16-bit
  local original_sample_rate = sbuf.sample_rate
  local original_frame_count = sbuf.number_of_frames
  local original_sample_data = {}
  
  -- Store the original sample data before creating a new 16-bit buffer
  for c = 1, sbuf.number_of_channels do
    original_sample_data[c] = {}
    for i = 1, original_frame_count do
      original_sample_data[c][i] = sbuf:sample_data(c, i)
    end
  end
  
  -- Now, create the new 16-bit buffer
  sbuf:create_sample_data(
    original_sample_rate,
    16, -- Convert to 16-bit
    sbuf.number_of_channels,
    original_frame_count
  )
  
  sbuf:prepare_sample_data_changes()
  
  -- Copy the original data into the new 16-bit buffer
  for c = 1, sbuf.number_of_channels do
    for i = 1, original_frame_count do
      sbuf:set_sample_data(c, i, original_sample_data[c][i])
    end
  end
  
  sbuf:finalize_sample_data_changes()
  
  if sbuf.has_sample_data then
    renoise.app():show_status("Sample successfully converted to 16-bit.")
  else
    renoise.app():show_error("Failed to convert the sample to 16-bit.")
    return
  end
  
  -- Step 6: Save the Sample
  local filename = renoise.app():prompt_for_filename_to_write(format, "Paketti Save Selected Sample in ." .. format .. " Format")
  
  if filename ~= "" then
    sbuf:save_as(filename, format)
    renoise.app():show_status("Saved sample as " .. format .. " in " .. filename)
  else
    renoise.app():show_error("Saving canceled.")
    return
  end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Duplicate, Maximize, 16bit, and Save as WAV",invoke=function() DuplicateMaximizeConvertAndSave("wav") end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Duplicate, Maximize, 16bit, and Save as FLAC",invoke=function() DuplicateMaximizeConvertAndSave("flac") end}
--------
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

function halve_bpm()
  local song=renoise.song()
  local current_bpm=song.transport.bpm
  local new_bpm=math.max(current_bpm/2,20)
  song.transport.bpm=new_bpm
  renoise.app():show_status("BPM halved from "..current_bpm.." to "..new_bpm)
end

function double_bpm()
  local song=renoise.song()
  local current_bpm=song.transport.bpm
  local new_bpm=math.min(current_bpm*2,999)
  song.transport.bpm=new_bpm
  renoise.app():show_status("BPM doubled from "..current_bpm.." to "..new_bpm)
end

renoise.tool():add_keybinding{name="Global:Paketti:Halve BPM",invoke=function() halve_bpm() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double BPM",invoke=function() double_bpm() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Halve BPM",invoke=function() halve_bpm() halve_bpm() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Double BPM",invoke=function() double_bpm() double_bpm() end}
-------
-- Function to detect note spacing
local function analyze_note_spacing()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No selection in pattern")
    return nil
  end

  local start_line = selection.start_line
  local end_line = selection.end_line
  local track_index = selection.start_track

  local previous_note_line = nil
  local note_spacing_counts = { [1] = 0, [2] = 0 }

  print("Analyzing note spacing in track:", track_index, "-", song:track(track_index).name)

  for line_index = start_line, end_line do
    local line = song:pattern(song.selected_pattern_index):track(track_index):line(line_index)
    local note_column = line:note_column(1)
    
    if not note_column.is_empty then
      if previous_note_line then
        local spacing=line_index - previous_note_line
        print("Note found at line:", line_index, "with spacing:", spacing, "Note:", note_column.note_string)
        if spacing == 1 or spacing == 2 then
          note_spacing_counts[spacing] = note_spacing_counts[spacing] + 1
        end
      end
      previous_note_line = line_index
    end
  end

  -- Determine dominant spacing
  if note_spacing_counts[2] > note_spacing_counts[1] then
    print("Detected note spacing: every 2nd row")
    return 2  -- Notes every 2nd row
  elseif note_spacing_counts[1] > 0 then
    print("Detected note spacing: every row")
    return 1  -- Notes every row
  else
    renoise.app():show_status("Could not determine note spacing")
    return nil
  end
end

-- Function to modify pattern for "notes every row"
local function modify_pattern_triplets()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No selection in pattern")
    return
  end

  local start_line = selection.start_line
  local end_line = selection.end_line
  local track_index = selection.start_track
  local delay_values = { "55", "AA" }  -- 66 and AA as strings
  
  local note_counter = 0
  local triplet_phase = 1

  print("Modifying pattern for notes every row in track:", track_index, "-", song:track(track_index).name)

  for line_index = start_line, end_line do
    local line = song:pattern(song.selected_pattern_index):track(track_index):line(line_index)
    local note_column = line:note_column(1)
    
    if not note_column.is_empty then
      note_counter = note_counter + 1

      if triplet_phase == 1 then
        triplet_phase = 2
        print("Line", line_index, "- No delay (start of triplet) - Note:", note_column.note_string, "Instrument:", note_column.instrument_value)

      elseif triplet_phase == 2 then
        note_column.delay_string = delay_values[1]
        triplet_phase = 3
        print("Line", line_index, "- Applied delay 66 - Note:", note_column.note_string, "Instrument:", note_column.instrument_value)

      elseif triplet_phase == 3 then
        note_column.delay_string = delay_values[2]
        triplet_phase = 1
        -- Insert an empty line after applying delay AA
        song:pattern(song.selected_pattern_index):track(track_index):line(line_index + 1):clear()
        print("Line", line_index, "- Applied delay AA and added an empty line after - Note:", note_column.note_string, "Instrument:", note_column.instrument_value)
      end
    end
  end

  renoise.app():show_status("Triplet pattern applied to every row")
end

-- Function to safely access renoise.song() only when it's valid
local function get_song()
    if renoise.song() then
        return renoise.song()
    else
        error("Renoise song is not available.")
    end
end

local function print_pattern_state(pattern_track, total_lines)
    print("Current pattern state:")
    for line_index = 1, total_lines do
        local line = pattern_track:line(line_index)
        local note_column = line:note_column(1)
        if not note_column.is_empty then
            print(string.format("Line %02d: Note: '%s', Instrument: '%02X', Delay: '%02X'",
                line_index,
                note_column.note_string,
                note_column.instrument_value,
                note_column.delay_value))
        end
    end
end

local function apply_triplet_pattern_with_shifting()
    local song = get_song()
    local pattern_track = song.selected_pattern:track(song.selected_track_index)
    local total_lines = #pattern_track.lines
    local delay_values = {0x00, 0xAA, 0x55}  -- The delay sequence 00-AA-66
    local move_down_accumulated = 0

    -- Step 1: Detect and store positions of all notes
    local note_positions = {}
    for line_index = 1, total_lines do
        local line = pattern_track:line(line_index)
        local note_column = line:note_column(1)

        if not note_column.is_empty then
            table.insert(note_positions, {
                line_index = line_index,
                note = note_column.note_string,
                instrument = note_column.instrument_string
            })
            print(string.format("Detected note '%s' at line: %d", note_column.note_string, line_index))
        end
    end

    -- Step 2: Apply triplet pattern with correct spacing and downward shifting
    for i, data in ipairs(note_positions) do
        local original_pos = data.line_index + move_down_accumulated
        local note_string = data.note
        local instrument_string = data.instrument
        local delay_value = delay_values[(i - 1) % 3 + 1]

        -- Calculate the target position based on the delay value and pattern
        local move_down = 0
        if delay_value == 0x55 then
            move_down = 1  -- Move the note down by 2 rows if the delay is 66
        elseif delay_value == 0xAA then
            move_down = 0  -- Move the note down by 1 row if the delay is AA
        elseif delay_value == 0x00 and i ~= 1 then
            move_down = 1  -- No delay; space to the next logical position
        end

        local target_position = original_pos + move_down

        if target_position > total_lines then
            print(string.format("Skipping move for note '%s' at line %d because it exceeds the pattern length.", note_string, target_position))
            break
        end

        -- Shift all subsequent lines down by `move_down` positions
        if move_down > 0 then
            for j = total_lines, target_position, -1 do
                pattern_track:line(j):copy_from(pattern_track:line(j - move_down))
                pattern_track:line(j - move_down):clear()
            end
            move_down_accumulated = move_down_accumulated + move_down
        end

        -- Set the note, instrument, and delay at the target position
        local target_line = pattern_track:line(target_position)
        target_line:note_column(1).note_string = note_string
        target_line:note_column(1).instrument_string = instrument_string
        target_line:note_column(1).delay_value = delay_value

        print(string.format("Moved note '%s' from line %d to line %d with delay %02X and instrument '%s'",
                            note_string, original_pos, target_position, delay_value, instrument_string))
    end

    renoise.app():show_status("Incremental triplet pattern applied with downward shifting successfully.")
end

-- Main function to detect note spacing and apply the appropriate triplet pattern logic
local function detect_and_apply_triplet_pattern()
    local song = get_song()
    song.selected_track.delay_column_visible = true

    local note_spacing=analyze_note_spacing()
    if note_spacing == 1 then
        modify_pattern_triplets()
    elseif note_spacing == 2 then
        apply_triplet_pattern_with_shifting()
    else
        renoise.app():show_status("Unsupported note spacing or could not detect note spacing")
    end
end

----------
renoise.tool():add_keybinding{name="Global:Paketti:Jump to Sends",invoke=function()
if renoise.song().send_track_count == 0 then
renoise.app():show_status("There are no Sends to jump to.")
else
renoise.song().selected_track_index = renoise.song().sequencer_track_count + 2
end
end}
---------
-- Function to wipe a specific note column
function wipeNoteColumn(column_number)
  local song=renoise.song()
  song.patterns[song.selected_pattern_index].tracks[song.selected_track_index].lines[song.selected_line_index].note_columns[column_number].note_string = "OFF"
  song.patterns[song.selected_pattern_index].tracks[song.selected_track_index].lines[song.selected_line_index].note_columns[column_number].instrument_string = ".."
end


function FinderShower2(plugin)
for i=2,#renoise.song().tracks[renoise.song().sequencer_track_count+1].devices do
if renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[i].short_name == plugin
then 
if renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[i].external_editor_visible then
renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[i].external_editor_visible = false
else

renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[i].external_editor_visible = true
end
else end
end
end
renoise.tool():add_keybinding{name="Global:Paketti:Master TDR Kotelnikov Show/Hide",invoke=function() FinderShower2("TDR Kotelnikov") end}

-------
function FinderShowerByPath(device_path, location)
  local track = nil
  local track_name = ""

  -- Determine the track based on the location
  if location == "master" then
    track = renoise.song().tracks[renoise.song().sequencer_track_count + 1]  -- Master track
    track_name = "Master"
    print("Debug: Master track selected.")
  elseif location == "selected_track" then
    track = renoise.song().selected_track  -- Selected track
    track_name = "Selected Track"
    print("Debug: Selected track selected.")
  end

  if not track then
    print("Debug: Error - Track not found!")
    renoise.app():show_status("Error: Track not found!")
    return
  else
    print("Debug: Track found - " .. track_name)
  end

  -- Try to find the device on the track using the device_path
  local device_found = false
  for i = 2, #track.devices do
    print("Debug: Checking device: " .. track.devices[i].device_path)
    if track.devices[i].device_path == device_path then
      print("Debug: Device found on the track.")

      -- Check if the device has an external editor
      if track.devices[i].external_editor_available then
        -- Toggle the external editor visibility
        track.devices[i].external_editor_visible = not track.devices[i].external_editor_visible
        print("Debug: Toggling external editor visibility for " .. track.devices[i].name)
      else
        -- No external editor available, toggle is_maximized
        track.devices[i].is_maximized = not track.devices[i].is_maximized
        renoise.app():show_status("No external editor for Device: " .. track.devices[i].name .. " - Toggled Maximized View.")
        print("Debug: No external editor for " .. track.devices[i].name .. " - Toggled is_maximized.")
      end

      device_found = true
      break
    end
  end

  -- If the device is not found, and the preference to auto-load is set to true, add the device
  if not device_found then
    print("Debug: Device not found on track.")

    if preferences.UserPreferences.userPreferredDeviceLoad then
      print("Debug: Auto-load preference is enabled.")

      -- Find the full name of the device to add it correctly
      for _, device_info in ipairs(renoise.song().selected_track.available_device_infos) do
        print("Debug: Checking available device: " .. device_info.path)
        if device_info.path == device_path then
          print("Debug: Inserting device at the end of the device chain.")
          -- Insert the device at the end of the track's device chain
          local new_device = track:insert_device_at(device_info.path, #track.devices + 1)

          -- Check if the newly inserted device has an external editor
          if new_device.external_editor_available then
            -- Open the external editor for the newly added device
            new_device.external_editor_visible = true
            new_device.is_maximized = false
            renoise.app():show_status("Device " .. new_device.name .. " was added to " .. track_name .. " and its editor is now visible.")
          else
            -- Toggle is_maximized if no external editor is available
         --   new_device.is_maximized = not new_device.is_maximized
            renoise.app():show_status("Device " .. new_device.name .. " was added to " .. track_name .. ", but it has no external editor. Maximized view toggled.")
            print("Debug: No external editor for " .. new_device.name .. " - Toggled is_maximized.")
          end

          return
        end
      end

      -- If no matching device is found in the available_device_infos, show error
      print("Debug: Error - Device not found in available_device_infos.")
      renoise.app():show_status("Error: Device " .. device_path .. " could not be found to load.")
    else
      print("Debug: Auto-load is disabled, showing 'not found' message.")
      -- Display the normal error message if not found and auto-load is off
      local formatted_short_name = "<Unknown Device>"
      for _, device_info in ipairs(renoise.song().selected_track.available_device_infos) do
        if device_info.path == device_path then
          -- Format the device short_name with its type prefix
          if device_info.path:find("/AU/") then
            formatted_short_name = "AU: " .. device_info.short_name
          elseif device_info.path:find("/VST3/") then
            formatted_short_name = "VST3: " .. device_info.short_name
          elseif device_info.path:find("/VST/") then
            formatted_short_name = "VST: " .. device_info.short_name
          elseif device_info.path:find("/Native/") then
            formatted_short_name = "Native: " .. device_info.short_name
          elseif device_info.path:find("/LADSPA/") then
            formatted_short_name = "LADSPA: " .. device_info.short_name
          elseif device_info.path:find("/DSSI/") then
            formatted_short_name = "DSSI: " .. device_info.short_name
          else
            formatted_short_name = device_info.short_name  -- Default to just the short_name
          end
          break
        end
      end

      -- Display the error message with the formatted device name
      renoise.app():show_status("The Device " .. formatted_short_name .. " was not found on " .. track_name)
    end
  else
    print("Debug: Device found and handled.")
  end
end

-- Load preferences on startup and print debug information
function PakettiUserPreferencesLoadPreferences()
  if io.exists("preferences.xml") then
    preferences:load_from("preferences.xml")
    renoise.app():show_status("User Preferences loaded.")

    -- Print loaded preferences for debugging
    for i = 1, 10 do
      local device_pref = preferences.UserPreferences["userPreferredDevice" .. string.format("%02d", i)].value
      
      -- Find the corresponding device from available devices
      local device_name = "<None>"
      for _, device_info in ipairs(renoise.song().selected_track.available_device_infos) do
        if device_info.path == device_pref then
          device_name = device_info.short_name
          -- Add formatting if necessary (like AU, VST, etc.)
          if device_info.path:find("/AU/") then
            device_name = "AU: " .. device_info.short_name
          elseif device_info.path:find("/VST3/") then
            device_name = "VST3: " .. device_info.short_name
          elseif device_info.path:find("/VST/") then
            device_name = "VST: " .. device_info.short_name
          elseif device_info.path:find("/Native/") then
            device_name = "Native: " .. device_info.short_name
          elseif device_info.path:find("/LADSPA/") then
            device_name = "LADSPA: " .. device_info.short_name
          elseif device_info.path:find("/DSSI/") then
            device_name = "DSSI: " .. device_info.short_name
          end
          break
        end
      end

      -- Debug print the loaded device for this slot
      print("Loaded Slot " .. string.format("%02d", i) .. ": " .. device_name .. " (" .. device_pref .. ")")
    end
  else
    renoise.app():show_status("No preferences file found, loading defaults.")
  end
end

-- Function to save user preferences and show debug output
function PakettiUserPreferenceSavePreferences(device_dropdowns, available_devices)
  for i = 1, #device_dropdowns do
    -- Get the selected device's path based on the dropdown value (index)
    local selected_device = available_devices[device_dropdowns[i].value]
    
    -- Save the device path in user preferences
    preferences.UserPreferences["userPreferredDevice" .. string.format("%02d", i)].value = selected_device.path
    
    -- Print debug information for saved devices
    print("Saving Slot " .. string.format("%02d", i) .. ": " .. selected_device.short_name .. " (" .. selected_device.path .. ")")
  end

  -- Persist the updated preferences to the preferences.xml file
  PakettiUserPreferencesSaveToFile()  -- Correct function name
  renoise.app():show_status("User preferences saved successfully.")
end

-- Separate function to handle saving to the preferences.xml file
function PakettiUserPreferencesSaveToFile()
  preferences:save_as("preferences.xml")
end

-- Variable to track the dialog state
local dialog

-- Variables to store the dropdowns and available devices globally
local device_dropdowns = {}
local available_devices = {}

local function my_userPrefskeyhandler_func(dialog_ref, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    PakettiUserPreferenceSavePreferences(device_dropdowns, available_devices)  -- Save preferences before closing
    dialog_ref:close()
    dialog = nil
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    return nil
else
    return key  -- Allow other key events to be handled as usual
  end
end

function pakettiUserPreferencesShowerDialog()
  local vb = renoise.ViewBuilder()

  -- If the dialog is already visible, close it and return focus to the pattern editor
  if dialog and dialog.visible then
    PakettiUserPreferenceSavePreferences(device_dropdowns, available_devices)  -- Save preferences before closing
    dialog:close()
    dialog = nil
    renoise.app():show_status("Preferences dialog closed.")
    
    -- Return focus to the active middle frame after closing
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    return
  end

  -- Load preferences when opening the dialog
  PakettiUserPreferencesLoadPreferences()

  -- Create the 10 device slots
  device_dropdowns = {}  -- Reset the dropdowns list
  available_devices = {}  -- Reset the available devices list
  local rows = {}

  -- Group devices by type and sort them alphabetically (case-insensitive)
  local grouped_devices = {
    AU = {},
    VST = {},
    VST3 = {},
    LADSPA = {},
    DSSI = {},
    Native = {},
    Other = {}
  }

  for _, device_info in ipairs(renoise.song().selected_track.available_device_infos) do
    local formatted_device = { short_name = device_info.short_name, path = device_info.path }

    -- Categorize the device based on its type and add the formatted device to the respective table
    if device_info.path:find("/AU/") then
      table.insert(grouped_devices.AU, formatted_device)
    elseif device_info.path:find("/VST3/") then
      table.insert(grouped_devices.VST3, formatted_device)
    elseif device_info.path:find("/VST/") then
      table.insert(grouped_devices.VST, formatted_device)
    elseif device_info.path:find("/Native/") then
      table.insert(grouped_devices.Native, formatted_device)
    elseif device_info.path:find("/LADSPA/") then
      table.insert(grouped_devices.LADSPA, formatted_device)
    elseif device_info.path:find("/DSSI/") then
      table.insert(grouped_devices.DSSI, formatted_device)
    else
      table.insert(grouped_devices.Other, formatted_device)
    end
  end

  -- Sort devices alphabetically within each category (case-insensitive)
  for _, device_list in pairs(grouped_devices) do
    table.sort(device_list, function(a, b)
      return string.lower(a.short_name) < string.lower(b.short_name)
    end)
  end

  -- Concatenate sorted device lists into the final available devices
  local function insert_devices(device_list, prefix)
    for _, device in ipairs(device_list) do
      table.insert(available_devices, { short_name = prefix .. device.short_name, path = device.path })
    end
  end

  insert_devices(grouped_devices.AU, "AU: ")
  insert_devices(grouped_devices.VST, "VST: ")
  insert_devices(grouped_devices.VST3, "VST3: ")
  insert_devices(grouped_devices.LADSPA, "LADSPA: ")
  insert_devices(grouped_devices.DSSI, "DSSI: ")
  insert_devices(grouped_devices.Native, "Native: ")
  insert_devices(grouped_devices.Other, "")  -- No prefix for others

  -- Add <None> to the list at the beginning
  table.insert(available_devices, 1, { short_name = "<None>", path = "<None>" })

  -- Create a list of device names (short_name) for the dropdown
  local device_names = {}
  for _, device in ipairs(available_devices) do
    table.insert(device_names, device.short_name)
  end

  -- Create device dropdowns using loaded preferences
  for i = 1, 10 do
    local device_pref = preferences.UserPreferences["userPreferredDevice" .. string.format("%02d", i)].value

    -- Find the correct index for the saved device_pref (path)
    local popup_value = 1  -- Default to "<None>"
    for index, device in ipairs(available_devices) do
      if device.path == device_pref then
        popup_value = index
        break
      end
    end

    -- Create the dropdown with the correct value (index of the device)
    device_dropdowns[i] = vb:popup{
      items = device_names,  -- Use the extracted device names list
      value = popup_value,   -- Set the popup to the correct index
      width=200
    }

    -- Add to rows
    table.insert(rows, vb:row{
      vb:text{text=string.format("%02d:", i), font = "bold", style = "strong" },
      device_dropdowns[i],
      vb:text{text="Show/Hide:", font="bold", style="strong" },
      vb:button{
        text="Selected Track",
        notifier=function() 
          FinderShowerByPath(available_devices[device_dropdowns[i].value].path, "selected_track")
          -- Return focus to the active middle frame
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:button{
        text="Master",
        notifier=function() 
          FinderShowerByPath(available_devices[device_dropdowns[i].value].path, "master")
          -- Return focus to the active middle frame
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      },
      vb:button{
        text="Clear",
        notifier=function() 
          device_dropdowns[i].value = 1
          -- Return focus to the active middle frame
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
      }
    })
  end

  -- Add Save and Close buttons
  table.insert(rows, vb:row{
    vb:button{
      text="Save",
      notifier=function()
        PakettiUserPreferenceSavePreferences(device_dropdowns, available_devices)
        -- Return focus to the active middle frame
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      end
    },
    vb:button{
      text="Close",
      notifier=function()
        PakettiUserPreferenceSavePreferences(device_dropdowns, available_devices)
        dialog:close()
        dialog = nil  -- Clear the dialog reference when it's closed
        
        -- Return focus to the active middle frame
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      end
    }
  })
  dialog = renoise.app():show_custom_dialog("Paketti User Preferences for Show/Hide Slots",vb:column(rows),my_userPrefskeyhandler_func)

  -- After opening the dialog, set the focus back to the active middle frame
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end


renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide User Preference Devices Master Dialog...",invoke=function() pakettiUserPreferencesShowerDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Open User Preferences Dialog...",invoke=function() pakettiUserPreferencesShowerDialog() end}

for i = 1, 10 do
  local slot = string.format("%02d", i)
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:SlotShow..:Show/Hide Slot " .. slot .. " on Master",
    invoke=function() FinderShowerByPath(preferences.UserPreferences["userPreferredDevice" .. slot].value, "master") end
  }

  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:SlotShow..:Show/Hide Slot " .. slot .. " on Selected Track",
    invoke=function() FinderShowerByPath(preferences.UserPreferences["userPreferredDevice" .. slot].value, "selected_track") end
  }

  renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide Slot " .. slot .. " on Master",
    invoke=function() FinderShowerByPath(preferences.UserPreferences["userPreferredDevice" .. slot].value, "master") end
  }

  renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide Slot " .. slot .. " on Selected Track",
    invoke=function() FinderShowerByPath(preferences.UserPreferences["userPreferredDevice" .. slot].value, "selected_track") end
  }
renoise.tool():add_midi_mapping{name="Paketti:Show/Hide Slot " .. slot .. " on Master",
  invoke=function(message)
    if message:is_trigger() then
      FinderShowerByPath(preferences.UserPreferences["userPreferredDevice" .. slot].value, "master")
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Show/Hide Slot " .. slot .. " on Selected Track",
  invoke=function(message)
    if message:is_trigger() then
      FinderShowerByPath(preferences.UserPreferences["userPreferredDevice" .. slot].value, "selected_track")
    end
  end
}
end

-- Add debug print for loading and saving the preferences
function PakettiUserPreferencesSaveSelectedDevice(slot, device_name)
  print("*** Debug: Saving Slot " .. slot .. " with Device: " .. device_name .. " ***")
  preferences.UserPreferences["userPreferredDevice" .. string.format("%02d", slot)].value = device_name
  PakettiUserPreferencesSavePreferences()

  -- Debug print of all saved slots
  print("*** Debug: Saved Preferences ***")
  for i = 1, 10 do
    print("Slot " .. string.format("%02d", i) .. ": " .. preferences.UserPreferences["userPreferredDevice" .. string.format("%02d", i)].value)
  end
  print("*** End Debug ***")
end
------
function setSelectedSampleToNoSampleFXChain()
renoise.song().instruments[renoise.song().selected_instrument_index].samples[renoise.song().selected_sample_index].device_chain_index = 0
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample FX Group to None",invoke=function() setSelectedSampleToNoSampleFXChain() end}
------------
function PakettiSetSelectedTrackVolumePostFX(dB_change)
  local currVol_dB = math.lin2db(renoise.song().selected_track.postfx_volume.value)
  local newVol_dB = currVol_dB + dB_change

  if newVol_dB < math.infdb then
    newVol_dB = math.infdb
    renoise.app():show_status("Selected Track PostFX Volume cannot go lower than -inf dB, setting to silence.")
  elseif newVol_dB > 3 then
    newVol_dB = 3
    renoise.app():show_status("Selected Track PostFX Volume cannot go higher than 3 dB, setting to 3 dB.")
  end

  renoise.song().selected_track.postfx_volume.value = math.db2lin(newVol_dB)
end

renoise.tool():add_keybinding{name="Global:Paketti:Change Selected Track Volume by +0.1dB",invoke=function() PakettiSetSelectedTrackVolumePostFX(0.1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Change Selected Track Volume by +0.5dB",invoke=function() PakettiSetSelectedTrackVolumePostFX(0.5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Change Selected Track Volume by +1dB",invoke=function() PakettiSetSelectedTrackVolumePostFX(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Change Selected Track Volume by -0.1dB",invoke=function() PakettiSetSelectedTrackVolumePostFX(-0.1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Change Selected Track Volume by -0.5dB",invoke=function() PakettiSetSelectedTrackVolumePostFX(-0.5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Change Selected Track Volume by -1dB",invoke=function() PakettiSetSelectedTrackVolumePostFX(-1) end}
---
function PakettiLoopSet(Mode)
if renoise.song().selected_sample == nil then
renoise.app():show_status("There is no selected sample.")
return
end

if Mode == "Percussion" then
renoise.song().selected_sample.beat_sync_mode=2
else if Mode == "Texture" then
renoise.song().selected_sample.beat_sync_mode=3
end
end
print("HEEY")
renoise.song().selected_sample.autoseek=true
renoise.song().selected_sample.beat_sync_enabled=true
renoise.song().selected_sample.loop_mode=2
renoise.song().selected_sample.mute_group=1

end

renoise.tool():add_keybinding{name="Global:Paketti:Loop Set Percussion",invoke=function() PakettiLoopSet("Percussion")end}

renoise.tool():add_keybinding{name="Global:Paketti:Loop Set Texture",invoke=function() PakettiLoopSet("Texture")end}

-------
-- SampleSelector logic
function SampleSelector(step)
  local song=renoise.song()
  local instrument=song.selected_instrument
  local num_samples=#instrument.samples
  local current_index=song.selected_sample_index

  if num_samples == 0 then
    renoise.app():show_status("There's no sample in this Instrument, doing nothing.")
    return
  end

  local new_index=current_index+step

  if new_index < 1 then
    renoise.app():show_status("You are on the first sample, doing nothing.")
  elseif new_index > num_samples then
    renoise.app():show_status("You are on the last sample, doing nothing.")
  else
    song.selected_sample_index=new_index
    local sample_name = instrument.samples[new_index].name
    local formatted_index = string.format("%03d", new_index)
    renoise.app().window.active_middle_frame = sampleEditor
    renoise.app():show_status("Selected Sample " .. formatted_index .. ": " .. sample_name)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Select Sample Next",invoke=function()SampleSelector(1)end}
renoise.tool():add_keybinding{name="Global:Paketti:Select Sample Previous",invoke=function()SampleSelector(-1)end}
renoise.tool():add_midi_mapping{name="Paketti:Select Sample Next",invoke=function(message)if message:is_trigger()then SampleSelector(1)end end}
renoise.tool():add_midi_mapping{name="Paketti:Select Sample Previous",invoke=function(message)if message:is_trigger()then SampleSelector(-1)end end}


function SampleSelectorMIDI(midi_value)
  local song=renoise.song()
  local instrument = song.selected_instrument
  local num_samples = #instrument.samples
  
  -- Do nothing if there's only one sample or no samples
  if num_samples <= 1 then
    return
  end
  
  -- Map MIDI value (0-127) to sample index (1-num_samples)
  local new_index = math.floor((midi_value / 127) * (num_samples - 1)) + 1
  
  -- Only update if the index actually changed
  if new_index ~= song.selected_sample_index then
    song.selected_sample_index = new_index
    local sample_name = instrument.samples[new_index].name
    local formatted_index = string.format("%03d", new_index)
    renoise.app().window.active_middle_frame = sampleEditor
    renoise.app():show_status("Selected Sample " .. formatted_index .. ": " .. sample_name)
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Select Sample x[Knob]",invoke=function(message) if message:is_abs_value() then SampleSelectorMIDI(message.int_value) end end}

---

function PakettiSerialOutputRoutings(is_non_continual, noMaster, includeMaster)
  local availOut = renoise.song().selected_track.available_output_routings
  local seq_count = renoise.song().sequencer_track_count
  local send_count = renoise.song().send_track_count

  -- Determine the valid range of output routings based on noMaster flag
  local start_index = noMaster and 2 or 1
  local num_routings = #availOut - start_index + 1

  -- Ensure there are enough routings based on the configuration
  if num_routings < 1 then
    renoise.app():show_status("Not enough available output routings to apply the configuration!")
    return
  end

  local track_index = 1

  -- Function to assign output routings in sequence
  local function assign_routing(i)
    local routing_index
    if is_non_continual then
      -- Non-Continual mode: assign the last routing after exceeding available outputs
      routing_index = track_index + start_index - 1
      if routing_index > #availOut then routing_index = #availOut end
    else
      -- Continual mode: wrap around with modulo
      routing_index = ((track_index - 1) % num_routings) + start_index
    end
    renoise.song().tracks[i].output_routing = availOut[routing_index]
    track_index = track_index + 1
  end

  -- Loop through the sequencer tracks (normal tracks)
  for i = 1, seq_count do
    assign_routing(i)
  end

  -- Handle the Master track
  if includeMaster then
    assign_routing(seq_count + 1)
  else
    -- Assign Master track to the last available routing if not part of the sequence
    renoise.song().tracks[seq_count + 1].output_routing = availOut[#availOut]
  end

  -- Loop through the send tracks
  for i = 1, send_count do
    assign_routing(seq_count + 1 + i)
  end

  -- Print the output routings for all tracks (for debugging)
  for i = 1, seq_count + send_count + 1 do oprint(renoise.song().tracks[i].output_routing) end
end

renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Skip Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(true, true, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Skip Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(false, true, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Include Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(true, false, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Include Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(false, false, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Skip Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(true, true, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Skip Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(false, true, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Include Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(true, false, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Include Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(false, false, true) end}
------
function resetOutputRoutings()
local calculation = renoise.song().sequencer_track_count + 1
local calculationSends = calculation + renoise.song().send_track_count

for i=1,renoise.song().sequencer_track_count do
renoise.song().tracks[i].output_routing="Master"
end

for i=calculation+1,calculationSends do
renoise.song().tracks[i].output_routing="Master"
end
rprint (renoise.song().tracks[calculation].available_output_routings)
renoise.song().tracks[calculation].output_routing=renoise.song().tracks[calculation].available_output_routings[1]

end

renoise.tool():add_keybinding{name="Global:Paketti:Reset Output Routings to Master",invoke=function() resetOutputRoutings() end}


function PlayCurrentLineAdvance(direction)
  local s=renoise.song()
  local t=s.transport
  local curr_pos=s.transport.edit_pos
  local num_lines=s.selected_pattern.number_of_lines
  local step=t.edit_step
    
  renoise.song().transport.follow_player = false
  
  -- Play the current line
  t:start_at(s.selected_line_index)

  -- Small delay to ensure the note is triggered
  local start_time = os.clock()
  while (os.clock() - start_time < 0.05) do
    -- Minimum delay to allow the line to play correctly
  end
  
  -- Stop playback immediately after playing the line
  t:stop()
  
  -- Adjust the selected line index based on the direction
  if direction == 1 then
    -- Forward movement
    if s.selected_line_index + direction > num_lines then
      s.selected_line_index = 1
    else
      s.selected_line_index = s.selected_line_index + direction
    end
  elseif direction == -1 then
    -- Backward movement
    if s.selected_line_index + direction < 1 then
      s.selected_line_index = num_lines
    else
      s.selected_line_index = s.selected_line_index + direction
    end
  elseif direction == "random" then
      s.selected_line_index = math.random(1, renoise.song().selected_pattern.number_of_lines)
  end
end

-- Key bindings for forward and backward movement
renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line&Step Forwards",invoke=function() PlayCurrentLineAdvance(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line&Step Backwards",invoke=function() PlayCurrentLineAdvance(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line&Step Random",invoke=function() PlayCurrentLineAdvance("random") end}

function PakettiDeviceBypass(number,state)
local number = number +1
if state == "toggle" then
if renoise.song().selected_track.devices[number].is_active 
then  renoise.song().selected_track.devices[number].is_active = false
return 
else renoise.song().selected_track.devices[number].is_active = true return 
end
end
if state == "enable" then renoise.song().selected_track.devices[number].is_active=true end
if state == "disable" then renoise.song().selected_track.devices[number].is_active=false end

end

for i=1,34 do
  local formatted_number=string.format("%02d",i)
  renoise.tool():add_keybinding{name="Global:Paketti:Device Control "..formatted_number.. " (Enable)",invoke=function() PakettiDeviceBypass(i,"enable") end}
  renoise.tool():add_keybinding{name="Global:Paketti:Device Control "..formatted_number .." (Disable)",invoke=function() PakettiDeviceBypass(i,"disable") end}
  renoise.tool():add_keybinding{name="Global:Paketti:Device Control "..formatted_number .. " (Toggle)",invoke=function() PakettiDeviceBypass(i,"toggle") end}
  renoise.tool():add_midi_mapping{name="Paketti:Device Control "..formatted_number.. " (Enable)",invoke=function(message) if message:is_trigger() then PakettiDeviceBypass(i,"enable") end end}
  renoise.tool():add_midi_mapping{name="Paketti:Device Control "..formatted_number .." (Disable)",invoke=function(message) if message:is_trigger() then PakettiDeviceBypass(i,"disable") end end}
  renoise.tool():add_midi_mapping{name="Paketti:Device Control "..formatted_number .. " (Toggle)",invoke=function(message) if message:is_trigger() then PakettiDeviceBypass(i,"toggle") end end}  
end
------------
-- Global variable to store the last selected line
local last_selected_line = nil

function setRandomLine(step)
  local num_lines = renoise.song().selected_pattern.number_of_lines
  local random_line

  -- Debug print: Log the number of lines in the current pattern
  print("Number of lines in pattern: " .. num_lines)

  -- If step is nil, treat it as fully random
  if step == nil then
    step = 1
  end

  -- Check if the step is a string (like "LPB") or a number
  if step == "lpb" then
    -- Use the actual LPB value from the transport
    step = renoise.song().transport.lpb
  end

  -- Validate the step value (ensure it's a number)
--  step = tonumber(step)
  if not step then
    print("Invalid step value provided.")
    return
  end

  -- Handle the case where the step value (LPB or numeric) is too high for the pattern length
  if step >= num_lines then
    print("LPB is too high for this pattern (LPB: " .. step .. ", Pattern Length: " .. num_lines .. ")")
    return
  end

  -- Repeat the line selection until a new line (different from last) is found
  repeat
    -- Random line must be a multiple of step + 1
    local max_multiplier = math.floor((num_lines - 1) / step)
    local random_multiplier = math.random(0, max_multiplier)
    random_line = 1 + step * random_multiplier
    -- Debug print: Show step/LPB information
    print("Step: " .. step .. " | Max multiplier: " .. max_multiplier .. " | Random multiplier: " .. random_multiplier .. " | Resulting line: " .. random_line)

  until random_line ~= last_selected_line -- Keep selecting until we find a new line

  -- Ensure the random line is valid
  random_line = math.min(random_line, num_lines)
  print("Final line selected: " .. random_line)

  -- Store the current selected line to compare next time
  last_selected_line = random_line

  -- Check if follow_player is on or off
  if not renoise.song().transport.follow_player then
    -- If follow_player is off, just set the line index and don't start playing
    renoise.song().selected_line_index = random_line
    print("Follow player is off. Line selected: " .. random_line)
  else
    -- If follow_player is on, move to the selected line and start playing
    renoise.song().transport:start_at(random_line)
    print("Follow player is on. Starting at line: " .. random_line)
  end
end




renoise.tool():add_midi_mapping{name="Paketti:Play at Random Line in Current Pattern",invoke=function(message)
  if message:is_trigger() or message:is_abs_value() then setRandomLine(1) end
end}
renoise.tool():add_keybinding{name="Global:Paketti:Play at Random Line in Current Pattern",invoke=function()
  setRandomLine(1)
end}

renoise.tool():add_midi_mapping{name="Paketti:Play at Random Line in Current Pattern 2",invoke=function(message)
  if message:is_trigger() or message:is_abs_value() then setRandomLine(2) end
end}

renoise.tool():add_keybinding{name="Global:Paketti:Play at Random Line in Current Pattern 2",invoke=function() setRandomLine(2) end}

renoise.tool():add_midi_mapping{name="Paketti:Play at Random Line in Current Pattern 4",invoke=function(message)
  if message:is_trigger() or message:is_abs_value() then setRandomLine(4) end
end}

renoise.tool():add_keybinding{name="Global:Paketti:Play at Random Line in Current Pattern 4",invoke=function()
  setRandomLine(4) end}

renoise.tool():add_midi_mapping{name="Paketti:Play at Random Line in Current Pattern LPB",invoke=function(message)
  if message:is_trigger() or message:is_abs_value()then setRandomLine("lpb") end end}
renoise.tool():add_keybinding{name="Global:Paketti:Play at Random Line in Current Pattern LPB",invoke=function() setRandomLine("lpb") end}



function playAtRow(number)
if number > renoise.song().selected_pattern.number_of_lines then
renoise.app():show_status("There is no such row " .. number .. " in the selected pattern, which has " .. renoise.song().selected_pattern.number_of_lines .. " lines, doing nothing.")
elseif not renoise.song().transport.playing then
  local s=renoise.song()
  local t=s.transport
  local curr_pos=s.transport.edit_pos
  local num_lines=s.selected_pattern.number_of_lines
  local step=t.edit_step
    
  renoise.song().transport.follow_player = false
  
  -- Play the current line
  t:start_at(number)

  -- Small delay to ensure the note is triggered
  local start_time = os.clock()
  while (os.clock() - start_time < 0.05) do
    -- Minimum delay to allow the line to play correctly
  end
  
  -- Stop playback immediately after playing the line
  t:stop()
renoise.song().selected_line_index=number
return
else


renoise.song().transport:start_at(number)

end
end

for i=0,511 do
local formatnumber = string.format("%03d",i)
local hexnumber = string.format("%03X", i)
renoise.tool():add_keybinding{name="Global:Paketti:Play at Row " .. formatnumber .. " (" .. hexnumber .. ")",invoke=function()
playAtRow(i+1) end}
renoise.tool():add_midi_mapping{name="Paketti:Play at Row " .. formatnumber .. " (" .. hexnumber .. ")",invoke=function()
playAtRow(i+1) end}
end
---------
local dialog = nil
local vb = renoise.ViewBuilder()
local global_slider_width=20
local global_slider_height = 100
local sliders = {volume={}, delay={}, panning={}}
local loop_values = {volume=16, delay=16, panning=16}
local auto_grab_enabled = false  -- Default value for auto-grab checkbox

-- Add at the top of the file, after variable declarations
local debug_print = true -- Control status messages


function global_shift_left()
  shift_row("volume", "left", false) -- Don't print status for individual shifts
  shift_row("delay", "left", false)
  shift_row("panning", "left", false)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("All patterns shifted left!")
end

function global_shift_right()
  shift_row("volume", "right", false) -- Don't print status for individual shifts
  shift_row("delay", "right", false)
  shift_row("panning", "right", false)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("All patterns shifted right!")
end

function closeVDP_dialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
  end
end

-- Function to check if selected track is a normal track (not Group, Send, or Master)
function is_normal_track()
  local track_type = renoise.song().selected_track.type
  return track_type == renoise.Track.TRACK_TYPE_SEQUENCER -- Normal track
end

-- Show error message when the wrong type of track is selected
function handle_invalid_track()
  renoise.app():show_status("Please select a Track, not a Group, Send or Master, doing nothing.")
end

function print_row(slider_set, track_column, show_status)
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local track_index = song.selected_track_index
  local lines = pattern.number_of_lines

  -- Make the appropriate column visible
  song.selected_track[track_column .. "_column_visible"] = true

  -- Define value range caps
  local value_cap = {
    volume = 128,  -- 00-80 hex, capped at 128 decimal
    delay = 256,   -- 00-FF hex, capped at 255
    panning = 128  -- 00-80 hex, capped at 128 decimal
  }

  for line = 1, lines do
    local index = (line - 1) % loop_values[slider_set] + 1
    local slider_value = sliders[slider_set][index].value

    -- Retrieve the note column
    local note_column = renoise.song().selected_pattern.tracks[track_index]:line(line):note_column(1)

    -- Assign the value based on the slider set (volume, delay, or panning)
    if slider_set == "volume" then
      note_column.volume_value = math.min(math.floor(slider_value * value_cap.volume), 128)
    elseif slider_set == "delay" then
      note_column.delay_value = math.min(math.floor(slider_value * value_cap.delay), 255)
    elseif slider_set == "panning" then
      note_column.panning_value = math.min(math.floor(slider_value * value_cap.panning), 128)
    end
  end

  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  
  -- Only show status message if requested
  if show_status ~= false then
    renoise.app():show_status(string.upper(string.sub(slider_set,1,1)) .. string.sub(slider_set,2) .. " sliders printed to pattern!")
  end
end


function print_all()
  print_row("volume", "volume")
  print_row("delay", "delay")
  print_row("panning", "panning")
  renoise.app().window.active_middle_frame = 1
end

-- Reset row values to default (volume=255, delay=00, panning=40)
function reset_row(slider_set)
  local default_value = {
    volume = 1,     -- Volume reset to 255 (1 in normalized range)
    delay = 0,      -- Delay reset to 00 (0 in normalized range)
    panning = 0.5   -- Panning reset to 40 (0.5 in normalized range)
  }

  for _, slider in ipairs(sliders[slider_set]) do
    slider.value = default_value[slider_set]
  end
end

-- Randomize slider values for a given row and print afterward
-- Randomize slider values for a given row considering loop_values and print afterward
function randomize_row(slider_set)
  local range_max = {
    volume = 128,  -- 00-80 hex range for volume
    delay = 255,   -- 00-FF hex range for delay
    panning = 128  -- 00-80 hex range for panning, centered at 64
  }
  
  local steps = loop_values[slider_set]
  if steps < 1 then steps = 1 end  -- Ensure at least one step
  
  local step_values = {}
  
  -- Generate random values for each unique step
  for i = 1, steps do
    step_values[i] = math.random(0, range_max[slider_set]) / range_max[slider_set] -- Normalize to 0-1 range
  end
  
  -- Assign the step values cyclically to all sliders
  for i = 1, #sliders[slider_set] do
    local step_index = ((i - 1) % steps) + 1
    sliders[slider_set][i].value = step_values[step_index]
  end

  print_row(slider_set, slider_set)
end
-- Randomize all sliders (volume, delay, panning) and print afterward
function randomizenongroovebox_all()
  randomize_row("volume")
  randomize_row("delay")
  randomize_row("panning")
  renoise.app().window.active_middle_frame = 1
end

function shift_row(slider_set, direction, show_status)
  local slider_vals = {}
  
  for _, slider in ipairs(sliders[slider_set]) do
    table.insert(slider_vals, slider.value)
  end

  if direction == "left" then
    local first_value = table.remove(slider_vals, 1)
    table.insert(slider_vals, first_value)
  elseif direction == "right" then
    local last_value = table.remove(slider_vals)
    table.insert(slider_vals, 1, last_value)
  end

  for i, slider in ipairs(sliders[slider_set]) do
    slider.value = slider_vals[i]
  end

  -- Print after shifting
  print_row(slider_set, slider_set, show_status)
end

-- Add this flag at the top of your file with other global variables
local is_receiving = false

function receive_row(slider_set, track_column, update_pattern)
  -- Don't set is_receiving here, let the caller handle it
  
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local track_index = song.selected_track_index
  local lines = pattern.number_of_lines

  -- Read ALL available lines from the pattern, up to 16
  for line = 1, math.min(lines, 16) do
    local note_column = renoise.song().selected_pattern.tracks[track_index]:line(line):note_column(1)

    local value
    if slider_set == "volume" then
      value = math.min(note_column.volume_value / 128, 1) -- Normalize and cap at 1
    elseif slider_set == "delay" then
      value = math.min(note_column.delay_value / 256, 1) -- Normalize and cap at 1
    elseif slider_set == "panning" then
      -- If panning value is 0 or 255, set it to 0.5 (middle, which is 40 in hex)
      value = (note_column.panning_value == 0 or note_column.panning_value == 255) and 0.5 or math.min(note_column.panning_value / 128, 1)
    end

    -- Update the slider value without triggering pattern updates
    sliders[slider_set][line].value = value
  end
  
  -- Don't set is_receiving = false here
  
  -- Only update pattern if explicitly requested (which should be NEVER for receive functions)
  if update_pattern then
    print_row(slider_set, slider_set)
  else
    renoise.app():show_status(string.upper(string.sub(slider_set,1,1)) .. string.sub(slider_set,2) .. " sliders received from pattern!")
  end
end


-- Fix global_receive to only update sliders without writing to pattern
function global_receive()
  if not is_normal_track() then
    handle_invalid_track()
    return
  end
  
  -- Temporarily disable slider notifiers
  local old_notifiers = {}
  for slider_set, slider_array in pairs(sliders) do
    old_notifiers[slider_set] = {}
    for i, slider in ipairs(slider_array) do
      old_notifiers[slider_set][i] = slider.notifier
      slider.notifier = nil
    end
  end
  
  -- Receive values for each slider set
  receive_row("volume", "volume", false)
  receive_row("delay", "delay", false)
  receive_row("panning", "panning", false)
  
  -- Restore slider notifiers
  for slider_set, slider_array in pairs(sliders) do
    for i, slider in ipairs(slider_array) do
      slider.notifier = old_notifiers[slider_set][i]
    end
  end
  
  renoise.app():show_status("All sliders updated from pattern!")
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Automatically receive current values when opening the dialog
-- Modify the auto_receive_all function similarly
function auto_receive_all()
  is_receiving = true
  
  if not is_normal_track() then
    handle_invalid_track()
    is_receiving = false
    return
  end

  receive_row("volume", "volume", false)
  receive_row("delay", "delay", false)
  receive_row("panning", "panning", false)
  
  is_receiving = false
end

-- Observe track changes and auto-update if auto-grab is enabled
function observe_track_changes()
  renoise.song().selected_track_observable:add_notifier(function()
    if auto_grab_enabled then
      if not is_normal_track() then
        handle_invalid_track()
        return
      end

      auto_receive_all()
      renoise.app():show_status("Track changed: auto-grab updated sliders.")
    end
  end)
end

function create_sliders(row, initial_value, range, slider_set)
  local slider_row = {}
  for i = 1, 16 do
    local slider = vb:minislider {
      width=global_slider_width,
      height = global_slider_height,
      min = 0,
      max = range,
      value = initial_value,
      notifier=function(new_value)
        -- CRITICAL: Only update pattern if we're not currently receiving
        if not is_receiving then
          print_row(slider_set, slider_set, false)
        end
      end
    }
    table.insert(slider_row, slider)
    row:add_child(slider)
  end
  return slider_row
end

function create_row_controls(slider_set, initial_value, range, loop_default)
  local row = vb:row{vb:text{text=slider_set:gsub("^%l", string.upper), font="bold", style="strong",width=60,}}

  -- Pass slider_set to create_sliders so it knows which pattern to update
  local sliders_row = create_sliders(row, initial_value, range, slider_set)

  row:add_child(vb:valuebox{
    min = 1,
    max = 16,
    value = loop_default,
    notifier=function(value) 
      loop_values[slider_set] = value 
      -- Only update pattern if we're not receiving
      if not is_receiving then
        print_row(slider_set, slider_set, true)
      end
    end
  })

  row:add_child(vb:button{
    text="Randomize",
    notifier=function() randomize_row(slider_set) end
  })
  
  row:add_child(vb:button{
    text="Print",
    notifier=function() print_row(slider_set, slider_set) end
  })

  row:add_child(vb:button{text="Reset",notifier=function() reset_row(slider_set) print_row(slider_set, slider_set) end})
  row:add_child(vb:button{text="Receive",notifier=function() receive_row(slider_set, slider_set, false) end})
  row:add_child(vb:button{text="<",notifier=function() shift_row(slider_set, "left") end})
  row:add_child(vb:button{text=">",notifier=function() shift_row(slider_set, "right") end})

  return row, sliders_row
end


function volume_interpolation()
  local song=renoise.song()
  local changes_made = false
  
  -- Get the selection data using the pro function
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_error("No selection in pattern!")
    return
  end

  -- Get pattern info
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  local selection = song.selection_in_pattern
  local start_line = selection.start_line
  local end_line = selection.end_line

  -- Ensure there is a difference between start and end lines
  if start_line == end_line then
    renoise.app():show_error("The selection must span at least two lines.")
    return
  end

  -- Iterate through each track in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    local track = pattern:track(track_index)
    
    -- Check if volume column is visible for this track
    if song:track(track_index).volume_column_visible then
      -- Process each selected note column in this track
      for _, note_column_index in ipairs(track_info.note_columns) do
        -- Get start and end note columns
        local start_note = track:line(start_line):note_column(note_column_index)
        local end_note = track:line(end_line):note_column(note_column_index)

        -- Get volume values, using 80 (0x50) as default when empty
        local start_vol = start_note.volume_value
        local end_vol = end_note.volume_value
        local start_vol_empty = start_note.volume_string == ".."
        local end_vol_empty = end_note.volume_string == ".."

        -- If end volume is empty, use 0x50 (80) as the target
        if end_vol_empty then
          end_vol = 0x50
        end

        -- Only proceed if we have a valid end volume or the end is explicitly empty (00)
        if not end_note.is_empty then
          -- Calculate volume difference and step
          local vol_diff = end_vol - (start_vol_empty and 0x50 or start_vol)
          
          -- Skip if no difference to interpolate
          if vol_diff ~= 0 then
            changes_made = true
            local steps = end_line - start_line
            local step_size = vol_diff / steps

            -- Interpolate volumes between start and end lines
            for i = 1, steps - 1 do
              local line_index = start_line + i
              local line = track:line(line_index)
              local note_column = line:note_column(note_column_index)
              
              -- Calculate interpolated volume
              local interpolated_vol = math.floor((start_vol_empty and 0x50 or start_vol) + (i * step_size))
              
              -- Ensure volume stays within valid range (0x00-0x80)
              interpolated_vol = math.max(0, math.min(0x80, interpolated_vol))
              
              -- Only set volume if we're not on the first line or if first line already has volume
              if i > 0 or not start_vol_empty then
                note_column.volume_value = interpolated_vol
              end
            end
          end
        end
      end
    end
  end

  if not changes_made then
    renoise.app():show_status("No volume values to interpolate in the selection.")
  end
end

function delay_interpolation()
  local song=renoise.song()
  local changes_made = false
  
  -- Get the selection data using the pro function
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_error("No selection in pattern!")
    return
  end

  -- Get pattern info
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  local selection = song.selection_in_pattern
  local start_line = selection.start_line
  local end_line = selection.end_line

  -- Ensure there is a difference between start and end lines
  if start_line == end_line then
    renoise.app():show_error("The selection must span at least two lines.")
    return
  end

  -- Iterate through each track in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    local track = pattern:track(track_index)
    
    -- Check if delay column is visible for this track
    if song:track(track_index).delay_column_visible then
      -- Process each selected note column in this track
      for _, note_column_index in ipairs(track_info.note_columns) do
        -- Get start and end note columns
        local start_note = track:line(start_line):note_column(note_column_index)
        local end_note = track:line(end_line):note_column(note_column_index)

        -- Get delay values, using 0 as default when empty
        local start_delay = start_note.delay_value
        local end_delay = end_note.delay_value
        local start_delay_empty = start_note.delay_string == ".."
        local end_delay_empty = end_note.delay_string == ".."

        -- If end delay is empty, use 0 as the target
        if end_delay_empty then
          end_delay = 0
        end

        -- Only proceed if we have a valid end delay or the end is explicitly empty (00)
        if not end_note.is_empty then
          -- Calculate delay difference and step
          local delay_diff = end_delay - (start_delay_empty and 0 or start_delay)
          
          -- Skip if no difference to interpolate
          if delay_diff ~= 0 then
            changes_made = true
            local steps = end_line - start_line
            local step_size = delay_diff / steps

            -- Interpolate delays between start and end lines
            for i = 1, steps - 1 do
              local line_index = start_line + i
              local line = track:line(line_index)
              local note_column = line:note_column(note_column_index)
              
              -- Calculate interpolated delay
              local interpolated_delay = math.floor((start_delay_empty and 0 or start_delay) + (i * step_size))
              
              -- Ensure delay stays within valid range (0x00-0xFF)
              interpolated_delay = math.max(0, math.min(0xFF, interpolated_delay))
              
              -- Only set delay if we're not on the first line or if first line already has delay
              if i > 0 or not start_delay_empty then
                note_column.delay_value = interpolated_delay
              end
            end
          end
        end
      end
    end
  end

  if not changes_made then
    renoise.app():show_status("No delay values to interpolate in the selection.")
  end
end

function panning_interpolation()
  local song=renoise.song()
  local changes_made = false
  
  -- Get the selection data using the pro function
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_error("No selection in pattern!")
    return
  end

  -- Get pattern info
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  local selection = song.selection_in_pattern
  local start_line = selection.start_line
  local end_line = selection.end_line

  -- Ensure there is a difference between start and end lines
  if start_line == end_line then
    renoise.app():show_error("The selection must span at least two lines.")
    return
  end

  -- Iterate through each track in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    local track = pattern:track(track_index)
    
    -- Check if panning column is visible for this track
    if song:track(track_index).panning_column_visible then
      -- Process each selected note column in this track
      for _, note_column_index in ipairs(track_info.note_columns) do
        -- Get start and end note columns
        local start_note = track:line(start_line):note_column(note_column_index)
        local end_note = track:line(end_line):note_column(note_column_index)

        -- Get panning values, using 0x40 (center) as default when empty
        local start_pan = start_note.panning_value
        local end_pan = end_note.panning_value
        local start_pan_empty = start_note.panning_string == ".."
        local end_pan_empty = end_note.panning_string == ".."

        -- If end panning is empty, use 0x40 (center) as the target
        if end_pan_empty then
          end_pan = 0x40
        end

        -- Only proceed if we have a valid end panning or the end is explicitly empty (00)
        if not end_note.is_empty then
          -- Calculate panning difference and step
          local pan_diff = end_pan - (start_pan_empty and 0x40 or start_pan)
          
          -- Skip if no difference to interpolate
          if pan_diff ~= 0 then
            changes_made = true
            local steps = end_line - start_line
            local step_size = pan_diff / steps

            -- Interpolate panning between start and end lines
            for i = 1, steps - 1 do
              local line_index = start_line + i
              local line = track:line(line_index)
              local note_column = line:note_column(note_column_index)
              
              -- Calculate interpolated panning
              local interpolated_pan = math.floor((start_pan_empty and 0x40 or start_pan) + (i * step_size))
              
              -- Ensure panning stays within valid range (0x00-0x80)
              interpolated_pan = math.max(0, math.min(0x80, interpolated_pan))
              
              -- Only set panning if we're not on the first line or if first line already has panning
              if i > 0 or not start_pan_empty then
                note_column.panning_value = interpolated_pan
              end
            end
          end
        end
      end
    end
  end

  if not changes_made then
    renoise.app():show_status("No panning values to interpolate in the selection.")
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Column Values (Volume)",invoke=function() volume_interpolation() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Column Values (Delay)",invoke=function() delay_interpolation() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Column Values (Panning)",invoke=function() panning_interpolation() end}
renoise.tool():add_midi_mapping{name="Paketti:Interpolate Column Values (Volume)",
  invoke=function(message) 
    if message:is_trigger() then volume_interpolation() end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Interpolate Column Values (Delay)",invoke=function(message) if message:is_trigger() then delay_interpolation() end end}
renoise.tool():add_midi_mapping{name="Paketti:Interpolate Column Values (Panning)",invoke=function(message) if message:is_trigger() then panning_interpolation() end  end}

function samplefx_interpolation()
  local song=renoise.song()
  local changes_made = false
  
  -- Get the selection data using the pro function
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_error("No selection in pattern!")
    return
  end

  -- Get pattern info
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  local selection = song.selection_in_pattern
  local start_line = selection.start_line
  local end_line = selection.end_line

  -- Ensure there is a difference between start and end lines
  if start_line == end_line then
    renoise.app():show_error("The selection must span at least two lines.")
    return
  end

  -- Iterate through each track in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    local track = pattern:track(track_index)
    
    -- Check if sample effects column is visible for this track
    if song:track(track_index).sample_effects_column_visible then
      -- Process each selected note column in this track
      for _, note_column_index in ipairs(track_info.note_columns) do
        -- Get start and end note columns
        local start_note = track:line(start_line):note_column(note_column_index)
        local end_note = track:line(end_line):note_column(note_column_index)

        -- Get effect values
        local start_effect_num = start_note.effect_number_value
        local end_effect_num = end_note.effect_number_value
        local start_effect_amt = start_note.effect_amount_value
        local end_effect_amt = end_note.effect_amount_value

        -- Check if effects are empty
        local start_empty = start_note.effect_number_string == ".."
        local end_empty = end_note.effect_number_string == ".."

        -- Only proceed if we have a valid end effect
        if not end_empty and not end_note.is_empty then
          -- We'll only interpolate the amount if the effect numbers match
          if start_effect_num == end_effect_num or start_empty then
            local effect_num = end_effect_num
            local amt_diff = end_effect_amt - (start_empty and 0 or start_effect_amt)
            
            -- Skip if no difference to interpolate
            if amt_diff ~= 0 then
              changes_made = true
              local steps = end_line - start_line
              local step_size = amt_diff / steps

              -- Interpolate effect amounts between start and end lines
              for i = 1, steps - 1 do
                local line_index = start_line + i
                local line = track:line(line_index)
                local note_column = line:note_column(note_column_index)
                
                -- Calculate interpolated amount
                local interpolated_amt = math.floor((start_empty and 0 or start_effect_amt) + (i * step_size))
                
                -- Ensure amount stays within valid range (0x00-0xFF)
                interpolated_amt = math.max(0, math.min(0xFF, interpolated_amt))
                
                -- Set the effect number and interpolated amount
                note_column.effect_number_value = effect_num
                note_column.effect_amount_value = interpolated_amt
              end
            end
          end
        end
      end
    end
  end

  if not changes_made then
    renoise.app():show_status("No sample effects to interpolate in the selection.")
  else
    renoise.app():show_status("Sample effects interpolated successfully!")
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Column Values (Sample FX)",invoke=function() samplefx_interpolation() end}
renoise.tool():add_midi_mapping{name="Paketti:Interpolate Column Values (Sample FX)",invoke=function(message) if message:is_trigger() then samplefx_interpolation() end  end}

-- Show the GUI dialog
function pakettiVolDelayPanSliderDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog=nil
    return
  end
  renoise.app().window.active_middle_frame=1

  if not is_normal_track() then
    handle_invalid_track()
    return
  end

  vb = renoise.ViewBuilder()

  local volume_row, volume_sliders = create_row_controls("volume", 0, 1, 16) -- 00-80 hex for volume
  sliders.volume = volume_sliders

  local delay_row, delay_sliders = create_row_controls("delay", 0, 1, 16) -- 00-FF hex for delay
  sliders.delay = delay_sliders

  local panning_row, panning_sliders = create_row_controls("panning", 0.5, 1, 16) -- 00-80 hex for panning, start at 40 (center)
  sliders.panning = panning_sliders

  -- Automatically receive current values from the selected track
  auto_receive_all()

  -- Observe track changes if auto-grab is enabled
  observe_track_changes()

  -- Layout the dialog with the auto-grab checkbox
  local content = vb:column{volume_row,delay_row,panning_row,
    vb:row{
      vb:checkbox{
        value = auto_grab_enabled,
        notifier=function(value)
          auto_grab_enabled = value
          renoise.app():show_status("Auto-grab " .. (value and "enabled" or "disabled"))
        end
      },
      vb:text{text="Auto-Grab", style="strong", font="bold"}},
    vb:row{ -- Print All and Randomize All buttons
      vb:button{text="Print All",notifier=function() print_all() end},
      vb:button{text="Randomize All",notifier=function() randomizenongroovebox_all() end},
      vb:button{text="Grab",notifier=function() global_receive() end},
      vb:button{text="<<",notifier=function() global_shift_left() end},
      vb:button{text=">>",notifier=function() global_shift_right() end}
    }
  }

  -- Focus on the middle frame when dialog opens
  renoise.app().window.active_middle_frame = 1

  dialog = renoise.app():show_custom_dialog("Paketti Volume/Delay/Pan Slider Controls", content, my_keyhandler_func)
  renoise.app().window.active_middle_frame=1
end

-- Trigger the dialog to show
renoise.tool():add_keybinding{name="Global:Paketti:Open VolDelayPan Slider Dialog...",invoke=function() pakettiVolDelayPanSliderDialog() end}

renoise.tool():add_midi_mapping{name="Paketti:Open VolDelayPan Slider Dialog...",invoke=function(message)  if message:is_trigger() then pakettiVolDelayPanSliderDialog() end end}
-----

renoise.tool():add_keybinding{name="Global:Paketti:Wipe All Columns of Selected Track",invoke=function()
renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]:clear()
end}

---
function PakettiGlobalSample(interpolation)
  local song=renoise.song()
  local interpolation_modes={"none","linear","cubic","sinc"}
  
  local interpolation_name=interpolation_modes[interpolation] or "unknown"

  for i=1,#song.instruments do
    local instrument=song.instruments[i]
    
    if instrument==nil then
      renoise.app():show_status("Instrument "..i.." is nil, skipping.")
    elseif #instrument.samples==0 then
      renoise.app():show_status("Instrument "..i.." has no samples, skipping.")
    else
      for y=1,#instrument.samples do
        instrument.samples[y].interpolation_mode=interpolation
      end
      renoise.app():show_status("Set interpolation for all samples in instrument "..i..".")
    end
  end
  
  renoise.app():show_status("Finished setting interpolation to "..interpolation_name.." for all instruments.")
end


renoise.tool():add_keybinding{name="Global:Paketti:Set Interpolation 1 (None) Globally",invoke=function() PakettiGlobalSample(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Interpolation 2 (Linear) Globally",invoke=function() PakettiGlobalSample(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Interpolation 3 (Cubic) Globally",invoke=function() PakettiGlobalSample(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Interpolation 4 (Sinc) Globally",invoke=function() PakettiGlobalSample(4) end}

--
for i=2,32 do
local actualNumber = formatDigits(2,i -1)
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide Selected Track Device " .. actualNumber,invoke=function() ShowHideSelectedTrack(i)
end}
renoise.tool():add_midi_mapping{name="Paketti:Show/Hide Selected Track Device " .. string.format("%02d", actualNumber),invoke=function(message) if message:is_trigger() then ShowHideSelectedTrack(i)
end end}
end

function ShowHideSelectedTrack(slot)
  local track=renoise.song().selected_track
  local device=track.devices[slot]

  if device~=nil then
    if device.external_editor_available then
      if device.external_editor_visible then
        device.external_editor_visible=false
        renoise.app():show_status("The device "..device.name.." has been hidden.")
      else
        device.external_editor_visible=true
        renoise.app():show_status("The device "..device.name.." External Editor has been opened.")
      end
    else
      renoise.app():show_status("There is no External Editor for device "..device.name)
    end
  else
    renoise.app():show_status("There is no device in slot "..slot)
  end
end

--
function PakettiJumpRows(jump_amount, direction)
  local song=renoise.song()
  local current_pattern = song.selected_pattern
  local num_lines = current_pattern.number_of_lines
  local signed_amount = direction == "forward" and jump_amount or -jump_amount
  
  if song.transport.playing and song.transport.follow_player then
    local current_pos = song.transport.playback_pos
    local new_index = (current_pos.line + signed_amount - 1) % num_lines + 1
    
    -- Create new SongPos and use start_at() to jump during playback
    local new_pos = renoise.SongPos()
    new_pos.sequence = current_pos.sequence
    new_pos.line = new_index
    song.transport:start_at(new_pos)
    
    renoise.app():show_status("Jumped " .. direction .. " " .. jump_amount .. " rows to line " .. new_index)
  else
    local new_index = (song.selected_line_index + signed_amount - 1) % num_lines + 1
    song.selected_line_index = new_index
    renoise.app():show_status("Jumped " .. direction .. " " .. jump_amount .. " rows to line " .. new_index)
  end
end

function PakettiJumpRowsRandom(direction)
  local song=renoise.song()
  local current_pattern = song.selected_pattern
  local num_lines = current_pattern.number_of_lines
  local random_index
  
  if direction == "forward" then
    random_index = math.random(1, num_lines)
  else -- backward
    local current_line = (song.transport.playing and song.transport.follow_player) and song.transport.playback_pos.line or song.selected_line_index
    random_index = (current_line - math.random(1, num_lines) - 1) % num_lines + 1
  end
  
  if song.transport.playing and song.transport.follow_player then
    -- Create new SongPos and use start_at() to jump during playback
    local current_pos = song.transport.playback_pos
    local new_pos = renoise.SongPos()
    new_pos.sequence = current_pos.sequence
    new_pos.line = random_index
    song.transport:start_at(new_pos)
  else
    song.selected_line_index = random_index
  end
  renoise.app():show_status("Randomly jumped " .. direction .. " to line " .. random_index)
end

for i = 1, 128 do
  renoise.tool():add_keybinding{name="Global:Paketti:Jump Forward Within Pattern by " .. formatDigits(3, i),invoke=function() PakettiJumpRows(i, "forward") end}
  renoise.tool():add_keybinding{name="Global:Paketti:Jump Backward Within Pattern by " .. formatDigits(3, i),invoke=function() PakettiJumpRows(i, "backward") end}
  renoise.tool():add_midi_mapping{name="Paketti:Jump Forward Within Pattern by " .. formatDigits(3, i),invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRows(i, "forward") end end}
  renoise.tool():add_midi_mapping{name="Paketti:Jump Backward Within Pattern by " .. formatDigits(3, i),invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRows(i, "backward") end end}
end
renoise.tool():add_keybinding{name="Global:Paketti:Jump Forward Within Pattern by Random",invoke=function() PakettiJumpRowsRandom("forward") end}
renoise.tool():add_keybinding{name="Global:Paketti:Jump Backward Within Pattern by Random",invoke=function() PakettiJumpRowsRandom("backward") end}
renoise.tool():add_midi_mapping{name="Paketti:Jump Forward Within Pattern by Random",invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRowsRandom("forward") end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump Backward Within Pattern by Random",invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRowsRandom("backward") end end}

local function get_total_song_rows()
  local song=renoise.song()
  local total_rows = 0
  for _, pattern_index in ipairs(song.sequencer.pattern_sequence) do
    total_rows = total_rows + song.patterns[pattern_index].number_of_lines
  end
  return total_rows
end

local function get_pattern_and_row_from_cumulative_position(position)
  local song=renoise.song()
  local cumulative_rows = 0

  for sequence_index, pattern_index in ipairs(song.sequencer.pattern_sequence) do
    local pattern_length = song.patterns[pattern_index].number_of_lines
    if position <= cumulative_rows + pattern_length then
      return sequence_index, position - cumulative_rows
    end
    cumulative_rows = cumulative_rows + pattern_length
  end

  return #song.sequencer.pattern_sequence, song.patterns[song.sequencer.pattern_sequence[#song.sequencer.pattern_sequence]].number_of_lines
end

local function get_current_cumulative_position()
  local song=renoise.song()
  local sequence_index = song.selected_sequence_index
  local line_index = song.selected_line_index
  local cumulative_rows = 0

  for i = 1, sequence_index - 1 do
    cumulative_rows = cumulative_rows + song.patterns[song.sequencer.pattern_sequence[i]].number_of_lines
  end

  return cumulative_rows + line_index
end

-- Jump across patterns in the song
function PakettiJumpRowsInSong(jump_amount, direction)
  local song=renoise.song()
  local current_position = get_current_cumulative_position()
  local total_rows = get_total_song_rows()
  local signed_amount = direction == "forward" and jump_amount or -jump_amount
  local target_position = direction == "forward" and math.min(current_position + jump_amount, total_rows) or math.max(current_position - jump_amount, 1)

  local target_sequence, target_row = get_pattern_and_row_from_cumulative_position(target_position)
  
  if song.transport.playing and song.transport.follow_player then
    -- Create new SongPos and use start_at() to jump during playback
    local new_pos = renoise.SongPos()
    new_pos.sequence = target_sequence
    new_pos.line = target_row
    song.transport:start_at(new_pos)
  else
    song.selected_sequence_index = target_sequence
    song.selected_line_index = target_row
  end
  renoise.app():show_status("Jumped " .. direction .. " within song by " .. jump_amount .. " rows to sequence " .. target_sequence .. ", row " .. target_row)
end

-- Random jump within song
function PakettiJumpRowsRandomInSong(direction)
  local song=renoise.song()
  local total_rows = get_total_song_rows()
  local random_position
  
  if direction == "forward" then
    random_position = math.random(1, total_rows)
  else -- backward
    random_position = math.random(1, total_rows)
    random_position = total_rows - random_position
  end
  
  local target_sequence, target_row = get_pattern_and_row_from_cumulative_position(random_position)
  
  if song.transport.playing and song.transport.follow_player then
    -- Create new SongPos and use start_at() to jump during playback
    local new_pos = renoise.SongPos()
    new_pos.sequence = target_sequence
    new_pos.line = target_row
    song.transport:start_at(new_pos)
  else
    song.selected_sequence_index = target_sequence
    song.selected_line_index = target_row
  end
  renoise.app():show_status("Randomly jumped " .. direction .. " within song to sequence " .. target_sequence .. ", row " .. target_row)
end

for i = 1, 128 do
  renoise.tool():add_keybinding{name="Global:Paketti:Jump Forward Within Song by " .. formatDigits(3, i),invoke=function() PakettiJumpRowsInSong(i, "forward") end}
  renoise.tool():add_keybinding{name="Global:Paketti:Jump Backward Within Song by " .. formatDigits(3, i),invoke=function() PakettiJumpRowsInSong(i, "backward") end}
  renoise.tool():add_midi_mapping{name="Paketti:Jump Forward Within Song by " .. formatDigits(3, i),invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRowsInSong(i, "forward") end end}
  renoise.tool():add_midi_mapping{name="Paketti:Jump Backward Within Song by " .. formatDigits(3, i),invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRowsInSong(i, "backward") end end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Jump Forward Within Song by Random",invoke=function() PakettiJumpRowsRandomInSong("forward") end}
renoise.tool():add_keybinding{name="Global:Paketti:Jump Backward Within Song by Random",invoke=function() PakettiJumpRowsRandomInSong("backward") end}
renoise.tool():add_midi_mapping{name="Paketti:Jump Forward Within Song by Random",invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRowsRandomInSong("forward") end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump Backward Within Song by Random",invoke=function(message) if message:is_trigger() or message:is_abs_value() then PakettiJumpRowsRandomInSong("backward") end end}

function PopulateGainersOnEachTrack(placement)
  local song=renoise.song()
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    local has_gainer = false

    -- Check for "GlobalGainer" in the current track's devices
    for j = 2, #track.devices do
      if track.devices[j].display_name == "GlobalGainer" then
        has_gainer = true
        break
      end
    end

    -- Add "Gainer" if not found
    if not has_gainer then
      local position = #track.devices + 1 -- Default to end
      if placement == "start" then
        position = 2 -- Beginning (position 2)
      end
      track:insert_device_at("Audio/Effects/Native/Gainer", position).display_name = "GlobalGainer"
    end
  end
end

function map_knob_to_gainer(knob_value, placement)
  local song=renoise.song()
  
  PopulateGainersOnEachTrack(placement)
  
  local scaled_value = (knob_value / 127) * 4
  
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    
    for j = 2, #track.devices do
      local device = track.devices[j]
      if device.display_name == "GlobalGainer" then
        device.parameters[1].value = scaled_value
        break
      end
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Populate GlobalGainers on Each Track (start chain)",invoke=function() PopulateGainersOnEachTrack("start") end}
renoise.tool():add_keybinding{name="Global:Paketti:Populate GlobalGainers on Each Track (end chain)",invoke=function() PopulateGainersOnEachTrack("end") end}
renoise.tool():add_midi_mapping{name="Paketti:GlobalGainer Knob Control (start chain)",invoke=function(midi_message) map_knob_to_gainer(midi_message.int_value, "start") end}
renoise.tool():add_midi_mapping{name="Paketti:GlobalGainer Knob Control (end chain)",invoke=function(midi_message) map_knob_to_gainer(midi_message.int_value, "end") end}
--------
function AddGainerCrossfadeSelectedTrack(name)
  local song=renoise.song()
  local track = song.selected_track
  local gainer_name = "Gainer " .. name
  local has_gainer_a, has_gainer_b = false, false
  
  -- Check if "Gainer A" or "Gainer B" already exists
  for i = 2, #track.devices do
    local device_name = track.devices[i].display_name
    if device_name == "Gainer A" then has_gainer_a = true end
    if device_name == "Gainer B" then has_gainer_b = true end
  end
  
  -- Add the specified gainer only if the other is not present
  if name == "A" and not has_gainer_a and not has_gainer_b then
    track:insert_device_at("Audio/Effects/Native/Gainer", #track.devices + 1).display_name = "Gainer A"
    renoise.app():show_status("Gainer A added to selected track")
  elseif name == "B" and not has_gainer_b and not has_gainer_a then
    track:insert_device_at("Audio/Effects/Native/Gainer", #track.devices + 1).display_name = "Gainer B"
    renoise.app():show_status("Gainer B added to selected track")
  else
    renoise.app():show_status("Gainer " .. name .. " could not be added as the other gainer already exists")
  end
end

function map_crossfade_to_ab(crossfade_value)
  local song=renoise.song()
  local scaled_a = crossfade_value / 127
  local scaled_b = (127 - crossfade_value) / 127
  
  -- Loop through each track to adjust all Gainer A and Gainer B parameters
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    for j = 2, #track.devices do
      local device = track.devices[j]
      if device.display_name == "Gainer A" then device.parameters[1].value = scaled_a end
      if device.display_name == "Gainer B" then device.parameters[1].value = scaled_b end
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Add Gainer A to Selected Track",invoke=function() AddGainerCrossfadeSelectedTrack("A") end}
renoise.tool():add_keybinding{name="Global:Paketti:Add Gainer B to Selected Track",invoke=function() AddGainerCrossfadeSelectedTrack("B") end}
renoise.tool():add_midi_mapping{name="Paketti:Gainer Crossfade A/B",invoke=function(midi_message) map_crossfade_to_ab(midi_message.int_value) end}

------
function flip_gainers()
  local song=renoise.song()
  local current_state = false -- will be used to track which gainer is active
  
  -- First, check any track's first gainer to determine current state
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    for j = 2, #track.devices do
      local device = track.devices[j]
      if device.display_name == "Gainer A" then
        current_state = (device.parameters[1].value > 0.9) -- if A is high, we're in A state
        break
      end
      if device.display_name == "Gainer B" then
        current_state = (device.parameters[1].value <= 0.9) -- if B is low, we're in A state
        break
      end
    end
    break -- we only need to check the first track
  end
  
  -- Now flip the state
  local a_value = current_state and 0 or 1
  local b_value = current_state and 1 or 0
  
  -- Apply to all tracks
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    for j = 2, #track.devices do
      local device = track.devices[j]
      if device.display_name == "Gainer A" then device.parameters[1].value = a_value end
      if device.display_name == "Gainer B" then device.parameters[1].value = b_value end
    end
  end
  
  renoise.app():show_status(string.format("Switched to Gainer %s", current_state and "B" or "A"))
end

renoise.tool():add_keybinding{name="Global:Paketti:Flip Gainers A/B",invoke=function() flip_gainers() end}

------
-- Create a timestamp in the format YYYYMMDD-HHMMSS
local function generate_timestamp()
  local time=os.date("*t")
  return string.format("%04d%02d%02d-%02d%02d%02d", time.year, time.month, time.day, time.hour, time.min, time.sec)
end

-- Main function to handle saving logic
local function save_with_new_timestamp()
  local timestamp=generate_timestamp()

  -- Prompt for folder every time
  local folder=renoise.app():prompt_for_path("Choose a folder to save the file:")
  if not folder then
    renoise.app():show_status("Folder selection canceled. Exiting process.")
    return
  end

  -- Generate the full filename with timestamp
  local filename=folder.."/"..timestamp..".xrns"

  -- Save the song
  local success=renoise.app():save_song_as(filename)
  if success then
    renoise.app():show_status("Song successfully saved as: "..filename)
  else
    renoise.app():show_status("Failed to save song. Check the folder permissions or disk space.")
  end
end


-- Call the main function
renoise.tool():add_keybinding{name="Global:Paketti:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
-------
local dialog -- Variable to track dialog visibility

-- Function to modify the SampleBuffer based on operation and value
function PakettiOffsetSampleBuffer(operation, number)
  local sample = renoise.song().selected_sample

    -- Check if we have a selected instrument
    if not renoise.song().selected_instrument then
      renoise.app():show_status("No instrument selected")
      return
    end
    
    -- Check if we have a selected sample
    local sample = renoise.song().selected_sample
    if not sample then
      renoise.app():show_status("No sample selected in the current instrument")
      return
    end

  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    
    for ch = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_sample = buffer:sample_data(ch, i)
        local modified_sample

        if operation == "Subtract" then
          modified_sample = math.max(-1.0, math.min(1.0, current_sample + number)) -- Shift down with negative value
        elseif operation == "Multiply" then
          modified_sample = math.max(-1.0, math.min(1.0, current_sample * (1 + number))) -- Apply scaling factor
        else
          renoise.app():show_status("Invalid operation. Use 'subtract' or 'multiply'.")
          return
        end

        buffer:set_sample_data(ch, i, modified_sample)
      end
    end
    
    buffer:finalize_sample_data_changes()
    renoise.app():show_status(operation .. " operation applied with value " .. number .. " to the sample buffer.")
  else
    renoise.app():show_status("No sample data available in the selected sample.")
  end
end

-- Function to show the offset dialog with slider, switch, and button
function pakettiOffsetDialog()
  if dialog and dialog.visible then
    dialog:close() -- Close if already open
    return
  end

  local vb = renoise.ViewBuilder()
  local slider_value = vb:text{text="0.0",width=40 } -- Initial display text for slider value
  
  local slider = vb:slider{
    min=-1.0,
    max=1.0,
    value=0,
    width=120,
    notifier=function(value)
      slider_value.text = string.format("%.2f", value) -- Update text to reflect slider position
    end
  }

  local operation_switch = vb:switch { items={ "-", "*" }, value=1,width=40 }
  
  local function apply_offset()
    local value = slider.value
    local operation = (operation_switch.value == 1) and "Subtract" or "Multiply"
    
    -- Adjust operation logic based on slider value
    PakettiOffsetSampleBuffer(operation, value)

    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  end

  local content = vb:column{
    vb:horizontal_aligner{
      vb:text{text="Offset/Multiplier:" },
      slider,
      slider_value -- Display text next to the slider
    },
    vb:horizontal_aligner{
      vb:text{text="Operation:" },
      operation_switch
    },
    vb:button{ text="Change Sample Buffer",width=160, notifier=apply_offset }
  }

  dialog = renoise.app():show_custom_dialog("Offset Sample Buffer", content, my_keyhandler_func)
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Offset Sample Buffer by -0.5",invoke=function() PakettiOffsetSampleBuffer("Subtract", 0.5) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Multiply Sample Buffer by 0.5",invoke=function() PakettiOffsetSampleBuffer("Multiply", 0.5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Open Offset Dialog...",invoke=pakettiOffsetDialog }
------

-- Function to invert specified content in the selection or entire track
function invert_content(column_type)
  local song=renoise.song()
  local pattern=song.selected_pattern
  local selection=song.selection_in_pattern

  -- Determine the range based on the selection or entire track if no selection
  local start_line, end_line, start_track, end_track, start_column, end_column

  if selection then
    start_line=selection.start_line
    end_line=selection.end_line
    start_track=selection.start_track
    end_track=selection.end_track
    start_column=selection.start_column
    end_column=selection.end_column
  else
    start_line=1
    end_line=pattern.number_of_lines
    start_track=song.selected_track_index
    end_track=start_track
    start_column=1
    end_column=song:track(start_track).visible_note_columns + song:track(start_track).visible_effect_columns
  end

  -- Iterate over the specified lines and tracks
  for line_index=start_line, end_line do
    for track_index=start_track, end_track do
      local track=pattern:track(track_index)
      local track_vis=song:track(track_index)
      local note_columns_visible=track_vis.visible_note_columns
      local effect_columns_visible=track_vis.visible_effect_columns
      local total_columns_visible=note_columns_visible + effect_columns_visible

      -- Calculate column boundaries for this track
      local current_start_column = (selection and track_index == start_track) and start_column or 1
      local current_end_column = (selection and track_index == end_track) and end_column or total_columns_visible

      -- Iterate over the columns based on calculated boundaries
      for col=current_start_column, current_end_column do
        if col <= note_columns_visible and (column_type == "notecolumns" or column_type == "all") then
          -- Note column inversion
          local note_col=track:line(line_index).note_columns[col]

          -- Invert volume if within 0x00-0x80 range
          if note_col.volume_value >= 0 and note_col.volume_value <= 0x80 then
            note_col.volume_value=0x80 - note_col.volume_value
          end

          -- Invert panning if within 0x00-0x80 range
          if note_col.panning_value >= 0 and note_col.panning_value <= 0x80 then
            note_col.panning_value=0x80 - note_col.panning_value
          end

          -- Invert delay if present (range 0x00-0xFF)
          if note_col.delay_value > 0 then
            note_col.delay_value=0xFF - note_col.delay_value
          end

          -- Invert effect amount if present (range 0x00-0xFF)
          if note_col.effect_amount_value > 0 then
            note_col.effect_amount_value=0xFF - note_col.effect_amount_value
          end

        elseif col > note_columns_visible and (column_type == "effectcolumns" or column_type == "all") then
          -- Effect column inversion
          local effect_col=track:line(line_index).effect_columns[col - note_columns_visible]

          -- Invert amount if present (range 0x00-0xFF) only if number_value is not zero
          if effect_col.number_value ~= 0 then
            effect_col.amount_value = (effect_col.amount_value == 0x00) and 0xFF or (0xFF - effect_col.amount_value)
          end
        end
      end
    end
  end

  renoise.app():show_status("Inverted values in selected range: " .. column_type)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Invert Note Column Subcolumns",invoke=function() invert_content("notecolumns") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Invert Effect Column Subcolumns",invoke=function() invert_content("effectcolumns") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Invert All Subcolumns",invoke=function() invert_content("all") end}


---
function wipe_random_notes_with_note_offs()
  local song=renoise.song()
  local random = math.random

  -- Get the selection in pattern
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_status("No valid selection in pattern!")
    return
  end

  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]

  -- Randomize the number of notes to replace (1–12)
  local notes_to_replace = random(1, 12)
  local replaced_count = 0

  print("Random notes to replace:", notes_to_replace)

  -- Iterate through the tracks in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    local track = song.tracks[track_index]

    print("Processing Track:", track_index)

    -- Skip tracks with no selected note columns
    if #track_info.note_columns > 0 then
      for _, column_index in ipairs(track_info.note_columns) do
        print("Processing Column:", column_index)

        -- Access the lines within the selected range
        for line_index = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
          local line = pattern.tracks[track_index]:line(line_index)
          local note_column = line:note_column(column_index)

          -- Debug: Print note details
          if note_column then
            print("Line:", line_index, "Column:", column_index, "Note String:", note_column.note_string or "Empty", "Is Empty:", note_column.is_empty)
          end

          -- Replace random notes with NOTE_OFF, skipping NOTE_OFF columns
          if note_column and not note_column.is_empty and note_column.note_string ~= "OFF" then
            if replaced_count < notes_to_replace and random(0, 1) == 1 then -- Random decision for replacement
              print("Replacing Note with NOTE_OFF at Line:", line_index, "Column:", column_index)
              note_column.note_string = "OFF" -- Set the note to OFF
              note_column.instrument_value = 255 -- Clear the instrument value
              replaced_count = replaced_count + 1
            end
          end
        end
      end
    else
      print("No selected note columns in Track:", track_index)
    end
  end

  -- Show appropriate status message
  if replaced_count > 0 then
    renoise.app():show_status("Removed " .. replaced_count .. " notes and replaced them with note-offs.")
  else
    renoise.app():show_status("No notes left to be wiped, doing nothing.")
  end

  -- Return focus to the pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Wipe Random Notes",invoke=function() wipe_random_notes_with_note_offs() end}
--------
-- Add this helper function at the top
function isInstrumentEmpty(instrument)
  return (#instrument.samples == 0 and 
          not instrument.plugin_properties.plugin_loaded and
          not instrument.midi_output_properties.device_name and
          #instrument.sample_mappings[1].slices == 0)
end

-- Function to reduce volume of all instruments
function reduceInstrumentsVolume(db_amount)
  local song=renoise.song()
  local MIN_DB = -96  -- Renoise's minimum dB level before -INF
  
  -- Check volumes first
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    if not isInstrumentEmpty(instrument) then
      local current_db = math.lin2db(instrument.volume)
      if (current_db - db_amount) <= MIN_DB then
        renoise.app():show_status("Cannot reduce by -" .. db_amount .. "dB: would go below -96dB")
        return
      end
    end
  end
  
  -- Apply volume changes
  local changed_count = 0
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    if not isInstrumentEmpty(instrument) then
      local current_db = math.lin2db(instrument.volume)
      local new_db = current_db - db_amount
      instrument.volume = math.db2lin(new_db)
      changed_count = changed_count + 1
    end
  end
  
  renoise.app():show_status(string.format("%d instruments volume reduced by %.1fdB", changed_count, db_amount))
end

renoise.tool():add_keybinding{name="Global:Paketti:Global Volume Reduce All Instruments by -4.5dB",invoke=function() reduceInstrumentsVolume(4.5) end}

renoise.tool():add_midi_mapping{name="Paketti:Global Volume Reduce All Instruments by -4.5dB",invoke=function(message) if message:is_trigger() then reduceInstrumentsVolume(4.5) end end}

-- Function to reduce volume of all samples in all instruments
function reduceSamplesVolume(db_amount)
  local song=renoise.song()
  local MIN_DB = -96  -- Renoise's minimum dB level before -INF
  
  -- First check if any sample would go below MIN_DB
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    if instrument and #instrument.samples > 0 then
      for _, sample in ipairs(instrument.samples) do
        local current_db = math.lin2db(sample.volume)
        if (current_db - db_amount) <= MIN_DB then
          renoise.app():show_status("Cannot reduce by -" .. db_amount .. "dB: would go below -96dB")
          return
        end
      end
    end
  end
  
  -- If we get here, it's safe to reduce all volumes
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    if instrument and #instrument.samples > 0 then
      for _, sample in ipairs(instrument.samples) do
        local current_db = math.lin2db(sample.volume)
        local new_db = current_db - db_amount
        sample.volume = math.db2lin(new_db)
      end
    end
  end
  
  renoise.app():show_status(string.format("All samples volume reduced by %.1fdB", db_amount))
end

renoise.tool():add_keybinding{name="Global:Paketti:Global Volume Reduce All Samples by -4.5dB",invoke=function() reduceSamplesVolume(4.5) end}

renoise.tool():add_midi_mapping{name="Paketti:Global Volume Reduce All Samples by -4.5dB",invoke=function(message) if message:is_trigger() then reduceSamplesVolume(4.5) end end}

function pakettiGlobalVolumeDialog()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  local current_db_value = 0
  local current_sample_db_value = 0
  
  local value_display = vb:text{ text="0.0 dB" }
  local sample_value_display = vb:text{ text="0.0 dB" }
  local value_slider
  local value_box
  local sample_value_slider
  local sample_value_box
  
  local function update_instrument_controls(new_value)
    current_db_value = new_value
    value_display.text = string.format("%.1f dB", new_value)
    value_slider.value = new_value
    value_box.value = new_value
  end
  
  local function update_sample_controls(new_value)
    current_sample_db_value = new_value
    sample_value_display.text = string.format("%.1f dB", new_value)
    sample_value_slider.value = new_value
    sample_value_box.value = new_value
  end

  value_box = vb:valuebox{
    min = -96,
    max = 0,
    width=90,
    value = current_db_value,
    tostring = function(value) return string.format("%.1f", value) end,
    tonumber = function(str) return tonumber(str) or 0 end,
    notifier=function(new_value)
      update_instrument_controls(new_value)
    end
  }
  
  sample_value_box = vb:valuebox{
    min = -96,
    max = 0,
    width=90,
    value = current_sample_db_value,
    tostring = function(value) return string.format("%.1f", value) end,
    tonumber = function(str) return tonumber(str) or 0 end,
    notifier=function(new_value)
      update_sample_controls(new_value)
    end
  }
  
  value_slider = vb:slider{
    min = -96,
    max = 0,
    value = current_db_value,
    width=250,
    notifier=function(new_value)
      update_instrument_controls(new_value)
    end
  }
  
  sample_value_slider = vb:slider{
    min = -96,
    max = 0,
    value = current_sample_db_value,
    width=250,
    notifier=function(new_value)
      update_sample_controls(new_value)
    end
  }
  
  local dialog_content = vb:column{
    margin=0,
    spacing=0,
    
    vb:text{text="Instrument Volume:",width=120 },
    vb:row{
      spacing=0,
      value_box,
      value_display
    },
    value_slider,
    
    vb:text{text="Sample/Slice Volume:",width=120 },
    vb:row{
      spacing=0,
      sample_value_box,
      sample_value_display
    },
    sample_value_slider,
    
    vb:button{
      text="Apply Volume Changes",
      width=250,
      notifier=function()
        if current_db_value ~= 0 then
          reduceInstrumentsVolume(-current_db_value)
        end
        if current_sample_db_value ~= 0 then
          reduceSamplesVolume(-current_sample_db_value)
        end
        if dialog and dialog.visible then
          dialog:close()
        end
      end
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Global Instrument/Sample Volume Adjustment",dialog_content, my_keyhandler_func)
end


renoise.tool():add_keybinding{name="Global:Paketti:Global Volume Adjustment...",invoke=function() pakettiGlobalVolumeDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Global Volume Adjustment...",invoke=function(message) if message:is_trigger() then pakettiGlobalVolumeDialog() end end}
-------
------

-------
function PatternMatrixCopyExpandLine(track_index, pattern_index, from_line, to_line)
  local s = renoise.song()
  local cur_pattern = s:pattern(pattern_index)
  local cur_track = cur_pattern:track(track_index)
  
  print(string.format("    Expanding in pattern %d: line %d -> line %d", pattern_index, from_line, to_line))
  cur_track:line(to_line):copy_from(cur_track:line(from_line))
  cur_track:line(from_line):clear()
  cur_track:line(to_line + 1):clear()
end

function PatternMatrixCopyShrinkLine(track_index, pattern_index, from_line, to_line)
  local s = renoise.song()
  local cur_pattern = s:pattern(pattern_index)
  local cur_track = cur_pattern:track(track_index)
  
  print(string.format("    Shrinking in pattern %d: line %d -> line %d", pattern_index, from_line, to_line))
  cur_track:line(to_line):copy_from(cur_track:line(from_line))
  cur_track:line(from_line):clear()
  cur_track:line(from_line + 1):clear()
end

function PatternMatrixExpandTrack(track_index, pattern_index, start_line, end_line)
  local s = renoise.song()
  local pattern = s:pattern(pattern_index)
  
  print(string.format("  Expanding track %d in pattern %d (lines %d to %d)", 
    track_index, pattern_index, start_line, end_line))
  
  for l = end_line, start_line, -1 do
    if l ~= start_line and l*2-start_line <= pattern.number_of_lines then
      PatternMatrixCopyExpandLine(track_index, pattern_index, l, l*2-start_line)
    end
  end
end

function PatternMatrixShrinkTrack(track_index, pattern_index, start_line, end_line)
  local s = renoise.song()
  local pattern = s:pattern(pattern_index)
  
  print(string.format("  Shrinking track %d in pattern %d (lines %d to %d)", 
    track_index, pattern_index, start_line, end_line))
  
  for l = start_line, end_line, 2 do
    if l ~= start_line then
      PatternMatrixCopyShrinkLine(track_index, pattern_index, l, l/2 + start_line/2)
    end
  end
end

function PatternMatrixExpand()
  local song=renoise.song()
  local sequencer = song.sequencer
  local selected_tracks = {}
  local selected_sequences = {}  -- Track -> array of sequence indices
  
  -- First pass: collect all selected tracks and their sequence positions
  for track_idx = 1, song.sequencer_track_count do
    for seq_idx = 1, #sequencer.pattern_sequence do
      if sequencer:track_sequence_slot_is_selected(track_idx, seq_idx) then
        if not selected_tracks[track_idx] then
          selected_tracks[track_idx] = true
          selected_sequences[track_idx] = {}
        end
        table.insert(selected_sequences[track_idx], seq_idx)
      end
    end
  end

  if next(selected_tracks) == nil then
    print("No tracks selected in pattern matrix")
    renoise.app():show_status("Nothing selected in pattern matrix")
    return
  end

  -- Second pass: process each track's selected patterns in order
  for track_idx, sequences in pairs(selected_sequences) do
    for _, seq_idx in ipairs(sequences) do
      local pattern_index = sequencer.pattern_sequence[seq_idx]
      local pattern_lines = song.patterns[pattern_index].number_of_lines
      PatternMatrixExpandTrack(track_idx, pattern_index, 1, pattern_lines)
    end
  end
end

function PatternMatrixShrink()
  local song=renoise.song()
  local sequencer = song.sequencer
  local selected_tracks = {}
  
  print("\nPattern Matrix Selection:")
  print("------------------------")
  
  for track_idx = 1, song.sequencer_track_count do
    local track_has_selection = false
    local track_selections = {}
    
    for seq_idx = 1, #sequencer.pattern_sequence do
      if sequencer:track_sequence_slot_is_selected(track_idx, seq_idx) then
        track_has_selection = true
        selected_tracks[track_idx] = true
        table.insert(track_selections, seq_idx)
      end
    end
    
    if track_has_selection then
      print(string.format("Track %02d: Selected in sequences %s", 
        track_idx, 
        table.concat(track_selections, ", ")))
    end
  end
  print("------------------------")
  
  if next(selected_tracks) == nil then
    print("No tracks selected in pattern matrix")
    renoise.app():show_status("Nothing selected in pattern matrix")
    return
  end
  
  print("\nProcessing Patterns:")
  print("------------------------")
  
  for seq_idx = 1, #sequencer.pattern_sequence do
    local pattern_index = sequencer.pattern_sequence[seq_idx]
    local pattern_lines = song.patterns[pattern_index].number_of_lines
    
    for track_idx, _ in pairs(selected_tracks) do
      if sequencer:track_sequence_slot_is_selected(track_idx, seq_idx) then
        print(string.format("\nProcessing: Track %02d, Sequence %02d (Pattern %02d with %d lines)", 
          track_idx, seq_idx, pattern_index, pattern_lines))
        PatternMatrixShrinkTrack(track_idx, pattern_index, 1, pattern_lines)
      end
    end
  end
  print("------------------------")
  
  renoise.app():show_status("Shrank selected tracks in pattern matrix")
end

renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Pattern Matrix Selection Expand",invoke=PatternMatrixExpand }
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Pattern Matrix Selection Shrink",invoke=PatternMatrixShrink }
--------
-- Dialog state
local dialog = nil
local vb = nil

-- Create and show the dialog
function pakettiEditStepDialog()
  if dialog and dialog.visible then
    return
  end

  vb = renoise.ViewBuilder()
  
  local dialog_content = vb:row{
    vb:text{text="EditStep&Enter"},
    vb:textfield {
      id = "edit_step_input",
      width=30,
      active = true,
      edit_mode = true,
      value = tostring(renoise.song().transport.edit_step),
      notifier=function(text)
        local number = tonumber(text)
        if number then
          -- Cap the value at 64 if it's higher
          if number > 64 then
            number = 64
          end
          -- Ensure number is not negative
          if number >= 0 then
            renoise.song().transport.edit_step = number
            dialog:close()
          end
        end
      end
    }
  }

  dialog = renoise.app():show_custom_dialog("Set EditStep&Enter",dialog_content,my_keyhandler_func)
end

--[[
-- Key binding functions
local function key_handler(key)
  if key.modifiers == "alt" then  -- You can change this modifier
    if key.name == "key_down" then
      pakettiEditStepDialog()      
    elseif key.name == "key_up" then
      if dialog and dialog.visible then
        dialog:close()
      end
    end
  end
end
]]--

renoise.tool():add_keybinding{name="Global:Paketti:Show EditStep Dialog...",invoke=function() pakettiEditStepDialog() end}
------
-- Function to step by editstep (forwards or backwards)
function PakettiStepByEditStep(direction)
  local song=renoise.song()
  local current_line = song.selected_line_index
  local pattern_length = song.selected_pattern.number_of_lines
  local edit_step = song.transport.edit_step * direction
  
  -- Calculate next position with pattern wrapping
  local next_position = current_line + edit_step
  if next_position > pattern_length then
    next_position = next_position - pattern_length
  elseif next_position < 1 then
    next_position = pattern_length - (math.abs(next_position) % pattern_length)
  end
  
  song.selected_line_index = next_position
  renoise.app():show_status(string.format("Stepped by %d to line %d", 
    edit_step, next_position))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Step by EditStep (Forwards)", invoke=function() PakettiStepByEditStep(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Step by EditStep (Backwards)", invoke=function() PakettiStepByEditStep(-1) end}
renoise.tool():add_midi_mapping{name="Paketti:Step by EditStep Forward x[Trigger]", invoke=function(message) if message:is_trigger() then PakettiStepByEditStep(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Step by EditStep Backward x[Trigger]", invoke=function(message) if message:is_trigger() then PakettiStepByEditStep(-1) end end}
-------
function PakettiFixC0Panning()
  local song=renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local visible_note_columns = song.tracks[song.selected_track_index].visible_note_columns
  local changes_made = false
  
  -- Process each note column independently
  for column = 1, visible_note_columns do
    local last_non_c0 = nil
    
    -- Process all lines in the pattern for this column
    for line = 1, #track.lines do
      local note_column = track:line(line).note_columns[column]
      
      if note_column.panning_string == "C0" and last_non_c0 then
        -- If we have a C0 and we've seen a non-C0 value before, replace it
        note_column.panning_string = last_non_c0
        changes_made = true
      elseif note_column.panning_string ~= "C0" and note_column.panning_string ~= ".." then
        -- Update the last non-C0 value we've seen
        last_non_c0 = note_column.panning_string
      end
    end
  end
  
  if changes_made then
    renoise.app():show_status("Updated C0 panning values based on previous values")
  else
    renoise.app():show_status("No C0 values found to change in any column")
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Fix C0 Panning Values",invoke=function() PakettiFixC0Panning() end}
renoise.tool():add_midi_mapping{name="Paketti:Fix C0 Panning Values",invoke=function(message) if message:is_trigger() then PakettiFixC0Panning() end end}

function delete_automation(all_tracks, whole_song)
  local song=renoise.song()
  local start_pattern, end_pattern
  local start_track, end_track
  
  -- Determine pattern range
  if whole_song then
    start_pattern = 1
    end_pattern = #song.patterns
  else
    start_pattern = song.selected_pattern_index
    end_pattern = start_pattern
  end
  
  -- Determine track range
  if all_tracks then
    start_track = 1
    end_track = song.sequencer_track_count
  else
    start_track = song.selected_track_index
    end_track = start_track
  end
  
  local total_deleted = 0
  
  -- Process each pattern in range
  for pattern_idx = start_pattern, end_pattern do
    -- Process each track in range
    for track_idx = start_track, end_track do
      local track = song.patterns[pattern_idx].tracks[track_idx]
      
      -- Store parameters to delete (since we'll modify the collection)
      local parameters_to_delete = {}
      
      -- Get all automation parameters (includes both mixer and device automation)
      for _, automation in ipairs(track.automation) do
        print("Found automation for parameter:", automation.dest_parameter.name)
        table.insert(parameters_to_delete, automation.dest_parameter)
      end
      
      -- Delete all found automation envelopes
      print("Total parameters to delete:", #parameters_to_delete)
      for _, parameter in ipairs(parameters_to_delete) do
        print("Deleting automation for:", parameter.name)
        track:delete_automation(parameter)
        total_deleted = total_deleted + 1
      end
    end
  end
  
  -- Show appropriate status message
  local scope = all_tracks and "all tracks" or "selected track"
  local range = whole_song and "whole song" or "current pattern"
  if total_deleted > 0 then
    renoise.app():show_status(string.format("Deleted %d automation envelope(s) from %s in %s", 
      total_deleted, scope, range))
  else
    renoise.app():show_status(string.format("No automation envelopes found in %s in %s", 
      scope, range))
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Automation in Track on Current Pattern",invoke=function() delete_automation(false, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Automation in All Tracks on Current Pattern",invoke=function() delete_automation(true, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Automation in Track on Whole Song",invoke=function() delete_automation(false, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Automation in All Tracks on Whole Song",invoke=function() delete_automation(true, true) end}
-------
function wipe_effect_columns(all_tracks, whole_song)
  local song=renoise.song()
  local start_pattern, end_pattern
  local start_track, end_track
  
  -- Determine pattern range
  if whole_song then
    start_pattern = 1
    end_pattern = #song.patterns
  else
    start_pattern = song.selected_pattern_index
    end_pattern = start_pattern
  end
  
  -- Determine track range
  if all_tracks then
    start_track = 1
    end_track = song.sequencer_track_count
  else
    start_track = song.selected_track_index
    end_track = start_track
  end
  
  local total_cleared = 0
  
  -- Process each pattern in range
  for pattern_idx = start_pattern, end_pattern do
    local pattern = song.patterns[pattern_idx]
    
    -- Process each track in range
    for track_idx = start_track, end_track do
      local track = pattern:track(track_idx)
      local visible_effect_columns = song:track(track_idx).visible_effect_columns
      
      -- Skip if no effect columns
      if visible_effect_columns > 0 then
        -- Clear each line's effect columns
        for line_idx = 1, pattern.number_of_lines do
          local line = track:line(line_idx)
          for effect_idx = 1, visible_effect_columns do
            if not line.effect_columns[effect_idx].is_empty then
              line.effect_columns[effect_idx]:clear()
              total_cleared = total_cleared + 1
            end
          end
        end
      end
    end
  end
  
  -- Show appropriate status message
  local scope = all_tracks and "all tracks" or "selected track"
  local range = whole_song and "whole song" or "current pattern"
  if total_cleared > 0 then
    renoise.app():show_status(string.format("Cleared %d effect column entries from %s in %s", 
      total_cleared, scope, range))
  else
    renoise.app():show_status(string.format("No effect column entries found in %s in %s", 
      scope, range))
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Effect Columns on Selected Track on Current Pattern",invoke=function() wipe_effect_columns(false, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Effect Columns on Selected Track on Song",invoke=function() wipe_effect_columns(false, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Effect Columns on Selected Pattern",invoke=function() wipe_effect_columns(true, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Effect Columns on Song",invoke=function() wipe_effect_columns(true, true) end}



function multiply_bpm_halve_lpb()
  local song=renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  
  -- Check if BPM can be doubled
  if current_bpm * 2 > 999 then
    renoise.app():show_status(string.format(
      "Cannot multiply BPM: %.2f * 2 would exceed maximum of 999", current_bpm))
    return
  end
  
  -- Check if LPB can be halved
  if current_lpb / 2 < 1 then
    renoise.app():show_status(string.format(
      "Cannot halve LPB: %d / 2 would be less than minimum of 1", current_lpb))
    return
  end
  
  -- Apply changes
  song.transport.bpm = current_bpm * 2
  song.transport.lpb = current_lpb / 2
  
  renoise.app():show_status(string.format(
    "BPM: %.2f -> %.2f, LPB: %d -> %d", 
    current_bpm, song.transport.bpm,
    current_lpb, song.transport.lpb))
end

-- Function to halve BPM and multiply LPB with bounds checking
function halve_bpm_multiply_lpb()
  local song=renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  
  -- Check if BPM can be halved
  if current_bpm / 2 < 20 then
    renoise.app():show_status(string.format(
      "Cannot halve BPM: %.2f / 2 would be less than minimum of 20", current_bpm))
    return
  end
  
  -- Check if LPB can be doubled
  if current_lpb * 2 > 256 then
    renoise.app():show_status(string.format(
      "Cannot multiply LPB: %d * 2 would exceed maximum of 256", current_lpb))
    return
  end
  
  -- Apply changes
  song.transport.bpm = current_bpm / 2
  song.transport.lpb = current_lpb * 2
  
  renoise.app():show_status(string.format(
    "BPM: %.2f -> %.2f, LPB: %d -> %d", 
    current_bpm, song.transport.bpm,
    current_lpb, song.transport.lpb))
end

renoise.tool():add_keybinding{name="Global:Paketti:Multiply BPM & Halve LPB",invoke=function() multiply_bpm_halve_lpb() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve BPM & Multiply LPB",invoke=function() halve_bpm_multiply_lpb() end}
--------
function sampleFXControls(scope, state)
  local total_affected = 0
  local song=renoise.song()
  
  -- Determine which instruments to process
  local instruments = {}
  if scope == "single" then
    instruments = {song.selected_instrument}
  else -- "all"
    instruments = song.instruments
  end
  
  -- Process the instruments
  for _, instrument in ipairs(instruments) do
    for _, chain in ipairs(instrument.sample_device_chains) do
      -- Start from 2 to skip the first device (volume/pan)
      for j=2, #chain.devices do
        chain.devices[j].is_active = state
        total_affected = total_affected + 1
      end
    end
  end
  
  -- Show status message
  local action = state and "Enabled" or "Disabled"
  local target = scope == "single" and "Selected Instrument" or "All Instruments"
  renoise.app():show_status(string.format("%s %d Sample FX Devices on %s", action, total_affected, target))
end

renoise.tool():add_keybinding{name="Global:Paketti:Bypass All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Enable All Sample FX on Selected Instrument",invoke=function() sampleFXControls("single", true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Bypass All Sample FX on All Instruments",invoke=function() sampleFXControls("all", false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Enable All Sample FX on All Instruments",invoke=function() sampleFXControls("all", true) end}



-----------
function random_note_offs_to_empty_rows()
  local song=renoise.song()
  local random = math.random
  
  -- Get the selection in pattern
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_status("No valid selection in pattern!")
    return
  end
  
  -- Randomize the number of note offs to insert (1-8)
  local note_offs_to_insert = random(1, 8)
  local inserted_count = 0
  
  -- Get pattern info
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  
  -- Create a list of empty rows in the selection
  local empty_rows = {}
  
  -- Iterate through the tracks in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    
    -- Skip tracks with no selected note columns
    if #track_info.note_columns > 0 then
      for _, column_index in ipairs(track_info.note_columns) do
        -- Access the lines within the selected range
        for line_index = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
          local line = pattern.tracks[track_index]:line(line_index)
          local note_column = line:note_column(column_index)
          
          -- Check if the row is empty
          if note_column and note_column.is_empty then
            table.insert(empty_rows, {
              line = line_index,
              track = track_index,
              column = column_index
            })
          end
        end
      end
    end
  end
  
  -- Randomly insert note offs into empty rows
  if #empty_rows > 0 then
    -- Shuffle the empty rows
    for i = #empty_rows, 2, -1 do
      local j = random(i)
      empty_rows[i], empty_rows[j] = empty_rows[j], empty_rows[i]
    end
    
    -- Insert note offs
    for i = 1, math.min(note_offs_to_insert, #empty_rows) do
      local row = empty_rows[i]
      local note_column = pattern.tracks[row.track]:line(row.line):note_column(row.column)
      
      note_column.note_string = "OFF"
      note_column.instrument_value = 255  -- Clear instrument value
      inserted_count = inserted_count + 1
    end
  end
  
  -- Show status message
  if inserted_count > 0 then
    renoise.app():show_status(string.format("Inserted %d random note-offs in empty rows", inserted_count))
  else
    renoise.app():show_status("No empty rows found in selection to insert note-offs")
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Insert Random Note-Offs in Empty Rows",invoke=function() random_note_offs_to_empty_rows() end}
---------
function randomize_note_off_positions()
  local song=renoise.song()
  local random = math.random
  
  -- Get the selection in pattern
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_status("No valid selection in pattern!")
    return
  end
  
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  
  -- Create lists for note offs and empty positions
  local note_offs = {}
  local empty_positions = {}
  
  -- First pass: collect all note offs and empty positions
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    
    if #track_info.note_columns > 0 then
      for _, column_index in ipairs(track_info.note_columns) do
        for line_index = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
          local line = pattern.tracks[track_index]:line(line_index)
          local note_column = line:note_column(column_index)
          
          if note_column then
            if note_column.note_string == "OFF" then
              -- Store note off position
              table.insert(note_offs, {
                line = line_index,
                track = track_index,
                column = column_index
              })
              -- Clear the original note off
              note_column:clear()
            elseif note_column.is_empty then
              -- Store empty position
              table.insert(empty_positions, {
                line = line_index,
                track = track_index,
                column = column_index
              })
            end
          end
        end
      end
    end
  end
  
  -- Check if we have any note offs to randomize
  if #note_offs == 0 then
    renoise.app():show_status("No note-offs found in selection to randomize")
    return
  end
  
  -- Check if we have enough empty positions
  if #empty_positions < #note_offs then
    renoise.app():show_status("Not enough empty positions to randomize note-offs")
    return
  end
  
  -- Shuffle empty positions
  for i = #empty_positions, 2, -1 do
    local j = random(i)
    empty_positions[i], empty_positions[j] = empty_positions[j], empty_positions[i]
  end
  
  -- Place note offs in random empty positions
  for i = 1, #note_offs do
    local pos = empty_positions[i]
    local note_column = pattern.tracks[pos.track]:line(pos.line):note_column(pos.column)
    
    note_column.note_string = "OFF"
    note_column.instrument_value = 255  -- Clear instrument value
  end
  
  renoise.app():show_status(string.format("Randomized positions of %d note-offs", #note_offs))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Randomize Positions of Note-Offs",invoke=function() randomize_note_off_positions() end}


--------
function pakettiFloodFillFromCurrentRow()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local current_line = song.selected_line_index  -- The source row we're copying FROM
  
  -- Get the selection in pattern
  local selection_data = selection_in_pattern_pro()
  if not selection_data then
    renoise.app():show_status("No valid selection in pattern!")
    return
  end

  -- Iterate through the tracks in the selection
  for _, track_info in ipairs(selection_data) do
    local track_index = track_info.track_index
    
    -- Skip tracks with no selected note columns
    if #track_info.note_columns > 0 then
      for _, column_index in ipairs(track_info.note_columns) do
        -- Get the source content from current row
        local source_line = pattern.tracks[track_index]:line(current_line)
        local source_column = source_line:note_column(column_index)
        
        -- Fill the selection with the current row's content
        for line_index = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
          -- Skip the current line since it's our source
          if line_index ~= current_line then
            local line = pattern.tracks[track_index]:line(line_index)
            local note_column = line:note_column(column_index)
            
            -- Copy all values from source
            note_column.note_value = source_column.note_value
            note_column.instrument_value = source_column.instrument_value
            note_column.volume_value = source_column.volume_value
            note_column.panning_value = source_column.panning_value
            note_column.delay_value = source_column.delay_value
            note_column.effect_number_string = source_column.effect_number_string
            note_column.effect_amount_string = source_column.effect_amount_string

            
          end
        end
      end
    end
  end
  RandomizeVoicing()
  -- Randomly choose sorting direction (or none)
  local sort_choice = math.random(1, 3)
  if sort_choice == 1 then
    NoteSorterAscending()
  elseif sort_choice == 2 then
    NoteSorterDescending()
  end
  -- If sort_choice == 3, skip sorting entirely
  GenerateDelayValueNotes("selection")
  renoise.app():show_status("Selection filled with contents of current row")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Flood Fill from Current Row w/ AutoArp",invoke=pakettiFloodFillFromCurrentRow}
--------
function findUsedInstruments()
  local song=renoise.song()
  local used_instruments = {}
  local used_samples = {}
  
  -- Initialize tracking tables for each instrument and sample
  for i=1, #song.instruments do
    used_instruments[i] = false
    used_samples[i] = {}
    for s=1, #song.instruments[i].samples do
      used_samples[i][s] = false
    end
  end
  
  -- Scan through all patterns in the song
  for _, pattern in ipairs(song.patterns) do
    for _, track in ipairs(pattern.tracks) do
      for _, line in ipairs(track.lines) do
        for _, note_column in ipairs(line.note_columns) do
          if note_column.instrument_value < 255 then
            local instr_idx = note_column.instrument_value + 1
            used_instruments[instr_idx] = true
            
            if note_column.note_value < 120 then  -- Valid note
              local instrument = song.instruments[instr_idx]
              if instrument then
                for sample_idx, sample in ipairs(instrument.samples) do
                  if sample.sample_mapping then
                    local note_range = sample.sample_mapping.note_range
                    if note_column.note_value >= note_range[1] and 
                       note_column.note_value <= note_range[2] then
                      used_samples[instr_idx][sample_idx] = true
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  return used_instruments, used_samples
end

function calculateTotalSize(unused_list)
  local total_bytes = 0
  for _, item in ipairs(unused_list) do
    if item.sample_buffer and item.sample_buffer.has_sample_data then
      local sample_size = item.sample_buffer.number_of_frames * 
                         item.sample_buffer.number_of_channels * 
                         (item.sample_buffer.bit_depth / 8)
      total_bytes = total_bytes + sample_size
    end
  end
  return total_bytes
end

function formatFileSize(bytes)
  local units = {'B', 'KB', 'MB', 'GB'}
  local unit_index = 1
  local size = bytes
  
  while size > 1024 and unit_index < #units do
    size = size / 1024
    unit_index = unit_index + 1
  end
  
  return string.format("%.2f %s", size, units[unit_index])
end

function saveUnusedSamples()
  local song=renoise.song()
  local used_instruments, used_samples = findUsedInstruments()
  
  -- Build list of unused samples
  local unused_list = {}
  local unused_instruments = {}
  
  for instr_idx, instrument in ipairs(song.instruments) do
    local has_unused_samples = false
    
    if not used_instruments[instr_idx] then
      for sample_idx, sample in ipairs(instrument.samples) do
        if sample.sample_buffer and sample.sample_buffer.has_sample_data then
          table.insert(unused_list, {
            instrument = instrument,
            sample = sample,
            instr_idx = instr_idx,
            sample_idx = sample_idx
          })
        end
      end
      if #instrument.samples > 0 then
        table.insert(unused_instruments, {
          instrument = instrument,
          instr_idx = instr_idx
        })
      end
    else
      for sample_idx, sample in ipairs(instrument.samples) do
        if not used_samples[instr_idx][sample_idx] and 
           sample.sample_buffer and 
           sample.sample_buffer.has_sample_data then
          table.insert(unused_list, {
            instrument = instrument,
            sample = sample,
            instr_idx = instr_idx,
            sample_idx = sample_idx
          })
          has_unused_samples = true
        end
      end
      if has_unused_samples then
        table.insert(unused_instruments, {
          instrument = instrument,
          instr_idx = instr_idx
        })
      end
    end
  end
  
  if #unused_list == 0 then
    renoise.app():show_status("No unused samples found in the song")
    return
  end

  local dialog_title = string.format(
    "Save %d unused samples - Select destination folder",
    #unused_list
  )
  
  local folder_path = renoise.app():prompt_for_path(dialog_title)
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Save operation cancelled")
    return
  end
  
  -- Save samples
  local saved_count = 0
  local current_instrument_index = song.selected_instrument_index
  local current_sample_index = song.selected_sample_index
  
  for _, item in ipairs(unused_list) do
    song.selected_instrument_index = item.instr_idx
    local safe_instr_name = item.instrument.name:gsub("[^%w%s-]", "_")
    local safe_sample_name = item.sample.name:gsub("[^%w%s-]", "_")
    
    local filename = string.format(
      "%s_-_%03d_-_%s.wav",
      safe_instr_name,
      item.sample_idx,
      safe_sample_name
    )
    
    local full_path = folder_path .. "/" .. filename
    song.selected_sample_index = item.sample_idx
    
    if song.selected_sample.sample_buffer:save_as(full_path, "wav") then
      saved_count = saved_count + 1
    end
  end
  
  -- Save unused instruments as XRNI
  local saved_instruments = 0
  for _, item in ipairs(unused_instruments) do
    song.selected_instrument_index = item.instr_idx
    local safe_name = item.instrument.name:gsub("[^%w%s-]", "_")
    local full_path = folder_path .. "/" .. safe_name .. ".xrni"
    
    renoise.app():save_instrument(full_path)
    saved_instruments = saved_instruments + 1
  end
  
  -- Restore original selection
  song.selected_instrument_index = current_instrument_index
  song.selected_sample_index = current_sample_index
  
  renoise.app():show_status(string.format(
    "Saved %d samples and %d instruments to %s",
    saved_count,
    saved_instruments,
    folder_path
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Save Unused Samples (.WAV&.XRNI)",invoke=saveUnusedSamples}
--------
function saveUnusedInstruments()
  local song=renoise.song()
  local used_instruments, _ = findUsedInstruments()
  
  -- Build list of unused instruments
  local unused_instruments = {}
  
  for instr_idx, instrument in ipairs(song.instruments) do
    if not used_instruments[instr_idx] and #instrument.samples > 0 then
      table.insert(unused_instruments, {
        instrument = instrument,
        instr_idx = instr_idx
      })
    end
  end
  
  if #unused_instruments == 0 then
    renoise.app():show_status("No unused instruments found in the song")
    return
  end

  local dialog_title = string.format(
    "Save %d unused instruments - Select destination folder",
    #unused_instruments
  )
  
  local folder_path = renoise.app():prompt_for_path(dialog_title)
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Save operation cancelled")
    return
  end
  
  -- Save instruments
  local saved_count = 0
  local current_instrument_index = song.selected_instrument_index
  
  for _, item in ipairs(unused_instruments) do
    song.selected_instrument_index = item.instr_idx
    local safe_name = item.instrument.name:gsub("[^%w%s-]", "_")
    local filename = string.format(
      "%03d_%s.xrni",
      item.instr_idx,
      safe_name
    )
    local full_path = folder_path .. "/" .. filename
    
    renoise.app():save_instrument(full_path)
    saved_count = saved_count + 1
  end
  
  -- Restore original selection
  song.selected_instrument_index = current_instrument_index
  
  renoise.app():show_status(string.format(
    "Saved %d unused instruments to %s",
    saved_count,
    folder_path
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Save Unused Instruments (.XRNI)",invoke=saveUnusedInstruments}
----
function deleteUnusedInstruments()
  local song=renoise.song()
  local used_instruments, _ = findUsedInstruments()
  
  -- Build list of unused instruments
  local unused_instruments = {}
  
  for instr_idx, instrument in ipairs(song.instruments) do
    if not used_instruments[instr_idx] and #instrument.samples > 0 then
      table.insert(unused_instruments, {
        instrument = instrument,
        instr_idx = instr_idx
      })
    end
  end
  
  if #unused_instruments == 0 then
    renoise.app():show_status("No unused instruments found in the song")
    return
  end

  -- Ask for confirmation before deletion
  local message = string.format(
    "Are you sure you want to delete %d unused instruments?",
    #unused_instruments
  )
  local ok = renoise.app():show_prompt("Delete Unused Instruments", message, {"Yes", "No"})
  if ok ~= "Yes" then
    renoise.app():show_status("Delete operation cancelled")
    return
  end
  
  -- Delete instruments (starting from highest index to avoid reindexing issues)
  table.sort(unused_instruments, function(a, b) return a.instr_idx > b.instr_idx end)
  local deleted_count = 0
  
  for _, item in ipairs(unused_instruments) do
    song:delete_instrument_at(item.instr_idx)
    deleted_count = deleted_count + 1
  end
  
  renoise.app():show_status(string.format(
    "Deleted %d unused instruments",
    deleted_count
  ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Delete Unused Instruments",invoke=deleteUnusedInstruments}
---
function findUsedSamples()
  local song=renoise.song()
  local used_samples = {}
  local used_notes = {}
  
  -- Initialize tables
  for i = 1, #song.instruments do
    used_samples[i] = {}
    used_notes[i] = {}
  end

  -- First pass: Find all notes being played in the song
  for pattern_idx, pattern in ipairs(song.patterns) do
    for track_idx, track in ipairs(pattern.tracks) do
      for line_idx, line in ipairs(track.lines) do
        if line.note_columns then
          for _, note_col in ipairs(line.note_columns) do
            if note_col.note_value then
              local instr_idx = (note_col.instrument_value or 0) + 1
              if instr_idx <= #song.instruments then
                used_notes[instr_idx][note_col.note_value] = true
              end
            end
          end
        end
      end
    end
  end

  -- Second pass: Check each sample's mappings
  for instr_idx, notes in pairs(used_notes) do
    local instrument = song.instruments[instr_idx]
    if instrument and instrument.sample_mappings then
      for sample_idx = 1, #instrument.samples do
        local mapping = instrument.sample_mappings[1][sample_idx]
        if mapping then
          -- Print velocity range info first
          print(string.format("DEBUG: Sample %d in instrument %d has velocity range [%d,%d]", 
                sample_idx, instr_idx,
                mapping.velocity_range[1], mapping.velocity_range[2]))

          -- Check if velocity range is [0,0]
          if mapping.velocity_range[1] == 0 and mapping.velocity_range[2] == 0 then
            used_samples[instr_idx][sample_idx] = false
            print(string.format("Sample %d in instrument %d is UNUSED - velocity range is [0,0]", 
                  sample_idx, instr_idx))
          else
            -- Only check note mappings if velocity range is valid
            if mapping.note_range then
              for note_value in pairs(notes) do
                if note_value >= mapping.note_range[1] and 
                   note_value <= mapping.note_range[2] then
                  used_samples[instr_idx][sample_idx] = true
                  print(string.format("Sample %d in instrument %d is USED - mapped to note %s (value %d) with velocity range [%d,%d]", 
                        sample_idx,
                        instr_idx,
                        noteValueToName(note_value), 
                        note_value,
                        mapping.velocity_range[1],
                        mapping.velocity_range[2]))
                end
              end
            end
          end
        end
      end
    end
  end

  return used_samples, used_notes
end


-- Helper function to convert note values to note names
function noteValueToName(value)
  if not value or value < 0 or value > 119 then return "---" end
  local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local octave = math.floor(value / 12)
  local note = value % 12
  return string.format("%s%d", notes[note + 1], octave)
end

function deleteUnusedSamples()
  local function process_samples()
    local song=renoise.song()
    local deleted_count = 0
    local notes_found = 0
    local dialog, vb = ProcessSlicer:create_dialog("Deleting Unused Samples")
    local status_text=""
    
    -- Set the width of the progress text
    vb.views.progress_text.width=300

    local function update_dialog(progress, status, is_error)
      if status then
        if is_error then
          status = "ERROR: " .. status
        end
        status_text = status .. "\n" .. status_text
        local lines = {}
        for line in status_text:gmatch("[^\n]+") do
          table.insert(lines, line)
        end
        if #lines > 8 then
          status_text = table.concat({unpack(lines, 1, 8)}, "\n")
        end
      end
      vb.views.progress_text.text = progress .. "\n\n" .. status_text
      coroutine.yield()
    end

    -- First, find all used notes in the song
    local used_notes = {}
    for i = 1, #song.instruments do
      used_notes[i] = {}
    end

    update_dialog("Scanning for used notes...", nil)
    for pattern_idx, pattern in ipairs(song.patterns) do
      for track_idx, track in ipairs(pattern.tracks) do
        for line_idx, line in ipairs(track.lines) do
          for _, note_col in ipairs(line.note_columns) do
            if note_col.note_value and note_col.instrument_value then
              local instr_idx = note_col.instrument_value + 1
              if instr_idx > 0 and instr_idx <= #song.instruments then
                if not used_notes[instr_idx][note_col.note_value] then
                  notes_found = notes_found + 1
                  used_notes[instr_idx][note_col.note_value] = true
                  if notes_found % 10 == 0 then
                    update_dialog(string.format("Scanning pattern %d/%d... (Found %d notes)", 
                      pattern_idx, #song.patterns, notes_found), nil)
                  end
                end
              end
            end
          end
        end
      end
    end
    update_dialog(string.format("Found %d unique notes in total", notes_found), nil)

    -- Process each instrument
    for instr_idx, instrument in ipairs(song.instruments) do
      -- Only process instruments that have samples and sample mappings
      if #instrument.samples > 0 and instrument.sample_mappings[1] then
        -- Check if any sample has slice markers
        local has_slices = false
        for _, sample in ipairs(instrument.samples) do
          if #sample.slice_markers > 0 then
            has_slices = true
            break
          end
        end

        if not has_slices then
          -- Check if instrument is used at all
          local instrument_used = false
          for note, _ in pairs(used_notes[instr_idx]) do
            instrument_used = true
            break
          end

          -- If instrument is not used at all, delete all its samples
          if not instrument_used then
            print(string.format("Instrument %d is completely unused - deleting all samples", instr_idx))
            for sample_idx = #instrument.samples, 1, -1 do
              update_dialog(
                string.format("Processing unused instrument %d/%d", instr_idx, #song.instruments),
                string.format("Deleting sample %d (instrument unused)", sample_idx)
              )
              -- Just delete the sample slot directly since the instrument is unused
              instrument:delete_sample_at(sample_idx)
              deleted_count = deleted_count + 1
            end
          else
            -- Instrument is used, check each sample
            for sample_idx = #instrument.samples, 1, -1 do
              local mapping = instrument.sample_mappings[1][sample_idx]
              if mapping then
                -- Debug print velocity range
                print(string.format("Instrument %d, Sample %d - Velocity Range: [%d,%d]", 
                  instr_idx, sample_idx, 
                  mapping.velocity_range[1], mapping.velocity_range[2]))

                -- Check if this specific sample mapping is used
                local sample_used = false
                if mapping.note_range then
                  for note = mapping.note_range[1], mapping.note_range[2] do
                    if used_notes[instr_idx][note] then
                      sample_used = true
                      break
                    end
                  end
                end

                -- Delete sample if:
                -- 1. It has velocity range [0,0] OR
                -- 2. It's not used in the song (even if velocity range is [0,127])
                if mapping.velocity_range[1] == 0 and mapping.velocity_range[2] == 0 then
                  print(string.format("Deleting sample %d in instrument %d: Velocity range [0,0]", 
                    sample_idx, instr_idx))
                  -- Just delete the slot directly
                  instrument:delete_sample_at(sample_idx)
                  deleted_count = deleted_count + 1
                elseif not sample_used then
                  print(string.format("Deleting sample %d in instrument %d: No used notes in range", 
                    sample_idx, instr_idx))
                  -- Just delete the slot directly
                  instrument:delete_sample_at(sample_idx)
                  deleted_count = deleted_count + 1
                end
              else
                -- No mapping, just delete the slot
                instrument:delete_sample_at(sample_idx)
                deleted_count = deleted_count + 1
              end
            end
          end
        else
          update_dialog(
            string.format("Processing instrument %d/%d", instr_idx, #song.instruments),
            string.format("Skipping instrument %d: Contains sliced samples", instr_idx)
          )
        end
      end
    end

    -- At completion, just change the Cancel button text to Done
    vb.views.cancel_button.text="Done"
    
    update_dialog(
      deleted_count > 0 
        and string.format("Deleted %d unused samples", deleted_count)
        or "Didn't find any unused samples to delete",
      nil
    )
  end
  local slicer = ProcessSlicer(process_samples)
  slicer:start()
end

renoise.tool():add_keybinding{name="Global:Paketti:Delete Unused Samples",invoke=deleteUnusedSamples}
renoise.tool():add_keybinding{name="Sample Keyzones:Paketti:Delete Unused Samples",invoke=deleteUnusedSamples}
--------

-----------
function ReplaceLegacyEffect(old_effect, new_effect)
  local song=renoise.song()
  local pattern_count = #song.patterns
  local changes_made = 0
  
  -- Iterate through all patterns
  for pattern_index = 1, pattern_count do
    local pattern = song:pattern(pattern_index)
    local track_count = #pattern.tracks
    
    -- Iterate through all tracks in pattern
    for track_index = 1, track_count do
      local track = pattern:track(track_index)
      local line_count = pattern.number_of_lines
      
      -- Iterate through all lines in track
      for line_index = 1, line_count do
        local line = track:line(line_index)
        
        -- Check effect columns
        for effect_column_index = 1, #line.effect_columns do
          local effect_column = line.effect_columns[effect_column_index]
          
          -- Check if effect number matches old_effect and replace with new_effect
          if effect_column.number_string == old_effect then
            effect_column.number_string = new_effect
            changes_made = changes_made + 1
          end
        end
      end
    end
  end
  
  -- Show status message with number of changes made
  if changes_made > 0 then
    renoise.app():show_status(string.format("Replaced %d instances of %s with %s", changes_made, old_effect, new_effect))
  else
    renoise.app():show_status(string.format("No %s effects found to replace", old_effect))
  end
end


renoise.tool():add_keybinding{name="Global:Paketti:Replace FC with 0L",invoke=function() ReplaceLegacyEffect("FC", "0L") end}

renoise.tool():add_midi_mapping{name="Paketti:Explode Notes to New Tracks",invoke=function() explode_notes_to_tracks() end}
renoise.tool():add_keybinding{name="Global:Paketti:Explode Notes to New Tracks",invoke=function() explode_notes_to_tracks() end}

  function explode_notes_to_tracks()
    local song=renoise.song()
    local selected_track_index = song.selected_track_index
    local selected_track = song:track(selected_track_index)
    local pattern = song.selected_pattern
    local track_data = pattern:track(selected_track_index)
    
  -- Store original edit mode state
  local original_edit_mode = song.transport.edit_mode
  -- Temporarily disable edit mode
  song.transport.edit_mode = false

    -- Check if there are any notes
    local found_notes = false
    for column_index = 1, selected_track.visible_note_columns do
      for line_index = 1, pattern.number_of_lines do
        local line = track_data:line(line_index)
        local note = line.note_columns[column_index]
        if note.note_value > 0 and note.note_value < 120 then
          found_notes = true
          break
        end
      end
      if found_notes then break end
    end
    
    if not found_notes then
      renoise.app():show_status("There are no notes on the currently selected track, doing nothing.")
      return
    end
  
    -- Store all unique notes and their positions, keeping track of simultaneous notes
    local notes_map = {}
    
    -- Go through all visible note columns
    for line_index = 1, pattern.number_of_lines do
      -- For each line, check all columns for simultaneous notes
      local simultaneous_notes = {}
      
      for column_index = 1, selected_track.visible_note_columns do
        local line = track_data:line(line_index)
        local note = line.note_columns[column_index]
        
        if note.note_value > 0 and note.note_value < 120 then
          local note_name = note_string(note.note_value)
          
          -- Initialize the note map entry if it doesn't exist
          if not notes_map[note_name] then
            notes_map[note_name] = {
              max_simultaneous = 1,
              notes = {}
            }
          end
          
          -- Count simultaneous notes of the same pitch
          if not simultaneous_notes[note_name] then
            simultaneous_notes[note_name] = 1
          else
            simultaneous_notes[note_name] = simultaneous_notes[note_name] + 1
            -- Update the maximum number of simultaneous notes needed
            notes_map[note_name].max_simultaneous = math.max(notes_map[note_name].max_simultaneous, simultaneous_notes[note_name])
          end
          
          -- Store position information for the note
          local note_info = {
            line_index = line_index,
            column_index = simultaneous_notes[note_name], -- Store which column this should go to
            note_value = note.note_value,
            instrument_value = note.instrument_value,
            volume_value = note.volume_value,
            panning_value = note.panning_value,
            note_offs = {}  -- Will store any following note-offs
          }
          
          -- Look ahead for note-offs
          local next_index = line_index + 1
          while next_index <= pattern.number_of_lines do
            local next_line = track_data:line(next_index)
            local next_note = next_line.note_columns[column_index]
            
            if next_note.note_value == 120 then  -- Note-off
              table.insert(note_info.note_offs, next_index)
              next_index = next_index + 1
            else
              break  -- Stop if we find anything other than a note-off
            end
          end
          
          table.insert(notes_map[note_name].notes, note_info)
        end
      end
    end
    
    -- Create new tracks for each unique note
    for note_name, note_data in pairs(notes_map) do
      -- Create new track after the selected track
      song:insert_track_at(selected_track_index + 1)
      local new_track = song:track(selected_track_index + 1)
      new_track.name = note_name .. " Notes"
      
      -- Set the number of visible note columns needed for simultaneous notes
      new_track.visible_note_columns = note_data.max_simultaneous
      
      -- Copy notes to new track
      for _, note_info in ipairs(note_data.notes) do
        local track_data = pattern:track(selected_track_index + 1)
        
        -- Place the note in the appropriate column
        local line = track_data:line(note_info.line_index)
        local note_column = line.note_columns[note_info.column_index]
        note_column.note_value = note_info.note_value
        note_column.instrument_value = note_info.instrument_value
        note_column.volume_value = note_info.volume_value
        note_column.panning_value = note_info.panning_value
        
        -- Place any associated note-offs
        for _, off_index in ipairs(note_info.note_offs) do
          local off_line = track_data:line(off_index)
          off_line.note_columns[note_info.column_index].note_value = 120  -- Note-off
        end
      end
    end
  
    -- Wipe the original track if the preference is enabled
    if preferences.pakettiWipeExplodedTrack.value then
      local original_track_data = pattern:track(selected_track_index)
      for line_index = 1, pattern.number_of_lines do
        local line = original_track_data:line(line_index)
        for column_index = 1, selected_track.visible_note_columns do
          local note = line.note_columns[column_index]
          note:clear()
        end
      end
    end
      -- Restore original edit mode state
  song.transport.edit_mode = original_edit_mode
  end

-- Helper function to convert note value to string
function note_string(note_value)
  local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local note_index = ((note_value - 48) % 12) + 1
  local octave = math.floor((note_value - 48) / 12) + 4
  return notes[note_index] .. octave
end


-------
-- Direction and scope enums
local DIRECTION = { PREVIOUS = 1, NEXT = 2 }
local SCOPE = { TRACK = 1, PATTERN = 2 }
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Next, Track)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.TRACK) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Previous, Track)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.TRACK) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Next, Pattern)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.PATTERN) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Previous, Pattern)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.PATTERN) end}
renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Next, Track)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.TRACK) end}
renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Previous, Track)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.TRACK) end}
renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Next, Pattern)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.PATTERN) end}
renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Previous, Pattern)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.PATTERN) end}
renoise.tool():add_midi_mapping{name="Paketti:Find Note (Next, Track)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.TRACK) end}
renoise.tool():add_midi_mapping{name="Paketti:Find Note (Previous, Track)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.TRACK) end}
renoise.tool():add_midi_mapping{name="Paketti:Find Note (Next, Pattern)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.PATTERN) end}
renoise.tool():add_midi_mapping{name="Paketti:Find Note (Previous, Pattern)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.PATTERN) end}

-- Add playback versions if API supports it
if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Next, Track, Play)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.TRACK, true) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Previous, Track, Play)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.TRACK, true) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Next, Pattern, Play)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.PATTERN, true) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Find Note (Previous, Pattern, Play)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.PATTERN, true) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Next, Track, Play)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.TRACK, true) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Previous, Track, Play)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.TRACK, true) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Next, Pattern, Play)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.PATTERN, true) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Find Note (Previous, Pattern, Play)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.PATTERN, true) end}-- Playback MIDI mappings
  renoise.tool():add_midi_mapping{name="Paketti:Find Note (Next, Track, Play)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.TRACK, true) end}
  renoise.tool():add_midi_mapping{name="Paketti:Find Note (Previous, Track, Play)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.TRACK, true) end}
  renoise.tool():add_midi_mapping{name="Paketti:Find Note (Next, Pattern, Play)",invoke=function() GotoNote(DIRECTION.NEXT, SCOPE.PATTERN, true) end}
  renoise.tool():add_midi_mapping{name="Paketti:Find Note (Previous, Pattern, Play)",invoke=function() GotoNote(DIRECTION.PREVIOUS, SCOPE.PATTERN, true) end}
end

local function has_note_at(track_data, line_index, track_index, column_index)
  local song=renoise.song()
  local track = song:track(track_index)
  local line = track_data:line(line_index)
  
  -- If column_index is provided, check only that column
  if column_index then
    if column_index <= track.visible_note_columns then
      local note = line.note_columns[column_index]
      return note.note_value > 0 and note.note_value < 120
    end
    return false
  end
  
  -- Otherwise check all columns
  for col = 1, track.visible_note_columns do
    local note = line.note_columns[col]
    if note.note_value > 0 and note.note_value < 120 then
      return true
    end
  end
  return false
end

function GotoNote(direction, scope, play_note)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local current_track = song.selected_track_index
  local current_line = song.selected_line_index
  local current_column = song.selected_note_column_index or 1
  
  local function update_position(line_idx, track_idx, col_idx)
    song.selected_line_index = line_idx
    if track_idx then song.selected_track_index = track_idx end
    song.selected_note_column_index = col_idx
    if play_note and renoise.API_VERSION >= 6.2 then
      song:trigger_pattern_line(line_idx)
    end
  end
  
  if scope == SCOPE.TRACK then
    local track_data = pattern:track(current_track)
    local track = song:track(current_track)
    
    if direction == DIRECTION.NEXT then
      -- First try remaining columns in current line
      for col = current_column + 1, track.visible_note_columns do
        if has_note_at(track_data, current_line, current_track, col) then
          update_position(current_line, nil, col)
          return
        end
      end
      
      -- Then try next lines
      for line_index = current_line + 1, pattern.number_of_lines do
        for col = 1, track.visible_note_columns do
          if has_note_at(track_data, line_index, current_track, col) then
            update_position(line_index, nil, col)
            return
          end
        end
      end
      
      -- Wrap to start
      for line_index = 1, current_line do
        for col = 1, track.visible_note_columns do
          if has_note_at(track_data, line_index, current_track, col) then
            update_position(line_index, nil, col)
            return
          end
        end
      end
      
      renoise.app():show_status("No notes found in current track")
      
    else -- DIRECTION.PREVIOUS
      -- First try previous columns in current line
      for col = current_column - 1, 1, -1 do
        if has_note_at(track_data, current_line, current_track, col) then
          update_position(current_line, nil, col)
          return
        end
      end
      
      -- Then try previous lines
      for line_index = current_line - 1, 1, -1 do
        for col = track.visible_note_columns, 1, -1 do
          if has_note_at(track_data, line_index, current_track, col) then
            update_position(line_index, nil, col)
            return
          end
        end
      end
      
      -- Wrap to end
      for line_index = pattern.number_of_lines, current_line, -1 do
        for col = track.visible_note_columns, 1, -1 do
          if has_note_at(track_data, line_index, current_track, col) then
            update_position(line_index, nil, col)
            return
          end
        end
      end
      
      renoise.app():show_status("No notes found in current track")
    end
    
  else -- SCOPE.PATTERN
    if direction == DIRECTION.NEXT then
      -- First check remaining columns in current track/row
      local track = song:track(current_track)
      for col = current_column + 1, track.visible_note_columns do
        if has_note_at(pattern:track(current_track), current_line, current_track, col) then
          update_position(current_line, current_track, col)
          return
        end
      end
      
      -- Then check remaining tracks in current row
      for track_index = current_track + 1, #song.tracks do
        local track_data = pattern:track(track_index)
        local track = song:track(track_index)
        for col = 1, track.visible_note_columns do
          if has_note_at(track_data, current_line, track_index, col) then
            update_position(current_line, track_index, col)
            return
          end
        end
      end
      
      -- Move to next rows
      local start_line = current_line + 1
      if start_line > pattern.number_of_lines then start_line = 1 end
      
      local current_row = start_line
      repeat
        for track_index = 1, #song.tracks do
          local track_data = pattern:track(track_index)
          local track = song:track(track_index)
          for col = 1, track.visible_note_columns do
            if has_note_at(track_data, current_row, track_index, col) then
              update_position(current_row, track_index, col)
              return
            end
          end
        end
        
        current_row = current_row + 1
        if current_row > pattern.number_of_lines then current_row = 1 end
      until current_row == start_line
      
      renoise.app():show_status("No notes found in pattern")
      
    else -- DIRECTION.PREVIOUS
      -- First check previous columns in current track/row
      local track = song:track(current_track)
      for col = current_column - 1, 1, -1 do
        if has_note_at(pattern:track(current_track), current_line, current_track, col) then
          update_position(current_line, current_track, col)
          return
        end
      end
      
      -- Then check previous tracks in current row
      for track_index = current_track - 1, 1, -1 do
        local track_data = pattern:track(track_index)
        local track = song:track(track_index)
        for col = track.visible_note_columns, 1, -1 do
          if has_note_at(track_data, current_line, track_index, col) then
            update_position(current_line, track_index, col)
            return
          end
        end
      end
      
      -- Move to previous rows
      local start_line = current_line - 1
      if start_line < 1 then start_line = pattern.number_of_lines end
      
      local current_row = start_line
      repeat
        for track_index = #song.tracks, 1, -1 do
          local track_data = pattern:track(track_index)
          local track = song:track(track_index)
          for col = track.visible_note_columns, 1, -1 do
            if has_note_at(track_data, current_row, track_index, col) then
              update_position(current_row, track_index, col)
              return
            end
          end
        end
        
        current_row = current_row - 1
        if current_row < 1 then current_row = pattern.number_of_lines end
      until current_row == start_line
      
      renoise.app():show_status("No notes found in pattern")
    end
  end
end

function toggle_two_devices(device1_index, device2_index)
  -- Get current states
  local device1_active = renoise.song().selected_track.devices[device1_index + 1].is_active
  local device2_active = renoise.song().selected_track.devices[device2_index + 1].is_active
  
  -- Handle edge cases first
  if device1_active and device2_active then
      -- Both ON: Turn device2 OFF first
      PakettiDeviceBypass(device2_index, "disable")
      return
  elseif not device1_active and not device2_active then
      -- Both OFF: Turn device1 ON first
      PakettiDeviceBypass(device1_index, "enable")
      return
  end
  
  -- Normal flip case (when one is ON and other is OFF)
  PakettiDeviceBypass(device1_index, device1_active and "disable" or "enable")
  PakettiDeviceBypass(device2_index, device2_active and "disable" or "enable")
end

renoise.tool():add_keybinding{name="Global:Paketti:Flip Devices 1&2 On/Off",invoke=function() toggle_two_devices(1, 2) end}

----------
-- Fuzzy search function
local function fuzzy_match(pattern, str)
  pattern = string.lower(pattern)
  str = string.lower(str)
  
  local pattern_len = #pattern
  local str_len = #str
  local j = 1
  
  for i = 1, pattern_len do
    local pattern_char = pattern:sub(i,i)
    local found = false
    
    while j <= str_len do
      if pattern_char == str:sub(j,j) then
        found = true
        j = j + 1
        break
      end
      j = j + 1
    end
    
    if not found then return false end
  end
  
  return true
end

-- Track fuzzy search dialog
local track_search_dialog = nil
function pakettiFuzzySearchTrackDialog()
  if track_search_dialog and track_search_dialog.visible then
    track_search_dialog:close()
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Store matched tracks for selection
  local matched_tracks = {}
  local results_listbox = nil
  
  local function select_track()
    -- Adjust for the <Empty> row offset
    local actual_index = results_listbox.value - 1
    if actual_index > 0 and actual_index <= #matched_tracks then
      local selected = matched_tracks[actual_index]
      renoise.song().selected_track_index = selected.index
      track_search_dialog:close()
    end
  end

  local function update_search_results(search_text)
    matched_tracks = {}
    local song=renoise.song()
    
    for i = 1, #song.tracks do
      if fuzzy_match(search_text, song.tracks[i].name) then
        table.insert(matched_tracks, {
          index = i,
          name = song.tracks[i].name
        })
      end
    end
    
    -- If exactly one match is found, select it and close immediately
    if #matched_tracks == 1 then
      renoise.song().selected_track_index = matched_tracks[1].index
      track_search_dialog:close()
      return
    end
    
    -- Update chooser items
    local items = {"<Empty>"}
    if #matched_tracks > 0 then
      for _, track in ipairs(matched_tracks) do
        table.insert(items, string.format("%d: %s", track.index, track.name))
      end
    else
      table.insert(items, "No matches found")
    end
    
    results_listbox.items = items
    
    -- If we have results, select the first one automatically
    if #matched_tracks > 0 then
      results_listbox.value = 2  -- Select first actual result
    else
      results_listbox.value = 1  -- Select <Empty>
    end
  end

  local search_field = vb:textfield {
    width=200,
    active = true,
    edit_mode = true,
    notifier=function(text)
      update_search_results(text)
    end
  }
 
  results_listbox = vb:chooser {
    width=200,
    height = 150,
    items = {"<Empty>", "Type to search..."},
    -- Remove the notifier that was auto-selecting
    notifier=function() end  -- Do nothing when selection changes
  }
  
  local PakettiFuzzySearchDialogContent = vb:column{
    vb:text{text="Search for track:", style="strong", font="bold" },
    search_field,
    vb:space { height = 5 },
    results_listbox
  }
   
  track_search_dialog = renoise.app():show_custom_dialog("Paketti Fuzzy Search Track",PakettiFuzzySearchDialogContent,
    function(dialog, key)
      local closer = preferences.pakettiDialogClose.value
      if key.name == closer then
        dialog:close()
        return true
      elseif key.name == "return" then
        if results_listbox.value > 1 then
          -- If we have a real selection (not <Empty>), select the track
          select_track()
          return true
        else
          -- If no selection or <Empty>, focus the textfield
          search_field.active = true
          search_field.edit_mode = true
          return true
        end
      elseif key.name == "up" then
        if results_listbox.value > 2 then
          results_listbox.value = results_listbox.value - 1
        end
        return true
      elseif key.name == "down" then
        if results_listbox.value < #results_listbox.items then
          results_listbox.value = results_listbox.value + 1
        end
        return true
      end
      return false
    end
  )
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Fuzzy Search Track",invoke = pakettiFuzzySearchTrackDialog}
renoise.tool():add_keybinding{name="Mixer:Paketti:Fuzzy Search Track",invoke = pakettiFuzzySearchTrackDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Fuzzy Search Track",invoke = pakettiFuzzySearchTrackDialog}
-----------
local dialog = nil
local show_dialog = nil
local current_scope = 1  -- Add this to store the scope value


function get_unique_notes()
  local song=renoise.song()
  local pattern = song.selected_pattern
  local track = pattern:track(song.selected_track_index)
  local trackvis = renoise.song().selected_track
  local unique_notes = {}
  local order = {}
  
  for line_index = 1, pattern.number_of_lines do
    local line = track:line(line_index)
    for note_index = 1, trackvis.visible_note_columns do
      local note_column = line:note_column(note_index)
      if note_column.note_string ~= "---" and note_column.note_string ~= "OFF" then
        -- Use just the note string as key to group by note regardless of instrument
        local key = note_column.note_string
        if not unique_notes[key] then
          unique_notes[key] = {
            note = note_column.note_string,
            instrument = note_column.instrument_value
          }
          table.insert(order, key)
        end
      end
    end
  end
  
  local ordered_notes = {}
  for _, key in ipairs(order) do
    table.insert(ordered_notes, unique_notes[key])
  end
  
  return ordered_notes
end

function apply_instrument_changes(note_string, original_instrument, new_instrument, whole_song)
  local song=renoise.song()
  
  print("\n=== Instrument Change Debug ===")
  print(string.format("Note: %s", note_string))
  print(string.format("Original Instrument: %02X", original_instrument))
  print(string.format("New Instrument: %02X", new_instrument))
  print(string.format("Whole Song Mode: %s", tostring(whole_song)))
  print(string.format("Total Patterns: %d", #song.patterns))
  print(string.format("Selected Track: %d", song.selected_track_index))
  
  if whole_song then
    -- Apply changes across all patterns
    for pattern_index = 1, #song.patterns do
      local pattern = song.patterns[pattern_index]  -- Changed this line
      local track = pattern:track(song.selected_track_index)
      local trackvis = song.selected_track
      local changes_in_pattern = 0
      
      for line_index = 1, pattern.number_of_lines do
        local line = track:line(line_index)
        for note_index = 1, trackvis.visible_note_columns do
          local note_column = line:note_column(note_index)
          if note_column.note_string == note_string and note_column.instrument_value == original_instrument then
            note_column.instrument_value = new_instrument
            changes_in_pattern = changes_in_pattern + 1
          end
        end
      end
      
      print(string.format("Pattern %d: Changed %d notes", pattern_index, changes_in_pattern))
    end
else
    -- Original behavior for current pattern only
    local pattern = song.selected_pattern
    local track = pattern:track(song.selected_track_index)
    local trackvis = song.selected_track
    local changes = 0
    
    for line_index = 1, pattern.number_of_lines do
      local line = track:line(line_index)
      for note_index = 1, trackvis.visible_note_columns do
        local note_column = line:note_column(note_index)
        if note_column.note_string == note_string and note_column.instrument_value == original_instrument then
          note_column.instrument_value = new_instrument
          changes = changes + 1
        end
      end
    end
    
    print(string.format("Current Pattern: Changed %d notes", changes))
  end
  print("=== End Debug ===\n")
end

function track_change_handler()
  if dialog and dialog.visible then
    show_dialog()
  end
end

function pakettiSwitchNoteInstrumentDialog()
  local dialog = nil

  if dialog and dialog.visible then
    dialog:close()
  end

  local song=renoise.song()


  -- Create track options for dropdown
  local track_options = {}
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    track_options[i] = string.format("%02d: %s", i, track.name)
  end

  local instrument_options = {}
  for i = 0, 255 do
    local instrument = song.instruments[i + 1]
    if instrument then
      local name = instrument.name
      if name == "" then name = string.format("Instrument %02X", i) end
      instrument_options[i + 1] = string.format("%02X: %s", i, name)
    end
  end

  -- Declare show_dialog function first
-- Declare show_dialog function first

  function show_dialog()
    if dialog and dialog.visible then
      -- Store current scope before closing
      current_scope = dialog.views.scope_switch.value
      dialog:close()
    end

    local vb = renoise.ViewBuilder()
    local unique_notes = get_unique_notes()
    local content = vb:column{     
      vb:row{
        vb:text{text="Track",width=40},
        vb:popup{
          width=250,
          items = track_options,
          value = song.selected_track_index,
          notifier=function(new_index)
            song.selected_track_index = new_index
            show_dialog()
          end
        }
      },
      vb:row{
        margin=4,
        vb:text{text="Scope",width=40},
        vb:switch{
          id = "scope_switch",
          width=250,
          items = {"Current Pattern", "Whole Song"},
          value = current_scope  -- Use stored scope value
        }
      }
    }

        
    -- Add header and notes if we have them
    if #unique_notes > 0 then
      content:add_child(
        vb:row{
          vb:text{text="Note",width=40, font="bold", style="strong"},
          vb:text{text="Instrument",width=250, font="bold", style="strong"}
        }
      )
      
      for _, note_data in ipairs(unique_notes) do
        content:add_child(
          vb:row{
            vb:text{text = note_data.note,width=40, font = "mono", style="strong"},
            vb:popup{
              width=250,
              items = instrument_options,
              value = note_data.instrument + 1,
              notifier=function(new_index)
                local scope_whole_song = (vb.views.scope_switch.value == 2)
                apply_instrument_changes(note_data.note, note_data.instrument, new_index - 1, scope_whole_song)
              end
            }
          }
        )
      end
    else
      content:add_child(
        vb:text{
          text="No notes on this track, select another one.",
          font = "bold",
          style = "strong"
        }
      )
    end
    
    dialog = renoise.app():show_custom_dialog("Switch Note Instrument Dialog",content,NoteToInstrumentKeyhandler)
    renoise.app().window.active_middle_frame = patternEditor
  end

  -- Remove any existing notifiers first
  if song.selected_track_index_observable:has_notifier(show_dialog) then
    song.selected_track_index_observable:remove_notifier(show_dialog)
  end
  if song.selected_pattern_index_observable:has_notifier(show_dialog) then
    song.selected_pattern_index_observable:remove_notifier(show_dialog)
  end

  -- Add notifiers
  song.selected_track_index_observable:add_notifier(show_dialog)
  song.selected_pattern_index_observable:add_notifier(show_dialog)



  -- Show initial dialog
  show_dialog()
  
  -- Add notifier for track changes
--  song.selected_track_index_observable:add_notifier(show_dialog)
  
  renoise.app().window.active_middle_frame = patternEditor
end

function NoteToInstrumentKeyhandler(dialog,key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    local song=renoise.song()
    -- Clean up notifiers when closing
    if song.selected_track_index_observable:has_notifier(show_dialog) then
      song.selected_track_index_observable:remove_notifier(show_dialog)
    end
    if song.selected_pattern_index_observable:has_notifier(show_dialog) then
      song.selected_pattern_index_observable:remove_notifier(show_dialog)
    end
    dialog:close()
    dialog = nil
    return nil
  else
    return key
  end
end
  
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Switch Note Instrument Dialog...",invoke=pakettiSwitchNoteInstrumentDialog}
------------------------------
function paketti_wrap_signed_as_unsigned()
  local instr=renoise.song().selected_instrument
  if not instr or #instr.samples==0 then renoise.app():show_status("No sample found.") return end
  local smp=instr.samples[renoise.song().selected_sample_index]
  if not smp.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample buffer.") return end

  local buf=smp.sample_buffer
  buf:prepare_sample_data_changes()
  for c=1,buf.number_of_channels do
    for f=1,buf.number_of_frames do
      local val=buf:sample_data(c,f)
      local i16=math.floor(val*32768)
      local u16=(i16+65536)%65536
      local out=((u16/65535)*2.0)-1.0
      buf:set_sample_data(c,f,math.max(-1.0,math.min(1.0,out)))
    end
  end
  buf:finalize_sample_data_changes()

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app():show_status("Wrapped signed buffer as unsigned. You wanted broken? You got it.")
end

function paketti_unwrap_unsigned_as_signed()
  local instr=renoise.song().selected_instrument
  if not instr or #instr.samples==0 then renoise.app():show_status("No sample found.") return end
  local smp=instr.samples[renoise.song().selected_sample_index]
  if not smp.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample buffer.") return end

  local buf=smp.sample_buffer
  buf:prepare_sample_data_changes()
  for c=1,buf.number_of_channels do
    for f=1,buf.number_of_frames do
      local val=buf:sample_data(c,f)
      local u16=math.floor(((val+1.0)*0.5)*65535)
      local i16=(u16>=32768) and (u16-65536) or u16
      local out=i16/32768
      buf:set_sample_data(c,f,math.max(-1.0,math.min(1.0,out)))
    end
  end
  buf:finalize_sample_data_changes()

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app():show_status("Unwrapped unsigned values back to signed.")
end

renoise.tool():add_keybinding {name="Sample Editor:Paketti:Wrap Signed as Unsigned",invoke=paketti_wrap_signed_as_unsigned}
renoise.tool():add_keybinding {name="Sample Editor:Paketti:Unwrap Unsigned to Signed",invoke=paketti_unwrap_unsigned_as_signed}

function paketti_toggle_signed_unsigned()
  local instr=renoise.song().selected_instrument
  if not instr or #instr.samples==0 then renoise.app():show_status("No sample found.") return end
  local smp=instr.samples[renoise.song().selected_sample_index]
  if not smp.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample buffer.") return end

  local buf=smp.sample_buffer
  local frames=math.min(512, buf.number_of_frames)
  local avg=0
  for f=1,frames do
    avg=avg+buf:sample_data(1,f)
  end
  avg=avg/frames

  local unwrap=(avg>0.25) -- if mean is high, likely unsigned-wrap

  buf:prepare_sample_data_changes()
  for c=1,buf.number_of_channels do
    for f=1,buf.number_of_frames do
      local val=buf:sample_data(c,f)
      local out
      if unwrap then
        local u16=math.floor(((val+1.0)*0.5)*65535)
        local i16=(u16>=32768) and (u16-65536) or u16
        out=i16/32768
      else
        local i16=math.floor(val*32768)
        local u16=(i16+65536)%65536
        out=((u16/65535)*2.0)-1.0
      end
      buf:set_sample_data(c,f,math.max(-1.0,math.min(1.0,out)))
    end
  end
  buf:finalize_sample_data_changes()

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  local msg=unwrap and "Unwrapped unsigned to signed." or "Wrapped signed to unsigned."
  renoise.app():show_status(msg)
end


renoise.tool():add_keybinding {name="Sample Editor:Paketti:Toggle Signed/Unsigned",invoke=paketti_toggle_signed_unsigned}


--
function paketti_float_unsign()
  local instr=renoise.song().selected_instrument
  if not instr or #instr.samples==0 then renoise.app():show_status("No sample found.") return end
  local smp=instr.samples[1]
  if not smp.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample buffer.") return end

  local buf=smp.sample_buffer
  buf:prepare_sample_data_changes()
  for c=1,buf.number_of_channels do
    for f=1,buf.number_of_frames do
      local val=buf:sample_data(c,f)
      buf:set_sample_data(c,f,(val+1.0)*0.5)
    end
  end
  buf:finalize_sample_data_changes()

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app():show_status("Sample scaled: signed → unsigned.")
end

function paketti_float_sign()
  local instr=renoise.song().selected_instrument
  if not instr or #instr.samples==0 then renoise.app():show_status("No sample found.") return end
  local smp=instr.samples[1]
  if not smp.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample buffer.") return end

  local buf=smp.sample_buffer
  buf:prepare_sample_data_changes()
  for c=1,buf.number_of_channels do
    for f=1,buf.number_of_frames do
      local val=buf:sample_data(c,f)
      buf:set_sample_data(c,f,(val*2.0)-1.0)
    end
  end
  buf:finalize_sample_data_changes()

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app():show_status("Sample scaled: unsigned → signed.")
end



---------
function paketti_build_sample_variants()
  local instr=renoise.song().selected_instrument
  if not instr then renoise.app():show_status("No instrument selected.") return end
  local base_idx=renoise.song().selected_sample_index
  local base=instr.samples[base_idx]
  if not base then renoise.app():show_status("No sample selected.") return end
  if not base.sample_buffer.has_sample_data then renoise.app():show_status("Empty sample.") return end

  local name=base.name

  local function clone_and_process(label, transform)
    local new=instr:insert_sample_at(#instr.samples+1)
    new:copy_from(base)
    new.name=name.." ("..label..")"
    new.volume=0.0  -- Set volume to -INF dB so user can fade them in manually

    local buf=new.sample_buffer
    buf:prepare_sample_data_changes()
    for c=1,buf.number_of_channels do
      for f=1,buf.number_of_frames do
        local val=buf:sample_data(c,f)
        buf:set_sample_data(c,f,math.max(-1.0,math.min(1.0,transform(val))))
      end
    end
    buf:finalize_sample_data_changes()
  end

  clone_and_process("wrapped", function(val)
    local i16=math.floor(val*32768)
    local u16=(i16+65536)%65536
    return ((u16/65535)*2.0)-1.0
  end)

  clone_and_process("unwrapped", function(val)
    local u16=math.floor(((val+1.0)*0.5)*65535)
    local i16=(u16>=32768) and (u16-65536) or u16
    return i16/32768
  end)

  clone_and_process("scaled unsigned", function(val)
    return (val+1.0)*0.5
  end)

  clone_and_process("scaled signed", function(val)
    return (val*2.0)-1.0
  end)

  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app():show_status("Created 4 wrecked variants of sample: "..name)
end


---
-- big-endian 16-bit reader, 1-based
local function read_be_u16(str, pos)
  local b1,b2 = str:byte(pos,pos+1)
  return b1*256 + b2
end

-- determine where in a 4-ch/31-sample .mod the sample data begins
local function find_mod_sample_data_offset(data)
  -- song length
  local song_len = data:byte(951)
  -- pattern table
  local patt = { data:byte(953, 953+127) }
  local maxp = 0
  for i=1,song_len do
    if patt[i] and patt[i]>maxp then maxp = patt[i] end
  end
  local num_patterns = maxp + 1

  -- channel count from bytes 1081–1084
  local id = data:sub(1081,1084)
  local channels = ({
    ["M.K."]=4, ["4CHN"]=4, ["6CHN"]=6,
    ["8CHN"]=8, ["FLT4"]=4, ["FLT8"]=8
  })[id] or 4

  -- offset = 1084 (end of header) + pattern_data_size
  local pattern_data_size = num_patterns * 64 * channels * 4
  return 1084 + pattern_data_size
end

function pakettiLoadExeAsSample(file_path)
  local f = io.open(file_path,"rb")
  if not f then 
    renoise.app():show_status("Could not open file: "..file_path)
    return 
  end
  local data = f:read("*all")
  f:close()
  if #data == 0 then 
    renoise.app():show_status("File is empty.") 
    return 
  end

  -- detect .mod by extension or signature
  local is_mod = file_path:lower():match("%.mod$")
  if not is_mod then
    -- maybe detect signature too?
    local sig = data:sub(1081,1084)
    if sig:match("^[46]CHN$") or sig=="M.K." or sig=="FLT4" or sig=="FLT8" then
      is_mod = true
    end
  end

  local raw
  if is_mod then
    -- strip header & patterns
    local off = find_mod_sample_data_offset(data)
    -- Lua strings are 1-based, so data:sub(off+1) if off bytes are header
    raw = data:sub(off+1)
  else
    raw = data
  end

  -- now load raw as before
  local name = file_path:match("([^\\/]+)$") or "Sample"
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index =
    renoise.song().selected_instrument_index + 1
  pakettiPreferencesDefaultInstrumentLoader()

  local instr = renoise.song().selected_instrument
  instr.name = name

  local smp = instr:insert_sample_at(#instr.samples+1)
  smp.name = name

  -- 8363 Hz, 8-bit, mono
  local length = #raw
  smp.sample_buffer:create_sample_data(8363, 8, 1, length)

  local buf = smp.sample_buffer
  buf:prepare_sample_data_changes()
  for i = 1, length do
    local byte = raw:byte(i)
    local val  = (byte / 255) * 2.0 - 1.0
    buf:set_sample_data(1, i, val)
  end
  buf:finalize_sample_data_changes()

  -- clean up any “Placeholder sample” left behind
  for i = #instr.samples, 1, -1 do
    if instr.samples[i].name == "Placeholder sample" then
      instr:delete_sample_at(i)
    end
  end

  renoise.app().window.active_middle_frame =
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

  local what = is_mod and "MOD samples" or "bytes"
  renoise.app():show_status(
    ("Loaded %q as 8-bit-style sample (%d %s at 8363Hz).")
    :format(name, length, what)
  )
end


renoise.tool():add_file_import_hook{category="sample",extensions={"exe","dll","bin","sys","dylib","png","jpg","jpeg","gif","bmp"},invoke=pakettiLoadExeAsSample}
---
--------


------
function ConvertChordsToArpeggio()
  local s = renoise.song()
  local track_index = s.selected_track_index
  local line_index = s.selected_line_index
  local pattern = s.selected_pattern
  local track = s.tracks[track_index]
  
  -- Make sure we have at least 3 visible note columns
  if track.visible_note_columns < 3 then
      renoise.app():show_status("Need at least 3 visible note columns to convert chords to arpeggio.")
      return
  end
  
  -- Get the current line
  local line = pattern.tracks[track_index].lines[line_index]
  
  -- Read the 3 note columns
  local note1 = line.note_columns[1]
  local note2 = line.note_columns[2]
  local note3 = line.note_columns[3]
  
  -- Check if we have valid notes in all 3 columns
  if note1.is_empty or note2.is_empty or note3.is_empty then
      renoise.app():show_status("Need notes in all 3 note columns to convert to arpeggio.")
      return
  end
  
  -- Check if any note is NOTE OFF or invalid
  if note1.note_value >= 120 or note2.note_value >= 120 or note3.note_value >= 120 then
      renoise.app():show_status("Cannot convert NOTE OFF or invalid notes to arpeggio.")
      return
  end
  
  print("Before sorting - Note1: " .. note1.note_value .. ", Note2: " .. note2.note_value .. ", Note3: " .. note3.note_value)
  
  -- FIRST: Run NoteSorterAscending function
  NoteSorterAscending()
  
  -- Re-read the notes after sorting
  note1 = line.note_columns[1]
  note2 = line.note_columns[2] 
  note3 = line.note_columns[3]
  
  print("After sorting - Note1: " .. note1.note_value .. ", Note2: " .. note2.note_value .. ", Note3: " .. note3.note_value)
  
  -- Calculate semitone differences from the first note
  local base_note = note1.note_value
  local diff2 = note2.note_value - base_note
  local diff3 = note3.note_value - base_note
  
  print("Differences - Note2: +" .. diff2 .. " semitones, Note3: +" .. diff3 .. " semitones")
  
  -- Check if differences exceed arpeggio range (0-F = 0-15)
  if diff2 > 15 or diff3 > 15 then
      renoise.app():show_status("These notes are higher than the Arpeggio command lets you Arpeggiate at (0...F), doing nothing")
      return
  end
  
  -- Convert differences to hex
  local hex2 = string.format("%X", diff2)
  local hex3 = string.format("%X", diff3)
  
  print("Hex differences - Note2: " .. hex2 .. ", Note3: " .. hex3)
  
  -- Replace note columns 2 and 3 with NOTE OFF (120)
  note2.note_value = 120
  note2.instrument_string = ".."
  note3.note_value = 120
  note3.instrument_string = ".."

  -- Make sure first effect column is visible
  if track.visible_effect_columns < 1 then
      track.visible_effect_columns = 1
  end
  
  -- Write the arpeggio command starting from current line until next note
  local arpeggio_command = "0A"
  local arpeggio_amount = hex2 .. hex3
  local lines_written = 0
  
  -- Start from current line and continue until we find another note or reach end of pattern
  for current_line = line_index, pattern.number_of_lines do
    local check_line = pattern.tracks[track_index].lines[current_line]
    
    -- Check if this line has any notes in visible note columns (skip the first line since we're processing it)
    local has_note = false
    if current_line > line_index then
      for col = 1, track.visible_note_columns do
        local note_col = check_line.note_columns[col]
        if not note_col.is_empty and note_col.note_value < 120 then
          has_note = true
          break
        end
      end
    end
    
    -- If we found a note on a later line, stop writing arpeggio commands
    if has_note then
      break
    end
    
    -- Write the arpeggio command to this line
    check_line.effect_columns[1].number_string = arpeggio_command
    check_line.effect_columns[1].amount_string = arpeggio_amount
    lines_written = lines_written + 1
  end
  
  print("Written arpeggio command: " .. arpeggio_command .. arpeggio_amount .. " to " .. lines_written .. " lines")
  renoise.app():show_status("Converted chord to arpeggio: " .. arpeggio_command .. arpeggio_amount .. " (written to " .. lines_written .. " lines)")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Convert 3 Note Chord to Arpeggio", invoke=function() ConvertChordsToArpeggio() end}


