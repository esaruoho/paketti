-- Shortcuts 2nd / 3rds
--2nd Save Song bind
function saveSong()
  renoise.app():save_song()
  renoise.app():show_status("Song saved: " .. "'"..renoise.app().current_song.file_name.."'")
end

renoise.tool():add_keybinding{name="Global:Paketti:Save Song (2nd)",invoke=function() saveSong() end}

function RecordFollowToggle()
  local s = renoise.song()
  local t = renoise.song().transport
  local w = renoise.app().window
  
  -- If not in pattern or phrase editor, force pattern editor with edit+follow on
  if w.active_middle_frame ~= pe and w.active_middle_frame ~= phrase then
    w.active_middle_frame = pe
    t.edit_mode = true
    t.follow_player = true
    return
  end

  -- Handle phrase editor specific behavior
  if w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    if t.playing then
      if not t.follow_player then
        -- Playing but not following - enable everything
        t.follow_player = true
        t.edit_mode = true
        enable_phrase_follow()
      else
        -- Playing and following - disable everything
        t.follow_player = false
        t.edit_mode = false
        disable_phrase_follow()
      end
    end
    return
  end
  -- For all other cases, force pattern editor (middle_frame = 1)
  w.active_middle_frame = 1

    -- Check if follow is on, playing is on, but edit mode is off
    if t.follow_player and t.playing and not t.edit_mode then
      t.edit_mode = true
      return
    end

  if t.edit_mode == true and t.follow_player == true then 
    t.edit_mode = false 
    t.follow_player = false
    return 
  end
  
  if t.edit_mode == false and t.follow_player == false then
    t.edit_mode = true
    t.follow_player = true
  else
    t.edit_mode = false
    t.follow_player = false
  end
  
  w.active_middle_frame = 1
end

renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow Toggle (2nd)",invoke=function() RecordFollowToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow Toggle (3rd)",invoke=function() RecordFollowToggle() end}
renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow Toggle (4th)",invoke=function() RecordFollowToggle() end}
--------------------------------------------------------------------------------------------------------------------------------------------------------
--esa- 2nd keybind for Record Toggle ON/OFF with effect_column reading
previous_edit_step = nil

function RecordToggleg()
  local s = renoise.song()
  local t = renoise.song().transport

  -- Output the current edit_step
  print("Current edit_step: " .. t.edit_step)

  -- Toggle edit mode
  t.edit_mode = not t.edit_mode

  if t.edit_mode then
    -- If turning edit_mode on
    if s.selected_effect_column_index and s.selected_effect_column_index > 0 then
      -- Store current edit_step before changing it to 0
      previous_edit_step = t.edit_step
      print("Stored previous_edit_step: " .. previous_edit_step)
      t.edit_step = 0
    else
      -- If no effect column is selected, do nothing with edit_step
      print("No effect column selected")
    end
  else
    -- If turning edit_mode off
    if s.selected_effect_column_index and s.selected_effect_column_index > 0 then
      -- Restore previous edit_step if it was saved
      if previous_edit_step then
        t.edit_step = previous_edit_step
        print("Restored edit_step to: " .. t.edit_step)
        previous_edit_step = nil
      else
        print("No previous_edit_step saved")
      end
    else
      -- If no effect column is selected and we are in note column
      if not s.selected_effect_column_index or s.selected_effect_column_index == 0 then
        -- Restore previous edit_step if edit_step is 0 and previous_edit_step is not 0
        if t.edit_step == 0 and previous_edit_step and previous_edit_step ~= 0 then
          t.edit_step = previous_edit_step
          print("Restored edit_step to: " .. t.edit_step)
          previous_edit_step = nil
        end
      else
        print("No effect column selected and not in note column")
      end
    end
  end

 -- -- Toggle follow_player mode
--  t.follow_player = not t.follow_player
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle EditMode (2nd)",invoke=function() RecordToggleg() end}
renoise.tool():add_keybinding{name="Global:Paketti:Toggle EditMode (3rd)",invoke=function() RecordToggleg() end}
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function RecordFollowMetronomeToggle()
local w=renoise.app().window
local t=renoise.song().transport
w.active_middle_frame=1
w.lock_keyboard_focus=true

if t.edit_mode==false and t.follow_player==false and t.metronome_enabled==false then
   t.edit_mode=true
   t.follow_player=true
   t.metronome_enabled=true else
   t.edit_mode=false
   t.follow_player=false
   t.metronome_enabled=false end
if t.playing==false then t.playing=true t.metronome_enabled=true t.follow_player=true t.edit_mode=true end
end

renoise.tool():add_keybinding{name="Global:Paketti:Record+Follow+Metronome Toggle",invoke=function() RecordFollowMetronomeToggle() end}
--------------------------------------------------------------------------------------------------------------------------------------------------------
function FollowPatternToggle()
local a=renoise.app()
local t=renoise.song().transport
local w=renoise.app().window
local pe=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR 

  if t.follow_player==true and w.active_middle_frame==pe
then t.follow_player=false
else t.follow_player = true
     w.active_middle_frame=pe end end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Follow Pattern (2nd)",invoke=function() FollowPatternToggle() end}

-- 2nd Fullscreen toggle
function SecondFullscreen()
local w=renoise.app().window
  if w.fullscreen==true then w.fullscreen=false else w.fullscreen=true end end
renoise.tool():add_keybinding{name="Global:Paketti:Fullscreen (2nd)",invoke=function() SecondFullscreen() end}
------


-------
function KeybOctave(amount)
local t = renoise.song().transport
t.octave= (t.octave + amount) % 9
end

renoise.tool():add_keybinding{name="Global:Paketti:KeybOctave Up",invoke=function() KeybOctave(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:KeybOctave Down",invoke=function() KeybOctave(-1) end}
-----
function PakettiTranspose(steps)
  local song=renoise.song()
  local selection = renoise.song().selection_in_pattern
  local pattern = renoise.song().selected_pattern

  local start_track, end_track, start_line, end_line, start_column, end_column

  if selection ~= nil then
    start_track = selection.start_track
    end_track = selection.end_track
    start_line = selection.start_line
    end_line = selection.end_line
    start_column = selection.start_column
    end_column = selection.end_column
  else
    start_track = song.selected_track_index
    end_track = song.selected_track_index
    start_line = 1
    end_line = pattern.number_of_lines
    start_column = 1
    end_column = song.tracks[start_track].visible_note_columns
  end

  local is_valid_track = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      is_valid_track = true
      break
    end
  end

  if not is_valid_track then
    renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
    return
  end

  for track_index = start_track, end_track do
    local track = song:track(track_index)

    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local track_pattern = pattern:track(track_index)

for line_index = start_line, end_line do
  local line = track_pattern:line(line_index)

  -- Clamp the end column for this particular track
  local columns_to_end = math.min(end_column, track.visible_note_columns)

  for column_index = start_column, columns_to_end do
    local note_column = line:note_column(column_index)
    if not note_column.is_empty then
      if note_column.note_value < 120 then
        note_column.note_value = (note_column.note_value + steps) % 120
      end
    end
  end
end
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose Octave Up (Selection/Track)",invoke=function() PakettiTranspose(12) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose Octave Down (Selection/Track)",invoke=function() PakettiTranspose(-12) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose +1 (Selection/Track)",invoke=function() PakettiTranspose(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose -1 (Selection/Track)",invoke=function() PakettiTranspose(-1) end}
--------------
function PakettiTransposer(steps, selection_and_row)
  local song=renoise.song()
  local selection = renoise.song().selection_in_pattern
  local pattern = renoise.song().selected_pattern

  -- Process selection if it exists and selection_and_row is true
  if selection_and_row and selection then
    -- Handle selection case
    local start_track = selection.start_track
    local end_track = selection.end_track
    local start_line = selection.start_line
    local end_line = selection.end_line
    local start_column = selection.start_column
    local end_column = selection.end_column

    -- Check if any selected track is valid
    local is_valid_track = false
    for track_index = start_track, end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        is_valid_track = true
        break
      end
    end

    if not is_valid_track then
      renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
      return
    end

    -- Process selection
    for track_index = start_track, end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local track_pattern = pattern:track(track_index)
        for line_index = start_line, end_line do
          local line = track_pattern:line(line_index)
          local columns_to_end = math.min(end_column, track.visible_note_columns)
          for column_index = start_column, columns_to_end do
            local note_column = line:note_column(column_index)
            if not note_column.is_empty then
              if note_column.note_value < 120 then
                note_column.note_value = (note_column.note_value + steps) % 120
              end
            end
          end
        end
      end
    end
  end

  -- Always handle single cursor position case
  local track = song:track(song.selected_track_index)
  
  -- Check if current track is valid
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    if not selection then  -- Only show error if we haven't processed a selection
      renoise.app():show_status("The current track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
    end
    return
  end

  local track_pattern = pattern:track(song.selected_track_index)
  local line = track_pattern:line(song.selected_line_index)
  local note_column = line:note_column(song.selected_note_column_index)
  
  if not note_column.is_empty then
    if note_column.note_value < 120 then
      note_column.note_value = (note_column.note_value + steps) % 120
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row +03",invoke=function() PakettiTransposer(3, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row -03",invoke=function() PakettiTransposer(-3, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row +04",invoke=function() PakettiTransposer(4, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row -04",invoke=function() PakettiTransposer(-4, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row +07",invoke=function() PakettiTransposer(7, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row -07",invoke=function() PakettiTransposer(-7, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row +11",invoke=function() PakettiTransposer(11, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Row -11",invoke=function() PakettiTransposer(-11, false) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row +03",invoke=function() PakettiTransposer(3, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row -03",invoke=function() PakettiTransposer(-3, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row +04",invoke=function() PakettiTransposer(4, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row -04",invoke=function() PakettiTransposer(-4, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row +07",invoke=function() PakettiTransposer(7, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row -07",invoke=function() PakettiTransposer(-7, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row +11",invoke=function() PakettiTransposer(11, true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Transposer Selection/Row -11",invoke=function() PakettiTransposer(-11, true) end}

--------------
function PakettiTransposeNoteColumn(steps)
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local pattern = song.selected_pattern

  local start_track, end_track, start_line, end_line, start_column, end_column

  if selection ~= nil then
    start_track = selection.start_track
    end_track = selection.end_track
    start_line = selection.start_line
    end_line = selection.end_line
    start_column = selection.start_column
    end_column = selection.end_column
  else
    start_track = song.selected_track_index
    end_track = song.selected_track_index
    start_line = 1
    end_line = pattern.number_of_lines
    start_column = song.selected_note_column_index
    end_column = song.selected_note_column_index
  end

  for track_index = start_track, end_track do
    local track = song:track(track_index)
    local track_pattern = pattern:track(track_index)

    local first_column = (track_index == start_track) and start_column or 1
    local last_column = (track_index == end_track) and end_column or track.visible_note_columns

    for line_index = start_line, end_line do
      local line = track_pattern:line(line_index)

      for column_index = first_column, last_column do
        local note_column = line:note_column(column_index)
        if not note_column.is_empty then
          if note_column.note_value < 120 then
            note_column.note_value = (note_column.note_value + steps) % 120
          end
        end
      end
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose Octave Up Note Column (Selection/Note Column)",invoke=function() PakettiTransposeNoteColumn(12) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose Octave Down Note Column (Selection/Note Column)",invoke=function() PakettiTransposeNoteColumn(-12) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose +1 Note Column (Selection/Note Column)",invoke=function() PakettiTransposeNoteColumn(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Transpose -1 Note Column (Selection/Note Column)",invoke=function() PakettiTransposeNoteColumn(-1) end}

---------
function simpleplay()
if renoise.song().transport.playing 
then renoise.song().transport.playing=false
else renoise.song().transport.playing=true end end

renoise.tool():add_keybinding{name="Global:Paketti:Simple Play",invoke=function() simpleplay() end}
---------
function MetronomeOff()
if renoise.song().transport.metronome_enabled then renoise.song().transport.metronome_enabled = false else renoise.song().transport.metronome_enabled=true end end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Metronome On/Off",invoke=function() MetronomeOff() end}
---------
renoise.tool():add_keybinding{name="Global:Paketti:Song Details (Filename, BPM, LPB)",invoke=function() 
local filename = nil
if renoise.song().file_name == ("") then filename="(Not Yet Saved)" 
else filename = renoise.song().file_name
end
renoise.app():show_status("File: " .. filename .. ", BPM: " .. renoise.song().transport.bpm .. ", LPB: " .. renoise.song().transport.lpb) end}
-------------
-- RecordFollowOn / Off / ContourShuttle
function recOffFollowOn()
  renoise.song().transport.edit_mode=false
  renoise.song().transport.follow_player=true
  renoise.song().transport.playing=true
end

function recOnFollowOff()
renoise.song().transport.edit_mode=true
renoise.song().transport.follow_player=false
renoise.song().transport.wrapped_pattern_edit=true
renoise.app().window.active_middle_frame=1
end

renoise.tool():add_keybinding{name="Global:Paketti:Contour Shuttle Record Off, Follow On",invoke=function() recOffFollowOn() end}
renoise.tool():add_keybinding{name="Global:Paketti:Contour Shuttle Record On, Follow Off",invoke=function() recOnFollowOff() end}

function recordFollowFlip()
  local t = renoise.song().transport
  local w = renoise.app().window
  
  if t.edit_mode then
    t.edit_mode = false
    t.follow_player = true
  else
    t.edit_mode = true 
    t.follow_player = false
    w.active_middle_frame = 1
    w.lock_keyboard_focus = true
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Record & Follow Flip",invoke=function() recordFollowFlip() end}
renoise.tool():add_midi_mapping{name="Paketti:Record & Follow Flip x[Toggle]",invoke=function(message) if message:is_trigger() then recordFollowFlip() end end}

-------
renoise.tool():add_keybinding{name="Global:Paketti:Global Edit Mode Toggle",invoke=function() 
 if  renoise.song().transport.edit_mode then renoise.song().transport.edit_mode=false
else renoise.song().transport.edit_mode=true end
end}
---------------
function upby(number)
    local result = nil
    local pos = renoise.song().transport.edit_pos
    result = pos.line - number
    if result < 1 then
        result = 1
    else
        -- print(result)
    end
    pos.line = result
    renoise.song().transport.edit_pos = pos
    renoise.song().transport.playback_pos = pos
end
function upbyn(number)
if renoise.song().transport.playing == true then
    if renoise.song().transport.follow_player == false then return end
    upby(number)
    renoise.app().window.active_middle_frame = 1
    renoise.app().window.lock_keyboard_focus = true
    if renoise.song().tracks[renoise.song().selected_track_index].max_note_columns == 0 then return end
    if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then return
    else renoise.song().selected_note_column_index = 1 end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Rewind Playback by 4 steps",invoke=function() upbyn(4) end}
---------
function midi_imm()
 if renoise.app().window.active_middle_frame==renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR 
 then renoise.app().window.active_middle_frame=1 
 else renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR end
end

renoise.tool():add_keybinding{name="Global:Paketti:Pattern Editor <-> Midi Editor Switcher",invoke=function() midi_imm() end}
-----------
function selectNextTrack()
local nextTrack= renoise.song().selected_track_index+1
if nextTrack > #renoise.song().tracks then
nextTrack=1 else end
renoise.song().selected_track_index=nextTrack
end

function selectPreviousTrack()
local previousTrack= renoise.song().selected_track_index-1
if previousTrack < 1
then previousTrack=#renoise.song().tracks 
renoise.song().selected_track_index=previousTrack return else

if previousTrack > #renoise.song().tracks then
previousTrack=1 else end
end
renoise.song().selected_track_index=previousTrack
end

renoise.tool():add_keybinding{name="Global:Paketti:Select Track (Next)",invoke=function() selectNextTrack() end}
renoise.tool():add_keybinding{name="Global:Paketti:Select Track (Previous)",invoke=function() selectPreviousTrack() end}
---------
function createNewTrack()
renoise.song():insert_track_at(renoise.song().selected_track_index+1)
renoise.song().selected_track_index = renoise.song().selected_track_index+1
end
renoise.tool():add_keybinding{name="Global:Paketti:Insert Track (2nd)",invoke=function() createNewTrack() end}

---------
-- Define a table with the middle frame constants
local middle_frames = {
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR
}

-- Function to switch the middle frame based on the tab number
function sampleEditorTabSwitcher(tabNumber)
  if tabNumber >= 1 and tabNumber <= #middle_frames then
    renoise.app().window.active_middle_frame = middle_frames[tabNumber]
  else
    renoise.app():show_status("Invalid tab number: " .. tostring(tabNumber))
  end
end

-- Function to cycle through middle frames based on MIDI input value (0-127)
function cycleMiddleFrames(midiValue)
  local index = math.floor(midiValue / 127 * (#middle_frames - 1)) + 1
  renoise.app().window.active_middle_frame = middle_frames[index]
end

renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (01 Phrases)",invoke=function() sampleEditorTabSwitcher(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (02 Keyzones)",invoke=function() sampleEditorTabSwitcher(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (03 Waveform)",invoke=function() sampleEditorTabSwitcher(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (04 Modulation)",invoke=function() sampleEditorTabSwitcher(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (05 Effects)",invoke=function() sampleEditorTabSwitcher(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (06 Plugin Editor)",invoke=function() sampleEditorTabSwitcher(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Editor Tab Switcher (07 Midi Editor)",invoke=function() sampleEditorTabSwitcher(7) end}
renoise.tool():add_midi_mapping{name="Paketti:Cycle Sample Editor Tabs x[Knob]",invoke=function(midiMessage) cycleMiddleFrames(midiMessage.int_value) end}

----------
--2nd keybind for LoopBlock forward/backward
function loopblockback()
local t = renoise.song().transport
      t.loop_block_enabled=true
      t:loop_block_move_backwards()
      t.follow_player = true
end

function loopblockforward()
local t = renoise.song().transport
      t.loop_block_enabled=true
      t:loop_block_move_forwards()
      t.follow_player = true
end

renoise.tool():add_keybinding{name="Global:Paketti:Select LoopBlock Backwards (Previous)",invoke=function() loopblockback() end}
renoise.tool():add_keybinding{name="Global:Paketti:Select LoopBlock Forwards (Next)",invoke=function() loopblockforward() end}
---------
local function PakettiSetEditStep(value)
  renoise.song().transport.edit_step=value
end

-- Function to double the edit step with bounds checking
local function PakettiDoubleEditStep()
  local t = renoise.song().transport
  local current = t.edit_step
  
  -- Special case for 0 and 1
  if current == 0 then
    t.edit_step = 1
    renoise.app():show_status("EditStep set to 1")
    return
  end
  
  local doubled = current * 2
  if doubled > 64 then
    renoise.app():show_status("Cannot double EditStep: would exceed maximum of 64")
    return
  end
  
  t.edit_step = doubled
  renoise.app():show_status("EditStep doubled to " .. doubled)
end

-- Function to halve the edit step with bounds checking
local function PakettiHalveEditStep()
  local t = renoise.song().transport
  local current = t.edit_step
  
  -- Special case for 0 and 1
  if current <= 1 then
    t.edit_step = 1
    renoise.app():show_status("Cannot halve EditStep: already at minimum of 1")
    return
  end
  
  local halved = math.floor(current / 2)
  t.edit_step = halved
  renoise.app():show_status("EditStep halved to " .. halved)
end

-- Function to adjust edit step by a fixed amount with bounds checking
local function PakettiAdjustEditStep(amount)
  local t = renoise.song().transport
  local current = t.edit_step
  
  -- Special handling for 0
  if current == 0 then
    if amount > 0 then
      -- When increasing from 0, jump to the amount if possible
      local target = math.min(amount, 64)
      t.edit_step = target
      renoise.app():show_status("EditStep set to " .. target)
      return
    else
      -- When decreasing from 0, set to 1 first
      current = 1
    end
  end
  
  -- Special handling for 1 when increasing by 2, 4 or 8
  if current == 1 and (amount == 2 or amount == 4 or amount == 8) then
    local target = amount
    t.edit_step = target
    renoise.app():show_status("EditStep set to " .. target)
    return
  end
  
  -- Special handling for 2, 4 or 8 when decreasing by the same amount
  if (current == 2 and amount == -2) or 
     (current == 4 and amount == -4) or 
     (current == 8 and amount == -8) then
    t.edit_step = 1
    renoise.app():show_status("EditStep set to 1")
    return
  end
  
  local new_value = current + amount
  
  -- Bounds checking
  if new_value < 1 then
    renoise.app():show_status("Cannot decrease EditStep: already at minimum of 1")
    return
  elseif new_value > 64 then
    renoise.app():show_status("Cannot increase EditStep: would exceed maximum of 64")
    return
  end
  
  t.edit_step = new_value
  renoise.app():show_status("EditStep " .. (amount > 0 and "increased" or "decreased") .. " to " .. new_value)
end

renoise.tool():add_keybinding{name="Global:Paketti:Double EditStep",invoke=function() PakettiDoubleEditStep() end}
renoise.tool():add_keybinding{name="Global:Paketti:Halve EditStep",invoke=function() PakettiHalveEditStep() end}
renoise.tool():add_keybinding{name="Global:Paketti:Increase EditStep by 1",invoke=function() PakettiAdjustEditStep(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Decrease EditStep by 1",invoke=function() PakettiAdjustEditStep(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Increase EditStep by 2",invoke=function() PakettiAdjustEditStep(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Decrease EditStep by 2",invoke=function() PakettiAdjustEditStep(-2) end}
renoise.tool():add_keybinding{name="Global:Paketti:Increase EditStep by 4",invoke=function() PakettiAdjustEditStep(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Decrease EditStep by 4",invoke=function() PakettiAdjustEditStep(-4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Increase EditStep by 8",invoke=function() PakettiAdjustEditStep(8) end}
renoise.tool():add_keybinding{name="Global:Paketti:Decrease EditStep by 8",invoke=function() PakettiAdjustEditStep(-8) end}

for i=0,64 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set EditStep to " .. formatDigits(2,i),
    invoke=function() PakettiSetEditStep(i) end}
end

----
--esa- 2nd keybind for Record Toggle ON/OFF with effect_column reading
function RecordToggle()
 local a=renoise.app()
 local s=renoise.song()
 local t=renoise.song().transport
 local currentstep=t.edit_step
--if has notifier, remove notifier, if no notifier, add notifier
 if t.edit_mode then
    t.edit_mode=false
 if t.edit_step==0 then
    t.edit_step=1
 else return end 
 else
      t.edit_mode = true
   if s.selected_effect_column_index == 1 then t.edit_step=0
   elseif s.selected_effect_column_index == 0 then t.edit_step=currentstep return
   end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Record Toggle with EditStep Reading (2nd)",invoke=function() RecordToggle() end}

---------
function loadRecentlySavedSong()
renoise.app():load_song(renoise.app().recently_saved_song_files[1])
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
-----------
local function switch_upper_frame()
  local app_window=renoise.app().window

  -- Check if the upper frame is visible; make it visible if not
  if not app_window.upper_frame_is_visible then
    app_window.upper_frame_is_visible=true
  end

  -- Toggle the upper frame between Track Scopes and Master Spectrum
  if app_window.active_upper_frame==renoise.ApplicationWindow.UPPER_FRAME_TRACK_SCOPES then
    app_window.active_upper_frame=renoise.ApplicationWindow.UPPER_FRAME_MASTER_SPECTRUM
  else
    app_window.active_upper_frame=renoise.ApplicationWindow.UPPER_FRAME_TRACK_SCOPES
  end

  -- Provide user feedback
  renoise.app():show_status("Switched Upper Frame to "..app_window.active_upper_frame)
end

-- Run the function
renoise.tool():add_keybinding{name="Global:Paketti:Switch Upper Frame (Track Scopes/Master Spectrum)",invoke=function()
switch_upper_frame() end}

--------
function switchMiddleFrames()
local amf=renoise.app().window.active_middle_frame

local available_frames = {
  renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_MIXER,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR
}

local max_frame = #available_frames

if amf >= max_frame then
  renoise.app().window.active_middle_frame = 1
else
  renoise.app().window.active_middle_frame = amf + 1
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Switch Middle Frames",invoke=function() switchMiddleFrames() end}

function midi_imm()
  if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR then 
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  else  
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:F4 Shift Midi Immediately", invoke=function() midi_imm() end}

----
-- Function to duplicate the selected track and rename it
local function duplicate_selected_track()
  local song=renoise.song()
  local selected_track_index=song.selected_track_index
  local selected_track=song.tracks[selected_track_index]

  -- Prevent duplication of master, send, or group tracks
  if selected_track.type~=1 then -- 1 represents a sequencer track
    renoise.app():show_status("Cannot duplicate master, group, or send tracks.")
    return
  end

  -- Extract the name of the selected track
  local original_name=selected_track.name
  local new_name=original_name -- Default to original name if no number is found

  -- Check if the name ends with a number, e.g., "drum1"
  local base_name, number=original_name:match("^(.-)(%d+)$")
  if number then
    local incremented_number=tonumber(number)+1
    new_name=base_name..incremented_number
  else
    -- If no number exists, append " Copy" to the name
    new_name=original_name.." Copy"
  end

  -- Insert a new track and copy properties/settings
  local new_track_index=selected_track_index+1
  song:insert_track_at(new_track_index)
  local new_track=song.tracks[new_track_index]

  -- Copy basic properties
  new_track.name=new_name
  new_track.color=selected_track.color

  -- Copy visibility settings
  new_track.visible_note_columns=selected_track.visible_note_columns
  new_track.visible_effect_columns=selected_track.visible_effect_columns
  new_track.volume_column_visible=selected_track.volume_column_visible
  new_track.panning_column_visible=selected_track.panning_column_visible
  new_track.delay_column_visible=selected_track.delay_column_visible
  new_track.sample_effects_column_visible=selected_track.sample_effects_column_visible

  -- Copy pattern data from the original track to the new track
  for pattern_index,pattern in ipairs(song.patterns) do
    local original_pattern_track=pattern.tracks[selected_track_index]
    local new_pattern_track=pattern.tracks[new_track_index]
    new_pattern_track:copy_from(original_pattern_track)
  end

  -- Provide feedback to the user
  renoise.app():show_status("Duplicated track '"..original_name.."' as '"..new_name.."'.")
end

-- Trigger the function
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Track & Name",invoke=function() 
duplicate_selected_track() end}






function getSequencerSelectionLength()
  if not renoise.song() then
    print("No song is currently loaded.")
    return nil
  end

  local song=renoise.song()
  local selection = song.sequencer.selection_range
  
  if selection and #selection == 2 then
    local length = selection[2] - selection[1] + 1
    print("Sequence selection length: " .. length)
    print(renoise.song().sequencer.selection_range)
    oprint(renoise.song().sequencer.selection_range)
    rprint(renoise.song().sequencer.selection_range)
    return length
  else
    print("No sequence selection")
    return nil
  end
end

--getSequencerSelectionLength()
---






---------
local target_devices = {
  "Audio/Effects/Native/Delay",                -- [1]
  "Audio/Effects/Native/Multitap",            -- [2]
  "Audio/Effects/Native/mpReverb 2",          -- [3]
  "Audio/Effects/Native/Reverb",              -- [4]
  "Audio/Effects/Native/Convolver",           -- [5]
  "Audio/Effects/Native/Bus Compressor",      -- [6]
  "Audio/Effects/Native/Compressor",          -- [7]
  "Audio/Effects/Native/Gate 2",              -- [8]
  "Audio/Effects/Native/Maximizer",           -- [9]
  "Audio/Effects/Native/Analog Filter",       -- [10]
  "Audio/Effects/Native/Digital Filter",      -- [11]
  "Audio/Effects/Native/Comb Filter 2",       -- [12]
  "Audio/Effects/Native/EQ 5",                -- [13]
  "Audio/Effects/Native/EQ 10",               -- [14]
  "Audio/Effects/Native/Mixer EQ",            -- [15]
  "Audio/Effects/Native/Chorus 2",            -- [16]
  "Audio/Effects/Native/Flanger 2",           -- [17]
  "Audio/Effects/Native/Phaser 2",            -- [18]
  "Audio/Effects/Native/RingMod 2",           -- [19]
  "Audio/Effects/Native/LofiMat 2",           -- [20]
  "Audio/Effects/Native/Distortion 2",        -- [21]
  "Audio/Effects/Native/Cabinet Simulator",    -- [22]
  "Audio/Effects/Native/Exciter",             -- [23]
  "Audio/Effects/Native/Stereo Expander",     -- [24]
  "Audio/Effects/Native/DC Offset",           -- [25]
  "Audio/Effects/Native/Gainer",              -- [26]
  "Audio/Effects/Native/Repeater",            -- [27]
  "Audio/Effects/Native/Doofer",              -- [28]
  "Audio/Effects/Native/#Line Input",         -- [29]
  "Audio/Effects/Native/#Send",               -- [30]
  "Audio/Effects/Native/#Multiband Send",     -- [31]
  "Audio/Effects/Native/#Sidechain",          -- [32]
  "Audio/Effects/Native/*Instr. Macros",      -- [33]
  "Audio/Effects/Native/*Instr. Automation",  -- [34]
  "Audio/Effects/Native/*Instr. MIDI Control",-- [35]
  "Audio/Effects/Native/*Hydra",              -- [36]
  "Audio/Effects/Native/*Meta Mixer",         -- [37]
  "Audio/Effects/Native/*Formula",            -- [38]
  "Audio/Effects/Native/*XY Pad",             -- [39]
  "Audio/Effects/Native/*LFO",                -- [40]
  "Audio/Effects/Native/*Key Tracker",        -- [41]
  "Audio/Effects/Native/*Velocity Tracker",   -- [42]
  "Audio/Effects/Native/*Signal Follower"     -- [43]
}

-- Check Renoise API version and add Notepad device if supported
if renoise.API_VERSION >= 6.2 then
  table.insert(target_devices, "Audio/Effects/Native/Notepad")  -- [44]
end

-- Function to find and control a device
function control_device(device_path, action)
  local track = renoise.song().selected_track
  local device_found = false
  
  -- Search for the device in the track's device chain
  for _, device in ipairs(track.devices) do
    if device.device_path == device_path then
      device_found = true
      
      -- Handle different actions
      if action == "toggle" then
        device.is_active = not device.is_active
        renoise.app():show_status(string.format("%s: %s", device.name, device.is_active and "On" or "Off"))
      elseif action == "on" then
        device.is_active = true
        renoise.app():show_status(string.format("%s: On", device.name))
      elseif action == "off" then
        device.is_active = false
        renoise.app():show_status(string.format("%s: Off", device.name))
      end
      
      return true
    end
  end
  
  if not device_found then
    renoise.app():show_status(string.format("No %s in Selected Track", device_path:match("[^/]+$")))
  end
  return false
end

for i, device_path in ipairs(target_devices) do
  local device_name = device_path:match("[^/]+$")
  
  -- On keybinding
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Enable Device %02d (%s)", i, device_name),
    invoke=function()
      control_device(device_path, "on")
    end
  }
  
  -- Off keybinding
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Disable Device %02d (%s)", i, device_name),invoke=function() control_device(device_path, "off") end}
  renoise.tool():add_midi_mapping{name=string.format("Paketti:Toggle Device %02d (%s) x[Toggle]", i, device_name),invoke=function(message) if message:is_trigger() then control_device(device_path, "toggle") end end}
  renoise.tool():add_midi_mapping{name=string.format("Paketti:Hold Device %02d (%s) x[Button]", i, device_name),
    invoke=function(message)
      if message:is_abs_value() then
        control_device(device_path, message.int_value > 0 and "on" or "off")
      end
    end
  }
    
  renoise.tool():add_keybinding{name=string.format("Global:Paketti:Toggle Device %02d (%s)", i, device_name),
    invoke=function() control_device(device_path, "toggle") end}
end


------


-- Function to set output delay with bounds checking
function set_output_delay(delay_value, rename)
  local track = renoise.song().selected_track
  
  -- Check if track type allows output delay changes
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot change output delay on group, master or send tracks")
    return
  end
  
  -- Clamp value between -100 and 100
  delay_value = math.max(-100, math.min(100, delay_value))
  track.output_delay = delay_value
  
  -- Update track name if rename is true
  if rename then
    local prefix = delay_value > 0 and "+" or ""
    track.name = string.format("%s%dms", prefix, delay_value)
  end
  
  renoise.app():show_status(string.format("Output delay set to: %d", delay_value))
end

-- Function to nudge output delay
function nudge_output_delay(amount, rename)
  local track = renoise.song().selected_track
  
  -- Check if track type allows output delay changes
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot change output delay on group, master or send tracks")
    return
  end
  
  local current_delay = track.output_delay
  local new_delay = current_delay + amount
  
  if new_delay > 100 then
    renoise.app():show_status("At maximum positive delay, cannot go further")
    return
  elseif new_delay < -100 then
    renoise.app():show_status("At maximum negative delay, cannot go further")
    return
  end
  
  track.output_delay = new_delay
  
  -- Update track name if rename is true
  if rename then
    local prefix = new_delay > 0 and "+" or ""
    track.name = string.format("%s%dms", prefix, new_delay)
  end
  
  renoise.app():show_status(string.format("Output delay: %d", new_delay))
end

function reset_output_delay(rename)
  local track = renoise.song().selected_track
  
  -- Check if track type allows output delay changes
  if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    track.output_delay = 0
    if rename then
      track.name = "0ms"
    end
    renoise.app():show_status("Output delay reset to 0ms")
  else
    renoise.app():show_status("Cannot change output delay on group, master or send tracks")
  end
end

function reset_output_delayALL(rename)
  local song=renoise.song()
  local count = 0
  
  -- Reset delays for sequencer tracks only
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER and track.output_delay ~= 0 then
      track.output_delay = 0
      if rename then
        track.name = "0ms"
      end
      count = count + 1
    end
  end
  
  if count > 0 then
    renoise.app():show_status(string.format("Reset output delay to 0ms on %d tracks", count))
  else
    renoise.app():show_status("All track output delays were already at 0ms")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay Control x[Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      local value = message.int_value
      local delay_value
      
      if value == 64 then
        delay_value = 0
      elseif value > 64 then
        -- Map 65-127 to 1-100
        delay_value = math.floor((value - 64) * (100 / 63))
      else
        -- Map 0-63 to -100-(-1)
        delay_value = math.floor(value * (-100 / 63))
      end
      
      set_output_delay(delay_value, false)
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay Control (Rename) x[Knob]",
  invoke=function(message)
    if message:is_abs_value() then
      local value = message.int_value
      local delay_value
      
      if value == 64 then
        delay_value = 0
      elseif value > 64 then
        -- Map 65-127 to 1-100
        delay_value = math.floor((value - 64) * (100 / 63))
      else
        -- Map 0-63 to -100-(-1)
        delay_value = math.floor(value * (-100 / 63))
      end
      
      set_output_delay(delay_value, true)
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +01 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(1, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -01 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-1, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +05 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(5, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -05 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-5, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +10 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(10, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -10 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-10, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delay(false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms (ALL) x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delayALL(false) end end}

renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +01 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(1, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -01 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-1, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +05 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(5, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -05 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-5, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +10 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(10, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -10 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-10, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delay(true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms (ALL) (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delayALL(true) end end}

renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

--------
function mapsample()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample then
    renoise.app():show_status("No sample selected.")
    return
  end
  
  -- Map the sample to the entire keyboard range (C-0 to B-9)
  sample.sample_mapping.note_range = {0, 119}
  
  renoise.app():show_status("Sample mapped to all keyzones (C-0 to B-9).")
end



renoise.tool():add_keybinding{name="Sample Editor:Paketti:Map Sample to All Keyzones", invoke=function() mapsample() end}
renoise.tool():add_keybinding{name="Sample Keyzones:Paketti:Map Sample to All Keyzones", invoke=function() mapsample() end}
renoise.tool():add_midi_mapping{name="Paketti:Map Sample to All Keyzones", invoke=function(message) if message:is_trigger() then mapsample() end end}





------
function PlayCurrentLineAdvance(direction)
  local s=renoise.song()
  local num_lines=s.selected_pattern.number_of_lines
  local sli = s.selected_line_index
    
  renoise.song().transport.follow_player = false
  
  if renoise.API_VERSION >= 6.2 then
    -- v3.5 method: Clean, immediate line triggering
    s:trigger_pattern_line(sli)
  else
    -- Legacy method for older versions
    local t = s.transport
    t:start_at(sli)
    local start_time = os.clock()
    while (os.clock() - start_time < 0.05) do
      -- Minimum delay to allow the line to play correctly
    end
    t:stop()
  end
  
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
      s.selected_line_index = math.random(1, num_lines)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line&Step Forwards",invoke=function() PlayCurrentLineAdvance(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line&Step Backwards",invoke=function() PlayCurrentLineAdvance(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Play Current Line&Step Random",invoke=function() PlayCurrentLineAdvance("random") end}
