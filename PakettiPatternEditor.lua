-- Function to mute or unmute the selected note column
function muteUnmuteNoteColumn()
  -- Access the song object
  local s = renoise.song()
  -- Get the selected track and note column indices
  local sti = s.selected_track_index
  local snci = s.selected_note_column_index

  -- Check if a note column is selected
  if snci == 0 then
    return
  else
    -- Access the selected track
    local track = s:track(sti)
    -- Check if the note column is muted and toggle its state
    if track:column_is_muted(snci) then
      track:set_column_is_muted(snci, false)
    else
      track:set_column_is_muted(snci, true)
    end
  end
end

-- Write Note Offs to All Tracks for First Row of current Pattern
function PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern()
  local s = renoise.song()
  PakettiToggleNoteOffAllTracks(0, s.selected_pattern_index)
end

-- Write Note Offs to All Tracks for First Pattern of Song, First Row
function PakettiNoteOffs_AllTracks_FirstRow_FirstPattern()
  local s = renoise.song()
  local first_seq_pattern_index = s.sequencer.pattern_sequence[1]
  PakettiToggleNoteOffAllTracks(0, first_seq_pattern_index)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Mute/Unmute Note Column",invoke=function() muteUnmuteNoteColumn() end}

function voloff()
local s = renoise.song()
local currColumn = renoise.song().selected_note_column_index

if renoise.song().selected_effect_column == nil 
then renoise.song().selected_effect_column_index=1
else end

local efc = s.selected_effect_column
local currTrak=s.selected_track_index
local currLine=s.selected_line_index
local currPatt=s.selected_pattern_index

local ns=efc.number_string
local as=efc.amount_string
if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then 
  return
  else
 --     if s.selected_effect_column=="" then
if renoise.song().selected_effect_column.number_string=="0L" then
renoise.song().selected_effect_column.number_string ="00"
else
renoise.song().selected_effect_column.number_string ="0L"
renoise.song().selected_effect_column.amount_string ="00"
     end
end
renoise.song().selected_note_column_index = 1
end

---------------------------------------------------------------------------
-- Note Off on all columns within Group (#758)
---------------------------------------------------------------------------
function PakettiNoteOffAllColumnsInGroup()
  local song = renoise.song()
  local selected_track = song.selected_track
  local selected_track_index = song.selected_track_index
  local current_line = song.selected_line_index
  local pattern = song.selected_pattern
  local group_parent = selected_track.group_parent

  if not group_parent then
    renoise.app():show_status("Selected track is not part of any group")
    return
  end

  song:describe_undo("Note Off All Columns in Group")
  local count = 0
  for i = 1, #song.tracks do
    local track = song.tracks[i]
    if track.group_parent and track.group_parent.name == group_parent.name then
      local pattern_track = pattern:track(i)
      local line = pattern_track:line(current_line)
      for col_idx = 1, track.visible_note_columns do
        line.note_columns[col_idx].note_value = 120 -- NOTE_OFF
        count = count + 1
      end
    end
  end
  renoise.app():show_status("Note Off written to " .. count .. " columns in group '" .. group_parent.name .. "'")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Off All Columns in Group", invoke=function() PakettiNoteOffAllColumnsInGroup() end}
renoise.tool():add_midi_mapping{name="Paketti:Note Off All Columns in Group", invoke=function(message) if message:is_trigger() then PakettiNoteOffAllColumnsInGroup() end end}

---------------------------------------------------------------------------
-- Mute the note playing on the note column you're on (#765)
-- Scans upward to find the last played note, writes OFF at cursor.
---------------------------------------------------------------------------
function PakettiMutePlayingNote()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local col_index = song.selected_note_column_index
  local current_line = song.selected_line_index
  local pattern_track = pattern:track(track_index)

  if col_index == 0 then
    renoise.app():show_status("No note column selected")
    return
  end

  -- Check if current line already has a note (nothing to mute above)
  local current_note = pattern_track:line(current_line).note_columns[col_index]
  if current_note.note_value ~= 121 and current_note.note_value ~= 120 then
    renoise.app():show_status("Current line already has a note")
    return
  end

  -- Scan upward to find the last playing note
  local found_note = false
  for line = current_line - 1, 1, -1 do
    local note_col = pattern_track:line(line).note_columns[col_index]
    if note_col.note_value == 120 then
      -- Found a note-off before finding a note, nothing is playing
      renoise.app():show_status("No note is currently playing on this column")
      return
    elseif note_col.note_value ~= 121 then
      -- Found a note that's playing
      found_note = true
      break
    end
  end

  if not found_note then
    renoise.app():show_status("No note found above cursor in this column")
    return
  end

  song:describe_undo("Mute Playing Note")
  current_note.note_value = 120 -- NOTE_OFF
  renoise.app():show_status("Note Off inserted at line " .. current_line)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Mute Playing Note (Insert Note Off)", invoke=function() PakettiMutePlayingNote() end}
renoise.tool():add_midi_mapping{name="Paketti:Mute Playing Note (Insert Note Off)", invoke=function(message) if message:is_trigger() then PakettiMutePlayingNote() end end}

---------------------------------------------------------------------------
-- BPM Switcher: Write ZTxx to Master Track Effect Column (#525)
---------------------------------------------------------------------------
function PakettiBPMSwitcherWrite(bpm)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local current_line = song.selected_line_index

  -- Clamp BPM to valid ZT range (32-255)
  if bpm < 32 or bpm > 255 then
    renoise.app():show_status("BPM must be between 32 and 255 for ZTxx command")
    return
  end

  -- Find master track index
  local master_track_index = nil
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_MASTER then
      master_track_index = i
      break
    end
  end
  if not master_track_index then
    renoise.app():show_status("Master track not found")
    return
  end

  song:describe_undo("Write BPM to Master Track")
  -- Ensure at least 1 effect column is visible
  if song.tracks[master_track_index].visible_effect_columns < 1 then
    song.tracks[master_track_index].visible_effect_columns = 1
  end

  local effect_col = pattern:track(master_track_index):line(current_line).effect_columns[1]
  effect_col.number_string = "ZT"
  effect_col.amount_value = bpm
  renoise.app():show_status("BPM " .. bpm .. " written as ZT" .. string.format("%02X", bpm) .. " at line " .. current_line)
end

function PakettiBPMSwitcherDialog()
  local vb = renoise.ViewBuilder()
  local bpm_id = "bpm_field_" .. tostring(math.random(2, 30000))
  local current_bpm = math.floor(renoise.song().transport.bpm)

  local content = vb:column{
    margin = 10, spacing = 5,
    vb:text{text = "Enter BPM to write as ZTxx on Master Track:"},
    vb:valuebox{id = bpm_id, min = 32, max = 255, value = math.min(255, current_bpm)},
    vb:row{spacing = 5,
      vb:button{text = "Write", pressed = function()
        PakettiBPMSwitcherWrite(vb.views[bpm_id].value)
      end},
      vb:button{text = "Write & Close", pressed = function()
        PakettiBPMSwitcherWrite(vb.views[bpm_id].value)
        if paketti_bpm_switcher_dialog and paketti_bpm_switcher_dialog.visible then
          paketti_bpm_switcher_dialog:close()
        end
        paketti_bpm_switcher_dialog = nil
      end},
    }
  }

  if paketti_bpm_switcher_dialog and paketti_bpm_switcher_dialog.visible then
    paketti_bpm_switcher_dialog:close()
  end
  paketti_bpm_switcher_dialog = renoise.app():show_custom_dialog("BPM Switcher", content)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:BPM Switcher Dialog...", invoke=function() PakettiBPMSwitcherDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:BPM Switcher Dialog", invoke=function(message) if message:is_trigger() then PakettiBPMSwitcherDialog() end end}

---------------------------------------------------------------------------
-- Mute/Solo via L00 effect commands (#734)
-- Writes Lxx commands in effect columns for pattern-level muting/soloing.
---------------------------------------------------------------------------
function PakettiWriteTrackMuteL00()
  local song = renoise.song()
  local track = song.selected_track
  local track_index = song.selected_track_index
  local pattern = song.selected_pattern
  local current_line = song.selected_line_index

  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Only works on sequencer tracks")
    return
  end

  song:describe_undo("Write L00 Track Mute")
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  local effect_col = pattern:track(track_index):line(current_line).effect_columns[1]
  effect_col.number_string = "0L"
  effect_col.amount_string = "00"
  renoise.app():show_status("Track mute (0L00) written at line " .. current_line)
end

function PakettiWriteTrackUnmuteL80()
  local song = renoise.song()
  local track = song.selected_track
  local track_index = song.selected_track_index
  local pattern = song.selected_pattern
  local current_line = song.selected_line_index

  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Only works on sequencer tracks")
    return
  end

  song:describe_undo("Write L80 Track Unmute")
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  local effect_col = pattern:track(track_index):line(current_line).effect_columns[1]
  effect_col.number_string = "0L"
  effect_col.amount_string = "80"
  renoise.app():show_status("Track unmute (0L80) written at line " .. current_line)
end

function PakettiWriteTrackSoloL00()
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local pattern = song.selected_pattern
  local current_line = song.selected_line_index

  song:describe_undo("Write L00 Solo (Mute All Others)")
  for i = 1, #song.tracks do
    local track = song.tracks[i]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER and i ~= selected_track_index then
      if track.visible_effect_columns < 1 then
        track.visible_effect_columns = 1
      end
      local effect_col = pattern:track(i):line(current_line).effect_columns[1]
      effect_col.number_string = "0L"
      effect_col.amount_string = "00"
    end
  end
  renoise.app():show_status("Solo via 0L00 written on all other tracks at line " .. current_line)
end

function PakettiWriteTrackUnsoloL80()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local current_line = song.selected_line_index

  song:describe_undo("Write L80 Unsolo (Unmute All)")
  for i = 1, #song.tracks do
    local track = song.tracks[i]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      if track.visible_effect_columns < 1 then
        track.visible_effect_columns = 1
      end
      local effect_col = pattern:track(i):line(current_line).effect_columns[1]
      effect_col.number_string = "0L"
      effect_col.amount_string = "80"
    end
  end
  renoise.app():show_status("Unsolo via 0L80 written on all tracks at line " .. current_line)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Track Mute (0L00)", invoke=function() PakettiWriteTrackMuteL00() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Track Unmute (0L80)", invoke=function() PakettiWriteTrackUnmuteL80() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Track Solo via 0L00 (Mute All Others)", invoke=function() PakettiWriteTrackSoloL00() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Track Unsolo via 0L80 (Unmute All)", invoke=function() PakettiWriteTrackUnsoloL80() end}

renoise.tool():add_midi_mapping{name="Paketti:Write Track Mute (0L00)", invoke=function(message) if message:is_trigger() then PakettiWriteTrackMuteL00() end end}
renoise.tool():add_midi_mapping{name="Paketti:Write Track Unmute (0L80)", invoke=function(message) if message:is_trigger() then PakettiWriteTrackUnmuteL80() end end}
renoise.tool():add_midi_mapping{name="Paketti:Write Track Solo via 0L00", invoke=function(message) if message:is_trigger() then PakettiWriteTrackSoloL00() end end}
renoise.tool():add_midi_mapping{name="Paketti:Write Track Unsolo via 0L80", invoke=function(message) if message:is_trigger() then PakettiWriteTrackUnsoloL80() end end}

---------------
function PakettiPatternEditorApplyF8FollowPreference()
  local t = renoise.song().transport
  local pref = preferences and preferences.PakettiImpulseTrackerF8 and preferences.PakettiImpulseTrackerF8.value or 1
  if pref == 2 then
    t.follow_player = true
  elseif pref == 3 then
    t.follow_player = false
  else
    -- Do Nothing
  end
end

---------------
function RecordFollowOffPattern()
local t=renoise.song().transport
local w = renoise.app().window
--w.active_middle_frame = 1
if t.edit_mode == false then t.edit_mode=true else t.edit_mode=false end
if t.follow_player == false then return else t.follow_player=false end end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Record+Follow Off",invoke=function() RecordFollowOffPattern() end}

-- Set Delay +1 / -1 / +10 / -10 on current_row, display delay column
function delayInput(chg)
 local s=renoise.song()
 local d=s.selected_note_column.delay_value
 local nc=s.selected_note_column
 local currTrak=s.selected_track_index

 s.tracks[currTrak].delay_column_visible=true
 --nc.delay_value=(d+chg)
 --if nc.delay_value == 0 and chg < 0 then
  --move_up(chg)
 --elseif nc.delay_value == 255 and chg > 0 then
  --move_down(chg)
 --else
 -- nc.delay_value 
 nc.delay_value = math.max(0, math.min(255, d + chg))
 --end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Increase (+1)",invoke=function() delayInput(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Decrease (-1)",invoke=function() delayInput(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Increase (+10)",invoke=function() delayInput(10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Decrease (-10)",invoke=function() delayInput(-10) end}

-- Set Delay +1 / -1 / +10 / -10 on current phrase line, display delay column
function phraseDelayInput(chg)
  local s = renoise.song()
  
  -- Check if we have a phrase selected
  if s.selected_phrase == nil then
    renoise.app():show_status("Please select a phrase first.")
    return
  end
  
  local d = s.selected_phrase_note_column.delay_value
  local nc = s.selected_phrase_note_column
  
  -- Make delay column visible in the phrase
  s.selected_phrase.delay_column_visible = true
  
  --[[nc.delay_value=(d+chg)
  if nc.delay_value == 0 and chg < 0 then
   move_up(chg)
  elseif nc.delay_value == 255 and chg > 0 then
   move_down(chg)
  else
  end--]]
  
  -- Set the new delay value with bounds checking
  nc.delay_value = math.max(0, math.min(255, d + chg))
end


if renoise.API_VERSION >= 6.2 then
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Delay Column Increase (+1)",invoke=function() phraseDelayInput(1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Delay Column Decrease (-1)",invoke=function() phraseDelayInput(-1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Delay Column Increase (+10)",invoke=function() phraseDelayInput(10) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Delay Column Decrease (-10)",invoke=function() phraseDelayInput(-10) end}
end
----
--Quantize +1 / -1
function adjust_quantize(quant_delta)
  local t = renoise.song().transport
  local counted = nil
  counted=t.record_quantize_lines+quant_delta
  if counted == 0 then
  t.record_quantize_enabled=false return end
  
  if t.record_quantize_enabled==false and t.record_quantize_lines == 1 then
  t.record_quantize_lines = 1
  t.record_quantize_enabled=true
  return end  
    t.record_quantize_lines=math.max(1, math.min(32, t.record_quantize_lines + quant_delta))
    t.record_quantize_enabled=true
renoise.app():show_status("Record Quantize Lines : " .. t.record_quantize_lines)
end
renoise.tool():add_keybinding{name="Global:Paketti:Quantization Decrease (-1)",invoke=function() adjust_quantize(-1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Quantization Increase (+1)",invoke=function() adjust_quantize(1, 0) end}
-------
-- +1/-1 on Metronome LPB and Metronome BPB (loads of help from dblue)
function adjust_metronome(lpb_delta, bpb_delta)
  -- Local reference to transport
  local t = renoise.song().transport
  t.metronome_lines_per_beat = math.max(1, math.min(16, t.metronome_lines_per_beat + lpb_delta))
  t.metronome_beats_per_bar = math.max(1, math.min(16, t.metronome_beats_per_bar + bpb_delta))
-- Show status
  t.metronome_enabled = true
  renoise.app():show_status("Metronome LPB: " .. t.metronome_lines_per_beat .. " BPB : " .. t.metronome_beats_per_bar) end

--dblue modified to be lpb/tpl  
function adjust_lpb_bpb(lpb_delta, tpl_delta)
  local t = renoise.song().transport
  t.lpb = math.max(1, math.min(256, t.lpb + lpb_delta))
  t.tpl = math.max(1, math.min(16, t.tpl + tpl_delta))
--  renoise.song().transport.metronome_enabled = true
  renoise.app():show_status("LPB: " .. t.lpb .. " TPL : " .. t.tpl) end

renoise.tool():add_keybinding{name="Global:Paketti:Metronome LPB Decrease (-1)",invoke=function() adjust_metronome(-1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Metronome LPB Increase (+1)",invoke=function() adjust_metronome(1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Metronome BPB Decrease (-1)",invoke=function() adjust_metronome(0, -1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Metronome BPB Increase (+1)",invoke=function() adjust_metronome(0, 1) end}
renoise.tool():add_keybinding{name="Global:Paketti:LPB Decrease (-1)",invoke=function() adjust_lpb_bpb(-1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:LPB Increase (+1)",invoke=function() adjust_lpb_bpb(1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:TPL Decrease (-1)",invoke=function() adjust_lpb_bpb(0, -1) end}
renoise.tool():add_keybinding{name="Global:Paketti:TPL Increase (+1)",invoke=function() adjust_lpb_bpb(0, 1) end}

---------------------------
function soloKey()
local s=renoise.song()
  s.tracks[renoise.song().selected_track_index]:solo()
    if s.transport.playing==false then renoise.song().transport.playing=true end
  s.transport.follow_player=true  
    if renoise.app().window.active_middle_frame~=1 then renoise.app().window.active_middle_frame=1 end
end

renoise.tool():add_keybinding{name="Global:Paketti:Solo Channel + Play + Follow",invoke=function() soloKey() end}

--This script uncollapses everything (all tracks, master, send trax)
function Uncollapser()
local send_track_counter=nil
local s=renoise.song()

   send_track_counter=s.sequencer_track_count+1+s.send_track_count

   for i=1,send_track_counter do
   s.tracks[i].collapsed=false
   end
end

--This script collapses everything (all tracks, master, send trax)
function Collapser()
local send_track_counter=nil
local s=renoise.song()
   send_track_counter=s.sequencer_track_count+1+s.send_track_count

   for i=1,send_track_counter do
   s.tracks[i].collapsed=true end
end


renoise.tool():add_keybinding{name="Global:Paketti:Uncollapse All Tracks",invoke=function() Uncollapser() end}
renoise.tool():add_keybinding{name="Global:Paketti:Collapse All Tracks",invoke=function() Collapser() end}

-- Toggle CapsLock Note Off "===" On / Off.
function CapsLok(use_editstep)
  local s = renoise.song()
  local currLine = s.selected_line_index
  local currPatt = s.selected_pattern_index
  local currTrak = s.selected_track_index
  local currPhra = s.selected_phrase_index
  local currInst = s.selected_instrument_index
  local editstep = s.transport.edit_step

  -- Check if the active middle frame is the Pattern Editor (1)
  if renoise.app().window.active_middle_frame == 1 then
    if s.selected_note_column_index == nil or s.selected_note_column_index == 0 then
      return
    else
      local noteColumn = s.patterns[currPatt].tracks[currTrak].lines[currLine].note_columns[s.selected_note_column_index]
      if noteColumn.note_string == "OFF" then
        noteColumn.note_string = ""
      else
        noteColumn.note_string = "OFF"
        noteColumn.instrument_value = 255  -- Clear instrument column
      end

      -- Handle edit step movement in pattern
      if use_editstep then
        local pattern_lines = s.patterns[currPatt].number_of_lines
        local new_line = currLine + editstep
        
        -- Handle wrapping
        if new_line > pattern_lines then
          new_line = ((new_line - 1) % pattern_lines) + 1
        end
        
        s.selected_line_index = new_line
      end
    end
  
  -- Check if the active middle frame is the Phrase Editor
  elseif renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    if renoise.API_VERSION < 6.2 then
      renoise.app():show_status("This feature requires Renoise API version 6.2 or higher.")
      return
    end

    if s.selected_phrase == nil then
      renoise.app():show_status("Please select a phrase first, doing nothing.")
      return
    else
      local phra = s.selected_phrase
      local noteColumn = phra.lines[s.selected_phrase_line_index].note_columns[s.selected_phrase_note_column_index]
      
      if noteColumn.note_string == "OFF" then
        noteColumn.note_string = ""
      else
        noteColumn.note_string = "OFF"
        noteColumn.instrument_value = 255  -- Clear instrument column
      end

      -- Handle edit step movement in phrase
      if use_editstep then
        local phrase_lines = phra.number_of_lines
        local new_line = s.selected_phrase_line_index + editstep
        
        -- Handle wrapping
        if new_line > phrase_lines then
          new_line = ((new_line - 1) % phrase_lines) + 1
        end
        
        s.selected_phrase_line_index = new_line
      end
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:KapsLock Note Off (No Step)",invoke=function() CapsLok(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:KapsLock Note Off (With Step)",invoke=function() CapsLok(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:KapsLock Note Off (No Step)",invoke=function() CapsLok(false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:KapsLock Note Off (With Step)",invoke=function() CapsLok(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:KapsLock CapsLock Caps Lock Note Off",invoke=function() CapsLok() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:KapsLock CapsLock Caps Lock Note Off",invoke=function() CapsLok() end}

renoise.tool():add_midi_mapping{name="Paketti:KapsLock Note Off (No Step) x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      CapsLok(false)
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:KapsLock Note Off (With Step) x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      CapsLok(true)
    end
  end
}

renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:KapsLock Note Off x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      CapsLok()
    end
  end
}

renoise.tool():add_midi_mapping{name="Phrase Editor:Paketti:KapsLock Note Off x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      CapsLok()
    end
  end
}

-------
function CleverNoteOff(mode)
  local s = renoise.song()
  local pattern = s:pattern(s.selected_pattern_index)
  local track = pattern:track(s.selected_track_index)
  local note_columns = s:track(s.selected_track_index).visible_note_columns
  
  -- Store note positions per column
  local notes_by_column = {}
  for col = 1, note_columns do
    notes_by_column[col] = {}
    for line_index = 1, pattern.number_of_lines do
      local note = track:line(line_index):note_column(col)
      if not note.is_empty and note.note_string ~= "OFF" then
        table.insert(notes_by_column[col], {line = line_index})
      end
    end
  end

  -- Process each column independently
  for col = 1, note_columns do
    local notes = notes_by_column[col]
    
    -- Process each note in this column
    for i = 1, #notes do
      local current_note = notes[i]
      local next_note = notes[i + 1]
      local note_off_line = nil
      
      if mode == "RightAfter" then
        -- Place Note Off in the next line after the note, only if that line is empty
        local next_line = current_note.line + 1
        if next_line <= pattern.number_of_lines then
          local next_line_note = track:line(next_line):note_column(col)
          if next_line_note.is_empty then
            note_off_line = next_line
          end
        end
        
      elseif mode == "RightBefore" then
        -- Place Note Off right before the next note (if it exists and there's space)
        if next_note then
          if next_note.line - current_note.line > 1 then  -- Ensure there's at least one line gap
            local before_next = next_note.line - 1
            local before_note = track:line(before_next):note_column(col)
            if before_note.is_empty then
              note_off_line = before_next
            end
          end
        end
        
      elseif mode == "HalfBefore" then
        -- Place Note Off halfway between current note and next note
        if next_note then
          if next_note.line - current_note.line > 1 then  -- Ensure there's at least one line gap
            local half_point = current_note.line + math.floor((next_note.line - current_note.line) / 2)
            local half_note = track:line(half_point):note_column(col)
            if half_note.is_empty then
              note_off_line = half_point
            end
          end
        end
      end
      
      -- Insert the Note Off if we have a valid line
      if note_off_line then
        local note_column = track:line(note_off_line):note_column(col)
        note_column.note_string = "OFF"
        note_column.instrument_value = 255  -- Clear instrument column
      end
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clever Note Off Right After",invoke=function() CleverNoteOff("RightAfter") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clever Note Off Right Before",invoke=function() CleverNoteOff("RightBefore") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clever Note Off Half Before",invoke=function() CleverNoteOff("HalfBefore") end}







----------------------------------------------------------------------------------------------------
function ptnLength(number) local rs=renoise.song() rs.patterns[rs.selected_pattern_index].number_of_lines=number end

function phrLength(number) local s=renoise.song() 
renoise.song().instruments[renoise.song().selected_instrument_index].phrases[renoise.song().selected_phrase_index].number_of_lines=number end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 001 (001)",invoke=function() ptnLength(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 004 (004)",invoke=function() ptnLength(4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 006 (006)",invoke=function() ptnLength(6) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 008 (008)",invoke=function() ptnLength(8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 012 (00C)",invoke=function() ptnLength(12) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 016 (010)",invoke=function() ptnLength(16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 024 (018)",invoke=function() ptnLength(24) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 032 (020)",invoke=function() ptnLength(32) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 048 (030)",invoke=function() ptnLength(48) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 064 (040)",invoke=function() ptnLength(64) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 096 (060)",invoke=function() ptnLength(96) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 128 (080)",invoke=function() ptnLength(128) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 192 (0C0)",invoke=function() ptnLength(192) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 256 (100)",invoke=function() ptnLength(256) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 384 (180)",invoke=function() ptnLength(384) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to 512 (200)",invoke=function() ptnLength(512) end}

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 001 (001)",invoke=function() phrLength(1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 004 (004)",invoke=function() phrLength(4) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 006 (006)",invoke=function() phrLength(6) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 008 (008)",invoke=function() phrLength(8) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 012 (00C)",invoke=function() phrLength(12) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 016 (010)",invoke=function() phrLength(16) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 024 (018)",invoke=function() phrLength(24) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 032 (020)",invoke=function() phrLength(32) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 048 (030)",invoke=function() phrLength(48) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 064 (040)",invoke=function() phrLength(64) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 096 (060)",invoke=function() phrLength(96) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 128 (080)",invoke=function() phrLength(128) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 192 (0C0)",invoke=function() phrLength(192) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 256 (100)",invoke=function() phrLength(256) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 384 (180)",invoke=function() phrLength(384) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase Length to 512 (200)",invoke=function() phrLength(512) end}

renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 001 (001)",invoke=function() ptnLength(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 004 (004)",invoke=function() ptnLength(4) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 006 (006)",invoke=function() ptnLength(6) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 008 (008)",invoke=function() ptnLength(8) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 012 (00C)",invoke=function() ptnLength(12) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 016 (010)",invoke=function() ptnLength(16) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 024 (018)",invoke=function() ptnLength(24) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 032 (020)",invoke=function() ptnLength(32) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 048 (030)",invoke=function() ptnLength(48) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 064 (040)",invoke=function() ptnLength(64) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 096 (060)",invoke=function() ptnLength(96) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 128 (080)",invoke=function() ptnLength(128) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 192 (0C0)",invoke=function() ptnLength(192) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 256 (100)",invoke=function() ptnLength(256) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 384 (180)",invoke=function() ptnLength(384) end}
renoise.tool():add_midi_mapping{name="Paketti:Set Pattern Length to 512 (200)",invoke=function() ptnLength(512) end}
--------------
function efxwrite(effect, x, y)
  local s = renoise.song()
  local counter = nil 
  local currentamount = nil
  local old_x = nil
  local old_y = nil
  local new_x = nil
  local new_y = nil

  if s.selection_in_pattern == nil then
    -- If no selection is set, output to the row that the cursor is on
    local current_line_index = s.selected_line_index
    
    if s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1).amount_value == 0 and (x < 0 or y < 0) then
      s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1).number_string = ""
    else
      s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1).number_string = effect
      old_y = s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1).amount_value % 16
      old_x = math.floor(s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1).amount_value / 16)
      
      new_x = old_x + x
      new_y = old_y + y
      
      if new_x > 15 then new_x = 15 end
      if new_y > 15 then new_y = 15 end
      if new_y < 1 then new_y = 0 end
      if new_x < 1 then new_x = 0 end
      
      counter = (16 * new_x) + new_y
      s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1).amount_value = counter
    end
  else
    -- If a selection is set, process the selection range
    for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
      if s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(i):effect_column(1).amount_value == 0 and (x < 0 or y < 0) then
        s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(i):effect_column(1).number_string = ""
      else
        s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(i):effect_column(1).number_string = effect
        old_y = s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(i):effect_column(1).amount_value % 16
        old_x = math.floor(s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(i):effect_column(1).amount_value / 16)
        
        new_x = old_x + x
        new_y = old_y + y
        
        if new_x > 15 then new_x = 15 end
        if new_y > 15 then new_y = 15 end
        if new_y < 1 then new_y = 0 end
        if new_x < 1 then new_x = 0 end
        
        counter = (16 * new_x) + new_y
        s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(i):effect_column(1).amount_value = counter
      end
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column AXx Arp Amount Xx (-1)",invoke=function() efxwrite("0A",-1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column AXx Arp Amount Xx (+1)",invoke=function() efxwrite("0A",1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column AxY Arp Amount xY (-1)",invoke=function() efxwrite("0A",0,-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column AxY Arp Amount xY (+1)",invoke=function() efxwrite("0A",0,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column VXy Vibrato Amount Xy (-1)",invoke=function() efxwrite("0V",-1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column VXy Vibrato Amount Xy (+1)",invoke=function() efxwrite("0V",1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column VxY Vibrato Amount xY (-1)",invoke=function() efxwrite("0V",0,-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column VxY Vibrato Amount xY (+1)",invoke=function() efxwrite("0V",0,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column TXy Tremolo Amount Xy (-1)",invoke=function() efxwrite("0T",-1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column TXy Tremolo Amount Xy (+1)",invoke=function() efxwrite("0T",1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column TxY Tremolo Amount xY (-1)",invoke=function() efxwrite("0T",0,-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column TxY Tremolo Amount xY (+1)",invoke=function() efxwrite("0T",0,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column RXy Retrig Amount Xy (-1)",invoke=function() efxwrite("0R",-1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column RXy Retrig Amount Xy (+1)",invoke=function() efxwrite("0R",1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column RxY Retrig Amount xY (-1)",invoke=function() efxwrite("0R",0,-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column RxY Retrig Amount xY (+1)",invoke=function() efxwrite("0R",0,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column CXy Cut Volume Amount Xy (-1)",invoke=function() efxwrite("0C",-1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column CXy Cut Volume Amount Xy (+1)",invoke=function() efxwrite("0C",1,0) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column CxY Cut Volume Amount xY (-1)",invoke=function() efxwrite("0C",0,-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column CxY Cut Volume Amount xY (+1)",invoke=function() efxwrite("0C",0,1) end}
-----------
function GlobalLPB(number)
renoise.song().transport.lpb=number end

for glpb=1,16 do
    renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to " .. formatDigits(3,glpb),invoke=function() GlobalLPB(glpb) end}
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to 024",invoke=function() GlobalLPB(24) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to 032",invoke=function() GlobalLPB(32) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to 048",invoke=function() GlobalLPB(48) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to 064",invoke=function() GlobalLPB(64) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to 128",invoke=function() GlobalLPB(128) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Global LPB to 256",invoke=function() GlobalLPB(256) end}

function PhraseLPB(number)
renoise.song().instruments[renoise.song().selected_instrument_index].phrases[renoise.song().selected_phrase_index].lpb=number end

for plpb=1,16 do
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to " .. formatDigits(3,plpb),invoke=function() PhraseLPB(plpb) end}
end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to 024",invoke=function() PhraseLPB(24) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to 032",invoke=function() PhraseLPB(32) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to 048",invoke=function() PhraseLPB(48) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to 064",invoke=function() PhraseLPB(64) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to 128",invoke=function() PhraseLPB(128) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Phrase LPB to 256",invoke=function() PhraseLPB(256) end}
----------------------------------------------------------------------------------------------------
function computerKeyboardVolChange(number)
local s=renoise.song();if s.transport.keyboard_velocity_enabled==false then s.transport.keyboard_velocity_enabled=true end
local addtovelocity=nil
addtovelocity=s.transport.keyboard_velocity+number
if addtovelocity > 127 then addtovelocity=127 end
if addtovelocity < 1 then s.transport.keyboard_velocity_enabled=false return end
s.transport.keyboard_velocity=addtovelocity
end

renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (-1)",invoke=function() computerKeyboardVolChange(-1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (+1)",invoke=function() computerKeyboardVolChange(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (-10)",invoke=function() computerKeyboardVolChange(-10) end}
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (+10)",invoke=function() computerKeyboardVolChange(10) end}

function adjustKeyboardVelocityMultiplier(isDouble)
  local s = renoise.song()
  if s.transport.keyboard_velocity_enabled == false then 
    s.transport.keyboard_velocity_enabled = true 
  end
  
  local multiplier = isDouble and 2 or 0.5
  local newVelocity = math.floor(s.transport.keyboard_velocity * multiplier)
  
  if newVelocity < 1 then
    s.transport.keyboard_velocity_enabled = false
    return
  end
  
  s.transport.keyboard_velocity = math.min(127, newVelocity)
  renoise.app():show_status("Keyboard Velocity: " .. s.transport.keyboard_velocity)
end

renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (Halve)",invoke=function() adjustKeyboardVelocityMultiplier(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Computer Keyboard Velocity (Double)",invoke=function() adjustKeyboardVelocityMultiplier(true) end}
renoise.tool():add_midi_mapping{name="Paketti:Computer Keyboard Velocity (Halve)",invoke=function(message) if message:is_trigger() then adjustKeyboardVelocityMultiplier(false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Computer Keyboard Velocity (Double)",invoke=function(message) if message:is_trigger() then adjustKeyboardVelocityMultiplier(true) end end}



local start_velocity = 10
local end_velocity = 70
local step = 10

for velocity = start_velocity, end_velocity, step do
  local velocity_hex = formatDigits(2,velocity)
  renoise.tool():add_keybinding{name="Global:Paketti:Set Keyboard Velocity to " .. velocity_hex,invoke=function() renoise.song().transport.keyboard_velocity=velocity renoise.app():show_status("Keyboard Velocity set to: " .. velocity_hex) end}
  renoise.tool():add_midi_mapping{name="Paketti:Set Keyboard Velocity to " .. velocity_hex,invoke=function(message) if message:is_trigger() then renoise.song().transport.keyboard_velocity=velocity renoise.app():show_status("Keyboard Velocity set to: " .. velocity_hex) end end}
end



renoise.tool():add_keybinding{name="Global:Paketti:Toggle Keyboard Velocity",invoke=function() renoise.song().transport.keyboard_velocity_enabled=not renoise.song().transport.keyboard_velocity_enabled renoise.app():show_status("Keyboard Velocity " .. (renoise.song().transport.keyboard_velocity_enabled and "Enabled" or "Disabled")) end}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Keyboard Velocity",invoke=function(message) if message:is_trigger() then renoise.song().transport.keyboard_velocity_enabled=not renoise.song().transport.keyboard_velocity_enabled renoise.app():show_status("Keyboard Velocity " .. (renoise.song().transport.keyboard_velocity_enabled and "Enabled" or "Disabled")) end end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Keyboard Velocity to 7F (Max)",invoke=function() renoise.song().transport.keyboard_velocity=127 renoise.app():show_status("Keyboard Velocity set to: 7F.") end}
renoise.tool():add_midi_mapping{name="Paketti:Set Keyboard Velocity to 7F (Max)",invoke=function(message) if message:is_trigger() then renoise.song().transport.keyboard_velocity=127 renoise.app():show_status("Keyboard Velocity set to: 7F") end end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Keyboard Velocity to 00 (Min)",invoke=function() renoise.song().transport.keyboard_velocity=0 renoise.app():show_status("Keyboard Velocity set to: 0.") end}
renoise.tool():add_midi_mapping{name="Paketti:Set Keyboard Velocity to 00 (Min)",invoke=function(message) if message:is_trigger() then renoise.song().transport.keyboard_velocity=0 renoise.app():show_status("Keyboard Velocity set to: 0") end end}


--BPM +1 / -1 / +0.1 / -0.1 (2024 update)
function adjust_bpm(bpm_delta)
  local t = renoise.song().transport
  t.bpm = math.max(20, math.min(999, t.bpm + bpm_delta))
renoise.app():show_status("BPM: " .. t.bpm)
end

renoise.tool():add_keybinding{name="Global:Paketti:BPM Decrease (-1)",invoke=function() adjust_bpm(-1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Increase (+1)",invoke=function() adjust_bpm(1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Decrease (-0.1)",invoke=function() adjust_bpm(-0.1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Increase (+0.1)",invoke=function() adjust_bpm(0.1, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Decrease (-0.5)",invoke=function() adjust_bpm(-0.5, 0) end}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Increase (+0.5)",invoke=function() adjust_bpm(0.5, 0) end}

renoise.tool():add_midi_mapping{name="Paketti:BPM Decrease (-1)",invoke=function(message) if message:is_trigger() then adjust_bpm(-1, 0) end end}
renoise.tool():add_midi_mapping{name="Paketti:BPM Increase (+1)",invoke=function(message) if message:is_trigger() then adjust_bpm(1, 0) end end}
renoise.tool():add_midi_mapping{name="Paketti:BPM Decrease (-0.1)",invoke=function(message) if message:is_trigger() then adjust_bpm(-0.1, 0) end end}
renoise.tool():add_midi_mapping{name="Paketti:BPM Increase (+0.1)",invoke=function(message) if message:is_trigger() then adjust_bpm(0.1, 0) end end}
renoise.tool():add_midi_mapping{name="Paketti:BPM Decrease (-0.5)",invoke=function(message) if message:is_trigger() then adjust_bpm(-0.5, 0) end end}
renoise.tool():add_midi_mapping{name="Paketti:BPM Increase (+0.5)",invoke=function(message) if message:is_trigger() then adjust_bpm(0.5, 0) end end}



function pakettiPatternDoubler()
  -- Retrieve the current song object
  local song=renoise.song()
  
  -- Get the currently selected pattern index
  local pattern_index = song.selected_pattern_index
  
  -- Get the number of lines in the selected pattern
  local old_patternlength = song.selected_pattern.number_of_lines
  
  -- Calculate the new pattern length by doubling the old length
  local new_patternlength = old_patternlength * 2
  
  -- Get the currently selected line index
  local current_line = song.selected_line_index

  -- Check if the new pattern length is within the allowed limit
  if new_patternlength <= renoise.Pattern.MAX_NUMBER_OF_LINES then
    -- Set the new pattern length
    song.selected_pattern.number_of_lines = new_patternlength

    -- Loop through each track in the selected pattern
    for track_index, pattern_track in ipairs(song.selected_pattern.tracks) do
      -- Copy notes in the pattern
      if not pattern_track.is_empty then
        for line_index = 1, old_patternlength do
          -- Copy each line to the corresponding new position
          local line = pattern_track:line(line_index)
          local new_line = pattern_track:line(line_index + old_patternlength)
          new_line:copy_from(line)
        end
      end

      -- Handle automation duplication
      local track_automations = song.patterns[pattern_index].tracks[track_index].automation
      for param, automation in pairs(track_automations) do
        local points = automation.points
        local new_points = {} -- Store new points to be added

        -- Collect new points to add, adjusting time by old pattern length
        for _, point in ipairs(points) do
          local new_time = point.time + old_patternlength
          -- Ensure new time does not exceed the new pattern length
          if new_time <= new_patternlength then
            table.insert(new_points, {time = new_time, value = point.value})
          end
        end

        -- Add the new points to the automation
        for _, new_point in ipairs(new_points) do
          automation:add_point_at(new_point.time, new_point.value)
        end
      end
    end

    -- Adjust the selected line index
    song.selected_line_index = current_line + old_patternlength
    renoise.app():show_status("Pattern doubled successfully.")
  else
    -- Print a message if the new pattern length exceeds the limit
    renoise.app():show_status("New pattern length exceeds " .. renoise.Pattern.MAX_NUMBER_OF_LINES .. " lines, operation cancelled.")
  end
end

function pakettiPatternHalver()
  local song=renoise.song()
  local old_patternlength = song.selected_pattern.number_of_lines
  local resultlength = math.floor(old_patternlength / 2)
  local current_line = song.selected_line_index

  -- Check if the result length is less than 1, which would be invalid
  if resultlength < 1 then
    print("Resulting pattern length is too small, operation cancelled.")
    return
  end

  -- Set the new pattern length
  song.selected_pattern.number_of_lines = resultlength

  -- Adjust automation for each track
  for track_index, track in ipairs(song.selected_pattern.tracks) do
    local track_automations = song.patterns[song.selected_pattern_index].tracks[track_index].automation
    for _, automation in pairs(track_automations) do
      local points = automation.points
      local new_points = {}

      -- Collect new points, scaling down the time values
      for _, point in ipairs(points) do
        local new_time = math.floor((point.time / old_patternlength) * resultlength)
        if new_time >= 1 and new_time <= resultlength then
          table.insert(new_points, {time = new_time, value = point.value})
        end
      end

      -- Clear existing points and add scaled points
      automation.points = {}
      for _, point in ipairs(new_points) do
        automation:add_point_at(point.time, point.value)
      end
    end
  end

  -- Adjust the cursor position to maintain the same relative distance from the end
  local relative_distance_from_end = old_patternlength - current_line
  local new_line = resultlength - relative_distance_from_end

  -- Ensure the new line is within the valid range
  if new_line < 1 then new_line = 1 end
  if new_line > resultlength then new_line = resultlength end

  song.selected_line_index = new_line
end
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Paketti Pattern Doubler",invoke=pakettiPatternDoubler}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Paketti Pattern Halver",invoke=pakettiPatternHalver}

renoise.tool():add_keybinding{name="Mixer:Paketti:Paketti Pattern Doubler",invoke=pakettiPatternDoubler}
renoise.tool():add_keybinding{name="Mixer:Paketti:Paketti Pattern Halver",invoke=pakettiPatternHalver}

function get_master_track_index()
  for k,v in ripairs(renoise.song().tracks)
    do if v.type == renoise.Track.TRACK_TYPE_MASTER then return k end  
  end
end

function write_bpm()
  if renoise.song().transport.bpm < 256 then -- safety check
    local column_index = renoise.song().selected_effect_column_index
    local t=renoise.song().transport
  renoise.song().tracks[get_master_track_index()].visible_effect_columns = 2  
    
    if renoise.song().selected_effect_column_index <= 1 then column_index = 2 end
    
    renoise.song().selected_pattern.tracks[get_master_track_index()].lines[1].effect_columns[1].number_string = "ZT"
    renoise.song().selected_pattern.tracks[get_master_track_index()].lines[1].effect_columns[1].amount_value  = t.bpm
    renoise.song().selected_pattern.tracks[get_master_track_index()].lines[1].effect_columns[2].number_string = "ZL"
    renoise.song().selected_pattern.tracks[get_master_track_index()].lines[1].effect_columns[2].amount_value  = t.lpb
  end
end

function randombpm()
local prefix=nil
local randombpm = {80, 100, 115, 123, 128, 132, 135, 138, 160}
 math.randomseed(os.time())
  for i = 1, 9 do
      prefix = math.random(1, #randombpm)
      prefix = randombpm[prefix]
      print(prefix)
  end
 renoise.song().transport.bpm=prefix
    if renoise.tool().preferences.RandomBPM.value then
        write_bpm()
    end
end

function randomBPMMaster()
  local randombpm = {80, 100, 115, 123, 128, 132, 135, 138, 160}
  math.randomseed(os.time())
  local prefix = randombpm[math.random(#randombpm)]
  renoise.song().transport.bpm = prefix

  if renoise.tool().preferences.RandomBPM.value then 

      write_bpm()
  end
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Renoise Random BPM & Write BPM/LPB to Master",invoke=function() randomBPMMaster() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write BPM/LPB to Master",invoke=function() write_bpm() end}
renoise.tool():add_keybinding{name="Global:Paketti:Write BPM/LPB to Master",invoke=function() write_bpm() end}


function playat75()
 renoise.song().transport.bpm=renoise.song().transport.bpm*0.75
 write_bpm()
 renoise.app():show_status("BPM set to 75% (" .. renoise.song().transport.bpm .. "BPM)") 
end

function returnbackto100()
 renoise.song().transport.bpm=renoise.song().transport.bpm/0.75
 write_bpm()
 renoise.app():show_status("BPM set back to 100% (" .. renoise.song().transport.bpm .. "BPM)") 
end

renoise.tool():add_keybinding{name="Global:Paketti:Play at 75% Speed (Song BPM)",invoke=function() playat75() end}
renoise.tool():add_keybinding{name="Global:Paketti:Play at 100% Speed (Song BPM)",invoke=function() returnbackto100() end}



function randomBPMFromList()
        -- Define a list of possible BPM values
        local bpmList = {80, 100, 115, 123, 128, 132, 135, 138, 160}
        
        -- Get the current BPM
        local currentBPM = renoise.song().transport.bpm
        
        -- Filter the list to exclude the current BPM
        local newBpmList = {}
        for _, bpm in ipairs(bpmList) do
            if bpm ~= currentBPM then
                table.insert(newBpmList, bpm)
            end
        end

        -- Select a random BPM from the filtered list
        if #newBpmList > 0 then
            local selectedBPM = newBpmList[math.random(#newBpmList)]
            renoise.song().transport.bpm = selectedBPM
            print("Random BPM set to: " .. selectedBPM) -- Debug output to the console
        else
            print("No alternative BPM available to switch to.")
        end

        -- Optional: write the BPM to a file or apply other logic
        if renoise.tool().preferences.RandomBPM and renoise.tool().preferences.RandomBPM.value then
            write_bpm() -- Ensure this function is defined elsewhere in your tool
            print("BPM written to file or handled additionally.")
        end
    end
  
renoise.tool():add_keybinding{name="Global:Paketti:Random BPM from List",invoke=function() randomBPMFromList() end}
-------------------------
function WipeEfxFromSelection()
  local s = renoise.song()
  if s.selection_in_pattern == nil then return end

  local start_track = s.selection_in_pattern.start_track
  local end_track = s.selection_in_pattern.end_track
  local start_line = s.selection_in_pattern.start_line
  local end_line = s.selection_in_pattern.end_line
  local start_column = s.selection_in_pattern.start_column
  local end_column = s.selection_in_pattern.end_column

  -- Iterate through each selected track
  for track_index = start_track, end_track do
    local track = s:track(track_index)
    local pattern_track = s:pattern(s.selected_pattern_index):track(track_index)

    local visible_note_columns = track.visible_note_columns
    local visible_effect_columns = track.visible_effect_columns

    -- Determine column range to clear for this track
    local track_column_start, track_column_end

    if track_index == start_track then
      -- If it's the first track in the selection, use start_column
      track_column_start = start_column
    else
      -- For subsequent tracks, start at column 1
      track_column_start = 1
    end

    if track_index == end_track then
      -- If it's the last track in the selection, use end_column
      track_column_end = end_column
    else
      -- For previous tracks, end at the maximum number of columns
      track_column_end = visible_note_columns + visible_effect_columns
    end

    -- Calculate which effect columns are selected for this track
    local effect_column_start = math.max(1, track_column_start - visible_note_columns)
    local effect_column_end = math.min(visible_effect_columns, track_column_end - visible_note_columns)

    -- Skip if no effect columns are selected for this track
    if effect_column_end >= 1 then
      -- Iterate through selected lines
      for line_index = start_line, end_line do
        local line = pattern_track:line(line_index)

        if not line.is_empty then
          -- Iterate through the selected effect columns and clear them
          for effect_column_index = effect_column_start, effect_column_end do
            line:effect_column(effect_column_index):clear()
          end
        end
      end
    end
  end
end




renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe Effects From Selection",invoke=function() WipeEfxFromSelection() end}
----------------
--rescued from ImpulseBuddy by Protman! I have no idea how many of these were originally a part of Paketti, or something else, but
--hey, more crosspollination, more features.
function delete_effect_column()
local s=renoise.song()
local currTrak = s.selected_track_index
local currPatt = s.selected_pattern_index

local iter = s.pattern_iterator:effect_columns_in_pattern_track(currPatt,currTrak)
  for _,line in iter do
   if not line.is_empty then
   line:clear()
   end
  end 
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delete/Wipe/Clear Effect Column Content from Current Track",invoke=function() delete_effect_column() end}

----------------------------------------------------------------------------------------------------------------------------------------
-- originally created by joule + danoise
-- http://forum.renoise.com/index.php/topic/47664-new-tool-31-better-column-navigation/
-- ripped into Paketti without their permission. tough cheese.
local cached_note_column_index = nil
local cached_effect_column_index = nil
local column_cache_notifier_active = false

-- Function to cache columns - called on-demand when using column navigation
function cache_columns()
  -- access song only once renoise is ready
  if not pcall(renoise.song) then return end
  local s = renoise.song()
  if (s.selected_note_column_index > 0) then
    cached_note_column_index = s.selected_note_column_index
  end
  if (s.selected_effect_column_index > 0) then
    cached_effect_column_index = s.selected_effect_column_index
  end
end

-- Start column caching (adds idle notifier if not already active)
local function start_column_cache_notifier()
  if not column_cache_notifier_active then
    if not renoise.tool().app_idle_observable:has_notifier(cache_columns) then
      renoise.tool().app_idle_observable:add_notifier(cache_columns)
    end
    column_cache_notifier_active = true
  end
end

-- Ensure column cache notifier is started when tool loads (with has_notifier check)
start_column_cache_notifier()

function toggle_column_type()
  -- Ensure cache is active
  start_column_cache_notifier()
  local s = renoise.song()
  if s.selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    if s.selected_note_column_index ~= 0 then
      local col_idx = (cached_effect_column_index ~= 0) and 
        cached_effect_column_index or 1
      if (col_idx <= s.selected_track.visible_effect_columns) then
        s.selected_effect_column_index = col_idx
      elseif (s.selected_track.visible_effect_columns > 0) then
        s.selected_effect_column_index = s.selected_track.visible_effect_columns
      else
        -- no effect columns available
      end
    else
      local col_idx = (cached_note_column_index ~= 0) and 
        cached_note_column_index or 1
      if (col_idx <= s.selected_track.visible_note_columns) then
        s.selected_note_column_index = col_idx
      else -- always one note column
        s.selected_note_column_index = s.selected_track.visible_note_columns
      end
    end
  end
end

function cycle_column(direction)
  -- Ensure cache is active
  start_column_cache_notifier()
  local s = renoise.song()
  if direction == "next" then
    if (s.selected_note_column_index > 0) and (s.selected_note_column_index < s.selected_track.visible_note_columns) then -- any note column but not the last
      s.selected_note_column_index = s.selected_note_column_index + 1
    elseif (s.selected_track.visible_note_columns > 0) and (s.selected_note_column_index == s.selected_track.visible_note_columns) and (s.selected_track.visible_effect_columns > 0) then -- last note column when effect columns are available
      s.selected_effect_column_index = 1
    elseif (s.selected_effect_column_index < s.selected_track.visible_effect_columns) then -- any effect column but not the last
      s.selected_effect_column_index = s.selected_effect_column_index + 1
    elseif (s.selected_effect_column_index == s.selected_track.visible_effect_columns) and (s.selected_track_index < #s.tracks) then -- last effect column but not the last track
      s.selected_track_index = s.selected_track_index + 1
    else -- last column in last track
      s.selected_track_index = 1
    end
  elseif direction == "prev" then
    if (s.selected_note_column_index > 0) and (s.selected_sub_column_type > 2 and s.selected_sub_column_type < 8) then -- any sample effects column
      s.selected_note_column_index = s.selected_note_column_index
    elseif (s.selected_note_column_index > 1) then -- any note column but not the first
      s.selected_note_column_index = s.selected_note_column_index - 1
    elseif (s.selected_effect_column_index > 1) then -- any effect column but not the first
      s.selected_effect_column_index = s.selected_effect_column_index - 1
    elseif (s.selected_effect_column_index == 1) and (s.selected_track.visible_note_columns > 0) then -- first effect column and note columns exist
      s.selected_note_column_index = s.selected_track.visible_note_columns
    elseif (s.selected_effect_column_index == 1) and (s.selected_track.visible_note_columns == 0) then -- first effect column and note columns do not exist (group/send/master)
      s.selected_track_index = s.selected_track_index - 1
      if s.selected_track.visible_effect_columns > 0 then 
        s.selected_effect_column_index = s.selected_track.visible_effect_columns
      else 
        s.selected_note_column_index = s.selected_track.visible_note_columns
      end
    elseif (s.selected_note_column_index == 1) and (s.selected_track_index == 1) then -- first note column in first track
      local rns = renoise.song()
      s.selected_track_index = #rns.tracks
      s.selected_effect_column_index = s.selected_track.visible_effect_columns
    elseif (s.selected_note_column_index == 1) then -- first note column
      s.selected_track_index = s.selected_track_index - 1
      if s.selected_track.visible_effect_columns > 0 then 
        s.selected_effect_column_index = s.selected_track.visible_effect_columns
      else 
        s.selected_note_column_index = s.selected_track.visible_note_columns
      end
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Navigation:Paketti Switch between Note/FX columns",invoke=toggle_column_type}
renoise.tool():add_keybinding{name="Pattern Editor:Navigation:Paketti Jump to Column (Next) (Note/FX)",invoke=function() cycle_column("next") end}
renoise.tool():add_keybinding{name="Pattern Editor:Navigation:Paketti Jump to Column (Previous) (Note/FX)",invoke=function() cycle_column("prev") end}

-- Pattern Resizer by dblue. some minor modifications.
function resize_pattern(pattern, new_length, patternresize)
  
  -- We need a valid pattern object
  if (pattern == nil) then
    renoise.app():show_status('Need a valid pattern object!')
    return
  end
  
  -- Rounding function
  local function round(value)
    return math.floor(value + 0.5)
  end
  
  -- Shortcut to the song object
  local rs = renoise.song()
  
  -- Get the current pattern length
  local src_length = pattern.number_of_lines 
  
  -- Make sure new_length is within valid limits
  local dst_length = math.min(512, math.max(1, new_length))
   
  -- If the new length is the same as the old length, then we have nothing to do.
  if (dst_length == src_length) then
    return
  end
  
  -- Set conversation ratio
  local ratio = dst_length / src_length
  
  -- Change pattern length
  if patternresize==1 then 
 pattern.number_of_lines = dst_length
end
   
  -- Source
  local src_track = nil
  local src_line = nil
  local src_note_column = nil
  local src_effect_column = nil
  
  -- Insert a new track as a temporary work area
  rs:insert_track_at(1)
  
  -- Destination
  local dst_track = pattern:track(1)
  local dst_line_index = 0
  local dst_delay = 0
  local dst_line = nil
  local dst_note_column = nil
  local dst_effect_column = nil
  
  -- Misc
  local tmp_line_index = 0
  local tmp_line_delay = 0
  local delay_column_used = false   
  local track = nil

  -- Iterate through each track
  for src_track_index = 2, #rs.tracks, 1 do
  
    track = rs:track(src_track_index)

    -- Set source track
    src_track = pattern:track(src_track_index)
    
    -- Reset delay check
    delay_column_used = false
 
    -- Iterate through source lines
    for src_line_index = 0, src_length - 1, 1 do
    
      -- Set source line
      src_line = src_track:line(src_line_index + 1)
      
      -- Only process source line if it contains data
      if (not src_line.is_empty) then
           
        -- Store temporary line index and delay
        tmp_line_index = math.floor(src_line_index * ratio)
        tmp_line_delay = math.floor(((src_line_index * ratio) - tmp_line_index) * 256)
         
        -- Process note columns
        for note_column_index = 1, track.visible_note_columns, 1 do
        
          -- Set source note column
          src_note_column = src_line:note_column(note_column_index)
          
          -- Only process note column if it contains data 
          if (not src_note_column.is_empty) then
          
            -- Calculate destination line and delay
            dst_line_index = tmp_line_index
            dst_delay = math.ceil(tmp_line_delay + (src_note_column.delay_value * ratio))
            
            -- Wrap note to next line if necessary
            while (dst_delay >= 256) do
              dst_delay = dst_delay - 256
              dst_line_index = dst_line_index + 1
            end
            
            -- Keep track of whether the delay column is used
            -- so that we can make it visible later if necessary.
            if (dst_delay > 0) then
              delay_column_used = true
            end
            dst_line = dst_track:line(dst_line_index + 1)
            dst_note_column = dst_line:note_column(note_column_index)
            
            -- Note prioritisation 
            if (dst_note_column.is_empty) then
            
              -- Destination is empty. Safe to copy
              dst_note_column:copy_from(src_note_column)
              dst_note_column.delay_value = dst_delay   
              
            else
              -- Destination contains data. Try to prioritise...
            
              -- If destination contains a note-off...
              if (dst_note_column.note_value == 120) then
                -- Source note takes priority
                dst_note_column:copy_from(src_note_column)
                dst_note_column.delay_value = dst_delay
                
              else
              
                -- If the source is louder than destination...
                if (src_note_column.volume_value > dst_note_column.volume_value) then
                  -- Louder source note takes priority
                  dst_note_column:copy_from(src_note_column)
                  dst_note_column.delay_value = dst_delay
                  
                -- If source note is less delayed than destination...
                elseif (src_note_column.delay_value < dst_note_column.delay_value) then
                  -- Less delayed source note takes priority
                  dst_note_column:copy_from(src_note_column)
                  dst_note_column.delay_value = dst_delay 
                  
                end
                
              end      
              
            end -- End: Note prioritisation 
          
          end -- End: Only process note column if it contains data 
         
        end -- End: Process note columns
          
        -- Process effect columns     
        for effect_column_index = 1, track.visible_effect_columns, 1 do
          src_effect_column = src_line:effect_column(effect_column_index)
          if (not src_effect_column.is_empty) then
            dst_effect_column = dst_track:line(round(src_line_index * ratio) + 1):effect_column(effect_column_index)
            if (dst_effect_column.is_empty) then
              dst_effect_column:copy_from(src_effect_column)
            end
          end
        end
      
      end -- End: Only process source line if it contains data

    end -- End: Iterate through source lines
    
    -- If there is automation to process...
    if (#src_track.automation > 0) then
    
      -- Copy processed lines from temporary track back to original track
      -- We can't simply use copy_from here, since it will erase the automation
      for line_index = 1, dst_length, 1 do
        dst_line = dst_track:line(line_index)
        src_line = src_track:line(line_index)
        src_line:copy_from(dst_line)
      end
    
      -- Process automation
      for _, automation in ipairs(src_track.automation) do
        local points = {}
        for _, point in ipairs(automation.points) do
          if (point.time <= src_length) then
            table.insert(points, { time = math.min(dst_length - 1, math.max(0, round((point.time - 1) * ratio))), value = point.value })
          end
          automation:remove_point_at(point.time)
        end
        for _, point in ipairs(points) do
          if (not automation:has_point_at(point.time + 1)) then
            automation:add_point_at(point.time + 1, point.value)
          end
        end
      end
    
    else
    
      -- No automation to process. We can save time and just copy_from
      src_track:copy_from(dst_track)
    
    end
       
    -- Clear temporary track for re-use
    dst_track:clear()
     
    -- Show the delay column if any note delays have been used
    if (rs:track(src_track_index).type == 1) then
      if (delay_column_used) then
        rs:track(src_track_index).delay_column_visible = true
      end
    end
               
  end -- End: Iterate through each track
 
  -- Remove temporary track
  rs:delete_track_at(1)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Shrink (dBlue)",invoke=function()
local pattern = renoise.song().selected_pattern
resize_pattern(pattern, pattern.number_of_lines * 0.5, 0) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Expand (dBlue)",invoke=function()
local pattern = renoise.song().selected_pattern
resize_pattern(pattern, pattern.number_of_lines * 2, 0 ) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Shrink + Resize (dBlue)",invoke=function()
local pattern = renoise.song().selected_pattern
resize_pattern(pattern, pattern.number_of_lines * 0.5,1 ) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Expand + Resize (dBlue)",invoke=function()
local pattern = renoise.song().selected_pattern
resize_pattern(pattern, pattern.number_of_lines * 2,1) end}
-------------------
function bend(amount)
  local counter = nil 
  local s = renoise.song()

  if s.selection_in_pattern == nil then
    -- If no selection is set, output to the row that the cursor is on
    local current_line_index = s.selected_line_index
    
    counter = s.patterns[s.selected_pattern_index].tracks[s.selected_track_index].lines[current_line_index].effect_columns[1].amount_value + amount

    if counter > 255 then counter = 255 end
    if counter < 1 then counter = 0 end
    s.patterns[s.selected_pattern_index].tracks[s.selected_track_index].lines[current_line_index].effect_columns[1].amount_value = counter
  else
    -- If a selection is set, process the selection range
    local start_track = s.selection_in_pattern.start_track
    local end_track = s.selection_in_pattern.end_track
    for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
      for t = start_track, end_track do
        counter = s.patterns[s.selected_pattern_index].tracks[t].lines[i].effect_columns[1].amount_value + amount 

        if counter > 255 then counter = 255 end
        if counter < 1 then counter = 0 end
        s.patterns[s.selected_pattern_index].tracks[t].lines[i].effect_columns[1].amount_value = counter
      end
    end
  end
end

function effectamount(amount, effectname)
  -- Massive thanks to pandabot for the optimization tricks!
  local s = renoise.song()
  local counter = nil

  print("DEBUG: effectamount called with amount=" .. amount .. ", effectname=" .. (effectname or "nil"))
  print("DEBUG: selected track=" .. s.selected_track_index .. ", selected line=" .. s.selected_line_index)
  print("DEBUG: track type=" .. s.selected_track.type)
  print("DEBUG: visible effect columns=" .. s.selected_track.visible_effect_columns)

  -- Check if track is a sequencer track
  if s.selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    print("DEBUG: Track is not a sequencer track (type=" .. s.selected_track.type .. "), cannot write effects")
    return
  end

  -- Ensure at least one effect column is visible
  if s.selected_track.visible_effect_columns == 0 then
    print("DEBUG: No effect columns visible, making first effect column visible")
    s.selected_track.visible_effect_columns = 1
  end

  if s.selection_in_pattern == nil then
    -- If no selection is set, output to the row that the cursor is on
    local current_line_index = s.selected_line_index
    
    print("DEBUG: Writing to single line " .. current_line_index)
    local effect_column = s:pattern(s.selected_pattern_index):track(s.selected_track_index):line(current_line_index):effect_column(1)
    
    if not effect_column then
      print("DEBUG: ERROR - Could not get effect column 1")
      return
    end
    
    effect_column.number_string = effectname
    counter = effect_column.amount_value + amount

    if counter > 255 then counter = 255 end
    if counter < 1 then counter = 0 end
    effect_column.amount_value = counter
    
    print("DEBUG: Wrote " .. effectname .. string.format("%02X", counter) .. " to line " .. current_line_index)
  else
    -- If a selection is set, process the selection range
    local start_track = s.selection_in_pattern.start_track
    local end_track = s.selection_in_pattern.end_track
    print("DEBUG: Processing selection from line " .. s.selection_in_pattern.start_line .. " to " .. s.selection_in_pattern.end_line)
    print("DEBUG: Processing tracks from " .. start_track .. " to " .. end_track)
    
    for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
      for t = start_track, end_track do
        local track = s:pattern(s.selected_pattern_index):track(t)
        local track_obj = s:track(t)
        
        -- Check if this is a sequencer track
        if track_obj.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
          print("DEBUG: Skipping track " .. t .. " (not sequencer track)")
        else
          -- Ensure effect column is visible for this track
          if track_obj.visible_effect_columns == 0 then
            print("DEBUG: Making effect column visible for track " .. t)
            track_obj.visible_effect_columns = 1
          end
          
          local effect_column = track:line(i):effect_column(1)
          if not effect_column then
            print("DEBUG: ERROR - Could not get effect column 1 for track " .. t .. ", line " .. i)
          else
            effect_column.number_string = effectname
            counter = effect_column.amount_value + amount

            if counter > 255 then counter = 255 end
            if counter < 1 then counter = 0 end
            effect_column.amount_value = counter
            
            print("DEBUG: Wrote " .. effectname .. string.format("%02X", counter) .. " to track " .. t .. ", line " .. i)
          end
        end
      end
    end
  end
end



renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (-1)",invoke=function() bend(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (-10)",invoke=function() bend(-10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (-1) (2nd)",invoke=function() bend(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (-10) (2nd)",invoke=function() bend(-10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (-1) (3rd)",invoke=function() bend(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (-10) (3rd)",invoke=function() bend(-10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (+1)",invoke=function() bend(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (+10)",invoke=function() bend(10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (+1) (2nd)",invoke=function() bend(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (+10) (2nd)",invoke=function() bend(10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (+1) (3rd)",invoke=function() bend(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Infobyte (+10) (3rd)",invoke=function() bend(10) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Gxx Glide (-1)",invoke=function() effectamount(-1,"0G") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Gxx Glide (-10)",invoke=function() effectamount(-10,"0G") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Gxx Glide (+1)",invoke=function() effectamount(1,"0G") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Gxx Glide (+10)",invoke=function() effectamount(10,"0G") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (+1)",invoke=function() effectamount(1,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (-1)",invoke=function() effectamount(-1,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (+10)",invoke=function() effectamount(10,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (-10)",invoke=function() effectamount(-10,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (+1)",invoke=function() effectamount(1,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (-1)",invoke=function() effectamount(-1,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (+10)",invoke=function() effectamount(10,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (-10)",invoke=function() effectamount(-10,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (+1) (2nd)",invoke=function() effectamount(1,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (-1) (2nd)",invoke=function() effectamount(-1,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (+10) (2nd)",invoke=function() effectamount(10,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (-10) (2nd)",invoke=function() effectamount(-10,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (+1) (2nd)",invoke=function() effectamount(1,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (-1) (2nd)",invoke=function() effectamount(-1,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (+10) (2nd)",invoke=function() effectamount(10,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (-10) (2nd)",invoke=function() effectamount(-10,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (+1) (3rd)",invoke=function() effectamount(1,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (-1) (3rd)",invoke=function() effectamount(-1,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (+10) (3rd)",invoke=function() effectamount(10,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Uxx Slide Pitch Up (-10) (3rd)",invoke=function() effectamount(-10,"0U") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (+1) (3rd)",invoke=function() effectamount(1,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (-1) (3rd)",invoke=function() effectamount(-1,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (+10) (3rd)",invoke=function() effectamount(10,"0D") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Dxx Slide Pitch Down (-10) (3rd)",invoke=function() effectamount(-10,"0D") end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column L00 Track Volume Level 0 On/Off",invoke=function() voloff() end}
renoise.tool():add_midi_mapping{name="Paketti:Set Track Volume Level (L00)",invoke=function(message) if message:is_trigger() then voloff() end end}



--Switch between Effect and Note Column
function switchcolumns()
  local s = renoise.song()
  local w = renoise.app().window
if s.selected_note_column_index==nil then return end

  if s.selected_note_column_index==nil then return
    else if s.selected_effect_column_index==1 then s.selected_note_column_index=1
          w.active_middle_frame=1
          w.lock_keyboard_focus=true
          else s.selected_effect_column_index=1
           w.active_middle_frame=1
             w.lock_keyboard_focus=true end
  end
end
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Switch Effect Column/Note Column",invoke=function() switchcolumns() end}
--------
function ClearRow()
 local s=renoise.song()
 local currTrak=s.selected_track_index
 local currPatt=s.selected_pattern_index
 local currLine=s.selected_line_index
 
 -- Check if phrase editor is visible to avoid unintended clearing
 if renoise.app().window.active_middle_frame ~= 1 or not s.instruments[s.selected_instrument_index].phrase_editor_visible then
  if currLine < 1 then currLine = 1 end
  for i=1,8 do
   s.patterns[currPatt].tracks[currTrak].lines[currLine].effect_columns[i]:clear()
  end
  for i=1,12 do
   s.patterns[currPatt].tracks[currTrak].lines[currLine].note_columns[i]:clear()
  end
 end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear Current Row",invoke=function() ClearRow() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear Current Row 2nd",invoke=function() ClearRow() end}
-------------
--Select specific track:

function select_specific_track(number)

  if number > renoise.song().sequencer_track_count  then 
     number=renoise.song().sequencer_track_count
     renoise.song().selected_track_index=number
  else renoise.song().selected_track_index=number  end

  --if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
    --    capture_ins_oct("no")
    --  end

  -- Auto-select instrument used in the track if preference is enabled
  if preferences.PakettiSelectTrackSelectInstrument.value then
    if type(capture_ins_oct) == "function" then
      capture_ins_oct("no")
    end
  end
end

for st=1,32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Select Specific Track " .. formatDigits(2,st), 
    invoke=function() select_specific_track(st) end}
end

-- Add MIDI mappings for selecting specific tracks
for st=1,16 do
  renoise.tool():add_midi_mapping{name="Paketti:Select Specific Track " .. formatDigits(2,st),
    invoke=function(message) if message:is_trigger() then select_specific_track(st) end end}
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
function JumpToNextRow()
local LineGoTo = nil

LineGoTo = renoise.song().selected_line_index


renoise.song().tracks[get_master_track_index()].visible_effect_columns = 4
if renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[3].number_string == "ZB"
then
renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[3].number_string = ""
renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[3].amount_string  = ""
return
end


renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[3].number_string = "ZB"

if renoise.song().selected_line_index > 255 then LineGoTo = 00 end

renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[3].amount_value  = LineGoTo
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column ZBxx Jump To Row (Next)",invoke=function() JumpToNextRow() end}

--------------------
--Clone Current Pattern to Current Sequence and maintain pattern line index.
--Heaps of help from KMaki
function clonePTN()
local rs=renoise.song()
local currline=rs.selected_line_index
local n_patterns = #rs.patterns
local src_pat_i = rs.selected_pattern_index
local src_pat = rs:pattern(src_pat_i)
rs.selected_pattern_index = n_patterns + 1
rs.patterns[rs.selected_pattern_index].number_of_lines=renoise.song().patterns[rs.selected_pattern_index-1].number_of_lines
rs.selected_pattern:copy_from(src_pat)
rs.selected_line_index=currline
end

renoise.tool():add_keybinding{name="Global:Paketti:Clone Current Pattern to Current Sequence",invoke=function() clonePTN() end}
renoise.tool():add_keybinding{name="Global:Paketti:Clone Current Pattern to Current Sequence (2nd)",invoke=function() clonePTN() end}
renoise.tool():add_keybinding{name="Global:Paketti:Clone Current Pattern to Current Sequence (3rd)",invoke=function() clonePTN() end}
------------------------------
-- Destructive 0B01 adder/disabler
function revnoter()
local s = renoise.song()
local efc = s.selected_effect_column

if efc==nil then
  return
  else
  if efc.number_value==11 then
     efc.number_value=00
     efc.amount_value=00
  else
     efc.number_value=11
     efc.amount_value=01
  end
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column B01 Reverse Sample Effect On/Off",invoke=function()
local s=renoise.song()
local nci=s.selected_note_column_index 
s.selected_effect_column_index=1
revnoter() 
if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then 
    return
else 
s.selected_note_column_index=nci
--s.selected_note_column_index=1 
end end}




-- Destructive 0B00 adder/disabler
function revnote()
local s = renoise.song()
local efc = s.selected_effect_column

if efc==nil then
  return
  else
  if efc.number_value==11 then
     efc.number_value=00
     efc.amount_value=00
  else
     efc.number_value=11
     efc.amount_value=00
  end
  end
end

function effectColumnB00()
  local song=renoise.song()
  local track = song.selected_track
  local line = song.selected_pattern_track.lines[song.selected_line_index]
  
  -- Only proceed if we can have effect columns
  if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    -- First check all effect columns for existing B00
    for i = 1, track.visible_effect_columns do
      local effect = line.effect_columns[i]
      if effect.number_value == 11 and effect.amount_value == 0 then
        -- Found B00, clear it
        effect.number_value = 0
        effect.amount_value = 0
        return -- Exit after clearing
      end
    end
    
    -- If we're in an effect column, try to use that first
    local target_column = nil
    if song.selected_effect_column_index and song.selected_effect_column_index > 0 then
      target_column = song.selected_effect_column_index
    else
      -- Find first empty effect column
      for i = 1, track.visible_effect_columns do
        if line.effect_columns[i].number_value == 0 then
          target_column = i
          break
        end
      end
    end
    
    -- If no empty visible column found, try to make a new one visible
    if not target_column and track.visible_effect_columns < 8 then
      track.visible_effect_columns = track.visible_effect_columns + 1
      target_column = track.visible_effect_columns
    end
    
    -- If we found or created a column, add B00
    if target_column then
      line.effect_columns[target_column].number_value = 11 -- 'B' effect
      line.effect_columns[target_column].amount_value = 0  -- '00' amount
    else
      renoise.app():show_status("There are no free Effect Columns available, doing nothing.")
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column B00 Reverse Sample Effect On/Off",invoke=function() effectColumnB00()end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column B00 Reverse Sample Effect On/Off (2nd)",invoke=function() effectColumnB00()end}
  

renoise.tool():add_midi_mapping{name="Paketti:Effect Column B00 Reverse Sample Effect On/Off",invoke=function(message) if message:is_trigger() then effectColumnB00() end end}

----------------------------------------------------------------------------------------------------------------------------------
function displayEffectColumn(number) local rs=renoise.song() rs.tracks[rs.selected_track_index].visible_effect_columns=number end

for dec=1,8 do
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Display Effect Column " .. dec,invoke=function() 
  renoise.app().window.active_middle_frame=1
  displayEffectColumn(dec) end}
end
-- Display user-specific amount of note columns or effect columns:
function displayNoteColumn(number) local rs=renoise.song() if rs.tracks[rs.selected_track_index].visible_note_columns == 0 then return else rs.tracks[rs.selected_track_index].visible_note_columns=number end end

for dnc=1,12 do
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Display Note Column " .. formatDigits(2,dnc),invoke=function() displayNoteColumn(dnc) end}
end
---------
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Reset Panning in Current Column & Row",invoke=function()
local s=renoise.song()
local nc=s.selected_note_column
local currTrak=s.selected_track_index
s.selected_track.panning_column_visible=true
if renoise.song().selected_note_column == nil then return else 
renoise.song().selected_note_column.panning_value = 0xFF
end
end}

function write_effect(incoming)
  local s = renoise.song()
  local efc = s.selected_effect_column

    if efc==nil then
         s.selected_effect_column.number_string=incoming
         s.selected_effect_column.amount_value=00
      else
      if efc.number_string==incoming and efc.amount_string=="00" then
         s.selected_effect_column.number_string=incoming
         s.selected_effect_column.amount_string="C0"
      else
         s.selected_effect_column.number_string=incoming
         s.selected_effect_column.amount_value=00
      end
    end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column L00/LC0 Volume Effect Switch",invoke=function() 
renoise.song().selected_effect_column_index=1
write_effect("0L") 

  if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then return
else renoise.song().selected_note_column_index=1 end end} 
  




------------------------------
function writeretrig()
  local s = renoise.song()
  local efc = s.selected_effect_column
  local av = renoise.song().transport.lpb * 2
    if efc==nil then
         renoise.song().selected_effect_column.number_string="0R"
         renoise.song().selected_effect_column.amount_value=av
      else
      if efc.number_string=="0R" and efc.amount_value==av then
         renoise.song().selected_effect_column.number_string="00"
         renoise.song().selected_effect_column.amount_string="00"
      else
         renoise.song().selected_effect_column.number_string="00"
         renoise.song().selected_effect_column.amount_value=00 end end end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column 0R(LPB) Retrig On/Off",invoke=function() 
renoise.song().selected_effect_column_index=1
writeretrig() 
  if renoise.song().selected_track.type==2 or renoise.song().selected_track.type==3 or renoise.song().selected_track.type==4 then return
else renoise.song().selected_note_column_index=1 end end} 





----------



function previousEffectColumn()
  -- Fetch the currently selected track
  local selected_track = renoise.song().selected_track
  local num_effect_columns = selected_track.visible_effect_columns

  -- Proceed only if there are visible effect columns
  if num_effect_columns > 0 then
    -- Check if there is a currently selected effect column
    if renoise.song().selected_effect_column == nil then
      -- No effect column selected, select the last one
      renoise.song().selected_effect_column_index = num_effect_columns
    else
      -- Find the index of the currently selected effect column
      local current_index = renoise.song().selected_effect_column_index

      -- If the current column is the first one, or there's only one, go to the previous track's last column
      if current_index == 1 or num_effect_columns == 1 then
        -- Find and select the last track with visible effect columns
        local song=renoise.song()
        local current_track_index = song.selected_track_index
        local track_count = #song.tracks

        -- Loop through tracks starting from the previous track
        local found = false
        for i = current_track_index - 1, 1, -1 do
          if song.tracks[i].visible_effect_columns > 0 then
            song.selected_track_index = i
            song.selected_effect_column_index = song.tracks[i].visible_effect_columns
            found = true
            break
          end
        end

        -- If no previous track with visible columns was found, loop from the end
        if not found then
          for i = track_count, current_track_index + 1, -1 do
            if song.tracks[i].visible_effect_columns > 0 then
              song.selected_track_index = i
              song.selected_effect_column_index = song.tracks[i].visible_effect_columns
              break
            end
          end
        end
      else
        -- Move to the previous effect column in the current track
        renoise.song().selected_effect_column_index = current_index - 1
      end
    end
  else
    print("The selected track has no visible effect columns.")
  end
end



function nextEffectColumn()
  local selected_track = renoise.song().selected_track
  local num_effect_columns = selected_track.visible_effect_columns

  -- Proceed only if there are visible effect columns
  if num_effect_columns > 0 then
    -- Check if there is a currently selected effect column
    if renoise.song().selected_effect_column == nil then
      -- No effect column selected, select the first one
      renoise.song().selected_effect_column_index = 1
    else
      -- Find the index of the currently selected effect column
      local current_index = renoise.song().selected_effect_column_index
      
      -- If the current column is the last one, or there's only one, go to the next track's first column
      if current_index == num_effect_columns or num_effect_columns == 1 then
        -- Find and select the first track with visible effect columns
        local song=renoise.song()
        local current_track_index = song.selected_track_index
        local track_count = #song.tracks

        -- Loop through tracks starting from the next track
        local found = false
        for i = current_track_index + 1, track_count do
          if song.tracks[i].visible_effect_columns > 0 then
            song.selected_track_index = i
            song.selected_effect_column_index = 1
            found = true
            break
          end
        end

        if not found then
          for i = 1, current_track_index - 1 do
            if song.tracks[i].visible_effect_columns > 0 then
              song.selected_track_index = i
              song.selected_effect_column_index = 1
              break
            end
          end
        end
      else
        renoise.song().selected_effect_column_index = current_index + 1
      end
    end
  else
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Select Effect Column (Previous)",invoke=function() previousEffectColumn() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Select Effect Column (Next)",invoke=function() nextEffectColumn() end}


-----------------

-- Columnizer, +1 / -1 / +10 / -10 on current_row, display needed column
function columns(chg,thing)
  local song=renoise.song()
local s=renoise.song()
local snci=song.selected_note_column_index
local seci=song.selected_effect_column_index
local sst=s.selected_track
local columns={}

if ( snci > 0 ) then 
columns[1] = s.selected_note_column.delay_value
columns[2] = s.selected_note_column.panning_value
columns[3] = s.selected_note_column.volume_value
elseif ( seci > 0 ) then
columns[4] = s.selected_effect_column.number_value
columns[5] = s.selected_effect_column.amount_value
end

 local nc = s.selected_note_column
 local nci = s.selected_note_column_index
 local currPatt = s.selected_pattern_index
 local currTrak = s.selected_track_index
 local currLine = s.selected_line_index
 
if thing == 1 then --if delay columning
        sst.delay_column_visible=true
        nc.delay_value = math.max(0, math.min(255, columns[thing] + chg))
elseif thing == 2 then --if panning
        local center_out_of_bounds=false
        changepan(chg, center_out_of_bounds)
elseif thing == 3 then --if volume columning
        sst.volume_column_visible=true
        nc.volume_value = math.max(0, math.min(128, columns[thing] + chg))
elseif thing == 4 then --if effect number columning
        s.selected_line.effect_columns[seci].number_value = math.max(0, math.min(255, columns[thing] + chg)) 
elseif thing == 5 then --if effect amount columning
        -- renoise.song().tracks[currTrak].sample_effects_column_visible=true
        s.selected_line.effect_columns[seci].amount_value = math.max(0, math.min(255, columns[thing] + chg)) 
else
-- default, shows panning, delay, volume columns.
        sst.delay_column_visible=true
        sst.panning_column_visible=true
        sst.volume_column_visible=true
end
 --nc.delay_value=(d+chg)
 --if nc.delay_value == 0 and chg < 0 then
  --move_up(chg)
 --elseif nc.delay_value == 255 and chg > 0 then
  --move_down(chg)
 --else
 -- nc.delay_value
--end
end

----------
--Shortcut for setting Panning +1/+10/-10/-1 on current_row - automatically displays the panning column.
--Lots of help from Joule, Raul/ulneiz, Ledger, dblue! 
function changepan(change,center_out_of_bounds)
-- Set the behaviour when going out of bounds.
-- If centering (to 0x40) then pan < 0 or > 0x80 will reset the new value back to center.
-- Else just clip to the valid pan range 0x00 to 0x80. (Default behaviour)
center_out_of_bounds = center_out_of_bounds or false
 
-- Local reference to the song.
local s = renoise.song()
  
-- Local reference to the selected note column.
local nc = s.selected_note_column
  
-- If no valid note column is selected...
if nc == nil then return false end
  
-- When triggering the function - always make panning column visible.
s.selected_track.panning_column_visible=true
  
-- Store the current pan value
local pan = nc.panning_value
  
-- If the pan value is empty, set the default center value (0x40)
if pan == renoise.PatternLine.EMPTY_PANNING then pan=0x40 end
  
-- Apply the pan change.
pan = pan + change

-- If wrapping to center and out of bounds, reset to center.
if center_out_of_bounds and (pan < 0x00 or pan > 0x80) then pan=0x40
  
-- Else...
  else

-- Clip to valid pan range.
pan=math.min(0x80, math.max(0x00, pan))    
end
  
-- If the final value ends up back at exact center then show an empty panning column instead.
if pan==0x40 then
   pan = renoise.PatternLine.EMPTY_PANNING end  
  
-- Finally shove the new value back into the note column.
nc.panning_value = pan 
end

function columnspart2(chg,thing)
    local song=renoise.song()
local effect_column_index
    -- Handle nil for selected_effect_column_index, default to 1

if renoise.song().selected_effect_column_index == nil or renoise.song().selected_effect_column_index == 0 then
effect_column_index = 1
else 
effect_column_index = song.selected_effect_column_index
end

    local currPatt = song.selected_pattern_index
    local currTrak = song.selected_track_index
    local currLine = song.selected_line_index
    local track = song.patterns[currPatt].tracks[currTrak]
    
    -- Ensure the effect column exists
    if effect_column_index > renoise.song().tracks[currTrak].visible_effect_columns then
        renoise.app():show_status("Effect column index out of range")
    return
  end

    local effect_column = track.lines[currLine].effect_columns[effect_column_index]
    if not effect_column then
        renoise.app():show_status("No effect column available at index " .. tostring(effect_column_index))
    return
  end

    -- Fetch the current values for the selected effect column
    local columns = {
        [4] = effect_column.number_value,
        [5] = effect_column.amount_value
    }

    -- Adjust the values based on the `thing` parameter
    if thing == 4 then
        effect_column.number_value = math.max(0, math.min(255, columns[thing] + chg))
    elseif thing == 5 then
        effect_column.amount_value = math.max(0, math.min(255, columns[thing] + chg))
    end
end

function PakettiNoteOffDelayModify(delay_change)
  local song = renoise.song()
  local current_pattern = song.selected_pattern
  local current_track_index = song.selected_track_index
  local current_track = song.selected_track
  
  -- Make delay column visible
  current_track.delay_column_visible = true
  
  local note_off_count = 0
  local pattern_lines = current_pattern.number_of_lines
  
  -- Iterate through all lines in the pattern
  for line_index = 1, pattern_lines do
    local pattern_line = current_pattern:track(current_track_index):line(line_index)
    
    -- Check all note columns in this line
    for column_index = 1, current_track.visible_note_columns do
      local note_column = pattern_line:note_column(column_index)
      
      -- Check if this is a NOTE_OFF
      if note_column.note_value == renoise.PatternLine.NOTE_OFF then
        -- Modify the delay value with bounds checking
        local new_delay = note_column.delay_value + delay_change
        new_delay = math.max(0, math.min(255, new_delay))
        note_column.delay_value = new_delay
        note_off_count = note_off_count + 1
      end
    end
  end
  
  if note_off_count > 0 then
    renoise.app():show_status(string.format("Modified delay for %d Note OFF events by %+d", note_off_count, delay_change))
  else
    renoise.app():show_status("No Note OFF events found in current track")
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Delay (+1)",invoke=function() columns(1,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Delay (+10)",invoke=function() columns(10,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Delay (-1)",invoke=function() columns(-1,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Delay (-10)",invoke=function() columns(-10,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Delay (+1) (2nd)",invoke=function() columns(1,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Delay (+10) (2nd)",invoke=function() columns(10,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Delay (-1) (2nd)",invoke=function() columns(-1,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Delay (-10) (2nd)",invoke=function() columns(-10,1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Off Note Delay Offset (+1)",invoke=function() PakettiNoteOffDelayModify(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Off Note Delay Offset (-1)",invoke=function() PakettiNoteOffDelayModify(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Panning (+1)",invoke=function() columns(1,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Panning (+10)",invoke=function() columns(10,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Panning (-1)",invoke=function() columns(-1,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Panning (-10)",invoke=function() columns(-10,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Panning (+1) (2nd)",invoke=function() columns(1,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Panning (+10) (2nd)",invoke=function() columns(10,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Panning (-1) (2nd)",invoke=function() columns(-1,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Panning (-10) (2nd)",invoke=function() columns(-10,2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Volume (+1)",invoke=function() columns(1,3) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Volume (+10)",invoke=function() columns(10,3) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Volume (-1)",invoke=function() columns(-1,3) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Volume (-10)",invoke=function() columns(-10,3) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Effect Number (+1)",invoke=function() columns(1,4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Effect Number (+10)",invoke=function() columnspart2(10,4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Effect Number (-1)",invoke=function() columnspart2(-1,4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Effect Number (-10)",invoke=function() columnspart2(-10,4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Effect Amount (+1)",invoke=function() columnspart2(1,5) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Increase Effect Amount (+10)",invoke=function() columnspart2(10,5) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Effect Amount (-1)",invoke=function() columnspart2(-1,5) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Columnizer Decrease Effect Amount (-10)",invoke=function() columnspart2(-10,5) end}

--------
-- Global variables to store the last track index and color
lastTrackIndex = nil
lastTrackColor = nil
trackNotifierAdded = false -- Flag to track if the notifier was added

-- Function to set color blend for all tracks
function pakettiEditModeSignalerSetAllTracksColorBlend(value)
  local song=renoise.song()
  if not song or not song.tracks then
    print("-- Paketti Debug: song or tracks table is nil in SetAllTracksColorBlend")
    return
  end
  for i=1,#song.tracks do
    song.tracks[i].color_blend = value
  end
end

-- Function to set color blend for a specific track
function pakettiEditModeSignalerSetTrackColorBlend(index,value)
  local song=renoise.song()
  if not song then
    print("-- Paketti Debug: song is nil in SetTrackColorBlend")
    return
  end
  if not song.tracks then
    print("-- Paketti Debug: song.tracks is nil in SetTrackColorBlend")
    return
  end
  if not song.tracks[index] then
    print(string.format("-- Paketti Debug: track at index %d is nil in SetTrackColorBlend", index))
    return
  end
  song.tracks[index].color_blend = value
end

-- Function to handle edit mode enabled
function pakettiEditModeSignalerOnEditModeEnabled()
  local song=renoise.song()
  local selectedTrackIndex=song.selected_track_index

  lastTrackIndex=selectedTrackIndex
  lastTrackColor=song.tracks[selectedTrackIndex].color_blend

  local pakettiEditMode=preferences.pakettiEditMode.value

  if pakettiEditMode==3 then
    pakettiEditModeSignalerSetAllTracksColorBlend(preferences.pakettiBlendValue.value)
  elseif pakettiEditMode==2 then
    pakettiEditModeSignalerSetTrackColorBlend(selectedTrackIndex,preferences.pakettiBlendValue.value)
  end

  -- Add selected track index notifier if not already added
  if not trackNotifierAdded then
    song.selected_track_index_observable:add_notifier(pakettiEditModeSignalerTrackIndexNotifier)
    trackNotifierAdded=true
  end
end

-- Function to handle edit mode disabled
function pakettiEditModeSignalerOnEditModeDisabled()
  local song=renoise.song()
  local pakettiEditMode=preferences.pakettiEditMode.value

  if lastTrackIndex and pakettiEditMode~=1 then
      pakettiEditModeSignalerSetTrackColorBlend(lastTrackIndex,lastTrackColor)
      pakettiEditModeSignalerSetAllTracksColorBlend(0)
  end

  -- Set all tracks' color blend to 0

  -- Remove selected track index notifier if it was added
  if trackNotifierAdded then
    pcall(function()
        song.selected_track_index_observable:remove_notifier(pakettiEditModeSignalerTrackIndexNotifier)
    end)
    trackNotifierAdded=false
  end
end

-- Notifier for edit mode change
function pakettiEditModeSignalerEditModeNotifier()
  local transport=renoise.song().transport
  if transport.edit_mode then
    pakettiEditModeSignalerOnEditModeEnabled()
  else
    pakettiEditModeSignalerOnEditModeDisabled()
  end
end

-- Notifier for track selection change
function pakettiEditModeSignalerTrackIndexNotifier()
  local song=renoise.song()
  local selectedTrackIndex=song.selected_track_index
  local pakettiEditMode=preferences.pakettiEditMode.value

  if song.transport.edit_mode then
    if pakettiEditMode==3 then
      pakettiEditModeSignalerSetAllTracksColorBlend(preferences.pakettiBlendValue.value)
    else
      if lastTrackIndex and lastTrackIndex~=selectedTrackIndex and pakettiEditMode~=1 then
          pakettiEditModeSignalerSetTrackColorBlend(lastTrackIndex,lastTrackColor)
      end
      lastTrackIndex=selectedTrackIndex
        lastTrackColor=song.tracks[selectedTrackIndex].color_blend
        if pakettiEditMode==2 then
          pakettiEditModeSignalerSetTrackColorBlend(selectedTrackIndex,preferences.pakettiBlendValue.value)
      end
    end
  end
end

-- Named handler function for proper notifier management
local function pakettiEditModeSignalerNewDocumentHandler()
  local song=renoise.song()
  if not song.transport.edit_mode_observable:has_notifier(pakettiEditModeSignalerEditModeNotifier) then
    song.transport.edit_mode_observable:add_notifier(pakettiEditModeSignalerEditModeNotifier)
  end
  pakettiEditModeSignalerEditModeNotifier() -- Call once to ensure the state is consistent
end

-- Add notifiers for edit mode change and initial track selection (with guard)
if not renoise.tool().app_new_document_observable:has_notifier(pakettiEditModeSignalerNewDocumentHandler) then
  renoise.tool().app_new_document_observable:add_notifier(pakettiEditModeSignalerNewDocumentHandler)
end

-- Keybinding and MIDI mapping
function recordTint()
  renoise.song().transport.edit_mode=not renoise.song().transport.edit_mode
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Edit Mode and Tint Track",invoke=recordTint}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Edit Mode and Tint Track",invoke=recordTint}


------------------
function pakettiDuplicateEffectColumnToPatternOrSelection()
  -- Obtain the currently selected song and pattern
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  
  -- Obtain the current track and line index
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  
  -- Obtain the current effect column command from the selected line
  local current_effects = song:pattern(pattern_index):track(track_index):line(line_index).effect_columns
  
  -- Check if there is a selection in the pattern
  local selection = song.selection_in_pattern
  local start_line, end_line
  
  if selection then
    -- There is a selection, use the selection range
    start_line = selection.start_line
    end_line = selection.end_line
  else
    -- No selection, use the entire pattern
    start_line = 1
    end_line = pattern.number_of_lines
  end
  
  -- Iterate through each line in the range and copy the effect column command
  for i = start_line, end_line do
    local line = song:pattern(pattern_index):track(track_index):line(i)
    for j = 1, #current_effects do
      line.effect_columns[j].number_string = current_effects[j].number_string
      line.effect_columns[j].amount_string = current_effects[j].amount_string
    end
  end
  
  -- Inform the user that the operation was successful
  renoise.app():show_status("Effect column command duplicated to selected rows in the pattern.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Effect Column Content to Pattern or Selection",invoke=pakettiDuplicateEffectColumnToPatternOrSelection}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Effect Column Content to Pattern or Selection",invoke=pakettiDuplicateEffectColumnToPatternOrSelection}


------------
-- Function to randomize effect column parameters
function pakettiRandomizeEffectColumnParameters()
  -- Obtain the currently selected song and pattern
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  
  -- Obtain the current track index
  local track_index = song.selected_track_index
  
  -- Check if there is a selection in the pattern
  local selection = song.selection_in_pattern
  local start_line, end_line
  
  if selection then
    -- There is a selection, use the selection range
    start_line = selection.start_line
    end_line = selection.end_line
  else
    -- No selection, use the entire pattern
    start_line = 1
    end_line = pattern.number_of_lines
  end

  -- Randomize effect parameters
  for line_index = start_line, end_line do
    local line = song:pattern(pattern_index):track(track_index):line(line_index)
    for i = 1, #line.effect_columns do
      local effect_type = line.effect_columns[i].number_string
      if effect_type ~= "" then
        local random_value = math.random(0, 255)
        line.effect_columns[i].amount_value = random_value
      end
    end
  end
  
  renoise.app():show_status("Effect column parameters randomized.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Parameters",invoke=pakettiRandomizeEffectColumnParameters}
renoise.tool():add_midi_mapping{name="Paketti:Randomize Effect Column Parameters",invoke=pakettiRandomizeEffectColumnParameters}

--------
function pakettiInterpolateEffectColumnParameters()
  -- Obtain the currently selected song and pattern
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  
  -- Obtain the current track index
  local track_index = song.selected_track_index
  
  -- Check if there is a selection in the pattern
  local selection = song.selection_in_pattern
  local start_line, end_line
  
  if selection then
    -- There is a selection, use the selection range
    start_line = selection.start_line
    end_line = selection.end_line
  else
    -- No selection, use the entire pattern
    start_line = 1
    end_line = pattern.number_of_lines
  end

  -- Interpolate effect parameters
  local first_effect_line = song:pattern(pattern_index):track(track_index):line(start_line).effect_columns
  local last_effect_line = song:pattern(pattern_index):track(track_index):line(end_line).effect_columns

  for i = 1, #first_effect_line do
    local first_value = tonumber(first_effect_line[i].amount_value)
    local last_value = tonumber(last_effect_line[i].amount_value)
    if first_value and last_value then
      for line_index = start_line, end_line do
        local line = song:pattern(pattern_index):track(track_index):line(line_index)
        local t = (line_index - start_line) / (end_line - start_line)
        local interpolated_value = math.floor(first_value + t * (last_value - first_value))
        line.effect_columns[i].number_value = first_effect_line[i].number_value
        line.effect_columns[i].amount_value = interpolated_value
      end
    end
  end
  
  -- Inform the user that the operation was successful
  renoise.app():show_status("Effect column parameters interpolated.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Column Values (Effect)",invoke=pakettiInterpolateEffectColumnParameters}
renoise.tool():add_midi_mapping{name="Paketti:Interpolate Column Values (Effect)",invoke=pakettiInterpolateEffectColumnParameters}

--------
-- Function to flood fill the track with the current note and instrument
function pakettiFloodFill()
  -- Obtain the currently selected song and pattern
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  
  -- Obtain the current track and line index
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  
  -- If no note column is selected, fail
  if not song.selected_note_column_index then
    renoise.app():show_status("No note column selected")
    return
  end
  
  local current_line = song:pattern(pattern_index):track(track_index):line(line_index)
  local current_note_column = current_line.note_columns[song.selected_note_column_index]
  
  -- Check if there's actually content to flood fill with
  if not current_note_column or current_note_column.is_empty then
    renoise.app():show_status("No note/instrument data to flood fill with")
    return
  end

  -- Get all the note column values
  local note_value = current_note_column.note_value
  local instrument_value = current_note_column.instrument_value
  local volume_value = current_note_column.volume_value
  local panning_value = current_note_column.panning_value
  local delay_value = current_note_column.delay_value
  local effect_number_string = current_note_column.effect_number_string
  local effect_amount_string = current_note_column.effect_amount_string

  -- Check if there is a selection in the pattern
  local selection = song.selection_in_pattern
  local start_line, end_line
  
  if selection then
    -- There is a selection, use the selection range
    start_line = selection.start_line
    end_line = selection.end_line
  else
    -- No selection, use from current onwards
    start_line = line_index
    end_line = pattern.number_of_lines
  end

  -- Iterate through each line in the range and fill with all note column values
  for i = start_line, end_line do
    local line = song:pattern(pattern_index):track(track_index):line(i)
    local note_column = line.note_columns[song.selected_note_column_index]
    note_column.note_value = note_value
    note_column.instrument_value = instrument_value
    note_column.volume_value = volume_value
    note_column.panning_value = panning_value
    note_column.delay_value = delay_value
    note_column.effect_number_string = effect_number_string
    note_column.effect_amount_string = effect_amount_string
  end
  
  -- Inform the user that the operation was successful
  renoise.app():show_status("Track or Selection filled with Note Column values.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Flood Fill Note and Instrument",invoke=pakettiFloodFill}
renoise.tool():add_midi_mapping{name="Paketti:Flood Fill Note and Instrument",invoke=pakettiFloodFill}

-----------
-- Function to Flood Fill the track with the current note and instrument with an edit step
function pakettiFloodFillWithEditStep()
  -- Obtain the currently selected song and pattern
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]

  -- Obtain the current track and line index
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index

  -- Obtain the current edit step
  local edit_step = song.transport.edit_step

  -- Obtain the current note column index
  local note_column_index = song.selected_note_column_index

  -- Get the selection in the pattern
  local selection = song.selection_in_pattern
  local start_line, end_line, start_track, end_track, start_column, end_column

  if selection then
    -- There is a selection, use the selection range
    start_line = selection.start_line
    end_line = selection.end_line
    start_track = selection.start_track
    end_track = selection.end_track
    start_column = selection.start_column
    end_column = selection.end_column
  else
    -- No selection, use from the current row onwards in the current track and note column
    start_line = line_index
    end_line = pattern.number_of_lines
    start_track = track_index
    end_track = track_index
    start_column = note_column_index
    end_column = note_column_index
  end

  -- Check if the edit step is larger than the number of lines in the pattern
  if edit_step > (end_line - start_line + 1) then
    renoise.app():show_status("Did not apply Flood Fill with EditStep because EditStep is larger than Amount of Lines in Pattern")
    return
  end

  local found_note = false
  local note_values = {}
  local instrument_values = {}
  local clear_columns = {}

  -- Read the current row's note and instrument values for each track and column in the selection
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    if track.type ~= renoise.Track.TRACK_TYPE_GROUP and track.type ~= renoise.Track.TRACK_TYPE_SEND and track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      note_values[track_idx] = {}
      instrument_values[track_idx] = {}
      clear_columns[track_idx] = {}
      local first_column = (track_idx == start_track) and start_column or 1
      local last_column = (track_idx == end_track) and end_column or track.visible_note_columns
      for column_index = first_column, last_column do
        local current_note_column = song:pattern(pattern_index):track(track_idx):line(line_index).note_columns[column_index]
        if current_note_column and not current_note_column.is_empty then
          note_values[track_idx][column_index] = current_note_column.note_value
          instrument_values[track_idx][column_index] = current_note_column.instrument_value
          clear_columns[track_idx][column_index] = true
          found_note = true
          -- Debug message to track the note and instrument values
          print(string.format("Read note %d and instrument %d from Track %d, Column %d", current_note_column.note_value, current_note_column.instrument_value, track_idx, column_index))
        elseif current_note_column then
          clear_columns[track_idx][column_index] = false
        end
      end
    end
  end

  if not found_note then
    renoise.app():show_status("There was nothing to Flood Fill with EditStep with.")
    return
  end

  -- Clear all selected note columns except the current row (or start line if selection exists)
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    if track.type ~= renoise.Track.TRACK_TYPE_GROUP and track.type ~= renoise.Track.TRACK_TYPE_SEND and track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      local first_column = (track_idx == start_track) and start_column or 1
      local last_column = (track_idx == end_track) and end_column or track.visible_note_columns
      for column_index = first_column, last_column do
        if clear_columns[track_idx][column_index] then
          for i = start_line, end_line do
            if selection then
              if i ~= start_line then
                local line = song:pattern(pattern_index):track(track_idx):line(i)
                local note_column = line.note_columns[column_index]
                note_column:clear()
              end
            else
              if i ~= line_index then
                local line = song:pattern(pattern_index):track(track_idx):line(i)
                local note_column = line.note_columns[column_index]
                note_column:clear()
              end
            end
          end
          -- Debug message to track the clearing of rows
          print(string.format("Cleared Track %d, Column %d from Row %d to Row %d", track_idx, column_index, start_line, end_line))
        end
      end
    end
  end

  -- Apply Flood Fill with edit step
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    if track.type ~= renoise.Track.TRACK_TYPE_GROUP and track.type ~= renoise.Track.TRACK_TYPE_SEND and track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      local first_column = (track_idx == start_track) and start_column or 1
      local last_column = (track_idx == end_track) and end_column or track.visible_note_columns
      for column_index = first_column, last_column do
        if note_values[track_idx][column_index] then
          local note_value = note_values[track_idx][column_index]
          local instrument_value = instrument_values[track_idx][column_index]

          -- Debug message to track the note and instrument values being applied
          print(string.format("Applying Flood Fill to Selection In Pattern, with EditStep %d to Track %d, Column %d using note %d and instrument %d", edit_step, track_idx, column_index, note_value, instrument_value))

          for i = start_line, end_line do
            if edit_step == 0 or (i - start_line) % edit_step == 0 then
              local line = song:pattern(pattern_index):track(track_idx):line(i)
              local note_column = line.note_columns[column_index]
              note_column.note_value = note_value
              note_column.instrument_value = instrument_value
            end
          end
        end
      end
    end
  end

  -- Inform the user that the operation was successful
  renoise.app():show_status("Track / Selection filled with the Current Note and Instrument with EditStep.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Flood Fill Note and Instrument with EditStep",invoke=pakettiFloodFillWithEditStep}
renoise.tool():add_midi_mapping{name="Paketti:Flood Fill Note and Instrument with EditStep",invoke=pakettiFloodFillWithEditStep}


--------------------
-- Function to Flood Fill the track with the current note, instrument, volume, delay, panning, and sample FX with an edit step
function pakettiFloodFillWithNotReallyEditStep(notstep)
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]

  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local edit_step = notstep
  local note_column_index = song.selected_note_column_index

  local selection = song.selection_in_pattern
  local start_line, end_line, start_track, end_track, start_column, end_column

  if selection then
    start_line = selection.start_line
    end_line = selection.end_line
    start_track = selection.start_track
    end_track = selection.end_track
    start_column = selection.start_column
    end_column = selection.end_column
  else
    start_line = line_index
    end_line = pattern.number_of_lines
    start_track = track_index
    end_track = track_index
    start_column = note_column_index
    end_column = note_column_index
  end

  if notstep > (end_line - start_line + 1) then
    renoise.app():show_status("EditStep is larger than the number of lines in the pattern.")
    return
  end

  local found_note = false
  local note_values = {}
  local instrument_values = {}
  local volume_values = {}
  local delay_values = {}
  local panning_values = {}
  local samplefx_values = {}

  local effect_number_values = {}
  local effect_amount_values = {}
  local clear_columns = {}
  local clear_effect_columns = {}

  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    if track.type ~= renoise.Track.TRACK_TYPE_GROUP and track.type ~= renoise.Track.TRACK_TYPE_SEND and track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      note_values[track_idx] = {}
      instrument_values[track_idx] = {}
      volume_values[track_idx] = {}
      delay_values[track_idx] = {}
      panning_values[track_idx] = {}
      samplefx_values[track_idx] = {}
      clear_columns[track_idx] = {}

      effect_number_values[track_idx] = {}
      effect_amount_values[track_idx] = {}
      clear_effect_columns[track_idx] = {}

      local first_column = (track_idx == start_track) and start_column or 1
      local last_column = (track_idx == end_track) and end_column or track.visible_note_columns

      -- Read Note Columns
      for column_index = first_column, last_column do
        local current_note_column = song:pattern(pattern_index):track(track_idx):line(line_index).note_columns[column_index]
        if current_note_column and not current_note_column.is_empty then
          note_values[track_idx][column_index] = current_note_column.note_value
          instrument_values[track_idx][column_index] = current_note_column.instrument_value
          volume_values[track_idx][column_index] = current_note_column.volume_value
          delay_values[track_idx][column_index] = current_note_column.delay_value
          panning_values[track_idx][column_index] = current_note_column.panning_value
          samplefx_values[track_idx][column_index] = current_note_column.effect_number_value
          clear_columns[track_idx][column_index] = true
          found_note = true
        else
          clear_columns[track_idx][column_index] = false
        end
      end

      -- Read Effect Columns
      for effect_idx = 1, track.visible_effect_columns do
        local effect_column = song:pattern(pattern_index):track(track_idx):line(line_index).effect_columns[effect_idx]
        if effect_column and not effect_column.is_empty then
          effect_number_values[track_idx][effect_idx] = effect_column.number_value
          effect_amount_values[track_idx][effect_idx] = effect_column.amount_value
          clear_effect_columns[track_idx][effect_idx] = true
          found_note = true
        else
          clear_effect_columns[track_idx][effect_idx] = false
        end
      end
    end
  end

  if not found_note then
    renoise.app():show_status("There was nothing to Flood Fill with EditStep with.")
    return
  end

  -- Clear note columns and effect columns if needed
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    if track.type ~= renoise.Track.TRACK_TYPE_GROUP and track.type ~= renoise.Track.TRACK_TYPE_SEND and track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      local first_column = (track_idx == start_track) and start_column or 1
      local last_column = (track_idx == end_track) and end_column or track.visible_note_columns

      -- Clear Note Columns
      for column_index = first_column, last_column do
        if clear_columns[track_idx][column_index] then
          for i = start_line, end_line do
            if selection then
              if i ~= start_line then
                local line = song:pattern(pattern_index):track(track_idx):line(i)
                local note_column = line.note_columns[column_index]
                note_column:clear()
              end
            else
              if i ~= line_index then
                local line = song:pattern(pattern_index):track(track_idx):line(i)
                local note_column = line.note_columns[column_index]
                note_column:clear()
              end
            end
          end
        end
      end

      -- Clear Effect Columns
      for effect_idx = 1, track.visible_effect_columns do
        if clear_effect_columns[track_idx][effect_idx] then
          for i = start_line, end_line do
            if selection then
              if i ~= start_line then
                local effect_column = song:pattern(pattern_index):track(track_idx):line(i).effect_columns[effect_idx]
                effect_column:clear()
              end
            else
              if i ~= line_index then
                local effect_column = song:pattern(pattern_index):track(track_idx):line(i).effect_columns[effect_idx]
                effect_column:clear()
              end
            end
          end
        end
      end
    end
  end

  -- Apply note columns and effect columns values with EditStep
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    if track.type ~= renoise.Track.TRACK_TYPE_GROUP and track.type ~= renoise.Track.TRACK_TYPE_SEND and track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      local first_column = (track_idx == start_track) and start_column or 1
      local last_column = (track_idx == end_track) and end_column or track.visible_note_columns

      -- Apply Note Columns
      for column_index = first_column, last_column do
        if note_values[track_idx][column_index] then
          local note_value = note_values[track_idx][column_index]
          local instrument_value = instrument_values[track_idx][column_index]
          local volume_value = volume_values[track_idx][column_index]
          local delay_value = delay_values[track_idx][column_index]
          local panning_value = panning_values[track_idx][column_index]
          local samplefx_value = samplefx_values[track_idx][column_index]

          for i = start_line, end_line do
            if edit_step == 0 or (i - start_line) % edit_step == 0 then
              local line = song:pattern(pattern_index):track(track_idx):line(i)
              local note_column = line.note_columns[column_index]
              note_column.note_value = note_value
              note_column.instrument_value = instrument_value
              note_column.volume_value = volume_value
              note_column.delay_value = delay_value
              note_column.panning_value = panning_value
              note_column.effect_number_value = samplefx_value
            end
          end
        end
      end

      -- Apply Effect Columns
      for effect_idx = 1, track.visible_effect_columns do
        if effect_number_values[track_idx][effect_idx] then
          local effect_number = effect_number_values[track_idx][effect_idx]
          local effect_amount = effect_amount_values[track_idx][effect_idx]

          for i = start_line, end_line do
            if edit_step == 0 or (i - start_line) % edit_step == 0 then
              local effect_column = song:pattern(pattern_index):track(track_idx):line(i).effect_columns[effect_idx]
              effect_column.number_value = effect_number
              effect_column.amount_value = effect_amount
            end
          end
        end
      end
    end
  end

  renoise.app():show_status("Track/Selection filled with Note, Instrument, Volume, Delay, Panning, Sample FX, and Effect Columns every " .. notstep .. " step(s).")
end


for i=1,64 do
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Flood Fill Note and Instrument every " .. i .. " step",invoke=function() pakettiFloodFillWithNotReallyEditStep(i) end}
end














-----------
local dialog
local track_index = 1
local selected_tracks = {}
local vb = renoise.ViewBuilder()

-- Function to show the track renamer dialog
function pakettiTrackRenamerDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  -- Get the current selection in the pattern
  local selection = renoise.song().selection_in_pattern
  selected_tracks = {}

  -- Check if there is a selection
  if selection then
    for i = selection.start_track, selection.end_track do
      table.insert(selected_tracks, i)
    end
  else
    -- If no selection, use the currently selected track
    table.insert(selected_tracks, renoise.song().selected_track_index)
  end

  -- Reset track index
  track_index = 1

  -- Debugging: print selected tracks
  print("Selected tracks: ", table.concat(selected_tracks, ", "))

  -- Show the dialog for the first track in the selection
  ShowRenameDialogForTrack(track_index)
end

-- Function to show the renaming dialog for a specific track
function ShowRenameDialogForTrack(index)
  local track_index = selected_tracks[index]
  local selected_track = renoise.song().tracks[track_index]
  local initial_name = selected_track.name

  local function closeRD_dialog()
    if dialog and dialog.visible then
      dialog:close()
    end
  end

  local function rename_track_and_close(new_name)
    selected_track.name = new_name
    closeRD_dialog()
    -- Move to the next track in the selection
    index = index + 1
    if index <= #selected_tracks then
      ShowRenameDialogForTrack(index)
    end
  end

  -- Create a new ViewBuilder instance
  vb = renoise.ViewBuilder()
  local text_field = vb:textfield{
    id = "track_name_field",
    text = initial_name,
    width=200,
    edit_mode = true,
    notifier=function(new_name)
      if new_name ~= initial_name then
        rename_track_and_close(new_name)
      end
    end
  }

  local function key_handler(dialog, key)
    local closer = preferences.pakettiDialogClose.value
    if key.name == "return" and not key.repeated then
      rename_track_and_close(vb.views.track_name_field.text)
      return
    elseif key.modifiers == "" and key.name == closer then
      closeRD_dialog()
      return
    else
      return key
    end
  end

  local dialog_content = vb:column{
    margin=10,
    vb:row{
      vb:text{
        text="Track Name:"
      },
      text_field
    },
    vb:row{
      margin=10,
      vb:button{
        text="OK",
        width=50,
        notifier=function() rename_track_and_close(vb.views.track_name_field.text) end
      },
      vb:button{
        text="Cancel",
        width=50,
        notifier = closeRD_dialog
      }
    }
  }

  -- Show the dialog
  dialog = renoise.app():show_custom_dialog("Paketti Track Renamer", dialog_content, key_handler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Track Renamer Dialog...",invoke=pakettiTrackRenamerDialog}
renoise.tool():add_keybinding{name="Mixer:Paketti:Paketti Track Renamer Dialog...",invoke=pakettiTrackRenamerDialog}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Paketti Track Renamer Dialog...",invoke=pakettiTrackRenamerDialog}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Paketti Track Renamer Dialog...",invoke=pakettiTrackRenamerDialog}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Track Renamer",invoke=pakettiTrackRenamerDialog}

-----
function effectbypasspattern()
local currTrak = renoise.song().selected_track_index
local number = (table.count(renoise.song().selected_track.devices))
 for i=2,number  do 
  --renoise.song().selected_track.devices[i].is_active=false
  renoise.song().selected_track.visible_effect_columns=(table.count(renoise.song().selected_track.devices)-1)
--This would be (1-8F)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[1].number_string="10"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[2].number_string="20"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[3].number_string="30"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[4].number_string="40"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[5].number_string="50"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[6].number_string="60"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[7].number_string="70"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[8].number_string="80"
--this would be 00 for disabling
local ooh=(i-1)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[ooh].amount_string="00"
 end
end

function effectenablepattern()
local currTrak = renoise.song().selected_track_index
local number = (table.count(renoise.song().selected_track.devices))
for i=2,number  do 
--enable all plugins on selected track right now
--renoise.song().selected_track.devices[i].is_active=true
--display max visible effects
local helper=(table.count(renoise.song().selected_track.devices)-1)
renoise.song().selected_track.visible_effect_columns=helper
--This would be (1-8F)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[1].number_string="10"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[2].number_string="20"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[3].number_string="30"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[4].number_string="40"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[5].number_string="50"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[6].number_string="60"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[7].number_string="70"
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[8].number_string="80"

--this would be 01 for enabling
local ooh=(i-1)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[currTrak].lines[1].effect_columns[ooh].amount_string="01"
end
end
------


-----
function patternEditorSelectedLastTrack()
renoise.song().selected_track_index=#renoise.song().tracks
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Select Last Track",invoke=function() patternEditorSelectedLastTrack() end}
----------
function wipeSelectedTrackTrackDSPs()

    for i = #renoise.song().selected_track.devices, 2, -1 do
      renoise.song().selected_track:delete_device_at(i)
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Clear/Wipe Selected Track TrackDSPs",invoke=function() wipeSelectedTrackTrackDSPs() end}

------

-- Function to toggle note off in all visible note columns
function PakettiToggleNoteOffAllColumns()
  local s = renoise.song()
  
  if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      -- Pattern Editor handling
      local track = s.selected_track
      local line = s.selected_line
      local count = track.visible_note_columns
      
      -- Count how many columns are OFF vs empty
      local off_count = 0
      local empty_or_off_count = 0
      for i = 1, count do
          if line.note_columns[i].note_string == "OFF" then
              off_count = off_count + 1
              empty_or_off_count = empty_or_off_count + 1
          elseif line.note_columns[i].note_value == 121 then -- empty note
              empty_or_off_count = empty_or_off_count + 1
          end
      end
      
      -- If all empty/OFF columns are OFF, clear them. Otherwise, set empty columns to OFF
      local should_clear = (off_count == empty_or_off_count and empty_or_off_count > 0)
      
      for i = 1, count do
          if line.note_columns[i].note_string == "OFF" or
             line.note_columns[i].note_value == 121 then
              line.note_columns[i].note_string = should_clear and "" or "OFF"
              if not should_clear then
                  line.note_columns[i].instrument_value = 255  -- Clear instrument column
              end
          end
      end
      renoise.app():show_status("Toggled Note Off in empty columns")
      
  elseif renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
      -- Ensure Renoise API version 6.2 or higher
      if renoise.API_VERSION < 6.2 then
          renoise.app():show_status("This feature requires Renoise API version 6.2 or higher.")
          return
      end
      
      -- Phrase Editor handling
      local phrase = s.selected_phrase
      if not phrase then
          renoise.app():show_status("No phrase selected")
          return
      end
      
      local line = phrase.lines[s.selected_phrase_line_index]
      local count = phrase.visible_note_columns
      
      -- Count how many columns are OFF vs empty
      local off_count = 0
      local empty_or_off_count = 0
      for i = 1, count do
          if line.note_columns[i].note_string == "OFF" then
              off_count = off_count + 1
              empty_or_off_count = empty_or_off_count + 1
          elseif line.note_columns[i].note_value == 121 then -- empty note
              empty_or_off_count = empty_or_off_count + 1
          end
      end
      
      -- If all empty/OFF columns are OFF, clear them. Otherwise, set empty columns to OFF
      local should_clear = (off_count == empty_or_off_count and empty_or_off_count > 0)
      
      for i = 1, count do
          if line.note_columns[i].note_string == "OFF" or
             line.note_columns[i].note_value == 121 then
              line.note_columns[i].note_string = should_clear and "" or "OFF"
              if not should_clear then
                  line.note_columns[i].instrument_value = 255  -- Clear instrument column
              end
          end
      end
      renoise.app():show_status("Toggled Note Off in empty phrase columns")
  end
end

-- Function to toggle note off on all tracks on current row
function PakettiToggleNoteOffAllTracks(target_line_index, target_pattern_index)
  local s = renoise.song()

  -- Resolve target pattern index
  local pattern_index
  if type(target_pattern_index) == "number" then
    pattern_index = target_pattern_index
  else
    if target_pattern_index ~= nil then
      print("PakettiToggleNoteOffAllTracks: non-number target_pattern_index=", tostring(target_pattern_index), ", defaulting to selected pattern")
    end
    pattern_index = s.selected_pattern_index
  end
  if pattern_index < 1 then pattern_index = 1 end
  if pattern_index > #s.patterns then pattern_index = #s.patterns end

  -- Resolve target line index (0 means first row)
  local line_index
  if type(target_line_index) ~= "number" then
    if target_line_index ~= nil then
      print("PakettiToggleNoteOffAllTracks: non-number target_line_index=", tostring(target_line_index), ", defaulting to selected line")
    end
    line_index = s.selected_line_index
  else
    if target_line_index <= 0 then
      line_index = 1
    else
      line_index = target_line_index
    end
  end

  -- Clamp to pattern bounds
  local max_lines = s.patterns[pattern_index].number_of_lines
  if line_index < 1 then line_index = 1 end
  if line_index > max_lines then line_index = max_lines end

  -- Count how many columns are OFF vs empty across all regular tracks on the target line
  local off_count = 0
  local empty_or_off_count = 0

  for t = 1, #s.tracks do
    local track = s:track(t)
    if not (track.type == renoise.Track.TRACK_TYPE_GROUP or 
            track.type == renoise.Track.TRACK_TYPE_MASTER or 
            track.type == renoise.Track.TRACK_TYPE_SEND) then
      local line = s.patterns[pattern_index]:track(t):line(line_index)
      local count = track.visible_note_columns
      for i = 1, count do
        if line.note_columns[i].note_string == "OFF" then
          off_count = off_count + 1
          empty_or_off_count = empty_or_off_count + 1
        elseif line.note_columns[i].note_value == 121 then
          empty_or_off_count = empty_or_off_count + 1
        end
      end
    end
  end

  -- If all empty/OFF columns are OFF, clear them. Otherwise, set empty columns to OFF
  local should_clear = (off_count == empty_or_off_count and empty_or_off_count > 0)

  for t = 1, #s.tracks do
    local track = s:track(t)
    if not (track.type == renoise.Track.TRACK_TYPE_GROUP or 
            track.type == renoise.Track.TRACK_TYPE_MASTER or 
            track.type == renoise.Track.TRACK_TYPE_SEND) then
      local line = s.patterns[pattern_index]:track(t):line(line_index)
      local count = track.visible_note_columns
      for i = 1, count do
        if line.note_columns[i].note_string == "OFF" or
           line.note_columns[i].note_value == 121 then
          line.note_columns[i].note_string = should_clear and "" or "OFF"
          if not should_clear then
            line.note_columns[i].instrument_value = 255  -- Clear instrument column
          end
        end
      end
    end
  end
  renoise.app():show_status("Toggled Note Off in empty columns across tracks")
end

-- Function to place note-offs in all visible note columns without toggling
function PakettiPlaceNoteOffAllColumns()
  local s = renoise.song()
  
  if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      -- Pattern Editor handling
      local track = s.selected_track
      local line = s.selected_line
      local count = track.visible_note_columns
      
      for i = 1, count do
          line.note_columns[i].note_string = "OFF"
          line.note_columns[i].instrument_value = 255  -- Clear instrument
      end
      renoise.app():show_status("Placed Note Off in all visible note columns")
      
  elseif renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
      -- Phrase Editor handling
      local phrase = s.selected_instrument.phrases[s.selected_phrase_index]
      if phrase then
          local line = phrase:line(s.selected_line_index)
          local count = phrase.visible_note_columns
          
          for i = 1, count do
              line.note_columns[i].note_string = "OFF"
              line.note_columns[i].instrument_value = 255  -- Clear instrument
          end
          renoise.app():show_status("Placed Note Off in all visible phrase note columns")
      end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Note Off in All Visible Note Columns",  invoke = PakettiToggleNoteOffAllColumns}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Place Note Off in All Visible Note Columns",  invoke = PakettiPlaceNoteOffAllColumns}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Note Off on All Tracks on Current Row",invoke = PakettiToggleNoteOffAllTracks}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Toggle Note Off in All Visible Note Columns",invoke = PakettiToggleNoteOffAllColumns}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Place Note Off in All Visible Note Columns",invoke = PakettiPlaceNoteOffAllColumns}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Toggle Note Off on All Tracks on Current Row",invoke = PakettiToggleNoteOffAllTracks}

renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Toggle Note Off in All Visible Note Columns [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiToggleNoteOffAllColumns()
    end
  end
}

renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Place Note Off in All Visible Note Columns [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiPlaceNoteOffAllColumns()
    end
  end
}

renoise.tool():add_midi_mapping{name="Pattern Editor:Paketti:Toggle Note Off on All Tracks on Current Row [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiToggleNoteOffAllTracks()
    end
  end
}

renoise.tool():add_midi_mapping{name="Phrase Editor:Paketti:Toggle Note Off in All Visible Note Columns [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiToggleNoteOffAllColumns()
    end
  end
}

renoise.tool():add_midi_mapping{name="Phrase Editor:Paketti:Place Note Off in All Visible Note Columns [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiPlaceNoteOffAllColumns()
    end
  end
}

renoise.tool():add_midi_mapping{name="Phrase Editor:Paketti:Toggle Note Off on All Tracks on Current Row [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiToggleNoteOffAllTracks()
    end
  end
}

-- Menu entries for Pattern Matrix, Pattern Sequencer, Pattern Editor
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=function() PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=function() PakettiNoteOffs_AllTracks_FirstRow_FirstPattern() end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=function() PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern() end}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=function() PakettiNoteOffs_AllTracks_FirstRow_FirstPattern() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=function() PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=function() PakettiNoteOffs_AllTracks_FirstRow_FirstPattern() end}

-- Keybindings for Pattern Matrix, Pattern Sequencer, Pattern Editor, and Global
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=PakettiNoteOffs_AllTracks_FirstRow_FirstPattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=PakettiNoteOffs_AllTracks_FirstRow_FirstPattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=PakettiNoteOffs_AllTracks_FirstRow_FirstPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Note Offs to All Tracks for First Row of Current Pattern", invoke=PakettiNoteOffs_AllTracks_FirstRow_CurrentPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Note Offs to All Tracks for First Pattern of Song, First Row", invoke=PakettiNoteOffs_AllTracks_FirstRow_FirstPattern}
-------



--------------
local function insert_random_value(mode)
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local pattern = song.selected_pattern
  local pattern_tracks = pattern.tracks

  -- Print the current selection_in_pattern
  if selection then
    print("Selection details: start_track =", selection.start_track, "end_track =", selection.end_track,
          "start_line =", selection.start_line, "end_line =", selection.end_line,
          "start_column =", selection.start_column, "end_column =", selection.end_column)
  else
    print("No selection, processing current row.")
  end

  -- If no selection, apply to the current row in the selected track
  if selection == nil then
    local track = song.selected_track
    local line_index = song.selected_line_index
    local pattern_track = pattern_tracks[song.selected_track_index]

    -- Check if the track is Group, Master, or Send
    if song.tracks[song.selected_track_index].type == renoise.Track.TRACK_TYPE_GROUP or 
       song.tracks[song.selected_track_index].type == renoise.Track.TRACK_TYPE_MASTER or 
       song.tracks[song.selected_track_index].type == renoise.Track.TRACK_TYPE_SEND then
      renoise.app():show_status("There are no Note Columns on a Track of this type")
      print("Skipped Group/Master/Send track:", song.selected_track_index)
    return
  end
  
    -- Print track details
    print("Processing track:", song.selected_track_index, "with", track.visible_note_columns, "note columns and",
          track.visible_effect_columns, "effect columns")

    -- Ensure corresponding columns are visible
    if mode == "delay" and not track.delay_column_visible then
      track.delay_column_visible = true
    elseif mode == "panning" and not track.panning_column_visible then
      track.panning_column_visible = true
    elseif mode == "volume" and not track.volume_column_visible then
      track.volume_column_visible = true
    end

    -- Insert random values into the selected line's visible note columns
    for col = selection.start_column, selection.start_column do
      local note_column = pattern_track.lines[line_index].note_columns[col]
      if note_column then
        if mode == "delay" then
          note_column.delay_value = math.random(0, 255)
          print("Inserted random delay value to track:", song.selected_track_index, "line:", line_index, "column:", col)
        elseif mode == "panning" then
          note_column.panning_value = math.random(0, 127)
          print("Inserted random panning value to track:", song.selected_track_index, "line:", line_index, "column:", col)
        elseif mode == "volume" then
          note_column.volume_value = math.random(0, 127)
          print("Inserted random volume value to track:", song.selected_track_index, "line:", line_index, "column:", col)
        end
      end
    end

    renoise.app():show_status("Inserted random " .. mode .. " values to selected row")
    print("Finished processing track:", song.selected_track_index)

  else
    -- Fix the selection column order (in case start_column is greater than end_column)
    local fixed_start_column = math.min(selection.start_column, selection.end_column)
    local fixed_end_column = math.max(selection.start_column, selection.end_column)

    -- Apply across the selection in the pattern
    for track_idx = selection.start_track, selection.end_track do
      local song_track = song.tracks[track_idx]
      local pattern_track = pattern_tracks[track_idx]

      -- Print track details
      print("Processing track:", track_idx, "with", song_track.visible_note_columns, "note columns and",
            song_track.visible_effect_columns, "effect columns")

      -- Skip Group, Master, and Send tracks
      if song_track.type == renoise.Track.TRACK_TYPE_GROUP or 
         song_track.type == renoise.Track.TRACK_TYPE_MASTER or 
         song_track.type == renoise.Track.TRACK_TYPE_SEND then
        print("Skipped Group/Master/Send track:", track_idx)
      else
        -- Ensure the corresponding columns are visible
        if mode == "delay" and not song_track.delay_column_visible then
          song_track.delay_column_visible = true
        elseif mode == "panning" and not song_track.panning_column_visible then
          song_track.panning_column_visible = true
        elseif mode == "volume" and not song_track.volume_column_visible then
          song_track.volume_column_visible = true
        end

        -- Track-specific column bounds, adjusted for each track's visible note columns
        local track_start_column = (track_idx == selection.start_track) and fixed_start_column or 1
        local track_end_column = (track_idx == selection.end_track) and fixed_end_column or song_track.visible_note_columns

        -- Print selected columns in this track
        print("Selected note columns in track:", track_idx, "from", track_start_column, "to", track_end_column)

        -- Apply random values within the selected columns and lines
        for line_idx = selection.start_line, selection.end_line do
          local line = pattern_track.lines[line_idx]

          -- Process note columns within the per-track selection range
          for col = track_start_column, track_end_column do
            local note_column = line.note_columns[col]
            if note_column then
              if mode == "delay" then
                note_column.delay_value = math.random(0, 255)
                print("Inserted random delay value to track:", track_idx, "line:", line_idx, "column:", col)
              elseif mode == "panning" then
                note_column.panning_value = math.random(0, 127)
                print("Inserted random panning value to track:", track_idx, "line:", line_idx, "column:", col)
              elseif mode == "volume" then
                note_column.volume_value = math.random(0, 127)
                print("Inserted random volume value to track:", track_idx, "line:", line_idx, "column:", col)
              end
            else
              print("No note column found in track:", track_idx, "line:", line_idx, "column:", col)
            end
          end
        end
      end
    end

    renoise.app():show_status("Inserted random " .. mode .. " values across selection")
    print("Finished processing selection")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Insert Random Delay to Selected Row",invoke=function()insert_random_value("delay")end}
renoise.tool():add_keybinding{name="Global:Paketti:Insert Random Panning to Selected Row",invoke=function()insert_random_value("panning")end}
renoise.tool():add_keybinding{name="Global:Paketti:Insert Random Volume to Selected Row",invoke=function()insert_random_value("volume")end}

renoise.tool():add_midi_mapping{name="Paketti:Insert Random Delay to Selected Row",invoke=function()insert_random_value("delay")end}
renoise.tool():add_midi_mapping{name="Paketti:Insert Random Panning to Selected Row",invoke=function()insert_random_value("panning")end}
renoise.tool():add_midi_mapping{name="Paketti:Insert Random Volume to Selected Row",invoke=function()insert_random_value("volume")end}


-- Generic replication function that handles both selection and cursor-based replication
function PakettiGenericReplicate(row_option, replicate_callback, status_message_callback, ignore_selection)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local cursor_row = song.selected_line_index
  local pattern_length = pattern.number_of_lines
  local selected_track_index = song.selected_track_index
  local selection = song.selection_in_pattern
  
  local repeat_length, start_row, source_start_row
  local status_suffix
  
  -- Check if there's a selection (and we're not ignoring it)
  if selection and not ignore_selection then
    -- Selection-based replication
    local selection_start = selection.start_line
    local selection_end = selection.end_line
    
    -- Validate that the selection is in the current track
    if selection.start_track ~= selected_track_index or selection.end_track ~= selected_track_index then
      renoise.app():show_status("Selection must be within a single track column.")
      return
    end
    
    -- Calculate repeat length from selection
    repeat_length = selection_end - selection_start + 1
    
    -- Start replicating from the row after the selection
    start_row = selection_end + 1
    
    -- Source starts from the beginning of the selection
    source_start_row = selection_start
    
    if start_row > pattern_length then
      renoise.app():show_status("Selection is at the end of pattern, nothing to replicate.")
      return
    end
    
    status_suffix = " (from selection)"
  else
    -- No selection: use original "above cursor" or "above + current" logic
    if (cursor_row == pattern_length and row_option == "above_and_current") then
      renoise.app():show_status("No rows to replicate.")
      return
    end
    if (cursor_row == 1 and row_option == "above_current") then
      row_option = "above_and_current"
    end

    -- Determine the repeat_length and starting row based on row_option
    if row_option == "above_current" then
      if cursor_row == 1 then
        renoise.app():show_status("You are on the first row, nothing to replicate.")
        return
      end
      repeat_length = cursor_row - 1
      start_row = cursor_row
      source_start_row = 1
    elseif row_option == "above_and_current" then
      repeat_length = cursor_row
      start_row = cursor_row + 1
      source_start_row = 1
      if cursor_row == pattern_length then
        renoise.app():show_status("You are on the last row, nothing to replicate.")
        return
      end
    else
      renoise.app():show_status("Invalid row option: " .. tostring(row_option))
      return
    end

    status_suffix = (row_option == "above_current") and " (above current)" or " (above + current)"
  end

  if repeat_length == 0 then
    renoise.app():show_status("No rows to replicate.")
    return
  end
  
  -- Perform the replication using the callback
  for row = start_row, pattern_length do
    local source_row = source_start_row + ((row - start_row) % repeat_length)
    local source_line = pattern:track(selected_track_index):line(source_row)
    local dest_line = pattern:track(selected_track_index):line(row)
    
    replicate_callback(source_line, dest_line)
  end

  -- Display status message
  if status_message_callback then
    renoise.app():show_status(status_message_callback() .. status_suffix)
  end
end

-- Function to replicate current note or effect column content
function PakettiReplicateNoteColumnAtCursor(transpose, row_option)
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_note_column_index = song.selected_note_column_index
  local selected_effect_column_index = song.selected_effect_column_index
  
  -- Determine if we're on a note column or effect column
  local is_effect_column = (selected_effect_column_index > 0)
  
  transpose = transpose or 0

  local function transpose_note(note_value, transpose_amount)
    local min_note = 0
    local max_note = 119
    if note_value >= min_note and note_value <= max_note then
      local new_note = note_value + transpose_amount
      if new_note > max_note then new_note = max_note
      elseif new_note < min_note then new_note = min_note end
      return new_note
    else
      return note_value
    end
  end

  -- Callback function for full column replication
  local function replicate_full_column(source_line, dest_line)
    if is_effect_column then
      -- Handle effect column replication
      local source_fx = source_line.effect_columns[selected_effect_column_index]
      local dest_fx = dest_line.effect_columns[selected_effect_column_index]
      
      if source_fx and dest_fx then
        dest_fx.number_value = source_fx.number_value
        dest_fx.amount_value = source_fx.amount_value
      end
    else
      -- Handle note column replication
      local source_note = source_line.note_columns[selected_note_column_index]
      local dest_note = dest_line.note_columns[selected_note_column_index]
      
      if source_note and dest_note then
        dest_note.note_value = transpose_note(source_note.note_value, transpose)
        dest_note.instrument_value = source_note.instrument_value
        dest_note.volume_value = source_note.volume_value
        dest_note.panning_value = source_note.panning_value
        dest_note.delay_value = source_note.delay_value
        dest_note.effect_number_value = source_note.effect_number_value
        dest_note.effect_amount_value = source_note.effect_amount_value
      end
    end
  end

  -- Status message callback
  local function status_message()
    if is_effect_column then
      return "Replicated effect column"
    else
      return "Replicated note column with transpose: " .. transpose
    end
  end

  -- Always ignore selections for full column replication (true = ignore_selection)
  PakettiGenericReplicate(row_option, replicate_full_column, status_message, true)
end

-- Helper function for subcolumn replication logic
local function replicate_subcolumn_content(subcolumn_type, is_note_column, is_effect_column, 
                                          selected_note_column_index, selected_effect_column_index, 
                                          source_line, dest_line)
  if subcolumn_type == renoise.Song.SUB_COLUMN_NOTE and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.note_value = source_note.note_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_INSTRUMENT and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.instrument_value = source_note.instrument_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_VOLUME and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.volume_value = source_note.volume_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_PANNING and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.panning_value = source_note.panning_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_DELAY and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.delay_value = source_note.delay_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.effect_number_value = source_note.effect_number_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT and is_note_column then
    local source_note = source_line.note_columns[selected_note_column_index]
    local dest_note = dest_line.note_columns[selected_note_column_index]
    if source_note and dest_note then
      dest_note.effect_amount_value = source_note.effect_amount_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER and is_effect_column then
    local source_fx = source_line.effect_columns[selected_effect_column_index]
    local dest_fx = dest_line.effect_columns[selected_effect_column_index]
    if source_fx and dest_fx then
      dest_fx.number_value = source_fx.number_value
    end
    
  elseif subcolumn_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT and is_effect_column then
    local source_fx = source_line.effect_columns[selected_effect_column_index]
    local dest_fx = dest_line.effect_columns[selected_effect_column_index]
    if source_fx and dest_fx then
      dest_fx.amount_value = source_fx.amount_value
    end
  end
end

-- Function to replicate the currently selected subcolumn
function PakettiReplicateSelectedSubcolumn(row_option)
  local song = renoise.song()
  local selected_note_column_index = song.selected_note_column_index
  local selected_effect_column_index = song.selected_effect_column_index
  
  -- Get current subcolumn type
  local subcolumn_type, subcolumn_name = whichSubcolumn()
  
  -- Determine which column we're working with
  local is_note_column = (selected_note_column_index > 0)
  local is_effect_column = (selected_effect_column_index > 0)
  
  if not is_note_column and not is_effect_column then
    renoise.app():show_status("No valid column selected.")
    return
  end
  
  -- Callback function for subcolumn replication
  local function replicate_subcolumn(source_line, dest_line)
    replicate_subcolumn_content(subcolumn_type, is_note_column, is_effect_column,
                               selected_note_column_index, selected_effect_column_index,
                               source_line, dest_line)
  end
  
  -- Status message callback
  local function status_message()
    return "Replicated " .. subcolumn_name .. " subcolumn"
  end
  
  -- Allow selections for subcolumn replication (false = don't ignore_selection)
  PakettiGenericReplicate(row_option, replicate_subcolumn, status_message, false)
end

-- Helper function for column replication
local function create_column_replicate_function(transpose, row_option)
  return function()
    PakettiReplicateNoteColumnAtCursor(transpose, row_option)
  end
end

-- Options for transpose and rows for column replication
local transpose_options = {
  {value = -12, name = "(-12)"},
  {value = -1, name = "(-1)"},
  {value = 0, name = ""},
  {value = 1, name = "(+1)"},
  {value = 12, name = "(+12)"},
}

local row_options = {
  {value = "above_current", name = "Above Current Row"},
  {value = "above_and_current", name = "Above + Current"},
}

-- Create menu entries, keybindings, and MIDI mappings for column replication
for _, row_opt in ipairs(row_options) do
  for _, transpose_opt in ipairs(transpose_options) do
    local replicate_function = create_column_replicate_function(transpose_opt.value, row_opt.value)
    
    -- For note columns
    local note_menu_entry_name = "Pattern Editor:Paketti:Replicate:Replicate Note/FX Column " .. row_opt.name .. " " .. transpose_opt.name
    renoise.tool():add_menu_entry{name=note_menu_entry_name,invoke=replicate_function}
    
    local note_keybinding_name = "Pattern Editor:Paketti:Replicate Note/FX Column " .. row_opt.name .. " " .. transpose_opt.name
    renoise.tool():add_keybinding{name=note_keybinding_name,invoke=replicate_function}
    
    local note_midi_mapping_name = "Paketti:Replicate Note/FX Column " .. row_opt.name .. " " .. transpose_opt.name
    renoise.tool():add_midi_mapping{name=note_midi_mapping_name,invoke=function(message)
      if message:is_trigger() then
        replicate_function()
      end
    end}
  end
end

-- Menu entries, keybindings, and MIDI mappings for subcolumn replication
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Replicate:Replicate Selected Subcolumn Above Current Row", invoke=function()
  PakettiReplicateSelectedSubcolumn("above_current")
end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Replicate Selected Subcolumn Above Current Row", invoke=function()
  PakettiReplicateSelectedSubcolumn("above_current")
end}
renoise.tool():add_midi_mapping{name="Paketti:Replicate Selected Subcolumn Above Current Row", invoke=function(message)
  if message:is_trigger() then
    PakettiReplicateSelectedSubcolumn("above_current")
  end
end}

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Replicate:Replicate Selected Subcolumn Above + Current", invoke=function()
  PakettiReplicateSelectedSubcolumn("above_and_current")
end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Replicate Selected Subcolumn Above + Current", invoke=function()
  PakettiReplicateSelectedSubcolumn("above_and_current")
end}
renoise.tool():add_midi_mapping{name="Paketti:Replicate Selected Subcolumn Above + Current", invoke=function(message)
  if message:is_trigger() then
    PakettiReplicateSelectedSubcolumn("above_and_current")
  end
end}

-------
-- Replicate Above Into Selection Only (Pattern Editor version)
-- Takes content from row 1 to (selection.start_line - 1) and fills only the selection
local function PakettiReplicateAboveIntoSelectionPattern()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  -- Require a selection
  if not selection then
    renoise.app():show_status("No selection in pattern.")
    return
  end
  
  local selection_start = selection.start_line
  local selection_end = selection.end_line
  local start_track = selection.start_track
  local end_track = selection.end_track
  
  -- Need at least 1 row above the selection as source
  if selection_start <= 1 then
    renoise.app():show_status("No content above selection to replicate.")
    return
  end
  
  local source_length = selection_start - 1  -- rows 1 to selection_start-1
  local pattern_index = song.selected_pattern_index
  
  -- Store source data from rows 1 to (selection_start - 1)
  local source_data = {}
  
  -- Iterate over the selected tracks
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    
    -- Skip non-sequencer tracks
    if track.type == renoise.Track.TRACK_TYPE_GROUP or 
       track.type == renoise.Track.TRACK_TYPE_SEND or 
       track.type == renoise.Track.TRACK_TYPE_MASTER then
      -- Skip this track
    else
      local pattern_track = song:pattern(pattern_index):track(track_idx)
      local num_note_columns = track.visible_note_columns
      local num_effect_columns = track.visible_effect_columns
      local total_columns = num_note_columns + num_effect_columns
      
      -- Determine start and end columns for the current track
      local track_start_column = (track_idx == start_track) and selection.start_column or 1
      local track_end_column = (track_idx == end_track) and selection.end_column or total_columns
      
      -- Store the data for this track
      source_data[track_idx] = {}
      
      -- Capture source data from rows 1 to (selection_start - 1)
      for row = 1, source_length do
        source_data[track_idx][row] = {}
        for col_idx = track_start_column, track_end_column do
          if col_idx <= num_note_columns then
            -- Capture note column data
            local note_column = pattern_track:line(row).note_columns[col_idx]
            source_data[track_idx][row][col_idx] = {
              note = note_column.note_value,
              instrument = note_column.instrument_value,
              volume = note_column.volume_value,
              panning = note_column.panning_value,
              delay = note_column.delay_value,
              effect_number = note_column.effect_number_value,
              effect_amount = note_column.effect_amount_value
            }
          elseif col_idx > num_note_columns and col_idx <= total_columns then
            -- Capture effect column data
            local effect_col_idx = col_idx - num_note_columns
            local effect_column = pattern_track:line(row).effect_columns[effect_col_idx]
            source_data[track_idx][row][col_idx] = {
              effect_number = effect_column.number_value,
              effect_amount = effect_column.amount_value
            }
          end
        end
      end
    end
  end
  
  -- Fill only the selection with source data (cycling if needed)
  for track_idx = start_track, end_track do
    local track = song:track(track_idx)
    
    -- Skip non-sequencer tracks
    if track.type == renoise.Track.TRACK_TYPE_GROUP or 
       track.type == renoise.Track.TRACK_TYPE_SEND or 
       track.type == renoise.Track.TRACK_TYPE_MASTER then
      -- Skip this track
    else
      local pattern_track = song:pattern(pattern_index):track(track_idx)
      local num_note_columns = track.visible_note_columns
      local num_effect_columns = track.visible_effect_columns
      local total_columns = num_note_columns + num_effect_columns
      
      -- Determine start and end columns for the current track
      local track_start_column = (track_idx == start_track) and selection.start_column or 1
      local track_end_column = (track_idx == end_track) and selection.end_column or total_columns
      
      -- Fill each row in the selection
      for target_row = selection_start, selection_end do
        -- Calculate which source row to use (cycling through source)
        local source_row = ((target_row - selection_start) % source_length) + 1
        
        for col_idx = track_start_column, track_end_column do
          if source_data[track_idx] and source_data[track_idx][source_row] and source_data[track_idx][source_row][col_idx] then
            if col_idx <= num_note_columns then
              -- Copy note column data
              local note_data = source_data[track_idx][source_row][col_idx]
              local target_note_column = pattern_track:line(target_row).note_columns[col_idx]
              
              target_note_column.note_value = note_data.note
              target_note_column.instrument_value = note_data.instrument
              target_note_column.volume_value = note_data.volume
              target_note_column.panning_value = note_data.panning
              target_note_column.delay_value = note_data.delay
              target_note_column.effect_number_value = note_data.effect_number
              target_note_column.effect_amount_value = note_data.effect_amount
            elseif col_idx > num_note_columns and col_idx <= total_columns then
              -- Copy effect column data
              local effect_data = source_data[track_idx][source_row][col_idx]
              local effect_col_idx = col_idx - num_note_columns
              local target_effect_column = pattern_track:line(target_row).effect_columns[effect_col_idx]
              
              target_effect_column.number_value = effect_data.effect_number
              target_effect_column.amount_value = effect_data.effect_amount
            end
          end
        end
      end
    end
  end
  
  local selection_size = selection_end - selection_start + 1
  renoise.app():show_status(string.format("Replicated %d rows above into %d-row selection.", source_length, selection_size))
end

-------
-- Replicate Above Into Selection Only (Phrase Editor version)
-- Takes content from row 1 to (selection.start_line - 1) and fills only the selection in phrase
local function PakettiReplicateAboveIntoSelectionPhrase()
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return
  end
  
  local selection = song.selection_in_phrase
  
  -- Require a selection
  if not selection then
    renoise.app():show_status("No selection in phrase.")
    return
  end
  
  local selection_start = selection.start_line
  local selection_end = selection.end_line
  local start_column = selection.start_column
  local end_column = selection.end_column
  
  -- Need at least 1 row above the selection as source
  if selection_start <= 1 then
    renoise.app():show_status("No content above selection to replicate in phrase.")
    return
  end
  
  local source_length = selection_start - 1  -- rows 1 to selection_start-1
  local num_note_columns = phrase.visible_note_columns
  local num_effect_columns = phrase.visible_effect_columns
  local total_columns = num_note_columns + num_effect_columns
  
  -- Store source data from rows 1 to (selection_start - 1)
  local source_data = {}
  
  -- Capture source data from rows 1 to (selection_start - 1)
  for row = 1, source_length do
    source_data[row] = {}
    for col_idx = start_column, end_column do
      if col_idx <= num_note_columns then
        -- Capture note column data
        local note_column = phrase:line(row).note_columns[col_idx]
        source_data[row][col_idx] = {
          note = note_column.note_value,
          instrument = note_column.instrument_value,
          volume = note_column.volume_value,
          panning = note_column.panning_value,
          delay = note_column.delay_value,
          effect_number = note_column.effect_number_value,
          effect_amount = note_column.effect_amount_value
        }
      elseif col_idx > num_note_columns and col_idx <= total_columns then
        -- Capture effect column data
        local effect_col_idx = col_idx - num_note_columns
        local effect_column = phrase:line(row).effect_columns[effect_col_idx]
        source_data[row][col_idx] = {
          effect_number = effect_column.number_value,
          effect_amount = effect_column.amount_value
        }
      end
    end
  end
  
  -- Fill only the selection with source data (cycling if needed)
  for target_row = selection_start, selection_end do
    -- Calculate which source row to use (cycling through source)
    local source_row = ((target_row - selection_start) % source_length) + 1
    
    for col_idx = start_column, end_column do
      if source_data[source_row] and source_data[source_row][col_idx] then
        if col_idx <= num_note_columns then
          -- Copy note column data
          local note_data = source_data[source_row][col_idx]
          local target_note_column = phrase:line(target_row).note_columns[col_idx]
          
          target_note_column.note_value = note_data.note
          target_note_column.instrument_value = note_data.instrument
          target_note_column.volume_value = note_data.volume
          target_note_column.panning_value = note_data.panning
          target_note_column.delay_value = note_data.delay
          target_note_column.effect_number_value = note_data.effect_number
          target_note_column.effect_amount_value = note_data.effect_amount
        elseif col_idx > num_note_columns and col_idx <= total_columns then
          -- Copy effect column data
          local effect_data = source_data[source_row][col_idx]
          local effect_col_idx = col_idx - num_note_columns
          local target_effect_column = phrase:line(target_row).effect_columns[effect_col_idx]
          
          target_effect_column.number_value = effect_data.effect_number
          target_effect_column.amount_value = effect_data.effect_amount
        end
      end
    end
  end
  
  local selection_size = selection_end - selection_start + 1
  renoise.app():show_status(string.format("Replicated %d rows above into %d-row phrase selection.", source_length, selection_size))
end

-------
-- Main dispatcher function that detects context (Pattern Editor vs Phrase Editor)
function PakettiReplicateAboveIntoSelection()
  local song = renoise.song()
  
  -- Check if we're in phrase editor
  local in_phrase_editor = false
  if renoise.API_VERSION >= 6.2 then
    if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
      local phrase = song.selected_phrase
      if phrase then
        in_phrase_editor = true
      end
    end
  end
  
  if in_phrase_editor then
    PakettiReplicateAboveIntoSelectionPhrase()
  else
    PakettiReplicateAboveIntoSelectionPattern()
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Replicate Above Into Selection Only", invoke=PakettiReplicateAboveIntoSelection}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Replicate Above Into Selection Only", invoke=PakettiReplicateAboveIntoSelection}
renoise.tool():add_midi_mapping{name="Paketti:Replicate Above Into Selection Only", invoke=function(message)
  if message:is_trigger() then
    PakettiReplicateAboveIntoSelection()
  end
end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Replicate:Replicate Above Into Selection Only", invoke=PakettiReplicateAboveIntoSelection}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Replicate Above Into Selection Only", invoke=PakettiReplicateAboveIntoSelection}

-------
-------
-- Main function to replicate content
function PakettiReplicateAtCursor(transpose, tracks_option, row_option)
  local song=renoise.song()
  
  -- Check API version and determine if we're in phrase editor
  local in_phrase_editor = false
  if renoise.API_VERSION >= 6.2 then
    if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
      local phrase = song.selected_phrase
      if phrase then
        in_phrase_editor = true
      end
    end
  end

  if in_phrase_editor then
    -- Phrase Editor replication logic
    local phrase = song.selected_phrase
    local cursor_row = song.selected_phrase_line_index
    local phrase_length = phrase.number_of_lines

    -- Check if there is content to replicate
    if (cursor_row == phrase_length and row_option == "above_and_current") then
      renoise.app():show_status("No rows to replicate in phrase.")
    return
  end
    if (cursor_row == 1 and row_option == "above_current") then
      row_option = "above_and_current"
    end

    -- Determine the repeat_length and starting row based on row_option
    local repeat_length, start_row
    if row_option == "above_current" then
      if cursor_row == 1 then
        renoise.app():show_status("You are on the first row of the phrase, nothing to replicate.")
        return
      end
      repeat_length = cursor_row - 1
    start_row = cursor_row
    elseif row_option == "above_and_current" then
      repeat_length = cursor_row
      start_row = cursor_row + 1
      if cursor_row == phrase_length then
        renoise.app():show_status("You are on the last row of the phrase, nothing to replicate.")
        return
      end
    else
      renoise.app():show_status("Invalid row option: " .. tostring(row_option))
      return
    end

    if repeat_length == 0 then
      renoise.app():show_status("No rows to replicate in phrase.")
      return
    end

    transpose = transpose or 0

    -- Function to transpose note
    local function transpose_note(note_value, transpose_amount)
      local min_note = 0
      local max_note = 119
      if note_value >= min_note and note_value <= max_note then
        local new_note = note_value + transpose_amount
        if new_note > max_note then new_note = max_note
        elseif new_note < min_note then new_note = min_note end
        return new_note
      else
        return note_value
    end
  end

    -- Replicate content in phrase
    for row = start_row, phrase_length do
      local source_row = ((row - start_row) % repeat_length) + 1
      local source_line = phrase:line(source_row)
      local dest_line = phrase:line(row)

      for col = 1, phrase.visible_note_columns do
        local source_note = source_line.note_columns[col]
        local dest_note = dest_line.note_columns[col]

        dest_note.note_value = transpose_note(source_note.note_value, transpose)
        dest_note.instrument_value = source_note.instrument_value
        dest_note.volume_value = source_note.volume_value
        dest_note.panning_value = source_note.panning_value
        dest_note.delay_value = source_note.delay_value
        dest_note.effect_number_value = source_note.effect_number_value
        dest_note.effect_amount_value = source_note.effect_amount_value
      end

      for col = 1, phrase.visible_effect_columns do
        local source_effect = source_line.effect_columns[col]
        local dest_effect = dest_line.effect_columns[col]

        dest_effect.number_value = source_effect.number_value
        dest_effect.amount_value = source_effect.amount_value
  end
end

    renoise.app():show_status("Replicated content in phrase with transpose: " .. transpose)

  else
    -- Pattern Editor replication logic
    local pattern = song.selected_pattern
    local cursor_row = song.selected_line_index
    local pattern_length = pattern.number_of_lines

    -- Check if there is content to replicate
    if (cursor_row == pattern_length and row_option == "above_and_current") then
      renoise.app():show_status("No rows to replicate.")
      return
    end
    if (cursor_row == 1 and row_option == "above_current") then
      row_option = "above_and_current"
    end

    -- Determine the repeat_length and starting row based on row_option
    local repeat_length, start_row
    if row_option == "above_current" then
      if cursor_row == 1 then
        renoise.app():show_status("You are on the first row, nothing to replicate.")
        return
      end
      repeat_length = cursor_row - 1
      start_row = cursor_row
    elseif row_option == "above_and_current" then
      repeat_length = cursor_row
      start_row = cursor_row + 1
      if cursor_row == pattern_length then
        renoise.app():show_status("You are on the last row, nothing to replicate.")
        return
      end
    else
      renoise.app():show_status("Invalid row option: " .. tostring(row_option))
      return
    end

    if repeat_length == 0 then
      renoise.app():show_status("No rows to replicate.")
      return
    end

    transpose = transpose or 0

    local function transpose_note(note_value, transpose_amount)
      local min_note = 0
      local max_note = 119

      if note_value >= min_note and note_value <= max_note then
        local new_note = note_value + transpose_amount
        if new_note > max_note then
          new_note = max_note
        elseif new_note < min_note then
          new_note = min_note
        end
        return new_note
      else
        return note_value
      end
    end

    -- Function to check if a track section has any content
    local function track_section_has_content(track, start_line, length)
      for row = start_line, start_line + length - 1 do
        local line = track:line(row)
        
        -- Check note columns
        for _, note_col in ipairs(line.note_columns) do
          if not note_col.is_empty then
            return true
          end
        end
        
        -- Check effect columns
        for _, fx_col in ipairs(line.effect_columns) do
          if not fx_col.is_empty then
            return true
          end
        end
      end
      return false
    end

    -- Function to replicate content on a track
    local function replicate_on_track(track_index)
      local track = pattern:track(track_index)
      
      -- Skip empty tracks for performance
      if not track_section_has_content(track, 1, repeat_length) then
        return
      end
      
      local source_data = {}
      
      -- Pre-cache source lines for better performance
      for source_row = 1, repeat_length do
        source_data[source_row] = track:line(source_row)
      end
      
      -- Process in batches for better performance
      local BATCH_SIZE = 32
      local current_batch = {}
      
      for row = start_row, pattern_length do
        local source_row = ((row - start_row) % repeat_length) + 1
        local dest_line = track:line(row)
        local source_line = source_data[source_row]
        
        -- Apply note columns
        for col = 1, #source_line.note_columns do
          local source_note = source_line.note_columns[col]
          local dest_note = dest_line.note_columns[col]
          
          -- Add to batch
          table.insert(current_batch, {
            dest_note = dest_note,
            source_note = source_note,
            transpose = transpose
          })
        end
        
        -- Apply effect columns immediately since they're simpler
        for col = 1, #source_line.effect_columns do
          local source_effect = source_line.effect_columns[col]
          local dest_effect = dest_line.effect_columns[col]
          dest_effect.number_value = source_effect.number_value
          dest_effect.amount_value = source_effect.amount_value
        end
        
        -- Process batch when it reaches size limit or at end
        if #current_batch >= BATCH_SIZE or row == pattern_length then
          for _, update in ipairs(current_batch) do
            local dest_note = update.dest_note
            local source_note = update.source_note
            dest_note.note_value = transpose_note(source_note.note_value, update.transpose)
            dest_note.instrument_value = source_note.instrument_value
            dest_note.volume_value = source_note.volume_value
            dest_note.panning_value = source_note.panning_value
            dest_note.delay_value = source_note.delay_value
            dest_note.effect_number_value = source_note.effect_number_value
            dest_note.effect_amount_value = source_note.effect_amount_value
          end
          current_batch = {}
        end
      end
    end

    if tracks_option == "all_tracks" then
      for track_index = 1, #pattern.tracks do
        replicate_on_track(track_index)
      end
    elseif tracks_option == "selected_track" then
      local selected_track_index = song.selected_track_index
      replicate_on_track(selected_track_index)
    else
      renoise.app():show_status("Invalid tracks option: " .. tostring(tracks_option))
      return
    end

    renoise.app():show_status("Replicated content with transpose: " .. transpose)
  end
end

-- Helper function to create menu entries, keybindings, and MIDI mappings
local function create_replicate_function(transpose, tracks_option, row_option)
  return function()
    PakettiReplicateAtCursor(transpose, tracks_option, row_option)
  end
end

-- Options for transpose, tracks, and rows
local transpose_options = {
  {value = -12, name = "(-12)"},
  {value = -1, name = "(-1)"},
  {value = 0, name = ""},
  {value = 1, name = "(+1)"},
  {value = 12, name = "(+12)"},
}

local tracks_options = {
  {value = "selected_track", name = "Selected Track"},
  {value = "all_tracks", name = "All"},
}

local row_options = {
  {value = "above_current",name="Above Current Row"},
  {value = "above_and_current",name="Above + Current"},
}

-- Generate menu entries, keybindings, and MIDI mappings for all combinations
for _, tracks_opt in ipairs(tracks_options) do
  for _, row_opt in ipairs(row_options) do
    for _, transpose_opt in ipairs(transpose_options) do
      local replicate_function = create_replicate_function(transpose_opt.value, tracks_opt.value, row_opt.value)

      -- Pattern Editor entries (always add these)
      local menu_entry_name = "Pattern Editor:Paketti:Replicate:Replicate " .. tracks_opt.name .. " " .. row_opt.name .. " " .. transpose_opt.name
      renoise.tool():add_menu_entry{name=menu_entry_name,invoke=replicate_function}
      
      local keybinding_name = "Pattern Editor:Paketti:Replicate " .. tracks_opt.name .. " " .. row_opt.name .. " " .. transpose_opt.name
      renoise.tool():add_keybinding{name=keybinding_name,invoke=replicate_function}
      
      local midi_mapping_name = "Paketti:Replicate " .. tracks_opt.name .. " " .. row_opt.name .. " " .. transpose_opt.name
      renoise.tool():add_midi_mapping{name=midi_mapping_name,invoke=function(message)
      if message:is_trigger() then
        replicate_function()
      end
    end}

      -- Add Phrase Editor entries only for "selected_track" option
      -- since phrases don't have multiple tracks
      if renoise.API_VERSION >= 6.2 and tracks_opt.value == "selected_track" then
        local phrase_menu_entry_name = "Phrase Editor:Paketti:Replicate:Replicate " .. row_opt.name .. " " .. transpose_opt.name
        renoise.tool():add_menu_entry{name=phrase_menu_entry_name,invoke=replicate_function}
        
        local phrase_keybinding_name = "Phrase Editor:Paketti:Replicate " .. row_opt.name .. " " .. transpose_opt.name
        renoise.tool():add_keybinding{name=phrase_keybinding_name,invoke=replicate_function}
        
        local phrase_midi_mapping_name = "Paketti:Phrase Replicate " .. row_opt.name .. " " .. transpose_opt.name
        renoise.tool():add_midi_mapping{name=phrase_midi_mapping_name,invoke=function(message)
          if message:is_trigger() then
            replicate_function()
          end
        end}
  end
end
end
end
------------
-- Function to adjust the delay column within the selected area or current note column
function PakettiDelayColumnModifier(amount)
  -- Get the current song
  local song=renoise.song()
  if not song then
    renoise.app():show_status("No active song found.")
    return
  end
  
  -- Get the selection in the pattern editor
    local selection = song.selection_in_pattern

    if selection then
    -- There is a selection; adjust the delay values within the selection
    for track_index = selection.start_track, selection.end_track do
      local track = song:track(track_index)
      -- Ensure the delay column is visible
      if not track.delay_column_visible then
        track.delay_column_visible = true
      end

      local max_note_columns = track.visible_note_columns
      for line_index = selection.start_line, selection.end_line do
        local pattern_index = song.selected_pattern_index
        local pattern = song:pattern(pattern_index)
        local line = pattern:track(track_index):line(line_index)
        for note_column_index = selection.start_column, selection.end_column do
          -- Ensure the note column index is within the track's note columns
          if note_column_index <= max_note_columns then
            local note_column = line:note_column(note_column_index)
            if note_column then
              -- Adjust the delay value
              local new_value = math.min(0xFF, math.max(0, note_column.delay_value + amount))
              note_column.delay_value = new_value
            end
          end
        end
      end
    end
    renoise.app():show_status("Delay Column adjustment (" .. amount .. ") applied to selection.")
  else
    -- No selection; adjust the current note column
    local selected_track_index = song.selected_track_index
    local selected_line_index = song.selected_line_index
    local selected_note_column_index = song.selected_note_column_index
    local track = song:track(selected_track_index)

    -- Check if the cursor is in a note column
    if selected_note_column_index == 0 then
      renoise.app():show_status("Not in a note column. No delay adjustment made.")
    return
  end

    -- Ensure the delay column is visible
    if not track.delay_column_visible then
      track.delay_column_visible = true
    end

    local pattern_index = song.selected_pattern_index
    local pattern = song:pattern(pattern_index)
    local line = pattern:track(selected_track_index):line(selected_line_index)
    local note_column = line:note_column(selected_note_column_index)
    if note_column then
      -- Adjust the delay value
      local new_value = math.min(0xFF, math.max(0, note_column.delay_value + amount))
      note_column.delay_value = new_value
      renoise.app():show_status("Delay Column adjustment (" .. amount .. ") applied to current note column.")
    else
      renoise.app():show_status("No note column found at index " .. selected_note_column_index .. ". No delay adjustment made.")
    end
  end
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Increase Selection/Row (+1)",invoke=function() PakettiDelayColumnModifier(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Decrease Selection/Row (-1)",invoke=function() PakettiDelayColumnModifier(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delay Column Increase Selection/Row (+10)",invoke=function() PakettiDelayColumnModifier(10) end}
renoise.tool():add_keybinding{name= "Pattern Editor:Paketti:Delay Column Decrease Selection/Row (-10)",invoke=function() PakettiDelayColumnModifier(-10) end}

------
function ExposeAndSelectColumn(number)
  local song=renoise.song()
  local track = song.selected_track
  local track_type = track.type

  -- Special handling for Master, Send, and Group tracks
  if track_type == renoise.Track.TRACK_TYPE_MASTER or 
     track_type == renoise.Track.TRACK_TYPE_SEND or 
     track_type == renoise.Track.TRACK_TYPE_GROUP then
    
    local visEffectCol = track.visible_effect_columns
    local newVisEffectCol = visEffectCol + number

    if newVisEffectCol > 8 then
      renoise.app():show_status("All 8 Effect Columns are already visible for the selected track, cannot add more.")
      return
    elseif newVisEffectCol < 1 then
      renoise.app():show_status("Cannot have less than 1 Effect Column visible on Master/Send/Group tracks.")
    return
  end

    track.visible_effect_columns = newVisEffectCol
    song.selected_effect_column_index = newVisEffectCol
    return
  end

  -- Normal sequencer track handling
  if track_type == renoise.Track.TRACK_TYPE_SEQUENCER then
    if song.selected_note_column ~= nil then
      -- Note Column handling (unchanged)
      local visNoteCol = track.visible_note_columns
      local newVisNoteCol = visNoteCol + number

      if newVisNoteCol > 12 then
        renoise.app():show_status("All 12 Note Columns are already visible for the selected track, cannot add more.")
        return
      elseif newVisNoteCol < 1 then
        renoise.app():show_status("Cannot have less than 1 Note Column visible.")
        return
      end

      track.visible_note_columns = newVisNoteCol
      song.selected_note_column_index = newVisNoteCol

    elseif song.selected_effect_column ~= nil then
      -- Effect Column handling for sequencer tracks
      local visEffectCol = track.visible_effect_columns
      local newVisEffectCol = visEffectCol + number

      if newVisEffectCol > 8 then
        renoise.app():show_status("All 8 Effect Columns are already visible for the selected track, cannot add more.")
        return
      elseif newVisEffectCol < 0 then
        renoise.app():show_status("Hiding all Effect Columns.")
        track.visible_effect_columns = 0
        return
      end

      track.visible_effect_columns = newVisEffectCol
      if newVisEffectCol > 0 then
        song.selected_effect_column_index = newVisEffectCol
      end
    else
      renoise.app():show_status("You are not on a Note or Effect Column, doing nothing.")
        end
      end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Expose and Select Next Column",invoke=function() ExposeAndSelectColumn(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Hide Current and Select Previous Column",invoke=function() ExposeAndSelectColumn(-1) end}
renoise.tool():add_midi_mapping{name="Paketti:Expose and Select Next Column",invoke=function(message) if message:is_trigger() then ExposeAndSelectColumn(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Hide Current and Select Previous Column",invoke=function(message) if message:is_trigger() then ExposeAndSelectColumn(-1) end end}

--------
function cloneAndExpandPatternToLPBDouble()
  local rs = renoise.song()
  local current_pattern_length = rs.selected_pattern.number_of_lines
  
  -- Check if pattern length is 257 or more
  if current_pattern_length >= 257 then
      renoise.app():show_status("Cannot expand: Pattern length would exceed maximum")
      return
  end
  
  write_bpm()
  
  -- Store current pattern length before cloning
  local original_length = current_pattern_length
  
  -- Clone the pattern
  clonePTN()
  
  -- Set the new pattern length
  local new_length = original_length * 2
  rs.selected_pattern.number_of_lines = new_length
  
  -- Double the LPB
  local number = rs.transport.lpb * 2
  if number == 1 then number = 2 end
  if number > 128 then 
      number = 128 
      rs.transport.lpb = number
      write_bpm()
      Deselect_All()
      MarkTrackMarkPattern()
      MarkTrackMarkPattern()
      ExpandSelection()
      Deselect_All()
      return 
  end
  
  rs.transport.lpb = number
  write_bpm()
  Deselect_All()
  MarkTrackMarkPattern()
  MarkTrackMarkPattern()
  ExpandSelection()
  Deselect_All()
end


function cloneAndShrinkPatternToLPBHalve()
local number=nil
local numbertwo=nil
local rs=renoise.song()
write_bpm()
clonePTN()
Deselect_All()
MarkTrackMarkPattern()
MarkTrackMarkPattern()
ShrinkSelection()
Deselect_All()
local nol=nil
    nol=renoise.song().selected_pattern.number_of_lines/2
    renoise.song().selected_pattern.number_of_lines=nol

number=renoise.song().transport.lpb/2
if number == 1 then number = 2 end
if number > 128 then number=128 
renoise.song().transport.lpb=number
write_bpm()
return end
renoise.song().transport.lpb=number
write_bpm()
end

renoise.tool():add_keybinding{name="Global:Paketti:Clone and Expand Pattern to LPB*2",invoke=function() cloneAndExpandPatternToLPBDouble()end}
renoise.tool():add_keybinding{name="Global:Paketti:Clone and Shrink Pattern to LPB/2",invoke=function() cloneAndShrinkPatternToLPBHalve()end}








function setPatternLengthByLPB(multiplier)
  local rs=renoise.song()
  local lpb=rs.transport.lpb
  local new_length=lpb*multiplier
  if new_length>512 then new_length=512 end
  rs.patterns[rs.selected_pattern_index].number_of_lines=new_length
  renoise.app():show_status("Pattern Length set to "..new_length.." (LPB*"..string.format("%03d", multiplier)..")")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*001",invoke=function() setPatternLengthByLPB(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*002",invoke=function() setPatternLengthByLPB(2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*004",invoke=function() setPatternLengthByLPB(4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*008",invoke=function() setPatternLengthByLPB(8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*016",invoke=function() setPatternLengthByLPB(16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*032",invoke=function() setPatternLengthByLPB(32) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*064",invoke=function() setPatternLengthByLPB(64) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*128",invoke=function() setPatternLengthByLPB(128) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*256",invoke=function() setPatternLengthByLPB(256) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Pattern Length to LPB*512",invoke=function() setPatternLengthByLPB(512) end}







----------
-- Initialize variables
local last_line_index = nil
local match_editstep_enabled = false
local target_column_type = "effect" -- Can be "effect" or "note"


-- Function to find the next note line
function find_next_note_line(start_line)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local num_lines = pattern.number_of_lines
  local current_track = song.selected_pattern_track
  local max_note_columns = renoise.song().selected_track.visible_note_columns

  -- Flag to check if any notes exist in the track
  local notes_exist = false
  for line_index = 1, num_lines do
    local track_line = current_track:line(line_index)
    for note_col_index = 1, max_note_columns do
      local note_column = track_line:note_column(note_col_index)
      if not note_column.is_empty and note_column.note_value <= 120 then
        notes_exist = true
        break
      end
    end
    if notes_exist then break end
  end

  if not notes_exist then
    renoise.app():show_status("No notes found in this track.")  -- Added for immediate feedback
    return nil  -- No notes found in the entire track
  end

  -- Search from start_line +1 to num_lines
  for line_index = start_line + 1, num_lines do
    local track_line = current_track:line(line_index)
    for note_col_index = 1, max_note_columns do
      local note_column = track_line:note_column(note_col_index)
      if not note_column.is_empty and note_column.note_value <= 120 then
        return line_index
      end
    end
  end

  -- Wrap around: Search from line 1 to start_line
  for line_index = 1, start_line do
    local track_line = current_track:line(line_index)
    for note_col_index = 1, max_note_columns do
      local note_column = track_line:note_column(note_col_index)
      if not note_column.is_empty and note_column.note_value <= 120 then
        return line_index
      end
    end
  end

  return nil  -- This shouldn't happen, but return nil just in case
end

-- Function to adjust the editstep
function match_editstep_with_next_note()
  local song=renoise.song()
  local current_line_index = song.selected_line_index
  local num_lines = song.selected_pattern.number_of_lines

  -- Check if the line index has changed
  if last_line_index ~= current_line_index then
    last_line_index = current_line_index

    -- Check column type based on target setting
    local should_adjust = false
    if target_column_type == "effect" then
      should_adjust = (song.selected_note_column_index == 0 and song.selected_effect_column_index > 0)
    else -- note
      should_adjust = (song.selected_note_column_index > 0)
    end

    if should_adjust then
      local next_note_line = find_next_note_line(current_line_index)
      if next_note_line then
        local editstep = 0
        if next_note_line > current_line_index then
          editstep = next_note_line - current_line_index
        elseif next_note_line < current_line_index then
          -- Wrap around case
          editstep = (num_lines - current_line_index) + next_note_line
        else
          -- The next note is on the same line
          editstep = 0
        end
        song.transport.edit_step = editstep
      else
        -- No notes in the track
        renoise.app():show_status("There are no notes on this track. Doing nothing.")
        -- Do not change editstep
      end
    end
  end
end

-- Function to immediately adjust the editstep when toggling on
function set_initial_editstep()
  local song=renoise.song()
  local current_line_index = song.selected_line_index
  local next_note_line = find_next_note_line(current_line_index)
  if next_note_line then
    local editstep = 0
    if next_note_line > current_line_index then
      editstep = next_note_line - current_line_index
    elseif next_note_line < current_line_index then
      editstep = (song.selected_pattern.number_of_lines - current_line_index) + next_note_line
    else
      editstep = 0  -- Same line
    end
    song.transport.edit_step = editstep
    renoise.app():show_status("Initial EditStep set to " .. tostring(editstep))
  else
    renoise.app():show_status("No notes found to adjust EditStep.")
  end
end

-- Idle notifier functions
function attach_idle_notifier()
  if not renoise.tool().app_idle_observable:has_notifier(match_editstep_with_next_note) then
    renoise.tool().app_idle_observable:add_notifier(match_editstep_with_next_note)
  end
end

function detach_idle_notifier()
  if renoise.tool().app_idle_observable:has_notifier(match_editstep_with_next_note) then
    renoise.tool().app_idle_observable:remove_notifier(match_editstep_with_next_note)
  end
end

-- Function to handle new songs
function attach_to_song()
  detach_idle_notifier()
  if match_editstep_enabled then
    attach_idle_notifier()
  end
end

-- Observe when a new song is loaded
if not renoise.tool().app_new_document_observable:has_notifier(attach_to_song) then
  renoise.tool().app_new_document_observable:add_notifier(attach_to_song)
end


-- Toggle functions for both column types
function toggle_match_editstep_effect()
  target_column_type = "effect"
  match_editstep_enabled = not match_editstep_enabled
  if match_editstep_enabled then
    last_line_index = renoise.song().selected_line_index
    attach_idle_notifier()
    set_initial_editstep()
    renoise.app():show_status("Match EditStep (Effect Column): ON")
  else
    detach_idle_notifier()
    renoise.app():show_status("Match EditStep (Effect Column): OFF")
  end
end

function toggle_match_editstep_note()
  target_column_type = "note"
  match_editstep_enabled = not match_editstep_enabled
  if match_editstep_enabled then
    last_line_index = renoise.song().selected_line_index
    attach_idle_notifier()
    set_initial_editstep()
    renoise.app():show_status("Match EditStep (Note Column): ON")
  else
    detach_idle_notifier()
    renoise.app():show_status("Match EditStep (Note Column): OFF")
  end
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Match EditStep with Note Placement (Effect Column)",invoke=function() toggle_match_editstep_effect() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Match EditStep with Note Placement (Note Column)",invoke=function() toggle_match_editstep_note() end}
--
function PakettiRandomEditStep(startNumber)
renoise.song().transport.edit_step = math.random(startNumber,64)
end

renoise.tool():add_keybinding{name="Global:Paketti:Set Random EditStep 0-64",invoke=function() PakettiRandomEditStep(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Random EditStep 1-64",invoke=function() PakettiRandomEditStep(1) end}
---------
-- Function to clear the selected track either above or below the selected line index
function clear_track_direction(direction, all_tracks)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local selected_line_index = song.selected_line_index
  local pattern_length = pattern.number_of_lines
  
  -- Validate direction parameter
  if direction ~= "above" and direction ~= "below" then
    renoise.app():show_status("Invalid direction specified.")
    return
  end
  
  -- Check if we're at pattern boundaries
  if direction == "above" and selected_line_index == 1 then
    renoise.app():show_status("You are already on the top row, doing nothing.")
    return
  elseif direction == "below" and selected_line_index == pattern_length then
    renoise.app():show_status("You are already on the bottom row, doing nothing.")
    return
  end

  -- Define the range of tracks to process
  local track_range = all_tracks and {1, #song.tracks} or {song.selected_track_index, song.selected_track_index}
  
  -- Process each track in the range
  for track_index = track_range[1], track_range[2] do
    local track = song.tracks[track_index]
    local pattern_track = pattern:track(track_index)
    
    -- Define line range based on direction
    local start_line = direction == "above" and 1 or selected_line_index + 1
    local end_line = direction == "above" and selected_line_index - 1 or pattern_length
    
    -- Clear the lines in the specified range
    for line_idx = start_line, end_line do
      local line = pattern_track:line(line_idx)
      
      -- Clear note columns (only for sequencer tracks)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        for note_col_idx = 1, track.visible_note_columns do
          local note_column = line:note_column(note_col_idx)
          note_column:clear()
        end
      end
      
      -- Clear effect columns (for all track types)
      for effect_col_idx = 1, track.visible_effect_columns do
        local effect_column = line:effect_column(effect_col_idx)
        effect_column:clear()
      end
    end
  end
  
  -- Inform the user of the operation via status bar
  local track_msg = all_tracks and "all tracks" or "the selected track"
  local direction_msg = direction == "above" and "above" or "below"
  renoise.app():show_status(string.format("Cleared %s %s the selected line.", track_msg, direction_msg))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear Selected Track Above Current Row",invoke=function() clear_track_direction("above",false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear Selected Track Below Current Row",invoke=function() clear_track_direction("below",false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear All Tracks Above Current Row",invoke=function() clear_track_direction("above",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear All Tracks Below Current Row",invoke=function() clear_track_direction("below",true) end}


renoise.tool():add_midi_mapping{name="Paketti:Clear Selected Track Above Current Row",invoke=function(message) if message:is_trigger() then clear_track_direction("above", false) end end}

-- Function to wipe track content by editstep intervals
function wipe_track_by_editstep(all_tracks)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  local selected_line_index = song.selected_line_index
  local editstep = song.transport.edit_step
  
  -- If editstep is 0, treat it as 1
  if editstep == 0 then
    editstep = 1
  end
  
  -- Determine what to clear based on current column selection
  local selected_note_column = song.selected_note_column_index
  local selected_effect_column = song.selected_effect_column_index
  local in_note_column = (selected_note_column > 0)
  local in_effect_column = (selected_note_column == 0 and selected_effect_column > 0)
  
  local lines_cleared = 0
  
  -- Check if there's a selection
  local selection = song.selection_in_pattern
  
  if selection then
    -- Work within selection using selection_in_pattern_pro
    local selection_data = selection_in_pattern_pro()
    if not selection_data then
      renoise.app():show_status("Could not get selection data")
      return
    end
    
    -- Process each track in the selection
    for _, track_info in ipairs(selection_data) do
      local track_index = track_info.track_index
      local track = song.tracks[track_index]
      local pattern_track = pattern:track(track_index)
      
      -- Start from selection start line and wipe at editstep intervals within selection bounds
      for line_idx = selection.start_line, selection.end_line, editstep do
        local line = pattern_track:line(line_idx)
        local line_had_content = false
        
        -- Clear note columns (only if in note column and for sequencer tracks and selected)
        if in_note_column and track.type == renoise.Track.TRACK_TYPE_SEQUENCER and #track_info.note_columns > 0 then
          for _, note_col_idx in ipairs(track_info.note_columns) do
            local note_column = line:note_column(note_col_idx)
            if not note_column.is_empty then
              line_had_content = true
              note_column:clear()
            end
          end
        end
        
        -- Clear effect columns (if in note column OR in effect column and selected)
        if (in_note_column or in_effect_column) and #track_info.effect_columns > 0 then
          for _, effect_col_idx in ipairs(track_info.effect_columns) do
            local effect_column = line:effect_column(effect_col_idx)
            if not effect_column.is_empty then
              line_had_content = true
              effect_column:clear()
            end
          end
        end
        
        if line_had_content then
          lines_cleared = lines_cleared + 1
        end
      end
    end
    
    -- Show status for selection mode
    local column_msg = in_note_column and "note+effect columns" or (in_effect_column and "effect columns" or "columns")
    renoise.app():show_status(string.format("Wiped %d lines (%s) within selection using EditStep intervals (%d)", 
      lines_cleared, column_msg, editstep))
  else
    -- No selection - use original behavior for whole track
    local track_range = all_tracks and {1, #song.tracks} or {song.selected_track_index, song.selected_track_index}
    
    -- Process each track in the range
    for track_index = track_range[1], track_range[2] do
      local track = song.tracks[track_index]
      local pattern_track = pattern:track(track_index)
      
      -- Start from selected line and wipe at editstep intervals
      for line_idx = selected_line_index, pattern_length, editstep do
        local line = pattern_track:line(line_idx)
        local line_had_content = false
        
        -- Clear note columns (only if in note column and for sequencer tracks)
        if in_note_column and track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          for note_col_idx = 1, track.visible_note_columns do
            local note_column = line:note_column(note_col_idx)
            if not note_column.is_empty then
              line_had_content = true
              note_column:clear()
            end
          end
        end
        
        -- Clear effect columns (if in note column OR in effect column)
        if in_note_column or in_effect_column then
          for effect_col_idx = 1, track.visible_effect_columns do
            local effect_column = line:effect_column(effect_col_idx)
            if not effect_column.is_empty then
              line_had_content = true
              effect_column:clear()
            end
          end
        end
        
        if line_had_content then
          lines_cleared = lines_cleared + 1
        end
      end
    end
    
    -- Show status for non-selection mode
    local track_msg = all_tracks and "all tracks" or "the selected track"
    local column_msg = in_note_column and "note+effect columns" or (in_effect_column and "effect columns" or "columns")
    renoise.app():show_status(string.format("Wiped %d lines (%s) from %s using EditStep intervals (%d)", 
      lines_cleared, column_msg, track_msg, editstep))
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe Selected Track by EditStep",invoke=function() wipe_track_by_editstep(false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wipe All Tracks by EditStep",invoke=function() wipe_track_by_editstep(true) end}

renoise.tool():add_midi_mapping{name="Paketti:Wipe Selected Track by EditStep",invoke=function(message) if message:is_trigger() then wipe_track_by_editstep(false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Wipe All Tracks by EditStep",invoke=function(message) if message:is_trigger() then wipe_track_by_editstep(true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Clear Selected Track Below Current Row",invoke=function(message) if message:is_trigger() then clear_track_direction("below", false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Clear All Tracks Above Current Row",invoke=function(message) if message:is_trigger() then clear_track_direction("above", true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Clear All Tracks Below Current Row",invoke=function(message) if message:is_trigger() then clear_track_direction("below", true) end end}
-----
-- Helper function to check if in a valid note column
local function is_in_note_column()
  local note_column_index = renoise.song().selected_note_column_index
  if note_column_index == nil then
    renoise.app():show_status("You are not in a Note Column, doing nothing.")
    return false
  end
  return true
end

-- Function to match the current sub-column type to all rows in the selected note column
local function match_current_sub_column_to_track()
  if not is_in_note_column() then return end

  local song=renoise.song()
  local track = song.selected_track
  local sub_column_type = song.selected_sub_column_type
  local line_index = song.selected_line_index
  local pattern = song.selected_pattern
  local number_of_lines = pattern.number_of_lines
  local note_column_index = song.selected_note_column_index
  local current_line = pattern:track(song.selected_track_index):line(line_index)

  -- Iterate through all lines in the selected track and match based on sub-column type
  for i = 1, number_of_lines do
    local line = pattern:track(song.selected_track_index):line(i)

    if sub_column_type == 2 and current_line.note_columns[note_column_index].instrument_value ~= nil then
      line.note_columns[note_column_index].instrument_value = current_line.note_columns[note_column_index].instrument_value
    elseif sub_column_type == 3 and current_line.note_columns[note_column_index].volume_value ~= renoise.PatternLine.EMPTY_VOLUME then
      line.note_columns[note_column_index].volume_value = current_line.note_columns[note_column_index].volume_value
    elseif sub_column_type == 4 and current_line.note_columns[note_column_index].panning_value ~= renoise.PatternLine.EMPTY_PANNING then
      line.note_columns[note_column_index].panning_value = current_line.note_columns[note_column_index].panning_value
    elseif sub_column_type == 5 and current_line.note_columns[note_column_index].delay_value ~= renoise.PatternLine.EMPTY_DELAY then
      line.note_columns[note_column_index].delay_value = current_line.note_columns[note_column_index].delay_value
    elseif sub_column_type == 6 and current_line.note_columns[note_column_index].effect_number_value ~= renoise.PatternLine.EMPTY_EFFECT_NUMBER then
      line.note_columns[note_column_index].effect_number_value = current_line.note_columns[note_column_index].effect_number_value
    elseif sub_column_type == 7 and current_line.note_columns[note_column_index].effect_amount_value ~= renoise.PatternLine.EMPTY_EFFECT_AMOUNT then
      line.note_columns[note_column_index].effect_amount_value = current_line.note_columns[note_column_index].effect_amount_value
    end
  end

  renoise.app():show_status("Matched current sub-column value to the entire track.")
end

-- Function to match volume column to current row
local function match_volume_to_current_row()
  if not is_in_note_column() then return end

  local song=renoise.song()
  local track = song.selected_track
  local line_index = song.selected_line_index
  local pattern = song.selected_pattern
  local number_of_lines = pattern.number_of_lines
  local note_column_index = song.selected_note_column_index
  local current_line = pattern:track(song.selected_track_index):line(line_index)

  -- Get the volume value from the selected note column
  if current_line.note_columns[note_column_index].volume_value ~= renoise.PatternLine.EMPTY_VOLUME then
    local volume_value = current_line.note_columns[note_column_index].volume_value

    -- Apply to all lines in the selected track
    for i = 1, number_of_lines do
      local line = pattern:track(song.selected_track_index):line(i)
      line.note_columns[note_column_index].volume_value = volume_value
    end
  end

  renoise.app():show_status("Matched volume to the entire track from the current row.")
end

-- Function to match panning column to current row
local function match_panning_to_current_row()
  if not is_in_note_column() then return end

  local song=renoise.song()
  local track = song.selected_track
  local line_index = song.selected_line_index
  local pattern = song.selected_pattern
  local number_of_lines = pattern.number_of_lines
  local note_column_index = song.selected_note_column_index
  local current_line = pattern:track(song.selected_track_index):line(line_index)

  -- Get the panning value from the selected note column
  if current_line.note_columns[note_column_index].panning_value ~= renoise.PatternLine.EMPTY_PANNING then
    local panning_value = current_line.note_columns[note_column_index].panning_value

    -- Apply to all lines in the selected track
    for i = 1, number_of_lines do
      local line = pattern:track(song.selected_track_index):line(i)
      line.note_columns[note_column_index].panning_value = panning_value
    end
  end

  renoise.app():show_status("Matched panning to the entire track from the current row.")
end

-- Function to match delay column to current row
local function match_delay_to_current_row()
  if not is_in_note_column() then return end

  local song=renoise.song()
  local track = song.selected_track
  local line_index = song.selected_line_index
  local pattern = song.selected_pattern
  local number_of_lines = pattern.number_of_lines
  local note_column_index = song.selected_note_column_index
  local current_line = pattern:track(song.selected_track_index):line(line_index)

  -- Get the delay value from the selected note column
  if current_line.note_columns[note_column_index].delay_value ~= renoise.PatternLine.EMPTY_DELAY then
    local delay_value = current_line.note_columns[note_column_index].delay_value

    -- Apply to all lines in the selected track
    for i = 1, number_of_lines do
      local line = pattern:track(song.selected_track_index):line(i)
      line.note_columns[note_column_index].delay_value = delay_value
    end
  end

  renoise.app():show_status("Matched delay to the entire track from the current row.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Match Current Sub Column Selection",invoke=function() match_current_sub_column_to_track() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Match Volume Column to Current Row",invoke=function() match_volume_to_current_row()end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Match Panning Column to Current Row",invoke=function() match_panning_to_current_row() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Match Delay Column to Current Row",invoke=function() match_delay_to_current_row() end}
-------

function nudge(direction)
  local song=renoise.song()
  local selection = selection_in_pattern_pro()
  if not selection then 
    renoise.app():show_status("No selection in pattern, doing nothing.")
    return
  end

  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]

  -- Get selection boundaries from song.selection_in_pattern
  local pattern_selection = song.selection_in_pattern
  if not pattern_selection then
    renoise.app():show_status("No selection in pattern, doing nothing.")
    return
  end
  local start_line = pattern_selection.start_line
  local end_line = pattern_selection.end_line

  -- Debugging: Print the selection boundaries
  print("Selection in Pattern:")
  print(string.format("Start Line: %d, End Line: %d", start_line, end_line))
  print(string.format("Start Column: %d, End Column: %d", pattern_selection.start_column, pattern_selection.end_column))
  for _, track_info in ipairs(selection) do
    print(string.format("Track Index: %d", track_info.track_index))
    print(string.format("Selected Note Columns: %s", table.concat(track_info.note_columns, ", ")))
  end

  -- Helper functions to copy note and effect columns
  local function copy_note_column(note_column)
    return {
      note_value = note_column.note_value,
      instrument_value = note_column.instrument_value,
      volume_value = note_column.volume_value,
      panning_value = note_column.panning_value,
      delay_value = note_column.delay_value,
      effect_number_value = note_column.effect_number_value,
      effect_amount_value = note_column.effect_amount_value
    }
  end

  local function set_note_column(note_column, data)
    note_column.note_value = data.note_value
    note_column.instrument_value = data.instrument_value
    note_column.volume_value = data.volume_value
    note_column.panning_value = data.panning_value
    note_column.delay_value = data.delay_value
    note_column.effect_number_value = data.effect_number_value
    note_column.effect_amount_value = data.effect_amount_value
  end

  local function copy_effect_column(effect_column)
    return {
      number_value = effect_column.number_value,
      amount_value = effect_column.amount_value
    }
  end

  local function set_effect_column(effect_column, data)
    effect_column.number_value = data.number_value
    effect_column.amount_value = data.amount_value
  end

  -- Iterate through selected tracks
  for _, track_info in ipairs(selection) do
    local track = song.tracks[track_info.track_index]

    -- Validate the boundaries
    local lines = pattern.tracks[track_info.track_index].lines
    local adjusted_start_line = math.max(1, math.min(start_line, #lines))
    local adjusted_end_line = math.max(1, math.min(end_line, #lines))

    -- Process all selected note columns
    for _, column_index in ipairs(track_info.note_columns) do
      if direction == "down" then
        -- Store the bottom line data
        local bottom_line = lines[adjusted_end_line]
        local stored_note_column = copy_note_column(bottom_line.note_columns[column_index])
        local stored_effect_columns = {}
        for ec_index, effect_column in ipairs(bottom_line.effect_columns) do
          stored_effect_columns[ec_index] = copy_effect_column(effect_column)
        end

        -- Shift data down
        for line_index = adjusted_end_line, adjusted_start_line + 1, -1 do
          local current_line = lines[line_index]
          local previous_line = lines[line_index - 1]

          -- Copy note column data
          local current_note_column = current_line.note_columns[column_index]
          local previous_note_column = previous_line.note_columns[column_index]
          current_note_column:copy_from(previous_note_column)

          -- Copy effect columns
          local current_effect_columns = current_line.effect_columns
          local previous_effect_columns = previous_line.effect_columns
          for ec_index = 1, #current_effect_columns do
            current_effect_columns[ec_index]:copy_from(previous_effect_columns[ec_index])
          end
        end

        -- Place stored data into the top line
        local top_line = lines[adjusted_start_line]
        set_note_column(top_line.note_columns[column_index], stored_note_column)
        local top_effect_columns = top_line.effect_columns
        for ec_index = 1, #top_effect_columns do
          set_effect_column(top_effect_columns[ec_index], stored_effect_columns[ec_index] or {})
        end

      elseif direction == "up" then
        -- Store the top line data
        local top_line = lines[adjusted_start_line]
        local stored_note_column = copy_note_column(top_line.note_columns[column_index])
        local stored_effect_columns = {}
        for ec_index, effect_column in ipairs(top_line.effect_columns) do
          stored_effect_columns[ec_index] = copy_effect_column(effect_column)
        end

        -- Shift data up
        for line_index = adjusted_start_line, adjusted_end_line - 1 do
          local current_line = lines[line_index]
          local next_line = lines[line_index + 1]

          -- Copy note column data
          local current_note_column = current_line.note_columns[column_index]
          local next_note_column = next_line.note_columns[column_index]
          current_note_column:copy_from(next_note_column)

          -- Copy effect columns
          local current_effect_columns = current_line.effect_columns
          local next_effect_columns = next_line.effect_columns
          for ec_index = 1, #current_effect_columns do
            current_effect_columns[ec_index]:copy_from(next_effect_columns[ec_index])
          end
        end

        -- Place stored data into the bottom line
        local bottom_line = lines[adjusted_end_line]
        set_note_column(bottom_line.note_columns[column_index], stored_note_column)
        local bottom_effect_columns = bottom_line.effect_columns
        for ec_index = 1, #bottom_effect_columns do
          set_effect_column(bottom_effect_columns[ec_index], stored_effect_columns[ec_index] or {})
        end

      else
        renoise.app():show_status("Invalid nudge direction!")
        return
      end
    end -- End of column iteration
  end -- End of track iteration

  -- Return focus to the pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Nudge " .. direction .. " applied.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Down",invoke=function() nudge("down") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Up",invoke=function() nudge("up") end}

function nudge_with_delay(direction)
  local song=renoise.song()
  local selection = selection_in_pattern_pro()
  if not selection then 
    renoise.app():show_status("No selection in pattern, doing nothing.")
    return
  end

  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]

  -- Get selection boundaries from song.selection_in_pattern
  local pattern_selection = song.selection_in_pattern
  if not pattern_selection then
    renoise.app():show_status("No selection in pattern, doing nothing.")
    return
  end
  local start_line = pattern_selection.start_line
  local end_line = pattern_selection.end_line

  -- Debugging: Print the selection boundaries
  print("Selection in Pattern:")
  print(string.format("Start Line: %d, End Line: %d", start_line, end_line))
  print(string.format("Start Column: %d, End Column: %d", pattern_selection.start_column, pattern_selection.end_column))
  for _, track_info in ipairs(selection) do
    print(string.format("Track Index: %d", track_info.track_index))
    print(string.format("Selected Note Columns: %s", table.concat(track_info.note_columns, ", ")))
  end

  -- Iterate through selected tracks
  for _, track_info in ipairs(selection) do
    local track = song.tracks[track_info.track_index]

    -- Do not modify delay column visibility
    -- Validate the boundaries
    local lines = pattern.tracks[track_info.track_index].lines
    local adjusted_start_line = math.max(1, math.min(start_line, #lines))
    local adjusted_end_line = math.max(1, math.min(end_line, #lines))

    -- Process all selected note columns
    for _, column_index in ipairs(track_info.note_columns) do
      -- Determine the iteration order based on the direction
      if direction == "down" then
        -- Process from bottom to top for "nudge down"
        for line_index = adjusted_end_line, adjusted_start_line, -1 do
          local note_column = lines[line_index].note_columns[column_index]
          local effect_columns = lines[line_index].effect_columns

          -- Process even if the note_column is empty (no note), but has a delay value
          if not note_column.is_empty or note_column.delay_value > 0 then
            local delay = note_column.delay_value
            local new_delay = delay + 1

            if new_delay > 0xFF then
              new_delay = 0

              -- Determine the next line index with wrap-around
              local next_line_index = line_index + 1
              if next_line_index > adjusted_end_line then
                next_line_index = adjusted_start_line  -- Wrap to the start of the selection
              end

              local next_line = lines[next_line_index]
              local next_note_column = next_line.note_columns[column_index]
              local next_effect_columns = next_line.effect_columns

              -- Check if the target note column and effect columns are empty
              local can_move = next_note_column.is_empty and next_note_column.delay_value == 0
              for _, next_effect_column in ipairs(next_effect_columns) do
                if not next_effect_column.is_empty then
                  can_move = false
                  break
                end
              end

              if can_move then
                print(string.format(
                  "Moving note/delay down with wrap: Track %d, Column %d, Row %d -> Row %d", 
                  track_info.track_index, column_index, line_index, next_line_index))
                
                -- Move the note column (includes volume, panning, sample effect data)
                next_note_column:copy_from(note_column)
                next_note_column.delay_value = new_delay -- Set new delay in the new row
                note_column:clear() -- Clear the old note completely

                -- Move effect columns
                for ec_index, effect_column in ipairs(effect_columns) do
                  local next_effect_column = next_effect_columns[ec_index]
                  next_effect_column:copy_from(effect_column)
                  effect_column:clear()
                end
              else
                print(string.format(
                  "Collision at Track %d, Column %d, Row %d. Cannot nudge further.", 
                  track_info.track_index, column_index, next_line_index))
                -- Cannot move note due to collision
              end
            else
              -- Update the delay value
              note_column.delay_value = new_delay
              print(string.format(
                "Row %d, Column %d: Note %s, Delay %02X -> %02X",
                line_index, column_index, note_column.note_string, delay, new_delay))
            end
          end
        end
      elseif direction == "up" then
        -- Process from top to bottom for "nudge up"
        for line_index = adjusted_start_line, adjusted_end_line do
          local note_column = lines[line_index].note_columns[column_index]
          local effect_columns = lines[line_index].effect_columns

          -- Process even if the note_column is empty (no note), but has a delay value
          if not note_column.is_empty or note_column.delay_value > 0 then
            local delay = note_column.delay_value
            local new_delay = delay - 1

            if new_delay < 0 then
              new_delay = 0xFF

              -- Determine the previous line index with wrap-around
              local prev_line_index = line_index - 1
              if prev_line_index < adjusted_start_line then
                prev_line_index = adjusted_end_line  -- Wrap to the end of the selection
              end

              local prev_line = lines[prev_line_index]
              local prev_note_column = prev_line.note_columns[column_index]
              local prev_effect_columns = prev_line.effect_columns

              -- Check if the target note column and effect columns are empty
              local can_move = prev_note_column.is_empty and prev_note_column.delay_value == 0
              for _, prev_effect_column in ipairs(prev_effect_columns) do
                if not prev_effect_column.is_empty then
                  can_move = false
                  break
                end
              end

              if can_move then
                print(string.format(
                  "Moving note/delay up with wrap: Track %d, Column %d, Row %d -> Row %d", 
                  track_info.track_index, column_index, line_index, prev_line_index))
                
                -- Move the note column (includes volume, panning, sample effect data)
                prev_note_column:copy_from(note_column)
                prev_note_column.delay_value = new_delay -- Set new delay in the new row
                note_column:clear() -- Clear the old note completely

                -- Move effect columns
                for ec_index, effect_column in ipairs(effect_columns) do
                  local prev_effect_column = prev_effect_columns[ec_index]
                  prev_effect_column:copy_from(effect_column)
                  effect_column:clear()
                end
              else
                print(string.format(
                  "Collision at Track %d, Column %d, Row %d. Cannot nudge further.", 
                  track_info.track_index, column_index, prev_line_index))
                -- Cannot move note due to collision
              end
            else
              -- Update the delay value
              note_column.delay_value = new_delay
              print(string.format(
                "Row %d, Column %d: Note %s, Delay %02X -> %02X",
                line_index, column_index, note_column.note_string, delay, new_delay))
            end
          end
        end
      else
        renoise.app():show_status("Invalid nudge direction!")
        return
      end
    end -- End of column iteration
  end -- End of track iteration

  renoise.song().selected_track.delay_column_visible=true
  -- Return focus to the pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Nudge " .. direction .. " with delay applied.")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge with Delay (Down)",invoke=function() nudge_with_delay("down") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge with Delay (Up)",invoke=function() nudge_with_delay("up") end}
-- Main function for toggling LPB and inserting ZLxx commands.
local function toggle_lpb_and_insert_commands()
  local song=renoise.song()
  local pattern=song.selected_pattern
  local track_idx=song.selected_track_index
  local line_idx=song.selected_line_index
  local track=song.tracks[track_idx]
  
  if track.type~=renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("ZLxx commands can only be applied to regular tracks!")
    return
  end

  -- Read LPB from the first row of the track (stored LPB).
  local first_line=pattern:track(track_idx):line(1)
  local stored_lpb=nil
  
  if first_line.effect_columns[1].number_string=="ZL" then
    stored_lpb=first_line.effect_columns[1].amount_value -- Read the stored LPB.
  else
    -- If no stored LPB, write the current LPB to the first row.
    stored_lpb=song.transport.lpb
    first_line.effect_columns[1].number_string="ZL"
    first_line.effect_columns[1].amount_value=stored_lpb
    renoise.app():show_status("Stored LPB="..stored_lpb.." in the first row.")
  end

  -- Calculate LPB/4.
  local lpb_div_4=math.max(1, math.floor(stored_lpb/4)) -- Ensure it's at least 1.

  -- Toggle LPB: If current LPB=LPB/4, switch back to stored LPB. Otherwise, set to LPB/4.
  if song.transport.lpb==lpb_div_4 then
    song.transport.lpb=stored_lpb
    renoise.app():show_status("Restored LPB to original value: "..stored_lpb)
  else
    song.transport.lpb=lpb_div_4
    renoise.app():show_status("Set LPB to LPB/4: "..lpb_div_4)
  end

  -- Insert ZL01 at the current line.
  local current_line=pattern:track(track_idx):line(line_idx)
  current_line.effect_columns[1].number_string="ZL"
  current_line.effect_columns[1].amount_value=1

  -- Insert ZLxx (stored LPB) at the calculated next position.
  local pattern_length=pattern.number_of_lines
  local next_idx=line_idx+lpb_div_4
  if next_idx>pattern_length then
    next_idx=(next_idx-pattern_length)%pattern_length -- Wrap to the first row.
  end

  local next_line=pattern:track(track_idx):line(next_idx)
  next_line.effect_columns[1].number_string="ZL"
  next_line.effect_columns[1].amount_value=stored_lpb

  -- Return focus to the pattern editor.
  renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Inserted ZL01 and ZL"..stored_lpb.." commands!")
  renoise.song().transport.lpb=stored_lpb
end

renoise.tool():add_keybinding{name="Global:Paketti:Divide LPB by 4, return to Original",invoke=function() toggle_lpb_and_insert_commands() end}
-------
function globalCenter()
local song=renoise.song()

-- Calculate the total number of tracks
local total_tracks=song.sequencer_track_count+1+song.send_track_count

-- Iterate through each track and set panning values
for i=1,total_tracks do
  local track=song.tracks[i]
  track.postfx_panning.value=0.5
  track.prefx_panning.value=0.5
end

renoise.app():show_status("Panning values for all tracks set to 0.5")

end

renoise.tool():add_keybinding{name="Global:Paketti:Set All Tracks to Hard Left",invoke=function() globalLeft() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set All Tracks to Hard Right",invoke=function() globalRight() end}
renoise.tool():add_keybinding{name="Global:Paketti:Set All Tracks to Center",invoke=function() globalCenter() end}


-------- Toggle Note Off "===" On / Off in all selected tracks within the selection or current row.
function PakettiNoteOffToSelection()
  local s = renoise.song()
  
  -- Pattern Editor handling
  if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      local selection = s.selection_in_pattern
      
      -- Handle selection or single note in pattern editor
      if selection then
          for line = selection.start_line, selection.end_line do
              for track = selection.start_track, selection.end_track do
                  -- Get the number of visible note columns for this track
                  local visible_columns = s.tracks[track].visible_note_columns
                  
                  -- Handle all visible note columns in the track
                  for col = 1, visible_columns do
                      local note_col = s.selected_pattern.tracks[track].lines[line].note_columns[col]
                      if note_col then
                          if note_col.note_string == "OFF" then
                              note_col.note_string = ""
                          else
                              note_col.note_string = "OFF"
                              note_col.instrument_value = 255  -- Clear instrument column
                          end
                      end
                  end
              end
          end
          renoise.app():show_status("Toggled note Off in pattern selection")
      else
          -- Single note toggle in pattern editor
          local note_col_idx = s.selected_note_column_index
          if not note_col_idx or note_col_idx == 0 then
              renoise.app():show_status("No note column selected in pattern")
              return
          end
          
          local note_col = s.selected_pattern_track.lines[s.selected_line_index].note_columns[note_col_idx]
          if note_col then
              if note_col.note_string == "OFF" then
                  note_col.note_string = ""
              else
                  note_col.note_string = "OFF"
                  note_col.instrument_value = 255  -- Clear instrument column
              end
          end
          renoise.app():show_status("Toggled note Off in pattern current note")
      end
      
  -- Phrase Editor handling remains the same
  elseif renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
      -- Get current phrase
      local phrase = s.selected_phrase
      if not phrase then
          renoise.app():show_status("No phrase selected")
          return
      end
      
      -- Get selection in phrase
      local selection = s.selection_in_phrase
      
      if selection then
          -- Handle selection in phrase editor
          for line = selection.start_line, selection.end_line do
              -- Handle all note columns in the selection range
              for col = selection.start_column, selection.end_column do
                  local note_col = phrase.lines[line].note_columns[col]
                  if note_col then
                      if note_col.note_string == "OFF" then
                          note_col.note_string = ""
                      else
                          note_col.note_string = "OFF"
                          note_col.instrument_value = 255  -- Clear instrument column
                      end
                  end
              end
          end
          renoise.app():show_status("Toggled note Off in phrase selection")
      else
          -- Single note toggle - use currently selected note column
          local note_col_idx = s.selected_phrase_note_column_index
          if not note_col_idx or note_col_idx == 0 then
              renoise.app():show_status("No note column selected in phrase")
              return
          end
          
          local note_col = phrase.lines[s.selected_phrase_line_index].note_columns[note_col_idx]
          if note_col then
              if note_col.note_string == "OFF" then
                  note_col.note_string = ""
              else
                  note_col.note_string = "OFF"
                  note_col.instrument_value = 255  -- Clear instrument column
              end
          end
          renoise.app():show_status("Toggled note Off in phrase current note")
      end
  else
      renoise.app():show_status("Not in Pattern Editor or Phrase Editor")
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Note Off in Selected Tracks",invoke=function() PakettiNoteOffToSelection() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Toggle Note Off in Selected Tracks",invoke=function() PakettiNoteOffToSelection() end}
-------
-- Function with an option to retain or clear silence rows
local function DuplicateSelectionWithPaddingMoveCursor(retain_silence_content)
    local song=renoise.song()
    local selection = song.selection_in_pattern

    -- Check if there's a selection
    if not selection then
        renoise.app():show_status("Nothing was selected, doing nothing.")
        return
    end

    local pattern = song.selected_pattern
    local pattern_lines = pattern.number_of_lines
    local selected_track_index = song.selected_track_index

    -- Determine selection start and end lines
    local start_line = selection.start_line
    local end_line = selection.end_line
    local selection_length = end_line - start_line + 1

    -- Calculate required end position to fit content, silence, content, and final silence
    local required_end_position = end_line + (selection_length * 3)  -- original + silence + duplicated + final silence

    -- Check if the required pattern length exceeds the max limit of 512 lines
    if required_end_position > 512 then
        renoise.app():show_status("Already at maximum pattern length, doing nothing.")
        return
    end

    -- Resize pattern only if required end position exceeds current length
    if required_end_position > pattern_lines then
        pattern.number_of_lines = required_end_position
        pattern_lines = required_end_position
        renoise.app():show_status("Pattern resized to " .. required_end_position .. " lines to accommodate duplication and silence.")
    end

    -- Calculate positions for silent rows and duplicated content
    local silence_start = end_line + 1
    local paste_start = silence_start + selection_length
    local paste_end = paste_start + selection_length - 1
    local final_silence_start = paste_end + 1

    -- Reference to the track for modifying lines
    local track = pattern:track(selected_track_index)

    -- Copy the selected lines into a table
    local content_copy = {}
    for line = start_line, end_line do
        local line_data = track:line(line)
        content_copy[#content_copy + 1] = {
            note_columns = {},
            effect_columns = {}
        }
        -- Copy each note column
        for nc = 1, #line_data.note_columns do
            local note_column = line_data:note_column(nc)
            content_copy[#content_copy].note_columns[nc] = {
                note_value = note_column.note_value,
                instrument_value = note_column.instrument_value,
                volume_value = note_column.volume_value,
                panning_value = note_column.panning_value,
                delay_value = note_column.delay_value,
                effect_number_value = note_column.effect_number_value,
                effect_amount_value = note_column.effect_amount_value
            }
        end
        -- Copy each effect column
        for ec = 1, #line_data.effect_columns do
            local effect_column = line_data:effect_column(ec)
            content_copy[#content_copy].effect_columns[ec] = {
                number_value = effect_column.number_value,
                amount_value = effect_column.amount_value
            }
        end
    end

    -- Insert silence after original content (retain or clear based on function parameter)
    for line = silence_start, silence_start + selection_length - 1 do
        if not retain_silence_content then
            track:line(line):clear()
        end
    end

    -- Paste duplicated content after the silent rows
    for i, line_content in ipairs(content_copy) do
        local target_line = track:line(paste_start + i - 1)
        -- Paste note columns
        for nc, note_data in ipairs(line_content.note_columns) do
            local note_column = target_line:note_column(nc)
            note_column.note_value = note_data.note_value
            note_column.instrument_value = note_data.instrument_value
            note_column.volume_value = note_data.volume_value
            note_column.panning_value = note_data.panning_value
            note_column.delay_value = note_data.delay_value
            note_column.effect_number_value = note_data.effect_number_value
            note_column.effect_amount_value = note_data.effect_amount_value
        end
        -- Paste effect columns
        for ec, effect_data in ipairs(line_content.effect_columns) do
            local effect_column = target_line:effect_column(ec)
            effect_column.number_value = effect_data.number_value
            effect_column.amount_value = effect_data.amount_value
        end
    end

    -- Insert final silence after the duplicated content (retain or clear based on function parameter)
    for line = final_silence_start, final_silence_start + selection_length - 1 do
        if not retain_silence_content then
            track:line(line):clear()
        end
    end

    -- Set selection and move cursor to the equivalent row in the pasted content
    song.selection_in_pattern = {
        start_line = paste_start,
        end_line = paste_end,
        start_track = selection.start_track,
        end_track = selection.end_track
    }
    song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, paste_start + (song.transport.edit_pos.line - start_line))
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Selection with Padding&Move Cursor 1",invoke=function() DuplicateSelectionWithPaddingMoveCursor(false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Selection with Padding&Move Cursor 2",invoke=function() DuplicateSelectionWithPaddingMoveCursor(true) end}
------
function NudgeAndPasteSelection(deselect)
    local song=renoise.song()
    local selection = song.selection_in_pattern

    -- Check if there's a selection
    if not selection then
        renoise.app():show_status("Nothing was selected, doing nothing.")
        return
    end

    local pattern = song.selected_pattern
    local pattern_lines = pattern.number_of_lines
    local selected_track_index = song.selected_track_index

    -- Determine selection start and end lines
    local start_line = selection.start_line
    local end_line = selection.end_line
    local selection_length = end_line - start_line + 1

    -- Reference to the track for modifying lines
    local track = pattern:track(selected_track_index)

    -- Step 1: Copy the selected lines into a table
    local content_copy = {}
    for line = start_line, end_line do
        local line_data = track:line(line)
        content_copy[#content_copy + 1] = {
            note_columns = {},
            effect_columns = {}
        }
        -- Copy each note column
        for nc = 1, #line_data.note_columns do
            local note_column = line_data:note_column(nc)
            content_copy[#content_copy].note_columns[nc] = {
                note_value = note_column.note_value,
                instrument_value = note_column.instrument_value,
                volume_value = note_column.volume_value,
                panning_value = note_column.panning_value,
                delay_value = note_column.delay_value,
                effect_number_value = note_column.effect_number_value,
                effect_amount_value = note_column.effect_amount_value
            }
        end
        -- Copy each effect column
        for ec = 1, #line_data.effect_columns do
            local effect_column = line_data:effect_column(ec)
            content_copy[#content_copy].effect_columns[ec] = {
                number_value = effect_column.number_value,
                amount_value = effect_column.amount_value
            }
        end
    end

    -- Step 2: Nudge existing content down by the selection length
    for line = pattern_lines - selection_length, start_line, -1 do
        local target_line = line + selection_length
        if target_line <= pattern_lines then
            track:line(target_line):copy_from(track:line(line))
        end
    end

    -- Step 3: Clear the original selection range to prepare for pasting
    for line = start_line, end_line do
        track:line(line):clear()
    end

    -- Step 4: Paste the copied content into the original selection position
    for i, line_content in ipairs(content_copy) do
        local target_line = track:line(start_line + i - 1)
        -- Paste note columns
        for nc, note_data in ipairs(line_content.note_columns) do
            local note_column = target_line:note_column(nc)
            note_column.note_value = note_data.note_value
            note_column.instrument_value = note_data.instrument_value
            note_column.volume_value = note_data.volume_value
            note_column.panning_value = note_data.panning_value
            note_column.delay_value = note_data.delay_value
            note_column.effect_number_value = note_data.effect_number_value
            note_column.effect_amount_value = note_data.effect_amount_value
        end
        -- Paste effect columns
        for ec, effect_data in ipairs(line_content.effect_columns) do
            local effect_column = target_line:effect_column(ec)
            effect_column.number_value = effect_data.number_value
            effect_column.amount_value = effect_data.amount_value
        end
    end

    -- Set selection in pattern to the newly pasted content
if deselect ~= false then

    song.selection_in_pattern = {
        start_line = start_line,
        end_line = end_line,
        start_track = selection.start_track,
        end_track = selection.end_track
    }
else renoise.song().selection_in_pattern = nil
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge and Paste Selection",invoke=function() NudgeAndPasteSelection(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge and Paste Selection + Deselect",invoke=function() NudgeAndPasteSelection(false) end}
------
---------------------------------------------------------------------------------------------------------
-- Nudge by Delay or Row (works on selection or current cell)
---------------------------------------------------------------------------------------------------------
function PakettiPatternEditorNudgeHelperSelectCurrentCell()
  local song=renoise.song()
  local selected_line = song.transport.edit_pos.line
  local selected_track = song.selected_track_index
  local selected_note_column = song.selected_note_column_index
  local selected_effect_column = song.selected_effect_column_index
  
  local column_index
  if selected_note_column > 0 then
    column_index = selected_note_column
  elseif selected_effect_column > 0 then
    local track = song:track(selected_track)
    column_index = track.visible_note_columns + selected_effect_column
  else
    column_index = 1
  end
  
  song.selection_in_pattern = {
    start_line = selected_line,
    end_line = selected_line,
    start_track = selected_track,
    end_track = selected_track,
    start_column = column_index,
    end_column = column_index
  }
end

function PakettiPatternEditorNudgeClearSelection()
  renoise.song().selection_in_pattern = nil
end

function PakettiPatternEditorNudgeMoveEditCursorUp()
  local song=renoise.song()
  local edit_pos = song.transport.edit_pos
  if edit_pos.line > 1 then
    edit_pos.line = edit_pos.line - 1
    song.transport.edit_pos = edit_pos
  end
end

function PakettiPatternEditorNudgeMoveEditCursorDown()
  local song=renoise.song()
  local edit_pos = song.transport.edit_pos
  local pattern_length = song.selected_pattern.number_of_lines
  if edit_pos.line < pattern_length then
    edit_pos.line = edit_pos.line + 1
    song.transport.edit_pos = edit_pos
  end
end

function PakettiPatternEditorNudgeGetSelectionInfo()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    return nil
  end
  
  local result = {
    start_line = selection.start_line,
    end_line = selection.end_line,
    start_track = selection.start_track,
    end_track = selection.end_track,
    start_column = selection.start_column,
    end_column = selection.end_column,
    note_columns = {},
    effect_columns = {}
  }
  
  for track_idx = selection.start_track, selection.end_track do
    local track = song:track(track_idx)
    local visible_note_columns = track.visible_note_columns
    local visible_effect_columns = track.visible_effect_columns
    
    local first_col = (track_idx == selection.start_track) and selection.start_column or 1
    local last_col = (track_idx == selection.end_track) and selection.end_column or (visible_note_columns + visible_effect_columns)
    
    for col_idx = first_col, last_col do
      if col_idx <= visible_note_columns then
        table.insert(result.note_columns, {track = track_idx, column = col_idx})
      else
        local effect_col = col_idx - visible_note_columns
        if effect_col <= visible_effect_columns then
          table.insert(result.effect_columns, {track = track_idx, column = effect_col})
        end
      end
    end
  end
  
  return result
end

function PakettiPatternEditorNudgeByDelay(steps)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local using_edit_cursor = false
  
  if not song.selection_in_pattern then
    if song.selected_effect_column_index ~= 0 then
      renoise.app():show_status("Cannot nudge effect columns by delay")
      return
    elseif song.selected_note_column_index ~= 0 then
      PakettiPatternEditorNudgeHelperSelectCurrentCell()
      using_edit_cursor = true
    else
      return
    end
  end
  
  local selection_info = PakettiPatternEditorNudgeGetSelectionInfo()
  if not selection_info then
    return
  end
  
  if #selection_info.effect_columns > 0 then
    renoise.app():show_status("Cannot nudge effect columns by delay")
    return
  end
  
  local column_entry_moved_to_new_line = false
  local something_was_nudged = false
  local is_single_cell = (selection_info.start_line == selection_info.end_line)
  
  for track_idx = selection_info.start_track, selection_info.end_track do
    local track = song:track(track_idx)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.delay_column_visible = true
    end
  end
  
  for _, col_info in ipairs(selection_info.note_columns) do
    local track = pattern:track(col_info.track)
    
    if steps > 0 then
      for line_idx = selection_info.end_line, selection_info.start_line, -1 do
        local line = track:line(line_idx)
        local note_column = line:note_column(col_info.column)
        
        if not note_column.is_empty then
          local current_delay = note_column.delay_value
          local new_delay = current_delay + steps
          
          if new_delay > 255 then
            local next_line_idx = line_idx + 1
            if is_single_cell then
              if next_line_idx > pattern.number_of_lines then
                next_line_idx = 1
              end
            else
              if next_line_idx > selection_info.end_line then
                next_line_idx = selection_info.start_line
              end
            end
            
            local next_line = track:line(next_line_idx)
            local next_note_column = next_line:note_column(col_info.column)
            
            if next_note_column.is_empty and next_note_column.delay_value == 0 then
              next_note_column:copy_from(note_column)
              next_note_column.delay_value = new_delay - 256
              note_column:clear()
              column_entry_moved_to_new_line = true
              something_was_nudged = true
            else
              note_column.delay_value = 255
              something_was_nudged = true
            end
          else
            note_column.delay_value = new_delay
            something_was_nudged = true
          end
        end
      end
    else
      for line_idx = selection_info.start_line, selection_info.end_line do
        local line = track:line(line_idx)
        local note_column = line:note_column(col_info.column)
        
        if not note_column.is_empty then
          local current_delay = note_column.delay_value
          local new_delay = current_delay + steps
          
          if new_delay < 0 then
            local prev_line_idx = line_idx - 1
            if is_single_cell then
              if prev_line_idx < 1 then
                prev_line_idx = pattern.number_of_lines
              end
            else
              if prev_line_idx < selection_info.start_line then
                prev_line_idx = selection_info.end_line
              end
            end
            
            local prev_line = track:line(prev_line_idx)
            local prev_note_column = prev_line:note_column(col_info.column)
            
            if prev_note_column.is_empty and prev_note_column.delay_value == 0 then
              prev_note_column:copy_from(note_column)
              prev_note_column.delay_value = new_delay + 256
              note_column:clear()
              column_entry_moved_to_new_line = true
              something_was_nudged = true
            else
              note_column.delay_value = 0
              something_was_nudged = true
            end
          else
            note_column.delay_value = new_delay
            something_was_nudged = true
          end
        end
      end
    end
  end
  
  if using_edit_cursor then
    PakettiPatternEditorNudgeClearSelection()
    if column_entry_moved_to_new_line then
      if is_single_cell then
        if steps > 0 then
          local target_line = selection_info.start_line + 1
          if target_line > pattern.number_of_lines then
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = 1}
          else
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = target_line}
          end
        else
          local target_line = selection_info.start_line - 1
          if target_line < 1 then
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = pattern.number_of_lines}
          else
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = target_line}
          end
        end
      else
        if steps > 0 then
          PakettiPatternEditorNudgeMoveEditCursorDown()
        else
          PakettiPatternEditorNudgeMoveEditCursorUp()
        end
      end
    end
  end
  
  if something_was_nudged then
    local direction = (steps > 0) and "down" or "up"
    renoise.app():show_status(string.format("Nudged %s by delay", direction))
  end
end

function PakettiPatternEditorNudgeByRow(direction)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local using_edit_cursor = false
  
  if not song.selection_in_pattern then
    if song.selected_effect_column_index ~= 0 then
      PakettiPatternEditorNudgeHelperSelectCurrentCell()
      using_edit_cursor = true
    elseif song.selected_note_column_index ~= 0 then
      PakettiPatternEditorNudgeHelperSelectCurrentCell()
      using_edit_cursor = true
    else
      return
    end
  end
  
  local selection_info = PakettiPatternEditorNudgeGetSelectionInfo()
  if not selection_info then
    return
  end
  
  local column_entry_moved = false
  local is_single_cell = (selection_info.start_line == selection_info.end_line)
  
  for _, col_info in ipairs(selection_info.note_columns) do
    local track = pattern:track(col_info.track)
    
    if is_single_cell then
      -- Single cell: calculate target and handle wrapping
      local source_idx = selection_info.start_line
      local target_idx = source_idx + direction
      local did_wrap = false
      
      if target_idx > pattern.number_of_lines then
        target_idx = 1
        did_wrap = true
      elseif target_idx < 1 then
        target_idx = pattern.number_of_lines
        did_wrap = true
      end
      
      local source_col = track:line(source_idx):note_column(col_info.column)
      local target_col = track:line(target_idx):note_column(col_info.column)
      
      -- Only move if source has content AND target is empty
      if not source_col.is_empty and target_col.is_empty then
        target_col:copy_from(source_col)
        source_col:clear()
        column_entry_moved = true
      end
    else
      -- Multi-row selection: use store-shift-place algorithm
      if direction > 0 then
        -- Nudge DOWN: Store last row, shift everything down, place stored at first row
        local stored_line = track:line(selection_info.end_line):note_column(col_info.column)
        local temp_note = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_note.note_value = stored_line.note_value
          temp_note.instrument_value = stored_line.instrument_value
          temp_note.volume_value = stored_line.volume_value
          temp_note.panning_value = stored_line.panning_value
          temp_note.delay_value = stored_line.delay_value
          temp_note.effect_number_value = stored_line.effect_number_value
          temp_note.effect_amount_value = stored_line.effect_amount_value
        end
        
        -- Shift all rows down (from end to start)
        for line_idx = selection_info.end_line, selection_info.start_line + 1, -1 do
          local curr_line = track:line(line_idx)
          local prev_line = track:line(line_idx - 1)
          curr_line:note_column(col_info.column):copy_from(prev_line:note_column(col_info.column))
          if not prev_line:note_column(col_info.column).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = track:line(selection_info.start_line)
        local target_col = target_line:note_column(col_info.column)
        target_col:clear()
        if has_stored_content then
          target_col.note_value = temp_note.note_value
          target_col.instrument_value = temp_note.instrument_value
          target_col.volume_value = temp_note.volume_value
          target_col.panning_value = temp_note.panning_value
          target_col.delay_value = temp_note.delay_value
          target_col.effect_number_value = temp_note.effect_number_value
          target_col.effect_amount_value = temp_note.effect_amount_value
          column_entry_moved = true
        end
      else
        -- Nudge UP: Store first row, shift everything up, place stored at last row
        local stored_line = track:line(selection_info.start_line):note_column(col_info.column)
        local temp_note = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_note.note_value = stored_line.note_value
          temp_note.instrument_value = stored_line.instrument_value
          temp_note.volume_value = stored_line.volume_value
          temp_note.panning_value = stored_line.panning_value
          temp_note.delay_value = stored_line.delay_value
          temp_note.effect_number_value = stored_line.effect_number_value
          temp_note.effect_amount_value = stored_line.effect_amount_value
        end
        
        -- Shift all rows up (from start to end)
        for line_idx = selection_info.start_line, selection_info.end_line - 1 do
          local curr_line = track:line(line_idx)
          local next_line = track:line(line_idx + 1)
          curr_line:note_column(col_info.column):copy_from(next_line:note_column(col_info.column))
          if not next_line:note_column(col_info.column).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = track:line(selection_info.end_line)
        local target_col = target_line:note_column(col_info.column)
        target_col:clear()
        if has_stored_content then
          target_col.note_value = temp_note.note_value
          target_col.instrument_value = temp_note.instrument_value
          target_col.volume_value = temp_note.volume_value
          target_col.panning_value = temp_note.panning_value
          target_col.delay_value = temp_note.delay_value
          target_col.effect_number_value = temp_note.effect_number_value
          target_col.effect_amount_value = temp_note.effect_amount_value
          column_entry_moved = true
        end
      end
    end
  end
  
  for _, col_info in ipairs(selection_info.effect_columns) do
    local track = pattern:track(col_info.track)
    
    if is_single_cell then
      -- Single cell: calculate target and handle wrapping
      local source_idx = selection_info.start_line
      local target_idx = source_idx + direction
      local did_wrap = false
      
      if target_idx > pattern.number_of_lines then
        target_idx = 1
        did_wrap = true
      elseif target_idx < 1 then
        target_idx = pattern.number_of_lines
        did_wrap = true
      end
      
      local source_col = track:line(source_idx):effect_column(col_info.column)
      local target_col = track:line(target_idx):effect_column(col_info.column)
      
      -- Only move if source has content AND target is empty
      if not source_col.is_empty and target_col.is_empty then
        target_col:copy_from(source_col)
        source_col:clear()
        column_entry_moved = true
      end
    else
      -- Multi-row selection: use store-shift-place algorithm
      if direction > 0 then
        -- Nudge DOWN: Store last row, shift everything down, place stored at first row
        local stored_line = track:line(selection_info.end_line):effect_column(col_info.column)
        local temp_effect = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_effect.number_value = stored_line.number_value
          temp_effect.amount_value = stored_line.amount_value
        end
        
        -- Shift all rows down (from end to start)
        for line_idx = selection_info.end_line, selection_info.start_line + 1, -1 do
          local curr_line = track:line(line_idx)
          local prev_line = track:line(line_idx - 1)
          curr_line:effect_column(col_info.column):copy_from(prev_line:effect_column(col_info.column))
          if not prev_line:effect_column(col_info.column).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = track:line(selection_info.start_line)
        local target_col = target_line:effect_column(col_info.column)
        target_col:clear()
        if has_stored_content then
          target_col.number_value = temp_effect.number_value
          target_col.amount_value = temp_effect.amount_value
          column_entry_moved = true
        end
      else
        -- Nudge UP: Store first row, shift everything up, place stored at last row
        local stored_line = track:line(selection_info.start_line):effect_column(col_info.column)
        local temp_effect = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_effect.number_value = stored_line.number_value
          temp_effect.amount_value = stored_line.amount_value
        end
        
        -- Shift all rows up (from start to end)
        for line_idx = selection_info.start_line, selection_info.end_line - 1 do
          local curr_line = track:line(line_idx)
          local next_line = track:line(line_idx + 1)
          curr_line:effect_column(col_info.column):copy_from(next_line:effect_column(col_info.column))
          if not next_line:effect_column(col_info.column).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = track:line(selection_info.end_line)
        local target_col = target_line:effect_column(col_info.column)
        target_col:clear()
        if has_stored_content then
          target_col.number_value = temp_effect.number_value
          target_col.amount_value = temp_effect.amount_value
          column_entry_moved = true
        end
      end
    end
  end
  
  if using_edit_cursor then
    PakettiPatternEditorNudgeClearSelection()
    if column_entry_moved then
      if is_single_cell then
        if direction > 0 then
          local target_line = selection_info.start_line + 1
          if target_line > pattern.number_of_lines then
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = 1}
          else
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = target_line}
          end
        else
          local target_line = selection_info.start_line - 1
          if target_line < 1 then
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = pattern.number_of_lines}
          else
            song.transport.edit_pos = {sequence = song.transport.edit_pos.sequence, line = target_line}
          end
        end
      else
        if direction > 0 then
          PakettiPatternEditorNudgeMoveEditCursorDown()
        else
          PakettiPatternEditorNudgeMoveEditCursorUp()
        end
      end
    end
  end
  
  if column_entry_moved then
    local dir_text = (direction > 0) and "down" or "up"
    renoise.app():show_status(string.format("Nudged %s by row", dir_text))
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Up by Delay",invoke=function() PakettiPatternEditorNudgeByDelay(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Down by Delay",invoke=function() PakettiPatternEditorNudgeByDelay(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Up by Row",invoke=function() PakettiPatternEditorNudgeByRow(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Down by Row",invoke=function() PakettiPatternEditorNudgeByRow(1) end}
------
function SelectionToNewPattern()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  -- Validate selection
  if not selection then
    renoise.app():show_status("No selection found in the pattern.")
    return
  end

  -- Calculate the selection length
  local selection_length = selection.end_line - selection.start_line + 1
  if selection_length <= 0 then
    renoise.app():show_status("Invalid selection length.")
    return
  end

  -- Clone the current sequence
  local current_sequence_index = song.selected_sequence_index
  local source_pattern_index = song.sequencer.pattern_sequence[current_sequence_index]
  
  -- Clone the sequence
  song.sequencer:clone_range(current_sequence_index, current_sequence_index)
  
  -- Move focus to the cloned sequence
  local new_sequence_index = current_sequence_index + 1
  song.selected_sequence_index = new_sequence_index
  
  -- Get the new pattern index
  local new_pattern_index = song.sequencer.pattern_sequence[new_sequence_index]
  local new_pattern = song.patterns[new_pattern_index]
  
  -- Resize the new pattern to match the selection
  new_pattern.number_of_lines = selection_length

  -- Copy the content from the selection into the new pattern
  local source_pattern = song.patterns[source_pattern_index]
  for track = selection.start_track, selection.end_track do
    local source_track = source_pattern.tracks[track]
    local dest_track = new_pattern.tracks[track]
    
    for line = selection.start_line, selection.end_line do
      dest_track:line(line - selection.start_line + 1):copy_from(source_track:line(line))
    end
  end

  -- Show status to the user
  renoise.app():show_status("Selection copied to a new pattern in the sequence.")

Deselect_All()
end



renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Create New Pattern with Selection",invoke=function() SelectionToNewPattern() end}
---
function HideAllEffectColumns()
  local song=renoise.song()
  
  -- Process only sequencer tracks (skip group, send, master)
  for i = 1, song.sequencer_track_count do
    local track = song.tracks[i]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Set to minimum of 1 effect column
      track.visible_effect_columns = 0
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Hide All Effect Columns",invoke=function() HideAllEffectColumns() end}


function moveTrackLeft()
  local song=renoise.song()
  local current_index = song.selected_track_index
  
  -- Check if we're at the leftmost movable position (track 1)
  if current_index <= 1 then
    local track_name = song.selected_track.name
    renoise.app():show_status(string.format("Track '%s' cannot be moved further to the left, doing nothing.", track_name))
    return
  end
  
  -- Swap with the track to the left
  song:swap_tracks_at(current_index, current_index - 1)
  
  -- Keep the moved track selected
  song.selected_track_index = current_index - 1
end

function moveTrackRight()
  local song=renoise.song()
  local current_index = song.selected_track_index
  local last_regular_track = song.sequencer_track_count
  
  -- Check if we're at the rightmost movable position (last track before master)
  if current_index >= last_regular_track then
    local track_name = song.selected_track.name
    renoise.app():show_status(string.format("Track '%s' cannot be moved further to the right, doing nothing.", track_name))
    return
  end
  
  -- Swap with the track to the right
  song:swap_tracks_at(current_index, current_index + 1)
  
  -- Keep the moved track selected
  song.selected_track_index = current_index + 1
end

renoise.tool():add_keybinding{name="Global:Paketti:Move Track Left",invoke=moveTrackLeft}
renoise.tool():add_keybinding{name="Global:Paketti:Move Track Right",invoke=moveTrackRight}


----
function randomly_raise_selected_notes_one_octave(probability)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local selection_data = selection_in_pattern_pro()
  
  probability = probability or 0.5
  
  if not selection_data then
    return
  end

  for _, track_info in ipairs(selection_data) do
    local track = song.tracks[track_info.track_index]
    local pattern_track = pattern.tracks[track_info.track_index]
    
    if #track_info.note_columns > 0 then
      for line_index = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
        for _, column_index in ipairs(track_info.note_columns) do
          local note_column = pattern_track:line(line_index):note_column(column_index)
          
          if note_column.note_value > 0 and note_column.note_value < 120 then
            if math.random() < probability then
              local new_note = note_column.note_value + 12
              
              if new_note <= 108 then
                note_column.note_value = new_note
              end
            end
          end
        end
      end
    end
  end
end



renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Random Selected Notes Octave Up 25% Probability",invoke=function() randomly_raise_selected_notes_one_octave(0.25) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Random Selected Notes Octave Up 50% Probability",invoke=function() randomly_raise_selected_notes_one_octave(0.5) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Random Selected Notes Octave Up 75% Probability",invoke=function() randomly_raise_selected_notes_one_octave(0.75) end}
---
-- Helper function to check if effect column is visible and exists
local function canWriteToEffectColumn()
  local song=renoise.song()
  local track = song.selected_track
  
  if not track then return false end
  
  -- Check if track has at least 1 effect column visible
  if track.visible_effect_columns < 1 then
    renoise.app():show_status("Track needs at least one visible effect column")
    return false
  end
  
  return true
end

-- Helper function to write effect to pattern
function writeEffectToPattern(effect_string, first_row_effect)
  if not canWriteToEffectColumn() then return end
  
  local song=renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  
  -- Safety checks
  if not pattern or not track_index then return end
  
  -- Get number of lines in pattern
  local num_lines = pattern.number_of_lines
  
  -- Process each line
  for line_index = 1, num_lines do
    local effect = effect_string
    local effect_column = pattern.tracks[track_index].lines[line_index].effect_columns[1]
    
    -- If first_row_effect is specified, use it for the first row
    if line_index == 1 and first_row_effect then
      effect = first_row_effect
    end
    
    -- Parse the effect string (format: "0D00")
    local number_string = effect:sub(1,2)  -- "0D"
    local amount_string = effect:sub(3,4)  -- "00"
    
    -- Set the values using number_string and amount_string
    effect_column.number_string = number_string
    effect_column.amount_string = amount_string
  end

  -- After writing, focus the effect column where 0D00/0U00 starts (second row for 0G01 patterns)
  if first_row_effect then
    song.selected_line_index = 2
  else
    song.selected_line_index = 1
  end
  song.selected_effect_column_index = 1  -- Select first effect column
  renoise.song().transport.edit_step = 0
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Fill Effect Column with 0D00",invoke=function() writeEffectToPattern("0D00") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Fill Effect Column with 0U00",invoke=function() writeEffectToPattern("0U00") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Fill Effect Column with 0G01+0D00",invoke=function() writeEffectToPattern("0D00", "0G01") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Fill Effect Column with 0G01+0U00",invoke=function() writeEffectToPattern("0U00", "0G01") end}


renoise.tool():add_midi_mapping{name="Paketti:Fill Effect Column with 0D00 [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      writeEffectToPattern("0D00")
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Fill Effect Column with 0U00 [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      writeEffectToPattern("0U00")
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Fill Effect Column with 0G01+0D00 [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      writeEffectToPattern("0D00", "0G01")
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Fill Effect Column with 0G01+0U00 [Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      writeEffectToPattern("0U00", "0G01")
    end
  end}


------
function deleteUnusedColumns()
  local song=renoise.song()
  local patterns = song.patterns
  local tracks = song.tracks
  
  -- For each track
  for track_idx, track in ipairs(tracks) do
    local max_used_note_col = 0
    local max_used_fx_col = 0
    
    -- Skip note column check for Group, Send, and Master tracks
    local check_notes = (track.type == renoise.Track.TRACK_TYPE_SEQUENCER)
    
    -- For each pattern
    for _, pattern in ipairs(patterns) do
      -- Skip empty patterns
      if not pattern.is_empty then
        local pattern_track = pattern:track(track_idx)
        
        -- Check each line in the pattern
        for line_idx = 1, pattern.number_of_lines do
          local line = pattern_track:line(line_idx)
          
          -- Check note columns (only for regular tracks)
          if check_notes then
            for note_col_idx = 1, track.visible_note_columns do
              local note_col = line:note_column(note_col_idx)
              -- Check if column contains any data
              if not note_col.is_empty then
                max_used_note_col = math.max(max_used_note_col, note_col_idx)
              end
            end
          end
          
          -- Check effect columns
          for fx_col_idx = 1, track.visible_effect_columns do
            local fx_col = line:effect_column(fx_col_idx)
            -- Check if column contains any effect data
            if not fx_col.is_empty then
                max_used_fx_col = math.max(max_used_fx_col, fx_col_idx)
            end
          end
        end
      end
    end
    
    -- Update visible columns
    if check_notes and max_used_note_col > 0 then
      track.visible_note_columns = max_used_note_col
    end
    
    -- Update effect columns
    if max_used_fx_col > 0 then
      track.visible_effect_columns = max_used_fx_col
    else
      track.visible_effect_columns = 1  -- Hide all effect columns if none are used
    end
  end
  
  renoise.app():show_status("Unused columns have been removed")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delete Unused Columns", invoke = deleteUnusedColumns}

for i=1,32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Quantization to ".. formatDigits(2,i), invoke=function() renoise.song().transport.record_quantize_line = i end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Quantization to ".. formatDigits(2,i), invoke=function() renoise.song().transport.record_quantize_line = i end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Set Quantization to ".. formatDigits(2,i), invoke=function() renoise.song().transport.record_quantize_line = i end}
end


function move_dsps_to_adjacent_track(direction)
  local song=renoise.song()
  local current_track_index = song.selected_track_index
  local current_track = song.tracks[current_track_index]
  
  -- Determine target track index with wrapping
  local target_track_index
  if direction < 0 and current_track_index == 1 then
    target_track_index = #song.tracks  -- Wrap to last track
  elseif direction > 0 and current_track_index == #song.tracks then
    target_track_index = 1  -- Wrap to first track
  else
    target_track_index = current_track_index + direction
  end
  
  local target_track = song.tracks[target_track_index]
  
  -- Store the devices to move (skip the first device which is the volume/pan)
  local devices_to_move = {}
  for i = 2, #current_track.devices do
    local device = current_track.devices[i]
    -- Store device path, parameters, and maximizer state
    local params = {}
    for _, param in ipairs(device.parameters) do
      params[#params + 1] = param.value
    end
    devices_to_move[#devices_to_move + 1] = {
      path = device.device_path,
      parameters = params,
      is_maximized = device.is_maximized
    }
  end
  
  if #devices_to_move == 0 then
    renoise.app():show_status("No DSP devices to move")
    return
  end
  
  -- Move devices to target track
  for _, device_data in ipairs(devices_to_move) do
    -- Add device to target track
    local new_device_index = #target_track.devices + 1
    target_track:insert_device_at(device_data.path, new_device_index)
    local new_device = target_track.devices[new_device_index]
    
    -- Restore parameter values
    for param_index, value in ipairs(device_data.parameters) do
      new_device.parameters[param_index].value = value
    end
    
    -- Restore maximizer state
    new_device.is_maximized = device_data.is_maximized
    
    -- Remove from original track
    current_track:delete_device_at(2) -- Always remove at position 2 since the list shifts
  end
  
  -- Select the target track
  song.selected_track_index = target_track_index
  
  renoise.app():show_status(string.format("Moved %d DSP devices to %s track", 
    #devices_to_move, 
    direction < 0 and "previous" or "next"))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Move DSPs to Previous Track",invoke=function() move_dsps_to_adjacent_track(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Move DSPs to Next Track",invoke=function() move_dsps_to_adjacent_track(1) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Move DSPs to Previous Track",invoke=function() move_dsps_to_adjacent_track(-1) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Move DSPs to Next Track",invoke=function() move_dsps_to_adjacent_track(1) end}

---
function move_selected_dsp_to_adjacent_track(direction)
  local song=renoise.song()
  local current_track_index = song.selected_track_index
  local current_track = song.tracks[current_track_index]
  
  -- Get the selected device index
  local selected_device_index = song.selected_device_index
  if not selected_device_index then
    renoise.app():show_status("No DSP device selected")
    return
  end
  
  local selected_device = current_track.devices[selected_device_index]
  
  -- Determine target track index with wrapping
  local target_track_index
  if direction < 0 and current_track_index == 1 then
    target_track_index = #song.tracks  -- Wrap to last track
  elseif direction > 0 and current_track_index == #song.tracks then
    target_track_index = 1  -- Wrap to first track
  else
    target_track_index = current_track_index + direction
  end
  
  local target_track = song.tracks[target_track_index]
  
  -- Store device data
  local params = {}
  for _, param in ipairs(selected_device.parameters) do
    params[#params + 1] = param.value
  end
  local device_data = {
    path = selected_device.device_path,
    parameters = params,
    is_maximized = selected_device.is_maximized
  }
  
  -- Add device to target track
  local new_device_index = #target_track.devices + 1
  target_track:insert_device_at(device_data.path, new_device_index)
  local new_device = target_track.devices[new_device_index]
  
  -- Restore parameter values
  for param_index, value in ipairs(device_data.parameters) do
    new_device.parameters[param_index].value = value
  end
  
  -- Restore maximizer state
  new_device.is_maximized = device_data.is_maximized
  
  -- Remove from original track
  current_track:delete_device_at(selected_device_index)
  
  -- Select the target track
  song.selected_track_index = target_track_index
  song.selected_device_index = new_device_index  
  
  renoise.app():show_status(string.format("Moved selected DSP to %s track", 
    direction < 0 and "previous" or "next"))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Move Selected DSP to Previous Track",invoke=function() move_selected_dsp_to_adjacent_track(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Move Selected DSP to Next Track",invoke=function() move_selected_dsp_to_adjacent_track(1) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Move Selected DSP to Previous Track",invoke=function() move_selected_dsp_to_adjacent_track(-1) end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Move Selected DSP to Next Track",invoke=function() move_selected_dsp_to_adjacent_track(1) end}


---------
function create_group_and_move_dsps()
  local song=renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_track = song.tracks[selected_track_index]
  
  -- Create a new group track after the selected track
  song:insert_group_at(selected_track_index + 1)
  
  -- Add the selected track to the group
  song:add_track_to_group(selected_track_index, selected_track_index + 1)
  
  -- Get reference to the group track
  local group_track = song.tracks[selected_track_index + 1]
  
  -- Store the devices to move with their parameter values
  local devices_to_move = {}
  for i = 2, #selected_track.devices do
    local device = selected_track.devices[i]
    -- Store device path, parameter values, and minimized state
    local params = {}
    for _, param in ipairs(device.parameters) do
      params[#params + 1] = param.value
    end
    devices_to_move[#devices_to_move + 1] = {
      path = device.device_path,
      parameters = params,
      is_maximized = device.is_maximized  -- Store maximized state
 
    }
  end
  
  -- Move devices to group track
  for _, device_data in ipairs(devices_to_move) do
    -- Add device to group track
    local new_device_index = #group_track.devices + 1
    group_track:insert_device_at(device_data.path, new_device_index)
    local new_device = group_track.devices[new_device_index]
    
    -- Restore parameter values
    for param_index, value in ipairs(device_data.parameters) do
      new_device.parameters[param_index].value = value
    end
    
    -- Restore minimized state
    new_device.is_maximized = device_data.is_maximized
        
    -- Remove from original track
    selected_track:delete_device_at(2) -- Always remove at position 2 since the list shifts
  end  
  -- Create a new track after the grouped track
  song:insert_track_at(selected_track_index + 2)
  
  -- Add the new track to the group
  song:add_track_to_group(selected_track_index + 2, selected_track_index + 1)
  
  -- Select the newly created track
  song.selected_track_index = selected_track_index + 1
  
  renoise.app():show_status("Created group and moved DSP devices")
end



renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Create Group and Move DSPs",invoke=create_group_and_move_dsps}
renoise.tool():add_keybinding{name="Mixer:Paketti:Create Group and Move DSPs",invoke=create_group_and_move_dsps}


-------
function applyNoteColumnEffects()
  local s = renoise.song()
  local track = s:track(s.selected_track_index)
  local pattern_track = s.selected_pattern:track(s.selected_track_index)
  local selected_column = s.selected_note_column_index
  
  -- Enable Sample Effects visibility for the track
  track.sample_effects_column_visible = true
  
  -- Check if we have a valid note column selected
  if selected_column == 0 then return end
  
  -- Process each visible note column
  for i = 1, track.visible_note_columns do
    local note_column = pattern_track:line(s.selected_line_index):note_column(i)
    
    -- Apply MFF to selected column, M00 to others
    if i == selected_column then
      note_column.effect_number_string = "0M"
      note_column.effect_amount_string = "FF"
    else
      note_column.effect_number_string = "0M"
      note_column.effect_amount_string = "00"
    end
  end
end

function clearNoteColumnEffects()
  local s = renoise.song()
  local track = s:track(s.selected_track_index)
  local pattern_track = s.selected_pattern:track(s.selected_track_index)
  
  -- Process each visible note column for the entire pattern
  for i = 1, track.visible_note_columns do
    for line_index = 1, s.selected_pattern.number_of_lines do
      local note_column = pattern_track:line(line_index):note_column(i)
      
      -- Clear effect values if they're M00 or MFF
      if (note_column.effect_number_string == "0M" and 
          (note_column.effect_amount_string == "00" or 
           note_column.effect_amount_string == "FF")) then
        note_column.effect_number_string = ""
        note_column.effect_amount_string = ""
      end
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Apply Note Column Sample Effects M00/MFF",invoke=function() applyNoteColumnEffects() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear Note Column Sample Effects M00/MFF",invoke=function() clearNoteColumnEffects() end}


---
function globalLeft()
  local song=renoise.song()
  local total_tracks = song.sequencer_track_count + 1 + song.send_track_count
  
  for i = 1, total_tracks do
    local track = song.tracks[i]
    track.postfx_panning.value = 0.0
    track.prefx_panning.value = 0.0
  end
  
  renoise.app():show_status("Panning values for all tracks set to Hard Left")
end

function globalRight()
  local song=renoise.song()
  local total_tracks = song.sequencer_track_count + 1 + song.send_track_count
  
  for i = 1, total_tracks do
    local track = song.tracks[i]
    track.postfx_panning.value = 1.0
    track.prefx_panning.value = 1.0
  end
  
  renoise.app():show_status("Panning values for all tracks set to Hard Right")
end



--------------------------------------------------------------------------------
-- Template Mode Implementation
--------------------------------------------------------------------------------

-- Add template mode state variables - all declared at the top
local template_mode = false
local template_data = nil
local last_processed_time = 0
local REUSE_DELAY = 0.1 -- seconds

-- Function to check for note input (only runs when template_mode is enabled)
local function check_for_note_input()
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local line = track:line(song.selected_line_index)
  local note_col = line.note_columns[1]
  
  -- Only process if it's a new note
  if note_col.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
     note_col.note_value < 120 then  -- Only real notes, not OFF
    
    local current_time = os.clock()
    -- Process if enough time has passed since last note
    if (current_time - last_processed_time) > REUSE_DELAY then
      local current_note = note_col.note_value
      last_processed_time = current_time
      
      -- Clear the note that triggered the template
      note_col.note_value = renoise.PatternLine.EMPTY_NOTE
      
      -- Apply the template with the captured note
      apply_template(current_note)
    end
  end
end

-- Start template mode notifier (only adds if not already active)
local function start_template_mode_notifier()
  if not renoise.tool().app_idle_observable:has_notifier(check_for_note_input) then
    renoise.tool().app_idle_observable:add_notifier(check_for_note_input)
  end
end

-- Stop template mode notifier
local function stop_template_mode_notifier()
  if renoise.tool().app_idle_observable:has_notifier(check_for_note_input) then
    renoise.tool().app_idle_observable:remove_notifier(check_for_note_input)
  end
end

function toggle_template_mode()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("No selection in pattern, please select something first.")
    return
  end
  
  if not template_mode then
    -- Reset the time tracker when entering template mode
    last_processed_time = 0
    
    -- Store the template data when enabling template mode
    template_data = {
      max_effect_columns = 0,
      has_delay_column = false,
      lines = {}
    }
    local base_note = nil
    
    -- Store the selection data
    for line_idx = selection.start_line, selection.end_line do
      template_data.lines[line_idx - selection.start_line] = {}
      for track_idx = selection.start_track, selection.end_track do
        local track = song:track(track_idx)
        local pattern_track = song:pattern(song.selected_pattern_index):track(track_idx)
        local line = pattern_track:line(line_idx)
        
        -- Track maximum effect columns used
        template_data.max_effect_columns = math.max(template_data.max_effect_columns, track.visible_effect_columns)
        
        -- Store note column data
        template_data.lines[line_idx - selection.start_line][track_idx] = {
          note_columns = {},
          effect_columns = {}
        }
        
        -- Store note columns
        for col_idx = 1, track.visible_note_columns do
          local note_col = line.note_columns[col_idx]
          if note_col then
            -- Check for delay column usage
            if note_col.delay_value > 0 then
              template_data.has_delay_column = true
            end
            
            -- Store ALL column data regardless of note presence
            template_data.lines[line_idx - selection.start_line][track_idx].note_columns[col_idx] = {
              note_value = note_col.note_value,
              instrument_value = note_col.instrument_value,
              volume_value = note_col.volume_value,
              panning_value = note_col.panning_value,
              delay_value = note_col.delay_value,
              effect_number_value = note_col.effect_number_value,
              effect_amount_value = note_col.effect_amount_value,
              had_note = (note_col.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
                         note_col.note_value < 120),
              relative_note = (note_col.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
                             note_col.note_value < 120) and 
                             (note_col.note_value - (base_note or note_col.note_value)) or nil
            }
            
            -- Update base_note if this is the first actual note we've found
            if not base_note and note_col.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
               note_col.note_value < 120 then
              base_note = note_col.note_value
            end
          end
        end
        
        -- Store effect columns
        for fx_idx = 1, track.visible_effect_columns do
          local fx_col = line.effect_columns[fx_idx]
          if fx_col and (fx_col.number_value ~= 0 or fx_col.amount_value ~= 0) then
            template_data.lines[line_idx - selection.start_line][track_idx].effect_columns[fx_idx] = {
              number_value = fx_col.number_value,
              amount_value = fx_col.amount_value
            }
          end
        end
      end
    end
    
    template_mode = true
    -- Start the idle notifier to watch for note input
    start_template_mode_notifier()
    renoise.app():show_status("Template Mode ON - Input a note to transpose the template")
  else
    -- Disable template mode
    template_mode = false
    template_data = nil
    last_processed_time = 0
    -- Stop the idle notifier
    stop_template_mode_notifier()
    renoise.app():show_status("Template Mode OFF")
  end
end

-- Function to apply template at a specific note
function apply_template(target_note)
  if not template_mode or not template_data then return end
  
  local song=renoise.song()
  local current_track_idx = song.selected_track_index
  local current_line_idx = song.selected_line_index
  
  -- Get the current instrument value from the triggering note
  local current_line = song:pattern(song.selected_pattern_index):track(current_track_idx):line(current_line_idx)
  local current_instrument = current_line.note_columns[1].instrument_value
  
  -- Adjust track settings if needed
  local track = song:track(current_track_idx)
  if track.visible_effect_columns < template_data.max_effect_columns then
    track.visible_effect_columns = template_data.max_effect_columns
  end
  if template_data.has_delay_column then
    track.delay_column_visible = true
  end
  
  -- Apply the template data
  for line_offset, line_data in pairs(template_data.lines) do
    local target_line_idx = current_line_idx + line_offset
    if target_line_idx <= song.selected_pattern.number_of_lines then
      for track_idx, track_data in pairs(line_data) do
        local pattern_track = song:pattern(song.selected_pattern_index):track(current_track_idx)
        local line = pattern_track:line(target_line_idx)
        
        -- Apply note columns
        for col_idx, note_data in pairs(track_data.note_columns) do
          if col_idx <= track.visible_note_columns then
            local note_col = line.note_columns[col_idx]
            if note_col then
              if note_data.had_note then
                -- This line had a note in the template, apply new note and instrument
                note_col.note_value = math.min(119, math.max(0, target_note + note_data.relative_note))
                if current_instrument ~= renoise.PatternLine.EMPTY_INSTRUMENT then
                  note_col.instrument_value = current_instrument
                else
                  note_col.instrument_value = note_data.instrument_value
                end
              else
                -- No note in template, just copy the original values
                note_col.note_value = note_data.note_value
                note_col.instrument_value = note_data.instrument_value
              end
              
              -- Always copy these values regardless of note presence
              note_col.volume_value = note_data.volume_value
              note_col.panning_value = note_data.panning_value
              note_col.delay_value = note_data.delay_value
              note_col.effect_number_value = note_data.effect_number_value
              note_col.effect_amount_value = note_data.effect_amount_value
            end
          end
        end
        
        -- Apply effect columns
        for fx_idx, fx_data in pairs(track_data.effect_columns) do
          if fx_idx <= track.visible_effect_columns then
            local fx_col = line.effect_columns[fx_idx]
            if fx_col then
              fx_col.number_value = fx_data.number_value
              fx_col.amount_value = fx_data.amount_value
            end
          end
        end
      end
    end
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Template Mode Note Input",
  invoke=function(message)
    if template_mode and message:is_note() then
      apply_template(message.note_value)
    end
  end
}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Template Mode",invoke = toggle_template_mode}

-- NOTE: check_for_note_input notifier is now ONLY added when template_mode is enabled
-- via toggle_template_mode() and removed when disabled, to avoid constant idle polling








local dialog = nil
function pakettiVolumeInterpolationLooper()
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  local vb = renoise.ViewBuilder()
  local DEFAULT_NOTES = 16
  local notes_count = DEFAULT_NOTES
  local start_val = 0
  local end_val = 128
  local current_mode = "volume"  -- Default mode
  local pingpong_enabled = false

  local function formatValue(value, mode)
    if mode == "delay" then
      return string.format("%02X (%d)", value, value)
    else
      -- For volume/panning, we need to show the hex value correctly
      -- value is in decimal (0-128), but we want to show it as 00-80 hex
      return string.format("%02X (%d)", value, value)
    end
  end


  local function apply_interpolation()
    local song=renoise.song()
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local track = song.tracks[track_index]
    
    -- Make column visible based on mode
    if current_mode == "volume" then
      track.volume_column_visible = true
    elseif current_mode == "panning" then
      track.panning_column_visible = true
    elseif current_mode == "delay" then
      track.delay_column_visible = true
    end

  local pattern = song:pattern(pattern_index)
  local track_data = pattern:track(track_index)
  local pattern_lines = pattern.number_of_lines
  
  -- First pass: Count actual notes in pattern
  local notes = {}
  for line_index = 1, pattern_lines do
    local line = track_data:line(line_index)
    local has_note = false
    for note_column_index = 1, track.visible_note_columns do
      if line:note_column(note_column_index).note_value ~= 121 then -- 121 is empty note
        has_note = true
        break
      end
    end
    if has_note then
      table.insert(notes, line_index)
    end
  end
  
  -- Check if pattern is empty
  if #notes == 0 then
    renoise.app():show_status("No notes to interpolate with, doing nothing")
    return
  end
  
    -- Calculate interpolation
    for i = 1, #notes do
      local cycle_position = ((i - 1) % notes_count)
      local factor
      local interpolated_val
      
      if pingpong_enabled then
        -- PingPong mode: go from start to end and back, but start value only hit once
        -- With 32 notes: 0→16→31, where 0 is start, 16 is end, 31 is almost start
        local half_cycle = math.floor(notes_count / 2)
        
        if cycle_position <= half_cycle then
          -- First half: start to end
          factor = cycle_position / half_cycle
          interpolated_val = math.floor(start_val + (end_val - start_val) * factor + 0.5)
        else
          -- Second half: end back to start (but not reaching start value again)
          local remaining_steps = notes_count - half_cycle
          factor = (cycle_position - half_cycle) / remaining_steps
          interpolated_val = math.floor(end_val - (end_val - start_val) * factor + 0.5)
        end
      else
        -- Normal mode: start to end
        factor = cycle_position / (math.max(1, notes_count - 1))
        interpolated_val = math.floor(start_val + (end_val - start_val) * factor)
      end
      
      -- Clamp values based on mode
      if current_mode == "delay" then
        interpolated_val = math.min(255, math.max(0, interpolated_val))
      else
        interpolated_val = math.min(128, math.max(0, interpolated_val))  -- Changed from 80 to 128
      end
      
      
      local line = track_data:line(notes[i])
      for note_column_index = 1, track.visible_note_columns do
        if line:note_column(note_column_index).note_value ~= 121 then
          if current_mode == "volume" then
            line:note_column(note_column_index).volume_value = interpolated_val
          elseif current_mode == "panning" then
            line:note_column(note_column_index).panning_value = interpolated_val
          elseif current_mode == "delay" then
            line:note_column(note_column_index).delay_value = interpolated_val
          end
        end
      end
    end
  end

  dialog = renoise.app():show_custom_dialog("Paketti Value Interpolation Looper",
    vb:column{
      width=250,
      vb:row{
        width=250,
        vb:switch {
          width=250,
          items = {"Volume", "Panning", "Delay"},
          value = 1,
          notifier=function(idx)
            current_mode = idx == 1 and "volume" or idx == 2 and "panning" or "delay"
            -- Update max value of sliders based on mode
            local max_val = current_mode == "delay" and 255 or 128  -- 128 decimal = 80 hex
            local start_slider = vb.views.start_slider
            local end_slider = vb.views.end_slider
            
            -- Adjust values if they were at previous max
            if start_val == start_slider.max then
              start_val = max_val
            end
            if end_val == end_slider.max then
              end_val = max_val
            end
            
            -- Update slider properties
            start_slider.max = max_val
            end_slider.max = max_val
            start_slider.value = start_val
            end_slider.value = end_val
            
            -- Update value displays
            vb.views.start_val_display.text = formatValue(start_val, current_mode)
            vb.views.end_val_display.text = formatValue(end_val, current_mode)
          end
        }
      },
      vb:row{
        width=250,
        vb:text{text="Notes",width=90, style="strong", font="bold" },
        vb:valuebox{
          min = 1,
          max = 512,
          value = DEFAULT_NOTES,
          notifier=function(value)
            notes_count = value
          end
        }
      },
      vb:row{
        width=250,
        vb:checkbox{
          value = pingpong_enabled,
          notifier=function(value)
            pingpong_enabled = value
          end
        },
        vb:text{text="PingPong", style="strong", font="bold" }
      },
      vb:row{
        width=250,
        vb:text{text="Start",width=90, style="strong", font="bold" },
        vb:slider{
          id = "start_slider",
          min = 0,
          max = 128,
          value = start_val,
          width=100,
          notifier=function(value)
            start_val = value
            vb.views.start_val_display.text = formatValue(value, current_mode)
          end
        },
        vb:text{
          id = "start_val_display",
          text = formatValue(start_val, current_mode)
        }
      },
      vb:row{
        width=250,
        vb:text{text="End",width=90, style="strong", font="bold" },
        vb:slider{
          id = "end_slider",
          min = 0,
          max = 128,
          value = end_val,
          width=100,
          notifier=function(value)
            end_val = value
            vb.views.end_val_display.text = formatValue(value, current_mode)
          end
        },
        vb:text{
          id = "end_val_display",
          text = formatValue(end_val, current_mode)
        }
      },
      vb:button{
        text="Print",
        notifier=function()
          apply_interpolation()
          renoise.app():show_status(string.format("%s interpolation applied", current_mode:upper()))
        end}
    },
    create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    ))
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Paketti Value Interpolation Looper Dialog...",invoke = pakettiVolumeInterpolationLooper}




--------
--[[----------------------------------------------------------------------------
  handle_above_effect_command
  Handles copying/incrementing/decrementing effect from the line above.
  @param operation: "copy", "inc", or "dec"
----------------------------------------------------------------------------]]--
function handle_above_effect_command(operation)
  local song = renoise.song()
  local pat = song.selected_pattern
  local track_idx = song.selected_track_index
  local line_idx = song.selected_line_index
  local effect_col_idx = song.selected_effect_column_index
  
  -- Check if we're on a note column
  if effect_col_idx == 0 then
    renoise.app():show_status("No effect column selected, doing nothing.")
    return
  end
  
  -- Check if we're on the first line
  if line_idx == 1 then
    renoise.app():show_status("Nothing above current row, doing nothing.")
    return
  end
  
  local track = pat:track(track_idx)
  local src = track:line(line_idx-1).effect_columns[effect_col_idx]
  
  -- Check if there's actually an effect to copy
  if src.number_string == "" and src.amount_string == "" then
    renoise.app():show_status("No effect to copy from above, doing nothing.")
    return
  end
  
  local dst = track:line(line_idx).effect_columns[effect_col_idx]
  
  -- Always copy the effect number
  dst.number_string = src.number_string
  
  if operation == "copy" then
    dst.amount_string = src.amount_string
  else
    -- Handle increment/decrement
    local num = tonumber(src.amount_string, 16)
    if num then
      if operation == "inc" then
        num = math.min(num + 1, 0xFF)
      elseif operation == "dec" then
        num = math.max(num - 1, 0x00)
      end
      dst.amount_string = string.format("%02X", num)
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Copy Above Effect Column",invoke=function() handle_above_effect_command("copy") end}
renoise.tool():add_keybinding{name="Global:Paketti:Copy Above Effect Column + Increase Value",invoke=function() handle_above_effect_command("inc") end}
renoise.tool():add_keybinding{name="Global:Paketti:Copy Above Effect Column + Decrease Value",invoke=function() handle_above_effect_command("dec") end}
renoise.tool():add_midi_mapping{name="Global:Paketti:Copy Above Effect Column",invoke=function(message) if message:is_trigger() then handle_above_effect_command("copy") end end}
renoise.tool():add_midi_mapping{name="Global:Paketti:Copy Above Effect Column + Increase Value",invoke=function(message) if message:is_trigger() then handle_above_effect_command("inc") end end}
renoise.tool():add_midi_mapping{name="Global:Paketti:Copy Above Effect Column + Decrease Value",invoke=function(message) if message:is_trigger() then handle_above_effect_command("dec") end end}

---
local match_editstep_enabled = false
local last_line_index = nil
local tick_counter = 0 -- To track the "tick-tick-tick-skip" cycle

-- Function to find the next valid delay value in the track
local function find_next_delay_line(start_line_index)
  local song=renoise.song()
  local track = song.selected_pattern_track
  local num_lines = song.selected_pattern.number_of_lines

  for line_index = start_line_index + 1, num_lines do
    local line = track:line(line_index)
    if line.note_columns[1] and not line.note_columns[1].is_empty then
      local delay_value = line.note_columns[1].delay_value
      if delay_value == 0x00 or delay_value == 0x55 or delay_value == 0xAA then
        return line_index
      end
    end
  end

  -- Wrap around: search from the top if no match is found below
  for line_index = 1, start_line_index do
    local line = track:line(line_index)
    if line.note_columns[1] and not line.note_columns[1].is_empty then
      local delay_value = line.note_columns[1].delay_value
      if delay_value == 0x00 or delay_value == 0x55 or delay_value == 0xAA then
        return line_index
      end
    end
  end

  return nil -- No valid delays found
end

-- Main function to dynamically adjust editstep
local function match_editstep_with_delay_pattern()
  local song=renoise.song()
  local current_line_index = song.selected_line_index

  -- Only act when the selected line changes
  if last_line_index ~= current_line_index then
    last_line_index = current_line_index

    -- Cycle through the "tick-tick-tick-skip" pattern
    local editstep = 0
    tick_counter = (tick_counter % 4) + 1 -- Cycle between 1-4

    if tick_counter == 4 then
      -- Skip step
      local next_line_index = find_next_delay_line(current_line_index)
      if next_line_index then
        editstep = next_line_index - current_line_index
        if editstep <= 0 then
          -- Wrap-around case
          editstep = (song.selected_pattern.number_of_lines - current_line_index) + next_line_index
        end
      else
        -- No valid delay found, reset to default behavior
        editstep = 1
      end
    else
      -- Standard tick step
      editstep = 1
    end

    -- Apply the editstep
    song.transport.edit_step = editstep
    renoise.app():show_status("EditStep set to " .. tostring(editstep) ..
      " (Cycle position: " .. tostring(tick_counter) .. ")")
  end
end

-- Toggle the functionality on or off
function toggle_match_editstep()
  match_editstep_enabled = not match_editstep_enabled
  if match_editstep_enabled then
    if not renoise.tool().app_idle_observable:has_notifier(match_editstep_with_delay_pattern) then
      renoise.tool().app_idle_observable:add_notifier(match_editstep_with_delay_pattern)
    end
    renoise.app():show_status("Match EditStep with Delay Pattern: ENABLED")
  else
    if renoise.tool().app_idle_observable:has_notifier(match_editstep_with_delay_pattern) then
      renoise.tool().app_idle_observable:remove_notifier(match_editstep_with_delay_pattern)
    end
    renoise.app():show_status("Match EditStep with Delay Pattern: DISABLED")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Match EditStep with Delay Pattern",invoke=function() toggle_match_editstep() end}

---
local function pakettiFloodFillColumn(use_editstep)
  local song = renoise.song()
  local track = song.selected_track
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local line_index = song.selected_line_index
  local lines = pattern.tracks[song.selected_track_index].lines

  local cursor_pos = song.transport.edit_pos
  local sel_effect_col = song.selected_effect_column_index
  local sel_note_col = song.selected_note_column_index
  
  -- Get the step size if we're using editstep
  local step_size = 1
  if use_editstep then
    step_size = song.transport.edit_step
    -- If editstep is 0, treat it as regular mode (step_size = 1)
    if step_size == 0 then
      step_size = 1
      use_editstep = false
    end
  end

  -- Check if we are in an effect column
  if sel_effect_col ~= 0 then
    -- Get the effect value in the current row
    local current_effect = lines[line_index].effect_columns[sel_effect_col]
    if current_effect.is_empty then
      renoise.app():show_status("No effect to flood fill from the current row.")
      return
    end
    
    -- Clear non-empty effect columns (starting after current row)
    for i = line_index + 1, pattern.number_of_lines do
      if not lines[i].effect_columns[sel_effect_col].is_empty then
        lines[i].effect_columns[sel_effect_col]:clear()
      end
    end
    
    -- Then apply the flood fill
    for i = line_index + step_size, #lines, step_size do
      lines[i].effect_columns[sel_effect_col]:copy_from(current_effect)
    end

  elseif sel_note_col ~= 0 then
    -- Get note column properties (note, instrument, etc.)
    local current_note_col = lines[line_index].note_columns[sel_note_col]
    if current_note_col.is_empty then
      renoise.app():show_status("No note to flood fill from the current row.")
      return
    end
    
    -- Clear non-empty note columns (starting after current row)
    for i = line_index + 1, pattern.number_of_lines do
      if not lines[i].note_columns[sel_note_col].is_empty then
        lines[i].note_columns[sel_note_col]:clear()
      end
    end
    
    -- Then apply the flood fill
    for i = line_index + step_size, #lines, step_size do
      lines[i].note_columns[sel_note_col]:copy_from(current_note_col)
    end

  else
    renoise.app():show_status("Neither an effect nor note column selected.")
    return
  end

  -- Return focus to the pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  local msg = use_editstep and "Flood fill completed (EditStep)" or "Flood fill completed"
  renoise.app():show_status(msg)
end

renoise.tool():add_keybinding{name = "Global:Paketti:Flood Fill Column with Row",invoke = function() pakettiFloodFillColumn(false) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Flood Fill Column with Row by EditStep",invoke = function() pakettiFloodFillColumn(true) end}

-----

-- Flexible CapsLock Pattern Generator
-- Places OFF notes at specified intervals from current position
function PakettiCapsLockPattern(intervals, block_size, start_offset, edit_step)
  local s = renoise.song()
  local currLine = s.selected_line_index
  local currPatt = s.selected_pattern_index
  local currTrak = s.selected_track_index
  local pattern_lines = s.patterns[currPatt].number_of_lines
  
  -- Default parameters if not provided
  intervals = intervals or {0, 3, 5, 8}  -- Default intervals from original function
  block_size = block_size or 8           -- How far to advance between blocks
  start_offset = start_offset or 2       -- Starting offset from current line
  edit_step = edit_step or 3             -- Edit step to set after completion
  
  -- Safety check
  if s.selected_note_column_index == nil or s.selected_note_column_index == 0 then
    renoise.app():show_status("Please select a note column first.")
    return
  end
  
  local current_block_start = currLine + start_offset
  local blocks_created = 0
  
  -- Continue until we reach the end of the pattern
  while current_block_start <= pattern_lines do
    -- Place OFF notes at each interval within this block
    for _, interval in ipairs(intervals) do
      local target_line = current_block_start + interval
      
      -- Check bounds
      if target_line > 0 and target_line <= pattern_lines then
        s.patterns[currPatt].tracks[currTrak].lines[target_line].note_columns[s.selected_note_column_index].note_string = "OFF"
        s.patterns[currPatt].tracks[currTrak].lines[target_line].note_columns[s.selected_note_column_index].instrument_value = 255  -- Clear instrument column
      end
    end
    
    -- Move to next block
    current_block_start = current_block_start + block_size
    blocks_created = blocks_created + 1
  end
  
  -- Set appropriate edit step
  renoise.song().transport.edit_step = edit_step
  
  renoise.app():show_status(string.format("Placed OFF pattern: %d blocks, EditStep set to %d", blocks_created, edit_step))
end

-- Preset functions for common patterns
function PakettiCapsLockPatternDefault()
  PakettiCapsLockPattern({0, 3, 5, 8}, 8, 2, 3)  -- Original: intervals, block_size, start_offset, edit_step
end

function PakettiCapsLockPatternTight()
  PakettiCapsLockPattern({0, 1, 2, 3}, 4, 1, 1)  -- Tighter pattern, edit_step = 1
end

function PakettiCapsLockPatternWide()
  PakettiCapsLockPattern({0, 4, 8, 12}, 16, 2, 4)  -- Wider spacing, edit_step = 4
end

function PakettiCapsLockPatternCustom()
  -- Uses current edit step as basis for pattern, then increments edit step by 1
  local current_edit_step = renoise.song().transport.edit_step
  local new_edit_step = current_edit_step + 1
  PakettiCapsLockPattern({0, current_edit_step, current_edit_step * 2, current_edit_step * 3}, current_edit_step * 4, current_edit_step, new_edit_step)
end

renoise.tool():add_keybinding{name="Global:Paketti:CapsLockChassis (Default)", invoke=function() PakettiCapsLockPatternDefault() end}
renoise.tool():add_keybinding{name="Global:Paketti:CapsLockChassis (Tight)", invoke=function() PakettiCapsLockPatternTight() end}
renoise.tool():add_keybinding{name="Global:Paketti:CapsLockChassis (Wide)", invoke=function() PakettiCapsLockPatternWide() end}
renoise.tool():add_keybinding{name="Global:Paketti:CapsLockChassis (Custom)", invoke=function() PakettiCapsLockPatternCustom() end}

-- Legacy keybinding for compatibility
renoise.tool():add_keybinding{name="Global:Paketti:CapsLockChassis", invoke=function() PakettiCapsLockPatternDefault() end}

-- Note Off Paste - copies NOTE OFFs and delay values within pattern selection
function noteOffPaste()
  local s = renoise.song()
  local selection = s.selection_in_pattern
  
  -- Check if there's a valid pattern selection
  if not selection then
    renoise.app():show_status("No pattern selection found.")
    return
  end
  
  local start_line = selection.start_line
  local end_line = selection.end_line
  local start_track = selection.start_track
  local end_track = selection.end_track
  local start_column = selection.start_column
  local end_column = selection.end_column
  
  -- Safety check
  if start_line > end_line or start_track > end_track then
    renoise.app():show_status("Invalid selection range.")
    return
  end
  
  local pattern = s.selected_pattern
  local selected_track_index = s.selected_track_index
  
  -- Make sure we're not trying to copy to the same track
  if selected_track_index >= start_track and selected_track_index <= end_track then
    renoise.app():show_status("Cannot paste to the same track that's in the selection.")
    return
  end
  
  local source_track = pattern.tracks[start_track]  -- Use first track in selection as source
  local target_track = pattern.tracks[selected_track_index]
  
  -- Get the actual track objects for visible_note_columns
  local source_track_obj = s.tracks[start_track]
  local target_track_obj = s.tracks[selected_track_index]
  
  local notes_copied = 0
  
  -- Iterate through the selected line range
  for line_index = start_line, end_line do
    local source_line = source_track.lines[line_index]
    local target_line = target_track.lines[line_index]
    
    -- Process each note column in the selection
    for col = start_column, math.min(end_column, source_track_obj.visible_note_columns) do
      if col <= target_track_obj.visible_note_columns then
        local source_note_col = source_line.note_columns[col]
        local target_note_col = target_line.note_columns[col]
        
        -- Copy NOTE OFF
        if source_note_col.note_string == "OFF" then
          target_note_col.note_string = "OFF"
          target_note_col.instrument_value = 255  -- Clear instrument column
          notes_copied = notes_copied + 1
        end
        
        -- Copy delay value (always copy, even if 0)
        if source_note_col.delay_value ~= target_note_col.delay_value then
          target_note_col.delay_value = source_note_col.delay_value
          -- Make delay column visible if we're copying delay values
          if source_note_col.delay_value > 0 then
            target_track_obj.delay_column_visible = true
          end
        end
      end
    end
  end
  
  renoise.app():show_status(string.format("Copied %d NOTE OFFs and delay values to track %d", notes_copied, selected_track_index))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note-Off Paste (from Selection)", invoke=function() noteOffPaste() end}



------
function duplicate_selection_pro()
  local song=renoise.song()
  local pattern_index=song.selected_pattern_index
  local selection=song.selection_in_pattern
  local selection_info=selection_in_pattern_pro()

  if not selection or not selection_info then
    renoise.app():show_status("No selection in pattern to duplicate.")
    return
  end

  local range_length=selection.end_line-selection.start_line+1
  local total_lines=#song.patterns[pattern_index].tracks[1].lines
  local lines_left=total_lines-selection.end_line
  local effective_length=math.min(range_length,lines_left)

  if effective_length<=0 then
    renoise.app():show_status("Not enough space in pattern to duplicate.")
    return
  end

  for _,track_data in ipairs(selection_info) do
    local pattern_track=song:pattern(pattern_index):track(track_data.track_index)

    for i=0,effective_length-1 do
      local src_line_idx=selection.start_line+i
      local tgt_line_idx=selection.end_line+1+i
      local src_line=pattern_track:line(src_line_idx)
      local tgt_line=pattern_track:line(tgt_line_idx)

      if track_data.track_type==renoise.Track.TRACK_TYPE_SEQUENCER then
        for _,col in ipairs(track_data.note_columns) do
          tgt_line:note_column(col):copy_from(src_line:note_column(col))
        end
      end

      for _,fx_col in ipairs(track_data.effect_columns) do
        tgt_line:effect_column(fx_col):copy_from(src_line:effect_column(fx_col))
      end
    end
  end

  local new_start_line=selection.end_line+1
  local new_end_line=new_start_line+effective_length-1

  song.selection_in_pattern={
    start_line=new_start_line,
    end_line=new_end_line,
    start_track=selection.start_track,
    end_track=selection.end_track,
    start_column=selection.start_column,
    end_column=selection.end_column
  }

  local pos=song.transport.edit_pos
  pos.line=new_start_line
  song.transport.edit_pos=pos

  if effective_length<range_length then
    renoise.app():show_status("Duplicated "..effective_length.." of "..range_length.." rows (pattern limit).")
  else
    renoise.app():show_status("Selection duplicated in pattern.")
  end
end

renoise.tool():add_keybinding {name="Global:Paketti:Duplicate Selection in Pattern",invoke=function()duplicate_selection_pro()end}
renoise.tool():add_midi_mapping{name="Paketti:Duplicate Selection in Pattern x[Trigger]",invoke=function(message) if message:is_trigger() then duplicate_selection_pro() end end}






renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Increase Pattern Length by 8",invoke=function() adjust_length_by(8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Decrease Pattern Length by 8",invoke=function() adjust_length_by(-8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Increase Pattern Length by LPB",invoke=function() adjust_length_by("lpb") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Decrease Pattern Length by LPB",invoke=function() adjust_length_by("-lpb") end}

--------------------------------------------------------------------------------
-- Audition Current Line on Pattern Row Change Toggle (V6.2+ only)
--------------------------------------------------------------------------------
if renoise.API_VERSION >= 6.2 then
  -- Global state for the audition feature
  PakettiAuditionOnLineChangeEnabled = false
  local last_audition_pos = nil
  
  -- Save/restore state variables
  local saved_playback_pos = nil
  local saved_playing = false
  local saved_follow_player = nil
  local saved_edit_mode = nil
  
  -- Table to track triggered notes: {track_index, instrument_index, note_value, note_column}
  local triggered_notes = {}

  -- Timer function that monitors cursor position changes
  local function audition_idle_notifier()
    -- Check if audition is enabled
    if not PakettiAuditionOnLineChangeEnabled then
      return
    end
    
    -- Safe song access with error handling
    local song
    local success, error_msg = pcall(function()
      song = renoise.song()
    end)
    
    if not success or not song or not song.selected_track then
      return
    end
    
    -- Only audition if we're in pattern editor
    if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      return
    end
    
    -- Get current cursor position
    local pos = song.transport.edit_pos
    local track_index = song.selected_track_index
    local line_index = pos.line
    local note_column_index = song.selected_note_column_index
    
    -- Create position hash for comparison
    local current_pos = track_index .. ":" .. line_index .. ":" .. note_column_index
    
    -- Check if cursor moved to a new position
    if current_pos ~= last_audition_pos then
      last_audition_pos = current_pos
      
      -- Only trigger if playback is stopped (API requirement)
      if not song.transport.playing then
        -- Send Note OFF to previously triggered notes before triggering new ones
        for _, note_info in ipairs(triggered_notes) do
          local track = song:track(note_info.track_index)
          if track and note_info.instrument_index <= #song.instruments then
            local instrument = song:instrument(note_info.instrument_index)
            instrument:trigger_note_off(note_info.track_index, note_info.note_value, note_info.note_column)
          end
        end
        
        -- Clear the triggered notes table
        triggered_notes = {}
        
        -- Get the current line to see what notes will be triggered
        local pattern = song:pattern(song.selected_pattern_index)
        local track = pattern:track(track_index)
        local line = track:line(line_index)
        
        -- Store the notes that are about to be triggered
        for col_index = 1, #line.note_columns do
          local note_col = line.note_columns[col_index]
          if not note_col.is_empty and note_col.note_value < 120 then
            local instr_index = note_col.instrument_value + 1
            if instr_index <= #song.instruments then
              table.insert(triggered_notes, {
                track_index = track_index,
                instrument_index = instr_index,
                note_value = note_col.note_value,
                note_column = col_index
              })
            end
          end
        end
        
        -- Now trigger the line
        song:trigger_pattern_line(line_index)
      end
    end
  end

  -- Function to toggle the audition feature on/off
  function PakettiToggleAuditionCurrentLineOnRowChange()
    if PakettiAuditionOnLineChangeEnabled then
      -- Turn OFF: Restore everything
      PakettiAuditionOnLineChangeEnabled = false
      preferences.pakettiAuditionOnLineChangeEnabled.value = false
      
      -- Remove timer
      if renoise.tool():has_timer(audition_idle_notifier) then
        renoise.tool():remove_timer(audition_idle_notifier)
      end
      
      local song = renoise.song()
      
      -- Send Note OFF to all tracked notes
      for _, note_info in ipairs(triggered_notes) do
        local track = song:track(note_info.track_index)
        if track and note_info.instrument_index <= #song.instruments then
          local instrument = song:instrument(note_info.instrument_index)
          instrument:trigger_note_off(note_info.track_index, note_info.note_value, note_info.note_column)
        end
      end
      
      -- Clear the triggered notes table
      triggered_notes = {}
      
      -- Restore edit mode
      if saved_edit_mode ~= nil then
        song.transport.edit_mode = saved_edit_mode
        saved_edit_mode = nil
      end
      
      -- Restore follow player
      if saved_follow_player ~= nil then
        song.transport.follow_player = saved_follow_player
        saved_follow_player = nil
      end
      
      -- Resume playback from saved position if it was playing
      if saved_playing and saved_playback_pos then
        song.transport:start_at(saved_playback_pos)
      end
      
      -- Show appropriate status message based on whether playback was restored
      local status_msg = saved_playing and "Audition Mode: OFF (Playback Restored)" or "Audition Mode: OFF"
      
      -- Clear saved state
      saved_playback_pos = nil
      saved_playing = false
      last_audition_pos = nil
      
      renoise.app():show_status(status_msg)
    else
      -- Turn ON: Save state and stop playback
      PakettiAuditionOnLineChangeEnabled = true
      preferences.pakettiAuditionOnLineChangeEnabled.value = true
      
      local song = renoise.song()
      local transport = song.transport
      
      -- Save current state
      saved_playback_pos = transport.playback_pos
      saved_playing = transport.playing
      saved_follow_player = transport.follow_player
      saved_edit_mode = transport.edit_mode
      
      -- Stop playback and set up for audition
      if saved_playing then
        transport:stop()
      end
      transport.edit_mode = true
      transport.follow_player = false
      
      -- Add timer for monitoring cursor position
      if not renoise.tool():has_timer(audition_idle_notifier) then
        renoise.tool():add_timer(audition_idle_notifier, 50)
      end
      
      -- Reset cursor tracking
      last_audition_pos = nil
      
      local status_msg = saved_playing and "Audition Mode: ON (Playback Paused)" or "Audition Mode: ON"
      renoise.app():show_status(status_msg)
    end
  end

  -- Add keybinding for the toggle
  renoise.tool():add_keybinding{
    name="Global:Paketti:Toggle Audition Current Line on Pattern Row Change",
    invoke=function() PakettiToggleAuditionCurrentLineOnRowChange() end
  }

  -- Add menu entry
  renoise.tool():add_menu_entry{
    name="Pattern Editor:Paketti:Toggle Audition Current Line on Pattern Row Change",
    invoke=function() PakettiToggleAuditionCurrentLineOnRowChange() end,
    selected=function() return PakettiAuditionOnLineChangeEnabled end
  }

  -- Add MIDI mapping for the toggle
  renoise.tool():add_midi_mapping{
    name="Paketti:Toggle Audition Current Line on Pattern Row Change x[Toggle]",
    invoke=function(message) 
      if message:is_trigger() then 
        PakettiToggleAuditionCurrentLineOnRowChange() 
      end 
    end
  }
end
-- If API < 6.2, don't create any menu entries, keybindings, or MIDI mappings at all


---
-- Function to write notes in specified order (ascending, descending, or random)
function writeNotesMethod(method)
  local song=renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local instrument = song.selected_instrument
  local current_line = song.selected_line_index
  local selected_note_column = song.selected_note_column_index
  
  if not instrument or not instrument.sample_mappings[1] then
    renoise.app():show_status("No sample mappings found for this instrument")
    return
  end
  
  -- Check if first sample has slice markers
  local first_sample_has_slices = false
  local slice_start_note = nil
  local slice_count = 0
  
  if #instrument.samples > 0 then
    local first_sample = instrument:sample(1)
    if first_sample and #first_sample.slice_markers > 0 then
      first_sample_has_slices = true
      slice_count = #first_sample.slice_markers
      
      -- Get the slice start note - slices are the SECOND mapping onwards
      local sample_mappings = instrument.sample_mappings[1] -- Note layer
      if sample_mappings and #sample_mappings >= 2 then
        -- Get the first slice mapping (slices start at index 2)
        local first_slice_mapping = sample_mappings[2]
        if first_slice_mapping and first_slice_mapping.base_note then
          slice_start_note = first_slice_mapping.base_note
        end
      end
      
      -- Fallback: slices typically start one note above the original sample's base note
      if not slice_start_note and first_sample.sample_mapping and first_sample.sample_mapping.base_note then
        slice_start_note = first_sample.sample_mapping.base_note + 1
      end
    end
  end
  
  -- Create a table of all mapped notes
  local notes = {}
  
  if first_sample_has_slices and slice_start_note then
    -- If slice markers exist, only create notes for slices
    for i = 0, slice_count - 1 do
      local slice_note = slice_start_note + i
      -- Ensure we don't exceed valid note range (0-119)
      if slice_note <= 119 then
        table.insert(notes, {
          note = slice_note,
          mapping = instrument.samples[1].sample_mapping
        })
      else
        break -- Stop adding notes if we exceed the valid range
      end
    end
  else
    -- If no slice markers, process all sample mappings
    for _, mapping in ipairs(instrument.sample_mappings[1]) do
      if mapping.note_range then
        for i = mapping.note_range[1], mapping.note_range[2] do
          table.insert(notes, {
            note = i,
            mapping = mapping
          })
        end
      end
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No valid sample mappings found for this instrument")
    return
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    table.sort(notes, function(a, b) return a.note < b.note end)
  elseif method == "descending" then
    table.sort(notes, function(a, b) return a.note > b.note end)
  elseif method == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  end
  
  local last_note = -1
  local last_mapping = nil
  
  -- Write the notes
  for i = 1, #notes do
    if current_line <= pattern.number_of_lines then
      local note_column = track:line(current_line):note_column(selected_note_column)
      note_column.note_value = notes[i].note
      note_column.instrument_value = song.selected_instrument_index - 1
      current_line = current_line + 1
      last_note = notes[i].note
      last_mapping = notes[i].mapping
    else
      break
    end
  end
  
  if last_note ~= -1 and last_mapping then
    local note_name = note_value_to_string(last_note)
    renoise.app():show_status(string.format(
      "Wrote notes until row %d at note %s (base note: %d)", 
      current_line - 1, 
      note_name,
      last_mapping.base_note
    ))
  end
end

-- Function to write notes in specified order with EditStep (ascending, descending, or random)
function writeNotesMethodEditStep(method)
  local song=renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local instrument = song.selected_instrument
  local current_line = song.selected_line_index
  local selected_note_column = song.selected_note_column_index
  local edit_step = song.transport.edit_step
  
  -- If edit_step is 0, treat it as 1 (write to every row)
  if edit_step == 0 then
    edit_step = 1
  end
  
  if not instrument or not instrument.sample_mappings[1] then
    renoise.app():show_status("No sample mappings found for this instrument")
    return
  end
  
  -- Check if first sample has slice markers
  local first_sample_has_slices = false
  local slice_start_note = nil
  local slice_count = 0
  
  if #instrument.samples > 0 then
    local first_sample = instrument:sample(1)
    if first_sample and #first_sample.slice_markers > 0 then
      first_sample_has_slices = true
      slice_count = #first_sample.slice_markers
      
      -- Get the slice start note - slices are the SECOND mapping onwards
      local sample_mappings = instrument.sample_mappings[1] -- Note layer
      if sample_mappings and #sample_mappings >= 2 then
        -- Get the first slice mapping (slices start at index 2)
        local first_slice_mapping = sample_mappings[2]
        if first_slice_mapping and first_slice_mapping.base_note then
          slice_start_note = first_slice_mapping.base_note
        end
      end
      
      -- Fallback: slices typically start one note above the original sample's base note
      if not slice_start_note and first_sample.sample_mapping and first_sample.sample_mapping.base_note then
        slice_start_note = first_sample.sample_mapping.base_note + 1
      end
    end
  end
  
  -- Create a table of all mapped notes
  local notes = {}
  
  if first_sample_has_slices and slice_start_note then
    -- If slice markers exist, only create notes for slices
    for i = 0, slice_count - 1 do
      local slice_note = slice_start_note + i
      -- Ensure we don't exceed valid note range (0-119)
      if slice_note <= 119 then
        table.insert(notes, {
          note = slice_note,
          mapping = instrument.samples[1].sample_mapping
        })
      else
        break -- Stop adding notes if we exceed the valid range
      end
    end
  else
    -- If no slice markers, process all sample mappings
    for _, mapping in ipairs(instrument.sample_mappings[1]) do
      if mapping.note_range then
        for i = mapping.note_range[1], mapping.note_range[2] do
          table.insert(notes, {
            note = i,
            mapping = mapping
          })
        end
      end
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No valid sample mappings found for this instrument")
    return
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    table.sort(notes, function(a, b) return a.note < b.note end)
  elseif method == "descending" then
    table.sort(notes, function(a, b) return a.note > b.note end)
  elseif method == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  end
  
  -- First, clear all existing notes in the selected note column from current line to end of pattern
  for line_index = current_line, pattern.number_of_lines do
    local note_column = track:line(line_index):note_column(selected_note_column)
    note_column.note_value = renoise.PatternLine.EMPTY_NOTE
    note_column.instrument_value = renoise.PatternLine.EMPTY_INSTRUMENT
    note_column.volume_value = renoise.PatternLine.EMPTY_VOLUME
    note_column.panning_value = renoise.PatternLine.EMPTY_PANNING
    note_column.delay_value = renoise.PatternLine.EMPTY_DELAY
    note_column.effect_number_value = renoise.PatternLine.EMPTY_EFFECT_NUMBER
    note_column.effect_amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
  end
  
  local last_note = -1
  local last_mapping = nil
  local write_line = current_line
  
  -- Write the notes using EditStep
  for i = 1, #notes do
    if write_line <= pattern.number_of_lines then
      local note_column = track:line(write_line):note_column(selected_note_column)
      -- Write the new note
      note_column.note_value = notes[i].note
      note_column.instrument_value = song.selected_instrument_index - 1
      write_line = write_line + edit_step
      last_note = notes[i].note
      last_mapping = notes[i].mapping
    else
      break
    end
  end
  
  if last_note ~= -1 and last_mapping then
    local note_name = note_value_to_string(last_note)
    renoise.app():show_status(string.format(
      "Cleared and wrote notes with EditStep %d until row %d at note %s (base note: %d)", 
      edit_step,
      write_line - edit_step, 
      note_name,
      last_mapping.base_note
    ))
  end
end

-- Helper function to convert note value to string
function note_value_to_string(value)
  local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local octave = math.floor(value / 12)
  local note = notes[(value % 12) + 1]
  return note .. octave
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes Ascending",invoke=function() writeNotesMethod("ascending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes Descending",invoke=function() writeNotesMethod("descending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes Random",invoke=function() writeNotesMethod("random") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes EditStep Ascending",invoke=function() writeNotesMethodEditStep("ascending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes EditStep Descending",invoke=function() writeNotesMethodEditStep("descending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes EditStep Random",invoke=function() writeNotesMethodEditStep("random") end}

---
-- Fit Sample Offset to Pattern
-- Calculates sample length and spreads 0Sxx commands from 0S00 to 0SFE across pattern length
-- This makes the sample play from beginning to end across the entire pattern
-- Parameters:
--   headless: if true, automatically clears track without prompting user
function PakettiFitSampleOffsetToPattern(headless)
  headless = headless or false  -- Default to interactive mode
  
  local song = renoise.song()
  
  -- Check if there's a selected sample
  if not song.selected_sample or not song.selected_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or sample has no data")
    print("ERROR: No sample selected or sample has no data")
    return
  end
  
  -- Check if there's a selected track
  if not song.selected_track then
    renoise.app():show_status("No track selected")
    print("ERROR: No track selected")
    return
  end
  
  local sample = song.selected_sample
  local sample_frames = sample.sample_buffer.number_of_frames
  local sample_rate = sample.sample_buffer.sample_rate
  local sample_duration = sample_frames / sample_rate
  
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  local track_index = song.selected_track_index
  local pattern_track = pattern:track(track_index)
  local pattern_length = pattern.number_of_lines
  
  local mode_text = headless and " (Headless)" or ""
  print(string.format("=== Fit Sample Offset to Pattern%s ===", mode_text))
  print(string.format("Sample: '%s'", sample.name or "Unnamed"))
  print(string.format("Sample length: %d frames (%.2f seconds at %.1fkHz)", sample_frames, sample_duration, sample_rate/1000))
  print(string.format("Pattern: %d (length: %d rows)", pattern_index, pattern_length))
  print(string.format("Track: %d ('%s')", track_index, song.selected_track.name or "Unnamed"))
  
  -- CRITICAL: Check for existing note to hijack BEFORE any clearing operations!
  local current_line = song.selected_line
  local hijack_note_value = nil
  local hijack_instrument_value = nil
  local hijack_note_string = "C-4"  -- Default fallback
  
  -- Look for existing note in current row BEFORE clearing
  for col = 1, song.selected_track.visible_note_columns do
    local note_column = current_line.note_columns[col]
    if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
       note_column.note_string ~= "OFF" and 
       note_column.note_value < 120 then
      hijack_note_value = note_column.note_value
      hijack_note_string = note_column.note_string
      -- Use existing instrument if present, otherwise use selected instrument
      if note_column.instrument_value ~= renoise.PatternLine.EMPTY_INSTRUMENT then
        hijack_instrument_value = note_column.instrument_value
      else
        hijack_instrument_value = song.selected_instrument_index - 1
      end
      print(string.format("HIJACK: Found existing note %s (value %d) with instrument %02X on current row", 
        hijack_note_string, hijack_note_value, hijack_instrument_value))
      break
    end
  end
  
  -- Fallback to C-4 if no note found
  if not hijack_note_value then
    hijack_note_value = 48  -- C-4
    hijack_instrument_value = song.selected_instrument_index - 1
    print("HIJACK: No existing note found, using default C-4")
  end
  
  local should_clear = false
  
  if headless then
    -- Headless mode: automatically clear track
    should_clear = true
    print("Headless mode: automatically clearing track data...")
  else
    -- Interactive mode: ask user
    -- Use the already-detected hijack note for the prompt
    local prompt_note = hijack_note_string
    if hijack_note_value == 48 and hijack_note_string == "C-4" then
      prompt_note = "C-4 (default)"
    else
      prompt_note = hijack_note_string .. " (hijacked from current row)"
    end
    
    local clear_track = renoise.app():show_prompt("Fit Sample Offset to Pattern", 
      string.format("This will write 0Sxx commands from 0S00 to 0SFE across %d rows.\n\nSample: %s (%d frames, %.2fs)\nNote: %s\n\nClear existing track data first?", 
        pattern_length, sample.name or "Unnamed", sample_frames, sample_duration, prompt_note),
      {"Clear & Write", "Overwrite Only", "Cancel"})
    
    if clear_track == "Cancel" then
      renoise.app():show_status("Operation cancelled")
      return
    end
    
    should_clear = (clear_track == "Clear & Write")
  end
  
  -- Clear track if requested/required
  if should_clear then
    print("Clearing existing track data...")
    for row = 1, pattern_length do
      local line = pattern_track:line(row)
      line:clear()
    end
  end

  
  -- Use even distribution formula: (row - 1) × (255 ÷ pattern_length)
  local sxx_max = 0xFF -- Maximum possible Sxx value (255 in decimal)
  
  print(string.format("Writing 0Sxx commands across %d rows using hijacked note %s...", pattern_length, hijack_note_string))
  
  -- Write 0Sxx commands across the pattern
  for row = 1, pattern_length do
    -- Calculate which Sxx value for this row
    -- Use formula: (row - 1) × (255 ÷ pattern_length) for even distribution
    local sxx_value = math.floor((row - 1) * (255 / pattern_length))
    sxx_value = math.max(0, math.min(sxx_value, 254)) -- Cap at SFE (254)
    
    -- Format as hex string for the S command
    local sxx_string = string.format("%02X", sxx_value)
    
    -- Write to the pattern
    local line = pattern_track:line(row)
    
    -- Set the 0S command in effect column 1
    line.effect_columns[1].number_string = "0S"
    line.effect_columns[1].amount_string = sxx_string
    
    -- Trigger the hijacked note to play the sample
    line.note_columns[1].note_value = hijack_note_value
    line.note_columns[1].instrument_value = hijack_instrument_value
    
    -- Debug output for first few and last few rows
    if row <= 5 or row > pattern_length - 5 then
      print(string.format("Row %03d: %s + 0S%s (%.1f%% through sample)", row, hijack_note_string, sxx_string, (row - 1) / (pattern_length - 1) * 100))
    elseif row == 6 then
      print("... (middle rows) ...")
    end
  end
  
  -- Show completion message
  local success_msg = string.format("Fit Sample Offset completed: %s + 0S00-0S%02X across %d rows", hijack_note_string, sxx_max - 1, pattern_length)
  renoise.app():show_status(success_msg)
  print(success_msg)
  print(string.format("Sample will play from start to just before end across pattern length using hijacked note %s", hijack_note_string))
  print("=====================================")
end

renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Fit Sample Offset to Pattern (0Sxx)",invoke = function() PakettiFitSampleOffsetToPattern(false) end}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Fit Sample Offset to Pattern (0Sxx Headless)",invoke = function() PakettiFitSampleOffsetToPattern(true) end}

renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Fit Sample Offset to Pattern (0Sxx)",invoke = function() PakettiFitSampleOffsetToPattern(false) end}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Fit Sample Offset to Pattern (0Sxx Headless)",invoke = function() PakettiFitSampleOffsetToPattern(true) end}

---
-- Match Effect Column to Current Row (Forward Only)
-- If current row has Y30, all other Yxx commands from current row to end of pattern become Y30

function PakettiMatchEffectColumnToCurrentRowForward()
  local song = renoise.song()
  local track_index = song.selected_track_index
  local track = song:track(track_index)
  
  -- Check if we're in a sequencer track
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("This function only works on sequencer tracks")
    return
  end
  
  -- Determine which effect column to use
  local target_effect_column_index = song.selected_effect_column_index
  local current_effect_column = nil
  
  -- If no effect column is selected, use the first one
  if not target_effect_column_index or target_effect_column_index == 0 then
    target_effect_column_index = 1
  end
  
  -- Get the effect column from current line
  current_effect_column = song.selected_line:effect_column(target_effect_column_index)
  
  if not current_effect_column or current_effect_column.is_empty then
    renoise.app():show_status(string.format("No effect in column %d of current row", target_effect_column_index))
    return
  end
  
  local target_command = current_effect_column.number_string
  local target_value = current_effect_column.amount_value
  
  if target_command == "00" then
    renoise.app():show_status("Current effect column is empty")
    return
  end
  
  local matches_found = 0
  
  -- Only work in current pattern, from current line to end
  local current_pattern = song:pattern(song.selected_pattern_index)
  local pattern_track = current_pattern:track(track_index)
  local current_line_index = song.selected_line_index
  local lines = current_pattern.number_of_lines
  
  -- Check each line from current line to end of pattern
  for line_index = current_line_index + 1, lines do
    local line = pattern_track:line(line_index)
    
    -- Only check the specific effect column index that was selected
    if target_effect_column_index <= track.visible_effect_columns then
      local effect_column = line:effect_column(target_effect_column_index)
      
      if effect_column and not effect_column.is_empty then
        -- If this effect column has the same command but different value
        if effect_column.number_string == target_command and 
           effect_column.amount_value ~= target_value then
          
          -- Change it to match the target value
          effect_column.amount_value = target_value
          matches_found = matches_found + 1
        end
      end
    end
  end
  
  if matches_found > 0 then
    renoise.app():show_status(string.format("Matched %d instances of %s to %s%02X in effect column %d (forward only)", 
      matches_found, target_command, target_command, target_value, target_effect_column_index))
  else
    renoise.app():show_status(string.format("No other instances of %s found in effect column %d (forward only)", target_command, target_effect_column_index))
  end
  
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Match Effect Column to Current Row (All Rows)
-- If current row has Y30, all other Yxx commands in current pattern become Y30

function PakettiMatchEffectColumnToCurrentRowAll()
  local song = renoise.song()
  local track_index = song.selected_track_index
  local track = song:track(track_index)
  
  -- Check if we're in a sequencer track
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("This function only works on sequencer tracks")
    return
  end
  
  -- Determine which effect column to use
  local target_effect_column_index = song.selected_effect_column_index
  local current_effect_column = nil
  
  -- If no effect column is selected, use the first one
  if not target_effect_column_index or target_effect_column_index == 0 then
    target_effect_column_index = 1
  end
  
  -- Get the effect column from current line
  current_effect_column = song.selected_line:effect_column(target_effect_column_index)
  
  if not current_effect_column or current_effect_column.is_empty then
    renoise.app():show_status(string.format("No effect in column %d of current row", target_effect_column_index))
    return
  end
  
  local target_command = current_effect_column.number_string
  local target_value = current_effect_column.amount_value
  
  if target_command == "00" then
    renoise.app():show_status("Current effect column is empty")
    return
  end
  
  local matches_found = 0
  
  -- Only work in current pattern, all rows
  local current_pattern = song:pattern(song.selected_pattern_index)
  local pattern_track = current_pattern:track(track_index)
  local lines = current_pattern.number_of_lines
  
  -- Check each line in the current pattern (all rows)
  for line_index = 1, lines do
    local line = pattern_track:line(line_index)
    
    -- Only check the specific effect column index that was selected
    if target_effect_column_index <= track.visible_effect_columns then
      local effect_column = line:effect_column(target_effect_column_index)
      
      if effect_column and not effect_column.is_empty then
        -- If this effect column has the same command but different value
        if effect_column.number_string == target_command and 
           effect_column.amount_value ~= target_value then
          
          -- Change it to match the target value
          effect_column.amount_value = target_value
          matches_found = matches_found + 1
        end
      end
    end
  end
  
  if matches_found > 0 then
    renoise.app():show_status(string.format("Matched %d instances of %s to %s%02X in effect column %d (all rows)", 
      matches_found, target_command, target_command, target_value, target_effect_column_index))
  else
    renoise.app():show_status(string.format("No other instances of %s found in effect column %d (all rows)", target_command, target_effect_column_index))
  end
  
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name = "Global:Paketti:Match Effect Column to Current Row (Forward)",invoke = PakettiMatchEffectColumnToCurrentRowForward}
renoise.tool():add_keybinding{name = "Global:Paketti:Match Effect Column to Current Row (All Rows)",invoke = PakettiMatchEffectColumnToCurrentRowAll}
renoise.tool():add_midi_mapping{name = "Paketti:Match Effect Column to Current Row (Forward)",invoke = PakettiMatchEffectColumnToCurrentRowForward}
renoise.tool():add_midi_mapping{name = "Paketti:Match Effect Column to Current Row (All Rows)",invoke = PakettiMatchEffectColumnToCurrentRowAll}

---------

function GenerateDelayValue(scope)
  local s = renoise.song()
  local track = s.tracks[s.selected_track_index]
  track.delay_column_visible = true
  
  local num_columns = track.visible_note_columns
  local base_delay = 256 / num_columns
  
  -- Get target lines based on scope
  local lines = {}
  if scope == "row" then
      table.insert(lines, s.selected_line_index)
  elseif scope == "pattern" then
      for i = 1, s.selected_pattern.number_of_lines do
          table.insert(lines, i)
      end
  elseif scope == "selection" then
      local selection = s.selection_in_pattern
      if not selection then
          renoise.app():show_status("No selection found!")
          return
      end
      for i = selection.start_line, selection.end_line do
          table.insert(lines, i)
      end
  end
  
  -- Apply to all target lines
  for _, line_index in ipairs(lines) do
      for i = 1, num_columns do
          local delay_value = math.floor(base_delay * (i - 1))
          s.patterns[s.selected_pattern_index].tracks[s.selected_track_index]
              .lines[line_index].note_columns[i].delay_value = delay_value
      end
  end
  
  s.selected_note_column_index = 1
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Note Columns",invoke=function() GenerateDelayValue("row") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Entire Pattern",invoke=function() GenerateDelayValue("pattern") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Selection",invoke=function() GenerateDelayValue("selection") end}
-- Function to get selected columns in the current selection
local function get_selected_columns(track, start_line, end_line)
  local selected_note_columns = {}
  local selected_effect_columns = {}

  for column_index = 1, #track:line(start_line).note_columns do
    for line = start_line, end_line do
      if track:line(line).note_columns[column_index].is_selected then
        table.insert(selected_note_columns, column_index)
        break
      end
    end
  end

  return selected_note_columns, selected_effect_columns
end

function GenerateDelayValueNotes(scope)
  local s = renoise.song()
  local track = s.tracks[s.selected_track_index]
  track.delay_column_visible = true
  
  local lines = {}
  if scope == "row" then
      table.insert(lines, s.selected_line_index)
  elseif scope == "pattern" then
      for i = 1, s.selected_pattern.number_of_lines do
          table.insert(lines, i)
      end
  elseif scope == "selection" then
      local selection = s.selection_in_pattern
      if not selection then
          renoise.app():show_status("No selection found!")
          return
      end
      for i = selection.start_line, selection.end_line do
          table.insert(lines, i)
      end
  end
  
  for _, line_index in ipairs(lines) do
      local line = s.patterns[s.selected_pattern_index].tracks[s.selected_track_index]:line(line_index)
      
      local actual_notes = 0
      for i = 1, track.visible_note_columns do
          local note_column = line.note_columns[i]
          if note_column and note_column.note_string ~= "" and 
             note_column.note_string ~= "OFF" and note_column.note_value < 120 then
              actual_notes = actual_notes + 1
          end
      end
      
      if actual_notes > 1 then
          local current_note = 0
          for i = 1, track.visible_note_columns do
              local note_column = line.note_columns[i]
              if note_column and note_column.note_string ~= "" and 
                 note_column.note_string ~= "OFF" and note_column.note_value < 120 then
                  local delay = math.floor(256 * current_note / actual_notes)
                  note_column.delay_value = delay
                  current_note = current_note + 1
              end
          end
      end
  end
end


-- Add new keybindings for note-specific version
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Row)",invoke=function() GenerateDelayValueNotes("row") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Pattern)",invoke=function() GenerateDelayValueNotes("pattern") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Selection)",invoke=function() GenerateDelayValueNotes("selection") end}

-- Tempo Interpolation Feature
-- Function to extract BPM from a pattern by looking for ZT effect commands
function PakettiTempoExtractBPMFromPattern(pattern_index)
  local song = renoise.song()
  local pattern = song.patterns[pattern_index]
  local master_track_index = get_master_track_index()
  
  if not master_track_index then
    return nil
  end
  
  local master_track = pattern.tracks[master_track_index]
  
  -- Look through all lines in the pattern for ZT effect commands
  for line_index = 1, pattern.number_of_lines do
    local line = master_track:line(line_index)
    for col_index = 1, #line.effect_columns do
      local effect_col = line.effect_columns[col_index]
      if effect_col.number_string == "ZT" and effect_col.amount_value > 0 then
        return effect_col.amount_value
      end
    end
  end
  
  -- No ZT effect found, return nil
  return nil
end

-- Main tempo interpolation function
function PakettiTempoInterpolateCurrentToNext()
  local song = renoise.song()
  local current_seq_index = song.selected_sequence_index
  local sequencer = song.sequencer
  local pattern_sequence = sequencer.pattern_sequence
  
  -- Check if there is a next pattern in the sequence
  if current_seq_index >= #pattern_sequence then
    renoise.app():show_status("No next pattern in sequence to interpolate to")
    return
  end
  
  -- Get current pattern index
  local current_pattern_index = pattern_sequence[current_seq_index]
  
  -- Search BACKWARDS through sequence to find source BPM (most recent pattern with ZT command)
  local source_bpm = nil
  local source_seq_index = nil
  for seq_idx = current_seq_index, 1, -1 do
    local pattern_idx = pattern_sequence[seq_idx]
    local bpm = PakettiTempoExtractBPMFromPattern(pattern_idx)
    if bpm then
      source_bpm = bpm
      source_seq_index = seq_idx
      break
    end
  end
  
  -- Fallback to transport BPM if no previous ZT effect found
  if not source_bpm then
    source_bpm = math.floor(song.transport.bpm)
    renoise.app():show_status("No previous BPM found in sequence, using transport BPM: " .. source_bpm)
  end
  
  -- Search FORWARDS through sequence to find target BPM (next pattern with ZT command)
  local target_bpm = nil
  local target_seq_index = nil
  for seq_idx = current_seq_index + 1, #pattern_sequence do
    local pattern_idx = pattern_sequence[seq_idx]
    local bpm = PakettiTempoExtractBPMFromPattern(pattern_idx)
    if bpm then
      target_bpm = bpm
      target_seq_index = seq_idx
      break
    end
  end
  
  -- Error if no target BPM found
  if not target_bpm then
    renoise.app():show_status("No BPM (ZT command) found in any following pattern in the sequence")
    return
  end
  
  -- Use source_bpm as current_bpm and target_bpm as next_bpm for the rest of the function
  local current_bpm = source_bpm
  local next_bpm = target_bpm
  
  -- Check if interpolation is needed
  local optimal_bpm = (current_bpm < next_bpm) and (next_bpm - 1) or (next_bpm + 1)
  if current_bpm == optimal_bpm then
    renoise.app():show_status("Current pattern already at optimal BPM (" .. current_bpm .. ") for smooth transition, no interpolation needed")
    return
  end
  
  -- Check BPM range limits for ZT command
  if current_bpm > 255 or next_bpm > 255 then
    renoise.app():show_status("Cannot interpolate: BPM over 255 (ZTFF) - ZT command maximum exceeded")
    return
  end
  
  if current_bpm < 20 or next_bpm < 20 then
    renoise.app():show_status("Cannot interpolate: BPM under 20 (ZT14) - ZT command minimum exceeded")
    return
  end
  
  -- Check if target_end_bpm would be out of valid range
  local target_end_bpm_check = (current_bpm < next_bpm) and (next_bpm - 1) or (next_bpm + 1)
  if target_end_bpm_check > 255 then
    renoise.app():show_status("Cannot interpolate: Target end BPM would be over 255 (ZTFF) - adjust next pattern BPM")
    return
  elseif target_end_bpm_check < 20 then
    renoise.app():show_status("Cannot interpolate: Target end BPM would be under 20 (ZT14) - adjust next pattern BPM")
    return
  end
  
  -- Get current pattern and its length
  local current_pattern = song.patterns[current_pattern_index]
  local pattern_length = current_pattern.number_of_lines
  local master_track_index = get_master_track_index()
  
  if not master_track_index then
    renoise.app():show_status("Could not find master track")
    return
  end
  
  -- Ensure master track has enough effect columns visible
  song.tracks[master_track_index].visible_effect_columns = math.max(song.tracks[master_track_index].visible_effect_columns, 1)
  
  -- Calculate BPM difference and step
  -- For smooth transition, we stop 1 BPM away from next pattern's starting BPM
  local target_end_bpm
  if current_bpm < next_bpm then
    -- Raising BPM: stop 1 BPM below next pattern's BPM
    target_end_bpm = next_bpm - 1
  else
    -- Lowering BPM: stop 1 BPM above next pattern's BPM  
    target_end_bpm = next_bpm + 1
  end
  local bpm_diff = target_end_bpm - current_bpm
  local master_track = current_pattern.tracks[master_track_index]
  
  -- Write interpolated BPM values throughout the pattern
  local bpm_changes_written = 0
  local bpm_range = math.abs(bpm_diff)
  
  -- Calculate how many lines per BPM change to ensure smooth progression
  local lines_per_bpm_change = 1
  if bpm_range > 0 then
    lines_per_bpm_change = math.max(1, math.floor(pattern_length / bpm_range))
  end
  
  local last_written_bpm = current_bpm
  
  for line_index = 1, pattern_length do
    -- Calculate exact interpolated BPM for this line
    local progress = (line_index - 1) / (pattern_length - 1)
    local exact_interpolated_bpm = current_bpm + (bpm_diff * progress)
    
    -- Round to nearest integer for smooth progression
    local target_bpm = math.floor(exact_interpolated_bpm + 0.5)
    
    -- Clamp BPM to valid ZT range (20-255)
    target_bpm = math.max(20, math.min(255, target_bpm))
    
    -- Write BPM change if we've hit a new BPM value or it's the first line
    if target_bpm ~= last_written_bpm or line_index == 1 then
      -- Find effect column for tempo interpolation
      local line = master_track:line(line_index)
      local effect_col = nil
      
      -- First, look for existing ZT commands to overwrite
      for col_index = 1, #line.effect_columns do
        if line.effect_columns[col_index].number_string == "ZT" then
          effect_col = line.effect_columns[col_index]
          break
        end
      end
      
      -- If no existing ZT command, look for empty column
      if not effect_col then
        for col_index = 1, #line.effect_columns do
          if line.effect_columns[col_index].number_string == "00" or line.effect_columns[col_index].number_string == "" then
            effect_col = line.effect_columns[col_index]
            break
          end
        end
      end
      
      -- If still no column found, use the first column (overwrite whatever is there)
      if not effect_col then
        effect_col = line.effect_columns[1]
      end
      
      -- Write the ZT command with interpolated BPM
      effect_col.number_string = "ZT"
      effect_col.amount_value = target_bpm
      bpm_changes_written = bpm_changes_written + 1
      last_written_bpm = target_bpm
    end
  end
  
  -- Update the transport BPM to the starting BPM
  song.transport.bpm = current_bpm
  
  renoise.app():show_status(string.format("Tempo interpolation complete: %d BPM → %d BPM (%d changes written)", 
    current_bpm, target_end_bpm, bpm_changes_written))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write BPM (Interpolated) to Master Track", invoke=PakettiTempoInterpolateCurrentToNext}
renoise.tool():add_keybinding{name="Global:Paketti:Write BPM (Interpolated) to Master Track", invoke=PakettiTempoInterpolateCurrentToNext}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Write BPM (Interpolated) to Master Track", invoke=PakettiTempoInterpolateCurrentToNext}


-------
-- Note Cut Effect Toggle Shortcut Function
function PakettiPatternEditorNoteCut()
  local s = renoise.song()
  local a = renoise.app()
  
  -- Ensure at least one effect column is visible
  sliderVisibleEffect()
  
  if s.selection_in_pattern then
    -- Apply to selection
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible
        
        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
        
        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = s:pattern(s.selected_pattern_index):track(t):line(i):effect_column(column_index)
              if effect_column then
                -- Toggle: if already 0C00, clear it; otherwise set it
                if effect_column.number_string == "0C" and effect_column.amount_string == "00" then
                  effect_column:clear()
                else
                  effect_column.number_string = "0C"
                  effect_column.amount_string = "00"
                end
              end
            end
          end
        end
      end
    end
  else
    -- Apply to current line
    if s.selected_effect_column_index > 0 then
      -- Effect column is selected
      local effect_column = s.selected_effect_column
      if effect_column then
        -- Toggle: if already 0C00, clear it; otherwise set it
        if effect_column.number_string == "0C" and effect_column.amount_string == "00" then
          effect_column:clear()
          a:show_status("Note Cut (0C00) removed from effect column")
        else
          effect_column.number_string = "0C"
          effect_column.amount_string = "00"
          a:show_status("Note Cut (0C00) applied to effect column")
        end
      end
    else
      -- Note column is selected or no specific column, use first effect column
      local line = s.selected_line
      if line then
        local effect_column = line:effect_column(1)
        if effect_column then
          -- Toggle: if already 0C00, clear it; otherwise set it
          if effect_column.number_string == "0C" and effect_column.amount_string == "00" then
            effect_column:clear()
            a:show_status("Note Cut (0C00) removed from effect column")
          else
            effect_column.number_string = "0C"
            effect_column.amount_string = "00"
            a:show_status("Note Cut (0C00) applied to effect column")
          end
        end
      end
    end
  end
  
  a.window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Pattern Editor Note Cut Toggle (0C00)", invoke=PakettiPatternEditorNoteCut}


-- Note Cut All Tracks Toggle Function - toggles C00 on all sequencer tracks for current row
function PakettiPatternEditorNoteCutAllTracks()
  local s = renoise.song()
  local a = renoise.app()
  local current_line = s.selected_line_index
  local sequencer_track_count = s.sequencer_track_count
  local applied_count = 0
  local removed_count = 0
  
  for track_index = 1, sequencer_track_count do
    local track = s:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Ensure at least one effect column is visible
      if track.visible_effect_columns == 0 then
        track.visible_effect_columns = 1
      end
      
      -- Toggle C00 on first effect column of current line
      local effect_column = s:pattern(s.selected_pattern_index):track(track_index):line(current_line):effect_column(1)
      if effect_column then
        -- Toggle: if already 0C00, clear it; otherwise set it
        if effect_column.number_string == "0C" and effect_column.amount_string == "00" then
          effect_column:clear()
          removed_count = removed_count + 1
        else
          effect_column.number_string = "0C"
          effect_column.amount_string = "00"
          applied_count = applied_count + 1
        end
      end
    end
  end
  
  if applied_count > 0 then
    a:show_status("Note Cut (0C00) applied to " .. applied_count .. " sequencer tracks on line " .. current_line)
  else
    a:show_status("Note Cut (0C00) removed from " .. removed_count .. " sequencer tracks on line " .. current_line)
  end
  a.window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Note Cut Master Track Toggle Function - toggles C00 on master track for current row  
function PakettiPatternEditorNoteCutMaster()
  local s = renoise.song()
  local a = renoise.app()
  local current_line = s.selected_line_index
  local master_track_index = s.sequencer_track_count + 1
  local master_track = s:track(master_track_index)
  
  -- Ensure at least one effect column is visible on master
  if master_track.visible_effect_columns == 0 then
    master_track.visible_effect_columns = 1
  end
  
  -- Toggle C00 on first effect column of master track on current line
  local effect_column = s:pattern(s.selected_pattern_index):track(master_track_index):line(current_line):effect_column(1)
  if effect_column then
    -- Toggle: if already 0C00, clear it; otherwise set it
    if effect_column.number_string == "0C" and effect_column.amount_string == "00" then
      effect_column:clear()
      a:show_status("Note Cut (0C00) removed from Master track on line " .. current_line)
    else
      effect_column.number_string = "0C"
      effect_column.amount_string = "00"
      a:show_status("Note Cut (0C00) applied to Master track on line " .. current_line)
    end
  end
  
  a.window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Note Cut All Tracks Toggle (0C00)", invoke=PakettiPatternEditorNoteCutAllTracks}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Cut All Tracks Toggle (0C00)", invoke=PakettiPatternEditorNoteCutAllTracks}


renoise.tool():add_keybinding{name="Global:Paketti:Note Cut Master Toggle (0C00)", invoke=PakettiPatternEditorNoteCutMaster}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Cut Master Toggle (0C00)", invoke=PakettiPatternEditorNoteCutMaster}

-- Pick & Move Feature - Global state variables
PakettiPickAndMoveActive = false
PakettiPickAndMoveStoredContent = nil
PakettiPickAndMoveOriginalLine = 0
PakettiPickAndMoveTrackIndex = 0

-- Function to copy all content from a track line (note columns and effect columns)
function PakettiPickAndMoveCopyLineContent(pattern_track, track, line_index)
  local line = pattern_track:line(line_index)
  local content = {}
  
  -- Copy only note columns that have content
  content.note_columns = {}
  local note_col_count = 0
  for i = 1, track.max_note_columns do
    local note_col = line.note_columns[i]
    if note_col.note_value ~= 121 or 
       note_col.instrument_value ~= 255 or 
       note_col.volume_value ~= 255 or 
       note_col.panning_value ~= 255 or 
       note_col.delay_value ~= 0 then
      note_col_count = i
    end
    -- Always copy up to the highest column with content
    if i <= note_col_count then
      content.note_columns[i] = {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value
      }
    end
  end
  
  -- Copy only effect columns that have content
  content.effect_columns = {}
  local effect_col_count = 0
  for i = 1, track.max_effect_columns do
    local effect_col = line.effect_columns[i]
    if effect_col.number_value ~= 0 or effect_col.amount_value ~= 0 then
      effect_col_count = i
    end
    -- Always copy up to the highest column with content
    if i <= effect_col_count then
      content.effect_columns[i] = {
        number_value = effect_col.number_value,
        amount_value = effect_col.amount_value
      }
    end
  end
  
  return content
end

-- Function to paste content to a track line
function PakettiPickAndMovePasteLineContent(pattern_track, track, line_index, content)
  local line = pattern_track:line(line_index)
  
  -- Set visible columns to exactly what's needed for note columns
  if content.note_columns and #content.note_columns > 0 then
    local required_note_cols = #content.note_columns
    if required_note_cols > track.visible_note_columns then
      track.visible_note_columns = math.min(required_note_cols, track.max_note_columns)
    end
  end
  
  -- Set visible columns to exactly what's needed for effect columns
  if content.effect_columns and #content.effect_columns > 0 then
    local required_effect_cols = #content.effect_columns
    if required_effect_cols > track.visible_effect_columns then
      track.visible_effect_columns = math.min(required_effect_cols, track.max_effect_columns)
    end
  end
  
  -- Paste note columns
  if content.note_columns then
    for i = 1, #content.note_columns do
      if content.note_columns[i] and i <= track.max_note_columns then
        local note_col = line.note_columns[i]
        local stored_col = content.note_columns[i]
        note_col.note_value = stored_col.note_value
        note_col.instrument_value = stored_col.instrument_value
        note_col.volume_value = stored_col.volume_value
        note_col.panning_value = stored_col.panning_value
        note_col.delay_value = stored_col.delay_value
      end
    end
  end
  
  -- Paste effect columns
  if content.effect_columns then
    for i = 1, #content.effect_columns do
      if content.effect_columns[i] and i <= track.max_effect_columns then
        local effect_col = line.effect_columns[i]
        local stored_col = content.effect_columns[i]
        effect_col.number_value = stored_col.number_value
        effect_col.amount_value = stored_col.amount_value
      end
    end
  end
end

-- Function to clear all content from a track line
function PakettiPickAndMoveClearLineContent(pattern_track, track, line_index)
  local line = pattern_track:line(line_index)
  
  -- Clear all note columns that might have content
  for i = 1, track.max_note_columns do
    local note_col = line.note_columns[i]
    note_col.note_value = 121 -- empty
    note_col.instrument_value = 255 -- empty
    note_col.volume_value = 255 -- empty
    note_col.panning_value = 255 -- empty
    note_col.delay_value = 0
  end
  
  -- Clear all effect columns that might have content
  for i = 1, track.max_effect_columns do
    local effect_col = line.effect_columns[i]
    effect_col.number_value = 0
    effect_col.amount_value = 0
  end
end

-- Function to check if a line has any content
function PakettiPickAndMoveLineHasContent(pattern_track, track, line_index)
  local line = pattern_track:line(line_index)
  
  -- Check note columns for any content
  for i = 1, track.max_note_columns do
    local note_col = line.note_columns[i]
    if note_col.note_value ~= 121 or -- not empty
       note_col.instrument_value ~= 255 or -- not empty
       note_col.volume_value ~= 255 or -- not empty
       note_col.panning_value ~= 255 or -- not empty
       note_col.delay_value ~= 0 then
      return true
    end
  end
  
  -- Check effect columns for any content
  for i = 1, track.max_effect_columns do
    local effect_col = line.effect_columns[i]
    if effect_col.number_value ~= 0 or effect_col.amount_value ~= 0 then
      return true
    end
  end
  
  return false
end

-- Function to enable Pick & Move mode and pick up current line content
function PakettiPickAndMoveEnable()
  local s = renoise.song()
  local pattern_track = s.selected_pattern_track
  local track = s.selected_track
  local line_index = s.transport.edit_pos.line
  
  -- Check if current line has content
  if not PakettiPickAndMoveLineHasContent(pattern_track, track, line_index) then
    renoise.app():show_status("Pick & Move: No content on current line to pick up")
    return
  end
  
  -- Store the content and position
  PakettiPickAndMoveStoredContent = PakettiPickAndMoveCopyLineContent(pattern_track, track, line_index)
  PakettiPickAndMoveOriginalLine = line_index
  PakettiPickAndMoveTrackIndex = s.selected_track_index
  PakettiPickAndMoveActive = true
  
  -- Clear the original line
  PakettiPickAndMoveClearLineContent(pattern_track, track, line_index)
  
  renoise.app():show_status("Pick & Move: Content picked up from line " .. line_index .. " - use cursor keys to move")
end

-- Function to disable Pick & Move mode
function PakettiPickAndMoveDisable()
  if PakettiPickAndMoveActive and PakettiPickAndMoveStoredContent then
    local s = renoise.song()
    -- Always paste content at current position when disabling
    local pattern_track = s.selected_pattern_track
    local track = s.selected_track
    local current_line = s.transport.edit_pos.line
    PakettiPickAndMovePasteLineContent(pattern_track, track, current_line, PakettiPickAndMoveStoredContent)
  end
  
  PakettiPickAndMoveActive = false
  PakettiPickAndMoveStoredContent = nil
  PakettiPickAndMoveOriginalLine = 0
  PakettiPickAndMoveTrackIndex = 0
  renoise.app():show_status("Pick & Move: Disabled")
end

-- Function to toggle Pick & Move mode
function PakettiPickAndMoveToggle()
  if PakettiPickAndMoveActive then
    PakettiPickAndMoveDisable()
  else
    PakettiPickAndMoveEnable()
  end
end

-- Function to handle cursor movement in Pick & Move mode
function PakettiPickAndMoveCursorMove(direction)
  if not PakettiPickAndMoveActive or not PakettiPickAndMoveStoredContent then
    return false -- Let normal cursor movement handle it
  end
  
  local s = renoise.song()
  local current_line = s.transport.edit_pos.line
  local pattern = s.selected_pattern
  local new_line = current_line
  
  -- Calculate new position
  if direction == "up" then
    new_line = math.max(1, current_line - 1)
  elseif direction == "down" then
    new_line = math.min(pattern.number_of_lines, current_line + 1)
  end
  
  -- Only move if position actually changed
  if new_line ~= current_line then
    -- Move cursor first
    s.transport.edit_pos = {sequence = s.transport.edit_pos.sequence, line = new_line}
    
    -- Always paste the content at the new position
    local pattern_track = s.selected_pattern_track
    local track = s.selected_track
    PakettiPickAndMovePasteLineContent(pattern_track, track, new_line, PakettiPickAndMoveStoredContent)
  end
  
  return true -- We handled the movement
end

-- Cursor Up handler for Pick & Move
function PakettiPickAndMoveCursorUp()
  if PakettiPickAndMoveCursorMove("up") then
    return -- We handled it
  end
  -- If Pick & Move didn't handle it, do normal cursor movement - move up one line
  local s = renoise.song()
  local current_line = s.transport.edit_pos.line
  if current_line > 1 then
    s.transport.edit_pos = {sequence = s.transport.edit_pos.sequence, line = current_line - 1}
  end
end

-- Cursor Down handler for Pick & Move  
function PakettiPickAndMoveCursorDown()
  if PakettiPickAndMoveCursorMove("down") then
    return -- We handled it
  end
  -- If Pick & Move didn't handle it, do normal cursor movement - move down one line
  local s = renoise.song()
  local current_line = s.transport.edit_pos.line
  local pattern = s.selected_pattern
  if current_line < pattern.number_of_lines then
    s.transport.edit_pos = {sequence = s.transport.edit_pos.sequence, line = current_line + 1}
  end
end


renoise.tool():add_keybinding{name="Global:Paketti:Pick & Move Toggle", invoke=PakettiPickAndMoveToggle}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pick & Move Toggle", invoke=PakettiPickAndMoveToggle}

-- Override cursor keys for Pick & Move functionality
renoise.tool():add_keybinding{name="Pattern Editor:Navigation:Move Cursor Up [Override]", invoke=PakettiPickAndMoveCursorUp}
renoise.tool():add_keybinding{name="Pattern Editor:Navigation:Move Cursor Down [Override]", invoke=PakettiPickAndMoveCursorDown}

--------------------------------------------------------------------------------
-- Nudge and Move Selection
--------------------------------------------------------------------------------

-- Helper function to check if a line has any data in the specified columns
function PakettiNudgeAndMoveCheckLineForData(pattern, track_index, line_index, note_columns, effect_columns)
  local track = pattern:track(track_index)
  local line = track:line(line_index)
  
  -- Check selected note columns
  for _, col_idx in ipairs(note_columns) do
    local note_col = line:note_column(col_idx)
    if not note_col.is_empty then
      return true
    end
  end
  
  -- Check selected effect columns
  for _, col_idx in ipairs(effect_columns) do
    local effect_col = line:effect_column(col_idx)
    if not effect_col.is_empty then
      return true
    end
  end
  
  return false
end

-- Main function to perform nudge and move selection
function PakettiNudgeAndMoveSelection(direction)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("No selection in pattern, doing nothing.")
    return
  end
  
  -- Get selection details using selection_in_pattern_pro
  local selection_info = selection_in_pattern_pro()
  if not selection_info then
    renoise.app():show_status("Please select a range before running this function.")
    return
  end
  
  local pattern = song.selected_pattern
  local start_line = selection.start_line
  local end_line = selection.end_line
  local num_lines = end_line - start_line + 1
  
  -- Calculate new selection range
  local new_start_line = start_line + direction
  local new_end_line = end_line + direction
  
  -- Check bounds
  if new_start_line < 1 then
    renoise.app():show_status("Cannot move beyond beginning of pattern, doing nothing.")
    return
  end
  
  if new_end_line > pattern.number_of_lines then
    renoise.app():show_status("Cannot move beyond end of pattern, doing nothing.")
    return
  end
  
  -- Check for data collision in the destination area
  -- We only need to check the NEW line that wasn't part of the selection before
  local check_line = nil
  if direction < 0 then
    -- Moving up: check line above current selection
    check_line = new_start_line
  else
    -- Moving down: check line below current selection
    check_line = new_end_line
  end
  
  -- Check for collisions in the destination line
  for _, track_info in ipairs(selection_info) do
    if PakettiNudgeAndMoveCheckLineForData(
      pattern, 
      track_info.track_index, 
      check_line,
      track_info.note_columns,
      track_info.effect_columns
    ) then
      renoise.app():show_status("This nudge and move would result in a data collision, doing nothing.")
      return
    end
  end
  
  -- All checks passed, perform the move
  -- We need to copy in the right order to avoid overwriting data
  if direction < 0 then
    -- Moving up: copy from top to bottom
    for line_offset = 0, num_lines - 1 do
      local src_line = start_line + line_offset
      local dst_line = new_start_line + line_offset
      
      for _, track_info in ipairs(selection_info) do
        local track = pattern:track(track_info.track_index)
        local src = track:line(src_line)
        local dst = track:line(dst_line)
        
        -- Copy selected note columns
        for _, col_idx in ipairs(track_info.note_columns) do
          dst:note_column(col_idx):copy_from(src:note_column(col_idx))
        end
        
        -- Copy selected effect columns
        for _, col_idx in ipairs(track_info.effect_columns) do
          dst:effect_column(col_idx):copy_from(src:effect_column(col_idx))
        end
      end
    end
    
    -- Clear the old line at the bottom that's no longer part of selection
    for _, track_info in ipairs(selection_info) do
      local track = pattern:track(track_info.track_index)
      local clear_line = track:line(end_line)
      
      for _, col_idx in ipairs(track_info.note_columns) do
        clear_line:note_column(col_idx):clear()
      end
      
      for _, col_idx in ipairs(track_info.effect_columns) do
        clear_line:effect_column(col_idx):clear()
      end
    end
  else
    -- Moving down: copy from bottom to top
    for line_offset = num_lines - 1, 0, -1 do
      local src_line = start_line + line_offset
      local dst_line = new_start_line + line_offset
      
      for _, track_info in ipairs(selection_info) do
        local track = pattern:track(track_info.track_index)
        local src = track:line(src_line)
        local dst = track:line(dst_line)
        
        -- Copy selected note columns
        for _, col_idx in ipairs(track_info.note_columns) do
          dst:note_column(col_idx):copy_from(src:note_column(col_idx))
        end
        
        -- Copy selected effect columns
        for _, col_idx in ipairs(track_info.effect_columns) do
          dst:effect_column(col_idx):copy_from(src:effect_column(col_idx))
        end
      end
    end
    
    -- Clear the old line at the top that's no longer part of selection
    for _, track_info in ipairs(selection_info) do
      local track = pattern:track(track_info.track_index)
      local clear_line = track:line(start_line)
      
      for _, col_idx in ipairs(track_info.note_columns) do
        clear_line:note_column(col_idx):clear()
      end
      
      for _, col_idx in ipairs(track_info.effect_columns) do
        clear_line:effect_column(col_idx):clear()
      end
    end
  end
  
  -- Update the selection to the new range
  song.selection_in_pattern = {
    start_track = selection.start_track,
    start_line = new_start_line,
    start_column = selection.start_column,
    end_track = selection.end_track,
    end_line = new_end_line,
    end_column = selection.end_column
  }
  
  -- Move cursor to maintain relative position within selection
  local cursor_line = song.selected_line_index
  if cursor_line >= start_line and cursor_line <= end_line then
    song.selected_line_index = cursor_line + direction
  end
  
  renoise.app():show_status(string.format("Nudged and moved selection %s", direction < 0 and "up" or "down"))
end

-- Wrapper functions for up/down
function PakettiNudgeAndMoveSelectionUp()
  PakettiNudgeAndMoveSelection(-1)
end

function PakettiNudgeAndMoveSelectionDown()
  PakettiNudgeAndMoveSelection(1)
end

-- Add keybindings
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge and Move Selection Up", invoke=PakettiNudgeAndMoveSelectionUp}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge and Move Selection Down", invoke=PakettiNudgeAndMoveSelectionDown}

-- Add MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:Nudge and Move Selection Up", invoke=function(message) if message:is_trigger() then PakettiNudgeAndMoveSelectionUp() end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge and Move Selection Down", invoke=function(message) if message:is_trigger() then PakettiNudgeAndMoveSelectionDown() end end}

------------------------------------------------------------------------
-- Pattern Effect Column Curve Fill
-- Fill effect column values (Volume, Panning, Delay) using curve shapes
------------------------------------------------------------------------

PakettiEffectColumnCurveFillDialog = nil
PakettiEffectColumnCurveFillVb = nil

function PakettiEffectColumnCurveFill()
    local song = renoise.song()
    local pattern = song.selected_pattern
    local track_index = song.selected_track_index
    local track = song.selected_track
    
    -- Check track type
    if track.type == renoise.Track.TRACK_TYPE_MASTER or 
       track.type == renoise.Track.TRACK_TYPE_SEND then
        renoise.app():show_status("Cannot fill effect columns on Master or Send tracks")
        return
    end
    
    -- Close existing dialog if open
    if PakettiEffectColumnCurveFillDialog and PakettiEffectColumnCurveFillDialog.visible then
        PakettiEffectColumnCurveFillDialog:close()
    end
    
    local vb = renoise.ViewBuilder()
    PakettiEffectColumnCurveFillVb = vb
    
    local num_lines = pattern.number_of_lines
    local current_line = song.selected_line_index
    
    local content = vb:column{
        margin = 10,
        spacing = 6,
        
        vb:row{
            vb:text{text = "Pattern Lines:", width = 80},
            vb:text{text = tostring(num_lines)}
        },
        
        vb:row{
            vb:text{text = "Column:", width = 80},
            vb:popup{
                id = "column_type",
                items = {
                    "Volume (00-80)",
                    "Panning (00-80)",
                    "Delay (00-FF)"
                },
                value = 1,
                width = 150
            }
        },
        
        vb:row{
            vb:text{text = "From Line:", width = 80},
            vb:valuebox{
                id = "from_line",
                min = 1,
                max = num_lines,
                value = 1,
                width = 60
            },
            vb:text{text = "Value:", width = 50},
            vb:valuebox{
                id = "from_value",
                min = 0,
                max = 255,
                value = 0,
                width = 60,
                tostring = function(v) return string.format("%02X", v) end,
                tonumber = function(s) return tonumber(s, 16) or 0 end
            }
        },
        
        vb:row{
            vb:text{text = "To Line:", width = 80},
            vb:valuebox{
                id = "to_line",
                min = 1,
                max = num_lines,
                value = num_lines,
                width = 60
            },
            vb:text{text = "Value:", width = 50},
            vb:valuebox{
                id = "to_value",
                min = 0,
                max = 255,
                value = 128,
                width = 60,
                tostring = function(v) return string.format("%02X", v) end,
                tonumber = function(s) return tonumber(s, 16) or 0 end
            }
        },
        
        vb:row{
            vb:text{text = "Curve Type:", width = 80},
            vb:popup{
                id = "curve_type",
                items = {
                    "Linear (even)",
                    "Logarithmic (fast start)",
                    "Exponential (slow start)",
                    "Down Parabola (U-shape)",
                    "Up Parabola (inverted U)",
                    "Double Peak",
                    "Double Valley"
                },
                value = 1,
                width = 180
            }
        },
        
        vb:row{
            vb:text{text = "Step:", width = 80},
            vb:valuebox{
                id = "step_size",
                min = 1,
                max = 64,
                value = 1,
                width = 60
            },
            vb:text{text = "(write every N lines)"}
        },
        
        vb:row{
            vb:checkbox{
                id = "all_note_columns",
                value = false
            },
            vb:text{text = "Apply to all visible note columns"}
        },
        
        vb:row{
            spacing = 10,
            vb:button{
                text = "Apply",
                width = 80,
                notifier = function()
                    PakettiEffectColumnCurveFillApply()
                end
            },
            vb:button{
                text = "Preview",
                width = 80,
                notifier = function()
                    PakettiEffectColumnCurveFillPreview()
                end
            },
            vb:button{
                text = "Close",
                width = 80,
                notifier = function()
                    if PakettiEffectColumnCurveFillDialog and PakettiEffectColumnCurveFillDialog.visible then
                        PakettiEffectColumnCurveFillDialog:close()
                    end
                end
            }
        },
        
        vb:text{
            id = "preview_text",
            text = "",
            font = "mono"
        }
    }
    
    -- Update max values based on column type
    vb.views.column_type:add_notifier(function()
        local col_type = vb.views.column_type.value
        if col_type == 1 or col_type == 2 then
            -- Volume or Panning: max 0x80 (128)
            vb.views.from_value.max = 128
            vb.views.to_value.max = 128
            if vb.views.from_value.value > 128 then vb.views.from_value.value = 128 end
            if vb.views.to_value.value > 128 then vb.views.to_value.value = 128 end
        else
            -- Delay: max 0xFF (255)
            vb.views.from_value.max = 255
            vb.views.to_value.max = 255
        end
    end)
    
    PakettiEffectColumnCurveFillDialog = renoise.app():show_custom_dialog(
        "Effect Column Curve Fill",
        content,
        my_keyhandler_func
    )
    
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiEffectColumnCurveFillGetCurveType(popup_index)
    local curve_map = {
        [1] = "linear",
        [2] = "logarithmic",
        [3] = "exponential",
        [4] = "downParabola",
        [5] = "upParabola",
        [6] = "doublePeak",
        [7] = "doubleValley"
    }
    return curve_map[popup_index] or "linear"
end

function PakettiEffectColumnCurveFillPreview()
    local vb = PakettiEffectColumnCurveFillVb
    if not vb then return end
    
    local from_line = vb.views.from_line.value
    local to_line = vb.views.to_line.value
    local from_value = vb.views.from_value.value
    local to_value = vb.views.to_value.value
    local curve_type = PakettiEffectColumnCurveFillGetCurveType(vb.views.curve_type.value)
    local step_size = vb.views.step_size.value
    
    -- Ensure from_line <= to_line
    if from_line > to_line then
        from_line, to_line = to_line, from_line
        from_value, to_value = to_value, from_value
    end
    
    -- Calculate number of values needed
    local line_count = math.floor((to_line - from_line) / step_size) + 1
    
    -- Generate values using the curve
    local values = PakettiGenerateCurve(from_value, to_value, line_count, curve_type, false)
    
    -- Build preview text
    local preview_lines = {}
    table.insert(preview_lines, string.format("Preview (%s, step %d):", curve_type, step_size))
    
    local show_count = math.min(8, line_count)
    for i = 1, show_count do
        local line_num = from_line + (i - 1) * step_size
        table.insert(preview_lines, string.format("  Line %03d: %02X", line_num, values[i]))
    end
    
    if line_count > 8 then
        table.insert(preview_lines, "  ...")
        local last_line = from_line + (line_count - 1) * step_size
        table.insert(preview_lines, string.format("  Line %03d: %02X", last_line, values[line_count]))
    end
    
    vb.views.preview_text.text = table.concat(preview_lines, "\n")
end

function PakettiEffectColumnCurveFillApply()
    local vb = PakettiEffectColumnCurveFillVb
    if not vb then return end
    
    local song = renoise.song()
    local pattern = song.selected_pattern
    local track_index = song.selected_track_index
    local pattern_track = pattern:track(track_index)
    local track = song.selected_track
    
    local from_line = vb.views.from_line.value
    local to_line = vb.views.to_line.value
    local from_value = vb.views.from_value.value
    local to_value = vb.views.to_value.value
    local column_type = vb.views.column_type.value
    local curve_type = PakettiEffectColumnCurveFillGetCurveType(vb.views.curve_type.value)
    local step_size = vb.views.step_size.value
    local all_columns = vb.views.all_note_columns.value
    
    -- Ensure from_line <= to_line
    if from_line > to_line then
        from_line, to_line = to_line, from_line
        from_value, to_value = to_value, from_value
    end
    
    -- Calculate number of values needed
    local line_count = math.floor((to_line - from_line) / step_size) + 1
    
    -- Generate values using the curve
    local values = PakettiGenerateCurve(from_value, to_value, line_count, curve_type, true)
    
    print("PakettiEffectColumnCurveFill: Applying " .. curve_type .. " curve")
    print("  Column type: " .. column_type .. " (" .. (column_type == 1 and "Volume" or column_type == 2 and "Panning" or "Delay") .. ")")
    print("  Lines " .. from_line .. " to " .. to_line .. ", step " .. step_size)
    print("  Values " .. string.format("%02X", from_value) .. " to " .. string.format("%02X", to_value))
    
    -- Determine which columns to apply to
    local columns_to_fill = {}
    if all_columns then
        for col = 1, track.visible_note_columns do
            table.insert(columns_to_fill, col)
        end
    else
        table.insert(columns_to_fill, song.selected_note_column_index)
    end
    
    -- Apply values
    local values_written = 0
    for i, value in ipairs(values) do
        local line_num = from_line + (i - 1) * step_size
        if line_num <= to_line and line_num <= pattern.number_of_lines then
            local line = pattern_track:line(line_num)
            
            for _, col_idx in ipairs(columns_to_fill) do
                local note_column = line:note_column(col_idx)
                
                if column_type == 1 then
                    -- Volume (clamp to 0x80)
                    note_column.volume_value = math.min(128, value)
                elseif column_type == 2 then
                    -- Panning (clamp to 0x80)
                    note_column.panning_value = math.min(128, value)
                else
                    -- Delay (0x00-0xFF)
                    note_column.delay_value = math.min(255, value)
                end
                
                values_written = values_written + 1
            end
        end
    end
    
    local column_name = column_type == 1 and "Volume" or column_type == 2 and "Panning" or "Delay"
    renoise.app():show_status(string.format("Applied %s curve to %s column (%d values written)", 
        curve_type, column_name, values_written))
    
    -- Close dialog
    if PakettiEffectColumnCurveFillDialog and PakettiEffectColumnCurveFillDialog.visible then
        PakettiEffectColumnCurveFillDialog:close()
    end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Effect Column Curve Fill", invoke = PakettiEffectColumnCurveFill}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Effect Column Curve Fill", invoke = PakettiEffectColumnCurveFill}
renoise.tool():add_midi_mapping{name="Paketti:Effect Column Curve Fill", invoke = function(message) if message:is_trigger() then PakettiEffectColumnCurveFill() end end}

---------------------------------------------------------------------------
-- Cursor Advance Forward/Backward by Steps
-- These allow jumping forward or backward by a specific number of steps
-- in a looping pattern situation, without changing EditStep.
---------------------------------------------------------------------------

function PakettiAdvanceCursorForward(steps)
  local song = renoise.song()
  local pattern_lines = song.selected_pattern.number_of_lines
  local current_line = song.selected_line_index
  local new_line = current_line + steps
  local wrapped = song.transport.wrapped_pattern_edit

  if new_line > pattern_lines then
    if not wrapped then
      -- Wrap around within the same pattern
      new_line = ((new_line - 1) % pattern_lines) + 1
      song.selected_line_index = new_line
    else
      -- Move to next pattern sequence(s)
      local seq_count = #song.sequencer.pattern_sequence
      local seq_index = song.selected_sequence_index
      local overflow = new_line - pattern_lines
      while overflow > 0 do
        if seq_index < seq_count then
          seq_index = seq_index + 1
        else
          -- Already on last pattern, stay at last line
          song.selected_line_index = pattern_lines
          renoise.app():show_status("Cursor at end of song")
          return
        end
        local next_pattern_lines = song.patterns[song.sequencer.pattern_sequence[seq_index]].number_of_lines
        if overflow <= next_pattern_lines then
          song.selected_sequence_index = seq_index
          song.selected_line_index = overflow
          overflow = 0
        else
          overflow = overflow - next_pattern_lines
        end
      end
    end
  else
    song.selected_line_index = new_line
  end
  renoise.app():show_status("Cursor advanced " .. steps .. " step(s) forward")
end

function PakettiAdvanceCursorBackward(steps)
  local song = renoise.song()
  local pattern_lines = song.selected_pattern.number_of_lines
  local current_line = song.selected_line_index
  local new_line = current_line - steps
  local wrapped = song.transport.wrapped_pattern_edit

  if new_line < 1 then
    if not wrapped then
      -- Wrap around within the same pattern
      while new_line < 1 do
        new_line = new_line + pattern_lines
      end
      song.selected_line_index = new_line
    else
      -- Move to previous pattern sequence(s)
      local seq_index = song.selected_sequence_index
      local underflow = 1 - new_line  -- how many lines we need to go back from line 1
      while underflow > 0 do
        if seq_index > 1 then
          seq_index = seq_index - 1
        else
          -- Already on first pattern, stay at line 1
          song.selected_line_index = 1
          renoise.app():show_status("Cursor at start of song")
          return
        end
        local prev_pattern_lines = song.patterns[song.sequencer.pattern_sequence[seq_index]].number_of_lines
        if underflow <= prev_pattern_lines then
          song.selected_sequence_index = seq_index
          song.selected_line_index = prev_pattern_lines - underflow + 1
          underflow = 0
        else
          underflow = underflow - prev_pattern_lines
        end
      end
    end
  else
    song.selected_line_index = new_line
  end
  renoise.app():show_status("Cursor advanced " .. steps .. " step(s) backward")
end

-- Generate keybindings and MIDI mappings for 1-32 steps forward and backward
for i = 1, 32 do
  local step_label = formatDigits(2, i)
  
  -- Forward keybindings and MIDI mappings
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Advance Cursor Forward by " .. step_label .. " Steps", invoke=function() PakettiAdvanceCursorForward(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Advance Cursor Forward by " .. step_label .. " Steps", invoke=function(message) if message:is_trigger() then PakettiAdvanceCursorForward(i) end end}
  
  -- Backward keybindings and MIDI mappings
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Advance Cursor Backward by " .. step_label .. " Steps", invoke=function() PakettiAdvanceCursorBackward(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Advance Cursor Backward by " .. step_label .. " Steps", invoke=function(message) if message:is_trigger() then PakettiAdvanceCursorBackward(i) end end}
end

---------------------------------------------------------------------------
-- Phrase Editor: Cursor Advance Forward/Backward by Steps
---------------------------------------------------------------------------

function PakettiAdvanceCursorForwardPhrase(steps)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  local phrase_lines = phrase.number_of_lines
  local current_line = song.selected_phrase_line_index
  local new_line = current_line + steps
  -- Wrap around if exceeds phrase length
  if new_line > phrase_lines then
    new_line = ((new_line - 1) % phrase_lines) + 1
  end
  song.selected_phrase_line_index = new_line
  renoise.app():show_status("Phrase cursor advanced " .. steps .. " step(s) forward")
end

function PakettiAdvanceCursorBackwardPhrase(steps)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  local phrase_lines = phrase.number_of_lines
  local current_line = song.selected_phrase_line_index
  local new_line = current_line - steps
  -- Wrap around if goes below 1
  while new_line < 1 do
    new_line = new_line + phrase_lines
  end
  song.selected_phrase_line_index = new_line
  renoise.app():show_status("Phrase cursor advanced " .. steps .. " step(s) backward")
end

-- Generate keybindings and MIDI mappings for 1-32 steps forward and backward in Phrase Editor
for i = 1, 32 do
  local step_label = formatDigits(2, i)
  
  -- Forward keybindings and MIDI mappings
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Advance Cursor Forward by " .. step_label .. " Steps", invoke=function() PakettiAdvanceCursorForwardPhrase(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Phrase Advance Cursor Forward by " .. step_label .. " Steps", invoke=function(message) if message:is_trigger() then PakettiAdvanceCursorForwardPhrase(i) end end}
  
  -- Backward keybindings and MIDI mappings
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Advance Cursor Backward by " .. step_label .. " Steps", invoke=function() PakettiAdvanceCursorBackwardPhrase(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Phrase Advance Cursor Backward by " .. step_label .. " Steps", invoke=function(message) if message:is_trigger() then PakettiAdvanceCursorBackwardPhrase(i) end end}
end

---------------------------------------------------------------------------
-- Dynamic Quick Jumps: Fractions of Pattern (#680)
-- Jump to 1/8, 2/8, 3/8 ... 8/8 of the current pattern length.
-- Also provides configurable fraction counts (2, 4, 8, 16).
---------------------------------------------------------------------------
local paketti_previous_cursor_position = nil

function PakettiSaveCursorPosition()
  local song = renoise.song()
  paketti_previous_cursor_position = {
    sequence = song.selected_sequence_index,
    line = song.selected_line_index
  }
end

function PakettiJumpToPatternFraction(fraction, total_fractions)
  local song = renoise.song()
  PakettiSaveCursorPosition()
  local pattern_lines = song.selected_pattern.number_of_lines
  local target_line
  if fraction >= total_fractions then
    target_line = pattern_lines
  else
    target_line = math.floor((fraction - 1) * pattern_lines / total_fractions) + 1
  end
  target_line = math.max(1, math.min(target_line, pattern_lines))
  song.selected_line_index = target_line
  renoise.app():show_status("Jumped to fraction " .. fraction .. "/" .. total_fractions .. " (line " .. target_line .. "/" .. pattern_lines .. ")")
end

-- Generate keybindings for fractions: /2, /4, /8, /16
for _, total in ipairs({2, 4, 8, 16}) do
  for frac = 1, total do
    local frac_label = string.format("%02d", frac)
    local name_suffix = frac_label .. "/" .. string.format("%02d", total)
    renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Jump to Pattern Fraction " .. name_suffix, invoke=function() PakettiJumpToPatternFraction(frac, total) end}
    renoise.tool():add_midi_mapping{name="Paketti:Jump to Pattern Fraction " .. name_suffix, invoke=function(message) if message:is_trigger() then PakettiJumpToPatternFraction(frac, total) end end}
  end
end

---------------------------------------------------------------------------
-- Jump Back to Previous Position (#683)
-- After jumping (fraction jumps or any navigation), jump back to where
-- you were. Works as a toggle: jump back, then jump forward again.
---------------------------------------------------------------------------
function PakettiJumpToPreviousPosition()
  if not paketti_previous_cursor_position then
    renoise.app():show_status("No previous position stored")
    return
  end
  local song = renoise.song()
  local current = {
    sequence = song.selected_sequence_index,
    line = song.selected_line_index
  }
  -- Jump to previous
  song.selected_sequence_index = paketti_previous_cursor_position.sequence
  song.selected_line_index = paketti_previous_cursor_position.line
  -- Store current as new previous (toggle behavior)
  paketti_previous_cursor_position = current
  renoise.app():show_status("Jumped back to sequence " .. song.selected_sequence_index .. ", line " .. song.selected_line_index)
end

-- Manual save position keybinding (for non-fraction jumps)
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Save Cursor Position", invoke=function() PakettiSaveCursorPosition() renoise.app():show_status("Cursor position saved") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Jump to Previous Position", invoke=function() PakettiJumpToPreviousPosition() end}
renoise.tool():add_keybinding{name="Global:Paketti:Jump to Previous Position", invoke=function() PakettiJumpToPreviousPosition() end}

renoise.tool():add_midi_mapping{name="Paketti:Save Cursor Position", invoke=function(message) if message:is_trigger() then PakettiSaveCursorPosition() renoise.app():show_status("Cursor position saved") end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump to Previous Position", invoke=function(message) if message:is_trigger() then PakettiJumpToPreviousPosition() end end}

---------------------------------------------------------------------------
-- Selection Follow Start - Dynamic selection from anchor to cursor
---------------------------------------------------------------------------
-- When enabled, saves current cursor position as anchor and continuously
-- updates selection from anchor to wherever cursor moves

PakettiSelectionFollowEnabled = false
PakettiSelectionFollowAnchor = nil

-- Helper function to get current column index within the track
-- Note columns are 1, 2, 3... then effect columns continue after
function PakettiSelectionFollowGetColumnIndex()
  local song = renoise.song()
  local track = song.selected_track
  local note_col_idx = song.selected_note_column_index
  local effect_col_idx = song.selected_effect_column_index
  
  if note_col_idx > 0 then
    return note_col_idx
  elseif effect_col_idx > 0 then
    return track.visible_note_columns + effect_col_idx
  else
    return 1
  end
end

-- Idle notifier that updates selection from anchor to current cursor position
function PakettiSelectionFollowIdleNotifier()
  if not PakettiSelectionFollowEnabled then
    return
  end
  
  if not PakettiSelectionFollowAnchor then
    return
  end
  
  local song
  local success = pcall(function()
    song = renoise.song()
  end)
  
  if not success or not song then
    return
  end
  
  -- Only work in pattern editor
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    return
  end
  
  -- Get current cursor position
  local current_line = song.selected_line_index
  local current_track = song.selected_track_index
  local current_column = PakettiSelectionFollowGetColumnIndex()
  
  -- Get anchor position
  local anchor_line = PakettiSelectionFollowAnchor.line
  local anchor_track = PakettiSelectionFollowAnchor.track
  local anchor_column = PakettiSelectionFollowAnchor.column
  
  -- Calculate start and end lines (Renoise requires start <= end)
  local start_line = math.min(anchor_line, current_line)
  local end_line = math.max(anchor_line, current_line)
  
  -- Determine track and column ordering
  local start_track, end_track, start_column, end_column
  
  if anchor_track == current_track then
    -- Same track - simple column min/max
    start_track = anchor_track
    end_track = anchor_track
    start_column = math.min(anchor_column, current_column)
    end_column = math.max(anchor_column, current_column)
  elseif anchor_track < current_track then
    -- Anchor is on an earlier track
    start_track = anchor_track
    end_track = current_track
    start_column = anchor_column
    end_column = current_column
  else
    -- Anchor is on a later track (current is earlier)
    start_track = current_track
    end_track = anchor_track
    start_column = current_column
    end_column = anchor_column
  end
  
  -- Set the selection with precise column boundaries
  song.selection_in_pattern = {
    start_line = start_line,
    end_line = end_line,
    start_track = start_track,
    end_track = end_track,
    start_column = start_column,
    end_column = end_column
  }
  
  print("Selection Follow: lines " .. start_line .. "-" .. end_line .. 
        ", tracks " .. start_track .. "-" .. end_track .. 
        ", columns " .. start_column .. "-" .. end_column)
end

-- Attach the idle notifier
function PakettiSelectionFollowAttachNotifier()
  if not renoise.tool().app_idle_observable:has_notifier(PakettiSelectionFollowIdleNotifier) then
    renoise.tool().app_idle_observable:add_notifier(PakettiSelectionFollowIdleNotifier)
  end
end

-- Detach the idle notifier
function PakettiSelectionFollowDetachNotifier()
  if renoise.tool().app_idle_observable:has_notifier(PakettiSelectionFollowIdleNotifier) then
    renoise.tool().app_idle_observable:remove_notifier(PakettiSelectionFollowIdleNotifier)
  end
end

-- Toggle function
function PakettiSelectionFollowToggle()
  PakettiSelectionFollowEnabled = not PakettiSelectionFollowEnabled
  
  if PakettiSelectionFollowEnabled then
    -- Save current position as anchor
    local song = renoise.song()
    local column = PakettiSelectionFollowGetColumnIndex()
    
    PakettiSelectionFollowAnchor = {
      line = song.selected_line_index,
      track = song.selected_track_index,
      column = column
    }
    
    -- Attach the idle notifier
    PakettiSelectionFollowAttachNotifier()
    
    renoise.app():show_status("Selection Follow Start: ON (Anchor at line " .. 
      PakettiSelectionFollowAnchor.line .. ", track " .. 
      PakettiSelectionFollowAnchor.track .. ", column " ..
      PakettiSelectionFollowAnchor.column .. ")")
    
    print("Selection Follow Start enabled - Anchor: line=" .. 
      PakettiSelectionFollowAnchor.line .. ", track=" .. 
      PakettiSelectionFollowAnchor.track .. ", column=" .. 
      PakettiSelectionFollowAnchor.column)
  else
    -- Detach the idle notifier
    PakettiSelectionFollowDetachNotifier()
    
    -- Clear the anchor
    PakettiSelectionFollowAnchor = nil
    
    renoise.app():show_status("Selection Follow Start: OFF")
    print("Selection Follow Start disabled")
  end
end

-- Return enabled state for menu checkmark
function PakettiSelectionFollowIsEnabled()
  return PakettiSelectionFollowEnabled
end

-- Keybinding
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Selection Follow Start",invoke=function() PakettiSelectionFollowToggle() end}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Selection Follow Start",invoke=function(message) if message:is_trigger() then PakettiSelectionFollowToggle() end end}

---------------------------------------------------------------------------
-- Selection Follow to End - Dynamic selection from cursor to end of pattern
---------------------------------------------------------------------------
-- When enabled, automatically selects from current cursor line to the end
-- of the pattern, spanning full width of the current track

PakettiSelectionFollowToEndEnabled = false

-- Idle notifier that updates selection from current line to end of pattern
function PakettiSelectionFollowToEndIdleNotifier()
  if not PakettiSelectionFollowToEndEnabled then
    return
  end
  
  local song
  local success = pcall(function()
    song = renoise.song()
  end)
  
  if not success or not song then
    return
  end
  
  -- Only work in pattern editor
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    return
  end
  
  -- Get current position
  local current_line = song.selected_line_index
  local current_track = song.selected_track_index
  local track = song.selected_track
  local pattern = song.selected_pattern
  
  -- Calculate last column (full track width)
  local last_column = track.visible_note_columns + track.visible_effect_columns
  
  -- Set selection from current line to end of pattern, full track width
  song.selection_in_pattern = {
    start_line = current_line,
    end_line = pattern.number_of_lines,
    start_track = current_track,
    end_track = current_track,
    start_column = 1,
    end_column = last_column
  }
  
  -- Also select automation range if automation frame is visible
  if renoise.app().window.lower_frame_is_visible and 
     renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
    local automation_param = song.selected_automation_parameter
    if automation_param then
      local pattern_track = song.selected_pattern_track
      local automation = pattern_track:find_automation(automation_param)
      if automation then
        automation.selection_range = {current_line, pattern.number_of_lines}
      end
    end
  end
end

-- Attach the idle notifier
function PakettiSelectionFollowToEndAttachNotifier()
  if not renoise.tool().app_idle_observable:has_notifier(PakettiSelectionFollowToEndIdleNotifier) then
    renoise.tool().app_idle_observable:add_notifier(PakettiSelectionFollowToEndIdleNotifier)
  end
end

-- Detach the idle notifier
function PakettiSelectionFollowToEndDetachNotifier()
  if renoise.tool().app_idle_observable:has_notifier(PakettiSelectionFollowToEndIdleNotifier) then
    renoise.tool().app_idle_observable:remove_notifier(PakettiSelectionFollowToEndIdleNotifier)
  end
end

-- Toggle function
function PakettiSelectionFollowToEndToggle()
  PakettiSelectionFollowToEndEnabled = not PakettiSelectionFollowToEndEnabled
  
  if PakettiSelectionFollowToEndEnabled then
    -- Attach the idle notifier
    PakettiSelectionFollowToEndAttachNotifier()
    
    local song = renoise.song()
    renoise.app():show_status("Selection Follow to End: ON (Line " .. 
      song.selected_line_index .. " to " .. 
      song.selected_pattern.number_of_lines .. ")")
    
    print("Selection Follow to End enabled")
  else
    -- Detach the idle notifier
    PakettiSelectionFollowToEndDetachNotifier()
    
    renoise.app():show_status("Selection Follow to End: OFF")
    print("Selection Follow to End disabled")
  end
end

-- Return enabled state for menu checkmark
function PakettiSelectionFollowToEndIsEnabled()
  return PakettiSelectionFollowToEndEnabled
end

-- Keybinding
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Selection Follow to End",invoke=function() PakettiSelectionFollowToEndToggle() end}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Selection Follow to End",invoke=function(message) if message:is_trigger() then PakettiSelectionFollowToEndToggle() end end}
