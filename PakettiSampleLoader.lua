-- Define render state (initialized when starting to render)
render_context = {
    source_track = 0,
    target_track = 0,
    target_instrument = 0,
    temp_file_path = "",
    num_tracks_before = 0  -- Add this to keep track of the original number of tracks
}

-- Variable to store the original solo and mute states
local track_states = {}

-- Function to initiate rendering
function start_rendering()
    local song = renoise.song()
    local render_priority = "high"
    local selected_track = song.selected_track

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
        start_pos = renoise.SongPos(song.selected_sequence_index, 1),
        end_pos = renoise.SongPos(song.selected_sequence_index, song.patterns[song.selected_pattern_index].number_of_lines),
    }

    -- Save current solo and mute states of all tracks
    track_states = {}
    render_context.num_tracks_before = #song.tracks  -- Save the number of tracks before rendering
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
    song.tracks[song.selected_track_index].solo_state = true

    -- Set render context
    render_context.source_track = song.selected_track_index
    render_context.target_track = render_context.source_track + 1
    render_context.target_instrument = song.selected_instrument_index + 1
    render_context.temp_file_path = os.tmpname() .. ".wav"

    -- Start rendering
    local success, error_message = song:render(render_options, render_context.temp_file_path, rendering_done_callback)
    if not success then
        print("Rendering failed: " .. error_message)
    else
        -- Start a timer to monitor rendering progress
        renoise.tool():add_timer(monitor_rendering, 500)
    end
end

-- Callback function that gets called when rendering is complete
function rendering_done_callback()
    print("Rendering done callback started")
    local song = renoise.song()
    local renderTrack = render_context.source_track
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
    for i = 1, render_context.num_tracks_before do
        if track_states[i] then
            song.tracks[i].solo_state = track_states[i].solo_state
            song.tracks[i].mute_state = track_states[i].mute_state
        end
    end

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

    -- Change Selected Track to Rendered Track
    song.selected_track_index = song.selected_track_index + 1

    -- Load default instrument (assuming this function is defined)
    pakettiPreferencesDefaultInstrumentLoader()

    -- Add *Instr. Macros to Rendered Track
    local new_instrument = song:instrument(song.selected_instrument_index)

    -- Load Sample into New Instrument Sample Buffer
    new_instrument.samples[1].sample_buffer:load_from(render_context.temp_file_path)
    os.remove(render_context.temp_file_path)

    -- Set the selected_instrument_index to the newly created instrument
    song.selected_instrument_index = renderedInstrument - 1

    -- Insert New Track Next to Render Track
    song:insert_track_at(renderedTrack)
    local renderName = song.tracks[renderTrack].name

    -- Ensure we are editing the correct pattern
    local selected_pattern_index = song.selected_pattern_index
    local pattern_track = song.patterns[selected_pattern_index]:track(renderedTrack)

    -- Place the note in the new track
    pattern_track:line(1).note_columns[1].note_string = "C-4"
    pattern_track:line(1).note_columns[1].instrument_value = song.selected_instrument_index - 1

    -- Add *Instr. Macros to selected Track (assuming this function is defined)
    loadnative("Audio/Effects/Native/*Instr. Macros")
    song.selected_track.devices[2].is_maximized = false

    -- Rename Sample Slot to Render Track
    new_instrument.samples[1].name = renderName .. " (Rendered)"

    -- Select New Track
    print(renderedTrack .. " this was the track but is it really the track?")
    song.selected_track_index = renderedTrack

    -- Rename New Track using Render Track Name
    song.tracks[renderedTrack].name = renderName .. " (Rendered)"
    new_instrument.name = renderName .. " (Rendered)"
    new_instrument.samples[1].autofade = true

    if song.transport.edit_mode then
        song.transport.edit_mode = false
        song.transport.edit_mode = true
    else
        song.transport.edit_mode = true
        song.transport.edit_mode = false
    end
    renoise.song().selected_track.mute_state=1
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
function render_group_track()
    local song = renoise.song()
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

    -- Start rendering
    start_rendering()
end

function pakettiCleanRenderSelection()
    local song = renoise.song()
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
        render_group_track()
    else
        start_rendering()
    end
end

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Clean Render..:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Clean Render..:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Clean Render Selected Track/Group",invoke=function() pakettiCleanRenderSelection() end}
