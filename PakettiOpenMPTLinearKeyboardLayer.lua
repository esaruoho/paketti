-- PakettiOpenMPTLinearKeyboardLayer.lua
-- Lua 5.1 only. All functions GLOBAL and defined before first use.
-- Uses my_keyhandler_func as fallback. After dialog opens, reactivate middle frame for key passthrough.
-- Linear keyboard layer: QWERTYUIOP, ASDFGHJKL, ZXCVBNM,. as linear octave rows

-- State
PakettiLinearKeyboard_dialog = nil
PakettiLinearKeyboard_vb = nil
PakettiLinearKeyboard_q_octave_dropdown = nil
PakettiLinearKeyboard_a_octave_dropdown = nil
PakettiLinearKeyboard_z_octave_dropdown = nil
PakettiLinearKeyboard_current_playing_notes = {}
PakettiLinearKeyboard_pressed_keys = {}  -- Track which keys are currently pressed
PakettiLinearKeyboard_DEBUG = true

-- Default note values (absolute note values, not octave offsets)
PakettiLinearKeyboard_q_base_note = 48    -- C-4 (transport.octave * 12)
PakettiLinearKeyboard_a_base_note = 60    -- C-5 (transport.octave + 1) * 12  
PakettiLinearKeyboard_z_base_note = 72    -- C-6 (transport.octave + 2) * 12

-- Linear key mappings for each row (semitone offsets within octave)
PakettiLinearKeyboard_q_row_keys = {
  q = 0, w = 1, e = 2, r = 3, t = 4, y = 5, u = 6, i = 7, o = 8, p = 9, ["å"] = 10, ["¨"] = 11
}

PakettiLinearKeyboard_a_row_keys = {
  a = 0, s = 1, d = 2, f = 3, g = 4, h = 5, j = 6, k = 7, l = 8, ["ö"] = 9, ["ä"] = 10, ["'"] = 11
}

PakettiLinearKeyboard_z_row_keys = {
  z = 0, x = 1, c = 2, v = 3, b = 4, n = 5, m = 6, [","] = 7, ["comma"] = 7, ["."] = 8, ["period"] = 8, ["-"] = 9, ["minus"] = 9, ["hyphen"] = 9
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
  
  -- Check Q row
  local q_offset = PakettiLinearKeyboard_q_row_keys[key_name]
  if q_offset ~= nil then
    local base_note = PakettiLinearKeyboard_GetSelectedNoteValue(PakettiLinearKeyboard_q_octave_dropdown.value)
    local note_value = base_note + q_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  -- Check A row  
  local a_offset = PakettiLinearKeyboard_a_row_keys[key_name]
  if a_offset ~= nil then
    local base_note = PakettiLinearKeyboard_GetSelectedNoteValue(PakettiLinearKeyboard_a_octave_dropdown.value)
    local note_value = base_note + a_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  -- Check Z row
  local z_offset = PakettiLinearKeyboard_z_row_keys[key_name]
  if z_offset ~= nil then
    local base_note = PakettiLinearKeyboard_GetSelectedNoteValue(PakettiLinearKeyboard_z_octave_dropdown.value)
    local note_value = base_note + z_offset
    return PakettiLinearKeyboard_Clamp(note_value, 0, 119)
  end
  
  return nil
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
  
  if PakettiLinearKeyboard_DEBUG then
    print("PakettiLinearKeyboard DEBUG: Stopped all notes")
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
  
  -- Stop the specific note
  song:trigger_instrument_note_off(selected_instrument_index, selected_track_index, {note_value})
  
  if PakettiLinearKeyboard_DEBUG then
    local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
    print("PakettiLinearKeyboard DEBUG: Stopped note " .. tostring(note_string) .. " (" .. tostring(note_value) .. ")")
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
    
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Wrote note " .. tostring(note_string) .. " to pattern")
    end
  end
end

-- Dedicated OpenMPT Linear Keyboard Key Handler
function OpenMPTKeyhandler(dialog, key)
  if not key then return my_keyhandler_func(dialog, key) end
  
  local key_name = tostring(key.name or "")
  
  -- Handle special keys for note control
  if key_name == "space" and not key.repeated then
    -- Space bar stops all notes
    PakettiLinearKeyboard_StopAllNotes()
    return nil
  end
  
  -- Check if we're in note column
  local in_note_column = PakettiLinearKeyboard_IsInNoteColumn()
  
  if not in_note_column then
    -- Not in note column, stop any playing notes and pass through to Renoise
    if #PakettiLinearKeyboard_current_playing_notes > 0 then
      PakettiLinearKeyboard_StopAllNotes()
    end
    
    -- Show user which column type they're in for the first key press
    if not key.repeated then
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
  
  if note_value then
    -- This is a mappable note key
    if not key.repeated then
      -- Key press: check if this is a new key or same key
      local was_already_pressed = PakettiLinearKeyboard_pressed_keys[key_name]
      
      if not was_already_pressed then
        -- New key pressed - stop all other notes first, then start this one
        PakettiLinearKeyboard_StopAllNotes()
        PakettiLinearKeyboard_pressed_keys = {} -- Clear all pressed keys
        
        -- Start this note and track the key
        PakettiLinearKeyboard_StartNote(note_value)
        PakettiLinearKeyboard_WriteNoteToPattern(note_value)
        PakettiLinearKeyboard_pressed_keys[key_name] = note_value
        
        -- Show feedback that we're intercepting
        local note_string = PakettiLinearKeyboard_NoteValueToString(note_value)
        renoise.app():show_status("PakettiLinearKeyboard: In Note column - playing " .. note_string .. " (key: " .. key_name .. ")")
      end
    else
      -- Key repeated - don't retrigger note, but keep it playing
      if PakettiLinearKeyboard_DEBUG then
        print("PakettiLinearKeyboard DEBUG: Key repeated, maintaining note: " .. key_name)
      end
    end
    
    -- Don't pass the key through to Renoise since we've handled it
    return nil
  else
    -- Not a mappable key, stop any playing notes and pass through
    if not key.repeated then
      PakettiLinearKeyboard_StopAllNotes()
      PakettiLinearKeyboard_pressed_keys = {}
    end
    if PakettiLinearKeyboard_DEBUG then
      print("PakettiLinearKeyboard DEBUG: Unmappable key, passing through: " .. key_name)
    end
    return my_keyhandler_func(dialog, key)
  end
end

-- Update dropdown values based on current transport octave
function PakettiLinearKeyboard_UpdateDropdowns()
  if not PakettiLinearKeyboard_vb then return end
  
  local song = renoise.song()
  local base_octave = song.transport.octave or 4
  
  -- Update dropdowns to show current defaults based on transport octave
  if PakettiLinearKeyboard_q_octave_dropdown then
    local default_note = base_octave * 12  -- C- of transport octave
    PakettiLinearKeyboard_q_base_note = default_note
    PakettiLinearKeyboard_q_octave_dropdown.value = default_note + 1  -- dropdown is 1-indexed
  end
  
  if PakettiLinearKeyboard_a_octave_dropdown then
    local default_note = (base_octave + 1) * 12  -- C- of transport octave + 1
    PakettiLinearKeyboard_a_base_note = default_note
    PakettiLinearKeyboard_a_octave_dropdown.value = default_note + 1
  end
  
  if PakettiLinearKeyboard_z_octave_dropdown then
    local default_note = (base_octave + 2) * 12  -- C- of transport octave + 2  
    PakettiLinearKeyboard_z_base_note = default_note
    PakettiLinearKeyboard_z_octave_dropdown.value = default_note + 1
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
  
  -- Create dropdowns with default note values
  PakettiLinearKeyboard_q_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_q_base_note, 0, 119) + 1,
    width = 80
  }
  
  PakettiLinearKeyboard_a_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_a_base_note, 0, 119) + 1,
    width = 80
  }
  
  PakettiLinearKeyboard_z_octave_dropdown = PakettiLinearKeyboard_vb:popup{
    items = note_items,
    value = PakettiLinearKeyboard_Clamp(PakettiLinearKeyboard_z_base_note, 0, 119) + 1,
    width = 80
  }

  local content = PakettiLinearKeyboard_vb:column{
    PakettiLinearKeyboard_vb:text{
      text = "Configure starting note for each keyboard row:",
      style = "strong"
    },
    PakettiLinearKeyboard_vb:space{ height = 5 },
    
    -- Q row configuration
    PakettiLinearKeyboard_vb:row{
      PakettiLinearKeyboard_vb:text{ text = "Q row (QWERTYUIOP):", width = 150, style = "strong" },
      PakettiLinearKeyboard_q_octave_dropdown,
      PakettiLinearKeyboard_vb:text{ text = "+ 0-11 semitones (linear)", width = 200 }
    },
    
    -- A row configuration  
    PakettiLinearKeyboard_vb:row{
      PakettiLinearKeyboard_vb:text{ text = "A row (ASDFGHJKL):", width = 150, style = "strong" },
      PakettiLinearKeyboard_a_octave_dropdown,
      PakettiLinearKeyboard_vb:text{ text = "+ 0-11 semitones (linear)", width = 200 }
    },
    
    -- Z row configuration
    PakettiLinearKeyboard_vb:row{
      PakettiLinearKeyboard_vb:text{ text = "Z row (ZXCVBNM):", width = 150, style = "strong" },
      PakettiLinearKeyboard_z_octave_dropdown,
      PakettiLinearKeyboard_vb:text{ text = "+ 0-11 semitones (linear)", width = 200 }
    },
    
    PakettiLinearKeyboard_vb:space{ height = 10 },
    
    PakettiLinearKeyboard_vb:text{
      text = "How it works:",
      font = "bold",
      style = "strong"
    },
    PakettiLinearKeyboard_vb:text{
      text = "• When cursor is in NOTE column: keys are remapped and auditioned",
      style = "normal"
    },
    PakettiLinearKeyboard_vb:text{
      text = "• When cursor is in other columns: keys pass through normally",
      style = "normal"
    },
    PakettiLinearKeyboard_vb:text{
      text = "• Each row plays 12 chromatic semitones linearly from chosen start note",
      style = "normal"
    },
    PakettiLinearKeyboard_vb:text{
      text = "• Press SPACE to stop all playing notes",
      style = "normal"
    },
    PakettiLinearKeyboard_vb:text{
      text = "• Notes auto-stop when moving cursor or pressing different keys",
      style = "normal"
    },
    
    PakettiLinearKeyboard_vb:space{ height = 10 },
    
    PakettiLinearKeyboard_vb:row{
      PakettiLinearKeyboard_vb:button{
        text = "Update from Transport",
        width = 140,
        notifier = function()
          PakettiLinearKeyboard_UpdateDropdowns()
          renoise.app():show_status("PakettiLinearKeyboard: Updated dropdowns from transport octave")
        end
      },
      PakettiLinearKeyboard_vb:space{ width = 10 },
      PakettiLinearKeyboard_vb:button{
        text = "Stop All Notes",
        width = 100,
        notifier = function()
          PakettiLinearKeyboard_StopAllNotes()
          renoise.app():show_status("PakettiLinearKeyboard: Stopped all playing notes")
        end
      },
      PakettiLinearKeyboard_vb:space{ width = 10 },
      PakettiLinearKeyboard_vb:button{
        text = "Close",
        width = 60,
        notifier = function()
          PakettiLinearKeyboard_StopAllNotes()
          if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then 
            PakettiLinearKeyboard_dialog:close() 
          end
        end
      }
    }
  }
  
  PakettiLinearKeyboard_dialog = renoise.app():show_custom_dialog("Paketti OpenMPT Linear Keyboard Layer", content, OpenMPTKeyhandler)
  
  -- Ensure Renoise keeps focus for keyboard
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  renoise.app():show_status("PakettiLinearKeyboard: Layer active - QWERTY rows play linear notes from selected starting points")
end

-- Toggle dialog
function PakettiOpenMPTLinearKeyboardLayerToggle()
  if PakettiLinearKeyboard_dialog and PakettiLinearKeyboard_dialog.visible then
    PakettiLinearKeyboard_StopAllNotes()
    PakettiLinearKeyboard_dialog:close()
    PakettiLinearKeyboard_dialog = nil
  else
    PakettiOpenMPTLinearKeyboardLayerDialog()
  end
end

-- Menu entries and keybinding
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti OpenMPT Linear Keyboard Layer...", invoke = PakettiOpenMPTLinearKeyboardLayerToggle}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti Gadgets:Paketti OpenMPT Linear Keyboard Layer...", invoke = PakettiOpenMPTLinearKeyboardLayerToggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti OpenMPT Linear Keyboard Layer...", invoke = PakettiOpenMPTLinearKeyboardLayerToggle}
