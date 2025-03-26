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
t.loop_block_enabled=false
t:start_at(startpos)
end
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F5 Start Playback",invoke=function() ImpulseTrackerPlaySong() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F5 Start Playback (2nd)",invoke=function() ImpulseTrackerPlaySong() end}
----------------------------------------------------------------------------------------------------------------
-- F6, or Impulse Tracker Play Pattern.
-- There is currently no need for this, but if there one day is, this'll be where it will reside :)
-- You can map F6 to Global:Transport:Play Pattern.
----------------------------------------------------------------------------------------------------------------
-- F7, or Impulse Tracker Play from line.
function ImpulseTrackerPlayFromLine()
local monitoring_enabled = true
  --InitSBx()
  reset_repeat_counts()
  ResetAllSteppers()

 local s = renoise.song()
 local t = s.transport
 local startpos = t.playback_pos  
 if t.playing == true  then 
 t.loop_pattern=false
   t:panic()
  t.loop_pattern=false
  t.loop_block_enabled=false
  t.edit_mode=true
 startpos.line = s.selected_line_index
 startpos.sequence = s.selected_sequence_index
 t.playback_pos = startpos
  t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN)
 return
 else
  t:panic()
  t.loop_pattern=false
  t.loop_block_enabled=false
  t.edit_mode=true
 startpos.line = s.selected_line_index
 startpos.sequence = s.selected_sequence_index
 t.playback_pos = startpos
  t:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN)
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F7 Start Playback from Cursor Row",invoke=function() ImpulseTrackerPlayFromLine() end}
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker F7 Start Playback from Cursor Row (2nd)",invoke=function() ImpulseTrackerPlayFromLine() end}
------------------------------------------------------------------------------------------------------------------------------------------- F8
function ImpulseTrackerStop()
  local t = renoise.song().transport
  local s = renoise.song()

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

-- Keep your existing keybindings
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
end}
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

-- Add the keybinding to ensure the function can be invoked using F12
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
        renoise.song().selection_in_phrase = {
          start_line   = renoise.song().selected_phrase_line_index,
          end_line     = new_end_line,
          start_column = 1,
          end_column   = total_columns,
        }

        -- Assign the new selection and print the assigned values
        --s.selection_in_phrase = new_selection
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
  local song = renoise.song()

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
  envelope.selection_range = { automation_start, automation_end }

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
    invoke=function() Octave(oct, true) end }
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Note to Octave " .. oct .. " without EditStep",
    invoke=function() Octave(oct, false) end }
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

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker PageUp Jump Lines",invoke=function() Jump(-1) end  }
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker PageDown Jump Lines",invoke=function() Jump(1) end  }
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

function ExpandSelectionReplicate()
  local s = renoise.song()
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
  renoise.app():show_status(string.format("Expanded and replicated selection from line %d to %d", sl, nl))
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

function ShrinkSelectionReplicate()
  local s = renoise.song()
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
    renoise.app():show_status(string.format("Shrank and replicated selection from line %d to %d", sl, nl))
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
function PlayCurrentLine()
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

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker 8 Play Current Line & Advance by EditStep",invoke=function() PlayCurrentLine() end}
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
-----------
-----------
-----------
local vb = renoise.ViewBuilder()
local dialog = nil  -- Declare dialog variable

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
  local song = renoise.song()
  for i = 1, #song.patterns do
    song.patterns[i]:clear()
  end
end

function instrumentsClear()
  local song = renoise.song()
  for i = 1, #song.instruments do
    song.instruments[i]:clear()
  end
end

function patternSequenceClear()
  local song = renoise.song()
  local sequence_length = #song.sequencer.pattern_sequence
  for i = sequence_length, 2, -1 do
    song.sequencer:delete_sequence_at(i)
  end
end

function instrumentMidiOutsClear()
  local song = renoise.song()
  for i = 1, #song.instruments do
    song.instruments[i].midi_output_properties.device_name = ""
  end
end

function instrumentSamplesClear()
  local song = renoise.song()
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
  local song = renoise.song()
  for i = 1, #song.instruments do
    song.instruments[i].plugin_properties:load_plugin("")
  end
end

function trackDspsClear()
  local song = renoise.song()
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
function show_new_song_dialog()
  -- Close any existing dialog before opening a new one
  if dialog and dialog.visible then
    dialog:close()
    clear_registered_views()  -- Ensure the reference is cleared
  end

  -- Resetting the ViewBuilder instance to ensure IDs are not reused
  vb = renoise.ViewBuilder()

  local dialog_content = vb:column {
    margin = 10,
    vb:text {text = "New Song ... with", font = "bold", align = "center"},
   
    -- "Set all to" switch   
    vb:space { height = 10 },
    vb:column {
      style = "border",
      margin = 10,
   vb:row {
      vb:text { text = "Set all to: ", width = 180 },
      vb:switch {
        id = "set_all_switch",
        items = { "Keep", "Clear" },
        value = 1,
        width = 100,
        notifier = handle_set_all_switch_change
      }
    },
    vb:space { height = 10 },
      vb:row {
        vb:text { text = "Patterns", width = 180 },
        vb:switch {
          id = "patterns_switch",
          items = { "Keep", "Clear" },
          value = patterns_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Patterns")
          end
        }
      },
      vb:row {
        vb:text { text = "Pattern Sequence", width = 180 },
        vb:switch {
          id = "pattern_sequence_switch",
          items = { "Keep", "Clear" },
          value = pattern_sequence_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Pattern Sequence")
          end
        }
      },
      vb:row {
        vb:text { text = "Instruments", width = 180 },
        vb:switch {
          id = "instruments_switch",
          items = { "Keep", "Clear" },
          value = instruments_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Instruments")
          end
        }
      },
      vb:row {
        vb:text { text = "Instrument Samples", width = 180 },
        vb:switch {
          id = "instrument_samples_switch",
          items = { "Keep", "Clear" },
          value = instrument_samples_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Instrument Samples")
          end
        }
      },
      vb:row {
        vb:text { text = "Instrument MIDI Outs", width = 180 },
        vb:switch {
          id = "instrument_midi_outs_switch",
          items = { "Keep", "Clear" },
          value = instrument_midi_outs_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Instrument MIDI Outs")
          end
        }
      },
      vb:row {
        vb:text { text = "Instrument Plugins", width = 180 },
        vb:switch {
          id = "instrument_plugins_switch",
          items = { "Keep", "Clear" },
          value = instrument_plugins_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Instrument Plugins")
          end
        }
      },
      vb:row {
        vb:text { text = "Track DSPs", width = 180 },
        vb:switch {
          id = "track_dsps_switch",
          items = { "Keep", "Clear" },
          value = track_dsps_state == "Keep" and 1 or 2,
          width = 100,
          notifier = function(value)
            handle_switch_change(value, "Track DSPs")
          end
        }
      },
      vb:space { height = 10 },
      vb:row {
        vb:button {text="OK", width=100, notifier=handle_ok_click()},
        vb:button {text="Cancel", width=100, notifier=handle_cancel_click(), color={1, 0, 0}}
      }
    }
  }

  -- Open the new dialog and assign it to the 'dialog' variable
  dialog = renoise.app():show_custom_dialog("New Song", dialog_content, my_ctrl_n_keyhandler_func)
end

function my_ctrl_n_keyhandler_func(dialog, key)

local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
else
    return key  -- Allow other key events to be handled as usual
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker CTRL-N New Song Dialog",invoke=function() show_new_song_dialog() end}
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------
-----------------------------------------------------

----ALT-U
function Deselect_All()
  local song = renoise.song()
  
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
  local song = renoise.song()
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

-- Add the keybinding for the ALT-Y action
renoise.tool():add_keybinding{name="Global:Paketti:Impulse Tracker ALT-Y Swap Block",invoke=PakettiImpulseTrackerSwapBlock}






-----------

-- Move to the next track, maintaining column type, with wrapping.
-- Move to the next track, maintaining column type, with wrapping.
function PakettiImpulseTrackerMoveForwardsTrackWrap()
  local song = renoise.song()
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
      song.selected_effect_column_index = 1
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Move to the previous track, maintaining column type, with wrapping.
function PakettiImpulseTrackerMoveBackwardsTrackWrap()
  local song = renoise.song()
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
      song.selected_effect_column_index = 1
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Move to the next track, maintaining column type, no wrapping.
function PakettiImpulseTrackerMoveForwardsTrack()
  local song = renoise.song()
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
      song.selected_effect_column_index = 1
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Move to the previous track, maintaining column type, no wrapping.
function PakettiImpulseTrackerMoveBackwardsTrack()
  local song = renoise.song()
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
      song.selected_effect_column_index = 1
    else
      song.selected_note_column_index = 1
    end
  else
    song.selected_effect_column_index = 1
  end
end

-- Add keybindings for Pattern Editor
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveForwardsTrackWrap}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveBackwardsTrackWrap}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel",invoke=PakettiImpulseTrackerMoveForwardsTrack}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel",invoke=PakettiImpulseTrackerMoveBackwardsTrack}

-- Add keybindings for Mixer
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveForwardsTrackWrap}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel (Wrap)",invoke=PakettiImpulseTrackerMoveBackwardsTrackWrap}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Right Move Forwards One Channel",invoke=PakettiImpulseTrackerMoveForwardsTrack}
renoise.tool():add_keybinding{name="Mixer:Paketti:Impulse Tracker Alt-Left Move Backwards One Channel",invoke=PakettiImpulseTrackerMoveBackwardsTrack}

-- Add MIDI mappings
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
local function alt_x_functionality()
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

  -- Get current track and pattern
  local track_index = s.selected_track_index
  local track = s:track(track_index)
  local pattern_track = s:pattern(s.selected_pattern_index):track(track_index)

  -- Retrieve visible columns
  local visible_note_columns = track.visible_note_columns
  local visible_effect_columns = track.visible_effect_columns

  -- Calculate effect column bounds for the selected area
  local effect_column_start = math.max(1, start_column - visible_note_columns)
  local effect_column_end = math.min(visible_effect_columns, end_column - visible_note_columns)

  -- Function to calculate interpolation values
  local function calculate_interpolation_values()
    local first_effect_line = pattern_track:line(start_line).effect_columns
    local last_effect_line = pattern_track:line(end_line).effect_columns
    local interpolated_values = {}

    for i = effect_column_start, effect_column_end do
      local first_value = tonumber(first_effect_line[i].amount_value)
      local last_value = tonumber(last_effect_line[i].amount_value)
      if first_value and last_value then
        interpolated_values[i] = {}
        for line_index = start_line, end_line do
          local t = (line_index - start_line) / (end_line - start_line)
          local interpolated_value = math.floor(first_value + t * (last_value - first_value))
          interpolated_values[i][line_index] = interpolated_value
        end
      end
    end

    return interpolated_values
  end

  -- Function to read current pattern content in selection
  local function read_current_content()
    local current_values = {}

    for i = effect_column_start, effect_column_end do
      current_values[i] = {}
      for line_index = start_line, end_line do
        local line = pattern_track:line(line_index)
        local effect_column = line:effect_column(i)
        current_values[i][line_index] = tonumber(effect_column.amount_value) or -1
      end
    end

    return current_values
  end

  -- Function to compare current content with calculated interpolation
  local function content_matches_interpolation(current_values, interpolated_values)
    for i = effect_column_start, effect_column_end do
      if interpolated_values[i] then
        for line_index = start_line, end_line do
          if current_values[i][line_index] ~= interpolated_values[i][line_index] then
            return false -- If any value differs, it's not a match
          end
        end
      end
    end
    return true -- All values match
  end

  -- Function to interpolate effect columns
  local function apply_interpolation(interpolated_values)
    local first_effect_line = pattern_track:line(start_line).effect_columns

    for i = effect_column_start, effect_column_end do
      if interpolated_values[i] then
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          line.effect_columns[i].number_value = first_effect_line[i].number_value
          line.effect_columns[i].amount_value = interpolated_values[i][line_index]
        end
      end
    end

    renoise.app():show_status("Effect column parameters interpolated.")
    already_interpolated = true -- Mark as interpolated
  end

  -- Function to wipe effect columns
  local function clear_effect_columns()
    for line_index = start_line, end_line do
      local line = pattern_track:line(line_index)
      if not line.is_empty then
        for effect_column_index = effect_column_start, effect_column_end do
          line:effect_column(effect_column_index):clear()
        end
      end
    end
    renoise.app():show_status("Effect columns cleared.")
    already_interpolated = false -- Reset flag after clearing
  end

  -- Main logic:
  -- 1. Read the current content in the selection
  -- 2. Calculate the interpolation
  -- 3. If the content matches the interpolation, wipe it; otherwise, interpolate

  local current_values = read_current_content()
  local interpolated_values = calculate_interpolation_values()

  if content_matches_interpolation(current_values, interpolated_values) then
    -- If the content matches the interpolation, wipe it
    clear_effect_columns()
  else
    -- Otherwise, apply the interpolation
    apply_interpolation(interpolated_values)
  end

  -- After the script is run, set focus back to the middle frame
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Add keybinding to trigger the functionality
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker ALT-X *2 (Interpolate&Clear Effect Columns)",
  invoke=function() alt_x_functionality() end}



