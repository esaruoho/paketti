-- PakettiOpenMPTLinearKeyboardLayer.lua
-- Lua 5.1 only. All functions GLOBAL and defined before first use.
-- Uses my_keyhandler_func as fallback. After dialog opens, reactivate middle frame for key passthrough.
-- Linear keyboard layer: QWERTYUIOP, ASDFGHJKL, ZXCVBNM,. as linear octave rows

-- State
PakettiLinearKeyboard_dialog = nil
PakettiLinearKeyboard_vb = nil
PakettiLinearKeyboard_1_octave_dropdown = nil
PakettiLinearKeyboard_q_octave_dropdown = nil
PakettiLinearKeyboard_a_octave_dropdown = nil
PakettiLinearKeyboard_z_octave_dropdown = nil
PakettiLinearKeyboard_follow_transport_checkbox = nil
PakettiLinearKeyboard_fret_checkbox = nil
PakettiLinearKeyboard_current_playing_notes = {}
PakettiLinearKeyboard_pressed_keys = {}  -- Track which keys are currently pressed
PakettiLinearKeyboard_key_timestamps = {} -- Track when keys were pressed for auto-cleanup
PakettiLinearKeyboard_DEBUG = true
PakettiLinearKeyboard_transport_notifier = nil
PakettiLinearKeyboard_minimized = false  -- Track minimized state
PakettiLinearKeyboard_fret_mode_enabled = false  -- Track fret mode state across dialog rebuilds
PakettiLinearKeyboard_follow_transport_enabled = false  -- Track follow transport state across dialog rebuilds
PakettiLinearKeyboard_cleanup_timer = nil -- Timer for cleaning up stuck notes
PakettiLinearKeyboard_NOTE_TIMEOUT = 5000 -- Auto-release notes after 5 seconds (only for truly stuck notes when no keys pressed)
PakettiLinearKeyboard_TIMER_INTERVAL = 5000 -- Timer interval in milliseconds for safety cleanup only (5 seconds)

-- Default note values (absolute note values, not octave offsets)
PakettiLinearKeyboard_1_base_note = 36    -- C-3 (transport.octave - 1) * 12
PakettiLinearKeyboard_q_base_note = 48    -- C-4 (transport.octave * 12)
PakettiLinearKeyboard_a_base_note = 60    -- C-5 (transport.octave + 1) * 12  
PakettiLinearKeyboard_z_base_note = 72    -- C-6 (transport.octave + 2) * 12

-- Fret mode base notes (dynamically updated with transport octave)
PakettiLinearKeyboard_fret_z_base = 16    -- E-2 (default, will follow transport)
PakettiLinearKeyboard_fret_a_base = 21    -- A-2 (default, will follow transport)
PakettiLinearKeyboard_fret_q_base = 26    -- D-3 (default, will follow transport)
PakettiLinearKeyboard_fret_1_base = 31    -- G-3 (default, will follow transport)

-- Linear key mappings for each row (semitone offsets within octave)
PakettiLinearKeyboard_1_row_keys = {
  ["1"] = 0, ["2"] = 1, ["3"] = 2, ["4"] = 3, ["5"] = 4, ["6"] = 5, ["7"] = 6, ["8"] = 7, ["9"] = 8, ["0"] = 9, ["+"] = 10, ["="] = 11, ["´"] = 12
}

PakettiLinearKeyboard_q_row_keys = {
  q = 0, w = 1, e = 2, r = 3, t = 4, y = 5, u = 6, i = 7, o = 8, p = 9, ["å"] = 10, ["¨"] = 10, ["]"] = 11
}

PakettiLinearKeyboard_a_row_keys = {
  a = 0, s = 1, d = 2, f = 3, g = 4, h = 5, j = 6, k = 7, l = 8, ["ö"] = 9, ["ä"] = 10, ["'"] = 11
}

PakettiLinearKeyboard_z_row_keys = {
  z = 0, x = 1, c = 2, v = 3, b = 4, n = 5, m = 6, [","] = 7, ["comma"] = 7, ["."] = 8, ["period"] = 8, ["-"] = 9, ["minus"] = 9, ["hyphen"] = 9
}

-- Additional continuation keys (like PakettiCapture) - extending the Z row further
-- NOTE: < and > are NOT mapped as notes - they pass through to Renoise for transport.octave control
PakettiLinearKeyboard_continuation_keys = {
}

-- Helper: clamp integer
function PakettiLinearKeyboard_Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Helper: convert 0..119 to note string C-0..B-9
function PakettiLinearKeyboard_NoteValueToString(value)
  local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
  local v = PakettiLinearKeyboard_Clamp(value, 0, 119)
  local octave = math.floor(v / 12)
  local name = names[(v % 12) + 1]
  return name .. tostring(octave)
end

-- Helper: convert note string to 0..119 value
function PakettiLinearKeyboard_NoteStringToValue(note_string)
  if not note_string or note_string == "" or note_string == "OFF" then return nil end
  local name = string.sub(note_string, 1, 2)
  local octave_char = string.sub(note_string, 3, 3)
  local names = { ["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3, ["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7, ["G#"] = 8, ["A-"] = 9, ["A#"] = 10, ["B-"] = 11 }
  local base = names[name]
  local octave = tonumber(octave_char)
  if base == nil or octave == nil then return nil end
  local value = (octave * 12) + base
  return PakettiLinearKeyboard_Clamp(value, 0, 119)
end

-- Create note dropdown items (C-0 through B-9 - all 120 notes)
function PakettiLinearKeyboard_CreateNoteItems()
  local items = {}
  for note_value = 0, 119 do
    local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
    table.insert(items, note_string)
  end
  return items
end

-- Get selected note value from dropdown index
function PakettiLinearKeyboard_GetSelectedNoteValue(dropdown_value)
  return dropdown_value - 1  -- dropdown is 1-indexed, note values are 0-indexed
end

-- Detect if cursor is in note column
function PakettiLinearKeyboard_IsInNoteColumn()
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Not in sequencer track")
    end
    return false
  end
  
  -- Check if we're in a note column using sub_column_type
  -- Based on PakettiSubColumnModifier.lua constants:
  -- [1] = "Note"
  -- [2] = "Instrument Number"
  -- [3] = "Volume"  
  -- [4] = "Panning"
  -- [5] = "Delay"
  -- [6] = "Sample Effect Number"
  -- [7] = "Sample Effect Amount"
  -- [8] = "Effect Number"
  -- [9] = "Effect Amount"
  local selected_sub_column_type = song.selected_sub_column_type
  
  if PakettiLinearKeyboard_DEBUG then
    local sub_column_names = {
      [1] = "Note",
      [2] = "Instrument Number", 
      [3] = "Volume",
      [4] = "Panning",
      [5] = "Delay",
      [6] = "Sample Effect Number",
      [7] = "Sample Effect Amount",
      [8] = "Effect Number",
      [9] = "Effect Amount"
    }
    local name = sub_column_names[selected_sub_column_type] or "Unknown"
    print("PakettiLinearKeyboard DEBUG: Current sub-column type: " .. tostring(selected_sub_column_type) .. " (" .. name .. ")")
  end
  
  -- Only intercept if we're in the Note sub-column (type 1)
  local is_note_column = (selected_sub_column_type == 1)
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Is in note column: " .. tostring(is_note_column))
  end
  
  return is_note_column
end

-- Map key to note value based on linear mapping
function PakettiLinearKeyboard_KeyToNoteValue(key_name)
  if not key_name then return nil end
  
  -- Check if Fret mode is enabled
  local fret_mode = PakettiLinearKeyboard_fret_mode_enabled
  
  if fret_mode then
    -- Fret mode: Dynamic fret layout that follows transport octave
    -- Z row = E-2 + transport offset, A row = A-2 + transport offset, etc.
    
    -- Z row (starts at E-2 equivalent)
    local z_fret_offsets = {
      z = 0, x = 1, c = 2, v = 3, b = 4, n = 5, m = 6, 
      [","] = 7, ["comma"] = 7, ["."] = 8, ["period"] = 8, 
      ["-"] = 9, ["minus"] = 9, ["hyphen"] = 9
    }
    local z_offset = z_fret_offsets[key_name]
    if z_offset ~= nil then
      local note_value = PakettiLinearKeyboard_fret_z_base + z_offset
      return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
    end
    
    -- A row (starts at A-2 equivalent)  
    local a_fret_offsets = {
      a = 0, s = 1, d = 2, f = 3, g = 4, h = 5, j = 6, k = 7, l = 8, 
      ["ö"] = 9, ["ä"] = 10, ["'"] = 11
    }
    local a_offset = a_fret_offsets[key_name]
    if a_offset ~= nil then
      local note_value = PakettiLinearKeyboard_fret_a_base + a_offset
      return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
    end
    
    -- Q row (starts at D-3 equivalent)
    local q_fret_offsets = {
      q = 0, w = 1, e = 2, r = 3, t = 4, y = 5, u = 6, i = 7, o = 8, p = 9, 
      ["å"] = 10, ["¨"] = 10, ["]"] = 11
    }
    local q_offset = q_fret_offsets[key_name]
    if q_offset ~= nil then
      local note_value = PakettiLinearKeyboard_fret_q_base + q_offset
      return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
    end
    
    -- 1 row (starts at G-3 equivalent)
    local num1_fret_offsets = {
      ["1"] = 0, ["2"] = 1, ["3"] = 2, ["4"] = 3, ["5"] = 4, ["6"] = 5, ["7"] = 6, 
      ["8"] = 7, ["9"] = 8, ["0"] = 9, ["+"] = 10, ["="] = 11, ["´"] = 12
    }
    local num1_offset = num1_fret_offsets[key_name]
    if num1_offset ~= nil then
      local note_value = PakettiLinearKeyboard_fret_1_base + num1_offset
      return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
    end
    
    -- NOTE: < and > are NOT mapped - they pass through to Renoise for transport.octave control
    return nil
  end
  
  -- Regular mode - always use current base note variables (updated by transport changes)
  
  -- Check 1 row
  local num1_offset = PakettiLinearKeyboard_1_row_keys[key_name]
  if num1_offset ~= nil then
    local note_value = PakettiLinearKeyboard_1_base_note + num1_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  -- Check Q row
  local q_offset = PakettiLinearKeyboard_q_row_keys[key_name]
  if q_offset ~= nil then
    local note_value = PakettiLinearKeyboard_q_base_note + q_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  -- Check A row  
  local a_offset = PakettiLinearKeyboard_a_row_keys[key_name]
  if a_offset ~= nil then
    local note_value = PakettiLinearKeyboard_a_base_note + a_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  -- Check Z row
  local z_offset = PakettiLinearKeyboard_z_row_keys[key_name]
  if z_offset ~= nil then
    local note_value = PakettiLinearKeyboard_z_base_note + z_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  -- Check continuation keys (extending Z row)
  local cont_offset = PakettiLinearKeyboard_continuation_keys[key_name]
  if cont_offset ~= nil then
    local note_value = PakettiLinearKeyboard_z_base_note + cont_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  return nil
end

-- Safety backup - only clean up truly stuck notes after a long timeout
function PakettiLinearKeyboard_CleanupStuckNotes()
  local current_time = os.clock() * 1000 -- Convert to milliseconds
  local keys_to_remove = {}
  
  -- Only clean up notes that have been stuck for a very long time (safety backup)
  for key_name, timestamp in pairs(PakettiLinearKeyboard_key_timestamps) do
    local time_held = current_time - timestamp
    
    -- Only clean up after 10 seconds - this is just a safety backup
    if time_held > 10000 then
      table.insert(keys_to_remove, key_name)
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Safety cleanup - removing truly stuck key: " .. key_name .. " (held for " .. tostring(math.floor(time_held)) .. "ms)")
      end
    end
  end
  
  -- Clean up truly stuck notes
  for _, key_name in ipairs(keys_to_remove) do
    local note_value = PakettiLinearKeyboard_pressed_keys[key_name]
    if note_value then
      PakettiLinearKeyboard_StopNote(note_value)
      if PakettiLinearKeyboard_DEBUG then
        local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
        print("PakettiLinearKeyboard DEBUG: Safety stopped note " .. note_string .. " for stuck key: " .. key_name)
      end
    end
    PakettiLinearKeyboard_pressed_keys[key_name] = nil
    PakettiLinearKeyboard_key_timestamps[key_name] = nil
  end
end

-- Stop all currently playing notes
function PakettiLinearKeyboard_StopAllNotes()
  if #PakettiLinearKeyboard_current_playing_notes == 0 then return end
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  
  -- Stop all notes that were triggered
  song:trigger_instrument_note_off(selected_instrument_index, selected_track_index, PakettiLinearKeyboard_current_playing_notes)
  
  PakettiLinearKeyboard_current_playing_notes = {}
  PakettiLinearKeyboard_pressed_keys = {}
  PakettiLinearKeyboard_key_timestamps = {}
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Stopped all notes and cleared state")
  end
end

-- Start note audition
function PakettiLinearKeyboard_StartNote(note_value)
  if not note_value then return end
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  
  -- Check if this note is already playing
  for i = 1, #PakettiLinearKeyboard_current_playing_notes do
    if PakettiLinearKeyboard_current_playing_notes[i] == note_value then
      return -- already playing
    end
  end
  
  -- Add to playing notes and trigger
  table.insert(PakettiLinearKeyboard_current_playing_notes, note_value)
  song:trigger_instrument_note_on(selected_instrument_index, selected_track_index, {note_value}, 1.0)
  
  if PakettiLinearKeyboard_DEBUG then
    local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
    print("PakettiLinearKeyboard DEBUG: Started note " .. tostring(note_string) .. " (" .. tostring(note_value) .. ")")
  end
end

-- Stop specific note audition
function PakettiLinearKeyboard_StopNote(note_value)
  if not note_value then return end
  
  -- Remove from playing notes
  for i = #PakettiLinearKeyboard_current_playing_notes, 1, -1 do
    if PakettiLinearKeyboard_current_playing_notes[i] == note_value then
      table.remove(PakettiLinearKeyboard_current_playing_notes, i)
      break
    end
  end
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index  
  local selected_instrument_index = song.selected_instrument_index
  
  -- More reliable note stopping for looping samples:
  -- First try standard note-off
  song:trigger_instrument_note_off(selected_instrument_index, selected_track_index, {note_value})
  
  -- For better reliability with looping samples, also trigger a zero-velocity note-on
  -- This forces the sample to stop even if it's looping
  song:trigger_instrument_note_on(selected_instrument_index, selected_track_index, {note_value}, 0.0)
  
  if PakettiLinearKeyboard_DEBUG then
    local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
    print("PakettiLinearKeyboard DEBUG: Stopped note " .. tostring(note_string) .. " (" .. tostring(note_value) .. ") with note-off + zero-velocity")
  end
end

-- Write note to pattern editor
function PakettiLinearKeyboard_WriteNoteToPattern(note_value)
  if not note_value then return end
  
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end
  
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local line = ptrack:line(song.selected_line_index)
  local ncol_index = song.selected_note_column_index
  
  if ncol_index > 0 then
    local ncol = line:note_column(ncol_index)
    local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
    ncol.note_string = note_string
    ncol.instrument_value = song.selected_instrument_index - 1
    
    -- Advance cursor by edit step with proper modulo wrapping
    local edit_step = song.transport.edit_step
    local current_line = song.selected_line_index
    local pattern_length = patt.number_of_lines
    
    -- Use modulo to wrap around properly (convert to 0-based, add step, modulo, convert back to 1-based)
    local new_line = ((current_line - 1 + edit_step) % pattern_length) + 1
    
    song.selected_line_index = new_line
    
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Wrote note " .. tostring(note_string) .. " to pattern, advanced cursor by " .. tostring(edit_step) .. " lines")
    end
  end
end

-- Dedicated OpenMPT Linear Keyboard Key Handler
function OpenMPTKeyhandler(dialog, key)
  if not key then return my_keyhandler_func(dialog, key) end
  
  local key_name = tostring(key.name or "")
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Key event: '" .. key_name .. "' state: " .. tostring(key.state or "pressed") .. " repeated: " .. tostring(key.repeated))
    local pressed_list = {}
    for k, _ in pairs(PakettiLinearKeyboard_pressed_keys) do
      table.insert(pressed_list, k)
    end
    print("PakettiLinearKeyboard DEBUG: Currently pressed keys: " .. table.concat(pressed_list, ", ") .. " (count: " .. tostring(#pressed_list) .. ")")
  end
  
  -- Handle key releases - this is the primary way to stop notes
  if key.state == "released" then
    local note_value = PakettiLinearKeyboard_KeyToNoteValue(key_name)
    if note_value then
      -- Stop the note immediately on key release
      PakettiLinearKeyboard_StopNote(note_value)
      
      -- Clean up tracking
      PakettiLinearKeyboard_pressed_keys[key_name] = nil
      PakettiLinearKeyboard_key_timestamps[key_name] = nil
      
      if PakettiLinearKeyboard_DEBUG then
        local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
        print("PakettiLinearKeyboard DEBUG: Key released - stopped note " .. note_string .. " for key: " .. key_name)
      end
    else
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Non-mappable key released: " .. key_name)
      end
    end
    return nil -- Consume all release events
  end
  
  -- Always pass through ANY modifier key combinations to Renoise (shift, alt, ctrl, cmd)
  if key.modifiers and (#key.modifiers > 0) then
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Passing through modifier key combo: " .. key_name)
    end
    return my_keyhandler_func(dialog, key)
  end
  
  -- Pass through cursor keys and function keys
  if key_name == "up" or key_name == "down" or key_name == "left" or key_name == "right" or
     key_name == "f1" or key_name == "f2" or key_name == "f3" or key_name == "f4" or 
     key_name == "f5" or key_name == "f6" or key_name == "f7" or key_name == "f8" or 
     key_name == "f9" or key_name == "f10" or key_name == "f11" then
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Passing through navigation/function key: " .. key_name)
    end
    return my_keyhandler_func(dialog, key)
  end
  
  -- Handle special keys for note control
  if key_name == "space" and not key.repeated then
    -- Space bar stops all notes and clears pressed keys state
    PakettiLinearKeyboard_StopAllNotes()
    PakettiLinearKeyboard_pressed_keys = {}
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Space pressed - stopped all notes and cleared pressed keys")
    end
    return nil
  end
  
  -- Check if we're in note column
  local in_note_column = PakettiLinearKeyboard_IsInNoteColumn()
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: In note column: " .. tostring(in_note_column))
  end
  
  if not in_note_column then
    -- Only stop notes when we're a mappable key but not in note column
    local note_value = PakettiLinearKeyboard_KeyToNoteValue(key_name)
    if note_value and #PakettiLinearKeyboard_current_playing_notes > 0 then
      PakettiLinearKeyboard_StopAllNotes()
      PakettiLinearKeyboard_pressed_keys = {}
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Mappable key pressed outside note column, stopped all notes")
      end
    end
    
    -- Show user which column type they're in for the first key press
    if not key.repeated and note_value then
      local song = renoise.song()
      local sub_column_type = song.selected_sub_column_type
      local sub_column_names = {
        [1] = "Note", [2] = "Instrument Number", [3] = "Volume", [4] = "Panning", [5] = "Delay",
        [6] = "Sample Effect Number", [7] = "Sample Effect Amount", [8] = "Effect Number", [9] = "Effect Amount"
      }
      local name = sub_column_names[sub_column_type] or "Unknown"
      renoise.app():show_status("PakettiLinearKeyboard: In " .. name .. " column (" .. tostring(sub_column_type) .. ") - keys pass through")
    end
    
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Not in note column, passing through key: " .. key_name)
    end
    return my_keyhandler_func(dialog, key)
  end
  
  -- Map key to note value
  local note_value = PakettiLinearKeyboard_KeyToNoteValue(key_name)
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Key '" .. key_name .. "' mapped to note value: " .. tostring(note_value))
  end
  
  if note_value then
    -- This is a mappable note key - ALWAYS intercept it when in note column
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Intercepting key '" .. key_name .. "' -> note " .. tostring(note_value))
    end
    
    if not key.repeated then
      -- Always allow retriggering - clear any previous state for this key first
      if PakettiLinearKeyboard_pressed_keys[key_name] then
        local old_note = PakettiLinearKeyboard_pressed_keys[key_name]
        PakettiLinearKeyboard_StopNote(old_note)
        if PakettiLinearKeyboard_DEBUG then
          print("PakettiLinearKeyboard DEBUG: Stopped previous note for key retrigger: " .. key_name)
        end
      end
      
      -- Start this note and add to tracking with timestamp
      PakettiLinearKeyboard_StartNote(note_value)
      
      -- Only write to pattern if edit mode is on
      local song = renoise.song()
      if song.transport.edit_mode then
        PakettiLinearKeyboard_WriteNoteToPattern(note_value)
      end
      
      PakettiLinearKeyboard_pressed_keys[key_name] = note_value
      PakettiLinearKeyboard_key_timestamps[key_name] = os.clock() * 1000 -- Record timestamp
      
      -- Show feedback with chord count and edit mode status
      local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
      local num_playing = 0
      for _ in pairs(PakettiLinearKeyboard_pressed_keys) do
        num_playing = num_playing + 1
      end
      local edit_status = song.transport.edit_mode and "written to pattern" or "auditioned only"
      renoise.app():show_status("PakettiLinearKeyboard: " .. note_string .. " " .. edit_status .. " (key: " .. key_name .. ") - " .. num_playing .. " notes")
      
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Started note " .. note_string .. " for key " .. key_name .. " (" .. num_playing .. " total notes playing)")
        print("PakettiLinearKeyboard DEBUG: Edit mode: " .. tostring(song.transport.edit_mode) .. " (" .. edit_status .. ")")
      end
    else
      -- Key repeated - handle edit mode (timestamp doesn't need refreshing since we have proper key release events now)
      
      local song = renoise.song()
      local edit_mode_on = song.transport.edit_mode
      
      if edit_mode_on then
        -- Edit mode is on: write to pattern on repeat (but keep other notes playing)
        if PakettiLinearKeyboard_pressed_keys[key_name] then
          PakettiLinearKeyboard_WriteNoteToPattern(note_value)
          
          if PakettiLinearKeyboard_DEBUG then
            print("PakettiLinearKeyboard DEBUG: Key repeated in edit mode, writing note: " .. key_name)
          end
        end
      else
        -- Edit mode is off: just keep the note playing, don't write to pattern
        if PakettiLinearKeyboard_DEBUG then
          print("PakettiLinearKeyboard DEBUG: Key repeated but edit mode off, holding note: " .. key_name)
        end
        -- Note continues playing, no pattern writing
      end
    end
    
    -- ALWAYS return nil for mappable keys when in note column to prevent global shortcuts
    return nil
  else
    -- Not a mappable key - only stop notes for certain keys (like Enter, Tab, Escape)
    local should_clear_notes = false
    if not key.repeated then
      -- Only clear notes for navigation keys that indicate user is done playing
      if key_name == "return" or key_name == "enter" or key_name == "tab" or key_name == "escape" or 
         key_name == "up" or key_name == "down" or key_name == "left" or key_name == "right" or
         key_name == "delete" or key_name == "backspace" then
        should_clear_notes = true
      end
      
      if should_clear_notes then
        PakettiLinearKeyboard_StopAllNotes()
        PakettiLinearKeyboard_pressed_keys = {}
        if PakettiLinearKeyboard_DEBUG then
          print("PakettiLinearKeyboard DEBUG: Navigation key pressed, cleared all notes: " .. key_name)
        end
      end
    end
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Unmappable key, passing through: " .. key_name)
    end
    return my_keyhandler_func(dialog, key)
  end
end

-- Transport octave notifier function
function PakettiLinearKeyboard_TransportOctaveChanged()
  if not PakettiLinearKeyboard_vb then return end
  
  local song = renoise.song()
  local base_octave = song.transport.octave or 4
  
  -- Always update base note variables when transport changes with proper bounds checking
  PakettiLinearKeyboard_1_base_note = PakettiLinearKeyboard_Clamp((base_octave - 1) * 12, 0, 119)  -- C- of transport octave - 1, clamped
  PakettiLinearKeyboard_q_base_note = PakettiLinearKeyboard_Clamp(base_octave * 12, 0, 119)        -- C- of transport octave, clamped
  PakettiLinearKeyboard_a_base_note = PakettiLinearKeyboard_Clamp((base_octave + 1) * 12, 0, 119)  -- C- of transport octave + 1, clamped
  PakettiLinearKeyboard_z_base_note = PakettiLinearKeyboard_Clamp((base_octave + 2) * 12, 0, 119)  -- C- of transport octave + 2, clamped
  
  -- Update fret mode base notes (maintain relative intervals)
  -- Default fret layout: Z=E-2(16), A=A-2(21), Q=D-3(26), 1=G-3(31) when transport.octave = 4
  -- When transport octave changes, shift all fret notes by the same amount
  local octave_shift = (base_octave - 4) * 12  -- How many semitones to shift from default octave 4
  
  -- Clamp fret base notes to valid MIDI range [0-119] to prevent dropdown errors
  PakettiLinearKeyboard_fret_z_base = PakettiLinearKeyboard_Clamp(16 + octave_shift, 0, 119)  -- E-2 + shift, clamped
  PakettiLinearKeyboard_fret_a_base = PakettiLinearKeyboard_Clamp(21 + octave_shift, 0, 119)  -- A-2 + shift, clamped
  PakettiLinearKeyboard_fret_q_base = PakettiLinearKeyboard_Clamp(26 + octave_shift, 0, 119)  -- D-3 + shift, clamped
  PakettiLinearKeyboard_fret_1_base = PakettiLinearKeyboard_Clamp(31 + octave_shift, 0, 119)  -- G-3 + shift, clamped
  
  if PakettiLinearKeyboard_DEBUG and (octave_shift < -16 or octave_shift > 88) then
    print("PakettiLinearKeyboard DEBUG: Extreme transport octave " .. tostring(base_octave) .. ", fret base notes clamped to valid range")
  end
  
  -- Only update dropdown display if following transport
  if PakettiLinearKeyboard_follow_transport_enabled then
    -- Check if we're in fret mode and update accordingly
    if PakettiLinearKeyboard_fret_mode_enabled then
      PakettiLinearKeyboard_UpdateFretModeDropdowns()
    else
      PakettiLinearKeyboard_UpdateDropdowns()
    end
  end
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Transport octave changed to " .. tostring(base_octave) .. ", updated base notes")
    print("PakettiLinearKeyboard DEBUG: Fret mode bases - Z:" .. PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_z_base) .. 
          " A:" .. PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_a_base) .. 
          " Q:" .. PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_q_base) .. 
          " 1:" .. PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_1_base))
  end
end

-- Update dropdown values based on current transport octave
function PakettiLinearKeyboard_UpdateDropdowns()
  if not PakettiLinearKeyboard_vb then return end
  
  local song = renoise.song()
  local base_octave = song.transport.octave or 4
  
  -- Only update dropdowns if not following transport or if manually triggered
  local follow_transport = PakettiLinearKeyboard_follow_transport_checkbox and PakettiLinearKeyboard_follow_transport_checkbox.value or false
  
  if follow_transport or not PakettiLinearKeyboard_follow_transport_checkbox then
    -- Update dropdowns to show current defaults based on transport octave with proper bounds checking
    if PakettiLinearKeyboard_1_octave_dropdown then
      local default_note = PakettiLinearKeyboard_Clamp((base_octave - 1) * 12, 0, 119)  -- C- of transport octave - 1, clamped
      PakettiLinearKeyboard_1_base_note = default_note
      local dropdown_value = PakettiLinearKeyboard_Clamp(default_note + 1, 1, 120)  -- Clamp dropdown to valid range
      PakettiLinearKeyboard_1_octave_dropdown.value = dropdown_value
    end
    
    if PakettiLinearKeyboard_q_octave_dropdown then
      local default_note = PakettiLinearKeyboard_Clamp(base_octave * 12, 0, 119)  -- C- of transport octave, clamped
      PakettiLinearKeyboard_q_base_note = default_note
      local dropdown_value = PakettiLinearKeyboard_Clamp(default_note + 1, 1, 120)  -- Clamp dropdown to valid range
      PakettiLinearKeyboard_q_octave_dropdown.value = dropdown_value
    end
    
    if PakettiLinearKeyboard_a_octave_dropdown then
      local default_note = PakettiLinearKeyboard_Clamp((base_octave + 1) * 12, 0, 119)  -- C- of transport octave + 1, clamped
      PakettiLinearKeyboard_a_base_note = default_note
      local dropdown_value = PakettiLinearKeyboard_Clamp(default_note + 1, 1, 120)  -- Clamp dropdown to valid range
      PakettiLinearKeyboard_a_octave_dropdown.value = dropdown_value
    end
    
    if PakettiLinearKeyboard_z_octave_dropdown then
      local default_note = PakettiLinearKeyboard_Clamp((base_octave + 2) * 12, 0, 119)  -- C- of transport octave + 2, clamped
      PakettiLinearKeyboard_z_base_note = default_note
      local dropdown_value = PakettiLinearKeyboard_Clamp(default_note + 1, 1, 120)  -- Clamp dropdown to valid range
      PakettiLinearKeyboard_z_octave_dropdown.value = dropdown_value
    end
    
    if PakettiLinearKeyboard_DEBUG and (base_octave < 1 or base_octave > 8) then
      print("PakettiLinearKeyboard DEBUG: Extreme transport octave " .. tostring(base_octave) .. ", regular base notes clamped to valid range")
    end
  end
end

-- Toggle minimize/maximize and rebuild dialog
function PakettiLinearKeyboard_ToggleMinimize()
  PakettiLinearKeyboard_minimized = not PakettiLinearKeyboard_minimized
  
  -- Close current dialog properly but keep timer running
  if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then
    PakettiLinearKeyboard_dialog:close()
    PakettiLinearKeyboard_dialog = nil
  end
  
  -- Rebuild the dialog with new content (timer will continue running)
  PakettiOpenMPTLinearKeyboardLayerDialog()
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Dialog " .. (PakettiLinearKeyboard_minimized and "minimized" or "maximized"))
  end
end

-- Update dropdowns for fret mode
function PakettiLinearKeyboard_UpdateFretModeDropdowns()
  if not PakettiLinearKeyboard_vb then return end
  
  if PakettiLinearKeyboard_fret_mode_enabled then
    -- Fret mode: Use dynamic base notes that follow transport octave with bounds checking
    if PakettiLinearKeyboard_z_octave_dropdown then
      local dropdown_value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_fret_z_base + 1, 1, 120)  -- Clamp to valid range
      PakettiLinearKeyboard_z_octave_dropdown.value = dropdown_value
    end
    if PakettiLinearKeyboard_a_octave_dropdown then
      local dropdown_value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_fret_a_base + 1, 1, 120)  -- Clamp to valid range
      PakettiLinearKeyboard_a_octave_dropdown.value = dropdown_value
    end
    if PakettiLinearKeyboard_q_octave_dropdown then
      local dropdown_value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_fret_q_base + 1, 1, 120)  -- Clamp to valid range
      PakettiLinearKeyboard_q_octave_dropdown.value = dropdown_value
    end
    if PakettiLinearKeyboard_1_octave_dropdown then
      local dropdown_value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_fret_1_base + 1, 1, 120)  -- Clamp to valid range
      PakettiLinearKeyboard_1_octave_dropdown.value = dropdown_value
    end
  else
    -- Regular mode - restore default values
    PakettiLinearKeyboard_UpdateDropdowns()
  end
end

-- Open dialog
function PakettiOpenMPTLinearKeyboardLayerDialog()
  if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then
    PakettiLinearKeyboard_dialog:close()
    PakettiLinearKeyboard_dialog = nil
  end

  PakettiLinearKeyboard_vb = renoise.ViewBuilder()
  
  -- Create note dropdown items (all 120 notes)
  local note_items = PakettiLinearKeyboard_CreateNoteItems()
  
  local song = renoise.song()
  local base_octave = song.transport.octave or 4
  
  -- Initialize fret mode base notes to follow current transport octave
  local octave_shift = (base_octave - 4) * 12
  PakettiLinearKeyboard_fret_z_base = PakettiLinearKeyboard_Clamp(16 + octave_shift, 0, 119)  -- E-2 + shift, clamped
  PakettiLinearKeyboard_fret_a_base = PakettiLinearKeyboard_Clamp(21 + octave_shift, 0, 119)  -- A-2 + shift, clamped
  PakettiLinearKeyboard_fret_q_base = PakettiLinearKeyboard_Clamp(26 + octave_shift, 0, 119)  -- D-3 + shift, clamped
  PakettiLinearKeyboard_fret_1_base = PakettiLinearKeyboard_Clamp(31 + octave_shift, 0, 119)  -- G-3 + shift, clamped
  
  -- Create dropdowns with default note values and notifiers to update base notes
  PakettiLinearKeyboard_1_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_1_base_note, 0, 119) + 1, 1, 120),
    width = 80,
    notifier = function(value)
      PakettiLinearKeyboard_1_base_note = value - 1 -- Convert from 1-indexed to 0-indexed
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: 1-row base note manually set to " .. tostring(PakettiLinearKeyboard_1_base_note))
      end
    end
  }
  
  PakettiLinearKeyboard_q_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_q_base_note, 0, 119) + 1, 1, 120),
    width = 80,
    notifier = function(value)
      PakettiLinearKeyboard_q_base_note = value - 1 -- Convert from 1-indexed to 0-indexed
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Q-row base note manually set to " .. tostring(PakettiLinearKeyboard_q_base_note))
      end
    end
  }
  
  PakettiLinearKeyboard_a_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_a_base_note, 0, 119) + 1, 1, 120),
    width = 80,
    notifier = function(value)
      PakettiLinearKeyboard_a_base_note = value - 1 -- Convert from 1-indexed to 0-indexed
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: A-row base note manually set to " .. tostring(PakettiLinearKeyboard_a_base_note))
      end
    end
  }
  
  PakettiLinearKeyboard_z_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_z_base_note, 0, 119) + 1, 1, 120),
    width = 80,
    notifier = function(value)
      PakettiLinearKeyboard_z_base_note = value - 1 -- Convert from 1-indexed to 0-indexed
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Z-row base note manually set to " .. tostring(PakettiLinearKeyboard_z_base_note))
      end
    end
  }
  
  -- Follow transport checkbox
  PakettiLinearKeyboard_follow_transport_checkbox = PakettiLinearKeyboard_vb:checkbox{
    value = PakettiLinearKeyboard_follow_transport_enabled,  -- Restore saved follow transport state
    tooltip = "Auto-update keyboard rows when Renoise transport octave changes",
    notifier = function(value)
      PakettiLinearKeyboard_follow_transport_enabled = value  -- Save follow transport state
      if value then
        -- Update dropdowns to follow transport immediately
        if PakettiLinearKeyboard_fret_mode_enabled then
          PakettiLinearKeyboard_UpdateFretModeDropdowns()
        else
          PakettiLinearKeyboard_UpdateDropdowns()
        end
        renoise.app():show_status("PakettiLinearKeyboard: Now following transport octave")
      else
        renoise.app():show_status("PakettiLinearKeyboard: Using manual octave settings")
      end
    end
  }

  -- Fret mode checkbox
  PakettiLinearKeyboard_fret_checkbox = PakettiLinearKeyboard_vb:checkbox{
    value = PakettiLinearKeyboard_fret_mode_enabled,  -- Restore saved fret mode state
    tooltip = "Switch to guitar fret layout instead of linear chromatic rows",
    notifier = function(value)
      PakettiLinearKeyboard_fret_mode_enabled = value  -- Save fret mode state
      if value then
        PakettiLinearKeyboard_UpdateFretModeDropdowns()
        local z_note = PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_z_base)
        local a_note = PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_a_base)
        local q_note = PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_q_base)
        local num1_note = PakettiLinearKeyboard_NoteValueToString(PakettiLinearKeyboard_fret_1_base)
        renoise.app():show_status("PakettiLinearKeyboard: Fret mode enabled - Z=" .. z_note .. ", A=" .. a_note .. ", Q=" .. q_note .. ", 1=" .. num1_note)
        if PakettiLinearKeyboard_DEBUG then
          print("PakettiLinearKeyboard DEBUG: Fret mode enabled with dynamic bases following transport octave")
        end
      else
        PakettiLinearKeyboard_UpdateDropdowns()
        renoise.app():show_status("PakettiLinearKeyboard: Normal linear mode")
      end
    end
  }

  -- Create content based on minimized state
  local content
  
  if PakettiLinearKeyboard_minimized then
    -- Minimized view - just toggle button and essential controls
    content = PakettiLinearKeyboard_vb:column{
      -- Toggle button row
      PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_vb:button{
           text = "+",
           width = 30,
           tooltip = "Maximize dialog to show all keyboard configuration options",
           notifier = function()
             PakettiLinearKeyboard_ToggleMinimize()
           end
         },
        PakettiLinearKeyboard_vb:text{ text = "Linear Keyboard Layer", style = "strong" },
        PakettiLinearKeyboard_vb:button{
          text = "Stop All",
          width = 60,
          tooltip = "Stop all currently playing notes (SPACE key also works)",
          notifier = function()
            PakettiLinearKeyboard_StopAllNotes()
            renoise.app():show_status("PakettiLinearKeyboard: Stopped all playing notes")
          end
        },
        PakettiLinearKeyboard_vb:button{
          text = "Close",
          width = 50,
          tooltip = "Close Linear Keyboard Layer",
          notifier = function()
            PakettiLinearKeyboard_StopAllNotes()
            
            -- Clean up transport notifier
            if renoise.song().transport.octave_observable:has_notifier(PakettiLinearKeyboard_TransportOctaveChanged) then
              renoise.song().transport.octave_observable:remove_notifier(PakettiLinearKeyboard_TransportOctaveChanged)
            end
            PakettiLinearKeyboard_transport_notifier = nil
            
            -- Clean up timer
            if renoise.tool():has_timer(PakettiLinearKeyboard_CleanupStuckNotes) then
              renoise.tool():remove_timer(PakettiLinearKeyboard_CleanupStuckNotes)
            end
            PakettiLinearKeyboard_cleanup_timer = nil
            
            if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then 
              PakettiLinearKeyboard_dialog:close() 
            end
          end
        }
      }
    }
  else
    -- Full view - all controls
    content = PakettiLinearKeyboard_vb:column{
      -- Toggle button row
      PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_vb:button{
           text = "-",
           width = 30,
           tooltip = "Minimize dialog to compact view - keyboard layer stays active",
           notifier = function()
             PakettiLinearKeyboard_ToggleMinimize()
           end
         },
        PakettiLinearKeyboard_vb:text{ text = "Linear Keyboard Layer", style = "strong" }
      },
      
      PakettiLinearKeyboard_vb:space{ height = 5 },
      
       -- Follow transport checkbox
       PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_follow_transport_checkbox,
         PakettiLinearKeyboard_vb:text{ 
           text = "Follow transport octave (dynamic)", 
           style = "strong",
           tooltip = "When enabled, all keyboard rows automatically follow Renoise's transport octave setting for dynamic octave tracking"
         }
       },
       
       -- Fret mode checkbox
       PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_fret_checkbox,
         PakettiLinearKeyboard_vb:text{ 
           text = "Fret mode (guitar-like layout)", 
           style = "strong",
           tooltip = "Guitar-like fret layout: Z=E-2, A=A-2, Q=D-3, 1=G-3, progressing in semitones to the right"
         }
       },
      
      PakettiLinearKeyboard_vb:space{ height = 5 },
      
       -- 1 row configuration
       PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_vb:text{ 
           text = "1 row (1234567890+´):", 
           width = 150, 
           style = "strong",
           tooltip = "Number row: 12 chromatic semitones (0-11) starting from selected base note"
         },
         PakettiLinearKeyboard_1_octave_dropdown,
         PakettiLinearKeyboard_vb:text{ text = "+ 0-11 semitones", width = 120 }
       },
       
       -- Q row configuration
       PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_vb:text{ 
           text = "Q row (QWERTYUIOPÅ¨=]):", 
           width = 150, 
           style = "strong",
           tooltip = "QWERTY row extended: 13+ chromatic semitones starting from selected base note"
         },
         PakettiLinearKeyboard_q_octave_dropdown,
         PakettiLinearKeyboard_vb:text{ text = "+ 0-12+ semitones", width = 120 }
       },
       
       -- A row configuration  
       PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_vb:text{ 
           text = "A row (ASDFGHJKLÖÄ'):", 
           width = 150, 
           style = "strong",
           tooltip = "ASDF row: 12 chromatic semitones (0-11) starting from selected base note"
         },
         PakettiLinearKeyboard_a_octave_dropdown,
         PakettiLinearKeyboard_vb:text{ text = "+ 0-11 semitones", width = 120 }
       },
       
       -- Z row configuration
       PakettiLinearKeyboard_vb:row{
         PakettiLinearKeyboard_vb:text{ 
           text = "Z row (ZXCVBNM,.-<>):", 
           width = 150, 
           style = "strong",
           tooltip = "ZXCV row extended: 12+ chromatic semitones starting from selected base note"
         },
         PakettiLinearKeyboard_z_octave_dropdown,
         PakettiLinearKeyboard_vb:text{ text = "+ 0-11+ semitones", width = 120 }
       },
      
      PakettiLinearKeyboard_vb:space{ height = 10 },
      
      PakettiLinearKeyboard_vb:row{
        PakettiLinearKeyboard_vb:button{
          text = "Update from Transport",
          width = 140,
          tooltip = "Update all keyboard row base notes to follow current Renoise transport octave setting",
          notifier = function()
            PakettiLinearKeyboard_UpdateDropdowns()
            renoise.app():show_status("PakettiLinearKeyboard: Updated dropdowns from transport octave")
          end
        },
        PakettiLinearKeyboard_vb:button{
          text = "Stop All Notes",
          width = 100,
          tooltip = "Stop all currently playing notes instantly (SPACE key also does this)",
          notifier = function()
            PakettiLinearKeyboard_StopAllNotes()
            renoise.app():show_status("PakettiLinearKeyboard: Stopped all playing notes")
          end
        },
        PakettiLinearKeyboard_vb:button{
          text = "Close",
          width = 60,
          tooltip = "Close the Linear Keyboard Layer dialog",
          notifier = function()
            PakettiLinearKeyboard_StopAllNotes()
            
            -- Clean up transport notifier
            if renoise.song().transport.octave_observable:has_notifier(PakettiLinearKeyboard_TransportOctaveChanged) then
              renoise.song().transport.octave_observable:remove_notifier(PakettiLinearKeyboard_TransportOctaveChanged)
            end
            PakettiLinearKeyboard_transport_notifier = nil
            
            -- Clean up timer
            if renoise.tool():has_timer(PakettiLinearKeyboard_CleanupStuckNotes) then
              renoise.tool():remove_timer(PakettiLinearKeyboard_CleanupStuckNotes)
            end
            PakettiLinearKeyboard_cleanup_timer = nil
            
            if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then 
              PakettiLinearKeyboard_dialog:close() 
            end
          end
        }
      }
    }
  end
  
  -- Enable key release events so we can properly detect when keys are let go
  local key_handler_options = {
    send_key_repeat = true,   -- We want key repeat events for held keys
    send_key_release = true   -- We NEED key release events to stop notes!
  }
  
  PakettiLinearKeyboard_dialog = renoise.app():show_custom_dialog("Paketti PlayerPro/OpenMPT Linear Keyboard Layer", content, OpenMPTKeyhandler, key_handler_options)
  
  -- Set up transport octave notifier
  if renoise.song().transport.octave_observable:has_notifier(PakettiLinearKeyboard_TransportOctaveChanged) then
    renoise.song().transport.octave_observable:remove_notifier(PakettiLinearKeyboard_TransportOctaveChanged)
  end
  PakettiLinearKeyboard_transport_notifier = renoise.song().transport.octave_observable:add_notifier(PakettiLinearKeyboard_TransportOctaveChanged)
  
  -- Start cleanup timer for stuck notes
  if renoise.tool():has_timer(PakettiLinearKeyboard_CleanupStuckNotes) then
    renoise.tool():remove_timer(PakettiLinearKeyboard_CleanupStuckNotes)
  end
  PakettiLinearKeyboard_cleanup_timer = renoise.tool():add_timer(PakettiLinearKeyboard_CleanupStuckNotes, PakettiLinearKeyboard_TIMER_INTERVAL) -- Safety backup timer to clean up truly stuck notes
  
  -- Ensure Renoise keeps focus for keyboard
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Apply saved states if they were previously enabled (after dialog rebuild)
  if PakettiLinearKeyboard_fret_mode_enabled then
    PakettiLinearKeyboard_UpdateFretModeDropdowns()
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Restored fret mode state after dialog rebuild")
    end
  elseif PakettiLinearKeyboard_follow_transport_enabled then
    PakettiLinearKeyboard_UpdateDropdowns()
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Restored follow transport state after dialog rebuild")
    end
  end
  
  renoise.app():show_status("PakettiLinearKeyboard: Active - Proper key release events enabled, < > keys pass to Renoise for octave control.")
end

-- Toggle dialog
function PakettiOpenMPTLinearKeyboardLayerToggle()
  if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then
    PakettiLinearKeyboard_StopAllNotes()
    
    -- Clean up transport notifier
    if renoise.song().transport.octave_observable:has_notifier(PakettiLinearKeyboard_TransportOctaveChanged) then
      renoise.song().transport.octave_observable:remove_notifier(PakettiLinearKeyboard_TransportOctaveChanged)
    end
    PakettiLinearKeyboard_transport_notifier = nil
    
    -- Clean up timer
    if renoise.tool():has_timer(PakettiLinearKeyboard_CleanupStuckNotes) then
      renoise.tool():remove_timer(PakettiLinearKeyboard_CleanupStuckNotes)
    end
    PakettiLinearKeyboard_cleanup_timer = nil
    
    PakettiLinearKeyboard_dialog:close()
    PakettiLinearKeyboard_dialog = nil
  else
    PakettiOpenMPTLinearKeyboardLayerDialog()
  end
end

-- Menu entries and keybinding
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti PlayerPro OpenMPT Linear Keyboard Layer...", invoke = PakettiOpenMPTLinearKeyboardLayerToggle}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti Gadgets:Paketti PlayerPro OpenMPT Linear Keyboard Layer...", invoke = PakettiOpenMPTLinearKeyboardLayerToggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti PlayerPro OpenMPT Linear Keyboard Layer...", invoke = PakettiOpenMPTLinearKeyboardLayerToggle}
