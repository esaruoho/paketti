-- Variable to store the original solo and mute states
local track_states = {}

function create_render_context(muteOriginal, justwav, newtrack, timestretch_mode, current_bpm)
    return {
        source_track = 0,
        target_track = 0,
        target_instrument = 0,
        temp_file_path = "",
        num_tracks_before = 0,  -- Add this to keep track of the original number of tracks
        muteOriginal = muteOriginal or false,
        justwav = justwav or false,
        newtrack = newtrack or false,
        timestretch_mode = timestretch_mode or false,
        current_bpm = current_bpm or nil
    }
end

function pakettiCleanRenderSelection(muteOriginal, justwav, newtrack, timestretch_mode, current_bpm)
    -- Set defaults if not provided
    muteOriginal = muteOriginal or false
    justwav = justwav or false  
    newtrack = newtrack or false
    timestretch_mode = timestretch_mode or false
    current_bpm = current_bpm or nil
    
    print("DEBUG 1: pakettiCleanRenderSelection called with muteOriginal =", muteOriginal, "justwav =", justwav, "newtrack =", newtrack, "timestretch_mode =", timestretch_mode)
    local song=renoise.song()
    local renderTrack = song.selected_track_index
    local renderedTrack = renderTrack + 1
    local renderedInstrument = song.selected_instrument_index + 1

    -- Create New Instrument
    song:insert_instrument_at(renderedInstrument)

    -- Select New Instrument
    song.selected_instrument_index = renderedInstrument

    -- Create a new render context with the parameters
    local render_context = create_render_context(muteOriginal, justwav, newtrack, timestretch_mode, current_bpm)
    print("DEBUG 2: render_context - muteOriginal:", render_context.muteOriginal, "justwav:", render_context.justwav, "newtrack:", render_context.newtrack, "timestretch_mode:", render_context.timestretch_mode)

    -- Check if the selected track is a group track
    if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
        print("DEBUG 3: Calling render_group_track")
        -- Render the group track
        render_group_track(render_context)
    else
        print("DEBUG 3: Calling start_rendering")
        -- Start rendering
        start_rendering(render_context)
    end
end

function start_rendering(render_context)
    local song=renoise.song()
    local render_priority = "high"
    local selected_track = song.selected_track
    local dc_offset_added = false
    local dc_offset_position = 0  -- Track where we find or add the DC Offset
    
    print("DEBUG 4: start_rendering - muteOriginal:", render_context.muteOriginal, "justwav:", render_context.justwav, "newtrack:", render_context.newtrack, "timestretch_mode:", render_context.timestretch_mode)

    -- Timestretch mode: explicitly set BPM if provided
    if render_context.timestretch_mode and render_context.current_bpm then
        print("DEBUG: Timestretch mode - setting BPM to", render_context.current_bpm)
        song.transport.bpm = render_context.current_bpm
    end

    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
            break
        end
    end

    -- Add DC Offset if enabled in preferences and not already present
    if preferences.RenderDCOffset.value then
        print("DEBUG DC: RenderDCOffset preference is enabled")
        -- First check if DC Offset already exists and find its position
        for i, device in ipairs(selected_track.devices) do
            if device.display_name == "Render DC Offset" then
                dc_offset_position = i
                print("DEBUG DC: Found existing DC Offset at position", i)
                break
            end
        end
        
        if dc_offset_position == 0 then
            print("DEBUG DC: Adding DC Offset to track", song.selected_track_index)
            loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
            
            -- Find the newly added DC Offset and its position
            for i, device in ipairs(selected_track.devices) do
                if device.display_name == "Render DC Offset" then
                    dc_offset_position = i
                    device.parameters[2].value = 1
                    dc_offset_added = true
                    print("DEBUG DC: Added new DC Offset at position", i)
                    break
                end
            end
            
            if not dc_offset_added then
                print("DEBUG DC: WARNING - Failed to find DC Offset after adding")
                print("DEBUG DC: Current devices on track:")
                for i, dev in ipairs(selected_track.devices) do
                    print(string.format("DEBUG DC: Device %d - name: %s, display_name: %s", 
                        i, dev.name or "nil", dev.display_name or "nil"))
                end
            end
        end
    else
        print("DEBUG DC: RenderDCOffset preference is disabled")
    end

    -- Store DC Offset information in render context
    render_context.dc_offset_added = dc_offset_added
    render_context.dc_offset_track_index = song.selected_track_index
    render_context.dc_offset_position = dc_offset_position
    print("DEBUG DC: Stored DC Offset info - added:", dc_offset_added, 
          "track:", song.selected_track_index, 
          "position:", dc_offset_position)

    -- Set up rendering options
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(song.selected_sequence_index, 1),
        end_pos = renoise.SongPos(song.selected_sequence_index, song.patterns[song.selected_pattern_index].number_of_lines),
    }

    -- Save current solo and mute states
    track_states = {}
    render_context.num_tracks_before = #song.tracks
    print("DEBUG CLEAN: Saving solo/mute states for", render_context.num_tracks_before, "tracks")
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
        if track.solo_state then
            print("DEBUG CLEAN: Track", i, "was soloed")
        end
    end

    -- Solo the selected track and unsolo others
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    song.tracks[song.selected_track_index].solo_state = true

    -- Update render context values
    render_context.source_track = song.selected_track_index
    render_context.target_track = song.selected_track_index + 1
    render_context.target_instrument = song.selected_instrument_index + 1
    render_context.temp_file_path = pakettiGetTempFilePath(".wav")

    -- Start rendering
    local success, error_message = song:render(render_options, render_context.temp_file_path, function() rendering_done_callback(render_context) end)
    if not success then
        print("Rendering failed: " .. error_message)
        -- Remove DC Offset if it was added
        if preferences.RenderDCOffset.value then
            local last_device = selected_track.devices[#selected_track.devices]
            if last_device.display_name == "Render DC Offset" then
                selected_track:delete_device_at(#selected_track.devices)
            end
        end
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(monitor_rendering, 500)
    end
end

function rendering_done_callback(render_context)
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    print("DEBUG 7: rendering_done_callback started - muteOriginal:", render_context.muteOriginal, "justwav:", render_context.justwav, "newtrack:", render_context.newtrack)
    local song=renoise.song()
    local renderTrack = render_context.source_track

    -- Handle DC Offset removal
    if render_context.dc_offset_position > 0 then  -- If we found or added DC Offset
        print("DEBUG DC: Checking for DC Offset at position", render_context.dc_offset_position)
        local track = song:track(render_context.dc_offset_track_index)
        
        -- Verify the device is still there and is still DC Offset
        if track and track.devices[render_context.dc_offset_position] and
           track.devices[render_context.dc_offset_position].display_name == "Render DC Offset" then
            print("DEBUG DC: Removing DC Offset from position", render_context.dc_offset_position)
            track:delete_device_at(render_context.dc_offset_position)
            print("DEBUG DC: Successfully removed DC Offset")
        else
            print("DEBUG DC: WARNING - DC Offset not found at expected position", render_context.dc_offset_position)
            -- Double check if it moved somewhere else
            for i, device in ipairs(track.devices) do
                if device.display_name == "Render DC Offset" then
                    print("DEBUG DC: Found DC Offset at different position", i, "- removing")
                    track:delete_device_at(i)
                    print("DEBUG DC: Successfully removed DC Offset from position", i)
                    break
                end
            end
        end
    else
        print("DEBUG DC: No DC Offset position stored")
    end

    local renderedTrack = renderTrack + 1
    local renderedInstrument = render_context.target_instrument

    -- Remove the monitoring timer
    renoise.tool():remove_timer(monitor_rendering)

    -- First, explicitly unsolo AND unmute ALL sequencer tracks
    for i = 1, song.sequencer_track_count do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end

    -- Then handle send tracks separately (starting after master track)
    local send_track_start = song.sequencer_track_count + 2  -- +2 to skip master track
    for i = send_track_start, send_track_start + song.send_track_count - 1 do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end

    -- Then restore the original solo and mute states only for the tracks that existed before rendering
    print("DEBUG CLEAN: Restoring solo/mute states for", render_context.num_tracks_before, "tracks")
    for i = 1, render_context.num_tracks_before do
        if track_states[i] then
            song.tracks[i].solo_state = track_states[i].solo_state
            song.tracks[i].mute_state = track_states[i].mute_state
            if track_states[i].solo_state then
                print("DEBUG CLEAN: Restored solo state for track", i)
            end
        end
    end

    -- 1) ALWAYS: Load default instrument and create sample
    local renderedInstrument = render_context.target_instrument
    local renderName = song.tracks[renderTrack].name
    
    pakettiPreferencesDefaultInstrumentLoader()
    local new_instrument = song:instrument(song.selected_instrument_index)
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)
    
    -- Set the selected_instrument_index to the newly created instrument
    song.selected_instrument_index = renderedInstrument - 1
    
    -- Rename instrument and sample (different for timestretch mode)
    if render_context.timestretch_mode then
        -- Timestretch naming: "120BPM 4LPB C-4"
        local bpm = render_context.current_bpm or song.transport.bpm
        local lpb = song.transport.lpb
        
        -- Get the current note from the pattern
        local pattern = song.patterns[song.selected_pattern_index]
        local track = pattern:track(song.selected_track_index)
        local note_val = track:line(1).note_columns[1].note_value
        local note = note_val % 12
        local octave = math.floor(note_val / 12)
        local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
        
        local timestretch_name = string.format("%dBPM %dLPB %s%d", bpm, lpb, note_names[note + 1], octave)
        new_instrument.name = timestretch_name
        new_instrument.samples[1].name = timestretch_name
        
        -- Add *Instr. Macros for timestretch mode
        if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
            loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
            song.selected_track.devices[2].is_maximized = false
        end
        
        -- Toggle edit mode for timestretch mode
        if song.transport.edit_mode then
            song.transport.edit_mode = false
            song.transport.edit_mode = true
        else
            song.transport.edit_mode = true
            song.transport.edit_mode = false
        end
    else
        -- Standard naming: "Track Name (Rendered)"
        new_instrument.name = renderName .. " (Rendered)"
        new_instrument.samples[1].name = renderName .. " (Rendered)"
    end
    new_instrument.samples[1].autofade = true

    -- 2) If muteOriginal: mute/disable/collapse original track
    if render_context.muteOriginal then
        print("DEBUG: Muting original track")
        -- Turn All Render Track Note Columns to "Off"
        for i = 1, song.tracks[renderTrack].max_note_columns do
            song.tracks[renderTrack]:set_column_is_muted(i, true)
        end

        if preferences.renderBypass.value == true then 
            for i = 2, #song.selected_track.devices do
                song.selected_track.devices[i].is_active = false
            end
        end

        -- Collapse Render Track
        song.tracks[renderTrack].collapsed = true
    else
        print("DEBUG: Preserving original track")
    end

    -- 3) If newtrack: create new track with C-4 0G01
    if render_context.newtrack then
        print("DEBUG: Creating new track with C-4 0G01")
        local renderedTrack = renderTrack + 1
        
        -- Insert New Track Next to Render Track
        song:insert_track_at(renderedTrack)
        
        -- Change Selected Track to Rendered Track
        song.selected_track_index = renderedTrack

        -- Ensure we are editing the correct pattern
        local selected_pattern_index = song.selected_pattern_index
        local pattern_track = song.patterns[selected_pattern_index]:track(renderedTrack)

        -- Place the note in the new track
        pattern_track:line(1).note_columns[1].note_string = "C-4"
        pattern_track:line(1).note_columns[1].instrument_value = song.selected_instrument_index - 1
        pattern_track:line(1).effect_columns[1].number_string="0G"
        pattern_track:line(1).effect_columns[1].amount_string="01"

        -- Add *Instr. Macros to selected Track
        if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
            loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
            song.selected_track.devices[2].is_maximized = false
        end

        -- Rename New Track using Render Track Name
        song.tracks[renderedTrack].name = renderName .. " (Rendered)"
        
        -- Toggle edit mode (refresh)
        if song.transport.edit_mode then
            song.transport.edit_mode = false
            song.transport.edit_mode = true
        else
            song.transport.edit_mode = true
            song.transport.edit_mode = false
        end

        -- Final muting if muteOriginal is also enabled
        if render_context.muteOriginal then
            print("DEBUG: Applying final muting")
            renoise.song().selected_track.mute_state = 1
            for i=1,#song.tracks do
                renoise.song().tracks[i].mute_state = 1
            end 
        else
            -- Ensure the new track is not muted
            song.tracks[renderedTrack].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    else
        print("DEBUG: No new track created - only instrument")
    end
    
    -- 4) If timestretch_mode: mute ALL tracks at the end
    if render_context.timestretch_mode then
        print("DEBUG: Timestretch mode - muting ALL tracks")
        song.selected_track.mute_state = 1
        for i=1,#song.tracks do
            song.tracks[i].mute_state = 1
        end 
    end
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to monitor rendering progress
function monitor_rendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Rendering in progress: " .. (progress * 100) .. "% complete")
    else
        -- Remove the monitoring timer once rendering is complete or if it wasn't started
        renoise.tool():remove_timer(monitor_rendering)
        print("Rendering not in progress or already completed.")
    end
end

-- Function to handle rendering for a group track
function render_group_track(render_context)
    local song=renoise.song()
    local group_track_index = song.selected_track_index
    local group_track = song:track(group_track_index)

    -- First verify we have a valid group track
    if not group_track or group_track.type ~= renoise.Track.TRACK_TYPE_GROUP then
        renoise.app():show_status("Selected track is not a group track")
        return
    end

    -- Save current solo and mute states
    track_states = {}
    render_context.num_tracks_before = #song.tracks
    print("DEBUG GROUP: Saving solo/mute states for", render_context.num_tracks_before, "tracks")
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
        if track.solo_state then
            print("DEBUG GROUP: Track", i, "was soloed")
        end
    end

    -- Unsolo all tracks and solo just the group track
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    group_track.solo_state = true
    print("DEBUG GROUP: Soloed group track", group_track_index)

    -- Start rendering with the render_context
    start_rendering(render_context)
end

-- pakettiCleanRenderSelection(muteOriginal, justwav, newtrack, timestretch_mode, current_bpm)
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection(true, false, true, false, nil) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Selected Track/Group (WAV Only)",invoke=function() pakettiCleanRenderSelection(false, true, false, false, nil) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection(true, false, true, false, nil) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Selected Track/Group (WAV Only)",invoke=function() pakettiCleanRenderSelection(false, true, false, false, nil) end}





--------
--------
-- TODO: Make one that renders the whole thing and then mutes all the tracks and 0G01


------
-- Define render state (initialized when starting to render)
render_context = {
  source_track = 0,
  target_track = 0,
  target_instrument = 0,
  temp_file_path = ""
}

-- Function to initiate rendering
function start_renderingLPB()
local song=renoise.song()
local render_priority = "high"
local selected_track = song.selected_track

-- Add DC Offset if enabled in preferences
if preferences.RenderDCOffset.value then
    local has_dc_offset = false
    for _, device in ipairs(selected_track.devices) do
        if device.display_name == "Render DC Offset" then
            has_dc_offset = true
            break
        end
    end
    
    if not has_dc_offset then
        loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
        local dc_offset_device = selected_track.devices[#selected_track.devices]
        if dc_offset_device.display_name == "Render DC Offset" then
            dc_offset_device.parameters[2].value = 1
        end
    end
end 

  for _, device in ipairs(selected_track.devices) do
      if device.name == "#Line Input" then
          render_priority = "realtime"
          break
      end
  end

  -- Set up rendering options
  local render_options = {
      sample_rate = preferences.renderSampleRate.value,
      bit_depth = preferences.renderBitDepth.value,
      interpolation = "precise",
      priority = render_priority,
      start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
      end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
  }

  -- Set render context
  render_context.source_track = renoise.song().selected_track_index
  render_context.target_track = render_context.source_track + 1
  render_context.target_instrument = renoise.song().selected_instrument_index + 1
  render_context.temp_file_path = pakettiGetTempFilePath(".wav")

  -- Start rendering with the correct function call
  local success, error_message = renoise.song():render(render_options, render_context.temp_file_path, rendering_done_callbackLPB)
  if not success then
      print("Rendering failed: " .. error_message)
  else
      -- Start a timer to monitor rendering progress
      renoise.tool():add_timer(monitor_renderingLPB, 500)
  end
end

-- Callback function that gets called when rendering is complete
function rendering_done_callbackLPB()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
local song=renoise.song()
local renderTrack = render_context.source_track

-- Remove DC Offset if it was added (FIRST, before other operations)
if preferences.RenderDCOffset.value then
    local original_track = song:track(renderTrack)
    local last_device = original_track.devices[#original_track.devices]
    if last_device.display_name == "Render DC Offset" then
        original_track:delete_device_at(#original_track.devices)
    end
end


  local renderedTrack = render_context.target_track
  local renderedInstrument = render_context.target_instrument

  -- Remove the monitoring timer
  renoise.tool():remove_timer(monitor_renderingLPB)

  -- Un-Solo Selected Track
  song.tracks[renderTrack]:solo()

  -- Turn All Render Track Note Columns to "Off"
  for i = 1, song.tracks[renderTrack].max_note_columns do
      song.tracks[renderTrack]:set_column_is_muted(i, true)
  end

  -- Collapse Render Track
  song.tracks[renderTrack].collapsed = true
  -- Change Selected Track to Rendered Track
  renoise.song().selected_track_index = renoise.song().selected_track_index + 1
  pakettiPreferencesDefaultInstrumentLoader()
  -- Add *Instr. Macros to Rendered Track
  --song:insert_instrument_at(renderedInstrument)
  local new_instrument = song:instrument(renoise.song().selected_instrument_index)

  -- Load Sample into New Instrument Sample Buffer
  new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
  os.remove(render_context.temp_file_path)

  -- Set the selected_instrument_index to the newly created instrument
  song.selected_instrument_index = renderedInstrument - 1

  -- Insert New Track Next to Render Track
  song:insert_track_at(renderedTrack)
  local renderName = song.tracks[renderTrack].name

local number=nil
local numbertwo=nil
local rs=renoise.song()
write_bpm()
clonePTN()
local nol=nil
    nol=renoise.song().selected_pattern.number_of_lines+renoise.song().selected_pattern.number_of_lines
    renoise.song().selected_pattern.number_of_lines=nol

number=renoise.song().transport.lpb*2
if number == 1 then number = 2 end
if number > 128 then number=128 
renoise.song().transport.lpb=number
write_bpm()
Deselect_All()
MarkTrackMarkPattern()
MarkTrackMarkPattern()
ExpandSelection()
Deselect_All()
return end
renoise.song().transport.lpb=number
write_bpm()
Deselect_All()
MarkTrackMarkPattern()
MarkTrackMarkPattern()
ExpandSelection()
Deselect_All()

  song.selected_pattern.tracks[renderedTrack].lines[1].note_columns[1].note_string = "C-4"
  song.selected_pattern.tracks[renderedTrack].lines[1].note_columns[1].instrument_value = renoise.song().selected_instrument_index - 1
  --    song.selected_pattern.tracks[renderedTrack].lines[1].effect_columns[1].number_string = "0G"
  --    song.selected_pattern.tracks[renderedTrack].lines[1].effect_columns[1].amount_value = 01 
  -- Add Instr* Macros to selected Track
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
  loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
  renoise.song().selected_track.devices[2].is_maximized = false
  end
  -- Rename Sample Slot to Render Track
  new_instrument.samples[1].name = renderName .. " (Rendered)"

  -- Select New Track
  print(renderedTrack .. " this was the track but is it really the track?")
  song.selected_track_index = renderedTrack

  -- Rename New Track using Render Track Name
  song.tracks[renderedTrack].name = renderName .. " (Rendered)"
  new_instrument.name = renderName .. " (Rendered)"
  new_instrument.samples[1].autofade = true
  --    new_instrument.samples[1].autoseek = true
if renoise.song().transport.edit_mode then
renoise.song().transport.edit_mode = false
renoise.song().transport.edit_mode = true
else
renoise.song().transport.edit_mode = true
renoise.song().transport.edit_mode = false
end
for i=1,#song.tracks do
renoise.song().tracks[i].mute_state=1
end 

  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to monitor rendering progress
function monitor_renderingLPB()
  if renoise.song().rendering then
      local progress = renoise.song().rendering_progress
      print("Rendering in progress: " .. (progress * 100) .. "% complete")
  else
      -- Remove the monitoring timer once rendering is complete or if it wasn't started
      renoise.tool():remove_timer(monitor_renderingLPB)
      print("Rendering not in progress or already completed.")
  end
end

-- Function to handle rendering for a group track
function render_group_trackLPB()
  local song=renoise.song()
  local group_track_index = song.selected_track_index
  local group_track = song:track(group_track_index)
  local start_track_index = group_track_index + 1
  local end_track_index = start_track_index + group_track.visible_note_columns - 1

  for i = start_track_index, end_track_index do
      song:track(i):solo()
  end

  -- Set rendering options and start rendering
  start_renderingLPB()
end

function pakettiCleanRenderSelectionLPB()
  local song=renoise.song()
  local renderTrack = song.selected_track_index
  local renderedTrack = renderTrack + 1
  local renderedInstrument = song.selected_instrument_index + 1

  -- Print the initial selected_instrument_index
  print("Initial selected_instrument_index: " .. song.selected_instrument_index)

  -- Create New Instrument
  song:insert_instrument_at(renderedInstrument)

  -- Select New Instrument
  song.selected_instrument_index = renderedInstrument

  -- Print the selected_instrument_index after creating new instrument
  print("selected_instrument_index after creating new instrument: " .. song.selected_instrument_index)

  -- Check if the selected track is a group track
  if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
      -- Render the group track
      render_group_trackLPB()
  else
      -- Solo Selected Track
      song.tracks[renderTrack]:solo()

      -- Render Selected Track
      start_renderingLPB()
  end
end



renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Selected Track/Group LPB*2",invoke=function() pakettiCleanRenderSelectionLPB() end}







---------
-- Define render state (initialized when starting to render)
render_context = {
  source_track = 0,
  target_track = 0,
  target_instrument = 0,
  temp_file_path = "",
  format = nil
}

-- Function to initiate rendering
function CleanRenderAndSaveStart(format)
  local render_priority = "high"
  local selected_track = renoise.song().selected_track

  for _, device in ipairs(selected_track.devices) do
      if device.name == "#Line Input" then
          render_priority = "realtime"
              break
          end
      end

  -- Set up rendering options
  local render_options = {
      sample_rate = preferences.renderSampleRate.value,
      bit_depth = preferences.renderBitDepth.value,
      interpolation = "precise",
      priority = render_priority,
      start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
      end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
  }

  -- Set render context
  render_context.source_track = renoise.song().selected_track_index
  render_context.target_track = render_context.source_track + 1
  render_context.target_instrument = renoise.song().selected_instrument_index + 1
  render_context.temp_file_path = pakettiGetTempFilePath(".wav")
  render_context.format = format

  -- Start rendering with the correct function call
  local success, error_message = renoise.song():render(render_options, render_context.temp_file_path, CleanRenderAndSaveDoneCallback)
  if not success then
      print("Rendering failed: " .. error_message)
  else
      -- Start a timer to monitor rendering progress
      renoise.tool():add_timer(CleanRenderAndSaveMonitor, 500)
      end
  end
  
-- Callback function that gets called when rendering is complete
function CleanRenderAndSaveDoneCallback()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song=renoise.song()
  local sourceTrackName = song.tracks[render_context.source_track].name

  -- Remove the monitoring timer
  renoise.tool():remove_timer(CleanRenderAndSaveMonitor)

  -- Un-solo the source track
  song.tracks[render_context.source_track].solo_state = false

  -- Create a new instrument below the currently selected instrument
  local renderedInstrument = song.selected_instrument_index + 1
  song:insert_instrument_at(renderedInstrument)

  -- Select the newly created instrument
  song.selected_instrument_index = renderedInstrument

  -- Ensure the new instrument has at least one sample slot
  local new_instrument = song:instrument(renderedInstrument)
  if #new_instrument.samples == 0 then
      new_instrument:insert_sample_at(1)
  end

  -- Load the rendered sample into the first Sample Buffer
  new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)

  -- Clean up the temporary file
  os.remove(render_context.temp_file_path)

  -- Ensure the correct sample is selected
  song.selected_sample_index = 1

  -- Name the new instrument and the sample inside it
  new_instrument.name = sourceTrackName .. " (Rendered)"
  new_instrument.samples[1].name = sourceTrackName .. " (Rendered)"

  -- Only save to file if format was specified
  if render_context.format and render_context.format ~= "" then
      -- Save the rendered sample using the specified format
      CleanRenderAndSaveSample(render_context.format)
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to monitor rendering progress
function CleanRenderAndSaveMonitor()
  if renoise.song().rendering then
      local progress = renoise.song().rendering_progress
      print("Rendering in progress: " .. (progress * 100) .. "% complete")
  else
      -- Remove the monitoring timer once rendering is complete or if it wasn't started
      renoise.tool():remove_timer(CleanRenderAndSaveMonitor)
      print("Rendering not in progress or already completed.")
  end
end

-- Function to handle rendering for a group track
function CleanRenderAndSaveGroupTrack(format)
  local song=renoise.song()
  local group_track_index = song.selected_track_index
  local group_track = song:track(group_track_index)
  local start_track_index = group_track_index + 1
  local end_track_index = start_track_index + group_track.visible_note_columns - 1

  for i = start_track_index, end_track_index do
      song:track(i):solo()
  end

  -- Set rendering options and start rendering
  CleanRenderAndSaveStart(format)
end

-- Function to clean render and save the selection
function CleanRenderAndSaveSelection(format)
  local song=renoise.song()
  local renderTrack = song.selected_track_index

  -- Check if the selected track is a group track
  if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
      -- Render the group track
      CleanRenderAndSaveGroupTrack(format)
  else
      -- Solo Selected Track
      song.tracks[renderTrack]:solo()

      -- Render Selected Track
      CleanRenderAndSaveStart(format)
  end
end

-- Function to save the rendered sample in the specified format
function CleanRenderAndSaveSample(format)
  if renoise.song().selected_sample == nil then return end

  local filename = renoise.app():prompt_for_filename_to_write(format, "CleanRenderAndSave: Save Selected Sample in ." .. format .. " Format")
  if filename == "" then return end

  renoise.song().selected_sample.sample_buffer:save_as(filename, format)
  renoise.app():show_status("Saved sample as " .. format .. " in " .. filename)
end






renoise.tool():add_keybinding{name="Global:Paketti:Clean Render&Save Selected Track/Group (.WAV)",invoke=function() CleanRenderAndSaveSelection("WAV") end}
renoise.tool():add_keybinding{name="Global:Paketti:Clean Render&Save Selected Track/Group (.FLAC)",invoke=function() CleanRenderAndSaveSelection("FLAC") end}

-------
-- MP3 Rendering Functions using ffmpeg
-------

-- Define render context for MP3 rendering
render_context_mp3 = {
  source_track = 0,
  target_track = 0,
  target_instrument = 0,
  temp_file_path = "",
  format = nil,
  render_type = "track",
  output_mp3_path = ""
}

-- Function to initiate MP3 rendering for track
function CleanRenderAndSaveMP3Start(render_type)
  local render_priority = "high"
  local selected_track = renoise.song().selected_track

  for _, device in ipairs(selected_track.devices) do
      if device.name == "#Line Input" then
          render_priority = "realtime"
          break
      end
  end

  -- Set up rendering options based on render type
  local render_options = {
      sample_rate = preferences.renderSampleRate.value,
      bit_depth = preferences.renderBitDepth.value,
      interpolation = "precise",
      priority = render_priority,
      start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
      end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
  }

  -- Set render context
  render_context_mp3.source_track = renoise.song().selected_track_index
  render_context_mp3.target_track = render_context_mp3.source_track + 1
  render_context_mp3.target_instrument = renoise.song().selected_instrument_index + 1
  render_context_mp3.temp_file_path = pakettiGetTempFilePath(".wav")
  render_context_mp3.format = "MP3"
  render_context_mp3.render_type = render_type

  -- Start rendering with the correct function call
  local success, error_message = renoise.song():render(render_options, render_context_mp3.temp_file_path, CleanRenderAndSaveMP3DoneCallback)
  if not success then
      print("MP3 Rendering failed: " .. error_message)
  else
      -- Start a timer to monitor rendering progress
      renoise.tool():add_timer(CleanRenderAndSaveMP3Monitor, 500)
  end
end

-- Callback function that gets called when rendering is complete
function CleanRenderAndSaveMP3DoneCallback()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local sourceTrackName = song.tracks[render_context_mp3.source_track].name

  -- Remove the monitoring timer
  renoise.tool():remove_timer(CleanRenderAndSaveMP3Monitor)

  -- Un-solo the source track
  song.tracks[render_context_mp3.source_track].solo_state = false

  print("DEBUG MP3: WAV rendering complete, starting ffmpeg conversion")
  
  -- Check if temp WAV file exists before conversion
  local temp_file = io.open(render_context_mp3.temp_file_path, "r")
  if temp_file then
    temp_file:close()
    print("DEBUG MP3: Temp WAV file exists, size:", renoise.song().selected_sample.sample_buffer.number_of_frames or "unknown")
  else
    print("DEBUG MP3: ERROR - Temp WAV file does not exist!")
    renoise.app():show_status("ERROR: Rendered WAV file not found")
    return
  end
  
  -- Find ffmpeg path
  local ffmpeg_path = FindFFmpegPath()
  if not ffmpeg_path then
    print("DEBUG MP3: ERROR - ffmpeg not found!")
    renoise.app():show_status("ERROR: ffmpeg not found. Install: brew install ffmpeg")
    os.remove(render_context_mp3.temp_file_path)
    return
  end
  
  -- Build ffmpeg command to convert WAV to MP3 (320k bitrate) directly to the output path
  -- Use -y to overwrite without prompting
  -- Redirect stderr to stdout so we can see errors
  local ffmpeg_command = string.format('"%s" -y -i "%s" -codec:a libmp3lame -b:a 320k "%s" 2>&1', 
    ffmpeg_path, render_context_mp3.temp_file_path, render_context_mp3.output_mp3_path)
  
  print("DEBUG MP3: Running ffmpeg command:", ffmpeg_command)
  
  -- Execute ffmpeg conversion
  local result = os.execute(ffmpeg_command)
  
  print("DEBUG MP3: ffmpeg returned:", result)
  
  -- Decode return value (on Unix, os.execute returns exit_status << 8)
  local exit_code = result
  if type(result) == "number" and result > 255 then
    exit_code = result / 256
  end
  print("DEBUG MP3: ffmpeg exit code:", exit_code)
  
  if exit_code == 127 then
    print("DEBUG MP3: ERROR - ffmpeg command not found!")
    renoise.app():show_status("ERROR: ffmpeg not found in PATH. Install: brew install ffmpeg")
    os.remove(render_context_mp3.temp_file_path)
    return
  end
  
  -- Check if output MP3 file was created
  local output_file = io.open(render_context_mp3.output_mp3_path, "r")
  if output_file then
    output_file:close()
    print("DEBUG MP3: MP3 file created successfully")
    renoise.app():show_status("Saved MP3 to " .. render_context_mp3.output_mp3_path)
    print("DEBUG MP3: Saved MP3 to", render_context_mp3.output_mp3_path)
  else
    print("DEBUG MP3: ERROR - MP3 file was not created!")
    print("DEBUG MP3: ffmpeg result was:", result)
    renoise.app():show_status("ERROR: ffmpeg conversion failed - MP3 file not created. Check if ffmpeg is installed and in PATH.")
  end
  
  -- Clean up temp WAV file
  os.remove(render_context_mp3.temp_file_path)
  print("DEBUG MP3: Cleaned up temp WAV file")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to monitor rendering progress
function CleanRenderAndSaveMP3Monitor()
  if renoise.song().rendering then
      local progress = renoise.song().rendering_progress
      print("MP3 Rendering in progress: " .. (progress * 100) .. "% complete")
  else
      -- Remove the monitoring timer once rendering is complete or if it wasn't started
      renoise.tool():remove_timer(CleanRenderAndSaveMP3Monitor)
      print("MP3 Rendering not in progress or already completed.")
  end
end

-- Function to handle rendering for a group track
function CleanRenderAndSaveMP3GroupTrack()
  local song = renoise.song()
  local group_track_index = song.selected_track_index
  local group_track = song:track(group_track_index)
  local start_track_index = group_track_index + 1
  local end_track_index = start_track_index + group_track.visible_note_columns - 1

  for i = start_track_index, end_track_index do
      song:track(i):solo()
  end

  -- Set rendering options and start rendering
  CleanRenderAndSaveMP3Start("track")
end

-- Function to find ffmpeg path
function FindFFmpegPath()
  -- Common locations where ffmpeg might be installed
  local common_paths = {
    "/opt/homebrew/bin/ffmpeg",  -- Apple Silicon Homebrew
    "/usr/local/bin/ffmpeg",      -- Intel Mac Homebrew
    "/usr/bin/ffmpeg",            -- System install
    "ffmpeg"                      -- In PATH
  }
  
  for _, path in ipairs(common_paths) do
    local test_cmd
    if os.platform() == "WINDOWS" then
      test_cmd = string.format('where "%s" >nul 2>&1', path)
    else
      test_cmd = string.format('test -f "%s"', path)
    end
    
    local result = os.execute(test_cmd)
    if result == 0 or result == true then
      print("DEBUG MP3: Found ffmpeg at:", path)
      return path
    end
  end
  
  print("DEBUG MP3: ffmpeg not found in common locations")
  return nil
end

-- Function to check if ffmpeg is available
function CheckFFmpegAvailable()
  local ffmpeg_path = FindFFmpegPath()
  return ffmpeg_path ~= nil
end

-- Function to clean render and save the selection as MP3
function CleanRenderAndSaveSelectionMP3()
  local song = renoise.song()
  local renderTrack = song.selected_track_index

  -- Check if ffmpeg is available FIRST
  if not CheckFFmpegAvailable() then
    renoise.app():show_status("ERROR: ffmpeg not found! Please install ffmpeg and ensure it's in your PATH")
    print("DEBUG MP3: ffmpeg not found in PATH")
    print("DEBUG MP3: Install ffmpeg:")
    print("  macOS: brew install ffmpeg")
    print("  Linux: sudo apt-get install ffmpeg (or your distro's package manager)")
    print("  Windows: Download from ffmpeg.org and add to PATH")
    return
  end
  
  print("DEBUG MP3: ffmpeg found and available")

  -- Prompt user for save location FIRST, before rendering
  local filename = renoise.app():prompt_for_filename_to_write("mp3", "Save Rendered Track as MP3")
  
  if filename == "" then
    renoise.app():show_status("MP3 render cancelled")
    print("DEBUG MP3: User cancelled save - aborting render")
    return
  end
  
  -- Store the output path in render context
  render_context_mp3.output_mp3_path = filename
  print("DEBUG MP3: Will save to:", filename)

  -- Check if the selected track is a group track
  if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
      -- Render the group track
      CleanRenderAndSaveMP3GroupTrack()
  else
      -- Solo Selected Track
      song.tracks[renderTrack]:solo()

      -- Render Selected Track
      CleanRenderAndSaveMP3Start("track")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Clean Render&Save Selected Track/Group (.MP3)",invoke=function() CleanRenderAndSaveSelectionMP3() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render&Save Selected Track/Group (.MP3)",invoke=function() CleanRenderAndSaveSelectionMP3() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Render Pattern to MP3",invoke=function() CleanRenderAndSaveSelectionMP3() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render&Save Selected Track/Group (.MP3)",invoke=function() CleanRenderAndSaveSelectionMP3() end}

-------
render_context = {
  source_track = 0,
  target_track = 0,
  target_instrument = 0,
  temp_file_path = "",
  original_pattern_size = 0}

-- Function to resize pattern if necessary
function PakettiSeamlessCheckAndResizePattern()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local current_pattern = song:pattern(pattern_index)
  local current_pattern_size = current_pattern.number_of_lines

  -- Save the original pattern size
  render_context.original_pattern_size = current_pattern_size

  -- Check if pattern size is over 256 - seamless rendering doesn't support this
  if current_pattern_size > 256 then
    renoise.app():show_status("Cannot Seamless Render, maximum Pattern Length for Seamless Render is 256 rows, doing nothing.")
    return false
  end

  -- If pattern size is less than 257, double it up to a maximum of 512
  if current_pattern_size < 257 then
      -- Double the pattern size until it's no more than 512
      while current_pattern_size < 512 do
          current_pattern_size = current_pattern_size * 2
      end
      -- Set the pattern size to the new value
  -- Call pakettiResizeAndFill() based on the original size before resizing
  if render_context.original_pattern_size == 256 then pakettiResizeAndFill(512)
  elseif render_context.original_pattern_size == 128 then pakettiResizeAndFill(256)
  elseif render_context.original_pattern_size == 64 then pakettiResizeAndFill(128)
  elseif render_context.original_pattern_size == 32 then pakettiResizeAndFill(64)
  elseif render_context.original_pattern_size == 16 then pakettiResizeAndFill(32)
  end end 
  return true
end

function PakettiSeamlessRestorePatternSize()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local current_pattern = song:pattern(pattern_index)
  current_pattern.number_of_lines = render_context.original_pattern_size
end

-- Function to initiate rendering
function PakettiSeamlessStartRendering()
local song=renoise.song()
local render_priority = "high"
local selected_track = song.selected_track

-- Add DC Offset if enabled in preferences
if preferences.RenderDCOffset.value then
    local has_dc_offset = false
    for _, device in ipairs(selected_track.devices) do
        if device.display_name == "Render DC Offset" then
            has_dc_offset = true
            break
        end
    end
    
    if not has_dc_offset then
        loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
        local dc_offset_device = selected_track.devices[#selected_track.devices]
        if dc_offset_device.display_name == "Render DC Offset" then
            dc_offset_device.parameters[2].value = 1
        end
    end
end

  for _, device in ipairs(selected_track.devices) do
      if device.name == "#Line Input" then
          render_priority = "realtime"
          break
      end
  end

  -- Set up rendering options
  local render_options = {
      sample_rate = preferences.renderSampleRate.value,
      bit_depth = preferences.renderBitDepth.value,
      interpolation = "precise",
      priority = render_priority,
      start_pos = renoise.SongPos(renoise.song().selected_sequence_index, 1),
      end_pos = renoise.SongPos(renoise.song().selected_sequence_index, renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines),
  }

  -- Set render context
  render_context.source_track = renoise.song().selected_track_index
  render_context.target_instrument = renoise.song().selected_instrument_index + 1
  render_context.temp_file_path = pakettiGetTempFilePath(".wav")

  -- Start rendering with the correct function call
  local success, error_message = renoise.song():render(render_options, render_context.temp_file_path, PakettiSeamlessRenderingDoneCallback)
  if not success then
      print("Rendering failed: " .. error_message)
  else
      -- Start a timer to monitor rendering progress
      renoise.tool():add_timer(PakettiSeamlessMonitorRendering, 500)
  end
end

-- Callback function that gets called when rendering is complete
function PakettiSeamlessRenderingDoneCallback()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
local song=renoise.song()
local renderTrack = render_context.source_track

-- Remove DC Offset if it was added (FIRST, before other operations)
if preferences.RenderDCOffset.value then
    local original_track = song:track(renderTrack)
    local last_device = original_track.devices[#original_track.devices]
    if last_device.display_name == "Render DC Offset" then
        original_track:delete_device_at(#original_track.devices)
    end
end

  local renderedInstrument = render_context.target_instrument

  -- Remove the monitoring timer
  renoise.tool():remove_timer(PakettiSeamlessMonitorRendering)

  -- Restore the original pattern size after rendering
  PakettiSeamlessRestorePatternSize()

  -- Use pakettiPreferencesDefaultInstrumentLoader before loading the sample
pakettiPreferencesDefaultInstrumentLoader()

  -- Load rendered sample into the selected instrument
  local new_instrument = song:instrument(renoise.song().selected_instrument_index)
  new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
  os.remove(render_context.temp_file_path)

  -- Set the selected_instrument_index to the newly created instrument
  song.selected_instrument_index = renderedInstrument - 1


  -- Switch to instrument sample editor's middle frame
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

  pakettiSampleBufferHalfSelector(1)

renoise.song().selected_sample.loop_start=renoise.song().selected_sample.sample_buffer.selection_end
renoise.song().selected_sample.loop_end=renoise.song().selected_sample.sample_buffer.number_of_frames
renoise.song().selected_sample.loop_mode=2
renoise.song().selected_sample.name = renoise.song().selected_track.name
renoise.song().selected_instrument.name = renoise.song().selected_track.name
  if renoise.song().transport.edit_mode then
      renoise.song().transport.edit_mode = false
      renoise.song().transport.edit_mode = true
  else
      renoise.song().transport.edit_mode = true
      renoise.song().transport.edit_mode = false
  end

  for i=1,#song.tracks do
    renoise.song().tracks[i].mute_state=1
end     

  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

function PakettiSeamlessMonitorRendering()
  if renoise.song().rendering then
      local progress = renoise.song().rendering_progress
      print("Rendering in progress: " .. (progress * 100) .. "% complete")
  else
      renoise.tool():remove_timer(PakettiSeamlessMonitorRendering)
      print("Rendering not in progress or already completed.")
  end
end

function PakettiSeamlessRenderGroupTrack()
  local song=renoise.song()
  local group_track_index = song.selected_track_index
  local group_track = song:track(group_track_index)
  local start_track_index = group_track_index + 1
  local end_track_index = start_track_index + group_track.visible_note_columns - 1

  for i = start_track_index, end_track_index do
      song:track(i):solo()
  end
  PakettiSeamlessStartRendering()
end

function PakettiSeamlessCleanRenderSelection()
  local song=renoise.song()
  local renderTrack = song.selected_track_index
  local renderedInstrument = song.selected_instrument_index + 1

  print("Initial selected_instrument_index: " .. song.selected_instrument_index)
  song:insert_instrument_at(renderedInstrument)
  song.selected_instrument_index = renderedInstrument
  print("selected_instrument_index after creating new instrument: " .. song.selected_instrument_index)
  
  -- Check if pattern can be seamlessly rendered
  if not PakettiSeamlessCheckAndResizePattern() then
    -- Remove the instrument we just created since we're not going to render
    song:delete_instrument_at(renderedInstrument)
    return
  end
  
  if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
      PakettiSeamlessRenderGroupTrack()
  else
      PakettiSeamlessStartRendering()
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Seamless Selected Track/Group",invoke=function() PakettiSeamlessCleanRenderSelection() end}

--------
-- Selection-based rendering functions
--------

function create_selection_render_context(muteOriginal, justwav, newtrack)
    return {
        source_track = 0,
        target_track = 0,
        target_instrument = 0,
        temp_file_path = "",
        num_tracks_before = 0,
        muteOriginal = muteOriginal or false,
        justwav = justwav or false,
        newtrack = newtrack or false,
        selection_start_line = 0,
        selection_end_line = 0,
        dc_offset_added = false,
        dc_offset_track_index = 0,
        dc_offset_position = 0
    }
end

function pakettiRenderPatternSelection(muteOriginal, justwav, newtrack)
    -- Set defaults if not provided
    muteOriginal = muteOriginal or false
    justwav = justwav or false  
    newtrack = newtrack or false
    
    print("DEBUG: pakettiRenderPatternSelection called with muteOriginal =", muteOriginal, "justwav =", justwav, "newtrack =", newtrack)
    
    local song = renoise.song()
    local selection = song.selection_in_pattern
    
    -- Check if there's a valid selection
    if not selection then
        renoise.app():show_status("No pattern selection found. Please select some pattern data first.")
        return
    end
    
    -- Validate selection has line range
    if not selection.start_line or not selection.end_line or selection.start_line >= selection.end_line then
        renoise.app():show_status("Invalid pattern selection. Please select a range of lines.")
        return
    end
    
    -- Validate selection has track
    if not selection.start_track or selection.start_track < 1 then
        renoise.app():show_status("Invalid track selection. Please select pattern data on a track.")
        return
    end
    
    print("DEBUG: Selection found - Lines:", selection.start_line, "to", selection.end_line, "Track:", selection.start_track)
    
    local renderTrack = selection.start_track
    local renderedInstrument = song.selected_instrument_index + 1

    -- Create New Instrument
    song:insert_instrument_at(renderedInstrument)
    -- Select New Instrument
    song.selected_instrument_index = renderedInstrument

    -- Create render context with selection bounds
    local render_context = create_selection_render_context(muteOriginal, justwav, newtrack)
    render_context.selection_start_line = selection.start_line
    render_context.selection_end_line = selection.end_line
    
    print("DEBUG: Created render context with selection lines:", render_context.selection_start_line, "to", render_context.selection_end_line)

    -- Check if the selected track is a group track
    if song:track(renderTrack).type == renoise.Track.TRACK_TYPE_GROUP then
        print("DEBUG: Calling render_selection_group_track")
        render_selection_group_track(render_context, renderTrack)
    else
        print("DEBUG: Calling start_selection_rendering")
        start_selection_rendering(render_context, renderTrack)
    end
end

function start_selection_rendering(render_context, track_index)
    local song = renoise.song()
    local render_priority = "high"
    local selected_track = song:track(track_index)
    local dc_offset_added = false
    local dc_offset_position = 0
    
    print("DEBUG: start_selection_rendering - track:", track_index, "lines:", render_context.selection_start_line, "to", render_context.selection_end_line)

    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
            break
        end
    end

    -- Add DC Offset if enabled in preferences and not already present
    if preferences.RenderDCOffset.value then
        print("DEBUG DC: RenderDCOffset preference is enabled")
        -- First check if DC Offset already exists and find its position
        for i, device in ipairs(selected_track.devices) do
            if device.display_name == "Render DC Offset" then
                dc_offset_position = i
                print("DEBUG DC: Found existing DC Offset at position", i)
                break
            end
        end
        
        if dc_offset_position == 0 then
            print("DEBUG DC: Adding DC Offset to track", track_index)
            -- Temporarily select the track to add the device
            local original_track_index = song.selected_track_index
            song.selected_track_index = track_index
            loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
            song.selected_track_index = original_track_index
            
            -- Find the newly added DC Offset and its position
            for i, device in ipairs(selected_track.devices) do
                if device.display_name == "Render DC Offset" then
                    dc_offset_position = i
                    device.parameters[2].value = 1
                    dc_offset_added = true
                    print("DEBUG DC: Added new DC Offset at position", i)
                    break
                end
            end
        end
    else
        print("DEBUG DC: RenderDCOffset preference is disabled")
    end

    -- Store DC Offset information in render context
    render_context.dc_offset_added = dc_offset_added
    render_context.dc_offset_track_index = track_index
    render_context.dc_offset_position = dc_offset_position

    -- Set up rendering options with selection bounds
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(song.selected_sequence_index, render_context.selection_start_line),
        end_pos = renoise.SongPos(song.selected_sequence_index, render_context.selection_end_line),
    }

    print("DEBUG: Render options - start:", render_options.start_pos.line, "end:", render_options.end_pos.line)

    -- Save current solo and mute states
    track_states = {}
    render_context.num_tracks_before = #song.tracks
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
    end

    -- Solo the selected track and unsolo others
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    song.tracks[track_index].solo_state = true

    -- Update render context values
    render_context.source_track = track_index
    render_context.target_track = track_index + 1
    render_context.target_instrument = song.selected_instrument_index
    render_context.temp_file_path = pakettiGetTempFilePath(".wav")

    -- Start rendering
    local success, error_message = song:render(render_options, render_context.temp_file_path, function() selection_rendering_done_callback(render_context) end)
    if not success then
        print("Selection rendering failed: " .. error_message)
        -- Remove DC Offset if it was added
        if dc_offset_added and dc_offset_position > 0 then
            selected_track:delete_device_at(dc_offset_position)
        end
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(monitor_selection_rendering, 500)
    end
end

function selection_rendering_done_callback(render_context)
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    print("DEBUG: selection_rendering_done_callback started")
    local song = renoise.song()
    local renderTrack = render_context.source_track

    -- Handle DC Offset removal
    if render_context.dc_offset_position > 0 then
        print("DEBUG DC: Checking for DC Offset at position", render_context.dc_offset_position)
        local track = song:track(render_context.dc_offset_track_index)
        
        if track and track.devices[render_context.dc_offset_position] and
           track.devices[render_context.dc_offset_position].display_name == "Render DC Offset" then
            print("DEBUG DC: Removing DC Offset from position", render_context.dc_offset_position)
            track:delete_device_at(render_context.dc_offset_position)
            print("DEBUG DC: Successfully removed DC Offset")
        end
    end

    -- Remove the monitoring timer
    renoise.tool():remove_timer(monitor_selection_rendering)

    -- Restore solo and mute states
    for i = 1, song.sequencer_track_count do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end

    local send_track_start = song.sequencer_track_count + 2
    for i = send_track_start, send_track_start + song.send_track_count - 1 do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end

    -- Restore original states for tracks that existed before rendering
    for i = 1, render_context.num_tracks_before do
        if track_states[i] then
            song.tracks[i].solo_state = track_states[i].solo_state
            song.tracks[i].mute_state = track_states[i].mute_state
        end
    end

    -- ALWAYS: Load default instrument and create sample
    local renderedInstrument = render_context.target_instrument
    local renderName = song.tracks[renderTrack].name
    
    pakettiPreferencesDefaultInstrumentLoader()
    local new_instrument = song:instrument(song.selected_instrument_index)
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)
    
    -- Set the selected_instrument_index to the newly created instrument
    song.selected_instrument_index = renderedInstrument
    
    -- Rename instrument and sample
    local selection_name = string.format("%s (Selection L%d-L%d)", renderName, render_context.selection_start_line, render_context.selection_end_line)
    new_instrument.name = selection_name
    new_instrument.samples[1].name = selection_name
    new_instrument.samples[1].autofade = true

    -- If muteOriginal: mute/disable/collapse original track
    if render_context.muteOriginal then
        print("DEBUG: Muting original track")
        for i = 1, song.tracks[renderTrack].max_note_columns do
            song.tracks[renderTrack]:set_column_is_muted(i, true)
        end

        if preferences.renderBypass.value == true then 
            local original_selected_track = song.selected_track_index
            song.selected_track_index = renderTrack
            for i = 2, #song.selected_track.devices do
                song.selected_track.devices[i].is_active = false
            end
            song.selected_track_index = original_selected_track
        end

        song.tracks[renderTrack].collapsed = true
    end

    -- If newtrack: create new track with C-4 0G01
    if render_context.newtrack then
        print("DEBUG: Creating new track with C-4 0G01")
        local renderedTrack = renderTrack + 1
        
        song:insert_track_at(renderedTrack)
        song.selected_track_index = renderedTrack

        local selected_pattern_index = song.selected_pattern_index
        local pattern_track = song.patterns[selected_pattern_index]:track(renderedTrack)

        pattern_track:line(1).note_columns[1].note_string = "C-4"
        pattern_track:line(1).note_columns[1].instrument_value = song.selected_instrument_index - 1
        pattern_track:line(1).effect_columns[1].number_string="0G"
        pattern_track:line(1).effect_columns[1].amount_string="01"

        if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
            loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
            song.selected_track.devices[2].is_maximized = false
        end

        song.tracks[renderedTrack].name = selection_name
        
        if song.transport.edit_mode then
            song.transport.edit_mode = false
            song.transport.edit_mode = true
        else
            song.transport.edit_mode = true
            song.transport.edit_mode = false
        end

        if render_context.muteOriginal then
            song.selected_track.mute_state = 1
            for i=1,#song.tracks do
                song.tracks[i].mute_state = 1
            end 
        else
            song.tracks[renderedTrack].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end
    
    renoise.app():show_status("Selection rendered: " .. selection_name)
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

function monitor_selection_rendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Selection rendering in progress: " .. (progress * 100) .. "% complete")
    else
        renoise.tool():remove_timer(monitor_selection_rendering)
        print("Selection rendering not in progress or already completed.")
    end
end

function render_selection_group_track(render_context, group_track_index)
    local song = renoise.song()
    local group_track = song:track(group_track_index)

    if not group_track or group_track.type ~= renoise.Track.TRACK_TYPE_GROUP then
        renoise.app():show_status("Selected track is not a group track")
        return
    end

    -- Save current solo and mute states
    track_states = {}
    render_context.num_tracks_before = #song.tracks
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
    end

    -- Unsolo all tracks and solo just the group track
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    group_track.solo_state = true

    -- Start rendering with the render_context
    start_selection_rendering(render_context, group_track_index)
end

-- Key bindings for selection-based rendering
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Render Pattern Selection",invoke=function() pakettiRenderPatternSelection(false, false, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Render Pattern Selection (Mute Original)",invoke=function() pakettiRenderPatternSelection(true, false, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Render Pattern Selection (New Track)",invoke=function() pakettiRenderPatternSelection(false, false, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Render Pattern Selection (Mute + New Track)",invoke=function() pakettiRenderPatternSelection(true, false, true) end}

-- Menu entries for selection-based rendering
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Render Pattern Selection",invoke=function() pakettiRenderPatternSelection(false, false, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Render Pattern Selection (Mute Original)",invoke=function() pakettiRenderPatternSelection(true, false, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Render Pattern Selection (New Track)",invoke=function() pakettiRenderPatternSelection(false, false, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Clean Render:Render Pattern Selection (Mute + New Track)",invoke=function() pakettiRenderPatternSelection(true, false, true) end}

--------
-- BPM Calculation Helper
--------

-- BPM DETECTION FUNCTIONS MOVED TO PakettiBPM.lua
-- Use: pakettiBPMCountFromSample(), pakettiBPMTestCalculation(), pakettiBPMAnalyzeSample(), pakettiBPMDetectFromSample()

-- Function to detect sample BPM and calculate render BPM  
function pakettiCalculateRenderBPM(sample_length_frames, sample_rate)
    local detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_length_frames, sample_rate)
    
    -- Use preference value for silence multiplier
    local silence_multiplier = preferences.experimentalRenderSilenceMultiplier.value
    local total_time_multiplier = 1 + silence_multiplier
    local render_bpm = detected_bpm / total_time_multiplier
    
    print("=== RENDER BPM CALCULATION ===")
    print("Detected BPM:", string.format("%.1f", detected_bpm), "with", beat_count, "beats")
    print("Silence multiplier:", silence_multiplier, "(sample-length silences after playback)")
    print("Total time multiplier:", total_time_multiplier, "(1 playback + " .. silence_multiplier .. " silences)")
    print("Render BPM:", string.format("%.1f", render_bpm), "(detected ÷ " .. total_time_multiplier .. ")")
    
    return render_bpm, detected_bpm, beat_count
end

--------
-- Peak Detection Helper
--------

function pakettiDetectSamplePeak(sample_buffer)
    if not sample_buffer or not sample_buffer.has_sample_data then
        return 0
    end
    
    local peak = 0
    local num_frames = sample_buffer.number_of_frames
    local num_channels = sample_buffer.number_of_channels
    local chunk_size = 10000
    
    print("DEBUG PEAK: Analyzing", num_frames, "frames in chunks of", chunk_size)
    
    -- Process in chunks of 10,000 frames for better performance
    for channel = 1, num_channels do
        for chunk_start = 1, num_frames, chunk_size do
            local chunk_end = math.min(chunk_start + chunk_size - 1, num_frames)
            local chunk_peak = 0
            
            -- Find peak within this chunk
            for frame = chunk_start, chunk_end do
                local sample_value = math.abs(sample_buffer:sample_data(channel, frame))
                if sample_value > chunk_peak then
                    chunk_peak = sample_value
                end
            end
            
            -- Update overall peak if this chunk's peak is higher
            if chunk_peak > peak then
                peak = chunk_peak
            end
        end
    end
    
    print("DEBUG PEAK: Analysis complete, peak found:", string.format("%.6f", peak))
    return peak
end

function pakettiTestPeakDetection()
    local song = renoise.song()
    local selected_sample = song.selected_sample
    
    if not selected_sample or not selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("Please select a sample with data first")
        return
    end
    
    local peak = pakettiDetectSamplePeak(selected_sample.sample_buffer)
    local peak_db = math.lin2db(peak)
    local msg = string.format("Sample Peak: %.6f (%.2f dB)", peak, peak_db)
    
    print("DEBUG:", msg)
    renoise.app():show_status(msg)
end

--------
-- Experimental Sample FX Renderer
-- Renders a long sample through track/sample FX by creating temporary playback environment
--------

-- Helper functions for slice detection and note calculation
function pakettiDetectSlicedInstrument(instrument)
    if not instrument or #instrument.samples == 0 then
        return false
    end
    
    local first_sample = instrument.samples[1]
    return #first_sample.slice_markers > 0
end

function pakettiDetectSampleTriggerNote(instrument, sample_index)
    if not instrument or not pakettiDetectSlicedInstrument(instrument) then
        return "C-4"  -- Default note for non-sliced instruments
    end
    
    -- For sliced instruments, find the key mapping of the first sample (the original whole sample)
    local first_sample = instrument.samples[1]
    if not first_sample then
        return "C-4"
    end
    
    -- Get the base note mapping of the first sample
    local base_note = first_sample.sample_mapping.base_note
    
    -- Convert note number to note string
    local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
    local note = base_note % 12
    local octave = math.floor(base_note / 12)
    
    return note_names[note + 1] .. octave
end

function pakettiCopySliceMarkers(source_sample, target_sample)
    if not source_sample or not target_sample then
        print("DEBUG SLICE: Cannot copy slice markers - invalid samples")
        return false
    end
    
    if #source_sample.slice_markers == 0 then
        print("DEBUG SLICE: No slice markers to copy")
        return false
    end
    
    -- Get sample rates to calculate scaling factor
    local source_sample_rate = source_sample.sample_buffer.sample_rate
    local target_sample_rate = target_sample.sample_buffer.sample_rate
    local scaling_factor = target_sample_rate / source_sample_rate
    
    print("DEBUG SLICE: Source sample rate:", source_sample_rate, "Hz")
    print("DEBUG SLICE: Target sample rate:", target_sample_rate, "Hz") 
    print("DEBUG SLICE: Scaling factor:", scaling_factor)
    
    -- Copy each slice marker from source to target, scaling position by sample rate ratio
    for i, marker_pos in ipairs(source_sample.slice_markers) do
        local scaled_marker_pos = math.floor(marker_pos * scaling_factor + 0.5)  -- Round to nearest integer
        target_sample:insert_slice_marker(scaled_marker_pos)
        print("DEBUG SLICE: Copied slice marker", i, "from position", marker_pos, "to scaled position", scaled_marker_pos)
    end
    
    print("DEBUG SLICE: Successfully copied", #source_sample.slice_markers, "slice markers with scaling factor", scaling_factor)
    return true
end

function pakettiCopySliceSettings(source_instrument, target_instrument)
    if not source_instrument or not target_instrument then
        print("DEBUG SLICE: Cannot copy slice settings - invalid instruments")
        return false
    end
    
    if not pakettiDetectSlicedInstrument(source_instrument) then
        print("DEBUG SLICE: Source instrument is not sliced, no slice settings to copy")
        return false
    end
    
    local source_samples = source_instrument.samples
    local target_samples = target_instrument.samples
    
    -- Copy ALL settings from each original slice to corresponding new slice
    for i = 1, #source_samples do
        local source_slice = source_samples[i]
        local target_slice = target_samples[i]
        
        if source_slice and target_slice then
            print("DEBUG SLICE: Copying ALL settings from original slice", i, "to new slice", i)
            
            -- Copy ALL sample properties - EVERYTHING!
            target_slice.panning = source_slice.panning
            target_slice.volume = source_slice.volume
            target_slice.transpose = source_slice.transpose
            target_slice.fine_tune = source_slice.fine_tune
            
            -- Copy beat sync settings (ALL of them)
            target_slice.beat_sync_enabled = source_slice.beat_sync_enabled
            target_slice.beat_sync_lines = source_slice.beat_sync_lines
            target_slice.beat_sync_mode = source_slice.beat_sync_mode
            
            -- Copy playback settings (ALL of them)
            target_slice.interpolation_mode = source_slice.interpolation_mode
            target_slice.oversample_enabled = source_slice.oversample_enabled
            target_slice.new_note_action = source_slice.new_note_action
            target_slice.oneshot = source_slice.oneshot
            target_slice.mute_group = source_slice.mute_group
            target_slice.autoseek = source_slice.autoseek
            target_slice.autofade = source_slice.autofade
            
            -- Copy loop settings (ALL of them)
            target_slice.loop_mode = source_slice.loop_mode
            target_slice.loop_release = source_slice.loop_release
            
            -- Scale loop points if they exist and are within the sample
            if source_slice.loop_start > 1 and source_slice.loop_end > source_slice.loop_start then
                local source_sample_rate = source_slice.sample_buffer.sample_rate
                local target_sample_rate = target_slice.sample_buffer.sample_rate
                local scaling_factor = target_sample_rate / source_sample_rate
                
                local scaled_loop_start = math.floor(source_slice.loop_start * scaling_factor + 0.5)
                local scaled_loop_end = math.floor(source_slice.loop_end * scaling_factor + 0.5)
                
                -- Ensure loop points are within target sample bounds
                if scaled_loop_start >= 1 and scaled_loop_end <= target_slice.sample_buffer.number_of_frames then
                    target_slice.loop_start = scaled_loop_start
                    target_slice.loop_end = scaled_loop_end
                    print("DEBUG SLICE: Scaled loop points for slice", i, "from", source_slice.loop_start, "-", source_slice.loop_end, "to", scaled_loop_start, "-", scaled_loop_end)
                end
            end
            
            -- Copy modulation and device chain indices
            target_slice.modulation_set_index = source_slice.modulation_set_index
            target_slice.device_chain_index = source_slice.device_chain_index
            
            print("  Slice", i, "settings: Vol:", target_slice.volume, "Pan:", target_slice.panning, "Transpose:", target_slice.transpose, "Mute:", target_slice.mute_group, "NNA:", target_slice.new_note_action)
        end
    end
    
    print("DEBUG SLICE: Successfully copied settings for", #source_samples, "slices")
    return true
end

function pakettiCopyBaseSampleSettings(source_sample, target_sample)
    if not source_sample or not target_sample then
        print("DEBUG SLICE: Cannot copy base sample settings - invalid samples")
        return false
    end
    
    print("DEBUG SLICE: Copying ALL base sample settings from original to new sample")
    
    -- Copy ALL sample properties - EVERYTHING!
    target_sample.panning = source_sample.panning
    target_sample.volume = source_sample.volume
    target_sample.transpose = source_sample.transpose
    target_sample.fine_tune = source_sample.fine_tune
    
    -- Copy beat sync settings (ALL of them)
    target_sample.beat_sync_enabled = source_sample.beat_sync_enabled
    target_sample.beat_sync_lines = source_sample.beat_sync_lines
    target_sample.beat_sync_mode = source_sample.beat_sync_mode
    
    -- Copy playback settings (ALL of them)
    target_sample.interpolation_mode = source_sample.interpolation_mode
    target_sample.oversample_enabled = source_sample.oversample_enabled
    target_sample.new_note_action = source_sample.new_note_action
    target_sample.oneshot = source_sample.oneshot
    target_sample.mute_group = source_sample.mute_group
    target_sample.autoseek = source_sample.autoseek
    target_sample.autofade = source_sample.autofade
    
    -- Copy loop settings (ALL of them)
    target_sample.loop_mode = source_sample.loop_mode
    target_sample.loop_release = source_sample.loop_release
    
    -- Scale loop points if they exist and are within the sample
    if source_sample.loop_start > 1 and source_sample.loop_end > source_sample.loop_start then
        local source_sample_rate = source_sample.sample_buffer.sample_rate
        local target_sample_rate = target_sample.sample_buffer.sample_rate
        local scaling_factor = target_sample_rate / source_sample_rate
        
        local scaled_loop_start = math.floor(source_sample.loop_start * scaling_factor + 0.5)
        local scaled_loop_end = math.floor(source_sample.loop_end * scaling_factor + 0.5)
        
        -- Ensure loop points are within target sample bounds
        if scaled_loop_start >= 1 and scaled_loop_end <= target_sample.sample_buffer.number_of_frames then
            target_sample.loop_start = scaled_loop_start
            target_sample.loop_end = scaled_loop_end
            print("DEBUG SLICE: Scaled base sample loop points from", source_sample.loop_start, "-", source_sample.loop_end, "to", scaled_loop_start, "-", scaled_loop_end)
        end
    end
    
    -- Copy modulation and device chain indices
    target_sample.modulation_set_index = source_sample.modulation_set_index
    target_sample.device_chain_index = source_sample.device_chain_index
    
    print("DEBUG SLICE: Successfully copied ALL base sample settings:")
    print("  - Volume:", target_sample.volume, "Panning:", target_sample.panning)
    print("  - Transpose:", target_sample.transpose, "Fine tune:", target_sample.fine_tune)
    print("  - Beat sync:", target_sample.beat_sync_enabled, "Lines:", target_sample.beat_sync_lines)
    print("  - Mute group:", target_sample.mute_group, "NNA:", target_sample.new_note_action)
    print("  - Loop mode:", target_sample.loop_mode, "Autofade:", target_sample.autofade, "Autoseek:", target_sample.autoseek)
    return true
end

-- Experimental render configuration now managed via preferences

local experimental_render_context = {
    original_bpm = 0,
    original_lpb = 0,
    original_pattern_length = 0,
    original_pattern_index = 0,
    original_track_headroom = 0,
    temp_pattern_created = false,
    temp_pattern_index = 0,
    source_track = 0,
    target_instrument = 0,
    original_instrument_index = 0,
    original_sample_index = 0,
    temp_file_path = "",
    sample_length_seconds = 0,
    calculated_bpm = 0,
    calculated_pattern_length = 0,
    dc_offset_added = false,
    dc_offset_position = 0,
    num_tracks_before = 0,
    is_sliced_instrument = false
}

function create_experimental_render_context()
    return {
        original_bpm = 0,
        original_lpb = 0,
        original_pattern_length = 0,
        original_pattern_index = 0,
        original_track_headroom = 0,
        temp_pattern_created = false,
        temp_pattern_index = 0,
        source_track = 0,
        target_instrument = 0,
        original_instrument_index = 0,
        original_sample_index = 0,
        temp_file_path = "",
        sample_length_seconds = 0,
        calculated_bpm = 0,
        calculated_pattern_length = 0,
        dc_offset_added = false,
        dc_offset_position = 0,
        num_tracks_before = 0,
        is_sliced_instrument = false
    }
end

function pakettiExperimentalSampleFXRender()
    local song = renoise.song()
    
    -- Validate we have a selected sample
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    print("DEBUG EXP: Starting experimental sample FX render")
    
    local selected_instrument = song.selected_instrument
    local is_sliced = pakettiDetectSlicedInstrument(selected_instrument)
    
    -- For sliced instruments, use the FIRST sample (original whole sample) for BPM calculation
    local sample_for_calculation
    if is_sliced then
        sample_for_calculation = selected_instrument.samples[1]  -- Always use first sample for sliced instruments
        print("DEBUG EXP: Detected sliced instrument - using first sample for BPM calculation")
    else
        sample_for_calculation = song.selected_sample  -- Use selected sample for regular instruments
        print("DEBUG EXP: Regular instrument - using selected sample for BPM calculation")
    end
    
    local sample_buffer = sample_for_calculation.sample_buffer
    
    -- Calculate sample length in seconds
    local sample_rate = sample_buffer.sample_rate
    local num_frames = sample_buffer.number_of_frames
    local sample_length_seconds = num_frames / sample_rate
    
    print("DEBUG EXP: Sample length:", sample_length_seconds, "seconds")
    
    -- Validate sample isn't too long (max 20 minutes for safety)
    if sample_length_seconds > 1200 then
        renoise.app():show_status("Sample too long (max 20 minutes supported)")
        return
    end
    
    -- Create render context and store current state
    experimental_render_context = create_experimental_render_context()
    experimental_render_context.original_bpm = song.transport.bpm
    experimental_render_context.original_lpb = song.transport.lpb
    experimental_render_context.original_pattern_index = song.selected_pattern_index
    
    -- Save loop mode state for sliced instruments
    if is_sliced then
        local first_sample = selected_instrument.samples[1]
        experimental_render_context.original_loop_mode = first_sample.loop_mode
        experimental_render_context.is_sliced_instrument = true
        print("DEBUG EXP: Saved loop mode for sliced instrument:", first_sample.loop_mode)
        -- Set loop mode to Off for rendering
        first_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
        print("DEBUG EXP: Set loop mode to Off for rendering")
    else
        experimental_render_context.is_sliced_instrument = false
    end
    experimental_render_context.original_pattern_length = song.patterns[song.selected_pattern_index].number_of_lines
    experimental_render_context.original_track_headroom = song.transport.track_headroom
    experimental_render_context.sample_length_seconds = sample_length_seconds
    experimental_render_context.source_track = song.selected_track_index
    experimental_render_context.original_instrument_index = song.selected_instrument_index
    experimental_render_context.original_sample_index = song.selected_sample_index
    experimental_render_context.is_sliced_instrument = is_sliced
    
    print("DEBUG EXP: Stored original state - BPM:", experimental_render_context.original_bpm, "LPB:", experimental_render_context.original_lpb, "Headroom:", math.lin2db(experimental_render_context.original_track_headroom), "dB")
    
    -- Use intelligent BPM detection to find appropriate render BPM
    local render_bpm, detected_bpm, beat_count = pakettiCalculateRenderBPM(num_frames, sample_rate)
    
    -- Use 512-line pattern for maximum time resolution
    local optimal_pattern_length = 512
    local target_lpb = 4  -- Standard LPB
    local optimal_bpm = render_bpm
    
    print("DEBUG EXP: Intelligent BPM detection complete")
    print("DEBUG EXP: Detected sample BPM:", string.format("%.1f", detected_bpm), "with", beat_count, "beats")
    print("DEBUG EXP: Using render BPM:", string.format("%.1f", optimal_bpm), "for sample playback + " .. preferences.experimentalRenderSilenceMultiplier.value .. " trailing silences")
    
    experimental_render_context.calculated_bpm = optimal_bpm
    experimental_render_context.calculated_pattern_length = optimal_pattern_length
    
    print("DEBUG EXP: Final calculation - BPM:", optimal_bpm, "Pattern length:", optimal_pattern_length, "LPB:", target_lpb)
    
    -- 1. Store current pattern index (already stored above)
    -- 2. Clone pattern using clonePTN approach 
    local n_patterns = #song.patterns
    local src_pat_i = song.selected_pattern_index
    local src_pat = song:pattern(src_pat_i)
    song.selected_pattern_index = n_patterns + 1  -- Clone to new pattern
    song.patterns[song.selected_pattern_index].number_of_lines = song.patterns[song.selected_pattern_index-1].number_of_lines
    song.selected_pattern:copy_from(src_pat)
    
    local temp_pattern_index = song.selected_pattern_index
    experimental_render_context.temp_pattern_created = true
    experimental_render_context.temp_pattern_index = temp_pattern_index
    
    print("DEBUG EXP: Cloned pattern to new pattern", temp_pattern_index)
    
    -- 3. Clear pattern
    song.selected_pattern:clear()
    print("DEBUG EXP: Cleared cloned pattern", temp_pattern_index)
    
    -- 4. Input appropriate note (C-4 for normal samples, or detected note for sliced instruments)
    local temp_pattern = song.patterns[temp_pattern_index]
    local pattern_track = temp_pattern:track(song.selected_track_index)
    
    -- Detect appropriate trigger note for the selected sample
    local selected_instrument = song:instrument(experimental_render_context.original_instrument_index)
    local selected_sample_index = song.selected_sample_index
    local trigger_note = pakettiDetectSampleTriggerNote(selected_instrument, selected_sample_index)
    
    if experimental_render_context.is_sliced_instrument then
        print("DEBUG EXP: Detected sliced instrument with", #selected_instrument.samples[1].slice_markers, "slice markers")
        print("DEBUG EXP: First sample (original whole sample) is mapped to note", trigger_note, "- using this to trigger complete sample")
    end
    
    pattern_track:line(1).note_columns[1].note_string = trigger_note
    pattern_track:line(1).note_columns[1].instrument_value = experimental_render_context.original_instrument_index - 1
    
    if pakettiDetectSlicedInstrument(selected_instrument) then
        print("DEBUG EXP: Added", trigger_note, "note to line 1 for sliced instrument sample", selected_sample_index, "with instrument", experimental_render_context.original_instrument_index - 1)
    else
        print("DEBUG EXP: Added", trigger_note, "note to line 1 with instrument", experimental_render_context.original_instrument_index - 1)
    end
    
    -- 5. Set BPM + LPB, resize pattern, set headroom to 0dB
    song.patterns[temp_pattern_index].number_of_lines = optimal_pattern_length
    song.transport.bpm = optimal_bpm
    song.transport.lpb = target_lpb
    song.transport.track_headroom = math.db2lin(0)  -- Set headroom to 0dB for maximum render quality
    print("DEBUG EXP: Set BPM to", optimal_bpm, "LPB to", target_lpb, "pattern to", optimal_pattern_length, "lines, and headroom to 0dB")
    
    -- 6. Render
    start_experimental_rendering()
end

function start_experimental_rendering()
    local song = renoise.song()
    local render_priority = preferences.experimentalRenderPriority.value
    local selected_track = song.selected_track
    local dc_offset_added = false
    local dc_offset_position = 0
    
    -- Check for Line Input device if using high priority
    if render_priority == "high" then
        for _, device in ipairs(selected_track.devices) do
            if device.name == "#Line Input" then
                render_priority = "realtime"
                break
            end
        end
    end
    
    print("DEBUG EXP: Starting rendering process with", render_priority, "priority")
    
    -- Add DC Offset if enabled in preferences
    if preferences.RenderDCOffset.value then
        print("DEBUG EXP: Adding DC Offset")
        for i, device in ipairs(selected_track.devices) do
            if device.display_name == "Render DC Offset" then
                dc_offset_position = i
                break
            end
        end
        
        if dc_offset_position == 0 then
            loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
            for i, device in ipairs(selected_track.devices) do
                if device.display_name == "Render DC Offset" then
                    dc_offset_position = i
                    device.parameters[2].value = 1
                    dc_offset_added = true
                    break
                end
            end
        end
    end
    
    experimental_render_context.dc_offset_added = dc_offset_added
    experimental_render_context.dc_offset_position = dc_offset_position
    
    -- Set up rendering options - render the pattern we just created
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(song.selected_sequence_index, 1),
        end_pos = renoise.SongPos(song.selected_sequence_index, experimental_render_context.calculated_pattern_length),
    }
    
    -- Create new instrument for result
    local target_instrument = song.selected_instrument_index + 1
    song:insert_instrument_at(target_instrument)
    experimental_render_context.target_instrument = target_instrument
    experimental_render_context.temp_file_path = pakettiGetTempFilePath(".wav")
    
    -- Save current solo and mute states before modifying them
    track_states = {}
    experimental_render_context.num_tracks_before = #song.tracks
    print("DEBUG EXP: Saving solo/mute states for", experimental_render_context.num_tracks_before, "tracks")
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
        if track.solo_state then
            print("DEBUG EXP: Track", i, "was soloed")
        end
    end
    
    -- Solo the track for rendering
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    song.tracks[experimental_render_context.source_track].solo_state = true
    
    print("DEBUG EXP: Starting render with options:", render_options.start_pos.line, "to", render_options.end_pos.line)
    
    -- Start rendering
    local success, error_message = song:render(render_options, experimental_render_context.temp_file_path, function() experimental_rendering_done_callback() end)
    if not success then
        print("Experimental rendering failed: " .. error_message)
        cleanup_experimental_render()
    else
        renoise.tool():add_timer(monitor_experimental_rendering, 500)
    end
end

function experimental_rendering_done_callback()
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    local song = renoise.song()
    
    print("DEBUG EXP: Rendering completed, processing result")
    
    -- Remove monitoring timer
    renoise.tool():remove_timer(monitor_experimental_rendering)
    
    -- Remove DC Offset if it was added
    if experimental_render_context.dc_offset_added and experimental_render_context.dc_offset_position > 0 then
        local track = song:track(experimental_render_context.source_track)
        if track.devices[experimental_render_context.dc_offset_position] and
           track.devices[experimental_render_context.dc_offset_position].display_name == "Render DC Offset" then
            track:delete_device_at(experimental_render_context.dc_offset_position)
        end
    end
    
    -- Restore solo and mute states properly (matching main renderer logic)
    -- First, explicitly unsolo AND unmute ALL sequencer tracks
    for i = 1, song.sequencer_track_count do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end

    -- Then handle send tracks separately (starting after master track)
    local send_track_start = song.sequencer_track_count + 2  -- +2 to skip master track
    for i = send_track_start, send_track_start + song.send_track_count - 1 do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end

    -- Then restore the original solo and mute states only for tracks that existed before rendering
    print("DEBUG EXP: Restoring solo/mute states for", experimental_render_context.num_tracks_before, "tracks")
    for i = 1, experimental_render_context.num_tracks_before do
        if track_states[i] then
            song.tracks[i].solo_state = track_states[i].solo_state
            song.tracks[i].mute_state = track_states[i].mute_state
            if track_states[i].solo_state then
                print("DEBUG EXP: Restored solo state for track", i)
            end
        end
    end
    
    -- Load result into new instrument
    song.selected_instrument_index = experimental_render_context.target_instrument
    pakettiPreferencesDefaultInstrumentLoader()
    
    local new_instrument = song:instrument(experimental_render_context.target_instrument)
    new_instrument.samples[1].sample_buffer:load_from(experimental_render_context.temp_file_path)
    os.remove(experimental_render_context.temp_file_path)
    
    -- Name the result
    local original_instrument = song:instrument(experimental_render_context.target_instrument - 1)
    local original_name = original_instrument.name
    local result_name = original_name .. " (FX Processed)"
    new_instrument.name = result_name
    new_instrument.samples[1].name = result_name
    new_instrument.samples[1].autofade = true
    
    print("DEBUG EXP: Loaded result into instrument:", result_name)
    
    -- Copy ALL settings from original to new instrument
    if experimental_render_context.is_sliced_instrument then
        print("DEBUG EXP: SLICED INSTRUMENT - Copying ALL settings from original sliced instrument to new FX-processed instrument")
        local original_sample = original_instrument.samples[1]  -- Slice markers are always in first sample
        local target_sample = new_instrument.samples[1]
        
        -- STEP 1: Copy ALL base sample settings from original first sample to new first sample
        -- (transpose, finetune, beat sync, mute group, NNA, autofade, autoseek, interpolation, oversampling, panning, volume, loops, etc.)
        if pakettiCopyBaseSampleSettings(original_sample, target_sample) then
            print("DEBUG EXP: Copied ALL base sample settings from original to new first sample")
        else
            print("DEBUG EXP: Failed to copy base sample settings")
        end
        
        -- STEP 2: Copy slice markers (this creates the slice aliases automatically)
        if pakettiCopySliceMarkers(original_sample, target_sample) then
            print("DEBUG EXP: Copied slice markers - new slices created")
            
            -- STEP 3: Copy ALL settings from each original slice to each corresponding new slice
            -- (transpose, finetune, beat sync, mute group, NNA, autofade, autoseek, interpolation, oversampling, panning, volume, loops, etc.)
            if pakettiCopySliceSettings(original_instrument, new_instrument) then
                print("DEBUG EXP: Copied ALL slice settings from original slices to new slices")
            else
                print("DEBUG EXP: Failed to copy slice settings")
            end
        else
            print("DEBUG EXP: Failed to copy slice markers")
        end
    else
        print("DEBUG EXP: REGULAR INSTRUMENT - Copying ALL settings from original sample to new FX-processed sample")
        -- For non-sliced instruments, copy ALL settings from original sample to new sample
        local original_sample = song:instrument(experimental_render_context.target_instrument - 1).samples[experimental_render_context.original_sample_index]
        local target_sample = new_instrument.samples[1]
        
        if pakettiCopyBaseSampleSettings(original_sample, target_sample) then
            print("DEBUG EXP: Copied ALL sample settings from original to new sample")
        else
            print("DEBUG EXP: Failed to copy sample settings")
        end
    end
    
    -- Apply optional silence removal before cleanup
    if preferences.experimentalRenderRemoveSilence.value then
        print("DEBUG EXP: Applying silence removal to rendered sample")
        -- Select the newly created sample for silence removal
        song.selected_instrument_index = experimental_render_context.target_instrument
        song.selected_sample_index = 1
        PakettiStripSilence()
        renoise.app():show_status("Experimental FX render complete: " .. result_name .. " (silence removed)")
    else
        renoise.app():show_status("Experimental FX render complete: " .. result_name)
    end
    
    -- Cleanup and restore original state
    cleanup_experimental_render()
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

function monitor_experimental_rendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        local progress_percent = progress * 100
        local progress_msg = string.format("Experimental Rendering: %.2f%% complete", progress_percent)
        print("Experimental rendering in progress: " .. progress_percent .. "% complete")
        renoise.app():show_status(progress_msg)
    else
        renoise.tool():remove_timer(monitor_experimental_rendering)
        print("Experimental rendering not in progress or already completed.")
    end
end

function cleanup_experimental_render()
    local song = renoise.song()
    
    print("DEBUG EXP: Cleaning up experimental render")
    
    -- Restore original BPM, LPB, and track headroom
    song.transport.bpm = experimental_render_context.original_bpm
    song.transport.lpb = experimental_render_context.original_lpb
    song.transport.track_headroom = experimental_render_context.original_track_headroom
    
    -- Restore original loop mode for sliced instruments
    if experimental_render_context.is_sliced_instrument and experimental_render_context.original_loop_mode then
        local original_instrument = song:instrument(experimental_render_context.target_instrument - 1)
        if original_instrument and #original_instrument.samples > 0 then
            local first_sample = original_instrument.samples[1]
            first_sample.loop_mode = experimental_render_context.original_loop_mode
            print("DEBUG EXP: Restored loop mode for sliced instrument to:", experimental_render_context.original_loop_mode)
        end
    end
    
    print("DEBUG EXP: Restored original state - BPM:", experimental_render_context.original_bpm, "LPB:", experimental_render_context.original_lpb, "Headroom:", math.lin2db(experimental_render_context.original_track_headroom), "dB")
    
    -- 7. Return back to original pattern index
    if experimental_render_context.temp_pattern_created and experimental_render_context.temp_pattern_index > 0 then
        song.selected_pattern_index = experimental_render_context.original_pattern_index
        print("DEBUG EXP: Cleanup - returned to original pattern", experimental_render_context.original_pattern_index)
    end
    
    -- Restore original pattern length if it was modified
    if experimental_render_context.original_pattern_length > 0 then
        local current_pattern = song.patterns[experimental_render_context.original_pattern_index]
        if current_pattern then
            current_pattern.number_of_lines = experimental_render_context.original_pattern_length
        end
    end
    
    print("DEBUG EXP: Restored original state - BPM:", song.transport.bpm, "LPB:", song.transport.lpb)
end

renoise.tool():add_keybinding{name="Global:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}
renoise.tool():add_keybinding{name="Global:Paketti:Test Peak Detection",invoke=function() pakettiTestPeakDetection() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Test Peak Detection",invoke=function() pakettiTestPeakDetection() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Test Peak Detection",invoke=function() pakettiTestPeakDetection() end}

--------
-- Pattern Matrix Selection Rendering
--------

function create_matrix_render_context()
    return {
        temp_file_path = "",
        target_instrument = 0,
        selection_start_sequence = 0,
        selection_end_sequence = 0,
        dc_offset_added = false,
        dc_offset_position = 0,
        num_tracks_before = 0
    }
end

function pakettiRenderMatrixSelection()
    local song = renoise.song()
    local sequencer = song.sequencer
    
    -- Read Pattern Matrix selection by checking all tracks and sequence slots
    local min_seq = nil
    local max_seq = nil
    local has_selection = false
    
    for track_idx = 1, #song.tracks do
        for seq_idx = 1, #sequencer.pattern_sequence do
            if sequencer:track_sequence_slot_is_selected(track_idx, seq_idx) then
                has_selection = true
                if not min_seq or seq_idx < min_seq then
                    min_seq = seq_idx
                end
                if not max_seq or seq_idx > max_seq then
                    max_seq = seq_idx
                end
            end
        end
    end
    
    -- Check if there's a valid selection
    if not has_selection or not min_seq or not max_seq then
        renoise.app():show_status("No Pattern Matrix selection found. Please select slots in Pattern Matrix first.")
        return
    end
    
    local start_pos = min_seq
    local end_pos = max_seq
    
    print("DEBUG MATRIX: Rendering matrix selection from", start_pos, "to", end_pos)
    
    -- Create New Instrument
    local target_instrument = song.selected_instrument_index + 1
    song:insert_instrument_at(target_instrument)
    song.selected_instrument_index = target_instrument
    
    -- Create render context
    local render_context = create_matrix_render_context()
    render_context.selection_start_sequence = start_pos
    render_context.selection_end_sequence = end_pos
    render_context.target_instrument = target_instrument
    
    -- Start rendering
    start_matrix_rendering(render_context)
end

function start_matrix_rendering(render_context)
    local song = renoise.song()
    local render_priority = "high"
    local dc_offset_added = false
    local dc_offset_position = 0
    
    print("DEBUG MATRIX: Starting matrix render")
    
    -- Check if ANY track has Line Input (need to check all tracks for matrix render)
    for _, track in ipairs(song.tracks) do
        for _, device in ipairs(track.devices) do
            if device.name == "#Line Input" then
                render_priority = "realtime"
                print("DEBUG MATRIX: Found Line Input device, using realtime priority")
                break
            end
        end
        if render_priority == "realtime" then
            break
        end
    end
    
    -- Add DC Offset if enabled in preferences (to master track for full render)
    if preferences.RenderDCOffset.value then
        print("DEBUG MATRIX DC: RenderDCOffset preference is enabled")
        local master_track = song:track(song.sequencer_track_count + 1)
        
        -- Check if DC Offset already exists
        for i, device in ipairs(master_track.devices) do
            if device.display_name == "Render DC Offset" then
                dc_offset_position = i
                print("DEBUG MATRIX DC: Found existing DC Offset at position", i)
                break
            end
        end
        
        if dc_offset_position == 0 then
            print("DEBUG MATRIX DC: Adding DC Offset to master track")
            local original_track_index = song.selected_track_index
            song.selected_track_index = song.sequencer_track_count + 1
            loadnative("Audio/Effects/Native/DC Offset","Render DC Offset")
            song.selected_track_index = original_track_index
            
            -- Find the newly added DC Offset
            for i, device in ipairs(master_track.devices) do
                if device.display_name == "Render DC Offset" then
                    dc_offset_position = i
                    device.parameters[2].value = 1
                    dc_offset_added = true
                    print("DEBUG MATRIX DC: Added new DC Offset at position", i)
                    break
                end
            end
        end
    else
        print("DEBUG MATRIX DC: RenderDCOffset preference is disabled")
    end
    
    -- Store DC Offset information
    render_context.dc_offset_added = dc_offset_added
    render_context.dc_offset_position = dc_offset_position
    
    -- Calculate start and end positions
    local start_sequence = render_context.selection_start_sequence
    local end_sequence = render_context.selection_end_sequence
    
    -- Get the pattern index at start position
    local start_pattern_index = song.sequencer.pattern_sequence[start_sequence]
    -- Get the pattern index at end position
    local end_pattern_index = song.sequencer.pattern_sequence[end_sequence]
    local end_pattern_lines = song.patterns[end_pattern_index].number_of_lines
    
    -- Set up rendering options
    local render_options = {
        sample_rate = preferences.renderSampleRate.value,
        bit_depth = preferences.renderBitDepth.value,
        interpolation = "precise",
        priority = render_priority,
        start_pos = renoise.SongPos(start_sequence, 1),
        end_pos = renoise.SongPos(end_sequence, end_pattern_lines),
    }
    
    print("DEBUG MATRIX: Render options - sequence", start_sequence, "to", end_sequence)
    print("DEBUG MATRIX: Start pos:", render_options.start_pos.sequence, render_options.start_pos.line)
    print("DEBUG MATRIX: End pos:", render_options.end_pos.sequence, render_options.end_pos.line)
    
    -- Save current solo and mute states
    track_states = {}
    render_context.num_tracks_before = #song.tracks
    print("DEBUG MATRIX: Saving solo/mute states for", render_context.num_tracks_before, "tracks")
    for i, track in ipairs(song.tracks) do
        track_states[i] = {
            solo_state = track.solo_state,
            mute_state = track.mute_state
        }
    end
    
    -- Unsolo all tracks (we want to render everything in the selection)
    for i, track in ipairs(song.tracks) do
        track.solo_state = false
    end
    
    render_context.temp_file_path = pakettiGetTempFilePath(".wav")
    
    -- Start rendering
    local success, error_message = song:render(render_options, render_context.temp_file_path, function() matrix_rendering_done_callback(render_context) end)
    if not success then
        print("Sequencer rendering failed: " .. error_message)
        -- Remove DC Offset if it was added
        if dc_offset_added and dc_offset_position > 0 then
            local master_track = song:track(song.sequencer_track_count + 1)
            master_track:delete_device_at(dc_offset_position)
        end
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(monitor_matrix_rendering, 500)
    end
end

function matrix_rendering_done_callback(render_context)
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    print("DEBUG MATRIX: Rendering completed")
    local song = renoise.song()
    
    -- Remove the monitoring timer
    renoise.tool():remove_timer(monitor_matrix_rendering)
    
    -- Handle DC Offset removal
    if render_context.dc_offset_position > 0 then
        print("DEBUG MATRIX DC: Removing DC Offset from master track")
        local master_track = song:track(song.sequencer_track_count + 1)
        
        if master_track.devices[render_context.dc_offset_position] and
           master_track.devices[render_context.dc_offset_position].display_name == "Render DC Offset" then
            master_track:delete_device_at(render_context.dc_offset_position)
            print("DEBUG MATRIX DC: Successfully removed DC Offset")
        end
    end
    
    -- Restore solo and mute states
    for i = 1, song.sequencer_track_count do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end
    
    local send_track_start = song.sequencer_track_count + 2
    for i = send_track_start, send_track_start + song.send_track_count - 1 do
        if song.tracks[i] then
            song.tracks[i].solo_state = false
            song.tracks[i].mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
    end
    
    -- Restore original states
    for i = 1, render_context.num_tracks_before do
        if track_states[i] then
            song.tracks[i].solo_state = track_states[i].solo_state
            song.tracks[i].mute_state = track_states[i].mute_state
        end
    end
    
    -- Load result into new instrument
    local target_instrument = render_context.target_instrument
    pakettiPreferencesDefaultInstrumentLoader()
    
    local new_instrument = song:instrument(target_instrument)
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)
    
    -- Set the selected_instrument_index
    song.selected_instrument_index = target_instrument
    
    -- Name the result with track name
    local track_name = song.selected_track.name
    if track_name == "" then
        track_name = string.format("Track%02d", song.selected_track_index)
    end
    local result_name = string.format("%s (Render S%02d-S%02d)", 
        track_name,
        render_context.selection_start_sequence, 
        render_context.selection_end_sequence)
    new_instrument.name = result_name
    new_instrument.samples[1].name = result_name
    new_instrument.samples[1].autofade = true
    
    print("DEBUG MATRIX: Created instrument:", result_name)
    renoise.app():show_status("Rendered Pattern Matrix selection: " .. result_name)
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

function monitor_matrix_rendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Sequencer rendering in progress: " .. (progress * 100) .. "% complete")
    else
        renoise.tool():remove_timer(monitor_matrix_rendering)
        print("Sequencer rendering not in progress or already completed.")
    end
end

-- Key bindings and menu entries
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Render Pattern Matrix Selection to New Instrument",invoke=function() pakettiRenderMatrixSelection() end}
renoise.tool():add_keybinding{name="Global:Paketti:Render Pattern Matrix Selection to New Instrument",invoke=function() pakettiRenderMatrixSelection() end}

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Render Pattern Matrix Selection to New Instrument",invoke=function() pakettiRenderMatrixSelection() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Render Pattern Matrix Selection to New Instrument",invoke=function() pakettiRenderMatrixSelection() end}
