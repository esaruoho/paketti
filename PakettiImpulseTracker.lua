----------------------------------------------------------------------------------------------------------------
-- F2
function F2()
local w=renoise.app().window
local raw=renoise.ApplicationWindow
w.lock_keyboard_focus=true

if w.active_middle_frame==raw.MIDDLE_FRAME_PATTERN_EDITOR and w.lower_frame_is_visible then
--renoise.app().window:select_preset(8)
  w.lower_frame_is_visible=false
    renoise.app().window.pattern_advanced_edit_is_visible=false
  w.upper_frame_is_visible=false
  w.pattern_advanced_edit_is_visible=false
  w.instrument_box_is_visible=true
  w.disk_browser_is_visible=true
  w.pattern_matrix_is_visible=false
else w.active_middle_frame=raw.MIDDLE_FRAME_PATTERN_EDITOR
  w.lower_frame_is_visible=true
  w.upper_frame_is_visible=true
    renoise.app().window.pattern_advanced_edit_is_visible=false
  w.active_lower_frame=raw.LOWER_FRAME_TRACK_DSPS
--w.pattern_advanced_edit_is_visible=true
  w.instrument_box_is_visible=true
  w.disk_browser_is_visible=true
-- w.pattern_matrix_is_visible = true
return end

if w.disk_browser_is_visible then
  w.active_middle_frame=raw.MIDDLE_FRAME_PATTERN_EDITOR
  w.lower_frame_is_visible=false
  w.upper_frame_is_visible=false
  w.pattern_advanced_edit_is_visible=false
  w.disk_browser_is_visible=false
    renoise.app().window.pattern_advanced_edit_is_visible=true
--renoise.app().window:select_preset(8)
return end 

--if preferences.upperFramePreference ~= 0 then  w.active_upper_frame = preferences.upperFramePreference else end


end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F2 Pattern Editor",invoke=function() F2() end}

-- F2
function F2Only()
local w=renoise.app().window
local raw=renoise.ApplicationWindow
w.active_middle_frame=raw.MIDDLE_FRAME_PATTERN_EDITOR
w.lower_frame_is_visible=true
w.upper_frame_is_visible=true
w.active_lower_frame=raw.LOWER_FRAME_TRACK_DSPS
end
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F2 Pattern Editor ONLY",invoke=function() F2Only() end}
----------------------------------------------------------------------------------------------------------------
function MixerToF2()
local w=renoise.app().window
if w.active_middle_frame == 2 then F2() else w.active_middle_frame=2 end
w.pattern_matrix_is_visible=false
w.pattern_advanced_edit_is_visible=false
w.instrument_box_is_visible=true
w.disk_browser_is_visible=true
end

renoise.tool():add_keybinding{name="Mixer:Paketti:To Pattern Editor",invoke=function() MixerToF2() end}
----------------------------------------------------------------------------------------------------------------
function F2mini()
local w=renoise.app().window
w.lock_keyboard_focus=true
w.active_middle_frame = 1
w.lower_frame_is_visible=false 
w.upper_frame_is_visible=false 
w.pattern_advanced_edit_is_visible=false 
w.instrument_box_is_visible=false
w.disk_browser_is_visible=false
w.pattern_matrix_is_visible=false
end
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F2 Pattern Editor Mini",invoke=function() F2mini() end}
----------------------------------------------------------------------------------------------------------------
-- F3
function F3()
  local w = renoise.app().window
  local raw = renoise.ApplicationWindow

if w.active_middle_frame == raw.MIDDLE_FRAME_MIXER and w.upper_frame_is_visible == false then
w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
w.upper_frame_is_visible = true
return else end
  if w.active_middle_frame == raw.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR or 
     w.active_middle_frame == raw.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR or 
     w.active_middle_frame == raw.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR or 
     w.active_middle_frame == raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES or
     w.active_middle_frame == raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION 
     then
    w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    w.lock_keyboard_focus = true
    w.disk_browser_is_visible = true
    w.instrument_box_is_visible = true
    return
  end

  if w.active_middle_frame == 5 then
    w.active_middle_frame = 7
    return
  elseif w.active_middle_frame == 7 then
    w.active_middle_frame = 5
    return
  end

  -- Rest of the original logic remains unchanged
  w.pattern_matrix_is_visible = false
  w.pattern_advanced_edit_is_visible = false

  if w.active_middle_frame == 1 then
    w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    w.lock_keyboard_focus = true
    w.disk_browser_is_visible = true
    w.instrument_box_is_visible = true

    if w.upper_frame_is_visible == true then
      w.active_upper_frame = 2
    else
      return
    end

    w.upper_frame_is_visible = true
    w.active_upper_frame = 2
    return
  else
  end

  if w.upper_frame_is_visible == true then
  else
    return
  end

  if w.active_middle_frame == raw.MIDDLE_FRAME_PATTERN_EDITOR and w.lower_frame_is_visible == false and w.pattern_advanced_edit_is_visible == false and w.upper_frame_is_visible == false then
    w.upper_frame_is_visible = true
    w.disk_browser_is_visible = true
    return
  else
  end

  local s = renoise.song()
  s.selected_instrument.active_tab = 1
  w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end


renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F3 Sample Editor",invoke=function() F3() end}

---


-- F3 Only
function F3Only()
local w=renoise.app().window
local s=renoise.song()
local raw=renoise.ApplicationWindow
w.pattern_matrix_is_visible=false
w.pattern_advanced_edit_is_visible=false
w.upper_frame_is_visible = true
w.disk_browser_is_visible=true
s.selected_instrument.active_tab=1
w.active_middle_frame=raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F3 Sample Editor Only",invoke=function() F3Only() end}
----------------------------------------------------------------------------------------------------------------
-- F4, or "Impulse Tracker Shortcut F4 display-change", "Instrument Editor".
-- Hides Pattern Matrix, Hides Advanced Edit.
-- Changes to Sample Keyzones, Disk Browser, Instrument Settings.
-- Sample Recorder will stay open, if Sample Recorder is already open.
function F4()
local w=renoise.app().window
local raw=renoise.ApplicationWindow
--if w.active_upper_frame == 1  and  w.active_middle_frame == 3  and w.active_lower_frame == 3 and w.disk_browser_is_expanded==false
--then w.disk_browser_is_expanded=true return
--end
--w.lower_frame_is_visible=true
--w.upper_frame_is_visible=true
--if preferences.upperFramePreference ~= 0 then 
-- w.active_upper_frame = preferences.upperFramePreference
--else end

--w.active_upper_frame=1 -- Force-sets to Track Scopes.
--w.active_lower_frame =3 -- Set to Instrument Settings
--w.lock_keyboard_focus=true
--w.pattern_matrix_is_visible=false
--w.pattern_advanced_edit_is_visible=false
--w.disk_browser_is_expanded=true
if w.active_middle_frame == raw.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR then
w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR
w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
else w.active_middle_frame = raw.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR end
--if renoise.app().window.active_middle_frame==renoise.Instrument.TAB_PLUGIN then renoise.app().window.active_middle_frame=5 else
--renoise.app().window.active_middle_frame=renoise.Instrument.TAB_PLUGIN end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F4 Instrument Editor",invoke=function() F4() end}
----------------------------------------------------------------------------------------------------------------
-- F5
function ImpulseTrackerPlaySong()
local s = renoise.song()
local t = s.transport
local startpos = t.playback_pos

if t.playing then t:panic() ResetAllSteppers() else end
  t:panic()
  ResetAllSteppers()
  startpos.sequence = 1
  startpos.line = 1
  t.playback_pos = startpos
local start_time = os.clock()
  while (os.clock() - start_time < 0.225) do
        -- Delay the start after panic. Don't go below 0.2 seconds 
        -- or you might tempt some plugins to crash and take Renoise in the fall!!    
        -- ^^^ I don't know or remember who wrote the above comments but it wasn't me -Esa  
  end
t.follow_player=true
t.edit_mode=false
t.metronome_enabled=false
t.loop_block_enabled=false
t.loop_pattern = false
t:start_at(startpos)

-- Check for Paketti Automation devices and initialize monitoring if they exist
if type(initialize_doofer_monitoring) == "function" then 
  local master_track = renoise.song().tracks[renoise.song().sequencer_track_count + 1]
  local has_paketti_automation = false
  local has_paketti_automation_2 = false
  
  for i = 1, #master_track.devices do
    local device = master_track.devices[i]
    if device.name == "Paketti Automation" then
      has_paketti_automation = true
    elseif device.name == "Paketti Automation 2" then
      has_paketti_automation_2 = true
    end
  end
  
  -- Only initialize if at least one of the Paketti Automation devices exists
  if has_paketti_automation or has_paketti_automation_2 then
    initialize_doofer_monitoring() 
  end
end
end
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F5 Start Playback",invoke=function() ImpulseTrackerPlaySong() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F5 Start Playback (2nd)",invoke=function() ImpulseTrackerPlaySong() end}
----------------------------------------------------------------------------------------------------------------
-- F6, or Impulse Tracker Play Pattern.
function playPattern()

if preferences.PakettiSBxFollowEnabled.value then
  InitSBx()
end

local s = renoise.song()
local t = s.transport
local startpos = t.playback_pos

-- Panic and reset once
t:panic()
ResetAllSteppers()

-- Use current position instead of resetting to sequence 1, line 1
startpos.sequence = s.selected_sequence_index
startpos.line = 1
t.playback_pos = startpos

-- Reduced delay from 225ms to 30ms for faster response
local start_time = os.clock()
while (os.clock() - start_time < 0.03) do
  -- Brief delay after panic for stability
end

-- Don't change follow_player, edit_mode, or metronome_enabled
t.loop_block_enabled=false
t.loop_pattern = true
t:start_at(startpos)

-- Check for Paketti Automation devices and initialize monitoring if they exist
if type(initialize_doofer_monitoring) == "function" then 
  local master_track = s.tracks[s.sequencer_track_count + 1]
  local has_paketti_automation = false
  
  -- Optimized: early exit when both devices found
  for i = 1, #master_track.devices do
    local device_name = master_track.devices[i].name
    if device_name == "Paketti Automation" or device_name == "Paketti Automation 2" then
      has_paketti_automation = true
      break
    end
  end
  
  if has_paketti_automation then
    initialize_doofer_monitoring() 
  end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F6 Start Playback Pattern",invoke=function() playPattern() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F6 Start Playback Pattern (2nd)",invoke=function() playPattern() end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker F6 Start Playback Pattern",invoke=function() playPattern() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker F6 Start Playback Pattern (2nd)",invoke=function() playPattern() end}

renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker F6 Start Playback Pattern",invoke=function() playPattern() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker F6 Start Playback Pattern (2nd)",invoke=function() playPattern() end}
----------------------------------------------------------------------------------------------------------------
-- Position Marker (for CTRL-F7)
-- Global variables to store the marker position (loaded from preferences)
PakettiMarkerLine = 1
PakettiMarkerSequence = 1
PakettiMarkerExists = false

-- Function to load marker from preferences
function PakettiLoadMarkerFromPreferences()
  PakettiMarkerLine = preferences.pakettiMarkerLine.value
  PakettiMarkerSequence = preferences.pakettiMarkerSequence.value
  PakettiMarkerExists = preferences.pakettiMarkerExists.value
end

-- CTRL-F7: Toggle marker on/off (capture at cursor position or turn off)
function PakettiCaptureMarkerPosition()
  local song = renoise.song()
  
  if PakettiMarkerExists then
    -- Marker exists, turn it off
    PakettiMarkerExists = false
    preferences.pakettiMarkerExists.value = false
    renoise.app():show_status("Marker Disabled")
  else
    -- No marker, capture current position
    PakettiMarkerLine = song.selected_line_index
    PakettiMarkerSequence = song.selected_sequence_index
    PakettiMarkerExists = true
    
    -- Save to preferences
    preferences.pakettiMarkerLine.value = PakettiMarkerLine
    preferences.pakettiMarkerSequence.value = PakettiMarkerSequence
    preferences.pakettiMarkerExists.value = PakettiMarkerExists
    
    renoise.app():show_status(
      string.format("Marker Captured: Sequence %d, Line %d", PakettiMarkerSequence, PakettiMarkerLine)
    )
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker Capture Marker Position (CTRL-F7)",invoke=function() PakettiCaptureMarkerPosition() end}

----------------------------------------------------------------------------------------------------------------
-- F7, or Impulse Tracker Play from line.
-- If marker exists (CTRL-F7), play from marker. Otherwise play from cursor.
function ImpulseTrackerPlayFromLine()
local monitoring_enabled = true
  --InitSBx()
  reset_repeat_counts()
  ResetAllSteppers()

 local s = renoise.song()
 local t = s.transport
 
 -- Check if we should use the marker position
 local use_line = s.selected_line_index
 local use_sequence = s.selected_sequence_index
 
 if PakettiMarkerExists then
   -- Validate marker is still valid
   local seq_count = #s.sequencer.pattern_sequence
   if PakettiMarkerSequence >= 1 and PakettiMarkerSequence <= seq_count then
     local pattern_index = s.sequencer.pattern_sequence[PakettiMarkerSequence]
     local pattern = s.patterns[pattern_index]
     local max_lines = (pattern and pattern.number_of_lines) or 1
     -- Clamp line to pattern length
     local clamped_line = math.max(1, math.min(PakettiMarkerLine, max_lines))
     if PakettiMarkerLine >= 1 and PakettiMarkerLine <= max_lines then
       use_line = clamped_line
       use_sequence = PakettiMarkerSequence
       renoise.app():show_status(
         string.format("Playing from Marker: Sequence %d, Line %d", use_sequence, use_line)
       )
     else
       PakettiMarkerExists = false
       preferences.pakettiMarkerExists.value = false
     end
   else
     PakettiMarkerExists = false
     preferences.pakettiMarkerExists.value = false
   end
 end
 
 -- Stop and reset transport settings
 t:panic()
 t.loop_pattern = false
 t.loop_block_enabled = false
 t.edit_mode = true
 
 -- Create SongPos and use start_at for precise positioning
 local pos = renoise.SongPos(use_sequence, use_line)
 
 if t.start_at then
   t:start_at(pos)
 else
   -- Fallback for older Renoise versions
   t.playback_pos = pos
   if renoise.Transport and renoise.Transport.PLAYMODE_CONTINUE_PATTERN then
     t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN)
   else
     t:start()
   end
 end



-- Check for Paketti Automation devices and initialize monitoring if they exist
if type(initialize_doofer_monitoring) == "function" then 
  local master_track = renoise.song().tracks[renoise.song().sequencer_track_count + 1]
  local has_paketti_automation = false
  local has_paketti_automation_2 = false
  
  for i = 1, #master_track.devices do
    local device = master_track.devices[i]
    if device.name == "Paketti Automation" then
      has_paketti_automation = true
    elseif device.name == "Paketti Automation 2" then
      has_paketti_automation_2 = true
    end
  end
  
  -- Only initialize if at least one of the Paketti Automation devices exists
  if has_paketti_automation or has_paketti_automation_2 then
    initialize_doofer_monitoring() 
  end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F7 Start Playback from Cursor Row",invoke=function() ImpulseTrackerPlayFromLine() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F7 Start Playback from Cursor Row (2nd)",invoke=function() ImpulseTrackerPlayFromLine() end}
------------------------------------------------------------------------------------------------------------------------------------------- F8
function ImpulseTrackerStop()
  local t = renoise.song().transport
  local s = renoise.song()

  -- Stop real-time slice marker monitoring timers if active
  local slice_state = rawget(_G, "realtime_slice_state")
  
  if slice_state then
    print("DEBUG F8: slice_state found, is_monitoring:", slice_state.is_monitoring)
    
    -- Stop the timer_func if it exists
    if slice_state.timer_func and renoise.tool():has_timer(slice_state.timer_func) then
      print("DEBUG F8: Removing timer_func")
      renoise.tool():remove_timer(slice_state.timer_func)
      slice_state.timer_func = nil
    end
    
    -- Stop the selection_update_timer if it exists
    if slice_state.selection_update_timer and renoise.tool():has_timer(slice_state.selection_update_timer) then
      print("DEBUG F8: Removing selection_update_timer")
      renoise.tool():remove_timer(slice_state.selection_update_timer)
      slice_state.selection_update_timer = nil
    end
    
    -- Call the full stop function to clean up everything else
    local slice_stop_func = rawget(_G, "pakettiRealtimeSliceStop")
    if slice_state.is_monitoring and slice_stop_func then
      print("DEBUG F8: Calling pakettiRealtimeSliceStop() for full cleanup")
      slice_stop_func()
    end
  else
    print("DEBUG F8: slice_state not found")
  end

  -- If playing, stop playback
  if t.playing then
    t.follow_player = false
    t:panic()
    t.loop_pattern = false
    t.loop_block_enabled = false
    ResetAllSteppers()
    return
  end

  -- If stopped and not on first line, move to first line
  if s.selected_line_index > 1 then
    s.selected_line_index = 1
    return
  end

  -- If on first line but not first pattern, move to first pattern
  if s.selected_sequence_index > 1 then
    s.selected_sequence_index = 1
    s.selected_line_index = 1
    return
  end

  -- If already at first pattern and line, trigger panic
  if s.selected_sequence_index == 1 and s.selected_line_index == 1 then
    t:panic()
    ResetAllSteppers()
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F8 Stop Playback (Panic)",invoke=function() ImpulseTrackerStop() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F8 Stop Playback (Panic) (2nd)",invoke=function() ImpulseTrackerStop() end}

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F8 Stop/Start Playback (Panic)",invoke=function() 
local t = renoise.song().transport
local startpos = t.playback_pos

if t.playing then ImpulseTrackerStop() 
   t.edit_mode=true
   ResetAllSteppers()
else
  startpos.sequence = 1
  startpos.line = 1
  t.playback_pos = startpos
      t.playing=true
   -- ImpulseTrackerPlaySong()
   t.edit_mode=false end
 if type(PakettiPatternEditorApplyF8FollowPreference) == "function" then PakettiPatternEditorApplyF8FollowPreference() end
end}
----------------------------------------------------------------------------------------------------------------
-- Start/Stop Playback Toggle (DRY)
function PakettiStartStopPlayback(playmode)
local t = renoise.song().transport

if t.playing then
  -- Stop playback
  t:stop()
else
  -- Start playback with specified playmode
  t:start(playmode)
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Start/Stop Playback (Continue)",invoke=function() PakettiStartStopPlayback(renoise.Transport.PLAYMODE_CONTINUE_PATTERN) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Start/Stop Playback (Continue)",invoke=function() PakettiStartStopPlayback(renoise.Transport.PLAYMODE_CONTINUE_PATTERN) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Start/Stop Playback (Continue)",invoke=function() PakettiStartStopPlayback(renoise.Transport.PLAYMODE_CONTINUE_PATTERN) end}

renoise.tool():add_keybinding{name="Global:Paketti:Start/Stop Playback (First Row)",invoke=function() PakettiStartStopPlayback(renoise.Transport.PLAYMODE_RESTART_PATTERN) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Start/Stop Playback (First Row)",invoke=function() PakettiStartStopPlayback(renoise.Transport.PLAYMODE_RESTART_PATTERN) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Start/Stop Playback (First Row)",invoke=function() PakettiStartStopPlayback(renoise.Transport.PLAYMODE_RESTART_PATTERN) end}
----------------------------------------------------------------------------------------------------------------
-- F11, or "Impulse Tracker Shortcut F11 display-change", "Order List",
-- Hides Pattern Matrix, Hides Advanced Edit.
-- Changes to Mixer, Track Scopes, Track DSPs.
-- Second press makes Pattern Matrix visible and changes to Automation.
-- Sample Recorder will stay open, if Sample Recorder is already open.
function F11() 
local  w=renoise.app().window
local raw=renoise.ApplicationWindow
if w.upper_frame_is_visible==true and w.pattern_matrix_is_visible==false and w.active_middle_frame==2 and w.active_lower_frame==1 then
w.pattern_matrix_is_visible=true
w.active_lower_frame=raw.LOWER_FRAME_TRACK_AUTOMATION
else w.pattern_matrix_is_visible=false
w.active_lower_frame=raw.LOWER_FRAME_TRACK_DSPS
end

--    if preferences and preferences.upperFramePreference and preferences.upperFramePreference ~= 0 then 
--        w.active_upper_frame = preferences.upperFramePreference
--    end
    
--w.active_upper_frame=raw.UPPER_FRAME_TRACK_SCOPES
w.active_middle_frame=raw.MIDDLE_FRAME_MIXER
w.lower_frame_is_visible=true
w.upper_frame_is_visible=true
w.lock_keyboard_focus=true
w.pattern_advanced_edit_is_visible=false
--w.instrument_box_is_visible=false
--w.disk_browser_is_visible=false
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F11 Order List",invoke=function() F11() end}
----------------------------------------------------------------------------------------------------------------
-- F12, or "Not really IT F11, not really IT F12 either".
-- Hides Pattern Matrix, Hides Advanced Edit.
-- Changes to Mixer, Track DSPs, Master Spectrum.
-- Changes to Master track.
-- Second press switches to Song Settings.
-- Sample Recorder will stay open, if Sample Recorder is already open.
function F12()
  local w = renoise.app().window
  local s = renoise.song()
  local raw = renoise.ApplicationWindow

  w.pattern_matrix_is_visible = false
  
  if renoise.app().window.active_middle_frame==8 or renoise.app().window.active_middle_frame==9 or renoise.app().window.active_middle_frame == 5 or renoise.app().window.active_middle_frame == 7 or renoise.app().window.active_middle_frame == 1 then
      s.selected_track_index = s.sequencer_track_count + 1
    w.active_middle_frame = raw.MIDDLE_FRAME_MIXER
    w.active_lower_frame = raw.LOWER_FRAME_TRACK_DSPS
  w.upper_frame_is_visible = true

  return else end
  -- Check if the Mixer is not visible and Track Automation is displaying
  if w.active_middle_frame ~= raw.MIDDLE_FRAME_MIXER and w.active_lower_frame == raw.LOWER_FRAME_TRACK_AUTOMATION then
    s.selected_track_index = s.sequencer_track_count + 1
    w.active_middle_frame = raw.MIDDLE_FRAME_MIXER
    w.active_lower_frame = raw.LOWER_FRAME_TRACK_DSPS
    return
  end

  w.lower_frame_is_visible = true
  w.upper_frame_is_visible = true

  -- Ensure the Master track is selected
  if s.selected_track_index ~= s.sequencer_track_count + 1 then
    s.selected_track_index = s.sequencer_track_count + 1
    w.active_lower_frame = raw.LOWER_FRAME_TRACK_DSPS
    return
  end

  -- Cycle through Track DSPs and Track Automation when the Master track is selected
  if w.active_lower_frame == raw.LOWER_FRAME_TRACK_DSPS and s.selected_track_index == s.sequencer_track_count + 1 then
    w.active_lower_frame = raw.LOWER_FRAME_TRACK_AUTOMATION
    return
  end

  -- Default case: set the lower frame to Track DSPs and upper frame to Track Scopes
  w.active_lower_frame = raw.LOWER_FRAME_TRACK_DSPS
  w.active_upper_frame = raw.UPPER_FRAME_TRACK_SCOPES
  w.lock_keyboard_focus = true
  w.pattern_advanced_edit_is_visible = false
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F12 Master",invoke=function() F12() end}
----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Impulse Tracker Next / Previous Pattern (Keyboard + Midi)
function ImpulseTrackerNextPattern()
local s=renoise.song()
if s.transport.follow_player==false then s.transport.follow_player=true end
  if s.transport.playing==false then 
   if s.selected_sequence_index==(table.count(s.sequencer.pattern_sequence)) then return 
  else
  s.selected_sequence_index=s.selected_sequence_index+1 end

  else if s.selected_sequence_index==(table.count(s.sequencer.pattern_sequence)) then
s.transport:trigger_sequence(1) else s.transport:trigger_sequence(s.selected_sequence_index+1) end
  end
end

function ImpulseTrackerPrevPattern()
local s=renoise.song()
local t=s.transport
if t.follow_player==false then t.follow_player=true end
    if t.playing==false then 
    if s.selected_sequence_index==1 then return 
    else s.selected_sequence_index=s.selected_sequence_index-1 end
else
  if s.selected_sequence_index==1 then t:trigger_sequence(s.selected_sequence_index) else
t:trigger_sequence(s.selected_sequence_index-1) end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker Pattern (Next)",invoke=function() ImpulseTrackerNextPattern() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker Pattern (Previous)",invoke=function() ImpulseTrackerPrevPattern() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker Pattern (Next) 2nd",invoke=function() ImpulseTrackerNextPattern() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker Pattern (Previous) 2nd",invoke=function() ImpulseTrackerPrevPattern() end}
----------------------------------------------------------------------------------------------------------------------------------------------------------------
--IT: ALT-D (whole track) Double-select
function DoubleSelect()
  local s = renoise.song()
  local win = renoise.app().window
  local middle_frame = win.active_middle_frame

 ------------------------------------------------------------------------------
  -- PHRASE EDITOR branch
  ------------------------------------------------------------------------------
  if middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    if renoise.API_VERSION >= 6.2 then
      local phrase = s.selected_phrase
      if not phrase then
        renoise.app():show_error("No phrase is selected!")
        return
      end

      local lpb = s.transport.lpb
      local sip = s.selection_in_phrase  -- may be nil
      local start_line = renoise.song().selected_phrase_line_index
      local total_columns = phrase.visible_note_columns + phrase.visible_effect_columns

      -- Ensure there's at least one column
      if total_columns < 1 then
        total_columns = 1
        phrase.visible_note_columns = 1
      end

      -- Helper function to visualize selection
      local function selection_to_string(sel)
        return sel and string.format("start_line=%d, end_line=%d, start_col=%d, end_col=%d",
          sel.start_line, sel.end_line, sel.start_column, sel.end_column) or "nil"
      end

      if not sip or (sip.start_line ~= start_line) or (sip.end_line == start_line) then
        print("Creating NEW selection because:")
        print("No selection: ", not sip)
        print("Start line mismatch: ", sip and (sip.start_line ~= start_line) or false)
        print("Single line selection: ", sip and (sip.end_line == start_line) or false)

        -- Calculate new end_line
        local new_end_line = start_line + lpb - 1
        if new_end_line > phrase.number_of_lines then
          new_end_line = phrase.number_of_lines
        end

        -- Prepare the new selection
        local new_selection = {
          start_line   = renoise.song().selected_phrase_line_index,
          end_line     = new_end_line,
          start_column = 1,
          end_column   = total_columns,
        }

        -- Assign the new selection and print the assigned values
        renoise.song().selection_in_phrase = new_selection
        print("Assigned selection_in_phrase:")
        print(selection_to_string(s.selection_in_phrase))

        -- Verify the assignment
        if s.selection_in_phrase and
           s.selection_in_phrase.start_line == new_selection.start_line and
           s.selection_in_phrase.end_line == new_selection.end_line and
           s.selection_in_phrase.start_column == new_selection.start_column and
           s.selection_in_phrase.end_column == new_selection.end_column then
          print("Verification succeeded: selection_in_phrase matches the assigned values.")
        else
          print("Verification failed: selection_in_phrase does not match the assigned values!")
          print("Expected: ", selection_to_string(new_selection))
          print("Actual: ", selection_to_string(s.selection_in_phrase))
        end

      else
        print("Expanding EXISTING selection: ", selection_to_string(sip))

        -- Calculate new end_line to expand selection
        local current_length = sip.end_line - sip.start_line + 1
        local new_end_line = sip.start_line + (current_length * 2) - 1

        if new_end_line > phrase.number_of_lines then
          new_end_line = phrase.number_of_lines
          print("Clamping new_end_line to phrase length")
        end

        -- Prepare the expanded selection
        local new_selection = {
          start_line   = sip.start_line,
          end_line     = new_end_line,
          start_column = 1,
          end_column   = total_columns,
        }

        -- Assign the expanded selection and print the assigned values
        s.selection_in_phrase = new_selection
        print("Expanded selection_in_phrase:")
        print(selection_to_string(s.selection_in_phrase))

        -- Verify the assignment
        if s.selection_in_phrase and
           s.selection_in_phrase.start_line == new_selection.start_line and
           s.selection_in_phrase.end_line == new_selection.end_line and
           s.selection_in_phrase.start_column == new_selection.start_column and
           s.selection_in_phrase.end_column == new_selection.end_column then
          print("Verification succeeded: selection_in_phrase matches the assigned values.")
        else
          print("Verification failed: selection_in_phrase does not match the assigned values!")
          print("Expected: ", selection_to_string(new_selection))
          print("Actual: ", selection_to_string(s.selection_in_phrase))
        end
      end

    else
      renoise.app():show_error("Phrase Editor functionality requires API version 6.2 or higher!")
      return
    end


  ------------------------------------------------------------------------------
  -- PATTERN EDITOR branch
  ------------------------------------------------------------------------------
  elseif middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    local lpb = s.transport.lpb
    local sip = s.selection_in_pattern
    local last_column = s.selected_track.visible_effect_columns +
                        s.selected_track.visible_note_columns
    local protect_row = s.selected_line_index + lpb - 1
    if protect_row > s.selected_pattern.number_of_lines then
      protect_row = s.selected_pattern.number_of_lines
    end

    if (not sip)
       or (sip.start_track ~= s.selected_track_index)
       or (s.selected_line_index ~= sip.start_line) then
      s.selection_in_pattern = {
        start_line   = s.selected_line_index,
        end_line     = protect_row,
        start_track  = s.selected_track_index,
        end_track    = s.selected_track_index,
        start_column = 1,
        end_column   = last_column,
      }
    else
      local new_end_line = (sip.end_line - sip.start_line) * 2 + (sip.start_line + 1)
      if new_end_line > s.selected_pattern.number_of_lines then
        new_end_line = s.selected_pattern.number_of_lines
      end
      s.selection_in_pattern = {
        start_line   = sip.start_line,
        end_line     = new_end_line,
        start_track  = s.selected_track_index,
        end_track    = s.selected_track_index,
        start_column = 1,
        end_column   = last_column,
      }
    end

  else
    renoise.app():show_error("Active middle frame not recognized for DoubleSelect!")
  end
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select",invoke=DoubleSelect}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-D Double Select",invoke=DoubleSelect}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker ALT-D Double Select",invoke=DoubleSelect}

-----------
-- Function to select the pattern range in automation
function selectPatternRangeInAutomation()
  local song=renoise.song()

  -- Check if the automation lower frame is displayed
  if not (renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION) then
    renoise.app():show_status("Automation lower frame is not displayed.")
    return
  end

  local selected_pattern_index = song.selected_pattern_index
  local selected_track_index = song.selected_track_index

  -- Check if an automatable parameter is selected
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  -- Get the selection in the pattern editor
  local pattern_selection = song.selection_in_pattern
  if pattern_selection == nil then
    renoise.app():show_status("No selection in Pattern Editor.")
    return
  end

  local start_line = pattern_selection.start_line
  local end_line = pattern_selection.end_line

  -- Access the track's automation for the selected parameter
  local track_automation = song:pattern(selected_pattern_index):track(selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)

  -- If no automation envelope exists, create one
  if not envelope then
    envelope = track_automation:create_automation(automation_parameter)
  end

  -- Calculate automation selection range based on pattern selection
  local pattern_lines = song:pattern(selected_pattern_index).number_of_lines
  local automation_start = math.floor((start_line / pattern_lines) * envelope.length)
  local automation_end = math.floor(((end_line + 1) / pattern_lines) * envelope.length)

  -- Set the selection range in the automation envelope
  envelope.selection_range = { automation_start, automation_end}

  -- Notify the user
  renoise.app():show_status("Automation selection set from line " .. start_line .. " to line " .. end_line)
end

-- IT: ALT-D (whole track) Double-select
function DoubleSelectAutomation()
  local s = renoise.song()
  local lpb = s.transport.lpb
  local sip = s.selection_in_pattern
  local last_column = s.selected_track.visible_effect_columns + s.selected_track.visible_note_columns
  local protectrow = lpb + s.selected_line_index - 1
  if protectrow > s.selected_pattern.number_of_lines then
    protectrow = s.selected_pattern.number_of_lines
  end

  if sip == nil or sip.start_track ~= s.selected_track_index or s.selected_line_index ~= s.selection_in_pattern.start_line then
    s.selection_in_pattern = {
      start_line = s.selected_line_index,
      end_line = protectrow,
      start_track = s.selected_track_index,
      end_track = s.selected_track_index,
      start_column = 1,
      end_column = last_column
    }
  else
    local endline = sip.end_line
    local startline = sip.start_line
    local new_endline = (endline - startline) * 2 + (startline + 1)

    if new_endline > s.selected_pattern.number_of_lines then
      new_endline = s.selected_pattern.number_of_lines
    end

    s.selection_in_pattern = {
      start_line = startline,
      end_line = new_endline,
      start_track = s.selected_track_index,
      end_track = s.selected_track_index,
      start_column = 1,
      end_column = last_column
    }
  end

  -- After updating the pattern selection, update the automation selection
  selectPatternRangeInAutomation()
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select W/ Automation",invoke=function() DoubleSelectAutomation() end}
renoise.tool():add_keybinding{name="Automation:Paketti:Impulse Tracker ALT-D Double Select W/ Automation",invoke=function() DoubleSelectAutomation() end}







--------------------------------------------------------------------------------------------------------------------------------
-- Protman's set octave with or without EditStep
-- Protman: Thanks to suva for the function per octave declaration loop :)
-- http://www.protman.com
function Octave(new_octave, use_editstep)
  local new_pos = 0
  local s = renoise.song()
  local editstep = s.transport.edit_step

  new_pos = s.transport.edit_pos
  if ((s.selected_note_column ~= nil) and (s.selected_note_column.note_value < 120)) then
    s.selected_note_column.note_value = s.selected_note_column.note_value  % 12 + (12 * new_octave)
  end
  
  if use_editstep then
    new_pos.line = new_pos.line + editstep
    if new_pos.line <= s.selected_pattern.number_of_lines then
       s.transport.edit_pos = new_pos
    end
  end
end

-- Create keybindings for both with and without EditStep
for oct=0,9 do
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Note to Octave " .. oct .. " with EditStep",
    invoke=function() Octave(oct, true) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Note to Octave " .. oct .. " without EditStep",
    invoke=function() Octave(oct, false) end}
end
-------------------------------------------------------------------------------------------------------------------------------------
------Protman PageUp PageDn
--PageUp / PageDown ImpulseTracker behaviour (reads according to LPB, and disables
--Pattern Follow to "eject" you out of playback back to editing step-by-step)
function Jump(Dir)
  local new_pos = 0
  local s=renoise.song()
  local lpb = s.transport.lpb
  local pat_lines = s.selected_pattern.number_of_lines
    new_pos = s.transport.edit_pos
    new_pos.line = new_pos.line + lpb * 2 * Dir
    if (new_pos.line < 1) then
    s.transport.follow_player = false
      new_pos.line = 1
      else if (new_pos.line > pat_lines) then
    s.transport.follow_player = false
        new_pos.line = pat_lines
      end
    end
    if ((Dir == -1) and (new_pos.line == pat_lines - ((lpb * 2)))) then
      new_pos.line = (pat_lines - (lpb*2) + 1)
    s.transport.follow_player = false
    end
    s.transport.edit_pos = new_pos
    s.transport.follow_player = false
end  

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker PageUp Jump Lines",invoke=function() Jump(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker PageDown Jump Lines",invoke=function() Jump(1) end}
--------------------------------------------------------------------------------------------------
---------Protman's Expand Selection
function cpclex_line(track, from_line, to_line)
  local s=renoise.song()
  local cur_track = s:pattern(s.selected_pattern_index):track(track)
  cur_track:line(to_line):copy_from(cur_track:line(from_line))
  cur_track:line(from_line):clear()
  cur_track:line(to_line+1):clear()
end

function ExpandSelection()
  local s = renoise.song()
  if s.selection_in_pattern == nil then
  renoise.app():show_status("Nothing selected to Expand, doing nothing.")
  return
  else  
  local sl = s.selection_in_pattern.start_line
  local el = s.selection_in_pattern.end_line
  local st = s.selection_in_pattern.start_track
  local et = s.selection_in_pattern.end_track
  local nl = s.selected_pattern.number_of_lines
  local tr
  
  for tr=st,et do
    for l =el,sl,-1 do
      if l ~= sl and l*2-sl <= nl
        then
        cpclex_line(tr,l,l*2-sl)
      end
    end
  end
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-F Expand Selection",invoke=function() ExpandSelection() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-F Expand Selection Twice",invoke=function() ExpandSelection() ExpandSelection() end}
-----------------------------------------------------------------------------------------------
-------Protman's Shrink Selection
function cpclsh_line(track, from_line, to_line)
  local cur_track = renoise.song():pattern(renoise.song().selected_pattern_index):track(track)
  cur_track:line(to_line):copy_from(cur_track:line(from_line))
  cur_track:line(from_line):clear()
  cur_track:line(from_line+1):clear()
end

function ShrinkSelection()
  local s = renoise.song()
  if s.selection_in_pattern == nil then
  renoise.app():show_status("Nothing selected to Shrink, doing nothing.")
  return
  else
  local sl = s.selection_in_pattern.start_line
  local el = s.selection_in_pattern.end_line
  local st = s.selection_in_pattern.start_track
  local et = s.selection_in_pattern.end_track
  local tr
  
  for tr=st,et do
    for l =sl,el,2 do
      if l ~= sl
        then
        cpclsh_line(tr,l,l/2+sl/2)
      end
    end
  end
end
end
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-G Shrink Selection",invoke=function() ShrinkSelection() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Twice",invoke=function() ShrinkSelection() ShrinkSelection() end}

-- Phrase Editor versions (API 6.2+)
if renoise.API_VERSION >= 6.2 then
  -- Helper function for phrase line operations
  function cpclex_phrase_line(from_line, to_line)
    local s = renoise.song()
    local phrase = s.selected_phrase
    if not phrase then
      renoise.app():show_status("No phrase selected.")
      return
    end
    phrase:line(to_line):copy_from(phrase:line(from_line))
    phrase:line(from_line):clear()
    if to_line + 1 <= phrase.number_of_lines then
      phrase:line(to_line + 1):clear()
    end
  end

  function cpclsh_phrase_line(from_line, to_line)
    local s = renoise.song()
    local phrase = s.selected_phrase
    if not phrase then
      renoise.app():show_status("No phrase selected.")
      return
    end
    phrase:line(to_line):copy_from(phrase:line(from_line))
    phrase:line(from_line):clear()
    if from_line + 1 <= phrase.number_of_lines then
      phrase:line(from_line + 1):clear()
    end
  end

  function ExpandSelectionPhrase()
    local s = renoise.song()
    local phrase = s.selected_phrase
    if not phrase then
      renoise.app():show_status("No phrase selected.")
      return
    end
    
    if s.selection_in_phrase == nil then
      renoise.app():show_status("Nothing selected to Expand in phrase, doing nothing.")
      return
    else  
      local sl = s.selection_in_phrase.start_line
      local el = s.selection_in_phrase.end_line
      local nl = phrase.number_of_lines
      
      for l = el, sl, -1 do
        if l ~= sl and l * 2 - sl <= nl then
          cpclex_phrase_line(l, l * 2 - sl)
        end
      end
    end
  end

  function ShrinkSelectionPhrase()
    local s = renoise.song()
    local phrase = s.selected_phrase
    if not phrase then
      renoise.app():show_status("No phrase selected.")
      return
    end
    
    if s.selection_in_phrase == nil then
      renoise.app():show_status("Nothing selected to Shrink in phrase, doing nothing.")
      return
    else
      local sl = s.selection_in_phrase.start_line
      local el = s.selection_in_phrase.end_line
      
      for l = sl, el, 2 do
        if l ~= sl then
          cpclsh_phrase_line(l, l / 2 + sl / 2)
        end
      end
    end
  end

  -- Keybindings for Phrase Editor
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-F Expand Selection",invoke=function() ExpandSelectionPhrase() end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-F Expand Selection Twice",invoke=function() ExpandSelectionPhrase() ExpandSelectionPhrase() end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-G Shrink Selection",invoke=function() ShrinkSelectionPhrase() end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Twice",invoke=function() ShrinkSelectionPhrase() ShrinkSelectionPhrase() end}
end
--------------------------------------------------------
-- Renamed helper function to cpclexrep_line
function cpclexrep_line(track, from_line, to_line)
  local s = renoise.song()
  local cur_pattern = s:pattern(s.selected_pattern_index)
  local cur_track = cur_pattern:track(track)
  
  -- Copy from from_line to to_line
  cur_track:line(to_line):copy_from(cur_track:line(from_line))
  
  -- Clear from_line
  cur_track:line(from_line):clear()
  
  -- Clear to_line + 1 only if it's within the valid range
  if to_line + 1 <= s.selected_pattern.number_of_lines then
    cur_track:line(to_line + 1):clear()
  end
end

function ExpandSelectionReplicate(track_number)
  local s = renoise.song()
  local original_track = s.selected_track_index
  
  -- If track_number is provided, switch to that track
  if track_number then
    if track_number <= #s.tracks and s.tracks[track_number].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track_index = track_number
      Deselect_All()
      MarkTrackMarkPattern()
    else
      renoise.app():show_status("Track " .. track_number .. " is not a valid sequencer track")
      return
    end
  end
  
  local currentLine = s.selected_line_index
  
  if s.selection_in_pattern == nil then
    renoise.app():show_status("Nothing selected to Expand, doing nothing.")
    return
  end
  
  local sl = s.selection_in_pattern.start_line
  local el = s.selection_in_pattern.end_line
  local st = s.selection_in_pattern.start_track
  local et = s.selection_in_pattern.end_track
  local nl = s.selected_pattern.number_of_lines
  
  -- Calculate the original and new selection lengths
  local original_length = el - sl + 1
  local new_end_line = el * 2
  if new_end_line > nl then
    new_end_line = nl
  end


  
  -- First pass: Expand the selection
  for tr = st, et do
    for l = el, sl, -1 do
      if l ~= sl then
        local new_line = (l * 2) - sl
        if new_line <= nl then
          cpclexrep_line(tr, l, new_line)
        end
      end
    end
  end
  
  -- Update selection to include expanded area
  local expanded_length = new_end_line - sl + 1
  s.selection_in_pattern = {start_line=sl, start_track=st, end_track=et, end_line = new_end_line}
floodfill_with_selection()
  
  -- Restore original track if track_number was provided
  if track_number and original_track <= #s.tracks then
    s.selected_track_index = original_track
    renoise.app():show_status(string.format("Expanded and replicated selection on track %d", track_number))
  else
    renoise.app():show_status(string.format("Expanded and replicated selection from line %d to %d", sl, nl))
  end
  
  -- Sync with groovebox if it's open
  if dialog and dialog.visible then
    fetch_pattern()
  end
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-F Expand Selection Replicate",invoke=function() ExpandSelectionReplicate() end}
-----------------------------------------------------------------------------------------------
-------Protman's Shrink Selection
-- Renamed helper function to cpclshrep_line
function cpclshrep_line(track, from_line, to_line)
  local s = renoise.song()
  local cur_pattern = s:pattern(s.selected_pattern_index)
  local cur_track = cur_pattern:track(track)
  
  -- Copy from from_line to to_line
  cur_track:line(to_line):copy_from(cur_track:line(from_line))
  
  -- Clear from_line
  cur_track:line(from_line):clear()
  
  -- Clear from_line + 1 only if it's within the valid range
  if from_line + 1 <= s.selected_pattern.number_of_lines then
    cur_track:line(from_line + 1):clear()
  end
end

function ShrinkSelectionReplicate(track_number)
  local s = renoise.song()
  local original_track = s.selected_track_index
  
  -- If track_number is provided, switch to that track
  if track_number then
    if track_number <= #s.tracks and s.tracks[track_number].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track_index = track_number
      Deselect_All()
      MarkTrackMarkPattern()
    else
      renoise.app():show_status("Track " .. track_number .. " is not a valid sequencer track")
      return
    end
  end
  
  local currentLine = s.selected_line_index
  
  if s.selection_in_pattern == nil then
    renoise.app():show_status("Nothing selected to Shrink, doing nothing.")
    return
  else
    local sl = s.selection_in_pattern.start_line
    local el = s.selection_in_pattern.end_line
    local st = s.selection_in_pattern.start_track
    local et = s.selection_in_pattern.end_track
    local nl = s.selected_pattern.number_of_lines
    
    -- Remove the problematic line index setting
    -- renoise.song().selected_line_index = el + 1  -- This was causing the error
    -- renoise.song().selected_line_index = currentLine
    
    for tr = st, et do
      for l = sl, el, 2 do
        if l ~= sl then
          -- Calculate new_line as an integer
          local new_line = math.floor(l / 2 + sl / 2)
          
          -- Ensure new_line is within valid range
          if new_line >= 1 and new_line <= nl then
            cpclshrep_line(tr, l, new_line)
          end
        end
      end
    end

    -- Update selection to include shrunken area and trigger replication
    local new_end_line = math.min(math.floor((el - sl) / 2) + sl, nl)
    s.selection_in_pattern = {start_line=sl, start_track=st, end_track=et, end_line=new_end_line}
    floodfill_with_selection()
    
    -- Restore original track if track_number was provided
    if track_number and original_track <= #s.tracks then
      s.selected_track_index = original_track
      renoise.app():show_status(string.format("Shrank and replicated selection on track %d", track_number))
    else
      renoise.app():show_status(string.format("Shrank and replicated selection from line %d to %d", sl, nl))
    end
    
    -- Sync with groovebox if it's open
    if dialog and dialog.visible then
      fetch_pattern()
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Replicate",invoke=function() ShrinkSelectionReplicate() end}
--------------------------------------------------------
--Protman's Set Instrument
function SetInstrument()
local s=renoise.song()
local EMPTY_INSTRUMENT = renoise.PatternTrackLine.EMPTY_INSTRUMENT
local pattern_iter = s.pattern_iterator
local pattern_index = s.selected_pattern_index
for _,line in pattern_iter:lines_in_pattern(pattern_index) do
  -- will be nil when a send or the master track is iterated
for i=0,s.tracks[s.selected_track_index].visible_note_columns do

 local first_note_column = line.note_columns[i]
  if (first_note_column and 
      first_note_column.instrument_value ~= EMPTY_INSTRUMENT and 
      first_note_column.is_selected) 
  then
    first_note_column.instrument_value = s.selected_instrument_index - 1 end
end  
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-S Set Selection to Instrument",invoke=function() SetInstrument() end} 
----------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
function MarkTrackMarkPattern()
--Known bug: Has no idea as to what to do with Groups.
local st=nil
local et=nil
local sl=nil
local el=nil
local s=renoise.song()
local sip=s.selection_in_pattern
local sp=s.selected_pattern
if sip ~= nil then 
  st = sip.start_track
  et = sip.end_track
  sl = sip.start_line
  el = sip.end_line
  local totalTrackCount=s.sequencer_track_count + 1 + s.send_track_count
  if st == et and st == s.selected_track_index then
    if sl == 1 and el == sp.number_of_lines then
      s.selection_in_pattern = {
        start_track = 1,
        end_track = totalTrackCount,
          start_line=1,
        end_line=sp.number_of_lines
      }
    else
        s.selection_in_pattern = {
        start_track = st,
          end_track = et,
          start_line = 1, 
       end_line = sp.number_of_lines}
    end
  else
      s.selection_in_pattern = {
      start_track = s.selected_track_index,
        end_track = s.selected_track_index,
        start_line = 1, 
        end_line = sp.number_of_lines}  end
else
  s.selection_in_pattern ={
      start_track = s.selected_track_index,
        end_track = s.selected_track_index,
        start_line = 1, 
        end_line = sp.number_of_lines} end

  selectPatternRangeInAutomation()

end

renoise.tool():add_keybinding{name="Pattern Editor:Selection:Impulse Tracker ALT-L Mark Track/Mark Pattern",invoke=function() MarkTrackMarkPattern() end}  

-- ALT-B: Extend Selection from End to Cursor
function PakettiImpulseTrackerModifySelectionStart()
  local s = renoise.song()
  local sip = s.selection_in_pattern
  local current_track = s.selected_track_index
  local current_line = s.selected_line_index
  local current_track_obj = s.tracks[current_track]
  
  -- Calculate column range for current track
  local last_column = current_track_obj.visible_effect_columns + current_track_obj.visible_note_columns
  
  -- If no selection exists, create one for just the current row
  if not sip then
    s.selection_in_pattern = {
      start_track = current_track,
      end_track = current_track,
      start_line = current_line,
      end_line = current_line,
      start_column = 1,
      end_column = last_column
    }
    return
  end
  
  -- Get existing selection bounds
  local st = sip.start_track
  local et = sip.end_track
  local sl = sip.start_line
  local el = sip.end_line
  local sc = sip.start_column
  local ec = sip.end_column
  
  -- Debug: Show original state
  print(string.format("ALT-B DEBUG: Cursor at track %d line %d", current_track, current_line))
  print(string.format("ALT-B DEBUG: Original selection - tracks %d-%d, lines %d-%d", st, et, sl, el))
  
  -- Strategy: Draw from END of current selection to new cursor position
  -- The new start is the old end position
  -- The new end is the current cursor position
  local new_st = et
  local new_et = current_track
  local new_sl = el
  local new_el = current_line
  local new_sc = sc
  local new_ec = ec
  
  print(string.format("ALT-B DEBUG: Before flip - new_st=%d new_et=%d new_sl=%d new_el=%d", new_st, new_et, new_sl, new_el))
  
  -- Normalize the selection: Renoise requires start_track <= end_track
  if new_st > new_et then
    new_st, new_et = new_et, new_st
  end
  
  -- Normalize lines: Renoise requires start_line <= end_line
  if new_sl > new_el then
    new_sl, new_el = new_el, new_sl
  end
  
  -- Debug output
  print(string.format("ALT-B: Setting selection - tracks %d-%d, lines %d-%d", new_st, new_et, new_sl, new_el))
  
  -- Validate before applying
  if new_st > new_et then
    renoise.app():show_status("ERROR: start_track > end_track!")
    return
  end
  if new_sl > new_el then
    renoise.app():show_status("ERROR: start_line > end_line!")
    return
  end
  
  -- Apply the new selection
  s.selection_in_pattern = {
    start_track = new_st,
    end_track = new_et,
    start_line = new_sl,
    end_line = new_el,
    start_column = new_sc,
    end_column = new_ec
  }
  
  -- Update automation selection if applicable
  selectPatternRangeInAutomation()
end

renoise.tool():add_keybinding{name="Pattern Editor:Selection:Impulse Tracker ALT-B Modify Selection Start (Keep End)",invoke=function() PakettiImpulseTrackerModifySelectionStart() end}

-- Shift-ALT-L: Mark Note Column/Mark Pattern (select only current note column content)
function MarkNoteColumnMarkPattern()
  local s = renoise.song()
  local sp = s.selected_pattern
  local current_track = s.selected_track_index
  local current_note_column = s.selected_note_column_index
  local current_effect_column = s.selected_effect_column_index
  
  -- Determine which column to select
  local column_index = nil
  
  if current_note_column > 0 then
    -- We're in a note column
    column_index = current_note_column
  elseif current_effect_column > 0 then
    -- We're in an effect column - calculate the column index
    local visible_note_columns = s.tracks[current_track].visible_note_columns
    column_index = visible_note_columns + current_effect_column
  else
    -- No column selected, default to first column
    column_index = 1
  end
  
  -- Create selection for the specific column only
  s.selection_in_pattern = {
    start_track = current_track,
    end_track = current_track,
    start_line = 1,
    end_line = sp.number_of_lines,
    start_column = column_index,
    end_column = column_index
  }
  
  -- Also update automation selection if available
  selectPatternRangeInAutomation()
end

renoise.tool():add_keybinding{name="Pattern Editor:Selection:Impulse Tracker SHIFT-ALT-L Mark Note Column/Mark Pattern",invoke=function() MarkNoteColumnMarkPattern() end}

-- ALT-L for Phrase Editor: Mark Note Column/Mark Phrase
function PakettiPhraseEditorMarkNoteColumnMarkPhrase()
  local s = renoise.song()
  local phrase = s.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local current_note_column = s.selected_phrase_note_column_index
  local current_effect_column = s.selected_phrase_effect_column_index
  
  -- Determine which column to select
  local column_index = nil
  
  if current_note_column > 0 then
    -- We're in a note column
    column_index = current_note_column
  elseif current_effect_column > 0 then
    -- We're in an effect column - need to offset by number of note columns
    column_index = phrase.visible_note_columns + current_effect_column
  else
    renoise.app():show_status("No column selected")
    return
  end
  
  local sip = s.selection_in_phrase
  
  if sip ~= nil then
    -- If there's already a selection for the current column spanning the entire phrase,
    -- then select all columns
    if sip.start_column == column_index and sip.end_column == column_index and
       sip.start_line == 1 and sip.end_line == phrase.number_of_lines then
      -- Select all columns in the phrase
      local total_columns = phrase.visible_note_columns + phrase.visible_effect_columns
      s.selection_in_phrase = {
        start_line = 1,
        end_line = phrase.number_of_lines,
        start_column = 1,
        end_column = total_columns
      }
      renoise.app():show_status("Selected entire phrase")
      return
    end
  end
  
  -- Otherwise, select just the current column for the entire phrase
  s.selection_in_phrase = {
    start_line = 1,
    end_line = phrase.number_of_lines,
    start_column = column_index,
    end_column = column_index
  }
  
  renoise.app():show_status(string.format("Selected column %d for entire phrase", column_index))
end

if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-L Mark Note Column/Mark Phrase",invoke=function() PakettiPhraseEditorMarkNoteColumnMarkPhrase() end}
end

------------------------------------------------------
----------Protman's Alt-D except patternwide
function DoubleSelectPattern()
 local s = renoise.song()
 local lpb = s.transport.lpb
 local sip = s.selection_in_pattern
-- local last_column = s.selected_track.visible_effect_columns + s.selected_track.visible_note_columns
 local last_column = s.selected_track.visible_note_columns

 if sip == nil or sip.start_track ~= s.selected_track_index or s.selected_line_index ~= s.selection_in_pattern.start_line then 
 
  s.selection_in_pattern = { 
    start_line = s.selected_line_index, 
      end_line = lpb + s.selected_line_index - 1,
   start_track = 1, 
     end_track = renoise.song().sequencer_track_count+1, 
  start_column = 1, 
    end_column = last_column }
 else 
  local endline = sip.end_line
  local startline = sip.start_line
  local new_endline = (endline - startline) * 2 + (startline + 1)

  if new_endline > s.selected_pattern.number_of_lines then
   new_endline = s.selected_pattern.number_of_lines
  end

print ("new_endline " .. new_endline)
  s.selection_in_pattern = { 
    start_line = startline, 
      end_line = new_endline, 
   start_track = 1, 
     end_track = renoise.song().sequencer_track_count+1, 
  start_column = 1, 
    end_column = last_column }
 end
end
--------------------------------------------------------------------------------------------------------------------------------------IT: Alt-D except Current Column only
--[[
function DoubleSelectColumnOnly()
 local s = renoise.song()
 local lpb = s.transport.lpb
 local sip = s.selection_in_pattern
 local last_column = s.selected_track.visible_effect_columns + s.selected_track.visible_note_columns
 local currTrak=s.selected_track_index
 local selection=nil
 
 if s.selected_note_column_index==0 then selection=renoise.song().tracks[currTrak].visible_note_columns+s.selected_effect_column_index
 else selection=s.selected_note_column_index
end 
 if sip == nil or sip.start_track ~= s.selected_track_index or s.selected_line_index ~= s.selection_in_pattern.start_line then 
 
  s.selection_in_pattern = { 
    start_line = s.selected_line_index, 
      end_line = lpb + s.selected_line_index - 1,
   start_track = s.selected_track_index, 
     end_track = s.selected_track_index, 
  start_column = selection, 
    end_column = selection }
 else 

  local endline = sip.end_line
  local startline = sip.start_line
  local new_endline = (endline - startline) * 2 + (startline + 1)

  if new_endline > s.selected_pattern.number_of_lines then
   new_endline = s.selected_pattern.number_of_lines
  end

  s.selection_in_pattern = { 
    start_line = startline, 
      end_line = new_endline, 
   start_track = s.selected_track_index, 
     end_track = s.selected_track_index, 
  start_column = selection, 
    end_column = selection }
 end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select Column",invoke=function() DoubleSelectColumnOnly() end}
--]]

function PakettiImpulseTrackerDoubleSelectColumn()
  local s = renoise.song()
  local lpb = s.transport.lpb
  local sip = s.selection_in_pattern
  local curr_track = s.selected_track_index
  local selection = nil

  -- Determine the selected column (note or effect column)
  if s.selected_note_column_index == 0 then
    -- If no note column is selected, use the effect column
    selection = s.selected_track.visible_note_columns + s.selected_effect_column_index
  else
    -- Use the selected note column
    selection = s.selected_note_column_index
  end

  -- Set the first selection relative to LPB (expand the selection for the first run)
  if sip == nil or sip.start_track ~= curr_track or s.selected_line_index ~= s.selection_in_pattern.start_line then
    s.selection_in_pattern = {
      start_line = s.selected_line_index,
      end_line = s.selected_line_index + lpb - 1,
      start_track = curr_track,
      end_track = curr_track,
      start_column = selection,
      end_column = selection
    }
  else
    -- Expand the selection based on LPB
    local start_line = sip.start_line
    local end_line = sip.end_line
    local new_end_line = end_line + lpb

    if new_end_line > s.selected_pattern.number_of_lines then
      new_end_line = s.selected_pattern.number_of_lines
    end

    s.selection_in_pattern = {
      start_line = start_line,
      end_line = new_end_line,
      start_track = curr_track,
      end_track = curr_track,
      start_column = selection,
      end_column = selection
    }
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select Column",
  invoke=function() PakettiImpulseTrackerDoubleSelectColumn() end}


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-D Double Select Pattern",invoke=function() DoubleSelectPattern() end}

-- Function to select just the current row across all note columns
function PakettiSelectCurrentRow()
  local s = renoise.song()
  local sip = s.selection_in_pattern
  local last_column = s.selected_track.visible_effect_columns +
                      s.selected_track.visible_note_columns

  s.selection_in_pattern = {
    start_line   = s.selected_line_index,
    end_line     = s.selected_line_index,
    start_track  = s.selected_track_index,
    end_track    = s.selected_track_index,
    start_column = 1,
    end_column   = last_column,
  }
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Select Current Row",invoke=PakettiSelectCurrentRow}
--------------------------------------------------------------------------------------------------------------------------------------
--IT "Home Home Home" behaviour. First Home takes to current column first_line. Second Home takes to current track first_line. 
--Third home takes to first track first_line.
function homehome()
  local s = renoise.song()
  local w = renoise.app().window
  local song_pos = s.transport.edit_pos
  local selcol = s.selected_note_column_index
  s.transport.follow_player = false
  s.transport.loop_block_enabled = false

  -- Check if we're in the phrase editor and have API 6.2+
  if w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    if renoise.API_VERSION >= 6.2 then
      -- Print debug info about phrase editor state
      if s.selected_phrase_note_column then
        oprint("Selected phrase note column:", s.selected_phrase_note_column)
      end
      if s.selected_phrase_note_column_index then
        oprint("Selected phrase note column index:", s.selected_phrase_note_column_index)
      end

      -- Handle phrase editor navigation
      if s.selected_phrase_line_index > 1 then
        s.selected_phrase_line_index = 1
        return
      end
      
      -- If we're at line 1 but not column 1, go to column 1
      if s.selected_phrase_line_index == 1 and s.selected_phrase_note_column_index > 1 then
        s.selected_phrase_note_column_index = 1
        return
      end
      
      -- If we're at line 1 and column 1, do nothing (matches pattern editor behavior)
      if s.selected_phrase_line_index == 1 and s.selected_phrase_note_column_index == 1 then
        return
      end
    else
      renoise.app():show_error("Phrase Editor functionality requires API version 6.2 or higher!")
      return
    end
  end

  -- If not in pattern editor or phrase editor, switch to pattern editor
  if w.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  -- Rest of the existing pattern editor logic
  -- If on Master or Send-track, detect and go to first effect column.
  if s.selected_note_column_index==0 and s.selected_effect_column_index > 1 and song_pos.line == 1 and renoise.song().tracks[renoise.song().selected_track_index].visible_note_columns==0 then
    s.selected_effect_column_index = 1 
    return 
  end

  -- If on Master or Send-track, detect and go to 1st track and first note column.
  if s.selected_note_column_index==0 and song_pos.line == 1 and renoise.song().tracks[renoise.song().selected_track_index].visible_note_columns==0 then
    s.selected_track_index = 1
    s.selected_note_column_index = 1 
    return 
  end

  -- If Effect-columns chosen, take you to current effect column's first row.
  if s.selected_note_column_index==0 and song_pos.line == 1 then
    s.selected_note_column_index=1 
    return 
  end

  if s.selected_note_column_index==0 then 
    song_pos.line = 1
    s.transport.edit_pos = song_pos 
    return 
  end

  -- If Song Position Line is already First Line - but Selected Note Column is not 1
  if song_pos.line == 1 and s.selected_note_column_index > 1 then
    s.selected_note_column_index = 1 
    return 
  end

  -- If Song Position Line is not 1, and Selected Note Column is not 1
  if (s.selected_note_column_index > 1) then
    s.selected_note_column_index = selcol
    song_pos.line = 1
    s.transport.edit_pos = song_pos 
    return 
  end

  if (song_pos.line > 1) then
    song_pos.line = 1          
    s.transport.edit_pos = song_pos   
    if s.selected_note_column_index==0 then 
      s.selected_effect_column_index=1 
    else 
      s.selected_note_column_index=1
    end
    return    
  end  

  -- Go to first track
  if (s.selected_track_index > 1) then
    s.selected_track_index = 1
    s.selected_note_column_index=1 
    return 
  end
  s.selected_note_column_index=1
end

-- Update keybindings to include phrase editor
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Home *2 behaviour",invoke=homehome}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Home *2 behaviour (2nd)",invoke=homehome}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Home *2 behaviour",invoke=homehome}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker Home *2 behaviour",invoke=homehome}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker Home *2 behaviour (2nd)",invoke=homehome}
---
function endend()
  local s = renoise.song()
  local w = renoise.app().window
  local song_pos = s.transport.edit_pos

  -- Disable follow player and loop block
  s.transport.follow_player = false
  s.transport.loop_block_enabled = false

  -- Check if we're in the phrase editor and have API 6.2+
  if w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    if renoise.API_VERSION >= 6.2 then
      -- Print debug info about phrase editor state
      if s.selected_phrase_note_column then
        oprint("Selected phrase note column:", s.selected_phrase_note_column)
      end
      if s.selected_phrase_note_column_index then
        oprint("Selected phrase note column index:", s.selected_phrase_note_column_index)
      end

      local phrase = s.selected_phrase
      if not phrase then
        renoise.app():show_error("No phrase is selected!")
        return
      end

      -- Handle phrase editor navigation
      if s.selected_phrase_line_index < phrase.number_of_lines then
        s.selected_phrase_line_index = phrase.number_of_lines
        return
      end
      
      -- If we're at last line but not last column, go to last column
      if s.selected_phrase_line_index == phrase.number_of_lines and 
         s.selected_phrase_note_column_index < phrase.visible_note_columns then
        s.selected_phrase_note_column_index = phrase.visible_note_columns
        return
      end
      
      -- If we're at last line and last column, do nothing
      if s.selected_phrase_line_index == phrase.number_of_lines and 
         s.selected_phrase_note_column_index == phrase.visible_note_columns then
        return
      end
    else
      renoise.app():show_error("Phrase Editor functionality requires API version 6.2 or higher!")
      return
    end
  end

  -- If not in pattern editor or phrase editor, switch to pattern editor
  if w.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  local number = s.patterns[s.selected_pattern_index].number_of_lines
  local current_track = s.selected_track_index
  local max_track = s.sequencer_track_count

  -- Pattern editor navigation logic
  if song_pos.line < number then
    -- First press: Go to last line of current column
    song_pos.line = number
    s.transport.edit_pos = song_pos
    return
  end

  if song_pos.line == number then
    if current_track < max_track then
      -- Second press: Go to last track (if not already there)
      s.selected_track_index = max_track
      return
    end
  end
end

-- Update keybindings to include phrase editor
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker End *2 behaviour",invoke=endend}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker End *2 behaviour (2nd)",invoke=endend}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker End *2 behaviour",invoke=endend}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker End *2 behaviour",invoke=endend}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker End *2 behaviour (2nd)",invoke=endend}
-----------------------------------------------------------------------------------------------------------------------------------------
--8.  "8" in Impulse Tracker "Plays Current Line" and "Advances by EditStep".
function PlayCurrentLine(should_step)
  local s = renoise.song()
  local sli = s.selected_line_index
  
  if renoise.API_VERSION >= 6.2 then
    s:trigger_pattern_line(sli)
  else
    local t = s.transport
    t:start_at(sli)
    local start_time = os.clock()
    while (os.clock() - start_time < 0.4) do
      -- Delay the start after panic. Don't go below 0.2 seconds 
      -- or you might tempt some plugins to crash and take Renoise in the fall!!      
    end
    t:stop()
  end
  
  -- Handle line advancement (same for both versions)
  if should_step then
    if sli == s.selected_pattern.number_of_lines then
      s.selected_line_index = 1
    else
      if s.selected_pattern.number_of_lines < sli + s.transport.edit_step then
        s.selected_line_index = s.selected_pattern.number_of_lines
      else
        s.selected_line_index = sli + s.transport.edit_step
      end
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker 8 Play Current Line & Advance by EditStep",invoke=function() PlayCurrentLine(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker 8 Play Current Line Only",invoke=function() PlayCurrentLine(false) end}
-----------------
-- alt-f9 - solo / unsolo selected track. if not in Pattern Editor or in Mixer, transport to Pattern Editor.
function impulseTrackerSoloKey()
local s=renoise.song()
  s.tracks[renoise.song().selected_track_index]:solo()
    if renoise.app().window.active_middle_frame~=1 and renoise.app().window.active_middle_frame~=2 then renoise.app().window.active_middle_frame=1 end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker ALT-F10 (Solo Toggle)",invoke=function() impulseTrackerSoloKey() end}
-----------
-----------
-----------
-----------
-----------
-----------
-----------
-----------
-----------
-----------
-----------
-----------
-----------
local vb = renoise.ViewBuilder()
local dialog = nil  -- Declare dialog variable

-- Global variable to prevent automatic sample loader from running when not desired
PakettiDontRunAutomaticSampleLoader = false

-- Variables to store the state of each section
local patterns_state = "Keep"
local instruments_state = "Keep"
local pattern_sequence_state = "Keep"
local instrument_midi_outs_state = "Keep"
local instrument_samples_state = "Keep"
local instrument_plugins_state = "Keep"
local track_dsps_state = "Keep"

-- Functions to clear patterns, instruments, pattern sequence, MIDI outs, samples, plugins, and Track DSPs
function patternClear()
  local song=renoise.song()
  for i = 1, #song.patterns do
    song.patterns[i]:clear()
  end
end

function instrumentsClear()
  local song=renoise.song()
  for i = 1, #song.instruments do
    song.instruments[i]:clear()
  end
end

function patternSequenceClear()
  local song=renoise.song()
  local sequence_length = #song.sequencer.pattern_sequence
  for i = sequence_length, 2, -1 do
    song.sequencer:delete_sequence_at(i)
  end
end

function instrumentMidiOutsClear()
  local song=renoise.song()
  for i = 1, #song.instruments do
    song.instruments[i].midi_output_properties.device_name = ""
  end
end

function instrumentSamplesClear()
  local song=renoise.song()
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    if #instrument.samples > 1 then
      instrument:delete_sample_at(1)
      if #instrument.samples > 1 then
        for j = #instrument.samples, 1, -1 do
          instrument:delete_sample_at(j)
        end
      end
    elseif #instrument.samples == 1 then
      instrument:delete_sample_at(1)
    end
  end
end

function instrumentPluginsClear()
  local song=renoise.song()
  for i = 1, #song.instruments do
    song.instruments[i].plugin_properties:load_plugin("")
  end
end

function trackDspsClear()
  local song=renoise.song()
  for _, track in ipairs(song.tracks) do
    for i = #track.devices, 2, -1 do
      track:delete_device_at(i)
    end
  end
end

-- Function to clear all registered views
local function clear_registered_views()
  for id, _ in pairs(vb.views) do
    vb.views[id] = nil
  end
end

-- Function to handle the "Set all to" switch change
function handle_set_all_switch_change(value)
  local state = value == 1 and "Keep" or "Clear"
  
  patterns_state = state
  instruments_state = state
  pattern_sequence_state = state
  instrument_midi_outs_state = state
  instrument_samples_state = state
  instrument_plugins_state = state
  track_dsps_state = state

  -- Update all switches in the UI
  vb.views.patterns_switch.value = value
  vb.views.instruments_switch.value = value
  vb.views.pattern_sequence_switch.value = value
  vb.views.instrument_midi_outs_switch.value = value
  vb.views.instrument_samples_switch.value = value
  vb.views.instrument_plugins_switch.value = value
  vb.views.track_dsps_switch.value = value
end

-- Function to handle switch changes
function handle_switch_change(value, section)
  local state = value == 1 and "Keep" or "Clear"
  if section == "Patterns" then
    patterns_state = state
  elseif section == "Instruments" then
    instruments_state = state
  elseif section == "Pattern Sequence" then
    pattern_sequence_state = state
  elseif section == "Instrument MIDI Outs" then
    instrument_midi_outs_state = state
  elseif section == "Instrument Samples" then
    instrument_samples_state = state
  elseif section == "Instrument Plugins" then
    instrument_plugins_state = state
  elseif section == "Track DSPs" then
    track_dsps_state = state
  end
end

-- Function to handle the OK button click
function handle_ok_click()
  return function()
    local actions = {}
    if patterns_state == "Clear" and instruments_state == "Clear" and pattern_sequence_state == "Clear" and 
       instrument_midi_outs_state == "Clear" and instrument_samples_state == "Clear" and instrument_plugins_state == "Clear" and
       track_dsps_state == "Clear" then  -- Check Track DSPs state
      renoise.app():new_song()
    else
      if patterns_state == "Clear" then
        patternClear()
        table.insert(actions, "Patterns")
      end
      if instruments_state == "Clear" then
        instrumentsClear()
        table.insert(actions, "Instruments")
      end
      if pattern_sequence_state == "Clear" then
        patternSequenceClear()
        table.insert(actions, "Pattern Sequence")
      end
      if instrument_midi_outs_state == "Clear" then
        instrumentMidiOutsClear()
        table.insert(actions, "Instrument MIDI Outs")
      end
      if instrument_samples_state == "Clear" then
        instrumentSamplesClear()
        table.insert(actions, "Instrument Samples")
      end
      if instrument_plugins_state == "Clear" then
        instrumentPluginsClear()
        table.insert(actions, "Instrument Plugins")
      end
      if track_dsps_state == "Clear" then  -- Clear Track DSPs
        trackDspsClear()
        table.insert(actions, "Track DSPs")
      end
    end 

    local status_message = ""
    if #actions == 0 then
      status_message = "Kept all"
    else
      local kept = {}
      if patterns_state == "Keep" then table.insert(kept, "Patterns") end
      if instruments_state == "Keep" then table.insert(kept, "Instruments") end
      if pattern_sequence_state == "Keep" then table.insert(kept, "Pattern Sequence") end
      if instrument_midi_outs_state == "Keep" then table.insert(kept, "Instrument MIDI Outs") end
      if instrument_samples_state == "Keep" then table.insert(kept, "Instrument Samples") end
      if instrument_plugins_state == "Keep" then table.insert(kept, "Instrument Plugins") end
      if track_dsps_state == "Keep" then table.insert(kept, "Track DSPs") end  -- Handle Track DSPs in the status message
      if #kept > 0 then
        status_message = "Kept " .. table.concat(kept, ", ") .. "; "
      end
      status_message = status_message .. "Cleared " .. table.concat(actions, ", ")
    end
    renoise.app():show_status(status_message)
    dialog:close()
    clear_registered_views()  -- Clear registered views after dialog close
  end
end

-- Function to handle the Cancel button click
function handle_cancel_click()
  return function()
    dialog:close()
    clear_registered_views()  -- Clear registered views after dialog close
  end
end

-- Function to show the dialog
function pakettiImpulseTrackerNewSongDialog()
  -- Close any existing dialog before opening a new one
  if dialog and dialog.visible then
    dialog:close()
    clear_registered_views()  -- Ensure the reference is cleared
    return  -- Add this return to prevent creating a new dialog
  end

  -- Rest of the dialog creation code...
  vb = renoise.ViewBuilder()
  local dialog_content = vb:column{
        --margin=10,
    --vb:text{text="New Song ... with",font="bold",style="strong",align="center"},
    -- "Set all to" switch   
    vb:space {height=5},
    vb:column{style="panel",--margin=10,
   vb:row{
      vb:text{text="Set all to",width=180,style="strong",font="bold"},
      vb:switch {
        id = "set_all_switch",
        items = { "Keep", "Clear" },
        value = 1,
        width=100,
        notifier = handle_set_all_switch_change
      }
    },
    --vb:space { height = 10 },
      vb:row{
        vb:text{text="Patterns",width=180,style="strong",font="bold"},
        vb:switch {
          id = "patterns_switch",
          items = { "Keep", "Clear" },
          value = patterns_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Patterns")
          end
        }
      },
      vb:row{
        vb:text{text="Pattern Sequence",width=180,style="strong",font="bold"},
        vb:switch {
          id = "pattern_sequence_switch",
          items = { "Keep", "Clear" },
          value = pattern_sequence_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Pattern Sequence")
          end
        }
      },
      vb:row{
        vb:text{text="Instruments",width=180,style="strong",font="bold"},
        vb:switch {
          id = "instruments_switch",
          items = { "Keep", "Clear" },
          value = instruments_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Instruments")
          end
        }
      },
      vb:row{
        vb:text{text="Instrument Samples",width=180,style="strong",font="bold"},
        vb:switch {
          id = "instrument_samples_switch",
          items = { "Keep", "Clear" },
          value = instrument_samples_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Instrument Samples")
          end
        }
      },
      vb:row{
        vb:text{text="Instrument MIDI Outs",width=180,style="strong",font="bold"},
        vb:switch {
          id = "instrument_midi_outs_switch",
          items = { "Keep", "Clear" },
          value = instrument_midi_outs_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Instrument MIDI Outs")
          end
        }
      },
      vb:row{
        vb:text{text="Instrument Plugins",width=180,style="strong",font="bold"},
        vb:switch {
          id = "instrument_plugins_switch",
          items = { "Keep", "Clear" },
          value = instrument_plugins_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Instrument Plugins")
          end
        }
      },
      vb:row{
        vb:text{text="Track DSPs",width=180,style="strong",font="bold"},
        vb:switch {
          id = "track_dsps_switch",
          items = { "Keep", "Clear" },
          value = track_dsps_state == "Keep" and 1 or 2,
          width=100,
          notifier=function(value)
            handle_switch_change(value, "Track DSPs")
          end
        }
      },
      vb:space {height=10},
      vb:row{
        vb:button{text="OK",width=100,notifier=handle_ok_click()},
        vb:button{text="Cancel",width=100,notifier=handle_cancel_click()} --color={1, 0, 0}}
      }
    }
  }

  -- Open the new dialog and assign it to the 'dialog' variable
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("New Song", dialog_content, keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker CTRL-N New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
-----------------------------------------------------
----ALT-U
function Deselect_All()
  local song=renoise.song()
  
  -- Deselect the selection in the pattern editor
  song.selection_in_pattern = nil
  
  -- If the automation lower frame is showing, clear the automation selection
  if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
    local selected_track_index = song.selected_track_index
    local selected_pattern_index = song.selected_pattern_index
    local automation_parameter = song.selected_automation_parameter

    -- Check if an automatable parameter is selected
    if automation_parameter then
      local track_automation = song:pattern(selected_pattern_index):track(selected_track_index)
      local envelope = track_automation:find_automation(automation_parameter)

      -- If there is an automation envelope, clear its selection
      if envelope then
        envelope.selection_range = {1,1} 
      end
    end
  end
end
function Deselect_Phr() renoise.song().selection_in_phrase =nil end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker ALT-U Unmark Selection",invoke=function() Deselect_All() end}
renoise.tool():add_keybinding{name="Automation:Paketti:Impulse Tracker ALT-U Unmark Selection",invoke=function() Deselect_All() end}

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker ALT-U Unmark Selection (2nd)",invoke=function() Deselect_All() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-U Unmark Selection",invoke=function() Deselect_All() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-U Unmark Selection (2nd)",invoke=function() Deselect_All() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-U Unmark Selection",invoke=function() Deselect_Phr() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-U Unmark Selection (2nd)",invoke=function() Deselect_Phr() end}

-- Function to swap blocks between note columns and effect columns
function PakettiImpulseTrackerSwapBlock()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    renoise.app():show_status("No selection in pattern.")
    return
  end

  -- Extract selection boundaries
  local start_line = selection.start_line
  local end_line = selection.end_line
  local start_column = selection.start_column
  local end_column = selection.end_column
  local start_track = selection.start_track
  local end_track = selection.end_track

  -- Cursor (edit position) details
  local cursor_pos = song.transport.edit_pos
  local cursor_track = song.selected_track_index
  local cursor_line = cursor_pos.line
  local cursor_column = song.selected_note_column_index

  -- Check if the cursor is at the start of the selection
  if cursor_line == start_line and cursor_column == start_column and cursor_track == start_track then
    renoise.app():show_status("Cursor is at the start of the selection. No action taken.")
    return
  end

  -- Calculate the number of lines in the selection
  local num_lines = end_line - start_line + 1

  -- Ensure there are enough lines from the cursor position to swap
  local target_pattern = song:pattern(cursor_pos.sequence)
  if cursor_line + num_lines - 1 > #target_pattern.tracks[cursor_track].lines then
    renoise.app():show_status("Not enough lines from cursor position to swap.")
    return
  end

  -- Determine visibility settings for source and target tracks
  local source_track_obj = song.tracks[start_track]
  local target_track_obj = song.tracks[cursor_track]

  local source_visible_note_columns = source_track_obj.visible_note_columns
  local source_volume_visible = source_track_obj.volume_column_visible
  local source_panning_visible = source_track_obj.panning_column_visible
  local source_delay_visible = source_track_obj.delay_column_visible
  local source_samplefx_visible = source_track_obj.sample_effects_column_visible
  local source_visible_effect_columns = source_track_obj.visible_effect_columns -- Get the visible effect columns

  local target_visible_note_columns = target_track_obj.visible_note_columns
  local target_volume_visible = target_track_obj.volume_column_visible
  local target_panning_visible = target_track_obj.panning_column_visible
  local target_delay_visible = target_track_obj.delay_column_visible
  local target_samplefx_visible = target_track_obj.sample_effects_column_visible
  local target_visible_effect_columns = target_track_obj.visible_effect_columns -- Get the visible effect columns

  -- Determine which properties are included in the selection
  local selection_includes_volume = false
  local selection_includes_panning = false
  local selection_includes_delay = false
  local selection_includes_samplefx = false

  for col = start_column, end_column do
    if col <= source_visible_note_columns then
      -- Note columns
      if source_volume_visible then
        selection_includes_volume = true
      end
      if source_panning_visible then
        selection_includes_panning = true
      end
      if source_delay_visible then
        selection_includes_delay = true
      end
    else
      -- Sample effect columns
      if source_samplefx_visible then
        selection_includes_samplefx = true
      end
    end
  end

  -- Adjust visibility settings in the target track based on the selection
  local visibility_changed = false

  if selection_includes_volume and not target_volume_visible then
    target_track_obj.volume_column_visible = true
    visibility_changed = true
  end

  if selection_includes_panning and not target_panning_visible then
    target_track_obj.panning_column_visible = true
    visibility_changed = true
  end

  if selection_includes_delay and not target_delay_visible then
    target_track_obj.delay_column_visible = true
    visibility_changed = true
  end

  if selection_includes_samplefx and not target_samplefx_visible then
    target_track_obj.sample_effects_column_visible = true
    visibility_changed = true
  end

  -- Adjust the target track's visible effect columns based on the selection
  if source_visible_effect_columns > target_visible_effect_columns then
    target_track_obj.visible_effect_columns = source_visible_effect_columns
    visibility_changed = true
  end

  if visibility_changed then
    renoise.app():show_status("Adjusted visibility settings for the target track.")
  else
    renoise.app():show_status("No visibility adjustments needed.")
  end

  -- Function to collect data from a track's pattern (including effect columns)
  local function collect_track_data(pattern, track_index, start_line, end_line)
    local data = {}
    for line = start_line, end_line do
      local line_data = {note_columns = {}, effect_columns = {}}
      
      -- Collect note column data
      local pattern_line = pattern.tracks[track_index].lines[line]
      for column = 1, renoise.song().tracks[track_index].visible_note_columns do
        local note_column = pattern_line.note_columns[column]
        table.insert(line_data.note_columns, {
          note_value = note_column.note_value,
          instrument_value = note_column.instrument_value,
          volume_value = note_column.volume_value,
          panning_value = note_column.panning_value,
          delay_value = note_column.delay_value,
          effect_number_value = note_column.effect_number_value,
          effect_amount_value = note_column.effect_amount_value
        })
      end

      -- Collect effect column data
      local effect_columns = pattern_line.effect_columns
      for i = 1, #effect_columns do
        local effect_column = effect_columns[i]
        table.insert(line_data.effect_columns, {
          number_value = effect_column.number_value,
          amount_value = effect_column.amount_value
        })
      end

      table.insert(data, line_data)
    end
    return data
  end

  -- Collect data from the selection (source track)
  local source_pattern = song:pattern(song.selected_pattern_index)
  local selection_data = collect_track_data(
    source_pattern, 
    start_track, 
    start_line, 
    end_line
  )

  -- Collect data from the cursor block (target track)
  local target_pattern = song:pattern(cursor_pos.sequence)
  local cursor_data = collect_track_data(
    target_pattern,
    cursor_track,
    cursor_line,
    cursor_line + num_lines - 1
  )

  -- Function to swap data between source and target (including effect columns)
  local function swap_data(selection_data, cursor_data, pattern, source_track, target_track, 
                            start_line, cursor_line, num_lines)
    for line_offset = 0, num_lines - 1 do
      local source_line = start_line + line_offset
      local target_line = cursor_line + line_offset

      -- Swap note columns
      local source_note_data = selection_data[line_offset + 1].note_columns
      local target_note_data = cursor_data[line_offset + 1].note_columns
      for column = 1, #source_note_data do
        local source_note = pattern.tracks[source_track].lines[source_line].note_columns[column]
        local target_note = pattern.tracks[target_track].lines[target_line].note_columns[column]

        -- Swap note column properties
        source_note.note_value, target_note.note_value = target_note.note_value, source_note.note_value
        source_note.instrument_value, target_note.instrument_value = target_note.instrument_value, source_note.instrument_value
        source_note.volume_value, target_note.volume_value = target_note.volume_value, source_note.volume_value
        source_note.panning_value, target_note.panning_value = target_note.panning_value, source_note.panning_value
        source_note.delay_value, target_note.delay_value = target_note.delay_value, source_note.delay_value
        source_note.effect_number_value, target_note.effect_number_value = target_note.effect_number_value, source_note.effect_number_value
        source_note.effect_amount_value, target_note.effect_amount_value = target_note.effect_amount_value, source_note.effect_amount_value
      end

      -- Swap effect columns
      local source_effect_data = selection_data[line_offset + 1].effect_columns
      local target_effect_data = cursor_data[line_offset + 1].effect_columns
      for i = 1, math.min(#source_effect_data, #target_effect_data) do
        local source_effect = pattern.tracks[source_track].lines[source_line].effect_columns[i]
        local target_effect = pattern.tracks[target_track].lines[target_line].effect_columns[i]

        -- Swap effect column properties
        source_effect.number_value, target_effect.number_value = target_effect.number_value, source_effect.number_value
        source_effect.amount_value, target_effect.amount_value = target_effect.amount_value, source_effect.amount_value
      end
    end
  end

  -- Perform the swap
  swap_data(
    selection_data,
    cursor_data,
    target_pattern,
    start_track,
    cursor_track,
    start_line,
    cursor_line,
    num_lines
  )

  renoise.app():show_status("Blocks swapped successfully.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker ALT-Y Swap Block",invoke=PakettiImpulseTrackerSwapBlock}
-----------
-- Move to the next track, maintaining column type, with wrapping.
-- Move to the next track, maintaining column type, with wrapping.
function PakettiImpulseTrackerMoveForwardsTrackWrap()
  local song=renoise.song()
  local current_index = song.selected_track_index
  local is_effect_column = song.selected_effect_column_index > 0
  
  -- Wrap to the first track if at the last track
  if current_index < #song.tracks then
    song.selected_track_index = current_index + 1
  else
    song.selected_track_index = 1
  end
  
  -- Handle note/effect column based on track type
  local selected_track = song.tracks[song.selected_track_index]
  if selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    if is_effect_column then
      -- Check if the track has visible effect columns before setting effect column index
      if selected_track.visible_effect_columns > 0 then
        song.selected_effect_column_index = 1
      else
        -- Fall back to note column if no effect columns are available
        song.selected_note_column_index = 1
      end
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Move to the previous track, maintaining column type, with wrapping.
function PakettiImpulseTrackerMoveBackwardsTrackWrap()
  local song=renoise.song()
  local current_index = song.selected_track_index
  local is_effect_column = song.selected_effect_column_index > 0
  
  -- Wrap to the last track if at the first track
  if current_index > 1 then
    song.selected_track_index = current_index - 1
  else
    song.selected_track_index = #song.tracks
  end
  
  -- Handle note/effect column based on track type
  local selected_track = song.tracks[song.selected_track_index]
  if selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    if is_effect_column then
      -- Check if the track has visible effect columns before setting effect column index
      if selected_track.visible_effect_columns > 0 then
        song.selected_effect_column_index = 1
      else
        -- Fall back to note column if no effect columns are available
        song.selected_note_column_index = 1
      end
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Move to the next track, maintaining column type, no wrapping.
function PakettiImpulseTrackerMoveForwardsTrack()
  local song=renoise.song()
  local current_index = song.selected_track_index
  local is_effect_column = song.selected_effect_column_index > 0
  
  -- Move to the next track if not at the last
  if current_index < #song.tracks then
    song.selected_track_index = current_index + 1
  else
    renoise.app():show_status("You are on the last track.")
    return
  end
  
  -- Handle note/effect column based on track type
  local selected_track = song.tracks[song.selected_track_index]
  if selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    if is_effect_column then
      -- Check if the track has visible effect columns before setting effect column index
      if selected_track.visible_effect_columns > 0 then
        song.selected_effect_column_index = 1
      else
        -- Fall back to note column if no effect columns are available
        song.selected_note_column_index = 1
      end
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Move to the previous track, maintaining column type, no wrapping.
function PakettiImpulseTrackerMoveBackwardsTrack()
  local song=renoise.song()
  local current_index = song.selected_track_index
  local is_effect_column = song.selected_effect_column_index > 0
  
  -- Move to the previous track if not at the first
  if current_index > 1 then
    song.selected_track_index = current_index - 1
  else
    renoise.app():show_status("You are on the first track.")
    return
  end
  
  -- Handle note/effect column based on track type
  local selected_track = song.tracks[song.selected_track_index]
  if selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    if is_effect_column then
      -- Check if the track has visible effect columns before setting effect column index
      if selected_track.visible_effect_columns > 0 then
        song.selected_effect_column_index = 1
      else
        -- Fall back to note column if no effect columns are available
        song.selected_note_column_index = 1
      end
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveForwardsTrackWrap}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveBackwardsTrackWrap}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel",invoke=PakettiImpulseTrackerMoveForwardsTrack}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel",invoke=PakettiImpulseTrackerMoveBackwardsTrack}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveForwardsTrackWrap}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveBackwardsTrackWrap}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel",invoke=PakettiImpulseTrackerMoveForwardsTrack}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel",invoke=PakettiImpulseTrackerMoveBackwardsTrack}
renoise.tool():add_midi_mapping{name="Paketti:Move to Next Track (Wrap) [Knob]",invoke=function(message)
  if message:is_abs_value() then
    PakettiImpulseTrackerMoveForwardsTrackWrap()
  end
end}

renoise.tool():add_midi_mapping{name="Paketti:Move to Previous Track (Wrap) [Knob]",invoke=function(message)
  if message:is_abs_value() then
    PakettiImpulseTrackerMoveBackwardsTrackWrap()
  end
end}

renoise.tool():add_midi_mapping{name="Paketti:Move to Next Track [Knob]",invoke=function(message)
  if message:is_abs_value() then
    PakettiImpulseTrackerMoveForwardsTrack()
  end
end}

renoise.tool():add_midi_mapping{name="Paketti:Move to Previous Track [Knob]",invoke=function(message)
  if message:is_abs_value() then
    PakettiImpulseTrackerMoveBackwardsTrack()
  end
end}
---------
local already_interpolated = false

-- Main function triggered by the keybinding
local function alt_x_functionality(mode)
  local s = renoise.song()

  -- Retrieve selection bounds
  local selection = s.selection_in_pattern
  if not selection then
    renoise.app():show_status("No selection in pattern.")
    return
  end

  local start_track = selection.start_track
  local end_track = selection.end_track
  local start_line = selection.start_line
  local end_line = selection.end_line
  local start_column = selection.start_column
  local end_column = selection.end_column

  -- Only work on single track selections
  if start_track ~= end_track then
    renoise.app():show_status("ALT-X interpolation only works on single track selections.")
    return
  end

  -- Get current track and pattern
  local track_index = start_track
  local track = s:track(track_index)
  local pattern_track = s:pattern(s.selected_pattern_index):track(track_index)

  -- Retrieve visible columns
  local visible_note_columns = track.visible_note_columns
  local visible_effect_columns = track.visible_effect_columns
  local volume_column_visible = track.volume_column_visible
  local panning_column_visible = track.panning_column_visible
  local delay_column_visible = track.delay_column_visible
  local sample_effects_column_visible = track.sample_effects_column_visible

  -- Determine what type of columns we're working with
  local note_column_range = {}
  local effect_column_range = {}
  
  -- Calculate note column ranges (volume, panning, delay, sample effects)
  for col = start_column, end_column do
    if col <= visible_note_columns then
      table.insert(note_column_range, col)
    elseif col > visible_note_columns then
      table.insert(effect_column_range, col - visible_note_columns)
    end
  end

  -- Function to convert hex string to number
  local function hex_string_to_number(hex_string)
    if hex_string == ".." or hex_string == "" then
      return nil
    end
    return tonumber(hex_string, 16)  -- Convert hex string to number
  end

  -- Function to convert number back to hex value (for writing back to Renoise)
  local function number_to_hex_value(number)
    return math.floor(math.max(0, math.min(255, number)))
  end

  -- Function to number_to_hex
  local function number_to_hex(number)
    return math.floor(math.max(0, math.min(255, number)))
  end

  -- Function to calculate interpolation values for note columns
  local function calculate_note_column_interpolation()
    local interpolated_values = {volume = {}, panning = {}, delay = {}, sample_effects = {}}
    
    for _, note_col in ipairs(note_column_range) do
      local first_line = pattern_track:line(start_line).note_columns[note_col]
      local last_line = pattern_track:line(end_line).note_columns[note_col]
      
                    -- Volume column interpolation
       if volume_column_visible then
         local first_vol = hex_string_to_number(first_line.volume_string)
         local last_vol = hex_string_to_number(last_line.volume_string)
         
         if first_vol ~= nil and last_vol ~= nil then
           interpolated_values.volume[note_col] = {}
           for line_index = start_line, end_line do
             local t = (end_line == start_line) and 0 or (line_index - start_line) / (end_line - start_line)
             local interpolated_value = number_to_hex_value(first_vol + t * (last_vol - first_vol))
             interpolated_values.volume[note_col][line_index] = interpolated_value
           end
         end
       end
      
                    -- Panning column interpolation
       if panning_column_visible then
         local first_pan = hex_string_to_number(first_line.panning_string)
         local last_pan = hex_string_to_number(last_line.panning_string)
         if first_pan ~= nil and last_pan ~= nil then
           interpolated_values.panning[note_col] = {}
           for line_index = start_line, end_line do
             local t = (end_line == start_line) and 0 or (line_index - start_line) / (end_line - start_line)
             local interpolated_value = number_to_hex_value(first_pan + t * (last_pan - first_pan))
             interpolated_values.panning[note_col][line_index] = interpolated_value
           end
         end
       end
      
                    -- Delay column interpolation
       if delay_column_visible then
         local first_delay = hex_string_to_number(first_line.delay_string)
         local last_delay = hex_string_to_number(last_line.delay_string)
         if first_delay ~= nil and last_delay ~= nil then
           interpolated_values.delay[note_col] = {}
           for line_index = start_line, end_line do
             local t = (end_line == start_line) and 0 or (line_index - start_line) / (end_line - start_line)
             local interpolated_value = number_to_hex_value(first_delay + t * (last_delay - first_delay))
             interpolated_values.delay[note_col][line_index] = interpolated_value
           end
         end
       end
      
                    -- Sample effects column interpolation
       if sample_effects_column_visible then
         local first_fx = hex_string_to_number(first_line.effect_amount_string)
         local last_fx = hex_string_to_number(last_line.effect_amount_string)
         if first_fx ~= nil and last_fx ~= nil then
           interpolated_values.sample_effects[note_col] = {}
           for line_index = start_line, end_line do
             local t = (end_line == start_line) and 0 or (line_index - start_line) / (end_line - start_line)
             local interpolated_value = number_to_hex_value(first_fx + t * (last_fx - first_fx))
             interpolated_values.sample_effects[note_col][line_index] = interpolated_value
           end
         end
       end
    end
    
    return interpolated_values
  end

  -- Function to calculate interpolation values for effect columns
  local function calculate_effect_column_interpolation()
    local interpolated_values = {}
    
    for _, effect_col in ipairs(effect_column_range) do
      if effect_col <= visible_effect_columns then
        local first_effect = pattern_track:line(start_line).effect_columns[effect_col]
        local last_effect = pattern_track:line(end_line).effect_columns[effect_col]
        
                          local first_value = hex_string_to_number(first_effect.amount_string)
         local last_value = hex_string_to_number(last_effect.amount_string)
         
         if first_value ~= nil and last_value ~= nil then
           interpolated_values[effect_col] = {}
           for line_index = start_line, end_line do
             local t = (end_line == start_line) and 0 or (line_index - start_line) / (end_line - start_line)
             local interpolated_value = number_to_hex_value(first_value + t * (last_value - first_value))
             interpolated_values[effect_col][line_index] = interpolated_value
           end
         end
      end
    end
    
    return interpolated_values
  end

  -- Function to read current note column content
  local function read_current_note_content()
    local current_values = {volume = {}, panning = {}, delay = {}, sample_effects = {}}
    
    for _, note_col in ipairs(note_column_range) do
      current_values.volume[note_col] = {}
      current_values.panning[note_col] = {}
      current_values.delay[note_col] = {}
      current_values.sample_effects[note_col] = {}
      
      for line_index = start_line, end_line do
        local line = pattern_track:line(line_index)
        local note_column = line.note_columns[note_col]
        
        current_values.volume[note_col][line_index] = hex_string_to_number(note_column.volume_string) or -1
        current_values.panning[note_col][line_index] = hex_string_to_number(note_column.panning_string) or -1
        current_values.delay[note_col][line_index] = hex_string_to_number(note_column.delay_string) or -1
        current_values.sample_effects[note_col][line_index] = hex_string_to_number(note_column.effect_amount_string) or -1
      end
    end
    
    return current_values
  end

  -- Function to read current effect column content
  local function read_current_effect_content()
    local current_values = {}
    
    for _, effect_col in ipairs(effect_column_range) do
      if effect_col <= visible_effect_columns then
        current_values[effect_col] = {}
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          local effect_column = line.effect_columns[effect_col]
          current_values[effect_col][line_index] = hex_string_to_number(effect_column.amount_string) or -1
        end
      end
    end
    
    return current_values
  end

  -- Function to compare note column content
  local function note_content_matches_interpolation(current_values, interpolated_values)
    for col_type, col_data in pairs(interpolated_values) do
      for note_col, line_data in pairs(col_data) do
        if current_values[col_type] and current_values[col_type][note_col] then
          for line_index, value in pairs(line_data) do
            if current_values[col_type][note_col][line_index] ~= value then
              return false
            end
          end
        end
      end
    end
    return true
  end

  -- Function to compare effect column content
  local function effect_content_matches_interpolation(current_values, interpolated_values)
    for effect_col, line_data in pairs(interpolated_values) do
      if current_values[effect_col] then
        for line_index, value in pairs(line_data) do
          if current_values[effect_col][line_index] ~= value then
            return false
          end
        end
      end
    end
    return true
  end

  -- Function to apply note column interpolation
  local function apply_note_interpolation(interpolated_values)
    local first_line = pattern_track:line(start_line)
    local status_parts = {}
    
    for col_type, col_data in pairs(interpolated_values) do
      for note_col, line_data in pairs(col_data) do
        for line_index, value in pairs(line_data) do
          local line = pattern_track:line(line_index)
          local note_column = line.note_columns[note_col]
          
          if col_type == "volume" then
            note_column.volume_value = value
            if not table.find(status_parts, "Volume") then table.insert(status_parts, "Volume") end
          elseif col_type == "panning" then
            note_column.panning_value = value
            if not table.find(status_parts, "Panning") then table.insert(status_parts, "Panning") end
          elseif col_type == "delay" then
            note_column.delay_value = value
            if not table.find(status_parts, "Delay") then table.insert(status_parts, "Delay") end
          elseif col_type == "sample_effects" then
            note_column.effect_number_string = first_line.note_columns[note_col].effect_number_string
            note_column.effect_amount_value = value
            if not table.find(status_parts, "Sample Effects") then table.insert(status_parts, "Sample Effects") end
          end
        end
      end
    end
    
    if #status_parts > 0 then
      renoise.app():show_status(table.concat(status_parts, ", ") .. " interpolated.")
    end
  end

  -- Function to apply effect column interpolation
  local function apply_effect_interpolation(interpolated_values)
    local first_effect_line = pattern_track:line(start_line).effect_columns
    
         for effect_col, line_data in pairs(interpolated_values) do
       for line_index, value in pairs(line_data) do
         local line = pattern_track:line(line_index)
         line.effect_columns[effect_col].number_string = first_effect_line[effect_col].number_string
         line.effect_columns[effect_col].amount_value = value
       end
     end
    
    renoise.app():show_status("Effect columns interpolated.")
  end

  -- Function to clear note columns
  local function clear_note_columns()
    local status_parts = {}
    
    for line_index = start_line, end_line do
      local line = pattern_track:line(line_index)
      for _, note_col in ipairs(note_column_range) do
        local note_column = line.note_columns[note_col]
        
                 if volume_column_visible and hex_string_to_number(note_column.volume_string) then
           note_column.volume_string = ".."
           if not table.find(status_parts, "Volume") then table.insert(status_parts, "Volume") end
         end
         if panning_column_visible and hex_string_to_number(note_column.panning_string) then
           note_column.panning_string = ".."
           if not table.find(status_parts, "Panning") then table.insert(status_parts, "Panning") end
         end
         if delay_column_visible and hex_string_to_number(note_column.delay_string) then
           note_column.delay_string = ".."
           if not table.find(status_parts, "Delay") then table.insert(status_parts, "Delay") end
         end
         if sample_effects_column_visible and hex_string_to_number(note_column.effect_amount_string) then
           note_column.effect_number_string = ".."
           note_column.effect_amount_string = ".."
           if not table.find(status_parts, "Sample Effects") then table.insert(status_parts, "Sample Effects") end
         end
      end
    end
    
    if #status_parts > 0 then
      renoise.app():show_status(table.concat(status_parts, ", ") .. " cleared.")
    end
  end

  -- Function to clear effect columns
  local function clear_effect_columns()
    for line_index = start_line, end_line do
      local line = pattern_track:line(line_index)
      for _, effect_col in ipairs(effect_column_range) do
        if effect_col <= visible_effect_columns then
          line.effect_columns[effect_col]:clear()
        end
      end
    end
    renoise.app():show_status("Effect columns cleared.")
  end

  -- Main logic based on mode
  if mode == "volume" then
    -- Volume column mode - only work with note columns for volume
    local has_note_columns = #note_column_range > 0
    
    if not has_note_columns then
      renoise.app():show_status("No note columns selected for volume interpolation.")
      return
    end
    
    if not volume_column_visible then
      renoise.app():show_status("Volume column is not visible.")
      return
    end
    
    local current_note_values = read_current_note_content()
    local interpolated_note_values = calculate_note_column_interpolation()
    
    -- Check if any volume interpolation data exists
    local has_volume_data = false
    
    for note_col, line_data in pairs(interpolated_note_values.volume) do
      if next(line_data) then
        has_volume_data = true
        break
      end
    end
    
    if has_volume_data then
      -- Create volume-only interpolation data
      local volume_only_interpolation = {volume = interpolated_note_values.volume}
      if note_content_matches_interpolation(current_note_values, volume_only_interpolation) then
        -- Clear only volume columns
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          for _, note_col in ipairs(note_column_range) do
            local note_column = line.note_columns[note_col]
            if hex_string_to_number(note_column.volume_string) then
              note_column.volume_string = ".."
            end
          end
        end
        renoise.app():show_status("Volume columns cleared.")
      else
        -- Apply only volume interpolation
        for note_col, line_data in pairs(interpolated_note_values.volume) do
          for line_index, value in pairs(line_data) do
            local line = pattern_track:line(line_index)
            local note_column = line.note_columns[note_col]
            note_column.volume_value = value
          end
        end
        renoise.app():show_status("Volume columns interpolated.")
      end
    else
      renoise.app():show_status("No volume data to interpolate between.")
    end
    
  elseif mode == "panning" then
    -- Panning column mode - only work with note columns for panning
    local has_note_columns = #note_column_range > 0
    
    if not has_note_columns then
      renoise.app():show_status("No note columns selected for panning interpolation.")
      return
    end
    
    if not panning_column_visible then
      renoise.app():show_status("Panning column is not visible.")
      return
    end
    
    local current_note_values = read_current_note_content()
    local interpolated_note_values = calculate_note_column_interpolation()
    
    -- Check if any panning interpolation data exists
    local has_panning_data = false
    for note_col, line_data in pairs(interpolated_note_values.panning) do
      if next(line_data) then
        has_panning_data = true
        break
      end
    end
    
    if has_panning_data then
      -- Create panning-only interpolation data
      local panning_only_interpolation = {panning = interpolated_note_values.panning}
      if note_content_matches_interpolation(current_note_values, panning_only_interpolation) then
        -- Clear only panning columns
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          for _, note_col in ipairs(note_column_range) do
            local note_column = line.note_columns[note_col]
            if hex_string_to_number(note_column.panning_string) then
              note_column.panning_string = ".."
            end
          end
        end
        renoise.app():show_status("Panning columns cleared.")
      else
        -- Apply only panning interpolation
        for note_col, line_data in pairs(interpolated_note_values.panning) do
          for line_index, value in pairs(line_data) do
            local line = pattern_track:line(line_index)
            local note_column = line.note_columns[note_col]
            note_column.panning_value = value
          end
        end
        renoise.app():show_status("Panning columns interpolated.")
      end
    else
      renoise.app():show_status("No panning data to interpolate between.")
    end
    
  elseif mode == "delay" then
    -- Delay column mode - only work with note columns for delay
    local has_note_columns = #note_column_range > 0
    
    if not has_note_columns then
      renoise.app():show_status("No note columns selected for delay interpolation.")
      return
    end
    
    if not delay_column_visible then
      renoise.app():show_status("Delay column is not visible.")
      return
    end
    
    local current_note_values = read_current_note_content()
    local interpolated_note_values = calculate_note_column_interpolation()
    
    -- Check if any delay interpolation data exists
    local has_delay_data = false
    for note_col, line_data in pairs(interpolated_note_values.delay) do
      if next(line_data) then
        has_delay_data = true
        break
      end
    end
    
    if has_delay_data then
      -- Create delay-only interpolation data
      local delay_only_interpolation = {delay = interpolated_note_values.delay}
      if note_content_matches_interpolation(current_note_values, delay_only_interpolation) then
        -- Clear only delay columns
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          for _, note_col in ipairs(note_column_range) do
            local note_column = line.note_columns[note_col]
            if hex_string_to_number(note_column.delay_string) then
              note_column.delay_string = ".."
            end
          end
        end
        renoise.app():show_status("Delay columns cleared.")
      else
        -- Apply only delay interpolation
        for note_col, line_data in pairs(interpolated_note_values.delay) do
          for line_index, value in pairs(line_data) do
            local line = pattern_track:line(line_index)
            local note_column = line.note_columns[note_col]
            note_column.delay_value = value
          end
        end
        renoise.app():show_status("Delay columns interpolated.")
      end
    else
      renoise.app():show_status("No delay data to interpolate between.")
    end
    
  elseif mode == "sample_effect" then
    -- Sample effect mode - only work with note columns for sample effects
    local has_note_columns = #note_column_range > 0
    
    if not has_note_columns then
      renoise.app():show_status("No note columns selected for sample effect interpolation.")
      return
    end
    
    if not sample_effects_column_visible then
      renoise.app():show_status("Sample effects column is not visible.")
      return
    end
    
    local current_note_values = read_current_note_content()
    local interpolated_note_values = calculate_note_column_interpolation()
    
    -- Check if any sample effect interpolation data exists
    local has_sample_effect_data = false
    for note_col, line_data in pairs(interpolated_note_values.sample_effects) do
      if next(line_data) then
        has_sample_effect_data = true
        break
      end
    end
    
    if has_sample_effect_data then
      -- Create sample effect-only interpolation data
      local sample_effect_only_interpolation = {sample_effects = interpolated_note_values.sample_effects}
      if note_content_matches_interpolation(current_note_values, sample_effect_only_interpolation) then
        -- Clear only sample effect columns
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          for _, note_col in ipairs(note_column_range) do
            local note_column = line.note_columns[note_col]
            if hex_string_to_number(note_column.effect_amount_string) then
              note_column.effect_number_string = ".."
              note_column.effect_amount_string = ".."
            end
          end
        end
        renoise.app():show_status("Sample effect columns cleared.")
      else
        -- Apply only sample effect interpolation
        local first_line = pattern_track:line(start_line)
        for note_col, line_data in pairs(interpolated_note_values.sample_effects) do
          for line_index, value in pairs(line_data) do
            local line = pattern_track:line(line_index)
            local note_column = line.note_columns[note_col]
            note_column.effect_number_value = first_line.note_columns[note_col].effect_number_value
            note_column.effect_amount_value = value
          end
        end
        renoise.app():show_status("Sample effect columns interpolated.")
      end
    else
      renoise.app():show_status("No sample effect data to interpolate between.")
    end
    
  elseif mode == "effect" then
    -- Effect column mode - only work with effect columns
    local has_effect_columns = #effect_column_range > 0
    
    if not has_effect_columns then
      renoise.app():show_status("No effect columns selected for effect interpolation.")
      return
    end
    
    local current_effect_values = read_current_effect_content()
    local interpolated_effect_values = calculate_effect_column_interpolation()
    
    if next(interpolated_effect_values) then
      if effect_content_matches_interpolation(current_effect_values, interpolated_effect_values) then
        clear_effect_columns()
      else
        apply_effect_interpolation(interpolated_effect_values)
      end
    else
      renoise.app():show_status("No effect data to interpolate between.")
    end
    
  else
    renoise.app():show_status("Invalid mode for ALT-X functionality.")
  end

  -- After the script is run, set focus back to the middle frame
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Smart ALT-X function that auto-detects the column type
local function smart_alt_x_functionality()
  local s = renoise.song()
  local sub_column_type = s.selected_sub_column_type
  
  -- Sub-column types from PakettiSubColumnModifier:
  -- 1 = "Note", 2 = "Instrument Number", 3 = "Volume", 4 = "Panning", 5 = "Delay"
  -- 6 = "Sample Effect Number", 7 = "Sample Effect Amount", 8 = "Effect Number", 9 = "Effect Amount"
  
  local mode = nil
  local column_name = ""
  
  if sub_column_type == 3 then
    -- Volume column
    mode = "volume"
    column_name = "Volume"
  elseif sub_column_type == 4 then
    -- Panning column
    mode = "panning"
    column_name = "Panning"
  elseif sub_column_type == 5 then
    -- Delay column
    mode = "delay"
    column_name = "Delay"
  elseif sub_column_type == 6 or sub_column_type == 7 then
    -- Sample Effect Number or Amount
    mode = "sample_effect"
    column_name = "Sample Effect"
  elseif sub_column_type == 8 or sub_column_type == 9 then
    -- Effect Number or Amount
    mode = "effect"
    column_name = "Effect"
  elseif sub_column_type == 1 or sub_column_type == 2 then
    -- Note or Instrument Number - default to effect column
    mode = "effect"
    column_name = "Effect (default for Note/Instrument column)"
  else
    renoise.app():show_status("ALT-X interpolation not supported for this column type.")
    return
  end
  
  print("Smart ALT-X detected: " .. column_name .. " column (sub-column type " .. sub_column_type .. ")")
  alt_x_functionality(mode)
end

-- Smart ALT-X keybinding that auto-detects column type
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-X Smart (Auto-detect Column)",
  invoke=function() smart_alt_x_functionality() end}

-- Volume column interpolation keybinding
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-X Volume Column (Interpolate&Clear)",
  invoke=function() alt_x_functionality("volume") end}

-- Effect column interpolation keybinding  
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-X Effect Column (Interpolate&Clear)",
  invoke=function() alt_x_functionality("effect") end}


  renoise.tool():add_keybinding{name="Global:Paketti:Select First Instrument Box Slot", invoke=function()
  renoise.song().selected_instrument_index = 1  
  local instrumentName = renoise.song().selected_instrument.name
  if renoise.song().selected_instrument.name == "" then instrumentName = "<No Instrument>" end
  
renoise.app():show_status("Selected first instrument: " .. formatDigits(3,renoise.song().selected_instrument_index) .. ": " .. instrumentName)
end

  }

-- Pattern to Sample (CTRL-O) - Render current pattern to new sample
function PakettiImpulseTrackerPatternToSample()
  local song = renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  
  -- Set flag to prevent automatic sample loader from running (we'll handle pakettification ourselves)
  PakettiDontRunAutomaticSampleLoader = true
  
  print("DEBUG: Starting Pattern to Sample render")
  print("DEBUG: Pattern " .. pattern_index .. " - " .. pattern.number_of_lines .. " lines")
  
  -- Create temporary file path (simpler approach for CoreAudio compatibility)
  local temp_filename = "paketti_pattern_render_" .. os.time() .. ".wav"
  local temp_path = renoise.tool().bundle_path .. temp_filename
  print("DEBUG: Temp file path: " .. temp_path)
  
  -- Setup render options for current pattern
  local render_options = {
    sample_rate = preferences.renderSampleRate.value,
    bit_depth = preferences.renderBitDepth.value,
    interpolation = preferences.renderInterpolation.value,
    priority = "high",
    start_pos = renoise.SongPos(song.selected_sequence_index, 1),
    end_pos = renoise.SongPos(song.selected_sequence_index, pattern.number_of_lines)
  }
  
  print("DEBUG: Render options setup - sequence " .. song.selected_sequence_index .. ", lines 1-" .. pattern.number_of_lines)
  
  -- Show status before rendering starts
  renoise.app():show_status("Rendering in progress...")
  
  -- Render the pattern
  print("STATUS: Rendering pattern " .. pattern_index .. " to sample...")
  
  -- Use completion callback like Clean Render does - called only when render is completely finished
  local success, error_message = song:render(render_options, temp_path, function()
    -- This callback is called when render is COMPLETELY finished (like in Clean Render)
    PakettiPatternToSampleRenderComplete(temp_path, pattern_index)
  end)
  
  if not success then
    print("ERROR: Render failed: " .. (error_message or "unknown error"))
    renoise.app():show_status("Pattern render failed: " .. (error_message or "unknown error"))
    -- Reset flag if render fails
    PakettiDontRunAutomaticSampleLoader = false
    return
  end
  
  print("DEBUG: Render started, waiting for completion callback...")
end

-- Completion callback called when render is completely finished
function PakettiPatternToSampleRenderComplete(temp_path, pattern_index)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  print("DEBUG: Render completion callback triggered - file should be ready")
  
  local song = renoise.song()
  
  -- Create new instrument
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  local instrument = song.selected_instrument
  
  -- Apply Paketti default instrument configuration if available
  if pakettiPreferencesDefaultInstrumentLoader then
    print("DEBUG: Applying default instrument configuration")
    pakettiPreferencesDefaultInstrumentLoader()
    instrument = song.selected_instrument
  end
  
  -- Clear default sample if present
  if #instrument.samples > 0 then
    print("DEBUG: Clearing default sample")
    instrument:delete_sample_at(1)
  end
  
  -- Load rendered file as sample
  print("DEBUG: Loading rendered file as sample")
  instrument:insert_sample_at(1)
  local sample = instrument.samples[1]
  
  -- File should be completely ready now since callback is only called when render is done
  local sample_buffer = sample.sample_buffer
  local load_success, load_error = pcall(function()
    return sample_buffer:load_from(temp_path)
  end)
  
  if load_success then
    print("DEBUG: Sample loaded successfully")
    
    -- Set sample properties
    sample.name = string.format("Pattern %02d Render", pattern_index)
    instrument.name = string.format("Pattern %02d Render", pattern_index)
    
    -- Apply Paketti loader preferences if available
    if preferences and preferences.pakettiLoaderAutofade then
      sample.autofade = preferences.pakettiLoaderAutofade.value
      sample.autoseek = preferences.pakettiLoaderAutoseek.value
      sample.loop_mode = preferences.pakettiLoaderLoopMode.value
      sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      sample.oneshot = preferences.pakettiLoaderOneshot.value
      sample.new_note_action = preferences.pakettiLoaderNNA.value
      sample.loop_release = preferences.pakettiLoaderLoopExit.value
      print("DEBUG: Applied Paketti loader preferences")
    else
      -- Fallback to sensible defaults if preferences not available
      sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
      sample.oversample_enabled = false
      sample.oneshot = false
      sample.new_note_action = renoise.Sample.NEW_NOTE_ACTION_NOTE_CUT
      print("DEBUG: Applied fallback sample settings")
    end
    
    print("DEBUG: Sample properties configured")
    
    -- Clean up temporary file
    os.remove(temp_path)
    print("DEBUG: Temporary file cleaned up")
    
    -- Success message with detailed information
    local duration_seconds = sample_buffer.number_of_frames / sample_buffer.sample_rate
    local status_msg = string.format("Instrument %02d saved with Pattern data %02d size %d frames %.1fs %dHz, %d-bit", 
      song.selected_instrument_index, pattern_index, sample_buffer.number_of_frames, 
      duration_seconds, sample_buffer.sample_rate, sample_buffer.bit_depth)
    
    print("STATUS: " .. status_msg)
    renoise.app():show_status(status_msg)
    
    -- Reset flag to allow automatic sample loader to work normally again
    PakettiDontRunAutomaticSampleLoader = false
    
  else
    print("ERROR: Failed to load rendered file as sample: " .. tostring(load_error))
    renoise.app():show_status("Failed to load rendered audio as sample")
    
    -- Clean up temporary file
    os.remove(temp_path)
    
    -- Remove empty instrument
    if #instrument.samples == 0 then
      song:delete_instrument_at(song.selected_instrument_index)
    end
    
    -- Reset flag even in error case to allow automatic sample loader to work normally again
    PakettiDontRunAutomaticSampleLoader = false
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker CTRL-O Pattern to Sample", invoke = PakettiImpulseTrackerPatternToSample}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Impulse Tracker CTRL-O Pattern to Sample", invoke = PakettiImpulseTrackerPatternToSample}
renoise.tool():add_midi_mapping{name="Paketti:Impulse Tracker CTRL-O Pattern to Sample [Trigger]",invoke=function(message) if message:is_trigger() then PakettiImpulseTrackerPatternToSample() end end}

--

-- MIDI Mappings for basic functions
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate [Trigger]",invoke=function(message)
  if message:is_trigger() then
    ExpandSelectionReplicate()
  end
end}

renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate [Trigger]",invoke=function(message)
  if message:is_trigger() then
    ShrinkSelectionReplicate()
  end
end}

-- Function to expand selection replicate on tracks 1-8
function ExpandSelectionReplicateTracks1to8()
  local s = renoise.song()
  local original_track = s.selected_track_index
  
  for track_index = 1, 8 do
    -- Check if track exists and is a sequencer track
    if track_index <= #s.tracks and s.tracks[track_index].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track_index = track_index
      ExpandSelectionReplicate()
    end
  end
  
  -- Restore original track selection if it's still valid
  if original_track <= #s.tracks then
    s.selected_track_index = original_track
  end
  
  renoise.app():show_status("Expand Selection Replicate applied to tracks 1-8")
end

-- Function to shrink selection replicate on tracks 1-8
function ShrinkSelectionReplicateTracks1to8()
  local s = renoise.song()
  local original_track = s.selected_track_index
  
  for track_index = 1, 8 do
    -- Check if track exists and is a sequencer track
    if track_index <= #s.tracks and s.tracks[track_index].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track_index = track_index
      ShrinkSelectionReplicate()
    end
  end
  
  -- Restore original track selection if it's still valid
  if original_track <= #s.tracks then
    s.selected_track_index = original_track
  end
  
  renoise.app():show_status("Shrink Selection Replicate applied to tracks 1-8")
end

-- MIDI Mappings for 8-track versions
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Tracks 1-8 [Trigger]",invoke=function(message)
  if message:is_trigger() then
    ExpandSelectionReplicateTracks1to8()
  end
end}

renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Tracks 1-8 [Trigger]",invoke=function(message)
  if message:is_trigger() then
    ShrinkSelectionReplicateTracks1to8()
  end
end}

for i=1,8 do
  renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track " .. i .. " [Trigger]",invoke=function(message) ExpandSelectionReplicate(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track " .. i .. " [Trigger]",invoke=function(message) ShrinkSelectionReplicate(i) end}
end 
  --[[
-- Individual track MIDI mappings for Expand Selection Replicate (8 mappings)
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 2 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(2) end end}
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 3 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(3) end end}
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 4 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 5 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(5) end end}
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 6 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(6) end end}
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 7 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(7) end end}
renoise.tool():add_midi_mapping{name="Paketti:Expand Selection Replicate Track 8 [Trigger]",invoke=function(message) if message:is_trigger() then ExpandSelectionReplicate(8) end end}

-- Individual track MIDI mappings for Shrink Selection Replicate (8 mappings)
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 2 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(2) end end}
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 3 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(3) end end}
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 4 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 5 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(5) end end}
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 6 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(6) end end}
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 7 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(7) end end}
renoise.tool():add_midi_mapping{name="Paketti:Shrink Selection Replicate Track 8 [Trigger]",invoke=function(message) if message:is_trigger() then ShrinkSelectionReplicate(8) end end}

]]--

----

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









-- from Paper
-- Rough formula i hacked up: 
-- ( 1 / (floor((5 * rate) / (3 * tempo)) / rate * speed) ) * 10

-- and another Paper example:
-- ( 1 / (floor((5 * rate) / (3 * tempo)) / rate * speed) ) * (rows_per_beat * 2.5)
-- i think this is correct


-- Paper simplified
--- (rows_per_beat * 2.5 * rate) / (floor((5 * rate) / (3 * tempo)) * speed)

-- from 8bitbubsy
-- Take BPM 129 at 44100Hz as an example:
-- samplesPerTick = 44100 / 129 = 341.860465116 --> truncated to 341.
-- BPM = 44100.0 / samplesPerTick (341) = BPM 129.325 

-- another example from 8bitbubsy
-- realBPM = (rate / floor(rate / bpm * 2.5)) / (speed / 15) 
-- result is (15 = 6*2.5)



-- TODO: Does this work if you have a 192 pattern length?
-- TODO: What if you wanna double it or halve it based on how many beats are there
-- in the pattern?
-- TODO: Consider those examples above.
-- Dialog Reference
local dialog = nil

-- Default Values
local speed = 6
local tempo = 125
local real_bpm = tempo / (speed / 6)


-- Function to Calculate BPM
local function calculate_bpm(speed, tempo)
  -- Simple formula: if speed is 6, BPM equals tempo
  -- If speed is higher than 6, BPM is lower, if speed is lower than 6, BPM is higher
  local bpm = tempo / (speed / 6)
  -- Check if BPM is within valid range (20 to 999)
  if bpm < 20 or bpm > 999 then
    return nil, {
      string.format("Invalid BPM value '%.2f'", bpm),
      "Valid values are (20 to 999)"
    }
  end
  return bpm
end

-- GUI Dialog Function
function pakettiSpeedTempoDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  -- Valueboxes for Speed and Tempo
  local vb = renoise.ViewBuilder()
  local dialog_content = vb:column{margin=10,--spacing=8,
    vb:row{
      vb:column{
        vb:text{text="Speed:"},
        vb:valuebox{min=1,max=255,value=speed,
          tostring=function(val) return string.format("%X", val) end,
          tonumber=function(val) return tonumber(val, 16) end,
          notifier=function(val)
            speed = val
            local calculated_bpm, error_msgs = calculate_bpm(speed, tempo)
            real_bpm = calculated_bpm
            vb.views.result_label.text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm or 0)
            if error_msgs then
              vb.views.error_label1.text = error_msgs[1]
              vb.views.error_label2.text = error_msgs[2]
            else
              vb.views.error_label1.text = ""
              vb.views.error_label2.text = ""
            end
          end
        }
      },
      vb:column{
        vb:text{text="Tempo:"},
        vb:valuebox{min=32,max=255,value=tempo,
          notifier=function(val)
            tempo = val
            local calculated_bpm, error_msgs = calculate_bpm(speed, tempo)
            real_bpm = calculated_bpm
            vb.views.result_label.text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm or 0)
            if error_msgs then
              vb.views.error_label1.text = error_msgs[1]
              vb.views.error_label2.text = error_msgs[2]
            else
              vb.views.error_label1.text = ""
              vb.views.error_label2.text = ""
            end
          end
        }
      }
    },

    -- Result Display
    vb:row{
      vb:text{id="result_label",text=string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm)}
    },

    -- Error Display (split into two rows)
    vb:row{vb:text{id="error_label1",text="",style="strong",font="bold"}},
    vb:row{vb:text{id="error_label2",text="",style="strong",font="bold"}},
    
    -- Set BPM Button
    vb:row{
      vb:button{text="Set BPM",width=60,
        notifier=function()
          if not real_bpm then
            renoise.app():show_status("Cannot set BPM - value out of valid range (20 to 999)")
            return
          end
          renoise.song().transport.bpm = real_bpm
          renoise.app():show_status(string.format("BPM set to %.2f", real_bpm))
        end
      },
      vb:button{text="Close",width=60,
        notifier=function()
          if dialog and dialog.visible then
            dialog:close()
            dialog = nil
          end
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Speed and Tempo to BPM",dialog_content,keyhandler)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Speed and Tempo to BPM Dialog...",invoke=pakettiSpeedTempoDialog}
