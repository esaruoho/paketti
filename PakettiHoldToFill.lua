-- Paketti: Hold-to-Fill Mode
-- Lua 5.1, global functions only, namespaced per project rules

PakettiHoldToFillKeyHoldStart = nil
PakettiHoldToFillHeldKeyName = nil
PakettiHoldToFillIsFilling = false
PakettiHoldToFillModeDialog = nil
PakettiHoldToFillSawRepeat = false
PakettiHoldToFillIgnoreKeys = {
  tab = true,
  up = true, down = true, left = true, right = true,
  ["<"] = true, [">"] = true
}
PakettiHoldToFillUseEditStep = false

-- MIDI Hold-to-Fill State
PakettiHoldToFill_midi_device = nil
PakettiHoldToFill_midi_listening = false
PakettiHoldToFill_SelectedMidiDeviceName = ""
PakettiHoldToFill_held_notes = {}  -- track which MIDI notes are currently held (note_value -> start_time)
PakettiHoldToFill_held_velocities = {}  -- track velocities for held notes (note_value -> velocity)
PakettiHoldToFill_fill_timers = {}  -- track fill timers for each note
PakettiHoldToFill_EnableMIDI = false  -- checkbox state
PakettiHoldToFill_DontClearColumn = false  -- checkbox state for preserving existing content
PakettiHoldToFill_editstep_valuebox = nil  -- reference to editstep valuebox for updates
PakettiHoldToFill_observers_active = false
PakettiHoldToFill_saved_editstep = nil
PakettiHoldToFill_editstep_temporarily_changed = false  -- store original editstep when note is pressed

-- Mapping of keyboard keys to semitone offsets from C in the current transport octave
-- Same as PakettiCaptureLastTake - includes QWERTY row and bottom piano row
PakettiHoldToFill_note_keymap = {
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

function PakettiHoldToFillResetState()
  PakettiHoldToFillIsFilling = false
  PakettiHoldToFillKeyHoldStart = nil
  PakettiHoldToFillHeldKeyName = nil
  PakettiHoldToFillSawRepeat = false
  -- Clear MIDI state
  PakettiHoldToFill_held_notes = {}
  PakettiHoldToFill_held_velocities = {}
  PakettiHoldToFill_fill_timers = {}
  -- Clear references and observers
  PakettiHoldToFill_editstep_valuebox = nil
  PakettiHoldToFill_RemoveObservers()
  -- Clear temporary EditStep flag and restore EditStep if saved
  PakettiHoldToFill_editstep_temporarily_changed = false
  PakettiHoldToFill_RestoreEditStep()
end

-- Helper: clamp integer
function PakettiHoldToFill_Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Helper: convert 0..119 to note string C-0..B-9
function PakettiHoldToFill_NoteValueToString(value)
  local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
  local v = PakettiHoldToFill_Clamp(value, 0, 119)
  local octave = math.floor(v / 12)
  local name = names[(v % 12) + 1]
  return name .. tostring(octave)
end

-- Helper: convert key.name to note value based on current octave; returns note value or nil
function PakettiHoldToFill_KeyToNoteValue(key_name)
  if not key_name then return nil end
  local offset = PakettiHoldToFill_note_keymap[key_name]
  if offset == nil then return nil end
  local song = renoise.song()
  local base_oct = song.transport.octave or 4
  local key_oct = base_oct + 1 -- z-row is base_oct, q/"," rows are one octave above
  local value = (key_oct * 12) + offset
  if value < 0 then
    value = value + 12 * math.ceil((-value) / 12)
  end
  if value > 119 then return nil end
  value = PakettiHoldToFill_Clamp(value, 0, 119)
  return value
end

-- Helper: temporarily set EditStep to 0 and save original value
function PakettiHoldToFill_SetEditStepToZero()
  local s = renoise.song()
  if s and s.transport then
    PakettiHoldToFill_saved_editstep = s.transport.edit_step
    PakettiHoldToFill_editstep_temporarily_changed = true  -- Flag to ignore observer updates
    s.transport.edit_step = 0
    print("DEBUG: Temporarily set EditStep to 0 (saved: " .. tostring(PakettiHoldToFill_saved_editstep) .. ")")
  end
end

-- Helper: restore original EditStep value
function PakettiHoldToFill_RestoreEditStep()
  local s = renoise.song()
  if s and s.transport and PakettiHoldToFill_saved_editstep ~= nil then
    s.transport.edit_step = PakettiHoldToFill_saved_editstep
    print("DEBUG: Restored EditStep to " .. tostring(PakettiHoldToFill_saved_editstep))
    PakettiHoldToFill_saved_editstep = nil
    PakettiHoldToFill_editstep_temporarily_changed = false  -- Clear flag to resume observer updates
  end
end

-- Helper: get keyboard velocity for note fills
function PakettiHoldToFill_GetKeyboardVelocity()
  local s = renoise.song()
  if s and s.transport and s.transport.keyboard_velocity_enabled then
    return s.transport.keyboard_velocity
  end
  return nil  -- Use default/no velocity
end

-- Helper: clear the selected note column from cursor position downward
function PakettiHoldToFill_ClearSelectedNoteColumn()
  if PakettiHoldToFill_DontClearColumn then 
    return -- Don't clear if checkbox is checked
  end
  
  local s = renoise.song()
  local track_idx = s.selected_track_index
  local line_idx = s.selected_line_index
  local column_idx = s.selected_note_column_index
  
  if track_idx == nil or line_idx == nil or column_idx == nil then return end
  
  local tr = s.tracks[track_idx]
  if tr.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end
  
  if column_idx < 1 then
    if tr.visible_note_columns < 1 then return end
    column_idx = 1
  elseif column_idx > tr.visible_note_columns then
    column_idx = tr.visible_note_columns
  end
  
  local patt_idx = s.selected_pattern_index
  local patt = s.patterns[patt_idx]
  local patt_tr = patt.tracks[track_idx]
  local num_lines = patt.number_of_lines
  
  -- Clear the note column from cursor position downward
  for clear_line_idx = line_idx, num_lines do
    local line = patt_tr.lines[clear_line_idx]
    local col = line.note_columns[column_idx]
    if col then
      col.note_string = ""
      col.instrument_value = 255
      col.volume_value = 255
      col.panning_value = 255
      col.delay_value = 0
    end
  end
  
  print("DEBUG: Cleared note column " .. tostring(column_idx) .. " from line " .. tostring(line_idx) .. " downward")
end

-- MIDI callback for Hold-to-Fill
function PakettiHoldToFill_MidiCallback(message)
  if not message or #message ~= 3 then return end
  if not PakettiHoldToFill_EnableMIDI then return end  -- Only process if MIDI is enabled
  
  local status = message[1]
  local data1 = message[2]
  local data2 = message[3]
  
  -- Note ON (status & 0xF0 == 0x90 and velocity > 0)
  if (bit.band(status, 0xF0) == 0x90) and (data2 and data2 > 0) then
    local note_value = PakettiHoldToFill_Clamp(tonumber(data1) or 0, 0, 119)
    local velocity = PakettiHoldToFill_Clamp(tonumber(data2) or 127, 0, 127)
    print("PakettiHoldToFill MIDI NOTE ON: " .. tostring(note_value) .. " Velocity: " .. tostring(velocity))
    
    -- Start hold-to-fill for this note with velocity
    PakettiHoldToFill_StartMidiNoteFill(note_value, velocity)
    
  -- Note OFF (status & 0xF0 == 0x80 OR status & 0xF0 == 0x90 with velocity 0)
  elseif (bit.band(status, 0xF0) == 0x80) or ((bit.band(status, 0xF0) == 0x90) and (data2 == 0)) then
    local note_value = PakettiHoldToFill_Clamp(tonumber(data1) or 0, 0, 119)
    print("PakettiHoldToFill MIDI NOTE OFF: " .. tostring(note_value))
    
    -- Stop hold-to-fill for this note
    PakettiHoldToFill_StopMidiNoteFill(note_value)
  end
end

-- Start MIDI listening
function PakettiHoldToFill_StartMidiListening()
  if PakettiHoldToFill_midi_listening then return end
  local inputs = renoise.Midi.available_input_devices()
  if not inputs or #inputs == 0 then
    renoise.app():show_status("PakettiHoldToFill: No MIDI input devices available")
    return
  end
  local device_name = PakettiHoldToFill_SelectedMidiDeviceName
  if not device_name or device_name == "" then
    device_name = inputs[1]
  end
  PakettiHoldToFill_midi_device = renoise.Midi.create_input_device(device_name, PakettiHoldToFill_MidiCallback)
  PakettiHoldToFill_midi_listening = true
  renoise.app():show_status("PakettiHoldToFill: Listening to MIDI on " .. tostring(device_name))
end

-- Stop MIDI listening
function PakettiHoldToFill_StopMidiListening()
  if PakettiHoldToFill_midi_device then
    PakettiHoldToFill_midi_device:close()
    PakettiHoldToFill_midi_device = nil
  end
  PakettiHoldToFill_midi_listening = false
  -- Clear all held notes, velocities and timers
  PakettiHoldToFill_held_notes = {}
  PakettiHoldToFill_held_velocities = {}
  for note_value, timer_func in pairs(PakettiHoldToFill_fill_timers) do
    if renoise.tool():has_timer(timer_func) then
      renoise.tool():remove_timer(timer_func)
    end
  end
  PakettiHoldToFill_fill_timers = {}
  renoise.app():show_status("PakettiHoldToFill: Stopped MIDI listening")
end

-- Start keyboard note hold-to-fill (with EditStep management)
function PakettiHoldToFill_StartKeyNoteFill(note_value, key_name)
  local timer_key = "key_" .. tostring(note_value) .. "_" .. tostring(key_name)
  if PakettiHoldToFill_fill_timers[timer_key] then
    return  -- Already holding this key/note combination
  end
  
  -- Set EditStep to 0 so cursor doesn't move when note is played in Renoise
  PakettiHoldToFill_SetEditStepToZero()
  
  local start_time = os.clock()
  
  -- Create a timer function specific to this key/note
  local timer_func = function()
    PakettiHoldToFill_CheckKeyNoteFill(note_value, key_name, timer_key, start_time)
  end
  
  PakettiHoldToFill_fill_timers[timer_key] = timer_func
  renoise.tool():add_timer(timer_func, 50)  -- Check every 50ms
  
  print("PakettiHoldToFill: Started timer for keyboard note " .. tostring(note_value) .. " (key: " .. tostring(key_name) .. ")")
end

-- Start MIDI note hold-to-fill
function PakettiHoldToFill_StartMidiNoteFill(note_value, velocity)
  if PakettiHoldToFill_held_notes[note_value] then
    return  -- Already holding this note
  end
  
  PakettiHoldToFill_held_notes[note_value] = os.clock()
  PakettiHoldToFill_held_velocities[note_value] = velocity or 127
  
  -- Create a timer function specific to this note
  local timer_func = function()
    PakettiHoldToFill_CheckMidiNoteFill(note_value)
  end
  
  PakettiHoldToFill_fill_timers[note_value] = timer_func
  renoise.tool():add_timer(timer_func, 50)  -- Check every 50ms
  
  print("PakettiHoldToFill: Started timer for MIDI note " .. tostring(note_value) .. " velocity " .. tostring(velocity))
end

-- Stop MIDI note hold-to-fill
function PakettiHoldToFill_StopMidiNoteFill(note_value)
  if not PakettiHoldToFill_held_notes[note_value] then
    return  -- Not holding this note
  end
  
  PakettiHoldToFill_held_notes[note_value] = nil
  PakettiHoldToFill_held_velocities[note_value] = nil
  
  local timer_func = PakettiHoldToFill_fill_timers[note_value]
  if timer_func and renoise.tool():has_timer(timer_func) then
    renoise.tool():remove_timer(timer_func)
  end
  PakettiHoldToFill_fill_timers[note_value] = nil
  
  print("PakettiHoldToFill: Stopped timer for MIDI note " .. tostring(note_value))
end

-- Check if keyboard note should trigger fill
function PakettiHoldToFill_CheckKeyNoteFill(note_value, key_name, timer_key, start_time)
  local hold_duration = os.clock() - start_time
  if hold_duration >= 0.25 then
    print("PakettiHoldToFill: Keyboard hold detected for note " .. tostring(note_value) .. " (key: " .. tostring(key_name) .. "). Filling...")
    PakettiHoldToFillPerformFillWithNoteAndVelocity(note_value, PakettiHoldToFill_GetKeyboardVelocity())
    -- Clean up timer and restore EditStep
    local timer_func = PakettiHoldToFill_fill_timers[timer_key]
    if timer_func and renoise.tool():has_timer(timer_func) then
      renoise.tool():remove_timer(timer_func)
    end
    PakettiHoldToFill_fill_timers[timer_key] = nil
    PakettiHoldToFill_RestoreEditStep()
  elseif hold_duration >= 1.0 then
    -- Safety timeout - restore EditStep even if hold-to-fill didn't trigger
    print("PakettiHoldToFill: Safety timeout for keyboard note " .. tostring(note_value) .. " - restoring EditStep")
    local timer_func = PakettiHoldToFill_fill_timers[timer_key]
    if timer_func and renoise.tool():has_timer(timer_func) then
      renoise.tool():remove_timer(timer_func)
    end
    PakettiHoldToFill_fill_timers[timer_key] = nil
    PakettiHoldToFill_RestoreEditStep()
  end
end

-- Check if MIDI note should trigger fill
function PakettiHoldToFill_CheckMidiNoteFill(note_value)
  local start_time = PakettiHoldToFill_held_notes[note_value]
  if not start_time then
    -- Note was released, clean up timer
    local timer_func = PakettiHoldToFill_fill_timers[note_value]
    if timer_func and renoise.tool():has_timer(timer_func) then
      renoise.tool():remove_timer(timer_func)
    end
    PakettiHoldToFill_fill_timers[note_value] = nil
    return
  end
  
  local hold_duration = os.clock() - start_time
  if hold_duration >= 0.25 then
    local velocity = PakettiHoldToFill_held_velocities[note_value] or 127
    print("PakettiHoldToFill: MIDI hold detected for note " .. tostring(note_value) .. ". Filling...")
    PakettiHoldToFillPerformFillWithNoteAndVelocity(note_value, velocity)
    -- Clear the note so we don't fill again
    PakettiHoldToFill_StopMidiNoteFill(note_value)
  end
end

-- Perform fill with specific note value and optional velocity
function PakettiHoldToFillPerformFillWithNoteAndVelocity(note_value, velocity)
  local s = renoise.song()
  local track_idx = s.selected_track_index
  local line_idx = s.selected_line_index
  local column_idx = s.selected_note_column_index

  if track_idx == nil or line_idx == nil or column_idx == nil then
    print("DEBUG: Invalid pattern editor position.")
    return
  end

  local tr = s.tracks[track_idx]
  if tr.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    print("DEBUG: Selected track is not a sequencer track.")
    return
  end

  if column_idx < 1 then
    if tr.visible_note_columns < 1 then
      renoise.app():show_status("PakettiHoldToFill: No visible note columns on this track.")
      return
    end
    s.selected_note_column_index = 1
    column_idx = 1
  elseif column_idx > tr.visible_note_columns then
    print("DEBUG: Column index out of visible range: " .. tostring(column_idx) .. ", clamping to visible range.")
    s.selected_note_column_index = tr.visible_note_columns
    column_idx = tr.visible_note_columns
  end

  -- Clear the note column first (unless "Don't Clear" is checked)
  PakettiHoldToFill_ClearSelectedNoteColumn()

  local patt_idx = s.selected_pattern_index
  local patt = s.patterns[patt_idx]
  local patt_tr = patt.tracks[track_idx]
  local line = patt_tr.lines[line_idx]
  local col = line.note_columns[column_idx]

  -- Place the note on current line
  col.note_value = note_value
  col.instrument_value = s.selected_instrument_index - 1
  
  -- Set velocity if provided
  if velocity and velocity >= 0 and velocity <= 127 then
    col.volume_value = velocity
    print("DEBUG: Filling column with Note Value: " .. tostring(note_value) .. " Velocity: " .. tostring(velocity))
  else
    print("DEBUG: Filling column with Note Value: " .. tostring(note_value))
  end

  local num_lines = patt.number_of_lines
  if PakettiHoldToFillUseEditStep then
    -- Use saved EditStep if available (when temporarily set to 0), otherwise current transport value
    local step = PakettiHoldToFill_saved_editstep or s.transport.edit_step
    if step == nil then step = 1 end
    print("DEBUG: Using EditStep: " .. tostring(step) .. " (saved: " .. tostring(PakettiHoldToFill_saved_editstep) .. ", transport: " .. tostring(s.transport.edit_step) .. ")")
    -- EditStep 0 means "no advancement" - treat as fill every line
    if step == 0 then
      for i = (line_idx + 1), num_lines do
        local tline = patt_tr.lines[i]
        local tcol = tline.note_columns[column_idx]
        if tcol then
          tcol.note_value = note_value
          tcol.instrument_value = s.selected_instrument_index - 1
          if velocity and velocity >= 0 and velocity <= 127 then
            tcol.volume_value = velocity
          end
        end
      end
    else
      for i = (line_idx + step), num_lines, step do
        local tline = patt_tr.lines[i]
        local tcol = tline.note_columns[column_idx]
        if tcol then
          tcol.note_value = note_value
          tcol.instrument_value = s.selected_instrument_index - 1
          if velocity and velocity >= 0 and velocity <= 127 then
            tcol.volume_value = velocity
          end
        end
      end
    end
  else
    for i = (line_idx + 1), num_lines do
      local tline = patt_tr.lines[i]
      local tcol = tline.note_columns[column_idx]
      if tcol then
        tcol.note_value = note_value
        tcol.instrument_value = s.selected_instrument_index - 1
        if velocity and velocity >= 0 and velocity <= 127 then
          tcol.volume_value = velocity
        end
      end
    end
  end
  print("DEBUG: Fill complete.")
end

-- Legacy function for backward compatibility
function PakettiHoldToFillPerformFillWithNote(note_value)
  PakettiHoldToFillPerformFillWithNoteAndVelocity(note_value, nil)
end

function PakettiHoldToFillPerformFill()
  local s = renoise.song()
  local track_idx = s.selected_track_index
  local line_idx = s.selected_line_index
  local column_idx = s.selected_note_column_index

  if track_idx == nil or line_idx == nil or column_idx == nil then
    print("DEBUG: Invalid pattern editor position.")
    return
  end

  local tr = s.tracks[track_idx]
  if tr.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    print("DEBUG: Selected track is not a sequencer track.")
    return
  end

  if column_idx < 1 then
    if tr.visible_note_columns < 1 then
      renoise.app():show_status("Paketti Hold-to-Fill: No visible note columns on this track.")
      return
    end
    s.selected_note_column_index = 1
    column_idx = 1
  elseif column_idx > tr.visible_note_columns then
    print("DEBUG: Column index out of visible range: " .. tostring(column_idx) .. ", clamping to visible range.")
    s.selected_note_column_index = tr.visible_note_columns
    column_idx = tr.visible_note_columns
  end

  local patt_idx = s.selected_pattern_index
  local patt = s.patterns[patt_idx]
  local patt_tr = patt.tracks[track_idx]
  local line = patt_tr.lines[line_idx]
  local col = line.note_columns[column_idx]

  local note_value = nil
  local instrument_value = nil
  local volume_value = nil
  local panning_value = nil
  local delay_value = nil

  if not col.is_empty then
    note_value = col.note_value
    instrument_value = col.instrument_value
    volume_value = col.volume_value
    panning_value = col.panning_value
    delay_value = col.delay_value
  else
    -- Search upwards for the nearest non-empty note in the same column
    local found_up = false
    for up = (line_idx - 1), 1, -1 do
      local uline = patt_tr.lines[up]
      local ucol = uline.note_columns[column_idx]
      if ucol and (not ucol.is_empty) then
        note_value = ucol.note_value
        instrument_value = ucol.instrument_value
        volume_value = ucol.volume_value
        panning_value = ucol.panning_value
        delay_value = ucol.delay_value
        found_up = true
        break
      end
    end
    if not found_up then
      -- Search downwards if nothing above
      for down = (line_idx + 1), patt.number_of_lines do
        local dline = patt_tr.lines[down]
        local dcol = dline.note_columns[column_idx]
        if dcol and (not dcol.is_empty) then
          note_value = dcol.note_value
          instrument_value = dcol.instrument_value
          volume_value = dcol.volume_value
          panning_value = dcol.panning_value
          delay_value = dcol.delay_value
          found_up = true
          break
        end
      end
    end
    if not found_up then
      print("DEBUG: No source note found above/below; cannot fill.")
      renoise.app():show_status("Paketti Hold-to-Fill: No note found in this column to copy.")
      return
    end
  end

  -- Clear the note column first (unless "Don't Clear" is checked)
  PakettiHoldToFill_ClearSelectedNoteColumn()

  print("DEBUG: Filling column with Note Value: " .. tostring(note_value))

  -- After clearing, place the source note at current line first
  col.note_value = note_value
  col.instrument_value = instrument_value
  col.volume_value = volume_value
  col.panning_value = panning_value
  col.delay_value = delay_value

  local num_lines = patt.number_of_lines
  if PakettiHoldToFillUseEditStep then
    -- Use saved EditStep if available (when temporarily set to 0), otherwise current transport value
    local step = PakettiHoldToFill_saved_editstep or s.transport.edit_step
    if step == nil then step = 1 end
    print("DEBUG: Using EditStep: " .. tostring(step) .. " (saved: " .. tostring(PakettiHoldToFill_saved_editstep) .. ", transport: " .. tostring(s.transport.edit_step) .. ")")
    -- EditStep 0 means "no advancement" - treat as fill every line
    if step == 0 then
      for i = (line_idx + 1), num_lines do
        local tline = patt_tr.lines[i]
        local tcol = tline.note_columns[column_idx]
        if tcol then
          tcol.note_value = note_value
          tcol.instrument_value = instrument_value
          tcol.volume_value = volume_value
          tcol.panning_value = panning_value
          tcol.delay_value = delay_value
        end
      end
    else
      for i = (line_idx + step), num_lines, step do
        local tline = patt_tr.lines[i]
        local tcol = tline.note_columns[column_idx]
        if tcol then
          tcol.note_value = note_value
          tcol.instrument_value = instrument_value
          tcol.volume_value = volume_value
          tcol.panning_value = panning_value
          tcol.delay_value = delay_value
        end
      end
    end
  else
    for i = (line_idx + 1), num_lines do
      local tline = patt_tr.lines[i]
      local tcol = tline.note_columns[column_idx]
      if tcol then
        tcol.note_value = note_value
        tcol.instrument_value = instrument_value
        tcol.volume_value = volume_value
        tcol.panning_value = panning_value
        tcol.delay_value = delay_value
      end
    end
  end
  print("DEBUG: Filling complete.")
end

-- Ensure we never keep a MIDI listener running when dialog is not open
function PakettiHoldToFill_IdleCheck()
  if PakettiHoldToFill_midi_listening then
    if not (PakettiHoldToFillModeDialog and PakettiHoldToFillModeDialog.visible) then
      PakettiHoldToFill_StopMidiListening()
    end
  end
end

-- Safety: stop MIDI listener when tool is unloaded/reloaded
if renoise.tool().app_release_document_observable then
  if not renoise.tool().app_release_document_observable:has_notifier(function()
    if PakettiHoldToFill_midi_listening then PakettiHoldToFill_StopMidiListening() end
  end) then
    renoise.tool().app_release_document_observable:add_notifier(function()
      if PakettiHoldToFill_midi_listening then PakettiHoldToFill_StopMidiListening() end
    end)
  end
end

-- Add an idle notifier to enforce the listener-while-closed rule
if renoise.tool().app_idle_observable then
  if not renoise.tool().app_idle_observable:has_notifier(PakettiHoldToFill_IdleCheck) then
    renoise.tool().app_idle_observable:add_notifier(PakettiHoldToFill_IdleCheck)
  end
end

-- Observer for editstep changes
function PakettiHoldToFill_OnEditStepChanged()
  print("DEBUG: EditStep observer triggered! Valuebox exists: " .. tostring(PakettiHoldToFill_editstep_valuebox ~= nil) .. " Temporarily changed: " .. tostring(PakettiHoldToFill_editstep_temporarily_changed))
  
  -- Ignore observer updates during temporary EditStep changes (during fill operations)
  if PakettiHoldToFill_editstep_temporarily_changed then
    print("DEBUG: EditStep observer - ignoring update during temporary change")
    return
  end
  
  if PakettiHoldToFill_editstep_valuebox then
    local song = renoise.song()
    if song and song.transport then
      local current_editstep = song.transport.edit_step or 1
      local old_value = PakettiHoldToFill_editstep_valuebox.value
      PakettiHoldToFill_editstep_valuebox.value = current_editstep
      print("DEBUG: EditStep observer updated valuebox from " .. tostring(old_value) .. " to: " .. tostring(current_editstep))
    else
      print("DEBUG: EditStep observer - no song or transport")
    end
  else
    print("DEBUG: EditStep observer - valuebox reference is nil!")
  end
end

function PakettiHoldToFill_AddObservers()
  if PakettiHoldToFill_observers_active then 
    print("DEBUG: Observers already active - skipping add")
    return 
  end
  local song = renoise.song()
  print("DEBUG: Adding EditStep observer...")
  print("DEBUG: Valuebox reference exists: " .. tostring(PakettiHoldToFill_editstep_valuebox ~= nil))
  
  if song and song.transport and song.transport.edit_step_observable then
    song.transport.edit_step_observable:add_notifier(PakettiHoldToFill_OnEditStepChanged)
    print("DEBUG: EditStep observer added successfully to song.transport.edit_step_observable")
    -- Test the observer by manually calling it once to sync initial value
    print("DEBUG: Testing observer with manual call...")
    PakettiHoldToFill_OnEditStepChanged()
  else
    print("DEBUG: Cannot add EditStep observer - missing observable")
    if not song then print("DEBUG: No song") end
    if song and not song.transport then print("DEBUG: No transport") end
    if song and song.transport and not song.transport.edit_step_observable then print("DEBUG: No edit_step_observable") end
  end
  PakettiHoldToFill_observers_active = true
  print("DEBUG: Observer system marked as active")
end

function PakettiHoldToFill_RemoveObservers()
  if not PakettiHoldToFill_observers_active then 
    print("DEBUG: Observers not active - skipping remove")
    return 
  end
  print("DEBUG: Removing EditStep observer...")
  local song = renoise.song()
  if song and song.transport and song.transport.edit_step_observable then
    if song.transport.edit_step_observable:has_notifier(PakettiHoldToFill_OnEditStepChanged) then
      song.transport.edit_step_observable:remove_notifier(PakettiHoldToFill_OnEditStepChanged)
      print("DEBUG: EditStep observer removed successfully")
    else
      print("DEBUG: EditStep observer was not attached")
    end
  else
    print("DEBUG: Cannot remove EditStep observer - missing observable")
  end
  PakettiHoldToFill_observers_active = false
  print("DEBUG: Observer system marked as inactive")
end

function PakettiHoldToFillCheckTimer()
  if not (PakettiHoldToFillModeDialog and PakettiHoldToFillModeDialog.visible) then
    if renoise.tool():has_timer(PakettiHoldToFillCheckTimer) then
      renoise.tool():remove_timer(PakettiHoldToFillCheckTimer)
    end
    PakettiHoldToFillModeDialog = nil
    PakettiHoldToFillResetState()  -- This will clean up observers too
    return
  end

  if not PakettiHoldToFillKeyHoldStart or not PakettiHoldToFillHeldKeyName then
    --print("DEBUG: Timer running, but no key is being held.")
    return
  end

  local hold_duration = os.clock() - PakettiHoldToFillKeyHoldStart
  if (hold_duration >= 0.125) and (not PakettiHoldToFillIsFilling) then
    print("DEBUG: Hold detected. Filling column...")
    PakettiHoldToFillIsFilling = true
    PakettiHoldToFillPerformFill()
    -- Reset only the immediate hold state, not the entire dialog state
    PakettiHoldToFillIsFilling = false
    PakettiHoldToFillKeyHoldStart = nil
    PakettiHoldToFillHeldKeyName = nil
    PakettiHoldToFillSawRepeat = false
  end
end

function PakettiHoldToFillKeyHandler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  print("KEYHANDLER DEBUG (HoldToFill): name:'" .. tostring(key.name) .. "' modifiers:'" .. tostring(key.modifiers) .. "' repeated:'" .. tostring(key.repeated) .. "'")

  -- Close dialog with configured key
  if key.modifiers == "" and key.name == closer then
    if renoise.tool():has_timer(PakettiHoldToFillCheckTimer) then
      renoise.tool():remove_timer(PakettiHoldToFillCheckTimer)
    end
    PakettiHoldToFillModeDialog = nil
    return my_keyhandler_func(dialog, key)
  end

  -- Ignore key repeat events; only initial press starts the hold window
  if key.repeated then
    return nil
  end

  -- Check if this key maps to a note (only when no modifiers are pressed)
  if key.modifiers == "" then
    local note_value = PakettiHoldToFill_KeyToNoteValue(key.name)
    if note_value then
      print("DEBUG: Note key pressed: " .. tostring(key.name) .. " -> note value: " .. tostring(note_value))
      -- Start hold-to-fill for this note value
      PakettiHoldToFill_StartKeyNoteFill(note_value, key.name)
      return key -- pass through to Renoise
    end
  else
    print("DEBUG: Key with modifiers ignored for note mapping: " .. tostring(key.name) .. " + " .. tostring(key.modifiers))
  end

  -- Ignore navigation keys
  if PakettiHoldToFillIgnoreKeys[key.name] then
    return key
  end

  -- For non-note keys, still do old behavior (copy existing note from column)
  PakettiHoldToFillKeyHoldStart = os.clock()
  PakettiHoldToFillHeldKeyName = key.name
  print("DEBUG: Non-note key pressed. name:" .. tostring(key.name) .. " Start Time:" .. tostring(PakettiHoldToFillKeyHoldStart))
  PakettiHoldToFillSawRepeat = false

  return key
end

function PakettiHoldToFillShowDialog()
  if PakettiHoldToFillModeDialog and PakettiHoldToFillModeDialog.visible then
    PakettiHoldToFillModeDialog:close()
    if renoise.tool():has_timer(PakettiHoldToFillCheckTimer) then
      renoise.tool():remove_timer(PakettiHoldToFillCheckTimer)
    end
    if PakettiHoldToFill_midi_listening then PakettiHoldToFill_StopMidiListening() end
    PakettiHoldToFillModeDialog = nil
    PakettiHoldToFillResetState()
    renoise.app():show_status("Paketti: Hold-to-Fill Mode disabled")
    print("DEBUG: Dialog already open. Closing.")
    return
  end

  local vb = renoise.ViewBuilder()
  local s = renoise.song()
  local current_edit_step = 1
  if s and s.transport and type(s.transport.edit_step) == "number" then
    current_edit_step = s.transport.edit_step
  end

  -- Create editstep valuebox and store reference for observer updates
  local editstep_valuebox = vb:valuebox {
    min = 0,  -- EditStep 0 is valid in Renoise (means "no advancement")
    max = 64,
    value = current_edit_step,
    width = 60,
    notifier = function(val)
      local song = renoise.song()
      if song and song.transport then
        song.transport.edit_step = val
        print("DEBUG: Edit step set to: " .. tostring(val) .. (val == 0 and " (no advancement)" or ""))
      end
    end
  }
  PakettiHoldToFill_editstep_valuebox = editstep_valuebox

  local view = vb:column {
    
    -- EditStep controls
    vb:row {
      vb:checkbox {
        value = PakettiHoldToFillUseEditStep,
        notifier = function(val)
          PakettiHoldToFillUseEditStep = val
          print("DEBUG: Fill by edit step set to: " .. tostring(PakettiHoldToFillUseEditStep))
        end
      },
      vb:text { text = "Fill by EditStep ", width = 100,style="strong",font="bold" },
      editstep_valuebox
    },
    
    vb:row {
      vb:checkbox {
        value = PakettiHoldToFill_DontClearColumn,
        notifier = function(val)
          PakettiHoldToFill_DontClearColumn = val
          print("DEBUG: Don't clear column: " .. tostring(PakettiHoldToFill_DontClearColumn))
        end
      },
      vb:text { text = "Don't Clear Column Before Fill", style = "strong",font="bold" }
    },
    --vb:space { height = 8 },
    
    -- MIDI input controls
    vb:row {
      vb:checkbox {
        value = PakettiHoldToFill_EnableMIDI,
        notifier = function(val)
          PakettiHoldToFill_EnableMIDI = val
          if val and not PakettiHoldToFill_midi_listening then
            PakettiHoldToFill_StartMidiListening()
          elseif not val and PakettiHoldToFill_midi_listening then
            PakettiHoldToFill_StopMidiListening()
          end
          print("DEBUG: MIDI input enabled: " .. tostring(PakettiHoldToFill_EnableMIDI))
        end
      },
      vb:text { text = "Enable MIDI Input", style = "strong",font="bold" }
    },
    
    vb:row {
      vb:text { text = "MIDI Device", width = 80,style="strong",font="bold" },
      vb:popup {
        items = renoise.Midi.available_input_devices(),
        value = math.max(1, table.find(renoise.Midi.available_input_devices(), PakettiHoldToFill_SelectedMidiDeviceName or "") or 1),
        width = 220,
        notifier = function(idx)
          local list = renoise.Midi.available_input_devices()
          local name = list[idx]
          PakettiHoldToFill_SelectedMidiDeviceName = name or ""
          if PakettiHoldToFill_midi_listening then
            PakettiHoldToFill_StopMidiListening()
            if PakettiHoldToFill_EnableMIDI then
              PakettiHoldToFill_StartMidiListening()
            end
          end
        end
      }
    }
  }
  
  PakettiHoldToFillModeDialog = renoise.app():show_custom_dialog("Paketti Hold-to-Fill Mode", view, PakettiHoldToFillKeyHandler)
  renoise.tool():add_timer(PakettiHoldToFillCheckTimer, 50)
  local amf = renoise.app().window.active_middle_frame
  renoise.app().window.active_middle_frame = amf
  
  -- Clear state but preserve valuebox reference for observers
  PakettiHoldToFillIsFilling = false
  PakettiHoldToFillKeyHoldStart = nil
  PakettiHoldToFillHeldKeyName = nil
  PakettiHoldToFillSawRepeat = false
  PakettiHoldToFill_held_notes = {}
  PakettiHoldToFill_held_velocities = {}
  PakettiHoldToFill_fill_timers = {}
  
  -- Force observer setup for dialog (ignore active flag since we just reset)
  PakettiHoldToFill_observers_active = false  -- Reset flag to ensure clean setup
  PakettiHoldToFill_AddObservers()  -- Add observers to keep editstep valuebox in sync
  renoise.app():show_status("Paketti: Hold-to-Fill Mode enabled")
  print("DEBUG: Dialog opened. Timer started.")
end

renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Paketti:Pattern Editor:Toggle OctaMED Hold-to-Fill Mode", invoke = function() PakettiHoldToFillShowDialog() end }
renoise.tool():add_menu_entry{ name = "--Pattern Editor:Paketti:Other Trackers:Toggle OctaMED Hold-to-Fill Mode", invoke = function() PakettiHoldToFillShowDialog() end }
renoise.tool():add_menu_entry{ name = "--Pattern Editor:Paketti Gadgets:OctaMED Hold-to-Fill...", invoke = function() PakettiHoldToFillShowDialog() end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Toggle OctaMED Hold-to-Fill Mode", invoke = function() PakettiHoldToFillShowDialog() end }


