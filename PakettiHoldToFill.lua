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

function PakettiHoldToFillResetState()
  PakettiHoldToFillIsFilling = false
  PakettiHoldToFillKeyHoldStart = nil
  PakettiHoldToFillHeldKeyName = nil
  PakettiHoldToFillSawRepeat = false
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
    -- Place the found note into the current line before filling downward
    col.note_value = note_value
    col.instrument_value = instrument_value
    col.volume_value = volume_value
    col.panning_value = panning_value
    col.delay_value = delay_value
  end

  print("DEBUG: Filling column with Note Value: " .. tostring(note_value))

  local num_lines = patt.number_of_lines
  if PakettiHoldToFillUseEditStep then
    local step = s.transport.edit_step
    if step == nil or step < 1 then step = 1 end
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

function PakettiHoldToFillCheckTimer()
  if not (PakettiHoldToFillModeDialog and PakettiHoldToFillModeDialog.visible) then
    if renoise.tool():has_timer(PakettiHoldToFillCheckTimer) then
      renoise.tool():remove_timer(PakettiHoldToFillCheckTimer)
    end
    PakettiHoldToFillModeDialog = nil
    PakettiHoldToFillResetState()
    return
  end

  if not PakettiHoldToFillKeyHoldStart or not PakettiHoldToFillHeldKeyName then
    --print("DEBUG: Timer running, but no key is being held.")
    return
  end

  local hold_duration = os.clock() - PakettiHoldToFillKeyHoldStart
  if (hold_duration >= 0.5) and (not PakettiHoldToFillIsFilling) then
    print("DEBUG: Hold detected. Filling column...")
    PakettiHoldToFillIsFilling = true
    PakettiHoldToFillPerformFill()
    PakettiHoldToFillResetState()
  end
end

function PakettiHoldToFillKeyHandler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  print("KEYHANDLER DEBUG (HoldToFill): name:'" .. tostring(key.name) .. "' modifiers:'" .. tostring(key.modifiers) .. "' repeated:'" .. tostring(key.repeated) .. "'")

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

  if PakettiHoldToFillIgnoreKeys[key.name] then
    return key
  end

  PakettiHoldToFillKeyHoldStart = os.clock()
  PakettiHoldToFillHeldKeyName = key.name
  print("DEBUG: Key pressed. name:" .. tostring(key.name) .. " Start Time:" .. tostring(PakettiHoldToFillKeyHoldStart))
  PakettiHoldToFillSawRepeat = false

  return key
end

function PakettiHoldToFillShowDialog()
  if PakettiHoldToFillModeDialog and PakettiHoldToFillModeDialog.visible then
    PakettiHoldToFillModeDialog:close()
    if renoise.tool():has_timer(PakettiHoldToFillCheckTimer) then
      renoise.tool():remove_timer(PakettiHoldToFillCheckTimer)
    end
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
  local view = vb:column {
    vb:text { text = "Hold a key to fill the current note column downward after ~0.5s." },
    vb:row {
      vb:checkbox {
        value = PakettiHoldToFillUseEditStep,
        notifier = function(val)
          PakettiHoldToFillUseEditStep = val
          print("DEBUG: Fill by edit step set to: " .. tostring(PakettiHoldToFillUseEditStep))
        end
      },
      vb:text { text = "Fill by edit step (" .. tostring(current_edit_step) .. ")" }
    }
  }
  PakettiHoldToFillModeDialog = renoise.app():show_custom_dialog("Paketti Hold-to-Fill Mode", view, PakettiHoldToFillKeyHandler)
  renoise.tool():add_timer(PakettiHoldToFillCheckTimer, 50)
  local amf = renoise.app().window.active_middle_frame
  renoise.app().window.active_middle_frame = amf
  PakettiHoldToFillResetState()
  renoise.app():show_status("Paketti: Hold-to-Fill Mode enabled")
  print("DEBUG: Dialog opened. Timer started.")
end

renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Toggle Hold-to-Fill Mode", invoke = function() PakettiHoldToFillShowDialog() end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Toggle Hold-to-Fill Mode", invoke = function() PakettiHoldToFillShowDialog() end }


