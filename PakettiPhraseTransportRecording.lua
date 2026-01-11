-- PakettiPhraseTransportRecording.lua
-- Live Phrase Recording System for Paketti
-- Implements MIDI/keyboard note recording directly into phrases
-- Lua 5.1, global functions only

--------------------------------------------------------------------------------
-- STATE MACHINE
--------------------------------------------------------------------------------

-- State constants
PakettiPhraseRec_STATE_IDLE = 1
PakettiPhraseRec_STATE_ARMED = 2
PakettiPhraseRec_STATE_RECORDING_PENDING = 3
PakettiPhraseRec_STATE_RECORDING_ACTIVE = 4

-- Current state
PakettiPhraseRec_CurrentState = PakettiPhraseRec_STATE_IDLE

-- MIDI Device State
PakettiPhraseRec_MidiDevice = nil
PakettiPhraseRec_MidiDeviceName = ""
PakettiPhraseRec_MidiInterceptEnabled = true  -- When true, MIDI goes to phrase; when false, pass-through

-- Pending Note Buffer (deferred write model)
PakettiPhraseRec_PendingNotes = {}  -- {note_value, velocity, target_line, channel, timestamp}
PakettiPhraseRec_ActiveNotes = {}   -- Track active notes for note-off handling {note_value -> start_line}

-- Quantization Settings
PakettiPhraseRec_QuantizeEnabled = true
PakettiPhraseRec_QuantizeGrid = 4  -- 0=OFF, 1, 2, 3, 4, 6, 8, 12, 16

-- Pre-count Settings
PakettiPhraseRec_PreCountBars = 1
PakettiPhraseRec_PreCountActive = false
PakettiPhraseRec_PreCountBeatsRemaining = 0

-- Click during playback
PakettiPhraseRec_ClickDuringPlayback = false

-- Recording start info
PakettiPhraseRec_RecordStartTime = 0
PakettiPhraseRec_RecordStartLine = 1

-- Dialog reference
PakettiPhraseRec_Dialog = nil
PakettiPhraseRec_Vb = nil

-- Debug flag
PakettiPhraseRec_DEBUG = false

-- Keyboard note tracking
PakettiPhraseRec_KeyboardNotes = {}  -- key_name -> {note_value, start_time, last_seen}
PakettiPhraseRec_KeyboardNoteOffTimeout = 0.15  -- seconds - if no key repeat within this time, consider released
PakettiPhraseRec_KeyboardWriteNoteOffs = false  -- Set to true to write note-offs for keyboard (MIDI recommended)

-- Note keymap (same as other Paketti tools for consistency)
PakettiPhraseRec_NoteKeymap = {
  q = 0,  ["2"] = 1,  w = 2,  ["3"] = 3,  e = 4,
  r = 5,  ["5"] = 6,  t = 7,  ["6"] = 8,  y = 9,
  ["7"] = 10, u = 11,
  i = 12, ["9"] = 13, o = 14, ["0"] = 15, p = 16, 
  z = -12, s = -11, x = -10, d = -9,  c = -8,
  v = -7,  g = -6,  b = -5,  h = -4,  n = -3,
  j = -2,  m = -1,
  [","] = 0, ["comma"] = 0, l = 1,  ["."] = 2, ["period"] = 2,
  ["-"] = 4, ["minus"] = 4, ["hyphen"] = 4
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

function PakettiPhraseRec_Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function PakettiPhraseRec_NoteValueToString(value)
  local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
  local v = PakettiPhraseRec_Clamp(value, 0, 119)
  local octave = math.floor(v / 12)
  local name = names[(v % 12) + 1]
  return name .. tostring(octave)
end

function PakettiPhraseRec_GetStateName(state)
  if state == PakettiPhraseRec_STATE_IDLE then return "IDLE"
  elseif state == PakettiPhraseRec_STATE_ARMED then return "ARMED"
  elseif state == PakettiPhraseRec_STATE_RECORDING_PENDING then return "RECORDING_PENDING"
  elseif state == PakettiPhraseRec_STATE_RECORDING_ACTIVE then return "RECORDING_ACTIVE"
  else return "UNKNOWN"
  end
end

function PakettiPhraseRec_Log(msg)
  if PakettiPhraseRec_DEBUG then
    print("PakettiPhraseRec: " .. tostring(msg))
  end
end

--------------------------------------------------------------------------------
-- PHRASE EDITOR FOCUS DETECTION
--------------------------------------------------------------------------------

function PakettiPhraseRec_IsPhraseEditorActive()
  local window = renoise.app().window
  return window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
end

function PakettiPhraseRec_GetSelectedPhrase()
  local song = renoise.song()
  if not song then return nil end
  return song.selected_phrase
end

--------------------------------------------------------------------------------
-- QUANTIZATION ENGINE
--------------------------------------------------------------------------------

function PakettiPhraseRec_QuantizeLine(raw_line, phrase_length)
  if not PakettiPhraseRec_QuantizeEnabled or PakettiPhraseRec_QuantizeGrid == 0 then
    return raw_line
  end
  
  local grid = PakettiPhraseRec_QuantizeGrid
  -- Round to nearest grid line
  local quantized = math.floor((raw_line - 1) / grid + 0.5) * grid + 1
  
  -- Wrap within phrase length
  if quantized > phrase_length then
    quantized = ((quantized - 1) % phrase_length) + 1
  end
  if quantized < 1 then
    quantized = 1
  end
  
  return quantized
end

function PakettiPhraseRec_GetCurrentPhraseLine()
  -- Use existing PhraseTransport function if available for consistency
  if PakettiPhraseTransportGetPhraseLine then
    local song = renoise.song()
    if song and song.selected_phrase then
      return PakettiPhraseTransportGetPhraseLine(song.selected_phrase)
    end
  end
  
  -- Fallback implementation
  local song = renoise.song()
  if not song then return 1 end
  
  local phrase = song.selected_phrase
  if not phrase then return 1 end
  
  local transport = song.transport
  if not transport.playing then return 1 end
  
  local playback_pos = transport.playback_pos
  local lpb = transport.lpb
  local phrase_lpb = phrase.lpb
  local phrase_length = phrase.number_of_lines
  
  -- Calculate global beat position
  local global_beat = (playback_pos.line - 1) / lpb
  
  -- Apply armed offset if PhraseTransport offset is set
  if PakettiPhraseTransportArmedOffset then
    local offset_beats = PakettiPhraseTransportArmedOffset / phrase_lpb
    global_beat = global_beat + offset_beats
  end
  
  -- Calculate phrase line position (1-based)
  local phrase_line = math.floor((global_beat * phrase_lpb) % phrase_length) + 1
  
  return phrase_line
end

--------------------------------------------------------------------------------
-- NOTE WRITING ENGINE
--------------------------------------------------------------------------------

function PakettiPhraseRec_FindFreeNoteColumn(phrase, line_index)
  local line = phrase:line(line_index)
  local note_columns = line.note_columns
  
  for col_idx = 1, phrase.visible_note_columns do
    local col = note_columns[col_idx]
    if col.note_value == 121 then  -- 121 = empty
      return col_idx
    end
  end
  
  -- All columns occupied, use first column (overwrite)
  return 1
end

function PakettiPhraseRec_WriteNoteToPhrase(note_value, velocity, line_index, is_note_off)
  local song = renoise.song()
  if not song then return false end
  
  local phrase = song.selected_phrase
  if not phrase then return false end
  
  -- Clamp line index to phrase length
  line_index = PakettiPhraseRec_Clamp(line_index, 1, phrase.number_of_lines)
  
  local line = phrase:line(line_index)
  local col_idx = PakettiPhraseRec_FindFreeNoteColumn(phrase, line_index)
  local col = line.note_columns[col_idx]
  
  if is_note_off then
    col.note_value = 120  -- OFF
    col.instrument_value = 255
    col.volume_value = 255
    PakettiPhraseRec_Log("Wrote NOTE-OFF at line " .. tostring(line_index) .. " col " .. tostring(col_idx))
  else
    col.note_value = note_value
    col.instrument_value = song.selected_instrument_index - 1
    if velocity and velocity > 0 and velocity < 128 then
      col.volume_value = velocity
    else
      col.volume_value = 255  -- Default/empty
    end
    PakettiPhraseRec_Log("Wrote note " .. PakettiPhraseRec_NoteValueToString(note_value) .. 
                         " vel=" .. tostring(velocity) .. 
                         " at line " .. tostring(line_index) .. " col " .. tostring(col_idx))
  end
  
  return true
end

function PakettiPhraseRec_ProcessPendingNotes()
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_RECORDING_ACTIVE then
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  local phrase = song.selected_phrase
  if not phrase then return end
  
  local current_line = PakettiPhraseRec_GetCurrentPhraseLine()
  
  -- Process pending notes that should be written now
  local notes_to_remove = {}
  
  for i, pending in ipairs(PakettiPhraseRec_PendingNotes) do
    if pending.target_line <= current_line or 
       (pending.target_line > current_line + phrase.number_of_lines / 2) then
      -- Write the note
      PakettiPhraseRec_WriteNoteToPhrase(
        pending.note_value, 
        pending.velocity, 
        pending.target_line, 
        pending.is_note_off
      )
      table.insert(notes_to_remove, i)
    end
  end
  
  -- Remove processed notes (in reverse order to maintain indices)
  for i = #notes_to_remove, 1, -1 do
    table.remove(PakettiPhraseRec_PendingNotes, notes_to_remove[i])
  end
end

--------------------------------------------------------------------------------
-- MIDI INPUT HANDLING
--------------------------------------------------------------------------------

function PakettiPhraseRec_MidiCallback(message)
  if not message or #message < 2 then return end
  if not PakettiPhraseRec_MidiInterceptEnabled then return end
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_RECORDING_ACTIVE then return end
  
  local status = message[1]
  local data1 = message[2]
  local data2 = message[3] or 0
  
  local channel = bit.band(status, 0x0F) + 1
  local msg_type = bit.band(status, 0xF0)
  
  -- Note ON (0x90 with velocity > 0)
  if msg_type == 0x90 and data2 > 0 then
    local note_value = PakettiPhraseRec_Clamp(data1, 0, 119)
    local velocity = PakettiPhraseRec_Clamp(data2, 0, 127)
    
    PakettiPhraseRec_Log("MIDI Note ON: " .. PakettiPhraseRec_NoteValueToString(note_value) .. 
                         " vel=" .. tostring(velocity) .. " ch=" .. tostring(channel))
    
    PakettiPhraseRec_HandleNoteOn(note_value, velocity, channel)
    
  -- Note OFF (0x80 or 0x90 with velocity 0)
  elseif msg_type == 0x80 or (msg_type == 0x90 and data2 == 0) then
    local note_value = PakettiPhraseRec_Clamp(data1, 0, 119)
    
    PakettiPhraseRec_Log("MIDI Note OFF: " .. PakettiPhraseRec_NoteValueToString(note_value))
    
    PakettiPhraseRec_HandleNoteOff(note_value, channel)
  end
end

function PakettiPhraseRec_StartMidiListening()
  if PakettiPhraseRec_MidiDevice then
    PakettiPhraseRec_StopMidiListening()
  end
  
  local inputs = renoise.Midi.available_input_devices()
  if not inputs or #inputs == 0 then
    renoise.app():show_status("PakettiPhraseRec: No MIDI input devices available")
    return false
  end
  
  local device_name = PakettiPhraseRec_MidiDeviceName
  if not device_name or device_name == "" then
    device_name = inputs[1]
    PakettiPhraseRec_MidiDeviceName = device_name
  end
  
  local success, err = pcall(function()
    PakettiPhraseRec_MidiDevice = renoise.Midi.create_input_device(
      device_name, 
      PakettiPhraseRec_MidiCallback
    )
  end)
  
  if not success then
    renoise.app():show_status("PakettiPhraseRec: Failed to open MIDI device: " .. tostring(device_name))
    return false
  end
  
  PakettiPhraseRec_Log("Started MIDI listening on: " .. tostring(device_name))
  return true
end

function PakettiPhraseRec_StopMidiListening()
  if PakettiPhraseRec_MidiDevice then
    if PakettiPhraseRec_MidiDevice.is_open then
      PakettiPhraseRec_MidiDevice:close()
    end
    PakettiPhraseRec_MidiDevice = nil
  end
  PakettiPhraseRec_Log("Stopped MIDI listening")
end

--------------------------------------------------------------------------------
-- NOTE ON/OFF HANDLING (SHARED BY MIDI AND KEYBOARD)
--------------------------------------------------------------------------------

function PakettiPhraseRec_HandleNoteOn(note_value, velocity, channel)
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_RECORDING_ACTIVE then
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  local phrase = song.selected_phrase
  if not phrase then return end
  
  -- Calculate target line with quantization
  local raw_line = PakettiPhraseRec_GetCurrentPhraseLine()
  local target_line = PakettiPhraseRec_QuantizeLine(raw_line, phrase.number_of_lines)
  
  -- Track active note for note-off handling
  PakettiPhraseRec_ActiveNotes[note_value] = target_line
  
  -- Add to pending buffer
  table.insert(PakettiPhraseRec_PendingNotes, {
    note_value = note_value,
    velocity = velocity,
    target_line = target_line,
    channel = channel or 1,
    timestamp = os.clock(),
    is_note_off = false
  })
  
  PakettiPhraseRec_Log("Queued note ON: " .. PakettiPhraseRec_NoteValueToString(note_value) .. 
                       " target line " .. tostring(target_line))
end

function PakettiPhraseRec_HandleNoteOff(note_value, channel)
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_RECORDING_ACTIVE then
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  local phrase = song.selected_phrase
  if not phrase then return end
  
  -- Get current line for note-off
  local raw_line = PakettiPhraseRec_GetCurrentPhraseLine()
  local target_line = PakettiPhraseRec_QuantizeLine(raw_line, phrase.number_of_lines)
  
  -- Clear active note tracking
  PakettiPhraseRec_ActiveNotes[note_value] = nil
  
  -- Add note-off to pending buffer
  table.insert(PakettiPhraseRec_PendingNotes, {
    note_value = note_value,
    velocity = 0,
    target_line = target_line,
    channel = channel or 1,
    timestamp = os.clock(),
    is_note_off = true
  })
  
  PakettiPhraseRec_Log("Queued note OFF: " .. PakettiPhraseRec_NoteValueToString(note_value) .. 
                       " target line " .. tostring(target_line))
end

--------------------------------------------------------------------------------
-- KEYBOARD INPUT HANDLING
--------------------------------------------------------------------------------

function PakettiPhraseRec_KeyToNoteValue(key_name)
  if not key_name then return nil end
  local offset = PakettiPhraseRec_NoteKeymap[key_name]
  if offset == nil then return nil end
  
  local song = renoise.song()
  if not song then return nil end
  
  local base_oct = song.transport.octave or 4
  local key_oct = base_oct + 1
  local value = (key_oct * 12) + offset
  
  if value < 0 then
    value = value + 12 * math.ceil((-value) / 12)
  end
  if value > 119 then return nil end
  
  return PakettiPhraseRec_Clamp(value, 0, 119)
end

function PakettiPhraseRec_GetKeyboardVelocity()
  local song = renoise.song()
  if song and song.transport and song.transport.keyboard_velocity_enabled then
    return song.transport.keyboard_velocity
  end
  return 127  -- Default velocity
end

function PakettiPhraseRec_KeyHandler(dialog, key)
  -- Only handle keys when recording is active and phrase editor is focused
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_RECORDING_ACTIVE then
    return key
  end
  
  if not PakettiPhraseRec_IsPhraseEditorActive() then
    return key
  end
  
  local key_name = key.name
  local note_value = PakettiPhraseRec_KeyToNoteValue(key_name)
  
  if note_value then
    local current_time = os.clock()
    
    if key.repeated then
      -- Key is being held - update last_seen time
      if PakettiPhraseRec_KeyboardNotes[key_name] then
        PakettiPhraseRec_KeyboardNotes[key_name].last_seen = current_time
      end
    else
      -- Key pressed (note on)
      if not PakettiPhraseRec_KeyboardNotes[key_name] then
        local velocity = PakettiPhraseRec_GetKeyboardVelocity()
        PakettiPhraseRec_KeyboardNotes[key_name] = {
          note_value = note_value,
          start_time = current_time,
          last_seen = current_time
        }
        PakettiPhraseRec_HandleNoteOn(note_value, velocity, 1)
        PakettiPhraseRec_Log("Keyboard note ON: " .. key_name .. " -> " .. 
                             PakettiPhraseRec_NoteValueToString(note_value))
      else
        -- Key already tracked, just update last_seen
        PakettiPhraseRec_KeyboardNotes[key_name].last_seen = current_time
      end
    end
    return nil  -- Consume the key
  end
  
  return key
end

function PakettiPhraseRec_CheckKeyboardNoteOffs()
  -- Timer-based note-off detection for keyboard
  -- Check if any tracked keys haven't been seen recently
  if not PakettiPhraseRec_KeyboardWriteNoteOffs then
    return  -- Skip note-off writing if disabled
  end
  
  local current_time = os.clock()
  local keys_to_release = {}
  
  for key_name, note_info in pairs(PakettiPhraseRec_KeyboardNotes) do
    local time_since_seen = current_time - note_info.last_seen
    if time_since_seen > PakettiPhraseRec_KeyboardNoteOffTimeout then
      table.insert(keys_to_release, key_name)
    end
  end
  
  for _, key_name in ipairs(keys_to_release) do
    local note_info = PakettiPhraseRec_KeyboardNotes[key_name]
    if note_info then
      PakettiPhraseRec_KeyboardNotes[key_name] = nil
      PakettiPhraseRec_HandleNoteOff(note_info.note_value, 1)
      PakettiPhraseRec_Log("Keyboard note OFF (timeout): " .. key_name .. " -> " .. 
                           PakettiPhraseRec_NoteValueToString(note_info.note_value))
    end
  end
end

function PakettiPhraseRec_KeyReleaseHandler(key_name)
  if not PakettiPhraseRec_KeyboardNotes[key_name] then
    return
  end
  
  local note_info = PakettiPhraseRec_KeyboardNotes[key_name]
  PakettiPhraseRec_KeyboardNotes[key_name] = nil
  
  if PakettiPhraseRec_KeyboardWriteNoteOffs then
    PakettiPhraseRec_HandleNoteOff(note_info.note_value, 1)
    PakettiPhraseRec_Log("Keyboard note OFF: " .. key_name .. " -> " .. 
                         PakettiPhraseRec_NoteValueToString(note_info.note_value))
  end
end

--------------------------------------------------------------------------------
-- STATE MACHINE CONTROL
--------------------------------------------------------------------------------

function PakettiPhraseRec_SetState(new_state)
  local old_state = PakettiPhraseRec_CurrentState
  PakettiPhraseRec_CurrentState = new_state
  
  PakettiPhraseRec_Log("State change: " .. PakettiPhraseRec_GetStateName(old_state) .. 
                       " -> " .. PakettiPhraseRec_GetStateName(new_state))
  
  renoise.app():show_status("PhraseRec: " .. PakettiPhraseRec_GetStateName(new_state))
  PakettiPhraseRec_UpdateDialog()
end

function PakettiPhraseRec_Arm()
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_IDLE then
    renoise.app():show_status("PhraseRec: Already armed or recording")
    return
  end
  
  -- Check API version (same as existing PhraseTransport)
  if renoise.API_VERSION < 6.1 then
    renoise.app():show_status("PhraseRec: Requires Renoise API 6.1+ (Renoise 3.4.2+)")
    return
  end
  
  -- Verify phrase editor is available
  local phrase = PakettiPhraseRec_GetSelectedPhrase()
  if not phrase then
    renoise.app():show_status("PhraseRec: No phrase selected. Create a phrase first.")
    return
  end
  
  -- Switch to phrase editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  
  -- Enable edit mode
  renoise.song().transport.edit_mode = true
  
  -- Start MIDI listening
  PakettiPhraseRec_StartMidiListening()
  
  -- Clear buffers
  PakettiPhraseRec_PendingNotes = {}
  PakettiPhraseRec_ActiveNotes = {}
  PakettiPhraseRec_KeyboardNotes = {}
  
  PakettiPhraseRec_SetState(PakettiPhraseRec_STATE_ARMED)
end

function PakettiPhraseRec_Disarm()
  PakettiPhraseRec_StopMidiListening()
  PakettiPhraseRec_RemoveIdleNotifier()
  
  PakettiPhraseRec_PendingNotes = {}
  PakettiPhraseRec_ActiveNotes = {}
  PakettiPhraseRec_KeyboardNotes = {}
  
  PakettiPhraseRec_SetState(PakettiPhraseRec_STATE_IDLE)
end

function PakettiPhraseRec_StartRecording()
  if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
    -- Auto-arm first
    PakettiPhraseRec_Arm()
  end
  
  if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_ARMED then
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  -- Check for pre-count
  if PakettiPhraseRec_PreCountBars > 0 then
    PakettiPhraseRec_SetState(PakettiPhraseRec_STATE_RECORDING_PENDING)
    PakettiPhraseRec_StartPreCount()
  else
    -- No pre-count, start immediately
    PakettiPhraseRec_BeginActiveRecording()
  end
end

function PakettiPhraseRec_StartPreCount()
  local song = renoise.song()
  if not song then return end
  
  local lpb = song.transport.lpb
  PakettiPhraseRec_PreCountBeatsRemaining = PakettiPhraseRec_PreCountBars * 4  -- 4 beats per bar
  PakettiPhraseRec_PreCountActive = true
  
  PakettiPhraseRec_Log("Starting pre-count: " .. tostring(PakettiPhraseRec_PreCountBeatsRemaining) .. " beats")
  
  -- Start transport if not playing
  if not song.transport.playing then
    song.transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
  end
  
  -- Add idle notifier for pre-count countdown
  PakettiPhraseRec_AddIdleNotifier()
end

function PakettiPhraseRec_BeginActiveRecording()
  local song = renoise.song()
  if not song then return end
  
  -- Ensure transport is playing
  if not song.transport.playing then
    song.transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
  end
  
  PakettiPhraseRec_RecordStartTime = os.clock()
  PakettiPhraseRec_RecordStartLine = PakettiPhraseRec_GetCurrentPhraseLine()
  
  -- Add idle notifier for note processing
  PakettiPhraseRec_AddIdleNotifier()
  
  PakettiPhraseRec_SetState(PakettiPhraseRec_STATE_RECORDING_ACTIVE)
end

function PakettiPhraseRec_StopRecording()
  if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
    return
  end
  
  -- Write any remaining pending notes immediately
  for _, pending in ipairs(PakettiPhraseRec_PendingNotes) do
    PakettiPhraseRec_WriteNoteToPhrase(
      pending.note_value, 
      pending.velocity, 
      pending.target_line, 
      pending.is_note_off
    )
  end
  
  PakettiPhraseRec_Disarm()
end

function PakettiPhraseRec_Toggle()
  if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
    PakettiPhraseRec_Arm()
  elseif PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_ARMED then
    PakettiPhraseRec_StartRecording()
  else
    PakettiPhraseRec_StopRecording()
  end
end

--------------------------------------------------------------------------------
-- IDLE NOTIFIER (MAIN LOOP)
--------------------------------------------------------------------------------

function PakettiPhraseRec_IdleNotifier()
  local song = renoise.song()
  if not song then return end
  
  -- Handle pre-count
  if PakettiPhraseRec_PreCountActive then
    -- For now, skip pre-count timing and just start recording
    -- A proper implementation would track beats and play click sounds
    PakettiPhraseRec_PreCountActive = false
    PakettiPhraseRec_BeginActiveRecording()
    return
  end
  
  -- Process pending notes during active recording
  if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_RECORDING_ACTIVE then
    PakettiPhraseRec_ProcessPendingNotes()
    
    -- Check for keyboard note-offs (timeout-based)
    PakettiPhraseRec_CheckKeyboardNoteOffs()
    
    -- Check if phrase editor is still active
    if not PakettiPhraseRec_IsPhraseEditorActive() then
      PakettiPhraseRec_Log("Phrase editor lost focus - disarming")
      PakettiPhraseRec_Disarm()
    end
    
    -- Check if transport stopped
    if not song.transport.playing then
      PakettiPhraseRec_Log("Transport stopped - stopping recording")
      PakettiPhraseRec_StopRecording()
    end
  end
end

function PakettiPhraseRec_AddIdleNotifier()
  if not renoise.tool().app_idle_observable:has_notifier(PakettiPhraseRec_IdleNotifier) then
    renoise.tool().app_idle_observable:add_notifier(PakettiPhraseRec_IdleNotifier)
  end
end

function PakettiPhraseRec_RemoveIdleNotifier()
  if renoise.tool().app_idle_observable:has_notifier(PakettiPhraseRec_IdleNotifier) then
    renoise.tool().app_idle_observable:remove_notifier(PakettiPhraseRec_IdleNotifier)
  end
end

--------------------------------------------------------------------------------
-- POST-RECORD QUANTIZATION
--------------------------------------------------------------------------------

function PakettiPhraseRec_QuantizeSelection()
  local song = renoise.song()
  if not song then return end
  
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("PhraseRec: No phrase selected")
    return
  end
  
  local selection = song.selection_in_phrase
  if not selection then
    renoise.app():show_status("PhraseRec: No selection in phrase")
    return
  end
  
  local grid = PakettiPhraseRec_QuantizeGrid
  if grid == 0 then
    renoise.app():show_status("PhraseRec: Quantize grid is OFF")
    return
  end
  
  local notes_moved = 0
  local phrase_length = phrase.number_of_lines
  
  -- Collect all notes in selection
  local notes_to_move = {}
  
  for line_idx = selection.start_line, selection.end_line do
    local line = phrase:line(line_idx)
    for col_idx = selection.start_column, math.min(selection.end_column, phrase.visible_note_columns) do
      local col = line.note_columns[col_idx]
      if col.note_value < 120 then  -- Not empty or OFF
        table.insert(notes_to_move, {
          note_value = col.note_value,
          instrument_value = col.instrument_value,
          volume_value = col.volume_value,
          panning_value = col.panning_value,
          delay_value = col.delay_value,
          original_line = line_idx,
          col_idx = col_idx
        })
      end
    end
  end
  
  -- Clear original positions
  for _, note in ipairs(notes_to_move) do
    local col = phrase:line(note.original_line).note_columns[note.col_idx]
    col.note_value = 121
    col.instrument_value = 255
    col.volume_value = 255
    col.panning_value = 255
    col.delay_value = 0
  end
  
  -- Move notes to quantized positions
  for _, note in ipairs(notes_to_move) do
    local target_line = PakettiPhraseRec_QuantizeLine(note.original_line, phrase_length)
    local col_idx = PakettiPhraseRec_FindFreeNoteColumn(phrase, target_line)
    local col = phrase:line(target_line).note_columns[col_idx]
    
    col.note_value = note.note_value
    col.instrument_value = note.instrument_value
    col.volume_value = note.volume_value
    col.panning_value = note.panning_value
    col.delay_value = note.delay_value
    
    if target_line ~= note.original_line then
      notes_moved = notes_moved + 1
    end
  end
  
  renoise.app():show_status("PhraseRec: Quantized " .. tostring(notes_moved) .. " notes to grid " .. tostring(grid))
end

function PakettiPhraseRec_QuantizePhrase()
  local song = renoise.song()
  if not song then return end
  
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("PhraseRec: No phrase selected")
    return
  end
  
  local grid = PakettiPhraseRec_QuantizeGrid
  if grid == 0 then
    renoise.app():show_status("PhraseRec: Quantize grid is OFF")
    return
  end
  
  local notes_moved = 0
  local phrase_length = phrase.number_of_lines
  
  -- Collect all notes in phrase
  local notes_to_move = {}
  
  for line_idx = 1, phrase_length do
    local line = phrase:line(line_idx)
    for col_idx = 1, phrase.visible_note_columns do
      local col = line.note_columns[col_idx]
      if col.note_value < 120 then  -- Not empty or OFF
        table.insert(notes_to_move, {
          note_value = col.note_value,
          instrument_value = col.instrument_value,
          volume_value = col.volume_value,
          panning_value = col.panning_value,
          delay_value = col.delay_value,
          original_line = line_idx,
          col_idx = col_idx
        })
      end
    end
  end
  
  -- Clear original positions
  for _, note in ipairs(notes_to_move) do
    local col = phrase:line(note.original_line).note_columns[note.col_idx]
    col.note_value = 121
    col.instrument_value = 255
    col.volume_value = 255
    col.panning_value = 255
    col.delay_value = 0
  end
  
  -- Move notes to quantized positions
  for _, note in ipairs(notes_to_move) do
    local target_line = PakettiPhraseRec_QuantizeLine(note.original_line, phrase_length)
    local col_idx = PakettiPhraseRec_FindFreeNoteColumn(phrase, target_line)
    local col = phrase:line(target_line).note_columns[col_idx]
    
    col.note_value = note.note_value
    col.instrument_value = note.instrument_value
    col.volume_value = note.volume_value
    col.panning_value = note.panning_value
    col.delay_value = note.delay_value
    
    if target_line ~= note.original_line then
      notes_moved = notes_moved + 1
    end
  end
  
  renoise.app():show_status("PhraseRec: Quantized entire phrase - " .. tostring(notes_moved) .. " notes moved to grid " .. tostring(grid))
end

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

function PakettiPhraseRec_UpdateDialog()
  if not PakettiPhraseRec_Vb then return end
  
  local state_text = PakettiPhraseRec_Vb.views["state_text"]
  if state_text then
    state_text.text = PakettiPhraseRec_GetStateName(PakettiPhraseRec_CurrentState)
  end
  
  -- Update button colors based on state
  local arm_btn = PakettiPhraseRec_Vb.views["arm_btn"]
  local rec_btn = PakettiPhraseRec_Vb.views["rec_btn"]
  local stop_btn = PakettiPhraseRec_Vb.views["stop_btn"]
  
  if arm_btn then
    if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_ARMED then
      arm_btn.color = {0xFF, 0xAA, 0x00}  -- Orange when armed
    else
      arm_btn.color = {0x60, 0x60, 0x60}  -- Default
    end
  end
  
  if rec_btn then
    if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_RECORDING_ACTIVE then
      rec_btn.color = {0xFF, 0x40, 0x40}  -- Red when recording
    elseif PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_RECORDING_PENDING then
      rec_btn.color = {0xFF, 0x80, 0x00}  -- Orange when pending
    else
      rec_btn.color = {0x60, 0x60, 0x60}
    end
  end
end

function PakettiPhraseRec_ShowDialog()
  if PakettiPhraseRec_Dialog and PakettiPhraseRec_Dialog.visible then
    PakettiPhraseRec_Dialog:close()
    PakettiPhraseRec_Dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  PakettiPhraseRec_Vb = vb
  
  -- Get available MIDI devices
  local midi_devices = renoise.Midi.available_input_devices()
  if #midi_devices == 0 then
    midi_devices = {"No MIDI devices"}
  end
  
  -- Find current device index
  local current_midi_idx = 1
  for i, dev in ipairs(midi_devices) do
    if dev == PakettiPhraseRec_MidiDeviceName then
      current_midi_idx = i
      break
    end
  end
  
  -- Quantize grid options
  local quant_items = {"OFF", "1", "2", "3", "4", "6", "8", "12", "16"}
  local current_quant_idx = 1
  for i, v in ipairs(quant_items) do
    if v == "OFF" and PakettiPhraseRec_QuantizeGrid == 0 then
      current_quant_idx = i
      break
    elseif tonumber(v) == PakettiPhraseRec_QuantizeGrid then
      current_quant_idx = i
      break
    end
  end
  
  local content = vb:column{
    margin = 10,
    spacing = 5,
    
    -- State Display
    vb:row{
      vb:text{text = "State: ", font = "bold"},
      vb:text{
        id = "state_text",
        text = PakettiPhraseRec_GetStateName(PakettiPhraseRec_CurrentState),
        font = "bold"
      }
    },
    
    vb:space{height = 5},
    
    -- Transport Controls
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Recording Controls", font = "bold"},
      vb:row{
        spacing = 5,
        vb:button{
          id = "arm_btn",
          text = "Arm",
          width = 60,
          tooltip = "Arm phrase recording (MIDI interception begins)",
          notifier = function()
            if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
              PakettiPhraseRec_Arm()
            else
              PakettiPhraseRec_Disarm()
            end
          end
        },
        vb:button{
          id = "rec_btn",
          text = "Record",
          width = 60,
          tooltip = "Start recording (requires armed state or auto-arms)",
          notifier = function()
            if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_RECORDING_ACTIVE then
              PakettiPhraseRec_StopRecording()
            else
              PakettiPhraseRec_StartRecording()
            end
          end
        },
        vb:button{
          id = "stop_btn",
          text = "Stop",
          width = 60,
          tooltip = "Stop recording and disarm",
          notifier = function()
            PakettiPhraseRec_StopRecording()
          end
        }
      }
    },
    
    vb:space{height = 5},
    
    -- MIDI Settings
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "MIDI Input", font = "bold"},
      vb:row{
        spacing = 5,
        vb:text{text = "Device:"},
        vb:popup{
          id = "midi_device_popup",
          items = midi_devices,
          value = current_midi_idx,
          width = 180,
          notifier = function(idx)
            PakettiPhraseRec_MidiDeviceName = midi_devices[idx]
            PakettiPhraseRec_SavePreferences()
            if PakettiPhraseRec_CurrentState ~= PakettiPhraseRec_STATE_IDLE then
              -- Restart MIDI listening with new device
              PakettiPhraseRec_StopMidiListening()
              PakettiPhraseRec_StartMidiListening()
            end
          end
        }
      },
      vb:row{
        vb:checkbox{
          id = "midi_intercept_cb",
          value = PakettiPhraseRec_MidiInterceptEnabled,
          notifier = function(value)
            PakettiPhraseRec_MidiInterceptEnabled = value
            PakettiPhraseRec_SavePreferences()
          end
        },
        vb:text{text = "Intercept MIDI for Phrase Recording"}
      }
    },
    
    vb:space{height = 5},
    
    -- Quantization Settings
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Quantization", font = "bold"},
      vb:row{
        spacing = 5,
        vb:checkbox{
          id = "quant_enable_cb",
          value = PakettiPhraseRec_QuantizeEnabled,
          notifier = function(value)
            PakettiPhraseRec_QuantizeEnabled = value
            PakettiPhraseRec_SavePreferences()
          end
        },
        vb:text{text = "Live Quantize"},
        vb:popup{
          id = "quant_grid_popup",
          items = quant_items,
          value = current_quant_idx,
          width = 60,
          notifier = function(idx)
            local val = quant_items[idx]
            if val == "OFF" then
              PakettiPhraseRec_QuantizeGrid = 0
            else
              PakettiPhraseRec_QuantizeGrid = tonumber(val)
            end
            PakettiPhraseRec_SavePreferences()
          end
        },
        vb:text{text = "lines"}
      },
      vb:row{
        spacing = 5,
        vb:button{
          text = "Quantize Selection",
          width = 110,
          tooltip = "Quantize notes in current phrase selection",
          notifier = PakettiPhraseRec_QuantizeSelection
        },
        vb:button{
          text = "Quantize Phrase",
          width = 110,
          tooltip = "Quantize all notes in current phrase",
          notifier = PakettiPhraseRec_QuantizePhrase
        }
      }
    },
    
    vb:space{height = 5},
    
    -- Pre-count Settings
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Pre-Count", font = "bold"},
      vb:row{
        spacing = 5,
        vb:text{text = "Bars:"},
        vb:valuebox{
          id = "precount_bars_vb",
          min = 0,
          max = 4,
          value = PakettiPhraseRec_PreCountBars,
          width = 50,
          notifier = function(value)
            PakettiPhraseRec_PreCountBars = value
            PakettiPhraseRec_SavePreferences()
          end
        },
        vb:checkbox{
          id = "click_playback_cb",
          value = PakettiPhraseRec_ClickDuringPlayback,
          notifier = function(value)
            PakettiPhraseRec_ClickDuringPlayback = value
            PakettiPhraseRec_SavePreferences()
          end
        },
        vb:text{text = "Click during playback"}
      }
    },
    
    vb:space{height = 5},
    
    -- Debug toggle
    vb:row{
      vb:checkbox{
        id = "debug_cb",
        value = PakettiPhraseRec_DEBUG,
        notifier = function(value)
          PakettiPhraseRec_DEBUG = value
        end
      },
      vb:text{text = "Debug Output"}
    },
    
    vb:space{height = 5},
    
    -- Close button
    vb:row{
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if PakettiPhraseRec_Dialog then
            PakettiPhraseRec_Dialog:close()
            PakettiPhraseRec_Dialog = nil
          end
        end
      }
    }
  }
  
  PakettiPhraseRec_Dialog = renoise.app():show_custom_dialog(
    "Phrase Transport Recording",
    content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  PakettiPhraseRec_UpdateDialog()
end

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Global:Paketti:Phrase Recording Dialog",
  invoke = PakettiPhraseRec_ShowDialog
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Phrase Recording Arm",
  invoke = function()
    if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
      PakettiPhraseRec_Arm()
    else
      PakettiPhraseRec_Disarm()
    end
  end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Phrase Recording Start",
  invoke = PakettiPhraseRec_StartRecording
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Phrase Recording Stop",
  invoke = PakettiPhraseRec_StopRecording
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Phrase Recording Toggle",
  invoke = PakettiPhraseRec_Toggle
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Recording Dialog",
  invoke = PakettiPhraseRec_ShowDialog
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Recording Arm",
  invoke = function()
    if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
      PakettiPhraseRec_Arm()
    else
      PakettiPhraseRec_Disarm()
    end
  end
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Recording Start",
  invoke = PakettiPhraseRec_StartRecording
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Recording Stop",
  invoke = PakettiPhraseRec_StopRecording
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Recording Toggle",
  invoke = PakettiPhraseRec_Toggle
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Quantize Selection",
  invoke = PakettiPhraseRec_QuantizeSelection
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Phrase Quantize Phrase",
  invoke = PakettiPhraseRec_QuantizePhrase
}

--------------------------------------------------------------------------------
-- MIDI MAPPINGS
--------------------------------------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:Phrase Recording Arm [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
        PakettiPhraseRec_Arm()
      else
        PakettiPhraseRec_Disarm()
      end
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Phrase Recording Start [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPhraseRec_StartRecording()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Phrase Recording Stop [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPhraseRec_StopRecording()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Phrase Recording Toggle [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPhraseRec_Toggle()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Phrase Quantize Selection [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPhraseRec_QuantizeSelection()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Phrase Quantize Phrase [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiPhraseRec_QuantizePhrase()
    end
  end
}

--------------------------------------------------------------------------------
-- MENU ENTRIES
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Phrase Recording:Show Recording Dialog",
  invoke = PakettiPhraseRec_ShowDialog
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Phrase Recording:Arm Recording",
  invoke = function()
    if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
      PakettiPhraseRec_Arm()
    else
      PakettiPhraseRec_Disarm()
    end
  end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Phrase Recording:Start Recording",
  invoke = PakettiPhraseRec_StartRecording
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Phrase Recording:Stop Recording",
  invoke = PakettiPhraseRec_StopRecording
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Phrase Recording:Quantize Selection",
  invoke = PakettiPhraseRec_QuantizeSelection
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Phrase Recording:Quantize Phrase",
  invoke = PakettiPhraseRec_QuantizePhrase
}

renoise.tool():add_menu_entry{
  name = "Instrument Phrases:Paketti..:Phrase Recording:Show Recording Dialog",
  invoke = PakettiPhraseRec_ShowDialog
}

renoise.tool():add_menu_entry{
  name = "Instrument Phrases:Paketti..:Phrase Recording:Arm Recording",
  invoke = function()
    if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
      PakettiPhraseRec_Arm()
    else
      PakettiPhraseRec_Disarm()
    end
  end
}

renoise.tool():add_menu_entry{
  name = "Instrument Phrases:Paketti..:Phrase Recording:Quantize Selection",
  invoke = PakettiPhraseRec_QuantizeSelection
}

renoise.tool():add_menu_entry{
  name = "Instrument Phrases:Paketti..:Phrase Recording:Quantize Phrase",
  invoke = PakettiPhraseRec_QuantizePhrase
}

--------------------------------------------------------------------------------
-- PREFERENCES LOAD/SAVE
--------------------------------------------------------------------------------

function PakettiPhraseRec_LoadPreferences()
  -- Load settings from preferences.xml
  if preferences and preferences.PakettiPhraseRecording then
    local prefs = preferences.PakettiPhraseRecording
    
    if prefs.MidiDeviceName and prefs.MidiDeviceName.value then
      PakettiPhraseRec_MidiDeviceName = prefs.MidiDeviceName.value
    end
    
    if prefs.MidiInterceptEnabled and prefs.MidiInterceptEnabled.value ~= nil then
      PakettiPhraseRec_MidiInterceptEnabled = prefs.MidiInterceptEnabled.value
    end
    
    if prefs.QuantizeEnabled and prefs.QuantizeEnabled.value ~= nil then
      PakettiPhraseRec_QuantizeEnabled = prefs.QuantizeEnabled.value
    end
    
    if prefs.QuantizeGrid and prefs.QuantizeGrid.value then
      PakettiPhraseRec_QuantizeGrid = tonumber(prefs.QuantizeGrid.value) or 4
    end
    
    if prefs.PreCountBars and prefs.PreCountBars.value then
      PakettiPhraseRec_PreCountBars = tonumber(prefs.PreCountBars.value) or 1
    end
    
    if prefs.ClickDuringPlayback and prefs.ClickDuringPlayback.value ~= nil then
      PakettiPhraseRec_ClickDuringPlayback = prefs.ClickDuringPlayback.value
    end
    
    PakettiPhraseRec_Log("Preferences loaded")
  end
end

function PakettiPhraseRec_SavePreferences()
  -- Save settings to preferences.xml
  if preferences and preferences.PakettiPhraseRecording then
    local prefs = preferences.PakettiPhraseRecording
    
    if prefs.MidiDeviceName then
      prefs.MidiDeviceName.value = PakettiPhraseRec_MidiDeviceName or ""
    end
    
    if prefs.MidiInterceptEnabled then
      prefs.MidiInterceptEnabled.value = PakettiPhraseRec_MidiInterceptEnabled
    end
    
    if prefs.QuantizeEnabled then
      prefs.QuantizeEnabled.value = PakettiPhraseRec_QuantizeEnabled
    end
    
    if prefs.QuantizeGrid then
      prefs.QuantizeGrid.value = PakettiPhraseRec_QuantizeGrid
    end
    
    if prefs.PreCountBars then
      prefs.PreCountBars.value = PakettiPhraseRec_PreCountBars
    end
    
    if prefs.ClickDuringPlayback then
      prefs.ClickDuringPlayback.value = PakettiPhraseRec_ClickDuringPlayback
    end
    
    PakettiPhraseRec_Log("Preferences saved")
  end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- Load preferences on startup
PakettiPhraseRec_LoadPreferences()

PakettiPhraseRec_Log("PakettiPhraseTransportRecording loaded")

