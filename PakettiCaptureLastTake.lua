-- PakettiCaptureLastTake.lua
-- Lua 5.1 only. All functions GLOBAL and defined before first use.
-- Uses my_keyhandler_func as fallback. After dialog opens, reactivate middle frame for key passthrough.

-- State
PakettiCapture_dialog = nil
PakettiCapture_vb = nil
PakettiCapture_log_view = nil
PakettiCapture_rows_text = {}
PakettiCapture_rows_buttons = {}
PakettiCapture_sequences = {}
PakettiCapture_current_notes = {}
PakettiCapture_current_set = {}
PakettiCapture_MAX_ROWS = 20

-- Mapping of keyboard keys to semitone offsets from C in the current transport octave
-- Focus on the top QWERTY row + number sharps to match tracker-style layout
PakettiCapture_note_keymap = {
  q = 0,  ["2"] = 1,  w = 2,  ["3"] = 3,  e = 4,
  r = 5,  ["5"] = 6,  t = 7,  ["6"] = 8,  y = 9,
  ["7"] = 10, u = 11,
  -- next partial octave on the same row
  i = 12, ["9"] = 13, o = 14, ["0"] = 15, p = 16
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

-- Helper: convert key.name to note string based on current octave; returns nil if key is not a note key
function PakettiCapture_KeyToNoteString(key_name)
  if not key_name then return nil end
  local offset = PakettiCapture_note_keymap[key_name]
  if offset == nil then return nil end
  local song = renoise.song()
  local base_oct = song.transport.octave or 4
  local value = (base_oct * 12) + offset
  value = PakettiCapture_Clamp(value, 0, 119)
  return PakettiCapture_NoteValueToString(value)
end

-- Append current buffer as a sequence row
function PakettiCapture_CommitCurrent()
  if #PakettiCapture_current_notes == 0 then return end
  local seq = {}
  for i = 1, #PakettiCapture_current_notes do seq[i] = PakettiCapture_current_notes[i] end
  table.insert(PakettiCapture_sequences, 1, seq)
  while #PakettiCapture_sequences > PakettiCapture_MAX_ROWS do
    table.remove(PakettiCapture_sequences)
  end
  PakettiCapture_current_notes = {}
  PakettiCapture_current_set = {}
  PakettiCapture_UpdateUI()
  renoise.app():show_status("PakettiCapture: Committed current take (" .. tostring(#seq) .. " notes)")
end

-- Clear all captured
function PakettiCapture_ClearAll()
  PakettiCapture_sequences = {}
  PakettiCapture_current_notes = {}
  PakettiCapture_current_set = {}
  PakettiCapture_UpdateUI()
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
  local needed = #notes
  if needed < 1 then return end

  -- Fit visible note columns
  local max_cols = track.max_note_columns or 12
  local new_cols = PakettiCapture_Clamp(needed, 1, max_cols)
  if track.visible_note_columns ~= new_cols then
    track.visible_note_columns = new_cols
  end

  -- Write notes as strings; clear extra columns
  for i = 1, new_cols do
    local ncol = line:note_column(i)
    ncol.note_string = notes[i] or "OFF"
  end
  for i = new_cols + 1, max_cols do
    local ncol = line:note_column(i)
    if not ncol.is_empty then ncol.note_string = "" end
  end

  renoise.app():show_status("PakettiCapture: Wrote " .. tostring(needed) .. " notes to row")
end

-- Update UI rows and log
function PakettiCapture_UpdateUI()
  if not PakettiCapture_vb then return end

  -- Update fixed rows
  for i = 1, PakettiCapture_MAX_ROWS do
    local txt = PakettiCapture_rows_text[i]
    local btn = PakettiCapture_rows_buttons[i]
    if txt and btn then
      if i <= #PakettiCapture_sequences then
        local seq = PakettiCapture_sequences[i]
        local line_txt = table.concat(seq, " ")
        txt.text = string.format("%02d) %s", i, line_txt)
        btn.active = true
      else
        txt.text = string.format("%02d) ", i)
        btn.active = false
      end
    end
  end

  -- Update log view
  if PakettiCapture_log_view then
    local lines = {}
    table.insert(lines, "Current: " .. (#PakettiCapture_current_notes > 0 and table.concat(PakettiCapture_current_notes, " ") or "<empty>"))
    table.insert(lines, "")
    for i = 1, math.min(#PakettiCapture_sequences, PakettiCapture_MAX_ROWS) do
      table.insert(lines, string.format("%02d) %s", i, table.concat(PakettiCapture_sequences[i], " ")))
    end
    PakettiCapture_log_view.text = table.concat(lines, "\n")
  end
end

-- Key handler modeled after Autocomplete: capture note keys but pass them back; handle control keys locally
function PakettiCapture_KeyHandler(dialog, key)
  if key and key.name == "return" then
    PakettiCapture_CommitCurrent()
    return nil
  elseif key and key.name == "back" then
    if #PakettiCapture_current_notes > 0 then
      table.remove(PakettiCapture_current_notes)
      PakettiCapture_UpdateUI()
    end
    return nil
  elseif key and key.name == "delete" then
    PakettiCapture_current_notes = {}
    PakettiCapture_current_set = {}
    PakettiCapture_UpdateUI()
    return nil
  end

  -- Map key to note; if mapped, append to current buffer and PASS THROUGH
  local kname = tostring(key and key.name or "")
  local note = PakettiCapture_KeyToNoteString(kname)
  if note then
    if not PakettiCapture_current_set[note] then
      PakettiCapture_current_set[note] = true
      table.insert(PakettiCapture_current_notes, note)
      PakettiCapture_UpdateUI()
    end
    return key -- pass back to Renoise so notes still play
  end

  -- Fallback to global handler for close etc.
  return my_keyhandler_func(dialog, key)
end

-- Build fixed rows
function PakettiCapture_BuildRows()
  local rows = {}
  for i = 1, PakettiCapture_MAX_ROWS do
    local idx = i
    local rt = PakettiCapture_vb:text{ text = string.format("%02d) ", i), width = 480, style = "normal" }
    local rb = PakettiCapture_vb:button{
      text = "Dump to current row",
      width = 180,
      active = false,
      notifier = function() PakettiCapture_DumpRow(idx) end
    }
    table.insert(rows, PakettiCapture_vb:row{ rt, rb })
    PakettiCapture_rows_text[i] = rt
    PakettiCapture_rows_buttons[i] = rb
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

  PakettiCapture_log_view = PakettiCapture_vb:multiline_textfield{
    width = 680,
    height = 120,
    font = "mono",
    text = ""
  }

  local content = PakettiCapture_vb:column{
    margin = 8,
    spacing = 4,
    PakettiCapture_vb:row{
      PakettiCapture_vb:text{ text = "Captured Last Takes", style = "strong", width = 300 },
      PakettiCapture_vb:space{ width = 10 },
      PakettiCapture_vb:button{ text = "Commit Current (Enter)", width = 170, notifier = PakettiCapture_CommitCurrent },
      PakettiCapture_vb:space{ width = 6 },
      PakettiCapture_vb:button{ text = "Clear All", width = 100, notifier = PakettiCapture_ClearAll }
    },
    PakettiCapture_log_view,
    PakettiCapture_vb:space{ height = 6 },
    unpack(PakettiCapture_BuildRows()),
    PakettiCapture_vb:space{ height = 8 },
    PakettiCapture_vb:row{
      PakettiCapture_vb:button{ text = "Close", width = 100, notifier = function()
        if PakettiCapture_dialog and PakettiCapture_dialog.visible then PakettiCapture_dialog:close() end
      end }
    }
  }

  PakettiCapture_dialog = renoise.app():show_custom_dialog("Paketti Capture Last Take", content, PakettiCapture_KeyHandler)
  PakettiCapture_UpdateUI()

  -- Ensure Renoise keeps focus for keyboard
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Toggle
function PakettiCaptureLastTakeToggle()
  if PakettiCapture_dialog and PakettiCapture_dialog.visible then
    PakettiCapture_dialog:close()
    PakettiCapture_dialog = nil
  else
    PakettiCaptureLastTakeDialog()
  end
end

-- Menu entries and keybinding
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Capture Last Take...", invoke = PakettiCaptureLastTakeToggle}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti Gadgets:Paketti Capture Last Take...", invoke = PakettiCaptureLastTakeToggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Capture Last Take...", invoke = PakettiCaptureLastTakeToggle}


