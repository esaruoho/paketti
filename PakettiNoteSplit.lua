-- PakettiNoteSplit.lua
-- Split a note into N equal pieces with calculated delay values
-- Replicates Ableton's CMD+E split behavior with proper delay column values

local dialog = nil

-- Auto-detect note length by scanning forward from cursor for next note or NOTE_OFF
local function PakettiNoteSplitAutoDetectLength(ptrack, start_line, note_col_index, max_lines)
  for line_idx = start_line + 1, max_lines do
    local ncol = ptrack:line(line_idx):note_column(note_col_index)
    if ncol.note_value < 121 then
      -- Found a real note (0-119) or NOTE_OFF (120)
      return line_idx - start_line
    end
  end
  -- No note found, use rest of pattern
  return max_lines - start_line + 1
end

function PakettiNoteSplitExecute(num_pieces)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]

  -- Must be a sequencer track
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Split Note: Must be on a sequencer track.")
    return
  end

  local ptrack = pattern:track(track_index)
  local max_lines = pattern.number_of_lines

  -- Determine note column index (default to 1 if cursor is in effect column)
  local note_col_index = song.selected_note_column_index
  if note_col_index == 0 then
    note_col_index = 1
  end

  -- Determine selection range
  local start_line, end_line
  local sel = song.selection_in_pattern

  if sel and sel.start_line and sel.end_line then
    start_line = sel.start_line
    end_line = sel.end_line
  else
    -- No selection: auto-detect from cursor
    start_line = song.selected_line_index
    local length = PakettiNoteSplitAutoDetectLength(ptrack, start_line, note_col_index, max_lines)
    end_line = start_line + length - 1
  end

  local total_lines = end_line - start_line + 1

  -- Read source note from first line
  local source = ptrack:line(start_line):note_column(note_col_index)
  local src_note = source.note_value
  local src_instrument = source.instrument_value
  local src_volume = source.volume_value
  local src_panning = source.panning_value

  -- Validate: must have a real note (0-119)
  if src_note >= 120 then
    renoise.app():show_status("Split Note: No note found at the start of the selection.")
    return
  end

  -- Validate: num_pieces must fit (minimum 1 line per piece)
  if num_pieces > total_lines then
    renoise.app():show_status("Split Note: Cannot split into " .. num_pieces .. " pieces across " .. total_lines .. " lines.")
    return
  end

  if num_pieces < 2 then
    renoise.app():show_status("Split Note: Need at least 2 pieces.")
    return
  end

  -- Undo support
  song:describe_undo("Split Note into " .. num_pieces .. " Equal Pieces")

  -- Clear the selection range on the target column
  for line_idx = start_line, end_line do
    if line_idx >= 1 and line_idx <= max_lines then
      ptrack:line(line_idx):note_column(note_col_index):clear()
    end
  end

  -- Calculate and write each piece
  for i = 0, num_pieces - 1 do
    local position = i * (total_lines / num_pieces)
    local target_line = start_line + math.floor(position)
    local frac = position - math.floor(position)
    local delay_value = math.floor(frac * 255)

    if target_line >= 1 and target_line <= max_lines then
      local ncol = ptrack:line(target_line):note_column(note_col_index)
      ncol.note_value = src_note
      if src_instrument ~= 255 then
        ncol.instrument_value = src_instrument
      end
      if src_volume ~= 255 then
        ncol.volume_value = src_volume
      end
      if src_panning ~= 255 then
        ncol.panning_value = src_panning
      end
      if delay_value > 0 then
        ncol.delay_value = delay_value
      end
    end
  end

  -- Write NOTE_OFF at end_line + 1 if within pattern bounds and the line is empty
  local off_line = end_line + 1
  if off_line >= 1 and off_line <= max_lines then
    local ncol = ptrack:line(off_line):note_column(note_col_index)
    if ncol.note_value == 121 then -- EMPTY_NOTE
      ncol.note_value = 120 -- NOTE_OFF
    end
  end

  -- Ensure delay column is visible
  if not track.delay_column_visible then
    track.delay_column_visible = true
  end

  renoise.app():show_status("Split note into " .. num_pieces .. " equal pieces across " .. total_lines .. " lines.")
end

-- Dialog
function PakettiNoteSplitDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local last_applied_pieces = 0

  local function get_selection_info()
    local song = renoise.song()
    local sel = song.selection_in_pattern
    if sel and sel.start_line and sel.end_line then
      local total = sel.end_line - sel.start_line + 1
      return "Selection: lines " .. sel.start_line .. "-" .. sel.end_line .. " (" .. total .. " lines)"
    else
      return "No selection (will auto-detect from cursor)"
    end
  end

  local function apply_split_from_dialog(num_pieces)
    if num_pieces == last_applied_pieces then return end
    last_applied_pieces = num_pieces
    vb.views.num_pieces.value = num_pieces
    vb.views.split_slider.value = math.min(num_pieces, 64)
    PakettiNoteSplitExecute(num_pieces)
    vb.views.selection_info.text = get_selection_info()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  local dialog_content = vb:column{
    margin = 6,
    spacing = 4,

    vb:text{
      id = "selection_info",
      text = get_selection_info(),
    },

    vb:horizontal_aligner{
      mode = "justify",
      vb:text{
        text = "Pieces:",
        width = 46,
      },
      vb:valuebox{
        id = "num_pieces",
        min = 2,
        max = 128,
        value = 3,
        width = 70,
        notifier = function(value)
          apply_split_from_dialog(value)
        end,
      },
    },

    vb:slider{
      id = "split_slider",
      min = 2,
      max = 64,
      value = 3,
      width = 200,
      notifier = function(value)
        local int_value = math.floor(value + 0.5)
        if int_value < 2 then int_value = 2 end
        apply_split_from_dialog(int_value)
      end,
    },

    vb:text{
      text = "Quick split:",
    },

    vb:horizontal_aligner{
      spacing = 2,
      vb:button{text = "2", width = 26, notifier = function() apply_split_from_dialog(2) end},
      vb:button{text = "3", width = 26, notifier = function() apply_split_from_dialog(3) end},
      vb:button{text = "4", width = 26, notifier = function() apply_split_from_dialog(4) end},
      vb:button{text = "5", width = 26, notifier = function() apply_split_from_dialog(5) end},
      vb:button{text = "6", width = 26, notifier = function() apply_split_from_dialog(6) end},
      vb:button{text = "7", width = 26, notifier = function() apply_split_from_dialog(7) end},
      vb:button{text = "8", width = 26, notifier = function() apply_split_from_dialog(8) end},
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Split Note into N Equal Pieces", dialog_content, keyhandler)
end

-- Keybindings
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into N Equal Pieces...", invoke = function() PakettiNoteSplitDialog() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 02 Equal Pieces", invoke = function() PakettiNoteSplitExecute(2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 03 Equal Pieces", invoke = function() PakettiNoteSplitExecute(3) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 04 Equal Pieces", invoke = function() PakettiNoteSplitExecute(4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 05 Equal Pieces", invoke = function() PakettiNoteSplitExecute(5) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 06 Equal Pieces", invoke = function() PakettiNoteSplitExecute(6) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 07 Equal Pieces", invoke = function() PakettiNoteSplitExecute(7) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Split Note into 08 Equal Pieces", invoke = function() PakettiNoteSplitExecute(8) end}

-- MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:Split Note into N Equal Pieces...", invoke = function(message) if message:is_trigger() then PakettiNoteSplitDialog() end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 02 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(2) end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 03 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(3) end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 04 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(4) end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 05 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(5) end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 06 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(6) end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 07 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(7) end end}
renoise.tool():add_midi_mapping{name="Paketti:Split Note into 08 Equal Pieces", invoke = function(message) if message:is_trigger() then PakettiNoteSplitExecute(8) end end}
