-- PakettiNudge.lua
-- Comprehensive nudge system for Pattern Editor and Phrase Editor.
-- Surpasses SuperNudge + HyperNudge combined.
--
-- Features:
--   Pattern Editor: nudge by line, nudge by step (1/2/4/8/16/32/64/128),
--                   nudge all columns, volume nudge, panning nudge
--   Phrase Editor:  nudge by line (wrap-around), nudge by step (wrap-around),
--                   nudge all columns (wrap-around), volume nudge, panning nudge
--   All operations: keybindings, menu entries, MIDI mappings

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function wrapLine(lineIdx, numLines)
  return ((lineIdx - 1) % numLines) + 1
end

------------------------------------------------------------------------
-- PATTERN EDITOR: Nudge by Step (delay value)
-- Supports configurable step amounts: 1, 2, 4, 8, 16, 32, 64, 128
------------------------------------------------------------------------

function PakettiNudgePatternByStep(direction, steps)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  if not sel then
    renoise.app():show_status("Paketti Nudge: No selection in pattern.")
    return
  end

  song:describe_undo("Paketti Nudge Pattern by " .. steps .. " Step(s) " .. (direction > 0 and "Down" or "Up"))

  local pattern = song.patterns[song.selected_pattern_index]
  local amount = direction * steps

  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    local pat_track = pattern:track(track_idx)
    local vis_note_cols = track.visible_note_columns

    -- Show delay column
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.delay_column_visible = true
    end

    -- Determine column range for this track
    local col_start = (track_idx == sel.start_track) and sel.start_column or 1
    local col_end = (track_idx == sel.end_track) and sel.end_column or (vis_note_cols + track.visible_effect_columns)
    col_start = math.max(col_start, 1)
    col_end = math.min(col_end, vis_note_cols) -- delay only applies to note columns

    if col_start <= vis_note_cols then
      -- Process in correct order to avoid clobbering
      local line_from, line_to, line_step
      if direction > 0 then
        line_from, line_to, line_step = sel.end_line, sel.start_line, -1
      else
        line_from, line_to, line_step = sel.start_line, sel.end_line, 1
      end

      for line_idx = line_from, line_to, line_step do
        local line = pat_track:line(line_idx)
        for col_idx = col_start, col_end do
          local note_col = line.note_columns[col_idx]
          if not note_col.is_empty or note_col.delay_value > 0 then
            local delay = note_col.delay_value
            local new_delay = delay + amount

            if new_delay > 0xFF then
              -- Move to next line
              local next_line_idx = line_idx + 1
              if next_line_idx > sel.end_line then
                next_line_idx = sel.start_line -- wrap within selection
              end
              if next_line_idx >= 1 and next_line_idx <= pattern.number_of_lines then
                local next_col = pat_track:line(next_line_idx).note_columns[col_idx]
                if next_col.is_empty and next_col.delay_value == 0 then
                  next_col:copy_from(note_col)
                  next_col.delay_value = new_delay - 256
                  note_col:clear()
                end
              end
            elseif new_delay < 0 then
              -- Move to previous line
              local prev_line_idx = line_idx - 1
              if prev_line_idx < sel.start_line then
                prev_line_idx = sel.end_line -- wrap within selection
              end
              if prev_line_idx >= 1 and prev_line_idx <= pattern.number_of_lines then
                local prev_col = pat_track:line(prev_line_idx).note_columns[col_idx]
                if prev_col.is_empty and prev_col.delay_value == 0 then
                  prev_col:copy_from(note_col)
                  prev_col.delay_value = new_delay + 256
                  note_col:clear()
                end
              end
            else
              note_col.delay_value = new_delay
            end
          end
        end
      end
    end
  end

  renoise.app():show_status("Paketti Nudge: " .. (direction > 0 and "Down" or "Up") .. " by " .. steps .. " step(s).")
end

------------------------------------------------------------------------
-- PATTERN EDITOR: Nudge by Line
------------------------------------------------------------------------

function PakettiNudgePatternByLine(direction)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  if not sel then
    renoise.app():show_status("Paketti Nudge: No selection in pattern.")
    return
  end

  song:describe_undo("Paketti Nudge Pattern by 1 Line " .. (direction > 0 and "Down" or "Up"))

  local pattern = song.patterns[song.selected_pattern_index]

  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    local pat_track = pattern:track(track_idx)
    local vis_note_cols = track.visible_note_columns
    local vis_fx_cols = track.visible_effect_columns

    local col_start = (track_idx == sel.start_track) and sel.start_column or 1
    local col_end = (track_idx == sel.end_track) and sel.end_column or (vis_note_cols + vis_fx_cols)
    col_start = math.max(col_start, 1)
    col_end = math.min(col_end, vis_note_cols + vis_fx_cols)

    if direction > 0 then
      -- Down: store bottom, shift down, place at top (wrap within selection)
      for col_idx = col_start, col_end do
        if col_idx <= vis_note_cols then
          -- Note column
          local bottom_line = pat_track:line(sel.end_line)
          local stored = {
            note_value = bottom_line.note_columns[col_idx].note_value,
            instrument_value = bottom_line.note_columns[col_idx].instrument_value,
            volume_value = bottom_line.note_columns[col_idx].volume_value,
            panning_value = bottom_line.note_columns[col_idx].panning_value,
            delay_value = bottom_line.note_columns[col_idx].delay_value,
            effect_number_value = bottom_line.note_columns[col_idx].effect_number_value,
            effect_amount_value = bottom_line.note_columns[col_idx].effect_amount_value,
          }
          for li = sel.end_line, sel.start_line + 1, -1 do
            pat_track:line(li).note_columns[col_idx]:copy_from(
              pat_track:line(li - 1).note_columns[col_idx])
          end
          local top_col = pat_track:line(sel.start_line).note_columns[col_idx]
          top_col.note_value = stored.note_value
          top_col.instrument_value = stored.instrument_value
          top_col.volume_value = stored.volume_value
          top_col.panning_value = stored.panning_value
          top_col.delay_value = stored.delay_value
          top_col.effect_number_value = stored.effect_number_value
          top_col.effect_amount_value = stored.effect_amount_value
        else
          -- Effect column
          local fx_idx = col_idx - vis_note_cols
          local bottom_line = pat_track:line(sel.end_line)
          local stored = {
            number_value = bottom_line.effect_columns[fx_idx].number_value,
            amount_value = bottom_line.effect_columns[fx_idx].amount_value,
          }
          for li = sel.end_line, sel.start_line + 1, -1 do
            pat_track:line(li).effect_columns[fx_idx]:copy_from(
              pat_track:line(li - 1).effect_columns[fx_idx])
          end
          local top_fx = pat_track:line(sel.start_line).effect_columns[fx_idx]
          top_fx.number_value = stored.number_value
          top_fx.amount_value = stored.amount_value
        end
      end
    else
      -- Up: store top, shift up, place at bottom (wrap within selection)
      for col_idx = col_start, col_end do
        if col_idx <= vis_note_cols then
          local top_line = pat_track:line(sel.start_line)
          local stored = {
            note_value = top_line.note_columns[col_idx].note_value,
            instrument_value = top_line.note_columns[col_idx].instrument_value,
            volume_value = top_line.note_columns[col_idx].volume_value,
            panning_value = top_line.note_columns[col_idx].panning_value,
            delay_value = top_line.note_columns[col_idx].delay_value,
            effect_number_value = top_line.note_columns[col_idx].effect_number_value,
            effect_amount_value = top_line.note_columns[col_idx].effect_amount_value,
          }
          for li = sel.start_line, sel.end_line - 1 do
            pat_track:line(li).note_columns[col_idx]:copy_from(
              pat_track:line(li + 1).note_columns[col_idx])
          end
          local bottom_col = pat_track:line(sel.end_line).note_columns[col_idx]
          bottom_col.note_value = stored.note_value
          bottom_col.instrument_value = stored.instrument_value
          bottom_col.volume_value = stored.volume_value
          bottom_col.panning_value = stored.panning_value
          bottom_col.delay_value = stored.delay_value
          bottom_col.effect_number_value = stored.effect_number_value
          bottom_col.effect_amount_value = stored.effect_amount_value
        else
          local fx_idx = col_idx - vis_note_cols
          local top_line = pat_track:line(sel.start_line)
          local stored = {
            number_value = top_line.effect_columns[fx_idx].number_value,
            amount_value = top_line.effect_columns[fx_idx].amount_value,
          }
          for li = sel.start_line, sel.end_line - 1 do
            pat_track:line(li).effect_columns[fx_idx]:copy_from(
              pat_track:line(li + 1).effect_columns[fx_idx])
          end
          local bottom_fx = pat_track:line(sel.end_line).effect_columns[fx_idx]
          bottom_fx.number_value = stored.number_value
          bottom_fx.amount_value = stored.amount_value
        end
      end
    end
  end

  renoise.app():show_status("Paketti Nudge: " .. (direction > 0 and "Down" or "Up") .. " by 1 line.")
end

------------------------------------------------------------------------
-- PATTERN EDITOR: Nudge All Columns by Line
------------------------------------------------------------------------

function PakettiNudgePatternAllColumnsByLine(direction)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  if not sel then
    renoise.app():show_status("Paketti Nudge: No selection in pattern.")
    return
  end

  song:describe_undo("Paketti Nudge All Columns by 1 Line " .. (direction > 0 and "Down" or "Up"))

  -- Temporarily expand selection to all columns, then nudge
  local orig_start_col = sel.start_column
  local orig_end_col = sel.end_column

  -- Calculate total columns across all selected tracks
  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    local total = track.visible_note_columns + track.visible_effect_columns
    -- Set selection to cover all columns
    song.selection_in_pattern = {
      start_track = sel.start_track,
      end_track = sel.end_track,
      start_line = sel.start_line,
      end_line = sel.end_line,
      start_column = 1,
      end_column = total,
    }
    break -- use first track's column count for the selection
  end

  PakettiNudgePatternByLine(direction)

  -- Restore original column selection
  song.selection_in_pattern = {
    start_track = sel.start_track,
    end_track = sel.end_track,
    start_line = sel.start_line,
    end_line = sel.end_line,
    start_column = orig_start_col,
    end_column = orig_end_col,
  }
end

------------------------------------------------------------------------
-- PATTERN EDITOR: Volume Nudge
------------------------------------------------------------------------

function PakettiNudgePatternVolume(amount)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  if not sel then
    renoise.app():show_status("Paketti Nudge: No selection in pattern.")
    return
  end

  song:describe_undo("Paketti Volume Nudge " .. (amount > 0 and "+" or "") .. amount)

  local pattern = song.patterns[song.selected_pattern_index]

  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    local pat_track = pattern:track(track_idx)
    local vis_note_cols = track.visible_note_columns

    local col_start = (track_idx == sel.start_track) and sel.start_column or 1
    local col_end = (track_idx == sel.end_track) and sel.end_column or vis_note_cols
    col_start = math.max(col_start, 1)
    col_end = math.min(col_end, vis_note_cols)

    if col_start <= vis_note_cols then
      for line_idx = sel.start_line, sel.end_line do
        local line = pat_track:line(line_idx)
        for col_idx = col_start, col_end do
          local note_col = line.note_columns[col_idx]
          -- Volume values 0x00-0x80 are volume, 0xFF is empty
          if note_col.volume_value ~= 255 and note_col.volume_value <= 0x80 then
            local new_vol = math.max(0, math.min(0x80, note_col.volume_value + amount))
            note_col.volume_value = new_vol
          end
        end
      end
    end
  end

  -- Make volume column visible
  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.volume_column_visible = true
    end
  end

  renoise.app():show_status("Paketti Volume Nudge: " .. (amount > 0 and "+" or "") .. amount)
end

------------------------------------------------------------------------
-- PATTERN EDITOR: Panning Nudge
------------------------------------------------------------------------

function PakettiNudgePatternPanning(amount)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  if not sel then
    renoise.app():show_status("Paketti Nudge: No selection in pattern.")
    return
  end

  song:describe_undo("Paketti Panning Nudge " .. (amount > 0 and "+" or "") .. amount)

  local pattern = song.patterns[song.selected_pattern_index]

  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    local pat_track = pattern:track(track_idx)
    local vis_note_cols = track.visible_note_columns

    local col_start = (track_idx == sel.start_track) and sel.start_column or 1
    local col_end = (track_idx == sel.end_track) and sel.end_column or vis_note_cols
    col_start = math.max(col_start, 1)
    col_end = math.min(col_end, vis_note_cols)

    if col_start <= vis_note_cols then
      for line_idx = sel.start_line, sel.end_line do
        local line = pat_track:line(line_idx)
        for col_idx = col_start, col_end do
          local note_col = line.note_columns[col_idx]
          -- Panning values 0x00-0x80 are panning, 0xFF is empty
          if note_col.panning_value ~= 255 and note_col.panning_value <= 0x80 then
            local new_pan = math.max(0, math.min(0x80, note_col.panning_value + amount))
            note_col.panning_value = new_pan
          end
        end
      end
    end
  end

  -- Make panning column visible
  for track_idx = sel.start_track, sel.end_track do
    local track = song.tracks[track_idx]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.panning_column_visible = true
    end
  end

  renoise.app():show_status("Paketti Panning Nudge: " .. (amount > 0 and "+" or "") .. amount)
end

------------------------------------------------------------------------
-- PHRASE EDITOR: Nudge by Step (delay value, with wrap-around)
------------------------------------------------------------------------

function PakettiNudgePhraseByStep(direction, steps)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("Paketti Nudge: No phrase selected.")
    return
  end

  song:describe_undo("Paketti Nudge Phrase by " .. steps .. " Step(s) " .. (direction > 0 and "Down" or "Up"))

  phrase.delay_column_visible = true
  local amount = direction * steps
  local num_lines = phrase.number_of_lines
  local sel = song.selection_in_phrase

  if not sel then
    -- Cursor mode: nudge single note column at cursor
    local line_idx = song.selected_phrase_line_index
    local col_idx = song.selected_phrase_note_column_index
    if col_idx == 0 then return end

    local note_col = phrase:line(line_idx).note_columns[col_idx]
    if note_col.is_empty then return end

    local delay = note_col.delay_value
    local new_delay = delay + amount

    if new_delay < 0 then
      local target_idx = wrapLine(line_idx - 1, num_lines)
      local dst_col = phrase:line(target_idx).note_columns[col_idx]
      if not dst_col.is_empty then return end
      dst_col:copy_from(note_col)
      note_col:clear()
      dst_col.delay_value = new_delay + 256
      song.selected_phrase_line_index = target_idx
    elseif new_delay > 255 then
      local target_idx = wrapLine(line_idx + 1, num_lines)
      local dst_col = phrase:line(target_idx).note_columns[col_idx]
      if not dst_col.is_empty then return end
      dst_col:copy_from(note_col)
      note_col:clear()
      dst_col.delay_value = new_delay - 256
      song.selected_phrase_line_index = target_idx
    else
      note_col.delay_value = new_delay
    end
  else
    -- Selection mode: nudge all note columns in selection
    local vis_note_cols = phrase.visible_note_columns
    local start_col = sel.start_column
    local end_col = math.min(sel.end_column, vis_note_cols)

    if start_col > vis_note_cols then return end

    local line_from, line_to, line_step
    if direction < 0 then
      line_from, line_to, line_step = sel.start_line, sel.end_line, 1
    else
      line_from, line_to, line_step = sel.end_line, sel.start_line, -1
    end

    local line_idx = line_from
    while true do
      for col_idx = start_col, end_col do
        local note_col = phrase:line(line_idx).note_columns[col_idx]
        if not note_col.is_empty then
          local delay = note_col.delay_value
          local new_delay = delay + amount

          if new_delay < 0 then
            local target_idx = wrapLine(line_idx - 1, num_lines)
            local dst_col = phrase:line(target_idx).note_columns[col_idx]
            if dst_col.is_empty then
              dst_col:copy_from(note_col)
              note_col:clear()
              dst_col.delay_value = new_delay + 256
            end
          elseif new_delay > 255 then
            local target_idx = wrapLine(line_idx + 1, num_lines)
            local dst_col = phrase:line(target_idx).note_columns[col_idx]
            if dst_col.is_empty then
              dst_col:copy_from(note_col)
              note_col:clear()
              dst_col.delay_value = new_delay - 256
            end
          else
            note_col.delay_value = new_delay
          end
        end
      end
      if line_idx == line_to then break end
      line_idx = line_idx + line_step
    end
  end

  renoise.app():show_status("Paketti Phrase Nudge: " .. (direction > 0 and "Down" or "Up") .. " by " .. steps .. " step(s).")
end

------------------------------------------------------------------------
-- PHRASE EDITOR: Nudge by Line (with wrap-around)
------------------------------------------------------------------------

function PakettiNudgePhraseByLine(direction)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("Paketti Nudge: No phrase selected.")
    return
  end

  song:describe_undo("Paketti Nudge Phrase by 1 Line " .. (direction > 0 and "Down" or "Up"))

  local num_lines = phrase.number_of_lines
  local sel = song.selection_in_phrase

  if not sel then
    -- Cursor mode: nudge single column at cursor
    local line_idx = song.selected_phrase_line_index
    local note_col_idx = song.selected_phrase_note_column_index
    local fx_col_idx = song.selected_phrase_effect_column_index

    local target_idx = wrapLine(line_idx + direction, num_lines)

    if note_col_idx ~= 0 then
      local src = phrase:line(line_idx).note_columns[note_col_idx]
      local dst = phrase:line(target_idx).note_columns[note_col_idx]
      if src.is_empty or not dst.is_empty then return end
      dst:copy_from(src)
      src:clear()
    elseif fx_col_idx ~= 0 then
      local src = phrase:line(line_idx).effect_columns[fx_col_idx]
      local dst = phrase:line(target_idx).effect_columns[fx_col_idx]
      if src.is_empty or not dst.is_empty then return end
      dst:copy_from(src)
      src:clear()
    else
      return
    end

    song.selected_phrase_line_index = target_idx
  else
    -- Selection mode: nudge all columns in selection
    local vis_note_cols = phrase.visible_note_columns

    local line_from, line_to, line_step
    if direction == -1 then
      line_from, line_to, line_step = sel.start_line, sel.end_line, 1
    else
      line_from, line_to, line_step = sel.end_line, sel.start_line, -1
    end

    local line_idx = line_from
    while true do
      local target_idx = wrapLine(line_idx + direction, num_lines)

      for col_idx = sel.start_column, sel.end_column do
        if col_idx <= vis_note_cols then
          local src = phrase:line(line_idx).note_columns[col_idx]
          local dst = phrase:line(target_idx).note_columns[col_idx]
          if not src.is_empty and dst.is_empty then
            dst:copy_from(src)
            src:clear()
          end
        else
          local fx_idx = col_idx - vis_note_cols
          local src = phrase:line(line_idx).effect_columns[fx_idx]
          local dst = phrase:line(target_idx).effect_columns[fx_idx]
          if not src.is_empty and dst.is_empty then
            dst:copy_from(src)
            src:clear()
          end
        end
      end

      if line_idx == line_to then break end
      line_idx = line_idx + line_step
    end

    -- Shift selection with wrap
    song.selection_in_phrase = {
      start_line = wrapLine(sel.start_line + direction, num_lines),
      end_line = wrapLine(sel.end_line + direction, num_lines),
      start_column = sel.start_column,
      end_column = sel.end_column,
    }
  end

  renoise.app():show_status("Paketti Phrase Nudge: " .. (direction > 0 and "Down" or "Up") .. " by 1 line.")
end

------------------------------------------------------------------------
-- PHRASE EDITOR: Nudge All Columns by Line (with wrap-around)
------------------------------------------------------------------------

function PakettiNudgePhraseAllColumnsByLine(direction)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("Paketti Nudge: No phrase selected.")
    return
  end

  song:describe_undo("Paketti Nudge Phrase All Columns by 1 Line " .. (direction > 0 and "Down" or "Up"))

  local total_cols = phrase.visible_note_columns + phrase.visible_effect_columns
  if total_cols == 0 then return end

  local sel = song.selection_in_phrase
  local start_line, end_line

  if sel then
    start_line = sel.start_line
    end_line = sel.end_line
  else
    start_line = song.selected_phrase_line_index
    end_line = start_line
  end

  -- Temporarily set full-width selection
  song.selection_in_phrase = {
    start_line = start_line,
    end_line = end_line,
    start_column = 1,
    end_column = total_cols,
  }

  -- Delegate to line nudge (which handles selection mode)
  local num_lines = phrase.number_of_lines
  local vis_note_cols = phrase.visible_note_columns

  local line_from, line_to, line_step
  if direction == -1 then
    line_from, line_to, line_step = start_line, end_line, 1
  else
    line_from, line_to, line_step = end_line, start_line, -1
  end

  local line_idx = line_from
  while true do
    local target_idx = wrapLine(line_idx + direction, num_lines)

    for col_idx = 1, total_cols do
      if col_idx <= vis_note_cols then
        local src = phrase:line(line_idx).note_columns[col_idx]
        local dst = phrase:line(target_idx).note_columns[col_idx]
        if not src.is_empty and dst.is_empty then
          dst:copy_from(src)
          src:clear()
        end
      else
        local fx_idx = col_idx - vis_note_cols
        local src = phrase:line(line_idx).effect_columns[fx_idx]
        local dst = phrase:line(target_idx).effect_columns[fx_idx]
        if not src.is_empty and dst.is_empty then
          dst:copy_from(src)
          src:clear()
        end
      end
    end

    if line_idx == line_to then break end
    line_idx = line_idx + line_step
  end

  -- Restore or update selection
  if sel then
    song.selection_in_phrase = {
      start_line = wrapLine(sel.start_line + direction, num_lines),
      end_line = wrapLine(sel.end_line + direction, num_lines),
      start_column = sel.start_column,
      end_column = sel.end_column,
    }
  else
    song.selection_in_phrase = nil
  end

  renoise.app():show_status("Paketti Phrase Nudge All Columns: " .. (direction > 0 and "Down" or "Up") .. " by 1 line.")
end

------------------------------------------------------------------------
-- PHRASE EDITOR: Volume Nudge
------------------------------------------------------------------------

function PakettiNudgePhraseVolume(amount)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("Paketti Nudge: No phrase selected.")
    return
  end

  song:describe_undo("Paketti Phrase Volume Nudge " .. (amount > 0 and "+" or "") .. amount)

  phrase.volume_column_visible = true
  local vis_note_cols = phrase.visible_note_columns
  local sel = song.selection_in_phrase

  if not sel then
    -- Cursor mode
    local line_idx = song.selected_phrase_line_index
    local col_idx = song.selected_phrase_note_column_index
    if col_idx == 0 then return end
    local note_col = phrase:line(line_idx).note_columns[col_idx]
    if note_col.volume_value ~= 255 and note_col.volume_value <= 0x80 then
      note_col.volume_value = math.max(0, math.min(0x80, note_col.volume_value + amount))
    end
  else
    local start_col = sel.start_column
    local end_col = math.min(sel.end_column, vis_note_cols)
    if start_col > vis_note_cols then return end

    for line_idx = sel.start_line, sel.end_line do
      for col_idx = start_col, end_col do
        local note_col = phrase:line(line_idx).note_columns[col_idx]
        if note_col.volume_value ~= 255 and note_col.volume_value <= 0x80 then
          note_col.volume_value = math.max(0, math.min(0x80, note_col.volume_value + amount))
        end
      end
    end
  end

  renoise.app():show_status("Paketti Phrase Volume Nudge: " .. (amount > 0 and "+" or "") .. amount)
end

------------------------------------------------------------------------
-- PHRASE EDITOR: Panning Nudge
------------------------------------------------------------------------

function PakettiNudgePhrasePanning(amount)
  local song = renoise.song()
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("Paketti Nudge: No phrase selected.")
    return
  end

  song:describe_undo("Paketti Phrase Panning Nudge " .. (amount > 0 and "+" or "") .. amount)

  phrase.panning_column_visible = true
  local vis_note_cols = phrase.visible_note_columns
  local sel = song.selection_in_phrase

  if not sel then
    local line_idx = song.selected_phrase_line_index
    local col_idx = song.selected_phrase_note_column_index
    if col_idx == 0 then return end
    local note_col = phrase:line(line_idx).note_columns[col_idx]
    if note_col.panning_value ~= 255 and note_col.panning_value <= 0x80 then
      note_col.panning_value = math.max(0, math.min(0x80, note_col.panning_value + amount))
    end
  else
    local start_col = sel.start_column
    local end_col = math.min(sel.end_column, vis_note_cols)
    if start_col > vis_note_cols then return end

    for line_idx = sel.start_line, sel.end_line do
      for col_idx = start_col, end_col do
        local note_col = phrase:line(line_idx).note_columns[col_idx]
        if note_col.panning_value ~= 255 and note_col.panning_value <= 0x80 then
          note_col.panning_value = math.max(0, math.min(0x80, note_col.panning_value + amount))
        end
      end
    end
  end

  renoise.app():show_status("Paketti Phrase Panning Nudge: " .. (amount > 0 and "+" or "") .. amount)
end

------------------------------------------------------------------------
-- MIDI helper
------------------------------------------------------------------------

local function midi_is_trigger(message)
  if message:is_trigger() then return true end
  if message.int_value > 0 then return true end
  return false
end

------------------------------------------------------------------------
-- REGISTRATION: Pattern Editor Keybindings + MIDI Mappings
------------------------------------------------------------------------

-- Pattern: Nudge by Line
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Up by 1 Line",invoke=function() PakettiNudgePatternByLine(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Down by 1 Line",invoke=function() PakettiNudgePatternByLine(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Pattern Up by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternByLine(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Pattern Down by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternByLine(1) end end}

-- Pattern: Nudge by Step (1, 2, 4, 8, 16, 32, 64, 128)
local step_sizes = {1, 2, 4, 8, 16, 32, 64, 128}
for _, steps in ipairs(step_sizes) do
  local s = tostring(steps)
  local label = steps == 1 and "1 Step" or (s .. " Steps")

  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Up by " .. label,
    invoke=function() PakettiNudgePatternByStep(-1, steps) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge Down by " .. label,
    invoke=function() PakettiNudgePatternByStep(1, steps) end}
  renoise.tool():add_midi_mapping{name="Paketti:Nudge Pattern Up by " .. label,
    invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternByStep(-1, steps) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Nudge Pattern Down by " .. label,
    invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternByStep(1, steps) end end}
end

-- Pattern: Nudge All Columns by Line
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge All Columns Up by 1 Line",invoke=function() PakettiNudgePatternAllColumnsByLine(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Nudge All Columns Down by 1 Line",invoke=function() PakettiNudgePatternAllColumnsByLine(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Pattern All Columns Up by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternAllColumnsByLine(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Pattern All Columns Down by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternAllColumnsByLine(1) end end}

-- Pattern: Volume Nudge (+1, -1, +16, -16)
local vol_pan_amounts = {1, 16}
for _, amt in ipairs(vol_pan_amounts) do
  local s = string.format("%02d", amt)
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Volume Nudge Up +" .. s,invoke=function() PakettiNudgePatternVolume(amt) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Volume Nudge Down -" .. s,invoke=function() PakettiNudgePatternVolume(-amt) end}
  renoise.tool():add_midi_mapping{name="Paketti:Volume Nudge Pattern Up +" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternVolume(amt) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Volume Nudge Pattern Down -" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternVolume(-amt) end end}
end

-- Pattern: Panning Nudge (+1, -1, +16, -16)
for _, amt in ipairs(vol_pan_amounts) do
  local s = string.format("%02d", amt)
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Panning Nudge Up +" .. s,invoke=function() PakettiNudgePatternPanning(amt) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Panning Nudge Down -" .. s,invoke=function() PakettiNudgePatternPanning(-amt) end}
  renoise.tool():add_midi_mapping{name="Paketti:Panning Nudge Pattern Up +" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternPanning(amt) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Panning Nudge Pattern Down -" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePatternPanning(-amt) end end}
end

------------------------------------------------------------------------
-- REGISTRATION: Phrase Editor Keybindings + MIDI Mappings
------------------------------------------------------------------------

-- Phrase: Nudge by Line
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Up by 1 Line",invoke=function() PakettiNudgePhraseByLine(-1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Down by 1 Line",invoke=function() PakettiNudgePhraseByLine(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Phrase Up by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseByLine(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Phrase Down by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseByLine(1) end end}

-- Phrase: Nudge by Step (1, 2, 4, 8, 16, 32, 64, 128)
for _, steps in ipairs(step_sizes) do
  local s = tostring(steps)
  local label = steps == 1 and "1 Step" or (s .. " Steps")

  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Up by " .. label,
    invoke=function() PakettiNudgePhraseByStep(-1, steps) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Down by " .. label,
    invoke=function() PakettiNudgePhraseByStep(1, steps) end}
  renoise.tool():add_midi_mapping{name="Paketti:Nudge Phrase Up by " .. label,
    invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseByStep(-1, steps) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Nudge Phrase Down by " .. label,
    invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseByStep(1, steps) end end}
end

-- Phrase: Nudge All Columns by Line
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge All Columns Up by 1 Line",invoke=function() PakettiNudgePhraseAllColumnsByLine(-1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge All Columns Down by 1 Line",invoke=function() PakettiNudgePhraseAllColumnsByLine(1) end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Phrase All Columns Up by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseAllColumnsByLine(-1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Phrase All Columns Down by 1 Line",invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseAllColumnsByLine(1) end end}

-- Phrase: Volume Nudge
for _, amt in ipairs(vol_pan_amounts) do
  local s = string.format("%02d", amt)
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Volume Nudge Up +" .. s,invoke=function() PakettiNudgePhraseVolume(amt) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Volume Nudge Down -" .. s,invoke=function() PakettiNudgePhraseVolume(-amt) end}
  renoise.tool():add_midi_mapping{name="Paketti:Volume Nudge Phrase Up +" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseVolume(amt) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Volume Nudge Phrase Down -" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhraseVolume(-amt) end end}
end

-- Phrase: Panning Nudge
for _, amt in ipairs(vol_pan_amounts) do
  local s = string.format("%02d", amt)
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Panning Nudge Up +" .. s,invoke=function() PakettiNudgePhrasePanning(amt) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Panning Nudge Down -" .. s,invoke=function() PakettiNudgePhrasePanning(-amt) end}
  renoise.tool():add_midi_mapping{name="Paketti:Panning Nudge Phrase Up +" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhrasePanning(amt) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Panning Nudge Phrase Down -" .. s,invoke=function(m) if midi_is_trigger(m) then PakettiNudgePhrasePanning(-amt) end end}
end

------------------------------------------------------------------------
-- REGISTRATION: Menu Entries
------------------------------------------------------------------------

-- Pattern Editor menus
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 1 Line",invoke=function() PakettiNudgePatternByLine(-1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 1 Line",invoke=function() PakettiNudgePatternByLine(1) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Nudge:Nudge Up by 1 Step",invoke=function() PakettiNudgePatternByStep(-1, 1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 1 Step",invoke=function() PakettiNudgePatternByStep(1, 1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 2 Steps",invoke=function() PakettiNudgePatternByStep(-1, 2) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 2 Steps",invoke=function() PakettiNudgePatternByStep(1, 2) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 4 Steps",invoke=function() PakettiNudgePatternByStep(-1, 4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 4 Steps",invoke=function() PakettiNudgePatternByStep(1, 4) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 8 Steps",invoke=function() PakettiNudgePatternByStep(-1, 8) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 8 Steps",invoke=function() PakettiNudgePatternByStep(1, 8) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 16 Steps",invoke=function() PakettiNudgePatternByStep(-1, 16) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 16 Steps",invoke=function() PakettiNudgePatternByStep(1, 16) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 32 Steps",invoke=function() PakettiNudgePatternByStep(-1, 32) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 32 Steps",invoke=function() PakettiNudgePatternByStep(1, 32) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 64 Steps",invoke=function() PakettiNudgePatternByStep(-1, 64) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 64 Steps",invoke=function() PakettiNudgePatternByStep(1, 64) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Up by 128 Steps",invoke=function() PakettiNudgePatternByStep(-1, 128) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge Down by 128 Steps",invoke=function() PakettiNudgePatternByStep(1, 128) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Nudge:Nudge All Columns Up by 1 Line",invoke=function() PakettiNudgePatternAllColumnsByLine(-1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Nudge All Columns Down by 1 Line",invoke=function() PakettiNudgePatternAllColumnsByLine(1) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Nudge:Volume Nudge Up +01",invoke=function() PakettiNudgePatternVolume(1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Volume Nudge Down -01",invoke=function() PakettiNudgePatternVolume(-1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Volume Nudge Up +16",invoke=function() PakettiNudgePatternVolume(16) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Volume Nudge Down -16",invoke=function() PakettiNudgePatternVolume(-16) end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Nudge:Panning Nudge Up +01",invoke=function() PakettiNudgePatternPanning(1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Panning Nudge Down -01",invoke=function() PakettiNudgePatternPanning(-1) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Panning Nudge Up +16",invoke=function() PakettiNudgePatternPanning(16) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Nudge:Panning Nudge Down -16",invoke=function() PakettiNudgePatternPanning(-16) end}

-- Phrase Editor menus
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 1 Line",invoke=function() PakettiNudgePhraseByLine(-1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 1 Line",invoke=function() PakettiNudgePhraseByLine(1) end}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Nudge:Nudge Up by 1 Step",invoke=function() PakettiNudgePhraseByStep(-1, 1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 1 Step",invoke=function() PakettiNudgePhraseByStep(1, 1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 2 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 2) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 2 Steps",invoke=function() PakettiNudgePhraseByStep(1, 2) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 4 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 4) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 4 Steps",invoke=function() PakettiNudgePhraseByStep(1, 4) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 8 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 8) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 8 Steps",invoke=function() PakettiNudgePhraseByStep(1, 8) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 16 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 16) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 16 Steps",invoke=function() PakettiNudgePhraseByStep(1, 16) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 32 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 32) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 32 Steps",invoke=function() PakettiNudgePhraseByStep(1, 32) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 64 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 64) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 64 Steps",invoke=function() PakettiNudgePhraseByStep(1, 64) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Up by 128 Steps",invoke=function() PakettiNudgePhraseByStep(-1, 128) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge Down by 128 Steps",invoke=function() PakettiNudgePhraseByStep(1, 128) end}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Nudge:Nudge All Columns Up by 1 Line",invoke=function() PakettiNudgePhraseAllColumnsByLine(-1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Nudge All Columns Down by 1 Line",invoke=function() PakettiNudgePhraseAllColumnsByLine(1) end}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Nudge:Volume Nudge Up +01",invoke=function() PakettiNudgePhraseVolume(1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Volume Nudge Down -01",invoke=function() PakettiNudgePhraseVolume(-1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Volume Nudge Up +16",invoke=function() PakettiNudgePhraseVolume(16) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Volume Nudge Down -16",invoke=function() PakettiNudgePhraseVolume(-16) end}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Nudge:Panning Nudge Up +01",invoke=function() PakettiNudgePhrasePanning(1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Panning Nudge Down -01",invoke=function() PakettiNudgePhrasePanning(-1) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Panning Nudge Up +16",invoke=function() PakettiNudgePhrasePanning(16) end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:Nudge:Panning Nudge Down -16",invoke=function() PakettiNudgePhrasePanning(-16) end}
