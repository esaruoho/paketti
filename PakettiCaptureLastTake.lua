-- PakettiCaptureLastTake.lua
-- Lua 5.1 only. All functions GLOBAL and defined before first use.
-- Uses my_keyhandler_func as fallback. After dialog opens, reactivate middle frame for key passthrough.

-- State
PakettiCapture_dialog = nil
PakettiCapture_vb = nil
PakettiCapture_log_view = nil
PakettiCapture_rows_text = {}
PakettiCapture_rows_buttons = {}
PakettiCapture_rows_details = {}
PakettiCapture_sequences = {}
PakettiCapture_current_notes = {}
PakettiCapture_current_set = {}
PakettiCapture_MAX_ROWS = 16
PakettiCapture_dump_buttons = {}
PakettiCapture_audition_buttons = {}
PakettiCapture_current_audition_slot = nil
PakettiCapture_audition_notes = {}
PakettiCapture_audition_samples = {}
PakettiCapture_selected_audition_slot = 1
PakettiCapture_DEBUG = true
PakettiCapture_scrollbar = nil
PakettiCapture_observers_active = false
PakettiCapture_current_tf = nil
PakettiCapture_newest_label = nil
PakettiCapture_BUTTON_HEIGHT = 20
PakettiCapture_DIALOG_WIDTH = 620
PakettiCapture_SCROLLBAR_WIDTH = 80
PakettiCapture_ROW_BUTTON_WIDTH = 40
PakettiCapture_LEFT_LABEL_WIDTH = 140
PakettiCapture_TOP_DUMP_BTN_WIDTH = 160
PakettiCapture_TOP_CLEAR_BTN_WIDTH = 180
PakettiCapture_GAP = 1
PakettiCapture_midi_device = nil
PakettiCapture_midi_listening = false
PakettiCapture_ExperimentalMIDICapture = true

PakettiCapture_SelectedMidiDeviceName = ""
-- Gate Incoming MIDI by EditStep (global state)
PakettiGate_midi_device = nil
PakettiGate_listening = false
PakettiGate_latest_note_value = nil
PakettiGate_prev_line = nil
-- hide features
PakettiCapture_ExperimentalMIDICaptureDialog = true
PakettiGate_ShowUI = true

-- Gater expandable section variables
PakettiCapture_gater_expanded = false
PakettiCapture_gater_toggle_button = nil
PakettiCapture_gater_content_column = nil



-- Helper: convert note string (e.g. "C-4", "D#5") to 0..119 value; returns nil for invalid or OFF
function PakettiCapture_NoteStringToValue(note_string)
  if not note_string or note_string == "" or note_string == "OFF" then return nil end
  local name = string.sub(note_string, 1, 2)
  local octave_char = string.sub(note_string, 3, 3)
  local names = { ["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3, ["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7, ["G#"] = 8, ["A-"] = 9, ["A#"] = 10, ["B-"] = 11 }
  local base = names[name]
  local octave = tonumber(octave_char)
  if base == nil or octave == nil then return nil end
  local value = (octave * 12) + base
  return PakettiCapture_Clamp(value, 0, 119)
end

-- Helper: return a new table of notes sorted ascending by pitch, limited to 12
function PakettiCapture_SortNotesAscending(notes)
  local tmp = {}
  local count = math.min(12, #notes)
  for i = 1, count do tmp[i] = notes[i] end
  table.sort(tmp, function(a, b)
    local va = PakettiCapture_NoteStringToValue(a) or -1
    local vb = PakettiCapture_NoteStringToValue(b) or -1
    return va < vb
  end)
  return tmp
end

function PakettiCapture_MidiCallback(message)
  if not message or #message ~= 3 then return end
  local status = message[1]
  local data1 = message[2]
  local data2 = message[3]
  if (bit.band(status, 0xF0) == 0x90) and (data2 and data2 > 0) then
    local note_value = PakettiCapture_Clamp(tonumber(data1) or 0, 0, 119)
    local note_str = PakettiCapture_NoteValueToString(note_value)
    if PakettiCapture_ExperimentalMIDICapture then
      print("PakettiCapture MIDI NOTE ON: " .. string.format("%02X %02X %02X", status, data1, data2) .. " -> " .. tostring(note_str))
    end
    if not PakettiCapture_current_set[note_str] then
      if #PakettiCapture_current_notes >= 12 then
        renoise.app():show_status("Cannot exceed 12 notes.")
        return
      end
      PakettiCapture_current_set[note_str] = true
      table.insert(PakettiCapture_current_notes, note_str)
      PakettiCapture_UpdateUI()
    end
  end
end

-- Gate MIDI: capture most recent note-on
function PakettiGate_MidiCallback(message)
  if not message or #message ~= 3 then return end
  local status = message[1]
  local data1 = message[2]
  local data2 = message[3]
  if (bit.band(status, 0xF0) == 0x90) and (data2 and data2 > 0) then
    PakettiGate_latest_note_value = PakettiCapture_Clamp(tonumber(data1) or 0, 0, 119)
  end
end

function PakettiGate_Start()
  if PakettiGate_listening then return end
  local inputs = renoise.Midi.available_input_devices()
  if not inputs or #inputs == 0 then
    renoise.app():show_status("PakettiGate: No MIDI input devices available")
    return
  end
  local device_name = PakettiCapture_SelectedMidiDeviceName
  if not device_name or device_name == "" then device_name = inputs[1] end
  PakettiGate_midi_device = renoise.Midi.create_input_device(device_name, PakettiGate_MidiCallback)
  PakettiGate_listening = true
  PakettiGate_prev_line = nil
  renoise.app():show_status("PakettiGate: Listening on " .. tostring(device_name))
end

function PakettiGate_Stop()
  if PakettiGate_midi_device then PakettiGate_midi_device:close() PakettiGate_midi_device = nil end
  PakettiGate_listening = false
  PakettiGate_prev_line = nil
  renoise.app():show_status("PakettiGate: Stopped")
end

-- Idle: write latest note to pattern on editstep-aligned lines during playback
function PakettiGate_Idle()
  if not PakettiGate_listening then return end
  local song = renoise.song()
  if not song.transport.playing then return end
  local editstep = math.max(1, song.transport.edit_step or 1)
  local line = song.selected_line_index
  if PakettiGate_prev_line == line then return end
  PakettiGate_prev_line = line
  if ((line - 1) % editstep) ~= 0 then return end
  if not PakettiGate_latest_note_value then return end

  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local p_line = ptrack:line(line)
  local ncol = p_line:note_column(1)
  ncol.note_value = PakettiGate_latest_note_value
  ncol.instrument_value = song.selected_instrument_index - 1
end

function PakettiCapture_StartMidiListening()
  if PakettiCapture_midi_listening then return end
  local inputs = renoise.Midi.available_input_devices()
  if not inputs or #inputs == 0 then
    renoise.app():show_status("PakettiCapture: No MIDI input devices available")
    return
  end
  local device_name = PakettiCapture_SelectedMidiDeviceName
  if not device_name or device_name == "" then
    device_name = inputs[1]
  end
  PakettiCapture_midi_device = renoise.Midi.create_input_device(device_name, PakettiCapture_MidiCallback)
  PakettiCapture_midi_listening = true
  renoise.app():show_status("PakettiCapture: Listening to MIDI on " .. tostring(device_name))
end

function PakettiCapture_StopMidiListening()
  if PakettiCapture_midi_device then
    PakettiCapture_midi_device:close()
    PakettiCapture_midi_device = nil
  end
  PakettiCapture_midi_listening = false
  renoise.app():show_status("PakettiCapture: Stopped MIDI listening")
end

-- Ensure we never keep a MIDI listener running when dialog is not open
function PakettiCapture_IdleCheck()
  if PakettiCapture_midi_listening then
    if not (PakettiCapture_dialog and PakettiCapture_dialog.visible) then
      PakettiCapture_StopMidiListening()
    end
  end
end

-- Safety: stop MIDI listener when tool is unloaded/reloaded
if renoise.tool().app_release_document_observable then
  if not renoise.tool().app_release_document_observable:has_notifier(function()
    if PakettiCapture_midi_listening then PakettiCapture_StopMidiListening() end
  end) then
    renoise.tool().app_release_document_observable:add_notifier(function()
      if PakettiCapture_midi_listening then PakettiCapture_StopMidiListening() end
    end)
  end
end

-- Add an idle notifier to enforce the listener-while-closed rule
if renoise.tool().app_idle_observable then
  if not renoise.tool().app_idle_observable:has_notifier(PakettiCapture_IdleCheck) then
    renoise.tool().app_idle_observable:add_notifier(PakettiCapture_IdleCheck)
  end
end

-- Function to update gater section visibility
function PakettiCapture_UpdateGaterVisibility()
  if PakettiCapture_gater_content_column then
    PakettiCapture_gater_content_column.visible = PakettiCapture_gater_expanded
    
    -- Setup/cleanup playhead timer based on visibility
    if PakettiCapture_gater_expanded then
      PakettiGaterSetupPlayhead()
    else
      PakettiGaterCleanupPlayhead()
    end
  end
  if PakettiCapture_gater_toggle_button then
    PakettiCapture_gater_toggle_button.text = PakettiCapture_gater_expanded and "▾" or "▴"
  end
end

-- Attach gate idle handler
if renoise.tool().app_idle_observable then
  if not renoise.tool().app_idle_observable:has_notifier(PakettiGate_Idle) then
    renoise.tool().app_idle_observable:add_notifier(PakettiGate_Idle)
  end
end

-- Shortcut & MIDI mapping to toggle EditStep Gate
function PakettiGate_Toggle()
  if PakettiGate_listening then PakettiGate_Stop() else PakettiGate_Start() end
end

renoise.tool():add_keybinding{ name = "Global:Paketti:Toggle EditStep MIDI Gate", invoke = PakettiGate_Toggle }
renoise.tool():add_midi_mapping{ name = "Paketti:Toggle EditStep MIDI Gate", invoke = PakettiGate_Toggle }

-- Helper: place note-offs in all note columns of current line without toggling
function PakettiCapture_PlaceNoteOffsAllColumns()
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local line = ptrack:line(song.selected_line_index)
  
  -- Place note-offs in all visible note columns
  local max_cols = math.min(12, track.visible_note_columns or 1)
  for i = 1, max_cols do
    local ncol = line:note_column(i)
    ncol.note_string = "OFF"
    ncol.instrument_value = 255  -- Clear instrument
  end
end

-- Mapping of keyboard keys to semitone offsets from C in the current transport octave
-- Includes:
--  - Top QWERTY row (q..p with number sharps)
--  - Bottom "piano" row z..m mapped to one octave LOWER (offsets -12..-1)
--  - Continuation keys ", l . ö -" mapped to the SAME octave (offsets 0..4)
PakettiCapture_note_keymap = {
  q = 0,  ["2"] = 1,  w = 2,  ["3"] = 3,  e = 4,
  r = 5,  ["5"] = 6,  t = 7,  ["6"] = 8,  y = 9,
  ["7"] = 10, u = 11,
  -- next partial octave on the same row
  i = 12, ["9"] = 13, o = 14, ["0"] = 15, p = 16, ["å"] = 17, ["¨"] = 18, ["="] = 18, ["]"] = 19,
  -- bottom row (computer keyboard piano) at one octave LOWER than transport.octave
  z = -12, s = -11, x = -10, d = -9,  c = -8,
  v = -7,  g = -6,  b = -5,  h = -4,  n = -3,
  j = -2,  m = -1,
  -- continuation into the SAME octave as transport.octave
  [","] = 0, ["comma"] = 0, l = 1,  ["."] = 2, ["period"] = 2, ["ö"] = 3,
  ["-"] = 4, ["minus"] = 4, ["hyphen"] = 4
}

-- Helper: clamp integer
function PakettiCapture_Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Helper: convert 0..119 to note string C-0..B-9
function PakettiCapture_NoteValueToString(value)
  local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
  local v = PakettiCapture_Clamp(value, 0, 119)
  local octave = math.floor(v / 12)
  local name = names[(v % 12) + 1]
  return name .. tostring(octave)
end

-- Stop any currently playing audition
function PakettiCaptureAuditionStop()
  if PakettiCapture_current_audition_slot == nil then return end
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  
  -- Stop all notes that were triggered for this slot using instrument note off
  if #PakettiCapture_audition_notes > 0 then
    song:trigger_instrument_note_off(selected_instrument_index, selected_track_index, PakettiCapture_audition_notes)
  end
  
  PakettiCapture_current_audition_slot = nil
  PakettiCapture_audition_notes = {}
  PakettiCapture_audition_samples = {}
  
  -- Update UI to reflect stopped state
  PakettiCapture_UpdateUI()
end

-- Start audition for a specific slot
function PakettiCaptureAuditionStart(slot_index)
  if slot_index < 1 or slot_index > #PakettiCapture_sequences then return end
  
  -- Stop any currently playing audition first
  PakettiCaptureAuditionStop()
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song:instrument(selected_instrument_index)
  
  -- Get the notes from this slot
  local seq = PakettiCapture_sequences[slot_index]
  if not seq or #seq == 0 then return end
  
  -- Check if instrument exists
  if not instrument then return end
  
  -- Convert note strings to values and trigger them using instrument 
  PakettiCapture_current_audition_slot = slot_index
  PakettiCapture_audition_notes = {}
  PakettiCapture_audition_samples = {}
  
  if PakettiCapture_DEBUG then
    print("PakettiCapture DEBUG: Using instrument " .. tostring(selected_instrument_index) .. " for audition")
  end
  
  -- Convert all note strings to values first
  local note_values = {}
  for i = 1, #seq do
    local note_string = seq[i]
    local note_value = PakettiCapture_NoteStringToValue(note_string)
    if note_value then
      table.insert(note_values, note_value)
      table.insert(PakettiCapture_audition_notes, note_value)
    end
  end
  
  -- Trigger all notes as a chord using instrument trigger (respects keyzones and instrument settings)
  if PakettiCapture_DEBUG then
    print("PakettiCapture DEBUG: Will trigger chord with " .. tostring(#note_values) .. " notes on instrument")
    for j = 1, #note_values do
      print("PakettiCapture DEBUG: Note " .. tostring(j) .. ": " .. tostring(note_values[j]))
    end
  end
  
  -- Trigger all notes as a chord in a single call using instrument
  if #note_values > 0 then
    song:trigger_instrument_note_on(selected_instrument_index, selected_track_index, note_values, 1.0)
  end
  
  -- Update UI to reflect playing state
  PakettiCapture_UpdateUI()
end

-- Toggle audition for a specific slot
function PakettiCaptureAuditionToggle(slot_index)
  if PakettiCapture_current_audition_slot == slot_index then
    PakettiCaptureAuditionStop()
  else
    PakettiCaptureAuditionStart(slot_index)
  end
end

-- Put the currently auditioning slot to the first row of pattern and note-offs to last row
function PakettiCapture_PutAuditionSlotToPattern()
  if not PakettiCapture_current_audition_slot then
    renoise.app():show_status("PakettiCapture: No slot is currently being auditioned")
    return
  end
  
  local slot_index = PakettiCapture_current_audition_slot
  if slot_index < 1 or slot_index > #PakettiCapture_sequences then
    renoise.app():show_status("PakettiCapture: Invalid audition slot")
    return
  end
  
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiCapture: Not a sequencer track")
    return
  end
  
  local patt = song:pattern(song.selected_pattern_index)
  local original_line = song.selected_line_index
  
  -- Stop audition first
  PakettiCaptureAuditionStop()
  
  -- Put the slot to the first row of the pattern
  song.selected_line_index = 1
  PakettiCapture_DumpRow(slot_index)
  
  -- Place note-offs on the last row of the pattern
  song.selected_line_index = patt.number_of_lines
  PakettiCapture_PlaceNoteOffsAllColumns()
  
  -- Restore original line selection
  song.selected_line_index = original_line
  
  renoise.app():show_status("PakettiCapture: Put audition slot " .. string.format("%02d", slot_index) .. " to pattern (first row + note-offs on last row)")
end

-- Helper: convert key.name to note string based on current octave; returns nil if key is not a note key
function PakettiCapture_KeyToNoteString(key_name)
  if not key_name then return nil end
  local offset = PakettiCapture_note_keymap[key_name]
  if offset == nil then return nil end
  local song = renoise.song()
  local base_oct = song.transport.octave or 4
  local key_oct = base_oct + 1 -- z-row is base_oct, q/"," rows are one octave above
  local value = (key_oct * 12) + offset
  if value < 0 then
    value = value + 12 * math.ceil((-value) / 12)
  end
  if value > 119 then return nil end
  value = PakettiCapture_Clamp(value, 0, 119)
  return PakettiCapture_NoteValueToString(value)
end

-- Append current buffer as a sequence row
function PakettiCapture_CommitCurrent()
  if #PakettiCapture_current_notes == 0 then return end
  local seq = {}
  local limit = math.min(12, #PakettiCapture_current_notes)
  for i = 1, limit do seq[i] = PakettiCapture_current_notes[i] end
  print("PakettiCapture DEBUG: sequences before commit: " .. tostring(#PakettiCapture_sequences))
  table.insert(PakettiCapture_sequences, seq) -- append so 01 stays, 02 appears below
  print("PakettiCapture DEBUG: sequences after commit: " .. tostring(#PakettiCapture_sequences))
  while #PakettiCapture_sequences > PakettiCapture_MAX_ROWS do
    table.remove(PakettiCapture_sequences, 1) -- drop oldest when exceeding max rows
  end
  
  -- Ensure selected audition slot is valid after adding new sequence
  if PakettiCapture_selected_audition_slot > #PakettiCapture_sequences then
    PakettiCapture_selected_audition_slot = #PakettiCapture_sequences
  end
  
  PakettiCapture_current_notes = {}
  PakettiCapture_current_set = {}
  PakettiCapture_UpdateUI()
  renoise.app():show_status("PakettiCapture: Committed current take (" .. tostring(#seq) .. " notes)")
end

-- Clear all captured
function PakettiCapture_ClearAll()
  PakettiCaptureAuditionStop()  -- Stop any playing audition
  PakettiCapture_sequences = {}
  PakettiCapture_current_notes = {}
  PakettiCapture_current_set = {}
  PakettiCapture_selected_audition_slot = 1  -- Reset selection to first slot
  PakettiCapture_UpdateUI()
end

-- Pick up notes from the current pattern track and fill slots
function PakettiCapture_PickupFromPattern()
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiCapture: Not a sequencer track")
    return
  end
  
  PakettiCaptureAuditionStop()  -- Stop any playing audition
  PakettiCapture_sequences = {}
  local slot_count = 0
  
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local num_lines = patt.number_of_lines
  
  if PakettiCapture_DEBUG then
    print("PakettiCapture DEBUG: Scanning pattern with " .. tostring(num_lines) .. " lines")
  end
  
  for line_idx = 1, num_lines do
    if slot_count >= PakettiCapture_MAX_ROWS then break end -- Stop at 16 slots
    
    local line = ptrack:line(line_idx)
    local notes_in_line = {}
    
    -- Scan all note columns in this line
    local max_cols = math.min(12, #line.note_columns)
    for col_idx = 1, max_cols do
      local ncol = line:note_column(col_idx)
      if not ncol.is_empty and ncol.note_string ~= "OFF" and ncol.note_string ~= "" then
        table.insert(notes_in_line, ncol.note_string)
      end
    end
    
    -- If we found notes in this line, create a slot
    if #notes_in_line > 0 then
      slot_count = slot_count + 1
      table.insert(PakettiCapture_sequences, notes_in_line)
      if PakettiCapture_DEBUG then
        print("PakettiCapture DEBUG: Line " .. tostring(line_idx) .. " -> Slot " .. tostring(slot_count) .. ": " .. table.concat(notes_in_line, " "))
      end
    end
  end
  
  PakettiCapture_selected_audition_slot = 1  -- Reset selection to first slot
  PakettiCapture_UpdateUI()
  renoise.app():show_status("PakettiCapture: Picked up " .. tostring(slot_count) .. " slots from pattern")
end

-- Dump a specific row to the current pattern line, fitting visible note columns
function PakettiCapture_DumpRow(index)
  if index < 1 or index > #PakettiCapture_sequences then return end
  local song = renoise.song()
  local track = song.selected_track
  if not track then return end
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiCapture: Not a sequencer track")
    return
  end
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local line = ptrack:line(song.selected_line_index)

  local notes = PakettiCapture_sequences[index]
  local sorted_notes = PakettiCapture_SortNotesAscending(notes)
  local needed = #sorted_notes
  if needed < 1 then return end

  -- Fit visible note columns
  local max_cols = 12 -- hard cap; sequencer tracks in Renoise max out at 12 note columns
  local needed_cols = PakettiCapture_Clamp(needed, 1, max_cols)
  local current_visible = track.visible_note_columns or 1
  local target_cols = math.max(current_visible, needed_cols)
  if track.visible_note_columns ~= target_cols then
    track.visible_note_columns = target_cols
  end
  -- Smart Note-Off above target line if enabled (after ensuring note column size)
  if preferences and preferences.pakettiCaptureLastTakeSmartNoteOff and preferences.pakettiCaptureLastTakeSmartNoteOff.value then
    local prev = song.selected_line_index - 1
    if prev >= 1 then
      local original_line = song.selected_line_index
      song.selected_line_index = prev
      PakettiCapture_PlaceNoteOffsAllColumns()
      song.selected_line_index = original_line
    end
  end

  -- Write notes as strings; clear extra columns
  for i = 1, needed_cols do
    local ncol = line:note_column(i)
    local val = sorted_notes[i]
    if val and val ~= "OFF" then
      ncol.note_string = val
      ncol.instrument_value = song.selected_instrument_index - 1
    else
      -- If empty or explicit OFF, clear instrument to avoid stale instrument values
      ncol.note_string = val == "OFF" and "OFF" or ""
      ncol.instrument_value = 255
    end
  end
  -- Only clear extra columns if we actually have notes and more columns than needed
  if needed > 0 and needed_cols < max_cols then
    for i = needed_cols + 1, max_cols do
      local ncol = line:note_column(i)
      if not ncol.is_empty then
        ncol.note_string = ""
        ncol.instrument_value = 255
      end
    end
  end

  -- Also place note-offs on the last pattern line when enabled
  if preferences and preferences.pakettiCaptureLastTakeSmartNoteOff and preferences.pakettiCaptureLastTakeSmartNoteOff.value then
    local original_line_final = song.selected_line_index
    local last_line = patt.number_of_lines
    if last_line and last_line >= 1 then
      song.selected_line_index = last_line
      PakettiCapture_PlaceNoteOffsAllColumns()
      song.selected_line_index = original_line_final
    end
  end

  renoise.app():show_status("PakettiCapture: Wrote " .. tostring(needed) .. " notes to row")
end

-- Fit all stored slots to the current pattern length
function PakettiCapture_FitSlotsToPattern()
  local song = renoise.song()
  local patt = song:pattern(song.selected_pattern_index)
  local num_lines = patt.number_of_lines
  local total_slots = #PakettiCapture_sequences
  if total_slots == 0 then
    renoise.app():show_status("PakettiCapture: No slots to fit")
    return
  end
  if total_slots > num_lines then
    renoise.app():show_status("PakettiCapture: " .. tostring(total_slots) .. " slots won't fit into pattern with " .. tostring(num_lines) .. " rows")
    return
  end

  local step = math.floor(num_lines / total_slots)
  if step < 1 then step = 1 end

  local start_line = 1
  local original_line = song.selected_line_index
  for i = 1, total_slots do
    song.selected_line_index = start_line
    PakettiCapture_DumpRow(i)
    
    -- Place note-offs before the next slot (but not after the last slot)
    if i < total_slots then
      local next_slot_line = math.min(num_lines, start_line + step)
      local noteoff_line = math.max(1, next_slot_line - 1)
      if noteoff_line > start_line and noteoff_line <= num_lines then
        song.selected_line_index = noteoff_line
        PakettiCapture_PlaceNoteOffsAllColumns()
      end
    end
    
    start_line = math.min(num_lines, start_line + step)
  end
  
  -- Always place note-offs on the last pattern line for Fit Slots to Pattern
  song.selected_line_index = num_lines
  PakettiCapture_PlaceNoteOffsAllColumns()
  
  -- Restore user-facing selection
  song.selected_line_index = original_line
end

-- Randomly shift each note in each slot by ±12 or ±24 semitones
function PakettiCapture_AlternatePhrasing()
  trueRandomSeed()

  if #PakettiCapture_sequences == 0 then return end
  local shifts = { -12, 12,}
  for s = 1, #PakettiCapture_sequences do
    local seq = PakettiCapture_sequences[s]
    for n = 1, #seq do
      local val = PakettiCapture_NoteStringToValue(seq[n])
      if val then
        local shift = shifts[math.random(#shifts)]
        local new_val = val + shift
        -- If shift would go out of bounds, reverse direction instead of clamping
        if new_val < 0 or new_val > 119 then
          new_val = val - shift
        end
        -- Final safety clamp (should not be needed with proper reversal)
        new_val = PakettiCapture_Clamp(new_val, 0, 119)
        seq[n] = PakettiCapture_NoteValueToString(new_val)
      end
    end
  end
  PakettiCapture_UpdateUI()
end

-- Randomly shift notes already present in the selected track across the entire current pattern
function PakettiCapture_AlternatePatternPhrasing()
  local song = renoise.song()
  local patt = song:pattern(song.selected_pattern_index)
  local track = patt:track(song.selected_track_index)
  local num_lines = patt.number_of_lines
  local shifts = { -12, 12,}

  for line_idx = 1, num_lines do
    local line = track:line(line_idx)
    for col_idx = 1, math.min(12, #line.note_columns) do
      local ncol = line:note_column(col_idx)
      if not ncol.is_empty and ncol.note_string ~= "OFF" and ncol.note_string ~= "" then
        local val = PakettiCapture_NoteStringToValue(ncol.note_string)
        if val then
          local shift = shifts[math.random(#shifts)]
          local new_val = val + shift
          -- If shift would go out of bounds, reverse direction instead of clamping
          if new_val < 0 or new_val > 119 then
            new_val = val - shift
          end
          -- Final safety clamp (should not be needed with proper reversal)
          new_val = PakettiCapture_Clamp(new_val, 0, 119)
          ncol.note_string = PakettiCapture_NoteValueToString(new_val)
        end
      end
    end
  end
  renoise.app():show_status("PakettiCapture: Alternated phrasing on selected track")
end

-- Dump by display index (01 is newest). Maps display index to underlying sequence index.
function PakettiCapture_DumpRowDisplay(display_index)
  local total = #PakettiCapture_sequences
  if total < 1 then return end
  local real_index = display_index
  if real_index < 1 or real_index > total then return end
  PakettiCapture_DumpRow(real_index)
end



-- Update UI rows and log
function PakettiCapture_UpdateUI()
  if not PakettiCapture_vb then return end

  -- Update the vertical list of 20 rows: [button NN] [notes]
  for i = 1, PakettiCapture_MAX_ROWS do
    local txt = PakettiCapture_rows_text[i]
    if txt then
      if i <= #PakettiCapture_sequences then
        local seq = PakettiCapture_sequences[i]
        txt.text = table.concat(seq, " ")
        -- Make selected audition slot bold
        if PakettiCapture_selected_audition_slot == i then
          txt.style = "strong"
        else
          txt.style = "normal"
        end
      else
        txt.text = ""
        txt.style = "normal"
      end
    end
  end

  -- Update current pressed notes (single-line textfield content)
  if PakettiCapture_current_tf then
    PakettiCapture_current_tf.text = (#PakettiCapture_current_notes > 0) and table.concat(PakettiCapture_current_notes, " ") or ""
  end

  -- Update quick dump buttons active state
  for i = 1, PakettiCapture_MAX_ROWS do
    local btn = PakettiCapture_dump_buttons[i]
    if btn then
      btn.active = (i <= #PakettiCapture_sequences)
    end
  end

  -- Update audition buttons active state and text
  for i = 1, PakettiCapture_MAX_ROWS do
    local audition_btn = PakettiCapture_audition_buttons[i]
    if audition_btn then
      local has_content = (i <= #PakettiCapture_sequences)
      audition_btn.active = has_content
      if has_content then
        if PakettiCapture_current_audition_slot == i then
          audition_btn.text = "Stop"
        else
          audition_btn.text = "Audition"
        end
      else
        audition_btn.text = "Audition"
      end
    end
  end

  -- Update newest label to show the most recent take inline
  if PakettiCapture_newest_label then
    if #PakettiCapture_sequences > 0 then
      local seq = PakettiCapture_sequences[#PakettiCapture_sequences]
      PakettiCapture_newest_label.text = "Newest: " .. table.concat(seq, " ")
    else
      PakettiCapture_newest_label.text = "Newest: "
    end
  end

  -- Sync scrollbar with song state
  PakettiCapture_UpdateScrollbar()
end

-- Key handler modeled after Autocomplete: capture note keys but pass them back; handle control keys locally
function PakettiCapture_KeyHandler(dialog, key)
  -- Shift+Enter: clear all stored takes
  if key and key.modifiers == "shift" and (key.name == "return" or key.name == "enter") then
    PakettiCapture_ClearAll()
    renoise.app():show_status("PakettiCapture: Cleared all takes")
    return nil
  end
  if key and key.modifiers == "shift" and key.name == "back" then
    PakettiCapture_current_notes = {}
    PakettiCapture_current_set = {}
    PakettiCapture_UpdateUI()
    renoise.app():show_status("PakettiCapture: Cleared current notes")
    return nil
  end
  if key and key.name == "return" then
    PakettiCapture_CommitCurrent()
    return nil
  elseif key and key.name == "back" then
    if #PakettiCapture_current_notes > 0 then
      local removed = table.remove(PakettiCapture_current_notes)
      if removed then PakettiCapture_current_set[removed] = nil end
      PakettiCapture_UpdateUI()
    end
    return nil
  elseif key and key.name == "delete" then
    PakettiCapture_current_notes = {}
    PakettiCapture_current_set = {}
    PakettiCapture_UpdateUI()
    return nil
  elseif key and key.name == "up" then
    -- Navigate up in audition slot selection
    if PakettiCapture_selected_audition_slot > 1 then
      PakettiCapture_selected_audition_slot = PakettiCapture_selected_audition_slot - 1
    end
    PakettiCapture_UpdateUI()
    return nil
  elseif key and key.name == "down" then
    -- Navigate down in audition slot selection
    local max_slot = math.min(PakettiCapture_MAX_ROWS, #PakettiCapture_sequences)
    if PakettiCapture_selected_audition_slot < max_slot then
      PakettiCapture_selected_audition_slot = PakettiCapture_selected_audition_slot + 1
    end
    PakettiCapture_UpdateUI()
    return nil
  elseif key and key.name == "space" then
    -- Toggle audition for currently selected slot
    if PakettiCapture_selected_audition_slot <= #PakettiCapture_sequences then
      PakettiCaptureAuditionToggle(PakettiCapture_selected_audition_slot)
    end
    return nil
  elseif key and key.modifiers == "control" and key.name == "p" then
    -- Ctrl+P: Pick up from pattern
    PakettiCapture_PickupFromPattern()
    return nil
  end

  -- Map key to note; if mapped, append to current buffer and PASS THROUGH
  local kname = tostring(key and key.name or "")
  local note = PakettiCapture_KeyToNoteString(kname)
  if note then
    if PakettiCapture_DEBUG then
      print("PakettiCapture DEBUG: mapped key '" .. tostring(kname) .. "' to note '" .. tostring(note) .. "'")
    end
    if not PakettiCapture_current_set[note] then
      if #PakettiCapture_current_notes >= 12 then
        renoise.app():show_status("Cannot exceed 12 notes.")
        return key
      end
      PakettiCapture_current_set[note] = true
      table.insert(PakettiCapture_current_notes, note)
      PakettiCapture_UpdateUI()
    end
    return key -- pass back to Renoise so notes still play
  end

  if PakettiCapture_DEBUG then
    print("PakettiCapture DEBUG: unmapped key pressed -> name:'" .. tostring(kname) .. "' modifiers:'" .. tostring(key and key.modifiers or "") .. "' repeated:'" .. tostring(key and key.repeated or false) .. "'")
  end
  -- Fallback to global handler for close etc.
  return my_keyhandler_func(dialog, key)
end

-- Build fixed rows
function PakettiCapture_BuildRows()
  local rows = {}
  for i = 1, PakettiCapture_MAX_ROWS do
    local idx = i
    local btn = PakettiCapture_vb:button{
      text = string.format("%02d", i),
      width = PakettiCapture_ROW_BUTTON_WIDTH,
      height = PakettiCapture_BUTTON_HEIGHT,
      active = false,
      notifier = function() PakettiCapture_DumpRowDisplay(idx) end
    }
    PakettiCapture_dump_buttons[i] = btn
    
    local audition_btn = PakettiCapture_vb:button{
      text = "Audition",
      width = 60,
      height = PakettiCapture_BUTTON_HEIGHT,
      active = false,
      notifier = function() PakettiCaptureAuditionToggle(idx) end
    }
    PakettiCapture_audition_buttons[i] = audition_btn
    
    local rt = PakettiCapture_vb:text{ text = "", width = 240, style = "normal" }
    PakettiCapture_rows_text[i] = rt
    table.insert(rows, PakettiCapture_vb:row{ height = PakettiCapture_BUTTON_HEIGHT, btn, audition_btn, rt })
  end
  return rows
end

-- Build scrollbar column (label + vertical scrollbar)
function PakettiCapture_BuildScrollbar()
  local song = renoise.song()
  local patt = song:pattern(song.selected_pattern_index)
  local max_lines = patt.number_of_lines
  -- ViewBuilder scrollbar value range is min to max-pagestep, so max should be max_lines+1 to allow value max_lines
  PakettiCapture_scrollbar = PakettiCapture_vb:scrollbar{
    min = 1,
    max = max_lines + 1,
    value = PakettiCapture_Clamp(song.selected_line_index, 1, max_lines),
    step = 1,
    pagestep = 1,
    autohide = false,
    background = "group",
    width=80,
    height = PakettiCapture_BUTTON_HEIGHT*PakettiCapture_MAX_ROWS,
    notifier = function(value)
      local s = renoise.song()
      local p = s:pattern(s.selected_pattern_index)
      local ml = p.number_of_lines
      local v = math.floor(PakettiCapture_Clamp(value, 1, ml))
      if s.selected_line_index ~= v then
        s.selected_line_index = v
      end
    end
  }
  return PakettiCapture_vb:column{
    PakettiCapture_vb:text{ text = "Pattern Line", font = "bold", style = "strong", width = PakettiCapture_SCROLLBAR_WIDTH },
    PakettiCapture_scrollbar
  }
end

-- Keep scrollbar in sync with current pattern
function PakettiCapture_UpdateScrollbar()
  if not PakettiCapture_scrollbar then return end
  local song = renoise.song()
  local patt = song:pattern(song.selected_pattern_index)
  local max_lines = patt.number_of_lines
  PakettiCapture_scrollbar.min = 1
  -- ViewBuilder scrollbar value range is min to max-pagestep, so max should be max_lines+1 to allow value max_lines
  PakettiCapture_scrollbar.max = max_lines + 1
  PakettiCapture_scrollbar.value = PakettiCapture_Clamp(song.selected_line_index, 1, max_lines)
end

-- Observers to keep UI synced when user changes pattern/line elsewhere
function PakettiCapture_OnPatternChanged()
  PakettiCapture_UpdateScrollbar()
  PakettiCapture_UpdateUI()
end

function PakettiCapture_OnLineChanged()
  PakettiCapture_UpdateScrollbar()
end

function PakettiCapture_AddObservers()
  if PakettiCapture_observers_active then return end
  local song = renoise.song()
  if song and song.selected_pattern_index_observable then
    if not song.selected_pattern_index_observable:has_notifier(PakettiCapture_OnPatternChanged) then
      song.selected_pattern_index_observable:add_notifier(PakettiCapture_OnPatternChanged)
    end
  end
  PakettiCapture_observers_active = true
  cleanup_observers = PakettiCapture_RemoveObservers
end

function PakettiCapture_RemoveObservers()
  if not PakettiCapture_observers_active then return end
  local song = renoise.song()
  if song and song.selected_pattern_index_observable and song.selected_pattern_index_observable:has_notifier(PakettiCapture_OnPatternChanged) then
    song.selected_pattern_index_observable:remove_notifier(PakettiCapture_OnPatternChanged)
  end
  PakettiCapture_observers_active = false
  cleanup_observers = nil
end

-- Build fixed quick dump buttons (01..16) in rows
function PakettiCapture_BuildQuickDumpButtons()
  local rows = {}
  for i = 1, PakettiCapture_MAX_ROWS do
    local idx = i
    local btn = PakettiCapture_vb:button{
      text = string.format("%02d", i),
      width = 40,
      height = PakettiCapture_BUTTON_HEIGHT,
      active = false,
      notifier = function() PakettiCapture_DumpRowDisplay(idx) end
    }
    PakettiCapture_dump_buttons[i] = btn
    
    local audition_btn = PakettiCapture_vb:button{
      text = "Audition",
      width = 60,
      height = PakettiCapture_BUTTON_HEIGHT,
      active = false,
      notifier = function() PakettiCaptureAuditionToggle(idx) end
    }
    PakettiCapture_audition_buttons[i] = audition_btn
    
    local txt = PakettiCapture_vb:text{ text = "", width = 240, style = "normal" }
    PakettiCapture_rows_text[i] = txt
    local txt_center = PakettiCapture_vb:vertical_aligner{ mode = "center", height = PakettiCapture_BUTTON_HEIGHT, txt }
    table.insert(rows, PakettiCapture_vb:row{ height = PakettiCapture_BUTTON_HEIGHT, btn, audition_btn, txt_center })
  end
  return rows
end

-- Open dialog
function PakettiCaptureLastTakeDialog()
  if PakettiCapture_dialog and PakettiCapture_dialog.visible then
    PakettiCapture_dialog:close()
    PakettiCapture_dialog = nil
  end

  PakettiCapture_vb = renoise.ViewBuilder()

  PakettiCapture_log_view = PakettiCapture_vb:text{
    text = "Current: <empty>",
    width = 200,
    style = "normal"
  }

  -- Build reusable views for rows where we need references
  local current_tf_view = PakettiCapture_vb:text{ text = "", width = 240, style = "normal" }
  PakettiCapture_current_tf = current_tf_view
  local newest_label_view = PakettiCapture_vb:text{ text = "Newest: ", width = 240, style = "normal" }
  PakettiCapture_newest_label = newest_label_view

  -- Create gater UI elements without IDs to avoid conflicts
  PakettiCapture_gater_toggle_button = PakettiCapture_vb:button{
    text = "▴", -- Start collapsed
    width = 22,
    notifier = function()
      PakettiCapture_gater_expanded = not PakettiCapture_gater_expanded
      PakettiCapture_UpdateGaterVisibility()
    end
  }
  
  PakettiCapture_gater_content_column = PakettiCapture_vb:column{
    style = "group",
    margin = 6,
    visible = false, -- Start hidden
    
    -- Include the Paketti Gater dialog content using DRY principle
    PakettiCreateGaterDialogContent(PakettiCapture_vb)
  }

  local content = PakettiCapture_vb:column{
    PakettiCapture_vb:row{
      PakettiCapture_vb:text{text="Captured Last Takes",font="bold",style="strong",width=160},
      PakettiCapture_vb:button{text="Commit Current (Enter)",width=120,notifier=PakettiCapture_CommitCurrent },
      PakettiCapture_vb:button{text="Clear All (Shift-Enter)", width=120, notifier = PakettiCapture_ClearAll },
      PakettiCapture_vb:button{text="Pick up from Pattern (Ctrl-P)", width=150, notifier = PakettiCapture_PickupFromPattern }
    },
    PakettiCapture_vb:row{
      PakettiCapture_vb:checkbox{ value = preferences.pakettiCaptureLastTakeSmartNoteOff.value, notifier = function(value)
        preferences.pakettiCaptureLastTakeSmartNoteOff.value = value
      end },
      PakettiCapture_vb:text{ text = "Smart Note Off on all Note columns above dump line", style = "strong",font="bold" }
    },
    PakettiCapture_vb:row{
      PakettiCapture_vb:text{ text = "Currently Pressed Notes:", width = PakettiCapture_LEFT_LABEL_WIDTH, font="bold", style="strong"},
      current_tf_view
    },
    (PakettiCapture_ExperimentalMIDICaptureDialog) and PakettiCapture_vb:row{
      PakettiCapture_vb:text{ text = "MIDI Device", width = 80, style = "strong", font="bold" },
      PakettiCapture_vb:popup{
        items = renoise.Midi.available_input_devices(),
        value = math.max(1, table.find(renoise.Midi.available_input_devices(), PakettiCapture_SelectedMidiDeviceName or "") or 1),
        width = 200,
        notifier = function(idx)
          local list = renoise.Midi.available_input_devices()
          local name = list[idx]
          PakettiCapture_SelectedMidiDeviceName = name or ""
          if PakettiCapture_midi_listening then
            PakettiCapture_StopMidiListening()
            PakettiCapture_StartMidiListening()
          end
        end
      },
      PakettiCapture_vb:space{ width = PakettiCapture_GAP },
      PakettiCapture_vb:checkbox{
        value = PakettiCapture_midi_listening,
        notifier = function(val)
          if val then PakettiCapture_StartMidiListening() else PakettiCapture_StopMidiListening() end
        end
      },
      PakettiCapture_vb:text{ text = "Listen to MIDI", style = "normal" },
      PakettiCapture_vb:space{ width = PakettiCapture_GAP },
      PakettiGate_ShowUI and PakettiCapture_vb:button{ text = (PakettiGate_listening and "Stop EditStep Gate" or "Start EditStep Gate"), width = 160, notifier = function()
        if PakettiGate_listening then PakettiGate_Stop() else PakettiGate_Start() end
      end } or PakettiCapture_vb:space{ width = 1 }
    } or PakettiCapture_vb:space{ width = 1 },
    PakettiCapture_vb:row{
      PakettiCapture_vb:button{ text = "Dump to Current Row", width = 140, notifier = function()
        PakettiCapture_DumpRowDisplay(#PakettiCapture_sequences)
      end},
      PakettiCapture_vb:button{ text = "Put Audition Slot to Pattern", width = 160, notifier = function()
        PakettiCapture_PutAuditionSlotToPattern()
      end},
      newest_label_view
    },
    PakettiCapture_vb:row{
      PakettiCapture_BuildScrollbar(),
      PakettiCapture_vb:space{ width = PakettiCapture_GAP },
      PakettiCapture_vb:column{
        PakettiCapture_vb:row{ PakettiCapture_vb:text{ text = "Dump stored", width = PakettiCapture_LEFT_LABEL_WIDTH, font="bold",style ="strong"} },
        unpack(PakettiCapture_BuildQuickDumpButtons())
      }
    },
    PakettiCapture_vb:row{
      PakettiCapture_vb:button{ text = "Fit Slots to Pattern", width = 121, notifier = function()
        PakettiCapture_FitSlotsToPattern()
      end },
      PakettiCapture_vb:space{ width = PakettiCapture_GAP },
      PakettiCapture_vb:button{ text = "Alternate Slot Phrasing", width = 140, notifier = function()
        PakettiCapture_AlternatePhrasing()
      end },
      PakettiCapture_vb:space{ width = PakettiCapture_GAP },
      PakettiCapture_vb:button{ text = "Alternate Pattern Phrasing", width = 140, notifier = function()
        PakettiCapture_AlternatePatternPhrasing()
      end },
      PakettiCapture_vb:space{ width = PakettiCapture_GAP },
      PakettiCapture_vb:button{ text = "Close", width = 40, notifier = function()
        PakettiCaptureAuditionStop()  -- Stop any playing audition
        if PakettiCapture_midi_listening then PakettiCapture_StopMidiListening() end
        PakettiGaterCleanupPlayhead()  -- Cleanup gater playhead timer
        if PakettiCapture_dialog and PakettiCapture_dialog.visible then PakettiCapture_dialog:close() end
      end },
      PakettiCapture_vb:space{ width = PakettiCapture_GAP }
    },

    -- Expandable Paketti Gater Section
    PakettiCapture_vb:row{
      PakettiCapture_gater_toggle_button,
      PakettiCapture_vb:text{
        text = "Show Paketti Gater Dialog Content",
        style = "strong",
        font = "bold",
        width = 300
      }
    },

    -- Collapsible Gater Content
    PakettiCapture_gater_content_column

  }
  
  PakettiCapture_dialog = renoise.app():show_custom_dialog("Paketti Capture Last Take", content, PakettiCapture_KeyHandler)
  PakettiCapture_UpdateUI()
  PakettiCapture_AddObservers()

  -- Ensure Renoise keeps focus for keyboard
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Initialize gater section visibility
  PakettiCapture_UpdateGaterVisibility()
  
  -- Show keyboard controls info
  renoise.app():show_status("PakettiCapture: Up/Down arrows=select slot (bold text), SPACE=audition selected, Ctrl+P=pickup from pattern")
end

-- Toggle
function PakettiCaptureLastTakeToggle()
  if PakettiCapture_dialog and PakettiCapture_dialog.visible then
    PakettiCaptureAuditionStop()  -- Stop any playing audition
    if PakettiCapture_midi_listening then PakettiCapture_StopMidiListening() end
    PakettiGaterCleanupPlayhead()  -- Cleanup gater playhead timer
    PakettiCapture_dialog:close()
    PakettiCapture_dialog = nil
  else
    PakettiCaptureLastTakeDialog()
  end
end

-- Menu entries and keybinding
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Gadgets:Paketti Capture Last Take...", invoke = PakettiCaptureLastTakeToggle}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti Gadgets:Paketti Capture Last Take...", invoke = PakettiCaptureLastTakeToggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Capture Last Take...", invoke = PakettiCaptureLastTakeToggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Put Audition Slot to Pattern", invoke = PakettiCapture_PutAuditionSlotToPattern}


