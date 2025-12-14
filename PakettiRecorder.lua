local contour_sample_timer = nil

function contourShuttleRecord()
  local w = renoise.app().window
  local t = renoise.song().transport
  
  if not w.sample_record_dialog_is_visible then
    w.sample_record_dialog_is_visible = true
    t:start_stop_sample_recording()
  else
    t:start_stop_sample_recording()
    
    -- Clean up existing timer if any
    if contour_sample_timer and renoise.tool():has_timer(contourShuttleRecordMonitor) then
      renoise.tool():remove_timer(contourShuttleRecordMonitor)
      contour_sample_timer = nil
    end
    
    -- Start new timer to monitor recording completion
    contour_sample_timer = renoise.tool():add_timer(contourShuttleRecordMonitor, 100)
  end
end

function contourShuttleRecordMonitor()
  local s = renoise.song()
  
  if s.selected_sample and s.selected_sample.sample_buffer.has_sample_data then
    -- Recording finished, set properties
    s.selected_sample.autoseek = true
    s.selected_sample.autofade = true
    
    -- Stop monitoring
    contour_sample_timer = nil
    renoise.tool():remove_timer(contourShuttleRecordMonitor)
    return false
  end
  -- Continue monitoring
  return true
end

renoise.tool():add_keybinding{name="Global:Paketti:Contour Shuttle Record On/Off",invoke=function() contourShuttleRecord() end}
----
-- Keep track of the active timer
local paketti_sample_timer = nil

function PakettiSampleAndToSampleEditor()
  local w=renoise.app().window
  local t=renoise.song().transport
  local s=renoise.song()
  
  if w.sample_record_dialog_is_visible==false then
    -- Check if there's already a selected sample and create new instrument if needed
    if s.selected_sample then
      local new_instrument_index=s.selected_instrument_index + 1
      s:insert_instrument_at(new_instrument_index)
      s.selected_instrument_index=new_instrument_index
    end
    
    -- Start recording
    w.sample_record_dialog_is_visible=true
    t:start_stop_sample_recording()
  else
    -- Stop recording and start monitoring for completion
    t:start_stop_sample_recording()
    
    -- Clean up existing timer if any
    if paketti_sample_timer and renoise.tool():has_timer(PakettiSampleAndToSampleEditorMonitor) then
      renoise.tool():remove_timer(PakettiSampleAndToSampleEditorMonitor)
      paketti_sample_timer = nil
    end
    
    -- Start new timer
    paketti_sample_timer = renoise.tool():add_timer(PakettiSampleAndToSampleEditorMonitor, 100)
  end
end

function PakettiSampleAndToSampleEditorMonitor()
  local s=renoise.song()
  
  if s.selected_sample and s.selected_sample.sample_buffer.has_sample_data then
    PakettiSampleAndToSampleEditorFinish()
    -- Stop monitoring
    paketti_sample_timer = nil
    renoise.tool():remove_timer(PakettiSampleAndToSampleEditorMonitor)
    return false
  end
  -- Continue monitoring
  return true
end

function PakettiSampleAndToSampleEditorFinish()
  local w=renoise.app().window
  w.active_upper_frame=1
  w.active_middle_frame=5
  w.lock_keyboard_focus=true
  renoise.song().selected_sample.autoseek=true
  renoise.song().selected_sample.autofade=true
end

renoise.tool():add_keybinding{name="Global:Paketti:Start Sampling and Sample Editor (Record)",invoke=function() PakettiSampleAndToSampleEditor() end}
  -------

-----
function instrument_is_empty(instrument)
 local inst = renoise.song().instruments[instrument]
 local has_sample_data = false
 for sample in ipairs(inst.samples) do
  has_sample_data = has_sample_data or inst.samples[sample].sample_buffer.has_sample_data
 end
 if inst.plugin_properties.plugin_loaded or inst.midi_output_properties.device_name ~= "" or has_sample_data then return false else return true end
end

function search_empty_instrument()
  local proc = renoise.song()
    for empty_instrument = 1, #proc.instruments do local samples = false
    
    for i = 1,#proc.instruments[empty_instrument].samples do
      local temp_buffer = proc.instruments[empty_instrument].samples[i].sample_buffer
        if temp_buffer.has_sample_data then samples = true break end
    end
    
    local plugin = proc.instruments[empty_instrument].plugin_properties.plugin_loaded
    local midi_device = proc.instruments[empty_instrument].midi_output_properties.device_name
      if ((samples == false) and (plugin == false) and (midi_device == nil or midi_device == "")) then
        return empty_instrument end
      end
  proc:insert_instrument_at(#proc.instruments+1)
  return #proc.instruments
end
--------------------------------------------------------------------------------------------------------
--  delay(3)
--  renoise.song().transport:trigger_sequence(1)
---
--t:panic()
--t:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
--  startpos.line = renoise.song().selected_line_index
--  startpos.sequence = renoise.song().selected_sequence_index
--  renoise.song().transport.playback_pos = startpos
--  t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN)
--  ss.sample_buffer_observable:remove_notifier(finalrecord) 
--[[  if ss.sample_buffer_observable:has_notifier(finalrecord) then 
     ss.sample_buffer_observable:remove_notifier(finalrecord)
     return
  end
  end
]]--

---------------------------------------------------------------------------------
-- Paketti: Record to Current Track+Plus (Complete Version with max_columns)
--
-- This script:
--   - Toggles recording (start/stop) with three parameters:
--       use_metronome (bool), use_lineinput (bool), max_columns (number)
--   - If row1 has reached "max_columns" used columns, creates a new track
--     after the current one
--   - Optionally creates a new instrument if the current one isn't empty
--   - Names the track as "overdubXX"
--   - Names the instrument as "overdubXX PTN:<len> BPM:<bpm> LPB:<lpb>"
--   - Adds / removes #Line Input if use_lineinput == true
--   - Enables / disables the metronome if use_metronome == true
--   - Places a note on row1 of the pattern
--   - Trims 959 frames from the end of the recorded sample, sets autofade/autoseek
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Globals / State
--------------------------------------------------------------------------------

local am_i_recording = false
local recording_instrument = nil
local paketti_record_timer = nil
local monitor_has_printed = nil

-- These store the user's choices per recording session
local record_use_metronome = false
local record_use_lineinput = false
local record_max_columns = 12  -- default to 12 columns if not specified


--------------------------------------------------------------------------------
-- recordtocurrenttrack(use_metronome, use_lineinput, max_columns)
--
-- Toggles start/stop recording based on am_i_recording.
--   If am_i_recording == false, we start recording.
--   If am_i_recording == true, we stop recording.
-- We also:
--   - turn metronome on/off if requested
--   - add/remove line input if requested
--   - optionally create a new instrument if current one isn't empty
--   - store "max_columns" for deciding if row1 is "full"
--------------------------------------------------------------------------------
function recordtocurrenttrack(use_metronome, use_lineinput, max_columns)
  local s = renoise.song()
  local t = s.transport
  local track = s.selected_track

  -- If user omitted max_columns, default to 12
  if (max_columns == nil) then
    max_columns = 12
  end

  print("=== recordtocurrenttrack() called ===")
  print("  am_i_recording:", am_i_recording)
  print("  use_metronome:", use_metronome,
        " use_lineinput:", use_lineinput,
        " max_columns:", max_columns)
  print("  Selected track idx:", s.selected_track_index,
        "  Selected instrument idx:", s.selected_instrument_index)

  ------------------------------------------------------------------------------
  -- START RECORDING
  ------------------------------------------------------------------------------
  if (not am_i_recording) then
    am_i_recording = true
    print("== START RECORDING ==")

    -- Remember user choices so finalrecord() can see them
    record_use_metronome = use_metronome
    record_use_lineinput = use_lineinput
    record_max_columns   = max_columns

    -- 1) Check if the selected track is a sequencer track
    if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status("Please select a normal sequencer track with note columns.")
      print("  Selected track is not a sequencer track. Aborting.")
      am_i_recording = false
      return
    end

    -- 2) If user wants metronome, enable it
    if record_use_metronome then
      t.metronome_enabled = true
      print("  Turned ON the metronome.")
    end

    -- 3) Show the Sample Recorder dialog
    renoise.app().window.sample_record_dialog_is_visible = true

    -- 4) If user wants line input, ensure #Line Input is present
    if record_use_lineinput then
      local has_line_input = false
      for _, device in ipairs(track.devices) do
        if (device.name == "#Line Input") then
          has_line_input = true
          break
        end
      end
      if not has_line_input then
        loadnative("Audio/Effects/Native/#Line Input")
        print("  Added #Line Input to the current track.")
      end
    end

    -- 5) Check if the current instrument is empty; if not, create a new instrument
    local curr_instr_idx = s.selected_instrument_index
    local curr_instr = s.instruments[curr_instr_idx]
    local is_empty_instrument =
      (#curr_instr.samples == 0) and
      (not curr_instr.plugin_properties.plugin_loaded)

    if not is_empty_instrument then
      -- Insert a new instrument at "current index + 1"
      local new_instr_idx = curr_instr_idx + 1
      if new_instr_idx > (#s.instruments + 1) then
        new_instr_idx = #s.instruments + 1
      end
      s:insert_instrument_at(new_instr_idx)
      s.selected_instrument_index = new_instr_idx
      print(("  Current instrument not empty; created new instr at index %d."):
        format(new_instr_idx))
    end

    pakettiPreferencesDefaultInstrumentLoader()
  -- 6) Store the index of the instrument we are recording into
    recording_instrument = s.selected_instrument_index
    print("  Recording instrument set to:", recording_instrument)

    -- 7) Start Renoise’s sample recording
    t:start_stop_sample_recording()

  ------------------------------------------------------------------------------
  -- STOP RECORDING
  ------------------------------------------------------------------------------
  else
    am_i_recording = false
    print("== STOP RECORDING ==")

    -- 1) Stop sample recording
    local t = renoise.song().transport
    t:start_stop_sample_recording()

    -- 2) Add a timer to monitor sample data
    if recording_instrument then
      if renoise.tool():has_timer(recordtocurrenttrackMonitor) then
        print("  Timer already exists, not adding another.")
      else
        renoise.tool():add_timer(recordtocurrenttrackMonitor, 100)
        paketti_record_timer = true
        print("  Added recordtocurrenttrackMonitor timer.")
      end
    else
      print("  No recording_instrument set; unexpected scenario.")
    end
  end
end


--------------------------------------------------------------------------------
-- recordtocurrenttrackMonitor()
-- Checks every 100 ms if the sample buffer is ready, or if user closed the dialog.
--------------------------------------------------------------------------------
function recordtocurrenttrackMonitor()
  local s = renoise.song()
  local w = renoise.app().window

  -- If user forcibly closed the recorder while we still think we're recording
  if am_i_recording and (not w.sample_record_dialog_is_visible) then
    print(">> Detected user closed the sample recorder dialog.")
    renoise.app():show_status(
      "Detected Sample Recorder was closed. Catching recorded sample..."
    )
    am_i_recording = false

    -- Check if sample data is present
    if s.selected_sample
       and s.selected_sample.sample_buffer
       and s.selected_sample.sample_buffer.has_sample_data
       and (s.selected_instrument_index == recording_instrument)
    then
      print("   Some sample data is present; calling finalrecord().")
      finalrecord()
    else
      print("   No sample data found => aborting silently.")
      cleanupMonitorAndVars()
    end
    return false
  else
    -- Normal polling for sample data
    if not monitor_has_printed then
      print("Monitoring for sample data in instrument:", recording_instrument)
      monitor_has_printed = true
    else
      io.write(".")
      io.flush()
    end

    if s.selected_sample
       and s.selected_sample.sample_buffer
       and s.selected_sample.sample_buffer.has_sample_data
       and (s.selected_instrument_index == recording_instrument)
    then
      print("\nSample data found, calling finalrecord()...")
      print ("123 and " .. renoise.song().selected_sample.sample_buffer.number_of_frames)

      finalrecord()
      return false
    end

    return true
  end
end


--------------------------------------------------------------------------------
-- finalrecord()
-- We remove line input if requested, turn off metronome if requested,
-- place the note (row1 only). If row1 has "record_max_columns" used columns,
-- we create a new track after the old one, place the note, rename track & instrument,
-- etc. Also trims 959 frames from the end of the recorded sample, sets autofade/autoseek.
--------------------------------------------------------------------------------
function finalrecord()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  print(">>> finalrecord triggered!")
  local s = renoise.song()
  local curr_track_idx = s.selected_track_index
  local curr_track = s.selected_track

  -- A) If track is not sequencer, fail.
  if curr_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Please select a normal sequencer track. Aborting finalrecord.")
    print("  Current track not a sequencer track, aborting finalrecord.")
    cleanupMonitorAndVars()
    return
  end

  local pattern_idx  = s.selected_pattern_index
  local pattern_track = s.patterns[pattern_idx].tracks[curr_track_idx]
  local line1 = pattern_track.lines[1]

  -- B) If we used line input, remove it
  if record_use_lineinput then
    for i, device in ipairs(curr_track.devices) do
      if (device.name == "#Line Input") then
        curr_track:delete_device_at(i)
        print("  Removed #Line Input from track.")
        break
      end
    end
  end

  -- C) If we used metronome, turn it off
  if record_use_metronome then
    s.transport.metronome_enabled = false
    print("  Turned OFF the metronome.")
  end

  ------------------------------------------------------------------------------
  -- D) Place the note in row1. If row1 is full (meaning record_max_columns used),
  --    create a new track. Then rename track & instrument. Also do sample trimming.
  ------------------------------------------------------------------------------
  local right_instrument_value = s.selected_instrument_index - 1
  local target_column = 1

  -- We search only up to record_max_columns
  for i = 1, record_max_columns do
    if line1.note_columns[i].note_string ~= "---" then
      target_column = i + 1
    end
  end

  -- If target_column > record_max_columns => row1 is "full"
  if target_column > record_max_columns then
    local new_track_index = curr_track_idx + 1
    if new_track_index > (#s.tracks + 1) then
      new_track_index = #s.tracks + 1
    end

    s:insert_track_at(new_track_index)
    s.selected_track_index = new_track_index
    print(("  The old track is full (row1 has %d used columns). " ..
          "Created new track AFTER old track at index %d."):
          format(record_max_columns, new_track_index))

    local new_track = s.selected_track
    if new_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status("New track is not a sequencer track. Aborting note placement.")
      print("  New track is not a sequencer track, aborting note placement.")
      cleanupMonitorAndVars()
      return
    end

    local new_pattern_track = s.patterns[pattern_idx].tracks[new_track_index]
    local new_line1 = new_pattern_track.lines[1]

    -- Place note in col1
    new_line1.note_columns[1].note_string      = "C-4"
    new_line1.note_columns[1].instrument_value = right_instrument_value
    new_line1.effect_columns[1].number_string  = "0G"
    new_line1.effect_columns[1].amount_string  = "01"

    -- Visible columns = 1 (a brand new track normally starts with 1 column)
    s.tracks[new_track_index].visible_note_columns = 1
    local col_count = s.tracks[new_track_index].visible_note_columns
    s.tracks[new_track_index].name = ("Overdub%02d"):format(col_count)

    local pat_length  = s.patterns[s.selected_pattern_index].number_of_lines
    local current_bpm = math.floor(s.transport.bpm)
    local current_lpb = s.transport.lpb
    local new_instr_name =
      ("Overdub%02d PTN:%d BPM:%d LPB:%d"):format(col_count, pat_length, current_bpm, current_lpb)

    s.instruments[s.selected_instrument_index].name = new_instr_name

    print(("  Placed C-4 (instr %d) in col1 of new track's row1. " ..
           "Track named '%s', instrument named '%s'."):
        format(
          right_instrument_value,
          s.tracks[new_track_index].name,
          new_instr_name
        ))

  else
    -- Not full => place note in the old track at target_column
    s.tracks[curr_track_idx].visible_note_columns = target_column
    line1.note_columns[target_column].note_string      = "C-4"
    line1.note_columns[target_column].instrument_value = right_instrument_value
    line1.effect_columns[1].number_string             = "0G"
    line1.effect_columns[1].amount_string             = "01"

    ----------------------------------------------------------------------------
    -- Trim sample
    ----------------------------------------------------------------------------
    local sample_buffer = s.selected_sample.sample_buffer
    print ("ABC" .. sample_buffer.number_of_frames)

    local sample_buffer = s.selected_sample.sample_buffer
    print ("DEF" .. sample_buffer.number_of_frames)
    if sample_buffer and sample_buffer.has_sample_data then


      
      renoise.song().selected_sample.sample_buffer:prepare_sample_data_changes()                
      local current_frames = sample_buffer.number_of_frames
      local new_length = current_frames
      
      local current_framesv2=renoise.song().selected_sample.sample_buffer.number_of_frames

      -- Special case for 336960 frames
      if current_framesv2 == 336960 then
        new_length = 336000
      else
        -- For all other cases, remove 3500 frames from the end
        new_length = current_framesv2 - 3500
      end
      
      if new_length > 0 then
        local sample_rate  = sample_buffer.sample_rate
        local bit_depth    = sample_buffer.bit_depth
        local num_channels = sample_buffer.number_of_channels
        
        local temp_data = {}
        for channel = 1, num_channels do
          temp_data[channel] = {}
          for frame = 1, new_length do
            temp_data[channel][frame] = sample_buffer:sample_data(channel, frame)
          end
        end
        print("Oh I'm definitely doing something to the sample now.")
        sample_buffer:delete_sample_data()
        local success = sample_buffer:create_sample_data(
          sample_rate,
          bit_depth,
          num_channels,
          new_length)

          renoise.song().selected_sample.sample_buffer:prepare_sample_data_changes()          
        if success and sample_buffer.has_sample_data then
          for channel = 1, num_channels do
            for frame = 1, new_length do
              sample_buffer:set_sample_data(channel, frame, temp_data[channel][frame])
            end
          end
        end
      end
    end  
    renoise.song().selected_sample.sample_buffer:finalize_sample_data_changes()

    -- Set autofade / autoseek
    s.selected_sample.autofade = true
    local amf=renoise.app().window.active_middle_frame
    renoise.app().window.active_middle_frame = amf 
    --s.selected_sample.autoseek = true
    ----------------------------------------------------------------------------
    -- Rename track & instrument
    ----------------------------------------------------------------------------
    local col_count = s.tracks[curr_track_idx].visible_note_columns
    s.tracks[curr_track_idx].name = ("Overdub%02d"):format(col_count)

    local pat_length  = s.patterns[s.selected_pattern_index].number_of_lines
    local current_bpm = math.floor(s.transport.bpm)
    local current_lpb = s.transport.lpb
    local new_instr_name =
      ("Overdub%02d PTN:%d BPM:%d LPB:%d"):format(col_count, pat_length, current_bpm, current_lpb)
    s.instruments[s.selected_instrument_index].name = new_instr_name

    print(("  Placed C-4 (instrument %d) in col %d of old track's row1. " ..
           "Renamed track to '%s', instrument to '%s'."):
      format(
        right_instrument_value,
        target_column,
        s.tracks[curr_track_idx].name,
        new_instr_name
      ))
  end

  -- E) Cleanup
  print ("Sample is name: " .. renoise.song().selected_sample.name)
  cleanupMonitorAndVars()
  print("finalrecord complete. Timer removed, variables cleared.")
  print ("Sample is frames: " .. renoise.song().selected_sample.sample_buffer.number_of_frames)
  print (renoise.song().instruments[renoise.song().selected_instrument_index].samples[1].name) 
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)

end


--------------------------------------------------------------------------------
-- cleanupMonitorAndVars()
--------------------------------------------------------------------------------
function cleanupMonitorAndVars()
  if renoise.tool():has_timer(recordtocurrenttrackMonitor) then
    renoise.tool():remove_timer(recordtocurrenttrackMonitor)
  end
  paketti_record_timer = nil
  recording_instrument = nil
  monitor_has_printed = nil
  am_i_recording = false

  -- Reset our booleans for the next usage
  record_use_metronome = false
  record_use_lineinput = false
  record_max_columns   = 12
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12)
end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 12 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,12) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 12 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,12) end}


renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 12 (Metronome/Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(true, true,12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 12 (Metronome/no Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(true, false,12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(false, true,12) end end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(false, false,12) end end}

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 01 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Overdub 01 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,1) end}

renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 01 (Metronome/Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(true, true,1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 01 (Metronome/no Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(true, false,1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(false, true,1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function(message) if message:is_trigger() then recordtocurrenttrack(false, false,1) end end}

---

function recordfollow()
local w=renoise.app().window
local t=renoise.song().transport
local pe=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

if not t.playing then t.playing = true end

w.active_middle_frame=pe
--w.lower_frame_is_visible = true
--w.upper_frame_is_visible = true

   -- Case 1: Not editing but following
   if not t.edit_mode and t.follow_player then
    t.edit_mode = true
    t.follow_player = false
    return
end

-- Case 2: Editing and following
if t.edit_mode and t.follow_player then
    t.follow_player = false
    return
end

-- Case 3: All other cases (false/false or true/false)
t.edit_mode = true
t.follow_player = true


end

renoise.tool():add_keybinding{name="Global:Paketti:Record Follow",invoke=function() recordfollow() end}
-------------
function simpleplayrecordfollow()
local w=renoise.app().window
local t=renoise.song().transport
local pe=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
-- w.upper_frame_is_visible=false
-- w.active_middle_frame=1
-- w.lower_frame_is_visible=true  -- if lower frame is hidden, don't reshow it. 

  if t.playing and t.follow_player and t.edit_mode and w.active_middle_frame==pe
then t.follow_player=false
     t.edit_mode=false return
else t.follow_player=true
     t.edit_mode=true
     w.active_middle_frame=pe end

  if t.playing==true -- if playback is on, continue playback and follow player, toggle edit, display pattern editor
then t.follow_player=true
     t.edit_mode=true
     w.active_middle_frame=pe
else t.playing=true -- if playback is off, start playback and follow player, toggle edit, display pattern editor
     t.follow_player=true
     t.edit_mode=true
     w.active_middle_frame=pe end
end

renoise.tool():add_keybinding{name="Global:Paketti:Simple Play Record Follow",invoke=function() simpleplayrecordfollow() end}
renoise.tool():add_keybinding{name="Global:Paketti:Simple Play Record Follow (2nd)",invoke=function() simpleplayrecordfollow() end}
-- PD use
renoise.tool():add_keybinding{name="Global:Paketti:TouchOSC Sample Recorder and Record",invoke=function() handle_sample_recording() end}
renoise.tool():add_keybinding{name="Global:Paketti:TouchOSC Pattern Editor",invoke=function() renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR end}
renoise.tool():add_keybinding{name="Global:Paketti:TouchOSC Sample Editor",invoke=function() renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR end}
-------------
--renoise.app().window.active_middle_frame=sampleEditor

-- Function to handle starting and stopping sample recording
function handle_sample_recording()
  local dialog_visible = renoise.app().window.sample_record_dialog_is_visible
renoise.app().window.active_middle_frame=1
  local song=renoise.song()
renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  if not dialog_visible then
    renoise.app().window.sample_record_dialog_is_visible = true
    renoise.app().window.active_middle_frame=1
renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
renoise.song().selected_instrument_index=renoise.song().selected_instrument_index+1
    pakettiPreferencesDefaultInstrumentLoader()
    renoise.song().selected_sample.loop_mode = 2
    song.transport:start_stop_sample_recording()
    return
  else
    song.transport:start_stop_sample_recording()
    local sample=renoise.song().selected_sample
  end
 --   renoise.song().selected_sample_index=1
    local sample=renoise.song().selected_sample
--    sample.mute_group = 1
  sample.interpolation_mode=preferences.pakettiLoaderInterpolation.value
    sample.beat_sync_enabled = false
    sample.beat_sync_mode = 2
    renoise.song().selected_instrument.sample_modulation_sets[1].filter_type=preferences.pakettiLoaderFilterType.value
      if preferences.pakettiPitchbendLoaderEnvelope.value then 
        PakettiApplyLoaderModulationSettings(renoise.song().selected_instrument, "PakettiRecorder")
      end
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_mode = 2
  sample.loop_release = preferences.pakettiLoaderLoopExit.value
end

renoise.tool():add_keybinding{name="Global:Paketti:Start/Stop Sample Recording and Pakettify",invoke=function() handle_sample_recording() end}




--------
------------
function start_stop_sample_and_loop_oh_my()
  local w=renoise.app().window
  local s=renoise.song()
  local t=s.transport
  local ss=s.selected_sample
  local currTrak=s.selected_track_index
  local currPatt=s.selected_pattern_index
  
  if w.sample_record_dialog_is_visible then
      -- we are recording, stop
      t:start_stop_sample_recording()
      -- write note
       ss.autoseek=true
       s.patterns[currPatt].tracks[currTrak].lines[1].effect_columns[1].number_string="0G"
       s.patterns[currPatt].tracks[currTrak].lines[1].effect_columns[1].amount_string="01"
  
  for i= 1,12 do
  if s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].is_empty==true then
     s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].note_string="C-4"
     s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].instrument_value=s.selected_instrument_index-1
  else
   if i == renoise.song().tracks[currTrak].visible_note_columns and i == 12
    then renoise.song():insert_track_at(renoise.song().selected_track_index)
     s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[1].note_string="C-4"
     s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[1].instrument_value=s.selected_instrument_index-1
  end
  end
  end
  -- hide dialog
      w.sample_record_dialog_is_visible = false
    else
      -- not recording. show dialog, start recording.
      w.sample_record_dialog_is_visible = true
      t:start_stop_sample_recording()
    end
  end
  
  ----------------------------
  -- has-line-input + add-line-input
  function has_line_input()
  -- Write some code to find the line input in the correct place
  local tr = renoise.song().selected_track
   if tr.devices[2] and tr.devices[2].device_path=="Audio/Effects/Native/#Line Input" 
    then return true
   else
    return false
   end
  end
  
  function add_line_input()
  -- Write some code to add the line input in the correct place
   loadnative("Audio/Effects/Native/#Line Input")
  end
  
  function remove_line_input()
  -- Write some code to remove the line input if it's in the correct place
   renoise.song().selected_track:delete_device_at(2)
  end
  
  -- recordamajic
  function recordamajic9000(running)
      if running then
      renoise.song().transport.playing=true
          -- start recording code here
  renoise.app().window.sample_record_dialog_is_visible=true
  renoise.app().window.lock_keyboard_focus=true
  renoise.song().transport:start_stop_sample_recording()
      else
      -- Stop recording here
      end
  end
  
  renoise.tool():add_keybinding{name="Global:Paketti:Recordammajic9000",
  invoke=function() if has_line_input() then 
        recordtocurrenttrack()    
        G01()
   else add_line_input()
        recordtocurrenttrack()
        G01()
   end end}
  
  -- turn samplerecorder ON
  function SampleRecorderOn()
  local howmany = table.count(renoise.song().selected_track.devices)
  
  if renoise.app().window.sample_record_dialog_is_visible==false then
  renoise.app().window.sample_record_dialog_is_visible=true 
  
    if howmany == 1 then 
      loadnative("Audio/Effects/Native/#Line Input")
      return
    else
      if renoise.song().selected_track.devices[2].name=="#Line Input" then
      renoise.song().selected_track:delete_device_at(2)
      renoise.app().window.sample_record_dialog_is_visible=false
      else
      loadnative("Audio/Effects/Native/#Line Input")
      return
  end    
    end  
  
  else renoise.app().window.sample_record_dialog_is_visible=false
    if renoise.song().selected_track.devices[2].name=="#Line Input" then
    renoise.song().selected_track:delete_device_at(2)
    end
  end
  end
  
  renoise.tool():add_keybinding{name="Global:Paketti:Display Sample Recorder with #Line Input",invoke=function() SampleRecorderOn() end}

--------------------------------------------------------------------------------------------------------------------
-- Quick Sample to New Track & Instrument Toggle
-- Three modalities:
--   1. Default: Doesn't touch pattern sync setting
--   2. Sync Off: Always sets sample_recording_sync_enabled = false
--   3. Sync On + 0G01: Sets sample_recording_sync_enabled = true, writes C-4 + 0G01 on stop
--
-- First press: Create new track (with -30dB volume if preference enabled), new instrument, 
--              open sample recorder, start recording
-- Second press: Stop recording, apply autoseek/autofade (and write 0G01 for mode 3)
-- Preference: pakettiQuickSampleTrackVolume (boolean) - Set new track volume to -30dB
--------------------------------------------------------------------------------------------------------------------

-- State tracking for all three modalities
local paketti_quick_sample_state = {
  recording_active = false,
  mode = nil,  -- nil=default, "sync_off", "sync_on_0g01"
  track_index = nil,
  pattern_index = nil,
  instrument_index = nil
}

-- Monitor function for modes without 0G01
function PakettiQuickSampleMonitor()
  local song = renoise.song()
  
  if song.selected_sample and song.selected_sample.sample_buffer.has_sample_data then
    -- Sample data has arrived, apply settings
    song.selected_sample.autoseek = true
    song.selected_sample.autofade = true
    print("=== Paketti Quick Sample: Sample received ===")
    print("  Applied autoseek=true, autofade=true")
    
    -- Stop monitoring
    if renoise.tool():has_timer(PakettiQuickSampleMonitor) then
      renoise.tool():remove_timer(PakettiQuickSampleMonitor)
    end
    return false
  end
  
  -- Continue monitoring
  return true
end

-- Monitor function for Sync On + 0G01 mode
function PakettiQuickSampleMonitor0G01()
  local song = renoise.song()
  local state = paketti_quick_sample_state
  
  if song.selected_sample and song.selected_sample.sample_buffer.has_sample_data then
    -- Sample data has arrived, apply settings
    song.selected_sample.autoseek = true
    song.selected_sample.autofade = true
    print("=== Paketti Quick Sample (Sync On + 0G01): Sample received ===")
    print("  Applied autoseek=true, autofade=true")
    
    -- Write C-4 + 0G01 to line 1 of the recorded track
    if state.track_index and state.pattern_index and state.instrument_index then
      local pattern = song.patterns[state.pattern_index]
      if pattern and pattern.tracks[state.track_index] then
        local line = pattern.tracks[state.track_index].lines[1]
        local instrument_value = state.instrument_index - 1  -- 0-based for display
        
        line.note_columns[1].note_string = "C-4"
        line.note_columns[1].instrument_value = instrument_value
        line.effect_columns[1].number_string = "0G"
        line.effect_columns[1].amount_string = "01"
        
        -- Make sure effect column is visible
        if song.tracks[state.track_index].visible_effect_columns < 1 then
          song.tracks[state.track_index].visible_effect_columns = 1
        end
        
        print(string.format("  Wrote C-4 (instrument %02X) + 0G01 to Track %d, Pattern %d, Line 1", 
          instrument_value, state.track_index, state.pattern_index))
      end
    end
    
    -- Stop monitoring
    if renoise.tool():has_timer(PakettiQuickSampleMonitor0G01) then
      renoise.tool():remove_timer(PakettiQuickSampleMonitor0G01)
    end
    return false
  end
  
  -- Continue monitoring
  return true
end

-- Core function for all three modalities
-- mode: nil=default (don't touch sync), "sync_off", "sync_on_0g01"
function PakettiQuickSampleToNewTrackCore(mode)
  local song = renoise.song()
  local transport = song.transport
  local window = renoise.app().window
  local state = paketti_quick_sample_state
  
  local mode_name = mode or "Default"
  if mode == "sync_off" then mode_name = "Sync Off"
  elseif mode == "sync_on_0g01" then mode_name = "Sync On + 0G01"
  end
  
  if not state.recording_active then
    -- FIRST PRESS: Setup and start recording
    print(string.format("=== Paketti Quick Sample (%s): Starting ===", mode_name))
    
    -- 1) Create a new track after the current track (but before send/master tracks)
    local current_track_index = song.selected_track_index
    local new_track_index = current_track_index + 1
    
    -- Make sure we don't insert after send/master tracks
    if new_track_index > song.sequencer_track_count then
      new_track_index = song.sequencer_track_count + 1
    end
    
    song:insert_track_at(new_track_index)
    song.selected_track_index = new_track_index
    print(string.format("  Created and selected new track at index %d", new_track_index))
    
    -- 2) Set track volume to -30dB if preference is enabled
    if preferences.pakettiQuickSampleTrackVolume.value then
      -- -30dB = 10^(-30/20) = 10^(-1.5) ≈ 0.0316
      local minus_30db_linear = math.pow(10, -30 / 20)
      song.tracks[new_track_index].prefx_volume.value = minus_30db_linear
      print(string.format("  Set track volume to -30dB (linear: %.4f)", minus_30db_linear))
    end
    
    -- 3) Create a new instrument after the current instrument
    local current_instrument_index = song.selected_instrument_index
    local new_instrument_index = current_instrument_index + 1
    
    if new_instrument_index > #song.instruments + 1 then
      new_instrument_index = #song.instruments + 1
    end
    
    song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    print(string.format("  Created and selected new instrument at index %d", new_instrument_index))
    
    -- 4) Set pattern sync mode based on modality
    if mode == "sync_off" then
      transport.sample_recording_sync_enabled = false
      print("  Pattern Sync: OFF")
    elseif mode == "sync_on_0g01" then
      transport.sample_recording_sync_enabled = true
      print("  Pattern Sync: ON (will write 0G01 on stop)")
    else
      print(string.format("  Pattern Sync: %s (unchanged)", transport.sample_recording_sync_enabled and "ON" or "OFF"))
    end
    
    -- 5) Show the sample recorder dialog
    window.sample_record_dialog_is_visible = true
    print("  Opened Sample Recorder dialog")
    
    -- 6) Store state for later use
    state.recording_active = true
    state.mode = mode
    state.track_index = new_track_index
    state.pattern_index = song.selected_pattern_index
    state.instrument_index = new_instrument_index
    
    -- 7) Start sample recording
    transport:start_stop_sample_recording()
    print("  Started sample recording")
    
    -- 8) For Sync On + 0G01 mode: ensure playback is running (Pattern sync requires it)
    if mode == "sync_on_0g01" then
      if not transport.playing then
        transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
        print("  Started playback (Pattern sync requires playback)")
      else
        print("  Playback already running, continuing...")
      end
    end
    
    print(string.format("=== Paketti Quick Sample (%s): Recording... Press again to stop ===", mode_name))
    
  else
    -- SECOND PRESS: Stop recording
    print(string.format("=== Paketti Quick Sample (%s): Stopping ===", mode_name))
    
    transport:start_stop_sample_recording()
    state.recording_active = false
    
    -- Choose appropriate monitor based on mode
    if state.mode == "sync_on_0g01" then
      -- Clean up existing timer if any, then start fresh
      if renoise.tool():has_timer(PakettiQuickSampleMonitor0G01) then
        renoise.tool():remove_timer(PakettiQuickSampleMonitor0G01)
      end
      if renoise.tool():has_timer(PakettiQuickSampleMonitor) then
        renoise.tool():remove_timer(PakettiQuickSampleMonitor)
      end
      
      -- Start timer to monitor when sample data arrives (0G01 version)
      renoise.tool():add_timer(PakettiQuickSampleMonitor0G01, 100)
      print("  Stopped sample recording, waiting for sample data (will write 0G01)...")
    else
      -- Clean up existing timer if any, then start fresh
      if renoise.tool():has_timer(PakettiQuickSampleMonitor) then
        renoise.tool():remove_timer(PakettiQuickSampleMonitor)
      end
      if renoise.tool():has_timer(PakettiQuickSampleMonitor0G01) then
        renoise.tool():remove_timer(PakettiQuickSampleMonitor0G01)
      end
      
      -- Start timer to monitor when sample data arrives
      renoise.tool():add_timer(PakettiQuickSampleMonitor, 100)
      print("  Stopped sample recording, waiting for sample data...")
    end
    
    -- Clear mode for next use
    state.mode = nil
  end
end

-- Modality 1: Default (doesn't touch pattern sync)
function PakettiQuickSampleToNewTrackToggle()
  PakettiQuickSampleToNewTrackCore(nil)
end

-- Modality 2: Sync Off
function PakettiQuickSampleToNewTrackToggleSyncOff()
  PakettiQuickSampleToNewTrackCore("sync_off")
end

-- Modality 3: Sync On + 0G01
function PakettiQuickSampleToNewTrackToggleSyncOn0G01()
  PakettiQuickSampleToNewTrackCore("sync_on_0g01")
end

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Quick Sample to New Track & Instrument (Toggle)",invoke=function() PakettiQuickSampleToNewTrackToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Sample to New Track & Instrument (Sync Off)",invoke=function() PakettiQuickSampleToNewTrackToggleSyncOff() end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Sample to New Track & Instrument (Sync On + 0G01)",invoke=function() PakettiQuickSampleToNewTrackToggleSyncOn0G01() end}

-- MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Quick Sample to New Track & Instrument (Toggle) x[Toggle]",invoke=function(message) if message:is_trigger() then PakettiQuickSampleToNewTrackToggle() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Sample to New Track & Instrument (Sync Off) x[Toggle]",invoke=function(message) if message:is_trigger() then PakettiQuickSampleToNewTrackToggleSyncOff() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Sample to New Track & Instrument (Sync On + 0G01) x[Toggle]",invoke=function(message) if message:is_trigger() then PakettiQuickSampleToNewTrackToggleSyncOn0G01() end end}
