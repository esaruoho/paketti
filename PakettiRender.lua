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
    render_context.temp_file_path = os.tmpname() .. ".wav"

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
            loadnative("Audio/Effects/Native/*Instr. Macros")
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
            loadnative("Audio/Effects/Native/*Instr. Macros")
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
  render_context.temp_file_path = os.tmpname() .. ".wav"

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
  loadnative("Audio/Effects/Native/*Instr. Macros")
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
  render_context.temp_file_path = os.tmpname() .. ".wav"
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
  end end end

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
  render_context.temp_file_path = os.tmpname() .. ".wav"

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
  PakettiSeamlessCheckAndResizePattern()
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
    render_context.temp_file_path = os.tmpname() .. ".wav"

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
            loadnative("Audio/Effects/Native/*Instr. Macros")
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

function pakettiCountBPM(sample_length_frames, sample_rate, beats_in_sample)
    -- Calculate sample length in seconds
    -- samples / samplerate = time
    local time_in_seconds = sample_length_frames / sample_rate
    
    -- Calculate time per beat
    -- time / beats = time factor (time per beat)
    local time_per_beat = time_in_seconds / beats_in_sample
    
    -- Calculate BPM
    -- 60 / time factor = bpm
    local bpm = 60 / time_per_beat
    
    print("DEBUG BPM: Sample length:", sample_length_frames, "frames")
    print("DEBUG BPM: Sample rate:", sample_rate, "Hz") 
    print("DEBUG BPM: Time in seconds:", time_in_seconds)
    print("DEBUG BPM: Beats in sample:", beats_in_sample)
    print("DEBUG BPM: Time per beat:", time_per_beat, "seconds")
    print("DEBUG BPM: Calculated BPM:", bpm)
    
    return bpm
end

-- Test function that analyzes the currently selected sample
function pakettiTestBPMCalculation()
    local song = renoise.song()
    
    -- Check if we have a selected sample
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer
    
    -- Get real sample data from Renoise
    local sample_length_frames = sample_buffer.number_of_frames
    local sample_rate = sample_buffer.sample_rate
    local bit_depth = sample_buffer.bit_depth
    local num_channels = sample_buffer.number_of_channels
    
    -- Calculate sample length in seconds
    local sample_length_seconds = sample_length_frames / sample_rate
    
    print("=== REAL SAMPLE ANALYSIS ===")
    print("Sample name:", sample.name)
    print("Sample length:", sample_length_frames, "frames")
    print("Sample rate:", sample_rate, "Hz")
    print("Bit depth:", bit_depth, "bits")
    print("Channels:", num_channels)
    print("Duration:", sample_length_seconds, "seconds")
    
    -- Assume it's a 4-beat loop for testing (user can modify this)
    local assumed_beats = 4
    local calculated_bpm = pakettiCountBPM(sample_length_frames, sample_rate, assumed_beats)
    
    renoise.app():show_status(string.format("Sample: %s | %d frames @ %dHz = %.2fs | Assuming %d beats = %.1f BPM", 
        sample.name, sample_length_frames, sample_rate, sample_length_seconds, assumed_beats, calculated_bpm))
end

-- Function to analyze sample with custom beat count
function pakettiAnalyzeSampleBPM(beats_in_sample)
    local song = renoise.song()
    
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return nil
    end
    
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer
    
    local sample_length_frames = sample_buffer.number_of_frames
    local sample_rate = sample_buffer.sample_rate
    
    return pakettiCountBPM(sample_length_frames, sample_rate, beats_in_sample)
end

-- Intelligent BPM detection - finds the beat count that gives reasonable BPM (80-180)
function pakettiDetectSampleBPM(sample_length_frames, sample_rate)
    local beat_counts = {1, 2, 4, 8, 16, 32}
    local reasonable_bpm_min = 80
    local reasonable_bpm_max = 180
    
    print("=== INTELLIGENT BPM DETECTION ===")
    print("Sample:", sample_length_frames, "frames @", sample_rate, "Hz")
    
    for _, beat_count in ipairs(beat_counts) do
        local bpm = pakettiCountBPM(sample_length_frames, sample_rate, beat_count)
        print("Testing", beat_count, "beats:", string.format("%.1f", bpm), "BPM")
        
        if bpm >= reasonable_bpm_min and bpm <= reasonable_bpm_max then
            print("*** FOUND REASONABLE BPM:", string.format("%.1f", bpm), "with", beat_count, "beats ***")
            return bpm, beat_count
        end
    end
    
    -- If no reasonable BPM found, use 4 beats as fallback
    local fallback_bpm = pakettiCountBPM(sample_length_frames, sample_rate, 4)
    print("No reasonable BPM found, using 4-beat fallback:", string.format("%.1f", fallback_bpm), "BPM")
    return fallback_bpm, 4
end

-- Function to detect sample BPM and calculate render BPM  
function pakettiCalculateRenderBPM(sample_length_frames, sample_rate)
    local detected_bpm, beat_count = pakettiDetectSampleBPM(sample_length_frames, sample_rate)
    
    -- Use detected BPM divided by 4 for rendering (to ensure full sample + trails fit)
    local render_bpm = detected_bpm / 4
    
    print("=== RENDER BPM CALCULATION ===")
    print("Detected BPM:", string.format("%.1f", detected_bpm), "with", beat_count, "beats")
    print("Render BPM:", string.format("%.1f", render_bpm), "(detected ÷ 4)")
    
    return render_bpm, detected_bpm, beat_count
end

--------
-- Experimental Sample FX Renderer
-- Renders a long sample through track/sample FX by creating temporary playback environment
--------

local experimental_render_context = {
    original_bpm = 0,
    original_lpb = 0,
    original_pattern_length = 0,
    original_pattern_index = 0,
    temp_pattern_created = false,
    temp_pattern_index = 0,
    source_track = 0,
    target_instrument = 0,
    original_instrument_index = 0,
    temp_file_path = "",
    sample_length_seconds = 0,
    calculated_bpm = 0,
    calculated_pattern_length = 0,
    dc_offset_added = false,
    dc_offset_position = 0,
    num_tracks_before = 0
}

function create_experimental_render_context()
    return {
        original_bpm = 0,
        original_lpb = 0,
        original_pattern_length = 0,
        original_pattern_index = 0,
        temp_pattern_created = false,
        temp_pattern_index = 0,
        source_track = 0,
        target_instrument = 0,
        original_instrument_index = 0,
        temp_file_path = "",
        sample_length_seconds = 0,
        calculated_bpm = 0,
        calculated_pattern_length = 0,
        dc_offset_added = false,
        dc_offset_position = 0,
        num_tracks_before = 0
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
    
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer
    
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
    experimental_render_context.original_pattern_length = song.patterns[song.selected_pattern_index].number_of_lines
    experimental_render_context.sample_length_seconds = sample_length_seconds
    experimental_render_context.source_track = song.selected_track_index
    experimental_render_context.original_instrument_index = song.selected_instrument_index
    
    print("DEBUG EXP: Stored original state - BPM:", experimental_render_context.original_bpm, "LPB:", experimental_render_context.original_lpb)
    
    -- Use intelligent BPM detection to find appropriate render BPM
    local render_bpm, detected_bpm, beat_count = pakettiCalculateRenderBPM(num_frames, sample_rate)
    
    -- Use 512-line pattern for maximum time resolution
    local optimal_pattern_length = 512
    local target_lpb = 4  -- Standard LPB
    local optimal_bpm = render_bpm
    
    print("DEBUG EXP: Intelligent BPM detection complete")
    print("DEBUG EXP: Detected sample BPM:", string.format("%.1f", detected_bpm), "with", beat_count, "beats")
    print("DEBUG EXP: Using render BPM:", string.format("%.1f", optimal_bpm), "for full sample + trails")
    
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
    
    -- 4. Input C-4
    local temp_pattern = song.patterns[temp_pattern_index]
    local pattern_track = temp_pattern:track(song.selected_track_index)
    pattern_track:line(1).note_columns[1].note_string = "C-4"
    pattern_track:line(1).note_columns[1].instrument_value = experimental_render_context.original_instrument_index -1
    print("DEBUG EXP: Added C-4 note to line 1 with instrument", experimental_render_context.original_instrument_index - 1)
    
    -- 5. Set BPM + LPB, resize pattern
    song.patterns[temp_pattern_index].number_of_lines = optimal_pattern_length
    song.transport.bpm = optimal_bpm
    song.transport.lpb = target_lpb
    print("DEBUG EXP: Set BPM to", optimal_bpm, "LPB to", target_lpb, "and resized pattern to", optimal_pattern_length, "lines")
    
    -- 6. Render
    start_experimental_rendering()
end

function start_experimental_rendering()
    local song = renoise.song()
    local render_priority = "high"
    local selected_track = song.selected_track
    local dc_offset_added = false
    local dc_offset_position = 0
    
    print("DEBUG EXP: Starting rendering process")
    
    -- Check for Line Input device
    for _, device in ipairs(selected_track.devices) do
        if device.name == "#Line Input" then
            render_priority = "realtime"
            break
        end
    end
    
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
    experimental_render_context.temp_file_path = os.tmpname() .. ".wav"
    
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
    local original_name = song:instrument(experimental_render_context.target_instrument - 1).name
    local result_name = original_name .. " (FX Processed)"
    new_instrument.name = result_name
    new_instrument.samples[1].name = result_name
    new_instrument.samples[1].autofade = true
    
    print("DEBUG EXP: Loaded result into instrument:", result_name)
    
    -- Cleanup and restore original state
    cleanup_experimental_render()
    
    renoise.app():show_status("Experimental FX render complete: " .. result_name)
end

function monitor_experimental_rendering()
    if renoise.song().rendering then
        local progress = renoise.song().rendering_progress
        print("Experimental rendering in progress: " .. (progress * 100) .. "% complete")
    else
        renoise.tool():remove_timer(monitor_experimental_rendering)
        print("Experimental rendering not in progress or already completed.")
    end
end

function cleanup_experimental_render()
    local song = renoise.song()
    
    print("DEBUG EXP: Cleaning up experimental render")
    
    -- Restore original BPM and LPB
    song.transport.bpm = experimental_render_context.original_bpm
    song.transport.lpb = experimental_render_context.original_lpb
    
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

-- Key bindings for experimental renderer
renoise.tool():add_keybinding{name="Global:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}

-- Menu entries  
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Experimental Sample FX Render",invoke=function() pakettiExperimentalSampleFXRender() end}

-- BPM calculation keybindings and menus
renoise.tool():add_keybinding{name="Global:Paketti:Analyze Sample BPM (4 beats)",invoke=function() pakettiTestBPMCalculation() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (4 beats)",invoke=function() pakettiTestBPMCalculation() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (1 beat)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(1)
    if bpm then renoise.app():show_status("Sample BPM (1 beat): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (2 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(2)
    if bpm then renoise.app():show_status("Sample BPM (2 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (8 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(8)
    if bpm then renoise.app():show_status("Sample BPM (8 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (16 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(16)
    if bpm then renoise.app():show_status("Sample BPM (16 beats): " .. string.format("%.1f", bpm)) end
end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Analyze Sample BPM (4 beats)",invoke=function() pakettiTestBPMCalculation() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Analyze Sample BPM (1 beat)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(1)
    if bpm then renoise.app():show_status("Sample BPM (1 beat): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Analyze Sample BPM (8 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(8)
    if bpm then renoise.app():show_status("Sample BPM (8 beats): " .. string.format("%.1f", bpm)) end
end}

-- Sample Editor Ruler menu entries
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (1 beat)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(1)
    if bpm then renoise.app():show_status("Sample BPM (1 beat): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (2 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(2)
    if bpm then renoise.app():show_status("Sample BPM (2 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (4 beats)",invoke=function() pakettiTestBPMCalculation() end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (8 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(8)
    if bpm then renoise.app():show_status("Sample BPM (8 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (16 beats)",invoke=function() 
    local bpm = pakettiAnalyzeSampleBPM(16)
    if bpm then renoise.app():show_status("Sample BPM (16 beats): " .. string.format("%.1f", bpm)) end
end}

-- Intelligent BPM detection menu entries
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Intelligent BPM Detection",invoke=function() 
    local song = renoise.song()
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample_buffer = song.selected_sample.sample_buffer
    local detected_bpm, beat_count = pakettiDetectSampleBPM(sample_buffer.number_of_frames, sample_buffer.sample_rate)
    renoise.app():show_status(string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count))
end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Intelligent BPM Detection",invoke=function() 
    local song = renoise.song()
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample_buffer = song.selected_sample.sample_buffer
    local detected_bpm, beat_count = pakettiDetectSampleBPM(sample_buffer.number_of_frames, sample_buffer.sample_rate)
    renoise.app():show_status(string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count))
end}

renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Intelligent BPM Detection",invoke=function() 
    local song = renoise.song()
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample_buffer = song.selected_sample.sample_buffer
    local detected_bpm, beat_count = pakettiDetectSampleBPM(sample_buffer.number_of_frames, sample_buffer.sample_rate)
    renoise.app():show_status(string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count))
end}
